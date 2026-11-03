---
--- Orders for a group the way a player's formation move gives them: each MOVE, FIGHT or PATROL order sends each
--- unit to its own spot, worked out from where the units are. IssueOrders gives orders this way with `formation`.
---
--- The engine makes formation moves only for a player's own orders to their selection, so synced Lua needs this.
---

local Formation = VFS.Include("luarules/mission_api/formation_math.lua")

-- In elmos. Closer than this, the way between two points says nothing about which way the group will face.
local MIN_FACING_DISTANCE = 32

-- One square in from the edge, as the engine drops a move order off the map.
local function clampToMap(x, z)
	local edge = Game.squareSize
	return math.max(edge, math.min(Game.mapSizeX - edge, x)), math.max(edge, math.min(Game.mapSizeZ - edge, z))
end

-- The position a queued command goes to. CAPTURE, RECLAIM, REPAIR and RESURRECT on a target inside an area take
-- { targetID, x, y, z, radius }.
local function getCommandPosition(command)
	local params = command.params
	local id = command.id
	if #params == 5 and (id == CMD.CAPTURE or id == CMD.RECLAIM or id == CMD.REPAIR or id == CMD.RESURRECT) then
		return params[2], params[4]
	end
	if #params >= 3 then
		return params[1], params[3]
	end
end

-- With queue, the unit starts from the last position in its queue.
local function getStart(unitID, queue)
	if queue then
		local commands = Spring.GetUnitCommands(unitID, -1)
		for i = #commands, 1, -1 do
			local x, z = getCommandPosition(commands[i])
			if x then
				return { x = x, z = z }
			end
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

-- A compass angle (0 north, clockwise), or a point to face from the destination.
local function getDirectionHeading(direction, destination)
	if direction.angle then
		-- TODO: refactor to call CompassAngleToHeading when it is merged
		return math.rad(180 - direction.angle)
	end
	if direction.x ~= destination.x or direction.z ~= destination.z then
		return math.atan2(direction.x - destination.x, direction.z - destination.z)
	end
end

local function getTurn(units, starts, queue, direction, destination)
	local heading = getGroupHeading(units, starts, queue, destination)
	local wanted = getDirectionHeading(direction, destination)
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

local function spreadOrder(units, order, direction, matchSpeed)
	local command, params, options = order[1], order[2], order[3] or {}
	local queue = table.contains(options, "shift")

	-- With shift, skip units that already have orders: the cap would slow those too.
	local starts, paced = {}, {}
	for i, unitID in ipairs(units) do
		starts[i] = getStart(unitID, queue)
		paced[i] = matchSpeed and (not queue or Spring.GetUnitCommandCount(unitID) == 0)
	end

	---@type table<integer, table>
	local targets
	if #params > 3 then
		targets = Formation.AlongLine(starts, linePoints(params))
	else
		local destination = { x = params[1], z = params[3] }
		local turn = direction and getTurn(units, starts, queue, direction, destination) or 0
		targets = Formation.AroundPoint(starts, destination, turn)
	end

	local pacedUnits, pacedTargets = {}, {}
	for i, unitID in ipairs(units) do
		local x, z = clampToMap(targets[i].x, targets[i].z)
		Spring.GiveOrderToUnit(unitID, command, { x, Spring.GetGroundHeight(x, z), z }, options)
		if paced[i] then
			pacedUnits[#pacedUnits + 1] = unitID
			pacedTargets[#pacedTargets + 1] = { x = x, z = z }
		end
	end

	if matchSpeed then
		GG["MissionAPIActionHelper"].matchFormationSpeed(pacedUnits, pacedTargets, command)
	end
end

-- Units that are not spread take the orders as written, a line as its first point.
local function asWritten(orders)
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
---@param orders table[] with unit and feature names already turned into IDs
---@param formation table { direction: the way the shape faces at each point it keeps, matchSpeed: arrive together at
--- the first point }
local function giveFormationOrders(unitIDs, orders, formation)
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
	-- The matching breaks ties by order, so the result must not depend on how the names table was filled.
	table.sort(spread)

	if #others > 0 then
		local written = asWritten(orders)
		for _, unitID in ipairs(others) do
			Spring.GiveOrderArrayToUnit(unitID, written)
		end
	end

	-- One order at a time to the whole group, so a queued order starts from where the one before it ends.
	-- matchSpeed paces the first move, the leg the units set out on now.
	local matchSpeed = formation.matchSpeed == true
	for _, order in ipairs(orders) do
		if isSpreadOrder(order) then
			if #spread > 0 then
				spreadOrder(spread, order, formation.direction, matchSpeed)
				matchSpeed = false
			end
		else
			for _, unitID in ipairs(spread) do
				Spring.GiveOrderToUnit(unitID, order[1], order[2], order[3] or {})
			end
		end
	end
end

return {
	GiveFormationOrders = giveFormationOrders,
	IsSpreadOrder = isSpreadOrder,
}
