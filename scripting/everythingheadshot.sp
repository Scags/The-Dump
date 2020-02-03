#include <sdktools>
#include <sdkhooks>
#include <dhooks>

public Plugin myinfo =  {
	name = "[TF2] Headshot Controller", 
	author = "Scag", 
	description = "Allows control over weapons that can headshot", 
	version = "1.0.0", 
	url = ""
};

Handle
	hCanFireCriticalShot
;

ConVar
	bEnabled,
	hfIgnoredSlots,
	hWeaponSpecifics
;

public void OnPluginStart()
{
	bEnabled = CreateConVar("sm_headshotc_enable", "1.0", "Enable the Everything Headshots plugin?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	hfIgnoredSlots = CreateConVar("sm_headshotc_ignored", "4", "Slot flags to ignore (extra) headshots with. Add up the values to get what you want. 1 = Primary, 2 = Secondary, 4 = Melee.", FCVAR_NOTIFY, true, 0.0, true, 7.0);
	hWeaponSpecifics = CreateConVar("sm_headshotc_weapons", "0", "If sm_headshotc_ignored flags a weapon that can already headshot, should that weapon no longer be able to headshot?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	AutoExecConfig(true, "HeadshotController");

//	GameData conf = new GameData("tf2.headshots");
	// 428 windows
	// 435 linux
	hCanFireCriticalShot = DHookCreate(428, HookType_Entity, ReturnType_Bool, ThisPointer_CBaseEntity, CTFWeaponBase_CanFireCriticalShot);
	DHookAddParam(hCanFireCriticalShot, HookParamType_Bool);
	DHookAddParam(hCanFireCriticalShot, HookParamType_CBaseEntity, _, DHookPass_ByRef);
//	delete conf;
}

public void OnEntityCreated(int ent, const char[] classname)
{
	if (!strncmp(classname, "tf_wea", 6, false))
		DHookEntity(hCanFireCriticalShot, true, ent);
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_TraceAttack, OnTraceAttack);
}

public Action OnTraceAttack(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
	if (!(0 < attacker <= MaxClients) || !IsClientInGame(attacker))
		return Plugin_Continue;

	if (hitgroup == 1)	// Invalid weapons or anything else won't call *CanFireCriticalShot so it's probably fine
	{
		damagetype |= DMG_USE_HITLOCATIONS;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

// Is this even called?
public MRESReturn CTFWeaponBase_CanFireCriticalShot(int pThis, Handle hReturn)
{
	if (!bEnabled.BoolValue)
		return MRES_Ignored;

	int owner = GetEntPropEnt(pThis, Prop_Send, "m_hOwnerEntity");
	if (!(0 < owner <= MaxClients))
		return MRES_Ignored;

	int slot = GetSlotFromWeapon(owner, pThis);
	if (slot == -1)
		return MRES_Ignored;

	bool ret = !(hfIgnoredSlots.IntValue & (1 << slot) && (DHookGetReturn(hReturn) && hWeaponSpecifics.BoolValue));
	DHookSetReturn(hReturn, ret);
	return MRES_Override;
}

stock Handle DHookCreateEx(GameData gc, const char[] key, HookType hooktype, ReturnType returntype, ThisPointerType thistype, DHookCallback callback)
{
	int offset = gc.GetOffset(key);
	if (offset == -1)
	{
		SetFailState("Failed to get offset of %s", key);
		return null;
	}
	
	return DHookCreate(offset, hooktype, returntype, thistype, callback);
}

stock int GetSlotFromWeapon(const int client, const int weapon)
{
	for (int i = 0; i < 5; ++i)
		if (weapon == GetPlayerWeaponSlot(client, i))
			return i;
	return -1;
}