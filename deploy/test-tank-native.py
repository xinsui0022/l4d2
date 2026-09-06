"""Empty-server native smoke test using a temporary build, restored in finally."""
from pathlib import Path
import subprocess,time
from rcon import run
B=Path('/home/l4d2'); S=B/'l4d2-mod/addons/sourcemod/scripting'; C=B/'custom'; live=B/'steamcmd/l4d2/left4dead2/addons/sourcemod/plugins/jjd_tank_tools.smx'
def empty(): assert '0 humans' in run('status'),'Player joined; stop testing'
empty()
src=(C/'scripting/jjd_tank_tools.sp').read_text().replace('    window=CreateConVar','    RegServerCmd("sm_jjd_tank_verify", VerifyNative);\n    window=CreateConVar',1)
src+='''
public Action VerifyNative(int args)
{
    for(int i=1;i<=MaxClients;i++)if(IsClientInGame(i)&&!IsFakeClient(i))return Plugin_Handled;
    int dummy=CreateFakeClient("JJD permission test");
    if(!dummy){PrintToServer("JJD_TEST failed: no bot slot");return Plugin_Handled;}
    ChangeClientTeam(dummy,3);
    bool denied=!Root(dummy);
    SpawnCommand(dummy,0);
    TakeCommand(dummy,0);
    KickClient(dummy,"Test completed");
    int spawn=FindEntityByClassname(-1,"info_survivor_position");
    if(spawn==-1)spawn=FindEntityByClassname(-1,"info_player_start");
    if(spawn==-1){PrintToServer("JJD_TEST denied=%d no_start_entity",denied);return Plugin_Handled;}
    float pos[3],ang[3];GetEntPropVector(spawn,Prop_Data,"m_vecOrigin",pos);pos[2]+=80.0;
    int tank=L4D2_SpawnTank(pos,ang);
    PrintToServer("JJD_TEST nonadmin_denied=%d spawn_native_ok=%d",denied,Tank(tank));
    if(Tank(tank))KickClient(tank,"Test completed");
    return Plugin_Handled;
}
'''
(C/'test-jjd-tank.sp').write_text(src)
subprocess.run([str(S/'sourcemod/spcomp'),str(C/'test-jjd-tank.sp'),'-i'+str(S/'sourcemod/include'),'-i'+str(S/'include'),'-o'+str(C/'test-jjd-tank.smx')],check=True)
import shutil
try:
    shutil.copy2(C/'test-jjd-tank.smx',live)
    subprocess.run(['systemctl','--user','restart','l4d2'],check=True)
    time.sleep(15);empty()
    result=run('sm_jjd_tank_verify')
    print(result,flush=True)
    assert 'nonadmin_denied=1 spawn_native_ok=1' in result
    (B/'deploy/tank-test-result.txt').write_text(result)
finally:
    shutil.copy2(C/'jjd_tank_tools.smx',live)
    empty();subprocess.run(['systemctl','--user','restart','l4d2'],check=True)
    print('PRODUCTION_RESTORED',run('sm_jjd_tank_status'),flush=True)
