@echo off
setlocal
cd /d "%~dp0"
where pwsh.exe >nul 2>&1
if errorlevel 1 (
  echo PowerShell 7.4 or newer is required. Install PowerShell 7 first.
  pause
  exit /b 1
)
echo First-play profile: new human warriors start in Northshire. See docs\FIRST-PLAY.md.
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Setup.ps1" -NorthshireWarrior
set "WOW_RESULT=%ERRORLEVEL%"
if not "%WOW_RESULT%"=="0" echo Operation failed or has open checks. Exit: %WOW_RESULT%
pause
exit /b %WOW_RESULT%
