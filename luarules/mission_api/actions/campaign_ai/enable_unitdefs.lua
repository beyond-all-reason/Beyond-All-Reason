-- Enable UnitDefs for construction by AI teamID
local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function enableUnitDefs(teamID, unitDefIDs)
	if not GG["campaign_ai"] then
		error("[Mission API] Campaign AI API unavailable (api_campaign_ai.lua gadget not loaded), can't enable UnitDefs")
	end

	GG["campaign_ai"].GadgetEnableUnitDefs(teamID, unitDefIDs)
end

return {
	{
		type = 'EnableUnitDefs',
		parameters = {
			{ name = 'teamID', required = true, type = ParameterTypes.TeamID },
			{ name = 'unitDefIDs', required = true, type = ParameterTypes.Table },
		},
		actionFunction = enableUnitDefs,
	}
}
