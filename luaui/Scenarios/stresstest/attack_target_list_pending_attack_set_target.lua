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
	local sourceDefID = UnitDefNames.armfboy.id
	local weaponRange = UnitDefs[sourceDefID].maxWeaponRange
	local sourceX = Game.mapSizeX / 2 - 1000
	local sourceZ = Game.mapSizeZ / 2
	local sourceID =
		assert(Spring.CreateUnit("armfboy", sourceX, Spring.GetGroundHeight(sourceX, sourceZ), sourceZ, "east", 0))

	-- This reproduces the replay's important state: the first list entry owns
	-- movement through an Attack command but cannot be assigned to the weapon
	-- yet, while a later entry is already targetable.
	local firstX = sourceX + weaponRange + 900
	local firstZ = sourceZ
	local fallbackX = sourceX + weaponRange * 0.55
	local fallbackZ = sourceZ + 100
	local firstTargetID =
		assert(Spring.CreateUnit("armfboy", firstX, Spring.GetGroundHeight(firstX, firstZ), firstZ, "west", 1))
	local fallbackTargetID = assert(
		Spring.CreateUnit("armfboy", fallbackX, Spring.GetGroundHeight(fallbackX, fallbackZ), fallbackZ, "west", 1)
	)

	Spring.SetUnitMaxHealth(firstTargetID, 100000)
	Spring.SetUnitHealth(firstTargetID, 100000)
	Spring.SetUnitMaxHealth(fallbackTargetID, 100000)
	Spring.SetUnitHealth(fallbackTargetID, 100000)
	Spring.SetUnitArmored(firstTargetID, true, 0)
	Spring.SetUnitArmored(fallbackTargetID, true, 0)
	Spring.GiveOrderToUnit(sourceID, CMD.FIRE_STATE, { CMD.FIRESTATE_FIREATWILL }, 0)
	Spring.GiveOrderToUnitArray({ firstTargetID, fallbackTargetID }, CMD.FIRE_STATE, { CMD.FIRESTATE_HOLDFIRE }, 0)
	Spring.GiveOrderToUnitArray({ firstTargetID, fallbackTargetID }, CMD.MOVE_STATE, { CMD.MOVESTATE_HOLDPOS }, 0)

	return sourceID, firstTargetID, fallbackTargetID
end

local function getTargetState(locals)
	local targetType, isUserTarget, weaponTargetID = Spring.GetUnitWeaponTarget(locals.sourceID, 1)
	return {
		firstTargetable = Spring.GetUnitWeaponTryTarget(locals.sourceID, 1, locals.firstTargetID),
		fallbackTargetable = Spring.GetUnitWeaponTryTarget(locals.sourceID, 1, locals.fallbackTargetID),
		targetType = targetType,
		isUserTarget = isUserTarget,
		weaponTargetID = weaponTargetID,
	}
end

function test()
	local sourceID, firstTargetID, fallbackTargetID = SyncedRun(createScenario)

	Spring.GiveOrderToUnit(sourceID, GameCMD.ATTACK_TARGETS, { firstTargetID, fallbackTargetID }, 0)
	Test.waitUntil(function()
		local queue = Spring.GetUnitCommands(sourceID, -1)
		return #queue == 2
			and queue[1].id == CMD.ATTACK
			and queue[1].params[1] == firstTargetID
			and queue[2].id == GameCMD.ATTACK_TARGETS
	end, 120)

	local initialState = SyncedRun(getTargetState)
	assertEqual(initialState.firstTargetable, false, "the first Attack target should not be weapon-targetable yet")
	assertEqual(initialState.fallbackTargetable, true, "the fallback target should be weapon-targetable")

	-- Cross several target-list slow updates. With weapon fallbacks disabled,
	-- the remaining compact list must never become an explicit Set Target.
	Test.waitFrames(45)
	local queue = Spring.GetUnitCommands(sourceID, -1)
	local retainedState = SyncedRun(getTargetState)
	assertEqual(queue[1].id, CMD.ATTACK, "Attack should remain the active movement command")
	assertEqual(queue[1].params[1], firstTargetID, "the first target should remain the movement target")
	assertEqual(retainedState.firstTargetable, false, "the first target should still be pending")
	assertEqual(
		Spring.GetUnitRulesParam(sourceID, "unitTargetID"),
		nil,
		"the remaining target list should not become Set Target"
	)
	assertEqual(retainedState.isUserTarget == true, false, "the remaining list should not assign a user weapon target")

	Spring.GiveOrderToUnit(sourceID, CMD.STOP, {}, 0)
end

return {
	skip = skip,
	setup = setup,
	test = test,
	cleanup = cleanup,
}
