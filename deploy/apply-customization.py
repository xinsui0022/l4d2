#!/usr/bin/env python3
"""Apply Jiaojiedi's maintained overlay without reinstalling the game or ZoneMod."""
from pathlib import Path
import re
import shutil
import subprocess
from public_settings import apply_public_settings

BASE = Path('/home/l4d2')
GAME = BASE / 'steamcmd/l4d2/left4dead2'
SM = GAME / 'addons/sourcemod'
cfg = GAME / 'cfg/server.cfg'
apply_public_settings(cfg)
(GAME / 'mymotd.txt').write_text('http://YOUR_SERVER_IP/l4d2/welcome.html\n')
(GAME / 'myhost.txt').write_text('http://YOUR_SERVER_IP/l4d2/banner.html\n')

admins = SM / 'configs/admins_simple.ini'
text = admins.read_text()
text = '\n'.join(line for line in text.splitlines()
    if not re.match(r'^\s*"(?:STEAM_[01]:1:YOUR_ACCOUNT_ID|YOUR_STEAM64)"', line)
    and line.strip() != '// Jiaojiedi: YOUR_STEAM64')
admins.write_text(text.rstrip() + '\n\n// Jiaojiedi: YOUR_STEAM64\n"STEAM_1:0:YOUR_ACCOUNT_ID" "99:z"\n')

# Stock basevotes owns an admin-only sm_vote; the public menu replaces it.
old = SM / 'plugins/basevotes.smx'
if old.exists():
    disabled = SM / 'plugins/disabled'
    disabled.mkdir(exist_ok=True)
    old.replace(disabled / old.name)
shutil.copy2(BASE / 'custom/scripting/jjd_server.sp', SM / 'scripting/jjd_server.sp')
shutil.copy2(BASE / 'custom/jjd_server.smx', SM / 'plugins/jjd_server.smx')
if (BASE / 'custom/jjd_tank_tools.smx').exists():
    shutil.copy2(BASE / 'custom/jjd_tank_tools.smx', SM / 'plugins/jjd_tank_tools.smx')
    shutil.copy2(BASE / 'custom/scripting/jjd_tank_tools.sp', SM / 'scripting/jjd_tank_tools.sp')
shared = GAME / 'cfg/sharedplugins.cfg'
text = shared.read_text()
line = 'sm plugins load jjd_server.smx'
if not re.search(r'^\s*sm plugins load jjd_server\.smx\s*$', text, re.M):
    shared.write_text(text.rstrip() + '\n\n// Jiaojiedi server features, loaded with every match config.\n' + line + '\n')
if (BASE / 'custom/jjd_tank_tools.smx').exists():
    text = shared.read_text()
    line = 'sm plugins load jjd_tank_tools.smx'
    if line not in text:
        shared.write_text(text.rstrip() + '\n' + line + '\n')

units = BASE / '.config/systemd/user'
units.mkdir(parents=True, exist_ok=True)
for name in ('l4d2.service', 'l4d2-motd.service', 'l4d2-idle-check.service', 'l4d2-idle-check.timer'):
    shutil.copy2(BASE / 'deploy' / name, units / name)
subprocess.run(['systemctl', '--user', 'daemon-reload'], check=True)
subprocess.run(['systemctl', '--user', 'enable', '--now', 'l4d2-motd.service', 'l4d2-idle-check.timer'], check=True)
print('CUSTOMIZATION_APPLIED; restart the game when empty. ZoneMod locks plugin hot reloads.')

subprocess.run(['python3', str(BASE / 'deploy/install-stats.py')], check=True)
subprocess.run(['python3', str(BASE / 'deploy/install-features.py')], check=True)
subprocess.run(['python3', str(BASE / 'deploy/install-idle-fix.py')], check=True)
subprocess.run(['python3', str(BASE / 'deploy/install-player-update.py')], check=True)

subprocess.run(['python3', str(BASE / 'deploy/install-join-info.py')], check=True)
subprocess.run(['python3', str(BASE / 'deploy/install-official.py')], check=True)
