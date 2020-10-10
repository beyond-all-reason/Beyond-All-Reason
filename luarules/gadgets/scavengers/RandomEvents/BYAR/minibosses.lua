
function RandomEventMiniboss1(CurrentFrame)
	Spring.Echo("MiniBoss Event")
	local T2bosses = {"corsumo_scav","corgol_scav","corparrow_scav","armfboy_scav","armmanni_scav",}
	local T3bosses = {"armmar_scav","armvang_scav","armraz_scav","corshiva_scav","corkarg_scav","corcat_scav","armlun_scav","corsok_scav","armsptkt4_scav",}
	local T4bosses = {"corkorg_scav", "corjugg_scav", "armbanth_scav","armpwt4_scav","armrattet4_scav","armvadert4_scav","cordemont4_scav","corkarganetht4_scav",}
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
			if globalScore < scavconfig.timers.T1med then
				Spring.CreateUnit(T2bosses[math_random(1,#T2bosses)], posx+math_random(-300,300), posy, posz+math_random(-300,300), math_random(0,3),GaiaTeamID)
			elseif globalScore < scavconfig.timers.T2med then
				Spring.CreateUnit(T3bosses[math_random(1,#T3bosses)], posx+math_random(-300,300), posy, posz+math_random(-300,300), math_random(0,3),GaiaTeamID)
			else
				Spring.CreateUnit(T4bosses[math_random(1,#T4bosses)], posx+math_random(-300,300), posy, posz+math_random(-300,300), math_random(0,3),GaiaTeamID)
			end
			break
		end
	end
end
table.insert(RandomEventsList,RandomEventMiniboss1)