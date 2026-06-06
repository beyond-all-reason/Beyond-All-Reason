local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name    = "Construction Turrets range assist",
		desc    = "When a command is given to nanos, this widget will check if each nanos is in range to execute it. If not the command will not be given to the out of range nanos. Use CTRL to skip this widget.",
		author  = "mreasyfrag",
		date    = "30/05/2026",
		license = "GNU GPL, v2 or later",
		layer   = -1,
		-- -1 to be executed before cmd_no_duplicate_orders.lua that break the behavior when using right click to repair on the second click
		enabled = true,
	}
end

local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetUnitDefID = Spring.GetUnitDefID
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local UnitDefs = UnitDefs
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitBuildeeRadius = Spring.GetUnitBuildeeRadius
local spGetFeaturePosition = Spring.GetFeaturePosition
local maxUnits = Game.maxUnits

local nanoBuildDistances = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.isBuilder and not unitDef.canMove and not unitDef.isFactory then
		nanoBuildDistances[unitDefID] = unitDef.buildDistance
	end
end

local function isWithinBuildDistance(unitID, buildDistance, targetX, targetZ, targetRadius)
	local nanoX, _, nanoZ = spGetUnitPosition(unitID)
	-- nanoX is nil if nano died before the command was processed
	if nanoX then
		local adjustedRange = buildDistance + targetRadius
		local dx = nanoX - targetX
		local dz = nanoZ - targetZ
		if dx * dx + dz * dz <= adjustedRange * adjustedRange then
			return true
		end
	end
	return false
end

local function hasNano(selectedUnits)
	for _, unitID in ipairs(selectedUnits) do
		if nanoBuildDistances[spGetUnitDefID(unitID)] then
			return true
		end
	end
	return false
end

function widget:CommandNotify(id, params, options)
	if options.ctrl then return false end
	if #params ~= 1 then return false end

	if id ~= CMD.REPAIR and id ~= CMD.RECLAIM and id ~= CMD.GUARD then return false end

	local selectedUnits = spGetSelectedUnits()

	if not hasNano(selectedUnits) then return false end

	local targetX, targetZ, targetRadius

	if params[1] < maxUnits then
		targetX, _, targetZ = spGetUnitPosition(params[1])
		targetRadius = spGetUnitBuildeeRadius(params[1]) or 0
	else
		targetX, _, targetZ = spGetFeaturePosition(params[1] - maxUnits)
		targetRadius = 0
	end

	-- targetX is nil if target died before the command was processed
	if not targetX then return false end

	for _, unitID in ipairs(selectedUnits) do
		local buildDistance = nanoBuildDistances[spGetUnitDefID(unitID)]

		-- buildDistance is nil when the unit is not a nano
		if buildDistance ~= nil then
			if isWithinBuildDistance(unitID, buildDistance, targetX, targetZ, targetRadius) then
				spGiveOrderToUnit(unitID, id, params, options)
			end
		else
			spGiveOrderToUnit(unitID, id, params, options)
		end
	end

	return true
end
