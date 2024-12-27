local widgetName = "Blueprint"

function skip()
	return Spring.GetGameFrame() <= 0
end

function setup()
	assert(widgetHandler.knownWidgets[widgetName] ~= nil)

	Test.clearMap()

	initialWidgetActive = widgetHandler.knownWidgets[widgetName].active
	if initialWidgetActive then
		widgetHandler:DisableWidget(widgetName)
	end
	widgetHandler:EnableWidget(widgetName, true)

	initialCameraState = Spring.GetCameraState()

	Spring.SetCameraState({
		mode = 5,
	})
end

function cleanup()
	Test.clearMap()

	widgetHandler:DisableWidget(widgetName)
	if initialWidgetActive then
		widgetHandler:EnableWidget(widgetName, false)
	end

	Spring.SetCameraState(initialCameraState)
end

local delay = 5
function test()
	VFS.Include("luarules/configs/customcmds.h.lua")

	widget = widgetHandler:FindWidget(widgetName)
	assert(widget)

	mock_saveBlueprintsToFile = Test.mock(widget, "saveBlueprintsToFile")

	-- load test blueprints
	widget.BLUEPRINT_FILE_PATH = "LuaUI/Widgets/Tests/cmd_blueprint/test_cmd_blueprint_filter_blueprints.json"
	widget.loadBlueprintsFromFile()

	Test.clearMap()

	local builderUnitDefName = "armck"

	local myTeamID = Spring.GetMyTeamID()
	local x, z = Game.mapSizeX / 2, Game.mapSizeZ / 2
	local y = Spring.GetGroundHeight(x, z)
	local facing = 1

	local builderUnitID = SyncedRun(function(locals)
		return Spring.CreateUnit(
			locals.builderUnitDefName,
			locals.x,
			locals.y,
			locals.z,
			locals.facing,
			locals.myTeamID
		)
	end)

	Spring.SelectUnit(builderUnitID)

	Test.waitFrames(delay)

	Spring.SetActiveCommand(
		Spring.GetCmdDescIndex(CMD_BLUEPRINT_PLACE),
		1,
		true,
		false,
		false,
		false,
		false,
		false
	)

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
