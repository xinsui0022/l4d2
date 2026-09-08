#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

public Plugin myinfo =
{
    name = "Jiaojiedi Friendly Fire Chat",
    author = "Jiaojiedi",
    description = "Announce actual survivor friendly fire, grouped without changing damage",
    version = "1.0.0"
};

ConVar g_Enabled, g_Decay;
float g_AfterHit[MAXPLAYERS + 1];
bool g_Downed[MAXPLAYERS + 1][MAXPLAYERS + 1], g_Killed[MAXPLAYERS + 1][MAXPLAYERS + 1];
int g_Amount[MAXPLAYERS + 1][MAXPLAYERS + 1];
float g_Due[MAXPLAYERS + 1][MAXPLAYERS + 1];
int g_Messages, g_Total;

public void OnPluginStart()
{
    g_Enabled = CreateConVar("jjd_ff_chat", "1", "Actual friendly-fire chat announcements", FCVAR_NONE, true, 0.0, true, 1.0);
    g_Decay = FindConVar("pain_pills_decay_rate");
    HookEvent("round_start", ResetRound, EventHookMode_PostNoCopy);
    HookEvent("player_hurt", HurtBeforeUndo, EventHookMode_Pre);
    HookEvent("player_hurt", HurtAfterUndo, EventHookMode_Post);
    HookEvent("player_incapacitated", Incapacitated, EventHookMode_Post);
    HookEvent("player_death", Killed, EventHookMode_Post);
    RegServerCmd("sm_jjd_ff_status", Status);
    CreateTimer(0.1, Flush, _, TIMER_REPEAT);
    for (int i = 1; i <= MaxClients; i++)
        if (IsClientInGame(i)) OnClientPutInServer(i);
}

bool Survivor(int client)
{
    return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2;
}

float Health(int client)
{
    if (!IsPlayerAlive(client)) return 0.0;
    float hp = float(GetClientHealth(client));
    if (!GetEntProp(client, Prop_Send, "m_isIncapacitated"))
    {
        float buffer = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
        buffer -= (GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * g_Decay.FloatValue;
        if (buffer > 0.0) hp += buffer;
    }
    return hp;
}

void ClearClient(int client)
{
    for (int i = 1; i <= MaxClients; i++)
    {
        g_Amount[client][i] = 0;
        g_Amount[i][client] = 0;
        g_Downed[client][i] = g_Downed[i][client] = false;
        g_Killed[client][i] = g_Killed[i][client] = false;
    }
}

public void OnClientPutInServer(int client)
{
    ClearClient(client);
}

public void OnClientDisconnect(int client) { ClearClient(client); }
public void OnMapStart() { ClearRound(); }
public void ResetRound(Event event, const char[] name, bool silent) { ClearRound(); }
void ClearRound()
{
    for (int i = 1; i <= MaxClients; i++) ClearClient(i);
}

// Events also cover ZoneMod's shotgun damage, applied with SDK hooks bypassed.
// Pre records health after engine damage but before synchronous UndoFF refunds.
public void HurtBeforeUndo(Event event, const char[] name, bool silent)
{
    int v = GetClientOfUserId(event.GetInt("userid"));
    if (Survivor(v)) g_AfterHit[v] = Health(v);
}

bool Pair(Event event, int &a, int &v)
{
    a = GetClientOfUserId(event.GetInt("attacker"));
    v = GetClientOfUserId(event.GetInt("userid"));
    return g_Enabled.BoolValue && Survivor(a) && Survivor(v) && a != v;
}

void Queue(int a, int v, int damage = 0, bool down = false, bool killed = false)
{
    if (g_Amount[a][v] == 0 && !g_Downed[a][v] && !g_Killed[a][v])
        g_Due[a][v] = GetGameTime() + 0.75;
    g_Amount[a][v] += damage;
    g_Downed[a][v] = g_Downed[a][v] || down;
    g_Killed[a][v] = g_Killed[a][v] || killed;
}

public void HurtAfterUndo(Event event, const char[] name, bool silent)
{
    int a, v;
    if (!Pair(event, a, v)) return;
    int damage = event.GetInt("dmg_health");
    float refund = Health(v) - g_AfterHit[v];
    if (refund > 0.0) damage -= RoundToNearest(refund);
    if (damage > 0) Queue(a, v, damage);
}

// L4D2 does not emit player_hurt for the hit that incapacitates a survivor.
// Announce the confirmed outcome instead of guessing the missing damage number.
public void Incapacitated(Event event, const char[] name, bool silent)
{
    int a, v;
    if (Pair(event, a, v) && IsPlayerAlive(v) && GetEntProp(v, Prop_Send, "m_isIncapacitated"))
        Queue(a, v, 0, true);
}

public void Killed(Event event, const char[] name, bool silent)
{
    int a, v;
    if (Pair(event, a, v) && !IsPlayerAlive(v)) Queue(a, v, 0, false, true);
}

void CleanName(int client, char[] name, int size)
{
    GetClientName(client, name, size);
    for (int i = 0; name[i] != '\0'; i++)
        if (name[i] > 0 && name[i] < 32) name[i] = ' ';
}

public Action Flush(Handle timer)
{
    for (int a = 1; a <= MaxClients; a++)
    {
        for (int v = 1; v <= MaxClients; v++)
        {
            if ((g_Amount[a][v] == 0 && !g_Downed[a][v] && !g_Killed[a][v]) || GetGameTime() < g_Due[a][v]) continue;
            int amount = g_Amount[a][v];
            bool down = g_Downed[a][v], killed = g_Killed[a][v];
            g_Amount[a][v] = 0;
            g_Downed[a][v] = g_Killed[a][v] = false;
            if (!g_Enabled.BoolValue || !Survivor(a) || !Survivor(v)) continue;
            char attacker[64], victim[64];
            CleanName(a, attacker, sizeof(attacker));
            CleanName(v, victim, sizeof(victim));
            if (killed) PrintToChatAll("\x04[友伤]\x01 %s 误伤杀死了 %s", attacker, victim);
            else if (down) PrintToChatAll("\x04[友伤]\x01 %s 误伤击倒了 %s", attacker, victim);
            else PrintToChatAll("\x04[友伤]\x01 %s 误伤了 %s：\x05%d\x01 点伤害", attacker, victim, amount);
            g_Messages++;
            g_Total += amount;
        }
    }
    return Plugin_Continue;
}

public Action Status(int args)
{
    int pending;
    for (int a = 1; a <= MaxClients; a++)
        for (int v = 1; v <= MaxClients; v++) pending += g_Amount[a][v];
    PrintToServer("JJD_FF enabled=%d messages=%d damage=%d pending=%d", g_Enabled.BoolValue, g_Messages, g_Total, pending);
    return Plugin_Handled;
}
