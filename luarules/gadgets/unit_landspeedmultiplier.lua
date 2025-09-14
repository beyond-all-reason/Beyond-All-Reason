local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = "Land Speed Multiplier",
        desc      = "Speeds up or slows down units based on whether they are on land or water. Takes water traversal speed as the supplied default maxSpeed, applies multiplier to desired land speed.",
        author    = "ZephyrSkies, with help from [BONELESS]/qscrew/efrec",
        date      = "2025-09-14",
        license   = "GNU GPL, v2 or later",
        layer     = 0,
        enabled   = true
    }
end

-- units need to have the following customparams set for this to work properly:
-- slowsonland (boolean)
-- landspeedfactor (double)

if not gadgetHandler:IsSyncedCode() then return false end

if gadgetHandler:IsSyncedCode() then

    ---------------------------------------------------------------------------------------------
    -- Array/Value Initialisation ---------------------------------------------------------------

        local unitDefsToSlow = {}
        local unitSpeeds = {}
        local unitFactors = {}
        local SMC = Spring.MoveCtrl

    ---------------------------------------------------------------------------------------------
    -- Applicable Units Selected ----------------------------------------------------------------

    -- handle which UnitDefs are affected early
    for defID, ud in pairs(UnitDefs) do
        local cp = ud.customParams or {}
        if cp.slowonland == "true" then
            local factor = tonumber(cp.landspeedfactor) or 0.5 -- setting default to half-speed slow or else things get freaky
            unitDefsToSlow[defID] = factor
        end
    end

    ---------------------------------------------------------------------------------------------
    -- Local Functions --------------------------------------------------------------------------

    -- stores the max possible speed and desired speed in two seperate spring variables, applies new speeds when commands are given and appropriate events happen related to water
    local function ApplySpeed(unitID, newSpeed)
        if not SMC.SetGroundMoveTypeData then return end
        SMC.SetGroundMoveTypeData(
            unitID, {maxSpeed = newSpeed, maxWantedSpeed = newSpeed}
        )
    end

    --  when unit's created, grabs the speed and multplier factor, and sets it to max speed. 
    --      Worth adjusting later to ensure that it doesn't accidentally set a unit to go off at max speed over land?
    function gadget:UnitCreated(unitID, unitDefID, teamID)
        local factor = unitDefsToSlow[unitDefID]
        if factor then
            local ud = UnitDefs[unitDefID]
            unitSpeeds[unitID] = ud.speed
            unitFactors[unitID] = factor
            ApplySpeed(unitID, ud.speed) -- start with full speed
        end
    end

    -- if it enters the water, goes full speed
    function gadget:UnitEnteredWater(unitID, unitDefID, teamID)
        if unitSpeeds[unitID] then
            ApplySpeed(unitID, unitSpeeds[unitID])
        end
    end

    -- if it exits water, goes the mupltiplied speed factor
    function gadget:UnitLeftWater(unitID, unitDefID, teamID)
        local base = unitSpeeds[unitID]
        local factor = unitFactors[unitID]
        if base and factor then
            ApplySpeed(unitID, base * factor)
        end
    end

    -- to ensure that the unit speed and factor values are properly discarded in case a unit is revived and the unitID is used again, can cause shenanigans otherwise
    function gadget:UnitDestroyed(unitID, unitDefID, teamID)
        unitSpeeds[unitID] = nil
        unitFactors[unitID] = nil
    end

end
