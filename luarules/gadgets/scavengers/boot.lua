if (not gadgetHandler:IsSyncedCode()) then
	return false
end

-- Base
VFS.Include("luarules/gadgets/scavengers/API/init.lua")
scavconfig = VFS.Include("luarules/gadgets/scavengers/Configs/" .. Game.gameShortName .. "/config.lua")
VFS.Include("luarules/gadgets/scavengers/API/api.lua")

spawnQueueLibrary = VFS.Include("luarules/utilities/damgam_lib/spawn_queue.lua")
positionCheckLibrary = VFS.Include("luarules/utilities/damgam_lib/position_checks.lua")
nearbyCaptureLibrary = VFS.Include("luarules/utilities/damgam_lib/nearby_capture.lua")
unitSwapLibrary = VFS.Include("luarules/utilities/damgam_lib/unit_swap.lua")

function ScavSendMessage(message)
	if scavconfig.messenger then
		SendToUnsynced("SendMessage", message)
	end
end

function ScavSendNotification(name)
	if scavconfig.messenger then
		SendToUnsynced("SendNotification", name)
	end
end

function ScavSendVoiceMessage(filedirectory)
	if scavconfig.messenger then
		Spring.SendCommands("scavplaysoundfile "..filedirectory)
	end
end

---- Unit Lists
bossUnitList = VFS.Include("luarules/gadgets/scavengers/Configs/" .. Game.gameShortName .. "/UnitLists/boss.lua")
constructorUnitList = VFS.Include("luarules/gadgets/scavengers/Configs/" .. Game.gameShortName .. "/UnitLists/constructors.lua")
staticUnitList = VFS.Include("luarules/gadgets/scavengers/Configs/" .. Game.gameShortName .. "/UnitLists/staticunits.lua")
factoryUnitList = VFS.Include("luarules/gadgets/scavengers/Configs/" .. Game.gameShortName .. "/UnitLists/factories.lua")
airUnitList = VFS.Include("luarules/gadgets/scavengers/Configs/" .. Game.gameShortName .. "/UnitLists/air.lua")
landUnitList = VFS.Include("luarules/gadgets/scavengers/Configs/" .. Game.gameShortName .. "/UnitLists/land.lua")
seaUnitList = VFS.Include("luarules/gadgets/scavengers/Configs/" .. Game.gameShortName .. "/UnitLists/sea.lua")

bossAbilities = VFS.Include("luarules/gadgets/scavengers/BossFight/" .. Game.gameShortName .. "/abilities.lua")

---- Modules
constructorController = VFS.Include("luarules/gadgets/scavengers/Modules/constructor_controller.lua")
randomEventsController = VFS.Include("luarules/gadgets/scavengers/Modules/random_events.lua")
factoryController = VFS.Include("luarules/gadgets/scavengers/Modules/factory_controller.lua")
nukeController = VFS.Include("luarules/gadgets/scavengers/Modules/nuke_controller.lua")
bossController = VFS.Include("luarules/gadgets/scavengers/Modules/bossfight_module.lua")
unitController = VFS.Include("luarules/gadgets/scavengers/Modules/unit_controller.lua")
spawnBeaconsController = VFS.Include("luarules/gadgets/scavengers/Modules/spawn_beacons.lua")
messengerController = VFS.Include("luarules/gadgets/scavengers/Modules/messenger.lua")

if scavconfig.modules.unitSpawnerModule then
	unitSpawnerController = VFS.Include("luarules/gadgets/scavengers/Modules/unit_spawner.lua")
end
if scavconfig.modules.startBoxProtection then
	startboxProtectionController = VFS.Include("luarules/gadgets/scavengers/Modules/startbox_protection.lua")
end

if scavconfig.modules.reinforcementsModule then
	reinforcementsController = VFS.Include("luarules/gadgets/scavengers/Modules/reinforcements_module.lua")
end
if scavconfig.modules.stockpilers == true then
	stockpilingController = VFS.Include("luarules/gadgets/scavengers/Modules/stockpiling.lua")
end

unitAddOrRemoveAPI = VFS.Include("luarules/gadgets/scavengers/API/unitaddremove.lua")

local function DisableUnit(unitID)
	Spring.DestroyUnit(unitID, false, true)
end

local function DisableCommander()
	local teamUnits = Spring.GetTeamUnits(scavengerAITeamID)
	for _, unitID in ipairs(teamUnits) do
		DisableUnit(unitID)
	end
end

function DestroyOldBuildings()
	local unitCount = Spring.GetTeamUnitCount(ScavengerTeamID)
	local unitCountBuffer = scavMaxUnits*0.1
	if unitCount + unitCountBuffer > scavMaxUnits then 
		for i = 1,((unitCount + unitCountBuffer)-scavMaxUnits) do
			if i > 5 then
				break
			end
			if #BaseCleanupQueue > 0 then
				spawnQueueLibrary.AddToDestroyQueue(BaseCleanupQueue[1], true, false, Spring.GetGameFrame()+1)
				table.remove(BaseCleanupQueue, 1)
			end
		end
	end
end

function PutScavAlliesInScavTeam(n)
	local players = Spring.GetPlayerList()
	for i = 1,#players do
		local player = players[i]
		local name, active, spectator, teamID, allyTeamID = Spring.GetPlayerInfo(player)
		if allyTeamID == ScavengerAllyTeamID and (not spectator) then
			Spring.AssignPlayerToTeam(player, ScavengerTeamID)
			local units = Spring.GetTeamUnits(teamID)
			for u = 1,#units do
				scavteamhasplayers = true
				spawnQueueLibrary.AddToDestroyQueue(units[u], false, true, n+1)
				Spring.KillTeam(teamID)
			end
		end
	end

	local scavAllies = Spring.GetTeamList(ScavengerAllyTeamID)
	for i = 1,#scavAllies do
		local _,_,_,AI = Spring.GetTeamInfo(scavAllies[i])
		local LuaAI = Spring.GetTeamLuaAI(scavAllies[i])
		if (AI or LuaAI) and scavAllies[i] ~= ScavengerTeamID then
			local units = Spring.GetTeamUnits(scavAllies[i])
			for u = 1,#units do
				spawnQueueLibrary.AddToDestroyQueue(units[u], false, true, n+1)
				Spring.KillTeam(scavAllies[i])
			end
		end
	end
end

local minionFramerate = math.ceil(scavconfig.unitSpawnerModuleConfig.FinalBossMinionsPassive/(teamcount*spawnmultiplier))
function gadget:GameFrame(n)
	if n == 1 then
		PutScavAlliesInScavTeam(n)
		teamsCheck()
		UpdateTierChances(n)
	end

	if n > 1 then
		spawnQueueLibrary.SpawnUnitsFromQueue(n)
		spawnQueueLibrary.DestroyUnitsFromQueue(n)
		DestroyOldBuildings()
	end

	if n == 300 then
		Spring.SetTeamColor(ScavengerTeamID, 0.38, 0.14, 0.38)
	end

	if n%30 == 0 and scavconfig.messenger == true then
		messengerController.pregameMessages(n)
	end

	if scavconfig.modules.startBoxProtection == true and ScavengerStartboxExists == true then
		-- if n%30 == 0 then
		-- 	startboxProtectionController.spawnStartBoxProtection(n)
		-- end
		if n%10 == 0 then
			startboxProtectionController.executeStartBoxProtection(n)
		end
		if n%45 == 15 then
			startboxProtectionController.spawnStartBoxEffect2(n)
		end
		if n%(math.ceil(5600000/(ScavSafeAreaSize*ScavSafeAreaSize))) == 0 then
			startboxProtectionController.spawnStartBoxEffect(n)
		end
	end

	randomEventsController.GameFrame(n)

	if n%30 == 0 and FinalBossUnitSpawned and not FinalBossKilled then
		local currentbosshealth = Spring.GetUnitHealth(FinalBossUnitID)
		--local initialbosshealth = scavconfig.unitSpawnerModuleConfig.FinalBossHealth*teamcount*spawnmultiplier
		local bosshealthpercentage = math.floor(currentbosshealth/(initialbosshealth*0.01))
		--ScavSendMessage("Boss Health: "..math.ceil(currentbosshealth).. " ("..bosshealthpercentage.."%)")

		bossController.UpdateFightPhase(bosshealthpercentage)
		bossController.ActivateAbility(n)
	end

	if n%10 == 0 and FinalBossUnitSpawned and not FinalBossKilled then
		bossController.ActivatePassiveAbilities(n)
	end

	if n%minionFramerate == 0 and FinalBossUnitSpawned and FinalBossKilled == false then
		unitSpawnerController.BossMinionsSpawn(n)
	end

	if n%30 == 0 and scavconfig.modules.reinforcementsModule and FinalBossKilled == false then
		reinforcementsController.spawnPlayerReinforcements(n)
		reinforcementsController.CaptureBeacons(n)
		reinforcementsController.SetBeaconsResourceProduction(n)
		reinforcementsController.ReinforcementsMoveOrder(n)
	end

	if n%30 == 0 and ScavengerTeamID ~= Spring.GetGaiaTeamID() then
		if not disabledCommander then
			DisableCommander()
			disabledCommander = true
		end
	end

	if n == 100 and globalScore then
		if scavteamhasplayers == false then
			Spring.SetTeamResource(ScavengerTeamID, "ms", 1000000)
			Spring.SetTeamResource(ScavengerTeamID, "es", 1000000)
		end
		Spring.SetGlobalLos(ScavengerAllyTeamID, false)
	end

	if n%30 == 0 and globalScore then
		
		if scavteamhasplayers == false then
			Spring.SetTeamResource(ScavengerTeamID, "ms", 1000000)
			Spring.SetTeamResource(ScavengerTeamID, "es", 1000000)
			Spring.SetTeamResource(ScavengerTeamID, "m", 1000000)
			Spring.SetTeamResource(ScavengerTeamID, "e", 1000000)
		end
		if BossWaveStarted == true then
			unitSpawnerController.BossWaveTimer(n)
		end
		local scavUnits = Spring.GetTeamUnits(ScavengerTeamID)
		local scavUnitsCount = #scavUnits
		if (scavUnitsCount < (scavconfig.unitSpawnerModuleConfig.minimumspawnbeacons*4) or numOfSpawnBeacons == 0) and n > scavconfig.gracePeriod*3 then 
			killedscavengers = killedscavengers + 1000
			if BossWaveStarted and (BossWaveTimeLeft and BossWaveTimeLeft > 20) then
				BossWaveTimeLeft = 20
			end
		end
	end

	if n%900 == 0 and n > 100 and FinalBossKilled == false then
		if (BossWaveStarted == false) and globalScore > scavconfig.timers.BossFight and scavconfig.unitSpawnerModuleConfig.bossFightEnabled then
			BossWaveStarted = true
		elseif not FinalBossUnitSpawned and not BossWaveStarted then
			if scavengersAIEnabled and scavengersAIEnabled == true then
				if globalScore == 0 then globalScore = 1 end
				if scavconfig.timers.BossFight == 0 then scavconfig.timers.BossFight = 1 end
			end
		end
	end

	if n%90 == 0 and scavconfig.modules.buildingSpawnerModule and FinalBossKilled == false then --and (not FinalBossUnitSpawned) then
		SpawnBlueprint(n)
	end

	-- if n%(math.ceil(1800/spawnmultiplier)) == 0 and not scavteamhasplayers and scavengerGamePhase ~= "initial" and scavconfig.constructorControllerModuleConfig.useresurrectors and FinalBossKilled == false then
	-- 	constructorController.SpawnResurrectorGroup(n)
	-- end

	if n%30 == 0 then
		if n > scavconfig.gracePeriod and scavengerGamePhase == "initial" then
			local scoreNow = globalScore
			endOfGracePeriodScore = scoreNow
			scavengerGamePhase = "action"
		end
		if globalScore then
			teamsCheck()
			UpdateTierChances(n)
			collectScavStats()
		end
		if scavconfig.modules.unitSpawnerModule and FinalBossKilled == false then
			spawnBeaconsController.SpawnBeacon(n)
			unitSpawnerController.UnitGroupSpawn(n)
		end
		if scavconfig.modules.constructorControllerModule and scavconfig.constructorControllerModuleConfig.useconstructors and scavengerGamePhase ~= "initial" then
			constructorController.SpawnConstructor(n)
		end
		local scavengerunits = Spring.GetTeamUnits(ScavengerTeamID)
		if scavengerunits and scavengerGamePhase ~= "initial" then
			for _, scav in ipairs(scavengerunits) do
				local scavDef = Spring.GetUnitDefID(scav)
				local collectorRNG = math_random(0,5)
				local scavFirestate = Spring.GetUnitStates(scav)["firestate"]
				if (scavFirestate ~= 2) or (scavFirestate ~= 1 and scavengerGamePhase == "initial") then
					if scavengerGamePhase == "initial" then
						Spring.GiveOrderToUnit(scav,CMD.FIRE_STATE,{1},0)
					else
						Spring.GiveOrderToUnit(scav,CMD.FIRE_STATE,{2},0)
					end
				end

				if n%300 == 0 and scavconfig.modules.stockpilers == true then
					if scavStockpiler[scav] == true then
						stockpilingController.ScavStockpile(n, scav)
					end
				end

				if not scavteamhasplayers and scavconfig.modules.nukes then
					if scavNuke[scav] then
						nukeController.SendRandomNukeOrder(n, scav)
					end
				end

				if scavteamhasplayers == false  then
					if scavconfig.modules.constructorControllerModule and scavconfig.constructorControllerModuleConfig.useconstructors then
						if scavConstructor[scav] then
							if Spring.GetCommandQueue(scav, 0) <= 0 then
								constructorController.ConstructNewBlueprint(n, scav)
							end
						end
					end

					if not scavteamhasplayers and scavconfig.constructorControllerModuleConfig.useresurrectors and collectorRNG == 0 then
						if scavResurrector[scav] then
							constructorController.ResurrectorOrders(n, scav)
						end
					end

					if not scavteamhasplayers and scavconfig.constructorControllerModuleConfig.usecollectors and collectorRNG == 0 then
						if scavCollector[scav] then
							constructorController.CollectorOrders(n, scav)
						end
						if scavCapturer[scav] then
							constructorController.CapturerOrders(n, scav)
						end
						if scavReclaimer[scav] then
							constructorController.ReclaimerOrders(n, scav)
						end
					end

					if scavAssistant[scav] and Spring.GetCommandQueue(scav, 0) <= 0 then
						constructorController.AssistantOrders(n, scav)
					end
				end

				if not scavteamhasplayers then
					factoryController.BuildUnit(scav, scavDef)
				end

				if scavteamhasplayers == false and n%900 == 0 and not scavStructure[scav] and not scavAssistant[scav] and not scavFactory[scav] and not scavSpawnBeacon[scav] then
					unitController.SelfDestructionControls(n, scav, scavDef, false)
				end
				if scavteamhasplayers == false and not scavStructure[scav] and not scavConstructor[scav] and not scavReclaimer[scav] and not scavResurrector[scav] and not scavAssistant[scav] and not scavCollector[scav] and not scavCapturer[scav] and not scavFactory[scav] and not scavSpawnBeacon[scav] then
					if Spring.GetCommandQueue(scav, 0) <= 3 then
						unitController.ArmyMoveOrders(n, scav, scavDef)
					elseif math.random(1,10) == 1 then
						Spring.GiveOrderToUnit(scav, CMD.STOP, 0, 0)
						Spring.GiveOrderToUnit(scav, CMD.STOP, 0, 0)
						unitController.ArmyMoveOrders(n, scav, scavDef)
					end
				end
			end
		end
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	local unitName = UnitDefs[unitDefID].name
	--Spring.Echo(Spring.GetUnitHeading(unitID))
	if unitName == staticUnitList.friendlySpawnEffectUnit then
		Spring.GiveOrderToUnit(unitID, CMD.SELFD,{}, {"shift"})
	end
	if unitTeam == ScavengerTeamID then
		unitAddOrRemoveAPI.AddScavUnit(unitID, unitDefID, unitName, unitTeam)
	else
		unitAddOrRemoveAPI.AddNonScavUnit(unitID, unitDefID, unitName, unitTeam)
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	local unitName = UnitDefs[unitDefID].name
	-- if unitName == "armassistdrone" or unitName == "corassistdrone" then
	-- 	constructorController.AssistDroneRespawn(unitID, unitName)
	-- end
	if unitTeam == ScavengerTeamID then
		unitAddOrRemoveAPI.RemoveScavUnit(unitID, unitDefID, unitTeam, unitName, attackerID, attackerDefID, attackerTeam)
	else
		unitAddOrRemoveAPI.RemoveNonScavUnit(unitID, unitDefID, unitTeam, unitName, attackerID, attackerDefID, attackerTeam)
	end
end

function gadget:UnitGiven(unitID, unitDefID, unitNewTeam, unitOldTeam)
	local unitName = UnitDefs[unitDefID].name
	if unitOldTeam == ScavengerTeamID then
		unitAddOrRemoveAPI.CaptureScavUnit(unitID, unitDefID, unitName, unitNewTeam, unitOldTeam)
	else
		if unitNewTeam == ScavengerTeamID then
			unitAddOrRemoveAPI.CaptureNonScavUnit(unitID, unitDefID, unitName, unitNewTeam, unitOldTeam)
		elseif UnitDefs[unitDefID].name == staticUnitList.scavSpawnBeacon then
			numOfSpawnBeaconsTeams[unitOldTeam] = numOfSpawnBeaconsTeams[unitOldTeam] - 1
			numOfSpawnBeaconsTeams[unitNewTeam] = numOfSpawnBeaconsTeams[unitNewTeam] + 1
		end
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if unitTeam == ScavengerTeamID then
		-- CMD.CLOAK = 37382
		local UnitName = UnitDefs[unitDefID].name
		if string.find(UnitName, scavconfig.unitnamesuffix) then
			UnitSuffixLenght[unitID] = string.len(scavconfig.unitnamesuffix)
		else
			UnitSuffixLenght[unitID] = 0
		end

		-- if staticUnitList.WallsID[unitDefID] then
		-- 	Spring.SetUnitNeutral(unitID, false)
		-- end

		Spring.GiveOrderToUnit(unitID,37382,{1},0)
		-- Fire At Will
		if scavConstructor[unitID] then
			-- if scavengerGamePhase == "initial" then
			-- 	Spring.GiveOrderToUnit(unitID,CMD.FIRE_STATE,{1},0)
			-- else
				Spring.GiveOrderToUnit(unitID,CMD.FIRE_STATE,{2},0)
			-- end
			if scavteamhasplayers == false then
				Spring.GiveOrderToUnit(unitID,CMD.MOVE_STATE,{0},0)
			end
		else
			-- if scavengerGamePhase == "initial" then
			-- 	Spring.GiveOrderToUnit(unitID,CMD.FIRE_STATE,{1},0)
			-- else
				Spring.GiveOrderToUnit(unitID,CMD.FIRE_STATE,{2},0)
			-- end
			if scavteamhasplayers == false then
				Spring.GiveOrderToUnit(unitID,CMD.MOVE_STATE,{2},0)
			end
		end
	end
end

function gadget:UnitDamaged(unitID, unitDefID, unitTeam)
	if unitTeam == ScavengerTeamID then
		local unitName = UnitDefs[unitDefID].name
		for i = 1,#bossUnitList.Bosses do
			if unitName == bossUnitList.Bosses[i] then
				local n = Spring.GetGameFrame()
				if not lastMinionFrame then
					lastMinionFrame = n
				end
				if n > lastMinionFrame + math.ceil(scavconfig.unitSpawnerModuleConfig.FinalBossMinionsActive/(teamcount*spawnmultiplier)) and FinalBossUnitID then
					lastMinionFrame = n
					unitSpawnerController.BossMinionsSpawn(n)
				end
			end
		end
	end
end
