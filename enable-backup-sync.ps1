$ErrorActionPreference='Stop'
try {
    Enable-ScheduledTask -TaskName 'Jiaojiedi-Private-Backup-Sync' | Out-Null
    Start-ScheduledTask -TaskName 'Jiaojiedi-Private-Backup-Sync'
    Write-Host 'Backup sync enabled: runs at login and hourly. A sync has started now.'
} catch {
    Write-Host ('Could not enable backup sync: '+$_.Exception.Message) -ForegroundColor Red
    exit 1
}
