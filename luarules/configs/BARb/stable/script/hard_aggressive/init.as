#include "../common.as"
#include "../unit.as"


namespace Init {

SInitInfo AiInit()
{
	AiLog("hard_aggressive AngelScript Rules!");

	SInitInfo data;
	data.armor = InitArmordef();
	data.category = InitCategories();
	@data.profile = @(array<string> = {"behaviour", "block_map", "build_chain", "commander", "economy", "factory", "response"});
	if (string(aiSetupMgr.GetModOptions()["experimentallegionfaction"]) == "1") {
		AiLog("inserting economy_leg");
		Side::LEGION = aiSideMasker.GetTypeMask("legion");
		data.profile.insertAt(data.profile.length(), {"behaviour_leg", "build_chain_leg", "commander_leg", "economy_leg", "factory_leg"});
	} else {
		AiLog("Ignoring Legion");
	}
	return data;
}

}
