-- Modoptions
	-- Numbers and Bools
	local ScavBossHealthModoption = Spring.GetModOptions().scavbosshealth
	local ScavTechCurveModoption = Spring.GetModOptions().scavtechcurve
	local ScavUnitCountModoption = Spring.GetModOptions().scavunitcountmultiplier
	local ScavUnitSpawnFrequencyModoption = Spring.GetModOptions().scavunitspawnmultiplier
	local ScavUnitVeterancyModoption = Spring.GetModOptions().scavunitspawnmultiplier
	local ScavGracePeriodModoption = Spring.GetModOptions().scavgraceperiod

	local scavDifficulty = Spring.GetModOptions().scavdifficulty
	if scavDifficulty == "noob" then
		spawnmultiplier = 0.1
		scavStatsDifficulty = "Noob"
	elseif scavDifficulty == "veryeasy" then
		spawnmultiplier = 0.5
		scavStatsDifficulty = "Very Easy"
	elseif scavDifficulty == "easy" then
		spawnmultiplier = 0.75
		scavStatsDifficulty = "Easy"
	elseif scavDifficulty == "medium" then
		spawnmultiplier = 1
		scavStatsDifficulty = "Medium"
	elseif scavDifficulty == "hard" then
		spawnmultiplier = 1.25
		scavStatsDifficulty = "Hard"
	elseif scavDifficulty == "veryhard" then
		spawnmultiplier = 1.5
		scavStatsDifficulty = "Very Hard"
	elseif scavDifficulty == "expert" then
		spawnmultiplier = 2
		scavStatsDifficulty = "Expert"
	elseif scavDifficulty == "brutal" then
		spawnmultiplier = 3
		scavStatsDifficulty = "Brutal"
	else
		spawnmultiplier = 0.5
		scavStatsDifficulty = "Very Easy"
	end

	-- Strings

	local endlessModeEnabled = Spring.GetModOptions().scavendless

	local randomEventsEnabled = Spring.GetModOptions().scavevents
	local eventsAmountModoption = Spring.GetModOptions().scaveventsamount
	local scavRandomEventsAmountModoption

	if eventsAmountModoption == "normal" then
		scavRandomEventsAmountModoption = 1
	elseif eventsAmountModoption == "lower" then
		scavRandomEventsAmountModoption = 2
	elseif eventsAmountModoption == "higher" then
		scavRandomEventsAmountModoption = 0.5
	end

	local initialBonusCommanderEnabled = Spring.GetModOptions().scavinitialbonuscommander

-- End of Modoptions


scavconfig = {
	difficulty = {
		easy = 1,
		medium = 2,
		hard = 3,
		brutal = 5,
	},
	unitnamesuffix = "_scav",
	messenger = true, -- BYAR specific thing, don't enable otherwise (or get gui_messages.lua from BYAR)
	modules = {
		buildingSpawnerModule 			= false,
		constructorControllerModule 	= true,
		factoryControllerModule 		= true,
		unitSpawnerModule 				= true,
		startBoxProtection				= true,
		reinforcementsModule			= true, --disabled for now for weird victory conditions and too much hp
		randomEventsModule				= randomEventsEnabled,
		stockpilers						= true,
		nukes							= true,
	},

	scoreConfig = {
		-- set to 0 to disable
		scorePerMetal 					= 5, 	-- thisvalue*metalproduction
		scorePerEnergy 					= 1,	-- thisvalue*energyproduction
		scorePerSecond 					= 1,	-- thisvalue*secondspassed
		scorePerOwnedUnit				= 1,	-- thisvalue*countofunits
		-----------------------------------------
		baseScorePerKill 				= 1, -- How much score EVERY KILL and CAPTURE adds
			-- Additional score for specific unit types, use -baseScorePerKill(default 1) to make it have no effect on score, use values lower than baseScorePerKill to reduce score
			scorePerKilledBuilding 			= 9,
			scorePerKilledConstructor 		= 49,
			scorePerKilledSpawner 			= 99,
			scorePerCapturedSpawner 		= 50, -- this doesn't care about baseScorePerKill
	},
	gracePeriod = ScavGracePeriodModoption*30*60,
	timers = {
		-- globalScore values
		T0start								= 1,
		T1start								= 750 * ScavTechCurveModoption,
		T1low								= 1125 * ScavTechCurveModoption,
		T1med								= 1500 * ScavTechCurveModoption,
		T1high								= 1875 * ScavTechCurveModoption,
		T1top								= 2250 * ScavTechCurveModoption,
		T2start								= 2815 * ScavTechCurveModoption,
		T2low								= 3750 * ScavTechCurveModoption,
		T2med								= 4685 * ScavTechCurveModoption,
		T2high								= 5625 * ScavTechCurveModoption,
		T2top								= 7500 * ScavTechCurveModoption,
		T3start								= 9375 * ScavTechCurveModoption,
		T3low								= 11250 * ScavTechCurveModoption,
		T3med								= 13125 * ScavTechCurveModoption,
		T3high								= 15000 * ScavTechCurveModoption,
		T3top								= 16875 * ScavTechCurveModoption,
		T4start								= 18750 * ScavTechCurveModoption,
		T4low								= 22500 * ScavTechCurveModoption,
		T4med								= 26250 * ScavTechCurveModoption,
		T4high								= 30000 * ScavTechCurveModoption,
		T4top								= 35000 * ScavTechCurveModoption,
		BossFight							= 40000 * ScavTechCurveModoption,
		Endless								= 40001 * ScavTechCurveModoption,
		-- don't delete
		NoRadar								= 2815 * ScavTechCurveModoption,
	},
	other = {
		heighttolerance						= 40, -- higher = allow higher height diffrences
		noheightchecksforwater				= true,

	}
}


-- Modules configs
buildingSpawnerModuleConfig = {
	spawnchance 						= 90,
}

unitSpawnerModuleConfig = {
	bossFightEnabled					= not endlessModeEnabled,
	FinalBossUnit						= true,
		FinalBossHealth						= 1000000*ScavBossHealthModoption, -- this*teamcount*difficulty
		FinalBossMinionsPassive				= 3000, -- this/(teamcount*difficulty), how often does boss spawn minions passively, frames.
		FinalBossMinionsActive				= 150, -- this/(teamcount*difficulty), how often does boss spawn minions when taking damage, frames.
	BossWaveTimeLeft					= 300,
	aircraftchance 						= 6, -- higher number = lower chance
	globalscoreperoneunit 				= 3000/ScavUnitCountModoption,
	spawnchance							= 120/ScavUnitSpawnFrequencyModoption,
	beaconspawnchance					= 480,
	beacondefences						= true,
	minimumspawnbeacons					= math.ceil(teamcount*4*spawnmultiplier),
	landmultiplier 						= 0.75,
	airmultiplier 						= 2,
	seamultiplier 						= 0.75,
	chanceforaircraftonsea				= 4, -- higher number = lower chance

	t0multiplier						= 3.5,
	t1multiplier						= 5,
	t2multiplier						= 1,
	t3multiplier						= 0.20,
	t4multiplier						= 0.015,

	initialbonuscommander				= initialBonusCommanderEnabled,
}

constructorControllerModuleConfig = {
	constructortimerstart				= 600, -- ammount of seconds it skips from constructortimer for the first spawn (make first spawn earlier - this timer starts on timer-Timer1)
	constructortimer 					= 600, -- time in seconds between commander/constructor spawns
	constructortimerreductionframes		= 36000, -- increase frequency of commander spawns every this many frames
	minimumconstructors					= math.ceil(teamcount*4*spawnmultiplier),
	useresurrectors						= true,
	searesurrectors						= true,
	useconstructors						= true,
	usecollectors						= true,
}

unitControllerModuleConfig = {
	minimumrangeforfight				= 650,
	veterancymultiplier					= ScavUnitVeterancyModoption,
}

spawnProtectionConfig = {
	useunit				= false, -- use starbox otherwise
	spread				= 100,
}

randomEventsConfig = {
	randomEventMinimumDelay = 9000*scavRandomEventsAmountModoption, -- frames
	randomEventChance = 200*scavRandomEventsAmountModoption, -- higher = lower chance

}



-- Functions which you can configure
function SpawnBonusCommander(unitID, unitName, unitTeam)
	if unitName == "armcom" or unitName == "corcom" then
		local posx, posy, posz = Spring.GetUnitPosition(unitID)
		-- Spring.CreateUnit("scavengerdroppodfriendly", posx-32, posy+48, posz, math_random(0,3), unitTeam)
		-- Spring.CreateUnit("scavengerdroppodfriendly", posx+32, posy+48, posz, math_random(0,3), unitTeam)
		-- Spring.CreateUnit("scavengerdroppodfriendly", posx, posy+48, posz+32, math_random(0,3), unitTeam)
		-- Spring.CreateUnit("scavengerdroppodfriendly", posx, posy+48, posz-32, math_random(0,3), unitTeam)
			--Spring.SetUnitPosition(unitID, posx-32, posz)
		if unitName == "armcom" then
			local a = Spring.CreateUnit("armassistdrone", posx-32, posy+48, posz,  	 0, unitTeam)
			local b = Spring.CreateUnit("armassistdrone", posx+32, posy+48, posz,  	 0, unitTeam)
			local c = Spring.CreateUnit("armassistdrone", posx,    posy+48, posz+32, 0, unitTeam)
			local d = Spring.CreateUnit("armassistdrone", posx,    posy+48, posz-32, 0, unitTeam)
			Spring.GiveOrderToUnit(a, CMD.GUARD, unitID, {})
			Spring.GiveOrderToUnit(b, CMD.GUARD, unitID, {})
			Spring.GiveOrderToUnit(c, CMD.GUARD, unitID, {})
			Spring.GiveOrderToUnit(d, CMD.GUARD, unitID, {})
		elseif unitName == "corcom" then
			local a = Spring.CreateUnit("corassistdrone", posx-32, posy+48, posz,  	 0, unitTeam)
			local b = Spring.CreateUnit("corassistdrone", posx+32, posy+48, posz,  	 0, unitTeam)
			local c = Spring.CreateUnit("corassistdrone", posx,    posy+48, posz+32, 0, unitTeam)
			local d = Spring.CreateUnit("corassistdrone", posx,    posy+48, posz-32, 0, unitTeam)
			Spring.GiveOrderToUnit(a, CMD.GUARD, unitID, {})
			Spring.GiveOrderToUnit(b, CMD.GUARD, unitID, {})
			Spring.GiveOrderToUnit(c, CMD.GUARD, unitID, {})
			Spring.GiveOrderToUnit(d, CMD.GUARD, unitID, {})
		end
	end
end

function UpdateTierChances(n)
	-- Must be 100 in total
	if globalScore > scavconfig.timers.Endless then
		TierSpawnChances.T0 = 0
		TierSpawnChances.T1 = 0
		TierSpawnChances.T2 = 33
		TierSpawnChances.T3 = 33
		TierSpawnChances.T4 = 34
		TierSpawnChances.Message = "Current tier: Endless"
		TierSpawnChances.BPMult = 5
	elseif globalScore > scavconfig.timers.T4top then
		TierSpawnChances.T0 = 0
		TierSpawnChances.T1 = 0
		TierSpawnChances.T2 = 10
		TierSpawnChances.T3 = 40
		TierSpawnChances.T4 = 50
		TierSpawnChances.Message = "Current tier: T4 Top"
		TierSpawnChances.BPMult = 4.8
	elseif globalScore > scavconfig.timers.T4high then
		TierSpawnChances.T0 = 0
		TierSpawnChances.T1 = 0
		TierSpawnChances.T2 = 10
		TierSpawnChances.T3 = 50
		TierSpawnChances.T4 = 40
		TierSpawnChances.Message = "Current tier: T4 High"
		TierSpawnChances.BPMult = 4.6
	elseif globalScore > scavconfig.timers.T4med then
		TierSpawnChances.T0 = 0
		TierSpawnChances.T1 = 0
		TierSpawnChances.T2 = 20
		TierSpawnChances.T3 = 50
		TierSpawnChances.T4 = 30
		TierSpawnChances.Message = "Current tier: T4 Medium"
		TierSpawnChances.BPMult = 4.4
	elseif globalScore > scavconfig.timers.T4low then
		TierSpawnChances.T0 = 0
		TierSpawnChances.T1 = 0
		TierSpawnChances.T2 = 30
		TierSpawnChances.T3 = 50
		TierSpawnChances.T4 = 20
		TierSpawnChances.Message = "Current tier: T4 Low"
		TierSpawnChances.BPMult = 4.2
	elseif globalScore > scavconfig.timers.T4start then
		TierSpawnChances.T0 = 0
		TierSpawnChances.T1 = 0
		TierSpawnChances.T2 = 40
		TierSpawnChances.T3 = 50
		TierSpawnChances.T4 = 10
		TierSpawnChances.Message = "Current tier: T4 Start"
		TierSpawnChances.BPMult = 4
	elseif globalScore > scavconfig.timers.T3top then
		TierSpawnChances.T0 = 0
		TierSpawnChances.T1 = 10
		TierSpawnChances.T2 = 40
		TierSpawnChances.T3 = 50
		TierSpawnChances.T4 = 0
		TierSpawnChances.Message = "Current tier: T3 Top"
		TierSpawnChances.BPMult = 3.8
	elseif globalScore > scavconfig.timers.T3high then
		TierSpawnChances.T0 = 0
		TierSpawnChances.T1 = 10
		TierSpawnChances.T2 = 50
		TierSpawnChances.T3 = 40
		TierSpawnChances.T4 = 0
		TierSpawnChances.Message = "Current tier: T3 High"
		TierSpawnChances.BPMult = 3.6
	elseif globalScore > scavconfig.timers.T3med then
		TierSpawnChances.T0 = 0
		TierSpawnChances.T1 = 20
		TierSpawnChances.T2 = 50
		TierSpawnChances.T3 = 30
		TierSpawnChances.T4 = 0
		TierSpawnChances.Message = "Current tier: T3 Medium"
		TierSpawnChances.BPMult = 3.4
	elseif globalScore > scavconfig.timers.T3low then
		TierSpawnChances.T0 = 0
		TierSpawnChances.T1 = 30
		TierSpawnChances.T2 = 50
		TierSpawnChances.T3 = 20
		TierSpawnChances.T4 = 0
		TierSpawnChances.Message = "Current tier: T3 Low"
		TierSpawnChances.BPMult = 3.2
	elseif globalScore > scavconfig.timers.T3start then
		TierSpawnChances.T0 = 0
		TierSpawnChances.T1 = 40
		TierSpawnChances.T2 = 50
		TierSpawnChances.T3 = 10
		TierSpawnChances.T4 = 0
		TierSpawnChances.Message = "Current tier: T3 Start"
		TierSpawnChances.BPMult = 3
	elseif globalScore > scavconfig.timers.T2top then
		TierSpawnChances.T0 = 10
		TierSpawnChances.T1 = 40
		TierSpawnChances.T2 = 50
		TierSpawnChances.T3 = 0
		TierSpawnChances.T4 = 0
		TierSpawnChances.Message = "Current tier: T2 Top"
		TierSpawnChances.BPMult = 2.8
	elseif globalScore > scavconfig.timers.T2high then
		TierSpawnChances.T0 = 10
		TierSpawnChances.T1 = 50
		TierSpawnChances.T2 = 40
		TierSpawnChances.T3 = 0
		TierSpawnChances.T4 = 0
		TierSpawnChances.Message = "Current tier: T2 High"
		TierSpawnChances.BPMult = 2.6
	elseif globalScore > scavconfig.timers.T2med then
		TierSpawnChances.T0 = 20
		TierSpawnChances.T1 = 50
		TierSpawnChances.T2 = 30
		TierSpawnChances.T3 = 0
		TierSpawnChances.T4 = 0
		TierSpawnChances.Message = "Current tier: T2 Medium"
		TierSpawnChances.BPMult = 2.4
	elseif globalScore > scavconfig.timers.T2low then
		TierSpawnChances.T0 = 30
		TierSpawnChances.T1 = 50
		TierSpawnChances.T2 = 20
		TierSpawnChances.T3 = 0
		TierSpawnChances.T4 = 0
		TierSpawnChances.Message = "Current tier: T2 Low"
		TierSpawnChances.BPMult = 2.2
	elseif globalScore > scavconfig.timers.T2start then
		TierSpawnChances.T0 = 40
		TierSpawnChances.T1 = 50
		TierSpawnChances.T2 = 10
		TierSpawnChances.T3 = 0
		TierSpawnChances.T4 = 0
		TierSpawnChances.Message = "Current tier: T2 Start"
		TierSpawnChances.BPMult = 2
	elseif globalScore > scavconfig.timers.T1top then
		TierSpawnChances.T0 = 50
		TierSpawnChances.T1 = 50
		TierSpawnChances.T2 = 0
		TierSpawnChances.T3 = 0
		TierSpawnChances.T4 = 0
		TierSpawnChances.Message = "Current tier: T1 Top"
		TierSpawnChances.BPMult = 1.8
	elseif globalScore > scavconfig.timers.T1high then
		TierSpawnChances.T0 = 60
		TierSpawnChances.T1 = 40
		TierSpawnChances.T2 = 0
		TierSpawnChances.T3 = 0
		TierSpawnChances.T4 = 0
		TierSpawnChances.Message = "Current tier: T1 High"
		TierSpawnChances.BPMult = 1.6
	elseif globalScore > scavconfig.timers.T1med then
		TierSpawnChances.T0 = 70
		TierSpawnChances.T1 = 30
		TierSpawnChances.T2 = 0
		TierSpawnChances.T3 = 0
		TierSpawnChances.T4 = 0
		TierSpawnChances.Message = "Current tier: T1 Medium"
		TierSpawnChances.BPMult = 1.4
	elseif globalScore > scavconfig.timers.T1low then
		TierSpawnChances.T0 = 80
		TierSpawnChances.T1 = 20
		TierSpawnChances.T2 = 0
		TierSpawnChances.T3 = 0
		TierSpawnChances.T4 = 0
		TierSpawnChances.Message = "Current tier: T1 Low"
		TierSpawnChances.BPMult = 1.2
	elseif globalScore > scavconfig.timers.T1start then
		TierSpawnChances.T0 = 90
		TierSpawnChances.T1 = 10
		TierSpawnChances.T2 = 0
		TierSpawnChances.T3 = 0
		TierSpawnChances.T4 = 0
		TierSpawnChances.Message = "Current tier: T1 Start"
		TierSpawnChances.BPMult = 1
	else
		TierSpawnChances.T0 = 100
		TierSpawnChances.T1 = 0
		TierSpawnChances.T2 = 0
		TierSpawnChances.T3 = 0
		TierSpawnChances.T4 = 0
		TierSpawnChances.Message = "Current tier: T0"
		TierSpawnChances.BPMult = 0.5
	end
end


local UDN = UnitDefNames
function BPWallOrPopup(faction)
	local r = math.random(0,5)
	if faction == "arm" then
		if r == 0 then
			return UDN.armclaw_scav.id
		else
			return UDN.armdrag_scav.id
		end
	elseif faction == "cor" then
		if r == 0 then
			return UDN.cormaw_scav.id
		else
			return UDN.cordrag_scav.id
		end
	elseif faction == "scav" then
		if r == 0 then
			local r2 = math.random(1,3)
			if r2 == 1 then
				return UDN.corscavdtf_scav.id
			elseif r2 == 2 then
				return UDN.corscavdtl_scav.id
			elseif r2 == 3 then
				return UDN.corscavdtm_scav.id
			end
		else
			return UDN.corscavdrag_scav.id
		end
	end
end

-----------------------------------------------------------
-----------------------------------------------------------
local tiers = {
	T0 = 0,
	T1 = 1,
	T2 = 2,
	T3 = 3,
	T4 = 4,
}

local blueprintTypes = {
	Land = 1,
	Sea = 2,
}

return {
	Tiers = tiers,
	BlueprintTypes = blueprintTypes,
}
