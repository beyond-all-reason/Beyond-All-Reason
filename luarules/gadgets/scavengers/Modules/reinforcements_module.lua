local ReinforcementsCountPerTeam = {}
local TryingToSpawnReinforcements = {}
local ReinforcementsFaction = {}
local ReinforcementsChancePerTeam = {}
local numOfSpawnBeaconsTeamsForSpawn = {}
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
                        -- if GameShortName == "BYAR" and ReinforcementsCountPerTeam[teamID] == 0 then
                            -- local spGetTeamUnits = Spring.GetTeamUnits(teamID)
                            -- for i = 1,#spGetTeamUnits do
                              --  local unitID = spGetTeamUnits[i]
                             --   local unitDefID = Spring.GetUnitDefID(unitID)
                            --    local UnitName = UnitDefs[unitDefID].name
                         --       if UnitName == "armcom" then
                        --            ReinforcementsFaction[teamID] = "arm"
                         --       elseif UnitName == "corcom" then
                         --           ReinforcementsFaction[teamID] = "core"
                        --        end
                       --     end
                      --      local posradius = 160
                      --      local posx,posy,posz = Spring.GetUnitPosition(pickedBeacon)
			         --       local posy = Spring.GetGroundHeight(posx, posz)
                     --       if ReinforcementsFaction[teamID] == "arm" then
                       --         Spring.CreateUnit("scavengerdroppodfriendly", posx, posy, posz, math_random(0,3),teamID)
                       --         QueueSpawn("corcom", posx, posy, posz, math_random(0,3),teamID,n+120)
                        --        ScavSendMessage(playerName .."'s additional commander arrived.")
                       --     elseif ReinforcementsFaction[teamID] == "core" then
                         --       Spring.CreateUnit("scavengerdroppodfriendly", posx, posy, posz, math_random(0,3),teamID)
                        --        QueueSpawn("armcom", posx, posy, posz, math_random(0,3),teamID,n+120)
                       --         ScavSendMessage(playerName .."'s additional commander arrived.")
                       --     end
                      --      TryingToSpawnReinforcements[teamID] = false
                     --       ReinforcementsCountPerTeam[teamID] = ReinforcementsCountPerTeam[teamID] + 1
                        --else
                            if not globalScore then
                                teamsCheck()
                            end
                            local groupsize = (bestTeamScore / unitSpawnerModuleConfig.globalscoreperoneunit)*spawnmultiplier
                            local posradius = 160
                            local posx,posy,posz = Spring.GetUnitPosition(pickedBeacon)
                            local posy = Spring.GetGroundHeight(posx, posz)
                            local spawnTier = math_random(1,100)
                            local aircraftchance = math_random(0,unitSpawnerModuleConfig.aircraftchance)
                            if aircraftchance == 0 then
                                if spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 then
                                    groupunit1 = T1ReinforcementAirUnits[math_random(1,#T1ReinforcementAirUnits)]
                                    groupunit2 = T1ReinforcementAirUnits[math_random(1,#T1ReinforcementAirUnits)]
                                    groupsize = groupsize*unitSpawnerModuleConfig.airmultiplier*unitSpawnerModuleConfig.t1multiplier
                                elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 then
                                    groupunit1 = T2ReinforcementAirUnits[math_random(1,#T2ReinforcementAirUnits)]
                                    groupunit2 = T2ReinforcementAirUnits[math_random(1,#T2ReinforcementAirUnits)]
                                    groupsize = groupsize*unitSpawnerModuleConfig.airmultiplier*unitSpawnerModuleConfig.t2multiplier
                                elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 then
                                    groupunit1 = T3ReinforcementAirUnits[math_random(1,#T3ReinforcementAirUnits)]
                                    groupunit2 = T3ReinforcementAirUnits[math_random(1,#T3ReinforcementAirUnits)]
                                    groupsize = groupsize*unitSpawnerModuleConfig.airmultiplier*unitSpawnerModuleConfig.t3multiplier
                                elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 + TierSpawnChances.T4 then
                                    groupunit1 = T4ReinforcementAirUnits[math_random(1,#T4ReinforcementAirUnits)]
                                    groupunit2 = T4ReinforcementAirUnits[math_random(1,#T4ReinforcementAirUnits)]
                                    groupsize = groupsize*unitSpawnerModuleConfig.airmultiplier*unitSpawnerModuleConfig.t4multiplier
                                end
                            elseif posy > -20 then
                                if spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 then
                                    groupunit1 = T1ReinforcementLandUnits[math_random(1,#T1ReinforcementLandUnits)]
                                    groupunit2 = T1ReinforcementLandUnits[math_random(1,#T1ReinforcementLandUnits)]
                                    groupsize = groupsize*unitSpawnerModuleConfig.landmultiplier*unitSpawnerModuleConfig.t1multiplier
                                elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 then
                                    groupunit1 = T2ReinforcementLandUnits[math_random(1,#T2ReinforcementLandUnits)]
                                    groupunit2 = T2ReinforcementLandUnits[math_random(1,#T2ReinforcementLandUnits)]
                                    groupsize = groupsize*unitSpawnerModuleConfig.landmultiplier*unitSpawnerModuleConfig.t2multiplier
                                elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 then
                                    groupunit1 = T3ReinforcementLandUnits[math_random(1,#T3ReinforcementLandUnits)]
                                    groupunit2 = T3ReinforcementLandUnits[math_random(1,#T3ReinforcementLandUnits)]
                                    groupsize = groupsize*unitSpawnerModuleConfig.landmultiplier*unitSpawnerModuleConfig.t3multiplier
                                elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 + TierSpawnChances.T4 then
                                    groupunit1 = T4ReinforcementLandUnits[math_random(1,#T4ReinforcementLandUnits)]
                                    groupunit2 = T4ReinforcementLandUnits[math_random(1,#T4ReinforcementLandUnits)]
                                    groupsize = groupsize*unitSpawnerModuleConfig.landmultiplier*unitSpawnerModuleConfig.t4multiplier
                                end
                            elseif posy <= -20 then
                                if spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 then
                                    groupunit1 = T1ReinforcementSeaUnits[math_random(1,#T1ReinforcementSeaUnits)]
                                    groupunit2 = T1ReinforcementSeaUnits[math_random(1,#T1ReinforcementSeaUnits)]
                                    groupsize = groupsize*unitSpawnerModuleConfig.seamultiplier*unitSpawnerModuleConfig.t1multiplier
                                elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 then
                                    groupunit1 = T2ReinforcementSeaUnits[math_random(1,#T2ReinforcementSeaUnits)]
                                    groupunit2 = T2ReinforcementSeaUnits[math_random(1,#T2ReinforcementSeaUnits)]
                                    groupsize = groupsize*unitSpawnerModuleConfig.seamultiplier*unitSpawnerModuleConfig.t2multiplier
                                elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 then
                                    groupunit1 = T3ReinforcementSeaUnits[math_random(1,#T3ReinforcementSeaUnits)]
                                    groupunit2 = T3ReinforcementSeaUnits[math_random(1,#T3ReinforcementSeaUnits)]
                                    groupsize = groupsize*unitSpawnerModuleConfig.seamultiplier*unitSpawnerModuleConfig.t3multiplier
                                elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 + TierSpawnChances.T4 then
                                    groupunit1 = T4ReinforcementSeaUnits[math_random(1,#T4ReinforcementSeaUnits)]
                                    groupunit2 = T4ReinforcementSeaUnits[math_random(1,#T4ReinforcementSeaUnits)]
                                    groupsize = groupsize*unitSpawnerModuleConfig.seamultiplier*unitSpawnerModuleConfig.t4multiplier
                                end
                            end
                            groupsize = math.ceil(groupsize*5)
							if scorePerTeam[teamID] < bestTeamScore*2 then
								groupsize = math.ceil(groupsize*2)
							end
                            if groupsize == 1 then
                                ScavSendMessage(playerName .."'s reinforcements detected. Unit: ".. UDN[groupunit1].humanName .. ".")
                            else
                                ScavSendMessage(playerName .."'s reinforcements detected. Units: ".. groupsize .." ".. UDN[groupunit1].humanName .."s and ".. UDN[groupunit2].humanName .."s.")
                            end
                            for i = 1,groupsize do
                                local posx = posx+(math_random(-posradius,posradius))
                                local posz = posz+(math_random(-posradius,posradius))
                                local posy = Spring.GetGroundHeight(posx, posz)
                                if i then
                                    if i < 2 or i < groupsize/2 then
                                        QueueSpawn(groupunit1..scavconfig.unitnamesuffix, posx, posy, posz, math_random(0,3),teamID, n+100+i)
                                    else
                                        QueueSpawn(groupunit2..scavconfig.unitnamesuffix, posx, posy, posz, math_random(0,3),teamID, n+100+i)
                                    end
                                else
                                    QueueSpawn(groupunit1..scavconfig.unitnamesuffix, posx, posy, posz, math_random(0,3),teamID, n+100)
                                end
                                Spring.CreateUnit("scavengerdroppodfriendly", posx, posy, posz, math_random(0,3),teamID)
                            end
                            groupsize = nil
                            groupunit1 = nil
                            groupunit2 = nil
                            TryingToSpawnReinforcements[teamID] = false
                            ReinforcementsCountPerTeam[teamID] = ReinforcementsCountPerTeam[teamID] + 1
                        --end
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
        pickedBeacon = nil
    end

end