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
			landEnergyStorage = "armestor",
			waterEnergyStorage = "armuwes",
		},
		corcom = {
			windmill = "corwin",
			mex = "cormex",
			converter = "cormakr",
			solar = "corsolar",
			tidal = "cortide",
			floatingConverter = "corfmkr",
			landEnergyStorage = "corestor",
			waterEnergyStorage = "coruwes",
		},
		legcom = {
			windmill = "legwin",
			mex = "legmex",
			converter = "legeconv",
			solar = "legsolar",
			tidal = "legtide",
			floatingConverter = "legfeconv",
			landEnergyStorage = "legestor",
			waterEnergyStorage = "leguwestore",
		}
	},
	optionsToNodeType = {
		windmill = "other",
		mex = "other",
		converter = "converters",
		solar = "other",
		tidal = "other",
		floatingConverter = "converters",
		landEnergyStorage = "other",
		waterEnergyStorage = "other",
	},
	quotas = {
		["metalMap"] = {
			["land"] = {
				["badWind"] = {
					"mex",
					"mex", 
					"mex",
					"solar",
					"solar",
					"solar",
					"solar",
					"solar",
					"solar",
					"solar",
					"solar",
					"solar",
					"solar",
					"solar",
					"landEnergyStorage",
				},
				["goodWind"] = {
					"mex",
					"mex",
					"windmill",
					"windmill",
					"windmill",
					"mex",
					"windmill",
					"windmill",
					"windmill",
					"windmill",
					"windmill",
					"solar",
					"solar",
					"solar",
					"landEnergyStorage",
				}
			},
			["water"] = {
				["badWind"] = {
					"mex",
					"mex",
					"mex",
					"mex",
					"tidal",
					"tidal",
					"tidal",
					"tidal",
					"tidal",
					"floatingConverter",
					"waterEnergyStorage",
				},
				["goodWind"] = {
					"mex",
					"mex",
					"mex",
					"mex",
					"tidal",
					"tidal",
					"tidal",
					"tidal",
					"tidal",
					"floatingConverter",
					"waterEnergyStorage",
				}
			}
		},
		["nonMetalMap"] = {
			["land"] = {
				["badWind"] = {
					"solar",
					"solar",
					"solar",
					"solar",
					"mex",
					"mex",
					"mex",
					"mex",
					"mex",
					"converter",
					"solar",
					"solar",
				},
				["goodWind"] = {
					"mex",
					"mex",
					"windmill",
					"mex",
					"windmill",
					"windmill",
					"mex", --100 extra base budget?
					"converter", --if no mex, this will be built
					"solar",
					"windmill",
					"windmill",
					"windmill",
					"windmill",
					"windmill",
					"landEnergyStorage",
					"windmill",
					"windmill",
					"converter", --if there's only two mex built, this is made
				}
			},
			["water"] = {
				["badWind"] = {
					"mex",
					"mex",
					"mex",
					"mex",
					"tidal",
					"floatingConverter",
					"tidal",
					"tidal",
					"tidal",
					"tidal",
					"tidal",
					"tidal",
					"tidal",
				},
				["goodWind"] = {
					"mex",
					"mex",
					"mex",
					"mex",
					"tidal",
					"floatingConverter",
					"tidal",
					"tidal",
					"tidal",
					"tidal",
					"tidal",
					"tidal",
					"tidal",
				}
			}
		}
	}
}

return quickStartConfig

