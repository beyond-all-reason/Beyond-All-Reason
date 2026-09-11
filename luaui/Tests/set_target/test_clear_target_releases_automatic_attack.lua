---@diagnostic disable: assign-type-mismatch, need-check-nil, unnecessary-assert

-- A mobile unit on Fire at Will turns its Set Target into an automatic
-- (internal) Attack command with a timeout of several seconds. Clearing the
-- Set Target must also drop that command, otherwise the unit keeps firing at
-- the cleared target until the timeout expires (#9176).

function setup()
	assert(select(1, Spring.GetTeamInfo(1, false)) ~= nil, "Set Target tests require enemy team 1")
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
	local sourceID = assert(Spring.CreateUnit("armstump", centerX, y, centerZ, "east", 0))
	local range = UnitDefs[Spring.GetUnitDefID(sourceID)].maxWeaponRange
	local targetID = assert(Spring.CreateUnit("armstump", centerX + range * 0.8, y, centerZ, "west", 1))
	local otherID = assert(Spring.CreateUnit("armstump", centerX + range * 0.45, y, centerZ + 60, "west", 1))
	for _, unitID in ipairs({ targetID, otherID }) do
		Spring.SetUnitArmored(unitID, true, 0)
		Spring.MoveCtrl.Enable(unitID)
	end
	Spring.GiveOrderToUnitArray({ targetID, otherID }, CMD.FIRE_STATE, { 0 }, 0)
	Spring.GiveOrderToUnit(sourceID, CMD.FIRE_STATE, { 0 }, 0)
	return sourceID, targetID, otherID
end

local function automaticAttackOn(sourceID, targetID)
	for _, command in ipairs(Spring.GetUnitCommands(sourceID, -1)) do
		if command.id == CMD.ATTACK and command.params[1] == targetID and command.options.internal then
			return true
		end
	end
	return false
end

local function weaponTarget(sourceID)
	local targetType, isUserTarget, target = Spring.GetUnitWeaponTarget(sourceID, 1)
	if targetType == 1 then
		return target, isUserTarget
	end
	return nil, false
end

local function checkRelease(cancelLast)
	local sourceID, targetID, otherID = SyncedRun(createScenario)
	Test.waitFrames(32)

	-- Hold fire while the Set Target is given so no automatic target interferes.
	Spring.GiveOrderToUnit(sourceID, GameCMD.UNIT_SET_TARGET, { targetID }, 0)
	Test.waitUntil(function()
		return Spring.GetUnitRulesParam(sourceID, "unitTargetID") == targetID and weaponTarget(sourceID) == targetID
	end, 120)

	-- On Fire at Will the engine wraps the weapon target into an internal Attack.
	Spring.GiveOrderToUnit(sourceID, CMD.FIRE_STATE, { 2 }, 0)
	Test.waitUntil(function()
		return automaticAttackOn(sourceID, targetID)
	end, 120)
	assertEqual(
		Spring.GetUnitRulesParam(sourceID, "unitTargetID"),
		targetID,
		"the Set Target stays active on Fire at Will"
	)

	Spring.GiveOrderToUnit(sourceID, GameCMD.UNIT_CANCEL_TARGET, cancelLast and { targetID } or {}, 0)
	Test.waitFrames(2)
	assertEqual(Spring.GetUnitRulesParam(sourceID, "unitTargetID"), nil, "Clear Target removes the priority target")
	assertEqual(Spring.GetUnitRulesParam(sourceID, "hasPriorityTarget"), nil, "Clear Target removes the list")
	assertEqual(
		automaticAttackOn(sourceID, targetID),
		false,
		"Clear Target drops the automatic Attack on the cleared target"
	)
	local _, isUserTarget = weaponTarget(sourceID)
	assertEqual(isUserTarget, false, "no user target remains after Clear Target")

	-- The unit is free to pick an opportunity target; it must not be re-issued
	-- an automatic Attack on the cleared target by leftover Set Target state.
	Test.waitFrames(60)
	assertEqual(
		Spring.GetUnitRulesParam(sourceID, "unitTargetID"),
		nil,
		"the cleared target does not come back as priority target"
	)
	assert(Spring.ValidUnitID(otherID), "the other enemy is still there")
end

local function checkExplicitAttack()
	local sourceID, targetID = SyncedRun(createScenario)
	Test.waitFrames(32)
	Spring.GiveOrderToUnit(sourceID, GameCMD.UNIT_SET_TARGET, { targetID }, 0)
	Test.waitUntil(function()
		return Spring.GetUnitRulesParam(sourceID, "unitTargetID") == targetID and weaponTarget(sourceID) == targetID
	end, 120)
	Spring.GiveOrderToUnit(sourceID, CMD.ATTACK, { targetID }, 0)
	Test.waitFrames(2)
	local commandID, options, tag, commandTarget = Spring.GetUnitCurrentCommand(sourceID)
	assertEqual(commandID, CMD.ATTACK, "explicit Attack is current")
	assertEqual(math.bit_and(options, CMD.OPT_INTERNAL), 0, "Attack belongs to the player")
	assertEqual(commandTarget, targetID, "explicit Attack owns the same target")

	Spring.GiveOrderToUnit(sourceID, GameCMD.UNIT_CANCEL_TARGET, {}, 0)
	Test.waitFrames(2)
	local currentID, _, currentTag = Spring.GetUnitCurrentCommand(sourceID)
	assertEqual(currentID, CMD.ATTACK, "Clear Target preserves explicit Attack")
	assertEqual(currentTag, tag, "the original explicit command survives")
	local target, isUserTarget = weaponTarget(sourceID)
	assertEqual(target, targetID, "explicit Attack retains its weapon target")
	assertEqual(isUserTarget, true, "explicit Attack retains user target ownership")
	assertEqual(Spring.GetUnitRulesParam(sourceID, "hasPriorityTarget"), nil, "Set Target list is cleared")
end

function test()
	checkRelease(false)
	Test.clearMap()
	checkRelease(true)
	Test.clearMap()
	checkExplicitAttack()
end

return {
	setup = setup,
	test = test,
	cleanup = cleanup,
}
