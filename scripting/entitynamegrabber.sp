#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

bool bSeeing[MAXPLAYERS+1];

Handle hHud;

public void OnPluginStart()
{
	RegAdminCmd("sm_seenames", CmdGetName, ADMFLAG_GENERIC);

	HookEvent("player_death", OnDied);

	hHud = CreateHudSynchronizer();

	for (int i = MaxClients; i; --i)
		if (IsClientInGame(i))
			OnClientPutInServer(i);
}

public void OnClientPutInServer(int client)
{
	bSeeing[client] = false;

	SDKHook(client, SDKHook_PostThink, OnThink);
}

public void OnDied(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (bSeeing[client])
	{
		PrintToChat(client, "[SM] You will no longer see entity data because you died.");
		bSeeing[client] = false;
	}
}

public Action CmdGetName(int client, int args)
{
	if (!client)
		return Plugin_Handled;
	if (!IsPlayerAlive(client))
	{
		PrintToChat(client, "[SM] You must be alive.");
		return Plugin_Handled;
	}

	if (!bSeeing[client])
	{
		bSeeing[client] = true;
		PrintToChat(client, "[SM] Look at entities to see their data.");
	}
	else
	{
		bSeeing[client] = false;
		PrintToChat(client, "[SM] You will no longer see entity data.");
	}
	return Plugin_Handled;
}

public void OnThink(int client)
{
	if (!bSeeing[client])
		return;
	if (!IsPlayerAlive(client))
		return;

	float StartOrigin[3], Angles[3];
	GetClientEyeAngles(client, Angles);
	GetClientEyePosition(client, StartOrigin);

	TR_TraceRayFilter(StartOrigin, Angles, MASK_SHOT, RayType_Infinite, TRACE, client);
}

public bool TRACE(int ent, int mask, any data)
{
	if (ent == data)
		return false;

	if (0 < ent <= 4096)
	{
		if (!IsValidEntity(ent))
			return true;

		char s[512];
		if (!GetEntityClassname(ent, s, 256))
			strcopy(s, 256, "-----");

		Format(s, sizeof(s), "%s\nIndex: %d", s, ent);
		if (!HasEntProp(ent, Prop_Data, "m_iName"))
			Format(s, sizeof(s), "%s\n-----\n", s);
		else
		{
			char others[32];
			GetEntPropString(ent, Prop_Data, "m_iName", others, 32);
			Format(s, sizeof(s), "%s\nName: %s", s, others);
		}

		if (HasEntProp(ent, Prop_Data, "m_iHammerID"))
			Format(s, sizeof(s), "%s\nHammer ID: %d", s, GetEntProp(ent, Prop_Data, "m_iHammerID"));

		SetHudTextParams(0.7, 0.7, 0.1, 255, 100, 255, 255, 1);
		ShowSyncHudText(data, hHud, s);
	}
	return true;
}