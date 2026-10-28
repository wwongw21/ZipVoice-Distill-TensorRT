@echo off
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start ZipVoice Native.ps1" -Action Stop %*
exit /b %errorlevel%
