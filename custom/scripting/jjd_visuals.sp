#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>

public Plugin myinfo={name="Jiaojiedi Visual Aids",author="Jiaojiedi",description="Team-filtered last-strike outlines and flow Tank forecast",version="1.0.0"};
ConVar bwEnabled,markerEnabled;
int glow[MAXPLAYERS+1],forecast=INVALID_ENT_REFERENCE,beamModel;
ArrayList navs,segments;
float cachedFlow=-1.0,spawnFlow=-1.0,forecastPos[3];
bool navReady;
public void OnPluginStart(){
    bwEnabled=CreateConVar("jjd_bw_blue","1","Blue last-strike outline visible to infected only",0,true,0.0,true,1.0);
    markerEnabled=CreateConVar("jjd_tank_forecast","1","Forecast flow Tank trigger for infected and spectators",0,true,0.0,true,1.0);
    navs=new ArrayList();segments=new ArrayList(6);
    RegConsoleCmd("sm_tankline",LineInfo);RegServerCmd("sm_jjd_visual_status",Status);
    HookEvent("player_team",TeamChanged);
    CreateTimer(0.5,TickGlow,_,TIMER_REPEAT);CreateTimer(1.0,TickMarkers,_,TIMER_REPEAT);
}
public void OnMapStart(){navReady=false;cachedFlow=-1.0;spawnFlow=-1.0;navs.Clear();segments.Clear();forecast=INVALID_ENT_REFERENCE;for(int c=1;c<=MaxClients;c++)glow[c]=INVALID_ENT_REFERENCE;beamModel=PrecacheModel("materials/sprites/laserbeam.vmt",true);PrecacheModel("models/infected/hulk.mdl",true);}
public void OnPluginEnd(){for(int c=1;c<=MaxClients;c++)RemoveGlow(c);RemoveForecast();}
public void OnClientDisconnect(int c){RemoveGlow(c);}
public void TeamChanged(Event event,const char[] name,bool broadcast){CreateTimer(3.0,Explain, event.GetInt("userid"),TIMER_FLAG_NO_MAPCHANGE);}
public Action Explain(Handle timer,any userid){int c=GetClientOfUserId(userid);if(c>0&&IsClientInGame(c)&&!IsFakeClient(c)&&(GetClientTeam(c)==1||GetClientTeam(c)==3)&&cachedFlow>0.0)PrintToChat(c,"[交界地] 白线为预计出克触发边界，淡蓝 Tank 仅代表预测区域；输入 !tankline 查看说明。");return Plugin_Stop;}
bool LastStrike(int c){return IsClientInGame(c)&&GetClientTeam(c)==2&&IsPlayerAlive(c)&&!GetEntProp(c,Prop_Send,"m_isIncapacitated")&&GetEntProp(c,Prop_Send,"m_currentReviveCount")>=FindConVar("survivor_max_incapacitated_count").IntValue;}
void RemoveGlow(int c){int ent=EntRefToEntIndex(glow[c]);glow[c]=INVALID_ENT_REFERENCE;if(ent>MaxClients&&IsValidEntity(ent))RemoveEntity(ent);}
public Action TickGlow(Handle timer){
    for(int c=1;c<=MaxClients;c++){
        if(!bwEnabled.BoolValue||!LastStrike(c)){RemoveGlow(c);continue;}
        int ent=EntRefToEntIndex(glow[c]);if(ent>MaxClients&&IsValidEntity(ent))continue;
        char model[128];GetClientModel(c,model,sizeof(model));ent=CreateEntityByName("prop_dynamic_ornament");if(ent==-1)continue;
        DispatchKeyValue(ent,"model",model);DispatchKeyValue(ent,"solid","0");DispatchSpawn(ent);
        SetEntProp(ent,Prop_Send,"m_iGlowType",3);SetEntProp(ent,Prop_Send,"m_glowColorOverride",255<<16|80<<8);SetEntProp(ent,Prop_Send,"m_nGlowRange",0);
        SetEntityRenderMode(ent,RENDER_TRANSCOLOR);SetEntityRenderColor(ent,0,0,0,0);
        SetVariantString("!activator");AcceptEntityInput(ent,"SetAttached",c);AcceptEntityInput(ent,"TurnOn");AcceptEntityInput(ent,"StartGlowing");
        SDKHook(ent,SDKHook_SetTransmit,BlueTransmit);glow[c]=EntIndexToEntRef(ent);
    }return Plugin_Continue;
}
public Action BlueTransmit(int entity,int client){return IsClientInGame(client)&&GetClientTeam(client)==3?Plugin_Continue:Plugin_Handled;}
public Action ForecastTransmit(int entity,int client){return IsClientInGame(client)&&(GetClientTeam(client)==3||GetClientTeam(client)==1)?Plugin_Continue:Plugin_Handled;}
void RemoveForecast(){int ent=EntRefToEntIndex(forecast);forecast=INVALID_ENT_REFERENCE;if(ent>MaxClients&&IsValidEntity(ent))RemoveEntity(ent);}
void BuildForecast(float threshold,float target){
    segments.Clear();RemoveForecast();cachedFlow=threshold;spawnFlow=target;
    ArrayList adjacent=new ArrayList();float best=999999999.0;
    for(int i=0;i<navs.Length;i++){
        Address area=view_as<Address>(navs.Get(i));float flow=L4D2Direct_GetTerrorNavAreaFlow(area);if(flow<0.0||flow>10000000.0)continue;
        float pos[3];L4D_GetNavAreaCenter(area,pos);float distance=FloatAbs(flow-target);
        if(distance<best&&!L4D_NavArea_IsBlocked(area,2,false)){best=distance;forecastPos=pos;}
        if(flow>=threshold||threshold-flow>2500.0||segments.Length>=48)continue;
        for(int direction=0;direction<4;direction++){
            adjacent.Clear();L4D_NavArea_GetAdjacentAreas(area,direction,adjacent);
            for(int j=0;j<adjacent.Length&&segments.Length<48;j++){
                Address next=view_as<Address>(adjacent.Get(j));float otherFlow=L4D2Direct_GetTerrorNavAreaFlow(next);
                if(otherFlow<threshold||otherFlow>10000000.0||otherFlow<=flow)continue;
                float other[3],size[3],t=(threshold-flow)/(otherFlow-flow);L4D_GetNavAreaCenter(next,other);L4D_GetNavAreaSize(area,size);
                float dx=other[0]-pos[0],dy=other[1]-pos[1],length=SquareRoot(dx*dx+dy*dy);if(length<1.0)continue;
                float width=(direction==0||direction==2)?size[0]:size[1];if(width<32.0)width=32.0;if(width>350.0)width=350.0;
                float x=pos[0]+t*dx,y=pos[1]+t*dy,z=pos[2]+t*(other[2]-pos[2])+5.0;
                float line[6];line[0]=x-dy/length*width*0.5;line[1]=y+dx/length*width*0.5;line[2]=z;line[3]=x+dy/length*width*0.5;line[4]=y-dx/length*width*0.5;line[5]=z;segments.PushArray(line,6);
            }
        }
    }delete adjacent;
    if(best>=999999999.0)return;
    int ent=CreateEntityByName("prop_dynamic_override");if(ent==-1)return;
    DispatchKeyValue(ent,"model","models/infected/hulk.mdl");DispatchKeyValue(ent,"solid","0");DispatchSpawn(ent);
    forecastPos[2]+=3.0;TeleportEntity(ent,forecastPos,NULL_VECTOR,NULL_VECTOR);
    SetEntityRenderMode(ent,RENDER_TRANSCOLOR);SetEntityRenderColor(ent,160,210,255,80);
    SetEntProp(ent,Prop_Send,"m_iGlowType",3);SetEntProp(ent,Prop_Send,"m_glowColorOverride",255<<16|210<<8|160);SetEntProp(ent,Prop_Send,"m_nGlowRange",0);AcceptEntityInput(ent,"StartGlowing");
    SDKHook(ent,SDKHook_SetTransmit,ForecastTransmit);forecast=EntIndexToEntRef(ent);
}
public Action TickMarkers(Handle timer){
    if(!navReady){L4D_GetAllNavAreas(navs);navReady=navs.Length>0;}
    int half=GameRules_GetProp("m_bInSecondHalfOfRound");
    if(!navReady||!markerEnabled.BoolValue||L4D_IsMissionFinalMap()||!L4D2Direct_GetVSTankToSpawnThisRound(half)){RemoveForecast();segments.Clear();cachedFlow=-1.0;spawnFlow=-1.0;return Plugin_Continue;}
    float max=L4D2Direct_GetMapMaxFlowDistance(),target=L4D2Direct_GetVSTankFlowPercent(half)*max,threshold=target-FindConVar("versus_boss_buffer").FloatValue;
    if(max<=0.0||target<=0.0||threshold<=0.0){RemoveForecast();segments.Clear();cachedFlow=-1.0;spawnFlow=-1.0;return Plugin_Continue;}
    if(FloatAbs(threshold-cachedFlow)>1.0)BuildForecast(threshold,target);
    int clients[MAXPLAYERS+1],count;for(int c=1;c<=MaxClients;c++)if(IsClientInGame(c)&&!IsFakeClient(c)&&(GetClientTeam(c)==1||GetClientTeam(c)==3))clients[count++]=c;
    if(!count)return Plugin_Continue;
    float line[6],a[3],b[3];int white[4]={255,255,255,210};
    for(int i=0;i<segments.Length;i++){segments.GetArray(i,line,6);for(int k=0;k<3;k++){a[k]=line[k];b[k]=line[k+3];}TE_SetupBeamPoints(a,b,beamModel,0,0,0,1.1,2.5,2.5,0,0.0,white,0);TE_Send(clients,count);}
    return Plugin_Continue;
}
public Action LineInfo(int c,int args){if(c>0&&IsClientInGame(c)){if(GetClientTeam(c)==2)ReplyToCommand(c,"[交界地] Tank 预览仅对感染者和旁观者显示。");else if(cachedFlow>0.0)ReplyToCommand(c,"[交界地] 白线为预计流程触发边界；蓝色 Tank 模型仅表示预测区域，最终坐标由导演决定。剧情/救援 Tank 不适用。");else ReplyToCommand(c,"[交界地] 当前没有可预测的流程 Tank；剧情/救援 Tank 或已刷出的 Tank 不显示预览。");}return Plugin_Handled;}
public Action Status(int args){int count;for(int c=1;c<=MaxClients;c++)if(EntRefToEntIndex(glow[c])>MaxClients)count++;PrintToServer("JJD_VISUAL blue=%d proxies=%d markers=%d navs=%d segments=%d trigger_flow=%.1f spawn_flow=%.1f",bwEnabled.BoolValue,count,markerEnabled.BoolValue,navs.Length,segments.Length,cachedFlow,spawnFlow);return Plugin_Handled;}
