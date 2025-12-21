#include "../common.as"
#include "../unit.as"


namespace Init {

SInitInfo AiInit()
{
	AiLog("hard AngelScript Rules!");

	SInitInfo data;
	data.armor = InitArmordef();
	data.category = InitCategories();
	@data.profile = @(array<string> = {"behaviour", "block_map", "build_chain", "commander", "economy", "factory", "response"});
	if (string(aiSetupMgr.GetModOptions()["experimentallegionfaction"]) == "1") {
		AiLog("Inserting Legion");
		Side::LEGION = aiSideMasker.GetTypeMask("legion");
		data.profile.insertAt(data.profile.length(), {"behaviour_leg", "build_chain_leg", "commander_leg", "economy_leg", "factory_leg"});
	} else {
		AiLog("Ignoring Legion");
	}
	if (string(aiSetupMgr.GetModOptions()["scavunitsforplayers"]) == "1") {
		AiLog("Inserting Scav Units");
		data.profile.insertAt(data.profile.length(), {"behaviour_scav_units"});
	} else {
		AiLog("Ignoring Scav Units");
	}
	if (string(aiSetupMgr.GetModOptions()["experimentalextraunits"]) == "1") {
		AiLog("Inserting Extra Units");
		data.profile.insertAt(data.profile.length(), {"behaviour_extra_units"});
	} else {
		AiLog("Ignoring Extra Units");
	}
	return data;
}

}
