@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0add-server-admin.ps1" %*
pause
