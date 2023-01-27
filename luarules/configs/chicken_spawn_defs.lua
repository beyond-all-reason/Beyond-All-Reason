
local difficulties = {
	-- veryeasy = 0,
	-- easy     = 1,
	normal   = 0,
	hard     = 1,
	veryhard = 2,
	insane   = 3,
	epic     = 4,
	unbeatable = 5,
	survival = 6,
}

local difficulty = difficulties[Spring.GetModOptions().chicken_difficulty]
local waves = {}
local basicWaves = {}
local specialWaves = {}
local superWaves = {}
local airWaves = {}

local burrowName = 'chicken_hive'

local chickenNukeTurret
if not Spring.GetModOptions().unit_restrictions_nonukes then
	chickenNukeTurret = "chicken_turretxl_meteor"
else
	chickenNukeTurret = "chicken_turretl"
end

local chickenTurrets = {
	lightTurrets = { 					-- Spawn from the start
		"chicken_turrets",
	},
	heavyTurrets = { 					-- Spawn from 20% queen anger
		"chicken_turretl",
	},
	specialLightTurrets = { 			-- Spawn from 40% queen anger alongside lightTurrets
		"chicken_turrets_acid",
		"chicken_turrets_electric",
	},
	specialHeavyTurrets = { 			-- Spawn from 60% queen anger alongside heavyTurrets
		"chicken_turretl_acid",
		"chicken_turretl_electric",
		chickenNukeTurret,
	},
	burrowDefenders = {					-- Spawns connected to burrow
		"chicken_turrets_burrow",
	},
}

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
	chickenh5      						=   "white",
	chickenw1      						=   "purple",
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
	chickenebomber1 					=   "blue",
	chickenelectricallterrain 			=   "blue",
	chickenelectricallterrainassault	=   "blue",
	chickenacidswarmer 					=   "acidgreen",
	chickenacidassault 					=   "acidgreen",
	chickenacidarty 					=   "acidgreen",
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
	chicken_miniqueen_spectre 				=  	"yellow",
}

chickenBehaviours = {
	SKIRMISH = { -- Run away from target after target gets hit
		[UnitDefNames["chickens1"].id] = { distance = 270, chance = 0.5 },
		[UnitDefNames["chickens2"].id] = { distance = 250, chance = 0.5 },
		[UnitDefNames["chickenr1"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["chickenr2"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["chickene1"].id] = { distance = 300, chance = 1 },
		[UnitDefNames["chickene2"].id] = { distance = 200, chance = 0.01 },	
		[UnitDefNames["chickenelectricallterrainassault"].id] = { distance = 200, chance = 0.01 },
		[UnitDefNames["chickenearty1"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["chickenelectricallterrain"].id] = { distance = 300, chance = 1 },
		[UnitDefNames["chickenacidswarmer"].id] = { distance = 300, chance = 1 },
		[UnitDefNames["chickenacidassault"].id] = { distance = 200, chance = 1 },
		[UnitDefNames["chickenacidallterrainassault"].id] = { distance = 200, chance = 1 },
		[UnitDefNames["chickenacidarty"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["chickenacidallterrain"].id] = { distance = 300, chance = 1 },
		[UnitDefNames["chickenh2"].id] = { distance = 500, chance = 0.25 },
		[UnitDefNames["chicken1x_spectre"].id] = { distance = 500, chance = 0.25, teleport = true, teleportcooldown = 2,},
		[UnitDefNames["chicken2_spectre"].id] = { distance = 500, chance = 0.25, teleport = true, teleportcooldown = 2,},
		[UnitDefNames["chickens2_spectre"].id] = { distance = 500, chance = 0.25, teleport = true, teleportcooldown = 2,},
		[UnitDefNames["chickena1_spectre"].id] = { distance = 500, chance = 0.25, teleport = true, teleportcooldown = 2,},
		[UnitDefNames["chickena2_spectre"].id] = { distance = 500, chance = 0.25, teleport = true, teleportcooldown = 2,},
	},
	COWARD = { -- Run away from target after getting hit by enemy
		[UnitDefNames["chickenh1"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["chickenh1b"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["chickens1"].id] = { distance = 270, chance = 0.5 },
		[UnitDefNames["chickens2"].id] = { distance = 250, chance = 0.5 },
		[UnitDefNames["chickenr1"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["chickenr2"].id] = { distance = 500, chance = 0.1 },
		[UnitDefNames["chickenearty1"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["chickenacidarty"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["chickenh2"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["chickenh3"].id] = { distance = 500, chance = 0.25 },
		[UnitDefNames["chicken1x_spectre"].id] = { distance = 500, chance = 0.25, teleport = true, teleportcooldown = 2,},
		[UnitDefNames["chicken2_spectre"].id] = { distance = 500, chance = 0.25, teleport = true, teleportcooldown = 2,},
		[UnitDefNames["chickens2_spectre"].id] = { distance = 500, chance = 0.25, teleport = true, teleportcooldown = 2,},
		[UnitDefNames["chickena1_spectre"].id] = { distance = 500, chance = 0.25, teleport = true, teleportcooldown = 2,},
		[UnitDefNames["chickena2_spectre"].id] = { distance = 500, chance = 0.25, teleport = true, teleportcooldown = 2,},
	},
	BERSERK = { -- Run towards target after getting hit by enemy or after hitting the target
		[UnitDefNames["ve_chickenq"].id] = { chance = 0.01 },
		[UnitDefNames["e_chickenq"].id] = { chance = 0.05 },
		[UnitDefNames["n_chickenq"].id] = { chance = 0.1 },
		[UnitDefNames["h_chickenq"].id] = { chance = 0.2 },
		[UnitDefNames["vh_chickenq"].id] = { chance = 0.3 },
		[UnitDefNames["epic_chickenq"].id] = { chance = 0.5 },
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
		[UnitDefNames["chicken_miniqueen_spectre"].id] = { chance = 1 },
		[UnitDefNames["chicken_miniqueen_electric"].id] = { chance = 1 },
		[UnitDefNames["chicken_miniqueen_acid"].id] = { chance = 1 },
		[UnitDefNames["chicken_miniqueen_healer"].id] = { chance = 1 },
		[UnitDefNames["chicken_miniqueen_basic"].id] = { chance = 1 },
		[UnitDefNames["chicken_miniqueen_fire"].id] = { chance = 1 },
	},
	HEALER = { -- Getting long max lifetime and always use Fight command. These units spawn as healers from burrows and queen
		"chickenh1",
		--"chickenh1b",
	},
	ARTILLERY = { -- Long lifetime and no regrouping, always uses Fight command to keep distance
		"chickenr1",
		"chickenr2",
		"chickenearty1",
		"chickenacidarty",
		"chicken_turretxl_meteor",
	},
	KAMIKAZE = { -- Long lifetime and no regrouping, always uses Move command to rush into the enemy
		"chicken_dodo1",
		"chicken_dodo2",
	},
	PROBE_UNIT = UnitDefNames["chicken2"].id, -- tester unit for picking viable spawn positions - use some medium sized unit
}

local optionValues = {
	-- [difficulties.veryeasy] = {
	-- 	chickenSpawnRate  = 120,
	-- 	burrowSpawnRate   = 105,
	-- 	turretSpawnRate   = 210,
	-- 	queenSpawnMult    = 0,
	-- 	angerBonus        = 1,
	-- 	maxXP			  = 0.1,
	-- 	spawnChance       = 0.25,
	-- 	damageMod         = 0.1,
	-- 	maxBurrows        = 2,
	-- 	minChickens		  = 5,
	-- 	maxChickens		  = 75,
	-- 	queenName         = 've_chickenq',
	-- 	queenResistanceMult   = 0.25,
	-- },
	-- [difficulties.easy] = {
	-- 	chickenSpawnRate  = 120,
	-- 	burrowSpawnRate   = 90,
	-- 	turretSpawnRate   = 180,
	-- 	queenSpawnMult    = 0,
	-- 	angerBonus        = 1,
	-- 	maxXP			  = 0.25,
	-- 	spawnChance       = 0.33,
	-- 	damageMod         = 0.2,
	-- 	maxBurrows        = 3,
	-- 	minChickens		  = 10,
	-- 	maxChickens		  = 100,
	-- 	queenName         = 'e_chickenq',
	-- 	queenResistanceMult   = 0.5,
	-- },

	[difficulties.normal] = {
		chickenSpawnRate  = 60,
		burrowSpawnRate   = 75,
		turretSpawnRate   = 150,
		queenSpawnMult    = 1,
		angerBonus        = 1,
		maxXP			  = 0.5,
		spawnChance       = 0.2,
		damageMod         = 0.4,
		maxBurrows        = 1000,
		minChickens		  = 10,
		maxChickens		  = 25,
		chickenPerPlayerMultiplier = 0.25,
		queenName         = 've_chickenq',
		queenResistanceMult   = 1,
	},

	[difficulties.hard] = {
		chickenSpawnRate  = 50,
		burrowSpawnRate   = 60,
		turretSpawnRate   = 120,
		queenSpawnMult    = 1,
		angerBonus        = 1,
		maxXP			  = 1,
		spawnChance       = 0.3,
		damageMod         = 0.6,
		maxBurrows        = 1000,
		minChickens		  = 10,
		maxChickens		  = 50,
		chickenPerPlayerMultiplier = 0.25,
		queenName         = 'e_chickenq',
		queenResistanceMult   = 1.25,
	},
	[difficulties.veryhard] = {
		chickenSpawnRate  = 40,
		burrowSpawnRate   = 45,
		turretSpawnRate   = 90,
		queenSpawnMult    = 3,
		angerBonus        = 1,
		maxXP			  = 1.5,
		spawnChance       = 0.4,
		damageMod         = 0.8,
		maxBurrows        = 1000,
		minChickens		  = 10,
		maxChickens		  = 75,
		chickenPerPlayerMultiplier = 0.25,
		queenName         = 'n_chickenq',
		queenResistanceMult   = 1.5,
	},
	[difficulties.insane] = {
		chickenSpawnRate  = 30,
		burrowSpawnRate   = 30,
		turretSpawnRate   = 60,
		queenSpawnMult    = 3,
		angerBonus        = 1,
		maxXP			  = 2,
		spawnChance       = 0.5,
		damageMod         = 1,
		maxBurrows        = 1000,
		minChickens		  = 10,
		maxChickens		  = 100,
		chickenPerPlayerMultiplier = 0.25,
		queenName         = 'h_chickenq',
		queenResistanceMult   = 1.75,
	},
	[difficulties.epic] = {
		chickenSpawnRate  = 30,
		burrowSpawnRate   = 20,
		turretSpawnRate   = 40,
		queenSpawnMult    = 3,
		angerBonus        = 1,
		maxXP			  = 5,
		spawnChance       = 0.6,
		damageMod         = 1.5,
		maxBurrows        = 1000,
		minChickens		  = 10,
		maxChickens		  = 125,
		chickenPerPlayerMultiplier = 0.25,
		queenName         = 'vh_chickenq',
		queenResistanceMult   = 2,
	},
	[difficulties.unbeatable] = {
		chickenSpawnRate  = 30,
		burrowSpawnRate   = 10,
		turretSpawnRate   = 20,
		queenSpawnMult    = 3,
		angerBonus        = 1,
		maxXP			  = 10,
		spawnChance       = 0.8,
		damageMod         = 2,
		maxBurrows        = 1000,
		minChickens		  = 10,
		maxChickens		  = 150,
		chickenPerPlayerMultiplier = 0.25,
		queenName         = 'epic_chickenq',
		queenResistanceMult   = 2.5,
	},

	[difficulties.survival] = {
		chickenSpawnRate  = 60,
		burrowSpawnRate   = 75,
		turretSpawnRate   = 150,
		queenSpawnMult    = 1,
		angerBonus        = 1,
		maxXP			  = 0.5,
		spawnChance       = 0.2,
		damageMod         = 0.4,
		maxBurrows        = 1000,
		minChickens		  = 10,
		maxChickens		  = 25,
		chickenPerPlayerMultiplier = 0.25,
		queenName         = 'n_chickenq',
		queenResistanceMult   = 1,
	},
}


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local wavesAmount = 10
if difficulty >= 3 then
	wavesAmount = 12
end

-- local function addSquad(wave, unitList, weight) -- unused
-- 	if not weight then weight = 1 end
--     for i = 1, weight do 
-- 		for j = wave,wavesAmount do
-- 			if not waves[j] then
-- 				waves[j] = {}
-- 			end
-- 			table.insert(waves[j], unitList)
-- 		end
--     end
-- end

local function addSuperSquad(wave, unitList, weight)
	if not weight then weight = 1 end
    for i = 1, weight do
		for j = wave,wavesAmount do
			wave = math.max(math.min(wave+math.random(-1,1), wavesAmount), 1)
			if not superWaves[j] then
				superWaves[j] = {}
			end
			table.insert(superWaves[j], unitList)
		end
    end
end

local function addSpecialSquad(wave, unitList, weight)
	if not weight then weight = 1 end
	addSuperSquad(math.max(wave-3, 1), unitList, weight)
    for i = 1, weight do 
		for j = wave,wavesAmount do
			wave = math.max(math.min(wave+math.random(-1,1), wavesAmount), 1)
			if not specialWaves[j] then
				specialWaves[j] = {}
			end
			table.insert(specialWaves[j], unitList)
		end
    end
end

local function addBasicSquad(wave, unitList, weight)
	if not weight then weight = 1 end
    for i = 1, weight do 
		for j = wave,wavesAmount do
			if not basicWaves[j] then
				basicWaves[j] = {}
			end
			table.insert(basicWaves[j], unitList)
		end
    end
end

local function addAirSquad(wave, unitList, weight)
	if not weight then weight = 1 end
    for i = 1, weight do
		for j = wave,wavesAmount do
			wave = math.max(math.min(wave+math.random(-1,1), wavesAmount), 1)
			if not airWaves[j] then
				airWaves[j] = {}
			end
			table.insert(airWaves[j], unitList)
		end
    end
end

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
		"chickenearty1",
		"chickenelectricallterrain",
		"chickenelectricallterrainassault",
	},
	["chicken_miniqueen_acid"] = {
		"chickenacidswarmer",
		"chickenacidassault",
		"chickenacidarty",
		"chickenacidallterrain",
		"chickenacidallterrainassault",
	},
	["chicken_miniqueen_healer"] = {
		"chickenh1",
		--"chickenh1b",
	},
	["chicken_miniqueen_basic"] = {
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
		"chickenh2",
		"chickenh3",
		"chickenh4",
	},
	["chickenh3"] = {
		"chickenh3",
		"chickenh4",
	},
	["chickenh4"] = {
		"chickenh4",
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
	},
	["n_chickenq"] = {
		"chickenh2",
		"chickenh3",
		"chickenh4",
	},
	["h_chickenq"] = {
		"chickenh2",
		"chickenh3",
		"chickenh4",
	},
	["vh_chickenq"] = {
		"chickenh2",
		"chickenh3",
		"chickenh4",
	},
	["epic_chickenq"] = {
		"chickenh2",
		"chickenh3",
		"chickenh4",
	},
}

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Special Squads -----------------------------------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	addSpecialSquad(3, { "5 chickens1" 																	}, 5) -- Spiker
	addSpecialSquad(3, { "10 chickenp1"  												            	}) -- Small Pyro
	addSpecialSquad(3, { "8 chickene1"                                                                  }) -- Small Paralyzer

	addSpecialSquad(4, { "5 chickens1" 																	}, 5) -- Spiker
	addSpecialSquad(4, { "10 chickenp1"																	}) -- Small Pyros
	addSpecialSquad(4, { "15 chicken_dodo1" 															}) -- Small Kamikaze
	addSpecialSquad(4, { "15 chickenc3"																	}, 3) -- AllTerrain Swarmer Small

	addSpecialSquad(5, { "3 chickene2" 																	}) -- EMP Brawler
	addSpecialSquad(5, { "10 chickenacidswarmer" 														}) -- Acid Swarmer
	addSpecialSquad(5, { "10 chicken1x_spectre" 														}) -- Spectre Swarmer
	addSpecialSquad(5, { "10 chickenc3b" 																}, 3) -- AllTerrain Swarmer Medium

	addSpecialSquad(6, { "10 chickenpyroallterrain" 													}) -- Pyro AllTerrain
	addSpecialSquad(6, { "10 chickenelectricallterrain" 												}) -- EMP AllTerrain
	addSpecialSquad(6, { "5 chickene1", "5 chickenacidswarmer" 											}) -- EMP and Acid Swarmer Combo
	addSpecialSquad(6, { "3 chickenr1" 																	}, 3) -- Artillery
	addSpecialSquad(6, { "5 chickenc3c" 																}, 3) -- AllTerrain Swarmer Big
	addSpecialSquad(6, { "6 chickenallterraina1" 														}, 2) -- AllTerrain Brawler
	addSpecialSquad(6, { "6 chickenallterraina1b" 														}, 2) -- AllTerrain Brawler
	addSpecialSquad(6, { "6 chickenallterraina1c" 														}, 2) -- AllTerrain Brawler
	addSpecialSquad(6, { "6 chickena1_spectre" 															}) -- Spectre Brawler
	addSpecialSquad(6, { "5 chickenelectricallterrain", "5 chickenacidallterrain" 						}) -- EMP and Acid AllTerrain Combo
	

	addSpecialSquad(7, { "3 chickenearty1" 																}) -- EMP Artillery
	addSpecialSquad(7, { "8 chickenp2" 																	}) -- Apex Pyro
	addSpecialSquad(7, { "3 chickene2" 																	}) -- EMP Brawler
	addSpecialSquad(7, { "3 chickenelectricallterrainassault" 											}) -- EMP AllTerrain Brawler
	addSpecialSquad(7, { "10 chickens2" 																}, 2) -- Apex Spiker
	

	addSpecialSquad(8, { "25 chicken_dodo2" 															}) -- Big Kamikaze
	addSpecialSquad(8, { "10 chickenacidallterrain" 													}) -- Acid AllTerrain 
	addSpecialSquad(8, { "4 chickenacidassault" 														}) -- Acid Brawler
	addSpecialSquad(8, { "3 chickene2" 																	}) -- EMP Brawler
	addSpecialSquad(8, { "4 chickenacidallterrainassault" 												}) -- Acid AllTerrain  Brawler
	addSpecialSquad(8, { "3 chickenacidarty" 															}) -- Acid Artillery
	addSpecialSquad(8, { "5 chickenh4" 																	}) -- Hatchling
	addSpecialSquad(8, { "5 chicken2_spectre" 															}) -- Hatchling
	addSpecialSquad(8, { "10 chickens2_spectre" 														}) -- Spectre Apex Spiker

	addSpecialSquad(9, { "2 chickenapexallterrainassault", "2 chickenapexallterrainassaultb"			}) -- Apex AllTerrain Brawler
	addSpecialSquad(9, { "4 chickena2_spectre"															}) -- Apex Spectre Brawler
	
	addSpecialSquad(9, { "3 chickenr1" 																	}, 3) -- Artillery
	if not Spring.GetModOptions().unit_restrictions_nonukes then
		addSpecialSquad(9, { "1 chickenr2"																}, 3) -- Meteor Artillery
	end
	addSpecialSquad(9, { "3 chickenh3" 																	}) -- Brood Mother
	addSpecialSquad(9, { "10 chickenh4" 																}) -- Hatchling

	addSpecialSquad(10, { "2 chickenapexallterrainassault", "2 chickenapexallterrainassaultb"			}) -- Apex AllTerrain Brawler
	addSpecialSquad(10, { "4 chickena2_spectre"															}) -- Apex Spectre Brawler
	addSpecialSquad(10, { "3 chickenr1" 																}, 3) -- Artillery
	if not Spring.GetModOptions().unit_restrictions_nonukes then
		addSpecialSquad(10, { "1 chickenr2"																}, 3) -- Meteor Artillery
	end
	addSpecialSquad(10, { "2 chickenh2" 																}) -- Apex Brood Mother
	addSpecialSquad(10, { "3 chickenh3" 																}) -- Brood Mother
	addSpecialSquad(10, { "10 chickenh4" 																}) -- Hatchling

if difficulty >= 3 then
	for i = 11,wavesAmount do
		for j = 1,#miniBosses do
			addSpecialSquad(i, { "1 " .. miniBosses[j] 													}, 10) -- Minibosses in regular endgame waves
		end
		addSpecialSquad(i, { "5 chickenapexallterrainassault", "5 chickenapexallterrainassaultb"		}) -- Apex AllTerrain Brawler
		addSpecialSquad(i, { "10 chickena2_spectre"														}) -- Apex Spectre Brawler
		addSpecialSquad(i, { "3 chickenr1", "3 chickenearty1", "3 chickenacidarty" 						}, 3) -- Artillery
		if not Spring.GetModOptions().unit_restrictions_nonukes then
			addSpecialSquad(i, { "1 chickenr2" 															}, 3) -- Meteor Artillery
		end
		addSpecialSquad(i, { "2 chickenh2" 																}) -- Apex Brood Mother
		addSpecialSquad(i, { "3 chickene2" 																}) -- EMP Brawler
		addSpecialSquad(i, { "3 chickenelectricallterrainassault" 										}) -- EMP AllTerrain Brawler
		addSpecialSquad(i, { "3 chickenacidassault" 													}) -- Acid Brawler
		addSpecialSquad(i, { "3 chickenacidallterrainassault" 											}) -- Acid AllTerrain  Brawler
		addSpecialSquad(i, { "25 chicken_dodo2" 														}) -- Kamikaze
		addSpecialSquad(i, { "10 chickenp2" 															}) -- Apex Pyro
		addSpecialSquad(i, { "10 chickens2" 															}, 2) -- Apex Spiker
		addSpecialSquad(i, { "10 chickens2_spectre" 													}) -- Spectre Apex Spiker
	end
end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Basic Squads -------------------------------------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

for i = 1,wavesAmount do
	if i <= 4 then -- Basic Swarmer
		addBasicSquad(1, { i*10 .. " chicken1_mini"}, 5)
		addBasicSquad(i, { i*2 .." chicken1", i*2 .." chicken1b", i*2 .." chicken1c" }, 2)
		addBasicSquad(i, { i*2 .." chicken1b", i*2 .." chicken1c", i*2 .." chicken1d" }, 2)
		addBasicSquad(i, { i*2 .." chicken1c", i*2 .." chicken1d", i*2 .." chicken1" }, 2)
		addBasicSquad(i, { i*2 .." chicken1d", i*2 .." chicken1", i*2 .." chicken1b" }, 2)
	end
	if i >= 3 and i <= 7 then -- Better Swarmer
		addBasicSquad(i, { i*2 .." chicken1x", i*2 .." chicken1y" }, 4)
		addBasicSquad(i, { i*2 .." chicken1y", i*2 .." chicken1z" }, 4)
		addBasicSquad(i, { i*2 .." chicken1z", i*2 .." chicken1x" }, 4)
	end
	if i >= 4 and i <= 6 then -- Brawlers
		addBasicSquad(i, { i ..  " chickena1" }, 5)
		addBasicSquad(i, { i ..  " chickena1b"}, 5)
		addBasicSquad(i, { i ..  " chickena1c"}, 5)
	end
	if i >= 7 then -- Apex Swarmer and  Apex Brawler
		addBasicSquad(i, { "2 chicken2" , "2 chicken2b" }, 5)
		addBasicSquad(i, { "1 chickena2", "1 chickena2b" }, 5)
	end
end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Air Squads ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

addAirSquad(5, { "2 chickenw1", "2 chickenw1b", "2 chickenw1c", "2 chickenw1d" 				}) -- Fighter
addAirSquad(5, { "4 chickenf1", "4 chickenf1b" 												}) -- Bomber

addAirSquad(7, { "2 chickenebomber1" 														}) -- EMP Bomber
addAirSquad(7, { "2 chickenacidbomber" 														}) -- Acid Bomber

addAirSquad(8, { "1 chicken_dodoair" 														}) -- Air Kamikaze

addAirSquad(9, { "2 chickenf1apex", "2 chickenf1apexb" 										}) -- Apex Bomber
addAirSquad(9, { "6 chickenw2" 																}) -- Apex Fighter

addAirSquad(10, { "4 chickenf1apex", "4 chickenf1apexb" 									}) -- Apex Bomber
addAirSquad(10, { "12 chickenw2" 															}) -- Apex Fighter

if difficulty >= 3 then
	for i = 11,wavesAmount do
		addAirSquad(i, { "6 chickenf1apex", "6 chickenf1apexb" 								}) -- Apex Bomber
		addAirSquad(i, { "18 chickenw2" 													}) -- Apex Fighter
		addAirSquad(i, { "1 chicken_dodoair" 												}) -- Air Kamikaze
	end
end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Settings -- Adjust these
local useEggs = true -- Drop eggs (requires egg features from Beyond All Reason)
local useScum = true -- Use scum as space where turrets can spawn (requires scum gadget from Beyond All Reason)
local useWaveMsg = false -- Show dropdown message whenever new wave is spawning
local spawnSquare = 90 -- size of the chicken spawn square centered on the burrow
local spawnSquareIncrement = 2 -- square size increase for each unit spawned
local minBaseDistance = 750 -- Minimum distance of new burrows from players and other burrows
local burrowTurretSpawnRadius = 32

local config = { -- Don't touch this! ---------------------------------------------------------------------------------------------------------------------------------------------
	useEggs 				= useEggs,
	useScum					= useScum,
	difficulty             	= difficulty,
	difficulties           	= difficulties,
	chickenEggs			   	= table.copy(chickenEggs),
	burrowName             	= burrowName,   -- burrow unit name
	burrowDef              	= UnitDefNames[burrowName].id,
	chickenSpawnMultiplier 	= Spring.GetModOptions().chicken_spawncountmult,
	gracePeriod            	= Spring.GetModOptions().chicken_graceperiod * 60,  -- no chicken spawn in this period, frames
	queenTime              	= Spring.GetModOptions().chicken_queentime * 60, -- time at which the queen appears, frames
	addQueenAnger          	= Spring.GetModOptions().chicken_queenanger,
	burrowSpawnType        	= Spring.GetModOptions().chicken_chickenstart,
	swarmMode			   	= Spring.GetModOptions().chicken_swarmmode,
	spawnSquare            	= spawnSquare,       
	spawnSquareIncrement   	= spawnSquareIncrement,         
	minBaseDistance        	= minBaseDistance,
	chickenTurrets			= table.copy(chickenTurrets),
	waves                  	= waves,
	wavesAmount            	= wavesAmount,
	basicWaves		   	   	= basicWaves,
	specialWaves           	= specialWaves,
	superWaves             	= superWaves,
	airWaves			   	= airWaves,
	miniBosses			   	= miniBosses,
	chickenMinions			= chickenMinions,
	chickenBehaviours 		= chickenBehaviours,
	difficultyParameters   	= optionValues,
	useWaveMsg 				= useWaveMsg,
	burrowTurretSpawnRadius = burrowTurretSpawnRadius,
}

for key, value in pairs(optionValues[difficulty]) do
	config[key] = value
end

return config