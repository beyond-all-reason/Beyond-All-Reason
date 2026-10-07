---@diagnostic disable: assign-type-mismatch, need-check-nil, unnecessary-assert

-- Skipping the last listed target must behave like skipping the last native
-- Attack: the Command Queue Manager sees a queue of length one, removes it and
-- issues Stop, and Stop clears Set Target. A controller trailing the last
-- Attack would make the queue two commands long and suppress that Stop.

---@type boolean
local areaPrepared = false
---@type boolean
local queuePrepared = false

function setup()
	assert(select(1, Spring.GetTeamInfo(1, false)) ~= nil, "target-list tests require enemy team 1")
	Test.clearMap()
end

function cleanup()
	if areaPrepared then
		Test.restoreWidget("Area Command Filter")
	end
	if queuePrepared then
		Test.restoreWidget("Command Queue Manager")
	end
	areaPrepared, queuePrepared = false, false
	Spring.SelectUnitArray({})
	Test.clearMap()
end

local function createScenario()
	local centerX = Game.mapSizeX / 2
	local centerZ = Game.mapSizeZ / 2
	local sourceID = assert(Spring.CreateUnit("armfig", centerX, 450, centerZ, "east", 0))
	local targetA = assert(Spring.CreateUnit("corhurc", centerX + 2800, 500, centerZ - 150, "west", 1))
	local targetB = assert(Spring.CreateUnit("corhurc", centerX + 3200, 500, centerZ + 150, "west", 1))
	local setTargetID = assert(Spring.CreateUnit("corhurc", centerX - 2800, 500, centerZ, "east", 1))
	for _, unitID in ipairs({ targetA, targetB, setTargetID }) do
		Spring.SetUnitArmored(unitID, true, 0)
		Spring.SetUnitAlwaysVisible(unitID, true)
	end
	Spring.GiveOrderToUnit(sourceID, CMD.FIRE_STATE, { 0 }, 0)
	Spring.GiveOrderToUnitArray({ targetA, targetB, setTargetID }, CMD.FIRE_STATE, { 0 }, 0)
	return sourceID, targetA, targetB, setTargetID, centerX, centerZ
end

local function hasSetTarget(sourceID)
	return Spring.GetUnitRulesParam(sourceID, "hasPriorityTarget") ~= nil
end

function test()
	local sourceID, targetA, targetB, setTargetID, centerX, centerZ = SyncedRun(createScenario)
	Test.waitFrames(32)

	-- The Set Target sits outside weapon range on purpose: it must stay listed
	-- (passive) while the Attack list runs, without becoming the weapon target.
	Spring.GiveOrderToUnit(sourceID, GameCMD.UNIT_SET_TARGET, { setTargetID }, 0)
	Test.waitUntil(function()
		return hasSetTarget(sourceID)
	end, 120)

	Spring.SelectUnitArray({ sourceID })
	local areaCommandFilter = Test.prepareWidget("Area Command Filter")
	assert(areaCommandFilter, "Area Command Filter should load")
	areaPrepared = true
	assertEqual(
		areaCommandFilter:CommandNotify(CMD.ATTACK, { centerX + 3000, 500, centerZ, 500 }, {}),
		true,
		"Attack area should create a compact target-list controller"
	)
	Test.waitUntil(function()
		local queue = Spring.GetUnitCommands(sourceID, -1)
		return #queue == 2
			and queue[1].id == CMD.ATTACK
			and queue[2].id == GameCMD.ATTACK_TARGETS
			and queue[2].params[1] < 0
	end, 120)
	local firstTarget = Spring.GetUnitCommands(sourceID, -1)[1].params[1]
	local secondTarget = firstTarget == targetA and targetB or targetA
	Test.restoreWidget("Area Command Filter")
	areaPrepared = false
	areaCommandFilter = nil
	assertEqual(hasSetTarget(sourceID), true, "Set Target should survive the Attack list")

	local commandQueueManager = Test.prepareWidget("Command Queue Manager")
	assert(commandQueueManager, "Command Queue Manager should load")
	queuePrepared = true

	-- Skipping the first target hands the last one over to a plain Attack.
	commandQueueManager.SkipCurrentCommand()
	Test.waitUntil(function()
		local queue = Spring.GetUnitCommands(sourceID, -1)
		return #queue == 1 and queue[1].id == CMD.ATTACK and queue[1].params[1] == secondTarget
	end, 120)
	assertEqual(
		hasSetTarget(sourceID),
		true,
		"skipping to the last target should not touch Set Target (no Stop was issued)"
	)

	-- Skipping the last target: queue length one, so the widget issues Stop.
	commandQueueManager.SkipCurrentCommand()
	Test.waitUntil(function()
		return #Spring.GetUnitCommands(sourceID, -1) == 0
	end, 120)
	Test.waitFrames(2)
	assertEqual(
		Spring.GetUnitRulesParam(sourceID, "unitTargetID"),
		nil,
		"Stop after skipping the last target should clear Set Target like a native queue"
	)
	assertEqual(hasSetTarget(sourceID), false, "Set Target list should be gone after Stop")
	Test.restoreWidget("Command Queue Manager")
	queuePrepared = false
end

return {
	setup = setup,
	test = test,
	cleanup = cleanup,
}
