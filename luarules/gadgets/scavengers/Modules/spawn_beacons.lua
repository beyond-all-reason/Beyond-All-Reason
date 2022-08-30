local BeaconSpawnChance = scavconfig.unitSpawnerModuleConfig.beaconspawnchance

local xtable = {{-128, -64, -128}, {128, 64, 128}, {-128, -64, 0}, {128, 64, 0}}
local ztable = {{-128, -64, 0}, {-128, -64, 0}, {128, 64, -128}, {-128, -64, 128}}

local function countScavCommanders()
	local commanderCount = 0
	for i = 1,#constructorUnitList.Constructors do
		commanderCount = commanderCount + Spring.GetTeamUnitDefCount(ScavengerTeamID, UnitDefNames[constructorUnitList.Constructors[i]].id)
	end
	return commanderCount
end

local function spawnBeacon(n)
	if n and n > spawningStartFrame then
		if numOfSpawnBeacons < scavconfig.unitSpawnerModuleConfig.minimumspawnbeacons or numOfSpawnBeacons < 3 then
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
				canSpawnBeaconHere = positionCheckLibrary.FlatAreaCheck(posx, posy, posz, 192)
				if canSpawnBeaconHere then
					canSpawnBeaconHere = positionCheckLibrary.OccupancyCheck(posx, posy, posz, 192)
				end
				if canSpawnBeaconHere then
					canSpawnBeaconHere = positionCheckLibrary.ScavengerSpawnAreaCheck(posx, posy, posz, 192)
				end
				if canSpawnBeaconHere and numOfSpawnBeacons > scavconfig.unitSpawnerModuleConfig.minimumspawnbeacons*0.25 then
					if positionCheckLibrary.StartboxCheck(posx, posy, posz, 256, ScavengerAllyTeamID, true) == true then
						canSpawnBeaconHere = false
					end
				end
				if canSpawnBeaconHere then
					if globalScore then
						--local g = math_random(0,20)
						if scavengerGamePhase == "initial" then
							if numOfSpawnBeacons > scavconfig.unitSpawnerModuleConfig.minimumspawnbeacons then
								canSpawnBeaconHere = false
							else
								canSpawnBeaconHere = positionCheckLibrary.VisibilityCheckEnemy(posx, posy, posz, 192, ScavengerAllyTeamID, true, true, true)
							end
						else
							if numOfSpawnBeacons < 2 then
								canSpawnBeaconHere = positionCheckLibrary.StartboxCheck(posx, posy, posz, posradius, ScavengerAllyTeamID)
							elseif numOfSpawnBeacons == 2 then
								canSpawnBeaconHere = positionCheckLibrary.OccupancyCheck(posx, posy, posz, 750)
							elseif numOfSpawnBeacons < scavconfig.unitSpawnerModuleConfig.minimumspawnbeacons*0.2 then
								canSpawnBeaconHere = positionCheckLibrary.VisibilityCheckEnemy(posx, posy, posz, 192, ScavengerAllyTeamID, true, false, false)
							elseif numOfSpawnBeacons < scavconfig.unitSpawnerModuleConfig.minimumspawnbeacons*0.4 then
								canSpawnBeaconHere = positionCheckLibrary.VisibilityCheckEnemy(posx, posy, posz, 192, ScavengerAllyTeamID, true, true, false)
							else
								canSpawnBeaconHere = positionCheckLibrary.VisibilityCheckEnemy(posx, posy, posz, 192, ScavengerAllyTeamID, true, true, true)
							end
						end
					end
				end

				if canSpawnBeaconHere then
					BeaconSpawnChance = scavconfig.unitSpawnerModuleConfig.beaconspawnchance
					spawnQueueLibrary.AddToSpawnQueue(staticUnitList.scavSpawnEffectUnit, posx, posy, posz, math_random(0,3),ScavengerTeamID, n+1, false)
					spawnQueueLibrary.AddToSpawnQueue(staticUnitList.scavSpawnBeacon, posx, posy, posz, math_random(0,3),ScavengerTeamID, n+150, false)
					
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
					
					
					for y = 1,4 do
						for z = 1,4 do
							if scavengerGamePhase ~= "initial" or math.random(0,3) == 0 then
								if math.random(0,3) == 0 then
									local rx = posx+xtable[y][1]+math.random(-64,64)
									local rz = posz+ztable[y][1]+math.random(-64,64)
									if positionCheckLibrary.StartboxCheck(rx, Spring.GetGroundHeight(rx, rz), rz, 64, ScavengerAllyTeamID, true) == false then
										if Spring.GetGroundHeight(rx, rz) > -20 then
											spawnQueueLibrary.AddToSpawnQueue(grouptier[math_random(1,#grouptier)], rx, posy, rz, math_random(0,3),ScavengerTeamID, n+150, false)
										else
											spawnQueueLibrary.AddToSpawnQueue(grouptiersea[math_random(1,#grouptiersea)], rx, posy, rz, math_random(0,3),ScavengerTeamID, n+150, false)
										end
										Spring.CreateUnit(staticUnitList.scavSpawnEffectUnit, rx, posy, rz, math_random(0,3),ScavengerTeamID)
									end
								end
								if math.random(0,3) == 0 or scavengerGamePhase ~= "initial" then
									local rx = posx+xtable[y][2]+math.random(-64,64)
									local rz = posz+ztable[y][2]+math.random(-64,64)
									if positionCheckLibrary.StartboxCheck(rx, Spring.GetGroundHeight(rx, rz), rz, 64, ScavengerAllyTeamID, true) == false then
										if Spring.GetGroundHeight(rx, rz) > -20 then
											spawnQueueLibrary.AddToSpawnQueue(constructorUnitList.Resurrectors[math_random(1,#constructorUnitList.Resurrectors)], rx, posy, rz, math_random(0,3),ScavengerTeamID, n+150, false)
										else
											spawnQueueLibrary.AddToSpawnQueue(constructorUnitList.ResurrectorsSea[math_random(1,#constructorUnitList.ResurrectorsSea)], rx, posy, rz, math_random(0,3),ScavengerTeamID, n+150, false)
										end
										Spring.CreateUnit(staticUnitList.scavSpawnEffectUnit, rx, posy, rz, math_random(0,3),ScavengerTeamID)
									end
								end
							end
						end
					end
					

					if scavengerGamePhase ~= "initial" then
						if scavconfig.modules.constructorControllerModule and scavconfig.constructorControllerModuleConfig.useconstructors then
							local neededcommanders = scavconfig.constructorControllerModuleConfig.minimumconstructors - countScavCommanders()
							if neededcommanders > 0 then
								local constructor
								local spawnTierChance = math.random(1,100)
								if spawnTierChance <= TierSpawnChances.T0 + TierSpawnChances.T1 then
									constructor = constructorUnitList.ConstructorsT1[math.random(#constructorUnitList.ConstructorsT1)]
								elseif spawnTierChance <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 then
									constructor = constructorUnitList.ConstructorsT2[math.random(#constructorUnitList.ConstructorsT2)]
								elseif spawnTierChance <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 then
									constructor = constructorUnitList.ConstructorsT3[math.random(#constructorUnitList.ConstructorsT3)]
								elseif spawnTierChance <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 + TierSpawnChances.T4 then
									constructor = constructorUnitList.ConstructorsT4[math.random(#constructorUnitList.ConstructorsT4)]
								else
									constructor = constructorUnitList.ConstructorsT1[math.random(#constructorUnitList.ConstructorsT1)]
								end
								if constructor then
									local posx = posx+math.random(-128,128)
									local posz = posz+math.random(-128,128)
									local posy = Spring.GetGroundHeight(posx, posz)
									spawnQueueLibrary.AddToSpawnQueue(constructor, posx, posy, posz, math.random(0, 3), ScavengerTeamID, n + 150)
									Spring.CreateUnit(staticUnitList.scavSpawnEffectUnit, posx, posy, posz, math_random(0,3),ScavengerTeamID)
								end
							end
						end
					end

					
					if scavconfig.unitSpawnerModuleConfig.beacondefences == true then
						if spawnTier <= TierSpawnChances.T0 then
							grouptier = staticUnitList.BeaconDefencesLand.T0
						elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 then
							grouptier = staticUnitList.BeaconDefencesLand.T1
						elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 then
							grouptier = staticUnitList.BeaconDefencesLand.T2
						elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 then
							grouptier = staticUnitList.BeaconDefencesLand.T3
						elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 + TierSpawnChances.T4 then
							grouptier = staticUnitList.BeaconDefencesLand.T4
						else
							grouptier = staticUnitList.BeaconDefencesLand.T0
						end
						if spawnTier <= TierSpawnChances.T0 then
							grouptiersea = staticUnitList.BeaconDefencesSea.T0
						elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 then
							grouptiersea = staticUnitList.BeaconDefencesSea.T1
						elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 then
							grouptiersea = staticUnitList.BeaconDefencesSea.T2
						elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 then
							grouptiersea = staticUnitList.BeaconDefencesSea.T3
						elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 + TierSpawnChances.T4 then
							grouptiersea = staticUnitList.BeaconDefencesSea.T4
						else
							grouptiersea = staticUnitList.BeaconDefencesSea.T0
						end
						
						for y = 1,4 do
							if scavengerGamePhase ~= "initial" or math.random(0,3) == 0 then
								local rx = posx+xtable[y][3]
								local rz = posz+ztable[y][3]
								if positionCheckLibrary.StartboxCheck(rx, Spring.GetGroundHeight(rx, rz), rz, 64, ScavengerAllyTeamID, true) == false then
									if Spring.GetGroundHeight(rx, rz) > -20 then
										local turret = grouptier[math_random(1,#grouptier)]
										spawnQueueLibrary.AddToSpawnQueue(turret, rx, posy, rz, math_random(0,3),ScavengerTeamID, n+150, false)
									else
										local turretSea = grouptiersea[math_random(1,#grouptiersea)]
										spawnQueueLibrary.AddToSpawnQueue(turretSea, rx, posy, rz, math_random(0,3),ScavengerTeamID, n+150, false)
									end
									Spring.CreateUnit(staticUnitList.scavSpawnEffectUnit, rx, posy, rz, math_random(0,3),ScavengerTeamID)
								end
							end
						end
						grouptier = nil
						grouptiersea = nil
					end
					break
				end
			end
		else
			BeaconSpawnChance = scavconfig.unitSpawnerModuleConfig.beaconspawnchance
			if BeaconSpawnChance < 1 then
				BeaconSpawnChance = 1
			end
		end
	end
end

return {
	SpawnBeacon = spawnBeacon,
}