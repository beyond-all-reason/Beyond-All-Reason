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
	},
}


-- Modules configs
buildingSpawnerModuleConfig = {
	spawnchance 						= 140,
	useSeaBlueprints 					= true,
}

unitSpawnerModuleConfig = {
	aircraftchance 						= 5, -- higher number = lower chance
	groupsizemultiplier 				= 1,
	spawnchance							= 60,
	spawnchancecostscale				= 1, -- higher = smaller groups (fine tune together with groupsizemultiplier)
	landmultiplier 						= 1,
	airmultiplier 						= 2.5,
	seamultiplier 						= 0.5,
}

constructorControllerModuleConfig = {
	constructortimer 					= 250, -- higher number = longer time between spawns
	useresurrectors						= true,
	useconstructors						= true,
	usecollectors						= true,
}