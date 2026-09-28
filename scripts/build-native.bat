@echo off
REM Modified by NInferEZ Engine in 2026. Thin cmd wrapper around the canonical PowerShell build.
setlocal
set "ARCH=%~1"
if not defined ARCH set "ARCH=120a"
if "%~2"=="" (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0build.ps1" -Arch "%ARCH%"
) else (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0build.ps1" -Arch "%ARCH%" -Target "%~2"
)
exit /b %errorlevel%
