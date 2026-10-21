function skip()
	return Spring.GetGameFrame() <= 0
		or Spring.GetModOptions().fixedallies
		or select(1, Spring.GetTeamInfo(1, false)) == nil
end

function setup()
	Test.clearMap()
end

local function setAlliance(locals)
	Spring.SetAlly(0, 1, locals.allied)
	Spring.SetAlly(1, 0, locals.allied)
end

function cleanup()
	local allied = false
	SyncedRun(setAlliance)
	Spring.SelectUnitArray({})
	Test.clearMap()
end

local function createScenario()
	local centerX = Game.mapSizeX / 2
	local centerZ = Game.mapSizeZ / 2
	local sourceID = assert(Spring.CreateUnit("armflak", centerX - 100, 0, centerZ, "east", 0))
	local targetID = assert(Spring.CreateUnit("corhurc", centerX + 100, 200, centerZ, "west", 1))
	Spring.GiveOrderToUnit(sourceID, CMD.FIRE_STATE, { 0 }, 0)
	return sourceID, targetID
end

function test()
	local sourceID, targetID = SyncedRun(createScenario)
	Spring.GiveOrderToUnit(sourceID, GameCMD.UNIT_SET_TARGETS, { targetID }, 0)
	Test.waitUntil(function()
		return Spring.GetUnitRulesParam(sourceID, "unitTargetID") == targetID
	end, 120)

	local allied = true
	SyncedRun(setAlliance)
	Test.waitUntil(function()
		return Spring.GetUnitRulesParam(sourceID, "unitTargetID") == nil
	end, 120)

	Test.waitFrames(15)
	assertEqual(
		Spring.GetUnitRulesParam(sourceID, "unitTargetID"),
		nil,
		"an alliance change should clear the source target list"
	)
end

return {
	skip = skip,
	setup = setup,
	test = test,
	cleanup = cleanup,
}
