-- A group marching for a scripted scene: every unit keeps its place in the group, which can turn to face a
-- direction. It is for looks; in play the stock formation moves suit better.

-- The orders that walk a unit to a point; orders on a target keep it as written.
---@type table<integer, boolean>
local MARCH_COMMANDS = {
	[CMD.MOVE] = true,
	[CMD.FIGHT] = true,
	[CMD.PATROL] = true,
}

-- A factory takes move orders as rally points but has no speed.
local function canMarch(unitID)
	return UnitDefs[Spring.GetUnitDefID(unitID)].speed > 0
		and not Spring.GetUnitIsBeingBuilt(unitID)
		and not Spring.GetUnitTransporter(unitID)
end

-- The way the group faces, in radians, or nil when its units face opposite ways.
local function getGroupHeading(unitIDs)
	local x, z = 0.0, 0.0
	for _, unitID in ipairs(unitIDs) do
		local dx, _, dz = Spring.GetUnitDirection(unitID)
		x, z = x + dx, z + dz
	end
	if x * x + z * z > 1e-6 then
		return math.atan2(x, z)
	end
end

-- The turn from heading to the direction, seen from the point x, z.
local function getTurn(direction, heading, x, z)
	if direction.angle then
		return BAR.Utilities.CompassAngleToHeading(direction.angle, true) - heading
	end
	if direction.x ~= x or direction.z ~= z then
		return math.atan2(direction.x - x, direction.z - z) - heading
	end
	return 0
end

---Gives the units the orders, each march order to each unit's own spot around its point.
---@param unitMap table<integer, boolean>
---@param orders table[] as Spring.GiveOrderArrayToUnit takes them
---@param direction table? a Direction the group faces at each point
local function giveMarchingOrders(unitMap, orders, direction)
	local marchers = {}
	for unitID in pairs(unitMap) do
		if canMarch(unitID) then
			marchers[#marchers + 1] = unitID
		else
			Spring.GiveOrderArrayToUnit(unitID, orders)
		end
	end
	if #marchers == 0 then
		return
	end

	local centerX, _, centerZ = Spring.GetUnitArrayCentroid(marchers)
	local heading = direction and getGroupHeading(marchers)
	local offsets, unitOrders = {}, {}
	for i, unitID in ipairs(marchers) do
		local x, _, z = Spring.GetUnitPosition(unitID)
		---@cast x number
		---@cast z number
		offsets[i] = { x - centerX, z - centerZ }
		unitOrders[i] = {}
	end

	-- One square in from the edge, as the engine drops a move order off the map.
	local edge = Game.squareSize
	for _, order in ipairs(orders) do
		local command, params, options = order[1], order[2], order[3]
		if MARCH_COMMANDS[command] then
			local turn = heading and getTurn(direction, heading, params[1], params[3]) or 0
			local cos, sin = math.cos(turn), math.sin(turn)
			for i, offset in ipairs(offsets) do
				local dx, dz = offset[1], offset[2]
				local x = math.clamp(params[1] + dx * cos + dz * sin, edge, Game.mapSizeX - edge)
				local z = math.clamp(params[3] + dz * cos - dx * sin, edge, Game.mapSizeZ - edge)
				table.insert(unitOrders[i], { command, { x, Spring.GetGroundHeight(x, z), z }, options })
			end
		else
			for i in ipairs(offsets) do
				table.insert(unitOrders[i], order)
			end
		end
	end

	for i, unitID in ipairs(marchers) do
		Spring.GiveOrderArrayToUnit(unitID, unitOrders[i])
	end
end

return {
	GiveMarchingOrders = giveMarchingOrders,
}
