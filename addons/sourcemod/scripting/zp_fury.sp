#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <franug_zp>

public Plugin:myinfo =
{
	name = "[ZP] fury",
	author = "Franc1sco franug",
	description = "",
	version = "3.1.1",
	url = "http://steamcommunity.com/id/franug"
};

// configuration part
#define AWARDNAME "fury" // Name of award
#define PRICE 20 // Award price
#define AWARDTEAM ZP_BOTH // Set team that can buy this award (use ZP_BOTH ZP_HUMANS ZP_ZOMBIES)
#define TRANSLATIONS "plague_fury.phrases" // Set translations file for this subplugin
// end configuration

enum struct FuryState
{
	Handle timer;
	int takeDamage;
	int color[4];
}

FuryState g_Fury[MAXPLAYERS + 1];
bool g_AwardRegistered;

public void OnPluginStart()
{
	CreateTimer(0.1, Lateload);
	HookEvent("player_death", Event_ResetPlayer);
	HookEvent("player_spawn", Event_ResetPlayer);
	HookEvent("round_end", Event_RoundEnd);
}

public Action Lateload(Handle timer)
{
	LoadTranslations(TRANSLATIONS); // translations to the local plugin
	ZP_LoadTranslations(TRANSLATIONS); // sent translations to the main plugin
	ZP_AddAward(AWARDNAME, PRICE, AWARDTEAM); // add award to the main plugin
	g_AwardRegistered = true;
	return Plugin_Stop;
}

public void OnPluginEnd()
{
	ClearAllFury();
	if (g_AwardRegistered && GetFeatureStatus(FeatureType_Native, "ZP_RemoveAward") == FeatureStatus_Available)
		ZP_RemoveAward(AWARDNAME);
}

public void OnMapEnd()
{
	ClearAllFury();
}

public void OnClientDisconnect(int client)
{
	ClearFury(client);
}

public void Event_ResetPlayer(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client > 0)
		ClearFury(client);
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	ClearAllFury();
}

void ClearAllFury()
{
	for (int client = 1; client <= MaxClients; client++)
		ClearFury(client);
}

void ClearFury(int client)
{
	if (g_Fury[client].timer == null)
		return;

	delete g_Fury[client].timer;
	if (!IsClientInGame(client))
		return;

	if (GetEntProp(client, Prop_Data, "m_takedamage", 1) == 0)
		SetEntProp(client, Prop_Data, "m_takedamage", g_Fury[client].takeDamage, 1);

	int red, green, blue, alpha;
	GetEntityRenderColor(client, red, green, blue, alpha);
	if (red == 255 && green == 0 && blue == 0)
	{
		red = g_Fury[client].color[0];
		green = g_Fury[client].color[1];
		blue = g_Fury[client].color[2];
	}
	if (alpha == 255)
		alpha = g_Fury[client].color[3];
	SetEntityRenderColor(client, red, green, blue, alpha);
}

public int ZP_OnAwardBought(int client, const char[] awardbought)
{
	if (!StrEqual(awardbought, AWARDNAME) || client < 1 || client > MaxClients ||
		!IsClientInGame(client) || !IsPlayerAlive(client))
		return 0;

	Handle timer = CreateTimer(5.0, Timer_ExpireFury, GetClientSerial(client), TIMER_FLAG_NO_MAPCHANGE);
	if (timer == null)
		return 0;

	ClearFury(client);
	g_Fury[client].takeDamage = GetEntProp(client, Prop_Data, "m_takedamage", 1);
	GetEntityRenderColor(client, g_Fury[client].color[0], g_Fury[client].color[1],
		g_Fury[client].color[2], g_Fury[client].color[3]);
	g_Fury[client].timer = timer;
	SetEntProp(client, Prop_Data, "m_takedamage", 0, 1);
	SetEntityRenderColor(client, 255, 0, 0, 255);
	PrintToChat(client, "\x01\x03[\x04SM_Franug-ZombiePlague\x03]\x01 %t", "you bought fury");
	return 0;
}

public Action Timer_ExpireFury(Handle timer, int serial)
{
	int client = GetClientFromSerial(serial);
	if (client < 1 || g_Fury[client].timer != timer)
		return Plugin_Stop;

	ClearFury(client);
	if (IsClientInGame(client) && IsPlayerAlive(client))
		PrintToChat(client, "\x01\x03[\x04SM_Franug-ZombiePlague\x03]\x01 %t", "Ya no eres INVULNERABLE!");
	return Plugin_Stop;
}
