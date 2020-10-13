
function RandomEventChickenInvasion1(CurrentFrame)
	Spring.Echo("Chicken Invasion Event")
	local scavUnits = Spring.GetTeamUnits(GaiaTeamID)
	local chickens = {"chicken1_scav","chicken1b_scav","chicken1c_scav","chicken1d_scav","chicken1x_scav","chicken1y_scav","chicken1z_scav","chickens1_scav","chicken_dodo1_scav","chickenc3_scav","chickenc3b_scav","chickenc3c_scav","chickenw2_scav",}
	for y = 1,#scavUnits do
		local unitID = scavUnits[y]
		local unitDefID = Spring.GetUnitDefID(unitID)
		local unitName = UnitDefs[unitDefID].name
		if unitName == "roost_scav" then
			EventChickenSpawner = unitID
			local posx, posy, posz = Spring.GetUnitPosition(unitID)
			
			local groupsize = (globalScore / unitSpawnerModuleConfig.globalscoreperoneunit)*spawnmultiplier
			local groupsize = groupsize*unitSpawnerModuleConfig.landmultiplier*unitSpawnerModuleConfig.t0multiplier
			local groupsize = math.ceil(groupsize*(teamcount/2))
			for z = 1,groupsize do
				Spring.CreateUnit(chickens[math_random(1,#chickens)], posx+math_random(-300,300), posy, posz+math_random(-300,300), math_random(0,3),GaiaTeamID)
			end
			break
		end
		if y == #scavUnits and unitName ~= "roost_scav" then
			for i = 1,1000 do
				local posx = math_random(300,mapsizeX-300)
				local posz = math_random(300,mapsizeZ-300)
				local posy = Spring.GetGroundHeight(posx, posz)
				CanSpawnEvent = posOccupied(posx, posy, posz, 300)
				if CanSpawnEvent then
					CanSpawnEvent = posCheck(posx, posy, posz, 300)
				end
				if CanSpawnEvent then
					CanSpawnEvent = posLosCheckNoRadar(posx, posy, posz, 300)
				end
				if CanSpawnEvent then
					CanSpawnEvent = posLandCheck(posx, posy, posz, 300)
				end
				if CanSpawnEvent then
					CanSpawnEvent = posMapsizeCheck(posx, posy, posz, 300)
				end
				if CanSpawnEvent then
					Spring.CreateUnit("roost_scav", posx, posy, posz, math_random(0,3),GaiaTeamID)
					Spring.CreateUnit("chickend1_scav", posx+200+(math_random(-100,100)), posy, posz, math_random(0,3),GaiaTeamID)
					Spring.CreateUnit("chickend1_scav", posx-200+(math_random(-100,100)), posy, posz, math_random(0,3),GaiaTeamID)
					Spring.CreateUnit("chickend1_scav", posx, posy, posz+200+(math_random(-100,100)), math_random(0,3),GaiaTeamID)
					Spring.CreateUnit("chickend1_scav", posx, posy, posz-200+(math_random(-100,100)), math_random(0,3),GaiaTeamID)
					Spring.CreateUnit("chickend1_scav", posx-200+(math_random(-100,100)), posy, posz-200+(math_random(-100,100)), math_random(0,3),GaiaTeamID)
					Spring.CreateUnit("chickend1_scav", posx+200+(math_random(-100,100)), posy, posz-200+(math_random(-100,100)), math_random(0,3),GaiaTeamID)
					Spring.CreateUnit("chickend1_scav", posx-200+(math_random(-100,100)), posy, posz+200+(math_random(-100,100)), math_random(0,3),GaiaTeamID)
					Spring.CreateUnit("chickend1_scav", posx+200+(math_random(-100,100)), posy, posz+200+(math_random(-100,100)), math_random(0,3),GaiaTeamID)
					local groupsize = (globalScore / unitSpawnerModuleConfig.globalscoreperoneunit)*spawnmultiplier
					local groupsize = groupsize*unitSpawnerModuleConfig.landmultiplier*unitSpawnerModuleConfig.t0multiplier
					local groupsize = math.ceil(groupsize*(teamcount/2))*3
					for z = 1,groupsize do
						Spring.CreateUnit(chickens[math_random(1,#chickens)], posx+math_random(-300,300), posy, posz+math_random(-300,300), math_random(0,3),GaiaTeamID)
					end
					break
				end
			end
		end
	end
end
--table.insert(RandomEventsList,RandomEventChickenInvasion1)