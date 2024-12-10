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

function runWaitUntil(unsafe, countOnly, reallyCountOnly)
	-- test waitUntilCallinArgs with and without expectCallin preregister
	local myTeamID = Spring.GetMyTeamID()
	if unsafe then
		Test.setUnsafeCallins(true)
	else
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
	if countOnly then
		Test.waitFrames(3)
		Test.waitUntilCallin("UnitCommand")
	else
		Test.waitUntilCallinArgs("UnitCommand", { nil, nil, nil, CMD.SELFD, nil, nil, nil })
	end
	assert(Spring.GetUnitSelfDTime(unitID) > 0)

	Test.clearCallins()
	if unsafe then
		Test.setUnsafeCallins(false)
	end
end

function test()
	runBaseTests()
	runWaitUntil()
	runWaitUntil(false, true)
	runWaitUntil(false, true, true)
	runWaitUntil(true)
end
