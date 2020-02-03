#include <sourcemod>
#include <morecolors>

#pragma semicolon 1
#pragma newdecls required

ArrayList hDisplays;
ConVar cvTime, cvColor1, cvColor2;
int iIndex[MAXPLAYERS+1];
int g_iCount;

public Plugin myinfo =
{
	name = "Trade Chat", 
	author = "Scag/Ragenewb", 
	description = "Add chat messages to a looping message displayer", 
	version = "1.0.0", 
	url = ""
};

public void OnPluginStart()
{
	cvTime = CreateConVar("sm_tradechat_interval", "60", "Message display interval", FCVAR_NOTIFY, true, 0.0);
	cvColor1 = CreateConVar("sm_tradechat_colorone", "darkblue", "Trade chat tag color. Consult https://www.doctormckay.com/morecolors.php ; Ignore brackets, leave blank for default color.", FCVAR_NOTIFY);
	cvColor2 = CreateConVar("sm_tradechat_colortwo", "haunted", "Trade chat tag color. Consult https://www.doctormckay.com/morecolors.php ; Ignore brackets, leave blank for default color.", FCVAR_NOTIFY);
	AutoExecConfig(true, "tradechat");
	RegConsoleCmd("sm_t", cmdTrade);
	RegAdminCmd("sm_cleartrade", cmdClearTrade, ADMFLAG_GENERIC);
	hDisplays = new ArrayList(ByteCountToCells(128));

	for (int i = MaxClients; i; --i)
		if (IsClientInGame(i))
			OnClientPutInServer(i);
}

public void OnMapStart()
{
	CreateTimer(cvTime.FloatValue, ChatCallback, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	g_iCount = 0;
}

public void OnClientPutInServer(int client)
{
	iIndex[client] = -1;
}

public void OnClientDisconnect(int client)
{
	if (iIndex[client] > -1)
	{
		hDisplays.Erase(iIndex[client]);
		for (int i = MaxClients; i; --i)
		{
			if (!IsClientInGame(i) || i == client)
				continue;

			if (iIndex[i] <= iIndex[client])
				continue;

			iIndex[i]--;
		}
		g_iCount--;
	}
	iIndex[client] = -1;
}

public Action cmdTrade(int client, int args)
{
	if (!client)
		return Plugin_Handled;

	if (!args)
	{
		ReplyToCommand(client, "[SM] Usage: !t <trade message>.");
		return Plugin_Handled;
	}

	bool newchat;
	char arg[128]; GetCmdArgString(arg, sizeof(arg));
	if (iIndex[client] > -1)
	{
		hDisplays.Erase(iIndex[client]);
		for (int i = MaxClients; i; --i)
		{
			if (!IsClientInGame(i) || i == client)
				continue;

			if (iIndex[i] <= iIndex[client])
				continue;

			iIndex[i]--;
		}
		newchat = true;
	}

	hDisplays.PushString(arg);
	iIndex[client] = hDisplays.Length-1;

	char color1[32], color2[32];
	cvColor1.GetString(color1, sizeof(color1));
	cvColor2.GetString(color2, sizeof(color2));
	if (color1[0] == '\0')
		color1 = "default";
	if (color2[0] == '\0')
		color2 = "default";

	CPrintToChat(client, "{%s}[Trade Chat]{default} Your %strade message is: {%s}%s", color1, (newchat ? "new " : ""), color2, arg);
	return Plugin_Handled;
}

public Action cmdClearTrade(int client, int args)
{
	hDisplays.Clear();
	for (int i = MaxClients; i; --i)
		iIndex[i] = -1;

	char color1[32], color2[32];
	cvColor1.GetString(color1, sizeof(color1));
	cvColor2.GetString(color2, sizeof(color2));
	if (color1[0] == '\0')
		color1 = "default";
	if (color2[0] == '\0')
		color2 = "default";

	CPrintToChatAll("{%s}[Trade Chat]{%s} Trade chat has been cleared.", color1, color2);
	return Plugin_Handled;
}

public Action ChatCallback(Handle timer)
{
	int len = hDisplays.Length;
	if (!len)
		return Plugin_Continue;

	if (g_iCount < 0)
		g_iCount = 0;

	char msg[128]; hDisplays.GetString(g_iCount, msg, sizeof(msg));
	int client;
	if ((client = FindTrader()) == -1)
		return Plugin_Continue;
	g_iCount++;
	if (msg[0] == '\0')	// ???
		return Plugin_Continue;

	char color1[32], color2[32];
	cvColor1.GetString(color1, sizeof(color1));
	cvColor2.GetString(color2, sizeof(color2));
	if (color1[0] == '\0')
		color1 = "default";
	if (color2[0] == '\0')
		color2 = "default";

	CPrintToChatAll("{%s}[Trade Chat]{default} %N: {%s}%s", color1, client, color2, msg);
	if (g_iCount >= len)
		(g_iCount = 0);

	return Plugin_Continue;
}

stock int FindTrader()
{
	for (int i = MaxClients; i; --i)
		if (IsClientInGame(i) && iIndex[i] == g_iCount)
			return i;
	return -1;
}