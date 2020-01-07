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
if scavconfig.modules.buildingSpawnerModule then
	buildingSpawnerModuleConfig = {
		spawnchance 					= 140,
		useSeaBlueprints 				= true,
	}
end

if scavconfig.modules.unitSpawnerModule then
	unitSpawnerModuleConfig = {
		aircraftchance 					= 5, -- higher number = lower chance
		groupsizemultiplier 			= 1,
		spawnchance						= 60,
	}
end

if scavconfig.modules.constructorControllerModule then
	constructorControllerModule = {
		constructortimer 				= 200, -- higher number = longer time between spawns
	}
end