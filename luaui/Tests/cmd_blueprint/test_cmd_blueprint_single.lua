local widgetName = "Blueprint"

function setup()
	assert(widgetHandler.knownWidgets[widgetName] ~= nil)

	Test.clearMap()

	widget = Test.prepareWidget(widgetName)

	mock_saveBlueprintsToFile = Test.mock(widget, "saveBlueprintsToFile")

	initialCameraState = Spring.GetCameraState()

	Spring.SetCameraState({
		mode = 5,
	})
end

function cleanup()
	Test.clearMap()

	Spring.SetCameraState(initialCameraState)
end

local delay = 5
function test()
	VFS.Include("luarules/configs/customcmds.h.lua")

	widget = widgetHandler:FindWidget(widgetName)
	assert(widget)

	while #(widget.blueprints) > 0 do
		widget.deleteBlueprint(1)
	end

	local blueprintUnitDefName = "armsolar"
	local builderUnitDefName = "armck"

	local blueprintUnitDefID = UnitDefNames[blueprintUnitDefName].id

	local myTeamID = Spring.GetMyTeamID()
	local x, z = Game.mapSizeX / 2, Game.mapSizeZ / 2
	local y = Spring.GetGroundHeight(x, z)
	local facing = 1

	local blueprintUnitID = SyncedRun(function(locals)
		return Spring.CreateUnit(
			locals.blueprintUnitDefName,
			locals.x,
			locals.y,
			locals.z,
			locals.facing,
			locals.myTeamID
		)
	end)

	Spring.SelectUnit(blueprintUnitID)

	Test.waitFrames(delay)

	widget:CommandNotify(CMD_BLUEPRINT_CREATE, {}, {})

	assert(#(widget.blueprints) == 1)

	Test.clearMap()

	local builderUnitID = SyncedRun(function(locals)
		return Spring.CreateUnit(
			locals.builderUnitDefName,
			locals.x + 100,
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

	local sx, sy = Spring.WorldToScreenCoords(x, y, z)
	Spring.WarpMouse(sx, sy)

	Test.waitFrames(delay)

	widget:CommandNotify(CMD_BLUEPRINT_PLACE, {}, {})

	Test.waitFrames(delay)

	local builderQueue = Spring.GetUnitCommands(builderUnitID, -1)

	assert(#builderQueue == 1)
	assert(builderQueue[1].id == -blueprintUnitDefID)
end
