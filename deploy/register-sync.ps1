$ErrorActionPreference='Stop'
$root='YOUR_PRIVATE_DIRECTORY'
$identity=[Security.Principal.WindowsIdentity]::GetCurrent().Name
$action=New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument '-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "YOUR_PRIVATE_DIRECTORY\sync-backups.ps1"'
$login=New-ScheduledTaskTrigger -AtLogOn -User $identity
$hourly=New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(5) -RepetitionInterval (New-TimeSpan -Hours 1)
$principal=New-ScheduledTaskPrincipal -UserId $identity -LogonType Interactive -RunLevel Limited
$settings=New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 2)
Register-ScheduledTask -TaskName 'Jiaojiedi-Private-Backup-Sync' -Action $action -Trigger @($login,$hourly) -Principal $principal -Settings $settings -Description 'Pull and verify latest private L4D2 recovery bundle at login and hourly; retries after offline periods.' -Force | Select-Object TaskName,State
