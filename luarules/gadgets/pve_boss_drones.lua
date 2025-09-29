if not (Spring.Utilities.Gametype.IsRaptors() or Spring.Utilities.Gametype.IsScavengers()) then
    Spring.Echo("REMOVED PVE BOSS DRONES")
	return false
end

local gadget = gadget ---@type Gadget

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

local pveTeamID = Spring.Utilities.GetScavTeamID() or Spring.Utilities.GetRaptorTeamID()

local positionCheckLibrary = VFS.Include("luarules/utilities/damgam_lib/position_checks.lua")

local unitListNames = {
    -- Brood Raptors
    ["raptor_land_swarmer_brood_t4_v1"] = {
        [1] = {
            name = "raptor_land_swarmer_brood_t3_v1",
            type = "ground",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 1,
            spawnTimer = 120,
        },
        [2] = {
            name = "raptor_land_swarmer_brood_t2_v1",
            type = "ground",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 4,
            maxAllowed = 4,
            spawnTimer = 60,
        },
    },
    ["raptor_land_swarmer_brood_t3_v1"] = {
        [1] = {
            name = "raptor_land_swarmer_brood_t2_v1",
            type = "ground",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 2,
            maxAllowed = 2,
            spawnTimer = 120,
        },
    },

    -- Miniqueens
    ["raptor_matriarch_basic"] = {
        [1] = {
            name = "raptor_land_swarmer_basic_t3_v1",
            type = "ground",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 3,
            spawnTimer = 10,
        },
        [2] = {
            name = "raptor_land_swarmer_basic_t3_v2",
            type = "ground",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 3,
            spawnTimer = 10,
        },
        [3] = {
            name = "raptor_land_swarmer_basic_t3_v3",
            type = "ground",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 3,
            spawnTimer = 10,
        },
        [4] = {
            name = "raptor_land_swarmer_basic_t4_v1",
            type = "ground",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 3,
            spawnTimer = 10,
        },
        [5] = {
            name = "raptor_land_swarmer_basic_t4_v2",
            type = "ground",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 3,
            spawnTimer = 10,
        },
    },
    ["raptor_matriarch_healer"] = {
        [1] = {
            name = "raptor_land_swarmer_heal_t1_v1",
            type = "ground",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 4,
            spawnTimer = 10,
        },
        [2] = {
            name = "raptor_land_swarmer_heal_t2_v1",
            type = "ground",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 3,
            spawnTimer = 10,
        },
        [3] = {
            name = "raptor_land_swarmer_heal_t3_v1",
            type = "ground",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 2,
            spawnTimer = 10,
        },
        [4] = {
            name = "raptor_land_swarmer_heal_t4_v1",
            type = "ground",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 1,
            spawnTimer = 10,
        },
    },
    ["raptor_matriarch_acid"] = {
        [1] = {
            name = "raptor_land_swarmer_acids_t2_v1",
            type = "ground",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 10,
            spawnTimer = 10,
        },
        [2] = {
            name = "raptor_land_assault_acid_t2_v1",
            type = "ground",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 2,
            spawnTimer = 10,
        },
        [3] = {
            name = "raptor_allterrain_arty_acid_t2_v1",
            type = "ground",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 1,
            spawnTimer = 10,
        },
    },
    ["raptor_matriarch_electric"] = {
        [1] = {
            name = "raptor_land_swarmer_emp_t2_v1",
            type = "ground",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 10,
            spawnTimer = 10,
        },
        [2] = {
            name = "raptor_land_assault_emp_t2_v1",
            type = "ground",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 2,
            spawnTimer = 10,
        },
        [3] = {
            name = "raptor_allterrain_arty_emp_t2_v1",
            type = "ground",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 1,
            spawnTimer = 10,
        },
    },
    ["raptor_matriarch_fire"] = {
        [1] = {
            name = "raptor_land_swarmer_fire_t2_v1",
            type = "ground",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 10,
            spawnTimer = 10,
        },
        [2] = {
            name = "raptor_land_swarmer_fire_t4_v1",
            type = "ground",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 2,
            spawnTimer = 10,
        },
    },
    ["raptor_matriarch_spectre"] = {
        [1] = {
            name = "raptor_land_swarmer_spectre_t3_v1",
            type = "ground",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 5,
            spawnTimer = 10,
        },
        [2] = {
            name = "raptor_land_assault_spectre_t2_v1",
            type = "ground",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 2,
            spawnTimer = 10,
        },
        [3] = {
            name = "raptor_land_spiker_spectre_t4_v1",
            type = "ground",
            spawnRadius = 100,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 5,
            spawnTimer = 10,
        },
    },

    -- Queens
    ["raptor_queen_veryeasy"] = {
        [1] = {
            name = "raptor_air_fighter_basic_t1_v1",
            type = "air",
            spawnRadius = 500,
            fightRadius = 1000,
            spawnedPerWave = 1,
            maxAllowed = 8,
            spawnTimer = 1,
        },
        [2] = {
            name = "raptor_air_bomber_basic_t1_v1",
            type = "air",
            spawnRadius = 500,
            fightRadius = 1000,
            spawnedPerWave = 1,
            maxAllowed = 2,
            spawnTimer = 1,
        },
        [3] = {
            name = "raptor_land_swarmer_brood_t4_v1",
            type = "ground",
            spawnRadius = 500,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 1,
            spawnTimer = 10,
        },
        [4] = {
            name = "raptor_land_swarmer_heal_t4_v1",
            type = "ground",
            spawnRadius = 500,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 1,
            spawnTimer = 10,
        },
    },
    ["raptor_queen_easy"] = {
        [1] = {
            name = "raptor_air_fighter_basic_t1_v1",
            type = "air",
            spawnRadius = 500,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 12,
            spawnTimer = 1,
        },
        [2] = {
            name = "raptor_air_bomber_basic_t1_v1",
            type = "air",
            spawnRadius = 500,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 3,
            spawnTimer = 1,
        },
        [3] = {
            name = "raptor_land_swarmer_brood_t4_v1",
            type = "ground",
            spawnRadius = 500,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 2,
            spawnTimer = 10,
        },
        [4] = {
            name = "raptor_land_swarmer_heal_t4_v1",
            type = "ground",
            spawnRadius = 500,
            fightRadius = 500,
            spawnedPerWave = 2,
            maxAllowed = 2,
            spawnTimer = 10,
        },
    },
    ["raptor_queen_normal"] = {
        [1] = {
            name = "raptor_air_fighter_basic_t1_v1",
            type = "air",
            spawnRadius = 500,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 16,
            spawnTimer = 1,
        },
        [2] = {
            name = "raptor_air_bomber_basic_t1_v1",
            type = "air",
            spawnRadius = 500,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 4,
            spawnTimer = 1,
        },
        [3] = {
            name = "raptor_land_swarmer_brood_t4_v1",
            type = "ground",
            spawnRadius = 500,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 3,
            spawnTimer = 10,
        },
        [4] = {
            name = "raptor_land_swarmer_heal_t4_v1",
            type = "ground",
            spawnRadius = 500,
            fightRadius = 500,
            spawnedPerWave = 3,
            maxAllowed = 3,
            spawnTimer = 10,
        },
    },
    ["raptor_queen_hard"] = {
        [1] = {
            name = "raptor_air_fighter_basic_t2_v1",
            type = "air",
            spawnRadius = 500,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 20,
            spawnTimer = 1,
        },
        [2] = {
            name = "raptor_air_bomber_basic_t2_v1",
            type = "air",
            spawnRadius = 500,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 5,
            spawnTimer = 1,
        },
        [3] = {
            name = "raptor_air_kamikaze_basic_t2_v1",
            type = "air",
            spawnRadius = 500,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 10,
            spawnTimer = 1,
        },
        [4] = {
            name = "raptor_land_swarmer_brood_t4_v1",
            type = "ground",
            spawnRadius = 500,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 4,
            spawnTimer = 10,
        },
        [5] = {
            name = "raptor_land_swarmer_heal_t4_v1",
            type = "ground",
            spawnRadius = 500,
            fightRadius = 500,
            spawnedPerWave = 4,
            maxAllowed = 4,
            spawnTimer = 10,
        },
    },
    ["raptor_queen_veryhard"] = {
        [1] = {
            name = "raptor_air_fighter_basic_t2_v1",
            type = "air",
            spawnRadius = 500,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 24,
            spawnTimer = 1,
        },
        [2] = {
            name = "raptor_air_bomber_basic_t2_v1",
            type = "air",
            spawnRadius = 500,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 6,
            spawnTimer = 1,
        },
        [3] = {
            name = "raptor_air_kamikaze_basic_t2_v1",
            type = "air",
            spawnRadius = 500,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 12,
            spawnTimer = 1,
        },
        [4] = {
            name = "raptor_land_swarmer_brood_t4_v1",
            type = "ground",
            spawnRadius = 500,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 5,
            spawnTimer = 10,
        },
        [5] = {
            name = "raptor_land_swarmer_heal_t4_v1",
            type = "ground",
            spawnRadius = 500,
            fightRadius = 500,
            spawnedPerWave = 5,
            maxAllowed = 5,
            spawnTimer = 10,
        },
    },
    ["raptor_queen_epic"] = {
        [1] = {
            name = "raptor_air_fighter_basic_t4_v1",
            type = "air",
            spawnRadius = 500,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 28,
            spawnTimer = 1,
        },
        [2] = {
            name = "raptor_air_bomber_basic_t4_v1",
            type = "air",
            spawnRadius = 500,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 7,
            spawnTimer = 1,
        },
        [3] = {
            name = "raptor_air_kamikaze_basic_t2_v1",
            type = "air",
            spawnRadius = 500,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 14,
            spawnTimer = 1,
        },
        [4] = {
            name = "raptor_land_swarmer_brood_t4_v1",
            type = "ground",
            spawnRadius = 500,
            fightRadius = 500,
            spawnedPerWave = 1,
            maxAllowed = 6,
            spawnTimer = 10,
        },
        [5] = {
            name = "raptor_land_swarmer_heal_t4_v1",
            type = "ground",
            spawnRadius = 500,
            fightRadius = 500,
            spawnedPerWave = 6,
            maxAllowed = 6,
            spawnTimer = 10,
        },
    },
}
-- convert unitname -> unitDefID
local unitList = {}
for name, params in pairs(unitListNames) do
	if UnitDefNames[name] then
		unitList[UnitDefNames[name].id] = params
	end
end
unitListNames = nil


local aliveCarriers = {}
local aliveDrones = {}
function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
    if unitList[unitDefID] and (unitTeam == pveTeamID) then
        aliveCarriers[unitID] = {}
        for i = 1,#unitList[unitDefID] do
            aliveCarriers[unitID][i] = {
                aliveDrones = 0,
                lastSpawned = Spring.GetGameSeconds()
            }
        end
    end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
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
