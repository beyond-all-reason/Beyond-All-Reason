
local function invasion(currentFrame)
ScavSendNotification("scav_eventswarm")
local invasionUnitsLand = {"armflea_scav", "armfav_scav", "corfav_scav", "armbeaver_scav", "cormuskrat_scav",}
local invasionUnitsSea = {"armbeaver_scav","cormuskrat_scav",}
local groupsize = (globalScore / scavconfig.unitSpawnerModuleConfig.globalscoreperoneunit)*spawnmultiplier
local groupsize = groupsize*((scavconfig.unitSpawnerModuleConfig.landmultiplier*scavconfig.unitSpawnerModuleConfig.seamultiplier*scavconfig.unitSpawnerModuleConfig.airmultiplier)*0.33)*scavconfig.unitSpawnerModuleConfig.t0multiplier*4
local groupsize = math.ceil(groupsize*(teamcount/2))
	for i = 1,groupsize do
		for y = 1,100 do
			local posx = math_random(150,mapsizeX-150)
			local posz = math_random(150,mapsizeZ-150)
			local posy = Spring.GetGroundHeight(posx, posz)
			local CanSpawnLand = positionCheckLibrary.SurfaceCheck(posx, posy, posz, 150)
			local CanSpawnSea = positionCheckLibrary.SurfaceCheck(posx, posy, posz, 150, true)
			CanSpawnEvent = positionCheckLibrary.OccupancyCheck(posx, posy, posz, 150)
			if CanSpawnEvent then
				CanSpawnEvent = positionCheckLibrary.FlatAreaCheck(posx, posy, posz, 150)
			end
			if CanSpawnEvent then
				CanSpawnEvent = positionCheckLibrary.VisibilityCheckEnemy(posx, posy, posz, 150, ScavengerAllyTeamID, true, true, false)
			end
			if CanSpawnEvent then
				CanSpawnEvent = positionCheckLibrary.MapEdgeCheck(posx, posy, posz, 150)
			end
			if CanSpawnEvent then
				if CanSpawnLand == true then
					--spawnQueueLibrary.AddToSpawnQueue(staticUnitList.scavSpawnEffectUnit, posx, posy, posz, math_random(0,3),ScavengerTeamID, currentFrame+(i))
					spawnQueueLibrary.AddToSpawnQueue(invasionUnitsLand[math.random(1,#invasionUnitsLand)], posx, posy, posz, math_random(0,3),ScavengerTeamID, currentFrame+90+(i))
					--Spring.CreateUnit(invasionUnitsLand[pickedInvasionUnitLand], posx, posy, posz, math_random(0,3),ScavengerTeamID)
				elseif CanSpawnSea == true then
					--spawnQueueLibrary.AddToSpawnQueue(staticUnitList.scavSpawnEffectUnit, posx, posy, posz, math_random(0,3),ScavengerTeamID, currentFrame+(i))
					spawnQueueLibrary.AddToSpawnQueue(invasionUnitsSea[math.random(1,#invasionUnitsSea)], posx, posy, posz, math_random(0,3),ScavengerTeamID, currentFrame+90+(i))
					--Spring.CreateUnit(invasionUnitsSea[pickedInvasionUnitLand], posx, posy, posz, math_random(0,3),ScavengerTeamID)
				end
				break
			end
		end
	end
end


local function raptorInvasion1(currentFrame)
	Spring.Echo("Raptor Invasion Event")
	local scavUnits = Spring.GetTeamUnits(ScavengerTeamID)
	local raptors = {"raptor1_scav","raptor1b_scav","raptor1c_scav","raptor1d_scav","raptor1x_scav","raptor1y_scav","raptor1z_scav","raptors1_scav","raptor_dodo1_scav","raptorc3_scav","raptorc3b_scav","raptorc3c_scav","raptorw2_scav",}
	for y = 1,#scavUnits do
		local unitID = scavUnits[y]
		local unitDefID = Spring.GetUnitDefID(unitID)
		local unitName = UnitDefs[unitDefID].name
		if unitName == "raptor_hive_scav" then
			EventRaptorSpawner = unitID
			local posx, posy, posz = Spring.GetUnitPosition(unitID)
			
			local groupsize = (globalScore / scavconfig.unitSpawnerModuleConfig.globalscoreperoneunit)*spawnmultiplier
			local groupsize = groupsize*scavconfig.unitSpawnerModuleConfig.landmultiplier*scavconfig.unitSpawnerModuleConfig.t0multiplier
			local groupsize = math.ceil(groupsize*(teamcount/2))
			for z = 1,groupsize do
				Spring.CreateUnit(raptors[math_random(1,#raptors)], posx+math_random(-300,300), posy, posz+math_random(-300,300), math_random(0,3),ScavengerTeamID)
			end
			break
		end
		if y == #scavUnits and unitName ~= "raptor_hive_scav" then
			for i = 1,1000 do
				local posx = math_random(300,mapsizeX-300)
				local posz = math_random(300,mapsizeZ-300)
				local posy = Spring.GetGroundHeight(posx, posz)
				CanSpawnEvent = positionCheckLibrary.OccupancyCheck(posx, posy, posz, 300)
				if CanSpawnEvent then
					CanSpawnEvent = positionCheckLibrary.FlatAreaCheck(posx, posy, posz, 300)
				end
				if CanSpawnEvent then
					CanSpawnEvent = positionCheckLibrary.VisibilityCheckEnemy(posx, posy, posz, radius, ScavengerAllyTeamID, true, true, false)
				end
				if CanSpawnEvent then
					CanSpawnEvent = positionCheckLibrary.SurfaceCheck(posx, posy, posz, 300)
				end
				if CanSpawnEvent then
					CanSpawnEvent = positionCheckLibrary.MapEdgeCheck(posx, posy, posz, 300)
				end
				if CanSpawnEvent then
					Spring.CreateUnit("raptor_hive_scav", posx, posy, posz, math_random(0,3),ScavengerTeamID)
					Spring.CreateUnit("raptor_turrets_scav", posx+200+(math_random(-100,100)), posy, posz, math_random(0,3),ScavengerTeamID)
					Spring.CreateUnit("raptor_turrets_scav", posx-200+(math_random(-100,100)), posy, posz, math_random(0,3),ScavengerTeamID)
					Spring.CreateUnit("raptor_turrets_scav", posx, posy, posz+200+(math_random(-100,100)), math_random(0,3),ScavengerTeamID)
					Spring.CreateUnit("raptor_turrets_scav", posx, posy, posz-200+(math_random(-100,100)), math_random(0,3),ScavengerTeamID)
					Spring.CreateUnit("raptor_turrets_scav", posx-200+(math_random(-100,100)), posy, posz-200+(math_random(-100,100)), math_random(0,3),ScavengerTeamID)
					Spring.CreateUnit("raptor_turrets_scav", posx+200+(math_random(-100,100)), posy, posz-200+(math_random(-100,100)), math_random(0,3),ScavengerTeamID)
					Spring.CreateUnit("raptor_turrets_scav", posx-200+(math_random(-100,100)), posy, posz+200+(math_random(-100,100)), math_random(0,3),ScavengerTeamID)
					Spring.CreateUnit("raptor_turrets_scav", posx+200+(math_random(-100,100)), posy, posz+200+(math_random(-100,100)), math_random(0,3),ScavengerTeamID)
					local groupsize = (globalScore / scavconfig.unitSpawnerModuleConfig.globalscoreperoneunit)*spawnmultiplier
					local groupsize = groupsize*scavconfig.unitSpawnerModuleConfig.landmultiplier*scavconfig.unitSpawnerModuleConfig.t0multiplier
					local groupsize = math.ceil(groupsize*(teamcount/2))*3
					for z = 1,groupsize do
						Spring.CreateUnit(raptors[math_random(1,#raptors)], posx+math_random(-300,300), posy, posz+math_random(-300,300), math_random(0,3),ScavengerTeamID)
					end
					break
				end
			end
		end
	end
end

return {
	-- invasion,
	-- raptorInvasion1,
}