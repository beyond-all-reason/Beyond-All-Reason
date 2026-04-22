-- tf_splat.lua: extracted tool module for gui_terraform_brush
local M = {}

function M.attach(doc, ctx)
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
	widgetState.spControlsEl = doc:GetElementById("tf-splat-controls")

	-- Splat channel buttons
	local spChannelButtons = {
		doc:GetElementById("btn-sp-ch1"),
		doc:GetElementById("btn-sp-ch2"),
		doc:GetElementById("btn-sp-ch3"),
		doc:GetElementById("btn-sp-ch4"),
	}
	for i, btn in ipairs(spChannelButtons) do
		if btn then
			btn:AddEventListener("click", function(event)
				playSound("modeSwitch")
				if WG.SplatPainter then WG.SplatPainter.setChannel(i) end
				for j, b in ipairs(spChannelButtons) do
					if b then b:SetClass("active", j == i) end
				end
				event:StopPropagation()
			end, false)
		end
	end

	-- Splat detail texture previews: discover per-layer texture names
	do
		widgetState.spPreviewEls = {
			doc:GetElementById("sp-ch1-preview"),
			doc:GetElementById("sp-ch2-preview"),
			doc:GetElementById("sp-ch3-preview"),
			doc:GetElementById("sp-ch4-preview"),
		}
		widgetState.spPreviewTextures = {}
		widgetState.spPreviewVerified = false
	end

	-- Splat strength slider + buttons
	local spSliderStrength = doc:GetElementById("sp-slider-strength")
	if spSliderStrength then
		trackSliderDrag(spSliderStrength, "sp-strength")
		spSliderStrength:AddEventListener("change", function(event)
			if not uiState.updatingFromCode and WG.SplatPainter then
				local val = tonumber(spSliderStrength:GetAttribute("value")) or 15
				WG.SplatPainter.setStrength(val / 100)
			end
			event:StopPropagation()
		end, false)
	end

	local spStrengthUp = doc:GetElementById("btn-sp-strength-up")
	if spStrengthUp then
		spStrengthUp:AddEventListener("click", function(event)
			if WG.SplatPainter then
				local st = WG.SplatPainter.getState()
				WG.SplatPainter.setStrength(st.strength + 0.05)
			end
			event:StopPropagation()
		end, false)
	end

	local spStrengthDown = doc:GetElementById("btn-sp-strength-down")
	if spStrengthDown then
		spStrengthDown:AddEventListener("click", function(event)
			if WG.SplatPainter then
				local st = WG.SplatPainter.getState()
				WG.SplatPainter.setStrength(st.strength - 0.05)
			end
			event:StopPropagation()
		end, false)
	end

	-- Splat intensity slider + buttons
	local spSliderIntensity = doc:GetElementById("sp-slider-intensity")
	if spSliderIntensity then
		trackSliderDrag(spSliderIntensity, "sp-intensity")
		spSliderIntensity:AddEventListener("change", function(event)
			if not uiState.updatingFromCode and WG.SplatPainter then
				local val = tonumber(spSliderIntensity:GetAttribute("value")) or 10
				WG.SplatPainter.setIntensity(val / 10)
			end
			event:StopPropagation()
		end, false)
	end

	local spIntensityUp = doc:GetElementById("btn-sp-intensity-up")
	if spIntensityUp then
		spIntensityUp:AddEventListener("click", function(event)
			if WG.SplatPainter then
				local st = WG.SplatPainter.getState()
				WG.SplatPainter.setIntensity(st.intensity + 0.1)
			end
			event:StopPropagation()
		end, false)
	end

	local spIntensityDown = doc:GetElementById("btn-sp-intensity-down")
	if spIntensityDown then
		spIntensityDown:AddEventListener("click", function(event)
			if WG.SplatPainter then
				local st = WG.SplatPainter.getState()
				WG.SplatPainter.setIntensity(st.intensity - 0.1)
			end
			event:StopPropagation()
		end, false)
	end

	-- Splat size slider + buttons
	local spSliderSize = doc:GetElementById("sp-slider-size")
	if spSliderSize then
		trackSliderDrag(spSliderSize, "sp-size")
		spSliderSize:AddEventListener("change", function(event)
			if not uiState.updatingFromCode and WG.SplatPainter then
				local val = tonumber(spSliderSize:GetAttribute("value")) or 100
				WG.SplatPainter.setRadius(val)
			end
			event:StopPropagation()
		end, false)
	end

	local spSizeUp = doc:GetElementById("btn-sp-size-up")
	if spSizeUp then
		spSizeUp:AddEventListener("click", function(event)
			if WG.SplatPainter then
				local st = WG.SplatPainter.getState()
				WG.SplatPainter.setRadius(st.radius + RADIUS_STEP)
			end
			event:StopPropagation()
		end, false)
	end

	local spSizeDown = doc:GetElementById("btn-sp-size-down")
	if spSizeDown then
		spSizeDown:AddEventListener("click", function(event)
			if WG.SplatPainter then
				local st = WG.SplatPainter.getState()
				WG.SplatPainter.setRadius(st.radius - RADIUS_STEP)
			end
			event:StopPropagation()
		end, false)
	end

	-- Splat rotation slider + buttons
	local spSliderRotation = doc:GetElementById("sp-slider-rotation")
	if spSliderRotation then
		trackSliderDrag(spSliderRotation, "sp-rotation")
		spSliderRotation:AddEventListener("change", function(event)
			if not uiState.updatingFromCode and WG.SplatPainter then
				local val = tonumber(spSliderRotation:GetAttribute("value")) or 0
				WG.SplatPainter.setRotation(val)
			end
			event:StopPropagation()
		end, false)
	end

	local spRotCW = doc:GetElementById("btn-sp-rot-cw")
	if spRotCW then
		spRotCW:AddEventListener("click", function(event)
			if WG.SplatPainter then WG.SplatPainter.rotate(ROTATION_STEP) end
			event:StopPropagation()
		end, false)
	end

	local spRotCCW = doc:GetElementById("btn-sp-rot-ccw")
	if spRotCCW then
		spRotCCW:AddEventListener("click", function(event)
			if WG.SplatPainter then WG.SplatPainter.rotate(-ROTATION_STEP) end
			event:StopPropagation()
		end, false)
	end

	-- Splat curve slider + buttons
	local spSliderCurve = doc:GetElementById("sp-slider-curve")
	if spSliderCurve then
		trackSliderDrag(spSliderCurve, "sp-curve")
		spSliderCurve:AddEventListener("change", function(event)
			if not uiState.updatingFromCode and WG.SplatPainter then
				local val = tonumber(spSliderCurve:GetAttribute("value")) or 10
				WG.SplatPainter.setCurve(val / 10)
			end
			event:StopPropagation()
		end, false)
	end

	local spCurveUp = doc:GetElementById("btn-sp-curve-up")
	if spCurveUp then
		spCurveUp:AddEventListener("click", function(event)
			if WG.SplatPainter then
				local st = WG.SplatPainter.getState()
				WG.SplatPainter.setCurve(st.curve + CURVE_STEP)
			end
			event:StopPropagation()
		end, false)
	end

	local spCurveDown = doc:GetElementById("btn-sp-curve-down")
	if spCurveDown then
		spCurveDown:AddEventListener("click", function(event)
			if WG.SplatPainter then
				local st = WG.SplatPainter.getState()
				WG.SplatPainter.setCurve(st.curve - CURVE_STEP)
			end
			event:StopPropagation()
		end, false)
	end

	-- Splat smart filter controls
	local function wireSpSmartToggle(btnId, filterKey)
		local btn = doc:GetElementById(btnId)
		if btn then
			btn:AddEventListener("click", function(event)
				if WG.SplatPainter then
					local sf = WG.SplatPainter.getState().smartFilters
					local newVal = not sf[filterKey]
					playSound(newVal and "toggleOn" or "toggleOff")
					WG.SplatPainter.setSmartFilter(filterKey, newVal)
					-- Auto-enable smart filter when any individual filter is turned on
					if newVal then WG.SplatPainter.setSmartEnabled(true) end
				end
				event:StopPropagation()
			end, false)
		end
	end
	wireSpSmartToggle("btn-sp-avoid-water",    "avoidWater")
	wireSpSmartToggle("btn-sp-avoid-cliffs",   "avoidCliffs")
	wireSpSmartToggle("btn-sp-prefer-slopes",  "preferSlopes")
	wireSpSmartToggle("btn-sp-alt-min-enable", "altMinEnable")
	wireSpSmartToggle("btn-sp-alt-max-enable", "altMaxEnable")

	local spSliderSlopeMax = doc:GetElementById("sp-slider-slope-max")
	if spSliderSlopeMax then
		trackSliderDrag(spSliderSlopeMax, "sp-slope-max")
		spSliderSlopeMax:AddEventListener("change", function(event)
			if not uiState.updatingFromCode and WG.SplatPainter then
				local val = tonumber(spSliderSlopeMax:GetAttribute("value")) or 45
				WG.SplatPainter.setSmartFilter("slopeMax", val)
			end
			event:StopPropagation()
		end, false)
	end

	local spSliderSlopeMin = doc:GetElementById("sp-slider-slope-min")
	if spSliderSlopeMin then
		trackSliderDrag(spSliderSlopeMin, "sp-slope-min")
		spSliderSlopeMin:AddEventListener("change", function(event)
			if not uiState.updatingFromCode and WG.SplatPainter then
				local val = tonumber(spSliderSlopeMin:GetAttribute("value")) or 10
				WG.SplatPainter.setSmartFilter("slopeMin", val)
			end
			event:StopPropagation()
		end, false)
	end

	local spSliderAltMin = doc:GetElementById("sp-slider-alt-min")
	if spSliderAltMin then
		trackSliderDrag(spSliderAltMin, "sp-alt-min")
		spSliderAltMin:AddEventListener("change", function(event)
			if not uiState.updatingFromCode and WG.SplatPainter then
				local val = tonumber(spSliderAltMin:GetAttribute("value")) or 0
				local sf = WG.SplatPainter.getState().smartFilters
				if sf.altMaxEnable and val > sf.altMax then
					WG.SplatPainter.setSmartFilter("altMax", val)
				end
				WG.SplatPainter.setSmartFilter("altMin", val)
			end
			event:StopPropagation()
		end, false)
	end

	local spSliderAltMax = doc:GetElementById("sp-slider-alt-max")
	if spSliderAltMax then
		trackSliderDrag(spSliderAltMax, "sp-alt-max")
		spSliderAltMax:AddEventListener("change", function(event)
			if not uiState.updatingFromCode and WG.SplatPainter then
				local val = tonumber(spSliderAltMax:GetAttribute("value")) or 200
				local sf = WG.SplatPainter.getState().smartFilters
				if sf.altMinEnable and val < sf.altMin then
					WG.SplatPainter.setSmartFilter("altMin", val)
				end
				WG.SplatPainter.setSmartFilter("altMax", val)
			end
			event:StopPropagation()
		end, false)
	end

	-- Splat painter smart filter +/- buttons
	do
		local function wireSpSmartBtn(btnId, filterKey, step)
			local btn = doc:GetElementById(btnId)
			if btn then
				btn:AddEventListener("click", function(event)
					if WG.SplatPainter then
						local sf = WG.SplatPainter.getState().smartFilters
						WG.SplatPainter.setSmartFilter(filterKey, (sf[filterKey] or 0) + step)
					end
					event:StopPropagation()
				end, false)
			end
		end
		wireSpSmartBtn("btn-sp-slope-max-up",   "slopeMax",  5)
		wireSpSmartBtn("btn-sp-slope-max-down", "slopeMax", -5)
		wireSpSmartBtn("btn-sp-slope-min-up",   "slopeMin",  5)
		wireSpSmartBtn("btn-sp-slope-min-down", "slopeMin", -5)
		wireSpSmartBtn("btn-sp-alt-min-up",     "altMin",   10)
		wireSpSmartBtn("btn-sp-alt-min-down",   "altMin",  -10)
		wireSpSmartBtn("btn-sp-alt-max-up",     "altMax",   10)
		wireSpSmartBtn("btn-sp-alt-max-down",   "altMax",  -10)
	end

	-- Splat export format toggle
	local spExportFmtBtn = doc:GetElementById("btn-sp-export-format")
	if spExportFmtBtn then
		spExportFmtBtn:AddEventListener("click", function(event)
			playSound("click")
			if WG.SplatPainter then WG.SplatPainter.cycleExportFormat() end
			event:StopPropagation()
		end, false)
	end

	-- Splat save button
	local spSaveBtn = doc:GetElementById("btn-sp-save")
	if spSaveBtn then
		spSaveBtn:AddEventListener("click", function(event)
			playSound("save")
			if WG.SplatPainter then WG.SplatPainter.saveSplats() end
			event:StopPropagation()
		end, false)
	end

	-- Splat undo/redo buttons and history slider
	do
		local spUndoBtn = doc:GetElementById("btn-sp-undo")
		if spUndoBtn then
			spUndoBtn:AddEventListener("click", function(event)
				playSound("click")
				if WG.SplatPainter then WG.SplatPainter.undo() end
				event:StopPropagation()
			end, false)
		end

		local spRedoBtn = doc:GetElementById("btn-sp-redo")
		if spRedoBtn then
			spRedoBtn:AddEventListener("click", function(event)
				playSound("click")
				if WG.SplatPainter then WG.SplatPainter.redo() end
				event:StopPropagation()
			end, false)
		end

		local spHistSlider = doc:GetElementById("slider-sp-history")
		if spHistSlider then
			spHistSlider:AddEventListener("change", function(event)
				if uiState.updatingFromCode then return end
				local spSt = WG.SplatPainter and WG.SplatPainter.getState()
				if not spSt then return end
				local newVal = tonumber(event.target:GetAttribute("value")) or 0
				local curPos = spSt.undoCount or 0
				local diff = newVal - curPos
				if diff < 0 then
					for _ = 1, -diff do
						WG.SplatPainter.undo()
					end
				elseif diff > 0 then
					for _ = 1, diff do
						WG.SplatPainter.redo()
					end
				end
				event:StopPropagation()
			end, false)
		end
	end

	-- ============================================================
	-- DISPLAY + INSTRUMENTS (mirrors tf_metal.lua pattern, prefix sp-)
	-- ============================================================
	do
		local function chipToggle(id, getter, setter)
			local el = doc:GetElementById(id)
			if not el then return end
			el:AddEventListener("click", function(ev)
				if WG.TerraformBrush then
					local newVal = not getter()
					playSound(newVal and "toggleOn" or "toggleOff")
					setter(newVal)
					el:SetClass("active", newVal)
				end
				ev:StopPropagation()
			end, false)
		end
		local function getTFState() return WG.TerraformBrush and WG.TerraformBrush.getState() or {} end

		-- DISPLAY: grid overlay + height colormap (shared TB state, drawn by terraform widget always)
		chipToggle("btn-sp-grid-overlay",
			function() return getTFState().gridOverlay end,
			function(v) WG.TerraformBrush.setGridOverlay(v) end)
		chipToggle("btn-sp-height-colormap",
			function() return getTFState().heightColormap end,
			function(v) WG.TerraformBrush.setHeightColormap(v) end)
		-- Splat Map overlay (channel-colorized world overlay, drawn by splat widget)
		local btnSplatOverlay = doc:GetElementById("btn-sp-splat-overlay")
		if btnSplatOverlay then
			btnSplatOverlay:AddEventListener("click", function(ev)
				local sp = WG.SplatPainter
				if sp then
					local newVal = not sp.getState().showSplatOverlay
					sp.setSplatOverlay(newVal)
					playSound(newVal and "toggleOn" or "toggleOff")
				end
				ev:StopPropagation()
			end, false)
		end

		-- INSTRUMENTS master chips
		local spSnapRow    = doc:GetElementById("sp-grid-snap-size-row")
		local spAngleRow   = doc:GetElementById("sp-angle-snap-step-row")
		local spMeasureRow = doc:GetElementById("sp-measure-toolbar-row")
		local spSymRow     = doc:GetElementById("sp-symmetry-toolbar-row")

		local spSnapBtn = doc:GetElementById("btn-sp-grid-snap")
		if spSnapBtn then
			spSnapBtn:AddEventListener("click", function(ev)
				if WG.TerraformBrush then
					local newVal = not getTFState().gridSnap
					playSound(newVal and "toggleOn" or "toggleOff")
					WG.TerraformBrush.setGridSnap(newVal)
					spSnapBtn:SetClass("active", newVal)
					if spSnapRow then spSnapRow:SetClass("hidden", not newVal) end
				end
				ev:StopPropagation()
			end, false)
		end
		local spMeasureBtn = doc:GetElementById("btn-sp-measure")
		if spMeasureBtn then
			spMeasureBtn:AddEventListener("click", function(ev)
				if WG.TerraformBrush then
					local newVal = not getTFState().measureActive
					playSound(newVal and "toggleOn" or "toggleOff")
					WG.TerraformBrush.setMeasureActive(newVal)
					spMeasureBtn:SetClass("active", newVal)
					if spMeasureRow then spMeasureRow:SetClass("hidden", not newVal) end
				end
				ev:StopPropagation()
			end, false)
		end

		-- Grid snap size slider
		local spSnapSlider = doc:GetElementById("sp-slider-grid-snap-size")
		if spSnapSlider then
			spSnapSlider:AddEventListener("change", function(ev)
				if uiState.updatingFromCode then ev:StopPropagation(); return end
				if WG.TerraformBrush then
					local v = tonumber(spSnapSlider:GetAttribute("value")) or 48
					WG.TerraformBrush.setGridSnapSize(v)
				end
				ev:StopPropagation()
			end, false)
		end
		local function spSnapStep(delta)
			if WG.TerraformBrush then
				local cur = tonumber(getTFState().gridSnapSize) or 48
				local v = math.max(16, math.min(128, cur + delta))
				WG.TerraformBrush.setGridSnapSize(v)
			end
		end
		local sd = doc:GetElementById("sp-btn-snap-size-down")
		if sd then sd:AddEventListener("click", function(ev) spSnapStep(-16); ev:StopPropagation() end, false) end
		local su = doc:GetElementById("sp-btn-snap-size-up")
		if su then su:AddEventListener("click", function(ev) spSnapStep(16); ev:StopPropagation() end, false) end

		-- Protractor (angle snap)
		local spAngleBtn = doc:GetElementById("btn-sp-angle-snap")
		if spAngleBtn then
			spAngleBtn:AddEventListener("click", function(ev)
				if WG.TerraformBrush then
					local newVal = not getTFState().angleSnap
					playSound(newVal and "toggleOn" or "toggleOff")
					WG.TerraformBrush.setAngleSnap(newVal)
					spAngleBtn:SetClass("active", newVal)
					if spAngleRow then spAngleRow:SetClass("hidden", not newVal) end
				end
				ev:StopPropagation()
			end, false)
		end
		local SP_ANGLE_PRESETS = {7.5, 15, 30, 45, 60, 90}
		local function spFindAnglePresetIdx(val)
			local best, bestD = 2, math.huge
			for i, p in ipairs(SP_ANGLE_PRESETS) do
				local d = math.abs(p - (val or 15))
				if d < bestD then bestD = d; best = i end
			end
			return best
		end
		local function spApplyAnglePreset(idx)
			idx = math.max(1, math.min(#SP_ANGLE_PRESETS, idx))
			local pval = SP_ANGLE_PRESETS[idx]
			local pstr = (pval == math.floor(pval)) and tostring(math.floor(pval)) or tostring(pval)
			if WG.TerraformBrush then WG.TerraformBrush.setAngleSnapStep(pval) end
			local sl = doc:GetElementById("sp-slider-angle-snap-step")
			if sl then sl:SetAttribute("value", tostring(idx - 1)) end
			local lbl = doc:GetElementById("sp-angle-snap-step-label")
			if lbl then lbl.inner_rml = pstr end
			local nb = doc:GetElementById("sp-slider-angle-snap-step-numbox")
			if nb then nb:SetAttribute("value", pstr) end
		end
		local spAngleSlider = doc:GetElementById("sp-slider-angle-snap-step")
		if spAngleSlider then
			spAngleSlider:AddEventListener("change", function(ev)
				if uiState.updatingFromCode then ev:StopPropagation(); return end
				local idx = (tonumber(spAngleSlider:GetAttribute("value")) or 1) + 1
				spApplyAnglePreset(idx)
				ev:StopPropagation()
			end, false)
		end
		local spStepDn = doc:GetElementById("sp-btn-angle-step-down")
		if spStepDn then spStepDn:AddEventListener("click", function(ev)
			if WG.TerraformBrush then spApplyAnglePreset(spFindAnglePresetIdx(getTFState().angleSnapStep) - 1) end
			ev:StopPropagation()
		end, false) end
		local spStepUp = doc:GetElementById("sp-btn-angle-step-up")
		if spStepUp then spStepUp:AddEventListener("click", function(ev)
			if WG.TerraformBrush then spApplyAnglePreset(spFindAnglePresetIdx(getTFState().angleSnapStep) + 1) end
			ev:StopPropagation()
		end, false) end
		local spAutoBtn = doc:GetElementById("sp-btn-angle-autosnap")
		if spAutoBtn then
			spAutoBtn:AddEventListener("click", function(ev)
				if WG.TerraformBrush then
					local newVal = not getTFState().angleSnapAuto
					playSound(newVal and "toggleOn" or "toggleOff")
					WG.TerraformBrush.setAngleSnapAuto(newVal)
					spAutoBtn:SetClass("active", newVal)
					local manualRow = doc:GetElementById("sp-angle-manual-spoke-row")
					if manualRow then manualRow:SetClass("hidden", newVal) end
				end
				ev:StopPropagation()
			end, false)
		end
		local spManualSlider = doc:GetElementById("sp-slider-manual-spoke")
		local function spApplyManualSpoke(idx)
			if WG.TerraformBrush then
				WG.TerraformBrush.setAngleSnapManualSpoke(idx)
				local step = getTFState().angleSnapStep or 15
				local deg  = (idx * step) % 360
				local lbl  = doc:GetElementById("sp-angle-manual-spoke-label")
				if lbl then lbl.inner_rml = tostring(deg) end
				if spManualSlider then spManualSlider:SetAttribute("value", tostring(idx)) end
			end
		end
		if spManualSlider then
			spManualSlider:AddEventListener("change", function(ev)
				if uiState.updatingFromCode then ev:StopPropagation(); return end
				spApplyManualSpoke(tonumber(spManualSlider:GetAttribute("value")) or 0)
				ev:StopPropagation()
			end, false)
		end
		local spMsDn = doc:GetElementById("sp-btn-manual-spoke-down")
		if spMsDn then spMsDn:AddEventListener("click", function(ev)
			if WG.TerraformBrush then
				local s = getTFState()
				local step = s.angleSnapStep or 15
				local num  = math.max(1, math.floor(360 / step))
				spApplyManualSpoke(((s.angleSnapManualSpoke or 0) - 1 + num) % num)
			end
			ev:StopPropagation()
		end, false) end
		local spMsUp = doc:GetElementById("sp-btn-manual-spoke-up")
		if spMsUp then spMsUp:AddEventListener("click", function(ev)
			if WG.TerraformBrush then
				local s = getTFState()
				local step = s.angleSnapStep or 15
				local num  = math.max(1, math.floor(360 / step))
				spApplyManualSpoke(((s.angleSnapManualSpoke or 0) + 1) % num)
			end
			ev:StopPropagation()
		end, false) end

		-- Measure toolbar
		local function spMeasureBtnClick(id, fn)
			local el = doc:GetElementById(id)
			if el then el:AddEventListener("click", function(ev) fn(); ev:StopPropagation() end, false) end
		end
		spMeasureBtnClick("sp-btn-measure-show-length", function() if WG.TerraformBrush then WG.TerraformBrush.setMeasureShowLength(not getTFState().measureShowLength) end end)
		spMeasureBtnClick("sp-btn-measure-clear",       function() if WG.TerraformBrush then WG.TerraformBrush.clearMeasureLines() end end)

		-- Symmetry master + sub-toolbar
		local spSymBtn = doc:GetElementById("btn-sp-symmetry")
		if spSymBtn then
			spSymBtn:AddEventListener("click", function(ev)
				if WG.TerraformBrush then
					local s = getTFState()
					local newVal = not s.symmetryActive
					playSound(newVal and "toggleOn" or "toggleOff")
					WG.TerraformBrush.setSymmetryActive(newVal)
					if newVal and not (s.symmetryRadial or s.symmetryMirrorX or s.symmetryMirrorY) then
						WG.TerraformBrush.setSymmetryMirrorX(true)
						local mxBtn = doc:GetElementById("sp-btn-symmetry-mirror-x")
						if mxBtn then mxBtn:SetClass("active", true) end
					end
					spSymBtn:SetClass("active", newVal)
					if spSymRow then spSymRow:SetClass("hidden", not newVal) end
				end
				ev:StopPropagation()
			end, false)
		end
		local function spSymBtnClick(id, fn)
			local el = doc:GetElementById(id)
			if el then el:AddEventListener("click", function(ev) fn(); ev:StopPropagation() end, false) end
		end
		local function spSyncSymChipClasses()
			local s = getTFState()
			local rEl = doc:GetElementById("sp-btn-symmetry-radial")
			local xEl = doc:GetElementById("sp-btn-symmetry-mirror-x")
			local yEl = doc:GetElementById("sp-btn-symmetry-mirror-y")
			if rEl then rEl:SetClass("active", s.symmetryRadial and true or false) end
			if xEl then xEl:SetClass("active", s.symmetryMirrorX and true or false) end
			if yEl then yEl:SetClass("active", s.symmetryMirrorY and true or false) end
			local countRow = doc:GetElementById("sp-symmetry-radial-count-row")
			if countRow then countRow:SetClass("hidden", not s.symmetryRadial) end
			local angleRow = doc:GetElementById("sp-symmetry-mirror-angle-row")
			if angleRow then angleRow:SetClass("hidden", not (s.symmetryMirrorX or s.symmetryMirrorY)) end
		end
		spSymBtnClick("sp-btn-symmetry-radial",    function() if WG.TerraformBrush then WG.TerraformBrush.setSymmetryRadial(not getTFState().symmetryRadial); spSyncSymChipClasses() end end)
		spSymBtnClick("sp-btn-symmetry-mirror-x",  function() if WG.TerraformBrush then WG.TerraformBrush.setSymmetryMirrorX(not getTFState().symmetryMirrorX); spSyncSymChipClasses() end end)
		spSymBtnClick("sp-btn-symmetry-mirror-y",  function() if WG.TerraformBrush then WG.TerraformBrush.setSymmetryMirrorY(not getTFState().symmetryMirrorY); spSyncSymChipClasses() end end)
		spSymBtnClick("sp-btn-symmetry-place-origin",  function() if WG.TerraformBrush then WG.TerraformBrush.setSymmetryPlacingOrigin(true); playSound("toggleOn") end end)
		spSymBtnClick("sp-btn-symmetry-center-origin", function() if WG.TerraformBrush then WG.TerraformBrush.setSymmetryOrigin(nil, nil); playSound("toggleOff") end end)
		spSymBtnClick("sp-btn-symmetry-count-down", function()
			if WG.TerraformBrush then
				local c = math.max(2, (getTFState().symmetryRadialCount or 2) - 1)
				WG.TerraformBrush.setSymmetryRadialCount(c)
			end
		end)
		spSymBtnClick("sp-btn-symmetry-count-up", function()
			if WG.TerraformBrush then
				local c = math.min(16, (getTFState().symmetryRadialCount or 2) + 1)
				WG.TerraformBrush.setSymmetryRadialCount(c)
			end
		end)
		spSymBtnClick("sp-btn-symmetry-angle-down", function()
			if WG.TerraformBrush then
				local a = ((getTFState().symmetryMirrorAngle or 0) - 5) % 360
				WG.TerraformBrush.setSymmetryMirrorAngle(a)
			end
		end)
		spSymBtnClick("sp-btn-symmetry-angle-up", function()
			if WG.TerraformBrush then
				local a = ((getTFState().symmetryMirrorAngle or 0) + 5) % 360
				WG.TerraformBrush.setSymmetryMirrorAngle(a)
			end
		end)
		local spCountSlider = doc:GetElementById("sp-slider-symmetry-radial-count")
		if spCountSlider then
			trackSliderDrag(spCountSlider, "sp-symmetry-radial-count")
			spCountSlider:AddEventListener("change", function(ev)
				if uiState.updatingFromCode then ev:StopPropagation(); return end
				if WG.TerraformBrush then
					local v = tonumber(spCountSlider:GetAttribute("value")) or 2
					WG.TerraformBrush.setSymmetryRadialCount(v)
				end
				ev:StopPropagation()
			end, false)
		end
		local spSymAngleSlider = doc:GetElementById("sp-slider-symmetry-mirror-angle")
		if spSymAngleSlider then
			trackSliderDrag(spSymAngleSlider, "sp-symmetry-mirror-angle")
			spSymAngleSlider:AddEventListener("change", function(ev)
				if uiState.updatingFromCode then ev:StopPropagation(); return end
				if WG.TerraformBrush then
					local v = tonumber(spSymAngleSlider:GetAttribute("value")) or 0
					WG.TerraformBrush.setSymmetryMirrorAngle(v)
				end
				ev:StopPropagation()
			end, false)
		end
	end

end

function M.sync(doc, ctx, spState, setSummary)
	local widgetState = ctx.widgetState
	local uiState = ctx.uiState
	local WG = ctx.WG
	local setActiveClass = ctx.setActiveClass
	local syncAndFlash = ctx.syncAndFlash
	local cadenceToSlider = ctx.cadenceToSlider
	local shapeNames = ctx.shapeNames
		-- ===== Splat Painter mode: update splat controls =====
		local splatBtn = doc and doc:GetElementById("btn-splat")
		if splatBtn then splatBtn:SetClass("active", true) end
		setActiveClass(widgetState.modeButtons, nil)

		setActiveClass(widgetState.shapeButtons, spState.shape)

		if doc then
			uiState.updatingFromCode = true
			local ds = uiState.draggingSlider

			-- Splat labels
			local spStrengthLabel = doc:GetElementById("sp-strength-label")
			if spStrengthLabel then spStrengthLabel.inner_rml = string.format("%.2f", spState.strength) end

			local spIntensityLabel = doc:GetElementById("sp-intensity-label")
			if spIntensityLabel then spIntensityLabel.inner_rml = string.format("%.1f", spState.intensity) end

			local spRadiusLabel = doc:GetElementById("sp-radius-label")
			if spRadiusLabel then spRadiusLabel.inner_rml = tostring(spState.radius) end

			local spRotationLabel = doc:GetElementById("sp-rotation-label")
			if spRotationLabel then spRotationLabel.inner_rml = tostring(spState.rotationDeg) end

			local spCurveLabel = doc:GetElementById("sp-curve-label")
			if spCurveLabel then spCurveLabel.inner_rml = string.format("%.1f", spState.curve) end

			-- Splat channel button highlights
			for i = 1, 4 do
				local chBtn = doc:GetElementById("btn-sp-ch" .. i)
				if chBtn then chBtn:SetClass("active", i == spState.channel) end
			end

			-- Splat sliders
			syncAndFlash(doc:GetElementById("sp-slider-strength"), "sp-strength", tostring(math.floor(spState.strength * 100 + 0.5)))
			syncAndFlash(doc:GetElementById("sp-slider-intensity"), "sp-intensity", tostring(math.floor(spState.intensity * 10 + 0.5)))
			syncAndFlash(doc:GetElementById("sp-slider-size"), "sp-size", tostring(spState.radius))
			syncAndFlash(doc:GetElementById("sp-slider-rotation"), "sp-rotation", tostring(spState.rotationDeg))
			syncAndFlash(doc:GetElementById("sp-slider-curve"), "sp-curve", tostring(math.floor(spState.curve * 10 + 0.5)))

			-- Smart filter UI sync
			do
				local warnChip = doc:GetElementById("warn-chip-sp-smart")
				if warnChip then
					warnChip:SetClass("hidden", not (spState.smartEnabled == true))
				end
				if spState.smartFilters then
					local sf = spState.smartFilters
					-- Slope/Altitude chips active when any sub-filter in that category is on
					local slopeChip = doc:GetElementById("sp-filter-chip-slope")
					if slopeChip then slopeChip:SetClass("active", sf.avoidCliffs or sf.preferSlopes or false) end
					local altChip = doc:GetElementById("sp-filter-chip-altitude")
					if altChip then altChip:SetClass("active", sf.altMinEnable or sf.altMaxEnable or false) end

					local avoidWaterBtn = doc:GetElementById("btn-sp-avoid-water")
					if avoidWaterBtn then
						avoidWaterBtn:SetAttribute("src", sf.avoidWater
							and "/luaui/images/terraform_brush/check_on.png"
							or "/luaui/images/terraform_brush/check_off.png")
					end

					local avoidCliffsBtn = doc:GetElementById("btn-sp-avoid-cliffs")
					if avoidCliffsBtn then
						avoidCliffsBtn:SetAttribute("src", sf.avoidCliffs
							and "/luaui/images/terraform_brush/check_on.png"
							or "/luaui/images/terraform_brush/check_off.png")
					end

					local slopeMaxRow = doc:GetElementById("sp-smart-slope-max-row")
					if slopeMaxRow then slopeMaxRow:SetClass("hidden", not sf.avoidCliffs) end
					local slopeMaxSliderRow = doc:GetElementById("sp-smart-slope-max-slider-row")
					if slopeMaxSliderRow then slopeMaxSliderRow:SetClass("hidden", not sf.avoidCliffs) end
					local slopeMaxLabel = doc:GetElementById("sp-smart-slope-max-label")
					if slopeMaxLabel then slopeMaxLabel.inner_rml = tostring(sf.slopeMax) end
					local spSSlopeMax = doc:GetElementById("sp-slider-slope-max")
					if spSSlopeMax and ds ~= "sp-slope-max" then
						spSSlopeMax:SetAttribute("value", tostring(sf.slopeMax))
					end

					local preferSlopesBtn = doc:GetElementById("btn-sp-prefer-slopes")
					if preferSlopesBtn then
						preferSlopesBtn:SetAttribute("src", sf.preferSlopes
							and "/luaui/images/terraform_brush/check_on.png"
							or "/luaui/images/terraform_brush/check_off.png")
					end

					local slopeMinRow = doc:GetElementById("sp-smart-slope-min-row")
					if slopeMinRow then slopeMinRow:SetClass("hidden", not sf.preferSlopes) end
					local slopeMinSliderRow = doc:GetElementById("sp-smart-slope-min-slider-row")
					if slopeMinSliderRow then slopeMinSliderRow:SetClass("hidden", not sf.preferSlopes) end
					local slopeMinLabel = doc:GetElementById("sp-smart-slope-min-label")
					if slopeMinLabel then slopeMinLabel.inner_rml = tostring(sf.slopeMin) end
					local spSSlopeMin = doc:GetElementById("sp-slider-slope-min")
					if spSSlopeMin and ds ~= "sp-slope-min" then
						spSSlopeMin:SetAttribute("value", tostring(sf.slopeMin))
					end

					local altMinEnableBtn = doc:GetElementById("btn-sp-alt-min-enable")
					if altMinEnableBtn then
						altMinEnableBtn:SetAttribute("src", sf.altMinEnable
							and "/luaui/images/terraform_brush/check_on.png"
							or "/luaui/images/terraform_brush/check_off.png")
					end
					local altMinSliderRow = doc:GetElementById("sp-smart-alt-min-slider-row")
					if altMinSliderRow then altMinSliderRow:SetClass("hidden", not sf.altMinEnable) end
					local altMinLabel = doc:GetElementById("sp-smart-alt-min-label")
					if altMinLabel then altMinLabel.inner_rml = tostring(sf.altMin) end
					local spSAltMin = doc:GetElementById("sp-slider-alt-min")
					if spSAltMin and ds ~= "sp-alt-min" then
						spSAltMin:SetAttribute("value", tostring(sf.altMin))
					end

					local altMaxEnableBtn = doc:GetElementById("btn-sp-alt-max-enable")
					if altMaxEnableBtn then
						altMaxEnableBtn:SetAttribute("src", sf.altMaxEnable
							and "/luaui/images/terraform_brush/check_on.png"
							or "/luaui/images/terraform_brush/check_off.png")
					end
					local altMaxSliderRow = doc:GetElementById("sp-smart-alt-max-slider-row")
					if altMaxSliderRow then altMaxSliderRow:SetClass("hidden", not sf.altMaxEnable) end
					local altMaxLabel = doc:GetElementById("sp-smart-alt-max-label")
					if altMaxLabel then altMaxLabel.inner_rml = tostring(sf.altMax) end
					local spSAltMax = doc:GetElementById("sp-slider-alt-max")
					if spSAltMax and ds ~= "sp-alt-max" then
						spSAltMax:SetAttribute("value", tostring(sf.altMax))
					end
				end
			end

			-- Export format label
			local spExportFmtLabel = doc:GetElementById("sp-export-format-label")
			if spExportFmtLabel and spState.exportFormat then
				spExportFmtLabel.inner_rml = string.upper(spState.exportFormat)
			end

			-- Undo/redo history slider sync
			do
				local undoCount = spState.undoCount or 0
				local redoCount = spState.redoCount or 0
				local total = undoCount + redoCount
				local spHistSlider = doc:GetElementById("slider-sp-history")
				if spHistSlider and ds ~= "sp-history" then
					spHistSlider:SetAttribute("max", tostring(total))
					spHistSlider:SetAttribute("value", tostring(undoCount))
				end
				local spHistNumbox = doc:GetElementById("slider-sp-history-numbox")
				if spHistNumbox then
					spHistNumbox.inner_rml = tostring(undoCount)
				end
			end

			-- Decal Exporter stats sync (throttled — every ~1 second)
			do if WG.DecalExporter and (Spring.GetGameFrame() % 30 == 0) then
				local dcGl4 = doc:GetElementById("dc-gl4-count")
				local dcEng = doc:GetElementById("dc-engine-count")
				local dcHeat = doc:GetElementById("dc-heat-count")
				local dcHeatExp = doc:GetElementById("dc-heat-explosions")
				local gl4n = 0
				local decalsApi = WG['decalsgl4']
				if decalsApi and decalsApi.GetActiveDecals then
					local ad = decalsApi.GetActiveDecals()
					if ad then for _ in pairs(ad) do gl4n = gl4n + 1 end end
				end
				local engn = 0
				if Spring.GetAllGroundDecals then
					local ids = Spring.GetAllGroundDecals()
					if ids then engn = #ids end
				end
				if dcGl4 then dcGl4.inner_rml = tostring(gl4n) end
				if dcEng then dcEng.inner_rml = tostring(engn) end
				local _, _, _, hm = WG.DecalExporter.getHeatGrid()
				if dcHeat then dcHeat.inner_rml = string.format("%.0f", hm or 0) end
				if dcHeatExp then dcHeatExp.inner_rml = tostring(WG.DecalExporter.getTotalExplosions()) end
			end end

			uiState.updatingFromCode = false
		end

		-- Gray out unsupported shapes in splat mode (no ring)
		for shape, element in pairs(widgetState.shapeButtons) do
			if element and shape ~= "ring" then
				element:SetClass("disabled", false)
			end
		end

		do
			local toolLabel = "SPLAT"
			setSummary(toolLabel, "#22c55e",
				"CH ", tostring(spState.channel or "?"),
				"", shapeNames[spState.shape] or "Circle",
				"R ", tostring(spState.radius or 0),
				"Str ", string.format("%.2f", spState.strength or 0),
				"Int ", string.format("%.1f", spState.intensity or 0))
		end

		-- Sync DISPLAY + INSTRUMENTS chip states from shared TerraformBrush state
		do
			local tb = WG.TerraformBrush
			if tb and tb.getState then
				local s = tb.getState()
				local function setChip(id, active)
					local el = doc:GetElementById(id)
					if el then el:SetClass("active", active and true or false) end
				end
				local function setHidden(id, hidden)
					local el = doc:GetElementById(id)
					if el then el:SetClass("hidden", hidden and true or false) end
				end
				setChip("btn-sp-grid-overlay",    s.gridOverlay)
				setChip("btn-sp-height-colormap", s.heightColormap)
				-- Splat Map overlay chip (own state from SplatPainter)
				do
					local sp = WG.SplatPainter
					setChip("btn-sp-splat-overlay", sp and sp.getState and sp.getState().showSplatOverlay or false)
				end
				-- Hint dot: visible (pulsing) while DISPLAY section is closed
				do
					local hintDot = doc:GetElementById("sp-display-notify-dot")
					if hintDot then
						local tipsDisabled = widgetState.uiPrefs and widgetState.uiPrefs.disableTips
						local alreadySeen = widgetState.uiPrefs and widgetState.uiPrefs.seenSplatDisplayHint
						local sec = doc:GetElementById("section-sp-overlays")
						hintDot:SetClass("hidden", tipsDisabled or alreadySeen or (sec and not sec:IsClassSet("hidden")) or false)
					end
				end
				-- Chip 2-pulse: fires the frame after DISPLAY section is opened
				if widgetState.splatDisplayPulseFrame and Spring.GetGameFrame() >= widgetState.splatDisplayPulseFrame then
					widgetState.splatDisplayPulseFrame = nil
					local tipsDisabled = widgetState.uiPrefs and widgetState.uiPrefs.disableTips
					local splatChip = doc:GetElementById("btn-sp-splat-overlay")
					if splatChip and not tipsDisabled then
						splatChip:SetClass("tf-chip-2pulse", false)
						splatChip:SetClass("tf-chip-2pulse", true)
						widgetState.splatChip2PulseExpiry = (Spring.GetGameSeconds() or 0) + 1.25
					end
				end
				-- Remove 2-pulse class after animation completes
				if widgetState.splatChip2PulseExpiry and (Spring.GetGameSeconds() or 0) >= widgetState.splatChip2PulseExpiry then
					widgetState.splatChip2PulseExpiry = nil
					local splatChip = doc:GetElementById("btn-sp-splat-overlay")
					if splatChip then splatChip:SetClass("tf-chip-2pulse", false) end
				end
				setChip("btn-sp-grid-snap",       s.gridSnap)
				setChip("btn-sp-angle-snap",      s.angleSnap)
				setChip("btn-sp-measure",         s.measureActive)
				setChip("btn-sp-symmetry",        s.symmetryActive)
				setHidden("sp-grid-snap-size-row",  not s.gridSnap)
				setHidden("sp-angle-snap-step-row", not s.angleSnap)
				setHidden("sp-measure-toolbar-row", not s.measureActive)
				setHidden("sp-symmetry-toolbar-row",not s.symmetryActive)
				-- Symmetry sub chips + sub rows
				setChip("sp-btn-symmetry-radial",   s.symmetryRadial)
				setChip("sp-btn-symmetry-mirror-x", s.symmetryMirrorX)
				setChip("sp-btn-symmetry-mirror-y", s.symmetryMirrorY)
				setHidden("sp-symmetry-radial-count-row",   not s.symmetryRadial)
				setHidden("sp-symmetry-mirror-angle-row",   not (s.symmetryMirrorX or s.symmetryMirrorY))
				-- Measure sub chips
				setChip("sp-btn-measure-show-length", s.measureShowLength)
				-- Angle auto-snap chip + manual spoke row
				setChip("sp-btn-angle-autosnap", s.angleSnapAuto)
				setHidden("sp-angle-manual-spoke-row", s.angleSnapAuto)
				-- Labels
				local function setLabel(id, text)
					local el = doc:GetElementById(id)
					if el then el.inner_rml = tostring(text) end
				end
				setLabel("sp-grid-snap-size-label",         s.gridSnapSize or 48)
				setLabel("sp-symmetry-radial-count-label",  s.symmetryRadialCount or 2)
				setLabel("sp-symmetry-mirror-angle-label",  s.symmetryMirrorAngle or 0)
				local step = s.angleSnapStep or 15
				setLabel("sp-angle-snap-step-label",
					(step == math.floor(step)) and tostring(math.floor(step)) or tostring(step))
				setLabel("sp-angle-manual-spoke-label", ((s.angleSnapManualSpoke or 0) * step) % 360)
				-- Numbox + slider value sync (avoid re-firing change)
				uiState.updatingFromCode = true
				local nb = doc:GetElementById("sp-slider-grid-snap-size-numbox")
				if nb then nb:SetAttribute("value", tostring(s.gridSnapSize or 48)) end
				local sz = doc:GetElementById("sp-slider-grid-snap-size")
				if sz then sz:SetAttribute("value", tostring(s.gridSnapSize or 48)) end
				uiState.updatingFromCode = false
			end
		end

		-- P3.2 Splat grayouts (per Phase 3 relevance matrix)
		if doc and ctx.setDisabledIds then
			local circular = (spState.shape == "circle")
			ctx.setDisabledIds(doc, {
				"sp-slider-rotation", "sp-slider-rotation-numbox",
				"btn-sp-rot-ccw", "btn-sp-rot-cw",
			}, circular)
		end

end

return M
