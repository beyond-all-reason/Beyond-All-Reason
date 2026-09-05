function skip()
	return Spring.GetGameFrame() <= 0
		or GameCMD.UNIT_SET_TARGET == nil
		or GameCMD.UNIT_CANCEL_TARGET == nil
		or select(1, Spring.GetTeamInfo(1, false)) == nil
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
	local sourceIDs = {}
	for index = 1, 3 do
		sourceIDs[index] = assert(Spring.CreateUnit("armflak", centerX - 100 + index * 50, 0, centerZ, "east", 0))
	end
	local targetIDs = {}
	for index = 1, 11 do
		targetIDs[index] =
			assert(Spring.CreateUnit("corhurc", centerX + 2500 + index * 40, 500, centerZ + index * 30, "west", 1))
		Spring.SetUnitArmored(targetIDs[index], true, 0)
	end
	Spring.GiveOrderToUnitArray(sourceIDs, CMD.FIRE_STATE, { 0 }, 0)
	return sourceIDs, targetIDs
end

local function getTargetListID(unitID)
	return SyncedProxy.gadgetHandler.GG.GetUnitTargetListID(unitID)
end

local function getTargetList(unitID)
	return SyncedProxy.gadgetHandler.GG.GetUnitTargetList(unitID)
end

local function assertTargetList(unitID, expectedTargets, label)
	local entries = getTargetList(unitID)
	assert(entries, label .. " should have a target list")
	assertEqual(#entries, #expectedTargets, label .. " target count")
	for index = 1, #expectedTargets do
		assertEqual(entries[index].target, expectedTargets[index], label .. " target order")
	end
end

local function assertSharedList(unitIDs, label)
	local listID = getTargetListID(unitIDs[1])
	assert(listID, label .. " should have a shared-list ID")
	for index = 2, #unitIDs do
		assertEqual(getTargetListID(unitIDs[index]), listID, label .. " list identity")
	end
	return listID
end

local function waitForListID(unitID, predicate)
	Test.waitFrames(3)
	local listID = getTargetListID(unitID)
	assert(predicate(listID), "target-list ID did not reach the expected state")
	return listID
end

function test()
	local sourceIDs, targetIDs = SyncedRun(createScenario)
	local sourceA, sourceB, sourceC = sourceIDs[1], sourceIDs[2], sourceIDs[3]
	local initialTargets = { targetIDs[1], targetIDs[2], targetIDs[3] }

	Spring.GiveOrderToUnitArray(sourceIDs, GameCMD.UNIT_SET_TARGETS, initialTargets, 0)
	waitForListID(sourceA, function(listID)
		return listID ~= nil
	end)
	local initialListID = assertSharedList(sourceIDs, "initial explicit assignment")
	for index = 1, #sourceIDs do
		assertTargetList(sourceIDs[index], initialTargets, "initial explicit assignment")
	end

	local explicitAppendTargets = { targetIDs[4], targetIDs[5], targetIDs[6] }
	Spring.GiveOrderToUnitArray({ sourceA, sourceB }, GameCMD.UNIT_SET_TARGETS, explicitAppendTargets, CMD.OPT_SHIFT)
	waitForListID(sourceA, function(listID)
		return listID ~= initialListID
	end)
	local appendedListID = assertSharedList({ sourceA, sourceB }, "explicit append")
	assert(appendedListID ~= initialListID, "explicit append should create a replacement list")
	assertEqual(getTargetListID(sourceC), initialListID, "explicit append should preserve the unselected list")
	local appendedTargets = {
		targetIDs[1],
		targetIDs[2],
		targetIDs[3],
		targetIDs[4],
		targetIDs[5],
		targetIDs[6],
	}
	assertTargetList(sourceA, appendedTargets, "explicit append source A")
	assertTargetList(sourceB, appendedTargets, "explicit append source B")
	assertTargetList(sourceC, initialTargets, "explicit append source C")

	local prependTargets = { targetIDs[10], targetIDs[11] }
	Spring.GiveOrderToUnitArray({ sourceA, sourceB }, GameCMD.UNIT_SET_TARGETS, prependTargets, CMD.OPT_META)
	waitForListID(sourceA, function(listID)
		return listID ~= appendedListID
	end)
	local prependedListID = assertSharedList({ sourceA, sourceB }, "explicit prepend")
	assert(prependedListID ~= appendedListID, "explicit prepend should create a replacement list")
	local prependedTargets = {
		targetIDs[10],
		targetIDs[11],
		targetIDs[1],
		targetIDs[2],
		targetIDs[3],
		targetIDs[4],
		targetIDs[5],
		targetIDs[6],
	}
	assertTargetList(sourceA, prependedTargets, "explicit prepend source A")
	assertTargetList(sourceB, prependedTargets, "explicit prepend source B")
	assertTargetList(sourceC, initialTargets, "explicit prepend source C")

	Spring.GiveOrderToUnit(sourceA, GameCMD.UNIT_CANCEL_TARGET, { targetIDs[10] }, 0)
	waitForListID(sourceA, function(listID)
		return listID ~= prependedListID
	end)
	local removedListID = getTargetListID(sourceA)
	assert(removedListID ~= getTargetListID(sourceB), "removing from A should detach it from B")
	local targetsAfterRemoval = {
		targetIDs[11],
		targetIDs[1],
		targetIDs[2],
		targetIDs[3],
		targetIDs[4],
		targetIDs[5],
		targetIDs[6],
	}
	assertTargetList(sourceA, targetsAfterRemoval, "remove source A")
	assertTargetList(sourceB, prependedTargets, "remove source B")

	Spring.GiveOrderToUnit(sourceB, GameCMD.UNIT_CANCEL_TARGET, { targetIDs[10] }, 0)
	waitForListID(sourceB, function(listID)
		return listID == removedListID
	end)
	assertSharedList({ sourceA, sourceB }, "identical removals should share a list again")
	assertTargetList(sourceB, targetsAfterRemoval, "re-shared removal source B")

	Spring.GiveOrderToUnitArray({ sourceA, sourceB }, GameCMD.UNIT_SET_TARGETS, initialTargets, 0)
	waitForListID(sourceA, function(listID)
		return listID == initialListID
	end)
	assertSharedList(sourceIDs, "explicit replace should reuse the initial shared list")
	for index = 1, #sourceIDs do
		assertTargetList(sourceIDs[index], initialTargets, "explicit replace")
	end

	Spring.GiveOrderToUnitArray({ sourceA, sourceB }, GameCMD.UNIT_SET_TARGET, { targetIDs[4] }, CMD.OPT_SHIFT)
	waitForListID(sourceA, function(listID)
		return listID ~= initialListID
	end)
	local legacyListA = getTargetListID(sourceA)
	local legacyListB = getTargetListID(sourceB)
	assert(legacyListA ~= legacyListB, "legacy shifted Set Target should use private growing lists")
	assert(legacyListA ~= initialListID, "legacy source A should detach from the initial list")
	assert(legacyListB ~= initialListID, "legacy source B should detach from the initial list")
	assertEqual(getTargetListID(sourceC), initialListID, "legacy append should preserve the unselected list")
	local legacyTargets = { targetIDs[1], targetIDs[2], targetIDs[3], targetIDs[4] }
	assertTargetList(sourceA, legacyTargets, "legacy append source A")
	assertTargetList(sourceB, legacyTargets, "legacy append source B")
	assertTargetList(sourceC, initialTargets, "legacy append source C")

	Spring.GiveOrderToUnitArray(
		{ sourceA, sourceB },
		GameCMD.UNIT_SET_TARGETS,
		{ targetIDs[5], targetIDs[6] },
		CMD.OPT_SHIFT
	)
	waitForListID(sourceA, function(listID)
		return listID ~= legacyListA
	end)
	local resharedListID = assertSharedList({ sourceA, sourceB }, "explicit append should coalesce legacy lists")
	local resharedTargets = {
		targetIDs[1],
		targetIDs[2],
		targetIDs[3],
		targetIDs[4],
		targetIDs[5],
		targetIDs[6],
	}
	assertTargetList(sourceA, resharedTargets, "re-shared legacy source A")
	assertTargetList(sourceB, resharedTargets, "re-shared legacy source B")

	Spring.GiveOrderToUnit(sourceA, GameCMD.UNIT_SET_TARGET, { targetIDs[7] }, CMD.OPT_SHIFT)
	waitForListID(sourceA, function(listID)
		return listID ~= resharedListID
	end)
	local finalLegacyListA = getTargetListID(sourceA)
	assertEqual(getTargetListID(sourceB), resharedListID, "legacy append to A should preserve B's shared list")
	assertTargetList(sourceA, {
		targetIDs[1],
		targetIDs[2],
		targetIDs[3],
		targetIDs[4],
		targetIDs[5],
		targetIDs[6],
		targetIDs[7],
	}, "legacy copy-on-write source A")
	assertTargetList(sourceB, resharedTargets, "legacy copy-on-write source B")

	Spring.GiveOrderToUnit(sourceB, GameCMD.UNIT_SET_TARGET, { targetIDs[7] }, CMD.OPT_SHIFT)
	Test.waitFrames(2)
	assertEqual(getTargetListID(sourceB), resharedListID, "legacy append should grow an exclusive list in place")
	assert(finalLegacyListA ~= getTargetListID(sourceB), "separate legacy appends should remain private")
	assertTargetList(sourceB, {
		targetIDs[1],
		targetIDs[2],
		targetIDs[3],
		targetIDs[4],
		targetIDs[5],
		targetIDs[6],
		targetIDs[7],
	}, "legacy in-place append source B")
end

return {
	skip = skip,
	setup = setup,
	test = test,
	cleanup = cleanup,
}
