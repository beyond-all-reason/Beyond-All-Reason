-- The graphics tab's settings. model.lua says what a row can hold.
return function(model)
	local types = model.types
	local state = model.state
	local upkeep = model.upkeep
	local hardware = model.hardware
	local getOption = model.getOption
	local applyOptionValue = model.applyOptionValue
	local saveOptionValue = model.saveOptionValue
	local loadWidgetData = model.loadWidgetData
	local GetWidgetToggleValue = model.GetWidgetToggleValue

	local screenModes = WG.screenMode and WG.screenMode.GetScreenModes() or {}
	local displays = WG.screenMode and WG.screenMode.GetDisplays() or {}

	local currentDisplay = 1
	local v_sx, v_sy, v_px, v_py = Spring.GetViewGeometry()
	local displayNames = {}
	for index, display in ipairs(displays) do
		if display.width > 0 then
			displayNames[index] = index
				.. ":  "
				.. display.name
				.. " "
				.. display.width
				.. " × "
				.. display.height
				.. "  ("
				.. display.hz
				.. "hz)"
			if
				v_px >= display.x
				and v_px < display.x + display.width
				and v_py >= display.y
				and v_py < display.y + display.height
			then
				currentDisplay = index
			end
		elseif model.devMode or model.devUI then -- advSettings
			displayNames[index] = display.name
		end
	end
	local selectedDisplay = currentDisplay

	local resolutionNames = {}
	local screenmodeOffset = 0
	for _, screenMode in ipairs(screenModes) do
		if screenMode.display == currentDisplay then
			resolutionNames[#resolutionNames + 1] = screenMode.name
		elseif #resolutionNames == 0 then
			screenmodeOffset = screenmodeOffset + 1
		end
	end

	-- The entry the window is in now, if one is: fullscreen or borderless (the switcher's mode types 1 and
	-- 2), or the windowed mode of its size, borders included as the switcher sets it.
	local function currentResolution()
		local fullscreen = Spring.GetConfigInt("Fullscreen", 0) == 1
		local borderless = Spring.GetConfigInt("WindowBorderless", 0) == 1
		local w, h, _, _, top, left, bottom, right = Spring.GetWindowGeometry()
		for i = 1, #resolutionNames do
			local mode = screenModes[i + screenmodeOffset]
			if not mode then
				break
			elseif fullscreen and mode.type == (borderless and 2 or 1) then
				return i
			elseif
				not fullscreen
				and not borderless
				and mode.type == 3
				and mode.width == w + left + right
				and mode.height == h + top + bottom
			then
				return i
			end
		end
	end

	-- only allow dualscreen-mode on single displays when super ultrawide screen or Multi Display option shows
	local dualScreen = not (
		(#displayNames <= 1 and v_sx / v_sy < 2.5) or (#displayNames > 1 and #displayNames == Spring.GetNumDisplays())
	)
	if not dualScreen and Spring.GetConfigInt("DualScreenMode", 0) ~= 0 then
		Spring.SetConfigInt("DualScreenMode", 0)
	end

	-- restric gfx preset options for potato gpu, lowest preset is added and high preset is removed
	-- custom has to stay last: changing a preset's setting by hand selects the last entry
	local presetKeys
	if model.devMode or model.devUI then
		-- dev mode: show all presets so every quality level can be tested
		presetKeys = { "lowest", "low", "medium", "high", "ultra", "custom" }
	elseif hardware.isPotatoGpu then
		presetKeys = { "lowest", "low", "medium", "custom" }
	else
		presetKeys = { "low", "medium", "high", "ultra", "custom" }
	end
	local presetNames = {}
	for i, key in ipairs(presetKeys) do
		presetNames[i] = BAR.I18N("ui.settings.option.select_" .. key)
	end

	return {
		--GFX
		{
			id = "preset",
			group = "gfx",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.preset"),
			type = "select",
			options = presetNames,
			onload = function(option)
				local preset = Spring.GetConfigString("graphicsPreset", "custom")
				option.value = table.getKeyOf(presetKeys, preset) or #presetKeys
			end,
			onchange = function(option, value)
				local configSetting = presetKeys[value]
				Spring.SetConfigString("graphicsPreset", configSetting)
				if configSetting == "custom" then
					return
				end

				Spring.Echo("Loading preset:   " .. option.options[value])
				model.manualChange = false
				for optionID, value in pairs(model.presets[configSetting]) do
					local presetOption = getOption(optionID)
					if presetOption ~= nil then
						applyOptionValue(presetOption, value, true)
					end
				end

				model.onListChanged()
				model.manualChange = true
			end,
		},
		{
			id = "label_gfx_screen",
			group = "gfx",
			name = BAR.I18N("ui.settings.option.label_screen"),
			category = types.basic,
		},
		{
			id = "display",
			group = "gfx",
			category = types.basic,
			available = #displayNames > 1, -- without it, resolution moves up a level
			name = BAR.I18N("ui.settings.option.display"),
			type = "select",
			options = displayNames,
			value = currentDisplay,
			onchange = function(option, value)
				--currentDisplay = value
				selectedDisplay = value
				Spring.SetConfigInt("SelectedDisplay", value)
				resolutionNames = {}
				screenmodeOffset = 0
				for _, screenMode in ipairs(screenModes) do
					if screenMode.display == selectedDisplay then
						resolutionNames[#resolutionNames + 1] = screenMode.name
					elseif #resolutionNames == 0 then
						screenmodeOffset = screenmodeOffset + 1
					end
				end
				getOption("resolution").options = resolutionNames
				if selectedDisplay == currentDisplay then
					getOption("resolution").value = Spring.GetConfigInt("SelectedScreenMode", 1)
				else
					getOption("resolution").value = 0
				end
				model.forceUpdate = true
			end,
		},
		{
			id = "resolution",
			parent = "display",
			group = "gfx",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.resolution"),
			type = "select",
			options = resolutionNames,
			value = Spring.GetConfigInt("SelectedScreenMode", 1),
			description = BAR.I18N("ui.settings.option.resolution_descr"),
			-- also run while the window is open, as the game window can be resized meanwhile
			onload = function(option)
				-- FIXME: disabled for now due to "Now whenever i do fullscreen or borderless the game will go to monitor 2 regardless of the chosen option. (I want the game on monitor 1)."
				--if Spring.GetConfigInt('SelectedScreenMode', -1) >= 1 then		-- chobby sets SelectedScreenMode to -1 when it changes game window mode
				--	WG['screenMode'].SetScreenMode(Spring.GetConfigInt('SelectedScreenMode', 1))
				--end

				-- the mode the window is in, not the last one picked
				if selectedDisplay ~= currentDisplay then
					return -- another display's modes are listed
				end
				local current = currentResolution()
				option.options = resolutionNames
				if current then
					option.value = current
				else
					local w, h = Spring.GetWindowGeometry()
					local names = {}
					for i, name in ipairs(resolutionNames) do
						names[i] = name
					end
					names[#names + 1] = BAR.I18N("ui.resolutionswitcher.window") .. " " .. w .. " × " .. h
					option.options = names
					option.value = #names
				end
			end,
			onchange = function(option, value)
				if value > #resolutionNames then
					return -- the size the window has now
				end
				Spring.SetConfigInt("SelectedScreenMode", value)

				if WG.screenMode then
					WG.screenMode.SetScreenMode(value + screenmodeOffset)
					currentDisplay = 1
					local v_sx, v_sy, v_px, v_py = Spring.GetViewGeometry()
					for index, display in ipairs(displays) do
						if
							v_px >= display.x
							and v_px < display.x + display.width
							and v_py >= display.y
							and v_py < display.y + display.height
						then
							currentDisplay = index
						end
					end
				end
			end,
		},
		{
			id = "dualmode_enabled",
			group = "gfx",
			category = types.dev,
			available = dualScreen,
			name = BAR.I18N("ui.settings.option.dualmode"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.dualmode_enabled_descr"),
			configInt = "DualScreenMode",
		},
		{
			id = "dualmode_left",
			parent = "dualmode_enabled",
			group = "gfx",
			category = types.dev,
			available = dualScreen,
			name = BAR.I18N("ui.settings.option.dualmode_left"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.dualmode_left_descr"),
			configInt = "DualScreenMiniMapOnLeft",
		},
		{
			id = "dualmode_minimap_aspectratio",
			parent = "dualmode_enabled",
			group = "gfx",
			category = types.dev,
			available = dualScreen,
			name = BAR.I18N("ui.settings.option.dualmode_minimap_aspectratio"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.dualmode_minimap_aspectratio_descr"),
			configInt = "DualScreenMiniMapAspectRatio",
		},
		{
			id = "vsync",
			group = "gfx",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.vsync"),
			type = "select",
			options = {
				BAR.I18N("ui.settings.option.select_off"),
				BAR.I18N("ui.settings.option.select_enabled"),
				BAR.I18N("ui.settings.option.select_adaptive"),
			},
			value = 2,
			description = BAR.I18N("ui.settings.option.vsync_descr"),
			onload = function(option)
				local vsync = Spring.GetConfigInt("VSyncGame", -1)
				if vsync > 0 then
					option.value = 2
				elseif vsync < 0 then
					option.value = 3
				else
					option.value = 1
				end
			end,
			onchange = function(option, value)
				-- VSyncGame is the mode (1 on, -1 adaptive, 0 off), times VSyncFraction here and in the lobby
				local mode = 0
				if value == 2 then
					mode = 1
				elseif value == 3 then
					mode = -1
				end
				Spring.SetConfigInt("VSync", mode * Spring.GetConfigInt("VSyncFraction", 1))
				Spring.SetConfigInt("VSyncGame", mode) -- stored here as assurance cause lobby/game also changes vsync when idle and lobby could think game has set vsync 4 after a hard crash
			end,
		},
		{
			id = "vsync_fraction",
			parent = "vsync",
			group = "gfx",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.vsync_fraction"),
			min = 1,
			max = 4,
			step = 1,
			type = "slider",
			value = Spring.GetConfigInt("VSyncFraction", 1),
			description = BAR.I18N("ui.settings.option.vsync_fraction_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("VSyncFraction", value)
				local vsync = Spring.GetConfigInt("VSyncGame", -1)
				if vsync ~= 0 then
					Spring.SetConfigInt("VSync", vsync * value)
				end
			end,
		},

		{
			id = "limitoffscreenfps",
			group = "gfx",
			category = types.advanced,
			widget = "Limit idle FPS",
			name = BAR.I18N("ui.settings.option.limitoffscreenfps"),
			type = "bool",
			value = GetWidgetToggleValue("Limit idle FPS"),
			description = BAR.I18N("ui.settings.option.limitoffscreenfps_descr"),
		},
		{
			id = "limitidlefps",
			parent = "limitoffscreenfps",
			group = "gfx",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.limitidlefps"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.limitidlefps_descr"),
			configInt = "LimitIdleFps",
		},

		{
			id = "msaa",
			group = "gfx",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.msaa"),
			type = "select",
			options = { BAR.I18N("ui.settings.option.select_off"), "x2", "x4", "x8" },
			restart = true,
			value = tonumber(Spring.GetConfigInt("MSAALevel", 0) or 0),
			description = BAR.I18N("ui.settings.option.msaa_descr"),
			onload = function(option)
				local msaa = tonumber(Spring.GetConfigInt("MSAALevel", 0) or 0)
				if msaa <= 0 then
					option.value = 1
				else
					for k, v in ipairs(option.options) do
						if v == "x" .. msaa then
							option.value = k
							break
						end
					end
				end
			end,
			onchange = function(option, value)
				if value == 1 then
					Spring.SetConfigInt("MSAA", 0)
					Spring.SetConfigInt("MSAALevel", -1) -- setting 0 will reset it to default x4 :(
				else
					Spring.SetConfigInt("MSAA", 1)
					Spring.SetConfigInt("MSAALevel", tonumber(string.sub(option.options[value], 2)))
				end
			end,
		},

		{
			id = "supersampling",
			parent = "msaa",
			group = "gfx",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.supersampling"),
			type = "bool",
			restart = false,
			value = (Spring.GetConfigFloat("MinSampleShadingRate", 0.0) == 1.0),
			description = BAR.I18N("ui.settings.option.supersampling_descr"),
			onchange = function(option, value)
				Spring.SetConfigFloat("MinSampleShadingRate", (value and 1.0 or 0.0))
			end,
		},

		{
			id = "cas_sharpness",
			group = "gfx",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.cas_sharpness"),
			min = 0.5,
			max = 1.1,
			step = 0.01,
			type = "slider",
			value = 1.0,
			description = BAR.I18N("ui.settings.option.cas_sharpness_descr"),
			onload = function(option)
				loadWidgetData("Contrast Adaptive Sharpen", "cas_sharpness", { "SHARPNESS" })
			end,
			onchange = function(option, value)
				if not GetWidgetToggleValue("Contrast Adaptive Sharpen") then
					widgetHandler:EnableWidget("Contrast Adaptive Sharpen")
				end
				saveOptionValue("Contrast Adaptive Sharpen", "cas", "setSharpness", { "SHARPNESS" }, option.value)
			end,
		},

		{
			id = "sepiatone",
			group = "gfx",
			category = types.advanced,
			widget = "Sepia Tone",
			name = BAR.I18N("ui.settings.option.sepiatone"),
			type = "bool",
			value = GetWidgetToggleValue("Sepia Tone"),
		},
		{
			id = "sepiatone_gamma",
			parent = "sepiatone",
			group = "gfx",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.sepiatone_gamma"),
			min = 0.1,
			max = 0.9,
			step = 0.02,
			type = "slider",
			value = 0.5,
			widgetConfig = { "Sepia Tone", "gamma", api = "sepia", set = "setGamma" },
		},
		{
			id = "sepiatone_saturation",
			parent = "sepiatone",
			group = "gfx",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.sepiatone_saturation"),
			min = 0,
			max = 1,
			step = 0.02,
			type = "slider",
			value = 0.5,
			widgetConfig = { "Sepia Tone", "saturation", api = "sepia", set = "setSaturation" },
		},
		{
			id = "sepiatone_contrast",
			parent = "sepiatone",
			group = "gfx",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.sepiatone_contrast"),
			min = 0.1,
			max = 0.9,
			step = 0.02,
			type = "slider",
			value = 0.5,
			widgetConfig = { "Sepia Tone", "contrast", api = "sepia", set = "setContrast" },
		},
		{
			id = "sepiatone_sepia",
			parent = "sepiatone",
			group = "gfx",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.sepiatone_sepia"),
			min = 0,
			max = 0.5,
			step = 0.02,
			type = "slider",
			value = 0.5,
			description = BAR.I18N("ui.settings.option.sepiatone_sepia_descr"),
			widgetConfig = { "Sepia Tone", "sepia", api = "sepia", set = "setSepia" },
		},
		{
			id = "sepiatone_shadeui",
			parent = "sepiatone",
			group = "gfx",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.sepiatone_shadeui"),
			type = "bool",
			value = false,
			widgetConfig = { "Sepia Tone", "shadeUI", api = "sepia", set = "setShadeUI" },
		},

		{
			id = "label_gfx_lighting",
			group = "gfx",
			name = BAR.I18N("ui.settings.option.label_lighting"),
			category = types.basic,
		},

		{
			id = "advmapshading",
			group = "gfx",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.advmapshading"),
			type = "bool",
			value = (Spring.GetConfigInt("AdvMapShading", 1) == 1),
			description = BAR.I18N("ui.settings.option.advmapshading_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("AdvMapShading", (value and 1 or 0))
				Spring.SendCommands("advmapshading " .. (value and "1" or "0"))
			end,
		},

		{
			id = "cusgl4",
			group = "gfx",
			name = BAR.I18N("ui.settings.option.cus"),
			category = types.basic,
			type = "bool",
			value = (Spring.GetConfigInt("cus2", 1) == 1),
			description = BAR.I18N("ui.settings.option.cus_descr"),
			onchange = function(option, value)
				if value == 0.5 then
					Spring.SendCommands("luarules disablecusgl4")
				else
					Spring.SetConfigInt("cus2", (value and 1 or 0))
					Spring.SendCommands("luarules " .. (value and "reloadcusgl4" or "disablecusgl4"))
				end
			end,
		},

		{
			id = "shadowslider",
			group = "gfx",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.shadowslider"),
			type = "select",
			options = {
				BAR.I18N("ui.settings.option.select_off"),
				BAR.I18N("ui.settings.option.select_lowest"),
				BAR.I18N("ui.settings.option.select_low"),
				BAR.I18N("ui.settings.option.select_medium"),
				BAR.I18N("ui.settings.option.select_high"),
				BAR.I18N("ui.settings.option.select_ultra"),
			},
			value = Spring.GetConfigInt("ShadowQuality", 3) + 1,
			description = BAR.I18N("ui.settings.option.shadowslider_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("ShadowQuality", value - 1)
				upkeep.adjustShadowQuality()
			end,
		},

		{
			id = "shadows_opacity",
			parent = "shadowslider",
			group = "gfx",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.shadows_opacity"),
			type = "slider",
			min = 0.3,
			max = 1,
			step = 0.01,
			value = gl.GetSun("shadowDensity"),
			description = "",
			onchange = function(option, value)
				Spring.SetSunLighting({ groundShadowDensity = value, modelShadowDensity = value })
			end,
		},

		{
			id = "ssao",
			group = "gfx",
			category = types.basic,
			widget = "SSAO",
			name = BAR.I18N("ui.settings.option.ssao"),
			type = "bool",
			value = GetWidgetToggleValue("SSAO"),
			description = BAR.I18N("ui.settings.option.ssao_descr"),
		},
		{
			id = "ssao_strength",
			parent = "ssao",
			group = "gfx",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.ssao_strength"),
			type = "slider",
			min = 5,
			max = 15,
			step = 1,
			value = 10,
			description = "",
			widgetConfig = { "SSAO", "strength", api = "ssao", set = "setStrength" },
		},
		{
			id = "ssao_quality",
			parent = "ssao",
			group = "gfx",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.ssao_quality"),
			type = "select",
			options = {
				BAR.I18N("ui.settings.option.select_low"),
				BAR.I18N("ui.settings.option.select_medium"),
				BAR.I18N("ui.settings.option.select_high"),
			},
			value = (WG.ssao ~= nil and WG.ssao.getPreset() or 2),
			description = BAR.I18N("ui.settings.option.ssao_quality_descr"),
			onload = function(option)
				if widgetHandler.configData.SSAO ~= nil and widgetHandler.configData.SSAO.preset ~= nil then
					option.value = widgetHandler.configData.SSAO.preset
				end
			end,
			onchange = function(option, value)
				saveOptionValue("SSAO", "ssao", "setPreset", { "preset" }, value)
			end,
		},

		{
			id = "bloomdeferred",
			group = "gfx",
			category = types.basic,
			widget = "Bloom Shader Deferred",
			name = BAR.I18N("ui.settings.option.bloomdeferred"),
			type = "bool",
			value = GetWidgetToggleValue("Bloom Shader Deferred"),
			description = BAR.I18N("ui.settings.option.bloomdeferred_descr"),
		},
		{
			id = "bloomdeferredbrightness",
			parent = "bloomdeferred",
			group = "gfx",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.bloomdeferredbrightness"),
			type = "slider",
			min = 0.5,
			max = 2.0,
			step = 0.05,
			value = 1.0,
			description = "",
			widgetConfig = { "Bloom Shader Deferred", "glowAmplifier", api = "bloomdeferred", set = "setBrightness" },
		},
		{
			id = "bloomdeferred_quality",
			parent = "bloomdeferred",
			group = "gfx",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.bloomdeferred_quality"),
			type = "select",
			options = {
				BAR.I18N("ui.settings.option.select_low"),
				BAR.I18N("ui.settings.option.select_medium"),
				BAR.I18N("ui.settings.option.select_high"),
			},
			value = (WG.bloomdeferred ~= nil and WG.bloomdeferred.getPreset() or 2),
			description = BAR.I18N("ui.settings.option.bloomdeferred_quality_descr"),
			onload = function(option)
				if
					widgetHandler.configData["Bloom Shader Deferred"] ~= nil
					and widgetHandler.configData["Bloom Shader Deferred"].preset ~= nil
				then
					option.value = widgetHandler.configData["Bloom Shader Deferred"].preset
				end
			end,
			onchange = function(option, value)
				saveOptionValue("Bloom Shader Deferred", "bloomdeferred", "setPreset", { "preset" }, value)
			end,
		},

		{
			id = "lighteffects",
			group = "gfx",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.lighteffects"),
			type = "bool",
			value = GetWidgetToggleValue("Deferred rendering GL4"),
			description = BAR.I18N("ui.settings.option.lighteffects_descr"),
			onchange = function(option, value)
				if value then
					widgetHandler:EnableWidget("Deferred rendering GL4")
				else
					widgetHandler:DisableWidget("Deferred rendering GL4")
				end
			end,
		},
		{
			id = "lighteffects_headlights",
			parent = "lighteffects",
			group = "gfx",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.lighteffects_headlights"),
			type = "bool",
			value = Spring.GetConfigInt("headlights", 1) == 1,
			description = BAR.I18N("ui.settings.option.lighteffects_headlights_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("headlights", value and 1 or 0)
				if widgetHandler.orderList["Deferred rendering GL4"] ~= nil then
					widgetHandler:DisableWidget("Deferred rendering GL4")
					widgetHandler:EnableWidget("Deferred rendering GL4")
				end
			end,
		},
		{
			id = "lighteffects_buildlights",
			parent = "lighteffects",
			group = "gfx",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.lighteffects_buildlights"),
			type = "bool",
			value = Spring.GetConfigInt("buildlights", 1) == 1,
			description = BAR.I18N("ui.settings.option.lighteffects_buildlights_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("buildlights", value and 1 or 0)
				if widgetHandler.orderList["Deferred rendering GL4"] ~= nil then
					widgetHandler:DisableWidget("Deferred rendering GL4")
					widgetHandler:EnableWidget("Deferred rendering GL4")
				end
			end,
		},
		{
			id = "lighteffects_brightness",
			parent = "lighteffects",
			group = "gfx",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.lighteffects_brightness"),
			min = 0.4,
			max = 1.5,
			step = 0.05,
			type = "slider",
			value = 1,
			description = BAR.I18N("ui.settings.option.lighteffects_brightness_descr"),
			widgetConfig = {
				"Deferred rendering GL4",
				"intensityMultiplier",
				api = "lightsgl4",
				set = "IntensityMultiplier",
			},
		},
		{
			id = "lighteffects_radius",
			parent = "lighteffects",
			group = "gfx",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.lighteffects_radius"),
			min = 0.4,
			max = 1.2,
			step = 0.05,
			type = "slider",
			value = 1,
			description = BAR.I18N("ui.settings.option.lighteffects_radius_descr"),
			widgetConfig = { "Deferred rendering GL4", "radiusMultiplier", api = "lightsgl4", set = "RadiusMultiplier" },
		},

		{
			id = "lighteffects_screenspaceshadows",
			parent = "lighteffects",
			group = "gfx",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.lighteffects_screenspaceshadows"),
			min = 0,
			max = 4,
			step = 1,
			type = "slider",
			value = 2,
			description = BAR.I18N("ui.settings.option.lighteffects_screenspaceshadows_descr"),
			widgetConfig = {
				"Deferred rendering GL4",
				"screenSpaceShadows",
				api = "lightsgl4",
				set = "ScreenSpaceShadows",
			},
		},

		{
			id = "lighteffects_nanoparticlelights",
			parent = "lighteffects",
			group = "gfx",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.nanoparticlelights"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.nanoparticlelights_descr"),
			configInt = "NanoParticlesUpdateLuaUI",
		},

		{
			id = "distortioneffects",
			group = "gfx",
			category = types.basic,
			widget = "Distortion GL4",
			name = BAR.I18N("ui.settings.option.distortioneffects"),
			type = "bool",
			value = GetWidgetToggleValue("Distortion GL4"),
			description = BAR.I18N("ui.settings.option.distortioneffects_descr"),
		},

		{
			id = "darkenmap",
			group = "gfx",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.darkenmap"),
			min = 0,
			max = 0.33,
			step = 0.01,
			type = "slider",
			value = 0,
			description = BAR.I18N("ui.settings.option.darkenmap_descr"),
			widgetConfig = { "Darken map", "darknessvalue", api = "darkenmap", set = "setMapDarkness" },
		},

		{
			id = "label_gfx_environment",
			group = "gfx",
			name = BAR.I18N("ui.settings.option.label_environment"),
			category = types.basic,
		},

		{
			id = "featuredrawdist",
			group = "gfx",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.featuredrawdist"),
			type = "slider",
			min = 2500,
			max = 40000,
			step = 500,
			value = tonumber(Spring.GetConfigInt("FeatureDrawDistance", 10000)),
			description = BAR.I18N("ui.settings.option.featuredrawdist_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("FeatureFadeDistance", math.floor(value * 0.8))
				Spring.SetConfigInt("FeatureDrawDistance", value)
			end,
		},

		{
			id = "losopacity",
			group = "gfx",
			category = types.advanced,
			prefix = BAR.I18N("ui.settings.option.lineofsight"),
			name = BAR.I18N("ui.settings.option.losopacity"),
			type = "slider",
			min = 0.01,
			max = 1,
			step = 0.01,
			value = 0.66,
			description = "",
			widgetConfig = { "LOS colors", "opacity", api = "los", get = "getOpacity", set = "setOpacity" },
		},

		{
			id = "fogdiaglines",
			group = "gfx",
			category = types.advanced,
			prefix = BAR.I18N("ui.settings.option.lineofsight"),
			name = BAR.I18N("ui.settings.option.fogdiaglines"),
			type = "slider",
			min = 0,
			max = 1,
			step = 0.01,
			value = 0.30,
			description = "",
			widgetConfig = {
				"Fog Diagonal Lines GL4",
				"strength",
				api = "fogdiaglines",
				get = "getStrength",
				set = "setStrength",
			},
		},

		{
			id = "fogdiaglines_blur",
			group = "gfx",
			category = types.advanced,
			prefix = BAR.I18N("ui.settings.option.lineofsight"),
			name = BAR.I18N("ui.settings.option.fogdiaglines_blur"),
			type = "slider",
			min = 0,
			max = 1,
			step = 0.01,
			value = 0.187,
			description = "",
			widgetConfig = {
				"Fog Diagonal Lines GL4",
				"blurriness",
				api = "fogdiaglines",
				get = "getBlurriness",
				set = "setBlurriness",
			},
		},

		{
			id = "dominion_height_opacity",
			group = "gfx",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.dominion_height_opacity"),
			type = "slider",
			min = 0.5,
			max = 2.0,
			step = 0.05,
			value = 1.0,
			description = BAR.I18N("ui.settings.option.dominion_height_opacity_descr"),
			configFloat = "dominion_height_opacity",
		},

		{
			id = "water",
			group = "gfx",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.water"),
			type = "select",
			options = { BAR.I18N("ui.settings.option.select_low"), BAR.I18N("ui.settings.option.select_high") },
			value = state.desiredWaterValue == 4 and 2 or 1,
			onchange = function(option, value)
				state.desiredWaterValue = value > 1 and 4 or 0
				if state.waterDetected then
					if state.desiredWaterValue > 0 then
						state.desiredWaterValue = 4
					end
					Spring.SendCommands("water " .. state.desiredWaterValue)
					Spring.SetConfigInt("water", 4)
				end
			end,
		},

		{
			id = "mapedgeextension",
			group = "gfx",
			category = types.advanced,
			widget = "Map Edge Extension",
			name = BAR.I18N("ui.settings.option.mapedgeextension"),
			type = "bool",
			value = GetWidgetToggleValue("Map Edge Extension"),
			description = BAR.I18N("ui.settings.option.mapedgeextension_descr"),
		},

		{
			id = "mapedgeextension_brightness",
			parent = "mapedgeextension",
			group = "gfx",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.mapedgeextension_brightness"),
			min = 0.2,
			max = 1,
			step = 0.01,
			type = "slider",
			value = 0.3,
			description = "",
			widgetConfig = { "Map Edge Extension", "brightness", api = "mapedgeextension", set = "setBrightness" },
		},
		{
			id = "mapedgeextension_curvature",
			parent = "mapedgeextension",
			category = types.dev,
			group = "gfx",
			name = BAR.I18N("ui.settings.option.mapedgeextension_curvature"),
			type = "bool",
			value = true,
			description = BAR.I18N("ui.settings.option.mapedgeextension_curvature_descr"),
			widgetConfig = { "Map Edge Extension", "curvature", api = "mapedgeextension", set = "setCurvature" },
		},

		{
			id = "decalsgl4",
			group = "gfx",
			category = types.basic,
			widget = "Decals GL4",
			name = BAR.I18N("ui.settings.option.decalsgl4"),
			type = "bool",
			value = GetWidgetToggleValue("Decals GL4"),
		},
		{
			id = "decalsgl4_lifetime",
			parent = "decalsgl4",
			group = "gfx",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.decalsgl4_lifetime"),
			min = 0.5,
			max = 8,
			step = 0.1,
			type = "slider",
			value = 1,
			description = BAR.I18N("ui.settings.option.decalsgl4_lifetime_descr"),
			widgetConfig = { "Decals GL4", "lifeTimeMult", api = "decalsgl4", set = "SetLifeTimeMult" },
		},
		{
			id = "decals",
			group = "gfx",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.decals"),
			type = "bool",
			value = Spring.GetConfigInt("GroundDecals", 1) > 0,
			description = BAR.I18N("ui.settings.option.decals_descr"),
			onchange = function(option, value)
				-- the engine draws ground decals or not, it has no levels
				Spring.SetConfigInt("GroundDecals", value and 1 or 0)
				Spring.SendCommands("GroundDecals " .. (value and 1 or 0))
			end,
		},

		{
			id = "grass",
			group = "gfx",
			category = types.basic,
			widget = "Map Grass GL4",
			name = BAR.I18N("ui.settings.option.grass"),
			type = "bool",
			value = GetWidgetToggleValue("Map Grass GL4"),
			description = BAR.I18N("ui.settings.option.grass_desc"),
		},
		{
			id = "grassdistance",
			parent = "grass",
			group = "gfx",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.grassdistance"),
			type = "slider",
			min = 0.3,
			max = 1,
			step = 0.01,
			value = 1,
			description = BAR.I18N("ui.settings.option.grassdistance_desc"),
			widgetConfig = { "Map Grass GL4", "distanceMult", api = "grassgl4", set = "setDistanceMult" },
		},

		{
			id = "treewind",
			group = "gfx",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.treewind"),
			type = "bool",
			value = tonumber(Spring.GetConfigInt("TreeWind", 1) or 1) == 1,
			description = BAR.I18N("ui.settings.option.treewind_descr"),
			onchange = function(option, value)
				Spring.SendCommands("luarules treewind " .. (value and 1 or 0))
				Spring.SetConfigInt("TreeWind", (value and 1 or 0))
			end,
		},

		{
			id = "snow",
			group = "gfx",
			category = types.basic,
			widget = "Snow",
			name = BAR.I18N("ui.settings.option.snow"),
			type = "bool",
			value = GetWidgetToggleValue("Snow"),
			description = BAR.I18N("ui.settings.option.snow_descr"),
		},
		{
			id = "snowmap",
			parent = "snow",
			group = "gfx",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.snowmap"),
			type = "bool",
			value = true,
			description = BAR.I18N("ui.settings.option.snowmap_descr"),
			onload = function(option)
				loadWidgetData("Snow", "snowmap", { "snowMaps", Game.mapName:lower() })
			end,
			onchange = function(option, value)
				saveOptionValue("Snow", "snow", "setSnowMap", { "snowMaps", Game.mapName:lower() }, value)
			end,
		},
		{
			id = "snowautoreduce",
			parent = "snow",
			group = "gfx",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.snowautoreduce"),
			type = "bool",
			value = true,
			description = BAR.I18N("ui.settings.option.snowautoreduce_descr"),
			widgetConfig = { "Snow", "autoReduce", api = "snow", set = "setAutoReduce" },
		},
		{
			id = "snowamount",
			parent = "snow",
			group = "gfx",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.snowamount"),
			type = "slider",
			min = 0.2,
			max = 3,
			step = 0.2,
			value = 1,
			description = BAR.I18N("ui.settings.option.snowamount_descr"),
			widgetConfig = { "Snow", "customParticleMultiplier", api = "snow", set = "setMultiplier" },
		},

		{
			id = "clouds",
			group = "gfx",
			category = types.advanced,
			widget = "Volumetric Clouds",
			name = BAR.I18N("ui.settings.option.clouds"),
			type = "bool",
			value = GetWidgetToggleValue("Volumetric Clouds"),
			description = "",
		},
		{
			id = "clouds_opacity",
			parent = "clouds",
			group = "gfx",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.clouds_opacity"),
			type = "slider",
			min = 0.2,
			max = 1.4,
			step = 0.05,
			value = 1,
			description = "",
			widgetConfig = { "Volumetric Clouds", "opacityMult", api = "clouds", set = "setOpacity" },
		},
		{
			id = "fogmult",
			group = "gfx",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.fog"),
			type = "slider",
			min = 0,
			max = 1,
			step = 0.01,
			value = Spring.GetConfigFloat("FogMult", 1),
			description = BAR.I18N("ui.settings.option.fogmult_descr"),
			onload = function(option)
				option.onchange(option, option.value)
			end,
			onchange = function(option, value)
				Spring.SetConfigFloat("FogMult", value)
				value = 1 / value -- inverse
				local newFogStart = math.min(9, (state.defaultMapFog.fogStart * ((value + 4) * 0.2)))
				local newFogEnd = math.min(9, state.defaultMapFog.fogEnd * ((value + 1) * 0.5))
				if newFogStart >= newFogEnd then
					newFogStart = newFogEnd - 0.01
				end
				Spring.SetAtmosphere({ fogStart = newFogStart, fogEnd = newFogEnd })
			end,
		},

		{
			id = "label_gfx_effects",
			group = "gfx",
			name = BAR.I18N("ui.settings.option.label_effects"),
			category = types.basic,
		},

		{
			id = "particles",
			group = "gfx",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.particles"),
			type = "slider",
			min = 10000,
			max = 40000,
			step = 1000,
			value = tonumber(Spring.GetConfigInt("MaxParticles", 1) or 15000),
			description = BAR.I18N("ui.settings.option.particles_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("MaxParticles", value)
				-- Keep the engine nano-spray budget in sync when the gadget is
				-- handing particles back to the engine (NanoParticleMode 0).
				if Spring.GetConfigInt("NanoParticleMode", 1) == 0 then
					Spring.SetConfigInt("MaxNanoParticles", math.floor(value * 0.34))
					if Spring.GetConfigInt("NanoParticleMode", 1) == 0 then
						Spring.SetConfigInt(
							"MaxNanoParticles",
							math.floor(Spring.GetConfigInt("MaxParticles", 15000) * 0.34)
						)
					else
						Spring.SetConfigInt("MaxNanoParticles", 0)
					end
				end
			end,
		},

		{
			id = "dof",
			group = "gfx",
			category = types.advanced,
			widget = "Depth of Field",
			name = BAR.I18N("ui.settings.option.dof"),
			type = "bool",
			value = GetWidgetToggleValue("Depth of Field"),
			description = BAR.I18N("ui.settings.option.dof_descr"),
		},
		{
			id = "dof_autofocus",
			parent = "dof",
			group = "gfx",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.dof_autofocus"),
			type = "bool",
			value = true,
			description = BAR.I18N("ui.settings.option.dof_autofocus_descr"),
			widgetConfig = { "Depth of Field", "autofocus", api = "dof", set = "setAutofocus" },
		},
		{
			id = "dof_fstop",
			parent = "dof",
			group = "gfx",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.dof_fstop"),
			type = "slider",
			min = 1,
			max = 6,
			step = 0.1,
			value = 2,
			description = BAR.I18N("ui.settings.option.dof_fstop_descr"),
			widgetConfig = { "Depth of Field", "fStop", api = "dof", set = "setFstop" },
		},
	}
end
