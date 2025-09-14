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

if gadgetHandler:IsSyncedCode() then

    ---------------------------------------------------------------------------------------------
    -- Setup and Data Storage -------------------------------------------------------------------

    local unitDefsWithFactor = {}  -- unitDefID -> factor
    local unitBaseStats = {}       -- unitID -> {speed, turnRate, accRate, decRate}
    local SMC = Spring.MoveCtrl

    ---------------------------------------------------------------------------------------------
    -- store which units are affected -----------------------------------------------------------

    -- this runs once when the gadget is loaded, checks units which have landspeedfactor, only runs once and only these units are then affected
    for defID, ud in pairs(UnitDefs) do
        local cp = ud.customParams or {}
        if cp.landspeedfactor then
            local factor = tonumber(cp.landspeedfactor)
            if factor then
                unitDefsWithFactor[defID] = factor
            end
        end
    end

    ---------------------------------------------------------------------------------------------
    -- Helper Function --------------------------------------------------------------------------

    -- uses maxSpeed and wantedMaxSpeed to make adjustments, grabs other variables too now
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

    -- store the base movement values
    function gadget:UnitCreated(unitID, unitDefID, teamID)
        local factor = unitDefsWithFactor[unitDefID]
        if factor then
            local ud = UnitDefs[unitDefID]
            unitBaseStats[unitID] = {
                speed = ud.speed,
                turn  = ud.turnRate,
                acc   = ud.maxAcc,
                dec   = ud.maxDec,
            }
            -- Default to water speed when first created (safe assumption).
            ApplySpeed(unitID, unitBaseStats[unitID], 1)
        end
    end

    -- allows units to go at full speed in water
    function gadget:UnitEnteredWater(unitID, unitDefID, teamID)
        local stats = unitBaseStats[unitID]
        if stats then
            ApplySpeed(unitID, stats, 1)
        end
    end

    -- slows unit down on land
    function gadget:UnitLeftWater(unitID, unitDefID, teamID)
        local stats = unitBaseStats[unitID]
        local factor = unitDefsWithFactor[unitDefID]
        if stats and factor then
            ApplySpeed(unitID, stats, factor)
        end
    end

    -- clear stored values in case unitID is used again
    function gadget:UnitDestroyed(unitID, unitDefID, teamID)
        unitBaseStats[unitID] = nil
    end

end
