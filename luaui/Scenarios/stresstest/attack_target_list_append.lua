---@diagnostic disable: assign-type-mismatch, need-check-nil, unnecessary-assert

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
	local centerX = Game.mapSizeX / 2
	local centerZ = Game.mapSizeZ / 2
	local sourceIDs = {}
	for index = 1, 3 do
		sourceIDs[index] = assert(
			Spring.CreateUnit(
				"armflak",
				centerX - 40 + index * 40,
				Spring.GetGroundHeight(centerX, centerZ),
				centerZ,
				0,
				0
			)
		)
	end
	local areaAX = centerX + 3000
	local areaAZ = centerZ - 1000
	local areaBX = centerX + 3000
	local areaBZ = centerZ + 1000
	local targetA = assert(Spring.CreateUnit("corhurc", areaAX, 500, areaAZ, 0, 1))
	local targetB = assert(Spring.CreateUnit("corhurc", areaBX, 500, areaBZ, 0, 1))
	local targetC = assert(Spring.CreateUnit("corhurc", centerX + 3400, 500, centerZ - 300, 0, 1))
	local targetD = assert(Spring.CreateUnit("corhurc", centerX + 3400, 500, centerZ + 300, 0, 1))
	Spring.SetUnitArmored(targetA, true, 0)
	Spring.SetUnitArmored(targetB, true, 0)
	Spring.SetUnitArmored(targetC, true, 0)
	Spring.SetUnitArmored(targetD, true, 0)
	Spring.GiveOrderToUnitArray(sourceIDs, CMD.FIRE_STATE, { 0 }, 0)
	return sourceIDs, targetA, targetB, targetC, targetD, areaAX, areaAZ
end

local function moveTarget(locals)
	local sourceX, _, sourceZ = Spring.GetUnitPosition(locals.sourceID)
	local x = sourceX + locals.offset
	local z = sourceZ + locals.zOffset
	Spring.MoveCtrl.Enable(locals.targetID)
	Spring.MoveCtrl.SetPosition(locals.targetID, x, Spring.GetGroundHeight(x, z) + 200, z)
end

local function getWeaponTargetability(locals)
	return Spring.GetUnitWeaponTryTarget(locals.sourceID, 1, locals.targetA),
		Spring.GetUnitWeaponTryTarget(locals.sourceID, 1, locals.targetB)
end

function test()
	local sourceIDs, targetA, targetB, targetC, targetD, areaAX, areaAZ = SyncedRun(createScenario)
	local sourceID = sourceIDs[1]
	Spring.Echo(string.format("[Attack Target Append] source=%d A=%d B=%d", sourceID, targetA, targetB))
	Spring.SelectUnitArray(sourceIDs)
	Test.waitUntil(function()
		return #Spring.GetSelectedUnits() == #sourceIDs
	end, 30)
	local areaCommandFilter = Test.prepareWidget("Area Command Filter")
	assert(areaCommandFilter, "Area Command Filter should load")

	assertEqual(
		areaCommandFilter:CommandNotify(CMD.ATTACK, { areaAX, 0, areaAZ, 200 }, {}),
		true,
		"the first attack area should use a compact controller"
	)
	Test.waitUntil(function()
		local queue = Spring.GetUnitCommands(sourceID, -1)
		return #queue == 2 and queue[1].id == CMD.ATTACK and queue[2].id == GameCMD.ATTACK_TARGETS
	end, 120)
	local controllerReference = Spring.GetUnitCommands(sourceID, -1)[2].params[1]
	Test.restoreWidget("Area Command Filter")
	areaCommandFilter = nil

	local targetID = targetA
	local offset = 300
	local zOffset = 0
	SyncedRun(moveTarget)
	Test.waitFrames(15)
	assertEqual(Spring.GetUnitRulesParam(sourceID, "unitTargetID"), nil, "A should only be an Engine Attack target")

	-- The player extends the chain with Shift+A+click. Absorb the ordinary
	-- Attack into the target list instead of growing the engine command queue.
	Spring.GiveOrderToUnitArray(sourceIDs, CMD.ATTACK, { targetB }, CMD.OPT_SHIFT)
	Test.waitUntil(function()
		local queue = Spring.GetUnitCommands(sourceID, -1)
		return #queue == 2 and queue[2].params[1] == controllerReference
	end, 120)

	targetID = targetB
	offset = 50
	zOffset = 100
	SyncedRun(moveTarget)
	Test.waitFrames(30)
	local targetAIsValid, targetBIsValid = SyncedRun(getWeaponTargetability)
	Spring.Echo(
		string.format("[Attack Target Append] targetable A=%s B=%s", tostring(targetAIsValid), tostring(targetBIsValid))
	)
	assertEqual(targetAIsValid, true, "A must remain a valid weapon target for the priority assertion")
	assertEqual(targetBIsValid, true, "B must be a valid weapon target for the priority assertion")
	assertEqual(
		Spring.GetUnitRulesParam(sourceID, "unitTargetID"),
		nil,
		"the appended target should not become Set Target"
	)

	-- Repeated Space+A+clicks restart the controller from the new list head
	-- without adding commands to the engine queue.
	for _, prependedTargetID in ipairs({ targetC, targetD }) do
		for index = 1, #sourceIDs do
			Spring.GiveOrderToUnit(sourceIDs[index], CMD.INSERT, { 0, CMD.ATTACK, 0, prependedTargetID }, CMD.OPT_ALT)
		end
	end
	Test.waitUntil(function()
		for index = 1, #sourceIDs do
			local queue = Spring.GetUnitCommands(sourceIDs[index], -1)
			if #queue ~= 2 or queue[1].id ~= CMD.ATTACK or queue[1].params[1] ~= targetD then
				return false
			end
		end
		return true
	end, 120)

	local expectedOrder = { targetD, targetC, targetA, targetB }
	for index = 1, #expectedOrder do
		local expectedTargetID = expectedOrder[index]
		Test.waitUntil(function()
			for sourceIndex = 1, #sourceIDs do
				local queue = Spring.GetUnitCommands(sourceIDs[sourceIndex], -1)
				if
					#queue ~= 2
					or queue[1].id ~= CMD.ATTACK
					or queue[1].params[1] ~= expectedTargetID
					or queue[2].id ~= GameCMD.ATTACK_TARGETS
				then
					return false
				end
			end
			return true
		end, 120)
		if index < #expectedOrder then
			for sourceIndex = 1, #sourceIDs do
				local firstAttackTag = Spring.GetUnitCommands(sourceIDs[sourceIndex], -1)[1].tag
				Spring.GiveOrderToUnit(sourceIDs[sourceIndex], CMD.REMOVE, { firstAttackTag }, 0)
			end
		end
	end

	Spring.GiveOrderToUnitArray(sourceIDs, CMD.STOP, {}, 0)
end

return {
	skip = skip,
	setup = setup,
	test = test,
	cleanup = cleanup,
}
