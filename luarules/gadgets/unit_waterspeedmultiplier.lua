local gadget = gadget ---@type Gadget

local enabled = true
do
    local success, mapinfo = pcall(VFS.Include, "mapinfo.lua")
    if success and mapinfo and mapinfo.voidwater then
        enabled = false
    end
end

function gadget:GetInfo()
    return {
        name      = "Water Speed Multiplier",
        desc      = "Speeds up or slows down units on water compared to their default land speed.",
        author    = "ZephyrSkies",
        date      = "2025-09-14",
        license   = "GNU GPL, v2 or later",
        layer     = 0,
        enabled   = enabled,
    }
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

-- Configuration

local depthUpdateRate = 0.2500 ---@type number in seconds | for units with speeds variable by water depth
local watchUpdateRate = 0.7500 ---@type number in seconds | slow watch interval for variable-speed units

-- Globals

local math_clamp = math.clamp

local spGetUnitPosition = Spring.GetUnitPosition
local spGetGroundHeight = Spring.GetGroundHeight
local spSetGroundMoveTypeData = Spring.MoveCtrl.SetGroundMoveTypeData
local spMoveCtrlEnabled = Spring.MoveCtrl.IsEnabled

-- Setup

local unitDefData = {}

for defID, ud in pairs(UnitDefs) do
    local cp = ud.customParams
    if tonumber(cp.speedfactorinwater) and tonumber(cp.speedfactorinwater) ~= 1 and (not ud.canFly and not ud.isAirUnit) then
		local speedFactorInWater = tonumber(cp.speedfactorinwater)
		local speedFactorAtDepth = math.abs(cp.speedfactoratdepth and tonumber(cp.speedfactoratdepth) or 0) * -1

		if speedFactorAtDepth > -1 then
			speedFactorAtDepth = 0
		end

		unitDefData[defID] = {
            speedFactorInWater = speedFactorInWater,
			speedFactorAtDepth = speedFactorAtDepth,

            speed  = ud.speed,
            turn   = ud.turnRate,
            acc    = ud.maxAcc,
            dec    = ud.maxDec,
        }
    end
end

local unitDepthSlowUpdate = {}
local unitDepthFastUpdate = {}
local slowUpdateFrames = math.round(watchUpdateRate * Game.gameSpeed)
local fastUpdateFrames = math.round(depthUpdateRate * Game.gameSpeed)

---@type GroundMoveType
local moveTypeData = {
	maxSpeed       = 0,
	maxWantedSpeed = 0,
	turnRate       = 0,
	accRate        = 0,
	decRate        = 0,
}

-- Local functions

-- applies a mutiplicative factor to a unit's base movement stats: speed, wanted speed, turn rate, accel, decel
-- The base stats come from UnitDefs and are scaled proportionally
--
-- TODO: unify with GG.ForceUpdateWantedMaxSpeed / unit_wanted_speed.lua
-- This gadget should eventually integrate with a system that can compose
-- multiple wanted speeds, constraints, and coefficients, as per efrec/BONELESS/qscrew
-- Current implementation is local only.
local function setMoveTypeData(unitID, unitData, factor)
	local data = moveTypeData

	--these factor effectiveness values for the given unit stats were chosen arbitrarily for the best mechanical feel and balance, 
    --as well as to avoid strange jerky visuals
	local speed = unitData.speed * factor

	data.maxSpeed       = speed
	data.maxWantedSpeed = speed
	data.turnRate       = unitData.turn * (factor * 0.50 + 0.50)
	data.accRate        = unitData.acc  * (factor * 0.75 + 0.25)
	data.decRate        = unitData.dec  * (factor * 0.75 + 0.25)

	spSetGroundMoveTypeData(unitID, data)
end

local function getUnitDepth(unitID)
	local x, y, z = spGetUnitPosition(unitID)
	return x and spGetGroundHeight(x, z) or 0
end

local function applySpeed(unitID, unitData, factor)
	if not factor then
		factor = unitData.speedFactorInWater
		local depthMax = unitData.speedFactorAtDepth
		if depthMax < 0 then
			factor = 1 + (factor - 1) * math_clamp(getUnitDepth(unitID) / depthMax, 0, 1)
		end
	end
	setMoveTypeData(unitID, unitData, factor)
end

local function slowUpdate()
	local getDepth = getUnitDepth -- micro speedup

	for unitID, unitData in pairs(unitDepthSlowUpdate) do
		if getDepth(unitID) > unitData.speedFactorAtDepth - 15 then
			unitDepthFastUpdate[unitID] = unitData
			unitDepthSlowUpdate[unitID] = nil
		end
	end
end

local function fastUpdate()
	local getDepth, inMoveCtrl, setMoveData = getUnitDepth, spMoveCtrlEnabled, setMoveTypeData -- micro speedup

	for unitID, unitData in pairs(unitDepthFastUpdate) do
		if not inMoveCtrl(unitID) then
			local depth, depthMax = getDepth(unitID), unitData.speedFactorAtDepth
			if depth >= depthMax - 15 then
				setMoveData(unitID, unitData, 1 + (unitData.speedFactorInWater - 1) * math_clamp(depth / depthMax, 0, 1))
			else
				unitDepthSlowUpdate[unitID] = unitData
				unitDepthFastUpdate[unitID] = nil
			end
		else
			unitDepthSlowUpdate[unitID] = unitData
			unitDepthFastUpdate[unitID] = nil
		end
	end
end

-- Engine callins

function gadget:GameFrame(frame)
	if frame % slowUpdateFrames == 0 then
		slowUpdate()
	end
	if frame % fastUpdateFrames == 0 then
		fastUpdate()
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
    local unitData = unitDefData[unitDefID]
    if unitData and getUnitDepth(unitID) <= 0 then
		-- if not spMoveCtrlEnabled(unitID) then
			applySpeed(unitID, unitData)
		-- end
		if unitData.speedFactorAtDepth ~= 0 then
			unitDepthFastUpdate[unitID] = unitData
		end
    end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	unitDepthSlowUpdate[unitID] = nil
	unitDepthFastUpdate[unitID] = nil
end

function gadget:UnitEnteredWater(unitID, unitDefID, unitTeam)
    local unitData = unitDefData[unitDefID]
    if unitData then
		if not spMoveCtrlEnabled(unitID) then
			applySpeed(unitID, unitData)
		end
		if unitData.speedFactorAtDepth ~= 0 then
			unitDepthFastUpdate[unitID] = unitData
		end
    end
end

function gadget:UnitLeftWater(unitID, unitDefID, unitTeam)
    local unitData = unitDefData[unitDefID]
    if unitData then
		if not spMoveCtrlEnabled(unitID) then
			applySpeed(unitID, unitData, 1)
		end
		unitDepthSlowUpdate[unitID] = nil
		unitDepthFastUpdate[unitID] = nil
    end
end

function gadget:Initialize()
    if not next(unitDefData) then
        gadgetHandler:RemoveGadget()
		return
    end

	local unitCreated = gadget.UnitCreated
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		unitCreated(gadget, unitID, Spring.GetUnitDefID(unitID), 0)
	end
end
