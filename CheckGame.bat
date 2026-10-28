@echo off
setlocal
cd /d "%~dp0"
where pwsh.exe >nul 2>&1
if errorlevel 1 (
  echo PowerShell 7.4 or newer is required. Install PowerShell 7 first.
  pause
  exit /b 1
)
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Audit.ps1" 
set "WOW_RESULT=%ERRORLEVEL%"
if not "%WOW_RESULT%"=="0" echo Operation failed or has open checks. Exit: %WOW_RESULT%
pause
exit /b %WOW_RESULT%
