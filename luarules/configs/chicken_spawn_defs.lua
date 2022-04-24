
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
local newWaveSquad = {}

local chickenTypes = {
	ve_chickenq    =  true,
	e_chickenq     =  true,
	n_chickenq     =  true,
	h_chickenq     =  true,
	vh_chickenq    =  true,
	chicken1       =  true,
	chicken1b      =  true,
	chicken1c      =  true,
	chicken1d      =  true,
	chicken1x      =  true,
	chicken1y      =  true,
	chicken1z      =  true,
	chicken2       =  true,
	chicken2b      =  true,
	chickena1      =  true,
	chickena1b     =  true,
	chickena1c     =  true,
	chickena2      =  true,
	chickena2b     =  true,
	chickens1      =  true,
	chickens2      =  true,
	chicken_dodo1  =  true,
	chicken_dodo2  =  true,
	chickenf1      =  true,
	chickenf1b     =  true,
	chickenf2      =  true,
	chickenc1      =  true,
	chickenc2      =  true,
	chickenc3      =  true,
	chickenc3b     =  true,
	chickenc3c     =  true,
	chickenr1      =  true,
	chickenr2      =  true,
	chickenh1      =  true,
	chickenh1b     =  true,
	chickenh2      =  true,
	chickenh3      =  true,
	chickenh4      =  true,
	chickenh5      =  true,
	chickenw1      =  true,
	chickenw1b     =  true,
	chickenw1c     =  true,
	chickenw1d     =  true,
	chickenw2      =  true,
	chickens3      =  true,
	chickenp1      =  true,
	chickenp2      =  true,
	chickene1	   =  true,
	chickene2	   =  true,
	chickenearty1  =  true,
	chickenebomber1 = true,
  }

  local defenders = {
	chickend1 = true,
  }

local optionValues = {
	[difficulties.veryeasy] = {
	  chickenSpawnRate  = 400,
	  burrowSpawnRate   = 360,
	  queenSpawnMult    = 0,
	  angerBonus        = 0.05,
	  expStep           = 0,
	  lobberEMPTime     = 0,
	  chickensPerPlayer = 7,
	  spawnChance       = 0.25,
	  damageMod         = 0.125,
	  maxBurrows        = 2,
	  queenName         = 've_chickenq',
  },
  [difficulties.easy] = {
	  chickenSpawnRate  = 400,
	  burrowSpawnRate   = 320,
	  queenSpawnMult    = 0,
	  angerBonus        = 0.075,
	  expStep           = 0.09375,
	  lobberEMPTime     = 2.5,
	  chickensPerPlayer = 7,
	  spawnChance       = 0.33,
	  damageMod         = 0.25,
	  maxBurrows        = 3,
	  queenName         = 'e_chickenq',
  },

  [difficulties.normal] = {
	  chickenSpawnRate  = 400,
	  burrowSpawnRate   = 210,
	  queenSpawnMult    = 1,
	  angerBonus        = 0.10,
	  expStep           = 0.125,
	  lobberEMPTime     = 4,
	  chickensPerPlayer = 9,
	  spawnChance       = 0.4,
	  damageMod         = 0.4,
	  maxBurrows        = 10,
	  queenName         = 'n_chickenq',
  },

  [difficulties.hard] = {
	  chickenSpawnRate  = 400,
	  burrowSpawnRate   = 140,
	  queenSpawnMult    = 1,
	  angerBonus        = 0.125,
	  expStep           = 0.25,
	  lobberEMPTime     = 5,
	  chickensPerPlayer = 14,
	  spawnChance       = 0.5,
	  damageMod         = 0.55,
	  maxBurrows        = 20,
	  queenName         = 'h_chickenq',
  },

  [difficulties.veryhard] = {
	  chickenSpawnRate  = 400,
	  burrowSpawnRate   = 70,
	  queenSpawnMult    = 3,
	  angerBonus        = 0.15,
	  expStep           = 0.4,
	  lobberEMPTime     = 7.5,
	  chickensPerPlayer = 18,
	  spawnChance       = 0.6,
	  damageMod         = 0.66,
	  maxBurrows        = 50,
	  queenName         = 'vh_chickenq',
  },
  [difficulties.epic] = {
	chickenSpawnRate  = 400,
	burrowSpawnRate   = 40,
	queenSpawnMult    = 3,
	angerBonus        = 0.2,
	expStep           = 0.5,
	lobberEMPTime     = 7.5,
	chickensPerPlayer = 20,
	spawnChance       = 1,
	damageMod         = 0.8,
	maxBurrows        = 50,
	queenName         = 'epic_chickenq',
	},

	[difficulties.survival] = {
	  chickenSpawnRate    = 360,
	  burrowSpawnRate     = 210,
	  queenSpawnMult      = 1,
	  angerBonus          = 0.1,
	  expStep             = 0.125,
	  lobberEMPTime       = 4,
	  chickenTypes        = table.copy(chickenTypes),
	  defenders           = table.copy(defenders),
	  chickensPerPlayer   = 9,
	  spawnChance         = 0.4,
	  damageMod           = 0.5,
	  maxBurrows          = 10,
	  queenName           = 'n_chickenq',
	},
  }

local maxAges = {
	chicken1      = 240,
	chicken1b     = 240,
	chicken1c     = 240,
	chicken_dodo1 = 120,
	chicken_dodo2 = 120,
	chickena2     = 500,
	chickena2b    = 500,
	chickenh4     = 120,
	chickenh1     = 240,
	chickenh1b    = 200,
}

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local function addWave(wave, unitList)
	if not waves[wave] then
		waves[wave] = {}
	end

	table.insert(waves[wave], unitList)
end

addWave(1, { "3 chicken1", "1 chickenf2" })
addWave(1, { "3 chicken1c", "1 chickenf2" })
addWave(1, { "1 chicken1", "1 chicken1b", "1 chicken1c", "1 chickenh1" })
addWave(1, { "1 chicken1", "1 chicken1b", "1 chicken1c", "1 chicken1d" })
addWave(1, { "3 chicken1d", "1 chickenh1" })
addWave(1, { "1 chicken1", "1 chicken1b", "1 chicken1c", "1 chicken1d" })
addWave(1, { "2 chicken1b", "1 chickenh1b" })
addWave(1, { "2 chicken1c", "1 chickena1" })

newWaveSquad[2] = {"7 chicken1", "6 chicken1b", "5 chicken1c", "4 chicken1d"}
addWave(2, { "5 chicken1", "4 chicken1b", "3 chicken1c", "2 chicken1d" })
addWave(2, { "2 chicken1", "3 chicken1b", "4 chicken1c", "5 chicken1d" })
addWave(2, { "3 chicken1", "3 chicken1b", "3 chicken1c", "3 chicken1d" })
addWave(2, { "1 chicken1x", "1 chicken1y", "1 chicken1z" })
addWave(2, { "5 chicken1b", "1 chickenf2" })
addWave(2, { "6 chicken1c", "1 chickenf2" })
addWave(2, { "3 chicken1", "1 chickena1b", "1 chickenh1" })
addWave(2, { "1 chickena1", "1 chickena1c", "1 chickenw1b" })
addWave(2, { "1 chickena1b", "1 chickena1c", "1 chickenw1", "1 chickens1" })
addWave(2, { "4 chicken1d", "1 chickens1" })
addWave(2, { "4 chicken1", "1 chickena1" })
addWave(2, { "3 chicken1", "1 chickenh1", "1 chickenh1b" })

newWaveSquad[3] = {"7 chicken1", "8 chicken1b", "9 chicken1c", "10 chicken1d"}
addWave(3, { "1 chickena1", "2 chickena1b", "1 chickena1c", "2 chickenh1" })
addWave(3, { "1 chickena1", "1 chickena1b", "2 chickena1c" })
addWave(3, { "1 chickena1", "1 chickena1b", "1 chickena1c", "1 chickenc3" })
addWave(3, { "1 chickenc3", "1 chickenc3b", "1 chickenc3c", "2 chicken1" })
addWave(3, { "1 chickena1", "1 chickena1b", "1 chickens1", "1 chicken1x", "1 chicken1y", "1 chicken1z" })
addWave(3, { "1 chickena1b", "1 chickena1c", "1 chickenh1", "1 chickenh1b", "3 chicken1b" })
addWave(3, { "1 chickena1", "1 chickena1b", "1 chickenf2", "3 chicken1c" })
addWave(3, { "1 chickena1", "1 chickena1c", "1 chickens1", "3 chicken1d" })
addWave(3, { "3 chicken1y", "2 chickena1", "1 chickenh1", "1 chickenw1", "1 chickens1" })
addWave(3, { "2 chickena1b", "1 chickenw1d", "1 chickens1" })
addWave(3, { "2 chickenp1" })

newWaveSquad[4] = {"1 chickenh5", "9 chickenh1", "9 chickenh1b", "1 chickene2"}
addWave(4, { "1 chickena1", "1 chickena1b", "1 chickena1c", "1 chickenh1", "1 chickenh1b" })
addWave(4, { "4 chicken1x", "3 chicken1y", "2 chicken1z", "1 chickenh1" })
addWave(4, { "2 chicken1x", "3 chicken1y", "4 chicken1z", "1 chickenh1" })
addWave(4, { "3 chickenc3", "1 chickena1" })
addWave(4, { "3 chickenc3b", "1 chickens3" })
addWave(4, { "3 chickenc3c", "1 chickens1" })
addWave(4, { "3 chickenw1", "1 chicken_dodo1" })
addWave(4, { "3 chickens1", "1 chickenf2" })
addWave(4, { "2 chickenp1", "3 chickene1" })
addWave(4, { "5 chickene1" })

newWaveSquad[5] = {"1 chickenh5", "11 chickens1", "2 chickenw2", "1 chickene2"}
addWave(5, { "6 chicken1x", "2 chickens1", "1 chicken_dodo1" })
addWave(5, { "6 chickens1", "1 chickenw1" })
addWave(5, { "5 chickens1", "1 chickena1b" })
addWave(5, { "4 chickens1", "1 chickena1", "1 chickenf2" })
addWave(5, { "3 chickens1", "1 chickena1c", "2 chickenc3" })
addWave(5, { "3 chickens1", "1 chickenh1", "1 chickenh1b" })
addWave(5, { "1 chickena1", "1 chickena1b", "1 chickena1c", "1 chickenw1b" })
addWave(5, { "5 chicken1y", "1 chicken_dodo1", "3 chickenh1" })
addWave(5, { "6 chicken1z", "1 chickenw1c", "1 chickenw1d" })
addWave(5, { "3 chickens1", "1 chickenp1" })
addWave(5, { "1 chickenp1", "1 chicken_dodo1", "3 chickenh1b" })
addWave(5, { "1 chickenc3", "2 chickenc3b", "2 chickenc3b" })
addWave(5, { "3 chickens3", "1 chickenf2" })
addWave(5, { "3 chickene1", "1 chickene2"})
addWave(5, { "5 chickene1", "1 chickene2"})

newWaveSquad[6] = {"1 chickenh5", "1 chicken_dodo2", "7 chickenp1", "1 chickene2"}
addWave(6, { "1 chicken_dodo1", "3 chickenp1", "1 chickenf2" })
addWave(6, { "1 chicken_dodo1", "3 chickenc3", "3 chickenc3b", "3 chickenc3c" })
addWave(6, { "1 chicken_dodo1", "4 chickenp1", "1 chickens3" })
addWave(6, { "1 chicken_dodo1", "4 chickenp1" })
addWave(6, { "1 chicken_dodo1", "2 chickenp1", "1 chickenh1", "1 chickenh1b" })
addWave(6, { "1 chicken_dodo1", "2 chickenp1", "1 chickenw1b", "1 chickenf2", "1 chickenw1" })
addWave(6, { "2 chicken_dodo1", "1 chickenp1", "2 chickenc1" })
addWave(6, { "2 chicken_dodo1", "1 chickena1", "1 chickena1b", "3 chickena1c", "1 chickenw1b" })
addWave(6, { "2 chicken_dodo1", "5 chickens1", "1 chickenw2", "1 chickens3" })
addWave(6, { "2 chicken_dodo1", "3 chicken1x", "1 chickenf1", "3 chicken2" })
addWave(6, { "2 chicken_dodo1", "1 chickenp1", "1 chickenc1", "1 chickens1", "1 chickena1b", "1 chickenh1" })
addWave(6, { "3 chicken_dodo1", "5 chickenh1", "1 chickens3" })
addWave(6, { "4 chicken_dodo1", "1 chickenf1", "1 chickenw2" })

newWaveSquad[7] = {"1 chickenh5", "12 chickenw2", "1 chickenf1", "1 chickenf1b", "1 chickene2"}
addWave(7, { "2 chickenw2", "1 chickenw1b", "1 chickenw1c", "1 chickens3" })
addWave(7, { "1 chickenw1", "2 chickenw2", "1 chickenw1d", "1 chicken_dodo1" })
addWave(7, { "1 chickenw1", "2 chickenw2", "1 chickenw1d", "1 chickens3" })
addWave(7, { "1 chickenw1b", "1 chickenw1c", "2 chickenw2" })
addWave(7, { "2 chickenw1", "3 chickenw1b", "1 chicken_dodo1" })
addWave(7, { "2 chickenw1c", "2 chickenw1d" })
addWave(7, { "1 chickenf1b", "2 chickens3" })
addWave(7, { "2 chickenf1", "1 chickens3", "1 chicken_dodo1" })
addWave(7, { "2 chickenf1", "1 chicken_dodo1", "1 chickens3" })
addWave(7, { "2 chickenf1", "1 chicken_dodo1", "1 chickenf1b" })
addWave(7, { "5 chickens3", "1 chickenf2" })
addWave(7, { "5 chickenw2", "1 chickenf2" })
addWave(7, { "5 chickenp2", "1 chickenr1" })
addWave(7, { "1 chickenearty1", "2 chickenebomber1" })

newWaveSquad[8] = {"1 chickenh5", "6 chickenc1", "2 chickenh2", "1 chickene2"}
addWave(8, { "2 chickenc1", "1 chickenw2", "1 chickenw1b", "1 chickenw1c", "1 chickenw1d" })
addWave(8, { "2 chickenc1", "3 chicken_dodo1", "1 chickenr1" })
addWave(8, { "2 chickenc1", "2 chickenf1", "1 chickenw2", "1 chickenw1d" })
addWave(8, { "2 chickenc1", "1 chickenf1b", "2 chickenw2", "2 chickenw1b" })
addWave(8, { "3 chickenc1", "4 chickenh1", "1 chickenf2" })
addWave(8, { "3 chickenc1", "1 chickena1", "2 chickena1b", "1 chickena1c", "1 chicken_dodo1" })
addWave(8, { "3 chickenc1", "4 chicken_dodo1" })
addWave(8, { "3 chickenc1", "1 chickens1", "1 chickens2","2 chickenp1", "2 chickenh1b" })
addWave(8, { "4 chickenc1", "1 chickenf1b", "1 chicken_dodo1" })
addWave(8, { "4 chickenc1", "3 chicken_dodo1", "1 chickenh2" })
addWave(8, { "2 chickena1", "1 chickena1b", "1 chickena1c", "1 chickena2", "1 chickenf2", "1 chickenr1"})
addWave(8, { "6 chickens1", "1 chickens2" })
addWave(8, { "5 chickenp1", "2 chickenh1", "2 chickenh1b" })
addWave(8, { "4 chickenc3", "4 chickenc3b", "4 chickenc3c" })
addWave(8, { "9 chicken2", "1 chicken_dodo2" })
addWave(8, { "1 chickene2",  "5 chickenp2"  })
addWave(8, { "1 chickene2", "1 chickenearty1", "2 chickenebomber1" })

newWaveSquad[9] = {"1 chickenh5", "5 chickens2", "10 chicken2", "1 chickene2"}
addWave(9, { "3 chickenf1", "1 chicken_dodo1", "1 chickena2", "1 chickenh1", "1 chickenw1b", "1 chicken2" })
addWave(9, { "2 chickenf1b", "2 chicken_dodo1", "1 chickenh1b", "1 chicken2", "1 chickenr1" })
addWave(9, { "1 chickenf1", "1 chickenf1b", "3 chicken_dodo1", "1 chickena2b", "1 chickenh1", "1 chickenh2" })
addWave(9, { "3 chickenc1", "1 chickenh1b", "1 chicken2", "1 chickenr1"})
addWave(9, { "3 chickenc1", "1 chicken_dodo2", "1 chickens2", "1 chickenh1", "1 chickenw1d", "1 chicken2" })
addWave(9, { "3 chickenc1", "1 chickenh1b", "1 chicken2", "1 chickenr1" })
addWave(9, { "1 chickenw1", "2 chickenw1b", "2 chickenw2", "1 chickenw1d", "2 chicken_dodo1", "1 chickens2", "1 chickenh1", "1 chicken2" })
addWave(9, { "6 chickenp1", "4 chickenh1b", "1 chicken2", "1 chickenr1" })
addWave(9, { "2 chickena1", "2 chickena1b", "2 chickena1c", "4 chickenh1", "1 chickenh1", "1 chickenw1", "1 chicken2" })
addWave(9, { "1 chickens2", "4 chickenh1b", "1 chicken2", "1 chickenr1" })
addWave(9, { "6 chicken2", "3 chickenh1", "1 chickenw2", "1 chickenf2" })
addWave(9, { "5 chickenp2", "1 chickenearty1", "2 chickenebomber1" })

newWaveSquad[10] = {"1 chickenh5", "13 chicken2b", "1 chickenh2", "1 chickena2", "1 chickena2b", "1 chickene2"}
addWave(10, { "7 chicken2b", "1 chickens2", "2 chickenh1" })
addWave(10, { "5 chicken2b", "1 chickena2", "1 chickenh1" })
addWave(10, { "4 chicken2", "1 chickens2", "2 chickenh1b" })
addWave(10, { "3 chicken2", "1 chickena2b", "1 chickenh1b" })
addWave(10, { "3 chicken2b", "1 chickenh2", "2 chickenh1" })
addWave(10, { "4 chicken2b", "1 chickenh1" })
addWave(10, { "7 chicken2", "1 chickenh2", "2 chickenh1b" })
addWave(10, { "6 chicken2", "1 chicken_dodo2", "1 chickenr1"})
addWave(10, { "1 chickenc2", "4 chickenc1", "1 chickenf1" })
addWave(10, { "4 chickens3", "4 chickenw2", "1 chickenf1b" })
addWave(10, { "6 chickenp1", "2 chickenh1b", "2 chickenh1" })
addWave(10, { "5 chickenp2", "1 chickenearty1"})
addWave(10, { "1 chickenr2", "2 chickenebomber1" })

newWaveSquad[11] = {"4 chickenh2", "4 chickenh1", "4 chickenh1b"}
addWave(11, { "3 chickenh1","2 chickenh1b","1 chickenh2","2 chickenh3", "1 chickenc2", "1 chickenw2" })
addWave(11, { "2 chickenh1","3 chickenh1b","1 chickenh2","2 chickenh3", "1 chickenc2", "1 chickenw2" })
addWave(11, { "2 chickenh1","2 chickenh1b","1 chickenh2","2 chickenh3", "1 chickenc2", "1 chickenw2" })
addWave(11, { "2 chickenh1","2 chickenh1b","1 chickenh2","2 chickenh3", "1 chickens2" })
addWave(11, { "2 chickenh1","2 chickenh1b","1 chickenh2","2 chickenh3", "1 chickens2" })
addWave(11, { "2 chickenh1","2 chickenh1b","1 chickenh2","2 chickenh3", "1 chickens2" })
addWave(11, { "3 chickenc2", "1 chickenf2" })
addWave(11, { "3 chickenw1","3 chickenw1b", "3 chickenw1c", "3 chickenw1d" })
addWave(11, { "3 chickens2", "1 chickenf2" })
addWave(11, { "1 chickena2", "2 chickenw2" })
addWave(11, { "7 chickenw2", "1 chickenf2" })

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local config = {
	difficulty             = difficulty,
	difficulties           = difficulties,
	maxChicken             = Spring.GetModOptions().chicken_maxchicken,
	chickenSpawnMultiplier = Spring.GetModOptions().chicken_spawncountmult,
	gracePeriod            = Spring.GetModOptions().chicken_graceperiod,  -- no chicken spawn in this period, seconds
	queenTime              = Spring.GetModOptions().chicken_queentime * 60, -- time at which the queen appears, seconds
	addQueenAnger          = Spring.GetModOptions().chicken_queenanger,
	burrowSpawnType        = Spring.GetModOptions().chicken_chickenstart,
	spawnSquare            = 90,       -- size of the chicken spawn square centered on the burrow
	spawnSquareIncrement   = 2,         -- square size increase for each unit spawned
	burrowName             = burrowName,   -- burrow unit name
	burrowDef              = UnitDefNames[burrowName].id,
	maxAge                 = 600,      -- default chicken die at this age, seconds
	maxAges                = maxAges,
	defenderChance         = 0.375,      -- probability of spawning a single turret
	maxTurrets             = 3,   		 -- Max Turrets per burrow
	minBaseDistance        = 500,
	maxBaseDistance        = 5000,
	bonusTurret            = "chickend1", -- Turret that gets spawned when a burrow dies
	chickenTypes           = table.copy(chickenTypes),
	defenders              = table.copy(defenders),
	waves                  = waves,
	newWaveSquad           = newWaveSquad,
}

for key, value in pairs(optionValues[difficulty]) do
	config[key] = value
end

return config