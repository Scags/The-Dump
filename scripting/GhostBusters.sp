#pragma semicolon 1

#include <sourcemod>
#include <tf2attributes>
#include <tf2items>
#include <tf2_stocks>
#include <sdkhooks>
#include <sdktools>
#include <morecolors>

#pragma newdecls required

#define PLUGIN_VERSION 	"1.0.0"
#define TAG 			"{black}[{fullred}GB{black}]{default}"
#define MEDIGUN_RANGE 	450.0

#define GhostModel1 	"models/props_halloween/ghost.mdl"
#define GhostModel2 	"models/props_halloween/ghost_no_hat.mdl"

public Plugin myinfo =  {
	name = "[TF2] Ghost Busters", 
	author = "Scag/Ragenewb", 
	description = "WHO YOU GONNA CALL?", 
	version = PLUGIN_VERSION, 
	url = ""
};

ConVar
	bEnabled,
	cvTeamRatio,
	cvRoundTime
;

Handle
	hHudText,
	hRoundHud
;

int
	g_iTimeLeft,
	iHealCount[MAXPLAYERS+1],
	iKills[MAXPLAYERS+1]
;

bool
	g_bActiveRound,
	bBeingVaped[MAXPLAYERS+1],
	bJumping[MAXPLAYERS+1]
;

float
	flCharge[MAXPLAYERS+1]
;

public void OnPluginStart()
{
	bEnabled = CreateConVar("sm_gb_enabled", "1", "Enabled the GhostBusters plugin?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	CreateConVar("gb_version", PLUGIN_VERSION, "GhostBusters plugin version", FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_CHEAT);
	cvTeamRatio = CreateConVar("sm_gb_team_ratio", "1.0", "Ratio in which teams are to be stacked", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvRoundTime = CreateConVar("sm_gb_round_time", "300", "Time in seconds as to how long the round should last", FCVAR_NOTIFY, true, 0.0, true, 600.0);

	AutoExecConfig(true, "GhostBusters");

	hHudText = CreateHudSynchronizer();
	hRoundHud = CreateHudSynchronizer();

	HookEvent("arena_round_start", OnArenaRoundStart);
	HookEvent("teamplay_round_start", OnRoundStart);
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Pre);

	for (int i = MaxClients; i; --i)
		if (IsClientInGame(i))
			OnClientPutInServer(i);
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	// SDKHook(client, SDKHook_PreThink, OnPreThink);
	ResetVars(client);
}

stock void ResetVars(const int client)
{
	iHealCount[client] = 0;
	iKills[client] = 0;
	bBeingVaped[client] = false;
	bJumping[client] = false;
	flCharge[client] = 0.0;
}

public void OnMapStart()
{
	PrecacheModel(GhostModel1);
	PrecacheModel(GhostModel2);

	CreateTimer(0.1, Timer_PlayerThink, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public void OnConfigsExecuted()
{
	FindConVar("tf_arena_use_queue").SetInt(0);
	// FindConVar("mp_teams_unbalance_limit").SetInt(0);
	FindConVar("tf_arena_first_blood").SetInt(0);
	FindConVar("mp_forcecamera").SetInt(0);
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (!bEnabled.BoolValue)
		return Plugin_Continue;

	if (!(0 < attacker <= MaxClients))
		return Plugin_Continue;

	if (!(0 < victim <= MaxClients))
		return Plugin_Continue;

	if (attacker == victim)
		return Plugin_Continue;

	TFClassType class = TF2_GetPlayerClass(attacker);

	if (class == TFClass_Spy)
	{
		if (damagetype == TF_CUSTOM_BACKSTAB)
			TF2_StunPlayer(victim, 2.0, _, TF_STUNFLAGS_LOSERSTATE);
		damage *= 0.0;
		return Plugin_Changed;
	}
	else if (class == TFClass_Medic)
	{
		damage *= 0.0;
		return Plugin_Changed;
	}
	else if (class == TFClass_Heavy)
	{
		if (bJumping[attacker])
		{
			damagetype |= DMG_CRIT;
			return Plugin_Changed;
		}
	}

	return Plugin_Continue;
}

public Action Timer_PlayerThink(Handle timer)
{
	if (!bEnabled.BoolValue)
		return Plugin_Stop;

	if (!g_bActiveRound)
		return Plugin_Continue;

	for (int i = MaxClients; i; --i)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i))
			continue;

		ManagePlayerThink(i);
	}
	return Plugin_Continue;
}

public Action Timer_Round(Handle timer)
{
	if (!bEnabled.BoolValue || !g_bActiveRound)
		return Plugin_Stop;

	int time = g_iTimeLeft;
	g_iTimeLeft--;
	char strTime[6];
	
	if (time / 60 > 9)
		IntToString(time / 60, strTime, 6);
	else Format(strTime, 6, "0%i", time / 60);
	
	if (time % 60 > 9)
		Format(strTime, 6, "%s:%i", strTime, time % 60);
	else Format(strTime, 6, "%s:0%i", strTime, time % 60);

	SetHudTextParams(-1.0, 0.17, 1.1, 255, 255, 255, 255);
	for (int i = MaxClients; i; --i)
		if (IsClientInGame(i))
			ShowSyncHudText(i, hRoundHud, strTime);

	switch (time) 
	{
		case 60:EmitSoundToAll("vo/announcer_ends_60sec.mp3");
		case 30:EmitSoundToAll("vo/announcer_ends_30sec.mp3");
		case 10:EmitSoundToAll("vo/announcer_ends_10sec.mp3");
		case 1, 2, 3, 4, 5: 
		{
			char sound[PLATFORM_MAX_PATH];
			Format(sound, PLATFORM_MAX_PATH, "vo/announcer_ends_%isec.mp3", time);
			EmitSoundToAll(sound);
		}
		case 0:
		{
			ForceTeamWin(3);
			return Plugin_Stop;
		}
	}
	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (!IsPlayerAlive(client))
		return Plugin_Continue;

	if ((buttons & IN_ATTACK) && TF2_GetPlayerClass(client) == TFClass_Medic)
	{
		int ent = GetClientAimTarget(client, true);
		int wep = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if (ent != -1 && IsValidEntity(wep) && TF2_GetPlayerClass(ent) == TFClass_Spy)
		{
			if (IsInRange(client, ent, MEDIGUN_RANGE, true))
			{
				SetEntProp(wep, Prop_Send, "m_hHealingTarget", ent);
				SetEntProp(wep, Prop_Send, "m_bHealing", 1);
				bBeingVaped[ent] = true;
			}
			else
			{
				SetEntProp(wep, Prop_Send, "m_hHealingTarget", -1);
				SetEntProp(wep, Prop_Send, "m_bHealing", 0);
				bBeingVaped[ent] = false;
			}
		}
		else if (ent == -1)
		{
			PrintToChatAll("losing");
			ent = GetEntPropEnt(wep, Prop_Send, "m_hHealingTarget");
			SetEntProp(wep, Prop_Send, "m_hHealingTarget", -1);
			SetEntProp(wep, Prop_Send, "m_bHealing", 0);
			if (ent != -1)
				bBeingVaped[ent] = false;
		}
	}
	return Plugin_Continue;
}

public void ManagePlayerThink(const int client)
{
	int wep;
	TFClassType class = TF2_GetPlayerClass(client);
	if (class == TFClass_Spy)
	{
		SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", 280.0);
		if (bBeingVaped[client])
			SDKHooks_TakeDamage(client, 0, 0, GetEntProp(client, Prop_Send, "m_nNumHealers")*4.0, DMG_PREVENT_PHYSICS_FORCE);
	}
	else if (class == TFClass_Medic)
	{
		SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", 300.0);
		wep = GetPlayerWeaponSlot(client, 1);
		SetEntPropFloat(wep, Prop_Send, "m_flChargeLevel", 0.0);
		int target = GetHealingTarget(client);
		if (target != -1 && TF2_GetPlayerClass(target) == TFClass_Spy)
		{
			RandomSlap(client);	
			if (!IsInRange(client, target, MEDIGUN_RANGE, false))
			{
				SetEntProp(wep, Prop_Send, "m_hHealingTarget", -1);
				SetEntProp(wep, Prop_Send, "m_bHealing", 0);
				bBeingVaped[target] = false;
			}
		}

	}
	else if (class == TFClass_Heavy)
	{
		SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", 260.0);
		if (GetEdictFlags(client) & FL_ONGROUND)
			bJumping[client] = false;

		if ((GetClientButtons(client) & IN_ATTACK2) && (flCharge[client] >= 0.0))
		{
			if (flCharge[client] + 1.25 < 25.0)
				flCharge[client] += 1.25;
			else flCharge[client] = 25.0;
		}
		else if (flCharge[client] < 0.0)
			flCharge[client] += 1.25;
		else 
		{
			float EyeAngles[3]; GetClientEyeAngles(client, EyeAngles);
			if ( flCharge[client] > 1.0 && EyeAngles[0] < -5.0 ) 
			{
				float vel[3]; GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel);
				vel[2] = 750 + flCharge[client] * 13.0;

				bJumping[client] = true;
				vel[0] *= (1+Sine(flCharge[client] * FLOAT_PI / 50));
				vel[1] *= (1+Sine(flCharge[client] * FLOAT_PI / 100));
				TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vel);
				flCharge[client] = -100.0;
			}
			else flCharge[client] = 0.0;
		}
		SetHudTextParams(-1.0, 0.77, 0.35, 255, 255, 255, 255);
		float jmp = flCharge[client];
		char s[32];
		if (jmp > 0.0)
		{
			jmp *= 4.0;
			s = "";
		}
		else if (jmp == 0.0)
			s = "\nHold Right-Click to Charge";
		ShowSyncHudText(client, hHudText, "Jump: %0.1f%s", jmp, s);
	}
}

public Action OnArenaRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (!bEnabled.BoolValue)
		return Plugin_Continue;

	int i;
	int q = 1;
	int u;

	float ratio;
	float balance = cvTeamRatio.FloatValue;
	float lBlue = float( GetLivingPlayers(3) );
	float lRed = float( GetLivingPlayers(2) );

	bool exact = !(GetLivingPlayers(0) % 2);

	if ((exact && lBlue != lRed) || (!exact && (lRed - lBlue == 1.0 || lBlue - lRed == 1.0)))
	{
		for (i = MaxClients; i; --i)
		{
			if (!IsClientInGame(i) || !IsPlayerAlive(i))
				continue;

			ratio = lBlue / lRed;

			if (ratio > balance)
			{
				u = GetRandomPlayer(3, true);
				ForceClientTeamChange(u, 2);

				lBlue--;	// Avoid loopception
				lRed++;
			}
			else if (balance > ratio)
			{
				u = GetRandomPlayer(2, true);
				ForceClientTeamChange(u, 3);

				lBlue++;	// Avoid loopception
				lRed--;
			}

			if (lBlue == lRed)
				break;

			if (!exact && (lRed - lBlue == 1.0 || lBlue - lRed == 1.0))
				break;
		}
	}

	for (i = MaxClients; i; --i)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i))
			continue;

		switch (GetClientTeam(i))
		{
			case 2:
			{
				if (TF2_GetPlayerClass(i) != TFClass_Medic)
					TF2_SetPlayerClass(i, TFClass_Medic);

				TF2Attrib_SetByDefIndex(i, 236, 1.0);
				CPrintToChat(i, "%s You are a Ghost Buster. Find and clean up all of the ghosts!", TAG);
			}
			case 3:
			{
				if (!(q % 2))
				{
					TF2_SetPlayerClass(i, TFClass_Spy);
					CPrintToChat(i, "%s You are a ghost. Escape the Ghost Busters!", TAG);
				}
				else
				{
					TF2_SetPlayerClass(i, TFClass_Heavy);
					CPrintToChat(i, "%s You are a zombie. Protect the ghosts and attack the Ghost Busters!", TAG);
				}
				q++;
			}
		}
		PrepPlayers(i);
	}

	g_iTimeLeft = cvRoundTime.IntValue;
	CreateTimer(1.0, Timer_Round, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	g_bActiveRound = true;
	return Plugin_Continue;
}

public Action OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (!bEnabled.BoolValue)
		return Plugin_Continue;

	int client = GetClientOfUserId(event.GetInt("userid"));

	if (0 < client <= MaxClients)
	{
		SetVariantString("");
		AcceptEntityInput(client, "SetCustomModel");
		TF2Attrib_RemoveAll(client);
		ResetVars(client);
	}
	return Plugin_Continue;
}

public Action OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (!bEnabled.BoolValue)
		return Plugin_Continue;

	g_bActiveRound = false;

	return Plugin_Continue;
}

public void PrepPlayers(const int client)
{
	TF2_RegeneratePlayer(client);
	int wep;
	TFClassType class = TF2_GetPlayerClass(client);
	if (class == TFClass_Medic)
	{
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_Primary);
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_Melee);
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_PDA);
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_Building);
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_Grenade);
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_Item1);
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_Item2);

		wep = GetPlayerWeaponSlot(client, 1);
		SetActive(client, wep);
	}
	else if (class == TFClass_Heavy)
	{
		TF2_RemoveAllWeapons(client);
		wep = TF2_SpawnWeapon(client, "tf_weapon_fists", 195, GetRandomInt(0, 100), 4, "5 ; 1.25 ; 1 ; 0.35 ; 57 ; 10.0");
		SetActive(client, wep);
	}
	else if (class == TFClass_Spy)
	{
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_Primary);
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_Secondary);
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_PDA);
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_Building);
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_Grenade);
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_Item1);
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_Item2);

		RemoveAll(client, false);

		if (!GetRandomInt(0, 1))
			SetVariantString(GhostModel1);
		else SetVariantString(GhostModel2);
		AcceptEntityInput(client, "SetCustomModel");

		wep = GetPlayerWeaponSlot(client, 2);
		SetActive(client, wep);
	}
}

stock int GetLivingPlayers(const int team)
{
	int living;
	for (int i = MaxClients ; i; --i)
		if (IsClientInGame(i) && IsPlayerAlive(i) && (team && GetClientTeam(i) == team))
			++living;
	return living;
}

stock void SetActive(const int client, const int wep)
{
	SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", wep);
}

stock void ForceClientTeamChange(const int client, const int iTeam)
{
	SetEntProp(client, Prop_Send, "m_lifeState", 2);
	ChangeClientTeam(client, iTeam);
	SetEntProp(client, Prop_Send, "m_lifeState", 0);
	TF2_RespawnPlayer(client);
}

stock int TF2_SpawnWeapon(const int client, char[] name, int index, int level, int qual, char[] att)
{
	Handle hWeapon = TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION);
	if (hWeapon == null)
		return -1;
	
	TF2Items_SetClassname(hWeapon, name);
	TF2Items_SetItemIndex(hWeapon, index);
	TF2Items_SetLevel(hWeapon, level);
	TF2Items_SetQuality(hWeapon, qual);
	char atts[32][32];
	int count = ExplodeString(att, " ; ", atts, 32, 32);
	count &= ~1;
	if (count > 0) {
		TF2Items_SetNumAttributes(hWeapon, count/2);
		int i2=0;
		for (int i=0 ; i<count ; i += 2) {
			TF2Items_SetAttribute(hWeapon, i2, StringToInt(atts[i]), StringToFloat(atts[i+1]));
			i2++;
		}
	}
	else TF2Items_SetNumAttributes(hWeapon, 0);

	int entity = TF2Items_GiveNamedItem(client, hWeapon);
	delete (hWeapon);
	EquipPlayerWeapon(client, entity);
	return entity;
}

stock int GetHealingTarget(const int client)
{
	int medigun = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
	if (!IsValidEntity(medigun))
		return -1;
	char s[32]; GetEdictClassname(medigun, s, sizeof(s));
	if (!strcmp(s, "tf_weapon_medigun", false))
		if (GetEntProp(medigun, Prop_Send, "m_bHealing") )
			return GetEntPropEnt( medigun, Prop_Send, "m_hHealingTarget");
	return -1;
}

stock void ForceTeamWin(int team = 0)
{
	int entity = FindEntityByClassname(-1, "team_control_point_master");
	if (entity <= 0)
	{
		entity = CreateEntityByName("team_control_point_master");
		DispatchSpawn(entity);
		AcceptEntityInput(entity, "Enable");
	}
	SetVariantInt(team);
	AcceptEntityInput(entity, "SetWinner");
}

stock bool IsInRange(const int entity, const int target, const float dist, bool pTrace = false)
{
	float entitypos[3]; GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", entitypos);
	float targetpos[3]; GetEntPropVector(target, Prop_Data, "m_vecAbsOrigin", targetpos);

	if (GetVectorDistance(entitypos, targetpos) <= dist)
	{
		if (!pTrace)
			return true;
		else 
		{
			TR_TraceRayFilter( entitypos, targetpos, MASK_SHOT, RayType_EndPoint, TraceRayDontHitSelf, entity );
			if (TR_GetFraction() > 0.98)
				return true;
		}
	}
	return false;
}

public bool TraceRayDontHitSelf(int ent, int mask, any data)
{
	return ent != data;
}

stock void RandomSlap(const int client) 
{
	float fEye[3];
	GetClientEyeAngles(client, fEye);
	fEye[0] += GetRandomFloat(-10.0,10.0) * 0.1;
	fEye[1] += GetRandomFloat(-10.0,10.0) * 0.1;
	fEye[2] += GetRandomFloat(-10.0,10.0) * 0.1;
	TeleportEntity(client, NULL_VECTOR, fEye, NULL_VECTOR);
}
// Pelipoika \o/
stock int GetHealerByIndex(int client, int index)
{
	int m_aHealers = FindSendPropInfo("CTFPlayer", "m_nNumHealers") + 12;

	Address m_Shared = GetEntityAddress(client) + view_as<Address>(m_aHealers);
	Address aHealers = view_as<Address>(LoadFromAddress(m_Shared, NumberType_Int32));

	return (LoadFromAddress(aHealers + view_as<Address>(index * 0x24), NumberType_Int32) & 0xFFF);
}

stock int GetRandomPlayer(int team = 0, bool alive = false)
{
	int[] clients = new int[MaxClients];  
	int clientCount;  
	for (int i = MaxClients; i; --i)  
	{
		if (!IsClientInGame(i))
			continue;
		if (team && GetClientTeam(i) != team)
			continue;
		if (alive && !IsPlayerAlive(i))
			continue;
		clients[clientCount++] = i;
	}
	return (clientCount == 0) ? -1 : clients[GetRandomInt(0, clientCount - 1)];
}

stock void RemoveAll(const int client, bool weps = true)
{
	TF2_RemovePlayerDisguise(client);
	int ent = -1;
	while ((ent = FindEntityByClassname(ent, "tf_wearabl*")) != -1)
	{
		if (GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity") == client) 
		{
			TF2_RemoveWearable(client, ent);
			AcceptEntityInput(ent, "Kill");
		}
	}
	ent = -1;
	while ((ent = FindEntityByClassname(ent, "tf_powerup_bottle")) != -1)
	{
		if (GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity") == client) 
		{
			TF2_RemoveWearable(client, ent);
			AcceptEntityInput(ent, "Kill");
		}
	}
	if (weps)
		TF2_RemoveAllWeapons(client);
}