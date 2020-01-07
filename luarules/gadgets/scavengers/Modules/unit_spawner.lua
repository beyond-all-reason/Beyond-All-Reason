Spring.Echo("[Scavengers] Unit Spawner initialized")

UnitLists = VFS.DirList('luarules/gadgets/scavengers/Configs/'..GameShortName..'/UnitLists/','*.lua')
for i = 1,#UnitLists do
	VFS.Include(UnitLists[i])
	Spring.Echo("Scav Units Directory: " ..UnitLists[i])
end

function UnitGroupSpawn(n)
	if n > 9000 then
		local gaiaUnitCount = Spring.GetTeamUnitCount(GaiaTeamID)
		local spawnchance = math.random(0,math.ceil((((gaiaUnitCount)/teamcount)+2)*(#Spring.GetAllyTeamList() - 1)/spawnmultiplier))
		--local spawnchance = 1 -- dev purpose
		if spawnchance == 0 or canSpawnHere == false then
			-- check positions
			local posx = math.random(300,mapsizeX-300)
			local posz = math.random(300,mapsizeZ-300)
			local posy = Spring.GetGroundHeight(posx, posz)
			-- minimum size needed for succesful spawn
			local posradius = 100
			canSpawnHere = posCheck(posx, posy, posz, posradius)
			if canSpawnHere then
				canSpawnHere = posLosCheck(posx, posy, posz,posradius)
			end
			if canSpawnHere then
				canSpawnHere = posOccupied(posx, posy, posz, posradius)
			end
			--spawn units
			if canSpawnHere then
				local groupsize = (((n)+#Spring.GetAllUnits())*spawnmultiplier*teamcount)/(#Spring.GetAllyTeamList())
				local aircraftchance = math.random(0,unitSpawnerModuleConfig.aircraftchance)
				if aircraftchance == 0 then
					if n > scavconfig.timers.Tech3 then
						local r = math.random(0,1)
						if r == 0 then
							groupunit = T3AirUnits[math.random(1,#T3AirUnits)]
						else
							groupunit = T2AirUnits[math.random(1,#T2AirUnits)]
							groupsize = groupsize*2
						end
					elseif n > scavconfig.timers.Tech2 then
						local r = math.random(0,1)
						if r == 0 then
							groupunit = T2AirUnits[math.random(1,#T2AirUnits)]
						else
							groupunit = T1AirUnits[math.random(1,#T1AirUnits)]
							groupsize = groupsize*2
						end
					elseif n > scavconfig.timers.Tech1 then
						local r = math.random(0,1)
						if r == 0 then
							groupunit = T1AirUnits[math.random(1,#T1AirUnits)]
						else
							groupunit = T0AirUnits[math.random(1,#T0AirUnits)]
							groupsize = groupsize*2
						end
					elseif n > scavconfig.timers.Tech0 then
						groupunit = T0AirUnits[math.random(1,#T0AirUnits)]
					end
				elseif posy > -20 then
					if n > scavconfig.timers.Tech3 then
						local r = math.random(0,1)
						if r == 0 then
							groupunit = T3LandUnits[math.random(1,#T3LandUnits)]
						else
							groupunit = T2LandUnits[math.random(1,#T2LandUnits)]
							groupsize = groupsize*2
						end
					elseif n > scavconfig.timers.Tech2 then
						local r = math.random(0,1)
						if r == 0 then
							groupunit = T2LandUnits[math.random(1,#T2LandUnits)]
						else
							groupunit = T1LandUnits[math.random(1,#T1LandUnits)]
							groupsize = groupsize*2
						end
					elseif n > scavconfig.timers.Tech1 then
						local r = math.random(0,1)
						if r == 0 then
							groupunit = T1LandUnits[math.random(1,#T1LandUnits)]
						else
							groupunit = T0LandUnits[math.random(1,#T0LandUnits)]
							groupsize = groupsize*2
						end
					elseif n > scavconfig.timers.Tech0 then
						groupunit = T0LandUnits[math.random(1,#T0LandUnits)]
					end
				elseif posy <= -20 then
					if n > scavconfig.timers.Tech3 then
						local r = math.random(0,1)
						if r == 0 then
							groupunit = T3SeaUnits[math.random(1,#T3SeaUnits)]
							groupsize = groupsize*0.5
						else
							groupunit = T2SeaUnits[math.random(1,#T2SeaUnits)]
						end
					elseif n > scavconfig.timers.Tech2 then
						local r = math.random(0,1)
						if r == 0 then
							groupunit = T2SeaUnits[math.random(1,#T2SeaUnits)]
							groupsize = groupsize*0.5
						else
							groupunit = T1SeaUnits[math.random(1,#T1SeaUnits)]
							
						end
					elseif n > scavconfig.timers.Tech1 then
						local r = math.random(0,1)
						if r == 0 then
							groupunit = T1SeaUnits[math.random(1,#T1SeaUnits)]
							groupsize = groupsize*0.5
						else
							groupunit = T0SeaUnits[math.random(1,#T0SeaUnits)]
						end
					elseif n > scavconfig.timers.Tech0 then
						groupunit = T0SeaUnits[math.random(1,#T0SeaUnits)]
					end
				end
				local cost = (UnitDefNames[groupunit].metalCost + UnitDefNames[groupunit].energyCost)
				local groupsize = math.ceil((groupsize/cost)*unitSpawnerModuleConfig.groupsizemultiplier)
				for i=1, groupsize do
					Spring.CreateUnit(groupunit..scavconfig.unitnamesuffix, posx+math.random(-groupsize*10,groupsize*10), posy, posz+math.random(-groupsize*10,groupsize*10), math.random(0,3),GaiaTeamID)
				end
			end
		end
	end
end			