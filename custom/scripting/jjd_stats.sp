#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

public Plugin myinfo={name="Jiaojiedi Ranking",author="Jiaojiedi",description="Audited half-round contribution ranking",version="1.0.0"};
#define SLOTS 64
enum { Common, SIDamage, TankDamage, Saves, Revives, InfectedDamage, TankAttack, Friendly, SIKills, Metrics }
Database db;
bool ready,live,eligible;
ConVar practice,practiceMap;
char ids[SLOTS][32],names[SLOTS][128],halfId[96],mapName[64],reason[64],pending[PLATFORM_MAX_PATH];
int counts[SLOTS][Metrics],slots;
float beforeHealth[MAXPLAYERS+1],lastSave[MAXPLAYERS+1],lastRevive[MAXPLAYERS+1];
bool beforeDown[MAXPLAYERS+1];
public void OnPluginStart()
{
    practice=CreateConVar("jjd_stats_practice","0","Chapter excluded from ranking",FCVAR_DONTRECORD);
    practiceMap=CreateConVar("jjd_stats_practice_map","","Practice chapter identity",FCVAR_DONTRECORD);
    RegConsoleCmd("sm_rank",RankCommand);RegConsoleCmd("sm_stats",RankCommand);RegConsoleCmd("sm_top",TopCommand);
    RegAdminCmd("sm_practice",PracticeCommand,ADMFLAG_ROOT);
    RegServerCmd("sm_jjd_stats_status",StatusCommand);
    HookEvent("round_start",RoundStart);HookEvent("round_end",RoundEnd);HookEvent("map_transition",RoundEnd);
    HookEvent("infected_death",CommonDeath);HookEvent("player_death",PlayerDeath);HookEvent("revive_success",Revive);
    BuildPath(Path_SM,pending,sizeof(pending),"data/jjd-stats-pending");CreateDirectory(pending,448);
    for(int c=1;c<=MaxClients;c++)if(IsClientInGame(c))OnClientPutInServer(c);
    CreateTimer(2.0,Guard,_,TIMER_REPEAT);
    CreateTimer(60.0,RetryPending,_,TIMER_REPEAT);
    Database.Connect(Connected,"jjd_stats");
}
public void OnMapStart()
{
    GetCurrentMap(mapName,sizeof(mapName));char previous[64];practiceMap.GetString(previous,sizeof(previous));
    if(!StrEqual(previous,mapName)){practice.SetInt(0);practiceMap.SetString(mapName);}
    live=false;
}
public void OnClientPutInServer(int c){SDKHook(c,SDKHook_OnTakeDamage,BeforeDamage);SDKHook(c,SDKHook_OnTakeDamagePost,AfterDamage);}
bool Human(int c){return c>0&&c<=MaxClients&&IsClientInGame(c)&&!IsFakeClient(c);}
bool TeamsReady(){int s,i;for(int c=1;c<=MaxClients;c++)if(Human(c)){if(GetClientTeam(c)==2)s++;if(GetClientTeam(c)==3)i++;}return s>=2&&i>=2;}
void Exclude(const char[] why){eligible=false;strcopy(reason,sizeof(reason),why);}
public Action Guard(Handle timer){if(live){if(practice.BoolValue)Exclude("practice");else if(FindConVar("sv_cheats").BoolValue){practice.SetInt(1);Exclude("cheats");}else if(!TeamsReady())Exclude("insufficient_humans");}return Plugin_Continue;}
public Action PracticeCommand(int c,int args){if(c!=0&&(!Human(c)||!CheckCommandAccess(c,"jjd_stats_root",ADMFLAG_ROOT,true)))return Plugin_Handled;practice.SetInt(1);Exclude("practice");ReplyToCommand(c,"[交界地] 当前章节已标记练习，不进入排行；换章节后恢复。");return Plugin_Handled;}
public void RoundStart(Event e,const char[] n,bool b){live=false;}
public void OnRoundIsLive()
{
    if(live)return;
    slots=0;for(int i=0;i<SLOTS;i++)for(int j=0;j<Metrics;j++)counts[i][j]=0;
    for(int c=1;c<=MaxClients;c++){lastSave[c]=-1000.0;lastRevive[c]=-1000.0;}
    GetCurrentMap(mapName,sizeof(mapName));Format(halfId,sizeof(halfId),"%d-%08x-%08x",GetTime(),GetURandomInt(),GetURandomInt());
    live=true;eligible=ready&&TeamsReady()&&!practice.BoolValue&&!FindConVar("sv_cheats").BoolValue;strcopy(reason,sizeof(reason),eligible?"ranked":"practice_or_not_ready");
    for(int c=1;c<=MaxClients;c++)if(Human(c)&&(GetClientTeam(c)==2||GetClientTeam(c)==3))Slot(c);
    PrintToChatAll("[交界地] 本半场%s。",eligible?"计入贡献排行":"为练习/人数不足，不计排行");
}
int Slot(int c)
{
    if(!Human(c))return -1;
    char steam[32];if(!GetClientAuthId(c,AuthId_SteamID64,steam,sizeof(steam)))return -1;
    int index=-1;for(int i=0;i<slots;i++)if(StrEqual(ids[i],steam)){index=i;break;}
    if(index==-1){if(slots>=SLOTS){Exclude("participant_limit");return -1;}index=slots++;strcopy(ids[index],sizeof(ids[]),steam);}
    GetClientName(c,names[index],sizeof(names[]));ReplaceString(names[index],sizeof(names[]),"\n"," ");ReplaceString(names[index],sizeof(names[]),"\r"," ");return index;
}
void Add(int c,int metric,int amount){if(!live||!eligible||practice.BoolValue||amount<=0)return;int i=Slot(c);if(i>=0)counts[i][metric]+=amount;}
public Action BeforeDamage(int victim,int &attacker,int &inflictor,float &damage,int &type)
{
    beforeDown[victim]=GetClientTeam(victim)==2&&GetEntProp(victim,Prop_Send,"m_isIncapacitated")!=0;
    beforeHealth[victim]=float(GetClientHealth(victim));
    if(GetClientTeam(victim)==2){float buffer=GetEntPropFloat(victim,Prop_Send,"m_healthBuffer")-(GetGameTime()-GetEntPropFloat(victim,Prop_Send,"m_healthBufferTime"))*FindConVar("pain_pills_decay_rate").FloatValue;if(buffer>0.0)beforeHealth[victim]+=buffer;}
    return Plugin_Continue;
}
public void AfterDamage(int victim,int attacker,int inflictor,float damage,int type)
{
    if(!live||!eligible||!Human(attacker)||attacker==victim||damage<=0.0)return;
    int amount=RoundToFloor(damage<beforeHealth[victim]?damage:beforeHealth[victim]);
    int a=GetClientTeam(attacker),v=GetClientTeam(victim);
    if(a==2&&v==3)Add(attacker,GetEntProp(victim,Prop_Send,"m_zombieClass")==8?TankDamage:SIDamage,amount);
    else if(v==2&&!beforeDown[victim]){
        if(a==2)Add(attacker,Friendly,amount);
        else if(a==3)Add(attacker,GetEntProp(attacker,Prop_Send,"m_zombieClass")==8?TankAttack:InfectedDamage,amount);
    }
}
public void CommonDeath(Event e,const char[] n,bool b){int c=GetClientOfUserId(e.GetInt("attacker"));if(Human(c)&&GetClientTeam(c)==2)Add(c,Common,1);}
public void PlayerDeath(Event e,const char[] n,bool b){int a=GetClientOfUserId(e.GetInt("attacker")),v=GetClientOfUserId(e.GetInt("userid"));if(Human(a)&&GetClientTeam(a)==2&&v>0&&IsClientInGame(v)&&GetClientTeam(v)==3&&GetEntProp(v,Prop_Send,"m_zombieClass")!=8)Add(a,SIKills,1);}
public void Revive(Event e,const char[] n,bool b){int c=GetClientOfUserId(e.GetInt("userid")),v=GetClientOfUserId(e.GetInt("subject"));if(Human(c)&&v>0&&c!=v&&!e.GetBool("ledge_hang")&&GetGameTime()-lastRevive[v]>30.0){lastRevive[v]=GetGameTime();Add(c,Revives,1);}}
public void OnSpecialClear(int clearer,int pinner,int victim,int zombieClass,float timeA,float timeB,bool withShove){if(Human(clearer)&&GetClientTeam(clearer)==2&&victim>0&&victim<=MaxClients&&clearer!=victim&&GetGameTime()-lastSave[victim]>2.0){lastSave[victim]=GetGameTime();Add(clearer,Saves,1);}}
int Points(int i){int common=counts[i][Common]/20;if(common>10)common=10;return common+counts[i][SIDamage]/100+counts[i][TankDamage]/500+3*counts[i][Saves]+2*counts[i][Revives]+counts[i][InfectedDamage]/10+counts[i][TankAttack]/20-counts[i][Friendly]/10;}
public void RoundEnd(Event e,const char[] n,bool b)
{
    if(!live)return;
    Guard(null);live=false;if(!ready)return;
    char file[PLATFORM_MAX_PATH];Format(file,sizeof(file),"%s/%s.sql",pending,halfId);
    File f=OpenFile(file,"w");if(f==null){LogError("Cannot persist settlement %s",halfId);return;}
    char query[2048],escaped[256];
    Format(query,sizeof(query),"INSERT OR IGNORE INTO halves(id,map,finished,eligible,reason) VALUES('%s','%s',%d,%d,'%s');",halfId,mapName,GetTime(),eligible?1:0,reason);f.WriteLine("%s",query);
    if(eligible)for(int i=0;i<slots;i++){
        db.Escape(names[i],escaped,sizeof(escaped));
        Format(query,sizeof(query),"INSERT OR REPLACE INTO players VALUES('%s','%s');",ids[i],escaped);f.WriteLine("%s",query);
        Format(query,sizeof(query),"INSERT OR IGNORE INTO contributions VALUES('%s','%s',%d,%d,%d,%d,%d,%d,%d,%d,%d,%d);",halfId,ids[i],Points(i),counts[i][Common],counts[i][SIDamage],counts[i][TankDamage],counts[i][Saves],counts[i][Revives],counts[i][InfectedDamage],counts[i][TankAttack],counts[i][Friendly],counts[i][SIKills]);f.WriteLine("%s",query);
    }
    f.Flush();delete f;Submit(file);
}
void Submit(const char[] file){File f=OpenFile(file,"r");if(f==null)return;Transaction t=new Transaction();char q[2048];while(f.ReadLine(q,sizeof(q))){TrimString(q);if(q[0])t.AddQuery(q);}delete f;DataPack p=new DataPack();p.WriteString(file);db.Execute(t,Committed,Failed,p);}
public void Committed(Database database,any data,int num,Handle[] results,any[] queryData){DataPack p=view_as<DataPack>(data);p.Reset();char file[PLATFORM_MAX_PATH];p.ReadString(file,sizeof(file));delete p;DeleteFile(file);}
public void Failed(Database database,any data,int num,const char[] error,int index,any[] queryData){delete view_as<DataPack>(data);LogError("Settlement retained for retry: %s",error);}
public void Connected(Database database,const char[] error,any data)
{
    if(database==null){LogError("Stats database unavailable: %s",error);return;}db=database;
    char path[PLATFORM_MAX_PATH];BuildPath(Path_SM,path,sizeof(path),"configs/jjd-stats-schema.sql");File f=OpenFile(path,"r");if(f==null){LogError("Missing stats schema");return;}
    Transaction t=new Transaction();char line[2048];while(f.ReadLine(line,sizeof(line))){TrimString(line);if(line[0])t.AddQuery(line);}delete f;db.Execute(t,SchemaReady,SchemaFailed);
}
public void SchemaReady(Database database,any data,int num,Handle[] results,any[] queryData){ready=true;RetryPending(null);}
public Action RetryPending(Handle timer){if(!ready)return Plugin_Continue;DirectoryListing d=OpenDirectory(pending);if(d==null)return Plugin_Continue;char name[PLATFORM_MAX_PATH],path[PLATFORM_MAX_PATH];FileType type;while(d.GetNext(name,sizeof(name),type))if(type==FileType_File&&StrContains(name,".sql")!=-1){Format(path,sizeof(path),"%s/%s",pending,name);Submit(path);}delete d;return Plugin_Continue;}
public void SchemaFailed(Database database,any data,int num,const char[] error,int index,any[] queryData){LogError("Stats schema failed: %s",error);}
public Action RankCommand(int c,int args)
{
    if(!Human(c))return Plugin_Handled;if(!ready){ReplyToCommand(c,"[交界地] 排行暂不可用。");return Plugin_Handled;}
    char steam[32],q[512];if(!GetClientAuthId(c,AuthId_SteamID64,steam,sizeof(steam)))return Plugin_Handled;
    Format(q,sizeof(q),"SELECT r.*,1+(SELECT COUNT(*) FROM ranking x WHERE x.score>r.score) AS place FROM ranking r WHERE steam='%s'",steam);db.Query(RankResult,q,GetClientUserId(c));return Plugin_Handled;
}
public void RankResult(Database database,DBResultSet r,const char[] error,any userid)
{
    int c=GetClientOfUserId(userid);if(!Human(c))return;if(r==null){LogError("Rank query: %s",error);PrintToChat(c,"[交界地] 查询失败，请稍后再试。");return;}if(!r.FetchRow()){PrintToChat(c,"[交界地] 暂无有效半场记录；双方至少各两名真人，练习局不计分。");return;}
    PrintToChat(c,"[交界地] 排名 #%d | 贡献 %d | 有效半场 %d",r.FetchInt(13),r.FetchInt(2),r.FetchInt(3));
    PrintToChat(c,"[交界地] 小丧尸 %d | 特感击杀 %d | 特感伤害 %d | 打克伤害 %d",r.FetchInt(4),r.FetchInt(12),r.FetchInt(5),r.FetchInt(6));
    PrintToChat(c,"[交界地] 解控 %d | 扶起 %d | 特感输出 %d | 克输出 %d | 友伤 %d",r.FetchInt(7),r.FetchInt(8),r.FetchInt(9),r.FetchInt(10),r.FetchInt(11));
}
public Action TopCommand(int c,int args){if(Human(c)&&ready)db.Query(TopResult,"SELECT name,score FROM ranking ORDER BY score DESC,steam LIMIT 10",GetClientUserId(c));return Plugin_Handled;}
public void TopResult(Database database,DBResultSet r,const char[] error,any userid){int c=GetClientOfUserId(userid);if(!Human(c))return;if(r==null){LogError("Top query: %s",error);return;}Menu m=new Menu(MenuEnd);m.SetTitle("交界地贡献排行（累计贡献，不代表段位）");int place;char name[128],line[192];while(r.FetchRow()){r.FetchString(0,name,sizeof(name));Format(line,sizeof(line),"%d. %s — %d",++place,name,r.FetchInt(1));m.AddItem("",line,ITEMDRAW_DISABLED);}if(place)m.Display(c,20);else{delete m;PrintToChat(c,"[交界地] 暂无排行记录。");}}
public int MenuEnd(Menu m,MenuAction a,int c,int item){if(a==MenuAction_End)delete m;return 0;}
public Action StatusCommand(int args){PrintToServer("JJD_STATS ready=%d live=%d eligible=%d practice=%d slots=%d rules=1",ready,live,eligible,practice.BoolValue,slots);return Plugin_Handled;}
