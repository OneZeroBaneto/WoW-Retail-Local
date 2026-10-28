@echo off
setlocal
cd /d "%~dp0"
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tests\Parse-All.ps1"
if errorlevel 1 exit /b 1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tests\Run.Tests.ps1"
if errorlevel 1 exit /b 1
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tests\Readiness.Tests.ps1"
set "WOW_RESULT=%ERRORLEVEL%"
pause
exit /b %WOW_RESULT%
