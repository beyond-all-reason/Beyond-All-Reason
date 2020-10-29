
function RandomEventInvasion(CurrentFrame)
ScavSendNotification("scav_eventswarm")
local invasionUnitsLand = {"armflea_scav", "armfav_scav", "corfav_scav", "armbeaver_scav", "cormuskrat_scav",}
local invasionUnitsSea = {"armbeaver_scav","cormuskrat_scav",}
local groupsize = (globalScore / unitSpawnerModuleConfig.globalscoreperoneunit)*spawnmultiplier
local groupsize = groupsize*((unitSpawnerModuleConfig.landmultiplier*unitSpawnerModuleConfig.seamultiplier*unitSpawnerModuleConfig.airmultiplier)*0.33)*unitSpawnerModuleConfig.t0multiplier*4
local groupsize = math.ceil(groupsize*(teamcount/2))
	for i = 1,groupsize do
		for y = 1,100 do
			local posx = math_random(150,mapsizeX-150)
			local posz = math_random(150,mapsizeZ-150)
			local posy = Spring.GetGroundHeight(posx, posz)
			local CanSpawnLand = posLandCheck(posx, posy, posz, 150)
			local CanSpawnSea = posSeaCheck(posx, posy, posz, 150)
			CanSpawnEvent = posOccupied(posx, posy, posz, 150)
			if CanSpawnEvent then
				CanSpawnEvent = posCheck(posx, posy, posz, 150)
			end
			if CanSpawnEvent then
				CanSpawnEvent = posLosCheckReversed(posx, posy, posz, 150)
			end
			if CanSpawnEvent then
				CanSpawnEvent = posMapsizeCheck(posx, posy, posz, 150)
			end
			if CanSpawnEvent then
				if CanSpawnLand == true then
					QueueSpawn("scavengerdroppod_scav", posx, posy, posz, math_random(0,3),GaiaTeamID, CurrentFrame+(i))
					QueueSpawn(invasionUnitsLand[math.random(1,#invasionUnitsLand)], posx, posy, posz, math_random(0,3),GaiaTeamID, CurrentFrame+90+(i))
					--Spring.CreateUnit(invasionUnitsLand[pickedInvasionUnitLand], posx, posy, posz, math_random(0,3),GaiaTeamID)
				elseif CanSpawnSea == true then
					QueueSpawn("scavengerdroppod_scav", posx, posy, posz, math_random(0,3),GaiaTeamID, CurrentFrame+(i))
					QueueSpawn(invasionUnitsSea[math.random(1,#invasionUnitsSea)], posx, posy, posz, math_random(0,3),GaiaTeamID, CurrentFrame+90+(i))
					--Spring.CreateUnit(invasionUnitsSea[pickedInvasionUnitLand], posx, posy, posz, math_random(0,3),GaiaTeamID)
				end
				break
			end
		end
	end
end
table.insert(RandomEventsList,RandomEventInvasion)