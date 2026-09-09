---@diagnostic disable: assign-type-mismatch, need-check-nil, unnecessary-assert

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
		sourceIDs[index] = assert(
			Spring.CreateUnit(
				"armflak",
				centerX - 400 + index * 40,
				Spring.GetGroundHeight(centerX, centerZ),
				centerZ,
				"east",
				0
			)
		)
	end
	local targetIDs = {
		assert(Spring.CreateUnit("corhurc", centerX + 3000, 500, centerZ, "west", 1)),
		assert(Spring.CreateUnit("corhurc", centerX - 200, 500, centerZ, "west", 1)),
	}
	Spring.SetUnitArmored(targetIDs[2], true, 0)
	Spring.GiveOrderToUnitArray(sourceIDs, CMD.FIRE_STATE, { 0 }, 0)
	return sourceIDs, targetIDs
end

local function issueInitialTarget(locals)
	Spring.GiveOrderToUnitArray(locals.sourceIDs, locals.setTargetListCommandID, { locals.targetIDs[1] }, 0)
end

local function moveTargetNearSource(locals)
	local sourceX, _, sourceZ = Spring.GetUnitPosition(locals.sourceID)
	Spring.MoveCtrl.Enable(locals.targetID)
	Spring.MoveCtrl.SetPosition(
		locals.targetID,
		sourceX + 100,
		Spring.GetGroundHeight(sourceX + 100, sourceZ) + 200,
		sourceZ
	)
end

local function getTargetListID(unitID)
	return SyncedProxy.gadgetHandler.GG.GetUnitTargetListID(unitID)
end

function test()
	local setTargetCommandID = GameCMD.UNIT_SET_TARGET
	local setTargetListCommandID = GameCMD.UNIT_SET_TARGETS
	local cancelTargetCommandID = GameCMD.UNIT_CANCEL_TARGET
	local sourceIDs, targetIDs = SyncedRun(createScenario)
	SyncedRun(issueInitialTarget)
	Test.waitFrames(5)
	assertEqual(Spring.GetUnitRulesParam(sourceIDs[1], "unitTargetID"), nil, "the initial far target is inactive")
	assertEqual(Spring.GetUnitRulesParam(sourceIDs[3], "unitTargetID"), nil, "all units retain the far list")
	local initialListID = getTargetListID(sourceIDs[1])
	assertEqual(initialListID, getTargetListID(sourceIDs[2]), "the initial explicit list should be shared")
	assertEqual(initialListID, getTargetListID(sourceIDs[3]), "all three units should share the initial list")

	Spring.SelectUnitArray({ sourceIDs[1], sourceIDs[2] })
	local areaCommandFilter = Test.prepareWidget("Area Command Filter")
	assert(areaCommandFilter, "Area Command Filter should load")
	areaCommandFilter.spWorldToScreenCoords = function()
		return 0, 0
	end
	areaCommandFilter.spTraceScreenRay = function()
		return "unit", targetIDs[2]
	end
	local targetX, targetY, targetZ = Spring.GetUnitPosition(targetIDs[2])
	local handled = areaCommandFilter:CommandNotify(
		setTargetCommandID,
		{ targetX, targetY, targetZ, 250 },
		{ alt = true, shift = true }
	)
	assertEqual(handled, true, "S+Alt+drag should use the shared explicit-list command")
	Test.waitUntil(function()
		return Spring.GetUnitRulesParam(sourceIDs[1], "unitTargetID") == targetIDs[2]
			and Spring.GetUnitRulesParam(sourceIDs[2], "unitTargetID") == targetIDs[2]
	end, 120)
	local firstListID = getTargetListID(sourceIDs[1])
	local secondListID = getTargetListID(sourceIDs[2])
	local unselectedListID = getTargetListID(sourceIDs[3])
	assertEqual(firstListID, secondListID, "an explicit one-target append should remain shared")
	assert(
		firstListID ~= unselectedListID,
		string.format(
			"the unselected unit should retain its original shared list (selected=%s, unselected=%s)",
			tostring(firstListID),
			tostring(unselectedListID)
		)
	)
	assertEqual(
		Spring.GetUnitRulesParam(sourceIDs[3], "unitTargetID"),
		nil,
		"appending to a subset must not mutate the unselected unit's list"
	)

	Spring.GiveOrderToUnit(sourceIDs[1], cancelTargetCommandID, { targetIDs[2] }, 0)
	Test.waitUntil(function()
		return Spring.GetUnitRulesParam(sourceIDs[1], "unitTargetID") == nil
	end, 120)
	assertEqual(
		Spring.GetUnitRulesParam(sourceIDs[2], "unitTargetID"),
		targetIDs[2],
		"removing from one unit must not mutate the other subset member's list"
	)

	Test.restoreWidget("Area Command Filter")
	areaCommandFilter = nil
	local sourceID = sourceIDs[1]
	local targetID = targetIDs[1]
	SyncedRun(moveTargetNearSource)
	Test.waitUntil(function()
		return Spring.GetUnitRulesParam(sourceID, "unitTargetID") == targetID
	end, 120)
end

return {
	skip = skip,
	setup = setup,
	test = test,
	cleanup = cleanup,
}
