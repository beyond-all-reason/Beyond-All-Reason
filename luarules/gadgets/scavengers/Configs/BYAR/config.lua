Spring.Echo("[Scavengers] Config initialized")

scavconfig = {
	unitnamesuffix = "_scav",
	modules = {
		buildingSpawnerModule 			= true,
		constructorControllerModule 	= true,
		factoryControllerModule 		= true,
		unitSpawnerModule 				= true,
	},
	timers = {
		-- (30 = 1 second)
		Tech0 							= 9000,
		Tech1 							= 18000,
		Tech2							= 36000,
		Tech3 							= 60000,
		Tech4 							= 72000,
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
	spawnchancecostscale				= 1, -- higher = smaller groups (fine tune together with groupsizemultiplier)
	landmultiplier 						= 0.8,
	airmultiplier 						= 1.5,
	seamultiplier 						= 0.3,
}

constructorControllerModuleConfig = {
	constructortimerstart				= 120, -- ammount of seconds it skips from constructortimer for the first spawn (make first spawn earlier - this timer starts on timer-tech0)
	constructortimer 					= 200, -- time in seconds between commander/constructor spawns
	useresurrectors						= true,
	useconstructors						= true,
	usecollectors						= true,
}