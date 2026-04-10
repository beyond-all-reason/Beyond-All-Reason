local widgetName = "Blueprint"

function skip()
	return not Platform.gl
end

function setup()
	assert(widgetHandler.knownWidgets[widgetName] ~= nil)

	Test.clearMap()

	widget = Test.prepareWidget(widgetName)

	assert(widget)
	mock_saveBlueprintsToFile = Test.mock(widget, "saveBlueprintsToFile")

	initialCameraState = SpringUnsynced.GetCameraState()

	SpringUnsynced.SetCameraState({
		mode = 5,
	})
end

function cleanup()
	Test.clearMap()

	SpringUnsynced.SetCameraState(initialCameraState)
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

	local myTeamID = SpringUnsynced.GetLocalTeamID()
	local x, z = Game.mapSizeX / 2, Game.mapSizeZ / 2
	local y = SpringShared.GetGroundHeight(x, z)
	local facing = 1
	local bpW, bpH = WG.api_blueprint.getBuildingDimensions(blueprintUnitDefID, facing)

	local bpCount = 5

	local blueprintUnitID = SyncedRun(function(locals)
		return SpringSynced.CreateUnit(locals.blueprintUnitDefName, locals.x, locals.y, locals.z, locals.facing, locals.myTeamID)
	end)

	SpringUnsynced.SelectUnit(blueprintUnitID)

	Test.waitFrames(delay)

	widget:CommandNotify(GameCMD.BLUEPRINT_CREATE, {}, {})

	assert(#widget.blueprints == 1)

	Test.clearMap()

	local builderUnitID = SyncedRun(function(locals)
		return SpringSynced.CreateUnit(locals.builderUnitDefName, locals.x + 100, locals.y, locals.z, locals.facing, locals.myTeamID)
	end)

	SpringUnsynced.SelectUnit(builderUnitID)

	Test.waitFrames(delay)

	SpringUnsynced.SetActiveCommand(SpringUnsynced.GetCmdDescIndex(GameCMD.BLUEPRINT_PLACE), 1, true, false, false, false, false, false)

	Test.waitFrames(delay)

	assert(widget.blueprintPlacementActive)

	mockSpringGetModKeyState = Test.mock(widget, "SpringGetModKeyState", function()
		return false, false, false, true
	end)

	mockSpringGetMouseState = Test.mock(widget, "SpringGetMouseState", function()
		local mx, my = SpringUnsynced.GetMouseState()
		return mx, my, true
	end)

	local sx, sy = SpringUnsynced.WorldToScreenCoords(x, y, z)
	SpringUnsynced.WarpMouse(sx, sy)

	Script.LuaUI.MousePress(sx, sy, 1)

	sx, sy = SpringUnsynced.WorldToScreenCoords(x, y, z + bpH * (bpCount - 1))
	SpringUnsynced.WarpMouse(sx, sy)

	Test.waitFrames(delay)

	widget:CommandNotify(GameCMD.BLUEPRINT_PLACE, {}, {})
	mockSpringGetMouseState.remove()

	Test.waitFrames(delay)

	local builderQueue = SpringShared.GetUnitCommands(builderUnitID, -1)

	assert(#builderQueue == bpCount, #builderQueue)
	assert(builderQueue[1].id == -blueprintUnitDefID)
end
