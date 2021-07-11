local scavConfig = VFS.Include('luarules/gadgets/scavengers/Configs/BYAR/config.lua')
local tiers = scavConfig.Tiers
local types = scavConfig.BlueprintTypes
local UDN = UnitDefNames

local function radarOutpostRed1()
	local unitPool = { UDN.corllt_scav.id, UDN.corllt_scav.id, UDN.corhllt_scav.id, UDN.cormaw_scav.id, UDN.corrl_scav.id, }

	return {
		radius =  100,
		type = types.Land,
		tiers = { tiers.T0, tiers.T1, },
		buildings = {
			{ unitDefID = UDN.corarad_scav.id,                 xOffset =    0, zOffset =    0, direction = math_random(0,3) },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset = -100, zOffset =    0, direction = 3 },
			{ unitDefID = UDN.corjamt_scav.id,                 xOffset =  100, zOffset =    0, direction = math_random(0,3) },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =    0, zOffset = -100, direction = 2 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =    0, zOffset =  100, direction = 0 },
		},
	}
end

local function radarOutpostRed2()
	local unitPool = { UDN.corllt_scav.id, UDN.corllt_scav.id, UDN.corhllt_scav.id, UDN.corrad_scav.id, UDN.corerad_scav.id, }

	return {
		radius =  100,
		type = types.Land,
		tiers = { tiers.T1, tiers.T2, },
		buildings = {
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset = -100, zOffset =    0, direction = 3 },
			{ unitDefID = UDN.corjamt_scav.id,                 xOffset =    0, zOffset =    0, direction = math_random(0,3) },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =    0, zOffset = -100, direction = 2 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =    0, zOffset =  100, direction = 0 },
		},
	}
end

local function radarOutpostBlue1()
	local unitPool = { UDN.armllt_scav.id, UDN.armllt_scav.id, UDN.armllt_scav.id, UDN.armclaw_scav.id, UDN.armrl_scav.id, }

	return {
		radius =  100,
		type = types.Land,
		tiers = { tiers.T0, tiers.T1, },
		buildings = {
			{ unitDefID = UDN.armarad_scav.id,                 xOffset =    0, zOffset =    0, direction = math_random(0,3) },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset = -100, zOffset =    0, direction = 3 },
			{ unitDefID = UDN.armjamt_scav.id,                 xOffset =  100, zOffset =    0, direction = math_random(0,3) },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =    0, zOffset = -100, direction = 0 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =    0, zOffset =  100, direction = 2 },
		},
	}
end

local function radarOutpostBlue2()
	local unitPool = { UDN.armllt_scav.id, UDN.armllt_scav.id, UDN.armrad_scav.id, UDN.armdrag_scav.id, UDN.armcir_scav.id, }

	return {
		radius =  100,
		type = types.Land,
		tiers = { tiers.T1, tiers.T2, },
		buildings = {
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset = -100, zOffset =    0, direction = 3 },
			{ unitDefID = UDN.armjamt_scav.id,                 xOffset =    0, zOffset =    0, direction = math_random(0,3) },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =    0, zOffset = -100, direction = 0 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =    0, zOffset =  100, direction = 2 },
		},
	}
end

local function roadblockRed()
	local unitPool = { UDN.cordrag_scav.id, UDN.cordrag_scav.id, UDN.cordrag_scav.id, UDN.cormaw_scav.id, UDN.cordrag_scav.id, }

	return {
		radius =   30,
		type = types.Land,
		tiers = { tiers.T1, },
		buildings = {
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset = 60, zOffset = 60, direction = math_random(0,3) },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset = 30, zOffset = 30, direction = math_random(0,3) },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =  0, zOffset =  0, direction = math_random(0,3) },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset = 30, zOffset = 30, direction = math_random(0,3) },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset = 60, zOffset = 60, direction = math_random(0,3) },
		},
	}
end

local function roadblockBlue()
	local unitPool = { UDN.armdrag_scav.id, UDN.armdrag_scav.id, UDN.armdrag_scav.id, UDN.armclaw_scav.id, UDN.armdrag_scav.id, }

	return {
		radius =   30,
		type = types.Land,
		tiers = { tiers.T0, tiers.T1, },
		buildings = {
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset = 60, zOffset = 60, direction = math_random(0,3) },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset = 30, zOffset = 30, direction = math_random(0,3) },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =  0, zOffset =  0, direction = math_random(0,3) },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset = 30, zOffset = 30, direction = math_random(0,3) },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset = 60, zOffset = 60, direction = math_random(0,3) },
		},
	}
end

local function mediumAntiAirOutpostRed()

	return {
		radius =   80,
		type = types.Land,
		tiers = { tiers.T2, tiers.T3, },
		buildings = {
			{ unitDefID = UDN.corflak_scav.id,   xOffset = 50, zOffset = 50, direction = 3 },
			{ unitDefID = UDN.corflak_scav.id,   xOffset = 50, zOffset = 50, direction = 1 },
			{ unitDefID = UDN.corshroud_scav.id, xOffset = 50, zOffset = 50, direction = 0 },
			{ unitDefID = UDN.corarad_scav.id,   xOffset = 50, zOffset = 50, direction = 2 },
		},
	}
end

local function mediumAntiAirOutpostBlue()

	return {
		radius =   80,
		type = types.Land,
		tiers = { tiers.T2, tiers.T3, },
		buildings = {
			{ unitDefID = UDN.armflak_scav.id, xOffset = 50, zOffset = 50, direction = math_random(0,3) },
			{ unitDefID = UDN.armflak_scav.id, xOffset = 50, zOffset = 50, direction = math_random(0,3) },
			{ unitDefID = UDN.armveil_scav.id, xOffset = 50, zOffset = 50, direction = math_random(0,3) },
			{ unitDefID = UDN.armarad_scav.id, xOffset = 50, zOffset = 50, direction = math_random(0,3) },
		},
	}
end

local function mediumRadarOutpostRed1()
	return {
		radius =  100,
		type = types.Land,
		tiers = { tiers.T2, tiers.T3, },
		buildings = {
			{ unitDefID = UDN.corarad_scav.id,   xOffset =  0, zOffset =  0, direction = math_random(0,3) },
			{ unitDefID = UDN.corfort_scav.id,   xOffset = 30, zOffset =  0, direction = math_random(0,3) },
			{ unitDefID = UDN.corfort_scav.id,   xOffset =  0, zOffset = 30, direction = math_random(0,3) },
			{ unitDefID = UDN.corfort_scav.id,   xOffset = 30, zOffset =  0, direction = math_random(0,3) },
			{ unitDefID = UDN.corfort_scav.id,   xOffset =  0, zOffset = 30, direction = math_random(0,3) },
			{ unitDefID = UDN.corshroud_scav.id, xOffset = 90, zOffset =  0, direction = math_random(0,3) },
		},
	}
end

local function mediumRadarOutpostRed2()
	local unitPool = { UDN.corhlt_scav.id, UDN.corhlt_scav.id, UDN.corhllt_scav.id, UDN.corvipe_scav.id, UDN.corflak_scav.id, }

	return {
		radius =  100,
		type = types.Land,
		tiers = { tiers.T2, tiers.T3, },
		buildings = {
			{ unitDefID = UDN.corarad_scav.id,                 xOffset =    0, zOffset =    0, direction = math_random(0,3) },
			{ unitDefID = UDN.corfort_scav.id,                 xOffset =   30, zOffset =    0, direction = math_random(0,3) },
			{ unitDefID = UDN.corfort_scav.id,                 xOffset =    0, zOffset =   30, direction = math_random(0,3) },
			{ unitDefID = UDN.corfort_scav.id,                 xOffset =   30, zOffset =    0, direction = math_random(0,3) },
			{ unitDefID = UDN.corfort_scav.id,                 xOffset =    0, zOffset =   30, direction = math_random(0,3) },
			{ unitDefID = UDN.corshroud_scav.id,               xOffset =   90, zOffset =    0, direction = math_random(0,3) },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset = -120, zOffset =    0, direction = 3 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =  150, zOffset =    0, direction = 1 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =   30, zOffset =  100, direction = 0 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =   60, zOffset =  100, direction = 0 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =   30, zOffset = -100, direction = 2 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =   60, zOffset = -100, direction = 2 },
		},
	}
end

local function mediumRadarOutpostRed3()
	local unitPool = { UDN.corhlt_scav.id, UDN.corhlt_scav.id, UDN.corvipe_scav.id, UDN.corvipe_scav.id, UDN.corflak_scav.id, }

	return {
		radius =  100,
		type = types.Land,
		tiers = { tiers.T2, tiers.T3, },
		buildings = {
			{ unitDefID = UDN.corarad_scav.id,                 xOffset =   30, zOffset =    0, direction = math_random(0,3) },
			{ unitDefID = UDN.corshroud_scav.id,               xOffset =   30, zOffset =    0, direction = math_random(0,3) },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset = -120, zOffset =    0, direction = 3 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =  120, zOffset =    0, direction = 1 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =   40, zOffset =  100, direction = 0 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =   40, zOffset =  100, direction = 0 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =   40, zOffset = -100, direction = 2 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =   40, zOffset = -100, direction = 2 },
		},
	}
end

local function lightOutpostBlue1()
	local unitPool = { UDN.armpb_scav.id, UDN.armferret_scav.id, }

	return {
		radius =  100,
		type = types.Land,
		tiers = { tiers.T2, tiers.T3, },
		buildings = {
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset = 60, zOffset = 0, direction = 3 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset = 60, zOffset = 0, direction = 1 },
		},
	}
end

local function mediumOutpostBlue1()
	local unitPool = { UDN.armpb_scav.id, UDN.armamb_scav.id, UDN.armferret_scav.id, }

	return {
		radius =  100,
		type = types.Land,
		tiers = { tiers.T3, },
		buildings = {
			{ unitDefID = UDN.armckfus_scav.id,                xOffset =    0, zOffset =    0, direction = 1 },
			{ unitDefID = UDN.armferret_scav.id,               xOffset = -120, zOffset =    0, direction = 3 },
			{ unitDefID = UDN.armferret_scav.id,               xOffset =  120, zOffset =    0, direction = 1 },
			{ unitDefID = UDN.armeyes_scav.id,                 xOffset =    0, zOffset =  170, direction = 0 },
			{ unitDefID = UDN.armeyes_scav.id,                 xOffset =    0, zOffset = -170, direction = 2 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset = -100, zOffset =   70, direction = 3 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =  100, zOffset =   70, direction = 1 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset = -100, zOffset =   70, direction = 3 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =  100, zOffset =   70, direction = 1 },
		},
	}
end

local function fusionOutpostBlue()

	return {
		radius =  100,
		type = types.Land,
		tiers = { tiers.T3, },
		buildings = {
			{ unitDefID = UDN.armckfus_scav.id,  xOffset =    0, zOffset = 0, direction = 1 },
			{ unitDefID = UDN.armferret_scav.id, xOffset = -120, zOffset = 0, direction = 3 },
			{ unitDefID = UDN.armferret_scav.id, xOffset =  120, zOffset = 0, direction = 1 },
		},
	}
end

local function heavyOutpostRed1()
	local unitPool = { UDN.corvipe_scav.id, UDN.cortoast_scav.id, UDN.corarad_scav.id, }
	local unitPoolAA = { UDN.corscreamer_scav.id, UDN.corflak_scav.id, }

	return {
		radius =  100,
		type = types.Land,
		tiers = { tiers.T3, },
		buildings = {
			{ unitDefID = UDN.corgate_scav.id,                     xOffset =    0, zOffset =    0, direction = 1 },
			{ unitDefID = UDN.cordoom_scav.id,                     xOffset = -160, zOffset =    0, direction = 3 },
			{ unitDefID = UDN.cordoom_scav.id,                     xOffset =  160, zOffset =    0, direction = 1 },
			{ unitDefID = unitPoolAA[math.random(1, #unitPoolAA)], xOffset =    0, zOffset =  150, direction = 0 },
			{ unitDefID = unitPoolAA[math.random(1, #unitPoolAA)], xOffset =    0, zOffset = -150, direction = 2 },
			{ unitDefID = unitPool[math.random(1, #unitPool)],     xOffset = -100, zOffset =   70, direction = 3 },
			{ unitDefID = unitPool[math.random(1, #unitPool)],     xOffset =  100, zOffset =   70, direction = 1 },
			{ unitDefID = unitPool[math.random(1, #unitPool)],     xOffset = -100, zOffset =   70, direction = 3 },
			{ unitDefID = unitPool[math.random(1, #unitPool)],     xOffset =  100, zOffset =   70, direction = 1 },
		},
	}
end

local function heavyOutpostBlue1()

	return {
		radius =  100,
		type = types.Land,
		tiers = { tiers.T3 },
		buildings = {
			{ unitDefID = UDN.armflak_scav.id, xOffset =  0, zOffset =  0, direction = 2 },
			{ unitDefID = UDN.armanni_scav.id, xOffset = 60, zOffset = 60, direction = 3 },
			{ unitDefID = UDN.armanni_scav.id, xOffset = 60, zOffset = 60, direction = 1 },
			{ unitDefID = UDN.armanni_scav.id, xOffset = 60, zOffset = 60, direction = 2 },
			{ unitDefID = UDN.armanni_scav.id, xOffset = 60, zOffset = 60, direction = 0 },
		},
	}
end

local function heavyOutpostRed2()

	return {
		radius =  110,
		type = types.Land,
		tiers = { tiers.T3, },
		buildings = {
			{ unitDefID = UDN.corflak_scav.id, xOffset =  0, zOffset =  0, direction = 2 },
			{ unitDefID = UDN.cordoom_scav.id, xOffset = 60, zOffset = 60, direction = 3 },
			{ unitDefID = UDN.cordoom_scav.id, xOffset = 60, zOffset = 60, direction = 1 },
			{ unitDefID = UDN.corflak_scav.id, xOffset = 60, zOffset = 60, direction = 2 },
			{ unitDefID = UDN.corarad_scav.id, xOffset = 60, zOffset = 60, direction = 0 },
		},
	}
end

local function heavyArtilleryOutpostRed()

	return {
		radius =  110,
		type = types.Land,
		tiers = { tiers.T3, },
		buildings = {
			{ unitDefID = UDN.corint_scav.id,  xOffset =    0, zOffset =  0, direction = math_random(0,3) },
			{ unitDefID = UDN.corarad_scav.id, xOffset = -120, zOffset = 30, direction = 3 },
		},
	}
end

local function heavyArtillertOutpostBlue()

	return {
		radius =  100,
		type = types.Land,
		tiers = { tiers.T3, },
		buildings = {
			{ unitDefID = UDN.armflak_scav.id,  xOffset = 20, zOffset = 80, direction = 0 },
			{ unitDefID = UDN.armbrtha_scav.id, xOffset = 60, zOffset = 20, direction = 0 },
			{ unitDefID = UDN.armbrtha_scav.id, xOffset = 60, zOffset = 20, direction = 0 },
		},
	}
end

return {
	radarOutpostRed1,
	radarOutpostRed2,
	radarOutpostBlue1,
	radarOutpostBlue2,
	roadblockRed,
	roadblockBlue,
	mediumAntiAirOutpostRed,
	mediumAntiAirOutpostBlue,
	mediumRadarOutpostRed1,
	mediumRadarOutpostRed2,
	mediumRadarOutpostRed3,
	lightOutpostBlue1,
	mediumOutpostBlue1,
	fusionOutpostBlue,
	heavyOutpostRed1,
	-- heavyOutpostBlue1,
	heavyOutpostRed2,
	heavyArtilleryOutpostRed,
	heavyArtillertOutpostBlue,
}