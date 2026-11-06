-- Enable/Disable UnitDefs for construction by AI teamID
local ParameterTypes = GG["MissionAPI"].Modules.ParameterTypes.Types
local teams = GG["MissionAPI"].Teams

local function enableUnitDef(unitDefName, teamName)
	GG["CampaignAI"].SetUnitDefsEnabled({ UnitDefNames[unitDefName].id }, true, teams[teamName])
end

local function disableUnitDef(unitDefName, teamName)
	GG["CampaignAI"].SetUnitDefsEnabled({ UnitDefNames[unitDefName].id }, false, teams[teamName])
end

return {
	{
		type = "EnableUnitDef",
		parameters = {
			{ name = "unitDefName", required = true, type = ParameterTypes.UnitDefName },
			{ name = "teamName", required = true, type = ParameterTypes.TeamName },
		},
		actionFunction = enableUnitDef,
	},
	{
		type = "DisableUnitDef",
		parameters = {
			{ name = "unitDefName", required = true, type = ParameterTypes.UnitDefName },
			{ name = "teamName", required = true, type = ParameterTypes.TeamName },
		},
		actionFunction = disableUnitDef,
	},
}
