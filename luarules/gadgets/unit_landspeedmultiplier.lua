local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = "Land Speed Multiplier",
        desc      = "Speeds up or slows down units on land compared to their default water speed.",
        author    = "ZephyrSkies, with a lot of help from [BONELESS]/qscrew/efrec",
        date      = "2025-09-14",
        license   = "GNU GPL, v2 or later",
        layer     = 0,
        enabled   = true
    }
end

-- units need to have the following customparam set for this to work properly:
-- landspeedfactor (number, e.g. 0.5 = half speed on land, 1 = no change, 2 = double speed)

if not gadgetHandler:IsSyncedCode() then return false end


local unitDefData = {}   -- unitDefID -> {factor, speed, turn, acc, dec}
local unitBaseStats = {} -- unitID -> reference to unitDefData[unitDefID]

-- local unitDefsWithFactor = {}  -- unitDefID -> factor
-- local unitDefMoveData = {}     -- unitDefID -> {speed, turnRate, accRate, decRate}
-- local unitBaseStats = {}       -- unitID -> reference to unitDefMoveData

local SMC = Spring.MoveCtrl


for defID, ud in pairs(UnitDefs) do
    local cp = ud.customParams
    if cp.landspeedfactor then
        unitDefData[defID] = {
            factor = tonumber(cp.landspeedfactor),
            speed  = ud.speed,
            turn   = ud.turnRate,
            acc    = ud.maxAcc,
            dec    = ud.maxDec,
        }
    end
end



---------------------------------------------------------------------------------------------
-- Helper Function --------------------------------------------------------------------------

-- applies a mutiplicative factor to a unit's base movement stats: speed, wanted speed, turn rate, accel, decel
-- The base stats come from UnitDefs and are scaled proportionally
local function ApplySpeed(unitID, stats, factor)
    -- speed scales directly
    -- turn rate scales at half effectiveness
    -- accel/decel scale at 0.75 effectiveness
    local speedFactor = factor
    local turnFactor = 0.5 * factor + 0.5
    local accelFactor = 0.25 + 0.75 * factor
    local decelFactor = 0.25 + 0.75 * factor

    Spring.MoveCtrl.SetGroundMoveTypeData(unitID, {
        maxWantedSpeed = stats.speed * speedFactor,
        turnRate       = stats.turn  * turnFactor,
        accRate        = stats.acc   * accelFactor,
        decRate        = stats.dec   * decelFactor,
    })

    -- TODO: unify with GG.ForceUpdateWantedMaxSpeed / unit_wanted_speed.lua
    -- This gadget should eventually integrate with a system that can compose
    -- multiple wanted speeds, constraints, and coefficients, as per efrec/BONELESS/qscrew
    -- Current implementation is local only.
end

---------------------------------------------------------------------------------------------
-- Engine Callins ---------------------------------------------------------------------------

function gadget:UnitCreated(unitID, unitDefID, teamID)
    local data = unitDefData[unitDefID]
    if data then
        --reuse cached move data
        unitBaseStats[unitID] = data

        local x, y, z = Spring.GetUnitPosition(unitID)
        local isInWater = Spring.GetGroundHeight(x, z) < Spring.GetWaterPlaneLevel()

        -- if in water default speed, if on land factored speed and stats
        if isInWater then
            ApplySpeed(unitID, data, 1)
        else
            ApplySpeed(unitID, data, data.factor)
        end
    end
end

function gadget:UnitEnteredWater(unitID, unitDefID, teamID)
    local stats = unitBaseStats[unitID]
    if stats then
        ApplySpeed(unitID, stats, 1)
    end
end


function gadget:UnitLeftWater(unitID, unitDefID, teamID)
    local stats = unitBaseStats[unitID]
    if stats then
        ApplySpeed(unitID, stats, stats.factor)
    end
end

function gadget:UnitDestroyed(unitID, unitDefID, teamID)
    unitBaseStats[unitID] = nil
end

