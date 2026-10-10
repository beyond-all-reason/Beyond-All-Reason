---@diagnostic disable: assign-type-mismatch, need-check-nil, unnecessary-assert

-- A compact Attack list must end in the same state as the native Attack queue
-- it replaces, including targets a unit's weapons cannot engage. The game's
-- onlytargetcategory gadget rejects an Attack on such a target when it is
-- given (a submarine may not attack a hover), so a native queue simply loses
-- that order. The compact list keeps the target like the native input and lets
-- the same rejection skip it when the controller issues it. Two identical
-- submarines receive the same hover and boat targets, one as a compact list
-- and one as native queued Attacks; their queues must stay equal. The
-- rejected entries must also cost no time: the native queue never held them,
-- so the compact list has to reach the boat in the same frame instead of
-- spending one SlowUpdate per rejected entry.

function setup()
	assert(select(1, Spring.GetTeamInfo(1, false)) ~= nil, "target-list tests require enemy team 1")
	Test.clearMap()
end

function cleanup()
	Spring.SelectUnitArray({})
	Test.clearMap()
end

local function createScenario()
	local waterX, waterZ
	for z = 512, Game.mapSizeZ - 512, 512 do
		for x = 512, Game.mapSizeX - 512, 512 do
			if
				Spring.GetGroundHeight(x - 300, z - 150) < -25
				and Spring.GetGroundHeight(x - 300, z + 150) < -25
				and Spring.GetGroundHeight(x + 300, z - 150) < -25
				and Spring.GetGroundHeight(x + 300, z + 150) < -25
			then
				waterX, waterZ = x, z
				break
			end
		end
		if waterX then
			break
		end
	end
	assert(waterX, "the test map must contain a 600x300 deep-water area")

	local sourceX = waterX - 300
	local targetX = waterX + 300
	local compactID = assert(Spring.CreateUnit("armsub", sourceX, 0, waterZ - 150, "east", 0))
	local nativeID = assert(Spring.CreateUnit("armsub", sourceX, 0, waterZ + 150, "east", 0))
	-- Three hovers ahead of the boat: every one of them is rejected for the
	-- submarine, and each rejection must not delay the boat.
	local hoverID = assert(Spring.CreateUnit("armsh", targetX, 0, waterZ - 150, "west", 1))
	local secondHoverID = assert(Spring.CreateUnit("armsh", targetX - 100, 0, waterZ - 150, "west", 1))
	local thirdHoverID = assert(Spring.CreateUnit("armsh", targetX - 200, 0, waterZ - 150, "west", 1))
	local boatID = assert(Spring.CreateUnit("armpt", targetX, 0, waterZ + 150, "west", 1))
	local units = { compactID, nativeID, hoverID, secondHoverID, thirdHoverID, boatID }
	for _, unitID in ipairs(units) do
		Spring.MoveCtrl.Enable(unitID)
	end
	Spring.GiveOrderToUnitArray(units, CMD.FIRE_STATE, { 0 }, 0)
	return compactID, nativeID, hoverID, secondHoverID, thirdHoverID, boatID
end

local function getTargetability(locals)
	local function canTarget(unitID, targetID)
		for weaponNum = 1, #UnitDefs[Spring.GetUnitDefID(unitID)].weapons do
			if Spring.GetUnitWeaponTestTarget(unitID, weaponNum, targetID) then
				return true
			end
		end
		return false
	end
	return canTarget(locals.compactID, locals.hoverID), canTarget(locals.compactID, locals.boatID)
end

local function destroyBoat(locals)
	Spring.DestroyUnit(locals.boatID, false, true)
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

local function weaponTarget(unitID)
	local targetType, _, target = Spring.GetUnitWeaponTarget(unitID, 1)
	return targetType == 1 and target or nil
end

function test()
	local compactID, nativeID, hoverID, secondHoverID, thirdHoverID, boatID = SyncedRun(createScenario)
	Test.waitFrames(32)
	local subCanTargetHover, subCanTargetBoat = SyncedRun(getTargetability)
	assertEqual(subCanTargetHover, false, "the submarine must not be able to target the hover")
	assertEqual(subCanTargetBoat, true, "the submarine must be able to target the boat")

	Spring.GiveOrderToUnit(nativeID, CMD.ATTACK, { hoverID }, 0)
	Spring.GiveOrderToUnit(nativeID, CMD.ATTACK, { secondHoverID }, CMD.OPT_SHIFT)
	Spring.GiveOrderToUnit(nativeID, CMD.ATTACK, { thirdHoverID }, CMD.OPT_SHIFT)
	Spring.GiveOrderToUnit(nativeID, CMD.ATTACK, { boatID }, CMD.OPT_SHIFT)
	Spring.GiveOrderToUnit(compactID, GameCMD.ATTACK_TARGETS, { hoverID, secondHoverID, thirdHoverID, boatID }, 0)

	-- The hover Attacks are rejected for the native queue in the frame the
	-- orders arrive. The compact list must reach the same plain Attack on the
	-- boat in that same frame, not one SlowUpdate per rejected entry later.
	Test.waitUntil(function()
		return attackQueue(nativeID) == "A" .. boatID
	end, 120)
	assertEqual(
		attackQueue(compactID),
		"A" .. boatID,
		"the compact list skips the rejected hovers in the same frame as the native queue"
	)
	Test.waitFrames(60)
	assertEqual(attackQueue(compactID), attackQueue(nativeID), "queues stay equal while attacking the boat")
	assertEqual(weaponTarget(compactID), weaponTarget(nativeID), "weapon targets stay equal")
	for _, skippedID in ipairs({ hoverID, secondHoverID, thirdHoverID }) do
		assertEqual(Spring.ValidUnitID(skippedID), true, "the hovers were skipped, not destroyed")
	end

	SyncedRun(destroyBoat)
	Test.waitUntil(function()
		return attackQueue(nativeID) == "" and attackQueue(compactID) == ""
	end, 120)
	assertEqual(
		select(2, Spring.GetUnitRulesParam(compactID, "hasPriorityTarget")),
		nil,
		"no Set Target state is left behind"
	)
end

return {
	setup = setup,
	test = test,
	cleanup = cleanup,
}
