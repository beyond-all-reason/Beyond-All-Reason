local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
local ConditionKinds = GG['MissionAPI'].Modules.ConditionKinds

-- Statistics condition: evaluated by the centralised statistics engine in
-- statistics.lua (shared counting), so it declares no callins.
return {
	type = 'TotalUnitsBuilt',
	kind = ConditionKinds.Event,
	parameters = {
		{ name = 'teamName',    required = true,  type = ParameterTypes.TeamName },
		{ name = 'unitDefName', required = false, type = ParameterTypes.UnitDefName },
	},
}
