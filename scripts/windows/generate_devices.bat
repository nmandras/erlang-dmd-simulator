@echo off
setlocal
set "ROOT=%~dp0"
cd /d "%ROOT%"

if "%~2"=="" (
    echo Usage: %~nx0 WMR WME [options...]
    echo Example: %~nx0 0 10 -o config\devices.csv
    exit /b 1
)

where escript >nul 2>&1
if errorlevel 1 (
    echo ERROR: escript not on PATH. Install Erlang/OTP.
    exit /b 1
)

if exist "%ROOT%generate_devices.escript" (
    set "SCRIPT=%ROOT%generate_devices.escript"
) else if exist "%ROOT%scripts\generate_devices.escript" (
    set "SCRIPT=%ROOT%scripts\generate_devices.escript"
) else (
    echo ERROR: generate_devices.escript not found in %ROOT%
    exit /b 1
)

escript "%SCRIPT%" %*
exit /b %ERRORLEVEL%
