#!/usr/bin/env python3
"""Empty-server integration: auto-unload callback, guarded quit and one-shot restart.
Uses synthetic activity timestamps, not a real 30-minute wait. Temporarily
adds server-only test hooks to Confogl, restoring the production binary finally.
"""
import importlib.util
import json
from pathlib import Path
import subprocess
import time

base = Path.home()
spec = importlib.util.spec_from_file_location('idle_watch',base/'deploy/idle-watch.py')
watch=importlib.util.module_from_spec(spec);spec.loader.exec_module(watch)
from rcon import run
sm=base/'steamcmd/l4d2/left4dead2/addons/sourcemod'
source=sm/'scripting'
fixture=source/'confoglcompmod/ReqMatch.sp'
original_module=fixture.read_text()
binary=sm/'plugins/confoglcompmod.smx'
production=binary.read_bytes()
out={}
def empty():assert watch.humans()==0,'Human connecting/connected; refusing disruption'
def restart():
    empty();subprocess.run(['systemctl','--user','restart','l4d2'],check=True);time.sleep(12)
def cv(name,value):return run(f'sm_cvar {name} {value}')

empty()
try:
    main=original_module
    anchor='void RM_OnModuleStart()\n{'
    assert main.count(anchor)==1
    main=main.replace(anchor,anchor+'\n    RegServerCmd("sm_jjd_test_empty_unload", TestEmptyUnload);\n    RegServerCmd("sm_jjd_test_mode", TestMode);')
    main+='''
public Action TestEmptyUnload(int args) { CreateTimer(0.2, RM_MatchResetTimer); return Plugin_Handled; }
public Action TestMode(int args) { PrintToServer("JJD_TEST_MATCH loaded=%d active=%d",RM_bIsMatchModeLoaded,RM_bIsAMatchActive); return Plugin_Handled; }
'''
    fixture.write_text(main)
    sdk=base/'l4d2-mod/addons/sourcemod/scripting'
    subprocess.run([str(sdk/'sourcemod/spcomp'),str(source/'confoglcompmod.sp'),'-i'+str(source),'-i'+str(sdk/'sourcemod/include'),'-i'+str(sdk/'include'),'-o'+str(binary)],check=True)
    restart()
    out['fresh_empty']=watch.check();assert not out['fresh_empty']['seen']
    run('sm_jjd_test_empty_unload');time.sleep(1)
    out['after_automatic_unload_timer']=run('sm_jjd_test_mode')
    assert 'loaded=1 active=1' in out['after_automatic_unload_timer']
    cv('jjd_idle_seen_human',1);cv('jjd_idle_epoch',9);cv('jjd_idle_last_active',int(time.time())-240)
    out['four_minute_guard']=run('sm_jjd_idle_restart 9')
    assert 'cancelled' in out['four_minute_guard']
    cv('jjd_idle_last_active',int(time.time())-1900)
    out['stale_connection_token']=run('sm_jjd_idle_restart 8')
    assert 'cancelled' in out['stale_connection_token']
    now=time.monotonic();instance=watch.invocation()
    watch.save(dict(version=2,instance=instance,observed=now,empty_since=now-1801,epoch=8))
    out['brief_reconnect_resets_clock']=watch.check()
    assert out['brief_reconnect_resets_clock']['action']=='wait' and out['brief_reconnect_resets_clock']['idle']==0
    empty();now=time.monotonic()
    watch.save(dict(version=2,instance=instance,observed=now,empty_since=now-1801,epoch=9))
    out['eligible_empty']=watch.check()
    assert out['eligible_empty']['action']=='restart_requested'
    deadline=time.monotonic()+90
    while time.monotonic()<deadline:
        time.sleep(2)
        try:
            if watch.invocation()!=instance and 'epoch=' in run('sm_jjd_idle_check'):
                out['after_restart']=watch.check()
                if out['after_restart']['seen']:continue
                break
        except (OSError,ValueError,RuntimeError):pass
    else:raise AssertionError('Guarded quit did not yield a fresh process')
    assert out['after_restart']['action']=='wait' and not out['after_restart']['seen']
    out['still_empty']=watch.check();assert out['still_empty']['action']=='wait'
finally:
    binary.write_bytes(production)
    fixture.write_text(original_module)
    restart()
    out['final_guard']=run('sm_jjd_idle_check')
    out['final_server']=run('sm_jjd_status')
    (base/'deploy/idle-fix-test-result.json').write_text(json.dumps(out,ensure_ascii=False,indent=2))
    print(json.dumps(out,ensure_ascii=False,indent=2))
