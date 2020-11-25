function RandomEventTransport1(CurrentFrame)
	local TransportsT1 = {"armatlas_scav", "corvalk_scav",}
	local UnitsT1 = {
	"armpw_scav", 
	"armart_scav",
	"armmh_scav",
	"armanac_scav",
	"armsh_scav",
	"armjanus_scav",
	"armsam_scav",
	"armrock_scav",
	"armwar_scav",
	"armham_scav",
	"armflash_scav",
	"armpincer_scav",
	"armstump_scav",
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
	}
	local TransportsT2 = {"armdfly_scav", "corseah_scav",}
	local UnitsT2 = {
	"armzeus_scav", 
	"corpyro_scav",
	"armmav_scav",
	"armfast_scav",
	"armsnipe_scav",
	"armbull_scav",
	"armsptk_scav",
	"armfboy_scav",
	"armanni_scav",
	"armmerl_scav",
	"armfido_scav",
	"armcroc_scav",
	"armmart_scav",
	"armvader_scav",
	"armlatnk_scav",
	"armgremlin_scav",
	"armamph_scav",
	"corsumo_scav",
	"cortrem_scav",
	"corparrow_scav",
	"corhrk_scav",
	"correap_scav",
	"corvroc_scav",
	"corcan_scav",
	"cormort_scav",
	"coramph_scav",
	"corseal_scav",
	"corban_scav",
	"corgol_scav",
	"cortermite_scav",
	"cormart_scav",
	}
	local baseNumber = ((spawnmultiplier*0.5)+(teamcount*0.5))*0.75
	for i = 1,1000 do
		local posx = math_random(300,mapsizeX-300)
		local posz = math_random(300,mapsizeZ-300)
		local posy = Spring.GetGroundHeight(posx, posz)
		CanSpawnEvent = posLosCheckNoRadar(posx, posy, posz, 300)
		if CanSpawnEvent then
			CanSpawnEvent = posLandCheck(posx, posy, posz, 300)
		end
		if CanSpawnEvent then
			local testunit = Spring.CreateUnit("scavengerdroppod_scav", posx, posy, posz, math_random(0,3),GaiaTeamID)
			if AliveEnemyCommanders and AliveEnemyCommandersCount > 0 then
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
			if attackTarget == nil then
				attackTarget = Spring.GetUnitNearestEnemy(scav, 200000, false)
			end
			local ax, ay, az = Spring.GetUnitPosition(attackTarget)
			
			if globalScore < scavconfig.timers.T1low then
				local transport = TransportsT1[math_random(1,#TransportsT1)]
				for a = 1,math.ceil(baseNumber*8) do
					local unit = UnitsT1[math_random(1,#UnitsT1)]
					local TransportID = Spring.CreateUnit(transport, posx+math_random(-300,300), posy, posz+math_random(-300,300), math_random(0,3),GaiaTeamID)
					local LoadedUnitID = Spring.CreateUnit(unit, posx+math_random(-300,300), posy, posz+math_random(-300,300), math_random(0,3),GaiaTeamID)
					local selfx, selfy, selfz = Spring.GetUnitPosition(LoadedUnitID)
					Spring.GiveOrderToUnit(LoadedUnitID, CMD.LOAD_ONTO,{TransportID}, {0})
					Spring.GiveOrderToUnit(TransportID, CMD.LOAD_UNITS,{LoadedUnitID}, {0})
					Spring.GiveOrderToUnit(TransportID, CMD.UNLOAD_UNIT,{ax+math_random(-300,300),ay,az+math_random(-300,300)}, {"shift"})
				end
			elseif globalScore < scavconfig.timers.T1high then
				local transport = TransportsT1[math_random(1,#TransportsT1)]
				for a = 1,math.ceil(baseNumber*12) do
					local unit = UnitsT1[math_random(1,#UnitsT1)]
					local TransportID = Spring.CreateUnit(transport, posx+math_random(-300,300), posy, posz+math_random(-300,300), math_random(0,3),GaiaTeamID)
					local LoadedUnitID = Spring.CreateUnit(unit, posx+math_random(-300,300), posy, posz+math_random(-300,300), math_random(0,3),GaiaTeamID)
					local selfx, selfy, selfz = Spring.GetUnitPosition(LoadedUnitID)
					Spring.GiveOrderToUnit(LoadedUnitID, CMD.LOAD_ONTO,{TransportID}, {0})
					Spring.GiveOrderToUnit(TransportID, CMD.LOAD_UNITS,{LoadedUnitID}, {0})
					Spring.GiveOrderToUnit(TransportID, CMD.UNLOAD_UNIT,{ax+math_random(-300,300),ay,az+math_random(-300,300)}, {"shift"})
				end
			elseif globalScore < scavconfig.timers.T2start then
				local transport = TransportsT1[math_random(1,#TransportsT1)]
				for a = 1,math.ceil(baseNumber*16) do
					local unit = UnitsT1[math_random(1,#UnitsT1)]
					local TransportID = Spring.CreateUnit(transport, posx+math_random(-300,300), posy, posz+math_random(-300,300), math_random(0,3),GaiaTeamID)
					local LoadedUnitID = Spring.CreateUnit(unit, posx+math_random(-300,300), posy, posz+math_random(-300,300), math_random(0,3),GaiaTeamID)
					local selfx, selfy, selfz = Spring.GetUnitPosition(LoadedUnitID)
					Spring.GiveOrderToUnit(LoadedUnitID, CMD.LOAD_ONTO,{TransportID}, {0})
					Spring.GiveOrderToUnit(TransportID, CMD.LOAD_UNITS,{LoadedUnitID}, {0})
					Spring.GiveOrderToUnit(TransportID, CMD.UNLOAD_UNIT,{ax+math_random(-300,300),ay,az+math_random(-300,300)}, {"shift"})
				end
			elseif globalScore < scavconfig.timers.T2low then
				local transport = TransportsT1[math_random(1,#TransportsT1)]
				for a = 1,math.ceil(baseNumber*20) do
					local unit = UnitsT1[math_random(1,#UnitsT1)]
					local TransportID = Spring.CreateUnit(transport, posx+math_random(-300,300), posy, posz+math_random(-300,300), math_random(0,3),GaiaTeamID)
					local LoadedUnitID = Spring.CreateUnit(unit, posx+math_random(-300,300), posy, posz+math_random(-300,300), math_random(0,3),GaiaTeamID)
					local selfx, selfy, selfz = Spring.GetUnitPosition(LoadedUnitID)
					Spring.GiveOrderToUnit(LoadedUnitID, CMD.LOAD_ONTO,{TransportID}, {0})
					Spring.GiveOrderToUnit(TransportID, CMD.LOAD_UNITS,{LoadedUnitID}, {0})
					Spring.GiveOrderToUnit(TransportID, CMD.UNLOAD_UNIT,{ax+math_random(-300,300),ay,az+math_random(-300,300)}, {"shift"})
				end
			elseif globalScore < scavconfig.timers.T2high then
				local transport = TransportsT1[math_random(1,#TransportsT1)]
				for a = 1,math.ceil(baseNumber*24) do
					local unit = UnitsT1[math_random(1,#UnitsT1)]
					local TransportID = Spring.CreateUnit(transport, posx+math_random(-300,300), posy, posz+math_random(-300,300), math_random(0,3),GaiaTeamID)
					local LoadedUnitID = Spring.CreateUnit(unit, posx+math_random(-300,300), posy, posz+math_random(-300,300), math_random(0,3),GaiaTeamID)
					local selfx, selfy, selfz = Spring.GetUnitPosition(LoadedUnitID)
					Spring.GiveOrderToUnit(LoadedUnitID, CMD.LOAD_ONTO,{TransportID}, {0})
					Spring.GiveOrderToUnit(TransportID, CMD.LOAD_UNITS,{LoadedUnitID}, {0})
					Spring.GiveOrderToUnit(TransportID, CMD.UNLOAD_UNIT,{ax+math_random(-300,300),ay,az+math_random(-300,300)}, {"shift"})
				end
			elseif globalScore < scavconfig.timers.T3start then
				local transport = TransportsT2[math_random(1,#TransportsT2)]
				for a = 1,math.ceil(baseNumber*20) do
					local unit = UnitsT2[math_random(1,#UnitsT2)]
					local TransportID = Spring.CreateUnit(transport, posx+math_random(-300,300), posy, posz+math_random(-300,300), math_random(0,3),GaiaTeamID)
					local LoadedUnitID = Spring.CreateUnit(unit, posx+math_random(-300,300), posy, posz+math_random(-300,300), math_random(0,3),GaiaTeamID)
					local selfx, selfy, selfz = Spring.GetUnitPosition(LoadedUnitID)
					Spring.GiveOrderToUnit(LoadedUnitID, CMD.LOAD_ONTO,{TransportID}, {0})
					Spring.GiveOrderToUnit(TransportID, CMD.LOAD_UNITS,{LoadedUnitID}, {0})
					Spring.GiveOrderToUnit(TransportID, CMD.UNLOAD_UNIT,{ax+math_random(-300,300),ay,az+math_random(-300,300)}, {"shift"})
				end
			elseif globalScore < scavconfig.timers.T3low then
				local transport = TransportsT2[math_random(1,#TransportsT2)]
				for a = 1,math.ceil(baseNumber*22) do
					local unit = UnitsT2[math_random(1,#UnitsT2)]
					local TransportID = Spring.CreateUnit(transport, posx+math_random(-300,300), posy, posz+math_random(-300,300), math_random(0,3),GaiaTeamID)
					local LoadedUnitID = Spring.CreateUnit(unit, posx+math_random(-300,300), posy, posz+math_random(-300,300), math_random(0,3),GaiaTeamID)
					local selfx, selfy, selfz = Spring.GetUnitPosition(LoadedUnitID)
					Spring.GiveOrderToUnit(LoadedUnitID, CMD.LOAD_ONTO,{TransportID}, {0})
					Spring.GiveOrderToUnit(TransportID, CMD.LOAD_UNITS,{LoadedUnitID}, {0})
					Spring.GiveOrderToUnit(TransportID, CMD.UNLOAD_UNIT,{ax+math_random(-300,300),ay,az+math_random(-300,300)}, {"shift"})
				end
			elseif globalScore < scavconfig.timers.T3high then
				local transport = TransportsT2[math_random(1,#TransportsT2)]
				for a = 1,math.ceil(baseNumber*24) do
					local unit = UnitsT2[math_random(1,#UnitsT2)]
					local TransportID = Spring.CreateUnit(transport, posx+math_random(-300,300), posy, posz+math_random(-300,300), math_random(0,3),GaiaTeamID)
					local LoadedUnitID = Spring.CreateUnit(unit, posx+math_random(-300,300), posy, posz+math_random(-300,300), math_random(0,3),GaiaTeamID)
					local selfx, selfy, selfz = Spring.GetUnitPosition(LoadedUnitID)
					Spring.GiveOrderToUnit(LoadedUnitID, CMD.LOAD_ONTO,{TransportID}, {0})
					Spring.GiveOrderToUnit(TransportID, CMD.LOAD_UNITS,{LoadedUnitID}, {0})
					Spring.GiveOrderToUnit(TransportID, CMD.UNLOAD_UNIT,{ax+math_random(-300,300),ay,az+math_random(-300,300)}, {"shift"})
				end
			elseif globalScore < scavconfig.timers.T4start then
				local transport = TransportsT2[math_random(1,#TransportsT2)]
				for a = 1,math.ceil(baseNumber*26) do
					local unit = UnitsT2[math_random(1,#UnitsT2)]
					local TransportID = Spring.CreateUnit(transport, posx+math_random(-300,300), posy, posz+math_random(-300,300), math_random(0,3),GaiaTeamID)
					local LoadedUnitID = Spring.CreateUnit(unit, posx+math_random(-300,300), posy, posz+math_random(-300,300), math_random(0,3),GaiaTeamID)
					local selfx, selfy, selfz = Spring.GetUnitPosition(LoadedUnitID)
					Spring.GiveOrderToUnit(LoadedUnitID, CMD.LOAD_ONTO,{TransportID}, {0})
					Spring.GiveOrderToUnit(TransportID, CMD.LOAD_UNITS,{LoadedUnitID}, {0})
					Spring.GiveOrderToUnit(TransportID, CMD.UNLOAD_UNIT,{ax+math_random(-300,300),ay,az+math_random(-300,300)}, {"shift"})
				end
			elseif globalScore < scavconfig.timers.T4low then
				local transport = TransportsT2[math_random(1,#TransportsT2)]
				for a = 1,math.ceil(baseNumber*28) do
					local unit = UnitsT2[math_random(1,#UnitsT2)]
					local TransportID = Spring.CreateUnit(transport, posx+math_random(-300,300), posy, posz+math_random(-300,300), math_random(0,3),GaiaTeamID)
					local LoadedUnitID = Spring.CreateUnit(unit, posx+math_random(-300,300), posy, posz+math_random(-300,300), math_random(0,3),GaiaTeamID)
					local selfx, selfy, selfz = Spring.GetUnitPosition(LoadedUnitID)
					Spring.GiveOrderToUnit(LoadedUnitID, CMD.LOAD_ONTO,{TransportID}, {0})
					Spring.GiveOrderToUnit(TransportID, CMD.LOAD_UNITS,{LoadedUnitID}, {0})
					Spring.GiveOrderToUnit(TransportID, CMD.UNLOAD_UNIT,{ax+math_random(-300,300),ay,az+math_random(-300,300)}, {"shift"})
				end
			elseif globalScore < scavconfig.timers.T4high then
				local transport = TransportsT2[math_random(1,#TransportsT2)]
				for a = 1,math.ceil(baseNumber*30) do
					local unit = UnitsT2[math_random(1,#UnitsT2)]
					local TransportID = Spring.CreateUnit(transport, posx+math_random(-300,300), posy, posz+math_random(-300,300), math_random(0,3),GaiaTeamID)
					local LoadedUnitID = Spring.CreateUnit(unit, posx+math_random(-300,300), posy, posz+math_random(-300,300), math_random(0,3),GaiaTeamID)
					local selfx, selfy, selfz = Spring.GetUnitPosition(LoadedUnitID)
					Spring.GiveOrderToUnit(LoadedUnitID, CMD.LOAD_ONTO,{TransportID}, {0})
					Spring.GiveOrderToUnit(TransportID, CMD.LOAD_UNITS,{LoadedUnitID}, {0})
					Spring.GiveOrderToUnit(TransportID, CMD.UNLOAD_UNIT,{ax+math_random(-300,300),ay,az+math_random(-300,300)}, {"shift"})
				end
			else
				local transport = TransportsT2[math_random(1,#TransportsT2)]
				for a = 1,math.ceil(baseNumber*32) do
					local unit = UnitsT2[math_random(1,#UnitsT2)]
					local TransportID = Spring.CreateUnit(transport, posx+math_random(-300,300), posy, posz+math_random(-300,300), math_random(0,3),GaiaTeamID)
					local LoadedUnitID = Spring.CreateUnit(unit, posx+math_random(-300,300), posy, posz+math_random(-300,300), math_random(0,3),GaiaTeamID)
					local selfx, selfy, selfz = Spring.GetUnitPosition(LoadedUnitID)
					Spring.GiveOrderToUnit(LoadedUnitID, CMD.LOAD_ONTO,{TransportID}, {0})
					Spring.GiveOrderToUnit(TransportID, CMD.LOAD_UNITS,{LoadedUnitID}, {0})
					Spring.GiveOrderToUnit(TransportID, CMD.UNLOAD_UNIT,{ax+math_random(-300,300),ay,az+math_random(-300,300)}, {"shift"})
				end
			end
			
			--ScavSendNotification("scav_eventcloud")
			break
		end
	end
end
table.insert(RandomEventsList,RandomEventTransport1)
table.insert(RandomEventsList,RandomEventTransport1)