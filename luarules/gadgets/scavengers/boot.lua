if (not gadgetHandler:IsSyncedCode()) then
	return false
end

GameShortName = Game.gameShortName
VFS.Include("luarules/gadgets/scavengers/Configs/"..GameShortName.."/config.lua")
--for i = 1,#scavconfig do
--Spring.Echo("scavconfig value "..i.." = "..scavconfig[i])
--end

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

VFS.Include("luarules/gadgets/scavengers/API/api.lua")
VFS.Include('luarules/gadgets/scavengers/API/poschecks.lua')
VFS.Include("luarules/gadgets/scavengers/Modules/unit_controller.lua")

local UnitLists = VFS.DirList('luarules/gadgets/scavengers/Configs/'..GameShortName..'/UnitLists/','*.lua')
for i = 1,#UnitLists do
	VFS.Include(UnitLists[i])
	Spring.Echo("Scav Units Directory: " ..UnitLists[i])
end

if scavconfig.modules.buildingSpawnerModule then
	ScavengerBlueprintsT0 = {}
	ScavengerBlueprintsT1 = {}
	ScavengerBlueprintsT2 = {}
	ScavengerBlueprintsT3 = {}
	ScavengerBlueprintsT4 = {}
	ScavengerBlueprintsT0Sea = {}
	ScavengerBlueprintsT1Sea = {}
	ScavengerBlueprintsT2Sea = {}
	ScavengerBlueprintsT3Sea = {}
	ScavengerBlueprintsT4Sea = {}
	VFS.Include("luarules/gadgets/scavengers/Modules/building_spawner.lua")
end

if scavconfig.modules.constructorControllerModule then
	ScavengerConstructorBlueprintsT0 = {}
	ScavengerConstructorBlueprintsT1 = {}
	ScavengerConstructorBlueprintsT2 = {}
	ScavengerConstructorBlueprintsT3 = {}
	ScavengerConstructorBlueprintsT4 = {}
	ScavengerConstructorBlueprintsT0Sea = {}
	ScavengerConstructorBlueprintsT1Sea = {}
	ScavengerConstructorBlueprintsT2Sea = {}
	ScavengerConstructorBlueprintsT3Sea = {}
	ScavengerConstructorBlueprintsT4Sea = {}
	VFS.Include("luarules/gadgets/scavengers/Modules/constructor_controller.lua")
end

if scavconfig.modules.randomEventsModule then
	RandomEventsList = {}
	VFS.Include("luarules/gadgets/scavengers/Modules/random_events.lua")
end

if scavconfig.modules.factoryControllerModule then
	VFS.Include("luarules/gadgets/scavengers/Modules/factory_controller.lua")
end

if scavconfig.modules.unitSpawnerModule then
	VFS.Include("luarules/gadgets/scavengers/Modules/unit_spawner.lua")
end

if scavconfig.modules.startBoxProtection then
	VFS.Include("luarules/gadgets/scavengers/Modules/startbox_protection.lua")
end

if scavconfig.modules.reinforcementsModule then
	VFS.Include("luarules/gadgets/scavengers/Modules/reinforcements_module.lua")
end

if scavconfig.modules.stockpilers == true then
	VFS.Include("luarules/gadgets/scavengers/Modules/stockpiling.lua")
end

if scavconfig.modules.nukes == true then
	VFS.Include("luarules/gadgets/scavengers/Modules/nuke_controller.lua")
end

VFS.Include("luarules/gadgets/scavengers/Modules/spawn_beacons.lua")
VFS.Include("luarules/gadgets/scavengers/Modules/messenger.lua")
VFS.Include("luarules/gadgets/scavengers/Modules/bossfight_module.lua")

local function DisableUnit(unitID)
	Spring.MoveCtrl.Enable(unitID)
	Spring.MoveCtrl.SetNoBlocking(unitID, true)
	Spring.MoveCtrl.SetPosition(unitID, Game.mapSizeX+1000, 2000, Game.mapSizeZ+1000) --don't move too far out or prevent_aicraft_hax will explode it!
	Spring.SetUnitCloak(unitID, true)
	--Spring.SetUnitHealth(unitID, {paralyze=99999999})
	Spring.SetUnitMaxHealth(unitID, 10000000)
	Spring.SetUnitHealth(unitID, 10000000)
	Spring.SetUnitNoDraw(unitID, true)
	Spring.SetUnitStealth(unitID, true)
	Spring.SetUnitNoSelect(unitID, true)
	Spring.SetUnitNoMinimap(unitID, true)
	Spring.GiveOrderToUnit(unitID, CMD.MOVE_STATE, { 0 }, 0)
	Spring.GiveOrderToUnit(unitID, CMD.FIRE_STATE, { 0 }, 0)
end

local function DisableCommander()
	local teamUnits = Spring.GetTeamUnits(scavengerAITeamID)
	for _, unitID in ipairs(teamUnits) do
		HiddenCommander = unitID
		DisableUnit(unitID)
	end
end

function QueueSpawn(unitName, posx, posy, posz, facing, team, frame)
	if UnitDefNames[unitName] then
		local QueueSpawnCommand = {unitName, posx, posy, posz, facing, team}
		local QueueFrame = frame
		if #QueuedSpawnsFrames > 0 then
			for i = 1, #QueuedSpawnsFrames do
				local CurrentQueueFrame = QueuedSpawnsFrames[i]
				if (not(CurrentQueueFrame < QueueFrame)) or i == #QueuedSpawnsFrames then
					table.insert(QueuedSpawns, i, QueueSpawnCommand)
					table.insert(QueuedSpawnsFrames, i, QueueFrame)
					break
				end
			end
		else
			table.insert(QueuedSpawns, QueueSpawnCommand)
			table.insert(QueuedSpawnsFrames, QueueFrame)
		end
	else
		Spring.Echo("[Scavengers] Failed to queue "..unitName..", invalid unit")
	end
end

function SpawnFromQueue(n)
	local QueuedSpawnsForNow = #QueuedSpawns
	if QueuedSpawnsForNow > 0 then
		for i = 1,QueuedSpawnsForNow do
			if n == QueuedSpawnsFrames[1] then
				local createSpawnCommand = QueuedSpawns[1]
				Spring.CreateUnit(QueuedSpawns[1][1],QueuedSpawns[1][2],QueuedSpawns[1][3],QueuedSpawns[1][4],QueuedSpawns[1][5],QueuedSpawns[1][6])
				Spring.SpawnCEG("scav-spawnexplo",QueuedSpawns[1][2],QueuedSpawns[1][3],QueuedSpawns[1][4],0,0,0)
				table.remove(QueuedSpawns, 1)
				table.remove(QueuedSpawnsFrames, 1)
			--else
				--break
			end
		end
	end
end

-- function PutSpectatorsInScavTeam(n)
	-- local players = Spring.GetPlayerList()
	-- for i = 1,#players do
		-- local player = players[i]
		-- local name, active, spectator = Spring.GetPlayerInfo(player)
		-- if spectator == true then
			-- Spring.AssignPlayerToTeam(player, GaiaTeamID)
		-- end
	-- end
-- end



local minionFramerate = math.ceil(unitSpawnerModuleConfig.FinalBossMinionsPassive/(teamcount*spawnmultiplier))
function gadget:GameFrame(n)


	-- if n%30 == 0 then
		-- PutSpectatorsInScavTeam(n)
	-- end

	if n > 1 then
		SpawnFromQueue(n)
	end

	if n == 1 and spawnProtectionConfig.useunit == false and scavconfig.modules.startBoxProtection == true and ScavengerStartboxExists then
		ScavSafeAreaExist = true
		ScavSafeAreaGenerator = 5
		ScavSafeAreaMinX = ScavengerStartboxXMin
		ScavSafeAreaMaxX = ScavengerStartboxXMax
		ScavSafeAreaMinZ = ScavengerStartboxZMin
		ScavSafeAreaMaxZ = ScavengerStartboxZMax
		ScavSafeAreaSize = math.ceil(((ScavengerStartboxXMax - ScavengerStartboxXMin) + (ScavengerStartboxZMax - ScavengerStartboxZMin))*0.25)
	end

	if n == 300 then
		--Spring.Echo("New Scavenger Spawner initialized")
		Spring.SetTeamColor(GaiaTeamID, 0.38, 0.14, 0.38)
	end

	if n%30 == 0 and scavconfig.messenger == true then
		pregameMessages(n)
	end

	if n%30 == 20 and n > 9000 and scavconfig.modules.randomEventsModule == true then
		RandomEventTrigger(n)
	end

	if n%(75/spawnmultiplier) == 0 and FinalBossUnitSpawned and FinalBossKilled == false then
		if not SpecialAbilityCountdown then SpecialAbilityCountdown = 10 end
		local currentbosshealth = Spring.GetUnitHealth(FinalBossUnitID)
		local initialbosshealth = unitSpawnerModuleConfig.FinalBossHealth*teamcount*spawnmultiplier
		local bosshealthpercentage = math.floor(currentbosshealth/(initialbosshealth*0.01))
		ScavSendMessage("Boss Health: "..math.ceil(currentbosshealth).. " ("..bosshealthpercentage.."%)")
		ScavBossPhaseControl(bosshealthpercentage)
		SpecialAbilityCountdown = SpecialAbilityCountdown - 1
		if SpecialAbilityCountdown <= 0 then
			local SpecAbi = BossSpecialAbilitiesUsedList[math_random(1,#BossSpecialAbilitiesUsedList)]
			if SpecAbi then
				SpecialAbilityCountdown = 10 - BossFightCurrentPhase
				SpecAbi(n)
			end
		end
	end

	if n%10 == 0 and FinalBossUnitSpawned and FinalBossKilled == false then
		BossPassiveAbilityController(n)
	end

	if n%minionFramerate == 0 and FinalBossUnitSpawned and FinalBossKilled == false then
		BossMinionsSpawn(n)
	end


	if scavconfig.modules.startBoxProtection == true and ScavSafeAreaExist == true and FinalBossKilled == false then
		if n%30 == 0 then
			spawnStartBoxProtection(n)
			executeStartBoxProtection(n)
			spawnStartBoxEffect2(n)
		end
		--if n%(math.ceil(450/(math.ceil(ScavSafeAreaSize/5)))) == 0 then
		if n%(math.ceil(4800000/(ScavSafeAreaSize*ScavSafeAreaSize))) == 0 then
			spawnStartBoxEffect(n)
		end
	end

	if n%30 == 0 and scavconfig.modules.reinforcementsModule then
		spawnPlayerReinforcements(n)
		CaptureBeacons(n)
		SetBeaconsResourceProduction(n)
	end

	if n%30 == 0 and GaiaTeamID ~= Spring.GetGaiaTeamID() then
		if not disabledCommander then
			DisableCommander()
			disabledCommander = true
		end
		Spring.SetUnitHealth(HiddenCommander, 10000000)
	end

	if n == 100 and globalScore then
		Spring.SetTeamResource(GaiaTeamID, "ms", 1000000)
		Spring.SetTeamResource(GaiaTeamID, "es", 1000000)
		Spring.SetGlobalLos(GaiaAllyTeamID, false)
	end
	if n%30 == 0 and globalScore then
		Spring.SetTeamResource(GaiaTeamID, "ms", 1000000)
		Spring.SetTeamResource(GaiaTeamID, "es", 1000000)
		Spring.SetTeamResource(GaiaTeamID, "m", 1000000)
		Spring.SetTeamResource(GaiaTeamID, "e", 1000000)
		if BossWaveStarted == true then
			BossWaveTimer(n)
		end
		local scavUnits = Spring.GetTeamUnits(GaiaTeamID)
		local scavUnitsCount = #scavUnits
		if scavUnitsCount < 5 and n > 18000 then
			killedscavengers = killedscavengers + 100
			if BossWaveStarted and (BossWaveTimeLeft and BossWaveTimeLeft > 20) then
				BossWaveTimeLeft = 20
			end
		end
	end
	if n%1800 == 0 and n > 100 then
		teamsCheck()
		UpdateTierChances(n)
		if (BossWaveStarted == false) and globalScore > scavconfig.timers.BossFight and unitSpawnerModuleConfig.bossFightEnabled then
			BossWaveStarted = true
		elseif not FinalBossUnitSpawned and not BossWaveStarted then
			if scavengersAIEnabled and scavengersAIEnabled == true then
				if globalScore == 0 then globalScore = 1 end
				if scavconfig.timers.BossFight == 0 then scavconfig.timers.BossFight = 1 end
				if globalScore/scavconfig.timers.BossFight < 1 then
					ScavSendMessage("Scavengers Tech Progress: "..math.ceil((globalScore/scavconfig.timers.BossFight)*100).."%")
					ScavSendMessage("Scav Score: "..globalScore)
					ScavSendMessage(TierSpawnChances.Message)
				else
					ScavSendMessage("Scavengers Tech Progress: 100%")
					ScavSendMessage("Score: "..globalScore)
					ScavSendMessage(TierSpawnChances.Message)
				end
			end
		end
	end

	if n%90 == 0 and scavconfig.modules.buildingSpawnerModule and (not FinalBossUnitSpawned) then
		SpawnBlueprint(n)
	end
	if n%30 == 0 then
		if scavconfig.modules.unitSpawnerModule and (not FinalBossUnitSpawned) then
			SpawnBeacon(n)
			UnitGroupSpawn(n)
		end
		if scavconfig.modules.constructorControllerModule and constructorControllerModuleConfig.useconstructors and n > 9000 and (not FinalBossUnitSpawned) then
			SpawnConstructor(n)
		end
		local scavengerunits = Spring.GetTeamUnits(GaiaTeamID)
		if scavengerunits then
			for i = 1,#scavengerunits do
				local scav = scavengerunits[i]
				local scavDef = Spring.GetUnitDefID(scav)
				local collectorRNG = math_random(0,2)

				if n%300 == 0 and scavconfig.modules.stockpilers == true then
					if scavStockpiler[scav] == true then
						ScavStockpile(n, scav)
					end
				end

				if scavconfig.modules.nukes == true then
					if scavNuke[scav] == true then
						SendRandomNukeOrder(n, scav)
					end
				end

				if scavconfig.modules.constructorControllerModule then
					if constructorControllerModuleConfig.useconstructors then
						if scavConstructor[scav] then
							if Spring.GetCommandQueue(scav, 0) <= 0 then
								-- if n%1800 == 0 then
									-- if (not HiddenCommander) or (scav ~= HiddenCommander) then
										-- SelfDestructionControls(n, scav, scavDef)
									-- end
								-- end
								ConstructNewBlueprint(n, scav)
							end
						end
					end

					if constructorControllerModuleConfig.useresurrectors and collectorRNG == 0 then
						if scavResurrector[scav] then
							ResurrectorOrders(n, scav)
						end
					end

					if constructorControllerModuleConfig.usecollectors and collectorRNG == 0 then
						if scavCollector[scav] then
							CollectorOrders(n, scav)
						end
						if scavReclaimer[scav] then
							ReclaimerOrders(n, scav)
						end
					end

					if scavAssistant[scav] and Spring.GetCommandQueue(scav, 0) <= 0 then
						AssistantOrders(n, scav)
					end
				end

				if scavconfig.modules.factoryControllerModule then
					if scavFactory[scav] and #Spring.GetFullBuildQueue(scav, 0) <= 0 then
						FactoryProduction(n, scav, scavDef)
					end
				end

				-- backup -- and not scavConstructor[scav] and not scavResurrector[scav] and not scavCollector[scav]
				if n%900 == 0 and not scavStructure[scav] and not scavAssistant[scav] and not scavFactory[scav] and not scavSpawnBeacon[scav] then
					SelfDestructionControls(n, scav, scavDef)
				end
				if Spring.GetCommandQueue(scav, 0) <= 1 and not scavStructure[scav] and not scavConstructor[scav] and not scavReclaimer[scav] and not scavResurrector[scav] and not scavAssistant[scav] and not scavCollector[scav] and not scavFactory[scav] and not scavSpawnBeacon[scav] then
					ArmyMoveOrders(n, scav, scavDef)
				end

			end
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	local UnitName = UnitDefs[unitDefID].name
	if unitTeam == GaiaTeamID then

		if FinalBossUnitSpawned == true then
			for i = 1,#BossUnits do
				if string.sub(UnitName, 1, string.len(UnitName)) == BossUnits[i] then
					Spring.Echo("GG")
					FinalBossKilled = true
					FinalBossUnitID = nil
				end
			end
		end

		killedscavengers = killedscavengers + scavconfig.scoreConfig.baseScorePerKill
		if scavStructure[unitID] and not UnitName == "scavengerdroppod_scav" and not UnitName == "scavengerdroppodbeacon_scav"  then
			killedscavengers = killedscavengers + scavconfig.scoreConfig.scorePerKilledBuilding
		end
		if scavConstructor[unitID] then
			killedscavengers = killedscavengers + scavconfig.scoreConfig.scorePerKilledConstructor
		end
		if UnitName == "scavengerdroppodbeacon_scav" or UnitDefs[unitDefID].name == "scavsafeareabeacon_scav" then
			numOfSpawnBeacons = numOfSpawnBeacons - 1
			killedscavengers = killedscavengers + scavconfig.scoreConfig.scorePerKilledSpawner
		end
		if UnitName == "scavengerdroppod_scav" then
			killedscavengers = killedscavengers - scavconfig.scoreConfig.baseScorePerKill
		end
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
		scavReclaimer[unitID] = nil
		scavStructure[unitID] = nil
		scavFactory[unitID] = nil
		scavSpawnBeacon[unitID] = nil
		scavStockpiler[unitID] = nil
		scavNuke[unitID] = nil
		UnitSuffixLenght[unitID] = nil
		ConstructorNumberOfRetries[unitID] = nil
		CaptureProgressForBeacons[unitID] = nil
		if UnitName == "scavsafeareabeacon_scav" then
			ScavSafeAreaExist = false
			killedscavengers = killedscavengers + ((scavconfig.scoreConfig.scorePerKilledSpawner+scavconfig.scoreConfig.baseScorePerKill)*4*ScavSafeAreaGenerator)
		end
	else
		for i = 1,#AliveEnemyCommanders do
			local comID = AliveEnemyCommanders[i]
			if unitID == comID then
				AliveEnemyCommandersCount = AliveEnemyCommandersCount - 1
				table.remove(AliveEnemyCommanders, i)
				break
			end
		end
		if UnitName == "scavengerdroppodbeacon_scav" or UnitDefs[unitDefID].name == "scavsafeareabeacon_scav" then
			numOfSpawnBeaconsTeams[unitTeam] = numOfSpawnBeaconsTeams[unitTeam] - 1
		end
	end
end

function gadget:UnitTaken(unitID, unitDefID, unitOldTeam, unitNewTeam)
	local UnitName = UnitDefs[unitDefID].name
	if unitOldTeam == GaiaTeamID then
		if UnitDefs[unitDefID].name == "scavengerdroppodbeacon_scav" or UnitDefs[unitDefID].name == "scavsafeareabeacon_scav" then
			numOfSpawnBeacons = numOfSpawnBeacons - 1
			numOfSpawnBeaconsTeams[unitNewTeam] = numOfSpawnBeaconsTeams[unitNewTeam] + 1
			killedscavengers = killedscavengers + scavconfig.scoreConfig.scorePerCapturedSpawner
			if scavconfig.modules.reinforcementsModule == true then
				Spring.SetUnitNeutral(unitID, false)
				Spring.SetUnitHealth(unitID, 10000)
				Spring.SetUnitMaxHealth(unitID, 10000)
			end
			--SpawnDefencesAfterCapture(unitID, unitNewTeam)
		end
		if UnitName == "scavsafeareabeacon_scav" then
			ScavSafeAreaExist = false
		end
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
		scavReclaimer[unitID] = nil
		scavStructure[unitID] = nil
		scavFactory[unitID] = nil
		scavSpawnBeacon[unitID] = nil
		scavStockpiler[unitID] = nil
		scavNuke[unitID] = nil
		UnitSuffixLenght[unitID] = nil
		ConstructorNumberOfRetries[unitID] = nil
		CaptureProgressForBeacons[unitID] = nil
		Spring.SetUnitHealth(unitID, {capture = 0})

	else
		if unitNewTeam == GaiaTeamID then
			if string.find(UnitName, scavconfig.unitnamesuffix) then
				UnitSuffixLenght[unitID] = string.len(scavconfig.unitnamesuffix)
			else
				UnitSuffixLenght[unitID] = 0
			end
			--Spring.Echo("Scavs just captured me " .. UnitName .. " and my suffix lenght is " .. UnitSuffixLenght[unitID])
			if UnitDefs[unitDefID].name == "scavengerdroppodbeacon_scav" or UnitDefs[unitDefID].name == "scavsafeareabeacon_scav" then
				numOfSpawnBeaconsTeams[unitOldTeam] = numOfSpawnBeaconsTeams[unitOldTeam] - 1
				numOfSpawnBeacons = numOfSpawnBeacons + 1
				scavSpawnBeacon[unitID] = true
			end
			-- CMD.CLOAK = 37382
			Spring.GiveOrderToUnit(unitID,37382,{1},0)
			-- Fire At Will
			Spring.GiveOrderToUnit(unitID,CMD.FIRE_STATE,{2},0)
			scavStructure[unitID] = UnitDefs[unitDefID].isBuilding
			for i = 1,#NoSelfdList do
				if string.sub(UnitName, 1, string.len(UnitName)-UnitSuffixLenght[unitID]) == NoSelfdList[i] then--string.find(UnitName, NoSelfdList[i]) then
					scavStructure[unitID] = true
				end
			end

			if scavconfig.modules.stockpilers == true then
				for i = 1,#StockpilingUnitNames do
					if string.sub(UnitName, 1, string.len(UnitName)-UnitSuffixLenght[unitID]) == StockpilingUnitNames[i] then
						scavStockpiler[unitID] = true
					end
				end
			end

			if scavconfig.modules.nukes == true then
				for i = 1,#NukingUnitNames do
					if string.sub(UnitName, 1, string.len(UnitName)-UnitSuffixLenght[unitID]) == NukingUnitNames[i] then
						scavNuke[unitID] = true
					end
				end
			end

			if scavconfig.modules.constructorControllerModule then
				if constructorControllerModuleConfig.useconstructors then
					for i = 1,#ConstructorsList do
						if string.sub(UnitName, 1, string.len(UnitName)-UnitSuffixLenght[unitID]) == ConstructorsList[i] then
							scavConstructor[unitID] = true
						end
					end
				end

				if constructorControllerModuleConfig.useresurrectors then
					for i = 1,#Resurrectors do
						if string.sub(UnitName, 1, string.len(UnitName)-UnitSuffixLenght[unitID]) == Resurrectors[i] then
							scavResurrector[unitID] = true
						end
					end
					for i = 1,#ResurrectorsSea do
						if string.sub(UnitName, 1, string.len(UnitName)-UnitSuffixLenght[unitID]) == ResurrectorsSea[i] then
							scavResurrector[unitID] = true
						end
					end
				end

				if constructorControllerModuleConfig.usecollectors then
					for i = 1,#Collectors do
						if string.sub(UnitName, 1, string.len(UnitName)-UnitSuffixLenght[unitID]) == Collectors[i] then
							if math_random(0,100) <= 10 then
								scavCollector[unitID] = true
							else
								scavReclaimer[unitID] = true
							end
						end
					end
				end

				for i = 1,#AssistUnits do
					if string.sub(UnitName, 1, string.len(UnitName)-UnitSuffixLenght[unitID]) == AssistUnits[i] then
						scavAssistant[unitID] = true
					end
				end
			end

			if scavconfig.modules.factoryControllerModule then
				for i = 1,#Factories do
					if string.sub(UnitName, 1, string.len(UnitName)-UnitSuffixLenght[unitID]) == Factories[i] then
						scavFactory[unitID] = true
					end
				end
			end
		end
		if UnitDefs[unitDefID].name == "scavengerdroppodbeacon_scav" or UnitDefs[unitDefID].name == "scavsafeareabeacon_scav" then
			numOfSpawnBeaconsTeams[unitOldTeam] = numOfSpawnBeaconsTeams[unitOldTeam] - 1
			numOfSpawnBeaconsTeams[unitNewTeam] = numOfSpawnBeaconsTeams[unitNewTeam] + 1
		end
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	local UnitName = UnitDefs[unitDefID].name
	--Spring.Echo(Spring.GetUnitHeading(unitID))
	if UnitName == "scavengerdroppodfriendly" then
		Spring.GiveOrderToUnit(unitID, CMD.SELFD,{}, {"shift"})
	end
	if unitTeam == GaiaTeamID then
		if string.find(UnitName, scavconfig.unitnamesuffix) then
			UnitSuffixLenght[unitID] = string.len(scavconfig.unitnamesuffix)
		else
			UnitSuffixLenght[unitID] = 0
			local frame = Spring.GetGameFrame()
			if frame > 300 then
				local heading = Spring.GetUnitHeading(unitID)
				local suffix = scavconfig.unitnamesuffix
				-- Spring.Echo(UnitName)
				-- Spring.Echo(UnitName..suffix)
				if UnitDefNames[UnitName..suffix] then
					local posx, posy, posz = Spring.GetUnitPosition(unitID)
					Spring.DestroyUnit(unitID, false, true)
					if heading >= -24576 and heading < -8192 then -- west
						-- 3
						QueueSpawn(UnitName..suffix, posx, posy, posz, 3 ,GaiaTeamID, frame+1)
						--Spring.CreateUnit(UnitName..suffix, posx, posy, posz, 3,GaiaTeamID)
					elseif heading >= -8192 and heading < 8192 then -- south
						-- 0
						QueueSpawn(UnitName..suffix, posx, posy, posz, 0 ,GaiaTeamID, frame+1)
						--Spring.CreateUnit(UnitName..suffix, posx, posy, posz, 0,GaiaTeamID)
					elseif heading >= 8192 and heading < 24576 then -- east
						-- 1
						QueueSpawn(UnitName..suffix, posx, posy, posz, 1 ,GaiaTeamID, frame+1)
						--Spring.CreateUnit(UnitName..suffix, posx, posy, posz, 1,GaiaTeamID)
					else -- north
						-- 2
						QueueSpawn(UnitName..suffix, posx, posy, posz, 2 ,GaiaTeamID, frame+1)
						--Spring.CreateUnit(UnitName..suffix, posx, posy, posz, 2,GaiaTeamID)
					end
					return
				end
			end
		end
		for i = 1,#BossUnits do
			if string.sub(UnitName, 1, string.len(UnitName)) == BossUnits[i] then
				--Spring.Echo("Got boss commander ID, attempting to spawn minions")
				FinalBossUnitID = unitID
				local bosshealth = unitSpawnerModuleConfig.FinalBossHealth*teamcount*spawnmultiplier
				Spring.SetUnitHealth(unitID, bosshealth)
			end
		end
		if UnitName == "scavsafeareabeacon_scav" then
			ScavSafeAreaExist = true
			if not ScavSafeAreaGenerator then
				ScavSafeAreaGenerator = 0
			end
			ScavSafeAreaSize = math.ceil(ScavSafeAreaSize + (250 * (teamcount*0.5) * (spawnmultiplier*0.5)))
			if ScavSafeAreaSize > 1000 then
				ScavSafeAreaSize = 1000
			end
			ScavSafeAreaGenerator = ScavSafeAreaGenerator + 1
			local posx, posy, posz = Spring.GetUnitPosition(unitID)
			ScavSafeAreaMinX = posx - ScavSafeAreaSize
			ScavSafeAreaMaxX = posx + ScavSafeAreaSize
			ScavSafeAreaMinZ = posz - ScavSafeAreaSize
			ScavSafeAreaMaxZ = posz + ScavSafeAreaSize
		end
		if UnitName == "scavengerdroppod_scav" then
			Spring.GiveOrderToUnit(unitID, CMD.SELFD,{}, {"shift"})
		end
		if UnitName == "scavengerdroppodbeacon_scav" or UnitDefs[unitDefID].name == "scavsafeareabeacon_scav" then
			scavSpawnBeacon[unitID] = true
			numOfSpawnBeacons = numOfSpawnBeacons + 1
			if scavconfig.modules.reinforcementsModule == true then
				Spring.SetUnitNeutral(unitID, true)
				Spring.SetUnitMaxHealth(unitID, 100000)
				Spring.SetUnitHealth(unitID, 100000)
			end
		end
		-- if UnitName == "lootboxgold" then //perhaps add this later when lootboxes are fully implemented
		-- 	Spring.SetUnitNeutral(unitID, true)
		-- end

		-- CMD.CLOAK = 37382
		Spring.GiveOrderToUnit(unitID,37382,{1},0)
		-- Fire At Will
		Spring.GiveOrderToUnit(unitID,CMD.FIRE_STATE,{2},0)
		scavStructure[unitID] = UnitDefs[unitDefID].isBuilding
		for i = 1,#NoSelfdList do
			if string.sub(UnitName, 1, string.len(UnitName)-UnitSuffixLenght[unitID]) == NoSelfdList[i] then--string.find(UnitName, NoSelfdList[i]) then
				scavStructure[unitID] = true
			end
		end

		if scavconfig.modules.stockpilers == true then
			for i = 1,#StockpilingUnitNames do
				if string.sub(UnitName, 1, string.len(UnitName)-UnitSuffixLenght[unitID]) == StockpilingUnitNames[i] then
					scavStockpiler[unitID] = true
				end
			end
		end

		if scavconfig.modules.nukes == true then
			for i = 1,#NukingUnitNames do
				if string.sub(UnitName, 1, string.len(UnitName)-UnitSuffixLenght[unitID]) == NukingUnitNames[i] then
					scavNuke[unitID] = true
				end
			end
		end

		if scavconfig.modules.constructorControllerModule then
			if constructorControllerModuleConfig.useconstructors then
				for i = 1,#ConstructorsList do
					if string.sub(UnitName, 1, string.len(UnitName)-UnitSuffixLenght[unitID]) == ConstructorsList[i] then
						scavConstructor[unitID] = true
					end
				end
			end

			if constructorControllerModuleConfig.useresurrectors then
				for i = 1,#Resurrectors do
					if string.sub(UnitName, 1, string.len(UnitName)-UnitSuffixLenght[unitID]) == Resurrectors[i] then
						scavResurrector[unitID] = true
					end
				end
				for i = 1,#ResurrectorsSea do
					if string.sub(UnitName, 1, string.len(UnitName)-UnitSuffixLenght[unitID]) == ResurrectorsSea[i] then
						scavResurrector[unitID] = true
					end
				end
			end

			if constructorControllerModuleConfig.usecollectors then
				for i = 1,#Collectors do
					if string.sub(UnitName, 1, string.len(UnitName)-UnitSuffixLenght[unitID]) == Collectors[i] then
						if math_random(0,100) <= 10 then
							scavCollector[unitID] = true
						else
							scavReclaimer[unitID] = true
						end
					end
				end
			end

			for i = 1,#AssistUnits do
				if string.sub(UnitName, 1, string.len(UnitName)-UnitSuffixLenght[unitID]) == AssistUnits[i] then
					scavAssistant[unitID] = true
				end
			end
		end

		if scavconfig.modules.factoryControllerModule then
			for i = 1,#Factories do
				if string.sub(UnitName, 1, string.len(UnitName)-UnitSuffixLenght[unitID]) == Factories[i] then
					scavFactory[unitID] = true
				end
			end
		end
	else
		--AliveEnemyCommanders
		for i = 1,#CommandersList do
			if string.sub(UnitName, 1, string.len(UnitName)) == CommandersList[i] then
				AliveEnemyCommandersCount = AliveEnemyCommandersCount + 1
				table.insert(AliveEnemyCommanders,unitID)
			end
		end
		if UnitDefs[unitDefID].name == "scavengerdroppodbeacon_scav" or UnitDefs[unitDefID].name == "scavsafeareabeacon_scav" then
			numOfSpawnBeaconsTeams[unitTeam] = numOfSpawnBeaconsTeams[unitTeam] + 1
			if scavconfig.modules.reinforcementsModule == true then
				Spring.SetUnitNeutral(unitID, false)
				Spring.SetUnitMaxHealth(unitID, 10000)
				Spring.SetUnitHealth(unitID, 10000)
			end
		end
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if unitTeam == GaiaTeamID then
		-- CMD.CLOAK = 37382
		local UnitName = UnitDefs[unitDefID].name
		if string.find(UnitName, scavconfig.unitnamesuffix) then
			UnitSuffixLenght[unitID] = string.len(scavconfig.unitnamesuffix)
		else
			UnitSuffixLenght[unitID] = 0
		end
		for i = 1,#WallUnitNames do
			if string.sub(UnitName, 1, string.len(UnitName)-UnitSuffixLenght[unitID]) == WallUnitNames[i] then
				Spring.SetUnitNeutral(unitID, false)
				break
			end
		end
		Spring.GiveOrderToUnit(unitID,37382,{1},0)
		-- Fire At Will
		if scavConstructor[unitID] then
			Spring.GiveOrderToUnit(unitID,CMD.FIRE_STATE,{1},0)
			Spring.GiveOrderToUnit(unitID,CMD.MOVE_STATE,{0},0)
		else
			Spring.GiveOrderToUnit(unitID,CMD.FIRE_STATE,{2},0)
			Spring.GiveOrderToUnit(unitID,CMD.MOVE_STATE,{2},0)
		end
	end
end

function gadget:UnitDamaged(unitID, unitDefID, unitTeam)
	if unitTeam == GaiaTeamID then
		local UnitName = UnitDefs[unitDefID].name
		for i = 1,#BossUnits do
			if string.sub(UnitName, 1, string.len(UnitName)) == BossUnits[i] then
				local n = Spring.GetGameFrame()
				if not lastMinionFrame then
					lastMinionFrame = n
				end
				if n > lastMinionFrame + math.ceil(unitSpawnerModuleConfig.FinalBossMinionsActive/(teamcount*spawnmultiplier)) and FinalBossUnitID then
					lastMinionFrame = n
					BossMinionsSpawn(n)
				end
			end
		end
	end
end
