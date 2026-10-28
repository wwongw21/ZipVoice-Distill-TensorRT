param([switch]$SelfCheck, [switch]$StopOnly)

$ErrorActionPreference = "Stop"
$Name = "ZipVoice"
$Url = "http://127.0.0.1:8020"
$EdgeProfile = Join-Path $env:LOCALAPPDATA "ZipVoice\EdgeProfile"
$ProcessPattern = "^python3 /home/william/tts/ZipVoice/zipvoice_gui[.]py$"
$Edge = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
$IconPath = Join-Path $PSScriptRoot 'assets\zipvoice.ico'

function Get-HttpStatus {
    param([string]$Target, [int]$TimeoutMilliseconds = 1000)
    $request = $null
    $response = $null
    $pending = $null
    try {
        if ($TimeoutMilliseconds -le 0) { return 0 }
        $request = [Net.WebRequest]::Create($Target)
        $request.Proxy = $null
        $pending = $request.BeginGetResponse($null, $null)
        if (-not $pending.AsyncWaitHandle.WaitOne($TimeoutMilliseconds)) { return 0 }
        $response = $request.EndGetResponse($pending)
        return [int]$response.StatusCode
    } catch {
        $response = $_.Exception.Response
        if ($response -and $response.StatusCode) {
            try { return [int]$response.StatusCode } catch { return 0 }
        }
        return 0
    } finally {
        if ($response) { $response.Dispose() }
        if ($request) { $request.Abort() }
        if ($pending) { $pending.AsyncWaitHandle.Close() }
    }
}

function Test-ServiceHealth {
    return (Get-HttpStatus "$Url/health") -eq 200
}

function Test-ServiceReady {
    return (Get-HttpStatus "http://127.0.0.1:8010/v2/health/ready") -eq 200
}

function Invoke-NativeQuiet {
    param([string]$FilePath, [string[]]$ArgumentList, [int]$TimeoutMilliseconds = 3000, [switch]$CaptureOutput)
    if ($TimeoutMilliseconds -le 0) { throw "Native probe deadline expired" }
    $clock = [Diagnostics.Stopwatch]::StartNew()
    $FilePath = @(Get-Command $FilePath -CommandType Application -ErrorAction Stop)[0].Source
    $process = [Diagnostics.Process]::new()
    $process.StartInfo.FileName = $FilePath
    $process.StartInfo.Arguments = (@($ArgumentList | ForEach-Object { ConvertTo-NativeArgument $_ }) -join ' ')
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.CreateNoWindow = $true
    $process.StartInfo.RedirectStandardOutput = $true
    $process.StartInfo.RedirectStandardError = $true
    try {
        if (-not $process.Start()) { throw "Could not start native probe" }
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        $remaining = [Math]::Max(0, $TimeoutMilliseconds - [int]$clock.ElapsedMilliseconds)
        if (-not $process.WaitForExit($remaining)) {
            $process.Kill()
            throw "Native probe timed out after $TimeoutMilliseconds milliseconds"
        }
        if ($CaptureOutput) {
            $remaining = [Math]::Max(0, $TimeoutMilliseconds - [int]$clock.ElapsedMilliseconds)
            if (-not $stdout.Wait($remaining)) { throw 'Native probe output deadline expired' }
            return [pscustomobject]@{ ExitCode = $process.ExitCode; Output = $stdout.Result }
        }
        return $process.ExitCode
    } finally {
        $process.Dispose()
        $clock.Stop()
    }
}

function ConvertTo-NativeArgument {
    param([string]$Argument)
    if ($Argument.Length -gt 0 -and $Argument -notmatch '[\s"]') { return $Argument }
    # Windows command-line quoting: double backslashes before quotes and at the end.
    $escaped = [regex]::Replace($Argument, '(\\*)"', '$1$1\"')
    return '"' + [regex]::Replace($escaped, '(\\+)$', '$1$1') + '"'
}

function Convert-PgrepExitCodeToState {
    param([int]$ExitCode)
    if ($ExitCode -eq 0) { return "Running" }
    if ($ExitCode -eq 1) { return "NotFound" }
    return "InfrastructureError"
}

function Get-GuiProcessState {
    param([int]$TimeoutMilliseconds = 3000)
    try {
        $exitCode = Invoke-NativeQuiet "wsl.exe" @(
            "-d", "Ubuntu-24.04", "--", "pgrep", "-f", $ProcessPattern
        ) -TimeoutMilliseconds $TimeoutMilliseconds
    } catch {
        return "InfrastructureError"
    }
    return Convert-PgrepExitCodeToState $exitCode
}

function Test-GuiProcess {
    param([int]$TimeoutMilliseconds = 3000)
    $state = Get-GuiProcessState -TimeoutMilliseconds $TimeoutMilliseconds
    if ($state -eq "InfrastructureError") {
        throw "Could not inspect the managed $Name GUI process in Ubuntu-24.04"
    }
    return $state -eq "Running"
}

function Test-ConnectOutcomeClosed {
    param([ValidateSet("Connected", "Refused", "TimedOut", "Error")][string]$Outcome)
    return $Outcome -eq "Refused"
}

function Get-ConnectOutcome {
    param($Client, $Task, [int]$TimeoutMilliseconds)
    try {
        if (-not $Task.IsCompleted -and
            ($TimeoutMilliseconds -le 0 -or -not $Task.Wait($TimeoutMilliseconds))) { return "TimedOut" }
        $Task.GetAwaiter().GetResult() | Out-Null
        if ($Client.Connected) { return "Connected" }
        return "Error"
    } catch {
        $exception = $_.Exception
        while ($exception.InnerException) { $exception = $exception.InnerException }
        if ($exception -is [Net.Sockets.SocketException] -and
            $exception.SocketErrorCode -eq [Net.Sockets.SocketError]::ConnectionRefused) {
            return "Refused"
        }
        return "Error"
    }
}

function Get-UnclosedPorts {
    param([int[]]$Ports, [int]$TimeoutMilliseconds = 3000)
    $probes = @()
    $clock = [Diagnostics.Stopwatch]::StartNew()
    try {
        # Start all connections before waiting; share one budget across all ports.
        foreach ($port in $Ports) {
            $client = [Net.Sockets.TcpClient]::new()
            $probe = [pscustomobject]@{ Port = $port; Client = $client; Task = $null }
            $probes += $probe
            try { $probe.Task = $client.ConnectAsync("127.0.0.1", $port) } catch { }
        }
        foreach ($probe in $probes) {
            $remaining = [Math]::Max(0, $TimeoutMilliseconds - [int]$clock.ElapsedMilliseconds)
            $outcome = if ($probe.Task) {
                Get-ConnectOutcome $probe.Client $probe.Task $remaining
            } else { "Error" }
            if (-not (Test-ConnectOutcomeClosed $outcome)) { $probe.Port }
        }
    } finally {
        foreach ($probe in $probes) { $probe.Client.Dispose() }
        $clock.Stop()
    }
}

function Test-OwnershipRecordGone {
    param([int]$TimeoutMilliseconds = 3000)
    $exitCode = Invoke-NativeQuiet "wsl.exe" @(
        "-d", "Ubuntu-24.04", "--", "test", "!", "-e",
        "/home/william/.local/state/zipvoice/runtime-ownership.json"
    ) -TimeoutMilliseconds $TimeoutMilliseconds
    if ($exitCode -notin @(0, 1)) { throw "Could not inspect the ZipVoice ownership record" }
    return $exitCode -eq 0
}

function Close-ManagedEdge {
    param([int]$TimeoutMilliseconds = 3000)
    # Run CIM enumeration in a bounded helper; this also bounds provider stalls.
    $edgeCommand = '$ErrorActionPreference = "Stop"; ' +
        'Get-CimInstance Win32_Process -Filter "Name=''msedge.exe''" -ErrorAction Stop | ' +
        'Select-Object ProcessId,CommandLine | ConvertTo-Json -Compress'
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($edgeCommand))
    $clock = [Diagnostics.Stopwatch]::StartNew()
    try {
        $result = Invoke-NativeQuiet 'powershell.exe' @('-NoProfile', '-EncodedCommand', $encoded) $TimeoutMilliseconds -CaptureOutput
        if ($result.ExitCode -ne 0) { throw 'Could not inspect managed Edge processes' }
        $output = $result.Output
        $edgeProcesses = if ([string]::IsNullOrWhiteSpace($output)) { @() } else { @($output | ConvertFrom-Json) }
        $edgeProcesses |
        Where-Object { Test-ManagedEdgeCommandLine $_.CommandLine } |
        ForEach-Object {
            if ($clock.ElapsedMilliseconds -ge $TimeoutMilliseconds) { throw 'Managed Edge shutdown deadline expired' }
            Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
        }
    } finally {
        $clock.Stop()
    }
}

function Get-ManagedWindow {
    foreach ($info in Get-CimInstance Win32_Process -Filter "Name='msedge.exe'" -ErrorAction SilentlyContinue) {
        if (-not (Test-ManagedEdgeCommandLine $info.CommandLine)) { continue }
        $process = Get-Process -Id $info.ProcessId -ErrorAction SilentlyContinue
        if ($process.MainWindowHandle -ne 0) { return $process }
    }
    return $null
}

function Get-NormalizedPath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    try {
        return [IO.Path]::GetFullPath($Path).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    } catch {
        return $null
    }
}

function Test-ManagedEdgeCommandLine {
    param([string]$CommandLine)
    if ([string]::IsNullOrWhiteSpace($CommandLine)) { return $false }
    $matches = [regex]::Matches(
        $CommandLine,
        '(?i)(?:^|\s)(?:"--user-data-dir=(?<wholeQuoted>[^"]*)"|--user-data-dir=(?:"(?<quoted>[^"]*)"|(?<bare>\S+)))(?=\s|$)'
    )
    if ($matches.Count -ne 1) { return $false }
    $match = $matches[0]
    $candidate = if ($match.Groups['wholeQuoted'].Success) {
        $match.Groups['wholeQuoted'].Value
    } elseif ($match.Groups['quoted'].Success) {
        $match.Groups['quoted'].Value
    } else {
        $match.Groups['bare'].Value
    }
    $expectedPath = Get-NormalizedPath $EdgeProfile
    $candidatePath = Get-NormalizedPath $candidate
    return $null -ne $candidatePath -and $candidatePath.Equals(
        $expectedPath,
        [StringComparison]::OrdinalIgnoreCase
    )
}

function Open-ServiceWindow {
    $window = Get-ManagedWindow
    if ($window) {
        $shell = New-Object -ComObject WScript.Shell
        if (-not $shell.AppActivate($window.Id)) { throw "Could not activate the $Name window" }
        return
    }
    if (-not (Test-Path -LiteralPath $Edge)) { throw "Microsoft Edge not found at $Edge" }
    New-Item -ItemType Directory -Force -Path $EdgeProfile | Out-Null
    Start-Process -FilePath $Edge -ArgumentList @(
        "--app=$Url",
        (ConvertTo-NativeArgument "--user-data-dir=$EdgeProfile"),
        "--no-first-run"
    )
}

function Stop-Service {
    param([int]$TimeoutMilliseconds = 30000)
    if ($script:ShutdownInProgress) { return }
    $script:ShutdownInProgress = $true
    $clock = [System.Diagnostics.Stopwatch]::StartNew()
    $guiGone = $false
    $healthGone = $false
    $readyGone = $false
    $openPorts = @(8010, 8011, 8012, 8020)
    $ownershipGone = $false
    try {
        $signalExit = Invoke-NativeQuiet "wsl.exe" @(
            "-d", "Ubuntu-24.04", "--", "pkill", "-INT", "-f", $ProcessPattern
        ) -TimeoutMilliseconds (Get-ProbeBudget $clock $TimeoutMilliseconds 3000)
        if ($signalExit -notin @(0, 1)) { throw "Could not signal the managed ZipVoice GUI" }
        Close-ManagedEdge -TimeoutMilliseconds (Get-ProbeBudget $clock $TimeoutMilliseconds 3000)
        while ($clock.ElapsedMilliseconds -lt $TimeoutMilliseconds) {
            $guiGone = -not (Test-GuiProcess -TimeoutMilliseconds (Get-ProbeBudget $clock $TimeoutMilliseconds 3000))
            $healthGone = (Get-HttpStatus "$Url/health" (Get-ProbeBudget $clock $TimeoutMilliseconds 1000)) -eq 0
            $readyGone = (Get-HttpStatus "http://127.0.0.1:8010/v2/health/ready" (Get-ProbeBudget $clock $TimeoutMilliseconds 1000)) -eq 0
            $openPorts = @(Get-UnclosedPorts @(8010, 8011, 8012, 8020) (Get-ProbeBudget $clock $TimeoutMilliseconds 3000))
            $portsGone = $openPorts.Count -eq 0
            $ownershipGone = Test-OwnershipRecordGone -TimeoutMilliseconds (Get-ProbeBudget $clock $TimeoutMilliseconds 3000)
            if ($guiGone -and $healthGone -and $readyGone -and $portsGone -and $ownershipGone) {
                Get-ProbeBudget $clock $TimeoutMilliseconds 1 | Out-Null
                return
            }
            Start-Sleep -Milliseconds (Get-ProbeBudget $clock $TimeoutMilliseconds 250)
        }
        $remaining = @()
        if (-not $guiGone) { $remaining += "gui-process" }
        if (-not $healthGone) { $remaining += "/health" }
        if (-not $readyGone) { $remaining += "/ready" }
        foreach ($port in $openPorts) { $remaining += "port-$port" }
        if (-not $ownershipGone) { $remaining += "ownership-record" }
        throw "$Name shutdown exceeded the single 30-second deadline; remaining: $($remaining -join ', ')"
    } finally {
        $clock.Stop()
        $script:ShutdownInProgress = $false
    }
}

function Get-ProbeBudget {
    param($Clock, [int]$DeadlineMilliseconds, [int]$MaximumMilliseconds)
    $remaining = $DeadlineMilliseconds - [int]$Clock.ElapsedMilliseconds
    if ($remaining -le 0) { throw "ZipVoice shutdown deadline expired" }
    return [Math]::Min($remaining, $MaximumMilliseconds)
}

function Should-ExitMonitor {
    param(
        [bool]$SeenRunning,
        [bool]$StopRequested,
        [bool]$Running,
        [bool]$StartupExpired,
        [bool]$ShutdownFailed = $false,
        [bool]$EndpointResponding = $false
    )
    return (-not $ShutdownFailed) -and (-not $Running) -and (-not $EndpointResponding) -and (
        $SeenRunning -or $StopRequested -or $StartupExpired
    )
}

function Get-TrayState {
    param([bool]$Health, [bool]$Ready, [bool]$Stopping, [bool]$Starting, [bool]$StartupExpired)
    if ($Stopping) { return "Stopping" }
    if ($Health -and $Ready) { return "Running" }
    if ($Health -or $StartupExpired) { return "Needs attention" }
    if ($Starting) { return "Starting" }
    return "Needs attention"
}

function Get-MonitorState {
    param([bool]$GuiRunning, [bool]$Health, [bool]$Ready, [bool]$Stopping, [bool]$Starting, [bool]$StartupExpired)
    if ($Stopping) { return "Stopping" }
    if (-not $GuiRunning -and ($Health -or $Ready)) { return "Needs attention" }
    return Get-TrayState $Health $Ready $Stopping $Starting $StartupExpired
}

if ($SelfCheck) {
    if ((Invoke-NativeQuiet $env:ComSpec @(
        "/d", "/c", "echo warning 1>&2 & exit /b 7"
    )) -ne 7) { throw "native stderr must preserve the exit code" }
    if (-not (Should-ExitMonitor $true $false $false $false)) { throw "stopped service must exit" }
    if (Should-ExitMonitor $false $false $false $false) { throw "starting service exited early" }
    if (Should-ExitMonitor $true $false $true $true) { throw "running service exited" }
    if ((Get-TrayState $false $false $false $true $false) -ne "Starting") { throw "starting service must show Starting" }
    if ((Get-TrayState $true $true $false $false $false) -ne "Running") { throw "ready service must show Running" }
    if ((Get-TrayState $true $false $false $false $false) -ne "Needs attention") { throw "live but unready service must need attention" }
    if ((Get-TrayState $true $true $true $false $false) -ne "Stopping") { throw "shutdown must show Stopping" }
    if ((Get-TrayState $false $false $false $false $true) -ne "Needs attention") { throw "expired startup must need attention" }
    if ((Get-MonitorState $false $true $false $false $false $false) -ne "Needs attention") { throw "health without the managed GUI process must need attention" }
    if ((Get-MonitorState $false $false $true $false $false $false) -ne "Needs attention") { throw "readiness without the managed GUI process must need attention" }
    if ((Get-MonitorState $false $true $true $true $false $false) -ne "Stopping") { throw "stopping state must take priority while endpoints respond" }
    if ((Get-MonitorState $true $true $true $false $false $false) -ne "Running") { throw "healthy managed GUI process must show Running" }
    if (-not (Should-ExitMonitor $false $false $false $true)) { throw "backend-only startup must not bypass expiry" }
    if (Should-ExitMonitor $true $false $false $false $true) { throw "failed shutdown must keep the tray open for retry" }
    if (Should-ExitMonitor $true $false $false $false $false $true) { throw "a responding endpoint must keep the tray available for attention and shutdown" }
    if ((Convert-PgrepExitCodeToState 0) -ne "Running") { throw "pgrep exit 0 must mean running" }
    if ((Convert-PgrepExitCodeToState 1) -ne "NotFound") { throw "pgrep exit 1 must mean not found" }
    if ((Convert-PgrepExitCodeToState 2) -ne "InfrastructureError") { throw "pgrep exit 2 must mean infrastructure error" }
    if ((Convert-PgrepExitCodeToState -1) -ne "InfrastructureError") { throw "negative exit codes must mean infrastructure error" }
    if (-not (Test-ConnectOutcomeClosed "Refused")) { throw "a refused connection must count as closed" }
    if (Test-ConnectOutcomeClosed "TimedOut") { throw "a timed-out connection must not count as closed" }
    if (Test-ConnectOutcomeClosed "Error") { throw "an indeterminate connection must not count as closed" }
    $profileWithDot = Join-Path $EdgeProfile "."
    if (-not (Test-ManagedEdgeCommandLine "msedge.exe --user-data-dir=`"$profileWithDot`" --no-first-run")) { throw "normalized managed Edge profile must match" }
    if (-not (Test-ManagedEdgeCommandLine "msedge.exe `"--user-data-dir=$profileWithDot`" --no-first-run")) { throw "whole-quoted managed Edge argument must match" }
    if (Test-ManagedEdgeCommandLine "msedge.exe --user-data-dir=`"$($EdgeProfile)2`" --no-first-run") { throw "Edge profile prefix collision must not match" }
    if (Test-ManagedEdgeCommandLine "msedge.exe --user-data-dir=`"$EdgeProfile`" --user-data-dir=`"$($EdgeProfile)2`"") { throw "managed-first duplicate Edge profile switches must not match" }
    if (Test-ManagedEdgeCommandLine "msedge.exe --user-data-dir=`"$($EdgeProfile)2`" --user-data-dir=`"$EdgeProfile`"") { throw "managed-last duplicate Edge profile switches must not match" }
    if (Select-String -Path $MyInvocation.MyCommand.Path -Pattern 'docker(\.exe)?\s+stop' -Quiet) { throw "tray must not issue a named-container stop" }
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    if (-not [System.Windows.Forms.NotifyIcon]) { throw "NotifyIcon unavailable" }
    $applicationIcon = [System.Drawing.Icon]::new($IconPath, [System.Windows.Forms.SystemInformation]::SmallIconSize)
    $applicationIcon.Dispose()
    Write-Host "$Name tray self-check passed"
    exit 0
}

if ($StopOnly) {
    $script:ShutdownInProgress = $false
    Stop-Service
    Write-Host "$Name shutdown completed"
    exit 0
}

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

$created = $false
$mutex = [Threading.Mutex]::new($true, "Local\VoiceTray-ZipVoice", [ref]$created)
if (-not $created) {
    $mutex.Dispose()
    exit 0
}

$script:SeenRunning = $false
$script:StopRequested = $false
$script:ShutdownFailed = $false
$script:ShutdownInProgress = $false
$script:Disposed = $false
$script:StartupDeadline = [DateTime]::UtcNow.AddMinutes(7)

$menu = [System.Windows.Forms.ContextMenuStrip]::new()
$statusItem = $menu.Items.Add("$Name - Starting")
$statusItem.Enabled = $false
$openItem = $menu.Items.Add("Open $Name")
$openItem.Enabled = $false
$endItem = $menu.Items.Add("End $Name")
$applicationIcon = [System.Drawing.Icon]::new($IconPath, [System.Windows.Forms.SystemInformation]::SmallIconSize)
$icon = [System.Windows.Forms.NotifyIcon]::new()
$icon.ContextMenuStrip = $menu
$icon.Icon = $applicationIcon
$icon.Text = "$Name - Starting"
$icon.Visible = $true

function Set-TrayState {
    param([string]$State)
    $icon.Text = "$Name - $State"
    $statusItem.Text = "$Name - $State"
    $openItem.Enabled = $State -in @("Running", "Needs attention")
    $endItem.Enabled = $State -ne "Stopping"
}

function Close-Tray {
    if ($script:Disposed) { return }
    $script:Disposed = $true
    $timer.Stop()
    $icon.Visible = $false
    $icon.Dispose()
    $applicationIcon.Dispose()
    $menu.Dispose()
    [System.Windows.Forms.Application]::ExitThread()
}

function Show-TrayError {
    param([string]$Action, [string]$Message)
    $icon.BalloonTipTitle = "Could not $Action $Name"
    $icon.BalloonTipText = $Message
    $icon.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Error
    $icon.ShowBalloonTip(5000)
}

$openAction = {
    try {
        if (-not (Test-ServiceHealth) -or -not (Test-GuiProcess)) { return }
        Open-ServiceWindow
    } catch {
        Show-TrayError "open" $_.Exception.Message
    }
}
$openItem.add_Click($openAction)
$icon.add_DoubleClick($openAction)

function Request-ServiceStop {
    $script:ShutdownFailed = $false
    $script:StopRequested = $true
    Set-TrayState "Stopping"
    try {
        Stop-Service
    } catch {
        $script:StopRequested = $false
        $script:ShutdownFailed = $true
        Set-TrayState "Needs attention"
        Show-TrayError "end" $_.Exception.Message
    }
}
$endItem.add_Click({ Request-ServiceStop })

$timer = [System.Windows.Forms.Timer]::new()
$timer.Interval = 2000
$timer.add_Tick({
    try {
        $health = Test-ServiceHealth
        $ready = Test-ServiceReady
        $guiProcessState = Get-GuiProcessState
        if ($guiProcessState -eq "InfrastructureError") {
            throw "Could not inspect the managed $Name GUI process in Ubuntu-24.04"
        }
        $running = $guiProcessState -eq "Running"
    } catch {
        Set-TrayState "Needs attention"
        return
    }
    if ($script:ShutdownFailed) {
        Set-TrayState "Needs attention"
        return
    }
    if ($running) {
        $script:SeenRunning = $true
        Set-TrayState (Get-MonitorState $true $health $ready $script:StopRequested $true $false)
        return
    }
    $endpointResponding = $health -or $ready
    $expired = [DateTime]::UtcNow -ge $script:StartupDeadline
    if (Should-ExitMonitor $script:SeenRunning $script:StopRequested $false $expired $script:ShutdownFailed $endpointResponding) {
        Close-Tray
    } elseif ($endpointResponding) {
        Set-TrayState (Get-MonitorState $false $health $ready $script:StopRequested $true $expired)
    } else {
        Set-TrayState (Get-MonitorState $false $false $false $script:StopRequested $true $expired)
    }
})

$timer.Start()
[System.Windows.Forms.Application]::Run()

$mutex.ReleaseMutex()
$mutex.Dispose()
