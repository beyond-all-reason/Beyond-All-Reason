-- tf_lights.lua: extracted tool module for gui_terraform_brush
local M = {}

function M.attach(doc, ctx)
	if ctx.attachTBMirrorControls then ctx.attachTBMirrorControls(doc, "lp") end
	local widgetState = ctx.widgetState
	local uiState = ctx.uiState
	local WG = ctx.WG
	local playSound = ctx.playSound
	local setActiveClass = ctx.setActiveClass
	local trackSliderDrag = ctx.trackSliderDrag
	local clearPassthrough = ctx.clearPassthrough
	local ROTATION_STEP = ctx.ROTATION_STEP
	local CURVE_STEP = ctx.CURVE_STEP
	local LENGTH_SCALE_STEP = ctx.LENGTH_SCALE_STEP
	local RADIUS_STEP = ctx.RADIUS_STEP
	local sliderToCadence = ctx.sliderToCadence
	local cadenceToSlider = ctx.cadenceToSlider
	local sliderToFrequency = ctx.sliderToFrequency
	local sliderToPersist = ctx.sliderToPersist
	local PERSIST_PERMANENT_VAL = ctx.PERSIST_PERMANENT_VAL
	local formatFrequency = ctx.formatFrequency
	local guideHints = ctx.guideHints
	local shapeNames = ctx.shapeNames
	local GetMouseState = Spring.GetMouseState
	local TraceScreenRay = Spring.TraceScreenRay
	-- ============ Light Placer controls ============

	widgetState.lightControlsEl = doc:GetElementById("tf-light-controls")

	-- Light type buttons
	local ltTypes = { "point", "cone", "beam" }
	for _, lt in ipairs(ltTypes) do
		local btn = doc:GetElementById("btn-lt-" .. lt)
		if btn then
			widgetState.lightTypeButtons[lt] = btn
			btn:AddEventListener("click", function(event)
				playSound("modeSwitch")
				if WG.LightPlacer then WG.LightPlacer.setLightType(lt) end
				event:StopPropagation()
			end, false)
		end
	end

	-- Placement mode buttons
	local lpModes = { "point", "scatter", "remove" }
	for _, mode in ipairs(lpModes) do
		local btn = doc:GetElementById("btn-lp-" .. mode)
		if btn then
			widgetState.lightModeButtons[mode] = btn
			btn:AddEventListener("click", function(event)
				playSound("modeSwitch")
				if WG.LightPlacer then WG.LightPlacer.setMode(mode) end
				event:StopPropagation()
			end, false)
		end
	end

	-- Distribution buttons
	local lpDists = { "random", "regular", "clustered" }
	for _, dist in ipairs(lpDists) do
		local btn = doc:GetElementById("btn-lp-dist-" .. dist)
		if btn then
			widgetState.lightDistButtons[dist] = btn
			btn:AddEventListener("click", function(event)
				playSound("shapeSwitch")
				if WG.LightPlacer then WG.LightPlacer.setDistribution(dist) end
				event:StopPropagation()
			end, false)
		end
	end

	-- Color sliders
	local function setupColorSlider(channel, idx)
		local slider = doc:GetElementById("slider-lp-color-" .. channel)
		if slider then
			trackSliderDrag(slider, "lp-color-" .. channel)
			slider:AddEventListener("change", function(event)
				if uiState.updatingFromCode then return end
				local val = tonumber(slider:GetAttribute("value")) or 0
				if WG.LightPlacer then
					local state = WG.LightPlacer.getState()
					local r, g, b = state.color[1], state.color[2], state.color[3]
					if idx == 1 then r = val / 1000
					elseif idx == 2 then g = val / 1000
					else b = val / 1000 end
					WG.LightPlacer.setColor(r, g, b)
				end
				event:StopPropagation()
			end, false)
		end
	end
	setupColorSlider("r", 1)
	setupColorSlider("g", 2)
	setupColorSlider("b", 3)

	-- Color palette swatch clicks
	do
	local PALETTE = {
		-- Row 1: neutrals + warm-to-cool spectrum (18)
		{1.0, 1.0, 1.0, "#FFFFFF", "White"},
		{0.88, 0.88, 0.88, "#E0E0E0", "Light Gray"},
		{0.53, 0.53, 0.53, "#888888", "Gray"},
		{0.33, 0.33, 0.33, "#555555", "Dark Gray"},
		{0.2, 0.2, 0.2, "#333333", "Charcoal"},
		{0.11, 0.11, 0.11, "#1D1D1D", "Near Black"},
		{0.03, 0.02, 0.02, "#080606", "Black"},
		{1.0, 0.0, 0.0, "#FF0000", "Red"},
		{1.0, 0.27, 0.0, "#FF4400", "Red-Orange"},
		{1.0, 0.53, 0.0, "#FF8800", "Orange"},
		{1.0, 0.8, 0.0, "#FFCC00", "Gold"},
		{1.0, 0.93, 0.33, "#FFEE54", "Yellow"},
		{0.53, 1.0, 0.0, "#88FF00", "Lime"},
		{0.0, 1.0, 0.0, "#00FF00", "Green"},
		{0.0, 1.0, 0.8, "#00FFCC", "Aquamarine"},
		{0.0, 0.8, 1.0, "#00CCFF", "Sky Blue"},
		{0.0, 0.53, 1.0, "#0088FF", "Dodger Blue"},
		{0.0, 0.0, 1.0, "#0000FF", "Blue"},
		-- Row 2: warm tones, pinks/purples, pastels (18)
		{1.0, 1.0, 0.8, "#FFFFCC", "Cream"},
		{1.0, 0.88, 0.69, "#FFE0B0", "Peach"},
		{1.0, 0.78, 0.49, "#FFC87C", "Light Apricot"},
		{1.0, 0.67, 0.27, "#FFAA44", "Sandy Orange"},
		{0.8, 0.4, 0.0, "#CC6600", "Brown Orange"},
		{0.53, 0.27, 0.0, "#884400", "Saddle Brown"},
		{0.27, 0.13, 0.0, "#442200", "Dark Brown"},
		{1.0, 0.0, 0.53, "#FF0088", "Hot Pink"},
		{1.0, 0.0, 1.0, "#FF00FF", "Magenta"},
		{0.53, 0.0, 1.0, "#8800FF", "Purple"},
		{0.64, 0.11, 0.89, "#A41DE2", "Violet"},
		{0.4, 0.27, 0.8, "#6644CC", "Indigo"},
		{0.0, 1.0, 1.0, "#00FFFF", "Cyan"},
		{0.67, 1.0, 0.8, "#AAFFCC", "Mint"},
		{0.8, 0.87, 1.0, "#CCDDFF", "Lavender"},
		{1.0, 0.8, 0.87, "#FFCCDD", "Pink"},
		{0.87, 0.8, 1.0, "#DDCCFF", "Lilac"},
		{0.8, 1.0, 0.87, "#CCFFDD", "Honeydew"},
		-- Row 3: BAR theme + warm/cool light presets (18)
		{0.17, 0.65, 0.92, "#2BA5EA", "Armada Blue"},
		{0.99, 0.75, 0.30, "#FDC04C", "BAR Yellow"},
		{0.27, 0.92, 0.17, "#46EA2B", "BAR HP Green"},
		{0.42, 0.35, 0.0, "#6B5A00", "Buildtime Dark"},
		{0.16, 0.16, 0.16, "#282828", "BAR Border"},
		{1.0, 0.93, 0.87, "#FFEEDD", "Warm White"},
		{1.0, 0.83, 0.63, "#FFD4A0", "Candle"},
		{1.0, 0.73, 0.47, "#FFBB77", "Tungsten"},
		{1.0, 0.6, 0.27, "#FF9944", "Sunset"},
		{1.0, 0.47, 0.13, "#FF7722", "Amber"},
		{0.87, 0.33, 0.0, "#DD5500", "Deep Orange"},
		{0.93, 0.93, 1.0, "#EEEEFF", "Cool White"},
		{0.8, 0.8, 1.0, "#CCCCFF", "Pale Blue"},
		{0.67, 0.73, 1.0, "#AABBFF", "Soft Blue"},
		{0.53, 0.6, 0.87, "#8899DD", "Steel Blue"},
		{0.4, 0.47, 0.73, "#6677BB", "Slate"},
		{0.27, 0.33, 0.6, "#445599", "Night Blue"},
		{0.13, 0.2, 0.47, "#223377", "Midnight"},
	}
	for idx, c in ipairs(PALETTE) do
		local swatch = doc:GetElementById("lp-swatch-" .. idx)
		if swatch then
			swatch:AddEventListener("click", function(event)
				if WG.LightPlacer then
					WG.LightPlacer.setColor(c[1], c[2], c[3])
				end
				event:StopPropagation()
			end, false)
			guideHints["lp-swatch-" .. idx] = c[5] .. " " .. c[4]
		end
	end
	end

	-- Brightness slider
	local brightnessSlider = doc:GetElementById("slider-lp-brightness")
	if brightnessSlider then
		trackSliderDrag(brightnessSlider, "lp-brightness")
		brightnessSlider:AddEventListener("change", function(event)
			if uiState.updatingFromCode then return end
			local val = tonumber(brightnessSlider:GetAttribute("value")) or 200
			if WG.LightPlacer then WG.LightPlacer.setBrightness(val / 100) end
			event:StopPropagation()
		end, false)
	end
	local brightDownBtn = doc:GetElementById("btn-lp-brightness-down")
	if brightDownBtn then
		brightDownBtn:AddEventListener("click", function(event)
			if WG.LightPlacer then
				local s = WG.LightPlacer.getState()
				WG.LightPlacer.setBrightness(s.brightness - 0.1)
			end
			event:StopPropagation()
		end, false)
	end
	local brightUpBtn = doc:GetElementById("btn-lp-brightness-up")
	if brightUpBtn then
		brightUpBtn:AddEventListener("click", function(event)
			if WG.LightPlacer then
				local s = WG.LightPlacer.getState()
				WG.LightPlacer.setBrightness(s.brightness + 0.1)
			end
			event:StopPropagation()
		end, false)
	end

	-- Light radius slider
	local lightRadSlider = doc:GetElementById("slider-lp-light-radius")
	if lightRadSlider then
		trackSliderDrag(lightRadSlider, "lp-light-radius")
		lightRadSlider:AddEventListener("change", function(event)
			if uiState.updatingFromCode then return end
			local val = tonumber(lightRadSlider:GetAttribute("value")) or 300
			if WG.LightPlacer then WG.LightPlacer.setLightRadius(val) end
			event:StopPropagation()
		end, false)
	end
	local lightRadDown = doc:GetElementById("btn-lp-light-radius-down")
	if lightRadDown then
		lightRadDown:AddEventListener("click", function(event)
			if WG.LightPlacer then
				local s = WG.LightPlacer.getState()
				WG.LightPlacer.setLightRadius(s.lightRadius - 50)
			end
			event:StopPropagation()
		end, false)
	end
	local lightRadUp = doc:GetElementById("btn-lp-light-radius-up")
	if lightRadUp then
		lightRadUp:AddEventListener("click", function(event)
			if WG.LightPlacer then
				local s = WG.LightPlacer.getState()
				WG.LightPlacer.setLightRadius(s.lightRadius + 50)
			end
			event:StopPropagation()
		end, false)
	end

	-- Elevation slider
	local elevSlider = doc:GetElementById("slider-lp-elevation")
	if elevSlider then
		trackSliderDrag(elevSlider, "lp-elevation")
		elevSlider:AddEventListener("change", function(event)
			if uiState.updatingFromCode then return end
			local val = tonumber(elevSlider:GetAttribute("value")) or 20
			if WG.LightPlacer then WG.LightPlacer.setElevation(val) end
			event:StopPropagation()
		end, false)
	end
	local elevDown = doc:GetElementById("btn-lp-elevation-down")
	if elevDown then
		elevDown:AddEventListener("click", function(event)
			if WG.LightPlacer then
				local s = WG.LightPlacer.getState()
				WG.LightPlacer.setElevation(s.elevation - 5)
			end
			event:StopPropagation()
		end, false)
	end
	local elevUp = doc:GetElementById("btn-lp-elevation-up")
	if elevUp then
		elevUp:AddEventListener("click", function(event)
			if WG.LightPlacer then
				local s = WG.LightPlacer.getState()
				WG.LightPlacer.setElevation(s.elevation + 5)
			end
			event:StopPropagation()
		end, false)
	end

	-- Direction sliders (roll removed; pitch/yaw use the globe widget)
	-- (no slider elements remain for pitch/yaw/roll)

	-- Theta slider (cone spread)
	local thetaSlider = doc:GetElementById("slider-lp-theta")
	if thetaSlider then
		trackSliderDrag(thetaSlider, "lp-theta")
		thetaSlider:AddEventListener("change", function(event)
			if uiState.updatingFromCode then return end
			local val = tonumber(thetaSlider:GetAttribute("value")) or 500
			if WG.LightPlacer then WG.LightPlacer.setTheta(val / 1000) end
			event:StopPropagation()
		end, false)
	end

	-- Beam length slider
	local beamLenSlider = doc:GetElementById("slider-lp-beam-length")
	if beamLenSlider then
		trackSliderDrag(beamLenSlider, "lp-beam-length")
		beamLenSlider:AddEventListener("change", function(event)
			if uiState.updatingFromCode then return end
			local val = tonumber(beamLenSlider:GetAttribute("value")) or 300
			if WG.LightPlacer then WG.LightPlacer.setBeamLength(val) end
			event:StopPropagation()
		end, false)
	end

	-- +/- buttons for direction / theta / beam-length / color channels
	local nudgeBtns = {
		{ id = "lp-theta",       getter = "theta",      setter = "setTheta",      step = 0.05 },
		{ id = "lp-beam-length", getter = "beamLength", setter = "setBeamLength", step = 50 },
	}
	for _, nb in ipairs(nudgeBtns) do
		local down = doc:GetElementById("btn-" .. nb.id .. "-down")
		if down then
			down:AddEventListener("click", function(event)
				if WG.LightPlacer then
					local s = WG.LightPlacer.getState()
					WG.LightPlacer[nb.setter](s[nb.getter] - nb.step)
				end
				event:StopPropagation()
			end, false)
		end
		local up = doc:GetElementById("btn-" .. nb.id .. "-up")
		if up then
			up:AddEventListener("click", function(event)
				if WG.LightPlacer then
					local s = WG.LightPlacer.getState()
					WG.LightPlacer[nb.setter](s[nb.getter] + nb.step)
				end
				event:StopPropagation()
			end, false)
		end
	end

	-- Hemisphere orientation globe (pitch/yaw interactive widget)
	local globeEl = doc:GetElementById("lp-orient-globe")
	local globeDragging = false
	local orientPitchInput = doc:GetElementById("lp-orient-pitch-input")
	local orientYawInput   = doc:GetElementById("lp-orient-yaw-input")
	local globeKeyReturn   -- resolved lazily on first keydown

	local function applyGlobeDirection()
		if not globeEl then return end
		local mx, my = GetMouseState()
		local vsy = select(2, Spring.GetViewGeometry())
		local rml_my = vsy - my
		local gl = globeEl.absolute_left
		local gt = globeEl.absolute_top
		local gw = globeEl.offset_width
		local gh = globeEl.offset_height
		if not gw or gw <= 0 or not gh or gh <= 0 then return end
		local nx = ((mx - gl) / gw) * 2 - 1
		local ny = ((rml_my - gt) / gh) * 2 - 1
		local len = math.sqrt(nx * nx + ny * ny)
		if len > 1 then nx = nx / len; ny = ny / len; len = 1 end
		local pitch_deg
		if len < 0.001 then
			pitch_deg = -90
		else
			pitch_deg = -(math.acos(math.max(0, math.min(1, len))) * 180 / math.pi)
		end
		local yaw_deg
		if len >= 0.001 then
			yaw_deg = math.atan2(nx, -ny) * 180 / math.pi
			if yaw_deg < 0 then yaw_deg = yaw_deg + 360 end
		else
			local s = WG.LightPlacer and WG.LightPlacer.getState()
			yaw_deg = s and s.yaw or 0
		end
		if WG.LightPlacer then
			WG.LightPlacer.setPitch(pitch_deg)
			WG.LightPlacer.setYaw(yaw_deg)
		end
	end

	if globeEl then
		globeEl:AddEventListener("mousedown", function(event)
			local p = event.parameters
			if p and p.button == 0 then
				globeDragging = true
				applyGlobeDirection()
			end
			event:StopPropagation()
		end, false)
	end
	doc:AddEventListener("mousemove", function()
		if globeDragging then applyGlobeDirection() end
	end, false)
	doc:AddEventListener("mouseup", function(event)
		local p = event.parameters
		if p and p.button == 0 then globeDragging = false end
	end, false)

	-- Pitch/Yaw direct-entry numboxes
	local function wireOrientNumbox(inputEl, setter, clampLo, clampHi)
		if not inputEl then return end
		local function applyVal()
			local raw = inputEl:GetAttribute("value")
			local val = tonumber(raw)
			if not val then return end
			val = math.max(clampLo, math.min(clampHi, val))
			if WG.LightPlacer then WG.LightPlacer[setter](val) end
		end
		inputEl:AddEventListener("focus", function()
			Spring.SDLStartTextInput()
			widgetState.focusedRmlInput = inputEl
		end, false)
		inputEl:AddEventListener("blur", function()
			applyVal()
			Spring.SDLStopTextInput()
			widgetState.focusedRmlInput = nil
		end, false)
		inputEl:AddEventListener("keydown", function(event)
			if not globeKeyReturn then
				pcall(function() globeKeyReturn = RmlUi.key_identifier.RETURN end)
			end
			local p = event.parameters
			if p and globeKeyReturn and p.key_identifier == globeKeyReturn then
				applyVal()
				inputEl:Blur()
			end
		end, false)
	end
	wireOrientNumbox(orientPitchInput, "setPitch", -90, 90)
	wireOrientNumbox(orientYawInput,   "setYaw",   0,   360)

	-- +/- buttons for color R/G/B channels
	local colorChannels = { r = 1, g = 2, b = 3 }
	for ch, idx in pairs(colorChannels) do
		local down = doc:GetElementById("btn-lp-color-" .. ch .. "-down")
		if down then
			down:AddEventListener("click", function(event)
				if WG.LightPlacer then
					local s = WG.LightPlacer.getState()
					local r, g, b = s.color[1], s.color[2], s.color[3]
					if idx == 1 then r = math.max(0, r - 0.05)
					elseif idx == 2 then g = math.max(0, g - 0.05)
					else b = math.max(0, b - 0.05) end
					WG.LightPlacer.setColor(r, g, b)
				end
				event:StopPropagation()
			end, false)
		end
		local up = doc:GetElementById("btn-lp-color-" .. ch .. "-up")
		if up then
			up:AddEventListener("click", function(event)
				if WG.LightPlacer then
					local s = WG.LightPlacer.getState()
					local r, g, b = s.color[1], s.color[2], s.color[3]
					if idx == 1 then r = math.min(1, r + 0.05)
					elseif idx == 2 then g = math.min(1, g + 0.05)
					else b = math.min(1, b + 0.05) end
					WG.LightPlacer.setColor(r, g, b)
				end
				event:StopPropagation()
			end, false)
		end
	end

	-- Scatter count slider
	local countSlider = doc:GetElementById("slider-lp-count")
	if countSlider then
		trackSliderDrag(countSlider, "lp-count")
		countSlider:AddEventListener("change", function(event)
			if uiState.updatingFromCode then return end
			local val = tonumber(countSlider:GetAttribute("value")) or 5
			if WG.LightPlacer then WG.LightPlacer.setLightCount(val) end
			event:StopPropagation()
		end, false)
	end
	local countDown = doc:GetElementById("btn-lp-count-down")
	if countDown then
		countDown:AddEventListener("click", function(event)
			if WG.LightPlacer then
				local s = WG.LightPlacer.getState()
				WG.LightPlacer.setLightCount(s.lightCount - 1)
			end
			event:StopPropagation()
		end, false)
	end
	local countUp = doc:GetElementById("btn-lp-count-up")
	if countUp then
		countUp:AddEventListener("click", function(event)
			if WG.LightPlacer then
				local s = WG.LightPlacer.getState()
				WG.LightPlacer.setLightCount(s.lightCount + 1)
			end
			event:StopPropagation()
		end, false)
	end

	-- Brush radius slider (scatter area)
	local brushRadSlider = doc:GetElementById("slider-lp-brush-radius")
	if brushRadSlider then
		trackSliderDrag(brushRadSlider, "lp-brush-radius")
		brushRadSlider:AddEventListener("change", function(event)
			if uiState.updatingFromCode then return end
			local val = tonumber(brushRadSlider:GetAttribute("value")) or 200
			if WG.LightPlacer then WG.LightPlacer.setRadius(val) end
			event:StopPropagation()
		end, false)
	end
	local brushRadDown = doc:GetElementById("btn-lp-brush-radius-down")
	if brushRadDown then
		brushRadDown:AddEventListener("click", function(event)
			if WG.LightPlacer then
				local s = WG.LightPlacer.getState()
				WG.LightPlacer.setRadius(s.radius - 8)
			end
			event:StopPropagation()
		end, false)
	end
	local brushRadUp = doc:GetElementById("btn-lp-brush-radius-up")
	if brushRadUp then
		brushRadUp:AddEventListener("click", function(event)
			if WG.LightPlacer then
				local s = WG.LightPlacer.getState()
				WG.LightPlacer.setRadius(s.radius + 8)
			end
			event:StopPropagation()
		end, false)
	end

	-- Action buttons: library, undo, redo, save, load, clear all
	local libraryBtn = doc:GetElementById("btn-lp-library")
	if libraryBtn then
		libraryBtn:AddEventListener("click", function(event)
			playSound("panelOpen")
			widgetState.lightLibraryOpen = not widgetState.lightLibraryOpen
			if not widgetState.lightLibraryOpen and WG.LightPlacer and WG.LightPlacer.clearPendingPreset then
				WG.LightPlacer.clearPendingPreset()
			end
			event:StopPropagation()
		end, false)
	end
	local undoBtn = doc:GetElementById("btn-lp-undo")
	if undoBtn then
		undoBtn:AddEventListener("click", function(event)
			playSound("undo")
			if WG.LightPlacer then WG.LightPlacer.undo() end
			event:StopPropagation()
		end, false)
	end
	local redoBtn = doc:GetElementById("btn-lp-redo")
	if redoBtn then
		redoBtn:AddEventListener("click", function(event)
			playSound("undo")
			if WG.LightPlacer then WG.LightPlacer.redo() end
			event:StopPropagation()
		end, false)
	end
	-- Light history slider
	local sliderLpHistory = doc:GetElementById("slider-lp-history")
	if sliderLpHistory then
		trackSliderDrag(sliderLpHistory, "lp-history")
		sliderLpHistory:AddEventListener("change", function(event)
			if uiState.updatingFromCode then event:StopPropagation(); return end
			if not WG.LightPlacer then event:StopPropagation(); return end
			local val = tonumber(sliderLpHistory:GetAttribute("value")) or 0
			local lpSt = WG.LightPlacer.getState()
			if not lpSt then event:StopPropagation(); return end
			local currentUndoCount = lpSt.undoCount or 0
			local diff = val - currentUndoCount
			if diff > 0 then
				for i = 1, diff do
					WG.LightPlacer.redo()
				end
			elseif diff < 0 then
				for i = 1, -diff do
					WG.LightPlacer.undo()
				end
			end
			event:StopPropagation()
		end, false)
	end
	local saveBtn = doc:GetElementById("btn-lp-save")
	if saveBtn then
		saveBtn:AddEventListener("click", function(event)
			playSound("save")
			if WG.LightPlacer then WG.LightPlacer.save() end
			event:StopPropagation()
		end, false)
	end
	local loadBtn = doc:GetElementById("btn-lp-load")
	if loadBtn then
		loadBtn:AddEventListener("click", function(event)
			playSound("dropdown")
			if WG.LightPlacer then WG.LightPlacer.load() end
			event:StopPropagation()
		end, false)
	end
	local clearAllBtn = doc:GetElementById("btn-lp-clear-all")
	if clearAllBtn then
		clearAllBtn:AddEventListener("click", function(event)
			playSound("reset")
			if WG.LightPlacer then WG.LightPlacer.clearAll() end
			event:StopPropagation()
		end, false)
	end

	-- ============ Light Library floating window ============
	widgetState.lightLibraryRootEl = doc:GetElementById("tf-light-library-root")
	local llBuiltinList = doc:GetElementById("ll-builtin-list")
	local llUserList    = doc:GetElementById("ll-user-list")
	local llSearchInput = doc:GetElementById("ll-search-input")

	local function getLLSearchFilter()
		if llSearchInput then
			local val = llSearchInput:GetAttribute("value") or ""
			return val:lower()
		end
		return ""
	end

	-- Helper: populate builtin presets list
	local function populateBuiltinPresets(filter)
		if not llBuiltinList or not WG.LightPlacer then return end
		filter = filter or getLLSearchFilter()
		llBuiltinList.inner_rml = ""
		local presets = WG.LightPlacer.getBuiltinPresets()
		if not presets then return end
		local shown = {}
		for i, preset in ipairs(presets) do
			local name = preset.name or "Unnamed"
			if filter == "" or name:lower():find(filter, 1, true) or (preset.desc or ""):lower():find(filter, 1, true) then
				shown[#shown + 1] = { idx = i, preset = preset }
			end
		end
		for _, entry in ipairs(shown) do
			local i = entry.idx
			local preset = entry.preset
			local itemId = "ll-builtin-" .. i
			local html = '<div id="' .. itemId .. '" class="ll-preset-item">'
				.. '<div class="ll-preset-name">' .. (preset.name or "Unnamed") .. '</div>'
				.. '<div class="ll-preset-desc">' .. (preset.desc or "") .. ' (' .. #preset.lights .. ' lights)</div>'
				.. '</div>'
			llBuiltinList.inner_rml = llBuiltinList.inner_rml .. html
		end
		-- Bind click events after populating
		for _, entry in ipairs(shown) do
			local i = entry.idx
			local preset = entry.preset
			local item = doc:GetElementById("ll-builtin-" .. i)
			if item then
				item:AddEventListener("click", function(event)
					widgetState.lightLibrarySelectedPreset = preset
					if WG.LightPlacer and WG.LightPlacer.setPendingPreset then
						WG.LightPlacer.setPendingPreset(preset)
					end
					for _, e2 in ipairs(shown) do
						local el = doc:GetElementById("ll-builtin-" .. e2.idx)
						if el then el:SetClass("selected", e2.idx == i) end
					end
					event:StopPropagation()
				end, false)
				item:AddEventListener("dblclick", function(event)
					if WG.LightPlacer then
						local mx, my = GetMouseState()
						local _, coords = TraceScreenRay(mx, my, true)
						if coords then
							WG.LightPlacer.placePreset(preset, coords[1], coords[3])
						end
					end
					event:StopPropagation()
				end, false)
			end
		end
	end

	-- Helper: populate user presets list
	local function populateUserPresets(filter)
		if not llUserList or not WG.LightPlacer then return end
		filter = filter or getLLSearchFilter()
		llUserList.inner_rml = ""
		local presets = WG.LightPlacer.listUserPresets()
		if not presets or #presets == 0 then
			llUserList.inner_rml = '<div class="text-xs text-keybind" style="padding: 4dp;">No saved user presets yet.</div>'
			return
		end
		local shown = {}
		for i, p in ipairs(presets) do
			local name = p.name or "?"
			if filter == "" or name:lower():find(filter, 1, true) then
				shown[#shown + 1] = { idx = i, p = p }
			end
		end
		for _, entry in ipairs(shown) do
			local i = entry.idx
			local p = entry.p
			local itemId = "ll-user-" .. i
			local html = '<div id="' .. itemId .. '" class="ll-preset-item">'
				.. '<div class="ll-preset-name">' .. (p.name or "?") .. '</div>'
				.. '</div>'
			llUserList.inner_rml = llUserList.inner_rml .. html
		end
		for _, entry in ipairs(shown) do
			local i = entry.idx
			local p = entry.p
			local item = doc:GetElementById("ll-user-" .. i)
			if item then
				item:AddEventListener("click", function(event)
					local data = WG.LightPlacer.loadPresetFile(p.path)
					if data then
						widgetState.lightLibrarySelectedPreset = data
						if WG.LightPlacer.setPendingPreset then
							WG.LightPlacer.setPendingPreset(data)
						end
					end
					for _, e2 in ipairs(shown) do
						local el = doc:GetElementById("ll-user-" .. e2.idx)
						if el then el:SetClass("selected", e2.idx == i) end
					end
					event:StopPropagation()
				end, false)
				item:AddEventListener("dblclick", function(event)
					local data = WG.LightPlacer.loadPresetFile(p.path)
					if data and WG.LightPlacer then
						local mx, my = GetMouseState()
						local _, coords = TraceScreenRay(mx, my, true)
						if coords then
							WG.LightPlacer.placePreset(data, coords[1], coords[3])
						end
					end
					event:StopPropagation()
				end, false)
			end
		end
	end

	-- Library button (in light controls) toggles library window
	-- Already bound above to widgetState.lightLibraryOpen toggle;
	-- Now also toggle the root element visibility
	local origLibraryBtn = doc:GetElementById("btn-lp-library")
	if origLibraryBtn then
		origLibraryBtn:AddEventListener("click", function(event)
			if widgetState.lightLibraryRootEl then
				widgetState.lightLibraryRootEl:SetClass("hidden", not widgetState.lightLibraryOpen)
				if widgetState.lightLibraryOpen then
					populateBuiltinPresets()
					if widgetState.lightLibraryTab == "user" then
						populateUserPresets()
					end
				end
			end
		end, false)
	end

	-- Tab buttons
	local tabBuiltin = doc:GetElementById("btn-ll-tab-builtin")
	local tabUser    = doc:GetElementById("btn-ll-tab-user")
	if tabBuiltin then
		tabBuiltin:AddEventListener("click", function(event)
			playSound("click")
			widgetState.lightLibraryTab = "builtin"
			if tabBuiltin then tabBuiltin:SetClass("active", true) end
			if tabUser then tabUser:SetClass("active", false) end
			if llBuiltinList then llBuiltinList:SetClass("hidden", false) end
			if llUserList then llUserList:SetClass("hidden", true) end
			event:StopPropagation()
		end, false)
	end
	if tabUser then
		tabUser:AddEventListener("click", function(event)
			playSound("click")
			widgetState.lightLibraryTab = "user"
			if tabBuiltin then tabBuiltin:SetClass("active", false) end
			if tabUser then tabUser:SetClass("active", true) end
			if llBuiltinList then llBuiltinList:SetClass("hidden", true) end
			if llUserList then llUserList:SetClass("hidden", false) end
			populateUserPresets()
			event:StopPropagation()
		end, false)
	end

	-- Close button
	local llCloseBtn = doc:GetElementById("btn-light-library-close")
	if llCloseBtn then
		llCloseBtn:AddEventListener("click", function(event)
			playSound("click")
			widgetState.lightLibraryOpen = false
			if widgetState.lightLibraryRootEl then
				widgetState.lightLibraryRootEl:SetClass("hidden", true)
			end
			if WG.LightPlacer and WG.LightPlacer.clearPendingPreset then
				WG.LightPlacer.clearPendingPreset()
			end
			event:StopPropagation()
		end, false)
	end

	-- Search bar filtering
	if llSearchInput then
		llSearchInput:AddEventListener("change", function(event)
			local filter = getLLSearchFilter()
			if widgetState.lightLibraryTab == "builtin" then
				populateBuiltinPresets(filter)
			else
				populateUserPresets(filter)
			end
		end, false)
	end
	local llSearchClear = doc:GetElementById("btn-ll-search-clear")
	if llSearchClear then
		llSearchClear:AddEventListener("click", function(event)
			if llSearchInput then
				llSearchInput:SetAttribute("value", "")
			end
			if widgetState.lightLibraryTab == "builtin" then
				populateBuiltinPresets("")
			else
				populateUserPresets("")
			end
			event:StopPropagation()
		end, false)
	end

	-- Save preset button
	local llSaveBtn = doc:GetElementById("btn-ll-save-preset")
	local llNameInput = doc:GetElementById("input-ll-preset-name")
	if llSaveBtn then
		llSaveBtn:AddEventListener("click", function(event)
			playSound("save")
			if WG.LightPlacer and llNameInput then
				local name = llNameInput:GetAttribute("value") or ""
				if name ~= "" then
					WG.LightPlacer.saveUserPreset(name)
					populateUserPresets()
				end
			end
			event:StopPropagation()
		end, false)
	end

	-- Delete selected preset
	local llDeleteBtn = doc:GetElementById("btn-ll-delete-preset")
	if llDeleteBtn then
		llDeleteBtn:AddEventListener("click", function(event)
			playSound("reset")
			local sel = widgetState.lightLibrarySelectedPreset
			if sel and sel.name and WG.LightPlacer then
				-- Only delete user presets (ones loaded from files)
				local presets = WG.LightPlacer.listUserPresets()
				for _, p in ipairs(presets) do
					if p.name == sel.name then
						os.remove(p.path)
						widgetState.lightLibrarySelectedPreset = nil
						populateUserPresets()
						break
					end
				end
			end
			event:StopPropagation()
		end, false)
	end

	-- Refresh button
	local llRefreshBtn = doc:GetElementById("btn-ll-refresh")
	if llRefreshBtn then
		llRefreshBtn:AddEventListener("click", function(event)
			playSound("click")
			populateBuiltinPresets()
			populateUserPresets()
			event:StopPropagation()
		end, false)
	end
end

function M.sync(doc, ctx, lpState, setSummary)
	if ctx.syncTBMirrorControls then ctx.syncTBMirrorControls(doc, "lp") end
	local widgetState = ctx.widgetState
	local uiState = ctx.uiState
	local WG = ctx.WG
	local setActiveClass = ctx.setActiveClass
	local syncAndFlash = ctx.syncAndFlash
	local cadenceToSlider = ctx.cadenceToSlider
	local shapeNames = ctx.shapeNames
		-- ===== Light Placer mode: highlight button, clear others, sync controls =====
		local lightsBtnU = doc and doc:GetElementById("btn-lights")
		if lightsBtnU then lightsBtnU:SetClass("active", true) end
		setActiveClass(widgetState.modeButtons, nil)

		-- Update light type buttons
		for lt, el in pairs(widgetState.lightTypeButtons) do
			el:SetClass("active", lt == lpState.lightType)
		end
		-- Update placement mode buttons
		for mode, el in pairs(widgetState.lightModeButtons) do
			el:SetClass("active", mode == lpState.mode)
		end
		-- Sync shape button active state to LightPlacer's shape
		setActiveClass(widgetState.shapeButtons, lpState.shape)
		-- Show/hide direction section for cone/beam
		local dirSection = doc and doc:GetElementById("lp-direction-section")
		if dirSection then dirSection:SetClass("hidden", lpState.lightType == "point") end
		local thetaSection = doc and doc:GetElementById("lp-theta-section")
		if thetaSection then thetaSection:SetClass("hidden", lpState.lightType ~= "cone") end
		local beamSection = doc and doc:GetElementById("lp-beam-section")
		if beamSection then beamSection:SetClass("hidden", lpState.lightType ~= "beam") end
		-- Show/hide scatter section
		local scatterSection = doc and doc:GetElementById("lp-scatter-section")
		if scatterSection then scatterSection:SetClass("hidden", lpState.mode ~= "scatter") end
		-- Show/hide distribution section (only visible for scatter)
		local distSection = doc and doc:GetElementById("lp-distribution-section")
		if distSection then distSection:SetClass("hidden", lpState.mode ~= "scatter") end
		-- Gray out scatter + distribution for cone/beam (they only support single placement)
		local directedLight = lpState.lightType == "cone" or lpState.lightType == "beam"
		if directedLight and lpState.mode == "scatter" then
			if WG.LightPlacer then WG.LightPlacer.setMode("point") end
		end
		local scatterBtn = doc and doc:GetElementById("btn-lp-scatter")
		if scatterBtn then scatterBtn:SetClass("lp-unavailable", directedLight) end
		local distToggleHdr = doc and doc:GetElementById("btn-toggle-lt-dist")
		if distToggleHdr then distToggleHdr:SetClass("lp-unavailable", directedLight) end
		local distLtSection = doc and doc:GetElementById("section-lt-dist")
		if distLtSection then distLtSection:SetClass("lp-unavailable", directedLight) end
		-- Update distribution buttons
		for dist, el in pairs(widgetState.lightDistButtons) do
			el:SetClass("active", dist == lpState.distribution)
		end
		-- Update labels
		local brightnessLabel = doc and doc:GetElementById("lp-brightness-label")
		if brightnessLabel then brightnessLabel.inner_rml = string.format("%.1f", lpState.brightness) end
		local lightRadLabel = doc and doc:GetElementById("lp-light-radius-label")
		if lightRadLabel then lightRadLabel.inner_rml = tostring(math.floor(lpState.lightRadius)) end
		local elevLabel = doc and doc:GetElementById("lp-elevation-label")
		if elevLabel then elevLabel.inner_rml = tostring(math.floor(lpState.elevation)) end
		local countLabel = doc and doc:GetElementById("lp-count-label")
		if countLabel then countLabel.inner_rml = tostring(lpState.lightCount) end
		local brushRadLabel = doc and doc:GetElementById("lp-brush-radius-label")
		if brushRadLabel then brushRadLabel.inner_rml = tostring(math.floor(lpState.radius)) end
		-- Update color labels and preview
		local rLabel = doc and doc:GetElementById("lp-color-r-label")
		if rLabel then rLabel.inner_rml = string.format("%.2f", lpState.color[1]) end
		local gLabel = doc and doc:GetElementById("lp-color-g-label")
		if gLabel then gLabel.inner_rml = string.format("%.2f", lpState.color[2]) end
		local bLabel = doc and doc:GetElementById("lp-color-b-label")
		if bLabel then bLabel.inner_rml = string.format("%.2f", lpState.color[3]) end
		local colorPreview = doc and doc:GetElementById("lp-color-preview")
		if colorPreview then
			local cr = math.floor(lpState.color[1] * 255)
			local cg = math.floor(lpState.color[2] * 255)
			local cb = math.floor(lpState.color[3] * 255)
			colorPreview:SetAttribute("style", string.format("background-color: #%02x%02x%02x;", cr, cg, cb))
		end
		-- Direction labels
		local pitchLabel = doc and doc:GetElementById("lp-pitch-label")
		if pitchLabel then pitchLabel.inner_rml = tostring(math.floor(lpState.pitch)) end
		local yawLabel = doc and doc:GetElementById("lp-yaw-label")
		if yawLabel then yawLabel.inner_rml = tostring(math.floor(lpState.yaw)) end
		local rollLabel = doc and doc:GetElementById("lp-roll-label")
		if rollLabel then rollLabel.inner_rml = tostring(math.floor(lpState.roll)) end
		local thetaLabel = doc and doc:GetElementById("lp-theta-label")
		if thetaLabel then thetaLabel.inner_rml = string.format("%.2f", lpState.theta) end
		local beamLenLabel = doc and doc:GetElementById("lp-beam-length-label")
		if beamLenLabel then beamLenLabel.inner_rml = tostring(math.floor(lpState.beamLength)) end
		-- Placed count
		local placedEl = doc and doc:GetElementById("lp-placed-count")
		if placedEl and WG.LightPlacer then
			placedEl.inner_rml = tostring(WG.LightPlacer.getPlacedCount())
		end
		-- Light history slider sync
		local sliderLpHist = doc and doc:GetElementById("slider-lp-history")
		if sliderLpHist and uiState.draggingSlider ~= "lp-history" then
			uiState.updatingFromCode = true
			local totalSteps = (lpState.undoCount or 0) + (lpState.redoCount or 0)
			local maxVal = math.min(totalSteps, 400)
			if maxVal < 1 then maxVal = 1 end
			sliderLpHist:SetAttribute("max", tostring(maxVal))
			sliderLpHist:SetAttribute("value", tostring(lpState.undoCount or 0))
			uiState.updatingFromCode = false
		end

		-- Globe orientation indicator sync
		local globeInd = doc and doc:GetElementById("lp-orient-indicator")
		if globeInd then
			local p = math.rad(lpState.pitch)
			local y = math.rad(lpState.yaw)
			local nx = math.cos(p) * math.sin(y)
			local ny = -(math.cos(p) * math.cos(y))
			local len = math.sqrt(nx * nx + ny * ny)
			if len > 1 then nx = nx / len; ny = ny / len end
			-- Globe R=41dp (100dp globe, 14dp indicator: center=50, half-ind=7, margin=2 → 50-7-2=41)
			local left = 43 + nx * 41
			local top  = 43 + ny * 41
			globeInd:SetAttribute("style", string.format("left: %.1fdp; top: %.1fdp;", left, top))
		end
		-- Pitch / Yaw numbox sync (skip while user is typing)
		local pitchInp = doc and doc:GetElementById("lp-orient-pitch-input")
		if pitchInp and widgetState.focusedRmlInput ~= pitchInp then
			pitchInp:SetAttribute("value", tostring(math.floor(lpState.pitch)))
		end
		local yawInp = doc and doc:GetElementById("lp-orient-yaw-input")
		if yawInp and widgetState.focusedRmlInput ~= yawInp then
			yawInp:SetAttribute("value", tostring(math.floor(lpState.yaw)))
		end

		setSummary("LIGHTS", "#fbbf24",
			"", (lpState.lightType or "point"):upper(),
			"Bright ", string.format("%.1f", lpState.brightness or 1),
			"Rad ", tostring(lpState.lightRadius or 200),
			"Elev ", tostring(lpState.elevation or 100))

		-- P3.2 Lights grayouts (per Phase 3 relevance matrix)
		if doc and ctx.setDisabledIds then
			local mode = lpState.mode or "point"
			local remove = (mode == "remove")
			local scatter = (mode == "scatter")
			-- Color/brightness/elevation: disabled in remove
			ctx.setDisabledIds(doc, {
				"slider-lp-brightness", "slider-lp-brightness-numbox",
				"slider-lp-elevation", "slider-lp-elevation-numbox",
				"slider-lp-color-r", "slider-lp-color-r-numbox",
				"slider-lp-color-g", "slider-lp-color-g-numbox",
				"slider-lp-color-b", "slider-lp-color-b-numbox",
			}, remove)
			-- Count/cadence: scatter only
			ctx.setDisabledIds(doc, {
				"slider-lp-count", "slider-lp-count-numbox",
				"slider-lp-cadence", "slider-lp-cadence-numbox",
			}, not scatter)
			-- Brush radius (pick/scatter radius): irrelevant in point mode
			ctx.setDisabledIds(doc, {
				"slider-lp-brush-radius", "slider-lp-brush-radius-numbox",
			}, mode == "point")
		end

end

return M
