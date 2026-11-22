-- The game tab's settings. model.lua says what a row can hold.
return function(model)
	local types = model.types
	local state = model.state
	local saveOptionValue = model.saveOptionValue
	local loadWidgetData = model.loadWidgetData
	local GetWidgetToggleValue = model.GetWidgetToggleValue
	local squadPreset = model.squadPreset
	local squadSelectValue = model.squadSelectValue
	return {
		-- GAME
		{
			id = "networksmoothing",
			restart = not Engine.FeatureSupport.liveConfigChanges,
			category = types.basic,
			group = "game",
			name = BAR.I18N("ui.settings.option.networksmoothing"),
			type = "bool",
			value = state.useNetworkSmoothing,
			description = BAR.I18N("ui.settings.option.networksmoothing_descr"),
			onload = function(option)
				option.onchange(option, option.value)
			end,
			onchange = function(option, value)
				state.useNetworkSmoothing = value
				if state.useNetworkSmoothing then
					Spring.SetConfigInt("UseNetMessageSmoothingBuffer", 1)
					Spring.SetConfigInt("NetworkLossFactor", 0)
					Spring.SetConfigInt("LinkOutgoingBandwidth", 196608)
					Spring.SetConfigInt("LinkIncomingSustainedBandwidth", 196608)
					Spring.SetConfigInt("LinkIncomingPeakBandwidth", 196608)
					Spring.SetConfigInt("LinkIncomingMaxPacketRate", 1024)
				else
					Spring.SetConfigInt("UseNetMessageSmoothingBuffer", 0)
					Spring.SetConfigInt("NetworkLossFactor", 2)
					Spring.SetConfigInt("LinkOutgoingBandwidth", 196608)
					Spring.SetConfigInt("LinkIncomingSustainedBandwidth", 1048576)
					Spring.SetConfigInt("LinkIncomingPeakBandwidth", 1048576)
					Spring.SetConfigInt("LinkIncomingMaxPacketRate", 2048)
				end
			end,
		},
		{
			id = "autoquit",
			group = "game",
			category = types.basic,
			widget = "Autoquit",
			name = BAR.I18N("ui.settings.option.autoquit"),
			type = "bool",
			value = GetWidgetToggleValue("Autoquit"),
			description = BAR.I18N("ui.settings.option.autoquit_descr"),
		},

		{
			id = "singleplayerpause",
			group = "game",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.singleplayerpause"),
			type = "bool",
			value = Spring.GetConfigInt("WindowsPauseGame", 1) == 1,
			description = BAR.I18N("ui.settings.option.singleplayerpause_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("WindowsPauseGame", (value and 1 or 0))
				-- pushed through as well so it takes effect now instead of at the next poll
				widgetHandler:SetWindowsPauseGame(value)
			end,
		},

		{
			id = "catchupsmoothness",
			group = "game",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.catchupsmoothness"),
			restart = not Engine.FeatureSupport.liveConfigChanges,
			type = "slider",
			min = 0.05,
			max = 0.3,
			step = 0.01,
			value = 0.15,
			description = BAR.I18N("ui.settings.option.catchupsmoothness_descr"),
			configFloat = "MinSimDrawBalance",
		},
		{
			id = "catchupminfps",
			group = "game",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.catchupminfps"),
			restart = not Engine.FeatureSupport.liveConfigChanges,
			type = "slider",
			min = 2,
			max = 15,
			step = 1,
			value = 2,
			description = BAR.I18N("ui.settings.option.catchupminfps_descr"),
			configInt = "MinDrawFPS",
		},

		{
			id = "label_ui_behavior",
			group = "game",
			name = BAR.I18N("ui.settings.option.label_behavior"),
			category = types.basic,
		},

		{
			id = "smartselect_includebuildings",
			group = "game",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.smartselect_includebuildings"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.smartselect_includebuildings_descr"),
			onchange = function(option, value)
				saveOptionValue(
					"SmartSelect",
					"smartselect",
					"setIncludeBuildings",
					{ "selectBuildingsWithMobile" },
					value
				)
			end,
		},
		{
			id = "smartselect_includebuilders",
			parent = "smartselect_includebuildings",
			group = "game",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.smartselect_includebuilders"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.smartselect_includebuilders_descr"),
			onchange = function(option, value)
				saveOptionValue("SmartSelect", "smartselect", "setIncludeBuilders", { "includeBuilders" }, value)
			end,
		},
		{
			id = "smartselect_includeresurrectors",
			parent = "smartselect_includebuildings",
			group = "game",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.smartselect_includeresurrectors"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.smartselect_includeresurrectors_descr"),
			onchange = function(option, value)
				saveOptionValue(
					"SmartSelect",
					"smartselect",
					"setIncludeResurrectors",
					{ "includeResurrectors" },
					value
				)
			end,
		},
		{
			id = "smartselect_includeantinuke",
			parent = "smartselect_includebuildings",
			group = "game",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.smartselect_includeantinuke"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.smartselect_includeantinuke_descr"),
			onchange = function(option, value)
				saveOptionValue("SmartSelect", "smartselect", "setIncludeAntinuke", { "includeAntinuke" }, value)
			end,
		},
		{
			id = "smartselect_includeradar",
			parent = "smartselect_includebuildings",
			group = "game",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.smartselect_includeradar"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.smartselect_includeradar_descr"),
			onchange = function(option, value)
				saveOptionValue("SmartSelect", "smartselect", "setIncludeRadar", { "includeRadar" }, value)
			end,
		},
		{
			id = "smartselect_includejammer",
			parent = "smartselect_includebuildings",
			group = "game",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.smartselect_includejammer"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.smartselect_includejammer_descr"),
			onchange = function(option, value)
				saveOptionValue("SmartSelect", "smartselect", "setIncludeJammer", { "includeJammer" }, value)
			end,
		},

		{
			id = "prioconturrets",
			group = "game",
			category = types.basic,
			widget = "Priority Construction Turrets",
			name = BAR.I18N("ui.settings.option.prioconturrets"),
			type = "bool",
			value = GetWidgetToggleValue("Priority Construction Turrets"),
			description = BAR.I18N("ui.settings.option.prioconturrets_descr"),
		},

		{
			id = "builderpriority",
			group = "game",
			category = types.basic,
			widget = "Builder Priority",
			name = BAR.I18N("ui.settings.option.builderpriority"),
			type = "bool",
			value = GetWidgetToggleValue("Builder Priority"),
			description = BAR.I18N("ui.settings.option.builderpriority_descr"),
		},

		{
			id = "builderpriority_nanos",
			parent = "builderpriority",
			group = "game",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.builderpriority_nanos"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.builderpriority_nanos_descr"),
			widgetConfig = {
				"Builder Priority",
				"lowpriorityNanos",
				api = "builderpriority",
				get = "getLowPriorityNanos",
				set = "setLowPriorityNanos",
			},
		},

		{
			id = "builderpriority_cons",
			parent = "builderpriority",
			group = "game",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.builderpriority_cons"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.builderpriority_cons_descr"),
			widgetConfig = {
				"Builder Priority",
				"lowpriorityCons",
				api = "builderpriority",
				get = "getLowPriorityCons",
				set = "setLowPriorityCons",
			},
		},

		{
			id = "builderpriority_labs",
			parent = "builderpriority",
			group = "game",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.builderpriority_labs"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.builderpriority_labs_descr"),
			widgetConfig = {
				"Builder Priority",
				"lowpriorityLabs",
				api = "builderpriority",
				get = "getLowPriorityLabs",
				set = "setLowPriorityLabs",
			},
		},

		{
			id = "factoryguard",
			group = "game",
			category = types.basic,
			widget = "Factory Guard Default On",
			prefix = BAR.I18N("ui.settings.option.factory"),
			name = BAR.I18N("ui.settings.option.factoryguard"),
			type = "bool",
			value = GetWidgetToggleValue("Factory Guard Default On"),
			description = BAR.I18N("ui.settings.option.factoryguard_descr"),
		},
		{
			id = "factoryholdpos",
			parent = "factoryguard",
			group = "game",
			category = types.basic,
			widget = "Factory hold position",
			name = BAR.I18N("ui.settings.option.factoryholdpos"),
			type = "bool",
			value = GetWidgetToggleValue("Factory hold position"),
			description = BAR.I18N("ui.settings.option.factoryholdpos_descr"),
		},
		{
			id = "factoryrepeat",
			parent = "factoryguard",
			group = "game",
			category = types.basic,
			widget = "Factory Auto-Repeat",
			name = BAR.I18N("ui.settings.option.factoryrepeat"),
			type = "bool",
			value = GetWidgetToggleValue("Factory Auto-Repeat"),
			description = BAR.I18N("ui.settings.option.factoryrepeat_descr"),
		},
		{
			id = "factorypreset",
			group = "game",
			category = types.basic,
			widget = "FactoryQ Manager",
			name = BAR.I18N("ui.settings.option.factorypreset"),
			type = "bool",
			value = GetWidgetToggleValue("FactoryQ Manager"),
			description = BAR.I18N("ui.settings.option.factorypreset_descr"),
		},

		{
			id = "transportOrderedUnits",
			group = "game",
			category = types.basic,
			name = "Ferry ignores units with manual orders",
			type = "bool",
			value = (
				WG.transportFactoryGuard ~= nil
				and WG.transportFactoryGuard.getBlacklistOrderedUnits ~= nil
				and WG.transportFactoryGuard.getBlacklistOrderedUnits()
			),
			description = "If enabled, transports guarding factories will not transport units that were given explicit orders during construction to their move waypoint.",
			onload = function(option)
				loadWidgetData("Transport Factory Guard", "transportOrderedUnits", { "blacklistOrderedUnits" })
			end,
			onchange = function(_, value)
				saveOptionValue(
					"Transport Factory Guard",
					"transportFactoryGuard",
					"setBlacklistOrderedUnits",
					{ "blacklistOrderedUnits" },
					value
				)
				if WG.transportFactoryGuard and WG.transportFactoryGuard.setBlacklistOrderedUnits then
					WG.transportFactoryGuard.setBlacklistOrderedUnits(value)
				end
			end,
		},

		{
			id = "onlyfighterspatrol",
			group = "game",
			category = types.basic,
			widget = "OnlyFightersPatrol",
			name = BAR.I18N("ui.settings.option.onlyfighterspatrol"),
			type = "bool",
			value = GetWidgetToggleValue("OnlyFightersPatrol"),
			description = BAR.I18N("ui.settings.option.onlyfighterspatrol_descr"),
		},
		{
			id = "bombers_default_hold_fire",
			group = "game",
			category = types.basic,
			widget = "BombersDefaultHoldFire",
			name = BAR.I18N("ui.settings.option.bombers_default_hold_fire"),
			type = "bool",
			value = GetWidgetToggleValue("BombersDefaultHoldFire"),
			description = BAR.I18N("ui.settings.option.bombers_default_hold_fire_descr"),
		},
		{
			id = "fightersfly",
			group = "game",
			category = types.basic,
			widget = "Set fighters on Fly mode",
			name = BAR.I18N("ui.settings.option.fightersfly"),
			type = "bool",
			value = GetWidgetToggleValue("Set fighters on Fly mode"),
			description = BAR.I18N("ui.settings.option.fightersfly_descr"),
		},

		{
			id = "settargetdefault",
			group = "game",
			category = types.basic,
			widget = "Set target default",
			name = BAR.I18N("ui.settings.option.settargetdefault"),
			type = "bool",
			value = GetWidgetToggleValue("Set target default"),
			description = BAR.I18N("ui.settings.option.settargetdefault_descr"),
		},
		{
			id = "dgunnogroundenemies",
			group = "game",
			category = types.advanced,
			widget = "DGun no ground enemies",
			name = BAR.I18N("ui.settings.option.dgunnogroundenemies"),
			type = "bool",
			value = GetWidgetToggleValue("DGun no ground enemies"),
			description = BAR.I18N("ui.settings.option.dgunnogroundenemies_descr"),
		},
		{
			id = "dgunstallassist",
			group = "game",
			category = types.advanced,
			widget = "DGun Stall Assist",
			name = BAR.I18N("ui.settings.option.dgunstallassist"),
			type = "bool",
			value = GetWidgetToggleValue("DGun Stall Assist"),
			description = BAR.I18N("ui.settings.option.dgunstallassist_descr"),
		},

		{
			id = "autogroup_immediate",
			group = "game",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.autogroup_immediate"),
			type = "bool",
			value = (WG.autogroup ~= nil and WG.autogroup.getImmediate ~= nil and WG.autogroup.getImmediate()),
			description = BAR.I18N("ui.settings.option.autogroup_immediate_descr"),
			onload = function(option)
				loadWidgetData("Auto Group", "autogroup_immediate", { "immediate" })
			end,
			onchange = function(option, value)
				if widgetHandler.configData["Auto Group"] == nil then
					widgetHandler.configData["Auto Group"] = {}
				end
				widgetHandler.configData["Auto Group"].immediate = value
				saveOptionValue("Auto Group", "autogroup", "setImmediate", { "immediate" }, value)
			end,
		},

		{
			id = "autogroup_persist",
			group = "game",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.autogroup_persist"),
			type = "bool",
			value = (WG.autogroup ~= nil and WG.autogroup.getPersist ~= nil and WG.autogroup.getPersist()),
			description = BAR.I18N("ui.settings.option.autogroup_persist_descr"),
			onload = function(option)
				loadWidgetData("Auto Group", "autogroup_persist", { "persist" })
			end,
			onchange = function(option, value)
				if widgetHandler.configData["Auto Group"] == nil then
					widgetHandler.configData["Auto Group"] = {}
				end
				widgetHandler.configData["Auto Group"].persist = value
				saveOptionValue("Auto Group", "autogroup", "setPersist", { "persist" }, value)
			end,
		},
		{
			id = "quickstartsuggestions",
			group = "game",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.quickstartsuggestions"),
			type = "bool",
			value = Spring.GetConfigInt("QuickStartSuggestions", 1) == 1,
			description = BAR.I18N("ui.settings.option.quickstartsuggestions_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("QuickStartSuggestions", value and 1 or 0)
				if WG.quickStart and WG.quickStart.setAutoGenerateSuggestions then
					WG.quickStart.setAutoGenerateSuggestions(value)
				end
			end,
		},

		{
			id = "label_ui_cloak",
			group = "game",
			name = BAR.I18N("ui.settings.option.label_cloak"),
			category = types.basic,
		},

		{
			id = "autocloak",
			group = "game",
			category = types.basic,
			widget = "Auto Cloak Units",
			name = BAR.I18N("ui.settings.option.autocloak"),
			type = "bool",
			value = GetWidgetToggleValue("Auto Cloak Units"),
		},

		-- SQUAD SELECTION (widget: "Squad Selection", WG['squadselection'])
		{
			id = "label_squad",
			group = "game",
			name = BAR.I18N("ui.settings.option.squadSelection_header"),
			category = types.basic,
		},

		-- Playstyle preset. Off disables the widgets entirely (the default), every other value enables them and writes the settings it owns.
		{
			id = "squad_preset",
			group = "game",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.squadSelection_preset"),
			type = "select",
			options = {
				BAR.I18N("ui.settings.option.squadSelection_preset_opt1"),
				BAR.I18N("ui.settings.option.squadSelection_preset_opt2"),
				BAR.I18N("ui.settings.option.squadSelection_preset_opt3"),
				BAR.I18N("ui.settings.option.squadSelection_preset_opt4"),
				BAR.I18N("ui.settings.option.squadSelection_preset_opt5"),
			},
			value = squadPreset.index[squadPreset.get()] or 1,
			description = BAR.I18N("ui.settings.option.squadSelection_preset_descr"),
			onload = function(option)
				option.value = squadPreset.index[squadPreset.get()] or 1
			end,
			onchange = function(_, value)
				-- Toggles widgets, so it schedules the rebuild for next frame rather than rebuilding here. See squadPreset.apply().
				squadPreset.apply(squadPreset.names[value] or "off")
			end,
		},

		{
			id = "squad_cyclingToNextSquad",
			group = "game",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.squadSelection_cyclingToNextSquad"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.squadSelection_cyclingToNextSquad_descr"),
			widgetConfig = {
				"Squad Selection",
				"cyclingToNextSquad",
				api = "squadselection",
				get = "getCyclingToNextSquad",
				set = "setCyclingToNextSquad",
			},
		},

		{
			id = "squad_leftClickSelectsSquad",
			group = "game",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.squadSelection_leftClickSelectsSquad"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.squadSelection_leftClickSelectsSquad_descr"),
			widgetConfig = {
				"Squad Selection",
				"leftClickSelectsSquad",
				api = "squadselection",
				get = "getLeftClickSelectsSquad",
				set = "setLeftClickSelectsSquad",
			},
		},

		{
			id = "squad_leftClickAlternativeSelection",
			parent = "squad_leftClickSelectsSquad",
			group = "game",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.squadSelection_leftClickAlternativeSelection"),
			type = "bool",
			value = squadSelectValue.get("getLeftClickAlternativeSelection") or false,
			description = BAR.I18N("ui.settings.option.squadSelection_leftClickAlternativeSelection_descr"),
			onload = function(option)
				loadWidgetData(
					"Squad Selection",
					"squad_leftClickAlternativeSelection",
					{ "leftClickAlternativeSelection" }
				)
			end,
			onchange = function(_, value)
				saveOptionValue(
					"Squad Selection",
					"squadselection",
					"setLeftClickAlternativeSelection",
					{ "leftClickAlternativeSelection" },
					value
				)
			end,
		},

		-- Synthetic select owning the three mutually-exclusive rightClick* booleans.
		{
			id = "squad_squadCreateMethod",
			group = "game",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.squadSelection_squadCreateMethod"),
			type = "select",
			options = {
				BAR.I18N("ui.settings.option.squadSelection_squadCreateMethod_opt1"),
				BAR.I18N("ui.settings.option.squadSelection_squadCreateMethod_opt2"),
				BAR.I18N("ui.settings.option.squadSelection_squadCreateMethod_opt3"),
				BAR.I18N("ui.settings.option.squadSelection_squadCreateMethod_opt4"),
			},
			value = squadSelectValue.squadCreateMethod(),
			description = BAR.I18N("ui.settings.option.squadSelection_squadCreateMethod_descr"),
			onload = function(option)
				option.value = squadSelectValue.squadCreateMethod()
			end,
			onchange = function(_, value)
				saveOptionValue(
					"Squad Selection",
					"squadselection",
					"setRightClickSquadCreate",
					{ "rightClickSquadCreate" },
					value == 2
				)
				saveOptionValue(
					"Squad Selection",
					"squadselection",
					"setCtrlRightClickCreatesSquad",
					{ "ctrlRightClickCreatesSquad" },
					value == 3
				)
				saveOptionValue(
					"Squad Selection",
					"squadselection",
					"setCtrlRightClickDragCreatesSquad",
					{ "ctrlRightClickDragCreatesSquad" },
					value == 4
				)
			end,
		},

		{
			id = "squad_rightClickMovesSquad",
			group = "game",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.squadSelection_rightClickMovesSquad"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.squadSelection_rightClickMovesSquad_descr"),
			widgetConfig = {
				"Squad Selection",
				"rightClickMovesSquad",
				api = "squadselection",
				get = "getRightClickMovesSquad",
				set = "setRightClickMovesSquad",
			},
		},

		-- Synthetic select owning the rightClickMoveControlsReserves boolean.
		{
			id = "squad_rightClickMoveControlsReserves",
			parent = "squad_rightClickMovesSquad",
			group = "game",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.squadSelection_rightClickMoveControlsReserves"),
			type = "select",
			options = {
				BAR.I18N("ui.settings.option.squadSelection_rightClickMoveControlsReserves_opt1"),
				BAR.I18N("ui.settings.option.squadSelection_rightClickMoveControlsReserves_opt2"),
			},
			value = squadSelectValue.rightClickMoveControlsReserves(),
			description = BAR.I18N("ui.settings.option.squadSelection_rightClickMoveControlsReserves_descr"),
			onload = function(option)
				option.value = squadSelectValue.rightClickMoveControlsReserves()
			end,
			onchange = function(_, value)
				saveOptionValue(
					"Squad Selection",
					"squadselection",
					"setRightClickMoveControlsReserves",
					{ "rightClickMoveControlsReserves" },
					value == 2
				)
			end,
		},

		{
			id = "squad_mergeIntoReserves",
			group = "game",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.squadSelection_mergeIntoReserves"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.squadSelection_mergeIntoReserves_descr"),
			widgetConfig = {
				"Squad Selection",
				"mergeIntoReserves",
				api = "squadselection",
				get = "getMergeIntoReserves",
				set = "setMergeIntoReserves",
			},
		},

		{
			id = "squad_mruSize",
			group = "game",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.squadSelection_mruSize"),
			type = "slider",
			min = 1,
			max = 9,
			step = 1,
			value = 3,
			description = BAR.I18N("ui.settings.option.squadSelection_mruSize_descr"),
			widgetConfig = {
				"Squad Selection",
				"mruSize",
				api = "squadselection",
				get = "getMruSize",
				set = "setMruSize",
			},
		},

		{
			id = "squad_excludeConstructors",
			group = "game",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.squadSelection_excludeConstructors"),
			type = "bool",
			value = squadSelectValue.get("getExcludeConstructors") or false,
			description = BAR.I18N("ui.settings.option.squadSelection_excludeConstructors_descr"),
			onload = function(option)
				loadWidgetData("Squad Selection", "squad_excludeConstructors", { "excludeConstructors" })
			end,
			onchange = function(_, value)
				saveOptionValue(
					"Squad Selection",
					"squadselection",
					"setExcludeConstructors",
					{ "excludeConstructors" },
					value
				)
				if WG["squadselection"] ~= nil and WG["squadselection"].rebuildTracking ~= nil then
					WG["squadselection"].rebuildTracking()
				end
			end,
		},

		{
			id = "squad_excludeResurrectionUnits",
			group = "game",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.squadSelection_excludeResurrectionUnits"),
			type = "bool",
			value = squadSelectValue.get("getExcludeResurrectionUnits") or false,
			description = BAR.I18N("ui.settings.option.squadSelection_excludeResurrectionUnits_descr"),
			onload = function(option)
				loadWidgetData("Squad Selection", "squad_excludeResurrectionUnits", { "excludeResurrectionUnits" })
			end,
			onchange = function(_, value)
				saveOptionValue(
					"Squad Selection",
					"squadselection",
					"setExcludeResurrectionUnits",
					{ "excludeResurrectionUnits" },
					value
				)
				if WG["squadselection"] ~= nil and WG["squadselection"].rebuildTracking ~= nil then
					WG["squadselection"].rebuildTracking()
				end
			end,
		},

		{
			id = "squad_excludeCombatEngineers",
			group = "game",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.squadSelection_excludeCombatEngineers"),
			type = "bool",
			value = squadSelectValue.get("getExcludeCombatEngineers") or false,
			description = BAR.I18N("ui.settings.option.squadSelection_excludeCombatEngineers_descr"),
			onload = function(option)
				loadWidgetData("Squad Selection", "squad_excludeCombatEngineers", { "excludeCombatEngineers" })
			end,
			onchange = function(_, value)
				saveOptionValue(
					"Squad Selection",
					"squadselection",
					"setExcludeCombatEngineers",
					{ "excludeCombatEngineers" },
					value
				)
				if WG["squadselection"] ~= nil and WG["squadselection"].rebuildTracking ~= nil then
					WG["squadselection"].rebuildTracking()
				end
			end,
		},
	}
end
