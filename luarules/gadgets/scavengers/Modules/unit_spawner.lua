Spring.Echo("[Scavengers] Unit Spawner initialized")

local UnitSpawnChance = unitSpawnerModuleConfig.spawnchance

function BossWaveTimer(n)
	if not BossWaveTimeLeft then
		BossWaveTimeLeft = unitSpawnerModuleConfig.BossWaveTimeLeft
	end
	if not FinalSelfDChance then
		FinalSelfDChance = 60
	end
	if not ScavBossFailedSpawnAttempts then
		ScavBossFailedSpawnAttempts = 0
	end
	if BossWaveTimeLeft > 0 then
		BossWaveTimeLeft = BossWaveTimeLeft - 1
		BossFightMessages(BossWaveTimeLeft)
	elseif BossWaveTimeLeft <= 0 then
		if not FinalBossUnitSpawned and unitSpawnerModuleConfig.FinalBossUnit == true then
			
			local bossunit = BossUnits[math_random(1,#BossUnits)]
			
			local scavengerunits = Spring.GetTeamUnits(GaiaTeamID)
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
					local _,_,pickedBeaconParalyze,pickedBeaconCaptureProgress = Spring.GetUnitHealth(pickedBeaconTest)
					if pickedBeaconCaptureProgress == 0 and pickedBeaconParalyze == 0 then
						pickedBeacon = pickedBeaconTest
						break
					else
						pickedBeacon = 1234567890
					end
				end
			elseif #SpawnBeacons == 1 then
				pickedBeacon = SpawnBeacons[1]
			elseif #SpawnBeacons == 0 then
				noSpawnerForBoss = true
			end
			SpawnBeacons = nil
			if noSpawnerForBoss ~= true and not Spring.ValidUnitID(pickedBeacon) or Spring.GetUnitIsDead(pickedBeacon) == true or Spring.GetUnitIsDead(pickedBeacon) == nil then
				pickedBeacon = 1234567890
			end
			if noSpawnerForBoss ~= true and pickedBeacon == 1234567890 then
				Spring.Echo("[Scavengers] Failed Attempt to spawn Final Boss")
				ScavBossFailedSpawnAttempts = ScavBossFailedSpawnAttempts+1
				return
			else
				if noSpawnerForBoss and ScavengerStartboxExists == true then
					local posx = math.floor((ScavengerStartboxXMin + ScavengerStartboxXMax)/2)
					local posz = math.floor((ScavengerStartboxZMin + ScavengerStartboxZMax)/2)
					local posy = Spring.GetGroundHeight(posx, posz)
					Spring.CreateUnit(bossunit, posx, posy, posz, math_random(0,3),GaiaTeamID)
					FinalBossUnitSpawned = true
					Spring.Echo("[Scavengers] Final Boss Spawned Successfully")
				elseif noSpawnerForBoss then
					local posx = math.floor(mapsizeX/2)
					local posz = math.floor(mapsizeZ/2)
					local posy = Spring.GetGroundHeight(posx, posz)
					Spring.CreateUnit(bossunit, posx, posy, posz, math_random(0,3),GaiaTeamID)
					FinalBossUnitSpawned = true
					Spring.Echo("[Scavengers] Final Boss Spawned Successfully")
				elseif pickedBeacon then
					local posx,posy,posz = Spring.GetUnitPosition(pickedBeacon)
					local posy = Spring.GetGroundHeight(posx, posz)
					Spring.CreateUnit(bossunit, posx, posy, posz, math_random(0,3),GaiaTeamID)
					FinalBossUnitSpawned = true
					Spring.Echo("[Scavengers] Final Boss Spawned Successfully")
				elseif ScavengerStartboxExists == true then
					local posx = math.floor((ScavengerStartboxXMin + ScavengerStartboxXMax)/2)
					local posz = math.floor((ScavengerStartboxZMin + ScavengerStartboxZMax)/2)
					local posy = Spring.GetGroundHeight(posx, posz)
					Spring.CreateUnit(bossunit, posx, posy, posz, math_random(0,3),GaiaTeamID)
					FinalBossUnitSpawned = true
					Spring.Echo("[Scavengers] Final Boss Spawned Successfully")
				else
					local posx = math.floor(mapsizeX/2)
					local posz = math.floor(mapsizeZ/2)
					local posy = Spring.GetGroundHeight(posx, posz)
					Spring.CreateUnit(bossunit, posx, posy, posz, math_random(0,3),GaiaTeamID)
					FinalBossUnitSpawned = true
					Spring.Echo("[Scavengers] Final Boss Spawned Successfully")
				end
			end
			pickedBeacon = nil

		elseif (not unitSpawnerModuleConfig.FinalBossUnit) or FinalBossKilled == true then
			if not FinalMessagePlayed then
				ScavSendNotification("scav_scavfinalvictory")
				FinalMessagePlayed = true
			end
			local units = Spring.GetTeamUnits(GaiaTeamID)
			FinalSelfDChance = FinalSelfDChance - 1
			if FinalSelfDChance < 2 then
				FinalSelfDChance = 2
			end
			for i = 1,#units do
				local r = math_random(1,FinalSelfDChance)
				if r == 1 then
					Spring.DestroyUnit(units[i],false,false)
				end
			end
		end
	end
end

function BossMinionsSpawn(n)
	if BossFightCurrentPhase then
		local x,y,z = Spring.GetUnitPosition(FinalBossUnitID)
		local posx = x + math_random(-500,500)
		local posz = z + math_random(-500,500)
		local posy = Spring.GetGroundHeight(posx, posz)
		local r = math_random(0,100)
		local rair = math_random(0, unitSpawnerModuleConfig.aircraftchance)

		if rair == 0 then
			if BossFightCurrentPhase >= 5 then
				minionUnit = T4AirUnits[math_random(1,#T4AirUnits)]..scavconfig.unitnamesuffix
			elseif BossFightCurrentPhase >= 4 then
				minionUnit = T3AirUnits[math_random(1,#T3AirUnits)]..scavconfig.unitnamesuffix
			elseif BossFightCurrentPhase >= 3 then
				minionUnit = T2AirUnits[math_random(1,#T2AirUnits)]..scavconfig.unitnamesuffix
			elseif BossFightCurrentPhase >= 2 then
				minionUnit = T1AirUnits[math_random(1,#T1AirUnits)]..scavconfig.unitnamesuffix
			elseif BossFightCurrentPhase == 1 then
				minionUnit = T0AirUnits[math_random(1,#T0AirUnits)]..scavconfig.unitnamesuffix
			else
				minionUnit = T0AirUnits[math_random(1,#T0AirUnits)]..scavconfig.unitnamesuffix
			end
		elseif posy > -20 then
			if BossFightCurrentPhase >= 9 then
				minionUnit = T4LandUnits[math_random(1,#T4LandUnits)]..scavconfig.unitnamesuffix
			elseif BossFightCurrentPhase >= 7 then
				minionUnit = T3LandUnits[math_random(1,#T3LandUnits)]..scavconfig.unitnamesuffix
			elseif BossFightCurrentPhase >= 5 then
				minionUnit = T2LandUnits[math_random(1,#T2LandUnits)]..scavconfig.unitnamesuffix
			elseif BossFightCurrentPhase >= 3 then
				minionUnit = T1LandUnits[math_random(1,#T1LandUnits)]..scavconfig.unitnamesuffix
			elseif BossFightCurrentPhase == 1 then
				minionUnit = T0LandUnits[math_random(1,#T0LandUnits)]..scavconfig.unitnamesuffix
			else
				minionUnit = T0LandUnits[math_random(1,#T0LandUnits)]..scavconfig.unitnamesuffix
			end
		elseif posy <= -20 then
			if BossFightCurrentPhase >= 5 then
				minionUnit = T4SeaUnits[math_random(1,#T4SeaUnits)]..scavconfig.unitnamesuffix
			elseif BossFightCurrentPhase >= 4 then
				minionUnit = T3SeaUnits[math_random(1,#T3SeaUnits)]..scavconfig.unitnamesuffix
			elseif BossFightCurrentPhase >= 3 then
				minionUnit = T2SeaUnits[math_random(1,#T2SeaUnits)]..scavconfig.unitnamesuffix
			elseif BossFightCurrentPhase >= 2 then
				minionUnit = T1SeaUnits[math_random(1,#T1SeaUnits)]..scavconfig.unitnamesuffix
			elseif BossFightCurrentPhase == 1 then
				minionUnit = T0SeaUnits[math_random(1,#T0SeaUnits)]..scavconfig.unitnamesuffix
			else
				minionUnit = T0SeaUnits[math_random(1,#T0SeaUnits)]..scavconfig.unitnamesuffix
			end
		end
		if math.random(1,4) == 1 then
			--Spring.CreateUnit(minionUnit, posx, posy, posz, math_random(0,3),GaiaTeamID)
			QueueSpawn(minionUnit, posx, posy, posz, math_random(0,3),GaiaTeamID, n+1)
			Spring.SpawnCEG("scav-spawnexplo",posx,posy,posz,0,0,0)
			local posx = x + math_random(-500,500)
			local posz = z + math_random(-500,500)
			local posy = Spring.GetGroundHeight(posx, posz)
			Spring.CreateUnit("scavmistxxl"..scavconfig.unitnamesuffix, posx, posy, posz, math_random(0,3),GaiaTeamID)
		end
	end
end


function UnitGroupSpawn(n)
	if n > 9000 then
		local gaiaUnitCount = Spring.GetTeamUnitCount(GaiaTeamID)
		if BossWaveTimeLeft then
			if numOfSpawnBeacons or numOfSpawnBeacons == 0 then
				ActualUnitSpawnChance = math_random(0,math.ceil(UnitSpawnChance)*3)
			else
				ActualUnitSpawnChance = math_random(0,(UnitSpawnChance/(numOfSpawnBeacons/5))*3)
			end
		else
			if numOfSpawnBeacons or numOfSpawnBeacons == 0 then
				ActualUnitSpawnChance = math_random(0,math.ceil(UnitSpawnChance))
			else
				ActualUnitSpawnChance = math_random(0,(UnitSpawnChance/(numOfSpawnBeacons/5)))
			end
		end
		if (ActualUnitSpawnChance == 0 or canSpawnHere == false) and numOfSpawnBeacons > 0 then
			-- check positions
			local scavengerunits = Spring.GetTeamUnits(GaiaTeamID)
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
			for b = 1,10 do
				local pickedBeaconTest = SpawnBeacons[math_random(1,#SpawnBeacons)]
				local _,_,_,pickedBeaconCaptureProgress = Spring.GetUnitHealth(pickedBeaconTest)
				if pickedBeaconCaptureProgress == 0 then
					pickedBeacon = pickedBeaconTest
					break
				else
					pickedBeacon = 1234567890
				end
			end
			if pickedBeacon == 1234567890 then
				return
			end
			local posx,posy,posz = Spring.GetUnitPosition(pickedBeacon)
			local posy = Spring.GetGroundHeight(posx, posz)
			local posradius = 256
			local nearestEnemy = Spring.GetUnitNearestEnemy(pickedBeacon, 99999, false)
			local nearestEnemyTeam = Spring.GetUnitTeam(nearestEnemy)
			if nearestEnemyTeam == bestTeam then
				bestTeamGroupMultiplier = 1.25
			else
				bestTeamGroupMultiplier = 0.75
			end
			canSpawnHere = true
			--Spring.DestroyUnit(pickedBeacon,false,false)
			SpawnBeacon(n)
			pickedBeacon = nil

			if canSpawnHere then

				if BossWaveTimeLeft then
					UnitSpawnChance = math.ceil(unitSpawnerModuleConfig.spawnchance / (teamcount/2))
				else
					UnitSpawnChance = unitSpawnerModuleConfig.spawnchance
				end
				if not globalScore then
					teamsCheck()
				end
				if (globalScore/unitSpawnerModuleConfig.globalscoreperoneunit)*spawnmultiplier < #scavengerunits then
					UnitSpawnChance = math.ceil(UnitSpawnChance/2)
				end
				if math.random(1,100) == 1 then
					waveSizeMultiplier = 4
				elseif math.random(1,25) == 1 then
					waveSizeMultiplier = 2
				elseif math.random(1,10) == 1 then
					waveSizeMultiplier = 1.5
				else
					waveSizeMultiplier = 1
				end
				local groupsize = (globalScore / unitSpawnerModuleConfig.globalscoreperoneunit)*spawnmultiplier*waveSizeMultiplier
				local groupsize = math.ceil(groupsize*bestTeamGroupMultiplier*(teamcount/2))
				local aircraftchance = math_random(0,unitSpawnerModuleConfig.aircraftchance)
				local aircraftchanceonsea = math_random(0,unitSpawnerModuleConfig.chanceforaircraftonsea)
				local bossaircraftchance = math_random(0,unitSpawnerModuleConfig.aircraftchance*5)
				local spawnTier = math_random(1,100)
				local groupunit = {}
				local numOfTypes = 0
				local newTypeNumber = math.random(2,20)
				--Spring.Echo(newTypeNumber)
				if (posy <= -20 and aircraftchanceonsea == 0) or (aircraftchance == 0 and (not BossWaveTimeLeft)) or (bossaircraftchance == 0 and BossWaveTimeLeft and BossWaveTimeLeft > 0) then
					if unitSpawnerModuleConfig.bossFightEnabled and BossWaveTimeLeft then
						groupsize = math.ceil(groupsize*unitSpawnerModuleConfig.airmultiplier*unitSpawnerModuleConfig.t4multiplier)
						if spawnTier < 50 then
							for i = 1,groupsize do
								if i%newTypeNumber == 1 then
									numOfTypes = numOfTypes+1
									groupunit[numOfTypes] = T4AirUnits[math_random(1,#T4AirUnits)]
								end
							end
						else
							for i = 1,groupsize do
								if i%newTypeNumber == 1 then
									numOfTypes = numOfTypes+1
									groupunit[numOfTypes] = T3AirUnits[math_random(1,#T3AirUnits)]
								end
							end
						end
					elseif spawnTier <= TierSpawnChances.T0 then
						groupsize = math.ceil(groupsize*unitSpawnerModuleConfig.airmultiplier*unitSpawnerModuleConfig.t0multiplier)
						for i = 1,groupsize do
							if i%newTypeNumber == 1 then
								numOfTypes = numOfTypes+1
								groupunit[numOfTypes] = T0AirUnits[math_random(1,#T0AirUnits)]
							end
						end
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 then
						groupsize = math.ceil(groupsize*unitSpawnerModuleConfig.airmultiplier*unitSpawnerModuleConfig.t1multiplier)
						for i = 1,groupsize do
							if i%newTypeNumber == 1 then
								numOfTypes = numOfTypes+1
								groupunit[numOfTypes] = T1AirUnits[math_random(1,#T1AirUnits)]
							end
						end
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 then
						groupsize = math.ceil(groupsize*unitSpawnerModuleConfig.airmultiplier*unitSpawnerModuleConfig.t2multiplier)
						for i = 1,groupsize do
							if i%newTypeNumber == 1 then
								numOfTypes = numOfTypes+1
								groupunit[numOfTypes] = T2AirUnits[math_random(1,#T2AirUnits)]
							end
						end
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 then
						groupsize = math.ceil(groupsize*unitSpawnerModuleConfig.airmultiplier*unitSpawnerModuleConfig.t3multiplier)
						for i = 1,groupsize do
							if i%newTypeNumber == 1 then
								numOfTypes = numOfTypes+1
								groupunit[numOfTypes] = T3AirUnits[math_random(1,#T3AirUnits)]
							end
						end
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 + TierSpawnChances.T4 then
						groupsize = math.ceil(groupsize*unitSpawnerModuleConfig.airmultiplier*unitSpawnerModuleConfig.t4multiplier)
						for i = 1,groupsize do
							if i%newTypeNumber == 1 then
								numOfTypes = numOfTypes+1
								groupunit[numOfTypes] = T4AirUnits[math_random(1,#T4AirUnits)]
							end
						end
					else
						groupsize = math.ceil(groupsize*unitSpawnerModuleConfig.airmultiplier*unitSpawnerModuleConfig.t0multiplier)
						for i = 1,groupsize do
							if i%newTypeNumber == 1 then
								numOfTypes = numOfTypes+1
								groupunit[numOfTypes] = T0AirUnits[math_random(1,#T0AirUnits)]
							end
						end
					end
				elseif posy > -20 then
					if unitSpawnerModuleConfig.bossFightEnabled and BossWaveTimeLeft then
						groupsize = math.ceil(groupsize*unitSpawnerModuleConfig.landmultiplier*unitSpawnerModuleConfig.t4multiplier)
						if spawnTier < 50 then
							for i = 1,groupsize do
								if i%newTypeNumber == 1 then
									numOfTypes = numOfTypes+1
									groupunit[numOfTypes] = T4LandUnits[math_random(1,#T4LandUnits)]
								end
							end
						else
							for i = 1,groupsize do
								if i%newTypeNumber == 1 then
									numOfTypes = numOfTypes+1
									groupunit[numOfTypes] = T3LandUnits[math_random(1,#T3LandUnits)]
								end
							end
						end
					elseif spawnTier <= TierSpawnChances.T0 then
						groupsize = math.ceil(groupsize*unitSpawnerModuleConfig.landmultiplier*unitSpawnerModuleConfig.t0multiplier)
						for i = 1,groupsize do
							if i%newTypeNumber == 1 then
								numOfTypes = numOfTypes+1
								groupunit[numOfTypes] = T0LandUnits[math_random(1,#T0LandUnits)]
							end
						end
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 then
						groupsize = math.ceil(groupsize*unitSpawnerModuleConfig.landmultiplier*unitSpawnerModuleConfig.t1multiplier)
						for i = 1,groupsize do
							if i%newTypeNumber == 1 then
								numOfTypes = numOfTypes+1
								groupunit[numOfTypes] = T1LandUnits[math_random(1,#T1LandUnits)]
							end
						end
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 then
						groupsize = math.ceil(groupsize*unitSpawnerModuleConfig.landmultiplier*unitSpawnerModuleConfig.t2multiplier)
						for i = 1,groupsize do
							if i%newTypeNumber == 1 then
								numOfTypes = numOfTypes+1
								groupunit[numOfTypes] = T2LandUnits[math_random(1,#T2LandUnits)]
							end
						end
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 then
						groupsize = math.ceil(groupsize*unitSpawnerModuleConfig.landmultiplier*unitSpawnerModuleConfig.t3multiplier)
						for i = 1,groupsize do
							if i%newTypeNumber == 1 then
								numOfTypes = numOfTypes+1
								groupunit[numOfTypes] = T3LandUnits[math_random(1,#T3LandUnits)]
							end
						end
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 + TierSpawnChances.T4 then
						groupsize = math.ceil(groupsize*unitSpawnerModuleConfig.landmultiplier*unitSpawnerModuleConfig.t4multiplier)
						for i = 1,groupsize do
							if i%newTypeNumber == 1 then
								numOfTypes = numOfTypes+1
								groupunit[numOfTypes] = T4LandUnits[math_random(1,#T4LandUnits)]
							end
						end
					else
						groupsize = math.ceil(groupsize*unitSpawnerModuleConfig.landmultiplier*unitSpawnerModuleConfig.t0multiplier)
						for i = 1,groupsize do
							if i%newTypeNumber == 1 then
								numOfTypes = numOfTypes+1
								groupunit[numOfTypes] = T0LandUnits[math_random(1,#T0LandUnits)]
							end
						end
					end
				elseif posy <= -20 then
					if unitSpawnerModuleConfig.bossFightEnabled and BossWaveTimeLeft then
						groupsize = math.ceil(groupsize*unitSpawnerModuleConfig.seamultiplier*unitSpawnerModuleConfig.t4multiplier)
						if spawnTier < 50 then
							for i = 1,groupsize do
								if i%newTypeNumber == 1 then
									numOfTypes = numOfTypes+1
									groupunit[numOfTypes] = T4SeaUnits[math_random(1,#T4SeaUnits)]
								end
							end
						else
							for i = 1,groupsize do
								if i%newTypeNumber == 1 then
									numOfTypes = numOfTypes+1
									groupunit[numOfTypes] = T3SeaUnits[math_random(1,#T3SeaUnits)]
								end
							end
						end
					elseif spawnTier <= TierSpawnChances.T0 then
						groupsize = math.ceil(groupsize*unitSpawnerModuleConfig.seamultiplier*unitSpawnerModuleConfig.t0multiplier)
						for i = 1,groupsize do
							if i%newTypeNumber == 1 then
								numOfTypes = numOfTypes+1
								groupunit[numOfTypes] = T0SeaUnits[math_random(1,#T0SeaUnits)]
							end
						end
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 then
						groupsize = math.ceil(groupsize*unitSpawnerModuleConfig.seamultiplier*unitSpawnerModuleConfig.t1multiplier)
						for i = 1,groupsize do
							if i%newTypeNumber == 1 then
								numOfTypes = numOfTypes+1
								groupunit[numOfTypes] = T1SeaUnits[math_random(1,#T1SeaUnits)]
							end
						end
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 then
						groupsize = math.ceil(groupsize*unitSpawnerModuleConfig.seamultiplier*unitSpawnerModuleConfig.t2multiplier)
						for i = 1,groupsize do
							if i%newTypeNumber == 1 then
								numOfTypes = numOfTypes+1
								groupunit[numOfTypes] = T2SeaUnits[math_random(1,#T2SeaUnits)]
							end
						end
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 then
						groupsize = math.ceil(groupsize*unitSpawnerModuleConfig.seamultiplier*unitSpawnerModuleConfig.t3multiplier)
						for i = 1,groupsize do
							if i%newTypeNumber == 1 then
								numOfTypes = numOfTypes+1
								groupunit[numOfTypes] = T3SeaUnits[math_random(1,#T3SeaUnits)]
							end
						end
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 + TierSpawnChances.T4 then
						groupsize = math.ceil(groupsize*unitSpawnerModuleConfig.seamultiplier*unitSpawnerModuleConfig.t4multiplier)
						for i = 1,groupsize do
							if i%newTypeNumber == 1 then
								numOfTypes = numOfTypes+1
								groupunit[numOfTypes] = T4SeaUnits[math_random(1,#T4SeaUnits)]
							end
						end
					else
						groupsize = math.ceil(groupsize*unitSpawnerModuleConfig.seamultiplier*unitSpawnerModuleConfig.t0multiplier)
						for i = 1,groupsize do
							if i%newTypeNumber == 1 then
								numOfTypes = numOfTypes+1
								groupunit[numOfTypes] = T0SeaUnits[math_random(1,#T0SeaUnits)]
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
							QueueSpawn("scavengerdroppod_scav", posx, posy, posz, math_random(0,3),GaiaTeamID, n+(i*15))
							QueueSpawn(groupunit[math.ceil(i/newTypeNumber)]..scavconfig.unitnamesuffix, posx, posy, posz, math_random(0,3),GaiaTeamID, n+90+(i*15))
						else
							QueueSpawn("scavengerdroppod_scav", posx, posy, posz, math_random(0,3),GaiaTeamID, n)
							QueueSpawn(groupunit[math.ceil(i/newTypeNumber)]..scavconfig.unitnamesuffix, posx, posy, posz, math_random(0,3),GaiaTeamID, n+90)
						end
					elseif posy < -20 and newposy < -20 then
						if i then
							QueueSpawn("scavengerdroppod_scav", posx, posy, posz, math_random(0,3),GaiaTeamID, n+(i*15))
							QueueSpawn(groupunit[math.ceil(i/newTypeNumber)]..scavconfig.unitnamesuffix, posx, posy, posz, math_random(0,3),GaiaTeamID, n+90+(i*15))
						else
							QueueSpawn("scavengerdroppod_scav", posx, posy, posz, math_random(0,3),GaiaTeamID, n)
							QueueSpawn(groupunit[math.ceil(i/newTypeNumber)]..scavconfig.unitnamesuffix, posx, posy, posz, math_random(0,3),GaiaTeamID, n+90)
						end
					end
					--Spring.CreateUnit("scavengerdroppod_scav", posx, posy, posz, math_random(0,3),GaiaTeamID)
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

