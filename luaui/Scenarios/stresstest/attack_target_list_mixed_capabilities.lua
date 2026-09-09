---@diagnostic disable: need-check-nil, unnecessary-assert

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
	local submarineID = assert(Spring.CreateUnit("armsub", sourceX, 0, waterZ - 150, "east", 0))
	local shipID = assert(Spring.CreateUnit("armpt", sourceX, 0, waterZ + 150, "east", 0))
	local hoverID = assert(Spring.CreateUnit("armsh", targetX, 0, waterZ - 150, "west", 1))
	local boatID = assert(Spring.CreateUnit("armpt", targetX, 0, waterZ + 150, "west", 1))

	for _, unitID in ipairs({ submarineID, shipID, hoverID, boatID }) do
		Spring.MoveCtrl.Enable(unitID)
	end
	Spring.GiveOrderToUnitArray({ submarineID, shipID, hoverID, boatID }, CMD.FIRE_STATE, { 0 }, 0)

	return submarineID, shipID, hoverID, boatID
end

local function getTargetability(locals)
	local function canAnyWeaponTarget(unitID, targetID)
		local unitDefID = Spring.GetUnitDefID(unitID)
		for weaponNum = 1, #UnitDefs[unitDefID].weapons do
			if Spring.GetUnitWeaponTestTarget(unitID, weaponNum, targetID) then
				return true
			end
		end
		return false
	end

	return canAnyWeaponTarget(locals.submarineID, locals.hoverID),
		canAnyWeaponTarget(locals.submarineID, locals.boatID),
		canAnyWeaponTarget(locals.shipID, locals.hoverID),
		canAnyWeaponTarget(locals.shipID, locals.boatID)
end

local function getTargetList(unitID)
	return SyncedProxy.gadgetHandler.GG.GetUnitAttackTargetList(unitID)
end

local function getTargetListID(unitID)
	return SyncedProxy.gadgetHandler.GG.GetUnitAttackTargetListID(unitID)
end

local function queueStartsWith(unitID, targetID)
	local queue = Spring.GetUnitCommands(unitID, -1)
	return queue
		and #queue == 2
		and queue[1].id == CMD.ATTACK
		and queue[1].params[1] == targetID
		and queue[2].id == GameCMD.ATTACK_TARGETS
		and #queue[2].params == 1
end

function test()
	local submarineID, shipID, hoverID, boatID = SyncedRun(createScenario)
	local subCanTargetHover, subCanTargetBoat, shipCanTargetHover, shipCanTargetBoat = SyncedRun(getTargetability)
	assertEqual(subCanTargetHover, false, "the submarine must not be able to target the hover")
	assertEqual(subCanTargetBoat, true, "the submarine must be able to target the boat")
	assertEqual(shipCanTargetHover, true, "the ship must be able to target the hover")
	assertEqual(shipCanTargetBoat, true, "the ship must be able to target the boat")

	-- Both selected sources receive the exact same input list. Like a native
	-- Attack queue, the compact list keeps every target regardless of which
	-- weapons a unit has; the onlytargetcategory gadget rejects the submarine's
	-- Attack on the hover when the controller issues it, exactly as it rejects
	-- a native Attack order. The submarine therefore skips the hover and ends
	-- on a plain Attack on the boat, the ship starts with the hover.
	Spring.GiveOrderToUnitArray({ submarineID, shipID }, GameCMD.ATTACK_TARGETS, { hoverID, boatID }, 0)
	Test.waitUntil(function()
		return queueStartsWith(shipID, hoverID)
	end, 120)
	Test.waitUntil(function()
		local queue = Spring.GetUnitCommands(submarineID, -1)
		return #queue == 1 and queue[1].id == CMD.ATTACK and queue[1].params[1] == boatID
	end, 120)

	local shipList = getTargetList(shipID)
	local shipListID = getTargetListID(shipID)
	assertEqual(#shipList, 2, "the ship keeps both targets")
	assertEqual(shipList[1].target, hoverID, "the ship preserves the shared input order")
	assertEqual(shipList[2].target, boatID, "the ship retains the boat after the hover")
	assertEqual(getTargetList(submarineID), nil, "the submarine released its list with the last target")

	local shipQueue = Spring.GetUnitCommands(shipID, -1)
	assertEqual(-shipQueue[2].params[1], shipListID, "ship controller list reference")

	-- Advancing the ship must use its own cursor and reveal the boat without
	-- touching the submarine's plain Attack.
	Spring.GiveOrderToUnit(shipID, CMD.REMOVE, { shipQueue[1].tag }, 0)
	Test.waitUntil(function()
		local queue = Spring.GetUnitCommands(shipID, -1)
		return #queue == 1 and queue[1].id == CMD.ATTACK and queue[1].params[1] == boatID
	end, 120)
	local submarineQueue = Spring.GetUnitCommands(submarineID, -1)
	assertEqual(#submarineQueue, 1, "the submarine keeps its single Attack")
	assertEqual(submarineQueue[1].params[1], boatID, "the submarine still attacks the boat")

	Spring.GiveOrderToUnitArray({ submarineID, shipID }, CMD.STOP, {}, 0)
end

return {
	skip = skip,
	setup = setup,
	test = test,
	cleanup = cleanup,
}
