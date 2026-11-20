local function skip()
	return Spring.GetGameFrame() > 0
end

local function setup()
	local proxy = Spring.GetTeamRulesParam(Spring.GetMyTeamID(), "pregameQueue_" .. Spring.GetMyPlayerID())
	assert(proxy and proxy >= 0, "Pregame builder missing")
	Spring.SelectUnitArray({ proxy })

	widget_cmd_extractor_snap = widgetHandler:FindWidget("Extractor Snap (mex/geo)")
	assert(widget_cmd_extractor_snap)

	widget_gui_pregame_build = widgetHandler:FindWidget("Pregame builder selection")
	assert(widget_gui_pregame_build)

	WG.pregameQueue.setBuildQueue({})
	Spring.SetActiveCommand(0)

	initialCameraState = Spring.GetCameraState()

	Spring.SetCameraState({
		mode = 5,
	})

	-- wait for camera to move
	Test.waitTime(10)
end

local function cleanup()

	WG.pregameQueue.setBuildQueue({})
	Spring.SetActiveCommand(0)

	Spring.SetCameraState(initialCameraState)
end

local function test()
	mexUnitDefId = UnitDefNames.armmex.id
	metalSpots = WG.resource_spot_finder.metalSpotsList

	midX, midZ = Game.mapSizeX / 2, Game.mapSizeZ / 2
	targetMex = nil
	targetMexDistance = 1e20
	for i = 1, #metalSpots do
		local distance2 = math.distance2dSquared(midX, midZ, metalSpots[i].x, metalSpots[i].z)
		if distance2 < targetMexDistance then
			targetMexDistance = distance2
			targetMex = metalSpots[i]
		end
	end

	-- Place a mex off of a mex spot - expect mex snap to position it on the spot, as close as possible to cursor position
	Spring.SetActiveCommand(Spring.GetCmdDescIndex(-mexUnitDefId))
	sx, sy, sz = Spring.WorldToScreenCoords(targetMex.x - 200, targetMex.y, targetMex.z - 200)
	Spring.WarpMouse(sx, sy)

	-- wait for widgets to respond
	Test.waitTime(10)

	-- did it snap?
	assert(WG.ExtractorSnap.position ~= nil)

	-- did it snap to the closest mex?
	assert(math.distance2d(WG.ExtractorSnap.position.x, WG.ExtractorSnap.position.z, targetMex.x, targetMex.z) < 100)

	snappedPosition = table.copy(WG.ExtractorSnap.position)

	-- queue the mex build
	Script.LuaUI.MousePress(sx, sy, 1)

	-- wait for widgets to respond
	Test.waitTime(10)

	-- did the mex get placed in the right spot?
	buildQueue = WG.pregameQueue.getBuildQueue()
	assertEqual(#buildQueue, 1)
	assertTablesEqual(buildQueue[1], {
		mexUnitDefId,
		snappedPosition.x,
		snappedPosition.y,
		snappedPosition.z,
		0,
	}, 0.1)
end

return { skip = skip, setup = setup, test = test, cleanup = cleanup }
