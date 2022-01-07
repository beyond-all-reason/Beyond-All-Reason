local BeaconSpawnChance = unitSpawnerModuleConfig.beaconspawnchance
local staticUnitList = VFS.Include("luarules/gadgets/scavengers/Configs/BYAR/UnitLists/staticunits.lua")
local airUnitList = VFS.Include("luarules/gadgets/scavengers/Configs/BYAR/UnitLists/air.lua")
local landUnitList = VFS.Include("luarules/gadgets/scavengers/Configs/BYAR/UnitLists/land.lua")
local seaUnitList = VFS.Include("luarules/gadgets/scavengers/Configs/BYAR/UnitLists/sea.lua")
local constructorUnitList = VFS.Include("luarules/gadgets/scavengers/Configs/BYAR/UnitLists/constructors.lua")

local xtable = {{-128, -64, -128}, {128, 64, 128}, {-128, -64, 0}, {128, 64, 0}}
local ztable = {{-128, -64, 0}, {-128, -64, 0}, {128, 64, -128}, {-128, -64, 128}}

local function countScavCommanders()
	return Spring.GetTeamUnitDefCount(GaiaTeamID, UnitDefNames.corcom_scav.id) + Spring.GetTeamUnitDefCount(GaiaTeamID, UnitDefNames.armcom_scav.id)
end

function SpawnBeacon(n)
	if n and n > spawningStartFrame then
		if numOfSpawnBeacons < unitSpawnerModuleConfig.minimumspawnbeacons or numOfSpawnBeacons < 3 then
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
						if scavengerGamePhase == "initial" then
							if numOfSpawnBeacons > unitSpawnerModuleConfig.minimumspawnbeacons*0.2 then
								canSpawnBeaconHere = false
							else
								canSpawnBeaconHere = posLosCheck(posx, posy, posz,192)
							end
						else
							if numOfSpawnBeacons == 0 then
								canSpawnBeaconHere = posOccupied(posx, posy, posz, 750)
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
					QueueSpawn("scavengerdroppod_scav", posx, posy, posz, math_random(0,3),GaiaTeamID, n+1, false)
					Spring.CreateUnit("scavengerdroppod_scav", posx, posy, posz, math_random(0,3),GaiaTeamID)
					QueueSpawn("scavengerdroppodbeacon_scav", posx, posy, posz, math_random(0,3),GaiaTeamID, n+150, false)
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
							if math.random(0,3) == 0 then
								local rx = posx+xtable[y][1]+math.random(-64,64)
								local rz = posz+ztable[y][1]+math.random(-64,64)
								if Spring.GetGroundHeight(rx, rz) > -20 then
									QueueSpawn(grouptier[math_random(1,#grouptier)], rx, posy, rz, math_random(0,3),GaiaTeamID, n+150, false)
								else
									QueueSpawn(grouptiersea[math_random(1,#grouptiersea)], rx, posy, rz, math_random(0,3),GaiaTeamID, n+150, false)
								end
								Spring.CreateUnit("scavengerdroppod_scav", rx, posy, rz, math_random(0,3),GaiaTeamID)
							end
							if math.random(0,3) == 0 or scavengerGamePhase ~= "initial" then
								local rx = posx+xtable[y][2]+math.random(-64,64)
								local rz = posz+ztable[y][2]+math.random(-64,64)
								if Spring.GetGroundHeight(rx, rz) > -20 then
									QueueSpawn(constructorUnitList.Resurrectors[math_random(1,#constructorUnitList.Resurrectors)], rx, posy, rz, math_random(0,3),GaiaTeamID, n+150, false)
								else
									QueueSpawn(constructorUnitList.ResurrectorsSea[math_random(1,#constructorUnitList.ResurrectorsSea)], rx, posy, rz, math_random(0,3),GaiaTeamID, n+150, false)
								end
								Spring.CreateUnit("scavengerdroppod_scav", rx, posy, rz, math_random(0,3),GaiaTeamID)
							end
						end
					end

					

					if scavengerGamePhase ~= "initial" then
						if constructorControllerModuleConfig.useconstructors then
							-- local unitCount = Spring.GetTeamUnitCount(GaiaTeamID)
							-- local unitCountBuffer = scavMaxUnits*0.5
							-- if not (unitCount + unitCountBuffer >= scavMaxUnits) then 
							local neededcommanders = constructorControllerModuleConfig.minimumconstructors - countScavCommanders()
							if neededcommanders > 0 then
								for i = 1,neededcommanders do
									local constructor = constructorUnitList.Constructors[math.random(#constructorUnitList.Constructors)]
									local posx = posx+math.random(-128,128)
									local posz = posz+math.random(-128,128)
									local posy = Spring.GetGroundHeight(posx, posz)
									QueueSpawn(constructor, posx, posy, posz, math.random(0, 3), GaiaTeamID, n + 150)
									Spring.CreateUnit("scavengerdroppod_scav", posx, posy, posz, math_random(0,3),GaiaTeamID)
								end
							end
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

						for y = 1,4 do
							local rx = posx+xtable[y][3]
							local rz = posz+ztable[y][3]
							if Spring.GetGroundHeight(rx, rz) > -20 then
								local turret = grouptier[math_random(1,#grouptier)]
								QueueSpawn(turret, rx, posy, rz, math_random(0,3),GaiaTeamID, n+150, false)
							else
								local turretSea = grouptiersea[math_random(1,#grouptiersea)]
								QueueSpawn(turretSea, rx, posy, rz, math_random(0,3),GaiaTeamID, n+150, false)
							end
							Spring.CreateUnit("scavengerdroppod_scav", rx, posy, rz, math_random(0,3),GaiaTeamID)
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
