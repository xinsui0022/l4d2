#!/usr/bin/env python3
"""Empty-server engine checks using temporary variants; restore production in finally."""
from pathlib import Path
import importlib.util
import json
import re
import shutil
import subprocess
import time

b = Path.home()
sm = b / 'steamcmd/l4d2/left4dead2/addons/sourcemod'
sdk = b / 'l4d2-mod/addons/sourcemod/scripting'
def run(*cmd): return subprocess.check_output(cmd, text=True)
def rcon(cmd): return run('python3', str(b/'deploy/rcon.py'), cmd)
def empty(): assert re.search(r'players\s*:\s*0 humans',rcon('status')), 'Requires an empty server'
def restart():
    empty()
    run('systemctl','--user','restart','l4d2')
    for _ in range(25):
        time.sleep(1)
        try:
            if 'JJD_INFO' in rcon('sm_jjd_info_status') and 'JJD_REPORT' in rcon('sm_jjd_report_status'):
                time.sleep(7)
                return
        except (subprocess.CalledProcessError, OSError): pass
    raise RuntimeError('Server did not become ready')

empty()
sources = {}
s=(b/'custom/scripting/l4d2_playstats.sp').read_text()
s=s.replace('JJD_ReportInit();','JJD_ReportInit();\n RegServerCmd("sm_jjd_report_test", ReportTest);',1)
s+='''
public Action ReportTest(int args) {
 g_iCurTeam=0; g_iPlayers=8; g_bInRound=true; g_bModeCampaign=false; jjdReportLive=true;
 for(int i=0;i<8;i++)for(int t=0;t<2;t++) {
  for(int m=0;m<=MAXPLYSTATS;m++)g_strRoundPlayerData[i][t][m]=0;
  for(int m=0;m<=MAXINFSTATS;m++)g_strRoundPlayerInfData[i][t][m]=0;
 }
 strcopy(g_sPlayerName[4],MAXNAME,"SurvivorA");strcopy(g_sPlayerName[5],MAXNAME,"SurvivorB");
 strcopy(g_sPlayerName[6],MAXNAME,"InfectedA");strcopy(g_sPlayerName[7],MAXNAME,"InfectedB");
 g_strRoundPlayerData[4][0][plyTimeStartPresent]=1;g_strRoundPlayerData[5][0][plyTimeStartPresent]=1;
 g_strRoundPlayerInfData[6][0][infTimeStartPresent]=1;g_strRoundPlayerInfData[7][0][infTimeStartPresent]=1;
 g_strRoundPlayerData[4][0][plySIDamage]=1000;g_strRoundPlayerData[4][0][plyTankDamage]=500;
 g_strRoundPlayerData[4][0][plyFFGivenTotal]=20;g_strRoundPlayerData[4][0][plyFFGivenSelf]=5;
 g_strRoundPlayerData[5][0][plySIDamage]=100;g_strRoundPlayerData[5][0][plyFFTakenTotal]=15;
 g_strRoundPlayerInfData[6][0][infDmgUpright]=100;g_strRoundPlayerInfData[6][0][infDmgTank]=40;
 g_strRoundPlayerInfData[6][0][infDmgTotal]=125;g_strRoundPlayerInfData[6][0][infDmgTankIncap]=15;
 g_strRoundPlayerInfData[7][0][infDmgUpright]=20;g_strRoundPlayerInfData[7][0][infDmgTotal]=20;
 int before=jjdReports;
 HandleRoundEnd(); HandleRoundEnd();
 PrintToServer("REPORT_TEST duplicate_guard=%d",jjdReports==before+1);
 g_iCurTeam=1;JJD_Report(); // Other half must not show the previous half's rows.
 g_iCurTeam=0;g_strRoundPlayerData[4][0][plyFFGivenTotal]=5;
 g_strRoundPlayerInfData[7][0][infDmgUpright]=140;JJD_Report();
 return Plugin_Handled;
}
'''
sources['l4d2_playstats']=s
s=(b/'custom/scripting/jjd_player_info.sp').read_text()
s=s.replace('interval = CreateConVar','RegServerCmd("sm_jjd_info_test", InfoTest);\n    interval = CreateConVar',1)
s+='''
public Action InfoTest(int args) {
 int total, publicCount;bool adminFound, commandsFound, serverOnlyFound;
 Handle it=GetCommandIterator();char cmd[80];int flags;
 while(ReadCommandIterator(it,cmd,sizeof(cmd),flags)) {
  total++;if(flags==0)publicCount++;
  if(StrEqual(cmd,"sm_spawntank")&&flags!=0)adminFound=true;
  if(StrEqual(cmd,"sm_commands"))commandsFound=true;
  if(StrEqual(cmd,"sm_jjd_idle_restart")) {
   char path[PLATFORM_MAX_PATH],line[80];BuildPath(Path_SM,path,sizeof(path),"configs/jjd-server-commands.txt");
   File f=OpenFile(path,"r");bool excluded;
   if(f!=null){while(f.ReadLine(line,sizeof(line))){TrimString(line);if(StrEqual(line,cmd))excluded=true;}delete f;}
   serverOnlyFound=!excluded;
  }
 }
 delete it;
 PrintProgress();
 OnRoundIsLive();bool enabled=live;Reset(null,"round_end",false);
 PrintToServer("INFO_TEST commands=%d admin_flags=%d server_only_listed=%d live_reset=%d total=%d public=%d",commandsFound,adminFound,serverOnlyFound,enabled&&!live,total,publicCount);
 return Plugin_Handled;
}
'''
sources['jjd_player_info']=s
s=(b/'custom/scripting/l4d2_unsilent_jockey.sp').read_text()
s=s.replace('// ConVars','RegServerCmd("sm_jjd_jockey_test", JockeyTest);\n\t// ConVars',1)
s+='''
public Action JockeyTest(int args) {
 float pos[3],ang[3];int ent=FindEntityByClassname(-1,"info_survivor_position");
 if(ent==-1){PrintToServer("JOCKEY_TEST no_position");return Plugin_Handled;}
 GetEntPropVector(ent,Prop_Send,"m_vecOrigin",pos);pos[2]+=60.0;
 int c=L4D2_SpawnSpecial(5,pos,ang);
 if(c<=0){PrintToServer("JOCKEY_TEST no_spawn");return Plugin_Handled;}
 SetEntProp(c,Prop_Send,"m_isGhost",0);
 bool valid=ValidJockey(c);ChangeJockeyTimerStatus(c,true);bool timer=g_hJockeySoundTimer[c]!=null;
 SetEntProp(c,Prop_Send,"m_isGhost",1);bool ghost=!ValidJockey(c);
 SetEntProp(c,Prop_Send,"m_isGhost",0);SetEntProp(c,Prop_Send,"m_zombieClass",8);bool tank=!ValidJockey(c);
 SetEntProp(c,Prop_Send,"m_zombieClass",5);ChangeJockeyTimerStatus(c,false);bool stopped=g_hJockeySoundTimer[c]==null;
 ChangeJockeyTimerStatus(0,false);
 PrintToServer("JOCKEY_TEST alive=%d timer=%d ghost_blocked=%d tank_blocked=%d cleanup=%d",valid,timer,ghost,tank,stopped);
 KickClient(c,"test complete");return Plugin_Handled;
}
'''
sources['l4d2_unsilent_jockey']=s

temps=[]
try:
    # Fixture output is captured from the plugin's existing report logging.
    for name, source in sources.items():
        src=b/f'custom/scripting/test-jjd-{name}.sp';binary=b/f'custom/test-jjd-{name}.smx'
        src.write_text(source);temps.extend([src,binary])
        result=subprocess.run([str(sdk/'sourcemod/spcomp'),str(src),'-i'+str(sdk/'sourcemod/include'),'-i'+str(sdk/'include'),'-o'+str(binary)],capture_output=True,text=True)
        assert result.returncode==0,result.stdout
        dest=sm/'plugins'
        if name!='jjd_player_info': dest/='optional'
        shutil.copy2(binary,dest/f'{name}.smx')
    restart()
    info=rcon('sm_jjd_info_test');print(info,flush=True)
    assert 'commands=1 admin_flags=1 server_only_listed=0 live_reset=1' in info
    jockey=rcon('sm_jjd_jockey_test');print(jockey,flush=True)
    assert 'alive=1 timer=1 ghost_blocked=1 tank_blocked=1 cleanup=1' in jockey
    report=rcon('sm_jjd_report_test');print(report,flush=True)
    assert 'duplicate_guard=1' in report
    logs='\n'.join(p.read_text(errors='replace') for p in (sm/'logs').glob('L*.log'))
    assert '[MVP][LVP]SurvivorA：特感 1000 | 克 500 | 小丧尸 0 | 友伤 15/受 0' in logs
    assert '[MVP]InfectedA：输出 140（克 40）| 倒地 40' in logs
    assert '[LVP]InfectedB：输出 20' in logs
    assert '[生还 LVP] 无友伤，无人上榜。' in logs
    assert '[MVP]InfectedB：输出 140' in logs
    assert '"0"' in rcon('tankcontrol_print_all')
    spec=importlib.util.spec_from_file_location('admin',b/'deploy/add-admin.py');admin=importlib.util.module_from_spec(spec);spec.loader.exec_module(admin)
    value='https://steamcommunity.com/profiles/76561199191371037/'
    assert admin.steam_identity(value)[1]=='STEAM_1:1:615552654'
    fixture='// keep\n"STEAM_0:1:615552654" "b"\n"STEAM_1:0:12345" "b"\n'
    updated=admin.update_text(fixture,value)
    assert updated==admin.update_text(updated,value) and 'STEAM_1:0:12345' in updated and updated.count('99:z')==1
    for bad in ('https://evil.example/profiles/76561199191371037/','76561199191371037;quit','https://steamcommunity.com/id/test','76561197960265728'):
        try: admin.steam_identity(bad)
        except ValueError: pass
        else: raise AssertionError('Accepted invalid ID')
    result={'engine_checks':True,'command_directory_and_admin_flags':True,'server_only_commands_excluded':True,
      'jockey_alive_ghost_tank_cleanup':True,'report_duplicate_guard':True,'report_damage_splits_and_ties':True,
      'tank_audience_cvar':0,'admin_conversion_idempotency_validation':True,
      'human_audio_and_chat_visual_tested':False}
    (b/'deploy/player-update-test-result.json').write_text(json.dumps(result,indent=2))
    print(json.dumps(result),flush=True)
finally:
    for name in sources:
        dest=sm/'plugins'
        if name!='jjd_player_info':dest/='optional'
        shutil.copy2(b/f'custom/{name}.smx',dest/f'{name}.smx')
    restart()
    for p in temps:p.unlink(missing_ok=True)
