--------------------------------------------------------------------------------
--- Unit idle states and "idle task" definitions for UnitIdled and UnitUnidled.
---
--- Both triggers read the same state and must agree on when a unit runs out of
--- work, when it picks it back up, and when the boundary of "busy" is reached.
--------------------------------------------------------------------------------

-- The engine misses a very large portion of its one side of the trigger responsibility:
-- A factory's build queue empties through CFactoryCAI::ExecuteStop, which is just a pop;
-- units that are built or spawned are not marked as idle, though they have no commands;
-- multi-command removals only "finish" the first command removed, so tend not to report.

-- In addition, units may have "idle tasks". These are orders followed to avoid player
-- frustration with useless units but are not player orders "to make yourself useful".
-- By "idle tasks" we primarily mean idle repair from unit_auto_repair_idle_builders.lua,
-- which also has a return-move, and cmd_build_bugger_off.lua, which has a bugger-move.
-- To distinguish these commands from others, we assume each is issued with OPT_INTERNAL.

local CMD_REPAIR   = CMD.REPAIR
local CMD_MOVE     = CMD.MOVE
local OPT_INTERNAL = CMD.OPT_INTERNAL -- Imperfect but acceptable marker for idle tasks.

-- Idle tasks are a pure accident of the many ways units receive commands via the engine.
-- We identify them by a command + params + internal triple. They have no simple summary.
local IDLE_TASK_PARAMS = {
	[CMD_REPAIR] = 1, -- a targetID
	[CMD_MOVE]   = 3, -- a position
}
--
-- Counterexamples shape the rest of idle tasks, then. Autotargeting is not currently idle.
-- Post-resurrection repair is not currently idle, by the same engine property that makes
-- most command-tracking impossible, which actually helps us here. It counts, that's a W.

local bit_and = math.bit_and

local latches = {}

local function inIdleTaskAtIndex(unitID, index)
	local cmdID, cmdOptions, _, _, secondParam, _, fourthParam = Spring.GetUnitCurrentCommand(unitID, index)
	local wantedParamCount = cmdID and IDLE_TASK_PARAMS[cmdID]
	if not wantedParamCount or bit_and(cmdOptions, OPT_INTERNAL) == 0 then
		return false
	end
	return (wantedParamCount == 1 and secondParam == nil)
		or (wantedParamCount == 3 and fourthParam == nil) -- NB: leaky.
end

---Whether everything in the unit's command queue is an idle task.
local function inIdleTask(unitID, commandCount)
	for index = 1, commandCount do
		if not inIdleTaskAtIndex(unitID, index) then
			return false
		end
	end
	return true
end

local function isIdle(unitID, unitDefID)
	-- Take after CUnit::IsIdle where we can:
	if Spring.GetUnitIsBeingBuilt(unitID) then
		return false
	end

	if UnitDefs[unitDefID].isFactory then
		return Spring.GetFactoryCommandCount(unitID) == 0
	end

	local commandCount = Spring.GetUnitCommandCount(unitID)
	return commandCount == 0
		or inIdleTask(unitID, commandCount)
end

---Build the IdleUpdate artificial callin for the UnitIdled and UnitUnidled triggers.
---Each runs the same update except for one boolean comparison and shares the same state.
---@param fireOnIdle boolean true := falling into idle, false := leaving it
---@param matchesUnit fun(parameters, context, unitID, unitDefID): boolean
local function createIdleUpdate(fireOnIdle, matchesUnit)
	return function(trigger, triggerID, context, dirtyUnits)
		local parameters = trigger.parameters
		local latched = table.ensureTable(latches, triggerID)

		for unitID in pairs(dirtyUnits) do
			-- Units can be finalized from mark to sweep; check they are valid.
			local unitDefID = Spring.GetUnitDefID(unitID)
			if unitDefID then
				local idle = isIdle(unitID, unitDefID)
				if idle ~= (latched[unitID] == true) then
					latched[unitID] = idle or nil
					-- Dying units still hold orders, and unit tracking can change between updates.
					if idle == fireOnIdle
						and Spring.GetUnitIsDead(unitID) == false
						and matchesUnit(parameters, context, unitID, unitDefID)
					then
						context.ActivateTrigger(trigger)
					end
				end
			end
		end
	end
end

-- Report nothing on death; only forget.
local function clear(triggerID, unitID)
	local latch = latches[triggerID]
	if latch then
		latch[unitID] = nil
	end
end

return {
	CreateIdleUpdate = createIdleUpdate,
	Clear            = clear,
}
