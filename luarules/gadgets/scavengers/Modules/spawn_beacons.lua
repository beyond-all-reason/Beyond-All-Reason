local BeaconSpawnChance = unitSpawnerModuleConfig.beaconspawnchance
local UnitLists = VFS.DirList('luarules/gadgets/scavengers/Configs/'..GameShortName..'/UnitLists/','*.lua')
for i = 1,#UnitLists do
	VFS.Include(UnitLists[i])
	Spring.Echo("Scav Units Directory: " ..UnitLists[i])
end

function SpawnBeacon(n)
	if n and n > 7200 then
		if scavengersAIEnabled == true then
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
						if ScavengerStartboxExists and ScavengerStartboxXMin < posx and ScavengerStartboxXMax > posx and ScavengerStartboxZMin < posz and ScavengerStartboxZMax > posz then
							canSpawnBeaconHere = true
						-- elseif globalScore > scavconfig.timers.OnlyLos then
							-- canSpawnBeaconHere = posLosCheckOnlyLOS(posx, posy, posz,posradius)
						elseif globalScore > scavconfig.timers.NoRadar then
							canSpawnBeaconHere = posLosCheckNoRadar(posx, posy, posz,posradius)
						else
							canSpawnBeaconHere = posLosCheck(posx, posy, posz,posradius)
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
					end

					BeaconSpawnChance = unitSpawnerModuleConfig.beaconspawnchance
					Spring.CreateUnit("scavengerdroppodbeacon_scav", posx, posy, posz, math_random(0,3),GaiaTeamID)
					local r = grouptier[math_random(1,#grouptier)]
					Spring.CreateUnit("scavengerdroppod_scav", posx-128, posy, posz, math_random(0,3),GaiaTeamID)
					QueueSpawn(r..scavconfig.unitnamesuffix, posx-128, posy, posz, math_random(0,3),GaiaTeamID, n+90)
					local r = grouptier[math_random(1,#grouptier)]
					Spring.CreateUnit("scavengerdroppod_scav", posx+128, posy, posz, math_random(0,3),GaiaTeamID)
					QueueSpawn(r..scavconfig.unitnamesuffix, posx+128, posy, posz, math_random(0,3),GaiaTeamID, n+90)
					local r = grouptier[math_random(1,#grouptier)]
					Spring.CreateUnit("scavengerdroppod_scav", posx, posy, posz+128, math_random(0,3),GaiaTeamID)
					QueueSpawn(r..scavconfig.unitnamesuffix, posx, posy, posz+128, math_random(0,3),GaiaTeamID, n+90)
					local r = grouptier[math_random(1,#grouptier)]
					Spring.CreateUnit("scavengerdroppod_scav", posx, posy, posz-128, math_random(0,3),GaiaTeamID)
					QueueSpawn(r..scavconfig.unitnamesuffix, posx, posy, posz-128, math_random(0,3),GaiaTeamID, n+90)
					grouptier = nil
					
					-- for i = 1,4 do
						-- local posx = posx+math_random(-256,256)
						-- local posz = posz+math_random(-256,256)
						-- local posy = Spring.GetGroundHeight(posx, posz)
						-- local r = StartboxDefenceStructuresT0[math_random(1,#StartboxDefenceStructuresT0)]
						-- Spring.CreateUnit("scavengerdroppod_scav", posx, posy, posz, math_random(0,3),GaiaTeamID)
						-- QueueSpawn(r..scavconfig.unitnamesuffix, posx, posy, posz, math_random(0,3),GaiaTeamID, n+90+i)
					-- end
				end
			else
				BeaconSpawnChance = BeaconSpawnChance - 1
				if BeaconSpawnChance < 1 then
					BeaconSpawnChance = 1
				end
			end
		else
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
						if ScavengerStartboxExists and ScavengerStartboxXMin < posx and ScavengerStartboxXMax > posx and ScavengerStartboxZMin < posz and ScavengerStartboxZMax > posz then
							canSpawnBeaconHere = true
						-- elseif globalScore > scavconfig.timers.NoRadar then
							-- canSpawnBeaconHere = posLosCheckNoRadar(posx, posy, posz,posradius)
						-- else
							canSpawnBeaconHere = posLosCheck(posx, posy, posz,posradius)
						end
					end
				end
				if canSpawnBeaconHere then
					local posradius = 384
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
					end
					
					beaconspawnretrycount = 0
					BeaconSpawnChance = unitSpawnerModuleConfig.beaconspawnchance
					Spring.CreateUnit("scavengerdroppodbeacon_scav", posx, posy, posz, math_random(0,3),GaiaTeamID)
					
					local r = grouptier[math_random(1,#grouptier)]
					Spring.CreateUnit("scavengerdroppod_scav", posx-128, posy, posz, math_random(0,3),GaiaTeamID)
					QueueSpawn(r..scavconfig.unitnamesuffix, posx-128, posy, posz, math_random(0,3),GaiaTeamID, n+90)
					local r = grouptier[math_random(1,#grouptier)]
					Spring.CreateUnit("scavengerdroppod_scav", posx+128, posy, posz, math_random(0,3),GaiaTeamID)
					QueueSpawn(r..scavconfig.unitnamesuffix, posx+128, posy, posz, math_random(0,3),GaiaTeamID, n+90)
					local r = grouptier[math_random(1,#grouptier)]
					Spring.CreateUnit("scavengerdroppod_scav", posx, posy, posz+128, math_random(0,3),GaiaTeamID)
					QueueSpawn(r..scavconfig.unitnamesuffix, posx, posy, posz+128, math_random(0,3),GaiaTeamID, n+90)
					local r = grouptier[math_random(1,#grouptier)]
					Spring.CreateUnit("scavengerdroppod_scav", posx, posy, posz-128, math_random(0,3),GaiaTeamID)
					QueueSpawn(r..scavconfig.unitnamesuffix, posx, posy, posz-128, math_random(0,3),GaiaTeamID, n+90)
					grouptier = nil
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

