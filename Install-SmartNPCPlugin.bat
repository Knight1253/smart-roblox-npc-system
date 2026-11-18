@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-SmartNPCPlugin.ps1"
if errorlevel 1 (
  echo.
  echo Installation failed. See the error above.
  pause
  exit /b 1
)
echo.
echo Installation complete. Restart Roblox Studio to load the plugin.
pause
