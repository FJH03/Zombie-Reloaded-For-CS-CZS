#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <zombiereloaded>

#define PANEL_TEAM "team"

public Plugin myinfo =
{
	name = "[ZR] FixPlayerTeam",
	author = "[CNSR] FJH_03",
	description = "用于CZ-ZR模式的修正团队与角色插件",
	version = "4.1.1",
	url = "<-url->"
};

static bool StopSpawn[MAXPLAYERS+1];
static Handle PlayerTimer[MAXPLAYERS+1];

//定义真人用户的人物模型数组
static int iEntPlayerModelList[MAXPLAYERS+1];
static char iEntPlayerModeNamelList[MAXPLAYERS+1][64];


public OnPluginStart()
{
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
	HookEvent("round_end", RoundEnd, EventHookMode_Pre);
	AddCommandListener(OnJoinClass, "joinclass");	//监听选择人物的控制台命令
}


public OnMapStart()
{
	for (int client = 1; client <= MaxClients; client++)
		ResetPlayerSelection(client);
}

public void OnMapEnd()
{
	for (int client = 1; client <= MaxClients; client++)
		delete PlayerTimer[client];
}

public void OnClientDisconnect(int client)
{
	ResetPlayerSelection(client);
}

void ResetPlayerSelection(int client)
{
	delete PlayerTimer[client];
	StopSpawn[client] = false;
	iEntPlayerModelList[client] = 0;
	iEntPlayerModeNamelList[client][0] = '\0';
}

void SchedulePlayerTimer(int client, float delay, Timer callback)
{
	delete PlayerTimer[client];
	PlayerTimer[client] = CreateTimer(delay, callback, GetClientSerial(client), TIMER_FLAG_NO_MAPCHANGE);
}

int TakePlayerTimer(Handle timer, int serial)
{
	int client = GetClientFromSerial(serial);
	if (client == 0 || PlayerTimer[client] != timer)
		return 0;

	PlayerTimer[client] = null;
	return IsAliveClient(client) ? client : 0;
}


public Action:Event_PlayerSpawn(Handle event, const char[] name, bool dontBroadcast) 
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsAliveClient(client))
		return Plugin_Continue;

	if (IsFakeClient(client))
	{
		SchedulePlayerTimer(client, 1.0, solveBotSelect);
	}
	else if (!StopSpawn[client])
	{
		if(iEntPlayerModelList[client] >= 1 && iEntPlayerModelList[client] <= 5)
		{
			SchedulePlayerTimer(client, 0.2, SetPlayerModel_T);
			StopSpawn[client] = PlayerTimer[client] != null;
		}
		
		else if(iEntPlayerModelList[client] >= 6 && iEntPlayerModelList[client] <= 10)
		{
			SchedulePlayerTimer(client, 0.2, SetPlayerModel_CT);
			StopSpawn[client] = PlayerTimer[client] != null;
		}
	}

	return Plugin_Continue;
}

public void solveBotSelect(Handle timer, int serial) {
	int client = TakePlayerTimer(timer, serial);
	if (client != 0 && IsFakeClient(client) && ZR_IsClientHuman(client)) {
		char Name[48];
		GetClientName(client, Name, sizeof(Name));
		
		decl String:ModelStr[64];
		GetClientModel(client, ModelStr, sizeof(ModelStr));
		
		if (!StrEqual(ModelStr, "models/player/ct_sas.mdl") && StrEqual(Name, "^4S^5X^3Y^5-^2E^0.^5Y^0T^d")) {
			if (GetClientTeam(client) == CS_TEAM_T) {
				SchedulePlayerTimer(client, 0.2, SetPlayerModel_CT);
			}
			SetEntityModel(client, "models/player/ct_sas.mdl");
		}
		
		if (StrEqual(ModelStr, "models/player/ct_czy.mdl") ||
			StrEqual(ModelStr, "models/player/ct_2b.mdl") ||
			StrEqual(ModelStr, "models/player/youxiang.mdl") ||
			StrEqual(ModelStr, "models/player/hecu.mdl")) {
			if (GetClientTeam(client) == CS_TEAM_T) {
				SchedulePlayerTimer(client, 0.2, SetPlayerModel_CT);
			}
		}
		
		if (StrEqual(ModelStr, "models/player/t_viper.mdl") ||
			StrEqual(ModelStr, "models/player/miku_classic.mdl") ||
			StrEqual(ModelStr, "models/player/t_an.mdl")) {
			if (GetClientTeam(client) == CS_TEAM_CT) {
				SchedulePlayerTimer(client, 0.2, SetPlayerModel_T);
			}
		}
	}
}


public void SetPlayerModel_T(Handle timer, int serial)
{
	ApplyPlayerSelection(TakePlayerTimer(timer, serial), CS_TEAM_T);
}

public void SetPlayerModel_CT(Handle timer, int serial)
{
	ApplyPlayerSelection(TakePlayerTimer(timer, serial), CS_TEAM_CT);
}

void ApplyPlayerSelection(int client, int team)
{
	if (client == 0)
		return;

	CS_SwitchTeam(client, team);
	if (iEntPlayerModeNamelList[client][0] != '\0')
		SetEntityModel(client, iEntPlayerModeNamelList[client]);
	CS_RespawnPlayer(client);
}


public Action:RoundEnd(Handle:event, const String:name[], bool:dontBroadcast) 
{
	for (int client = 1; client <= MaxClients; client++)
	{
		delete PlayerTimer[client];
		StopSpawn[client] = false;
	}

	return Plugin_Continue;
}


//监听选择人物的控制台命令的响应函数
public Action:OnJoinClass(client, const String:command[], args)
{
	if(client > 0 && IsClientInGame(client) && !IsFakeClient(client))
	{
		decl String:sText[256]; 
		GetCmdArg(1, sText, sizeof(sText));
		StripQuotes(sText);
		TrimString(sText);
		// PrintToChatAll("命令：%s", sText); 
		int classtype = 0;
		if(strlen(sText) > 0)
			classtype = StringToInt(sText);
		
		if(classtype >= 1 && classtype <= 10)
		{
			decl String:ModelStr[64];
			if(classtype == 1)
				ModelStr = "models/player/ct_urban.mdl";
			if(classtype == 2)
				ModelStr = "models/player/ct_gsg9.mdl";
			if(classtype == 3)
				ModelStr = "models/player/ct_sas.mdl";
			if(classtype == 4)
				ModelStr = "models/player/ct_gign.mdl";
			if(classtype == 5)
				ModelStr = "models/player/ct_spetsnaz.mdl";
			if(classtype == 6)
				ModelStr = "models/player/t_phoenix.mdl";
			if(classtype == 7)
				ModelStr = "models/player/t_leet.mdl";
			if(classtype == 8)
				ModelStr = "models/player/t_arctic.mdl";
			if(classtype == 9)
				ModelStr = "models/player/t_guerilla.mdl";
			if(classtype == 10)
				ModelStr = "models/player/t_militia.mdl";
				
			TrimString(ModelStr);
			iEntPlayerModelList[client] = classtype;
			strcopy(iEntPlayerModeNamelList[client], sizeof(iEntPlayerModeNamelList[]), ModelStr);
		}
	}

	return Plugin_Continue;
}


//检测玩家属性函数
bool IsAliveClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client);
}
