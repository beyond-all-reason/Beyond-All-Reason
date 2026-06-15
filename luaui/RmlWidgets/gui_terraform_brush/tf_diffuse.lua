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
	widgetState.dfpLastLayerSig = nil

	-- Slider drag tracking only; section collapse for dfp-* frames is wired
	-- centrally in tf_environment.lua (envSectionToggle) like every other tool.
	for _, entry in ipairs({
		{ "dfp-slider-radius",          "dfp-radius" },
		{ "dfp-slider-strength",        "dfp-strength" },
		{ "dfp-slider-curve",           "dfp-curve" },
		{ "dfp-slider-fractal",         "dfp-fractal" },
		{ "dfp-slider-fractal-freq",    "dfp-fractal-freq" },
		{ "dfp-slider-history",         "dfp-history" },
		{ "dfp-slider-specint",         "dfp-specint" },
		{ "dfp-slider-glow",            "dfp-glow" },
		{ "dfp-slider-grass",           "dfp-grass" },
		{ "dfp-slider-hydro-strength",  "dfp-hydro-strength" },
		{ "dfp-slider-hydro-flo",       "dfp-hydro-flo" },
		{ "dfp-slider-hydro-fhi",       "dfp-hydro-fhi" },
		{ "dfp-slider-thermo-angle",    "dfp-thermo-angle" },
		{ "dfp-slider-thermo-falloff",  "dfp-thermo-falloff" },
	}) do
		local sliderEl = doc:GetElementById(entry[1])
		if sliderEl and trackSliderDrag then trackSliderDrag(sliderEl, entry[2]) end
	end
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

-- Layer names come from material basenames; keep the one-line summary readable
-- if a long custom name sneaks in.
local function shortName(name, maxLen)
	name = tostring(name or "-")
	if #name > maxLen then return name:sub(1, maxLen - 1) .. "…" end
	return name
end

function M.sync(doc, ctx, dfpState, setSummary)
	local widgetState = ctx.widgetState
	local uiState = ctx.uiState
	local syncAndFlash = ctx.syncAndFlash
	if not dfpState or not WG.DiffusePainter then return end

	local layers   = dfpState.layers or {}
	local activeId = dfpState.activeLayerId

	-- Rebuild layer list only when needed
	local sig = buildSig(layers, activeId)
	if sig ~= widgetState.dfpLastLayerSig then
		widgetState.dfpLastLayerSig = sig
		rebuildLayerList(doc, ctx, layers, activeId)
	end

	-- Resolve the active layer (used for DM labels and slider sync below)
	local activeLayer = nil
	for i = 1, #layers do if layers[i].id == activeId then activeLayer = layers[i] break end end

	-- DM labels for brush + active layer
	local dm = widgetState.dmHandle
	if dm then
		local radiusStr   = tostring(dfpState.radius or 128)
		local strengthStr = string.format("%.2f", dfpState.strength or 1.0)
		local curveStr    = string.format("%.1f", dfpState.curve or 1.5)
		if dm.dfpRadiusStr   ~= radiusStr   then dm.dfpRadiusStr   = radiusStr   end
		if dm.dfpStrengthStr ~= strengthStr then dm.dfpStrengthStr = strengthStr end
		if dm.dfpCurveStr    ~= curveStr    then dm.dfpCurveStr    = curveStr    end
		if dm.dfpErase       ~= (dfpState.erase == true) then dm.dfpErase = (dfpState.erase == true) end

		local activeName = shortName(activeLayer and activeLayer.name or "", 28)
		if dm.dfpActiveLayerName ~= activeName then dm.dfpActiveLayerName = activeName end

		-- Fractal brush
		do
			local amt, freq = dfpState.fractalAmount, dfpState.fractalFreq
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

		-- SSMF material channels
		local chN = dfpState.channelNormals  and true or false
		local chS = dfpState.channelSpecular and true or false
		local chE = dfpState.channelEmission and true or false
		if dm.dfpChNormals  ~= chN then dm.dfpChNormals  = chN end
		if dm.dfpChSpecular ~= chS then dm.dfpChSpecular = chS end
		if dm.dfpChEmission ~= chE then dm.dfpChEmission = chE end
		local specIntStr = tostring(math.floor((dfpState.specIntensity or 0.25) * 100 + 0.5))
		if dm.dfpSpecIntStr ~= specIntStr then dm.dfpSpecIntStr = specIntStr end
		local glowStr = tostring(math.floor(((activeLayer and activeLayer.glowStrength) or 0) * 100 + 0.5))
		if dm.dfpGlowStr ~= glowStr then dm.dfpGlowStr = glowStr end

		-- Grass attach
		local gAttach = dfpState.grassAttach and true or false
		if dm.dfpGrassAttach ~= gAttach then dm.dfpGrassAttach = gAttach end
		local grassStr = tostring(math.floor(((activeLayer and activeLayer.grassDensity) or 0) * 100 + 0.5))
		if dm.dfpGrassStr ~= grassStr then dm.dfpGrassStr = grassStr end

		-- Warn chips: effects when blend/hydro/thermo/channels engaged; layers
		-- when more than the starter layer exists (visible only while collapsed).
		local effectsActive = hydroEn or thermoEn or (blendStr ~= "normal") or chN or chS or chE
		if doc and ctx.syncWarnChip then
			ctx.syncWarnChip(doc, "warn-chip-dfp-effects", "section-dfp-effects", effectsActive)
			ctx.syncWarnChip(doc, "warn-chip-dfp-layers", "section-dfp-layers", #layers > 1)
		end
	end

	-- Sliders
	if doc then
		uiState.updatingFromCode = true
		local getCachedEl = ctx.getCachedEl
		syncAndFlash(getCachedEl(doc, "dfp-slider-radius"),   "dfp-radius",   tostring(dfpState.radius or 128))
		syncAndFlash(getCachedEl(doc, "dfp-slider-strength"), "dfp-strength", tostring(math.floor((dfpState.strength or 1.0) * 100 + 0.5)))
		syncAndFlash(getCachedEl(doc, "dfp-slider-curve"),    "dfp-curve",    tostring(math.floor((dfpState.curve or 1.5) * 10 + 0.5)))
		do
			local amt, freq = dfpState.fractalAmount, dfpState.fractalFreq
			syncAndFlash(getCachedEl(doc, "dfp-slider-fractal"), "dfp-fractal", tostring(math.floor((amt or 0) * 100 + 0.5)))
			local freqSlider = math.floor(1 + ((freq or 0.003) - 0.0002) / (0.01 - 0.0002) * 49 + 0.5)
			freqSlider = math.max(1, math.min(50, freqSlider))
			syncAndFlash(getCachedEl(doc, "dfp-slider-fractal-freq"), "dfp-fractal-freq", tostring(freqSlider))
		end

		-- Channel sliders
		syncAndFlash(getCachedEl(doc, "dfp-slider-specint"), "dfp-specint", tostring(math.floor((dfpState.specIntensity or 0.25) * 100 + 0.5)))
		if activeLayer then
			syncAndFlash(getCachedEl(doc, "dfp-slider-glow"), "dfp-glow", tostring(math.floor((activeLayer.glowStrength or 0) * 100 + 0.5)))
			syncAndFlash(getCachedEl(doc, "dfp-slider-grass"), "dfp-grass", tostring(math.floor((activeLayer.grassDensity or 0) * 100 + 0.5)))
		end

		-- History slider sync (same shape as tf_grass)
		do
			local histIdx = dfpState.historyIndex or 0
			local histMax = dfpState.historyMax or 0
			local slH = getCachedEl(doc, "dfp-slider-history")
			if slH then
				slH:SetAttribute("max", tostring(histMax))
				syncAndFlash(slH, "dfp-history", tostring(histIdx))
			end
			local numH = getCachedEl(doc, "dfp-slider-history-numbox")
			if numH then numH:SetAttribute("value", tostring(histIdx)) end
		end
		if activeLayer then
			local hs = math.floor((activeLayer.hydroStrength or 0.02) * 1000 + 0.5)
			syncAndFlash(getCachedEl(doc, "dfp-slider-hydro-strength"), "dfp-hydro-strength", tostring(hs))
			local hlo = math.floor((activeLayer.hydroFalloffLo or 0.1) * 100 + 0.5)
			syncAndFlash(getCachedEl(doc, "dfp-slider-hydro-flo"), "dfp-hydro-flo", tostring(hlo))
			local hhi = math.floor((activeLayer.hydroFalloffHi or 0.6) * 100 + 0.5)
			syncAndFlash(getCachedEl(doc, "dfp-slider-hydro-fhi"), "dfp-hydro-fhi", tostring(hhi))
			syncAndFlash(getCachedEl(doc, "dfp-slider-thermo-angle"),   "dfp-thermo-angle",   tostring(math.floor(activeLayer.thermoAngle  or 30)))
			syncAndFlash(getCachedEl(doc, "dfp-slider-thermo-falloff"), "dfp-thermo-falloff", tostring(math.floor(activeLayer.thermoFalloff or 8)))
		end
		uiState.updatingFromCode = false
	end

	if setSummary then
		setSummary("DIFFUSE", "#e8b96b",
			"", shortName(activeLayer and activeLayer.name, 18),
			"R ", tostring(dfpState.radius or 128),
			"Str ", string.format("%d%%", math.floor((dfpState.strength or 0.6) * 100 + 0.5)),
			"", dfpState.erase and "ERASE" or "PAINT")
	end
end

return M
