-----------------------------------------------------------------------------------------------------------------------------------------------------
-- Called when new unit is created for Scavengers ---------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------
local function AddScavUnit(unitID, unitDefID, unitName, unitTeam)
	if (UnitDefs[unitDefID].canMove == false or UnitDefs[unitDefID].isBuilding == true or scavNoSelfD[unitID]) and (unitName ~= "scavengerdroppodbeacon_scav") then
		BaseCleanupQueue[#BaseCleanupQueue+1] = unitID 
	end
	Spring.SetUnitExperience(unitID, math_random() * (spawnmultiplier*0.01*scavconfig.unitControllerModuleConfig.veterancymultiplier))
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
				scavConverted[unitID] = true
				unitSwapLibrary.SwapUnit(unitID, unitName..suffix)
				return
			end
		end
	end
	for i = 1,#bossUnitList.Bosses do
		if unitName == bossUnitList.Bosses[i] then
			FinalBossUnitID = unitID
			initialbosshealth = Spring.GetUnitHealth(unitID)

			local stopScavUnits = Spring.GetTeamUnits(ScavengerTeamID)
			for y = 1,#stopScavUnits do
				local unitID = stopScavUnits[y]							
				Spring.GiveOrderToUnit(unitID, CMD.STOP, 0, 0)
			end
			
		end
	end
	if constructorUnitList.SwapUnitsToScav[unitDefID] then
		scavConverted[unitID] = true
		unitSwapLibrary.SwapUnit(unitID, constructorUnitList.SwapUnitsToScav[unitDefID])
		return
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
	-- if scavengerGamePhase == "initial" then
	-- 	Spring.GiveOrderToUnit(unitID,CMD.FIRE_STATE,{1},0)
	-- else
		Spring.GiveOrderToUnit(unitID,CMD.FIRE_STATE,{2},0)
	-- end
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

	if scavconfig.modules.constructorControllerModule and scavconfig.constructorControllerModuleConfig.useconstructors then
		if constructorUnitList.ConstructorsID[unitDefID] then
			scavStatsScavCommanders = scavStatsScavCommanders+1
			scavConstructor[unitID] = true
			buffConstructorBuildSpeed(unitID)
		end
	end

	if scavconfig.constructorControllerModuleConfig.useresurrectors then
		if constructorUnitList.ResurrectorsID[unitDefID] then
			scavResurrector[unitID] = true
			buffConstructorBuildSpeed(unitID)
		end

		if constructorUnitList.ResurrectorsSeaID[unitDefID] then
			scavResurrector[unitID] = true
			buffConstructorBuildSpeed(unitID)
		end
	end

	if scavconfig.constructorControllerModuleConfig.usecollectors then
		if constructorUnitList.CollectorsID[unitDefID] then
			buffConstructorBuildSpeed(unitID)
			local r = math_random(0,100)
			if scavengerGamePhase == "initial" or r <= 10 then
				scavCollector[unitID] = true
			elseif r <= 25 then
				scavCapturer[unitID] = true
			else
				scavReclaimer[unitID] = true
			end
		end
	end

	if constructorUnitList.AssistersID[unitDefID] then
		buffConstructorBuildSpeed(unitID)
		scavAssistant[unitID] = true
	end

	factoryController.CheckNewUnit(unitID, unitDefID)
end

-----------------------------------------------------------------------------------------------------------------------------------------------------
-- Called when Scavenger unit is destroyed ----------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------

local function RemoveScavUnit(unitID, unitDefID, unitTeam, unitName, attackerID, attackerDefID, attackerTeam)
	if scavengerGamePhase == "initial" and (not scavConverted[unitID]) then
		initialPhaseCountdown = initialPhaseCountdown + 1
	end

	if FinalBossUnitSpawned == true then
		for i = 1,#bossUnitList.Bosses do
			if unitName  == bossUnitList.Bosses[i] then
				FinalBossKilled = true
				FinalBossUnitID = nil
			end
		end
	end

	if attackerID and unitTeam == ScavengerTeamID and attackerTeam ~= ScavengerTeamID then
		scavStatsScavUnitsKilled = scavStatsScavUnitsKilled + 1
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
	Spring.SetUnitHealth(unitID, {capture = 0})
end

-----------------------------------------------------------------------------------------------------------------------------------------------------
-- Called when new unit is created for Player -------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------

local function AddNonScavUnit(unitID, unitDefID, unitName, unitTeam)
	--AliveEnemyCommanders
	if constructorUnitList.PlayerCommandersID[unitDefID] then
		AliveEnemyCommandersCount = AliveEnemyCommandersCount + 1
		table.insert(AliveEnemyCommanders,unitID)
	end
	if constructorUnitList.SwapUnitsFromScav[unitDefID] then
		unitSwapLibrary.SwapUnit(unitID, constructorUnitList.SwapUnitsFromScav[unitDefID])
		return
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

-----------------------------------------------------------------------------------------------------------------------------------------------------
-- Called when Player unit is destroyed -------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------

local function RemoveNonScavUnit(unitID, unitDefID, unitTeam, unitName, attackerID, attackerDefID, attackerTeam)
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

-----------------------------------------------------------------------------------------------------------------------------------------------------
-- Called when Player captures Scavenger's unit -----------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------

local function CaptureScavUnit(unitID, unitDefID, unitName, unitNewTeam, unitOldTeam)
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
	if constructorUnitList.SwapUnitsFromScav[unitDefID] then
		unitSwapLibrary.SwapUnit(unitID, constructorUnitList.SwapUnitsFromScav[unitDefID])
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
end

-----------------------------------------------------------------------------------------------------------------------------------------------------
-- Called when Scavenger captures Player's unit -----------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------

local function CaptureNonScavUnit(unitID, unitDefID, unitName, unitNewTeam, unitOldTeam)
	if scavengerGamePhase == "initial" and (not scavConverted[unitID]) then
		initialPhaseCountdown = initialPhaseCountdown + 1
	end
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
				scavConverted[unitID] = true
				unitSwapLibrary.SwapUnit(unitID, unitName..suffix)
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
	if constructorUnitList.SwapUnitsToScav[unitDefID] then
		scavConverted[unitID] = true
		unitSwapLibrary.SwapUnit(unitID, constructorUnitList.SwapUnitsToScav[unitDefID])
		return
	end
	-- CMD.CLOAK = 37382
	Spring.GiveOrderToUnit(unitID,37382,{1},0)
	-- Fire At Will
	-- if scavengerGamePhase == "initial" then
	-- 	Spring.GiveOrderToUnit(unitID,CMD.FIRE_STATE,{1},0)
	-- else
		Spring.GiveOrderToUnit(unitID,CMD.FIRE_STATE,{2},0)
	-- end
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

	if scavconfig.modules.constructorControllerModule and scavconfig.constructorControllerModuleConfig.useconstructors then
		if constructorUnitList.ConstructorsID[unitDefID] then
			scavStatsScavCommanders = scavStatsScavCommanders+1
			scavConstructor[unitID] = true
			buffConstructorBuildSpeed(unitID)
		end
	end

	if scavconfig.constructorControllerModuleConfig.useresurrectors then
		if constructorUnitList.ResurrectorsID[unitDefID] then
			buffConstructorBuildSpeed(unitID)
			scavResurrector[unitID] = true
		end

		if constructorUnitList.ResurrectorsSeaID[unitDefID] then
			buffConstructorBuildSpeed(unitID)
			scavResurrector[unitID] = true
		end
	end

	if scavconfig.constructorControllerModuleConfig.usecollectors then
		if constructorUnitList.CollectorsID[unitDefID] then
			buffConstructorBuildSpeed(unitID)
			local r = math_random(0, 100)
			if scavengerGamePhase == "initial" or r <= 10 then
				scavCollector[unitID] = true
			elseif r <= 20 then
				scavCapturer[unitID] = true
			else
				scavReclaimer[unitID] = true
			end
		end
	end

	if constructorUnitList.AssistersID[unitDefID] then
		buffConstructorBuildSpeed(unitID)
		scavAssistant[unitID] = true
	end

	factoryController.CheckNewUnit(unitID, unitDefID)
end

return {
    AddScavUnit = AddScavUnit,
    RemoveScavUnit = RemoveScavUnit,
    AddNonScavUnit = AddNonScavUnit,
    RemoveNonScavUnit = RemoveNonScavUnit,
    CaptureScavUnit = CaptureScavUnit,
    CaptureNonScavUnit = CaptureNonScavUnit,
}