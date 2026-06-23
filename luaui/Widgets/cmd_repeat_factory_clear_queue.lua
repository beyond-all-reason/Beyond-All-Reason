local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Repeat Factory Clear Queue",
		desc = "Fully clears repeat-mode factory queues before stop/clear queue commands",
		author = "26Projects, Codex",
		date = "22 Jun, 2026",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true,
	}
end

local spGetRealBuildQueue = Spring.GetRealBuildQueue
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitStates = Spring.GetUnitStates
local spGiveOrderToUnit = Spring.GiveOrderToUnit

local CMD_STOP = CMD.STOP
local CMD_STOP_PRODUCTION = GameCMD and GameCMD.STOP_PRODUCTION
local CMD_WAIT = CMD.WAIT
local EMPTY = {}

local function getRepeatState(unitID)
	local states = spGetUnitStates(unitID)
	if type(states) == "table" then
		-- "repeat" is a Lua keyword, so the table key must be indexed with brackets.
		-- Some engine/widget contexts have exposed this as repeatState, so keep that
		-- fallback to make the widget tolerant of API shape differences.
		return states["repeat"] or states.repeatState
	end

	-- Older BAR code paths use the multi-return form where the 4th value is repeat.
	return select(4, spGetUnitStates(unitID, false, true))
end

local function orderDequeue(unitID, buildDefID, count)
	-- Match the factory stop-production gadget batching:
	-- right-click removes 1, shift removes 5, ctrl removes 20, ctrl+shift removes 100.
	while count > 0 do
		local opts
		if count >= 100 then
			opts = { "right", "ctrl", "shift" }
			count = count - 100
		elseif count >= 20 then
			opts = { "right", "ctrl" }
			count = count - 20
		elseif count >= 5 then
			opts = { "right", "shift" }
			count = count - 5
		else
			opts = { "right" }
			count = count - 1
		end

		spGiveOrderToUnit(unitID, -buildDefID, EMPTY, opts)
	end
end

local function clearRepeatFactoryQueue(unitID)
	local unitDefID = spGetUnitDefID(unitID)
	local unitDef = unitDefID and UnitDefs[unitDefID]

	-- This widget only changes repeat-mode factories. Manual-mode factories keep
	-- BAR's default "leave the current unit in queue" behavior.
	if not (unitDef and unitDef.isFactory and getRepeatState(unitID)) then
		return false
	end

	local queue = spGetRealBuildQueue(unitID)
	if not queue then
		return false
	end

	local cleared = false
	for _, buildPair in ipairs(queue) do
		local buildUnitDefID, count = next(buildPair, nil)
		if buildUnitDefID and count and count > 0 then
			orderDequeue(unitID, buildUnitDefID, count)
			cleared = true
		end
	end

	if cleared then
		-- Mirrors the synced gadget's wait toggle workaround: if a factory is waiting,
		-- removing the build commands alone may not clear the current build command.
		spGiveOrderToUnit(unitID, CMD_WAIT, EMPTY, 0)
		spGiveOrderToUnit(unitID, CMD_WAIT, EMPTY, 0)
	end

	return cleared
end

function widget:CommandNotify(cmdID, cmdParams, cmdOptions)
	if cmdID ~= CMD_STOP and cmdID ~= CMD_STOP_PRODUCTION then
		return false
	end

	-- Clear repeat factories first, then return false so the original stop/clear
	-- command still runs for manual factories and non-factory selected units.
	local selectedUnits = spGetSelectedUnits()
	for i = 1, #selectedUnits do
		clearRepeatFactoryQueue(selectedUnits[i])
	end

	return false
end
