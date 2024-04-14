function gadget:GetInfo()
    return {
        name      = "Prevent Cloaked Unit Reclaim",
        desc      = "Prevents builders from reclaiming cloaked units",
        author    = "hihoman23",
        date      = "Apr 2024",
        license   = "GNU GPL, v2 or later",
        layer     = 0,
        enabled   = true  --  loaded by default?
    }
end

local builders = {}
local toDo = {
}
local frame = -1


--[[if gadgetHandler:IsSyncedCode() then
    local GetUnitAllyTeam = Spring.GetUnitAllyTeam
    local GetUnitIsCloaked = Spring.GetUnitIsCloaked
    local GetUnitWorkerTask = Spring.GetUnitWorkerTask
    local GiveOrderToUnit = Spring.GiveOrderToUnit
    local GetUnitCurrentCommand = Spring.GetUnitCurrentCommand
    local GetAllUnits = Spring.GetAllUnits
    local GetUnitDefID = Spring.GetUnitDefID

    function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams)
        if (cmdID == CMD.RECLAIM) and (#cmdParams == 1) and GetUnitIsCloaked(cmdParams[1]) and (GetUnitAllyTeam(unitID) ~= GetUnitAllyTeam(cmdParams[1])) then
            return false
        end
        return true
    end

    function gadget:GameFrame(n)
        frame = n
        if not toDo[frame] then
            return
        end
        for k, doThis in ipairs(toDo[frame]) do
            doThis[1](doThis[2])
            toDo[frame][k] = nil
        end
    end
    
    function gadget:AllowUnitCloak(unitID) -- cancel reclaim commands
        for bID, _ in pairs(builders) do
            local cmd, target = GetUnitWorkerTask(bID)
            if cmd == CMD.RECLAIM and target == unitID and (GetUnitAllyTeam(bID) ~= GetUnitAllyTeam(unitID)) then
                local _, _, cmdTag = GetUnitCurrentCommand(bID, 1)
                GiveOrderToUnit(bID, CMD.REMOVE, {cmdTag}, {})
            end
        end
        return true
    end

    local function initBuilder(unitID, unitDefID)
        local def = UnitDefs[unitDefID]
        if def.isBuilder then
            builders[unitID] = true
        end
    end

    function gadget:UnitCreated(unitID, unitDefID)
        initBuilder(unitID, unitDefID)
    end

    function gadget:UnitDestroyed(unitID)
        builders[unitID] = nil
    end

    function gadget:Initialize()
        -- handle luarules reload
        local units = GetAllUnits()
        for _,unitID in ipairs(units) do
            local unitDefID = GetUnitDefID(unitID)
            initBuilder(unitID, unitDefID)
        end
    end
end]]