#pragma semicolon 1

#define PLUGIN_AUTHOR "Ragenewb"
#define PLUGIN_VERSION "1.0"

#include <sourcemod>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "Map Prioritizer",
	author = PLUGIN_AUTHOR,
	description = "After some time of no players being on a map, switch to a more popular one",
	version = PLUGIN_VERSION,
	url = ""
};

public void OnPluginStart()
{
	CreateTimer(600.0, Timer_ForceMap, TIMER_REPEAT, TIMER_FLAG_NO_MAPCHANGE);
}

/*public void OnClientDisconnect(int client)
{
	if (GetClientCount() <= 0)
		CreateTimer(300.0, Timer_ForceMap, TIMER_REPEAT, TIMER_FLAG_NO_MAPCHANGE);
}*/
// sv_hibernate_when_empty 0
public Action Timer_ForceMap(Handle timer)
{
	if (GetClientCount() <= 0) {
		int rand = GetRandomInt(1, 8);
		switch (rand) {
			case 1: { 
				ForceChangeLevel("vsh_crevice_b5", "[SM] Map Priority");
				PrintToServer("[SM] Force-Changing to vsh_crevice_b5");
			}
			case 2: {
				ForceChangeLevel("vsh_dust_showdown_final1", "[SM] Map Priority");
				PrintToServer("[SM] Force-Changing to vsh_dust_showdown_final1");
			}
			case 3: {
				ForceChangeLevel("vsh_militaryzone_v2b", "[SM] Map Priority");
				PrintToServer("[SM] Force-Changing to vsh_militaryzone_v2b");
			}
			case 4: {
				ForceChangeLevel("vsh_minegay_b3", "[SM] Map Priority");
				PrintToServer("[SM] Force-Changing to vsh_minegay_b3");
			}
			case 5: {
				ForceChangeLevel("vsh_remains_of_king_b1", "[SM] Map Priority");
				PrintToServer("[SM] Force-Changing to vsh_remains_of_king_b1");
			}
			case 6: {
				ForceChangeLevel("vsh_2fortdesk_v8", "[SM] Map Priority");
				PrintToServer("[SM] Force-Changing to vsh_2fortdesk_v8");
			}
			case 7: {
				ForceChangeLevel("vsh_arrival_v3", "[SM] Map Priority");
				PrintToServer("[SM] Force-Changing to vsh_arrival_v3");
			}
			case 8: {
				ForceChangeLevel("vsh_minecube_v2", "[SM] Map Priority");
				PrintToServer("[SM] Force-Changing to vsh_minecube_v2");
			}
		}
	}
	return Plugin_Continue;
}