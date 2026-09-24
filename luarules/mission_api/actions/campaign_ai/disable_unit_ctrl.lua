-- Disable AI's direct control over its units
local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function disableUnitsControl(teamID, unitIDs)
	if not GG["campaign_ai"] then
		error("[Mission API] Campaign AI API unavailable (api_campaign_ai.lua gadget not loaded), can't disable units control")
	end

	GG["campaign_ai"].GadgetDisableUnitsCtrl(teamID, unitIDs)
end

return {
	{
		type = 'DisableUnitsControl',
		parameters = {
			{ name = 'teamID', required = true, type = ParameterTypes.TeamID },
			{ name = 'unitIDs', required = true, type = ParameterTypes.Table },
		},
		actionFunction = disableUnitsControl,
	}
}
