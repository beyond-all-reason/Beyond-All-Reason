local Types = GG['MissionAPI'].Modules.ParameterTypes.Types

local function spawnUnits(unitLoadout)
	GG['MissionAPI'].Modules.Loadout.SpawnUnitLoadout(unitLoadout)
end

return {
	type = 'SpawnUnits',
	parameters = {
		{ name = 'unitLoadout', required = true, type = Types.UnitLoadout },
	},
	actionFunction = spawnUnits,
}
