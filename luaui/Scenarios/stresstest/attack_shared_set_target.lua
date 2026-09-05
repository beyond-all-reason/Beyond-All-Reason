---@diagnostic disable: need-check-nil, unnecessary-assert

function skip()
	return select(1, Spring.GetTeamInfo(1, false)) == nil
end

function setup()
	Test.clearMap()
end

function cleanup()
	Test.restoreWidget("Area Command Filter")
	Spring.SelectUnitArray({})
	Test.clearMap()
end

local function createScenario()
	local centerX = Game.mapSizeX / 2
	local centerZ = Game.mapSizeZ / 2
	local sourceIDs = {}
	for index = 1, 3 do
		sourceIDs[index] = assert(Spring.CreateUnit("armfig", centerX - 200 - index * 40, 450, centerZ, "east", 0))
	end
	local targetA = assert(Spring.CreateUnit("corhurc", centerX + 2600, 500, centerZ - 100, "west", 1))
	local targetB = assert(Spring.CreateUnit("corhurc", centerX + 3000, 500, centerZ + 100, "west", 1))
	local targetC = assert(Spring.CreateUnit("corhurc", centerX + 4000, 500, centerZ - 100, "west", 1))
	local targetD = assert(Spring.CreateUnit("corhurc", centerX + 4400, 500, centerZ + 100, "west", 1))
	local targetIDs = { targetA, targetB, targetC, targetD }
	for index = 1, #targetIDs do
		Spring.SetUnitArmored(targetIDs[index], true, 0)
	end
	Spring.GiveOrderToUnitArray(sourceIDs, CMD.FIRE_STATE, { 0 }, 0)
	Spring.GiveOrderToUnitArray(targetIDs, CMD.FIRE_STATE, { 0 }, 0)
	return sourceIDs, targetA, targetB, targetC, targetD, centerX, centerZ
end

local function assertInitialQueue(sourceID, targetA, targetB, compactEnabled)
	local queue = Spring.GetUnitCommands(sourceID, -1)
	assertEqual(#queue, 2, "A+Alt+drag should represent the two-target attack with two queue entries")
	assertEqual(queue[1].id, CMD.ATTACK, "the first target should be an ordinary Attack command")
	assertEqual(queue[1].params[1], targetA, "the nearest target should be attacked first")
	if compactEnabled then
		assertEqual(queue[2].id, GameCMD.ATTACK_TARGETS, "the remaining targets should use a compact controller")
		assertEqual(#queue[2].params, 1, "the compact controller should contain only a shared-list reference")
		assert(queue[2].params[1] < 0, "the compact controller should reference a stored target list")
	else
		assertEqual(queue[2].id, CMD.ATTACK, "legacy behavior should queue one Attack per target")
		assertEqual(queue[2].params[1], targetB, "legacy behavior should preserve the second target")
	end
	return compactEnabled
end

local function queueStartsWithTarget(sourceID, targetID)
	local queue = Spring.GetUnitCommands(sourceID, -1)
	return queue[1] and queue[1].id == CMD.ATTACK and queue[1].params[1] == targetID
end

function test()
	local sourceIDs, targetA, targetB, targetC, targetD, centerX, centerZ = SyncedRun(createScenario)
	Spring.SelectUnitArray(sourceIDs)
	Test.waitUntil(function()
		return #Spring.GetSelectedUnits() == #sourceIDs
	end, 30)

	local areaCommandFilter = Test.prepareWidget("Area Command Filter")
	assert(areaCommandFilter, "Area Command Filter should load")
	-- Model the player's cursor being over target A while releasing A+Alt+drag.
	areaCommandFilter.spTraceScreenRay = function()
		return "unit", targetA
	end

	assertEqual(
		areaCommandFilter:CommandNotify(CMD.ATTACK, { centerX + 2800, 500, centerZ, 600 }, { alt = true }),
		true,
		"A+Alt+drag should be handled"
	)
	Test.waitUntil(function()
		return #Spring.GetUnitCommands(sourceIDs[1], -1) == 2
	end, 120)

	local compactEnabled = Spring.GetUnitCommands(sourceIDs[1], -1)[2].id == GameCMD.ATTACK_TARGETS
	for index = 1, #sourceIDs do
		assertEqual(
			assertInitialQueue(sourceIDs[index], targetA, targetB, compactEnabled),
			compactEnabled,
			"all sources should use the same queue representation"
		)
	end

	-- Continue the player's chain with Shift+A+click and Space+A+click. The
	-- compact controller may remain inside the queue, but target order must be
	-- D, A, B, C in both representations.
	Spring.GiveOrderToUnitArray(sourceIDs, CMD.ATTACK, { targetC }, CMD.OPT_SHIFT)
	for index = 1, #sourceIDs do
		Spring.GiveOrderToUnit(sourceIDs[index], CMD.INSERT, { 0, CMD.ATTACK, 0, targetD }, CMD.OPT_ALT)
	end
	Test.waitUntil(function()
		for index = 1, #sourceIDs do
			local queue = Spring.GetUnitCommands(sourceIDs[index], -1)
			local expectedQueueLength = compactEnabled and 2 or 4
			if #queue ~= expectedQueueLength or not queueStartsWithTarget(sourceIDs[index], targetD) then
				return false
			end
			if compactEnabled then
				if queue[2].id ~= GameCMD.ATTACK_TARGETS then
					return false
				end
			elseif
				queue[2].params[1] ~= targetA
				or queue[3].params[1] ~= targetB
				or queue[4].id ~= CMD.ATTACK
				or queue[4].params[1] ~= targetC
			then
				return false
			end
		end
		return true
	end, 120)

	local expectedOrder = { targetD, targetA, targetB, targetC }
	for targetIndex = 1, #expectedOrder do
		local expectedTargetID = expectedOrder[targetIndex]
		Test.waitUntil(function()
			for sourceIndex = 1, #sourceIDs do
				if not queueStartsWithTarget(sourceIDs[sourceIndex], expectedTargetID) then
					return false
				end
			end
			return true
		end, 120)
		if targetIndex < #expectedOrder then
			for sourceIndex = 1, #sourceIDs do
				local firstAttackTag = Spring.GetUnitCommands(sourceIDs[sourceIndex], -1)[1].tag
				Spring.GiveOrderToUnit(sourceIDs[sourceIndex], CMD.REMOVE, { firstAttackTag }, 0)
			end
		end
	end

	Spring.GiveOrderToUnitArray(sourceIDs, CMD.STOP, {}, 0)
	Test.waitUntil(function()
		for index = 1, #sourceIDs do
			if #Spring.GetUnitCommands(sourceIDs[index], -1) ~= 0 then
				return false
			end
		end
		return true
	end, 120)
	Spring.Echo(
		string.format(
			"[A chain] representation=%s behavior=drag,shift-click,space-click,ordered-progress,stop",
			compactEnabled and "compact ATTACK_TARGETS" or "legacy Attack list"
		)
	)
end

return {
	skip = skip,
	setup = setup,
	test = test,
	cleanup = cleanup,
}
