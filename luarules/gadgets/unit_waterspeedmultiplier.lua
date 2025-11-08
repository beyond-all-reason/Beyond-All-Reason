local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = "Water Speed Multiplier",
        desc      = "Speeds up or slows down units on water compared to their default land speed.",
        author    = "ZephyrSkies",
        date      = "2025-09-14",
        license   = "GNU GPL, v2 or later",
        layer     = 0,
        enabled   = true
    }
end

-- units need to have the following customparam set for this to work properly:
-- waterspeedfactor (number, e.g. 0.5 = half speed on water, 1 = no change, 2 = double speed)

if not gadgetHandler:IsSyncedCode() then return false end

local spSetGroundMoveTypeData = Spring.MoveCtrl.SetGroundMoveTypeData
local spMoveCtrlEnabled = Spring.MoveCtrl.IsEnabled

local unitDefData = {}   -- unitDefID -> {factor, speed, turn, acc, dec}

for defID, ud in pairs(UnitDefs) do
    local cp = ud.customParams
    if tonumber(cp.speedfactorwater) and tonumber(cp.speedfactorwater) ~= 1 and (not ud.canFly and not ud.isAirUnit) then
        unitDefData[defID] = {
            speedFactorInWater  = tonumber(cp.waterspeedfactor),
            speed  = ud.speed,
            turn   = ud.turnRate,
            acc    = ud.maxAcc,
            dec    = ud.maxDec,
        }
    end
end

-- water is void check
local waterIsVoid = false
do
    local success, mapinfo = pcall(VFS.Include, "mapinfo.lua")
    if success and mapinfo then
	    waterIsVoid = mapinfo.voidwater
    end
end

-- applies a mutiplicative factor to a unit's base movement stats: speed, wanted speed, turn rate, accel, decel
-- The base stats come from UnitDefs and are scaled proportionally
--
-- TODO: unify with GG.ForceUpdateWantedMaxSpeed / unit_wanted_speed.lua
-- This gadget should eventually integrate with a system that can compose
-- multiple wanted speeds, constraints, and coefficients, as per efrec/BONELESS/qscrew
-- Current implementation is local only.
local function applySpeed(unitID, stats, factor)

    if spMoveCtrlEnabled(unitID) then return end
    
    local speedFactor = factor
    local accelFactor = factor * 0.75 + 0.25
    local decelFactor = factor * 0.75 + 0.25
    local turnFactor  = factor * 0.5 + 0.5
    --these factor effectiveness values for the given unit stats were chosen arbitrarily for the best mechanical feel and balance, 
    --as well as to avoid strange jerky visuals

    spSetGroundMoveTypeData(unitID, {
		maxSpeed       = stats.speed * speedFactor,
        maxWantedSpeed = stats.speed * speedFactor,
        turnRate       = stats.turn  * turnFactor,
        accRate        = stats.acc   * accelFactor,
        decRate        = stats.dec   * decelFactor,
    })
end

function gadget:Initialize()
    if waterIsVoid or not next(unitDefData) then
        gadgetHandler:RemoveGadget()
    end
end

function gadget:UnitCreated(unitID, unitDefID, teamID)
    local data = unitDefData[unitDefID]
    if data then
        local x, y, z = Spring.GetUnitPosition(unitID)
        local isInWater = (not waterIsVoid) and (Spring.GetGroundHeight(x, z) < Spring.GetWaterPlaneLevel())

        if isInWater then
            applySpeed(unitID, data, data.speedFactorInWater )
        else
            applySpeed(unitID, data, 1)
        end
    end
end

function gadget:UnitEnteredWater(unitID, unitDefID, teamID)
    local data = unitDefData[unitDefID]
    if data then
        applySpeed(unitID, data, data.speedFactorInWater )
    end
end

function gadget:UnitLeftWater(unitID, unitDefID, teamID)
    local data = unitDefData[unitDefID]
    if data then
        applySpeed(unitID, data, 1)
    end
end