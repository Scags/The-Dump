#include <tf2_stocks>
#include <sdkhooks>
#include <sdktools>

Handle hud;

public void OnPluginStart()
{
	for (int i = MaxClients; i; --i)
		if (IsClientInGame(i))
			OnClientPutInServer(i);

	hud = CreateHudSynchronizer();
}

public void OnClientPutInServer(int client)
{
	if (!IsFakeClient(client))
		SDKHook(client, SDKHook_PreThink, OnThink);
}

public void OnThink(int client)
{
	int count = TF2_GetObjectCount(client);
	char buffer[256];
	for (int i = 0; i < count; ++i)
	{
		int obj = TF2_GetObject(client, i);
		char buf[32]; GetEntityClassname(obj, buf, sizeof(buf));
		Format(buffer, sizeof(buffer), "%s\n%s | %d", buffer, buf, obj);
	}

	SetHudTextParams(0.6, 0.0, 0.35, 90, 255, 90, 255, 0, 0.35, 0.0, 0.1);
	ShowSyncHudText(client, hud, buffer);
}

#define BUILDING_MODE_ANY view_as< TFObjectMode >(-1)

// CTFPlayer::GetObjectCount()
stock int TF2_GetObjectCount(int client)
{
	// CUtlVector<CBaseObject*, CUtlMemory<CBaseObject*, int>>
	return GetEntData(client, FindSendPropInfo("CTFPlayer", "m_flMvMLastDamageTime") + 48 + 12);
}

// CTFPlayer::GetObject(int)
stock int TF2_GetObject(int client, objidx)
{
	//8568 linux
	//8560 windows
	int offset = FindSendPropInfo("CTFPlayer", "m_flMvMLastDamageTime") + 48;
	Address m_aObjects = view_as< Address >(LoadFromAddress(GetEntityAddress(client) + view_as< Address >(offset), NumberType_Int32));
	return LoadFromAddress(m_aObjects + view_as< Address >(4 * objidx), NumberType_Int32) & 0xFFF;
}

// CTFPlayer::GetObjectOfType(int, int)
stock int TF2_GetObjectOfType(int client, TFObjectType objtype, TFObjectMode objmode = TFObjectMode_None, bool incdisposables = false)
{
	int numobjs = TF2_GetObjectCount(client);
	for (int i = 0; i < numobjs; ++i)
	{
		int obj = TF2_GetObject(client, i);
		if (!obj)
			continue;

		if (TF2_GetObjectType(obj) != objtype)
			continue;

		if (TF2_GetObjectMode(obj) != objmode)
			continue;

		if (!incdisposables && GetEntProp(obj, Prop_Send, "m_bDisposableBuilding"))
			continue;

		return obj;
	}
	return -1;
}

// CTFPlayer::GetNumObjects(int, int)
stock int TF2_GetNumObjects(int client, TFObjectType objtype, TFObjectMode objmode, bool incdisposables = false)
{
	int count;
	int objcount = TF2_GetObjectCount(client);
	for (int i = 0; i < objcount; ++i)
	{
		int obj = TF2_GetObject(client, i);
		if (!obj)
			continue;

		if (!incdisposables && GetEntProp(obj, Prop_Send, "m_bDisposableBuilding"))
			continue;

		if (TF2_GetObjectType(obj) == objtype && (objmode == BUILDING_MODE_ANY || TF2_GetObjectMode(objmode) == objmode))
			++count;
	}
	return count;
}
