local buildQuotaConfigs = {
	-- [isMetalMap][isInWater][isGoodWind] = {mex, windmill, converter, solar, tidal, floatingConverter}
	["metalMap"] = {
		["land"] = {
			["noWind"] = {mex = 4, windmill = 0, converter = 0, solar = 4, tidal = 0, floatingConverter = 0},
			["goodWind"] = {mex = 4, windmill = 4, converter = 0, solar = 1, tidal = 0, floatingConverter = 0}
		},
		["water"] = {
			["noWind"] = {mex = 4, windmill = 0, converter = 0, solar = 0, tidal = 5, floatingConverter = 1},
			["goodWind"] = {mex = 4, windmill = 0, converter = 0, solar = 0, tidal = 5, floatingConverter = 1}
		}
	},
	["nonMetalMap"] = {
		["land"] = {
			["noWind"] = {mex = 4, windmill = 0, converter = 2, solar = 4, tidal = 0, floatingConverter = 0},
			["goodWind"] = {mex = 4, windmill = 4, converter = 2, solar = 1, tidal = 0, floatingConverter = 0}
		},
		["water"] = {
			["noWind"] = {mex = 4, windmill = 0, converter = 0, solar = 0, tidal = 5, floatingConverter = 1},
			["goodWind"] = {mex = 4, windmill = 0, converter = 0, solar = 0, tidal = 5, floatingConverter = 1}
		}
	}
}

return buildQuotaConfigs
