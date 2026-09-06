param([string]$Root = $PSScriptRoot)
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path -LiteralPath $Root).Path
$backupDirectory = Join-Path $Root 'backups'
$sshConfig = Join-Path $Root 'ssh_config_l4d2'
$statusFile = Join-Path $backupDirectory 'sync-status.json'
$mutex = [Threading.Mutex]::new($false, 'Local\JiaojiediBackupSync')
if (-not $mutex.WaitOne(0)) { $mutex.Dispose(); exit 0 }
try {
  $manifestTemp = Join-Path $backupDirectory 'download-manifest.partial'
  $sshOptions = @('-F',$sshConfig,'-o','BatchMode=yes','-o','ConnectTimeout=20','-o','ServerAliveInterval=20','-o','ServerAliveCountMax=3')
  & scp.exe @sshOptions 'jiaojiedi-server:restore-bundles/latest.json' $manifestTemp
  if ($LASTEXITCODE -ne 0) { throw 'Could not download cloud manifest; previous backups retained.' }
  $record = Get-Content -Raw -LiteralPath $manifestTemp | ConvertFrom-Json
  $filename = [string]$record.filename
  if ($filename -notmatch '^jiaojiedi-full-[0-9]{8}T[0-9]{6}Z\.tar\.gz$' -or $record.sha256 -notmatch '^[a-f0-9]{64}$' -or $record.bytes -le 0) { throw 'Invalid cloud manifest' }
  $destination = Join-Path $backupDirectory $filename
  $valid = (Test-Path -LiteralPath $destination) -and ((Get-Item -LiteralPath $destination).Length -eq $record.bytes)
  if ($valid) { $valid = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant() -eq $record.sha256 }
  if (-not $valid) {
    $partial = $destination + '.partial'
    & scp.exe @sshOptions ('jiaojiedi-server:restore-bundles/' + $filename) $partial
    if ($LASTEXITCODE -ne 0) { throw 'Download interrupted; previous backups retained.' }
    if ((Get-Item -LiteralPath $partial).Length -ne $record.bytes -or (Get-FileHash -LiteralPath $partial -Algorithm SHA256).Hash.ToLowerInvariant() -ne $record.sha256) { throw 'Backup checksum mismatch' }
    Move-Item -LiteralPath $partial -Destination $destination -Force
  }
  Copy-Item -LiteralPath $manifestTemp -Destination ($destination + '.json') -Force
  Move-Item -LiteralPath $manifestTemp -Destination (Join-Path $backupDirectory 'latest.json') -Force
  @{ok=$true;checked_utc=[DateTime]::UtcNow.ToString('o');archive=$filename;sha256=$record.sha256;backup_created_utc=$record.created_utc} | ConvertTo-Json | Set-Content -LiteralPath $statusFile -Encoding UTF8
  # Remove only validated-name complete snapshots inside this exact directory.
  $old = Get-ChildItem -LiteralPath $backupDirectory -File | Where-Object { $_.Name -match '^jiaojiedi-full-[0-9]{8}T[0-9]{6}Z\.tar\.gz$' } | Sort-Object Name -Descending | Select-Object -Skip 30
  foreach ($item in $old) {
    if ($item.DirectoryName -ne $backupDirectory -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Unsafe retention target' }
    Remove-Item -LiteralPath $item.FullName
    $oldManifest=$item.FullName+'.json';if(Test-Path -LiteralPath $oldManifest){Remove-Item -LiteralPath $oldManifest}
  }
  Write-Output ('BACKUP_VERIFIED ' + $filename)
} catch {
  @{ok=$false;checked_utc=[DateTime]::UtcNow.ToString('o');error=$_.Exception.Message;previous_backups_retained=$true} | ConvertTo-Json | Set-Content -LiteralPath $statusFile -Encoding UTF8
  Write-Error $_
  exit 1
} finally { $mutex.ReleaseMutex(); $mutex.Dispose() }
