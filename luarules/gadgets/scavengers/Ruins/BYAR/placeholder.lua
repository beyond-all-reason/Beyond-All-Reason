local scavConfig = VFS.Include('luarules/gadgets/scavengers/Configs/BYAR/config.lua')
local types = scavConfig.BlueprintTypes

local function corLonelyWind()
	return {
		radius = 64,
		type = types.Land,
		buildings = {
			{ unitDefID = UnitDefNames.corwin.id, xOffset =   0, zOffset =   0, direction = math.random(0, 3) },
			{ unitDefID = UnitDefNames.corwin.id, xOffset =  48, zOffset =   0, direction = math.random(0, 3) },
			{ unitDefID = UnitDefNames.corwin.id, xOffset = -48, zOffset =   0, direction = math.random(0, 3) },
			{ unitDefID = UnitDefNames.corwin.id, xOffset =   0, zOffset =  48, direction = math.random(0, 3) },
			{ unitDefID = UnitDefNames.corwin.id, xOffset =   0, zOffset = -48, direction = math.random(0, 3) },
			{ unitDefID = UnitDefNames.corak.id,  xOffset =  96, zOffset =   0, direction = math.random(0, 3), patrol = true },
			{ unitDefID = UnitDefNames.corak.id,  xOffset = -96, zOffset =   0, direction = math.random(0, 3) },
			{ unitDefID = UnitDefNames.corak.id,  xOffset =   0, zOffset =  96, direction = math.random(0, 3) },
			{ unitDefID = UnitDefNames.corak.id,  xOffset =   0, zOffset = -96, direction = math.random(0, 3) },
		},
	}
end

local function armLonelyWind()
	return {
		radius = 64,
		type = types.Land,
		buildings = {
			{ unitDefID = UnitDefNames.armwin.id, xOffset =   0, zOffset =   0, direction = math.random(0, 3) },
			{ unitDefID = UnitDefNames.armwin.id, xOffset =  48, zOffset =   0, direction = math.random(0, 3) },
			{ unitDefID = UnitDefNames.armwin.id, xOffset = -48, zOffset =   0, direction = math.random(0, 3) },
			{ unitDefID = UnitDefNames.armwin.id, xOffset =   0, zOffset =  48, direction = math.random(0, 3) },
			{ unitDefID = UnitDefNames.armwin.id, xOffset =   0, zOffset = -48, direction = math.random(0, 3) },
			{ unitDefID = UnitDefNames.armpw.id,  xOffset =  96, zOffset =   0, direction = math.random(0, 3), patrol = true },
			{ unitDefID = UnitDefNames.armpw.id,  xOffset = -96, zOffset =   0, direction = math.random(0, 3) },
			{ unitDefID = UnitDefNames.armpw.id,  xOffset =   0, zOffset =  96, direction = math.random(0, 3) },
			{ unitDefID = UnitDefNames.armpw.id,  xOffset =   0, zOffset = -96, direction = math.random(0, 3), patrol = true },
		},
	}
end

local function corLonelySolar()
	return {
		radius = 50,
		type = types.Land,
		buildings = {
			{ unitDefID = UnitDefNames.corsolar.id, xOffset = 0, zOffset = 0, direction = math.random(0, 3) },

		},
	}
end

local function armLonelySolar()
	return {
		radius = 50,
		type = types.Land,
		buildings = {
			{ unitDefID = UnitDefNames.armsolar.id, xOffset = 0, zOffset = 0, direction = math.random(0, 3) },
		},
	}
end


-- Lonely Sonars

local function corLonelyTidal2()
	return {
		radius = 64,
		type = types.Sea,
		buildings = {
			{ unitDefID = UnitDefNames.cortide.id, xOffset =   0, zOffset =   0, direction = math.random(0, 3) },
			{ unitDefID = UnitDefNames.cortide.id, xOffset =  48, zOffset =   0, direction = math.random(0, 3) },
			{ unitDefID = UnitDefNames.cortide.id, xOffset = -48, zOffset =   0, direction = math.random(0, 3) },
			{ unitDefID = UnitDefNames.cortide.id, xOffset =   0, zOffset =  48, direction = math.random(0, 3) },
			{ unitDefID = UnitDefNames.cortide.id, xOffset =   0, zOffset = -48, direction = math.random(0, 3) },
		},
	}
end

local function armLonelyTidal2()
	return {
		radius = 64,
		type = types.Sea,
		buildings = {
			{ unitDefID = UnitDefNames.armtide.id, xOffset =   0, zOffset =   0, direction = math.random(0, 3) },
			{ unitDefID = UnitDefNames.armtide.id, xOffset =  48, zOffset =   0, direction = math.random(0, 3) },
			{ unitDefID = UnitDefNames.armtide.id, xOffset = -48, zOffset =   0, direction = math.random(0, 3) },
			{ unitDefID = UnitDefNames.armtide.id, xOffset =   0, zOffset =  48, direction = math.random(0, 3) },
			{ unitDefID = UnitDefNames.armtide.id, xOffset =   0, zOffset = -48, direction = math.random(0, 3) },
		},
	}
end

local function corLonelyTidal()
	return {
		radius = 50,
		type = types.Sea,
		buildings = {
			{ unitDefID = UnitDefNames.cortide.id, xOffset = 0, zOffset =0, direction = math.random(0, 3) },

		},
	}
end

local function armLonelyTidal()
	return {
		radius = 50,
		type = types.Sea,
		buildings = {
			{ unitDefID = UnitDefNames.armtide.id, xOffset = 0, zOffset = 0, direction = math.random(0, 3) },
		},
	}
end

return {
	corLonelyWind,
	armLonelyWind,
	corLonelySolar,
	armLonelySolar,
	corLonelyTidal2,
	armLonelyTidal2,
	corLonelyTidal,
	armLonelyTidal	,
}