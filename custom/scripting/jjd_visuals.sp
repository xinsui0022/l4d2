#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>

public Plugin myinfo={name="Jiaojiedi Visual Aids",author="Jiaojiedi",description="Team-filtered outlines and merged striped Tank forecast barriers",version="1.2.0"};
ConVar bwEnabled,markerEnabled;
int glow[MAXPLAYERS+1],forecast=INVALID_ENT_REFERENCE,beamModel;
ArrayList navs,segments,stripes;
float cachedFlow=-1.0,spawnFlow=-1.0,forecastPos[3];
bool navReady;
int transmitAllowed[4],transmitBlocked[4],transmitRepairs;
int mergedBands;
public void OnPluginStart(){
    bwEnabled=CreateConVar("jjd_bw_blue","1","Blue last-strike outline visible to infected only",0,true,0.0,true,1.0);
    markerEnabled=CreateConVar("jjd_tank_forecast","1","Forecast flow Tank trigger for infected and spectators",0,true,0.0,true,1.0);
    navs=new ArrayList();segments=new ArrayList(6);stripes=new ArrayList(6);
    RegConsoleCmd("sm_tankline",LineInfo);RegServerCmd("sm_jjd_visual_status",Status);
    HookEvent("player_team",TeamChanged);
    CreateTimer(0.5,TickGlow,_,TIMER_REPEAT);CreateTimer(1.0,TickMarkers,_,TIMER_REPEAT);
    CreateTimer(0.2,TickStripes,_,TIMER_REPEAT);
}
public void OnMapStart(){navReady=false;cachedFlow=-1.0;spawnFlow=-1.0;navs.Clear();segments.Clear();stripes.Clear();mergedBands=0;forecast=INVALID_ENT_REFERENCE;for(int c=1;c<=MaxClients;c++)glow[c]=INVALID_ENT_REFERENCE;beamModel=PrecacheModel("materials/sprites/laserbeam.vmt",true);PrecacheModel("models/infected/hulk.mdl",true);}
public void OnPluginEnd(){for(int c=1;c<=MaxClients;c++)RemoveGlow(c);RemoveForecast();}
public void OnClientDisconnect(int c){RemoveGlow(c);}
public void TeamChanged(Event event,const char[] name,bool broadcast){
    // Remove old entity identities when teams change, so a previously allowed
    // client cannot retain a cached glow after becoming a survivor.
    RemoveForecast();cachedFlow=-1.0;segments.Clear();stripes.Clear();
    for(int c=1;c<=MaxClients;c++)RemoveGlow(c);
    CreateTimer(3.0,Explain,event.GetInt("userid"),TIMER_FLAG_NO_MAPCHANGE);
}
void RequireTransmitCheck(int ent){
    if(ent<=MaxClients||!IsValidEntity(ent))return;
    int flags=GetEdictFlags(ent);
    // Glowing props may set ALWAYS, bypassing SDKHook_SetTransmit entirely.
    // FULLCHECK is zero: clear all optimized transmit modes, preserve other bits.
    int restricted=flags&~(FL_EDICT_ALWAYS|FL_EDICT_PVSCHECK|FL_EDICT_DONTSEND);
    if(flags!=restricted){SetEdictFlags(ent,restricted);transmitRepairs++;}
}
public void OnGameFrame(){
    RequireTransmitCheck(EntRefToEntIndex(forecast));
    for(int c=1;c<=MaxClients;c++)RequireTransmitCheck(EntRefToEntIndex(glow[c]));
}
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
        SDKHook(ent,SDKHook_SetTransmit,BlueTransmit);RequireTransmitCheck(ent);glow[c]=EntIndexToEntRef(ent);
    }return Plugin_Continue;
}
public Action BlueTransmit(int entity,int client){return client>0&&client<=MaxClients&&IsClientInGame(client)&&GetClientTeam(client)==3?Plugin_Continue:Plugin_Handled;}
bool ForecastAudience(int client){return client>0&&client<=MaxClients&&IsClientInGame(client)&&(GetClientTeam(client)==3||GetClientTeam(client)==1);}
public Action ForecastTransmit(int entity,int client){
    bool allowed=ForecastAudience(client);
    if(client>0&&client<=MaxClients&&IsClientInGame(client)){
        int team=GetClientTeam(client);if(team>=0&&team<4){if(allowed)transmitAllowed[team]++;else transmitBlocked[team]++;}
    }
    return allowed?Plugin_Continue:Plugin_Handled;
}
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
                // Do not turn jumps between floors or inaccessible nav edges
                // into free-floating diagonal fragments.
                if(FloatAbs(other[2]-pos[2])>64.0||L4D_NavArea_IsBlocked(area,2,false)||L4D_NavArea_IsBlocked(next,2,false))continue;
                float dx=other[0]-pos[0],dy=other[1]-pos[1],length=SquareRoot(dx*dx+dy*dy);if(length<1.0)continue;
                float width=(direction==0||direction==2)?size[0]:size[1];if(width<32.0)width=32.0;if(width>350.0)width=350.0;
                float x=pos[0]+t*dx,y=pos[1]+t*dy,z=pos[2]+t*(other[2]-pos[2])+5.0;
                float line[6];line[0]=x-dy/length*width*0.5;line[1]=y+dx/length*width*0.5;line[2]=z;line[3]=x+dy/length*width*0.5;line[4]=y-dx/length*width*0.5;line[5]=z;segments.PushArray(line,6);
            }
        }
    }delete adjacent;
    BuildStripes();
    if(best>=999999999.0)return;
    int ent=CreateEntityByName("prop_dynamic_override");if(ent==-1)return;
    DispatchKeyValue(ent,"model","models/infected/hulk.mdl");DispatchKeyValue(ent,"solid","0");DispatchSpawn(ent);
    forecastPos[2]+=3.0;TeleportEntity(ent,forecastPos,NULL_VECTOR,NULL_VECTOR);
    SetEntityRenderMode(ent,RENDER_TRANSCOLOR);SetEntityRenderColor(ent,160,210,255,80);
    SetEntProp(ent,Prop_Send,"m_iGlowType",3);SetEntProp(ent,Prop_Send,"m_glowColorOverride",255<<16|210<<8|160);SetEntProp(ent,Prop_Send,"m_nGlowRange",0);AcceptEntityInput(ent,"StartGlowing");
    SDKHook(ent,SDKHook_SetTransmit,ForecastTransmit);RequireTransmitCheck(ent);forecast=EntIndexToEntRef(ent);
}
bool BandsJoin(const float a[6],const float b[6]){
    return a[0]==b[0]&&FloatAbs(a[1]-b[1])<=64.0&&FloatAbs(a[4]-b[4])<=24.0
        &&a[2]<=b[3]+24.0&&b[2]<=a[3]+24.0;
}
void JoinBand(float a[6],const float b[6]){
    float total=a[5]+b[5];a[1]=(a[1]*a[5]+b[1]*b[5])/total;
    a[4]=(a[4]*a[5]+b[4]*b[5])/total;a[5]=total;
    if(b[2]<a[2])a[2]=b[2];if(b[3]>a[3])a[3]=b[3];
}
public bool GroundOnly(int entity,int mask,any data){return entity==0;}
void BuildStripes(){
    stripes.Clear();ArrayList bands=new ArrayList(6);
    float line[6],band[6],other[6];
    // Project neighboring fragments onto a common corridor plane. A canonical
    // direction and world-anchored stripe phase prevent X shapes and phase jumps.
    for(int i=0;i<segments.Length;i++){
        segments.GetArray(i,line,6);float dx=line[3]-line[0],dy=line[4]-line[1];
        if(dx<0.0||(FloatAbs(dx)<0.001&&dy<0.0)){dx=-dx;dy=-dy;}
        // Nav centers are irregular even in a straight corridor. Choose the
        // dominant local corridor axis, not each pair of nav centers' angle.
        float alongX,alongY,neighbor[6];
        float centerX=(line[0]+line[3])*0.5,centerY=(line[1]+line[4])*0.5,centerZ=(line[2]+line[5])*0.5;
        for(int n=0;n<segments.Length;n++){
            segments.GetArray(n,neighbor,6);float nx=(neighbor[0]+neighbor[3])*0.5-centerX,ny=(neighbor[1]+neighbor[4])*0.5-centerY;
            if(nx*nx+ny*ny>384.0*384.0||FloatAbs((neighbor[2]+neighbor[5])*0.5-centerZ)>24.0)continue;
            float wx=FloatAbs(neighbor[3]-neighbor[0]),wy=FloatAbs(neighbor[4]-neighbor[1]);
            if(wx>=wy)alongX+=wx;else alongY+=wy;
        }
        int sector=alongX>=alongY?0:6;float radians=DegToRad(float(sector)*15.0);
        float ux=Cosine(radians),uy=Sine(radians);
        float low=line[0]*ux+line[1]*uy,high=line[3]*ux+line[4]*uy;
        if(low>high){float swap=low;low=high;high=swap;}
        if(high-low<16.0)continue;
        band[0]=float(sector);band[1]=((line[0]+line[3])*(-uy)+(line[1]+line[4])*ux)*0.5;
        band[2]=low;band[3]=high;band[4]=(line[2]+line[5])*0.5;band[5]=high-low;
        bool joined;
        for(int j=0;j<bands.Length;j++){bands.GetArray(j,other,6);if(BandsJoin(other,band)){JoinBand(other,band);bands.SetArray(j,other,6);joined=true;break;}}
        if(!joined)bands.PushArray(band,6);
    }
    // A new fragment can bridge two previously separate groups.
    bool changed=true;
    while(changed){changed=false;for(int i=0;i<bands.Length&&!changed;i++){bands.GetArray(i,band,6);for(int j=i+1;j<bands.Length;j++){bands.GetArray(j,other,6);if(BandsJoin(band,other)){JoinBand(band,other);bands.SetArray(i,band,6);bands.Erase(j);changed=true;break;}}}}
    mergedBands=0;
    for(int i=0;i<bands.Length&&stripes.Length<256;i++){
        bands.GetArray(i,band,6);if(band[3]-band[2]<48.0)continue;
        float radians=DegToRad(band[0]*15.0),ux=Cosine(radians),uy=Sine(radians);
        int before=stripes.Length;
        for(float x=float(RoundToFloor(band[2]/32.0))*32.0-32.0;x<band[3]&&stripes.Length<256;x+=32.0){
            float left=x<band[2]?band[2]:x,right=x+40.0>band[3]?band[3]:x+40.0;
            if(right-left<16.0)continue;
            float start[3],end[3],hit[3],center=(left+right)*0.5;
            start[0]=center*ux-band[1]*uy;start[1]=center*uy+band[1]*ux;start[2]=band[4]+40.0;
            end=start;end[2]=band[4]-56.0;
            Handle trace=TR_TraceRayFilterEx(start,end,MASK_PLAYERSOLID,RayType_EndPoint,GroundOnly);
            bool grounded=TR_DidHit(trace);if(grounded)TR_GetEndPosition(hit,trace);delete trace;
            if(!grounded||FloatAbs(hit[2]-(band[4]-5.0))>24.0)continue;
            // One common base height per band, with thinner 48-unit slashes.
            line[0]=left*ux-band[1]*uy;line[1]=left*uy+band[1]*ux;
            line[2]=band[4]+48.0*(1.0-(left-x)/40.0);
            line[3]=right*ux-band[1]*uy;line[4]=right*uy+band[1]*ux;
            line[5]=band[4]+48.0*(1.0-(right-x)/40.0);
            stripes.PushArray(line,6);
        }
        if(stripes.Length>before)mergedBands++;
    }
    delete bands;
}
public Action TickMarkers(Handle timer){
    if(!navReady){L4D_GetAllNavAreas(navs);navReady=navs.Length>0;}
    int half=GameRules_GetProp("m_bInSecondHalfOfRound");
    if(!navReady||!markerEnabled.BoolValue||L4D_IsMissionFinalMap()||!L4D2Direct_GetVSTankToSpawnThisRound(half)){RemoveForecast();segments.Clear();cachedFlow=-1.0;spawnFlow=-1.0;return Plugin_Continue;}
    float max=L4D2Direct_GetMapMaxFlowDistance(),target=L4D2Direct_GetVSTankFlowPercent(half)*max,threshold=target-FindConVar("versus_boss_buffer").FloatValue;
    if(max<=0.0||target<=0.0||threshold<=0.0){RemoveForecast();segments.Clear();cachedFlow=-1.0;spawnFlow=-1.0;return Plugin_Continue;}
    if(FloatAbs(threshold-cachedFlow)>1.0)BuildForecast(threshold,target);
    return Plugin_Continue;
}
public Action TickStripes(Handle timer){
    if(!markerEnabled.BoolValue||cachedFlow<=0.0)return Plugin_Continue;
    int clients[MAXPLAYERS+1],count;for(int c=1;c<=MaxClients;c++)if(ForecastAudience(c)&&!IsFakeClient(c))clients[count++]=c;
    if(!count)return Plugin_Continue;
    float line[6],a[3],b[3],middle[3],eye[3];int white[4]={255,255,255,220};int drawn;
    for(int i=0;i<stripes.Length&&drawn<128;i++){
        stripes.GetArray(i,line,6);
        for(int k=0;k<3;k++)middle[k]=(line[k]+line[k+3])*0.5;
        int nearby[MAXPLAYERS+1],nearCount;
        for(int j=0;j<count;j++){GetClientEyePosition(clients[j],eye);if(GetVectorDistance(eye,middle)<3000.0)nearby[nearCount++]=clients[j];}
        if(!nearCount)continue;
        for(int k=0;k<3;k++){a[k]=line[k];b[k]=line[k+3];}
        TE_SetupBeamPoints(a,b,beamModel,0,0,0,0.22,2.5,2.5,0,0.0,white,0);TE_Send(nearby,nearCount);drawn++;
    }
    return Plugin_Continue;
}
public Action LineInfo(int c,int args){if(c>0&&IsClientInGame(c)){if(GetClientTeam(c)==2)ReplyToCommand(c,"[交界地] Tank 预览仅对感染者和旁观者显示。");else if(cachedFlow>0.0)ReplyToCommand(c,"[交界地] 白线为预计流程触发边界；蓝色 Tank 模型仅表示预测区域，最终坐标由导演决定。剧情/救援 Tank 不适用。");else ReplyToCommand(c,"[交界地] 当前没有可预测的流程 Tank；剧情/救援 Tank 或已刷出的 Tank 不显示预览。");}return Plugin_Handled;}
public Action Status(int args){int count;for(int c=1;c<=MaxClients;c++)if(EntRefToEntIndex(glow[c])>MaxClients)count++;int ent=EntRefToEntIndex(forecast);PrintToServer("JJD_VISUAL blue=%d proxies=%d markers=%d navs=%d segments=%d bands=%d stripes=%d trigger_flow=%.1f spawn_flow=%.1f flags=%d repairs=%d survivor_allowed=%d survivor_blocked=%d",bwEnabled.BoolValue,count,markerEnabled.BoolValue,navs.Length,segments.Length,mergedBands,stripes.Length,cachedFlow,spawnFlow,ent>MaxClients?GetEdictFlags(ent):-1,transmitRepairs,transmitAllowed[2],transmitBlocked[2]);return Plugin_Handled;}
