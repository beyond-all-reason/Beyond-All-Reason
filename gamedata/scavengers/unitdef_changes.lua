-- (note that alldefs_post.lua is still ran afterwards if you change anything there)

-- Special rules:
-- you only need to put the things you want changed in comparison with the regular unitdef. (use the same table structure)
-- since you cant actually remove parameters normally, it will do it when you set string: 'nil' as value
-- normally an empty table as value will be ignored when merging, but not here, it will overwrite what it had with an empty table

customDefs = {}


local scavUnit = {}
for name,uDef in pairs(UnitDefs) do
    scavUnit[#scavUnit+1] = name..'_scav'
end

-- Scav Commanders

customDefs.corcom = {		
	autoheal = 15,
	buildoptions = scavUnit,
	cloakcost = 50,
	cloakcostmoving = 100,
	explodeas = "bantha",
	hidedamage = true,
	idleautoheal = 20,
	maxdamage = 4500,
	maxvelocity = 2,
	mincloakdistance = 20,
	showplayername = false,
	stealth = false,
	workertime = 1000,				-- can get multiplied in unitdef_post 
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
		disintegrator = {
			commandfire = false,
			reloadtime = 10,
			weaponvelocity = 350,
			damage = {
				default = 2250,
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
	cloakcost = 50,
	cloakcostmoving = 100,
	explodeas = "bantha",
	hidedamage = true,
	idleautoheal = 20,
	maxdamage = 4500,
	mincloakdistance = 20,
	showplayername = false,
	stealth = false,
	workertime = 900,				-- can get multiplied in unitdef_post 
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
		disintegrator = {
			commandfire = false,
			reloadtime = 10,
			weaponvelocity = 350,
			damage = {
				default = 2250,
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

-- M/E storages T1 give rewarding amounts of metal / energy for reclaim

customDefs.armmstor = {		
	explodeas = "decoycommander",
	--buildcostmetal = 1500,
	featuredefs = {
		dead = {
			category = "loot",
			description = "1500 Metal Lootbox",
			damage = 3000,
			metal = 3000, --50% reduction for being scav
			energy = 0,
			object = "scavs/scavcrate.s3o",
			resurrectable = 0,
			smokeTime = 0,
		},
		heap = {
			category = "loot",
			description = "750 Metal Lootbox (Damaged)",
			damage = 1500,
			metal = 1500, --50% reduction for being scav
			energy = 0,
			object = "scavs/scavcrate.s3o",
			resurrectable = 0,
			smokeTime = 0,
		},
	},	
}

customDefs.armestor = {		
	explodeas = "decoycommander",
	--buildcostenergy = 3000,
	featuredefs = {
		dead = {
			category = "corpses",
			collisionvolumescales = "26 26 26",
			description = "3000 Energy Lootbox",
			damage = 3000,
			energy = 6000, --50% reduction for being scav
			metal = 0,
			object = "scavs/scavcrate.s3o",
			resurrectable = 0,
			smokeTime = 0,
			customparams = {
				normaltex = "unittextures/Core_normal.dds",
			},
		},
		heap = {
			category = "corpses",
			collisionvolumescales = "26 26 26",
			description = "1500 Energy Lootbox Damaged",
			damage = 1500,
			energy = 3000, --50% reduction for being scav
			metal = 0,
			object = "scavs/scavcrate.s3o",
			resurrectable = 0,
			smokeTime = 0,
			customparams = {
				normaltex = "unittextures/Core_normal.dds",
			},
		},
	},	
}

customDefs.cormstor = {		
	explodeas = "decoycommander",
	--buildcostmetal = 1500,
	featuredefs = {
		dead = {
			category = "loot",
			description = "1500 Metal Lootbox",
			damage = 3000,
			metal = 3000, --50% reduction for being scav
			energy = 0,
			object = "scavs/scavcrate.s3o",
			resurrectable = 0,
			smokeTime = 0,
		},
		heap = {
			category = "loot",
			description = "750 Metal Lootbox Damaged",
			damage = 1500,
			metal = 1500, --50% reduction for being scav
			energy = 0,
			object = "scavs/scavcrate.s3o",
			resurrectable = 0,
			smokeTime = 0,
		},
	},	
}

customDefs.corestor = {		
	explodeas = "decoycommander",
	--buildcostenergy = 3000,
	featuredefs = {
		dead = {
			category = "loot",
			description = "3000 Energy Lootbox",
			damage = 3000,
			energy = 6000, --50% reduction for being scav
			metal = 0,
			object = "scavs/scavcrate.s3o",
			resurrectable = 0,
			smokeTime = 0,
		},
		heap = {
			category = "loot",
			description = "1500 Energy Lootbox Damaged",
			damage = 1500,
			energy = 3000, --50% reduction for being scav
			metal = 0,
			object = "scavs/scavcrate.s3o",
			resurrectable = 0,
		},
	},	
}

-- M/E storages T2 give rewarding amounts of metal / energy for reclaim

customDefs.armuwadvms = {		
	explodeas = "decoycommander",
	--buildcostmetal = 5000,
	featuredefs = {
		dead = {
			category = "loot",
			description = "Big 5000 Metal Lootbox",
			damage = 4500,
			metal = 10000, --50% reduction for being scav
			energy = 0,
			object = "scavs/scavcrate.s3o",
			resurrectable = 0,
			smokeTime = 0,
		},
		heap = {
			category = "loot",
			description = "Big 2500 Metal Lootbox Damaged",
			damage = 2250,
			metal = 5000, --50% reduction for being scav
			energy = 0,
			object = "scavs/scavcrate.s3o",
			resurrectable = 0,
			smokeTime = 0,
		},
	},	
}

customDefs.armuwadves = {		
	explodeas = "decoycommander",
	--buildcostenergy = 20000,
	featuredefs = {
	    dead = {
			category = "loot",
			description = "Big 5000 Energy Lootbox",
			damage = 4500,
			energy = 10000, --50% reduction for being scav
			metal = 0,
			object = "scavs/scavcrate.s3o",
			resurrectable = 0,
			smokeTime = 0,
		},
		heap = {
			category = "loot",
			description = "Big 2500 Energy Lootbox Damaged",
			damage = 2250,
			energy = 5000, --50% reduction for being scav
			metal = 0,
			object = "scavs/scavcrate.s3o",
			resurrectable = 0,
			smokeTime = 0,
		},
	},
}

customDefs.coruwadvms = {		
	explodeas = "decoycommander",
	--buildcostmetal = 5000,
	featuredefs = {
		dead = {
			category = "loot",
			description = "Big 5000 Metal Lootbox",
			damage = 4500,
			metal = 10000, --50% reduction for being scav
			energy = 0,
			object = "scavs/scavcrate.s3o",
			resurrectable = 0,
			smokeTime = 0,
		},
		heap = {
			category = "loot",
			description = "Big 2500 Metal Lootbox Damaged",
			damage = 2250,
			metal = 5000, --50% reduction for being scav
			energy = 0,
			object = "scavs/scavcrate.s3o",
			resurrectable = 0,
			smokeTime = 0,
		},
	},	
}

customDefs.coruwadves = {		
	explodeas = "decoycommander",
	--buildcostenergy = 20000,
	featuredefs = {
		dead = {
			category = "loot",
			description = "Big 5000 Energy Lootbox",
			damage = 4500,
			energy = 10000, --50% reduction for being scav
			metal = 0,
			object = "scavs/scavcrate.s3o",
			resurrectable = 0,
			smokeTime = 0,
		},
		heap = {
			category = "loot",
			description = "Big 2500 Energy Lootbox Damaged",
			damage = 2250,
			energy = 5000, --50% reduction for being scav
			metal = 0,
			object = "scavs/scavcrate.s3o",
			resurrectable = 0,
			smokeTime = 0,
		},
	},	
}


----CUSTOM UNITS---

-- Bladewing do damage instead of paralyzer
customDefs.corbw = {
	weapondefs = {
		bladewing_lyzer = {
			paralyzer = false,
			reloadtime = 0.1,
			damage = {
				default = 2,
			},
		},
	},
}

-- Faster rockets with Accel - Lower DMG - higher pitched sound
customDefs.corstorm = {
	weapondefs = {
		core_kbot_rocket = {
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
		arm_kbot_rocket = {
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
	mincloakdistance = 72,
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

-- Cloaked Radar

customDefs.armrad = {
	cloakcost = 6,
	mincloakdistance = 72,
}

customDefs.armarad = {
	cloakcost = 12,
	mincloakdistance = 144,
}

customDefs.corrad = {
	cloakcost = 6,
	mincloakdistance = 72,
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

-- Cloaked Constructors

customDefs.correcl = {
	cloakcost = 3,
	mincloakdistance = 72,
}

customDefs.armrecl = {
	cloakcost = 3,
	mincloakdistance = 72,
}

customDefs.corck = {
	cloakcost = 3,
	mincloakdistance = 72,
}

customDefs.corcv = {
	cloakcost = 3,
	mincloakdistance = 72,
}

customDefs.cormuskrat = {
	cloakcost = 3,
	mincloakdistance = 72,
}

customDefs.corack = {
	cloakcost = 3,
	mincloakdistance = 72,
}

customDefs.coracv = {
	cloakcost = 3,
	mincloakdistance = 72,
}

customDefs.corca = {
	cloakcost = 3,
	mincloakdistance = 72,
}

customDefs.coraca = {
	cloakcost = 3,
	mincloakdistance = 72,
}

customDefs.armck = {
	cloakcost = 3,
	mincloakdistance = 72,
}

customDefs.armcv = {
	cloakcost = 3,
	mincloakdistance = 72,
}

customDefs.armbeaver = {
	cloakcost = 3,
	mincloakdistance = 72,
}

customDefs.armack = {
	cloakcost = 3,
	mincloakdistance = 72,
}

customDefs.armacv = {
	cloakcost = 3,
	mincloakdistance = 72,
}

customDefs.armca = {
	cloakcost = 3,
	mincloakdistance = 72,
}

customDefs.armaca = {
	cloakcost = 3,
	mincloakdistance = 72,
}

-- Cloaked Radar/Jammer Units

customDefs.armaser = {
	cloakcost = 3,
	mincloakdistance = 72,
}

customDefs.armmark = {
	cloakcost = 3,
	mincloakdistance = 72,
}

customDefs.armjam = {
	cloakcost = 3,
	mincloakdistance = 72,
}

customDefs.armseer = {
	cloakcost = 3,
	mincloakdistance = 72,
}

customDefs.corspec = {
	cloakcost = 3,
	mincloakdistance = 72,
}

customDefs.corvoyr = {
	cloakcost = 3,
	mincloakdistance = 72,
}

customDefs.coreter = {
	cloakcost = 3,
	mincloakdistance = 72,
}

customDefs.corvrad = {
	cloakcost = 3,
	mincloakdistance = 72,
}


-- Cloaked Combat Units

customDefs.corcrash = {
	cloakcost = 3,
	mincloakdistance = 72,
}

customDefs.coraak = {
	cloakcost = 6,
	mincloakdistance = 144,
}

customDefs.armjeth = {
	cloakcost = 3,
	mincloakdistance = 72,
}

customDefs.armaak = {
	cloakcost = 6,
	mincloakdistance = 144,
}

customDefs.corgator = {
	cloakcost = 6,
	mincloakdistance = 144,
}

customDefs.cortermite = {
	cloakcost = 12,
	mincloakdistance = 144,
}

customDefs.cormando = {
	cloakcost = 12,
	mincloakdistance = 144,
}

customDefs.corhrk = {
	cloakcost = 12,
	mincloakdistance = 160,
}

customDefs.armzeus = {
	cloakcost = 12,
	mincloakdistance = 144,
}

customDefs.corroach = {
	cloakcost = 3,
	mincloakdistance = 72,
}

customDefs.armvader = {
	cloakcost = 3,
	mincloakdistance = 72,
}

-- Cloaked + Stealh Units

customDefs.corkarg = {
	cloakcost = 24,
	stealth = true,
	mincloakdistance = 144,
}

customDefs.corroach = {
	cloakcost = 3,
	mincloakdistance = 72,
}

customDefs.corsktl = {
	cloakcost = 6,
	stealth = true,
	mincloakdistance = 72,
}

-- Cloaked Defenses

-- Faster LLT - unique sound - shorter beamtime
customDefs.corllt = {
	cloakcost = 6,
	mincloakdistance = 144,
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

-- Custom HLLT - low laser = faster - high laser is slower - unique sounds
customDefs.corhllt = {
 	cloakcost = 9,
 	mincloakdistance = 144,
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

customDefs.corhlt = {
	cloakcost = 18,
	mincloakdistance = 288,
}

customDefs.armhlt = {
	cloakcost = 18,
	mincloakdistance = 288,
}

-- Faster LLT - unique sound - shorter beamtime
customDefs.armllt = {
	cloakcost = 6,
	mincloakdistance = 144,
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

--Custom Nanoturrets - 25% more range
customDefs.armnanotc = {
	cloakcost = 6,
	mincloakdistance = 72,
	builddistance = 500,
}

customDefs.cornanotc = {
	cloakcost = 6,
	mincloakdistance = 72,
	builddistance = 500,
}

customDefs.corsilo = {
	cloakcost = 100,
	mincloakdistance = 144,
}

customDefs.armsilo = {
	cloakcost = 100,
	mincloakdistance = 144,
}

-- customDefs.armbeamer = {
-- 	cloakcost = 6,
-- 	mincloakdistance = 144,
-- }

customDefs.corvipe = {
	cloakcost = 20,
	mincloakdistance = 288,
}

customDefs.cortoast = {
	cloakcost = 20,
	mincloakdistance = 288,
}

customDefs.corint = {
	cloakcost = 75,
	mincloakdistance = 432,
}

customDefs.cordoom = {
	cloakcost = 50,
	mincloakdistance = 432,
}

customDefs.armrectr = {
	workertime = 400, 	-- can get multiplied in unitdef_post 
}

customDefs.cornecro = {
	workertime = 400,		-- can get multiplied in unitdef_post 
}
