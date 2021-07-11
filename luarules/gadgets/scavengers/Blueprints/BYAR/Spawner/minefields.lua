local scavConfig = VFS.Include('luarules/gadgets/scavengers/Configs/BYAR/config.lua')
local tiers = scavConfig.Tiers
local types = scavConfig.BlueprintTypes
local UDN = UnitDefNames

local function lightMinefield1()
	local unitPool = { UDN.armmine1_scav.id, UDN.armmine1_scav.id, UDN.armmine1_scav.id, UDN.armmine2_scav.id, }

	return {
		radius =  100,
		type = types.Land,
		tiers = { tiers.T1 },
		buildings = {
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset = -35, zOffset = -35, direction = 2 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =  35, zOffset = -35, direction = 2 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset = -35, zOffset =  35, direction = 2 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =  35, zOffset =  35, direction = 2 },
		},
	}
end

local function lightMinefield2()
	local unitPool = { UDN.armmine1_scav.id, UDN.armmine1_scav.id, UDN.armmine1_scav.id, UDN.armmine2_scav.id, }

	return {
		radius =  100,
		type = types.Land,
		tiers = { tiers.T1 },
		buildings = {
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset = -100, zOffset = -25, direction = 2 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =  -50, zOffset = -25, direction = 2 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =    0, zOffset = -25, direction = 2 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =   50, zOffset = -25, direction = 2 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =  100, zOffset = -25, direction = 2 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset = -100, zOffset =  25, direction = 2 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =  -50, zOffset =  25, direction = 2 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =    0, zOffset =  25, direction = 2 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =   50, zOffset =  25, direction = 2 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =  100, zOffset =  25, direction = 2 },
		},
	}
end

local function mediumMinefield1()
	local unitPool = { UDN.armmine2_scav.id, UDN.armmine2_scav.id, UDN.armmine2_scav.id, UDN.armmine2_scav.id, }

	return {
		radius =  100,
		type = types.Land,
		tiers = { tiers.T2 },
		buildings = {
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset = -100, zOffset = -25, direction = 2 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =  -50, zOffset = -25, direction = 2 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =    0, zOffset = -25, direction = 2 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =   50, zOffset = -25, direction = 2 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =  100, zOffset = -25, direction = 2 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset = -100, zOffset =  25, direction = 2 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =  -50, zOffset =  25, direction = 2 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =    0, zOffset =  25, direction = 2 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =   50, zOffset =  25, direction = 2 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =  100, zOffset =  25, direction = 2 },
		},
	}
end

local function heavyMinefield1()
	local unitPool = { UDN.armmine3_scav.id, UDN.armmine2_scav.id, UDN.armmine3_scav.id, UDN.armmine3_scav.id, }

	return {
		radius =   80,
		type = types.Land,
		tiers = { tiers.T3, tiers.T4 },
		buildings = {
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset = -30, zOffset = -60, direction = 2 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset = -60, zOffset = -30, direction = 2 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =   0, zOffset = -30, direction = 2 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =  60, zOffset = -30, direction = 2 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =  30, zOffset = -60, direction = 2 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset = -30, zOffset =  60, direction = 2 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset = -60, zOffset =  30, direction = 2 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =   0, zOffset =  30, direction = 2 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =  60, zOffset =  30, direction = 2 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =  30, zOffset =  60, direction = 2 },
		},
	}
end

local function heavyMinefield2()
	local unitPool = { UDN.armmine3_scav.id, UDN.armmine2_scav.id, UDN.armmine2_scav.id, UDN.armmine3_scav.id, }

	return {
		radius =  120,
		type = types.Land,
		tiers = { tiers.T3, tiers.T4 },
		buildings = {
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =  -50, zOffset = -100, direction = 2 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =  -50, zOffset =  100, direction = 2 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset = -100, zOffset =  -50, direction = 2 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset = -100, zOffset =   50, direction = 2 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =    0, zOffset =  -50, direction = 2 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =    0, zOffset =   50, direction = 2 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =   50, zOffset =  100, direction = 2 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =   50, zOffset = -100, direction = 2 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =  100, zOffset =  -50, direction = 2 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =  100, zOffset =   50, direction = 2 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset = -100, zOffset = -100, direction = 2 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset = -100, zOffset =  100, direction = 2 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset = -150, zOffset =   50, direction = 2 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset = -150, zOffset =  -50, direction = 2 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =  150, zOffset =   50, direction = 2 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =  150, zOffset =  -50, direction = 2 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =  200, zOffset =    0, direction = 2 },
			{ unitDefID = unitPool[math.random(1, #unitPool)], xOffset =  200, zOffset =    0, direction = 2 },
		},
	}
end

return {
	lightMinefield1,
	lightMinefield2,
	mediumMinefield1,
	heavyMinefield1,
	heavyMinefield2,
}