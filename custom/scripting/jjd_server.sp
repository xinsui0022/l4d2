#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <builtinvotes>

#define DEFAULT_MAP "c5m1_waterfront"
#define WELCOME_URL "http://YOUR_SERVER_IP/l4d2/welcome.html"
#define ADMIN_ID "STEAM_1:0:YOUR_ACCOUNT_ID"

public Plugin myinfo = {
    name = "Jiaojiedi Server Tools", author = "l4d2 server",
    description = "Welcome, campaign votes, fresh matches and idle maintenance",
    version = "1.0.0", url = ""
};

static const char MAPS[][] = {
    "c1m1_hotel", "c2m1_highway", "c3m1_plankcountry", "c4m1_milltown_a",
    "c5m1_waterfront", "c6m1_riverbank", "c7m1_docks", "c8m1_apartment",
    "c9m1_alleys", "c10m1_caves", "c11m1_greenhouse", "c12m1_hilltop",
    "c13m1_alpinecreek", "c14m1_junkyard"
};
static const char NAMES[][] = {
    "C1 死亡中心", "C2 黑色嘉年华", "C3 沼泽激战", "C4 暴风骤雨",
    "C5 教区", "C6 短暂时刻（串联 C7）", "C7 牺牲", "C8 毫不留情",
    "C9 坠机险途（串联 C14）", "C10 死亡丧钟", "C11 静寂时分", "C12 血腥收获",
    "C13 刺骨寒溪", "C14 临死一搏"
};

ConVar g_Next, g_Seen, g_LastActive, g_IdleSeconds, g_FreshMap, g_LastVote;
Handle g_Vote, g_ChangeTimer;
int g_VoteKind, g_Electorate;
char g_VoteMap[64];
bool g_FinaleQueued;

public void OnPluginStart()
{
    g_Next = CreateConVar("jjd_next_campaign", DEFAULT_MAP, "Next full campaign; one-use override");
    // Existing ConVars survive ZoneMod plugin reloads; process restart clears them.
    g_Seen = CreateConVar("jjd_idle_seen_human", "0", "Human activity since process start");
    g_LastActive = CreateConVar("jjd_idle_last_active", "0", "Last human activity, Unix seconds");
    g_IdleSeconds = CreateConVar("jjd_idle_seconds", "1800", "Continuous empty seconds before one restart", 0, true, 60.0);
    g_FreshMap = CreateConVar("jjd_fresh_map", "", "Pending fresh-campaign score reset");
    g_LastVote = CreateConVar("jjd_last_vote", "0", "Last public vote start, Unix seconds");
    RegConsoleCmd("sm_vote", VoteMenuCommand);
    RegConsoleCmd("sm_nextmap", NextMapCommand);
    RegConsoleCmd("sm_welcome", WelcomeCommand);
    RegServerCmd("sm_jjd_status", StatusCommand);
    RegServerCmd("sm_jjd_idle_check", IdleCheckCommand);
    RegServerCmd("sm_jjd_newcampaign", NewCampaignCommand);
    HookUserMessage(GetUserMessageId("PZEndGamePanelMsg"), EndGameMessage, true);
    TouchActivity();
}

public void OnMapStart()
{
    g_FinaleQueued = false;
    g_ChangeTimer = null;
}

public void OnMapEnd()
{
    // Explicit cleanup also covers map changes initiated by other plugins/admins.
    if (g_ChangeTimer != null) { delete g_ChangeTimer; }
    g_FinaleQueued = false;
}

public void OnConfigsExecuted()
{
    // Set through the UTF-8 native: the engine's cfg command parser can strip
    // a wholly non-ASCII hostname on this Linux build.
    FindConVar("hostname").SetString("交界地");
    CreateTimer(2.0, ResetFreshScores, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action ResetFreshScores(Handle timer)
{
    char target[64], current[64];
    g_FreshMap.GetString(target, sizeof(target));
    GetCurrentMap(current, sizeof(current));
    if (target[0] && StrEqual(target, current)) {
        L4D2Direct_SetVSCampaignScore(0, 0);
        L4D2Direct_SetVSCampaignScore(1, 0);
        GameRules_SetProp("m_iCampaignScore", 0, _, 0);
        GameRules_SetProp("m_iCampaignScore", 0, _, 1);
        g_FreshMap.SetString("");
        LogMessage("Fresh campaign scores reset: %s", current);
    }
    return Plugin_Stop;
}

int HumanConnections()
{
    int count;
    for (int i = 1; i <= MaxClients; i++)
        if (IsClientConnected(i) && !IsFakeClient(i)) count++;
    return count;
}

void TouchActivity()
{
    if (HumanConnections() > 0) {
        g_Seen.IntValue = 1;
        g_LastActive.IntValue = GetTime();
    }
}

public void OnClientPutInServer(int client)
{
    if (!IsFakeClient(client)) {
        TouchActivity();
        CreateTimer(8.0, WelcomeChat, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
    }
}

public void OnClientDisconnect(int client)
{
    if (!IsFakeClient(client)) {
        g_Seen.IntValue = 1;
        g_LastActive.IntValue = GetTime();
    }
}

public Action WelcomeChat(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    if (client && IsClientInGame(client)) {
        PrintToChat(client, "\x04[交界地]\x01 本服务器由五郎、心碎提供");
        PrintToChat(client, "\x04[交界地]\x01 !vote 投票菜单 | !nextmap 下一局 | !welcome 欢迎页");
    }
    return Plugin_Stop;
}

public Action IdleCheckCommand(int args)
{
    TouchActivity();
    int humans = HumanConnections();
    int idle = GetTime() - g_LastActive.IntValue;
    PrintToServer("JJD_IDLE humans=%d seen=%d idle=%d threshold=%d", humans, g_Seen.IntValue,
        g_LastActive.IntValue > 0 ? idle : 0, g_IdleSeconds.IntValue);
    // The external wall-clock watcher owns restarts; this command is diagnostic.
    return Plugin_Handled;
}

int MapIndex(const char[] map)
{
    for (int i = 0; i < sizeof(MAPS); i++)
        if (StrEqual(map, MAPS[i], false) && IsMapValid(MAPS[i])) return i;
    return -1;
}

void NextMap(char[] map, int size)
{
    g_Next.GetString(map, size);
    if (MapIndex(map) < 0) strcopy(map, size, DEFAULT_MAP);
}

public Action NextMapCommand(int client, int args)
{
    char map[64]; NextMap(map, sizeof(map));
    ReplyToCommand(client, "[交界地] 下一场战役：%s（%s），可用 !vote 投票修改。", NAMES[MapIndex(map)], map);
    return Plugin_Handled;
}

public Action WelcomeCommand(int client, int args)
{
    if (client > 0) ShowMOTDPanel(client, "交界地", WELCOME_URL, MOTDPANEL_TYPE_URL);
    return Plugin_Handled;
}

public Action VoteMenuCommand(int client, int args)
{
    if (!client || !IsClientInGame(client)) return Plugin_Handled;
    Menu menu = new Menu(MainMenuHandler);
    menu.SetTitle("交界地 · 投票菜单");
    menu.AddItem("now", "投票：立即开始指定战役");
    menu.AddItem("next", "投票：选择打完后的下一场战役");
    menu.AddItem("restart", "投票：从头重开当前战役");
    menu.AddItem("info", "查看下一场战役");
    menu.AddItem("welcome", "欢迎页与公告");
    if (CheckCommandAccess(client, "sm_admin", ADMFLAG_GENERIC)) menu.AddItem("admin", "管理员菜单");
    menu.Display(client, 30);
    return Plugin_Handled;
}

public int MainMenuHandler(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_End) { delete menu; }
    else if (action == MenuAction_Select) {
        char key[16]; menu.GetItem(item, key, sizeof(key));
        if (StrEqual(key, "info")) NextMapCommand(client, 0);
        else if (StrEqual(key, "welcome")) WelcomeCommand(client, 0);
        else if (StrEqual(key, "admin")) FakeClientCommand(client, "sm_admin");
        else if (StrEqual(key, "restart")) {
            char current[64], prefix[8]; GetCurrentMap(current, sizeof(current));
            int split = FindCharInString(current, 'm');
            if (split > 0 && split < sizeof(prefix)) {
                strcopy(prefix, split + 1, current);
                for (int i = 0; i < sizeof(MAPS); i++) {
                    if (strncmp(prefix, MAPS[i], split) == 0 && MAPS[i][split] == 'm') {
                        StartVote(client, 2, i); break;
                    }
                }
            }
        } else {
            Menu maps = new Menu(MapMenuHandler);
            maps.SetTitle(StrEqual(key, "next") ? "投票选择下一场战役" : "投票立即开始战役");
            char value[24];
            for (int i = 0; i < sizeof(MAPS); i++) {
                if (!IsMapValid(MAPS[i])) continue;
                Format(value, sizeof(value), "%d:%d", StrEqual(key, "next") ? 1 : 0, i);
                maps.AddItem(value, NAMES[i]);
            }
            maps.Display(client, 30);
        }
    }
    return 0;
}

public int MapMenuHandler(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_End) { delete menu; }
    else if (action == MenuAction_Select) {
        char value[24], parts[2][12]; menu.GetItem(item, value, sizeof(value));
        ExplodeString(value, ":", parts, sizeof(parts), sizeof(parts[]));
        StartVote(client, StringToInt(parts[0]), StringToInt(parts[1]));
    }
    return 0;
}

void StartVote(int client, int kind, int index)
{
    if (!IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) < 2) {
        PrintToChat(client, "[交界地] 旁观者不能发起或参与投票。"); return;
    }
    if (g_FinaleQueued || g_ChangeTimer != null || IsBuiltinVoteInProgress()) {
        PrintToChat(client, "[交界地] 正在投票或即将换图，请稍后再试。"); return;
    }
    int remaining = 60 - (GetTime() - g_LastVote.IntValue);
    if (remaining > 0) { PrintToChat(client, "[交界地] 请等待 %d 秒再发起投票。", remaining); return; }
    if (index < 0 || index >= sizeof(MAPS) || !IsMapValid(MAPS[index])) return;
    int players[MAXPLAYERS + 1]; g_Electorate = 0;
    for (int i = 1; i <= MaxClients; i++)
        if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) >= 2) players[g_Electorate++] = i;
    g_VoteKind = kind; strcopy(g_VoteMap, sizeof(g_VoteMap), MAPS[index]);
    char title[192];
    if (kind == 1) Format(title, sizeof(title), "下一场战役改为 %s？", NAMES[index]);
    else if (kind == 2) Format(title, sizeof(title), "清零比分并重开 %s？", NAMES[index]);
    else Format(title, sizeof(title), "立即清零比分并开始 %s？", NAMES[index]);
    g_Vote = CreateBuiltinVote(VoteActionHandler, BuiltinVoteType_Custom_YesNo,
        BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
    SetBuiltinVoteArgument(g_Vote, title);
    SetBuiltinVoteInitiator(g_Vote, client);
    SetBuiltinVoteResultCallback(g_Vote, VoteResult);
    if (!DisplayBuiltinVote(g_Vote, players, g_Electorate, 20)) {
        delete g_Vote; PrintToChat(client, "[交界地] 投票暂时无法启动。"); return;
    }
    g_LastVote.IntValue = GetTime();
    PrintToChatAll("[交界地] 投票需 %d 名参赛玩家中至少 %d 人同意；F1 同意 / F2 反对。", g_Electorate, g_Electorate / 2 + 1);
    FakeClientCommand(client, "Vote Yes");
}

public void VoteActionHandler(Handle vote, BuiltinVoteAction action, int param1, int param2)
{
    if (action == BuiltinVoteAction_End) { delete vote; g_Vote = null; }
    else if (action == BuiltinVoteAction_Cancel) DisplayBuiltinVoteFail(vote, view_as<BuiltinVoteFailReason>(param1));
}

public void VoteResult(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
    int yes;
    for (int i = 0; i < num_items; i++)
        if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES) yes = item_info[i][BUILTINVOTEINFO_ITEM_VOTES];
    if (yes <= g_Electorate / 2) { DisplayBuiltinVoteFail(vote, BuiltinVoteFail_NotEnoughVotes); return; }
    char message[192];
    if (g_VoteKind == 1) {
        g_Next.SetString(g_VoteMap);
        Format(message, sizeof(message), "下一场：%s", NAMES[MapIndex(g_VoteMap)]);
    } else {
        Format(message, sizeof(message), "即将开始：%s", NAMES[MapIndex(g_VoteMap)]);
        DataPack pack;
        g_ChangeTimer = CreateDataTimer(5.0, VotedChange, pack, TIMER_FLAG_NO_MAPCHANGE);
        pack.WriteString(g_VoteMap);
    }
    DisplayBuiltinVotePass(vote, message);
    PrintToChatAll("[交界地] 投票通过（%d/%d）：%s", yes, g_Electorate, message);
    LogMessage("Vote passed: kind=%d map=%s yes=%d electorate=%d", g_VoteKind, g_VoteMap, yes, g_Electorate);
}

public Action VotedChange(Handle timer, DataPack pack)
{
    g_ChangeTimer = null;
    char map[64]; pack.Reset(); pack.ReadString(map, sizeof(map));
    FreshCampaign(map);
    return Plugin_Stop;
}

// End-game panel is sent after a complete versus campaign, not every half.
// ACS documents this engine message; no ACS code is included in this plugin.
public Action EndGameMessage(UserMsg msg, Handle data, const int[] players, int count, bool reliable, bool init)
{
    char mode[32], map[64]; FindConVar("mp_gamemode").GetString(mode, sizeof(mode));
    if (!StrEqual(mode, "versus")) return Plugin_Continue;
    GetCurrentMap(map, sizeof(map));
    // ZoneMod intentionally joins these short campaigns while preserving scores.
    if (StrEqual(map, "c6m2_bedlam") || StrEqual(map, "c9m2_lots")) return Plugin_Handled;
    if (!g_FinaleQueued && g_ChangeTimer == null) {
        g_FinaleQueued = true;
        g_ChangeTimer = CreateTimer(30.0, FinishedCampaign, _, TIMER_FLAG_NO_MAPCHANGE);
        // Defer messages until after the intercepted usermessage is delivered.
        RequestFrame(AnnounceNext);
        LogMessage("Campaign finished: %s; next campaign in 30 seconds", map);
    }
    return Plugin_Handled;
}

public void AnnounceNext(any data)
{
    char map[64]; NextMap(map, sizeof(map));
    PrintToChatAll("[交界地] 本场结束，30 秒后开启新局：%s。", NAMES[MapIndex(map)]);
}

public Action FinishedCampaign(Handle timer)
{
    g_ChangeTimer = null;
    char map[64]; NextMap(map, sizeof(map));
    g_Next.SetString(DEFAULT_MAP);
    FreshCampaign(map);
    return Plugin_Stop;
}

void FreshCampaign(const char[] map)
{
    if (MapIndex(map) < 0) return;
    g_FreshMap.SetString(map);
    LogMessage("Starting fresh campaign: %s", map);
    ForceChangeLevel(map, "Jiaojiedi fresh campaign");
}

public Action NewCampaignCommand(int args)
{
    char map[64]; GetCmdArg(1, map, sizeof(map));
    if (args != 1 || MapIndex(map) < 0) PrintToServer("JJD_ERROR expected an installed stock campaign first map");
    else FreshCampaign(map);
    return Plugin_Handled;
}

public Action StatusCommand(int args)
{
    char map[64], next[64], fresh[64]; GetCurrentMap(map, sizeof(map));
    NextMap(next, sizeof(next)); g_FreshMap.GetString(fresh, sizeof(fresh));
    AdminId admin = FindAdminByIdentity(AUTHMETHOD_STEAM, ADMIN_ID);
    bool root = admin != INVALID_ADMIN_ID && GetAdminFlag(admin, Admin_Root);
    int valid;
    for (int i = 0; i < sizeof(MAPS); i++) if (IsMapValid(MAPS[i])) valid++;
    PrintToServer("JJD_STATUS map=%s next=%s humans=%d seen=%d last=%d idle_seconds=%d", map, next, HumanConnections(), g_Seen.IntValue, g_LastActive.IntValue, g_IdleSeconds.IntValue);
    PrintToServer("JJD_STATUS admin_root=%d valid_campaigns=%d finale_queued=%d fresh_pending=%s scores=%d:%d", root, valid, g_FinaleQueued, fresh, L4D2Direct_GetVSCampaignScore(0), L4D2Direct_GetVSCampaignScore(1));
    return Plugin_Handled;
}
