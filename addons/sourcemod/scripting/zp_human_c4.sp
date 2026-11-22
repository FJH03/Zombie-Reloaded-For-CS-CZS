#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <zombiereloaded>
#include <franug_zp>

public Plugin:myinfo =
{
	name = "[ZP] human_c4",
	author = "[CNSR] FJH_03",
	description = "人类放置C4炸弹",
	version = "3.2.1",
	url = "<-url->"
};

int g_iTimerExplosion,
	g_iBombDamage,
	g_iBombRadius,
	g_iIgniteTime,
	g_iPos;
	
bool g_bPublicMsg,
	g_haveHumanC4[MAXPLAYERS + 1];

int g_C4Ref = INVALID_ENT_REFERENCE;
int g_C4Owner;
Handle g_BeepTimer, g_BoomTimer;
bool g_AwardRegistered;

enum struct ExplosionParticle
{
	int reference;
	Handle timer;
}

ArrayList g_Particles;
	
Handle	g_cTimerExplosion, g_cBombDamage, g_cBombRadius,
	g_cIgniteTime, g_cPublicMsg, g_cPos;	

// configuration part
#define AWARDNAME "human_c4" // Name of award
#define PRICE 18 // Award price
#define AWARDTEAM ZP_HUMANS // Set team that can buy this award (use ZP_BOTH ZP_HUMANS ZP_ZOMBIES)
#define TRANSLATIONS "plague_human_c4.phrases" // Set translations file for this subplugin
// end configuration

// dont touch
public OnPluginStart()
{
	g_Particles = new ArrayList(sizeof(ExplosionParticle));
	CreateTimer(0.1, Lateload);
	
	g_cTimerExplosion 		= CreateConVar("zp_c4bomb_exp_timer", 		"15", 		"炸弹爆炸前的秒数（默认 15）");
	g_cBombDamage 			= CreateConVar("zp_c4bomb_bomb_damage", 	"5000", 	"炸弹的伤害（默认 5000）");
	g_cBombRadius 			= CreateConVar("zp_c4bomb_bomb_radius", 	"600", 		"炸弹爆炸的半径（默认 600）");
	g_cIgniteTime			= CreateConVar("zp_c4bomb_ignite_time", 	"7", 		"点燃敌人的时间（以秒为单位）| 0 = 禁用（默认 7）");

	g_cPublicMsg			= CreateConVar("zp_c4bomb_plant_message", 	"1", 		"当有人放置炸弹时打印一条公共消息？| 1 = 启用 | 0 = 禁用（默认 1）");

	g_cPos			= CreateConVar("zp_c4bomb_g_iPos", 	"10", 		"放置的c4炸弹距离眼睛位置低多少位置");
	
	HookConVarChange(g_cTimerExplosion, eConvarChanged);
	HookConVarChange(g_cBombDamage, eConvarChanged);
	HookConVarChange(g_cBombRadius, eConvarChanged);
	HookConVarChange(g_cIgniteTime, eConvarChanged);
	HookConVarChange(g_cPublicMsg, eConvarChanged);
	HookConVarChange(g_cPos, eConvarChanged);
	
	HookEvent("round_end", Event_ResetRound);
	HookEvent("round_start", Event_ResetRound);

	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
			SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	}

	AutoExecConfig(true, "zombiereloaded/zp_human_c4");
	CvarsChanged();
}

public OnConfigsExecuted()
{
	CvarsChanged();
}

public void eConvarChanged(Handle hCvar, const char[] sOldVal, const char[] sNewVal)
{
	CvarsChanged();
}

void CvarsChanged()
{
	g_iTimerExplosion = GetConVarInt(g_cTimerExplosion);
	g_iBombDamage = GetConVarInt(g_cBombDamage);
	g_iBombRadius = GetConVarInt(g_cBombRadius);
	g_iIgniteTime = GetConVarInt(g_cIgniteTime);
	g_bPublicMsg = GetConVarBool(g_cPublicMsg);
	g_iPos = GetConVarInt(g_cPos);
}

public void OnMapStart()
{
	PrecacheSound("weapons/c4/c4_explode1.wav");
	PrecacheSound("weapons/c4/c4_beep3.wav");
	PrecacheSound("weapons/c4/c4_initiate.wav");
	PrecacheModel("models/weapons/w_c4_planted.mdl");
}

public void OnMapEnd()
{
	ResetRound();
	ClearExplosionParticles();
}

public void OnPluginEnd()
{
	ResetRound();
	ClearExplosionParticles();
	if (g_AwardRegistered && GetFeatureStatus(FeatureType_Native, "ZP_RemoveAward") == FeatureStatus_Available)
		ZP_RemoveAward(AWARDNAME);
}

public void OnClientPutInServer(int client) 
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage); 
	g_haveHumanC4[client] = false;
}

public void OnClientDisconnect(int client)
{
	g_haveHumanC4[client] = false;
	if (g_C4Owner != 0 && g_C4Owner == GetClientSerial(client))
		ClearC4();
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype) 
{
	if(g_iIgniteTime >= 1 && inflictor > MaxClients && IsValidEntity(inflictor))
	{
		char sExplosion[32];
		GetEntityClassname(inflictor, sExplosion, sizeof(sExplosion));

		if (StrContains(sExplosion, "env_explosion") != -1)
		{
			if(ZR_IsClientZombie(victim))
			{
				IgniteEntity(victim, g_iIgniteTime * 1.0);
				return Plugin_Changed;
			}
		}
	}

	return Plugin_Continue;
}

public Action Lateload(Handle timer)
{
	LoadTranslations(TRANSLATIONS); // translations to the local plugin
	ZP_LoadTranslations(TRANSLATIONS); // sent translations to the main plugin
	
	ZP_AddAward(AWARDNAME, PRICE, AWARDTEAM); // add award to the main plugin
	g_AwardRegistered = true;
	return Plugin_Stop;
}

public ZP_OnAwardBought( client, const String:awardbought[])
{
	if(StrEqual(awardbought, AWARDNAME))
	{
		// use your custom code here
		PrintToChat(client, "\x01\x03[\x04SM_Franug-ZombiePlague\x03]\x01 %t", "you bought human_c4");
		g_haveHumanC4[client] = true;
	}
}

public void Event_ResetRound(Event event, const char[] name, bool dontBroadcast)
{
	ResetRound();
	if (StrEqual(name, "round_start"))
		ClearExplosionParticles();
}

void ResetRound()
{
	ClearC4();
	for (int i = 1; i <= MaxClients; i++)
		g_haveHumanC4[i] = false;
}

void ClearExplosionParticles()
{
	ExplosionParticle particle;
	for (int i = g_Particles.Length - 1; i >= 0; i--)
	{
		g_Particles.GetArray(i, particle, sizeof(particle));
		delete particle.timer;
		RemoveEntityRef(particle.reference);
	}
	g_Particles.Clear();
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (IsClient(client, true)) {
		if(GetEntProp(client, Prop_Data, "m_afButtonPressed") & IN_SPEED) {
			if (g_haveHumanC4[client] && !IsFakeClient(client)) {
				Command_C4(client, 0);
			}
		}
	}

	return Plugin_Continue;
}

public Action Command_C4(int client, int args)
{
	if(!IsClientInGame(client))
	{
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(client))
	{
		PrintToChat(client, "\x01\x03[\x04SM_Franug-ZombiePlague\x03]\x01 %t", "you must be alive");
		return Plugin_Handled;
	}
	
	if(!(GetEntityFlags(client) & FL_ONGROUND))
	{
		PrintToChat(client, "\x01\x03[\x04SM_Franug-ZombiePlague\x03]\x01 %t", "you must be plant c4 on ground");
		return Plugin_Handled;
	}

	if (g_C4Ref != INVALID_ENT_REFERENCE && EntRefToEntIndex(g_C4Ref) == INVALID_ENT_REFERENCE)
		ClearC4();

	if(g_C4Ref != INVALID_ENT_REFERENCE)
	{	
		PrintToChat(client, "\x01\x03[\x04SM_Franug-ZombiePlague\x03]\x01 %t", "wait another c4 explode");
		return Plugin_Handled;
	}

	g_C4Ref = SpawnC4(client);
	if (g_C4Ref == INVALID_ENT_REFERENCE)
		return Plugin_Handled;

	g_C4Owner = GetClientSerial(client);
	DataPack bomb;
	g_BoomTimer = CreateDataTimer(float(g_iTimerExplosion), Timer_Boom, bomb, TIMER_FLAG_NO_MAPCHANGE);
	if (g_BoomTimer == null)
	{
		delete bomb;
		ClearC4();
		return Plugin_Handled;
	}
	bomb.WriteCell(g_C4Ref);
	bomb.WriteCell(g_C4Owner);
	g_BeepTimer = CreateTimer(1.0, Timer_Beep, g_C4Ref, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	g_haveHumanC4[client] = false;

	if(g_bPublicMsg)
	{
		PrintToChatAll("\x01\x03[\x04SM_Franug-ZombiePlague\x03]\x01 %t", "the bomb has been planted");
	}

	float fEyePos[3];
	GetClientEyePosition(client, fEyePos);
	EmitAmbientSound("weapons/c4/c4_initiate.wav", fEyePos, client);

	return Plugin_Handled;
}

void ClearC4()
{
	delete g_BeepTimer;
	delete g_BoomTimer;
	int reference = g_C4Ref;
	g_C4Ref = INVALID_ENT_REFERENCE;
	g_C4Owner = 0;
	RemoveEntityRef(reference);
}

public Action Timer_Beep(Handle timer, int reference)
{
	if (timer != g_BeepTimer)
		return Plugin_Stop;

	int entity = EntRefToEntIndex(reference);
	if (entity == INVALID_ENT_REFERENCE)
	{
		g_BeepTimer = null;
		ClearC4();
		return Plugin_Stop;
	}
	float origin[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);
	EmitAmbientSound("weapons/c4/c4_beep3.wav", origin, entity);
	return Plugin_Continue;
}

public Action Timer_Boom(Handle timer, DataPack bomb)
{
	if (timer != g_BoomTimer)
		return Plugin_Stop;

	bomb.Reset();
	int entity = EntRefToEntIndex(bomb.ReadCell());
	int client = GetClientFromSerial(bomb.ReadCell());
	float origin[3];
	if (entity != INVALID_ENT_REFERENCE)
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);

	g_BoomTimer = null;
	ClearC4();

	if (entity == INVALID_ENT_REFERENCE || client < 1 || !IsClientInGame(client))
		return Plugin_Stop;

	int explosion = CreateEntityByName("env_explosion");
	if (explosion == -1)
		return Plugin_Stop;

	int reference = EntIndexToEntRef(explosion);
	SetEntProp(explosion, Prop_Data, "m_spawnflags", 16384);
	SetEntProp(explosion, Prop_Data, "m_iMagnitude", g_iBombDamage);
	SetEntProp(explosion, Prop_Data, "m_iRadiusOverride", g_iBombRadius);
	TeleportEntity(explosion, origin, NULL_VECTOR, NULL_VECTOR);
	if (!DispatchSpawn(explosion))
	{
		RemoveEntityRef(reference);
		return Plugin_Stop;
	}
	ActivateEntity(explosion);
	SetEntPropEnt(explosion, Prop_Send, "m_hOwnerEntity", client);
	SpawnExplosionParticle(origin);
	EmitSoundToAll("weapons/c4/c4_explode1.wav", SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0);
	if (!AcceptEntityInput(explosion, "Explode"))
		RemoveEntityRef(reference);

	return Plugin_Stop;
}

void SpawnExplosionParticle(const float origin[3])
{
	int entity = CreateEntityByName("info_particle_system");
	if (entity == -1)
		return;

	ExplosionParticle particle;
	particle.reference = EntIndexToEntRef(entity);
	DispatchKeyValue(entity, "effect_name", "explosion_c4_500_fallback");
	TeleportEntity(entity, origin, NULL_VECTOR, NULL_VECTOR);
	if (!DispatchSpawn(entity))
	{
		RemoveEntityRef(particle.reference);
		return;
	}
	ActivateEntity(entity);
	if (!AcceptEntityInput(entity, "Start"))
	{
		RemoveEntityRef(particle.reference);
		return;
	}

	particle.timer = CreateTimer(5.0, Timer_RemoveParticle, particle.reference, TIMER_FLAG_NO_MAPCHANGE);
	if (particle.timer != null)
		g_Particles.PushArray(particle, sizeof(particle));
	else
		RemoveEntityRef(particle.reference);
}

public Action Timer_RemoveParticle(Handle timer, int reference)
{
	int index = g_Particles.FindValue(reference);
	if (index >= 0)
		g_Particles.Erase(index);
	RemoveEntityRef(reference);
	return Plugin_Stop;
}

void RemoveEntityRef(int reference)
{
	int entity = EntRefToEntIndex(reference);
	if (entity != INVALID_ENT_REFERENCE)
		RemoveEntity(entity);
}

//---------------------------------------
// Purpose: Spawn C4 bomb
//---------------------------------------

int SpawnC4(int client)
{
	int m_iEnt = CreateEntityByName("prop_dynamic_override");
	if (m_iEnt == -1)
		return INVALID_ENT_REFERENCE;
	int reference = EntIndexToEntRef(m_iEnt);

	DispatchKeyValue(m_iEnt, "model", "models/weapons/w_c4_planted.mdl"); 
	DispatchKeyValue(m_iEnt, "spawnflags", "256"); 
	DispatchKeyValue(m_iEnt, "solid", "0");
	DispatchKeyValue(m_iEnt, "modelscale", "1.0");

	float fPosition[3];
	GetClientEyePosition(client, fPosition);
	fPosition[2] -= g_iPos;
 
	if (!DispatchSpawn(m_iEnt))
	{
		RemoveEntityRef(reference);
		return INVALID_ENT_REFERENCE;
	}

	TeleportEntity(m_iEnt, fPosition, NULL_VECTOR, NULL_VECTOR);
	return reference;
}

//检测玩家属性函数
bool:IsClient(Client, bool:Alive)
{
	return Client > 0 && Client <= MaxClients && IsClientInGame(Client) && (!Alive || IsPlayerAlive(Client));
}
