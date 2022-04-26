local blueprintConfig = VFS.Include('luarules/gadgets/scavengers/Blueprints/' .. Game.gameShortName .. '/blueprint_tiers.lua')
local tiers = blueprintConfig.Tiers
local types = blueprintConfig.BlueprintTypes
local UDN = UnitDefNames

--	facing:
--  0 - south
--  1 - east
--  2 - north
--  3 - west

local function nukeOutpost1()
	return {
		type = types.Land,
		tiers = { tiers.T3, tiers.T4 },
		radius =   80,
		buildings = {
			{ unitDefID = UDN.corshroud_scav.id, xOffset = 72,  zOffset = 72, direction = 3 },
			{ unitDefID = UDN.corvipe_scav.id,   xOffset =  0,  zOffset = 80, direction = 2 },
			{ unitDefID = UDN.corsilo_scav.id,   xOffset =  0,  zOffset =  0, direction = 1 },
			{ unitDefID = UDN.corshroud_scav.id, xOffset = 72,  zOffset = 72, direction = 3 },
			{ unitDefID = UDN.corshroud_scav.id, xOffset = 72,  zOffset = 72, direction = 3 },
			{ unitDefID = UDN.corvipe_scav.id,   xOffset =  0,  zOffset = 80, direction = 0 },
			{ unitDefID = UDN.corshroud_scav.id, xOffset = 72,  zOffset = 72, direction = 3 },
			{ unitDefID = UDN.corvipe_scav.id,   xOffset = 80,  zOffset =  0, direction = 3 },
			{ unitDefID = UDN.corvipe_scav.id,   xOffset = 80,  zOffset =  0, direction = 1 },
		},
	}
end

local function nukeOutpost2()
	return {
		type = types.Land,
		tiers = { tiers.T3, tiers.T4 },
		radius =  112,
		buildings = {
			{ unitDefID = UDN.corfmd_scav.id,      xOffset =  104,  zOffset =   24, direction = 1 },
			{ unitDefID = UDN.cordoom_scav.id,     xOffset =  104,  zOffset =   56, direction = 1 },
			{ unitDefID = UDN.corvipe_scav.id,     xOffset = -112,  zOffset =   96, direction = 0 },
			{ unitDefID = UDN.corsilo_scav.id,     xOffset =    0,  zOffset =    0, direction = 1 },
			{ unitDefID = UDN.corfmd_scav.id,      xOffset = -104,  zOffset =   24, direction = 1 },
			{ unitDefID = UDN.corscreamer_scav.id, xOffset =   24,  zOffset =  104, direction = 1 },
			{ unitDefID = UDN.corvipe_scav.id,     xOffset =   48,  zOffset =   96, direction = 0 },
			{ unitDefID = UDN.corvipe_scav.id,     xOffset =   48,  zOffset =   96, direction = 2 },
			{ unitDefID = UDN.cordoom_scav.id,     xOffset = -104,  zOffset =   56, direction = 3 },
			{ unitDefID = UDN.corvipe_scav.id,     xOffset =  112,  zOffset =   96, direction = 2 },
			{ unitDefID = UDN.corscreamer_scav.id, xOffset =   24,  zOffset = -104, direction = 1 },
		},
	}
end

local function nukeOutpost3()
	return {
		type = types.Land,
		tiers = { tiers.T3, tiers.T4 },
		radius =  192,
		buildings = {
			{ unitDefID = UDN.cordoom_scav.id, xOffset = -104,  zOffset =   56, direction = 3 },
			{ unitDefID = UDN.corsilo_scav.id, xOffset =    0,  zOffset =    0, direction = 2 },
			{ unitDefID = UDN.cortron_scav.id, xOffset =   24,  zOffset = -104, direction = 2 },
			{ unitDefID = UDN.corfmd_scav.id,  xOffset =   56,  zOffset = -104, direction = 2 },
			{ unitDefID = UDN.corvipe_scav.id, xOffset =  128,  zOffset =   96, direction = 1 },
			{ unitDefID = UDN.cortron_scav.id, xOffset =  104,  zOffset =   24, direction = 2 },
			{ unitDefID = UDN.cordoom_scav.id, xOffset =  104,  zOffset =   56, direction = 1 },
			{ unitDefID = UDN.corvipe_scav.id, xOffset =   96,  zOffset =  128, direction = 1 },
			{ unitDefID = UDN.corvipe_scav.id, xOffset =   96,  zOffset = -128, direction = 3 },
			{ unitDefID = UDN.cortron_scav.id, xOffset = -104,  zOffset =   24, direction = 2 },
			{ unitDefID = UDN.corfmd_scav.id,  xOffset =   56,  zOffset =  104, direction = 2 },
			{ unitDefID = UDN.cortron_scav.id, xOffset =   24,  zOffset =  104, direction = 2 },
			{ unitDefID = UDN.corint_scav.id,  xOffset =   16,  zOffset = -192, direction = 3 },
			{ unitDefID = UDN.corvipe_scav.id, xOffset = -128,  zOffset =   96, direction = 3 },
			{ unitDefID = UDN.corint_scav.id,  xOffset =   16,  zOffset =  192, direction = 1 },
		},
	}
end

local function nukeOutpost4()
	return {
		type = types.Land,
		tiers = { tiers.T3, tiers.T4 },
		radius =   80,
		buildings = {
			{ unitDefID = UDN.armveil_scav.id, xOffset = 72,  zOffset = 72, direction = 2 },
			{ unitDefID = UDN.armpb_scav.id,   xOffset =  0,  zOffset = 80, direction = 0 },
			{ unitDefID = UDN.armsilo_scav.id, xOffset =  0,  zOffset =  0, direction = 1 },
			{ unitDefID = UDN.armveil_scav.id, xOffset = 72,  zOffset = 72, direction = 2 },
			{ unitDefID = UDN.armpb_scav.id,   xOffset = 80,  zOffset =  0, direction = 1 },
			{ unitDefID = UDN.armveil_scav.id, xOffset = 72,  zOffset = 72, direction = 2 },
			{ unitDefID = UDN.armpb_scav.id,   xOffset = 80,  zOffset =  0, direction = 3 },
			{ unitDefID = UDN.armpb_scav.id,   xOffset =  0,  zOffset = 80, direction = 2 },
			{ unitDefID = UDN.armveil_scav.id, xOffset = 72,  zOffset = 72, direction = 2 },
		},
	}
end

local function nukeOutpost5()
	return {
		type = types.Land,
		tiers = { tiers.T3, tiers.T4 },
		radius =  112,
		buildings = {
			{ unitDefID = UDN.armanni_scav.id,    xOffset =  104,  zOffset =   56, direction = 1 },
			{ unitDefID = UDN.armamd_scav.id,     xOffset =  104,  zOffset =   24, direction = 2 },
			{ unitDefID = UDN.armamd_scav.id,     xOffset = -104,  zOffset =   24, direction = 2 },
			{ unitDefID = UDN.armmercury_scav.id, xOffset =   24,  zOffset =  104, direction = 1 },
			{ unitDefID = UDN.armsilo_scav.id,    xOffset =    0,  zOffset =    0, direction = 2 },
			{ unitDefID = UDN.armmercury_scav.id, xOffset =   24,  zOffset = -104, direction = 1 },
			{ unitDefID = UDN.armpb_scav.id,      xOffset = -112,  zOffset =   96, direction = 2 },
			{ unitDefID = UDN.armpb_scav.id,      xOffset =  112,  zOffset =   96, direction = 0 },
			{ unitDefID = UDN.armpb_scav.id,      xOffset =   48,  zOffset =   96, direction = 0 },
			{ unitDefID = UDN.armanni_scav.id,    xOffset = -104,  zOffset =   56, direction = 3 },
			{ unitDefID = UDN.armpb_scav.id,      xOffset =   48,  zOffset =   96, direction = 2 },
		},
	}
end

local function nukeOutpost6()
	return {
		type = types.Land,
		tiers = { tiers.T3, tiers.T4 },
		radius =  184,
		buildings = {
			{ unitDefID = UDN.armpb_scav.id,    xOffset =   96,  zOffset = -128, direction = 3 },
			{ unitDefID = UDN.armbrtha_scav.id, xOffset =    8,  zOffset =  184, direction = 3 },
			{ unitDefID = UDN.armamd_scav.id,   xOffset = -104,  zOffset =   56, direction = 1 },
			{ unitDefID = UDN.armamd_scav.id,   xOffset =  104,  zOffset =   56, direction = 1 },
			{ unitDefID = UDN.armpb_scav.id,    xOffset = -128,  zOffset =   96, direction = 3 },
			{ unitDefID = UDN.armemp_scav.id,   xOffset =   24,  zOffset =  104, direction = 1 },
			{ unitDefID = UDN.armemp_scav.id,   xOffset = -104,  zOffset =   24, direction = 1 },
			{ unitDefID = UDN.armsilo_scav.id,  xOffset =    0,  zOffset =    0, direction = 1 },
			{ unitDefID = UDN.armemp_scav.id,   xOffset =   24,  zOffset = -104, direction = 1 },
			{ unitDefID = UDN.armpb_scav.id,    xOffset =   96,  zOffset =  128, direction = 1 },
			{ unitDefID = UDN.armanni_scav.id,  xOffset =   56,  zOffset =  104, direction = 3 },
			{ unitDefID = UDN.armemp_scav.id,   xOffset =  104,  zOffset =   24, direction = 1 },
			{ unitDefID = UDN.armanni_scav.id,  xOffset =   56,  zOffset = -104, direction = 1 },
			{ unitDefID = UDN.armbrtha_scav.id, xOffset =    8,  zOffset = -184, direction = 1 },
			{ unitDefID = UDN.armpb_scav.id,    xOffset =  128,  zOffset =   96, direction = 1 },
		},
	}
end

local function nukeOutpost7()
	return {
		type = types.Land,
		tiers = { tiers.T3, tiers.T4 },
		radius =   64,
		buildings = {
			{ unitDefID = UDN.cordoom_scav.id,   xOffset = 64,  zOffset = 64, direction = 3 },
			{ unitDefID = UDN.cortron_scav.id,   xOffset = 64,  zOffset = 64, direction = 3 },
			{ unitDefID = UDN.cordoom_scav.id,   xOffset = 64,  zOffset = 64, direction = 1 },
			{ unitDefID = UDN.cortron_scav.id,   xOffset = 64,  zOffset = 64, direction = 3 },
			{ unitDefID = UDN.corshroud_scav.id, xOffset =  0,  zOffset =  0, direction = 3 },
		},
	}
end

local function nukeOutpost8()
	return {
		type = types.Land,
		tiers = { tiers.T3, tiers.T4 },
		radius =   64,
		buildings = {
			{ unitDefID = UDN.armanni_scav.id, xOffset = 64,  zOffset = 64, direction = 3 },
			{ unitDefID = UDN.armemp_scav.id,  xOffset = 64,  zOffset = 64, direction = 3 },
			{ unitDefID = UDN.armemp_scav.id,  xOffset = 64,  zOffset = 64, direction = 3 },
			{ unitDefID = UDN.armveil_scav.id, xOffset =  0,  zOffset =  0, direction = 3 },
			{ unitDefID = UDN.armanni_scav.id, xOffset = 64,  zOffset = 64, direction = 1 },
		},
	}
end

local function nukeOutpost9()
	return {
		type = types.Land,
		tiers = { tiers.T3, tiers.T4 },
		radius =  112,
		buildings = {
			{ unitDefID = UDN.corscreamer_scav.id, xOffset = -112,  zOffset =  112, direction = 1 },
			{ unitDefID = UDN.cortron_scav.id,     xOffset =    0,  zOffset =    0, direction = 1 },
			{ unitDefID = UDN.corscreamer_scav.id, xOffset =  112,  zOffset = -112, direction = 1 },
			{ unitDefID = UDN.corscreamer_scav.id, xOffset =    0,  zOffset =  112, direction = 1 },
			{ unitDefID = UDN.corscreamer_scav.id, xOffset =  112,  zOffset =    0, direction = 1 },
			{ unitDefID = UDN.corscreamer_scav.id, xOffset = -112,  zOffset = -112, direction = 1 },
			{ unitDefID = UDN.corscreamer_scav.id, xOffset = -112,  zOffset =    0, direction = 1 },
			{ unitDefID = UDN.corscreamer_scav.id, xOffset =  112,  zOffset =  112, direction = 1 },
			{ unitDefID = UDN.corscreamer_scav.id, xOffset =    0,  zOffset = -112, direction = 1 },
		},
	}
end

local function nukeOutpost10()
	return {
		type = types.Land,
		tiers = { tiers.T3, tiers.T4 },
		radius =   96,
		buildings = {
			{ unitDefID = UDN.armmercury_scav.id, xOffset = 96,  zOffset = 96, direction = 1 },
			{ unitDefID = UDN.armemp_scav.id,     xOffset =  0,  zOffset =  0, direction = 1 },
			{ unitDefID = UDN.armmercury_scav.id, xOffset = 96,  zOffset =  0, direction = 1 },
			{ unitDefID = UDN.armmercury_scav.id, xOffset =  0,  zOffset = 96, direction = 1 },
			{ unitDefID = UDN.armmercury_scav.id, xOffset = 96,  zOffset = 96, direction = 1 },
			{ unitDefID = UDN.armmercury_scav.id, xOffset = 96,  zOffset = 96, direction = 1 },
			{ unitDefID = UDN.armmercury_scav.id, xOffset = 96,  zOffset = 96, direction = 1 },
			{ unitDefID = UDN.armmercury_scav.id, xOffset =  0,  zOffset = 96, direction = 1 },
			{ unitDefID = UDN.armmercury_scav.id, xOffset = 96,  zOffset =  0, direction = 1 },
		},
	}
end

return {
	nukeOutpost1,
	nukeOutpost2,
	nukeOutpost3,
	nukeOutpost4,
	nukeOutpost5,
	nukeOutpost6,
	nukeOutpost7,
	nukeOutpost8,
	nukeOutpost9,
	nukeOutpost10,
}