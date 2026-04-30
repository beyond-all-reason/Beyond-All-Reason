local widgetName = "Self-Destruct Icons"

function skip()
	return SpringShared.GetGameFrame() <= 0
end

function setup()
	Test.clearMap()

	Test.prepareWidget(widgetName)
	Test.expectCallin("UnitCommand")
end

function cleanup()
	Test.clearMap()
end

function test()
	widget = widgetHandler:FindWidget(widgetName)
	assert(widget)

	local x, z = Game.mapSizeX / 2, Game.mapSizeZ / 2
	local y = SpringShared.GetGroundHeight(x, z)

	unitID = SyncedRun(function(locals)
		return SpringSynced.CreateUnit("armpw", locals.x, locals.y, locals.z, 0, 0)
	end)

	assert(table.count(widget.activeSelfD) == 0)
	assert(table.count(widget.queuedSelfD) == 0)

	-- standard selfd command
	SpringShared.GiveOrderToUnit(unitID, CMD.SELFD, {}, 0)
	Test.waitUntilCallinArgs("UnitCommand", { unitID, nil, nil, CMD.SELFD })
	assert(table.count(widget.activeSelfD) == 1)
	assert(table.count(widget.queuedSelfD) == 0)

	-- cancel selfd order
	SpringShared.GiveOrderToUnit(unitID, CMD.SELFD, {}, 0)
	Test.waitUntilCallinArgs("UnitCommand", { unitID, nil, nil, CMD.SELFD })
	assert(table.count(widget.activeSelfD) == 0)
	assert(table.count(widget.queuedSelfD) == 0)

	-- queued selfd order
	SpringShared.GiveOrderToUnit(unitID, CMD.MOVE, { 1, 1, 1 }, 0)
	SpringShared.GiveOrderToUnit(unitID, CMD.SELFD, {}, { "shift" })
	Test.waitUntilCallinArgs("UnitCommand", { unitID, nil, nil, CMD.SELFD })
	assert(table.count(widget.activeSelfD) == 0)
	assert(table.count(widget.queuedSelfD) == 1)

	-- remove move order
	SpringShared.GiveOrderToUnit(unitID, CMD.REMOVE, { CMD.MOVE }, { "alt" })
	Test.waitUntil(function()
		return table.count(widget.activeSelfD) == 1 and table.count(widget.queuedSelfD) == 0
	end, 10)
end
