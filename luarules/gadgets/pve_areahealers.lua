function gadget:GetInfo()
    return {
        name = "Raptor Area Healers",
        desc = "Area Heal raptors around raptor healers - healers don't heal each other.",
        author = "Damgam",
        date = "2023",
        license = "GNU GPL, v2 or later",
        layer = 0,
        enabled = true -- we don't need it for now, but might need it later.
    }
end

if not gadgetHandler:IsSyncedCode() then
    return
end

if Spring.Utilities.Gametype.IsRaptors() then
	Spring.Log(gadget:GetInfo().name, LOG.INFO, "Raptor Defense Spawner Activated!")
elseif Spring.Utilities.Gametype.IsScavengers() then
    Spring.Log(gadget:GetInfo().name, LOG.INFO, "Scav Defense Spawner Activated!")
else
	Spring.Log(gadget:GetInfo().name, LOG.INFO, "Defense Spawner Deactivated!")
	return false
end

local aliveHealers = {}
local healersTable = {}
if Spring.Utilities.Gametype.IsRaptors() then
    local healersTableRaptors = {
        [UnitDefNames["raptor_land_swarmer_heal_t1_v1"].id] = {
            healingpower = UnitDefNames["raptor_land_swarmer_heal_t1_v1"].repairSpeed,
            healingrange = UnitDefNames["raptor_land_swarmer_heal_t1_v1"].buildDistance*2,
            canbehealed = false,
        },
        [UnitDefNames["raptor_land_swarmer_heal_t2_v1"].id] = {
            healingpower = UnitDefNames["raptor_land_swarmer_heal_t2_v1"].repairSpeed,
            healingrange = UnitDefNames["raptor_land_swarmer_heal_t2_v1"].buildDistance*2,
            canbehealed = false,
        },
        [UnitDefNames["raptor_land_swarmer_heal_t3_v1"].id] = {
            healingpower = UnitDefNames["raptor_land_swarmer_heal_t3_v1"].repairSpeed,
            healingrange = UnitDefNames["raptor_land_swarmer_heal_t3_v1"].buildDistance*2,
            canbehealed = false,
        },
        [UnitDefNames["raptor_land_swarmer_heal_t4_v1"].id] = {
            healingpower = UnitDefNames["raptor_land_swarmer_heal_t4_v1"].repairSpeed,
            healingrange = UnitDefNames["raptor_land_swarmer_heal_t4_v1"].buildDistance*2,
            canbehealed = false,
        },
        [UnitDefNames["raptor_matriarch_healer"].id] = {
            healingpower = UnitDefNames["raptor_matriarch_healer"].repairSpeed,
            healingrange = UnitDefNames["raptor_matriarch_healer"].buildDistance*2,
            canbehealed = false,
        },
    }
    table.append(healersTable, healersTableRaptors)
end

for unitDefID, unitDef in pairs(UnitDefs) do
    if unitDef.customParams.isscavenger and unitDef.canRepair and unitDef.repairSpeed and unitDef.buildDistance then
        healersTable[unitDefID] = {
            healingpower = unitDef.repairSpeed*0.1,
            healingrange = unitDef.buildDistance*2,
            canbehealed = true,
        }
    end
end


function gadget:UnitCreated(unitID, unitDefID, unitTeam)
    if healersTable[unitDefID] then
        aliveHealers[unitID] = {
            healingpower = healersTable[unitDefID].healingpower,
            healingrange = healersTable[unitDefID].healingrange,
            canbehealed = healersTable[unitDefID].canbehealed,
        }
    end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID)
    if aliveHealers[unitID] then
        aliveHealers[unitID] = nil
    end
end

function gadget:GameFrame(frame)
    for unitID, statsTable in pairs(aliveHealers) do
        if unitID%30 == frame%30 then
            local x,y,z = Spring.GetUnitPosition(unitID)
            local surroundingUnits = Spring.GetUnitsInSphere(x, y, z, statsTable.healingrange)
            for i = 1,#surroundingUnits do
                local healedUnitID = surroundingUnits[i]
                if (not aliveHealers[healedUnitID]) or (aliveHealers[healedUnitID].canbehealed and unitID ~= healedUnitID) then
                    if Spring.AreTeamsAllied(Spring.GetUnitTeam(unitID), Spring.GetUnitTeam(healedUnitID)) == true then
                        local oldHP, maxHP = Spring.GetUnitHealth(healedUnitID)
                        if oldHP < maxHP then
                            local x2, y2, z2 = Spring.GetUnitPosition(healedUnitID)
                            local surroundingUnits2 = Spring.GetUnitsInSphere(x2, y2, z2, math.ceil(statsTable.healingrange))
                            local enemiesNearby = false
                            for i = 1,#surroundingUnits2 do
                                if Spring.GetUnitTeam(surroundingUnits2[i]) ~= Spring.GetUnitTeam(unitID) and Spring.GetUnitTeam(surroundingUnits2[i]) ~= Spring.GetGaiaTeamID() then
                                    enemiesNearby = true
                                    break
                                end
                            end
                            if not enemiesNearby then
                                local healedUnitDefID = Spring.GetUnitDefID(healedUnitID)
                                local healedUnitBuildTime = UnitDefs[healedUnitDefID].buildTime
                                local healValue = (maxHP/healedUnitBuildTime)*statsTable.healingpower
                                Spring.SetUnitHealth(healedUnitID, oldHP+healValue)
                                Spring.SpawnCEG("heal", x2, y2+10, z2, 0,1,0)
                            end
                        end
                    end
                end
            end
        end
    end
end