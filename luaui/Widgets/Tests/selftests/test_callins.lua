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
	Test.expectCallin("UnitCommand")

	assertThrowsMessage(function()
		Test.waitUntilCallin("UnitCommand", function()
			return true
		end)
	end, "[registerCallin:UnitCommand] expecting a different mode")

	Test.clearCallins()

	-- mismatching expect and wait
	Test.expectCallin("UnitCommand", true)

	assertThrowsMessage(function()
		Test.waitUntilCallin("UnitCommand")
	end, "[registerCallin:UnitCommand] expecting a different mode")

	Test.clearCallins()
end

function runWaitUntil(expect)
	-- test waitUntilCallinArgs with and without expectCallin preregister
	local myTeamID = Spring.GetMyTeamID()
	if expect then
		Test.expectCallin("UnitCommand", true)
	end

	local unitID = SyncedRun(function(locals)
		local x, z = Game.mapSizeX / 2, Game.mapSizeZ / 2
		local y = Spring.GetGroundHeight(x, z)
		return Spring.CreateUnit("armpw", x, y, z, 0, locals.myTeamID)
	end)

	-- issue selfd
	Spring.GiveOrderToUnit(unitID, CMD.SELFD, {}, 0)

	-- actual test
	Test.waitUntilCallinArgs("UnitCommand", { nil, nil, nil, CMD.SELFD, nil, nil, nil })
	assert(Spring.GetUnitSelfDTime(unitID) > 0)

	Test.clearCallins()
end

function test()
	runBaseTests()
	runWaitUntil()
	runWaitUntil(true)
end
