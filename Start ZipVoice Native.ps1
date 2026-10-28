param(
    [ValidateSet('Start','Status','Stop')][string]$Action = 'Start',
    [string]$ConfigPath = (Join-Path $env:LOCALAPPDATA 'ZipVoiceNative\config.json'),
    [switch]$NoBrowser
)
$ErrorActionPreference = 'Stop'
function ConvertTo-NativeArgument {
    param([AllowEmptyString()][string]$Argument)
    if ($Argument.Length -gt 0 -and $Argument -notmatch '[\s"]') { return $Argument }
    $escaped = [regex]::Replace($Argument, '(\\*)"', '$1$1\"')
    return '"' + [regex]::Replace($escaped, '(\\+)$', '$1$1') + '"'
}
function Invoke-OwnedNative {
    param([string]$FilePath,[string[]]$Arguments,[string]$InputText='',[int]$TimeoutMilliseconds=30000)
    if ($TimeoutMilliseconds -le 0) { throw 'Native command deadline expired' }
    $p = New-Object Diagnostics.Process
    $p.StartInfo.FileName = (Get-Command $FilePath -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
    $p.StartInfo.Arguments = (@($Arguments | ForEach-Object { ConvertTo-NativeArgument $_ }) -join ' ')
    $p.StartInfo.UseShellExecute = $false
    $p.StartInfo.CreateNoWindow = $true
    $p.StartInfo.RedirectStandardOutput = $true
    $p.StartInfo.RedirectStandardError = $true
    $p.StartInfo.RedirectStandardInput = $true
    try {
        if (-not $p.Start()) { throw 'Could not start native controller command' }
        $output = $p.StandardOutput.ReadToEndAsync()
        $errorOutput = $p.StandardError.ReadToEndAsync()
        $p.StandardInput.Write($InputText)
        $p.StandardInput.Close()
        if (-not $p.WaitForExit($TimeoutMilliseconds)) {
            $p.Kill()
            throw "Native controller command timed out; inspect Status before retrying"
        }
        if (-not $output.Wait(3000) -or -not $errorOutput.Wait(3000)) { throw 'Native command output did not close' }
        return [pscustomobject]@{ ExitCode=$p.ExitCode; Output=$output.Result; Error=$errorOutput.Result.Replace([string][char]0,'') }
    } finally { $p.Dispose() }
}
function Read-NativeProfile {
    param([string]$Path,[string]$Template)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null
        Copy-Item -LiteralPath $Template -Destination $Path -ErrorAction Stop
        Write-Host "Created the separate native profile: $Path"
    }
    $c = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    if ($c.Distro -notmatch '^[A-Za-z0-9][A-Za-z0-9_.-]{0,63}$') { throw 'Invalid WSL distribution name' }
    foreach ($name in @('EngineBuildTimeoutSeconds','StartupTimeoutSeconds','StopTimeoutSeconds')) {
        $v = [double]$c.$name
        if ([double]::IsNaN($v) -or [double]::IsInfinity($v) -or $v -le 0) { throw "$name must be positive and finite" }
    }
    if ([double]$c.StartupTimeoutSeconds -lt ([double]$c.EngineBuildTimeoutSeconds + 480)) {
        throw 'StartupTimeoutSeconds must include at least 480 seconds beyond the engine-build deadline'
    }
    return $c
}
function Invoke-NativeControl {
    param($Profile,[string]$Helper,[string]$ControlAction)
    $limit = if ($ControlAction -eq 'Stop') { ([int]$Profile.StopTimeoutSeconds + 60) * 1000 } else { 120000 }
    $r = Invoke-OwnedNative 'wsl.exe' @('-d',[string]$Profile.Distro,'--exec','python3','-B',$Helper,'--action',$ControlAction.ToLowerInvariant()) ($Profile | ConvertTo-Json -Depth 8 -Compress) $limit
    try { $value = $r.Output | ConvertFrom-Json } catch { throw "Native control did not return valid JSON: $($r.Error)" }
    if ($r.ExitCode -ne 0 -or $value.phase -eq 'error') { throw "Native control: $($value.error)" }
    return $value
}
function Test-WindowsNativeReady {
    param([int]$Port,[string]$ExpectedSourceHash)
    try {
        $values=@{}
        foreach($path in @('/health','/ready','/version')){
            $request=[Net.WebRequest]::Create("http://127.0.0.1:$Port$path")
            $request.Proxy=$null;$request.Timeout=1500;$request.ReadWriteTimeout=1500
            $response=$null;$reader=$null
            try{
                $response=$request.GetResponse()
                $reader=New-Object IO.StreamReader($response.GetResponseStream())
                $values[$path]=$reader.ReadToEnd()
            }finally{if($reader){$reader.Dispose()};if($response){$response.Dispose()}}
        }
        $ready=$values['/ready'] | ConvertFrom-Json
        $version=$values['/version'] | ConvertFrom-Json
        return ($values['/health'] -ceq 'ready' -and $ready.ready -eq $true -and $version.gui_source_hash -ceq $ExpectedSourceHash -and $version.runtime_transport -eq 'native' -and $version.runtime_backend -eq 'native-experimental')
    }catch{return $false}
}
function Open-NativeWindow {
    param([int]$Port)
    $edge = @((Join-Path ([Environment]::GetEnvironmentVariable('ProgramFiles(x86)')) 'Microsoft\Edge\Application\msedge.exe'),(Join-Path $env:ProgramFiles 'Microsoft\Edge\Application\msedge.exe')) |
        Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $edge) { throw "Native backend is ready, but Edge is unavailable. Open http://127.0.0.1:$Port manually." }
    $profile = Join-Path $env:LOCALAPPDATA 'ZipVoiceNative\EdgeProfile'
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = $edge
    $info.UseShellExecute = $true
    $info.CreateNoWindow = $true
    $info.Arguments = (@("--app=http://127.0.0.1:$Port","--user-data-dir=$profile",'--no-first-run') | ForEach-Object { ConvertTo-NativeArgument $_ }) -join ' '
    $opened = [Diagnostics.Process]::Start($info)
    if ($opened) { $opened.Dispose() }
}
function Invoke-NativeMain {
    $c = Read-NativeProfile $ConfigPath (Join-Path $PSScriptRoot 'NativeConfig.example.json')
    $mapped = Invoke-OwnedNative 'wsl.exe' @('-d',[string]$c.Distro,'--exec','wslpath','-a','-u',(Join-Path $PSScriptRoot 'zipvoice_native_control.py')) '' 30000
    if ($mapped.ExitCode -ne 0 -or -not $mapped.Output.Trim()) { throw "Could not locate the native control helper in WSL: $($mapped.Error)" }
    $helper = $mapped.Output.Trim()
    if ($Action -ne 'Start') {
        $r = Invoke-NativeControl $c $helper $Action
        Write-Host ("Native {0}: {1}" -f $Action.ToLowerInvariant(),$r.phase)
        if ($Action -eq 'Stop' -and $r.phase -ne 'stopped') { throw 'The native profile still has outstanding resources' }
        return
    }
    Write-Host 'Starting ZipVoice Native (Experimental). Docker and its launcher are unchanged.'
    Write-Host 'Cold engine preparation can take time. Use Stop ZipVoice Native.cmd to cancel safely.'
    $clock = [Diagnostics.Stopwatch]::StartNew()
    $ready = $false
    try {
        $r = Invoke-NativeControl $c $helper 'Start'
        $lastNotice = -10
        while ($clock.Elapsed.TotalSeconds -lt [double]$c.StartupTimeoutSeconds) {
            if ($r.ready) {
                if (Test-WindowsNativeReady ([int]$c.Port) ([string]$r.gui_source_hash)) { $ready=$true; break }
                $r.reason='Linux is ready; waiting for the matching Windows loopback endpoint'
            }
            if ($r.phase -in @('stopped','resources-outstanding')) { throw "Native startup ended: $($r.phase). Inspect $($r.log)." }
            if (($clock.Elapsed.TotalSeconds - $lastNotice) -ge 10) {
                Write-Host ("Native startup: {0}; elapsed {1:n0}s. {2}" -f $r.phase,$clock.Elapsed.TotalSeconds,$r.reason)
                $lastNotice=$clock.Elapsed.TotalSeconds
            }
            Start-Sleep -Milliseconds 1500
            $r = Invoke-NativeControl $c $helper 'Status'
        }
        if (-not $ready) { throw 'Native startup deadline expired' }
    } catch {
        $failure = $_
        try { Invoke-NativeControl $c $helper 'Stop' | Out-Null } catch { Write-Warning "Native cleanup needs attention: $_" }
        throw $failure
    }
    Write-Host "Native backend is ready at http://127.0.0.1:$($c.Port)"
    if (-not $NoBrowser -and $c.LaunchBrowser) { Open-NativeWindow ([int]$c.Port) }
}
if ($MyInvocation.InvocationName -ne '.') {
    try { Invoke-NativeMain; exit 0 } catch { Write-Error $_; exit 1 }
}
