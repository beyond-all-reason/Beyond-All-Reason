-- Caps how many units of a type a team may have at once (GG.UnitTypeLimits, api_unit_type_limits.lua).
local ParameterTypes = GG["MissionAPI"].Modules.ParameterTypes.Types

local function setUnitTypeLimit(unitDefName, teamID, limit)
	GG.UnitTypeLimits.Set(teamID, UnitDefNames[unitDefName].id, limit)
end

local function removeUnitTypeLimit(unitDefName, teamID)
	GG.UnitTypeLimits.Set(teamID, UnitDefNames[unitDefName].id, nil)
end

return {
	{
		type = "SetUnitTypeLimit",
		parameters = {
			{ name = "unitDefName", required = true, type = ParameterTypes.UnitDefName },
			{ name = "teamName", required = true, type = ParameterTypes.TeamName },
			{ name = "limit", required = true, type = ParameterTypes.PositiveInteger },
		},
		actionFunction = setUnitTypeLimit,
	},
	{
		type = "RemoveUnitTypeLimit",
		parameters = {
			{ name = "unitDefName", required = true, type = ParameterTypes.UnitDefName },
			{ name = "teamName", required = true, type = ParameterTypes.TeamName },
		},
		actionFunction = removeUnitTypeLimit,
	},
}
