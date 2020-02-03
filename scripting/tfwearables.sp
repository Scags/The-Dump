#include <sdkhooks>

public void OnPluginStart()
{
	for (int i = MaxClients; i; --i)
		if (IsClientInGame(i))
			OnClientPutInServer(i);
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_PreThink, OnThink);
}

public void OnThink(int client)
{
	for (int i = 0; i < TF2_GetNumWearables(client); ++i)
	{
		int wearable = TF2_GetWearable(client, i);
		char buf[32]; GetEntityClassname(wearable, buf, sizeof(buf));
		PrintToChat(client, "%d | %s", wearable, buf);
	}
}

stock int TF2_GetNumWearables(int client)
{
	// 3552 linux
	// 3532 windows
	int offset = FindSendPropInfo("CTFPlayer", "m_flMaxspeed") - 20 + 12;
	return GetEntData(client, offset);
}

stock int TF2_GetWearable(int client, int wearableidx)
{
	// 3540 linux
	// 3520 windows
	int offset = FindSendPropInfo("CTFPlayer", "m_flMaxspeed") - 20;
	Address m_hMyWearables = view_as< Address >(LoadFromAddress(GetEntityAddress(client) + view_as< Address >(offset), NumberType_Int32));
	return LoadFromAddress(m_hMyWearables + view_as< Address >(4 * wearableidx), NumberType_Int32) & 0xFFF;
}