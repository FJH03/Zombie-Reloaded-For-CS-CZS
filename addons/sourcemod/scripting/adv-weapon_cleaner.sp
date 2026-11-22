#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

public Plugin:myinfo =
{
	name = "Advanced Weapon Cleaner",
	author = ".#Zipcore",
	description = "",
	version = "1.0.1",
	url = "https://gitlab.com/Zipcore/AdvWeaponCleaner"
};

enum struct WatchedWeapon
{
	int reference;
	float dropTime;
	int lastOwnerSerial;
}

ArrayList g_Weapons;

ConVar cvRemoveDelay = null;
ConVar cvRemoveDelay2 = null;
ConVar cvMuchWeapons = null;
ConVar cvWeaponsPerPlayer = null;
ConVar cvPunishment = null;
ConVar cvKeepMapWeapons = null;

int g_iWeaponCount[MAXPLAYERS + 1];

public void OnPluginStart()
{
	g_Weapons = new ArrayList(sizeof(WatchedWeapon));
	cvRemoveDelay = CreateConVar("adv_weapon_cleaner_remove_delay", "20.0", "Time to wait before weapon gets removed when a player drops it.");
	cvRemoveDelay2 = CreateConVar("adv_weapon_cleaner_remove_delay2", "0.1", "Reduced remove delay per weapon.");
	cvMuchWeapons = CreateConVar("adv_weapon_cleaner_much_weapons", "100", "How much weapons have to be spawned (including each players inventory) before intensifying remove delay.");
	cvWeaponsPerPlayer = CreateConVar("adv_weapon_cleaner_weapons_per_player", "50", "How much weapons a player can spawn before all his weapons get removed.");
	cvPunishment = CreateConVar("adv_weapon_cleaner_punishment", "1", "0: Disable 1: Warn player 2: Kick player");
	cvKeepMapWeapons = CreateConVar("adv_weapon_cleaner_keep_map_weapons", "1", "0: Disable 1: Keep");
	
	AutoExecConfig(true, "adv_weapon_cleaner");
}

public void OnMapStart()
{
	CreateTimer(0.1, Timer_Check, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public void OnMapEnd()
{
	g_Weapons.Clear();
}

public void OnEntityCreated(int iEntity, const char[] classname)
{
	// Is not c4 but weapon or item
	if(StrContains(classname, "c4") == -1 && (StrContains(classname, "weapon_") != -1 || StrContains(classname, "item_") != -1))
		SDKHook(iEntity, SDKHook_Spawn, OnWeaponSpawned);
}

public void OnWeaponSpawned(int iWeapon)
{
	SDKUnhook(iWeapon, SDKHook_Spawn, OnWeaponSpawned);
	
	int iPrevOwner = GetPreviousOwner(iWeapon);

	// Check if a player has spawned the weapon but his weapon slot was full
	if (iPrevOwner == 0)
		iPrevOwner = FindClosestPlayerOwner(iWeapon);
	if (iPrevOwner == 0 && cvKeepMapWeapons.BoolValue)
		return;

	WatchedWeapon weapon;
	weapon.reference = EntIndexToEntRef(iWeapon);
	weapon.dropTime = GetGameTime();
	weapon.lastOwnerSerial = iPrevOwner > 0 ? GetClientSerial(iPrevOwner) : 0;
	g_Weapons.PushArray(weapon, sizeof(weapon));
}

public Action Timer_Check(Handle timer, any data)
{
	UpdateWatchList();
	CheckPlayerWeaponCounts();
	CleanupWeapons();
	return Plugin_Continue;
}

void ResetPlayerWeaponCounts()
{
	// Check player spam
	for(int i = 1; i <= MaxClients; i++)
	{
		g_iWeaponCount[i] = 0;
	}
}

void CheckPlayerWeaponCounts()
{
	// Check player spam
	for(int i = 1; i <= MaxClients; i++)
	{
		if(g_iWeaponCount[i] > 0 && g_iWeaponCount[i] >= cvWeaponsPerPlayer.IntValue)
			CleanupWeaponsByPlayer(i);
	}
}

void UpdateWatchList()
{
	ResetPlayerWeaponCounts();
	
	WatchedWeapon weapon;
	for (int i = g_Weapons.Length - 1; i >= 0; --i)
	{
		g_Weapons.GetArray(i, weapon, sizeof(weapon));
		int iWeapon = EntRefToEntIndex(weapon.reference);

		if(iWeapon <= 0 || !HasEntProp(iWeapon, Prop_Send, "m_hOwnerEntity"))
		{
			g_Weapons.Erase(i);
			continue;
		}

		int iOwner = GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity");
		if(iOwner > 0)
		{
			weapon.dropTime = GetGameTime();
			weapon.lastOwnerSerial = IsPlayer(iOwner) ? GetClientSerial(iOwner) : 0;
			g_Weapons.SetArray(i, weapon, sizeof(weapon));
			continue;
		}

		int iPrevOwner = GetPreviousOwner(iWeapon);
		if (iPrevOwner > 0)
		{
			weapon.lastOwnerSerial = GetClientSerial(iPrevOwner);
			g_Weapons.SetArray(i, weapon, sizeof(weapon));
		}
		else if (weapon.lastOwnerSerial != 0)
			iPrevOwner = GetClientFromSerial(weapon.lastOwnerSerial);

		if (IsPlayer(iPrevOwner))
			g_iWeaponCount[iPrevOwner]++;
	}
}

void CleanupWeaponsByPlayer(int iClient)
{
	if (!IsClientInGame(iClient))
		return;

	int serial = GetClientSerial(iClient);
	WatchedWeapon weapon;
	for (int i = g_Weapons.Length - 1; i >= 0; --i)
	{
		g_Weapons.GetArray(i, weapon, sizeof(weapon));
		int iWeapon = EntRefToEntIndex(weapon.reference);
		if (iWeapon > 0 && weapon.lastOwnerSerial == serial &&
			GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity") <= 0)
		{
			g_Weapons.Erase(i);
			RemoveEntity(iWeapon);
		}
	}
	
	if(cvPunishment.IntValue > 0 && IsClientInGame(iClient))
	{
		if(cvPunishment.IntValue == 1)
			PrintToChat(iClient, "Removed all your weapons! Please don't spam weapons!");
		else if(cvPunishment.IntValue == 2)
			KickClient(iClient, "Weapon SPAM");
	}
}

void CleanupWeapons()
{
	int iWeaponCount = g_Weapons.Length;
	
	float fRemoveDelay = cvRemoveDelay.FloatValue;
	
	if(iWeaponCount > cvMuchWeapons.IntValue)
		fRemoveDelay -= float(iWeaponCount - cvMuchWeapons.IntValue) * cvRemoveDelay2.FloatValue;
	
	float now = GetGameTime();
	WatchedWeapon weapon;
	for (int i = iWeaponCount - 1; i >= 0; --i)
	{
		g_Weapons.GetArray(i, weapon, sizeof(weapon));
		int iWeapon = EntRefToEntIndex(weapon.reference);
		if (iWeapon > 0 && weapon.dropTime + fRemoveDelay < now &&
			GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity") <= 0)
		{
			g_Weapons.Erase(i);
			RemoveEntity(iWeapon);
		}
	}
}

int FindClosestPlayerOwner(int iEntity)
{
	float fPos[3];
	GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", fPos);
	
	float fClosestDistance = -1.0;
	int iClient;
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i))
			continue;
		
		if(!IsPlayerAlive(i))
			continue;
		
		float fTargetPos[3];
		GetClientAbsOrigin(i, fTargetPos);
		
		if(fTargetPos[0] == 0.0 && fTargetPos[1] == 0.0 && fTargetPos[2] == 0.0)
			continue;
		
		float fDistance = GetVectorDistance(fPos, fTargetPos);
		
		if (fDistance < fClosestDistance || fClosestDistance == -1.0)
		{
			fClosestDistance = fDistance;
			iClient = i;
		}
	}
	
	return fClosestDistance == 0.0 ? iClient : 0;
}

int GetPreviousOwner(int weapon)
{
	if (!HasEntProp(weapon, Prop_Send, "m_hPrevOwner"))
		return 0;

	int client = GetEntPropEnt(weapon, Prop_Send, "m_hPrevOwner");
	return IsPlayer(client) ? client : 0;
}

stock bool IsPlayer(int iEntity)
{
	return iEntity >= 1 && iEntity <= MaxClients && IsClientInGame(iEntity);
}
