local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
local matchingUnits = GG['MissionAPI'].Modules.UnitQuery.MatchingUnits
local Formation = VFS.Include("luarules/mission_api/formation_math.lua")

-- In elmos. Closer than this, the way between two points says nothing about which way the group will face.
local MIN_FACING_DISTANCE = 32

-- One square in from the edge, as the engine drops a move order off the map.
local function clampToMap(x, z)
	local edge = Game.squareSize
	return math.max(edge, math.min(Game.mapSizeX - edge, x)), math.max(edge, math.min(Game.mapSizeZ - edge, z))
end

-- The position a queued command goes to. CAPTURE, RECLAIM and REPAIR on a unit inside an area take
-- { unitID, x, y, z, radius }.
local function getCommandPosition(command)
	local params = command.params
	local id = command.id
	if #params == 5 and (id == CMD.CAPTURE or id == CMD.RECLAIM or id == CMD.REPAIR) then
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

local function issueFormationOrders(unitName, command, position, positions, direction, queue)
	local units = table.filterArray(matchingUnits(unitName), function(unitID)
		return Spring.GetUnitIsDead(unitID) == false
			and UnitDefs[Spring.GetUnitDefID(unitID)].canMove
			and not Spring.GetUnitIsBeingBuilt(unitID)
			and not Spring.GetUnitTransporter(unitID)
	end)
	if #units == 0 then
		return
	end
	-- The matching breaks ties by order, so the result must not depend on how the names table was filled.
	table.sort(units)

	local starts = {}
	for i, unitID in ipairs(units) do
		starts[i] = getStart(unitID, queue)
	end

	---@type table<integer, table>
	local targets
	if positions then
		targets = Formation.AlongLine(starts, positions)
	else
		local turn = direction and getTurn(units, starts, queue, direction, position) or 0
		targets = Formation.AroundPoint(starts, position, turn)
	end

	command = command or CMD.MOVE
	local options = queue and { "shift" } or {}

	-- Fence around mission-issued orders for UnitOrdered triggers using ignoreMissionActions.
	GG['MissionAPI'].issuingOrders = true
	for i, unitID in ipairs(units) do
		local x, z = clampToMap(targets[i].x, targets[i].z)
		Spring.GiveOrderToUnit(unitID, command, { x, Spring.GetGroundHeight(x, z), z }, options)
	end
	GG['MissionAPI'].issuingOrders = nil
end

return {
	{
		type = 'IssueFormationOrders',
		parameters = {
			{ name = 'unitName', required = true, type = ParameterTypes.UnitName },
			-- CMD.MOVE when not given.
			{ name = 'command', required = false, type = ParameterTypes.MoveCommand },
			-- The units keep their shape around position.
			{ name = 'position', required = false, type = ParameterTypes.Position },
			-- The units spread evenly along the line.
			{ name = 'positions', required = false, type = ParameterTypes.Positions },
			-- The way the shape faces at position.
			{ name = 'direction', required = false, type = ParameterTypes.Direction },
			-- Add the move to the end of each unit's queue, as the 'shift' option does.
			{ name = 'queue', required = false, type = ParameterTypes.Boolean },
			requiresOneOf = { 'position', 'positions' },
		},
		actionFunction = issueFormationOrders,
	},
}
