#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
public Plugin myinfo={name="Jiaojiedi Fun Cosmetics",author="Jiaojiedi",description="Vote-gated chapter rain and cosmetic props",version="1.0.0"};
ConVar mode,modeMap;
int rain=INVALID_ENT_REFERENCE,hats[MAXPLAYERS+1],choice[MAXPLAYERS+1];
static const char MODELS[][]={"models/props_junk/gnome.mdl","models/props_fortifications/orange_cone001_reference.mdl"};
bool modelReady[2];
public void OnPluginStart(){mode=CreateConVar("jjd_fun_mode","0","Chapter cosmetics: rain=1 hats=2",FCVAR_DONTRECORD);modeMap=CreateConVar("jjd_fun_map","","Cosmetic chapter",FCVAR_DONTRECORD);RegServerCmd("sm_jjd_fun_apply",Apply);RegServerCmd("sm_jjd_fun_status",Status);RegConsoleCmd("sm_hat",HatCommand);RegConsoleCmd("sm_hats",HatCommand);HookEvent("round_start",RoundStart);CreateTimer(1.0,Maintain,_,TIMER_REPEAT);}
public void OnMapStart(){char current[64],old[64];GetCurrentMap(current,sizeof(current));modeMap.GetString(old,sizeof(old));if(!StrEqual(current,old)){mode.IntValue=0;modeMap.SetString(current);}rain=INVALID_ENT_REFERENCE;for(int c=1;c<=MaxClients;c++)hats[c]=INVALID_ENT_REFERENCE;for(int i=0;i<2;i++)modelReady[i]=FileExists(MODELS[i],true)&&PrecacheModel(MODELS[i],true)>0;}
public void OnPluginEnd(){ClearRain();for(int c=1;c<=MaxClients;c++)ClearHat(c);}
public void OnClientDisconnect(int c){ClearHat(c);choice[c]=0;}
public void RoundStart(Event e,const char[] name,bool b){ClearRain();for(int c=1;c<=MaxClients;c++)ClearHat(c);}
void ClearRain(){int e=EntRefToEntIndex(rain);rain=INVALID_ENT_REFERENCE;if(e>MaxClients&&IsValidEntity(e))RemoveEntity(e);}
void ClearHat(int c){int e=EntRefToEntIndex(hats[c]);hats[c]=INVALID_ENT_REFERENCE;if(e>MaxClients&&IsValidEntity(e))RemoveEntity(e);}
bool CreateRain(){
    ClearRain();int e=CreateEntityByName("func_precipitation");if(e==-1)return false;
    char map[128];GetCurrentMap(map,sizeof(map));Format(map,sizeof(map),"maps/%s.bsp",map);PrecacheModel(map,true);
    DispatchKeyValue(e,"model",map);DispatchKeyValue(e,"preciptype","0");DispatchKeyValue(e,"renderamt","255");DispatchSpawn(e);
    float mins[3],maxs[3],origin[3];GetEntPropVector(0,Prop_Data,"m_WorldMins",mins);GetEntPropVector(0,Prop_Data,"m_WorldMaxs",maxs);
    SetEntPropVector(e,Prop_Send,"m_vecMins",mins);SetEntPropVector(e,Prop_Send,"m_vecMaxs",maxs);TeleportEntity(e,origin,NULL_VECTOR,NULL_VECTOR);ActivateEntity(e);
    rain=EntIndexToEntRef(e);return true;
}
bool CreateHat(int c){
    ClearHat(c);int selected=choice[c];if(selected<0||selected>=2||!modelReady[selected])return false;
    int e=CreateEntityByName("prop_dynamic_override");if(e==-1)return false;
    DispatchKeyValue(e,"model",MODELS[selected]);DispatchKeyValue(e,"solid","0");DispatchKeyValue(e,"disableshadows","1");DispatchSpawn(e);
    SetEntPropFloat(e,Prop_Send,"m_flModelScale",selected==0?0.35:0.5);SetEntPropEnt(e,Prop_Send,"m_hOwnerEntity",c);
    SetVariantString("!activator");AcceptEntityInput(e,"SetParent",c);SetVariantString("eyes");AcceptEntityInput(e,"SetParentAttachment",c);
    float origin[3]={0.0,0.0,8.0},angles[3];TeleportEntity(e,origin,angles,NULL_VECTOR);SDKHook(e,SDKHook_SetTransmit,HatTransmit);hats[c]=EntIndexToEntRef(e);return true;
}
public Action HatTransmit(int entity,int client){int owner=GetEntPropEnt(entity,Prop_Send,"m_hOwnerEntity");if(client==owner)return Plugin_Handled;if(IsClientInGame(client)&&GetEntProp(client,Prop_Send,"m_iObserverMode")==4&&GetEntPropEnt(client,Prop_Send,"m_hObserverTarget")==owner)return Plugin_Handled;return Plugin_Continue;}
public Action Maintain(Handle timer){
    if(mode.IntValue){ConVar practice=FindConVar("jjd_stats_practice");if(practice!=null)practice.SetInt(1);}
    int e=EntRefToEntIndex(rain);if(mode.IntValue&1){if(e<=MaxClients||!IsValidEntity(e))CreateRain();}else ClearRain();
    for(int c=1;c<=MaxClients;c++){
        if(!(mode.IntValue&2)||!IsClientInGame(c)||GetClientTeam(c)!=2||!IsPlayerAlive(c)||choice[c]<0){ClearHat(c);continue;}
        e=EntRefToEntIndex(hats[c]);if(e<=MaxClients||!IsValidEntity(e))CreateHat(c);
    }return Plugin_Continue;
}
public Action Apply(int args){char value[16];GetCmdArg(1,value,sizeof(value));if(StrEqual(value,"rain"))mode.IntValue=mode.IntValue|1;else if(StrEqual(value,"hats"))mode.IntValue=mode.IntValue|2;else if(StrEqual(value,"off"))mode.IntValue=0;else return Plugin_Handled;ConVar practice=FindConVar("jjd_stats_practice");if(practice!=null)practice.SetInt(1);Maintain(null);PrintToChatAll("[交界地] 娱乐效果已更新，本章节不计排行。装饰开启后可用 !hat 选择或摘下。");return Plugin_Handled;}
public Action HatCommand(int c,int args){if(c<=0||!IsClientInGame(c))return Plugin_Handled;if(!(mode.IntValue&2)){ReplyToCommand(c,"[交界地] 请先用 !vote 投票开启本章节装饰模式。");return Plugin_Handled;}if(GetClientTeam(c)!=2){ReplyToCommand(c,"[交界地] 装饰仅供生还者使用。");return Plugin_Handled;}Menu m=new Menu(HatMenu);m.SetTitle("趣味装饰（不改变伤害与碰撞）");m.AddItem("0","小矮人头饰",modelReady[0]?ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);m.AddItem("1","交通锥头饰",modelReady[1]?ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);m.AddItem("-1","摘下装饰");m.Display(c,20);return Plugin_Handled;}
public int HatMenu(Menu m,MenuAction a,int c,int item){if(a==MenuAction_End){delete m;return 0;}if(a!=MenuAction_Select||!IsClientInGame(c)||GetClientTeam(c)!=2||!(mode.IntValue&2))return 0;char value[8];m.GetItem(item,value,sizeof(value));choice[c]=StringToInt(value);ClearHat(c);if(choice[c]>=0&&IsPlayerAlive(c))CreateHat(c);return 0;}
public Action Status(int args){int count;for(int c=1;c<=MaxClients;c++)if(EntRefToEntIndex(hats[c])>MaxClients)count++;PrintToServer("JJD_FUN mode=%d rain=%d hats=%d models=%d,%d",mode.IntValue,EntRefToEntIndex(rain)>MaxClients,count,modelReady[0],modelReady[1]);return Plugin_Handled;}
