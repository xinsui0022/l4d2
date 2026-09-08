param([string]$Profile, [switch]$DryRun)
$ErrorActionPreference = 'Stop'
if (-not $Profile) {
    Write-Host 'Add a FULL server administrator (99:z).'
    $Profile = Read-Host 'Paste Steam profile URL or SteamID64'
}
$Profile = $Profile.Trim()
if ($Profile -notmatch '^(?:https?://steamcommunity\.com/profiles/)?(\d{17})/?(?:\?[^\s#]*)?$') {
    throw 'Use https://steamcommunity.com/profiles/7656.../ or a 17-digit SteamID64. Custom /id/ links are not supported.'
}
$adminSteamId = $Matches[1]
$adminAccount = [long]$adminSteamId - [long]76561197960265728
if ($adminAccount -le 0 -or $adminAccount -gt 4294967295) { throw 'Invalid individual SteamID64.' }
$adminSshConfig = Join-Path $PSScriptRoot 'ssh_config_l4d2'
if (-not (Test-Path -LiteralPath $adminSshConfig)) { throw 'Missing ssh_config_l4d2 next to this script.' }
# Only the validated decimal ID enters the remote shell command.
$adminRemoteCommand = "python3 ~/deploy/add-admin.py $adminSteamId"
if ($DryRun) { $adminRemoteCommand += ' --dry-run' }
& ssh.exe -F $adminSshConfig l4d2-cloud $adminRemoteCommand
if ($LASTEXITCODE -ne 0) { throw "Admin command failed (exit $LASTEXITCODE). See the output above." }
