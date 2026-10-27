local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- Statistics condition: evaluated by the centralised statistics engine in
-- statistics.lua (shared counting), so it declares no callins.
return {
	type = 'TotalUnitsBuilt',
	kind = 'event',
	parameters = {
		{ name = 'teamID',      required = true,  type = ParameterTypes.TeamID },
		{ name = 'unitDefName', required = false, type = ParameterTypes.UnitDefName },
	},
}
