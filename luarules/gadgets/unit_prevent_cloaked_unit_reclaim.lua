function gadget:GetInfo()
    return {
        name      = "Prevent Cloaked Unit Reclaim",
        desc      = "Prevents builders from reclaiming cloaked units",
        author    = "hihoman23",
        date      = "Apr 2024",
        license   = "GNU GPL, v2 or later",
        layer     = 0,
        enabled   = true
    }
end

local canReclaim = {}

local maxBuildDist = 0


if gadgetHandler:IsSyncedCode() then
    local GetUnitAllyTeam = Spring.GetUnitAllyTeam
    local GetUnitIsCloaked = Spring.GetUnitIsCloaked
    local GetUnitWorkerTask = Spring.GetUnitWorkerTask
    local GiveOrderToUnit = Spring.GiveOrderToUnit
    local GetUnitCurrentCommand = Spring.GetUnitCurrentCommand
    local GetAllUnits = Spring.GetAllUnits
    local IsUnitInRadar = Spring.IsUnitInRadar
    local GetUnitPosition = Spring.GetUnitPosition
    local GetUnitsInCylinder = Spring.GetUnitsInCylinder
    local GetUnitDefID = Spring.GetUnitDefID
    

    function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams)
        if (cmdID == CMD.RECLAIM) and (#cmdParams == 1) and GetUnitIsCloaked(cmdParams[1]) and (GetUnitAllyTeam(unitID) ~= GetUnitAllyTeam(cmdParams[1])) and not IsUnitInRadar(cmdParams[1], GetUnitAllyTeam(unitID)) then
            return false
        end
        return true
    end
    
    function gadget:AllowUnitCloak(unitID) -- cancel reclaim commands
        local x, y, z = GetUnitPosition(unitID)
        local units = GetUnitsInCylinder(x, z, maxBuildDist)
        for _, bID in pairs(units) do
            local unitDefID = GetUnitDefID(bID)
            if canReclaim[unitDefID] then
                local cmd, target = GetUnitWorkerTask(bID)
                if cmd == CMD.RECLAIM and target == unitID and (GetUnitAllyTeam(bID) ~= GetUnitAllyTeam(unitID)) and not IsUnitInRadar(unitID, GetUnitAllyTeam(bID)) then
                    local _, _, cmdTag = GetUnitCurrentCommand(bID, 1)
                    GiveOrderToUnit(bID, CMD.REMOVE, {cmdTag}, {})
                end
            end
        end
        return true
    end

    local function initBuilder(unitID, unitDefID)
        if canReclaim[unitDefID] then
            if canReclaim[unitDefID] > maxBuildDist then
                maxBuildDist = canReclaim[unitDefID]
            end
        end
    end

    function gadget:UnitCreated(unitID, unitDefID)
        initBuilder(unitID, unitDefID)
    end

    function gadget:Initialize()
        for unitDefID, unitDef in pairs(UnitDefs) do
            if unitDef.canReclaim then
                canReclaim[unitDefID] = unitDef.buildDistance or 0
            end
        end
        -- handle luarules reload
        local units = GetAllUnits()
        for _,unitID in ipairs(units) do
            local unitDefID = GetUnitDefID(unitID)
            initBuilder(unitID, unitDefID)
        end
    end
end