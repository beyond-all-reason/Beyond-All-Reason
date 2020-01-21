Spring.Echo("[Scavengers] Config initialized")

scavconfig = {
	unitnamesuffix = "_scav",
	modules = {
		buildingSpawnerModule 			= false,
		constructorControllerModule 	= true,
		factoryControllerModule 		= true,
		unitSpawnerModule 				= true,
	},
	timers = {
		-- (30 = 1 second)
		-- Timer0							= 9000, -- Start
		-- Timer1 							= 13500,
		-- Timer2 							= 27000,
		-- Timer3 							= 40500,
		-- Timer4 							= 54000,
		-- Timer5							= 67500,
		-- Timer6							= 81000,
		-- Timer7 							= 94500,
		-- Timer8 							= 108000,
		-- Timer9 							= 121000,
		-- Timer10							= 135000, -- Endgame Units Only
		
		T0start								= 1,
		T1start								= 400,
		T1low								= 600,
		T1med								= 800,
		T1high								= 1000,
		T1top								= 1200,
		T2start								= 1500,
		T2low								= 2000,
		T2med								= 2500,
		T2high								= 3000,
		T2top								= 4000,
		T3start								= 5000,
		T3low								= 6000,
		T3med								= 7000,
		T3high								= 8000,
		T3top								= 9000,
		T4start								= 10000,
		T4low								= 12000,
		T4med								= 14000,
		T4high								= 16000,
		T4top								= 20000,
	},
}


-- Modules configs
buildingSpawnerModuleConfig = {
	spawnchance 						= 90,
	useSeaBlueprints 					= true,
}

unitSpawnerModuleConfig = {
	aircraftchance 						= 5, -- higher number = lower chance
	groupsizemultiplier 				= 1,
	spawnchance							= 60,
	beaconspawnchance					= 60,
	spawnchancecostscale				= 1, -- higher = smaller groups (fine tune together with groupsizemultiplier)
	landmultiplier 						= 0.8,
	airmultiplier 						= 1.5,
	seamultiplier 						= 0.3,
}

constructorControllerModuleConfig = {
	constructortimerstart				= 120, -- ammount of seconds it skips from constructortimer for the first spawn (make first spawn earlier - this timer starts on timer-Timer1)
	constructortimer 					= 200, -- time in seconds between commander/constructor spawns
	useresurrectors						= true,
	useconstructors						= true,
	usecollectors						= true,
}



-- Functions which you can configure
function UpdateTierChances(n)
	-- Must be 100 in total
	if globalScore > scavconfig.timers.T4top then
		TierSpawnChances.T0 = 0
		TierSpawnChances.T1 = 0
		TierSpawnChances.T2 = 5
		TierSpawnChances.T3 = 35
		TierSpawnChances.T4 = 60
	elseif globalScore > scavconfig.timers.T4high then
		TierSpawnChances.T0 = 0
		TierSpawnChances.T1 = 0
		TierSpawnChances.T2 = 10
		TierSpawnChances.T3 = 40
		TierSpawnChances.T4 = 50
	elseif globalScore > scavconfig.timers.T4med then
		TierSpawnChances.T0 = 0
		TierSpawnChances.T1 = 0
		TierSpawnChances.T2 = 15
		TierSpawnChances.T3 = 50
		TierSpawnChances.T4 = 35
	elseif globalScore > scavconfig.timers.T4low then
		TierSpawnChances.T0 = 0
		TierSpawnChances.T1 = 0
		TierSpawnChances.T2 = 20
		TierSpawnChances.T3 = 60
		TierSpawnChances.T4 = 20
	elseif globalScore > scavconfig.timers.T4start then
		TierSpawnChances.T0 = 0
		TierSpawnChances.T1 = 0
		TierSpawnChances.T2 = 20
		TierSpawnChances.T3 = 70
		TierSpawnChances.T4 = 10
	elseif globalScore > scavconfig.timers.T3top then
		TierSpawnChances.T0 = 0
		TierSpawnChances.T1 = 0
		TierSpawnChances.T2 = 20
		TierSpawnChances.T3 = 80
		TierSpawnChances.T4 = 0
	elseif globalScore > scavconfig.timers.T3high then
		TierSpawnChances.T0 = 0
		TierSpawnChances.T1 = 0
		TierSpawnChances.T2 = 30
		TierSpawnChances.T3 = 70
		TierSpawnChances.T4 = 0
	elseif globalScore > scavconfig.timers.T3med then
		TierSpawnChances.T0 = 0
		TierSpawnChances.T1 = 0
		TierSpawnChances.T2 = 50
		TierSpawnChances.T3 = 50
		TierSpawnChances.T4 = 0
	elseif globalScore > scavconfig.timers.T3low then
		TierSpawnChances.T0 = 0
		TierSpawnChances.T1 = 0
		TierSpawnChances.T2 = 75
		TierSpawnChances.T3 = 25
		TierSpawnChances.T4 = 0
	elseif globalScore > scavconfig.timers.T3start then
		TierSpawnChances.T0 = 0
		TierSpawnChances.T1 = 0
		TierSpawnChances.T2 = 90
		TierSpawnChances.T3 = 10
		TierSpawnChances.T4 = 0
	elseif globalScore > scavconfig.timers.T2top then
		TierSpawnChances.T0 = 0
		TierSpawnChances.T1 = 0
		TierSpawnChances.T2 = 100
		TierSpawnChances.T3 = 0
		TierSpawnChances.T4 = 0
	elseif globalScore > scavconfig.timers.T2high then
		TierSpawnChances.T0 = 0
		TierSpawnChances.T1 = 25
		TierSpawnChances.T2 = 75
		TierSpawnChances.T3 = 0
		TierSpawnChances.T4 = 0
	elseif globalScore > scavconfig.timers.T2med then
		TierSpawnChances.T0 = 0
		TierSpawnChances.T1 = 50
		TierSpawnChances.T2 = 50
		TierSpawnChances.T3 = 0
		TierSpawnChances.T4 = 0
	elseif globalScore > scavconfig.timers.T2low then
		TierSpawnChances.T0 = 0
		TierSpawnChances.T1 = 75
		TierSpawnChances.T2 = 25
		TierSpawnChances.T3 = 0
		TierSpawnChances.T4 = 0
	elseif globalScore > scavconfig.timers.T2start then
		TierSpawnChances.T0 = 0
		TierSpawnChances.T1 = 90
		TierSpawnChances.T2 = 10
		TierSpawnChances.T3 = 0
		TierSpawnChances.T4 = 0
	elseif globalScore > scavconfig.timers.T1top then
		TierSpawnChances.T0 = 0
		TierSpawnChances.T1 = 100
		TierSpawnChances.T2 = 0
		TierSpawnChances.T3 = 0
		TierSpawnChances.T4 = 0
	elseif globalScore > scavconfig.timers.T1high then
		TierSpawnChances.T0 = 25
		TierSpawnChances.T1 = 75
		TierSpawnChances.T2 = 0
		TierSpawnChances.T3 = 0
		TierSpawnChances.T4 = 0
	elseif globalScore > scavconfig.timers.T1med then
		TierSpawnChances.T0 = 50
		TierSpawnChances.T1 = 50
		TierSpawnChances.T2 = 0
		TierSpawnChances.T3 = 0
		TierSpawnChances.T4 = 0
	elseif globalScore > scavconfig.timers.T1low then
		TierSpawnChances.T0 = 75
		TierSpawnChances.T1 = 25
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
	
	
	-- if n > scavconfig.timers.Timer10 then
		-- TierSpawnChances.T0 = 0
		-- TierSpawnChances.T1 = 0
		-- TierSpawnChances.T2 = 0
		-- TierSpawnChances.T3 = 0
		-- TierSpawnChances.T4 = 100
	-- elseif n > scavconfig.timers.Timer9 then
		-- TierSpawnChances.T0 = 0
		-- TierSpawnChances.T1 = 0
		-- TierSpawnChances.T2 = 5
		-- TierSpawnChances.T3 = 15
		-- TierSpawnChances.T4 = 80
	-- elseif n > scavconfig.timers.Timer8 then
		-- TierSpawnChances.T0 = 0
		-- TierSpawnChances.T1 = 0
		-- TierSpawnChances.T2 = 20
		-- TierSpawnChances.T3 = 30
		-- TierSpawnChances.T4 = 50
	-- elseif n > scavconfig.timers.Timer7 then
		-- TierSpawnChances.T0 = 0
		-- TierSpawnChances.T1 = 5
		-- TierSpawnChances.T2 = 35
		-- TierSpawnChances.T3 = 50
		-- TierSpawnChances.T4 = 10
	-- elseif n > scavconfig.timers.Timer6 then
		-- TierSpawnChances.T0 = 0
		-- TierSpawnChances.T1 = 10
		-- TierSpawnChances.T2 = 75
		-- TierSpawnChances.T3 = 15
		-- TierSpawnChances.T4 = 0
	-- elseif n > scavconfig.timers.Timer5 then
		-- TierSpawnChances.T0 = 0
		-- TierSpawnChances.T1 = 20
		-- TierSpawnChances.T2 = 75
		-- TierSpawnChances.T3 = 5
		-- TierSpawnChances.T4 = 0
	-- elseif n > scavconfig.timers.Timer4 then
		-- TierSpawnChances.T0 = 0
		-- TierSpawnChances.T1 = 50
		-- TierSpawnChances.T2 = 50
		-- TierSpawnChances.T3 = 0
		-- TierSpawnChances.T4 = 0
	-- elseif n > scavconfig.timers.Timer3 then
		-- TierSpawnChances.T0 = 0
		-- TierSpawnChances.T1 = 70
		-- TierSpawnChances.T2 = 30
		-- TierSpawnChances.T3 = 0
		-- TierSpawnChances.T4 = 0
	-- elseif n > scavconfig.timers.Timer2 then
		-- TierSpawnChances.T0 = 0
		-- TierSpawnChances.T1 = 90
		-- TierSpawnChances.T2 = 10
		-- TierSpawnChances.T3 = 0
		-- TierSpawnChances.T4 = 0
	-- elseif n > scavconfig.timers.Timer1 then
		-- TierSpawnChances.T0 = 20
		-- TierSpawnChances.T1 = 80
		-- TierSpawnChances.T2 = 0
		-- TierSpawnChances.T3 = 0
		-- TierSpawnChances.T4 = 0
	-- elseif n > scavconfig.timers.Timer0 then
		-- TierSpawnChances.T0 = 90
		-- TierSpawnChances.T1 = 10
		-- TierSpawnChances.T2 = 0
		-- TierSpawnChances.T3 = 0
		-- TierSpawnChances.T4 = 0
	-- else
		-- TierSpawnChances.T0 = 100
		-- TierSpawnChances.T1 = 0
		-- TierSpawnChances.T2 = 0
		-- TierSpawnChances.T3 = 0
		-- TierSpawnChances.T4 = 0
	-- end
end