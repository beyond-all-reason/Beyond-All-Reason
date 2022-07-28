-- nil fixes
if not teamcount then teamcount = 1 end


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
		spawnmultiplier = 0.25
		scavStatsDifficulty = "Very Easy"
	elseif scavDifficulty == "easy" then
		spawnmultiplier = 0.375
		scavStatsDifficulty = "Easy"
	elseif scavDifficulty == "medium" then
		spawnmultiplier = 0.5
		scavStatsDifficulty = "Medium"
	elseif scavDifficulty == "hard" then
		spawnmultiplier = 0.875
		scavStatsDifficulty = "Hard"
	elseif scavDifficulty == "veryhard" then
		spawnmultiplier = 1
		scavStatsDifficulty = "Very Hard"
	elseif scavDifficulty == "expert" then
		spawnmultiplier = 1.5
		scavStatsDifficulty = "Expert"
	elseif scavDifficulty == "brutal" then
		spawnmultiplier = 2
		scavStatsDifficulty = "Brutal"
	else
		spawnmultiplier = 0.25
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

	local constructorsEnabled = Spring.GetModOptions().scavconstructors
	if constructorsEnabled == false then
		ScavUnitSpawnFrequencyModoption = ScavUnitSpawnFrequencyModoption*2
	end

	local startboxCloudEnabled = Spring.GetModOptions().scavstartboxcloud
	local scavMaxTechLevel = Spring.GetModOptions().scavmaxtechlevel
	local scavMaxTechLevelNumber = 4
	if scavMaxTechLevel == "tech4" then
		scavMaxTechLevelNumber = 4
	elseif scavMaxTechLevel == "tech3" then
		scavMaxTechLevelNumber = 3
	elseif scavMaxTechLevel == "tech2" then
		scavMaxTechLevelNumber = 2
	elseif scavMaxTechLevel == "tech1" then
		scavMaxTechLevelNumber = 1
	end
-- End of Modoptions


local scavconfig = {
	difficulty = scavDifficulty,
	difficultyName = scavStatsDifficulty,
	maxTechLevel = scavMaxTechLevelNumber,
	unitnamesuffix = "_scav",
	messenger = true, -- BYAR specific thing, don't enable otherwise (or get gui_messages.lua from BYAR)
	modules = {
		buildingSpawnerModule 			= false,
		constructorControllerModule 	= constructorsEnabled,
		factoryControllerModule 		= true,
		unitSpawnerModule 				= true,
		startBoxProtection				= startboxCloudEnabled,
		reinforcementsModule			= true, --disabled for now for weird victory conditions and too much hp
		randomEventsModule				= randomEventsEnabled,
		stockpilers						= true,
		nukes							= true,
	},

	scoreConfig = {
		-- set to 0 to disable
		scorePerMetal 					= 2.5, 	-- thisvalue*metalproduction
		scorePerEnergy 					= 0.25,	-- thisvalue*energyproduction
		scorePerSecond 					= 5.5,	-- thisvalue*secondspassed
		scorePerOwnedUnit				= 1,	-- thisvalue*countofunits
		-----------------------------------------
		baseScorePerKill 				= 1, -- How much score EVERY KILL and CAPTURE adds
			-- Additional score for specific unit types, use -baseScorePerKill(default 1) to make it have no effect on score, use values lower than baseScorePerKill to reduce score
			scorePerKilledBuilding 			= 19,
			scorePerKilledConstructor 		= 199,
			scorePerKilledSpawner 			= 199,
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
		Endless1							= 40001 * ScavTechCurveModoption,
		Endless2							= 50000 * ScavTechCurveModoption,
		Endless3							= 60000 * ScavTechCurveModoption,
		Endless4							= 70000 * ScavTechCurveModoption,
		Endless5							= 80000 * ScavTechCurveModoption,
		Endless6							= 90000 * ScavTechCurveModoption,
		Endless7							= 100000 * ScavTechCurveModoption,
		Endless8							= 110000 * ScavTechCurveModoption,
		Endless9							= 120000 * ScavTechCurveModoption,
		-- don't delete
		NoRadar								= 2815 * ScavTechCurveModoption,
	},
	other = {
		heighttolerance						= 40, -- higher = allow higher height diffrences
		noheightchecksforwater				= true,

	},
	buildingSpawnerModuleConfig = {
		spawnchance 						= 90,
	},
	unitSpawnerModuleConfig = {
		bossFightEnabled					= not endlessModeEnabled,
		FinalBossUnit						= Spring.GetModOptions().scavbosstoggle,
			FinalBossHealth						= 1000000*ScavBossHealthModoption, -- this*teamcount*difficulty
			FinalBossMinionsPassive				= 36000, -- this/(teamcount*difficulty), how often does boss spawn minions passively, frames.
			FinalBossMinionsActive				= 10800, -- this/(teamcount*difficulty), how often does boss spawn minions when taking damage, frames.
		BossWaveTimeLeft					= 300,
		aircraftchance 						= 10, -- higher number = lower chance
		globalscoreperoneunit 				= 1600/ScavUnitCountModoption,
		spawnchance							= 100/ScavUnitSpawnFrequencyModoption,
		beaconspawnchance					= 900,
		beacondefences						= true,
		minimumspawnbeacons					= math.ceil(teamcount*spawnmultiplier)*3,
		landmultiplier 						= 0.75,
		airmultiplier 						= 1,
		seamultiplier 						= 0.75,
		chanceforaircraftonsea				= 4, -- higher number = lower chance
	
		t0multiplier						= 6,
		t1multiplier						= 5,
		t2multiplier						= 2.5,
		t3multiplier						= 0.30,
		t4multiplier						= 0.010,
	
		initialbonuscommander				= initialBonusCommanderEnabled,
	},
	constructorControllerModuleConfig = {
		constructortimerstart				= 600, -- ammount of seconds it skips from constructortimer for the first spawn (make first spawn earlier - this timer starts on timer-Timer1)
		constructortimer 					= 600, -- time in seconds between commander/constructor spawns
		constructortimerreductionframes		= 36000, -- increase frequency of commander spawns every this many frames
		minimumconstructors					= math.ceil(teamcount*3*spawnmultiplier),
		useresurrectors						= true,
		searesurrectors						= true,
		useconstructors						= true,
		usecollectors						= true,
		usecapturers						= true,
	},
	unitControllerModuleConfig = {
		minimumrangeforfight				= 650,
		veterancymultiplier					= ScavUnitVeterancyModoption,
	},
	spawnProtectionConfig = {
		useunit				= false, -- use starbox otherwise -- currently unavailable
		useturrets 			= false, -- Spawn turrets around the cloud
		spread				= 64,
	},
	randomEventsConfig = {
		randomEventMinimumDelay = 4500*scavRandomEventsAmountModoption, -- frames
		randomEventChance = 200*scavRandomEventsAmountModoption, -- higher = lower chance
	},
}

return scavconfig
