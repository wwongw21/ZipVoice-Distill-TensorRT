param([switch]$SelfCheck, [switch]$StopOnly)

$ErrorActionPreference = "Stop"
$Name = "ZipVoice"
$Url = "http://127.0.0.1:8020"
$EdgeProfile = Join-Path $env:LOCALAPPDATA "ZipVoice\EdgeProfile"
$ProcessPattern = "^python3 /home/william/tts/ZipVoice/zipvoice_gui[.]py$"
$Edge = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"

function Test-Http {
    param([string]$Target, [string]$ContentPattern)
    try {
        $response = Invoke-WebRequest -UseBasicParsing -Uri $Target -TimeoutSec 1
        return $response.StatusCode -eq 200 -and (
            -not $ContentPattern -or $response.Content -match $ContentPattern
        )
    } catch {
        return $false
    }
}

function Get-HttpStatus {
    param([string]$Target)
    try {
        $response = Invoke-WebRequest -UseBasicParsing -Uri $Target -TimeoutSec 1
        return [int]$response.StatusCode
    } catch {
        $response = $_.Exception.Response
        if ($response -and $response.StatusCode) {
            try { return [int]$response.StatusCode.value__ } catch { return 0 }
        }
        return 0
    }
}

function Test-ServiceHealth {
    return (Get-HttpStatus "$Url/health") -eq 200
}

function Test-ServiceReady {
    return (Get-HttpStatus "$Url/ready") -eq 200
}

function Invoke-NativeQuiet {
    param([string]$FilePath, [string[]]$ArgumentList)
    $FilePath = @(Get-Command $FilePath -CommandType Application -ErrorAction Stop)[0].Source
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & $FilePath @ArgumentList *> $null
        return $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }
}

function Test-ServiceBackground {
    if (Test-Http "http://127.0.0.1:8010/v2/health/ready" "") { return $true }
    return (Invoke-NativeQuiet "wsl.exe" @(
        "-d", "Ubuntu-24.04", "--", "pgrep", "-f", $ProcessPattern
    )) -eq 0
}

function Test-GuiProcess {
    return (Invoke-NativeQuiet "wsl.exe" @(
        "-d", "Ubuntu-24.04", "--", "pgrep", "-f", $ProcessPattern
    )) -eq 0
}

function Test-PortClosed {
    param([int]$Port)
    try {
        $client = [Net.Sockets.TcpClient]::new()
        $task = $client.ConnectAsync("127.0.0.1", $Port)
        if (-not $task.Wait(500)) { $client.Dispose(); return $true }
        $open = $client.Connected
        $client.Dispose()
        return -not $open
    } catch { return $true }
}

function Test-OwnershipRecordGone {
    return (Invoke-NativeQuiet "wsl.exe" @(
        "-d", "Ubuntu-24.04", "--", "test", "!", "-e",
        "/home/william/.local/state/zipvoice/runtime-ownership.json"
    )) -eq 0
}

function Close-ManagedEdge {
    Get-CimInstance Win32_Process -Filter "Name='msedge.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like "*$EdgeProfile*" } |
        ForEach-Object {
            Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
        }
}

function Get-ManagedWindow {
    foreach ($info in Get-CimInstance Win32_Process -Filter "Name='msedge.exe'" -ErrorAction SilentlyContinue) {
        if ($info.CommandLine -notlike "*$EdgeProfile*") { continue }
        $process = Get-Process -Id $info.ProcessId -ErrorAction SilentlyContinue
        if ($process.MainWindowHandle -ne 0) { return $process }
    }
    return $null
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
        "--user-data-dir=$EdgeProfile",
        "--no-first-run"
    )
}

function Stop-Service {
    if ($script:ShutdownInProgress) { return $false }
    $script:ShutdownInProgress = $true
    $clock = [System.Diagnostics.Stopwatch]::StartNew()
    $guiGone = $false
    $healthGone = $false
    $readyGone = $false
    $openPorts = @()
    $ownershipGone = $false
    try {
        Invoke-NativeQuiet "wsl.exe" @(
            "-d", "Ubuntu-24.04", "--", "pkill", "-INT", "-f", $ProcessPattern
        ) | Out-Null
        Close-ManagedEdge
        while ($clock.Elapsed.TotalSeconds -lt 30) {
            $guiGone = -not (Test-GuiProcess)
            $healthGone = -not (Test-ServiceHealth)
            $readyGone = -not (Test-ServiceReady)
            $openPorts = @(8010, 8011, 8012, 8020 | Where-Object { -not (Test-PortClosed $_) })
            $portsGone = $openPorts.Count -eq 0
            $ownershipGone = Test-OwnershipRecordGone
            if ($guiGone -and $healthGone -and $readyGone -and $portsGone -and $ownershipGone) {
                return $true
            }
            Start-Sleep -Milliseconds 250
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

function Should-ExitMonitor {
    param(
        [bool]$SeenRunning,
        [bool]$StopRequested,
        [bool]$Running,
        [bool]$StartupExpired,
        [bool]$ShutdownFailed = $false,
        [bool]$ShutdownInProgress = $false
    )
    return (-not $ShutdownFailed) -and (-not $ShutdownInProgress) -and (-not $Running) -and ($SeenRunning -or $StopRequested -or $StartupExpired)
}

function Get-TrayState {
    param(
        [bool]$Health,
        [bool]$Ready,
        [bool]$Stopping,
        [bool]$Starting,
        [bool]$StartupExpired,
        [bool]$ShutdownFailed = $false
    )
    if ($Stopping) { return "Stopping" }
    if ($ShutdownFailed) { return "Needs attention" }
    if ($Health -and $Ready) { return "Running" }
    if ($Health -or $StartupExpired) { return "Needs attention" }
    if ($Starting) { return "Starting" }
    return "Needs attention"
}

function Invoke-EndAction {
    if ($script:ShutdownInProgress) { return }
    $script:StopRequested = $true
    Set-TrayState "Stopping"
    try {
        $completed = Stop-Service
        if ($completed -ne $true) {
            if (-not $script:ShutdownInProgress) {
                $script:StopRequested = $false
                $script:ShutdownFailed = $true
                Set-TrayState "Needs attention"
                Show-TrayError "end" "$Name shutdown could not be verified; retry is available"
            }
            return
        }
        $script:ShutdownFailed = $false
    } catch {
        $script:StopRequested = $false
        $script:ShutdownFailed = $true
        Set-TrayState "Needs attention"
        Show-TrayError "end" $_.Exception.Message
    }
}

function Invoke-MonitorTick {
    try {
        $health = Test-ServiceHealth
        $ready = Test-ServiceReady
        $running = $health -or (Test-ServiceBackground)
    } catch {
        $health = $false
        $ready = $false
        $running = $false
    }
    if ($running) {
        $script:SeenRunning = $true
        Set-TrayState (Get-TrayState $health $ready ($script:StopRequested -or $script:ShutdownInProgress) $true $false $script:ShutdownFailed)
        return
    }
    $expired = [DateTime]::UtcNow -ge $script:StartupDeadline
    if (Should-ExitMonitor $script:SeenRunning $script:StopRequested $false $expired $script:ShutdownFailed $script:ShutdownInProgress) {
        Close-Tray
    } else {
        Set-TrayState (Get-TrayState $false $false $script:StopRequested $true $expired $script:ShutdownFailed)
    }
}

$script:EndClickHandler = { Invoke-EndAction }
$script:MonitorTickHandler = { Invoke-MonitorTick }

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
    if ((Get-TrayState $true $true $false $true $false $true) -ne "Needs attention") { throw "failed shutdown must stay visible in Needs attention" }
    if (Should-ExitMonitor $true $false $false $false $true) { throw "failed shutdown must block monitor exit" }
    if (Should-ExitMonitor $false $true $false $false $false $true) { throw "active shutdown must block monitor exit until verification completes" }
    if (-not (Should-ExitMonitor $true $true $false $false $false)) { throw "successful stop request must retain the monitor exit path" }

    function Assert-TrayCheck {
        param([bool]$Condition, [string]$Message)
        if (-not $Condition) { throw "tray self-check failed: $Message" }
    }
    function Set-TrayState {
        param([string]$State)
        $script:TestUi.State = $State
        $script:TestUi.EndEnabled = $State -ne "Stopping"
    }
    function Close-Tray {
        $script:TestUi.Visible = $false
        $script:TestUi.CloseCount++
    }
    function Show-TrayError {
        param([string]$Action, [string]$Message)
        $script:TestUi.ErrorAction = $Action
        $script:TestUi.ErrorMessage = $Message
    }
    function Test-ServiceHealth {
        if ($script:TestProbe.ThrowOn -eq "health") { throw "mock health probe failure" }
        return $script:TestProbe.Health
    }
    function Test-ServiceReady {
        if ($script:TestProbe.ThrowOn -eq "ready") { throw "mock readiness probe failure" }
        return $script:TestProbe.Ready
    }
    function Test-ServiceBackground {
        if ($script:TestProbe.ThrowOn -eq "background") { throw "mock background probe failure" }
        return $script:TestProbe.BackendReady -or $script:TestProbe.GuiProcess
    }
    function Stop-Service {
        if ($script:ShutdownInProgress) { return $false }
        $script:TestStop.Calls++
        $script:ShutdownInProgress = $true
        try {
            if ($script:TestStop.TickDuringStop) { & $script:MonitorTickHandler }
            if ($script:TestStop.ReenterEnd) { & $script:EndClickHandler }
            if ($script:TestStop.FailureMessage) { throw $script:TestStop.FailureMessage }
            if ($script:TestStop.ResidualPort) { throw "mock port-$($script:TestStop.ResidualPort) residual" }
            if ($script:TestStop.ResidualOwnership) { throw "mock ownership-record-only residual" }
            if ($script:TestStop.ReturnFalse) { return $false }
            return $true
        } finally {
            $script:ShutdownInProgress = $false
        }
    }
    function Reset-TrayTestState {
        param(
            [bool]$Health = $false,
            [bool]$Ready = $false,
            [bool]$BackendReady = $false,
            [bool]$GuiProcess = $false
        )
        $script:StopRequested = $false
        $script:ShutdownInProgress = $false
        $script:ShutdownFailed = $false
        $script:SeenRunning = $false
        $script:StartupDeadline = [DateTime]::UtcNow.AddMinutes(7)
        $script:TestUi = [ordered]@{
            State = "Starting"
            EndEnabled = $true
            Visible = $true
            CloseCount = 0
            ErrorAction = $null
            ErrorMessage = $null
        }
        $script:TestProbe = [ordered]@{
            Health = $Health
            Ready = $Ready
            BackendReady = $BackendReady
            GuiProcess = $GuiProcess
            ThrowOn = $null
        }
        $script:TestStop = [ordered]@{
            Calls = 0
            FailureMessage = $null
            ResidualPort = $null
            ResidualOwnership = $false
            ReturnFalse = $false
            TickDuringStop = $false
            ReenterEnd = $false
        }
    }

    Reset-TrayTestState -Health $true -Ready $true -GuiProcess $true
    $script:SeenRunning = $true
    $script:TestStop.FailureMessage = "mock shutdown failure while the GUI remains running"
    $script:TestStop.TickDuringStop = $true
    $script:TestStop.ReenterEnd = $true
    & $script:EndClickHandler
    Assert-TrayCheck ($script:TestStop.Calls -eq 1) "overlapping End clicks must not start a second shutdown"
    Assert-TrayCheck ($script:TestUi.State -eq "Needs attention" -and $script:TestUi.EndEnabled -and $script:TestUi.Visible) "running shutdown failure must leave an actionable tray state"
    Assert-TrayCheck ($script:TestUi.ErrorMessage -like "mock shutdown failure*") "failed shutdown must report its error"
    Assert-TrayCheck (-not $script:StopRequested -and $script:ShutdownFailed -and -not $script:ShutdownInProgress) "failed shutdown state must be latched separately from request and active state"
    for ($tick = 0; $tick -lt 2; $tick++) { & $script:MonitorTickHandler }
    Assert-TrayCheck ($script:TestUi.State -eq "Needs attention" -and $script:TestUi.EndEnabled -and $script:TestUi.Visible) "later running ticks must preserve the retry action"
    Assert-TrayCheck ($script:TestUi.CloseCount -eq 0) "running failed shutdown must not close the tray"

    foreach ($port in @(8010, 8011, 8012, 8020)) {
        Reset-TrayTestState
        $script:TestStop.ResidualPort = $port
        & $script:EndClickHandler
        for ($tick = 0; $tick -lt 2; $tick++) { & $script:MonitorTickHandler }
        Assert-TrayCheck ($script:TestUi.State -eq "Needs attention" -and $script:TestUi.EndEnabled -and $script:TestUi.Visible) "port-$port-only residue must keep the tray actionable"
        Assert-TrayCheck ($script:TestUi.CloseCount -eq 0 -and $script:TestStop.ResidualPort -eq $port) "port-$port residue must not be reported as stopped"
    }

    Reset-TrayTestState
    $script:TestStop.ResidualOwnership = $true
    & $script:EndClickHandler
    $script:TestProbe.ThrowOn = "health"
    for ($tick = 0; $tick -lt 2; $tick++) { & $script:MonitorTickHandler }
    Assert-TrayCheck ($script:TestUi.State -eq "Needs attention" -and $script:TestUi.EndEnabled -and $script:TestUi.Visible) "ownership-only residue and probe exceptions must keep the tray actionable"
    Assert-TrayCheck ($script:TestUi.CloseCount -eq 0 -and $script:TestStop.ResidualOwnership) "ownership record must not be reported as gone"

    $script:TestProbe.ThrowOn = $null
    $script:TestStop.FailureMessage = "mock retry failure"
    & $script:EndClickHandler
    Assert-TrayCheck ($script:TestStop.Calls -eq 2 -and $script:ShutdownFailed -and $script:TestUi.EndEnabled) "a repeated failed retry must remain available"
    for ($tick = 0; $tick -lt 2; $tick++) { & $script:MonitorTickHandler }
    Assert-TrayCheck ($script:TestUi.Visible -and $script:TestUi.CloseCount -eq 0 -and $script:TestUi.State -eq "Needs attention") "a failed retry must remain visible through later timer ticks"
    $script:TestStop.FailureMessage = $null
    $script:TestStop.ResidualOwnership = $false
    & $script:EndClickHandler
    Assert-TrayCheck ($script:TestStop.Calls -eq 3 -and -not $script:ShutdownFailed -and $script:StopRequested) "a later successful retry must clear the failure latch"
    & $script:MonitorTickHandler
    Assert-TrayCheck (-not $script:TestUi.Visible -and $script:TestUi.CloseCount -eq 1) "a verified successful retry must preserve the monitor exit path"

    Reset-TrayTestState
    $script:TestStop.ReturnFalse = $true
    & $script:EndClickHandler
    & $script:MonitorTickHandler
    Assert-TrayCheck ($script:ShutdownFailed -and -not $script:StopRequested -and $script:TestUi.Visible -and $script:TestUi.EndEnabled) "a stop result without full verification must remain a visible failure"

    Reset-TrayTestState
    $script:SeenRunning = $true
    & $script:EndClickHandler
    & $script:MonitorTickHandler
    Assert-TrayCheck (-not $script:TestUi.Visible) "successful first shutdown must permit monitor exit"
    Reset-TrayTestState
    $script:StartupDeadline = [DateTime]::UtcNow.AddSeconds(-1)
    & $script:MonitorTickHandler
    Assert-TrayCheck (-not $script:TestUi.Visible) "never-started startup timeout must still exit"
    Reset-TrayTestState -Health $true -Ready $false
    & $script:MonitorTickHandler
    Assert-TrayCheck ($script:TestUi.State -eq "Needs attention" -and $script:TestUi.EndEnabled) "health without readiness must remain actionable"
    Reset-TrayTestState
    $script:TestStop.TickDuringStop = $true
    & $script:EndClickHandler
    Assert-TrayCheck ($script:TestUi.CloseCount -eq 0 -and $script:TestUi.Visible -and $script:TestUi.State -eq "Stopping") "an interleaved stopped-looking tick must wait for full shutdown verification"
    & $script:MonitorTickHandler
    Assert-TrayCheck (-not $script:TestUi.Visible) "monitor may exit after the successful shutdown completes"

    if (Select-String -Path $MyInvocation.MyCommand.Path -Pattern 'docker(\.exe)?\s+stop' -Quiet) { throw "tray must not issue a named-container stop" }
    Add-Type -AssemblyName System.Windows.Forms
    if (-not [System.Windows.Forms.NotifyIcon]) { throw "NotifyIcon unavailable" }
    Write-Host "$Name tray self-check passed"
    exit 0
}

if ($StopOnly) {
    $script:ShutdownInProgress = $false
    $script:ShutdownFailed = $false
    if (-not (Stop-Service)) { throw "$Name shutdown did not complete" }
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
$script:ShutdownInProgress = $false
$script:ShutdownFailed = $false
$script:Disposed = $false
$script:StartupDeadline = [DateTime]::UtcNow.AddMinutes(7)

$menu = [System.Windows.Forms.ContextMenuStrip]::new()
$statusItem = $menu.Items.Add("$Name - Starting")
$statusItem.Enabled = $false
$openItem = $menu.Items.Add("Open $Name")
$openItem.Enabled = $false
$endItem = $menu.Items.Add("End $Name")
$icon = [System.Windows.Forms.NotifyIcon]::new()
$icon.ContextMenuStrip = $menu
$icon.Icon = [System.Drawing.SystemIcons]::Information
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
    if (-not (Test-ServiceHealth)) { return }
    try {
        Open-ServiceWindow
    } catch {
        Show-TrayError "open" $_.Exception.Message
    }
}
$openItem.add_Click($openAction)
$icon.add_DoubleClick($openAction)

$endItem.add_Click($script:EndClickHandler)

$timer = [System.Windows.Forms.Timer]::new()
$timer.Interval = 2000
$timer.add_Tick($script:MonitorTickHandler)

$timer.Start()
[System.Windows.Forms.Application]::Run()

$mutex.ReleaseMutex()
$mutex.Dispose()
