#include <sourcemod>

#define PLUGIN_VERSION "1.2"

bool g_bLateLoad;
StringMap g_smArmsModels;
Handle g_hApplyTimer[MAXPLAYERS + 1];

void CancelApplyTimer(int client)
{
    if (client < 1 || client > MaxClients)
        return;

    Handle timer = g_hApplyTimer[client];
    g_hApplyTimer[client] = null;

    if (timer != null && IsValidHandle(timer))
    {
        KillTimer(timer);
    }
}

void ClearApplyTimerSlotByHandle(Handle timer)
{
    if (timer == null)
        return;

    for (int i = 1; i <= MaxClients; i++)
    {
        if (g_hApplyTimer[i] == timer)
        {
            g_hApplyTimer[i] = null;
            return;
        }
    }
}

public Plugin myinfo = 
{
    name = "Change ArmModel For New Player",
    author = "[CNSR] FJH_03",
    description = "Assigns custom arms models based on new player roles",
    version = PLUGIN_VERSION,
    url = "QQ: 1297573948"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    g_bLateLoad = late;
    return APLRes_Success;
}

public void OnPluginStart()
{
	g_smArmsModels = new StringMap();
    for (int i = 1; i <= MaxClients; i++)
    {
        g_hApplyTimer[i] = null;
    }
	
	HookEvent("player_spawn", Event_PlayerSpawn);
    HookEvent("round_start", Event_RoundStart);
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("player_team", Event_PlayerTeam);
	
	AutoExecConfig(true, "custom_arms_models");
	
	if (g_bLateLoad)
    {
        for (int i = 1; i <= MaxClients; i++)
        {
			if (IsClientInGame(i)) {
				if (IsPlayerAlive(i))
				{
                    ScheduleApplyArmsModel(i, 1.0);
				}
				else
				{
					// 死亡玩家清除手臂模型
					SetEntPropString(i, Prop_Send, "m_szArmsModel", "");
				}
			}
        }
    }
}

public void OnClientDisconnect(int client)
{
    CancelApplyTimer(client);
}

void ScheduleApplyArmsModel(int client, float delay)
{
    if (!IsClient(client))
        return;

    CancelApplyTimer(client);

    g_hApplyTimer[client] = CreateTimer(delay, Timer_ApplyArmsModel, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

public void OnConfigsExecuted()
{
    LoadArmsModelsConfig();
}

void LoadArmsModelsConfig()
{
    g_smArmsModels.Clear();
    
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "configs/custom_arms_models.cfg");
    
    if (!FileExists(path))
    {
        SetFailState("Configuration file not found: %s", path);
		
        return;
    }
    
    KeyValues kv = new KeyValues("ArmsModels");
    
    kv.ImportFromFile(path);
	
	if(!kv.GotoFirstSubKey())
	{
		SetFailState("Fatal error: Unable to read configuration file \"%s\"!", path);
		return;
	}
    
	char role[PLATFORM_MAX_PATH], model[PLATFORM_MAX_PATH];
	
	do
	{
		kv.GetSectionName(role, sizeof(role));
		kv.GetString("armfile", model, sizeof(model));
		
		// Precache model if not already done
		if (!IsModelPrecached(model))
		{
			PrecacheModel(model, true);
		}
		
		g_smArmsModels.SetString(role, model);
		
	} while (kv.GotoNextKey());
    
    delete kv;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (IsClient(client))
    {
		ScheduleApplyArmsModel(client, 1.0);
    }
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (IsClient(client))
    {
		ScheduleApplyArmsModel(client, 3.0);
    }
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (IsClient(client))
    {
        SetEntPropString(client, Prop_Send, "m_szArmsModel", "");
    }
}

public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (IsClient(client))
    {
		ScheduleApplyArmsModel(client, 1.0);
    }
}

public Action Timer_ApplyArmsModel(Handle timer, any userid)
{
    ClearApplyTimerSlotByHandle(timer);

    int client = GetClientOfUserId(userid);
    if (!IsClient(client))
    {
        return Plugin_Continue;
    }

    // 如果玩家已死亡，清除手臂模型
    if (!IsPlayerAlive(client))
    {
        SetEntPropString(client, Prop_Send, "m_szArmsModel", "");
        return Plugin_Continue;
    }

    // 获取玩家当前模型
    char currentModel[PLATFORM_MAX_PATH];
    GetEntPropString(client, Prop_Data, "m_ModelName", currentModel, sizeof(currentModel));

    // 查找对应的手臂模型
    char armsModel[PLATFORM_MAX_PATH];
    if (!g_smArmsModels.GetString(currentModel, armsModel, sizeof(armsModel)))
    {
        SetEntPropString(client, Prop_Send, "m_szArmsModel", "");
        return Plugin_Continue;
    }

    // 设置手臂模型属性
    SetEntPropString(client, Prop_Send, "m_szArmsModel", armsModel);
    return Plugin_Continue;
}

//检测玩家属性函数
bool IsClient(int client)
{
    return client <= MaxClients && IsClientConnected(client) && IsClientInGame(client);
}
