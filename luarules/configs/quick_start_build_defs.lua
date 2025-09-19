local quickStartConfig = {
	discountableFactories = {
		armap = true, armfhp = true, armhp = true, armlab = true, armsy = true, armvp = true,
		corap = true, corfhp = true, corhp = true, corlab = true, corsy = true, corvp = true,
		legap = true, legfhp = true, leghp = true, leglab = true, legsy = true, legvp = true,
	},
	commanderNonLabOptions = {
		armcom = {
			windmill = "armwin",
			mex = "armmex",
			converter = "armmakr",
			solar = "armsolar",
			tidal = "armtide",
			floatingConverter = "armfmkr",
		},
		corcom = {
			windmill = "corwin",
			mex = "cormex",
			converter = "cormakr",
			solar = "corsolar",
			tidal = "cortide",
			floatingConverter = "corfmkr",
		},
		legcom = {
			windmill = "legwin",
			mex = "legmex",
			converter = "legeconv",
			solar = "legsolar",
			tidal = "legtide",
			floatingConverter = "legfconv",
		}
	},
	optionsToNodeType = {
		windmill = "other",
		mex = "other",
		converter = "converters",
		solar = "other",
		tidal = "other",
		floatingConverter = "converters",
	},
	quotas = {
		["metalMap"] = {
			["land"] = {
				["noWind"] = {mex = 3, windmill = 0, converter = 0, solar = 4, tidal = 0, floatingConverter = 0},
				["goodWind"] = {mex = 3, windmill = 4, converter = 0, solar = 1, tidal = 0, floatingConverter = 0}
			},
			["water"] = {
				["noWind"] = {mex = 4, windmill = 0, converter = 0, solar = 0, tidal = 5, floatingConverter = 1},
				["goodWind"] = {mex = 4, windmill = 0, converter = 0, solar = 0, tidal = 5, floatingConverter = 1}
			}
		},
		["nonMetalMap"] = {
			["land"] = {
				["noWind"] = {mex = 3, windmill = 0, converter = 2, solar = 4, tidal = 0, floatingConverter = 0},
				["goodWind"] = {mex = 3, windmill = 4, converter = 2, solar = 1, tidal = 0, floatingConverter = 0}
			},
			["water"] = {
				["noWind"] = {mex = 3, windmill = 0, converter = 0, solar = 0, tidal = 5, floatingConverter = 2},
				["goodWind"] = {mex = 3, windmill = 0, converter = 0, solar = 0, tidal = 5, floatingConverter = 2}
			}
		}
	}
}

return quickStartConfig

