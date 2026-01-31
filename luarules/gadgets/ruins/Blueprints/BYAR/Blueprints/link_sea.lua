local blueprintConfig = VFS.Include('luarules/gadgets/ruins/Blueprints/' .. Game.gameShortName .. '/blueprint_tiers.lua')
local tiers = blueprintConfig.Tiers
local types = blueprintConfig.BlueprintTypes
local UDN = UnitDefNames


local function t1RadarOutpost()
	return {
		type = types.Sea,
		tiers = { tiers.T0, tiers.T1 },
		radius = 166,
		buildings = {
			{ unitDefID = UnitDefNames.armfdrag_scav.id, xOffset = 54, zOffset = -74, direction = 0},
			{ unitDefID = UnitDefNames.armfdrag_scav.id, xOffset = -74, zOffset = 118, direction = 0},
			{ unitDefID = UnitDefNames.armfdrag_scav.id, xOffset = 102, zOffset = -74, direction = 0},
			{ unitDefID = UnitDefNames.armfdrag_scav.id, xOffset = -74, zOffset = 54, direction = 0},
			{ unitDefID = UnitDefNames.armfdrag_scav.id, xOffset = -74, zOffset = 150, direction = 0},
			{ unitDefID = UnitDefNames.armfrt_scav.id, xOffset = 86, zOffset = -26, direction = 0},
			{ unitDefID = UnitDefNames.armfdrag_scav.id, xOffset = -42, zOffset = -26, direction = 0},
			{ unitDefID = UnitDefNames.armfdrag_scav.id, xOffset = 134, zOffset = -74, direction = 0},
			{ unitDefID = UnitDefNames.armfdrag_scav.id, xOffset = -74, zOffset = 86, direction = 0},
			{ unitDefID = UnitDefNames.armfrad_scav.id, xOffset = -34, zOffset = 78, direction = 0},
			{ unitDefID = UnitDefNames.armfdrag_scav.id, xOffset = 166, zOffset = -74, direction = 0},
			{ unitDefID = UnitDefNames.armfdrag_scav.id, xOffset = -74, zOffset = -58, direction = 0},
			{ unitDefID = UnitDefNames.armfrt_scav.id, xOffset = 54, zOffset = 70, direction = 0},
			{ unitDefID = UnitDefNames.armfdrag_scav.id, xOffset = 22, zOffset = -74, direction = 0},
			{ unitDefID = UnitDefNames.armfdrag_scav.id, xOffset = -74, zOffset = -10, direction = 0},
			{ unitDefID = UnitDefNames.armfdrag_scav.id, xOffset = -74, zOffset = 22, direction = 0},
			{ unitDefID = UnitDefNames.armfdrag_scav.id, xOffset = -26, zOffset = -58, direction = 0},
			{ unitDefID = UnitDefNames.armfrad_scav.id, xOffset = 14, zOffset = -18, direction = 0},
		},
	}
end

return {
	t1RadarOutpost,
}