Spring.Echo("[Scavengers] Unit Spawner initialized")

UnitLists = VFS.DirList('luarules/gadgets/scavengers/Configs/'..GameShortName..'/UnitLists/','*.lua')
for i = 1,#UnitLists do
	VFS.Include(UnitLists[i])
	Spring.Echo("Scav Units Directory: " ..UnitLists[i])
end
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
		local units = Spring.GetTeamUnits(GaiaTeamID)
		FinalSelfDChance = FinalSelfDChance - 1
		if FinalSelfDChance < 2 then
			FinalSelfDChance = 2
		end
		for i = 1,#units do
			local r = math.random(1,FinalSelfDChance)
			if r == 1 then
				Spring.DestroyUnit(units[i],false,false)
			end
		end 
	end
end

function UnitGroupSpawn(n)
	if n > 9000 then
		local gaiaUnitCount = Spring.GetTeamUnitCount(GaiaTeamID)
		if BossWaveTimeLeft then
			ActualUnitSpawnChance = math.random(0,UnitSpawnChance*3)
		else
			ActualUnitSpawnChance = math.random(0,UnitSpawnChance)
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
			
			local pickedBeacon = SpawnBeacons[math.random(1,#SpawnBeacons)]
			posx,posy,posz = Spring.GetUnitPosition(pickedBeacon)
			posy = Spring.GetGroundHeight(posx, posz)
			local nearestEnemy = Spring.GetUnitNearestEnemy(pickedBeacon, 99999, false)
			local nearestEnemyTeam = Spring.GetUnitTeam(nearestEnemy)
			if nearestEnemyTeam == bestTeam then
				bestTeamGroupMultiplier = 1.25
			else
				bestTeamGroupMultiplier = 0.75
			end
			canSpawnHere = true
			Spring.DestroyUnit(pickedBeacon,false,false)
			SpawnBeacon(n)
			local posradius = 160
			
			if canSpawnHere then
				
				if BossWaveTimeLeft then
					UnitSpawnChance = math.ceil(unitSpawnerModuleConfig.spawnchance / (teamcount/2))
				else
					UnitSpawnChance = unitSpawnerModuleConfig.spawnchance
				end
				
				if (globalScore/unitSpawnerModuleConfig.globalscoreperoneunit)*spawnmultiplier < #scavengerunits then
					UnitSpawnChance = math.ceil(UnitSpawnChance/2)
				end
				local groupsize = (globalScore / unitSpawnerModuleConfig.globalscoreperoneunit)*spawnmultiplier
				local aircraftchance = math.random(0,unitSpawnerModuleConfig.aircraftchance)
				local aircraftchanceonsea = math.random(0,unitSpawnerModuleConfig.chanceforaircraftonsea)
				local bossaircraftchance = math.random(0,unitSpawnerModuleConfig.aircraftchance*5)
				local spawnTier = math.random(1,100)
				
				if (posy <= -20 and aircraftchanceonsea ~= 0) or (aircraftchance == 0 and (not BossWaveTimeLeft)) or (bossaircraftchance == 0 and BossWaveTimeLeft and BossWaveTimeLeft > 0) then
					if unitSpawnerModuleConfig.bossFightEnabled and BossWaveTimeLeft and BossWaveTimeLeft > 0 then
						groupunit = T4AirUnits[math.random(1,#T4AirUnits)]
						groupsize = groupsize*unitSpawnerModuleConfig.airmultiplier*unitSpawnerModuleConfig.t4multiplier
					elseif spawnTier <= TierSpawnChances.T0 then
						groupunit = T0AirUnits[math.random(1,#T0AirUnits)]
						groupsize = groupsize*unitSpawnerModuleConfig.airmultiplier*unitSpawnerModuleConfig.t0multiplier
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 then
						groupunit = T1AirUnits[math.random(1,#T1AirUnits)]
						groupsize = groupsize*unitSpawnerModuleConfig.airmultiplier*unitSpawnerModuleConfig.t1multiplier
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 then
						groupunit = T2AirUnits[math.random(1,#T2AirUnits)]
						groupsize = groupsize*unitSpawnerModuleConfig.airmultiplier*unitSpawnerModuleConfig.t2multiplier
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 then
						groupunit = T3AirUnits[math.random(1,#T3AirUnits)]
						groupsize = groupsize*unitSpawnerModuleConfig.airmultiplier*unitSpawnerModuleConfig.t3multiplier
						ScavSendMessage("Warning! Scavengers dropped group of ".. UDN[groupunit].humanName .."s")
						if math.random(0,2) == 0 then
							ScavSendNotification("scav_scavheavyairdetected")
						end
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 + TierSpawnChances.T4 then
						groupunit = T4AirUnits[math.random(1,#T4AirUnits)]
						groupsize = groupsize*unitSpawnerModuleConfig.airmultiplier*unitSpawnerModuleConfig.t4multiplier
						ScavSendNotification("scav_scavbossdetected")
					else
						groupunit = T0AirUnits[math.random(1,#T0AirUnits)]
						groupsize = groupsize*unitSpawnerModuleConfig.airmultiplier*unitSpawnerModuleConfig.t0multiplier
					end
				elseif posy > -20 then
					if unitSpawnerModuleConfig.bossFightEnabled and BossWaveTimeLeft and BossWaveTimeLeft > 0 then
						groupunit = T4LandUnits[math.random(1,#T4LandUnits)]
						groupsize = groupsize*unitSpawnerModuleConfig.landmultiplier*unitSpawnerModuleConfig.t4multiplier
					elseif spawnTier <= TierSpawnChances.T0 then
						groupunit = T0LandUnits[math.random(1,#T0LandUnits)]
						groupsize = groupsize*unitSpawnerModuleConfig.landmultiplier*unitSpawnerModuleConfig.t0multiplier
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 then
						groupunit = T1LandUnits[math.random(1,#T1LandUnits)]
						groupsize = groupsize*unitSpawnerModuleConfig.landmultiplier*unitSpawnerModuleConfig.t1multiplier
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 then
						groupunit = T2LandUnits[math.random(1,#T2LandUnits)]
						groupsize = groupsize*unitSpawnerModuleConfig.landmultiplier*unitSpawnerModuleConfig.t2multiplier
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 then
						groupunit = T3LandUnits[math.random(1,#T3LandUnits)]
						groupsize = groupsize*unitSpawnerModuleConfig.landmultiplier*unitSpawnerModuleConfig.t3multiplier
							local c = math.random(0,2)
							if c == 0 then
								ScavSendMessage("Warning! Scavengers dropped group of ".. UDN[groupunit].humanName .."s")
								local s = math.random(0,4)
								if s == 0 then
									ScavSendNotification("scav_scavtech3")
								elseif s == 1 then
									ScavSendNotification("scav_scavtech3b")
								elseif s == 2 then
									ScavSendNotification("scav_scavtech3c")
								elseif s == 3 then
									ScavSendNotification("scav_scavtech3d")
								else
									ScavSendNotification("scav_scavtech3e")
								end	
							else
								ScavSendMessage("Warning! Scavengers dropped group of ".. UDN[groupunit].humanName .."s")
							end
								
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 + TierSpawnChances.T4 then
						groupunit = T4LandUnits[math.random(1,#T4LandUnits)]
						groupsize = groupsize*unitSpawnerModuleConfig.landmultiplier*unitSpawnerModuleConfig.t4multiplier
						ScavSendNotification("scav_scavbossdetected")
					else
						groupunit = T0LandUnits[math.random(1,#T0LandUnits)]
						groupsize = groupsize*unitSpawnerModuleConfig.landmultiplier*unitSpawnerModuleConfig.t0multiplier
					end
				elseif posy <= -20 then
					if unitSpawnerModuleConfig.bossFightEnabled and BossWaveTimeLeft and BossWaveTimeLeft > 0 then
						groupunit = T4SeaUnits[math.random(1,#T4SeaUnits)]
						groupsize = groupsize*unitSpawnerModuleConfig.seamultiplier*unitSpawnerModuleConfig.t4multiplier
					elseif spawnTier <= TierSpawnChances.T0 then
						groupunit = T0SeaUnits[math.random(1,#T0SeaUnits)]
						groupsize = groupsize*unitSpawnerModuleConfig.seamultiplier*unitSpawnerModuleConfig.t0multiplier
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 then
						groupunit = T1SeaUnits[math.random(1,#T1SeaUnits)]
						groupsize = groupsize*unitSpawnerModuleConfig.seamultiplier*unitSpawnerModuleConfig.t1multiplier
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 then
						groupunit = T2SeaUnits[math.random(1,#T2SeaUnits)]
						groupsize = groupsize*unitSpawnerModuleConfig.seamultiplier*unitSpawnerModuleConfig.t2multiplier
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 then
						groupunit = T3SeaUnits[math.random(1,#T3SeaUnits)]
						groupsize = groupsize*unitSpawnerModuleConfig.seamultiplier*unitSpawnerModuleConfig.t3multiplier
						ScavSendMessage("Warning! Scavengers dropped group of ".. UDN[groupunit].humanName .."s")
						if math.random(0,2) == 0 then
							ScavSendNotification("scav_scavheavyshipsdetected")
						end
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 + TierSpawnChances.T4 then
						groupunit = T4SeaUnits[math.random(1,#T4SeaUnits)]
						groupsize = groupsize*unitSpawnerModuleConfig.seamultiplier*unitSpawnerModuleConfig.t4multiplier
						ScavSendNotification("scav_scavbossdetected")
					else
						groupunit = T0SeaUnits[math.random(1,#T0SeaUnits)]
						groupsize = groupsize*unitSpawnerModuleConfig.seamultiplier*unitSpawnerModuleConfig.t0multiplier
					end
				end
				
				local groupsize = math.ceil(groupsize*bestTeamGroupMultiplier*math.floor(teamcount/2))
				for i=1, groupsize do
					local posx = posx+math.random(-160,160)
					local posz = posz+math.random(-160,160)
					Spring.CreateUnit(groupunit..scavconfig.unitnamesuffix, posx, posy, posz, math.random(0,3),GaiaTeamID)
					Spring.CreateUnit("scavengerdroppod_scav", posx, posy, posz, math.random(0,3),GaiaTeamID)
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