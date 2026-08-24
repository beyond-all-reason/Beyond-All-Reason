-- The engine misses a very large portion of its one side of the idle responsibility:
-- A factory's build queue empties through CFactoryCAI::ExecuteStop, which is just a pop;
-- multi-command removals only "finish" the first command removed, so tend not to report;
-- units that are built or spawned are not marked as idle, though they have no commands;
-- but we have kept this last gap, for now, rather than treat it as crossing a boundary.

-- In addition, units may have "idle tasks". These are orders followed to avoid player
-- frustration with useless units but are not player orders "to make yourself useful".

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
-- Post-resurrection repair is not currently idle, by the same engine property that makes
-- most command-tracking impossible, which actually helps us here. It counts, that's a W.
-- Autotargeting is not currently idle, either, though that seems subject to change.

local bit_and = math.bit_and

local spGetFactoryCommandCount = Spring.GetFactoryCommandCount
local spGetUnitCommandCount = Spring.GetUnitCommandCount
local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt

local function inIdleTaskAtIndex(unitID, index)
	local cmdID, cmdOptions, _, _, secondParam, _, fourthParam = spGetUnitCurrentCommand(unitID, index)
	local params = cmdID and IDLE_TASK_PARAMS[cmdID]
	if not params or bit_and(cmdOptions, OPT_INTERNAL) == 0 then
		return false
	end
	-- This is a fast parameter count but is not very future-proof.
	return (params == 1 and secondParam == nil)
		or (params == 3 and fourthParam == nil)
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
	-- Taking after base CUnit::IsIdle:
	if spGetUnitIsBeingBuilt(unitID) then
		return false
	end

	if UnitDefs[unitDefID].isFactory then
		return spGetFactoryCommandCount(unitID) == 0
	end

	local commandCount = spGetUnitCommandCount(unitID)
	return commandCount == 0
		or inIdleTask(unitID, commandCount)
end

return {
	IsIdle = isIdle,
}
