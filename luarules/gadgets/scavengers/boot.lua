new_scavengers = 0
if new_scavengers == 1 then
	local GameShortName = Game.gameShortName
	VFS.Include("luarules/gadgets/scavengers/Configs/"..GameShortName.."/config.lua")
	for i = 1,#scavconfig do
		Spring.Echo("scavconfig value "..i.." = "..scavconfig[i])
	end

	VFS.Include("luarules/gadgets/scavengers/Modules/unit_controller.lua")

	if scavconfig.modules.buildingSpawnerModule then
		VFS.Include("luarules/gadgets/scavengers/Modules/building_spawner.lua")
	end

	if scavconfig.modules.constructorControllerModule then
		VFS.Include("luarules/gadgets/scavengers/Modules/constructor_controller.lua")
	end

	if scavconfig.modules.factoryControllerModule then
		VFS.Include("luarules/gadgets/scavengers/Modules/factory_controller.lua")
	end

	if scavconfig.modules.unitSpawnerModule then
		VFS.Include("luarules/gadgets/scavengers/Modules/unit_spawner.lua")
	end

	if scavconfig.modules.commanders then
		VFS.Include("luarules/gadgets/scavengers/Modules/commander_spawner.lua")
	end
else
	VFS.Include("luarules/gadgets/scavengers/Leftovers/scavenger_spawner.lua")
end