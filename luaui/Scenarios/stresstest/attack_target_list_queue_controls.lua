---@diagnostic disable: assign-type-mismatch, need-check-nil, unnecessary-assert

function skip()
	return select(1, Spring.GetTeamInfo(1, false)) == nil
end

function setup()
	Test.clearMap()
end

function cleanup()
	Spring.SelectUnitArray({})
	Test.clearMap()
end

local function createScenario()
	local centerX = Game.mapSizeX / 2
	local centerZ = Game.mapSizeZ / 2
	local sourceID = assert(Spring.CreateUnit("armfig", centerX, 450, centerZ, "east", 0))
	local targetA = assert(Spring.CreateUnit("corhurc", centerX + 2800, 500, centerZ - 150, "west", 1))
	local targetB = assert(Spring.CreateUnit("corhurc", centerX + 3200, 500, centerZ + 150, "west", 1))
	Spring.SetUnitArmored(targetA, true, 0)
	Spring.SetUnitArmored(targetB, true, 0)
	Spring.GiveOrderToUnit(sourceID, CMD.FIRE_STATE, { 0 }, 0)
	Spring.GiveOrderToUnitArray({ targetA, targetB }, CMD.FIRE_STATE, { 0 }, 0)
	return sourceID, targetA, targetB, centerX, centerZ
end

local function queueMatches(sourceID, targetID, controllerReference, moveX)
	local queue = Spring.GetUnitCommands(sourceID, -1)
	return #queue == 3
		and queue[1].id == CMD.ATTACK
		and queue[1].params[1] == targetID
		and queue[2].id == GameCMD.ATTACK_TARGETS
		and queue[2].params[1] == controllerReference
		and queue[3].id == CMD.MOVE
		and queue[3].params[1] == moveX
end

function test()
	local sourceID, targetA, targetB, centerX, centerZ = SyncedRun(createScenario)
	local moveX = centerX - 1000
	Spring.GiveOrderToUnit(sourceID, CMD.MOVE, { moveX, Spring.GetGroundHeight(moveX, centerZ), centerZ }, 0)
	Test.waitUntil(function()
		local queue = Spring.GetUnitCommands(sourceID, -1)
		return #queue == 1 and queue[1].id == CMD.MOVE
	end, 120)

	Spring.SelectUnitArray({ sourceID })
	local areaCommandFilter = Test.prepareWidget("Area Command Filter")
	assert(areaCommandFilter, "Area Command Filter should load")
	assertEqual(
		areaCommandFilter:CommandNotify(CMD.ATTACK, { centerX + 3000, 500, centerZ, 500 }, { meta = true }),
		true,
		"Space+Attack should prepend a compact target-list controller"
	)
	Test.waitUntil(function()
		local queue = Spring.GetUnitCommands(sourceID, -1)
		return #queue == 3
			and queue[1].id == CMD.ATTACK
			and queue[1].params[1] == targetA
			and queue[2].id == GameCMD.ATTACK_TARGETS
			and queue[2].params[1] < 0
			and queue[3].id == CMD.MOVE
	end, 120)
	local controllerReference = Spring.GetUnitCommands(sourceID, -1)[2].params[1]
	Test.restoreWidget("Area Command Filter")
	areaCommandFilter = nil
	Spring.GiveOrderToUnit(sourceID, CMD.MOVE_STATE, { CMD.MOVESTATE_HOLDPOS }, 0)
	Test.waitUntil(function()
		return queueMatches(sourceID, targetA, controllerReference, moveX)
	end, 120)

	local commandQueueManager = Test.prepareWidget("Command Queue Manager")
	assert(commandQueueManager, "Command Queue Manager should load")
	commandQueueManager.SkipCurrentCommand()
	Test.waitUntil(function()
		return queueMatches(sourceID, targetB, controllerReference, moveX)
	end, 120)

	commandQueueManager.SkipCurrentCommand()
	Test.waitUntil(function()
		local queue = Spring.GetUnitCommands(sourceID, -1)
		return #queue == 1 and queue[1].id == CMD.MOVE and queue[1].params[1] == moveX
	end, 120)
	Test.restoreWidget("Command Queue Manager")
end

return {
	skip = skip,
	setup = setup,
	test = test,
	cleanup = cleanup,
}
