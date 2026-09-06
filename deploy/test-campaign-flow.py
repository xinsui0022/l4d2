#!/usr/bin/env python3
"""Empty-server integration harness. Installs a temporary diagnostic build,
injects the engine end-game message, then restores the production binary.
Never run while players are using the server.
"""
from pathlib import Path
import json
import shutil
import subprocess
import time
from rcon import run

BASE = Path('/home/l4d2')
CUSTOM = BASE / 'custom'
SCRIPTS = BASE / 'l4d2-mod/addons/sourcemod/scripting'
LIVE = BASE / 'steamcmd/l4d2/left4dead2/addons/sourcemod/plugins/jjd_server.smx'

def empty():
    assert '0 humans' in run('status'), 'A human joined; abort maintenance test'

def ready():
    deadline = time.monotonic() + 60
    while time.monotonic() < deadline:
        try:
            result = run('sm_jjd_status')
            if 'JJD_STATUS' in result:
                return result
        except OSError:
            pass
        time.sleep(1)
    raise AssertionError('Custom plugin not available')

empty()
source = (CUSTOM / 'scripting/jjd_server.sp').read_text()
source = source.replace('    TouchActivity();\n}',
    '    RegServerCmd("sm_jjd_verify_end", VerifyEnd);\n'
    '    RegServerCmd("sm_jjd_verify_seed", VerifySeed);\n'
    '    TouchActivity();\n}', 1)
source += '''
public Action VerifySeed(int args)
{
    if (HumanConnections() != 0) return Plugin_Handled;
    L4D2Direct_SetVSCampaignScore(0, 123);
    L4D2Direct_SetVSCampaignScore(1, 456);
    GameRules_SetProp("m_iCampaignScore", 123, _, 0);
    GameRules_SetProp("m_iCampaignScore", 456, _, 1);
    return Plugin_Handled;
}
public Action VerifyEnd(int args)
{
    if (HumanConnections() != 0) return Plugin_Handled;
    int clients[1];
    Handle message = StartMessage("PZEndGamePanelMsg", clients, 0, USERMSG_RELIABLE);
    BfWriteByte(message, 0);
    EndMessage();
    PrintToServer("JJD_TEST end-game message injected");
    return Plugin_Handled;
}
'''
test_source = CUSTOM / 'test-jjd-server.sp'
test_binary = CUSTOM / 'test-jjd-server.smx'
test_source.write_text(source)
subprocess.run([str(SCRIPTS / 'sourcemod/spcomp'), str(test_source),
    '-i' + str(SCRIPTS / 'sourcemod/include'), '-i' + str(SCRIPTS / 'include'),
    '-o' + str(test_binary)], check=True)
out = {'method': 'synthetic engine end-game message, real campaign change and score reset'}
try:
    shutil.copy2(test_binary, LIVE)
    empty()
    subprocess.run(['systemctl', '--user', 'restart', 'l4d2'], check=True)
    ready()
    # Confogl schedules its initial map restart after loading the rules.
    # Let that finish before issuing a separate maintenance map change.
    time.sleep(15)
    empty()
    run('changelevel c2m5_concert')
    deadline = time.monotonic() + 60
    while time.monotonic() < deadline:
        try:
            if 'map=c2m5_concert' in ready(): break
        except OSError:
            pass
        time.sleep(1)
    else: raise AssertionError('C2 finale did not load')
    time.sleep(5)
    empty()
    run('sm_jjd_verify_seed')
    out['before'] = run('sm_jjd_status').strip()
    assert 'map=c2m5_concert' in out['before'] and 'scores=123:456' in out['before']
    out['message'] = run('sm_jjd_verify_end').strip()
    out['queued'] = run('sm_jjd_status').strip()
    assert 'finale_queued=1' in out['queued'], 'Engine end-game hook did not queue a new campaign'
    deadline = time.monotonic() + 65
    while time.monotonic() < deadline:
        time.sleep(2)
        try:
            current = run('sm_jjd_status')
            if 'map=c5m1_waterfront' in current and 'fresh_pending= scores=0:0' in current:
                out['after'] = current.strip()
                break
        except OSError:
            pass
    else: raise AssertionError('C5 fresh campaign was not ready')
    empty()
    out['invalid_map'] = run('sm_jjd_newcampaign invalid_map').strip()
    assert 'JJD_ERROR' in out['invalid_map']
    print(json.dumps(out, ensure_ascii=False, indent=2), flush=True)
    (BASE / 'deploy/campaign-test-result.json').write_text(json.dumps(out, ensure_ascii=False, indent=2) + '\n')
finally:
    shutil.copy2(CUSTOM / 'jjd_server.smx', LIVE)
    empty()
    subprocess.run(['systemctl', '--user', 'restart', 'l4d2'], check=True)
    print('PRODUCTION_RESTORED', ready(), flush=True)
