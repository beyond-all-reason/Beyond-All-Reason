local widgetName = "Battle Resource Tracker"

function skip()
	return Spring.GetGameFrame() <= 0
end

function setup()
	assert(widgetHandler.knownWidgets[widgetName] ~= nil)

	Test.clearMap()

	Test.prepareWidget(widgetName)
end

function cleanup()
	Test.clearMap()
end

function test()
	widget = widgetHandler:FindWidget(widgetName)
	assert(widget)

	widget.spatialHash:clear()

	combineEventsSpy = Test.spy(widget, "combineEvents")

	local x, z = Game.mapSizeX / 2, Game.mapSizeZ / 2
	local y = Spring.GetGroundHeight(x, z)
	local n = 5

	local unit = "armpw"

	unitM = UnitDefNames[unit].metalCost
	unitE = UnitDefNames[unit].energyCost

	SyncedRun(function(locals)
		for i = 1, locals.n do
			Spring.CreateUnit(locals.unit, locals.x, locals.y, locals.z + 10 * i, 0, 0)
		end
	end)

	Test.clearMap()

	assert(#(combineEventsSpy.calls) == n - 1, #(combineEventsSpy.calls))

	events = widget.spatialHash:allEvents()
	assert(#events == 1)

	assert(events[1].n == n, events[1].n)

	totalM = 0
	for _, v in pairs(events[1].metal) do
		totalM = totalM + v
	end
	assert(totalM == n * unitM)

	totalE = 0
	for _, v in pairs(events[1].energy) do
		totalE = totalE + v
	end
	assert(totalE == n * unitE)
end
