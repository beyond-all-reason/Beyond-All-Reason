-- The developer tab's settings. model.lua says what a row can hold.

local devLanguageCodes = { "en", "fr", "de", "ru", "zh", "es", "test_unicode" }
devLanguageCodes = table.merge(devLanguageCodes, table.invert(devLanguageCodes))

local devLanguageNames = {}
for key, code in ipairs(devLanguageCodes) do
	devLanguageNames[key] = BAR.I18N.languages[code]
end

return function(model)
	local types = model.types
	local state = model.state
	local upkeep = model.upkeep
	local getOption = model.getOption
	local init = model.init
	local applyOptionValue = model.applyOptionValue
	local GetWidgetToggleValue = model.GetWidgetToggleValue
	return {
		-- DEV
		{
			id = "customwidgets",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.customwidgets"),
			type = "bool",
			value = widgetHandler.allowUserWidgets,
			description = BAR.I18N("ui.settings.option.customwidgets_descr"),
			onchange = function(option, value)
				widgetHandler.__allowUserWidgets = value
				Spring.SendCommands("luarules reloadluaui")
			end,
		},

		{
			id = "autocheat",
			group = "dev",
			category = types.dev,
			widget = "Dev Auto cheat",
			name = BAR.I18N("ui.settings.option.autocheat"),
			type = "bool",
			value = GetWidgetToggleValue("Dev Auto cheat"),
			description = BAR.I18N("ui.settings.option.autocheat_descr"),
		},
		{
			id = "restart",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.restart"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.restart_descr"),
			onchange = function(option, value)
				option.value = false
				Spring.Restart("", upkeep.startScript)
			end,
		},
		{
			id = "restart_with_state",
			group = "dev",
			category = types.dev,
			available = upkeep.isSinglePlayer,
			name = BAR.I18N("ui.settings.option.restart_with_state"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.restart_with_state_descr"),
			onchange = function(option, value)
				option.value = false
				Spring.SendLuaRulesMsg("restart_with_state")
			end,
		},

		{
			id = "label_dev_debug",
			group = "dev",
			name = BAR.I18N("ui.settings.option.label_debug"),
			category = types.dev,
		},

		{
			id = "profiler_widget",
			group = "dev",
			category = types.dev,
			widget = "Widget Profiler",
			prefix = BAR.I18N("ui.settings.option.profiler"),
			name = BAR.I18N("ui.settings.option.profiler_widget"),
			type = "bool",
			value = GetWidgetToggleValue("Widget Profiler"),
		},
		{
			id = "profiler_gadget",
			parent = "profiler_widget",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.profiler_gadget"),
			type = "bool",
			value = false,
			onchange = function(option, value)
				Spring.SendCommands("luarules profile")
			end,
		},
		{
			id = "profiler_sort_by_load",
			parent = "profiler_widget",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.profiler_sort_by_load"),
			type = "bool",
			value = true,
			description = BAR.I18N("ui.settings.option.profiler_sort_by_load_descr"),
			configInt = "profiler_sort_by_load",
		},
		{
			id = "profiler_averagetime",
			parent = "profiler_widget",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.profiler_averagetime"),
			type = "slider",
			min = 0.1,
			max = 10,
			step = 0.1,
			value = 2,
			description = BAR.I18N("ui.settings.option.profiler_averagetime_descr"),
			configFloat = "profiler_averagetime",
		},
		{
			id = "framegrapher",
			group = "dev",
			category = types.dev,
			widget = "Frame Grapher",
			name = BAR.I18N("ui.settings.option.framegrapher"),
			type = "bool",
			value = GetWidgetToggleValue("Frame Grapher"),
			description = "",
		},

		{
			id = "debugcolvol",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.debugcolvol"),
			type = "bool",
			value = false,
			description = "",
			onchange = function(option, value)
				Spring.SendCommands("DebugColVol " .. (value and "1" or "0"))
			end,
		},
		{
			id = "echocamerastate",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.echocamerastate"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.echocamerastate_descr"),
			onchange = function(option, value)
				option.value = false
				Spring.Echo(Spring.GetCameraState())
			end,
		},

		{
			id = "label_dev_other",
			group = "dev",
			name = BAR.I18N("ui.settings.option.label_other"),
			category = types.dev,
		},

		{
			id = "storedefaultsettings",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.storedefaultsettings"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.storedefaultsettings_descr"),
			configInt = "StoreDefaultSettings",
		},

		{
			id = "cegbrowser",
			group = "dev",
			category = types.dev,
			widget = "CEG Effects Browser",
			name = BAR.I18N("ui.settings.option.cegbrowser"),
			type = "bool",
			value = GetWidgetToggleValue("CEG Effects Browser"),
			description = BAR.I18N("ui.settings.option.cegbrowser_descr"),
		},

		{
			id = "startboxeditor",
			group = "dev",
			category = types.dev,
			widget = "Startbox Editor",
			name = BAR.I18N("ui.settings.option.startboxeditor"),
			type = "bool",
			value = GetWidgetToggleValue("Startbox Editor"),
			description = BAR.I18N("ui.settings.option.startboxeditor_descr"),
		},

		{
			id = "language_dev",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.language"),
			type = "select",
			options = devLanguageNames,
			value = devLanguageCodes[BAR.I18N.getLocale()],
			onchange = function(option, value)
				local devLanguage = devLanguageCodes[value]
				WG.language.setLanguage(devLanguage)
			end,
		},
		{
			id = "font",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.font"),
			type = "select",
			options = {},
			value = 1,
			description = BAR.I18N("ui.settings.option.font_descr"),
			onchange = function(option, value)
				if VFS.FileExists("fonts/" .. option.optionsFont[value]) then
					Spring.SetConfigString("bar_font", option.optionsFont[value])
					Spring.SendCommands("luarules reloadluaui")
				end
			end,
		},
		{
			id = "font2",
			--parent = "font",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.font2"),
			type = "select",
			options = {},
			value = 1,
			description = BAR.I18N("ui.settings.option.font2_descr"),
			onchange = function(option, value)
				if VFS.FileExists("fonts/" .. option.optionsFont[value]) then
					Spring.SetConfigString("bar_font2", option.optionsFont[value])
					Spring.SendCommands("luarules reloadluaui")
				end
			end,
		},

		--{ id = "label_dev_unit", group = "dev", name = Spring.I18N('ui.settings.option.label_unit'), category = types.dev },
		--{ id = "label_dev_unit_spacer", group = "dev", category = types.dev },
		--
		--{ id = "tonemapA", group = "dev", category = types.dev, name = Spring.I18N('ui.settings.option.tonemap') .. widgetOptionColor .. "  1", type = "slider", min = 0, max = 7, step = 0.01, value = Spring.GetConfigFloat("tonemapA", 4.8), description = "",
		--  onchange = function(option, value)
		--	  Spring.SetConfigFloat("tonemapA", value)
		--	  Spring.SendCommands("luarules updatesun")
		--	  Spring.SendCommands("luarules GlassUpdateSun")
		--  end,
		--},
		--{ id = "tonemapB", group = "dev", category = types.dev, name = widgetOptionColor .. "   2", type = "slider", min = 0, max = 2, step = 0.01, value = Spring.GetConfigFloat("tonemapB", 0.75), description = "",
		--  onchange = function(option, value)
		--	  Spring.SetConfigFloat("tonemapB", value)
		--	  Spring.SendCommands("luarules updatesun")
		--	  Spring.SendCommands("luarules GlassUpdateSun")
		--  end,
		--},
		--{ id = "tonemapC", group = "dev", category = types.dev, name = widgetOptionColor .. "   3", type = "slider", min = 0, max = 5, step = 0.01, value = Spring.GetConfigFloat("tonemapC", 3.5), description = "",
		--  onchange = function(option, value)
		--	  Spring.SetConfigFloat("tonemapC", value)
		--	  Spring.SendCommands("luarules updatesun")
		--	  Spring.SendCommands("luarules GlassUpdateSun")
		--  end,
		--},
		--{ id = "tonemapD", group = "dev", category = types.dev, name = widgetOptionColor .. "   4", type = "slider", min = 0, max = 3, step = 0.01, value = Spring.GetConfigFloat("tonemapD", 0.85), description = "",
		--  onchange = function(option, value)
		--	  Spring.SetConfigFloat("tonemapD", value)
		--	  Spring.SendCommands("luarules updatesun")
		--	  Spring.SendCommands("luarules GlassUpdateSun")
		--  end,
		--},
		--{ id = "tonemapE", group = "dev", category = types.dev, name = widgetOptionColor .. "   5", type = "slider", min = 0.75, max = 1.5, step = 0.01, value = Spring.GetConfigFloat("tonemapE", 1.0), description = "",
		--  onchange = function(option, value)
		--	  Spring.SetConfigFloat("tonemapE", value)
		--	  Spring.SendCommands("luarules updatesun")
		--	  Spring.SendCommands("luarules GlassUpdateSun")
		--  end,
		--},
		--{ id = "envAmbient", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.envAmbient'), type = "slider", min = 0, max = 1, step = 0.01, value = Spring.GetConfigFloat("envAmbient", 0.25), description = "",
		--  onchange = function(option, value)
		--	  Spring.SetConfigFloat("envAmbient", value)
		--	  Spring.SendCommands("luarules updatesun")
		--	  Spring.SendCommands("luarules GlassUpdateSun")
		--  end,
		--},
		--{ id = "unitSunMult", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.unitSunMult'), type = "slider", min = 0.7, max = 1.6, step = 0.01, value = Spring.GetConfigFloat("unitSunMult", 1.0), description = "",
		--  onchange = function(option, value)
		--	  Spring.SetConfigFloat("unitSunMult", value)
		--	  Spring.SendCommands("luarules updatesun")
		--	  Spring.SendCommands("luarules GlassUpdateSun")
		--  end,
		--},
		--{ id = "unitExposureMult", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.unitExposureMult'), type = "slider", min = 0.6, max = 1.25, step = 0.01, value = Spring.GetConfigFloat("unitExposureMult", 1.0), description = "",
		--  onchange = function(option, value)
		--	  Spring.SetConfigFloat("unitExposureMult", value)
		--	  Spring.SendCommands("luarules updatesun")
		--	  Spring.SendCommands("luarules GlassUpdateSun")
		--  end,
		--},
		--{ id = "modelGamma", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.modelGamma'), type = "slider", min = 0.7, max = 1.7, step = 0.01, value = Spring.GetConfigFloat("modelGamma", 1.0), description = "",
		--  onchange = function(option, value)
		--	  Spring.SetConfigFloat("modelGamma", value)
		--	  Spring.SendCommands("luarules updatesun")
		--	  Spring.SendCommands("luarules GlassUpdateSun")
		--  end,
		--},
		--{ id = "tonemapDefaults", group = "dev", category = types.dev, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.tonemapDefaults'), type = "bool", value = GetWidgetToggleValue("Unit Reclaimer"), description = "",
		--  onchange = function(option, value)
		--	  Spring.SetConfigFloat("tonemapA", 4.75)
		--	  Spring.SetConfigFloat("tonemapB", 0.75)
		--	  Spring.SetConfigFloat("tonemapC", 3.5)
		--	  Spring.SetConfigFloat("tonemapD", 0.85)
		--	  Spring.SetConfigFloat("tonemapE", 1.0)
		--	  Spring.SetConfigFloat("envAmbient", 0.25)
		--	  Spring.SetConfigFloat("unitSunMult", 1.0)
		--	  Spring.SetConfigFloat("unitExposureMult", 1.0)
		--	  Spring.SetConfigFloat("modelGamma", 1.0)
		--	  getOption('tonemapA').value = Spring.GetConfigFloat("tonemapA")
		--	  getOption('tonemapB').value = Spring.GetConfigFloat("tonemapB")
		--	  getOption('tonemapC').value = Spring.GetConfigFloat("tonemapC")
		--	  getOption('tonemapD').value = Spring.GetConfigFloat("tonemapD")
		--	  getOption('tonemapE').value = Spring.GetConfigFloat("tonemapE")
		--	  getOption('envAmbient').value = Spring.GetConfigFloat("envAmbient")
		--	  getOption('unitSunMult').value = Spring.GetConfigFloat("unitSunMult")
		--	  getOption('unitExposureMult').value = Spring.GetConfigFloat("unitExposureMult")
		--	  getOption('modelGamma').value = Spring.GetConfigFloat("modelGamma")
		--	  Spring.SendCommands("luarules updatesun")
		--	  Spring.SendCommands("luarules GlassUpdateSun")
		--	  getOption('tonemapDefaults').value = false
		--  end,
		--},

		{
			id = "label_dev_map",
			group = "dev",
			name = BAR.I18N("ui.settings.option.label_map"),
			category = types.dev,
		},

		{
			id = "sun_y",
			group = "dev",
			category = types.dev,
			prefix = BAR.I18N("ui.settings.option.sun"),
			name = BAR.I18N("ui.settings.option.sun_y"),
			type = "slider",
			min = 0.05,
			max = 0.9999,
			step = 0.0001,
			value = select(2, gl.GetSun("pos")),
			onchange = function(option, value)
				local sunX, sunY, sunZ = gl.GetSun("pos")
				sunY = value
				if sunY < option.min then
					sunY = option.min
				end
				if sunY > option.max then
					sunY = option.max
				end
				option.value = sunY
				Spring.SetSunDirection(sunX, sunY, sunZ)
				-- just so that map/model lighting gets updated
				Spring.SetSunLighting({
					groundShadowDensity = gl.GetSun("shadowDensity"),
					modelShadowDensity = gl.GetSun("shadowDensity"),
				})
				Spring.Echo(gl.GetSun())
			end,
		},
		{
			id = "sun_x",
			parent = "sun_y",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.sun_x"),
			type = "slider",
			min = -0.9999,
			max = 0.9999,
			step = 0.0001,
			value = select(1, gl.GetSun("pos")),
			onchange = function(option, value)
				local sunX, sunY, sunZ = gl.GetSun("pos")
				sunX = value
				if sunX < option.min then
					sunX = option.min
				end
				if sunX > option.max then
					sunX = option.max
				end
				option.value = sunX
				Spring.SetSunDirection(sunX, sunY, sunZ)
				-- just so that map/model lighting gets updated
				Spring.SetSunLighting({
					groundShadowDensity = gl.GetSun("shadowDensity"),
					modelShadowDensity = gl.GetSun("shadowDensity"),
				})
				Spring.Echo(gl.GetSun())
			end,
		},
		{
			id = "sun_z",
			parent = "sun_y",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.sun_z"),
			type = "slider",
			min = -0.9999,
			max = 0.9999,
			step = 0.0001,
			value = select(3, gl.GetSun("pos")),
			onchange = function(option, value)
				local sunX, sunY, sunZ = gl.GetSun("pos")
				sunZ = value
				if sunZ < option.min then
					sunZ = option.min
				end
				if sunZ > option.max then
					sunZ = option.max
				end
				option.value = sunZ
				Spring.SetSunDirection(sunX, sunY, sunZ)
				-- just so that map/model lighting gets updated
				Spring.SetSunLighting({
					groundShadowDensity = gl.GetSun("shadowDensity"),
					modelShadowDensity = gl.GetSun("shadowDensity"),
				})
				Spring.Echo(gl.GetSun())
			end,
		},
		{
			id = "sun_reset",
			parent = "sun_y",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.sun_reset"),
			type = "bool",
			value = false,
			onchange = function(option, value)
				getOption("sun_x").value = state.defaultMapSunPos[1]
				getOption("sun_y").value = state.defaultMapSunPos[2]
				getOption("sun_z").value = state.defaultMapSunPos[3]
				option.value = false
				Spring.SetSunDirection(state.defaultMapSunPos[1], state.defaultMapSunPos[2], state.defaultMapSunPos[3])
				-- just so that map/model lighting gets updated
				Spring.SetSunLighting({
					groundShadowDensity = gl.GetSun("shadowDensity"),
					modelShadowDensity = gl.GetSun("shadowDensity"),
				})
				Spring.Echo(gl.GetSun())
			end,
		},

		{
			id = "fog_start",
			group = "dev",
			category = types.dev,
			prefix = BAR.I18N("ui.settings.option.fog"),
			name = BAR.I18N("ui.settings.option.fog_start"),
			type = "slider",
			min = 0,
			max = 1.99,
			step = 0.01,
			value = gl.GetAtmosphere("fogStart"),
			onchange = function(option, value)
				if getOption("fog_end") and value >= getOption("fog_end").value then
					applyOptionValue(getOption("fog_end"), value + 0.01)
				end
				Spring.SetAtmosphere({ fogStart = value })
			end,
		},
		{
			id = "fog_end",
			parent = "fog_start",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.fog_end"),
			type = "slider",
			min = 0.5,
			max = 2,
			step = 0.01,
			value = gl.GetAtmosphere("fogEnd"),
			onchange = function(option, value)
				if getOption("fog_start") and value <= getOption("fog_start").value then
					applyOptionValue(getOption("fog_start"), value - 0.01)
				end
				Spring.SetAtmosphere({ fogEnd = value })
			end,
		},
		{
			id = "fog_reset",
			parent = "fog_start",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.fog_reset"),
			type = "bool",
			value = false,
			description = "",
			onchange = function(option, value)
				if getOption("fog_start") then
					getOption("fog_start").value = state.defaultMapFog.fogStart
					getOption("fog_end").value = state.defaultMapFog.fogEnd
					option.value = false
				end
				Spring.SetAtmosphere({ fogStart = state.defaultMapFog.fogStart, fogEnd = state.defaultMapFog.fogEnd })
			end,
		},

		{
			id = "fog_color",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.fog_color"),
			type = "color",
			max = 1,
			step = 0.01,
			value = { gl.GetAtmosphere("fogColor") },
			description = "",
			onchange = function(option, value)
				local alpha = select(4, gl.GetAtmosphere("fogColor"))
				Spring.SetAtmosphere({ fogColor = { value[1], value[2], value[3], alpha } })
			end,
		},
		{
			id = "fog_color_reset",
			parent = "fog_color",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.fog_color_reset"),
			type = "bool",
			value = false,
			description = "",
			onchange = function(option, value)
				local fogColor = state.defaultMapFog.fogColor
				getOption("fog_color").value = { fogColor[1], fogColor[2], fogColor[3] }
				option.value = false
				Spring.SetAtmosphere({ fogColor = state.defaultMapFog.fogColor })
				Spring.Echo("reset map fog color defaults")
			end,
		},

		{
			id = "map_voidwater",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.map_voidwater"),
			type = "bool",
			value = false,
			description = "",
			onload = function(option)
				option.value = gl.GetMapRendering("voidWater")
			end,
			onchange = function(option, value)
				Spring.SetMapRenderingParams({ voidWater = value })
			end,
		},
		{
			id = "map_voidground",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.map_voidground"),
			type = "bool",
			value = false,
			description = "",
			onload = function(option)
				option.value = gl.GetMapRendering("voidGround")
			end,
			onchange = function(option, value)
				Spring.SetMapRenderingParams({ voidGround = value })
			end,
		},

		{
			id = "map_splatdetailnormaldiffusealpha",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.map_splatdetailnormaldiffusealpha"),
			type = "bool",
			value = false,
			description = "",
			onload = function(option)
				option.value = gl.GetMapRendering("splatDetailNormalDiffuseAlpha")
			end,
			onchange = function(option, value)
				Spring.SetMapRenderingParams({ splatDetailNormalDiffuseAlpha = value })
			end,
		},

		{
			id = "map_splattexmults_r",
			group = "dev",
			category = types.dev,
			prefix = BAR.I18N("ui.settings.option.map_splattexmults"),
			name = "0",
			type = "slider",
			min = 0,
			max = 1.5,
			step = 0.001,
			value = 0,
			description = "",
			onload = function(option)
				local r, _, _, _ = gl.GetMapRendering("splatTexMults")
				option.value = r
			end,
			onchange = function(option, value)
				local r, g, b, a = gl.GetMapRendering("splatTexMults")
				Spring.SetMapRenderingParams({ splatTexMults = { value, g, b, a } })
			end,
		},
		{
			id = "map_splattexmults_g",
			parent = "map_splattexmults_r",
			group = "dev",
			category = types.dev,
			name = "1",
			type = "slider",
			min = 0,
			max = 1.5,
			step = 0.001,
			value = 0,
			description = "",
			onload = function(option)
				local _, g, _, _ = gl.GetMapRendering("splatTexMults")
				option.value = g
			end,
			onchange = function(option, value)
				local r, g, b, a = gl.GetMapRendering("splatTexMults")
				Spring.SetMapRenderingParams({ splatTexMults = { r, value, b, a } })
			end,
		},
		{
			id = "map_splattexmults_b",
			parent = "map_splattexmults_r",
			group = "dev",
			category = types.dev,
			name = "2",
			type = "slider",
			min = 0,
			max = 1.5,
			step = 0.001,
			value = 0,
			description = "",
			onload = function(option)
				local _, _, b, _ = gl.GetMapRendering("splatTexMults")
				option.value = b
			end,
			onchange = function(option, value)
				local r, g, b, a = gl.GetMapRendering("splatTexMults")
				Spring.SetMapRenderingParams({ splatTexMults = { r, g, value, a } })
			end,
		},
		{
			id = "map_splattexmults_a",
			parent = "map_splattexmults_r",
			group = "dev",
			category = types.dev,
			name = "3",
			type = "slider",
			min = 0,
			max = 1.5,
			step = 0.001,
			value = 0,
			description = "",
			onload = function(option)
				local r, g, b, a = gl.GetMapRendering("splatTexMults")
				option.value = a
			end,
			onchange = function(option, value)
				local r, g, b, _ = gl.GetMapRendering("splatTexMults")
				Spring.SetMapRenderingParams({ splatTexMults = { r, g, b, value } })
			end,
		},

		{
			id = "map_splattexacales_r",
			group = "dev",
			category = types.dev,
			prefix = BAR.I18N("ui.settings.option.map_splattexacales"),
			name = "0",
			type = "slider",
			min = 0,
			max = 0.02,
			step = 0.0001,
			value = 0,
			description = "",
			onload = function(option)
				local r, _, _, _ = gl.GetMapRendering("splatTexScales")
				option.value = r
			end,
			onchange = function(option, value)
				local r, g, b, a = gl.GetMapRendering("splatTexScales")
				Spring.SetMapRenderingParams({ splatTexScales = { value, g, b, a } })
			end,
		},
		{
			id = "map_splattexacales_g",
			parent = "map_splattexacales_r",
			group = "dev",
			category = types.dev,
			name = "1",
			type = "slider",
			min = 0,
			max = 0.02,
			step = 0.0001,
			value = 0,
			description = "",
			onload = function(option)
				local _, g, _, _ = gl.GetMapRendering("splatTexScales")
				option.value = g
			end,
			onchange = function(option, value)
				local r, g, b, a = gl.GetMapRendering("splatTexScales")
				Spring.SetMapRenderingParams({ splatTexScales = { r, value, b, a } })
			end,
		},
		{
			id = "map_splattexacales_b",
			parent = "map_splattexacales_r",
			group = "dev",
			category = types.dev,
			name = "2",
			type = "slider",
			min = 0,
			max = 0.02,
			step = 0.0001,
			value = 0,
			description = "",
			onload = function(option)
				local _, _, b, _ = gl.GetMapRendering("splatTexScales")
				option.value = b
			end,
			onchange = function(option, value)
				local r, g, b, a = gl.GetMapRendering("splatTexScales")
				Spring.SetMapRenderingParams({ splatTexScales = { r, g, value, a } })
			end,
		},
		{
			id = "map_splattexacales_a",
			parent = "map_splattexacales_r",
			group = "dev",
			category = types.dev,
			name = "3",
			type = "slider",
			min = 0,
			max = 0.02,
			step = 0.0001,
			value = 0,
			description = "",
			onload = function(option)
				local r, g, b, a = gl.GetMapRendering("splatTexScales")
				option.value = a
			end,
			onchange = function(option, value)
				local r, g, b, _ = gl.GetMapRendering("splatTexScales")
				Spring.SetMapRenderingParams({ splatTexScales = { r, g, b, value } })
			end,
		},

		{
			id = "GroundShadowDensity",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.GroundShadowDensity"),
			type = "slider",
			min = 0,
			max = 1.5,
			step = 0.001,
			value = 0,
			description = "",
			onload = function(option)
				local groundshadowDensity = gl.GetSun("shadowDensity", "ground")
				option.value = groundshadowDensity
			end,
			onchange = function(option, value)
				Spring.SetSunLighting({ groundShadowDensity = value })
				Spring.SendCommands("luarules updatesun")
			end,
		},

		{
			id = "UnitShadowDensity",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.UnitShadowDensity"),
			type = "slider",
			min = 0,
			max = 1.5,
			step = 0.001,
			value = 0,
			description = "",
			onload = function(option)
				local groundshadowDensity = gl.GetSun("shadowDensity", "unit")
				option.value = groundshadowDensity
			end,
			onchange = function(option, value)
				Spring.SetSunLighting({ modelShadowDensity = value })
				Spring.SendCommands("luarules updatesun")
			end,
		},

		{
			id = "color_groundambient",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.color_groundambient"),
			type = "color",
			max = 2,
			white = 1,
			step = 0.001,
			value = { 0, 0, 0 },
			description = "",
			onload = function(option)
				option.value = { gl.GetSun("ambient") }
			end,
			onchange = function(option, value)
				Spring.SetSunLighting({ groundAmbientColor = { value[1], value[2], value[3] } })
				Spring.SendCommands("luarules updatesun")
			end,
		},

		{
			id = "color_grounddiffuse",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.color_grounddiffuse"),
			type = "color",
			max = 2,
			white = 1,
			step = 0.001,
			value = { 0, 0, 0 },
			description = "",
			onload = function(option)
				option.value = { gl.GetSun("diffuse") }
			end,
			onchange = function(option, value)
				Spring.SetSunLighting({ groundDiffuseColor = { value[1], value[2], value[3] } })
				Spring.SendCommands("luarules updatesun")
			end,
		},

		{
			id = "color_groundspecular",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.color_groundspecular"),
			type = "color",
			max = 2,
			white = 1,
			step = 0.001,
			value = { 0, 0, 0 },
			description = "",
			onload = function(option)
				option.value = { gl.GetSun("specular") }
			end,
			onchange = function(option, value)
				Spring.SetSunLighting({ groundSpecularColor = { value[1], value[2], value[3] } })
				Spring.SendCommands("luarules updatesun")
			end,
		},

		{
			id = "color_unitambient",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.color_unitambient"),
			type = "color",
			max = 2,
			white = 1,
			step = 0.001,
			value = { 0, 0, 0 },
			description = "",
			onload = function(option)
				option.value = { gl.GetSun("ambient", "unit") }
			end,
			onchange = function(option, value)
				Spring.SetSunLighting({ unitAmbientColor = { value[1], value[2], value[3] } })
				Spring.SendCommands("luarules updatesun")
			end,
		},

		{
			id = "color_unitdiffuse",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.color_unitdiffuse"),
			type = "color",
			max = 2,
			white = 1,
			step = 0.001,
			value = { 0, 0, 0 },
			description = "",
			onload = function(option)
				option.value = { gl.GetSun("diffuse", "unit") }
			end,
			onchange = function(option, value)
				Spring.SetSunLighting({ unitDiffuseColor = { value[1], value[2], value[3] } })
				Spring.SendCommands("luarules updatesun")
			end,
		},

		{
			id = "color_unitspecular",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.color_unitspecular"),
			type = "color",
			max = 2,
			white = 1,
			step = 0.001,
			value = { 0, 0, 0 },
			description = "",
			onload = function(option)
				option.value = { gl.GetSun("specular", "unit") }
			end,
			onchange = function(option, value)
				Spring.SetSunLighting({ unitSpecularColor = { value[1], value[2], value[3] } })
				Spring.SendCommands("luarules updatesun")
			end,
		},

		{
			id = "suncolor",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.suncolor"),
			type = "color",
			max = 1,
			step = 0.001,
			value = { 0, 0, 0 },
			description = "",
			onload = function(option)
				option.value = { gl.GetAtmosphere("sunColor") }
			end,
			onchange = function(option, value)
				Spring.SetAtmosphere({ sunColor = { value[1], value[2], value[3] } })
				Spring.SendCommands("luarules updatesun")
			end,
		},

		{
			id = "skycolor",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.skycolor"),
			type = "color",
			max = 1,
			step = 0.001,
			value = { 0, 0, 0 },
			description = "",
			onload = function(option)
				option.value = { gl.GetAtmosphere("skyColor") }
			end,
			onchange = function(option, value)
				Spring.SetAtmosphere({ skyColor = { value[1], value[2], value[3] } })
				Spring.SendCommands("luarules updatesun")
			end,
		},

		{
			id = "sunlighting_reset",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.sunlighting_reset"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.sunlighting_reset_descr"),
			onchange = function(option, value)
				option.value = false
				-- just so that map/model lighting gets updated
				Spring.SetSunLighting(state.defaultSunLighting)
				Spring.Echo("reset ground/unit coloring")
				init()
			end,
		},

		{
			id = "skyaxisangle_angle",
			group = "dev",
			category = types.dev,
			prefix = BAR.I18N("ui.settings.option.skybox"),
			name = BAR.I18N("ui.settings.option.angle"),
			type = "slider",
			min = -3.14,
			max = 3.14,
			step = 0.01,
			value = 0,
			description = "",
			onload = function(option)
				local x, y, z, angle = gl.GetAtmosphere("skyAxisAngle")
				option.value = angle
			end,
			onchange = function(option, value)
				local x, y, z, angle = gl.GetAtmosphere("skyAxisAngle")
				angle = value
				Spring.SetAtmosphere({ skyAxisAngle = { x, y, z, angle } })
			end,
		},
		{
			id = "skyaxisangle_x",
			parent = "skyaxisangle_angle",
			group = "dev",
			category = types.dev,
			name = "x",
			type = "slider",
			min = -1,
			max = 1,
			step = 0.01,
			value = 0,
			description = "",
			onload = function(option)
				local x, _, _, _ = gl.GetAtmosphere("skyAxisAngle")
				option.value = x
			end,
			onchange = function(option, value)
				local x, y, z, angle = gl.GetAtmosphere("skyAxisAngle")
				x = value
				Spring.SetAtmosphere({ skyAxisAngle = { x, y, z, angle } })
			end,
		},
		{
			id = "skyaxisangle_y",
			parent = "skyaxisangle_angle",
			group = "dev",
			category = types.dev,
			name = "y",
			type = "slider",
			min = -1,
			max = 1,
			step = 0.01,
			value = 0,
			description = "",
			onload = function(option)
				local _, y, _, _ = gl.GetAtmosphere("skyAxisAngle")
				option.value = y
			end,
			onchange = function(option, value)
				local x, y, z, angle = gl.GetAtmosphere("skyAxisAngle")
				y = value
				Spring.SetAtmosphere({ skyAxisAngle = { x, y, z, angle } })
			end,
		},
		{
			id = "skyaxisangle_z",
			parent = "skyaxisangle_angle",
			group = "dev",
			category = types.dev,
			name = "z",
			type = "slider",
			min = -1,
			max = 1,
			step = 0.01,
			value = 0,
			description = "",
			onload = function(option)
				local _, _, z, _ = gl.GetAtmosphere("skyAxisAngle")
				option.value = z
			end,
			onchange = function(option, value)
				local x, y, z, angle = gl.GetAtmosphere("skyAxisAngle")
				z = value
				Spring.SetAtmosphere({ skyAxisAngle = { x, y, z, angle } })
			end,
		},

		{
			id = "skyaxisangle_reset",
			parent = "skyaxisangle_angle",
			group = "dev",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.reset"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.sunlighting_reset_descr"),
			onchange = function(option, value)
				option.value = false
				Spring.SetAtmosphere({ skyAxisAngle = state.defaultSkyAxisAngle })
				Spring.Echo("reset skyAxisAngle atmosphere")
				init()
			end,
		},
		{
			id = "label_dev_water",
			group = "dev",
			name = BAR.I18N("ui.settings.option.label_water"),
			category = types.dev,
		},

		-- springsettings water params
		{
			id = "waterconfig_shorewaves",
			group = "dev",
			category = types.dev,
			prefix = "Bumpwater settings",
			name = "shorewaves",
			type = "bool",
			value = Spring.GetConfigInt("BumpWaterShoreWaves", 1) == 1,
			description = "",
			onchange = function(option, value)
				Spring.SetConfigInt("BumpWaterShoreWaves", (value and 1 or 0))
				-- rebuilds the water from the config; /water 4 does nothing while it is already 4
				Spring.SetWaterParams({})
			end,
		},
		{
			id = "waterconfig_dynamicwaves",
			parent = "waterconfig_shorewaves",
			group = "dev",
			category = types.dev,
			name = "dynamic waves",
			type = "bool",
			value = Spring.GetConfigInt("BumpWaterDynamicWaves", 1) == 1,
			description = "Springsettings.cfg config",
			onchange = function(option, value)
				Spring.SetConfigInt("BumpWaterDynamicWaves", (value and 1 or 0))
				Spring.SetWaterParams({})
			end,
		},
		{
			id = "waterconfig_endless",
			parent = "waterconfig_shorewaves",
			group = "dev",
			category = types.dev,
			name = "endless",
			type = "bool",
			value = Spring.GetConfigInt("BumpWaterEndlessOcean", 1) == 1,
			description = "Springsettings.cfg config",
			onchange = function(option, value)
				Spring.SetConfigInt("BumpWaterEndlessOcean", (value and 1 or 0))
				Spring.SetWaterParams({})
			end,
		},
		{
			id = "waterconfig_occlusionquery",
			parent = "waterconfig_shorewaves",
			group = "dev",
			category = types.dev,
			name = "occlusion query",
			type = "bool",
			value = Spring.GetConfigInt("BumpWaterOcclusionQuery", 1) == 1,
			description = "Springsettings.cfg config",
			onchange = function(option, value)
				Spring.SetConfigInt("BumpWaterOcclusionQuery", (value and 1 or 0))
				Spring.SetWaterParams({})
			end,
		},
		{
			id = "waterconfig_blurreflection",
			parent = "waterconfig_shorewaves",
			group = "dev",
			category = types.dev,
			name = "blur reflection",
			type = "bool",
			value = Spring.GetConfigInt("BumpWaterBlurReflection", 1) == 1,
			description = "Springsettings.cfg config",
			onchange = function(option, value)
				Spring.SetConfigInt("BumpWaterBlurReflection", (value and 1 or 0))
				Spring.SetWaterParams({})
			end,
		},
		{
			id = "waterconfig_anisotropy",
			parent = "waterconfig_shorewaves",
			group = "dev",
			category = types.dev,
			name = "anisotropy",
			type = "slider",
			min = 0,
			max = 16,
			step = 1,
			value = Spring.GetConfigFloat("BumpWaterAnisotropy", 0),
			description = "Springsettings.cfg config",
			onchange = function(option, value)
				Spring.SetConfigFloat("BumpWaterAnisotropy", value)
				Spring.SetWaterParams({})
			end,
		},
		{
			id = "wateconfigr_usedepthtexture",
			parent = "waterconfig_shorewaves",
			group = "dev",
			category = types.dev,
			name = "use depth texture",
			type = "bool",
			value = Spring.GetConfigInt("BumpWaterUseDepthTexture", 1) == 1,
			description = "Springsettings.cfg config",
			onchange = function(option, value)
				Spring.SetConfigInt("BumpWaterUseDepthTexture", (value and 1 or 0))
				Spring.SetWaterParams({})
			end,
		},
		{
			id = "waterconfig_useuniforms",
			parent = "waterconfig_shorewaves",
			group = "dev",
			category = types.dev,
			name = "use uniforms",
			type = "bool",
			value = Spring.GetConfigInt("BumpWaterUseUniforms", 1) == 1,
			description = "Springsettings.cfg config",
			onchange = function(option, value)
				Spring.SetConfigInt("BumpWaterUseUniforms", (value and 1 or 0))
				Spring.SetWaterParams({})
			end,
		},

		-- GL water params
		{
			id = "water_shorewaves",
			group = "dev",
			category = types.dev,
			prefix = "Bumpwater GL params",
			name = "shorewaves",
			type = "bool",
			value = gl.GetWaterRendering("shoreWaves"),
			description = "",
			onchange = function(option, value)
				Spring.SetWaterParams({ shoreWaves = value })
				Spring.SendCommands("water 4")
			end,
		},
		{
			id = "water_haswaterplane",
			parent = "water_shorewaves",
			group = "dev",
			category = types.dev,
			name = "has waterplane",
			type = "bool",
			value = gl.GetWaterRendering("hasWaterPlane"),
			description = "The WaterPlane is a single Quad beneath the map.\nIt should have the same color as the ocean floor to hide the map -> background boundary. Specifying waterPlaneColor in mapinfo.lua will turn this on.",
			onchange = function(option, value)
				Spring.SetWaterParams({ hasWaterPlane = value })
				Spring.SendCommands("water 4")
			end,
		},
		{
			id = "water_forcerendering",
			parent = "water_shorewaves",
			group = "dev",
			category = types.dev,
			name = "force rendering",
			type = "bool",
			value = gl.GetWaterRendering("forceRendering"),
			description = "Should the water be rendered even when minMapHeight>0.\nUse it to avoid the jumping of the outside-map water rendering (BumpWater: endlessOcean option) when combat explosions reach groundwater.",
			onchange = function(option, value)
				Spring.SetWaterParams({ forceRendering = value })
				Spring.SendCommands("water 4")
			end,
		},
		{
			id = "water_repeatx",
			parent = "water_shorewaves",
			group = "dev",
			category = types.dev,
			name = "repeat X",
			type = "slider",
			min = 0,
			max = 20,
			step = 1,
			value = gl.GetWaterRendering("repeatX"),
			description = "water 0 texture repeat horizontal",
			onchange = function(option, value)
				Spring.SetWaterParams({ repeatX = value })
				Spring.SendCommands("water 4")
			end,
		},
		{
			id = "water_repeaty",
			parent = "water_shorewaves",
			group = "dev",
			category = types.dev,
			name = "repeat Y",
			type = "slider",
			min = 0,
			max = 20,
			step = 1,
			value = gl.GetWaterRendering("repeatY"),
			description = "water 0 texture repeat vertical",
			onchange = function(option, value)
				Spring.SetWaterParams({ repeatY = value })
				Spring.SendCommands("water 4")
			end,
		},
		{
			id = "water_surfacealpha",
			parent = "water_shorewaves",
			group = "dev",
			category = types.dev,
			name = "surface alpha",
			type = "slider",
			min = 0,
			max = 1,
			step = 0.001,
			value = gl.GetWaterRendering("surfaceAlpha"),
			description = "",
			onchange = function(option, value)
				Spring.SetWaterParams({ surfaceAlpha = value })
				Spring.SendCommands("water 4")
			end,
		},
		-- gl.GetWaterRendering("windSpeed") seems to not exist
		--{ id = "water_windspeed", group = "dev", category = types.dev, name = widgetOptionColor .. "   windspeed", type = "slider", min = 0.0, max = 2.0, step = 0.01, value = gl.GetWaterRendering("windSpeed"), description = "The speed of bumpwater tiles moving",
		--  onload = function(option)
		--  end,
		--  onchange = function(option, value)
		--	  Spring.SetWaterParams({ windSpeed = value })
		--	  Spring.SendCommands("water 4")
		--  end,
		--},
		{
			id = "water_ambientfactor",
			parent = "water_shorewaves",
			group = "dev",
			category = types.dev,
			name = "ambient factor",
			type = "slider",
			min = 0,
			max = 2,
			step = 0.001,
			value = gl.GetWaterRendering("ambientFactor"),
			description = "How much ambient lighting the water surface gets (ideally very little)",
			onchange = function(option, value)
				Spring.SetWaterParams({ ambientFactor = value })
				Spring.SendCommands("water 4")
			end,
		},
		{
			id = "water_diffusefactor",
			parent = "water_shorewaves",
			group = "dev",
			category = types.dev,
			name = "diffuse factor",
			type = "slider",
			min = 0,
			max = 5,
			step = 0.001,
			value = gl.GetWaterRendering("diffuseFactor"),
			description = "How strong the diffuse lighting should be on the water",
			onchange = function(option, value)
				Spring.SetWaterParams({ diffuseFactor = value })
				Spring.SendCommands("water 4")
			end,
		},
		{
			id = "water_specularfactor",
			parent = "water_shorewaves",
			group = "dev",
			category = types.dev,
			name = "specular factor",
			type = "slider",
			min = 0,
			max = 5,
			step = 0.01,
			value = gl.GetWaterRendering("specularFactor"),
			description = "How much light should be reflected straight from the sun",
			onchange = function(option, value)
				Spring.SetWaterParams({ specularFactor = value })
				Spring.SendCommands("water 4")
			end,
		},
		{
			id = "water_specularpower",
			parent = "water_shorewaves",
			group = "dev",
			category = types.dev,
			name = "specular power",
			type = "slider",
			min = 0,
			max = 100,
			step = 0.1,
			value = gl.GetWaterRendering("specularPower"),
			description = "How polished the surface of the water is",
			onchange = function(option, value)
				Spring.SetWaterParams({ specularPower = value })
				Spring.SendCommands("water 4")
			end,
		},
		{
			id = "water_perlinstartfreq",
			parent = "water_shorewaves",
			group = "dev",
			category = types.dev,
			name = "perlin start freq",
			type = "slider",
			min = 10,
			max = 50,
			step = 1,
			value = gl.GetWaterRendering("perlinStartFreq"),
			description = "The initial frequency of the bump map repetition rate. Larger numbers mean more tiles",
			onchange = function(option, value)
				Spring.SetWaterParams({ perlinStartFreq = value })
				Spring.SendCommands("water 4")
			end,
		},
		{
			id = "water_perlinlacunarity",
			parent = "water_shorewaves",
			group = "dev",
			category = types.dev,
			name = "perlin lacunarity",
			type = "slider",
			min = 0.1,
			max = 4,
			step = 0.01,
			value = gl.GetWaterRendering("perlinLacunarity"),
			description = "How much smaller each additional repetition of the normal map should be. Larger numbers mean smaller",
			onchange = function(option, value)
				Spring.SetWaterParams({ perlinLacunarity = value })
				Spring.SendCommands("water 4")
			end,
		},
		{
			id = "water_perlinlamplitude",
			parent = "water_shorewaves",
			group = "dev",
			category = types.dev,
			name = "perlin amplitude",
			type = "slider",
			min = 0.1,
			max = 4,
			step = 0.01,
			value = gl.GetWaterRendering("perlinAmplitude"),
			description = "How strong each additional repetition of the normal map should be",
			onchange = function(option, value)
				Spring.SetWaterParams({ perlinAmplitude = value })
				Spring.SendCommands("water 4")
			end,
		},
		{
			id = "water_fresnelmin",
			parent = "water_shorewaves",
			group = "dev",
			category = types.dev,
			name = "fresnel min",
			type = "slider",
			min = 0,
			max = 2,
			step = 0.01,
			value = gl.GetWaterRendering("fresnelMin"),
			description = "Minimum reflection strength, e.g. the reflectivity of the water when looking straight down on it",
			onchange = function(option, value)
				Spring.SetWaterParams({ fresnelMin = value })
				Spring.SendCommands("water 4")
			end,
		},
		{
			id = "water_fresnelmax",
			parent = "water_shorewaves",
			group = "dev",
			category = types.dev,
			name = "fresnel max",
			type = "slider",
			min = 0,
			max = 2,
			step = 0.01,
			value = gl.GetWaterRendering("fresnelMax"),
			description = "Maximum reflection strength, the reflectivity of the water when looking parallel to the water plane",
			onchange = function(option, value)
				Spring.SetWaterParams({ fresnelMax = value })
				Spring.SendCommands("water 4")
			end,
		},
		{
			id = "water_fresnelpower",
			parent = "water_shorewaves",
			group = "dev",
			category = types.dev,
			name = "fresnel power",
			type = "slider",
			min = 0,
			max = 16,
			step = 0.1,
			value = gl.GetWaterRendering("fresnelPower"),
			description = "Determines how fast the reflection increases when going from straight down view to parallel.",
			onchange = function(option, value)
				Spring.SetWaterParams({ fresnelPower = value })
				Spring.SendCommands("water 4")
			end,
		},
		{
			id = "water_numtiles",
			parent = "water_shorewaves",
			group = "dev",
			category = types.dev,
			name = "num tiles",
			type = "slider",
			min = 1.0,
			max = 8,
			step = 1.0,
			value = gl.GetWaterRendering("numTiles"),
			description = "How many (squared) Tiles does the `normalTexture` have?\nSuch Tiles are used when DynamicWaves are enabled in BumpWater, the more the better.\nCheck the example php script to generate such tiled bumpmaps.",
			onchange = function(option, value)
				Spring.SetWaterParams({ numTiles = value })
				Spring.SendCommands("water 4")
			end,
		},
		{
			id = "water_blurbase",
			parent = "water_shorewaves",
			group = "dev",
			category = types.dev,
			name = "blur base",
			type = "slider",
			min = 0,
			max = 3,
			step = 0.01,
			value = gl.GetWaterRendering("blurBase"),
			description = "How much should the reflection be blurred",
			onchange = function(option, value)
				Spring.SetWaterParams({ blurBase = value })
				Spring.SendCommands("water 4")
			end,
		},
		{
			id = "water_blurexponent",
			parent = "water_shorewaves",
			group = "dev",
			category = types.dev,
			name = "blur exponent",
			type = "slider",
			min = 0,
			max = 3,
			step = 0.01,
			value = gl.GetWaterRendering("blurExponent"),
			description = "How much should the reflection be blurred",
			onchange = function(option, value)
				Spring.SetWaterParams({ blurExponent = value })
				Spring.SendCommands("water 4")
			end,
		},
		{
			id = "water_reflectiondistortion",
			parent = "water_shorewaves",
			group = "dev",
			category = types.dev,
			name = "reflection distortion",
			type = "slider",
			min = 0,
			max = 5,
			step = 0.01,
			value = gl.GetWaterRendering("reflectionDistortion"),
			description = "",
			onchange = function(option, value)
				Spring.SetWaterParams({ reflectionDistortion = value })
				Spring.SendCommands("water 4")
			end,
		},
		-- new water 4 params since engine 105BAR 582
		{
			id = "water_waveoffsetfactor",
			parent = "water_shorewaves",
			group = "dev",
			category = types.dev,
			name = "waveoffsetfactor",
			type = "slider",
			min = 0.0,
			max = 2.0,
			step = 0.01,
			value = gl.GetWaterRendering("waveOffsetFactor"),
			description = "Set this to 0.1 to make waves break shores not all at the same time",
			onchange = function(option, value)
				Spring.SetWaterParams({ waveOffsetFactor = value })
				Spring.SendCommands("water 4")
			end,
		},
		{
			id = "water_wavelength",
			parent = "water_shorewaves",
			group = "dev",
			category = types.dev,
			name = "waveLength",
			type = "slider",
			min = 0.0,
			max = 1.0,
			step = 0.01,
			value = gl.GetWaterRendering("waveLength"),
			description = "How long the waves are",
			onchange = function(option, value)
				Spring.SetWaterParams({ waveLength = value })
				Spring.SendCommands("water 4")
			end,
		},
		{
			id = "water_wavefoamdistortion",
			parent = "water_shorewaves",
			group = "dev",
			category = types.dev,
			name = "waveFoamDistortion",
			type = "slider",
			min = 0.0,
			max = 0.5,
			step = 0.01,
			value = gl.GetWaterRendering("waveFoamDistortion"),
			description = "How much the waters movement distorts the foam texture",
			onchange = function(option, value)
				Spring.SetWaterParams({ waveFoamDistortion = value })
				Spring.SendCommands("water 4")
			end,
		},
		{
			id = "water_wavefoamintensity",
			parent = "water_shorewaves",
			group = "dev",
			category = types.dev,
			name = "waveFoamIntensity",
			type = "slider",
			min = 0.0,
			max = 2.0,
			step = 0.01,
			value = gl.GetWaterRendering("waveFoamIntensity"),
			description = "How strong the foam texture is",
			onchange = function(option, value)
				Spring.SetWaterParams({ waveFoamIntensity = value })
				Spring.SendCommands("water 4")
			end,
		},
		{
			id = "water_causticsresolution",
			parent = "water_shorewaves",
			group = "dev",
			category = types.dev,
			name = "causticsResolution",
			type = "slider",
			min = 10.0,
			max = 300.0,
			step = 1.0,
			value = gl.GetWaterRendering("causticsResolution"),
			description = "The tiling rate of the caustics texture",
			onchange = function(option, value)
				Spring.SetWaterParams({ causticsResolution = value })
				Spring.SendCommands("water 4")
			end,
		},
		{
			id = "water_causticsstrength",
			parent = "water_shorewaves",
			group = "dev",
			category = types.dev,
			name = "causticsStrength",
			type = "slider",
			min = 0.0,
			max = 0.5,
			step = 0.01,
			value = gl.GetWaterRendering("causticsStrength"),
			description = "How intense the caustics effects are",
			onchange = function(option, value)
				Spring.SetWaterParams({ causticsStrength = value })
				Spring.SendCommands("water 4")
			end,
		},
		-- TODO add SetWaterParams:
		--absorb = {number r, number g, number b},
		--baseColor = {number r, number g, number b},
		--minColor = {number r, number g, number b},
		--surfaceColor = {number r, number g, number b},
		--diffuseColor = {number r, number g, number b},
		--specularColor = {number r, number g, number b},
		--planeColor = {number r, number g, number b},
	}
end
