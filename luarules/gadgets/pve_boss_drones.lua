function gadget:GetInfo()
    return {
        name = "PvE Boss Drones",
        desc = "Spawns and controls drones/minions for PvE enemies",
        author = "Damgam",
        date = "2023",
        license = "GNU GPL, v2 or later",
        layer = 0,
        enabled = true
    }
end

if not gadgetHandler:IsSyncedCode() then
    return
end

local positionCheckLibrary = VFS.Include("luarules/utilities/damgam_lib/position_checks.lua")

local unitList = {
    -- Brood Raptors
    [UnitDefNames["raptorh2"].id] = {
        [1] = {
            name = "raptorh3",
            type = "ground",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 1,
            spawnTimer = 120,
        },
        [2] = {
            name = "raptorh4",
            type = "ground",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 4,
            maxAllowed = 4,
            spawnTimer = 60,
        },
    },
    [UnitDefNames["raptorh3"].id] = {
        [1] = {
            name = "raptorh4",
            type = "ground",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 2,
            maxAllowed = 2,
            spawnTimer = 120,
        },
    },

    -- Miniqueens
    [UnitDefNames["raptor_miniqueen_basic"].id] = {
        [1] = {
            name = "raptor1x",
            type = "ground",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 3,
            spawnTimer = 10,
        },
        [2] = {
            name = "raptor1y",
            type = "ground",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 3,
            spawnTimer = 10,
        },
        [3] = {
            name = "raptor1z",
            type = "ground",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 3,
            spawnTimer = 10,
        },
        [4] = {
            name = "raptor2",
            type = "ground",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 3,
            spawnTimer = 10,
        },
        [5] = {
            name = "raptor2b",
            type = "ground",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 3,
            spawnTimer = 10,
        },
    },
    [UnitDefNames["raptor_miniqueen_healer"].id] = {
        [1] = {
            name = "raptorhealer1",
            type = "ground",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 4,
            spawnTimer = 10,
        },
        [2] = {
            name = "raptorhealer2",
            type = "ground",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 3,
            spawnTimer = 10,
        },
        [3] = {
            name = "raptorhealer3",
            type = "ground",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 2,
            spawnTimer = 10,
        },
        [4] = {
            name = "raptorhealer4",
            type = "ground",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 1,
            spawnTimer = 10,
        },
    },
    [UnitDefNames["raptor_miniqueen_acid"].id] = {
        [1] = {
            name = "raptoracidswarmer",
            type = "ground",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 10,
            spawnTimer = 10,
        },
        [2] = {
            name = "raptoracidassault",
            type = "ground",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 2,
            spawnTimer = 10,
        },
        [3] = {
            name = "raptoracidarty",
            type = "ground",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 1,
            spawnTimer = 10,
        },
    },
    [UnitDefNames["raptor_miniqueen_electric"].id] = {
        [1] = {
            name = "raptore1",
            type = "ground",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 10,
            spawnTimer = 10,
        },
        [2] = {
            name = "raptore2",
            type = "ground",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 2,
            spawnTimer = 10,
        },
        [3] = {
            name = "raptorearty1",
            type = "ground",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 1,
            spawnTimer = 10,
        },
    },
    [UnitDefNames["raptor_miniqueen_fire"].id] = {
        [1] = {
            name = "raptorp1",
            type = "ground",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 10,
            spawnTimer = 10,
        },
        [2] = {
            name = "raptorp2",
            type = "ground",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 2,
            spawnTimer = 10,
        },
    },
    [UnitDefNames["raptor_miniqueen_spectre"].id] = {
        [1] = {
            name = "raptor1x_spectre",
            type = "ground",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 5,
            spawnTimer = 10,
        },
        [2] = {
            name = "raptora1_spectre",
            type = "ground",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 2,
            spawnTimer = 10,
        },
        [3] = {
            name = "raptors2_spectre",
            type = "ground",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 5,
            spawnTimer = 10,
        },
    },

    -- Queens
    [UnitDefNames["ve_raptorq"].id] = {
        [1] = {
            name = "raptorw1_mini",
            type = "air",
            spawnRadius = 500,
            fightRadius = 1000,
            spawnedPerWave = 1,
            maxAllowed = 8,
            spawnTimer = 1,
        },
        [2] = {
            name = "raptorf1_mini",
            type = "air",
            spawnRadius = 500,
            fightRadius = 1000,
            spawnedPerWave = 1,
            maxAllowed = 2,
            spawnTimer = 1,
        },
        [3] = {
            name = "raptorh2",
            type = "ground",
            spawnRadius = 500,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 1,
            spawnTimer = 10,
        },
        [4] = {
            name = "raptorhealer4",
            type = "ground",
            spawnRadius = 500,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 1,
            spawnTimer = 10,
        },
    },
    [UnitDefNames["e_raptorq"].id] = {
        [1] = {
            name = "raptorw1_mini",
            type = "air",
            spawnRadius = 500,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 12,
            spawnTimer = 1,
        },
        [2] = {
            name = "raptorf1_mini",
            type = "air",
            spawnRadius = 500,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 3,
            spawnTimer = 1,
        },
        [3] = {
            name = "raptorh2",
            type = "ground",
            spawnRadius = 500,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 2,
            spawnTimer = 10,
        },
        [4] = {
            name = "raptorhealer4",
            type = "ground",
            spawnRadius = 500,
            fightRadius = 500,
            spawnedPerWave = 2,
            maxAllowed = 2,
            spawnTimer = 10,
        },
    },
    [UnitDefNames["n_raptorq"].id] = {
        [1] = {
            name = "raptorw1_mini",
            type = "air",
            spawnRadius = 500,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 16,
            spawnTimer = 1,
        },
        [2] = {
            name = "raptorf1_mini",
            type = "air",
            spawnRadius = 500,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 4,
            spawnTimer = 1,
        },
        [3] = {
            name = "raptorh2",
            type = "ground",
            spawnRadius = 500,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 3,
            spawnTimer = 10,
        },
        [4] = {
            name = "raptorhealer4",
            type = "ground",
            spawnRadius = 500,
            fightRadius = 500,
            spawnedPerWave = 3,
            maxAllowed = 3,
            spawnTimer = 10,
        },
    },
    [UnitDefNames["h_raptorq"].id] = {
        [1] = {
            name = "raptorw1",
            type = "air",
            spawnRadius = 500,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 20,
            spawnTimer = 1,
        },
        [2] = {
            name = "raptorf1",
            type = "air",
            spawnRadius = 500,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 5,
            spawnTimer = 1,
        },
        [3] = {
            name = "raptor_dodoair",
            type = "air",
            spawnRadius = 500,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 10,
            spawnTimer = 1,
        },
        [4] = {
            name = "raptorh2",
            type = "ground",
            spawnRadius = 500,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 4,
            spawnTimer = 10,
        },
        [5] = {
            name = "raptorhealer4",
            type = "ground",
            spawnRadius = 500,
            fightRadius = 500,
            spawnedPerWave = 4,
            maxAllowed = 4,
            spawnTimer = 10,
        },
    },
    [UnitDefNames["vh_raptorq"].id] = {
        [1] = {
            name = "raptorw1",
            type = "air",
            spawnRadius = 500,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 24,
            spawnTimer = 1,
        },
        [2] = {
            name = "raptorf1",
            type = "air",
            spawnRadius = 500,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 6,
            spawnTimer = 1,
        },
        [3] = {
            name = "raptor_dodoair",
            type = "air",
            spawnRadius = 500,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 12,
            spawnTimer = 1,
        },
        [4] = {
            name = "raptorh2",
            type = "ground",
            spawnRadius = 500,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 5,
            spawnTimer = 10,
        },
        [5] = {
            name = "raptorhealer4",
            type = "ground",
            spawnRadius = 500,
            fightRadius = 500,
            spawnedPerWave = 5,
            maxAllowed = 5,
            spawnTimer = 10,
        },
    },
    [UnitDefNames["epic_raptorq"].id] = {
        [1] = {
            name = "raptorw2",
            type = "air",
            spawnRadius = 500,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 28,
            spawnTimer = 1,
        },
        [2] = {
            name = "raptorf1apex",
            type = "air",
            spawnRadius = 500,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 7,
            spawnTimer = 1,
        },
        [3] = {
            name = "raptor_dodoair",
            type = "air",
            spawnRadius = 500,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 14,
            spawnTimer = 1,
        },
        [4] = {
            name = "raptorh2",
            type = "ground",
            spawnRadius = 500,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 6,
            spawnTimer = 10,
        },
        [5] = {
            name = "raptorhealer4",
            type = "ground",
            spawnRadius = 500,
            fightRadius = 500,
            spawnedPerWave = 6,
            maxAllowed = 6,
            spawnTimer = 10,
        },
    },
}

local aliveCarriers = {}
local aliveDrones = {}
function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
    if unitList[unitDefID] then
        aliveCarriers[unitID] = {}
        for i = 1,#unitList[unitDefID] do
            aliveCarriers[unitID][i] = {
                aliveDrones = 0,
                lastSpawned = Spring.GetGameSeconds()
            }
        end
    end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
    if aliveCarriers[unitID] then
        aliveCarriers[unitID] = nil
        for droneID, stats in pairs(aliveDrones) do
            if stats.owner == unitID then
                aliveDrones[droneID].owner = nil
                aliveDrones[droneID].ownerDefID = nil
            end
        end
    end
    if aliveDrones[unitID] then
        if aliveCarriers[aliveDrones[unitID].owner] then
            aliveCarriers[aliveDrones[unitID].owner][aliveDrones[unitID].index].aliveDrones = aliveCarriers[aliveDrones[unitID].owner][aliveDrones[unitID].index].aliveDrones - 1
        end
        aliveDrones[unitID] = nil
    end
end

function gadget:GameFrame(frame)
    if frame%30 == 13 then
        for unitID, unitDroneStats in pairs(aliveCarriers) do
            local unitDefID = Spring.GetUnitDefID(unitID)
            for index, stats in pairs(unitDroneStats) do
                if stats.aliveDrones <= (unitList[unitDefID][index].maxAllowed - unitList[unitDefID][index].spawnedPerWave) and Spring.GetGameSeconds() >= stats.lastSpawned + unitList[unitDefID][index].spawnTimer then
                    for _ = 1,unitList[unitDefID][index].spawnedPerWave do
                        local x,y,z = Spring.GetUnitPosition(unitID)
                        local spawnx = x + math.random(-unitList[unitDefID][index].spawnRadius, unitList[unitDefID][index].spawnRadius)
                        local spawny = y
                        local spawnz = z + math.random(-unitList[unitDefID][index].spawnRadius, unitList[unitDefID][index].spawnRadius)
                        if (unitList[unitDefID][index].type == "air" and UnitDefNames[unitList[unitDefID][index].name].canFly) or
                        (unitList[unitDefID][index].type == "ground" and positionCheckLibrary.FlatAreaCheck(spawnx, spawny, spawnz, 64, 30, true)) or
                        (unitList[unitDefID][index].type == "land" and positionCheckLibrary.FlatAreaCheck(spawnx, spawny, spawnz, 64, 30, true) and Spring.GetGroundHeight(spawnx, spawnz) > 0) or
                        (unitList[unitDefID][index].type == "sea" and positionCheckLibrary.FlatAreaCheck(spawnx, spawny, spawnz, 64, 30, true) and Spring.GetGroundHeight(spawnx, spawnz) <= 0) then
                            local droneID = Spring.CreateUnit(unitList[unitDefID][index].name, spawnx, spawny, spawnz, math.random(0,3), Spring.GetUnitTeam(unitID))
                            if droneID then
                                aliveDrones[droneID] = {
                                    owner = unitID,
                                    ownerDefID = unitDefID,
                                    index = index,
                                    fightRadius = unitList[unitDefID][index].fightRadius,
                                }
                                aliveCarriers[unitID][index].aliveDrones = aliveCarriers[unitID][index].aliveDrones + 1
                                aliveCarriers[unitID][index].lastSpawned = Spring.GetGameSeconds()
                                Spring.GiveOrderToUnit(droneID,37382,{1},0)
                                --Spring.GiveOrderToUnit(droneID, CMD.MOVE_STATE, 2, 0)
                            end
                        end
                    end
                end
            end
        end
    end

    if frame%30 == 14 then
        for droneID, stats in pairs(aliveDrones) do
            if stats.owner then
                local x,y,z = Spring.GetUnitPosition(stats.owner)
                if math.random(0,4) == 0 then
                    Spring.GiveOrderToUnit(droneID, CMD.PATROL, {x+math.random(-stats.fightRadius, stats.fightRadius), y, z+math.random(-stats.fightRadius, stats.fightRadius)} , {"shift"})
                elseif math.random(0,6) == 0 then
                    Spring.GiveOrderToUnit(droneID, CMD.PATROL, {x+math.random(-stats.fightRadius, stats.fightRadius), y, z+math.random(-stats.fightRadius, stats.fightRadius)} , {})
                end
            else
                if math.random(0,10) == 0 then
                    Spring.GiveOrderToUnit(droneID, CMD.PATROL, {math.random(0, Game.mapSizeX), 0, math.random(0, Game.mapSizeZ)} , {"shift"})
                end
            end
        end
    end
end
