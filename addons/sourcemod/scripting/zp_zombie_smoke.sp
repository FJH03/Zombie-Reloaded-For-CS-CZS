#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <zombiereloaded>
#include <franug_zp>

public Plugin:myinfo =
{
	name = "[ZP] zombie_smoke",
	author = "[CNSR] FJH_03",
	description = "僵尸放毒雾",
	version = "3.0.1",
	url = "<-url->"
};

Handle	g_cSmokeTime,g_cSmokeColor,g_cSmokeAlpha,g_cTimerDamage,g_cSmokeRadius,g_cSmokeDamage,g_cSmokeStartSize,g_cSmokeEndSize,
g_cBaseSpread, g_cSpreadSpeed,g_cSpeed, g_cRate, g_cJetLength, g_cTwist, g_cPublicMsg;
bool 	g_bPublicMsg, g_haveSmoke[MAXPLAYERS + 1];
int     g_iSmokeTime,g_iSmokeRadius,g_iSmokeDamage;
float   g_fTimerDamage;
char    g_sSmokeColor[12],g_sSmokeAlpha[4],g_sSmokeStartSize[7],g_sSmokeEndSize[7], g_sBaseSpread[7], 
g_sSpreadSpeed[7],g_sSpeed[7], g_sRate[7], g_sJetLength[7], g_sTwist[7];

enum struct SmokeCloud
{
	int reference;
	int ownerSerial;
	float center[3];
	Handle damageTimer;
	Handle expiryTimer;
}

ArrayList g_Clouds;
bool g_AwardRegistered;

// configuration part
#define AWARDNAME "zombie_smoke" // Name of award
#define PRICE 18 // Award price
#define AWARDTEAM ZP_ZOMBIES // Set team that can buy this award (use ZP_BOTH ZP_HUMANS ZP_ZOMBIES)
#define TRANSLATIONS "plague_zombie_smoke.phrases" // Set translations file for this subplugin
// end configuration

public void OnPluginStart()
{
	g_Clouds = new ArrayList(sizeof(SmokeCloud));
	CreateTimer(0.1, Lateload);
	
	g_cSmokeTime			= CreateConVar("zp_Smoke_time", 	"5", 		"毒气持续时间（以秒为单位）", FCVAR_NOTIFY);
	g_cSmokeColor         = CreateConVar("zp_Smoke_color", "0 255 0", "毒气颜色.\n三个值取值均在0-255之间，并且三个值之间均通过空格分开 (若不懂，请百度rgb就知道了).", FCVAR_NOTIFY);
	g_cSmokeAlpha         = CreateConVar("zp_Smoke_alpha", "255", "毒气透明度（0-255之间，值越低，越透明）", FCVAR_NOTIFY);
	g_cSmokeStartSize         = CreateConVar("zp_Smoke_Startsize", "600", "首次发射毒气粒子时的大小", FCVAR_NOTIFY);
	g_cSmokeEndSize         = CreateConVar("zp_Smoke_Endsize", "600", "完全淡出时毒气粒子的大小", FCVAR_NOTIFY);
	
	g_cBaseSpread         = CreateConVar("zp_Smoke_BaseSpread", "80", "产生毒气粒子时随机散布的数量", FCVAR_NOTIFY);
	g_cSpreadSpeed         = CreateConVar("zp_Smoke_SpreadSpeed", "80", "毒气粒子速度的随机分布量。", FCVAR_NOTIFY);
	g_cSpeed         = CreateConVar("zp_Smoke_Speed", "80", "毒气粒子在生成后移动的速度", FCVAR_NOTIFY);
	g_cRate         = CreateConVar("zp_Smoke_Rate", "80", "发射毒气粒子的速率（即每秒发射的粒子数）", FCVAR_NOTIFY);
	g_cJetLength         = CreateConVar("zp_Smoke_JetLength", "30", "毒气的长度", FCVAR_NOTIFY);
	g_cTwist         = CreateConVar("zp_Smoke_Twist", "50", "毒气粒子绕原点扭曲的量,即涡流", FCVAR_NOTIFY);
	
	g_cTimerDamage         = CreateConVar("zp_Smoke_TimerDamage", "0.5", "毒气每多少秒制造一次伤害", FCVAR_NOTIFY);
	g_cSmokeRadius        = CreateConVar("zp_Smoke_Radius", "600", "玩家距离毒气中心多少范围才会受到伤害", FCVAR_NOTIFY);
	g_cSmokeDamage        = CreateConVar("zp_Smoke_Damage", "10", "毒气每制造一次伤害的大小", FCVAR_NOTIFY);
	
	g_cPublicMsg			= CreateConVar("zp_Smoke_message", 	"1", 		"当有人释放毒气时打印一条公共消息？| 1 = 启用 | 0 = 禁用（默认 1）");

	HookConVarChange(g_cSmokeTime, eConvarChanged);
	HookConVarChange(g_cSmokeColor, eConvarChanged);
	HookConVarChange(g_cSmokeAlpha, eConvarChanged);
	HookConVarChange(g_cSmokeStartSize, eConvarChanged);
	HookConVarChange(g_cSmokeEndSize, eConvarChanged);
	
	HookConVarChange(g_cBaseSpread, eConvarChanged);
	HookConVarChange(g_cSpreadSpeed, eConvarChanged);
	HookConVarChange(g_cSpeed, eConvarChanged);
	HookConVarChange(g_cRate, eConvarChanged);
	HookConVarChange(g_cJetLength, eConvarChanged);
	HookConVarChange(g_cTwist, eConvarChanged);
	
	HookConVarChange(g_cTimerDamage, eConvarChanged);
	HookConVarChange(g_cSmokeRadius, eConvarChanged);
	HookConVarChange(g_cSmokeDamage, eConvarChanged);
	
	HookConVarChange(g_cPublicMsg, eConvarChanged);
	HookEvent("round_start", Event_ResetRound);
	HookEvent("round_end", Event_ResetRound);
	AutoExecConfig(true, "zombiereloaded/zp_zombie_smoke");
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
	g_bPublicMsg = GetConVarBool(g_cPublicMsg);
	g_iSmokeTime = GetConVarInt(g_cSmokeTime);
	g_fTimerDamage = GetConVarFloat(g_cTimerDamage);
	g_iSmokeRadius = GetConVarInt(g_cSmokeRadius);
	g_iSmokeDamage = GetConVarInt(g_cSmokeDamage);
	GetConVarString(g_cSmokeColor,g_sSmokeColor, sizeof(g_sSmokeColor));
	TrimString(g_sSmokeColor);
	GetConVarString(g_cSmokeAlpha,g_sSmokeAlpha, sizeof(g_sSmokeAlpha));
	GetConVarString(g_cSmokeStartSize,g_sSmokeStartSize, sizeof(g_sSmokeStartSize));
	GetConVarString(g_cSmokeEndSize,g_sSmokeEndSize, sizeof(g_sSmokeEndSize));
	
	GetConVarString(g_cBaseSpread,g_sBaseSpread, sizeof(g_sBaseSpread));
	GetConVarString(g_cSpreadSpeed,g_sSpreadSpeed, sizeof(g_sSpreadSpeed));
	GetConVarString(g_cSpeed,g_sSpeed, sizeof(g_sSpeed));
	GetConVarString(g_cRate,g_sRate, sizeof(g_sRate));
	GetConVarString(g_cJetLength,g_sJetLength, sizeof(g_sJetLength));
	GetConVarString(g_cTwist,g_sTwist, sizeof(g_sTwist));
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
		PrintToChat(client, "\x01\x03[\x04SM_Franug-ZombiePlague\x03]\x01 %t", "you bought zombie_smoke");
		g_haveSmoke[client] = true;
	}
}

public void OnMapStart()
{
	PrecacheModel("particle/particle_smokegrenade1.vmt");
}

public void OnMapEnd()
{
	ResetRound();
}

public void OnPluginEnd()
{
	ResetRound();
	if (g_AwardRegistered && GetFeatureStatus(FeatureType_Native, "ZP_RemoveAward") == FeatureStatus_Available)
		ZP_RemoveAward(AWARDNAME);
}

public void OnClientDisconnect(int client)
{
	g_haveSmoke[client] = false;
	int serial = GetClientSerial(client);
	SmokeCloud cloud;
	for (int i = g_Clouds.Length - 1; i >= 0; i--)
	{
		g_Clouds.GetArray(i, cloud, sizeof(cloud));
		if (cloud.ownerSerial == serial)
			RemoveCloud(i, cloud);
	}
}

public void Event_ResetRound(Event event, const char[] name, bool dontBroadcast)
{
	ResetRound();
}

void ResetRound()
{
	for (int client = 1; client <= MaxClients; client++)
		g_haveSmoke[client] = false;

	SmokeCloud cloud;
	for (int i = g_Clouds.Length - 1; i >= 0; i--)
	{
		g_Clouds.GetArray(i, cloud, sizeof(cloud));
		RemoveCloud(i, cloud);
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (IsClient(client, true)) {
		if(GetEntProp(client, Prop_Data, "m_afButtonPressed") & IN_ATTACK2) {
			if (g_haveSmoke[client] && !IsFakeClient(client)) {
				Command_Smoke(client, 0); 
			}
		}
	}

	return Plugin_Continue;
}

public Action Command_Smoke(int client, int args)
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
	
	if(IsClient(client, true) && !ZR_IsClientZombie(client))
	{
		PrintToChat(client, "\x01\x03[\x04SM_Franug-ZombiePlague\x03]\x01 %t", "only zombie can use this");
		return Plugin_Handled;
	}

	if (!CreateColorSmoke(client, float(g_iSmokeTime)))
		return Plugin_Handled;
	g_haveSmoke[client] = false;

	if(g_bPublicMsg) {
		PrintToChatAll("\x01\x03[\x04SM_Franug-ZombiePlague\x03]\x01 %t", "the smoke has been released");
	}

	return Plugin_Handled;
}

bool CreateColorSmoke(int client, float duration)
{
	int entity = CreateEntityByName("env_smokestack");
	if (entity == -1)
		return false;

	SmokeCloud cloud;
	cloud.reference = EntIndexToEntRef(entity);
	cloud.ownerSerial = GetClientSerial(client);
	GetClientAbsOrigin(client, cloud.center);

	char origin[64];
	Format(origin, sizeof(origin), "%f %f %f", cloud.center[0], cloud.center[1], cloud.center[2] + 15.0);
	DispatchKeyValue(entity, "Origin", origin);
	DispatchKeyValue(entity, "BaseSpread", g_sBaseSpread);
	DispatchKeyValue(entity, "SpreadSpeed", g_sSpreadSpeed);
	DispatchKeyValue(entity, "Speed", g_sSpeed);
	DispatchKeyValue(entity, "StartSize", g_sSmokeStartSize);
	DispatchKeyValue(entity, "EndSize", g_sSmokeEndSize);
	DispatchKeyValue(entity, "Rate", g_sRate);
	DispatchKeyValue(entity, "JetLength", g_sJetLength);
	DispatchKeyValue(entity, "Twist", g_sTwist);
	DispatchKeyValue(entity, "RenderColor", g_sSmokeColor);
	DispatchKeyValue(entity, "RenderAmt", g_sSmokeAlpha);
	DispatchKeyValue(entity, "SmokeMaterial", "particle/particle_smokegrenade1.vmt");

	if (!DispatchSpawn(entity) || !AcceptEntityInput(entity, "TurnOn"))
	{
		RemoveEntityRef(cloud.reference);
		return false;
	}

	cloud.expiryTimer = CreateTimer(duration, Timer_StopSmoke, cloud.reference, TIMER_FLAG_NO_MAPCHANGE);
	cloud.damageTimer = CreateTimer(g_fTimerDamage, Timer_Damage, cloud.reference, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	if (cloud.expiryTimer == null || cloud.damageTimer == null)
	{
		delete cloud.expiryTimer;
		delete cloud.damageTimer;
		RemoveEntityRef(cloud.reference);
		return false;
	}

	g_Clouds.PushArray(cloud, sizeof(cloud));
	return true;
}

public Action Timer_Damage(Handle timer, int reference)
{
	int index = g_Clouds.FindValue(reference);
	if (index < 0)
		return Plugin_Stop;

	SmokeCloud cloud;
	g_Clouds.GetArray(index, cloud, sizeof(cloud));
	if (EntRefToEntIndex(reference) == INVALID_ENT_REFERENCE)
	{
		RemoveCloud(index, cloud);
		return Plugin_Stop;
	}

	int client = GetClientFromSerial(cloud.ownerSerial);
	if (client < 1 || !IsClientInGame(client) || !ZR_IsClientZombie(client))
	{
		cloud.damageTimer = null;
		g_Clouds.SetArray(index, cloud, sizeof(cloud));
		return Plugin_Stop;
	}

	float pos[3];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i) || !ZR_IsClientHuman(i))
			continue;

		GetClientAbsOrigin(i, pos);
		if (GetVectorDistance(cloud.center, pos) <= g_iSmokeRadius)
		{
			DealDamage(client, i, g_iSmokeDamage);
			if (g_Clouds.FindValue(reference) < 0)
				return Plugin_Stop;
		}
	}
	return Plugin_Continue;
}

void DealDamage(int attacker, int victim, int damage)
{
	if (damage <= 0)
		return;

	int entity = CreateEntityByName("point_hurt");
	if (entity == -1)
		return;

	int reference = EntIndexToEntRef(entity);
	char originalName[256], targetName[32];
	GetEntPropString(victim, Prop_Data, "m_iName", originalName, sizeof(originalName));
	Format(targetName, sizeof(targetName), "__zp_smoke_hurt_%d", victim);
	DispatchKeyValue(entity, "DamageTarget", targetName);
	DispatchKeyValueFloat(entity, "Damage", float(damage));
	DispatchKeyValue(entity, "DamageType", "0");
	DispatchKeyValue(entity, "classname", "smoke");
	if (DispatchSpawn(entity))
	{
		int serial = GetClientSerial(victim);
		DispatchKeyValue(victim, "targetname", targetName);
		AcceptEntityInput(entity, "Hurt", attacker);
		if (GetClientFromSerial(serial) == victim && IsClientInGame(victim))
		{
			char currentName[32];
			GetEntPropString(victim, Prop_Data, "m_iName", currentName, sizeof(currentName));
			if (StrEqual(currentName, targetName))
				DispatchKeyValue(victim, "targetname", originalName);
		}
	}
	RemoveEntityRef(reference);
}

public Action Timer_StopSmoke(Handle timer, int reference)
{
	int index = g_Clouds.FindValue(reference);
	if (index < 0)
		return Plugin_Stop;

	SmokeCloud cloud;
	g_Clouds.GetArray(index, cloud, sizeof(cloud));
	cloud.expiryTimer = null;
	int entity = EntRefToEntIndex(reference);
	if (entity != INVALID_ENT_REFERENCE)
	{
		AcceptEntityInput(entity, "TurnOff");
		cloud.expiryTimer = CreateTimer(0.2, Timer_RemoveSmoke, reference, TIMER_FLAG_NO_MAPCHANGE);
	}

	if (cloud.expiryTimer != null)
	{
		delete cloud.damageTimer;
		g_Clouds.SetArray(index, cloud, sizeof(cloud));
	}
	else
	{
		RemoveCloud(index, cloud);
	}
	return Plugin_Stop;
}

public Action Timer_RemoveSmoke(Handle timer, int reference)
{
	int index = g_Clouds.FindValue(reference);
	if (index >= 0)
	{
		SmokeCloud cloud;
		g_Clouds.GetArray(index, cloud, sizeof(cloud));
		cloud.expiryTimer = null;
		RemoveCloud(index, cloud);
	}
	return Plugin_Stop;
}

void RemoveCloud(int index, SmokeCloud cloud)
{
	g_Clouds.Erase(index);
	delete cloud.damageTimer;
	delete cloud.expiryTimer;
	RemoveEntityRef(cloud.reference);
}

void RemoveEntityRef(int reference)
{
	int entity = EntRefToEntIndex(reference);
	if (entity != INVALID_ENT_REFERENCE)
		RemoveEntity(entity);
}

//检测玩家属性函数
bool:IsClient(Client, bool:Alive)
{
	return Client > 0 && Client <= MaxClients && IsClientInGame(Client) && (!Alive || IsPlayerAlive(Client));
}
