
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
		gracePeriod       		= 9 * Spring.GetModOptions().scav_graceperiodmult * 60,
		bossTime      	  		= 55 * Spring.GetModOptions().scav_bosstimemult * 60, -- time at which the boss appears, frames
		scavSpawnRate   		= 240 * Spring.GetModOptions().scav_spawntimemult,
		burrowSpawnRate   		= 240 * Spring.GetModOptions().scav_spawntimemult,
		turretSpawnRate   		= 260 * Spring.GetModOptions().scav_spawntimemult,
		bossSpawnMult    		= 1,
		angerBonus        		= 0.1,
		maxXP			  		= 0.5,
		spawnChance       		= 0.1,
		damageMod         		= 0.5,
		maxBurrows        		= 1000,
		minScavs		  		= 5,
		maxScavs		  		= 20,
		scavPerPlayerMultiplier = 0.25,
		bossName         		= 'armscavengerbossv2_veryeasy_scav',
		bossResistanceMult   	= 0.5,
	},

	[difficulties.easy] = {
		gracePeriod       		= 8 * Spring.GetModOptions().scav_graceperiodmult * 60,
		bossTime      	  		= 50 * Spring.GetModOptions().scav_bosstimemult * 60, -- time at which the boss appears, frames
		scavSpawnRate   		= 210 * Spring.GetModOptions().scav_spawntimemult,
		burrowSpawnRate   		= 210 * Spring.GetModOptions().scav_spawntimemult,
		turretSpawnRate   		= 230 * Spring.GetModOptions().scav_spawntimemult,
		bossSpawnMult    		= 1,
		angerBonus        		= 0.15,
		maxXP			  		= 0.75,
		spawnChance       		= 0.2,
		damageMod         		= 0.75,
		maxBurrows        		= 1000,
		minScavs		  		= 10,
		maxScavs		  		= 25,
		scavPerPlayerMultiplier = 0.25,
		bossName         		= 'armscavengerbossv2_easy_scav',
		bossResistanceMult   	= 0.75,
	},
	[difficulties.normal] = {
		gracePeriod       		= 7 * Spring.GetModOptions().scav_graceperiodmult * 60,
		bossTime      	  		= 45 * Spring.GetModOptions().scav_bosstimemult * 60, -- time at which the boss appears, frames
		scavSpawnRate   		= 180 * Spring.GetModOptions().scav_spawntimemult,
		burrowSpawnRate   		= 180 * Spring.GetModOptions().scav_spawntimemult,
		turretSpawnRate   		= 200 * Spring.GetModOptions().scav_spawntimemult,
		bossSpawnMult    		= 3,
		angerBonus        		= 0.2,
		maxXP			  		= 1,
		spawnChance       		= 0.3,
		damageMod         		= 1,
		maxBurrows        		= 1000,
		minScavs		  		= 15,
		maxScavs		  		= 30,
		scavPerPlayerMultiplier = 0.25,
		bossName         		= 'armscavengerbossv2_normal_scav',
		bossResistanceMult  	= 1,
	},
	[difficulties.hard] = {
		gracePeriod       		= 6 * Spring.GetModOptions().scav_graceperiodmult * 60,
		bossTime      	  		= 40 * Spring.GetModOptions().scav_bosstimemult * 60, -- time at which the boss appears, frames
		scavSpawnRate   		= 150 * Spring.GetModOptions().scav_spawntimemult,
		burrowSpawnRate   		= 150 * Spring.GetModOptions().scav_spawntimemult,
		turretSpawnRate   		= 170 * Spring.GetModOptions().scav_spawntimemult,
		bossSpawnMult    		= 3,
		angerBonus        		= 0.25,
		maxXP			  		= 1.25,
		spawnChance       		= 0.4,
		damageMod         		= 1.25,
		maxBurrows        		= 1000,
		minScavs		  		= 20,
		maxScavs		  		= 35,
		scavPerPlayerMultiplier = 0.25,
		bossName         		= 'armscavengerbossv2_hard_scav',
		bossResistanceMult   	= 1.33,
	},
	[difficulties.veryhard] = {
		gracePeriod       		= 5 * Spring.GetModOptions().scav_graceperiodmult * 60,
		bossTime      	  		= 35 * Spring.GetModOptions().scav_bosstimemult * 60, -- time at which the boss appears, frames
		scavSpawnRate  			= 120 * Spring.GetModOptions().scav_spawntimemult,
		burrowSpawnRate   		= 120 * Spring.GetModOptions().scav_spawntimemult,
		turretSpawnRate   		= 140 * Spring.GetModOptions().scav_spawntimemult,
		bossSpawnMult    		= 3,
		angerBonus        		= 0.30,
		maxXP			  		= 1.5,
		spawnChance       		= 0.5,
		damageMod         		= 1.5,
		maxBurrows        		= 1000,
		minScavs		  		= 25,
		maxScavs		  		= 40,
		scavPerPlayerMultiplier = 0.25,
		bossName         		= 'armscavengerbossv2_veryhard_scav',
		bossResistanceMult   	= 1.67,
	},
	[difficulties.epic] = {
		gracePeriod       		= 4 * Spring.GetModOptions().scav_graceperiodmult * 60,
		bossTime      	  		= 30 * Spring.GetModOptions().scav_bosstimemult * 60, -- time at which the boss appears, frames
		scavSpawnRate   		= 90 * Spring.GetModOptions().scav_spawntimemult,
		burrowSpawnRate   		= 90 * Spring.GetModOptions().scav_spawntimemult,
		turretSpawnRate   		= 110 * Spring.GetModOptions().scav_spawntimemult,
		bossSpawnMult    		= 3,
		angerBonus        		= 0.35,
		maxXP			  		= 2,
		spawnChance       		= 0.6,
		damageMod         		= 2,
		maxBurrows        		= 1000,
		minScavs		  		= 30,
		maxScavs		  		= 50,
		scavPerPlayerMultiplier = 0.25,
		bossName         		= 'armscavengerbossv2_epic_scav',
		bossResistanceMult   	= 2,
	},

}

local burrowName = 'scavengerdroppodbeacon_scav'

--[[
	So here we define lists of units from which behaviours tables and spawn tables are created dynamically.
	We're setting up 5 levels representing the below:

	Level 1 - Tech 0 - very early game crap, stuff that players usually build first in their games. pawns and grunts, scouts, etc.
	Level 2 - Tech 1 - at this point we're introducing what remains of T1, basically late stage T1, but it's not T2 yet
	Level 3 - Tech 2 - early/cheap Tech 2 units. we're putting expensive T2's later for smoother progression
	Level 4 - Tech 2.5 - Here we're introducing all the expensive late T2 equipment.
	Level 5 - Tech 3 - Here we introduce the cheaper T3 units
	Level 6 - Tech 3.5/Tech 4 - The most expensive units in the game, spawned in the endgame, right before and alongside the final boss

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

local TierConfiguration = { -- Double for basic squads
	[1] = {minAnger = 0,  maxAnger = 25, 	maxSquadSize = 20},
	[2] = {minAnger = 10, maxAnger = 40, 	maxSquadSize = 15},
	[3] = {minAnger = 25, maxAnger = 60, 	maxSquadSize = 10},
	[4] = {minAnger = 40, maxAnger = 80, 	maxSquadSize = 5},
	[5] = {minAnger = 60, maxAnger = 100, 	maxSquadSize = 3},
	[6] = {minAnger = 80, maxAnger = 1000, 	maxSquadSize = 1},
}

----------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------

local LandUnitsList = {
	Raid = {
		[1] = {
			--Armada
			["armada_tick_scav"] = 1,
			["armada_pawn_scav"] = 1,
			["armada_rover_scav"] = 1,
			["armada_seeker_scav"] = 1,
			--Cortex
			["cortex_grunt_scav"] = 1,
			["corfav_scav"] = 1,
			["corsh_scav"] = 1,
			--Legion
			["leggob_scav"] = 1,
		},
		[2] = {
			--Armada
			["armada_blitz_scav"] = 1,
			["armzapper_scav"] = 1,
			--Cortex
			["corgator_scav"] = 1,
			--Legion
			["leghades_scav"] = 1,
		},
		[3] = {
			--Armada
			["armada_jaguar_scav"] = 1,
			["armada_amphibiousbot_scav"] = 1,
			["armada_sprinter_scav"] = 1,
			--Cortex
			["cortorch_scav"] = 1,
			["corsala_scav"] = 1,
			["cortex_fiend_scav"] = 1,
			["corseal_scav"] = 1,
			["cortex_duck_scav"] = 1,
			--Legion
			["legmrv_scav"] = 1,
			["legstr_scav"] = 1,
		},
		[4] = {
			--Armada

			--Cortex

			--Legion


		},
		[5] = {
			--Armada
			["armada_pawnt4_scav"] = 1,
			["armada_marauder_scav"] = 1,
			--Cortex
			["cortex_gruntt4_scav"] = 1,
			--Legion
			--N/A
		},
		[6] = {
			--Armada
			["armada_razorback_scav"] = 1,
			--Cortex
			["cordemon_scav"] = 1,
			--Legion
			--N/A
		},
	},
	Assault = {
		[1] = {
			--Armada
			["armada_mace_scav"] = 1,
			["armada_pincer_scav"] = 1,
			--Cortex
			["cortex_thug_scav"] = 1,
			["corgarp_scav"] = 1,
			--Legion
			["legcen_scav"] = 1,
			["leglob_scav"] = 1,
		},
		[2] = {
			--Armada
			["armada_centurion_scav"] = 1,
			["armada_stout_scav"] = 1,
			["armada_janus_scav"] = 1,
			["armada_crocodile_scav"] = 1,
			--Cortex
			["corraid_scav"] = 1,
			["corlevlr_scav"] = 1,
			["corhal_scav"] = 1,
			["corsnap_scav"] = 1,
			--Legion
			["leggat_scav"] = 1,
			["legkark_scav"] = 1,
		},
		[3] = {
			--Armada
			["armada_welder_scav"] = 1,
			--Cortex
			["cortex_sumo_scav"] = 1,
			--Legion
			["legshot_scav"] = 1,

		},
		[4] = {
			--Armada
			["armada_sharpshooter_scav"] = 1,
			["armada_tumbleweed_scav"] = 1,
			["armada_recluse_scav"] = 1,
			["armada_bull_scav"] = 1,
			["armada_turtle_scav"] = 1,
			--Cortex
			["corparrow_scav"] = 1,
			["corftiger_scav"] = 1,
			["corgol_scav"] = 1,
			["cortex_bedbug_scav"] = 1,
			["cortex_skuttle_scav"] = 1,
			["cortex_termite_scav"] = 1,
			["cortex_mammoth_scav"] = 1,
			["correap_scav"] = 1,
			["corgatreap_scav"] = 1,
			--Legion
			["legsco_scav"] = 1,
			["leginc_scav"] = 1,
		},
		[5] = {
			--Armada
			["armassimilator_scav"] = 1,
			["armmeatball_scav"] = 1,
			["armada_lunkhead_scav"] = 1,
			--Cortex
			["corshiva_scav"] = 1,
			["corkarg_scav"] = 1,
			["corthermite"] = 1,
			["corsok_scav"] = 1,
			--Legion
			--N/A
		},
		[6] = {
			--Armada
			["armada_thor_scav"] = 1,
			["armada_titan_scav"] = 1,
			["armrattet4_scav"] = 1,
			["armada_tumbleweedt4_scav"] = 1,
			["armada_recluset4_scav"] = 1,
			--Cortex
			["corjugg_scav"] = 1,
			["corkorg_scav"] = 1,
			["corkarganetht4_scav"] = 1,
			["corgolt4_scav"] = 1,
			--Legion
			["legpede_scav"] = 1,
		},
	},
	Support = {
		[1] = {
			--Armada
			["armada_rocketeer_scav"] = 1,
			["armada_crossbow_scav"] = 1,
			["armada_sweeper_scav"] = 1,
			--Cortex
			["cortex_aggravator_scav"] = 1,
			["cortex_trasher_scav"] = 1,
			["corah_scav"] = 1,
			--Legion
			["legbal_scav"] = 1,
		},
		[2] = {
			--Armada
			["armada_shellshocker_scav"] = 1,
			["armada_whistler_scav"] = 1,
			["armada_possum_scav"] = 1,
			--Cortex
			["corwolv_scav"] = 1,
			["cormist_scav"] = 1,
			["cormh_scav"] = 1,
			--Legion
			["leghelios_scav"] = 1,
			["legbar_scav"] = 1,
			["legrail_scav"] = 1,
		},
		[3] = {
			--Armada
			["armada_hound_scav"] = 1,
			["armada_archangel_scav"] = 1,
			["armada_gunslinger_scav"] = 1,
			["armada_shredder_scav"] = 1,
			["armada_mauser_scav"] = 1,
			--Cortex
			["cormart_scav"] = 1,
			["corsent_scav"] = 1,
			["cortex_manticore_scav"] = 1,
			["cortex_sheldon_scav"] = 1,
			--Legion
			["legvcarry_scav"] = 1,
			["legbart_scav"] = 1,

		},
		[4] = {
			--Armada
			["armada_fatboy_scav"] = 1,
			["armada_starlight_scav"] = 1,
			["armada_ambassador_scav"] = 1,
			--Cortex
			["corban_scav"] = 1,
			["corvroc_scav"] = 1,
			["cortrem_scav"] = 1,
			["cortex_arbiter_scav"] = 1,
			--Legion
			["leginf_scav"] = 1,

		},
		[5] = {
			--Armada
			["armada_vanguard_scav"] = 1,
			["armada_dronecarrierland_scav"] = 1,
			["armada_umbrella_scav"] = 1,
			--Cortex
			["cortex_catapult_scav"] = 1,
			["cormabm_scav"] = 1,
			--Legion
		},
		[6] = {
			--Armada

			--Cortex

			--Legion
			--N/A
		},
	},
	Healer = {
		[1] = {
			--Armada

			--Cortex

			--Legion
		},
		[2] = {
			--Armada
			["armada_constructionbot_scav"] = 1,
			["armada_lazarus_scav"] = 20,
			["armada_constructionvehicle_scav"] = 1,
			--Cortex
			["cortex_constructionbot_scav"] = 1,
			["cortex_graverobber_scav"] = 20,
			["corcv_scav"] = 1,
			--Legion
			["legcv_scav"] = 1,
			["legck_scav"] = 1,
		},
		[3] = {
			--Armada
			["armada_advancedconstructionbot_scav"] = 1,
			["armada_advancedconstructionvehicle_scav"] = 1,
			["armada_butler_scav"] = 1,
			["armada_decoycommander_scav"] = 1,
			["armada_consul_scav"] = 1,
			--Cortex
			["cortex_advancedconstructionbot_scav"] = 1,
			["coracv_scav"] = 1,
			["cortex_twitcher_scav"] = 1,
			["cortex_decoycommander_scav"] = 1,
			["cortex_commando_scav"] = 1,
			["corforge_scav"] = 1,
			--Legion
			["legacv_scav"] = 1,
			["legack_scav"] = 1,

		},
		[4] = {
			--Armada

			--Cortex

			--Legion

		},
		[5] = {
			--Armada

			--Cortex

			--Legion
		},
		[6] = {
			--Armada

			--Cortex

			--Legion
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
		["armada_dolphin_scav"] = 1,
		--Cortex
		["coresupp_scav"] = 1,
		},
		[2] = {
		--Armada

		--Cortex

		},
		[3] = {
		--Armada
		["armada_lightningship_scav"] = 1,
		--Cortex
		["corfship_scav"] = 1,
		},
		[4] = {
		--Armada
		["armada_barracuda_scav"] = 1,
		--Cortex
		["corshark_scav"] = 1,
		},
		[5] = {
		--Armada

		--Cortex

		},
		[6] = {
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
		["armada_ellysaw_scav"] = 1,
		["armada_corsair_scav"] = 1,
		--Cortex
		["corpship_scav"] = 1,
		["corroy_scav"] = 1,
		},
		[3] = {
		--Armada
		["armada_paladin_scav"] = 1,
		--Cortex
		["corcrus_scav"] = 1,
		},
		[4] = {
		--Armada
		["armada_dreadnought_scav"] = 1,
		--Cortex
		["corbats_scav"] = 1,
		},
		[5] = {
		--Armada
		["armada_ellysawt3_scav"] = 1,
		["armada_skatert2_scav"] = 1,
		--Cortex
		["corblackhy_scav"] = 1,
		},
		[6] = {
		--Armada
		["armada_epoch_scav"] = 1,
		["armada_serpentt3_scav"] = 1,
		--Cortex
		["coresuppt3_scav"] = 1,
		},
	},
	Support = {
		[1] = {
		--Armada
		["armada_skater_scav"] = 1,
		--Cortex
		["corpt_scav"] = 1,
		},
		[2] = {
		--Armada
		["armada_eel_scav"] = 1,
		--Cortex
		["corsub_scav"] = 1,
		},
		[3] = {
		--Armada
		["armada_haven2_scav"] = 1,
		["armada_t2supportship_scav"] = 1,
		["armada_dronecarrier_scav"] = 1,
		["armada_dragonslayer_scav"] = 1,
		--Cortex
		["cortex_dronecarrier_scav"] = 1,
		["corantiship_scav"] = 1,
		["cortex_oasis2_scav"] = 1,
		["corarch_scav"] = 1,
		},
		[4] = {
		--Armada
		["armada_serpent_scav"] = 1,
		["armada_longbow_scav"] = 1,
		["armada_bermuda_scav"] = 1,
		--Cortex
		["corssub_scav"] = 1,
		["cormship_scav"] = 1,
		["corsjam_scav"] = 1,
		},
		[5] = {
		--Armada

		--Cortex

		},
		[6] = {
		--Armada
		["armada_dolphint3_scav"] = 1,
		--Cortex
		["corslrpc_scav"] = 1,
		},
	},
	Healer = {
		[1] = {
		--Armada

		--Cortex

		},
		[2] = {
		--Armada
		["armada_constructionship_scav"] = 1,
		["armada_grimreaper_scav"] = 1,
		--Cortex
		["corcs_scav"] = 1,
		["correcl_scav"] = 1,
		},
		[3] = {
		--Armada
		["armada_advancedconstructionsub_scav"] = 1,
		["armada_voyager_scav"] = 1,
		--Cortex
		["coracsub_scav"] = 1,
		["cormls_scav"] = 1,
		},
		[4] = {
		--Armada

		--Cortex
		},
		[5] = {
		--Armada

		--Cortex
		},
		[6] = {
		--Armada

		--Cortex
		},
	},
}

----------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------

local AirUnitsList = {
	[1] = {
	--Armada
	["armada_blink_scav"] = 1,
	["armada_horizon_scav"]= 1,
	--Cortex
	["corfink_scav"] = 1,
	["cortex_shuriken_scav"] = 1,
	["corhunt_scav"] = 1,
	--Legion
	["legfig_scav"] = 1,

	},
	[2] = {
	--Armada
	["armada_constructionaircraft_scav"] = 1,
	["armada_falcon_scav"] = 1,
	["armada_banshee_scav"] = 1,
	["armada_stormbringer_scav"] = 1,
	["armada_cyclone_scav"] = 1,
	["armada_constructionseaplane_scav"] = 1,
	--Cortex
	["cortex_constructionaircraft_scav"] = 1,
	["cortex_valiant_scav"] = 1,
	["cortex_whirlwind_scav"] = 1,
	["corsfig_scav"] = 1,
	["corcsa_scav"] = 1,
	--Legion
	["legca_scav"] = 1,
	["legmos_scav"] = 1,
	["legcib_scav"] = 1,
	["legkam_scav"] = 1,

	},
	[3] = {
	--Armada
	["armada_advancedconstructionaircraft_scav"] = 1,
	["armada_oracle_scav"] = 1,
	["armada_sabre_scav"] = 1,
	["armada_puffin_scav"] = 1,
	["armada_tsunami_scav"] = 1,
	["armada_cormorant_scav"] = 1,
	--Cortex
	["cortex_advancedconstructionaircraft_scav"] = 1,
	["cortex_condor_scav"] = 1,
	["corcut_scav"] = 1,
	["corsb_scav"] = 1,
	["corseap_scav"] = 1,
	["cortex_angler_scav"] = 1,
	--Legion
	["legaca_scav"] = 1,
	},
	[4] = {
	--Armada
	["armada_highwind_scav"] = 1,
	["armada_roughneck_scav"] = 1,
	["armada_blizzard_scav"] = 1,
	["armada_stiletto_scav"] = 1,
	["armada_hornet_scav"] = 1,
	["armada_liche_scav"] = 1,
	--Cortex
	["cortex_nighthawk_scav"] = 1,
	["cortex_wasp_scav"] = 1,
	["cortex_hailstorm_scav"] = 1,
	["cortex_dragonold_scav"] = 1,
	--Legion
	["legnap_scav"] = 1,
	["legmineb_scav"] = 1,
	["legfort_scav"] = 1,
	},
	[5] = {
	--Armada
	["armada_stormbringert4_scav"] = 1,
	--Cortex
	["cortex_flyingdronecarrier_scav"] = 1,
	--Legion
	--N/A
	},
	[6] = {
	--Armada
	["armfepocht4_scav"] = 1,
	["armada_lichet4_scav"] = 1,
	--Cortex
	["corfblackhyt4_scav"] = 1,
	["cortex_dragont4_scav"] = 1,
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
		["armada_sentry_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.6, maxExisting = 10},
		["corllt_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.6, maxExisting = 10},
		["armada_nettle_scav"] = {type = "antiair", surface = "land", spawnedPerWave = 0.6, maxExisting = 10},
		["corrl_scav"] = {type = "antiair", surface = "land", spawnedPerWave = 0.6, maxExisting = 10},
		--["cordl_scav"] = {type = "normal", surface = "mixed", spawnedPerWave = 0.6, maxExisting = 1},
		--["armada_anemone_scav"] = {type = "normal", surface = "mixed", spawnedPerWave = 0.6, maxExisting = 1},
		--Sea Only
		["armada_manta_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.6, maxExisting = 5},
		["corfhlt_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.6, maxExisting = 5},
		["armada_navalnettle_scav"] = {type = "antiair", surface = "sea", spawnedPerWave = 0.6, maxExisting = 2},
		["corfrt_scav"] = {type = "antiair", surface = "sea", spawnedPerWave = 0.6, maxExisting = 2},
		["cortl_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.6, maxExisting = 4},
		["armada_harpoon_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.6, maxExisting = 4},
		["armada_scumbag_scav"] = {type = "antiair", surface = "sea", spawnedPerWave = 0.6, maxExisting = 2},
		["corfrock_scav"] = {type = "antiair", surface = "sea", spawnedPerWave = 0.6, maxExisting = 2},
		["corgplat_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.6, maxExisting = 5},
		["armada_gunplatform_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.6, maxExisting = 5},
	},
	[2] = {
		["armada_beamer_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.5, maxExisting = 5},
		["corhllt_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.5, maxExisting = 5},
		["cormaw_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.5, maxExisting = 4},
		["armada_dragonsclaw_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.5, maxExisting = 4},
		["armada_ferret_scav"] = {type = "antiair", surface = "land", spawnedPerWave = 0.5, maxExisting = 3},
		["cormadsam_scav"] = {type = "antiair", surface = "land", spawnedPerWave = 0.5, maxExisting = 5},
		["corhlt_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.5, maxExisting = 3},
		["corpun_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.5, maxExisting = 2},
		["armada_overwatch_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.5, maxExisting = 5},
		["armada_gauntlet_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.5, maxExisting = 3},
		["corscavdtl_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.5, maxExisting = 3},
		["corscavdtf_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.5, maxExisting = 3},
		["corscavdtm_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.5, maxExisting = 3},
		["legdefcarryt1_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.5, maxExisting = 3},
		--radar/jam
		["corrad_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.5, maxExisting = 2},
		["corjamt_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.5, maxExisting = 2},
		["armada_radartower_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.5, maxExisting = 2},
		["armada_sneakypete_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.5, maxExisting = 2},
		["armada_juno_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.5, maxExisting = 2},
		["corjuno_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.5, maxExisting = 2},
	},
	[3] = {
		["armada_chainsaw_scav"] = {type = "antiair", surface = "land", spawnedPerWave = 0.4, maxExisting = 3},
		["corerad_scav"] = {type = "antiair", surface = "land", spawnedPerWave = 0.4, maxExisting = 3},
		--Sea
		["corfdoom_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.4, maxExisting = 5},
		["coratl_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.4, maxExisting = 5},
		["corenaa_scav"] = {type = "antiair", surface = "sea", spawnedPerWave = 0.4, maxExisting = 5},
		["corason_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.4, maxExisting = 0.4},
		["armada_gorgon_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.4, maxExisting = 5},
		["armada_navalarbalest_scav"] = {type = "antiair", surface = "sea", spawnedPerWave = 0.4, maxExisting = 5},
		["armada_moray_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.4, maxExisting = 5},
		["armada_advancedsonarstation_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.4, maxExisting = 0.4},
		--T2 Radar/jam
		["corarad_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.4, maxExisting = 2},
		["corshroud_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.4, maxExisting = 2},
		["armada_advancedradartower_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.4, maxExisting = 2},
		["armada_veil_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.4, maxExisting = 2},
		--T2 Popups
		["armlwall_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.4, maxExisting = 3},
		["cormwall_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.4, maxExisting = 3},
		["armada_pitbull_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.4, maxExisting = 3},
		["corvipe_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.4, maxExisting = 3},
		--Misc
		["corhllllt_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.4, maxExisting = 3},
		["armada_keeper_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.4, maxExisting = 2},
		["corgate_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.4, maxExisting = 2},
		--T2 AA
		["corflak_scav"] = {type = "antiair", surface = "land", spawnedPerWave = 0.4, maxExisting = 4},
		["armada_arbalest_scav"] = {type = "antiair", surface = "land", spawnedPerWave = 0.4, maxExisting = 4},
	},
	[4] = {
		-- T2 popup arty
		["armada_rattlesnake_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.3, maxExisting = 2},
		["cortoast_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.3, maxExisting = 2},
		-- Pulsar and Bulwark normals
		["armada_pulsar_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.3, maxExisting = 2},
		["cordoom_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.3, maxExisting = 2},
		--LRPC
		["armada_basilica_scav"] = {type = "lrpc", surface = "land", spawnedPerWave = 0.3, maxExisting = 2},
		["corint_scav"] = {type = "lrpc", surface = "land", spawnedPerWave = 0.3, maxExisting = 2},
		--antinukes
		["armada_citadel_scav"] = {type = "nuke", surface = "land", spawnedPerWave = 0.3, maxExisting = 2},
		["corfmd_scav"] = {type = "nuke", surface = "land", spawnedPerWave = 0.3, maxExisting = 2},
		--Tactical Weapons
		["cortron_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.3, maxExisting = 2},
		["armada_paralyzer_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.3, maxExisting = 2},
		--T2 AA
		["armada_mercury_scav"] = {type = "antiair", surface = "land", spawnedPerWave = 0.3, maxExisting = 2},
		["corscreamer_scav"] = {type = "antiair", surface = "land", spawnedPerWave = 0.3, maxExisting = 2},
	},
	[5] = {
		-- nukes
		["corsilo_scav"] = {type = "nuke", surface = "land", spawnedPerWave = 0.2, maxExisting = 1},
		["armada_armageddon_scav"] = {type = "nuke", surface = "land", spawnedPerWave = 0.2, maxExisting = 1},

		["armminivulc_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.2, maxExisting = 3},
		["corminibuzz_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.2, maxExisting = 3},
		["armbotrail_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.2, maxExisting = 2},
	},
	[6] = {
		--Epic Bulwark and Pulsar/rag/cal
		["armada_pulsart3_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 3},
		["cordoomt3_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 3},
		["armada_ragnarok_scav"] = {type = "lrpc", surface = "land", spawnedPerWave = 0.1, maxExisting = 1},
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
				minBossAnger = TierConfiguration[tier].minAnger,
				spawnedPerWave = turretInfo.spawnedPerWave or 1,
				maxExisting = turretInfo.maxExisting or 10,
				maxBossAnger = turretInfo.maxBossAnger or 1000,
				surfaceType = turretInfo.surface or "land",
			}
		end
	end
end

scavBehaviours = {
	SKIRMISH = { -- Run away from target after target gets hit

	},
	COWARD = { -- Run away from target after getting hit by enemy

	},
	BERSERK = { -- Run towards target after getting hit by enemy or after hitting the target
		[UnitDefNames["armscavengerbossv2_veryeasy_scav"].id]	= { distance = 2000, chance = 0.001},
		[UnitDefNames["armscavengerbossv2_easy_scav"].id] 		= { distance = 2000, chance = 0.001},
		[UnitDefNames["armscavengerbossv2_normal_scav"].id] 	= { distance = 2000, chance = 0.001},
		[UnitDefNames["armscavengerbossv2_hard_scav"].id] 		= { distance = 2000, chance = 0.001},
		[UnitDefNames["armscavengerbossv2_veryhard_scav"].id] 	= { distance = 2000, chance = 0.001},
		[UnitDefNames["armscavengerbossv2_epic_scav"].id]		= { distance = 2000, chance = 0.001},
	},
	HEALER = { -- Getting long max lifetime and always use Fight command. These units spawn as healers from burrows and boss
		--[UnitDefNames["raptor_land_swarmer_heal_t1_v1"].id] = true,
		[UnitDefNames["armada_lazarus_scav"].id] = true,--Armada Rezzer
		[UnitDefNames["cortex_graverobber_scav"].id] = true,--Cortex Rezzer
	},
	ARTILLERY = { -- Long lifetime and no regrouping, always uses Fight command to keep distance
		--[UnitDefNames["raptor_allterrain_arty_basic_t2_v1"].id] = true,
	},
	KAMIKAZE = { -- Long lifetime and no regrouping, always uses Move command to rush into the enemy
		--[UnitDefNames["raptor_land_kamikaze_basic_t2_v1"].id] = true,
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
	specialLand = {}, -- 33% spawn chance, there's 1% chance of Special squad spawning Super squad, which is specials but 30% anger earlier.
	specialSea = {}, -- 33% spawn chance, there's 1% chance of Special squad spawning Super squad, which is specials but 30% anger earlier.
	healerLand = {}, -- Healers/Medics
	healerSea = {}, -- Healers/Medics
	airLand = {},
	airSea = {},
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
		local unitWeight = LandUnitsList.Raid[tier][unitName]
		-- Spring.Echo(unitName)
		addNewSquad({ type = "basicLand", minAnger = TierConfiguration[tier].minAnger*2, units = { TierConfiguration[tier].maxSquadSize .. " " .. unitName}, weight = unitWeight, maxAnger = TierConfiguration[tier].maxAnger*2 })
		addNewSquad({ type = "specialLand", minAnger = TierConfiguration[tier].minAnger, units = { TierConfiguration[tier].maxSquadSize .. " " .. unitName}, weight = unitWeight, maxAnger = TierConfiguration[tier].maxAnger })
	end
end

for tier, _ in pairs(LandUnitsList.Assault) do
	for unitName, _ in pairs(LandUnitsList.Assault[tier]) do
		local unitWeight = LandUnitsList.Assault[tier][unitName]
		-- Spring.Echo(unitName)
		if not scavBehaviours.BERSERK[UnitDefNames[unitName].id] then
			scavBehaviours.BERSERK[UnitDefNames[unitName].id] = {distance = 2000, chance = 0.01}
		end
		addNewSquad({ type = "basicLand", minAnger = TierConfiguration[tier].minAnger*2, units = { TierConfiguration[tier].maxSquadSize .. " " .. unitName}, weight = unitWeight, maxAnger = TierConfiguration[tier].maxAnger*2 })
		addNewSquad({ type = "specialLand", minAnger = TierConfiguration[tier].minAnger, units = { TierConfiguration[tier].maxSquadSize .. " " .. unitName}, weight = unitWeight, maxAnger = TierConfiguration[tier].maxAnger })
	end
end

for tier, _ in pairs(LandUnitsList.Support) do
	for unitName, _ in pairs(LandUnitsList.Support[tier]) do
		local unitWeight = LandUnitsList.Support[tier][unitName]
		-- Spring.Echo(unitName)
		if not scavBehaviours.SKIRMISH[UnitDefNames[unitName].id] then
			scavBehaviours.SKIRMISH[UnitDefNames[unitName].id] = {distance = 500, chance = 0.1}
			scavBehaviours.COWARD[UnitDefNames[unitName].id] = {distance = 500, chance = 0.75}
			scavBehaviours.ARTILLERY[UnitDefNames[unitName].id] = true
		end
		addNewSquad({ type = "basicLand", minAnger = TierConfiguration[tier].minAnger*2, units = { TierConfiguration[tier].maxSquadSize .. " " .. unitName}, weight = unitWeight, maxAnger = TierConfiguration[tier].maxAnger*2 })
		addNewSquad({ type = "specialLand", minAnger = TierConfiguration[tier].minAnger, units = { TierConfiguration[tier].maxSquadSize .. " " .. unitName}, weight = unitWeight, maxAnger = TierConfiguration[tier].maxAnger })
	end
end

for tier, _ in pairs(LandUnitsList.Healer) do
	for unitName, _ in pairs(LandUnitsList.Healer[tier]) do
		local unitWeight = LandUnitsList.Healer[tier][unitName]
		-- Spring.Echo(unitName)
		if not scavBehaviours.HEALER[UnitDefNames[unitName].id] then
			scavBehaviours.HEALER[UnitDefNames[unitName].id] = true
			if not scavBehaviours.SKIRMISH[UnitDefNames[unitName].id] then
				scavBehaviours.SKIRMISH[UnitDefNames[unitName].id] = {distance = 500, chance = 0.1}
				scavBehaviours.COWARD[UnitDefNames[unitName].id] = {distance = 500, chance = 0.75}
			end
		end
		addNewSquad({ type = "healerLand", minAnger = TierConfiguration[tier].minAnger, units = { TierConfiguration[tier].maxSquadSize .. " " .. unitName}, weight = unitWeight, maxAnger = TierConfiguration[tier].maxAnger })
	end
end

--------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------- SEA
--------------------------------------------------------------------------------------------------------------------------------------------------------

for tier, _ in pairs(SeaUnitsList.Raid) do
	for unitName, _ in pairs(SeaUnitsList.Raid[tier]) do
		local unitWeight = SeaUnitsList.Raid[tier][unitName]
		-- Spring.Echo(unitName)
		addNewSquad({ type = "basicSea", minAnger = TierConfiguration[tier].minAnger*2, units = { TierConfiguration[tier].maxSquadSize .. " " .. unitName}, weight = unitWeight, maxAnger = TierConfiguration[tier].maxAnger*2 })
		addNewSquad({ type = "specialSea", minAnger = TierConfiguration[tier].minAnger, units = { TierConfiguration[tier].maxSquadSize .. " " .. unitName}, weight = unitWeight, maxAnger = TierConfiguration[tier].maxAnger })
	end
end

for tier, _ in pairs(SeaUnitsList.Assault) do
	for unitName, _ in pairs(SeaUnitsList.Assault[tier]) do
		local unitWeight = SeaUnitsList.Assault[tier][unitName]
		-- Spring.Echo(unitName)
		if not scavBehaviours.BERSERK[UnitDefNames[unitName].id] then
			scavBehaviours.BERSERK[UnitDefNames[unitName].id] = {distance = 2000, chance = 0.01}
		end
		addNewSquad({ type = "basicSea", minAnger = TierConfiguration[tier].minAnger*2, units = { TierConfiguration[tier].maxSquadSize .. " " .. unitName}, weight = unitWeight, maxAnger = TierConfiguration[tier].maxAnger*2 })
		addNewSquad({ type = "specialSea", minAnger = TierConfiguration[tier].minAnger, units = { TierConfiguration[tier].maxSquadSize .. " " .. unitName}, weight = unitWeight, maxAnger = TierConfiguration[tier].maxAnger })
	end
end

for tier, _ in pairs(SeaUnitsList.Support) do
	for unitName, _ in pairs(SeaUnitsList.Support[tier]) do
		local unitWeight = SeaUnitsList.Support[tier][unitName]
		-- Spring.Echo(unitName)
		if not scavBehaviours.SKIRMISH[UnitDefNames[unitName].id] then
			scavBehaviours.SKIRMISH[UnitDefNames[unitName].id] = {distance = 500, chance = 0.1}
			scavBehaviours.COWARD[UnitDefNames[unitName].id] = {distance = 500, chance = 0.75}
			scavBehaviours.ARTILLERY[UnitDefNames[unitName].id] = true
		end
		addNewSquad({ type = "basicSea", minAnger = TierConfiguration[tier].minAnger*2, units = { TierConfiguration[tier].maxSquadSize .. " " .. unitName}, weight = unitWeight, maxAnger = TierConfiguration[tier].maxAnger*2 })
		addNewSquad({ type = "specialSea", minAnger = TierConfiguration[tier].minAnger, units = { TierConfiguration[tier].maxSquadSize .. " " .. unitName}, weight = unitWeight, maxAnger = TierConfiguration[tier].maxAnger })
	end
end

for tier, _ in pairs(SeaUnitsList.Healer) do
	for unitName, _ in pairs(SeaUnitsList.Healer[tier]) do
		local unitWeight = SeaUnitsList.Healer[tier][unitName]
		-- Spring.Echo(unitName)
		if not scavBehaviours.HEALER[UnitDefNames[unitName].id] then
			scavBehaviours.HEALER[UnitDefNames[unitName].id] = true
		end
		addNewSquad({ type = "healerSea", minAnger = TierConfiguration[tier].minAnger, units = { TierConfiguration[tier].maxSquadSize .. " " .. unitName}, weight = unitWeight, maxAnger = TierConfiguration[tier].maxAnger })
	end
end

--------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------- AIR
--------------------------------------------------------------------------------------------------------------------------------------------------------

for tier, _ in pairs(AirUnitsList) do
	for unitName, _ in pairs(AirUnitsList[tier]) do
		local unitWeight = AirUnitsList[tier][unitName]
		-- Spring.Echo(unitName)
		addNewSquad({ type = "airLand", minAnger = TierConfiguration[tier].minAnger, units = { TierConfiguration[tier].maxSquadSize .. " " .. unitName}, weight = unitWeight, maxAnger = TierConfiguration[tier].maxAnger })
		addNewSquad({ type = "airSea", minAnger = TierConfiguration[tier].minAnger, units = { TierConfiguration[tier].maxSquadSize .. " " .. unitName}, weight = unitWeight, maxAnger = TierConfiguration[tier].maxAnger })
	end
end

------Tier 1 0-25% (Land and Airland)
addNewSquad({ type = "healerLand", minAnger = 0, units = { "6 armada_lazarus_scav","6 cortex_graverobber_scav",}, weight = 8, maxAnger = 1000}) --Rezzers/Entire Game
--Land
addNewSquad({ type = "basicLand", minAnger = 0, units = { "20 armada_rover_scav","20 corfav_scav",}, weight = 6, maxAnger = 25}) --Rovers/Whole Tier Length
addNewSquad({ type = "basicLand", minAnger = 5, units = { "6 armada_blitz_scav","6 corgator_scav","6 leghelios_scav",}, weight = 4, maxAnger = 20}) --T1 Veh Raid
addNewSquad({ type = "basicLand", minAnger = 5, units = { "5 armada_stout_scav","5 corraid_scav","5 leggat_scav",}, weight = 4, maxAnger = 25}) --T1 Veh Assault
addNewSquad({ type = "basicLand", minAnger = 10, units = { "2 armada_janus_scav","2 corlevlr_scav","2 legrail_scav",}, weight = 4, maxAnger = 25}) --T1 Veh Unique
addNewSquad({ type = "basicLand", minAnger = 10, units = { "1 armada_shellshocker_scav","2 armada_whistler_scav","1 corwolv_scav","2 cormist_scav","2 legbar_scav"}, weight = 4, maxAnger = 25}) --T1 Arty/AA
--AirLand
addNewSquad({ type = "airLand", minAnger = 10, units = { "3 armada_blink_scav","3 corfink_scav","9 legfig_scav",}, weight = 4, maxAnger = 20}) --T1 Air Scouts
addNewSquad({ type = "airLand", minAnger = 10, units = { "12 cortex_shuriken_scav",}, weight = 4, maxAnger = 20}) --Bladewings
addNewSquad({ type = "airLand", minAnger = 15, units = { "20 armada_falcon_scav","20 cortex_valiant_scav",}, weight = 4, maxAnger = 25}) --Fighters
addNewSquad({ type = "airLand", minAnger = 15, units = { "12 armada_stormbringer_scav","12 cortex_whirlwind_scav","5 legcib_scav",}, weight = 4, maxAnger = 25}) --Bombers
------Tier 2 25-60%
addNewSquad({ type = "basicLand", minAnger = 25, units = { "10 armada_rover_scav","10 corfav_scav","25 armzapper_scav",}, weight = 6, maxAnger = 60}) --Rover and EMP Rover/Whole Tier Length
--Land
addNewSquad({ type = "basicLand", minAnger = 30, units = { "6 armada_jaguar_scav","6 cortorch_scav","6 legmrv_scav",}, weight = 4, maxAnger = 55}) --T2 Veh Raid
addNewSquad({ type = "basicLand", minAnger = 30, units = { "6 armada_bull_scav","6 correap_scav","1 corgol_scav","5 legsco_scav","2 armada_shredder_scav","2 corsent_scav",}, weight = 4, maxAnger = 60}) --T2 Veh Assault/AA
addNewSquad({ type = "basicLand", minAnger = 40, units = { "2 armada_starlight_scav","2 corban_scav","1 legvcarry_scav",}, weight = 4, maxAnger = 60}) --T2 Veh Unique
addNewSquad({ type = "basicLand", minAnger = 40, units = { "3 armada_mauser_scav","1 armada_ambassador_scav","1 armada_shredder_scav","3 cormart_scav","1 corvroc_scav","1 corsent_scav","1 leginf_scav",}, weight = 4, maxAnger = 60}) --T2 Arty/AA
--AirLand
addNewSquad({ type = "airLand", minAnger = 40, units = { "3 armada_oracle_scav","3 cortex_condor_scav",}, weight = 4, maxAnger = 50}) --T2 Air Scouts
addNewSquad({ type = "airLand", minAnger = 40, units = { "2 armada_stiletto_scav",}, weight = 4, maxAnger = 50}) --EMP Bombers
addNewSquad({ type = "airLand", minAnger = 50, units = { "20 armada_highwind_scav","20 cortex_nighthawk_scav",}, weight = 4, maxAnger = 60}) --Fighters
addNewSquad({ type = "airLand", minAnger = 50, units = { "1 armada_hornet_scav","15 armada_roughneck_scav","1 legfort_scav","1 cortex_dragonold_scav","15 cortex_wasp_scav"}, weight = 4, maxAnger = 60}) --T2 Gunships
------Tier 3 60-80%
--Dilluters
addNewSquad({ type = "basicLand", minAnger = 60, units = { "15 armada_rover_scav","15 corfav_scav",}, weight = 8, maxAnger = 1000}) --Rover Whole Tier Length
addNewSquad({ type = "basicLand", minAnger = 60, units = { "6 cortorch_scav","6 legmrv_scav",}, weight = 3, maxAnger = 1000}) --T2 Veh Raid
--Land
addNewSquad({ type = "basicLand", minAnger = 60, units = { "12 armada_marauder_scav",}, weight = 3, maxAnger = 1000}) --T3 Raid
addNewSquad({ type = "basicLand", minAnger = 60, units = { "6 armmeatball_scav","6 armassimilator_scav","2 armada_shredder_scav","2 corsent_scav",}, weight = 4, maxAnger = 100}) --T3 Assault/AA
addNewSquad({ type = "basicLand", minAnger = 60, units = { "6 corshiva_scav","2 armada_razorback_scav","1 legpede_scav","1 armada_shredder_scav","1 corsent_scav",}, weight = 4, maxAnger = 100}) --T3 Assault/AA
addNewSquad({ type = "basicLand", minAnger = 70, units = { "2 armada_vanguard_scav","2 cortex_catapult_scav","1 armada_shredder_scav","1 corsent_scav",}, weight = 4, maxAnger = 1000}) --T3 Arty/AA
--AirLand
addNewSquad({ type = "airLand", minAnger = 65, units = { "40 armada_falcon_scav","40 cortex_valiant_scav",}, weight = 4, maxAnger = 1000}) --T2 Fighters
addNewSquad({ type = "airLand", minAnger = 65, units = { "1 armada_hornet_scav","15 armada_roughneck_scav","1 legfort_scav","1 cortex_dragonold_scav","15 cortex_wasp_scav"}, weight = 2, maxAnger = 100}) --T2 Gunships

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
	[UnitDefNames["armada_solarcollector"].id] 	= 0.0000001,
	[UnitDefNames["corsolar"].id] 	= 0.0000001,
	[UnitDefNames["armada_windturbine"].id] 	= 0.0000001,
	[UnitDefNames["corwin"].id] 	= 0.0000001,
	[UnitDefNames["armada_tidalgenerator"].id] 	= 0.0000001,
	[UnitDefNames["cortide"].id] 	= 0.0000001,
	[UnitDefNames["armada_advancedsolarcollector"].id] 	= 0.000005,
	[UnitDefNames["coradvsol"].id] 	= 0.000005,

	-- T2 Energy
	[UnitDefNames["armada_windturbinet2"].id] 	= 0.000075,
	[UnitDefNames["corwint2"].id] 	= 0.000075,
	[UnitDefNames["armada_fusionreactor"].id] 	= 0.000125,
	[UnitDefNames["armada_cloakablefusionreactor"].id] 	= 0.000125,
	[UnitDefNames["corfus"].id] 	= 0.000125,
	[UnitDefNames["armada_navalfusionreactor"].id] 	= 0.000125,
	[UnitDefNames["coruwfus"].id] 	= 0.000125,
	[UnitDefNames["armada_advancedgeothermalpowerplant"].id] 	= 0.000125,
	[UnitDefNames["corageo"].id] 	= 0.000125,
	[UnitDefNames["armada_advancedfusionreactor"].id] 	= 0.0005,
	[UnitDefNames["corafus"].id] 	= 0.0005,

	-- T1 Metal Makers
	[UnitDefNames["armada_energyconverter"].id] 	= 0.00005,
	[UnitDefNames["cormakr"].id] 	= 0.00005,
	[UnitDefNames["armada_navalenergyconverter"].id] 	= 0.00005,
	[UnitDefNames["corfmkr"].id] 	= 0.00005,

	-- T2 Metal Makers
	[UnitDefNames["armada_advancedenergyconverter"].id] 	= 0.0005,
	[UnitDefNames["cormmkr"].id] 	= 0.0005,
	[UnitDefNames["armada_navaladvancedenergyconverter"].id] 	= 0.0005,
	[UnitDefNames["coruwmmm"].id] 	= 0.0005,
	]]--
}

local highValueTargets = { -- Priority targets for Scav. Must be immobile to prevent issues.
	-- T2 Energy
	[UnitDefNames["armada_windturbinet2"].id] 	= true,
	[UnitDefNames["corwint2"].id] 	= true,
	[UnitDefNames["armada_fusionreactor"].id] 	= true,
	[UnitDefNames["armada_cloakablefusionreactor"].id] 	= true,
	[UnitDefNames["corfus"].id] 	= true,
	[UnitDefNames["armada_navalfusionreactor"].id] 	= true,
	[UnitDefNames["coruwfus"].id] 	= true,
	[UnitDefNames["armada_advancedgeothermalpowerplant"].id] 	= true,
	[UnitDefNames["corageo"].id] 	= true,
	[UnitDefNames["armada_advancedfusionreactor"].id] 	= true,
	[UnitDefNames["corafus"].id] 	= true,
	-- T2 Metal Makers
	[UnitDefNames["armada_advancedenergyconverter"].id] 	= true,
	[UnitDefNames["cormmkr"].id] 	= true,
	[UnitDefNames["armada_navaladvancedenergyconverter"].id] 	= true,
	[UnitDefNames["coruwmmm"].id] 	= true,
	-- T2 Metal Extractors
	[UnitDefNames["cormoho"].id] 	= true,
	[UnitDefNames["armada_advancedmetalextractor"].id] 	= true,
	-- Nukes
	[UnitDefNames["corsilo"].id] 	= true,
	[UnitDefNames["armada_armageddon"].id] 	= true,
	-- Antinukes
	[UnitDefNames["armada_citadel"].id] 	= true,
	[UnitDefNames["corfmd"].id] 	= true,
}
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local config = { -- Don't touch this! ---------------------------------------------------------------------------------------------------------------------------------------------
	useScum					= useScum,
	difficulty             	= difficulty,
	difficulties           	= difficulties,
	burrowName             	= burrowName,   -- burrow unit name
	burrowDef              	= UnitDefNames[burrowName].id,
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
}

for key, value in pairs(difficultyParameters[difficulty]) do
	config[key] = value
end

return config
