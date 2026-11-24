-- The squad selection settings: their playstyle presets, and the selects that merge several of the
-- widget's settings into one.
return function(model)
	local GetWidgetToggleValue, saveOptionValue = model.GetWidgetToggleValue, model.saveOptionValue

	-- Lookups for the squad selects that merge several widget settings into select inputs.
	local squadSelectValue = {}

	function squadSelectValue.get(getterName)
		local api = WG["squadselection"]
		if api == nil or api[getterName] == nil then
			return nil
		end
		return api[getterName]()
	end

	function squadSelectValue.hullDisplayMode()
		if squadSelectValue.get("getVisualizationMode") ~= "convexHull" then
			return 1
		end
		if squadSelectValue.get("getShowReserveSquads") then
			return 2
		end
		return 3
	end

	function squadSelectValue.squadColorMode()
		local mode = squadSelectValue.get("getSquadColorMode")
		if mode == "custom" then
			return 2
		end
		if mode == "squad" then
			return 3
		end
		return 1
	end

	function squadSelectValue.squadCreateMethod()
		if squadSelectValue.get("getRightClickSquadCreate") then
			return 2
		end
		if squadSelectValue.get("getCtrlRightClickCreatesSquad") then
			return 3
		end
		if squadSelectValue.get("getCtrlRightClickDragCreatesSquad") then
			return 4
		end
		return 1
	end

	-- the custom squad color, from the widget's three channels
	function squadSelectValue.customColor()
		local color = { 0, 0.3, 0.7 }
		for i, channel in ipairs({ "R", "G", "B" }) do
			local value = squadSelectValue.get("getSquadCustomColor" .. channel)
			if type(value) == "number" then
				color[i] = value
			end
		end
		return color
	end

	function squadSelectValue.rightClickMoveControlsReserves()
		if squadSelectValue.get("getRightClickMoveControlsReserves") then
			return 2
		end
		return 1
	end

	-------------------------------------------------------------------------------
	-- Squad selection presets
	--
	-- The Squad Selection widget supports several playstyles, and each one wants a different set of its switches. Rather than show every switch to everyone, the panel offers a playstyle preset: picking one writes the settings that preset owns and hides their rows. Custom owns nothing and shows the full list.

	local squadPreset = {
		-- The playstyle definitions, shared with the widget.
		definitions = VFS.Include("luaui/Include/squad_selection_presets.lua"),

		-- Rows for settings a preset owns; hidden unless the preset is Custom.
		ownedOptions = {
			"squad_cyclingToNextSquad",
			"squad_leftClickAlternativeSelection",
			"squad_squadCreateMethod",
			"squad_rightClickMoveControlsReserves",
			"squad_mergeIntoReserves",
		},

		allOptions = {
			"squad_cyclingToNextSquad",
			"squad_leftClickSelectsSquad",
			"squad_leftClickAlternativeSelection",
			"squad_squadCreateMethod",
			"squad_rightClickMovesSquad",
			"squad_rightClickMoveControlsReserves",
			"squad_mergeIntoReserves",
			"squad_mruSize",
			"squad_excludeConstructors",
			"squad_excludeResurrectionUnits",
			"squad_excludeCombatEngineers",
			"label_squad_hulls",
			"squad_hullDisplayMode",
			"squad_convexHullPadding",
			"squad_convexHullArcResolution",
			"squad_convexHullFillOpacity",
			"squad_convexHullBorderOpacity",
			"squad_convexHullBorderThickness",
			"squad_convexHullColorMode",
			"squad_convexHullCustomColor",
		},

		-- Rows that only make sense while the hull widget itself is running.
		hullOptions = {
			"squad_convexHullPadding",
			"squad_convexHullArcResolution",
			"squad_convexHullFillOpacity",
			"squad_convexHullBorderOpacity",
			"squad_convexHullBorderThickness",
			"squad_convexHullColorMode",
			"squad_convexHullCustomColor",
		},
	}
	-- Index-aligned with the squad_preset select's option labels. 'off' is not a preset but the widget being disabled, so it leads the shared list.
	squadPreset.names = { "off" }
	for _, name in ipairs(squadPreset.definitions.names) do
		squadPreset.names[#squadPreset.names + 1] = name
	end
	squadPreset.index = table.invert(squadPreset.names)

	-- The widget is unloaded while the preset is Off
	function squadPreset.get()
		if not GetWidgetToggleValue("Squad Selection") then
			return "off"
		end
		local preset = squadSelectValue.get("getPreset")
		if preset ~= nil then
			return preset
		end
		local data = widgetHandler.configData["Squad Selection"]
		return (data and data.preset) or "custom"
	end

	function squadPreset.apply(name)
		if name == "off" then
			if GetWidgetToggleValue("Squad Selection Hull") then
				widgetHandler:DisableWidget("Squad Selection Hull")
			end
			if GetWidgetToggleValue("Squad Selection") then
				widgetHandler:DisableWidget("Squad Selection")
			end
			model.scheduleInit = true
			return
		end

		-- The two widgets are a pair: the hull widget only draws state the main one owns, so a preset enables and disables both.
		if not GetWidgetToggleValue("Squad Selection") then
			widgetHandler:EnableWidget("Squad Selection")
		end
		if not GetWidgetToggleValue("Squad Selection Hull") then
			widgetHandler:EnableWidget("Squad Selection Hull")
		end

		for key, value in pairs(squadPreset.definitions.values[name] or {}) do
			saveOptionValue(
				"Squad Selection",
				"squadselection",
				"set" .. key:sub(1, 1):upper() .. key:sub(2),
				{ key },
				value
			)
		end
		saveOptionValue("Squad Selection", nil, nil, { "preset" }, name)

		local api = WG["squadselection"]
		if api ~= nil and api.applyPreset ~= nil then
			api.applyPreset(name)
		end

		model.scheduleInit = true
	end

	return squadPreset, squadSelectValue
end
