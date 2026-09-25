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
		name = "Water Speed Multiplier",
		desc = "Speeds up or slows down units on water compared to their default land speed.",
		author = "ZephyrSkies",
		date = "2025-09-14",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = enabled,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

-- Configuration

local depthUpdateRate = 0.2500 ---@type number # in seconds | for units with speeds variable by water depth
local watchUpdateRate = 0.5000 ---@type number # in seconds | slow watch interval for variable-speed units

-- Globals

local math_clamp = math.clamp

local spGetUnitPosition = Spring.GetUnitPosition
local spGetGroundHeight = Spring.GetGroundHeight

local ATTRIBUTE_SOURCE = "speedfactor_inwater"

-- Setup

local unitDefData = {}

local function hasSurfaceMoveType(unitDef)
	return not unitDef.isHoveringAirUnit and not unitDef.isAirUnit and not unitDef.isImmobile
end

for defID, ud in pairs(UnitDefs) do
	local params = ud.customParams

	local speedFactorInWater = tonumber(params.speedfactorinwater or 1) or 1
	local speedFactorAtDepth = math.abs(params.speedfactoratdepth and tonumber(params.speedfactoratdepth) or 0) * -1

	if speedFactorInWater ~= 1 and hasSurfaceMoveType(ud) then
		if speedFactorAtDepth > -1 then
			speedFactorAtDepth = 0
		end

		unitDefData[defID] = {
			speedFactorInWater = speedFactorInWater,
			speedFactorAtDepth = speedFactorAtDepth,
		}
	end
end

local unitDepthSlowUpdate = {}
local unitDepthFastUpdate = {}
local slowUpdateFrames = math.round(watchUpdateRate * Game.gameSpeed)
local fastUpdateFrames = math.round(depthUpdateRate * Game.gameSpeed)

-- Local functions

---@param unitID UnitID
---@param factor number? A nil clears this source's factor.
local function setSpeedModifiers(unitID, factor)
	local setUnitModifier = GG.UnitAttributes.SetUnitModifier

	local turnFactor = factor and (factor * 0.50 + 0.50)
	local accFactor = factor and (factor * 0.75 + 0.25)

	setUnitModifier(unitID, "speed", factor, ATTRIBUTE_SOURCE)
	setUnitModifier(unitID, "turnRate", turnFactor, ATTRIBUTE_SOURCE)
	setUnitModifier(unitID, "maxAcc", accFactor, ATTRIBUTE_SOURCE)
	setUnitModifier(unitID, "maxDec", accFactor, ATTRIBUTE_SOURCE)
end

local function getUnitDepth(unitID)
	local x, y, z = spGetUnitPosition(unitID)
	return x and spGetGroundHeight(x, z) or 0
end

local function getDepthFactor(unitData, depth)
	local factor = unitData.speedFactorInWater
	local depthMax = unitData.speedFactorAtDepth
	if depthMax < 0 then
		factor = 1 + (factor - 1) * math_clamp(depth / depthMax, 0, 1)
	end
	return factor
end

local function applySpeed(unitID, unitData)
	setSpeedModifiers(unitID, getDepthFactor(unitData, getUnitDepth(unitID)))
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
	local getDepth, getFactor, setModifiers = getUnitDepth, getDepthFactor, setSpeedModifiers -- micro speedup

	for unitID, unitData in pairs(unitDepthFastUpdate) do
		local depth = getDepth(unitID)
		if depth >= unitData.speedFactorAtDepth - 15 then
			setModifiers(unitID, getFactor(unitData, depth))
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
		applySpeed(unitID, unitData)
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
		applySpeed(unitID, unitData)
		if unitData.speedFactorAtDepth ~= 0 then
			unitDepthFastUpdate[unitID] = unitData
		end
	end
end

function gadget:UnitLeftWater(unitID, unitDefID, unitTeam)
	local unitData = unitDefData[unitDefID]
	if unitData then
		setSpeedModifiers(unitID, nil)
		unitDepthSlowUpdate[unitID] = nil
		unitDepthFastUpdate[unitID] = nil
	end
end

function gadget:Initialize()
	if not next(unitDefData) then
		gadgetHandler:RemoveGadget()
		return
	end

	local unitFinished = self.UnitFinished
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		unitFinished(self, unitID, Spring.GetUnitDefID(unitID), 0)
	end
end
