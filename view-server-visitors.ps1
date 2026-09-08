param([switch]$Once, [ValidateRange(0,3650)][int]$Days=7)
$ErrorActionPreference='Stop'
[Console]::OutputEncoding=New-Object System.Text.UTF8Encoding($false)
$OutputEncoding=[Console]::OutputEncoding
$visitorConfig=Join-Path $PSScriptRoot 'ssh_config_l4d2'
$visitorCommand="python3 ~/deploy/visitor-status.py --days $Days"
if(-not $Once){$visitorCommand+=' --watch'}
& ssh.exe -F $visitorConfig l4d2-cloud $visitorCommand
if($LASTEXITCODE -ne 0){Write-Host 'Connection ended. Check your network and SSH access, then run again.' -ForegroundColor Yellow}
