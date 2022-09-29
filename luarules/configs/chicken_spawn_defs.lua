
local difficulties = {
	veryeasy = 0,
	easy     = 1,
	normal   = 2,
	hard     = 3,
	veryhard = 4,
	epic     = 5,
	survival = 6,
}

local difficulty = difficulties[Spring.GetModOptions().chicken_difficulty]

local burrowName = 'chicken_hive'
local waves = {}
local basicWaves = {}
local specialWaves = {}
local superWaves = {}

local chickenTypes = {
	ve_chickenq    						=  true,
	e_chickenq     						=  true,
	n_chickenq     						=  true,
	h_chickenq     						=  true,
	vh_chickenq    						=  true,
	chicken1       						=  true,
	chicken1b      						=  true,
	chicken1c      						=  true,
	chicken1d      						=  true,
	chicken1x      						=  true,
	chicken1y      						=  true,
	chicken1z      						=  true,
	chicken2       						=  true,
	chicken2b      						=  true,
	chickena1      						=  true,
	chickena1b     						=  true,
	chickena1c     						=  true,
	chickenallterraina1					=  true,
	chickenallterraina1b				=  true,
	chickenallterraina1c				=  true,
	chickena2      						=  true,
	chickena2b     						=  true,
	chickenapexallterrainassault 		=  true,
	chickenapexallterrainassaultb 		=  true,
	chickens1      						=  true,
	chickens2      						=  true,
	chicken_dodo1  						=  true,
	chicken_dodo2  						=  true,
	chicken_dodoair						=  true,
	chickenf1      						=  true,
	chickenf1b     						=  true,
	chickenf1apex      					=  true,
	chickenf1apexb     					=  true,
	chickenf2      						=  true,
	chickenc2      						=  true,
	chickenc3      						=  true,
	chickenc3b     						=  true,
	chickenc3c     						=  true,
	chickenr1      						=  true,
	chickenr2      						=  true,
	chickenh1      						=  true,
	chickenh1b     						=  true,
	chickenh2      						=  true,
	chickenh3      						=  true,
	chickenh4      						=  true,
	chickenh5      						=  true,
	chickenw1      						=  true,
	chickenw1b     						=  true,
	chickenw1c     						=  true,
	chickenw1d     						=  true,
	chickenw2      						=  true,
	chickens3      						=  true,
	chickenp1      						=  true,
	chickenp2      						=  true,
	chickenpyroallterrain				=  true,
	chickene1	   						=  true,
	chickene2	   						=  true,
	chickenearty1  						=  true,
	chickenebomber1 					=  true,
	chickenelectricallterrain 			=  true,
	chickenelectricallterrainassault 	=  true,
	chickenacidswarmer 					=  true,
	chickenacidassault 					=  true,
	chickenacidarty 					=  true,
	chickenacidbomber 					=  true,
	chickenacidallterrain				=  true,
	chickenacidallterrainassault		=  true,

	chicken_miniqueen_electric			=  true,
  }

  local defenders = {
	chicken_turrets = true,
  }

  local chickenEggs = {
	chicken1       						=   "purple", 
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
	chickens2      						=   "yellow",
	chicken_dodo1  						=   "red",
	chicken_dodo2  						=   "red",
	chicken_dodoair  					=   "red",
	chickenf1      						=   "yellow",
	chickenf1b     						=   "yellow",
	chickenf1apex      					=   "yellow",
	chickenf1apexb     					=   "yellow",
	chickenf2      						=   "white",
	chickenc2      						=   "darkred",
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
	chickens3      						=   "green",
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

	chicken_miniqueen_electric			=   "blue",
  }

local optionValues = {
	[difficulties.veryeasy] = {
		chickenMaxSpawnRate  = 120,
		burrowSpawnRate   = 105,
		turretSpawnRate   = 210,
		queenSpawnMult    = 0,
		angerBonus        = 1,
		maxXP			  = 0.1,
		spawnChance       = 0.25,
		damageMod         = 0.1,
		maxBurrows        = 2,
		minChickens		  = 5,
		maxChickens		  = 75,
		queenName         = 've_chickenq',
		queenResistanceMult   = 0.25,
	},
	[difficulties.easy] = {
		chickenMaxSpawnRate  = 120,
		burrowSpawnRate   = 90,
		turretSpawnRate   = 180,
		queenSpawnMult    = 0,
		angerBonus        = 1,
		maxXP			  = 0.25,
		spawnChance       = 0.33,
		damageMod         = 0.2,
		maxBurrows        = 3,
		minChickens		  = 10,
		maxChickens		  = 100,
		queenName         = 'e_chickenq',
		queenResistanceMult   = 0.5,
	},

	[difficulties.normal] = {
		chickenMaxSpawnRate  = 120,
		burrowSpawnRate   = 75,
		turretSpawnRate   = 150,
		queenSpawnMult    = 1,
		angerBonus        = 1,
		maxXP			  = 0.5,
		spawnChance       = 0.4,
		damageMod         = 0.4,
		maxBurrows        = 4,
		minChickens		  = 15,
		maxChickens		  = 125,
		queenName         = 'n_chickenq',
		queenResistanceMult   = 1,
	},

	[difficulties.hard] = {
		chickenMaxSpawnRate  = 120,
		burrowSpawnRate   = 60,
		turretSpawnRate   = 120,
		queenSpawnMult    = 1,
		angerBonus        = 1,
		maxXP			  = 1,
		spawnChance       = 0.5,
		damageMod         = 0.6,
		maxBurrows        = 5,
		minChickens		  = 20,
		maxChickens		  = 150,
		queenName         = 'h_chickenq',
		queenResistanceMult   = 2,
	},

	[difficulties.veryhard] = {
		chickenMaxSpawnRate  = 120,
		burrowSpawnRate   = 45,
		turretSpawnRate   = 90,
		queenSpawnMult    = 3,
		angerBonus        = 1,
		maxXP			  = 1.5,
		spawnChance       = 0.6,
		damageMod         = 0.8,
		maxBurrows        = 6,
		minChickens		  = 25,
		maxChickens		  = 175,
		queenName         = 'vh_chickenq',
		queenResistanceMult   = 3,
	},
	[difficulties.epic] = {
		chickenMaxSpawnRate  = 120,
		burrowSpawnRate   = 30,
		turretSpawnRate   = 60,
		queenSpawnMult    = 3,
		angerBonus        = 1,
		maxXP			  = 2,
		spawnChance       = 0.8,
		damageMod         = 1,
		maxBurrows        = 10,
		minChickens		  = 30,
		maxChickens		  = 200,
		queenName         = 'epic_chickenq',
		queenResistanceMult   = 5,
	},

	[difficulties.survival] = {
		chickenMaxSpawnRate  = 120,
		burrowSpawnRate   = 150,
		turretSpawnRate   = 300,
		queenSpawnMult    = 0,
		angerBonus        = 1,
		maxXP			  = 0.2,
		spawnChance       = 0.25,
		damageMod         = 0.1,
		maxBurrows        = 2,
		minChickens		  = 1,
		maxChickens		  = 50,
		queenName         = 've_chickenq',
		queenResistanceMult   = 0.25,
	},
}


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local wavesAmount = 10
if difficulty >= 5 then
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

local function addSpecialSquad(wave, unitList, weight)
	if not weight then weight = 1 end
    for i = 1, weight do 
		for j = wave,wavesAmount do
			if not specialWaves[j] then
				specialWaves[j] = {}
			end
			table.insert(specialWaves[j], unitList)
		end
    end
end

local function addSuperSquad(wave, unitList, weight)
	if not weight then weight = 1 end
    for i = 1, weight do 
		for j = wave,wavesAmount do
			if not superWaves[j] then
				superWaves[j] = {}
			end
			table.insert(superWaves[j], unitList)
		end
    end
end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Super Squads -----------------------------------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	addSuperSquad(5, { "2 chickenf1apex"  																}) -- Apex Bomber
	addSuperSquad(5, { "2 chickenf1apexb" 																}) -- Apex Bomber
	addSuperSquad(5, { "5 chickenw2" 																	}) -- Apex Fighter
	addSuperSquad(5, { "5 chicken2"																		}) -- Apex Swarmer
	addSuperSquad(5, { "5 chicken2b" 																	}) -- Apex Swarmer
	addSuperSquad(5, { "2 chickena2" 																	}) -- Apex Brawler
	addSuperSquad(5, { "2 chickena2b"																	}) -- Apex Brawler
	addSuperSquad(5, { "2 chickenapexallterrainassault"													}) -- Apex AllTerrain Brawler
	addSuperSquad(5, { "2 chickenapexallterrainassaultb"												}) -- Apex AllTerrain Brawler
	addSuperSquad(3, { "6 chickenr1"																	}) -- Artillery
	addSuperSquad(4, { "3 chickenearty1"																}) -- Artillery
	addSuperSquad(5, { "3 chickenacidarty" 																}) -- Artillery
	addSuperSquad(5, { "2 chickenh2" 																	}) -- Apex Brood Mother
	addSuperSquad(3, { "3 chickene2" 																    }) -- EMP Brawler
	addSuperSquad(4, { "3 chickenelectricallterrainassault" 											}) -- EMP AllTerrain Brawler
	addSuperSquad(5, { "2 chickenacidassault" 															}) -- Acid Brawler
	addSuperSquad(5, { "2 chickenacidallterrainassault" 												}) -- Acid AllTerrain  Brawler
	addSuperSquad(5, { "5 chicken_dodo2" 																}) -- Kamikaze
	addSuperSquad(5, { "10 chicken_dodoair" 															}) -- Air Kamikaze
	addSuperSquad(4, { "6 chickenp2" 																	}) -- Apex Pyro
	addSuperSquad(5, { "5 chickens2" 																	}) -- Apex Spiker
	if not Spring.GetModOptions().unit_restrictions_nonukes then
		addSpecialSquad(7, { "2 chickenr2"																}, 2) -- Meteor Artillery
	end

	addSuperSquad(5, {"1 chicken_miniqueen_electric"													}) -- Electric Miniqueen
	addSuperSquad(5, {"1 chicken_miniqueen_acid"													}) -- Acid Miniqueen

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Special Squads -----------------------------------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	--addSpecialSquad(1,    { "1 chickenf2"									 	                     }) -- Observer

	addSpecialSquad(2, { "8 chickenp1" 																	}) -- Small Pyro

	addSpecialSquad(3, { "10 chickenp1"  												            	}) -- Small Pyro
	addSpecialSquad(3, { "8 chickene1"                                                                  }) -- Small Paralyzer

	addSpecialSquad(4, { "4 chickenp1" , "1 chickenp2"													}) -- Small Pyros with mom
	addSpecialSquad(4, { "15 chicken_dodo1" 															}) -- Small Kamikaze

	addSpecialSquad(5, { "3 chickene2" 																	}) -- EMP Brawler
	addSpecialSquad(5, { "10 chickenw1", "10 chickenw1b", "10 chickenw1c", "10 chickenw1d" 				}) -- Fighter
	addSpecialSquad(5, { "10 chickenf1", "10 chickenf1b" 												}) -- Bomber
	addSpecialSquad(5, { "10 chickenebomber1" 															}) -- EMP Bomber
	addSpecialSquad(5, { "10 chickenacidswarmer" 														}) -- Acid Swarmer

	addSpecialSquad(6, { "10 chickenpyroallterrain" 													}) -- Pyro AllTerrain
	addSpecialSquad(6, { "10 chickenelectricallterrain" 												}) -- EMP AllTerrain
	addSpecialSquad(6, { "5 chickene1", "5 chickenacidswarmer" 											}) -- EMP and Acid Swarmer Combo
	addSpecialSquad(6, { "3 chickenr1" 																	}) -- Artillery

	addSpecialSquad(7, { "3 chickenearty1" 																}) -- EMP Artillery
	addSpecialSquad(7, { "8 chickenp2" 																	}) -- Apex Pyro
	addSpecialSquad(7, { "3 chickene2" 																	}) -- EMP Brawler
	addSpecialSquad(7, { "3 chickenelectricallterrainassault" 											}) -- EMP AllTerrain Brawler
	addSpecialSquad(7, { "5 chickenelectricallterrain", "5 chickenacidallterrain" 						}) -- EMP and Acid AllTerrain Combo

	addSpecialSquad(8, { "25 chicken_dodo2" 															}) -- Big Kamikaze
	addSpecialSquad(8, { "35 chicken_dodoair" 															}) -- Air Kamikaze
	addSpecialSquad(8, { "10 chickens2" 																}) -- Apex Spiker
	addSpecialSquad(8, { "10 chickenacidallterrain" 													}) -- Acid AllTerrain 
	addSpecialSquad(8, { "4 chickenacidassault" 														}) -- Acid Brawler
	addSpecialSquad(8, { "3 chickene2" 																	}) -- EMP Brawler
	addSpecialSquad(8, { "4 chickenacidallterrainassault" 												}) -- Acid AllTerrain  Brawler
	addSpecialSquad(8, { "6 chickenacidbomber" 															}) -- Acid Bomber
	addSpecialSquad(8, { "3 chickenacidarty" 															}) -- Acid Artillery
	addSpecialSquad(8, { "5 chickenh4" 																	}) -- Hatchling

	addSpecialSquad(9, { "6 chickenf1apex", "6 chickenf1apexb" 											}) -- Apex Bomber
	addSpecialSquad(9, { "20 chickenw2" 																}) -- Apex Fighter
	addSpecialSquad(9, { "5 chicken2" , "5 chicken2b" 													}, 7) -- Apex Swarmer
	addSpecialSquad(9, { "3 chickena2", "3 chickena2b"													}, 2) -- Apex Brawler
	addSpecialSquad(9, { "2 chickenapexallterrainassault", "2 chickenapexallterrainassaultb"			}) -- Apex AllTerrain Brawler
	addSpecialSquad(9, { "3 chickenr1" 																	}) -- Artillery
	if not Spring.GetModOptions().unit_restrictions_nonukes then
		addSpecialSquad(9, { "2 chickenr2"																}) -- Meteor Artillery
	end
	addSpecialSquad(9, { "3 chickenh3" 																	}) -- Brood Mother
	addSpecialSquad(9, { "10 chickenh4" 																}) -- Hatchling

	addSpecialSquad(10, { "6 chickenf1apex", "6 chickenf1apexb" 										}) -- Apex Bomber
	addSpecialSquad(10, { "30 chickenw2" 																}) -- Apex Fighter
	addSpecialSquad(10, { "5 chicken2" , "5 chicken2b" 													}, 5) -- Apex Swarmer
	addSpecialSquad(10, { "3 chickena2", "3 chickena2b"													}, 2) -- Apex Brawler
	addSpecialSquad(10, { "2 chickenapexallterrainassault", "2 chickenapexallterrainassaultb"			}) -- Apex AllTerrain Brawler
	addSpecialSquad(10, { "3 chickenr1" 																}) -- Artillery
	if not Spring.GetModOptions().unit_restrictions_nonukes then
		addSpecialSquad(10, { "2 chickenr2"																}) -- Meteor Artillery
	end
	addSpecialSquad(10, { "2 chickenh2" 																}) -- Apex Brood Mother
	addSpecialSquad(10, { "3 chickenh3" 																}) -- Brood Mother
	addSpecialSquad(10, { "10 chickenh4" 																}) -- Hatchling

	
if difficulty >= 5 then
	for i = 11,12 do
	addSpecialSquad(i, { "3 chickenf1apex", "3 chickenf1apexb" 											}) -- Apex Bomber
	addSpecialSquad(i, { "10 chickenw2" 																}) -- Apex Fighter
	addSpecialSquad(i, { "5 chicken2" , "5 chicken2b" 													}) -- Apex Swarmer
	addSpecialSquad(i, { "5 chickena2", "5 chickena2b"													}) -- Apex Brawler
	addSpecialSquad(i, { "5 chickenapexallterrainassault", "5 chickenapexallterrainassaultb"			}) -- Apex AllTerrain Brawler
	addSpecialSquad(i, { "3 chickenr1", "3 chickenearty1", "3 chickenacidarty" 							}) -- Artillery
	if not Spring.GetModOptions().unit_restrictions_nonukes then
		addSpecialSquad(i, { "5 chickenr2" 																}) -- Meteor Artillery
	end
	addSpecialSquad(i, { "2 chickenh2" 																	}) -- Apex Brood Mother
	addSpecialSquad(i, { "3 chickene2" 																    }) -- EMP Brawler
	addSpecialSquad(i, { "3 chickenelectricallterrainassault" 											}) -- EMP AllTerrain Brawler
	addSpecialSquad(i, { "3 chickenacidassault" 														}) -- Acid Brawler
	addSpecialSquad(i, { "3 chickenacidallterrainassault" 												}) -- Acid AllTerrain  Brawler
	addSpecialSquad(i, { "25 chicken_dodo2" 															}) -- Kamikaze
	addSpecialSquad(i, { "75 chicken_dodoair" 															}) -- Air Kamikaze
	addSpecialSquad(i, { "10 chickenp2" 																}) -- Apex Pyro
	addSpecialSquad(i, { "10 chickens2" 																}) -- Apex Spiker
	end
end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Basic Squads
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

for i = 1,wavesAmount do
	if i >= 1 and i <= 4 then -- Basic Swarmer
		addBasicSquad(i, { i*2 .." chicken1", i*2 .." chicken1b", i*2 .." chicken1c" })
		addBasicSquad(i, { i*2 .." chicken1b", i*2 .." chicken1c", i*2 .." chicken1d" })  
		addBasicSquad(i, { i*2 .." chicken1c", i*2 .." chicken1d", i*2 .." chicken1" }) 
		addBasicSquad(i, { i*2 .." chicken1d", i*2 .." chicken1", i*2 .." chicken1b" })
	end
	if i >= 2 then
		addBasicSquad(i, { i*2 .." chicken1x", i*2 .." chicken1y" })
		addBasicSquad(i, { i*2 .." chicken1y", i*2 .." chicken1z" })
		addBasicSquad(i, { i*2 .." chicken1z", i*2 .." chicken1x" })
	end
	if i >= 2 and i <= 6 then -- Brawler and Spiker
		addBasicSquad(i, { i ..  " chickena1" })
		addBasicSquad(i, { i ..  " chickena1b"})
		addBasicSquad(i, { i ..  " chickena1c"})
		addBasicSquad(i, { i*4 .." chickens1" })
	end
	if i >= 6  then -- More AllTerrains over time
		addBasicSquad(i, { i*3 .." chickenc3" }, 2)
		addBasicSquad(i, { i*2 .." chickenc3b" }, 2)
		addBasicSquad(i, { i .." chickenc3c" }, 2)
		addBasicSquad(i, { i .." chickenallterraina1" })
		addBasicSquad(i, { i .." chickenallterraina1b" })
		addBasicSquad(i, { i .." chickenallterraina1c" })
	end
end



local config = {
	difficulty             = difficulty,
	difficulties           = difficulties,
	chickenSpawnMultiplier = Spring.GetModOptions().chicken_spawncountmult,
	gracePeriod            = Spring.GetModOptions().chicken_graceperiod * 60,  -- no chicken spawn in this period, seconds
	queenTime              = Spring.GetModOptions().chicken_queentime * 60, -- time at which the queen appears, seconds
	addQueenAnger          = Spring.GetModOptions().chicken_queenanger,
	burrowSpawnType        = Spring.GetModOptions().chicken_chickenstart,
	swarmMode			   = Spring.GetModOptions().chicken_swarmmode,
	spawnSquare            = 90,       -- size of the chicken spawn square centered on the burrow
	spawnSquareIncrement   = 2,         -- square size increase for each unit spawned
	burrowName             = burrowName,   -- burrow unit name
	burrowDef              = UnitDefNames[burrowName].id,
	minBaseDistance        = 500,
	chickenTypes           = table.copy(chickenTypes),
	chickenEggs			   = table.copy(chickenEggs),
	defenders              = table.copy(defenders),
	waves                  = waves,
	wavesAmount            = wavesAmount,
	basicWaves		   	   = basicWaves,
	specialWaves           = specialWaves,
	superWaves             = superWaves,
	difficultyParameters   = optionValues,
}

for key, value in pairs(optionValues[difficulty]) do
	config[key] = value
end

return config