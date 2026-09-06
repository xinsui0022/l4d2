#!/usr/bin/env python3
"""Install the pinned official tree after SteamCMD validation has completed."""
from pathlib import Path
import json
import re
import secrets
import shutil
import subprocess

base = Path('/home/l4d2')
source = base / 'l4d2-mod'
game = base / 'steamcmd/l4d2'
target = game / 'left4dead2'
assert (source / 'addons/sourcemod/plugins/confoglcompmod.smx').is_file()
assert 'BASE_INSTALL_COMPLETE' in (base / 'logs/base-install.log').read_text(errors='replace')
for folder in ('addons', 'cfg', 'scripts'):
    shutil.copytree(source / folder, target / folder, dirs_exist_ok=True)
for filename in ('host.txt', 'motd.txt', 'myhost.txt', 'mymotd.txt'):
    shutil.copy2(source / filename, target / filename)

cfg = (source / 'cfg/server.cfg').read_text()
changes = {
    'hostname': '"l4d2 | ZoneMod 2.9.1b | 4v4"',
    'rcon_password': '""',
    'sv_steamgroup': '""',
    'sv_search_key': '"l4d2_zonemod"',
    'sv_steamgroup_exclusive': '"0"',
}
for key, value in changes.items():
    cfg, count = re.subn(r'^' + re.escape(key) + r'\s+[^\n]*', key + ' ' + value, cfg, flags=re.M)
    assert count == 1, (key, count)
cfg = re.sub(r'^sm_cvar mv_maxplayers\s+[^\n]*', 'sm_cvar mv_maxplayers 8', cfg, flags=re.M)
cfg += '''
// l4d2 MVP: use the official ZoneMod rules and auto-load on connection.
sv_lan 0
sv_password ""
sm_cvar confogl_match_autoload 1
sm_cvar confogl_match_autoconfig "zonemod"
exec private_server.cfg
'''
(target / 'cfg/server.cfg').write_text(cfg)
secret = target / 'cfg/private_server.cfg'
if not secret.exists():
    secret.write_text('rcon_password "' + secrets.token_hex(24) + '"\n')
secret.chmod(0o600)
# Keep the upstream server language: some LANG_SERVER phrases have no Chinese
# entries. Individual clients can still use translations supplied upstream.
for optional_cfg in ('confogl_rates.cfg', 'confogl_personalize.cfg'):
    path = target / 'cfg' / optional_cfg
    if not path.exists():
        path.write_text('// Optional local overrides; rates are set in server.cfg.\n')
(target / 'myhost.txt').write_text('l4d2 ZoneMod 4v4\n')
(target / 'mymotd.txt').write_text('l4d2 ZoneMod 2.9.1b | 4v4\nReady: !ready | Unready: !unready | Pause: !pause | Spectate: !spec\n')
for binary in (game / 'srcds_run', game / 'srcds_linux'):
    binary.chmod(binary.stat().st_mode | 0o100)
sdk = base / '.steam/sdk32'
sdk.mkdir(parents=True, exist_ok=True)
steamclient = sdk / 'steamclient.so'
if not steamclient.exists():
    steamclient.symlink_to(base / 'steamcmd/linux32/steamclient.so')
units = base / '.config/systemd/user'
units.mkdir(parents=True, exist_ok=True)
shutil.copy2(base / 'deploy/l4d2.service', units / 'l4d2.service')
record = {
    'source': 'https://github.com/SirPlease/L4D2-Competitive-Rework',
    'commit': (base / 'downloads/competitive-commit.txt').read_text().strip(),
    'mode': 'zonemod', 'zonemod': '2.9.1b', 'tickrate': 100,
    'players': 8, 'game_directory': str(game), 'port': 27015,
    'legacy_files_policy': 'Reference only; not maintained, backed up, or used for rollback.',
}
(base / 'deploy/installed-version.json').write_text(json.dumps(record, indent=2) + '\n')
overlay = base / 'deploy/apply-customization.py'
if overlay.exists() and (base / 'custom/jjd_server.smx').exists():
    subprocess.run(['python3', str(overlay)], check=True)
subprocess.run(['systemctl', '--user', 'daemon-reload'], check=True)
print('CONFIGURATION_COMPLETE')
