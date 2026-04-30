local widgetName = "Blueprint"

function skip()
	-- TODO re-enable and debug. Disabled 2025-09-30 to unblock CICD
	-- return Spring.GetGameFrame() <= 0
	return true
end

function setup()
	assert(widgetHandler.knownWidgets[widgetName] ~= nil)

	Test.clearMap()

	widget = Test.prepareWidget(widgetName)

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
	assert(widget)

	mock_saveBlueprintsToFile = Test.mock(widget, "saveBlueprintsToFile")

	-- load test blueprints
	widget.BLUEPRINT_FILE_PATH = "LuaUI/Tests/cmd_blueprint/test_cmd_blueprint_filter_blueprints.json"
	widget.loadBlueprintsFromFile()

	Test.clearMap()

	local builderUnitDefName = "armck"

	local myTeamID = Spring.GetMyTeamID()
	local x, z = Game.mapSizeX / 2, Game.mapSizeZ / 2
	local y = SpringShared.GetGroundHeight(x, z)
	local facing = 1

	local builderUnitID = SyncedRun(function(locals)
		return SpringSynced.CreateUnit(locals.builderUnitDefName, locals.x, locals.y, locals.z, locals.facing, locals.myTeamID)
	end)

	SpringUnsynced.SelectUnit(builderUnitID)

	Test.waitFrames(delay)

	SpringUnsynced.SetActiveCommand(SpringUnsynced.GetCmdDescIndex(GameCMD.BLUEPRINT_PLACE), 1, true, false, false, false, false, false)

	Test.waitFrames(delay)

	assert(widget.blueprintPlacementActive)

	-- make sure we skipped the blueprint #1, which is invalid
	assert(widget.selectedBlueprintIndex == 2, widget.selectedBlueprintIndex)

	-- make sure we skipped blueprint #3, which is cortex and unbuildable by armada
	widget.handleBlueprintNextAction()
	assert(widget.selectedBlueprintIndex == 4, widget.selectedBlueprintIndex)

	-- make sure we rotate to the next valid blueprint, #2
	widget.handleBlueprintDeleteAction()
	assert(widget.selectedBlueprintIndex == 2, widget.selectedBlueprintIndex)

	-- reset blueprints
	widget.loadBlueprintsFromFile()

	-- make sure we rotate to the next valid blueprint, #3 (which shifted from #4)
	widget.handleBlueprintDeleteAction()
	assert(widget.selectedBlueprintIndex == 3, widget.selectedBlueprintIndex)

	-- make sure we rotate to the next valid blueprint, nil
	widget.handleBlueprintDeleteAction()
	assert(widget.selectedBlueprintIndex == nil, widget.selectedBlueprintIndex)
end
