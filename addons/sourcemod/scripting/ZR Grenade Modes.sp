#pragma semicolon 1

/* ========================================================================= */
/* INCLUDES																  */
/* ========================================================================= */

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <zombiereloaded>

/* ========================================================================= */
/* DEFINES																   */
/* ========================================================================= */

/* Plugin version															*/
#define C_PLUGIN_VERSION				"1.4.8"

/* ------------------------------------------------------------------------- */

#define FLASH 0
#define SMOKE 1

#define SOUND_FREEZE	"physics/glass/glass_impact_bullet4.wav"
#define SOUND_FREEZE_EXPLODE	"ui/freeze_cam.wav"

#define FragColor 	{255,75,75,255}
#define FlashColor 	{255,255,255,255}
#define FreezeColor	{75,75,255,255}

new Float:f_smoke_freeze_distance=600.0, Float:f_smoke_freeze_duration=4.0;
new Handle:h_fwdOnClientFreeze,
	Handle:h_fwdOnClientFreezed;
	
new Handle:h_freeze_timer[MAXPLAYERS+1];
new Float:NULL_VELOCITY[3] = {0.0, 0.0, 0.0};

/* No grenade type (Assault rifle, knife..)								  */
#define C_GRENADE_TYPE_NONE			 (-1)
/* High explosive grenade type											   */
#define C_GRENADE_TYPE_HE			   (0)
/* Flashbang grenade type													*/
#define C_GRENADE_TYPE_FLASHBANG		(1)
/* Smoke grenade type														*/
#define C_GRENADE_TYPE_SMOKE			(2)
/* Maximum grenade type													  */
#define C_GRENADE_TYPE_MAXIMUM		  (3)

/* Normal grenade mode													   */
#define C_GRENADE_MODE_NORMAL		   (0)
/* Impact grenade mode													   */
#define C_GRENADE_MODE_IMPACT		   (1)
/* Proximity grenade mode													*/
#define C_GRENADE_MODE_PROXIMITY		(2)
/* Tripwire grenade mode													 */
#define C_GRENADE_MODE_TRIPWIRE		 (3)
/* Maximum grenade mode													  */
#define C_GRENADE_MODE_MAXIMUM		  (4)

#define C_BOT_TRIPWIRE_WALL_RANGE 400.0
#define C_BOT_TRIPWIRE_WALL_NORMAL_Z 0.866026

/* Wait idle proximity state												 */
#define C_PROXIMITY_STATE_WAIT_IDLE	 (0)
/* Powerup proximity state												   */
#define C_PROXIMITY_STATE_POWERUP	   (1)
/* Detect proximity state													*/
#define C_PROXIMITY_STATE_DETECT		(2)
/* Maximum proximity state												   */
#define C_PROXIMITY_STATE_MAXIMUM	   (3)

/* Powerup tripwire state													*/
#define C_TRIPWIRE_STATE_POWERUP		(0)
/* Detect tripwire state													 */
#define C_TRIPWIRE_STATE_DETECT		 (1)
/* Maximum tripwire state													*/
#define C_TRIPWIRE_STATE_MAXIMUM		(2)

new BeamSprite, GlowSprite, g_beamsprite, g_halosprite;

/* ========================================================================= */
/* GLOBAL CONSTANTS														  */
/* ========================================================================= */

/* Plugin information														*/
public Plugin myinfo =
{
	name		= "[ZR] Grenade Modes",
	author	  = "Nyuu, modified by [CNSR] FJH_03",
	description = "Provide new modes for the grenades",
	version	 = C_PLUGIN_VERSION,
	url		 = "https://forums.alliedmods.net/showthread.php?t=309154"
}

/* ------------------------------------------------------------------------- */

/* Grenade type names (Translation)										  */
char gl_szGrenadeTypeNameTr[C_GRENADE_TYPE_MAXIMUM][] =
{
	"TExplosive", // HE
	"TFlashbang", // FLASHBANG
	"TSmoke"	  // SMOKE
};

/* Grenade mode names (Translation)										  */
char gl_szGrenadeModeNameTr[C_GRENADE_MODE_MAXIMUM][] =
{
	"TNormal",	// NORMAL
	"TImpact",	// IMPACT
	"TProximity", // PROXIMITY
	"TTripwire"   // TRIPWIRE
};

/* Grenade mode limits													   */
int gl_iGrenadeModeLimits[C_GRENADE_TYPE_MAXIMUM] = 
{
	C_GRENADE_MODE_MAXIMUM, // HE
	C_GRENADE_MODE_MAXIMUM, // FLASHBANG
	C_GRENADE_MODE_MAXIMUM // SMOKE
};

/* ========================================================================= */
/* GLOBAL VARIABLES														  */
/* ========================================================================= */

/* Plugin late loading													   */
bool	  gl_bPluginLateLoading;

/* Players in game														   */
bool	  gl_bPlayerInGame	 [MAXPLAYERS + 1];
/* Players current grenade type											  */
int	   gl_iPlayerGrenadeType[MAXPLAYERS + 1];
/* Players mode for each grenade type										*/
int	   gl_iPlayerGrenadeMode[MAXPLAYERS + 1][C_GRENADE_TYPE_MAXIMUM];

/* Beacon sprite															 */
int	   gl_nSpriteBeacon;
/* Beam sprite															   */
int	   gl_nSpriteBeam;
/* Halo sprite															   */
int	   gl_nSpriteHalo;

/* Grenade weapon name stringmap											 */
StringMap gl_hGrenadeWeaponName;
/* Grenade projectile name stringmap										 */
StringMap gl_hGrenadeProjectileName;

/* ------------------------------------------------------------------------- */

/* Plugin enable cvar														*/
ConVar	gl_hCvarPluginEnable;
/* Color of the self effects cvar											*/
ConVar	gl_hCvarEffectsSelfColor;
/* Color of the teammate effects cvar										*/
ConVar	gl_hCvarEffectsTeammateColor;
/* Color of the enemy effects cvar										   */
ConVar	gl_hCvarEffectsEnemyColor;
/* Powerup time for the proximity mode cvar								  */
ConVar	gl_hCvarProximityPowerupTime;
/* Powerup time for the tripwire mode cvar								   */
ConVar	gl_hCvarTripwirePowerupTime;

/* Plugin enable cvar value												  */
bool	  gl_bCvarPluginEnable;
/* Color of the self effects cvar value									  */
int	   gl_iCvarEffectsSelfColor;
/* Color of the teammate effects cvar value								  */
int	   gl_iCvarEffectsTeammateColor;
/* Color of the enemy effects cvar value									 */
int	   gl_iCvarEffectsEnemyColor;
/* Powerup time for the proximity mode cvar value							*/
float	 gl_flCvarProximityPowerupTime;
/* Powerup time for the tripwire mode cvar value							 */
float	 gl_flCvarTripwirePowerupTime;


/* ========================================================================= */
/* FUNCTIONS																 */
/* ========================================================================= */

/* ------------------------------------------------------------------------- */
/* Plugin																	*/
/* ------------------------------------------------------------------------- */

public APLRes AskPluginLoad2(Handle hMySelf, bool bLate, char[] szError, int iErrorMaxLen)
{
	// Cache plugin late loading status
	gl_bPluginLateLoading = bLate;
	
	h_fwdOnClientFreeze = CreateGlobalForward("ZR_OnClientFreeze", ET_Hook, Param_Cell, Param_Cell, Param_FloatByRef);
	h_fwdOnClientFreezed = CreateGlobalForward("ZR_OnClientFreezed", ET_Ignore, Param_Cell, Param_Cell, Param_Float);
	
	return APLRes_Success;
}

public bool:FilterTarget(entity, contentsMask, any:data)
{
	return (data == entity);
}

Action:Forward_OnClientFreeze(client, attacker, &Float:time)
{
	decl Action:result;
	result = Plugin_Continue;
	
	Call_StartForward(h_fwdOnClientFreeze);
	Call_PushCell(client);
	Call_PushCell(attacker);
	Call_PushFloatRef(time);
	Call_Finish(result);
	
	return result;
}

Forward_OnClientFreezed(client, attacker, Float:time)
{
	Call_StartForward(h_fwdOnClientFreezed);
	Call_PushCell(client);
	Call_PushCell(attacker);
	Call_PushFloat(time);
	Call_Finish();
}

bool Freeze(int client, int attackerUserId, float time)
{
	int attacker = GetClientOfUserId(attackerUserId);
	if (attacker == 0 || !IsClientInGame(attacker))
	{
		return false;
	}

	int clientSerial = GetClientSerial(client);
	new Action:result, Float:dummy_duration = time;
	result = Forward_OnClientFreeze(client, attacker, dummy_duration);
	
	switch (result)
	{
		case Plugin_Handled, Plugin_Stop :
		{
			return false;
		}
		case Plugin_Continue :
		{
			dummy_duration = time;
		}
	}
	
	if (GetClientFromSerial(clientSerial) != client || !IsClientInGame(client) || !IsPlayerAlive(client)
		|| GetClientOfUserId(attackerUserId) != attacker || !IsClientInGame(attacker))
	{
		return false;
	}

	Handle timer = CreateTimer(dummy_duration, Unfreeze, clientSerial, TIMER_FLAG_NO_MAPCHANGE);
	if (timer == null)
	{
		return false;
	}
	delete h_freeze_timer[client];
	h_freeze_timer[client] = timer;

	SetEntityMoveType(client, MOVETYPE_NONE);
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, NULL_VELOCITY);
	
	new Float:vec[3];
	GetClientEyePosition(client, vec);
	vec[2] -= 50.0;
	EmitAmbientSound(SOUND_FREEZE, vec, client, SNDLEVEL_RAIDSIREN);

	TE_SetupGlowSprite(vec, GlowSprite, dummy_duration, 2.0, 50);
	TE_SendToAll();
	
	Forward_OnClientFreezed(client, attacker, dummy_duration);
	
	return true;
}

static void RestoreMovement(int client)
{
	if (IsClientInGame(client) && IsPlayerAlive(client) && GetEntityMoveType(client) == MOVETYPE_NONE)
	{
		SetEntityMoveType(client, MOVETYPE_WALK);
	}
}

public void Unfreeze(Handle timer, int clientSerial)
{
	int client = GetClientFromSerial(clientSerial);
	if (client != 0 && h_freeze_timer[client] == timer)
	{
		h_freeze_timer[client] = null;
		RestoreMovement(client);
	}
}

static void ClearAllFreezes()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (h_freeze_timer[client] != null)
		{
			delete h_freeze_timer[client];
			RestoreMovement(client);
		}
	}
}

public void OnMapEnd()
{
	ClearAllFreezes();
}

public void OnPluginEnd()
{
	ClearAllFreezes();
}

public void OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	ClearAllFreezes();
}

public void OnPluginStart()
{
	// Initialize the cvars
	CvarInitialize();
	
	// Load the translations
	LoadTranslations("grenade_modes.phrases");
	
	// Prepare the grenade weapon name stringmap
	gl_hGrenadeWeaponName = new StringMap();
	gl_hGrenadeWeaponName.SetValue("weapon_hegrenade",	C_GRENADE_TYPE_HE);
	gl_hGrenadeWeaponName.SetValue("weapon_flashbang",	C_GRENADE_TYPE_FLASHBANG);
	gl_hGrenadeWeaponName.SetValue("weapon_smokegrenade", C_GRENADE_TYPE_SMOKE);
	
	// Prepare the grenade projectile name stringmap
	gl_hGrenadeProjectileName = new StringMap();
	gl_hGrenadeProjectileName.SetValue("hegrenade_projectile",	C_GRENADE_TYPE_HE);
	gl_hGrenadeProjectileName.SetValue("flashbang_projectile",	C_GRENADE_TYPE_FLASHBANG);
	gl_hGrenadeProjectileName.SetValue("smokegrenade_projectile", C_GRENADE_TYPE_SMOKE);
	
	HookEvent("smokegrenade_detonate", OnSmokeDetonate);
	HookEvent("round_start", OnRoundStart, EventHookMode_PostNoCopy);
	
	// Check for plugin late loading
	if (gl_bPluginLateLoading)
	{
		PluginStartLate();
	}
}

public OnSmokeDetonate(Handle:event, const String:name[], bool:dontBroadcast) 
{
	if (!gl_bCvarPluginEnable)
	{
		return;
	}
	
	int attackerUserId = GetEventInt(event, "userid");
	int attacker = GetClientOfUserId(attackerUserId);
	if (attacker == 0 || !IsClientInGame(attacker))
	{
		return;
	}
	
	new Float:origin[3];
	origin[0] = GetEventFloat(event, "x"); origin[1] = GetEventFloat(event, "y"); origin[2] = GetEventFloat(event, "z");
	
	new index = MaxClients+1; decl Float:xyz[3];
	while ((index = FindEntityByClassname(index, "smokegrenade_projectile")) != -1)
	{
		GetEntPropVector(index, Prop_Send, "m_vecOrigin", xyz);
		if (xyz[0] == origin[0] && xyz[1] == origin[1] && xyz[2] == origin[2])
		{
			AcceptEntityInput(index, "kill");
		}
	}
	
	origin[2] += 10.0;
	
	new Float:targetOrigin[3];
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i) || ZR_IsClientHuman(i))
		{
			continue;
		}
		
		GetClientAbsOrigin(i, targetOrigin);
		targetOrigin[2] += 2.0;
		float distance = GetVectorDistance(origin, targetOrigin);
		if (distance <= f_smoke_freeze_distance)
		{
			Handle trace = TR_TraceRayFilterEx(origin, targetOrigin, MASK_SOLID, RayType_EndPoint, FilterTarget, i);
			bool canFreeze = (TR_DidHit(trace) && TR_GetEntityIndex(trace) == i) || distance <= 100.0;
			delete trace;

			if (!canFreeze)
			{
				GetClientEyePosition(i, targetOrigin);
				targetOrigin[2] -= 2.0;

				trace = TR_TraceRayFilterEx(origin, targetOrigin, MASK_SOLID, RayType_EndPoint, FilterTarget, i);
				canFreeze = (TR_DidHit(trace) && TR_GetEntityIndex(trace) == i) || GetVectorDistance(origin, targetOrigin) <= 100.0;
				delete trace;
			}

			if (canFreeze)
			{
				Freeze(i, attackerUserId, f_smoke_freeze_duration);
			}
		}
	}
	
	TE_SetupBeamRingPoint(origin, 10.0, f_smoke_freeze_distance, g_beamsprite, g_halosprite, 1, 1, 0.2, 100.0, 1.0, FreezeColor, 0, 0);
	TE_SendToAll();
	LightCreate(SMOKE, origin);
}

// 定义冷却时间（单位：秒）
float gl_flTriggerCooldown = 0.5;
// 记录每个玩家的上次触发时间
float gl_flPlayerLastTrigger[MAXPLAYERS + 1] = {0.0};

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (IsClient(client, true)) {
		if(GetEntProp(client, Prop_Data, "m_afButtonPressed") & IN_ATTACK2) {
			if (IsClient(client, true)) {
				// 获取当前时间
				float currentTime = GetGameTime();
				// 检查是否在冷却时间内
				if (currentTime - gl_flPlayerLastTrigger[client] < gl_flTriggerCooldown) {
					return Plugin_Continue;
				}

				if (GetEntProp(client, Prop_Data, "m_afButtonPressed") & IN_ATTACK2) {
					if (IsClient(client, true)) {
						OnPlayerAltAttack(client);
						// 更新上次触发时间
						gl_flPlayerLastTrigger[client] = currentTime;
					}
				}
			}
		}
	}

	return Plugin_Continue;
}

void PluginStartLate()
{
	// Process the players already on the server
	for (int iPlayer = 1 ; iPlayer <= MaxClients ; iPlayer++)
	{
		// Check if the player is connected
		if (IsClientConnected(iPlayer))
		{
			// Call the client connected forward
			OnClientConnected(iPlayer);
				
			// Check if the player is in game
			if (IsClientInGame(iPlayer))
			{
				// Call the client put in server forward
				OnClientPutInServer(iPlayer);
			}
		}
	}
}

/* ------------------------------------------------------------------------- */
/* Map																	   */
/* ------------------------------------------------------------------------- */

public void OnMapStart()
{
	// Precache the sprites
	BeamSprite = PrecacheModel("materials/sprites/laserbeam.vmt");
	GlowSprite = PrecacheModel("sprites/blueglow2.vmt");
	g_beamsprite = PrecacheModel("materials/sprites/lgtning.vmt");
	g_halosprite = PrecacheModel("materials/sprites/halo01.vmt");
	
	gl_nSpriteBeacon = PrecacheModel("materials/sprites/physbeam.vmt");
	gl_nSpriteBeam   = PrecacheModel("materials/sprites/purplelaser1.vmt");
	gl_nSpriteHalo   = PrecacheModel("materials/sprites/purpleglow1.vmt");
	
	// Precache the sounds
	PrecacheSound("buttons/blip1.wav");
	PrecacheSound("buttons/blip2.wav");
	
	PrecacheSound(SOUND_FREEZE);
	PrecacheSound(SOUND_FREEZE_EXPLODE);
	
	for (int i = 0; i <= MaxClients; i++) {
		gl_flPlayerLastTrigger[i] = 0.0;
	}
}

static void LightCreate(int grenade, float pos[3])
{
	int entity = CreateEntityByName("light_dynamic");
	if (entity == -1)
	{
		return;
	}

	bool flash = grenade == FLASH;
	DispatchKeyValue(entity, "inner_cone", "0");
	DispatchKeyValue(entity, "cone", "80");
	DispatchKeyValue(entity, "brightness", "1");
	DispatchKeyValueFloat(entity, "spotlight_radius", 150.0);
	DispatchKeyValue(entity, "pitch", "90");
	DispatchKeyValue(entity, "style", "1");
	DispatchKeyValue(entity, "_light", flash ? "255 255 255 255" : "75 75 255 255");
	DispatchKeyValueFloat(entity, "distance", flash ? 1000.0 : f_smoke_freeze_distance);

	int reference = EntIndexToEntRef(entity);
	bool spawned = DispatchSpawn(entity);
	entity = EntRefToEntIndex(reference);
	if (entity == INVALID_ENT_REFERENCE)
	{
		return;
	}
	if (!spawned || CreateTimer(flash ? 15.0 : 0.2, DeleteLight, reference, TIMER_FLAG_NO_MAPCHANGE) == null)
	{
		RemoveEntity(entity);
		return;
	}

	EmitSoundToAll(flash ? "items/nvg_on.wav" : SOUND_FREEZE_EXPLODE, entity, SNDCHAN_WEAPON);
	TeleportEntity(entity, pos, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(entity, "TurnOn");
}

static int ParseColorString(const char[] input)
{
	char value[32];
	strcopy(value, sizeof(value), input);
	TrimString(value);

	if (value[0] == '0' && (value[1] == 'x' || value[1] == 'X'))
	{
		ReplaceString(value, sizeof(value), "0x", "", false);
		ReplaceString(value, sizeof(value), "0X", "", false);
		return StringToInt(value, 16);
	}

	return StringToInt(value, 10);
}

static int ParseColorConVar(ConVar cvar)
{
	char value[32];
	cvar.GetString(value, sizeof(value));
	return ParseColorString(value);
}

/* ------------------------------------------------------------------------- */
/* Cvar																	  */
/* ------------------------------------------------------------------------- */

void CvarInitialize()
{
	// Create the version cvar
	CreateConVar("sm_grenade_modes_version", C_PLUGIN_VERSION, "Display the plugin version", FCVAR_DONTRECORD | FCVAR_NOTIFY | FCVAR_REPLICATED | FCVAR_SPONLY);
	
	// Create the custom cvars
	gl_hCvarPluginEnable		 = CreateConVar("sm_grenade_modes_enable",				 "1",		"Enable the plugin",					 _, true, 0.0, true, 1.0);
	gl_hCvarEffectsSelfColor	 = CreateConVar("sm_grenade_modes_self_color",			 "0x00FF00", "Set the color of the self effects",	 _, true, 0.0);
	gl_hCvarEffectsTeammateColor = CreateConVar("sm_grenade_modes_teammate_color",		 "0x0000FF", "Set the color of the teammate effects", _, true, 0.0);
	gl_hCvarEffectsEnemyColor	= CreateConVar("sm_grenade_modes_enemy_color",			"0xFF0000", "Set the color of the enemy effects",	_, true, 0.0);
	gl_hCvarProximityPowerupTime = CreateConVar("sm_grenade_modes_proximity_powerup_time", "2.0",	  "Set the proximity powerup time",		_, true, 0.0);
	gl_hCvarTripwirePowerupTime  = CreateConVar("sm_grenade_modes_tripwire_powerup_time",  "2.0",	  "Set the tripwire powerup time",		 _, true, 0.0);
	
	// Cache the custom cvars values
	gl_bCvarPluginEnable		  = gl_hCvarPluginEnable.BoolValue;
	gl_iCvarEffectsSelfColor	  = ParseColorConVar(gl_hCvarEffectsSelfColor);
	gl_iCvarEffectsTeammateColor  = ParseColorConVar(gl_hCvarEffectsTeammateColor);
	gl_iCvarEffectsEnemyColor	 = ParseColorConVar(gl_hCvarEffectsEnemyColor);
	gl_flCvarProximityPowerupTime = gl_hCvarProximityPowerupTime.FloatValue;
	gl_flCvarTripwirePowerupTime  = gl_hCvarTripwirePowerupTime.FloatValue;
	
	// Hook the custom cvars change
	gl_hCvarPluginEnable.AddChangeHook(OnCvarChanged);
	gl_hCvarEffectsSelfColor.AddChangeHook(OnCvarChanged);
	gl_hCvarEffectsTeammateColor.AddChangeHook(OnCvarChanged);
	gl_hCvarEffectsEnemyColor.AddChangeHook(OnCvarChanged);
	gl_hCvarProximityPowerupTime.AddChangeHook(OnCvarChanged);
	gl_hCvarTripwirePowerupTime.AddChangeHook(OnCvarChanged);
}

public void OnCvarChanged(ConVar hCvar, const char[] szOldValue, const char[] szNewValue)
{
	// Cache the custom cvars values
	if	  (gl_hCvarPluginEnable		 == hCvar) gl_bCvarPluginEnable		  = gl_hCvarPluginEnable.BoolValue;
	else if (gl_hCvarEffectsSelfColor	 == hCvar) gl_iCvarEffectsSelfColor	  = ParseColorString(szNewValue);
	else if (gl_hCvarEffectsTeammateColor == hCvar) gl_iCvarEffectsTeammateColor  = ParseColorString(szNewValue);
	else if (gl_hCvarEffectsEnemyColor	== hCvar) gl_iCvarEffectsEnemyColor	 = ParseColorString(szNewValue);
	else if (gl_hCvarProximityPowerupTime == hCvar) gl_flCvarProximityPowerupTime = gl_hCvarProximityPowerupTime.FloatValue;
	else if (gl_hCvarTripwirePowerupTime  == hCvar) gl_flCvarTripwirePowerupTime  = gl_hCvarTripwirePowerupTime.FloatValue;
}

/* ------------------------------------------------------------------------- */
/* Client																	*/
/* ------------------------------------------------------------------------- */

public void OnClientConnected(int iClient)
{
	// Initialize the client data
	gl_bPlayerInGame	 [iClient] = false;
	gl_iPlayerGrenadeType[iClient] = C_GRENADE_TYPE_NONE;
	
	gl_iPlayerGrenadeMode[iClient][C_GRENADE_TYPE_HE]		 = GetRandomInt(C_GRENADE_MODE_NORMAL, C_GRENADE_MODE_MAXIMUM - 1);
	gl_iPlayerGrenadeMode[iClient][C_GRENADE_TYPE_FLASHBANG]  = GetRandomInt(C_GRENADE_MODE_NORMAL, C_GRENADE_MODE_MAXIMUM - 1);
	gl_iPlayerGrenadeMode[iClient][C_GRENADE_TYPE_SMOKE]	  = GetRandomInt(C_GRENADE_MODE_NORMAL, C_GRENADE_MODE_MAXIMUM - 1);
}

public void OnClientPutInServer(int iClient)
{
	// Set the client as in game
	gl_bPlayerInGame[iClient] = true;
	
	// Hook the client weapon switch function
	SDKHook(iClient, SDKHook_WeaponSwitch, OnPlayerWeaponSwitch);
}

public void OnClientDisconnect(int iClient)
{
	delete h_freeze_timer[iClient];

	// Clear the client data
	gl_bPlayerInGame	 [iClient] = false;
	gl_iPlayerGrenadeType[iClient] = C_GRENADE_TYPE_NONE;
}

/* ------------------------------------------------------------------------- */
/* Player																	*/
/* ------------------------------------------------------------------------- */

public Action OnPlayerWeaponSwitch(int iPlayer, int iWeapon)
{
	static char szClassname[32];
	static int  iGrenadeType;
	
	// Get the weapon classname
	GetEdictClassname(iWeapon, szClassname, sizeof(szClassname));
	
	// Check if the weapon is a grenade
	if (gl_hGrenadeWeaponName.GetValue(szClassname, iGrenadeType))
	{
		gl_iPlayerGrenadeType[iPlayer] = iGrenadeType;
	}
	else
	{
		gl_iPlayerGrenadeType[iPlayer] = C_GRENADE_TYPE_NONE;
	}
	
	return Plugin_Continue;
}

void OnPlayerAltAttack(int iPlayer)
{
	// Check if the plugin is enabled
	if (gl_bCvarPluginEnable)
	{
		// Check if the player is alive
		if (gl_bPlayerInGame[iPlayer] && IsPlayerAlive(iPlayer))
		{
			// Cache the grenade type
			int iGrenadeType = gl_iPlayerGrenadeType[iPlayer];
			
			// Check if the current player weapon is a grenade
			if (iGrenadeType != C_GRENADE_TYPE_NONE)
			{
				/* Cache the grenade mode */
				int iGrenadeMode = gl_iPlayerGrenadeMode[iPlayer][iGrenadeType];
				
				// Go to the next grenade mode
				iGrenadeMode = (iGrenadeMode + 1) % gl_iGrenadeModeLimits[iGrenadeType];
				
				// Set the grenade mode
				gl_iPlayerGrenadeMode[iPlayer][iGrenadeType] = iGrenadeMode;
				
				// Display the grenade mode
				PrintHintText(iPlayer, "%t : %t\n  >> %t : %t",
										"TGrenade", gl_szGrenadeTypeNameTr[iGrenadeType], 
										"TMode",	gl_szGrenadeModeNameTr[iGrenadeMode]);
			}
		}
	}
}

/* ------------------------------------------------------------------------- */
/* Entity																	*/
/* ------------------------------------------------------------------------- */

public void OnEntityCreated(int iEntity, const char[] szClassname)
{
	static int iGrenadeType;
	
	// Check if the plugin is enabled
	if (gl_bCvarPluginEnable)
	{
		// Check if the entity created is a grenade projectile
		if (gl_hGrenadeProjectileName.GetValue(szClassname, iGrenadeType))
		{
			// Hook the grenade spawn function
			SDKHook(iEntity, SDKHook_SpawnPost, OnGrenadeSpawnPost);
		}
	}
}

public Action CreateEvent_SmokeDetonate(Handle timer, int reference)
{
	int entity = EntRefToEntIndex(reference);
	if (entity == INVALID_ENT_REFERENCE)
	{
		return Plugin_Stop;
	}
	
	decl String:g_szClassname[64];
	GetEdictClassname(entity, g_szClassname, sizeof(g_szClassname));
	if (!strcmp(g_szClassname, "smokegrenade_projectile", false))
	{
		new Float:origin[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);
		int thrower = GetEntPropEnt(entity, Prop_Send, "m_hThrower");
		if (thrower < 1 || thrower > MaxClients || !IsClientInGame(thrower))
		{
			RemoveEntity(entity);
			return Plugin_Stop;
		}

		Event event = CreateEvent("smokegrenade_detonate");
		if (event == null)
		{
			RemoveEntity(entity);
			return Plugin_Stop;
		}

		SetEventInt(event, "userid", GetClientUserId(thrower));
		SetEventFloat(event, "x", origin[0]);
		SetEventFloat(event, "y", origin[1]);
		SetEventFloat(event, "z", origin[2]);
		FireEvent(event);
	}
	
	return Plugin_Stop;
}

BeamFollowCreate(entity, color[4])
{
	TE_SetupBeamFollow(entity, BeamSprite,	0, 1.0, 10.0, 10.0, 5, color);
	TE_SendToAll();	
}

public Action DoFlashLight(Handle timer, int reference)
{
	int entity = EntRefToEntIndex(reference);
	if (entity == INVALID_ENT_REFERENCE)
	{
		return Plugin_Stop;
	}
		
	decl String:g_szClassname[64];
	GetEdictClassname(entity, g_szClassname, sizeof(g_szClassname));
	if (!strcmp(g_szClassname, "flashbang_projectile", false))
	{
		decl Float:origin[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);
		origin[2] += 50.0;
		LightCreate(FLASH, origin);
		AcceptEntityInput(entity, "kill");
	}
	
	return Plugin_Stop;
}

public void DeleteLight(Handle timer, int reference)
{
	int entity = EntRefToEntIndex(reference);
	if (entity != INVALID_ENT_REFERENCE)
	{
		RemoveEntity(entity);
	}
}

/* ------------------------------------------------------------------------- */
/* Grenade																   */
/* ------------------------------------------------------------------------- */

public void OnGrenadeSpawnPost(int iGrenade)
{
	char szClassname[32];
	int iGrenadeType;
	GetEdictClassname(iGrenade, szClassname, sizeof(szClassname));
	if (!gl_hGrenadeProjectileName.GetValue(szClassname, iGrenadeType))
	{
		return;
	}

	int iOwner = GetEntPropEnt(iGrenade, Prop_Send, "m_hOwnerEntity");
	if (iOwner < 1 || iOwner > MaxClients)
	{
		return;
	}

	int iMode = gl_iPlayerGrenadeMode[iOwner][iGrenadeType];
	if (IsClientInGame(iOwner) && IsFakeClient(iOwner))
	{
		// NadeModes 11.2 (Nomexous & OT), nademodes.sma::grenade_process:
		// choose a mode for each bot throw and place tripwires on nearby walls.
		iMode = GetRandomInt(C_GRENADE_MODE_NORMAL, gl_iGrenadeModeLimits[iGrenadeType] - 1);
		if (iMode == C_GRENADE_MODE_TRIPWIRE)
		{
			// CS:CZS finishes initializing the projectile after SpawnPost.
			RequestFrame(PlaceBotTripwire, EntIndexToEntRef(iGrenade));
			return;
		}
	}
	ActivateGrenadeMode(iGrenade, iGrenadeType, iMode);
}

void GrenadeTrail(int iGrenade, int iGrenadeType)
{
	switch (iGrenadeType)
	{
		case C_GRENADE_TYPE_HE: BeamFollowCreate(iGrenade, FragColor);
		case C_GRENADE_TYPE_FLASHBANG: BeamFollowCreate(iGrenade, FlashColor);
		case C_GRENADE_TYPE_SMOKE: BeamFollowCreate(iGrenade, FreezeColor);
	}
}

void ActivateGrenadeMode(int iGrenade, int iGrenadeType, int iMode)
{
	GrenadeTrail(iGrenade, iGrenadeType);
	int iReference = EntIndexToEntRef(iGrenade);
	switch (iMode)
	{
		case C_GRENADE_MODE_NORMAL:
		{
			if (iGrenadeType == C_GRENADE_TYPE_FLASHBANG)
			{
				CreateTimer(1.3, DoFlashLight, iReference, TIMER_FLAG_NO_MAPCHANGE);
			}
			else if (iGrenadeType == C_GRENADE_TYPE_SMOKE)
			{
				CreateTimer(1.3, CreateEvent_SmokeDetonate, iReference, TIMER_FLAG_NO_MAPCHANGE);
			}
		}
		case C_GRENADE_MODE_IMPACT:
		{
			CreateTimer(0.1, OnGrenadeTimerSetInfinite, iReference, TIMER_FLAG_NO_MAPCHANGE);
			SDKHook(iGrenade, SDKHook_TouchPost, OnGrenadeImpactTouchPost);
		}
		case C_GRENADE_MODE_PROXIMITY:
		{
			CreateTimer(0.1, OnGrenadeTimerSetInfinite, iReference, TIMER_FLAG_NO_MAPCHANGE);

			DataPack hPack;
			CreateDataTimer(0.1, OnGrenadeProximityTimerThink, hPack, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
			hPack.WriteCell(iReference);
			hPack.WriteCell(C_PROXIMITY_STATE_WAIT_IDLE);
			hPack.WriteCell(0);
		}
		case C_GRENADE_MODE_TRIPWIRE:
		{
			CreateTimer(0.1, OnGrenadeTimerSetInfinite, iReference, TIMER_FLAG_NO_MAPCHANGE);
			SDKHook(iGrenade, SDKHook_TouchPost, OnGrenadeTripwireTouchPost);
		}
	}
}

/* ------------------------------------------------------------------------- */
/* Grenade :: Common														 */
/* ------------------------------------------------------------------------- */

static void GrenadeSetBreakable(int iGrenade)
{
	// Set the grenade as breakable
	SetEntProp(iGrenade, Prop_Data, "m_takedamage", 2);
	SetEntProp(iGrenade, Prop_Data, "m_iHealth", 1);
}

static void GrenadeDetonate(int iGrenade)
{
	char szClassname[32];
	
	// Get the grenade classname
	GetEdictClassname(iGrenade, szClassname, sizeof(szClassname));
	
	// Check if the grenade is a smoke
	if (StrEqual(szClassname, "smokegrenade_projectile"))
	{
		CreateTimer(0.1, CreateEvent_SmokeDetonate, EntIndexToEntRef(iGrenade), TIMER_FLAG_NO_MAPCHANGE);
	}
	else if (StrEqual(szClassname, "flashbang_projectile")) {
		CreateTimer(0.1, DoFlashLight, EntIndexToEntRef(iGrenade), TIMER_FLAG_NO_MAPCHANGE);
	}
	else
	{
		// Set the grenade as breakable
		GrenadeSetBreakable(iGrenade);
		
		// Inflict damage
		SDKHooks_TakeDamage(iGrenade, iGrenade, iGrenade, 10.0);
	}
}

public Action OnGrenadeTimerSetInfinite(Handle hTimer, int iReference)
{
	// Get the grenade index
	int iGrenade = EntRefToEntIndex(iReference);
	
	// Check if the grenade is still valid
	if (iGrenade != INVALID_ENT_REFERENCE)
	{
		// Set the grenade as infinite
		SetEntProp(iGrenade, Prop_Data, "m_nNextThinkTick", -1);
	}
	
	return Plugin_Continue;
}

public Action OnGrenadeTimerDetonate(Handle hTimer, int iReference)
{
	// Get the grenade index
	int iGrenade = EntRefToEntIndex(iReference);
	
	// Check if the grenade is still valid
	if (iGrenade != INVALID_ENT_REFERENCE)
	{
		// Detonate the grenade
		GrenadeDetonate(iGrenade);
	}
	
	return Plugin_Continue;
}

/* ------------------------------------------------------------------------- */
/* Grenade :: Impact														 */
/* ------------------------------------------------------------------------- */

public void OnGrenadeImpactTouchPost(int iGrenade, int iOther)
{
	// Check if the grenade touches the world
	if (!iOther)
	{
		// Detonate the grenade
		GrenadeDetonate(iGrenade);
	}
	else
	{
		// Check if the grenade touches a solid entity
		if (GetEntProp(iOther, Prop_Send, "m_nSolidType", 1) && !(GetEntProp(iOther, Prop_Send, "m_usSolidFlags", 2) & 0x0004))
		{
			// Get the grenade owner
			int iOwner = GetEntPropEnt(iGrenade, Prop_Send, "m_hOwnerEntity");
			
			// Check if it's not the owner
			if (iOwner != iOther)
			{
				// Detonate the grenade
				GrenadeDetonate(iGrenade);
			}
		}
	}
}

/* ------------------------------------------------------------------------- */
/* Grenade :: Proximity													  */
/* ------------------------------------------------------------------------- */

stock Action GrenadeProximityThinkWaitIdle(int  iGrenade, 
										   int  iGrenadeReference, 
										   int &rGrenadeState, 
										   int &rGrenadeCounter)
{
	static float vGrenadeVelocity[3];
	
	// Get the grenade velocity
	GetEntPropVector(iGrenade, Prop_Data, "m_vecVelocity", vGrenadeVelocity);
	
	// Check if the grenade is stationary
	if (GetVectorLength(vGrenadeVelocity) <= 0.0)
	{
		float vGrenadeOrigin[3];
		
		// Get the grenade origin
		GetEntPropVector(iGrenade, Prop_Send, "m_vecOrigin", vGrenadeOrigin);
		
		// Set the grenade as breakable
		GrenadeSetBreakable(iGrenade);
		
		
		// Set the grenade next state
		rGrenadeState   = C_PROXIMITY_STATE_POWERUP;
		rGrenadeCounter = RoundFloat(gl_flCvarProximityPowerupTime * 10.0);
	}
	
	return Plugin_Continue;
}

stock Action GrenadeProximityThinkPowerUp(int  iGrenade, 
										  int  iGrenadeReference, 
										  int &rGrenadeState, 
										  int &rGrenadeCounter)
{
	// Check if the grenade is ready
	if (rGrenadeCounter <= 0)
	{
		// Play a sound
		EmitSoundToAll("buttons/blip2.wav", iGrenade, _, SNDLEVEL_CONVO);
		
		// Set the grenade next state
		rGrenadeState   = C_PROXIMITY_STATE_DETECT;
		rGrenadeCounter = 0;
	}
	else if ((rGrenadeCounter % 2) == 0)
	{
		// Determine the pitch
		int iPitch = 200 - rGrenadeCounter * 4;
		
		if (iPitch <= 100)
		{
			iPitch = 100;
		}
		
		// Play a sound
		EmitSoundToAll("buttons/blip1.wav", iGrenade, _, SNDLEVEL_CONVO, _, _, iPitch);
	}
	
	return Plugin_Continue;
}

stock Action GrenadeProximityThinkDetect(int  iGrenade, 
										 int  iGrenadeReference, 
										 int &rGrenadeState, 
										 int &rGrenadeCounter)
{
	static int iOwner;
	
	// Get the grenade owner
	iOwner = GetEntPropEnt(iGrenade, Prop_Send, "m_hOwnerEntity");
	
	// Check if the owner is still connected
	if (1 <= iOwner <= MaxClients)
	{
		static int   iOwnerTeam;
		static float vGrenadeOrigin[3];
		static float vPlayerOrigin[3];
		static int   iPlayer;
		static bool  bDetonate;
		
		// Get the owner team
		iOwnerTeam = GetClientTeam(iOwner);
		
		// Get the grenade origin
		GetEntPropVector(iGrenade, Prop_Send, "m_vecOrigin", vGrenadeOrigin);
		
		// Initialize the context
		iPlayer   = -1;
		bDetonate = false;
		
		// Check if there's a valid player near the grenade
		while (((iPlayer = FindEntityByClassname(iPlayer, "player")) != -1) && !bDetonate)
		{
			if ((1 <= iPlayer <= MaxClients) && (IsPlayerAlive(iPlayer)) && (GetClientTeam(iPlayer) != iOwnerTeam))
			{
				GetEntPropVector(iPlayer, Prop_Send, "m_vecOrigin", vPlayerOrigin);
				
				if (GetVectorDistance(vGrenadeOrigin, vPlayerOrigin) <= 100.0)
				{
					bDetonate = true;
				}
			}
		}
		
		// Check if the grenade must detonate
		if (bDetonate)
		{
			CreateTimer(0.1, OnGrenadeTimerDetonate, iGrenadeReference, TIMER_FLAG_NO_MAPCHANGE);
			return Plugin_Stop;
		}
		
		// Warn the players
		if (rGrenadeCounter <= 0)
		{
			static int iPlayers[MAXPLAYERS + 1];
			static int iNbPlayers;
			static int iNumPlayer;
			static int iColor;
			
			// Just above the ground..
			vGrenadeOrigin[2] += 2;
			
			// Get all the players in range
			iNbPlayers = GetClientsInRange(vGrenadeOrigin, RangeType_Audibility, iPlayers, MaxClients);
			
			// Send the beacon effect to all the close players
			for (iNumPlayer = 0 ; iNumPlayer < iNbPlayers ; iNumPlayer++)
			{
				iPlayer = iPlayers[iNumPlayer];
				
				// Determine the color of the beacon
				if (iPlayer == iOwner)
				{
					iColor = gl_iCvarEffectsSelfColor;
				}
				else if (GetClientTeam(iPlayer) == iOwnerTeam)
				{
					iColor = gl_iCvarEffectsTeammateColor;
				}
				else
				{
					iColor = gl_iCvarEffectsEnemyColor;
				}
				
				// Prepare the beacon effect
				TE_Start	  ("BeamRingPoint");
				TE_WriteVector("m_vecCenter",	 vGrenadeOrigin);
				TE_WriteFloat ("m_flStartRadius", 0.0);
				TE_WriteFloat ("m_flEndRadius",   200.0);
				TE_WriteNum   ("m_nModelIndex",   gl_nSpriteBeacon);
				TE_WriteNum   ("m_nHaloIndex",	gl_nSpriteHalo);
				TE_WriteNum   ("m_nStartFrame",   0);
				TE_WriteNum   ("m_nFrameRate",	0);
				TE_WriteFloat ("m_fLife",		 0.5);
				TE_WriteFloat ("m_fWidth",		4.0);
				TE_WriteFloat ("m_fEndWidth",	 4.0);
				TE_WriteNum   ("r",			   (iColor >> 16) & 0xFF);
				TE_WriteNum   ("g",			   (iColor >>  8) & 0xFF);
				TE_WriteNum   ("b",			   (iColor	  ) & 0xFF);
				TE_WriteNum   ("a",			   255);
				TE_WriteNum   ("m_nFadeLength",   0);
				
				// Send the beacon effect to the player
				TE_SendToClient(iPlayer);
			}
			
			rGrenadeCounter = 10; // 1.0 sec
		}
	}
	else
	{
		// Detonate the grenade
		CreateTimer(GetRandomFloat(0.5, 2.0), OnGrenadeTimerDetonate, iGrenadeReference, TIMER_FLAG_NO_MAPCHANGE);
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

bool IsClient(int Client, bool Alive)
{
	return Client <= MaxClients && IsClientConnected(Client) && IsClientInGame(Client) && (Alive && IsPlayerAlive(Client));
}

public Action OnGrenadeProximityTimerThink(Handle hTimer, DataPack hPack)
{
	static int	iGrenadeReference;
	static int	iGrenade;
	static int	iGrenadeState;
	static int	iGrenadeCounter;
	static Action iTimerAction;
	
	// Read the datapack
	ResetPack(hPack);
	iGrenadeReference = hPack.ReadCell();
	iGrenade		  = EntRefToEntIndex(iGrenadeReference);
	iGrenadeState	 = hPack.ReadCell();
	iGrenadeCounter   = hPack.ReadCell();
	
	// By default, exit the timer
	iTimerAction = Plugin_Stop;
	
	// Check if the grenade is still valid
	if (iGrenade != INVALID_ENT_REFERENCE)
	{
		// Decrement the grenade counter
		if (iGrenadeCounter > 0)
		{
			iGrenadeCounter--;
		}
		
		// Execute the grenade think function
		switch (iGrenadeState)
		{
			case C_PROXIMITY_STATE_WAIT_IDLE:
			{
				iTimerAction = GrenadeProximityThinkWaitIdle(iGrenade, iGrenadeReference, iGrenadeState, iGrenadeCounter);
			}
			case C_PROXIMITY_STATE_POWERUP:
			{
				iTimerAction = GrenadeProximityThinkPowerUp(iGrenade, iGrenadeReference, iGrenadeState, iGrenadeCounter);
			}
			case C_PROXIMITY_STATE_DETECT:
			{
				iTimerAction = GrenadeProximityThinkDetect(iGrenade, iGrenadeReference, iGrenadeState, iGrenadeCounter);
			}
		}
		
		// Write the datapack
		if (iTimerAction == Plugin_Continue)
		{
			ResetPack(hPack, true);
			hPack.WriteCell(iGrenadeReference);
			hPack.WriteCell(iGrenadeState);
			hPack.WriteCell(iGrenadeCounter);
		}
	}
	
	return iTimerAction;
}

/* ------------------------------------------------------------------------- */
/* Grenade :: Tripwire													   */
/* ------------------------------------------------------------------------- */

public bool OnGrenadeTripwireTraceFilterNoPlayer(int iEntity, int iContentsMask, any iData)
{
	return (iEntity == view_as<int>(iData) || 1 <= iEntity <= MaxClients) ? false : true;
}

bool ArmTripwire(int iGrenade, const float vNormal[3])
{
	DataPack hPack;
	if (CreateDataTimer(0.1, OnGrenadeTripwireTimerThink, hPack, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE) == null)
	{
		return false;
	}
	hPack.WriteCell(EntIndexToEntRef(iGrenade));
	hPack.WriteFloat(vNormal[0]);
	hPack.WriteFloat(vNormal[1]);
	hPack.WriteFloat(vNormal[2]);
	hPack.WriteCell(C_TRIPWIRE_STATE_POWERUP);
	hPack.WriteCell(RoundFloat(gl_flCvarTripwirePowerupTime * 10.0));

	SetEntityMoveType(iGrenade, MOVETYPE_NONE);
	GrenadeSetBreakable(iGrenade);
	return true;
}

bool FindBotTripwireMount(int iOwner, int iGrenade, float vMount[3], float vMountNormal[3])
{
	static const float directions[][] = {
		{ 1.0, 0.0 }, { -1.0, 0.0 }, { 0.0, 1.0 }, { 0.0, -1.0 },
		{ 0.7071068, 0.7071068 }, { 0.7071068, -0.7071068 },
		{ -0.7071068, 0.7071068 }, { -0.7071068, -0.7071068 }
	};
	static const float vMins[3] = { -2.0, -2.0, -2.0 };
	static const float vMaxs[3] = {  2.0,  2.0,  2.0 };
	float vOrigin[3], vFeet[3];
	GetClientEyePosition(iOwner, vOrigin);
	GetClientAbsOrigin(iOwner, vFeet);
	vOrigin[2] -= 8.0;
	if (vOrigin[2] > vFeet[2] + 55.0)
	{
		vOrigin[2] = vFeet[2] + 55.0;
	}

	float bestFraction = 1.0;
	for (int i = 0; i < sizeof(directions); i++)
	{
		float vEnd[3];
		vEnd[0] = vOrigin[0] + directions[i][0] * C_BOT_TRIPWIRE_WALL_RANGE;
		vEnd[1] = vOrigin[1] + directions[i][1] * C_BOT_TRIPWIRE_WALL_RANGE;
		vEnd[2] = vOrigin[2];
		Handle hTrace = TR_TraceRayFilterEx(vOrigin, vEnd, MASK_SOLID, RayType_EndPoint,
			OnGrenadeTripwireTraceFilterNoPlayer, iGrenade);
		float fraction = TR_GetFraction(hTrace);
		int iWall = TR_GetEntityIndex(hTrace);
		if (fraction >= bestFraction || TR_StartSolid(hTrace) || TR_AllSolid(hTrace)
			|| (TR_GetSurfaceFlags(hTrace) & (SURF_SKY | SURF_SKY2D)) != 0
			|| (iWall != 0 && (iWall <= MaxClients || !IsValidEntity(iWall)
				|| GetEntityMoveType(iWall) != MOVETYPE_NONE)))
		{
			delete hTrace;
			continue;
		}

		float vNormal[3];
		TR_GetPlaneNormal(hTrace, vNormal);
		TR_GetEndPosition(vEnd, hTrace);
		delete hTrace;
		if (FloatAbs(vNormal[2]) > C_BOT_TRIPWIRE_WALL_NORMAL_Z || GetVectorLength(vNormal, true) < 0.5)
		{
			continue;
		}

		for (int axis = 0; axis < 3; axis++)
		{
			vEnd[axis] += vNormal[axis] * 4.0;
		}
		hTrace = TR_TraceHullFilterEx(vEnd, vEnd, vMins, vMaxs, MASK_SOLID,
			OnGrenadeTripwireTraceFilterNoPlayer, iGrenade);
		bool clear = !TR_StartSolid(hTrace) && !TR_AllSolid(hTrace);
		delete hTrace;
		if (clear)
		{
			bestFraction = fraction;
			vMount = vEnd;
			vMountNormal = vNormal;
		}
	}
	return bestFraction < 1.0;
}

public void PlaceBotTripwire(int iReference)
{
	int iGrenade = EntRefToEntIndex(iReference);
	if (iGrenade == INVALID_ENT_REFERENCE || !gl_bCvarPluginEnable)
	{
		return;
	}

	char szClassname[32];
	int iGrenadeType;
	GetEdictClassname(iGrenade, szClassname, sizeof(szClassname));
	if (!gl_hGrenadeProjectileName.GetValue(szClassname, iGrenadeType))
	{
		return;
	}

	int iOwner = GetEntPropEnt(iGrenade, Prop_Send, "m_hThrower");
	float vMount[3], vNormal[3];
	if (iOwner >= 1 && iOwner <= MaxClients && IsClientInGame(iOwner) && IsFakeClient(iOwner)
		&& IsPlayerAlive(iOwner) && FindBotTripwireMount(iOwner, iGrenade, vMount, vNormal)
		&& ArmTripwire(iGrenade, vNormal))
	{
		float vStop[3];
		TeleportEntity(iGrenade, vMount, NULL_VECTOR, vStop);
		GrenadeTrail(iGrenade, iGrenadeType);
		CreateTimer(0.1, OnGrenadeTimerSetInfinite, iReference, TIMER_FLAG_NO_MAPCHANGE);
		return;
	}

	ActivateGrenadeMode(iGrenade, iGrenadeType, GetRandomInt(C_GRENADE_MODE_NORMAL, C_GRENADE_MODE_TRIPWIRE - 1));
}

stock void GrenadeTripwireTrackWall(int iGrenade)
{
	float vTracker[6][3] = {{ 0.0,  0.0,  5.0},
							{ 0.0,  5.0,  0.0},
							{ 5.0,  0.0,  0.0},
							{ 0.0,  0.0, -5.0},
							{ 0.0, -5.0,  0.0},
							{-5.0,  0.0,  0.0}};
	
	Handle hTrace;
	float  vGrenadeOrigin[3];
	float  vEndPoint[3];
	float  vNormal[3];
	
	int	iIndex;
	float  flFraction;
	float  flBestFraction;
	
	// Get the grenade origin
	GetEntPropVector(iGrenade, Prop_Send, "m_vecOrigin", vGrenadeOrigin);
	
	// Search the best fraction
	flBestFraction = 1.0;
	
	for (iIndex = 0 ; iIndex < 6 ; iIndex++)
	{
		vEndPoint[0] = vTracker[iIndex][0] + vGrenadeOrigin[0];
		vEndPoint[1] = vTracker[iIndex][1] + vGrenadeOrigin[1];
		vEndPoint[2] = vTracker[iIndex][2] + vGrenadeOrigin[2];
		
		hTrace	 = TR_TraceRayFilterEx(vGrenadeOrigin, vEndPoint, MASK_SOLID, RayType_EndPoint, OnGrenadeTripwireTraceFilterNoPlayer, iGrenade);
		flFraction = TR_GetFraction(hTrace);
		
		if (flBestFraction > flFraction)
		{
			flBestFraction = flFraction;
			TR_GetPlaneNormal(hTrace, vNormal);
		}
		
		CloseHandle(hTrace);
	}
	
	// Keep the touch hook when there is no surface to mount the grenade on.
	if (flBestFraction < 1.0 && ArmTripwire(iGrenade, vNormal))
	{
		SDKUnhook(iGrenade, SDKHook_TouchPost, OnGrenadeTripwireTouchPost);
	}
}

public void OnGrenadeTripwireTouchPost(int iGrenade, int iOther)
{
	// Check if the grenade touches the world
	if (!iOther)
	{
		// Search a wall near the grenade
		GrenadeTripwireTrackWall(iGrenade);
	}
	// Check if the grenade touches a solid entity (But not a player)
	else if ((iOther > MaxClients) && (GetEntProp(iOther, Prop_Send, "m_nSolidType", 1) && !(GetEntProp(iOther, Prop_Send, "m_usSolidFlags", 2) & 0x0004)))
	{
		// Search a wall near the grenade
		GrenadeTripwireTrackWall(iGrenade);
	}
}

stock Action GrenadeTripwireThinkPowerUp(int	iGrenade, 
										 int	iGrenadeReference, 
										 float  vGrenadeNormal[3],
										 int   &rGrenadeState, 
										 int   &rGrenadeCounter)
{
	// Check if the grenade is ready
	if (rGrenadeCounter <= 0)
	{
		// Play a sound
		EmitSoundToAll("buttons/blip2.wav", iGrenade, _, SNDLEVEL_CONVO);
		
		// Set the grenade next state
		rGrenadeState   = C_TRIPWIRE_STATE_DETECT;
		rGrenadeCounter = 0;
	}
	else if ((rGrenadeCounter % 2) == 0)
	{
		// Determine the pitch
		int iPitch = 200 - rGrenadeCounter * 4;
		
		if (iPitch <= 100)
		{
			iPitch = 100;
		}
		
		// Play a sound
		EmitSoundToAll("buttons/blip1.wav", iGrenade, _, SNDLEVEL_CONVO, _, _, iPitch);
	}
	
	return Plugin_Continue;
}

public bool OnGrenadeTripwireTraceFilter(int iEntity, int iContentsMask, any iData)
{
	return (iEntity == view_as<int>(iData)) ? false : true;
}

stock Action GrenadeTripwireThinkDetect(int	iGrenade, 
										int	iGrenadeReference, 
										float  vGrenadeNormal[3],
										int   &rGrenadeState, 
										int   &rGrenadeCounter)
{
	static int iOwner;
	
	// Get the grenade owner
	iOwner = GetEntPropEnt(iGrenade, Prop_Send, "m_hOwnerEntity");
	
	// Check if the owner is still connected
	if (1 <= iOwner <= MaxClients)
	{
		static int	iOwnerTeam;
		static float  vGrenadeOrigin[3];
		static float  vGrenadeEndPoint[3];
		static Handle hTrace;
		static int	iEntityHit;
		static bool   bDetonate;
		
		// Get the owner team
		iOwnerTeam = GetClientTeam(iOwner);
		
		// Get the grenade origin
		GetEntPropVector(iGrenade, Prop_Send, "m_vecOrigin", vGrenadeOrigin);
		
		// Initialize the context
		bDetonate = false;
		
		// Check if there's a valid player in the grenade tripwire
		vGrenadeEndPoint[0] = vGrenadeNormal[0] * 8192.0 + vGrenadeOrigin[0];
		vGrenadeEndPoint[1] = vGrenadeNormal[1] * 8192.0 + vGrenadeOrigin[1];
		vGrenadeEndPoint[2] = vGrenadeNormal[2] * 8192.0 + vGrenadeOrigin[2];
		
		hTrace = TR_TraceRayFilterEx(vGrenadeOrigin, vGrenadeEndPoint, MASK_SOLID, RayType_EndPoint, OnGrenadeTripwireTraceFilter, iGrenade);
		
		if (TR_GetFraction(hTrace) < 1.0)
		{
			TR_GetEndPosition(vGrenadeEndPoint, hTrace);
			iEntityHit = TR_GetEntityIndex(hTrace);
			
			if ((1 <= iEntityHit <= MaxClients) && (IsPlayerAlive(iEntityHit)) && (GetClientTeam(iEntityHit) != iOwnerTeam))
			{
				bDetonate = true;
			}
		}
		
		CloseHandle(hTrace);
		
		// Check if the grenade must detonate
		if (bDetonate)
		{
			CreateTimer(0.1, OnGrenadeTimerDetonate, iGrenadeReference, TIMER_FLAG_NO_MAPCHANGE);
			return Plugin_Stop;
		}
		
		// Warn the players
		if (rGrenadeCounter <= 0)
		{
			static int iPlayers[MAXPLAYERS + 1];
			static int iNbPlayers;
			static int iNumPlayer;
			static int iPlayer;
			static int iColor;
			
			// Get all the players in range
			iNbPlayers = GetClientsInRange(vGrenadeOrigin, RangeType_Audibility, iPlayers, MaxClients);
			
			// Send the beam effect to all the close players
			for (iNumPlayer = 0 ; iNumPlayer < iNbPlayers ; iNumPlayer++)
			{
				iPlayer = iPlayers[iNumPlayer];
				
				// Determine the color of the beam
				if (iPlayer == iOwner)
				{
					iColor = gl_iCvarEffectsSelfColor;
				}
				else if (GetClientTeam(iPlayer) == iOwnerTeam)
				{
					iColor = gl_iCvarEffectsTeammateColor;
				}
				else
				{
					iColor = gl_iCvarEffectsEnemyColor;
				}
				
				// Create the beam effect
				TE_Start	  ("BeamEntPoint");
				TE_WriteNum   ("m_nStartEntity", iGrenade);
				TE_WriteVector("m_vecEndPoint",  vGrenadeEndPoint);
				TE_WriteNum   ("m_nModelIndex",  gl_nSpriteBeam);
				TE_WriteNum   ("m_nHaloIndex",   gl_nSpriteHalo);
				TE_WriteNum   ("m_nStartFrame",  0);
				TE_WriteNum   ("m_nFrameRate",   0);
				TE_WriteFloat ("m_fLife",		0.1);
				TE_WriteFloat ("m_fWidth",	   8.0);
				TE_WriteFloat ("m_fEndWidth",	8.0);
				TE_WriteNum   ("r",			  (iColor >> 16) & 0xFF);
				TE_WriteNum   ("g",			  (iColor >>  8) & 0xFF);
				TE_WriteNum   ("b",			  (iColor	  ) & 0xFF);
				TE_WriteNum   ("a",			  255);
				TE_WriteNum   ("m_nFlags",	   FBEAM_STARTENTITY);
				TE_WriteNum   ("m_nFadeLength",  0);
				
				// Send the beam effect to the player
				TE_SendToClient(iPlayer);
			}
			
			rGrenadeCounter = 1; // 0.1 sec
		}
	}
	else
	{
		// Detonate the grenade
		CreateTimer(GetRandomFloat(0.5, 2.0), OnGrenadeTimerDetonate, iGrenadeReference, TIMER_FLAG_NO_MAPCHANGE);
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

public Action OnGrenadeTripwireTimerThink(Handle hTimer, DataPack hPack)
{
	static int	iGrenadeReference;
	static int	iGrenade;
	static float  vGrenadeNormal[3];
	static int	iGrenadeState;
	static int	iGrenadeCounter;
	static Action iTimerAction;
	
	// Read the datapack
	ResetPack(hPack);
	iGrenadeReference = hPack.ReadCell();
	iGrenade		  = EntRefToEntIndex(iGrenadeReference);
	vGrenadeNormal[0] = hPack.ReadFloat();
	vGrenadeNormal[1] = hPack.ReadFloat();
	vGrenadeNormal[2] = hPack.ReadFloat();
	iGrenadeState	 = hPack.ReadCell();
	iGrenadeCounter   = hPack.ReadCell();

	// By default, exit the timer
	iTimerAction = Plugin_Stop;
	
	// Check if the grenade is still valid
	if (iGrenade != INVALID_ENT_REFERENCE)
	{
		// Decrement the grenade counter
		if (iGrenadeCounter > 0)
		{
			iGrenadeCounter--;
		}
		
		// Execute the grenade think function
		switch (iGrenadeState)
		{
			case C_TRIPWIRE_STATE_POWERUP:
			{
				iTimerAction = GrenadeTripwireThinkPowerUp(iGrenade, iGrenadeReference, vGrenadeNormal, iGrenadeState, iGrenadeCounter);
			}
			case C_TRIPWIRE_STATE_DETECT:
			{
				iTimerAction = GrenadeTripwireThinkDetect(iGrenade, iGrenadeReference, vGrenadeNormal, iGrenadeState, iGrenadeCounter);
			}
		}
		
		// Write the datapack
		if (iTimerAction == Plugin_Continue)
		{
			ResetPack(hPack, true);
			hPack.WriteCell(EntIndexToEntRef(iGrenade));
			hPack.WriteFloat(vGrenadeNormal[0]);
			hPack.WriteFloat(vGrenadeNormal[1]);
			hPack.WriteFloat(vGrenadeNormal[2]);
			hPack.WriteCell(iGrenadeState);
			hPack.WriteCell(iGrenadeCounter);
		}
	}
	
	return iTimerAction;
}

/* ========================================================================= */
