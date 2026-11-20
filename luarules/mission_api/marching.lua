-- A group marching for a scripted scene: every unit keeps its place in the group, which can turn to face a
-- direction. It is for looks; in play the stock formation moves suit better.

-- The orders that walk a unit to a point; orders on a target keep it as written.
---@type table<integer, boolean>
local MARCH_COMMANDS = {
	[CMD.MOVE] = true,
	[CMD.FIGHT] = true,
	[CMD.PATROL] = true,
}

-- The unit attributes source of the marching pace.
local SPEED_SOURCE = "marching"
local UPDATE_INTERVAL_FRAMES = math.round(0.5 * Game.gameSpeed)
-- How far a queued order may sit from a unit's last march order and still be it.
local SAME_POSITION = Game.squareSize

---@type table<integer, table> unitID to its last march order and its own speed: { command, x, z, speed }
local paced = {}

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

---The orders of each unit, each march order moved to the unit's own spot around its point.
---@param unitMap table<integer, boolean>
---@param orders table[]
---@param direction table? a Direction the group faces at each point
---@return table<integer, table[]> unitOrders
local function getMarchingOrders(unitMap, orders, direction)
	local marchers, marchingOrders = {}, {}
	for unitID in pairs(unitMap) do
		if canMarch(unitID) then
			marchers[#marchers + 1] = unitID
		else
			marchingOrders[unitID] = orders
		end
	end
	if #marchers == 0 then
		return marchingOrders
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
		marchingOrders[unitID] = unitOrders[i]
	end
	return marchingOrders
end

local function getLastMarchOrder(orders)
	for i = #orders, 1, -1 do
		if MARCH_COMMANDS[orders[i][1]] then
			return orders[i]
		end
	end
end

---Holds the marchers to the slowest one's speed until their march orders are gone.
---@param unitOrders table<integer, table[]> as GetMarchingOrders returns them, already given
local function matchSpeed(unitOrders)
	local marchers, count, slowest = {}, 0, math.huge
	for unitID, orders in pairs(unitOrders) do
		local last = canMarch(unitID) and getLastMarchOrder(orders)
		if last then
			-- A unit already paced reads back its paced speed, so its own is kept from the first time.
			local speed = paced[unitID] and paced[unitID].speed
				or GG.UnitAttributes.GetUnitAttributeValue(unitID, "speed")
			marchers[unitID] = { command = last[1], x = last[2][1], z = last[2][3], speed = speed }
			count, slowest = count + 1, math.min(slowest, speed)
		end
	end
	if count < 2 then
		return
	end
	-- A modifier, so the pace holds whatever else sets or scales the unit's speed.
	for unitID, marcher in pairs(marchers) do
		paced[unitID] = marcher
		local share = slowest / marcher.speed
		GG.UnitAttributes.SetUnitModifier(unitID, "speed", share < 1 and share or nil, SPEED_SOURCE)
	end
end

-- The whole queue, as an ATTACK can be pushed in front of a FIGHT and a PATROL never leaves it.
local function hasMarchOrder(unitID, last)
	for index = 1, Spring.GetUnitCommandCount(unitID) do
		local command, _, _, x, _, z = Spring.GetUnitCurrentCommand(unitID, index)
		if
			command == last.command
			and z
			and math.abs(x - last.x) < SAME_POSITION
			and math.abs(z - last.z) < SAME_POSITION
		then
			return true
		end
	end
	return false
end

local function updateSpeeds(frameNumber)
	if frameNumber % UPDATE_INTERVAL_FRAMES ~= 0 then
		return
	end
	for unitID, last in pairs(paced) do
		local alive = Spring.GetUnitIsDead(unitID) == false
		-- Arrived, given other orders or loaded: the unit gets its own speed back.
		if not alive or Spring.GetUnitTransporter(unitID) or not hasMarchOrder(unitID, last) then
			paced[unitID] = nil
			if alive then
				GG.UnitAttributes.SetUnitModifier(unitID, "speed", nil, SPEED_SOURCE)
			end
		end
	end
end

return {
	GetMarchingOrders = getMarchingOrders,
	MatchSpeed = matchSpeed,
	UpdateSpeeds = updateSpeeds,
}
