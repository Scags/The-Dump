#include <sourcemod>
#include <sdkhooks>
#include <tf2_stocks>

public Plugin myinfo =  {
	name = "[TF2] Building Saver", 
	author = "Scag", 
	description = "Gone, but not forgotten", 
	version = "1.0.0", 
	url = ""
};

#define MAX_EDICT_BITS 	11
#define MAX_EDICTS 		(1 << MAX_EDICT_BITS)
#define BOX_MODEL 		"idk"

#define EF_BONEMERGE 	(1 << 0)
#define EF_NOSHADOW		(1 << 4)

enum struct BuildingInfo {
	int iIndex;
	int iHealth;
	int iBullets;
	int iRockets;
	int iUpgradeLevel;
	int iUpgradeMetal;
	TFObjectType iType;
	bool bIsMini;
}

ArrayList
	hBuildingInfo
;

public void OnPluginStart()
{
	HookEvent("object_destroyed", OnObjectDestroy, EventHookMode_Pre);
	hBuildingInfo = new ArrayList(sizeof(BuildingInfo));
}

public Action OnObjectDestroy(Event event, const char[] name, bool dontBroadcast)
{
	int building = event.GetInt("index");
	int client = GetEntPropEnt(building, Prop_Send, "m_hBuilder");
	if (!(0 < client <= MaxClients))
		return Plugin_Continue;

	if (!GetEntProp(client, Prop_Send, "m_bCarryingObject"))
		return Plugin_Continue;

	if (GetEntPropEnt(client, Prop_Send, "m_hCarriedObject") != building)
		return Plugin_Continue;

	int box = CreateEntityByName("tf_ammo_pack");
	if (box == -1)
		return Plugin_Continue;

	char s[16];
	IntToString(GetClientTeam(client)-1, s, sizeof(s));
	DispatchKeyValue(box, "skin", s);

	FormatEx(s, sizeof(s), "box%d", building);
	DispatchKeyValue(box, "targetname", s);

	SetEntityModel(box, BOX_MODEL);
	DispatchSpawn(box);
	SetEntityMoveType(box, MOVETYPE_VPHYSICS);
	ActivateEntity(box);

	float pos[3]; GetEntPropVector(building, Prop_Send, "m_vecOrigin", pos);
	float vel[3];
	vel[0] = GetRandomFloat(-100.0, 100.0);	// Toss a little bit of randomness in there
	vel[1] = GetRandomFloat(-100.0, 100.0);
	vel[2] = GetRandomFloat(-100.0, 100.0);

	TeleportEntity(box, pos, NULL_VECTOR, vel);
	SDKHook(box, SDKHook_StartTouch, OnBoxTouch);

	// Now make it when we look at it
	int highlighter = CreateEntityByName("tf_taunt_prop");
	if (highlighter != -1)
	{
		Format(s, sizeof(s), "highlighter%d", building);
		DispatchKeyValue(highlighter, "targetname", s);

		SetEntityModel(highlighter, BOX_MODEL);

		SetEntPropEnt(highlighter, Prop_Data, "m_hEffectEntity", box);
		SetEntProp(highlighter, Prop_Send, "m_bGlowEnabled", 1);
		SetEntProp(highlighter, Prop_Send, "m_fEffects", GetEntProp(highlighter, Prop_Send, "m_fEffects")|EF_BONEMERGE|EF_NOSHADOW);
		SetEntityFlags(box, GetEntityFlags(box) | FL_EDICT_ALWAYS);

		SetVariantString("!activator");
		AcceptEntityInput(highlighter, "SetParent", box);

		DispatchSpawn(highlighter);

		SDKHook(highlighter, SDKHook_SetTransmit, OnHighlight);
	}

	// Now shove everything needed into the global arraylist
	TFObjectType type = view_as< TFObjectType >(event.GetInt("objecttype"));

	BuildingInfo info;
	info.iIndex = EntRefToEntIndex(box);
	info.iHealth = GetEntProp(building, Prop_Send, "m_iHealth");
	info.iBullets = type == TFObject_Sentry ? GetEntProp(building, Prop_Send, "m_iAmmoShells") : 0;
	info.iRockets = type == TFObject_Sentry ? GetEntProp(building, Prop_Send, "m_iAmmoRockets") : 0;
	info.iUpgradeLevel = GetEntProp(building, Prop_Send, "m_iUpgradeLevel");
	info.iUpgradeMetal = GetEntProp(building, Prop_Send, "m_iUpgradeMetal");
	info.iType = type;
	info.bIsMini = !!GetEntProp(building, Prop_Send, "m_bMiniBuilding");
	event.BroadcastDisabled = true;

	// Whew

	hBuildingInfo.PushArray(info, sizeof(BuildingInfo));
	return Plugin_Continue;
}

public Action OnBoxTouch(int ent)
{
	return Plugin_Handled;	// No touchy
}

public Action OnHighlight(int ent, int other)
{
	if (!(0 < other <= MaxClients))
		return Plugin_Handled;

	if (!IsLookingAtTarget(other, ent, 100.0))
		return Plugin_Handled;

	return Plugin_Continue;
}

public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3], const float angles[3], int weapon, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2])
{
	if (!(0 < client <= MaxClients))
		return;

	if (TF2_GetPlayerClass(client) != TFClass_Engineer || GetEntProp(client, Prop_Send, "m_bCarryingObject"))
		return;

	// One day...
}

stock bool IsLookingAtTarget(int client, int ent, float dist)
{
	float pos[3]; GetClientEyePosition(client, pos);
	float ang[3]; GetClientEyeAngles(client, pos);
	float pos2[3]; GetEntPropVector(ent, Prop_Send, "m_vecOrigin", pos2);
	if (GetVectorDistance(pos, pos2) > dist)
		return false;

	TR_TraceRayFilter(pos, ang, MASK_OPAQUE|MASK_PLAYERSOLID, RayType_EndPoint, VisTrace, client);
	return (!TR_DidHit() || TR_GetEntityIndex() == ent);
}

public bool VisTrace(int ent, int mask, any data)
{
	return !(ent <= MaxClients);
}