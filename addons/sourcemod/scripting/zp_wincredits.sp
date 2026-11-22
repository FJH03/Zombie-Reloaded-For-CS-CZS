#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <franug_zp>

public Plugin:myinfo =
{
	name = "[ZP] wincredits",
	author = "Franc1sco franug",
	description = "",
	version = "3.1.1",
	url = "http://steamcommunity.com/id/franug"
};


new g_Movimientos[MAXPLAYERS+1];
new Handle:cvarCreditsKill = INVALID_HANDLE;
new Handle:cvarInterval = INVALID_HANDLE;
new Handle:disparos = INVALID_HANDLE;

new g_cvarCreditsKill;
new g_disparos;

new Handle:AmmoTimer2;
new Handle:g_RoundNotice;

public OnPluginStart()
{
	LoadTranslations("plague_wincredits.phrases");
	HookEvent("player_hurt", EventPlayerHurt);
	HookEvent("player_death", EventPlayerDeath);
	
	cvarInterval = CreateConVar("credits_interval", "60", "Receive credits each X seconds.", _, true, 1.0);
	
	cvarCreditsKill = CreateConVar("zombieplague_credits_kill", "2", "Number of credits for kill");
	disparos = CreateConVar("zombieplague_shots", "8", "Number of shots to zombies for receive credits");
	
	g_cvarCreditsKill = GetConVarInt(cvarCreditsKill);
	g_disparos = GetConVarInt(disparos);
	
	HookConVarChange(cvarCreditsKill, OnConVarChanged);
	HookConVarChange(disparos, OnConVarChanged);
	HookEvent("round_start", InicioRonda);
	HookEvent("round_end", FinRonda);
}

public void InicioRonda(Event event, const char[] name, bool dontBroadcast)
{
	delete g_RoundNotice;
	g_RoundNotice = CreateTimer(1.5, llamada, _, TIMER_FLAG_NO_MAPCHANGE);
}

public void FinRonda(Event event, const char[] name, bool dontBroadcast)
{
	delete g_RoundNotice;
}

public Action llamada(Handle timer)
{
	g_RoundNotice = null;
	PrintToChatAll("\x01\x03[\x04SM_Franug-ZombiePlague\x03]\x01 %t", "Mata jugadores para conseguir creditos");
	PrintToChatAll("\x01\x03[\x04SM_Franug-ZombiePlague\x03]\x01 %t", "Escribe !premios para gastar tus creditos en premios");
	return Plugin_Stop;
}

public OnConVarChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (convar == cvarCreditsKill)
	{
		g_cvarCreditsKill = StringToInt(newValue);
	}
	else if (convar == disparos)
	{
		g_disparos = StringToInt(newValue);
	}
}

public OnClientPostAdminCheck(client)
{
	g_Movimientos[client] = 0;
}

public Action:EventPlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	//new client = GetClientOfUserId(GetEventInt(event, "userid"));
	//new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	if (!attacker) return;
	
	g_Movimientos[attacker] += 1;
	if(g_Movimientos[attacker] > g_disparos)
	{
		
		ZP_SetCredits(attacker, ZP_GetCredits(attacker)+1);
		
		g_Movimientos[attacker] = 0;
	}	
}

public Action:EventPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{

	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (!attacker) return;
	if (attacker == client) return;
	
	ZP_SetCredits(attacker, ZP_GetCredits(attacker)+g_cvarCreditsKill);
	
}

public OnMapStart()
{
	delete AmmoTimer2;
	AmmoTimer2 = CreateTimer(GetConVarFloat(cvarInterval), ResetAmmo2, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public void OnMapEnd()
{
	delete g_RoundNotice;
	delete AmmoTimer2;
}

public Action ResetAmmo2(Handle timer)
{
	for (new client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client) > 1)
		{
			ZP_SetCredits(client, ZP_GetCredits(client)+1);
		}
	}

	PrintToChatAll("\x01\x03[\x04SM_Franug-ZombiePlague\x03]\x01 %t", "Has recibido 1 credito gratis! cada minuto recibiras 1 credito gratuito");
	return Plugin_Continue;
}
