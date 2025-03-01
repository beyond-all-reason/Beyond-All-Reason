function skip()
	return Spring.GetGameFrame() <= 0
end

function setup()
	Test.clearMap()
	-- Enable UnitCommand callin for tests
	Test.expectCallin("UnitCommand")
end

function cleanup()
	Test.clearMap()
end

function test()
	widget = widgetHandler:FindWidget("Stop means Stop")
	assert(widget)

	local myTeamID = Spring.GetMyTeamID()

	unitID = SyncedRun(function(locals)
		local x, z = Game.mapSizeX / 2, Game.mapSizeZ / 2
		local y = Spring.GetGroundHeight(x, z)
		return Spring.CreateUnit("armpw", x, y, z, 0, locals.myTeamID)
	end)

	-- issue selfd and then issue stop
	Spring.GiveOrderToUnit(unitID, CMD.SELFD, {}, 0)
	Test.waitUntilCallinArgs("UnitCommand", { nil, nil, nil, CMD.SELFD, nil, nil, nil })
	assert(Spring.GetUnitSelfDTime(unitID) > 0)

	Spring.GiveOrderToUnit(unitID, CMD.STOP, {}, 0)
	Test.waitUntilCallinArgs("UnitCommand", { nil, nil, nil, CMD.SELFD, nil, nil, nil })
	assert(Spring.GetUnitSelfDTime(unitID) == 0)
	assert(Spring.GetUnitCommandCount(unitID) == 0)

	-- issue {move, selfd}, then issue stop
	Spring.GiveOrderToUnit(unitID, CMD.MOVE, { 1, 1, 1 }, 0)
	Spring.GiveOrderToUnit(unitID, CMD.SELFD, {}, { "shift" })
	Test.waitUntilCallinArgs("UnitCommand", { nil, nil, nil, CMD.SELFD, nil, nil, nil })
	assert(Spring.GetUnitSelfDTime(unitID) == 0)

	Spring.GiveOrderToUnit(unitID, CMD.STOP, {}, 0)
	Test.waitUntilCallinArgs("UnitCommand", { nil, nil, nil, CMD.STOP, nil, nil, nil })
	assert(Spring.GetUnitSelfDTime(unitID) == 0)
	assert(Spring.GetUnitCommandCount(unitID) == 0)
end
