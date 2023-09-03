
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
		gracePeriod       		= 8 * Spring.GetModOptions().scav_graceperiodmult * 60,
		queenTime      	  		= 50 * Spring.GetModOptions().scav_queentimemult * 60, -- time at which the queen appears, frames
		scavSpawnRate   		= 120 * Spring.GetModOptions().scav_spawntimemult,
		burrowSpawnRate   		= 240 * Spring.GetModOptions().scav_spawntimemult,
		turretSpawnRate   		= 120 * Spring.GetModOptions().scav_spawntimemult,
		queenSpawnMult    		= 1,
		angerBonus        		= 1,
		maxXP			  		= 0.5,
		spawnChance       		= 0.1,
		damageMod         		= 0.5,
		maxBurrows        		= 1000,
		minScavs		  		= 5,
		maxScavs		  		= 25,
		scavPerPlayerMultiplier = 0.25,
		queenName         		= 'corcomboss_scav',
		queenResistanceMult   	= 0.5,
	},

	[difficulties.easy] = {
		gracePeriod       		= 7 * Spring.GetModOptions().scav_graceperiodmult * 60,
		queenTime      	  		= 45 * Spring.GetModOptions().scav_queentimemult * 60, -- time at which the queen appears, frames
		scavSpawnRate   		= 90 * Spring.GetModOptions().scav_spawntimemult,
		burrowSpawnRate   		= 210 * Spring.GetModOptions().scav_spawntimemult,
		turretSpawnRate   		= 100 * Spring.GetModOptions().scav_spawntimemult,
		queenSpawnMult    		= 1,
		angerBonus        		= 1.2,
		maxXP			  		= 1,
		spawnChance       		= 0.2,
		damageMod         		= 0.75,
		maxBurrows        		= 1000,
		minScavs		  		= 5,
		maxScavs		  		= 30,
		scavPerPlayerMultiplier = 0.25,
		queenName         		= 'corcomboss_scav',
		queenResistanceMult   	= 0.75,
	},
	[difficulties.normal] = {
		gracePeriod       		= 6 * Spring.GetModOptions().scav_graceperiodmult * 60,
		queenTime      	  		= 40 * Spring.GetModOptions().scav_queentimemult * 60, -- time at which the queen appears, frames
		scavSpawnRate   		= 60 * Spring.GetModOptions().scav_spawntimemult,
		burrowSpawnRate   		= 180 * Spring.GetModOptions().scav_spawntimemult,
		turretSpawnRate   		= 80 * Spring.GetModOptions().scav_spawntimemult,
		queenSpawnMult    		= 3,
		angerBonus        		= 1.4,
		maxXP			  		= 1.5,
		spawnChance       		= 0.3,
		damageMod         		= 1,
		maxBurrows        		= 1000,
		minScavs		  		= 5,
		maxScavs		  		= 35,
		scavPerPlayerMultiplier = 0.25,
		queenName         		= 'corcomboss_scav',
		queenResistanceMult  	= 1,
	},
	[difficulties.hard] = {
		gracePeriod       		= 5 * Spring.GetModOptions().scav_graceperiodmult * 60,
		queenTime      	  		= 40 * Spring.GetModOptions().scav_queentimemult * 60, -- time at which the queen appears, frames
		scavSpawnRate   		= 50 * Spring.GetModOptions().scav_spawntimemult,
		burrowSpawnRate   		= 150 * Spring.GetModOptions().scav_spawntimemult,
		turretSpawnRate   		= 60 * Spring.GetModOptions().scav_spawntimemult,
		queenSpawnMult    		= 3,
		angerBonus        		= 1.6,
		maxXP			  		= 2,
		spawnChance       		= 0.4,
		damageMod         		= 1.25,
		maxBurrows        		= 1000,
		minScavs		  		= 5,
		maxScavs		  		= 40,
		scavPerPlayerMultiplier = 0.25,
		queenName         		= 'corcomboss_scav',
		queenResistanceMult   	= 1.33,
	},
	[difficulties.veryhard] = {
		gracePeriod       		= 4 * Spring.GetModOptions().scav_graceperiodmult * 60,
		queenTime      	  		= 35 * Spring.GetModOptions().scav_queentimemult * 60, -- time at which the queen appears, frames
		scavSpawnRate  			= 40 * Spring.GetModOptions().scav_spawntimemult,
		burrowSpawnRate   		= 120 * Spring.GetModOptions().scav_spawntimemult,
		turretSpawnRate   		= 40 * Spring.GetModOptions().scav_spawntimemult,
		queenSpawnMult    		= 3,
		angerBonus        		= 1.8,
		maxXP			  		= 2.5,
		spawnChance       		= 0.5,
		damageMod         		= 1.5,
		maxBurrows        		= 1000,
		minScavs		  		= 5,
		maxScavs		  		= 45,
		scavPerPlayerMultiplier = 0.25,
		queenName         		= 'corcomboss_scav',
		queenResistanceMult   	= 1.67,
	},
	[difficulties.epic] = {
		gracePeriod       		= 3 * Spring.GetModOptions().scav_graceperiodmult * 60,
		queenTime      	  		= 30 * Spring.GetModOptions().scav_queentimemult * 60, -- time at which the queen appears, frames
		scavSpawnRate   		= 30 * Spring.GetModOptions().scav_spawntimemult,
		burrowSpawnRate   		= 90 * Spring.GetModOptions().scav_spawntimemult,
		turretSpawnRate   		= 20 * Spring.GetModOptions().scav_spawntimemult,
		queenSpawnMult    		= 3,
		angerBonus        		= 2,
		maxXP			  		= 3,
		spawnChance       		= 0.6,
		damageMod         		= 2,
		maxBurrows        		= 1000,
		minScavs		  		= 5,
		maxScavs		  		= 50,
		scavPerPlayerMultiplier = 0.25,
		queenName         		= 'corcomboss_scav',
		queenResistanceMult   	= 2,
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

local TierIntroductionAnger = { -- Double for basic squads
	[1] = 0,
	[2] = 10,
	[3] = 25,
	[4] = 40,
	[5] = 60,
	[6] = 80,
}

----------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------
local LandUnitsList = {
		Raid = {
			[1] = {
				--Armada 
				["armflea_scav"] = 2,
				["armpw_scav"] = 3,
				["armfav_scav"] = 2,
				["armsh_scav"] = 1,
				--Cortex
				["corak_scav"] = 3,
				["corfav_scav"] = 2,
				["corsh_scav"] = 1,
				--Legion
				["leggob_scav"] = 2,
			},
			[2] = {
				--Armada
				["armflash_scav"] = 2,
				["armzapper_scav"] = 1,
		        --Cortex
				["corgator_scav"] = 2,
                --Legion
				["leghades_scav"] = 2,
			},
			[3] = {
                --Armada
				["armlatnk_scav"] = 3,
				["armamph_scav"] = 1,
				["armfast_scav"] = 3,
				--Cortex
				["cortorch_scav"] = 1,
				["corsala_scav"] = 1,
				["corpyro_scav"] = 3,
				["corseal_scav"] = 1,
				["coramph_scav"] = 1,
				--Legion
				["legmrv_scav"] = 1,
				["legstr_scav"] = 3,
			},
			[4] = {
                --Armada

				--Cortex

				--Legion


			},
			[5] = {
				--Armada
				["armpwt4_scav"] = 1,
				["armmar_scav"] = 1,
				--Cortex
				["corakt4_scav"] = 1,
				--Legion
                --N/A
			},
			[6] = {
			    --Armada
				["armraz_scav"] = 1,
				--Cortex
				["cordemont4_scav"] = 1,
				--Legion	
                --N/A
			},
		},
		Assault = {
			[1] = {
				--Armada
				["armham_scav"] = 3,
				["armpincer_scav"] = 1,
				--Cortex
				["corthud_scav"] = 3,
				["corgarp_scav"] = 1,
				--Legion
				["legcen_scav"] = 1,
				["leglob_scav"] = 2,
			},
			[2] = {
				--Armada
				["armwar_scav"] = 2,
				["armstump_scav"] = 2,
				["armjanus_scav"] = 1,
				["armanac_scav"] = 1,
				--Cortex
				["corraid_scav"] = 2,
				["corlevlr_scav"] = 2,
				["corhal_scav"] = 1,
				["corsnap_scav"] = 1,
				--Legion
				["leggat_scav"] = 2,
				["legkark_scav"] = 2,
			},
			[3] = {
				--Armada
				["armzeus_scav"] = 1,
				--Cortex
				["corcan_scav"] = 1,
				--Legion
				["legshot_scav"] = 1,

			},
			[4] = {
				--Armada
				["armsnipe_scav"] = 2,
				["armvader_scav"] = 1,
				["armsptk_scav"] = 1,
				["armbull_scav"] = 3,
				["armcroc_scav"] = 1,
				--Cortex
				["corparrow_scav"] = 1,
				["corftiger_scav"] = 3,
				["corgol_scav"] = 1,
				["corroach_scav"] = 1,
				["corsktl_scav"] = 1,
				["cortermite_scav"] = 1,
				["corsumo_scav"] = 2,
				["correap_scav"] = 3,
				["corgatreap_scav"] = 2,
				--Legion
				["legsco_scav"] = 1,
				["leginc_scav"] = 1,
			},
			[5] = {
				--Armada
				["armassimilator_scav"] = 1,
				["armmeatball_scav"] = 1,
				["armlun_scav"] = 1,
				--Cortex
				["corshiva_scav"] = 2,
				["corkarg_scav"] = 1,
				["corsok_scav"] = 1,
				--Legion
				--N/A
			},
			[6] = {
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
				["legpede_scav"] = 1,
			},
		},
		Support = {
			[1] = {
				--Armada
				["armrock_scav"] = 2,
				["armjeth_scav"] = 1,
				["armah_scav"] = 1,
				--Cortex	
				["corstorm_scav"] = 2,
				["corcrash_scav"] = 1,
				["corah_scav"] = 1,
				--Legion
				["legbal_scav"] = 2,
			},
			[2] = {
				--Armada
				["armart_scav"] = 2,
				["armsam_scav"] = 1,
				["armmh_scav"] = 1,
				--Cortex
				["corwolv_scav"] = 2,
				["cormist_scav"] = 1,
				["cormh_scav"] = 1,
				--Legion
				["leghelios_scav"] = 1,
				["legbar_scav"] = 1,
				["legrail_scav"] = 1,
			},
			[3] = {
				--Armada	
				["armfido_scav"] = 2,
				["armaak_scav"] = 1,
				["armmav_scav"] = 1,
				["armyork_scav"] = 1,
				["armmart_scav"] = 1,
				--Cortex
				["cormart_scav"] = 1,
				["corsent_scav"] = 1,
				["coraak_scav"] = 1,
				["cormort_scav"] = 2,
				--Legion
				["legvcarry_scav"] = 1,
				["legbart_scav"] = 1,

			},
			[4] = {
				--Armada
				["armfboy_scav"] = 1,
				["armmanni_scav"] = 1,
				["armmerl_scav"] = 1,
				--Cortex
				["corban_scav"] = 1,
				["corvroc_scav"] = 1,
				["cortrem_scav"] = 1,
				["corhrk_scav"] = 1,
				--Legion
				["leginf_scav"] = 1,

			},
			[5] = {
				--Armada
				["armvang_scav"] = 1,
				--Cortex
				["corcat_scav"] = 1,
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
				["armck_scav"] = 1,
				["armrectr_scav"] = 20,
				["armcv_scav"] = 1,
				--Cortex
				["corck_scav"] = 1,
				["cornecro_scav"] = 20,
				["corcv_scav"] = 1,
				--Legion
				["legcv_scav"] = 1,
				["legck_scav"] = 1,
			},
			[2] = {
				--Armada

				--Cortex

				--Legion

			},
			[3] = {
				--Armada	
				["armack_scav"] = 1,
				["armacv_scav"] = 1,
				["armfark_scav"] = 1,
				["armdecom_scav"] = 1,
				["armconsul_scav"] = 1,
				--Cortex
				["corack_scav"] = 1,
				["coracv_scav"] = 1,
				["corfast_scav"] = 1,
				["cordecom_scav"] = 1,
				["corvac_scav"] = 1,
				["cormando_scav"] = 1,
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
				["armpt_scav"] = 1,
			},
			[2] = {
				["armdecade_scav"] = 1,
			},
			[3] = {
				["armdecade_scav"] = 1,
			},
			[4] = {
				["armdecade_scav"] = 1,
			},
			[5] = {
				["armdecade_scav"] = 1,
			},
			[6] = {
				["armdecade_scav"] = 1,
			},
		},
		Assault = {
			[1] = {
				["armpship_scav"] = 1,
			},
			[2] = {
				["armpship_scav"] = 1,
			},
			[3] = {
				["armpship_scav"] = 1,
			},
			[4] = {
				["armpship_scav"] = 1,
			},
			[5] = {
				["armpship_scav"] = 1,
			},
			[6] = {
				["armpship_scav"] = 1,
			},
		},
		Support = {
			[1] = {
				["armroy_scav"] = 1,
			},
			[2] = {
				["armroy_scav"] = 1,
			},
			[3] = {
				["armroy_scav"] = 1,
			},
			[4] = {
				["armroy_scav"] = 1,
			},
			[5] = {
				["armroy_scav"] = 1,
			},
			[6] = {
				["armroy_scav"] = 1,
			},
		},
		Healer = {
			[1] = {
				["armcs_scav"] = 1,
			},
			[2] = {
				["armcs_scav"] = 1,
			},
			[3] = {
				["armcs_scav"] = 1,
			},
			[4] = {
				["armcs_scav"] = 1,
			},
			[5] = {
				["armcs_scav"] = 1,
			},
			[6] = {
				["armcs_scav"] = 1,
			},
		},
	}

----------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------

local AirUnitsList = {
		[1] = {
			["armpeep_scav"] = 1,
		},
		[2] = {
			["armkam_scav"] = 1,
		},
		[3] = {
			["armkam_scav"] = 1,
		},
		[4] = {
			["armkam_scav"] = 1,
		},
		[5] = {
			["armkam_scav"] = 1,
		},
		[6] = {
			["armkam_scav"] = 1,
		},
	}
----------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------
-- types: normal, antiair, nuke, lrpc
-- surfaces: land, sea, mixed
-- don't put the same turret twice in here, ever.
local Turrets = {
		[1] = {
			["armllt_scav"] = {type = "normal", surface = "land", spawnedPerWave = 1, maxExisting = 10},
			["corllt_scav"] = {type = "normal", surface = "land", spawnedPerWave = 1, maxExisting = 10},
			["armrl_scav"] = {type = "antiair", surface = "land", spawnedPerWave = 1, maxExisting = 10},
			["corrl_scav"] = {type = "antiair", surface = "land", spawnedPerWave = 1, maxExisting = 10},
		},
		[2] = {

		},
		[3] = {

		},
		[4] = {

		},
		[5] = {

		},
		[6] = {

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
			Spring.Echo(UnitDefs[UnitDefNames[turret].id].name)
			scavTurrets[turret] = { 
				minQueenAnger = TierIntroductionAnger[tier],
				spawnedPerWave = turretInfo.spawnedPerWave or 1,
				maxExisting = turretInfo.maxExisting or 10,
				maxQueenAnger = turretInfo.maxQueenAnger or 1000,
				surfaceType = turretInfo.surface or "land",
			}
		end
	end
end


scavBehaviours = {
	SKIRMISH = { -- Run away from target after target gets hit
		--[UnitDefNames["raptor1x_spectre"].id] = { distance = 500, chance = 0.25, teleport = true, teleportcooldown = 2,},
	},
	COWARD = { -- Run away from target after getting hit by enemy
		--[UnitDefNames["raptor1x_spectre"].id] = { distance = 500, chance = 0.25, teleport = true, teleportcooldown = 2,},
	},
	BERSERK = { -- Run towards target after getting hit by enemy or after hitting the target
		--[UnitDefNames["raptor1x_spectre"].id] = { distance = 1000, chance = 0.25},
	},
	HEALER = { -- Getting long max lifetime and always use Fight command. These units spawn as healers from burrows and queen
		--[UnitDefNames["raptorhealer1"].id] = true,
	},
	ARTILLERY = { -- Long lifetime and no regrouping, always uses Fight command to keep distance
		--[UnitDefNames["raptorr1"].id] = true,
	},
	KAMIKAZE = { -- Long lifetime and no regrouping, always uses Move command to rush into the enemy
		--[UnitDefNames["raptor_dodo1"].id] = true,
	},
	ALLOWFRIENDLYFIRE = {
		--[UnitDefNames["raptorr1"].id] = true,
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
	air = {}, 		-- Aircrafts
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
		Spring.Echo(unitName)
		for i = 1,5 do
			if i < 5 then
				addNewSquad({ type = "basicLand", minAnger = TierIntroductionAnger[tier]*2+((i-1)*5), units = { (#TierIntroductionAnger+1-tier)*2+((i-1)*3) .. " " .. unitName}, weight = unitWeight, maxAnger = TierIntroductionAnger[tier]*2+10+((i-1)*5) })
				addNewSquad({ type = "specialLand", minAnger = TierIntroductionAnger[tier]+((i-1)*5), units = { (#TierIntroductionAnger+1-tier)*2+((i-1)*3) .. " " .. unitName}, weight = unitWeight, maxAnger = TierIntroductionAnger[tier]+5+((i-1)*5) })
			else
				addNewSquad({ type = "basicLand", minAnger = TierIntroductionAnger[tier]*2+((i-1)*5), units = { (#TierIntroductionAnger+1-tier)*2+((i-1)*3) .. " " .. unitName}, weight = unitWeight, maxAnger = 1000 })
				addNewSquad({ type = "specialLand", minAnger = TierIntroductionAnger[tier]+((i-1)*5), units = { (#TierIntroductionAnger+1-tier)*2+((i-1)*3) .. " " .. unitName}, weight = unitWeight, maxAnger = 1000 })
			end
		end
	end
end

for tier, _ in pairs(LandUnitsList.Assault) do
	for unitName, _ in pairs(LandUnitsList.Assault[tier]) do
		local unitWeight = LandUnitsList.Assault[tier][unitName]
		Spring.Echo(unitName)
		if not scavBehaviours.BERSERK[UnitDefNames[unitName].id] then
			scavBehaviours.BERSERK[UnitDefNames[unitName].id] = {distance = 2000, chance = 0.01}
		end
		for i = 1,5 do
			if i < 5 then
				addNewSquad({ type = "basicLand", minAnger = TierIntroductionAnger[tier]*2+((i-1)*5), units = { #TierIntroductionAnger+1-tier+((i-1)*2) .. " " .. unitName}, weight = unitWeight, maxAnger = TierIntroductionAnger[tier]*2+10+((i-1)*5) })
				addNewSquad({ type = "specialLand", minAnger = TierIntroductionAnger[tier]+((i-1)*5), units = { #TierIntroductionAnger+1-tier+((i-1)*2) .. " " .. unitName}, weight = unitWeight, maxAnger = TierIntroductionAnger[tier]+5+((i-1)*5) })
			else
				addNewSquad({ type = "basicLand", minAnger = TierIntroductionAnger[tier]*2+((i-1)*5), units = { #TierIntroductionAnger+1-tier+((i-1)*2) .. " " .. unitName}, weight = unitWeight, maxAnger = 1000 })
				addNewSquad({ type = "specialLand", minAnger = TierIntroductionAnger[tier]+((i-1)*5), units = { #TierIntroductionAnger+1-tier+((i-1)*2) .. " " .. unitName}, weight = unitWeight, maxAnger = 1000 })
			end
		end
	end
end

for tier, _ in pairs(LandUnitsList.Support) do
	for unitName, _ in pairs(LandUnitsList.Support[tier]) do
		local unitWeight = LandUnitsList.Support[tier][unitName]
		Spring.Echo(unitName)
		if not scavBehaviours.SKIRMISH[UnitDefNames[unitName].id] then
			scavBehaviours.SKIRMISH[UnitDefNames[unitName].id] = {distance = 500, chance = 0.1}
			scavBehaviours.COWARD[UnitDefNames[unitName].id] = {distance = 500, chance = 0.75}
			scavBehaviours.ARTILLERY[UnitDefNames[unitName].id] = true
		end
		for i = 1,5 do
			if i < 5 then
				addNewSquad({ type = "basicLand", minAnger = TierIntroductionAnger[tier]*2+((i-1)*5), units = { #TierIntroductionAnger+1-tier+((i-1)*1) .. " " .. unitName}, weight = unitWeight, maxAnger = TierIntroductionAnger[tier]*2+10+((i-1)*5) })
				addNewSquad({ type = "specialLand", minAnger = TierIntroductionAnger[tier]+((i-1)*5), units = { #TierIntroductionAnger+1-tier+((i-1)*1) .. " " .. unitName}, weight = unitWeight, maxAnger = TierIntroductionAnger[tier]+5+((i-1)*5) })
			else
				addNewSquad({ type = "basicLand", minAnger = TierIntroductionAnger[tier]*2+((i-1)*5), units = { #TierIntroductionAnger+1-tier+((i-1)*1) .. " " .. unitName}, weight = unitWeight, maxAnger = 1000 })
				addNewSquad({ type = "specialLand", minAnger = TierIntroductionAnger[tier]+((i-1)*5), units = { #TierIntroductionAnger+1-tier+((i-1)*1) .. " " .. unitName}, weight = unitWeight, maxAnger = 1000 })
			end
		end
	end
end

for tier, _ in pairs(LandUnitsList.Healer) do
	for unitName, _ in pairs(LandUnitsList.Healer[tier]) do
		local unitWeight = LandUnitsList.Healer[tier][unitName]
		Spring.Echo(unitName)
		if not scavBehaviours.HEALER[UnitDefNames[unitName].id] then
			scavBehaviours.HEALER[UnitDefNames[unitName].id] = true
			if not scavBehaviours.SKIRMISH[UnitDefNames[unitName].id] then
				scavBehaviours.SKIRMISH[UnitDefNames[unitName].id] = {distance = 500, chance = 0.1}
				scavBehaviours.COWARD[UnitDefNames[unitName].id] = {distance = 500, chance = 0.75}
			end
		end
		for i = 1,5 do
			if i < 5 then
				addNewSquad({ type = "healerLand", minAnger = TierIntroductionAnger[tier]+((i-1)*5), units = { (#TierIntroductionAnger+1-tier)*2 .. " " .. unitName}, weight = unitWeight, maxAnger = TierIntroductionAnger[tier]+5+((i-1)*5) })
			else
				addNewSquad({ type = "healerLand", minAnger = TierIntroductionAnger[tier]+((i-1)*5), units = { (#TierIntroductionAnger+1-tier)*2 .. " " .. unitName}, weight = unitWeight, maxAnger = 1000 })
			end
		end
	end
end

--------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------- SEA
--------------------------------------------------------------------------------------------------------------------------------------------------------

for tier, _ in pairs(SeaUnitsList.Raid) do
	for unitName, _ in pairs(SeaUnitsList.Raid[tier]) do
		local unitWeight = SeaUnitsList.Raid[tier][unitName]
		Spring.Echo(unitName)
		for i = 1,5 do
			if i < 5 then
				addNewSquad({ type = "basicSea", minAnger = TierIntroductionAnger[tier]*2+((i-1)*5), units = { #TierIntroductionAnger+1-tier+((i-1)*2) .. " " .. unitName}, weight = unitWeight, maxAnger = TierIntroductionAnger[tier]*2+10+((i-1)*5) })
				addNewSquad({ type = "specialSea", minAnger = TierIntroductionAnger[tier]+((i-1)*5), units = { #TierIntroductionAnger+1-tier+((i-1)*2) .. " " .. unitName}, weight = unitWeight, maxAnger = TierIntroductionAnger[tier]+5+((i-1)*5) })
			else
				addNewSquad({ type = "basicSea", minAnger = TierIntroductionAnger[tier]*2+((i-1)*5), units = { #TierIntroductionAnger+1-tier+((i-1)*2) .. " " .. unitName}, weight = unitWeight, maxAnger = 1000 })
				addNewSquad({ type = "specialSea", minAnger = TierIntroductionAnger[tier]+((i-1)*5), units = { #TierIntroductionAnger+1-tier+((i-1)*2) .. " " .. unitName}, weight = unitWeight, maxAnger = 1000 })
			end
		end
	end
end

for tier, _ in pairs(SeaUnitsList.Assault) do
	for unitName, _ in pairs(SeaUnitsList.Assault[tier]) do
		local unitWeight = SeaUnitsList.Assault[tier][unitName]
		Spring.Echo(unitName)
		if not scavBehaviours.BERSERK[UnitDefNames[unitName].id] then
			scavBehaviours.BERSERK[UnitDefNames[unitName].id] = {distance = 2000, chance = 0.01}
		end
		for i = 1,5 do
			if i < 5 then
				addNewSquad({ type = "basicSea", minAnger = TierIntroductionAnger[tier]*2+((i-1)*5), units = { math.ceil((#TierIntroductionAnger+1-tier)/2)+((i-1)*1) .. " " .. unitName}, weight = unitWeight, maxAnger = TierIntroductionAnger[tier]*2+10+((i-1)*5) })
				addNewSquad({ type = "specialSea", minAnger = TierIntroductionAnger[tier]+((i-1)*5), units = { math.ceil((#TierIntroductionAnger+1-tier)/2)+((i-1)*1) .. " " .. unitName}, weight = unitWeight, maxAnger = TierIntroductionAnger[tier]+5+((i-1)*5) })
			else
				addNewSquad({ type = "basicSea", minAnger = TierIntroductionAnger[tier]*2+((i-1)*5), units = { math.ceil((#TierIntroductionAnger+1-tier)/2)+((i-1)*1) .. " " .. unitName}, weight = unitWeight, maxAnger = 1000 })
				addNewSquad({ type = "specialSea", minAnger = TierIntroductionAnger[tier]+((i-1)*5), units = { math.ceil((#TierIntroductionAnger+1-tier)/2)+((i-1)*1) .. " " .. unitName}, weight = unitWeight, maxAnger = 1000 })
			end
		end
	end
end

for tier, _ in pairs(SeaUnitsList.Support) do
	for unitName, _ in pairs(SeaUnitsList.Support[tier]) do
		local unitWeight = SeaUnitsList.Support[tier][unitName]
		Spring.Echo(unitName)
		if not scavBehaviours.SKIRMISH[UnitDefNames[unitName].id] then
			scavBehaviours.SKIRMISH[UnitDefNames[unitName].id] = {distance = 500, chance = 0.1}
			scavBehaviours.COWARD[UnitDefNames[unitName].id] = {distance = 500, chance = 0.75}
			scavBehaviours.ARTILLERY[UnitDefNames[unitName].id] = true
		end
		for i = 1,5 do
			if i < 5 then
				addNewSquad({ type = "basicSea", minAnger = TierIntroductionAnger[tier]*2+((i-1)*5), units = { math.ceil((#TierIntroductionAnger+1-tier)/2)+((i-1)*1) .. " " .. unitName}, weight = unitWeight, maxAnger = TierIntroductionAnger[tier]*2+10+((i-1)*5) })
				addNewSquad({ type = "specialSea", minAnger = TierIntroductionAnger[tier]+((i-1)*5), units = { math.ceil((#TierIntroductionAnger+1-tier)/2)+((i-1)*1) .. " " .. unitName}, weight = unitWeight, maxAnger = TierIntroductionAnger[tier]+5+((i-1)*5) })
			else 
				addNewSquad({ type = "basicSea", minAnger = TierIntroductionAnger[tier]*2+((i-1)*5), units = { math.ceil((#TierIntroductionAnger+1-tier)/2)+((i-1)*1) .. " " .. unitName}, weight = unitWeight, maxAnger = 1000 })
				addNewSquad({ type = "specialSea", minAnger = TierIntroductionAnger[tier]+((i-1)*5), units = { math.ceil((#TierIntroductionAnger+1-tier)/2)+((i-1)*1) .. " " .. unitName}, weight = unitWeight, maxAnger = 1000 })
			end
		end
	end
end

for tier, _ in pairs(SeaUnitsList.Healer) do
	for unitName, _ in pairs(SeaUnitsList.Healer[tier]) do
		local unitWeight = SeaUnitsList.Healer[tier][unitName]
		Spring.Echo(unitName)
		if not scavBehaviours.HEALER[UnitDefNames[unitName].id] then
			scavBehaviours.HEALER[UnitDefNames[unitName].id] = true
		end
		for i = 1,5 do
			if tier < #TierIntroductionAnger and i < 5 then
				addNewSquad({ type = "healerSea", minAnger = TierIntroductionAnger[tier]+((i-1)*5), units = { #TierIntroductionAnger+1-tier .. " " .. unitName}, weight = unitWeight, maxAnger = TierIntroductionAnger[tier]+5+((i-1)*5) })
			else
				addNewSquad({ type = "healerSea", minAnger = TierIntroductionAnger[tier]+((i-1)*5), units = { #TierIntroductionAnger+1-tier .. " " .. unitName}, weight = unitWeight, maxAnger = 1000 })
			end
		end
	end
end

--------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------- AIR
--------------------------------------------------------------------------------------------------------------------------------------------------------

for tier, _ in pairs(AirUnitsList) do
	for unitName, _ in pairs(AirUnitsList[tier]) do
		local unitWeight = AirUnitsList[tier][unitName]
		Spring.Echo(unitName)
		for i = 1,5 do
			if tier < #TierIntroductionAnger and i < 5 then
				addNewSquad({ type = "air", minAnger = TierIntroductionAnger[tier]+((i-1)*5), units = { (#TierIntroductionAnger+1-tier)*2+((i-1)*3) .. " " .. unitName}, weight = unitWeight, maxAnger = TierIntroductionAnger[tier]+5+((i-1)*5) })
			else
				addNewSquad({ type = "air", minAnger = TierIntroductionAnger[tier]+((i-1)*5), units = { (#TierIntroductionAnger+1-tier)*2+((i-1)*3) .. " " .. unitName}, weight = unitWeight, maxAnger = 1000 })
			end
		end
	end
end

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

local highValueTargets = { -- Priority targets for Scav. Must be immobile to prevent issues.
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
	-- T2 Metal Extractors
	[UnitDefNames["cormoho"].id] 	= true,
	[UnitDefNames["armmoho"].id] 	= true,
	-- Nukes
	[UnitDefNames["corsilo"].id] 	= true,
	[UnitDefNames["armsilo"].id] 	= true,
	-- Antinukes
	[UnitDefNames["armamd"].id] 	= true,
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
