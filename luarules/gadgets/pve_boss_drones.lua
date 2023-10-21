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

local unitList = {
    [UnitDefNames["raptor_hive"].id] = {
        [1] = {
            name = "raptor1_mini",
            type = "ground",
            spawnRadius = 1,
            fightRadius = 300,
            spawnedPerWave = 1,
            maxAllowed = 10,
            spawnTimer = 120,
        },
    },
    [UnitDefNames["ve_raptorq"].id] = {
        [1] = {
            name = "raptorw1_mini",
            type = "air",
            spawnRadius = 100,
            fightRadius = 1000,
            spawnedPerWave = 2,
            maxAllowed = 4,
            spawnTimer = 30,
        },
        [2] = {
            name = "raptorf1_mini",
            type = "air",
            spawnRadius = 100,
            fightRadius = 1000,
            spawnedPerWave = 2,
            maxAllowed = 4,
            spawnTimer = 31,
        },
    },
    [UnitDefNames["e_raptorq"].id] = {
        [1] = {
            name = "raptorw1_mini",
            type = "air",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 3,
            maxAllowed = 6,
            spawnTimer = 25,
        },
        [2] = {
            name = "raptorf1_mini",
            type = "air",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 3,
            maxAllowed = 6,
            spawnTimer = 26,
        },
    },
    [UnitDefNames["n_raptorq"].id] = {
        [1] = {
            name = "raptorw1_mini",
            type = "air",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 4,
            maxAllowed = 8,
            spawnTimer = 20,
        },
        [2] = {
            name = "raptorf1_mini",
            type = "air",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 4,
            maxAllowed = 8,
            spawnTimer = 21,
        },
    },
    [UnitDefNames["h_raptorq"].id] = {
        [1] = {
            name = "raptorw1",
            type = "air",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 5,
            maxAllowed = 10,
            spawnTimer = 15,
        },
        [2] = {
            name = "raptorf1",
            type = "air",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 5,
            maxAllowed = 10,
            spawnTimer = 16,
        },
        [4] = {
            name = "raptor_dodoair",
            type = "air",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 5,
            maxAllowed = 10,
            spawnTimer = 180,
        },
    },
    [UnitDefNames["vh_raptorq"].id] = {
        [1] = {
            name = "raptorw1",
            type = "air",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 6,
            maxAllowed = 12,
            spawnTimer = 10,
        },
        [2] = {
            name = "raptorf1",
            type = "air",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 6,
            maxAllowed = 12,
            spawnTimer = 11,
        },
        [3] = {
            name = "raptor_dodoair",
            type = "air",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 6,
            maxAllowed = 12,
            spawnTimer = 120,
        },
    },
    [UnitDefNames["epic_raptorq"].id] = {
        [1] = {
            name = "raptorw2",
            type = "air",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 7,
            maxAllowed = 14,
            spawnTimer = 5,
        },
        [2] = {
            name = "raptorf1apex",
            type = "air",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 7,
            maxAllowed = 14,
            spawnTimer = 6,
        },
        [3] = {
            name = "raptor_dodoair",
            type = "air",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 7,
            maxAllowed = 14,
            spawnTimer = 60,
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
                        local spawny = y + 200
                        local spawnz = z + math.random(-unitList[unitDefID][index].spawnRadius, unitList[unitDefID][index].spawnRadius)
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
                            --Spring.GiveOrderToUnit(droneID, CMD.MOVE_STATE, 2, 0)
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
