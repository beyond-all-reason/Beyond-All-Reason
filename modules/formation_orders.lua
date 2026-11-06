-- modules/formation_orders.lua
--
-- Orders for a group the way a player's formation move gives them: each MOVE, FIGHT or PATROL order sends each
-- unit to its own spot, worked out from where the units are.
-- The engine makes formation moves only for a player's own orders to their selection, so synced Lua needs this.

local Formation = require("modules/formation_math")

-- In elmos. Closer than this, the way between two points says nothing about which way the group will face.
local MIN_FACING_DISTANCE = 32

-- One square in from the edge, as the engine drops a move order off the map.
local function clampToMap(x, z)
	local edge = Game.squareSize
	return math.max(edge, math.min(Game.mapSizeX - edge, x)), math.max(edge, math.min(Game.mapSizeZ - edge, z))
end

-- CAPTURE, RECLAIM, REPAIR and RESURRECT on a target inside an area take { targetID, x, y, z, radius }.
local function getCommandPosition(id, params)
	if #params == 5 and (id == CMD.CAPTURE or id == CMD.RECLAIM or id == CMD.REPAIR or id == CMD.RESURRECT) then
		return params[2], params[4]
	end
	if #params >= 3 then
		return params[1], params[3]
	end
end

-- The last queued command with a position, else where the unit stands.
local function getQueueEndPosition(unitID)
	for index = -1, -(Spring.GetUnitCommandCount(unitID) or 0), -1 do
		local id, _, _, a, b, c, d, e = Spring.GetUnitCurrentCommand(unitID, index)
		local x, z = getCommandPosition(id, { a, b, c, d, e })
		if x then
			return { x = x, z = z }
		end
	end
	local x, _, z = Spring.GetUnitPosition(unitID)
	return { x = x, z = z }
end

-- The way the group faces now. With queue, the way from where the units stand to where their queues end, otherwise
-- the mean of their headings. When that says nothing, as for units facing opposite ways, the way to the destination.
local function getGroupHeading(units, starts, queue, destination)
	if queue then
		local positions = {}
		for i, unitID in ipairs(units) do
			local x, _, z = Spring.GetUnitPosition(unitID)
			positions[i] = { x = x, z = z }
		end
		local from, to = Formation.Center(positions), Formation.Center(starts)
		if Formation.Distance(from, to) >= MIN_FACING_DISTANCE then
			return math.atan2(to.x - from.x, to.z - from.z)
		end
	end

	local headings = {}
	for i, unitID in ipairs(units) do
		headings[i] = Spring.GetUnitHeading(unitID, true)
	end
	local heading = Formation.MeanHeading(headings)
	if heading then
		return heading
	end

	local from = Formation.Center(starts)
	if Formation.Distance(from, destination) >= MIN_FACING_DISTANCE then
		return math.atan2(destination.x - from.x, destination.z - from.z)
	end
end

-- A heading, or a point to face from the destination.
local function getFacingHeading(facing, destination)
	if type(facing) == "number" then
		return facing
	end
	if facing.x ~= destination.x or facing.z ~= destination.z then
		return math.atan2(facing.x - destination.x, facing.z - destination.z)
	end
end

local function getTurn(units, starts, queue, facing, destination)
	local heading = getGroupHeading(units, starts, queue, destination)
	local wanted = getFacingHeading(facing, destination)
	if heading and wanted then
		return math.clampRadians(wanted - heading)
	end
	return 0
end

-- A factory can move, to take rally orders, but has no speed.
local function canSpread(unitID)
	local unitDef = UnitDefs[Spring.GetUnitDefID(unitID)]
	return unitDef ~= nil
		and unitDef.canMove
		and unitDef.speed > 0
		and not Spring.GetUnitIsBeingBuilt(unitID)
		and not Spring.GetUnitTransporter(unitID)
end

local function isSpreadOrder(order)
	local command = order[1]
	return command == CMD.MOVE or command == CMD.FIGHT or command == CMD.PATROL
end

-- A spread order with more than one point is a line: { x1, y1, z1, x2, y2, z2, ... }.
local function linePoints(params)
	local points = {}
	for i = 1, #params - 2, 3 do
		points[#points + 1] = { x = params[i], z = params[i + 2] }
	end
	return points
end

-- Each unit's spot for one order. A queued order starts where the unit's previous one ends.
local function spreadTargets(units, order, facing, lastSpots)
	local params, options = order[2], order[3] or {}
	local queue = table.contains(options, "shift")

	local starts = {}
	for i, unitID in ipairs(units) do
		if queue then
			starts[i] = lastSpots[unitID] or getQueueEndPosition(unitID)
		else
			local x, _, z = Spring.GetUnitPosition(unitID)
			starts[i] = { x = x, z = z }
		end
	end

	---@type table<integer, table>
	local targets
	if #params > 3 then
		targets = Formation.AlongLine(starts, linePoints(params))
	else
		local destination = { x = params[1], z = params[3] }
		local turn = facing and getTurn(units, starts, queue, facing, destination) or 0
		targets = Formation.AroundPoint(starts, destination, turn)
	end

	return targets
end

-- Units that are not spread take a line as its first point.
local function ordersWithoutFormation(orders)
	local written = {}
	for i, order in ipairs(orders) do
		local params = order[2]
		if isSpreadOrder(order) and #params > 3 then
			written[i] = { order[1], { params[1], params[2], params[3] }, order[3] }
		else
			written[i] = order
		end
	end
	return written
end

--- Nanoframes, transported units and units that cannot move take the orders as written; dead units take none.
---@param unitIDs integer[]
---@param orders table[] as Spring.GiveOrderArrayToUnit takes them
---@param options table { facing: a heading, or a point { x, z }, the shape faces at each point it keeps,
--- pace: function(unitIDs, targets, command) given the units and spots of the first move, to set their speeds }
local function giveFormationOrders(unitIDs, orders, options)
	local spread, others = {}, {}
	for _, unitID in ipairs(unitIDs) do
		if Spring.GetUnitIsDead(unitID) ~= false then
			-- Dead, or no longer a unit.
		elseif canSpread(unitID) then
			spread[#spread + 1] = unitID
		else
			others[#others + 1] = unitID
		end
	end
	-- The matching breaks ties by order, so the result must not depend on the order of unitIDs.
	table.sort(spread)

	if #others > 0 then
		local written = ordersWithoutFormation(orders)
		for _, unitID in ipairs(others) do
			Spring.GiveOrderArrayToUnit(unitID, written)
		end
	end

	local unitOrders, lastSpots, paced = {}, {}, nil
	for _, unitID in ipairs(spread) do
		unitOrders[unitID] = {}
	end
	for _, order in ipairs(orders) do
		local command, params, orderOptions = order[1], order[2], order[3] or {}
		local targets = isSpreadOrder(order) and #spread > 0 and spreadTargets(spread, order, options.facing, lastSpots)
		-- The first move is the leg the units set out on now; a queued one only where nothing is queued before it.
		local pacing = targets and options.pace and not paced
		if pacing then
			paced = { units = {}, targets = {}, command = command }
		end
		for i, unitID in ipairs(spread) do
			local list = unitOrders[unitID]
			if targets then
				local x, z = clampToMap(targets[i].x, targets[i].z)
				list[#list + 1] = { command, { x, Spring.GetGroundHeight(x, z), z }, orderOptions }
				lastSpots[unitID] = { x = x, z = z }
				if
					pacing and (not table.contains(orderOptions, "shift") or Spring.GetUnitCommandCount(unitID) == 0)
				then
					paced.units[#paced.units + 1] = unitID
					paced.targets[#paced.targets + 1] = { x = x, z = z }
				end
			else
				list[#list + 1] = { command, params, orderOptions }
				local x, z = getCommandPosition(command, params)
				lastSpots[unitID] = x and { x = x, z = z } or lastSpots[unitID]
			end
		end
	end
	for _, unitID in ipairs(spread) do
		Spring.GiveOrderArrayToUnit(unitID, unitOrders[unitID])
	end
	if paced then
		options.pace(paced.units, paced.targets, paced.command)
	end
end

return {
	GiveFormationOrders = giveFormationOrders,
	IsSpreadOrder = isSpreadOrder,
}
