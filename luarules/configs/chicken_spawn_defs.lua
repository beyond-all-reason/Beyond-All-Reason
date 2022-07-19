
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
	chickenh1b     						=   "yellow",
	chickenh2      						=   "purple",
	chickenh3      						=   "red",
	chickenh4      						=   "red",
	chickenh5      						=   "red",
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
  }

local optionValues = {
	[difficulties.veryeasy] = {
		chickenMaxSpawnRate  = 60,
		burrowSpawnRate   = 120,
		turretSpawnRate	  = 360,
		queenSpawnMult    = 0,
		angerBonus        = 0.25,
		maxXP			  = 0.2,
		spawnChance       = 0.25,
		damageMod         = 0.1,
		maxBurrows        = 2,
		minChickens		  = 10,
		maxChickens		  = 15,
		queenName         = 've_chickenq',
	},
	[difficulties.easy] = {
		chickenMaxSpawnRate  = 60,
		burrowSpawnRate   = 105,
		turretSpawnRate	  = 320,
		queenSpawnMult    = 0,
		angerBonus        = 0.5,
		maxXP			  = 0.4,
		spawnChance       = 0.33,
		damageMod         = 0.2,
		maxBurrows        = 3,
		minChickens		  = 15,
		maxChickens		  = 30,
		queenName         = 'e_chickenq',
	},

	[difficulties.normal] = {
		chickenMaxSpawnRate  = 60,
		burrowSpawnRate   = 70,
		turretSpawnRate	  = 210,
		queenSpawnMult    = 1,
		angerBonus        = 0.75,
		maxXP			  = 0.8,
		spawnChance       = 0.4,
		damageMod         = 0.4,
		maxBurrows        = 4,
		minChickens		  = 20,
		maxChickens		  = 60,
		queenName         = 'n_chickenq',
	},

	[difficulties.hard] = {
		chickenMaxSpawnRate  = 60,
		burrowSpawnRate   = 45,
		turretSpawnRate	  = 140,
		queenSpawnMult    = 1,
		angerBonus        = 1,
		maxXP			  = 1.2,
		spawnChance       = 0.5,
		damageMod         = 0.6,
		maxBurrows        = 5,
		minChickens		  = 25,
		maxChickens		  = 90,
		queenName         = 'h_chickenq',
	},

	[difficulties.veryhard] = {
		chickenMaxSpawnRate  = 60,
		burrowSpawnRate   = 25,
		turretSpawnRate	  = 70,
		queenSpawnMult    = 3,
		angerBonus        = 1,
		maxXP			  = 1.6,
		spawnChance       = 0.6,
		damageMod         = 0.8,
		maxBurrows        = 6,
		minChickens		  = 30,
		maxChickens		  = 120,
		queenName         = 'vh_chickenq',
	},
	[difficulties.epic] = {
		chickenMaxSpawnRate  = 60,
		burrowSpawnRate   = 10,
		turretSpawnRate	  = 40,
		queenSpawnMult    = 3,
		angerBonus        = 1,
		maxXP			  = 2,
		spawnChance       = 0.8,
		damageMod         = 1,
		maxBurrows        = 10,
		minChickens		  = 35,
		maxChickens		  = 150,
		queenName         = 'epic_chickenq',
	},

	[difficulties.survival] = {
		chickenMaxSpawnRate  = 60,
		burrowSpawnRate   = 120,
		turretSpawnRate	  = 360,
		queenSpawnMult    = 0,
		angerBonus        = 0.25,
		maxXP			  = 0.2,
		spawnChance       = 0.25,
		damageMod         = 0.1,
		maxBurrows        = 2,
		minChickens		  = 1,
		maxChickens		  = 5,
		queenName         = 've_chickenq',
	},
}


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local function addSquad(wave, unitList, weight)
	if not waves[wave] then
		waves[wave] = {}
	end
	if not weight then weight = 1 end
    for i = 1, weight do 
	table.insert(waves[wave], unitList)
    end
end

local accumulativeSquads = true -- dev switch

if accumulativeSquads == true then
	-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Squads -------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

		addSquad(1, { "1 chicken1", "1 chicken1b", "1 chicken1c", "1 chicken1d" 					}) -- Basic Raptor
		addSquad(1, { "2 chicken1"																	}) -- Basic Raptor
		addSquad(1, { "2 chicken1b"																	}) -- Basic Raptor
		addSquad(1, { "2 chicken1c"																	}) -- Basic Raptor
		addSquad(1, { "2 chicken1d"																	}) -- Basic Raptor

		addSquad(2, { "4 chicken1x", "4 chicken1y", "4 chicken1z"  									}) -- Better Basic Raptor
		addSquad(2, { "10 chickens1" 																}) -- Spiker

		addSquad(3, { "2 chickena1", "2 chickena1b", "2 chickena1c"									}) -- Brawler
		addSquad(3, { "8 chickene1" 																}) -- EMP Swarmer

		addSquad(4, { "10 chickenp1" 																}) -- Small Pyro
		addSquad(4, { "4 chickenp1" , "1 chickenp2"													}) -- Small Pyros with mom

		addSquad(5, { "4 chicken1x", "4 chicken1y", "4 chicken1z"  									}) -- Better Basic Raptor
		addSquad(5, { "3 chickene2" 																}) -- EMP Brawler
		addSquad(5, { "5 chickenw1", "5 chickenw1b", "5 chickenw1c", "5 chickenw1d" 				}) -- Fighter
		addSquad(5, { "5 chickenf1", "5 chickenf1b" 												}) -- Bomber
		addSquad(5, { "5 chickenebomber1" 															}) -- EMP Bomber
		addSquad(5, { "10 chickenacidswarmer" 														}) -- Acid Swarmer

		addSquad(6, { "15 chickenc3" 																}) -- Swarmer AllTerrain
		addSquad(6, { "10 chickenc3b" 																}) -- Swarmer AllTerrain
		addSquad(6, { "5 chickenc3c" 																}) -- Swarmer AllTerrain
		addSquad(6, { "2 chickenallterraina1", "2 chickenallterraina1b", "2 chickenallterraina1c"	}) -- Brawler AllTerrain
		addSquad(6, { "10 chickenpyroallterrain" 													}) -- Pyro AllTerrain
		addSquad(6, { "10 chickenelectricallterrain" 												}) -- EMP AllTerrain
		addSquad(6, { "5 chickene1", "5 chickenacidswarmer" 										}) -- EMP and Acid Swarmer Combo
		addSquad(6, { "3 chickenr1" 																}) -- Artillery

		addSquad(7, { "3 chickenearty1" 															}) -- EMP Artillery
		addSquad(7, { "8 chickenp2" 																}) -- Apex Pyro
		addSquad(7, { "3 chickene2" 																}) -- EMP Brawler
		addSquad(7, { "3 chickenelectricallterrainassault" 											}) -- EMP AllTerrain Brawler
		addSquad(7, { "5 chickenelectricallterrain", "5 chickenacidallterrain" 						}) -- EMP and Acid AllTerrain Combo

		addSquad(8, { "70 chicken_dodo1" 															}) -- Kamikaze
		addSquad(8, { "35 chicken_dodo2" 															}) -- Kamikaze
		addSquad(8, { "35 chicken_dodoair" 															}) -- Kamikaze
		addSquad(8, { "10 chickens2" 																}) -- Apex Spiker
		addSquad(8, { "10 chickenacidallterrain" 													}) -- Acid AllTerrain 
		addSquad(8, { "4 chickenacidassault" 														}) -- Acid Brawler
		addSquad(8, { "3 chickene2" 																}) -- EMP Brawler
		addSquad(8, { "4 chickenacidallterrainassault" 												}) -- Acid AllTerrain  Brawler
		addSquad(8, { "5 chickenacidbomber" 														}) -- Acid Bomber
		addSquad(8, { "3 chickenacidarty" 															}) -- Acid Artillery

		addSquad(9, { "3 chickenf1apex", "3 chickenf1apexb" 										}) -- Apex Bomber
		addSquad(9, { "10 chickenw2" 																}) -- Apex Fighter
		addSquad(9, { "5 chicken2" , "5 chicken2b" 													}) -- Apex Swarmer
		addSquad(9, { "5 chickena2", "5 chickena2b"													}) -- Apex Brawler
		addSquad(9, { "5 chickenapexallterrainassault", "5 chickenapexallterrainassaultb"			}) -- Apex AllTerrain Brawler
		addSquad(9, { "1 chickenr2", "3 chickenr1" 													}) -- Meteor Artillery

		addSquad(10, { "3 chickenf1apex", "3 chickenf1apexb" 										}) -- Apex Bomber
		addSquad(10, { "20 chickenw2" 																}) -- Apex Fighter
		addSquad(10, { "5 chicken2" , "5 chicken2b" 												}) -- Apex Swarmer
		addSquad(10, { "5 chickena2", "5 chickena2b"												}) -- Apex Brawler
		addSquad(10, { "5 chickenapexallterrainassault", "5 chickenapexallterrainassaultb"			}) -- Apex AllTerrain Brawler
		addSquad(10, { "1 chickenr2", "3 chickenr1" 												}) -- Meteor Artillery
		addSquad(10, { "5 chickenh2" 																}) -- Apex Brood Mother
		addSquad(10, { "10 chickenh3" 																}) -- Brood Mother
		addSquad(10, { "20 chickenh4" 																}) -- Hatchling

		
	if difficulty >= 5 then
		for i = 11,12 do
		addSquad(i, { "3 chickenf1apex", "3 chickenf1apexb" 										}) -- Apex Bomber
		addSquad(i, { "10 chickenw2" 																}) -- Apex Fighter
		addSquad(i, { "5 chicken2" , "5 chicken2b" 													}) -- Apex Swarmer
		addSquad(i, { "5 chickena2", "5 chickena2b"													}) -- Apex Brawler
		addSquad(i, { "5 chickenapexallterrainassault", "5 chickenapexallterrainassaultb"			}) -- Apex AllTerrain Brawler
		addSquad(i, { "1 chickenr2", "3 chickenr1", "3 chickenearty1", "3 chickenacidarty" 			}) -- Meteor Artillery
		addSquad(i, { "5 chickenh2" 																}) -- Apex Brood Mother
		addSquad(i, { "10 chickene2" 																}) -- EMP Brawler
		addSquad(i, { "10 chickenelectricallterrainassault" 										}) -- EMP AllTerrain Brawler
		addSquad(i, { "10 chickenacidassault" 														}) -- Acid Brawler
		addSquad(i, { "10 chickenacidallterrainassault" 											}) -- Acid AllTerrain  Brawler
		addSquad(i, { "100 chicken_dodo2" 															}) -- Kamikaze
		addSquad(i, { "100 chicken_dodoair" 														}) -- Air Kamikaze
		addSquad(i, { "20 chickenp2" 																}) -- Apex Pyro
		addSquad(i, { "20 chickens2" 																}) -- Apex Spiker
		end
	end

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
			addSquad(i, { i*2 .." chickenc3b" })
			addSquad(i, { i .." chickenc3c" })
			addSquad(i, { i .." chickenallterraina1" })
			addSquad(i, { i .." chickenallterraina1b" })
			addSquad(i, { i .." chickenallterraina1c" })
		end
	end
else

	addSquad(1, { "1 chicken1", "1 chicken1b", "1 chicken1c", "1 chicken1d" }) -- Basic Raptor
	addSquad(1, { "4 chicken1"												}) -- Basic Raptor
	addSquad(1, { "4 chicken1b"												}) -- Basic Raptor
	addSquad(1, { "4 chicken1c"												}) -- Basic Raptor
	addSquad(1, { "4 chicken1d"												}) -- Basic Raptor

	addSquad(1, { "1 chicken1x"												}) -- Better Basic Raptor
	addSquad(1, { "1 chicken1y"												}) -- Better Basic Raptor
	addSquad(1, { "1 chicken1z"												}) -- Better Basic Raptor

	addSquad(1, { "1 chickens1" 											}) -- Spiker

	--------------------------------------------------------------------------------------------------------------

	addSquad(2, { "6 chicken1", "6 chicken1b", "6 chicken1c", "6 chicken1d" }) -- Basic Raptor

	addSquad(2, { "3 chicken1x", "3 chicken1y", "3 chicken1z"  				}) -- Better Basic Raptor

	addSquad(2, { "3 chickens1" 											}) -- Spiker

	--------------------------------------------------------------------------------------------------------------

	addSquad(3, { "6 chicken1", "6 chicken1b", "6 chicken1c", "6 chicken1d" }) -- Basic Raptor
	addSquad(3, { "6 chicken1", "6 chicken1b", "6 chicken1c", "6 chicken1d" }) -- Basic Raptor

	addSquad(3, { "3 chicken1x", "3 chicken1y", "3 chicken1z"  				}) -- Better Basic Raptor
	addSquad(3, { "3 chicken1x", "3 chicken1y", "3 chicken1z"  				}) -- Better Basic Raptor
	addSquad(3, { "3 chicken1x", "3 chicken1y", "3 chicken1z"  				}) -- Better Basic Raptor

	addSquad(3, { "10 chickens1" 											}) -- Spiker
	addSquad(3, { "5 chickens1" 											}) -- Spiker

	addSquad(3, { "2 chickena1"												}) -- Brawler
	addSquad(3, { "2 chickena1b"											}) -- Brawler
	addSquad(3, { "2 chickena1c"											}) -- Brawler
	
	--------------------------------------------------------------------------------------------------------------
	
	
	
	------ placeholder
	for i = 4,10 do
		addSquad(i, { "20 chicken1"											}) -- Basic Raptor
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
	difficultyParameters   = optionValues,
	accumulativeSquads	   = accumulativeSquads,
}

for key, value in pairs(optionValues[difficulty]) do
	config[key] = value
end

return config