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
else
	Spring.Log(gadget:GetInfo().name, LOG.INFO, "Raptor Defense Spawner Deactivated!")
	return false
end

local aliveHealers = {}
local healersTable = {
    [UnitDefNames["raptorhealer1"].id] = {
        healingpower = UnitDefNames["raptorhealer1"].repairSpeed,
        healingrange = UnitDefNames["raptorhealer1"].buildDistance*2,
    },
    [UnitDefNames["raptorhealer2"].id] = {
        healingpower = UnitDefNames["raptorhealer2"].repairSpeed,
        healingrange = UnitDefNames["raptorhealer2"].buildDistance*2,
    },
    [UnitDefNames["raptorhealer3"].id] = {
        healingpower = UnitDefNames["raptorhealer3"].repairSpeed,
        healingrange = UnitDefNames["raptorhealer3"].buildDistance*2,
    },
    [UnitDefNames["raptorhealer4"].id] = {
        healingpower = UnitDefNames["raptorhealer4"].repairSpeed,
        healingrange = UnitDefNames["raptorhealer4"].buildDistance*2,
    },
    [UnitDefNames["raptor_miniqueen_healer"].id] = {
        healingpower = UnitDefNames["raptor_miniqueen_healer"].repairSpeed,
        healingrange = UnitDefNames["raptor_miniqueen_healer"].buildDistance*2,
    },
}

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
    if healersTable[unitDefID] then
        aliveHealers[unitID] = {
            healingpower = healersTable[unitDefID].healingpower,
            healingrange = healersTable[unitDefID].healingrange,
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
            if not aliveHealers[unitID] then
                local x,y,z = Spring.GetUnitPosition(unitID)
                local surroundingUnits = Spring.GetUnitsInSphere(x, y, z, statsTable.healingrange)
                for i = 1,#surroundingUnits do
                    local healedUnitID = surroundingUnits[i]
                    if Spring.AreTeamsAllied(Spring.GetUnitTeam(unitID), Spring.GetUnitTeam(healedUnitID)) == true then
                        local oldHP, maxHP = Spring.GetUnitHealth(healedUnitID)
                        if oldHP < maxHP then
                            local healedUnitDefID = Spring.GetUnitDefID(healedUnitID)
                            local healedUnitBuildTime = UnitDefs[healedUnitDefID].buildTime
                            local healValue = (maxHP/healedUnitBuildTime)*statsTable.healingpower
                            Spring.SetUnitHealth(healedUnitID, oldHP+healValue)
                            if math.random() <= 0.5 then
                                local x2, y2, z2 = Spring.GetUnitPosition(healedUnitID)
                                Spring.SpawnCEG("heal", x2, y2+10, z2, 0,1,0)
                            end
                        end
                    end
                end
            end
        end
    end
end