Spring.Echo("[Scavengers] Config initialized")

-- Config for Scavengers Survival AI
if scavengersAIEnabled then
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
			reinforcementsModule			= false,
			stockpilers						= true,
			nukes							= true,
		},
		timers = {
			-- globalScore values
			T0start								= 1,
			T1start								= 600,
			T1low								= 900,
			T1med								= 1200,
			T1high								= 1500,
			T1top								= 1800,
			T2start								= 2250,
			T2low								= 3000,
			T2med								= 3750,
			T2high								= 4500,
			T2top								= 6000,
			T3start								= 7500,
			T3low								= 9000,
			T3med								= 10500,
			T3high								= 12000,
			T3top								= 13500,
			T4start								= 15000,
			T4low								= 18000,
			T4med								= 21000,
			T4high								= 24000,
			T4top								= 28000,
			BossFight							= 28001,
			-- don't delete
			NoRadar								= 1200,
		},
		other = {
			heighttolerance						= 30, -- higher = allow higher height diffrences
			noheightchecksforwater				= true,
		}
	}


	-- Modules configs
	buildingSpawnerModuleConfig = {
		spawnchance 						= 90,
	}

	unitSpawnerModuleConfig = {
		bossFightEnabled					= true,
		BossWaveTimeLeft					= 900,
		aircraftchance 						= 20, -- higher number = lower chance
		globalscoreperoneunit 				= 900,
		spawnchance							= 120,
		beaconspawnchance					= 120,
		minimumspawnbeacons					= 2,
		landmultiplier 						= 0.75,
		airmultiplier 						= 2,
		seamultiplier 						= 0.2,
		chanceforaircraftonsea				= 2, -- higher number = lower chance

		t0multiplier						= 3,
		t1multiplier						= 2.5,
		t2multiplier						= 0.8,
		t3multiplier						= 0.1,
		t4multiplier						= 0.05,
	}

	constructorControllerModuleConfig = {
		constructortimerstart				= 120, -- ammount of seconds it skips from constructortimer for the first spawn (make first spawn earlier - this timer starts on timer-Timer1)
		constructortimer 					= 220, -- time in seconds between commander/constructor spawns
		constructortimerreductionframes		= 36000,
		minimumconstructors					= 5,
		useresurrectors						= true,
			searesurrectors					= false,
		useconstructors						= true,
		usecollectors						= true,
	}

	unitControllerModuleConfig = {
		minimumrangeforfight				= 650,
	}

	spawnProtectionConfig = {
		spread				= 192,
	}



	-- Functions which you can configure
	function CountScavConstructors()
		return UDC(GaiaTeamID, UDN.corcom_scav.id) + UDC(GaiaTeamID, UDN.armcom_scav.id)
	end

	function UpdateTierChances(n)
		-- Must be 100 in total
		if globalScore > scavconfig.timers.T4top then
			TierSpawnChances.T0 = 0
			TierSpawnChances.T1 = 0
			TierSpawnChances.T2 = 10
			TierSpawnChances.T3 = 30
			TierSpawnChances.T4 = 60
		elseif globalScore > scavconfig.timers.T4high then
			TierSpawnChances.T0 = 0
			TierSpawnChances.T1 = 0
			TierSpawnChances.T2 = 20
			TierSpawnChances.T3 = 50
			TierSpawnChances.T4 = 30
		elseif globalScore > scavconfig.timers.T4med then
			TierSpawnChances.T0 = 0
			TierSpawnChances.T1 = 0
			TierSpawnChances.T2 = 30
			TierSpawnChances.T3 = 50
			TierSpawnChances.T4 = 20
		elseif globalScore > scavconfig.timers.T4low then
			TierSpawnChances.T0 = 0
			TierSpawnChances.T1 = 0
			TierSpawnChances.T2 = 40
			TierSpawnChances.T3 = 50
			TierSpawnChances.T4 = 10
		elseif globalScore > scavconfig.timers.T4start then
			TierSpawnChances.T0 = 0
			TierSpawnChances.T1 = 0
			TierSpawnChances.T2 = 40
			TierSpawnChances.T3 = 55
			TierSpawnChances.T4 = 5
		elseif globalScore > scavconfig.timers.T3top then
			TierSpawnChances.T0 = 0
			TierSpawnChances.T1 = 10
			TierSpawnChances.T2 = 20
			TierSpawnChances.T3 = 70
			TierSpawnChances.T4 = 0
		elseif globalScore > scavconfig.timers.T3high then
			TierSpawnChances.T0 = 0
			TierSpawnChances.T1 = 10
			TierSpawnChances.T2 = 50
			TierSpawnChances.T3 = 40
			TierSpawnChances.T4 = 0
		elseif globalScore > scavconfig.timers.T3med then
			TierSpawnChances.T0 = 0
			TierSpawnChances.T1 = 10
			TierSpawnChances.T2 = 60
			TierSpawnChances.T3 = 30
			TierSpawnChances.T4 = 0
		elseif globalScore > scavconfig.timers.T3low then
			TierSpawnChances.T0 = 0
			TierSpawnChances.T1 = 10
			TierSpawnChances.T2 = 65
			TierSpawnChances.T3 = 25
			TierSpawnChances.T4 = 0
		elseif globalScore > scavconfig.timers.T3start then
			TierSpawnChances.T0 = 0
			TierSpawnChances.T1 = 10
			TierSpawnChances.T2 = 70
			TierSpawnChances.T3 = 10
			TierSpawnChances.T4 = 0
		elseif globalScore > scavconfig.timers.T2top then
			TierSpawnChances.T0 = 10
			TierSpawnChances.T1 = 10
			TierSpawnChances.T2 = 80
			TierSpawnChances.T3 = 0
			TierSpawnChances.T4 = 0
		elseif globalScore > scavconfig.timers.T2high then
			TierSpawnChances.T0 = 10
			TierSpawnChances.T1 = 30
			TierSpawnChances.T2 = 60
			TierSpawnChances.T3 = 0
			TierSpawnChances.T4 = 0
		elseif globalScore > scavconfig.timers.T2med then
			TierSpawnChances.T0 = 10
			TierSpawnChances.T1 = 40
			TierSpawnChances.T2 = 50
			TierSpawnChances.T3 = 0
			TierSpawnChances.T4 = 0
		elseif globalScore > scavconfig.timers.T2low then
			TierSpawnChances.T0 = 10
			TierSpawnChances.T1 = 60
			TierSpawnChances.T2 = 30
			TierSpawnChances.T3 = 0
			TierSpawnChances.T4 = 0
		elseif globalScore > scavconfig.timers.T2start then
			TierSpawnChances.T0 = 10
			TierSpawnChances.T1 = 70
			TierSpawnChances.T2 = 20
			TierSpawnChances.T3 = 0
			TierSpawnChances.T4 = 0
		elseif globalScore > scavconfig.timers.T1top then
			TierSpawnChances.T0 = 10
			TierSpawnChances.T1 = 90
			TierSpawnChances.T2 = 0
			TierSpawnChances.T3 = 0
			TierSpawnChances.T4 = 0
		elseif globalScore > scavconfig.timers.T1high then
			TierSpawnChances.T0 = 40
			TierSpawnChances.T1 = 60
			TierSpawnChances.T2 = 0
			TierSpawnChances.T3 = 0
			TierSpawnChances.T4 = 0
		elseif globalScore > scavconfig.timers.T1med then
			TierSpawnChances.T0 = 60
			TierSpawnChances.T1 = 40
			TierSpawnChances.T2 = 0
			TierSpawnChances.T3 = 0
			TierSpawnChances.T4 = 0
		elseif globalScore > scavconfig.timers.T1low then
			TierSpawnChances.T0 = 80
			TierSpawnChances.T1 = 20
			TierSpawnChances.T2 = 0
			TierSpawnChances.T3 = 0
			TierSpawnChances.T4 = 0
		elseif globalScore > scavconfig.timers.T1start then
			TierSpawnChances.T0 = 90
			TierSpawnChances.T1 = 10
			TierSpawnChances.T2 = 0
			TierSpawnChances.T3 = 0
			TierSpawnChances.T4 = 0
		else
			TierSpawnChances.T0 = 100
			TierSpawnChances.T1 = 0
			TierSpawnChances.T2 = 0
			TierSpawnChances.T3 = 0
			TierSpawnChances.T4 = 0
		end
	end











-- Config for PvP (Gaia) Scavengers
else
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
			startBoxProtection				= false,
			reinforcementsModule			= false,
			stockpilers						= true,
			nukes							= true,
		},
		timers = {
			-- globalScore values
			T0start								= 1,
			T1start								= 600,
			T1low								= 900,
			T1med								= 1200,
			T1high								= 1500,
			T1top								= 1800,
			T2start								= 2250,
			T2low								= 3000,
			T2med								= 3750,
			T2high								= 4500,
			T2top								= 6000,
			T3start								= 7500,
			T3low								= 9000,
			T3med								= 10500,
			T3high								= 12000,
			T3top								= 13500,
			T4start								= 15000,
			T4low								= 18000,
			T4med								= 21000,
			T4high								= 24000,
			T4top								= 28000,
			BossFight							= 28001,
			-- don't delete
			NoRadar								= 1200,
		},
		other = {
			heighttolerance						= 30, -- higher = allow higher height diffrences
			noheightchecksforwater				= true,
		}
	}


	-- Modules configs
	buildingSpawnerModuleConfig = {
		spawnchance 						= 90,
	}

	unitSpawnerModuleConfig = {
		bossFightEnabled					= false,
		BossWaveTimeLeft					= 900,
		aircraftchance 						= 5, -- higher number = lower chance
		globalscoreperoneunit 				= 800,
		spawnchance							= 120,
		beaconspawnchance					= 360,
		minimumspawnbeacons					= 2,
		landmultiplier 						= 0.75,
		airmultiplier 						= 1.5,
		seamultiplier 						= 0.2,
		chanceforaircraftonsea				= 2, -- higher number = lower chance

		t0multiplier						= 1.5,
		t1multiplier						= 1.0,
		t2multiplier						= 0.3,
		t3multiplier						= 0.05,
		t4multiplier						= 0.01,
	}

	constructorControllerModuleConfig = {
		constructortimerstart				= 120, -- ammount of seconds it skips from constructortimer for the first spawn (make first spawn earlier - this timer starts on timer-Timer1)
		constructortimer 					= 220, -- time in seconds between commander/constructor spawns
		constructortimerreductionframes		= 36000,
		minimumconstructors					= 1,
		useresurrectors						= true,
			searesurrectors					= false,
		useconstructors						= true,
		usecollectors						= true,

	}

	unitControllerModuleConfig = {
		minimumrangeforfight				= 650,
	}

	spawnProtectionConfig = {
		spread				= 128,
	}


	-- Functions which you can configure
	function CountScavConstructors()
		return UDC(GaiaTeamID, UDN.corcom_scav.id) + UDC(GaiaTeamID, UDN.armcom_scav.id)
	end

	function UpdateTierChances(n)
		-- Must be 100 in total

		if globalScore > scavconfig.timers.T4top then
			TierSpawnChances.T0 = 0
			TierSpawnChances.T1 = 0
			TierSpawnChances.T2 = 10
			TierSpawnChances.T3 = 30
			TierSpawnChances.T4 = 60
		elseif globalScore > scavconfig.timers.T4high then
			TierSpawnChances.T0 = 0
			TierSpawnChances.T1 = 0
			TierSpawnChances.T2 = 20
			TierSpawnChances.T3 = 50
			TierSpawnChances.T4 = 30
		elseif globalScore > scavconfig.timers.T4med then
			TierSpawnChances.T0 = 0
			TierSpawnChances.T1 = 0
			TierSpawnChances.T2 = 30
			TierSpawnChances.T3 = 50
			TierSpawnChances.T4 = 20
		elseif globalScore > scavconfig.timers.T4low then
			TierSpawnChances.T0 = 0
			TierSpawnChances.T1 = 0
			TierSpawnChances.T2 = 40
			TierSpawnChances.T3 = 50
			TierSpawnChances.T4 = 10
		elseif globalScore > scavconfig.timers.T4start then
			TierSpawnChances.T0 = 0
			TierSpawnChances.T1 = 0
			TierSpawnChances.T2 = 40
			TierSpawnChances.T3 = 55
			TierSpawnChances.T4 = 5
		elseif globalScore > scavconfig.timers.T3top then
			TierSpawnChances.T0 = 0
			TierSpawnChances.T1 = 10
			TierSpawnChances.T2 = 20
			TierSpawnChances.T3 = 70
			TierSpawnChances.T4 = 0
		elseif globalScore > scavconfig.timers.T3high then
			TierSpawnChances.T0 = 0
			TierSpawnChances.T1 = 10
			TierSpawnChances.T2 = 50
			TierSpawnChances.T3 = 40
			TierSpawnChances.T4 = 0
		elseif globalScore > scavconfig.timers.T3med then
			TierSpawnChances.T0 = 0
			TierSpawnChances.T1 = 10
			TierSpawnChances.T2 = 60
			TierSpawnChances.T3 = 30
			TierSpawnChances.T4 = 0
		elseif globalScore > scavconfig.timers.T3low then
			TierSpawnChances.T0 = 0
			TierSpawnChances.T1 = 10
			TierSpawnChances.T2 = 65
			TierSpawnChances.T3 = 25
			TierSpawnChances.T4 = 0
		elseif globalScore > scavconfig.timers.T3start then
			TierSpawnChances.T0 = 0
			TierSpawnChances.T1 = 10
			TierSpawnChances.T2 = 70
			TierSpawnChances.T3 = 20
			TierSpawnChances.T4 = 0
		elseif globalScore > scavconfig.timers.T2top then
			TierSpawnChances.T0 = 10
			TierSpawnChances.T1 = 10
			TierSpawnChances.T2 = 80
			TierSpawnChances.T3 = 0
			TierSpawnChances.T4 = 0
		elseif globalScore > scavconfig.timers.T2high then
			TierSpawnChances.T0 = 10
			TierSpawnChances.T1 = 30
			TierSpawnChances.T2 = 60
			TierSpawnChances.T3 = 0
			TierSpawnChances.T4 = 0
		elseif globalScore > scavconfig.timers.T2med then
			TierSpawnChances.T0 = 10
			TierSpawnChances.T1 = 40
			TierSpawnChances.T2 = 50
			TierSpawnChances.T3 = 0
			TierSpawnChances.T4 = 0
		elseif globalScore > scavconfig.timers.T2low then
			TierSpawnChances.T0 = 10
			TierSpawnChances.T1 = 60
			TierSpawnChances.T2 = 30
			TierSpawnChances.T3 = 0
			TierSpawnChances.T4 = 0
		elseif globalScore > scavconfig.timers.T2start then
			TierSpawnChances.T0 = 10
			TierSpawnChances.T1 = 70
			TierSpawnChances.T2 = 20
			TierSpawnChances.T3 = 0
			TierSpawnChances.T4 = 0
		elseif globalScore > scavconfig.timers.T1top then
			TierSpawnChances.T0 = 10
			TierSpawnChances.T1 = 90
			TierSpawnChances.T2 = 0
			TierSpawnChances.T3 = 0
			TierSpawnChances.T4 = 0
		elseif globalScore > scavconfig.timers.T1high then
			TierSpawnChances.T0 = 40
			TierSpawnChances.T1 = 60
			TierSpawnChances.T2 = 0
			TierSpawnChances.T3 = 0
			TierSpawnChances.T4 = 0
		elseif globalScore > scavconfig.timers.T1med then
			TierSpawnChances.T0 = 60
			TierSpawnChances.T1 = 40
			TierSpawnChances.T2 = 0
			TierSpawnChances.T3 = 0
			TierSpawnChances.T4 = 0
		elseif globalScore > scavconfig.timers.T1low then
			TierSpawnChances.T0 = 80
			TierSpawnChances.T1 = 20
			TierSpawnChances.T2 = 0
			TierSpawnChances.T3 = 0
			TierSpawnChances.T4 = 0
		elseif globalScore > scavconfig.timers.T1start then
			TierSpawnChances.T0 = 90
			TierSpawnChances.T1 = 10
			TierSpawnChances.T2 = 0
			TierSpawnChances.T3 = 0
			TierSpawnChances.T4 = 0
		else
			TierSpawnChances.T0 = 100
			TierSpawnChances.T1 = 0
			TierSpawnChances.T2 = 0
			TierSpawnChances.T3 = 0
			TierSpawnChances.T4 = 0
		end
	end
end
