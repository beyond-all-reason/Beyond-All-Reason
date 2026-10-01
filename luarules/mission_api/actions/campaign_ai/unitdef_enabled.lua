-- Enable/Disable UnitDefs for construction by AI teamID
local ParameterTypes = GG["MissionAPI"].Modules.ParameterTypes.Types

local function enableUnitDef(unitDefName, isEnabled, teamID)
	GG["CampaignAI"].SetUnitDefsEnabled({ UnitDefNames[unitDefName].id }, true, teamID)
end

local function disableUnitDef(unitDefName, isEnabled, teamID)
	GG["CampaignAI"].SetUnitDefsEnabled({ UnitDefNames[unitDefName].id }, false, teamID)
end

return {
	{
		type = "EnableUnitDef",
		parameters = {
			{ name = "unitDefName", required = true, type = ParameterTypes.UnitDefName },
			{ name = "teamID", required = true, type = ParameterTypes.TeamID },
		},
		actionFunction = enableUnitDef,
	},
	{
		type = "DisableUnitDef",
		parameters = {
			{ name = "unitDefName", required = true, type = ParameterTypes.UnitDefName },
			{ name = "teamID", required = true, type = ParameterTypes.TeamID },
		},
		actionFunction = disableUnitDef,
	},
}
