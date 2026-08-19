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
    if ($script:ShutdownInProgress) { return }
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
                return
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
    param([bool]$SeenRunning, [bool]$StopRequested, [bool]$Running, [bool]$StartupExpired)
    return (-not $Running) -and ($SeenRunning -or $StopRequested -or $StartupExpired)
}

function Get-TrayState {
    param([bool]$Health, [bool]$Ready, [bool]$Stopping, [bool]$Starting, [bool]$StartupExpired)
    if ($Stopping) { return "Stopping" }
    if ($Health -and $Ready) { return "Running" }
    if ($Health -or $StartupExpired) { return "Needs attention" }
    if ($Starting) { return "Starting" }
    return "Needs attention"
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
    if (Select-String -Path $MyInvocation.MyCommand.Path -Pattern 'docker(\.exe)?\s+stop' -Quiet) { throw "tray must not issue a named-container stop" }
    Add-Type -AssemblyName System.Windows.Forms
    if (-not [System.Windows.Forms.NotifyIcon]) { throw "NotifyIcon unavailable" }
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
$script:ShutdownInProgress = $false
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

$endItem.add_Click({
    $script:StopRequested = $true
    Set-TrayState "Stopping"
    try {
        Stop-Service
    } catch {
        Set-TrayState "Needs attention"
        Show-TrayError "end" $_.Exception.Message
    }
})

$timer = [System.Windows.Forms.Timer]::new()
$timer.Interval = 2000
$timer.add_Tick({
    try {
        $health = Test-ServiceHealth
        $ready = Test-ServiceReady
        $running = $health -or (Test-ServiceBackground)
    } catch {
        $ready = $false
        $running = $false
    }
    if ($running) {
        $script:SeenRunning = $true
        Set-TrayState (Get-TrayState $health $ready $script:StopRequested $true $false)
        return
    }
    $expired = [DateTime]::UtcNow -ge $script:StartupDeadline
    if (Should-ExitMonitor $script:SeenRunning $script:StopRequested $false $expired) {
        Close-Tray
    } else {
        Set-TrayState (Get-TrayState $false $false $script:StopRequested $true $expired)
    }
})

$timer.Start()
[System.Windows.Forms.Application]::Run()

$mutex.ReleaseMutex()
$mutex.Dispose()
