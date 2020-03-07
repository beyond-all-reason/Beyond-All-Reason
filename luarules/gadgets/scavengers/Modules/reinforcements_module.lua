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
        
        if teamID ~= GaiaTeamID and teamID ~= Spring.GetGaiaTeamID() then
            
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
                        
                        local canSpawnBeaconHereLos = posFriendlyCheckOnlyLos(posx, posy, posz, posradius, allyTeamID)
                        local canSpawnBeaconHereOcc = posOccupied(posx, posy, posz, posradius)
                        if canSpawnBeaconHereLos and canSpawnBeaconHereOcc then
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
                        
                        local canSpawnBeaconHereLos = posFriendlyCheckOnlyLos(posx, posy, posz, posradius, allyTeamID)
                        local canSpawnBeaconHereOcc = posOccupied(posx, posy, posz, posradius)
                        if canSpawnBeaconHereLos and canSpawnBeaconHereOcc then
                            -- nothing to see here yet
                            -- this is where we spawn reinforcements
                            TryingToSpawnReinforcements[teamID] = false
                            ReinforcementsCountPerTeam[teamID] = ReinforcementsCountPerTeam[teamID] + 1
                        end
                    end






                else
                    local r = math_random(0,120*ReinforcementsCountPerTeam[teamID])
                    if r == 0 then
                        TryingToSpawnReinforcements[teamID] = true
                    else
                        TryingToSpawnReinforcements[teamID] = false
                    end
                end
            
            end
        
        end
    
    end

end