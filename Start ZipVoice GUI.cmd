@echo off
setlocal
title ZipVoice TTS Control Panel
set "GUI_URL=http://127.0.0.1:8020"
set "DOCKER_DESKTOP=%ProgramFiles%\Docker\Docker\Docker Desktop.exe"
set "EDGE=C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
set "EDGE_PROFILE=%LOCALAPPDATA%\ZipVoice\EdgeProfile"
set "TRAY_SCRIPT=%~dp0Voice Tray.ps1"
set "ZIPVOICE_TRAY_SCRIPT=%TRAY_SCRIPT%"
set "WSL_PREFLIGHT_ERROR=%TEMP%\zipvoice_wsl_preflight.error.log"
set "WSL_BOOTSTRAP_ERROR=%TEMP%\zipvoice_host_bootstrap.log"
set "GUI_STDOUT=%TEMP%\zipvoice_gui.stdout.log"
set "GUI_STDERR=%TEMP%\zipvoice_gui.stderr.log"
set "ZIPVOICE_GUI_STDOUT=%GUI_STDOUT%"
set "ZIPVOICE_GUI_STDERR=%GUI_STDERR%"

if not exist "%TRAY_SCRIPT%" (
    echo ZipVoice tray script was not found: "%TRAY_SCRIPT%"
    pause
    exit /b 1
)

rem A launcher-owned GUI may still be starting even though /health is not up yet.
rem Check for that exact process before prepare so an existing instance is not
rem mutated, and never trust an unrelated HTTP 200 as proof of ownership.
wsl.exe -d Ubuntu-24.04 -- pgrep -f "^python3 /home/william/tts/ZipVoice/zipvoice_gui[.]py$" >nul 2>&1
call :classify_exit_code
if not errorlevel 1 (
    call :start_tray
    call :classify_exit_code
    if errorlevel 1 exit /b 1
    curl.exe --connect-timeout 1 --max-time 1 -fsS "%GUI_URL%/health" >nul 2>&1
    call :classify_exit_code
    if not errorlevel 1 goto open_gui
    goto wait_existing_gui
)
if errorlevel 2 (
    echo Could not inspect the managed ZipVoice GUI process in Ubuntu-24.04.
    pause
    exit /b 1
)

echo Preparing the isolated ZipVoice host environment...
wsl.exe -d Ubuntu-24.04 -- python3 /home/william/tts/ZipVoice/zipvoice_bootstrap.py prepare --json >"%WSL_BOOTSTRAP_ERROR%" 2>&1
call :classify_exit_code
if errorlevel 1 (
    echo ZipVoice host dependency preparation failed:
    type "%WSL_BOOTSTRAP_ERROR%"
    pause
    exit /b 1
)

docker info >nul 2>&1
call :classify_exit_code
if errorlevel 1 (
    if not exist "%DOCKER_DESKTOP%" (
        echo Docker Desktop was not found.
        pause
        exit /b 1
    )
    echo Starting Docker Desktop...
    start "" "%DOCKER_DESKTOP%"
    for /L %%I in (1,1,120) do (
        docker info >nul 2>&1
        call :classify_exit_code
        if not errorlevel 1 goto docker_ready
        ping.exe -n 3 127.0.0.1 >nul
    )
    echo Docker Desktop did not become ready within four minutes.
    pause
    exit /b 1
)

:docker_ready
echo Waiting for Ubuntu-24.04 Docker integration...
for /L %%I in (1,1,120) do (
    wsl.exe -d Ubuntu-24.04 -- docker info >nul 2>"%WSL_PREFLIGHT_ERROR%"
    call :classify_exit_code
    if not errorlevel 1 goto wsl_ready
    ping.exe -n 3 127.0.0.1 >nul
)
echo Ubuntu-24.04 Docker integration did not become ready within four minutes:
type "%WSL_PREFLIGHT_ERROR%"
echo In Docker Desktop, enable Ubuntu-24.04 under Settings, Resources, WSL integration.
pause
exit /b 1

:wsl_ready
rem A clean, completed shutdown removes the ownership lease. Re-establish it
rem through the managed GUI path before the next launch; this never stops or
removes a container and still requires the GUI's normal identity checks.
wsl.exe -d Ubuntu-24.04 -- test -e /home/william/.local/state/zipvoice/runtime-ownership.json >nul 2>&1
call :classify_exit_code
if errorlevel 2 (
    echo Could not inspect the ZipVoice runtime ownership lease.
    pause
    exit /b 1
)
if errorlevel 1 (
    echo Establishing the verified ZipVoice runtime ownership lease...
    wsl.exe -d Ubuntu-24.04 -- python3 /home/william/tts/ZipVoice/zipvoice_bootstrap.py exec --adopt-runtime zipvoice-trt-pinned-r5 >"%WSL_BOOTSTRAP_ERROR%" 2>&1
    call :classify_exit_code
    if errorlevel 1 (
        echo ZipVoice runtime adoption failed:
        type "%WSL_BOOTSTRAP_ERROR%"
        pause
        exit /b 1
    )
)
echo Starting ZipVoice. The first launch can take several minutes...
powershell.exe -NoProfile -Command "try { Start-Process -FilePath 'wsl.exe' -WindowStyle Hidden -RedirectStandardOutput $env:ZIPVOICE_GUI_STDOUT -RedirectStandardError $env:ZIPVOICE_GUI_STDERR -ArgumentList '-d','Ubuntu-24.04','--','python3','/home/william/tts/ZipVoice/zipvoice_bootstrap.py','exec' -ErrorAction Stop | Out-Null } catch { Write-Error $_; exit 1 }"
call :classify_exit_code
if errorlevel 1 (
    echo ZipVoice background startup could not be launched.
    pause
    exit /b 1
)
call :start_tray
call :classify_exit_code
if errorlevel 1 exit /b 1
:wait_existing_gui
for /L %%I in (1,1,180) do (
    curl.exe --connect-timeout 1 --max-time 1 -fsS "%GUI_URL%/health" >nul 2>&1
    call :classify_exit_code
    if not errorlevel 1 (
        wsl.exe -d Ubuntu-24.04 -- pgrep -f "^python3 /home/william/tts/ZipVoice/zipvoice_gui[.]py$" >nul 2>&1
        call :classify_exit_code
        if not errorlevel 1 goto open_gui
        if errorlevel 2 goto gui_probe_failed
    )
    ping.exe -n 2 127.0.0.1 >nul
)

echo ZipVoice GUI did not become live within six minutes.
echo Host bootstrap output:
type "%WSL_BOOTSTRAP_ERROR%"
echo GUI output:
type "%GUI_STDOUT%"
type "%GUI_STDERR%"
pause
exit /b 1

:gui_probe_failed
echo ZipVoice GUI health responded, but the managed process could not be inspected.
pause
exit /b 1

:open_gui
if not exist "%EDGE%" (
    echo Microsoft Edge was not found.
    pause
    exit /b 1
)
start "" "%EDGE%" "--app=%GUI_URL%" "--user-data-dir=%EDGE_PROFILE%" "--no-first-run"
endlocal
goto :eof

:start_tray
if not exist "%TRAY_SCRIPT%" (
    echo ZipVoice tray script was not found: "%TRAY_SCRIPT%"
    exit /b 1
)
powershell.exe -NoProfile -Command "try { $trayFileArgument = [char]34 + $env:ZIPVOICE_TRAY_SCRIPT + [char]34; Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-File',$trayFileArgument -ErrorAction Stop | Out-Null } catch { Write-Error $_; exit 1 }"
call :classify_exit_code
if errorlevel 1 (
    echo ZipVoice tray could not be launched.
    exit /b 1
)
exit /b 0

:classify_exit_code
rem A signed negative exit code is an error too. Normalize before ERRORLEVEL tests.
if "%errorlevel%"=="0" exit /b 0
if "%errorlevel%"=="1" exit /b 1
exit /b 2
