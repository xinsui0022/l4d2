#!/usr/bin/env python3
"""Install the maintained browser overlay and existing small-team switch fixes."""
from pathlib import Path
import re, shutil, subprocess
base = Path.home()
game = base/'steamcmd/l4d2/left4dead2'
sm = game/'addons/sourcemod'
custom = base/'custom'
for name in ('jjd_browser','jjd_browser_maps'):
    for src, dst in [(custom/f'{name}.smx',sm/f'plugins/{name}.smx'),
                     (custom/f'scripting/{name}.sp',sm/f'scripting/{name}.sp'),
                     (custom/f'gamedata/{name}.txt',sm/f'gamedata/{name}.txt')]:
        dst.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(src,dst)
shutil.copy2(custom/'configs/jjd_browser_maps.txt',sm/'configs/jjd_browser_maps.txt')
shared=game/'cfg/sharedplugins.cfg';text=shared.read_text()
for name in ('jjd_browser','jjd_browser_maps'):
    line=f'sm plugins load {name}.smx'
    if line not in text:text=text.rstrip()+'\n'+line+'\n'
shared.write_text(text)
cfg=game/'cfg/server.cfg';text=cfg.read_text()
text,count=re.subn(r'^hostname .*$', 'hostname "[CN] 纯净药抗"',text,flags=re.M)
assert count==1
for key in ('mv_maxplayers','sv_maxplayers'):
    pattern=rf'^sm_cvar {key}\s+[^\n]*'
    if re.search(pattern,text,re.M):text=re.sub(pattern,f'sm_cvar {key} 12',text,flags=re.M)
    else:text=text.rstrip()+f'\nsm_cvar {key} 12\n'
text=re.sub(r'^(sv_tags\s+")([^"]*)(")',lambda m:m[1]+','.join(t for t in m[2].split(',') if t!='test')+m[3],text,flags=re.M)
cfg.write_text(text)
# Keep the previously deployed jjd2 fixes when restoring the public source overlay.
module=sm/'scripting/confoglcompmod/ReqMatch.sp';text=module.read_text()
marker='// Keep the game thread awake while a config switch is in progress.'
if marker not in text:
    pairs=[('if (!RM_hAutoLoad.BoolValue || RM_bIsAMatchActive)',
            'if (!RM_hAutoLoad.BoolValue || RM_bIsAMatchActive || RM_bIsChmatchRequest)'),
           ('RM_hSbAllBotGame.SetInt(0);',marker+'\n\t\tif (!RM_bIsChmatchRequest)\n\t\t\tRM_hSbAllBotGame.SetInt(0);'),
           ('RM_bIsChmatchRequest = true;\n\n\tRM_Match_Unload(true);',
            'RM_bIsChmatchRequest = true;\n\tFindConVar("sv_hibernate_when_empty").SetInt(0);\n\tRM_hSbAllBotGame.SetInt(1);\n\n\tRM_Match_Unload(true);')]
    for old,new in pairs:
        assert text.count(old)==1,'Confogl changed; review switch patch'
        text=text.replace(old,new,1)
    module.write_text(text)
    main=sm/'scripting/confoglcompmod.sp';text=main.read_text()
    assert '"2.5.0-jjd1"' in text,'Run install-idle-fix.py first'
    main.write_text(text.replace('"2.5.0-jjd1"','"2.5.0-jjd2"',1))
    sdk=sm/'scripting'
    subprocess.run([str(sdk/'sourcemod/spcomp'),str(main),'-i'+str(sdk),'-i'+str(sdk/'include'),'-i'+str(sdk/'sourcemod/include'),'-o'+str(custom/'confoglcompmod.smx')],check=True)
    shutil.copy2(custom/'confoglcompmod.smx',sm/'plugins/confoglcompmod.smx')
print('Official overlay installed. Reload/restart only when the server is empty.')
