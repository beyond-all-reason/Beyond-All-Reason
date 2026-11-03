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
-- A maximum. Extra squads of units get more budget to keep the total count of squads low.
local EXTRA_SQUAD_COMMANDS = 1600
-- River splits aim for lanes about this wide. The actual width varies with the targets.
local LANE_WIDTH = 400

local math_ceil = math.ceil
local math_min = math.min
local table_sort = table.sort

local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitNeutral = Spring.GetUnitNeutral
local spGetUnitCommands = Spring.GetUnitCommands
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
local spGiveOrderArrayToUnit = Spring.GiveOrderArrayToUnit
local spGiveOrderToUnit = Spring.GiveOrderToUnit

local ENEMY_UNITS = Spring.ENEMY_UNITS
local CMD_ATTACK = CMD.ATTACK
local CMD_FIGHT = CMD.FIGHT
local CMD_REMOVE = CMD.REMOVE
local CMD_STOP = CMD.STOP
local CMD_OPT_SHIFT = CMD.OPT_SHIFT

local getCentroid = BAR.Utilities.GetObjectCentroid
local splitRivers = require("modules/split_targets").Rivers

local isObject = {}
local canFight = {} -- excludes static units and bombers, which generally cannot execute FIGHT
for unitDefID, unitDef in pairs(UnitDefs) do
	isObject[unitDefID] = unitDef.customParams.objectify ~= nil
	local weapon = unitDef.weapons[1]
	canFight[unitDefID] = unitDef.canFight
		and not unitDef.isImmobile
		and weapon
		and WeaponDefs[weapon.weaponDef].type ~= "AircraftBomb"
end

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

local centerX, centerZ = 0.0, 0.0

local function sortNearestCenter(_, targets)
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

local isReissuing = false

function gadget:CommandNotify(cmdID, cmdParams, cmdOpts)
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

	local ax, az, areaRadius = cmdParams[1], cmdParams[3], cmdParams[4]
	local handled = false

	CallAsTeam(Spring.GetLocalTeamID(), function()
		local targets = spGetUnitsInCylinder(ax, az, areaRadius, ENEMY_UNITS)

		local total = 0 -- TODO: Wall exclusion should be absorbed into other widgets. The separate/double handling is a pain.
		for i = 1, #targets do
			local targetID = targets[i]
			if not (isObject[spGetUnitDefID(targetID)] and spGetUnitNeutral(targetID)) then
				total = total + 1
				targets[i], targets[total] = targets[total], targetID
			end
		end
		if #attackers * total <= COMMAND_LIMIT then
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

		for i = #targets, total + 1, -1 do
			targets[i] = nil
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

		centerX, centerZ = getCentroid(attackers, unitPositionAtQueueEnd) -- for sortNearestCenter
		local targetsPerUnit, squads =
			splitRivers(attackers, targets, unitPositionAtQueueEnd, sortNearestCenter, nil, COMMAND_LIMIT, LANE_WIDTH)

		local commandLimit = math_min(
			#attackers * total / #squads,
			COMMAND_LIMIT + EXTRA_SQUAD_COMMANDS * (1 - 1 / #squads)
		)
		local maxTargetsPerUnit = math_ceil(commandLimit / #attackers)

		for s = 1, #squads do
			local squad = squads[s]
			for k = 1, #squad do
				local unitID = squad[k]
				local unitTargets = targetsPerUnit[unitID]
				local alreadyQueued = queuedAttacks and queuedAttacks[unitID]

				local orders = {}
				if not cmdOpts.shift then
					orders[1] = { CMD_STOP, {}, 0 }
				end

				-- The order being replaced would give all units a sequence of shared targets.
				-- Squad orders do the same thing starting from the "head" of the shared lane.
				local count, headEnd = 0, #unitTargets
				for j = 1, #unitTargets do
					local targetID = unitTargets[j]
					if not (alreadyQueued and alreadyQueued[targetID]) then
						count = count + 1
						orders[#orders + 1] = { CMD_ATTACK, { targetID }, opts + CMD_OPT_SHIFT }
						if count == maxTargetsPerUnit then
							headEnd = j
							break
						end
					end
				end

				-- Uncovered targets are shared out equally, then a FIGHT to the end of the lane.
				for j = headEnd + k, #unitTargets, #squad do
					local targetID = unitTargets[j]
					if not (alreadyQueued and alreadyQueued[targetID]) then
						orders[#orders + 1] = { CMD_ATTACK, { targetID }, opts + CMD_OPT_SHIFT }
					end
				end
				if headEnd < #unitTargets and canFight[spGetUnitDefID(unitID)] then
					local x, y, z = spGetUnitPosition(unitTargets[#unitTargets])
					orders[#orders + 1] = { CMD_FIGHT, { x, y, z }, opts + CMD_OPT_SHIFT }
				end

				if orders[1] ~= nil then
					spGiveOrderArrayToUnit(unitID, orders)
				end
			end
		end
	end)
	isReissuing = false

	return handled
end
