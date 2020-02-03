#include <sourcemod>
#include <sdktools>
#include <morecolors>

StringMap
	hTheShit
;

enum struct HammerEV {
	int ID;
	char Func[32];
}

ArrayList
	hHammerIDs
;

public void OnPluginStart()
{
	RegAdminCmd("sm_mapdebug", CmdDebug, ADMFLAG_GENERIC, "Debug a map's validation status");
	RegAdminCmd("sm_validatemap", CmdDoCfg, ADMFLAG_CONFIG, "Run a map's validation cfg");
	hHammerIDs = new ArrayList(sizeof(HammerEV));
	hTheShit = new StringMap();

	HookEvent("teamplay_round_start", DoTheseThings, EventHookMode_Pre);
}

public Action DoTheseThings(Event event, const char[] name, bool dontBroadcast)
{
	if (hTheShit.Size)
	{
		StringMapSnapshot snap = hTheShit.Snapshot();
		if (snap)
		{
			char[][] classnames = new char[snap.Length][32];
			char[][] funcs = new char[snap.Length][32];
			int i, u;
			for (i = 0; i < snap.Length; ++i)
			{
				snap.GetKey(i, classnames[i], 32);
				hTheShit.GetString(classnames[i], funcs[i], 32);
			}

			for (i = 0; i < snap.Length; ++i)
			{
				u = -1;
				while ((u = FindEntityByClassname(u, classnames[i])) != -1)
				{
					if (IsValidEntity(u))
					{
						SetVariantInt(1);
						AcceptEntityInput(u, funcs[i]);
					}
				}
			}

			delete snap;
		}
	}
	if (hHammerIDs.Length)
	{
		int[] ids = new int[hHammerIDs.Length];
		char[][] funcs = new char[hHammerIDs.Length][32];
		HammerEV val;
		int i, u;
		for (i = 0; i < hHammerIDs.Length; ++i)
		{
			hHammerIDs.GetArray(i, val, sizeof(HammerEV));
			ids[i] = val.ID;
			strcopy(funcs[i], 32, val.Func);
		}

		i = -1;
		while ((i = FindEntityByClassname(i, "*")) != -1)
		{
			for (u = 0; u < hHammerIDs.Length; ++u)
				if (GetEntProp(i, Prop_Data, "m_iHammerID", 4, 0) == ids[u])
				{
					SetVariantInt(1);
					AcceptEntityInput(i, funcs[u]);
				}
		}
	}
}

public void OnMapStart()
{
	hHammerIDs.Clear();
	hTheShit.Clear();

	char cfg[PLATFORM_MAX_PATH]; 
	BuildPath(Path_SM, cfg, PLATFORM_MAX_PATH, "configs/mapvalidator.cfg");

	if (!FileExists(cfg))
	{
		LogError("No Map cfg at '%s'", cfg);
		return;
	}

	KeyValues kv = new KeyValues("Map Validation");
	if (!kv.ImportFromFile(cfg))
	{
		LogError("Invalid file at '%s'", cfg);
		delete kv;
		return;
	}

	char map[64]; GetCurrentMap(map, sizeof(map));
	if (kv.JumpToKey(map))
	{
		if (kv.JumpToKey("Classnames"))
		{
			if (kv.GotoFirstSubKey(false))
			{
				char func[32];
				char classname[32];
				do
				{
					kv.GetSectionName(classname, sizeof(classname));
					PrintToChatAll(classname);
					kv.GetString(NULL_STRING, func, sizeof(func));
					PrintToChatAll(func);
					hTheShit.SetString(classname, func);
				}	while kv.GotoNextKey(false);
			}
		}
		if (kv.JumpToKey("Hammer IDs"))
		{
			if (kv.GotoFirstSubKey(false))
			{
				char buff[32];
				HammerEV eval;
				do
				{
					kv.GetSectionName(buff, sizeof(buff));
					kv.GetString(NULL_STRING, eval.Func, sizeof(eval.Func));
					eval.ID = StringToInt(buff);
					if (eval.ID <= 0)
						continue;

					hHammerIDs.PushArray(eval);
				}	while kv.GotoNextKey(false);				
			}
		}
	}
	delete kv;
}

public Action CmdDebug(int client, int args)
{
	CReplyToCommand(client, "{lightcoral}[OPST]{default} Check console for output.");
	PrintToConsole(client, "********ENTITIES********");
	if (hTheShit.Size)
	{
		PrintToConsole(client, "Name\t\t\tFunc");
		StringMapSnapshot snap = hTheShit.Snapshot();
		if (snap)
		{
			char s[32], s2[32];
			for (int i = 0; i < snap.Length; ++i)
			{
				snap.GetKey(i, s, sizeof(s));
				hTheShit.GetString(s, s2, sizeof(s2));
				PrintToConsole(client, "%s\t\t%s", s, s2);
			}
			delete snap;
		}
	}
	if (hHammerIDs.Length)
	{
		PrintToConsole(client, "********HAMMER IDS********")
		PrintToConsole(client, "ID\t\t\tFunc");
		HammerEV val;
		for (int i = 0; i < hHammerIDs.Length; ++i)
		{
			hHammerIDs.GetArray(i, val, sizeof(HammerEV));
			PrintToConsole(client, "%d\t\t\t%s", val.ID, val.Func);
		}
	}
	return Plugin_Handled;
}

public Action CmdDoCfg(int client, int args)
{
	CReplyToCommand(client, "{lightcoral}[OPST]{default} Running map validation config");
	OnMapStart();
}