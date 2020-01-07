if (not gadgetHandler:IsSyncedCode()) then
	return false
end

new_scavengers = 0
if new_scavengers == 1 then
	GameShortName = Game.gameShortName
	VFS.Include("luarules/gadgets/scavengers/Configs/"..GameShortName.."/config.lua")
	--for i = 1,#scavconfig do
		--Spring.Echo("scavconfig value "..i.." = "..scavconfig[i])
	--end
	
	-- Include
	VFS.Include("luarules/gadgets/scavengers/API/api.lua")
	VFS.Include("luarules/gadgets/scavengers/Modules/unit_controller.lua")

	if scavconfig.modules.buildingSpawnerModule then
		ScavengerBlueprintsT0 = {}
		ScavengerBlueprintsT1 = {}
		ScavengerBlueprintsT2 = {}
		ScavengerBlueprintsT3 = {}
		ScavengerBlueprintsT0Sea = {}
		ScavengerBlueprintsT1Sea = {}
		ScavengerBlueprintsT2Sea = {}
		ScavengerBlueprintsT3Sea = {}
		VFS.Include("luarules/gadgets/scavengers/Modules/building_spawner.lua")
	end

	if scavconfig.modules.constructorControllerModule then
		ScavengerConstructorBlueprintsT0 = {}
		ScavengerConstructorBlueprintsT1 = {}
		ScavengerConstructorBlueprintsT2 = {}
		ScavengerConstructorBlueprintsT3 = {}
		ScavengerConstructorBlueprintsT0Sea = {}
		ScavengerConstructorBlueprintsT1Sea = {}
		ScavengerConstructorBlueprintsT2Sea = {}
		ScavengerConstructorBlueprintsT3Sea = {}
		VFS.Include("luarules/gadgets/scavengers/Modules/constructor_controller.lua")
	end

	if scavconfig.modules.factoryControllerModule then
		VFS.Include("luarules/gadgets/scavengers/Modules/factory_controller.lua")
	end

	if scavconfig.modules.unitSpawnerModule then
		VFS.Include("luarules/gadgets/scavengers/Modules/unit_spawner.lua")
	end
	
else
	VFS.Include("luarules/gadgets/scavengers/Leftovers/scavenger_spawner.lua")
end

function gadget:GameFrame(n)
	if new_scavengers == 1 then
		if n == 100 then
			Spring.Echo("New Scavenger Spawner initialized")
			Spring.SetTeamResource(GaiaTeamID, "ms", 100000)
			Spring.SetTeamResource(GaiaTeamID, "es", 100000)
			Spring.SetGlobalLos(GaiaAllyTeamID, false)
		end
		if n%300 == 0 then
			Spring.SetTeamResource(GaiaTeamID, "ms", 100000)
			Spring.SetTeamResource(GaiaTeamID, "es", 100000)
			Spring.SetTeamResource(GaiaTeamID, "m", 100000)
			Spring.SetTeamResource(GaiaTeamID, "e", 100000)
		end
		
		
		if n%90 == 0 and scavconfig.modules.buildingSpawnerModule then
			SpawnBlueprint(n)
		end
		if n%30 == 0 and scavconfig.modules.unitSpawnerModule then
			UnitGroupSpawn(n)
		end
	else
		OldSpawnGadgetCrap(n)
	end
end