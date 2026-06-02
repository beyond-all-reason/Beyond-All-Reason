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

local nanoDefs = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.isBuilder and not unitDef.canMove and not unitDef.isFactory then
		nanoDefs[unitDefID] = unitDef.buildDistance
	end
end

function widget:CommandNotify(id, params, options)
	if options.ctrl then return false end
	if #params ~= 1 then return false end

	if id ~= CMD.REPAIR and id ~= CMD.RECLAIM and id ~= CMD.GUARD then return false end

	local selectedUnits = spGetSelectedUnits()

	local hasNano = false
	for _, unitID in ipairs(selectedUnits) do
		if nanoDefs[spGetUnitDefID(unitID)] then
			hasNano = true
			break
		end
	end
	if not hasNano then return false end

	local tx, tz, targetRadius

	if params[1] < maxUnits then
		tx, _, tz = spGetUnitPosition(params[1])
		targetRadius = spGetUnitBuildeeRadius(params[1]) or 0
	else
		tx, _, tz = spGetFeaturePosition(params[1] - maxUnits)
		targetRadius = 0
	end

	-- tx is nil if target died before the command was processed
	if not tx then return false end

	for _, unitID in ipairs(selectedUnits) do
		local unitDefID = spGetUnitDefID(unitID)

		if nanoDefs[unitDefID] ~= nil then
			local nx, _, nz = spGetUnitPosition(unitID)
			-- nx is nil if nano died before the command was processed
			if nx then
				local adjustedRange = nanoDefs[unitDefID] + targetRadius
				local dx = nx - tx
				local dz = nz - tz
				if dx * dx + dz * dz <= adjustedRange * adjustedRange then
					spGiveOrderToUnit(unitID, id, params, options)
				end
			end
		else
			spGiveOrderToUnit(unitID, id, params, options)
		end
	end

	return true
end
