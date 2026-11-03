local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- Statistics condition: evaluated by the centralised statistics engine in
-- statistics.lua (shared counting), so it declares no callins.
return {
	type = 'TotalUnitsKilled',
	kind = 'event',
	parameters = {
		{ name = 'teamName',    required = true,  type = ParameterTypes.TeamName },
		{ name = 'unitName',    required = false, type = ParameterTypes.UnitName },
		{ name = 'unitDefName', required = false, type = ParameterTypes.UnitDefName },
	},
}
