namespace Side {

/*
 * Register factions
 */
TypeMask ARMADA = aiSideMasker.GetTypeMask("armada");
TypeMask CORTEX = aiSideMasker.GetTypeMask("cortex");

}  // namespace Side

namespace Init {

SCategoryInfo InitCategories()
{
	SCategoryInfo category;
	category.air   = "VTOL NOTSUB";
	category.land  = "SURFACE NOTSUB";
	category.water = "UNDERWATER NOTHOVER";
	category.bad   = "TERRAFORM STUPIDTARGET MINE";
	category.good  = "TURRET FLOAT";
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
		"standard",
		"bombers",
		"fighters",
		"mines",
		"nanos",
		"vtol",
		"shields",
		"lboats",
		"hvyboats",
		"subs",
		"tinychicken",
		"chicken"
	};
	armors.sortAsc();
	armors.insertAt(0, "default");

	dictionary armorTypes;
	for (uint i = 0; i < armors.length(); ++i) {
		armorTypes[armors[i]] = i;
	}

	array<string> airTypes = {"bombers", "fighters", "vtol"};
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

}  // namespace Init
