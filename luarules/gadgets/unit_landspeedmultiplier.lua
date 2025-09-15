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

local unitDefsWithFactor = {}  -- unitDefID -> factor
local unitBaseStats = {}       -- unitID -> {speed, turnRate, accRate, decRate}

local unitDefsWithFactor = {}  -- unitDefID -> factor
local unitDefMoveData = {}     -- unitDefID -> {speed, turnRate, accRate, decRate}
local unitBaseStats = {}       -- unitID -> reference to unitDefMoveData

local SMC = Spring.MoveCtrl


for defID, ud in pairs(UnitDefs) do
    local cp = ud.customParams
    if cp.landspeedfactor then
        local factor = tonumber(cp.landspeedfactor)
        unitDefsWithFactor[defID] = factor

        -- cache base stats for this unitDefID only once
        unitDefMoveData[defID] = {
            speed = ud.speed,
            turn  = ud.turnRate,
            acc   = ud.maxAcc,
            dec   = ud.maxDec,
        }
    end
end



---------------------------------------------------------------------------------------------
-- Helper Function --------------------------------------------------------------------------

-- uses maxSpeed and wantedMaxSpeed to multiply a unit's base moveType data (speed, turn, acceleration) by a coefficient
local function ApplySpeed(unitID, stats, factor)
    SMC.SetGroundMoveTypeData(unitID, {
        maxSpeed       = stats.speed   * factor,
        maxWantedSpeed = stats.speed   * factor,
        turnRate       = stats.turn    * factor,
        accRate        = stats.acc     * factor,
        decRate        = stats.dec     * factor,
    })
end

---------------------------------------------------------------------------------------------
-- Engine Callins ---------------------------------------------------------------------------

function gadget:UnitCreated(unitID, unitDefID, teamID)
    local factor = unitDefsWithFactor[unitDefID]
    if factor then
        -- reuse cached move data
        unitBaseStats[unitID] = unitDefMoveData[unitDefID]

        local x, y, z = Spring.GetUnitPosition(unitID)
        local isInWater = Spring.GetGroundHeight(x, z) < Spring.GetWaterPlaneLevel()

        -- if in water, default speed, if on land, speed up or slow down immediately
        if isInWater then
            ApplySpeed(unitID, unitBaseStats[unitID], 1)
        else
            ApplySpeed(unitID, unitBaseStats[unitID], factor)
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
    local factor = unitDefsWithFactor[unitDefID]
    if stats and factor then
        ApplySpeed(unitID, stats, factor)
    end
end

function gadget:UnitDestroyed(unitID, unitDefID, teamID)
    unitBaseStats[unitID] = nil
end

