#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

public Plugin myinfo = { name = "JJD Bot Pills", author = "Jiaojiedi", description = "让药抗模式的人机在瘸腿时自动使用药物", version = "1.0.0" };
ConVar g_ReadyName;

public void OnPluginStart()
{
    g_ReadyName = FindConVar("l4d_ready_cfg_name");
    HookEvent("player_hurt", OnHurt, EventHookMode_Post);
    HookEvent("player_incapacitated", OnIncap, EventHookMode_Post);
}

bool IsPillVersus()
{
    ConVar mode = FindConVar("mp_gamemode");
    if (mode == null) return false;
    char gm[32]; mode.GetString(gm, sizeof(gm));
    if (!StrEqual(gm, "versus", false)) return false;
    if (g_ReadyName == null) return false;
    char cfg[128]; g_ReadyName.GetString(cfg, sizeof(cfg));
    return StrContains(cfg, "ZoneMod", false) >= 0 && StrContains(cfg, "1v1", false) < 0;
}

bool IsBotSurvivor(int client)
{
    return client > 0 && client <= MaxClients && IsClientInGame(client) && IsFakeClient(client)
        && GetClientTeam(client) == 2 && IsPlayerAlive(client) && !GetEntProp(client, Prop_Send, "m_isIncapacitated");
}

bool HasMedicine(int client)
{
    int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    if (weapon > MaxClients && IsValidEntity(weapon)) {
        char cls[64]; GetEntityClassname(weapon, cls, sizeof(cls));
        if (StrEqual(cls, "weapon_pain_pills") || StrEqual(cls, "weapon_adrenaline")) return true;
    }
    for (int ent = MaxClients + 1; ent < GetMaxEntities(); ent++) {
        if (!IsValidEntity(ent)) continue;
        char cls[64]; GetEntityClassname(ent, cls, sizeof(cls));
        if (!StrEqual(cls, "weapon_pain_pills") && !StrEqual(cls, "weapon_adrenaline")) continue;
        if (GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity") == client) return true;
    }
    return false;
}

void TryUseMedicine(int userid)
{
    int client = GetClientOfUserId(userid);
    if (!IsPillVersus() || !IsBotSurvivor(client) || !HasMedicine(client)) return;
    FakeClientCommand(client, "use weapon_pain_pills");
    CreateTimer(0.2, TryAdrenaline, userid, TIMER_FLAG_NO_MAPCHANGE);
}

public Action TryAdrenaline(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    if (IsPillVersus() && IsBotSurvivor(client) && HasMedicine(client)) FakeClientCommand(client, "use weapon_adrenaline");
    return Plugin_Stop;
}

void QueueMedicine(int client)
{
    if (!IsBotSurvivor(client) || !HasMedicine(client)) return;
    CreateTimer(0.15, TryMedicineTimer, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

public Action TryMedicineTimer(Handle timer, any userid)
{
    TryUseMedicine(userid);
    return Plugin_Stop;
}

public void OnHurt(Event event, const char[] name, bool dontBroadcast)
{
    if (!IsPillVersus()) return;
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (IsBotSurvivor(client) && GetClientHealth(client) <= 40) QueueMedicine(client);
}

public void OnIncap(Event event, const char[] name, bool dontBroadcast)
{
    if (!IsPillVersus()) return;
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client > 0 && IsClientInGame(client) && IsFakeClient(client) && GetClientTeam(client) == 2) QueueMedicine(client);
}