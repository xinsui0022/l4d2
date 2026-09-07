#!/usr/bin/env python3
"""Install the maintained visual/cosmetic overlay, including on a restored host."""
from pathlib import Path
import re
import shutil

base = Path.home()
sm = base / 'steamcmd/l4d2/left4dead2/addons/sourcemod'
for name in ('jjd_visuals', 'jjd_fun', 'l4d2_tankrage'):
    destination = sm / 'plugins'
    if name == 'l4d2_tankrage':
        destination /= 'optional'
    destination.mkdir(parents=True, exist_ok=True)
    shutil.copy2(base / f'custom/{name}.smx', destination / f'{name}.smx')
    shutil.copy2(base / f'custom/scripting/{name}.sp', sm / f'scripting/{name}.sp')

shared = base / 'steamcmd/l4d2/left4dead2/cfg/sharedplugins.cfg'
text = shared.read_text()
for name in ('jjd_visuals', 'jjd_fun'):
    line = f'sm plugins load {name}.smx'
    if line not in text:
        text = text.rstrip() + '\n' + line + '\n'
shared.write_text(text)

build = base / 'deploy/build-plugins.sh'
text = build.read_text()
match = re.search(r'for plugin in ([^;\n]+);', text)
assert match, 'Expected the maintained plugin compiler loop'
names = match.group(1).split()
for name in ('jjd_visuals', 'jjd_fun', 'l4d2_tankrage'):
    if name not in names:
        names.append(name)
text = text[:match.start(1)] + ' '.join(names) + text[match.end(1):]
build.write_text(text)

overlay = base / 'deploy/apply-customization.py'
text = overlay.read_text()
hook = "subprocess.run(['python3', str(BASE / 'deploy/install-features.py')], check=True)"
if hook not in text:
    overlay.write_text(text.rstrip() + '\n' + hook + '\n')
print('VISUAL_AND_FUN_FEATURES_INSTALLED; restart the game while empty')
