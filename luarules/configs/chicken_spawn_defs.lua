
local difficulties = {
	veryeasy = 1,
	easy 	 = 2,
	normal   = 3,
	hard     = 4,
	veryhard = 5,
	epic     = 6,
	--survival = 6,
}

local difficulty = difficulties[Spring.GetModOptions().chicken_difficulty]
local burrowName = 'chicken_hive'

local chickenTurrets
if not Spring.GetModOptions().unit_restrictions_nonukes then
	chickenTurrets = {
		["chicken_turrets"] 			= { minQueenAnger = 0, 		spawnedPerWave = 2,		spawnOnBurrows = true,	maxQueenAnger = 50,},
		["chicken_turrets_antiair"] 	= { minQueenAnger = 0, 		spawnedPerWave = 2,		spawnOnBurrows = true,	maxQueenAnger = 50,},
		["chicken_turrets_acid"] 		= { minQueenAnger = 25, 	spawnedPerWave = 1,		spawnOnBurrows = false,	maxQueenAnger = 75,},
		["chicken_turrets_electric"] 	= { minQueenAnger = 25, 	spawnedPerWave = 1,		spawnOnBurrows = false,	maxQueenAnger = 75,},
		["chicken_turretl"] 			= { minQueenAnger = 50, 	spawnedPerWave = 2,		spawnOnBurrows = true,	maxQueenAnger = 1000,},
		["chicken_turretl_antiair"] 	= { minQueenAnger = 50, 	spawnedPerWave = 2,		spawnOnBurrows = true,	maxQueenAnger = 1000,},
		["chicken_turretl_acid"] 		= { minQueenAnger = 75, 	spawnedPerWave = 1,		spawnOnBurrows = false,	maxQueenAnger = 1000,},
		["chicken_turretl_electric"] 	= { minQueenAnger = 75, 	spawnedPerWave = 1,		spawnOnBurrows = false,	maxQueenAnger = 1000,},
		["chicken_turretxl_meteor"]		= { minQueenAnger = 75, 	spawnedPerWave = 1,		spawnOnBurrows = false,	maxQueenAnger = 1000,},
	}
else
	chickenTurrets = {
		["chicken_turrets"] 			= { minQueenAnger = 0, 		spawnedPerWave = 2,		spawnOnBurrows = true,	maxQueenAnger = 50,},
		["chicken_turrets_antiair"] 	= { minQueenAnger = 0, 		spawnedPerWave = 2,		spawnOnBurrows = true,	maxQueenAnger = 50,},
		["chicken_turrets_acid"] 		= { minQueenAnger = 25, 	spawnedPerWave = 1,		spawnOnBurrows = false,	maxQueenAnger = 75,},
		["chicken_turrets_electric"] 	= { minQueenAnger = 25, 	spawnedPerWave = 1,		spawnOnBurrows = false,	maxQueenAnger = 75,},
		["chicken_turretl"] 			= { minQueenAnger = 50, 	spawnedPerWave = 2,		spawnOnBurrows = true,	maxQueenAnger = 1000,},
		["chicken_turretl_antiair"] 	= { minQueenAnger = 50, 	spawnedPerWave = 2,		spawnOnBurrows = true,	maxQueenAnger = 1000,},
		["chicken_turretl_acid"] 		= { minQueenAnger = 75, 	spawnedPerWave = 1,		spawnOnBurrows = false,	maxQueenAnger = 1000,},
		["chicken_turretl_electric"] 	= { minQueenAnger = 75, 	spawnedPerWave = 1,		spawnOnBurrows = false,	maxQueenAnger = 1000,},
	}
end

local chickenEggs = { -- Specify eggs dropped by unit here, requires useEggs to be true, if some unit is not specified here, it drops random egg colors.
	chicken1       						=   "purple", 
	chicken1_mini						=   "purple",
	chicken1b      						=   "pink",
	chicken1c      						=   "purple",
	chicken1d      						=   "purple",
	chicken1x      						=   "pink",
	chicken1y      						=   "pink",
	chicken1z      						=   "pink",
	chicken2       						=   "pink",
	chicken2b      						=   "pink",
	chickena1      						=   "red",
	chickena1b     						=   "red",
	chickena1c     						=   "red",
	chickenallterraina1					=   "red",
	chickenallterraina1b				=   "red",
	chickenallterraina1c				=   "red",
	chickena2      						=   "red",
	chickena2b     						=   "red",
	chickenapexallterrainassault 		=   "red",
	chickenapexallterrainassaultb 		=   "red",
	chickens1      						=   "green",
	chickens2      						=   "green",
	chicken_dodo1  						=   "red",
	chicken_dodo2  						=   "red",
	chicken_dodoair  					=   "red",
	chickenf1_mini      				=   "darkgreen",
	chickenf1      						=   "darkgreen",
	chickenf1b     						=   "darkgreen",
	chickenf1apex      					=   "darkgreen",
	chickenf1apexb     					=   "darkgreen",
	chickenf2      						=   "white",
	chickenc3      						=   "white",
	chickenc3b     						=   "white",
	chickenc3c     						=   "white",
	chickenr1      						=   "darkgreen",
	chickenr2      						=   "darkgreen",
	chickenh1      						=   "white",
	chickenh1b     						=   "white",
	chickenh2      						=   "purple",
	chickenh3      						=   "purple",
	chickenh4      						=   "purple",
	chickenbroodbomberh2 				= 	"purple",
	chickenbroodbomberh3 				= 	"purple",
	chickenbroodbomberh4 				= 	"purple",
	chickenbroodartyh4 					= 	"purple",
	chickenbroodartyh4small 			= 	"purple",
	chickenh5      						=   "white",
	chickenw1      						=   "purple",
	chickenw1_mini      				=   "purple",
	chickenw1b     						=   "purple",
	chickenw1c     						=   "purple",
	chickenw1d     						=   "purple",
	chickenw2      						=   "darkred",
	chickenp1      						=   "darkred",
	chickenp2      						=   "darkred",
	chickenpyroallterrain				=	"darkred",
	chickene1	   						=   "blue",
	chickene2	   						=   "blue",
	chickenearty1  						=   "blue",
	chickenearty2  						=   "blue",
	chickenebomber1 					=   "blue",
	chickenelectricallterrain 			=   "blue",
	chickenelectricallterrainassault	=   "blue",
	chicken_dodo1_electric  			=   "blue",
	chicken_dodo2_electric  			=   "blue",
	chickenacidswarmer 					=   "acidgreen",
	chickenacidassault 					=   "acidgreen",
	chickenacidarty 					=   "acidgreen",
	chickenacidartyxl 					=   "acidgreen",
	chickenacidbomber 					=   "acidgreen",
	chickenacidallterrain				=	"acidgreen",
	chickenacidallterrainassault		=   "acidgreen",
	chicken1x_spectre					=   "yellow",
	chicken2_spectre					=   "yellow",
	chickena1_spectre					=   "yellow",
	chickena2_spectre					=   "yellow",
	chickens2_spectre					=   "yellow",

	chicken_miniqueen_electric			=   "blue",
	chicken_miniqueen_acid				=   "acidgreen",
	chicken_miniqueen_healer			=  	"white",
	chicken_miniqueen_basic 			=  	"pink",
	chicken_miniqueen_fire 				=  	"darkred",
	chicken_miniqueen_spectre 			=  	"yellow",
}

chickenBehaviours = {
	SKIRMISH = { -- Run away from target after target gets hit
		[UnitDefNames["chickens1"].id] = { distance = 270, chance = 0.5 },
		[UnitDefNames["chickens2"].id] = { distance = 250, chance = 0.5 },
		[UnitDefNames["chickenr1"].id] = { distance = 500, chance = 0.1 },
		[UnitDefNames["chickenr2"].id] = { distance = 500, chance = 0.01 },
		[UnitDefNames["chickene1"].id] = { distance = 300, chance = 1 },
		[UnitDefNames["chickene2"].id] = { distance = 200, chance = 0.01 },	
		[UnitDefNames["chickenelectricallterrainassault"].id] = { distance = 200, chance = 0.01 },
		[UnitDefNames["chickenearty1"].id] = { distance = 500, chance = 0.1 },
		[UnitDefNames["chickenearty2"].id] = { distance = 500, chance = 0.01 },
		[UnitDefNames["chickenelectricallterrain"].id] = { distance = 300, chance = 1 },
		[UnitDefNames["chickenacidswarmer"].id] = { distance = 300, chance = 1 },
		[UnitDefNames["chickenacidassault"].id] = { distance = 200, chance = 1 },
		[UnitDefNames["chickenacidallterrainassault"].id] = { distance = 200, chance = 1 },
		[UnitDefNames["chickenacidarty"].id] = { distance = 500, chance = 0.1 },
		[UnitDefNames["chickenacidartyxl"].id] = { distance = 500, chance = 0.01 },
		[UnitDefNames["chickenacidallterrain"].id] = { distance = 300, chance = 1 },
		[UnitDefNames["chickenh2"].id] = { distance = 500, chance = 0.25 },
		[UnitDefNames["chickenbroodartyh4small"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["chickenbroodartyh4"].id] = { distance = 500, chance = 0.1 },
		[UnitDefNames["chicken1x_spectre"].id] = { distance = 500, chance = 0.25, teleport = true, teleportcooldown = 2,},
		[UnitDefNames["chicken2_spectre"].id] = { distance = 500, chance = 0.25, teleport = true, teleportcooldown = 2,},
		[UnitDefNames["chickens2_spectre"].id] = { distance = 500, chance = 0.25, teleport = true, teleportcooldown = 2,},
		[UnitDefNames["chickena1_spectre"].id] = { distance = 500, chance = 0.25, teleport = true, teleportcooldown = 2,},
		[UnitDefNames["chickena2_spectre"].id] = { distance = 500, chance = 0.25, teleport = true, teleportcooldown = 2,},
		[UnitDefNames["chicken_miniqueen_spectre"].id] = {distance = 500, chance = 0.01, teleport = true, teleportcooldown = 2 },
		[UnitDefNames["chicken_miniqueen_electric"].id] = {distance = 500, chance = 0.01 },
		[UnitDefNames["chicken_miniqueen_acid"].id] = { distance = 500, chance = 0.01 },
		[UnitDefNames["chicken_miniqueen_healer"].id] = { distance = 500, chance = 0.01 },
		[UnitDefNames["chicken_miniqueen_basic"].id] = { distance = 500, chance = 0.01 },
		[UnitDefNames["chicken_miniqueen_fire"].id] = { distance = 500, chance = 0.01 },
		[UnitDefNames["ve_chickenq"].id] = { distance = 500, chance = 0.005 },
		[UnitDefNames["e_chickenq"].id] = { distance = 500, chance = 0.005 },
		[UnitDefNames["n_chickenq"].id] = { distance = 500, chance = 0.005 },
		[UnitDefNames["h_chickenq"].id] = { distance = 500, chance = 0.005 },
		[UnitDefNames["vh_chickenq"].id] = { distance = 500, chance = 0.005 },
		[UnitDefNames["epic_chickenq"].id] = { distance = 500, chance = 0.005 },
	},
	COWARD = { -- Run away from target after getting hit by enemy
		[UnitDefNames["chickenh1"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["chickenh1b"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["chickens1"].id] = { distance = 270, chance = 0.5 },
		[UnitDefNames["chickens2"].id] = { distance = 250, chance = 0.5 },
		[UnitDefNames["chickenr1"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["chickenr2"].id] = { distance = 500, chance = 0.1 },
		[UnitDefNames["chickenearty1"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["chickenearty2"].id] = { distance = 500, chance = 0.1 },
		[UnitDefNames["chickenacidarty"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["chickenacidartyxl"].id] = { distance = 500, chance = 0.1 },
		[UnitDefNames["chickenbroodartyh4small"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["chickenbroodartyh4"].id] = { distance = 500, chance = 0.1 },
		[UnitDefNames["chickenh2"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["chickenh3"].id] = { distance = 500, chance = 0.25 },
		[UnitDefNames["chicken1x_spectre"].id] = { distance = 500, chance = 0.25, teleport = true, teleportcooldown = 2,},
		[UnitDefNames["chicken2_spectre"].id] = { distance = 500, chance = 0.25, teleport = true, teleportcooldown = 2,},
		[UnitDefNames["chickens2_spectre"].id] = { distance = 500, chance = 0.25, teleport = true, teleportcooldown = 2,},
		[UnitDefNames["chickena1_spectre"].id] = { distance = 500, chance = 0.25, teleport = true, teleportcooldown = 2,},
		[UnitDefNames["chickena2_spectre"].id] = { distance = 500, chance = 0.25, teleport = true, teleportcooldown = 2,},
		[UnitDefNames["chicken_miniqueen_spectre"].id] = { distance = 500, chance = 0.01, teleport = true, teleportcooldown = 2 },
		[UnitDefNames["chicken_miniqueen_electric"].id] = { distance = 500, chance = 0.01 },
		[UnitDefNames["chicken_miniqueen_acid"].id] = { distance = 500, chance = 0.01 },
		[UnitDefNames["chicken_miniqueen_healer"].id] = { distance = 500, chance = 0.01 },
		[UnitDefNames["chicken_miniqueen_basic"].id] = { distance = 500, chance = 0.01 },
		[UnitDefNames["chicken_miniqueen_fire"].id] = { distance = 500, chance = 0.01 },
		[UnitDefNames["ve_chickenq"].id] = { distance = 500, chance = 0.005 },
		[UnitDefNames["e_chickenq"].id] = { distance = 500, chance = 0.005 },
		[UnitDefNames["n_chickenq"].id] = { distance = 500, chance = 0.005 },
		[UnitDefNames["h_chickenq"].id] = { distance = 500, chance = 0.005 },
		[UnitDefNames["vh_chickenq"].id] = { distance = 500, chance = 0.005 },
		[UnitDefNames["epic_chickenq"].id] = { distance = 500, chance = 0.005 },
	},
	BERSERK = { -- Run towards target after getting hit by enemy or after hitting the target
		[UnitDefNames["chickens2"].id] = {chance = 0.2, distance = 750},
		[UnitDefNames["chickena1"].id] = { chance = 0.2, distance = 1500 },
		[UnitDefNames["chickena1b"].id] = { chance = 0.2, distance = 1500 },
		[UnitDefNames["chickena1c"].id] = { chance = 0.2, distance = 1500 },
		[UnitDefNames["chickenallterraina1"].id] = { chance = 0.2, distance = 1500 },
		[UnitDefNames["chickenallterraina1b"].id] = { chance = 0.2, distance = 1500 },
		[UnitDefNames["chickenallterraina1c"].id] = { chance = 0.2, distance = 1500 },
		[UnitDefNames["chickena2"].id] = { chance = 0.2, distance = 3000 },
		[UnitDefNames["chickena2b"].id] = { chance = 0.2, distance = 3000 },
		[UnitDefNames["chickenapexallterrainassault"].id] = { chance = 0.2, distance = 3000 },
		[UnitDefNames["chickenapexallterrainassaultb"].id] = { chance = 0.2, distance = 3000 },
		[UnitDefNames["chickene2"].id] = { chance = 0.05 },
		[UnitDefNames["chickenelectricallterrainassault"].id] = { chance = 0.05 },
		[UnitDefNames["chickenacidassault"].id] = { chance = 0.05 },
		[UnitDefNames["chickenacidallterrainassault"].id] = { chance = 0.05 },
		[UnitDefNames["chickenacidswarmer"].id] = { chance = 0.01 },
		[UnitDefNames["chickenacidallterrain"].id] = { chance = 0.01 },
		[UnitDefNames["chickenp1"].id] = { chance = 0.2 },
		[UnitDefNames["chickenp2"].id] = { chance = 0.2 },
		[UnitDefNames["chickenpyroallterrain"].id] = { chance = 0.2 },
		[UnitDefNames["chickenh4"].id] = { chance = 1 },
		[UnitDefNames["chicken1x_spectre"].id] = { distance = 1000, chance = 0.25},
		[UnitDefNames["chicken2_spectre"].id] = { distance = 1000, chance = 0.25},
		[UnitDefNames["chickena1_spectre"].id] = { distance = 1000, chance = 0.25},
		[UnitDefNames["chickena2_spectre"].id] = { distance = 1000, chance = 0.25},
		[UnitDefNames["chickens2_spectre"].id] = { distance = 1000, chance = 0.25},
		[UnitDefNames["chicken_miniqueen_spectre"].id] = {distance = 500, chance = 0.01 },
		[UnitDefNames["chicken_miniqueen_electric"].id] = {distance = 500, chance = 0.01 },
		[UnitDefNames["chicken_miniqueen_acid"].id] = { distance = 500, chance = 0.01 },
		[UnitDefNames["chicken_miniqueen_healer"].id] = { distance = 500, chance = 0.01 },
		[UnitDefNames["chicken_miniqueen_basic"].id] = { distance = 500, chance = 0.01 },
		[UnitDefNames["chicken_miniqueen_fire"].id] = { distance = 500, chance = 0.01 },
		[UnitDefNames["ve_chickenq"].id] = { chance = 0.05 },
		[UnitDefNames["e_chickenq"].id] = { chance = 0.05 },
		[UnitDefNames["n_chickenq"].id] = { chance = 0.05 },
		[UnitDefNames["h_chickenq"].id] = { chance = 0.05 },
		[UnitDefNames["vh_chickenq"].id] = { chance = 0.05 },
		[UnitDefNames["epic_chickenq"].id] = { chance = 0.05 },
	},
	HEALER = { -- Getting long max lifetime and always use Fight command. These units spawn as healers from burrows and queen
		[UnitDefNames["chickenh1"].id] = true,
		[UnitDefNames["chickenh1b"].id] = true,
	},
	ARTILLERY = { -- Long lifetime and no regrouping, always uses Fight command to keep distance, friendly fire enabled (assuming nothing else in the game stops it)
		[UnitDefNames["chickenr1"].id] = true,
		[UnitDefNames["chickenr2"].id] = true,
		[UnitDefNames["chickenearty1"].id] = true,
		[UnitDefNames["chickenearty2"].id] = true,
		[UnitDefNames["chickenacidarty"].id] = true,
		[UnitDefNames["chickenacidartyxl"].id] = true,
		[UnitDefNames["chickenbroodartyh4"].id] = true,
		[UnitDefNames["chickenbroodartyh4small"].id] = true,
		[UnitDefNames["chicken_turretxl_meteor"].id] = true,
	},
	KAMIKAZE = { -- Long lifetime and no regrouping, always uses Move command to rush into the enemy
		[UnitDefNames["chicken_dodo1"].id] = true,
		[UnitDefNames["chicken_dodo2"].id] = true,
		[UnitDefNames["chicken_dodo1_electric"].id] = true,
		[UnitDefNames["chicken_dodo2_electric"].id] = true,
	},
	PROBE_UNIT = UnitDefNames["chicken2"].id, -- tester unit for picking viable spawn positions - use some medium sized unit
}

local optionValues = {

	[difficulties.veryeasy] = {
		gracePeriod       = 8 * Spring.GetModOptions().chicken_graceperiodmult * 60,
		queenTime      	  = 50 * Spring.GetModOptions().chicken_queentimemult * 60, -- time at which the queen appears, frames
		chickenSpawnRate  = 120,
		burrowSpawnRate   = 480,
		turretSpawnRate   = 240,
		queenSpawnMult    = 1,
		angerBonus        = 1,
		maxXP			  = 0.5,
		spawnChance       = 0.1,
		damageMod         = 0.4,
		maxBurrows        = 1000,
		minChickens		  = 5,
		maxChickens		  = 25,
		chickenPerPlayerMultiplier = 0.25,
		queenName         = 've_chickenq',
		queenResistanceMult   = 0.5,
	},

	[difficulties.easy] = {
		gracePeriod       = 7 * Spring.GetModOptions().chicken_graceperiodmult * 60,
		queenTime      	  = 45 * Spring.GetModOptions().chicken_queentimemult * 60, -- time at which the queen appears, frames
		chickenSpawnRate  = 90,
		burrowSpawnRate   = 420,
		turretSpawnRate   = 210,
		queenSpawnMult    = 1,
		angerBonus        = 1,
		maxXP			  = 1,
		spawnChance       = 0.2,
		damageMod         = 0.6,
		maxBurrows        = 1000,
		minChickens		  = 5,
		maxChickens		  = 30,
		chickenPerPlayerMultiplier = 0.25,
		queenName         = 'e_chickenq',
		queenResistanceMult   = 0.75,
	},
	[difficulties.normal] = {
		gracePeriod       = 6 * Spring.GetModOptions().chicken_graceperiodmult * 60,
		queenTime      	  = 40 * Spring.GetModOptions().chicken_queentimemult * 60, -- time at which the queen appears, frames
		chickenSpawnRate  = 60,
		burrowSpawnRate   = 360,
		turretSpawnRate   = 180,
		queenSpawnMult    = 3,
		angerBonus        = 1,
		maxXP			  = 1.5,
		spawnChance       = 0.3,
		damageMod         = 0.8,
		maxBurrows        = 1000,
		minChickens		  = 5,
		maxChickens		  = 35,
		chickenPerPlayerMultiplier = 0.25,
		queenName         = 'n_chickenq',
		queenResistanceMult   = 1,
	},
	[difficulties.hard] = {
		gracePeriod       = 5 * Spring.GetModOptions().chicken_graceperiodmult * 60,
		queenTime      	  = 40 * Spring.GetModOptions().chicken_queentimemult * 60, -- time at which the queen appears, frames
		chickenSpawnRate  = 50,
		burrowSpawnRate   = 300,
		turretSpawnRate   = 150,
		queenSpawnMult    = 3,
		angerBonus        = 1,
		maxXP			  = 2,
		spawnChance       = 0.4,
		damageMod         = 1,
		maxBurrows        = 1000,
		minChickens		  = 5,
		maxChickens		  = 40,
		chickenPerPlayerMultiplier = 0.25,
		queenName         = 'h_chickenq',
		queenResistanceMult   = 1.33,
	},
	[difficulties.veryhard] = {
		gracePeriod       = 4 * Spring.GetModOptions().chicken_graceperiodmult * 60,
		queenTime      	  = 35 * Spring.GetModOptions().chicken_queentimemult * 60, -- time at which the queen appears, frames
		chickenSpawnRate  = 40,
		burrowSpawnRate   = 240,
		turretSpawnRate   = 120,
		queenSpawnMult    = 3,
		angerBonus        = 1,
		maxXP			  = 2.5,
		spawnChance       = 0.5,
		damageMod         = 1.2,
		maxBurrows        = 1000,
		minChickens		  = 5,
		maxChickens		  = 45,
		chickenPerPlayerMultiplier = 0.25,
		queenName         = 'vh_chickenq',
		queenResistanceMult   = 1.67,
	},
	[difficulties.epic] = {
		gracePeriod       = 3 * Spring.GetModOptions().chicken_graceperiodmult * 60,
		queenTime      	  = 30 * Spring.GetModOptions().chicken_queentimemult * 60, -- time at which the queen appears, frames
		chickenSpawnRate  = 30,
		burrowSpawnRate   = 180,
		turretSpawnRate   = 90,
		queenSpawnMult    = 3,
		angerBonus        = 1,
		maxXP			  = 3,
		spawnChance       = 0.6,
		damageMod         = 1.4,
		maxBurrows        = 1000,
		minChickens		  = 5,
		maxChickens		  = 50,
		chickenPerPlayerMultiplier = 0.25,
		queenName         = 'epic_chickenq',
		queenResistanceMult   = 2,
	},

	-- [difficulties.survival] = {
	-- 	gracePeriod       = 8 * Spring.GetModOptions().chicken_graceperiodmult * 60,
	-- 	queenTime      	  = 50 * Spring.GetModOptions().chicken_queentimemult * 60, -- time at which the queen appears, frames
	-- 	chickenSpawnRate  = 120,
	-- 	burrowSpawnRate   = 480,
	-- 	turretSpawnRate   = 240,
	-- 	queenSpawnMult    = 1,
	-- 	angerBonus        = 1,
	-- 	maxXP			  = 0.5,
	-- 	spawnChance       = 0.1,
	-- 	damageMod         = 0.4,
	-- 	maxBurrows        = 1000,
	-- 	minChickens		  = 5,
	-- 	maxChickens		  = 25,
	-- 	chickenPerPlayerMultiplier = 0.25,
	-- 	queenName         = 've_chickenq',
	-- 	queenResistanceMult   = 0.5,
	-- },
}


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local squadSpawnOptionsTable = {
	basic = {}, -- 67% spawn chance
	special = {}, -- 33% spawn chance, there's 1% chance of Special squad spawning Super squad, which is specials but 30% anger earlier.
	air = {}, -- Air waves
}

local function addNewSquad(squadParams) -- params: {type = "basic", minAnger = 0, maxAnger = 100, units = {"1 chicken1"}, weight = 1}
	if squadParams then -- Just in case
		if not squadParams.units then return end
		if not squadParams.minAnger then squadParams.minAnger = 0 end
		if not squadParams.maxAnger then squadParams.maxAnger = 100 end -- Eliminate squads 100% after they're introduced by default, can be overwritten
		if squadParams.maxAnger >= 100 then squadParams.maxAnger = 1000 end -- basically infinite
		if not squadParams.weight then squadParams.weight = 1 end

		for _ = 1,squadParams.weight do
			table.insert(squadSpawnOptionsTable[squadParams.type], {minAnger = squadParams.minAnger, maxAnger = squadParams.maxAnger, units = squadParams.units, weight = squadParams.weight})
		end
	end
end

-- addNewSquad({type = "basic", minAnger = 0, units = {"1 chicken1"}}) -- Minimum
-- addNewSquad({type = "basic", minAnger = 0, units = {"1 chicken1"}, weight = 1, maxAnger = 100}) -- Full

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- MiniBoss Squads ----------------------------------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local miniBosses = { -- Units that spawn alongside queen
	"chicken_miniqueen_electric", 	-- Electric Miniqueen
	"chicken_miniqueen_acid", 		-- Acid Miniqueen
	"chicken_miniqueen_healer", 	-- Healer Miniqueen
	"chicken_miniqueen_basic",		-- Basic Miniqueen
	"chicken_miniqueen_fire",		-- Pyro Miniqueen
	"chicken_miniqueen_spectre",	-- Spectre Miniqueen
}

local chickenMinions = { -- Units spawning other units
	["chicken_miniqueen_electric"] = {
		"chickene1",
		"chickene2",
		--"chickenearty1",
		"chickenelectricallterrain",
		"chickenelectricallterrainassault",
	},
	["chicken_miniqueen_acid"] = {
		"chickenacidswarmer",
		"chickenacidassault",
		--"chickenacidarty",
		"chickenacidallterrain",
		"chickenacidallterrainassault",
	},
	["chicken_miniqueen_healer"] = {
		"chickenh1",
		--"chickenh1b",
	},
	["chicken_miniqueen_basic"] = {
		"chicken1",
		"chicken1x",
		"chicken2",
		"chicken2b",
		"chickenc3c",
	},
	["chicken_miniqueen_fire"] = {
		"chickenp1",
		"chickenp2",
		"chickenpyroallterrain",
	},
	["chicken_miniqueen_spectre"] = {
		"chickens2_spectre",
		"chicken1x_spectre",
		"chicken2_spectre",
		"chickena1_spectre",
		"chickena2_spectre",
	},
	["chickenh2"] = {
		"chickenh3",
		"chickenh4",
	},
	["chickenh3"] = {
		"chickenh4",
	},
	["chickenbroodartyh4"] = {
		"chickenh4",
		"chickenbroodartyh4small",
	},
	["ve_chickenq"] = {
		"chickenh2",
		"chickenh3",
		"chickenh4",
	},
	["e_chickenq"] = {
		"chickenh2",
		"chickenh3",
		"chickenh4",
		"chickenbroodartyh4small",
	},
	["n_chickenq"] = {
		"chickenh2",
		"chickenh3",
		"chickenh4",
		"chickenbroodartyh4small",
	},
	["h_chickenq"] = {
		"chickenh2",
		"chickenh3",
		"chickenh4",
		"chickenbroodartyh4small",
	},
	["vh_chickenq"] = {
		"chickenh2",
		"chickenh3",
		"chickenh4",
		"chickenbroodartyh4small",
	},
	["epic_chickenq"] = {
		"chickenh2",
		"chickenh3",
		"chickenh4",
		"chickenbroodartyh4small",
	},
}

local chickenHealers = { -- Spawn indepedently from squads in small numbers
	"chickenh1",
	--"chickenh1b",
},

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Squads -------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-----------
-- Basic --
-----------

-- Basic Swarmer
addNewSquad({ type = "basic", minAnger = 0, units = { "4 chicken1_mini" }, weight = 5, maxAnger = 30 })
addNewSquad({ type = "basic", minAnger = 5, units = { "4 chicken1" }, maxAnger = 70 })
addNewSquad({ type = "basic", minAnger = 5, units = { "4 chicken1b" }, maxAnger = 70 })
addNewSquad({ type = "basic", minAnger = 5, units = { "4 chicken1c" }, maxAnger = 70 })
addNewSquad({ type = "basic", minAnger = 5, units = { "4 chicken1d" }, maxAnger = 70 })

-- Better Swarmer
addNewSquad({ type = "basic", minAnger = 25, units = { "4 chicken1x" }, maxAnger = 1000 })
addNewSquad({ type = "basic", minAnger = 25, units = { "4 chicken1y" }, maxAnger = 1000 })
addNewSquad({ type = "basic", minAnger = 25, units = { "4 chicken1z" }, maxAnger = 1000 })

-- Brawlers
addNewSquad({ type = "basic", minAnger = 35, units = { "3 chickena1" }, maxAnger = 1000 })
addNewSquad({ type = "basic", minAnger = 35, units = { "3 chickena1b" }, maxAnger = 1000 })
addNewSquad({ type = "basic", minAnger = 35, units = { "3 chickena1c" }, maxAnger = 1000 })

-- Apex Swarmer and  Apex Brawler
addNewSquad({ type = "basic", minAnger = 65, units = { "4 chicken2b" }, maxAnger = 1000 })
addNewSquad({ type = "basic", minAnger = 65, units = { "4 chicken2" }, maxAnger = 1000 })
addNewSquad({ type = "basic", minAnger = 65, units = { "1 chickena2" }, maxAnger = 1000 })
addNewSquad({ type = "basic", minAnger = 65, units = { "1 chickena2b" }, maxAnger = 1000 })

-------------
-- Special --
-------------

addNewSquad({ type = "special", minAnger = 20, units = { "5 chickenp1" } })
addNewSquad({ type = "special", minAnger = 20, units = { "3 chickene1" } })
addNewSquad({ type = "special", minAnger = 20, units = { "4 chicken1x" }, maxAnger = 40 })
addNewSquad({ type = "special", minAnger = 20, units = { "4 chicken1y" }, maxAnger = 40 })
addNewSquad({ type = "special", minAnger = 20, units = { "4 chicken1z" }, maxAnger = 40 })

addNewSquad({ type = "special", minAnger = 30, units = { "5 chickens1" }, weight = 3 })
addNewSquad({ type = "special", minAnger = 30, units = { "10 chickenp1" } })

addNewSquad({ type = "special", minAnger = 30, units = { "15 chicken_dodo1_electric" } })
addNewSquad({ type = "special", minAnger = 30, units = { "15 chickenc3" }, weight = 3 })

addNewSquad({ type = "special", minAnger = 40, units = { "3 chickene2" } })
addNewSquad({ type = "special", minAnger = 40, units = { "10 chickenacidswarmer" } })
addNewSquad({ type = "special", minAnger = 40, units = { "10 chicken1x_spectre" } })
addNewSquad({ type = "special", minAnger = 40, units = { "10 chickenc3b" }, weight = 3 })
addNewSquad({ type = "special", minAnger = 40, units = { "15 chicken_dodo1" } })
addNewSquad({ type = "special", minAnger = 40, units = { "10 chicken_dodo1", "10 chicken_dodo1_electric" } })

addNewSquad({ type = "special", minAnger = 50, units = { "10 chickenpyroallterrain" } })
addNewSquad({ type = "special", minAnger = 50, units = { "10 chickenelectricallterrain" } })
addNewSquad({ type = "special", minAnger = 50, units = { "5 chickene1", "5 chickenacidswarmer" } })
addNewSquad({ type = "special", minAnger = 50, units = { "3 chickenr1" } })
addNewSquad({ type = "special", minAnger = 50, units = { "3 chickenacidarty" } })
addNewSquad({ type = "special", minAnger = 50, units = { "3 chickenearty1" } })
addNewSquad({ type = "special", minAnger = 50, units = { "3 chickenbroodartyh4small" } })
addNewSquad({ type = "special", minAnger = 50, units = { "5 chickenc3c" }, weight = 3 })
addNewSquad({ type = "special", minAnger = 50, units = { "6 chickenallterraina1" }, weight = 2 })
addNewSquad({ type = "special", minAnger = 50, units = { "6 chickenallterraina1b" }, weight = 2 })
addNewSquad({ type = "special", minAnger = 50, units = { "6 chickenallterraina1c" }, weight = 2 })
addNewSquad({ type = "special", minAnger = 50, units = { "6 chickena1_spectre" } })
addNewSquad({ type = "special", minAnger = 50, units = { "5 chickenelectricallterrain", "5 chickenacidallterrain" } })
addNewSquad({ type = "special", minAnger = 50, units = { "5 chickenh4" } })

addNewSquad({ type = "special", minAnger = 60, units = { "8 chickenp2" } })
addNewSquad({ type = "special", minAnger = 60, units = { "3 chickene2" } })
addNewSquad({ type = "special", minAnger = 60, units = { "3 chickenelectricallterrainassault" } })
addNewSquad({ type = "special", minAnger = 60, units = { "10 chickens2" }, weight = 2 })
addNewSquad({ type = "special", minAnger = 60, units = { "5 chickenh4" } })
addNewSquad({ type = "special", minAnger = 60, units = { "25 chicken_dodo2_electric" } })

addNewSquad({ type = "special", minAnger = 70, units = { "25 chicken_dodo2" } })
addNewSquad({ type = "special", minAnger = 70, units = { "20 chicken_dodo2", "20 chicken_dodo2_electric" } })
addNewSquad({ type = "special", minAnger = 70, units = { "10 chickenacidallterrain" } })
addNewSquad({ type = "special", minAnger = 70, units = { "4 chickenacidassault" } })
addNewSquad({ type = "special", minAnger = 70, units = { "3 chickene2" } })
addNewSquad({ type = "special", minAnger = 70, units = { "4 chickenacidallterrainassault" } })
addNewSquad({ type = "special", minAnger = 70, units = { "3 chickenh3" } })
addNewSquad({ type = "special", minAnger = 70, units = { "5 chickenh4" } })
addNewSquad({ type = "special", minAnger = 70, units = { "5 chicken2_spectre" } })
addNewSquad({ type = "special", minAnger = 70, units = { "10 chickens2_spectre" } })
addNewSquad({ type = "special", minAnger = 70, units = { "1 chickenr2" } })
addNewSquad({ type = "special", minAnger = 70, units = { "1 chickenearty2" } })
addNewSquad({ type = "special", minAnger = 70, units = { "1 chickenacidartyxl" } })
addNewSquad({ type = "special", minAnger = 70, units = { "1 chickenbroodartyh4" } })

addNewSquad({ type = "special", minAnger = 80, units = { "2 chickenapexallterrainassault" } })
addNewSquad({ type = "special", minAnger = 80, units = { "2 chickenapexallterrainassaultb" } })
addNewSquad({ type = "special", minAnger = 80, units = { "4 chickena2_spectre" } })
addNewSquad({ type = "special", minAnger = 80, units = { "3 chickenr1" }, weight = 3 })
addNewSquad({ type = "special", minAnger = 80, units = { "3 chickenh3" } })
addNewSquad({ type = "special", minAnger = 80, units = { "10 chickenh4" } })
addNewSquad({ type = "special", minAnger = 80, units = { "1 chickenr2" } })
addNewSquad({ type = "special", minAnger = 80, units = { "1 chickenearty2" } })
addNewSquad({ type = "special", minAnger = 80, units = { "1 chickenacidartyxl" } })
addNewSquad({ type = "special", minAnger = 80, units = { "1 chickenbroodartyh4" } })

addNewSquad({ type = "special", minAnger = 90, units = { "2 chickenapexallterrainassault" } })
addNewSquad({ type = "special", minAnger = 90, units = { "2 chickenapexallterrainassaultb" } })
addNewSquad({ type = "special", minAnger = 90, units = { "4 chickena2_spectre" } })
addNewSquad({ type = "special", minAnger = 90, units = { "3 chickenr1" }, weight = 3 })
addNewSquad({ type = "special", minAnger = 90, units = { "2 chickenh2" } })
addNewSquad({ type = "special", minAnger = 90, units = { "3 chickenh3" } })
addNewSquad({ type = "special", minAnger = 90, units = { "10 chickenh4" } })
addNewSquad({ type = "special", minAnger = 90, units = { "1 chickenr2" } })
addNewSquad({ type = "special", minAnger = 90, units = { "1 chickenearty2" } })
addNewSquad({ type = "special", minAnger = 90, units = { "1 chickenacidartyxl" } })
addNewSquad({ type = "special", minAnger = 90, units = { "1 chickenbroodartyh4" } })

addNewSquad({ type = "special", minAnger = 100, units = { "5 chickenapexallterrainassault" } })
addNewSquad({ type = "special", minAnger = 100, units = { "5 chickenapexallterrainassaultb" } })
addNewSquad({ type = "special", minAnger = 100, units = { "10 chickena2_spectre" } })
addNewSquad({ type = "special", minAnger = 100, units = { "3 chickenr1" }, weight = 3 })
addNewSquad({ type = "special", minAnger = 100, units = { "3 chickenearty1" }, weight = 3 })
addNewSquad({ type = "special", minAnger = 100, units = { "3 chickenacidarty" }, weight = 3 })
addNewSquad({ type = "special", minAnger = 100, units = { "3 chickenbroodartyh4small" }, weight = 3 })
addNewSquad({ type = "special", minAnger = 100, units = { "2 chickenh2" } })
addNewSquad({ type = "special", minAnger = 100, units = { "3 chickene2" } })
addNewSquad({ type = "special", minAnger = 100, units = { "3 chickenelectricallterrainassault" } })
addNewSquad({ type = "special", minAnger = 100, units = { "3 chickenacidassault" } })
addNewSquad({ type = "special", minAnger = 100, units = { "3 chickenacidallterrainassault" } })
addNewSquad({ type = "special", minAnger = 100, units = { "25 chicken_dodo2" } })
addNewSquad({ type = "special", minAnger = 100, units = { "25 chicken_dodo2_electric" } })
addNewSquad({ type = "special", minAnger = 100, units = { "20 chicken_dodo2", "20 chicken_dodo2_electric" } })
addNewSquad({ type = "special", minAnger = 100, units = { "10 chickenp2" } })
addNewSquad({ type = "special", minAnger = 100, units = { "10 chickens2" }, weight = 2 })
addNewSquad({ type = "special", minAnger = 100, units = { "10 chickens2_spectre" } })
addNewSquad({ type = "special", minAnger = 100, units = { "2 chickenr2" } })
addNewSquad({ type = "special", minAnger = 100, units = { "2 chickenearty2" } })
addNewSquad({ type = "special", minAnger = 100, units = { "2 chickenacidartyxl" } })
addNewSquad({ type = "special", minAnger = 100, units = { "2 chickenbroodartyh4" } })

for j = 1, #miniBosses do
	addNewSquad({ type = "special", minAnger = 70, units = { "1 " .. miniBosses[j] }})
	addNewSquad({ type = "special", minAnger = 100, units = { "1 " .. miniBosses[j] }})
end

---------
-- Air --
---------

local airStartAnger = 20 -- needed for air waves to work correctly.

addNewSquad({ type = "air", minAnger = 20, units = { "4 chickenw1_mini" } })
addNewSquad({ type = "air", minAnger = 20, units = { "4 chickenf1_mini" } })

addNewSquad({ type = "air", minAnger = 40, units = { "4 chickenw1", } })
addNewSquad({ type = "air", minAnger = 40, units = { "4 chickenw1b", } })
addNewSquad({ type = "air", minAnger = 40, units = { "4 chickenw1c", } })
addNewSquad({ type = "air", minAnger = 40, units = { "4 chickenw1d", } })
addNewSquad({ type = "air", minAnger = 40, units = { "4 chickenf1", }, weight = 2 })
addNewSquad({ type = "air", minAnger = 40, units = { "4 chickenf1b", }, weight = 2 })

addNewSquad({ type = "air", minAnger = 50, units = { "2 chickenbroodbomberh4" } })

addNewSquad({ type = "air", minAnger = 60, units = { "4 chickenebomber1" } })
addNewSquad({ type = "air", minAnger = 60, units = { "4 chickenacidbomber" } })

addNewSquad({ type = "air", minAnger = 70, units = { "10 chicken_dodoair" }, weight = 2 })
addNewSquad({ type = "air", minAnger = 70, units = { "2 chickenbroodbomberh3" } })
addNewSquad({ type = "air", minAnger = 70, units = { "2 chickenbroodbomberh4" } })

addNewSquad({ type = "air", minAnger = 80, units = { "2 chickenf1apex" } })
addNewSquad({ type = "air", minAnger = 80, units = { "2 chickenf1apexb" } })
addNewSquad({ type = "air", minAnger = 80, units = { "6 chickenw2" }, weight = 2 })

addNewSquad({ type = "air", minAnger = 90, units = { "10 chicken_dodoair" }, weight = 2 })
addNewSquad({ type = "air", minAnger = 90, units = { "2 chickenbroodbomberh2" } })
addNewSquad({ type = "air", minAnger = 90, units = { "2 chickenbroodbomberh3" } })
addNewSquad({ type = "air", minAnger = 90, units = { "2 chickenbroodbomberh4" } })

addNewSquad({ type = "air", minAnger = 100, units = { "3 chickenf1apex" } })
addNewSquad({ type = "air", minAnger = 100, units = { "3 chickenf1apexb" } })
addNewSquad({ type = "air", minAnger = 100, units = { "8 chickenw2" }, weight = 2 })
addNewSquad({ type = "air", minAnger = 100, units = { "10 chicken_dodoair" }, weight = 2 })
addNewSquad({ type = "air", minAnger = 100, units = { "4 chickenbroodbomberh4" } })
addNewSquad({ type = "air", minAnger = 100, units = { "4 chickenbroodbomberh3" } })
addNewSquad({ type = "air", minAnger = 100, units = { "4 chickenbroodbomberh2" } })

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Settings -- Adjust these
local useEggs = true -- Drop eggs (requires egg features from Beyond All Reason)
local useScum = true -- Use scum as space where turrets can spawn (requires scum gadget from Beyond All Reason)
local useWaveMsg = true -- Show dropdown message whenever new wave is spawning
local spawnSquare = 90 -- size of the chicken spawn square centered on the burrow
local spawnSquareIncrement = 2 -- square size increase for each unit spawned
local minBaseDistance = 256 -- Minimum distance of new burrows from players and other burrows
local burrowTurretSpawnRadius = 80

local ecoBuildingsPenalty = { -- Additional queen hatch per second from eco buildup (for 60 minutes queen time. scales to queen time)
	--[[
	-- T1 Energy
	[UnitDefNames["armsolar"].id] 	= 0.0000001,
	[UnitDefNames["corsolar"].id] 	= 0.0000001,
	[UnitDefNames["armwin"].id] 	= 0.0000001,
	[UnitDefNames["corwin"].id] 	= 0.0000001,
	[UnitDefNames["armtide"].id] 	= 0.0000001,
	[UnitDefNames["cortide"].id] 	= 0.0000001,
	[UnitDefNames["armadvsol"].id] 	= 0.000005,
	[UnitDefNames["coradvsol"].id] 	= 0.000005,

	-- T2 Energy
	[UnitDefNames["armwint2"].id] 	= 0.000075,
	[UnitDefNames["corwint2"].id] 	= 0.000075,
	[UnitDefNames["armfus"].id] 	= 0.000125,
	[UnitDefNames["armckfus"].id] 	= 0.000125,
	[UnitDefNames["corfus"].id] 	= 0.000125,
	[UnitDefNames["armuwfus"].id] 	= 0.000125,
	[UnitDefNames["coruwfus"].id] 	= 0.000125,
	[UnitDefNames["armafus"].id] 	= 0.0005,
	[UnitDefNames["corafus"].id] 	= 0.0005,

	-- T1 Metal Makers
	[UnitDefNames["armmakr"].id] 	= 0.00005,
	[UnitDefNames["cormakr"].id] 	= 0.00005,
	[UnitDefNames["armfmkr"].id] 	= 0.00005,
	[UnitDefNames["corfmkr"].id] 	= 0.00005,
	
	-- T2 Metal Makers
	[UnitDefNames["armmmkr"].id] 	= 0.0005,
	[UnitDefNames["cormmkr"].id] 	= 0.0005,
	[UnitDefNames["armuwmmm"].id] 	= 0.0005,
	[UnitDefNames["coruwmmm"].id] 	= 0.0005,
	]]--
}

local highValueTargets = { -- Priority targets for Chickens. Must be immobile to prevent issues.
	-- T2 Energy
	[UnitDefNames["armwint2"].id] 	= true,
	[UnitDefNames["corwint2"].id] 	= true,
	[UnitDefNames["armfus"].id] 	= true,
	[UnitDefNames["armckfus"].id] 	= true,
	[UnitDefNames["corfus"].id] 	= true,
	[UnitDefNames["armuwfus"].id] 	= true,
	[UnitDefNames["coruwfus"].id] 	= true,
	[UnitDefNames["armafus"].id] 	= true,
	[UnitDefNames["corafus"].id] 	= true,
	-- T2 Metal Makers
	[UnitDefNames["armmmkr"].id] 	= true,
	[UnitDefNames["cormmkr"].id] 	= true,
	[UnitDefNames["armuwmmm"].id] 	= true,
	[UnitDefNames["coruwmmm"].id] 	= true,

	[UnitDefNames["cormoho"].id] 	= true,
	[UnitDefNames["armmoho"].id] 	= true,
}

local config = { -- Don't touch this! ---------------------------------------------------------------------------------------------------------------------------------------------
	useEggs 				= useEggs,
	useScum					= useScum,
	difficulty             	= difficulty,
	difficulties           	= difficulties,
	chickenEggs			   	= table.copy(chickenEggs),
	chickenHealers			= table.copy(chickenHealers),
	burrowName             	= burrowName,   -- burrow unit name
	burrowDef              	= UnitDefNames[burrowName].id,
	chickenSpawnMultiplier 	= Spring.GetModOptions().chicken_spawncountmult,
	burrowSpawnType        	= Spring.GetModOptions().chicken_chickenstart,
	swarmMode			   	= Spring.GetModOptions().chicken_swarmmode,
	spawnSquare            	= spawnSquare,       
	spawnSquareIncrement   	= spawnSquareIncrement,         
	minBaseDistance        	= minBaseDistance,
	chickenTurrets			= table.copy(chickenTurrets),
	miniBosses			   	= miniBosses,
	chickenMinions			= chickenMinions,
	chickenBehaviours 		= chickenBehaviours,
	difficultyParameters   	= optionValues,
	useWaveMsg 				= useWaveMsg,
	burrowTurretSpawnRadius = burrowTurretSpawnRadius,
	squadSpawnOptionsTable	= squadSpawnOptionsTable,
	airStartAnger			= airStartAnger,
	ecoBuildingsPenalty		= ecoBuildingsPenalty,
	highValueTargets		= highValueTargets,
}

for key, value in pairs(optionValues[difficulty]) do
	config[key] = value
end

return config