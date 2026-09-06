from pathlib import Path
import shutil,subprocess
base=Path.home(); sm=base/'steamcmd/l4d2/left4dead2/addons/sourcemod'
shutil.copy2(base/'custom/jjd_stats.sp',base/'custom/scripting/jjd_stats.sp')
shutil.copy2(base/'custom/jjd_stats.smx',sm/'plugins/jjd_stats.smx')
shutil.copy2(base/'custom/jjd_stats.sp',sm/'scripting/jjd_stats.sp')
shutil.copy2(base/'custom/stats-schema.sql',sm/'configs/jjd-stats-schema.sql')
cfg=sm/'configs/databases.cfg'; text=cfg.read_text()
if '"jjd_stats"' not in text:
    end=text.rfind('}'); assert end>=0
    text=text[:end]+'\n "jjd_stats"\n {\n "driver" "sqlite"\n "database" "jjd_stats"\n }\n'+text[end:];cfg.write_text(text)
cfg.chmod(0o600)
shared=base/'steamcmd/l4d2/left4dead2/cfg/sharedplugins.cfg';text=shared.read_text()
if 'sm plugins load jjd_stats.smx' not in text:shared.write_text(text+'\nsm plugins load jjd_stats.smx\n')
build=base/'deploy/build-plugins.sh';text=build.read_text().replace('for plugin in jjd_server jjd_tank_tools;', 'for plugin in jjd_server jjd_tank_tools jjd_stats;');build.write_text(text)
overlay=base/'deploy/apply-customization.py';text=overlay.read_text()
hook="subprocess.run(['python3', str(BASE / 'deploy/install-stats.py')], check=True)"
if hook not in text:overlay.write_text(text+'\n'+hook+'\n')
# Explicitly mark admin practice, even when the Tank is later removed.
tank=base/'custom/scripting/jjd_tank_tools.sp';text=tank.read_text()
if 'void MarkStatsPractice()' not in text:
    text=text.replace('if(Tank(tank)){LogAction', 'if(Tank(tank)){MarkStatsPractice();LogAction')
    text=text.replace('L4D_TakeOverZombieBot(c,bot);LogAction', 'MarkStatsPractice();L4D_TakeOverZombieBot(c,bot);LogAction')
    text+='\nvoid MarkStatsPractice(){ConVar cv=FindConVar("jjd_stats_practice");if(cv!=null)cv.SetInt(1);}\n'
    tank.write_text(text)
print('STATS_INSTALLED')
