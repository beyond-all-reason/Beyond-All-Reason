---@diagnostic disable: assign-type-mismatch, need-check-nil

function skip()
	return Spring.GetGameFrame() <= 0 or select(1, Spring.GetTeamInfo(1, false)) == nil
end

function setup()
	Test.clearMap()
end

function cleanup()
	local enabled = true
	SyncedRun(setGlobalLos)
	Spring.SelectUnitArray({})
	Test.clearMap()
end

local function createScenario()
	local centerX = Game.mapSizeX / 2
	local centerZ = Game.mapSizeZ / 2
	local sourceIDs = {}
	for index = 1, 32 do
		sourceIDs[index] = assert(Spring.CreateUnit("armflak", centerX - 400 + index * 12, 0, centerZ, "east", 0))
	end

	local targetIDs = {
		assert(Spring.CreateUnit("corhurc", centerX + 100, 150, centerZ, "west", 1)),
		assert(Spring.CreateUnit("corhurc", centerX + 130, 150, centerZ, "west", 1)),
	}
	for index = 3, 8 do
		targetIDs[index] = assert(Spring.CreateUnit("corhurc", centerX + 3000, 300, centerZ + index * 60, "west", 1))
	end
	Spring.GiveOrderToUnitArray(sourceIDs, CMD.FIRE_STATE, { 0 }, 0)
	Spring.GiveOrderToUnitArray(targetIDs, CMD.FIRE_STATE, { 0 }, 0)
	return sourceIDs, targetIDs
end

function setGlobalLos(locals)
	Spring.SetGlobalLos(0, locals.enabled)
end

local function destroyTarget(locals)
	Spring.DestroyUnit(locals.targetID, false, true)
end

local function captureUnit(locals)
	Spring.TransferUnit(locals.unitID, locals.newTeam, false)
end

local function moveTargetNearSources(locals)
	local x, _, z = Spring.GetUnitPosition(locals.sourceID)
	Spring.MoveCtrl.Enable(locals.targetID)
	Spring.MoveCtrl.SetPosition(locals.targetID, x + 100, Spring.GetGroundHeight(x + 100, z) + 150, z)
end

local function moveTargetOutOfSight(locals)
	local x, _, z = Spring.GetUnitPosition(locals.sourceID)
	Spring.MoveCtrl.Enable(locals.targetID)
	Spring.MoveCtrl.SetPosition(locals.targetID, x + 3000, Spring.GetGroundHeight(x + 3000, z) + 300, z)
end

function test()
	local sourceIDs, targetIDs = SyncedRun(createScenario)
	Spring.GiveOrderToUnitArray(sourceIDs, GameCMD.UNIT_SET_TARGETS, targetIDs, 0)
	Test.waitUntil(function()
		return Spring.GetUnitRulesParam(sourceIDs[1], "unitTargetID") == targetIDs[1]
			and Spring.GetUnitRulesParam(sourceIDs[#sourceIDs], "unitTargetID") == targetIDs[1]
	end, 120)

	local unitID = sourceIDs[1]
	local newTeam = 1
	SyncedRun(captureUnit)
	Test.waitUntil(function()
		return Spring.GetUnitRulesParam(sourceIDs[1], "unitTargetID") == nil
			and Spring.GetUnitRulesParam(sourceIDs[2], "unitTargetID") == targetIDs[1]
			and Spring.GetUnitRulesParam(sourceIDs[#sourceIDs], "unitTargetID") == targetIDs[1]
	end, 120)

	local targetID = targetIDs[1]
	SyncedRun(destroyTarget)
	Test.waitUntil(function()
		return Spring.GetUnitRulesParam(sourceIDs[2], "unitTargetID") == targetIDs[2]
			and Spring.GetUnitRulesParam(sourceIDs[#sourceIDs], "unitTargetID") == targetIDs[2]
	end, 120)

	local _, _, _, _, _, _, syncedMemoryBefore = Spring.GetLuaMemUsage()
	newTeam = 0
	unitID = targetIDs[2]
	SyncedRun(captureUnit)
	Test.waitUntil(function()
		return Spring.GetUnitRulesParam(sourceIDs[2], "unitTargetID") == nil
			and Spring.GetUnitRulesParam(sourceIDs[#sourceIDs], "unitTargetID") == nil
	end, 120)

	local enabled = false
	SyncedRun(setGlobalLos)
	Test.waitFrames(20)
	local sourceID = sourceIDs[2]
	targetID = targetIDs[3]
	SyncedRun(moveTargetNearSources)
	Test.waitUntil(function()
		return Spring.GetUnitRulesParam(sourceIDs[2], "unitTargetID") == targetID
			and Spring.GetUnitRulesParam(sourceIDs[#sourceIDs], "unitTargetID") == targetID
	end, 120)
	SyncedRun(moveTargetOutOfSight)
	-- Return before the documented two-second (60-frame) unseen grace expires.
	Test.waitFrames(30)
	SyncedRun(moveTargetNearSources)
	Test.waitUntil(function()
		return Spring.GetUnitRulesParam(sourceIDs[2], "unitTargetID") == targetID
			and Spring.GetUnitRulesParam(sourceIDs[#sourceIDs], "unitTargetID") == targetID
	end, 30)
	SyncedRun(moveTargetOutOfSight)
	Test.waitFrames(180)

	targetID = targetIDs[4]
	SyncedRun(moveTargetNearSources)
	Test.waitFrames(60)
	assertEqual(
		Spring.GetUnitRulesParam(sourceIDs[2], "unitTargetID"),
		nil,
		"a target globally pruned after LOS expiry must not reactivate when it becomes visible"
	)
	local _, _, _, _, _, _, syncedMemoryAfter = Spring.GetLuaMemUsage()
	Spring.Echo(
		string.format(
			"[Shared Target List Global Prune] sources=%d targets=%d retained=%d synced_lua_delta_kb=%.1f",
			#sourceIDs,
			#targetIDs,
			0,
			syncedMemoryAfter - syncedMemoryBefore
		)
	)

	enabled = true
	SyncedRun(setGlobalLos)
end

return {
	skip = skip,
	setup = setup,
	test = test,
	cleanup = cleanup,
}
