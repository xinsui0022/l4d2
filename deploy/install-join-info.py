#!/usr/bin/env python3
from pathlib import Path
import shutil

base = Path.home()
game = base / 'steamcmd/l4d2/left4dead2'
sm = game / 'addons/sourcemod'
database_dir = sm / 'data/sqlite'
database_dir.mkdir(parents=True, exist_ok=True)
database_dir.chmod(0o700)
database = database_dir / 'jjd_visitors.sq3'
if database.exists():
    database.chmod(0o600)
for folder, suffix in (('scripting', 'sp'), ('plugins', 'smx')):
    source = base / 'custom' / ('scripting/jjd_join_info.sp' if suffix == 'sp' else 'jjd_join_info.smx')
    shutil.copy2(source, sm / folder / ('jjd_join_info.' + suffix))
shared = game / 'cfg/sharedplugins.cfg'
text = shared.read_text()
line = 'sm plugins load jjd_join_info.smx'
if line not in text.splitlines():
    shared.write_text(text.rstrip() + '\n' + line + '\n')
