namespace Side {

/*
 * Register factions
 */
	TypeMask ARMADA = aiSideMasker.GetTypeMask("armada");
	TypeMask CORTEX = aiSideMasker.GetTypeMask("cortex");
	TypeMask LEGION;

}  // namespace Side

namespace Init {

const float WALL_THREAT_KERNEL = 0.01f;

	SCategoryInfo InitCategories()
	{
		SCategoryInfo category;
		category.air   = "VTOL NOTSUB";
		category.land  = "SURFACE NOTSUB";
		category.water = "UNDERWATER NOTHOVER";
		category.bad   = "MINE";
		category.good  = "";
		return category;
	}

	SArmorInfo InitArmordef()
	{
		// NOTE: Intentionally unsorted as it is in bar.sdd/gamedata/armordefs.lua
		//       Replicates engine's string<=>int assignment
		//       Must not include "default" keyword
		array<string> armors = {
			"commanders",
			"scavboss",
			"indestructable",
			"crawlingbombs",
			"walls",
			"standard",
			"space",
			"mines",
			"nanos",
			"vtol",
			"shields",
			"lboats",
			"hvyboats",
			"subs",
			"raptor"
		};
		armors.sortAsc();
		armors.insertAt(0, "default");

		dictionary armorTypes;
		for (uint i = 0; i < armors.length(); ++i) {
			armorTypes[armors[i]] = i;
		}

		array<string> airTypes = {"vtol"};
		array<string> surfaceTypes = {"default"};
		array<string> waterTypes = {"subs"};

		SArmorInfo armor;
		for (uint i = 0; i < airTypes.length(); ++i) {
			armor.AddAir(int(armorTypes[airTypes[i]]));
		}
		for (uint i = 0; i < surfaceTypes.length(); ++i) {
			armor.AddSurface(int(armorTypes[surfaceTypes[i]]));
		}
		for (uint i = 0; i < waterTypes.length(); ++i) {
			armor.AddWater(int(armorTypes[waterTypes[i]]));
		}
		return armor;
	}
	

void SetFireStateForUnits(const array<string>& in units, int fireState)
{
	for (uint i = 0; i < units.length(); ++i) {
		CCircuitDef@ cdef = ai.GetCircuitDef(units[i]);
		if (cdef is null) {
			@cdef = ai.GetCircuitDef(units[i].toLower());
		}
		if (cdef !is null) {
			cdef.SetFireState(fireState);
		}
	}
}

void AddAttributeForUnits(const array<string>& in units, int attr)
{
	for (uint i = 0; i < units.length(); ++i) {
		CCircuitDef@ cdef = ai.GetCircuitDef(units[i]);
		if (cdef is null) {
			@cdef = ai.GetCircuitDef(units[i].toLower());
		}
		if (cdef !is null) {
			cdef.AddAttribute(attr);
		}
	}
}

void EnableStaticWallPressure()
{
	const uint staticPressureRolesMask = Unit::Role::RAIDER.mask
		| Unit::Role::RIOT.mask
		| Unit::Role::ASSAULT.mask
		| Unit::Role::SKIRM.mask
		| Unit::Role::ARTY.mask
		| Unit::Role::AA.mask
		| Unit::Role::AH.mask
		| Unit::Role::SUPER.mask
		| Unit::Role::STATIC.mask;

	int staticDefsTuned = 0;
	for (Id defId = 1, count = ai.GetDefCount(); defId <= count; ++defId) {
		CCircuitDef@ def = ai.GetCircuitDef(defId);
		if (def is null)
			continue;
		if (def.IsMobile())
			continue;
		if (def.IsRoleAny(Unit::Role::AIR.mask))
			continue;
		if (!def.IsRoleAny(staticPressureRolesMask))
			continue;

		if (!def.IsAttrAny(Unit::Attr::ANTI_STAT.mask)) {
			def.AddAttribute(Unit::Attr::ANTI_STAT.type);
		}
		def.SetFireState(3);
		++staticDefsTuned;
	}

	AiLog("[WallTargets] static pressure tuned defs=" + staticDefsTuned);
}

void EnableGlobalWallPressure()
{
	const uint pressureRolesMask = Unit::Role::RAIDER.mask
		| Unit::Role::RIOT.mask
		| Unit::Role::ASSAULT.mask
		| Unit::Role::SKIRM.mask
		| Unit::Role::ARTY.mask
		| Unit::Role::AH.mask
		| Unit::Role::AA.mask;

	for (Id defId = 1, count = ai.GetDefCount(); defId <= count; ++defId) {
		CCircuitDef@ def = ai.GetCircuitDef(defId);
		if (def is null)
			continue;
		if (!def.IsMobile())
			continue;
		if (def.IsRoleAny(Unit::Role::AIR.mask))
			continue;
		if (!def.IsRoleAny(pressureRolesMask))
			continue;

		if (!def.IsAttrAny(Unit::Attr::ANTI_STAT.mask)) {
			def.AddAttribute(Unit::Attr::ANTI_STAT.type);
		}
		def.SetFireState(3);
	}
}

bool IsRuinsEnabled()
{
	string ruins = string(aiSetupMgr.GetModOptions()["ruins"]);
	ruins = ruins.toLower();
	return (ruins == "enabled") || (ruins == "1") || (ruins == "true");
}

void EnableWallTargets()
{
	string ruins = string(aiSetupMgr.GetModOptions()["ruins"]);
	string ruinsNormalized = ruins.toLower();
	const bool ruinsEnabled = (ruinsNormalized == "enabled") || (ruinsNormalized == "1") || (ruinsNormalized == "true");

	AiLog("[WallTargets] ruins modoption raw='" + ruins + "' normalized='" + ruinsNormalized + "'");
	if (ruinsEnabled) {
		AiLog("[WallTargets] skipped: ruins modoption is enabled (wall pressure disabled)");
		return;
	} else {
		AiLog("[WallTargets] enabled: ruins modoption is disabled (wall pressure enabled)");
	}

	int explicitWallsFound = 0;
	int explicitWallsMissing = 0;

	array<string> walls = {
		"armdrag", "armfdrag", "armfort",
		"cordrag", "corfdrag", "corfort",
		"legdrag", "legfdrag", "legforti", "legrwall",
		"armdrag_scav", "armfdrag_scav", "armfort_scav",
		"cordrag_scav", "corfdrag_scav", "corfort_scav",
		"corscavdrag", "corscavdrag_scav", "corscavfort", "corscavfort_scav"
	};

	for (uint i = 0; i < walls.length(); ++i) {
		CCircuitDef@ cdef = ai.GetCircuitDef(walls[i]);
		if (cdef is null) {
			@cdef = ai.GetCircuitDef(walls[i].toLower());
		}
		if (cdef !is null) {
			cdef.SetIgnore(false);
			cdef.SetThreatKernel(WALL_THREAT_KERNEL);
			++explicitWallsFound;
		} else {
			++explicitWallsMissing;
		}
	}

	AiLog("[WallTargets] explicit wall defs: found=" + explicitWallsFound + " missing=" + explicitWallsMissing);
	
	EnableWallBreakingFireState();
	EnableDefenceFireState();
	EnableGlobalWallPressure();
	EnableStaticWallPressure();
}

void EnableWallBreakingFireState()
{
	array<string> units = {
		"armfav", "armpw", "armrock", "armham", "armjeth", "armflash", "armstump", "armart", "armwar",
		"armflea", "armfboy", "armaser", "armmark", "armfast", "armsptk", "armscab",
		"corak", "corstorm", "corthud", "corcrash", "corraid", "cormist", "cormart", "coraak",
		"legkoda", "legshot", "legaa", "legraider", "leginf", "legart", "legcen", "legbal",
		"legkark", "leglob", "leggob",

		"armpt", "armsub", "armroy", "armpship",
		"corpt", "corsub", "corroy", "corpship",
		"legnavyscout", "legnavyfrigate", "legnavydestro", "legnavysub", "legnavyaaship", "legnavyartyship",

		"armsh", "armmh", "armanac", "armah",
		"corsh", "cormh", "corsnap", "corah",
		"legsh", "legmh", "legner", "legah"
	};

	SetFireStateForUnits(units, 3);

	for (uint i = 0; i < units.length(); ++i) {
		CCircuitDef@ cdef = ai.GetCircuitDef(units[i]);
		if (cdef is null) {
			@cdef = ai.GetCircuitDef(units[i].toLower());
		}
		if (cdef !is null) {
			cdef.AddAttribute(Unit::Attr::ANTI_STAT.type);
		}
	}
}

void EnableDefenceFireState()
{
	array<string> units = {
		// Armed Armada static defenses
		"armllt", "armtl", "armrl", "armbeamer", "armhlt", "armclaw", "armcir", "armferret",
		"armpb", "armatl", "armflak", "armamb", "armanni", "armguard", "armamd", "armtarg",
		"armbrtha", "armvulc",
		"armgate", "armemp", "armfhlt",

		// Armed Cortex static defenses
		"corllt", "cortl", "corrl", "corhllt", "corhlt", "cormaw", "cormadsam", "corvipe",
		"coratl", "corflak", "cortoast", "cordoom", "corpun", "corfmd", "cortarg", "corgate",
		"corint", "corbuzz",
		"cortron", "corfhlt",

		// Armed Legion static defenses
		"leglht", "legtl", "legrl", "legmg", "leghive", "legdtr", "legrhapsis", "leglupara",
		"legapopupdef", "legflak", "legacluster", "legbastion", "legcluster", "legabm", "legtarg",
		"legfmg", "legperdition", "leglrpc", "leganavalaaturret", "leganavalatorpturret", "leganavaldefturret"
	};

	SetFireStateForUnits(units, 3);
	AddAttributeForUnits(units, Unit::Attr::ANTI_STAT.type);
}

}  // namespace Init
