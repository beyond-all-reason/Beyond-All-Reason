local Types = GG['MissionAPI'].Modules.ParameterTypes.Types

local function spawnUnits(unitLoadout)
	GG['MissionAPI'].Modules.Loadout.SpawnUnitLoadout(unitLoadout)
end

return {
	name = 'SpawnUnits',
	parameters = {
		{ name = 'unitLoadout', required = true, type = Types.UnitLoadout },
	},
	execute = spawnUnits,
}
