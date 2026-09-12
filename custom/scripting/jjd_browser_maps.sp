#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <dhooks>

public Plugin myinfo = {
    name = "Jiaojiedi Browser Chinese Maps", author = "Xinsui server",
    description = "Translate only the Steam server browser map field",
    version = "1.0.0", url = ""
};
Handle g_GetSteam, g_SetMap;
DynamicHook g_Hook;
Address g_Steam;
int g_HookId = INVALID_HOOK_ID;
StringMap g_Names;

public void OnPluginStart()
{
    GameData data = new GameData("jjd_browser_maps");
    if (data == null) SetFailState("Missing gamedata");
    StartPrepSDKCall(SDKCall_Static);
    if (!PrepSDKCall_SetFromConf(data, SDKConf_Signature, "Steam3Server"))
        SetFailState("Missing Steam3Server symbol");
    PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
    g_GetSteam = EndPrepSDKCall();
    int slot = data.GetOffset("SetMapName");
    if (slot < 0) SetFailState("Missing SetMapName slot");
    StartPrepSDKCall(SDKCall_Raw);
    PrepSDKCall_SetVirtual(slot);
    PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
    g_SetMap = EndPrepSDKCall();
    delete data;
    if (g_GetSteam == null || g_SetMap == null) SetFailState("SDKCall setup failed");
    g_Hook = new DynamicHook(slot, HookType_Raw, ReturnType_Void, ThisPointer_Ignore);
    g_Hook.AddParam(HookParamType_CharPtr);
    g_Names = new StringMap();
    char path[PLATFORM_MAX_PATH], key[128], value[64];
    BuildPath(Path_SM, path, sizeof(path), "configs/jjd_browser_maps.txt");
    KeyValues kv = new KeyValues("Maps");
    if (!kv.ImportFromFile(path) || !kv.GotoFirstSubKey(false)) SetFailState("Missing map translations");
    do {
        kv.GetSectionName(key, sizeof(key));
        kv.GetString(NULL_STRING, value, sizeof(value));
        if (strlen(value) > 31) SetFailState("Map label exceeds Steam limit: %s", key);
        g_Names.SetString(key, value);
    } while (kv.GotoNextKey(false));
    delete kv;
    CreateTimer(2.0, Refresh, _, TIMER_REPEAT);
    RegServerCmd("sm_jjd_browser_map", Status);
}

public Action Refresh(Handle timer)
{
    Address owner = view_as<Address>(SDKCall(g_GetSteam));
    if (owner == Address_Null) return Plugin_Continue;
    // ISteamGameServer pointer at +4, verified against this engine's code.
    Address steam = view_as<Address>(LoadFromAddress(owner + view_as<Address>(4), NumberType_Int32));
    if (steam == Address_Null) return Plugin_Continue;
    if (steam != g_Steam) {
        if (g_HookId != INVALID_HOOK_ID) DynamicHook.RemoveHook(g_HookId);
        g_HookId = g_Hook.HookRaw(Hook_Pre, steam, MapName);
        if (g_HookId == INVALID_HOOK_ID) SetFailState("Cannot hook Steam SetMapName");
        g_Steam = steam;
    }
    char map[128];
    GetCurrentMap(map, sizeof(map));
    // Also refresh when hot loaded or after the engine recreates its interface.
    SDKCall(g_SetMap, steam, map);
    return Plugin_Continue;
}

public MRESReturn MapName(DHookParam params)
{
    char map[128], label[64];
    params.GetString(1, map, sizeof(map));
    if (!g_Names.GetString(map, label, sizeof(label))) return MRES_Ignored;
    params.SetString(1, label);
    return MRES_ChangedHandled;
}

public Action Status(int args)
{
    char map[128], label[64];
    GetCurrentMap(map, sizeof(map));
    if (!g_Names.GetString(map, label, sizeof(label))) strcopy(label, sizeof(label), map);
    PrintToServer("Actual map: %s; browser: %s; translations: %d; hook: %d", map, label, g_Names.Size, g_HookId);
    return Plugin_Handled;
}

public void OnPluginEnd()
{
    if (g_HookId != INVALID_HOOK_ID) DynamicHook.RemoveHook(g_HookId);
    if (g_Steam != Address_Null) {
        char map[128];
        GetCurrentMap(map, sizeof(map));
        SDKCall(g_SetMap, g_Steam, map);
    }
}
