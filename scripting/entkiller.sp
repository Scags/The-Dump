#include <sdktools>
#include <sdkhooks>
#include <morecolors>

StringMap
	hMap
;

public void OnPluginStart()
{
	RegAdminCmd("sm_kcfg", RunCFG, ADMFLAG_CONFIG);
	hMap = new StringMap();
}

public Action RunCFG(int client, int args)
{
	OnMapStart();
	CReplyToCommand(client, "{lightcoral}[OPST]{default} Running map validation config");
}

public void OnMapStart()
{
	hMap.Clear();

	char cfg[PLATFORM_MAX_PATH]; 
	BuildPath(Path_SM, cfg, PLATFORM_MAX_PATH, "configs/entkiller.cfg");

	if (!FileExists(cfg))
	{
		LogError("No Map cfg at '%s'", cfg);
		return;
	}

	KeyValues kv = new KeyValues("Ent Killer");
	if (!kv.ImportFromFile(cfg))
	{
		LogError("Invalid file at '%s'", cfg);
		delete kv;
		return;
	}

	char map[64]; GetCurrentMap(map, sizeof(map));
	if (kv.JumpToKey(map))
	{
		if (kv.GotoFirstSubKey(false))
		{
			char classname[32];
			do
			{
				kv.GetSectionName(classname, sizeof(classname));
				if (kv.GetNum(NULL_STRING))
				{
					hMap.SetValue(classname, 1);
					//PrintToChatAll("%s", classname);
				}
			}	while kv.GotoNextKey(false);
		}
	}
	delete kv;
}

public void OnEntityCreated(int ent, const char[] classname)
{
	any idk;
	if (hMap.GetValue(classname, idk))
		SDKHook(ent, SDKHook_Spawn, KillOnSpawn);
}

public Action KillOnSpawn(int ent)
{
	RemoveEntity(ent);
	return Plugin_Handled;
}