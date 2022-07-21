Spring.Echo("[Scavengers] Unit Spawner initialized")

local UnitSpawnChance = scavconfig.unitSpawnerModuleConfig.spawnchance

local function bossWaveTimer(n)
	if not BossWaveTimeLeft then
		BossWaveTimeLeft = scavconfig.unitSpawnerModuleConfig.BossWaveTimeLeft
	end
	if not FinalSelfDChance then
		FinalSelfDChance = 60
	end
	if not ScavBossFailedSpawnAttempts then
		ScavBossFailedSpawnAttempts = 0
	end
	if BossWaveTimeLeft > 0 then
		BossWaveTimeLeft = BossWaveTimeLeft - 1
		messengerController.BossFightMessages(BossWaveTimeLeft)
	elseif BossWaveTimeLeft <= 0 then
		if not FinalBossUnitSpawned and scavconfig.unitSpawnerModuleConfig.FinalBossUnit == true then

			local bossunit = bossUnitList.Bosses[math_random(1, #bossUnitList.Bosses)]

			local scavengerunits = Spring.GetTeamUnits(ScavengerTeamID)
			SpawnBeacons = {}
			for i = 1,#scavengerunits do
				local scav = scavengerunits[i]
				local scavDef = Spring.GetUnitDefID(scav)
				if scavSpawnBeacon[scav] then
					table.insert(SpawnBeacons,scav)
				end
			end

			if ScavBossFailedSpawnAttempts >= 10 then
				noSpawnerForBoss = true
			elseif #SpawnBeacons > 1 then
				for b = 1,1000 do
					local pickedBeaconTest = SpawnBeacons[math_random(1,#SpawnBeacons)]
					if pickedBeaconTest then
						pickedBeacon = pickedBeaconTest
					end
				end
			elseif #SpawnBeacons == 1 then
				pickedBeacon = SpawnBeacons[1]
			elseif #SpawnBeacons == 0 then
				noSpawnerForBoss = true
				pickedBeacon = 16000000 -- high number that UnitID should never pick
			end
			SpawnBeacons = nil
			if noSpawnerForBoss ~= true and (not Spring.ValidUnitID(pickedBeacon) or Spring.GetUnitIsDead(pickedBeacon) == true or Spring.GetUnitIsDead(pickedBeacon) == nil) then
				pickedBeacon = 16000000 -- high number that UnitID should never pick
			end
			if noSpawnerForBoss ~= true and pickedBeacon == 16000000 then
				--Spring.Echo("[Scavengers] Failed Attempt to spawn Final Boss")
				ScavBossFailedSpawnAttempts = ScavBossFailedSpawnAttempts+1
				return
			else
				if noSpawnerForBoss then
					local posx = math.floor((ScavengerStartboxXMin + ScavengerStartboxXMax)/2)
					local posz = math.floor((ScavengerStartboxZMin + ScavengerStartboxZMax)/2)
					local posy = Spring.GetGroundHeight(posx, posz)
					Spring.CreateUnit(bossunit, posx, posy, posz, math_random(0,3),ScavengerTeamID)
					FinalBossUnitSpawned = true
					--Spring.Echo("[Scavengers] Final Boss Spawned Successfully")
				elseif pickedBeacon then
					local posx,posy,posz = Spring.GetUnitPosition(pickedBeacon)
					local posy = Spring.GetGroundHeight(posx, posz)
					Spring.CreateUnit(bossunit, posx, posy, posz, math_random(0,3),ScavengerTeamID)
					FinalBossUnitSpawned = true
					--Spring.Echo("[Scavengers] Final Boss Spawned Successfully")
				else
					local posx = math.floor((ScavengerStartboxXMin + ScavengerStartboxXMax)/2)
					local posz = math.floor((ScavengerStartboxZMin + ScavengerStartboxZMax)/2)
					local posy = Spring.GetGroundHeight(posx, posz)
					Spring.CreateUnit(bossunit, posx, posy, posz, math_random(0,3),ScavengerTeamID)
					FinalBossUnitSpawned = true
					--Spring.Echo("[Scavengers] Final Boss Spawned Successfully")
				end
			end
			pickedBeacon = nil

		elseif (not scavconfig.unitSpawnerModuleConfig.FinalBossUnit) or FinalBossKilled == true then
			if not FinalMessagePlayed then
				ScavSendNotification("scav_scavfinalvictory")
				FinalMessagePlayed = true
			end

			-- kill whole allyteam  (game_end gadget will destroy leftover units)
			if not killedScavengerAllyTeam then
				local scavengerAllyTeamID = select(6, Spring.GetTeamInfo(scavengerAITeamID,false))
				for _, teamID in ipairs(Spring.GetTeamList(scavengerAllyTeamID)) do
					if not select(3, Spring.GetTeamInfo(teamID, false)) then
						Spring.KillTeam(teamID)
					end
				end
				killedScavengerAllyTeam = true
			end
		end
	end
end

local function bossMinionsSpawn(n)
	for i = 1,10 do
		local x,y,z = Spring.GetUnitPosition(FinalBossUnitID)
		local posx = x + math_random(-500,500)
		local posz = z + math_random(-500,500)
		local posy = Spring.GetGroundHeight(posx, posz)
		local r = math_random(0,100)
		local rair = math_random(0, scavconfig.unitSpawnerModuleConfig.aircraftchance)
		local landLevel, seaLevel = positionCheckLibrary.MapIsLandOrSea()

		if rair == 0 or (posy > 0 and landLevel < 40) or (posy < 0 and seaLevel < 30) then
			if TierSpawnChances.T4 > 0 then
				minionUnit = airUnitList.T4[math_random(1,#airUnitList.T4)]
			elseif TierSpawnChances.T3 > 0 then
				minionUnit = airUnitList.T3[math_random(1,#airUnitList.T3)]
			elseif TierSpawnChances.T2 > 0 then
				minionUnit = airUnitList.T2[math_random(1,#airUnitList.T2)]
			elseif TierSpawnChances.T1 > 0 then
				minionUnit = airUnitList.T1[math_random(1,#airUnitList.T1)]
			else
				minionUnit = airUnitList.T0[math_random(1,#airUnitList.T0)]
			end
			posy = posy + 1500
		elseif posy > -20 then
			if TierSpawnChances.T4 > 0 then
				minionUnit = landUnitList.T4[math_random(1,#landUnitList.T4)]
			elseif TierSpawnChances.T3 > 0 then
				minionUnit = landUnitList.T3[math_random(1,#landUnitList.T3)]
			elseif TierSpawnChances.T2 > 0 then
				minionUnit = landUnitList.T2[math_random(1,#landUnitList.T2)]
			elseif TierSpawnChances.T1 > 0 then
				minionUnit = landUnitList.T1[math_random(1,#landUnitList.T1)]
			else
				minionUnit = landUnitList.T0[math_random(1,#landUnitList.T0)]
			end
		elseif posy <= -20 then
			if TierSpawnChances.T4 > 0 then
				minionUnit = seaUnitList.T4[math_random(1,#seaUnitList.T4)]
			elseif TierSpawnChances.T3 > 0 then
				minionUnit = seaUnitList.T3[math_random(1,#seaUnitList.T3)]
			elseif TierSpawnChances.T2 > 0 then
				minionUnit = seaUnitList.T2[math_random(1,#seaUnitList.T2)]
			elseif TierSpawnChances.T1 > 0 then
				minionUnit = seaUnitList.T1[math_random(1,#seaUnitList.T1)]
			else
				minionUnit = seaUnitList.T0[math_random(1,#seaUnitList.T0)]
			end
		end
		spawnQueueLibrary.AddToSpawnQueue(minionUnit, posx, posy, posz, math_random(0,3),ScavengerTeamID, n+1)
		Spring.SpawnCEG("scav-spawnexplo",posx,posy,posz,0,0,0)
	end
end


local function unitGroupSpawn(n)
	if scavengerGamePhase ~= "initial" then
		local gaiaUnitCount = Spring.GetTeamUnitCount(ScavengerTeamID)
		if BossWaveTimeLeft then
			if (not numOfSpawnBeacons) or numOfSpawnBeacons == 0 then
				ActualUnitSpawnChance = math_random(0,math.ceil(UnitSpawnChance/1))
			else
				ActualUnitSpawnChance = math_random(0,((UnitSpawnChance/1)/(numOfSpawnBeacons/5)))
			end
		else
			if (not numOfSpawnBeacons) or numOfSpawnBeacons == 0 then
				ActualUnitSpawnChance = math_random(0,math.ceil(UnitSpawnChance))
			else
				ActualUnitSpawnChance = math_random(0,(UnitSpawnChance/(numOfSpawnBeacons/5)))
			end
		end
		if (ActualUnitSpawnChance == 0 or canSpawnHere == false) and numOfSpawnBeacons > 0 then
			-- check positions
			local scavengerunits = Spring.GetTeamUnits(ScavengerTeamID)
			SpawnBeacons = {}
			for i = 1,#scavengerunits do
				local scav = scavengerunits[i]
				local scavDef = Spring.GetUnitDefID(scav)
				if scavSpawnBeacon[scav] then
					table.insert(SpawnBeacons,scav)
				end
			end
			if #SpawnBeacons == 0 then
				return
			end
			for b = 1,100 do
				local pickedBeaconTest = SpawnBeacons[math_random(1,#SpawnBeacons)]
				if pickedBeaconTest then
					pickedBeacon = pickedBeaconTest
				end
			end
			if pickedBeacon == 16000000 then
				return
			end
			local posx,posy,posz = Spring.GetUnitPosition(pickedBeacon)
			local posy = Spring.GetGroundHeight(posx, posz)
			local posradius = 256
			local nearestEnemy = Spring.GetUnitNearestEnemy(pickedBeacon, 99999, false)
			if nearestEnemy and Spring.GetUnitTeam(nearestEnemy) == bestTeam then
				bestTeamGroupMultiplier = 1.25
			else
				bestTeamGroupMultiplier = 0.75
			end
			canSpawnHere = true
			--Spring.DestroyUnit(pickedBeacon,false,false)
			spawnBeaconsController.SpawnBeacon(n)
			pickedBeacon = nil

			if canSpawnHere then

				if BossWaveTimeLeft then
					UnitSpawnChance = math.ceil(scavconfig.unitSpawnerModuleConfig.spawnchance / (teamcount/2))
				else
					UnitSpawnChance = scavconfig.unitSpawnerModuleConfig.spawnchance
				end
				if not globalScore then
					teamsCheck()
				end
				if (globalScore/scavconfig.unitSpawnerModuleConfig.globalscoreperoneunit)*spawnmultiplier < #scavengerunits then
					UnitSpawnChance = math.ceil(UnitSpawnChance/2)
				end
				if math.random(1,100) == 1 then
					waveSizeMultiplier = 2
				elseif math.random(1,25) == 1 then
					waveSizeMultiplier = 1.5
				elseif math.random(1,10) == 1 then
					waveSizeMultiplier = 1.25
				else
					waveSizeMultiplier = 1
				end
				local groupsize = (globalScore / scavconfig.unitSpawnerModuleConfig.globalscoreperoneunit)*spawnmultiplier*waveSizeMultiplier
				local groupsize = math.ceil(groupsize*bestTeamGroupMultiplier*(teamcount/2))
				local aircraftchance = math_random(0,scavconfig.unitSpawnerModuleConfig.aircraftchance)
				local aircraftchanceonsea = math_random(0,scavconfig.unitSpawnerModuleConfig.chanceforaircraftonsea)
				local bossaircraftchance = math_random(0,scavconfig.unitSpawnerModuleConfig.aircraftchance*5)
				local spawnTier = math_random(1,100)
				local groupunit = {}
				local numOfTypes = 0
				local newTypeNumber = 9999 --math.random(2,20)
				--Spring.Echo(newTypeNumber)
				local landLevel, seaLevel = positionCheckLibrary.MapIsLandOrSea()
				if (posy <= -20 and aircraftchanceonsea == 0) or (aircraftchance == 0 and (not BossWaveTimeLeft)) or (bossaircraftchance == 0 and BossWaveTimeLeft and BossWaveTimeLeft > 0) or (posy > 0 and landLevel < 40) or (posy < 0 and seaLevel < 30) then
					if spawnTier <= TierSpawnChances.T0 then
						groupsize = math.ceil(groupsize*scavconfig.unitSpawnerModuleConfig.airmultiplier*scavconfig.unitSpawnerModuleConfig.t0multiplier)
						for i = 1,groupsize do
							if i%newTypeNumber == 1 then
								numOfTypes = numOfTypes+1
								groupunit[numOfTypes] = airUnitList.T0[math_random(1,#airUnitList.T0)]
							end
						end
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 then
						groupsize = math.ceil(groupsize*scavconfig.unitSpawnerModuleConfig.airmultiplier*scavconfig.unitSpawnerModuleConfig.t1multiplier)
						for i = 1,groupsize do
							if i%newTypeNumber == 1 then
								numOfTypes = numOfTypes+1
								groupunit[numOfTypes] = airUnitList.T1[math_random(1,#airUnitList.T1)]
							end
						end
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 then
						groupsize = math.ceil(groupsize*scavconfig.unitSpawnerModuleConfig.airmultiplier*scavconfig.unitSpawnerModuleConfig.t2multiplier)
						for i = 1,groupsize do
							if i%newTypeNumber == 1 then
								numOfTypes = numOfTypes+1
								groupunit[numOfTypes] = airUnitList.T2[math_random(1,#airUnitList.T2)]
							end
						end
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 then
						groupsize = math.ceil(groupsize*scavconfig.unitSpawnerModuleConfig.airmultiplier*scavconfig.unitSpawnerModuleConfig.t3multiplier)
						for i = 1,groupsize do
							if i%newTypeNumber == 1 then
								numOfTypes = numOfTypes+1
								groupunit[numOfTypes] = airUnitList.T3[math_random(1,#airUnitList.T3)]
							end
						end
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 + TierSpawnChances.T4 then
						groupsize = math.ceil(groupsize*scavconfig.unitSpawnerModuleConfig.airmultiplier*scavconfig.unitSpawnerModuleConfig.t4multiplier)
						for i = 1,groupsize do
							if i%newTypeNumber == 1 then
								numOfTypes = numOfTypes+1
								groupunit[numOfTypes] = airUnitList.T4[math_random(1,#airUnitList.T4)]
							end
						end
					else
						groupsize = math.ceil(groupsize*scavconfig.unitSpawnerModuleConfig.airmultiplier*scavconfig.unitSpawnerModuleConfig.t0multiplier)
						for i = 1,groupsize do
							if i%newTypeNumber == 1 then
								numOfTypes = numOfTypes+1
								groupunit[numOfTypes] = airUnitList.T0[math_random(1,#airUnitList.T0)]
							end
						end
					end
				elseif posy > -20 then
					if spawnTier <= TierSpawnChances.T0 then
						groupsize = math.ceil(groupsize*scavconfig.unitSpawnerModuleConfig.landmultiplier*scavconfig.unitSpawnerModuleConfig.t0multiplier)
						for i = 1,groupsize do
							if i%newTypeNumber == 1 then
								numOfTypes = numOfTypes+1
								groupunit[numOfTypes] = landUnitList.T0[math_random(1,#landUnitList.T0)]
							end
						end
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 then
						groupsize = math.ceil(groupsize*scavconfig.unitSpawnerModuleConfig.landmultiplier*scavconfig.unitSpawnerModuleConfig.t1multiplier)
						for i = 1,groupsize do
							if i%newTypeNumber == 1 then
								numOfTypes = numOfTypes+1
								groupunit[numOfTypes] = landUnitList.T1[math_random(1,#landUnitList.T1)]
							end
						end
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 then
						groupsize = math.ceil(groupsize*scavconfig.unitSpawnerModuleConfig.landmultiplier*scavconfig.unitSpawnerModuleConfig.t2multiplier)
						for i = 1,groupsize do
							if i%newTypeNumber == 1 then
								numOfTypes = numOfTypes+1
								groupunit[numOfTypes] = landUnitList.T2[math_random(1,#landUnitList.T2)]
							end
						end
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 then
						groupsize = math.ceil(groupsize*scavconfig.unitSpawnerModuleConfig.landmultiplier*scavconfig.unitSpawnerModuleConfig.t3multiplier)
						for i = 1,groupsize do
							if i%newTypeNumber == 1 then
								numOfTypes = numOfTypes+1
								groupunit[numOfTypes] = landUnitList.T3[math_random(1,#landUnitList.T3)]
							end
						end
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 + TierSpawnChances.T4 then
						groupsize = math.ceil(groupsize*scavconfig.unitSpawnerModuleConfig.landmultiplier*scavconfig.unitSpawnerModuleConfig.t4multiplier)
						for i = 1,groupsize do
							if i%newTypeNumber == 1 then
								numOfTypes = numOfTypes+1
								groupunit[numOfTypes] = landUnitList.T4[math_random(1,#landUnitList.T4)]
							end
						end
					else
						groupsize = math.ceil(groupsize*scavconfig.unitSpawnerModuleConfig.landmultiplier*scavconfig.unitSpawnerModuleConfig.t0multiplier)
						for i = 1,groupsize do
							if i%newTypeNumber == 1 then
								numOfTypes = numOfTypes+1
								groupunit[numOfTypes] = landUnitList.T0[math_random(1,#landUnitList.T0)]
							end
						end
					end
				elseif posy <= -20 then
					if spawnTier <= TierSpawnChances.T0 then
						groupsize = math.ceil(groupsize*scavconfig.unitSpawnerModuleConfig.seamultiplier*scavconfig.unitSpawnerModuleConfig.t0multiplier)
						for i = 1,groupsize do
							if i%newTypeNumber == 1 then
								numOfTypes = numOfTypes+1
								groupunit[numOfTypes] = seaUnitList.T0[math_random(1,#seaUnitList.T0)]
							end
						end
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 then
						groupsize = math.ceil(groupsize*scavconfig.unitSpawnerModuleConfig.seamultiplier*scavconfig.unitSpawnerModuleConfig.t1multiplier)
						for i = 1,groupsize do
							if i%newTypeNumber == 1 then
								numOfTypes = numOfTypes+1
								groupunit[numOfTypes] = seaUnitList.T1[math_random(1,#seaUnitList.T1)]
							end
						end
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 then
						groupsize = math.ceil(groupsize*scavconfig.unitSpawnerModuleConfig.seamultiplier*scavconfig.unitSpawnerModuleConfig.t2multiplier)
						for i = 1,groupsize do
							if i%newTypeNumber == 1 then
								numOfTypes = numOfTypes+1
								groupunit[numOfTypes] = seaUnitList.T2[math_random(1,#seaUnitList.T2)]
							end
						end
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 then
						groupsize = math.ceil(groupsize*scavconfig.unitSpawnerModuleConfig.seamultiplier*scavconfig.unitSpawnerModuleConfig.t3multiplier)
						for i = 1,groupsize do
							if i%newTypeNumber == 1 then
								numOfTypes = numOfTypes+1
								groupunit[numOfTypes] = seaUnitList.T3[math_random(1,#seaUnitList.T3)]
							end
						end
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 + TierSpawnChances.T4 then
						groupsize = math.ceil(groupsize*scavconfig.unitSpawnerModuleConfig.seamultiplier*scavconfig.unitSpawnerModuleConfig.t4multiplier)
						for i = 1,groupsize do
							if i%newTypeNumber == 1 then
								numOfTypes = numOfTypes+1
								groupunit[numOfTypes] = seaUnitList.T4[math_random(1,#seaUnitList.T4)]
							end
						end
					else
						groupsize = math.ceil(groupsize*scavconfig.unitSpawnerModuleConfig.seamultiplier*scavconfig.unitSpawnerModuleConfig.t0multiplier)
						for i = 1,groupsize do
							if i%newTypeNumber == 1 then
								numOfTypes = numOfTypes+1
								groupunit[numOfTypes] = seaUnitList.T0[math_random(1,#seaUnitList.T0)]
							end
						end
					end
				end

				for i=1, groupsize do
					local posx = posx+math_random(-160,160)
					local posz = posz+math_random(-160,160)
					local newposy = Spring.GetGroundHeight(posx, posz)
					if posy >= -20 and newposy >= -20 then
						if i then
							spawnQueueLibrary.AddToSpawnQueue(staticUnitList.scavSpawnEffectUnit, posx, posy, posz, math_random(0,3),ScavengerTeamID, n+(i*2))
							spawnQueueLibrary.AddToSpawnQueue(groupunit[math.ceil(i/newTypeNumber)], posx, posy, posz, math_random(0,3),ScavengerTeamID, n+150+(i*2))
						else
							spawnQueueLibrary.AddToSpawnQueue(staticUnitList.scavSpawnEffectUnit, posx, posy, posz, math_random(0,3),ScavengerTeamID, n)
							spawnQueueLibrary.AddToSpawnQueue(groupunit[math.ceil(i/newTypeNumber)], posx, posy, posz, math_random(0,3),ScavengerTeamID, n+150)
						end
					elseif posy < -20 and newposy < -20 then
						if i then
							spawnQueueLibrary.AddToSpawnQueue(staticUnitList.scavSpawnEffectUnit, posx, posy, posz, math_random(0,3),ScavengerTeamID, n+(i*2))
							spawnQueueLibrary.AddToSpawnQueue(groupunit[math.ceil(i/newTypeNumber)], posx, posy, posz, math_random(0,3),ScavengerTeamID, n+150+(i*2))
						else
							spawnQueueLibrary.AddToSpawnQueue(staticUnitList.scavSpawnEffectUnit, posx, posy, posz, math_random(0,3),ScavengerTeamID, n)
							spawnQueueLibrary.AddToSpawnQueue(groupunit[math.ceil(i/newTypeNumber)], posx, posy, posz, math_random(0,3),ScavengerTeamID, n+150)
						end
					end
					local rx = posx+math.random(-64,64)
					local rz = posz+math.random(-64,64)
					if math.random(0,3) == 0 then
						if Spring.GetGroundHeight(rx, rz) > -20 then
							spawnQueueLibrary.AddToSpawnQueue(constructorUnitList.Resurrectors[math_random(1,#constructorUnitList.Resurrectors)], rx, posy, rz, math_random(0,3),ScavengerTeamID, n+150+(i*2), false)
						else
							spawnQueueLibrary.AddToSpawnQueue(constructorUnitList.ResurrectorsSea[math_random(1,#constructorUnitList.ResurrectorsSea)], rx, posy, rz, math_random(0,3),ScavengerTeamID, n+150+(i*2), false)
						end
						spawnQueueLibrary.AddToSpawnQueue(staticUnitList.scavSpawnEffectUnit, rx, posy, rz, math_random(0,3),ScavengerTeamID, n+(i*2))
					end
					--Spring.CreateUnit(staticUnitList.scavSpawnEffectUnit, posx, posy, posz, math_random(0,3),ScavengerTeamID)
				end
				posx = nil
				posy = nil
				posz = nil
				SpawnBeacons = nil
			end
		else
			UnitSpawnChance = UnitSpawnChance - 1
			if UnitSpawnChance < 1 then
				UnitSpawnChance = 1
			end
		end
	end
end

return {
	BossWaveTimer = bossWaveTimer,
	BossMinionsSpawn = bossMinionsSpawn,
	UnitGroupSpawn = unitGroupSpawn,
}
