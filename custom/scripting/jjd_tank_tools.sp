#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#undef REQUIRE_PLUGIN
#include <adminmenu>

public Plugin myinfo = {name="Jiaojiedi Tank Tools", author="l4d2 server", description="Opening tank handoff and root-only practice tools", version="1.1.0"};
float deadline[MAXPLAYERS+1];
bool offered[MAXPLAYERS+1], spent[MAXPLAYERS+1], passing;
TopMenu adminMenu;
ConVar window;
Menu passMenu[MAXPLAYERS+1];

bool Tank(int c) { return c>0 && c<=MaxClients && IsClientInGame(c) && GetClientTeam(c)==3 && IsPlayerAlive(c) && GetEntProp(c,Prop_Send,"m_zombieClass")==8; }
bool Target(int c,int owner) { return c>0 && c<=MaxClients && c!=owner && IsClientInGame(c) && !IsFakeClient(c) && GetClientTeam(c)==3 && !Tank(c); }
public void OnPluginStart()
{
    window=CreateConVar("jjd_tank_pass_window","10","Opening handoff window in seconds",0,true,3.0,true,30.0);
    CreateTimer(1.0,Countdown,_,TIMER_REPEAT);
    HookEvent("tank_spawn", SpawnEvent);
    HookEvent("round_start", RoundStart);
    RegConsoleCmd("sm_pass", PassCommand);
    RegConsoleCmd("sm_tankpass", PassCommand);
    RegConsoleCmd("sm_passtank", PassCommand);
    RegAdminCmd("sm_spawntank", SpawnCommand, ADMFLAG_ROOT);
    RegAdminCmd("sm_taketank", TakeCommand, ADMFLAG_ROOT);
    RegServerCmd("sm_jjd_tank_status", Status);
    if (LibraryExists("adminmenu")) OnAdminMenuReady(GetAdminTopMenu());
    for(int i=1;i<=MaxClients;i++) if(IsClientInGame(i)) OnClientPutInServer(i);
}
public void OnClientPutInServer(int c) { offered[c]=false; spent[c]=false; deadline[c]=0.0; SDKHook(c,SDKHook_OnTakeDamagePost,Damage); }
public void RoundStart(Event e,const char[] n,bool b) { for(int i=1;i<=MaxClients;i++){offered[i]=false;spent[i]=false;deadline[i]=0.0;} }
public void SpawnEvent(Event e,const char[] n,bool b)
{
    int c=GetClientOfUserId(e.GetInt("userid"));
    if(!Tank(c) || passing) return;
    offered[c]=false; spent[c]=false; deadline[c]=0.0;
    if(!IsFakeClient(c)) CreateTimer(0.5,Offer,GetClientUserId(c),TIMER_FLAG_NO_MAPCHANGE);
}
public void L4D_OnReplaceTank(int old,int next)
{
    if(old<=0 || next<=0 || old==next) return;
    spent[next]=spent[old] || passing;
    offered[next]=offered[old] || passing;
    deadline[next]=deadline[old];
    if(!passing) CreateTimer(0.5,Offer,GetClientUserId(next),TIMER_FLAG_NO_MAPCHANGE);
}
public void L4D2_OnTankPassControl(int old,int next,int count)
{
    if(next>0 && !passing) CreateTimer(0.5,Offer,GetClientUserId(next),TIMER_FLAG_NO_MAPCHANGE);
}
public Action Offer(Handle timer,any userid)
{
    int c=GetClientOfUserId(userid);
    if(!Tank(c) || IsFakeClient(c) || offered[c] || spent[c]) return Plugin_Stop;
    offered[c]=true; deadline[c]=GetGameTime()+window.FloatValue;
    ShowPass(c);
    return Plugin_Stop;
}
public void Damage(int victim,int attacker,int inflictor,float damage,int type)
{
    // Only a damaging claw hit on a survivor commits the player to this Tank.
    if(damage<=0.0 || !Tank(attacker) || inflictor!=attacker || victim<1 || victim>MaxClients || !IsClientInGame(victim) || GetClientTeam(victim)!=2) return;
    char weapon[64];GetClientWeapon(attacker,weapon,sizeof(weapon));
    if(StrEqual(weapon,"weapon_tank_claw")) LockPass(attacker);
}
public void L4D_TankRock_OnRelease_Post(int tank,int rock,const float pos[3],const float ang[3],const float vel[3],const float rot[3])
{
    if(Tank(tank)) LockPass(tank);
}
void ClosePass(int c)
{
    Menu menu=passMenu[c];passMenu[c]=null;
    if(menu!=null) menu.Cancel();
}
void LockPass(int c) { spent[c]=true;ClosePass(c); }
public void OnClientDisconnect(int c) { ClosePass(c); }
public Action Countdown(Handle timer)
{
    for(int c=1;c<=MaxClients;c++) if(passMenu[c]!=null){
        if(CanPass(c)) ShowPass(c);else ClosePass(c);
    }
    return Plugin_Continue;
}
bool CanPass(int c) { return Tank(c) && !IsFakeClient(c) && offered[c] && !spent[c] && GetGameTime()<deadline[c]; }
void ShowPass(int c)
{
    ClosePass(c);
    Menu menu=new Menu(PassHandler);
    passMenu[c]=menu;
    menu.SetTitle("Tank 开场选择（剩余 %d 秒）\n超时默认自己玩",RoundToCeil(deadline[c]-GetGameTime()));
    char id[16],name[MAX_NAME_LENGTH]; int count;
    for(int i=1;i<=MaxClients;i++) if(Target(i,c)){
        IntToString(GetClientUserId(i),id,sizeof(id));GetClientName(i,name,sizeof(name));menu.AddItem(id,name);count++;
    }
    menu.AddItem("random","随机交给一名队友",count ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
    menu.AddItem("self","我自己玩");
    menu.ExitButton=false;
    menu.Display(c,RoundToCeil(deadline[c]-GetGameTime()));
}
public Action PassCommand(int c,int args)
{
    if(c>0){if(CanPass(c)) ShowPass(c);else ReplyToCommand(c,"[交界地] 只能在开场 %.0f 秒内、未拳击命中生还者且未投石时传克一次。",window.FloatValue);}
    return Plugin_Handled;
}
public int PassHandler(Menu menu,MenuAction action,int c,int item)
{
    if(action==MenuAction_End){for(int i=1;i<=MaxClients;i++)if(passMenu[i]==menu)passMenu[i]=null;delete menu;return 0;}
    if(action!=MenuAction_Select) return 0;
    char id[16];menu.GetItem(item,id,sizeof(id));
    if(StrEqual(id,"self")){spent[c]=true;return 0;}
    if(!CanPass(c)){PrintToChat(c,"[交界地] 传克窗口已结束。");return 0;}
    int next;
    if(StrEqual(id,"random")){
        int players[MAXPLAYERS+1],count;
        for(int i=1;i<=MaxClients;i++)if(Target(i,c))players[count++]=i;
        if(count)next=players[GetRandomInt(0,count-1)];
    }else next=GetClientOfUserId(StringToInt(id));
    if(!Target(next,c)){PrintToChat(c,"[交界地] 队友已离开或不可接克，请重新输入 !pass。");return 0;}
    float pos[3],ang[3];GetClientAbsOrigin(c,pos);GetClientAbsAngles(c,ang);
    int health=GetClientHealth(c),rage=L4D_GetTankFrustration(c),passes=L4D2Direct_GetTankPassedCount();
    spent[c]=true;spent[next]=true;offered[next]=true;passing=true;
    if(IsPlayerAlive(next)){
        if(!GetEntProp(next,Prop_Send,"m_isGhost")) L4D_ReplaceWithBot(next);
        ForcePlayerSuicide(next);
    }
    TeleportEntity(next,pos,ang,NULL_VECTOR);
    L4D_ReplaceTank(c,next);
    if(Tank(next)){
        SetEntityHealth(next,health);L4D_SetTankFrustration(next,rage);
        L4D2Direct_SetTankPassedCount(passes);
        spent[next]=true;offered[next]=true;
        PrintToChatAll("[交界地] %N 将 Tank 交给了 %N。",c,next);
        LogAction(c,next,"Opening Tank handoff; health=%d rage=%d engine_passes=%d",health,rage,passes);
    }else LogError("Tank handoff failed: old=%d target=%d",c,next);
    passing=false;
    return 0;
}
bool Root(int c) { return c>0 && IsClientInGame(c) && CheckCommandAccess(c,"jjd_tank_root",ADMFLAG_ROOT,true); }
public Action SpawnCommand(int c,int args)
{
    if(!Root(c)) return Plugin_Handled;
    float eye[3],ang[3],pos[3],normal[3];GetClientEyePosition(c,eye);GetClientEyeAngles(c,ang);
    Handle ray=TR_TraceRayFilterEx(eye,ang,MASK_PLAYERSOLID,RayType_Infinite,TraceFilter,c);
    if(!TR_DidHit(ray)){delete ray;ReplyToCommand(c,"[交界地] 请瞄准附近空旷地面。");return Plugin_Handled;}
    TR_GetEndPosition(pos,ray);TR_GetPlaneNormal(ray,normal);delete ray;
    if(normal[2]<0.7 || GetVectorDistance(eye,pos)>1500.0){ReplyToCommand(c,"[交界地] 请瞄准 1500 单位内的平坦地面。");return Plugin_Handled;}
    pos[2]+=4.0;
    float mins[3]={-32.0,-32.0,0.0},maxs[3]={32.0,32.0,84.0};
    Handle hull=TR_TraceHullFilterEx(pos,pos,mins,maxs,MASK_PLAYERSOLID,TraceFilter,0);
    bool blocked=TR_StartSolid(hull)||TR_AllSolid(hull)||TR_DidHit(hull);delete hull;
    if(blocked){ReplyToCommand(c,"[交界地] 空间不足，请换一个空旷位置。");return Plugin_Handled;}
    ang[0]=0.0;ang[2]=0.0;
    int tank=L4D2_SpawnTank(pos,ang);
    if(Tank(tank)){LogAction(c,tank,"Admin spawned Tank at %.1f %.1f %.1f",pos[0],pos[1],pos[2]);PrintToChatAll("[交界地] 管理员 %N 补充了一只 Tank。",c);}
    else ReplyToCommand(c,"[交界地] 生成失败，请检查当前模式与位置。");
    return Plugin_Handled;
}
public bool TraceFilter(int entity,int mask,any skip) { return skip==0 || entity!=skip; }
public Action TakeCommand(int c,int args)
{
    if(!Root(c))return Plugin_Handled;
    if(GetClientTeam(c)!=3 || Tank(c)){ReplyToCommand(c,"[交界地] 请先加入感染者队，且当前不是 Tank。");return Plugin_Handled;}
    Menu menu=new Menu(TakeHandler);menu.SetTitle("接管哪只 AI Tank？");char id[16],label[48];int count;
    for(int i=1;i<=MaxClients;i++)if(Tank(i)&&IsFakeClient(i)){IntToString(GetClientUserId(i),id,sizeof(id));Format(label,sizeof(label),"AI Tank #%d（%d HP）",GetClientUserId(i),GetClientHealth(i));menu.AddItem(id,label);count++;}
    if(count)menu.Display(c,20);else{delete menu;ReplyToCommand(c,"[交界地] 当前没有可接管的 AI Tank。");}
    return Plugin_Handled;
}
public int TakeHandler(Menu menu,MenuAction action,int c,int item)
{
    if(action==MenuAction_End){delete menu;return 0;}
    if(action!=MenuAction_Select || !Root(c) || GetClientTeam(c)!=3 || Tank(c))return 0;
    char id[16];menu.GetItem(item,id,sizeof(id));int bot=GetClientOfUserId(StringToInt(id));
    if(!Tank(bot)||!IsFakeClient(bot))return 0;
    if(IsPlayerAlive(c)){if(!GetEntProp(c,Prop_Send,"m_isGhost"))L4D_ReplaceWithBot(c);ForcePlayerSuicide(c);}
    L4D_TakeOverZombieBot(c,bot);LogAction(c,bot,"Admin took over AI Tank");return 0;
}
public void OnLibraryRemoved(const char[] name){if(StrEqual(name,"adminmenu"))adminMenu=null;}
public void OnAdminMenuReady(Handle handle)
{
    if(handle==null)return;
    TopMenu top=TopMenu.FromHandle(handle);if(top==null || top==adminMenu)return;adminMenu=top;
    TopMenuObject category=top.FindCategory(ADMINMENU_SERVERCOMMANDS);
    if(category!=INVALID_TOPMENUOBJECT){top.AddItem("jjd_spawn_tank",AdminItem,category,"sm_spawntank",ADMFLAG_ROOT);top.AddItem("jjd_take_tank",AdminItem,category,"sm_taketank",ADMFLAG_ROOT);}
}
public void AdminItem(TopMenu top,TopMenuAction action,TopMenuObject objectId,int c,char[] buffer,int size)
{
    char name[64];top.GetObjName(objectId,name,sizeof(name));bool spawn=StrEqual(name,"jjd_spawn_tank");
    if(action==TopMenuAction_DisplayOption)strcopy(buffer,size,spawn?"交界地：瞄准地面刷 Tank":"交界地：接管 AI Tank");
    else if(action==TopMenuAction_SelectOption){if(spawn)SpawnCommand(c,0);else TakeCommand(c,0);}
}
public Action Status(int args)
{
    int tanks;for(int i=1;i<=MaxClients;i++)if(Tank(i))tanks++;
    PrintToServer("JJD_TANK window=%.0f root_only=1 tanks=%d",window.FloatValue,tanks);return Plugin_Handled;
}
