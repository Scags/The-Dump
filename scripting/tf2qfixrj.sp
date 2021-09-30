#include <sourcemod>
#include <sdkhooks>
#include <tf2_stocks>
#include <dhooks>

#define PLUGIN_VERSION	"1.0.0"

#if 0
class CTakeDamageInfo
{
	Vector			m_vecDamageForce;
	Vector			m_vecDamagePosition;
	Vector			m_vecReportedPosition;	// Position players are told damage is coming from
	EHANDLE			m_hInflictor;
	EHANDLE			m_hAttacker;
	EHANDLE			m_hWeapon;
	float			m_flDamage;
	float			m_flMaxDamage;
	float			m_flBaseDamage;			// The damage amount before skill leve adjustments are made. Used to get uniform damage forces.
	int				m_bitsDamageType;
	int				m_iDamageCustom;
	int				m_iDamageStats;
	int				m_iAmmoType;			// AmmoType of the weapon used to cause this damage, if any
	int				m_iDamagedOtherPlayers;
	int				m_iPlayerPenetrationCount;
	float			m_flDamageBonus;		// Anything that increases damage (crit) - store the delta
	EHANDLE			m_hDamageBonusProvider;	// Who gave us the ability to do extra damage?
	bool			m_bForceFriendlyFire;	// Ideally this would be a dmg type, but we can't add more
	int 			m_nCritType;

	float			m_flDamageForForce;
}

class CTFRadiusDamageInfo
{
	CTakeDamageInfo	m_pInfo;
	Vector 			m_vecSrc;
	float 			m_flRadius;
	int 			m_iClassIgnore;
	CBaseEntity 	m_pEntityIgnore;
}
#endif

enum CTFRadiusDamageInfo (+= 4)
{
	__m_vecDamageForce,
	__m_vecDamagePosition = 12,
	__m_vecReportedPosition = 24,
	__m_hInflictor = 36,
	__m_hAttacker,
	__m_hWeapon,
	__m_flDamage,
	__m_flMaxDamage,
	__m_flBaseDamage,
	__m_bitsDamageType,
	__m_iDamageCustom,
	__m_iDamageStats,
	__m_iAmmoType,
	__m_iDamagedOtherPlayers,
	__m_iPlayerPenetrationCount,
	__m_flDamageBonus,
	__m_hDamageBonusProvider,	// Everything below here is probs wrong but w/e
	__m_bForceFriendlyFire,
	__m_flDamageForForce = 93,
	__m_nCritType,

	__m_vecSrc,
	__m_flRadius = 113,
	__m_iClassIgnore,
	__m_pEntityIgnore
};

public Plugin myinfo =  {
	name = "TF2 Quickfix Blast Jump Fix", 
	author = "Scag", 
	description = "Lets Soldiers/Demomen blast away when ubercharged with the Quickfix", 
	version = PLUGIN_VERSION, 
	url = ""
};

public void OnPluginStart()
{
	GameData conf = new GameData("tf2.qfixrj");
	Handle hook = DHookCreateFromConf(conf, "CTFRadiusDamageInfo::ApplyToEntity");
	if (!DHookEnableDetour(hook, false, CTFRadiusDamageInfo_ApplyToEntity))
		SetFailState("Could not enable detour for CTFRadiusDamageInfo::ApplyToEntity!");

	hook = DHookCreateFromConf(conf, "CalculateExplosiveDamageForce");
	if (!DHookEnableDetour(hook, true, CalculateExplosiveDamageForce))
		SetFailState("Could not enable detour for CalculateExplosiveDamageForce!");

	delete conf;
}

float fuck[3];
bool yea;
public MRESReturn CTFRadiusDamageInfo_ApplyToEntity(Address pThis, Handle hParams)
{
	int victim = DHookGetParam(hParams, 1);

	if (LoadFromAddress(pThis + view_as< Address >(__m_hAttacker), NumberType_Int32) == victim 
	&& TF2_IsPlayerInCondition(victim, TFCond_MegaHeal) 
	&& (LoadFromAddress(pThis + view_as< Address >(__m_bitsDamageType), NumberType_Int32) & DMG_BLAST) 
	&& LoadFromAddress(pThis + view_as< Address >(__m_hWeapon), NumberType_Int32) == GetPlayerWeaponSlot(victim, TF2_GetPlayerClass(victim) == TFClass_Soldier ? 0 : 1))
	{
		fuck[0] = view_as< float >(LoadFromAddress(pThis + view_as< Address >(__m_vecDamageForce), NumberType_Int32));
		fuck[1] = view_as< float >(LoadFromAddress(pThis + view_as< Address >(__m_vecDamageForce) + view_as< Address >(0x04), NumberType_Int32));
		fuck[2] = view_as< float >(LoadFromAddress(pThis + view_as< Address >(__m_vecDamageForce) + view_as< Address >(0x08), NumberType_Int32));
		yea = true;
	}
	return MRES_Ignored;
}

public MRESReturn CalculateExplosiveDamageForce(Handle hParams)
{
	if (yea)
	{
		DHookSetParamVector(2, fuck);
		yea = false;
		return MRES_ChangedHandled;
	}
	return MRES_Ignored;
}
