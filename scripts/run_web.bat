@echo off
set SCRIPT_DIR=%~dp0
setlocal enabledelayedexpansion

set "ARGS="

:parse_loop
if "%~1"=="" goto execute
set "CURR=%~1"
if /i "!CURR!"=="--server" (
    set "ARGS=!ARGS! -Server"
) else if /i "!CURR!"=="-s" (
    set "ARGS=!ARGS! -Server"
) else if /i "!CURR!"=="/s" (
    set "ARGS=!ARGS! -Server"
) else if /i "!CURR!"=="server" (
    set "ARGS=!ARGS! -Server"
) else if /i "!CURR!"=="--clean" (
    set "ARGS=!ARGS! -Clean"
) else if /i "!CURR!"=="-c" (
    set "ARGS=!ARGS! -Clean"
) else if /i "!CURR!"=="--port" (
    set "ARGS=!ARGS! -Port"
) else if /i "!CURR!"=="-p" (
    set "ARGS=!ARGS! -Port"
) else if /i "!CURR!"=="--help" (
    set "ARGS=!ARGS! -Help"
) else if /i "!CURR!"=="-h" (
    set "ARGS=!ARGS! -Help"
) else if /i "!CURR!"=="/?" (
    set "ARGS=!ARGS! -Help"
) else if /i "!CURR!"=="help" (
    set "ARGS=!ARGS! -Help"
) else (
    set "ARGS=!ARGS! !CURR!"
)
shift /1
goto parse_loop

:execute
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%run_web.ps1" !ARGS!
exit /b %ERRORLEVEL%