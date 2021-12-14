if (not gadgetHandler:IsSyncedCode()) then
	return false
end

VFS.Include("luarules/gadgets/scavengers/API/init.lua")
VFS.Include("luarules/gadgets/scavengers/Configs/" .. Game.gameShortName .. "/config.lua")

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
VFS.Include("luarules/gadgets/scavengers/Modules/mastermind_controller.lua")
VFS.Include("luarules/gadgets/scavengers/Modules/unit_controller.lua")

local bossUnitList = VFS.Include("luarules/gadgets/scavengers/Configs/BYAR/UnitLists/boss.lua")
local constructorUnitList = VFS.Include("luarules/gadgets/scavengers/Configs/BYAR/UnitLists/constructors.lua")
local staticUnitList = VFS.Include("luarules/gadgets/scavengers/Configs/BYAR/UnitLists/staticunits.lua")

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

local constructorController = VFS.Include("luarules/gadgets/scavengers/Modules/constructor_controller.lua")
local randomEventsController = VFS.Include("luarules/gadgets/scavengers/Modules/random_events.lua")
local factoryController = VFS.Include("luarules/gadgets/scavengers/Modules/factory_controller.lua")

if scavconfig.modules.unitSpawnerModule then
	VFS.Include("luarules/gadgets/scavengers/Modules/unit_spawner.lua")
end

-- if scavconfig.modules.startBoxProtection then
-- 	VFS.Include("luarules/gadgets/scavengers/Modules/startbox_protection.lua")
-- end

if scavconfig.modules.reinforcementsModule then
	VFS.Include("luarules/gadgets/scavengers/Modules/reinforcements_module.lua")
end

if scavconfig.modules.stockpilers == true then
	VFS.Include("luarules/gadgets/scavengers/Modules/stockpiling.lua")
end

local nukeController = VFS.Include("luarules/gadgets/scavengers/Modules/nuke_controller.lua")

VFS.Include("luarules/gadgets/scavengers/Modules/spawn_beacons.lua")
VFS.Include("luarules/gadgets/scavengers/Modules/messenger.lua")
local bossController = VFS.Include("luarules/gadgets/scavengers/Modules/bossfight_module.lua")

local function DisableUnit(unitID)
	Spring.DestroyUnit(unitID, false, true)
	-- Spring.MoveCtrl.Enable(unitID)
	-- Spring.MoveCtrl.SetNoBlocking(unitID, true)
	-- Spring.MoveCtrl.SetPosition(unitID, Game.mapSizeX+1900, 2000, Game.mapSizeZ+1900) --don't move too far out or prevent_aicraft_hax will explode it!
	-- Spring.SetUnitNeutral(unitID, true)
	-- Spring.SetUnitCloak(unitID, true)
	-- --Spring.SetUnitHealth(unitID, {paralyze=99999999})
	-- Spring.SetUnitMaxHealth(unitID, 10000000)
	-- Spring.SetUnitHealth(unitID, 10000000)
	-- --Spring.SetUnitNoDraw(unitID, true)
	-- Spring.SetUnitStealth(unitID, true)
	-- --Spring.SetUnitNoSelect(unitID, true)
	-- Spring.SetUnitNoMinimap(unitID, true)
	-- Spring.GiveOrderToUnit(unitID, CMD.MOVE_STATE, { 0 }, 0)
	-- Spring.GiveOrderToUnit(unitID, CMD.FIRE_STATE, { 0 }, 0)
end

local function DisableCommander()
	local teamUnits = Spring.GetTeamUnits(scavengerAITeamID)
	for _, unitID in ipairs(teamUnits) do
		--HiddenCommander = unitID
		DisableUnit(unitID)
	end
end

function QueueSpawn(unitName, posx, posy, posz, facing, team, frame, blocking)
	if blocking == nil then blocking = true end
	if UnitDefNames[unitName] then
		local QueueSpawnCommand = {unitName, posx, posy, posz, facing, team, blocking,}
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
	blocking = nil
end

function SpawnFromQueue(n)
	local QueuedSpawnsForNow = #QueuedSpawns
	if QueuedSpawnsForNow > 0 then
		for i = 1,QueuedSpawnsForNow do
			if n == QueuedSpawnsFrames[1] then
				local createSpawnCommand = QueuedSpawns[1]
				local unit = Spring.CreateUnit(QueuedSpawns[1][1],QueuedSpawns[1][2],QueuedSpawns[1][3],QueuedSpawns[1][4],QueuedSpawns[1][5],QueuedSpawns[1][6])
				if QueuedSpawns[1][7] == false then
					Spring.SetUnitBlocking(unit, false, false, true)
				end
				Spring.SpawnCEG("scav-spawnexplo",QueuedSpawns[1][2],QueuedSpawns[1][3],QueuedSpawns[1][4],0,0,0)
				table.remove(QueuedSpawns, 1)
				table.remove(QueuedSpawnsFrames, 1)
			--else
				--break
			end
		end
	end
end

function DestroyOldBuildings()
	local unitCount = Spring.GetTeamUnitCount(GaiaTeamID)
	local unitCountBuffer = scavMaxUnits*0.05
	if unitCount + unitCountBuffer > scavMaxUnits then 
		for i = 1,((unitCount + unitCountBuffer)-scavMaxUnits) do
			if #BaseCleanupQueue > 0 then
				Spring.DestroyUnit(BaseCleanupQueue[1], true, false)
				table.remove(BaseCleanupQueue, 1)
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

function PutScavAlliesInScavTeam(n)
	local players = Spring.GetPlayerList()
	for i = 1,#players do
		local player = players[i]
		local name, active, spectator, teamID, allyTeamID = Spring.GetPlayerInfo(player)
		if allyTeamID == GaiaAllyTeamID and (not spectator) then
			Spring.AssignPlayerToTeam(player, GaiaTeamID)
			local units = Spring.GetTeamUnits(teamID)
			for u = 1,#units do
				scavteamhasplayers = true
				Spring.DestroyUnit(units[u], false, true)
				Spring.KillTeam(teamID)
			end
		end
	end

	local scavAllies = Spring.GetTeamList(GaiaAllyTeamID)
	for i = 1,#scavAllies do
		local _,_,_,AI = Spring.GetTeamInfo(scavAllies[i])
		local LuaAI = Spring.GetTeamLuaAI(scavAllies[i])
		if (AI or LuaAI) and scavAllies[i] ~= GaiaTeamID then
			local units = Spring.GetTeamUnits(scavAllies[i])
			for u = 1,#units do
				--scavteamhasplayers = true
				Spring.DestroyUnit(units[u], false, true)
				Spring.KillTeam(scavAllies[i])
			end
		end
	end
end

local minionFramerate = math.ceil(unitSpawnerModuleConfig.FinalBossMinionsPassive/(teamcount*spawnmultiplier))
function gadget:GameFrame(n)
	if n == 1 then
		-- PutSpectatorsInScavTeam(n)
		PutScavAlliesInScavTeam(n)
		teamsCheck()
		UpdateTierChances(n)
	end

	if n > 1 then
		SpawnFromQueue(n)
		DestroyOldBuildings()
	end

	if n%900 then
		MasterMindLandTargetsListUpdate(n)
		MasterMindSeaTargetsListUpdate(n)
		MasterMindAirTargetsListUpdate(n)
		MasterMindAmphibiousTargetsListUpdate(n)
	end

	if n == 300 then
		--Spring.Echo("New Scavenger Spawner initialized")
		Spring.SetTeamColor(GaiaTeamID, 0.38, 0.14, 0.38)
	end

	if n%30 == 0 and scavconfig.messenger == true then
		pregameMessages(n)
	end

	randomEventsController.GameFrame(n)

	if n%30 == 0 and FinalBossUnitSpawned and not FinalBossKilled then
		local currentbosshealth = Spring.GetUnitHealth(FinalBossUnitID)
		--local initialbosshealth = unitSpawnerModuleConfig.FinalBossHealth*teamcount*spawnmultiplier
		local bosshealthpercentage = math.floor(currentbosshealth/(initialbosshealth*0.01))
		ScavSendMessage("Boss Health: "..math.ceil(currentbosshealth).. " ("..bosshealthpercentage.."%)")

		bossController.UpdateFightPhase(bosshealthpercentage)
		bossController.ActivateAbility(n)
	end

	if n%10 == 0 and FinalBossUnitSpawned and not FinalBossKilled then
		bossController.ActivatePassiveAbilities(n)
	end

	if n%minionFramerate == 0 and FinalBossUnitSpawned and FinalBossKilled == false then
		BossMinionsSpawn(n)
	end

	if n%30 == 0 and scavconfig.modules.reinforcementsModule and FinalBossKilled == false then
		spawnPlayerReinforcements(n)
		CaptureBeacons(n)
		SetBeaconsResourceProduction(n)
		ReinforcementsMoveOrder(n)
	end

	if n%30 == 0 and GaiaTeamID ~= Spring.GetGaiaTeamID() then
		if not disabledCommander then
			DisableCommander()
			disabledCommander = true
		end
		--Spring.SetUnitHealth(HiddenCommander, 10000000)
	end

	if n == 100 and globalScore then
		if scavteamhasplayers == false then
			Spring.SetTeamResource(GaiaTeamID, "ms", 1000000)
			Spring.SetTeamResource(GaiaTeamID, "es", 1000000)
		end
		Spring.SetGlobalLos(GaiaAllyTeamID, false)
	end

	if n%30 == 0 and globalScore then
		if scavteamhasplayers == false then
			Spring.SetTeamResource(GaiaTeamID, "ms", 1000000)
			Spring.SetTeamResource(GaiaTeamID, "es", 1000000)
			Spring.SetTeamResource(GaiaTeamID, "m", 1000000)
			Spring.SetTeamResource(GaiaTeamID, "e", 1000000)
		end
		if BossWaveStarted == true then
			BossWaveTimer(n)
		end
		local scavUnits = Spring.GetTeamUnits(GaiaTeamID)
		local scavUnitsCount = #scavUnits
		if scavUnitsCount < (unitSpawnerModuleConfig.minimumspawnbeacons*4) and n > scavconfig.gracePeriod*3 then 
			killedscavengers = killedscavengers + 1000
			if BossWaveStarted and (BossWaveTimeLeft and BossWaveTimeLeft > 20) then
				BossWaveTimeLeft = 20
			end
		end
	end

	if n%900 == 0 and n > 100 and FinalBossKilled == false then
		teamsCheck()
		UpdateTierChances(n)
		if (BossWaveStarted == false) and globalScore > scavconfig.timers.BossFight and unitSpawnerModuleConfig.bossFightEnabled then
			BossWaveStarted = true
		elseif not FinalBossUnitSpawned and not BossWaveStarted then
			if scavengersAIEnabled and scavengersAIEnabled == true then
				if globalScore == 0 then globalScore = 1 end
				if scavconfig.timers.BossFight == 0 then scavconfig.timers.BossFight = 1 end
				if globalScore/scavconfig.timers.BossFight < 1 then
					ScavSendMessage("Scavengers Tech: "..math.ceil((globalScore/scavconfig.timers.BossFight)*100).."%")
					--ScavSendMessage("Scav Score: "..globalScore)
					ScavSendMessage(TierSpawnChances.Message)
				else
					ScavSendMessage("Scavengers Tech: 100%")
					--ScavSendMessage("Score: "..globalScore)
					ScavSendMessage(TierSpawnChances.Message)
				end
			end
		end
	end

	if n%90 == 0 and scavconfig.modules.buildingSpawnerModule and FinalBossKilled == false then --and (not FinalBossUnitSpawned) then
		SpawnBlueprint(n)
	end

	-- if n%(math.ceil(1800/spawnmultiplier)) == 0 and not scavteamhasplayers and scavengerGamePhase ~= "initial" and constructorControllerModuleConfig.useresurrectors and FinalBossKilled == false then
	-- 	constructorController.SpawnResurrectorGroup(n)
	-- end

	if n%30 == 0 then
		if n > scavconfig.gracePeriod and scavengerGamePhase == "initial" then
			scavengerGamePhase = "action"
		end
		if globalScore then
			collectScavStats()
		end
		if scavconfig.modules.unitSpawnerModule and FinalBossKilled == false then --and (not FinalBossUnitSpawned) then
			SpawnBeacon(n)
			UnitGroupSpawn(n)
		end
		if scavconfig.modules.constructorControllerModule and constructorControllerModuleConfig.useconstructors and scavengerGamePhase ~= "initial" then
			constructorController.SpawnConstructor(n)
		end
		local scavengerunits = Spring.GetTeamUnits(GaiaTeamID)
		if scavengerunits and scavengerGamePhase ~= "initial" then
			for _, scav in ipairs(scavengerunits) do
				local scavDef = Spring.GetUnitDefID(scav)
				local collectorRNG = math_random(0,2)
				local scavFirestate = Spring.GetUnitStates(scav)["firestate"]
				if (scavFirestate ~= 2) or (scavFirestate ~= 1 and scavengerGamePhase == "initial") then
					if scavengerGamePhase == "initial" then
						Spring.GiveOrderToUnit(scav,CMD.FIRE_STATE,{1},0)
					else
						Spring.GiveOrderToUnit(scav,CMD.FIRE_STATE,{2},0)
					end
					--Spring.Echo("Forced firestate of unitID: "..scav)
				end

				if n%300 == 0 and scavconfig.modules.stockpilers == true then
					if scavStockpiler[scav] == true then
						ScavStockpile(n, scav)
					end
				end

				if not scavteamhasplayers and scavconfig.modules.nukes then
					if scavNuke[scav] then
						nukeController.SendRandomNukeOrder(n, scav)
					end
				end

				if scavteamhasplayers == false and scavconfig.modules.constructorControllerModule then
					if constructorControllerModuleConfig.useconstructors then
						if scavConstructor[scav] then
							if Spring.GetCommandQueue(scav, 0) <= 0 then
								constructorController.ConstructNewBlueprint(n, scav)
							end
						end
					end

					if not scavteamhasplayers and constructorControllerModuleConfig.useresurrectors and collectorRNG == 0 then
						if scavResurrector[scav] then
							constructorController.ResurrectorOrders(n, scav)
						end
					end

					if not scavteamhasplayers and constructorControllerModuleConfig.usecollectors and collectorRNG == 0 then
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

				-- backup -- and not scavConstructor[scav] and not scavResurrector[scav] and not scavCollector[scav]
				if scavteamhasplayers == false and n%900 == 0 and not scavStructure[scav] and not scavAssistant[scav] and not scavFactory[scav] and not scavSpawnBeacon[scav] then
					SelfDestructionControls(n, scav, scavDef, false)
				end
				if scavteamhasplayers == false and Spring.GetCommandQueue(scav, 0) <= 1 and not scavStructure[scav] and not scavConstructor[scav] and not scavReclaimer[scav] and not scavResurrector[scav] and not scavAssistant[scav] and not scavCollector[scav] and not scavCapturer[scav] and not scavFactory[scav] and not scavSpawnBeacon[scav] then
					ArmyMoveOrders(n, scav, scavDef)
				end
			end
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	local unitName = UnitDefs[unitDefID].name
	if unitTeam ~= GaiaTeamID and unitEnteredTeam == GaiaTeamID then
		MasterMindTargetListTargetSpotted(unitID, unitTeam, unitEnteredTeam, unitDefID)
	end
	-- if unitName == "armassistdrone" or unitName == "corassistdrone" then
	-- 	constructorController.AssistDroneRespawn(unitID, unitName)
	-- end
	if unitTeam == GaiaTeamID then
		if scavengerGamePhase == "initial" and (not scavConverted[unitID]) then
			initialPhaseCountdown = initialPhaseCountdown + 1
		end
		scavStatsScavUnits = scavStatsScavUnits-1
		scavStatsScavUnitsKilled = scavStatsScavUnitsKilled+1

		if FinalBossUnitSpawned == true then
			for i = 1,#bossUnitList.Bosses do
				if unitName  == bossUnitList.Bosses[i] then
					FinalBossKilled = true
					FinalBossUnitID = nil
				end
			end
		end

		killedscavengers = killedscavengers + scavconfig.scoreConfig.baseScorePerKill
		if scavStructure[unitID] and not unitName == "scavengerdroppod_scav" and not unitName == "scavengerdroppodbeacon_scav"  then
			killedscavengers = killedscavengers + scavconfig.scoreConfig.scorePerKilledBuilding
		end
		if scavConstructor[unitID] then
			scavStatsScavCommanders = scavStatsScavCommanders-1
			killedscavengers = killedscavengers + scavconfig.scoreConfig.scorePerKilledConstructor
		end
		if unitName == "scavengerdroppodbeacon_scav" then
			scavStatsScavSpawners = scavStatsScavSpawners-1
			numOfSpawnBeacons = numOfSpawnBeacons - 1
			killedscavengers = killedscavengers + scavconfig.scoreConfig.scorePerKilledSpawner
		end
		if unitName == "scavengerdroppod_scav" then
			killedscavengers = killedscavengers - scavconfig.scoreConfig.baseScorePerKill
		end
		scavConverted[unitID] = nil
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
		scavCapturer[unitID] = nil
		scavReclaimer[unitID] = nil
		scavStructure[unitID] = nil
		scavFactory[unitID] = nil
		scavSpawnBeacon[unitID] = nil
		scavStockpiler[unitID] = nil
		scavNuke[unitID] = nil
		UnitSuffixLenght[unitID] = nil
		ConstructorNumberOfRetries[unitID] = nil
		CaptureProgressForBeacons[unitID] = nil
	else

		if #ActiveReinforcementUnits > 0 then
			for i = 1,#ActiveReinforcementUnits do
				if unitID == ActiveReinforcementUnits[i] then
					FriendlyCollectors[unitID] = nil
					FriendlyReclaimers[unitID] = nil
					FriendlyResurrectors[unitID] = nil
					UnitSuffixLenght[unitID] = nil
					selfdx[unitID] = nil
					selfdy[unitID] = nil
					selfdz[unitID] = nil
					oldselfdx[unitID] = nil
					oldselfdy[unitID] = nil
					oldselfdz[unitID] = nil
					table.remove(ActiveReinforcementUnits, i)
				end
			end
		end
		for i = 1,#AliveEnemyCommanders do
			local comID = AliveEnemyCommanders[i]
			if unitID == comID then
				AliveEnemyCommandersCount = AliveEnemyCommandersCount - 1
				table.remove(AliveEnemyCommanders, i)
				break
			end
		end
		if unitName == "scavengerdroppodbeacon_scav" then
			numOfSpawnBeaconsTeams[unitTeam] = numOfSpawnBeaconsTeams[unitTeam] - 1
		end
	end
end

function gadget:UnitGiven(unitID, unitDefID, unitNewTeam, unitOldTeam)
	local unitName = UnitDefs[unitDefID].name
	if unitNewTeam == GaiaTeamID and unitOldTeam ~= GaiaTeamID then
		MasterMindTargetListTargetGone(unitID, unitTeam, unitEnteredTeam, unitDefID)
	end
	if unitOldTeam == GaiaTeamID then
		scavStatsScavUnits = scavStatsScavUnits-1
		--AliveEnemyCommanders
		if constructorUnitList.PlayerCommandersID[unitDefID] then
			AliveEnemyCommandersCount = AliveEnemyCommandersCount + 1
			table.insert(AliveEnemyCommanders,unitID)
		end
		if UnitDefs[unitDefID].canMove == false or UnitDefs[unitDefID].isBuilding == true or (not scavNoSelfD[unitID]) then
			for i = 1,#BaseCleanupQueue do
				if unitID == BaseCleanupQueue[i] then
					table.remove(BaseCleanupQueue, i)
				end
			end
		end
		if UnitDefs[unitDefID].name == "scavengerdroppodbeacon_scav" then
			numOfSpawnBeacons = numOfSpawnBeacons - 1
			numOfSpawnBeaconsTeams[unitNewTeam] = numOfSpawnBeaconsTeams[unitNewTeam] + 1
			killedscavengers = killedscavengers + scavconfig.scoreConfig.scorePerCapturedSpawner
			if scavconfig.modules.reinforcementsModule == true then
				Spring.SetUnitNeutral(unitID, false)
				--Spring.SetUnitHealth(unitID, 10000)
				--Spring.SetUnitMaxHealth(unitID, 10000)
			end
			--SpawnDefencesAfterCapture(unitID, unitNewTeam)
		end

		if unitName == "corcom"..scavconfig.unitnamesuffix then
			local frame = Spring.GetGameFrame()
			local posx, posy, posz = Spring.GetUnitPosition(unitID)
			Spring.DestroyUnit(unitID, false, true)
			QueueSpawn("corcomcon"..scavconfig.unitnamesuffix, posx, posy, posz, 3 ,unitNewTeam, frame+1)
		end
		if unitName == "armcom"..scavconfig.unitnamesuffix then
			local frame = Spring.GetGameFrame()
			local posx, posy, posz = Spring.GetUnitPosition(unitID)
			Spring.DestroyUnit(unitID, false, true)
			QueueSpawn("armcomcon"..scavconfig.unitnamesuffix, posx, posy, posz, 3 ,unitNewTeam, frame+1)
		end
		
		if scavConstructor[unitID] then
			scavStatsScavCommanders = scavStatsScavCommanders-1
		end
		if unitName == "scavengerdroppodbeacon_scav" then
			scavStatsScavSpawners = scavStatsScavSpawners-1
		end
		scavConverted[unitID] = nil
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
		scavCapturer[unitID] = nil
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
			if scavengerGamePhase == "initial" and (not scavConverted[unitID]) then
				initialPhaseCountdown = initialPhaseCountdown + 1
			end
			scavStatsScavUnits = scavStatsScavUnits+1
			for i = 1,#AliveEnemyCommanders do
				local comID = AliveEnemyCommanders[i]
				if unitID == comID then
					AliveEnemyCommandersCount = AliveEnemyCommandersCount - 1
					table.remove(AliveEnemyCommanders, i)
					break
				end
			end
			if (UnitDefs[unitDefID].canMove == false or UnitDefs[unitDefID].isBuilding == true or scavNoSelfD[unitID]) and (unitName ~= "scavengerdroppodbeacon_scav") then
				BaseCleanupQueue[#BaseCleanupQueue+1] = unitID 
			end
			if string.find(unitName, scavconfig.unitnamesuffix) then
				UnitSuffixLenght[unitID] = string.len(scavconfig.unitnamesuffix)
			else
				UnitSuffixLenght[unitID] = 0
				local frame = Spring.GetGameFrame()
				if frame > 30 then
					local heading = Spring.GetUnitHeading(unitID)
					local suffix = scavconfig.unitnamesuffix
					-- Spring.Echo(UnitName)
					-- Spring.Echo(UnitName..suffix)
					if UnitDefNames[unitName..suffix] then
						local posx, posy, posz = Spring.GetUnitPosition(unitID)
						Spring.DestroyUnit(unitID, false, true)
						scavConverted[unitID] = true
						if heading >= -24576 and heading < -8192 then -- west
							-- 3
							QueueSpawn(unitName..suffix, posx, posy, posz, 3 ,GaiaTeamID, frame+1)
							--Spring.CreateUnit(UnitName..suffix, posx, posy, posz, 3,GaiaTeamID)
						elseif heading >= -8192 and heading < 8192 then -- south
							-- 0
							QueueSpawn(unitName..suffix, posx, posy, posz, 0 ,GaiaTeamID, frame+1)
							--Spring.CreateUnit(UnitName..suffix, posx, posy, posz, 0,GaiaTeamID)
						elseif heading >= 8192 and heading < 24576 then -- east
							-- 1
							QueueSpawn(unitName..suffix, posx, posy, posz, 1 ,GaiaTeamID, frame+1)
							--Spring.CreateUnit(UnitName..suffix, posx, posy, posz, 1,GaiaTeamID)
						else -- north
							-- 2
							QueueSpawn(unitName..suffix, posx, posy, posz, 2 ,GaiaTeamID, frame+1)
							--Spring.CreateUnit(UnitName..suffix, posx, posy, posz, 2,GaiaTeamID)
						end
						return
					end
				end
			end
			--Spring.Echo("Scavs just captured me " .. UnitName .. " and my suffix lenght is " .. UnitSuffixLenght[unitID])
			if UnitDefs[unitDefID].name == "scavengerdroppodbeacon_scav" then
				scavStatsScavSpawners = scavStatsScavSpawners + 1
				numOfSpawnBeaconsTeams[unitOldTeam] = numOfSpawnBeaconsTeams[unitOldTeam] - 1
				numOfSpawnBeacons = numOfSpawnBeacons + 1
				scavSpawnBeacon[unitID] = true
			end
			if unitName == "corcomcon"..scavconfig.unitnamesuffix then
				local frame = Spring.GetGameFrame()
				local posx, posy, posz = Spring.GetUnitPosition(unitID)
				Spring.DestroyUnit(unitID, false, true)
				scavConverted[unitID] = true
				QueueSpawn("corcom"..scavconfig.unitnamesuffix, posx, posy, posz, 3 ,GaiaTeamID, frame+1)
				return
			end
			if unitName == "armcomcon"..scavconfig.unitnamesuffix then
				local frame = Spring.GetGameFrame()
				local posx, posy, posz = Spring.GetUnitPosition(unitID)
				Spring.DestroyUnit(unitID, false, true)
				scavConverted[unitID] = true
				QueueSpawn("armcom"..scavconfig.unitnamesuffix, posx, posy, posz, 3 ,GaiaTeamID, frame+1)
				return
			end
			-- CMD.CLOAK = 37382
			Spring.GiveOrderToUnit(unitID,37382,{1},0)
			-- Fire At Will
			if scavengerGamePhase == "initial" then
				Spring.GiveOrderToUnit(unitID,CMD.FIRE_STATE,{1},0)
			else
				Spring.GiveOrderToUnit(unitID,CMD.FIRE_STATE,{2},0)
			end
			scavStructure[unitID] = UnitDefs[unitDefID].isBuilding
			if staticUnitList.NoSelfDestructID[unitDefID] then
				scavStructure[unitID] = true
			end


			if scavconfig.modules.stockpilers == true then
				if staticUnitList.StockpilersID[unitDefID] then
					scavStockpiler[unitID] = true
				end
			end

			if scavconfig.modules.nukes == true then
				if staticUnitList.NukesID[unitDefID] then
					scavNuke[unitID] = true
				end
			end

			if scavconfig.modules.constructorControllerModule then
				if constructorControllerModuleConfig.useconstructors then
					if constructorUnitList.ConstructorsID[unitDefID] then
						scavStatsScavCommanders = scavStatsScavCommanders+1
						scavConstructor[unitID] = true
						buffConstructorBuildSpeed(unitID)
					end
				end

				if constructorControllerModuleConfig.useresurrectors then
					if constructorUnitList.ResurrectorsID[unitDefID] then
						buffConstructorBuildSpeed(unitID)
						scavResurrector[unitID] = true
					end

					if constructorUnitList.ResurrectorsSeaID[unitDefID] then
						buffConstructorBuildSpeed(unitID)
						scavResurrector[unitID] = true
					end
				end

				if constructorControllerModuleConfig.usecollectors then
					if constructorUnitList.CollectorsID[unitDefID] then
						buffConstructorBuildSpeed(unitID)
						local r = math_random(0, 100)
						if scavengerGamePhase == "initial" or r <= 10 then
							scavCollector[unitID] = true
						-- elseif r <= 50 then
						-- 	scavCapturer[unitID] = true
						else
							scavReclaimer[unitID] = true
						end
					end
				end

				if constructorUnitList.AssistersID[unitDefID] then
					scavAssistant[unitID] = true
				end
			end

			factoryController.CheckNewUnit(unitID, unitDefID)
		elseif UnitDefs[unitDefID].name == "scavengerdroppodbeacon_scav" then
			numOfSpawnBeaconsTeams[unitOldTeam] = numOfSpawnBeaconsTeams[unitOldTeam] - 1
			numOfSpawnBeaconsTeams[unitNewTeam] = numOfSpawnBeaconsTeams[unitNewTeam] + 1
		end
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	local unitName = UnitDefs[unitDefID].name
	--Spring.Echo(Spring.GetUnitHeading(unitID))
	if unitName == "scavengerdroppodfriendly" then
		Spring.GiveOrderToUnit(unitID, CMD.SELFD,{}, {"shift"})
	end
	if unitTeam == GaiaTeamID then
		scavStatsScavUnits = scavStatsScavUnits+1
		if (UnitDefs[unitDefID].canMove == false or UnitDefs[unitDefID].isBuilding == true or scavNoSelfD[unitID]) and (unitName ~= "scavengerdroppodbeacon_scav") then
			BaseCleanupQueue[#BaseCleanupQueue+1] = unitID 
		end
		Spring.SetUnitExperience(unitID, math_random() * (spawnmultiplier*0.01*unitControllerModuleConfig.veterancymultiplier))
		if string.find(unitName, scavconfig.unitnamesuffix) then
			UnitSuffixLenght[unitID] = string.len(scavconfig.unitnamesuffix)
		else
			UnitSuffixLenght[unitID] = 0
			local frame = Spring.GetGameFrame()
			if frame > 30 then
				local heading = Spring.GetUnitHeading(unitID)
				local suffix = scavconfig.unitnamesuffix
				-- Spring.Echo(UnitName)
				-- Spring.Echo(UnitName..suffix)
				if UnitDefNames[unitName..suffix] then
					local posx, posy, posz = Spring.GetUnitPosition(unitID)
					Spring.DestroyUnit(unitID, false, true)
					scavConverted[unitID] = true
					if heading >= -24576 and heading < -8192 then -- west
						-- 3
						QueueSpawn(unitName..suffix, posx, posy, posz, 3 ,GaiaTeamID, frame+1)
						--Spring.CreateUnit(UnitName..suffix, posx, posy, posz, 3,GaiaTeamID)
					elseif heading >= -8192 and heading < 8192 then -- south
						-- 0
						QueueSpawn(unitName..suffix, posx, posy, posz, 0 ,GaiaTeamID, frame+1)
						--Spring.CreateUnit(UnitName..suffix, posx, posy, posz, 0,GaiaTeamID)
					elseif heading >= 8192 and heading < 24576 then -- east
						-- 1
						QueueSpawn(unitName..suffix, posx, posy, posz, 1 ,GaiaTeamID, frame+1)
						--Spring.CreateUnit(UnitName..suffix, posx, posy, posz, 1,GaiaTeamID)
					else -- north
						-- 2
						QueueSpawn(unitName..suffix, posx, posy, posz, 2 ,GaiaTeamID, frame+1)
						--Spring.CreateUnit(UnitName..suffix, posx, posy, posz, 2,GaiaTeamID)
					end
					return
				end
			end
		end
		for i = 1,#bossUnitList.Bosses do
			if unitName == bossUnitList.Bosses[i] then
				FinalBossUnitID = unitID
				Spring.SetUnitArmored(unitID, true , 1/(spawnmultiplier*3))
				initialbosshealth = Spring.GetUnitHealth(unitID)

				local stopScavUnits = Spring.GetTeamUnits(GaiaTeamID)
				for y = 1,#stopScavUnits do
					local unitID = stopScavUnits[y]							
					Spring.GiveOrderToUnit(unitID, CMD.STOP, 0, 0)
				end
				
			end
		end
		if unitName == "corcomcon"..scavconfig.unitnamesuffix then
			local frame = Spring.GetGameFrame()
			local posx, posy, posz = Spring.GetUnitPosition(unitID)
			Spring.DestroyUnit(unitID, false, true)
			scavConverted[unitID] = true
			QueueSpawn("corcom"..scavconfig.unitnamesuffix, posx, posy, posz, 3 ,unitTeam, frame+1)
		end
		if unitName == "armcomcon"..scavconfig.unitnamesuffix then
			local frame = Spring.GetGameFrame()
			local posx, posy, posz = Spring.GetUnitPosition(unitID)
			Spring.DestroyUnit(unitID, false, true)
			scavConverted[unitID] = true
			QueueSpawn("armcom"..scavconfig.unitnamesuffix, posx, posy, posz, 3 ,unitTeam, frame+1)
		end
		if unitName == "scavengerdroppod_scav" then
			Spring.GiveOrderToUnit(unitID, CMD.SELFD,{}, {"shift"})
		end
		if unitName == "scavengerdroppodbeacon_scav" then
			scavStatsScavSpawners = scavStatsScavSpawners+1
			scavSpawnBeacon[unitID] = true
			numOfSpawnBeacons = numOfSpawnBeacons + 1
			if scavconfig.modules.reinforcementsModule == true then
				Spring.SetUnitNeutral(unitID, true)
				--Spring.SetUnitMaxHealth(unitID, 100000)
				--Spring.SetUnitHealth(unitID, 100000)
			end
		end
		-- if UnitName == "lootboxgold" then //perhaps add this later when lootboxes are fully implemented
		-- 	Spring.SetUnitNeutral(unitID, true)
		-- end

		-- CMD.CLOAK = 37382
		Spring.GiveOrderToUnit(unitID,37382,{1},0)
		-- Fire At Will
		if scavengerGamePhase == "initial" then
			Spring.GiveOrderToUnit(unitID,CMD.FIRE_STATE,{1},0)
		else
			Spring.GiveOrderToUnit(unitID,CMD.FIRE_STATE,{2},0)
		end
		scavStructure[unitID] = UnitDefs[unitDefID].isBuilding
		if staticUnitList.NoSelfDestructID[unitDefID] then
			scavStructure[unitID] = true
		end

		if scavconfig.modules.stockpilers == true then
			if staticUnitList.StockpilersID[unitDefID] then
				scavStockpiler[unitID] = true
			end
		end

		if scavconfig.modules.nukes == true then
			if staticUnitList.NukesID[unitDefID] then
				scavNuke[unitID] = true
			end
		end

		if scavconfig.modules.constructorControllerModule then
			if constructorControllerModuleConfig.useconstructors then
				if constructorUnitList.ConstructorsID[unitDefID] then
					scavStatsScavCommanders = scavStatsScavCommanders+1
					scavConstructor[unitID] = true
					buffConstructorBuildSpeed(unitID)
				end
			end

			if constructorControllerModuleConfig.useresurrectors then
				if constructorUnitList.ResurrectorsID[unitDefID] then
					scavResurrector[unitID] = true
					buffConstructorBuildSpeed(unitID)
				end

				if constructorUnitList.ResurrectorsSeaID[unitDefID] then
					scavResurrector[unitID] = true
					buffConstructorBuildSpeed(unitID)
				end
			end

			if constructorControllerModuleConfig.usecollectors then
				if constructorUnitList.CollectorsID[unitDefID] then
					buffConstructorBuildSpeed(unitID)
					local r = math_random(0,100)
					if scavengerGamePhase == "initial" or r <= 10 then
						scavCollector[unitID] = true
					-- elseif r <= 75 then
					-- 	scavCapturer[unitID] = true
					else
						scavReclaimer[unitID] = true
					end
				end
			end

			if constructorUnitList.AssistersID[unitDefID] then
				buffConstructorBuildSpeed(unitID)
				scavAssistant[unitID] = true
			end
		end

		factoryController.CheckNewUnit(unitID, unitDefID)
	else
		--AliveEnemyCommanders
		if constructorUnitList.PlayerCommandersID[unitDefID] then
			AliveEnemyCommandersCount = AliveEnemyCommandersCount + 1
			table.insert(AliveEnemyCommanders,unitID)
		end

		if unitName == "corcom"..scavconfig.unitnamesuffix then
			local frame = Spring.GetGameFrame()
			local posx, posy, posz = Spring.GetUnitPosition(unitID)
			Spring.DestroyUnit(unitID, false, true)
			QueueSpawn("corcomcon"..scavconfig.unitnamesuffix, posx, posy, posz, 3 ,unitTeam, frame+1)
		end
		if unitName == "armcom"..scavconfig.unitnamesuffix then
			local frame = Spring.GetGameFrame()
			local posx, posy, posz = Spring.GetUnitPosition(unitID)
			Spring.DestroyUnit(unitID, false, true)
			QueueSpawn("armcomcon"..scavconfig.unitnamesuffix, posx, posy, posz, 3 ,unitTeam, frame+1)
		end
		if UnitDefs[unitDefID].name == "scavengerdroppodbeacon_scav" then
			numOfSpawnBeaconsTeams[unitTeam] = numOfSpawnBeaconsTeams[unitTeam] + 1
			if scavconfig.modules.reinforcementsModule == true then
				Spring.SetUnitNeutral(unitID, false)
				--Spring.SetUnitMaxHealth(unitID, 10000)
				--Spring.SetUnitHealth(unitID, 10000)
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

		-- if staticUnitList.WallsID[unitDefID] then
		-- 	Spring.SetUnitNeutral(unitID, false)
		-- end

		Spring.GiveOrderToUnit(unitID,37382,{1},0)
		-- Fire At Will
		if scavConstructor[unitID] then
			if scavengerGamePhase == "initial" then
				Spring.GiveOrderToUnit(unitID,CMD.FIRE_STATE,{1},0)
			else
				Spring.GiveOrderToUnit(unitID,CMD.FIRE_STATE,{2},0)
			end
			if scavteamhasplayers == false then
				Spring.GiveOrderToUnit(unitID,CMD.MOVE_STATE,{0},0)
			end
		else
			if scavengerGamePhase == "initial" then
				Spring.GiveOrderToUnit(unitID,CMD.FIRE_STATE,{1},0)
			else
				Spring.GiveOrderToUnit(unitID,CMD.FIRE_STATE,{2},0)
			end
			if scavteamhasplayers == false then
				Spring.GiveOrderToUnit(unitID,CMD.MOVE_STATE,{2},0)
			end
		end
	end
end

function gadget:UnitDamaged(unitID, unitDefID, unitTeam)
	if unitTeam == GaiaTeamID then
		local unitName = UnitDefs[unitDefID].name
		for i = 1,#bossUnitList.Bosses do
			if unitName == bossUnitList.Bosses[i] then
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

function gadget:UnitEnteredLos(unitID, unitTeam, allyTeam, unitDefID)
	if unitTeam ~= GaiaTeamID and allyTeam == GaiaTeamID then
		MasterMindTargetListTargetSpotted(unitID, unitTeam, unitEnteredTeam, unitDefID)
	end
end

function gadget:UnitLeftLos(unitID, unitTeam, allyTeam, unitDefID)
	if unitTeam ~= GaiaTeamID and allyTeam == GaiaTeamID then
		if UnitDefs[unitDefID].canMove == true then
			MasterMindTargetListTargetGone(unitID, unitTeam, unitEnteredTeam, unitDefID)
		end
	end
end
