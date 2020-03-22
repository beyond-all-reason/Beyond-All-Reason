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

VFS.Include("luarules/gadgets/scavengers/Modules/spawn_beacons.lua")
VFS.Include("luarules/gadgets/scavengers/Modules/messenger.lua")

local function DisableUnit(unitID)
	Spring.MoveCtrl.Enable(unitID)
	Spring.MoveCtrl.SetNoBlocking(unitID, true)
	Spring.MoveCtrl.SetPosition(unitID, Game.mapSizeX+500, 2000, Game.mapSizeZ+500) --don't move too far out or prevent_aicraft_hax will explode it!
	Spring.SetUnitCloak(unitID, true)
	Spring.SetUnitHealth(unitID, {paralyze=99999999})
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
		DisableUnit(unitID)
	end
end

function QueueSpawn(unitName, posx, posy, posz, facing, team, frame)
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
end

function SpawnFromQueue(n)
	local QueuedSpawnsForNow = #QueuedSpawns
	if QueuedSpawnsForNow > 0 then
		for i = 1,QueuedSpawnsForNow do
			if n == QueuedSpawnsFrames[1] then
				local createSpawnCommand = QueuedSpawns[1]
				Spring.CreateUnit(QueuedSpawns[1][1],QueuedSpawns[1][2],QueuedSpawns[1][3],QueuedSpawns[1][4],QueuedSpawns[1][5],QueuedSpawns[1][6])
				table.remove(QueuedSpawns, 1)
				table.remove(QueuedSpawnsFrames, 1)
			else
				break
			end
		end
	end
end

local CaptureProgressForBeacons = {}
function CaptureBeacons(n)
	local scavengerunits = Spring.GetTeamUnits(GaiaTeamID)
	local spGetUnitTeam = Spring.GetUnitTeam
	
	for i = 1,#scavengerunits do
		local scav = scavengerunits[i]
		local scavDef = Spring.GetUnitDefID(scav)
		if scavSpawnBeacon[scav] then
			if not CaptureProgressForBeacons[scav] then
				CaptureProgressForBeacons[scav] = 0
				Spring.SetUnitHealth(scav, {capture = CaptureProgressForBeacons[scav]})
			end
			local posx,posy,posz = Spring.GetUnitPosition(scav)
			local unitsAround = Spring.GetUnitsInCylinder(posx, posz, 256)
			CapturingUnits = {}
			CapturingUnitsTeam = {}
			CapturingUnitsTeamTest = {}
			local TeamsCapturing = 0
			CapturingUnits[scav] = 0
			
			for j = 1,#unitsAround do
				local unitID = unitsAround[j]
				local unitTeamID = spGetUnitTeam(unitID)
				local unitAllyTeam = Spring.GetUnitAllyTeam(unitID)
				local LuaAI = Spring.GetTeamLuaAI(unitTeamID)
				local _,_,_,isAI,_,_ = Spring.GetTeamInfo(unitTeamID)
				if (not LuaAI) and unitTeamID ~= GaiaTeamID and unitTeamID ~= Spring.GetGaiaTeamID() and (not isAI) then
					captureraiTeam = false
				else
					captureraiTeam = true
				end
				if not CapturingUnitsTeamTest[unitAllyTeam] then
					CapturingUnitsTeamTest[unitAllyTeam] = true
					if unitTeamID ~= GaiaTeamID and captureraiTeam == false then
						TeamsCapturing = TeamsCapturing + 1
						if TeamsCapturing > 1 then
							break
						end
					end
				end
				captureraiTeam = nil
			end
			
			for j = 1,#unitsAround do
				local unitID = unitsAround[j]
				local unitTeamID = spGetUnitTeam(unitID)
				if not CapturingUnitsTeam[unitTeamID] then
					CapturingUnitsTeam[unitTeamID] = 0
				end
				local unitDefID = Spring.GetUnitDefID(unitID)
				local LuaAI = Spring.GetTeamLuaAI(unitTeamID)
				local _,_,_,isAI,_,_ = Spring.GetTeamInfo(unitTeamID)
				
				if (not LuaAI) and unitTeamID ~= GaiaTeamID and unitTeamID ~= Spring.GetGaiaTeamID() and (not isAI) then
					captureraiTeam = false
				else
					captureraiTeam = true
				end

				if not CapturingUnitsTeam[unitTeamID] then
					CapturingUnitsTeam[unitTeamID] = 0
				end
				
				for k = 1,#BeaconCaptureExcludedUnits do
					if UnitDefs[unitDefID].name == BeaconCaptureExcludedUnits[k] then
						IsUnitExcluded = true
						break
					else
						IsUnitExcluded = false
					end
				end
				
				if unitDefID == scavDef then
					CaptureProgressForBeacons[scav] = CaptureProgressForBeacons[scav] - 0.0005
				elseif unitTeamID == GaiaTeamID and (not unitTeamID == scavDef) then
					CaptureProgressForBeacons[scav] = CaptureProgressForBeacons[scav] - 1
				elseif captureraiTeam == false and unitTeamID ~= GaiaTeamID and unitTeamID ~= Spring.GetGaiaTeamID() and IsUnitExcluded == false and (not UnitDefs[unitDefID].canFly) then
					CaptureProgressForBeacons[scav] = CaptureProgressForBeacons[scav] + 0.001
					CapturingUnitsTeam[unitTeamID] = CapturingUnitsTeam[unitTeamID] + 1
				end
				if CaptureProgressForBeacons[scav] < 0 then
					CaptureProgressForBeacons[scav] = 0
				end
				if CaptureProgressForBeacons[scav] > 1 then
					CaptureProgressForBeacons[scav] = 1
				end
				Spring.SetUnitHealth(scav, {capture = CaptureProgressForBeacons[scav]})
				
				if TeamsCapturing < 2 and captureraiTeam == false and CaptureProgressForBeacons[scav] >= 1 then
					CaptureProgressForBeacons[scav] = 0
					Spring.SetUnitHealth(scav, {capture = 0})
					Spring.TransferUnit(scav, unitTeamID, true)
					captureraiTeam = nil
					break
				end
				captureraiTeam = nil
				IsUnitExcluded = nil
			end
			CapturingUnits = nil
			CapturingUnitsTeam = nil
		end
	end
end

function SetBeaconsResourceProduction(n)
	if globalScore then
		local units = Spring.GetAllUnits()
		local minutes = math.ceil(Spring.GetGameSeconds()/300)
		local beaconmetalproduction = minutes
		local beaconenergyproduction = beaconmetalproduction*20
		for i = 1,#units do
			local unitID = units[i]
			local unitDefID = Spring.GetUnitDefID(unitID)
			local name = UnitDefs[unitDefID].name
			if name ==	"scavengerdroppodbeacon_scav" then
				--Spring.AddUnitResource(unitID, "m", beaconmetalproduction)
				Spring.AddUnitResource(unitID, "e", beaconenergyproduction)
			end
		end
	end
end

function gadget:GameFrame(n)


	
	if n > 1 then
		SpawnFromQueue(n)
	end

	if n == 1 then
		Spring.Echo("New Scavenger Spawner initialized")
		Spring.SetTeamColor(GaiaTeamID, 0.38, 0.14, 0.38)
	end

	if scavconfig.messenger == true and n%30 == 0 then
		pregameMessages(n)
	end

	if scavconfig.modules.startBoxProtection == true and ScavengerStartboxExists == true and n%30 == 0 then
		spawnStartBoxProtection(n)
	end

	if n%30 == 0 and scavconfig.modules.reinforcementsModule then
		spawnPlayerReinforcements(n)
	end

	if n == 15 and GaiaTeamID ~= Spring.GetGaiaTeamID() then
		DisableCommander()
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
	end
	if n%1800 == 0 and n > 100 then
		teamsCheck()
		UpdateTierChances(n)
		if (BossWaveStarted == false) and globalScore > scavconfig.timers.BossFight and unitSpawnerModuleConfig.bossFightEnabled then
			BossWaveStarted = true
		else
			if scavengersAIEnabled and scavengersAIEnabled == true then
				ScavSendMessage("Scavengers Progress: "..math.ceil((globalScore/scavconfig.timers.BossFight)*100).."%, Score: "..globalScore)
			end
		end
	end

	if n%90 == 0 and scavconfig.modules.buildingSpawnerModule then
		SpawnBlueprint(n)
	end
	if n%30 == 0 and scavconfig.modules.unitSpawnerModule then
		if scavconfig.modules.unitSpawnerModule then
			SpawnBeacon(n)
			UnitGroupSpawn(n)
			CaptureBeacons(n)
			SetBeaconsResourceProduction(n)
		end
		if scavconfig.modules.constructorControllerModule and constructorControllerModuleConfig.useconstructors and n > 9000 then
			SpawnConstructor(n)
		end
		local scavengerunits = Spring.GetTeamUnits(GaiaTeamID)
		if scavengerunits then
			for i = 1,#scavengerunits do
				local scav = scavengerunits[i]
				local scavDef = Spring.GetUnitDefID(scav)
				local collectorRNG = math_random(0,5)

				if scavconfig.modules.constructorControllerModule then
					if constructorControllerModuleConfig.useconstructors then
						if scavConstructor[scav] and Spring.GetCommandQueue(scav, 0) <= 0 then
							ConstructNewBlueprint(n, scav)
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

				if n%900 == 0 and not scavStructure[scav] and not scavConstructor[scav] and not scavResurrector[scav] and not scavAssistant[scav] and not scavCollector[scav] and not scavFactory[scav] and not scavSpawnBeacon[scav] then
					SelfDestructionControls(n, scav, scavDef)
				end
				if Spring.GetCommandQueue(scav, 0) <= 1 and not scavStructure[scav] and not scavConstructor[scav] and not scavResurrector[scav] and not scavAssistant[scav] and not scavCollector[scav] and not scavFactory[scav] and not scavSpawnBeacon[scav] then
					ArmyMoveOrders(n, scav, scavDef)
				end

			end
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	if unitTeam == GaiaTeamID then
		killedscavengers = killedscavengers + 1
		if scavStructure[unitID] and not UnitDefs[unitDefID].name == "scavengerdroppod_scav" and not UnitDefs[unitDefID].name == "scavengerdroppodbeacon_scav"  then
			killedscavengers = killedscavengers + 4
		end
		if scavConstructor[unitID] then
			killedscavengers = killedscavengers + 99
		end
		if UnitDefs[unitDefID].name == "scavengerdroppodbeacon_scav" then
			numOfSpawnBeacons = numOfSpawnBeacons - 1
			killedscavengers = killedscavengers - 1
		end
		if UnitDefs[unitDefID].name == "scavengerdroppod_scav" then
			killedscavengers = killedscavengers - 1
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
		scavStructure[unitID] = nil
		scavFactory[unitID] = nil
		scavSpawnBeacon[unitID] = nil
		UnitSuffixLenght[unitID] = nil
		ConstructorNumberOfRetries[unitID] = nil
		CaptureProgressForBeacons[unitID] = nil
	else
		if UnitDefs[unitDefID].name == "scavengerdroppodbeacon_scav" then
			numOfSpawnBeaconsTeams[unitTeam] = numOfSpawnBeaconsTeams[unitTeam] - 1
		end
	end
end

function SpawnDefencesAfterCapture(unitID, teamID)
	local spawnTier = math_random(1,100)
	if spawnTier <= TierSpawnChances.T0 then
		grouptier = BeaconDefenceStructuresT0
	elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 then
		grouptier = BeaconDefenceStructuresT1
	elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 then
		grouptier = BeaconDefenceStructuresT2
	elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 + TierSpawnChances.T4 then
		grouptier = BeaconDefenceStructuresT3
	end
	if spawnTier <= TierSpawnChances.T0 then
		grouptiersea = StartboxDefenceStructuresT0Sea
	elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 then
		grouptiersea = StartboxDefenceStructuresT1Sea
	elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 then
		grouptiersea = StartboxDefenceStructuresT2Sea
	elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 + TierSpawnChances.T4 then
		grouptiersea = StartboxDefenceStructuresT3Sea
	end
	
	local posx,posy,posz = Spring.GetUnitPosition(unitID)
	local posy = Spring.GetGroundHeight(posx, posz)
	local n = Spring.GetGameFrame()
	
	local r = grouptier[math_random(1,#grouptier)]
	local r2 = grouptiersea[math_random(1,#grouptiersea)]
	Spring.CreateUnit("scavengerdroppodfriendly", posx-128, posy, posz-128, math_random(0,3),teamID)
	local posy = Spring.GetGroundHeight(posx-128, posz-128)
	if posy > 0 then
		QueueSpawn(r..scavconfig.unitnamesuffix, posx-128, posy, posz-128, math_random(0,3),teamID, n+90)
	else
		QueueSpawn(r2..scavconfig.unitnamesuffix, posx-128, posy, posz-128, math_random(0,3),teamID, n+90)
	end
	
	local r = grouptier[math_random(1,#grouptier)]
	local r2 = grouptiersea[math_random(1,#grouptiersea)]
	Spring.CreateUnit("scavengerdroppodfriendly", posx+128, posy, posz+128, math_random(0,3),teamID)
	local posy = Spring.GetGroundHeight(posx+128, posz+128)
	if posy > 0 then
		QueueSpawn(r..scavconfig.unitnamesuffix, posx+128, posy, posz+128, math_random(0,3),teamID, n+90)
	else
		QueueSpawn(r2..scavconfig.unitnamesuffix, posx+128, posy, posz+128, math_random(0,3),teamID, n+90)
	end
	
	local r = grouptier[math_random(1,#grouptier)]
	local r2 = grouptiersea[math_random(1,#grouptiersea)]
	Spring.CreateUnit("scavengerdroppodfriendly", posx-128, posy, posz+128, math_random(0,3),teamID)
	local posy = Spring.GetGroundHeight(posx-128, posz+128)
	if posy > 0 then
		QueueSpawn(r..scavconfig.unitnamesuffix, posx-128, posy, posz+128, math_random(0,3),teamID, n+90)
	else
		QueueSpawn(r2..scavconfig.unitnamesuffix, posx-128, posy, posz+128, math_random(0,3),teamID, n+90)
	end
	
	local r = grouptier[math_random(1,#grouptier)]
	local r2 = grouptiersea[math_random(1,#grouptiersea)]
	Spring.CreateUnit("scavengerdroppodfriendly", posx+128, posy, posz-128, math_random(0,3),teamID)
	local posy = Spring.GetGroundHeight(posx+128, posz-128)
	if posy > 0 then
		QueueSpawn(r..scavconfig.unitnamesuffix, posx+128, posy, posz-128, math_random(0,3),teamID, n+90)
	else
		QueueSpawn(r2..scavconfig.unitnamesuffix, posx+128, posy, posz-128, math_random(0,3),teamID, n+90)
	end
	
	grouptier = nil
	grouptiersea = nil
end

function gadget:UnitTaken(unitID, unitDefID, unitOldTeam, unitNewTeam)
	if unitOldTeam == GaiaTeamID then
		if UnitDefs[unitDefID].name == "scavengerdroppodbeacon_scav" then
			numOfSpawnBeacons = numOfSpawnBeacons - 1
			numOfSpawnBeaconsTeams[unitNewTeam] = numOfSpawnBeaconsTeams[unitNewTeam] + 1
			killedscavengers = killedscavengers + 50
			Spring.SetUnitNeutral(unitID, false)
			Spring.SetUnitHealth(unitID, 10000)
			Spring.SetUnitMaxHealth(unitID, 10000)
			SpawnDefencesAfterCapture(unitID, unitNewTeam)
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
		scavStructure[unitID] = nil
		scavFactory[unitID] = nil
		scavSpawnBeacon[unitID] = nil
		UnitSuffixLenght[unitID] = nil
		ConstructorNumberOfRetries[unitID] = nil
		CaptureProgressForBeacons[unitID] = nil
		Spring.SetUnitHealth(unitID, {capture = 0})
		
	else
		if UnitDefs[unitDefID].name == "scavengerdroppodbeacon_scav" then
			numOfSpawnBeaconsTeams[unitOldTeam] = numOfSpawnBeaconsTeams[unitOldTeam] - 1
			numOfSpawnBeaconsTeams[unitNewTeam] = numOfSpawnBeaconsTeams[unitNewTeam] + 1
		end
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	local UnitName = UnitDefs[unitDefID].name
	if UnitName == "scavengerdroppodfriendly" then
		Spring.GiveOrderToUnit(unitID, CMD.SELFD,{}, {"shift"})
	end
	if unitTeam == GaiaTeamID then
		
		if string.find(UnitName, "_scav") then
			UnitSuffixLenght[unitID] = string.len(scavconfig.unitnamesuffix)
		else
			UnitSuffixLenght[unitID] = 0
		end
		if UnitName == "scavengerdroppod_scav" then
			Spring.GiveOrderToUnit(unitID, CMD.SELFD,{}, {"shift"})
		end
		if UnitName == "scavengerdroppodbeacon_scav" then
			scavSpawnBeacon[unitID] = true
			numOfSpawnBeacons = numOfSpawnBeacons + 1
			Spring.SetUnitNeutral(unitID, true)
			Spring.SetUnitMaxHealth(unitID, 100000)
			Spring.SetUnitHealth(unitID, 100000)
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
						scavCollector[unitID] = true
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
		if UnitDefs[unitDefID].name == "scavengerdroppodbeacon_scav" then
			numOfSpawnBeaconsTeams[unitTeam] = numOfSpawnBeaconsTeams[unitTeam] + 1
			Spring.SetUnitNeutral(unitID, false)
			Spring.SetUnitMaxHealth(unitID, 10000)
			Spring.SetUnitHealth(unitID, 10000)
		end
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if unitTeam == GaiaTeamID then
		-- CMD.CLOAK = 37382
		Spring.GiveOrderToUnit(unitID,37382,{1},0)
		-- Fire At Will
		Spring.GiveOrderToUnit(unitID,CMD.FIRE_STATE,{2},0)
		Spring.GiveOrderToUnit(unitID,CMD.MOVE_STATE,{2},0)
	end
end
