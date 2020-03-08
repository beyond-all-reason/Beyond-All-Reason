VFS.Include('luarules/gadgets/scavengers/Configs/'..GameShortName..'/UnitLists/reinforcements.lua')
local ReinforcementsCountPerTeam = {}
local TryingToSpawnReinforcements = {}
local ReinforcementsFaction = {}

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
        if (not LuaAI) and teamID ~= GaiaTeamID and teamID ~= Spring.GetGaiaTeamID() then
            
            local _,_,isDead,_,_,allyTeamID = Spring.GetTeamInfo(teamID)
            
            if not ReinforcementsCountPerTeam[teamID] or ReinforcementsCountPerTeam[teamID] == 0 then
                ReinforcementsCountPerTeam[teamID] = 1
            end

            if not isDead then
                if TryingToSpawnReinforcements[teamID] == true then
                    if GameShortName == "BYAR" and ReinforcementsCountPerTeam[teamID] == 1 then
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
                                Spring.CreateUnit("corcom", posx, posy, posz, math_random(0,3),teamID)
                            elseif ReinforcementsFaction[teamID] == "core" then
                                Spring.CreateUnit("scavengerdroppodfriendly", posx, posy, posz, math_random(0,3),teamID)
                                Spring.CreateUnit("armcom", posx, posy, posz, math_random(0,3),teamID)
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
                                if spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 then
                                    groupunit = T2AirUnits[math_random(1,#T2AirUnits)]
                                    groupsize = ReinforcementsCountPerTeam[teamID]*unitSpawnerModuleConfig.airmultiplier
                                elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 then
                                    groupunit = T3AirUnits[math_random(1,#T3AirUnits)]
                                    groupsize = math.floor((ReinforcementsCountPerTeam[teamID]/4)*unitSpawnerModuleConfig.airmultiplier)
                                elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 + TierSpawnChances.T4 then
                                    groupunit = T4AirUnits[math_random(1,#T4AirUnits)]
                                    groupsize = 1
                                end
                            elseif posy > -20 then
                                if spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 then
                                    groupunit = T2LandUnits[math_random(1,#T2LandUnits)]
                                    groupsize = ReinforcementsCountPerTeam[teamID]*unitSpawnerModuleConfig.landmultiplier
                                elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 then
                                    groupunit = T3LandUnits[math_random(1,#T3LandUnits)]
                                    groupsize = math.floor((ReinforcementsCountPerTeam[teamID]/4)*unitSpawnerModuleConfig.landmultiplier)
                                elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 + TierSpawnChances.T4 then
                                    groupunit = T4LandUnits[math_random(1,#T4LandUnits)]
                                    groupsize = 1
                                end
                            elseif posy <= -20 then
                                if spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 then
                                    groupunit = T2SeaUnits[math_random(1,#T2SeaUnits)]
                                    groupsize = ReinforcementsCountPerTeam[teamID]*unitSpawnerModuleConfig.seamultiplier
                                elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 then
                                    groupunit = T3SeaUnits[math_random(1,#T3SeaUnits)]
                                    groupsize = math.floor((ReinforcementsCountPerTeam[teamID]/4)*unitSpawnerModuleConfig.seamultiplier)
                                elseif spawnTier <= TierSpawnChances.T0 + TierSpawnChances.T1 + TierSpawnChances.T2 + TierSpawnChances.T3 + TierSpawnChances.T4 then
                                    groupunit = T4SeaUnits[math_random(1,#T4SeaUnits)]
                                    groupsize = 1
                                end
                            end
                            for i = 1,groupsize do
                                local posx = posx+(math_random(-posradius,posradius))
                                local posz = posz+(math_random(-posradius,posradius))
                                local posy = Spring.GetGroundHeight(posx, posz)
                                Spring.CreateUnit(groupunit, posx, posy, posz, math_random(0,3),teamID)
                                Spring.CreateUnit("scavengerdroppodfriendly", posx, posy, posz, math_random(0,3),teamID)
                            end
                            TryingToSpawnReinforcements[teamID] = false
                            ReinforcementsCountPerTeam[teamID] = ReinforcementsCountPerTeam[teamID] + 1
                        end
                    end






                else
                    local r = math_random(0,30*ReinforcementsCountPerTeam[teamID])
                    --Spring.Echo(r)
                    if r == 0 then
                        TryingToSpawnReinforcements[teamID] = true
                        --Spring.Echo("true")
                    else
                        TryingToSpawnReinforcements[teamID] = false
                        --Spring.Echo("false")
                    end

                end
            
            end
        
        end
    
    end

end