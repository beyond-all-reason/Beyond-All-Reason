local BeaconSpawnChance = unitSpawnerModuleConfig.beaconspawnchance
local UnitLists = VFS.DirList('luarules/gadgets/scavengers/Configs/'..GameShortName..'/UnitLists/','*.lua')
for i = 1,#UnitLists do
	VFS.Include(UnitLists[i])
	Spring.Echo("Scav Units Directory: " ..UnitLists[i])
end

function SpawnBeacon(n)
	if n and n > 7200 then
		if scavengersAIEnabled == true then -- Survival
			local BeaconSpawnChance = math_random(0,BeaconSpawnChance)
			if numOfSpawnBeacons <= unitSpawnerModuleConfig.minimumspawnbeacons then
				BeaconSpawnChance = 0
			end
			if BossWaveTimeLeft and BossWaveTimeLeft < 1 then
				BeaconSpawnChance = 1 -- can't spawn
			end
			if BeaconSpawnChance == 0 or canSpawnBeaconHere == false then
				local posx = math_random(80,mapsizeX-80)
				local posz = math_random(80,mapsizeZ-80)
				local posy = Spring.GetGroundHeight(posx, posz)
				local posradius = 80
				canSpawnBeaconHere = posCheck(posx, posy, posz, posradius)
				if canSpawnBeaconHere then
					if globalScore then
						local g = math_random(0,3)
						if ScavengerStartboxExists and g ~= 0 then
							if ScavengerStartboxXMin < posx and ScavengerStartboxXMax > posx and ScavengerStartboxZMin < posz and ScavengerStartboxZMax > posz then
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
				if canSpawnBeaconHere then
					canSpawnBeaconHere = posOccupied(posx, posy, posz, posradius)
				end

				if canSpawnBeaconHere then
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
					end

					BeaconSpawnChance = unitSpawnerModuleConfig.beaconspawnchance
					Spring.CreateUnit("scavengerdroppodbeacon_scav", posx, posy, posz, math_random(0,3),GaiaTeamID)

					
					Spring.CreateUnit("scavengerdroppod_scav", posx-128, posy, posz, math_random(0,3),GaiaTeamID)
					local posy = Spring.GetGroundHeight(posx-128, posz)
					if posy > 0 then
						local r = grouptier[math_random(1,#grouptier)]
						QueueSpawn(r..scavconfig.unitnamesuffix, posx-128, posy, posz, math_random(0,3),GaiaTeamID, n+90)
					else
						local r2 = grouptiersea[math_random(1,#grouptiersea)]
						QueueSpawn(r2..scavconfig.unitnamesuffix, posx-128, posy, posz, math_random(0,3),GaiaTeamID, n+90)
					end

					Spring.CreateUnit("scavengerdroppod_scav", posx+128, posy, posz, math_random(0,3),GaiaTeamID)
					local posy = Spring.GetGroundHeight(posx+128, posz)
					if posy > 0 then
						local r = grouptier[math_random(1,#grouptier)]
						QueueSpawn(r..scavconfig.unitnamesuffix, posx+128, posy, posz, math_random(0,3),GaiaTeamID, n+90)
					else
						local r2 = grouptiersea[math_random(1,#grouptiersea)]
						QueueSpawn(r2..scavconfig.unitnamesuffix, posx+128, posy, posz, math_random(0,3),GaiaTeamID, n+90)
					end

					Spring.CreateUnit("scavengerdroppod_scav", posx, posy, posz+128, math_random(0,3),GaiaTeamID)
					local posy = Spring.GetGroundHeight(posx, posz+128)
					if posy > 0 then
						local r = grouptier[math_random(1,#grouptier)]
						QueueSpawn(r..scavconfig.unitnamesuffix, posx, posy, posz+128, math_random(0,3),GaiaTeamID, n+90)
					else
						local r2 = grouptiersea[math_random(1,#grouptiersea)]
						QueueSpawn(r2..scavconfig.unitnamesuffix, posx, posy, posz+128, math_random(0,3),GaiaTeamID, n+90)
					end

					Spring.CreateUnit("scavengerdroppod_scav", posx, posy, posz-128, math_random(0,3),GaiaTeamID)
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
			else
				BeaconSpawnChance = BeaconSpawnChance - 1
				if BeaconSpawnChance < 1 then
					BeaconSpawnChance = 1
				end
			end
		else -- PvP
			local BeaconSpawnChance = math_random(0,BeaconSpawnChance)
			if numOfSpawnBeacons <= unitSpawnerModuleConfig.minimumspawnbeacons then
				BeaconSpawnChance = 0
			end
			if BossWaveTimeLeft and BossWaveTimeLeft < 1 then
				BeaconSpawnChance = 1 -- can't spawn
			end
			if BeaconSpawnChance == 0 or canSpawnBeaconHere == false then
				if not beaconspawnretrycount then
					beaconspawnretrycount = 0
				end
				local posx = math_random(math.ceil((mapsizeX/2)-(((mapsizeX/2)/60)*beaconspawnretrycount)),math.floor((mapsizeX/2)+(((mapsizeX/2)/60)*beaconspawnretrycount)))
				local posz = math_random(math.ceil((mapsizeZ/2)-(((mapsizeZ/2)/60)*beaconspawnretrycount)),math.floor((mapsizeZ/2)+(((mapsizeZ/2)/60)*beaconspawnretrycount)))
				if posx < 256 then
					posx = 256
				end
				if posx > mapsizeX-256 then
					posx = mapsizeX-256
				end
				if posz < 256 then
					posz = 256
				end
				if posz > mapsizeZ-256 then
					posz = mapsizeZ-256
				end
				local posy = Spring.GetGroundHeight(posx, posz)
				local posradius = 80
				beaconspawnretrycount = beaconspawnretrycount + 1
				canSpawnBeaconHere = posCheck(posx, posy, posz, posradius)
				if canSpawnBeaconHere then
					if globalScore then
						-- elseif globalScore > scavconfig.timers.NoRadar then
							-- canSpawnBeaconHere = posLosCheckNoRadar(posx, posy, posz,posradius)
						--else
							canSpawnBeaconHere = posLosCheck(posx, posy, posz,posradius)
						--end
					end
				end
				if canSpawnBeaconHere then
					local posradius = 384
					canSpawnBeaconHere = posOccupied(posx, posy, posz, posradius)
				end

				if canSpawnBeaconHere then
					beaconspawnretrycount = 0
					local spawnTier = math_random(1,100)
					if spawnTier <= TierSpawnChances.T0 then
						grouptier = BeaconDefenceStructuresT0
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 then
						grouptier = BeaconDefenceStructuresT1
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 then
						grouptier = BeaconDefenceStructuresT2
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 + TierSpawnChances.T4 then
						grouptier = BeaconDefenceStructuresT3
					end
					if spawnTier <= TierSpawnChances.T0 then
						grouptiersea = StartboxDefenceStructuresT0Sea
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 then
						grouptiersea = StartboxDefenceStructuresT1Sea
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 then
						grouptiersea = StartboxDefenceStructuresT2Sea
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 + TierSpawnChances.T4 then
						grouptiersea = StartboxDefenceStructuresT3Sea
					end

					BeaconSpawnChance = unitSpawnerModuleConfig.beaconspawnchance
					Spring.CreateUnit("scavengerdroppodbeacon_scav", posx, posy, posz, math_random(0,3),GaiaTeamID)

					
					Spring.CreateUnit("scavengerdroppod_scav", posx-128, posy, posz, math_random(0,3),GaiaTeamID)
					local posy = Spring.GetGroundHeight(posx-128, posz)
					if posy > 0 then
						local r = grouptier[math_random(1,#grouptier)]
						QueueSpawn(r..scavconfig.unitnamesuffix, posx-128, posy, posz, math_random(0,3),GaiaTeamID, n+90)
					else
						local r2 = grouptiersea[math_random(1,#grouptiersea)]
						QueueSpawn(r2..scavconfig.unitnamesuffix, posx-128, posy, posz, math_random(0,3),GaiaTeamID, n+90)
					end

					Spring.CreateUnit("scavengerdroppod_scav", posx+128, posy, posz, math_random(0,3),GaiaTeamID)
					local posy = Spring.GetGroundHeight(posx+128, posz)
					if posy > 0 then
						local r = grouptier[math_random(1,#grouptier)]
						QueueSpawn(r..scavconfig.unitnamesuffix, posx+128, posy, posz, math_random(0,3),GaiaTeamID, n+90)
					else
						local r2 = grouptiersea[math_random(1,#grouptiersea)]
						QueueSpawn(r2..scavconfig.unitnamesuffix, posx+128, posy, posz, math_random(0,3),GaiaTeamID, n+90)
					end

					Spring.CreateUnit("scavengerdroppod_scav", posx, posy, posz+128, math_random(0,3),GaiaTeamID)
					local posy = Spring.GetGroundHeight(posx, posz+128)
					if posy > 0 then
						local r = grouptier[math_random(1,#grouptier)]
						QueueSpawn(r..scavconfig.unitnamesuffix, posx, posy, posz+128, math_random(0,3),GaiaTeamID, n+90)
					else
						local r2 = grouptiersea[math_random(1,#grouptiersea)]
						QueueSpawn(r2..scavconfig.unitnamesuffix, posx, posy, posz+128, math_random(0,3),GaiaTeamID, n+90)
					end

					Spring.CreateUnit("scavengerdroppod_scav", posx, posy, posz-128, math_random(0,3),GaiaTeamID)
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
				posx = nil
				posz = nil
			else
				BeaconSpawnChance = BeaconSpawnChance - 1
				if BeaconSpawnChance < 1 then
					BeaconSpawnChance = 1
				end
			end
		end
	end
end
