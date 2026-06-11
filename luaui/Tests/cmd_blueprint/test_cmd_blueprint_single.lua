local widgetName = "Blueprint"

function setup()
	assert(widgetHandler.knownWidgets[widgetName] ~= nil)

	Test.clearMap()

	widget = Test.prepareWidget(widgetName)

	mock_saveBlueprintsToFile = Test.mock(widget, "saveBlueprintsToFile")

	initialCameraState = Engine.Unsynced.GetCameraState()

	Engine.Unsynced.SetCameraState({
		mode = 5,
	})
end

function cleanup()
	Test.clearMap()

	Engine.Unsynced.SetCameraState(initialCameraState)
end

local delay = 5
function test()
	widget = widgetHandler:FindWidget(widgetName)
	assert(widget)

	widget.blueprints = {}
	widget.setSelectedBlueprintIndex(nil)

	local blueprintUnitDefName = "armsolar"
	local builderUnitDefName = "armck"

	local blueprintUnitDefID = UnitDefNames[blueprintUnitDefName].id

	local myTeamID = Spring.GetMyTeamID()
	local x, z = Game.mapSizeX / 2, Game.mapSizeZ / 2
	local y = Engine.Shared.GetGroundHeight(x, z)
	local facing = 1

	local blueprintUnitID = SyncedRun(function(locals)
		return Engine.Synced.CreateUnit(locals.blueprintUnitDefName, locals.x, locals.y, locals.z, locals.facing, locals.myTeamID)
	end)

	Engine.Unsynced.SelectUnit(blueprintUnitID)

	Test.waitFrames(delay)

	widget:CommandNotify(GameCMD.BLUEPRINT_CREATE, {}, {})

	assertEqual(#widget.blueprints, 1)

	Test.clearMap()

	local builderUnitID = SyncedRun(function(locals)
		return Engine.Synced.CreateUnit(locals.builderUnitDefName, locals.x + 100, locals.y, locals.z, locals.facing, locals.myTeamID)
	end)

	Engine.Unsynced.SelectUnit(builderUnitID)

	Test.waitFrames(delay)

	Engine.Unsynced.SetActiveCommand(Engine.Unsynced.GetCmdDescIndex(GameCMD.BLUEPRINT_PLACE), 1, true, false, false, false, false, false)

	Test.waitFrames(delay)

	assert(widget.blueprintPlacementActive, "blueprintPlacementActive was nil or false")

	local sx, sy = Engine.Unsynced.WorldToScreenCoords(x, y, z)
	Engine.Unsynced.WarpMouse(sx, sy)

	Test.waitFrames(delay)

	widget:CommandNotify(GameCMD.BLUEPRINT_PLACE, {}, {})

	Test.waitFrames(delay)

	local builderQueue = Engine.Shared.GetUnitCommands(builderUnitID, -1)

	assertEqual(#builderQueue, 1)
	assertEqual(builderQueue[1].id, -blueprintUnitDefID)
end
