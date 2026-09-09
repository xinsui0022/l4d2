#!/usr/bin/env python3
"""Install Jiaojiedi v2 player features; safe to reapply after restore/config setup."""
from pathlib import Path
import re
import shutil

base = Path.home()
game = base / 'steamcmd/l4d2/left4dead2'
sm = game / 'addons/sourcemod'
for name in ('jjd_player_info', 'l4d2_unsilent_jockey', 'l4d2_playstats'):
    dest = sm / 'plugins'
    if name != 'jjd_player_info':
        dest /= 'optional'
    shutil.copy2(base / f'custom/{name}.smx', dest / f'{name}.smx')
    shutil.copy2(base / f'custom/scripting/{name}.sp', sm / f'scripting/{name}.sp')
shutil.copy2(base / 'custom/scripting/jjd_round_report.inc', sm / 'scripting/jjd_round_report.inc')
# SourceMod's command iterator also contains server-only callbacks. Its public API
# does not expose that distinction; derive the exclusion list from installed source.
server_commands, player_commands = set(), set()
for source in (sm / 'scripting').rglob('*.sp'):
    text = source.read_text(errors='replace')
    server_commands.update(re.findall(r'RegServerCmd\s*\(\s*"([^"]+)"', text))
    player_commands.update(re.findall(r'Reg(?:Console|Admin)Cmd\s*\(\s*"([^"]+)"', text))
(sm / 'configs/jjd-server-commands.txt').write_text('\n'.join(sorted(server_commands - player_commands)) + '\n')
shared = game / 'cfg/sharedplugins.cfg'
text = shared.read_text()
line = 'sm plugins load jjd_player_info.smx'
if line not in text:
    shared.write_text(text.rstrip() + '\n' + line + '\n')

# The mode cvar manager owns these values; change its source, not only the live cvar.
config = game / 'cfg/cfgogl/zonemod/shared_cvars.cfg'
text, n = re.subn(r'(?m)^confogl_addcvar tankcontrol_print_all\s+\S+', 'confogl_addcvar tankcontrol_print_all 0', config.read_text())
assert n == 1, 'Tank audience setting changed upstream; inspect before deployment'
config.write_text(text)
config = game / 'cfg/cfgogl/zonemod/zonemod.cfg'
text = config.read_text()
settings_anchor = 'exec cfgogl/zonemod/shared_settings.cfg'
assert text.count(settings_anchor) == 1, 'Expected ZoneMod shared settings include'
player_settings = []
for name, value in (('jjd_progress_interval', '30'), ('jjd_round_report', '1'),
                    ('sm_survivor_mvp_enabled', '0'), ('sm_stats_autoprint_vs_round', '8324')):
    # Keep the detailed console tables; the maintained Chinese summary owns automatic chat.
    pattern = rf'(?m)^confogl_addcvar {name}\s+[^\n]+'
    line = f'confogl_addcvar {name} {value}'
    text = re.sub(pattern + r'\n?', '', text)
    player_settings.append(line)
# shared_settings.cfg executes confogl_setcvars, which rejects later additions.
# Register all maintained cvars BEFORE that include, including on repeated installs.
text = text.replace(settings_anchor, '\n'.join(player_settings) + '\n' + settings_anchor)
config.write_text(text)
print('PLAYER_UPDATE_INSTALLED; restart only while empty')
