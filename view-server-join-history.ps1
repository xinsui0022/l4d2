param([switch]$Once, [ValidateRange(0,3650)][int]$Days=7, [ValidateRange(1,100000)][int]$Limit=200)
$ErrorActionPreference='Stop'
[Console]::OutputEncoding=New-Object System.Text.UTF8Encoding($false)
$OutputEncoding=[Console]::OutputEncoding
$historyConfig=Join-Path $PSScriptRoot 'ssh_config_l4d2'
$historyCommand="python3 ~/deploy/visitor-history.py --days $Days --limit $Limit"
if(-not $Once){$historyCommand+=' --watch'}
& ssh.exe -F $historyConfig l4d2-cloud $historyCommand
if($LASTEXITCODE -ne 0){throw 'SSH history query failed.'}
