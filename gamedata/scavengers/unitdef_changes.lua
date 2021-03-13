-- (note that alldefs_post.lua is still ran afterwards if you change anything there)

-- Special rules:
-- you only need to put the things you want changed in comparison with the regular unitdef. (use the same table structure)
-- since you cant actually remove parameters normally, it will do it when you set string: 'nil' as value
-- normally an empty table as value will be ignored when merging, but not here, it will overwrite what it had with an empty table

customDefs = {}

scavDifficulty = (Spring.GetModOptions and Spring.GetModOptions().scavdifficulty) or "veryeasy"
if scavDifficulty == "noob" then
	ScavDifficultyMultiplier = 0.1
elseif scavDifficulty == "veryeasy" then
	ScavDifficultyMultiplier = 0.5
elseif scavDifficulty == "easy" then
	ScavDifficultyMultiplier = 0.75
elseif scavDifficulty == "medium" then
	ScavDifficultyMultiplier = 1
elseif scavDifficulty == "hard" then
	ScavDifficultyMultiplier = 1.25
elseif scavDifficulty == "veryhard" then
	ScavDifficultyMultiplier = 1.5
elseif scavDifficulty == "expert" then
	ScavDifficultyMultiplier = 2
elseif scavDifficulty == "brutal" then
	ScavDifficultyMultiplier = 3
else
	ScavDifficultyMultiplier = 0.5
end

local scavUnit = {}
for name,uDef in pairs(UnitDefs) do
	if string.sub(name, 1, 3) == "arm" or string.sub(name, 1, 3) == "cor" then
		scavUnit[#scavUnit+1] = name..'_scav'
	end
end

-- Scav Commanders

customDefs.scavengerdroppodbeacon = {
	maxdamage = 5000*ScavDifficultyMultiplier,
}

customDefs.scavsafeareabeacon = {
	maxdamage = 10000*ScavDifficultyMultiplier,
}

customDefs.corcom = {
	autoheal = 15,
	--blocking = false,
	buildoptions = scavUnit,
	builddistance = 175,
	cloakcost = 50,
	cloakcostmoving = 100,
	description = Spring.I18N('units.descriptions.corcom_scav'),
	explodeas = "scavcomexplosion",
	footprintx = 0,
	footprintz = 0,
	hidedamage = true,
	idleautoheal = 20,
	maxdamage = 4500*ScavDifficultyMultiplier,
	maxvelocity = 0.55,
	turnrate = 50000,
	mincloakdistance = 20,
	movementclass = "SCAVCOMMANDERBOT",
	selfdestructas = "scavcomexplosion",
	showplayername = false,
	stealth = false,
	workertime = 1000*ScavDifficultyMultiplier,				-- can get multiplied in unitdef_post
	customparams = {
		iscommander = 'nil',		-- since you cant actually remove parameters normally, it will do it when you set string: 'nil' as value
	},
	featuredefs = {
		dead = {
			resurrectable = 0,
			metal = 1500,
		},
		heap = {
			resurrectable = 0,
			metal = 750,
		},
	},
	weapondefs = {
		corcomlaser = {
			range = 400,
			damage = {
				bombers = 320,
				default = 75,
				fighters = 220,
				vtol = 320,
				subs = 5,
			},
		},
		disintegrator = {
			commandfire = false,
			reloadtime = 1.5/ScavDifficultyMultiplier,
			weaponvelocity = 350,
			damage = {
				bombers = 9000,
				default = 2250,
				fighters = 9000,
				vtol = 9000,
				commanders = 225,
			},
		},
	},
	-- Extra Shield
	-- weapons = {
	-- 		[4] = {
	-- 			def = "REPULSOR1",
	-- 		},
	-- 	},
}

customDefs.armcom = {
	autoheal = 15,
	buildoptions = scavUnit,
	builddistance = 175,
	cloakcost = 50,
	cloakcostmoving = 100,
	description = Spring.I18N('units.descriptions.armcom_scav'),
	explodeas = "scavcomexplosion",
	footprintx = 0,
	footprintz = 0,
	hidedamage = true,
	idleautoheal = 20,
	maxdamage = 4500*ScavDifficultyMultiplier,
	maxvelocity = 0.55,
	turnrate = 50000,
	mincloakdistance = 20,
	movementclass = "SCAVCOMMANDERBOT",
	selfdestructas = "scavcomexplosion",
	showplayername = false,
	stealth = false,
	workertime = 1000*ScavDifficultyMultiplier,				-- can get multiplied in unitdef_post
	customparams = {
		iscommander = 'nil',		-- since you cant actually remove parameters normally, it will do it when you set string: 'nil' as value
	},
	featuredefs = {
		dead = {
			resurrectable = 0,
			metal = 1500,
		},
		heap = {
			resurrectable = 0,
			metal = 750,
		},
	},
	weapondefs = {
		armcomlaser = {
			range = 400,
			damage = {
				bombers = 320,
				default = 75,
				fighters = 220,
				vtol = 320,
				subs = 5,
			},
		},
		disintegrator = {
			commandfire = false,
			reloadtime = 1.5/ScavDifficultyMultiplier,
			weaponvelocity = 350,
			damage = {
				bombers = 9000,
				default = 2250,
				fighters = 9000,
				vtol = 9000,
				commanders = 225,
			},
		},
	},
	-- Extra Shield
	--weapons = {
	--		[4] = {
	--			def = "REPULSOR1",
	--		},
	--	},
}

customDefs.armdecom = {
	decoyfor = "armcom_scav",
}
customDefs.cordecom = {
	decoyfor = "cordecom_scav",
}
customDefs.armclaw = {
	decoyfor = "armdrag_scav"
}
customDefs.cormaw = {
	decoyfor = "cordrag_scav"
}
customDefs.armdf = {
	decoyfor = "armfus_scav"
}

customDefs.armfort = {
	collisionvolumeoffsets = "0 -3 0",
	collisionvolumescales = "32 50 32",
	collisionvolumetype = "CylY",
	corpse = "ROCKTEETHX",
	objectname = "scavs/SCAVFORT.s3o",
	script = "scavs/SCAVFORT.cob",
}

customDefs.corfort = {
	collisionvolumeoffsets = "0 -3 0",
	collisionvolumescales = "32 50 32",
	collisionvolumetype = "CylY",
	corpse = "ROCKTEETHX",
	objectname = "scavs/SCAVFORT.s3o",
	script = "scavs/SCAVFORT.cob",
}

customDefs.armdrag = {
	collisionvolumeoffsets = "0 0 0",
	collisionvolumescales = "32 22 32",
	collisionvolumetype = "CylY",
	corpse = "ROCKTEETH",
	objectname = "scavs/scavdrag.s3o",
	script = "Units/cordrag.cob",
}

customDefs.cordrag = {
	collisionvolumeoffsets = "0 0 0",
	collisionvolumescales = "32 22 32",
	collisionvolumetype = "CylY",
	corpse = "ROCKTEETH",
	objectname = "scavs/scavdrag.s3o",
	script = "Units/cordrag.cob",
}

-- M/E storages T1 give rewarding amounts of metal / energy for reclaim

-- customDefs.armmstor = {
	-- explodeas = "decoycommander",
	-- --buildcostmetal = 1500,
	-- featuredefs = {
		-- dead = {
			-- category = "loot",
			-- description = "3000 Metal Lootbox",
			-- damage = 3000,
			-- metal = 3000, --50% reduction for being scav?
			-- energy = 0,
			-- object = "scavs/scavcrate.s3o",
			-- resurrectable = 0,
			-- smokeTime = 0,
		-- },
		-- heap = {
			-- category = "loot",
			-- description = "1500 Metal Lootbox (Damaged)",
			-- damage = 1500,
			-- metal = 1500, --50% reduction for being scav?
			-- energy = 0,
			-- object = "scavs/scavcrate.s3o",
			-- resurrectable = 0,
			-- smokeTime = 0,
		-- },
	-- },
-- }

-- customDefs.armestor = {
	-- explodeas = "decoycommander",
	-- --buildcostenergy = 3000,
	-- featuredefs = {
		-- dead = {
			-- category = "corpses",
			-- collisionvolumescales = "26 26 26",
			-- description = "6000 Energy Lootbox",
			-- damage = 3000,
			-- energy = 6000, --50% reduction for being scav?
			-- metal = 0,
			-- object = "scavs/scavcrate.s3o",
			-- resurrectable = 0,
			-- smokeTime = 0,
			-- -- customparams = {
			-- -- 	normaltex = "unittextures/cor_normal.dds",
			-- -- },
		-- },
		-- heap = {
			-- category = "corpses",
			-- collisionvolumescales = "26 26 26",
			-- description = "3000 Energy Lootbox Damaged",
			-- damage = 1500,
			-- energy = 3000, --50% reduction for being scav?
			-- metal = 0,
			-- object = "scavs/scavcrate.s3o",
			-- resurrectable = 0,
			-- smokeTime = 0,
			-- -- customparams = {
			-- -- 	normaltex = "unittextures/cor_normal.dds",
			-- -- },
		-- },
	-- },
-- }

-- customDefs.cormstor = {
	-- explodeas = "decoycommander",
	-- --buildcostmetal = 1500,
	-- featuredefs = {
		-- dead = {
			-- category = "loot",
			-- description = "3000 Metal Lootbox",
			-- damage = 3000,
			-- metal = 3000, --50% reduction for being scav
			-- energy = 0,
			-- object = "scavs/scavcrate.s3o",
			-- resurrectable = 0,
			-- smokeTime = 0,
		-- },
		-- heap = {
			-- category = "loot",
			-- description = "1500 Metal Lootbox Damaged",
			-- damage = 1500,
			-- metal = 1500, --50% reduction for being scav
			-- energy = 0,
			-- object = "scavs/scavcrate.s3o",
			-- resurrectable = 0,
			-- smokeTime = 0,
		-- },
	-- },
-- }

-- customDefs.corestor = {
	-- explodeas = "decoycommander",
	-- --buildcostenergy = 3000,
	-- featuredefs = {
		-- dead = {
			-- category = "loot",
			-- description = "6000 Energy Lootbox",
			-- damage = 3000,
			-- energy = 6000, --50% reduction for being scav
			-- metal = 0,
			-- object = "scavs/scavcrate.s3o",
			-- resurrectable = 0,
			-- smokeTime = 0,
		-- },
		-- heap = {
			-- category = "loot",
			-- description = "3000 Energy Lootbox Damaged",
			-- damage = 1500,
			-- energy = 3000, --50% reduction for being scav
			-- metal = 0,
			-- object = "scavs/scavcrate.s3o",
			-- resurrectable = 0,
		-- },
	-- },
-- }

-- -- M/E storages T2 give rewarding amounts of metal / energy for reclaim

-- customDefs.armuwadvms = {
	-- explodeas = "decoycommander",
	-- --buildcostmetal = 5000,
	-- featuredefs = {
		-- dead = {
			-- category = "loot",
			-- description = "Big 10000 Metal Lootbox",
			-- damage = 4500,
			-- metal = 10000, --50% reduction for being scav
			-- energy = 0,
			-- object = "scavs/scavcrate.s3o",
			-- resurrectable = 0,
			-- smokeTime = 0,
		-- },
		-- heap = {
			-- category = "loot",
			-- description = "Big 5000 Metal Lootbox Damaged",
			-- damage = 2250,
			-- metal = 5000, --50% reduction for being scav
			-- energy = 0,
			-- object = "scavs/scavcrate.s3o",
			-- resurrectable = 0,
			-- smokeTime = 0,
		-- },
	-- },
-- }

-- customDefs.armuwadves = {
	-- explodeas = "decoycommander",
	-- --buildcostenergy = 20000,
	-- featuredefs = {
	    -- dead = {
			-- category = "loot",
			-- description = "Big 10000 Energy Lootbox",
			-- damage = 4500,
			-- energy = 10000, --50% reduction for being scav
			-- metal = 0,
			-- object = "scavs/scavcrate.s3o",
			-- resurrectable = 0,
			-- smokeTime = 0,
		-- },
		-- heap = {
			-- category = "loot",
			-- description = "Big 5000 Energy Lootbox Damaged",
			-- damage = 2250,
			-- energy = 5000, --50% reduction for being scav
			-- metal = 0,
			-- object = "scavs/scavcrate.s3o",
			-- resurrectable = 0,
			-- smokeTime = 0,
		-- },
	-- },
-- }

-- customDefs.coruwadvms = {
	-- explodeas = "decoycommander",
	-- --buildcostmetal = 5000,
	-- featuredefs = {
		-- dead = {
			-- category = "loot",
			-- description = "Big 10000 Metal Lootbox",
			-- damage = 4500,
			-- metal = 10000, --50% reduction for being scav
			-- energy = 0,
			-- object = "scavs/scavcrate.s3o",
			-- resurrectable = 0,
			-- smokeTime = 0,
		-- },
		-- heap = {
			-- category = "loot",
			-- description = "Big 5000 Metal Lootbox Damaged",
			-- damage = 2250,
			-- metal = 5000, --50% reduction for being scav
			-- energy = 0,
			-- object = "scavs/scavcrate.s3o",
			-- resurrectable = 0,
			-- smokeTime = 0,
		-- },
	-- },
-- }

-- customDefs.coruwadves = {
	-- explodeas = "decoycommander",
	-- --buildcostenergy = 20000,
	-- featuredefs = {
		-- dead = {
			-- category = "loot",
			-- description = "Big 10000 Energy Lootbox",
			-- damage = 4500,
			-- energy = 10000, --50% reduction for being scav
			-- metal = 0,
			-- object = "scavs/scavcrate.s3o",
			-- resurrectable = 0,
			-- smokeTime = 0,
		-- },
		-- heap = {
			-- category = "loot",
			-- description = "Big 5000 Energy Lootbox Damaged",
			-- damage = 2250,
			-- energy = 5000, --50% reduction for being scav
			-- metal = 0,
			-- object = "scavs/scavcrate.s3o",
			-- resurrectable = 0,
			-- smokeTime = 0,
		-- },
	-- },
-- }


----CUSTOM UNITS---

-- Bladewing do damage instead of paralyzer
customDefs.corbw = {
	weapondefs = {
		bladewing_lyzer = {
			paralyzer = false,
			reloadtime = 0.1,
			damage = {
				default = 3,
			},
		},
	},
}

-- Faster rockets with Accel - Lower DMG - higher pitched sound
customDefs.corstorm = {
	weapondefs = {
		core_bot_rocket = {
			soundstart = "rocklit1scav",
			startvelocity = 64,
			weaponacceleration = 480,
			weaponvelocity = 380,
			damage = {
				default = 105,
					subs = 5,
			},
		},
	},
}

-- Faster rockets with Accel - Lower DMG - higher pitched sound
customDefs.armrock = {
	weapondefs = {
		arm_bot_rocket = {
			soundstart = "rocklit1scav",
			startvelocity = 64,
			weaponacceleration = 480,
			weaponvelocity = 380,
			damage = {
				default = 105,
					subs = 5,
			},
		},
	},
}

-- Rapid Fire AK + Cloak
customDefs.corak = {
	cloakcost = 3,
	description = Spring.I18N('units.descriptions.corak_scav'),
	mincloakdistance = 144,
	maxvelocity = 3,
	weapondefs = {
		gator_laser = {
			beamtime = 0.13,
			beamttl = 0,
			reloadtime = 0.2,
			soundstart = "lasrlit3scav",
			damage = {
				bombers = 1.6,
				default = 20,
				fighters = 1.6,
				subs = 0.4,
				vtol = 1.6,
			},
		},
	},
}

-- Heavy Slow Fire Warrior + Cloak
customDefs.armwar = {
	cloakcost = 3,
	description = Spring.I18N('units.descriptions.armwar_scav'),
	mincloakdistance = 144,
	script = "scavs/ARMWARSCAV.cob",
	weapondefs = {
		armwar_laser = {
			beamtime = 0.23,
			energypershot = 60,
			laserflaresize = 9.2,
			reloadtime = 1.2,
			soundstart = "lasrfir4scav",
			targetborder = 0.2,
			thickness = 2.5,
			damage = {
				bombers = 40,
				default = 268,
				fighters = 40,
				subs = 55,
				vtol = 40,
			},
		},
	},
}

local numBuildoptions = #UnitDefs.armshltx.buildoptions
customDefs.armshltx = {
	buildoptions = {
		[numBuildoptions+1] = "armrattet4",
		[numBuildoptions+2] = "armsptkt4",
		[numBuildoptions+3] = "armpwt4",
		[numBuildoptions+4] = "armvadert4",
		[numBuildoptions+5] = "armlunchbox",
		[numBuildoptions+6] = "armmeatball",
		[numBuildoptions+7] = "armassimilator",
		[numBuildoptions+8] = "armrectrt4",
		
	},
}

numBuildoptions = #UnitDefs.armshltxuw.buildoptions
customDefs.armshltxuw = {
	buildoptions = {
		[numBuildoptions+1] = "armrattet4",
		[numBuildoptions+2] = "armpwt4",
		[numBuildoptions+3] = "armvadert4",
		[numBuildoptions+4] = "armmeatball",
	},
}

numBuildoptions = #UnitDefs.corgant.buildoptions
customDefs.corgant = {
	buildoptions = {
		[numBuildoptions+1] = "cordemont4",
		[numBuildoptions+2] = "corkarganetht4",
		[numBuildoptions+3] = "corgolt4",
		
	},
}

numBuildoptions = #UnitDefs.corgantuw.buildoptions
customDefs.corgantuw = {
	buildoptions = {
		[numBuildoptions+1] = "corgolt4",
	},
}

numBuildoptions = #UnitDefs.coravp.buildoptions
customDefs.coravp = {
	buildoptions = {
		[numBuildoptions+1] = "corgatreap",
	},
}



numBuildoptions = #UnitDefs.armaca.buildoptions
customDefs.armaca = {
	buildoptions = {
		[numBuildoptions+1] = "armapt3",
		[numBuildoptions+2] = "armminivulc",
	},
}

numBuildoptions = #UnitDefs.armack.buildoptions
customDefs.armack = {
	buildoptions = {
		[numBuildoptions+1] = "armapt3",
		[numBuildoptions+2] = "armminivulc",
	},
}

numBuildoptions = #UnitDefs.armacv.buildoptions
customDefs.armacv = {
	buildoptions = {
		[numBuildoptions+1] = "armapt3",
		[numBuildoptions+2] = "armminivulc",
	},
}

numBuildoptions = #UnitDefs.coraca.buildoptions
customDefs.coraca = {
	buildoptions = {
		[numBuildoptions+1] = "corapt3",
		[numBuildoptions+2] = "corminibuzz",
	},
}

numBuildoptions = #UnitDefs.corack.buildoptions
customDefs.corack = {
	buildoptions = {
		[numBuildoptions+1] = "corapt3",
		[numBuildoptions+2] = "corminibuzz",
	},
}

numBuildoptions = #UnitDefs.coracv.buildoptions
customDefs.coracv = {
	buildoptions = {
		[numBuildoptions+1] = "corapt3",
		[numBuildoptions+2] = "corminibuzz",
	},
}

-- Cloaked Radar

customDefs.armrad = {
	cloakcost = 6,
	mincloakdistance = 144,
}

customDefs.armarad = {
	cloakcost = 12,
	mincloakdistance = 144,
}

customDefs.corrad = {
	cloakcost = 6,
	mincloakdistance = 144,
}

customDefs.corarad = {
	cloakcost = 12,
	mincloakdistance = 144,
}


-- Cloaked Jammers

customDefs.armjamt = {
	cloakcost = 10,
	mincloakdistance = 144,
--	radardistancejam = 700,
	sightdistance = 250,
}

customDefs.armveil = {
	cloakcost = 25,
	mincloakdistance = 288,
--	radardistancejam = 900,
	sightdistance = 310,
}

customDefs.corjamt = {
	cloakcost = 10,
	mincloakdistance = 144,
--	radardistancejam = 700,
	sightdistance = 250,
}

customDefs.corshroud = {
	cloakcost = 25,
	mincloakdistance = 288,
--	radardistancejam = 900,
	sightdistance = 310,
}

customDefs.corgator = {
	cloakcost = 6,
	mincloakdistance = 144,
}

customDefs.cortermite = {
	cloakcost = 12,
	description = Spring.I18N('units.descriptions.cortermite_scav'),
	maxdamage = 2300,
	mincloakdistance = 144,
	weapondefs = {
		cor_termite_laser = {
			beamtime = 0.65,
			corethickness = 0.22,
			energypershot = 40,
			laserflaresize = 5.2,
			range = 330,
			reloadtime = 1.6,
			soundstart = "heatray1s",
			thickness = 2.8,
			damage = {
				bombers = 125,
				default = 625,
				fighters = 125,
				subs = 11,
				vtol = 125,
			},
		},
	},
}

customDefs.cormando = {
	cloakcost = 12,
	mincloakdistance = 144,
	maxvelocity = 1.5,
}

customDefs.corfast = {
	maxvelocity = 2.1,
}

customDefs.armzeus = {
	cloakcost = 12,
	mincloakdistance = 144,
}

customDefs.corroach = {
	cloakcost = 3,
	mincloakdistance = 144,
}

customDefs.armvader = {
	cloakcost = 3,
	mincloakdistance = 144,
}

-- Cloaked + Stealh Units

customDefs.corspy = {
	explodeas = "spybombxscav",
	selfdestructas = "spybombxscav",
	mincloakdistance = 64,
}

customDefs.armspy = {
	explodeas = "spybombxscav",
	selfdestructas = "spybombxscav",
	mincloakdistance = 64,
}

customDefs.corkarg = {
	cloakcost = 24,
	mincloakdistance = 144,
}

customDefs.corroach = {
	cloakcost = 3,
	mincloakdistance = 144,
}

customDefs.corsktl = {
	cloakcost = 6,
	mincloakdistance = 144,
}

-- Cloaked Defenses

-- Faster LLT - unique sound - shorter beamtime
customDefs.corllt = {
	-- cloakcost = 6,
	-- mincloakdistance = 144,
	weapondefs = {
		core_lightlaser = {
			beamtime = 0.08,
			energypershot = 10,
			reloadtime = 0.36,
			soundstart = "lasrfir3scav",
			damage = {
				bombers = 3.75,
				default = 105,
				fighters = 3.75,
				subs = 1.5,
				vtol = 3.75,
			},
		},
	},
}

-- Custom ARM ambusher - NO cloak since looks weird/ugly atm
customDefs.armamb = {
	description = Spring.I18N('units.descriptions.armamb_scav'),
	cancloak = false,
	stealth = true,
	weapondefs = {
		armamb_gun = {
			impulseboost = 0.5,
			impulsefactor = 2,
		},
	},
}


customDefs.cortoast = {
	description = Spring.I18N('units.descriptions.cortoast_scav'),
	cancloak = false,
	stealth = true,
	weapondefs = {
		cortoast_gun = {
			impulseboost = 0.5,
			impulsefactor = 2,
		},
	},
}

-- Custom HLLT - low laser = faster - high laser is slower - unique sounds
customDefs.corhllt = {
 	-- cloakcost = 9,
 	-- mincloakdistance = 144,
 	weapondefs = {
		hllt_bottom = {
			beamtime = 0.07,
			energypershot = 7.5,
			reloadtime = 0.24,
			soundstart = "lasrfir3scav",
			damage = {
				bombers = 2.5,
				default = 70,
				fighters = 2.5,
				subs = 1,
				vtol = 2.5,
			},
		},
		hllt_top = {
			beamtime = 0.28,
			energypershot = 30,
			reloadtime = 1.92,
			soundstart = "lasrfir4scav",
			thickness = 3,
			damage = {
				bombers = 20,
				commanders = 400,
				default = 300,
				fighters = 20,
				subs = 12,
				vtol = 20,
			},
		},
	},
 }

customDefs.armemp = {
	weapondefs = {
		armemp_weapon = {
			range = 1800,
			stockpiletime = 25,
		}
	}
}

customDefs.cortron = {
	weapondefs = {
		cortron_weapon = {
			range = 1500,
			stockpiletime = 45,
		}
	}
}

customDefs.armmercury = {
	description = Spring.I18N('units.descriptions.armmercury_scav'),
	weapondefs = {
		arm_advsam = {
			range = 1800,
			reloadtime = 0.6,
			stockpiletime = 28,
		}
	}
}

customDefs.corscreamer = {
	description = Spring.I18N('units.descriptions.corscreamer_scav'),
	weapondefs = {
		cor_advsam = {
			range = 1800,
			reloadtime = 0.6,
			stockpiletime = 28,
		}
	}
}


-- Faster LLT - unique sound - shorter beamtime
customDefs.armllt = {
	-- cloakcost = 6,
	-- mincloakdistance = 144,
	weapondefs = {
		arm_lightlaser = {
			beamtime = 0.08,
			energypershot = 10,
			reloadtime = 0.36,
			soundstart = "lasrfir3scav",
			damage = {
				bombers = 3.75,
				default = 105,
				fighters = 3.75,
				subs = 1.5,
				vtol = 3.75,
			},
		},

	},
}


customDefs.corvipe = {
	cloakcost = 20,
	mincloakdistance = 288,
}

customDefs.cortoast = {
	cloakcost = 20,
	mincloakdistance = 288,
}

customDefs.armrectr = {
	--cancloak = true,
	--cloakcost = 10,
	--cloakcostmoving = 100,
	description = Spring.I18N('units.descriptions.armrectr_scav'),
	footprintx = 0,
	footprintz = 0,
	movementclass = "SCAVCOMMANDERBOT",
	workertime = 200*ScavDifficultyMultiplier, 	-- can get multiplied in unitdef_post
}

customDefs.cornecro = {
	--cancloak = true,
	--cloakcost = 10,
	--cloakcostmoving = 100,
	description = Spring.I18N('units.descriptions.cornecro_scav'),
	footprintx = 0,
	footprintz = 0,
	movementclass = "SCAVCOMMANDERBOT",
	workertime = 200*ScavDifficultyMultiplier,		-- can get multiplied in unitdef_post
}

-- LOOTBOXES

customDefs.lootboxbronze = {
	energymake = 400,
	metalmake = 20,
}

customDefs.lootboxsilver = {
	energymake = 800,
	metalmake = 40,
}

customDefs.lootboxgold = {
	energymake = 1600,
	metalmake = 80,
}

customDefs.lootboxplatinum = {
	energymake = 2800,
	metalmake = 140,
}

-- Shorter ranged long range rockets

customDefs.armmerl = {
	description = Spring.I18N('units.descriptions.armmerl_scav'),
	weapondefs = {
		armtruck_rocket = {
			areaofeffect = 200,
			edgeeffectiveness = 0.72,
			explosiongenerator = "custom:genericshellexplosion-large-aoe",
			impulseboost = 0.35,
			impulsefactor = 0.35,
			range = 651,
			reloadtime = 18,
			damage = {
				default = 2850,
			},
		},
	},
}

customDefs.corvroc = {
	description = Spring.I18N('units.descriptions.corvroc_scav'),
	weapondefs = {
		cortruck_rocket = {
			areaofeffect = 200,
			edgeeffectiveness = 0.72,
			explosiongenerator = "custom:genericshellexplosion-large-aoe",
			impulseboost = 0.35,
			impulsefactor = 0.35,
			range = 655,
			reloadtime = 16,
			damage = {
				default = 2550,
			},
		},
	},
}

customDefs.corhrk = {
	weapondefs = {
		corhrk_rocket = {
			range = 605,
			reloadtime = 4,
			damage = {
				default = 400,
			},
		},
	},
}

customDefs.cormh = {
	weapondefs = {
		cormh_weapon = {
			range = 525,
			reloadtime = 6,
			damage = {
				default = 393,
			},
		},
	},
}

customDefs.armmh = {
	weapondefs = {
		armmh_weapon = {
			range = 532,
			reloadtime = 4,
			damage = {
				default = 225,
			},
		},
	},
}