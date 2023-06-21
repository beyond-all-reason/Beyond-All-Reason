-- (note that alldefs_post.lua is still ran afterwards if you change anything there)

-- Special rules:
-- Only things you want changed in comparison with the regular unitdef need to be present (use the same table structure)
-- Since you can't actually remove parameters normally, it will do it when you set string: 'nil' as value
-- Normally an empty table as value will be ignored when merging, but not here, it will overwrite what it had with an empty table


local customDefs = {}

local scavDifficulty = Spring.GetModOptions().scavdifficulty
if scavDifficulty == "noob" then
	ScavDifficultyMultiplier = 0.1
elseif scavDifficulty == "veryeasy" then
	ScavDifficultyMultiplier = 0.25
elseif scavDifficulty == "easy" then
	ScavDifficultyMultiplier = 0.375
elseif scavDifficulty == "medium" then
	ScavDifficultyMultiplier = 0.5
elseif scavDifficulty == "hard" then
	ScavDifficultyMultiplier = 0.875
elseif scavDifficulty == "veryhard" then
	ScavDifficultyMultiplier = 1
elseif scavDifficulty == "expert" then
	ScavDifficultyMultiplier = 1.5
elseif scavDifficulty == "brutal" then
	ScavDifficultyMultiplier = 2
else
	ScavDifficultyMultiplier = 0.25
end

local scavUnit = {}
for name,uDef in pairs(UnitDefs) do
	if string.sub(name, 1, 3) == "arm" or string.sub(name, 1, 3) == "cor" or string.sub(name, 1, 3) == "leg" then
		scavUnit[#scavUnit+1] = name .. '_scav'
	end
end

local scavConstructorsList = {
	-- rezzers
	"armrectr",
	"cornecro",
	-- builders
	"armca",
	"corca",
	"armaca",
	"coraca",
	"armck",
	"corck",
	"armack",
	"corack",
	"armch",
	"corch",
	"armcsa",
	"corcsa",
	"armcs",
	"corcs",
	"armacsub",
	"coracsub",
	"armcv",
	"corcv",
	"armacv",
	"coracv",
}

customDefs.scavengerdroppodbeacon = {
	maxdamage = 22000 * ScavDifficultyMultiplier,
}

customDefs.scavsafeareabeacon = {
	maxdamage = 56000 * ScavDifficultyMultiplier,
}

-- Scav Commanders

customDefs.corcom = {
	autoheal = 15,
	--blocking = false,
	buildoptions = scavUnit,
	builddistance = 250,
	capturable = false,
	cloakcost = 50,
	cloakcostmoving = 100,
	explodeas = "scavcomexplosion",
	footprintx = 0,
	footprintz = 0,
	hidedamage = true,
	idleautoheal = 20,
	maxdamage = 5600,
	--maxvelocity = 0.55,
	turnrate = 50000,
	mincloakdistance = 20,
	movementclass = "SCAVCOMMANDERBOT",
	selfdestructas = "scavcomexplosion",
	showplayername = false,
	stealth = false,

	--objectname = "Units/CORCOM.s3o",
	--script = "Units/CORCOM.cob",
	--workertime = 200,				-- can get multiplied in unitdef_post
	customparams = {
		iscommander = 'nil',
	},
	featuredefs = {
		dead = {
			--resurrectable = 0,
			metal = 1500,
		},
		heap = {
			--resurrectable = 0,
			metal = 750,
		},
	},
	weapondefs = {
		disintegrator = {
			commandfire = false,
		},
	},
	-- Extra Shield
	-- weapons = {
	-- 		[4] = {
	-- 			def = "REPULSOR1",
	-- 		},
	-- 	},
}

customDefs.corcomcon = {
	autoheal = 15,
	--blocking = false,
	--buildoptions = scavConstructorsList,
	builddistance = 175,
	cloakcost = 50,
	cloakcostmoving = 100,
	explodeas = "scavcomexplosion",
	footprintx = 0,
	footprintz = 0,
	hidedamage = true,
	idleautoheal = 20,
	maxdamage = 5600,
	--maxvelocity = 0.55,
	--turnrate = 50000,
	mincloakdistance = 20,
	movementclass = "SCAVCOMMANDERBOT",
	selfdestructas = "scavcomexplosion",
	showplayername = false,
	stealth = false,

	--workertime = 200,				-- can get multiplied in unitdef_post
	customparams = {
		iscommander = 'nil',
	},
	featuredefs = {
		dead = {
			--resurrectable = 0,
			metal = 1500,
		},
		heap = {
			--resurrectable = 0,
			metal = 750,
		},
	},
	weapondefs = {
		disintegrator = {
			commandfire = false,
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
	builddistance = 250,
	capturable = false,
	cloakcost = 50,
	cloakcostmoving = 100,
	explodeas = "scavcomexplosion",
	footprintx = 0,
	footprintz = 0,
	hidedamage = true,
	idleautoheal = 20,
	maxdamage = 5600,
	--maxvelocity = 0.55,
	turnrate = 50000,
	mincloakdistance = 20,
	movementclass = "SCAVCOMMANDERBOT",
	selfdestructas = "scavcomexplosion",
	showplayername = false,
	stealth = false,
	--workertime = 200,				-- can get multiplied in unitdef_post

	--objectname = "Units/ARMCOM.s3o",
	--script = "Units/ARMCOM_lus.lua",
	customparams = {
		iscommander = 'nil',
	},
	featuredefs = {
		dead = {
			--resurrectable = 0,
			metal = 1500,
		},
		heap = {
			--resurrectable = 0,
			metal = 750,
		},
	},
	weapondefs = {
		disintegrator = {
			commandfire = false,
		},
	},
	-- Extra Shield
	--weapons = {
	--		[4] = {
	--			def = "REPULSOR1",
	--		},
	--	},
}

customDefs.armcomcon = {
	autoheal = 15,
	--buildoptions = scavConstructorsList,
	builddistance = 175,
	cloakcost = 50,
	cloakcostmoving = 100,
	explodeas = "scavcomexplosion",
	footprintx = 0,
	footprintz = 0,
	hidedamage = true,
	idleautoheal = 20,
	maxdamage = 5600,
	--maxvelocity = 0.55,
	--turnrate = 50000,
	mincloakdistance = 20,
	movementclass = "SCAVCOMMANDERBOT",
	selfdestructas = "scavcomexplosion",
	showplayername = false,
	stealth = false,
	--workertime = 200,				-- can get multiplied in unitdef_post
	customparams = {
		iscommander = 'nil',
	},
	featuredefs = {
		dead = {
			--resurrectable = 0,
			metal = 1500,
		},
		heap = {
			--resurrectable = 0,
			metal = 750,
		},
	},
	weapondefs = {
		disintegrator = {
			commandfire = false,
		},
	},
	-- Extra Shield
	--weapons = {
	--		[4] = {
	--			def = "REPULSOR1",
	--		},
	--	},
}

customDefs.legcom = {
	corpse = "HEAP",
	buildoptions = scavUnit,
	maxdamage = 5600,
	hidedamage = true,
	capturable = false,
	explodeas = "scavcomexplosion",
	selfdestructas = "scavcomexplosion",
	movementclass = "SCAVCOMMANDERBOT",
	showplayername = false,
	customparams = {
		iscommander = 'nil',
	},
	featuredefs = {
		dead = {
			--resurrectable = 0,
			metal = 1500,
		},
		heap = {
			--resurrectable = 0,
			metal = 750,
		},
	},
}

customDefs.legcomoff = {
	corpse = "HEAP",
	buildoptions = scavUnit,
	maxdamage = 11100,
	hidedamage = true,
	capturable = false,
	explodeas = "scavcomexplosion",
	selfdestructas = "scavcomexplosion",
	movementclass = "SCAVCOMMANDERBOT",
	showplayername = false,
	customparams = {
		iscommander = 'nil',
	},
	featuredefs = {
		dead = {
			--resurrectable = 0,
			metal = 3000,
		},
		heap = {
			--resurrectable = 0,
			metal = 1500,
		},
	},
}

customDefs.legcomt2com = {
	corpse = "HEAP",
	buildoptions = scavUnit,
	maxdamage = 22000,
	hidedamage = true,
	capturable = false,
	explodeas = "scavcomexplosion",
	selfdestructas = "scavcomexplosion",
	movementclass = "SCAVCOMMANDERBOT",
	showplayername = false,
	customparams = {
		iscommander = 'nil',
	},
	featuredefs = {
		dead = {
			--resurrectable = 0,
			metal = 6000,
		},
		heap = {
			--resurrectable = 0,
			metal = 3000,
		},
	},
}

customDefs.legcomt2def = {
	corpse = "HEAP",
	buildoptions = scavUnit,
	maxdamage = 11100,
	hidedamage = true,
	capturable = false,
	explodeas = "scavcomexplosion",
	selfdestructas = "scavcomexplosion",
	movementclass = "SCAVCOMMANDERBOT",
	showplayername = false,
	customparams = {
		iscommander = 'nil',
	},
	featuredefs = {
		dead = {
			--resurrectable = 0,
			metal = 3000,
		},
		heap = {
			--resurrectable = 0,
			metal = 1500,
		},
	},
}

customDefs.armdecom = {
	decoyfor = "armcom_scav",
}

customDefs.cordecom = {
	decoyfor = "cordecom_scav",
}

customDefs.armclaw = {
	decoyfor = "armdrag_scav",
}

customDefs.cormaw = {
	decoyfor = "cordrag_scav",
}

customDefs.armdf = {
	decoyfor = "armfus_scav",
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

----CUSTOM UNITS---

-- Bladewing do damage instead of paralyzer
customDefs.corbw = {
	weapondefs = {
		bladewing_lyzer = {
			explosiongenerator = "custom:laserhit-tiny-blue",
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
	--cloakcost = 3,
	--mincloakdistance = 144,
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
	--cloakcost = 3,
	--mincloakdistance = 144,
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
		[numBuildoptions+4] = "corakt4",
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
		[numBuildoptions+2] = "corforge",
		[numBuildoptions+3] = "corprinter",
		[numBuildoptions+4] = "cortorch",
	},
}

numBuildoptions = #UnitDefs.corasy.buildoptions
customDefs.corasy = {
	buildoptions = {
		[numBuildoptions+1] = "corslrpc",
		[numBuildoptions+2] = "coresuppt3",
	},
}

numBuildoptions = #UnitDefs.armasy.buildoptions
customDefs.armasy = {
	buildoptions = {
		[numBuildoptions+1] = "armptt2",
		[numBuildoptions+2] = "armdecadet3",
		[numBuildoptions+3] = "armpshipt3",
	},
}

-- numBuildoptions = #UnitDefs.corap.buildoptions
-- customDefs.corap = {
-- 	buildoptions = {
-- 		[numBuildoptions+1] = "corassistdrone",
-- 	},
-- }

-- numBuildoptions = #UnitDefs.armap.buildoptions
-- customDefs.armap = {
-- 	buildoptions = {
-- 		[numBuildoptions+1] = "armassistdrone",
-- 	},
-- }

numBuildoptions = #UnitDefs.armca.buildoptions
customDefs.armca = {
	buildoptions = {
		[numBuildoptions+1] = "corscavdrag",
		[numBuildoptions+2] = "corscavdtl",
		[numBuildoptions+3] = "corscavdtf",
		[numBuildoptions+4] = "corscavdtm",
		[numBuildoptions+5] = "legmg",
	},
}

numBuildoptions = #UnitDefs.armck.buildoptions
customDefs.armck = {
	buildoptions = {
		[numBuildoptions+1] = "corscavdrag",
		[numBuildoptions+2] = "corscavdtl",
		[numBuildoptions+3] = "corscavdtf",
		[numBuildoptions+4] = "corscavdtm",
		[numBuildoptions+5] = "legmg",
	},
}

numBuildoptions = #UnitDefs.armcv.buildoptions
customDefs.armcv = {
	buildoptions = {
		[numBuildoptions+1] = "corscavdrag",
		[numBuildoptions+2] = "corscavdtl",
		[numBuildoptions+3] = "corscavdtf",
		[numBuildoptions+4] = "corscavdtm",
		[numBuildoptions+5] = "legmg",
	},
}

numBuildoptions = #UnitDefs.corca.buildoptions
customDefs.corca = {
	buildoptions = {
		[numBuildoptions+1] = "corscavdrag",
		[numBuildoptions+2] = "corscavdtl",
		[numBuildoptions+3] = "corscavdtf",
		[numBuildoptions+4] = "corscavdtm",
	},
}

numBuildoptions = #UnitDefs.corck.buildoptions
customDefs.corck = {
	buildoptions = {
		[numBuildoptions+1] = "corscavdrag",
		[numBuildoptions+2] = "corscavdtl",
		[numBuildoptions+3] = "corscavdtf",
		[numBuildoptions+4] = "corscavdtm",
	},
}

numBuildoptions = #UnitDefs.corcv.buildoptions
customDefs.corcv = {
	buildoptions = {
		[numBuildoptions+1] = "corscavdrag",
		[numBuildoptions+2] = "corscavdtl",
		[numBuildoptions+3] = "corscavdtf",
		[numBuildoptions+4] = "corscavdtm",
	},
}

numBuildoptions = #UnitDefs.armaca.buildoptions
customDefs.armaca = {
	buildoptions = {
		[numBuildoptions+1] = "armapt3",
		[numBuildoptions+2] = "armminivulc",
		[numBuildoptions+3] = "armwint2",
		[numBuildoptions+4] = "corscavfort",
		[numBuildoptions+5] = "armbotrail",
		[numBuildoptions+6] = "armannit3",
	},
}

numBuildoptions = #UnitDefs.armack.buildoptions
customDefs.armack = {
	buildoptions = {
		[numBuildoptions+1] = "armapt3",
		[numBuildoptions+2] = "armminivulc",
		[numBuildoptions+3] = "armwint2",
		[numBuildoptions+4] = "corscavfort",
		[numBuildoptions+5] = "armbotrail",
		[numBuildoptions+6] = "armannit3",
	},
}

numBuildoptions = #UnitDefs.armacv.buildoptions
customDefs.armacv = {
	buildoptions = {
		[numBuildoptions+1] = "armapt3",
		[numBuildoptions+2] = "armminivulc",
		[numBuildoptions+3] = "armwint2",
		[numBuildoptions+4] = "corscavfort",
		[numBuildoptions+5] = "armbotrail",
		[numBuildoptions+6] = "armannit3",
	},
}

numBuildoptions = #UnitDefs.coraca.buildoptions
customDefs.coraca = {
	buildoptions = {
		[numBuildoptions+1] = "corapt3",
		[numBuildoptions+2] = "corminibuzz",
		[numBuildoptions+3] = "corwint2",
		[numBuildoptions+4] = "corhllllt",
		[numBuildoptions+5] = "corscavfort",
		[numBuildoptions+6] = "cordoomt3",
	},
}

numBuildoptions = #UnitDefs.corack.buildoptions
customDefs.corack = {
	buildoptions = {
		[numBuildoptions+1] = "corapt3",
		[numBuildoptions+2] = "corminibuzz",
		[numBuildoptions+3] = "corwint2",
		[numBuildoptions+4] = "corhllllt",
		[numBuildoptions+5] = "corscavfort",
		[numBuildoptions+6] = "cordoomt3",
	},
}

numBuildoptions = #UnitDefs.coracv.buildoptions
customDefs.coracv = {
	buildoptions = {
		[numBuildoptions+1] = "corapt3",
		[numBuildoptions+2] = "corminibuzz",
		[numBuildoptions+3] = "corwint2",
		[numBuildoptions+4] = "corhllllt",
		[numBuildoptions+5] = "corscavfort",
		[numBuildoptions+6] = "cordoomt3",
	},
}

-- Purple Juno
customDefs.armjuno = {
	weapondefs = {
		juno_pulse = {
			explosiongenerator = "custom:juno-explo-purple",
		},
	},
}

customDefs.corjuno = {
	weapondefs = {
		juno_pulse = {
			explosiongenerator = "custom:juno-explo-purple",
		},
	},
}

--[[
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
	maxdamage = 2550,
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

--]]

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
	-- cancloak = false,
	-- stealth = true,
	weapondefs = {
		armamb_gun = {
			impulseboost = 0.5,
			impulsefactor = 2,
		},
	},
}

customDefs.cortoast = {
	-- cancloak = false,
	-- stealth = true,
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

-- customDefs.armemp = {
-- 	weapondefs = {
-- 		armemp_weapon = {
-- 			--range = 1800,
-- 			stockpiletime = 120, --25,
-- 		}
-- 	}
-- }

-- customDefs.cortron = {
-- 	weapondefs = {
-- 		cortron_weapon = {
-- 			--range = 1500,
-- 			stockpiletime = 180, --45,
-- 		}
-- 	}
-- }

customDefs.armmercury = {
	weapondefs = {
		arm_advsam = {
			range = 1800,
			reloadtime = 0.6,
			stockpiletime = 28,
		}
	}
}

customDefs.corscreamer = {
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

-- customDefs.corvipe = {
-- 	cloakcost = 20,
-- 	mincloakdistance = 288,
-- }

-- customDefs.cortoast = {
-- 	cloakcost = 20,
-- 	mincloakdistance = 288,
-- }

customDefs.armrectr = {
	-- cancloak = true,
	-- cloakcost = 10,
	--cloakcostmoving = 100,
	canassist = true,
	category = "ALL BOT MOBILE NOWEAPON NOTSUB NOTSHIP NOTAIR NOTHOVER SURFACE CANBEUW EMPABLE",
	footprintx = 2,
	footprintz = 2,
	movementclass = "SCAVREZZER",
	-- workertime = 100 * ScavDifficultyMultiplier, 	-- can get multiplied in unitdef_post
}

customDefs.cornecro = {
	-- cancloak = true,
	-- cloakcost = 10,
	--cloakcostmoving = 100,
	canassist = true,
	category = "ALL BOT MOBILE NOWEAPON NOTSUB NOTSHIP NOTAIR NOTHOVER SURFACE CANBEUW EMPABLE",
	footprintx = 2,
	footprintz = 2,
	movementclass = "SCAVREZZER",
	-- workertime = 100 * ScavDifficultyMultiplier,		-- can get multiplied in unitdef_post
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

customDefs.armbotrail = {
	weapondefs = {
		arm_botrail = {
			customparams = {
				spawns_name = "armpw_scav",
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

return customDefs
