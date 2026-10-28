param()
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$trayPath = Join-Path $root 'Voice Tray.ps1'
$parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($trayPath, [ref]$null, [ref]$parseErrors)
if ($parseErrors.Count) { throw 'Tray PowerShell syntax failed' }
# Import functions only: no tray, WSL, Docker, Edge, or application startup.
$ast.FindAll({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Parent -eq $ast.EndBlock }, $true) |
    ForEach-Object { Invoke-Expression $_.Extent.Text }
$Name = 'ZipVoice'
$Url = 'http://127.0.0.1:8020'
$ProcessPattern = '^python3 /home/william/tts/ZipVoice/zipvoice_gui[.]py$'
$EdgeProfile = Join-Path $env:TEMP "ZipVoice space's\EdgeProfile"
$fixtures = Join-Path $env:TEMP ('zipvoice-launcher-tests-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixtures | Out-Null
$script:passed = 0
function Assert-True { param([bool]$Condition, [string]$Message) if (-not $Condition) { throw $Message } }
function Check {
    param([string]$Label, [scriptblock]$Body)
    & $Body
    $script:passed++
    Write-Host "PASS $Label"
}
try {
    Check 'Native exit codes and process classification' {
        foreach ($code in @(0, 1, 2, -1)) {
            $actual = Invoke-NativeQuiet $env:ComSpec @('/d', '/c', "exit /b $code")
            Assert-True ($actual -eq $code) "Native exit $code changed to $actual"
            $expected = if ($code -eq 0) { 'Running' } elseif ($code -eq 1) { 'NotFound' } else { 'InfrastructureError' }
            Assert-True ((Convert-PgrepExitCodeToState $actual) -eq $expected) "Wrong classification for $code"
        }
    }
    Check 'Missing executable and bounded native timeout' {
        $failed = $false
        try { Invoke-NativeQuiet (Join-Path $fixtures 'missing.exe') @() } catch { $failed = $true }
        Assert-True $failed 'Missing executable was accepted'
        $clock = [Diagnostics.Stopwatch]::StartNew()
        $failed = $false
        try { Invoke-NativeQuiet 'powershell.exe' @('-NoProfile', '-Command', 'Start-Sleep -Seconds 10') 200 } catch { $failed = $true }
        Assert-True ($failed -and $clock.ElapsedMilliseconds -lt 2000) 'Native timeout did not bound the helper process'
    }
    Check 'GUI probe rejects execution failures' {
        function Invoke-NativeQuiet { throw 'mock process start failure' }
        Assert-True ((Get-GuiProcessState) -eq 'InfrastructureError') 'Probe failure became a running or absent GUI'
    }
    Check 'Bounded native output capture' {
        $result = Invoke-NativeQuiet $env:ComSpec @('/d', '/c', 'echo probe-output') 3000 -CaptureOutput
        Assert-True ($result.ExitCode -eq 0 -and $result.Output.Trim() -eq 'probe-output') 'Captured native output was lost'
    }
    Check 'Native arguments preserve spaces, apostrophes and trailing backslashes' {
        $fixture = Join-Path $fixtures "argument space's.ps1"
        [IO.File]::WriteAllText($fixture, 'param([string]$TargetPath) [Console]::Write($TargetPath)', [Text.Encoding]::ASCII)
        $target = "C:\space's folder\trailing\"
        $result = Invoke-NativeQuiet 'powershell.exe' @('-NoProfile', '-File', $fixture, '-TargetPath', $target) 3000 -CaptureOutput
        Assert-True ($result.ExitCode -eq 0 -and $result.Output -eq $target) 'Native path argument did not survive quoting'
    }
    Check 'Managed Edge closure filters exact profiles without touching real processes' {
        $script:mockEdgeOutput = @(
            @{ProcessId=11;CommandLine="msedge.exe --user-data-dir=`"$EdgeProfile`""},
            @{ProcessId=12;CommandLine="msedge.exe --user-data-dir=`"$($EdgeProfile)2`""},
            @{ProcessId=13;CommandLine='msedge.exe --user-data-dir="C:\unrelated"'}
        ) | ConvertTo-Json -Compress
        $script:stoppedIds = @()
        function Invoke-NativeQuiet {
            param($FilePath, $ArgumentList, $TimeoutMilliseconds, [switch]$CaptureOutput)
            Assert-True ($TimeoutMilliseconds -eq 1000 -and $CaptureOutput) 'Edge inspection did not use its supplied deadline'
            return [pscustomobject]@{ExitCode=0;Output=$script:mockEdgeOutput}
        }
        function Stop-Process { param($Id, [switch]$Force, $ErrorAction) $script:stoppedIds += $Id }
        Close-ManagedEdge 1000
        Assert-True ($script:stoppedIds.Count -eq 1 -and $script:stoppedIds[0] -eq 11) 'Edge closure selected an unrelated profile'
    }
    Check 'Ownership record rejects infrastructure errors' {
        foreach ($code in @(0, 1, 2, -1)) {
            $script:mockExit = $code
            function Invoke-NativeQuiet { return $script:mockExit }
            $failed = $false
            $gone = $false
            try { $gone = Test-OwnershipRecordGone } catch { $failed = $true }
            Assert-True ($failed -eq ($code -notin @(0, 1))) "Ownership result $code was misclassified"
            if (-not $failed) { Assert-True ($gone -eq ($code -eq 0)) 'Ownership presence was reversed' }
        }
    }
    Check 'Actual batch subroutine handles signed exit codes' {
        $launcher = Get-Content -Raw -LiteralPath (Join-Path $root 'Start ZipVoice GUI.cmd')
        $classifier = $launcher.Substring([regex]::Match($launcher, '(?m)^:classify_exit_code\r?$').Index)
        foreach ($code in @(0, 1, 2, -1)) {
            $expected = if ($code -in @(0, 1)) { $code } else { 2 }
            $body = "@echo off`r`ncmd /d /c exit /b $code`r`ncall :classify_exit_code`r`nexit /b %errorlevel%`r`n" + $classifier
            $fixture = Join-Path $fixtures "exit-$code.cmd"
            [IO.File]::WriteAllText($fixture, $body, [Text.Encoding]::ASCII)
            & $env:ComSpec /d /c $fixture
            Assert-True ($LASTEXITCODE -eq $expected) "Batch exit $code did not become $expected"
        }
        # Every conditional external command must pass through the tested classifier.
        $lines = Get-Content -LiteralPath (Join-Path $root 'Start ZipVoice GUI.cmd')
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i].Trim() -match '^(wsl\.exe|curl\.exe|docker info|powershell\.exe|call :start_tray)') {
                Assert-True ($lines[$i + 1].Trim() -eq 'call :classify_exit_code') "Unclassified command at line $($i + 1)"
            }
        }
    }
    Check 'Ownership adoption runs only for an absent record' {
        $launcher = Get-Content -Raw -LiteralPath (Join-Path $root 'Start ZipVoice GUI.cmd')
        $classifier = $launcher.Substring([regex]::Match($launcher, '(?m)^:classify_exit_code\r?$').Index)
        $begin = $launcher.IndexOf('wsl.exe -d Ubuntu-24.04 -- test -e')
        $end = $launcher.IndexOf('echo Starting ZipVoice.')
        $ownership = $launcher.Substring($begin, $end - $begin)
        foreach ($code in @(0, 1, 2, -1)) {
            $mock = [regex]::Replace($ownership, '(?m)^wsl\.exe .*test -e[^\r\n]*', "cmd /d /c exit /b $code")
            $mock = [regex]::Replace($mock, '(?m)^\s*wsl\.exe .*--adopt-runtime[^\r\n]*', '    echo MOCK_ADOPTION' + "`r`n" + '    cmd /d /c exit /b 0')
            $mock = [regex]::Replace($mock, '(?m)^\s*pause\s*$', 'rem no interactive pause')
            Assert-True ($mock -notmatch '(?m)^\s*wsl\.exe') 'Fixture retained a real WSL command'
            $fixture = Join-Path $fixtures "ownership-$code.cmd"
            [IO.File]::WriteAllText($fixture, "@echo off`r`n" + $mock + "`r`nexit /b 0`r`n" + $classifier, [Text.Encoding]::ASCII)
            $output = @(& $env:ComSpec /d /c $fixture)
            $actualCode = $LASTEXITCODE
            Assert-True (($output -contains 'MOCK_ADOPTION') -eq ($code -eq 1)) "Wrong adoption decision for $code"
            Assert-True (($actualCode -eq 0) -eq ($code -in @(0, 1))) "Wrong ownership fixture exit for $code"
        }
    }
    Check 'Concurrent live port probes and delayed refusal' {
        $listeners = @()
        try {
            foreach ($i in 1..4) {
                $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
                $listener.Start()
                $listeners += $listener
            }
            $ports = @($listeners | ForEach-Object { $_.LocalEndpoint.Port })
            $open = @(Get-UnclosedPorts $ports 3000)
            Assert-True ($open.Count -eq 4) 'Connected ports were reported closed'
            foreach ($listener in $listeners) { $listener.Stop() }
            $clock = [Diagnostics.Stopwatch]::StartNew()
            $unclosed = @(Get-UnclosedPorts $ports 3000)
            Assert-True ($unclosed.Count -eq 0) 'Delayed refusal was reported open or unknown'
            Assert-True ($clock.ElapsedMilliseconds -lt 4200) 'Four refusal waits were serialized'
        } finally { foreach ($listener in $listeners) { $listener.Stop() } }
    }
    Check 'Timeout and unknown socket errors are not closed' {
        $pending = [Threading.Tasks.TaskCompletionSource[object]]::new()
        $client = [Net.Sockets.TcpClient]::new()
        try {
            Assert-True ((Get-ConnectOutcome $client $pending.Task 20) -eq 'TimedOut') 'Pending task was accepted as closed'
            $failed = [Threading.Tasks.TaskCompletionSource[object]]::new()
            $failed.SetException([Net.Sockets.SocketException]::new([int][Net.Sockets.SocketError]::NetworkUnreachable))
            Assert-True ((Get-ConnectOutcome $client $failed.Task 100) -eq 'Error') 'Unknown network error was accepted as refusal'
            $refused = [Threading.Tasks.TaskCompletionSource[object]]::new()
            $refused.SetException([Net.Sockets.SocketException]::new([int][Net.Sockets.SocketError]::ConnectionRefused))
            Assert-True ((Get-ConnectOutcome $client $refused.Task 100) -eq 'Refused') 'Refusal was not recognized'
        } finally { $client.Dispose() }
        Assert-True (-not (Test-ConnectOutcomeClosed 'TimedOut')) 'Timeout counted as closed'
        Assert-True (-not (Test-ConnectOutcomeClosed 'Error')) 'Error counted as closed'
    }
    Check 'HTTP timeout is bounded against a nonresponding local listener' {
        $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
        try {
            $listener.Start()
            $clock = [Diagnostics.Stopwatch]::StartNew()
            $status = Get-HttpStatus ("http://127.0.0.1:" + $listener.LocalEndpoint.Port + '/') 150
            Assert-True ($status -eq 0 -and $clock.ElapsedMilliseconds -lt 1500) 'HTTP probe exceeded its timeout'
        } finally { $listener.Stop() }
    }
    Check 'Shutdown deadline and retry state' {
        function Close-ManagedEdge { }
        function Test-GuiProcess { param($TimeoutMilliseconds) return $false }
        function Get-HttpStatus { param($Target, $TimeoutMilliseconds) return 0 }
        function Get-UnclosedPorts { param($Ports, $TimeoutMilliseconds) return $Ports }
        function Test-OwnershipRecordGone { param($TimeoutMilliseconds) return $true }
        function Invoke-NativeQuiet { param($FilePath, $ArgumentList, $TimeoutMilliseconds) return 0 }
        $script:ShutdownInProgress = $false
        $failed = $false
        $clock = [Diagnostics.Stopwatch]::StartNew()
        try { Stop-Service -TimeoutMilliseconds 150 } catch { $failed = $true }
        Assert-True ($failed -and $clock.ElapsedMilliseconds -lt 1000) 'Shutdown deadline was not enforced'
        Assert-True (-not $script:ShutdownInProgress) 'Failed shutdown left its retry lock set'
        function Get-UnclosedPorts { param($Ports, $TimeoutMilliseconds) }
        Stop-Service -TimeoutMilliseconds 500
        Assert-True (-not $script:ShutdownInProgress) 'Successful retry left its lock set'
    }
    Check 'Expired budget prevents another shutdown probe' {
        $clock = [Diagnostics.Stopwatch]::StartNew()
        Start-Sleep -Milliseconds 20
        $failed = $false
        try { Get-ProbeBudget $clock 10 3000 } catch { $failed = $true }
        Assert-True $failed 'Expired budget accepted another probe'
        $budget = Get-ProbeBudget ([pscustomobject]@{ElapsedMilliseconds=75}) 100 3000
        Assert-True ($budget -eq 25) 'Probe did not inherit the remaining deadline'
    }
    Check 'Shutdown bounds a stalled native command before further actions' {
        $script:realNativeProbe = (Get-Command Invoke-NativeQuiet -CommandType Function).ScriptBlock
        function Invoke-NativeQuiet {
            param($FilePath, $ArgumentList, $TimeoutMilliseconds)
            & $script:realNativeProbe 'powershell.exe' @('-NoProfile', '-Command', 'Start-Sleep -Seconds 10') $TimeoutMilliseconds
        }
        function Close-ManagedEdge { throw 'Unexpected Edge action after native timeout' }
        $script:ShutdownInProgress = $false
        $clock = [Diagnostics.Stopwatch]::StartNew()
        $failure = ''
        try { Stop-Service -TimeoutMilliseconds 200 } catch { $failure = $_.Exception.Message }
        Assert-True ($failure -like 'Native probe timed out*' -and $clock.ElapsedMilliseconds -lt 1500) 'Stalled native command escaped the shutdown budget'
        Assert-True (-not $script:ShutdownInProgress) 'Stalled command left shutdown locked'
    }
    Check 'Failed shutdown remains retryable through the tray action' {
        function Set-TrayState { param($State) $script:lastState = $State }
        function Show-TrayError { param($Action, $Message) }
        function Stop-Service { throw 'mock shutdown failure' }
        Request-ServiceStop
        Assert-True ($script:ShutdownFailed -and -not $script:StopRequested -and $script:lastState -eq 'Needs attention') 'Failed stop did not allow retry'
        function Stop-Service { return $true }
        Request-ServiceStop
        Assert-True (-not $script:ShutdownFailed -and $script:StopRequested -and $script:lastState -eq 'Stopping') 'Retry retained its previous failure'
    }
    Check 'Orphan endpoints retain tray attention and stopping precedence' {
        Assert-True ((Get-MonitorState $false $true $false $false $false $false) -eq 'Needs attention') 'Orphan health looked running'
        Assert-True ((Get-MonitorState $false $false $true $false $false $false) -eq 'Needs attention') 'Orphan readiness looked running'
        Assert-True ((Get-MonitorState $false $true $true $true $false $false) -eq 'Stopping') 'Stopping lost precedence'
        Assert-True (-not (Should-ExitMonitor $true $false $false $false $false $true)) 'Tray exited with responding endpoints'
        Assert-True (-not (Should-ExitMonitor $true $false $false $false $true)) 'Tray exited after failed shutdown'
    }
    Check 'Edge quoting, normalized paths, collisions and duplicate switches' {
        $argument = ConvertTo-NativeArgument "--user-data-dir=$EdgeProfile"
        Assert-True ($argument.StartsWith('"') -and $argument.EndsWith('"')) 'Space-containing Edge argument was not quoted'
        Assert-True (Test-ManagedEdgeCommandLine ("msedge.exe $argument --no-first-run")) 'Quoted space/apostrophe profile did not match'
        Assert-True (Test-ManagedEdgeCommandLine "msedge.exe --user-data-dir=`"$EdgeProfile\.\`"") 'Normalized profile did not match'
        Assert-True (-not (Test-ManagedEdgeCommandLine "msedge.exe --user-data-dir=`"$($EdgeProfile)2`"")) 'Profile prefix collision matched'
        Assert-True (-not (Test-ManagedEdgeCommandLine "msedge.exe $argument $argument")) 'Duplicate profiles matched'
        function Get-ManagedWindow { return $null }
        function Test-Path { return $true }
        function New-Item { }
        function Start-Process { param($FilePath, $ArgumentList) $script:capturedEdgeArguments = $ArgumentList }
        Open-ServiceWindow
        Assert-True ($script:capturedEdgeArguments[1] -eq $argument) 'Open window did not use the quoted argument'
    }
    Check 'All PowerShell sources, inline commands, and cleanup JSON parse' {
        foreach ($file in @($trayPath, $PSCommandPath, (Join-Path $root 'New ZipVoice Shortcut.ps1'))) {
            $errors = $null
            [Management.Automation.Language.Parser]::ParseFile($file, [ref]$null, [ref]$errors) | Out-Null
            Assert-True ($errors.Count -eq 0) "Syntax errors in $file"
        }
        foreach ($line in Get-Content -LiteralPath (Join-Path $root 'Start ZipVoice GUI.cmd')) {
            if ($line -match '^powershell\.exe -NoProfile -Command "(.*)"$') {
                $errors = $null
                [Management.Automation.Language.Parser]::ParseInput($Matches[1], [ref]$null, [ref]$errors) | Out-Null
                Assert-True ($errors.Count -eq 0) 'Embedded PowerShell syntax failed'
            }
        }
        Get-ChildItem -LiteralPath (Join-Path $root 'cleanup') -Filter '*.json' |
            ForEach-Object { Get-Content -Raw -LiteralPath $_.FullName | ConvertFrom-Json | Out-Null }
    }
    Check 'Application icon loads at every Windows display size' {
        Add-Type -AssemblyName System.Drawing
        $iconPath = Join-Path $root 'assets\zipvoice.ico'
        $bytes = [IO.File]::ReadAllBytes($iconPath)
        $sizes = @(16, 20, 24, 32, 40, 48, 64, 128, 256)
        Assert-True ([BitConverter]::ToUInt16($bytes, 0) -eq 0 -and
            [BitConverter]::ToUInt16($bytes, 2) -eq 1 -and
            [BitConverter]::ToUInt16($bytes, 4) -eq $sizes.Count) 'ICO header or frame count is invalid'
        for ($i = 0; $i -lt $sizes.Count; $i++) {
            $offset = 6 + 16 * $i
            Assert-True ($bytes[$offset] -eq ($sizes[$i] % 256) -and
                $bytes[$offset + 1] -eq ($sizes[$i] % 256)) 'ICO directory size is incorrect'
            $length = [BitConverter]::ToUInt32($bytes, $offset + 8)
            $imageOffset = [BitConverter]::ToUInt32($bytes, $offset + 12)
            Assert-True ($length -gt 0 -and $imageOffset -ge (6 + 16 * $sizes.Count) -and
                $imageOffset + $length -le $bytes.Length) 'ICO frame extends outside the file'
            # Decode each frame separately: .NET's multi-size picker can prefer
            # 128 pixels even when asked for a valid 256-pixel frame.
            $singleFrame = [byte[]]::new(22 + $length)
            [Array]::Copy($bytes, 0, $singleFrame, 0, 6)
            $singleFrame[4] = 1
            [Array]::Copy($bytes, $offset, $singleFrame, 6, 16)
            [Array]::Copy([BitConverter]::GetBytes([uint32]22), 0, $singleFrame, 18, 4)
            [Array]::Copy($bytes, $imageOffset, $singleFrame, 22, $length)
            $stream = [IO.MemoryStream]::new($singleFrame)
            $applicationIcon = $null
            try {
                $applicationIcon = [Drawing.Icon]::new($stream, [Drawing.Size]::new($sizes[$i], $sizes[$i]))
                Assert-True ($applicationIcon.Width -eq $sizes[$i] -and
                    $applicationIcon.Height -eq $sizes[$i]) "Windows could not load the $($sizes[$i])-pixel icon"
            } finally {
                if ($applicationIcon) { $applicationIcon.Dispose() }
                $stream.Dispose()
            }
        }
        $png = [Drawing.Bitmap]::new((Join-Path $root 'assets\zipvoice.png'))
        try {
            Assert-True ($png.Width -eq 256 -and $png.Height -eq 256 -and
                $png.GetPixel(0, 0).A -eq 0) 'PNG size or transparent corners are invalid'
        } finally { $png.Dispose() }
        [xml](Get-Content -Raw -LiteralPath (Join-Path $root 'assets\zipvoice.svg')) | Out-Null
    }
    Check 'Branded shortcut targets the real launcher and preserves unrelated shortcuts' {
        $creator = Join-Path $root 'New ZipVoice Shortcut.ps1'
        $shortcutPath = & $creator -DestinationDirectory $fixtures
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $null
        try {
            $shortcut = $shell.CreateShortcut($shortcutPath)
            Assert-True ($shortcut.TargetPath -eq (Join-Path $root 'Start ZipVoice GUI.cmd')) 'Shortcut targets a different launcher'
            Assert-True ($shortcut.WorkingDirectory -eq $root -and $shortcut.Arguments -eq '') 'Shortcut changes launcher behavior'
            Assert-True ($shortcut.IconLocation -eq ((Join-Path $root 'assets\zipvoice.ico') + ',0')) 'Shortcut does not use the application icon'
            $updatedPath = & $creator -DestinationDirectory $fixtures
            Assert-True ($updatedPath -eq $shortcutPath) 'Shortcut update created a different file'
            $shortcut.TargetPath = Join-Path $env:SystemRoot 'notepad.exe'
            $shortcut.Save()
            $before = (Get-FileHash -LiteralPath $shortcutPath).Hash
            $failed = $false
            try { & $creator -DestinationDirectory $fixtures | Out-Null } catch { $failed = $true }
            Assert-True ($failed -and (Get-FileHash -LiteralPath $shortcutPath).Hash -eq $before) 'An unrelated shortcut was replaced'
        } finally {
            if ($shortcut) { [Runtime.InteropServices.Marshal]::FinalReleaseComObject($shortcut) | Out-Null }
            [Runtime.InteropServices.Marshal]::FinalReleaseComObject($shell) | Out-Null
        }
    }
    Write-Host "Launcher regression checks passed: $script:passed"
} finally {
    # Only exact fixture files created by this run may be removed.
    Get-ChildItem -LiteralPath $fixtures -File | Remove-Item -Force
    Remove-Item -LiteralPath $fixtures -ErrorAction Stop
}
