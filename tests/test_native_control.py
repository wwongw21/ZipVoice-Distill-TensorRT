import hashlib,http.server,importlib.util,json,os,socket,subprocess,sys,tempfile,time,unittest
from pathlib import Path
from unittest.mock import patch
MODULE=Path(__file__).resolve().parents[1]/"zipvoice_native_control.py"
spec=importlib.util.spec_from_file_location("native_control",MODULE);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
GUI=r'''
import argparse,hashlib,json,os,signal,subprocess,sys,time
from http.server import BaseHTTPRequestHandler,HTTPServer
from pathlib import Path
a=argparse.ArgumentParser();a.add_argument("--host");a.add_argument("--port",type=int);v=a.parse_args()
mode=os.environ.get("NATIVE_TEST_MODE","")
if mode=="fail":raise SystemExit(3)
if mode=="delay":time.sleep(4)
if mode=="ignore":signal.signal(signal.SIGTERM,signal.SIG_IGN)
if mode=="leak":subprocess.Popen([sys.executable,"-c","import time;time.sleep(60)"],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
class Handler(BaseHTTPRequestHandler):
 def log_message(self,*a):pass
 def do_GET(self):
  if self.path=="/health":body=b"ready"
  elif self.path=="/ready":body=json.dumps({"ready":True}).encode()
  else:body=json.dumps({"gui_source_hash":"wrong" if mode=="bad" else hashlib.sha256(Path(__file__).name.encode()+Path(__file__).read_bytes()).hexdigest(),"runtime_backend":"native-experimental","runtime_transport":"native"}).encode()
  self.send_response(200);self.end_headers();self.wfile.write(body)
HTTPServer((v.host,v.port),Handler).serve_forever()
'''
BOOTSTRAP=r'''
import os,sys
from pathlib import Path
assert sys.argv[1]=="exec"
os.execv(sys.executable,["python3",str(Path(__file__).with_name("zipvoice_gui.py")),*sys.argv[2:]])
'''
class ControlTests(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory(prefix="zvn-test-");self.root=Path(self.tmp.name)
  app=self.root/"app space's";app.mkdir();(app/"zipvoice_gui.py").write_text(GUI);(app/"zipvoice_bootstrap.py").write_text(BOOTSTRAP)
  with socket.socket() as s:s.bind(("127.0.0.1",0));port=s.getsockname()[1]
  self.cfg={"SchemaVersion":1,"Distro":"Ubuntu-24.04","AppRoot":str(app),"NativePython":sys.executable,"HostEnvironmentSource":str(self.root/"old-host"),
   "StateRoot":str(self.root/"state"),"JobStateRoot":str(self.root/"state/jobs"),"OutputRoot":str(self.root/"output"),"ScratchRoot":str(self.root/"scratch"),"Port":port,
   "EngineBuildTimeoutSeconds":7200,"StartupTimeoutSeconds":7500,"StopTimeoutSeconds":2,"LaunchBrowser":False,"PruneCompletedJobs":False}
  self.c=m.Controller(self.cfg);self.owned=[]
 def tearDown(self):
  r=self.c.load()
  if r:
   self.owned += [{"pid":r["pid"],"token":r["start_token"]}]+r.get("observed_children",[])
  for x in self.owned:
   p=m.process_stat(x["pid"])
   if p and p["token"]==x["token"]:
    os.kill(x["pid"],9)
   try:os.waitpid(x["pid"],0)
   except ChildProcessError:pass
  if self.c._child is not None:self.c._child.poll()
  self.tmp.cleanup()
 def start(self,mode=""):
  with patch.dict(os.environ,{"NATIVE_TEST_MODE":mode}),patch.object(self.c,"adopt_host_cache",return_value=Path(sys.executable)):
   return self.c.start()
 def ready(self):
  end=time.monotonic()+8
  while time.monotonic()<end:
   r=self.c.status()
   if r["ready"]:return r
   if r["phase"]=="stopped":self.fail("Owned fixture exited: "+self.c.log.read_text()[-1000:])
   time.sleep(.03)
  self.fail("Owned test GUI did not become ready: "+repr(r)+" "+self.c.log.read_text()[-1000:])
 def test_real_start_ready_stop_and_idempotency(self):
  self.start();r=self.ready();pid=r["pid"]
  self.assertEqual(self.start()["pid"],pid);self.assertTrue(m.owns_port(pid,self.cfg["Port"]))
  self.assertEqual(self.c.stop()["phase"],"stopped");self.assertEqual(self.c.stop()["phase"],"stopped")
 def test_stop_while_starting(self):
  self.start("delay");self.assertEqual(self.c.status()["phase"],"starting");self.assertEqual(self.c.stop()["phase"],"stopped")
 def test_health_cannot_override_wrong_source_identity(self):
  self.start("bad");time.sleep(.25);self.assertFalse(self.c.status()["ready"]);self.assertEqual(self.c.stop()["phase"],"stopped")
 def test_pid_token_mismatch_does_not_signal_process(self):
  self.start();self.ready();r=self.c.load();r["start_token"]="wrong";m.atomic(self.c.record,r)
  with self.assertRaises(m.ControlError):self.c.stop()
  self.assertIsNotNone(m.process(r["pid"]));r["start_token"]=m.process(r["pid"])["token"];m.atomic(self.c.record,r)
 def test_boot_identity_mismatch_does_not_signal_process(self):
  self.start();self.ready();r=self.c.load();saved=r["boot_id"];r["boot_id"]="wrong";m.atomic(self.c.record,r)
  with self.assertRaises(m.ControlError):self.c.stop()
  self.assertIsNotNone(m.process(r["pid"]));r["boot_id"]=saved;m.atomic(self.c.record,r)
 def test_wrong_approot_record_does_not_signal_process(self):
  self.start();self.ready();r=self.c.load();saved=r["app_root"];r["app_root"]="/different";m.atomic(self.c.record,r)
  with self.assertRaises(m.ControlError):self.c.stop()
  self.assertIsNotNone(m.process(r["pid"]));r["app_root"]=saved;m.atomic(self.c.record,r)
 def test_unmanaged_port_is_not_adopted_or_stopped(self):
  server=http.server.HTTPServer(("127.0.0.1",self.cfg["Port"]),http.server.BaseHTTPRequestHandler)
  try:
   with patch.object(self.c,"adopt_host_cache") as a:
    with self.assertRaises(m.ControlError):self.c.start()
    a.assert_not_called()
   with self.assertRaises(m.ControlError):self.c.stop()
   self.assertTrue(m.tcp_open(self.cfg["Port"]))
  finally:server.server_close()
 def test_ignore_signal_does_not_false_report_stopped(self):
  self.start("ignore");self.ready();self.c.c["StopTimeoutSeconds"]=.2
  with self.assertRaises(m.ControlError):self.c.stop()
  self.assertIsNotNone(m.process(self.c.load()["pid"]))
 def test_leftover_owned_child_prevents_false_stopped(self):
  self.start("leak");self.ready();self.c.c["StopTimeoutSeconds"]=.2
  with self.assertRaises(m.ControlError):self.c.stop()
  self.assertEqual(self.c.status()["phase"],"resources-outstanding")
 def test_exec_transition_is_reobserved_without_accepting_unknown_command(self):
  self.start("delay");r=self.c.load();good=m.process(r["pid"])
  bad=dict(good);bad["argv"]=["python3","/transient/exec-window"]
  with patch.object(m,"process",side_effect=[bad,good]) as inspect,patch.object(m.time,"sleep"):
   self.assertEqual(self.c.owned(r),good)
   self.assertEqual(inspect.call_count,2)
  self.assertEqual(self.c.stop()["phase"],"stopped")
 def test_unreadable_stat_is_unknown_not_stopped(self):
  with patch.object(m.Path,"read_text",side_effect=PermissionError("probe denied")):
   with self.assertRaises(m.ControlError):m.process(os.getpid())
 def test_unreadable_command_is_unknown_not_stopped(self):
  with patch.object(m.Path,"read_bytes",side_effect=PermissionError("probe denied")):
   with self.assertRaises(m.ControlError):m.process(os.getpid())
 def test_persistent_unknown_identity_never_signals_or_reports_stopped(self):
  self.start();self.ready()
  with patch.object(m,"process",side_effect=m.ProcessUnknown("unreadable")),patch.object(m.time,"sleep"),patch.object(m.os,"kill") as send:
   with self.assertRaises(m.ProcessUnknown):self.c.stop()
   send.assert_not_called()
 def test_confirmed_process_absence_is_stopped(self):
  with patch.object(m.Path,"read_text",side_effect=FileNotFoundError()):
   self.assertIsNone(m.process(os.getpid()))
 def test_descendants_do_not_read_unrelated_commands_or_executables(self):
  values={101:{"token":"parent","ppid":1},102:{"token":"child","ppid":101},103:{"token":"other","ppid":1}}
  with patch.object(m.Path,"iterdir",return_value=[Path("/proc/101"),Path("/proc/102"),Path("/proc/103")]),patch.object(m,"process_stat",side_effect=lambda pid:values[pid]),patch.object(m,"process",side_effect=AssertionError("full identity must not be read")):
   self.assertEqual(m.descendants(101),[{"pid":102,"token":"child"}])
 def test_recorded_child_unknown_cannot_be_reported_closed(self):
  with patch.object(m,"process_stat",side_effect=m.ProcessUnknown("child stat unreadable")):
   with self.assertRaises(m.ProcessUnknown):self.c.resources_open({"observed_children":[{"pid":123,"token":"owned"}]})
 def test_public_gui_hash_includes_filename_before_bytes(self):
  self.start("delay");r=self.c.load()
  expected=hashlib.sha256(self.c.gui.name.encode()+self.c.gui.read_bytes()).hexdigest()
  self.assertEqual(r["gui_source_hash"],expected)
  self.assertNotEqual(expected,hashlib.sha256(self.c.gui.read_bytes()).hexdigest())
 def test_config_paths_and_deadlines_are_validated(self):
  for key,value in [("StateRoot","/tmp/"+("x"*80)),("Port",8020),("EngineBuildTimeoutSeconds",float("inf")),("StopTimeoutSeconds",True),("JobStateRoot",str(self.root/"foreignjobs")),("ScratchRoot","/")]:
   c=dict(self.cfg);c[key]=value
   with self.assertRaises(m.ControlError,msg=key):m.Controller(c)
 def test_native_environment_is_separate_and_explicit(self):
  e=self.c.environment()
  self.assertEqual(e["ZIPVOICE_RUNTIME_BACKEND"],"native-experimental")
  self.assertEqual(e["ZIPVOICE_STATE_ROOT"],self.cfg["StateRoot"])
  self.assertEqual(e["ZIPVOICE_JOB_ROOT"],self.cfg["ScratchRoot"])
  self.assertEqual(e["ZIPVOICE_JOB_STATE_ROOT"],self.cfg["JobStateRoot"])
  self.assertEqual(e["ZIPVOICE_OUTPUT_ROOT"],self.cfg["OutputRoot"])
  self.assertEqual(e["ZIPVOICE_ENGINE_BUILD_TIMEOUT_SECONDS"],"7200")
  self.assertEqual(e["VOICE_JOB_PRUNE_ENABLED"],"0")
if __name__=="__main__":unittest.main(verbosity=2)
