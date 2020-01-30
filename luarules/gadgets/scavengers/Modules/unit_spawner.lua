Spring.Echo("[Scavengers] Unit Spawner initialized")

UnitLists = VFS.DirList('luarules/gadgets/scavengers/Configs/'..GameShortName..'/UnitLists/','*.lua')
for i = 1,#UnitLists do
	VFS.Include(UnitLists[i])
	Spring.Echo("Scav Units Directory: " ..UnitLists[i])
end
local UnitSpawnChance = unitSpawnerModuleConfig.spawnchance

function UnitGroupSpawn(n)
	if n > 9000 then
		local gaiaUnitCount = Spring.GetTeamUnitCount(GaiaTeamID)
		local ActualUnitSpawnChance = math.random(0,UnitSpawnChance)
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
				bestTeamGroupMultiplier = 1
			else
				bestTeamGroupMultiplier = 0.5
			end
			canSpawnHere = true
			Spring.GiveOrderToUnit(pickedBeacon, CMD.SELFD,{}, {"shift"})
			SpawnBeacon(n)
			local posradius = 80
			
			if canSpawnHere then
				
				UnitSpawnChance = unitSpawnerModuleConfig.spawnchance
				if (globalScore/unitSpawnerModuleConfig.globalscoreperoneunit)*spawnmultiplier < #scavengerunits then
					UnitSpawnChance = math.ceil(UnitSpawnChance/2)
				end
				local groupsize = (globalScore / unitSpawnerModuleConfig.globalscoreperoneunit)*spawnmultiplier
				local aircraftchance = math.random(0,unitSpawnerModuleConfig.aircraftchance)
				local spawnTier = math.random(1,100)
				
				if aircraftchance == 0 then
					if spawnTier <= TierSpawnChances.T0 then
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
						local c = math.random(0,2)
							if c == 0 then
								ScavSendVoiceMessage(scavengerSoundPath.."scavheavyairdetected.wav")
							else
							end
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 + TierSpawnChances.T4 then
						groupunit = T4AirUnits[math.random(1,#T4AirUnits)]
						groupsize = groupsize*unitSpawnerModuleConfig.airmultiplier*unitSpawnerModuleConfig.t4multiplier
						ScavSendMessage("Alert! Scavengers dropped a Scavenger Boss")
						ScavSendVoiceMessage(scavengerSoundPath.."scavbossdetected.wav")
					else
						groupunit = T0AirUnits[math.random(1,#T0AirUnits)]
						groupsize = groupsize*unitSpawnerModuleConfig.airmultiplier*unitSpawnerModuleConfig.t0multiplier
					end
				elseif posy > -20 then
					if spawnTier <= TierSpawnChances.T0 then
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
									ScavSendVoiceMessage(scavengerSoundPath.."scavtech3.wav")
								elseif s == 1 then
									ScavSendVoiceMessage(scavengerSoundPath.."scavtech3b.wav")
								elseif s == 2 then
									ScavSendVoiceMessage(scavengerSoundPath.."scavtech3c.wav")
								elseif s == 3 then
									ScavSendVoiceMessage(scavengerSoundPath.."scavtech3d.wav")
								else
									ScavSendVoiceMessage(scavengerSoundPath.."scavtech3e.wav")
								end	
							else
								ScavSendMessage("Warning! Scavengers dropped group of ".. UDN[groupunit].humanName .."s")
							end
								
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 + TierSpawnChances.T4 then
						groupunit = T4LandUnits[math.random(1,#T4LandUnits)]
						groupsize = groupsize*unitSpawnerModuleConfig.landmultiplier*unitSpawnerModuleConfig.t4multiplier
						ScavSendMessage("Alert! Scavengers dropped a Scavenger Boss")
						ScavSendVoiceMessage(scavengerSoundPath.."scavbossdetected.wav")
					else
						groupunit = T0LandUnits[math.random(1,#T0LandUnits)]
						groupsize = groupsize*unitSpawnerModuleConfig.landmultiplier*unitSpawnerModuleConfig.t0multiplier
					end
				elseif posy <= -20 then
					if spawnTier <= TierSpawnChances.T0 then
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
						local c = math.random(0,2)
							if c == 0 then
								ScavSendVoiceMessage(scavengerSoundPath.."scavheavyshipsdetected.wav")
							else
							end
					elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 + TierSpawnChances.T4 then
						groupunit = T4SeaUnits[math.random(1,#T4SeaUnits)]
						groupsize = groupsize*unitSpawnerModuleConfig.seamultiplier*unitSpawnerModuleConfig.t4multiplier
						ScavSendMessage("Alert! Scavengers dropped a Scavenger Boss")
						ScavSendVoiceMessage(scavengerSoundPath.."scavbossdetected.wav")
					else
						groupunit = T0SeaUnits[math.random(1,#T0SeaUnits)]
						groupsize = groupsize*unitSpawnerModuleConfig.seamultiplier*unitSpawnerModuleConfig.t0multiplier
					end
				end
				
				local groupsize = math.ceil(groupsize*bestTeamGroupMultiplier*math.floor(teamcount/2))
				for i=1, groupsize do
					local posx = posx+math.random(-80,80)
					local posz = posz+math.random(-80,80)
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