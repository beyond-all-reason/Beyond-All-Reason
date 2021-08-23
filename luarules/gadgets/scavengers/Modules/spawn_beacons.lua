local BeaconSpawnChance = unitSpawnerModuleConfig.beaconspawnchance
local staticUnitList = VFS.Include("luarules/gadgets/scavengers/Configs/BYAR/UnitLists/staticunits.lua")
local airUnitList = VFS.Include("luarules/gadgets/scavengers/Configs/BYAR/UnitLists/air.lua")
local landUnitList = VFS.Include("luarules/gadgets/scavengers/Configs/BYAR/UnitLists/land.lua")
local seaUnitList = VFS.Include("luarules/gadgets/scavengers/Configs/BYAR/UnitLists/sea.lua")

function SpawnBeacon(n)
	if n and n > 30 then
		local BeaconSpawnChance = math_random(0,BeaconSpawnChance)
		if numOfSpawnBeacons <= unitSpawnerModuleConfig.minimumspawnbeacons then
			BeaconSpawnChance = 0
		end
		if BossWaveTimeLeft and BossWaveTimeLeft < 1 then
			BeaconSpawnChance = 1 -- can't spawn
		end
		if BeaconSpawnChance == 0 or canSpawnBeaconHere == false then
			local posx = math_random(128,mapsizeX-128)
			local posz = math_random(128,mapsizeZ-128)
			local posy = Spring.GetGroundHeight(posx, posz)
			beacontype = "normal"
			posradius = 128

			canSpawnBeaconHere = posCheck(posx, posy, posz, 80)
			if canSpawnBeaconHere then
				if globalScore then
					--local g = math_random(0,20)
					if scavengerGamePhase == "initial" then
						canSpawnBeaconHere = posLosCheck(posx, posy, posz,posradius)
					else
						if numOfSpawnBeacons <= 1  then
							canSpawnBeaconHere = posOccupied(posx, posy, posz, posradius)
						elseif numOfSpawnBeacons <= unitSpawnerModuleConfig.minimumspawnbeacons*0.3 then
							canSpawnBeaconHere = posLosCheckOnlyLOS(posx, posy, posz,posradius)
						elseif numOfSpawnBeacons <= unitSpawnerModuleConfig.minimumspawnbeacons*0.6 then
							canSpawnBeaconHere = posLosCheckNoRadar(posx, posy, posz,posradius)
						else
							canSpawnBeaconHere = posLosCheck(posx, posy, posz,posradius)
						end
					end
				end
			end

			if canSpawnBeaconHere then
				BeaconSpawnChance = unitSpawnerModuleConfig.beaconspawnchance
				Spring.CreateUnit("scavengerdroppodbeacon_scav", posx, posy, posz, math_random(0,3),GaiaTeamID)
				-- if scavengerGamePhase == "initial" then
				-- 	if math.random(0,1) == 0 then
				-- 		if Spring.GetGroundHeight(posx-64, posz) > -20 then
				-- 			QueueSpawn(landUnitList.T0[math_random(1,#landUnitList.T0)], posx-64, posy, posz, math_random(0,3),GaiaTeamID, n+150, false)
				-- 		else
				-- 			QueueSpawn(seaUnitList.T0[math_random(1,#seaUnitList.T0)], posx-64, posy, posz, math_random(0,3),GaiaTeamID, n+150, false)
				-- 		end
				-- 	end
				-- 	if math.random(0,1) == 0 then
				-- 		if Spring.GetGroundHeight(posx+64, posz) > -20 then
				-- 			QueueSpawn(landUnitList.T0[math_random(1,#landUnitList.T0)], posx+64, posy, posz, math_random(0,3),GaiaTeamID, n+150, false)
				-- 		else
				-- 			QueueSpawn(seaUnitList.T0[math_random(1,#seaUnitList.T0)], posx+64, posy, posz, math_random(0,3),GaiaTeamID, n+150, false)
				-- 		end
				-- 	end
				-- 	if math.random(0,1) == 0 then
				-- 		if Spring.GetGroundHeight(posx, posz-64) > -20 then
				-- 			QueueSpawn(landUnitList.T0[math_random(1,#landUnitList.T0)], posx, posy, posz-64, math_random(0,3),GaiaTeamID, n+150, false)
				-- 		else
				-- 			QueueSpawn(seaUnitList.T0[math_random(1,#seaUnitList.T0)], posx, posy, posz-64, math_random(0,3),GaiaTeamID, n+150, false)
				-- 		end
				-- 	end
				-- 	if math.random(0,1) == 0 then
				-- 		if Spring.GetGroundHeight(posx, posz+64) > -20 then
				-- 			QueueSpawn(landUnitList.T0[math_random(1,#landUnitList.T0)], posx, posy, posz+64, math_random(0,3),GaiaTeamID, n+150, false)
				-- 		else
				-- 			QueueSpawn(seaUnitList.T0[math_random(1,#seaUnitList.T0)], posx, posy, posz+64, math_random(0,3),GaiaTeamID, n+150, false)
				-- 		end
				-- 	end
				-- end
				if unitSpawnerModuleConfig.beacondefences == true and scavengerGamePhase ~= "initial" then
					Spring.CreateUnit("scavengerdroppod_scav", posx, posy, posz, math_random(0,3),GaiaTeamID)
					local spawnTier = math_random(1,100)
					if spawnTier <= TierSpawnChances.T0 then
						grouptier = staticUnitList.BeaconDefences.T0
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 then
						grouptier = staticUnitList.BeaconDefences.T1
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 then
						grouptier = staticUnitList.BeaconDefences.T2
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 + TierSpawnChances.T4 then
						grouptier = staticUnitList.BeaconDefences.T3
					else
						grouptier = staticUnitList.BeaconDefences.T0
					end
					if spawnTier <= TierSpawnChances.T0 then
						grouptiersea = staticUnitList.StartboxDefencesSea.T0
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 then
						grouptiersea = staticUnitList.StartboxDefencesSea.T1
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 then
						grouptiersea = staticUnitList.StartboxDefencesSea.T2
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 + TierSpawnChances.T4 then
						grouptiersea = staticUnitList.StartboxDefencesSea.T3
					else
						grouptiersea = staticUnitList.StartboxDefencesSea.T0
					end

					Spring.CreateUnit("scavengerdroppod_scav", posx-128, posy, posz, math_random(0,3),GaiaTeamID)
					Spring.CreateUnit("scavengerdroppod_scav", posx+128, posy, posz, math_random(0,3),GaiaTeamID)
					Spring.CreateUnit("scavengerdroppod_scav", posx, posy, posz+128, math_random(0,3),GaiaTeamID)
					Spring.CreateUnit("scavengerdroppod_scav", posx, posy, posz-128, math_random(0,3),GaiaTeamID)

					local posy = Spring.GetGroundHeight(posx-128, posz)
					if posy > 0 then
						local turret = grouptier[math_random(1,#grouptier)]
						QueueSpawn(turret, posx-128, posy, posz, math_random(0,3),GaiaTeamID, n+150, false)
					else
						local turretSea = grouptiersea[math_random(1,#grouptiersea)]
						QueueSpawn(turretSea, posx-128, posy, posz, math_random(0,3),GaiaTeamID, n+150, false)
					end


					local posy = Spring.GetGroundHeight(posx+128, posz)
					if posy > 0 then
						local turret = grouptier[math_random(1,#grouptier)]
						QueueSpawn(turret, posx+128, posy, posz, math_random(0,3),GaiaTeamID, n+150, false)
					else
						local turretSea = grouptiersea[math_random(1,#grouptiersea)]
						QueueSpawn(turretSea, posx+128, posy, posz, math_random(0,3),GaiaTeamID, n+150, false)
					end


					local posy = Spring.GetGroundHeight(posx, posz+128)
					if posy > 0 then
						local turret = grouptier[math_random(1,#grouptier)]
						QueueSpawn(turret, posx, posy, posz+128, math_random(0,3),GaiaTeamID, n+150, false)
					else
						local turretSea = grouptiersea[math_random(1,#grouptiersea)]
						QueueSpawn(turretSea, posx, posy, posz+128, math_random(0,3),GaiaTeamID, n+150, false)
					end


					local posy = Spring.GetGroundHeight(posx, posz-128)
					if posy > 0 then
						local turret = grouptier[math_random(1,#grouptier)]
						QueueSpawn(turret, posx, posy, posz-128, math_random(0,3),GaiaTeamID, n+150, false)
					else
						local turretSea = grouptiersea[math_random(1,#grouptiersea)]
						QueueSpawn(turretSea, posx, posy, posz-128, math_random(0,3),GaiaTeamID, n+150, false)
					end
					grouptier = nil
					grouptiersea = nil
				end
			end
		else
			BeaconSpawnChance = BeaconSpawnChance - 1
			if BeaconSpawnChance < 1 then
				BeaconSpawnChance = 1
			end
		end
	end
end
