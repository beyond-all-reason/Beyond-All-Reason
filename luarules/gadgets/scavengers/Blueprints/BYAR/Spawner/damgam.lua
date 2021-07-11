local scavConfig = VFS.Include('luarules/gadgets/scavengers/Configs/BYAR/config.lua')
local tiers = scavConfig.Tiers
local types = scavConfig.BlueprintTypes
local UDN = UnitDefNames

local function radarCor()
	return {
		radius = 50,
		type = types.Land,
		tiers = { tiers.T0, tiers.T1, },
		buildings = {
			{ unitDefID = UDN.corrad_scav.id, xOffset = 0, zOffset = 0, direction = math.random(0, 3) },
		},
	}
end

local function radarArm()
	return {
		radius = 50,
		type = types.Land,
		tiers = { tiers.T0, tiers.T1, },
		buildings = {
			{ unitDefID = UDN.armrad_scav.id, xOffset = 0, zOffset = 0, direction = math.random(0, 3) },
		},
	}
end

local function adavancedRadarCor()
	return {
		radius = 50,
		type = types.Land,
		tiers = { tiers.T2, tiers.T3, },
		buildings = {
			{ unitDefID = UDN.corarad_scav.id, xOffset = 0, zOffset = 0, direction = math.random(0, 3) },
		},
	}
end

local function advancedRadarArm()
	return {
		radius = 50,
		type = types.Land,
		tiers = { tiers.T2, tiers.T3, },
		buildings = {
			{ unitDefID = UDN.armarad_scav.id, xOffset = 0, zOffset = 0, direction = math.random(0, 3) },
		},
	}
end

local function sonarCor()
	return {
		radius = 50,
		type = types.Sea,
		tiers = { tiers.T0, tiers.T1, },
		buildings = {
			{ unitDefID = UDN.corsonar_scav.id, xOffset = 0, zOffset = 0, direction = math.random(0, 3) },
		},
	}
end

local function sonarArm()
	return {
		radius = 50,
		type = types.Sea,
		tiers = { tiers.T0, tiers.T1, },
		buildings = {
			{ unitDefID = UDN.armsonar_scav.id, xOffset = 0, zOffset = 0, direction = math.random(0, 3) },
		},
	}
end

local function advancedSonarCor()
	return {
		radius = 50,
		type = types.Sea,
		tiers = { tiers.T2, tiers.T3, },
		buildings = {
			{ unitDefID = UDN.corason_scav.id, xOffset = 0, zOffset = 0, direction = math.random(0, 3) },
		},
	}
end

local function advancedSonerArm()
	return {
		radius = 50,
		type = types.Sea,
		tiers = { tiers.T2, tiers.T3, },
		buildings = {
			{ unitDefID = UDN.armason_scav.id, xOffset = 0, zOffset = 0, direction = math.random(0, 3) },
		},
	}
end

local function torpedoArm()
	return {
		radius = 50,
		type = types.Sea,
		tiers = { tiers.T1, tiers.T2, },
		buildings = {
			{ unitDefID = UDN.armtl_scav.id, xOffset = 0, zOffset = 0, direction = math.random(0, 3) },
		},
	}
end

local function advancedTorpedoCor()
	return {
		radius = 50,
		type = types.Sea,
		tiers = { tiers.T2, tiers.T3, },
		buildings = {
			{ unitDefID = UDN.coratl_scav.id, xOffset = 0, zOffset = 0, direction = math.random(0, 3) },
		},
	}
end

return {
	radarCor,
	radarArm,
	adavancedRadarCor,
	advancedRadarArm,
	sonarCor,
	sonarArm,
	advancedSonarCor,
	advancedSonerArm,
	torpedoArm,
	advancedTorpedoCor,
}