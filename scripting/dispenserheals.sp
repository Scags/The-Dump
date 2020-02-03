#include <sdktools>

public void OnGameFrame()
{
	int ent = MaxClients+1;
	while ((ent = FindEntityByClassname(ent, "obj_dispenser")) != -1)
	{
		int owner = GetEntPropEnt(ent, Prop_Send, "m_hBuilder");
		if (!(0 < owner <= MaxClients))
			continue;

		int targets = TF2_GetDispenserNumHealTargets(ent);
		for (int i = 0; i < targets; ++i)
		{
			int target = TF2_GetDispenserHealTarget(ent, i);
			PrintToChatAll("Dispenser %d (owner %N) healing %N", ent, owner, target);
		}
	}
}

stock int TF2_GetDispenserNumHealTargets(int dispenser)
{
	int offset = FindSendPropInfo("CObjectDispenser", "m_iState") - 20 + 12;
	return GetEntData(dispenser, offset);
}
stock int TF2_GetDispenserHealTarget(int dispenser, int idx)
{
	int offset = FindSendPropInfo("CObjectDispenser", "m_iState") - 20;
	Address m_hHealingTargets = view_as< Address >(LoadFromAddress(GetEntityAddress(dispenser) + view_as< Address >(offset), NumberType_Int32));
	return LoadFromAddress(m_hHealingTargets + view_as< Address >(4 * idx), NumberType_Int32) & 0xFFF;
}
