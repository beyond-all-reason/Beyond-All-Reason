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
		Tech2							= 39000,
		Tech3 							= 60000,
	},
}


-- Modules configs
if scavconfig.modules.buildingSpawnerModule then
	buildingSpawnerModuleConfig = {
		spawnchance 					= 2,
		useSeaBlueprints 				= false,
	}
end

if scavconfig.modules.unitSpawnerModule then
	unitSpawnerModuleConfig = {
		aircraftchance = 5, -- higher number = lower chance
		groupsizemultiplier = 1,
	}
end