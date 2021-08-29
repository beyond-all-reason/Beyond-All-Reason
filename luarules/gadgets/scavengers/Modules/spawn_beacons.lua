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
				local posx = math_random(128,mapsizeX-128)
				local posz = math_random(128,mapsizeZ-128)
				local posy = Spring.GetGroundHeight(posx, posz)

				canSpawnBeaconHere = posCheck(posx, posy, posz, 128)
				if canSpawnBeaconHere then
					canSpawnBeaconHere = posOccupied(posx, posy, posz, 128)
				end
				if canSpawnBeaconHere then
					if globalScore then
						--local g = math_random(0,20)
						if scavengerGamePhase == "initial" then
							canSpawnBeaconHere = posLosCheck(posx, posy, posz,80)
						else
							if numOfSpawnBeacons == 0 then
								canSpawnBeaconHere = posOccupied(posx, posy, posz, 128)
							elseif numOfSpawnBeacons < unitSpawnerModuleConfig.minimumspawnbeacons*0.2 then
								canSpawnBeaconHere = posLosCheckOnlyLOS(posx, posy, posz,128)
							elseif numOfSpawnBeacons < unitSpawnerModuleConfig.minimumspawnbeacons*0.4 then
								canSpawnBeaconHere = posLosCheckNoRadar(posx, posy, posz,128)
							else
								canSpawnBeaconHere = posLosCheck(posx, posy, posz,128)
							end
						end
					end
				end
				
				if canSpawnBeaconHere then
					BeaconSpawnChance = unitSpawnerModuleConfig.beaconspawnchance
					Spring.CreateUnit("scavengerdroppodbeacon_scav", posx, posy, posz, math_random(0,3),GaiaTeamID)
					if scavengerGamePhase == "initial" then
						if math.random(0,1) == 0 then
							if Spring.GetGroundHeight(posx-64, posz-64) > -20 then
								QueueSpawn(landUnitList.T0[math_random(1,#landUnitList.T0)], posx-64, posy, posz-64, math_random(0,3),GaiaTeamID, n+150, false)
							else
								QueueSpawn(seaUnitList.T0[math_random(1,#seaUnitList.T0)], posx-64, posy, posz-64, math_random(0,3),GaiaTeamID, n+150, false)
							end
						else
							if Spring.GetGroundHeight(posx-64, posz-64) > -20 then
								QueueSpawn(constructorUnitList.Resurrectors[math_random(1,#constructorUnitList.Resurrectors)], posx-64, posy, posz-64, math_random(0,3),GaiaTeamID, n+150, false)
							else
								QueueSpawn(constructorUnitList.ResurrectorsSea[math_random(1,#constructorUnitList.ResurrectorsSea)], posx-64, posy, posz-64, math_random(0,3),GaiaTeamID, n+150, false)
							end
						end
						if math.random(0,1) == 0 then
							if Spring.GetGroundHeight(posx+64, posz+64) > -20 then
								QueueSpawn(landUnitList.T0[math_random(1,#landUnitList.T0)], posx+64, posy, posz+64, math_random(0,3),GaiaTeamID, n+150, false)
							else
								QueueSpawn(seaUnitList.T0[math_random(1,#seaUnitList.T0)], posx+64, posy, posz+64, math_random(0,3),GaiaTeamID, n+150, false)
							end
						else
							if Spring.GetGroundHeight(posx+64, posz+64) > -20 then
								QueueSpawn(constructorUnitList.Resurrectors[math_random(1,#constructorUnitList.Resurrectors)], posx+64, posy, posz+64, math_random(0,3),GaiaTeamID, n+150, false)
							else
								QueueSpawn(constructorUnitList.ResurrectorsSea[math_random(1,#constructorUnitList.ResurrectorsSea)], posx+64, posy, posz+64, math_random(0,3),GaiaTeamID, n+150, false)
							end
						end
						if math.random(0,1) == 0 then
							if Spring.GetGroundHeight(posx+64, posz-64) > -20 then
								QueueSpawn(landUnitList.T0[math_random(1,#landUnitList.T0)], posx+64, posy, posz-64, math_random(0,3),GaiaTeamID, n+150, false)
							else
								QueueSpawn(seaUnitList.T0[math_random(1,#seaUnitList.T0)], posx+64, posy, posz-64, math_random(0,3),GaiaTeamID, n+150, false)
							end
						else
							if Spring.GetGroundHeight(posx+64, posz-64) > -20 then
								QueueSpawn(constructorUnitList.Resurrectors[math_random(1,#constructorUnitList.Resurrectors)], posx+64, posy, posz-64, math_random(0,3),GaiaTeamID, n+150, false)
							else
								QueueSpawn(constructorUnitList.ResurrectorsSea[math_random(1,#constructorUnitList.ResurrectorsSea)], posx+64, posy, posz-64, math_random(0,3),GaiaTeamID, n+150, false)
							end
						end
						if math.random(0,1) == 0 then
							if Spring.GetGroundHeight(posx-64, posz+64) > -20 then
								QueueSpawn(landUnitList.T0[math_random(1,#landUnitList.T0)], posx-64, posy, posz+64, math_random(0,3),GaiaTeamID, n+150, false)
							else
								QueueSpawn(seaUnitList.T0[math_random(1,#seaUnitList.T0)], posx-64, posy, posz+64, math_random(0,3),GaiaTeamID, n+150, false)
							end
						else
							if Spring.GetGroundHeight(posx-64, posz+64) > -20 then
								QueueSpawn(constructorUnitList.Resurrectors[math_random(1,#constructorUnitList.Resurrectors)], posx-64, posy, posz+64, math_random(0,3),GaiaTeamID, n+150, false)
							else
								QueueSpawn(constructorUnitList.ResurrectorsSea[math_random(1,#constructorUnitList.ResurrectorsSea)], posx-64, posy, posz+64, math_random(0,3),GaiaTeamID, n+150, false)
							end
						end
					end
					if unitSpawnerModuleConfig.beacondefences == true then
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

						if scavengerGamePhase ~= "initial" then
							Spring.CreateUnit("scavengerdroppod_scav", posx, posy, posz, math_random(0,3),GaiaTeamID)
							Spring.CreateUnit("scavengerdroppod_scav", posx-128, posy, posz, math_random(0,3),GaiaTeamID)
							Spring.CreateUnit("scavengerdroppod_scav", posx+128, posy, posz, math_random(0,3),GaiaTeamID)
							Spring.CreateUnit("scavengerdroppod_scav", posx, posy, posz+128, math_random(0,3),GaiaTeamID)
							Spring.CreateUnit("scavengerdroppod_scav", posx, posy, posz-128, math_random(0,3),GaiaTeamID)
						end

						if scavengerGamePhase ~= "initial" or math.random(0,3) == 0 then
							local posy = Spring.GetGroundHeight(posx-80, posz)
							if posy > 0 then
								local turret = grouptier[math_random(1,#grouptier)]
								QueueSpawn(turret, posx-80, posy, posz, math_random(0,3),GaiaTeamID, n+150, false)
							else
								local turretSea = grouptiersea[math_random(1,#grouptiersea)]
								QueueSpawn(turretSea, posx-80, posy, posz, math_random(0,3),GaiaTeamID, n+150, false)
							end
						end

						if scavengerGamePhase ~= "initial" or math.random(0,3) == 0 then
							local posy = Spring.GetGroundHeight(posx+80, posz)
							if posy > 0 then
								local turret = grouptier[math_random(1,#grouptier)]
								QueueSpawn(turret, posx+80, posy, posz, math_random(0,3),GaiaTeamID, n+150, false)
							else
								local turretSea = grouptiersea[math_random(1,#grouptiersea)]
								QueueSpawn(turretSea, posx+80, posy, posz, math_random(0,3),GaiaTeamID, n+150, false)
							end
						end

						if scavengerGamePhase ~= "initial" or math.random(0,3) == 0 then
							local posy = Spring.GetGroundHeight(posx, posz+80)
							if posy > 0 then
								local turret = grouptier[math_random(1,#grouptier)]
								QueueSpawn(turret, posx, posy, posz+80, math_random(0,3),GaiaTeamID, n+150, false)
							else
								local turretSea = grouptiersea[math_random(1,#grouptiersea)]
								QueueSpawn(turretSea, posx, posy, posz+80, math_random(0,3),GaiaTeamID, n+150, false)
							end
						end

						if scavengerGamePhase ~= "initial" or math.random(0,3) == 0 then
							local posy = Spring.GetGroundHeight(posx, posz-80)
							if posy > 0 then
								local turret = grouptier[math_random(1,#grouptier)]
								QueueSpawn(turret, posx, posy, posz-80, math_random(0,3),GaiaTeamID, n+150, false)
							else
								local turretSea = grouptiersea[math_random(1,#grouptiersea)]
								QueueSpawn(turretSea, posx, posy, posz-80, math_random(0,3),GaiaTeamID, n+150, false)
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
