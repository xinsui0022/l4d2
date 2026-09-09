@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0view-server-join-history.ps1" %*
pause
