-- -- (note that alldefs_post.lua is still ran afterwards if you change anything there)

-- -- Special rules:
-- -- Only things you want changed in comparison with the regular unitdef need to be present (use the same table structure)
-- -- Since you can't actually remove parameters normally, it will do it when you set string: 'nil' as value
-- -- Normally an empty table as value will be ignored when merging, but not here, it will overwrite what it had with an empty table


local customDefs = {}

-- local scavDifficulty = Spring.GetModOptions().scavdifficulty
-- if scavDifficulty == "noob" then
-- 	ScavDifficultyMultiplier = 0.1
-- elseif scavDifficulty == "veryeasy" then
-- 	ScavDifficultyMultiplier = 0.25
-- elseif scavDifficulty == "easy" then
-- 	ScavDifficultyMultiplier = 0.375
-- elseif scavDifficulty == "medium" then
-- 	ScavDifficultyMultiplier = 0.5
-- elseif scavDifficulty == "hard" then
-- 	ScavDifficultyMultiplier = 0.875
-- elseif scavDifficulty == "veryhard" then
-- 	ScavDifficultyMultiplier = 1
-- elseif scavDifficulty == "expert" then
-- 	ScavDifficultyMultiplier = 1.5
-- elseif scavDifficulty == "brutal" then
-- 	ScavDifficultyMultiplier = 2
-- else
-- 	ScavDifficultyMultiplier = 0.25
-- end

local scavUnit = {}
for name,uDef in pairs(UnitDefs) do
	if string.sub(name, 1, 3) == "arm" or string.sub(name, 1, 3) == "cor" or string.sub(name, 1, 3) == "leg" then
		scavUnit[#scavUnit+1] = name .. '_scav'
	end
end

customDefs.armada_armageddon = {
	weapondefs = {
		nuclear_missile = {
			stockpile = false,
			stockpiletime = 0,
			reloadtime = 30,
			commandfire = true,
			customparams = {
				scavforcecommandfire = true,
			},
		},
	},
}

customDefs.cortex_apocalypse = {
	weapondefs = {
		crblmssl = {
			stockpile = false,
			stockpiletime = 0,
			reloadtime = 30,
			commandfire = true,
			customparams = {
				scavforcecommandfire = true,
			},
		},
	},
}

customDefs.armada_juno = {
	weapondefs = {
		juno_pulse = {
			stockpile = false,
			stockpiletime = 0,
			explosiongenerator = "custom:juno-explo-purple",
			reloadtime = 30,
			commandfire = true,
			customparams = {
				scavforcecommandfire = true,
			},
		},
	},
}

customDefs.cortex_juno = {
	weapondefs = {
		juno_pulse = {
			stockpile = false,
			stockpiletime = 0,
			explosiongenerator = "custom:juno-explo-purple",
			reloadtime = 30,
			commandfire = true,
			customparams = {
				scavforcecommandfire = true,
			},
		},
	},
}
















customDefs.armada_decoycommander = {
	decoyfor = "armada_commander_scav",
}

customDefs.cortex_decoycommander = {
	decoyfor = "cortex_decoycommander_scav",
}

customDefs.armada_dragonsclaw = {
	decoyfor = "armada_dragonsteeth_scav",
}

customDefs.cortex_dragonsmaw = {
	decoyfor = "cortex_dragonsteeth_scav",
}

customDefs.armada_decoyfusionreactor = {
	decoyfor = "armada_fusionreactor_scav",
}

customDefs.corscavdtf = {
	decoyfor = "corscavdrag_scav",
}

customDefs.corscavdtm = {
	decoyfor = "corscavdrag_scav",
}

customDefs.corscavdtl = {
	decoyfor = "corscavdrag_scav",
}


-- local scavConstructorsList = {
-- 	-- rezzers
-- 	"armada_lazarus",
-- 	"cortex_graverobber",
-- 	-- builders
-- 	"armada_constructionaircraft",
-- 	"cortex_constructionaircraft",
-- 	"armada_advancedconstructionaircraft",
-- 	"cortex_advancedconstructionaircraft",
-- 	"armada_constructionbot",
-- 	"cortex_constructionbot",
-- 	"armada_advancedconstructionbot",
-- 	"cortex_advancedconstructionbot",
-- 	"armada_constructionhovercraft",
-- 	"cortex_constructionhovercraft",
-- 	"armada_constructionseaplane",
-- 	"cortex_constructionseaplane",
-- 	"armada_constructionship",
-- 	"cortex_constructionship",
-- 	"armada_advancedconstructionsub",
-- 	"cortex_advancedconstructionsub",
-- 	"armada_constructionvehicle",
-- 	"cortex_constructionvehicle",
-- 	"armada_advancedconstructionvehicle",
-- 	"cortex_advancedconstructionvehicle",
-- }

-- customDefs.scavengerdroppodbeacon = {
-- 	maxdamage = 22000 * ScavDifficultyMultiplier,
-- }

-- customDefs.scavsafeareabeacon = {
-- 	maxdamage = 56000 * ScavDifficultyMultiplier,
-- }

-- -- Scav Commanders

-- customDefs.cortex_commander = {
-- 	autoheal = 15,
-- 	--blocking = false,
-- 	buildoptions = scavUnit,
-- 	builddistance = 250,
-- 	capturable = false,
-- 	cloakcost = 50,
-- 	cloakcostmoving = 100,
-- 	explodeas = "scavcomexplosion",
-- 	footprintx = 0,
-- 	footprintz = 0,
-- 	hidedamage = true,
-- 	idleautoheal = 20,
-- 	maxdamage = 5600,
-- 	--maxvelocity = 0.55,
-- 	turnrate = 50000,
-- 	mincloakdistance = 20,
-- 	movementclass = "SCAVCOMMANDERBOT",
-- 	selfdestructas = "scavcomexplosion",
-- 	showplayername = false,
-- 	stealth = false,

-- 	--objectname = "Units/cortex_commander.s3o",
-- 	--script = "Units/cortex_commander.cob",
-- 	--workertime = 200,				-- can get multiplied in unitdef_post
-- 	customparams = {
-- 		iscommander = 'nil',
-- 	},
-- 	featuredefs = {
-- 		dead = {
-- 			--resurrectable = 0,
-- 			metal = 1500,
-- 		},
-- 		heap = {
-- 			--resurrectable = 0,
-- 			metal = 750,
-- 		},
-- 	},
-- 	weapondefs = {
-- 		disintegrator = {
-- 			commandfire = false,
-- 		},
-- 	},
-- 	-- Extra Shield
-- 	-- weapons = {
-- 	-- 		[4] = {
-- 	-- 			def = "REPULSOR1",
-- 	-- 		},
-- 	-- 	},
-- }

-- customDefs.cortex_commandercon = {
-- 	autoheal = 15,
-- 	--blocking = false,
-- 	--buildoptions = scavConstructorsList,
-- 	builddistance = 175,
-- 	cloakcost = 50,
-- 	cloakcostmoving = 100,
-- 	explodeas = "scavcomexplosion",
-- 	footprintx = 0,
-- 	footprintz = 0,
-- 	hidedamage = true,
-- 	idleautoheal = 20,
-- 	maxdamage = 5600,
-- 	--maxvelocity = 0.55,
-- 	--turnrate = 50000,
-- 	mincloakdistance = 20,
-- 	movementclass = "SCAVCOMMANDERBOT",
-- 	selfdestructas = "scavcomexplosion",
-- 	showplayername = false,
-- 	stealth = false,

-- 	--workertime = 200,				-- can get multiplied in unitdef_post
-- 	customparams = {
-- 		iscommander = 'nil',
-- 	},
-- 	featuredefs = {
-- 		dead = {
-- 			--resurrectable = 0,
-- 			metal = 1500,
-- 		},
-- 		heap = {
-- 			--resurrectable = 0,
-- 			metal = 750,
-- 		},
-- 	},
-- 	weapondefs = {
-- 		disintegrator = {
-- 			commandfire = false,
-- 		},
-- 	},
-- 	-- Extra Shield
-- 	-- weapons = {
-- 	-- 		[4] = {
-- 	-- 			def = "REPULSOR1",
-- 	-- 		},
-- 	-- 	},
-- }

-- customDefs.armada_commander = {
-- 	autoheal = 15,
-- 	buildoptions = scavUnit,
-- 	builddistance = 250,
-- 	capturable = false,
-- 	cloakcost = 50,
-- 	cloakcostmoving = 100,
-- 	explodeas = "scavcomexplosion",
-- 	footprintx = 0,
-- 	footprintz = 0,
-- 	hidedamage = true,
-- 	idleautoheal = 20,
-- 	maxdamage = 5600,
-- 	--maxvelocity = 0.55,
-- 	turnrate = 50000,
-- 	mincloakdistance = 20,
-- 	movementclass = "SCAVCOMMANDERBOT",
-- 	selfdestructas = "scavcomexplosion",
-- 	showplayername = false,
-- 	stealth = false,
-- 	--workertime = 200,				-- can get multiplied in unitdef_post

-- 	--objectname = "Units/armada_commander.s3o",
-- 	--script = "Units/armada_commander_lus.lua",
-- 	customparams = {
-- 		iscommander = 'nil',
-- 	},
-- 	featuredefs = {
-- 		dead = {
-- 			--resurrectable = 0,
-- 			metal = 1500,
-- 		},
-- 		heap = {
-- 			--resurrectable = 0,
-- 			metal = 750,
-- 		},
-- 	},
-- 	weapondefs = {
-- 		disintegrator = {
-- 			commandfire = false,
-- 		},
-- 	},
-- 	-- Extra Shield
-- 	--weapons = {
-- 	--		[4] = {
-- 	--			def = "REPULSOR1",
-- 	--		},
-- 	--	},
-- }

-- customDefs.armada_commandercon = {
-- 	autoheal = 15,
-- 	--buildoptions = scavConstructorsList,
-- 	builddistance = 175,
-- 	cloakcost = 50,
-- 	cloakcostmoving = 100,
-- 	explodeas = "scavcomexplosion",
-- 	footprintx = 0,
-- 	footprintz = 0,
-- 	hidedamage = true,
-- 	idleautoheal = 20,
-- 	maxdamage = 5600,
-- 	--maxvelocity = 0.55,
-- 	--turnrate = 50000,
-- 	mincloakdistance = 20,
-- 	movementclass = "SCAVCOMMANDERBOT",
-- 	selfdestructas = "scavcomexplosion",
-- 	showplayername = false,
-- 	stealth = false,
-- 	--workertime = 200,				-- can get multiplied in unitdef_post
-- 	customparams = {
-- 		iscommander = 'nil',
-- 	},
-- 	featuredefs = {
-- 		dead = {
-- 			--resurrectable = 0,
-- 			metal = 1500,
-- 		},
-- 		heap = {
-- 			--resurrectable = 0,
-- 			metal = 750,
-- 		},
-- 	},
-- 	weapondefs = {
-- 		disintegrator = {
-- 			commandfire = false,
-- 		},
-- 	},
-- 	-- Extra Shield
-- 	--weapons = {
-- 	--		[4] = {
-- 	--			def = "REPULSOR1",
-- 	--		},
-- 	--	},
-- }

-- customDefs.legcom = {
-- 	corpse = "HEAP",
-- 	buildoptions = scavUnit,
-- 	maxdamage = 5600,
-- 	hidedamage = true,
-- 	capturable = false,
-- 	explodeas = "scavcomexplosion",
-- 	selfdestructas = "scavcomexplosion",
-- 	movementclass = "SCAVCOMMANDERBOT",
-- 	showplayername = false,
-- 	customparams = {
-- 		iscommander = 'nil',
-- 	},
-- 	featuredefs = {
-- 		dead = {
-- 			--resurrectable = 0,
-- 			metal = 1500,
-- 		},
-- 		heap = {
-- 			--resurrectable = 0,
-- 			metal = 750,
-- 		},
-- 	},
-- }

-- customDefs.legcomoff = {
-- 	corpse = "HEAP",
-- 	buildoptions = scavUnit,
-- 	maxdamage = 11100,
-- 	hidedamage = true,
-- 	capturable = false,
-- 	explodeas = "scavcomexplosion",
-- 	selfdestructas = "scavcomexplosion",
-- 	movementclass = "SCAVCOMMANDERBOT",
-- 	showplayername = false,
-- 	customparams = {
-- 		iscommander = 'nil',
-- 	},
-- 	featuredefs = {
-- 		dead = {
-- 			--resurrectable = 0,
-- 			metal = 3000,
-- 		},
-- 		heap = {
-- 			--resurrectable = 0,
-- 			metal = 1500,
-- 		},
-- 	},
-- }

-- customDefs.legcomt2com = {
-- 	corpse = "HEAP",
-- 	buildoptions = scavUnit,
-- 	maxdamage = 22000,
-- 	hidedamage = true,
-- 	capturable = false,
-- 	explodeas = "scavcomexplosion",
-- 	selfdestructas = "scavcomexplosion",
-- 	movementclass = "SCAVCOMMANDERBOT",
-- 	showplayername = false,
-- 	customparams = {
-- 		iscommander = 'nil',
-- 	},
-- 	featuredefs = {
-- 		dead = {
-- 			--resurrectable = 0,
-- 			metal = 6000,
-- 		},
-- 		heap = {
-- 			--resurrectable = 0,
-- 			metal = 3000,
-- 		},
-- 	},
-- }

-- customDefs.legcomt2def = {
-- 	corpse = "HEAP",
-- 	buildoptions = scavUnit,
-- 	maxdamage = 11100,
-- 	hidedamage = true,
-- 	capturable = false,
-- 	explodeas = "scavcomexplosion",
-- 	selfdestructas = "scavcomexplosion",
-- 	movementclass = "SCAVCOMMANDERBOT",
-- 	showplayername = false,
-- 	customparams = {
-- 		iscommander = 'nil',
-- 	},
-- 	featuredefs = {
-- 		dead = {
-- 			--resurrectable = 0,
-- 			metal = 3000,
-- 		},
-- 		heap = {
-- 			--resurrectable = 0,
-- 			metal = 1500,
-- 		},
-- 	},
-- }

-- ----CUSTOM UNITS---

-- -- Bladewing do damage instead of paralyzer
-- customDefs.cortex_shuriken = {
-- 	weapondefs = {
-- 		bladewing_lyzer = {
-- 			explosiongenerator = "custom:laserhit-tiny-blue",
-- 			paralyzer = false,
-- 			reloadtime = 0.1,
-- 			damage = {
-- 				default = 3,
-- 			},
-- 		},
-- 	},
-- }

-- -- Faster rockets with Accel - Lower DMG - higher pitched sound
-- customDefs.cortex_aggravator = {
-- 	weapondefs = {
-- 		core_bot_rocket = {
-- 			soundstart = "rocklit1scav",
-- 			startvelocity = 64,
-- 			weaponacceleration = 480,
-- 			weaponvelocity = 380,
-- 			damage = {
-- 				default = 105,
-- 					subs = 5,
-- 			},
-- 		},
-- 	},
-- }

-- -- Faster rockets with Accel - Lower DMG - higher pitched sound
-- customDefs.armada_rocketeer = {
-- 	weapondefs = {
-- 		arm_bot_rocket = {
-- 			soundstart = "rocklit1scav",
-- 			startvelocity = 64,
-- 			weaponacceleration = 480,
-- 			weaponvelocity = 380,
-- 			damage = {
-- 				default = 105,
-- 					subs = 5,
-- 			},
-- 		},
-- 	},
-- }

-- -- Rapid Fire AK + Cloak
-- customDefs.cortex_grunt = {
-- 	--cloakcost = 3,
-- 	--mincloakdistance = 144,
-- 	maxvelocity = 3,
-- 	weapondefs = {
-- 		gator_laser = {
-- 			beamtime = 0.13,
-- 			beamttl = 0,
-- 			reloadtime = 0.2,
-- 			soundstart = "lasrlit3scav",
-- 			damage = {
-- 				bombers = 1.6,
-- 				default = 20,
-- 				fighters = 1.6,
-- 				subs = 0.4,
-- 				vtol = 1.6,
-- 			},
-- 		},
-- 	},
-- }

-- -- Heavy Slow Fire Warrior + Cloak
-- customDefs.armada_centurion = {
-- 	--cloakcost = 3,
-- 	--mincloakdistance = 144,
-- 	script = "scavs/armada_centurionSCAV.cob",
-- 	weapondefs = {
-- 		armada_centurion_laser = {
-- 			beamtime = 0.23,
-- 			energypershot = 60,
-- 			laserflaresize = 9.2,
-- 			reloadtime = 1.2,
-- 			soundstart = "lasrfir4scav",
-- 			targetborder = 0.2,
-- 			thickness = 2.5,
-- 			damage = {
-- 				bombers = 40,
-- 				default = 268,
-- 				fighters = 40,
-- 				subs = 55,
-- 				vtol = 40,
-- 			},
-- 		},
-- 	},
-- }

-- local numBuildoptions = #UnitDefs.armada_experimentalgantry.buildoptions
-- customDefs.armada_experimentalgantry = {
-- 	buildoptions = {
-- 		[numBuildoptions+1] = "armrattet4",
-- 		[numBuildoptions+2] = "armada_recluset4",
-- 		[numBuildoptions+3] = "armada_pawnt4",
-- 		[numBuildoptions+4] = "armada_tumbleweedt4",
-- 		[numBuildoptions+5] = "armada_lunchbox",
-- 		[numBuildoptions+6] = "armmeatball",
-- 		[numBuildoptions+7] = "armassimilator",
-- 	},
-- }

-- numBuildoptions = #UnitDefs.armada_experimentalgantryuw.buildoptions
-- customDefs.armada_experimentalgantryuw = {
-- 	buildoptions = {
-- 		[numBuildoptions+1] = "armrattet4",
-- 		[numBuildoptions+2] = "armada_pawnt4",
-- 		[numBuildoptions+3] = "armada_tumbleweedt4",
-- 		[numBuildoptions+4] = "armmeatball",
-- 	},
-- }

-- numBuildoptions = #UnitDefs.cortex_experimentalgantry.buildoptions
-- customDefs.cortex_experimentalgantry = {
-- 	buildoptions = {
-- 		[numBuildoptions+1] = "cortex_demon",
-- 		[numBuildoptions+2] = "cortex_epickarganeth",
-- 		[numBuildoptions+3] = "cortex_epictzar",
-- 		[numBuildoptions+4] = "cortex_epicgrunt",
-- 	},
-- }

-- numBuildoptions = #UnitDefs.cortex_underwaterexperimentalgantry.buildoptions
-- customDefs.cortex_underwaterexperimentalgantry = {
-- 	buildoptions = {
-- 		[numBuildoptions+1] = "cortex_epictzar",
-- 	},
-- }

-- numBuildoptions = #UnitDefs.cortex_advancedvehicleplant.buildoptions
-- customDefs.cortex_advancedvehicleplant = {
-- 	buildoptions = {
-- 		[numBuildoptions+1] = "corgatreap",
-- 		[numBuildoptions+2] = "corforge",
-- 		[numBuildoptions+3] = "corvac", --corprinter
-- 		[numBuildoptions+4] = "cortorch",
-- 		[numBuildoptions+5] = "corftiger",
-- 		[numBuildoptions+6] = "corsala",
-- 	},
-- }

-- numBuildoptions = #UnitDefs.cortex_advancedshipyard.buildoptions
-- customDefs.cortex_advancedshipyard = {
-- 	buildoptions = {
-- 		[numBuildoptions+1] = "corslrpc",
-- 		[numBuildoptions+2] = "cortex_epicsupporter",
-- 	},
-- }

-- numBuildoptions = #UnitDefs.armada_advancedshipyard.buildoptions
-- customDefs.armada_advancedshipyard = {
-- 	buildoptions = {
-- 		[numBuildoptions+1] = "armada_skatert2",
-- 		[numBuildoptions+2] = "cortex_epicdolphin",
-- 		[numBuildoptions+3] = "armada_epicellysaw",
-- 	},
-- }

-- -- numBuildoptions = #UnitDefs.cortex_aircraftplant.buildoptions
-- -- customDefs.cortex_aircraftplant = {
-- -- 	buildoptions = {
-- -- 		[numBuildoptions+1] = "corassistdrone",
-- -- 	},
-- -- }

-- -- numBuildoptions = #UnitDefs.armada_aircraftplant.buildoptions
-- -- customDefs.armada_aircraftplant = {
-- -- 	buildoptions = {
-- -- 		[numBuildoptions+1] = "armassistdrone",
-- -- 	},
-- -- }

-- numBuildoptions = #UnitDefs.armada_constructionaircraft.buildoptions
-- customDefs.armada_constructionaircraft = {
-- 	buildoptions = {
-- 		[numBuildoptions+1] = "corscavdrag",
-- 		[numBuildoptions+2] = "corscavdtl",
-- 		[numBuildoptions+3] = "corscavdtf",
-- 		[numBuildoptions+4] = "corscavdtm",
-- 		[numBuildoptions+5] = "legmg",
-- 	},
-- }

-- numBuildoptions = #UnitDefs.armada_constructionbot.buildoptions
-- customDefs.armada_constructionbot = {
-- 	buildoptions = {
-- 		[numBuildoptions+1] = "corscavdrag",
-- 		[numBuildoptions+2] = "corscavdtl",
-- 		[numBuildoptions+3] = "corscavdtf",
-- 		[numBuildoptions+4] = "corscavdtm",
-- 		[numBuildoptions+5] = "legmg",
-- 	},
-- }

-- numBuildoptions = #UnitDefs.armada_constructionvehicle.buildoptions
-- customDefs.armada_constructionvehicle = {
-- 	buildoptions = {
-- 		[numBuildoptions+1] = "corscavdrag",
-- 		[numBuildoptions+2] = "corscavdtl",
-- 		[numBuildoptions+3] = "corscavdtf",
-- 		[numBuildoptions+4] = "corscavdtm",
-- 		[numBuildoptions+5] = "legmg",
-- 	},
-- }

-- numBuildoptions = #UnitDefs.cortex_constructionaircraft.buildoptions
-- customDefs.cortex_constructionaircraft = {
-- 	buildoptions = {
-- 		[numBuildoptions+1] = "corscavdrag",
-- 		[numBuildoptions+2] = "corscavdtl",
-- 		[numBuildoptions+3] = "corscavdtf",
-- 		[numBuildoptions+4] = "corscavdtm",
-- 	},
-- }

-- numBuildoptions = #UnitDefs.cortex_constructionbot.buildoptions
-- customDefs.cortex_constructionbot = {
-- 	buildoptions = {
-- 		[numBuildoptions+1] = "corscavdrag",
-- 		[numBuildoptions+2] = "corscavdtl",
-- 		[numBuildoptions+3] = "corscavdtf",
-- 		[numBuildoptions+4] = "corscavdtm",
-- 	},
-- }

-- numBuildoptions = #UnitDefs.cortex_constructionvehicle.buildoptions
-- customDefs.cortex_constructionvehicle = {
-- 	buildoptions = {
-- 		[numBuildoptions+1] = "corscavdrag",
-- 		[numBuildoptions+2] = "corscavdtl",
-- 		[numBuildoptions+3] = "corscavdtf",
-- 		[numBuildoptions+4] = "corscavdtm",
-- 	},
-- }

-- numBuildoptions = #UnitDefs.armada_advancedconstructionaircraft.buildoptions
-- customDefs.armada_advancedconstructionaircraft = {
-- 	buildoptions = {
-- 		[numBuildoptions+1] = "armada_aircraftplantt3",
-- 		[numBuildoptions+2] = "armminivulc",
-- 		[numBuildoptions+3] = "armada_windturbinet2",
-- 		[numBuildoptions+4] = "corscavfort",
-- 		[numBuildoptions+5] = "armbotrail",
-- 		[numBuildoptions+6] = "armada_pulsart3",
-- 	},
-- }

-- numBuildoptions = #UnitDefs.armada_advancedconstructionbot.buildoptions
-- customDefs.armada_advancedconstructionbot = {
-- 	buildoptions = {
-- 		[numBuildoptions+1] = "armada_aircraftplantt3",
-- 		[numBuildoptions+2] = "armminivulc",
-- 		[numBuildoptions+3] = "armada_windturbinet2",
-- 		[numBuildoptions+4] = "corscavfort",
-- 		[numBuildoptions+5] = "armbotrail",
-- 		[numBuildoptions+6] = "armada_pulsart3",
-- 	},
-- }

-- numBuildoptions = #UnitDefs.armada_advancedconstructionvehicle.buildoptions
-- customDefs.armada_advancedconstructionvehicle = {
-- 	buildoptions = {
-- 		[numBuildoptions+1] = "armada_aircraftplantt3",
-- 		[numBuildoptions+2] = "armminivulc",
-- 		[numBuildoptions+3] = "armada_windturbinet2",
-- 		[numBuildoptions+4] = "corscavfort",
-- 		[numBuildoptions+5] = "armbotrail",
-- 		[numBuildoptions+6] = "armada_pulsart3",
-- 	},
-- }

-- numBuildoptions = #UnitDefs.cortex_advancedconstructionaircraft.buildoptions
-- customDefs.cortex_advancedconstructionaircraft = {
-- 	buildoptions = {
-- 		[numBuildoptions+1] = "cortex_experimentalaircraftplant",
-- 		[numBuildoptions+2] = "corminibuzz",
-- 		[numBuildoptions+3] = "cortex_advancedwindturbine",
-- 		[numBuildoptions+4] = "corhllllt",
-- 		[numBuildoptions+5] = "corscavfort",
-- 		[numBuildoptions+6] = "cortex_epicbulwark",
-- 	},
-- }

-- numBuildoptions = #UnitDefs.cortex_advancedconstructionbot.buildoptions
-- customDefs.cortex_advancedconstructionbot = {
-- 	buildoptions = {
-- 		[numBuildoptions+1] = "cortex_experimentalaircraftplant",
-- 		[numBuildoptions+2] = "corminibuzz",
-- 		[numBuildoptions+3] = "cortex_advancedwindturbine",
-- 		[numBuildoptions+4] = "corhllllt",
-- 		[numBuildoptions+5] = "corscavfort",
-- 		[numBuildoptions+6] = "cortex_epicbulwark",
-- 	},
-- }

-- numBuildoptions = #UnitDefs.cortex_advancedconstructionvehicle.buildoptions
-- customDefs.cortex_advancedconstructionvehicle = {
-- 	buildoptions = {
-- 		[numBuildoptions+1] = "cortex_experimentalaircraftplant",
-- 		[numBuildoptions+2] = "corminibuzz",
-- 		[numBuildoptions+3] = "cortex_advancedwindturbine",
-- 		[numBuildoptions+4] = "corhllllt",
-- 		[numBuildoptions+5] = "corscavfort",
-- 		[numBuildoptions+6] = "cortex_epicbulwark",
-- 	},
-- }

-- --[[
-- -- Cloaked Radar

-- customDefs.armada_radartower = {
-- 	cloakcost = 6,
-- 	mincloakdistance = 144,
-- }

-- customDefs.armada_advancedradartower = {
-- 	cloakcost = 12,
-- 	mincloakdistance = 144,
-- }

-- customDefs.cortex_radartower = {
-- 	cloakcost = 6,
-- 	mincloakdistance = 144,
-- }

-- customDefs.cortex_advancedradartower = {
-- 	cloakcost = 12,
-- 	mincloakdistance = 144,
-- }


-- -- Cloaked Jammers

-- customDefs.armada_sneakypete = {
-- 	cloakcost = 10,
-- 	mincloakdistance = 144,
-- --	radardistancejam = 700,
-- 	sightdistance = 250,
-- }

-- customDefs.armada_veil = {
-- 	cloakcost = 25,
-- 	mincloakdistance = 288,
-- --	radardistancejam = 900,
-- 	sightdistance = 310,
-- }

-- customDefs.cortex_castro = {
-- 	cloakcost = 10,
-- 	mincloakdistance = 144,
-- --	radardistancejam = 700,
-- 	sightdistance = 250,
-- }

-- customDefs.cortex_shroud = {
-- 	cloakcost = 25,
-- 	mincloakdistance = 288,
-- --	radardistancejam = 900,
-- 	sightdistance = 310,
-- }

-- customDefs.cortex_incisor = {
-- 	cloakcost = 6,
-- 	mincloakdistance = 144,
-- }

-- customDefs.cortex_termite = {
-- 	cloakcost = 12,
-- 	maxdamage = 2550,
-- 	mincloakdistance = 144,
-- 	weapondefs = {
-- 		cor_termite_laser = {
-- 			beamtime = 0.65,
-- 			corethickness = 0.22,
-- 			energypershot = 40,
-- 			laserflaresize = 5.2,
-- 			range = 330,
-- 			reloadtime = 1.6,
-- 			soundstart = "heatray1s",
-- 			thickness = 2.8,
-- 			damage = {
-- 				bombers = 125,
-- 				default = 625,
-- 				fighters = 125,
-- 				subs = 11,
-- 				vtol = 125,
-- 			},
-- 		},
-- 	},
-- }

-- customDefs.cortex_commando = {
-- 	cloakcost = 12,
-- 	mincloakdistance = 144,
-- 	maxvelocity = 1.5,
-- }

-- customDefs.cortex_twitcher = {
-- 	maxvelocity = 2.1,
-- }

-- customDefs.armada_welder = {
-- 	cloakcost = 12,
-- 	mincloakdistance = 144,
-- }

-- customDefs.cortex_bedbug = {
-- 	cloakcost = 3,
-- 	mincloakdistance = 144,
-- }

-- customDefs.armada_tumbleweed = {
-- 	cloakcost = 3,
-- 	mincloakdistance = 144,
-- }

-- -- Cloaked + Stealh Units

-- customDefs.cortex_spectre = {
-- 	explodeas = "spybombxscav",
-- 	selfdestructas = "spybombxscav",
-- 	mincloakdistance = 64,
-- }

-- customDefs.armada_ghost = {
-- 	explodeas = "spybombxscav",
-- 	selfdestructas = "spybombxscav",
-- 	mincloakdistance = 64,
-- }

-- customDefs.cortex_karganeth = {
-- 	cloakcost = 24,
-- 	mincloakdistance = 144,
-- }

-- customDefs.cortex_bedbug = {
-- 	cloakcost = 3,
-- 	mincloakdistance = 144,
-- }

-- customDefs.cortex_skuttle = {
-- 	cloakcost = 6,
-- 	mincloakdistance = 144,
-- }

-- -- Cloaked Defenses

-- --]]

-- -- Faster LLT - unique sound - shorter beamtime
-- customDefs.cortex_guard = {
-- 	-- cloakcost = 6,
-- 	-- mincloakdistance = 144,
-- 	weapondefs = {
-- 		core_lightlaser = {
-- 			beamtime = 0.08,
-- 			energypershot = 10,
-- 			reloadtime = 0.36,
-- 			soundstart = "lasrfir3scav",
-- 			damage = {
-- 				bombers = 3.75,
-- 				default = 105,
-- 				fighters = 3.75,
-- 				subs = 1.5,
-- 				vtol = 3.75,
-- 			},
-- 		},
-- 	},
-- }

-- -- Custom ARM ambusher - NO cloak since looks weird/ugly atm
-- customDefs.armada_rattlesnake = {
-- 	-- cancloak = false,
-- 	-- stealth = true,
-- 	weapondefs = {
-- 		armada_rattlesnake_gun = {
-- 			impulseboost = 0.5,
-- 			impulsefactor = 2,
-- 		},
-- 	},
-- }

-- customDefs.cortex_persecutor = {
-- 	-- cancloak = false,
-- 	-- stealth = true,
-- 	weapondefs = {
-- 		cortex_persecutor_gun = {
-- 			impulseboost = 0.5,
-- 			impulsefactor = 2,
-- 		},
-- 	},
-- }

-- -- Custom HLLT - low laser = faster - high laser is slower - unique sounds
-- customDefs.cortex_twinguard = {
--  	-- cloakcost = 9,
--  	-- mincloakdistance = 144,
--  	weapondefs = {
-- 		hllt_bottom = {
-- 			beamtime = 0.07,
-- 			energypershot = 7.5,
-- 			reloadtime = 0.24,
-- 			soundstart = "lasrfir3scav",
-- 			damage = {
-- 				bombers = 2.5,
-- 				default = 70,
-- 				fighters = 2.5,
-- 				subs = 1,
-- 				vtol = 2.5,
-- 			},
-- 		},
-- 		hllt_top = {
-- 			beamtime = 0.28,
-- 			energypershot = 30,
-- 			reloadtime = 1.92,
-- 			soundstart = "lasrfir4scav",
-- 			thickness = 3,
-- 			damage = {
-- 				bombers = 20,
-- 				commanders = 400,
-- 				default = 300,
-- 				fighters = 20,
-- 				subs = 12,
-- 				vtol = 20,
-- 			},
-- 		},
-- 	},
--  }

-- -- customDefs.armada_paralyzer = {
-- -- 	weapondefs = {
-- -- 		armada_paralyzer_weapon = {
-- -- 			--range = 1800,
-- -- 			stockpiletime = 120, --25,
-- -- 		}
-- -- 	}
-- -- }

-- -- customDefs.cortex_catalyst = {
-- -- 	weapondefs = {
-- -- 		cortex_catalyst_weapon = {
-- -- 			--range = 1500,
-- -- 			stockpiletime = 180, --45,
-- -- 		}
-- -- 	}
-- -- }

-- customDefs.armada_mercury = {
-- 	weapondefs = {
-- 		arm_advsam = {
-- 			range = 1800,
-- 			reloadtime = 0.6,
-- 			stockpiletime = 28,
-- 		}
-- 	}
-- }

-- customDefs.cortex_screamer = {
-- 	weapondefs = {
-- 		cor_advsam = {
-- 			range = 1800,
-- 			reloadtime = 0.6,
-- 			stockpiletime = 28,
-- 		}
-- 	}
-- }


-- -- Faster LLT - unique sound - shorter beamtime
-- customDefs.armada_sentry = {
-- 	-- cloakcost = 6,
-- 	-- mincloakdistance = 144,
-- 	weapondefs = {
-- 		arm_lightlaser = {
-- 			beamtime = 0.08,
-- 			energypershot = 10,
-- 			reloadtime = 0.36,
-- 			soundstart = "lasrfir3scav",
-- 			damage = {
-- 				bombers = 3.75,
-- 				default = 105,
-- 				fighters = 3.75,
-- 				subs = 1.5,
-- 				vtol = 3.75,
-- 			},
-- 		},

-- 	},
-- }

-- -- customDefs.cortex_scorpion = {
-- -- 	cloakcost = 20,
-- -- 	mincloakdistance = 288,
-- -- }

-- -- customDefs.cortex_persecutor = {
-- -- 	cloakcost = 20,
-- -- 	mincloakdistance = 288,
-- -- }

-- customDefs.armada_lazarus = {
-- 	-- cancloak = true,
-- 	-- cloakcost = 10,
-- 	--cloakcostmoving = 100,
-- 	canassist = true,
-- 	category = "ALL BOT MOBILE NOWEAPON NOTSUB NOTSHIP NOTAIR NOTHOVER SURFACE CANBEUW EMPABLE",
-- 	footprintx = 2,
-- 	footprintz = 2,
-- 	movementclass = "COMMANDERBOT",
-- 	-- workertime = 100 * ScavDifficultyMultiplier, 	-- can get multiplied in unitdef_post
-- }

-- customDefs.cortex_graverobber = {
-- 	-- cancloak = true,
-- 	-- cloakcost = 10,
-- 	--cloakcostmoving = 100,
-- 	canassist = true,
-- 	category = "ALL BOT MOBILE NOWEAPON NOTSUB NOTSHIP NOTAIR NOTHOVER SURFACE CANBEUW EMPABLE",
-- 	footprintx = 2,
-- 	footprintz = 2,
-- 	movementclass = "COMMANDERBOT",
-- 	-- workertime = 100 * ScavDifficultyMultiplier,		-- can get multiplied in unitdef_post
-- }

-- -- LOOTBOXES

-- customDefs.lootboxbronze = {
-- 	energymake = 400,
-- 	metalmake = 20,
-- }

-- customDefs.lootboxsilver = {
-- 	energymake = 800,
-- 	metalmake = 40,
-- }

-- customDefs.lootboxgold = {
-- 	energymake = 1600,
-- 	metalmake = 80,
-- }

-- customDefs.lootboxplatinum = {
-- 	energymake = 2800,
-- 	metalmake = 140,
-- }

-- -- Shorter ranged long range rockets

-- customDefs.armada_ambassador = {
-- 	weapondefs = {
-- 		armtruck_rocket = {
-- 			areaofeffect = 200,
-- 			edgeeffectiveness = 0.72,
-- 			explosiongenerator = "custom:genericshellexplosion-large-aoe",
-- 			impulseboost = 0.35,
-- 			impulsefactor = 0.35,
-- 			range = 651,
-- 			reloadtime = 18,
-- 			damage = {
-- 				default = 2850,
-- 			},
-- 		},
-- 	},
-- }

-- customDefs.cortex_negotiator = {
-- 	weapondefs = {
-- 		cortruck_rocket = {
-- 			areaofeffect = 200,
-- 			edgeeffectiveness = 0.72,
-- 			explosiongenerator = "custom:genericshellexplosion-large-aoe",
-- 			impulseboost = 0.35,
-- 			impulsefactor = 0.35,
-- 			range = 655,
-- 			reloadtime = 16,
-- 			damage = {
-- 				default = 2550,
-- 			},
-- 		},
-- 	},
-- }

customDefs.armbotrail = {
	weapondefs = {
		arm_botrail = {
			customparams = {
				spawns_name = "armada_pawn_scav",
			},
		},
	},
}

-- customDefs.cortex_arbiter = {
-- 	weapondefs = {
-- 		cortex_arbiter_rocket = {
-- 			range = 605,
-- 			reloadtime = 4,
-- 			damage = {
-- 				default = 400,
-- 			},
-- 		},
-- 	},
-- }

-- customDefs.cortex_mangonel = {
-- 	weapondefs = {
-- 		cortex_mangonel_weapon = {
-- 			range = 525,
-- 			reloadtime = 6,
-- 			damage = {
-- 				default = 393,
-- 			},
-- 		},
-- 	},
-- }

-- customDefs.armada_possum = {
-- 	weapondefs = {
-- 		armada_possum_weapon = {
-- 			range = 532,
-- 			reloadtime = 4,
-- 			damage = {
-- 				default = 225,
-- 			},
-- 		},
-- 	},
-- }

return customDefs
