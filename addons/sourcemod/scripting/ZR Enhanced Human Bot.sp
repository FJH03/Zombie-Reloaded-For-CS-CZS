#include <sdktools>
#include <sourcemod>
#include <cstrike>
#include <zombiereloaded>

public Plugin:myinfo =
{
	name = "[ZR] Enhanced Human Bot",
	author = "[CNSR] FJH_03 & H-AN",
	description = "加强人类Bot攻击感染体",
	version = "1.0",
	url = "<-url->"
};

public Action OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon, &subtype, &cmdnum, &tickcount, &seed, mouse[2])
{
	if(client <= 0 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client) || !IsFakeClient(client))
		return Plugin_Continue;

	if (ZR_IsClientZombie(client)) return Plugin_Continue;

	int target = GetClosestClient(client);
	if (target <= -1 || !IsValidEntity(target)) 
		return Plugin_Continue;

	if (!ClientCanSeeTarget(client, target, 800.0) || !IsPlayerAlive(target) || !ZR_IsClientZombie(target)) return Plugin_Continue;

	float clientPos[3], targetPos[3];
	GetClientAbsOrigin(client, clientPos);
	GetEntPropVector(target, Prop_Send, "m_vecOrigin", targetPos);
	float actualDistance = GetVectorDistance(clientPos, targetPos);

	LookAtTarget(client, target);
	if (actualDistance < 300.0)
	{
		vel[0] = (220.0 * -1.0);
	}
	else if (actualDistance > 400.0)
	{
		vel[0] = 220.0;
	}

	return Plugin_Continue;
}

int GetClosestClient(int client)
{
	float fClientOrigin[3], fTargetOrigin[3];
	GetClientAbsOrigin(client, fClientOrigin);
	int iClosestTarget = -1;
	
	float fClosestDistance = -1.0;
	float fTargetDistance;

	for (int i = 1; i <= MAXPLAYERS; i++)
	{
		if (!IsValidEntity(i) || i == client)
		{
			continue;
		}
		
		char classname[32];
		GetEdictClassname(i, classname, sizeof(classname));
		if (!StrEqual(classname, "player"))
		   continue;
		
		if (!IsClientConnected(i) || !IsClientInGame(i))
			continue;

		GetClientAbsOrigin(i, fTargetOrigin);
		fTargetDistance = GetVectorDistance(fClientOrigin, fTargetOrigin);

		if (fTargetDistance > fClosestDistance && fClosestDistance > -1.0)
		{
			continue;
		}

		if (!ClientCanSeeTarget(client, i))
		{
			continue;
		}
				
		fClosestDistance = fTargetDistance;
		iClosestTarget = i;

	}   
	return iClosestTarget;
}

bool ClientCanSeeTarget(int client, int iTarget, float fDistance = 0.0, float fHeight = 50.0)
{
	float fClientPosition[3]; float fTargetPosition[3];
	
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", fClientPosition);
	fClientPosition[2] += fHeight;
	
	GetEntPropVector(iTarget, Prop_Send, "m_vecOrigin", fTargetPosition);
	fTargetPosition[2] += fHeight;
	
	if (fDistance == 0.0 || GetVectorDistance(fClientPosition, fTargetPosition, false) < fDistance)
	{
		Handle hTrace = TR_TraceRayFilterEx(fClientPosition, fTargetPosition, MASK_SOLID_BRUSHONLY, RayType_EndPoint, Base_TraceFilter);
		
		if (TR_DidHit(hTrace))
		{
			delete hTrace;
			return false;
		}
		
		delete hTrace;
		return true;
	}
	
	return false;
}

void LookAtTarget(int client, int iTarget)
{

   if(!IsValidEntity(iTarget))
		return;

	float fTargetPos[3]; float fTargetAngles[3]; float fFinalPos[3]; float fClientPos[3];
	GetClientEyePosition(client, fClientPos);
	GetEntPropVector(iTarget, Prop_Send, "m_vecOrigin", fTargetPos);
	fTargetPos[2] += 50.0;
	GetEntPropVector(iTarget, Prop_Data, "m_angRotation", fTargetAngles);
	
	float fVecFinal[3];
	AddInFrontOf(fTargetPos, fTargetAngles, 7.0, fVecFinal);
	MakeVectorFromPoints(fClientPos, fVecFinal, fFinalPos);
	
	GetVectorAngles(fFinalPos, fFinalPos);

	TeleportEntity(client, NULL_VECTOR, fFinalPos, NULL_VECTOR); 
}

void AddInFrontOf(float fVecOrigin[3], float fVecAngle[3], float fUnits, float fOutPut[3])
{
    float fVecView[3]; GetViewVector(fVecAngle, fVecView);
    
    fOutPut[0] = fVecView[0] * fUnits + fVecOrigin[0];
    fOutPut[1] = fVecView[1] * fUnits + fVecOrigin[1];
    fOutPut[2] = fVecView[2] * fUnits + fVecOrigin[2];
}

void GetViewVector(float fVecAngle[3], float fOutPut[3])
{
    fOutPut[0] = Cosine(fVecAngle[1] / (180 / FLOAT_PI));
    fOutPut[1] = Sine(fVecAngle[1] / (180 / FLOAT_PI));
    fOutPut[2] = -Sine(fVecAngle[0] / (180 / FLOAT_PI));
}

bool Base_TraceFilter(int iEntity, int iContentsMask, int iData)
{
    return iEntity == iData;
}