Spring.Echo("[Scavengers] Unit Spawner initialized")

UnitLists = VFS.DirList('luarules/gadgets/scavengers/Configs/'..GameShortName..'/UnitLists/','*.lua')
for i = 1,#UnitLists do
	VFS.Include(UnitLists[i])
	Spring.Echo("Scav Units Directory: " ..UnitLists[i])
end
local UnitSpawnChance = unitSpawnerModuleConfig.spawnchance



function UnitGroupSpawn(n)
	if n > 9000 then
		-- this doesnt work
		-- if teamcount == 0 then
  --  		teamcount = 1
  --  		if allyteamcount == 0 then
  --  		allyteamcount = 1
   		
		local gaiaUnitCount = Spring.GetTeamUnitCount(GaiaTeamID)
		local UnitSpawnChance = math.random(0,UnitSpawnChance)
		--local UnitSpawnChance = 1 -- dev purpose
		if UnitSpawnChance == 0 or canSpawnHere == false then
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
				UnitSpawnChance = unitSpawnerModuleConfig.spawnchance
				local groupsize = (((n)+#Spring.GetAllUnits())*spawnmultiplier*teamcount)/(#Spring.GetAllyTeamList())
				--Spring.Echo("groupsize 1: "..groupsize)
				local aircraftchance = math.random(0,unitSpawnerModuleConfig.aircraftchance)
				if aircraftchance == 0 then
					if n > scavconfig.timers.Tech3 then
						local r = math.random(0,15)
						if r == 0 then
							groupunit = T3AirUnits[math.random(1,#T3AirUnits)]
							groupsize = groupsize*unitSpawnerModuleConfig.airmultiplier
						else
							groupunit = T2AirUnits[math.random(1,#T2AirUnits)]
							groupsize = groupsize*2*unitSpawnerModuleConfig.airmultiplier
						end
					elseif n > scavconfig.timers.Tech2 then
						local r = math.random(0,1)
						if r == 0 then
							groupunit = T2AirUnits[math.random(1,#T2AirUnits)]
							groupsize = groupsize*unitSpawnerModuleConfig.airmultiplier
						else
							groupunit = T1AirUnits[math.random(1,#T1AirUnits)]
							groupsize = groupsize*2*unitSpawnerModuleConfig.airmultiplier
						end
					elseif n > scavconfig.timers.Tech1 then
						local r = math.random(0,1)
						if r == 0 then
							groupunit = T1AirUnits[math.random(1,#T1AirUnits)]
							groupsize = groupsize*unitSpawnerModuleConfig.airmultiplier
						else
							groupunit = T0AirUnits[math.random(1,#T0AirUnits)]
							groupsize = groupsize*2*unitSpawnerModuleConfig.airmultiplier
						end
					elseif n > scavconfig.timers.Tech0 then
						groupunit = T0AirUnits[math.random(1,#T0AirUnits)]
						groupsize = groupsize*unitSpawnerModuleConfig.airmultiplier
					end
				elseif posy > -20 then
					if n > scavconfig.timers.Tech4 then
						local r = math.random(0,20)
						if r == 0 then
							groupunit = T4LandUnits[math.random(1,#T4LandUnits)]
							groupsize = groupsize*unitSpawnerModuleConfig.landmultiplier
						elseif r == 1 then
							groupunit = T3LandUnits[math.random(1,#T3LandUnits)]
							groupsize = groupsize*1.5*unitSpawnerModuleConfig.landmultiplier
						else
							groupunit = T2LandUnits[math.random(1,#T2LandUnits)]
							groupsize = groupsize*2.5*unitSpawnerModuleConfig.landmultiplier	
						end
					elseif n > scavconfig.timers.Tech3 then
						local r = math.random(0,15)
						if r == 0 then
							groupunit = T3LandUnits[math.random(1,#T3LandUnits)]
							groupsize = groupsize*unitSpawnerModuleConfig.landmultiplier
						else
							groupunit = T2LandUnits[math.random(1,#T2LandUnits)]
							groupsize = groupsize*2*unitSpawnerModuleConfig.landmultiplier
						end
					elseif n > scavconfig.timers.Tech2 then
						local r = math.random(0,1)
						if r == 0 then
							groupunit = T2LandUnits[math.random(1,#T2LandUnits)]
							groupsize = groupsize*unitSpawnerModuleConfig.landmultiplier
						else
							groupunit = T1LandUnits[math.random(1,#T1LandUnits)]
							groupsize = groupsize*2*unitSpawnerModuleConfig.landmultiplier
						end
					elseif n > scavconfig.timers.Tech1 then
						local r = math.random(0,1)
						if r == 0 then
							groupunit = T1LandUnits[math.random(1,#T1LandUnits)]
							groupsize = groupsize*unitSpawnerModuleConfig.landmultiplier
						else
							groupunit = T0LandUnits[math.random(1,#T0LandUnits)]
							groupsize = groupsize*2*unitSpawnerModuleConfig.landmultiplier
						end
					elseif n > scavconfig.timers.Tech0 then
						groupunit = T0LandUnits[math.random(1,#T0LandUnits)]
						groupsize = groupsize*unitSpawnerModuleConfig.landmultiplier
					end
				elseif posy <= -20 then
					if n > scavconfig.timers.Tech3 then
						local r = math.random(0,15)
						if r == 0 then
							groupunit = T3SeaUnits[math.random(1,#T3SeaUnits)]
							groupsize = groupsize*unitSpawnerModuleConfig.seamultiplier
						else
							groupunit = T2SeaUnits[math.random(1,#T2SeaUnits)]
							groupsize = groupsize*2*unitSpawnerModuleConfig.seamultiplier
						end
					elseif n > scavconfig.timers.Tech2 then
						local r = math.random(0,1)
						if r == 0 then
							groupunit = T2SeaUnits[math.random(1,#T2SeaUnits)]
							groupsize = groupsize*unitSpawnerModuleConfig.seamultiplier
						else
							groupunit = T1SeaUnits[math.random(1,#T1SeaUnits)]
							groupsize = groupsize*2*unitSpawnerModuleConfig.seamultiplier
							
						end
					elseif n > scavconfig.timers.Tech1 then
						local r = math.random(0,1)
						if r == 0 then
							groupunit = T1SeaUnits[math.random(1,#T1SeaUnits)]
							groupsize = groupsize*2*unitSpawnerModuleConfig.seamultiplier
						else
							groupunit = T0SeaUnits[math.random(1,#T0SeaUnits)]
							groupsize = groupsize*unitSpawnerModuleConfig.seamultiplier
						end
					elseif n > scavconfig.timers.Tech0 then
						groupunit = T0SeaUnits[math.random(1,#T0SeaUnits)]
						groupsize = groupsize*unitSpawnerModuleConfig.seamultiplier
					end
				end
				local cost = (UnitDefNames[groupunit].metalCost + UnitDefNames[groupunit].energyCost)*unitSpawnerModuleConfig.spawnchancecostscale
				local groupsize = math.ceil((groupsize/cost)*unitSpawnerModuleConfig.groupsizemultiplier)
				--Spring.Echo("groupsize 2: "..groupsize)
				
				for i=1, groupsize do
					Spring.CreateUnit(groupunit..scavconfig.unitnamesuffix, posx+math.random(-groupsize*10,groupsize*10), posy, posz+math.random(-groupsize*10,groupsize*10), math.random(0,3),GaiaTeamID)
					Spring.CreateUnit("scavengerdroppod_scav", posx+math.random(-groupsize*10,groupsize*10), posy, posz+math.random(-groupsize*10,groupsize*10), math.random(0,3),GaiaTeamID)
				end
			end
		else
			UnitSpawnChance = UnitSpawnChance - 1
		end
	end
end			