local gadget = gadget ---@type Gadget

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
local unitRadius = {}
local cloakedUnits = {}
local checkedUnits = {}

local maxBuildDist = 0


if gadgetHandler:IsSyncedCode() then
    local GetUnitAllyTeam = Spring.GetUnitAllyTeam
    local GetUnitWorkerTask = Spring.GetUnitWorkerTask
    local GiveOrderToUnit = Spring.GiveOrderToUnit
    local GetUnitCurrentCommand = Spring.GetUnitCurrentCommand
    local GetAllUnits = Spring.GetAllUnits
    local IsUnitInRadar = Spring.IsUnitInRadar
    local GetUnitPosition = Spring.GetUnitPosition
    local GetUnitsInCylinder = Spring.GetUnitsInCylinder
    local GetUnitDefID = Spring.GetUnitDefID
    local GetUnitIsCloaked = Spring.GetUnitIsCloaked

    function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams)
        if (#cmdParams == 1) and GetUnitIsCloaked(cmdParams[1]) and (GetUnitAllyTeam(unitID) ~= GetUnitAllyTeam(cmdParams[1])) and not IsUnitInRadar(cmdParams[1], GetUnitAllyTeam(unitID)) then
            return false
        end
        return true
    end

    function gadget:AllowUnitCloak(unitID) -- cancel reclaim commands
        -- accepts: CMD.RECLAIM
        if (cloakedUnits[unitID]) and (not checkedUnits[unitID]) then  -- only needs to be checked when the unit barely is cloaked
            checkedUnits[unitID] = true
            local x, y, z = GetUnitPosition(unitID)
            local units = GetUnitsInCylinder(x, z, maxBuildDist + unitRadius[GetUnitDefID(unitID)]) -- + unit radius since reclaim also works if only the edge of the unit is in range
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
        end
        return true
    end

    local function initUnit(unitID, unitDefID)
        if GetUnitIsCloaked(unitID) then
            cloakedUnits[unitID] = true
        end
        if canReclaim[unitDefID] then
            if canReclaim[unitDefID] > maxBuildDist then
                maxBuildDist = canReclaim[unitDefID]
            end
        end
    end

    function gadget:UnitCreated(unitID, unitDefID)
        initUnit(unitID, unitDefID)
    end

    function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD.RECLAIM)
        for unitDefID, unitDef in pairs(UnitDefs) do
            if unitDef.canReclaim then
                canReclaim[unitDefID] = unitDef.buildDistance or 0
            end
            if unitDef.canCloak then
                unitRadius[unitDefID] = unitDef.radius
            end
        end
        -- handle luarules reload
        local units = GetAllUnits()
        for _,unitID in ipairs(units) do
            local unitDefID = GetUnitDefID(unitID)
            initUnit(unitID, unitDefID)
        end
    end

    function gadget:UnitCloaked(unitID)
        cloakedUnits[unitID] = true
    end

    function gadget:UnitDecloaked(unitID)
        cloakedUnits[unitID] = nil
        checkedUnits[unitID] = nil
    end
end
