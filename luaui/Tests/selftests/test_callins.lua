function skip()
	return Spring.GetGameFrame() <= 0
end

function setup()
	Test.clearMap()
end

function cleanup()
	Test.clearMap()
end

function runBaseTests()
	-- double expect should throw
	Test.expectCallin("UnitCommand")

	assertThrowsMessage(function()
		Test.expectCallin("UnitCommand")
	end, "[preRegisterCallin:UnitCommand] already pre-registered")

	Test.clearCallins()

	-- mismatching expect and wait
	Test.expectCallin("UnitCommand", true)

	assertThrowsMessage(function()
		Test.waitUntilCallin("UnitCommand", function()
			return true
		end)
	end, "[registerCallin:UnitCommand] expecting countOnly but requesting full")

	Test.clearCallins()

	-- not calling expect first
	assertThrowsMessage(function()
		Test.waitUntilCallin("UnitCommand")
	end, "[registerCallin:UnitCommand] need to call Test.expectCallin(\"UnitCommand\") first")

	Test.clearCallins()

end

function runWaitUntil(countOnly, reallyCountOnly, wait, expect, clear)
	-- test waitUntilCallinArgs with and without expectCallin preregister
	local myTeamID = Spring.GetMyTeamID()
	if expect then
		Test.expectCallin("UnitCommand", reallyCountOnly)
	end

	local unitID = SyncedRun(function(locals)
		local x, z = Game.mapSizeX / 2, Game.mapSizeZ / 2
		local y = Spring.GetGroundHeight(x, z)
		return Spring.CreateUnit("armpw", x, y, z, 0, locals.myTeamID)
	end)

	-- issue selfd
	Spring.GiveOrderToUnit(unitID, CMD.SELFD, {}, 0)

	-- actual test
	if wait > 0 then
		Test.waitFrames(wait)
	end
	if countOnly then
		Test.waitUntilCallin("UnitCommand")
	else
		Test.waitUntilCallinArgs("UnitCommand", { nil, nil, nil, CMD.SELFD, nil, nil, nil })
	end
	assert(Spring.GetUnitSelfDTime(unitID) > 0)

	if clear then
		Test.clearCallins()
	end
end

function test()
	local FULL = false
	local COUNT = true
	local EXPECT = true
	local CLEAR = true

	runBaseTests()
	-- normal run, try full register, then only count, then only count and expect count
	runWaitUntil(FULL, FULL, 0, EXPECT, CLEAR)
	runWaitUntil(COUNT, FULL, 0, EXPECT, CLEAR)
	runWaitUntil(COUNT, COUNT, 0, EXPECT, CLEAR)

	-- same but now with wait before give order and waitUntilCallin
	runWaitUntil(FULL, FULL, 3, EXPECT, CLEAR)
	runWaitUntil(COUNT, FULL, 3, EXPECT, CLEAR)
	runWaitUntil(COUNT, COUNT, 3, EXPECT, CLEAR)

	-- same but now without cleaning callins
	runWaitUntil(FULL, FULL, 3, EXPECT, not CLEAR)
	runWaitUntil(COUNT, FULL, 3, not EXPECT, not CLEAR)
	runWaitUntil(COUNT, COUNT, 3, not EXPECT, CLEAR)

	-- test with unsafe call
	Test.setUnsafeCallins(true)
	runWaitUntil(FULL, FULL, 0, not EXPECT, CLEAR)
	Test.setUnsafeCallins(false)
end
