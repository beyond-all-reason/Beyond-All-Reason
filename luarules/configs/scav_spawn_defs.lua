
local difficulties = {
	veryeasy = 1,
	easy 	 = 2,
	normal   = 3,
	hard     = 4,
	veryhard = 5,
	epic     = 6,
	--survival = 6,
}

local difficulty = difficulties[Spring.GetModOptions().scav_difficulty]

local difficultyParameters = {

	[difficulties.veryeasy] = {
		gracePeriod       		= 1 * Spring.GetModOptions().scav_graceperiodmult * 60,
		bossTime      	  		= 65 * Spring.GetModOptions().scav_bosstimemult * 60, -- time at which the boss appears, frames
		scavSpawnRate   		= 240 * Spring.GetModOptions().scav_spawntimemult,
		burrowSpawnRate   		= 240 * Spring.GetModOptions().scav_spawntimemult,
		turretSpawnRate   		= 500 * Spring.GetModOptions().scav_spawntimemult,
		bossSpawnMult    		= 1,
		angerBonus        		= 0.1,
		maxXP			  		= 0.1,
		spawnChance       		= 0.1,
		damageMod         		= 0.5,
		maxBurrows        		= 1000,
		minScavs		  		= 5,
		maxScavs		  		= 15,
		scavPerPlayerMultiplier = 0.25,
		bossName         		= 'armscavengerbossv2_veryeasy_scav',
		bossResistanceMult   	= 1,
	},

	[difficulties.easy] = {
		gracePeriod       		= 1 * Spring.GetModOptions().scav_graceperiodmult * 60,
		bossTime      	  		= 60 * Spring.GetModOptions().scav_bosstimemult * 60, -- time at which the boss appears, frames
		scavSpawnRate   		= 200 * Spring.GetModOptions().scav_spawntimemult,
		burrowSpawnRate   		= 210 * Spring.GetModOptions().scav_spawntimemult,
		turretSpawnRate   		= 420 * Spring.GetModOptions().scav_spawntimemult,
		bossSpawnMult    		= 1,
		angerBonus        		= 0.15,
		maxXP			  		= 0.2,
		spawnChance       		= 0.2,
		damageMod         		= 0.75,
		maxBurrows        		= 1000,
		minScavs		  		= 10,
		maxScavs		  		= 20,
		scavPerPlayerMultiplier = 0.25,
		bossName         		= 'armscavengerbossv2_easy_scav',
		bossResistanceMult   	= 1.5,
	},
	[difficulties.normal] = {
		gracePeriod       		= 1 * Spring.GetModOptions().scav_graceperiodmult * 60,
		bossTime      	  		= 55 * Spring.GetModOptions().scav_bosstimemult * 60, -- time at which the boss appears, frames
		scavSpawnRate   		= 180 * Spring.GetModOptions().scav_spawntimemult,
		burrowSpawnRate   		= 180 * Spring.GetModOptions().scav_spawntimemult,
		turretSpawnRate   		= 380 * Spring.GetModOptions().scav_spawntimemult,
		bossSpawnMult    		= 3,
		angerBonus        		= 0.2,
		maxXP			  		= 0.3,
		spawnChance       		= 0.3,
		damageMod         		= 1,
		maxBurrows        		= 1000,
		minScavs		  		= 15,
		maxScavs		  		= 25,
		scavPerPlayerMultiplier = 0.25,
		bossName         		= 'armscavengerbossv2_normal_scav',
		bossResistanceMult  	= 2,
	},
	[difficulties.hard] = {
		gracePeriod       		= 1 * Spring.GetModOptions().scav_graceperiodmult * 60,
		bossTime      	  		= 50 * Spring.GetModOptions().scav_bosstimemult * 60, -- time at which the boss appears, frames
		scavSpawnRate   		= 160 * Spring.GetModOptions().scav_spawntimemult,
		burrowSpawnRate   		= 150 * Spring.GetModOptions().scav_spawntimemult,
		turretSpawnRate   		= 340 * Spring.GetModOptions().scav_spawntimemult,
		bossSpawnMult    		= 3,
		angerBonus        		= 0.25,
		maxXP			  		= 0.4,
		spawnChance       		= 0.4,
		damageMod         		= 1.25,
		maxBurrows        		= 1000,
		minScavs		  		= 20,
		maxScavs		  		= 30,
		scavPerPlayerMultiplier = 0.25,
		bossName         		= 'armscavengerbossv2_hard_scav',
		bossResistanceMult   	= 2.5,
	},
	[difficulties.veryhard] = {
		gracePeriod       		= 1 * Spring.GetModOptions().scav_graceperiodmult * 60,
		bossTime      	  		= 45 * Spring.GetModOptions().scav_bosstimemult * 60, -- time at which the boss appears, frames
		scavSpawnRate  			= 140 * Spring.GetModOptions().scav_spawntimemult,
		burrowSpawnRate   		= 120 * Spring.GetModOptions().scav_spawntimemult,
		turretSpawnRate   		= 320 * Spring.GetModOptions().scav_spawntimemult,
		bossSpawnMult    		= 3,
		angerBonus        		= 0.30,
		maxXP			  		= 0.5,
		spawnChance       		= 0.5,
		damageMod         		= 1.5,
		maxBurrows        		= 1000,
		minScavs		  		= 25,
		maxScavs		  		= 35,
		scavPerPlayerMultiplier = 0.25,
		bossName         		= 'armscavengerbossv2_veryhard_scav',
		bossResistanceMult   	= 3,
	},
	[difficulties.epic] = {
		gracePeriod       		= 1 * Spring.GetModOptions().scav_graceperiodmult * 60,
		bossTime      	  		= 40 * Spring.GetModOptions().scav_bosstimemult * 60, -- time at which the boss appears, frames
		scavSpawnRate   		= 120 * Spring.GetModOptions().scav_spawntimemult,
		burrowSpawnRate   		= 90 * Spring.GetModOptions().scav_spawntimemult,
		turretSpawnRate   		= 260 * Spring.GetModOptions().scav_spawntimemult,
		bossSpawnMult    		= 3,
		angerBonus        		= 0.35,
		maxXP			  		= 0.6,
		spawnChance       		= 0.6,
		damageMod         		= 2,
		maxBurrows        		= 1000,
		minScavs		  		= 30,
		maxScavs		  		= 40,
		scavPerPlayerMultiplier = 0.25,
		bossName         		= 'armscavengerbossv2_epic_scav',
		bossResistanceMult   	= 3.5,
	},

}

--[[
	So here we define lists of units from which behaviours tables and spawn tables are created dynamically.
	We're setting up 7 levels representing the below:

	Level 1 and 2 - Tech 0 - very early game crap, stuff that players usually build first in their games. pawns and grunts, scouts, etc.
	Level 3 - Tech 1 - at this point we're introducing what remains of T1, basically late stage T1, but it's not T2 yet
	Level 4 - Tech 2 - early/cheap Tech 2 units. we're putting expensive T2's later for smoother progression
	Level 5 - Tech 2.5 - Here we're introducing all the expensive late T2 equipment.
	Level 6 - Tech 3 - Here we introduce the cheaper T3 units
	Level 7 - Tech 3.5/Tech 4 - The most expensive units in the game, spawned in the endgame, right before and alongside the final boss

	Now that we talked about tiers, let's talk about roles.
	There will be 3 of these for Land and Sea, and only one for Air because there we don't really introduce any behaviours. They're just sent to enemy on fight command.

	Raid - Quick and harrassing, these have no behaviours attached, they just rush in and act as cannon fodder and distraction.
	Assault - Main combat force. These will focus on attacking what attacks them, pushing in and taking damage
	Support - Long range units dealing damage or utility roles from afar. These will run away from you when they take damage.
	MAKE SURE NOT TO PUT THE SAME UNIT IN 2 TABLES.

	Numbers assigned to units is weight. Higher weight makes this unit spawn more often than others.

	There's also list of turrets which works in a bit different way.
	While it follows the 6 levels, the table is structured differently. You can set maximum of this turret you want to be spawned.
]]

local tierConfiguration = { -- Double everything for basic squads
	[1] = {minAnger = 0,  maxAnger = 10, 	maxSquadSize = 1},
	[2] = {minAnger = 10, maxAnger = 25, 	maxSquadSize = 13},
	[3] = {minAnger = 20, maxAnger = 45, 	maxSquadSize = 11},
	[4] = {minAnger = 35, maxAnger = 65, 	maxSquadSize = 9},
	[5] = {minAnger = 45, maxAnger = 85, 	maxSquadSize = 7},
	[6] = {minAnger = 60, maxAnger = 500, 	maxSquadSize = 5},
	[7] = {minAnger = 80, maxAnger = 1000, 	maxSquadSize = 3},
}

----------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------

local BurrowUnitsList = {
	['scavbeacon_t1_scav'] = {minAnger = tierConfiguration[1].minAnger, maxAnger = tierConfiguration[3].maxAnger},
	['scavbeacon_t2_scav'] = {minAnger = tierConfiguration[3].minAnger, maxAnger = tierConfiguration[5].maxAnger},
	['scavbeacon_t3_scav'] = {minAnger = tierConfiguration[5].minAnger, maxAnger = tierConfiguration[7].maxAnger},
	['scavbeacon_t4_scav'] = {minAnger = tierConfiguration[7].minAnger, maxAnger = tierConfiguration[7].maxAnger},
}

----------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------

local LandUnitsList = {
	Raid = {
		[1] = {
			--Armada
			["armflea_scav"] = 1,
			["armpw_scav"] = 1,
			["armfav_scav"] = 1,
			["armsh_scav"] = 1,
			--Cortex
			["corak_scav"] = 1,
			["corfav_scav"] = 1,
			["corsh_scav"] = 1,
			--Legion
			["leggob_scav"] = 1,
			["legsh_scav"] = 1,
		},
		[2] = {
			--Armada
			["armflea_scav"] = 1,
			["armpw_scav"] = 1,
			["armfav_scav"] = 1,
			["armsh_scav"] = 1,
			--Cortex
			["corak_scav"] = 1,
			["corfav_scav"] = 1,
			["corsh_scav"] = 1,
			--Legion
			["leggob_scav"] = 1,
			["legsh_scav"] = 1,
		},
		[3] = {
			--Armada
			["armflash_scav"] = 1,
			["armzapper_scav"] = 1,
			--Cortex
			["corgator_scav"] = 1,
			--Legion
			["leghades_scav"] = 1,
		},
		[4] = {
			--Armada
			["armlatnk_scav"] = 1,
			["armamph_scav"] = 1,
			["armfast_scav"] = 1,
			--Cortex
			["cortorch_scav"] = 1,
			["corsala_scav"] = 1,
			["corpyro_scav"] = 1,
			["corseal_scav"] = 1,
			["coramph_scav"] = 1,
			--Legion
			["legmrv_scav"] = 1,
			["legstr_scav"] = 1,
		},
		[5] = {
			--Armada

			--Cortex

			--Legion


		},
		[6] = {
			--Armada
			["armpwt4_scav"] = 1,
			["armmar_scav"] = 1,
			--Cortex
			["corakt4_scav"] = 1,
			--Legion
			--N/A
		},
		[7] = {
			--Armada
			["armraz_scav"] = 1,
			--Cortex
			["cordemon_scav"] = 1,
			--Legion
			--N/A
		},
	},
	Assault = {
		[1] = {
			--Armada
			["armham_scav"] = 1,
			["armpincer_scav"] = 1,
			--Cortex
			["corthud_scav"] = 1,
			["corgarp_scav"] = 1,
			--Legion
			["legcen_scav"] = 1,
			["leglob_scav"] = 1,
		},
		[2] = {
			--Armada
			["armham_scav"] = 1,
			["armpincer_scav"] = 1,
			--Cortex
			["corthud_scav"] = 1,
			["corgarp_scav"] = 1,
			--Legion
			["legcen_scav"] = 1,
			["leglob_scav"] = 1,
		},
		[3] = {
			--Armada
			["armwar_scav"] = 1,
			["armstump_scav"] = 1,
			["armjanus_scav"] = 1,
			["armanac_scav"] = 1,
			--Cortex
			["corraid_scav"] = 1,
			["corlevlr_scav"] = 1,
			["corsnap_scav"] = 1,
			--Legion
			["leggat_scav"] = 1,
			["legkark_scav"] = 1,
			["legner_scav"] = 1,
		},
		[4] = {
			--Armada
			["armzeus_scav"] = 1,
			--Cortex
			["corcan_scav"] = 1,
			["corhal_scav"] = 1,
			--Legion
			["legshot_scav"] = 1,

		},
		[5] = {
			--Armada
			["armsnipe_scav"] = 1,
			["armvader_scav"] = 1,
			["armsptk_scav"] = 1,
			["armbull_scav"] = 1,
			["armcroc_scav"] = 1,
			--Cortex
			["corparrow_scav"] = 1,
			["corftiger_scav"] = 1,
			["corgol_scav"] = 1,
			["corroach_scav"] = 1,
			["corsktl_scav"] = 1,
			["cortermite_scav"] = 1,
			["corsumo_scav"] = 1,
			["correap_scav"] = 1,
			["corgatreap_scav"] = 1,
			--Legion
			["legsco_scav"] = 1,
			["leginc_scav"] = 1,
			["legfloat_scav"] = 1,
		},
		[6] = {
			--Armada
			["armassimilator_scav"] = 1,
			["armmeatball_scav"] = 1,
			["armlun_scav"] = 1,
			--Cortex
			["corshiva_scav"] = 1,
			["corkarg_scav"] = 1,
			["corthermite"] = 1,
			["corsok_scav"] = 1,
			--Legion
			["legpede_scav"] = 1,
			["legkeres_scav"] = 1,
		},
		[7] = {
			--Armada
			["armthor_scav"] = 1,
			["armbanth_scav"] = 1,
			["armrattet4_scav"] = 1,
			["armvadert4_scav"] = 1,
			["armsptkt4_scav"] = 1,
			--Cortex
			["corjugg_scav"] = 1,
			["corkorg_scav"] = 1,
			["corkarganetht4_scav"] = 1,
			["corgolt4_scav"] = 1,
			--Legion
			["leegmech_scav"] = 1,
		},
	},
	Support = {
		[1] = {
			--Armada
			["armrock_scav"] = 1,
			["armjeth_scav"] = 1,
			["armah_scav"] = 1,
			--Cortex
			["corstorm_scav"] = 1,
			["corcrash_scav"] = 1,
			["corah_scav"] = 1,
			--Legion
			["legbal_scav"] = 1,
		},
		[2] = {
			--Armada
			["armrock_scav"] = 1,
			["armjeth_scav"] = 1,
			["armah_scav"] = 1,
			--Cortex
			["corstorm_scav"] = 1,
			["corcrash_scav"] = 1,
			["corah_scav"] = 1,
			--Legion
			["legbal_scav"] = 1,
		},
		[3] = {
			--Armada
			["armart_scav"] = 1,
			["armsam_scav"] = 1,
			["armmh_scav"] = 1,
			--Cortex
			["corwolv_scav"] = 1,
			["cormist_scav"] = 1,
			["cormh_scav"] = 1,
			--Legion
			["leghelios_scav"] = 1,
			["legbar_scav"] = 1,
			["legrail_scav"] = 1,
			["legmh_scav"] = 1,
			["legah_scav"] = 1,
		},
		[4] = {
			--Armada
			["armfido_scav"] = 1,
			["armaak_scav"] = 1,
			["armmav_scav"] = 1,
			["armyork_scav"] = 1,
			["armmart_scav"] = 1,
			--Cortex
			["cormart_scav"] = 1,
			["corsent_scav"] = 1,
			["coraak_scav"] = 1,
			["cormort_scav"] = 1,
			--Legion
			["legvcarry_scav"] = 1,
			["legbart_scav"] = 1,

		},
		[5] = {
			--Armada
			["armfboy_scav"] = 1,
			["armmanni_scav"] = 1,
			["armmerl_scav"] = 1,
			--Cortex
			["corban_scav"] = 1,
			["corvroc_scav"] = 1,
			["cortrem_scav"] = 1,
			["corhrk_scav"] = 1,
			["corsiegebreaker_scav"] = 1,
			--Legion
			["leginf_scav"] = 1,
			["legmed_scav"] = 1,

		},
		[6] = {
			--Armada
			["armvang_scav"] = 1,
			["armdronecarryland_scav"] = 1,
			["armscab_scav"] = 1,
			--Cortex
			["corcat_scav"] = 1,
			["cormabm_scav"] = 1,
			--Legion
		},
		[7] = {
			--Armada

			--Cortex

			--Legion
			--N/A
		},
	},
	Healer = {
		[1] = {
			--Armada
			["armck_scav"] = 1,
			["armrectr_scav"] = 40,
			["armcv_scav"] = 1,
			["armch_scav"] = 1,
			--Cortex
			["corck_scav"] = 1,
			["cornecro_scav"] = 40,
			["corcv_scav"] = 1,
			["corch_scav"] = 1,
			--Legion
			["legcv_scav"] = 1,
			["legck_scav"] = 1,
			["legch_scav"] = 1,
			["legotter_scav"] = 1,
		},
		[2] = {
			--Armada
			["armck_scav"] = 1,
			["armrectr_scav"] = 40,
			["armcv_scav"] = 1,
			["armch_scav"] = 1,
			--Cortex
			["corck_scav"] = 1,
			["cornecro_scav"] = 40,
			["corcv_scav"] = 1,
			["corch_scav"] = 1,
			--Legion
			["legcv_scav"] = 1,
			["legck_scav"] = 1,
			["legch_scav"] = 1,
			["legotter_scav"] = 1,
		},
		[3] = {
			--Armada
			["armck_scav"] = 1,
			["armrectr_scav"] = 40,
			["armcv_scav"] = 1,
			["armch_scav"] = 1,
			--Cortex
			["corck_scav"] = 1,
			["cornecro_scav"] = 40,
			["corcv_scav"] = 1,
			["corch_scav"] = 1,
			--Legion
			["legcv_scav"] = 1,
			["legck_scav"] = 1,
			["legch_scav"] = 1,
			["legotter_scav"] = 1,
		},
		[4] = {
			--Armada
			["armrectr_scav"] = 40,
			["armack_scav"] = 1,
			["armacv_scav"] = 1,
			["armfark_scav"] = 1,
			["armdecom_scav"] = 1,
			["armconsul_scav"] = 1,
			--Cortex
			["cornecro_scav"] = 40,
			["corack_scav"] = 1,
			["coracv_scav"] = 1,
			["corfast_scav"] = 1,
			["legaceb_scav"] = 1,
			["cordecom_scav"] = 1,
			["cormando_scav"] = 1,
			["corforge_scav"] = 1,
			--Legion
			["legacv_scav"] = 1,
			["legack_scav"] = 1,
		},
		[5] = {
			--Armada
			["armrectr_scav"] = 40,
			["armack_scav"] = 1,
			["armacv_scav"] = 1,
			["armfark_scav"] = 1,
			["armdecom_scav"] = 1,
			["armconsul_scav"] = 1,
			--Cortex
			["cornecro_scav"] = 40,
			["corack_scav"] = 1,
			["coracv_scav"] = 1,
			["corfast_scav"] = 1,
			["legaceb_scav"] = 1,
			["cordecom_scav"] = 1,
			["cormando_scav"] = 1,
			["corforge_scav"] = 1,
			--Legion
			["legacv_scav"] = 1,
			["legack_scav"] = 1,
		},
		[6] = {
			--Armada
			["armrectr_scav"] = 40,
			["armack_scav"] = 1,
			["armacv_scav"] = 1,
			["armfark_scav"] = 1,
			["armdecom_scav"] = 1,
			["armconsul_scav"] = 1,
			--Cortex
			["cornecro_scav"] = 40,
			["corack_scav"] = 1,
			["coracv_scav"] = 1,
			["corfast_scav"] = 1,
			["legaceb_scav"] = 1,
			["cordecom_scav"] = 1,
			["cormando_scav"] = 1,
			["corforge_scav"] = 1,
			--Legion
			["legacv_scav"] = 1,
			["legack_scav"] = 1,
		},
		[7] = {
			--Armada
			["armrectr_scav"] = 40,
			["armack_scav"] = 1,
			["armacv_scav"] = 1,
			["armfark_scav"] = 1,
			["armdecom_scav"] = 1,
			["armconsul_scav"] = 1,
			--Cortex
			["cornecro_scav"] = 40,
			["corack_scav"] = 1,
			["coracv_scav"] = 1,
			["corfast_scav"] = 1,
			["legaceb_scav"] = 1,
			["cordecom_scav"] = 1,
			["cormando_scav"] = 1,
			["corforge_scav"] = 1,
			--Legion
			["legacv_scav"] = 1,
			["legack_scav"] = 1,
		},
	},
}

----------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------

local SeaUnitsList = {
	Raid = {
		[1] = {
			--Armada
			["armdecade_scav"] = 1,
			["armsh_scav"] = 1,
			--Cortex
			["coresupp_scav"] = 1,
			["corsh_scav"] = 1,
			--Legion
			["legsh_scav"] = 1,
		},
		[2] = {
			--Armada
			["armdecade_scav"] = 1,
			["armsh_scav"] = 1,
			--Cortex
			["coresupp_scav"] = 1,
			["corsh_scav"] = 1,
			--Legion
			["legsh_scav"] = 1,
		},
		[3] = {
			--Armada
			--Cortex
			--Legion
		},
		[4] = {
			--Armada
			["armlship_scav"] = 1,
			--Cortex
			["corfship_scav"] = 1,
		},
		[5] = {
			--Armada
			["armsubk_scav"] = 1,
			--Cortex
			["corshark_scav"] = 1,
		},
		[6] = {
			--Armada

			--Cortex

		},
		[7] = {
			--Armada

			--Cortex

		},
	},
	Assault = {
		[1] = {
			--Armada

			--Cortex
		},
		[2] = {
			--Armada

			--Cortex
		},
		[3] = {
			--Armada
			["armpship_scav"] = 1,
			["armroy_scav"] = 1,
			["armanac_scav"] = 1,
			--Cortex
			["corpship_scav"] = 1,
			["corroy_scav"] = 1,
			["corsnap_scav"] = 1,
			--Legion
			["legner_scav"] = 1,
		},
		[4] = {
			--Armada
			["armcrus_scav"] = 1,
			--Cortex
			["corcrus_scav"] = 1,
			["corhal_scav"] = 1,
		},
		[5] = {
			--Armada
			["armbats_scav"] = 1,
			--Cortex
			["corbats_scav"] = 1,
		},
		[6] = {
			--Armada
			["armpshipt3_scav"] = 1,
			["armptt2_scav"] = 1,
			--Cortex
			["corblackhy_scav"] = 1,
		},
		[7] = {
			--Armada
			["armepoch_scav"] = 1,
			["armserpt3_scav"] = 1,
			--Cortex
			["coresuppt3_scav"] = 1,
		},
	},
	Support = {
		[1] = {
			--Armada
			["armpt_scav"] = 1,
			--Cortex
			["corpt_scav"] = 1,
		},
		[2] = {
			--Armada
			["armpt_scav"] = 1,
			--Cortex
			["corpt_scav"] = 1,
		},
		[3] = {
			--Armada
			["armsub_scav"] = 1,
			["armah_scav"] = 1,
			["armmh_scav"] = 1,
			--Cortex
			["corsub_scav"] = 1,
			["corah_scav"] = 1,
			["cormh_scav"] = 1,
			--Legion
			["legah_scav"] = 1,
			["legmh_scav"] = 1,
		},
		[4] = {
			--Armada
			["armantiship_scav"] = 1,
			["armdronecarry_scav"] = 1,
			["armaas_scav"] = 1,
			--Cortex
			["cordronecarry_scav"] = 1,
			["corantiship_scav"] = 1,
			["corarch_scav"] = 1,
		},
		[5] = {
			--Armada
			["armserp_scav"] = 1,
			["armmship_scav"] = 1,
			["armsjam_scav"] = 1,
			["armtrident_scav"] = 1,
			--Cortex
			["corssub_scav"] = 1,
			["cormship_scav"] = 1,
			["corsjam_scav"] = 1,
			["corsentinel_scav"] = 1,
		},
		[6] = {
			--Armada

			--Cortex

		},
		[7] = {
			--Armada
			["armdecadet3_scav"] = 1,
			--Cortex
			["corslrpc_scav"] = 1,
		},
	},
	Healer = {
		[1] = {
			--Armada
			["armcs_scav"] = 1,
			["armrecl_scav"] = 1,
			["armch_scav"] = 1,
			--Cortex
			["corcs_scav"] = 1,
			["correcl_scav"] = 1,
			["corch_scav"] = 1,
			--Legion
			["legch_scav"] = 1,
		},
		[2] = {
			--Armada
			["armcs_scav"] = 1,
			["armrecl_scav"] = 1,
			["armch_scav"] = 1,
			--Cortex
			["corcs_scav"] = 1,
			["correcl_scav"] = 1,
			["corch_scav"] = 1,
			--Legion
			["legch_scav"] = 1,
		},
		[3] = {
			--Armada
			["armcs_scav"] = 1,
			["armrecl_scav"] = 1,
			["armch_scav"] = 1,
			--Cortex
			["corcs_scav"] = 1,
			["correcl_scav"] = 1,
			["corch_scav"] = 1,
			--Legion
			["legch_scav"] = 1,
		},
		[4] = {
			--Armada
			["armacsub_scav"] = 1,
			["armmls_scav"] = 1,
			--Cortex
			["coracsub_scav"] = 1,
			["cormls_scav"] = 1,
		},
		[5] = {
			--Armada
			["armacsub_scav"] = 1,
			["armmls_scav"] = 1,
			--Cortex
			["coracsub_scav"] = 1,
			["cormls_scav"] = 1,
		},
		[6] = {
			--Armada
			["armacsub_scav"] = 1,
			["armmls_scav"] = 1,
			--Cortex
			["coracsub_scav"] = 1,
			["cormls_scav"] = 1,

		},
		[7] = {
			--Armada
			["armacsub_scav"] = 1,
			["armmls_scav"] = 1,
			--Cortex
			["coracsub_scav"] = 1,
			["cormls_scav"] = 1,
		},
	},
}

----------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------

local AirUnitsList = {
	[1] = {
		--Armada
		["armpeep_scav"] = 1,
		["armsehak_scav"] = 1,
		--Cortex
		["corfink_scav"] = 1,
		["corbw_scav"] = 1,
		["corhunt_scav"] = 1,
		--Legion
		["legfig_scav"] = 1,

	},
	[2] = {
		--Armada
		["armpeep_scav"] = 1,
		["armsehak_scav"] = 1,
		--Cortex
		["corfink_scav"] = 1,
		["corbw_scav"] = 1,
		["corhunt_scav"] = 1,
		--Legion
		["legfig_scav"] = 1,

	},
	[3] = {
		--Armada
		["armca_scav"] = 1,
		["armfig_scav"] = 1,
		["armkam_scav"] = 1,
		["armthund_scav"] = 1,
		["armsfig_scav"] = 1,
		["armcsa_scav"] = 1,
		--Cortex
		["corca_scav"] = 1,
		["corveng_scav"] = 1,
		["corshad_scav"] = 1,
		["corsfig_scav"] = 1,
		["corcsa_scav"] = 1,
		--Legion
		["legca_scav"] = 1,
		["legmos_scav"] = 1,
		["legcib_scav"] = 1,
		["legkam_scav"] = 1,

	},
	[4] = {
		--Armada
		["armaca_scav"] = 1,
		["armawac_scav"] = 1,
		["armsaber_scav"] = 1,
		["armseap_scav"] = 1,
		["armsb_scav"] = 1,
		["armlance_scav"] = 1,
		--Cortex
		["coraca_scav"] = 1,
		["corawac_scav"] = 1,
		["corcut_scav"] = 1,
		["corsb_scav"] = 1,
		["corseap_scav"] = 1,
		["cortitan_scav"] = 1,
		--Legion
		["legaca_scav"] = 1,
		["legwhisper_scav"] = 1,
	},
	[5] = {
		--Armada
		["armhawk_scav"] = 1,
		["armbrawl_scav"] = 1,
		["armpnix_scav"] = 1,
		["armstil_scav"] = 1,
		["armblade_scav"] = 1,
		["armliche_scav"] = 1,
		--Cortex
		["corvamp_scav"] = 1,
		["corape_scav"] = 1,
		["corhurc_scav"] = 1,
		["corcrw_scav"] = 1,
		["corcrwh_scav"] = 1,
		--Legion
		["legstronghold_scav"] = 1,
		["legvenator_scav"] = 1,
		["legionnaire_scav"] = 1,
		["legnap_scav"] = 1,
		["legmineb_scav"] = 1,
		["legphoenix_scav"] = 1,
		["legfort_scav"] = 1,
	},
	[6] = {
		--Armada
		["armthundt4_scav"] = 1,
		--Cortex
		["cordronecarryair_scav"] = 1,
		--Legion
		--N/A
	},
	[7] = {
		--Armada
		["armfepocht4_scav"] = 1,
		["armlichet4_scav"] = 1,
		--Cortex
		["corfblackhyt4_scav"] = 1,
		["corcrwt4_scav"] = 1,
		--Legion
		--N/A
	},
}
----------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------
-- types: normal, antiair, nuke, lrpc
-- surfaces: land, sea, mixed
-- don't put the same turret twice in here, ever.
-- If you use fractions in spawnerPerWave, it becomes a percentage chance to spawn one.

local Turrets = {
	[1] = {
		["armllt_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 10},
		["corllt_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 10},
		["leglht_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 10},
		["armrl_scav"] = {type = "antiair", surface = "land", spawnedPerWave = 0.1, maxExisting = 10},
		["corrl_scav"] = {type = "antiair", surface = "land", spawnedPerWave = 0.1, maxExisting = 10},
		["cortl_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.1, maxExisting = 4},
		["armtl_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.1, maxExisting = 4},
		["armfrt_scav"] = {type = "antiair", surface = "sea", spawnedPerWave = 0.1, maxExisting = 2},
		["corfrt_scav"] = {type = "antiair", surface = "sea", spawnedPerWave = 0.1, maxExisting = 2},
	},
	[2] = {
		--["cordl_scav"] = {type = "normal", surface = "mixed", spawnedPerWave = 0.1, maxExisting = 1},
		--["armdl_scav"] = {type = "normal", surface = "mixed", spawnedPerWave = 0.1, maxExisting = 1},
		--Sea Only
		["armfhlt_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.1, maxExisting = 5},
		["corfhlt_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.1, maxExisting = 5},
		["armfrock_scav"] = {type = "antiair", surface = "sea", spawnedPerWave = 0.1, maxExisting = 2},
		["corfrock_scav"] = {type = "antiair", surface = "sea", spawnedPerWave = 0.1, maxExisting = 2},
		["corgplat_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.1, maxExisting = 5},
		["armgplat_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.1, maxExisting = 5},
		--Eco
		["armsolar_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 2},
		["corsolar_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 2},
		["legsolar_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 2},
		["armwin_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 2},
		["corwin_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 2},
		["legwin_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 2},
		["legadvsol_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 2},
		["armtide_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.1, maxExisting = 3},
		["cortide_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.1, maxExisting = 3},
		["armmstor_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 1},
		["cormstor_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 1},
		["armestor_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 1},
		["corestor_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 1},
		["armuwms_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.1, maxExisting = 1},
		["coruwms_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.1, maxExisting = 1},
		["armuwes_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.1, maxExisting = 1},
		["coruwes_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.1, maxExisting = 1},
		["armmakr_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 1},
		["cormakr_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 1},
		["armfmkr_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.1, maxExisting = 1},
		["corfmkr_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.1, maxExisting = 1},
	},
	[3] = {
		["armbeamer_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 5},
		["corhllt_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 5},
		["legmg_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 5},
		["cormaw_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 4},
		["armclaw_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 4},
		["legdtr_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 4},
		["armferret_scav"] = {type = "antiair", surface = "land", spawnedPerWave = 0.1, maxExisting = 3},
		["cormadsam_scav"] = {type = "antiair", surface = "land", spawnedPerWave = 0.1, maxExisting = 5},
		["corhlt_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 3},
		["corpun_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 2},
		["armhlt_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 5},
		["armguard_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 3},
		["legcluster_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 3},
		["corscavdtl_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 3},
		["corscavdtf_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 3},
		["corscavdtm_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 3},
		["legdefcarryt1_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 3},
		--radar/jam
		["corrad_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 2},
		["corjamt_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 2},
		["armrad_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 2},
		["armjamt_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 2},
		["armjuno_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 1},
		["corjuno_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 1},
		["legrad_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 2},
		["legjam_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 2},
	},
	[4] = {
		["armcir_scav"] = {type = "antiair", surface = "land", spawnedPerWave = 0.1, maxExisting = 3},
		["corerad_scav"] = {type = "antiair", surface = "land", spawnedPerWave = 0.1, maxExisting = 3},
		["leglupara_scav"] = {type = "antiair", surface = "land", spawnedPerWave = 0.1, maxExisting = 3},
		--Sea
		["corfdoom_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.1, maxExisting = 5},
		["coratl_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.1, maxExisting = 5},
		["corenaa_scav"] = {type = "antiair", surface = "sea", spawnedPerWave = 0.1, maxExisting = 5},
		["corason_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.1, maxExisting = 0.4},
		["armkraken_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.1, maxExisting = 5},
		["armfflak_scav"] = {type = "antiair", surface = "sea", spawnedPerWave = 0.1, maxExisting = 5},
		["armatl_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.1, maxExisting = 5},
		["armason_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.1, maxExisting = 0.4},
		--T2 Radar/jam
		["corarad_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 2},
		["corshroud_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 2},
		["armarad_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 2},
		["armveil_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 2},
		--T2 Popups
		["armlwall_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 3},
		["cormwall_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 3},
		["armpb_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 3},
		["corvipe_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 3},
		["legbombard_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 3},
		--Misc
		["corhllllt_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 3},
		["armgate_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 2},
		["corgate_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 2},
		--T2 AA
		["corflak_scav"] = {type = "antiair", surface = "land", spawnedPerWave = 0.1, maxExisting = 4},
		["armflak_scav"] = {type = "antiair", surface = "land", spawnedPerWave = 0.1, maxExisting = 4},
		["legflak_scav"] = {type = "antiair", surface = "land", spawnedPerWave = 0.1, maxExisting = 4},
		--Eco
		["armwint2_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 3},
		["corwint2_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 3},
		["legwint2_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 3},
		["armfus_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 1},
		["armckfus_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 1},
		["corfus_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 1},
		["armuwfus_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.1, maxExisting = 1},
		["coruwfus_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.1, maxExisting = 1},
		["armuwadvms_scav"] = {type = "normal", surface = "mixed", spawnedPerWave = 0.1, maxExisting = 1},
		["coruwadvms_scav"] = {type = "normal", surface = "mixed", spawnedPerWave = 0.1, maxExisting = 1},
		["armuwadves_scav"] = {type = "normal", surface = "mixed", spawnedPerWave = 0.1, maxExisting = 1},
		["coruwadves_scav"] = {type = "normal", surface = "mixed", spawnedPerWave = 0.1, maxExisting = 1},
		["armmmkr_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 1},
		["cormmkr_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 1},
		["armuwmmm_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.1, maxExisting = 1},
		["coruwmmm_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.1, maxExisting = 1},
	},
	[5] = {
		-- T2 popup arty
		["armamb_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 2},
		["cortoast_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 2},
		["legacluster_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 2},
		-- Pulsar and Bulwark normals
		["armanni_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 2},
		["cordoom_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 2},
		["legbastion_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 2},
		--LRPC
		["armbrtha_scav"] = {type = "lrpc", surface = "land", spawnedPerWave = 0.1, maxExisting = 7},
		["corint_scav"] = {type = "lrpc", surface = "land", spawnedPerWave = 0.1, maxExisting = 7},
		["leglrpc_scav"] = {type = "lrpc", surface = "land", spawnedPerWave = 0.1, maxExisting = 7},
		--antinukes
		["armamd_scav"] = {type = "nuke", surface = "land", spawnedPerWave = 0.1, maxExisting = 10},
		["corfmd_scav"] = {type = "nuke", surface = "land", spawnedPerWave = 0.1, maxExisting = 10},
		--Tactical Weapons
		["cortron_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 2},
		["armemp_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 2},
		["legperdition_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 2},
		--T2 AA
		["armmercury_scav"] = {type = "antiair", surface = "land", spawnedPerWave = 0.1, maxExisting = 2},
		["corscreamer_scav"] = {type = "antiair", surface = "land", spawnedPerWave = 0.1, maxExisting = 2},
		["leglraa_scav"] = {type = "antiair", surface = "land", spawnedPerWave = 0.1, maxExisting = 2},
	},
	[6] = {
		-- nukes
		["corsilo_scav"] = {type = "nuke", surface = "land", spawnedPerWave = 0.1, maxExisting = 3},
		["armsilo_scav"] = {type = "nuke", surface = "land", spawnedPerWave = 0.1, maxExisting = 3},
		["legsilo_scav"] = {type = "nuke", surface = "land", spawnedPerWave = 0.1, maxExisting = 3},
		-- misc t3 turrets
		["armminivulc_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 3},
		["corminibuzz_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 3},
		["legministarfall_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 3},
		["armbotrail_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 1},
		--Eco
		["armafus_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 2},
		["corafus_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 2},
	},
	[7] = {
		--Epic Bulwark and Pulsar/rag/cal
		["armannit3_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 3},
		["cordoomt3_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 3},
		["armvulc_scav"] = {type = "lrpc", surface = "land", spawnedPerWave = 0.1, maxExisting = 1},
		["corbuzz_scav"] = {type = "lrpc", surface = "land", spawnedPerWave = 0.1, maxExisting = 1},
		["legstarfall_scav"] = {type = "lrpc", surface = "land", spawnedPerWave = 0.1, maxExisting = 1},
	},
}

----------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------

local scavTurrets = {}
-- Turrets table creation loop
for tier, _ in pairs(Turrets) do
	for turret, turretInfo in pairs(Turrets[tier]) do
		if (not scavTurrets[turret]) and
		(not ( Spring.GetModOptions().unit_restrictions_noair and turretInfo.type == "antiair")) and
		(not ( Spring.GetModOptions().unit_restrictions_nonukes and turretInfo.type == "nuke")) and
		(not (Spring.GetModOptions().unit_restrictions_nolrpc and turretInfo.type == "lrpc")) then
			-- Spring.Echo("---")
			-- Spring.Echo(turret)
			-- Spring.Echo(UnitDefs[UnitDefNames[turret].id].name)
			scavTurrets[turret] = {
				minBossAnger = tierConfiguration[tier].minAnger,
				spawnedPerWave = turretInfo.spawnedPerWave or 1,
				maxExisting = turretInfo.maxExisting or 10,
				maxBossAnger = turretInfo.maxBossAnger or 1000,
				surfaceType = turretInfo.surface or "land",
			}
		end
	end
end

----------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------

scavBehaviours = {
	SKIRMISH = { -- Run away from target after target gets hit
		[UnitDefNames["legcom_scav"].id] = { distance = 100, chance = 0.1 },
		[UnitDefNames["legcomlvl2_scav"].id] = { distance = 150, chance = 0.1 },
		[UnitDefNames["legcomlvl3_scav"].id] = { distance = 200, chance = 0.1 },
		[UnitDefNames["legcomlvl4_scav"].id] = { distance = 250, chance = 0.1 },
		[UnitDefNames["legcomlvl5_scav"].id] = { distance = 300, chance = 0.1 },
		[UnitDefNames["legcomlvl6_scav"].id] = { distance = 350, chance = 0.1 },
		[UnitDefNames["legcomlvl7_scav"].id] = { distance = 400, chance = 0.1 },
		[UnitDefNames["legcomlvl8_scav"].id] = { distance = 450, chance = 0.1 },
		[UnitDefNames["legcomlvl9_scav"].id] = { distance = 500, chance = 0.1 },
		[UnitDefNames["legcomlvl10_scav"].id] = { distance = 550, chance = 0.1 },
		[UnitDefNames["armcom_scav"].id] = { distance = 100, chance = 0.001 },
		[UnitDefNames["armcomlvl2_scav"].id] = { distance = 200, chance = 0.001 },
		[UnitDefNames["armcomlvl3_scav"].id] = { distance = 300, chance = 0.001 },
		[UnitDefNames["armcomlvl4_scav"].id] = { distance = 400, chance = 0.001 },
		[UnitDefNames["armcomlvl5_scav"].id] = { distance = 500, chance = 0.001 },
		[UnitDefNames["armcomlvl6_scav"].id] = { distance = 600, chance = 0.001 },
		[UnitDefNames["armcomlvl7_scav"].id] = { distance = 700, chance = 0.001 },
		[UnitDefNames["armcomlvl8_scav"].id] = { distance = 800, chance = 0.001 },
		[UnitDefNames["armcomlvl9_scav"].id] = { distance = 900, chance = 0.001 },
		[UnitDefNames["armcomlvl10_scav"].id] = { distance = 1000, chance = 0.001 },
	},
	COWARD = { -- Run away from target after getting hit by enemy
		[UnitDefNames["corcom_scav"].id] = { distance = 100, chance = 0.1 },
		[UnitDefNames["corcomlvl2_scav"].id] = { distance = 150, chance = 0.1 },
		[UnitDefNames["corcomlvl3_scav"].id] = { distance = 200, chance = 0.1 },
		[UnitDefNames["corcomlvl4_scav"].id] = { distance = 250, chance = 0.1 },
		[UnitDefNames["corcomlvl5_scav"].id] = { distance = 300, chance = 0.1 },
		[UnitDefNames["corcomlvl6_scav"].id] = { distance = 350, chance = 0.1 },
		[UnitDefNames["corcomlvl7_scav"].id] = { distance = 400, chance = 0.1 },
		[UnitDefNames["corcomlvl8_scav"].id] = { distance = 450, chance = 0.1 },
		[UnitDefNames["corcomlvl9_scav"].id] = { distance = 500, chance = 0.1 },
		[UnitDefNames["corcomlvl10_scav"].id] = { distance = 550, chance = 0.1 },
		[UnitDefNames["legcom_scav"].id] = { distance = 100, chance = 0.001 },
		[UnitDefNames["legcomlvl2_scav"].id] = { distance = 150, chance = 0.001 },
		[UnitDefNames["legcomlvl3_scav"].id] = { distance = 200, chance = 0.001 },
		[UnitDefNames["legcomlvl4_scav"].id] = { distance = 250, chance = 0.001 },
		[UnitDefNames["legcomlvl5_scav"].id] = { distance = 300, chance = 0.001 },
		[UnitDefNames["legcomlvl6_scav"].id] = { distance = 350, chance = 0.001 },
		[UnitDefNames["legcomlvl7_scav"].id] = { distance = 400, chance = 0.001 },
		[UnitDefNames["legcomlvl8_scav"].id] = { distance = 450, chance = 0.001 },
		[UnitDefNames["legcomlvl9_scav"].id] = { distance = 500, chance = 0.001 },
		[UnitDefNames["legcomlvl10_scav"].id] = { distance = 550, chance = 0.001 },
	},
	BERSERK = { -- Run towards target after getting hit by enemy or after hitting the target
		[UnitDefNames["armcom_scav"].id] = { distance = 2000, chance = 0.1 },
		[UnitDefNames["armcomlvl2_scav"].id] = { distance = 2000, chance = 0.1 },
		[UnitDefNames["armcomlvl3_scav"].id] = { distance = 2000, chance = 0.1 },
		[UnitDefNames["armcomlvl4_scav"].id] = { distance = 2000, chance = 0.1 },
		[UnitDefNames["armcomlvl5_scav"].id] = { distance = 2000, chance = 0.1 },
		[UnitDefNames["armcomlvl6_scav"].id] = { distance = 2000, chance = 0.1 },
		[UnitDefNames["armcomlvl7_scav"].id] = { distance = 2000, chance = 0.1 },
		[UnitDefNames["armcomlvl8_scav"].id] = { distance = 2000, chance = 0.1 },
		[UnitDefNames["armcomlvl9_scav"].id] = { distance = 2000, chance = 0.1 },
		[UnitDefNames["armcomlvl10_scav"].id] = { distance = 2000, chance = 0.1 },
		[UnitDefNames["corcom_scav"].id] = { distance = 2000, chance = 0.001 },
		[UnitDefNames["corcomlvl2_scav"].id] = { distance = 2000, chance = 0.001 },
		[UnitDefNames["corcomlvl3_scav"].id] = { distance = 2000, chance = 0.001 },
		[UnitDefNames["corcomlvl4_scav"].id] = { distance = 2000, chance = 0.001 },
		[UnitDefNames["corcomlvl5_scav"].id] = { distance = 2000, chance = 0.001 },
		[UnitDefNames["corcomlvl6_scav"].id] = { distance = 2000, chance = 0.001 },
		[UnitDefNames["corcomlvl7_scav"].id] = { distance = 2000, chance = 0.001 },
		[UnitDefNames["corcomlvl8_scav"].id] = { distance = 2000, chance = 0.001 },
		[UnitDefNames["corcomlvl9_scav"].id] = { distance = 2000, chance = 0.001 },
		[UnitDefNames["corcomlvl10_scav"].id] = { distance = 2000, chance = 0.001 },
		[UnitDefNames["armscavengerbossv2_veryeasy_scav"].id]	= { distance = 2000, chance = 0.001},
		[UnitDefNames["armscavengerbossv2_easy_scav"].id] 		= { distance = 2000, chance = 0.001},
		[UnitDefNames["armscavengerbossv2_normal_scav"].id] 	= { distance = 2000, chance = 0.001},
		[UnitDefNames["armscavengerbossv2_hard_scav"].id] 		= { distance = 2000, chance = 0.001},
		[UnitDefNames["armscavengerbossv2_veryhard_scav"].id] 	= { distance = 2000, chance = 0.001},
		[UnitDefNames["armscavengerbossv2_epic_scav"].id]		= { distance = 2000, chance = 0.001},
		[UnitDefNames["scavmist_scav"].id]			= { distance = 2000, chance = 1},
		[UnitDefNames["scavmistxl_scav"].id]		= { distance = 2000, chance = 1},
		[UnitDefNames["scavmistxxl_scav"].id]		= { distance = 2000, chance = 1},
	},
	HEALER = { -- Getting long max lifetime and always use Fight command. These units spawn as healers from burrows and boss
		--[UnitDefNames["raptor_land_swarmer_heal_t1_v1"].id] = true,
		[UnitDefNames["armrectr_scav"].id] = true,--Armada Rezzer
		[UnitDefNames["cornecro_scav"].id] = true,--Cortex Rezzer
		[UnitDefNames["armca_scav"].id] = true,
		[UnitDefNames["armaca_scav"].id] = true,
		[UnitDefNames["armcsa_scav"].id] = true,
		[UnitDefNames["corca_scav"].id] = true,
		[UnitDefNames["coraca_scav"].id] = true,
		[UnitDefNames["corcsa_scav"].id] = true,
		[UnitDefNames["legca_scav"].id] = true,
		[UnitDefNames["legaca_scav"].id] = true,


		[UnitDefNames["armcom_scav"].id] = true,
		[UnitDefNames["corcom_scav"].id] = true,
		[UnitDefNames["legcom_scav"].id] = true,
		[UnitDefNames["armcomlvl2_scav"].id] = true,
		[UnitDefNames["corcomlvl2_scav"].id] = true,
		[UnitDefNames["legcomlvl2_scav"].id] = true,
		[UnitDefNames["armcomlvl3_scav"].id] = true,
		[UnitDefNames["corcomlvl3_scav"].id] = true,
		[UnitDefNames["legcomlvl3_scav"].id] = true,
		[UnitDefNames["armcomlvl4_scav"].id] = true,
		[UnitDefNames["corcomlvl4_scav"].id] = true,
		[UnitDefNames["legcomlvl4_scav"].id] = true,
		[UnitDefNames["armcomlvl5_scav"].id] = true,
		[UnitDefNames["corcomlvl5_scav"].id] = true,
		[UnitDefNames["legcomlvl5_scav"].id] = true,
		[UnitDefNames["armcomlvl6_scav"].id] = true,
		[UnitDefNames["corcomlvl6_scav"].id] = true,
		[UnitDefNames["legcomlvl6_scav"].id] = true,
		[UnitDefNames["armcomlvl7_scav"].id] = true,
		[UnitDefNames["corcomlvl7_scav"].id] = true,
		[UnitDefNames["legcomlvl7_scav"].id] = true,
		[UnitDefNames["armcomlvl8_scav"].id] = true,
		[UnitDefNames["corcomlvl8_scav"].id] = true,
		[UnitDefNames["legcomlvl8_scav"].id] = true,
		[UnitDefNames["armcomlvl9_scav"].id] = true,
		[UnitDefNames["corcomlvl9_scav"].id] = true,
		[UnitDefNames["legcomlvl9_scav"].id] = true,
		[UnitDefNames["armcomlvl10_scav"].id] = true,
		[UnitDefNames["corcomlvl10_scav"].id] = true,
		[UnitDefNames["legcomlvl10_scav"].id] = true,


	},
	ARTILLERY = { -- Long lifetime and no regrouping, always uses Fight command to keep distance
		--[UnitDefNames["raptor_allterrain_arty_basic_t2_v1"].id] = true,
	},
	KAMIKAZE = { -- Long lifetime and no regrouping, always uses Move command to rush into the enemy
		--[UnitDefNames["raptor_land_kamikaze_basic_t2_v1"].id] = true,
		[UnitDefNames["scavmist_scav"].id]			= true,
		[UnitDefNames["scavmistxl_scav"].id]		= true,
		[UnitDefNames["scavmistxxl_scav"].id]		= true,
	},
	ALLOWFRIENDLYFIRE = {
		--[UnitDefNames["raptor_allterrain_arty_basic_t2_v1"].id] = true,
	},
}

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local squadSpawnOptionsTable = {
	basicLand = {}, -- 67% spawn chance
	basicSea = {}, -- 67% spawn chance
	basicAir = {},
	specialLand = {}, -- 33% spawn chance, there's 1% chance of Special squad spawning Super squad, which is specials but 30% anger earlier.
	specialSea = {}, -- 33% spawn chance, there's 1% chance of Special squad spawning Super squad, which is specials but 30% anger earlier.
	specialAir = {},
	healerLand = {}, -- Healers/Medics
	healerSea = {}, -- Healers/Medics
	commanders = {
		["armcom_scav"]      = { minAnger = 0, maxAnger = 20, maxAlive = 1 },
		["armcomlvl2_scav"]  = { minAnger = 10, maxAnger = 30, maxAlive = 1 },
		["armcomlvl3_scav"]  = { minAnger = 20, maxAnger = 40, maxAlive = 1 },
		["armcomlvl4_scav"]  = { minAnger = 30, maxAnger = 50, maxAlive = 1 },
		["armcomlvl5_scav"]  = { minAnger = 40, maxAnger = 60, maxAlive = 2 },
		["armcomlvl6_scav"]  = { minAnger = 50, maxAnger = 70, maxAlive = 2 },
		["armcomlvl7_scav"]  = { minAnger = 60, maxAnger = 80, maxAlive = 2 },
		["armcomlvl8_scav"]  = { minAnger = 70, maxAnger = 90, maxAlive = 2 },
		["armcomlvl9_scav"]  = { minAnger = 80, maxAnger = 100, maxAlive = 3 },
		["armcomlvl10_scav"] = { minAnger = 90, maxAnger = 1000, maxAlive = 3 },
		["armdecom_scav"]    = { minAnger = 25, maxAnger = 1000, maxAlive = 3 },
		["corcom_scav"]      = { minAnger = 0, maxAnger = 20, maxAlive = 1 },
		["corcomlvl2_scav"]  = { minAnger = 10, maxAnger = 30, maxAlive = 1 },
		["corcomlvl3_scav"]  = { minAnger = 20, maxAnger = 40, maxAlive = 1 },
		["corcomlvl4_scav"]  = { minAnger = 30, maxAnger = 50, maxAlive = 1 },
		["corcomlvl5_scav"]  = { minAnger = 40, maxAnger = 60, maxAlive = 2 },
		["corcomlvl6_scav"]  = { minAnger = 50, maxAnger = 70, maxAlive = 2 },
		["corcomlvl7_scav"]  = { minAnger = 60, maxAnger = 80, maxAlive = 2 },
		["corcomlvl8_scav"]  = { minAnger = 70, maxAnger = 90, maxAlive = 2 },
		["corcomlvl9_scav"]  = { minAnger = 80, maxAnger = 100, maxAlive = 3 },
		["corcomlvl10_scav"] = { minAnger = 90, maxAnger = 1000, maxAlive = 3 },
		["cordecom_scav"]    = { minAnger = 25, maxAnger = 1000, maxAlive = 3 },
		["legcom_scav"]      = { minAnger = 0, maxAnger = 20, maxAlive = 1 },
		["legcomlvl2_scav"]  = { minAnger = 10, maxAnger = 30, maxAlive = 1 },
		["legcomlvl3_scav"]  = { minAnger = 20, maxAnger = 40, maxAlive = 1 },
		["legcomlvl4_scav"]  = { minAnger = 30, maxAnger = 50, maxAlive = 1 },
		["legcomlvl5_scav"]  = { minAnger = 40, maxAnger = 60, maxAlive = 2 },
		["legcomlvl6_scav"]  = { minAnger = 50, maxAnger = 70, maxAlive = 2 },
		["legcomlvl7_scav"]  = { minAnger = 60, maxAnger = 80, maxAlive = 2 },
		["legcomlvl8_scav"]  = { minAnger = 70, maxAnger = 90, maxAlive = 2 },
		["legcomlvl9_scav"]  = { minAnger = 80, maxAnger = 100, maxAlive = 3 },
		["legcomlvl10_scav"] = { minAnger = 90, maxAnger = 1000, maxAlive = 3 },
	}
}

local scavMinions = {} -- Units spawning other units

local function addNewSquad(squadParams) -- params: {type = "basic", minAnger = 0, maxAnger = 100, units = {"1 raptor1"}, weight = 1}
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

--------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------- LAND
--------------------------------------------------------------------------------------------------------------------------------------------------------

for tier, _ in pairs(LandUnitsList.Raid) do
	for unitName, _ in pairs(LandUnitsList.Raid[tier]) do
		if UnitDefNames[unitName] then
			local unitWeight = LandUnitsList.Raid[tier][unitName]
			-- Spring.Echo(unitName)
			addNewSquad({ type = "basicLand", minAnger = tierConfiguration[tier].minAnger*2, units = { tierConfiguration[tier].maxSquadSize*2 .. " " .. unitName}, weight = unitWeight, maxAnger = tierConfiguration[tier].maxAnger*2 })
			addNewSquad({ type = "specialLand", minAnger = tierConfiguration[tier].minAnger, units = { tierConfiguration[tier].maxSquadSize .. " " .. unitName}, weight = unitWeight, maxAnger = tierConfiguration[tier].maxAnger })
		end
	end
end

for tier, _ in pairs(LandUnitsList.Assault) do
	for unitName, _ in pairs(LandUnitsList.Assault[tier]) do
		if UnitDefNames[unitName] then
			local unitWeight = LandUnitsList.Assault[tier][unitName]
			-- Spring.Echo(unitName)
			if not scavBehaviours.BERSERK[UnitDefNames[unitName].id] then
				scavBehaviours.BERSERK[UnitDefNames[unitName].id] = {distance = 2000, chance = 0.01}
			end
			addNewSquad({ type = "basicLand", minAnger = tierConfiguration[tier].minAnger*2, units = { tierConfiguration[tier].maxSquadSize*2 .. " " .. unitName}, weight = unitWeight, maxAnger = tierConfiguration[tier].maxAnger*2 })
			addNewSquad({ type = "specialLand", minAnger = tierConfiguration[tier].minAnger, units = { tierConfiguration[tier].maxSquadSize .. " " .. unitName}, weight = unitWeight, maxAnger = tierConfiguration[tier].maxAnger })
		end
	end
end

for tier, _ in pairs(LandUnitsList.Support) do
	for unitName, _ in pairs(LandUnitsList.Support[tier]) do
		if UnitDefNames[unitName] then
			local unitWeight = LandUnitsList.Support[tier][unitName]
			-- Spring.Echo(unitName)
			if not scavBehaviours.SKIRMISH[UnitDefNames[unitName].id] then
				scavBehaviours.SKIRMISH[UnitDefNames[unitName].id] = {distance = 500, chance = 0.1}
				scavBehaviours.COWARD[UnitDefNames[unitName].id] = {distance = 500, chance = 0.75}
				scavBehaviours.ARTILLERY[UnitDefNames[unitName].id] = true
			end
			addNewSquad({ type = "basicLand", minAnger = tierConfiguration[tier].minAnger*2, units = { tierConfiguration[tier].maxSquadSize*2 .. " " .. unitName}, weight = unitWeight, maxAnger = tierConfiguration[tier].maxAnger*2 })
			addNewSquad({ type = "specialLand", minAnger = tierConfiguration[tier].minAnger, units = { tierConfiguration[tier].maxSquadSize .. " " .. unitName}, weight = unitWeight, maxAnger = tierConfiguration[tier].maxAnger })
		end
	end
end

for tier, _ in pairs(LandUnitsList.Healer) do
	for unitName, _ in pairs(LandUnitsList.Healer[tier]) do
		if UnitDefNames[unitName] then
			local unitWeight = LandUnitsList.Healer[tier][unitName]
			-- Spring.Echo(unitName)
			if not scavBehaviours.HEALER[UnitDefNames[unitName].id] then
				scavBehaviours.HEALER[UnitDefNames[unitName].id] = true
				if not scavBehaviours.SKIRMISH[UnitDefNames[unitName].id] then
					scavBehaviours.SKIRMISH[UnitDefNames[unitName].id] = {distance = 500, chance = 0.1}
					scavBehaviours.COWARD[UnitDefNames[unitName].id] = {distance = 500, chance = 0.75}
				end
			end
			addNewSquad({ type = "healerLand", minAnger = tierConfiguration[tier].minAnger, units = { tierConfiguration[tier].maxSquadSize .. " " .. unitName}, weight = unitWeight, maxAnger = tierConfiguration[tier].maxAnger })
		end
	end
end

--------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------- SEA
--------------------------------------------------------------------------------------------------------------------------------------------------------

for tier, _ in pairs(SeaUnitsList.Raid) do
	for unitName, _ in pairs(SeaUnitsList.Raid[tier]) do
		if UnitDefNames[unitName] then
			local unitWeight = SeaUnitsList.Raid[tier][unitName]
			-- Spring.Echo(unitName)
			addNewSquad({ type = "basicSea", minAnger = tierConfiguration[tier].minAnger*2, units = { tierConfiguration[tier].maxSquadSize .. " " .. unitName}, weight = unitWeight, maxAnger = tierConfiguration[tier].maxAnger*2 })
			addNewSquad({ type = "specialSea", minAnger = tierConfiguration[tier].minAnger, units = { math.ceil(tierConfiguration[tier].maxSquadSize*0.5) .. " " .. unitName}, weight = unitWeight, maxAnger = tierConfiguration[tier].maxAnger })
		end
	end
end

for tier, _ in pairs(SeaUnitsList.Assault) do
	for unitName, _ in pairs(SeaUnitsList.Assault[tier]) do
		if UnitDefNames[unitName] then
			local unitWeight = SeaUnitsList.Assault[tier][unitName]
			-- Spring.Echo(unitName)
			if not scavBehaviours.BERSERK[UnitDefNames[unitName].id] then
				scavBehaviours.BERSERK[UnitDefNames[unitName].id] = {distance = 2000, chance = 0.01}
			end
			addNewSquad({ type = "basicSea", minAnger = tierConfiguration[tier].minAnger*2, units = { tierConfiguration[tier].maxSquadSize .. " " .. unitName}, weight = unitWeight, maxAnger = tierConfiguration[tier].maxAnger*2 })
			addNewSquad({ type = "specialSea", minAnger = tierConfiguration[tier].minAnger, units = { math.ceil(tierConfiguration[tier].maxSquadSize*0.5) .. " " .. unitName}, weight = unitWeight, maxAnger = tierConfiguration[tier].maxAnger })
		end
	end
end

for tier, _ in pairs(SeaUnitsList.Support) do
	for unitName, _ in pairs(SeaUnitsList.Support[tier]) do
		if UnitDefNames[unitName] then
			local unitWeight = SeaUnitsList.Support[tier][unitName]
			-- Spring.Echo(unitName)
			if not scavBehaviours.SKIRMISH[UnitDefNames[unitName].id] then
				scavBehaviours.SKIRMISH[UnitDefNames[unitName].id] = {distance = 500, chance = 0.1}
				scavBehaviours.COWARD[UnitDefNames[unitName].id] = {distance = 500, chance = 0.75}
				scavBehaviours.ARTILLERY[UnitDefNames[unitName].id] = true
			end
			addNewSquad({ type = "basicSea", minAnger = tierConfiguration[tier].minAnger*2, units = { tierConfiguration[tier].maxSquadSize .. " " .. unitName}, weight = unitWeight, maxAnger = tierConfiguration[tier].maxAnger*2 })
			addNewSquad({ type = "specialSea", minAnger = tierConfiguration[tier].minAnger, units = { math.ceil(tierConfiguration[tier].maxSquadSize*0.5) .. " " .. unitName}, weight = unitWeight, maxAnger = tierConfiguration[tier].maxAnger })
		end
	end
end

for tier, _ in pairs(SeaUnitsList.Healer) do
	for unitName, _ in pairs(SeaUnitsList.Healer[tier]) do
		if UnitDefNames[unitName] then
			local unitWeight = SeaUnitsList.Healer[tier][unitName]
			-- Spring.Echo(unitName)
			if not scavBehaviours.HEALER[UnitDefNames[unitName].id] then
				scavBehaviours.HEALER[UnitDefNames[unitName].id] = true
				if not scavBehaviours.SKIRMISH[UnitDefNames[unitName].id] then
					scavBehaviours.SKIRMISH[UnitDefNames[unitName].id] = {distance = 500, chance = 0.1}
					scavBehaviours.COWARD[UnitDefNames[unitName].id] = {distance = 500, chance = 0.75}
				end
			end
			addNewSquad({ type = "healerSea", minAnger = tierConfiguration[tier].minAnger, units = { tierConfiguration[tier].maxSquadSize .. " " .. unitName}, weight = unitWeight, maxAnger = tierConfiguration[tier].maxAnger })
		end
	end
end

--------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------- AIR
--------------------------------------------------------------------------------------------------------------------------------------------------------

for tier, _ in pairs(AirUnitsList) do
	for unitName, _ in pairs(AirUnitsList[tier]) do
		if UnitDefNames[unitName] then
			local unitWeight = AirUnitsList[tier][unitName]
			-- Spring.Echo(unitName)
			addNewSquad({ type = "basicAir", minAnger = tierConfiguration[tier].minAnger*2, units = { tierConfiguration[tier].maxSquadSize*2 .. " " .. unitName}, weight = unitWeight, maxAnger = tierConfiguration[tier].maxAnger*2 })
			addNewSquad({ type = "specialAir", minAnger = tierConfiguration[tier].minAnger, units = { tierConfiguration[tier].maxSquadSize .. " " .. unitName}, weight = unitWeight, maxAnger = tierConfiguration[tier].maxAnger })
		end
	end
end

------Tier 1 0-25% (Land and Air)
addNewSquad({ type = "healerLand", minAnger = tierConfiguration[2].minAnger, units = { "20 armrectr_scav","20 cornecro_scav",}, weight = 40, maxAnger = 1000}) --Rezzers/Entire Game
--Land
addNewSquad({ type = "specialLand", minAnger = tierConfiguration[2].minAnger, units = { "20 armfav_scav","20 corfav_scav",}, weight = 6, maxAnger = tierConfiguration[2].maxAnger}) --Rovers/Whole Tier Length
addNewSquad({ type = "specialLand", minAnger = tierConfiguration[2].minAnger, units = { "6 armflash_scav","6 corgator_scav","6 leghelios_scav",}, weight = 4, maxAnger = tierConfiguration[2].maxAnger}) --T1 Veh Raid
addNewSquad({ type = "specialLand", minAnger = tierConfiguration[3].minAnger, units = { "5 armstump_scav","5 corraid_scav","5 leggat_scav",}, weight = 4, maxAnger = tierConfiguration[3].maxAnger}) --T1 Veh Assault
addNewSquad({ type = "specialLand", minAnger = tierConfiguration[3].minAnger, units = { "2 armjanus_scav","2 corlevlr_scav","2 legrail_scav",}, weight = 4, maxAnger = tierConfiguration[3].maxAnger}) --T1 Veh Unique
addNewSquad({ type = "specialLand", minAnger = tierConfiguration[3].minAnger, units = { "1 armart_scav","2 armsam_scav","1 corwolv_scav","2 cormist_scav","2 legbar_scav"}, weight = 4, maxAnger = tierConfiguration[3].maxAnger}) --T1 Arty/AA
--air
addNewSquad({ type = "specialAir", minAnger = tierConfiguration[2].minAnger, units = { "3 armpeep_scav","3 corfink_scav","9 legfig_scav",}, weight = 4, maxAnger = tierConfiguration[2].maxAnger}) --T1 Air Scouts
addNewSquad({ type = "specialAir", minAnger = tierConfiguration[3].minAnger, units = { "12 corbw_scav",}, weight = 4, maxAnger = tierConfiguration[3].maxAnger}) --Bladewings
addNewSquad({ type = "specialAir", minAnger = tierConfiguration[3].minAnger, units = { "20 armfig_scav","20 corveng_scav",}, weight = 4, maxAnger = tierConfiguration[3].maxAnger}) --Fighters
addNewSquad({ type = "specialAir", minAnger = tierConfiguration[3].minAnger, units = { "12 armthund_scav","12 corshad_scav","5 legcib_scav",}, weight = 4, maxAnger = tierConfiguration[3].maxAnger}) --Bombers
------Tier 2 25-60%
addNewSquad({ type = "specialLand", minAnger = tierConfiguration[4].minAnger, units = { "10 armfav_scav","10 corfav_scav","25 armzapper_scav",}, weight = 6, maxAnger = tierConfiguration[4].maxAnger}) --Rover and EMP Rover/Whole Tier Length
--Land
addNewSquad({ type = "specialLand", minAnger = tierConfiguration[4].minAnger, units = { "6 armlatnk_scav","6 cortorch_scav","6 legmrv_scav",}, weight = 4, maxAnger = tierConfiguration[4].maxAnger}) --T2 Veh Raid
addNewSquad({ type = "specialLand", minAnger = tierConfiguration[4].minAnger, units = { "6 armbull_scav","6 correap_scav","1 corgol_scav","5 legsco_scav","2 armyork_scav","2 corsent_scav",}, weight = 4, maxAnger = tierConfiguration[4].maxAnger}) --T2 Veh Assault/AA
addNewSquad({ type = "specialLand", minAnger = tierConfiguration[5].minAnger, units = { "2 armmanni_scav","2 corban_scav","1 legvcarry_scav",}, weight = 4, maxAnger = tierConfiguration[5].maxAnger}) --T2 Veh Unique
addNewSquad({ type = "specialLand", minAnger = tierConfiguration[5].minAnger, units = { "3 armmart_scav","1 armmerl_scav","1 armyork_scav","3 cormart_scav","1 corvroc_scav","1 corsent_scav","1 leginf_scav",}, weight = 4, maxAnger = tierConfiguration[5].maxAnger}) --T2 Arty/AA
--air
addNewSquad({ type = "specialAir", minAnger = tierConfiguration[5].minAnger, units = { "3 armawac_scav","3 corawac_scav",}, weight = 4, maxAnger = tierConfiguration[5].maxAnger}) --T2 Air Scouts
addNewSquad({ type = "specialAir", minAnger = tierConfiguration[5].minAnger, units = { "2 armstil_scav",}, weight = 4, maxAnger = tierConfiguration[5].maxAnger}) --EMP Bombers
addNewSquad({ type = "specialAir", minAnger = tierConfiguration[5].minAnger, units = { "20 armhawk_scav","20 corvamp_scav",}, weight = 4, maxAnger = tierConfiguration[5].maxAnger}) --Fighters
addNewSquad({ type = "specialAir", minAnger = tierConfiguration[5].minAnger, units = { "15 armblade_scav","15 armbrawl_scav","1 legfort_scav","1 corcrw_scav", "1 corcrwh_scav","15 corape_scav"}, weight = 4, maxAnger = tierConfiguration[5].maxAnger}) --T2 Gunships
------Tier 3 60-80%
--Dilluters
addNewSquad({ type = "specialLand", minAnger = tierConfiguration[6].minAnger, units = { "15 armfav_scav","15 corfav_scav",}, weight = 8, maxAnger = tierConfiguration[6].maxAnger}) --Rover Whole Tier Length
addNewSquad({ type = "specialLand", minAnger = tierConfiguration[6].minAnger, units = { "6 cortorch_scav","6 legmrv_scav",}, weight = 3, maxAnger = tierConfiguration[6].maxAnger}) --T2 Veh Raid
--Land
addNewSquad({ type = "specialLand", minAnger = tierConfiguration[6].minAnger, units = { "12 armmar_scav",}, weight = 3, maxAnger = tierConfiguration[6].maxAnger}) --T3 Raid
addNewSquad({ type = "specialLand", minAnger = tierConfiguration[6].minAnger, units = { "6 armmeatball_scav","6 armassimilator_scav","2 armyork_scav","2 corsent_scav",}, weight = 4, maxAnger = tierConfiguration[6].maxAnger}) --T3 Assault/AA
addNewSquad({ type = "specialLand", minAnger = tierConfiguration[6].minAnger, units = { "6 corshiva_scav","2 armraz_scav","1 legpede_scav","1 armyork_scav","1 corsent_scav",}, weight = 4, maxAnger = tierConfiguration[6].maxAnger}) --T3 Assault/AA
addNewSquad({ type = "specialLand", minAnger = tierConfiguration[6].minAnger, units = { "2 armvang_scav","2 corcat_scav","1 armyork_scav","1 corsent_scav",}, weight = 4, maxAnger = tierConfiguration[6].maxAnger}) --T3 Arty/AA
--air
addNewSquad({ type = "specialAir", minAnger = tierConfiguration[6].minAnger, units = { "40 armfig_scav","40 corveng_scav",}, weight = 4, maxAnger = tierConfiguration[6].maxAnger}) --T2 Fighters
addNewSquad({ type = "specialAir", minAnger = tierConfiguration[6].minAnger, units = { "15 armblade_scav","15 armbrawl_scav","1 legfort_scav","1 corcrw_scav", "1 corcrwh_scav","15 corape_scav"}, weight = 2, maxAnger = tierConfiguration[6].maxAnger}) --T2 Gunships
------Tier 4 80%+
addNewSquad({ type = "specialAir", minAnger = tierConfiguration[7].minAnger, units = { "80 armfig_scav","80 corveng_scav",}, weight = 5, maxAnger = tierConfiguration[7].maxAnger}) --T2 Fighters
addNewSquad({ type = "specialAir", minAnger = tierConfiguration[7].minAnger, units = { "10 armfepocht4_scav",}, weight = 1, maxAnger = tierConfiguration[7].maxAnger}) --Armada Flying Flagships
addNewSquad({ type = "specialAir", minAnger = tierConfiguration[7].minAnger, units = { "10 corfblackhyt4_scav",}, weight = 1, maxAnger = tierConfiguration[7].maxAnger}) --Cortex Flying Flagships

-- evocoms
--addNewSquad({ type = "specialLand", minAnger = 0, units = { "2 armcom_scav",}, weight = 1, maxAnger = 20})
--addNewSquad({ type = "specialLand", minAnger = 0, units = { "2 corcom_scav",}, weight = 1, maxAnger = 20})
--addNewSquad({ type = "specialLand", minAnger = 0, units = { "2 legcom_scav",}, weight = 1, maxAnger = 20})
--
--addNewSquad({ type = "specialLand", minAnger = 10, units = { "2 armcomlvl2_scav",}, weight = 1, maxAnger = 30})
--addNewSquad({ type = "specialLand", minAnger = 10, units = { "2 corcomlvl2_scav",}, weight = 1, maxAnger = 30})
--addNewSquad({ type = "specialLand", minAnger = 10, units = { "2 legcomlvl2_scav",}, weight = 1, maxAnger = 30})
--
--addNewSquad({ type = "specialLand", minAnger = 20, units = { "2 armcomlvl3_scav",}, weight = 1, maxAnger = 40})
--addNewSquad({ type = "specialLand", minAnger = 20, units = { "2 corcomlvl3_scav",}, weight = 1, maxAnger = 40})
--addNewSquad({ type = "specialLand", minAnger = 20, units = { "2 legcomlvl3_scav",}, weight = 1, maxAnger = 40})
--
--addNewSquad({ type = "specialLand", minAnger = 30, units = { "2 armcomlvl4_scav",}, weight = 1, maxAnger = 50})
--addNewSquad({ type = "specialLand", minAnger = 30, units = { "2 corcomlvl4_scav",}, weight = 1, maxAnger = 50})
--addNewSquad({ type = "specialLand", minAnger = 30, units = { "2 legcomlvl4_scav",}, weight = 1, maxAnger = 50})
--
--addNewSquad({ type = "specialLand", minAnger = 40, units = { "2 armcomlvl5_scav",}, weight = 1, maxAnger = 60})
--addNewSquad({ type = "specialLand", minAnger = 40, units = { "2 corcomlvl5_scav",}, weight = 1, maxAnger = 60})
--addNewSquad({ type = "specialLand", minAnger = 40, units = { "2 legcomlvl5_scav",}, weight = 1, maxAnger = 60})
--
--addNewSquad({ type = "specialLand", minAnger = 50, units = { "2 armcomlvl6_scav",}, weight = 1, maxAnger = 70})
--addNewSquad({ type = "specialLand", minAnger = 50, units = { "2 corcomlvl6_scav",}, weight = 1, maxAnger = 70})
--addNewSquad({ type = "specialLand", minAnger = 50, units = { "2 legcomlvl6_scav",}, weight = 1, maxAnger = 70})
--
--addNewSquad({ type = "specialLand", minAnger = 60, units = { "2 armcomlvl7_scav",}, weight = 1, maxAnger = 80})
--addNewSquad({ type = "specialLand", minAnger = 60, units = { "2 corcomlvl7_scav",}, weight = 1, maxAnger = 80})
--addNewSquad({ type = "specialLand", minAnger = 60, units = { "2 legcomlvl7_scav",}, weight = 1, maxAnger = 80})
--
--addNewSquad({ type = "specialLand", minAnger = 70, units = { "2 armcomlvl8_scav",}, weight = 1, maxAnger = 90})
--addNewSquad({ type = "specialLand", minAnger = 70, units = { "2 corcomlvl8_scav",}, weight = 1, maxAnger = 90})
--addNewSquad({ type = "specialLand", minAnger = 70, units = { "2 legcomlvl8_scav",}, weight = 1, maxAnger = 90})
--
--addNewSquad({ type = "specialLand", minAnger = 80, units = { "2 armcomlvl9_scav",}, weight = 1, maxAnger = 100})
--addNewSquad({ type = "specialLand", minAnger = 80, units = { "2 corcomlvl9_scav",}, weight = 1, maxAnger = 100})
--addNewSquad({ type = "specialLand", minAnger = 80, units = { "2 legcomlvl9_scav",}, weight = 1, maxAnger = 100})
--
--addNewSquad({ type = "specialLand", minAnger = 90, units = { "2 armcomlvl10_scav",}, weight = 1, maxAnger = 1000})
--addNewSquad({ type = "specialLand", minAnger = 90, units = { "2 corcomlvl10_scav",}, weight = 1, maxAnger = 1000})
--addNewSquad({ type = "specialLand", minAnger = 90, units = { "2 legcomlvl10_scav",}, weight = 1, maxAnger = 1000})

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Settings -- Adjust these
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
local airStartAnger = 0 -- needed for air waves to work correctly.
local useScum = true -- Use scum as space where turrets can spawn (requires scum gadget from Beyond All Reason)
local useWaveMsg = true -- Show dropdown message whenever new wave is spawning
local spawnSquare = 90 -- size of the scav spawn square centered on the burrow
local spawnSquareIncrement = 2 -- square size increase for each unit spawned
local burrowSize = 144
local bossFightWaveSizeScale = 100 -- Percentage
local defaultScavFirestate = 3 -- 0 - Hold Fire | 1 - Return Fire | 2 - Fire at Will | 3 - Fire at everything

local ecoBuildingsPenalty = { -- Additional boss hatch per second from eco buildup (for 60 minutes boss time. scales to boss time)
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

local highValueTargetsNames = { -- Priority targets for Scav. Must be immobile to prevent issues.
	-- T2 Energy
	["armwint2"] = true,
	["corwint2"] = true,
	["legwint2"] = true,
	["armfus"] = true,
	["armckfus"] = true,
	["corfus"] = true,
	["armuwfus"] = true,
	["coruwfus"] = true,
	["armageo"] = true,
	["corageo"] = true,
	["armafus"] = true,
	["corafus"] = true,
	-- T2 Metal Makers
	["armmmkr"] = true,
	["cormmkr"] = true,
	["armuwmmm"] = true,
	["coruwmmm"] = true,
	-- T2 Metal Extractors
	["cormoho"] = true,
	["armmoho"] = true,
	-- Nukes
	["corsilo"] = true,
	["armsilo"] = true,
	-- Antinukes
	["armamd"] = true,
	["corfmd"] = true,
}
-- convert unitname -> unitDefID
local highValueTargets = {}
for unitName, params in pairs(highValueTargetsNames) do
	if not UnitDefNames[unitName] then
		Spring.Log(gadget:GetInfo().name, LOG.ERROR, 'couldnt find unit name: '..unitName)
	else
		highValueTargets[UnitDefNames[unitName].id] = params
	end
end
highValueTargetsNames = nil

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local config = { -- Don't touch this! ---------------------------------------------------------------------------------------------------------------------------------------------
	useScum					= useScum,
	difficulty             	= difficulty,
	difficulties           	= difficulties,
	burrowUnitsList         = BurrowUnitsList,   -- burrow unit name
	scavSpawnMultiplier 	= Spring.GetModOptions().scav_spawncountmult,
	burrowSpawnType        	= Spring.GetModOptions().scav_scavstart,
	swarmMode			   	= Spring.GetModOptions().scav_swarmmode,
	spawnSquare            	= spawnSquare,
	spawnSquareIncrement   	= spawnSquareIncrement,
	scavTurrets				= table.copy(scavTurrets),
	scavMinions				= scavMinions,
	scavBehaviours 			= scavBehaviours,
	difficultyParameters   	= difficultyParameters,
	useWaveMsg 				= useWaveMsg,
	burrowSize 				= burrowSize,
	squadSpawnOptionsTable	= squadSpawnOptionsTable,
	airStartAnger			= airStartAnger,
	ecoBuildingsPenalty		= ecoBuildingsPenalty,
	highValueTargets		= highValueTargets,
	bossFightWaveSizeScale  = bossFightWaveSizeScale,
	defaultScavFirestate 	= defaultScavFirestate,
	tierConfiguration		= tierConfiguration,
}

for key, value in pairs(difficultyParameters[difficulty]) do
	config[key] = value
end

return config
