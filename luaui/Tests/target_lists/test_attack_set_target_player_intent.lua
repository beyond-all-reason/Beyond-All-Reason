---@diagnostic disable: assign-type-mismatch, need-check-nil, unnecessary-assert

function setup()
	assert(select(1, Spring.GetTeamInfo(1, false)) ~= nil, "target-list tests require enemy team 1")
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
	local sourceID = assert(Spring.CreateUnit("armflak", centerX, 0, centerZ, "east", 0))
	local attackA = assert(Spring.CreateUnit("corhurc", centerX + 2600, 500, centerZ - 100, "west", 1))
	local attackB = assert(Spring.CreateUnit("corhurc", centerX + 3000, 500, centerZ + 100, "west", 1))
	local setTargetA = assert(Spring.CreateUnit("corhurc", centerX + 250, 200, centerZ - 80, "west", 1))
	local setTargetB = assert(Spring.CreateUnit("corhurc", centerX + 350, 200, centerZ + 80, "west", 1))
	Spring.SetUnitArmored(attackA, true, 0)
	Spring.SetUnitArmored(attackB, true, 0)
	Spring.SetUnitArmored(setTargetA, true, 0)
	Spring.SetUnitArmored(setTargetB, true, 0)
	Spring.GiveOrderToUnit(sourceID, CMD.FIRE_STATE, { 0 }, 0)
	Spring.GiveOrderToUnitArray({ attackA, attackB, setTargetA, setTargetB }, CMD.FIRE_STATE, { 0 }, 0)
	return sourceID, attackA, attackB, setTargetA, setTargetB, centerX, centerZ
end

local function attackQueueStartsWith(sourceID, targetID)
	local queue = Spring.GetUnitCommands(sourceID, -1)
	return #queue == 2
		and queue[1].id == CMD.ATTACK
		and queue[1].params[1] == targetID
		and (queue[2].id == CMD.ATTACK or (queue[2].id == GameCMD.ATTACK_TARGETS and queue[2].params[1] < 0))
end

function test()
	local sourceID, attackA, attackB, setTargetA, setTargetB, centerX, centerZ = SyncedRun(createScenario)
	Spring.SelectUnitArray({ sourceID })
	Test.waitUntil(function()
		return #Spring.GetSelectedUnits() == 1
	end, 30)

	local areaCommandFilter = Test.prepareWidget("Area Command Filter")
	assert(areaCommandFilter, "Area Command Filter should load")
	local pointedUnitID = attackA
	areaCommandFilter.spTraceScreenRay = function()
		return "unit", pointedUnitID
	end

	-- Assign S first: starting A must retain this separate priority list.
	Spring.GiveOrderToUnit(sourceID, GameCMD.UNIT_SET_TARGET, { setTargetB }, 0)
	Test.waitUntil(function()
		return Spring.GetUnitRulesParam(sourceID, "unitTargetID") == setTargetB
	end, 120)

	-- Player queues an ordered attack list with A+Alt+drag.
	assertEqual(
		areaCommandFilter:CommandNotify(CMD.ATTACK, { centerX + 2800, 500, centerZ, 600 }, { alt = true }),
		true,
		"A+Alt+drag should be handled"
	)
	Test.waitUntil(function()
		return attackQueueStartsWith(sourceID, attackA)
	end, 120)

	assertEqual(
		Spring.GetUnitRulesParam(sourceID, "unitTargetID"),
		setTargetB,
		"starting Attack must preserve Set Target"
	)
	Spring.GiveOrderToUnit(sourceID, GameCMD.UNIT_CANCEL_TARGET, {}, 0)
	Test.waitUntil(function()
		return Spring.GetUnitRulesParam(sourceID, "hasPriorityTarget") == nil
	end, 120)
	assert(attackQueueStartsWith(sourceID, attackA), "Cancel Target must preserve Attack")

	-- While that movement queue remains active, the player assigns a weapon
	-- priority list with S+Alt+drag over a different group.
	pointedUnitID = setTargetA
	assertEqual(
		areaCommandFilter:CommandNotify(GameCMD.UNIT_SET_TARGET, { centerX + 300, 200, centerZ, 250 }, { alt = true }),
		true,
		"S+Alt+drag should be handled"
	)
	Test.waitUntil(function()
		return Spring.GetUnitRulesParam(sourceID, "unitTargetID") == setTargetA
			and attackQueueStartsWith(sourceID, attackA)
	end, 120)
	areaCommandFilter = nil

	-- Skipping the first Attack target must preserve the independently assigned
	-- Set Target state.
	local firstAttackTag = Spring.GetUnitCommands(sourceID, -1)[1].tag
	Spring.GiveOrderToUnit(sourceID, CMD.REMOVE, { firstAttackTag }, 0)
	Test.waitUntil(function()
		local queue = Spring.GetUnitCommands(sourceID, -1)
		local advanced = queue[1]
			and queue[1].id == CMD.ATTACK
			and queue[1].params[1] == attackB
			and (#queue == 1 or (#queue == 2 and queue[2].id == GameCMD.ATTACK_TARGETS))
		return advanced and Spring.GetUnitRulesParam(sourceID, "unitTargetID") == setTargetA
	end, 120)

	local lastAttackTag = Spring.GetUnitCommands(sourceID, -1)[1].tag
	Spring.GiveOrderToUnit(sourceID, CMD.REMOVE, { lastAttackTag }, 0)
	Test.waitUntil(function()
		return #Spring.GetUnitCommands(sourceID, -1) == 0
	end, 120)
	assertEqual(
		Spring.GetUnitRulesParam(sourceID, "unitTargetID"),
		setTargetA,
		"finishing Attack must preserve Set Target"
	)

	Spring.Echo("[A then S player intent] behavior=independent")
end

return {
	setup = setup,
	test = test,
	cleanup = cleanup,
}
