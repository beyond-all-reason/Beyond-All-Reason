---@diagnostic disable: assign-type-mismatch, need-check-nil, unnecessary-assert

-- A shared Set Target list drops dead and captured targets for every owner at
-- once. When the dropped entry was a unit's active target and nothing else in
-- the list is attackable, that unit must still release the engine target in its
-- next update, like the per-unit lists did. Explicit Cancel Target of the active
-- entry keeps the per-unit behavior as well: the unit moves on to the next
-- attackable listed target in its next update. (When nothing else is attackable
-- the per-unit lists left the cancelled target in place; that sticky behavior is
-- tracked in #9176 and intentionally not changed here.)

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
	local sourceID =
		assert(Spring.CreateUnit("armflak", centerX, Spring.GetGroundHeight(centerX, centerZ), centerZ, "east", 0))
	local farID = assert(Spring.CreateUnit("corhurc", centerX + 3000, 500, centerZ, "west", 1))
	Spring.GiveOrderToUnit(sourceID, CMD.FIRE_STATE, { 0 }, 0)
	Spring.GiveOrderToUnit(farID, CMD.FIRE_STATE, { 0 }, 0)
	return sourceID, farID
end

local function createNearTarget(locals)
	local x, _, z = Spring.GetUnitPosition(locals.sourceID)
	local targetID = assert(Spring.CreateUnit("corhurc", x + 200 + (locals.offset or 0), 500, z, "west", 1))
	Spring.SetUnitArmored(targetID, true, 0)
	Spring.GiveOrderToUnit(targetID, CMD.FIRE_STATE, { 0 }, 0)
	return targetID
end

local function captureTarget(locals)
	Spring.TransferUnit(locals.targetID, 0, false)
end

local function destroyTarget(locals)
	Spring.DestroyUnit(locals.targetID, false, true)
end

local function targetIDs(sourceID)
	local ids = {}
	for _, entry in ipairs(SyncedProxy.gadgetHandler.GG.GetUnitTargetList(sourceID) or {}) do
		ids[#ids + 1] = entry.target
	end
	return ids
end

local function weaponTarget(sourceID)
	local targetType, _, target = Spring.GetUnitWeaponTarget(sourceID, 1)
	if targetType == 1 then
		return target
	end
	return nil
end

local function activeTarget(sourceID)
	return Spring.GetUnitRulesParam(sourceID, "unitTargetID")
end

local function appendTarget(sourceID, targetID)
	Spring.GiveOrderToUnit(sourceID, GameCMD.UNIT_SET_TARGET, { targetID }, CMD.OPT_SHIFT)
	Test.waitUntil(function()
		return activeTarget(sourceID) == targetID and weaponTarget(sourceID) == targetID
	end, 120)
end

function test()
	local sourceID, farID = SyncedRun(createScenario)
	Test.waitFrames(32)
	Spring.GiveOrderToUnit(sourceID, GameCMD.UNIT_SET_TARGET, { farID }, 0)
	Test.waitFrames(20)
	assertEqual(activeTarget(sourceID), nil, "the far target is out of range and stays passive")
	assertEqual(#targetIDs(sourceID), 1, "the far target is listed")

	-- Captured active target: released in the next update, the far target stays listed.
	local targetID = SyncedRun(createNearTarget)
	appendTarget(sourceID, targetID)
	SyncedRun(captureTarget)
	-- The release happens in the unit's own update; the shared list drops the
	-- entry on its slow update at the latest, so allow one more slow-update period.
	Test.waitUntil(function()
		return activeTarget(sourceID) == nil
	end, 120)
	Test.waitFrames(16)
	assertEqual(weaponTarget(sourceID), nil, "the captured target must not stay the weapon target")
	assertEqual(
		table.concat(targetIDs(sourceID), ","),
		tostring(farID),
		"only the far target remains listed after the capture"
	)

	-- Dead active target: same release, same remaining list.
	targetID = SyncedRun(createNearTarget)
	appendTarget(sourceID, targetID)
	SyncedRun(destroyTarget)
	-- The release happens in the unit's own update; the shared list drops the
	-- entry on its slow update at the latest, so allow one more slow-update period.
	Test.waitUntil(function()
		return activeTarget(sourceID) == nil
	end, 120)
	Test.waitFrames(16)
	assertEqual(weaponTarget(sourceID), nil, "the dead target must not stay the weapon target")
	assertEqual(
		table.concat(targetIDs(sourceID), ","),
		tostring(farID),
		"only the far target remains listed after the death"
	)

	-- Cancel Target on the active entry: the next attackable listed target takes over.
	local firstID = SyncedRun(createNearTarget)
	appendTarget(sourceID, firstID)
	local offset = 60
	local secondID = SyncedRun(createNearTarget)
	Spring.GiveOrderToUnit(sourceID, GameCMD.UNIT_SET_TARGET, { secondID }, CMD.OPT_SHIFT)
	Test.waitFrames(20)
	assertEqual(#targetIDs(sourceID), 3, "far, first and second target are listed")
	assertEqual(activeTarget(sourceID), firstID, "the earlier listed target keeps priority")
	Spring.GiveOrderToUnit(sourceID, GameCMD.UNIT_CANCEL_TARGET, { firstID }, 0)
	Test.waitUntil(function()
		return activeTarget(sourceID) == secondID and weaponTarget(sourceID) == secondID
	end, 120)
	assertEqual(
		table.concat(targetIDs(sourceID), ","),
		farID .. "," .. secondID,
		"Cancel Target removes only the cancelled entry"
	)
end

return {
	setup = setup,
	test = test,
	cleanup = cleanup,
}
