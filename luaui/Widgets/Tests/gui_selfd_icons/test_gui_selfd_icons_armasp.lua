local widgetName = "Self-Destruct Icons"

function setup()
	Test.clearMap()

	initialWidgetActive = widgetHandler.knownWidgets[widgetName].active
	if initialWidgetActive then
		widgetHandler:DisableWidget(widgetName)
	end
	widgetHandler:EnableWidget(widgetName, true)
end

function cleanup()
	Test.clearMap()

	widgetHandler:DisableWidget(widgetName)
	if initialWidgetActive then
		widgetHandler:EnableWidget(widgetName, false)
	end
end

function test()
	widget = widgetHandler:FindWidget(widgetName)
	assert(widget)
	local x, z = Game.mapSizeX / 2, Game.mapSizeZ / 2
	local y = Spring.GetGroundHeight(x, z)

	unitID = SyncedRun(function(locals)
		return Spring.CreateUnit(
			"armasp",
			locals.x, locals.y, locals.z,
			0, 0
		)
	end)

	assert(table.count(widget.activeSelfD) == 0)
	assert(table.count(widget.queuedSelfD) == 0)

	-- standard selfd command
	Spring.GiveOrderToUnit(unitID, CMD.SELFD, {}, 0)
	Test.waitFrames(1)
	assert(table.count(widget.activeSelfD) == 1)
	assert(table.count(widget.queuedSelfD) == 0)

	-- cancel selfd order
	Spring.GiveOrderToUnit(unitID, CMD.SELFD, {}, 0)
	Test.waitFrames(1)
	assert(table.count(widget.activeSelfD) == 0)
	assert(table.count(widget.queuedSelfD) == 0)

	-- currently fails
	---- queued selfd order (repair pad should not be able to queue selfd)
	--Spring.GiveOrderToUnit(unitID, CMD.MOVE, { 1, 1, 1 }, 0)
	--Spring.GiveOrderToUnit(unitID, CMD.SELFD, {}, { "shift" })
	--Test.waitFrames(1)
	--assert(table.count(widget.activeSelfD) == 0)
	--assert(table.count(widget.queuedSelfD) == 0)
end
