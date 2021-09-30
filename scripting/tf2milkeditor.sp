#pragma semicolon 1
#pragma newdecls required

#include <smmem>

Address g_Ptr;
Address g_Addr;
Address g_Old;

ConVar cvMilk;

public void OnPluginStart()
{
	GameData conf = LoadGameConfigFile("tf2.milk");
	g_Addr = conf.GetAddress("ApplyOnHitAttributes");
	g_Addr += view_as< Address >(conf.GetOffset("Milk_Offset"));
	g_Old = Deref(g_Addr);
	delete conf;

	cvMilk = CreateConVar("sm_milk_pct", "0.5", "Milk damage to health %", FCVAR_NOTIFY);
	cvMilk.AddChangeHook(OnMilkCVarChange);
	AutoExecConfig(true, "TF2Milk");
	Patch();
}

public void OnMilkCVarChange(ConVar convar, const char[] old, const char[] neww)
{
	Patch();
}

public void Patch()
{
	if (!g_Ptr)
		g_Ptr = malloc(cellbytes);

	WriteVal(g_Ptr, cvMilk.FloatValue);
	WriteVal(g_Addr, g_Ptr);
}

public void OnPluginEnd()
{
	WriteVal(g_Addr, g_Old);
	free(g_Ptr);
}