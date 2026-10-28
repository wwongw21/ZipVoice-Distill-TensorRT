"""Private, loopback-only lifecycle control for the separate native profile."""
from __future__ import annotations
import argparse,fcntl,hashlib,importlib.util,json,math,os,signal,socket,stat,subprocess,sys,time,uuid
from pathlib import Path
import urllib.request

class ControlError(RuntimeError): pass
class ProcessUnknown(ControlError): pass

def atomic(path, value):
    path.parent.mkdir(mode=0o700,parents=True,exist_ok=True)
    temp=path.with_name("."+path.name+"."+uuid.uuid4().hex+".tmp")
    fd=os.open(temp,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
    with os.fdopen(fd,"w") as f:json.dump(value,f,sort_keys=True);f.flush();os.fsync(f.fileno())
    os.replace(temp,path)
    d=os.open(path.parent,os.O_RDONLY|os.O_DIRECTORY)
    try:os.fsync(d)
    finally:os.close(d)

def process_stat(pid):
    """Only absence or a confirmed dead state means the process is gone."""
    try:
        pid=int(pid)
        text=Path(f"/proc/{pid}/stat").read_text()
        tail=text.rsplit(")",1)[1].split()
        if tail[0] in {"Z","X"}:return None
        return {"token":tail[19],"ppid":int(tail[1])}
    except (FileNotFoundError,ProcessLookupError):return None
    except (OSError,ValueError,IndexError) as e:
        raise ProcessUnknown(f"Process {pid} stat is unreadable or invalid") from e

def process(pid):
    before=process_stat(pid)
    if before is None:return None
    try:
        raw=Path(f"/proc/{pid}/cmdline").read_bytes()
        exe=str(Path(f"/proc/{pid}/exe").resolve(strict=True))
    except OSError as e:
        if process_stat(pid) is None:return None
        raise ProcessUnknown(f"Live process {pid} command or executable is unreadable") from e
    after=process_stat(pid)
    if after is None:return None
    if before["token"]!=after["token"]:
        raise ProcessUnknown(f"Process {pid} changed during observation")
    argv=os.fsdecode(raw).rstrip("\0").split("\0")
    if not raw or argv==[""]:
        raise ProcessUnknown(f"Live process {pid} command is temporarily unavailable")
    return {**after,"argv":argv,"exe":exe}

def boot():return Path("/proc/sys/kernel/random/boot_id").read_text().strip()

def descendants(pid):
    found=[];parents={int(pid)}
    items={int(p.name):process_stat(int(p.name)) for p in Path("/proc").iterdir() if p.name.isdigit()}
    while True:
        new={p for p,v in items.items() if v and v["ppid"] in parents and p not in parents}
        if not new:break
        parents.update(new)
        found.extend({"pid":p,"token":items[p]["token"]} for p in new)
    return found

def tcp_open(port):
    # WSL VirtioProxy can acknowledge connects after a Linux listener exits.
    # Kernel LISTEN entries identify actual local backend occupancy instead.
    try:
        for name in ("/proc/net/tcp","/proc/net/tcp6"):
            for line in Path(name).read_text().splitlines()[1:]:
                fields=line.split()
                if int(fields[1].rsplit(":",1)[1],16)==port and fields[3]=="0A":return True
        return False
    except (OSError,ValueError,IndexError) as e:raise ControlError("Kernel port state is unknown: "+str(e))

def owns_port(pid, port):
    inodes=set()
    try:
        for line in Path("/proc/net/tcp").read_text().splitlines()[1:]:
            f=line.split()
            if f[1]==f"0100007F:{port:04X}" and f[3]=="0A":inodes.add(f[9])
        return any(p.is_symlink() and os.readlink(p) in {"socket:["+x+"]" for x in inodes}
                   for p in Path(f"/proc/{pid}/fd").iterdir())
    except OSError:return False

def request(port, path):
    opener=urllib.request.build_opener(urllib.request.ProxyHandler({}))
    with opener.open(f"http://127.0.0.1:{port}{path}",timeout=.5) as response:
        value=response.read(65537)
        if response.status!=200 or len(value)>65536:raise ControlError("Invalid native HTTP response")
        return value

class Controller:
    def __init__(self,c):
        known={"SchemaVersion","Distro","AppRoot","NativePython","HostEnvironmentSource","StateRoot","JobStateRoot",
               "OutputRoot","ScratchRoot","Port","EngineBuildTimeoutSeconds","StartupTimeoutSeconds","StopTimeoutSeconds",
               "LaunchBrowser","PruneCompletedJobs"}
        if set(c)-known:raise ControlError("Unknown native profile settings: "+", ".join(sorted(set(c)-known)))
        if c.get("SchemaVersion")!=1:raise ControlError("Unsupported native profile version")
        self.c=c
        self.app=Path(c["AppRoot"]).expanduser().resolve()
        self.state=Path(c["StateRoot"]).expanduser().absolute()
        self.native=Path(c["NativePython"]).expanduser().absolute()
        self.jobs=Path(c["JobStateRoot"]).expanduser().absolute()
        self.outputs=Path(c["OutputRoot"]).expanduser().absolute()
        self.scratch=Path(c["ScratchRoot"]).expanduser().absolute()
        self.port=int(c["Port"])
        if not 1024<=self.port<=65535 or self.port==8020:raise ControlError("Choose a native port distinct from Docker 8020")
        if self.state.is_symlink() or self.state in (Path.home(),Path("/"),self.app,Path.home()/".local/state/zipvoice"):
            raise ControlError("StateRoot must be a separate private native profile")
        if len(os.fsencode(str(self.state)))>72:raise ControlError("StateRoot is too long for native Unix sockets; choose a shorter path")
        if len({self.jobs,self.outputs,self.scratch,self.state,self.app})!=5:raise ControlError("Job, output and scratch roots must be separate")
        if not self.jobs.resolve().is_relative_to(self.state.resolve()):raise ControlError("JobStateRoot must be inside the separate native StateRoot")
        if self.outputs in (Path.home(),Path("/")) or self.scratch in (Path.home(),Path("/")):raise ControlError("Output and scratch roots must be specific private folders")
        if not (self.app/"zipvoice_gui.py").is_file() or not (self.app/"zipvoice_bootstrap.py").is_file():
            raise ControlError("AppRoot does not contain the qualified GUI and bootstrap")
        if not self.native.is_file() or not os.access(self.native,os.X_OK):raise ControlError("NativePython is not executable")
        for name,default in [("EngineBuildTimeoutSeconds",7200),("StopTimeoutSeconds",60)]:
            if isinstance(c.get(name,default),bool):raise ControlError(name+" must be a number")
            n=float(c.get(name,default))
            if not math.isfinite(n) or n<=0:raise ControlError(name+" must be positive and finite")
        self.state.mkdir(mode=0o700,parents=True,exist_ok=True);self.state.chmod(0o700)
        self.record=self.state/"control/native-gui.json"
        self.log=self.state/"control/native-gui.log"
        self.gui=self.app/"zipvoice_gui.py";self.bootstrap=self.app/"zipvoice_bootstrap.py";self._child=None

    def lock(self):
        p=self.state/"control/controller.lock";p.parent.mkdir(mode=0o700,parents=True,exist_ok=True)
        f=p.open("a+");os.chmod(p,0o600)
        try:fcntl.flock(f,fcntl.LOCK_EX|fcntl.LOCK_NB)
        except BlockingIOError:f.close();raise ControlError("Another native control operation is active")
        return f

    def load(self):
        if not self.record.exists():return None
        if self.record.is_symlink():raise ControlError("Ownership record may not be a link")
        return json.loads(self.record.read_text())

    def owned(self,r):
        if r.get("app_root")!=str(self.app) or r.get("state_root")!=str(self.state) or r.get("port")!=self.port:
            raise ControlError("Ownership record belongs to a different profile")
        # execve can expose command/executable fields from opposite sides of
        # the bootstrap transition. Reobserve read-only; never bless that
        # mixed snapshot and never treat an unreadable live PID as stopped.
        error=None
        for attempt in range(10):
            try:
                p=process(r["pid"])
                if p is None:return None
                if r.get("boot_id")!=boot() or p["token"]!=r.get("start_token"):
                    raise ControlError("Live PID identity does not match the native ownership record")
                if p["exe"]==r.get("python_exe") and p["argv"][1:] in (r["bootstrap_argv"][1:],r["gui_argv"][1:]):
                    return p
                error=ProcessUnknown("Live command/executable does not match the exact native AppRoot")
            except ProcessUnknown as e:error=e
            if attempt<9:time.sleep(.025)
        raise ProcessUnknown("Native process identity remains unproven after bounded observation") from error

    def adopt_host_cache(self):
        # Read-only validation; activation is performed only by the public bootstrap CLI.
        spec=importlib.util.spec_from_file_location("native_profile_bootstrap",self.bootstrap)
        module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
        expected=module.lock_packages(module.LOCK_PATH.read_text())
        fingerprint=module.lock_fingerprint(module.LOCK_PATH.read_text())
        target=self.state/"host-envs"/fingerprint
        if not target.exists():
            source=Path(self.c["HostEnvironmentSource"]).expanduser().resolve()
            valid,detail=module.validate_environment(source,expected)
            if not valid:raise ControlError("Existing host cache is invalid: "+detail)
            target.parent.mkdir(mode=0o700,parents=True,exist_ok=True)
            temporary=target.with_name(".adopt-"+uuid.uuid4().hex)
            import shutil
            shutil.copytree(source,temporary,symlinks=True)
            valid,detail=module.validate_environment(temporary,expected)
            if not valid:raise ControlError("Copied host cache is invalid; retained at "+str(temporary))
            os.replace(temporary,target)
        valid,detail=module.validate_environment(target,expected)
        if not valid:raise ControlError("Native host cache is invalid: "+detail)
        env=self.environment()
        p=subprocess.run([str(target/"bin/python"),"-B",str(self.bootstrap),"prepare","--json"],
                         env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=40)
        if p.returncode:raise ControlError("Public host preparation failed; inspect the native profile log")
        data=json.loads(p.stdout)
        if Path(data["environment"]).resolve()!=target.resolve():raise ControlError("Public bootstrap selected an unexpected host cache")
        return target/"bin/python"

    def environment(self):
        e=os.environ.copy()
        e.update(HF_HUB_OFFLINE="1",TRANSFORMERS_OFFLINE="1",PYTHONDONTWRITEBYTECODE="1",ZIPVOICE_RUNTIME_BACKEND="native-experimental",
                 ZIPVOICE_TRITON_TRANSPORT="native",ZIPVOICE_NATIVE_PYTHON=str(self.native),
                 ZIPVOICE_STATE_ROOT=str(self.state),ZIPVOICE_JOB_STATE_ROOT=str(self.jobs),
                 ZIPVOICE_OUTPUT_ROOT=str(self.outputs),ZIPVOICE_JOB_ROOT=str(self.scratch),VOICE_JOB_PRUNE_ENABLED="1" if self.c.get("PruneCompletedJobs",False) else "0",
                 ZIPVOICE_ENGINE_BUILD_TIMEOUT_SECONDS=str(self.c.get("EngineBuildTimeoutSeconds",7200)))
        return e

    def resources_open(self,r):
        live=[]
        for child in r.get("observed_children",[]):
            p=process(child["pid"])
            if p and p["token"]==child["token"]:live.append(child["pid"])
        sockets=[]
        for path in self.state.rglob("*.sock"):
            if path.is_symlink() or not stat.S_ISSOCK(path.stat().st_mode):continue
            s=socket.socket(socket.AF_UNIX);s.settimeout(.2)
            try:s.connect(str(path));sockets.append(str(path))
            except ConnectionRefusedError:pass
            except OSError as e:raise ControlError("Native socket state is unknown: "+str(e))
            finally:s.close()
        return {"tcp_open":tcp_open(self.port),"children_alive":live,"unix_sockets_open":sockets}

    def status(self):
        r=self.load()
        if self._child is not None:self._child.poll()
        if not r:
            if tcp_open(self.port):raise ControlError("Native port is occupied by an unmanaged service")
            return {"phase":"stopped","ready":False,"log":str(self.log)}
        p=self.owned(r)
        if not p:
            resources=self.resources_open(r)
            if any(resources.values()):return {"phase":"resources-outstanding","ready":False,"resources":resources}
            return {"phase":"stopped","ready":False,"log":str(self.log)}
        r["observed_children"]=list({(x["pid"],x["token"]):x for x in r.get("observed_children",[])+descendants(r["pid"])}.values());atomic(self.record,r)
        ready=False;reason="Waiting for the managed GUI and native runtime"
        if p["argv"][1:]==r["gui_argv"][1:] and owns_port(r["pid"],self.port):
            try:
                health=request(self.port,"/health")
                admitted=json.loads(request(self.port,"/ready"))
                version=json.loads(request(self.port,"/version"))
                ready=(health==b"ready" and admitted.get("ready") is True
                       and version.get("gui_source_hash")==r["gui_source_hash"]
                       and version.get("runtime_transport")=="native"
                       and version.get("runtime_backend")=="native-experimental")
                if not ready:reason="Public readiness or source/backend identity does not match"
            except Exception as e:reason="Native readiness is not yet proven: "+type(e).__name__
        return {"phase":"ready" if ready else "starting","ready":ready,"pid":r["pid"],
                "reason":None if ready else reason,"log":str(self.log),"gui_source_hash":r["gui_source_hash"],"url":f"http://127.0.0.1:{self.port}"}

    def start(self):
        existing=self.load()
        if existing and self.owned(existing):return self.status()
        if tcp_open(self.port):raise ControlError("Native port is already occupied; no process was started")
        if existing:os.replace(self.record,self.record.with_name("native-gui.stale-"+str(time.time_ns())+".json"))
        host=self.adopt_host_cache()
        self.jobs.mkdir(mode=0o700,parents=True,exist_ok=True);self.outputs.mkdir(mode=0o700,parents=True,exist_ok=True);self.scratch.mkdir(mode=0o700,parents=True,exist_ok=True)
        # Match the public GUI source_hash contract: filename followed by bytes.
        gui_hash=hashlib.sha256(self.gui.name.encode()+self.gui.read_bytes()).hexdigest()
        command=[str(host),"-B",str(self.bootstrap),"exec","--host","127.0.0.1","--port",str(self.port)]
        self.log.parent.mkdir(mode=0o700,parents=True,exist_ok=True)
        with self.log.open("ab") as log:
            child=subprocess.Popen(command,cwd=self.app,env=self.environment(),stdin=subprocess.DEVNULL,
                                   stdout=log,stderr=subprocess.STDOUT,start_new_session=True,close_fds=True)
        self._child=child
        p=process_stat(child.pid)
        if p is None:raise ControlError("Native GUI exited before ownership could be recorded; inspect "+str(self.log))
        r={"schema":1,"pid":child.pid,"start_token":p["token"],"boot_id":boot(),"app_root":str(self.app),
           "state_root":str(self.state),"port":self.port,"python_exe":str(host.resolve()),"bootstrap_argv":command,
           "gui_argv":["python3",str(self.gui),"--host","127.0.0.1","--port",str(self.port)],
           "gui_source_hash":gui_hash,"observed_children":[]}
        atomic(self.record,r);return self.status()

    def stop(self):
        r=self.load()
        if not r:return self.status()
        if self.owned(r):
            r["observed_children"]=list({(x["pid"],x["token"]):x for x in r.get("observed_children",[])+descendants(r["pid"])}.values());atomic(self.record,r)
            os.kill(r["pid"],signal.SIGTERM)
        deadline=time.monotonic()+float(self.c.get("StopTimeoutSeconds",60))
        while time.monotonic()<deadline:
            result=self.status()
            if result["phase"]=="stopped":return result
            time.sleep(.1)
        raise ControlError("Native stop deadline expired; ownership and resources retained for inspection")

def main():
    a=argparse.ArgumentParser();a.add_argument("--action",choices=["start","status","stop"],required=True);args=a.parse_args()
    try:
        os.environ["PYTHONDONTWRITEBYTECODE"]="1"
        control=Controller(json.load(sys.stdin))
        with control.lock():result=getattr(control,args.action)()
        print(json.dumps(result));return 0
    except Exception as e:
        print(json.dumps({"phase":"error","ready":False,"error":str(e)}));return 2

if __name__=="__main__":raise SystemExit(main())
