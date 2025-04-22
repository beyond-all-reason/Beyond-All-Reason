
local difficulties = {
	veryeasy = 1,
	easy 	 = 2,
	normal   = 3,
	hard     = 4,
	veryhard = 5,
	epic     = 6,
	--survival = 6,
}

local difficulty = difficulties[Spring.GetModOptions().raptor_difficulty]
local economyScale = 1 * Spring.GetModOptions().multiplier_resourceincome *
(0.67+(Spring.GetModOptions().multiplier_metalextraction*0.33)) *
(0.67+(Spring.GetModOptions().multiplier_energyconversion*0.33)) *
(0.67+(Spring.GetModOptions().multiplier_energyproduction*0.33)) *
(((((Spring.GetModOptions().startmetal - 1000) / 9000) + 1)*0.1)+0.9) *
(((((Spring.GetModOptions().startenergy - 1000) / 9000) + 1)*0.1)+0.9)

economyScale = math.min(5, (economyScale*0.33)+0.67)

local burrowName = 'raptor_hive'

local raptorTurrets = {}

-- If you use fractions in spawnerPerWave, it becomes a percentage chance to spawn one.

raptorTurrets["raptor_turret_basic_t2_v1"] 				= { minQueenAnger = 0, 	spawnedPerWave = 0.5, 	maxExisting = 20,	maxQueenAnger = 1000,}
raptorTurrets["raptor_turret_acid_t2_v1"] 			= { minQueenAnger = 15, spawnedPerWave = 0.25, 	maxExisting = 10,	maxQueenAnger = 1000,}
raptorTurrets["raptor_turret_emp_t2_v1"] 		= { minQueenAnger = 15, spawnedPerWave = 0.25, 	maxExisting = 10,	maxQueenAnger = 1000,}
raptorTurrets["raptor_turret_basic_t3_v1"] 				= { minQueenAnger = 30, spawnedPerWave = 0.5, 	maxExisting = 6,	maxQueenAnger = 1000,}
raptorTurrets["raptor_turret_acid_t3_v1"] 			= { minQueenAnger = 45, spawnedPerWave = 0.25, 	maxExisting = 3,	maxQueenAnger = 1000,}
raptorTurrets["raptor_turret_emp_t3_v1"] 		= { minQueenAnger = 45, spawnedPerWave = 0.25, 	maxExisting = 3,	maxQueenAnger = 1000,}

if not Spring.GetModOptions().unit_restrictions_nonukes then

	raptorTurrets["raptor_turret_antinuke_t2_v1"] 	= { minQueenAnger = 15, spawnedPerWave = 0.25, 	maxExisting = 10,	maxQueenAnger = 1000,}
	raptorTurrets["raptor_turret_antinuke_t3_v1"] 	= { minQueenAnger = 45, spawnedPerWave = 0.25, 	maxExisting = 3,	maxQueenAnger = 1000,}
	raptorTurrets["raptor_turret_meteor_t4_v1"]		= { minQueenAnger = 75, spawnedPerWave = 0.5, 	maxExisting = 6,	maxQueenAnger = 1000,}

end
if not Spring.GetModOptions().unit_restrictions_noair then

	raptorTurrets["raptor_turret_antiair_t2_v1"] 	= { minQueenAnger = 0, 	spawnedPerWave = 0.5, 	maxExisting = 20,	maxQueenAnger = 1000,}
	raptorTurrets["raptor_turret_antiair_t3_v1"] 	= { minQueenAnger = 30, spawnedPerWave = 0.5, 	maxExisting = 6,	maxQueenAnger = 1000,}
	raptorTurrets["raptor_turret_antiair_t4_v1"]	= { minQueenAnger = 60, spawnedPerWave = 0.25, 	maxExisting = 2,	maxQueenAnger = 1000,}

end
if not Spring.GetModOptions().unit_restrictions_nolrpc then

	raptorTurrets["raptor_turret_basic_t4_v1"]			= { minQueenAnger = 60, spawnedPerWave = 0.25, 	maxExisting = 2,	maxQueenAnger = 1000,}
	raptorTurrets["raptor_turret_emp_t4_v1"]	= { minQueenAnger = 75, spawnedPerWave = 0.25, 	maxExisting = 1,	maxQueenAnger = 1000,}
	raptorTurrets["raptor_turret_acid_t4_v1"]		= { minQueenAnger = 75, spawnedPerWave = 0.25, 	maxExisting = 1,	maxQueenAnger = 1000,}
end

local raptorEggs = { -- Specify eggs dropped by unit here, requires useEggs to be true, if some unit is not specified here, it drops random egg colors.
	raptor_land_swarmer_basic_t2_v1       						=   "purple",
	raptor_land_swarmer_basic_t1_v1						=   "purple",
	raptor_land_swarmer_basic_t2_v2      						=   "pink",
	raptor_land_swarmer_basic_t2_v3      						=   "purple",
	raptor_land_swarmer_basic_t2_v4      						=   "purple",
	raptor_land_swarmer_basic_t3_v1      						=   "pink",
	raptor_land_swarmer_basic_t3_v2      						=   "pink",
	raptor_land_swarmer_basic_t3_v3      						=   "pink",
	raptor_land_swarmer_basic_t4_v1       						=   "pink",
	raptor_land_swarmer_basic_t4_v2      						=   "pink",
	raptor_land_assault_basic_t2_v1      						=   "red",
	raptor_land_assault_basic_t2_v2     						=   "red",
	raptor_land_assault_basic_t2_v3     						=   "red",
	raptor_allterrain_assault_basic_t2_v1					=   "red",
	raptor_allterrain_assault_basic_t2_v2					=   "red",
	raptor_allterrain_assault_basic_t2_v3					=   "red",
	raptor_land_assault_basic_t4_v1      						=   "red",
	raptor_land_assault_basic_t4_v2     						=   "red",
	raptor_allterrain_assault_basic_t4_v1 		=   "red",
	raptor_allterrain_assault_basic_t4_v2 		=   "red",
	raptor_land_spiker_basic_t2_v1      						=   "green",
	raptor_land_spiker_basic_t4_v1      						=   "darkgreen",
	raptor_land_kamikaze_basic_t2_v1  						=   "red",
	raptor_land_kamikaze_basic_t4_v1  						=   "red",
	raptor_air_kamikaze_basic_t2_v1  					=   "red",
	raptor_air_bomber_basic_t1_v1      					=   "darkgreen",
	raptor_air_bomber_basic_t2_v1      						=   "darkgreen",
	raptor_air_bomber_basic_t2_v2     						=   "darkgreen",
	raptor_air_bomber_basic_t4_v1      					=   "darkgreen",
	raptor_air_bomber_basic_t4_v2     					=   "darkgreen",
	raptor_air_scout_basic_t2_v1      				=   "white",
	raptor_air_scout_basic_t3_v1      				=   "white",
	raptor_air_scout_basic_t4_v1      				=   "white",
	raptor_allterrain_swarmer_basic_t2_v1      						=   "white",
	raptor_allterrain_swarmer_basic_t3_v1     						=   "white",
	raptor_allterrain_swarmer_basic_t4_v1     						=   "white",
	raptor_allterrain_arty_basic_t2_v1      						=   "darkgreen",
	raptor_allterrain_arty_basic_t4_v1      						=   "darkgreen",
	raptor_land_swarmer_heal_t1_v1      					=   "white",
	raptor_land_swarmer_heal_t2_v1      					=   "white",
	raptor_land_swarmer_heal_t3_v1      					=   "white",
	raptor_land_swarmer_heal_t4_v1      					=   "white",
	raptorh1b     						=   "white",
	raptor_land_swarmer_brood_t4_v1      						=   "purple",
	raptor_land_swarmer_brood_t3_v1      						=   "purple",
	raptor_land_swarmer_brood_t2_v1      						=   "purple",
	raptor_air_bomber_brood_t4_v2 				= 	"purple",
	raptor_air_bomber_brood_t4_v3 				= 	"purple",
	raptor_air_bomber_brood_t4_v4 				= 	"purple",
	raptor_allterrain_arty_brood_t4_v1 					= 	"purple",
	raptor_allterrain_arty_brood_t2_v1 				= 	"purple",
	raptorh5      						=   "white",
	raptor_air_fighter_basic_t2_v1      						=   "purple",
	raptor_air_fighter_basic_t1_v1      					=   "purple",
	raptor_air_fighter_basic_t2_v2     						=   "purple",
	raptor_air_fighter_basic_t2_v3     						=   "purple",
	raptor_air_fighter_basic_t2_v4     						=   "purple",
	raptor_air_fighter_basic_t4_v1      						=   "darkred",
	raptor_land_swarmer_fire_t2_v1      						=   "darkred",
	raptor_land_swarmer_fire_t4_v1      						=   "darkred",
	raptor_allterrain_swarmer_fire_t2_v1				=	"darkred",
	raptor_land_swarmer_emp_t2_v1	   						=   "blue",
	raptor_land_assault_emp_t2_v1	   						=   "blue",
	raptor_allterrain_arty_emp_t2_v1  						=   "blue",
	raptor_allterrain_arty_emp_t4_v1  						=   "blue",
	raptor_air_bomber_emp_t2_v1 						=   "blue",
	raptor_allterrain_swarmer_emp_t2_v1 			=   "blue",
	raptor_allterrain_assault_emp_t2_v1		=   "blue",
	raptor_land_kamikaze_emp_t2_v1  				=   "blue",
	raptor_land_kamikaze_emp_t4_v1  				=   "blue",
	raptor_land_swarmer_acids_t2_v1 					=   "acidgreen",
	raptor_land_assault_acid_t2_v1 					=   "acidgreen",
	raptor_allterrain_arty_acid_t2_v1 						=   "acidgreen",
	raptor_allterrain_arty_acid_t4_v1 					=   "acidgreen",
	raptor_air_bomber_acid_t2_v1 					=   "acidgreen",
	raptor_allterrain_swarmer_acid_t2_v1				=	"acidgreen",
	raptor_allterrain_assault_acid_t2_v1			=   "acidgreen",
	raptor_land_swarmer_spectre_t3_v1					=   "yellow",
	raptor_land_swarmer_spectre_t4_v1						=   "yellow",
	raptor_land_assault_spectre_t2_v1					=   "yellow",
	raptor_land_assault_spectre_t4_v1					=   "yellow",
	raptor_land_spiker_spectre_t4_v1					=   "yellow",

	raptor_turret_basic_t2_v1						=	"white",
	raptor_turret_basic_t3_v1						=	"white",
	raptor_turret_basic_t4_v1						=	"white",
	raptor_turret_emp_t2_v1				=   "blue",
	raptor_turret_emp_t3_v1				=   "blue",
	raptor_turret_emp_t4_v1			=   "blue",
	raptor_turret_acid_t2_v1					=   "acidgreen",
	raptor_turret_acid_t3_v1					=   "acidgreen",
	raptor_turret_acid_t4_v1				=   "acidgreen",
	raptor_turret_antinuke_t2_v1				= 	"white",
	raptor_turret_antinuke_t3_v1				= 	"white",
	raptor_turret_antiair_t2_v1				=	"red",
	raptor_turret_antiair_t3_v1				=	"red",
	raptor_turret_antiair_t4_v1				=	"red",
	raptor_turret_meteor_t4_v1				=	"darkgreen",

	raptor_matriarch_electric			=   "blue",
	raptor_matriarch_acid				=   "acidgreen",
	raptor_matriarch_healer				=  	"white",
	raptor_matriarch_basic 				=  	"pink",
	raptor_matriarch_fire 				=  	"darkred",
	raptor_matriarch_spectre 			=  	"yellow",
}

raptorBehaviours = {
	SKIRMISH = { -- Run away from target after target gets hit
		[UnitDefNames["raptor_land_spiker_basic_t2_v1"].id] = { distance = 270, chance = 0.5 },
		[UnitDefNames["raptor_land_spiker_basic_t4_v1"].id] = { distance = 250, chance = 0.5 },
		[UnitDefNames["raptor_allterrain_arty_basic_t2_v1"].id] = { distance = 500, chance = 0.1 },
		[UnitDefNames["raptor_allterrain_arty_basic_t4_v1"].id] = { distance = 500, chance = 0.01 },
		[UnitDefNames["raptor_land_swarmer_emp_t2_v1"].id] = { distance = 300, chance = 1 },
		[UnitDefNames["raptor_land_assault_emp_t2_v1"].id] = { distance = 200, chance = 0.01 },
		[UnitDefNames["raptor_allterrain_assault_emp_t2_v1"].id] = { distance = 200, chance = 0.01 },
		[UnitDefNames["raptor_allterrain_arty_emp_t2_v1"].id] = { distance = 500, chance = 0.1 },
		[UnitDefNames["raptor_allterrain_arty_emp_t4_v1"].id] = { distance = 500, chance = 0.01 },
		[UnitDefNames["raptor_allterrain_swarmer_emp_t2_v1"].id] = { distance = 300, chance = 1 },
		[UnitDefNames["raptor_land_swarmer_acids_t2_v1"].id] = { distance = 300, chance = 1 },
		[UnitDefNames["raptor_land_assault_acid_t2_v1"].id] = { distance = 200, chance = 1 },
		[UnitDefNames["raptor_allterrain_assault_acid_t2_v1"].id] = { distance = 200, chance = 1 },
		[UnitDefNames["raptor_allterrain_arty_acid_t2_v1"].id] = { distance = 500, chance = 0.1 },
		[UnitDefNames["raptor_allterrain_arty_acid_t4_v1"].id] = { distance = 500, chance = 0.01 },
		[UnitDefNames["raptor_allterrain_swarmer_acid_t2_v1"].id] = { distance = 300, chance = 1 },
		[UnitDefNames["raptor_land_swarmer_brood_t4_v1"].id] = { distance = 500, chance = 0.25 },
		[UnitDefNames["raptor_allterrain_arty_brood_t2_v1"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["raptor_allterrain_arty_brood_t4_v1"].id] = { distance = 500, chance = 0.1 },
		[UnitDefNames["raptor_land_swarmer_spectre_t3_v1"].id] = { distance = 500, chance = 0.25, teleport = true, teleportcooldown = 2,},
		[UnitDefNames["raptor_land_swarmer_spectre_t4_v1"].id] = { distance = 500, chance = 0.25, teleport = true, teleportcooldown = 2,},
		[UnitDefNames["raptor_land_spiker_spectre_t4_v1"].id] = { distance = 500, chance = 0.25, teleport = true, teleportcooldown = 2,},
		[UnitDefNames["raptor_land_assault_spectre_t2_v1"].id] = { distance = 500, chance = 0.25, teleport = true, teleportcooldown = 2,},
		[UnitDefNames["raptor_land_assault_spectre_t4_v1"].id] = { distance = 500, chance = 0.25, teleport = true, teleportcooldown = 2,},
		[UnitDefNames["raptor_matriarch_spectre"].id] = {distance = 500, chance = 0.001, teleport = true, teleportcooldown = 2 },
		[UnitDefNames["raptor_matriarch_electric"].id] = {distance = 500, chance = 0.001 },
		[UnitDefNames["raptor_matriarch_acid"].id] = { distance = 500, chance = 0.001 },
		[UnitDefNames["raptor_matriarch_healer"].id] = { distance = 500, chance = 0.001 },
		[UnitDefNames["raptor_matriarch_basic"].id] = { distance = 500, chance = 0.001 },
		[UnitDefNames["raptor_matriarch_fire"].id] = { distance = 500, chance = 0.001 },
	},
	COWARD = { -- Run away from target after getting hit by enemy
		[UnitDefNames["raptor_land_swarmer_heal_t1_v1"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["raptor_land_swarmer_heal_t2_v1"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["raptor_land_swarmer_heal_t3_v1"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["raptor_land_swarmer_heal_t4_v1"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["raptorh1b"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["raptor_land_spiker_basic_t2_v1"].id] = { distance = 270, chance = 0.5 },
		[UnitDefNames["raptor_land_spiker_basic_t4_v1"].id] = { distance = 250, chance = 0.5 },
		[UnitDefNames["raptor_allterrain_arty_basic_t2_v1"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["raptor_allterrain_arty_basic_t4_v1"].id] = { distance = 500, chance = 0.1 },
		[UnitDefNames["raptor_allterrain_arty_emp_t2_v1"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["raptor_allterrain_arty_emp_t4_v1"].id] = { distance = 500, chance = 0.1 },
		[UnitDefNames["raptor_allterrain_arty_acid_t2_v1"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["raptor_allterrain_arty_acid_t4_v1"].id] = { distance = 500, chance = 0.1 },
		[UnitDefNames["raptor_allterrain_arty_brood_t2_v1"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["raptor_allterrain_arty_brood_t4_v1"].id] = { distance = 500, chance = 0.1 },
		[UnitDefNames["raptor_land_swarmer_brood_t4_v1"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["raptor_land_swarmer_brood_t3_v1"].id] = { distance = 500, chance = 0.25 },
		[UnitDefNames["raptor_land_swarmer_spectre_t3_v1"].id] = { distance = 500, chance = 0.25, teleport = true, teleportcooldown = 2,},
		[UnitDefNames["raptor_land_swarmer_spectre_t4_v1"].id] = { distance = 500, chance = 0.25, teleport = true, teleportcooldown = 2,},
		[UnitDefNames["raptor_land_spiker_spectre_t4_v1"].id] = { distance = 500, chance = 0.25, teleport = true, teleportcooldown = 2,},
		[UnitDefNames["raptor_land_assault_spectre_t2_v1"].id] = { distance = 500, chance = 0.25, teleport = true, teleportcooldown = 2,},
		[UnitDefNames["raptor_land_assault_spectre_t4_v1"].id] = { distance = 500, chance = 0.25, teleport = true, teleportcooldown = 2,},
		[UnitDefNames["raptor_matriarch_spectre"].id] = { distance = 500, chance = 0.001, teleport = true, teleportcooldown = 2 },
		[UnitDefNames["raptor_matriarch_electric"].id] = { distance = 500, chance = 0.001 },
		[UnitDefNames["raptor_matriarch_acid"].id] = { distance = 500, chance = 0.001 },
		[UnitDefNames["raptor_matriarch_healer"].id] = { distance = 500, chance = 0.001 },
		[UnitDefNames["raptor_matriarch_basic"].id] = { distance = 500, chance = 0.001 },
		[UnitDefNames["raptor_matriarch_fire"].id] = { distance = 500, chance = 0.001 },
	},
	BERSERK = { -- Run towards target after getting hit by enemy or after hitting the target
		[UnitDefNames["raptor_land_spiker_basic_t4_v1"].id] = {chance = 0.2, distance = 750},
		[UnitDefNames["raptor_land_assault_basic_t2_v1"].id] = { chance = 0.2, distance = 1500 },
		[UnitDefNames["raptor_land_assault_basic_t2_v2"].id] = { chance = 0.2, distance = 1500 },
		[UnitDefNames["raptor_land_assault_basic_t2_v3"].id] = { chance = 0.2, distance = 1500 },
		[UnitDefNames["raptor_allterrain_assault_basic_t2_v1"].id] = { chance = 0.2, distance = 1500 },
		[UnitDefNames["raptor_allterrain_assault_basic_t2_v2"].id] = { chance = 0.2, distance = 1500 },
		[UnitDefNames["raptor_allterrain_assault_basic_t2_v3"].id] = { chance = 0.2, distance = 1500 },
		[UnitDefNames["raptor_land_assault_basic_t4_v1"].id] = { chance = 0.2, distance = 3000 },
		[UnitDefNames["raptor_land_assault_basic_t4_v2"].id] = { chance = 0.2, distance = 3000 },
		[UnitDefNames["raptor_allterrain_assault_basic_t4_v1"].id] = { chance = 0.2, distance = 3000 },
		[UnitDefNames["raptor_allterrain_assault_basic_t4_v2"].id] = { chance = 0.2, distance = 3000 },
		[UnitDefNames["raptor_land_assault_emp_t2_v1"].id] = { chance = 0.05 },
		[UnitDefNames["raptor_allterrain_assault_emp_t2_v1"].id] = { chance = 0.05 },
		[UnitDefNames["raptor_land_assault_acid_t2_v1"].id] = { chance = 0.05 },
		[UnitDefNames["raptor_allterrain_assault_acid_t2_v1"].id] = { chance = 0.05 },
		[UnitDefNames["raptor_land_swarmer_acids_t2_v1"].id] = { chance = 0.01 },
		[UnitDefNames["raptor_allterrain_swarmer_acid_t2_v1"].id] = { chance = 0.01 },
		[UnitDefNames["raptor_land_swarmer_fire_t2_v1"].id] = { chance = 0.2 },
		[UnitDefNames["raptor_land_swarmer_fire_t4_v1"].id] = { chance = 0.2 },
		[UnitDefNames["raptor_allterrain_swarmer_fire_t2_v1"].id] = { chance = 0.2 },
		[UnitDefNames["raptor_land_swarmer_brood_t2_v1"].id] = { chance = 1 },
		[UnitDefNames["raptor_land_swarmer_spectre_t3_v1"].id] = { distance = 1000, chance = 0.25},
		[UnitDefNames["raptor_land_swarmer_spectre_t4_v1"].id] = { distance = 1000, chance = 0.25},
		[UnitDefNames["raptor_land_assault_spectre_t2_v1"].id] = { distance = 1000, chance = 0.25},
		[UnitDefNames["raptor_land_assault_spectre_t4_v1"].id] = { distance = 1000, chance = 0.25},
		[UnitDefNames["raptor_land_spiker_spectre_t4_v1"].id] = { distance = 1000, chance = 0.25},
		[UnitDefNames["raptor_matriarch_spectre"].id] = {distance = 500, chance = 0.01 },
		[UnitDefNames["raptor_matriarch_electric"].id] = {distance = 500, chance = 0.01 },
		[UnitDefNames["raptor_matriarch_acid"].id] = { distance = 500, chance = 0.01 },
		[UnitDefNames["raptor_matriarch_healer"].id] = { distance = 500, chance = 0.01 },
		[UnitDefNames["raptor_matriarch_basic"].id] = { distance = 500, chance = 0.01 },
		[UnitDefNames["raptor_matriarch_fire"].id] = { distance = 500, chance = 0.01 },
		[UnitDefNames["raptor_queen_veryeasy"].id] = { chance = 0.005 },
		[UnitDefNames["raptor_queen_easy"].id] = { chance = 0.005 },
		[UnitDefNames["raptor_queen_normal"].id] = { chance = 0.005 },
		[UnitDefNames["raptor_queen_hard"].id] = { chance = 0.005 },
		[UnitDefNames["raptor_queen_veryhard"].id] = { chance = 0.005 },
		[UnitDefNames["raptor_queen_epic"].id] = { chance = 0.005 },
	},
	HEALER = { -- Getting long max lifetime and always use Fight command. These units spawn as healers from burrows and queen
		[UnitDefNames["raptor_land_swarmer_heal_t1_v1"].id] = true,
		[UnitDefNames["raptor_land_swarmer_heal_t2_v1"].id] = true,
		[UnitDefNames["raptor_land_swarmer_heal_t3_v1"].id] = true,
		[UnitDefNames["raptor_land_swarmer_heal_t4_v1"].id] = true,
		[UnitDefNames["raptorh1b"].id] = true,
	},
	ARTILLERY = { -- Long lifetime and no regrouping, always uses Fight command to keep distance, friendly fire enabled (assuming nothing else in the game stops it)
		[UnitDefNames["raptor_allterrain_arty_basic_t2_v1"].id] = true,
		[UnitDefNames["raptor_allterrain_arty_basic_t4_v1"].id] = true,
		[UnitDefNames["raptor_allterrain_arty_emp_t2_v1"].id] = true,
		[UnitDefNames["raptor_allterrain_arty_emp_t4_v1"].id] = true,
		[UnitDefNames["raptor_allterrain_arty_acid_t2_v1"].id] = true,
		[UnitDefNames["raptor_allterrain_arty_acid_t4_v1"].id] = true,
		[UnitDefNames["raptor_allterrain_arty_brood_t4_v1"].id] = true,
		[UnitDefNames["raptor_allterrain_arty_brood_t2_v1"].id] = true,
		[UnitDefNames["raptor_turret_meteor_t4_v1"].id] = true,
	},
	KAMIKAZE = { -- Long lifetime and no regrouping, always uses Move command to rush into the enemy
		[UnitDefNames["raptor_land_kamikaze_basic_t2_v1"].id] = true,
		[UnitDefNames["raptor_land_kamikaze_basic_t4_v1"].id] = true,
		[UnitDefNames["raptor_land_kamikaze_emp_t2_v1"].id] = true,
		[UnitDefNames["raptor_land_kamikaze_emp_t4_v1"].id] = true,
		[UnitDefNames["raptor_air_kamikaze_basic_t2_v1"].id] = true,
	},
	ALLOWFRIENDLYFIRE = {
		[UnitDefNames["raptor_allterrain_arty_basic_t2_v1"].id] = true,
		[UnitDefNames["raptor_allterrain_arty_basic_t4_v1"].id] = true,
		[UnitDefNames["raptor_turret_basic_t2_v1"].id] = true,
		[UnitDefNames["raptor_turret_basic_t3_v1"].id] = true,
		[UnitDefNames["raptor_turret_basic_t4_v1"].id] = true,
		[UnitDefNames["raptor_turret_meteor_t4_v1"].id] = true,
		[UnitDefNames["raptor_hive"].id] = true,
	},
	PROBE_UNIT = UnitDefNames["raptor_land_swarmer_basic_t4_v1"].id, -- tester unit for picking viable spawn positions - use some medium sized unit
}

local optionValues = {

	[difficulties.veryeasy] = {
		gracePeriod               = 9 * Spring.GetModOptions().raptor_graceperiodmult * 60,
		queenTime                 = 55 * Spring.GetModOptions().raptor_queentimemult * 60, -- time at which the queen appears, seconds
		raptorSpawnRate           = 120 / Spring.GetModOptions().raptor_spawntimemult / economyScale,
		burrowSpawnRate           = 240 / Spring.GetModOptions().raptor_spawntimemult / economyScale,
		turretSpawnRate           = 120 / Spring.GetModOptions().raptor_spawntimemult / economyScale,
		queenSpawnMult            = 1,
		angerBonus                = 0.1,
		maxXP                     = 0.5 * economyScale,
		spawnChance               = 0.1,
		damageMod                 = 0.4,
		healthMod                 = 0.5,
		maxBurrows                = 1000,
		minRaptors                = 5 * economyScale,
		maxRaptors                = 25 * economyScale,
		raptorPerPlayerMultiplier = 0.25,
		queenName                 = 'raptor_queen_veryeasy',
		queenResistanceMult       = 0.5 * economyScale,
	},

	[difficulties.easy] = {
		gracePeriod               = 8 * Spring.GetModOptions().raptor_graceperiodmult * 60,
		queenTime                 = 50 * Spring.GetModOptions().raptor_queentimemult * 60, -- time at which the queen appears, seconds
		raptorSpawnRate           = 90 / Spring.GetModOptions().raptor_spawntimemult / economyScale,
		burrowSpawnRate           = 210 / Spring.GetModOptions().raptor_spawntimemult / economyScale,
		turretSpawnRate           = 100 / Spring.GetModOptions().raptor_spawntimemult / economyScale,
		queenSpawnMult            = 1,
		angerBonus                = 0.15,
		maxXP                     = 1 * economyScale,
		spawnChance               = 0.2,
		damageMod                 = 0.6,
		healthMod                 = 0.75,
		maxBurrows                = 1000,
		minRaptors                = 5 * economyScale,
		maxRaptors                = 30 * economyScale,
		raptorPerPlayerMultiplier = 0.25,
		queenName                 = 'raptor_queen_easy',
		queenResistanceMult       = 0.75 * economyScale,
	},
	[difficulties.normal] = {
		gracePeriod               = 7 * Spring.GetModOptions().raptor_graceperiodmult * 60,
		queenTime                 = 45 * Spring.GetModOptions().raptor_queentimemult * 60, -- time at which the queen appears, seconds
		raptorSpawnRate           = 60 / Spring.GetModOptions().raptor_spawntimemult / economyScale,
		burrowSpawnRate           = 180 / Spring.GetModOptions().raptor_spawntimemult / economyScale,
		turretSpawnRate           = 80 / Spring.GetModOptions().raptor_spawntimemult / economyScale,
		queenSpawnMult            = 3,
		angerBonus                = 0.20,
		maxXP                     = 1.5 * economyScale,
		spawnChance               = 0.3,
		damageMod                 = 0.8,
		healthMod                 = 1,
		maxBurrows                = 1000,
		minRaptors                = 5 * economyScale,
		maxRaptors                = 35 * economyScale,
		raptorPerPlayerMultiplier = 0.25,
		queenName                 = 'raptor_queen_normal',
		queenResistanceMult       = 1 * economyScale,
	},
	[difficulties.hard] = {
		gracePeriod               = 6 * Spring.GetModOptions().raptor_graceperiodmult * 60,
		queenTime                 = 40 * Spring.GetModOptions().raptor_queentimemult * 60, -- time at which the queen appears, seconds
		raptorSpawnRate           = 50 / Spring.GetModOptions().raptor_spawntimemult / economyScale,
		burrowSpawnRate           = 150 / Spring.GetModOptions().raptor_spawntimemult / economyScale,
		turretSpawnRate           = 60 / Spring.GetModOptions().raptor_spawntimemult / economyScale,
		queenSpawnMult            = 3,
		angerBonus                = 0.25,
		maxXP                     = 2 * economyScale,
		spawnChance               = 0.4,
		damageMod                 = 1,
		healthMod                 = 1.1,
		maxBurrows                = 1000,
		minRaptors                = 5 * economyScale,
		maxRaptors                = 40 * economyScale,
		raptorPerPlayerMultiplier = 0.25,
		queenName                 = 'raptor_queen_hard',
		queenResistanceMult       = 1.33 * economyScale,
	},
	[difficulties.veryhard] = {
		gracePeriod               = 5 * Spring.GetModOptions().raptor_graceperiodmult * 60,
		queenTime                 = 35 * Spring.GetModOptions().raptor_queentimemult * 60, -- time at which the queen appears, seconds
		raptorSpawnRate           = 40 / Spring.GetModOptions().raptor_spawntimemult / economyScale,
		burrowSpawnRate           = 120 / Spring.GetModOptions().raptor_spawntimemult / economyScale,
		turretSpawnRate           = 40 / Spring.GetModOptions().raptor_spawntimemult / economyScale,
		queenSpawnMult            = 3,
		angerBonus                = 0.30,
		maxXP                     = 2.5 * economyScale,
		spawnChance               = 0.5,
		damageMod                 = 1.2,
		healthMod                 = 1.25,
		maxBurrows                = 1000,
		minRaptors                = 5 * economyScale,
		maxRaptors                = 45 * economyScale,
		raptorPerPlayerMultiplier = 0.25,
		queenName                 = 'raptor_queen_veryhard',
		queenResistanceMult       = 1.67 * economyScale,
	},
	[difficulties.epic] = {
		gracePeriod               = 4 * Spring.GetModOptions().raptor_graceperiodmult * 60,
		queenTime                 = 30 * Spring.GetModOptions().raptor_queentimemult * 60, -- time at which the queen appears, seconds
		raptorSpawnRate           = 30 / Spring.GetModOptions().raptor_spawntimemult / economyScale,
		burrowSpawnRate           = 90 / Spring.GetModOptions().raptor_spawntimemult / economyScale,
		turretSpawnRate           = 20 / Spring.GetModOptions().raptor_spawntimemult / economyScale,
		queenSpawnMult            = 3,
		angerBonus                = 0.35,
		maxXP                     = 3 * economyScale,
		spawnChance               = 0.6,
		damageMod                 = 1.4,
		healthMod                 = 1.5,
		maxBurrows                = 1000,
		minRaptors                = 5 * economyScale,
		maxRaptors                = 50 * economyScale,
		raptorPerPlayerMultiplier = 0.25,
		queenName                 = 'raptor_queen_epic',
		queenResistanceMult       = 2 * economyScale,
	},

	-- [difficulties.survival] = {
	-- 	gracePeriod       = 8 * Spring.GetModOptions().raptor_graceperiodmult * 60,
	-- 	queenTime      	  = 50 * Spring.GetModOptions().raptor_queentimemult * 60, -- time at which the queen appears, seconds
	-- 	raptorSpawnRate  = 120,
	-- 	burrowSpawnRate   = 480,
	-- 	turretSpawnRate   = 240,
	-- 	queenSpawnMult    = 1,
	-- 	angerBonus        = 1,
	-- 	maxXP			  = 0.5,
	-- 	spawnChance       = 0.1,
	-- 	damageMod         = 0.4,
	-- 	maxBurrows        = 1000,
	-- 	minRaptors		  = 5,
	-- 	maxRaptors		  = 25,
	-- 	raptorPerPlayerMultiplier = 0.25,
	-- 	queenName         = 'raptor_queen_veryeasy',
	-- 	queenResistanceMult   = 0.5,
	-- },
}


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local squadSpawnOptionsTable = {
	basic = {},
	special = {},
	basicAir = {},
	specialAir = {},
	healer = {}, -- Healers/Medics
}

local function addNewSquad(squadParams) -- params: {type = "basic", minAnger = 0, maxAnger = 100, units = {"1 raptor_land_swarmer_basic_t2_v1"}, weight = 1}
	if squadParams then -- Just in case
		if not squadParams.units then return end
		if not squadParams.minAnger then squadParams.minAnger = 0 end
		if not squadParams.maxAnger then squadParams.maxAnger = squadParams.minAnger + 100 end -- Eliminate squads 100% after they're introduced by default, can be overwritten
		if squadParams.maxAnger >= 1000 then squadParams.maxAnger = 1000 end -- basically infinite, anger caps at 999
		if not squadParams.weight then squadParams.weight = 1 end

		for _ = 1,squadParams.weight do
			table.insert(squadSpawnOptionsTable[squadParams.type], {minAnger = squadParams.minAnger, maxAnger = squadParams.maxAnger, units = squadParams.units, weight = squadParams.weight})
		end
	end
end

-- addNewSquad({type = "basic", minAnger = 0, units = {"1 raptor_land_swarmer_basic_t2_v1"}}) -- Minimum
-- addNewSquad({type = "basic", minAnger = 0, units = {"1 raptor_land_swarmer_basic_t2_v1"}, weight = 1, maxAnger = 100}) -- Full

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- MiniBoss Squads ----------------------------------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local miniBosses = { -- Units that spawn alongside queen
	"raptor_matriarch_electric", 	-- Electric Miniqueen
	"raptor_matriarch_acid", 		-- Acid Miniqueen
	"raptor_matriarch_healer", 	-- Healer Miniqueen
	"raptor_matriarch_basic",		-- Basic Miniqueen
	"raptor_matriarch_fire",		-- Pyro Miniqueen
	"raptor_matriarch_spectre",	-- Spectre Miniqueen
}

local raptorMinions = { -- Units spawning other units
	["raptor_matriarch_electric"] = {
		"raptor_land_swarmer_emp_t2_v1",
		"raptor_land_assault_emp_t2_v1",
		--"raptor_allterrain_arty_emp_t2_v1",
		"raptor_allterrain_swarmer_emp_t2_v1",
		"raptor_allterrain_assault_emp_t2_v1",
	},
	["raptor_matriarch_acid"] = {
		"raptor_land_swarmer_acids_t2_v1",
		"raptor_land_assault_acid_t2_v1",
		--"raptor_allterrain_arty_acid_t2_v1",
		"raptor_allterrain_swarmer_acid_t2_v1",
		"raptor_allterrain_assault_acid_t2_v1",
	},
	["raptor_matriarch_healer"] = {
		"raptor_land_swarmer_heal_t1_v1",
		"raptor_land_swarmer_heal_t2_v1",
		"raptor_land_swarmer_heal_t3_v1",
		"raptor_land_swarmer_heal_t4_v1",
		--"raptorh1b",
	},
	["raptor_matriarch_basic"] = {
		"raptor_land_swarmer_basic_t2_v1",
		"raptor_land_swarmer_basic_t3_v1",
		"raptor_land_swarmer_basic_t4_v1",
		"raptor_land_swarmer_basic_t4_v2",
		"raptor_allterrain_swarmer_basic_t4_v1",
	},
	["raptor_matriarch_fire"] = {
		"raptor_land_swarmer_fire_t2_v1",
		"raptor_land_swarmer_fire_t4_v1",
		"raptor_allterrain_swarmer_fire_t2_v1",
	},
	["raptor_matriarch_spectre"] = {
		"raptor_land_spiker_spectre_t4_v1",
		"raptor_land_swarmer_spectre_t3_v1",
		"raptor_land_swarmer_spectre_t4_v1",
		"raptor_land_assault_spectre_t2_v1",
		"raptor_land_assault_spectre_t4_v1",
	},
	["raptor_land_swarmer_brood_t4_v1"] = {
		"raptor_land_swarmer_brood_t3_v1",
		"raptor_land_swarmer_brood_t2_v1",
	},
	["raptor_land_swarmer_brood_t3_v1"] = {
		"raptor_land_swarmer_brood_t2_v1",
	},
	["raptor_allterrain_arty_brood_t4_v1"] = {
		"raptor_land_swarmer_brood_t2_v1",
	},
	["raptor_queen_veryeasy"] = {
		"raptor_land_swarmer_brood_t4_v1",
		"raptor_land_swarmer_brood_t3_v1",
		"raptor_land_swarmer_brood_t2_v1",
		"raptor_land_swarmer_heal_t1_v1",
	},
	["raptor_queen_easy"] = {
		"raptor_land_swarmer_brood_t4_v1",
		"raptor_land_swarmer_brood_t3_v1",
		"raptor_land_swarmer_brood_t2_v1",
		"raptor_allterrain_arty_brood_t2_v1",
		"raptor_land_swarmer_heal_t1_v1",
		"raptor_land_swarmer_heal_t2_v1",
	},
	["raptor_queen_normal"] = {
		"raptor_land_swarmer_brood_t4_v1",
		"raptor_land_swarmer_brood_t3_v1",
		"raptor_land_swarmer_brood_t2_v1",
		"raptor_allterrain_arty_brood_t2_v1",
		"raptor_land_swarmer_heal_t2_v1",
		"raptor_land_swarmer_heal_t3_v1",
	},
	["raptor_queen_hard"] = {
		"raptor_land_swarmer_brood_t4_v1",
		"raptor_land_swarmer_brood_t3_v1",
		"raptor_land_swarmer_brood_t2_v1",
		"raptor_allterrain_arty_brood_t2_v1",
		"raptor_land_swarmer_heal_t2_v1",
		"raptor_land_swarmer_heal_t3_v1",
	},
	["raptor_queen_veryhard"] = {
		"raptor_land_swarmer_brood_t4_v1",
		"raptor_land_swarmer_brood_t3_v1",
		"raptor_land_swarmer_brood_t2_v1",
		"raptor_allterrain_arty_brood_t2_v1",
		"raptor_land_swarmer_heal_t3_v1",
		"raptor_land_swarmer_heal_t4_v1",
	},
	["raptor_queen_epic"] = {
		"raptor_land_swarmer_brood_t4_v1",
		"raptor_land_swarmer_brood_t3_v1",
		"raptor_land_swarmer_brood_t2_v1",
		"raptor_allterrain_arty_brood_t2_v1",
		"raptor_land_swarmer_heal_t3_v1",
		"raptor_land_swarmer_heal_t4_v1",
	},
}

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Squads -------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-----------
-- Basic --
-----------

-- Basic Swarmer

addNewSquad({ 
	type = "basic",
	minAnger = 0,
	maxAnger = 30,
	weight = 10,
	units = { {count = 4, unit = "raptor_land_swarmer_basic_t1_v1"} }
})
addNewSquad({
	type = "basic",
	minAnger = 10,
	maxAnger = 40,
	units = { {count = 8, unit = "raptor_land_swarmer_basic_t1_v1"} }
})
addNewSquad({
	type = "basic",
	minAnger = 20,
	maxAnger = 50,
	units = { {count = 16, unit = "raptor_land_swarmer_basic_t1_v1"} }
 })
addNewSquad({
	type = "basic",
	minAnger = 30,
	maxAnger = 60,
	units = { {count = 32, unit = "raptor_land_swarmer_basic_t1_v1"} }
})

addNewSquad({
	type = "basic",
	minAnger = 5,
	maxAnger = 50,
	units = { {count = 4, unit = "raptor_land_swarmer_basic_t2_v1" } }
})
addNewSquad({
	type = "basic",
	minAnger = 5,
	maxAnger = 50,
	units = { {count = 4, unit = "raptor_land_swarmer_basic_t2_v2" } }
})
addNewSquad({
	type = "basic",
	minAnger = 5,
	maxAnger = 50,
	units = { {count = 4, unit = "raptor_land_swarmer_basic_t2_v3"} }
})
addNewSquad({
	type = "basic",
	minAnger = 5,
	maxAnger = 50,
	units = { {count = 4, unit = "raptor_land_swarmer_basic_t2_v4"} }
})

addNewSquad({
	type = "basic",
	minAnger = 25,
	maxAnger = 70,
	units = {
		{count = 4, unit = "raptor_land_swarmer_basic_t2_v1"},
		{count = 4, unit = "raptor_land_swarmer_basic_t2_v2"}
	},
})
addNewSquad({
	type = "basic",
	minAnger = 25,
	maxAnger = 70,
	units = {
		{count = 4, unit = "raptor_land_swarmer_basic_t2_v2"},
		{count = 4, unit = "raptor_land_swarmer_basic_t2_v3"}
	},
})
addNewSquad({
	type = "basic",
	minAnger = 25,
	maxAnger = 70,
	units = {
		{count = 4, unit = "raptor_land_swarmer_basic_t2_v3"},
		{count = 4, unit = "raptor_land_swarmer_basic_t2_v4"}
	},
})
addNewSquad({
	type = "basic",
	minAnger = 25,
	maxAnger = 70,
	units = {
		{count = 4, unit = "raptor_land_swarmer_basic_t2_v4"},
		{count = 4, unit = "raptor_land_swarmer_basic_t2_v1"}
	},
})

addNewSquad({
	type = "basic",
	minAnger = 45,
	maxAnger = 90,
	units = {
		{count = 4, unit = "raptor_land_swarmer_basic_t2_v1"},
		{count = 4, unit = "raptor_land_swarmer_basic_t2_v2"},
		{count = 4, unit = "raptor_land_swarmer_basic_t2_v3"}
	},
})
addNewSquad({
	type = "basic",
	minAnger = 45,
	maxAnger = 90,
	units = {
		{count = 4, unit = "raptor_land_swarmer_basic_t2_v2"},
		{count = 4, unit = "raptor_land_swarmer_basic_t2_v3"},
		{count = 4, unit = "raptor_land_swarmer_basic_t2_v4"}
	},
})
addNewSquad({
	type = "basic",
	minAnger = 45,
	maxAnger = 90,
	units = {
		{count = 4, unit = "raptor_land_swarmer_basic_t2_v3"},
		{count = 4, unit = "raptor_land_swarmer_basic_t2_v4"},
		{count = 4, unit = "raptor_land_swarmer_basic_t2_v1"}
	},
})
addNewSquad({
	type = "basic",
	minAnger = 45,
	maxAnger = 90,
	units = {
		{count = 4, unit = "raptor_land_swarmer_basic_t2_v4"},
		{count = 4, unit = "raptor_land_swarmer_basic_t2_v1"},
		{count = 4, unit = "raptor_land_swarmer_basic_t2_v2"}
	},
})

addNewSquad({
	type = "basic",
	minAnger = 65,
	maxAnger = 125,
	units = {
		{count = 4, unit = "raptor_land_swarmer_basic_t2_v1"},
		{count = 4, unit = "raptor_land_swarmer_basic_t2_v2"},
		{count = 4, unit = "raptor_land_swarmer_basic_t2_v3"},
		{count = 4, unit = "raptor_land_swarmer_basic_t2_v4"}
	},
})
addNewSquad({
	type = "basic",
	minAnger = 65,
	maxAnger = 125,
	units = {
		{count = 4, unit = "raptor_land_swarmer_basic_t2_v2"},
		{count = 4, unit = "raptor_land_swarmer_basic_t2_v3"},
		{count = 4, unit = "raptor_land_swarmer_basic_t2_v4"},
		{count = 4, unit = "raptor_land_swarmer_basic_t2_v1"}
	},
})
addNewSquad({
	type = "basic",
	minAnger = 65,
	maxAnger = 125,
	units = {
		{count = 4, unit = "raptor_land_swarmer_basic_t2_v3"},
		{count = 4, unit = "raptor_land_swarmer_basic_t2_v4"},
		{count = 4, unit = "raptor_land_swarmer_basic_t2_v1"},
		{count = 4, unit = "raptor_land_swarmer_basic_t2_v2"}
	},
})
addNewSquad({
	type = "basic",
	minAnger = 65,
	maxAnger = 125,
	units = {
		{count = 4, unit = "raptor_land_swarmer_basic_t2_v4"},
		{count = 4, unit = "raptor_land_swarmer_basic_t2_v1"},
		{count = 4, unit = "raptor_land_swarmer_basic_t2_v2"},
		{count = 4, unit = "raptor_land_swarmer_basic_t2_v3"}
	},
})

addNewSquad({
	type = "basic",
	minAnger = 85,
	maxAnger = 1000,
	units = {
		{count = 8, unit = "raptor_land_swarmer_basic_t2_v1"},
		{count = 8, unit = "raptor_land_swarmer_basic_t2_v2"},
		{count = 8, unit = "raptor_land_swarmer_basic_t2_v3"},
		{count = 8, unit = "raptor_land_swarmer_basic_t2_v4"}
	}
})
addNewSquad({
	type = "basic",
	minAnger = 85,
	maxAnger = 1000,
	units = {
		{count = 8, unit = "raptor_land_swarmer_basic_t2_v2"},
		{count = 8, unit = "raptor_land_swarmer_basic_t2_v3"},
		{count = 8, unit = "raptor_land_swarmer_basic_t2_v4"},
		{count = 8, unit = "raptor_land_swarmer_basic_t2_v1"}
	}
})
addNewSquad({
	type = "basic",
	minAnger = 85,
	maxAnger = 1000,
	units = {
		{count = 8, unit = "raptor_land_swarmer_basic_t2_v3"},
		{count = 8, unit = "raptor_land_swarmer_basic_t2_v4"},
		{count = 8, unit = "raptor_land_swarmer_basic_t2_v1"},
		{count = 8, unit = "raptor_land_swarmer_basic_t2_v2"}
	}
})
addNewSquad({
	type = "basic",
	minAnger = 85,
	maxAnger = 1000,
	units = {
		{count = 8, unit = "raptor_land_swarmer_basic_t2_v4"},
		{count = 8, unit = "raptor_land_swarmer_basic_t2_v1"},
		{count = 8, unit = "raptor_land_swarmer_basic_t2_v2"},
		{count = 8, unit = "raptor_land_swarmer_basic_t2_v3"}
	}
})

-- Better Swarmer

addNewSquad({
	type = "basic",
	minAnger = 25,
	maxAnger = 70,
	units = { {count = 4, unit = "raptor_land_swarmer_basic_t3_v1"} }
})
addNewSquad({
	type = "basic",
	minAnger = 25,
	maxAnger = 70,
	units = { {count = 4, unit = "raptor_land_swarmer_basic_t3_v2"} }
})
addNewSquad({
	type = "basic",
	minAnger = 25,
	maxAnger = 70,
	units = { {count = 4, unit = "raptor_land_swarmer_basic_t3_v3"} }
})

addNewSquad({
	type = "basic",
	minAnger = 45,
	maxAnger = 90,
	units = {
		{ count = 4, unit = "raptor_land_swarmer_basic_t3_v1" },
		{ count = 4, unit = "raptor_land_swarmer_basic_t3_v2" }
	},
})
addNewSquad({
	type = "basic",
	minAnger = 45,
	maxAnger = 90,
	units = {
		{ count = 4, unit = "raptor_land_swarmer_basic_t3_v2" },
		{ count = 4, unit = "raptor_land_swarmer_basic_t3_v3" }
	},
})
addNewSquad({
	type = "basic",
	minAnger = 45,
	maxAnger = 90,
	units = {
		{ count = 4, unit = "raptor_land_swarmer_basic_t3_v3" },
		{ count = 4, unit = "raptor_land_swarmer_basic_t3_v1" }
	},
})

addNewSquad({
	type = "basic",
	minAnger = 65,
	maxAnger = 125,
	units = {
		{ count = 4, unit = "raptor_land_swarmer_basic_t3_v1" },
		{ count = 4, unit = "raptor_land_swarmer_basic_t3_v2" },
		{ count = 4, unit = "raptor_land_swarmer_basic_t3_v3" }
	},
})
addNewSquad({
	type = "basic",
	minAnger = 65,
	maxAnger = 125,
	units = {
		{ count = 4, unit = "raptor_land_swarmer_basic_t3_v2" },
		{ count = 4, unit = "raptor_land_swarmer_basic_t3_v3" },
		{ count = 4, unit = "raptor_land_swarmer_basic_t3_v1" }
	},
})
addNewSquad({
	type = "basic",
	minAnger = 65,
	maxAnger = 125,
	units = {
		{ count = 4, unit = "raptor_land_swarmer_basic_t3_v3" },
		{ count = 4, unit = "raptor_land_swarmer_basic_t3_v1" },
		{ count = 4, unit = "raptor_land_swarmer_basic_t3_v2" }
	},
})

addNewSquad({
	type = "basic",
	minAnger = 85,
	maxAnger = 1000,
	units = {
		{ count = 8, unit = "raptor_land_swarmer_basic_t3_v1" },
		{ count = 8, unit = "raptor_land_swarmer_basic_t3_v2" },
		{ count = 8, unit = "raptor_land_swarmer_basic_t3_v3" }
	}
})
addNewSquad({
	type = "basic",
	minAnger = 85,
	maxAnger = 1000,
	units = {
		{ count = 8, unit = "raptor_land_swarmer_basic_t3_v2" },
		{ count = 8, unit = "raptor_land_swarmer_basic_t3_v3" },
		{ count = 8, unit = "raptor_land_swarmer_basic_t3_v1" }
	}
})
addNewSquad({
	type = "basic",
	minAnger = 85,
	maxAnger = 1000,
	units = {
		{ count = 8, unit = "raptor_land_swarmer_basic_t3_v3" },
		{ count = 8, unit = "raptor_land_swarmer_basic_t3_v1" },
		{ count = 8, unit = "raptor_land_swarmer_basic_t3_v2" }
	}
})
addNewSquad({
	type = "basic",
	minAnger = 25,
	maxAnger = 70,
	units = { {count = 4, unit = "raptor_land_swarmer_basic_t3_v2"} }
})
addNewSquad({
	type = "basic",
	minAnger = 25,
	maxAnger = 70,
	units = { {count = 4, unit = "raptor_land_swarmer_basic_t3_v3"} }
})

addNewSquad({
	type = "basic",
	minAnger = 45,
	maxAnger = 90,
	units = {
		{count = 4, unit = "raptor_land_swarmer_basic_t3_v1"},
		{count = 4, unit = "raptor_land_swarmer_basic_t3_v2"}
	}
})
addNewSquad({
	type = "basic",
	minAnger = 45,
	maxAnger = 90,
	units = {
		{count = 4, unit = "raptor_land_swarmer_basic_t3_v2"},
		{count = 4, unit = "raptor_land_swarmer_basic_t3_v3"}
	}
})
addNewSquad({
	type = "basic",
	minAnger = 45,
	maxAnger = 90,
	units = {
		{count = 4, unit = "raptor_land_swarmer_basic_t3_v3"},
		{count = 4, unit = "raptor_land_swarmer_basic_t3_v1"}
	}
})

addNewSquad({
	type = "basic",
	minAnger = 65,
	maxAnger = 125,
	units = {
		{count = 4, unit = "raptor_land_swarmer_basic_t3_v1"},
		{count = 4, unit = "raptor_land_swarmer_basic_t3_v2"},
		{count = 4, unit = "raptor_land_swarmer_basic_t3_v3"}
	}
})
addNewSquad({
	type = "basic",
	minAnger = 65,
	maxAnger = 125,
	units = {
		{count = 4, unit = "raptor_land_swarmer_basic_t3_v2"},
		{count = 4, unit = "raptor_land_swarmer_basic_t3_v3"},
		{count = 4, unit = "raptor_land_swarmer_basic_t3_v1"}
	}
})
addNewSquad({
	type = "basic",
	minAnger = 65,
	maxAnger = 125,
	units = {
		{count = 4, unit = "raptor_land_swarmer_basic_t3_v3"},
		{count = 4, unit = "raptor_land_swarmer_basic_t3_v1"},
		{count = 4, unit = "raptor_land_swarmer_basic_t3_v2"}
	}
})

addNewSquad({
	type = "basic",
	minAnger = 85,
	maxAnger = 1000,
	units = {
		{count = 8, unit = "raptor_land_swarmer_basic_t3_v1"},
		{count = 8, unit = "raptor_land_swarmer_basic_t3_v2"},
		{count = 8, unit = "raptor_land_swarmer_basic_t3_v3"}
	}
})
addNewSquad({
	type = "basic",
	minAnger = 85,
	maxAnger = 1000,
	units = {
		{count = 8, unit = "raptor_land_swarmer_basic_t3_v2"},
		{count = 8, unit = "raptor_land_swarmer_basic_t3_v3"},
		{count = 8, unit = "raptor_land_swarmer_basic_t3_v1"}
	}
})
addNewSquad({
	type = "basic",
	minAnger = 85,
	maxAnger = 1000,
	units = {
		{count = 8, unit = "raptor_land_swarmer_basic_t3_v3"},
		{count = 8, unit = "raptor_land_swarmer_basic_t3_v1"},
		{count = 8, unit = "raptor_land_swarmer_basic_t3_v2"}
	}
})

-- Apex Swarmer

addNewSquad({
	type = "basic",
	minAnger = 65,
	maxAnger = 1000,
	units = { {count = 4, unit = "raptor_land_swarmer_basic_t4_v2"} }
})
addNewSquad({
	type = "basic",
	minAnger = 65,
	maxAnger = 1000,
	units = { {count = 4, unit = "raptor_land_swarmer_basic_t4_v1"} }
})

addNewSquad({
	type = "basic",
	minAnger = 85,
	maxAnger = 1000,
	units = {
		{count = 4, unit = "raptor_land_swarmer_basic_t4_v2"},
		{count = 4, unit = "raptor_land_swarmer_basic_t4_v1"}
	}
})
addNewSquad({
	type = "basic",
	minAnger = 85,
	maxAnger = 1000,
	units = {
		{count = 4, unit = "raptor_land_swarmer_basic_t4_v1"},
		{count = 4, unit = "raptor_land_swarmer_basic_t4_v2"}
	}
})

addNewSquad({
	type = "basic",
	minAnger = 100,
	maxAnger = 1000,
	units = {
		{count = 8, unit = "raptor_land_swarmer_basic_t4_v2"},
		{count = 8, unit = "raptor_land_swarmer_basic_t4_v1"}
	}
})
addNewSquad({
	type = "basic",
	minAnger = 100,
	maxAnger = 1000,
	units = {
		{count = 8, unit = "raptor_land_swarmer_basic_t4_v1"},
		{count = 8, unit = "raptor_land_swarmer_basic_t4_v2"}
	}
})

-------------------------------------------------
-- Special --------------------------------------
-------------------------------------------------

--Swarmers------------------------------------------------------------------------------------------------------

addNewSquad({
	type = "special",
	minAnger = 0,
	maxAnger = 15,
	units = { {count = 1, unit = "raptor_land_swarmer_basic_t2_v1"}}
})
addNewSquad({
	type = "special",
	minAnger = 0,
	maxAnger = 15,
	units = { {count = 1, unit = "raptor_land_swarmer_basic_t2_v2"}}
})
addNewSquad({
	type = "special",
	inAnger = 0, 
	axAnger = 15, 
	nits = { {count = 1, unit = "raptor_land_swarmer_basic_t2_v3"} }
})
addNewSquad({
	type = "special",
	minAnger = 0,
	maxAnger = 15,
	units = { {count = 1, unit = "raptor_land_swarmer_basic_t2_v4"}}
})


addNewSquad({type = "special",
	minAnger = 10,
	maxAnger = 25,
	units = { {count = 1, unit = "raptor_land_swarmer_basic_t3_v1"} }
})
addNewSquad({type = "special",
	minAnger = 10,
	maxAnger = 25,
	units = { {count = 1, unit = "raptor_land_swarmer_basic_t3_v2"} }
})
addNewSquad({type = "special",
	minAnger = 10,
	maxAnger = 25,
	units = { {count = 1, unit = "raptor_land_swarmer_basic_t3_v3"} }
})

addNewSquad({
	type = "special",
	minAnger = 20,
	maxAnger = 40,
	units = {
		{count = 4, unit = "raptor_land_swarmer_basic_t3_v1"}
	}
})
addNewSquad({
	type = "special",
	minAnger = 20,
	maxAnger = 40,
	units = {
		{count = 4, unit = "raptor_land_swarmer_basic_t3_v2"}
	}
})
addNewSquad({
	type = "special",
	minAnger = 20,
	maxAnger = 40,
	units = {
		{count = 4, unit = "raptor_land_swarmer_basic_t3_v3"}
	}
})


addNewSquad({
	type = "special",
	minAnger = 40,
	units = {
		{count = 10, unit = "raptor_land_swarmer_spectre_t3_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 70,
	units = {
		{count = 5, unit = "raptor_land_swarmer_spectre_t4_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 20,
	units = {
		{count = 3, unit = "raptor_land_swarmer_emp_t2_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 50,
	units = {
		{count = 10, unit = "raptor_land_swarmer_emp_t2_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 20,
	units = {
		{count = 3, unit = "raptor_land_swarmer_acids_t2_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 50,
	units = {
		{count = 10, unit = "raptor_land_swarmer_acids_t2_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 20,
	units = {
		{count = 3, unit = "raptor_land_swarmer_emp_t2_v1"},
		{count = 3, unit = "raptor_land_swarmer_acids_t2_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 50,
	units = {
		{count = 10, unit = "raptor_land_swarmer_emp_t2_v1"},
		{count = 10, unit = "raptor_land_swarmer_acids_t2_v1"}
	}
})


addNewSquad({
	type = "special",
	minAnger = 40,
	units = {
		{count = 10, unit = "raptor_land_swarmer_basic_t3_v1"},
		{count = 10, unit = "raptor_land_swarmer_spectre_t3_v1"}
	}
})
addNewSquad({
	type = "special",
	minAnger = 40,
	units = {
		{count = 10, unit = "raptor_land_swarmer_basic_t3_v2"},
		{count = 10, unit = "raptor_land_swarmer_spectre_t3_v1"}
	}
})
addNewSquad({
	type = "special",
	minAnger = 40,
	units = {
		{count = 10, unit = "raptor_land_swarmer_basic_t3_v3"},
		{count = 10, unit = "raptor_land_swarmer_spectre_t3_v1"}
	}
})


addNewSquad({
	type = "special",
	minAnger = 70,
	maxAnger = 1000,
	units = {
		{count = 4, unit = "raptor_land_swarmer_basic_t4_v2"},
		{count = 4, unit = "raptor_land_swarmer_spectre_t4_v1"}
	}
})
addNewSquad({
	type = "special",
	minAnger = 70,
	maxAnger = 1000,
	units = {
		{count = 4, unit = "raptor_land_swarmer_basic_t4_v1"},
		{count = 4, unit = "raptor_land_swarmer_spectre_t4_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 85,
	units = {
		{count = 4, unit = "raptor_land_swarmer_basic_t4_v2"},
		{count = 4, unit = "raptor_land_swarmer_spectre_t4_v1"}
	}
})
addNewSquad({
	type = "special",
	minAnger = 85,
	units = {
		{count = 4, unit = "raptor_land_swarmer_basic_t4_v1"},
		{count = 4, unit = "raptor_land_swarmer_spectre_t4_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 100,
	maxAnger = 1000,
	units = {
		{count = 8, unit = "raptor_land_swarmer_basic_t4_v2"},
		{count = 8, unit = "raptor_land_swarmer_spectre_t4_v1"}
	}
})
addNewSquad({
	type = "special",
	minAnger = 100,
	maxAnger = 1000,
	units = {
		{count = 8, unit = "raptor_land_swarmer_basic_t4_v1"},
		{count = 8, unit = "raptor_land_swarmer_spectre_t4_v1"}
	}
})

--All Terrain Swarmers------------------------------------------------------------------------------------------------------

addNewSquad({
	type = "special",
	minAnger = 20,
	maxAnger = 60,
	weight = 2,
	units = {
		{count = 5, unit = "raptor_allterrain_swarmer_basic_t2_v1"}
	}
})
addNewSquad({
	type = "special",
	weight = 2,
	minAnger = 50,
	maxAnger = 90,
	units = {
		{count = 10, unit = "raptor_allterrain_swarmer_basic_t2_v1"}
	}
})

addNewSquad({
	type = "special",
	weight = 2,
	minAnger = 80,
	maxAnger = 1000,
	units = {
		{count = 15, unit = "raptor_allterrain_swarmer_basic_t2_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 50,
	maxAnger = 90,
	weight = 2,
	units = {
		{count = 5, unit = "raptor_allterrain_swarmer_basic_t3_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 80,
	maxAnger = 1000,
	weight = 2,
	units = {
		{count = 10, unit = "raptor_allterrain_swarmer_basic_t3_v1"}
	}
})

addNewSquad({
	type = "special",
	weight = 2,
	minAnger = 80,
	maxAnger = 1000,
	units = {
		{count = 5, unit = "raptor_allterrain_swarmer_basic_t4_v1" }
	}
})


addNewSquad({
	type = "special",
	minAnger = 50,
	units = {
		{count = 10, unit = "raptor_allterrain_swarmer_emp_t2_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 80,
	maxAnger = 1000, 
	units = {
		{count = 20, unit = "raptor_allterrain_swarmer_emp_t2_v1"}
	}
})


addNewSquad({
	type = "special",
	minAnger = 50,
	units = {
		{count = 10, unit = "raptor_allterrain_swarmer_acid_t2_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 80,
	maxAnger = 1000,
	units = {
		{count = 20, unit = "raptor_allterrain_swarmer_acid_t2_v1"}
	}
})


addNewSquad({
	type = "special",
	minAnger = 50,
	units = {
		{count = 5, unit = "raptor_allterrain_swarmer_emp_t2_v1"},
		{count = 5, unit = "raptor_allterrain_swarmer_acid_t2_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 80,
	maxAnger = 1000,
	units = {
		{count = 10, unit = "raptor_allterrain_swarmer_emp_t2_v1"},
		{count = 10, unit = "raptor_allterrain_swarmer_acid_t2_v1"}
	}
})

--Brawlers------------------------------------------------------------------------------------------------------

addNewSquad({
	type = "special",
	minAnger = 0,
	maxAnger = 35,
	units = {
		{count = 1, unit = "raptor_land_assault_basic_t2_v1"}
	}
})
addNewSquad({
	type = "special",
	minAnger = 0,
	maxAnger = 35,
	units = {
		{count = 1, unit = "raptor_land_assault_basic_t2_v2"}
	}
})
addNewSquad({
	type = "special",
	minAnger = 0,
	maxAnger = 35,
	units = {
		{count = 1, unit = "raptor_land_assault_basic_t2_v3"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 35,
	weight = 2,
	units = {
		{count = 3, unit = "raptor_land_assault_basic_t2_v1"}
	}
})
addNewSquad({
	type = "special",
	minAnger = 35,
	weight = 2,
	units = {
		{count = 3, unit = "raptor_land_assault_basic_t2_v2"}
	}
})
addNewSquad({
	type = "special",
	minAnger = 35,
	weight = 2,
	units = {
		{count = 3, unit = "raptor_land_assault_basic_t2_v3"}
	}
})


addNewSquad({
	type = "special",
	minAnger = 65,
	units = {
		{count = 2, unit = "raptor_land_assault_basic_t4_v1"}
	}
})
addNewSquad({
	type = "special",
	minAnger = 65,
	units = {
		{count = 2, unit = "raptor_land_assault_basic_t4_v2"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 75,
	units = {
		{count = 2, unit = "raptor_land_assault_basic_t4_v1"}
	}
})
addNewSquad({
	type = "special",
	minAnger = 75,
	units = {
		{count = 2, unit = "raptor_land_assault_basic_t4_v2"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 85,
	maxAnger = 1000,
	units = {
		{count = 5, unit = "raptor_land_assault_basic_t4_v1"}
	}
})
addNewSquad({
	type = "special",
	minAnger = 85,
	maxAnger = 1000,
	units = {
		{count = 5, unit = "raptor_land_assault_basic_t4_v2"}
	}
})


addNewSquad({
	type = "special",
	minAnger = 50,
	weight = 2,
	units = {
		{count = 3, unit = "raptor_allterrain_assault_basic_t2_v1"}
	}
})
addNewSquad({
	type = "special",
	minAnger = 50,
	weight = 2,
	units = {
		{count = 3, unit = "raptor_allterrain_assault_basic_t2_v2"}
	}
})
addNewSquad({
	type = "special",
	minAnger = 50,
	weight = 2,
	units = {
		{count = 3, unit = "raptor_allterrain_assault_basic_t2_v3"}
	}
})


addNewSquad({
	type = "special",
	minAnger = 80,
	units = {
		{count = 2, unit = "raptor_allterrain_assault_basic_t4_v1"}
	}
})
addNewSquad({
	type = "special",
	minAnger = 80,
	units = {
		{count = 2, unit = "raptor_allterrain_assault_basic_t4_v2"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 90,
	units = {
		{count = 2, unit = "raptor_allterrain_assault_basic_t4_v1"}
	}
})
addNewSquad({
	type = "special",
	minAnger = 90,
	units = {
		{count = 2, unit = "raptor_allterrain_assault_basic_t4_v2"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 100,
	maxAnger = 1000,
	units = {
		{count = 5, unit = "raptor_allterrain_assault_basic_t4_v1"}
	}
})
addNewSquad({
	type = "special",
	minAnger = 100,
	maxAnger = 1000,
	units = {
		{count = 5, unit = "raptor_allterrain_assault_basic_t4_v2"}
	}
})


addNewSquad({
	type = "special",
	minAnger = 50,
	units = {
		{count = 3, unit = "raptor_land_assault_spectre_t2_v1"}
	}
})


addNewSquad({
	type = "special",
	minAnger = 80,
	units = {
		{count = 4, unit = "raptor_land_assault_spectre_t4_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 90,
	units = {
		{count = 4, unit = "raptor_land_assault_spectre_t4_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 100,
	maxAnger = 1000,
	units = {
		{count = 10, unit = "raptor_land_assault_spectre_t4_v1"}
	}
})


addNewSquad({
	type = "special",
	minAnger = 60,
	units = {
		{count = 3, unit = "raptor_land_assault_emp_t2_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 100,
	maxAnger = 1000,
	units = {
		{count = 5, unit = "raptor_land_assault_emp_t2_v1"}
	}
})


addNewSquad({
	type = "special",
	minAnger = 70,
	units = {
		{count = 3, unit = "raptor_land_assault_acid_t2_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 100,
	maxAnger = 1000,
	units = {
		{count = 5, unit = "raptor_land_assault_acid_t2_v1"}
	}
})


addNewSquad({
	type = "special",
	minAnger = 60,
	units = {
		{count = 3, unit = "raptor_allterrain_assault_emp_t2_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 100,
	maxAnger = 1000,
	units = {
		{count = 5, unit = "raptor_allterrain_assault_emp_t2_v1"}
	}
})


addNewSquad({
	type = "special",
	minAnger = 70,
	units = {
		{count = 3, unit = "raptor_allterrain_assault_acid_t2_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 100,
	maxAnger = 1000,
	units = {
		{count = 5, unit = "raptor_allterrain_assault_acid_t2_v1"}
	}
})


addNewSquad({
	type = "special",
	minAnger = 50,
	weight = 2,
	units = {
		{count = 3, unit = "raptor_land_assault_basic_t2_v1"},
		{count = 3, unit = "raptor_land_assault_spectre_t2_v1"}
	}
})
addNewSquad({
	type = "special",
	minAnger = 50,
	weight = 2,
	units = {
		{count = 3, unit = "raptor_land_assault_basic_t2_v2"},
		{count = 3, unit = "raptor_land_assault_spectre_t2_v1"}
	}
})
addNewSquad({
	type = "special",
	minAnger = 50,
	weight = 2,
	units = {
		{count = 3, unit = "raptor_land_assault_basic_t2_v3"},
		{count = 3, unit = "raptor_land_assault_spectre_t2_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 80,
	units ={
		{count = 1, unit = "raptor_land_assault_basic_t4_v1"},
		{count = 2, unit = "raptor_land_assault_spectre_t4_v1"}
	}
})
addNewSquad({
	type = "special",
	minAnger = 80,
	units ={
		{count = 1, unit = "raptor_land_assault_basic_t4_v2"},
		{count = 2, unit = "raptor_land_assault_spectre_t4_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 90,
	units = {
		{count = 1, unit = "raptor_land_assault_basic_t4_v1"},
		{count = 2, unit = "raptor_land_assault_spectre_t4_v1"}
	}
})
addNewSquad({
	type = "special",
	minAnger = 90,
	units = {
		{count = 1, unit = "raptor_land_assault_basic_t4_v2"},
		{count = 2, unit = "raptor_land_assault_spectre_t4_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 100,
	maxAnger = 1000,
	units = {
		{count = 3, unit = "raptor_land_assault_basic_t4_v1"},
		{count = 2, unit = "raptor_land_assault_spectre_t4_v1"}
	}
})
addNewSquad({
	type = "special",
	minAnger = 100,
	maxAnger = 1000,
	units = {
		{count = 3, unit = "raptor_land_assault_basic_t4_v2"},
		{count = 2, unit = "raptor_land_assault_spectre_t4_v1"}
	}
})

--Spikers------------------------------------------------------------------------------------------------------

addNewSquad({
	type = "special",
	minAnger = 10,
	maxAnger = 30,
	units = {
		{count = 1, unit = "raptor_land_spiker_basic_t2_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 30, 
	weight = 3,
	units = {
		{count = 5, unit = "raptor_land_spiker_basic_t2_v1"}
	}
})


addNewSquad({
	type = "special",
	minAnger = 60,
	weight = 2,
	units = {
		{count = 10, unit = "raptor_land_spiker_basic_t4_v1" }
	}
})

addNewSquad({
	type = "special",
	weight = 2,
	minAnger = 100,
	maxAnger = 1000,
	units = {
		{count = 10, unit = "raptor_land_spiker_basic_t4_v1" }
	}
})


addNewSquad({
	type = "special",
	minAnger = 70,
	units = {
		{count = 10, unit = "raptor_land_spiker_spectre_t4_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 100,
	maxAnger = 1000,
	units = {
		{count = 10, unit = "raptor_land_spiker_spectre_t4_v1"}
	}
})


addNewSquad({
	type = "special",
	minAnger = 70,
	units = {
		{count = 5, unit = "raptor_land_spiker_basic_t4_v1"},
		{count = 5, unit = "raptor_land_spiker_spectre_t4_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 100,
	maxAnger = 1000,
	units = {
		{count = 5, unit = "raptor_land_spiker_basic_t4_v1"},
		{count = 5, unit = "raptor_land_spiker_spectre_t4_v1"}
	}
})

--Kamikaze------------------------------------------------------------------------------------------------------

addNewSquad({
	type = "special",
	minAnger = 40,
	units = {
		{count = 15, unit = "raptor_land_kamikaze_basic_t2_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 70,
	units = {
		{count = 25, unit = "raptor_land_kamikaze_basic_t4_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 100,
	maxAnger = 1000,
	units = {
		{count = 25, unit = "raptor_land_kamikaze_basic_t4_v1"}
	}
})


addNewSquad({
	type = "special",
	minAnger = 30,
	units = {
		{count = 15, unit = "raptor_land_kamikaze_emp_t2_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 60,
	units = {
		{count = 25, unit = "raptor_land_kamikaze_emp_t4_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 100,
	maxAnger = 1000,
	units = {
		{count = 25, unit = "raptor_land_kamikaze_emp_t4_v1"}
	}
})


addNewSquad({
	type = "special",
	minAnger = 40,
	units = {
		{count = 10, unit = "raptor_land_kamikaze_basic_t2_v1"},
		{count = 10, unit = "raptor_land_kamikaze_emp_t2_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 70,
	units = {
		{count = 20, unit = "raptor_land_kamikaze_basic_t4_v1"},
		{count = 20, unit = "raptor_land_kamikaze_emp_t4_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 100,
	maxAnger = 1000,
	units = {
		{count = 20, unit = "raptor_land_kamikaze_basic_t4_v1"},
		{count = 20, unit = "raptor_land_kamikaze_emp_t4_v1"}
	}
})

--Flamers------------------------------------------------------------------------------------------------------

addNewSquad({
	type = "special",
	minAnger = 0,
	maxAnger = 20,
	units = {
		{count = 1, unit = "raptor_land_swarmer_fire_t2_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 20,
	units = {
		{count = 5, unit = "raptor_land_swarmer_fire_t2_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 30,
	units = {
		{count = 10, unit = "raptor_land_swarmer_fire_t2_v1"}
	}
})


addNewSquad({
	type = "special",
	minAnger = 50,
	units = {
		{count = 10, unit = "raptor_allterrain_swarmer_fire_t2_v1"}
	}
})


addNewSquad({
	type = "special",
	minAnger = 60,
	units = {
		{count = 8, unit = "raptor_land_swarmer_fire_t4_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 100,
	maxAnger = 1000,
	units ={
		{count = 10, unit = "raptor_land_swarmer_fire_t4_v1"}
	}
})

--Artillery------------------------------------------------------------------------------------------------------

addNewSquad({
	type = "special",
	minAnger = 20,
	maxAnger = 50,
	units = {
		{count = 1, unit = "raptor_allterrain_arty_basic_t2_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 50,
	weight = 3,
	units = {
		{count = 3, unit = "raptor_allterrain_arty_basic_t2_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 80,
	weight = 3,
	units = {
		{count = 3, unit = "raptor_allterrain_arty_basic_t2_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 90,
	weight = 3,
	units = {
		{count = 3, unit = "raptor_allterrain_arty_basic_t2_v1"}
	}
})

addNewSquad({
	type = "special",
	weight = 3,
	minAnger = 100,
	maxAnger = 1000,
	units = {
		{count = 3, unit = "raptor_allterrain_arty_basic_t2_v1"}
	}
})


addNewSquad({
	type = "special",
	minAnger = 70,
	units = {
		{count = 1, unit = "raptor_allterrain_arty_basic_t4_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 80,
	units = {
		{count = 1, unit = "raptor_allterrain_arty_basic_t4_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 90,
	units = {
		{count = 1, unit = "raptor_allterrain_arty_basic_t4_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 100,
	maxAnger = 1000,
	units = {
		{count = 2, unit = "raptor_allterrain_arty_basic_t4_v1"}
	}
})


addNewSquad({
	type = "special",
	minAnger = 20,
	maxAnger = 50,
	units = {
		{count = 1, unit = "raptor_allterrain_arty_acid_t2_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 50,
	units = {
		{count = 3, unit = "raptor_allterrain_arty_acid_t2_v1"}}
	}
)

addNewSquad({
	type = "special",
	minAnger = 100,
	maxAnger = 1000,
	units = {
		{count = 3, unit = "raptor_allterrain_arty_acid_t2_v1"}
	}
})


addNewSquad({
	type = "special",
	minAnger = 70,
	units = {
		{count = 1, unit = "raptor_allterrain_arty_acid_t4_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 80,
	units = {
		{count = 1, unit = "raptor_allterrain_arty_acid_t4_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 90,
	units = {
		{count = 1, unit = "raptor_allterrain_arty_acid_t4_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 100,
	maxAnger = 1000,
	units = {
		{count = 2, unit = "raptor_allterrain_arty_acid_t4_v1"}
	}
})


addNewSquad({
	type = "special",
	minAnger = 20,
	maxAnger = 50,
	units = {
		{count = 1, unit = "raptor_allterrain_arty_emp_t2_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 50,
	units = {
		{count = 3, unit = "raptor_allterrain_arty_emp_t2_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 100,
	maxAnger = 1000,
	units = {
		{count = 3, unit = "raptor_allterrain_arty_emp_t2_v1"}
	}
})


addNewSquad({
	type = "special",
	minAnger = 70,
	units = {
		{count = 1, unit = "raptor_allterrain_arty_emp_t4_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 80,
	units = {
		{count = 1, unit = "raptor_allterrain_arty_emp_t4_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 90,
	units = {
		{count = 1, unit = "raptor_allterrain_arty_emp_t4_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 100,
	maxAnger = 1000,
	units = {
		{count = 2, unit = "raptor_allterrain_arty_emp_t4_v1"}
	}
})


addNewSquad({
	type = "special",
	minAnger = 50,
	units = {
		{count = 3, unit = "raptor_allterrain_arty_brood_t2_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 100,
	maxAnger = 1000,
	units = {
		{count = 3, unit = "raptor_allterrain_arty_brood_t2_v1"}
	}
})


addNewSquad({
	type = "special",
	minAnger = 70,
	units ={{count = 1, unit = "raptor_allterrain_arty_brood_t4_v1"}
}
})

addNewSquad({
	type = "special",
	minAnger = 80,
	units ={{count = 1, unit = "raptor_allterrain_arty_brood_t4_v1"}
}
})

addNewSquad({
	type = "special",
	minAnger = 90,
	units ={{count = 1, unit = "raptor_allterrain_arty_brood_t4_v1"}
}
})

addNewSquad({
	type = "special",
	minAnger = 100,
	maxAnger = 1000,
	units = {
		{count = 2, unit = "raptor_allterrain_arty_brood_t4_v1"}
	}
})

--Brood------------------------------------------------------------------------------------------------------

addNewSquad({
	type = "special",
	minAnger = 20,
	units = {
		{count = 2, unit = "raptor_land_swarmer_brood_t2_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 40,
	units = {
		{count = 4, unit = "raptor_land_swarmer_brood_t2_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 60,
	units = {
		{count = 8, unit = "raptor_land_swarmer_brood_t2_v1"}
	}
})

addNewSquad({ 
	type = "special",
	minAnger = 80,
	units = { 
		{count = 16, unit = "raptor_land_swarmer_brood_t2_v1"}
	}
})

addNewSquad({ 
	type = "special",
	minAnger = 100,
	maxAnger = 1000,
	units = {
		{count = 32, unit = "raptor_land_swarmer_brood_t2_v1"}
	},
})


addNewSquad({
	type = "special",
	minAnger = 20,
	units = {
		{count = 1, unit = "raptor_land_swarmer_brood_t3_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 40,
	units = {
		{count = 2, unit = "raptor_land_swarmer_brood_t3_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 60,
	units = {
		{count = 4, unit = "raptor_land_swarmer_brood_t3_v1"}
	}
})

addNewSquad({
type = "special",
minAnger = 80,
	units = {
		{count = 8, unit = "raptor_land_swarmer_brood_t3_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 100,
	maxAnger = 1000,
	units = {
		{count = 16, unit = "raptor_land_swarmer_brood_t3_v1"}
	}
})


addNewSquad({
	type = "special",
	minAnger = 40,
	units = {
		{count =1, unit = "raptor_land_swarmer_brood_t4_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 60,
	units = {
		{count =2, unit = "raptor_land_swarmer_brood_t4_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 80,
	units = {
		{count =4, unit = "raptor_land_swarmer_brood_t4_v1"}
	}
})

addNewSquad({
	type = "special",
	minAnger = 100,
	maxAnger = 1000,
	units = {
		{count = 8, unit = "raptor_land_swarmer_brood_t4_v1"}
	}
})

--Matriarchs------------------------------------------------------------------------------------------------------

for j = 1, #miniBosses do
	addNewSquad({ 
		type = "special",
		minAnger = 70,
		units = { 
			{count = 1, unit = miniBosses[j]}
		},
		maxAnger = 1000
	})
	addNewSquad({ 
		type = "special",
		minAnger = 85,
		units = { 
			{count = 1, unit = miniBosses[j]}
		},
		maxAnger = 1000
	})
	addNewSquad({ 
		type = "special",
		minAnger = 100,
		units = { 
			{count = 1, unit = miniBosses[j]}
		},
		maxAnger = 1000
	})
end

---------------------------------------------
-- Air --------------------------------------
---------------------------------------------

local airStartAnger = 0 -- needed for air waves to work correctly.
--Scouts------------------------------------------------------------------------------------------------------

addNewSquad({
	type = "basicAir",
	weight = 10,
	minAnger = 0,
	maxAnger = 20,
	units = {
		{count = 3, unit = "raptor_air_scout_basic_t2_v1"}
	}
})

addNewSquad({
	type = "basicAir",
	minAnger = 20,
	maxAnger = 40,
	units = {
		{count = 1, unit = "raptor_air_scout_basic_t2_v1"}
	}
})

addNewSquad({
	type = "basicAir",
	minAnger = 33,
	maxAnger = 80,
	units = {
		{count = 1, unit = "raptor_air_scout_basic_t3_v1"}
	}
})

addNewSquad({
	type = "basicAir",
	minAnger = 66,
	maxAnger = 1000,
	units = {
		{count = 1, unit = "raptor_air_scout_basic_t4_v1"}
	}
})

--Fighters------------------------------------------------------------------------------------------------------

addNewSquad({
	type = "basicAir",
	minAnger = 0,
	maxAnger = 20,
	units = {
		{count = 1, unit = "raptor_air_fighter_basic_t1_v1"}
	}
})

addNewSquad({
	type = "basicAir",
	minAnger = 20,
	maxAnger = 60,
	units = {
		{count = 4, unit = "raptor_air_fighter_basic_t1_v1"}
	}
})


addNewSquad({
	type = "basicAir",
	minAnger = 40,
	units = {
		{count = 4, unit = "raptor_air_fighter_basic_t2_v1"}
	}
})
addNewSquad({
	type = "basicAir",
	minAnger = 40,
	units = {
		{count = 4, unit = "raptor_air_fighter_basic_t2_v2"}
	}
})
addNewSquad({
	type = "basicAir",
	minAnger = 40,
	units = {
		{count = 4, unit = "raptor_air_fighter_basic_t2_v3"}
	}
})
addNewSquad({
type = "basicAir",
minAnger = 40,
	units = {
		{count = 4, unit = "raptor_air_fighter_basic_t2_v4"}
	}
})

addNewSquad({
	type = "basicAir",
	minAnger = 60,
	units = {
		{count = 4, unit = "raptor_air_fighter_basic_t2_v1"}
	}
})
addNewSquad({
	type = "basicAir",
	minAnger = 60,
	units = {
		{count = 4, unit = "raptor_air_fighter_basic_t2_v2"}
	}
})
addNewSquad({
	type = "basicAir",
	minAnger = 60,
	units = {
		{count = 4, unit = "raptor_air_fighter_basic_t2_v3"}
	}
})
addNewSquad({
type = "basicAir",
minAnger = 60,
	units = {
		{count = 4, unit = "raptor_air_fighter_basic_t2_v4"}
	}
})


addNewSquad({
	type = "basicAir",
	weight = 2,
	minAnger = 80,
	units = {
		{count = 6, unit = "raptor_air_fighter_basic_t4_v1"}
	}
})

addNewSquad({
	type = "basicAir",
	weight = 2,
	minAnger = 100,
	maxAnger = 1000,
	units = {
		{count = 8, unit = "raptor_air_fighter_basic_t4_v1"}
	}
})

--Bombers------------------------------------------------------------------------------------------------------

addNewSquad({
	type = "basicAir",
	minAnger = 0,
	maxAnger = 20,
	units = {
		{count = 1, unit = "raptor_air_bomber_basic_t1_v1"}
	}
})

addNewSquad({
	type = "basicAir",
	minAnger = 20,
	maxAnger = 60,
	units = {
		{count = 4, unit = "raptor_air_bomber_basic_t1_v1"}
	}
})


addNewSquad({
	type = "basicAir",
	minAnger = 40,
	weight = 2,
	units = {
		{count = 4, unit = "raptor_air_bomber_basic_t2_v1"}
	}
})
addNewSquad({
	type = "basicAir",
	minAnger = 40,
	weight = 2,
	units = {
		{count = 4, unit = "raptor_air_bomber_basic_t2_v2"}
	}
})

addNewSquad({
	type = "basicAir",
	minAnger = 60,
	weight = 2,
	units = {
		{count = 4, unit = "raptor_air_bomber_basic_t2_v1"}
	}
})
addNewSquad({
	type = "basicAir",
	minAnger = 60,
	weight = 2,
	units = {
		{count = 4, unit = "raptor_air_bomber_basic_t2_v2"}
	}
})


addNewSquad({
	type = "basicAir",
	minAnger = 80,
	units = {
		{count = 2, unit = "raptor_air_bomber_basic_t4_v1"}
	}
})
addNewSquad({
	type = "basicAir",
	minAnger = 80,
	units = {
		{count = 2, unit = "raptor_air_bomber_basic_t4_v2"}
	}
})

addNewSquad({
	type = "basicAir",
	minAnger = 100,
	maxAnger = 1000,
	units = {
		{count = 3, unit = "raptor_air_bomber_basic_t4_v1"}
	}
})
addNewSquad({
	type = "basicAir",
	minAnger = 100,
	maxAnger = 1000,
	units = {
		{count = 3, unit = "raptor_air_bomber_basic_t4_v2"}
	}
})


addNewSquad({
	type = "specialAir",
	minAnger = 50,
	units = {
		{count = 1, unit = "raptor_air_bomber_emp_t2_v1" }
	}
})

addNewSquad({
	type = "specialAir",
	minAnger = 60,
	units = {
		{count = 2, unit = "raptor_air_bomber_emp_t2_v1" }
	}
})

addNewSquad({
	type = "specialAir",
	minAnger = 70,
	units = {
		{count = 4, unit = "raptor_air_bomber_emp_t2_v1" }
	}
})

addNewSquad({
	type = "specialAir",
	minAnger = 80,
	units = {
		{count = 6, unit = "raptor_air_bomber_emp_t2_v1" }
	}
})

addNewSquad({
	type = "specialAir",
	minAnger = 90,
	maxAnger = 1000,
	units = {
		{count = 8, unit = "raptor_air_bomber_emp_t2_v1" }
	}
})


addNewSquad({
	type = "specialAir",
	minAnger = 50,
	units = {
		{count = 1, unit = "raptor_air_bomber_acid_t2_v1"}
	}
})

addNewSquad({
	type = "specialAir",
	minAnger = 70,
	units = {
		{count = 4, unit = "raptor_air_bomber_acid_t2_v1"}
	}
})

addNewSquad({
	type = "specialAir",
	minAnger = 90,
	maxAnger = 1000,
	units = {
	{count = 8, unit = "raptor_air_bomber_acid_t2_v1"}
	}
})


addNewSquad({
	type = "specialAir",
	minAnger = 50,
	units = {
		{count = 1, unit = "raptor_air_bomber_brood_t4_v4"}
	}
})

addNewSquad({
	type = "specialAir",
	minAnger = 70,
	units = {
		{count = 1, unit = "raptor_air_bomber_brood_t4_v3"}
	}
})
addNewSquad({
	type = "specialAir",
	minAnger = 70,
	units = {
		{count = 2, unit = "raptor_air_bomber_brood_t4_v4"}
	}
})

addNewSquad({
	type = "specialAir",
	minAnger = 90,
	units = {
		{count = 1, unit = "raptor_air_bomber_brood_t4_v2"}
	}
})
addNewSquad({
	type = "specialAir",
	minAnger = 90,
	units = {
		{count = 2, unit = "raptor_air_bomber_brood_t4_v3"}
	}
})
addNewSquad({
	type = "specialAir",
	minAnger = 90,
	units = {
		{count = 4, unit = "raptor_air_bomber_brood_t4_v4"}
	}
})

addNewSquad({
	type = "specialAir",
	minAnger = 100,
	maxAnger = 1000,
	units = {
		{count = 4, unit = "raptor_air_bomber_brood_t4_v4"}
	}
})
addNewSquad({
	type = "specialAir",
	minAnger = 100,
	maxAnger = 1000,
	units = {
		{count = 4, unit = "raptor_air_bomber_brood_t4_v3"}
	}
})
addNewSquad({
	type = "specialAir",
	minAnger = 100,
	maxAnger = 1000,
	units = {
		{count = 4, unit = "raptor_air_bomber_brood_t4_v2"}
	}
})

--Kamikaze------------------------------------------------------------------------------------------------------

-- addNewSquad({ type = "specialAir", minAnger = 70, units = { "10 raptor_air_kamikaze_basic_t2_v1" } })

-- addNewSquad({ type = "specialAir", minAnger = 90, units = { "10 raptor_air_kamikaze_basic_t2_v1" } })

-- addNewSquad({ type = "specialAir", minAnger = 100, units = { "10 raptor_air_kamikaze_basic_t2_v1" }, maxAnger = 1000 })

------------------------------------------------
-- Healer --------------------------------------
------------------------------------------------

addNewSquad({
	type = "healer",
	minAnger = 0,
	maxAnger = 35,
	units = {
		{count = 1, unit = "raptor_land_swarmer_heal_t1_v1"}
	},
})

addNewSquad({
	type = "healer",
	minAnger = 25,
	maxAnger = 60,
	units = {
		{count = 2, unit = "raptor_land_swarmer_heal_t1_v1"}
	}
})
addNewSquad({
	type = "healer",
	minAnger = 25,
	maxAnger = 60,
	units = {
		{count = 1, unit = "raptor_land_swarmer_heal_t2_v1"}
	}
})

addNewSquad({
	type = "healer",
	minAnger = 50,
	maxAnger = 85,
	units = {
		{count = 4, unit = "raptor_land_swarmer_heal_t1_v1"}
	}
})
addNewSquad({
	type = "healer",
	minAnger = 50,
	maxAnger = 85,
	units = {
		{count = 2, unit = "raptor_land_swarmer_heal_t2_v1"}
	}
})
addNewSquad({
	type = "healer",
	minAnger = 50,
	maxAnger = 85,
	units = {
		{count = 1, unit = "raptor_land_swarmer_heal_t3_v1"}
	}
})

addNewSquad({
	type = "healer",
	minAnger = 75,
	maxAnger = 100,
	units = {
		{count = 8, unit = "raptor_land_swarmer_heal_t1_v1"}
	}
})
addNewSquad({
	type = "healer",
	minAnger = 75,
	maxAnger = 200,
	units = {
		{count = 4, unit = "raptor_land_swarmer_heal_t2_v1"}
	}
})
addNewSquad({
	type = "healer",
	minAnger = 75,
	maxAnger = 300,
	units = {
		{count = 2, unit = "raptor_land_swarmer_heal_t3_v1"}
	}
})
addNewSquad({
	type = "healer",
	minAnger = 75,
	maxAnger = 400,
	units = {
		{count = 1, unit = "raptor_land_swarmer_heal_t4_v1"}
	}
})

addNewSquad({
	type = "healer",
	minAnger = 100,
	maxAnger = 300,
	units = {
		{count = 8, unit = "raptor_land_swarmer_heal_t2_v1"}
	}
})
addNewSquad({
	type = "healer",
	minAnger = 100,
	maxAnger = 400,
	units = {
		{count = 4, unit = "raptor_land_swarmer_heal_t3_v1"}
	}
})
addNewSquad({
	type = "healer",
	minAnger = 100,
	maxAnger = 500,
	units = {
		{count = 2, unit = "raptor_land_swarmer_heal_t4_v1"}
	}
})

addNewSquad({
	type = "healer",
	minAnger = 125,
	maxAnger = 500,
	units = {
		{count = 8, unit = "raptor_land_swarmer_heal_t3_v1"}
	}
})
addNewSquad({
	type = "healer",
	minAnger = 125,
	maxAnger = 600,
	units = {
		{count = 4, unit = "raptor_land_swarmer_heal_t4_v1"}
	}
})

addNewSquad({
	type = "healer",
	minAnger = 150,
	maxAnger = 1000,
	units = {
		{count = 8, unit = "raptor_land_swarmer_heal_t4_v1"}
	}
})

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Settings -- Adjust these
local useEggs = true -- Drop eggs (requires egg features from Beyond All Reason)
local useScum = true -- Use scum as space where turrets can spawn (requires scum gadget from Beyond All Reason)
local useWaveMsg = true -- Show dropdown message whenever new wave is spawning
local spawnSquare = 90 -- size of the raptor spawn square centered on the burrow
local spawnSquareIncrement = 2 -- square size increase for each unit spawned
local burrowSize = 144
local bossFightWaveSizeScale = 10 -- Percentage
local defaultRaptorFirestate = 3 -- 0 - Hold Fire | 1 - Return Fire | 2 - Fire at Will | 3 - Fire at everything

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
	[UnitDefNames["armageo"].id] 	= 0.000125,
	[UnitDefNames["corageo"].id] 	= 0.000125,
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

local config = { -- Don't touch this! ---------------------------------------------------------------------------------------------------------------------------------------------
	useEggs 				= useEggs,
	useScum					= useScum,
	difficulty             	= difficulty,
	difficulties           	= difficulties,
	raptorEggs			   	= table.copy(raptorEggs),
	burrowName             	= burrowName,   -- burrow unit name
	burrowDef              	= UnitDefNames[burrowName] and UnitDefNames[burrowName].id,
	raptorSpawnMultiplier 	= Spring.GetModOptions().raptor_spawncountmult,
	burrowSpawnType        	= Spring.GetModOptions().raptor_raptorstart,
	swarmMode			   	= Spring.GetModOptions().raptor_swarmmode,
	spawnSquare            	= spawnSquare,
	spawnSquareIncrement   	= spawnSquareIncrement,
	raptorTurrets			= table.copy(raptorTurrets),
	miniBosses			   	= miniBosses,
	raptorMinions			= raptorMinions,
	raptorBehaviours 		= raptorBehaviours,
	difficultyParameters   	= optionValues,
	useWaveMsg 				= useWaveMsg,
	burrowSize 				= burrowSize,
	squadSpawnOptionsTable	= squadSpawnOptionsTable,
	airStartAnger			= airStartAnger,
	ecoBuildingsPenalty		= ecoBuildingsPenalty,
	bossFightWaveSizeScale  = bossFightWaveSizeScale,
	defaultRaptorFirestate = defaultRaptorFirestate,
	economyScale			= economyScale,
}

for key, value in pairs(optionValues[difficulty]) do
	config[key] = value
end

return config
