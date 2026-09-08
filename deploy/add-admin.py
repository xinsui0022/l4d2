#!/usr/bin/env python3
"""Add a Steam profile as a SourceMod root admin, preserving unrelated entries."""
from pathlib import Path
import argparse
import datetime
import fcntl
import os
import re
import shutil
import subprocess

STEAM_BASE = 76561197960265728

def steam_identity(value):
    value = value.strip()
    match = re.fullmatch(r'(?:https?://steamcommunity\.com/profiles/)?(\d{17})/?(?:\?[^\s#]*)?', value)
    if not match:
        raise ValueError('Use a numeric Steam profile URL or a 17-digit SteamID64 (custom /id/ URLs are not supported).')
    number = int(match[1])
    account = number - STEAM_BASE
    if not 0 < account <= 0xffffffff:
        raise ValueError('Not an individual public-universe Steam account ID.')
    return str(number), f'STEAM_1:{account % 2}:{account // 2}', f'[U:1:{account}]'

def update_text(text, value):
    sid64, steam2, steam3 = steam_identity(value)
    aliases = {sid64, steam2, steam2.replace('STEAM_1:', 'STEAM_0:'), steam3}
    result = []
    for line in text.splitlines():
        match = re.match(r'^\s*"([^"]+)"\s+', line)
        if not match or match[1] not in aliases:
            result.append(line)
    result.append(f'"{steam2}" "99:z" // SteamID64 {sid64}')
    return '\n'.join(result).rstrip() + '\n'

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('profile')
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()
    sid64, steam2, _ = steam_identity(args.profile)
    base = Path.home()
    config = base / 'steamcmd/l4d2/left4dead2/addons/sourcemod/configs/admins_simple.ini'
    if args.dry_run:
        print(f'VALID: {sid64} -> {steam2}; permission 99:z (full administrator); no changes made')
        return
    os.umask(0o077)
    with open(config.with_suffix('.lock'), 'w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        original = config.read_text()
        updated = update_text(original, args.profile)
        if original != updated:
            directory = base / 'admin-backups'
            directory.mkdir(mode=0o700, exist_ok=True)
            stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
            backup = directory / f'admins_simple-{stamp}.ini'
            shutil.copy2(config, backup)
            backup.chmod(0o600)
            temporary = config.with_suffix('.ini.tmp')
            temporary.write_text(updated)
            temporary.chmod(config.stat().st_mode & 0o777)
            temporary.replace(config)
            print(f'Saved admin {steam2} (99:z). Backup: {backup}')
        else:
            print(f'Already configured: {steam2} (99:z)')
        result = subprocess.run(['python3', str(base / 'deploy/rcon.py'), 'sm_reloadadmins'], capture_output=True, text=True)
        if result.returncode or 'Unknown command' in result.stdout:
            print('Configuration saved, but live reload failed. Run sm_reloadadmins when the server is available.')
            print(result.stdout or result.stderr)
            raise SystemExit(2)
        print(result.stdout.strip())
        print('DONE: administrator permissions refreshed; no server restart needed.')

if __name__ == '__main__':
    main()
