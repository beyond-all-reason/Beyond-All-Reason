Spring.Echo("[Scavengers] Unit Spawner initialized")

local UnitSpawnChance = unitSpawnerModuleConfig.spawnchance

function BossWaveTimer(n)
	if not BossWaveTimeLeft then
		BossWaveTimeLeft = unitSpawnerModuleConfig.BossWaveTimeLeft
	end
	if not FinalSelfDChance then
		FinalSelfDChance = 60
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
			
			if #SpawnBeacons > 1 then
				for b = 1,1000 do
					local pickedBeaconTest = SpawnBeacons[math_random(1,#SpawnBeacons)]
					local _,_,_,pickedBeaconCaptureProgress = Spring.GetUnitHealth(pickedBeaconTest)
					if pickedBeaconCaptureProgress == 0 then
						pickedBeacon = pickedBeaconTest
						break
					else
						pickedBeacon = 1234567890
					end
				end
			elseif #SpawnBeacons == 1 then
				pickedBeacon = SpawnBeacons[1]
			end
			SpawnBeacons = nil
			
			if pickedBeacon == 1234567890 then
				return
			else
				if pickedBeacon then
					local posx,posy,posz = Spring.GetUnitPosition(pickedBeacon)
					local posy = Spring.GetGroundHeight(posx, posz)
					Spring.CreateUnit(bossunit, posx, posy, posz, math_random(0,3),GaiaTeamID)
					FinalBossUnitSpawned = true
					Spring.Echo("BOSS COMMANDER SPAWNED")
				elseif ScavengerStartboxExists == true then
					local posx = math.floor((ScavengerStartboxXMin + ScavengerStartboxXMax)/2)
					local posz = math.floor((ScavengerStartboxZMin + ScavengerStartboxZMax)/2)
					local posy = Spring.GetGroundHeight(posx, posz)
					Spring.CreateUnit(bossunit, posx, posy, posz, math_random(0,3),GaiaTeamID)
					FinalBossUnitSpawned = true
					Spring.Echo("BOSS COMMANDER SPAWNED")
				else
					local posx = math.floor(mapsizeX/2)
					local posz = math.floor(mapsizeZ/2)
					local posy = Spring.GetGroundHeight(posx, posz)
					Spring.CreateUnit(bossunit, posx, posy, posz, math_random(0,3),GaiaTeamID)
					FinalBossUnitSpawned = true
					Spring.Echo("BOSS COMMANDER SPAWNED")
				end
			end
			pickedBeacon = nil

		elseif (not unitSpawnerModuleConfig.FinalBossUnit) or FinalBossKilled == true then
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
	local x,y,z = Spring.GetUnitPosition(FinalBossUnitID)
	local posx = x + math_random(-256,256)
	local posz = z + math_random(-256,256)
	local posy = Spring.GetGroundHeight(posx, posz)
	local r = math_random(0,100)
	local rair = math_random(0, unitSpawnerModuleConfig.aircraftchance)

	if rair == 0 then
		if r <= 40 then
			minionUnit = T1AirUnits[math_random(1,#T1AirUnits)]..scavconfig.unitnamesuffix
		elseif r <= 80 then
			minionUnit = T2AirUnits[math_random(1,#T2AirUnits)]..scavconfig.unitnamesuffix
		elseif r <= 95 then
			minionUnit = T3AirUnits[math_random(1,#T3AirUnits)]..scavconfig.unitnamesuffix
		elseif r <= 100 then
			minionUnit = T4AirUnits[math_random(1,#T4AirUnits)]..scavconfig.unitnamesuffix
		else
			minionUnit = T0AirUnits[math_random(1,#T0AirUnits)]..scavconfig.unitnamesuffix
		end
	elseif posy > -20 then
		if r <= 40 then
			minionUnit = T1LandUnits[math_random(1,#T1LandUnits)]..scavconfig.unitnamesuffix
		elseif r <= 80 then
			minionUnit = T2LandUnits[math_random(1,#T2LandUnits)]..scavconfig.unitnamesuffix
		elseif r <= 95 then
			minionUnit = T3LandUnits[math_random(1,#T3LandUnits)]..scavconfig.unitnamesuffix
		elseif r <= 100 then
			minionUnit = T4LandUnits[math_random(1,#T4LandUnits)]..scavconfig.unitnamesuffix
		else
			minionUnit = T0LandUnits[math_random(1,#T0LandUnits)]..scavconfig.unitnamesuffix
		end
	elseif posy <= -20 then
		if r <= 40 then
			minionUnit = T1SeaUnits[math_random(1,#T1SeaUnits)]..scavconfig.unitnamesuffix
		elseif r <= 80 then
			minionUnit = T2SeaUnits[math_random(1,#T2SeaUnits)]..scavconfig.unitnamesuffix
		elseif r <= 95 then
			minionUnit = T3SeaUnits[math_random(1,#T3SeaUnits)]..scavconfig.unitnamesuffix
		elseif r <= 100 then
			minionUnit = T4SeaUnits[math_random(1,#T4SeaUnits)]..scavconfig.unitnamesuffix
		else
			minionUnit = T0SeaUnits[math_random(1,#T0SeaUnits)]..scavconfig.unitnamesuffix
		end
	end
	Spring.CreateUnit(minionUnit, posx, posy, posz, math_random(0,3),GaiaTeamID)
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
				local groupsize = (globalScore / unitSpawnerModuleConfig.globalscoreperoneunit)*spawnmultiplier
				local aircraftchance = math_random(0,unitSpawnerModuleConfig.aircraftchance)
				local aircraftchanceonsea = math_random(0,unitSpawnerModuleConfig.chanceforaircraftonsea)
				local bossaircraftchance = math_random(0,unitSpawnerModuleConfig.aircraftchance*5)
				local spawnTier = math_random(1,100)

				if (posy <= -20 and aircraftchanceonsea == 0) or (aircraftchance == 0 and (not BossWaveTimeLeft)) or (bossaircraftchance == 0 and BossWaveTimeLeft and BossWaveTimeLeft > 0) then
					if unitSpawnerModuleConfig.bossFightEnabled and BossWaveTimeLeft then
						if spawnTier < 50 then
							groupunit = T4AirUnits
						else
							groupunit = T3AirUnits
						end
						groupsize = groupsize*unitSpawnerModuleConfig.airmultiplier*unitSpawnerModuleConfig.t4multiplier
					elseif spawnTier <= TierSpawnChances.T0 then
						groupunit = T0AirUnits
						groupsize = groupsize*unitSpawnerModuleConfig.airmultiplier*unitSpawnerModuleConfig.t0multiplier
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 then
						groupunit = T1AirUnits
						groupsize = groupsize*unitSpawnerModuleConfig.airmultiplier*unitSpawnerModuleConfig.t1multiplier
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 then
						groupunit = T2AirUnits
						groupsize = groupsize*unitSpawnerModuleConfig.airmultiplier*unitSpawnerModuleConfig.t2multiplier
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 then
						groupunit = T3AirUnits
						groupsize = groupsize*unitSpawnerModuleConfig.airmultiplier*unitSpawnerModuleConfig.t3multiplier
						-- ScavSendMessage("Warning! Scavengers dropped group of ".. UDN[groupunit].humanName .."s")
						-- if math_random(0,2) == 0 then
							-- ScavSendNotification("scav_scavheavyairdetected")
						-- end
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 + TierSpawnChances.T4 then
						groupunit = T4AirUnits
						groupsize = groupsize*unitSpawnerModuleConfig.airmultiplier*unitSpawnerModuleConfig.t4multiplier
						-- ScavSendNotification("scav_scavbossdetected")
					else
						groupunit = T0AirUnits
						groupsize = groupsize*unitSpawnerModuleConfig.airmultiplier*unitSpawnerModuleConfig.t0multiplier
					end
				elseif posy > -20 then
					if unitSpawnerModuleConfig.bossFightEnabled and BossWaveTimeLeft then
						if spawnTier < 50 then
							groupunit = T4LandUnits
						else
							groupunit = T3LandUnits
						end
						groupsize = groupsize*unitSpawnerModuleConfig.landmultiplier*unitSpawnerModuleConfig.t4multiplier
					elseif spawnTier <= TierSpawnChances.T0 then
						groupunit = T0LandUnits
						groupsize = groupsize*unitSpawnerModuleConfig.landmultiplier*unitSpawnerModuleConfig.t0multiplier
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 then
						groupunit = T1LandUnits
						groupsize = groupsize*unitSpawnerModuleConfig.landmultiplier*unitSpawnerModuleConfig.t1multiplier
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 then
						groupunit = T2LandUnits
						groupsize = groupsize*unitSpawnerModuleConfig.landmultiplier*unitSpawnerModuleConfig.t2multiplier
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 then
						groupunit = T3LandUnits
						groupsize = groupsize*unitSpawnerModuleConfig.landmultiplier*unitSpawnerModuleConfig.t3multiplier
							-- local c = math_random(0,2)
							-- if c == 0 then
								-- ScavSendMessage("Warning! Scavengers dropped group of ".. UDN[groupunit].humanName .."s")
								-- local s = math_random(0,4)
								-- if s == 0 then
									-- ScavSendNotification("scav_scavtech3")
								-- elseif s == 1 then
									-- ScavSendNotification("scav_scavtech3b")
								-- elseif s == 2 then
									-- ScavSendNotification("scav_scavtech3c")
								-- elseif s == 3 then
									-- ScavSendNotification("scav_scavtech3d")
								-- else
									-- ScavSendNotification("scav_scavtech3e")
								-- end
							-- else
								-- ScavSendMessage("Warning! Scavengers dropped group of ".. UDN[groupunit].humanName .."s")
							-- end

					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 + TierSpawnChances.T4 then
						groupunit = T4LandUnits
						groupsize = groupsize*unitSpawnerModuleConfig.landmultiplier*unitSpawnerModuleConfig.t4multiplier
						-- ScavSendNotification("scav_scavbossdetected")
					else
						groupunit = T0LandUnits
						groupsize = groupsize*unitSpawnerModuleConfig.landmultiplier*unitSpawnerModuleConfig.t0multiplier
					end
				elseif posy <= -20 then
					if unitSpawnerModuleConfig.bossFightEnabled and BossWaveTimeLeft then
						if spawnTier < 50 then
							groupunit = T4SeaUnits
						else
							groupunit = T3SeaUnits
						end
						groupsize = groupsize*unitSpawnerModuleConfig.seamultiplier*unitSpawnerModuleConfig.t4multiplier
					elseif spawnTier <= TierSpawnChances.T0 then
						groupunit = T0SeaUnits
						groupsize = groupsize*unitSpawnerModuleConfig.seamultiplier*unitSpawnerModuleConfig.t0multiplier
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 then
						groupunit = T1SeaUnits
						groupsize = groupsize*unitSpawnerModuleConfig.seamultiplier*unitSpawnerModuleConfig.t1multiplier
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 then
						groupunit = T2SeaUnits
						groupsize = groupsize*unitSpawnerModuleConfig.seamultiplier*unitSpawnerModuleConfig.t2multiplier
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 then
						groupunit = T3SeaUnits
						groupsize = groupsize*unitSpawnerModuleConfig.seamultiplier*unitSpawnerModuleConfig.t3multiplier
						-- ScavSendMessage("Warning! Scavengers dropped group of ".. UDN[groupunit].humanName .."s")
						-- if math_random(0,2) == 0 then
							-- ScavSendNotification("scav_scavheavyshipsdetected")
						-- end
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 + TierSpawnChances.T4 then
						groupunit = T4SeaUnits
						groupsize = groupsize*unitSpawnerModuleConfig.seamultiplier*unitSpawnerModuleConfig.t4multiplier
						-- ScavSendNotification("scav_scavbossdetected")
					else
						groupunit = T0SeaUnits
						groupsize = groupsize*unitSpawnerModuleConfig.seamultiplier*unitSpawnerModuleConfig.t0multiplier
					end
				end

				local groupsize = math.ceil(groupsize*bestTeamGroupMultiplier*(teamcount/2))
				for i=1, groupsize do
					local posx = posx+math_random(-160,160)
					local posz = posz+math_random(-160,160)
					local newposy = Spring.GetGroundHeight(posx, posz)
					if posy >= -20 and newposy >= -20 then
						if i then
							QueueSpawn("scavengerdroppod_scav", posx, posy, posz, math_random(0,3),GaiaTeamID, n+(i*15))
							QueueSpawn(groupunit[math_random(1,#groupunit)]..scavconfig.unitnamesuffix, posx, posy, posz, math_random(0,3),GaiaTeamID, n+90+(i*15))
						else
							QueueSpawn("scavengerdroppod_scav", posx, posy, posz, math_random(0,3),GaiaTeamID, n)
							QueueSpawn(groupunit[math_random(1,#groupunit)]..scavconfig.unitnamesuffix, posx, posy, posz, math_random(0,3),GaiaTeamID, n+90)
						end
					elseif posy < -20 and newposy < -20 then
						if i then
							QueueSpawn("scavengerdroppod_scav", posx, posy, posz, math_random(0,3),GaiaTeamID, n+(i*15))
							QueueSpawn(groupunit[math_random(1,#groupunit)]..scavconfig.unitnamesuffix, posx, posy, posz, math_random(0,3),GaiaTeamID, n+90+(i*15))
						else
							QueueSpawn("scavengerdroppod_scav", posx, posy, posz, math_random(0,3),GaiaTeamID, n)
							QueueSpawn(groupunit[math_random(1,#groupunit)]..scavconfig.unitnamesuffix, posx, posy, posz, math_random(0,3),GaiaTeamID, n+90)
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

