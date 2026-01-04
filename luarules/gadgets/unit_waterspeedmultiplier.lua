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
local watchUpdateRate = 0.5000 ---@type number in seconds | slow watch interval for variable-speed units

-- Globals

local math_clamp = math.clamp

local spGetUnitIsDead = Spring.GetUnitIsDead
local spGetUnitPosition = Spring.GetUnitPosition
local spGetGroundHeight = Spring.GetGroundHeight
local spGetMoveTypeData = Spring.GetUnitMoveTypeData
local spSetGroundMoveTypeData = Spring.MoveCtrl.SetGroundMoveTypeData

-- Setup

local unitDefData = {}

local function canHaveGroundMoveType(unitDef)
	-- I think you are not supposed to be able to set a moveDef on air or immobile units,
	-- but I think you can MoveCtrl.Enable, then MoveCtrl.SetMoveDef, to get around this.
	return true -- so, lol
end

for defID, ud in pairs(UnitDefs) do
    local params = ud.customParams

	local speedFactorInWater = tonumber(params.speedfactorinwater or 1) or 1
	local speedFactorAtDepth = math.abs(params.speedfactoratdepth and tonumber(params.speedfactoratdepth) or 0) * -1

	if speedFactorInWater ~= 1 and canHaveGroundMoveType(ud) then
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

local fake = {} -- just in case tbh

local function canSetSpeed(unitID)
	return spGetUnitIsDead(unitID) == false and (spGetMoveTypeData(unitID) or fake).name == "ground"
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
	local canSetSpeed, getDepth, setMoveData = canSetSpeed, getUnitDepth, setMoveTypeData -- micro speedup

	for unitID, unitData in pairs(unitDepthFastUpdate) do
		if canSetSpeed(unitID) then
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

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
    local unitData = unitDefData[unitDefID]
    if unitData and getUnitDepth(unitID) <= 0 then
		if canSetSpeed(unitID) then
			applySpeed(unitID, unitData)
		end
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
		if canSetSpeed(unitID) then
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
		if canSetSpeed(unitID) then
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

	local unitFinished = gadget.UnitFinished
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		unitFinished(gadget, unitID, Spring.GetUnitDefID(unitID), 0)
	end
end
