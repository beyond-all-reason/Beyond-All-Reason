-- Disable UnitDefs for construction by AI teamID
local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function disableUnitDefs(teamID, unitDefIDs)
	if not GG["campaign_ai"] then
		error("[Mission API] Campaign AI API unavailable (api_campaign_ai.lua gadget not loaded), can't disable UnitDefs")
	end

	GG["campaign_ai"].GadgetDisableUnitDefs(teamID, unitDefIDs)
end

return {
	{
		type = 'DisableUnitDefs',
		parameters = {
			{ name = 'teamID', required = true, type = ParameterTypes.TeamID },
			{ name = 'unitDefIDs', required = true, type = ParameterTypes.Table },
		},
		actionFunction = disableUnitDefs,
	}
}
