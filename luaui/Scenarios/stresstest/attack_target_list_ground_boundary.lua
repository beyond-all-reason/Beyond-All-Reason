---@diagnostic disable: need-check-nil

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
	local sourceID =
		assert(Spring.CreateUnit("armstump", centerX, Spring.GetGroundHeight(centerX, centerZ), centerZ, "east", 0))
	local targetIDs = {}
	for index = 1, 4 do
		local x = centerX + 2400
		local z = centerZ + index * 120
		targetIDs[index] = assert(Spring.CreateUnit("corraid", x, Spring.GetGroundHeight(x, z), z, "west", 1))
	end
	Spring.GiveOrderToUnit(sourceID, CMD.FIRE_STATE, { CMD.FIRESTATE_HOLDFIRE }, 0)
	Spring.GiveOrderToUnitArray(targetIDs, CMD.FIRE_STATE, { CMD.FIRESTATE_HOLDFIRE }, 0)

	local groundX = centerX + 1200
	local groundY = Spring.GetGroundHeight(groundX, centerZ)
	return sourceID, targetIDs, groundX, groundY, centerZ
end

function test()
	local attackTargetsCommandID = GameCMD.ATTACK_TARGETS
	local sourceID, targetIDs, groundX, groundY, groundZ = SyncedRun(createScenario)
	Spring.GiveOrderToUnit(sourceID, attackTargetsCommandID, { targetIDs[1], targetIDs[2], targetIDs[3] }, 0)
	Spring.GiveOrderToUnit(sourceID, CMD.ATTACK, { groundX, groundY, groundZ }, { "shift" })
	Spring.GiveOrderToUnit(sourceID, attackTargetsCommandID, { targetIDs[4] }, { "shift" })
	Test.waitFrames(10)
	local queue = Spring.GetUnitCommands(sourceID, -1)
	assertEqual(#queue, 4, "ground attack should separate two compact target lists")
	assertEqual(queue[1].id, CMD.ATTACK, "the first list should execute its first unit target")
	assertEqual(queue[1].params[1], targetIDs[1], "the first list should start at A")
	assertEqual(queue[2].id, attackTargetsCommandID, "the first list should use a compact reference")
	assert(queue[2].params[1] < 0, "the active list should be compact")
	assertEqual(queue[3].id, CMD.ATTACK, "ground attack should remain between the lists")
	assertEqual(#queue[3].params, 3, "ground attack should keep XYZ parameters")
	assertEqual(queue[3].params[1], groundX, "ground attack X")
	assertEqual(queue[3].params[2], groundY, "ground attack Y")
	assertEqual(queue[3].params[3], groundZ, "ground attack Z")
	assertEqual(queue[4].id, attackTargetsCommandID, "D should remain in a second target list")
	assertEqual(queue[4].params[1], targetIDs[4], "D should not join the first priority list")
end

return {
	skip = skip,
	setup = setup,
	test = test,
	cleanup = cleanup,
}
