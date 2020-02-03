public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	RegAdminCmd("sm_getinterp", CmdInterp, ADMFLAG_GENERIC);
}

public Action CmdInterp(int client, int args)
{
	if (client && args)
	{
		char arg[32]; GetCmdArg(1, arg, sizeof(arg));
		int target = FindTarget(client, arg);
		if (target >= 1)
			QueryClientConVar(target, "cl_interp", OnGetInterp, GetClientUserId(client));
	}
	return Plugin_Handled;
}

public void OnGetInterp(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue, any value)
{
	int client2 = GetClientOfUserId(value);
	if (!client2)
		return;

	if (result != ConVarQuery_Okay)
		PrintToChat(client2, "[SM] Unable to get cl_interp value of %N! Error %d", client, result);
	else PrintToChat(client2, "[SM] cl_interp value of %N: %s", client, cvarValue);

}