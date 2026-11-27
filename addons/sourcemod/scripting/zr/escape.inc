/*
 * Zombie:Reloaded - Zombie Escape rules (GPL-3.0-or-later).
 */

enum EscapeTimeoutOutcome
{
    EscapeTimeout_Humans = 0,
    EscapeTimeout_Draw,
    EscapeTimeout_Zombies
}

new Handle:g_hEscapeMode = INVALID_HANDLE;
new Handle:g_hEscapeFinaleTrigger = INVALID_HANDLE;
new Handle:g_hEscapeTimeout = INVALID_HANDLE;
new Handle:g_hEscapeLatchedTrigger = INVALID_HANDLE;
new bool:g_bEscapeMapPrefix;
new bool:g_bEscapeFinale;
new bool:g_bEscapeRoundEnded;
new g_iEscapeTriggerRef = INVALID_ENT_REFERENCE;

EscapeInit()
{
    g_hEscapeMode = CreateConVar("zr_ze_mode", "-1", "Zombie Escape map profile: -1 = auto (ze_ prefix), 0 = off, 1 = on.", _, true, -1.0, true, 1.0);
    g_hEscapeFinaleTrigger = CreateConVar("zr_ze_finale_trigger", "", "Targetname of the map's trigger_hurt that locks ZR respawns when enabled.");
    g_hEscapeTimeout = CreateConVar("zr_ze_timeout_result", "0", "Zombie Escape timeout outcome: 0 = humans, 1 = draw, 2 = zombies.", _, true, 0.0, true, 2.0);
    g_hEscapeLatchedTrigger = CreateConVar("zr_ze_latched_trigger_ref", "-1", "Active ZE finale entity reference.", FCVAR_HIDDEN | FCVAR_DONTRECORD);
    HookConVarChange(g_hEscapeFinaleTrigger, EscapeOnTriggerChanged);
    RegServerCmd("zr_ze_status", EscapeStatusCommand, "Show the active ZR profile, finale trigger and respawn lock.");
}

EscapeOnMapStart(bool:lateLoad)
{
    decl String:map[PLATFORM_MAX_PATH];
    GetCurrentMap(map, sizeof(map));
    new basename = FindCharInString(map, '/', true) + 1;
    g_bEscapeMapPrefix = StrContains(map[basename], "ze_", false) == 0;

    if (lateLoad)
    {
        EscapeBindFinaleTrigger();

        // SourceMod keeps cvars across plugin reloads. The engine recreates trigger_hurt entities each round.
        g_bEscapeFinale = EntRefToEntIndex(GetConVarInt(g_hEscapeLatchedTrigger)) != INVALID_ENT_REFERENCE;
        return;
    }

    ResetConVar(g_hEscapeMode);
    ResetConVar(g_hEscapeFinaleTrigger);
    ResetConVar(g_hEscapeTimeout);
    EscapeOnRoundStart();
}

EscapeOnRoundStart()
{
    g_bEscapeFinale = false;
    g_bEscapeRoundEnded = false;
    ResetConVar(g_hEscapeLatchedTrigger);
    EscapeBindFinaleTrigger();
}

EscapeOnRoundEnd()
{
    g_bEscapeRoundEnded = true;
}

bool:EscapeModeEnabled()
{
    if (g_hEscapeMode == INVALID_HANDLE)
    {
        return false;
    }

    new mode = GetConVarInt(g_hEscapeMode);
    return mode < 0 ? g_bEscapeMapPrefix : mode > 0;
}

public EscapeOnTriggerChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
    EscapeBindFinaleTrigger();
}

EscapeBindFinaleTrigger()
{
    g_iEscapeTriggerRef = INVALID_ENT_REFERENCE;

    decl String:target[PLATFORM_MAX_PATH];
    GetConVarString(g_hEscapeFinaleTrigger, target, sizeof(target));
    if (!target[0])
    {
        return;
    }

    new ent = -1;
    decl String:name[PLATFORM_MAX_PATH];
    while ((ent = FindEntityByClassname(ent, "trigger_hurt")) != -1)
    {
        GetEntPropString(ent, Prop_Data, "m_iName", name, sizeof(name));
        if (StrEqual(name, target, false) && HasEntProp(ent, Prop_Data, "m_bDisabled"))
        {
            g_iEscapeTriggerRef = EntIndexToEntRef(ent);
            return;
        }
    }
}

bool:EscapeRespawnsBlocked()
{
    if (!EscapeModeEnabled())
    {
        return false;
    }
    if (g_bEscapeFinale || g_bEscapeRoundEnded)
    {
        return true;
    }

    new ent = EntRefToEntIndex(g_iEscapeTriggerRef);
    if (ent == INVALID_ENT_REFERENCE || GetEntProp(ent, Prop_Data, "m_bDisabled"))
    {
        return false;
    }

    // Once the map starts its cleanup, keep respawns locked through round end.
    g_bEscapeFinale = true;
    SetConVarInt(g_hEscapeLatchedTrigger, g_iEscapeTriggerRef);
    RespawnCancelAllTimers();
    return true;
}

EscapeOnGameFrame()
{
    if (g_iEscapeTriggerRef != INVALID_ENT_REFERENCE && !g_bEscapeFinale && !g_bEscapeRoundEnded)
    {
        EscapeRespawnsBlocked();
    }
}

EscapeTimeoutOutcome:EscapeGetTimeoutOutcome()
{
    if (!EscapeModeEnabled())
    {
        return EscapeTimeout_Humans;
    }

    return EscapeTimeoutOutcome:GetConVarInt(g_hEscapeTimeout);
}

public Action:EscapeStatusCommand(args)
{
    decl String:target[PLATFORM_MAX_PATH];
    GetConVarString(g_hEscapeFinaleTrigger, target, sizeof(target));
    new bool:blocked = EscapeRespawnsBlocked();
    PrintToServer("[ZR] profile=%s finale_trigger=%s bound=%d finale=%d respawn_locked=%d timeout_result=%d",
        EscapeModeEnabled() ? "ze" : "zm", target[0] ? target : "-",
        EntRefToEntIndex(g_iEscapeTriggerRef) != INVALID_ENT_REFERENCE,
        g_bEscapeFinale, blocked, EscapeGetTimeoutOutcome());
    return Plugin_Handled;
}

public APIIsEscapeMode(Handle:plugin, numParams)
{
    return EscapeModeEnabled();
}
