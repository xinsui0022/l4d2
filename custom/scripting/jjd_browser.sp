#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <dhooks>

public Plugin myinfo = {
    name = "Jiaojiedi Browser Description", author = "Xinsui server",
    description = "Custom game description in the server browser",
    version = "1.0.0", url = ""
};

DynamicDetour g_Description;

public void OnPluginStart()
{
    GameData data = new GameData("jjd_browser");
    if (data == null) SetFailState("Missing jjd_browser gamedata");
    g_Description = DynamicDetour.FromConf(data, "GetGameDescription");
    delete data;
    if (g_Description == null || !g_Description.Enable(Hook_Pre, Description))
        SetFailState("Cannot hook game description");
    FindConVar("hostname").SetString("[CN] 纯净药抗");
}

public MRESReturn Description(DHookReturn result)
{
    result.SetString("Zonemod药抗&单练");
    return MRES_Supercede;
}
