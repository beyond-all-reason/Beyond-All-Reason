---@diagnostic disable: assign-type-mismatch, need-check-nil, unnecessary-assert

-- Cancel Target on the entry a unit is currently firing at must release the
-- weapon target at once. Before the fix the entry left the list but the unit
-- kept firing at it as long as no other listed target was in range (#9176).

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
	local sourceID = assert(Spring.CreateUnit("armflak", centerX, Spring.GetGroundHeight(centerX, centerZ), centerZ, "east", 0))
	local nearID = assert(Spring.CreateUnit("corhurc", centerX + 200, 500, centerZ, "west", 1))
	local farID = assert(Spring.CreateUnit("corhurc", centerX + 3000, 500, centerZ, "west", 1))
	Spring.SetUnitArmored(nearID, true, 0)
	Spring.GiveOrderToUnitArray({ nearID, farID }, CMD.FIRE_STATE, { 0 }, 0)
	Spring.GiveOrderToUnit(sourceID, CMD.FIRE_STATE, { 0 }, 0)
	return sourceID, nearID, farID
end

local function weaponTarget(sourceID)
	local targetType, _, target = Spring.GetUnitWeaponTarget(sourceID, 1)
	if targetType == 1 then
		return target
	end
	return nil
end

local function listedTargets(sourceID)
	local ids = {}
	for _, entry in ipairs(SyncedProxy.gadgetHandler.GG.GetUnitTargetList(sourceID) or {}) do
		ids[#ids + 1] = entry.target
	end
	return table.concat(ids, ",")
end

function test()
	local sourceID, nearID, farID = SyncedRun(createScenario)
	Test.waitFrames(32)

	Spring.GiveOrderToUnit(sourceID, GameCMD.UNIT_SET_TARGET, { farID }, 0)
	Spring.GiveOrderToUnit(sourceID, GameCMD.UNIT_SET_TARGET, { nearID }, CMD.OPT_SHIFT)
	Test.waitUntil(function()
		return Spring.GetUnitRulesParam(sourceID, "unitTargetID") == nearID and weaponTarget(sourceID) == nearID
	end, 120)
	assertEqual(listedTargets(sourceID), farID .. "," .. nearID, "both targets are listed, the near one is active")

	Spring.GiveOrderToUnit(sourceID, GameCMD.UNIT_CANCEL_TARGET, { nearID }, 0)
	Test.waitFrames(2)
	assertEqual(listedTargets(sourceID), tostring(farID), "Cancel Target removes only the cancelled entry")
	assertEqual(Spring.GetUnitRulesParam(sourceID, "unitTargetID"), nil, "the cancelled target is no longer the priority target")
	assertEqual(weaponTarget(sourceID), nil, "the cancelled target is no longer the weapon target")
	assertEqual(Spring.GetUnitRulesParam(sourceID, "hasPriorityTarget"), 1, "the remaining far target keeps the list alive")

	-- It stays released: the far target is out of range, nothing else is listed.
	Test.waitFrames(60)
	assertEqual(weaponTarget(sourceID), nil, "the unit does not resume firing at the cancelled target")
end

return {
	setup = setup,
	test = test,
	cleanup = cleanup,
}
