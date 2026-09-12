#!/usr/bin/env python3
"""Keep Confogl's automatic empty unload from competing with guarded maintenance."""
from pathlib import Path
import shutil
import subprocess

base = Path.home()
sm = base/'steamcmd/l4d2/left4dead2/addons/sourcemod'
source = sm/'scripting'
module = source/'confoglcompmod/ReqMatch.sp'
text = module.read_text()
marker = '// Jiaojiedi: one owner for empty-server cleanup.'
if marker not in text:
    anchor = 'static void RM_Match_Unload(bool bForced = false)\n{'
    assert text.count(anchor) == 1, 'Upstream changed; review the empty-unload patch'
    text = text.replace(anchor, anchor + '''
    // Jiaojiedi: one owner for empty-server cleanup.
    // Explicit admin/config mode changes must still work.
    ConVar managedIdle = FindConVar("jjd_idle_managed");
    if (!bForced && managedIdle != null && managedIdle.BoolValue)
        return;
''')
    module.write_text(text)
sdk = base/'l4d2-mod/addons/sourcemod/scripting'
main = source/'confoglcompmod.sp'
main_text = main.read_text()
if not any(version in main_text for version in ('"2.5.0-jjd1"', '"2.5.0-jjd2"')):
    assert '"2.5.0"' in main_text, 'Upstream version changed; review the patch'
    main.write_text(main_text.replace('"2.5.0"', '"2.5.0-jjd1"', 1))
subprocess.run([str(sdk/'sourcemod/spcomp'), str(source/'confoglcompmod.sp'),
                '-i'+str(source), '-i'+str(sdk/'sourcemod/include'), '-i'+str(sdk/'include'),
                '-o'+str(base/'custom/confoglcompmod.smx')], check=True)
shutil.copy2(base/'custom/confoglcompmod.smx', sm/'plugins/confoglcompmod.smx')

rcon = base/'deploy/rcon.py'
text = rcon.read_text()
if "'sm_jjd_idle_restart'" not in text:
    text = text.replace("'sm_jjd_idle_check',", "'sm_jjd_idle_check', 'sm_jjd_idle_restart',")
    rcon.write_text(text)
overlay = base/'deploy/apply-customization.py'
text = overlay.read_text()
hook = "subprocess.run(['python3', str(BASE / 'deploy/install-idle-fix.py')], check=True)"
if hook not in text:
    overlay.write_text(text.rstrip()+'\n'+hook+'\n')
print('IDLE_FIX_INSTALLED; empty restart required')
