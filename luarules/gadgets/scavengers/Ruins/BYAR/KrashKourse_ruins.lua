local blueprintConfig = VFS.Include('luarules/gadgets/scavengers/Blueprints/' .. Game.gameShortName .. '/blueprint_tiers.lua')
local types = blueprintConfig.BlueprintTypes


local function RADAR_LLT()
	return {
		type = types.Land,
		radius = 96,
		buildings = {
			{ unitDefID = UnitDefNames.armrad.id, xOffset = 0, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.corscavdrag.id, xOffset = -32, zOffset = -64, direction = 0},
			{ unitDefID = UnitDefNames.corscavdrag.id, xOffset = -64, zOffset = 32, direction = 0},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -32, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.corscavdrag.id, xOffset = 64, zOffset = -32, direction = 0},
			{ unitDefID = UnitDefNames.corscavdrag.id, xOffset = -64, zOffset = -32, direction = 0},
			{ unitDefID = UnitDefNames.armllt.id, xOffset = 64, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.armllt.id, xOffset = 0, zOffset = -64, direction = 0},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 0, zOffset = -32, direction = 0},
			{ unitDefID = UnitDefNames.corscavdrag.id, xOffset = 0, zOffset = 96, direction = 0},
			{ unitDefID = UnitDefNames.corscavdrag.id, xOffset = -96, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.corscavdrag.id, xOffset = 0, zOffset = -96, direction = 0},
			{ unitDefID = UnitDefNames.corscavdrag.id, xOffset = 32, zOffset = 64, direction = 0},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 0, zOffset = 32, direction = 0},
			{ unitDefID = UnitDefNames.corscavdrag.id, xOffset = 96, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.armllt.id, xOffset = -64, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.armllt.id, xOffset = 0, zOffset = 64, direction = 0},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 32, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.corscavdrag.id, xOffset = 64, zOffset = 32, direction = 0},
			{ unitDefID = UnitDefNames.corscavdrag.id, xOffset = 32, zOffset = -64, direction = 0},
			{ unitDefID = UnitDefNames.corscavdrag.id, xOffset = -32, zOffset = 64, direction = 0},
		},
	}
end

local function LIGHTNING_SOLAR()
	return {
		type = types.Land,
		radius = 48,
		buildings = {
			{ unitDefID = UnitDefNames.armclaw.id, xOffset = 16, zOffset = 48, direction = 0},
			{ unitDefID = UnitDefNames.armclaw.id, xOffset = -48, zOffset = -16, direction = 0},
			{ unitDefID = UnitDefNames.armadvsol.id, xOffset = 0, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.armclaw.id, xOffset = -16, zOffset = -48, direction = 0},
			{ unitDefID = UnitDefNames.armclaw.id, xOffset = 48, zOffset = 16, direction = 0},
		},
	}
end

local function FIRE_POWER_STATION()
	return {
		type = types.Land,
		radius = 208,
		buildings = {
			{ unitDefID = UnitDefNames.corpun.id, xOffset = 32, zOffset = -32, direction = 0},
			{ unitDefID = UnitDefNames.cormaw.id, xOffset = 144, zOffset = -208, direction = 0},
			{ unitDefID = UnitDefNames.corsolar.id, xOffset = -104, zOffset = -104, direction = 0},
			{ unitDefID = UnitDefNames.cormaw.id, xOffset = 16, zOffset = 16, direction = 0},
			{ unitDefID = UnitDefNames.coradvsol.id, xOffset = 96, zOffset = -160, direction = 0},
			{ unitDefID = UnitDefNames.cormaw.id, xOffset = -144, zOffset = 208, direction = 0},
			{ unitDefID = UnitDefNames.coradvsol.id, xOffset = -160, zOffset = 96, direction = 0},
			{ unitDefID = UnitDefNames.coradvsol.id, xOffset = 160, zOffset = -96, direction = 0},
			{ unitDefID = UnitDefNames.cormaw.id, xOffset = -48, zOffset = -48, direction = 0},
			{ unitDefID = UnitDefNames.corpun.id, xOffset = -32, zOffset = 32, direction = 0},
			{ unitDefID = UnitDefNames.cormaw.id, xOffset = -48, zOffset = 208, direction = 0},
			{ unitDefID = UnitDefNames.cormaw.id, xOffset = 48, zOffset = -208, direction = 0},
			{ unitDefID = UnitDefNames.cormaw.id, xOffset = 208, zOffset = -48, direction = 0},
			{ unitDefID = UnitDefNames.cormaw.id, xOffset = -208, zOffset = 48, direction = 0},
			{ unitDefID = UnitDefNames.coradvsol.id, xOffset = -96, zOffset = 160, direction = 0},
			{ unitDefID = UnitDefNames.cormaw.id, xOffset = -16, zOffset = -16, direction = 0},
			{ unitDefID = UnitDefNames.cormaw.id, xOffset = 48, zOffset = 48, direction = 0},
			{ unitDefID = UnitDefNames.cormaw.id, xOffset = -208, zOffset = 144, direction = 0},
			{ unitDefID = UnitDefNames.corsolar.id, xOffset = 104, zOffset = 104, direction = 0},
			{ unitDefID = UnitDefNames.cormaw.id, xOffset = 208, zOffset = -144, direction = 0},
		},
	}
end

local function MIX_LASER_POWER()
	return {
		type = types.Land,
		radius = 144,
		buildings = {
			{ unitDefID = UnitDefNames.coradvsol.id, xOffset = -64, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.cordrag.id, xOffset = -16, zOffset = -144, direction = 0},
			{ unitDefID = UnitDefNames.cordrag.id, xOffset = 112, zOffset = 48, direction = 0},
			{ unitDefID = UnitDefNames.cordrag.id, xOffset = 48, zOffset = 112, direction = 0},
			{ unitDefID = UnitDefNames.coradvsol.id, xOffset = 0, zOffset = 64, direction = 0},
			{ unitDefID = UnitDefNames.cordrag.id, xOffset = -16, zOffset = 144, direction = 0},
			{ unitDefID = UnitDefNames.corhlt.id, xOffset = 48, zOffset = 48, direction = 0},
			{ unitDefID = UnitDefNames.cordrag.id, xOffset = -144, zOffset = 16, direction = 0},
			{ unitDefID = UnitDefNames.cordrag.id, xOffset = -144, zOffset = -16, direction = 0},
			{ unitDefID = UnitDefNames.cordrag.id, xOffset = 16, zOffset = -144, direction = 0},
			{ unitDefID = UnitDefNames.cordrag.id, xOffset = 80, zOffset = 80, direction = 0},
			{ unitDefID = UnitDefNames.cordrag.id, xOffset = 144, zOffset = -16, direction = 0},
			{ unitDefID = UnitDefNames.coradvsol.id, xOffset = 0, zOffset = -64, direction = 0},
			{ unitDefID = UnitDefNames.corhllt.id, xOffset = -48, zOffset = 48, direction = 0},
			{ unitDefID = UnitDefNames.cordrag.id, xOffset = -48, zOffset = 112, direction = 0},
			{ unitDefID = UnitDefNames.cordrag.id, xOffset = 32, zOffset = 144, direction = 0},
			{ unitDefID = UnitDefNames.cordrag.id, xOffset = 48, zOffset = -112, direction = 0},
			{ unitDefID = UnitDefNames.cordrag.id, xOffset = 144, zOffset = 16, direction = 0},
			{ unitDefID = UnitDefNames.cordrag.id, xOffset = -48, zOffset = -112, direction = 0},
			{ unitDefID = UnitDefNames.cordrag.id, xOffset = 112, zOffset = -48, direction = 0},
			{ unitDefID = UnitDefNames.coradvsol.id, xOffset = 64, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.cordrag.id, xOffset = 80, zOffset = -80, direction = 0},
			{ unitDefID = UnitDefNames.cordrag.id, xOffset = -112, zOffset = 48, direction = 0},
			{ unitDefID = UnitDefNames.cordrag.id, xOffset = -80, zOffset = -80, direction = 0},
			{ unitDefID = UnitDefNames.corhllt.id, xOffset = 48, zOffset = -48, direction = 0},
			{ unitDefID = UnitDefNames.corhlt.id, xOffset = -48, zOffset = -48, direction = 0},
			{ unitDefID = UnitDefNames.cordrag.id, xOffset = -112, zOffset = -48, direction = 0},
			{ unitDefID = UnitDefNames.cordrag.id, xOffset = -80, zOffset = 80, direction = 0},
		},
	}
end

local function HEAVY_LASERS()
	return {
		type = types.Land,
		radius = 160,
		buildings = {
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 128, zOffset = -32, direction = 0},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -96, zOffset = -64, direction = 0},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -128, zOffset = 32, direction = 0},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 96, zOffset = -64, direction = 0},
			{ unitDefID = UnitDefNames.armhlt.id, xOffset = 96, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -64, zOffset = -32, direction = 0},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -32, zOffset = 64, direction = 0},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -32, zOffset = -64, direction = 0},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -128, zOffset = -32, direction = 0},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -96, zOffset = 64, direction = 0},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 160, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -160, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 0, zOffset = -32, direction = 0},
			{ unitDefID = UnitDefNames.armhlt.id, xOffset = 32, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 32, zOffset = -64, direction = 0},
			{ unitDefID = UnitDefNames.armhlt.id, xOffset = -96, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 64, zOffset = -32, direction = 0},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 32, zOffset = 64, direction = 0},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 64, zOffset = 32, direction = 0},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 96, zOffset = 64, direction = 0},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -64, zOffset = 32, direction = 0},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 128, zOffset = 32, direction = 0},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 0, zOffset = 32, direction = 0},
			{ unitDefID = UnitDefNames.armhlt.id, xOffset = -32, zOffset = 0, direction = 0},
		},
	}
end

local function ANIHI_OUTPOST()
	return {
		type = types.Land,
		radius = 144,
		buildings = {
			{ unitDefID = UnitDefNames.armanni.id, xOffset = 0, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 0, zOffset = 144, direction = 0},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 32, zOffset = -128, direction = 0},
			{ unitDefID = UnitDefNames.corllt.id, xOffset = 0, zOffset = -112, direction = 0},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -32, zOffset = -128, direction = 0},
			{ unitDefID = UnitDefNames.corllt.id, xOffset = 0, zOffset = 112, direction = 0},
			{ unitDefID = UnitDefNames.corllt.id, xOffset = 112, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 128, zOffset = -32, direction = 0},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -128, zOffset = 32, direction = 0},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 128, zOffset = 32, direction = 0},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 0, zOffset = -144, direction = 0},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 32, zOffset = 128, direction = 0},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -32, zOffset = 128, direction = 0},
			{ unitDefID = UnitDefNames.corllt.id, xOffset = -112, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -144, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 144, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -128, zOffset = -32, direction = 0},
		},
	}
end

local function BEAM_WALL()
	return {
		type = types.Land,
		radius = 128,
		buildings = {
			{ unitDefID = UnitDefNames.armbeamer.id, xOffset = 96, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.corscavdrag.id, xOffset = -32, zOffset = 32, direction = 0},
			{ unitDefID = UnitDefNames.armbeamer.id, xOffset = -96, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.corscavdrag.id, xOffset = -64, zOffset = -64, direction = 0},
			{ unitDefID = UnitDefNames.corscavdrag.id, xOffset = -96, zOffset = -32, direction = 0},
			{ unitDefID = UnitDefNames.corscavdrag.id, xOffset = -96, zOffset = 32, direction = 0},
			{ unitDefID = UnitDefNames.corscavdrag.id, xOffset = 32, zOffset = 32, direction = 0},
			{ unitDefID = UnitDefNames.armbeamer.id, xOffset = 32, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.corscavdrag.id, xOffset = 128, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.corscavdrag.id, xOffset = 96, zOffset = 32, direction = 0},
			{ unitDefID = UnitDefNames.corscavdrag.id, xOffset = 64, zOffset = 64, direction = 0},
			{ unitDefID = UnitDefNames.corscavdrag.id, xOffset = 96, zOffset = -32, direction = 0},
			{ unitDefID = UnitDefNames.corscavdrag.id, xOffset = -64, zOffset = 64, direction = 0},
			{ unitDefID = UnitDefNames.corscavdrag.id, xOffset = 0, zOffset = -64, direction = 0},
			{ unitDefID = UnitDefNames.armbeamer.id, xOffset = -32, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.corscavdrag.id, xOffset = 32, zOffset = -32, direction = 0},
			{ unitDefID = UnitDefNames.corscavdrag.id, xOffset = 0, zOffset = 64, direction = 0},
			{ unitDefID = UnitDefNames.corscavdrag.id, xOffset = 64, zOffset = -64, direction = 0},
			{ unitDefID = UnitDefNames.corscavdrag.id, xOffset = -128, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.corscavdrag.id, xOffset = -32, zOffset = -32, direction = 0},
		},
	}
end

return {
    RADAR_LLT,
    LIGHTNING_SOLAR,
    FIRE_POWER_STATION,
    MIX_LASER_POWER,
    HEAVY_LASERS,
    ANIHI_OUTPOST,
    BEAM_WALL,
}