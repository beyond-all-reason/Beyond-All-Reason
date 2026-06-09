-- tf_diffuse.lua: Diffuse Painter tool UI module for gui_terraform_brush
-- Phase A MVP: brush sliders (handled declaratively) + imperative layer list.
local M = {}

-- Capture WG as a module-level upvalue. RmlUi-dispatched event closures may
-- execute outside the host widget's global env, so referring to the global
-- `WG` from inside an AddEventListener body throws "attempt to index global
-- 'WG' (a nil value)". The upvalue capture sidesteps that.
local WG = WG

local function _rgbCss(c)
	local r = math.floor(((c and c[1]) or 1) * 255 + 0.5)
	local g = math.floor(((c and c[2]) or 1) * 255 + 0.5)
	local b = math.floor(((c and c[3]) or 1) * 255 + 0.5)
	return string.format("rgb(%d,%d,%d)", r, g, b)
end

function M.attach(doc, ctx)
	local widgetState = ctx.widgetState
	local trackSliderDrag = ctx.trackSliderDrag

	widgetState.dfpControlsEl   = doc:GetElementById("tf-diff-controls")
	widgetState.dfpLayerListEl  = doc:GetElementById("dfp-layer-list")
	widgetState.dfpMaterialListEl = doc:GetElementById("dfp-material-list")
	widgetState.dfpLastLayerSig = nil
	widgetState.dfpLastMatSig   = nil

	for _, entry in ipairs({
		{ "dfp-slider-radius",          "dfp-radius" },
		{ "dfp-slider-strength",        "dfp-strength" },
		{ "dfp-slider-curve",           "dfp-curve" },
		{ "dfp-slider-fractal",         "dfp-fractal" },
		{ "dfp-slider-fractal-freq",    "dfp-fractal-freq" },
		{ "dfp-slider-hydro-strength",  "dfp-hydro-strength" },
		{ "dfp-slider-hydro-flo",       "dfp-hydro-flo" },
		{ "dfp-slider-hydro-fhi",       "dfp-hydro-fhi" },
		{ "dfp-slider-thermo-angle",    "dfp-thermo-angle" },
		{ "dfp-slider-thermo-falloff",  "dfp-thermo-falloff" },
	}) do
		local sliderEl = doc:GetElementById(entry[1])
		if sliderEl and trackSliderDrag then trackSliderDrag(sliderEl, entry[2]) end
	end

	-- Wire collapse buttons for diffuse-specific sections.
	-- Reuse the same pattern as tf_environment.lua (envSectionToggle).
	local function dfpSectionToggle(btnId, imgId, sectionId, defaultExpanded)
		local btnEl  = doc:GetElementById(btnId)
		local imgEl  = doc:GetElementById(imgId)
		local secEl  = doc:GetElementById(sectionId)
		if not (btnEl and secEl) then return end
		local expanded = defaultExpanded ~= false
		local function apply()
			if expanded then
				secEl:SetAttribute("style", "display: block;")
				if imgEl then imgEl:SetAttribute("src", "/luaui/images/terraform_brush/minus.png") end
			else
				secEl:SetAttribute("style", "display: none;")
				if imgEl then imgEl:SetAttribute("src", "/luaui/images/terraform_brush/plus.png") end
			end
		end
		apply()
		btnEl:AddEventListener("mousedown", function(_ev)
			expanded = not expanded
			apply()
		end, false)
	end

	dfpSectionToggle("btn-toggle-dfp-brush",   "img-toggle-dfp-brush",   "section-dfp-brush",   true)
	dfpSectionToggle("btn-toggle-dfp-effects", "img-toggle-dfp-effects", "section-dfp-effects", false)
	dfpSectionToggle("btn-toggle-dfp-layers",  "img-toggle-dfp-layers",  "section-dfp-layers",  true)
	dfpSectionToggle("btn-toggle-dfp-materials", "img-toggle-dfp-materials", "section-dfp-materials", false)
	dfpSectionToggle("btn-toggle-dfp-actions", "img-toggle-dfp-actions", "section-dfp-actions", false)
end

-- Build a signature of the current layer stack so we can detect when the list
-- needs imperative rebuild (add/remove/enable/active/color change).
local function buildSig(layers, activeId)
	local parts = {}
	for i = 1, #layers do
		local layer = layers[i]
		parts[#parts + 1] = string.format("%d:%s:%s:%.2f:%.2f:%.2f:%.2f:%s:%s",
			layer.id or 0,
			tostring(layer.name or ""),
			layer.enabled and "1" or "0",
			(layer.color and layer.color[1]) or 0,
			(layer.color and layer.color[2]) or 0,
			(layer.color and layer.color[3]) or 0,
			layer.opacity or 0,
			tostring(layer.texturePath or ""),
			(activeId == layer.id) and "A" or "-")
	end
	return table.concat(parts, "|")
end

local function buildMatSig(library, activeLayer)
	local active = activeLayer and tostring(activeLayer.texturePath or "") or ""
	return tostring(#library) .. "#" .. active
end

local function rebuildLayerList(doc, ctx, layers, activeId)
	local widgetState = ctx.widgetState
	local listEl = widgetState.dfpLayerListEl
	if not listEl then return end
	listEl.inner_rml = ""

	for i = 1, #layers do
		local layer = layers[i]
		local rowId = "dfp-row-" .. layer.id
		local row = doc:CreateElement("div")
		row:SetAttribute("id", rowId)
		row:SetClass("tf-overlay-chip", true)
		if activeId == layer.id then row:SetClass("active", true) end
		row:SetAttribute("style",
			"display: flex; flex-direction: row; align-items: center; gap: 6dp; padding: 4dp 6dp;")

		-- Color swatch
		local swatch = doc:CreateElement("div")
		swatch:SetAttribute("style",
			"width: 18dp; height: 18dp; background-color: " .. _rgbCss(layer.color) ..
			"; border: 1dp #000;")
		row:AppendChild(swatch)

		-- Enable toggle (checkbox icon)
		local enableImg = doc:CreateElement("img")
		enableImg:SetClass("tf-icon-sm", true)
		enableImg:SetAttribute("src", layer.enabled
			and "/luaui/images/terraform_brush/check_on.png"
			or  "/luaui/images/terraform_brush/check_off.png")
		enableImg:SetAttribute("style", "cursor: pointer;")
		enableImg:AddEventListener("mousedown", function(_event)
			if not WG.DiffusePainter then return end
			WG.DiffusePainter.setLayerParam(layer.id, "enabled", not layer.enabled)
		end, false)
		row:AppendChild(enableImg)

		-- Name
		local nameEl = doc:CreateElement("div")
		nameEl:SetClass("tf-overlay-chip-label", true)
		nameEl:SetAttribute("style", "flex: 1;")
		nameEl.inner_rml = tostring(layer.name or ("Layer " .. layer.id))
		row:AppendChild(nameEl)

		-- Opacity readout
		local opacityEl = doc:CreateElement("div")
		opacityEl:SetClass("text-sm", true)
		opacityEl:SetAttribute("style", "min-width: 32dp; text-align: right;")
		opacityEl.inner_rml = string.format("%d%%", math.floor((layer.opacity or 1) * 100 + 0.5))
		row:AppendChild(opacityEl)

		-- Whole row click = make active layer
		row:AddEventListener("mousedown", function(_event)
			-- Skip if the enable-checkbox handled it (target hit there has its
			-- own propagation; for safety we still always set active).
			if not WG.DiffusePainter then return end
			WG.DiffusePainter.setActiveLayer(layer.id)
		end, false)

		listEl:AppendChild(row)
	end
end

local function rebuildMaterialList(doc, ctx, library, activeLayerId)
	local listEl = ctx.widgetState.dfpMaterialListEl
	if not listEl then return end
	listEl.inner_rml = ""

	local activeLayer = nil
	local layers = WG.DiffusePainter and WG.DiffusePainter.getLayers and WG.DiffusePainter.getLayers() or {}
	for i = 1, #layers do if layers[i].id == activeLayerId then activeLayer = layers[i] break end end
	local activePath = activeLayer and activeLayer.texturePath or nil

	for i = 1, #library do
		local mat = library[i]
		local row = doc:CreateElement("div")
		row:SetAttribute("id", "dfp-mat-" .. mat.key)
		row:SetClass("tf-overlay-chip", true)
		if activePath == mat.path then row:SetClass("active", true) end
		row:SetAttribute("style",
			"display: flex; flex-direction: row; align-items: center; gap: 6dp; padding: 4dp 6dp; cursor: pointer;")

		local nameEl = doc:CreateElement("div")
		nameEl:SetClass("tf-overlay-chip-label", true)
		nameEl:SetAttribute("style", "flex: 1;")
		nameEl.inner_rml = mat.name
		row:AppendChild(nameEl)

		local resEl = doc:CreateElement("div")
		resEl:SetClass("text-sm", true)
		resEl.inner_rml = tostring(mat.resK) .. "k"
		row:AppendChild(resEl)

		row:AddEventListener("mousedown", function(_event)
			local API = WG.DiffusePainter
			if not API then return end
			local id = API.getActiveLayerId and API.getActiveLayerId()
			local currentLayers = API.getLayers and API.getLayers() or {}
			local activeLayer = nil
			if id then
				for j = 1, #currentLayers do
					if currentLayers[j].id == id then activeLayer = currentLayers[j] break end
				end
			end
			-- Smart routing: if the active layer has no material yet, assign
			-- this material to it (and rename). Otherwise spawn a new layer
			-- using this material so existing painted strokes are preserved.
			if activeLayer and (not activeLayer.texturePath or activeLayer.texturePath == "") then
				if API.setLayerTexture then API.setLayerTexture(id, mat.path, nil, mat.name) end
			else
				if API.addLayerFromMaterial then API.addLayerFromMaterial(mat.path, mat.name) end
			end
		end, false)

		listEl:AppendChild(row)
	end
end

function M.sync(doc, ctx, setSummary)
	local widgetState = ctx.widgetState
	local uiState = ctx.uiState
	local syncAndFlash = ctx.syncAndFlash
	if not WG.DiffusePainter then return end

	local layers   = WG.DiffusePainter.getLayers and WG.DiffusePainter.getLayers() or {}
	local activeId = WG.DiffusePainter.getActiveLayerId and WG.DiffusePainter.getActiveLayerId()

	-- Rebuild layer list only when needed
	local sig = buildSig(layers, activeId)
	if sig ~= widgetState.dfpLastLayerSig then
		widgetState.dfpLastLayerSig = sig
		rebuildLayerList(doc, ctx, layers, activeId)
	end

	-- Rebuild material list when active layer's texture changes or library size changes
	local library = WG.DiffusePainter.getMaterialLibrary and WG.DiffusePainter.getMaterialLibrary() or {}
	local activeLayer = nil
	for i = 1, #layers do if layers[i].id == activeId then activeLayer = layers[i] break end end
	local matSig = buildMatSig(library, activeLayer)
	if matSig ~= widgetState.dfpLastMatSig then
		widgetState.dfpLastMatSig = matSig
		rebuildMaterialList(doc, ctx, library, activeId)
	end

	-- DM labels for brush + active layer
	local dm = widgetState.dmHandle
	if dm then
		local radius, strength, curve, erase = WG.DiffusePainter.getBrush()
		local radiusStr   = tostring(radius or 128)
		local strengthStr = string.format("%.2f", strength or 1.0)
		local curveStr    = string.format("%.1f", curve or 1.5)
		if dm.dfpRadiusStr   ~= radiusStr   then dm.dfpRadiusStr   = radiusStr   end
		if dm.dfpStrengthStr ~= strengthStr then dm.dfpStrengthStr = strengthStr end
		if dm.dfpCurveStr    ~= curveStr    then dm.dfpCurveStr    = curveStr    end
		if dm.dfpErase       ~= (erase == true) then dm.dfpErase = (erase == true) end

		local activeName = ""
		for i = 1, #layers do
			if layers[i].id == activeId then activeName = layers[i].name or "" break end
		end
		if dm.dfpActiveLayerName ~= activeName then dm.dfpActiveLayerName = activeName end

		-- Fractal brush
		if WG.DiffusePainter.getFractal then
			local amt, freq = WG.DiffusePainter.getFractal()
			local fracStr = tostring(math.floor((amt or 0) * 100 + 0.5))
			if dm.dfpFractalStr ~= fracStr then dm.dfpFractalStr = fracStr end
			-- Freq 0.0002..0.01 → slider 1..50 (linear)
			local freqSlider = math.floor(1 + ((freq or 0.003) - 0.0002) / (0.01 - 0.0002) * 49 + 0.5)
			freqSlider = math.max(1, math.min(50, freqSlider))
			local freqStr = tostring(freqSlider)
			if dm.dfpFractalFreqStr ~= freqStr then dm.dfpFractalFreqStr = freqStr end
		end

		-- Blend mode for active layer
		local blendStr = (activeLayer and activeLayer.blend) or "normal"
		if dm.dfpBlend ~= blendStr then dm.dfpBlend = blendStr end

		-- Hydro/thermo for active layer
		local hydroEn = activeLayer and activeLayer.hydroEnabled and true or false
		if dm.dfpHydroEnabled ~= hydroEn then dm.dfpHydroEnabled = hydroEn end
		local hydroStr = tostring(math.floor(((activeLayer and activeLayer.hydroStrength) or 0.02) * 1000 + 0.5))
		if dm.dfpHydroStrStr ~= hydroStr then dm.dfpHydroStrStr = hydroStr end
		local hydroFloStr = tostring(math.floor(((activeLayer and activeLayer.hydroFalloffLo) or 0.1) * 100 + 0.5))
		if dm.dfpHydroFalloffLoStr ~= hydroFloStr then dm.dfpHydroFalloffLoStr = hydroFloStr end
		local hydroFhiStr = tostring(math.floor(((activeLayer and activeLayer.hydroFalloffHi) or 0.6) * 100 + 0.5))
		if dm.dfpHydroFalloffHiStr ~= hydroFhiStr then dm.dfpHydroFalloffHiStr = hydroFhiStr end

		local thermoEn = activeLayer and activeLayer.thermoEnabled and true or false
		if dm.dfpThermoEnabled ~= thermoEn then dm.dfpThermoEnabled = thermoEn end
		local thermoAngStr = tostring(math.floor((activeLayer and activeLayer.thermoAngle) or 30))
		if dm.dfpThermoAngleStr ~= thermoAngStr then dm.dfpThermoAngleStr = thermoAngStr end
		local thermoFallStr = tostring(math.floor((activeLayer and activeLayer.thermoFalloff) or 8))
		if dm.dfpThermoFalloffStr ~= thermoFallStr then dm.dfpThermoFalloffStr = thermoFallStr end

		-- Warn chip: active when blend is non-normal, or hydro/thermo is on
		local effectsActive = hydroEn or thermoEn or (blendStr ~= "normal")
		if doc and ctx.syncWarnChip then
			ctx.syncWarnChip(doc, "warn-chip-dfp-effects", "section-dfp-effects", effectsActive)
		end
	end

	-- Sliders
	if doc then
		uiState.updatingFromCode = true
		local radius, strength, curve = WG.DiffusePainter.getBrush()
		syncAndFlash(doc:GetElementById("dfp-slider-radius"),   "dfp-radius",   tostring(radius or 128))
		syncAndFlash(doc:GetElementById("dfp-slider-strength"), "dfp-strength", tostring(math.floor((strength or 1.0) * 100 + 0.5)))
		syncAndFlash(doc:GetElementById("dfp-slider-curve"),    "dfp-curve",    tostring(math.floor((curve or 1.5) * 10 + 0.5)))
		if WG.DiffusePainter.getFractal then
			local amt, freq = WG.DiffusePainter.getFractal()
			syncAndFlash(doc:GetElementById("dfp-slider-fractal"), "dfp-fractal", tostring(math.floor((amt or 0) * 100 + 0.5)))
			local freqSlider = math.floor(1 + ((freq or 0.003) - 0.0002) / (0.01 - 0.0002) * 49 + 0.5)
			freqSlider = math.max(1, math.min(50, freqSlider))
			syncAndFlash(doc:GetElementById("dfp-slider-fractal-freq"), "dfp-fractal-freq", tostring(freqSlider))
		end
		if activeLayer then
			local hs = math.floor((activeLayer.hydroStrength or 0.02) * 1000 + 0.5)
			syncAndFlash(doc:GetElementById("dfp-slider-hydro-strength"), "dfp-hydro-strength", tostring(hs))
			local hlo = math.floor((activeLayer.hydroFalloffLo or 0.1) * 100 + 0.5)
			syncAndFlash(doc:GetElementById("dfp-slider-hydro-flo"), "dfp-hydro-flo", tostring(hlo))
			local hhi = math.floor((activeLayer.hydroFalloffHi or 0.6) * 100 + 0.5)
			syncAndFlash(doc:GetElementById("dfp-slider-hydro-fhi"), "dfp-hydro-fhi", tostring(hhi))
			syncAndFlash(doc:GetElementById("dfp-slider-thermo-angle"),   "dfp-thermo-angle",   tostring(math.floor(activeLayer.thermoAngle  or 30)))
			syncAndFlash(doc:GetElementById("dfp-slider-thermo-falloff"), "dfp-thermo-falloff", tostring(math.floor(activeLayer.thermoFalloff or 8)))
		end
		uiState.updatingFromCode = false
	end

	if setSummary then
		local r, s, c, e = WG.DiffusePainter.getBrush()
		setSummary("Diffuse Painter", "#e8b96b",
			"Layer", tostring(activeLayer and activeLayer.name or "-"),
			"Size", tostring(r or 128),
			"Strength", string.format("%d%%", math.floor((s or 0.6) * 100 + 0.5)),
			"Mode", e and "Erase" or "Paint")
	end
end

return M
