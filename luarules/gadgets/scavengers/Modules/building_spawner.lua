
Spring.Echo("[Scavengers] Building spawner initialized")

BlueprintsList = VFS.DirList('luarules/gadgets/scavengers/Blueprints/'..GameShortName..'/Spawner/','*.lua')
for i = 1,#BlueprintsList do
	VFS.Include(BlueprintsList[i])
	Spring.Echo("Scav Blueprints Directory: " ..BlueprintsList[i])
end

function SpawnBlueprint(n)
	if n > 9000 then
		local gaiaUnitCount = Spring.GetTeamUnitCount(GaiaTeamID)
		local spawnchance = math_random(0,buildingSpawnerModuleConfig.spawnchance)
		if spawnchance == 0 or canBuildHere == false then
			posx = math_random(200,mapsizeX-200)
			posz = math_random(200,mapsizeZ-200)
			posy = Spring.GetGroundHeight(posx, posz)
			local spawnTier = math_random(1,100)
			if posy > 0 then
				if spawnTier <= TierSpawnChances.T0 then
						blueprint = ScavengerBlueprintsT0[math_random(1,#ScavengerBlueprintsT0)]
				elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 then
						blueprint = ScavengerBlueprintsT1[math_random(1,#ScavengerBlueprintsT1)]
				elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 then
						blueprint = ScavengerBlueprintsT2[math_random(1,#ScavengerBlueprintsT2)]
				elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 then
						blueprint = ScavengerBlueprintsT3[math_random(1,#ScavengerBlueprintsT3)]
				elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 + TierSpawnChances.T4 then
						blueprint = ScavengerBlueprintsT3[math_random(1,#ScavengerBlueprintsT3)]
				else
					blueprint = ScavengerBlueprintsT0[math_random(1,#ScavengerBlueprintsT0)]
				end
			elseif posy <= 0 then
				if spawnTier <= TierSpawnChances.T0 then
						blueprint = ScavengerBlueprintsT0Sea[math_random(1,#ScavengerBlueprintsT0Sea)]
				elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 then
						blueprint = ScavengerBlueprintsT1Sea[math_random(1,#ScavengerBlueprintsT1Sea)]
				elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 then
						blueprint = ScavengerBlueprintsT2Sea[math_random(1,#ScavengerBlueprintsT2Sea)]
				elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 then
						blueprint = ScavengerBlueprintsT3Sea[math_random(1,#ScavengerBlueprintsT3Sea)]
				elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 + TierSpawnChances.T4 then
						blueprint = ScavengerBlueprintsT4Sea[math_random(1,#ScavengerBlueprintsT4Sea)]
				else
					blueprint = ScavengerBlueprintsT0Sea[math_random(1,#ScavengerBlueprintsT0Sea)]
				end
			end
			posradius = blueprint(posx, posy, posz, GaiaTeamID, true)
			canBuildHere = posLosCheck(posx, posy, posz, posradius)
			if canBuildHere then
				canBuildHere = posOccupied(posx, posy, posz, posradius)
			end
			if canBuildHere then
				canBuildHere = posCheck(posx, posy, posz, posradius)
			end

			if canBuildHere then
				-- let's do this shit
				blueprint(posx, posy, posz, GaiaTeamID, false)
				Spring.CreateUnit("scavengerdroppod_scav", posx+posradius, posy, posz, math_random(0,3),GaiaTeamID)
				Spring.CreateUnit("scavengerdroppod_scav", posx-posradius, posy, posz, math_random(0,3),GaiaTeamID)
				Spring.CreateUnit("scavengerdroppod_scav", posx, posy, posz+posradius, math_random(0,3),GaiaTeamID)
				Spring.CreateUnit("scavengerdroppod_scav", posx, posy, posz-posradius, math_random(0,3),GaiaTeamID)
				Spring.CreateUnit("scavengerdroppod_scav", posx+posradius, posy, posz+posradius, math_random(0,3),GaiaTeamID)
				Spring.CreateUnit("scavengerdroppod_scav", posx-posradius, posy, posz+posradius, math_random(0,3),GaiaTeamID)
				Spring.CreateUnit("scavengerdroppod_scav", posx-posradius, posy, posz-posradius, math_random(0,3),GaiaTeamID)
				Spring.CreateUnit("scavengerdroppod_scav", posx+posradius, posy, posz-posradius, math_random(0,3),GaiaTeamID)
			end
		end
	end
end