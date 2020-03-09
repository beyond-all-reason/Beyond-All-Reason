local ReinforcementsCountPerTeam = {}
local TryingToSpawnReinforcements = {}
local ReinforcementsFaction = {}
local ReinforcementsChancePerTeam = {}
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
            if not ReinforcementsCountPerTeam[teamID] then
                ReinforcementsCountPerTeam[teamID] = 0
            end
            if not ReinforcementsChancePerTeam[teamID] then
                ReinforcementsChancePerTeam[teamID] = 300
            end

            if not isDead then
                if TryingToSpawnReinforcements[teamID] == true then
                    if GameShortName == "BYAR" and ReinforcementsCountPerTeam[teamID] == 0 then
                        local spGetTeamUnits = Spring.GetTeamUnits(teamID)
                        for i = 1,#spGetTeamUnits do
                            local unitID = spGetTeamUnits[i]
                            local unitDefID = Spring.GetUnitDefID(unitID)
                            local UnitName = UnitDefs[unitDefID].name
                            if UnitName == "armcom" then
                                ReinforcementsFaction[teamID] = "arm"
                            elseif UnitName == "corcom" then
                                ReinforcementsFaction[teamID] = "core"
                            end
                        end
                        local posradius = 200
                        local posx = math_random(0,mapsizeX)
                        local posz = math_random(0,mapsizeZ)
                        local posy = Spring.GetGroundHeight(posx, posz)
                        
                        local canSpawnBeaconHereLos = posFriendlyCheckOnlyLos(posx, posy, posz, allyTeamID)
                        local canSpawnBeaconHereOcc = posOccupied(posx, posy, posz, posradius)
                        local canSpawnBeaconHerePos = posCheck(posx, posy, posz, posradius)
                        if canSpawnBeaconHereLos and canSpawnBeaconHereOcc and canSpawnBeaconHerePos then
                            if ReinforcementsFaction[teamID] == "arm" then
                                Spring.CreateUnit("scavengerdroppodfriendly", posx, posy, posz, math_random(0,3),teamID)
                                QueueSpawn("corcom", posx, posy, posz, math_random(0,3),teamID,n+180+math.random(0,30))
                                ScavSendMessage(playerName .."'s additional commander arrived.")
                            elseif ReinforcementsFaction[teamID] == "core" then
                                Spring.CreateUnit("scavengerdroppodfriendly", posx, posy, posz, math_random(0,3),teamID)
                                QueueSpawn("armcom", posx, posy, posz, math_random(0,3),teamID,n+180+math.random(0,30))
                                ScavSendMessage(playerName .."'s additional commander arrived.")
                            end
                            TryingToSpawnReinforcements[teamID] = false
                            ReinforcementsCountPerTeam[teamID] = ReinforcementsCountPerTeam[teamID] + 1
                        end
                    else
                        local posradius = 200
                        local posx = math_random(0,mapsizeX)
                        local posz = math_random(0,mapsizeZ)
                        local posy = Spring.GetGroundHeight(posx, posz)
                        local spawnTier = math_random(1,100)
                        local aircraftchance = math_random(0,unitSpawnerModuleConfig.aircraftchance)
                        local canSpawnBeaconHereLos = posFriendlyCheckOnlyLos(posx, posy, posz, allyTeamID)
                        local canSpawnBeaconHereOcc = posOccupied(posx, posy, posz, posradius)
                        local canSpawnBeaconHerePos = posCheck(posx, posy, posz, posradius)
                        if canSpawnBeaconHereLos and canSpawnBeaconHereOcc and canSpawnBeaconHerePos then
                            if aircraftchance == 0 then
                                if spawnTier <= 50 then
                                    groupunit = T1AirUnits[math_random(1,#T1AirUnits)]
                                    groupsize = math.floor((ReinforcementsCountPerTeam[teamID]*2)*unitSpawnerModuleConfig.airmultiplier)
                                elseif spawnTier <= 95 then
                                    groupunit = T2AirUnits[math_random(1,#T2AirUnits)]
                                    groupsize = math.floor((ReinforcementsCountPerTeam[teamID])*unitSpawnerModuleConfig.airmultiplier)
                                elseif spawnTier <= 99 then
                                    groupunit = T3AirUnits[math_random(1,#T3AirUnits)]
                                    groupsize = math.floor((ReinforcementsCountPerTeam[teamID]/4)*unitSpawnerModuleConfig.airmultiplier)
                                elseif spawnTier <= 100 then
                                    groupunit = T4AirUnits[math_random(1,#T4AirUnits)]
                                    groupsize = 1
                                end
                            elseif posy > -20 then
                                if spawnTier <= 50 then
                                    groupunit = T1LandUnits[math_random(1,#T1LandUnits)]
                                    groupsize = math.floor((ReinforcementsCountPerTeam[teamID]*4)*unitSpawnerModuleConfig.landmultiplier)
                                elseif spawnTier <= 95 then
                                    groupunit = T2LandUnits[math_random(1,#T2LandUnits)]
                                    groupsize = math.floor((ReinforcementsCountPerTeam[teamID]*2)*unitSpawnerModuleConfig.landmultiplier)
                                elseif spawnTier <= 99 then
                                    groupunit = T3LandUnits[math_random(1,#T3LandUnits)]
                                    groupsize = math.floor((ReinforcementsCountPerTeam[teamID]/4)*unitSpawnerModuleConfig.landmultiplier)
                                elseif spawnTier <= 100 then
                                    groupunit = T4LandUnits[math_random(1,#T4LandUnits)]
                                    groupsize = 1
                                end
                            elseif posy <= -20 then
                                if spawnTier <= 50 then
                                    groupunit = T1SeaUnits[math_random(1,#T1SeaUnits)]
                                    groupsize = math.floor((ReinforcementsCountPerTeam[teamID]*2)*unitSpawnerModuleConfig.seamultiplier)
                                elseif spawnTier <= 95 then
                                    groupunit = T2SeaUnits[math_random(1,#T2SeaUnits)]
                                    groupsize = math.floor((ReinforcementsCountPerTeam[teamID])*unitSpawnerModuleConfig.seamultiplier)
                                elseif spawnTier <= 99 then
                                    groupunit = T3SeaUnits[math_random(1,#T3SeaUnits)]
                                    groupsize = math.floor((ReinforcementsCountPerTeam[teamID]/4)*unitSpawnerModuleConfig.seamultiplier)
                                elseif spawnTier <= 100 then
                                    groupunit = T4SeaUnits[math_random(1,#T4SeaUnits)]
                                    groupsize = 1
                                end
                            end
                            if groupsize == 1 then
                                ScavSendMessage(playerName .."'s reinforcements detected. Unit: ".. UDN[groupunit].humanName .. ".")
                            else
                                ScavSendMessage(playerName .."'s reinforcements detected. Units: ".. groupsize .." ".. UDN[groupunit].humanName .."s.")
                            end
                            for i = 1,groupsize do
                                local posx = posx+(math_random(-posradius,posradius))
                                local posz = posz+(math_random(-posradius,posradius))
                                local posy = Spring.GetGroundHeight(posx, posz)
                                
                                QueueSpawn(groupunit, posx, posy, posz, math_random(0,3),teamID, n+180+math.random(0,30))
                                Spring.CreateUnit("scavengerdroppodfriendly", posx, posy, posz, math_random(0,3),teamID)
                            end
                            TryingToSpawnReinforcements[teamID] = false
                            ReinforcementsCountPerTeam[teamID] = ReinforcementsCountPerTeam[teamID] + 1
                        end
                    end
                else
                    local r = math_random(0,ReinforcementsChancePerTeam[teamID])
                    if r == 0 or ReinforcementsCountPerTeam[teamID] == 0 then
                        TryingToSpawnReinforcements[teamID] = true
                        ReinforcementsChancePerTeam[teamID] = 300
                    else
                        TryingToSpawnReinforcements[teamID] = false
                        ReinforcementsChancePerTeam[teamID] = ReinforcementsChancePerTeam[teamID] - 1
                    end

                end
            
            end
        
        end
    
    end

end