
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

local burrowName = 'roost'
local waves = {}

local chickenTypes = {
	ve_chickenq    				=  true,
	e_chickenq     				=  true,
	n_chickenq     				=  true,
	h_chickenq     				=  true,
	vh_chickenq    				=  true,
	chicken1       				=  true,
	chicken1b      				=  true,
	chicken1c      				=  true,
	chicken1d      				=  true,
	chicken1x      				=  true,
	chicken1y      				=  true,
	chicken1z      				=  true,
	chicken2       				=  true,
	chicken2b      				=  true,
	chickena1      				=  true,
	chickena1b     				=  true,
	chickena1c     				=  true,
	chickena2      				=  true,
	chickena2b     				=  true,
	chickens1      				=  true,
	chickens2      				=  true,
	chicken_dodo1  				=  true,
	chicken_dodo2  				=  true,
	chicken_dodoair				=  true,
	chickenf1      				=  true,
	chickenf1b     				=  true,
	chickenf1apex      			=  true,
	chickenf1apexb     			=  true,
	chickenf2      				=  true,
	chickenc1      				=  true,
	chickenc2      				=  true,
	chickenc3      				=  true,
	chickenc3b     				=  true,
	chickenc3c     				=  true,
	chickenr1      				=  true,
	chickenr2      				=  true,
	chickenh1      				=  true,
	chickenh1b     				=  true,
	chickenh2      				=  true,
	chickenh3      				=  true,
	chickenh4      				=  true,
	chickenh5      				=  true,
	chickenw1      				=  true,
	chickenw1b     				=  true,
	chickenw1c     				=  true,
	chickenw1d     				=  true,
	chickenw2      				=  true,
	chickens3      				=  true,
	chickenp1      				=  true,
	chickenp2      				=  true,
	chickenpyroallterrain		=  true,
	chickene1	   				=  true,
	chickene2	   				=  true,
	chickenearty1  				=  true,
	chickenebomber1 			=  true,
	chickenelectricallterrain 	=  true,
	chickenacidswarmer 			=  true,
	chickenacidassault 			=  true,
	chickenacidarty 			=  true,
	chickenacidbomber 			=  true,
	chickenacidallterrain		=  true,
  }

  local defenders = {
	chickend1 = true,
  }

  local chickenEggs = {
	chicken1       				=   "purple", 
	chicken1b      				=   "pink",
	chicken1c      				=   "purple",
	chicken1d      				=   "purple",
	chicken1x      				=   "pink",
	chicken1y      				=   "pink",
	chicken1z      				=   "pink",
	chicken2       				=   "pink",
	chicken2b      				=   "pink",
	chickena1      				=   "red",
	chickena1b     				=   "red",
	chickena1c     				=   "red",
	chickena2      				=   "red",
	chickena2b     				=   "red",
	chickens1      				=   "green",
	chickens2      				=   "yellow",
	chicken_dodo1  				=   "red",
	chicken_dodo2  				=   "red",
	chicken_dodoair  			=   "red",
	chickenf1      				=   "yellow",
	chickenf1b     				=   "yellow",
	chickenf1apex      			=   "yellow",
	chickenf1apexb     			=   "yellow",
	chickenf2      				=   "white",
	chickenc1      				=   "white",
	chickenc2      				=   "darkred",
	chickenc3      				=   "white",
	chickenc3b     				=   "white",
	chickenc3c     				=   "white",
	chickenr1      				=   "darkgreen",
	chickenr2      				=   "darkgreen",
	chickenh1      				=   "white",
	chickenh1b     				=   "yellow",
	chickenh2      				=   "purple",
	chickenh3      				=   "red",
	chickenh4      				=   "red",
	chickenh5      				=   "red",
	chickenw1      				=   "purple",
	chickenw1b     				=   "purple",
	chickenw1c     				=   "purple",
	chickenw1d     				=   "purple",
	chickenw2      				=   "darkred",
	chickens3      				=   "green",
	chickenp1      				=   "darkred",
	chickenp2      				=   "darkred",
	chickenpyroallterrain		=	"darkred",
	chickene1	   				=   "blue",
	chickene2	   				=   "blue",
	chickenearty1  				=   "blue",
	chickenebomber1 			=   "blue",
	chickenelectricallterrain 	=   "blue",
	chickenacidswarmer 			=   "acidgreen",
	chickenacidassault 			=   "acidgreen",
	chickenacidarty 			=   "acidgreen",
	chickenacidbomber 			=   "acidgreen",
	chickenacidallterrain		=	"acidgreen",
  }

local optionValues = {
	[difficulties.veryeasy] = {
		chickenMaxSpawnRate  = 60,
		burrowSpawnRate   = 360,
		queenSpawnMult    = 0,
		angerBonus        = 0.5,
		expStep           = 0.05,
		spawnChance       = 0.25,
		damageMod         = 0.5,
		maxBurrows        = 5,
		queenName         = 've_chickenq',
	},
	[difficulties.easy] = {
		chickenMaxSpawnRate  = 60,
		burrowSpawnRate   = 320,
		queenSpawnMult    = 0,
		angerBonus        = 1,
		expStep           = 0.2,
		spawnChance       = 0.33,
		damageMod         = 0.6,
		maxBurrows        = 10,
		queenName         = 'e_chickenq',
	},

	[difficulties.normal] = {
		chickenMaxSpawnRate  = 60,
		burrowSpawnRate   = 210,
		queenSpawnMult    = 1,
		angerBonus        = 1,
		expStep           = 0.4,
		spawnChance       = 0.4,
		damageMod         = 0.7,
		maxBurrows        = 20,
		queenName         = 'n_chickenq',
	},

	[difficulties.hard] = {
		chickenMaxSpawnRate  = 60,
		burrowSpawnRate   = 140,
		queenSpawnMult    = 1,
		angerBonus        = 1,
		expStep           = 0.6,
		spawnChance       = 0.5,
		damageMod         = 0.8,
		maxBurrows        = 30,
		queenName         = 'h_chickenq',
	},

	[difficulties.veryhard] = {
		chickenMaxSpawnRate  = 60,
		burrowSpawnRate   = 70,
		queenSpawnMult    = 3,
		angerBonus        = 1,
		expStep           = 0.8,
		spawnChance       = 0.6,
		damageMod         = 0.9,
		maxBurrows        = 40,
		queenName         = 'vh_chickenq',
	},
	[difficulties.epic] = {
		chickenMaxSpawnRate  = 60,
		burrowSpawnRate   = 40,
		queenSpawnMult    = 3,
		angerBonus        = 1,
		expStep           = 1,
		spawnChance       = 0.8,
		damageMod         = 1,
		maxBurrows        = 50,
		queenName         = 'epic_chickenq',
	},

	[difficulties.survival] = {
		chickenMaxSpawnRate  = 60,
		burrowSpawnRate   = 360,
		queenSpawnMult    = 0,
		angerBonus        = 0.5,
		expStep           = 0.05,
		spawnChance       = 0.25,
		damageMod         = 0.1,
		maxBurrows        = 5,
		queenName         = 've_chickenq',
	},
}


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local function addSquad(wave, unitList)
	if not waves[wave] then
		waves[wave] = {}
	end

	table.insert(waves[wave], unitList)
end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Squads -------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	addSquad(1, { "5 chicken1", "5 chicken1b", "5 chicken1c", "5 chicken1d" 					}) -- Basic Raptor

	addSquad(2, { "4 chicken1x", "4 chicken1y", "4 chicken1z"  									}) -- Better Basic Raptor
	addSquad(2, { "2 chickena1", "2 chickena1b", "2 chickena1c"									}) -- Brawler

if difficulty >= 1 then
	addSquad(3, { "12 chickens1" 																}) -- Spiker
	addSquad(3, { "8 chickene1" 																}) -- EMP Swarmer

	addSquad(4, { "10 chickenp1" 																}) -- Small Pyro
	addSquad(4, { "4 chickenp1" , "1 chickenp2"													}) -- Small Pyros with mom
end

if difficulty >= 2 then
	addSquad(5, { "5 chickenw1", "5 chickenw1b", "5 chickenw1c", "5 chickenw1d" 				}) -- Fighter
	addSquad(5, { "5 chickenf1", "5 chickenf1b" 												}) -- Bomber
	addSquad(5, { "5 chickenebomber1" 															}) -- EMP Bomber
	addSquad(5, { "10 chickenacidswarmer" 														}) -- Acid Swarmer

	addSquad(6, { "15 chickenc3" 																}) -- Swarmer AllTerrain
	addSquad(6, { "10 chickenc3b" 																}) -- Swarmer AllTerrain
	addSquad(6, { "5 chickenc3c" 																}) -- Swarmer AllTerrain
	addSquad(6, { "10 chickenc3", "5 chickenc3b"  												}) -- Swarmer AllTerrain
	addSquad(6, { "5 chickenc3b", "3 chickenc3c" 												}) -- Swarmer AllTerrain
	addSquad(6, { "10 chickenc3", "5 chickenc3b", "3 chickenc3c" 								}) -- Swarmer AllTerrain
	addSquad(6, { "10 chickenpyroallterrain" 													}) -- Pyro AllTerrain
	addSquad(6, { "10 chickenelectricallterrain" 												}) -- EMP AllTerrain
	addSquad(6, { "5 chickene1", "5 chickenacidswarmer" 										}) -- EMP and Acid Swarmer Combo
	addSquad(6, { "3 chickenr1" 																}) -- Artillery
end

if difficulty >= 3 then
	addSquad(7, { "3 chickenearty1" 															}) -- EMP Artillery
	addSquad(7, { "8 chickenp2" 																}) -- Apex Pyro
	addSquad(7, { "3 chickene2" 																}) -- EMP Brawler
	addSquad(7, { "5 chickenelectricallterrain", "5 chickenacidallterrain" 						}) -- EMP and Acid AllTerrain Combo

	addSquad(8, { "70 chicken_dodo1" 															}) -- Kamikaze
	addSquad(8, { "35 chicken_dodo2" 															}) -- Kamikaze
	addSquad(8, { "35 chicken_dodoair" 															}) -- Kamikaze
	addSquad(8, { "10 chickens2" 																}) -- Apex Spiker
	addSquad(8, { "10 chickenacidallterrain" 													}) -- Acid AllTerrain 
	addSquad(8, { "4 chickenacidassault" 														}) -- Acid Brawler
	addSquad(8, { "5 chickenacidbomber" 														}) -- Acid Bomber
	addSquad(8, { "3 chickenacidarty" 															}) -- Acid Artillery
end

if difficulty >= 4 then
	addSquad(9, { "3 chickenf1apex", "3 chickenf1apexb" 										}) -- Apex Bomber
	addSquad(9, { "10 chickenw2" 																}) -- Apex Fighter
	addSquad(9, { "5 chicken2" , "5 chicken2b" 													}) -- Apex Swarmer
	addSquad(9, { "5 chickena2", "5 chickena2b"													}) -- Apex Brawler
	addSquad(9, { "1 chickenr2", "3 chickenr1" 													}) -- Meteor Artillery

	addSquad(10, { "3 chickenf1apex", "3 chickenf1apexb" 										}) -- Apex Bomber
	addSquad(10, { "20 chickenw2" 																}) -- Apex Fighter
	addSquad(10, { "5 chicken2" , "5 chicken2b" 												}) -- Apex Swarmer
	addSquad(10, { "5 chickena2", "5 chickena2b"												}) -- Apex Brawler
	addSquad(10, { "1 chickenr2", "3 chickenr1" 												}) -- Meteor Artillery
	addSquad(10, { "5 chickenh2" 																}) -- Apex Brood Mother
	addSquad(10, { "10 chickenh3" 																}) -- Brood Mother
	addSquad(10, { "20 chickenh4" 																}) -- Hatchling
end

if difficulty >= 5 then
	addSquad(11, { "3 chickenf1apex", "3 chickenf1apexb" 										}) -- Apex Bomber
	addSquad(11, { "10 chickenw2" 																}) -- Apex Fighter
	addSquad(11, { "5 chicken2" , "5 chicken2b" 												}) -- Apex Swarmer
	addSquad(11, { "5 chickena2", "5 chickena2b"												}) -- Apex Brawler
	addSquad(11, { "1 chickenr2", "3 chickenr1", "3 chickenearty1", "3 chickenacidarty" 		}) -- Meteor Artillery
	addSquad(11, { "5 chickenh2" 																}) -- Apex Brood Mother
	addSquad(11, { "10 chickene2" 																}) -- EMP Brawler
	addSquad(11, { "10 chickenacidassault" 														}) -- Acid Brawler
	addSquad(11, { "100 chicken_dodo2" 															}) -- Kamikaze
	addSquad(11, { "100 chicken_dodoair" 														}) -- Air Kamikaze
	addSquad(11, { "20 chickenp2" 																}) -- Apex Pyro
	addSquad(11, { "20 chickens2" 																}) -- Apex Spiker

	addSquad(12, { "3 chickenf1apex", "3 chickenf1apexb" 										}) -- Apex Bomber
	addSquad(12, { "10 chickenw2" 																}) -- Apex Fighter
	addSquad(12, { "5 chicken2" , "5 chicken2b" 												}) -- Apex Swarmer
	addSquad(12, { "5 chickena2", "5 chickena2b"												}) -- Apex Brawler
	addSquad(12, { "1 chickenr2", "3 chickenr1", "3 chickenearty1", "3 chickenacidarty" 		}) -- Meteor Artillery
	addSquad(12, { "5 chickenh2" 																}) -- Apex Brood Mother
	addSquad(12, { "10 chickene2" 																}) -- EMP Brawler
	addSquad(12, { "10 chickenacidassault" 														}) -- Acid Brawler
	addSquad(12, { "100 chicken_dodo2" 															}) -- Kamikaze
	addSquad(12, { "100 chicken_dodoair" 														}) -- Air Kamikaze
	addSquad(12, { "20 chickenp2" 																}) -- Apex Pyro
	addSquad(12, { "20 chickens2" 																}) -- Apex Spiker
end

--[[
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Squads -------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Tier1
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
addSquad(1, { "5 chicken1", "5 chicken1b", "5 chicken1c", "5 chicken1d" 					}) -- Basic Raptor
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Tier2
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
addSquad(2, { "4 chicken1x", "4 chicken1y", "4 chicken1z"  									}) -- Better Basic Raptor

addSquad(2, { "2 chickena1", "2 chickena1b", "2 chickena1c"									}) -- Brawler
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Tier3
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
addSquad(3, { "12 chickens1" 																}) -- Spiker

addSquad(3, { "8 chickene1" 																}) -- EMP Swarmer
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Tier4
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
addSquad(4, { "10 chickenp1" 																}) -- Small Pyro

addSquad(4, { "4 chickenp1" , "1 chickenp2"													}) -- Small Pyros with mom
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Tier5
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
addSquad(5, { "5 chickenw1", "5 chickenw1b", "5 chickenw1c", "5 chickenw1d" 			}) -- Fighter

addSquad(5, { "5 chickenf1", "5 chickenf1b" 												}) -- Bomber

addSquad(5, { "5 chickenebomber1" 															}) -- EMP Bomber

addSquad(5, { "10 chickenacidswarmer" 														}) -- Acid Swarmer
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Tier6
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
addSquad(6, { "15 chickenc3" 																}) -- Swarmer AllTerrain
addSquad(6, { "10 chickenc3b" 																}) -- Swarmer AllTerrain
addSquad(6, { "5 chickenc3c" 																}) -- Swarmer AllTerrain
addSquad(6, { "10 chickenc3", "5 chickenc3b"  												}) -- Swarmer AllTerrain
addSquad(6, { "5 chickenc3b", "3 chickenc3c" 												}) -- Swarmer AllTerrain
addSquad(6, { "10 chickenc3", "5 chickenc3b", "3 chickenc3c" 								}) -- Swarmer AllTerrain

addSquad(6, { "10 chickenpyroallterrain" 													}) -- Pyro AllTerrain

addSquad(6, { "10 chickenelectricallterrain" 												}) -- EMP AllTerrain

addSquad(6, { "5 chickene1", "5 chickenacidswarmer" 										}) -- EMP and Acid Swarmer Combo

addSquad(6, { "3 chickenr1" 																}) -- Artillery
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Tier7
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
addSquad(7, { "3 chickenearty1" 															}) -- EMP Artillery

addSquad(7, { "8 chickenp2" 																}) -- Apex Pyro

addSquad(7, { "3 chickene2" 																}) -- EMP Brawler

addSquad(7, { "5 chickenelectricallterrain", "5 chickenacidallterrain" 						}) -- EMP and Acid AllTerrain Combo
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Tier8
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
addSquad(8, { "70 chicken_dodo1" 															}) -- Kamikaze
addSquad(8, { "35 chicken_dodo2" 															}) -- Kamikaze
addSquad(8, { "35 chicken_dodoair" 															}) -- Kamikaze

addSquad(8, { "3 chickenf1apex", "3 chickenf1apexb" 										}) -- Bomber

addSquad(8, { "10 chickens2" 																}) -- Apex Spiker

addSquad(8, { "10 chickenacidallterrain" 													}) -- Acid AllTerrain 

addSquad(8, { "4 chickenacidassault" 														}) -- Acid Brawler

addSquad(8, { "10 chickenacidbomber" 														}) -- Acid Bomber

addSquad(8, { "3 chickenacidarty" 															}) -- Acid Artillery
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Tier9
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
addSquad(9, { "5 chicken2" , "5 chicken2b" 													}) -- Apex Swarmer

addSquad(9, { "5 chickena2", "5 chickena2b"													}) -- Apex Brawler

addSquad(9, { "1 chickenr2", "3 chickenr1" 													}) -- Meteor Artillery

addSquad(9, { "10 chickenw2" 																}) -- Apex Fighter
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Tier10
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
addSquad(10, { "5 chicken2" , "5 chicken2b" 												}) -- Apex Swarmer

addSquad(10, { "5 chickena2", "5 chickena2b"												}) -- Apex Brawler

addSquad(10, { "1 chickenr2", "3 chickenr1" 												}) -- Meteor Artillery

addSquad(10, { "20 chickenw2" 																}) -- Apex Fighter

addSquad(10, { "5 chickenh2" 																}) -- Apex Brood Mother
addSquad(10, { "10 chickenh3" 																}) -- Brood Mother
addSquad(10, { "20 chickenh4" 																}) -- Hatchling

]]

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Filling junk
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
for i = 1,#waves do
	if i >= 2 and i <= 4 then -- Basic Swarmer
		addSquad(i, { i*2 .." chicken1", i*2 .." chicken1b", i*2 .." chicken1c" })
		addSquad(i, { i*2 .." chicken1b", i*2 .." chicken1c", i*2 .." chicken1d" })  
		addSquad(i, { i*2 .." chicken1c", i*2 .." chicken1d", i*2 .." chicken1" }) 
		addSquad(i, { i*2 .." chicken1d", i*2 .." chicken1", i*2 .." chicken1b" })
	end
	if i >= 3 and i <= 6 then -- Better Swarmer, Brawler and Spiker
		addSquad(i, { i*2 .." chicken1x", i*2 .." chicken1y" })
		addSquad(i, { i*2 .." chicken1y", i*2 .." chicken1z" })  
		addSquad(i, { i*2 .." chicken1z", i*2 .." chicken1x" }) 
		addSquad(i, { i ..  " chickena1" })
		addSquad(i, { i ..  " chickena1b"})
		addSquad(i, { i ..  " chickena1c"})
		addSquad(i, { i*4 .." chickens1" })
	end
	if i >= 7 and i <= 10 then -- More AllTerrains over time
		addSquad(i, { i*3 .." chickenc3" })
		addSquad(i, { i*3 .." chickenc3" })
		addSquad(i, { i*2 .." chickenc3b" })
		addSquad(i, { i*2 .." chickenc3b" })
		addSquad(i, { i .." chickenc3c" })
		addSquad(i, { i .." chickenc3c" })
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Additional system for keeping minimum number of specific raptors.
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


local config = {
	difficulty             = difficulty,
	difficulties           = difficulties,
	maxChicken             = Spring.GetModOptions().chicken_maxchicken,
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
	difficultyParameters   = optionValues,
}

for key, value in pairs(optionValues[difficulty]) do
	config[key] = value
end

return config