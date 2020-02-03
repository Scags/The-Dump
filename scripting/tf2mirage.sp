#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <dhooks>
#include <tf2_stocks>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =  {
	name = "[TF2] Mirage", 
	author = "Scag", 
	description = "You got bamboozled!", 
	version = "1.0.0", 
	url = ""
};

#define EF_BONEMERGE                (1 << 0)
#define EF_PARENT_ANIMATES          (1 << 9)

float
	flBoozleTime[(1 << 11)],
	flGoal[(1 << 11)][3]
;

int
	iAnims[(1 << 11)][3],	// Still, move, fall
	iGesture[(1 << 11)]
;

static char strGestures[][] = {
	"taunt_russian",
	"taunt_aerobic_b",
	"disco_fever",
	"taunt_laugh"
};

//Animation
Handle g_hResetSequence;
Handle g_hStudioFrameAdvance;
Handle g_hFaceTowards;
Handle g_hMyNextBotPointer;
Handle g_hGetLocomotionInterface;
Handle g_hGetBodyInterface;

Handle g_hGetGroundNormal;
Handle g_hRun;
Handle g_hApproach;
Handle g_hGetStepHeight;
Handle g_hGetGravity;
Handle g_hShouldCollideWith;

Handle g_hGetSolidMask;
Handle g_hGetHullWidth;
Handle g_hGetStandHullHeight;
Handle g_hGetHullMins;
Handle g_hGetHullMaxs;
Handle g_hGetHullHeight;
Handle g_hGetCrouchHullHeight;
Handle g_hGetCollisionGroup;

Handle g_hGetGroundSpeed;
Handle g_hGetVectors;
Handle g_hGetGroundMotionVector;
Handle g_hGetMaxAcceleration;

Handle g_hLookupPoseParameter;
Handle g_hSetPoseParameter;
Handle g_hDispatchAnimEvents;
Handle g_hLookupSequence;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("tf2mirage");
}

public void OnPluginStart()
{
	Handle hConf = LoadGameConfigFile("tf2.pets");
	
	//SDKCalls
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CBaseAnimating::StudioFrameAdvance");
	if ((g_hStudioFrameAdvance = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for CBaseAnimating::StudioFrameAdvance offset!"); 	

	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CBaseAnimating::DispatchAnimEvents");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	if ((g_hDispatchAnimEvents = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for CBaseAnimating::DispatchAnimEvents offset!"); 

	//ResetSequence( int nSequence );
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CBaseAnimating::ResetSequence");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	if ((g_hResetSequence = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for CBaseAnimating::ResetSequence signature!"); 

	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "LookupSequence");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);	//pStudioHdr
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);		//label
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);	//return index
	if((g_hLookupSequence = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Call for LookupSequence");

	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CBaseEntity::MyNextBotPointer");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if ((g_hMyNextBotPointer = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for CBaseEntity::MyNextBotPointer offset!"); 
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "INextBot::GetLocomotionInterface");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if((g_hGetLocomotionInterface = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for INextBot::GetLocomotionInterface!");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "INextBot::GetBodyInterface");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if((g_hGetBodyInterface = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for INextBot::GetBodyInterface!");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "ILocomotion::Run");
	if((g_hRun = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for ILocomotion::Run!");

	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "ILocomotion::Approach");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	if((g_hApproach = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for ILocomotion::Approach!");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "ILocomotion::FaceTowards");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	if((g_hFaceTowards = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for ILocomotion::FaceTowards!");
	
	int iOffset = GameConfGetOffset(hConf, "ILocomotion::GetStepHeight");
	if(iOffset == -1) SetFailState("Failed to get offset of ILocomotion::GetStepHeight");
	g_hGetStepHeight = DHookCreate(iOffset, HookType_Raw, ReturnType_Float, ThisPointer_Address, NextBotGroundLocomotion_GetStepHeight);

	iOffset = GameConfGetOffset(hConf, "ILocomotion::GetGravity");
	if(iOffset == -1) SetFailState("Failed to get offset of ILocomotion::GetGravity");
	g_hGetGravity = DHookCreate(iOffset, HookType_Raw, ReturnType_Float, ThisPointer_Address, NextBotGroundLocomotion_GetGravity);
	
	iOffset = GameConfGetOffset(hConf, "IBody::GetSolidMask");
	if(iOffset == -1) SetFailState("Failed to get offset of IBody::GetSolidMask");
	g_hGetSolidMask = DHookCreate(iOffset, HookType_Raw, ReturnType_Int, ThisPointer_Address, IBody_GetSolidMask);
	
	iOffset = GameConfGetOffset(hConf, "ILocomotion::GetGroundNormal");
	if(iOffset == -1) SetFailState("Failed to get offset of ILocomotion::GetGroundNormal");
	g_hGetGroundNormal = DHookCreate(iOffset, HookType_Raw, ReturnType_VectorPtr, ThisPointer_Address, NextBotGroundLocomotion_GetGroundNormal);
	
	iOffset = GameConfGetOffset(hConf, "ILocomotion::ShouldCollideWith");
	if(iOffset == -1) SetFailState("Failed to get offset of ILocomotion::ShouldCollideWith");
	g_hShouldCollideWith = DHookCreate(iOffset, HookType_Raw, ReturnType_Bool, ThisPointer_Address, NextBotGroundLocomotion_ShouldCollideWith);
	DHookAddParam(g_hShouldCollideWith, HookParamType_CBaseEntity);
	
	iOffset = GameConfGetOffset(hConf, "IBody::GetHullWidth");
	if(iOffset == -1) SetFailState("Failed to get offset of IBody::GetHullWidth");
	g_hGetHullWidth = DHookCreate(iOffset, HookType_Raw, ReturnType_Float, ThisPointer_Address, IBody_GetHullWidth);
	
	iOffset = GameConfGetOffset(hConf, "IBody::GetStandHullHeight");
	if(iOffset == -1) SetFailState("Failed to get offset of IBody::GetStandHullHeight");
	g_hGetStandHullHeight = DHookCreate(iOffset, HookType_Raw, ReturnType_Float, ThisPointer_Address, IBody_GetStandHullHeight);
	
	//Put into gamedata config
	g_hGetMaxAcceleration  = DHookCreateEx(hConf, "ILocomotion::GetMaxAcceleration", HookType_Raw, ReturnType_Float, ThisPointer_Address, ILocomotion_GetMaxAcceleration);
	g_hGetHullMins         = DHookCreateEx(hConf, "IBody::GetHullMins", HookType_Raw, ReturnType_VectorPtr, ThisPointer_Address, IBody_GetHullMins);
	g_hGetHullMaxs         = DHookCreateEx(hConf, "IBody::GetHullMaxs", HookType_Raw, ReturnType_VectorPtr, ThisPointer_Address, IBody_GetHullMaxs);
	g_hGetHullHeight       = DHookCreateEx(hConf, "IBody::GetHullHeight", HookType_Raw, ReturnType_Float,     ThisPointer_Address, IBody_GetHullHeight);
	g_hGetCrouchHullHeight = DHookCreateEx(hConf, "IBody::GetCrouchHullHeight", HookType_Raw, ReturnType_Float,     ThisPointer_Address, IBody_GetCrouchHullHeight);
	g_hGetCollisionGroup   = DHookCreateEx(hConf, "IBody::GetCollisionGroup", HookType_Raw, ReturnType_Int,       ThisPointer_Address, IBody_GetCollisionGroup);
	
	//ILocomotion::GetGroundSpeed() 
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "ILocomotion::GetGroundSpeed");
	PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);
	if((g_hGetGroundSpeed = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for ILocomotion::GetGroundSpeed!");
	
	//ILocomotion::GetGroundMotionVector() 
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "ILocomotion::GetGroundMotionVector");
	PrepSDKCall_SetReturnInfo(SDKType_Vector, SDKPass_ByRef);
	if((g_hGetGroundMotionVector = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for ILocomotion::GetGroundMotionVector!");
	
	//CBaseEntity::GetVectors(Vector*, Vector*, Vector*) 
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CBaseEntity::GetVectors");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK);
	if((g_hGetVectors = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for CBaseEntity::GetVectors!");
	
	//SetPoseParameter( CStudioHdr *pStudioHdr, int iParameter, float flValue );
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CBaseAnimating::SetPoseParameter");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);
	if((g_hSetPoseParameter = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Call for CBaseAnimating::SetPoseParameter");
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CBaseAnimating::LookupPoseParameter");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if((g_hLookupPoseParameter = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Call for CBaseAnimating::LookupPoseParameter");
	
	//DHooks
	//Dumbass base_boss quirk
	g_hGetStepHeight = DHookCreateEx(hConf, "ILocomotion::GetStepHeight", HookType_Raw, ReturnType_Float, ThisPointer_Address, ILocomotion_GetStepHeight);	
	
	delete hConf;
}

public void OnMapStart()
{
	PrecacheGeneric("ping_circle");
}

public Action OnPlayerRunCmd(int client, int & buttons, int & impulse, float vel[3], float angles[3], int & weapon, int & subtype, int & cmdnum, int & tickcount, int & seed, int mouse[2])
{
	//if (GetSteamAccountID(client) == 125236808)
	//	PrintToConsole(client, "%d", GetEntProp(client, Prop_Send, "m_nSequence"));
	if (!(buttons & IN_ATTACK2))
		return Plugin_Continue;

	if (GetClientCloakIndex(client) != 60)
		return Plugin_Continue;

	buttons &= ~IN_ATTACK2;

	if (GetEntPropFloat(client, Prop_Send, "m_flCloakMeter") < 100.0)
		return Plugin_Changed;

	float pos[3]; GetClientEyePosition(client, pos);
	float endpos[3];
	if (!GetAimPos(client, pos, angles, endpos))
		return Plugin_Changed;

	SetEntPropFloat(client, Prop_Send, "m_flCloakMeter", 0.0);

	int ping = ShowParticle(endpos, "ping_circle", 3.0);
	SetEntPropEnt(ping, Prop_Send, "m_hOwnerEntity", client);
	SDKHook(ping, SDKHook_SetTransmit, OnPingTransmit);

	int wep = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");

	// base_boss stufffffffffff
	char strModel[PLATFORM_MAX_PATH];
	GetEntPropString(client, Prop_Data, "m_ModelName", strModel, PLATFORM_MAX_PATH);
	
	int npc = CreateEntityByName("base_boss");
	float pos2[3]; GetClientAbsOrigin(client, pos2);
	DispatchKeyValueVector(npc, "origin", pos2);
	angles[0] = 0.0;
	DispatchKeyValueVector(npc, "angles", angles);
	DispatchKeyValue(npc, "model", strModel);
	DispatchKeyValue(npc, "modelscale", "1.0");
	DispatchKeyValue(npc, "health", "0");
	DispatchSpawn(npc);

	////////////////////////////
	
	int table = FindStringTable("modelprecache");
	if (IsValidEntity(wep))
		ReadStringTable(table, GetEntProp(wep, Prop_Send, "m_iWorldModelIndex"), strModel, PLATFORM_MAX_PATH);  
	
	if(!StrEqual(strModel, ""))
	{	
		int item = CreateEntityByName("prop_dynamic");
		DispatchKeyValue(item, "model", strModel);
		DispatchSpawn(item);
		
		SetEntProp(item, Prop_Send, "m_nSkin", GetEntProp(client, Prop_Send, "m_nSkin"));
		SetEntProp(item, Prop_Send, "m_hOwnerEntity", npc);
		SetEntProp(item, Prop_Send, "m_fEffects", (1 << 0)|(1 << 9)|16);
	
		SetVariantString("!activator");
		AcceptEntityInput(item, "SetParent", npc);
		
		SetVariantString("head");
		AcceptEntityInput(item, "SetParentAttachmentMaintainOffset"); 
	}

	////////////////////////////
	
	
	PrepBot(client, npc);
	SDKCall(g_hResetSequence, npc, GetEntProp(client, Prop_Send, "m_nSequence"));
	SDKCall(g_hStudioFrameAdvance, npc);

	if (wep == GetPlayerWeaponSlot(client, 0))
	{
		iAnims[npc][0] = 84;
		iAnims[npc][1] = 147;
		iAnims[npc][2] = 98;
	}
	else if (wep == GetPlayerWeaponSlot(client, 1))
	{
		iAnims[npc][0] = 84;
		iAnims[npc][1] = 147;
		iAnims[npc][2] = 98;
	}
	else if (wep == GetPlayerWeaponSlot(client, 2))
	{
		if (GetEntProp(wep, Prop_Send, "m_iItemDefinitionIndex") == 638)	// Sharp Dresser
		{
			iAnims[npc][0] = 87;
			iAnims[npc][1] = 152;
			iAnims[npc][2] = 114;
		}
		else
		{
			iAnims[npc][0] = 84;
			iAnims[npc][1] = 147;			
			iAnims[npc][2] = 102;
		}
	}
	else if (wep == GetPlayerWeaponSlot(client, 3))
	{
		iAnims[npc][0] = 88;
		iAnims[npc][1] = 154;
		iAnims[npc][2] = 118;
	}
	
	iGesture[npc] = 0;
	flGoal[npc] = endpos;
	float time = GetGameTime() + 12.0;
	flBoozleTime[npc] = time;

	int iWearable = -1;
	int iItem;
	while ((iWearable = FindEntityByClassname(iWearable, "tf_wearable*")) != -1)
	{
		if(!GetEntProp(iWearable, Prop_Send, "m_bDisguiseWearable") && GetEntPropEnt(iWearable, Prop_Send, "m_hOwnerEntity") == client)
		{
			GetEntPropString(iWearable, Prop_Data, "m_ModelName", strModel, PLATFORM_MAX_PATH);
			iItem = EquipItem(npc, "head", strModel, _, GetClientTeam(client) - 2);
			
			SetVariantString("1.0");
			AcceptEntityInput(iItem, "SetModelScale");
		}
	}

	SDKHook(npc, SDKHook_Think, OnMirageThink);

	return Plugin_Changed;
}

public void OnMirageThink(int iEntity)
{
	int client = GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity");
	if (client <= 0 || !IsPlayerAlive(client))
	{
		AcceptEntityInput(iEntity, "KillHierarchy");
		return;
	}

	if (flBoozleTime[iEntity] < GetGameTime())
	{
		AcceptEntityInput(iEntity, "KillHierarchy");
		return;
	}

	Address pLocomotion = GetLocomotionInterface(iEntity);
	if(pLocomotion == Address_Null)
		return;

//	Profiler prof = CreateProfiler();
//	prof.Start();

	SetEntityFlags(iEntity, FL_ONGROUND);
	SetEntPropEnt(iEntity, Prop_Data, "m_hGroundEntity", 0);
	SetEntPropVector(iEntity, Prop_Data, "m_vecAbsVelocity", NULL_VECTOR);

	float pos[3]; GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", pos);
	int iSequence = GetEntProp(iEntity, Prop_Send, "m_nSequence");
//	if (GetSteamAccountID(client) == 125236808)
//		PrintToConsole(client, "%d", iSequence);

	SDKCall(g_hStudioFrameAdvance, iEntity);
	SDKCall(g_hDispatchAnimEvents, iEntity, iEntity);

	if (flGoal[iEntity][2] == -9999.0)
	{
		SetEntProp(iEntity, Prop_Data, "m_bSequenceLoops", true);
		//PrintToChat(client, "%d\n%s", iGesture[iEntity], strGestures[iGesture[iEntity]]);
		int seq = GetEntProp(iEntity, Prop_Send, "m_nSequence");
		int seq2 = SDKCall(g_hLookupSequence, GetStudioHdr(iEntity), strGestures[iGesture[iEntity]]);
		if (seq != seq2)
			SDKCall(g_hResetSequence, iEntity, seq2);

//		delete prof;
		return;
	}
	if (GetVectorDistance(pos, flGoal[iEntity]) < 40.0)
	{
		if(iSequence != iAnims[iEntity][0])
		{
			float v[3];
			TeleportEntity(iEntity, NULL_VECTOR, NULL_VECTOR, v);
			//Set animation.
			SDKCall(g_hResetSequence, iEntity, iAnims[iEntity][0]);
		}
//		delete prof;
		return;
	}

	Address pStudioHdr = GetStudioHdr(iEntity);

	SDKCall(g_hRun, pLocomotion);
	SDKCall(g_hApproach, pLocomotion, flGoal[iEntity], 1.0);
	static ConVar flTurnRate;
	if (!flTurnRate) flTurnRate = FindConVar("tf_base_boss_max_turn_rate");
	float flPrevValue = flTurnRate.FloatValue;
	flTurnRate.FloatValue = 200.0;
	SDKCall(g_hFaceTowards, pLocomotion, flGoal[iEntity]);
	flTurnRate.FloatValue = flPrevValue;

	int m_iMoveX = SDKCall(g_hLookupPoseParameter, iEntity, pStudioHdr, "move_x");
	int m_iMoveY = SDKCall(g_hLookupPoseParameter, iEntity, pStudioHdr, "move_y");

	if ( m_iMoveX <= 0 || m_iMoveY <= 0 )
	{
//		delete prof;
		return;
	}

	float m_flGroundSpeed = GetEntPropFloat(iEntity, Prop_Data, "m_flGroundSpeed");
	float flGroundSpeed = SDKCall(g_hGetGroundSpeed, pLocomotion);
	if ( flGroundSpeed <= 1.0 )
	{
		SDKCall(g_hSetPoseParameter, iEntity, pStudioHdr, m_iMoveX, 0.0);
		SDKCall(g_hSetPoseParameter, iEntity, pStudioHdr, m_iMoveY, 0.0);
		
		if(iSequence != iAnims[iEntity][0])
		{
			//Set animation.
			SDKCall(g_hResetSequence, iEntity, iAnims[iEntity][0]);      
		}
	}
	else
	{
		if (!(GetEntityFlags(iEntity) & FL_ONGROUND))
		{
			if(iSequence != iAnims[iEntity][2])
			{
				SDKCall(g_hResetSequence, iEntity, iAnims[iEntity][2]);				
			}
		}
		else
		{
			if(iSequence != iAnims[iEntity][1])
			{
				SDKCall(g_hResetSequence, iEntity, iAnims[iEntity][1]);
			}
		}
		
		float vecForward[3], vecRight[3], vecUp[3];
		SDKCall(g_hGetVectors, iEntity, vecForward, vecRight, vecUp);
		
		float vecMotion[3];
		SDKCall(g_hGetGroundMotionVector, pLocomotion, vecMotion);
		
		SDKCall(g_hSetPoseParameter, iEntity, pStudioHdr, m_iMoveX, GetVectorDotProduct(vecMotion, vecForward));
		SDKCall(g_hSetPoseParameter, iEntity, pStudioHdr, m_iMoveY, GetVectorDotProduct(vecMotion, vecRight));
	}
	
	if(m_flGroundSpeed != 0.0)
	{
		float flReturnValue = clamp(flGroundSpeed / m_flGroundSpeed, -4.0, 12.0);
		
		SetEntPropFloat(iEntity, Prop_Send, "m_flPlaybackRate", flReturnValue);
	}
//	prof.Stop();
//	PrintToChatAll("%f", prof.Time);
//	delete prof;
}

public Action OnPingTransmit(int ent, int other)
{
	if (!(0 < other <= MaxClients))
		return Plugin_Continue;

	return (GetClientTeam(GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity")) == GetClientTeam(other)) ? Plugin_Continue : Plugin_Handled;
}

public Action DeleteParticles(Handle timer, any ref)
{
	int ent = EntRefToEntIndex(ref);
	if (IsValidEntity(ent))
		RemoveEntity(ent);
}

public void PrepBot(const int client, const int npc)
{
	Address pLoco = GetLocomotionInterface(npc);
	if (pLoco != Address_Null)
	{
		DHookRaw(g_hGetStepHeight,       true, pLoco);	//NextBot hack to get it to stay in air
		DHookRaw(g_hShouldCollideWith,   true, pLoco);  //Don't need to collide with anything but world
		DHookRaw(g_hGetStepHeight,       true, pLoco);  //The default step height on a base_boss is 1000.0 and this causes it to be able to climb HUGE gaps, limit it to 18.0
		DHookRaw(g_hGetGravity,          true, pLoco);  //The default gravity on base_boss is too big and causes it to fall onto the ground way too fast.
		DHookRaw(g_hGetGroundNormal,     true, pLoco);  //The default base_boss rotates itself to the ground normal, this prevents that.
		DHookRaw(g_hGetMaxAcceleration,  true, pLoco);  //We want to accelerate faster than by default.
	}
	
	Address pBody = GetBodyInterface(npc);
	if (pBody != Address_Null)
	{
		DHookRaw(g_hGetHullMins,         true, pBody);  //Fixes the NPC getting stuck so much
		DHookRaw(g_hGetHullMaxs,         true, pBody);  //Fixes the NPC getting stuck so much  
		DHookRaw(g_hGetHullWidth,        true, pBody);  //Fixes the NPC getting stuck so much
		DHookRaw(g_hGetSolidMask,        true, pBody);  //The default mask causes base_boss to fall through some things players could walk on.
		DHookRaw(g_hGetStandHullHeight,  true, pBody);  //Fixes the NPC getting stuck so much
		DHookRaw(g_hGetCrouchHullHeight, true, pBody);  //Fixes the NPC getting stuck so much
		DHookRaw(g_hGetHullHeight,       true, pBody);  //Fixes the NPC getting stuck so much
		DHookRaw(g_hGetCollisionGroup,   true, pBody);  //Fixes the NPC getting stuck so much
	}
	
	SetEntProp(npc, Prop_Data, "m_takedamage", 0);
	SetEntProp(npc, Prop_Send, "m_iTeamNum", GetClientTeam(client));
	SetEntProp(npc, Prop_Data, "m_CollisionGroup", 1);
	
	SetEntityRenderMode(npc, RENDER_NORMAL);
	
	SetEntProp(npc, Prop_Data, "m_bloodColor", -1); //Don't bleed
	SetEntProp(npc, Prop_Send, "m_nSkin", GetEntProp(client, Prop_Send, "m_nSkin")); //Don't bleed
	SetEntPropEnt(npc, Prop_Data, "m_hOwnerEntity", client);
	SetEntPropFloat(npc, Prop_Data, "m_speed", GetEntPropFloat(client, Prop_Send, "m_flMaxspeed"));

	SetEntData(npc, FindSendPropInfo("CTFBaseBoss", "m_lastHealthPercentage") + 28, false, 4, true);	//ResolvePlayerCollisions

	ActivateEntity(npc);
}

stock bool GetAimPos(const int client, float pos[3], float ang[3], float endpos[3])
{
	Handle trace = TR_TraceRayFilterEx(pos, ang, MASK_SHOT, RayType_Infinite, TraceIgnorePlayers, client);
	bool ret;

	if ((ret = TR_DidHit(trace)))
		TR_GetEndPosition(endpos, trace);

	delete trace;

	return ret;
}

public bool TraceIgnorePlayers(int ent, int mask, any data)
{
	return !(0 < ent <= MaxClients);
}

stock int ShowParticle(float pos[3], char[] particlename, float time)
{
	int particle = CreateEntityByName("info_particle_system");
	if (particle != -1)
	{
		TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
		DispatchKeyValue(particle, "effect_name", particlename);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		CreateTimer(time, DeleteParticles, EntIndexToEntRef(particle));
	}
	return particle;
}

public Address GetLocomotionInterface(int index) { return SDKCall(g_hGetLocomotionInterface, SDKCall(g_hMyNextBotPointer, index)); }
public Address GetStudioHdr(int npc) { return view_as<Address>(GetEntData(npc, FindDataMapInfo(npc, "m_flFadeScale") + 28)); }

public MRESReturn ILocomotion_GetStepHeight(Address pThis, Handle hReturn, Handle hParams) { DHookSetReturn(hReturn, 18.0); return MRES_Supercede; }

Handle DHookCreateEx(Handle gc, const char[] key, HookType hooktype, ReturnType returntype, ThisPointerType thistype, DHookCallback callback)
{
	int iOffset = GameConfGetOffset(gc, key);
	if(iOffset == -1)
	{
		SetFailState("Failed to get offset of %s", key);
		return null;
	}
	
	return DHookCreate(iOffset, hooktype, returntype, thistype, callback);
}

stock float[] WorldSpaceCenter(int entity)
{
	float vecPos[3];
	SDKCall(g_hSDKWorldSpaceCenter, entity, vecPos);
	
	return vecPos;
}

stock int GetClientCloakIndex(const int client)
{
	if (!(0 < client <= MaxClients))
		return -1;
	int wep = GetPlayerWeaponSlot(client, 4);
	if (wep <= MaxClients || !IsValidEntity(wep))
		return -1;
	return GetEntProp(wep, Prop_Send, "m_iItemDefinitionIndex");
}

public Address GetBodyInterface(int index)
{
	Address pNB = SDKCall(g_hMyNextBotPointer, index);
	return SDKCall(g_hGetBodyInterface, pNB);
}


public MRESReturn IBody_GetHullWidth(Address pThis, Handle hReturn, Handle hParams)
{
//  PrintToServer("GetHullWidth %f", DHookGetReturn(hReturn));

	DHookSetReturn(hReturn, 26.0);
	return MRES_Supercede;
}

public MRESReturn IBody_GetStandHullHeight(Address pThis, Handle hReturn, Handle hParams)
{
//  PrintToServer("GetStandHullHeight %f", DHookGetReturn(hReturn));
	
	DHookSetReturn(hReturn, 68.0);
	return MRES_Supercede;
}

public MRESReturn IBody_GetHullHeight(Address pThis, Handle hReturn, Handle hParams)
{
//  PrintToServer("GetHullHeight %f", DHookGetReturn(hReturn));
	
	DHookSetReturn(hReturn, 68.0);
	return MRES_Supercede;
}

public MRESReturn IBody_GetCrouchHullHeight(Address pThis, Handle hReturn, Handle hParams)
{
//  PrintToServer("GetCrouchHullHeight %f", DHookGetReturn(hReturn));
	
	DHookSetReturn(hReturn, 32.0);
	return MRES_Supercede;
}

public MRESReturn IBody_GetCollisionGroup(Address pThis, Handle hReturn, Handle hParams)
{
//  PrintToServer("GetCollisionGroup %i", DHookGetReturn(hReturn));

	DHookSetReturn(hReturn, 1);
	return MRES_Supercede;
}

public MRESReturn IBody_GetHullMins(Address pThis, Handle hReturn, Handle hParams)
{
//  float vecReturn[3];
//  DHookGetReturnVector(hReturn, vecReturn);
	
//  PrintToServer("GetHullMins %f %f %f", vecReturn[0], vecReturn[1], vecReturn[2]);
	
	DHookSetReturnVector(hReturn, view_as<float>( { -13.0, -13.0, 0.0 } ));
	return MRES_Supercede;
}

public MRESReturn IBody_GetHullMaxs(Address pThis, Handle hReturn, Handle hParams)
{
//  float vecReturn[3];
//  DHookGetReturnVector(hReturn, vecReturn);
	
//  PrintToServer("GetHullMaxs %f %f %f", vecReturn[0], vecReturn[1], vecReturn[2]);
	
	DHookSetReturnVector(hReturn, view_as<float>( { 13.0, 13.0, 68.0 } ));
	return MRES_Supercede;
}

public MRESReturn IBody_GetSolidMask(Address pThis, Handle hReturn, Handle hParams)
{
//  PrintToServer("GetSolidMask 0x%x", DHookGetReturn(hReturn));
	
	DHookSetReturn(hReturn, MASK_NPCSOLID|MASK_PLAYERSOLID);
	return MRES_Supercede;
}

public MRESReturn ILocomotion_GetMaxAcceleration(Address pThis, Handle hReturn, Handle hParams)
{
	DHookSetReturn(hReturn, 300.0);
	return MRES_Supercede;
}

public MRESReturn NextBotGroundLocomotion_GetStepHeight(Address pThis, Handle hReturn, Handle hParams)
{
	DHookSetReturn(hReturn, 18.0);
	return MRES_Supercede;
}

public MRESReturn NextBotGroundLocomotion_ShouldCollideWith(Address pThis, Handle hReturn, Handle hParams)
{
	DHookSetReturn(hReturn, false);
	return MRES_Supercede;
}

public MRESReturn NextBotGroundLocomotion_GetGravity(Address pThis, Handle hReturn, Handle hParams)
{
	DHookSetReturn(hReturn, 800.0);
	return MRES_Supercede;
}

public MRESReturn NextBotGroundLocomotion_GetGroundNormal(Address pThis, Handle hReturn, Handle hParams)
{
	DHookSetReturnVector(hReturn, view_as<float>( { 0.0, 0.0, 1.0 } ));
	return MRES_Supercede;
}

public float clamp(float a, float b, float c)
{
	return (a > c ? c : (a < b ? b : a));
}

stock int EquipItem(int ent, const char[] attachment, const char[] model, const char[] anim = "", int skin = 0, float flScale = 1.0)
{
	int item = CreateEntityByName("prop_dynamic");
	DispatchKeyValue(item, "model", model);
	DispatchKeyValueFloat(item, "modelscale", flScale == 1.0 ? GetEntPropFloat(ent, Prop_Send, "m_flModelScale") : flScale);
	DispatchSpawn(item);
	
	SetEntProp(item, Prop_Send, "m_nSkin", skin);
	SetEntProp(item, Prop_Send, "m_hOwnerEntity", ent);
	SetEntProp(item, Prop_Send, "m_fEffects", EF_BONEMERGE|EF_PARENT_ANIMATES|16);	// EF_NOSHADOW
	SetEntProp(item, Prop_Send, "m_nRenderFX", 6);

	if(!StrEqual(anim, ""))
	{
		SetVariantString(anim);
		AcceptEntityInput(item, "SetAnimation");
	}

	SetVariantString("!activator");
	AcceptEntityInput(item, "SetParent", ent);
	
	SetVariantString(attachment);
	AcceptEntityInput(item, "SetParentAttachmentMaintainOffset"); 
	
	return item;
}

stock bool BringClientToSide(const int client, const float flOrigin[3], bool z = true)
{
	float vec_modifier[3];
	const float flMove = 70.0;
	vec_modifier = flOrigin; vec_modifier[0] += flMove;	// check x-axis
	if (!IsClientStuck(client, vec_modifier)) {
		TeleportEntity(client, vec_modifier, NULL_VECTOR, NULL_VECTOR);
		return true;
	}
	vec_modifier = flOrigin; vec_modifier[0] -= flMove;
	if (!IsClientStuck(client, vec_modifier)) {
		TeleportEntity(client, vec_modifier, NULL_VECTOR, NULL_VECTOR);
		return true;
	}
	vec_modifier = flOrigin; vec_modifier[1] += flMove;	// check y-axis
	if (!IsClientStuck(client, vec_modifier)) {
		TeleportEntity(client, vec_modifier, NULL_VECTOR, NULL_VECTOR);
		return true;
	}
	vec_modifier = flOrigin; vec_modifier[1] -= flMove;
	if (!IsClientStuck(client, vec_modifier)) {
		TeleportEntity(client, vec_modifier, NULL_VECTOR, NULL_VECTOR);
		return true;
	}

	if (z)
	{
		vec_modifier = flOrigin; vec_modifier[2] += flMove;	// check z-axis
		if (!IsClientStuck(client, vec_modifier)) {
			TeleportEntity(client, vec_modifier, NULL_VECTOR, NULL_VECTOR);
			return true;
		}
		vec_modifier = flOrigin; vec_modifier[2] -= flMove;
		if (!IsClientStuck(client, vec_modifier)) {
			TeleportEntity(client, vec_modifier, NULL_VECTOR, NULL_VECTOR);
			return true;
		}
	}
	return false;
}

stock bool IsClientStuck(const int iEntity, const float flOrigin[3])
{
	//float flOrigin[3]; GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", flOrigin);
	float flMins[3]; GetEntPropVector(iEntity, Prop_Send, "m_vecMins", flMins);
	float flMaxs[3]; GetEntPropVector(iEntity, Prop_Send, "m_vecMaxs", flMaxs);

	TR_TraceHullFilter(flOrigin, flOrigin, flMins, flMaxs, MASK_PLAYERSOLID, TraceIgnorePlayers, iEntity);
	return TR_DidHit();
}

