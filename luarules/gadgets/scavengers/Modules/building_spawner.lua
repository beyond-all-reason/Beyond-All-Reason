
Spring.Echo("[Scavengers] Building spawner initialized")

BlueprintsList = VFS.DirList('luarules/gadgets/scavengers/Blueprints/Spawner/','*.lua')
for i = 1,#BlueprintsList do
	VFS.Include(BlueprintsList[i])
	Spring.Echo("Scav Blueprints Directory: " ..BlueprintsList[i])
end

function SpawnBlueprint(n)
	if n > scavconfig.timers.Tech0 then
		local gaiaUnitCount = Spring.GetTeamUnitCount(GaiaTeamID)
		local spawnchance = math.random(0,buildingSpawnerModuleConfig.spawnchance)
		if spawnchance == 0 or canBuildHere == false then
			posx = math.random(200,mapsizeX-200)
			posz = math.random(200,mapsizeZ-200)
			posy = Spring.GetGroundHeight(posx, posz)
			--blueprint = ScavengerBlueprintsT0[math.random(1,#ScavengerBlueprintsT0)]
			if posy > 0 or not buildingSpawnerModuleConfig.useSeaBlueprints then
				if n > scavconfig.timers.Tech3 then
					local r = math.random(0,1)
					if r == 0 then
						blueprint = ScavengerBlueprintsT3[math.random(1,#ScavengerBlueprintsT3)]
					else
						blueprint = ScavengerBlueprintsT2[math.random(1,#ScavengerBlueprintsT2)]
					end
				elseif n > scavconfig.timers.Tech2 then
					local r = math.random(0,2)
					if r == 0 then
						blueprint = ScavengerBlueprintsT2[math.random(1,#ScavengerBlueprintsT2)]
					elseif r == 1 then
						blueprint = ScavengerBlueprintsT1[math.random(1,#ScavengerBlueprintsT1)]
					else
						blueprint = ScavengerBlueprintsT0[math.random(1,#ScavengerBlueprintsT0)]
					end
				elseif n > scavconfig.timers.Tech1 then
					local r = math.random(0,1)
					if r == 0 then
						blueprint = ScavengerBlueprintsT1[math.random(1,#ScavengerBlueprintsT1)]
					else
						blueprint = ScavengerBlueprintsT0[math.random(1,#ScavengerBlueprintsT0)]
					end
				else
					blueprint = ScavengerBlueprintsT0[math.random(1,#ScavengerBlueprintsT0)]
				end
			elseif posy <= 0 then	
				if n > scavconfig.timers.Tech3 then
					local r = math.random(0,3)
					if r == 0 then
						blueprint = ScavengerBlueprintsT3Sea[math.random(1,#ScavengerBlueprintsT3Sea)]
					elseif r == 1 then
						blueprint = ScavengerBlueprintsT2Sea[math.random(1,#ScavengerBlueprintsT2Sea)]
					elseif r == 2 then
						blueprint = ScavengerBlueprintsT1Sea[math.random(1,#ScavengerBlueprintsT1Sea)]
					else
						blueprint = ScavengerBlueprintsT0Sea[math.random(1,#ScavengerBlueprintsT0Sea)]
					end
				elseif n > scavconfig.timers.Tech2 then
					local r = math.random(0,2)
					if r == 0 then
						blueprint = ScavengerBlueprintsT2Sea[math.random(1,#ScavengerBlueprintsT2Sea)]
					elseif r == 1 then
						blueprint = ScavengerBlueprintsT1Sea[math.random(1,#ScavengerBlueprintsT1Sea)]
					else
						blueprint = ScavengerBlueprintsT0Sea[math.random(1,#ScavengerBlueprintsT0Sea)]
					end
				elseif n > scavconfig.timers.Tech1 then
					local r = math.random(0,1)
					if r == 0 then
						blueprint = ScavengerBlueprintsT1Sea[math.random(1,#ScavengerBlueprintsT1Sea)]
					else
						blueprint = ScavengerBlueprintsT0Sea[math.random(1,#ScavengerBlueprintsT0Sea)]
					end
				else
					blueprint = ScavengerBlueprintsT0Sea[math.random(1,#ScavengerBlueprintsT0Sea)]
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
			end
		end
	end
end