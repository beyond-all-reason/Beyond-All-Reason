local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Area Attack Limiter",
		desc = "Splits large area-form attack commands into targeted attacks to reduce lag from large (air) engagements",
		author = "Floris",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = -999999,
		enabled = true,
	}
end

if gadgetHandler:IsSyncedCode() then
	return
end

-- Commands expand into N = units x targets orders. Above this many, it's split instead.
local COMMAND_LIMIT = 2000
-- River splits aim for lanes about this wide. The actual width varies with the targets.
local LANE_WIDTH = 400

local CMD_ATTACK = CMD.ATTACK
local CMD_REMOVE = CMD.REMOVE
local CMD_STOP = CMD.STOP
local CMD_OPT_SHIFT = CMD.OPT_SHIFT
local ENEMY_UNITS = Spring.ENEMY_UNITS

local math_ceil = math.ceil
local math_max = math.max
local table_sort = table.sort

local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetUnitCommands = Spring.GetUnitCommands
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
local spGiveOrderArrayToUnit = Spring.GiveOrderArrayToUnit
local spGiveOrderToUnit = Spring.GiveOrderToUnit

local getCentroid = BAR.Utilities.GetObjectCentroid
local splitRivers = require("modules/split_targets").Rivers

local isReissuing = false

local queueEnd = {} -- queued area attacks start after the last-queued command position

local function unitPositionAtQueueEnd(unitID)
	local position = queueEnd[unitID]
	if position then
		return position[1], position[2], position[3]
	end
	return spGetUnitPosition(unitID)
end

local function readQueue(unitID)
	local queue = spGetUnitCommands(unitID, -1)
	local queuedAttacks = {}
	local endPosition
	for i = #queue, 1, -1 do
		local command = queue[i]
		local params = command.params
		if command.id == CMD_ATTACK and #params == 1 then
			queuedAttacks[params[1]] = command.tag
		end
		if not endPosition and #params >= 3 then
			endPosition = params
		end
	end
	return queuedAttacks, endPosition
end

local function sortNearestGroup(group, targets)
	local centerX, centerZ = getCentroid(group, unitPositionAtQueueEnd)
	local distances = {}
	for i = 1, #targets do
		local targetID = targets[i]
		local targetX, _, targetZ = spGetUnitPosition(targetID)
		local dx, dz = targetX - centerX, targetZ - centerZ
		distances[targetID] = dx * dx + dz * dz
	end
	table_sort(targets, function(a, b)
		return distances[a] < distances[b]
	end)
end

function gadget:CommandNotify(cmdID, cmdParams, cmdOpts)
	-- Guard against re-entrancy: reissued orders can trigger CommandNotify again
	if isReissuing then
		return
	end

	-- Only intercept area-form CMD_ATTACK commands (4 params: x, y, z, radius).
	-- Engine-native CMD_AREA_ATTACK remains compact and is intentionally not limited.
	if cmdID ~= CMD_ATTACK or #cmdParams ~= 4 or cmdParams[4] <= 0 then
		return
	end

	local attackers = spGetSelectedUnits()

	-- Preserve command options
	local opts = 0
	if cmdOpts.alt then
		opts = opts + CMD.OPT_ALT
	end
	if cmdOpts.ctrl then
		opts = opts + CMD.OPT_CTRL
	end
	if cmdOpts.meta then
		opts = opts + CMD.OPT_META
	end
	if cmdOpts.right then
		opts = opts + CMD.OPT_RIGHT
	end

	local x, z, radius = cmdParams[1], cmdParams[3], cmdParams[4]
	local handled = false

	CallAsTeam(Spring.GetLocalTeamID(), function()
		local targets = spGetUnitsInCylinder(x, z, radius, ENEMY_UNITS)
		if #attackers * #targets <= COMMAND_LIMIT then
			return
		end

		isReissuing = true
		handled = true

		-- Ctrl copies the engine for now and removes targets in the area.
		-- TODO: Remove this behavior. This modifier is badly overloaded with area commands and causes the current stupid modifier combinations.
		if cmdOpts.ctrl then
			local inArea = {}
			for i = 1, #targets do
				inArea[targets[i]] = true
			end
			for i = 1, #attackers do
				local unitID = attackers[i]
				local tags = {}
				for targetID, tag in pairs(readQueue(unitID)) do
					if inArea[targetID] then
						tags[#tags + 1] = tag
					end
				end
				if tags[1] then
					spGiveOrderToUnit(unitID, CMD_REMOVE, tags, 0)
				end
			end
			return
		end

		local queuedAttacks
		queueEnd = {}
		if cmdOpts.shift then
			-- A target already queued is not queued again to prevent canceling the duplicate command.
			queuedAttacks = {}
			for i = 1, #attackers do
				local unitID = attackers[i]
				queuedAttacks[unitID], queueEnd[unitID] = readQueue(unitID)
			end
		end

		local maxTargetsPerUnit = math_max(math_ceil(COMMAND_LIMIT / #attackers), 1)
		local targetsPerUnit =
			splitRivers(attackers, targets, unitPositionAtQueueEnd, sortNearestGroup, COMMAND_LIMIT, LANE_WIDTH)
		for i = 1, #attackers do
			local unitID = attackers[i]
			local unitTargets = targetsPerUnit[unitID]

			local orders = {}
			if not cmdOpts.shift then
				orders[1] = { CMD_STOP, {}, 0 }
			end
			local alreadyQueued = queuedAttacks and queuedAttacks[unitID]
			local count = 0
			for j = 1, #unitTargets do
				if count == maxTargetsPerUnit then
					break
				end
				local targetID = unitTargets[j]
				if targetID ~= unitID and not (alreadyQueued and alreadyQueued[targetID]) then
					count = count + 1
					orders[#orders + 1] = { CMD_ATTACK, { targetID }, opts + CMD_OPT_SHIFT }
				end
			end
			if orders[1] then
				spGiveOrderArrayToUnit(unitID, orders)
			end
		end
	end)
	isReissuing = false

	return handled
end
