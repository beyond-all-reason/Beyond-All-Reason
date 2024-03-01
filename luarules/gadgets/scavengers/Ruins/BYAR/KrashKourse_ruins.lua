local blueprintConfig = VFS.Include('luarules/gadgets/scavengers/Blueprints/' .. Game.gameShortName .. '/blueprint_tiers.lua')
local types = blueprintConfig.BlueprintTypes


local function RADAR_LLT()
	return {
		type = types.Land,
		radius = 96,
		buildings = {
			{ unitDefID = UnitDefNames.armada_radartower.id, xOffset = 0, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.cortex_scavdragonsteeth.id, xOffset = -32, zOffset = -64, direction = 0},
			{ unitDefID = UnitDefNames.cortex_scavdragonsteeth.id, xOffset = -64, zOffset = 32, direction = 0},
			{ unitDefID = UnitDefNames.armada_dragonsteeth.id, xOffset = -32, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.cortex_scavdragonsteeth.id, xOffset = 64, zOffset = -32, direction = 0},
			{ unitDefID = UnitDefNames.cortex_scavdragonsteeth.id, xOffset = -64, zOffset = -32, direction = 0},
			{ unitDefID = UnitDefNames.armada_sentry.id, xOffset = 64, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.armada_sentry.id, xOffset = 0, zOffset = -64, direction = 0},
			{ unitDefID = UnitDefNames.armada_dragonsteeth.id, xOffset = 0, zOffset = -32, direction = 0},
			{ unitDefID = UnitDefNames.cortex_scavdragonsteeth.id, xOffset = 0, zOffset = 96, direction = 0},
			{ unitDefID = UnitDefNames.cortex_scavdragonsteeth.id, xOffset = -96, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.cortex_scavdragonsteeth.id, xOffset = 0, zOffset = -96, direction = 0},
			{ unitDefID = UnitDefNames.cortex_scavdragonsteeth.id, xOffset = 32, zOffset = 64, direction = 0},
			{ unitDefID = UnitDefNames.armada_dragonsteeth.id, xOffset = 0, zOffset = 32, direction = 0},
			{ unitDefID = UnitDefNames.cortex_scavdragonsteeth.id, xOffset = 96, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.armada_sentry.id, xOffset = -64, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.armada_sentry.id, xOffset = 0, zOffset = 64, direction = 0},
			{ unitDefID = UnitDefNames.armada_dragonsteeth.id, xOffset = 32, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.cortex_scavdragonsteeth.id, xOffset = 64, zOffset = 32, direction = 0},
			{ unitDefID = UnitDefNames.cortex_scavdragonsteeth.id, xOffset = 32, zOffset = -64, direction = 0},
			{ unitDefID = UnitDefNames.cortex_scavdragonsteeth.id, xOffset = -32, zOffset = 64, direction = 0},
		},
	}
end

local function LIGHTNING_SOLAR()
	return {
		type = types.Land,
		radius = 48,
		buildings = {
			{ unitDefID = UnitDefNames.armada_dragonsclaw.id, xOffset = 16, zOffset = 48, direction = 0},
			{ unitDefID = UnitDefNames.armada_dragonsclaw.id, xOffset = -48, zOffset = -16, direction = 0},
			{ unitDefID = UnitDefNames.armada_advancedsolarcollector.id, xOffset = 0, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.armada_dragonsclaw.id, xOffset = -16, zOffset = -48, direction = 0},
			{ unitDefID = UnitDefNames.armada_dragonsclaw.id, xOffset = 48, zOffset = 16, direction = 0},
		},
	}
end

local function FIRE_POWER_STATION()
	return {
		type = types.Land,
		radius = 208,
		buildings = {
			{ unitDefID = UnitDefNames.cortex_agitator.id, xOffset = 32, zOffset = -32, direction = 0},
			{ unitDefID = UnitDefNames.cortex_dragonsmaw.id, xOffset = 144, zOffset = -208, direction = 0},
			{ unitDefID = UnitDefNames.cortex_solarcollector.id, xOffset = -104, zOffset = -104, direction = 0},
			{ unitDefID = UnitDefNames.cortex_dragonsmaw.id, xOffset = 16, zOffset = 16, direction = 0},
			{ unitDefID = UnitDefNames.cortex_advancedsolarcollector.id, xOffset = 96, zOffset = -160, direction = 0},
			{ unitDefID = UnitDefNames.cortex_dragonsmaw.id, xOffset = -144, zOffset = 208, direction = 0},
			{ unitDefID = UnitDefNames.cortex_advancedsolarcollector.id, xOffset = -160, zOffset = 96, direction = 0},
			{ unitDefID = UnitDefNames.cortex_advancedsolarcollector.id, xOffset = 160, zOffset = -96, direction = 0},
			{ unitDefID = UnitDefNames.cortex_dragonsmaw.id, xOffset = -48, zOffset = -48, direction = 0},
			{ unitDefID = UnitDefNames.cortex_agitator.id, xOffset = -32, zOffset = 32, direction = 0},
			{ unitDefID = UnitDefNames.cortex_dragonsmaw.id, xOffset = -48, zOffset = 208, direction = 0},
			{ unitDefID = UnitDefNames.cortex_dragonsmaw.id, xOffset = 48, zOffset = -208, direction = 0},
			{ unitDefID = UnitDefNames.cortex_dragonsmaw.id, xOffset = 208, zOffset = -48, direction = 0},
			{ unitDefID = UnitDefNames.cortex_dragonsmaw.id, xOffset = -208, zOffset = 48, direction = 0},
			{ unitDefID = UnitDefNames.cortex_advancedsolarcollector.id, xOffset = -96, zOffset = 160, direction = 0},
			{ unitDefID = UnitDefNames.cortex_dragonsmaw.id, xOffset = -16, zOffset = -16, direction = 0},
			{ unitDefID = UnitDefNames.cortex_dragonsmaw.id, xOffset = 48, zOffset = 48, direction = 0},
			{ unitDefID = UnitDefNames.cortex_dragonsmaw.id, xOffset = -208, zOffset = 144, direction = 0},
			{ unitDefID = UnitDefNames.cortex_solarcollector.id, xOffset = 104, zOffset = 104, direction = 0},
			{ unitDefID = UnitDefNames.cortex_dragonsmaw.id, xOffset = 208, zOffset = -144, direction = 0},
		},
	}
end

local function MIX_LASER_POWER()
	return {
		type = types.Land,
		radius = 144,
		buildings = {
			{ unitDefID = UnitDefNames.cortex_advancedsolarcollector.id, xOffset = -64, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.cortex_dragonsteeth.id, xOffset = -16, zOffset = -144, direction = 0},
			{ unitDefID = UnitDefNames.cortex_dragonsteeth.id, xOffset = 112, zOffset = 48, direction = 0},
			{ unitDefID = UnitDefNames.cortex_dragonsteeth.id, xOffset = 48, zOffset = 112, direction = 0},
			{ unitDefID = UnitDefNames.cortex_advancedsolarcollector.id, xOffset = 0, zOffset = 64, direction = 0},
			{ unitDefID = UnitDefNames.cortex_dragonsteeth.id, xOffset = -16, zOffset = 144, direction = 0},
			{ unitDefID = UnitDefNames.cortex_warden.id, xOffset = 48, zOffset = 48, direction = 0},
			{ unitDefID = UnitDefNames.cortex_dragonsteeth.id, xOffset = -144, zOffset = 16, direction = 0},
			{ unitDefID = UnitDefNames.cortex_dragonsteeth.id, xOffset = -144, zOffset = -16, direction = 0},
			{ unitDefID = UnitDefNames.cortex_dragonsteeth.id, xOffset = 16, zOffset = -144, direction = 0},
			{ unitDefID = UnitDefNames.cortex_dragonsteeth.id, xOffset = 80, zOffset = 80, direction = 0},
			{ unitDefID = UnitDefNames.cortex_dragonsteeth.id, xOffset = 144, zOffset = -16, direction = 0},
			{ unitDefID = UnitDefNames.cortex_advancedsolarcollector.id, xOffset = 0, zOffset = -64, direction = 0},
			{ unitDefID = UnitDefNames.cortex_twinguard.id, xOffset = -48, zOffset = 48, direction = 0},
			{ unitDefID = UnitDefNames.cortex_dragonsteeth.id, xOffset = -48, zOffset = 112, direction = 0},
			{ unitDefID = UnitDefNames.cortex_dragonsteeth.id, xOffset = 32, zOffset = 144, direction = 0},
			{ unitDefID = UnitDefNames.cortex_dragonsteeth.id, xOffset = 48, zOffset = -112, direction = 0},
			{ unitDefID = UnitDefNames.cortex_dragonsteeth.id, xOffset = 144, zOffset = 16, direction = 0},
			{ unitDefID = UnitDefNames.cortex_dragonsteeth.id, xOffset = -48, zOffset = -112, direction = 0},
			{ unitDefID = UnitDefNames.cortex_dragonsteeth.id, xOffset = 112, zOffset = -48, direction = 0},
			{ unitDefID = UnitDefNames.cortex_advancedsolarcollector.id, xOffset = 64, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.cortex_dragonsteeth.id, xOffset = 80, zOffset = -80, direction = 0},
			{ unitDefID = UnitDefNames.cortex_dragonsteeth.id, xOffset = -112, zOffset = 48, direction = 0},
			{ unitDefID = UnitDefNames.cortex_dragonsteeth.id, xOffset = -80, zOffset = -80, direction = 0},
			{ unitDefID = UnitDefNames.cortex_twinguard.id, xOffset = 48, zOffset = -48, direction = 0},
			{ unitDefID = UnitDefNames.cortex_warden.id, xOffset = -48, zOffset = -48, direction = 0},
			{ unitDefID = UnitDefNames.cortex_dragonsteeth.id, xOffset = -112, zOffset = -48, direction = 0},
			{ unitDefID = UnitDefNames.cortex_dragonsteeth.id, xOffset = -80, zOffset = 80, direction = 0},
		},
	}
end

local function HEAVY_LASERS()
	return {
		type = types.Land,
		radius = 160,
		buildings = {
			{ unitDefID = UnitDefNames.armada_dragonsteeth.id, xOffset = 128, zOffset = -32, direction = 0},
			{ unitDefID = UnitDefNames.armada_dragonsteeth.id, xOffset = -96, zOffset = -64, direction = 0},
			{ unitDefID = UnitDefNames.armada_dragonsteeth.id, xOffset = -128, zOffset = 32, direction = 0},
			{ unitDefID = UnitDefNames.armada_dragonsteeth.id, xOffset = 96, zOffset = -64, direction = 0},
			{ unitDefID = UnitDefNames.armada_overwatch.id, xOffset = 96, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.armada_dragonsteeth.id, xOffset = -64, zOffset = -32, direction = 0},
			{ unitDefID = UnitDefNames.armada_dragonsteeth.id, xOffset = -32, zOffset = 64, direction = 0},
			{ unitDefID = UnitDefNames.armada_dragonsteeth.id, xOffset = -32, zOffset = -64, direction = 0},
			{ unitDefID = UnitDefNames.armada_dragonsteeth.id, xOffset = -128, zOffset = -32, direction = 0},
			{ unitDefID = UnitDefNames.armada_dragonsteeth.id, xOffset = -96, zOffset = 64, direction = 0},
			{ unitDefID = UnitDefNames.armada_dragonsteeth.id, xOffset = 160, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.armada_dragonsteeth.id, xOffset = -160, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.armada_dragonsteeth.id, xOffset = 0, zOffset = -32, direction = 0},
			{ unitDefID = UnitDefNames.armada_overwatch.id, xOffset = 32, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.armada_dragonsteeth.id, xOffset = 32, zOffset = -64, direction = 0},
			{ unitDefID = UnitDefNames.armada_overwatch.id, xOffset = -96, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.armada_dragonsteeth.id, xOffset = 64, zOffset = -32, direction = 0},
			{ unitDefID = UnitDefNames.armada_dragonsteeth.id, xOffset = 32, zOffset = 64, direction = 0},
			{ unitDefID = UnitDefNames.armada_dragonsteeth.id, xOffset = 64, zOffset = 32, direction = 0},
			{ unitDefID = UnitDefNames.armada_dragonsteeth.id, xOffset = 96, zOffset = 64, direction = 0},
			{ unitDefID = UnitDefNames.armada_dragonsteeth.id, xOffset = -64, zOffset = 32, direction = 0},
			{ unitDefID = UnitDefNames.armada_dragonsteeth.id, xOffset = 128, zOffset = 32, direction = 0},
			{ unitDefID = UnitDefNames.armada_dragonsteeth.id, xOffset = 0, zOffset = 32, direction = 0},
			{ unitDefID = UnitDefNames.armada_overwatch.id, xOffset = -32, zOffset = 0, direction = 0},
		},
	}
end

local function ANIHI_OUTPOST()
	return {
		type = types.Land,
		radius = 144,
		buildings = {
			{ unitDefID = UnitDefNames.armada_pulsar.id, xOffset = 0, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.armada_dragonsteeth.id, xOffset = 0, zOffset = 144, direction = 0},
			{ unitDefID = UnitDefNames.armada_dragonsteeth.id, xOffset = 32, zOffset = -128, direction = 0},
			{ unitDefID = UnitDefNames.cortex_guard.id, xOffset = 0, zOffset = -112, direction = 0},
			{ unitDefID = UnitDefNames.armada_dragonsteeth.id, xOffset = -32, zOffset = -128, direction = 0},
			{ unitDefID = UnitDefNames.cortex_guard.id, xOffset = 0, zOffset = 112, direction = 0},
			{ unitDefID = UnitDefNames.cortex_guard.id, xOffset = 112, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.armada_dragonsteeth.id, xOffset = 128, zOffset = -32, direction = 0},
			{ unitDefID = UnitDefNames.armada_dragonsteeth.id, xOffset = -128, zOffset = 32, direction = 0},
			{ unitDefID = UnitDefNames.armada_dragonsteeth.id, xOffset = 128, zOffset = 32, direction = 0},
			{ unitDefID = UnitDefNames.armada_dragonsteeth.id, xOffset = 0, zOffset = -144, direction = 0},
			{ unitDefID = UnitDefNames.armada_dragonsteeth.id, xOffset = 32, zOffset = 128, direction = 0},
			{ unitDefID = UnitDefNames.armada_dragonsteeth.id, xOffset = -32, zOffset = 128, direction = 0},
			{ unitDefID = UnitDefNames.cortex_guard.id, xOffset = -112, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.armada_dragonsteeth.id, xOffset = -144, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.armada_dragonsteeth.id, xOffset = 144, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.armada_dragonsteeth.id, xOffset = -128, zOffset = -32, direction = 0},
		},
	}
end

local function BEAM_WALL()
	return {
		type = types.Land,
		radius = 128,
		buildings = {
			{ unitDefID = UnitDefNames.armada_beamer.id, xOffset = 96, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.cortex_scavdragonsteeth.id, xOffset = -32, zOffset = 32, direction = 0},
			{ unitDefID = UnitDefNames.armada_beamer.id, xOffset = -96, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.cortex_scavdragonsteeth.id, xOffset = -64, zOffset = -64, direction = 0},
			{ unitDefID = UnitDefNames.cortex_scavdragonsteeth.id, xOffset = -96, zOffset = -32, direction = 0},
			{ unitDefID = UnitDefNames.cortex_scavdragonsteeth.id, xOffset = -96, zOffset = 32, direction = 0},
			{ unitDefID = UnitDefNames.cortex_scavdragonsteeth.id, xOffset = 32, zOffset = 32, direction = 0},
			{ unitDefID = UnitDefNames.armada_beamer.id, xOffset = 32, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.cortex_scavdragonsteeth.id, xOffset = 128, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.cortex_scavdragonsteeth.id, xOffset = 96, zOffset = 32, direction = 0},
			{ unitDefID = UnitDefNames.cortex_scavdragonsteeth.id, xOffset = 64, zOffset = 64, direction = 0},
			{ unitDefID = UnitDefNames.cortex_scavdragonsteeth.id, xOffset = 96, zOffset = -32, direction = 0},
			{ unitDefID = UnitDefNames.cortex_scavdragonsteeth.id, xOffset = -64, zOffset = 64, direction = 0},
			{ unitDefID = UnitDefNames.cortex_scavdragonsteeth.id, xOffset = 0, zOffset = -64, direction = 0},
			{ unitDefID = UnitDefNames.armada_beamer.id, xOffset = -32, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.cortex_scavdragonsteeth.id, xOffset = 32, zOffset = -32, direction = 0},
			{ unitDefID = UnitDefNames.cortex_scavdragonsteeth.id, xOffset = 0, zOffset = 64, direction = 0},
			{ unitDefID = UnitDefNames.cortex_scavdragonsteeth.id, xOffset = 64, zOffset = -64, direction = 0},
			{ unitDefID = UnitDefNames.cortex_scavdragonsteeth.id, xOffset = -128, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.cortex_scavdragonsteeth.id, xOffset = -32, zOffset = -32, direction = 0},
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