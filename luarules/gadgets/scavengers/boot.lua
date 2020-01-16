if (not gadgetHandler:IsSyncedCode()) then
	return false
end

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

function gadget:GameFrame(n)
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
		if scavconfig.modules.unitSpawnerModule then
			UnitGroupSpawn(n)
		end
		if scavconfig.modules.buildingSpawnerModule and constructorControllerModuleConfig.useconstructors and n > scavconfig.timers.Tech0 then
			SpawnConstructor()
		end
		local scavengerunits = Spring.GetTeamUnits(GaiaTeamID)
		if scavengerunits then
			for i = 1,#scavengerunits do
				local scav = scavengerunits[i]
				local scavDef = Spring.GetUnitDefID(scav)
				local collectorRNG = math.random(0,5)
				-- scavStructure[scav] = UnitDefs[scavDef].isBuilding
				-- for i = 1,#NoSelfdList do
					-- if string.find(UnitDefs[scavDef].name..scavconfig.unitnamesuffix, NoSelfdList[i]) then
						-- scavStructure[scav] = true
					-- end
				-- end
				
				if scavconfig.modules.constructorControllerModule then
					if constructorControllerModuleConfig.useconstructors then
						-- for i = 1,#ConstructorsList do
							-- if string.find(UnitDefs[scavDef].name..scavconfig.unitnamesuffix, ConstructorsList[i]) then
								-- scavConstructor[scav] = true
							-- end
						-- end
						if scavConstructor[scav] and Spring.GetCommandQueue(scav, 0) <= 1 then
							ConstructNewBlueprint(n, scav)
						end
					end
					
					if constructorControllerModuleConfig.useresurrectors and collectorRNG == 0 then
						-- for i = 1,#Resurrectors do
							-- if string.find(UnitDefs[scavDef].name..scavconfig.unitnamesuffix, Resurrectors[i]) then
								-- scavResurrector[scav] = true
							-- end
						-- end
						-- for i = 1,#ResurrectorsSea do
							-- if string.find(UnitDefs[scavDef].name..scavconfig.unitnamesuffix, ResurrectorsSea[i]) then
								-- scavResurrector[scav] = true
							-- end
						-- end
						if scavResurrector[scav] then
							ResurrectorOrders(n, scav)
						end
					end
					
					if constructorControllerModuleConfig.usecollectors and collectorRNG == 0 then
						-- for i = 1,#Collectors do
							-- if string.find(UnitDefs[scavDef].name..scavconfig.unitnamesuffix, Collectors[i]) then
								-- scavCollector[scav] = true
							-- end
						-- end
						if scavCollector[scav] then
							CollectorOrders(n, scav)
						end
					end
					
					--for i = 1,#AssistUnits do
						-- if string.find(UnitDefs[scavDef].name..scavconfig.unitnamesuffix, AssistUnits[i]) then
							-- scavAssistant[scav] = true
						-- end
					--end
					if scavAssistant[scav] and Spring.GetCommandQueue(scav, 0) <= 1 then
						AssistantOrders(n, scav)
					end
				end
				
				if scavconfig.modules.factoryControllerModule then
					-- for i = 1,#Factories do
						-- if string.find(UnitDefs[scavDef].name..scavconfig.unitnamesuffix, Factories[i]) then
							-- scavFactory[scav] = true
						-- end
					-- end
					if scavFactory[scav] and #Spring.GetFullBuildQueue(scav, 0) <= 1 then
						FactoryProduction(n, scav, scavDef)
					end
				end
				
				if n%900 == 0 and not scavStructure[scav] and not scavConstructor[scav] and not scavResurrector[scav] and not scavAssistant[scav] and not scavCollector[scav] and not scavFactory[scav] then
					SelfDestructionControls(n, scav, scavDef)
				end
				if Spring.GetCommandQueue(scav, 0) <= 1 and not scavStructure[scav] and not scavConstructor[scav] and not scavResurrector[scav] and not scavAssistant[scav] and not scavCollector[scav] and not scavFactory[scav] then
					ArmyMoveOrders(n, scav)
				end
				
			end
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	if unitTeam == GaiaTeamID then
		selfdx[unitID] = nil
		selfdy[unitID] = nil
		selfdz[unitID] = nil
		oldselfdx[unitID] = nil
		oldselfdy[unitID] = nil
		oldselfdz[unitID] = nil
		scavNoSelfD[unitID] = nil
		scavConstructor[unitID] = nil
		scavAssistant[unitID] = nil
		scavResurrector[unitID] = nil
		scavCollector[unitID] = nil
		scavStructure[unitID] = nil
		scavFactory[unitID] = nil
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
    if unitTeam == GaiaTeamID then
    	if UnitDefs[unitDefID].name == "scavengerdroppod_scav" then
			Spring.GiveOrderToUnit(unitID, CMD.SELFD,{}, {"shift"})
		end
		-- CMD.CLOAK = 37382
        Spring.GiveOrderToUnit(unitID,37382,{1},{""})
        -- Fire At Will
        Spring.GiveOrderToUnit(unitID,CMD.FIRE_STATE,{2},{""})
		scavStructure[unitID] = UnitDefs[unitDefID].isBuilding
				
				for i = 1,#NoSelfdList do
					if string.find(UnitDefs[unitDefID].name..scavconfig.unitnamesuffix, NoSelfdList[i]) then
						scavStructure[unitID] = true
					end
				end
				
				if scavconfig.modules.constructorControllerModule then
					if constructorControllerModuleConfig.useconstructors then
						for i = 1,#ConstructorsList do
							if string.find(UnitDefs[unitDefID].name..scavconfig.unitnamesuffix, ConstructorsList[i]) then
								scavConstructor[unitID] = true
							end
						end
						-- if scavConstructor[unitID] and Spring.GetCommandQueue(unitID, 0) <= 1 then
							-- ConstructNewBlueprint(n, unitID)
						-- end
					end
					
					if constructorControllerModuleConfig.useresurrectors then
						for i = 1,#Resurrectors do
							if string.find(UnitDefs[unitDefID].name..scavconfig.unitnamesuffix, Resurrectors[i]) then
								scavResurrector[unitID] = true
							end
						end
						for i = 1,#ResurrectorsSea do
							if string.find(UnitDefs[unitDefID].name..scavconfig.unitnamesuffix, ResurrectorsSea[i]) then
								scavResurrector[unitID] = true
							end
						end
						-- if scavResurrector[unitID] then
							-- ResurrectorOrders(n, unitID)
						-- end
					end
					
					if constructorControllerModuleConfig.usecollectors then
						for i = 1,#Collectors do
							if string.find(UnitDefs[unitDefID].name..scavconfig.unitnamesuffix, Collectors[i]) then
								scavCollector[unitID] = true
							end
						end
						-- if scavCollector[unitID] then
							-- CollectorOrders(n, unitID)
						-- end
					end
					
					for i = 1,#AssistUnits do
						if string.find(UnitDefs[unitDefID].name..scavconfig.unitnamesuffix, AssistUnits[i]) then
							scavAssistant[unitID] = true
						end
					end
					-- if scavAssistant[unitID] and Spring.GetCommandQueue(unitID, 0) <= 1 then
						-- AssistantOrders(n, unitID)
					-- end
				end
				
				if scavconfig.modules.factoryControllerModule then
					for i = 1,#Factories do
						if string.find(UnitDefs[unitDefID].name..scavconfig.unitnamesuffix, Factories[i]) then
							scavFactory[unitID] = true
						end
					end
					-- if scavFactory[unitID] and #Spring.GetFullBuildQueue(unitID, 0) <= 1 then
						-- FactoryProduction(n, unitID, unitDefID)
					-- end
				end
				
    end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if unitTeam == GaiaTeamID then
    	-- CMD.CLOAK = 37382
        Spring.GiveOrderToUnit(unitID,37382,{1},{""})
        -- Fire At Will
        Spring.GiveOrderToUnit(unitID,CMD.FIRE_STATE,{2},{""})
	end
end