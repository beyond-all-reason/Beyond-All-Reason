-- The interface tab's settings. model.lua says what a row can hold.

local languageCodes = { "en", "fr", "ru", "es" }
languageCodes = table.merge(languageCodes, table.invert(languageCodes))

local languageNames = {}
for key, code in ipairs(languageCodes) do
	languageNames[key] = BAR.I18N.languages[code]
end

local reclaimFieldHighlightOptions = {
	BAR.I18N("ui.settings.option.reclaimfieldhighlight_always"),
	BAR.I18N("ui.settings.option.reclaimfieldhighlight_resource"),
	BAR.I18N("ui.settings.option.reclaimfieldhighlight_reclaimer"),
	BAR.I18N("ui.settings.option.reclaimfieldhighlight_resbot"),
	BAR.I18N("ui.settings.option.reclaimfieldhighlight_order"),
	BAR.I18N("ui.settings.option.reclaimfieldhighlight_disabled"),
}

local spectatorHUDConfigOptions = {
	BAR.I18N("ui.settings.option.spectator_hud_config_basic"),
	BAR.I18N("ui.settings.option.spectator_hud_config_advanced"),
	BAR.I18N("ui.settings.option.spectator_hud_config_expert"),
	BAR.I18N("ui.settings.option.spectator_hud_config_custom"),
}

return function(model)
	local types = model.types
	local init = model.init
	local saveOptionValue = model.saveOptionValue
	local loadWidgetData = model.loadWidgetData
	local GetWidgetToggleValue = model.GetWidgetToggleValue
	local squadSelectValue = model.squadSelectValue

	local hasUserWidgets = false
	for _, data in pairs(widgetHandler.knownWidgets) do
		if not data.fromZip then
			hasUserWidgets = true
		end
	end
	local aiDetected = false
	for _, teamID in ipairs(Spring.GetTeamList()) do
		if select(4, Spring.GetTeamInfo(teamID, false)) then
			aiDetected = true
		end
	end
	local gridMenuOn = model.GridLayoutOn()

	return {
		-- INTERFACE
		{
			id = "label_ui_interface",
			group = "ui",
			name = BAR.I18N("ui.settings.option.label_interface"),
			category = types.basic,
		},
		{
			id = "language",
			group = "ui",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.language"),
			type = "select",
			options = languageNames,
			value = languageCodes[BAR.I18N.getLocale()],
			onchange = function(option, value)
				local language = languageCodes[value]
				WG.language.setLanguage(language)
				if widgetHandler.orderList.Notifications ~= nil then
					widgetHandler:DisableWidget("Notifications")
					widgetHandler:EnableWidget("Notifications")
					init()
				end
			end,
		},
		{
			id = "language_english_unit_names",
			parent = "language",
			group = "ui",
			category = types.basic,
			available = BAR.I18N.getLocale() ~= "en",
			name = BAR.I18N("ui.settings.option.language_english_unit_names"),
			type = "bool",
			value = Spring.GetConfigInt("language_english_unit_names", 0) == 1,
			onchange = function(option, value)
				WG.language.setEnglishUnitNames(value)
			end,
		},
		{
			id = "uiscale",
			group = "ui",
			category = types.basic,
			prefix = BAR.I18N("ui.settings.option.interface"),
			name = BAR.I18N("ui.settings.option.uiscale"),
			type = "slider",
			min = 0.8,
			max = 1.3,
			step = 0.01,
			value = Spring.GetConfigFloat("ui_scale", 1),
			description = "",
			onchange = function(option, value, force)
				if force then
					Spring.SetConfigFloat("ui_scale", value)
					Spring.SendCommands("luarules reloadluaui")
				else
					model.scheduledApply = { os.clock() + 1.5, "uiscale" }
				end
			end,
		},
		{
			id = "guiopacity",
			parent = "uiscale",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.guiopacity"),
			type = "slider",
			min = 0.3,
			max = 1,
			step = 0.01,
			value = Spring.GetConfigFloat("ui_opacity", 0.7),
			description = "",
			onchange = function(option, value, force)
				Spring.SetConfigFloat("ui_opacity", value)
				ui_opacity = Spring.GetConfigFloat("ui_opacity", 0.7)
				model.forceUpdate = true

				if force then
					Spring.SetConfigFloat("ui_opacity", value)
					Spring.SendCommands("luarules reloadluaui")
				else
					model.scheduledApply = { os.clock() + 1.5, "guiopacity" }
				end
			end,
		},
		{
			id = "guitilescale",
			parent = "uiscale",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.guitilescale"),
			type = "slider",
			min = 4,
			max = 40,
			step = 1,
			value = Spring.GetConfigFloat("ui_tilescale", 7),
			description = "",
			onchange = function(option, value, force)
				if force then
					Spring.SetConfigFloat("ui_tilescale", value)
					Spring.SendCommands("luarules reloadluaui")
				else
					model.scheduledApply = { os.clock() + 1.5, "guitilescale" }
				end
			end,
		},
		{
			id = "guitileopacity",
			parent = "guitilescale",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.guitileopacity"),
			type = "slider",
			min = 0,
			max = 0.03,
			step = 0.001,
			value = Spring.GetConfigFloat("ui_tileopacity", 0.014),
			description = "",
			onchange = function(option, value, force)
				if force then
					Spring.SetConfigFloat("ui_tileopacity", value)
					Spring.SendCommands("luarules reloadluaui")
				else
					model.scheduledApply = { os.clock() + 1.5, "guitileopacity" }
				end
			end,
		},

		{
			id = "supersample",
			parent = "uiscale",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.supersample"),
			type = "select",
			options = {
				BAR.I18N("ui.settings.option.supersample_auto"),
				BAR.I18N("ui.settings.option.supersample_off"),
				BAR.I18N("ui.settings.option.supersample_2x"),
			},
			value = (Spring.GetConfigInt("ui_supersample", 2) or 2) + 1,
			description = BAR.I18N("ui.settings.option.supersample_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("ui_supersample", value - 1) -- 0 auto, 1 off, 2 always 2x (default)
				Spring.SendCommands("luarules reloadluaui") -- the widgets size their textures by it at start
			end,
		},

		{
			id = "guishader",
			parent = "uiscale",
			group = "ui",
			category = types.basic,
			widget = "GUI Shader",
			name = BAR.I18N("ui.settings.option.guishader"),
			type = "bool",
			value = GetWidgetToggleValue("GUI Shader"),
		},

		{
			id = "minimap_maxheight",
			group = "ui",
			category = types.advanced,
			prefix = BAR.I18N("ui.settings.option.minimap"),
			name = BAR.I18N("ui.settings.option.minimap_maxheight"),
			type = "slider",
			min = 0.2,
			max = 0.4,
			step = 0.01,
			value = Spring.GetConfigFloat("MinimapMaxHeight", 0.32),
			description = BAR.I18N("ui.settings.option.minimap_maxheight_descr"),
			onchange = function(option, value)
				Spring.SetConfigFloat("MinimapMaxHeight", value)
				if WG.minimap and WG.minimap.setMaxHeight then
					WG.minimap.setMaxHeight(value)
				end
			end,
		},
		{
			id = "minimapleftclick",
			parent = "minimap_maxheight",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.minimapleftclick"),
			type = "bool",
			value = Spring.GetConfigInt("MinimapLeftClickMove", 1) == 1,
			description = BAR.I18N("ui.settings.option.minimapleftclick_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("MinimapLeftClickMove", value and 1 or 0)
				if WG.minimap and WG.minimap.setLeftClickMove then
					WG.minimap.setLeftClickMove(value)
				end
			end,
		},
		{
			id = "minimapiconsize",
			parent = "minimap_maxheight",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.minimapiconsize"),
			type = "slider",
			min = 2,
			max = 5,
			step = 0.25,
			value = tonumber(Spring.GetConfigFloat("MinimapIconScale", 3.5) or 1),
			description = "",
			onchange = function(option, value)
				Spring.SetConfigFloat("MinimapIconScale", value)
				Spring.SendCommands("minimap unitsize " .. value) -- spring won't remember what you set with '/minimap iconssize #'
				if WG.minimap and WG.minimap.setBaseIconScale then
					WG.minimap.setBaseIconScale(value)
				end
			end,
		},
		{
			id = "minimap_minimized",
			parent = "minimap_maxheight",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.minimapminimized"),
			type = "bool",
			value = Spring.GetConfigInt("MinimapMinimize", 0) == 1,
			description = BAR.I18N("ui.settings.option.minimapminimized_descr"),
			onchange = function(option, value)
				Spring.SendCommands("minimap minimize " .. (value and "1" or "0"))
				Spring.SetConfigInt("MinimapMinimize", (value and "1" or "0"))
			end,
		},
		{
			id = "minimaprotation",
			parent = "minimap_maxheight",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.minimaprotation"),
			type = "select",
			options = {
				BAR.I18N("ui.settings.option.minimaprotation_none"),
				BAR.I18N("ui.settings.option.minimaprotation_autoflip"),
				BAR.I18N("ui.settings.option.minimaprotation_autorotate"),
				BAR.I18N("ui.settings.option.minimaprotation_autolandscape"),
			},
			description = BAR.I18N("ui.settings.option.minimaprotation_descr"),
			onload = function(option)
				loadWidgetData("Minimap Rotation Manager", "minimaprotation", { "mode" })
				if option.value == nil then -- first load to migrate from old behavior smoothly, might wanna remove it later
					option.value = Spring.GetConfigInt("MiniMapCanFlip", 0) + 1
				end
			end,
			onchange = function(option, value)
				if WG.minimaprotationmanager ~= nil and WG.minimaprotationmanager.setMode ~= nil then
					saveOptionValue("Minimap Rotation Manager", "minimaprotationmanager", "setMode", { "mode" }, value)
				else
					widgetHandler:EnableWidget("Minimap Rotation Manager") -- Widget has auto sync
				end
			end,
		},
		{
			id = "minimappip",
			parent = "minimap_maxheight",
			group = "ui",
			category = types.advanced,
			widget = "Picture-in-Picture Minimap",
			name = BAR.I18N("ui.settings.option.minimappip"),
			type = "bool",
			value = GetWidgetToggleValue("Picture-in-Picture Minimap"),
			description = BAR.I18N("ui.settings.option.minimappip_descr"),
		},
		{
			id = "pip_altkeyzoom",
			parent = "minimappip",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.pip_altkeyzoom"),
			type = "bool",
			value = Spring.GetConfigInt("PipAltKeyRequiredForZoom", 1) == 1,
			description = BAR.I18N("ui.settings.option.pip_altkeyzoom_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("PipAltKeyRequiredForZoom", value and 1 or 0)
				for _, n in ipairs({ 0, 1, 2, 3, 4 }) do
					if WG["pip" .. n] and WG["pip" .. n].setAltKeyRequiredForZoom then
						WG["pip" .. n].setAltKeyRequiredForZoom(value)
					end
				end
			end,
		},

		{
			id = "pip_commandfx",
			parent = "minimappip",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.pip_commandfx"),
			type = "bool",
			value = Spring.GetConfigInt("PipDrawCommandFX", 1) == 1,
			description = BAR.I18N("ui.settings.option.pip_commandfx_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("PipDrawCommandFX", value and 1 or 0)
				for _, n in ipairs({ 0, 1, 2, 3, 4 }) do
					if WG["pip" .. n] and WG["pip" .. n].setDrawCommandFX then
						WG["pip" .. n].setDrawCommandFX(value)
					end
				end
			end,
		},
		{
			id = "pip_nanostreams",
			parent = "minimappip",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.pip_nanostreams"),
			type = "bool",
			value = Spring.GetConfigInt("PipDrawNanoStreams", 1) == 1,
			description = BAR.I18N("ui.settings.option.pip_nanostreams_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("PipDrawNanoStreams", value and 1 or 0)
				for _, n in ipairs({ 0, 1, 2, 3, 4 }) do
					if WG["pip" .. n] and WG["pip" .. n].setDrawNanoStreams then
						WG["pip" .. n].setDrawNanoStreams(value)
					end
				end
			end,
		},
		{
			id = "pip_nanostream_usage",
			parent = "minimappip",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.pip_nanostream_usage"),
			type = "bool",
			value = Spring.GetConfigInt("PipNanoStreamReflectUsage", 1) == 1,
			description = BAR.I18N("ui.settings.option.pip_nanostream_usage_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("PipNanoStreamReflectUsage", value and 1 or 0)
				for _, n in ipairs({ 0, 1, 2, 3, 4 }) do
					if WG["pip" .. n] and WG["pip" .. n].setNanoStreamReflectUsage then
						WG["pip" .. n].setNanoStreamReflectUsage(value)
					end
				end
			end,
		},
		{
			id = "pip_mapdrawings",
			parent = "minimappip",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.pip_mapdrawings"),
			type = "bool",
			value = Spring.GetConfigInt("PipShowMapDrawings", 1) == 1,
			description = BAR.I18N("ui.settings.option.pip_mapdrawings_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("PipShowMapDrawings", value and 1 or 0)
				for _, n in ipairs({ 0, 1, 2, 3, 4 }) do
					if WG["pip" .. n] and WG["pip" .. n].setShowMapDrawings then
						WG["pip" .. n].setShowMapDrawings(value)
					end
				end
			end,
		},
		{
			id = "pip_mapdrawing_duration",
			parent = "minimappip",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.pip_mapdrawing_duration"),
			type = "slider",
			min = 1,
			max = 60,
			step = 1,
			value = Spring.GetConfigFloat("PipMapDrawingDuration", 15),
			description = BAR.I18N("ui.settings.option.pip_mapdrawing_duration_descr"),
			onchange = function(option, value)
				Spring.SetConfigFloat("PipMapDrawingDuration", value)
				for _, n in ipairs({ 0, 1, 2, 3, 4 }) do
					if WG["pip" .. n] and WG["pip" .. n].setMapDrawingDuration then
						WG["pip" .. n].setMapDrawingDuration(value)
					end
				end
			end,
		},
		{
			id = "pip_history",
			parent = "minimappip",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.pip_history"),
			type = "bool",
			value = true,
			description = BAR.I18N("ui.settings.option.pip_history_descr"),
			onload = function(option)
				for _, n in ipairs({ 0, 1, 2, 3, 4 }) do
					if WG["pip" .. n] and WG["pip" .. n].getHistoryEnabled then
						option.value = WG["pip" .. n].getHistoryEnabled()
						break
					end
				end
			end,
			onchange = function(option, value)
				for _, n in ipairs({ 0, 1, 2, 3, 4 }) do
					if WG["pip" .. n] and WG["pip" .. n].setHistoryEnabled then
						WG["pip" .. n].setHistoryEnabled(value)
					end
				end
			end,
		},
		-- { id = "minimap_engine_fallback", group = "ui", category = types.advanced, name = widgetOptionColor .. "      " .. Spring.I18N('ui.settings.option.pip_minimap_engine_fallback'), type = "bool", value = false, description = Spring.I18N('ui.settings.option.pip_minimap_engine_fallback_descr'),
		--   onload = function(option)
		-- 	  if WG['minimap'] and WG['minimap'].getEngineMinimapFallback then
		-- 		  getOption('minimap_engine_fallback').value = WG['minimap'].getEngineMinimapFallback()
		-- 	  end
		--   end,
		--   onchange = function(option, value)
		-- 	  if WG['minimap'] and WG['minimap'].setEngineMinimapFallback then
		-- 		  WG['minimap'].setEngineMinimapFallback(value)
		-- 	  end
		--   end,
		-- },
		{
			id = "pip_engine_fallback_threshold",
			parent = "minimappip",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.pip_engine_fallback_threshold"),
			type = "slider",
			min = 1500,
			max = 5000,
			step = 100,
			value = 4000,
			description = BAR.I18N("ui.settings.option.pip_engine_fallback_threshold_descr"),
			onload = function(option)
				if WG.minimap and WG.minimap.getEngineMinimapFallbackThreshold then
					option.value = WG.minimap.getEngineMinimapFallbackThreshold()
				end
			end,
			onchange = function(option, value)
				if WG.minimap and WG.minimap.setEngineMinimapFallbackThreshold then
					WG.minimap.setEngineMinimapFallbackThreshold(value)
				end
			end,
		},

		{
			id = "pip",
			group = "ui",
			category = types.advanced,
			widget = "Picture-in-Picture",
			name = BAR.I18N("ui.settings.option.pip"),
			type = "bool",
			value = GetWidgetToggleValue("Picture-in-Picture"),
			description = BAR.I18N("ui.settings.option.pip_descr"),
		},
		{
			id = "pip2",
			group = "ui",
			category = types.advanced,
			widget = "Picture-in-Picture 2",
			name = BAR.I18N("ui.settings.option.pip2"),
			type = "bool",
			value = GetWidgetToggleValue("Picture-in-Picture 2"),
			description = BAR.I18N("ui.settings.option.pip2_descr"),
		},

		{
			id = "buildmenu_bottom",
			group = "ui",
			category = types.basic,
			prefix = BAR.I18N("ui.settings.option.buildmenu"),
			name = BAR.I18N("ui.settings.option.buildmenu_bottom"),
			type = "bool",
			value = (
				WG.buildmenu ~= nil
				and WG.buildmenu.getBottomPosition ~= nil
				and WG.buildmenu.getBottomPosition()
			),
			description = BAR.I18N("ui.settings.option.buildmenu_bottom_descr"),
			onchange = function(option, value)
				saveOptionValue("Build menu", "buildmenu", "setBottomPosition", { "stickToBottom" }, value)
				saveOptionValue("Grid menu", "buildmenu", "setBottomPosition", { "stickToBottom" }, value)
			end,
		},
		{
			id = "buildmenu_maxposy",
			parent = "buildmenu_bottom",
			group = "ui",
			category = types.advanced,
			available = not gridMenuOn, -- the grid menu has a fixed height
			name = BAR.I18N("ui.settings.option.buildmenu_maxposy"),
			type = "slider",
			min = 0.66,
			max = 0.88,
			step = 0.01,
			value = 0.74,
			description = BAR.I18N("ui.settings.option.buildmenu_maxposy_descr"),
			widgetConfig = { "Build menu", "maxPosY", api = "buildmenu", set = "setMaxPosY" },
		},
		{
			id = "buildmenu_alwaysshow",
			parent = "buildmenu_bottom",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.buildmenu_alwaysshow"),
			type = "bool",
			value = (WG.buildmenu ~= nil and WG.buildmenu.getAlwaysShow ~= nil and WG.buildmenu.getAlwaysShow()),
			description = BAR.I18N("ui.settings.option.buildmenu_alwaysshow_descr"),
			onchange = function(option, value)
				saveOptionValue("Build menu", "buildmenu", "setAlwaysShow", { "alwaysShow" }, value)
				saveOptionValue("Grid menu", "buildmenu", "setAlwaysShow", { "alwaysShow" }, value)
			end,
		},
		{
			id = "buildmenu_prices",
			parent = "buildmenu_bottom",
			group = "ui",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.buildmenu_prices"),
			type = "bool",
			value = (WG.buildmenu ~= nil and WG.buildmenu.getShowPrice ~= nil and WG.buildmenu.getShowPrice()),
			description = BAR.I18N("ui.settings.option.buildmenu_prices_descr"),
			onchange = function(option, value)
				saveOptionValue("Build menu", "buildmenu", "setShowPrice", { "showPrice" }, value)
				saveOptionValue("Grid menu", "buildmenu", "setShowPrice", { "showPrice" }, value)
			end,
		},
		{
			id = "buildmenu_groupicon",
			parent = "buildmenu_bottom",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.buildmenu_groupicon"),
			type = "bool",
			value = (WG.buildmenu ~= nil and WG.buildmenu.getShowGroupIcon ~= nil and WG.buildmenu.getShowGroupIcon()),
			description = BAR.I18N("ui.settings.option.buildmenu_groupicon_descr"),
			onchange = function(option, value)
				saveOptionValue("Build menu", "buildmenu", "setShowGroupIcon", { "showGroupIcon" }, value)
				saveOptionValue("Grid menu", "buildmenu", "setShowGroupIcon", { "showGroupIcon" }, value)
			end,
		},
		{
			id = "buildmenu_radaricon",
			parent = "buildmenu_bottom",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.buildmenu_radaricon"),
			type = "bool",
			value = (WG.buildmenu ~= nil and WG.buildmenu.getShowRadarIcon ~= nil and WG.buildmenu.getShowRadarIcon()),
			description = BAR.I18N("ui.settings.option.buildmenu_radaricon_descr"),
			onchange = function(option, value)
				saveOptionValue("Build menu", "buildmenu", "setShowRadarIcon", { "showRadarIcon" }, value)
				saveOptionValue("Grid menu", "buildmenu", "setShowRadarIcon", { "showRadarIcon" }, value)
			end,
		},
		{
			id = "buildmenu_blueprints",
			parent = "buildmenu_bottom",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.buildmenu_blueprints"),
			type = "bool",
			value = Spring.GetConfigInt("ShowBlueprintUI", 1) == 1,
			description = BAR.I18N("ui.settings.option.buildmenu_blueprints_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("ShowBlueprintUI", value and 1 or 0)
				Spring.ForceLayoutUpdate() -- the menus read it with the commands (CommandsChanged)
			end,
		},

		{
			id = "ordermenu_bottompos",
			group = "ui",
			category = types.basic,
			prefix = BAR.I18N("ui.settings.option.ordermenu"),
			name = BAR.I18N("ui.settings.option.ordermenu_bottompos"),
			type = "bool",
			value = (
				WG.ordermenu ~= nil
				and WG.ordermenu.getBottomPosition ~= nil
				and WG.ordermenu.getBottomPosition()
			),
			description = BAR.I18N("ui.settings.option.ordermenu_bottompos_descr"),
			onchange = function(option, value)
				saveOptionValue("Order menu", "ordermenu", "setBottomPosition", { "stickToBottom" }, value)
			end,
		},
		{
			id = "ordermenu_colorize",
			parent = "ordermenu_bottompos",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.ordermenu_colorize"),
			type = "slider",
			min = 0,
			max = 1,
			step = 0.1,
			value = 0.5,
			description = "",
			widgetConfig = { "Order menu", "colorize", api = "ordermenu", set = "setColorize" },
		},
		{
			id = "ordermenu_alwaysshow",
			parent = "ordermenu_bottompos",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.ordermenu_alwaysshow"),
			type = "bool",
			value = (WG.ordermenu ~= nil and WG.ordermenu.getAlwaysShow ~= nil and WG.ordermenu.getAlwaysShow()),
			description = BAR.I18N("ui.settings.option.ordermenu_alwaysshow_descr"),
			onchange = function(option, value)
				saveOptionValue("Order menu", "ordermenu", "setAlwaysShow", { "alwaysShow" }, value)
			end,
		},
		{
			id = "ordermenu_hideset",
			parent = "ordermenu_bottompos",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.ordermenu_hideset"),
			type = "bool",
			value = (
				WG.ordermenu ~= nil
				and WG.ordermenu.getDisabledCmd ~= nil
				and WG.ordermenu.getDisabledCmd("Move")
			),
			description = BAR.I18N("ui.settings.option.ordermenu_hideset_descr"),
			onchange = function(option, value)
				local cmds =
					{ "Move", "Stop", "Attack", "Patrol", "Fight", "Wait", "Guard", "Reclaim", "Repair", "ManualFire" }
				for k, cmd in pairs(cmds) do
					saveOptionValue(
						"Order menu",
						"ordermenu",
						"setDisabledCmd",
						{ "disabledCmd", cmd },
						value,
						{ cmd, value }
					)
				end
			end,
		},

		{
			id = "info_buildlist",
			group = "ui",
			category = types.advanced,
			prefix = BAR.I18N("ui.settings.option.info"),
			name = BAR.I18N("ui.settings.option.info_buildlist"),
			type = "bool",
			value = (WG.info and WG.info.getShowBuilderBuildlist ~= nil and WG.info.getShowBuilderBuildlist()),
			description = BAR.I18N("ui.settings.option.info_buildlist_descr"),
			onchange = function(option, value)
				saveOptionValue("Info", "info", "setShowBuilderBuildlist", { "showBuilderBuildlist" }, value)
			end,
		},
		{
			id = "info_mappos",
			parent = "info_buildlist",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.info_mappos"),
			type = "bool",
			value = (WG.info and WG.info.getDisplayMapPosition ~= nil and WG.info.getDisplayMapPosition()),
			description = BAR.I18N("ui.settings.option.info_mappos_descr"),
			onchange = function(option, value)
				saveOptionValue("Info", "info", "setDisplayMapPosition", { "displayMapPosition" }, value)
			end,
		},
		{
			id = "info_alwaysshow",
			parent = "info_buildlist",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.info_alwaysshow"),
			type = "bool",
			value = (WG.info ~= nil and WG.info.getAlwaysShow ~= nil and WG.info.getAlwaysShow()),
			onchange = function(option, value)
				saveOptionValue("Info", "info", "setAlwaysShow", { "alwaysShow" }, value)
			end,
		},

		{
			id = "advplayerlist_country",
			group = "ui",
			category = types.basic,
			prefix = BAR.I18N("ui.settings.option.advplayerlist"),
			name = BAR.I18N("ui.settings.option.advplayerlist_country"),
			type = "bool",
			value = true,
			description = BAR.I18N("ui.settings.option.advplayerlist_country_descr"),
			widgetConfig = {
				"AdvPlayersList",
				{ "m_active_Table", "country" },
				api = "advplayerlist_api",
				set = "SetModuleActive",
				key = "country",
			},
		},
		{
			id = "advplayerlist_scale",
			parent = "advplayerlist_country",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.advplayerlist_scale"),
			min = 0.85,
			max = 1.2,
			step = 0.01,
			type = "slider",
			value = 1,
			description = BAR.I18N("ui.settings.option.advplayerlist_scale_descr"),
			widgetConfig = { "AdvPlayersList", "customScale", api = "advplayerlist_api", set = "SetScale" },
		},
		{
			id = "advplayerlist_showallyid",
			parent = "advplayerlist_country",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.advplayerlist_showallyid"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.advplayerlist_showallyid_descr"),
			widgetConfig = {
				"AdvPlayersList",
				{ "m_active_Table", "allyid" },
				api = "advplayerlist_api",
				set = "SetModuleActive",
				key = "allyid",
			},
		},
		{
			id = "advplayerlist_showid",
			parent = "advplayerlist_country",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.advplayerlist_showid"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.advplayerlist_showid_descr"),
			widgetConfig = {
				"AdvPlayersList",
				{ "m_active_Table", "id" },
				api = "advplayerlist_api",
				set = "SetModuleActive",
				key = "id",
			},
		},
		{
			id = "advplayerlist_showplayerid",
			parent = "advplayerlist_country",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.advplayerlist_showplayerid"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.advplayerlist_showplayerid_descr"),
			widgetConfig = {
				"AdvPlayersList",
				{ "m_active_Table", "playerid" },
				api = "advplayerlist_api",
				set = "SetModuleActive",
				key = "playerid",
			},
		},
		{
			id = "advplayerlist_rank",
			parent = "advplayerlist_country",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.advplayerlist_rank"),
			type = "bool",
			value = true,
			description = BAR.I18N("ui.settings.option.advplayerlist_rank_descr"),
			widgetConfig = {
				"AdvPlayersList",
				{ "m_active_Table", "rank" },
				api = "advplayerlist_api",
				set = "SetModuleActive",
				key = "rank",
			},
		},
		--{ id = "advplayerlist_side", group = "ui", category = types.advanced, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.advplayerlist_side'), type = "bool", value = true, description = Spring.I18N('ui.settings.option.advplayerlist_side_descr'),
		--  onload = function(option)
		--	  loadWidgetData("AdvPlayersList", "advplayerlist_side", { 'm_active_Table', 'side' })
		--  end,
		--  onchange = function(option, value)
		--	  saveOptionValue('AdvPlayersList', 'advplayerlist_api', 'SetModuleActive', { 'm_active_Table', 'side' }, value, { 'side', value })
		--  end,
		--},
		{
			id = "advplayerlist_skill",
			parent = "advplayerlist_country",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.advplayerlist_skill"),
			type = "bool",
			value = true,
			description = BAR.I18N("ui.settings.option.advplayerlist_skill_descr"),
			widgetConfig = {
				"AdvPlayersList",
				{ "m_active_Table", "skill" },
				api = "advplayerlist_api",
				set = "SetModuleActive",
				key = "skill",
			},
		},
		{
			id = "advplayerlist_cpuping",
			parent = "advplayerlist_country",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.advplayerlist_cpuping"),
			type = "bool",
			value = true,
			description = BAR.I18N("ui.settings.option.advplayerlist_cpuping_descr"),
			widgetConfig = {
				"AdvPlayersList",
				{ "m_active_Table", "cpuping" },
				api = "advplayerlist_api",
				set = "SetModuleActive",
				key = "cpuping",
			},
		},
		{
			id = "advplayerlist_resources",
			parent = "advplayerlist_country",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.advplayerlist_resources"),
			type = "bool",
			value = true,
			description = BAR.I18N("ui.settings.option.advplayerlist_resources_descr"),
			widgetConfig = {
				"AdvPlayersList",
				{ "m_active_Table", "resources" },
				api = "advplayerlist_api",
				set = "SetModuleActive",
				key = "resources",
			},
		},
		{
			id = "advplayerlist_income",
			parent = "advplayerlist_country",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.advplayerlist_income"),
			type = "bool",
			value = true,
			description = BAR.I18N("ui.settings.option.advplayerlist_income_descr"),
			widgetConfig = {
				"AdvPlayersList",
				{ "m_active_Table", "income" },
				api = "advplayerlist_api",
				set = "SetModuleActive",
				key = "income",
			},
		},
		{
			id = "advplayerlist_absresbars",
			parent = "advplayerlist_country",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.advplayerlist_absresbars"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.advplayerlist_absresbars_descr"),
			widgetConfig = {
				"AdvPlayersList",
				"absoluteResbarValues",
				api = "advplayerlist_api",
				set = "SetAbsoluteResbars",
			},
		},
		{
			id = "advplayerlist_share",
			parent = "advplayerlist_country",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.advplayerlist_share"),
			type = "bool",
			value = true,
			description = BAR.I18N("ui.settings.option.advplayerlist_share_descr"),
			widgetConfig = {
				"AdvPlayersList",
				{ "m_active_Table", "share" },
				api = "advplayerlist_api",
				set = "SetModuleActive",
				key = "share",
			},
		},
		{
			id = "advplayerlist_hidespecs",
			parent = "advplayerlist_country",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.advplayerlist_hidespecs"),
			type = "bool",
			value = true,
			description = BAR.I18N("ui.settings.option.advplayerlist_hidespecs_descr"),
			widgetConfig = {
				"AdvPlayersList",
				"alwaysHideSpecs",
				api = "advplayerlist_api",
				set = "SetAlwaysHideSpecs",
			},
		},
		{
			id = "unittotals",
			parent = "advplayerlist_country",
			group = "ui",
			category = types.advanced,
			widget = "AdvPlayersList Unit Totals",
			name = BAR.I18N("ui.settings.option.unittotals"),
			type = "bool",
			value = GetWidgetToggleValue("AdvPlayersList Unit Totals"),
			description = BAR.I18N("ui.settings.option.unittotals_descr"),
		},
		{
			id = "musicplayer",
			parent = "advplayerlist_country",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.musicplayer"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.musicplayer_descr"),
			widgetConfig = {
				"AdvPlayersList Music Player New",
				"showGUI",
				api = "music",
				get = "GetShowGui",
				set = "SetShowGui",
			},
		},
		{
			id = "mascot",
			parent = "advplayerlist_country",
			group = "ui",
			category = types.advanced,
			widget = "AdvPlayersList Mascot",
			name = BAR.I18N("ui.settings.option.mascot"),
			type = "bool",
			value = GetWidgetToggleValue("AdvPlayersList Mascot"),
			description = BAR.I18N("ui.settings.option.mascot_descr"),
		},

		{
			id = "displayselectedname",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.displayselectedname"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.displayselectedname_descr"),
			widgetConfig = {
				"Player-TV",
				"alwaysDisplayName",
				api = "playertv",
				get = "GetAlwaysDisplayName",
				set = "SetAlwaysDisplayName",
			},
		},

		{
			id = "console_fontsize",
			group = "ui",
			category = types.basic,
			prefix = BAR.I18N("ui.settings.option.console"),
			name = BAR.I18N("ui.settings.option.console_fontsize"),
			type = "slider",
			min = 0.92,
			max = 1.12,
			step = 0.02,
			value = 1,
			description = "",
			widgetConfig = { "Chat", "fontsizeMult", api = "chat", get = "getFontsize", set = "setFontsize" },
		},
		{
			id = "console_backgroundopacity",
			parent = "console_fontsize",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.console_backgroundopacity"),
			type = "slider",
			min = 0,
			max = 0.45,
			step = 0.01,
			value = 0,
			description = BAR.I18N("ui.settings.option.console_backgroundopacity_descr"),
			widgetConfig = {
				"Chat",
				"chatBackgroundOpacity",
				api = "chat",
				get = "getBackgroundOpacity",
				set = "setBackgroundOpacity",
			},
		},
		{
			id = "console_hidespecchat",
			parent = "console_fontsize",
			group = "ui",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.console_hidespecchat"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.console_hidespecchat_descr"),
			configInt = "HideSpecChat",
		},
		{
			id = "console_hidespecchatplayer",
			parent = "console_hidespecchat",
			group = "ui",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.console_hidespecchatplayer"),
			type = "bool",
			value = true,
			description = BAR.I18N("ui.settings.option.console_hidespecchatplayer_descr"),
			configInt = "HideSpecChatPlayer",
		},
		{
			id = "console_hide",
			parent = "console_fontsize",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.console_hide"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.console_hide_descr"),
			widgetConfig = { "Chat", "hide", api = "chat", get = "getHide", set = "setHide" },
		},
		{
			id = "console_maxlines",
			parent = "console_fontsize",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.console_maxlines"),
			type = "slider",
			min = 3,
			max = 7,
			step = 1,
			value = 5,
			description = "",
			widgetConfig = { "Chat", "maxLines", api = "chat", get = "getMaxLines", set = "setMaxLines" },
		},
		{
			id = "console_maxconsolelines",
			parent = "console_fontsize",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.console_maxconsolelines"),
			type = "slider",
			min = 2,
			max = 12,
			step = 1,
			value = 2,
			description = "",
			widgetConfig = {
				"Chat",
				"maxConsoleLines",
				api = "chat",
				get = "getMaxConsoleLines",
				set = "setMaxConsoleLines",
			},
		},
		--{ id = "console_handleinput", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.console_handleinput'), type = "bool", value = (WG['chat'] ~= nil and WG['chat'].getHandleInput() or 0), description = Spring.I18N('ui.settings.option.console_handleinput_descr'),
		--  onload = function(option)
		--	  loadWidgetData("Chat", "console_handleinput", { 'handleTextInput' })
		--  end,
		--  onchange = function(option, value)
		--	  saveOptionValue('Chat', 'chat', 'setHandleInput', { 'handleTextInput' }, value)
		--  end,
		--},
		--{ id = "console_inputbutton", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.console_inputbutton'), type = "bool", value = (WG['chat'] ~= nil and WG['chat'].getInputButton() or 0), description = Spring.I18N('ui.settings.option.console_inputbutton_descr'),
		--  onload = function(option)
		--	  loadWidgetData("Chat", "console_inputbutton", { 'inputButton' })
		--  end,
		--  onchange = function(option, value)
		--	  saveOptionValue('Chat', 'chat', 'setInputButton', { 'inputButton' }, value)
		--  end,
		--},
		{
			id = "autoeraser",
			group = "ui",
			category = types.basic,
			widget = "Auto mapmark eraser",
			name = BAR.I18N("ui.settings.option.autoeraser"),
			type = "bool",
			value = GetWidgetToggleValue("Auto mapmark eraser"),
			description = BAR.I18N("ui.settings.option.autoeraser_descr"),
		},
		{
			id = "autoeraser_erasetime",
			parent = "autoeraser",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.autoeraser_erasetime"),
			type = "slider",
			min = 5,
			max = 600,
			step = 5,
			value = 60,
			description = BAR.I18N("ui.settings.option.autoeraser_erasetime_descr"),
			widgetConfig = { "Auto mapmark eraser", "eraseTime", api = "autoeraser", set = "setEraseTime" },
		},

		{
			id = "topbar_hidebuttons",
			group = "ui",
			category = types.advanced,
			prefix = BAR.I18N("ui.settings.option.topbar"),
			name = BAR.I18N("ui.settings.option.topbar_hidebuttons"),
			type = "bool",
			value = false,
			widgetConfig = {
				"Top Bar Buttons",
				"autoHideButtons",
				api = "topbar",
				get = "getAutoHideButtons",
				set = "setAutoHideButtons",
			},
		},

		{
			id = "continuouslyclearmapmarks",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.continuouslyclearmapmarks"),
			type = "bool",
			value = Spring.GetConfigInt("ContinuouslyClearMapmarks", 0) == 1,
			description = BAR.I18N("ui.settings.option.continuouslyclearmapmarks_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("ContinuouslyClearMapmarks", (value and 1 or 0))
				if value then
					Spring.SendCommands({ "clearmapmarks" })
				end
			end,
		},

		{
			id = "unitgroups",
			group = "ui",
			category = types.basic,
			widget = "Unit Groups",
			name = BAR.I18N("ui.settings.option.unitgroups"),
			type = "bool",
			value = GetWidgetToggleValue("Unit Groups"),
			description = BAR.I18N("ui.settings.option.unitgroups_descr"),
		},
		{
			id = "idlebuilders",
			group = "ui",
			category = types.basic,
			widget = "Idle Builders",
			name = BAR.I18N("ui.settings.option.idlebuilders"),
			type = "bool",
			value = GetWidgetToggleValue("Idle Builders"),
			description = BAR.I18N("ui.settings.option.idlebuilders_descr"),
		},
		{
			id = "buildbar",
			group = "ui",
			category = types.basic,
			widget = "BuildBar",
			name = BAR.I18N("ui.settings.option.buildbar"),
			type = "bool",
			value = GetWidgetToggleValue("BuildBar"),
			description = BAR.I18N("ui.settings.option.buildbar_descr"),
		},

		{
			id = "converterusage",
			group = "ui",
			category = types.advanced,
			widget = "Converter Usage",
			name = BAR.I18N("ui.settings.option.converterusage"),
			type = "bool",
			value = GetWidgetToggleValue("Converter Usage"),
			description = BAR.I18N("ui.settings.option.converterusage_descr"),
		},

		{
			id = "widgetselector",
			group = "ui",
			category = types.advanced,
			available = not (model.devMode or model.devUI) and hasUserWidgets,
			name = BAR.I18N("ui.settings.option.widgetselector"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.widgetselector_descr"),
			configInt = "widgetselector",
		},

		{
			id = "windows_hideinterface",
			group = "ui",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.windows_hideinterface"),
			type = "bool",
			value = Spring.GetConfigInt("WindowsHideInterface", 0) == 1,
			description = BAR.I18N("ui.settings.option.windows_hideinterface_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("WindowsHideInterface", (value and 1 or 0))
				-- pushed through as well so it takes effect now instead of at the next poll
				widgetHandler:SetWindowsHideInterface(value)
			end,
		},

		{
			id = "label_ui_visuals",
			group = "ui",
			name = BAR.I18N("ui.settings.option.label_visuals"),
			category = types.basic,
		},

		{
			id = "uniticon_scaleui",
			group = "ui",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.uniticonscaleui"),
			type = "slider",
			min = 0.85,
			max = 3,
			step = 0.05,
			value = tonumber(Spring.GetConfigFloat("UnitIconScaleUI", 1) or 1),
			description = BAR.I18N("ui.settings.option.uniticonscaleui_descr"),
			onchange = function(option, value)
				Spring.SendCommands("iconscaleui " .. value)
				Spring.SetConfigFloat("UnitIconScaleUI", value)
			end,
		},
		{
			id = "uniticon_distance",
			parent = "uniticon_scaleui",
			group = "ui",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.uniticondistance"),
			type = "slider",
			min = 1,
			max = 12000,
			step = 50,
			value = tonumber(Spring.GetConfigInt("UnitIconFadeVanish", 2700) or 1),
			description = BAR.I18N("ui.settings.option.uniticondistance_descr"),
			onchange = function(option, value)
				Spring.SendCommands("iconfadestart " .. value)
				Spring.SetConfigInt("UnitIconFadeStart", value)
				-- update UnitIconFadeVanish too
				Spring.SendCommands("iconfadevanish " .. value)
				Spring.SetConfigInt("UnitIconFadeVanish", value)
			end,
		},
		{
			id = "uniticon_hidewithui",
			parent = "uniticon_scaleui",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.uniticonhidewithui"),
			type = "bool",
			value = (Spring.GetConfigInt("UnitIconsHideWithUI", 0) == 1),
			description = BAR.I18N("ui.settings.option.uniticonhidewithui_descr"),
			onchange = function(option, value)
				Spring.SendCommands("iconshidewithui " .. (value and 1 or 0))
				Spring.SetConfigInt("UnitIconsHideWithUI", (value and 1 or 0))
			end,
		},

		-- { id = "teamcolors", group = "ui", category = types.basic, widget = "Player Color Palette", name = Spring.I18N('ui.settings.option.teamcolors'), type = "bool", value = GetWidgetToggleValue("Player Color Palette"), description = Spring.I18N('ui.settings.option.teamcolors_descr') },
		-- { id = "sameteamcolors", group = "ui", category = types.basic, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.sameteamcolors'), type = "bool", value = (WG['playercolorpalette'] ~= nil and WG['playercolorpalette'].getSameTeamColors ~= nil and WG['playercolorpalette'].getSameTeamColors()), description = Spring.I18N('ui.settings.option.sameteamcolors_descr'),
		--   onchange = function(option, value)
		-- 	  saveOptionValue('Player Color Palette', 'playercolorpalette', 'setSameTeamColors', { 'useSameTeamColors' }, value)
		--   end,
		-- },

		{
			id = "teamplatter",
			group = "ui",
			category = types.basic,
			widget = "TeamPlatter",
			name = BAR.I18N("ui.settings.option.teamplatter"),
			type = "bool",
			value = GetWidgetToggleValue("TeamPlatter"),
			description = BAR.I18N("ui.settings.option.teamplatter_descr"),
		},
		{
			id = "teamplatter_opacity",
			parent = "teamplatter",
			category = types.advanced,
			group = "ui",
			name = BAR.I18N("ui.settings.option.teamplatter_opacity"),
			min = 0.05,
			max = 0.4,
			step = 0.01,
			type = "slider",
			value = 0.25,
			description = BAR.I18N("ui.settings.option.teamplatter_opacity_descr"),
			widgetConfig = { "TeamPlatter", "opacity", api = "teamplatter", set = "setOpacity" },
		},
		{
			id = "teamplatter_skipownteam",
			parent = "teamplatter",
			category = types.advanced,
			group = "ui",
			name = BAR.I18N("ui.settings.option.teamplatter_skipownteam"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.teamplatter_skipownteam_descr"),
			widgetConfig = { "TeamPlatter", "skipOwnTeam", api = "teamplatter", set = "setSkipOwnTeam" },
		},

		{
			id = "enemyspotter",
			group = "ui",
			category = types.basic,
			widget = "EnemySpotter",
			name = BAR.I18N("ui.settings.option.enemyspotter"),
			type = "bool",
			value = GetWidgetToggleValue("EnemySpotter"),
			description = BAR.I18N("ui.settings.option.enemyspotter_descr"),
		},
		{
			id = "enemyspotter_opacity",
			parent = "enemyspotter",
			category = types.advanced,
			group = "ui",
			name = BAR.I18N("ui.settings.option.enemyspotter_opacity"),
			min = 0.12,
			max = 0.4,
			step = 0.01,
			type = "slider",
			value = 0.15,
			description = BAR.I18N("ui.settings.option.enemyspotter_opacity_descr"),
			widgetConfig = { "EnemySpotter", "opacity", api = "enemyspotter", set = "setOpacity" },
		},

		--{ id = "selectedunits", group = "ui", category = types.basic, widget = "Selected Units GL4", name = "Selection", type = "bool", value = GetWidgetToggleValue("Selected Units GL4"), description = Spring.I18N('ui.settings.option.selectedunits_descr') },
		{
			id = "selectedunits_opacity",
			group = "ui",
			category = types.advanced,
			prefix = BAR.I18N("ui.settings.option.selectedunits"),
			name = BAR.I18N("ui.settings.option.selectedunits_opacity"),
			min = 0,
			max = 0.5,
			step = 0.01,
			type = "slider",
			value = 0.19,
			description = BAR.I18N("ui.settings.option.selectedunits_opacity_descr"),
			widgetConfig = { "Selected Units GL4", "opacity", api = "selectedunits", set = "setOpacity" },
		},
		{
			id = "selectedunits_teamcoloropacity",
			parent = "selectedunits_opacity",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.selectedunits_teamcoloropacity"),
			min = 0,
			max = 1,
			step = 0.01,
			type = "slider",
			value = 0.6,
			description = BAR.I18N("ui.settings.option.selectedunits_teamcoloropacity_descr"),
			widgetConfig = {
				"Selected Units GL4",
				"teamcolorOpacity",
				api = "selectedunits",
				set = "setTeamcolorOpacity",
			},
		},

		--{ id = "highlightselunits", group = "ui", category = types.basic, widget = "Highlight Selected Units GL4", name = Spring.I18N('ui.settings.option.highlightselunits'), type = "bool", value = GetWidgetToggleValue("Highlight Selected Units GL4"), description = Spring.I18N('ui.settings.option.highlightselunits_descr') },

		{
			id = "highlightselunits",
			parent = "selectedunits_opacity",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.highlightselunits"),
			type = "bool",
			value = true,
			description = BAR.I18N("ui.settings.option.highlightselunits_descr"),
			widgetConfig = {
				"Selected Units GL4",
				"selectionHighlight",
				api = "selectedunits",
				set = "setSelectionHighlight",
			},
		},
		--{ id = "highlightselunits_opacity", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.highlightselunits_opacity'), min = 0.02, max = 0.12, step = 0.01, type = "slider", value = 0.05, description = Spring.I18N('ui.settings.option.highlightselunits_opacity_descr'),
		--  onload = function(option)
		--	  loadWidgetData("Highlight Selected Units GL4", "highlightselunits_opacity", { 'highlightAlpha' })
		--  end,
		--  onchange = function(option, value)
		--	  saveOptionValue('Highlight Selected Units GL4', 'highlightselunits', 'setOpacity', { 'highlightAlpha' }, value)
		--  end,
		--},
		--{ id = "highlightselunits_teamcolor", group = "ui", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.highlightselunits_teamcolor'), type = "bool", value = false, description = Spring.I18N('ui.settings.option.highlightselunits_teamcolor_descr'),
		--  onload = function(option)
		--	  loadWidgetData("Highlight Selected Units GL4", "highlightselunits_teamcolor", { 'useTeamcolor' })
		--  end,
		--  onchange = function(option, value)
		--	  saveOptionValue('Highlight Selected Units GL4', 'highlightselunits', 'setTeamcolor', { 'useTeamcolor' }, value)
		--  end,
		--},

		-- { id = "highlightunit", group = "ui", category = types.advanced, widget = "Highlight Unit GL4", name = Spring.I18N('ui.settings.option.highlightunit'), type = "bool", value = GetWidgetToggleValue("Highlight Unit GL4"), description = Spring.I18N('ui.settings.option.highlightunit_descr') },

		{
			id = "highlightunit",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.highlightunit"),
			type = "bool",
			value = true,
			description = BAR.I18N("ui.settings.option.highlightunit_descr"),
			widgetConfig = {
				"Selected Units GL4",
				"mouseoverHighlight",
				api = "selectedunits",
				set = "setMouseoverHighlight",
			},
		},

		-- Jammed units highlight
		{
			id = "jammedunits",
			group = "ui",
			category = types.advanced,
			widget = "Jammed Units Highlight",
			name = BAR.I18N("ui.settings.option.jammedunits"),
			type = "bool",
			value = GetWidgetToggleValue("Jammed Units Highlight"),
			description = BAR.I18N("ui.settings.option.jammedunits_descr"),
		},
		{
			id = "ghosticons_brightness",
			group = "ui",
			category = types.dev,
			prefix = BAR.I18N("ui.settings.option.ghosticons"),
			name = BAR.I18N("ui.settings.option.ghosticons_brightness"),
			min = 0,
			max = 1.0,
			step = 0.15,
			type = "slider",
			value = 0.8,
			description = BAR.I18N("ui.settings.option.ghosticons_brightness_descr"),
			configFloat = "UnitGhostIconsDimming",
		},

		{
			id = "cursorlight",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.cursorlight"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.cursorlight_descr"),
			widgetConfig = {
				"Deferred rendering GL4",
				"showPlayerCursorLight",
				api = "lightsgl4",
				set = "ShowPlayerCursorLight",
			},
		},
		{
			id = "cursorlight_lightradius",
			parent = "cursorlight",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.cursorlight_lightradius"),
			type = "slider",
			min = 0.3,
			max = 2,
			step = 0.05,
			value = 1,
			description = "",
			widgetConfig = {
				"Deferred rendering GL4",
				"playerCursorLightRadius",
				api = "lightsgl4",
				set = "PlayerCursorLightRadius",
			},
		},
		{
			id = "cursorlight_lightstrength",
			parent = "cursorlight",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.cursorlight_lightstrength"),
			type = "slider",
			min = 0.3,
			max = 2,
			step = 0.05,
			value = 1,
			description = "",
			widgetConfig = {
				"Deferred rendering GL4",
				"playerCursorLightBrightness",
				api = "lightsgl4",
				set = "PlayerCursorLightBrightness",
			},
		},

		{
			id = "label_ui_info",
			group = "ui",
			name = BAR.I18N("ui.settings.option.label_info"),
			category = types.basic,
		},

		{
			id = "metalspots_values",
			group = "ui",
			category = types.advanced,
			prefix = BAR.I18N("ui.settings.option.metalspots"),
			name = BAR.I18N("ui.settings.option.metalspots_values"),
			type = "bool",
			value = (WG.metalspots ~= nil and WG.metalspots.getShowValue()),
			description = BAR.I18N("ui.settings.option.metalspots_values_descr"),
			onload = function(option)
				loadWidgetData("Metalspots", "metalspots_values", { "showValue" })
			end,
			onchange = function(option, value)
				if WG.metalspots then
					WG.metalspots.setShowValue(value)
				end
				saveOptionValue("Metalspots", "metalspots", "setShowValue", { "showValue" }, option.value)
			end,
		},
		{
			id = "metalspots_metalviewonly",
			parent = "metalspots_values",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.metalspots_metalviewonly"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.metalspots_metalviewonly_descr"),
			widgetConfig = { "Metalspots", "metalViewOnly", api = "metalspots", set = "setMetalViewOnly" },
		},

		{
			id = "geospots",
			group = "ui",
			category = types.dev,
			widget = "Geothermalspots",
			name = BAR.I18N("ui.settings.option.geospots"),
			type = "bool",
			value = GetWidgetToggleValue("Geothermalspots"),
			description = BAR.I18N("ui.settings.option.geospots_descr"),
		},

		{
			id = "healthbarsscale",
			group = "ui",
			category = types.advanced,
			prefix = BAR.I18N("ui.settings.option.healthbars"),
			name = BAR.I18N("ui.settings.option.healthbarsscale"),
			type = "slider",
			min = 0.6,
			max = 2.0,
			step = 0.1,
			value = 1,
			description = "",
			widgetConfig = { "Health Bars GL4", "barScale", api = "healthbars", set = "setScale" },
		},
		{
			id = "healthbarsheight",
			parent = "healthbarsscale",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.healthbarsheight"),
			type = "slider",
			min = 0.7,
			max = 2,
			step = 0.1,
			value = (WG.healthbars ~= nil and WG.healthbars.getHeight() or 0.9),
			description = "",
			onload = function(option)
				loadWidgetData("Health Bars GL4", "healthbarsheight", { "barHeight" })
			end,
			onchange = function(option, value)
				saveOptionValue("Health Bars GL4", "healthbars", "setHeight", { "barHeight" }, value)
				widgetHandler:DisableWidget("Health Bars GL4")
				widgetHandler:EnableWidget("Health Bars GL4")
			end,
		},
		{
			id = "healthbarsvariable",
			parent = "healthbarsscale",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.healthbarsvariable"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.healthbarsvariable_descr"),
			widgetConfig = {
				"Health Bars GL4",
				"variableBarSizes",
				api = "healthbars",
				get = "getVariableSizes",
				set = "setVariableSizes",
			},
		},
		{
			id = "healthbarswhenguihidden",
			parent = "healthbarsscale",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.healthbarswhenguihidden"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.healthbarswhenguihidden_descr"),
			widgetConfig = {
				"Health Bars GL4",
				"drawWhenGuiHidden",
				api = "healthbars",
				get = "getDrawWhenGuiHidden",
				set = "setDrawWhenGuiHidden",
			},
		},
		{
			id = "rankicons",
			group = "ui",
			category = types.advanced,
			widget = "Rank Icons GL4",
			name = BAR.I18N("ui.settings.option.rankicons"),
			type = "bool",
			value = GetWidgetToggleValue("Rank Icons GL4"),
			description = BAR.I18N("ui.settings.option.rankicons_descr"),
		},
		{
			id = "rankicons_distance",
			parent = "rankicons",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.rankicons_distance"),
			type = "slider",
			min = 0.1,
			max = 1.5,
			step = 0.05,
			value = (WG.rankicons ~= nil and WG.rankicons.getDrawDistance ~= nil and WG.rankicons.getDrawDistance()),
			description = "",
			onchange = function(option, value)
				saveOptionValue("Rank Icons GL4", "rankicons", "setDrawDistance", { "distanceMult" }, value)
			end,
		},
		{
			id = "rankicons_scale",
			parent = "rankicons",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.rankicons_scale"),
			type = "slider",
			min = 0.5,
			max = 2,
			step = 0.1,
			value = (WG.rankicons ~= nil and WG.rankicons.getScale ~= nil and WG.rankicons.getScale()),
			description = "",
			onchange = function(option, value)
				saveOptionValue("Rank Icons GL4", "rankicons", "setScale", { "iconsizeMult" }, value)
			end,
		},

		{
			id = "allycursors",
			group = "ui",
			category = types.basic,
			widget = "AllyCursors",
			name = BAR.I18N("ui.settings.option.allycursors"),
			type = "bool",
			value = GetWidgetToggleValue("AllyCursors"),
			description = BAR.I18N("ui.settings.option.allycursors_descr"),
		},
		{
			id = "allycursors_playername",
			parent = "allycursors",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.allycursors_playername"),
			type = "bool",
			value = true,
			description = BAR.I18N("ui.settings.option.allycursors_playername_descr"),
			widgetConfig = { "AllyCursors", "showPlayerName", api = "allycursors", set = "setPlayerNames" },
		},
		{
			id = "allycursors_showdot",
			parent = "allycursors",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.allycursors_showdot"),
			type = "bool",
			value = true,
			description = BAR.I18N("ui.settings.option.allycursors_showdot_descr"),
			widgetConfig = { "AllyCursors", "showCursorDot", api = "allycursors", set = "setCursorDot" },
		},
		{
			id = "allycursors_spectatorname",
			parent = "allycursors",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.allycursors_spectatorname"),
			type = "bool",
			value = true,
			description = BAR.I18N("ui.settings.option.allycursors_spectatorname_descr"),
			widgetConfig = { "AllyCursors", "showSpectatorName", api = "allycursors", set = "setSpectatorNames" },
		},
		{
			id = "allycursors_lights",
			parent = "allycursors",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.allycursors_lights"),
			type = "bool",
			value = true,
			description = BAR.I18N("ui.settings.option.allycursors_lights_descr"),
			widgetConfig = { "AllyCursors", "addLights", api = "allycursors", set = "setLights" },
		},
		{
			id = "allycursors_lightradius",
			parent = "allycursors_lights",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.allycursors_lightradius"),
			type = "slider",
			min = 0.15,
			max = 1,
			step = 0.05,
			value = 0.5,
			description = "",
			widgetConfig = { "AllyCursors", "lightRadiusMult", api = "allycursors", set = "setLightRadius" },
		},
		{
			id = "allycursors_lightstrength",
			parent = "allycursors_lights",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.allycursors_lightstrength"),
			type = "slider",
			min = 0.1,
			max = 1.2,
			step = 0.05,
			value = 0.85,
			description = "",
			widgetConfig = { "AllyCursors", "lightStrengthMult", api = "allycursors", set = "setLightStrength" },
		},
		{
			id = "allycursors_selfshadowing",
			parent = "allycursors_lights",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.allycursors_selfshadowing"),
			type = "bool",
			value = false,
			description = "",
			widgetConfig = { "AllyCursors", "lightSelfShadowing", api = "allycursors", set = "setLightSelfShadowing" },
		},

		{
			id = "showbuilderqueue",
			group = "ui",
			category = types.advanced,
			widget = "Show Builder Queue",
			name = BAR.I18N("ui.settings.option.showbuilderqueue"),
			type = "bool",
			value = GetWidgetToggleValue("Show Builder Queue"),
			description = BAR.I18N("ui.settings.option.showbuilderqueue_descr"),
		},

		{
			id = "unitenergyicons",
			group = "ui",
			category = types.advanced,
			widget = "Unit Energy Icons",
			name = BAR.I18N("ui.settings.option.unitenergyicons"),
			type = "bool",
			value = GetWidgetToggleValue("Unit Energy Icons"),
			description = BAR.I18N("ui.settings.option.unitenergyicons_descr"),
		},

		{
			id = "unitidlebuildericons",
			group = "ui",
			category = types.advanced,
			widget = "Unit Idle Builder Icons",
			name = BAR.I18N("ui.settings.option.unitidlebuildericons"),
			type = "bool",
			value = GetWidgetToggleValue("Unit Idle Builder Icons"),
			description = BAR.I18N("ui.settings.option.unitidlebuildericons_descr"),
		},

		{
			id = "unitfirestateicons",
			group = "ui",
			category = types.advanced,
			widget = "Unit Fire State Icons",
			name = BAR.I18N("ui.settings.option.unitfirestateicons"),
			type = "bool",
			value = GetWidgetToggleValue("Unit Fire State Icons"),
			description = BAR.I18N("ui.settings.option.unitfirestateicons_descr"),
		},

		{
			id = "resurrectionhalos",
			group = "ui",
			category = types.advanced,
			widget = "Resurrection Halos GL4",
			name = BAR.I18N("ui.settings.option.resurrectionhalos"),
			type = "bool",
			value = GetWidgetToggleValue("Resurrection Halos GL4"),
			description = BAR.I18N("ui.settings.option.resurrectionhalos_descr"),
		},

		{
			id = "nametags_rank",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.nametags_rank"),
			type = "bool",
			value = true,
			description = BAR.I18N("ui.settings.option.nametags_rank_descr"),
			widgetConfig = { "Commander Name Tags", "showPlayerRank", api = "nametags", set = "SetShowPlayerRank" },
		},

		{
			id = "commandsfx",
			group = "ui",
			category = types.basic,
			widget = "Commands FX",
			name = BAR.I18N("ui.settings.option.commandsfx"),
			type = "bool",
			value = GetWidgetToggleValue("Commands FX"),
			description = BAR.I18N("ui.settings.option.commandsfx_descr"),
		},

		{
			id = "commandsfxopacity",
			parent = "commandsfx",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.commandsfxopacity"),
			type = "slider",
			min = 0.25,
			max = 1,
			step = 0.1,
			value = 1,
			description = "",
			widgetConfig = { "Commands FX", "opacity", api = "commandsfx", set = "setOpacity" },
		},
		{
			id = "commandsfxduration",
			parent = "commandsfx",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.commandsfxduration"),
			type = "slider",
			min = 0.5,
			max = 2,
			step = 0.01,
			value = 1,
			description = "",
			widgetConfig = { "Commands FX", "duration", api = "commandsfx", set = "setDuration" },
		},
		{
			id = "commandsfxfilterai",
			parent = "commandsfx",
			group = "ui",
			category = types.dev,
			available = aiDetected,
			name = BAR.I18N("ui.settings.option.commandsfxfilterai"),
			type = "bool",
			value = true,
			description = BAR.I18N("ui.settings.option.commandsfxfilterai_descr"),
			widgetConfig = { "Commands FX", "filterAIteams", api = "commandsfx", set = "setFilterAI" },
		},
		{
			id = "commandsfxuseteamcolors",
			parent = "commandsfx",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.commandsfxuseteamcolors"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.commandsfxuseteamcolors_descr"),
			widgetConfig = { "Commands FX", "useTeamColors", api = "commandsfx", set = "setUseTeamColors" },
		},
		{
			id = "commandsfxuseteamcolorswhenspec",
			parent = "commandsfx",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.commandsfxuseteamcolorswhenspec"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.commandsfxuseteamcolorswhenspec_descr"),
			widgetConfig = {
				"Commands FX",
				"useTeamColorsWhenSpec",
				api = "commandsfx",
				get = "getUseTeamColorsWhenSpec",
				set = "setUseTeamColorsWhenSpec",
			},
		},

		{
			id = "flankingicons",
			group = "ui",
			category = types.advanced,
			widget = "Flanking Icons GL4",
			name = BAR.I18N("ui.settings.option.flankingicons"),
			type = "bool",
			value = GetWidgetToggleValue("Flanking Icons GL4"),
			description = BAR.I18N("ui.settings.option.flankingicons_descr"),
		},

		{
			id = "displaydps",
			group = "ui",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.displaydps"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.displaydps_descr"),
			configInt = "DisplayDPS",
		},

		{
			id = "givenunits",
			group = "ui",
			category = types.advanced,
			widget = "Given Units",
			name = BAR.I18N("ui.settings.option.givenunits"),
			type = "bool",
			value = GetWidgetToggleValue("Given Units"),
			description = BAR.I18N("ui.settings.option.givenunits_descr"),
		},

		{
			id = "reclaimfieldhighlight",
			group = "ui",
			category = types.advanced,
			widget = "Reclaim Field Highlight",
			name = BAR.I18N("ui.settings.option.reclaimfieldhighlight"),
			type = "bool",
			description = BAR.I18N("ui.settings.option.reclaimfieldhighlight_descr"),
		},

		{
			id = "reclaimfieldhighlight_metal",
			parent = "reclaimfieldhighlight",
			group = "ui",
			category = types.advanced,
			widget = "Reclaim Field Highlight",
			name = BAR.I18N("ui.settings.option.reclaimfieldhighlight_metal"),
			type = "select",
			options = reclaimFieldHighlightOptions,
			value = 3,
			description = BAR.I18N("ui.settings.option.reclaimfieldhighlight_metal_descr"),
			widgetConfig = {
				"Reclaim Field Highlight",
				"showOption",
				api = "reclaimfieldhighlight",
				set = "setShowOption",
			},
		},

		{
			id = "reclaimfieldhighlight_energy",
			parent = "reclaimfieldhighlight",
			group = "ui",
			category = types.advanced,
			widget = "Reclaim Field Highlight",
			name = BAR.I18N("ui.settings.option.reclaimfieldhighlight_energy"),
			type = "select",
			options = reclaimFieldHighlightOptions,
			value = 3,
			description = BAR.I18N("ui.settings.option.reclaimfieldhighlight_energy_descr"),
			widgetConfig = {
				"Reclaim Field Highlight",
				"showEnergyOption",
				api = "reclaimfieldhighlight",
				set = "setShowEnergyOption",
			},
		},

		{
			id = "highlightcomwrecks",
			group = "ui",
			category = types.advanced,
			widget = "Highlight Commander Wrecks",
			name = BAR.I18N("ui.settings.option.highlightcomwrecks"),
			type = "bool",
			value = GetWidgetToggleValue("Highlight Commander Wrecks"),
			description = BAR.I18N("ui.settings.option.highlightcomwrecks_descr"),
		},
		{
			id = "highlightcomwrecks_teamcolor",
			parent = "highlightcomwrecks",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.highlightcomwrecks_teamcolor"),
			type = "bool",
			value = true,
			description = BAR.I18N("ui.settings.option.highlightcomwrecks_teamcolor_descr"),
			widgetConfig = {
				"Highlight Commander Wrecks",
				"useTeamColor",
				api = "highlightcomwrecks",
				set = "setUseTeamColor",
			},
		},

		{
			id = "buildinggrid",
			group = "ui",
			category = types.basic,
			widget = "Building Grid GL4",
			name = BAR.I18N("ui.settings.option.buildinggrid"),
			type = "bool",
			value = GetWidgetToggleValue("Building Grid GL4"),
			description = BAR.I18N("ui.settings.option.buildinggrid_descr"),
		},
		{
			id = "buildinggridopacity",
			parent = "buildinggrid",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.buildinggridopacity"),
			type = "slider",
			min = 0.3,
			max = 1,
			step = 0.05,
			value = 1,
			description = "",
			widgetConfig = {
				"Building Grid GL4",
				"opacity",
				api = "buildinggrid",
				get = "getOpacity",
				set = "setOpacity",
			},
		},
		{
			id = "startpositionsuggestions",
			group = "ui",
			category = types.basic,
			widget = "Start Position Suggestions",
			name = BAR.I18N("ui.settings.option.startpositionsuggestions"),
			type = "bool",
			value = GetWidgetToggleValue("Start Position Suggestions"),
			description = BAR.I18N("ui.settings.option.startpositionsuggestions_descr"),
		},

		{
			id = "label_ui_ranges",
			group = "ui",
			name = BAR.I18N("ui.settings.option.label_ranges"),
			category = types.basic,
		},

		-- read by the radar and jammer preview widgets
		{
			id = "sensorpreviewcircles",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.sensorpreviewcircles"),
			type = "bool",
			value = Spring.GetConfigInt("SensorPreviewCircles", 1) ~= 0,
			description = BAR.I18N("ui.settings.option.sensorpreviewcircles_descr"),
			onchange = function(_, value)
				Spring.SetConfigInt("SensorPreviewCircles", value and 1 or 0)
			end,
		},

		-- Radar range rings:
		{
			id = "radarrange",
			group = "ui",
			category = types.advanced,
			widget = "Sensor Ranges Radar",
			name = BAR.I18N("ui.settings.option.radarrange"),
			type = "bool",
			value = GetWidgetToggleValue("Sensor Ranges Radar"),
			description = BAR.I18N("ui.settings.option.radarrange_descr"),
		},

		{
			id = "radarrangeopacity",
			parent = "radarrange",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.radarrangeopacity"),
			type = "slider",
			min = 0.01,
			max = 0.33,
			step = 0.01,
			value = 0.08,
			description = "",
			widgetConfig = {
				"Sensor Ranges Radar",
				"opacity",
				api = "radarrange",
				get = "getOpacity",
				set = "setOpacity",
			},
		},
		-- Sonar range
		{
			id = "sonarrange",
			group = "ui",
			category = types.advanced,
			widget = "Sensor Ranges Sonar",
			name = BAR.I18N("ui.settings.option.sonarrange"),
			type = "bool",
			value = GetWidgetToggleValue("Sensor Ranges Sonar"),
			description = BAR.I18N("ui.settings.option.sonarrange_descr"),
		},

		{
			id = "sonarrangeopacity",
			parent = "sonarrange",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.sonarrangeopacity"),
			type = "slider",
			min = 0.01,
			max = 0.33,
			step = 0.01,
			value = 0.08,
			description = "",
			widgetConfig = {
				"Sensor Ranges Sonar",
				"opacity",
				api = "sonarrange",
				get = "getOpacity",
				set = "setOpacity",
			},
		},
		-- Jammer range

		-- LOS Range:
		{
			id = "losrange",
			group = "ui",
			category = types.advanced,
			widget = "Sensor Ranges LOS",
			name = BAR.I18N("ui.settings.option.losrange"),
			type = "bool",
			value = GetWidgetToggleValue("Sensor Ranges LOS"),
			description = BAR.I18N("ui.settings.option.losrange_descr"),
		},

		{
			id = "losrangeopacity",
			parent = "losrange",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.losrangeopacity"),
			type = "slider",
			min = 0.01,
			max = 0.33,
			step = 0.01,
			value = 0.08,
			description = "",
			widgetConfig = { "Sensor Ranges LOS", "opacity", api = "losrange", get = "getOpacity", set = "setOpacity" },
		},
		{
			id = "losrangeteamcolors",
			parent = "losrange",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.losrangeteamcolors"),
			type = "bool",
			value = false,
			description = "",
			widgetConfig = {
				"Sensor Ranges LOS",
				"useteamcolors",
				api = "losrange",
				get = "getUseTeamColors",
				set = "setUseTeamColors",
			},
		},

		{
			id = "attackrange",
			group = "ui",
			category = types.basic,
			widget = "Attack Range GL4",
			name = BAR.I18N("ui.settings.option.attackrange"),
			type = "bool",
			value = GetWidgetToggleValue("Attack Range GL4"),
			description = BAR.I18N("ui.settings.option.attackrange_descr"),
		},
		{
			id = "attackrange_shiftonly",
			parent = "attackrange",
			category = types.dev,
			group = "ui",
			name = BAR.I18N("ui.settings.option.attackrange_shiftonly"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.attackrange_shiftonly_descr"),
			widgetConfig = {
				"Attack Range GL4",
				"shift_only",
				api = "attackrange",
				get = "getShiftOnly",
				set = "setShiftOnly",
			},
		},
		{
			id = "attackrange_cursorunitrange",
			parent = "attackrange",
			category = types.dev,
			group = "ui",
			name = BAR.I18N("ui.settings.option.attackrange_cursorunitrange"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.attackrange_cursorunitrange_descr"),
			widgetConfig = {
				"Attack Range GL4",
				"cursor_unit_range",
				api = "attackrange",
				get = "getCursorUnitRange",
				set = "setCursorUnitRange",
			},
		},
		{
			id = "attackrange_numrangesmult",
			parent = "attackrange",
			group = "ui",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.attackrange_numrangesmult"),
			type = "slider",
			min = 0.3,
			max = 1,
			step = 0.1,
			value = 1,
			description = BAR.I18N("ui.settings.option.attackrange_numrangesmult_descr"),
			widgetConfig = {
				"Attack Range GL4",
				"selectionDisableThresholdMult",
				api = "attackrange",
				get = "getNumRangesMult",
				set = "setNumRangesMult",
			},
		},

		{
			id = "defrange",
			group = "ui",
			category = types.basic,
			widget = "Defense Range GL4",
			name = BAR.I18N("ui.settings.option.defrange"),
			type = "bool",
			value = GetWidgetToggleValue("Defense Range GL4"),
			description = BAR.I18N("ui.settings.option.defrange_descr"),
		},

		{
			id = "defrange_allyair",
			parent = "defrange",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.defrange_allyair"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.defrange_allyair_descr"),
			widgetConfig = {
				"Defense Range GL4",
				{ "enabled", "ally", "air" },
				api = "defrange",
				get = "getAllyAir",
				set = "setAllyAir",
			},
		},
		{
			id = "defrange_allyground",
			parent = "defrange",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.defrange_allyground"),
			type = "bool",
			value = (WG.defrange ~= nil and WG.defrange.getAllyGround ~= nil and WG.defrange.getAllyGround()),
			description = BAR.I18N("ui.settings.option.defrange_allyground_descr"),
			onload = function(option)
				loadWidgetData("Defense Range GL4", "defrange_allyground", { "enabled", "ally", "ground" })
			end,
			onchange = function(option, value)
				--saveOptionValue('Defense Range', 'defrange', 'setAllyGround', { 'enabled', 'ally', 'ground' }, value)
				saveOptionValue(
					"Defense Range GL4",
					"defrange",
					"setAllyGround",
					{ "enabled", "ally", "ground" },
					value
				)
				saveOptionValue(
					"Defense Range GL4",
					"defrange",
					"setAllyGround",
					{ "enabled", "ally", "cannon" },
					value
				)
			end,
		},
		{
			id = "defrange_allynuke",
			parent = "defrange",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.defrange_allynuke"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.defrange_allynuke_descr"),
			widgetConfig = {
				"Defense Range GL4",
				{ "enabled", "ally", "nuke" },
				api = "defrange",
				get = "getAllyNuke",
				set = "setAllyNuke",
			},
		},
		{
			id = "defrange_allylrpc",
			parent = "defrange",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.defrange_allylrpc"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.defrange_allylrpc_descr"),
			widgetConfig = {
				"Defense Range GL4",
				{ "enabled", "ally", "lrpc" },
				api = "defrange",
				get = "getAllyLRPC",
				set = "setAllyLRPC",
			},
		},
		{
			id = "defrange_enemyair",
			parent = "defrange",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.defrange_enemyair"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.defrange_enemyair_descr"),
			widgetConfig = {
				"Defense Range GL4",
				{ "enabled", "enemy", "air" },
				api = "defrange",
				get = "getEnemyAir",
				set = "setEnemyAir",
			},
		},
		{
			id = "defrange_enemyground",
			parent = "defrange",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.defrange_enemyground"),
			type = "bool",
			value = (WG.defrange ~= nil and WG.defrange.getEnemyGround ~= nil and WG.defrange.getEnemyGround()),
			description = BAR.I18N("ui.settings.option.defrange_enemyground_descr"),
			onload = function(option)
				loadWidgetData("Defense Range GL4", "defrange_enemyground", { "enabled", "enemy", "ground" })
			end,
			onchange = function(option, value)
				--saveOptionValue('Defense Range', 'defrange', 'setEnemyGround', { 'enabled', 'enemy', 'ground' }, value)
				saveOptionValue(
					"Defense Range GL4",
					"defrange",
					"setEnemyGround",
					{ "enabled", "enemy", "ground" },
					value
				)
				saveOptionValue(
					"Defense Range GL4",
					"defrange",
					"setEnemyGround",
					{ "enabled", "enemy", "cannon" },
					value
				)
			end,
		},
		{
			id = "defrange_enemynuke",
			parent = "defrange",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.defrange_enemynuke"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.defrange_enemynuke_descr"),
			widgetConfig = {
				"Defense Range GL4",
				{ "enabled", "enemy", "nuke" },
				api = "defrange",
				get = "getEnemyNuke",
				set = "setEnemyNuke",
			},
		},
		{
			id = "defrange_enemylrpc",
			parent = "defrange",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.defrange_enemylrpc"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.defrange_enemylrpc_descr"),
			widgetConfig = {
				"Defense Range GL4",
				{ "enabled", "enemy", "lrpc" },
				api = "defrange",
				get = "getEnemyLRPC",
				set = "setEnemyLRPC",
			},
		},

		{
			id = "label_ui_spectator",
			group = "ui",
			name = BAR.I18N("ui.settings.option.label_spectator"),
			category = types.basic,
		},

		{
			id = "spectator_hud",
			group = "ui",
			category = types.basic,
			widget = "Spectator HUD",
			name = BAR.I18N("ui.settings.option.spectator_hud"),
			type = "bool",
			value = GetWidgetToggleValue("Spectator HUD"),
			description = BAR.I18N("ui.settings.option.spectator_hud_descr"),
		},
		{
			id = "spectator_hud_size",
			parent = "spectator_hud",
			group = "ui",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.spectator_hud_size"),
			type = "slider",
			min = 0.1,
			max = 2,
			step = 0.1,
			value = 0.8,
			description = "",
			widgetConfig = {
				"Spectator HUD",
				"widgetScale",
				api = "spectator_hud",
				get = "getWidgetSize",
				set = "setWidgetSize",
			},
		},

		{
			id = "spectator_hud_config",
			parent = "spectator_hud",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.spectator_hud_config"),
			type = "select",
			options = spectatorHUDConfigOptions,
			value = (WG.spectator_hud ~= nil and WG.spectator_hud.getConfig ~= nil and WG.spectator_hud.getConfig())
				or 1,
			description = BAR.I18N("ui.settings.option.spectator_hud_config_descr"),
			onload = function(option)
				loadWidgetData("Spectator HUD", "spectator_hud_config", { "widgetConfig" })
			end,
			onchange = function(option, value)
				saveOptionValue("Spectator HUD", "spectator_hud", "setConfig", { "widgetConfig" }, value)
				init()
			end,
		},

		{
			id = "spectator_hud_metric_metalIncome",
			parent = "spectator_hud",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.spectator_hud.metalIncome_title"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.spectator_hud.metalIncome_tooltip"),
			widgetConfig = {
				"Spectator HUD",
				{ "metricsEnabled", "metalIncome" },
				api = "spectator_hud",
				get = "getMetricEnabled",
				set = "setMetricEnabled",
				key = "metalIncome",
			},
		},
		{
			id = "spectator_hud_metric_energyIncome",
			parent = "spectator_hud",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.spectator_hud.energyIncome_title"),
			type = "bool",
			value = (
				WG.spectator_hud ~= nil
				and WG.spectator_hud.getMetricEnabled ~= nil
				and WG.spectator_hud.getMetricEnabled("energyIncome")
			) or false,
			description = BAR.I18N("ui.spectator_hud.energyIncome_tooltip"),
			onload = function(option)
				loadWidgetData(
					"Spectator HUD",
					"spectator_hud_metric_energyIncome",
					{ "metricsEnabled", "energyIncome" }
				)
			end,
			onchange = function(option, value)
				saveOptionValue(
					"Spectator HUD",
					"spectator_hud",
					"setMetricEnabled",
					{ "metricsEnabled", "energyIncome" },
					value,
					{ "energyIncome", value }
				)
			end,
		},
		{
			id = "spectator_hud_metric_buildPower",
			parent = "spectator_hud",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.spectator_hud.buildPower_title"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.spectator_hud.buildPower_tooltip"),
			widgetConfig = {
				"Spectator HUD",
				{ "metricsEnabled", "buildPower" },
				api = "spectator_hud",
				get = "getMetricEnabled",
				set = "setMetricEnabled",
				key = "buildPower",
			},
		},
		{
			id = "spectator_hud_metric_metalProduced",
			parent = "spectator_hud",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.spectator_hud.metalProduced_title"),
			type = "bool",
			value = (
				WG.spectator_hud ~= nil
				and WG.spectator_hud.getMetricEnabled ~= nil
				and WG.spectator_hud.getMetricEnabled("metalProduced")
			) or false,
			description = BAR.I18N("ui.spectator_hud.metalProduced_tooltip"),
			onload = function(option)
				loadWidgetData(
					"Spectator HUD",
					"spectator_hud_metric_metalProduced",
					{ "metricsEnabled", "metalProduced" }
				)
			end,
			onchange = function(option, value)
				saveOptionValue(
					"Spectator HUD",
					"spectator_hud",
					"setMetricEnabled",
					{ "metricsEnabled", "metalProduced" },
					value,
					{ "metalProduced", value }
				)
			end,
		},
		{
			id = "spectator_hud_metric_energyProduced",
			parent = "spectator_hud",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.spectator_hud.energyProduced_title"),
			type = "bool",
			value = (
				WG.spectator_hud ~= nil
				and WG.spectator_hud.getMetricEnabled ~= nil
				and WG.spectator_hud.getMetricEnabled("energyProduced")
			) or false,
			description = BAR.I18N("ui.spectator_hud.energyProduced_tooltip"),
			onload = function(option)
				loadWidgetData(
					"Spectator HUD",
					"spectator_hud_metric_energyProduced",
					{ "metricsEnabled", "energyProduced" }
				)
			end,
			onchange = function(option, value)
				saveOptionValue(
					"Spectator HUD",
					"spectator_hud",
					"setMetricEnabled",
					{ "metricsEnabled", "energyProduced" },
					value,
					{ "energyProduced", value }
				)
			end,
		},
		{
			id = "spectator_hud_metric_metalExcess",
			parent = "spectator_hud",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.spectator_hud.metalExcess_title"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.spectator_hud.metalExcess_tooltip"),
			widgetConfig = {
				"Spectator HUD",
				{ "metricsEnabled", "metalExcess" },
				api = "spectator_hud",
				get = "getMetricEnabled",
				set = "setMetricEnabled",
				key = "metalExcess",
			},
		},
		{
			id = "spectator_hud_metric_energyExcess",
			parent = "spectator_hud",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.spectator_hud.energyExcess_title"),
			type = "bool",
			value = (
				WG.spectator_hud ~= nil
				and WG.spectator_hud.getMetricEnabled ~= nil
				and WG.spectator_hud.getMetricEnabled("energyExcess")
			) or false,
			description = BAR.I18N("ui.spectator_hud.energyExcess_tooltip"),
			onload = function(option)
				loadWidgetData(
					"Spectator HUD",
					"spectator_hud_metric_energyExcess",
					{ "metricsEnabled", "energyExcess" }
				)
			end,
			onchange = function(option, value)
				saveOptionValue(
					"Spectator HUD",
					"spectator_hud",
					"setMetricEnabled",
					{ "metricsEnabled", "energyExcess" },
					value,
					{ "energyExcess", value }
				)
			end,
		},
		{
			id = "spectator_hud_metric_armyValue",
			parent = "spectator_hud",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.spectator_hud.armyValue_title"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.spectator_hud.armyValue_tooltip"),
			widgetConfig = {
				"Spectator HUD",
				{ "metricsEnabled", "armyValue" },
				api = "spectator_hud",
				get = "getMetricEnabled",
				set = "setMetricEnabled",
				key = "armyValue",
			},
		},
		{
			id = "spectator_hud_metric_defenseValue",
			parent = "spectator_hud",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.spectator_hud.defenseValue_title"),
			type = "bool",
			value = (
				WG.spectator_hud ~= nil
				and WG.spectator_hud.getMetricEnabled ~= nil
				and WG.spectator_hud.getMetricEnabled("defenseValue")
			) or false,
			description = BAR.I18N("ui.spectator_hud.defenseValue_tooltip"),
			onload = function(option)
				loadWidgetData(
					"Spectator HUD",
					"spectator_hud_metric_defenseValue",
					{ "metricsEnabled", "defenseValue" }
				)
			end,
			onchange = function(option, value)
				saveOptionValue(
					"Spectator HUD",
					"spectator_hud",
					"setMetricEnabled",
					{ "metricsEnabled", "defenseValue" },
					value,
					{ "defenseValue", value }
				)
			end,
		},
		{
			id = "spectator_hud_metric_utilityValue",
			parent = "spectator_hud",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.spectator_hud.utilityValue_title"),
			type = "bool",
			value = (
				WG.spectator_hud ~= nil
				and WG.spectator_hud.getMetricEnabled ~= nil
				and WG.spectator_hud.getMetricEnabled("utilityValue")
			) or false,
			description = BAR.I18N("ui.spectator_hud.utilityValue_tooltip"),
			onload = function(option)
				loadWidgetData(
					"Spectator HUD",
					"spectator_hud_metric_utilityValue",
					{ "metricsEnabled", "utilityValue" }
				)
			end,
			onchange = function(option, value)
				saveOptionValue(
					"Spectator HUD",
					"spectator_hud",
					"setMetricEnabled",
					{ "metricsEnabled", "utilityValue" },
					value,
					{ "utilityValue", value }
				)
			end,
		},
		{
			id = "spectator_hud_metric_economyValue",
			parent = "spectator_hud",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.spectator_hud.economyValue_title"),
			type = "bool",
			value = (
				WG.spectator_hud ~= nil
				and WG.spectator_hud.getMetricEnabled ~= nil
				and WG.spectator_hud.getMetricEnabled("economyValue")
			) or false,
			description = BAR.I18N("ui.spectator_hud.economyValue_tooltip"),
			onload = function(option)
				loadWidgetData(
					"Spectator HUD",
					"spectator_hud_metric_economyValue",
					{ "metricsEnabled", "economyValue" }
				)
			end,
			onchange = function(option, value)
				saveOptionValue(
					"Spectator HUD",
					"spectator_hud",
					"setMetricEnabled",
					{ "metricsEnabled", "economyValue" },
					value,
					{ "economyValue", value }
				)
			end,
		},
		{
			id = "spectator_hud_metric_damageDealt",
			parent = "spectator_hud",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.spectator_hud.damageDealt_title"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.spectator_hud.damageDealt_tooltip"),
			widgetConfig = {
				"Spectator HUD",
				{ "metricsEnabled", "damageDealt" },
				api = "spectator_hud",
				get = "getMetricEnabled",
				set = "setMetricEnabled",
				key = "damageDealt",
			},
		},

		-- SQUAD HULLS (widget: "Squad Selection", WG['squadselection']).
		{
			id = "label_squad_hulls",
			group = "ui",
			name = BAR.I18N("ui.settings.option.squadSelection_header_hulls"),
			category = types.basic,
		},
		{
			id = "squad_hullDisplayMode",
			group = "ui",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.squadSelection_hullDisplayMode"),
			type = "select",
			options = {
				BAR.I18N("ui.settings.option.squadSelection_hullDisplayMode_opt1"),
				BAR.I18N("ui.settings.option.squadSelection_hullDisplayMode_opt2"),
				BAR.I18N("ui.settings.option.squadSelection_hullDisplayMode_opt3"),
			},
			value = squadSelectValue.hullDisplayMode(),
			description = BAR.I18N("ui.settings.option.squadSelection_hullDisplayMode_descr"),
			onload = function(option)
				option.value = squadSelectValue.hullDisplayMode()
			end,
			onchange = function(_, value)
				saveOptionValue(
					"Squad Selection",
					"squadselection",
					"setVisualizationMode",
					{ "visualizationMode" },
					value == 1 and "none" or "convexHull"
				)
				saveOptionValue(
					"Squad Selection",
					"squadselection",
					"setShowReserveSquads",
					{ "showReserveSquads" },
					value == 2
				)
				if widgetHandler:IsWidgetKnown("Squad Selection Hull") then
					if value == 1 then
						widgetHandler:DisableWidget("Squad Selection Hull")
					else
						widgetHandler:EnableWidget("Squad Selection Hull")
					end
				end
				model.scheduleInit = true
			end,
		},

		{
			id = "squad_convexHullPadding",
			parent = "squad_hullDisplayMode",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.squadSelectionHull_Padding"),
			type = "slider",
			min = 0,
			max = 200,
			step = 5,
			value = 60,
			description = BAR.I18N("ui.settings.option.squadSelectionHull_Padding_descr"),
			widgetConfig = {
				"Squad Selection Hull",
				"convexHullPadding",
				api = "squadselectionhull",
				get = "getConvexHullPadding",
				set = "setConvexHullPadding",
			},
		},

		{
			id = "squad_convexHullArcResolution",
			parent = "squad_hullDisplayMode",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.squadSelectionHull_ArcResolution"),
			type = "slider",
			min = 0.05,
			max = 1.0,
			step = 0.05,
			value = 0.4,
			description = BAR.I18N("ui.settings.option.squadSelectionHull_ArcResolution_descr"),
			widgetConfig = {
				"Squad Selection Hull",
				"convexHullArcResolution",
				api = "squadselectionhull",
				get = "getConvexHullArcResolution",
				set = "setConvexHullArcResolution",
			},
		},

		{
			id = "squad_convexHullFillOpacity",
			parent = "squad_hullDisplayMode",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.squadSelectionHull_FillOpacity"),
			type = "slider",
			min = 0,
			max = 1,
			step = 0.05,
			value = 0.25,
			description = BAR.I18N("ui.settings.option.squadSelectionHull_FillOpacity_descr"),
			widgetConfig = {
				"Squad Selection Hull",
				"convexHullFillOpacity",
				api = "squadselectionhull",
				get = "getConvexHullFillOpacity",
				set = "setConvexHullFillOpacity",
			},
		},

		{
			id = "squad_convexHullBorderOpacity",
			parent = "squad_hullDisplayMode",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.squadSelectionHull_BorderOpacity"),
			type = "slider",
			min = 0,
			max = 1,
			step = 0.05,
			value = 0.3,
			widgetConfig = {
				"Squad Selection Hull",
				"convexHullBorderOpacity",
				api = "squadselectionhull",
				get = "getConvexHullBorderOpacity",
				set = "setConvexHullBorderOpacity",
			},
		},

		{
			id = "squad_convexHullBorderThickness",
			parent = "squad_hullDisplayMode",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.squadSelectionHull_BorderThickness"),
			type = "slider",
			min = 0.5,
			max = 5,
			step = 0.5,
			value = (
				WG["squadselectionhull"] ~= nil
				and WG["squadselectionhull"].getConvexHullBorderThickness ~= nil
				and WG["squadselectionhull"].getConvexHullBorderThickness()
			) or 2,
			onload = function(option)
				loadWidgetData(
					"Squad Selection Hull",
					"squad_convexHullBorderThickness",
					{ "convexHullBorderThickness" }
				)
			end,
			onchange = function(_, value)
				saveOptionValue(
					"Squad Selection Hull",
					"squadselectionhull",
					"setConvexHullBorderThickness",
					{ "convexHullBorderThickness" },
					value
				)
			end,
		},
		{
			id = "squad_convexHullColorMode",
			parent = "squad_hullDisplayMode",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.squadSelection_squadColorMode"),
			type = "select",
			options = {
				BAR.I18N("ui.settings.option.squadSelection_squadColorMode_opt1"),
				BAR.I18N("ui.settings.option.squadSelection_squadColorMode_opt2"),
				BAR.I18N("ui.settings.option.squadSelection_squadColorMode_opt3"),
			},
			value = squadSelectValue.squadColorMode(),
			description = BAR.I18N("ui.settings.option.squadSelection_squadColorMode_descr"),
			onload = function(option)
				option.value = squadSelectValue.squadColorMode()
			end,
			onchange = function(_, value)
				local modes = { "player", "custom", "squad" }
				saveOptionValue(
					"Squad Selection",
					"squadselection",
					"setSquadColorMode",
					{ "squadColorMode" },
					modes[value] or "player"
				)
			end,
		},

		{
			id = "squad_convexHullCustomColor",
			parent = "squad_hullDisplayMode",
			group = "ui",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.squadSelection_squadCustomColor"),
			type = "color",
			max = 1,
			step = 0.01,
			value = squadSelectValue.customColor(),
			description = BAR.I18N("ui.settings.option.squadSelection_squadCustomColor_descr"),
			onchange = function(_, value)
				for i, channel in ipairs({ "R", "G", "B" }) do
					saveOptionValue(
						"Squad Selection",
						"squadselection",
						"setSquadCustomColor" .. channel,
						{ "squadCustomColor" .. channel },
						value[i]
					)
				end
			end,
		},

		{
			id = "label_ui_developer",
			group = "ui",
			available = not model.devMode,
			name = BAR.I18N("ui.settings.option.label_developer"),
			category = types.advanced,
		},

		{
			id = "devmode",
			group = "ui",
			category = types.advanced,
			available = not model.devMode,
			name = BAR.I18N("ui.settings.option.devmode"),
			type = "bool",
			value = model.devUI,
			description = BAR.I18N("ui.settings.option.devmode_descr"),
			onchange = function(option, value)
				model.devUI = value
				Spring.SetConfigInt("DevUI", value and 1 or 0)
				Spring.SendCommands("luaui reload")
			end,
		},
	}
end
