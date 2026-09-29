-- Enable/Disable UnitDefs for construction by AI teamID
local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function setUnitDefEnabled(unitDefName, isEnabled, teamID)
	GG["CampaignAI"].SetUnitDefsEnabled({UnitDefNames[unitDefName].id}, isEnabled, teamID)
end

return {
	{
		type = 'DisableUnitDef',
		parameters = {
			{ name = 'unitDefName', required = true, type = ParameterTypes.UnitDefName },
			{ name = 'isEnabled', required = true, type = ParameterTypes.Boolean },
			{ name = 'teamID', required = true, type = ParameterTypes.TeamID },
		},
		actionFunction = disableUnitDef,
	}
}
