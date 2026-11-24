#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "2.1.0"

public Plugin:myinfo = 
{
	name = "Advance-Noblock",
	author = "[CNSR] FJH_03",
	description = "AgPB 加载时持续取消玩家碰撞，否则连点计分板临时取消指定玩家碰撞",
	version = PLUGIN_VERSION,
	url = "http://otstrel.ru"
};

// ===========================================================================
// GLOBALS
// ===========================================================================

new g_offsCollisionGroup;
new bool:g_enabled_nades;
new bool:g_enabled_hostages;
new Float:g_noblockTime;

new Handle:sm_noblock_nades;
new Handle:sm_noblock_hostages;
new Handle:sm_noblock_time;

#define COLLISION_GROUP_DEBRIS_TRIGGER 2
#define COLLISION_GROUP_PLAYER 5
#define AGPB_PRESENCE_CONVAR "agpb_enable"
#define ZR_ANTISTICK_CONVAR "zr_antistick"

enum struct NoBlockRequest
{
	Handle timer;
	int targetSerial;
	bool active;
}

NoBlockRequest g_Request[MAXPLAYERS + 1];
int g_TargetPasses[MAXPLAYERS + 1];
int g_TargetCollisionGroup[MAXPLAYERS + 1];

bool g_MapRunning;
bool g_AgPBNoBlock;
int g_AgPBClientSerial[MAXPLAYERS + 1];
int g_AgPBPreviousGroup[MAXPLAYERS + 1];
ConVar g_ZRAntiStick;
bool g_RestoreZRAntiStick;

#define cDefault 0x01
#define cLightGreen 0x03

public OnPluginStart()
{
	g_offsCollisionGroup = FindSendPropInfo("CBaseEntity", "m_CollisionGroup");
	
	if (g_offsCollisionGroup <= 0)
	{
		SetFailState("[NoBlock] Failed to get offset for CBaseEntity::m_CollisionGroup.");
	}
	
	sm_noblock_nades = CreateConVar("sm_noblock_nades", "1", "Removes player vs. nade collisions");
	
	HookConVarChange(sm_noblock_nades, OnConVarChange);
	
	sm_noblock_hostages = CreateConVar("sm_noblock_hostages", "1", "Removes player vs. hostage collisions");
	
	HookConVarChange(sm_noblock_hostages, OnConVarChange);
	
	sm_noblock_time = CreateConVar("sm_noblock_time", "2", "No blocking only for that time");
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("round_end", Event_RoundEnd);
	CreateTimer(0.2, Timer_AgPBNoBlock, _, TIMER_REPEAT);
	
	AutoExecConfig(true, "adv-noblock");
	CvarsChanged();
}

public OnConfigsExecuted()
{
	CvarsChanged();
	RefreshAgPBNoBlock();
}

public OnConVarChange(Handle:hCvar, const String:oldValue[], const String:newValue[])
{
	CvarsChanged();
}

void CvarsChanged()
{
	g_enabled_nades = GetConVarBool(sm_noblock_nades);
	
	g_enabled_hostages = GetConVarBool(sm_noblock_hostages);
	if (g_enabled_hostages) {
		 UnblockHostages();
	} else {
		BlockHostages();
	}
	
	g_noblockTime = GetConVarFloat(sm_noblock_time);
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (!g_AgPBNoBlock && IsClient(client, true)) {
		if(GetEntProp(client, Prop_Data, "m_afButtonPressed") & IN_SCORE) {
			if (!IsFakeClient(client)) {
				int Target = GetClientAimTarget(client, true);   // 获取准心目标实体
				if (IsClient(Target, true)) {
					RequestNoBlock(client, Target);
				}
			}
		}
	}

	return Plugin_Continue;
}

public OnEntityCreated(entity, const String:classname[])
{
	if ( g_enabled_nades )
	{
		//Enable NoBlock on Nades
		if (StrEqual(classname, "hegrenade_projectile")) {
			UnblockEntity(entity);
		} else if (StrEqual(classname, "flashbang_projectile")) {
			UnblockEntity(entity);
		} else if (StrEqual(classname, "smokegrenade_projectile")) {
			UnblockEntity(entity);
		}
	}
}

void RequestNoBlock(int client, int target)
{
	int serial = GetClientSerial(target);
	bool sameTarget = g_Request[client].targetSerial == serial;
	bool active = sameTarget && g_Request[client].active;
	Handle timer = CreateTimer(g_noblockTime, Timer_PlayerUnblock, GetClientSerial(client), TIMER_FLAG_NO_MAPCHANGE);
	if (timer == null)
		return;

	if (sameTarget)
		delete g_Request[client].timer;
	else
		EndRequest(client, false);

	g_Request[client].timer = timer;
	g_Request[client].targetSerial = serial;
	if (sameTarget && !active)
	{
		int collisionGroup = GetEntData(target, g_offsCollisionGroup, 4);
		if (g_TargetPasses[target] == 0 || collisionGroup != COLLISION_GROUP_DEBRIS_TRIGGER)
		{
			g_TargetCollisionGroup[target] = collisionGroup;
			UnblockEntity(target);
		}
		g_TargetPasses[target]++;
		g_Request[client].active = true;
		PrintToChat(target, "%c[NoBlock] %c%N 尝试穿透你！", cLightGreen, cDefault, client);
	}
}

public Action Timer_PlayerUnblock(Handle timer, int serial)
{
	int client = GetClientFromSerial(serial);
	if (client > 0 && g_Request[client].timer == timer)
		EndRequest(client, true);
	return Plugin_Stop;
}

void EndRequest(int client, bool notify)
{
	if (g_Request[client].timer == null)
		return;

	delete g_Request[client].timer;
	int target = GetClientFromSerial(g_Request[client].targetSerial);
	bool active = g_Request[client].active;
	g_Request[client].targetSerial = 0;
	g_Request[client].active = false;

	if (!active || target < 1)
		return;
	if (--g_TargetPasses[target] != 0 || !IsClientInGame(target))
		return;

	if (GetEntData(target, g_offsCollisionGroup, 4) == COLLISION_GROUP_DEBRIS_TRIGGER)
		SetEntData(target, g_offsCollisionGroup, g_TargetCollisionGroup[target], 4, true);

	if (notify && IsClient(client, true) && IsClient(target, true))
	{
		PrintToChat(client, "%c[NoBlock] %c现在你不能穿透 %N 了！", cLightGreen, cDefault, target);
		PrintToChat(target, "%c[NoBlock] %c现在你不可被穿透！", cLightGreen, cDefault);
	}
}

void EndPlayerRequests(int client)
{
	int serial = GetClientSerial(client);
	EndRequest(client, false);
	for (int other = 1; other <= MaxClients; other++)
	{
		if (g_Request[other].targetSerial == serial)
			EndRequest(other, false);
	}
	g_TargetPasses[client] = 0;
}

void EndAllRequests()
{
	for (int client = 1; client <= MaxClients; client++)
		EndRequest(client, false);
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client > 0)
	{
		EndPlayerRequests(client);
		RestoreAgPBClient(client);
	}
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	// Apply after the engine and ZR finish their spawn handlers.
	if (g_AgPBNoBlock)
		RequestFrame(RefreshAgPBClient, event.GetInt("userid"));
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	EndAllRequests();
}

public void OnClientDisconnect(int client)
{
	EndPlayerRequests(client);
	g_AgPBClientSerial[client] = 0;
}

public void OnMapStart()
{
	g_MapRunning = true;
	RefreshAgPBNoBlock();
}

public void OnMapEnd()
{
	g_MapRunning = false;
	EndAllRequests();
	StopAgPBNoBlock();
}

public void OnPluginPauseChange(bool pause)
{
	if (pause)
	{
		EndAllRequests();
		StopAgPBNoBlock();
	}
	else
	{
		char map[PLATFORM_MAX_PATH];
		g_MapRunning = GetCurrentMap(map, sizeof(map)) > 0;
		RefreshAgPBNoBlock();
	}
}

public void OnPluginEnd()
{
	EndAllRequests();
	StopAgPBNoBlock();
}

public Action Timer_AgPBNoBlock(Handle timer)
{
	RefreshAgPBNoBlock();
	return Plugin_Continue;
}

void RefreshAgPBNoBlock()
{
	if (!g_MapRunning)
		return;

	// Metamod registers this ConVar with AgPB and removes it on unload.
	// Its value represents bot control, so only its presence matters here.
	if (FindConVar(AGPB_PRESENCE_CONVAR) == null)
	{
		StopAgPBNoBlock();
		return;
	}

	if (!g_AgPBNoBlock)
	{
		EndAllRequests();
		g_AgPBNoBlock = true;
	}
	HoldZRAntiStick();
	for (int client = 1; client <= MaxClients; client++)
		ApplyAgPBNoBlock(client);
}

public void RefreshAgPBClient(int userId)
{
	int client = GetClientOfUserId(userId);
	if (g_AgPBNoBlock && client > 0)
		ApplyAgPBNoBlock(client);
}

void ApplyAgPBNoBlock(int client)
{
	if (!IsClient(client, true) || IsClientObserver(client))
	{
		RestoreAgPBClient(client);
		return;
	}

	int group = GetEntProp(client, Prop_Send, "m_CollisionGroup");
	// Already nonblocking, possibly due to a ZR antistick timer in flight.
	if (group == COLLISION_GROUP_DEBRIS_TRIGGER)
		return;

	g_AgPBClientSerial[client] = GetClientSerial(client);
	g_AgPBPreviousGroup[client] = group;
	SetAgPBClientCollisionGroup(client, COLLISION_GROUP_DEBRIS_TRIGGER);
}

void RestoreAgPBClient(int client)
{
	int serial = g_AgPBClientSerial[client];
	g_AgPBClientSerial[client] = 0;
	if (serial != 0 && GetClientFromSerial(serial) == client && IsClientInGame(client)
		&& GetEntProp(client, Prop_Send, "m_CollisionGroup") == COLLISION_GROUP_DEBRIS_TRIGGER)
	{
		SetAgPBClientCollisionGroup(client, g_AgPBPreviousGroup[client]);
	}
}

void SetAgPBClientCollisionGroup(int client, int group)
{
	SetEntProp(client, Prop_Send, "m_CollisionGroup", group);
	EntityCollisionRulesChanged(client);
}

void HoldZRAntiStick()
{
	if (g_ZRAntiStick != null)
		return;

	g_ZRAntiStick = FindConVar(ZR_ANTISTICK_CONVAR);
	if (g_ZRAntiStick != null)
	{
		g_RestoreZRAntiStick = g_ZRAntiStick.BoolValue;
		g_ZRAntiStick.BoolValue = false;
		g_ZRAntiStick.AddChangeHook(OnZRAntiStickChanged);
	}
}

public void OnZRAntiStickChanged(ConVar antiStick, const char[] oldValue, const char[] newValue)
{
	if (antiStick.BoolValue)
	{
		g_RestoreZRAntiStick = true;
		antiStick.BoolValue = false;
	}
}

void StopAgPBNoBlock()
{
	if (!g_AgPBNoBlock)
		return;

	g_AgPBNoBlock = false;
	for (int client = 1; client <= MaxClients; client++)
		RestoreAgPBClient(client);

	if (g_ZRAntiStick != null)
	{
		g_ZRAntiStick.RemoveChangeHook(OnZRAntiStickChanged);
		g_ZRAntiStick.BoolValue = g_RestoreZRAntiStick;
		g_ZRAntiStick = null;
	}
}

UnblockHostages() {
	new String:sClassName[32];
	new iMaxEntities = GetMaxEntities();
	
	/* Apparently the clients are always at the start of the entity list,
		so we can skip them in hopes of reducing roundstart lag */
		
	for ( new iEntity = MaxClients + 1; iEntity < iMaxEntities; iEntity++ )
	{
		if ( !IsValidEntity(iEntity) || !IsValidEdict(iEntity) ) {
			continue;
		}		
		GetEdictClassname(iEntity, sClassName, sizeof(sClassName));
		if ( StrEqual("hostage_entity", sClassName) ) {
			UnblockEntity(iEntity);
		}
	}
}	

BlockHostages() {
	new String:sClassName[32];
	new iMaxEntities = GetMaxEntities();
	
	/* Apparently the clients are always at the start of the entity list,
		so we can skip them in hopes of reducing roundstart lag */
		
	for ( new iEntity = MaxClients + 1; iEntity < iMaxEntities; iEntity++ )
	{
		if ( !IsValidEntity(iEntity) || !IsValidEdict(iEntity) ) {
			continue;
		}		
		GetEdictClassname(iEntity, sClassName, sizeof(sClassName));
		if ( StrEqual("hostage_entity", sClassName) ) {
			BlockEntity(iEntity);
		}
	}
}

BlockEntity(client)
{
	SetEntData(client, g_offsCollisionGroup, COLLISION_GROUP_PLAYER, 4, true);
}

UnblockEntity(client)
{
	SetEntData(client, g_offsCollisionGroup, COLLISION_GROUP_DEBRIS_TRIGGER, 4, true);
}

//检测玩家属性函数
bool:IsClient(Client, bool:Alive)
{
	return Client > 0 && Client <= MaxClients && IsClientInGame(Client) && (!Alive || IsPlayerAlive(Client));
}




