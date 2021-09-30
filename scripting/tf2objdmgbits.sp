#include <smmem>
#include <smmem_stocks>

#define PLUGIN_VERSION 	"1.0.0"

public Plugin myinfo =  {
	name = "[TF2] Object Event damagebits", 
	author = "Scags", 
	description = "Implements damagebits into TF2's object_destroyed event", 
	version = PLUGIN_VERSION, 
	url = "https://github.com/Scags?tab=repositories"
};

static const char[] g_DmgBits = "dmgbits";

ptr g_Jmp;
ptr g_Old;
ptr g_StartAddr;

static const int[] the_shit = {
	// For replaced jump bytes
	0x00, 0x00, 0x00, 0x00, 0x00,
	0x8B, 0x06,											// mov     eax, [esi]
	0x8b, 0x55, 0x0c,									// mov     edx, dword ptr [ebp+Ch]
	0x8b, 0x52, 0x3c, 									// mov     edx, dword ptr [edx+3Ch]
	0xC7, 0x44, 0x24, 0x08, 0x06, 0x00, 0x00, 0x00,		// mov     dword ptr [esp+8], edx
	// Address load starts at 25
	0xC7, 0x44, 0x24, 0x04, 0x00, 0x00, 0x00, 0x00,		// mov     dword ptr [esp+4], offset g_DmgBits
	0x89, 0x34, 0x24,									// mov     [esp], esi
	0xFF, 0x50, 0x2C,									// call    dword ptr [eax+2Ch]
	// Jump starts at 36
	0xe9, 0x00, 0x00, 0x00, 0x00 						// jmp     0xBADF000D
};

#define JMP_SIZE 5

#define OFFS_BITS 25
#define OFFS_JMP 36

public void OnPluginStart()
{
	GameData conf = new GameData("tf2.objdmgbits");
	g_StartAddr = conf.GetAddress("CBaseObject::Killed");

	g_Old = malloc(cellbytes * JMP_SIZE);
	g_Jmp = ArrayToPtr(the_shit, sizeof(the_shit));
	WriteVal(g_Jmp + OFFS_BITS, AddressOfString(g_DmgBits));
	WriteVal(g_Jmp + OFFS_JMP, g_StartAddr + JMP_SIZE);
	CreateJmp(g_StartAddr, replace, JMP_SIZE, g_Old);

	delete conf;
}

public void OnPluginEnd()
{
	MemCopy(g_StartAddr, g_Old, JMP_SIZE);
	Free(g_Old);
	Free(g_Jmp);
}