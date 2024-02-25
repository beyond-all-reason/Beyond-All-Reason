local function SpawnAirRaid(transport, units, posx, posy, posz, attackTarget)
	local unitCount = Spring.GetTeamUnitCount(ScavengerTeamID)
	local unitCountBuffer = scavMaxUnits*0.01
	if unitCount + unitCountBuffer < scavMaxUnits then 
		local unit = units[math_random(1,#units)]
		local TransportID = Spring.CreateUnit(transport, posx+math_random(-300,300), posy+300, posz+math_random(-300,300), math_random(0,3),ScavengerTeamID)
		local LoadedUnitID = Spring.CreateUnit(unit, posx+math_random(-300,300), posy, posz+math_random(-300,300), math_random(0,3),ScavengerTeamID)
		if TransportID and LoadedUnitID then
			local selfx, selfy, selfz = Spring.GetUnitPosition(LoadedUnitID)
			Spring.GiveOrderToUnit(LoadedUnitID, CMD.LOAD_ONTO,{TransportID}, {0})
			Spring.GiveOrderToUnit(TransportID, CMD.LOAD_UNITS,{LoadedUnitID}, {0})
			local ax, ay, az = Spring.GetUnitPosition(attackTarget)
			Spring.GiveOrderToUnit(TransportID, CMD.UNLOAD_UNIT,{ax+math_random(-300,300),ay,az+math_random(-300,300)}, {"shift"})
		end
	end
end


local function transport1(currentFrame)
	if currentFrame > scavconfig.gracePeriod*2 then
		local transportsT1 = {"armada_stork_scav", "cortex_hercules_scav",}
		local unitsT1 = {
			"armada_pawn_scav",
			"armada_shellshocker_scav",
			"armada_possum_scav",
			"armada_crocodile_scav",
			"armada_seeker_scav",
			"armada_janus_scav",
			"armada_whistler_scav",
			"armada_rocketeer_scav",
			"armada_centurion_scav",
			"armada_mace_scav",
			"armada_blitz_scav",
			"armada_pincer_scav",
			"armada_stout_scav",
			"corak_scav",
			"corthud_scav",
			"corgator_scav",
			"cormist_scav",
			"corsnap_scav",
			"cormh_scav",
			"corwolv_scav",
			"corlevlr_scav",
			"corraid_scav",
			"corhal_scav",
			"corsh_scav",
			"corstorm_scav",
			"corgarp_scav",
			"armada_constructionturret_scav",
			"cornanotc_scav",
		}
		local transportsT2 = {"armada_abductor_scav", "cortex_skyhook_scav",}
		local unitsT2 = {
			"armada_welder_scav",
			"corpyro_scav",
			"armada_gunslinger_scav",
			"armada_sprinter_scav",
			"armada_sharpshooter_scav",
			"armada_bull_scav",
			"armada_recluse_scav",
			"armada_fatboy_scav",
			"armada_ambassador_scav",
			"armada_hound_scav",
			"armada_turtle_scav",
			"armada_mauser_scav",
			"armada_tumbleweed_scav",
			"armada_jaguar_scav",
			"armada_gremlin_scav",
			"armada_amphibiousbot_scav",
			"corsumo_scav",
			"cortrem_scav",
			"corparrow_scav",
			"corhrk_scav",
			"correap_scav",
			"corvroc_scav",
			"cortex_sumo_scav",
			"cormort_scav",
			"coramph_scav",
			"corseal_scav",
			"corban_scav",
			"corgol_scav",
			"cortermite_scav",
			"cormart_scav",
			"corllt_scav",
			"armada_sentry_scav",
			"corrl_scav",
			"armada_nettle_scav",
			"corhllt_scav",
			"armada_beamer_scav",
			"armada_constructionturret_scav",
			"cornanotc_scav",
		}

		local baseNumber = ((spawnmultiplier*0.5)+(teamcount*0.5))*0.5
		local commanderOrNearestTarget = math.random(2)
		for i = 1,1000 do
			local posx = math_random(300,mapsizeX-300)
			local posz = math_random(300,mapsizeZ-300)
			local posy = Spring.GetGroundHeight(posx, posz, attackTarget)
			CanSpawnEvent = positionCheckLibrary.VisibilityCheckEnemy(posx, posy, posz, 300, ScavengerAllyTeamID, true, true, false)
			if CanSpawnEvent then
				CanSpawnEvent = positionCheckLibrary.SurfaceCheck(posx, posy, posz, 300)
			end
			if CanSpawnEvent then
				local testunit = Spring.CreateUnit(staticUnitList.scavSpawnEffectUnit, posx, posy, posz, math_random(0,3),ScavengerTeamID)
				if AliveEnemyCommanders and AliveEnemyCommandersCount > 0 and commanderOrNearestTarget == 1 then
					if AliveEnemyCommandersCount > 1 then
						for i = 1,AliveEnemyCommandersCount do
							-- let's get nearest commander
							local separation = Spring.GetUnitSeparation(testunit,AliveEnemyCommanders[i])
							if not lowestSeparation then
								lowestSeparation = separation
								attackTarget = AliveEnemyCommanders[i]
							end
							if separation < lowestSeparation then
								lowestSeparation = separation
								attackTarget = AliveEnemyCommanders[i]
							end
						end
						lowestSeparation = nil
					elseif AliveEnemyCommandersCount == 1 then
						attackTarget = AliveEnemyCommanders[1]
					end
				end
				if attackTarget == nil or commanderOrNearestTarget == 2 then
					local test = Spring.CreateUnit(staticUnitList.scavSpawnEffectUnit, posx, posy, posz, math.random(0, 3), ScavengerTeamID)
					attackTarget = Spring.GetUnitNearestEnemy(test, 200000, true)
				end
				if attackTarget == nil or commanderOrNearestTarget == 2 then
					local test = Spring.CreateUnit(staticUnitList.scavSpawnEffectUnit, posx, posy, posz, math.random(0, 3), ScavengerTeamID)
					attackTarget = Spring.GetUnitNearestEnemy(test, 200000, false)
				end
				local ax, ay, az = Spring.GetUnitPosition(attackTarget)
				if TierSpawnChances.T2 == 0 and TierSpawnChances.T3 == 0 and TierSpawnChances.T4 == 0 then
					local transport = transportsT1[math_random(1,#transportsT1)]
					for a = 1,math.ceil(baseNumber*12) do
						SpawnAirRaid(transport, unitsT1, posx, posy, posz, attackTarget)
					end
				elseif TierSpawnChances.T3 == 0 and TierSpawnChances.T4 == 0 then
					local transport = transportsT2[math_random(1,#transportsT2)]
					for a = 1,math.ceil(baseNumber*12) do
						SpawnAirRaid(transport, unitsT1, posx, posy, posz, attackTarget)
					end
				elseif TierSpawnChances.T4 == 0 then
					local transport = transportsT2[math_random(1,#transportsT2)]
					for a = 1,math.ceil(baseNumber*24) do
						SpawnAirRaid(transport, unitsT2, posx, posy, posz, attackTarget)
					end
				else
					local transport = transportsT2[math_random(1,#transportsT2)]
					for a = 1,math.ceil(baseNumber*32) do
						SpawnAirRaid(transport, unitsT2, posx, posy, posz, attackTarget)
					end
				end
				
				--ScavSendNotification("scav_eventcloud")
				break
			end
		end
	end
end

return {
	transport1,
	transport1,
	transport1,
	transport1,
}