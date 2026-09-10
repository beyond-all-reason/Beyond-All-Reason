---@diagnostic disable: assign-type-mismatch, need-check-nil, unnecessary-assert

-- A crashing aircraft is not an available attack target: weapons refuse it and
-- the engine ends an Attack on it once it notices. The compact list skips such
-- an entry when it hands out the next target, the same way a deleted target is
-- skipped, and the remaining entries stay in order. (Native queues on the
-- release engine only notice a crashing target one SlowUpdate after the order
-- started and stall after their target is made neutral; see the RecoilEngine
-- issue linked from PR #8935, so this test does not compare against them.)

function setup()
	assert(select(1, Spring.GetTeamInfo(1, false)) ~= nil, "target-list tests require enemy team 1")
	Test.clearMap()
end

function cleanup()
	Spring.SelectUnitArray({})
	Test.clearMap()
end

local function createScenario()
	local centerX = Game.mapSizeX / 2
	local centerZ = Game.mapSizeZ / 2
	local y = Spring.GetGroundHeight(centerX, centerZ)
	local sourceID = assert(Spring.CreateUnit("armfig", centerX, y + 400, centerZ, "east", 0))
	local targets = {}
	for index = 1, 3 do
		targets[index] =
			assert(Spring.CreateUnit("corhurc", centerX + 900, y + 500, centerZ - 400 + index * 200, "west", 1))
		Spring.SetUnitArmored(targets[index], true, 0)
	end
	-- Pin the first and last target. The second keeps its own air move type so
	-- SetUnitCrashing works on it; the fighter keeps its move type so its
	-- command AI runs.
	Spring.MoveCtrl.Enable(targets[1])
	Spring.MoveCtrl.Enable(targets[3])
	-- Aircraft spawn landed; a Move order gets the second one airborne.
	Spring.GiveOrderToUnit(targets[2], CMD.MOVE, { centerX + 900, y + 500, centerZ + 2000 }, 0)
	Spring.SetUnitArmored(sourceID, true, 0)
	Spring.GiveOrderToUnit(sourceID, CMD.FIRE_STATE, { 0 }, 0)
	Spring.GiveOrderToUnitArray(targets, CMD.FIRE_STATE, { 0 }, 0)
	return sourceID, targets[1], targets[2], targets[3]
end

local function aircraftState(locals)
	local moveTypeData = Spring.GetUnitMoveTypeData(locals.secondID)
	return moveTypeData and moveTypeData.aircraftState
end

local function startCrashing(locals)
	Spring.SetUnitCrashing(locals.secondID, true)
	local moveTypeData = Spring.GetUnitMoveTypeData(locals.secondID)
	return moveTypeData and moveTypeData.aircraftState
end

local function destroyFirst(locals)
	Spring.DestroyUnit(locals.firstID, false, true)
end

local function attackQueue(unitID)
	local parts = {}
	for _, command in ipairs(Spring.GetUnitCommands(unitID, -1)) do
		if command.id == CMD.ATTACK then
			parts[#parts + 1] = "A" .. command.params[1]
		elseif command.id == GameCMD.ATTACK_TARGETS then
			parts[#parts + 1] = "L"
		else
			parts[#parts + 1] = tostring(command.id)
		end
	end
	return table.concat(parts, " ")
end

function test()
	local sourceID, firstID, secondID, thirdID = SyncedRun(createScenario)
	Test.waitFrames(32)

	Spring.GiveOrderToUnit(sourceID, GameCMD.ATTACK_TARGETS, { firstID, secondID, thirdID }, 0)
	Test.waitUntil(function()
		return attackQueue(sourceID) == "A" .. firstID .. " L"
	end, 120)
	-- Move-type data is only readable from synced code.
	local airborne = false
	for _ = 1, 40 do
		if SyncedRun(aircraftState) == "flying" then
			airborne = true
			break
		end
		Test.waitFrames(10)
	end
	assertEqual(airborne, true, "the second target must take off")

	-- The second target starts crashing while the first is still being attacked.
	assertEqual(SyncedRun(startCrashing), "crashing", "the second target must be crashing")
	Test.waitFrames(20)
	assertEqual(
		attackQueue(sourceID),
		"A" .. firstID .. " L",
		"a crashing entry further down the list changes nothing yet"
	)

	-- When the first target dies the crashing one is skipped: the third target
	-- becomes the plain last Attack in the same frame, exactly like a native queue
	-- whose entry for the dead target vanished.
	SyncedRun(destroyFirst)
	Test.waitUntil(function()
		return attackQueue(sourceID) == "A" .. thirdID
	end, 5)
	Test.waitFrames(30)
	assertEqual(attackQueue(sourceID), "A" .. thirdID, "the crashing target stays skipped")
	assert(Spring.ValidUnitID(secondID), "the crashing target was skipped, not destroyed")
end

return {
	setup = setup,
	test = test,
	cleanup = cleanup,
}
