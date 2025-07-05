
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
local economyScale = 1 * Spring.GetModOptions().multiplier_resourceincome *
(0.67+(Spring.GetModOptions().multiplier_metalextraction*0.33)) *
(0.67+(Spring.GetModOptions().multiplier_energyconversion*0.33)) *
(0.67+(Spring.GetModOptions().multiplier_energyproduction*0.33)) *
(((((Spring.GetModOptions().startmetal - 1000) / 9000) + 1)*0.1)+0.9) *
(((((Spring.GetModOptions().startenergy - 1000) / 9000) + 1)*0.1)+0.9)

economyScale = math.min(5, (economyScale*0.33)+0.67)

local teams = Spring.GetTeamList()
local humanTeamCount = -1 -- starts at -1 to disregard gaia
local scavTeamCount
local scavTeamID
for _, teamID in ipairs(teams) do
	local teamLuaAI =  Spring.GetTeamLuaAI(teamID)
	if not (teamLuaAI and string.find(teamLuaAI, "ScavengersAI")) then
		humanTeamCount = humanTeamCount + 1
	end
end



local difficultyParameters = {

	[difficulties.veryeasy] = {
		gracePeriod             = 180,
		bossTime                = 65 * Spring.GetModOptions().scav_bosstimemult * 60, -- time at which the boss appears, seconds
		scavSpawnRate           = 240 / Spring.GetModOptions().scav_spawntimemult / economyScale,
		burrowSpawnRate         = 240 / Spring.GetModOptions().scav_spawntimemult / economyScale,
		turretSpawnRate         = 500 / Spring.GetModOptions().scav_spawntimemult / economyScale,
		bossSpawnMult           = 1,
		angerBonus              = 0.1,
		maxXP                   = 0.1 * economyScale,
		spawnChance             = 0.1,
		damageMod               = 0.5,
		healthMod               = 0.5,
		maxBurrows              = 1000,
		minScavs                = 15 * economyScale,
		maxScavs                = 45 * economyScale,
		scavPerPlayerMultiplier = 0.25,
		bossName                = 'scavengerbossv4_veryeasy_scav',
		bossResistanceMult      = 1 * economyScale,
	},

	[difficulties.easy] = {
		gracePeriod             = 120,
		bossTime                = 60 * Spring.GetModOptions().scav_bosstimemult * 60, -- time at which the boss appears, seconds
		scavSpawnRate           = 200 / Spring.GetModOptions().scav_spawntimemult / economyScale,
		burrowSpawnRate         = 210 / Spring.GetModOptions().scav_spawntimemult / economyScale,
		turretSpawnRate         = 420 / Spring.GetModOptions().scav_spawntimemult / economyScale,
		bossSpawnMult           = 1,
		angerBonus              = 0.15,
		maxXP                   = 0.2 * economyScale,
		spawnChance             = 0.2,
		damageMod               = 0.75,
		healthMod               = 0.75,
		maxBurrows              = 1000,
		minScavs                = 15 * economyScale,
		maxScavs                = 45 * economyScale,
		scavPerPlayerMultiplier = 0.25,
		bossName                = 'scavengerbossv4_easy_scav',
		bossResistanceMult      = 1.5 * economyScale,
	},
	[difficulties.normal] = {
		gracePeriod             = 90,
		bossTime                = 55 * Spring.GetModOptions().scav_bosstimemult * 60, -- time at which the boss appears, seconds
		scavSpawnRate           = 180 / Spring.GetModOptions().scav_spawntimemult / economyScale,
		burrowSpawnRate         = 180 / Spring.GetModOptions().scav_spawntimemult / economyScale,
		turretSpawnRate         = 380 / Spring.GetModOptions().scav_spawntimemult / economyScale,
		bossSpawnMult           = 3,
		angerBonus              = 0.2,
		maxXP                   = 0.3 * economyScale,
		spawnChance             = 0.3,
		damageMod               = 1,
		healthMod               = 1,
		maxBurrows              = 1000,
		minScavs                = 15 * economyScale,
		maxScavs                = 45 * economyScale,
		scavPerPlayerMultiplier = 0.25,
		bossName                = 'scavengerbossv4_normal_scav',
		bossResistanceMult      = 2 * economyScale,
	},
	[difficulties.hard] = {
		gracePeriod             = 80,
		bossTime                = 50 * Spring.GetModOptions().scav_bosstimemult * 60, -- time at which the boss appears, seconds
		scavSpawnRate           = 160 / Spring.GetModOptions().scav_spawntimemult / economyScale,
		burrowSpawnRate         = 150 / Spring.GetModOptions().scav_spawntimemult / economyScale,
		turretSpawnRate         = 340 / Spring.GetModOptions().scav_spawntimemult / economyScale,
		bossSpawnMult           = 3,
		angerBonus              = 0.25,
		maxXP                   = 0.4 * economyScale,
		spawnChance             = 0.4,
		damageMod               = 1,
		healthMod               = 1,
		maxBurrows              = 1000,
		minScavs                = 20 * economyScale,
		maxScavs                = 60 * economyScale,
		scavPerPlayerMultiplier = 0.25,
		bossName                = 'scavengerbossv4_hard_scav',
		bossResistanceMult      = 2.5 * economyScale,
	},
	[difficulties.veryhard] = {
		gracePeriod             = 70,
		bossTime                = 45 * Spring.GetModOptions().scav_bosstimemult * 60, -- time at which the boss appears, seconds
		scavSpawnRate           = 140 / Spring.GetModOptions().scav_spawntimemult / economyScale,
		burrowSpawnRate         = 120 / Spring.GetModOptions().scav_spawntimemult / economyScale,
		turretSpawnRate         = 320 / Spring.GetModOptions().scav_spawntimemult / economyScale,
		bossSpawnMult           = 3,
		angerBonus              = 0.30,
		maxXP                   = 0.5 * economyScale,
		spawnChance             = 0.5,
		damageMod               = 1,
		healthMod               = 1,
		maxBurrows              = 1000,
		minScavs                = 25 * economyScale,
		maxScavs                = 75 * economyScale,
		scavPerPlayerMultiplier = 0.25,
		bossName                = 'scavengerbossv4_veryhard_scav',
		bossResistanceMult      = 3 * economyScale,
	},
	[difficulties.epic] = {
		gracePeriod             = 60,
		bossTime                = 40 * Spring.GetModOptions().scav_bosstimemult * 60, -- time at which the boss appears, seconds
		scavSpawnRate           = 120 / Spring.GetModOptions().scav_spawntimemult / economyScale,
		burrowSpawnRate         = 90 / Spring.GetModOptions().scav_spawntimemult / economyScale,
		turretSpawnRate         = 260 / Spring.GetModOptions().scav_spawntimemult / economyScale,
		bossSpawnMult           = 3,
		angerBonus              = 0.35,
		maxXP                   = 0.6 * economyScale,
		spawnChance             = 0.6,
		damageMod               = 1,
		healthMod               = 1,
		maxBurrows              = 1000,
		minScavs                = 30 * economyScale,
		maxScavs                = 90 * economyScale,
		scavPerPlayerMultiplier = 0.25,
		bossName                = 'scavengerbossv4_epic_scav',
		bossResistanceMult      = 3.5 * economyScale,
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

local tierConfiguration = { -- Double maxSquadSize for special squads
	[1] = {minAnger = 0,  maxAnger = 20, 	maxSquadSize = 1},
	[2] = {minAnger = 10, maxAnger = 65, 	maxSquadSize = 10},
	[3] = {minAnger = 20, maxAnger = 100, 	maxSquadSize = 10},
	[4] = {minAnger = 35, maxAnger = 200, 	maxSquadSize = 10},
	[5] = {minAnger = 45, maxAnger = 350, 	maxSquadSize = 8},
	[6] = {minAnger = 60, maxAnger = 500, 	maxSquadSize = 5},
	[7] = {minAnger = 70, maxAnger = 1000, 	maxSquadSize = 3},
}

--local teamAngerEasementFB = 16
--teamAngerEasementFB = math.floor(teamAngerEasementFB / humanTeamCount)

-- if humanTeamCount == 1 then
-- 	teamAngerEasementFB = teamAngerEasementFB + 10
-- end

-- if humanTeamCount % 2 == 1 then
-- 	teamAngerEasementFB = teamAngerEasementFB + 6
-- end

--local fBusterConfig = { --configures the anger levels certain tiers of frontbusters appear
--	[1] = {minAnger = 1,  maxAnger = 20+teamAngerEasementFB},
--	[2] = {minAnger = 21 + teamAngerEasementFB, maxAnger = 30 + teamAngerEasementFB},
--	[3] = {minAnger = 31 + teamAngerEasementFB, maxAnger = 40 + teamAngerEasementFB},
--	[4] = {minAnger = 41 + teamAngerEasementFB, maxAnger = 50 + teamAngerEasementFB},
--	[5] = {minAnger = 51 + teamAngerEasementFB, maxAnger = 60 + teamAngerEasementFB},
--	[6] = {minAnger = 61 + teamAngerEasementFB, maxAnger = 70 + teamAngerEasementFB},
--	[7] = {minAnger = 71 + teamAngerEasementFB, maxAnger = 80 + teamAngerEasementFB},
--}

----------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------

local BurrowUnitsList = {
	['scavbeacon_t1_scav'] = {minAnger = tierConfiguration[1].minAnger, maxAnger = tierConfiguration[2].maxAnger},
	['scavbeacon_t2_scav'] = {minAnger = tierConfiguration[2].minAnger, maxAnger = tierConfiguration[3].maxAnger},
	['scavbeacon_t3_scav'] = {minAnger = tierConfiguration[3].minAnger, maxAnger = tierConfiguration[5].maxAnger},
	['scavbeacon_t4_scav'] = {minAnger = tierConfiguration[4].minAnger, maxAnger = tierConfiguration[7].maxAnger},
}

----------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------

local LandUnitsList = {
	Raid = {
		[1] = {
			--Armada
			["armflea_scav"] = 4,
			["armpw_scav"] = 3,
			["armfav_scav"] = 3,
			["armsh_scav"] = 3,
			--Cortex
			["corak_scav"] = 3,
			["corfav_scav"] = 4,
			["corsh_scav"] = 2,
			--Legion
			["leggob_scav"] = 4,
			["legsh_scav"] = 2,
			["legscout_scav"] = 3,
		},
		[2] = {
			--Armada
			["armflea_scav"] = 3,
			["armpw_scav"] = 4,
			["armfav_scav"] = 3,
			["armsh_scav"] = 3,
			--Cortex
			["corak_scav"] = 4,
			["corfav_scav"] = 3,
			["corsh_scav"] = 3,
			--Legion
			["leggob_scav"] = 4,
			["legsh_scav"] = 3,
			["leghades_scav"] = 4,
		},
		[3] = {
			--Armada
			["armflash_scav"] = 4,
			["armzapper_scav"] = 4,
			--Cortex
			["corgator_scav"] = 3,
			--Legion
			["legamphtank_scav"] = 3,
		},
		[4] = {
			--Armada
			["armlatnk_scav"] = 4,
			["armamph_scav"] = 3,
			["armfast_scav"] = 4,
			--Cortex
			["cortorch_scav"] = 3,
			["corsala_scav"] = 3,
			["corpyro_scav"] = 4,
			["corseal_scav"] = 3,
			["coramph_scav"] = 3,
			["corphantom_scav"] = 3,
			--Legion
			["legmrv_scav"] = 4,
			["legstr_scav"] = 4,
		},
		[5] = {
			--Armada

			--Cortex

			--Legion


		},
		[6] = {
			--Armada
			["armpwt4_scav"] = 3,
			["armmar_scav"] = 4,
			--Cortex
			["corakt4_scav"] = 3,
			--Legion
			["legjav_scav"] = 3,
			--N/A
		},
		[7] = {
			--Armada
			["armraz_scav"] = 3,
			--Cortex
			["cordemon_scav"] = 3,
			--Legion
			--N/A
		},
	},
	Assault = {
		[1] = {
			--Armada
			--Cortex
			--Legion
		},
		[2] = {
			--Armada
			["armham_scav"] = 4,
			["armpincer_scav"] = 2,
			--Cortex
			["corthud_scav"] = 3,
			["corgarp_scav"] = 2,
			--Legion
			["legcen_scav"] = 3,
			["leglob_scav"] = 3,
		},
		[3] = {
			--Armada
			["armwar_scav"] = 3,
			["armstump_scav"] = 4,
			["armjanus_scav"] = 2,
			["armanac_scav"] = 4,
			--Cortex
			["corraid_scav"] = 4,
			["corlevlr_scav"] = 4,
			["corsnap_scav"] = 2,
			--Legion
			["leggat_scav"] = 4,
			["legkark_scav"] = 4,
			["corkark_scav"] = 4,
			["legner_scav"] = 4,
		},
		[4] = {
			--Armada
			["armzeus_scav"] = 4,
			--Cortex
			["corcan_scav"] = 4,
			["corhal_scav"] = 4,
			--Legion
			["legshot_scav"] = 4,

		},
		[5] = {
			--Armada
			["armsnipe_scav"] = 2,
			["armvader_scav"] = 4,
			["armsptk_scav"] = 2,
			["armbull_scav"] = 4,
			["armcroc_scav"] = 4,
			--Cortex
			["corparrow_scav"] = 2,
			["cordeadeye_scav"] = 2,
			["corftiger_scav"] = 4,
			["corgol_scav"] = 2,
			["corroach_scav"] = 4,
			["corsktl_scav"] = 2,
			["cortermite_scav"] = 4,
			["corsumo_scav"] = 2,
			["correap_scav"] = 2,
			["corgatreap_scav"] = 4,
			--Legion
			["legaheattank_scav"] = 4,
			["legamph_scav"] = 3,
			["leginc_scav"] = 2,
			["legfloat_scav"] = 4,
		},
		[6] = {
			--Armada
			["armassimilator_scav"] = 4,
			["armmeatball_scav"] = 4,
			["armlun_scav"] = 4,
			--Cortex
			["corshiva_scav"] = 4,
			["corkarg_scav"] = 4,
			["legeallterrainmech_scav"] = 4,
			["corthermite"] = 4,
			["corsok_scav"] = 2,
			--Legion
			["legpede_scav"] = 1,
			["legkeres_scav"] = 4,
			["legeshotgunmech_scav"] = 2,
			["legbunk_scav"] = 2,
			["legehovertank_scav"] = 2,
		},
		[7] = {
			--Armada
			["armthor_scav"] = 3,
			["armbanth_scav"] = 4,
			["armrattet4_scav"] = 2,
			["armvadert4_scav"] = 2,
			["armsptkt4_scav"] = 2,
			--Cortex
			["corjugg_scav"] = 2,
			["corkorg_scav"] = 2,
			["corkarganetht4_scav"] = 2,
			["corgolt4_scav"] = 2,
			--Legion
			["leegmech_scav"] = 2,
			["legerailtank_scav"] = 3,
			["legeheatraymech_scav"] = 2,
			["legelrpcmech_scav"] = 3,
		},
	},
	Support = {
		[1] = {
			--Armada
			--Cortex
			--Legion
		},
		[2] = {
			--Armada
			["armrock_scav"] = 2,
			["armjeth_scav"] = 2,
			["armah_scav"] = 2,
			--Cortex
			["corstorm_scav"] = 2,
			["corcrash_scav"] = 2,
			["corah_scav"] = 2,
			--Legion
			["legbal_scav"] = 2,
		},
		[3] = {
			--Armada
			["armart_scav"] = 2,
			["armsam_scav"] = 2,
			["armmh_scav"] = 2,
			--Cortex
			["corwolv_scav"] = 2,
			["cormist_scav"] = 2,
			["cormh_scav"] = 2,
			--Legion
			["leghelios_scav"] = 2,
			["legbar_scav"] = 2,
			["legrail_scav"] = 2,
			["legmh_scav"] = 2,
			["legah_scav"] = 2,
		},
		[4] = {
			--Armada
			["armfido_scav"] = 2,
			["armaak_scav"] = 2,
			["armmav_scav"] = 2,
			["armyork_scav"] = 2,
			["armmart_scav"] = 2,
			--Cortex
			["cormart_scav"] = 2,
			["corsent_scav"] = 2,
			["coraak_scav"] = 2,
			["cormort_scav"] = 2,
			--Legion
			["legaskirmtank_scav"] = 2,
			["legamcluster_scav"] = 2,
			["legvcarry_scav"] = 2,
			["legbart_scav"] = 2,
			["legsrail_scav"] = 2,
			["legvflak_scav"] = 2,

		},
		[5] = {
			--Armada
			["armfboy_scav"] = 2,
			["armmanni_scav"] = 2,
			["armmerl_scav"] = 2,
			--Cortex
			["corban_scav"] = 2,
			["corvroc_scav"] = 2,
			["cortrem_scav"] = 2,
			["corhrk_scav"] = 2,
			["corsiegebreaker_scav"] = 2,
			--Legion
			["legavroc_scav"] = 2,
			["leginf_scav"] = 2,
			["legmed_scav"] = 2,

		},
		[6] = {
			--Armada
			["armvang_scav"] = 2,
			["armdronecarryland_scav"] = 2,
			["armscab_scav"] = 2,
			--Cortex
			["corcat_scav"] = 2,
			["cormabm_scav"] = 2,
			--Legion
			["leggobt3_scav"] = 3,
		},
		[7] = {
			--Armada

			--Cortex

			--Legion
			["legsrailt4_scav"] = 2,
		},
	},
	Healer = {
		[1] = {
			--Armada
			["armck_scav"] = 2,
			["armrectr_scav"] = 40,
			["armcv_scav"] = 2,
			["armch_scav"] = 2,
			--Cortex
			["corck_scav"] = 2,
			["cornecro_scav"] = 40,
			["corcv_scav"] = 2,
			["corch_scav"] = 2,
			--Legion
			["legcv_scav"] = 2,
			["legck_scav"] = 2,
			["legch_scav"] = 2,
			["legotter_scav"] = 2,
		},
		[2] = {
			--Armada
			["armck_scav"] = 2,
			["armrectr_scav"] = 40,
			["armcv_scav"] = 2,
			["armch_scav"] = 2,
			--Cortex
			["corck_scav"] = 2,
			["cornecro_scav"] = 40,
			["corcv_scav"] = 2,
			["corch_scav"] = 2,
			--Legion
			["legcv_scav"] = 2,
			["legck_scav"] = 2,
			["legch_scav"] = 2,
			["legotter_scav"] = 2,
		},
		[3] = {
			--Armada
			["armck_scav"] = 2,
			["armrectr_scav"] = 40,
			["armcv_scav"] = 2,
			["armch_scav"] = 2,
			--Cortex
			["corck_scav"] = 2,
			["cornecro_scav"] = 40,
			["corcv_scav"] = 2,
			["corch_scav"] = 2,
			--Legion
			["legcv_scav"] = 2,
			["legck_scav"] = 2,
			["legch_scav"] = 2,
			["legotter_scav"] = 2,
		},
		[4] = {
			--Armada
			["armrectr_scav"] = 40,
			["armack_scav"] = 2,
			["armacv_scav"] = 2,
			["armfark_scav"] = 2,
			["armconsul_scav"] = 2,
			--Cortex
			["cornecro_scav"] = 40,
			["corack_scav"] = 2,
			["coracv_scav"] = 2,
			["corfast_scav"] = 2,
			["cormando_scav"] = 2,
			["corforge_scav"] = 2,
			--Legion
			["legacv_scav"] = 2,
			["legack_scav"] = 2,
			["legaceb_scav"] = 2,
		},
		[5] = {
			--Armada
			["armrectr_scav"] = 40,
			["armack_scav"] = 2,
			["armacv_scav"] = 2,
			["armfark_scav"] = 2,
			["armconsul_scav"] = 2,
			--Cortex
			["cornecro_scav"] = 40,
			["corack_scav"] = 2,
			["coracv_scav"] = 2,
			["corfast_scav"] = 2,
			["cormando_scav"] = 2,
			["corforge_scav"] = 2,
			--Legion
			["legacv_scav"] = 2,
			["legack_scav"] = 2,
			["legaceb_scav"] = 2,
		},
		[6] = {
			--Armada
			["armrectr_scav"] = 40,
			["armack_scav"] = 2,
			["armacv_scav"] = 2,
			["armfark_scav"] = 2,
			["armconsul_scav"] = 2,
			--Cortex
			["cornecro_scav"] = 40,
			["corack_scav"] = 2,
			["coracv_scav"] = 2,
			["corfast_scav"] = 2,
			["cormando_scav"] = 2,
			["corforge_scav"] = 2,
			--Legion
			["legacv_scav"] = 2,
			["legack_scav"] = 2,
			["legaceb_scav"] = 2,
		},
		[7] = {
			--Armada
			["armrectr_scav"] = 40,
			["armack_scav"] = 2,
			["armacv_scav"] = 2,
			["armfark_scav"] = 2,
			["armconsul_scav"] = 2,
			--Cortex
			["cornecro_scav"] = 40,
			["corack_scav"] = 2,
			["coracv_scav"] = 2,
			["corfast_scav"] = 2,
			["cormando_scav"] = 2,
			["corforge_scav"] = 2,
			--Legion
			["legacv_scav"] = 2,
			["legack_scav"] = 2,
			["legaceb_scav"] = 2,
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
			["armdecade_scav"] = 3,
			["armsh_scav"] = 3,
			--Cortex
			["coresupp_scav"] = 3,
			["corsh_scav"] = 3,
			--Legion
			["legsh_scav"] = 3,
		},
		[2] = {
			--Armada
			["armdecade_scav"] = 3,
			["armsh_scav"] = 3,
			--Cortex
			["coresupp_scav"] = 3,
			["corsh_scav"] = 3,
			--Legion
			["legsh_scav"] = 3,
		},
		[3] = {
			--Armada
			--Cortex
			--Legion
		},
		[4] = {
			--Armada
			["armlship_scav"] = 3,
			--Cortex
			["corfship_scav"] = 3,
		},
		[5] = {
			--Armada
			["armsubk_scav"] = 2,
			--Cortex
			["corshark_scav"] = 2,
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
			["armpship_scav"] = 4,
			["armroy_scav"] = 2,
			["armanac_scav"] = 3,
			--Cortex
			["corpship_scav"] = 4,
			["corroy_scav"] = 2,
			["corsnap_scav"] = 4,
			--Legion
			["legner_scav"] = 3,
		},
		[4] = {
			--Armada
			["armcrus_scav"] = 3,
			--Cortex
			["corcrus_scav"] = 3,
			["corhal_scav"] = 3,
		},
		[5] = {
			--Armada
			["armbats_scav"] = 3,
			--Cortex
			["corbats_scav"] = 3,
		},
		[6] = {
			--Armada
			["armpshipt3_scav"] = 2,
			["armptt2_scav"] = 2,
			--Cortex
			["corblackhy_scav"] = 2,
		},
		[7] = {
			--Armada
			["armepoch_scav"] = 2,
			["armserpt3_scav"] = 2,
			--Cortex
			["coresuppt3_scav"] = 2,
		},
	},
	Support = {
		[1] = {
			--Armada
			["armpt_scav"] = 2,
			--Cortex
			["corpt_scav"] = 2,
		},
		[2] = {
			--Armada
			["armpt_scav"] = 2,
			--Cortex
			["corpt_scav"] = 2,
		},
		[3] = {
			--Armada
			["armsub_scav"] = 2,
			["armah_scav"] = 2,
			["armmh_scav"] = 2,
			--Cortex
			["corsub_scav"] = 2,
			["corah_scav"] = 2,
			["cormh_scav"] = 2,
			--Legion
			["legah_scav"] = 2,
			["legmh_scav"] = 2,
		},
		[4] = {
			--Armada
			["armantiship_scav"] = 2,
			["armdronecarry_scav"] = 2,
			["armaas_scav"] = 2,
			--Cortex
			["cordronecarry_scav"] = 2,
			["corantiship_scav"] = 2,
			["corarch_scav"] = 2,
		},
		[5] = {
			--Armada
			["armserp_scav"] = 2,
			["armmship_scav"] = 2,
			["armsjam_scav"] = 2,
			["armtrident_scav"] = 2,
			--Cortex
			["corssub_scav"] = 2,
			["cormship_scav"] = 2,
			["corsjam_scav"] = 2,
			["corsentinel_scav"] = 2,
			--Legion
			["legvflak_scav"] = 2,
		},
		[6] = {
			--Armada
			["armexcalibur_scav"] = 1,
			["armseadeagon_scav"] = 1,

			--Cortex
			["coronager_scav"] = 1,
			["cordesolator_scav"] = 1,

		},
		[7] = {
			--Armada
			["armdecadet3_scav"] = 2,
			--Cortex
			["corslrpc_scav"] = 2,
		},
	},
	Healer = {
		[1] = {
			--Armada
			["armcs_scav"] = 2,
			["armrecl_scav"] = 40,
			["armch_scav"] = 2,
			--Cortex
			["corcs_scav"] = 2,
			["correcl_scav"] = 40,
			["corch_scav"] = 2,
			--Legion
			["legch_scav"] = 2,
		},
		[2] = {
			--Armada
			["armcs_scav"] = 2,
			["armrecl_scav"] = 40,
			["armch_scav"] = 2,
			--Cortex
			["corcs_scav"] = 2,
			["correcl_scav"] = 40,
			["corch_scav"] = 2,
			--Legion
			["legch_scav"] = 2,
		},
		[3] = {
			--Armada
			["armcs_scav"] = 2,
			["armrecl_scav"] = 40,
			["armch_scav"] = 2,
			--Cortex
			["corcs_scav"] = 2,
			["correcl_scav"] = 40,
			["corch_scav"] = 2,
			--Legion
			["legch_scav"] = 2,
		},
		[4] = {
			--Armada
			["armacsub_scav"] = 2,
			["armrecl_scav"] = 40,
			["armmls_scav"] = 2,
			--Cortex
			["coracsub_scav"] = 2,
			["correcl_scav"] = 40,
			["cormls_scav"] = 2,
		},
		[5] = {
			--Armada
			["armacsub_scav"] = 2,
			["armrecl_scav"] = 40,
			["armmls_scav"] = 2,
			--Cortex
			["coracsub_scav"] = 2,
			["correcl_scav"] = 40,
			["cormls_scav"] = 2,
		},
		[6] = {
			--Armada
			["armacsub_scav"] = 2,
			["armrecl_scav"] = 40,
			["armmls_scav"] = 2,
			--Cortex
			["coracsub_scav"] = 2,
			["correcl_scav"] = 40,
			["cormls_scav"] = 2,

		},
		[7] = {
			--Armada
			["armacsub_scav"] = 2,
			["armrecl_scav"] = 40,
			["armmls_scav"] = 2,
			--Cortex
			["coracsub_scav"] = 2,
			["correcl_scav"] = 40,
			["cormls_scav"] = 2,
		},
	},
}

----------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------
if not Spring.GetModOptions().unit_restrictions_noair then
	local t1landairconstructors = {
		["armca_scav"] = 2,
		["corca_scav"] = 2,
		["legca_scav"] = 2,
		["armfify_scav"] = 2,
	}
	local t2landairconstructors = {
		["armaca_scav"] = 2,
		["coraca_scav"] = 2,
		["legaca_scav"] = 2,
	}
	local t2seaairconstructors = {
		["armcsa_scav"] = 2,
		["corcsa_scav"] = 2,
	}

	table.append(LandUnitsList.Healer[2], table.copy(t1landairconstructors))
	table.append(SeaUnitsList.Healer[2], table.copy(t1landairconstructors))

	table.append(LandUnitsList.Healer[3], table.copy(t1landairconstructors))
	table.append(SeaUnitsList.Healer[3], table.copy(t1landairconstructors))

	table.append(LandUnitsList.Healer[4], table.copy(t2landairconstructors))
	table.append(SeaUnitsList.Healer[4], table.copy(t2seaairconstructors))

	table.append(LandUnitsList.Healer[5], table.copy(t2landairconstructors))
	table.append(SeaUnitsList.Healer[5], table.copy(t2seaairconstructors))

	table.append(LandUnitsList.Healer[6], table.copy(t2landairconstructors))
	table.append(SeaUnitsList.Healer[6], table.copy(t2seaairconstructors))

	table.append(LandUnitsList.Healer[7], table.copy(t2landairconstructors))
	table.append(SeaUnitsList.Healer[7], table.copy(t2seaairconstructors))
end


local AirUnitsList = {
	Land = {
		[1] = {
			--Armada
			["armpeep_scav"] = 2,
			--Cortex
			["corfink_scav"] = 2,
			--Legion

		},
		[2] = {
			--Armada
			["armpeep_scav"] = 2,
			--Cortex
			["corfink_scav"] = 2,
			["corbw_scav"] = 2,
			--Legion
			["legfig_scav"] = 2,

		},
		[3] = {
			--Armada
			["armfig_scav"] = 2,
			["armkam_scav"] = 2,
			["armthund_scav"] = 2,
			--Cortex
			["corveng_scav"] = 2,
			["corshad_scav"] = 2,
			--Legion
			["legmos_scav"] = 2,
			["legcib_scav"] = 2,
			["legkam_scav"] = 2,

		},
		[4] = {
			--Armada
			["armawac_scav"] = 2,
			["armdfly_scav"] = 2,
			--Cortex
			["corawac_scav"] = 2,
			--Legion
			["legwhisper_scav"] = 2,
			
		},
		[5] = {
			--Armada
			["armhawk_scav"] = 3,
			["armbrawl_scav"] = 3,
			["armpnix_scav"] = 3,
			["armstil_scav"] = 3,
			["armblade_scav"] = 3,
			["armliche_scav"] = 2,
			["armdfly_scav"] = 2,
			--Cortex
			["corvamp_scav"] = 3,
			["corape_scav"] = 3,
			["corhurc_scav"] = 3,
			["corcrw_scav"] = 2,
			["corcrwh_scav"] = 2,
			--Legion
			["legstronghold_scav"] = 2,
			["legvenator_scav"] = 3,
			["legionnaire_scav"] = 3,
			["legafigdef_scav"] = 3,
			["legnap_scav"] = 3,
			["legmineb_scav"] = 3,
			["legphoenix_scav"] = 3,
			["legfort_scav"] = 2,
			["legmost3_scav"] = 1,
		},
		[6] = {
			--Armada
			["armdfly_scav"] = 2,
			--Cortex
			["cordronecarryair_scav"] = 2,
			--Legion

		},
		[7] = {
			--Armada
			["armliche_scav"] = 4,
			["armthundt4_scav"] = 2,
			["armfepocht4_scav"] = 1,
			--Cortex
			["corcrw_scav"] = 3,
			["corcrwh_scav"] = 3,
			["corfblackhyt4_scav"] = 1,
			["corcrwt4_scav"] = 2,
			--Legion
			["legfort_scav"] = 3,
			["legmost3_scav"] = 2,
			["legfortt4_scav"] = 1,

		},
	},
	Sea = {
		[1] = {
			["armpeep_scav"] = 2,

			["corfink_scav"] = 2,
		},
		[2] = {
			["armsehak_scav"] = 2,
			["armsfig_scav"] = 2,

			["corsfig_scav"] = 2,
			["corhunt_scav"] = 2,
		},
		[3] = {
			["armsfig_scav"] = 2,
			["corsfig_scav"] = 2,
		},
		[4] = {
			["armsfig_scav"] = 2,
			["armsaber_scav"] = 2,
			["armseap_scav"] = 2,
			["armsb_scav"] = 2,
			["armlance_scav"] = 2,
			["armdfly_scav"] = 2,

			["corsfig_scav"] = 2,
			["corsb_scav"] = 2,
			["corseap_scav"] = 2,
			["corcut_scav"] = 2,
			["cortitan_scav"] = 2,

			["legatorpbomber"] = 2,
		},
		[5] = {
			["armsfig_scav"] = 2,
			["armsaber_scav"] = 2,
			["armseap_scav"] = 2,
			["armsb_scav"] = 2,
			["armlance_scav"] = 2,
			["armdfly_scav"] = 2,

			["corsfig_scav"] = 2,
			["corsb_scav"] = 2,
			["corseap_scav"] = 2,
			["corcut_scav"] = 2,
			["cortitan_scav"] = 2,
			
			["legatorpbomber"] = 2,
		},
		[6] = {
			["armsfig_scav"] = 2,
			["armsaber_scav"] = 2,
			["armseap_scav"] = 2,
			["armsb_scav"] = 2,
			["armlance_scav"] = 2,
			["armdfly_scav"] = 2,

			["corsfig_scav"] = 2,
			["corsb_scav"] = 2,
			["corseap_scav"] = 2,
			["corcut_scav"] = 2,
			["cortitan_scav"] = 2,
			
			["legatorpbomber"] = 2,
		},
		[7] = {
			--Armada
			["armliche_scav"] = 4,
			["armthundt4_scav"] = 2,
			["armfepocht4_scav"] = 1,
			--Cortex
			["corfblackhyt4_scav"] = 1,
			["corcrwt4_scav"] = 2,
			["corcrw_scav"] = 3,
			["corcrwh_scav"] = 3,
			--Legion
			["legfort_scav"] = 3,
			["legfortt4_scav"] = 3,
			["legmost3_scav"] = 2,
		},
	}
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
		["armestor_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 5},
		["corestor_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 5},
		["armuwms_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.1, maxExisting = 1},
		["coruwms_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.1, maxExisting = 1},
		["armuwes_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.1, maxExisting = 5},
		["coruwes_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.1, maxExisting = 5},
		["armmakr_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 1},
		["cormakr_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 1},
		["armfmkr_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.1, maxExisting = 1},
		["corfmkr_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.1, maxExisting = 1},
		--Factories
		["armlab_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.05, maxExisting = 1},
		["armvp_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.05, maxExisting = 1},
		["armap_scav"] = {type = "antiair", surface = "land", spawnedPerWave = 0.05, maxExisting = 1},
		["armhp_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.05, maxExisting = 1},
		["corlab_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.05, maxExisting = 1},
		["corvp_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.05, maxExisting = 1},
		["corap_scav"] = {type = "antiair", surface = "land", spawnedPerWave = 0.05, maxExisting = 1},
		["corhp_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.05, maxExisting = 1},
		["leglab_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.05, maxExisting = 1},
		["legvp_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.05, maxExisting = 1},
		["legap_scav"] = {type = "antiair", surface = "land", spawnedPerWave = 0.05, maxExisting = 1},
		["leghp_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.05, maxExisting = 1},
		["armfhp_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.05, maxExisting = 1},
		["armsy_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.05, maxExisting = 1},
		["corfhp_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.05, maxExisting = 1},
		["corsy_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.05, maxExisting = 1},
		["legfhp_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.05, maxExisting = 1},
		--["legsy_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.05, maxExisting = 1},
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
		["leghive_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 3},
		--radar/jam
		["corrad_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 2},
		["corjamt_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 2},
		["armrad_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 2},
		["armjamt_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 2},
		["armjuno_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 1},
		["corjuno_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 1},
		["legjuno_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 1},
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
		["legrwall_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 3},
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
		["armfus_scav"] = {type = "normal", surface = "land", spawnedPerWave = 1, maxExisting = 5},
		["armckfus_scav"] = {type = "normal", surface = "land", spawnedPerWave = 1, maxExisting = 5},
		["corfus_scav"] = {type = "normal", surface = "land", spawnedPerWave = 1, maxExisting = 5},
		["armuwfus_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 1, maxExisting = 5},
		["coruwfus_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 1, maxExisting = 5},
		["armuwadvms_scav"] = {type = "normal", surface = "mixed", spawnedPerWave = 0.1, maxExisting = 1},
		["coruwadvms_scav"] = {type = "normal", surface = "mixed", spawnedPerWave = 0.1, maxExisting = 1},
		["legamstor_scav"] = {type = "normal", surface = "mixed", spawnedPerWave = 0.1, maxExisting = 1},
		["armuwadves_scav"] = {type = "normal", surface = "mixed", spawnedPerWave = 0.1, maxExisting = 3},
		["coruwadves_scav"] = {type = "normal", surface = "mixed", spawnedPerWave = 0.1, maxExisting = 3},
		["armmmkr_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 1},
		["cormmkr_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 1},
		["legadveconv_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 1},
		["armuwmmm_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.1, maxExisting = 1},
		["coruwmmm_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.1, maxExisting = 1},
		-- Factories
		["armalab_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.05, maxExisting = 1},
		["armavp_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.05, maxExisting = 1},
		["armaap_scav"] = {type = "antiair", surface = "land", spawnedPerWave = 0.05, maxExisting = 1},
		["coralab_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.05, maxExisting = 1},
		["coravp_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.05, maxExisting = 1},
		["coraap_scav"] = {type = "antiair", surface = "land", spawnedPerWave = 0.05, maxExisting = 1},
		["legalab_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.05, maxExisting = 1},
		["legavp_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.05, maxExisting = 1},
		["legaap_scav"] = {type = "antiair", surface = "land", spawnedPerWave = 0.05, maxExisting = 1},
		["armamsub_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.05, maxExisting = 1},
		["armasy_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.05, maxExisting = 1},
		["armplat_scav"] = {type = "antiair", surface = "sea", spawnedPerWave = 0.05, maxExisting = 1},
		["coramsub_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.05, maxExisting = 1},
		["corasy_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.05, maxExisting = 1},
		["corplat_scav"] = {type = "antiair", surface = "sea", spawnedPerWave = 0.05, maxExisting = 1},
		["legamsub_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.05, maxExisting = 1},
		--["legasy_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.05, maxExisting = 1},
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
		["armbrtha_scav"] = {type = "lrpc", surface = "land", spawnedPerWave = 0.25, maxExisting = 7},
		["corint_scav"] = {type = "lrpc", surface = "land", spawnedPerWave = 0.25, maxExisting = 7},
		["leglrpc_scav"] = {type = "lrpc", surface = "land", spawnedPerWave = 0.25, maxExisting = 7},
		--antinukes
		["armamd_scav"] = {type = "nuke", surface = "land", spawnedPerWave = 1, maxExisting = 5},
		["corfmd_scav"] = {type = "nuke", surface = "land", spawnedPerWave = 1, maxExisting = 5},
		--Tactical Weapons
		["cortron_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 2},
		["armemp_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 2},
		["legperdition_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 2},
		--T2 AA
		["armmercury_scav"] = {type = "antiair", surface = "land", spawnedPerWave = 1, maxExisting = 2},
		["corscreamer_scav"] = {type = "antiair", surface = "land", spawnedPerWave = 1, maxExisting = 2},
		["leglraa_scav"] = {type = "antiair", surface = "land", spawnedPerWave = 1, maxExisting = 2},
	},
	[6] = {
		-- nukes
		["corsilo_scav"] = {type = "nuke", surface = "land", spawnedPerWave = 1, maxExisting = 3},
		["armsilo_scav"] = {type = "nuke", surface = "land", spawnedPerWave = 1, maxExisting = 3},
		["legsilo_scav"] = {type = "nuke", surface = "land", spawnedPerWave = 1, maxExisting = 3},
		-- misc t3 turrets
		["armminivulc_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 3},
		["corminibuzz_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 3},
		["legministarfall_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 3},
		["armbotrail_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 1},
		--Eco
		["armafus_scav"] = {type = "normal", surface = "land", spawnedPerWave = 1, maxExisting = 5},
		["corafus_scav"] = {type = "normal", surface = "land", spawnedPerWave = 1, maxExisting = 5},
		["legafus_scav"] = {type = "normal", surface = "land", spawnedPerWave = 1, maxExisting = 5},
		--Factories
		["armshltx_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 1},
		["corgant_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 1},
		["leggant_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 1},
		["armshltxuw_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.1, maxExisting = 1},
		["corgantuw_scav"] = {type = "normal", surface = "sea", spawnedPerWave = 0.1, maxExisting = 1},
		--misc
		["armgatet3_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 2},
		["corgatet3_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 2},
		["leggatet3_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 2},
	},
	[7] = {
		--Epic Bulwark and Pulsar/rag/cal
		["armannit3_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 3},
		["cordoomt3_scav"] = {type = "normal", surface = "land", spawnedPerWave = 0.1, maxExisting = 3},
		["armvulc_scav"] = {type = "lrpc", surface = "land", spawnedPerWave = 0.1, maxExisting = 1},
		["corbuzz_scav"] = {type = "lrpc", surface = "land", spawnedPerWave = 0.1, maxExisting = 1},
		["legstarfall_scav"] = {type = "lrpc", surface = "land", spawnedPerWave = 0.1, maxExisting = 1},
		--Eco
		["armafust3_scav"] = {type = "normal", surface = "land", spawnedPerWave = 1, maxExisting = 1},
		["corafust3_scav"] = {type = "normal", surface = "land", spawnedPerWave = 1, maxExisting = 1},
		["legafust3_scav"] = {type = "normal", surface = "land", spawnedPerWave = 1, maxExisting = 1},
		["armmmkrt3_scav"] = {type = "normal", surface = "land", spawnedPerWave = 1, maxExisting = 1},
		["cormmkrt3_scav"] = {type = "normal", surface = "land", spawnedPerWave = 1, maxExisting = 1},
		["legadveconvt3_scav"] = {type = "normal", surface = "land", spawnedPerWave = 1, maxExisting = 1},
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
		[UnitDefNames["legdecom_scav"].id] = { distance = 100, chance = 0.1 },
		[UnitDefNames["legcomlvl2_scav"].id] = { distance = 150, chance = 0.1 },
		[UnitDefNames["legcomlvl3_scav"].id] = { distance = 200, chance = 0.1 },
		[UnitDefNames["legdecomlvl3_scav"].id] = { distance = 200, chance = 0.1 },
		[UnitDefNames["legcomlvl4_scav"].id] = { distance = 250, chance = 0.1 },
		[UnitDefNames["legcomlvl5_scav"].id] = { distance = 300, chance = 0.01 },
		[UnitDefNames["legcomlvl6_scav"].id] = { distance = 350, chance = 0.01 },
		[UnitDefNames["legdecomlvl6_scav"].id] = { distance = 350, chance = 0.01 },
		[UnitDefNames["legcomlvl7_scav"].id] = { distance = 400, chance = 0.01 },
		[UnitDefNames["legcomlvl8_scav"].id] = { distance = 450, chance = 0.001 },
		[UnitDefNames["legcomlvl9_scav"].id] = { distance = 500, chance = 0.001 },
		[UnitDefNames["legcomlvl10_scav"].id] = { distance = 550, chance = 0.001 },
		[UnitDefNames["legdecomlvl10_scav"].id] = { distance = 550, chance = 0.001 },
		[UnitDefNames["armcom_scav"].id] = { distance = 100, chance = 0.1 },
		[UnitDefNames["armdecom_scav"].id] = { distance = 100, chance = 0.1 },
		[UnitDefNames["armcomlvl2_scav"].id] = { distance = 200, chance = 0.1 },
		[UnitDefNames["armcomlvl3_scav"].id] = { distance = 300, chance = 0.1 },
		[UnitDefNames["armdecomlvl3_scav"].id] = { distance = 300, chance = 0.1 },
		[UnitDefNames["armcomlvl4_scav"].id] = { distance = 400, chance = 0.1 },
		[UnitDefNames["armcomlvl5_scav"].id] = { distance = 500, chance = 0.01 },
		[UnitDefNames["armcomlvl6_scav"].id] = { distance = 600, chance = 0.01 },
		[UnitDefNames["armdecomlvl6_scav"].id] = { distance = 600, chance = 0.01 },
		[UnitDefNames["armcomlvl7_scav"].id] = { distance = 700, chance = 0.01 },
		[UnitDefNames["armcomlvl8_scav"].id] = { distance = 800, chance = 0.001 },
		[UnitDefNames["armcomlvl9_scav"].id] = { distance = 900, chance = 0.001 },
		[UnitDefNames["armcomlvl10_scav"].id] = { distance = 1000, chance = 0.001 },
		[UnitDefNames["armdecomlvl10_scav"].id] = { distance = 1000, chance = 0.001 },
		[UnitDefNames["corcom_scav"].id] = { distance = 2000, chance = 0.1 },
		[UnitDefNames["cordecom_scav"].id] = { distance = 2000, chance = 0.1 },
		[UnitDefNames["corcomlvl2_scav"].id] = { distance = 2000, chance = 0.1 },
		[UnitDefNames["corcomlvl3_scav"].id] = { distance = 2000, chance = 0.1 },
		[UnitDefNames["cordecomlvl3_scav"].id] = { distance = 2000, chance = 0.1 },
		[UnitDefNames["corcomlvl4_scav"].id] = { distance = 2000, chance = 0.1 },

		[UnitDefNames["squadarmpwt4_scav"].id] = { distance = 500, chance = 0.001 },
		[UnitDefNames["squadcorakt4_scav"].id] = { distance = 500, chance = 0.001 },
		[UnitDefNames["squadarmsptkt4_scav"].id] = { distance = 500, chance = 0.001 },
		[UnitDefNames["squadcorkarganetht4_scav"].id] = { distance = 500, chance = 0.001 },
	},
	COWARD = { -- Run away from target after getting hit by enemy
		[UnitDefNames["armcom_scav"].id] = { distance = 100, chance = 0.1 },
		[UnitDefNames["armcomlvl2_scav"].id] = { distance = 150, chance = 0.1 },
		[UnitDefNames["armcomlvl3_scav"].id] = { distance = 200, chance = 0.1 },
		[UnitDefNames["armdecomlvl3_scav"].id] = { distance = 200, chance = 0.1 },
		[UnitDefNames["armcomlvl4_scav"].id] = { distance = 250, chance = 0.1 },
		[UnitDefNames["armcomlvl5_scav"].id] = { distance = 300, chance = 0.01 },
		[UnitDefNames["armcomlvl6_scav"].id] = { distance = 350, chance = 0.01 },
		[UnitDefNames["armdecomlvl6_scav"].id] = { distance = 350, chance = 0.01 },
		[UnitDefNames["armcomlvl7_scav"].id] = { distance = 400, chance = 0.01 },
		[UnitDefNames["armcomlvl8_scav"].id] = { distance = 450, chance = 0.001 },
		[UnitDefNames["armcomlvl9_scav"].id] = { distance = 500, chance = 0.001 },
		[UnitDefNames["armcomlvl10_scav"].id] = { distance = 550, chance = 0.001 },
		[UnitDefNames["armdecomlvl10_scav"].id] = { distance = 550, chance = 0.001 },
		[UnitDefNames["corcom_scav"].id] = { distance = 100, chance = 0.1 },
		[UnitDefNames["cordecom_scav"].id] = { distance = 100, chance = 0.1 },
		[UnitDefNames["corcomlvl2_scav"].id] = { distance = 150, chance = 0.1 },
		[UnitDefNames["corcomlvl3_scav"].id] = { distance = 200, chance = 0.1 },
		[UnitDefNames["cordecomlvl3_scav"].id] = { distance = 200, chance = 0.1 },
		[UnitDefNames["corcomlvl4_scav"].id] = { distance = 250, chance = 0.1 },
		[UnitDefNames["corcomlvl5_scav"].id] = { distance = 300, chance = 0.01 },
		[UnitDefNames["corcomlvl6_scav"].id] = { distance = 350, chance = 0.01 },
		[UnitDefNames["cordecomlvl6_scav"].id] = { distance = 350, chance = 0.01 },
		[UnitDefNames["corcomlvl7_scav"].id] = { distance = 400, chance = 0.01 },
		[UnitDefNames["corcomlvl8_scav"].id] = { distance = 450, chance = 0.001 },
		[UnitDefNames["corcomlvl9_scav"].id] = { distance = 500, chance = 0.001 },
		[UnitDefNames["corcomlvl10_scav"].id] = { distance = 550, chance = 0.001 },
		[UnitDefNames["cordecomlvl10_scav"].id] = { distance = 550, chance = 0.001 },
		[UnitDefNames["legcom_scav"].id] = { distance = 100, chance = 0.1 },
		[UnitDefNames["legdecom_scav"].id] = { distance = 100, chance = 0.1 },
		[UnitDefNames["legcomlvl2_scav"].id] = { distance = 150, chance = 0.1 },
		[UnitDefNames["legcomlvl3_scav"].id] = { distance = 200, chance = 0.1 },
		[UnitDefNames["legdecomlvl3_scav"].id] = { distance = 200, chance = 0.1 },
		[UnitDefNames["legcomlvl4_scav"].id] = { distance = 250, chance = 0.1 },
		[UnitDefNames["legcomlvl5_scav"].id] = { distance = 300, chance = 0.01 },
		[UnitDefNames["legcomlvl6_scav"].id] = { distance = 350, chance = 0.01 },
		[UnitDefNames["legdecomlvl6_scav"].id] = { distance = 350, chance = 0.01 },
		[UnitDefNames["legcomlvl7_scav"].id] = { distance = 400, chance = 0.01 },
		[UnitDefNames["legcomlvl8_scav"].id] = { distance = 450, chance = 0.001 },
		[UnitDefNames["legcomlvl9_scav"].id] = { distance = 500, chance = 0.001 },
		[UnitDefNames["legcomlvl10_scav"].id] = { distance = 550, chance = 0.001 },
		[UnitDefNames["legdecomlvl10_scav"].id] = { distance = 550, chance = 0.001 },
		[UnitDefNames["cormandot4_scav"].id] = { distance = 500, chance = 0.1 },

		[UnitDefNames["squadarmpwt4_scav"].id] = { distance = 500, chance = 0.1 },
		[UnitDefNames["squadcorakt4_scav"].id] = { distance = 500, chance = 0.1 },
		[UnitDefNames["squadarmsptkt4_scav"].id] = { distance = 500, chance = 0.1 },
		[UnitDefNames["squadcorkarganetht4_scav"].id] = { distance = 500, chance = 0.1 },
		
	},
	BERSERK = { -- Run towards target after getting hit by enemy or after hitting the target
		[UnitDefNames["armcomlvl5_scav"].id] = { distance = 5000, chance = 0.01 },
		[UnitDefNames["armcomlvl6_scav"].id] = { distance = 5000, chance = 0.01 },
		[UnitDefNames["armdecomlvl6_scav"].id] = { distance = 5000, chance = 0.01 },
		[UnitDefNames["armcomlvl7_scav"].id] = { distance = 5000, chance = 0.01 },
		[UnitDefNames["armcomlvl8_scav"].id] = { distance = 5000, chance = 0.01 },
		[UnitDefNames["armcomlvl9_scav"].id] = { distance = 5000, chance = 0.01 },
		[UnitDefNames["armcomlvl10_scav"].id] = { distance = 5000, chance = 0.01 },
		[UnitDefNames["armdecomlvl10_scav"].id] = { distance = 5000, chance = 0.01 },
		[UnitDefNames["corcomlvl5_scav"].id] = { distance = 5000, chance = 0.01 },
		[UnitDefNames["corcomlvl6_scav"].id] = { distance = 5000, chance = 0.01 },
		[UnitDefNames["cordecomlvl6_scav"].id] = { distance = 5000, chance = 0.01 },
		[UnitDefNames["corcomlvl7_scav"].id] = { distance = 5000, chance = 0.01 },
		[UnitDefNames["corcomlvl8_scav"].id] = { distance = 5000, chance = 0.01 },
		[UnitDefNames["corcomlvl9_scav"].id] = { distance = 5000, chance = 0.01 },
		[UnitDefNames["corcomlvl10_scav"].id] = { distance = 5000, chance = 0.01 },
		[UnitDefNames["cordecomlvl10_scav"].id] = { distance = 5000, chance = 0.01 },
		[UnitDefNames["legcomlvl5_scav"].id] = { distance = 5000, chance = 0.01 },
		[UnitDefNames["legcomlvl6_scav"].id] = { distance = 5000, chance = 0.01 },
		[UnitDefNames["legdecomlvl6_scav"].id] = { distance = 5000, chance = 0.01 },
		[UnitDefNames["legcomlvl7_scav"].id] = { distance = 5000, chance = 0.01 },
		[UnitDefNames["legcomlvl8_scav"].id] = { distance = 5000, chance = 0.01 },
		[UnitDefNames["legcomlvl9_scav"].id] = { distance = 5000, chance = 0.01 },
		[UnitDefNames["legcomlvl10_scav"].id] = { distance = 5000, chance = 0.01 },
		[UnitDefNames["legdecomlvl10_scav"].id] = { distance = 5000, chance = 0.01 },
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
		[UnitDefNames["armfify_scav"].id] = true,
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

		[UnitDefNames["armdecom_scav"].id] = true,
		[UnitDefNames["armdecomlvl3_scav"].id] = true,
		[UnitDefNames["armdecomlvl6_scav"].id] = true,
		[UnitDefNames["armdecomlvl10_scav"].id] = true,

		[UnitDefNames["cordecom_scav"].id] = true,
		[UnitDefNames["cordecomlvl3_scav"].id] = true,
		[UnitDefNames["cordecomlvl6_scav"].id] = true,
		[UnitDefNames["cordecomlvl10_scav"].id] = true,

		[UnitDefNames["legdecom_scav"].id] = true,
		[UnitDefNames["legdecomlvl3_scav"].id] = true,
		[UnitDefNames["legdecomlvl6_scav"].id] = true,
		[UnitDefNames["legdecomlvl10_scav"].id] = true,
	},
	ARTILLERY = { -- Long lifetime and no regrouping, always uses Fight command to keep distance
		--[UnitDefNames["raptor_allterrain_arty_basic_t2_v1"].id] = true,
		[UnitDefNames["squadarmpwt4_scav"].id] = true,
		[UnitDefNames["squadcorakt4_scav"].id] = true,
		[UnitDefNames["squadarmsptkt4_scav"].id] = true,
		[UnitDefNames["squadcorkarganetht4_scav"].id] = true,
	},
	KAMIKAZE = { -- Long lifetime and no regrouping, always uses Move command to rush into the enemy
		--[UnitDefNames["raptor_land_kamikaze_basic_t2_v1"].id] = true,
		[UnitDefNames["scavmist_scav"].id]			= true,
		[UnitDefNames["scavmistxl_scav"].id]		= true,
		[UnitDefNames["scavmistxxl_scav"].id]		= true,
		[UnitDefNames["armvadert4_scav"].id]		= true,
	},
	ALWAYSMOVE = { -- Always use Move command, no matter what category this unit is in
		[UnitDefNames["cormandot4_scav"].id]		= true,
	},
	ALWAYSFIGHT = { -- Always use Fight command, no matter what category this unit is in
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
	basicAirLand = {},
	basicAirSea = {},
	specialLand = {}, -- 33% spawn chance, there's 1% chance of Special squad spawning Super squad, which is specials but 30% anger earlier.
	specialSea = {}, -- 33% spawn chance, there's 1% chance of Special squad spawning Super squad, which is specials but 30% anger earlier.
	specialAirLand = {},
	specialAirSea = {},
	healerLand = {}, -- Healers/Medics
	healerSea = {}, -- Healers/Medics
	commanders = {
		["armcom_scav"]        = { minAnger = 10, maxAnger = 40, maxAlive = 1 },
		["armcomlvl2_scav"]    = { minAnger = 15, maxAnger = 50, maxAlive = 1 },
		["armcomlvl3_scav"]    = { minAnger = 20, maxAnger = 60, maxAlive = 1 },
		["armcomlvl4_scav"]    = { minAnger = 30, maxAnger = 70, maxAlive = 1 },
		["armcomlvl5_scav"]    = { minAnger = 40, maxAnger = 80, maxAlive = 1 },
		["armcomlvl6_scav"]    = { minAnger = 50, maxAnger = 90, maxAlive = 1 },
		["armcomlvl7_scav"]    = { minAnger = 60, maxAnger = 100, maxAlive = 1 },
		["armcomlvl8_scav"]    = { minAnger = 70, maxAnger = 110, maxAlive = 1 },
		["armcomlvl9_scav"]    = { minAnger = 80, maxAnger = 120, maxAlive = 1 },
		["armcomlvl10_scav"]   = { minAnger = 90, maxAnger = 1000, maxAlive = 4 },
		["corcom_scav"]        = { minAnger = 10, maxAnger = 40, maxAlive = 1 },
		["corcomlvl2_scav"]    = { minAnger = 15, maxAnger = 50, maxAlive = 1 },
		["corcomlvl3_scav"]    = { minAnger = 20, maxAnger = 60, maxAlive = 1 },
		["corcomlvl4_scav"]    = { minAnger = 30, maxAnger = 70, maxAlive = 1 },
		["corcomlvl5_scav"]    = { minAnger = 40, maxAnger = 80, maxAlive = 1 },
		["corcomlvl6_scav"]    = { minAnger = 50, maxAnger = 90, maxAlive = 1 },
		["corcomlvl7_scav"]    = { minAnger = 60, maxAnger = 100, maxAlive = 1 },
		["corcomlvl8_scav"]    = { minAnger = 70, maxAnger = 110, maxAlive = 1 },
		["corcomlvl9_scav"]    = { minAnger = 80, maxAnger = 120, maxAlive = 1 },
		["corcomlvl10_scav"]   = { minAnger = 90, maxAnger = 1000, maxAlive = 4 },
		["legcom_scav"]        = { minAnger = 10, maxAnger = 40, maxAlive = 1 },
		["legcomlvl2_scav"]    = { minAnger = 15, maxAnger = 50, maxAlive = 1 },
		["legcomlvl3_scav"]    = { minAnger = 20, maxAnger = 60, maxAlive = 1 },
		["legcomlvl4_scav"]    = { minAnger = 30, maxAnger = 70, maxAlive = 1 },
		["legcomlvl5_scav"]    = { minAnger = 40, maxAnger = 80, maxAlive = 1 },
		["legcomlvl6_scav"]    = { minAnger = 50, maxAnger = 90, maxAlive = 1 },
		["legcomlvl7_scav"]    = { minAnger = 60, maxAnger = 100, maxAlive = 1 },
		["legcomlvl8_scav"]    = { minAnger = 70, maxAnger = 110, maxAlive = 1 },
		["legcomlvl9_scav"]    = { minAnger = 80, maxAnger = 120, maxAlive = 1 },
		["legcomlvl10_scav"]   = { minAnger = 90, maxAnger = 1000, maxAlive = 4 },


	},

	decoyCommanders = {
		["armdecom_scav"]      = { minAnger = 10, maxAnger = 40, maxAlive = 1 },
		["armdecomlvl3_scav"]  = { minAnger = 20, maxAnger = 60, maxAlive = 1 },
		["armdecomlvl6_scav"]  = { minAnger = 50, maxAnger = 90, maxAlive = 1 },
		["armdecomlvl10_scav"] = { minAnger = 80, maxAnger = 1000, maxAlive = 1 },

		["cordecom_scav"]      = { minAnger = 10, maxAnger = 40, maxAlive = 1 },
		["cordecomlvl3_scav"]  = { minAnger = 20, maxAnger = 60, maxAlive = 1},
		["cordecomlvl6_scav"]  = { minAnger = 50, maxAnger = 90, maxAlive = 1 },
		["cordecomlvl10_scav"] = { minAnger = 80, maxAnger = 1000, maxAlive = 1 },

		["legdecom_scav"]      = { minAnger = 10, maxAnger = 40, maxAlive = 1 },
		["legdecomlvl3_scav"]  = { minAnger = 20, maxAnger = 60, maxAlive = 1 },
		["legdecomlvl6_scav"]  = { minAnger = 50, maxAnger = 90, maxAlive = 1 },
		["legdecomlvl10_scav"] = { minAnger = 80, maxAnger = 1000, maxAlive = 1 },

		["cormandot4_scav"] = { minAnger = 60, maxAnger = 1000, maxAlive = 4 },
	}
	--frontbusters = {
--
	--	----Tier 1 [1]----
--
	--	--land
	--	{ name = "armfboy_scav",        minAnger = fBusterConfig[1].minAnger, maxAnger = fBusterConfig[1].maxAnger, squadSize = 1, maxAlive = 1, surface = "land" },
	--	{ name = "armmanni_scav",        minAnger = fBusterConfig[1].minAnger, maxAnger = fBusterConfig[1].maxAnger, squadSize = 1, maxAlive = 1, surface = "land" },
	--	{ name = "corcan_scav",        minAnger = fBusterConfig[1].minAnger, maxAnger = fBusterConfig[1].maxAnger, squadSize = 3, maxAlive = 3, surface = "land" },
	--	{ name = "corsiegebreaker_scav",        minAnger = fBusterConfig[1].minAnger, maxAnger = fBusterConfig[1].maxAnger, squadSize = 1, maxAlive = 1, surface = "land" },
	--	{ name = "corgol_scav",        minAnger = fBusterConfig[1].minAnger, maxAnger = fBusterConfig[1].maxAnger, squadSize = 1, maxAlive = 1, surface = "land" },
	--	--mixed
	--	{ name = "armlun_scav",        minAnger = fBusterConfig[1].minAnger, maxAnger = fBusterConfig[1].maxAnger, squadSize = 1, maxAlive = 1, surface = "mixed" },
	--	{ name = "armmar_scav",        minAnger = fBusterConfig[1].minAnger, maxAnger = fBusterConfig[1].maxAnger, squadSize = 1, maxAlive = 1, surface = "mixed" },
	--	--sea
	--	{ name = "armcrus_scav",        minAnger = fBusterConfig[1].minAnger, maxAnger = fBusterConfig[1].maxAnger, squadSize = 1, maxAlive = 1, surface = "sea" },
	--	{ name = "corcrus_scav",        minAnger = fBusterConfig[1].minAnger, maxAnger = fBusterConfig[1].maxAnger, squadSize = 1, maxAlive = 1, surface = "sea" },
--
	--	----Tier 1.5 [2]----
	--	--land
	--	{ name = "armassimilator_scav",        minAnger = fBusterConfig[2].minAnger, maxAnger = fBusterConfig[2].maxAnger, squadSize = 1, maxAlive = 1, surface = "land" },
	--	{ name = "armdronecarryland_scav",        minAnger = fBusterConfig[2].minAnger, maxAnger = fBusterConfig[2].maxAnger, squadSize = 1, maxAlive = 1, surface = "land" },
	--	{ name = "corsumo_scav",        minAnger = fBusterConfig[2].minAnger, maxAnger = fBusterConfig[2].maxAnger, squadSize = 1, maxAlive = 1, surface = "land" },
	--	{ name = "corshiva_scav",        minAnger = fBusterConfig[2].minAnger, maxAnger = fBusterConfig[2].maxAnger, squadSize = 1, maxAlive = 1, surface = "land" },
	--	{ name = "cortrem_scav",        minAnger = fBusterConfig[2].minAnger, maxAnger = fBusterConfig[2].maxAnger, squadSize = 1, maxAlive = 1, surface = "land" },
	--	{ name = "leginf_scav",        minAnger = fBusterConfig[2].minAnger, maxAnger = fBusterConfig[2].maxAnger, squadSize = 1, maxAlive = 1, surface = "land" },
	--	{ name = "leginc_scav",        minAnger = fBusterConfig[2].minAnger, maxAnger = fBusterConfig[2].maxAnger, squadSize = 1, maxAlive = 1, surface = "land" },
	--	--mixed
	--	{ name = "cordronecarryair_scav",        minAnger = fBusterConfig[2].minAnger, maxAnger = fBusterConfig[2].maxAnger, squadSize = 1, maxAlive = 1, surface = "mixed" },
	--	--sea
	--	{ name = "armdronecarry_scav",        minAnger = fBusterConfig[2].minAnger, maxAnger = fBusterConfig[2].maxAnger, squadSize = 1, maxAlive = 1, surface = "sea" },
	--	{ name = "armtrident_scav",        minAnger = fBusterConfig[2].minAnger, maxAnger = fBusterConfig[2].maxAnger, squadSize = 1, maxAlive = 1, surface = "sea" },
	--	{ name = "armmship_scav",        minAnger = fBusterConfig[2].minAnger, maxAnger = fBusterConfig[2].maxAnger, squadSize = 1, maxAlive = 1, surface = "sea" },
	--	{ name = "corsentinel_scav",        minAnger = fBusterConfig[2].minAnger, maxAnger = fBusterConfig[2].maxAnger, squadSize = 1, maxAlive = 1, surface = "sea" },
	--	{ name = "cordronecarry_scav",        minAnger = fBusterConfig[2].minAnger, maxAnger = fBusterConfig[2].maxAnger, squadSize = 1, maxAlive = 1, surface = "sea" },
	--	{ name = "cormship_scav",        minAnger = fBusterConfig[2].minAnger, maxAnger = fBusterConfig[2].maxAnger, squadSize = 1, maxAlive = 1, surface = "sea" },
--
	--	
--
	--	----Tier 2, [3]----
	--	--land
	--	{ name = "armraz_scav",        minAnger = fBusterConfig[3].minAnger, maxAnger = fBusterConfig[3].maxAnger, squadSize = 1, maxAlive = 1, surface = "land" },
	--	{ name = "armvang_scav",        minAnger = fBusterConfig[3].minAnger, maxAnger = fBusterConfig[3].maxAnger, squadSize = 1, maxAlive = 1, surface = "land" },
	--	{ name = "armmeatball_scav",        minAnger = fBusterConfig[3].minAnger, maxAnger = fBusterConfig[3].maxAnger, squadSize = 1, maxAlive = 1, surface = "land" },
	--	{ name = "corthermite_scav",        minAnger = fBusterConfig[3].minAnger, maxAnger = fBusterConfig[3].maxAnger, squadSize = 1, maxAlive = 1, surface = "land" },
	--	{ name = "corcat_scav",        minAnger = fBusterConfig[3].minAnger, maxAnger = fBusterConfig[3].maxAnger, squadSize = 1, maxAlive = 1, surface = "land" },
	--	{ name = "legkeres_scav",        minAnger = fBusterConfig[3].minAnger, maxAnger = fBusterConfig[3].maxAnger, squadSize = 1, maxAlive = 1, surface = "land" },
	--	--mixed
	--	{ name = "armliche_scav",        minAnger = fBusterConfig[3].minAnger, maxAnger = fBusterConfig[3].maxAnger, squadSize = 1, maxAlive = 1, surface = "mixed" },
	--	--sea
	--	{ name = "armbats_scav",        minAnger = fBusterConfig[3].minAnger, maxAnger = fBusterConfig[3].maxAnger, squadSize = 1, maxAlive = 1, surface = "sea" },
	--	{ name = "corbats_scav",        minAnger = fBusterConfig[3].minAnger, maxAnger = fBusterConfig[3].maxAnger, squadSize = 1, maxAlive = 1, surface = "sea" },
--
	--	----Tier 2.5 [4]----
	--	{ name = "armpwt4_scav",        minAnger = fBusterConfig[4].minAnger, maxAnger = fBusterConfig[4].maxAnger, squadSize = 1, maxAlive = 1, surface = "land" },
	--	{ name = "cordemon_scav",        minAnger = fBusterConfig[4].minAnger, maxAnger = fBusterConfig[4].maxAnger, squadSize = 1, maxAlive = 1, surface = "land" },
	--	{ name = "corakt4_scav",        minAnger = fBusterConfig[4].minAnger, maxAnger = fBusterConfig[4].maxAnger, squadSize = 1, maxAlive = 1, surface = "land" },
	--	{ name = "corkarg_scav",        minAnger = fBusterConfig[4].minAnger, maxAnger = fBusterConfig[4].maxAnger, squadSize = 1, maxAlive = 1, surface = "land" },
	--	--mixed
	--	{ name = "corcrw_scav",        minAnger = fBusterConfig[4].minAnger, maxAnger = fBusterConfig[4].maxAnger, squadSize = 1, maxAlive = 1, surface = "mixed" },
	--	{ name = "corcrwh_scav",        minAnger = fBusterConfig[4].minAnger, maxAnger = fBusterConfig[4].maxAnger, squadSize = 1, maxAlive = 1, surface = "mixed" },
	--	{ name = "legfort_scav",        minAnger = fBusterConfig[4].minAnger, maxAnger = fBusterConfig[4].maxAnger, squadSize = 1, maxAlive = 1, surface = "mixed" },
	--	--sea
	--	{ name = "armbats_scav",        minAnger = fBusterConfig[4].minAnger, maxAnger = fBusterConfig[4].maxAnger, squadSize = 2, maxAlive = 2, surface = "sea" },
	--	{ name = "corbats_scav",        minAnger = fBusterConfig[4].minAnger, maxAnger = fBusterConfig[4].maxAnger, squadSize = 2, maxAlive = 2, surface = "sea" },
--
	--	----Tier 3 [5]----
	--	--land
	--	{ name = "armthor_scav",        minAnger = fBusterConfig[5].minAnger, maxAnger = fBusterConfig[5].maxAnger, squadSize = 1, maxAlive = 1, surface = "land" },
	--	{ name = "armsptkt4_scav",        minAnger = fBusterConfig[5].minAnger, maxAnger = fBusterConfig[5].maxAnger, squadSize = 1, maxAlive = 1, surface = "land" },
	--	{ name = "corjugg_scav",        minAnger = fBusterConfig[5].minAnger, maxAnger = fBusterConfig[5].maxAnger, squadSize = 1, maxAlive = 1, surface = "land" },
	--	{ name = "leegmech_scav",        minAnger = fBusterConfig[5].minAnger, maxAnger = fBusterConfig[5].maxAnger, squadSize = 1, maxAlive = 1, surface = "land" },
	--	{ name = "legpede_scav",        minAnger = fBusterConfig[5].minAnger, maxAnger = fBusterConfig[5].maxAnger, squadSize = 1, maxAlive = 1, surface = "land" },
	--	{ name = "squadarmpwt4_scav",        minAnger = fBusterConfig[5].minAnger, maxAnger = fBusterConfig[5].maxAnger, squadSize = 1, maxAlive = 1, surface = "land" },
	--	{ name = "squadcorakt4_scav",        minAnger = fBusterConfig[5].minAnger, maxAnger = fBusterConfig[5].maxAnger, squadSize = 1, maxAlive = 1, surface = "land" },
	--	--mixed
	--	{ name = "corcrwt4_scav",        minAnger = fBusterConfig[5].minAnger, maxAnger = fBusterConfig[5].maxAnger, squadSize = 1, maxAlive = 1, surface = "mixed" },
	--	{ name = "armbanth_scav",        minAnger = fBusterConfig[5].minAnger, maxAnger = fBusterConfig[5].maxAnger, squadSize = 1, maxAlive = 1, surface = "mixed" },
	--	--sea
	--	{ name = "armpshipt3",        minAnger = fBusterConfig[5].minAnger, maxAnger = fBusterConfig[5].maxAnger, squadSize = 1, maxAlive = 1, surface = "sea" },
	--	{ name = "armdecadet3",        minAnger = fBusterConfig[5].minAnger, maxAnger = fBusterConfig[5].maxAnger, squadSize = 1, maxAlive = 1, surface = "sea" },
	--	{ name = "corslrpc",        minAnger = fBusterConfig[5].minAnger, maxAnger = fBusterConfig[5].maxAnger, squadSize = 1, maxAlive = 1, surface = "sea" },
	--	{ name = "armpshipt3",        minAnger = fBusterConfig[5].minAnger, maxAnger = fBusterConfig[5].maxAnger, squadSize = 1, maxAlive = 1, surface = "sea" },
	--	
--
	--	----Tier 3.5 [6]----
	--	--land
	--	{ name = "corkarganetht4_scav", minAnger = fBusterConfig[6].minAnger, maxAnger = fBusterConfig[6].maxAnger, squadSize = 1, maxAlive = 1, surface = "land" },
	--	{ name = "squadarmsptkt4_scav", minAnger = fBusterConfig[6].minAnger, maxAnger = fBusterConfig[6].maxAnger, squadSize = 1, maxAlive = 1, surface = "land" },
	--	--mixed
	--	{ name = "armthundt4_scav", minAnger = fBusterConfig[6].minAnger, maxAnger = fBusterConfig[6].maxAnger, squadSize = 1, maxAlive = 1, surface = "mixed" },
	--	{ name = "armrattet4_scav", minAnger = fBusterConfig[6].minAnger, maxAnger = fBusterConfig[6].maxAnger, squadSize = 1, maxAlive = 1, surface = "mixed" },
	--	{ name = "armfepocht4_scav", minAnger = fBusterConfig[6].minAnger, maxAnger = fBusterConfig[6].maxAnger, squadSize = 1, maxAlive = 1, surface = "mixed" },
	--	{ name = "corgolt4_scav", minAnger = fBusterConfig[6].minAnger, maxAnger = fBusterConfig[6].maxAnger, squadSize = 1, maxAlive = 1, surface = "mixed" },
	--	{ name = "corfblackhyt4_scav", minAnger = fBusterConfig[6].minAnger, maxAnger = fBusterConfig[6].maxAnger, squadSize = 1, maxAlive = 1, surface = "mixed" },
	--	{ name = "corkorg_scav", minAnger = fBusterConfig[6].minAnger, maxAnger = fBusterConfig[6].maxAnger, squadSize = 1, maxAlive = 1, surface = "mixed" },
	--	--sea
	--	{ name = "armdecadet3_scav",        minAnger = fBusterConfig[6].minAnger, maxAnger = fBusterConfig[6].maxAnger, squadSize = 1, maxAlive = 1, surface = "sea" },
	--	{ name = "armepoch_scav",        minAnger = fBusterConfig[6].minAnger, maxAnger = fBusterConfig[6].maxAnger, squadSize = 1, maxAlive = 1, surface = "sea" },
	--	{ name = "corslrpc_scav",        minAnger = fBusterConfig[6].minAnger, maxAnger = fBusterConfig[6].maxAnger, squadSize = 2, maxAlive = 2, surface = "sea" },
--
	--	----Tier 4 [7]----
	--	--land
	--	{ name = "squadcorkarganetht4_scav", minAnger = fBusterConfig[7].minAnger, maxAnger = fBusterConfig[7].maxAnger, squadSize = 1, maxAlive = 1, surface = "land" },
	--	--mixed
	--	{ name = "armvadert4_scav", minAnger = fBusterConfig[7].minAnger, maxAnger = fBusterConfig[7].maxAnger, squadSize = 1, maxAlive = 1, surface = "mixed" },
	--	{ name = "armlichet4_scav", minAnger = fBusterConfig[7].minAnger, maxAnger = fBusterConfig[7].maxAnger, squadSize = 1, maxAlive = 1, surface = "mixed" },
	--	--sea
	--	{ name = "armdecadet3_scav",        minAnger = fBusterConfig[7].minAnger, maxAnger = fBusterConfig[7].maxAnger, squadSize = 2, maxAlive = 2, surface = "sea" },
	--	{ name = "armepoch_scav",        minAnger = fBusterConfig[7].minAnger, maxAnger = fBusterConfig[7].maxAnger, squadSize = 2, maxAlive = 2, surface = "sea" },
	--}
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
			addNewSquad({
				type = "basicLand",
				weight = unitWeight,
				minAnger = tierConfiguration[tier].minAnger,
				maxAnger = tierConfiguration[tier].maxAnger,
				units = {
					{count = tierConfiguration[tier].maxSquadSize, unit = unitName}
				}
			})
			addNewSquad({
				type = "specialLand",
				weight = unitWeight,
				minAnger = tierConfiguration[tier].minAnger,
				maxAnger = tierConfiguration[tier].maxAnger,
				units = {
					{count = tierConfiguration[tier].maxSquadSize * 2, unit = unitName}
				}
			})
		end
	end
end

for tier, _ in pairs(LandUnitsList.Assault) do
	for unitName, _ in pairs(LandUnitsList.Assault[tier]) do
		if UnitDefNames[unitName] then
			local unitWeight = LandUnitsList.Assault[tier][unitName]
			if not scavBehaviours.BERSERK[UnitDefNames[unitName].id] then
				scavBehaviours.BERSERK[UnitDefNames[unitName].id] = {distance = 2000, chance = 0.01}
			end
			addNewSquad({ 
				type = "basicLand",
				weight = unitWeight,
				maxAnger = tierConfiguration[tier].maxAnger,
				minAnger = tierConfiguration[tier].minAnger,
				units = {
					{count = tierConfiguration[tier].maxSquadSize, unit = unitName}
				}
			})
			addNewSquad({
				type = "specialLand",
				weight = unitWeight,
				maxAnger = tierConfiguration[tier].maxAnger,
				minAnger = tierConfiguration[tier].minAnger,
				units = {
					{count = tierConfiguration[tier].maxSquadSize*2, unit = unitName}
				}
			})
		end
	end
end

for tier, _ in pairs(LandUnitsList.Support) do
	for unitName, _ in pairs(LandUnitsList.Support[tier]) do
		if UnitDefNames[unitName] then
			local unitWeight = LandUnitsList.Support[tier][unitName]
			if not scavBehaviours.SKIRMISH[UnitDefNames[unitName].id] then
				scavBehaviours.SKIRMISH[UnitDefNames[unitName].id] = {distance = 500, chance = 0.1}
				scavBehaviours.COWARD[UnitDefNames[unitName].id] = {distance = 500, chance = 0.75}
				scavBehaviours.ARTILLERY[UnitDefNames[unitName].id] = true
			end
			addNewSquad({
				type = "basicLand",
				weight = unitWeight,
				maxAnger = tierConfiguration[tier].maxAnger,
				minAnger = tierConfiguration[tier].minAnger,
				units = {
					{count = tierConfiguration[tier].maxSquadSize, unit = unitName}
				}
			})
			addNewSquad({
				type = "specialLand",
				weight = unitWeight,
				maxAnger = tierConfiguration[tier].maxAnger,
				minAnger = tierConfiguration[tier].minAnger,
				units = {
					{count = tierConfiguration[tier].maxSquadSize*2, unit = unitName}
				}
			})
		end
	end
end

for tier, _ in pairs(LandUnitsList.Healer) do
	for unitName, _ in pairs(LandUnitsList.Healer[tier]) do
		if UnitDefNames[unitName] then
			local unitWeight = LandUnitsList.Healer[tier][unitName]
			if not scavBehaviours.HEALER[UnitDefNames[unitName].id] then
				scavBehaviours.HEALER[UnitDefNames[unitName].id] = true
				if not scavBehaviours.SKIRMISH[UnitDefNames[unitName].id] then
					scavBehaviours.SKIRMISH[UnitDefNames[unitName].id] = {distance = 500, chance = 0.1}
					scavBehaviours.COWARD[UnitDefNames[unitName].id] = {distance = 500, chance = 0.75}
				end
			end
			addNewSquad({
				type = "healerLand",
				weight = unitWeight,
				maxAnger = tierConfiguration[tier].maxAnger,
				minAnger = tierConfiguration[tier].minAnger,
				units = {
					{count = tierConfiguration[tier].maxSquadSize, unit = unitName}
				}
			})
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
			addNewSquad({
				type = "basicSea",
				weight = unitWeight,
				maxAnger = tierConfiguration[tier].maxAnger,
				minAnger = tierConfiguration[tier].minAnger,
				units = {
					{count = math.ceil(tierConfiguration[tier].maxSquadSize*0.25), unit = unitName}
				}
			})
			addNewSquad({
				type = "specialSea",
				weight = unitWeight,
				maxAnger = tierConfiguration[tier].maxAnger,
				minAnger = tierConfiguration[tier].minAnger,
				units = {
					{count = math.ceil(tierConfiguration[tier].maxSquadSize*0.5), unit = unitName}
				}
			})
		end
	end
end

for tier, _ in pairs(SeaUnitsList.Assault) do
	for unitName, _ in pairs(SeaUnitsList.Assault[tier]) do
		if UnitDefNames[unitName] then
			local unitWeight = SeaUnitsList.Assault[tier][unitName]
			if not scavBehaviours.BERSERK[UnitDefNames[unitName].id] then
				scavBehaviours.BERSERK[UnitDefNames[unitName].id] = {distance = 2000, chance = 0.01}
			end
			addNewSquad({
				type = "basicSea",
				weight = unitWeight,
				maxAnger = tierConfiguration[tier].maxAnger,
				minAnger = tierConfiguration[tier].minAnger,
				units = {
					{count = math.ceil(tierConfiguration[tier].maxSquadSize*0.25), unit = unitName}
				}
			})
			addNewSquad({
				type = "specialSea",
				weight = unitWeight,
				maxAnger = tierConfiguration[tier].maxAnger,
				minAnger = tierConfiguration[tier].minAnger,
				units = {
					{count = math.ceil(tierConfiguration[tier].maxSquadSize*0.5), unit = unitName}
				}
			})
		end
	end
end

for tier, _ in pairs(SeaUnitsList.Support) do
	for unitName, _ in pairs(SeaUnitsList.Support[tier]) do
		if UnitDefNames[unitName] then
			local unitWeight = SeaUnitsList.Support[tier][unitName]
			if not scavBehaviours.SKIRMISH[UnitDefNames[unitName].id] then
				scavBehaviours.SKIRMISH[UnitDefNames[unitName].id] = {distance = 500, chance = 0.1}
				scavBehaviours.COWARD[UnitDefNames[unitName].id] = {distance = 500, chance = 0.75}
				scavBehaviours.ARTILLERY[UnitDefNames[unitName].id] = true
			end
			addNewSquad({
				type = "basicSea",
				weight = unitWeight,
				maxAnger = tierConfiguration[tier].maxAnger,
				minAnger = tierConfiguration[tier].minAnger,
				units = {
					{count = math.ceil(tierConfiguration[tier].maxSquadSize*0.25), unit = unitName}
				}
			})
			addNewSquad({
				type = "specialSea",
				weight = unitWeight,
				maxAnger = tierConfiguration[tier].maxAnger,
				minAnger = tierConfiguration[tier].minAnger,
				units = {
					{count = math.ceil(tierConfiguration[tier].maxSquadSize*0.5), unit = unitName}
				}
			})
		end
	end
end

for tier, _ in pairs(SeaUnitsList.Healer) do
	for unitName, _ in pairs(SeaUnitsList.Healer[tier]) do
		if UnitDefNames[unitName] then
			local unitWeight = SeaUnitsList.Healer[tier][unitName]
			if not scavBehaviours.HEALER[UnitDefNames[unitName].id] then
				scavBehaviours.HEALER[UnitDefNames[unitName].id] = true
				if not scavBehaviours.SKIRMISH[UnitDefNames[unitName].id] then
					scavBehaviours.SKIRMISH[UnitDefNames[unitName].id] = {distance = 500, chance = 0.1}
					scavBehaviours.COWARD[UnitDefNames[unitName].id] = {distance = 500, chance = 0.75}
				end
			end
			addNewSquad({
				type = "healerSea",
				weight = unitWeight,
				maxAnger = tierConfiguration[tier].maxAnger,
				minAnger = tierConfiguration[tier].minAnger,
				units = {
					{count = math.ceil(tierConfiguration[tier].maxSquadSize*0.25), unit = unitName}
				}
			})
		end
	end
end

--------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------- AIR
--------------------------------------------------------------------------------------------------------------------------------------------------------

for tier, _ in pairs(AirUnitsList.Land) do
	for unitName, _ in pairs(AirUnitsList.Land[tier]) do
		if UnitDefNames[unitName] then
			local unitWeight = AirUnitsList.Land[tier][unitName]
			addNewSquad({
				type = "basicAirLand",
				weight = unitWeight,
				maxAnger = 1000,
				minAnger = tierConfiguration[tier].minAnger,
				units = {
					{count = tierConfiguration[tier].maxSquadSize, unit = unitName}
				}
			})
			addNewSquad({
				type = "specialAirLand",
				weight = unitWeight,
				maxAnger = 1000,
				minAnger = tierConfiguration[tier].minAnger,
				units = {
					{count = tierConfiguration[tier].maxSquadSize*2, unit = unitName}
				}
			})
		end
	end
end

for tier, _ in pairs(AirUnitsList.Sea) do
	for unitName, _ in pairs(AirUnitsList.Sea[tier]) do
		if UnitDefNames[unitName] then
			local unitWeight = AirUnitsList.Sea[tier][unitName]
			addNewSquad({
				type = "basicAirSea",
				weight = unitWeight,
				maxAnger = 1000,
				minAnger = tierConfiguration[tier].minAnger,
				units = {
					{count = tierConfiguration[tier].maxSquadSize, unit = unitName}
				}
			})
			addNewSquad({
				type = "specialAirSea",
				weight = unitWeight,
				maxAnger = 1000,
				minAnger = tierConfiguration[tier].minAnger,
				units = {
					{count = tierConfiguration[tier].maxSquadSize*2, unit = unitName}
				}
			})
		end
	end
end

------Tier 1 0-25% (Land and Air)
addNewSquad({
	type = "healerLand",
	minAnger = tierConfiguration[2].minAnger,
	maxAnger = 1000,
	units = {
		{count = 5, unit = "armrectr_scav"},
		{count = 5, unit = "cornecro_scav"}
	}
}) --Rezzers
addNewSquad({
	type = "healerLand",
	weight = 20,
	minAnger = tierConfiguration[4].minAnger,
	maxAnger = 1000,
	units = {
		{count = 10, unit = "armrectr_scav"},
		{count = 10, unit = "cornecro_scav"}
	}
}) --Rezzers
addNewSquad({
	type = "healerLand",
	weight = 40,
	minAnger = tierConfiguration[6].minAnger,
	maxAnger = 1000,
	units = {
		{count = 20, unit = "armrectr_scav"},
		{count = 20, unit = "cornecro_scav"}
	}
}) --Rezzers
--Land
addNewSquad({
	type = "specialLand",
	weight = 6, 
	maxAnger = tierConfiguration[2].maxAnger,
	minAnger = tierConfiguration[2].minAnger,
	units = {
		{count = 13, unit = "armfav_scav"},
		{count = 13, unit = "corfav_scav"},
		{count = 13, unit = "legscout_scav"}
	}
}) --Rovers/Whole Tier Length
addNewSquad({
	type = "specialLand",
	weight = 4,
	maxAnger = tierConfiguration[2].maxAnger,
	minAnger = tierConfiguration[2].minAnger,
	units = {
		{count = 6, unit = "armflash_scav"},
		{count = 6, unit = "corgator_scav"},
		{count = 6, unit = "leghelios_scav"},
		{count = 6, unit = "leghades_scav"}
	}
}) --T1 Veh Raid
addNewSquad({
	type = "specialLand",
	weight = 4,
	maxAnger = tierConfiguration[3].maxAnger,
	minAnger = tierConfiguration[3].minAnger,
	units = {
		{count = 5, unit = "armstump_scav"},
		{count = 5, unit = "corraid_scav"},
		{count = 5, unit = "leggat_scav"},
		{count = 5, unit = "leghades_scav"}
	}
}) --T1 Veh Assault
addNewSquad({
	type = "specialLand",
	weight = 4,
	maxAnger = tierConfiguration[3].maxAnger,
	minAnger = tierConfiguration[3].minAnger,
	units = {
		{count = 2, unit = "armjanus_scav"},
		{count = 2, unit = "corlevlr_scav"},
		{count = 2, unit = "legrail_scav"},
		{count = 6, unit = "leghades_scav"}
	}
}) --T1 Veh Unique
addNewSquad({
	type = "specialLand",
	weight = 4,
	maxAnger = tierConfiguration[3].maxAnger,
	minAnger = tierConfiguration[3].minAnger,
	units = {
		{count = 1,unit = "armart_scav"},
		{count = 2, unit = "armsam_scav"},
		{count = 1, unit = "corwolv_scav"},
		{count = 2, unit = "cormist_scav"},
		{count = 2, unit = "legbar_scav"},
		{count = 8, unit = "leghades_scav"}
	}
}) --T1 Arty/AA
--air
addNewSquad({
	type = "specialAirLand",
	weight = 4,
	minAnger = tierConfiguration[2].minAnger,
	maxAnger = 1000,
	units = {
		{count = 3, unit = "armpeep_scav"},
		{count = 3, unit = "corfink_scav"},
		{count = 9, unit = "legfig_scav"}
	}
}) --T1 Air Scouts
addNewSquad({
	type = "specialAirLand",
	weight = 4,
	maxAnger = 1000,
	minAnger = tierConfiguration[3].minAnger,
	units = {
		{count = 12, unit = "corbw_scav"}
	}
}) --Bladewings
addNewSquad({
	type = "specialAirLand",
	weight = 4,
	maxAnger = 1000,
	minAnger = tierConfiguration[3].minAnger,
	units = 
	{
		{count = 20, unit = "armfig_scav"},
		{count = 20, unit = "corveng_scav"}
	}
}) --Fighters
addNewSquad({
	type = "specialAirSea",
	weight = 5,
	maxAnger = 1000,
	minAnger = tierConfiguration[3].minAnger,
	units = {
		{count = 20, unit = "armsfig_scav"},
		{count = 20, unit = "corsfix_scav"}
	}
}) --T2 Fighters
addNewSquad({
	type = "specialAirLand",
	weight = 4,
	maxAnger = 1000,
	minAnger = tierConfiguration[3].minAnger,
	units = {
		{count = 12, unit = "armthund_scav"},
		{count = 12, unit = "corshad_scav"},
		{count = 5, unit = "legcib_scav"}
	}
}) --Bombers
------Tier 2 25-60%
addNewSquad({
	type = "specialLand",
	weight = 6,
	maxAnger = tierConfiguration[4].maxAnger,
	minAnger = tierConfiguration[4].minAnger,
	units = {
		{count = 10, unit = "armfav_scav"},
		{count = 10, unit = "corfav_scav"},
		{count = 25, unit = "armzapper_scav"}
	}
}) --Rover and EMP Rover/Whole Tier Length
--Land
addNewSquad({
	type = "specialLand",
	weight = 4,
	maxAnger = tierConfiguration[4].maxAnger,
	minAnger = tierConfiguration[4].minAnger,
	units = {
		{count = 6, unit = "armlatnk_scav"},
		{count = 6, unit = "cortorch_scav"},
		{count = 6, unit = "legmrv_scav"}
	}
}) --T2 Veh Raid
addNewSquad({
	type = "specialLand",
	weight = 4,
	maxAnger = tierConfiguration[4].maxAnger,
	minAnger = tierConfiguration[4].minAnger,
	units = {
		{count = 6, unit = "armbull_scav"},
		{count = 6, unit = "correap_scav"},
		{count = 1, unit = "corgol_scav"},
		{count = 2, unit = "legaheattank_scav"},
		{count = 2, unit = "armyork_scav"},
		{count = 2, unit = "corsent_scav"},
		{count = 2, unit = "legvflak_scav"}
	}
}) --T2 Veh Assault/AA
addNewSquad({
	type = "specialLand",
	weight = 4,
	maxAnger = tierConfiguration[5].maxAnger,
	minAnger = tierConfiguration[5].minAnger,
	units = {
		{count = 2, unit = "armmanni_scav"},
		{count = 2, unit = "corban_scav"},
		{count = 1, unit = "legvcarry_scav"}
	}
}) --T2 Veh Unique
addNewSquad({
	type = "specialLand",
	weight = 4,
	maxAnger = tierConfiguration[5].maxAnger,
	minAnger = tierConfiguration[5].minAnger,
	units = {
		{count = 3, unit = "armmart_scav"},
		{count = 1, unit = "armmerl_scav"},
		{count = 1, unit = "armyork_scav"},
		{count = 3, unit = "cormart_scav"},
		{count = 1, unit = "corvroc_scav"},
		{count = 1, unit = "corsent_scav"},
		{count = 2, unit = "legvflak_scav"},
		{count = 1, unit = "leginf_scav"}
	}
}) --T2 Arty/AA
--air
addNewSquad({
	type = "specialAirLand",
	weight = 4,
	minAnger = tierConfiguration[5].minAnger,
	maxAnger = 1000,
	units = {
		{count = 3, unit = "armawac_scav"},
		{count = 3, unit = "corawac_scav"}
	}
}) --T2 Air Scouts
addNewSquad({
	type = "specialAirLand",
	weight = 4,
	minAnger = tierConfiguration[5].minAnger,
	maxAnger = 1000,
	units = {
		{count = 2, unit = "armstil_scav"}
	}
}) --EMP Bombers
addNewSquad({
	type = "specialAirLand",
	weight = 4,
	minAnger = tierConfiguration[5].minAnger,
	maxAnger = 1000,
	units = {
		{count = 20, unit = "armhawk_scav"},
		{count = 20, unit = "corvamp_scav"}
	}
}) --Fighters
addNewSquad({
	type = "specialAirSea",
	weight = 5,
	minAnger = tierConfiguration[5].minAnger,
	maxAnger = 1000,
	units = {
		{count = 20, unit = "armsfig_scav"},
		{count = 20, unit = "corsfix_scav"}
	}
}) --T2 Fighters

addNewSquad({
	type = "specialAirLand",
	weight = 4,
	minAnger = tierConfiguration[5].minAnger,
	maxAnger = 1000,
	units = {
		{count = 15, unit = "armblade_scav"},
		{count = 15, unit = "armbrawl_scav"},
		{count = 1, unit = "legfort_scav"},
		{count = 1, unit = "corcrw_scav"},
		{count = 1, unit = "corcrwh_scav"},
		{count = 15, unit = "corape_scav"}
	}
}) --T2 Gunships
------Tier 3 60-80%
--Dilluters
addNewSquad({
	type = "specialLand",
	weight = 8,
	minAnger = tierConfiguration[6].minAnger,
	maxAnger = tierConfiguration[6].maxAnger,
	units = {
		{count = 15, unit = "armfav_scav"},
		{count = 15, unit = "corfav_scav"},
		{count = 15, unit = "legscout_scav"}
	}
}) --Rover Whole Tier Length

addNewSquad({
	type = "specialLand",
	weight = 3,
	minAnger = tierConfiguration[6].minAnger,
	maxAnger = tierConfiguration[6].maxAnger,
	units = {
		{count = 6, unit = "cortorch_scav"},
		{count = 6, unit = "legmrv_scav"}
	}
}) --T2 Veh Raid
--Land
addNewSquad({
	type = "specialLand",
	weight = 3,
	minAnger = tierConfiguration[6].minAnger,
	maxAnger = tierConfiguration[6].maxAnger,
	units = {
		{count = 12, unit = "armmar_scav"}
	}
}) --T3 Raid

addNewSquad({
	type = "specialLand",
	weight = 4,
	minAnger = tierConfiguration[6].minAnger,
	maxAnger = tierConfiguration[6].maxAnger,
	units = {
		{count = 6, unit = "armmeatball_scav"},
		{count = 6, unit = "armassimilator_scav"},
		{count = 2, unit = "armyork_scav"},
		{count = 2, unit = "corsent_scav"},
		{count = 2, unit = "legvflak_scav"}
	}
}) --T3 Assault/AA
addNewSquad({
	type = "specialLand",
	weight = 4,
	maxAnger = tierConfiguration[6].maxAnger,
	minAnger = tierConfiguration[6].minAnger,
	units = {
		{count = 6, unit = "corshiva_scav"},
		{count = 2, unit = "armraz_scav"},
		{count = 1, unit = "legpede_scav"},
		{count = 1, unit = "armyork_scav"},
		{count = 1, unit = "corsent_scav"},
		{count = 2, unit = "legvflak_scav"}
	}
}) --T3 Assault/AA
addNewSquad({
	type = "specialLand",
	weight = 4,
	maxAnger = tierConfiguration[6].maxAnger,
	minAnger = tierConfiguration[6].minAnger,
	units = {
		{count = 2, unit = "armvang_scav"},
		{count = 2, unit = "corcat_scav"},
		{count = 1, unit = "armyork_scav"},
		{count = 1, unit = "corsent_scav"},
		{count = 2, unit = "legvflak_scav"}
	}
}) --T3 Arty/AA
addNewSquad({
	type = "specialLand",
	weight = 3,
	maxAnger = 1000,
	minAnger = tierConfiguration[6].minAnger,
	units = {
		{count = 5, unit = "armvadert4_scav"}
	}
}) --Epic Tumbleweeds
addNewSquad({
	type = "specialSea",
	weight = 3,
	maxAnger = 1000,
	minAnger = tierConfiguration[6].minAnger,
	units = {
		{count = 5, unit = "armvadert4_scav"}
	}
}) --Epic Tumbleweeds
--air
addNewSquad({
	type = "specialAirLand",
	weight = 4,
	maxAnger = 1000,
	minAnger = tierConfiguration[6].minAnger,
	units = {
		{count = 40, unit = "armfig_scav"},
		{count = 40, unit = "corveng_scav"}
	}
}) --T2 Fighters
addNewSquad({
	type = "specialAirSea",
	weight = 5,
	maxAnger = 1000,
	minAnger = tierConfiguration[6].minAnger,
	units = {
		{count = 40, unit = "armsfig_scav"},
		{count = 40, unit = "corsfix_scav"}
	}
}) --T2 Fighters
addNewSquad({
	type = "specialAirLand",
	weight = 2,
	maxAnger = 1000,
	minAnger = tierConfiguration[6].minAnger,
	units = {
		{count = 15, unit = "armblade_scav"},
		{count = 15, unit = "armbrawl_scav"},
		{count = 1, unit = "legfort_scav"},
		{count = 1, unit = "corcrw_scav"},
		{count = 1, unit = "corcrwh_scav"},
		{count = 15, unit = "corape_scav"}
	}
}) --T2 Gunships
------Tier 4 80%+
addNewSquad({
	type = "specialLand",
	weight = 3,
	maxAnger = 1000,
	minAnger = tierConfiguration[7].minAnger,
	units = {
		{count = 10 , unit = "armvadert4_scav"}
	}
}) --Epic Tumbleweeds
addNewSquad({
	type = "specialSea",
	weight = 3,
	maxAnger = 1000,
	minAnger = tierConfiguration[7].minAnger,
	units = {
		{count = 10, unit = "armvadert4_scav"}
	}
}) --Epic Tumbleweeds
addNewSquad({
	type = "specialAirLand",
	weight = 5,
	maxAnger = 1000,
	minAnger = tierConfiguration[7].minAnger,
	units = {
		{count = 80, unit = "armfig_scav"},
		{count = 80, unit = "corveng_scav"}
	}
}) --T2 Fighters
addNewSquad({
	type = "specialAirLand",
	weight = 1,
	maxAnger = 1000,
	minAnger = tierConfiguration[7].minAnger,
	units = {
		{count = 10, unit = "armfepocht4_scav"}
	}
}) --Armada Flying Flagships
addNewSquad({
	type = "specialAirLand",
	weight = 1,
	maxAnger = 1000,
	minAnger = tierConfiguration[7].minAnger,
	units = {
		{count = 10, unit = "corfblackhyt4_scav"}
	}
}) --Cortex Flying Flagships
addNewSquad({
	type = "specialAirSea",
	weight = 5,
	maxAnger = 1000,
	minAnger = tierConfiguration[7].minAnger,
	units = {
		{count = 80, unit = "armsfig_scav"},
		{count = 80, unit = "corsfix_scav"}
	}
}) --T2 Fighters
addNewSquad({
	type = "specialAirSea",
	weight = 1,
	maxAnger = 1000,
	minAnger = tierConfiguration[7].minAnger,
	units = {
		{count = 10, unit = "armfepocht4_scav"}
	}
}) --Armada Flying Flagships
addNewSquad({
	type = "specialAirSea",
	weight = 1,
	maxAnger = 1000,
	minAnger = tierConfiguration[7].minAnger,
	units = {
		{count = 10, unit = "corfblackhyt4_scav"}
	}
}) --Cortex Flying Flagships

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
	["legafus"] = true,
	["armafust3"] = true,
	["corafust3"] = true,
	["legafust3"] = true,
	-- T2 Metal Makers
	["armmmkr"] = true,
	["cormmkr"] = true,
	["legadveconv"] = true,
	["armmmkrt3"] = true,
	["cormmkrt3"] = true,
	["legadveconvt3"] = true,
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
	unprocessedScavTurrets  = table.copy(Turrets),
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
	economyScale			= economyScale,
}

for key, value in pairs(difficultyParameters[difficulty]) do
	config[key] = value
end

return config
