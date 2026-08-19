@echo off
setlocal
title ZipVoice TTS Control Panel
set "GUI_URL=http://127.0.0.1:8020"
set "DOCKER_DESKTOP=%ProgramFiles%\Docker\Docker\Docker Desktop.exe"
set "EDGE=C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
set "EDGE_PROFILE=%LOCALAPPDATA%\ZipVoice\EdgeProfile"
set "TRAY_SCRIPT=%~dp0Voice Tray.ps1"
set "WSL_PREFLIGHT_ERROR=%TEMP%\zipvoice_wsl_preflight.error.log"
set "WSL_BOOTSTRAP_ERROR=%TEMP%\zipvoice_host_bootstrap.log"
set "GUI_STDOUT=%TEMP%\zipvoice_gui.stdout.log"
set "GUI_STDERR=%TEMP%\zipvoice_gui.stderr.log"

echo Preparing the isolated ZipVoice host environment...
wsl.exe -d Ubuntu-24.04 -- python3 /home/william/tts/ZipVoice/zipvoice_bootstrap.py prepare --json >"%WSL_BOOTSTRAP_ERROR%" 2>&1
if errorlevel 1 (
    echo ZipVoice host dependency preparation failed:
    type "%WSL_BOOTSTRAP_ERROR%"
    pause
    exit /b 1
)

curl.exe --connect-timeout 1 --max-time 1 -fsS "%GUI_URL%/health" >nul 2>&1
if not errorlevel 1 (
    call :start_tray
    goto open_gui
)

rem A launcher-owned GUI may still be starting even though /health is not up yet.
rem Wait for that process instead of starting a duplicate instance.
wsl.exe -d Ubuntu-24.04 -- pgrep -f "^python3 /home/william/tts/ZipVoice/zipvoice_gui[.]py$" >nul 2>&1
if not errorlevel 1 (
    call :start_tray
    goto wait_existing_gui
)

docker info >nul 2>&1
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
if errorlevel 1 (
    echo Establishing the verified ZipVoice runtime ownership lease...
    wsl.exe -d Ubuntu-24.04 -- python3 /home/william/tts/ZipVoice/zipvoice_bootstrap.py exec --adopt-runtime zipvoice-trt-pinned-r5 >"%WSL_BOOTSTRAP_ERROR%" 2>&1
    if errorlevel 1 (
        echo ZipVoice runtime adoption failed:
        type "%WSL_BOOTSTRAP_ERROR%"
        pause
        exit /b 1
    )
)
echo Starting ZipVoice. The first launch can take several minutes...
powershell.exe -NoProfile -Command "Start-Process -FilePath 'wsl.exe' -WindowStyle Hidden -RedirectStandardOutput '%GUI_STDOUT%' -RedirectStandardError '%GUI_STDERR%' -ArgumentList '-d','Ubuntu-24.04','--','python3','/home/william/tts/ZipVoice/zipvoice_bootstrap.py','exec'"
call :start_tray
:wait_existing_gui
for /L %%I in (1,1,180) do (
    curl.exe --connect-timeout 1 --max-time 1 -fsS "%GUI_URL%/health" >nul 2>&1
    if not errorlevel 1 goto open_gui
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
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%TRAY_SCRIPT%"
exit /b
