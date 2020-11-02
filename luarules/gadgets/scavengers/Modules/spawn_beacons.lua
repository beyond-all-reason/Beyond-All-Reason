local BeaconSpawnChance = unitSpawnerModuleConfig.beaconspawnchance
local UnitLists = VFS.DirList('luarules/gadgets/scavengers/Configs/'..GameShortName..'/UnitLists/','*.lua')
for i = 1,#UnitLists do
	VFS.Include(UnitLists[i])
	Spring.Echo("Scav Units Directory: " ..UnitLists[i])
end

function SpawnBeacon(n)
	if n and n > 7200 then
		local BeaconSpawnChance = math_random(0,BeaconSpawnChance)
		if numOfSpawnBeacons <= unitSpawnerModuleConfig.minimumspawnbeacons or ScavSafeAreaExists == false then
			BeaconSpawnChance = 0
		end
		if BossWaveTimeLeft and BossWaveTimeLeft < 1 then
			BeaconSpawnChance = 1 -- can't spawn
		end
		if BeaconSpawnChance == 0 or canSpawnBeaconHere == false then
			local posx = math_random(80,mapsizeX-80)
			local posz = math_random(80,mapsizeZ-80)
			local posy = Spring.GetGroundHeight(posx, posz)
			if not SafeAreaBeaconSpawnAttempts then 
				SafeAreaBeaconSpawnAttempts = 0 
			end
			if not ScavSafeAreaSize then 
				ScavSafeAreaSize = math.ceil(250 * spawnmultiplier * (teamcount/2)) 
			end
			if ScavSafeAreaExist or SafeAreaBeaconSpawnAttempts > 20 then 
				beacontype = "normal"
				posradius = 80 
			else
				beacontype = "safearea"
				posradius = ScavSafeAreaSize
				SafeAreaBeaconSpawnAttempts = (SafeAreaBeaconSpawnAttempts + 1) or 1
			end
			
			canSpawnBeaconHere = posCheck(posx, posy, posz, 80)
			if canSpawnBeaconHere then
				if globalScore then
					local g = math_random(0,1)
					--ScavSafeAreaMinX
					--ScavSafeAreaMaxX
					--ScavSafeAreaMinZ
					--ScavSafeAreaMaxZ
					if ScavSafeAreaExist and g ~= 0 then
						if ScavSafeAreaMinX < posx and ScavSafeAreaMaxX > posx and ScavSafeAreaMinZ < posz and ScavSafeAreaMaxZ > posz then
							canSpawnBeaconHere = true
						else
							canSpawnBeaconHere = false
						end
					else
						-- elseif globalScore > scavconfig.timers.OnlyLos then
							-- canSpawnBeaconHere = posLosCheckOnlyLOS(posx, posy, posz,posradius)
						if globalScore > scavconfig.timers.NoRadar then
							canSpawnBeaconHere = posLosCheckNoRadar(posx, posy, posz,posradius)
						else
							canSpawnBeaconHere = posLosCheck(posx, posy, posz,posradius)
						end
					end
				end
			end
			if canSpawnBeaconHere and beacontype ~= "safearea" then
				canSpawnBeaconHere = posOccupied(posx, posy, posz, posradius)
			end

			if canSpawnBeaconHere then
				BeaconSpawnChance = unitSpawnerModuleConfig.beaconspawnchance
				if ScavSafeAreaExist or scavconfig.modules.startBoxProtection == false or SafeAreaBeaconSpawnAttempts > 20 then
					Spring.CreateUnit("scavengerdroppodbeacon_scav", posx, posy, posz, math_random(0,3),GaiaTeamID)
					SafeAreaBeaconSpawnAttempts = 0
				else
					Spring.CreateUnit("scavsafeareabeacon_scav", posx, posy, posz, math_random(0,3),GaiaTeamID)
					SafeAreaBeaconSpawnAttempts = 0
				end
				
				Spring.CreateUnit("scavengerdroppod_scav", posx-128, posy, posz, math_random(0,3),GaiaTeamID)
				Spring.CreateUnit("scavengerdroppod_scav", posx+128, posy, posz, math_random(0,3),GaiaTeamID)
				Spring.CreateUnit("scavengerdroppod_scav", posx, posy, posz+128, math_random(0,3),GaiaTeamID)
				Spring.CreateUnit("scavengerdroppod_scav", posx, posy, posz-128, math_random(0,3),GaiaTeamID)
				if unitSpawnerModuleConfig.beacondefences == true then
					local spawnTier = math_random(1,100)
					if spawnTier <= TierSpawnChances.T0 then
						grouptier = BeaconDefenceStructuresT0
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 then
						grouptier = BeaconDefenceStructuresT1
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 then
						grouptier = BeaconDefenceStructuresT2
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 + TierSpawnChances.T4 then
						grouptier = BeaconDefenceStructuresT3
					else
						grouptier = BeaconDefenceStructuresT0
					end
					if spawnTier <= TierSpawnChances.T0 then
						grouptiersea = StartboxDefenceStructuresT0Sea
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 then
						grouptiersea = StartboxDefenceStructuresT1Sea
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 then
						grouptiersea = StartboxDefenceStructuresT2Sea
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 + TierSpawnChances.T4 then
						grouptiersea = StartboxDefenceStructuresT3Sea
					else
						grouptiersea = StartboxDefenceStructuresT0Sea
					end

					
					local posy = Spring.GetGroundHeight(posx-128, posz)
					if posy > 0 then
						local r = grouptier[math_random(1,#grouptier)]
						QueueSpawn(r..scavconfig.unitnamesuffix, posx-128, posy, posz, math_random(0,3),GaiaTeamID, n+90)
					else
						local r2 = grouptiersea[math_random(1,#grouptiersea)]
						QueueSpawn(r2..scavconfig.unitnamesuffix, posx-128, posy, posz, math_random(0,3),GaiaTeamID, n+90)
					end

					
					local posy = Spring.GetGroundHeight(posx+128, posz)
					if posy > 0 then
						local r = grouptier[math_random(1,#grouptier)]
						QueueSpawn(r..scavconfig.unitnamesuffix, posx+128, posy, posz, math_random(0,3),GaiaTeamID, n+90)
					else
						local r2 = grouptiersea[math_random(1,#grouptiersea)]
						QueueSpawn(r2..scavconfig.unitnamesuffix, posx+128, posy, posz, math_random(0,3),GaiaTeamID, n+90)
					end

					
					local posy = Spring.GetGroundHeight(posx, posz+128)
					if posy > 0 then
						local r = grouptier[math_random(1,#grouptier)]
						QueueSpawn(r..scavconfig.unitnamesuffix, posx, posy, posz+128, math_random(0,3),GaiaTeamID, n+90)
					else
						local r2 = grouptiersea[math_random(1,#grouptiersea)]
						QueueSpawn(r2..scavconfig.unitnamesuffix, posx, posy, posz+128, math_random(0,3),GaiaTeamID, n+90)
					end

					
					local posy = Spring.GetGroundHeight(posx, posz-128)
					if posy > 0 then
						local r = grouptier[math_random(1,#grouptier)]
						QueueSpawn(r..scavconfig.unitnamesuffix, posx, posy, posz-128, math_random(0,3),GaiaTeamID, n+90)
					else
						local r2 = grouptiersea[math_random(1,#grouptiersea)]
						QueueSpawn(r2..scavconfig.unitnamesuffix, posx, posy, posz-128, math_random(0,3),GaiaTeamID, n+90)
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
