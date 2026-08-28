function skip()
	return GameCMD.UNIT_SET_TARGET == nil or select(1, Spring.GetTeamInfo(1, false)) == nil
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
	local sourceID = assert(Spring.CreateUnit("armfig", centerX, 450, centerZ, "east", 0))
	local targetA = assert(Spring.CreateUnit("corhurc", centerX + 250, 500, centerZ - 300, "west", 1))
	local targetB = assert(Spring.CreateUnit("corhurc", centerX + 250, 500, centerZ + 300, "west", 1))
	local targetC = assert(Spring.CreateUnit("corhurc", centerX + 350, 500, centerZ + 100, "west", 1))
	local targetIDs = { targetA, targetB, targetC }
	for index = 1, #targetIDs do
		Spring.SetUnitArmored(targetIDs[index], true, 0)
	end
	Spring.GiveOrderToUnit(sourceID, CMD.FIRE_STATE, { 0 }, 0)
	Spring.GiveOrderToUnitArray(targetIDs, CMD.FIRE_STATE, { 0 }, 0)
	return sourceID, targetA, targetB, targetC, centerX, centerZ
end

function test()
	local sourceID, targetA, targetB, targetC, centerX, centerZ = SyncedRun(createScenario)
	Spring.SelectUnitArray({ sourceID })
	Test.waitUntil(function()
		return #Spring.GetSelectedUnits() == 1
	end, 30)
	local areaCommandFilter = Test.prepareWidget("Area Command Filter")
	assert(areaCommandFilter, "Area Command Filter should load")
	local pointedUnitID = targetA
	areaCommandFilter.spTraceScreenRay = function()
		return "unit", pointedUnitID
	end

	-- Establish the initial priority through the same S+Alt+drag gesture a
	-- player uses. Legacy sends UNIT_SET_TARGET commands; compact builds send one
	-- UNIT_SET_TARGETS command, but both must select A.
	assertEqual(
		areaCommandFilter:CommandNotify(
			GameCMD.UNIT_SET_TARGET,
			{ centerX + 250, 500, centerZ - 300, 100 },
			{ alt = true }
		),
		true,
		"S+Alt+drag should be handled"
	)
	Test.waitUntil(function()
		return Spring.GetUnitRulesParam(sourceID, "unitTargetID") == targetA
	end, 120)

	-- Shift+S+click appends another weapon-priority target without changing A.
	Spring.GiveOrderToUnit(sourceID, GameCMD.UNIT_SET_TARGET, { targetC }, CMD.OPT_SHIFT)
	Test.waitFrames(2)
	assertEqual(Spring.GetUnitRulesParam(sourceID, "unitTargetID"), targetA, "Shift+S+click should append after A")

	local moveX = centerX - 1000
	Spring.GiveOrderToUnit(sourceID, CMD.MOVE, { moveX, Spring.GetGroundHeight(moveX, centerZ), centerZ }, 0)
	Test.waitUntil(function()
		local queue = Spring.GetUnitCommands(sourceID, -1)
		return #queue == 1 and queue[1].id == CMD.MOVE
	end, 120)

	-- Space+S+click is represented by inserting the clicked Set Target at queue
	-- position zero. Legacy replaces the list; the feature commit preserves the
	-- existing A,C chain behind the prepended B.
	Spring.GiveOrderToUnit(sourceID, CMD.INSERT, { 0, GameCMD.UNIT_SET_TARGET, CMD.OPT_META, targetB }, CMD.OPT_ALT)
	Test.waitUntil(function()
		return Spring.GetUnitRulesParam(sourceID, "unitTargetID") == targetB
	end, 120)

	local queue = Spring.GetUnitCommands(sourceID, -1)
	assertEqual(#queue, 1, "Set Target should remain state rather than an engine queue command")
	assertEqual(queue[1].id, CMD.MOVE, "Space+Set Target should preserve the movement command")
	assertEqual(queue[1].params[1], moveX, "Space+Set Target should preserve the movement destination")
	areaCommandFilter = nil

	Spring.GiveOrderToUnit(sourceID, GameCMD.UNIT_CANCEL_TARGET, { targetB }, 0)
	Test.waitUntil(function()
		return Spring.GetUnitRulesParam(sourceID, "unitTargetID") == targetA
	end, 120)
	Spring.GiveOrderToUnit(sourceID, GameCMD.UNIT_CANCEL_TARGET, { targetA }, 0)
	Test.waitUntil(function()
		return Spring.GetUnitRulesParam(sourceID, "unitTargetID") == targetC
	end, 120)

	Spring.Echo("[S chain] behavior=drag,shift-click,space-click,preserve-move")
end

return {
	skip = skip,
	setup = setup,
	test = test,
	cleanup = cleanup,
}
