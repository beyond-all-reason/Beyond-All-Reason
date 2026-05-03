-- tf_lights.lua: extracted tool module for gui_terraform_brush
local M = {}

-- Color palette (shared by swatch click handler + guideHints population).
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

function M.attach(doc, ctx)
	if ctx.attachTBMirrorControls then ctx.attachTBMirrorControls(doc, "lp") end
	local widgetState = ctx.widgetState
	local uiState = ctx.uiState
	local WG = ctx.WG
	local playSound = ctx.playSound
	local trackSliderDrag = ctx.trackSliderDrag
	local guideHints = ctx.guideHints
	local GetMouseState = Spring.GetMouseState
	local TraceScreenRay = Spring.TraceScreenRay
	-- ============ Light Placer controls ============

	widgetState.lightControlsEl = doc:GetElementById("tf-light-controls")

	-- Slider drag tracking (legitimate imperative: slider-specific drag state).
	-- Slider change events are wired declaratively via onchange= in RML.
	for _, sid in ipairs({
		"lp-color-r", "lp-color-g", "lp-color-b",
		"lp-brightness", "lp-light-radius", "lp-elevation",
		"lp-theta", "lp-beam-length",
		"lp-count", "lp-brush-radius", "lp-history",
	}) do
		local sl = doc:GetElementById("slider-" .. sid)
		if sl then trackSliderDrag(sl, sid) end
	end
	for _, entry in ipairs({
		{ "lp-slider-symmetry-radial-count", "lp-symmetry-radial-count" },
		{ "lp-slider-symmetry-mirror-angle", "lp-symmetry-mirror-angle" },
	}) do
		local sl = doc:GetElementById(entry[1])
		if sl then trackSliderDrag(sl, entry[2]) end
	end

	-- Populate per-swatch guide hints (click handlers wired declaratively in RML).
	for idx, c in ipairs(PALETTE) do
		guideHints["lp-swatch-" .. idx] = c[5] .. " " .. c[4]
	end

	-- ============ Light Library floating window ============
	-- Dynamic preset lists remain imperative (Phase 3 defers data-for binding).
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
		-- Bind click events after populating (dynamic per-item closures: legitimate imperative)
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

	-- ============ Hemisphere orientation globe (pitch/yaw interactive) ============
	-- Legitimate imperative: drag mousedown/move/up + SDL focus/blur on numboxes.
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

	-- Pitch/Yaw direct-entry numboxes (SDL text input legitimately imperative)
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

	-- Store palette + populate helpers in widgetState for model-king handlers in initialModel.
	-- Recoil forbids adding/replacing function keys after OpenDataModel (all onLp*/onLl*
	-- handlers are defined there, not here).
	widgetState.lpPalette = PALETTE
	widgetState.lpPopulateBuiltinPresets = populateBuiltinPresets
	widgetState.lpPopulateUserPresets = populateUserPresets
end

function M.sync(doc, ctx, lpState, setSummary)
	if ctx.syncTBMirrorControls then ctx.syncTBMirrorControls(doc, "lp") end
	local widgetState = ctx.widgetState
	local uiState = ctx.uiState
	local WG = ctx.WG
	local syncAndFlash = ctx.syncAndFlash
	local cadenceToSlider = ctx.cadenceToSlider
	local shapeNames = ctx.shapeNames
		-- btn-lights active state driven by data-class-active="activeTool == 'lp'" in RML.

		-- Light type/mode/dist buttons driven by dm.lpLightType/lpMode/lpDistMode (data-class-active).
		-- Sync shape button active state to LightPlacer's shape
		if widgetState.dmHandle then widgetState.dmHandle.activeShape = lpState.shape or "circle" end
		-- Show/hide direction/theta/beam/scatter sections via dm flags (data-if in RML)
		local dm = widgetState.dmHandle
		if dm then
			dm.lpLightType = lpState.lightType or "point"
			dm.lpMode = lpState.mode or "place"
			local dist = lpState.distribution or "random"
			if dm.lpDistMode ~= dist then dm.lpDistMode = dist end
			local tbs = WG.TerraformBrush and WG.TerraformBrush.getState and WG.TerraformBrush.getState() or {}
			dm.lpSymmetryRadial = tbs.symmetryRadial and true or false
			dm.lpSymmetryMirrorAny = (tbs.symmetryMirrorX or tbs.symmetryMirrorY) and true or false
			local cs = tostring(tbs.symmetryRadialCount or 2)
			if dm.lpSymCountStr ~= cs then dm.lpSymCountStr = cs end
			local as = tostring(math.floor(tbs.symmetryMirrorAngle or 0))
			if dm.lpSymAngleStr ~= as then dm.lpSymAngleStr = as end
		end
		-- Gray out scatter + distribution for cone/beam (they only support single placement)
		local directedLight = lpState.lightType == "cone" or lpState.lightType == "beam"
		if directedLight and lpState.mode == "scatter" then
			if WG.LightPlacer then WG.LightPlacer.setMode("point") end
		end
		-- data-class-lp-unavailable="lpDirectedLight" drives grayout in RML.
		if dm and dm.lpDirectedLight ~= directedLight then dm.lpDirectedLight = directedLight end
		-- Update distribution buttons (data-class-active="lpDistMode == 'X'" drives active class)
		-- Labels driven by {{lpBrightnessStr}}/{{lpLightRadiusStr}}/{{lpElevationStr}}/{{lpCountStr}}/{{lpBrushRadiusStr}} in RML.
		if widgetState.dmHandle then
			local dm = widgetState.dmHandle
			local v = string.format("%.1f", lpState.brightness)
			if dm.lpBrightnessStr ~= v then dm.lpBrightnessStr = v end
			v = tostring(math.floor(lpState.lightRadius))
			if dm.lpLightRadiusStr ~= v then dm.lpLightRadiusStr = v end
			v = tostring(math.floor(lpState.elevation))
			if dm.lpElevationStr ~= v then dm.lpElevationStr = v end
			v = tostring(lpState.lightCount)
			if dm.lpCountStr ~= v then dm.lpCountStr = v end
			v = tostring(math.floor(lpState.radius))
			if dm.lpBrushRadiusStr ~= v then dm.lpBrushRadiusStr = v end
		end
		-- Sync slider+numbox values for state that can mutate outside the UI
		-- (Ctrl+Scroll = brush radius, Shift+Scroll = elevation, Space+Scroll =
		-- brightness, Alt+Scroll = yaw, R/G/B+Scroll = color channels, etc.)
		-- syncAndFlash is guarded against the user's active drag on that slider.
		if syncAndFlash then
			uiState.updatingFromCode = true
			syncAndFlash(doc:GetElementById("slider-lp-brush-radius"),  "lp-brush-radius",  tostring(math.floor(lpState.radius)))
			syncAndFlash(doc:GetElementById("slider-lp-brightness"),    "lp-brightness",    tostring(math.floor(lpState.brightness * 100 + 0.5)))
			syncAndFlash(doc:GetElementById("slider-lp-light-radius"),  "lp-light-radius",  tostring(math.floor(lpState.lightRadius)))
			syncAndFlash(doc:GetElementById("slider-lp-elevation"),     "lp-elevation",     tostring(math.floor(lpState.elevation)))
			syncAndFlash(doc:GetElementById("slider-lp-count"),         "lp-count",         tostring(lpState.lightCount))
			syncAndFlash(doc:GetElementById("slider-lp-color-r"),       "lp-color-r",       tostring(math.floor((lpState.color[1] or 0) * 1000 + 0.5)))
			syncAndFlash(doc:GetElementById("slider-lp-color-g"),       "lp-color-g",       tostring(math.floor((lpState.color[2] or 0) * 1000 + 0.5)))
			syncAndFlash(doc:GetElementById("slider-lp-color-b"),       "lp-color-b",       tostring(math.floor((lpState.color[3] or 0) * 1000 + 0.5)))
			do
				local tbs = WG.TerraformBrush and WG.TerraformBrush.getState and WG.TerraformBrush.getState() or {}
				syncAndFlash(doc:GetElementById("lp-slider-symmetry-radial-count"), "lp-symmetry-radial-count", tostring(tbs.symmetryRadialCount or 2))
				syncAndFlash(doc:GetElementById("lp-slider-symmetry-mirror-angle"), "lp-symmetry-mirror-angle", tostring(math.floor(tbs.symmetryMirrorAngle or 0)))
			end
			local setNum = function(id, v)
				local el = doc:GetElementById(id)
				if el then el:SetAttribute("value", v) end
			end
			setNum("slider-lp-brush-radius-numbox", tostring(math.floor(lpState.radius)))
			setNum("slider-lp-brightness-numbox",   tostring(lpState.brightness))
			setNum("slider-lp-light-radius-numbox", tostring(math.floor(lpState.lightRadius)))
			setNum("slider-lp-elevation-numbox",    tostring(math.floor(lpState.elevation)))
			setNum("slider-lp-count-numbox",        tostring(lpState.lightCount))
			setNum("slider-lp-color-r-numbox",      tostring(lpState.color[1]))
			setNum("slider-lp-color-g-numbox",      tostring(lpState.color[2]))
			setNum("slider-lp-color-b-numbox",      tostring(lpState.color[3]))
			uiState.updatingFromCode = false
		end
		-- Color preview (live background-color via SetAttribute, no label span in RML)
		local colorPreview = doc and doc:GetElementById("lp-color-preview")
		if colorPreview then
			local cr = math.floor(lpState.color[1] * 255)
			local cg = math.floor(lpState.color[2] * 255)
			local cb = math.floor(lpState.color[3] * 255)
			colorPreview:SetAttribute("style", string.format("background-color: #%02x%02x%02x;", cr, cg, cb))
		end
		-- Placed count driven by {{lpPlacedCountStr}} in RML.
		if widgetState.dmHandle and WG.LightPlacer then
			local v = tostring(WG.LightPlacer.getPlacedCount())
			if widgetState.dmHandle.lpPlacedCountStr ~= v then widgetState.dmHandle.lpPlacedCountStr = v end
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
			-- Globe R=41dp (100dp globe, 14dp indicator: center=50, half-ind=7, margin=2 â†’ 50-7-2=41)
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
