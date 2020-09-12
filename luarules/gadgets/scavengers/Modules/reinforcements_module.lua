local ReinforcementsCountPerTeam = {}
local TryingToSpawnReinforcements = {}
local ReinforcementsFaction = {}
local ReinforcementsChancePerTeam = {}
local numOfSpawnBeaconsTeamsForSpawn = {}
local CaptureProgressForBeacons = {}

function CaptureBeacons(n)
	local scavengerunits = Spring.GetTeamUnits(GaiaTeamID)
	local spGetUnitTeam = Spring.GetUnitTeam

	for i = 1,#scavengerunits do
		local scav = scavengerunits[i]
		local scavDef = Spring.GetUnitDefID(scav)
		if scavSpawnBeacon[scav] then
			if not CaptureProgressForBeacons[scav] then
				CaptureProgressForBeacons[scav] = 0
				Spring.SetUnitHealth(scav, {capture = CaptureProgressForBeacons[scav]})
			end
			local posx,posy,posz = Spring.GetUnitPosition(scav)
			--Spring.Echo("posx "..posx)
			--Spring.Echo("posz "..posz)
			unitsAround = Spring.GetUnitsInCylinder(posx, posz, 256)
			--Spring.Echo("#unitsAround "..#unitsAround)
			CapturingUnits = {}
			CapturingUnitsTeam = {}
			CapturingUnitsTeamTest = {}
			local TeamsCapturing = 0
			CapturingUnits[scav] = 0

			for j = 1,#unitsAround do
				local unitID = unitsAround[j]
				local unitTeamID = spGetUnitTeam(unitID)
				local unitAllyTeam = Spring.GetUnitAllyTeam(unitID)
				local LuaAI = Spring.GetTeamLuaAI(unitTeamID)
				local _,_,_,isAI,_,_ = Spring.GetTeamInfo(unitTeamID)
				if (not LuaAI) and unitTeamID ~= GaiaTeamID and unitTeamID ~= Spring.GetGaiaTeamID() and (not isAI) then
					captureraiTeam = false
				else
					captureraiTeam = false -- true
				end
				if not CapturingUnitsTeamTest[unitAllyTeam] then
					CapturingUnitsTeamTest[unitAllyTeam] = true
					if unitTeamID ~= GaiaTeamID and captureraiTeam == false then
						TeamsCapturing = TeamsCapturing + 1
						if TeamsCapturing > 1 then
							break
						end
					end
				end
				captureraiTeam = nil
			end

			for j = 1,#unitsAround do
				local unitID = unitsAround[j]
				local unitTeamID = spGetUnitTeam(unitID)
				if not CapturingUnitsTeam[unitTeamID] then
					CapturingUnitsTeam[unitTeamID] = 0
				end
				local unitDefID = Spring.GetUnitDefID(unitID)
				local LuaAI = Spring.GetTeamLuaAI(unitTeamID)
				local _,_,_,isAI,_,_ = Spring.GetTeamInfo(unitTeamID)

				if (not LuaAI) and unitTeamID ~= GaiaTeamID and unitTeamID ~= Spring.GetGaiaTeamID() and (not isAI) then
					captureraiTeam = false
				else
					captureraiTeam = false -- true
				end

				if not CapturingUnitsTeam[unitTeamID] then
					CapturingUnitsTeam[unitTeamID] = 0
				end

				for k = 1,#BeaconCaptureExcludedUnits do
					if UnitDefs[unitDefID].name == BeaconCaptureExcludedUnits[k] then
						IsUnitExcluded = true
						break
					else
						IsUnitExcluded = false
					end
				end
				
				if unitDefID == scavDef then
					CaptureProgressForBeacons[scav] = CaptureProgressForBeacons[scav] - 0.0005
					--Spring.Echo("uncapturing myself")
				elseif unitTeamID == GaiaTeamID and (not unitDefID == scavDef) then
					CaptureProgressForBeacons[scav] = CaptureProgressForBeacons[scav] - 1
					--Spring.Echo("uncapturing our beacon")
				elseif captureraiTeam == false and unitTeamID ~= GaiaTeamID and unitTeamID ~= Spring.GetGaiaTeamID() and IsUnitExcluded == false and (not UnitDefs[unitDefID].canFly) then
					CaptureProgressForBeacons[scav] = CaptureProgressForBeacons[scav] + 0.001
					CapturingUnitsTeam[unitTeamID] = CapturingUnitsTeam[unitTeamID] + 1
					--Spring.Echo("capturing scav beacon")
				end
				if CaptureProgressForBeacons[scav] < 0 then
					CaptureProgressForBeacons[scav] = 0
					--Spring.Echo("capture below 0")
				end
				if CaptureProgressForBeacons[scav] > 1 then
					CaptureProgressForBeacons[scav] = 1
					--Spring.Echo("capture above 1")
				end
				Spring.SetUnitHealth(scav, {capture = CaptureProgressForBeacons[scav]})

				if TeamsCapturing < 2 and captureraiTeam == false and CaptureProgressForBeacons[scav] >= 1 then
					CaptureProgressForBeacons[scav] = 0
					Spring.SetUnitHealth(scav, {capture = 0})
					Spring.TransferUnit(scav, unitTeamID, true)
					captureraiTeam = nil
					break
				end
				captureraiTeam = nil
				IsUnitExcluded = nil
			end
			CapturingUnits = nil
			CapturingUnitsTeam = nil
			unitsAround = nil
		end
	end
end

function SetBeaconsResourceProduction(n)
	if globalScore then
		local units = Spring.GetAllUnits()
		local minutes = math.ceil(Spring.GetGameSeconds()/300)
		local beaconmetalproduction = minutes
		local beaconenergyproduction = beaconmetalproduction*20
		for i = 1,#units do
			local unitID = units[i]
			local unitDefID = Spring.GetUnitDefID(unitID)
			local name = UnitDefs[unitDefID].name
			if name ==	"scavengerdroppodbeacon_scav" then
				--Spring.AddUnitResource(unitID, "m", beaconmetalproduction)
				Spring.AddUnitResource(unitID, "e", beaconenergyproduction)
			end
		end
	end
end

-- function SpawnDefencesAfterCapture(unitID, teamID)
	-- local spawnTier = math_random(1,100)
	-- if spawnTier <= TierSpawnChances.T0 then
		-- grouptier = BeaconDefenceStructuresT0
	-- elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 then
		-- grouptier = BeaconDefenceStructuresT1
	-- elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 then
		-- grouptier = BeaconDefenceStructuresT2
	-- elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 + TierSpawnChances.T4 then
		-- grouptier = BeaconDefenceStructuresT3
	-- end
	-- if spawnTier <= TierSpawnChances.T0 then
		-- grouptiersea = StartboxDefenceStructuresT0Sea
	-- elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 then
		-- grouptiersea = StartboxDefenceStructuresT1Sea
	-- elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 then
		-- grouptiersea = StartboxDefenceStructuresT2Sea
	-- elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 + TierSpawnChances.T4 then
		-- grouptiersea = StartboxDefenceStructuresT3Sea
	-- end

	-- local posx,posy,posz = Spring.GetUnitPosition(unitID)
	-- local posy = Spring.GetGroundHeight(posx, posz)
	-- local n = Spring.GetGameFrame()

	-- local r = grouptier[math_random(1,#grouptier)]
	-- local r2 = grouptiersea[math_random(1,#grouptiersea)]
	-- Spring.CreateUnit("scavengerdroppodfriendly", posx-128, posy, posz-128, math_random(0,3),teamID)
	-- local posy = Spring.GetGroundHeight(posx-128, posz-128)
	-- if posy > 0 then
		-- QueueSpawn(r..scavconfig.unitnamesuffix, posx-128, posy, posz-128, math_random(0,3),teamID, n+90)
	-- else
		-- QueueSpawn(r2..scavconfig.unitnamesuffix, posx-128, posy, posz-128, math_random(0,3),teamID, n+90)
	-- end

	-- local r = grouptier[math_random(1,#grouptier)]
	-- local r2 = grouptiersea[math_random(1,#grouptiersea)]
	-- Spring.CreateUnit("scavengerdroppodfriendly", posx+128, posy, posz+128, math_random(0,3),teamID)
	-- local posy = Spring.GetGroundHeight(posx+128, posz+128)
	-- if posy > 0 then
		-- QueueSpawn(r..scavconfig.unitnamesuffix, posx+128, posy, posz+128, math_random(0,3),teamID, n+90)
	-- else
		-- QueueSpawn(r2..scavconfig.unitnamesuffix, posx+128, posy, posz+128, math_random(0,3),teamID, n+90)
	-- end

	-- local r = grouptier[math_random(1,#grouptier)]
	-- local r2 = grouptiersea[math_random(1,#grouptiersea)]
	-- Spring.CreateUnit("scavengerdroppodfriendly", posx-128, posy, posz+128, math_random(0,3),teamID)
	-- local posy = Spring.GetGroundHeight(posx-128, posz+128)
	-- if posy > 0 then
		-- QueueSpawn(r..scavconfig.unitnamesuffix, posx-128, posy, posz+128, math_random(0,3),teamID, n+90)
	-- else
		-- QueueSpawn(r2..scavconfig.unitnamesuffix, posx-128, posy, posz+128, math_random(0,3),teamID, n+90)
	-- end

	-- local r = grouptier[math_random(1,#grouptier)]
	-- local r2 = grouptiersea[math_random(1,#grouptiersea)]
	-- Spring.CreateUnit("scavengerdroppodfriendly", posx+128, posy, posz-128, math_random(0,3),teamID)
	-- local posy = Spring.GetGroundHeight(posx+128, posz-128)
	-- if posy > 0 then
		-- QueueSpawn(r..scavconfig.unitnamesuffix, posx+128, posy, posz-128, math_random(0,3),teamID, n+90)
	-- else
		-- QueueSpawn(r2..scavconfig.unitnamesuffix, posx+128, posy, posz-128, math_random(0,3),teamID, n+90)
	-- end

	-- grouptier = nil
	-- grouptiersea = nil
-- end

function spawnPlayerReinforcements(n)
    --mapsizeX
    --mapsizeZ
    --ScavengerStartboxXMin
    --ScavengerStartboxZMin
    --ScavengerStartboxXMax
    --ScavengerStartboxZMax
    --GaiaTeamID
    --GaiaAllyTeamID
    --posCheck(posx, posy, posz, posradius)
    --posOccupied(posx, posy, posz, posradius)
    for _,teamID in ipairs(Spring.GetTeamList()) do
		local LuaAI = Spring.GetTeamLuaAI(teamID)
		local _,teamLeader,isDead,isAI,_,allyTeamID = Spring.GetTeamInfo(teamID)

		if (not LuaAI) and teamID ~= GaiaTeamID and teamID ~= Spring.GetGaiaTeamID() and (not isAI) then
			local playerName = Spring.GetPlayerInfo(teamLeader)
			if not numOfSpawnBeaconsTeams[teamID] then
				numOfSpawnBeaconsTeams[teamID] = 0
			end
			if not numOfSpawnBeaconsTeamsForSpawn[teamID] or numOfSpawnBeaconsTeamsForSpawn[teamID] == 0 then
				numOfSpawnBeaconsTeamsForSpawn[teamID] = 2
			else
				numOfSpawnBeaconsTeamsForSpawn[teamID] = numOfSpawnBeaconsTeams[teamID] + 2
			end


			if not ReinforcementsCountPerTeam[teamID] then
				ReinforcementsCountPerTeam[teamID] = 0
			end
			if not ReinforcementsChancePerTeam[teamID] then
				ReinforcementsChancePerTeam[teamID] = (((unitSpawnerModuleConfig.spawnchance)*10)/numOfSpawnBeaconsTeamsForSpawn[teamID])
			end

			if not isDead then
				if TryingToSpawnReinforcements[teamID] == true then
					local playerunits = Spring.GetTeamUnits(teamID)
					PlayerSpawnBeacons = {}
					for i = 1,#playerunits do
						local playerbeacon = playerunits[i]
						local playerbeaconDef = Spring.GetUnitDefID(playerbeacon)
						local UnitName = UnitDefs[playerbeaconDef].name
						if UnitName == "scavengerdroppodbeacon_scav" then
							table.insert(PlayerSpawnBeacons,playerbeacon)
						end
					end
					--numOfSpawnBeaconsTeams[teamID] = 10
					if numOfSpawnBeaconsTeams[teamID] == 1 then
						pickedBeacon = PlayerSpawnBeacons[1]
					elseif numOfSpawnBeaconsTeams[teamID] > 1 then
						pickedBeacon = PlayerSpawnBeacons[math_random(1,#PlayerSpawnBeacons)]
					else
						pickedBeacon = nil
						TryingToSpawnReinforcements[teamID] = false
						ReinforcementsChancePerTeam[teamID] = (((unitSpawnerModuleConfig.spawnchance)*10)/numOfSpawnBeaconsTeamsForSpawn[teamID])
					end
					PlayerSpawnBeacons = nil
					if pickedBeacon then
						if not globalScore then
							teamsCheck()
						end
						local groupsize = (bestTeamScore / unitSpawnerModuleConfig.globalscoreperoneunit)*spawnmultiplier
						local groupsize = math.ceil(groupsize*2)
						if scorePerTeam[teamID] < bestTeamScore*2 then
							groupsize = math.ceil(groupsize*2)
						end
						local posradius = 160
						local posx,posy,posz = Spring.GetUnitPosition(pickedBeacon)
						local posy = Spring.GetGroundHeight(posx, posz)
						local spawnTier = math_random(1,100)
						local aircraftchance = math_random(0,unitSpawnerModuleConfig.aircraftchance)
						if aircraftchance == 0 then
							if spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 then
								groupunit = T1ReinforcementAirUnits[math_random(1,#T1ReinforcementAirUnits)]
								groupsize = groupsize*unitSpawnerModuleConfig.airmultiplier*unitSpawnerModuleConfig.t1multiplier
							elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 then
								groupunit = T2ReinforcementAirUnits[math_random(1,#T2ReinforcementAirUnits)]
								groupsize = groupsize*unitSpawnerModuleConfig.airmultiplier*unitSpawnerModuleConfig.t2multiplier
							elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 then
								groupunit = T3ReinforcementAirUnits[math_random(1,#T3ReinforcementAirUnits)]
								groupsize = 5
							elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 + TierSpawnChances.T4 then
								groupunit = T4ReinforcementAirUnits[math_random(1,#T4ReinforcementAirUnits)]
								groupsize = 2
							end
						elseif posy > -20 then
							if spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 then
								groupunit = T1ReinforcementLandUnits[math_random(1,#T1ReinforcementLandUnits)]
								groupsize = groupsize*unitSpawnerModuleConfig.landmultiplier*unitSpawnerModuleConfig.t1multiplier
							elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 then
								groupunit = T2ReinforcementLandUnits[math_random(1,#T2ReinforcementLandUnits)]
								groupsize = groupsize*unitSpawnerModuleConfig.landmultiplier*unitSpawnerModuleConfig.t2multiplier
							elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 then
								groupunit = T3ReinforcementLandUnits[math_random(1,#T3ReinforcementLandUnits)]
								groupsize = 5
							elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 + TierSpawnChances.T4 then
								groupunit = T4ReinforcementLandUnits[math_random(1,#T4ReinforcementLandUnits)]
								groupsize = 2
							end
						elseif posy <= -20 then
							if spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 then
								groupunit = T1ReinforcementSeaUnits[math_random(1,#T1ReinforcementSeaUnits)]
								groupsize = groupsize*unitSpawnerModuleConfig.seamultiplier*unitSpawnerModuleConfig.t1multiplier
							elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 then
								groupunit = T2ReinforcementSeaUnits[math_random(1,#T2ReinforcementSeaUnits)]
								groupsize = groupsize*unitSpawnerModuleConfig.seamultiplier*unitSpawnerModuleConfig.t2multiplier
							elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 then
								groupunit = T3ReinforcementSeaUnits[math_random(1,#T3ReinforcementSeaUnits)]
								groupsize = 5
							elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 + TierSpawnChances.T4 then
								groupunit = T4ReinforcementSeaUnits[math_random(1,#T4ReinforcementSeaUnits)]
								groupsize = 2
							end
							ScavSendMessage(playerName .."'s reinforcements detected. Units: ".. UDN[groupunit1].humanName .. "s.")
						end
						for i = 1,groupsize do
							local posx = posx+(math_random(-posradius,posradius))
							local posz = posz+(math_random(-posradius,posradius))
							local newposy = Spring.GetGroundHeight(posx, posz)
							if posy >= -20 and newposy >= -20 then
								if i then
									QueueSpawn("scavengerdroppodfriendly", posx, posy, posz, math_random(0,3),GaiaTeamID, n+(i*60))
									QueueSpawn(groupunit..scavconfig.unitnamesuffix, posx, posy, posz, math_random(0,3),GaiaTeamID, n+90+(i*60))
								else
									QueueSpawn("scavengerdroppodfriendly", posx, posy, posz, math_random(0,3),GaiaTeamID, n)
									QueueSpawn(groupunit..scavconfig.unitnamesuffix, posx, posy, posz, math_random(0,3),GaiaTeamID, n+90)
								end
							elseif posy < -20 and newposy < -20 then
								if i then
									QueueSpawn("scavengerdroppod_scav", posx, posy, posz, math_random(0,3),GaiaTeamID, n+(i*60))
									QueueSpawn(groupunit..scavconfig.unitnamesuffix, posx, posy, posz, math_random(0,3),GaiaTeamID, n+90+(i*60))
								else
									QueueSpawn("scavengerdroppod_scav", posx, posy, posz, math_random(0,3),GaiaTeamID, n)
									QueueSpawn(groupunit..scavconfig.unitnamesuffix, posx, posy, posz, math_random(0,3),GaiaTeamID, n+90)
								end
							end
						end
						groupsize = nil
						groupunit1 = nil
						groupunit2 = nil
						TryingToSpawnReinforcements[teamID] = false
						ReinforcementsCountPerTeam[teamID] = ReinforcementsCountPerTeam[teamID] + 1
					end
				else
					local r = math_random(0,ReinforcementsChancePerTeam[teamID])
					if r == 0 or ReinforcementsCountPerTeam[teamID] == 0 then
						TryingToSpawnReinforcements[teamID] = true
						ReinforcementsChancePerTeam[teamID] = (((unitSpawnerModuleConfig.spawnchance)*10)/numOfSpawnBeaconsTeamsForSpawn[teamID])
					else
						TryingToSpawnReinforcements[teamID] = false
						ReinforcementsChancePerTeam[teamID] = ReinforcementsChancePerTeam[teamID] - 1
					end
				end
			end
		end
	end
	pickedBeacon = nil
end

