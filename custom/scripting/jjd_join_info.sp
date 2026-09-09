#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <geoip>

public Plugin myinfo = {name="Jiaojiedi Join Info", author="Jiaojiedi", description="Local GeoIP join notices and private history", version="2.0.2"};
Database g_DB;
bool g_Recorded[MAXPLAYERS + 1];

public void OnPluginStart()
{
    char error[256];
    g_DB = SQLite_UseDatabase("jjd_visitors", error, sizeof(error));
    if (g_DB == null) SetFailState("Visitor database: %s", error);
    if (!SQL_FastQuery(g_DB, "CREATE TABLE IF NOT EXISTS visits (id INTEGER PRIMARY KEY, timestamp INTEGER NOT NULL, name TEXT NOT NULL, steam TEXT NOT NULL, ip TEXT NOT NULL, location TEXT NOT NULL, map TEXT NOT NULL)"))
        SetFailState("Cannot create visitor table");
}

public void OnClientConnected(int client) { g_Recorded[client] = false; }
public void OnClientDisconnect(int client) { g_Recorded[client] = false; }

void Clean(char[] text)
{
    for (int i = 0; text[i] != 0; i++)
        if ((text[i] > 0 && text[i] < 32) || text[i] == 127) text[i] = ' ';
}

public void OnClientPostAdminCheck(int client)
{
    if (IsFakeClient(client) || g_Recorded[client]) return;
    g_Recorded[client] = true;
    char ip[64], steam[32], name[128], country[96], region[96], city[96], location[300], map[128];
    if (!GetClientIP(client, ip, sizeof(ip), true)) strcopy(ip, sizeof(ip), "unknown");
    if (!GetClientAuthId(client, AuthId_Steam2, steam, sizeof(steam))) strcopy(steam, sizeof(steam), "unknown");
    GetClientName(client, name, sizeof(name));
    Clean(name);
    GeoipCountryEx(ip, country, sizeof(country), client);
    GeoipRegion(ip, region, sizeof(region), client);
    GeoipCity(ip, city, sizeof(city), client);
    if (country[0]) strcopy(location, sizeof(location), country);
    if (region[0]) Format(location, sizeof(location), "%s %s", location, region);
    if (city[0]) Format(location, sizeof(location), "%s %s", location, city);
    TrimString(location);
    if (!location[0]) strcopy(location, sizeof(location), "未知地区");
    GetCurrentMap(map, sizeof(map));
    char eName[257], eSteam[65], eIp[129], eLocation[601], eMap[257], query[1600];
    g_DB.Escape(name, eName, sizeof(eName));
    g_DB.Escape(steam, eSteam, sizeof(eSteam));
    g_DB.Escape(ip, eIp, sizeof(eIp));
    g_DB.Escape(location, eLocation, sizeof(eLocation));
    g_DB.Escape(map, eMap, sizeof(eMap));
    Format(query, sizeof(query), "INSERT INTO visits(timestamp,name,steam,ip,location,map) VALUES(%d,'%s','%s','%s','%s','%s')", GetTime(), eName, eSteam, eIp, eLocation, eMap);
    g_DB.Query(OnRecorded, query);
    char masked[64];
    strcopy(masked, sizeof(masked), ip);
    int dot = FindCharInString(masked, '.', true);
    if (dot != -1) { masked[dot] = 0; StrCat(masked, sizeof(masked), ".*"); }
    else strcopy(masked, sizeof(masked), "已隐藏");
    PrintToChatAll("\x04[加入]\x01 %s | IP: %s | %s（大致定位）", name, masked, location);
}

public void OnRecorded(Database db, DBResultSet results, const char[] error, any data)
{
    if (error[0]) LogError("Visitor record failed: %s", error);
}
