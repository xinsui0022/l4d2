#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#undef REQUIRE_PLUGIN
#include <readyup>
#include <pause>

public Plugin myinfo = {name="Jiaojiedi Player Info", author="Jiaojiedi", description="Live command directory and periodic progress", version="1.0.0"};
ConVar interval;
bool live;
float nextReport;
int reports;

public void OnPluginStart()
{
    interval = CreateConVar("jjd_progress_interval", "30", "Progress chat interval, 0 disables", _, true, 0.0, true, 300.0);
    RegConsoleCmd("sm_commands", Commands, "Browse all currently available ! commands");
    RegConsoleCmd("sm_cmds", Commands, "Browse all currently available ! commands");
    RegConsoleCmd("sm_progress", Progress, "Show current survivor flow and Tank flow");
    RegServerCmd("sm_jjd_info_status", Status);
    HookEvent("round_start", Reset, EventHookMode_PostNoCopy);
    HookEvent("round_end", Reset, EventHookMode_PostNoCopy);
    HookEvent("map_transition", Reset, EventHookMode_PostNoCopy);
    CreateTimer(1.0, Tick, _, TIMER_REPEAT);
    CreateTimer(180.0, Notice, _, TIMER_REPEAT);
}
public void OnMapStart() { live = false; }
public void Reset(Event e, const char[] n, bool silent) { live = false; }
public void OnRoundIsLive() { live = true; nextReport = GetGameTime() + interval.FloatValue; }
bool Human(int c) { return c > 0 && IsClientInGame(c) && !IsFakeClient(c); }
public Action Notice(Handle timer)
{
    for (int c=1;c<=MaxClients;c++) if (Human(c)) PrintToChat(c, "[交界地公告] 输入 !commands 查询全部可用命令；!progress 查看路程；!roundstats 查看双方本半场数据。");
    return Plugin_Continue;
}
public Action Tick(Handle timer)
{
    if (!live || interval.FloatValue <= 0.0) return Plugin_Continue;
    if ((GetFeatureStatus(FeatureType_Native, "IsInReady") == FeatureStatus_Available && IsInReady())
        || (GetFeatureStatus(FeatureType_Native, "IsInPause") == FeatureStatus_Available && IsInPause()))
    { nextReport = GetGameTime() + interval.FloatValue; return Plugin_Continue; }
    if (GetGameTime() < nextReport) return Plugin_Continue;
    nextReport = GetGameTime() + interval.FloatValue;
    bool audience;
    for (int c=1;c<=MaxClients;c++) if (Human(c)) audience = true;
    if (audience) { PrintProgress(); reports++; }
    return Plugin_Continue;
}
public Action Progress(int client, int args) { if (Human(client)) PrintProgress(client); return Plugin_Handled; }
void PrintProgress(int client = 0)
{
    float maxflow = L4D2Direct_GetMapMaxFlowDistance();
    if (maxflow <= 0.0) { if (client) PrintToChat(client,"[路程] 当前地图暂无有效流程数据。"); return; }
    float flow = L4D2_GetFurthestSurvivorFlow() / maxflow * 100.0;
    if (flow < 0.0) flow = 0.0;
    if (flow > 100.0) flow = 100.0;
    int half = GameRules_GetProp("m_bInSecondHalfOfRound");
    char tank[96], line[220];
    bool aliveTank;
    for (int c=1;c<=MaxClients;c++) if (IsClientInGame(c) && GetClientTeam(c)==3 && IsPlayerAlive(c)
        && GetEntProp(c,Prop_Send,"m_zombieClass")==8) aliveTank = true;
    if (aliveTank) strcopy(tank,sizeof(tank),"Tank 在场");
    else if (L4D_IsMissionFinalMap()) strcopy(tank,sizeof(tank),"剧情/救援 Tank 无固定流程");
    else if (!L4D2Direct_GetVSTankToSpawnThisRound(half)) strcopy(tank,sizeof(tank),"无待刷流程 Tank");
    else {
        float at = L4D2Direct_GetVSTankFlowPercent(half)*100.0;
        if (at > 0.0 && at < 100.0) FormatEx(tank,sizeof(tank),"Tank %.0f%%（导演实际触发可提前）",at);
        else strcopy(tank,sizeof(tank),"Tank 流程暂无数据");
    }
    FormatEx(line,sizeof(line),"[路程] 最前生还 %.0f%% | %s",flow,tank);
    if (client) PrintToChat(client,"%s",line); else PrintToChatAll("%s",line);
}
public Action Commands(int client, int args)
{
    if (!Human(client)) return Plugin_Handled;
    Menu menu = new Menu(CommandMenu);
    menu.SetTitle("交界地命令（实时按权限列出）\n选择查看说明，不直接执行");
    Handle iter = GetCommandIterator();
    char name[80], desc[200], label[230]; int flags;
    StringMap seen = new StringMap();
    StringMap serverOnly = new StringMap();
    char path[PLATFORM_MAX_PATH], blocked[80];
    BuildPath(Path_SM,path,sizeof(path),"configs/jjd-server-commands.txt");
    File file = OpenFile(path,"r");
    if (file != null) {
        while (file.ReadLine(blocked,sizeof(blocked))) { TrimString(blocked); if (blocked[0]) serverOnly.SetValue(blocked,1); }
        delete file;
    }
    while (ReadCommandIterator(iter,name,sizeof(name),flags,desc,sizeof(desc)))
    {
        if (StrContains(name,"sm_") != 0 || !CheckCommandAccess(client,name,flags)) continue;
        int unused;
        if (seen.GetValue(name,unused) || serverOnly.GetValue(name,unused) || StrContains(name,"sm_jjd_")==0) continue;
        seen.SetValue(name,1);
        TranslateHelp(name,desc,sizeof(desc));
        FormatEx(label,sizeof(label),"!%s — %s",name[3],desc[0]?desc:"查看插件命令");
        menu.AddItem(name,label);
    }
    delete serverOnly; delete seen; delete iter;
    menu.Display(client,MENU_TIME_FOREVER);
    return Plugin_Handled;
}
void TranslateHelp(const char[] cmd, char[] desc, int size)
{
    if (StrEqual(cmd,"sm_commands") || StrEqual(cmd,"sm_cmds")) strcopy(desc,size,"查询全部可用命令");
    else if (StrEqual(cmd,"sm_ready") || StrEqual(cmd,"sm_r")) strcopy(desc,size,"准备");
    else if (StrEqual(cmd,"sm_unready")) strcopy(desc,size,"取消准备");
    else if (StrEqual(cmd,"sm_vote")) strcopy(desc,size,"投票菜单：地图/娱乐效果");
    else if (StrEqual(cmd,"sm_progress")) strcopy(desc,size,"当前路程与刷克流程");
    else if (StrEqual(cmd,"sm_roundstats") || StrEqual(cmd,"sm_lvp")) strcopy(desc,size,"本半场双方 MVP/LVP 和伤害");
    else if (StrEqual(cmd,"sm_rank")) strcopy(desc,size,"累计贡献积分与排名");
    else if (StrEqual(cmd,"sm_top")) strcopy(desc,size,"累计贡献前十");
    else if (StrEqual(cmd,"sm_stats")) strcopy(desc,size,"ZoneMod 统计及本服积分；积分用 !rank");
    else if (StrEqual(cmd,"sm_tank") || StrEqual(cmd,"sm_boss")) strcopy(desc,size,"刷克流程；感染方另可看待变克玩家");
    else if (StrEqual(cmd,"sm_pass") || StrEqual(cmd,"sm_tankpass")) strcopy(desc,size,"开场传克菜单，仅当前 Tank");
    else if (StrEqual(cmd,"sm_welcome")) strcopy(desc,size,"欢迎页与公告");
    else if (StrEqual(cmd,"sm_nextmap")) strcopy(desc,size,"下一场战役");
    else if (StrEqual(cmd,"sm_pause")) strcopy(desc,size,"暂停游戏");
    else if (StrEqual(cmd,"sm_unpause")) strcopy(desc,size,"本队准备恢复游戏");
    else if (StrEqual(cmd,"sm_spec")) strcopy(desc,size,"转旁观");
    else if (StrEqual(cmd,"sm_mvp")) strcopy(desc,size,"ZoneMod 生还 MVP；双方用 !roundstats");
}
public int CommandMenu(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_End) delete menu;
    else if (action == MenuAction_Select && Human(client)) {
        char cmd[80],label[230]; menu.GetItem(item,cmd,sizeof(cmd),_,label,sizeof(label));
        PrintToChat(client,"[命令] %s",label);
        PrintToChat(client,"[命令] 聊天输入 !%s；需要目标/参数时请按说明填写。",cmd[3]);
        menu.DisplayAt(client,menu.Selection,MENU_TIME_FOREVER);
    }
    return 0;
}
public Action Status(int args) { PrintToServer("JJD_INFO live=%d interval=%.0f reports=%d",live,interval.FloatValue,reports); return Plugin_Handled; }
