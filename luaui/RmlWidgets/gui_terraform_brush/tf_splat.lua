-- tf_splat.lua: SPLAT painter controls of the terraform brush panel (attach + per-frame sync).
local M = {}

function M.attach(doc, ctx)
	local widgetState = ctx.widgetState
	local trackSliderDrag = ctx.trackSliderDrag

	widgetState.spPreviewEls = {
		doc:GetElementById("sp-ch1-preview"),
		doc:GetElementById("sp-ch2-preview"),
		doc:GetElementById("sp-ch3-preview"),
		doc:GetElementById("sp-ch4-preview"),
	}
	widgetState.spChannelSectionEl = doc:GetElementById("section-spl-channel")
	widgetState.spPreviewTextures = {}
	widgetState.spPreviewVerified = false

	-- Drag state needs a listener per slider; value changes come from data-event-change= in the RML.
	for _, entry in ipairs({
		{ "sp-slider-strength", "sp-strength" },
		{ "sp-slider-intensity", "sp-intensity" },
		{ "sp-slider-size", "sp-size" },
		{ "sp-slider-rotation", "sp-rotation" },
		{ "sp-slider-curve", "sp-curve" },
		{ "sp-slider-fractal", "sp-fractal" },
		{ "sp-slider-fractal-freq", "sp-fractal-freq" },
		{ "sp-slider-slope-max", "sp-slope-max" },
		{ "sp-slider-slope-min", "sp-slope-min" },
		{ "sp-slider-alt-min", "sp-alt-min" },
		{ "sp-slider-alt-max", "sp-alt-max" },
		{ "slider-sp-history", "sp-history" },
		{ "sp-slider-symmetry-radial-count", "sp-symmetry-radial-count" },
		{ "sp-slider-symmetry-mirror-angle", "sp-symmetry-mirror-angle" },
	}) do
		local sl = doc:GetElementById(entry[1])
		if sl then
			trackSliderDrag(sl, entry[2])
		end
	end
	-- The onSplXxx event handlers live in initialModel in gui_terraform_brush.lua:
	-- Recoil forbids adding or replacing function keys after OpenDataModel.
end

function M.sync(doc, ctx, spState, setSummary)
	if ctx.syncTBMirrorControls then
		ctx.syncTBMirrorControls(doc, "sp")
	end
	local widgetState = ctx.widgetState
	local uiState = ctx.uiState
	local WG = ctx.WG
	local syncAndFlash = ctx.syncAndFlash
	local getCachedEl = ctx.getCachedEl
	local shapeNames = ctx.shapeNames

	if widgetState.dmHandle then
		local shp = spState.shape or "circle"
		if widgetState.dmHandle.activeShape ~= shp then
			widgetState.dmHandle.activeShape = shp
		end
	end

	if doc then
		uiState.updatingFromCode = true
		local ds = uiState.draggingSlider

		local dm = widgetState.dmHandle
		if dm then
			-- Fractal edge warp; frequency 0.0002..0.01 maps linearly to slider 1..50.
			local fracStr = string.format("%.2f", spState.fractalAmount or 0)
			if dm.splatFractalStr ~= fracStr then
				dm.splatFractalStr = fracStr
			end
			local freq = spState.fractalFreq or 0.003
			local freqSlider = math.floor(1 + (freq - 0.0002) / (0.01 - 0.0002) * 49 + 0.5)
			freqSlider = math.max(1, math.min(50, freqSlider))
			local freqStr = tostring(freqSlider)
			if dm.splatFractalFreqStr ~= freqStr then
				dm.splatFractalFreqStr = freqStr
			end
		end

		if dm then
			local ch = spState.channel or 1
			if dm.spChannel ~= ch then
				dm.spChannel = ch
			end
		end

		syncAndFlash(
			getCachedEl(doc, "sp-slider-strength"),
			"sp-strength",
			tostring(math.floor(spState.strength * 100 + 0.5))
		)
		syncAndFlash(
			getCachedEl(doc, "sp-slider-intensity"),
			"sp-intensity",
			tostring(math.floor(spState.intensity * 10 + 0.5))
		)
		syncAndFlash(getCachedEl(doc, "sp-slider-size"), "sp-size", tostring(spState.radius))
		syncAndFlash(getCachedEl(doc, "sp-slider-rotation"), "sp-rotation", tostring(spState.rotationDeg))
		syncAndFlash(getCachedEl(doc, "sp-slider-curve"), "sp-curve", tostring(math.floor(spState.curve * 10 + 0.5)))
		syncAndFlash(
			getCachedEl(doc, "sp-slider-fractal"),
			"sp-fractal",
			tostring(math.floor((spState.fractalAmount or 0) * 100 + 0.5))
		)
		do
			local freq = spState.fractalFreq or 0.003
			local freqSlider = math.floor(1 + (freq - 0.0002) / (0.01 - 0.0002) * 49 + 0.5)
			freqSlider = math.max(1, math.min(50, freqSlider))
			syncAndFlash(getCachedEl(doc, "sp-slider-fractal-freq"), "sp-fractal-freq", tostring(freqSlider))
		end

		-- Smart filters
		do
			local sf = spState.smartFilters or {}
			local anyFilterOn = spState.smartEnabled == true
					and (sf.avoidWater or sf.avoidCliffs or sf.preferSlopes or sf.altMinEnable or sf.altMaxEnable)
					and true
				or false
			ctx.syncWarnChip(doc, "warn-chip-sp-smart", "section-sp-smart", anyFilterOn)
			if spState.smartFilters then
				local sf = spState.smartFilters
				-- Filter flags drive data-if rows in the RML.
				if widgetState.dmHandle then
					local setDm = ctx.setDm
					setDm("spAvoidCliffs", sf.avoidCliffs == true)
					setDm("spPreferSlopes", sf.preferSlopes == true)
					setDm("spAltMinEnable", sf.altMinEnable == true)
					setDm("spAltMaxEnable", sf.altMaxEnable == true)
				end
				-- Never set the slope/altitude chip "active" class here: wireVisibilityChip
				-- (tf_environment.lua) owns it as "section expanded", and a per-frame write
				-- fights the click toggle. The slope-mode sub-chips belong to wireMutexChipPair.
				if dm then
					local v = sf.avoidWater == true
					if dm.spAvoidWater ~= v then
						dm.spAvoidWater = v
					end
				end

				local spSSlopeMax = getCachedEl(doc, "sp-slider-slope-max")
				if spSSlopeMax and ds ~= "sp-slope-max" then
					spSSlopeMax:SetAttribute("value", tostring(sf.slopeMax))
				end

				local spSSlopeMin = getCachedEl(doc, "sp-slider-slope-min")
				if spSSlopeMin and ds ~= "sp-slope-min" then
					spSSlopeMin:SetAttribute("value", tostring(sf.slopeMin))
				end

				local altMinEnableBtn = getCachedEl(doc, "btn-sp-alt-min-enable")
				if altMinEnableBtn then
					altMinEnableBtn:SetAttribute(
						"src",
						sf.altMinEnable and "/luaui/images/terraform_brush/check_on.png"
							or "/luaui/images/terraform_brush/check_off.png"
					)
				end
				local spSAltMin = getCachedEl(doc, "sp-slider-alt-min")
				if spSAltMin and ds ~= "sp-alt-min" then
					spSAltMin:SetAttribute("value", tostring(sf.altMin))
				end

				local altMaxEnableBtn = getCachedEl(doc, "btn-sp-alt-max-enable")
				if altMaxEnableBtn then
					altMaxEnableBtn:SetAttribute(
						"src",
						sf.altMaxEnable and "/luaui/images/terraform_brush/check_on.png"
							or "/luaui/images/terraform_brush/check_off.png"
					)
				end
				local spSAltMax = getCachedEl(doc, "sp-slider-alt-max")
				if spSAltMax and ds ~= "sp-alt-max" then
					spSAltMax:SetAttribute("value", tostring(sf.altMax))
				end

				-- SAMPLE buttons light up while the brush samples height for that bound.
				local hsm = WG.TerraformBrush and (WG.TerraformBrush.getState() or {}).heightSamplingMode
				if dm then
					local minS = hsm == "spAltMin"
					if dm.spAltMinSample ~= minS then
						dm.spAltMinSample = minS
					end
					local maxS = hsm == "spAltMax"
					if dm.spAltMaxSample ~= maxS then
						dm.spAltMaxSample = maxS
					end
				end
			end
		end

		if spState.exportFormat and widgetState.dmHandle then
			local v = string.upper(spState.exportFormat)
			if widgetState.dmHandle.splatExportFmtStr ~= v then
				widgetState.dmHandle.splatExportFmtStr = v
			end
		end

		-- History slider: max = undo + redo depth, value = undo depth.
		do
			local undoCount = spState.undoCount or 0
			local redoCount = spState.redoCount or 0
			local total = undoCount + redoCount
			local spHistSlider = getCachedEl(doc, "slider-sp-history")
			if spHistSlider and ds ~= "sp-history" then
				spHistSlider:SetAttribute("max", tostring(total))
				spHistSlider:SetAttribute("value", tostring(undoCount))
			end
			local spHistNumbox = getCachedEl(doc, "slider-sp-history-numbox")
			if spHistNumbox then
				ctx.setInnerRmlIfChanged(spHistNumbox, "slider-sp-history-numbox", tostring(undoCount))
			end
		end

		uiState.updatingFromCode = false
	end

	-- Re-enable every shape button except ring: the panel's Update disables ring for this tool every frame.
	for shape, element in pairs(widgetState.shapeButtons) do
		if element and shape ~= "ring" then
			element:SetClass("disabled", false)
		end
	end

	do
		local toolLabel = "SPLAT"
		setSummary(
			toolLabel,
			"#fdc04c",
			"CH ",
			tostring(spState.channel or "?"),
			"",
			shapeNames[spState.shape] or "Circle",
			"R ",
			tostring(spState.radius or 0),
			"Str ",
			string.format("%.2f", spState.strength or 0),
			"Int ",
			string.format("%.1f", spState.intensity or 0)
		)
	end

	-- DISPLAY and INSTRUMENTS chips mirror the shared terraform brush state into
	-- data model flags (data-if rows and data-class-active chips in the RML).
	do
		local tb = WG.TerraformBrush
		if tb and tb.getState then
			local s = tb.getState()
			local dm = widgetState.dmHandle
			if dm then
				local setDm = ctx.setDm
				setDm("spGridSnap", s.gridSnap and true or false)
				setDm("spAngleSnap", s.angleSnap and true or false)
				setDm("spMeasureActive", s.measureActive and true or false)
				setDm("spSymmetryActive", s.symmetryActive and true or false)
				setDm("spSymmetryRadial", s.symmetryRadial and true or false)
				setDm("spSymHasAxis", (s.symmetryRadial or s.symmetryMirrorX or s.symmetryMirrorY) and true or false)
				setDm("spAngleSnapAuto", s.angleSnapAuto and true or false)
				setDm("spGridOverlay", s.gridOverlay and true or false)
				setDm("spHeightColormap", s.heightColormap and true or false)
				-- The splat map overlay is the splat painter's own state.
				local sp = WG.SplatPainter
				local spState = sp and sp.getState and sp.getState()
				setDm("spSplatOverlay", (spState and spState.showSplatOverlay) and true or false)
				setDm("spMeasureShowLength", s.measureShowLength and true or false)
				setDm("spSymMirrorX", s.symmetryMirrorX and true or false)
				setDm("spSymMirrorY", s.symmetryMirrorY and true or false)
			end
			-- Pulsing hint dot while DISPLAY is closed and the hint is not marked seen.
			do
				local tipsDisabled = widgetState.uiPrefs and widgetState.uiPrefs.disableTips
				local alreadySeen = widgetState.uiPrefs and widgetState.uiPrefs.seenSplatDisplayHint
				local sec = getCachedEl(doc, "section-sp-overlays")
				local hidden = tipsDisabled or alreadySeen or (sec and not sec:IsClassSet("hidden")) or false
				if dm and dm.spDisplayHintVisible ~= not hidden then
					dm.spDisplayHintVisible = not hidden
				end
			end
			-- Two-pulse highlight on the splat overlay chip once DISPLAY is opened.
			if widgetState.splatDisplayPulseFrame and Spring.GetGameFrame() >= widgetState.splatDisplayPulseFrame then
				widgetState.splatDisplayPulseFrame = nil
				local tipsDisabled = widgetState.uiPrefs and widgetState.uiPrefs.disableTips
				local splatChip = getCachedEl(doc, "btn-sp-splat-overlay")
				if splatChip and not tipsDisabled then
					splatChip:SetClass("tf-chip-2pulse", false)
					splatChip:SetClass("tf-chip-2pulse", true)
					widgetState.splatChip2PulseExpiry = (Spring.GetGameSeconds() or 0) + 1.25
				end
			end
			if
				widgetState.splatChip2PulseExpiry
				and (Spring.GetGameSeconds() or 0) >= widgetState.splatChip2PulseExpiry
			then
				widgetState.splatChip2PulseExpiry = nil
				local splatChip = getCachedEl(doc, "btn-sp-splat-overlay")
				if splatChip then
					splatChip:SetClass("tf-chip-2pulse", false)
				end
			end
			-- Instrument labels (grid size, symmetry, angle step) come from the shared
			-- tb* fields set by syncTBMirrorControls; only the manual spoke is ours.
			local step = s.angleSnapStep or 15
			local spokeStr = tostring(((s.angleSnapManualSpoke or 0) * step) % 360)
			if widgetState.dmHandle and widgetState.dmHandle.spManualSpokeStr ~= spokeStr then
				widgetState.dmHandle.spManualSpokeStr = spokeStr
			end
			uiState.updatingFromCode = true
			local nb = getCachedEl(doc, "sp-slider-grid-snap-size-numbox")
			if nb then
				nb:SetAttribute("value", tostring(s.gridSnapSize or 48))
			end
			-- syncTBMirrorControls("sp") writes these ids through a cache keyed by
			-- element id; update that cache after a direct write.
			local sz = getCachedEl(doc, "sp-slider-grid-snap-size")
			if sz and uiState.draggingSlider ~= "sp-grid-snap-size" then
				local szStr = tostring(s.gridSnapSize or 48)
				sz:SetAttribute("value", szStr)
				widgetState.lastAttrValue["sp-slider-grid-snap-size"] = szStr
			end
			local cntSlSp = getCachedEl(doc, "sp-slider-symmetry-radial-count")
			if cntSlSp then
				local cntStr = tostring(s.symmetryRadialCount or 2)
				cntSlSp:SetAttribute("value", cntStr)
				widgetState.lastAttrValue["sp-slider-symmetry-radial-count"] = cntStr
			end
			local angSlSp = getCachedEl(doc, "sp-slider-symmetry-mirror-angle")
			if angSlSp then
				local angStr = tostring(math.floor(s.symmetryMirrorAngle or 0))
				angSlSp:SetAttribute("value", angStr)
				widgetState.lastAttrValue["sp-slider-symmetry-mirror-angle"] = angStr
			end
			uiState.updatingFromCode = false
		end
	end

	-- Rotation does nothing on a circle.
	if doc and ctx.setDisabledIds then
		local circular = (spState.shape == "circle")
		ctx.setDisabledIds(doc, {
			"sp-slider-rotation",
			"sp-slider-rotation-numbox",
			"btn-sp-rot-ccw",
			"btn-sp-rot-cw",
		}, circular)
	end
end

return M
