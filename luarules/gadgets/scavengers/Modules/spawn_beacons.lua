local BeaconSpawnChance = unitSpawnerModuleConfig.beaconspawnchance
local staticUnitList = VFS.Include("luarules/gadgets/scavengers/Configs/BYAR/UnitLists/staticunits.lua")
local airUnitList = VFS.Include("luarules/gadgets/scavengers/Configs/BYAR/UnitLists/air.lua")
local landUnitList = VFS.Include("luarules/gadgets/scavengers/Configs/BYAR/UnitLists/land.lua")
local seaUnitList = VFS.Include("luarules/gadgets/scavengers/Configs/BYAR/UnitLists/sea.lua")
local constructorUnitList = VFS.Include("luarules/gadgets/scavengers/Configs/BYAR/UnitLists/constructors.lua")

function SpawnBeacon(n)
	if n and n > 30 then
		if numOfSpawnBeacons < unitSpawnerModuleConfig.minimumspawnbeacons then
			BeaconSpawnChance = 0
		elseif BeaconSpawnChance > 0 then
			BeaconSpawnChance = math_random(0,BeaconSpawnChance)
		end
		if BossWaveTimeLeft and BossWaveTimeLeft < 1 then
			BeaconSpawnChance = 1 -- can't spawn
		end
		if BeaconSpawnChance == 0 or canSpawnBeaconHere == false then
			for i = 1,100 do
				local posx = math_random(192,mapsizeX-192)
				local posz = math_random(192,mapsizeZ-192)
				local posy = Spring.GetGroundHeight(posx, posz)

				canSpawnBeaconHere = posCheck(posx, posy, posz, 192)
				if canSpawnBeaconHere then
					canSpawnBeaconHere = posOccupied(posx, posy, posz, 192)
				end
				if canSpawnBeaconHere then
					if globalScore then
						--local g = math_random(0,20)
						if Spring.GetModOptions().disable_fogofwar then -- doesn't fix situation when fog of war is removed by a cheat
							canSpawnBeaconHere = posOccupied(posx, posy, posz, 384)
						elseif scavengerGamePhase == "initial" then
							canSpawnBeaconHere = posLosCheck(posx, posy, posz, 192)
						else
							if numOfSpawnBeacons == 0 then
								canSpawnBeaconHere = posOccupied(posx, posy, posz, 192)
							elseif numOfSpawnBeacons < unitSpawnerModuleConfig.minimumspawnbeacons*0.2 then
								canSpawnBeaconHere = posLosCheckOnlyLOS(posx, posy, posz,192)
							elseif numOfSpawnBeacons < unitSpawnerModuleConfig.minimumspawnbeacons*0.4 then
								canSpawnBeaconHere = posLosCheckNoRadar(posx, posy, posz,192)
							else
								canSpawnBeaconHere = posLosCheck(posx, posy, posz,192)
							end
						end
					end
				end
				
				if canSpawnBeaconHere then
					BeaconSpawnChance = unitSpawnerModuleConfig.beaconspawnchance
					Spring.CreateUnit("scavengerdroppodbeacon_scav", posx, posy, posz, math_random(0,3),GaiaTeamID)
					local spawnTier = math_random(1,100)
					if spawnTier <= TierSpawnChances.T0 then
						grouptier = landUnitList.T0
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 then
						grouptier = landUnitList.T1
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 then
						grouptier = landUnitList.T2
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 then
						grouptier = landUnitList.T3
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 + TierSpawnChances.T4 then
						grouptier = landUnitList.T4
					else
						grouptier = landUnitList.T0
					end
					if spawnTier <= TierSpawnChances.T0 then
						grouptiersea = seaUnitList.T0
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 then
						grouptiersea = seaUnitList.T1
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 then
						grouptiersea = seaUnitList.T2
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 then
						grouptiersea = seaUnitList.T3
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 + TierSpawnChances.T4 then
						grouptiersea = seaUnitList.T4
					else
						grouptiersea = seaUnitList.T0
					end
					


					if Spring.GetGroundHeight(posx-64, posz-64) > -20 then
						if scavengerGamePhase ~= "initial" or math.random(0,3) == 0 then
							QueueSpawn(grouptier[math_random(1,#grouptier)], posx-128+math.random(-64,64), posy, posz-128+math.random(-64,64), math_random(0,3),GaiaTeamID, n+150, false)
						end
						if scavengerGamePhase ~= "initial" or math.random(0,3) == 0 then
							QueueSpawn(constructorUnitList.Resurrectors[math_random(1,#constructorUnitList.Resurrectors)], posx-64+math.random(-64,64), posy, posz-64+math.random(-64,64), math_random(0,3),GaiaTeamID, n+150, false)
						end
					else
						if scavengerGamePhase ~= "initial" or math.random(0,3) == 0 then
							QueueSpawn(grouptiersea[math_random(1,#grouptiersea)], posx-128+math.random(-64,64), posy, posz-128+math.random(-64,64), math_random(0,3),GaiaTeamID, n+150, false)
						end
						if scavengerGamePhase ~= "initial" or math.random(0,3) == 0 then
							QueueSpawn(constructorUnitList.ResurrectorsSea[math_random(1,#constructorUnitList.ResurrectorsSea)], posx-64+math.random(-64,64), posy, posz-64+math.random(-64,64), math_random(0,3),GaiaTeamID, n+150, false)
						end
					end

					if Spring.GetGroundHeight(posx-64, posz+64) > -20 then
						if scavengerGamePhase ~= "initial" or math.random(0,3) == 0 then
							QueueSpawn(grouptier[math_random(1,#grouptier)], posx-128+math.random(-64,64), posy, posz+128+math.random(-64,64), math_random(0,3),GaiaTeamID, n+150, false)
						end
						if scavengerGamePhase ~= "initial" or math.random(0,3) == 0 then
							QueueSpawn(constructorUnitList.Resurrectors[math_random(1,#constructorUnitList.Resurrectors)], posx-64+math.random(-64,64), posy, posz+64+math.random(-64,64), math_random(0,3),GaiaTeamID, n+150, false)
						end
					else
						if scavengerGamePhase ~= "initial" or math.random(0,3) == 0 then
							QueueSpawn(grouptiersea[math_random(1,#grouptiersea)], posx-128+math.random(-64,64), posy, posz+128+math.random(-64,64), math_random(0,3),GaiaTeamID, n+150, false)
						end
						if scavengerGamePhase ~= "initial" or math.random(0,3) == 0 then
							QueueSpawn(constructorUnitList.ResurrectorsSea[math_random(1,#constructorUnitList.ResurrectorsSea)], posx-64+math.random(-64,64), posy, posz+64+math.random(-64,64), math_random(0,3),GaiaTeamID, n+150, false)
						end
					end

					if Spring.GetGroundHeight(posx+64, posz+64) > -20 then
						if scavengerGamePhase ~= "initial" or math.random(0,3) == 0 then
							QueueSpawn(grouptier[math_random(1,#grouptier)], posx+128+math.random(-64,64), posy, posz+128+math.random(-64,64), math_random(0,3),GaiaTeamID, n+150, false)
						end
						if scavengerGamePhase ~= "initial" or math.random(0,3) == 0 then
							QueueSpawn(constructorUnitList.Resurrectors[math_random(1,#constructorUnitList.Resurrectors)], posx+64+math.random(-64,64), posy, posz+64+math.random(-64,64), math_random(0,3),GaiaTeamID, n+150, false)
						end
					else
						if scavengerGamePhase ~= "initial" or math.random(0,3) == 0 then
							QueueSpawn(grouptiersea[math_random(1,#grouptiersea)], posx+128+math.random(-64,64), posy, posz+128+math.random(-64,64), math_random(0,3),GaiaTeamID, n+150, false)
						end
						if scavengerGamePhase ~= "initial" or math.random(0,3) == 0 then
							QueueSpawn(constructorUnitList.ResurrectorsSea[math_random(1,#constructorUnitList.ResurrectorsSea)], posx+64+math.random(-64,64), posy, posz+64+math.random(-64,64), math_random(0,3),GaiaTeamID, n+150, false)
						end
					end

					if Spring.GetGroundHeight(posx+64, posz-64) > -20 then
						if scavengerGamePhase ~= "initial" or math.random(0,3) == 0 then
							QueueSpawn(grouptier[math_random(1,#grouptier)], posx+128+math.random(-64,64), posy, posz-128+math.random(-64,64), math_random(0,3),GaiaTeamID, n+150, false)
						end
						if scavengerGamePhase ~= "initial" or math.random(0,3) == 0 then
							QueueSpawn(constructorUnitList.Resurrectors[math_random(1,#constructorUnitList.Resurrectors)], posx+64+math.random(-64,64), posy, posz-64+math.random(-64,64), math_random(0,3),GaiaTeamID, n+150, false)
						end
					else
						if scavengerGamePhase ~= "initial" or math.random(0,3) == 0 then
							QueueSpawn(grouptiersea[math_random(1,#grouptiersea)], posx+128+math.random(-64,64), posy, posz-128+math.random(-64,64), math_random(0,3),GaiaTeamID, n+150, false)
						end
						if scavengerGamePhase ~= "initial" or math.random(0,3) == 0 then
							QueueSpawn(constructorUnitList.ResurrectorsSea[math_random(1,#constructorUnitList.ResurrectorsSea)], posx+64+math.random(-64,64), posy, posz-64+math.random(-64,64), math_random(0,3),GaiaTeamID, n+150, false)
						end
					end

					if scavengerGamePhase ~= "initial" or math.random(0,3) == 0 then
						if constructorControllerModuleConfig.useconstructors then
							local constructor = constructorUnitList.Constructors[math.random(#constructorUnitList.Constructors)]
							QueueSpawn(constructor, posx+math.random(-64,64), posy, posz+math.random(-64,64), math.random(0, 3), GaiaTeamID, n + 150)
						end
					end

					if unitSpawnerModuleConfig.beacondefences == true then
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

						if scavengerGamePhase ~= "initial" then
							
							Spring.CreateUnit("scavengerdroppod_scav", posx, posy, posz, math_random(0,3),GaiaTeamID)
							Spring.CreateUnit("scavengerdroppod_scav", posx-192, posy, posz, math_random(0,3),GaiaTeamID)
							Spring.CreateUnit("scavengerdroppod_scav", posx+192, posy, posz, math_random(0,3),GaiaTeamID)
							Spring.CreateUnit("scavengerdroppod_scav", posx, posy, posz+192, math_random(0,3),GaiaTeamID)
							Spring.CreateUnit("scavengerdroppod_scav", posx, posy, posz-192, math_random(0,3),GaiaTeamID)
							Spring.CreateUnit("scavengerdroppod_scav", posx-192, posy, posz-192, math_random(0,3),GaiaTeamID)
							Spring.CreateUnit("scavengerdroppod_scav", posx+192, posy, posz+192, math_random(0,3),GaiaTeamID)
							Spring.CreateUnit("scavengerdroppod_scav", posx-192, posy, posz+192, math_random(0,3),GaiaTeamID)
							Spring.CreateUnit("scavengerdroppod_scav", posx+192, posy, posz-192, math_random(0,3),GaiaTeamID)
						end

						if scavengerGamePhase ~= "initial" or math.random(0,3) == 0 then
							local posy = Spring.GetGroundHeight(posx-128, posz)
							if posy > 0 then
								local turret = grouptier[math_random(1,#grouptier)]
								QueueSpawn(turret, posx-128+math.random(-64,64), posy, posz+math.random(-64,64), math_random(0,3),GaiaTeamID, n+150, false)
							else
								local turretSea = grouptiersea[math_random(1,#grouptiersea)]
								QueueSpawn(turretSea, posx-128+math.random(-64,64), posy, posz+math.random(-64,64), math_random(0,3),GaiaTeamID, n+150, false)
							end
						end

						if scavengerGamePhase ~= "initial" or math.random(0,3) == 0 then
							local posy = Spring.GetGroundHeight(posx+128, posz)
							if posy > 0 then
								local turret = grouptier[math_random(1,#grouptier)]
								QueueSpawn(turret, posx+128+math.random(-64,64), posy, posz+math.random(-64,64), math_random(0,3),GaiaTeamID, n+150, false)
							else
								local turretSea = grouptiersea[math_random(1,#grouptiersea)]
								QueueSpawn(turretSea, posx+128+math.random(-64,64), posy, posz+math.random(-64,64), math_random(0,3),GaiaTeamID, n+150, false)
							end
						end

						if scavengerGamePhase ~= "initial" or math.random(0,3) == 0 then
							local posy = Spring.GetGroundHeight(posx, posz+128)
							if posy > 0 then
								local turret = grouptier[math_random(1,#grouptier)]
								QueueSpawn(turret, posx+math.random(-64,64), posy, posz+128+math.random(-64,64), math_random(0,3),GaiaTeamID, n+150, false)
							else
								local turretSea = grouptiersea[math_random(1,#grouptiersea)]
								QueueSpawn(turretSea, posx+math.random(-64,64), posy, posz+128+math.random(-64,64), math_random(0,3),GaiaTeamID, n+150, false)
							end
						end

						if scavengerGamePhase ~= "initial" or math.random(0,3) == 0 then
							local posy = Spring.GetGroundHeight(posx, posz-128)
							if posy > 0 then
								local turret = grouptier[math_random(1,#grouptier)]
								QueueSpawn(turret, posx+math.random(-64,64), posy, posz-128+math.random(-64,64), math_random(0,3),GaiaTeamID, n+150, false)
							else
								local turretSea = grouptiersea[math_random(1,#grouptiersea)]
								QueueSpawn(turretSea, posx+math.random(-64,64), posy, posz-128+math.random(-64,64), math_random(0,3),GaiaTeamID, n+150, false)
							end
						end
						grouptier = nil
						grouptiersea = nil
					end
					break
				end
			end
		else
			BeaconSpawnChance = unitSpawnerModuleConfig.beaconspawnchance
			if BeaconSpawnChance < 1 then
				BeaconSpawnChance = 1
			end
		end
	end
end
