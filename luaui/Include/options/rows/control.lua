-- The control tab's settings. model.lua says what a row can hold.

local keyLayouts = require("luaui/configs/keyboard_layouts")

return function(model)
	local types = model.types
	local state = model.state
	local upkeep = model.upkeep
	local getOption = model.getOption
	local init = model.init
	local saveOptionValue = model.saveOptionValue
	local loadWidgetData = model.loadWidgetData
	local GetWidgetToggleValue = model.GetWidgetToggleValue

	local gridMenuOn = model.GridLayoutOn()
	local camMode = Spring.GetConfigInt("CamMode", 2)

	return {
		-- CONTROL
		{
			id = "label_ui_hotkeys",
			group = "control",
			name = BAR.I18N("ui.settings.option.label_hotkeys"),
			category = types.basic,
		},

		{
			id = "keylayout",
			group = "control",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.keylayout"),
			type = "select",
			options = keyLayouts.layouts,
			value = 1,
			description = BAR.I18N("ui.settings.option.keylayout_descr"),
			onload = function(option)
				local keyLayout = Spring.GetConfigString("KeyboardLayout")

				if not keyLayout or keyLayout == "" then
					keyLayout = keyLayouts.layouts[1]
					Spring.SetConfigString("KeyboardLayout", keyLayouts.layouts[1])
				end

				local value = 1
				for i, v in ipairs(keyLayouts.layouts) do
					if v == keyLayout then
						value = i
						break
					end
				end

				option.value = value
			end,
			onchange = function(_, value)
				Spring.SetConfigString("KeyboardLayout", keyLayouts.layouts[value])
				if WG.bar_hotkeys and WG.bar_hotkeys.reloadBindings then
					WG.bar_hotkeys.reloadBindings()
				end
			end,
		},

		{
			id = "gridmenu",
			group = "control",
			category = types.basic,
			available = Spring.GetConfigString("KeybindingFile") == "uikeys.txt",
			name = BAR.I18N("ui.settings.option.gridmenu"),
			type = "bool",
			value = gridMenuOn,
			description = BAR.I18N("ui.settings.option.gridmenu_descr"),
			onchange = function(option, value)
				local api = WG.buildmenu
				if api and api.setLayout then -- a build menu with both layouts (Build Menu FlowUI2)
					api.setLayout(value and "grid" or "build")
				elseif value then
					widgetHandler:DisableWidget("Build menu")
					widgetHandler:EnableWidget("Grid menu")
				else
					widgetHandler:DisableWidget("Grid menu")
					widgetHandler:EnableWidget("Build menu")
				end
				model.scheduleInit = true
			end,
		},
		{
			id = "gridmenu_alwaysreturn",
			group = "control",
			category = types.advanced,
			available = gridMenuOn,
			name = BAR.I18N("ui.settings.option.gridmenu_alwaysreturn"),
			type = "bool",
			value = (WG.gridmenu ~= nil and WG.gridmenu.getAlwaysReturn ~= nil and WG.gridmenu.getAlwaysReturn()),
			description = BAR.I18N("ui.settings.option.gridmenu_alwaysreturn_descr"),
			onchange = function(_, value)
				saveOptionValue("Grid menu", "gridmenu", "setAlwaysReturn", { "alwaysReturn" }, value)
			end,
		},
		{
			id = "gridmenu_autoselectfirst",
			group = "control",
			category = types.advanced,
			available = gridMenuOn,
			name = BAR.I18N("ui.settings.option.gridmenu_autoselectfirst"),
			type = "bool",
			value = (WG.gridmenu ~= nil and WG.gridmenu.getAutoSelectFirst ~= nil and WG.gridmenu.getAutoSelectFirst()),
			description = BAR.I18N("ui.settings.option.gridmenu_autoselectfirst_descr"),
			onchange = function(_, value)
				saveOptionValue("Grid menu", "gridmenu", "setAutoSelectFirst", { "autoSelectFirst" }, value)
			end,
		},
		{
			id = "gridmenu_labbuildmode",
			group = "control",
			category = types.advanced,
			available = gridMenuOn,
			name = BAR.I18N("ui.settings.option.gridmenu_labbuildmode"),
			type = "bool",
			value = (WG.gridmenu ~= nil and WG.gridmenu.getUseLabBuildMode ~= nil and WG.gridmenu.getUseLabBuildMode()),
			description = BAR.I18N("ui.settings.option.gridmenu_labbuildmode_descr"),
			onchange = function(_, value)
				saveOptionValue("Grid menu", "gridmenu", "setUseLabBuildMode", { "useLabBuildMode" }, value)
			end,
		},

		{
			id = "gridmenu_ctrlkeymodifier",
			group = "control",
			category = types.advanced,
			available = gridMenuOn,
			name = BAR.I18N("ui.settings.option.gridmenu_ctrlkeymodifier"),
			type = "slider",
			min = -20,
			max = 100,
			step = 1,
			value = (WG.gridmenu ~= nil and WG.gridmenu.getCtrlKeyModifier ~= nil and WG.gridmenu.getCtrlKeyModifier()),
			description = BAR.I18N("ui.settings.option.gridmenu_ctrlkeymodifier_descr"),
			onchange = function(_, value)
				saveOptionValue("Grid menu", "gridmenu", "setCtrlKeyModifier", { "ctrlKeyModifier" }, value)
			end,
		},
		{
			id = "gridmenu_shiftkeymodifier",
			group = "control",
			category = types.advanced,
			available = gridMenuOn,
			name = BAR.I18N("ui.settings.option.gridmenu_shiftkeymodifier"),
			type = "slider",
			min = -20,
			max = 100,
			step = 1,
			value = (
				WG.gridmenu ~= nil
				and WG.gridmenu.getShiftKeyModifier ~= nil
				and WG.gridmenu.getShiftKeyModifier()
			),
			description = BAR.I18N("ui.settings.option.gridmenu_shiftkeymodifier_descr"),
			onchange = function(_, value)
				saveOptionValue("Grid menu", "gridmenu", "setShiftKeyModifier", { "shiftKeyModifier" }, value)
			end,
		},

		{
			id = "label_ui_cursor",
			group = "control",
			name = BAR.I18N("ui.settings.option.label_cursor"),
			category = types.basic,
		},

		{
			id = "hwcursor",
			group = "control",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.hwcursor"),
			type = "bool",
			value = tonumber(Spring.GetConfigInt("HardwareCursor", 0) or 0) == 1,
			description = BAR.I18N("ui.settings.option.hwcursor_descr"),
			onchange = function(option, value)
				Spring.SendCommands("HardwareCursor " .. (value and 1 or 0))
				Spring.SetConfigInt("HardwareCursor", (value and 1 or 0))
			end,
		},
		{
			id = "setcamera_bugfix",
			group = "control",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.setcamera_bugfix"),
			type = "bool",
			value = Spring.GetConfigInt("SetCameraEveryFrame", 1) == 1,
			description = BAR.I18N("ui.settings.option.setcamera_bugfix_descr"),
			onload = function(option)
				WG.setcamera_bugfix = option.value
			end,
			onchange = function(option, value)
				WG.setcamera_bugfix = value
				Spring.SetConfigInt("SetCameraEveryFrame", value and 1 or 0)
			end,
		},
		{
			id = "cursorsize",
			group = "control",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.cursorsize"),
			type = "slider",
			min = 0.3,
			max = 1.7,
			step = 0.1,
			value = 1,
			description = BAR.I18N("ui.settings.option.cursorsize_descr"),
			onchange = function(option, value)
				if WG.cursors then
					WG.cursors.setsizemult(value)
				end
			end,
		},

		{
			id = "containmouse",
			group = "control",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.containmouse"),
			type = "bool",
			value = Spring.GetConfigInt("grabinput", 1) == 1,
			description = BAR.I18N("ui.settings.option.containmouse_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("grabinput", (value and 1 or 0))
				upkeep.updateGrabinput()
			end,
		},

		{
			id = "doubleclicktime",
			group = "control",
			category = types.advanced,
			restart = not Engine.FeatureSupport.liveConfigChanges,
			name = BAR.I18N("ui.settings.option.doubleclicktime"),
			type = "slider",
			min = 150,
			max = 400,
			step = 10,
			value = 200,
			description = BAR.I18N("ui.settings.option.doubleclicktime_descr"),
			configInt = "DoubleClickTime",
		},

		{
			id = "dragthreshold",
			group = "control",
			category = types.advanced,
			restart = false,
			name = BAR.I18N("ui.settings.option.dragthreshold"),
			type = "slider",
			min = 4,
			max = 50,
			step = 1,
			value = Spring.GetConfigInt("MouseDragSelectionThreshold", 4),
			description = BAR.I18N("ui.settings.option.dragthreshold_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("MouseDragSelectionThreshold", value)
				Spring.SetConfigInt("MouseDragCircleCommandThreshold", value)
				Spring.SetConfigInt("MouseDragBoxCommandThreshold", value + 12)
				Spring.SetConfigInt("MouseDragFrontCommandThreshold", value + 26)
			end,
		},

		{
			id = "label_ui_camera",
			group = "control",
			name = BAR.I18N("ui.settings.option.label_camera"),
			category = types.basic,
		},

		{
			id = "middleclicktoggle",
			group = "control",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.middleclicktoggle"),
			type = "bool",
			value = (Spring.GetConfigFloat("MouseDragScrollThreshold", 0.3) ~= 0),
			description = BAR.I18N("ui.settings.option.middleclicktoggle_descr"),
			onchange = function(option, value)
				Spring.SetConfigFloat("MouseDragScrollThreshold", (value and 0.3 or 0))
			end,
		},

		{
			id = "screenedgemove",
			group = "control",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.screenedgemove"),
			type = "bool",
			value = tonumber(Spring.GetConfigInt("FullscreenEdgeMove", 1) or 1) == 1,
			description = BAR.I18N("ui.settings.option.screenedgemove_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("FullscreenEdgeMove", (value and 1 or 0))
				Spring.SetConfigInt("WindowedEdgeMove", (value and 1 or 0))
				if value then
					Spring.SetConfigFloat("EdgeMoveWidth", state.edgeMoveWidth)
				else
					Spring.SetConfigFloat("EdgeMoveWidth", 0)
				end
			end,
		},
		{
			id = "screenedgemovewidth",
			parent = "screenedgemove",
			group = "control",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.screenedgemovewidth"),
			type = "slider",
			min = 0,
			max = 0.1,
			step = 0.01,
			value = state.edgeMoveWidth,
			description = BAR.I18N("ui.settings.option.screenedgemovewidth_descr"),
			onchange = function(option, value)
				state.edgeMoveWidth = value
				Spring.SetConfigFloat("EdgeMoveWidth", value)
			end,
		},
		{
			id = "screenedgemovedynamic",
			parent = "screenedgemove",
			group = "control",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.screenedgemovedynamic"),
			type = "bool",
			value = true,
			description = BAR.I18N("ui.settings.option.screenedgemovedynamic_descr"),
			configInt = "EdgeMoveDynamic",
		},

		{
			id = "camera",
			group = "control",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.camera"),
			type = "select",
			options = {
				BAR.I18N("ui.settings.option.select_firstperson"),
				BAR.I18N("ui.settings.option.select_overhead"),
				BAR.I18N("ui.settings.option.select_springcam"),
				BAR.I18N("ui.settings.option.select_rotoverhead"),
				BAR.I18N("ui.settings.option.select_free"),
			},
			value = (tonumber((Spring.GetConfigInt("CamMode", 1) + 1) or 2)),
			onchange = function(option, value)
				Spring.SetConfigInt("CamMode", (value - 1))
				if value == 1 then
					Spring.SendCommands("viewfps")
				elseif value == 2 then
					Spring.SendCommands("viewta")
				elseif value == 3 then
					Spring.SendCommands("viewspring")
				elseif value == 4 then
					Spring.SendCommands("viewrot")
				elseif value == 5 then
					Spring.SendCommands("viewfree")
				end
				init()
			end,
		},
		{
			id = "springcamheightmode",
			parent = "camera",
			group = "control",
			category = types.advanced,
			available = camMode == 2,
			name = BAR.I18N("ui.settings.option.springcamheightmode"),
			type = "select",
			options = {
				BAR.I18N("ui.settings.option.select_constant"),
				BAR.I18N("ui.settings.option.select_terrain"),
				BAR.I18N("ui.settings.option.select_smooth"),
			},
			-- Smooth (2) once the engine tracks the smooth mesh properly (RecoilEngine #3012), else as before.
			value = Spring.GetConfigInt(
				"CamSpringTrackMapHeightMode",
				Engine.FeatureSupport.smoothCameraHeightTracking and 2 or 0
			) + 1,
			description = BAR.I18N("ui.settings.option.springcamheightmode_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("CamSpringTrackMapHeightMode", value - 1)
			end,
		},
		{
			id = "mincamheight",
			parent = "camera",
			group = "control",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.mincamheight"),
			type = "slider",
			min = 0,
			max = 1500,
			step = 1,
			value = Spring.GetConfigInt("CamSpringMinZoomDistance", 0),
			description = BAR.I18N("ui.settings.option.mincamheight_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("CamSpringMinZoomDistance", value)
				Spring.SetConfigInt("OverheadMinZoomDistance", value)
			end,
		},
		{
			id = "camerashake",
			parent = "camera",
			group = "control",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.camerashake"),
			type = "slider",
			min = 0,
			max = 200,
			step = 10,
			value = 80,
			description = BAR.I18N("ui.settings.option.camerashake_descr"),
			onload = function(option)
				loadWidgetData("CameraShake", "camerashake", { "powerScale" })
				if option.value > 0 then
					widgetHandler:EnableWidget("CameraShake")
				end
			end,
			onchange = function(option, value)
				saveOptionValue("CameraShake", "camerashake", "setStrength", { "powerScale" }, value)
				if value > 0 then
					widgetHandler:EnableWidget("CameraShake")
				end
			end,
		},
		--{ id = "camerasmoothing", group = "control", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.camerasmoothing'), type = "bool", value = (tonumber(Spring.GetConfigInt("CameraSmoothing", 0)) == 1), description = "",
		--  onload = function(option)
		--  end,
		--  onchange = function(option, value)
		--	  Spring.SetConfigInt("CameraSmoothing", (value and 1 or 0))
		--	  if value then
		--		  Spring.SendCommands("set CamFrameTimeCorrection 1")
		--		  Spring.SendCommands("set SmoothTimeOffset 2")
		--		else
		--		  Spring.SendCommands("set CamFrameTimeCorrection 0")
		--		  Spring.SendCommands("set SmoothTimeOffset 0")
		--	  end
		--  end,
		--},
		{
			id = "smoothingmode",
			parent = "camera",
			group = "control",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.smoothingmode"),
			type = "select",
			options = {
				BAR.I18N("ui.settings.option.smoothing_exponential"),
				BAR.I18N("ui.settings.option.smoothing_spring"),
			},
			value = (Spring.GetConfigInt("CamTransitionMode", 1) + 1),
			onchange = function(option, value)
				Spring.SetConfigInt("CamTransitionMode", (value - 1))
			end,
		},
		{
			id = "camerasmoothness",
			parent = "camera",
			group = "control",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.camerasmoothness"),
			type = "slider",
			min = 0.04,
			max = 2,
			step = 0.01,
			value = state.cameraTransitionTime,
			description = BAR.I18N("ui.settings.option.camerasmoothness_descr"),
			onchange = function(option, value)
				state.cameraTransitionTime = value
				local halfLife = value
				if halfLife <= 1 then
					halfLife = halfLife * 200
				else
					halfLife = halfLife * 600 - 400
				end
				Spring.SetConfigFloat("CamSpringHalflife", halfLife)
			end,
		},
		{
			id = "camerapanspeed",
			parent = "camera",
			group = "control",
			category = types.basic,
			available = camMode == 1, -- only the overhead camera reads MiddleClickScrollSpeed
			name = BAR.I18N("ui.settings.option.camerapanspeed"),
			type = "slider",
			min = -0.01,
			max = -0.00195,
			step = 0.0001,
			value = 0.0035,
			description = BAR.I18N("ui.settings.option.camerapanspeed_descr"),
			configFloat = "MiddleClickScrollSpeed",
		},
		{
			id = "cameramovespeed",
			parent = "camera",
			group = "control",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.cameramovespeed"),
			type = "slider",
			min = 0,
			max = 100,
			step = 1,
			value = Spring.GetConfigInt("CamSpringScrollSpeed", 10),
			description = BAR.I18N("ui.settings.option.cameramovespeed_descr"),
			onchange = function(option, value)
				--cameraPanTransitionTime = value
				Spring.SetConfigInt("FPSScrollSpeed", value) -- spring default: 10
				Spring.SetConfigInt("OverheadScrollSpeed", value) -- spring default: 10
				Spring.SetConfigInt("RotOverheadScrollSpeed", value) -- spring default: 10
				Spring.SetConfigFloat("CamFreeScrollSpeed", value * 50) -- spring default: 500
				Spring.SetConfigInt("CamSpringScrollSpeed", value) -- spring default: 10
			end,
		},
		{
			id = "scrollspeed",
			parent = "camera",
			group = "control",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.scrollspeed"),
			type = "slider",
			min = 1,
			max = 50,
			step = 1,
			value = math.abs(tonumber(Spring.GetConfigInt("ScrollWheelSpeed", 1) or 25)),
			description = "",
			onchange = function(option, value)
				if getOption("scrollinverse") and getOption("scrollinverse").value then
					Spring.SetConfigInt("ScrollWheelSpeed", -value)
				else
					Spring.SetConfigInt("ScrollWheelSpeed", value)
				end
			end,
		},
		{
			id = "scrollinverse",
			parent = "camera",
			group = "control",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.scrollinverse"),
			type = "bool",
			value = (tonumber(Spring.GetConfigInt("ScrollWheelSpeed", 1) or 25) < 0),
			description = "",
			onchange = function(option, value)
				if getOption("scrollspeed") then
					if value then
						Spring.SetConfigInt("ScrollWheelSpeed", -getOption("scrollspeed").value)
					else
						Spring.SetConfigInt("ScrollWheelSpeed", getOption("scrollspeed").value)
					end
				end
			end,
		},
		{
			id = "zoomtocursor",
			parent = "camera",
			group = "control",
			category = types.advanced,
			available = camMode == 2,
			name = BAR.I18N("ui.settings.option.zoomtocursor"),
			type = "bool",
			value = true,
			description = "",
			configInt = "CamSpringZoomInToMousePos",
		},
		{
			id = "zoomfromcursor",
			parent = "camera",
			group = "control",
			category = types.advanced,
			available = camMode == 2,
			name = BAR.I18N("ui.settings.option.zoomfromcursor"),
			type = "bool",
			value = false,
			description = "",
			configInt = "CamSpringZoomOutFromMousePos",
		},
		{
			id = "invertmouse",
			parent = "camera",
			group = "control",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.invertmouse"),
			type = "bool",
			value = false,
			description = "",
			configInt = "InvertMouse",
		},
		{
			id = "scrolltoggleoverview",
			parent = "camera",
			group = "control",
			category = types.advanced,
			widget = "Scrolldown Toggleoverview",
			name = BAR.I18N("ui.settings.option.scrolltoggleoverview"),
			type = "bool",
			value = GetWidgetToggleValue("Scrolldown Toggleoverview"),
			description = BAR.I18N("ui.settings.option.scrolltoggleoverview_descr"),
		},

		{
			id = "camoverviewrestore",
			parent = "camera",
			group = "control",
			category = types.advanced,
			widget = "Overview Camera Keep Position",
			name = BAR.I18N("ui.settings.option.camoverviewrestore"),
			type = "bool",
			value = GetWidgetToggleValue("Overview Camera Keep Position"),
			description = BAR.I18N("ui.settings.option.camoverviewrestore_descr"),
		},

		{
			id = "lockcamera_transitiontime",
			group = "control",
			category = types.advanced,
			available = WG.lockcamera ~= nil, -- these act while watching a player's camera
			prefix = BAR.I18N("ui.settings.option.lockcamera"),
			name = BAR.I18N("ui.settings.option.lockcamera_transitiontime"),
			type = "slider",
			min = 0.5,
			max = 1.7,
			step = 0.01,
			description = BAR.I18N("ui.settings.option.lockcamera_transitiontime_descr"),
			widgetConfig = {
				"Lockcamera",
				"transitionTime",
				api = "lockcamera",
				get = "GetTransitionTime",
				set = "SetTransitionTime",
			},
		},

		{
			id = "allyselunits_select",
			parent = "lockcamera_transitiontime",
			group = "control",
			category = types.advanced,
			available = WG.lockcamera ~= nil, -- these act while watching a player's camera
			name = BAR.I18N("ui.settings.option.allyselunits_select"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.allyselunits_select_descr"),
			widgetConfig = {
				"Ally Selected Units",
				"selectPlayerUnits",
				api = "allyselectedunits",
				get = "getSelectPlayerUnits",
				set = "setSelectPlayerUnits",
			},
		},
		{
			id = "lockcamera_hideenemies",
			parent = "lockcamera_transitiontime",
			group = "control",
			category = types.advanced,
			available = WG.lockcamera ~= nil, -- these act while watching a player's camera
			name = BAR.I18N("ui.settings.option.lockcamera_hideenemies"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.lockcamera_hideenemies_descr"),
			widgetConfig = {
				"Lockcamera",
				"lockcameraHideEnemies",
				api = "lockcamera",
				get = "GetHideEnemies",
				set = "SetHideEnemies",
			},
		},
		{
			id = "lockcamera_los",
			parent = "lockcamera_transitiontime",
			group = "control",
			category = types.advanced,
			available = WG.lockcamera ~= nil, -- these act while watching a player's camera
			name = BAR.I18N("ui.settings.option.lockcamera_los"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.lockcamera_los_descr"),
			widgetConfig = { "Lockcamera", "lockcameraLos", api = "lockcamera", get = "GetLos", set = "SetLos" },
		},

		{
			id = "label_ui_command",
			group = "control",
			name = BAR.I18N("ui.settings.option.label_commands"),
			category = types.advanced,
		},
		{
			id = "drag_multicommand_shift",
			parent = "label_ui_command",
			group = "control",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.drag_multicommand_shift"),
			type = "bool",
			value = (WG.customformations ~= nil and WG.customformations.getRepeatForSingleUnit()),
			description = BAR.I18N("ui.settings.option.drag_multicommand_shift_descr"),
			onchange = function(option, value)
				saveOptionValue(
					"CustomFormations2",
					"customformations",
					"setRepeatForSingleUnit",
					{ "repeatForSingleUnit" },
					value
				)
			end,
		},
	}
end
