-- tf_grass.lua — Grass Brush attach + sync (extracted from gui_terraform_brush.lua)
local M = {}

function M.attach(doc, ctx)
	local widgetState = ctx.widgetState
	local uiState = ctx.uiState
	local playSound = ctx.playSound
	local setActiveClass = ctx.setActiveClass
	local trackSliderDrag = ctx.trackSliderDrag
	local WG = ctx.WG
	local RADIUS_STEP = ctx.RADIUS_STEP
	local ROTATION_STEP = ctx.ROTATION_STEP
	local CURVE_STEP = ctx.CURVE_STEP

	widgetState.gbSubmodesEl = doc:GetElementById("tf-grass-submodes")
	widgetState.gbControlsEl = doc:GetElementById("tf-grass-controls")
	widgetState.gbSubModeButtons = {}
	widgetState.gbSubModeButtons.paint = doc:GetElementById("btn-gb-paint")
	widgetState.gbSubModeButtons.fill = doc:GetElementById("btn-gb-fill")
	widgetState.gbSubModeButtons.erase = doc:GetElementById("btn-gb-erase")

	for gbMode, element in pairs(widgetState.gbSubModeButtons) do
		if element then
			element:AddEventListener("click", function(event)
				playSound("modeSwitch")
				if WG.GrassBrush then WG.GrassBrush.setSubMode(gbMode) end
				setActiveClass(widgetState.gbSubModeButtons, gbMode)
				event:StopPropagation()
			end, false)
		end
	end

	do
		local sl = doc:GetElementById("slider-grass-density")
		if sl then
			trackSliderDrag(sl, "gb-density")
			sl:AddEventListener("change", function(event)
				if uiState.updatingFromCode then event:StopPropagation(); return end
				local v = tonumber(sl:GetAttribute("value")) or 80
				local density = v / 100
				if WG.GrassBrush then WG.GrassBrush.setDensity(density) end
				local label = doc:GetElementById("gb-density-label")
				if label then label.inner_rml = tostring(math.floor(density * 100 + 0.5)) .. "%" end
				event:StopPropagation()
			end, false)
		end
		local densUp = doc:GetElementById("btn-grass-density-up")
		if densUp then
			densUp:AddEventListener("click", function(event)
				if WG.GrassBrush then
					local s = WG.GrassBrush.getState()
					local cur = s and s.density or 0.8
					WG.GrassBrush.setDensity(math.min(1.0, cur + 0.05))
				end
				event:StopPropagation()
			end, false)
		end
		local densDn = doc:GetElementById("btn-grass-density-down")
		if densDn then
			densDn:AddEventListener("click", function(event)
				if WG.GrassBrush then
					local s = WG.GrassBrush.getState()
					local cur = s and s.density or 0.8
					WG.GrassBrush.setDensity(math.max(0.0, cur - 0.05))
				end
				event:StopPropagation()
			end, false)
		end
	end

	do
		local btn = doc:GetElementById("btn-grass-save")
		if btn then
			btn:AddEventListener("click", function(event)
				playSound("save")
				if WG.GrassBrush then WG.GrassBrush.saveGrassMap() end
				event:StopPropagation()
			end, false)
		end
	end

	-- Grass undo/redo history controls
	do
		local btnUndo = doc:GetElementById("btn-gb-undo")
		if btnUndo then
			btnUndo:AddEventListener("click", function(event)
				if WG.GrassBrush then playSound("undo"); WG.GrassBrush.undo() end
				event:StopPropagation()
			end, false)
		end

		local btnRedo = doc:GetElementById("btn-gb-redo")
		if btnRedo then
			btnRedo:AddEventListener("click", function(event)
				if WG.GrassBrush then playSound("redo"); WG.GrassBrush.redo() end
				event:StopPropagation()
			end, false)
		end

		local slHist = doc:GetElementById("slider-gb-history")
		if slHist then
			trackSliderDrag(slHist, "gb-history")
			slHist:AddEventListener("change", function(event)
				if uiState.updatingFromCode then event:StopPropagation(); return end
				local v = tonumber(slHist:GetAttribute("value")) or 0
				if WG.GrassBrush then WG.GrassBrush.undoToIndex(v) end
				event:StopPropagation()
			end, false)
		end
	end



	-- Grass size slider
	do
		local sl = doc:GetElementById("slider-gb-size")
		if sl then
			trackSliderDrag(sl, "gb-size")
			sl:AddEventListener("change", function(event)
				if not uiState.updatingFromCode and WG.GrassBrush then
					local val = tonumber(sl:GetAttribute("value")) or 100
					WG.GrassBrush.setRadius(val)
				end
				event:StopPropagation()
			end, false)
		end
		local up = doc:GetElementById("btn-gb-size-up")
		if up then
			up:AddEventListener("click", function(event)
				if WG.GrassBrush then
					local state = WG.GrassBrush.getState()
					WG.GrassBrush.setRadius(state.radius + RADIUS_STEP)
				end
				event:StopPropagation()
			end, false)
		end
		local dn = doc:GetElementById("btn-gb-size-down")
		if dn then
			dn:AddEventListener("click", function(event)
				if WG.GrassBrush then
					local state = WG.GrassBrush.getState()
					WG.GrassBrush.setRadius(state.radius - RADIUS_STEP)
				end
				event:StopPropagation()
			end, false)
		end
	end

	-- Grass rotation slider
	do
		local sl = doc:GetElementById("slider-gb-rotation")
		if sl then
			trackSliderDrag(sl, "gb-rotation")
			sl:AddEventListener("change", function(event)
				if not uiState.updatingFromCode and WG.GrassBrush then
					local val = tonumber(sl:GetAttribute("value")) or 0
					WG.GrassBrush.setRotation(val)
				end
				event:StopPropagation()
			end, false)
		end
		local cw = doc:GetElementById("btn-gb-rot-cw")
		if cw then
			cw:AddEventListener("click", function(event)
				if WG.GrassBrush then
					local state = WG.GrassBrush.getState()
					WG.GrassBrush.setRotation((state.rotationDeg or 0) + ROTATION_STEP)
				end
				event:StopPropagation()
			end, false)
		end
		local ccw = doc:GetElementById("btn-gb-rot-ccw")
		if ccw then
			ccw:AddEventListener("click", function(event)
				if WG.GrassBrush then
					local state = WG.GrassBrush.getState()
					WG.GrassBrush.setRotation((state.rotationDeg or 0) - ROTATION_STEP)
				end
				event:StopPropagation()
			end, false)
		end
	end

	-- Grass curve/falloff slider
	do
		local sl = doc:GetElementById("slider-gb-curve")
		if sl then
			trackSliderDrag(sl, "gb-curve")
			sl:AddEventListener("change", function(event)
				if not uiState.updatingFromCode and WG.GrassBrush then
					local val = tonumber(sl:GetAttribute("value")) or 10
					WG.GrassBrush.setCurve(val / 10)
				end
				event:StopPropagation()
			end, false)
		end
		local up = doc:GetElementById("btn-gb-curve-up")
		if up then
			up:AddEventListener("click", function(event)
				if WG.GrassBrush then
					local state = WG.GrassBrush.getState()
					WG.GrassBrush.setCurve(state.curve + CURVE_STEP)
				end
				event:StopPropagation()
			end, false)
		end
		local dn = doc:GetElementById("btn-gb-curve-down")
		if dn then
			dn:AddEventListener("click", function(event)
				if WG.GrassBrush then
					local state = WG.GrassBrush.getState()
					WG.GrassBrush.setCurve(state.curve - CURVE_STEP)
				end
				event:StopPropagation()
			end, false)
		end
	end

	-- Grass length scale slider
	do
		local sl = doc:GetElementById("slider-gb-length")
		if sl then
			trackSliderDrag(sl, "gb-length")
			sl:AddEventListener("change", function(event)
				if uiState.updatingFromCode then event:StopPropagation(); return end
				local v = tonumber(sl:GetAttribute("value")) or 10
				if WG.GrassBrush then WG.GrassBrush.setLengthScale(v / 10) end
				event:StopPropagation()
			end, false)
		end
		local up = doc:GetElementById("btn-gb-length-up")
		if up then
			up:AddEventListener("click", function(event)
				if WG.GrassBrush then
					local state = WG.GrassBrush.getState()
					WG.GrassBrush.setLengthScale(state.lengthScale + 0.1)
				end
				event:StopPropagation()
			end, false)
		end
		local dn = doc:GetElementById("btn-gb-length-down")
		if dn then
			dn:AddEventListener("click", function(event)
				if WG.GrassBrush then
					local state = WG.GrassBrush.getState()
					WG.GrassBrush.setLengthScale(state.lengthScale - 0.1)
				end
				event:StopPropagation()
			end, false)
		end
	end

	-- Grass smart filter toggles
	do
		local function wireGbSmartToggle(btnId, filterKey)
			local btn = doc:GetElementById(btnId)
			if btn then
				btn:AddEventListener("click", function(event)
					if WG.GrassBrush then
						local sf = WG.GrassBrush.getState().smartFilters
						playSound(sf[filterKey] and "toggleOff" or "toggleOn")
						WG.GrassBrush.setSmartFilter(filterKey, not sf[filterKey])
					end
					event:StopPropagation()
				end, false)
			end
		end

		local toggle = doc:GetElementById("btn-gb-smart-toggle")
		if toggle then
			toggle:AddEventListener("click", function(event)
				if WG.GrassBrush then
					local st = WG.GrassBrush.getState()
					playSound(st.smartEnabled and "toggleOff" or "toggleOn")
					WG.GrassBrush.setSmartEnabled(not st.smartEnabled)
				end
				event:StopPropagation()
			end, false)
		end

		wireGbSmartToggle("btn-gb-avoid-water",    "avoidWater")
		wireGbSmartToggle("btn-gb-avoid-cliffs",   "avoidCliffs")
		wireGbSmartToggle("btn-gb-prefer-slopes",  "preferSlopes")
		wireGbSmartToggle("btn-gb-alt-min-enable", "altMinEnable")
		wireGbSmartToggle("btn-gb-alt-max-enable", "altMaxEnable")

		local slSlopeMax = doc:GetElementById("slider-gb-slope-max")
		if slSlopeMax then
			trackSliderDrag(slSlopeMax, "gb-slope-max")
			slSlopeMax:AddEventListener("change", function(event)
				if uiState.updatingFromCode then event:StopPropagation(); return end
				local v = tonumber(slSlopeMax:GetAttribute("value")) or 45
				if WG.GrassBrush then WG.GrassBrush.setSmartFilter("slopeMax", v) end
				event:StopPropagation()
			end, false)
		end

		local slSlopeMin = doc:GetElementById("slider-gb-slope-min")
		if slSlopeMin then
			trackSliderDrag(slSlopeMin, "gb-slope-min")
			slSlopeMin:AddEventListener("change", function(event)
				if uiState.updatingFromCode then event:StopPropagation(); return end
				local v = tonumber(slSlopeMin:GetAttribute("value")) or 10
				if WG.GrassBrush then WG.GrassBrush.setSmartFilter("slopeMin", v) end
				event:StopPropagation()
			end, false)
		end

		local slAltMin = doc:GetElementById("slider-gb-alt-min")
		if slAltMin then
			trackSliderDrag(slAltMin, "gb-alt-min")
			slAltMin:AddEventListener("change", function(event)
				if uiState.updatingFromCode then event:StopPropagation(); return end
				local v = tonumber(slAltMin:GetAttribute("value")) or 0
				if WG.GrassBrush then WG.GrassBrush.setSmartFilter("altMin", v) end
				event:StopPropagation()
			end, false)
		end

		local slAltMax = doc:GetElementById("slider-gb-alt-max")
		if slAltMax then
			trackSliderDrag(slAltMax, "gb-alt-max")
			slAltMax:AddEventListener("change", function(event)
				if uiState.updatingFromCode then event:StopPropagation(); return end
				local v = tonumber(slAltMax:GetAttribute("value")) or 200
				if WG.GrassBrush then WG.GrassBrush.setSmartFilter("altMax", v) end
				event:StopPropagation()
			end, false)
		end

		-- Grass smart filter +/- buttons
		local function wireGbSmartBtn(btnId, filterKey, step)
			local btn = doc:GetElementById(btnId)
			if btn then
				btn:AddEventListener("click", function(event)
					if WG.GrassBrush then
						local sf = WG.GrassBrush.getState().smartFilters
						WG.GrassBrush.setSmartFilter(filterKey, (sf[filterKey] or 0) + step)
					end
					event:StopPropagation()
				end, false)
			end
		end
		wireGbSmartBtn("btn-gb-slope-max-up",   "slopeMax",  5)
		wireGbSmartBtn("btn-gb-slope-max-down", "slopeMax", -5)
		wireGbSmartBtn("btn-gb-slope-min-up",   "slopeMin",  5)
		wireGbSmartBtn("btn-gb-slope-min-down", "slopeMin", -5)
		wireGbSmartBtn("btn-gb-alt-min-up",     "altMin",   10)
		wireGbSmartBtn("btn-gb-alt-min-down",   "altMin",  -10)
		wireGbSmartBtn("btn-gb-alt-max-up",     "altMax",   10)
		wireGbSmartBtn("btn-gb-alt-max-down",   "altMax",  -10)
	end

	-- Grass color filter controls
	do
		local colorToggle = doc:GetElementById("btn-gb-color-toggle")
		if colorToggle then
			colorToggle:AddEventListener("click", function(event)
				if WG.GrassBrush then
					local st = WG.GrassBrush.getState()
					playSound(st.texFilterEnabled and "toggleOff" or "toggleOn")
					WG.GrassBrush.setTexFilterEnabled(not st.texFilterEnabled)
				end
				event:StopPropagation()
			end, false)
		end

		local pipetteBtn = doc:GetElementById("btn-gb-pipette")
		if pipetteBtn then
			pipetteBtn:AddEventListener("click", function(event)
				if WG.GrassBrush then
					local st = WG.GrassBrush.getState()
					if st.pipetteMode then
						WG.GrassBrush.setPipetteMode(false)
					else
						playSound("click")
						WG.GrassBrush.setPipetteMode(true)
					end
				end
				event:StopPropagation()
			end, false)
		end

		local slThresh = doc:GetElementById("slider-gb-color-thresh")
		if slThresh then
			trackSliderDrag(slThresh, "gb-color-thresh")
			slThresh:AddEventListener("change", function(event)
				if uiState.updatingFromCode then event:StopPropagation(); return end
				local v = tonumber(slThresh:GetAttribute("value")) or 35
				if WG.GrassBrush then WG.GrassBrush.setTexFilterThreshold(v / 100) end
				event:StopPropagation()
			end, false)
		end

		local slPad = doc:GetElementById("slider-gb-color-pad")
		if slPad then
			trackSliderDrag(slPad, "gb-color-pad")
			slPad:AddEventListener("change", function(event)
				if uiState.updatingFromCode then event:StopPropagation(); return end
				local v = tonumber(slPad:GetAttribute("value")) or 0
				if WG.GrassBrush then WG.GrassBrush.setTexFilterPadding(v) end
				event:StopPropagation()
			end, false)
		end

		local excludeToggle = doc:GetElementById("btn-gb-exclude-toggle")
		if excludeToggle then
			excludeToggle:AddEventListener("click", function(event)
				if WG.GrassBrush then
					local st = WG.GrassBrush.getState()
					playSound(st.texExcludeEnabled and "toggleOff" or "toggleOn")
					WG.GrassBrush.setTexExcludeEnabled(not st.texExcludeEnabled)
				end
				event:StopPropagation()
			end, false)
		end

		local excludePipetteBtn = doc:GetElementById("btn-gb-exclude-pipette")
		if excludePipetteBtn then
			excludePipetteBtn:AddEventListener("click", function(event)
				if WG.GrassBrush then
					local st = WG.GrassBrush.getState()
					if st.pipetteExcludeMode then
						WG.GrassBrush.setPipetteExcludeMode(false)
					else
						playSound("click")
						WG.GrassBrush.setPipetteExcludeMode(true)
					end
				end
				event:StopPropagation()
			end, false)
		end
	end

	-- ── DISPLAY + INSTRUMENTS chips (forward to shared WG.TerraformBrush state) ──
	do
		local function chipToggle(id, getCur, setter)
			local el = doc:GetElementById(id)
			if not el then return end
			el:AddEventListener("click", function(ev)
				if WG.TerraformBrush then
					local newVal = not getCur()
					playSound(newVal and "toggleOn" or "toggleOff")
					setter(newVal)
					el:SetClass("active", newVal)
				end
				ev:StopPropagation()
			end, false)
		end
		local function getTFState() return WG.TerraformBrush and WG.TerraformBrush.getState() or {} end

		chipToggle("btn-gb-grid-overlay",
			function() return getTFState().gridOverlay end,
			function(v) WG.TerraformBrush.setGridOverlay(v) end)
		chipToggle("btn-gb-height-colormap",
			function() return getTFState().heightColormap end,
			function(v) WG.TerraformBrush.setHeightColormap(v) end)
		local gbSnapRow = doc:GetElementById("gb-grid-snap-size-row")
		local gbSnapBtn = doc:GetElementById("btn-gb-grid-snap")
		if gbSnapBtn then
			gbSnapBtn:AddEventListener("click", function(ev)
				if WG.TerraformBrush then
					local newVal = not getTFState().gridSnap
					playSound(newVal and "toggleOn" or "toggleOff")
					WG.TerraformBrush.setGridSnap(newVal)
					gbSnapBtn:SetClass("active", newVal)
					if gbSnapRow then gbSnapRow:SetClass("hidden", not newVal) end
				end
				ev:StopPropagation()
			end, false)
		end
		local gbMeasureRow = doc:GetElementById("gb-measure-toolbar-row")
		local gbMeasureBtn = doc:GetElementById("btn-gb-measure")
		if gbMeasureBtn then
			gbMeasureBtn:AddEventListener("click", function(ev)
				if WG.TerraformBrush then
					local newVal = not getTFState().measureActive
					playSound(newVal and "toggleOn" or "toggleOff")
					WG.TerraformBrush.setMeasureActive(newVal)
					gbMeasureBtn:SetClass("active", newVal)
					if gbMeasureRow then gbMeasureRow:SetClass("hidden", not newVal) end
				end
				ev:StopPropagation()
			end, false)
		end

		local gbSnapSlider = doc:GetElementById("gb-slider-grid-snap-size")
		if gbSnapSlider then
			gbSnapSlider:AddEventListener("change", function(ev)
				if uiState.updatingFromCode then ev:StopPropagation(); return end
				if WG.TerraformBrush then
					local v = tonumber(gbSnapSlider:GetAttribute("value")) or 48
					WG.TerraformBrush.setGridSnapSize(v)
				end
				ev:StopPropagation()
			end, false)
		end
		local function gbSnapStep(delta)
			if WG.TerraformBrush then
				local cur = tonumber(getTFState().gridSnapSize) or 48
				local v = math.max(16, math.min(128, cur + delta))
				WG.TerraformBrush.setGridSnapSize(v)
			end
		end
		local gsd = doc:GetElementById("gb-btn-snap-size-down")
		if gsd then gsd:AddEventListener("click", function(ev) gbSnapStep(-16); ev:StopPropagation() end, false) end
		local gsu = doc:GetElementById("gb-btn-snap-size-up")
		if gsu then gsu:AddEventListener("click", function(ev) gbSnapStep(16); ev:StopPropagation() end, false) end

		-- INSTRUMENTS: Protractor (angle snap) — shared state via WG.TerraformBrush
		local gbAngleRow = doc:GetElementById("gb-angle-snap-step-row")
		local gbAngleBtn = doc:GetElementById("btn-gb-angle-snap")
		if gbAngleBtn then
			gbAngleBtn:AddEventListener("click", function(ev)
				if WG.TerraformBrush then
					local newVal = not getTFState().angleSnap
					playSound(newVal and "toggleOn" or "toggleOff")
					WG.TerraformBrush.setAngleSnap(newVal)
					gbAngleBtn:SetClass("active", newVal)
					if gbAngleRow then gbAngleRow:SetClass("hidden", not newVal) end
				end
				ev:StopPropagation()
			end, false)
		end
		local GB_ANGLE_PRESETS = {7.5, 15, 30, 45, 60, 90}
		local function gbFindAnglePresetIdx(val)
			local best, bestD = 2, math.huge
			for i, p in ipairs(GB_ANGLE_PRESETS) do
				local d = math.abs(p - (val or 15))
				if d < bestD then bestD = d; best = i end
			end
			return best
		end
		local function gbApplyAnglePreset(idx)
			idx = math.max(1, math.min(#GB_ANGLE_PRESETS, idx))
			local pval = GB_ANGLE_PRESETS[idx]
			local pstr = (pval == math.floor(pval)) and tostring(math.floor(pval)) or tostring(pval)
			if WG.TerraformBrush then WG.TerraformBrush.setAngleSnapStep(pval) end
			local sl = doc:GetElementById("gb-slider-angle-snap-step")
			if sl then sl:SetAttribute("value", tostring(idx - 1)) end
			local lbl = doc:GetElementById("gb-angle-snap-step-label")
			if lbl then lbl.inner_rml = pstr end
			local nb = doc:GetElementById("gb-slider-angle-snap-step-numbox")
			if nb then nb:SetAttribute("value", pstr) end
		end
		local gbAngleSlider = doc:GetElementById("gb-slider-angle-snap-step")
		if gbAngleSlider then
			gbAngleSlider:AddEventListener("change", function(ev)
				if uiState.updatingFromCode then ev:StopPropagation(); return end
				local idx = (tonumber(gbAngleSlider:GetAttribute("value")) or 1) + 1
				gbApplyAnglePreset(idx)
				ev:StopPropagation()
			end, false)
		end
		local gbStepDn = doc:GetElementById("gb-btn-angle-step-down")
		if gbStepDn then gbStepDn:AddEventListener("click", function(ev)
			if WG.TerraformBrush then gbApplyAnglePreset(gbFindAnglePresetIdx(getTFState().angleSnapStep) - 1) end
			ev:StopPropagation()
		end, false) end
		local gbStepUp = doc:GetElementById("gb-btn-angle-step-up")
		if gbStepUp then gbStepUp:AddEventListener("click", function(ev)
			if WG.TerraformBrush then gbApplyAnglePreset(gbFindAnglePresetIdx(getTFState().angleSnapStep) + 1) end
			ev:StopPropagation()
		end, false) end
		local gbAutoBtn = doc:GetElementById("gb-btn-angle-autosnap")
		if gbAutoBtn then
			gbAutoBtn:AddEventListener("click", function(ev)
				if WG.TerraformBrush then
					local newVal = not getTFState().angleSnapAuto
					playSound(newVal and "toggleOn" or "toggleOff")
					WG.TerraformBrush.setAngleSnapAuto(newVal)
					gbAutoBtn:SetClass("active", newVal)
					local manualRow = doc:GetElementById("gb-angle-manual-spoke-row")
					if manualRow then manualRow:SetClass("hidden", newVal) end
				end
				ev:StopPropagation()
			end, false)
		end
		local gbManualSlider = doc:GetElementById("gb-slider-manual-spoke")
		local function gbApplyManualSpoke(idx)
			if WG.TerraformBrush then
				WG.TerraformBrush.setAngleSnapManualSpoke(idx)
				local step = getTFState().angleSnapStep or 15
				local deg  = (idx * step) % 360
				local lbl  = doc:GetElementById("gb-angle-manual-spoke-label")
				if lbl then lbl.inner_rml = tostring(deg) end
				if gbManualSlider then gbManualSlider:SetAttribute("value", tostring(idx)) end
			end
		end
		if gbManualSlider then
			gbManualSlider:AddEventListener("change", function(ev)
				if uiState.updatingFromCode then ev:StopPropagation(); return end
				gbApplyManualSpoke(tonumber(gbManualSlider:GetAttribute("value")) or 0)
				ev:StopPropagation()
			end, false)
		end
		local gbMsDn = doc:GetElementById("gb-btn-manual-spoke-down")
		if gbMsDn then gbMsDn:AddEventListener("click", function(ev)
			if WG.TerraformBrush then
				local s = getTFState()
				local step = s.angleSnapStep or 15
				local num  = math.max(1, math.floor(360 / step))
				gbApplyManualSpoke(((s.angleSnapManualSpoke or 0) - 1 + num) % num)
			end
			ev:StopPropagation()
		end, false) end
		local gbMsUp = doc:GetElementById("gb-btn-manual-spoke-up")
		if gbMsUp then gbMsUp:AddEventListener("click", function(ev)
			if WG.TerraformBrush then
				local s = getTFState()
				local step = s.angleSnapStep or 15
				local num  = math.max(1, math.floor(360 / step))
				gbApplyManualSpoke(((s.angleSnapManualSpoke or 0) + 1) % num)
			end
			ev:StopPropagation()
		end, false) end

		local function gbMeasureBtnClick(id, fn)
			local el = doc:GetElementById(id)
			if el then el:AddEventListener("click", function(ev) fn(); ev:StopPropagation() end, false) end
		end
		gbMeasureBtnClick("gb-btn-measure-ruler",       function() if WG.TerraformBrush then WG.TerraformBrush.setMeasureRulerMode(not getTFState().measureRulerMode) end end)
		gbMeasureBtnClick("gb-btn-measure-sticky",      function() if WG.TerraformBrush then WG.TerraformBrush.setMeasureStickyMode(not getTFState().measureStickyMode) end end)
		gbMeasureBtnClick("gb-btn-measure-show-length", function() if WG.TerraformBrush then WG.TerraformBrush.setMeasureShowLength(not getTFState().measureShowLength) end end)
		gbMeasureBtnClick("gb-btn-measure-clear",       function() if WG.TerraformBrush then WG.TerraformBrush.clearMeasureLines() end end)

		local gbSymRow = doc:GetElementById("gb-symmetry-toolbar-row")
		local gbSymBtn = doc:GetElementById("btn-gb-symmetry")
		if gbSymBtn then
			gbSymBtn:AddEventListener("click", function(ev)
				if WG.TerraformBrush then
					local s = getTFState()
					local newVal = not s.symmetryActive
					playSound(newVal and "toggleOn" or "toggleOff")
					WG.TerraformBrush.setSymmetryActive(newVal)
					if newVal and not (s.symmetryRadial or s.symmetryMirrorX or s.symmetryMirrorY) then
						WG.TerraformBrush.setSymmetryMirrorX(true)
						local mxBtn = doc:GetElementById("gb-btn-symmetry-mirror-x")
						if mxBtn then mxBtn:SetClass("active", true) end
					end
					gbSymBtn:SetClass("active", newVal)
					if gbSymRow then gbSymRow:SetClass("hidden", not newVal) end
				end
				ev:StopPropagation()
			end, false)
		end

		local function gbSymBtnClick(id, fn)
			local el = doc:GetElementById(id)
			if el then el:AddEventListener("click", function(ev) fn(); ev:StopPropagation() end, false) end
		end
		local function syncGbSymChipClasses()
			local s = getTFState()
			local radialEl = doc:GetElementById("gb-btn-symmetry-radial")
			local mxEl     = doc:GetElementById("gb-btn-symmetry-mirror-x")
			local myEl     = doc:GetElementById("gb-btn-symmetry-mirror-y")
			if radialEl then radialEl:SetClass("active", s.symmetryRadial and true or false) end
			if mxEl     then mxEl:SetClass("active",     s.symmetryMirrorX and true or false) end
			if myEl     then myEl:SetClass("active",     s.symmetryMirrorY and true or false) end
			local countRow = doc:GetElementById("gb-symmetry-radial-count-row")
			if countRow then countRow:SetClass("hidden", not s.symmetryRadial) end
			local angleRow = doc:GetElementById("gb-symmetry-mirror-angle-row")
			if angleRow then angleRow:SetClass("hidden", not (s.symmetryMirrorX or s.symmetryMirrorY)) end
		end
		gbSymBtnClick("gb-btn-symmetry-radial",    function() if WG.TerraformBrush then WG.TerraformBrush.setSymmetryRadial(not getTFState().symmetryRadial); syncGbSymChipClasses() end end)
		gbSymBtnClick("gb-btn-symmetry-mirror-x",  function() if WG.TerraformBrush then WG.TerraformBrush.setSymmetryMirrorX(not getTFState().symmetryMirrorX); syncGbSymChipClasses() end end)
		gbSymBtnClick("gb-btn-symmetry-mirror-y",  function() if WG.TerraformBrush then WG.TerraformBrush.setSymmetryMirrorY(not getTFState().symmetryMirrorY); syncGbSymChipClasses() end end)
		gbSymBtnClick("gb-btn-symmetry-place-origin",  function() if WG.TerraformBrush then WG.TerraformBrush.setSymmetryPlacingOrigin(true); playSound("toggleOn") end end)
		gbSymBtnClick("gb-btn-symmetry-center-origin", function() if WG.TerraformBrush then WG.TerraformBrush.setSymmetryOrigin(nil, nil); playSound("toggleOff") end end)
		gbSymBtnClick("gb-btn-symmetry-count-down", function()
			if WG.TerraformBrush then
				local c = math.max(2, (getTFState().symmetryRadialCount or 2) - 1)
				WG.TerraformBrush.setSymmetryRadialCount(c)
			end
		end)
		gbSymBtnClick("gb-btn-symmetry-count-up", function()
			if WG.TerraformBrush then
				local c = math.min(16, (getTFState().symmetryRadialCount or 2) + 1)
				WG.TerraformBrush.setSymmetryRadialCount(c)
			end
		end)
		gbSymBtnClick("gb-btn-symmetry-angle-down", function()
			if WG.TerraformBrush then
				local a = ((getTFState().symmetryMirrorAngle or 0) - 5) % 360
				WG.TerraformBrush.setSymmetryMirrorAngle(a)
			end
		end)
		gbSymBtnClick("gb-btn-symmetry-angle-up", function()
			if WG.TerraformBrush then
				local a = ((getTFState().symmetryMirrorAngle or 0) + 5) % 360
				WG.TerraformBrush.setSymmetryMirrorAngle(a)
			end
		end)

		local gbCountSlider = doc:GetElementById("gb-slider-symmetry-radial-count")
		if gbCountSlider then
			trackSliderDrag(gbCountSlider, "gb-symmetry-radial-count")
			gbCountSlider:AddEventListener("change", function(ev)
				if uiState.updatingFromCode then ev:StopPropagation(); return end
				if WG.TerraformBrush then
					local v = tonumber(gbCountSlider:GetAttribute("value")) or 2
					WG.TerraformBrush.setSymmetryRadialCount(v)
				end
				ev:StopPropagation()
			end, false)
		end
		local gbAngleSlider = doc:GetElementById("gb-slider-symmetry-mirror-angle")
		if gbAngleSlider then
			trackSliderDrag(gbAngleSlider, "gb-symmetry-mirror-angle")
			gbAngleSlider:AddEventListener("change", function(ev)
				if uiState.updatingFromCode then ev:StopPropagation(); return end
				if WG.TerraformBrush then
					local v = tonumber(gbAngleSlider:GetAttribute("value")) or 0
					WG.TerraformBrush.setSymmetryMirrorAngle(v)
				end
				ev:StopPropagation()
			end, false)
		end
	end
end

function M.sync(doc, ctx, gbState, setSummary, sumEl)
	local widgetState = ctx.widgetState
	local uiState = ctx.uiState
	local setActiveClass = ctx.setActiveClass
	local syncAndFlash = ctx.syncAndFlash
	local shapeNames = ctx.shapeNames
	local WG = ctx.WG

	local grassBtn = doc and doc:GetElementById("btn-grass")
	if grassBtn then grassBtn:SetClass("active", true) end
	setActiveClass(widgetState.modeButtons, nil)

	-- Grass sub-mode buttons
	setActiveClass(widgetState.gbSubModeButtons, gbState.subMode)

	-- Update clay button: unavailable in grass mode
	local clayBtnG = doc and doc:GetElementById("btn-clay-mode")
	if clayBtnG then
		clayBtnG:SetClass("unavailable", true)
	end

	-- Grass density slider & label sync
	if doc then
		uiState.updatingFromCode = true

		local gbDensityLabel = doc:GetElementById("gb-density-label")
		if gbDensityLabel then gbDensityLabel.inner_rml = tostring(math.floor(gbState.density * 100 + 0.5)) .. "%" end

		do
			local sv = math.floor(gbState.density * 100 + 0.5)
			syncAndFlash(doc:GetElementById("slider-grass-density"), "gb-density", tostring(sv))
		end

		-- Sync size, rotation, curve, length from grass brush own state
		do
			local gbSizeLabel = doc:GetElementById("gb-size-label")
			if gbSizeLabel then gbSizeLabel.inner_rml = tostring(gbState.radius or 100) end
			syncAndFlash(doc:GetElementById("slider-gb-size"), "gb-size", tostring(gbState.radius or 100))

			local gbRotLabel = doc:GetElementById("gb-rotation-label")
			if gbRotLabel then gbRotLabel.inner_rml = tostring(gbState.rotationDeg or 0) .. "&#176;" end
			syncAndFlash(doc:GetElementById("slider-gb-rotation"), "gb-rotation", tostring(gbState.rotationDeg or 0))

			local gbCurveLabel = doc:GetElementById("gb-curve-label")
			if gbCurveLabel then gbCurveLabel.inner_rml = string.format("%.1f", gbState.curve or 1.0) end
			syncAndFlash(doc:GetElementById("slider-gb-curve"), "gb-curve", tostring(math.floor((gbState.curve or 1.0) * 10 + 0.5)))

			local gbLenLabel = doc:GetElementById("gb-length-label")
			if gbLenLabel then gbLenLabel.inner_rml = string.format("%.1f", gbState.lengthScale or 1.0) end
			syncAndFlash(doc:GetElementById("slider-gb-length"), "gb-length", tostring(math.floor((gbState.lengthScale or 1.0) * 10 + 0.5)))
		end

		-- Smart filter UI sync
		do
			local smartOn = gbState.smartEnabled
			local smartToggle = doc:GetElementById("btn-gb-smart-toggle")
			if smartToggle then smartToggle:SetAttribute("src", smartOn and "/luaui/images/terraform_brush/check_on.png" or "/luaui/images/terraform_brush/check_off.png") end
			local smartOpts = doc:GetElementById("gb-smart-options")
			if smartOpts then smartOpts:SetClass("hidden", not smartOn) end

			-- Shared helper: only show the "Active" chip when the section is collapsed AND something is engaged
			local function syncSectionWarn(chipId, sectionId, anyActive)
				local sec = doc:GetElementById(sectionId)
				local collapsed = sec and sec:IsClassSet("hidden")
				local chip = doc:GetElementById(chipId)
				if chip then chip:SetClass("hidden", not (anyActive and collapsed)) end
			end

			-- FILTERS warn-chip (avoidWater excluded; defaults on).
			local sfEarly = gbState.smartFilters or {}
			local anyFilter = (smartOn and (sfEarly.avoidCliffs or sfEarly.preferSlopes or sfEarly.altMinEnable or sfEarly.altMaxEnable))
				or gbState.texFilterEnabled
			syncSectionWarn("warn-chip-gb-smart", "section-gb-smart", anyFilter and true or false)

			-- DISPLAY + INSTRUMENTS warn-chips (reflect shared TB state).
			local tbs = (WG.TerraformBrush and WG.TerraformBrush.getState()) or {}
			local dispActive = tbs.gridOverlay or tbs.heightColormap
			local instActive = tbs.gridSnap or tbs.angleSnap or tbs.measureActive or tbs.symmetryActive
			syncSectionWarn("warn-chip-gb-overlays",    "section-gb-overlays",    dispActive and true or false)
			syncSectionWarn("warn-chip-gb-instruments", "section-gb-instruments", instActive and true or false)

			local sf = gbState.smartFilters or {}
			local function syncSmartCheck(id, key)
				local el = doc:GetElementById(id)
				if el then el:SetAttribute("src", sf[key] and "/luaui/images/terraform_brush/check_on.png" or "/luaui/images/terraform_brush/check_off.png") end
			end
			syncSmartCheck("btn-gb-avoid-water",    "avoidWater")
			syncSmartCheck("btn-gb-avoid-cliffs",   "avoidCliffs")
			syncSmartCheck("btn-gb-prefer-slopes",  "preferSlopes")
			syncSmartCheck("btn-gb-alt-min-enable", "altMinEnable")
			syncSmartCheck("btn-gb-alt-max-enable", "altMaxEnable")

			local slopeMaxRow = doc:GetElementById("gb-smart-slope-max-row")
			local slopeMaxSl = doc:GetElementById("gb-smart-slope-max-slider-row")
			if slopeMaxRow then slopeMaxRow:SetClass("hidden", not sf.avoidCliffs) end
			if slopeMaxSl then slopeMaxSl:SetClass("hidden", not sf.avoidCliffs) end
			local slopeMaxLabel = doc:GetElementById("gb-smart-slope-max-label")
			if slopeMaxLabel then slopeMaxLabel.inner_rml = tostring(sf.slopeMax or 45) end
			syncAndFlash(doc:GetElementById("slider-gb-slope-max"), "gb-slope-max", tostring(sf.slopeMax or 45))

			local slopeMinRow = doc:GetElementById("gb-smart-slope-min-row")
			local slopeMinSl = doc:GetElementById("gb-smart-slope-min-slider-row")
			if slopeMinRow then slopeMinRow:SetClass("hidden", not sf.preferSlopes) end
			if slopeMinSl then slopeMinSl:SetClass("hidden", not sf.preferSlopes) end
			local slopeMinLabel = doc:GetElementById("gb-smart-slope-min-label")
			if slopeMinLabel then slopeMinLabel.inner_rml = tostring(sf.slopeMin or 10) end
			syncAndFlash(doc:GetElementById("slider-gb-slope-min"), "gb-slope-min", tostring(sf.slopeMin or 10))

			local altMinSl = doc:GetElementById("gb-smart-alt-min-slider-row")
			if altMinSl then altMinSl:SetClass("hidden", not sf.altMinEnable) end
			local altMinLabel = doc:GetElementById("gb-smart-alt-min-label")
			if altMinLabel then altMinLabel.inner_rml = tostring(sf.altMin or 0) end
			syncAndFlash(doc:GetElementById("slider-gb-alt-min"), "gb-alt-min", tostring(sf.altMin or 0))

			local altMaxSl = doc:GetElementById("gb-smart-alt-max-slider-row")
			if altMaxSl then altMaxSl:SetClass("hidden", not sf.altMaxEnable) end
			local altMaxLabel = doc:GetElementById("gb-smart-alt-max-label")
			if altMaxLabel then altMaxLabel.inner_rml = tostring(sf.altMax or 200) end
			syncAndFlash(doc:GetElementById("slider-gb-alt-max"), "gb-alt-max", tostring(sf.altMax or 200))

			-- Filter category chip active state mirrors whether any sub-filter is on
			local slopeActive = smartOn and (sf.avoidCliffs or sf.preferSlopes)
			local altActive   = smartOn and (sf.altMinEnable or sf.altMaxEnable)
			local slopeChip = doc:GetElementById("btn-gb-pill-slope")
			if slopeChip then slopeChip:SetClass("active", slopeActive and true or false) end
			local altChip = doc:GetElementById("btn-gb-pill-altitude")
			if altChip then altChip:SetClass("active", altActive and true or false) end
			local slopeContent = doc:GetElementById("gb-smart-slope-content")
			if slopeContent then slopeContent:SetClass("hidden", not slopeActive) end
			local altContent = doc:GetElementById("gb-smart-altitude-content")
			if altContent then altContent:SetClass("hidden", not altActive) end
		end

		-- Color filter UI sync
		do
			local colorOn = gbState.texFilterEnabled
			local colorToggle = doc:GetElementById("btn-gb-color-toggle")
			if colorToggle then colorToggle:SetAttribute("src", colorOn and "/luaui/images/terraform_brush/check_on.png" or "/luaui/images/terraform_brush/check_off.png") end
			local colorOpts = doc:GetElementById("gb-color-options")
			if colorOpts then colorOpts:SetClass("hidden", not colorOn) end
			-- Color chip drives texFilterEnabled now: mirror state onto chip + content
			local colorChip = doc:GetElementById("btn-gb-pill-color")
			if colorChip then colorChip:SetClass("active", colorOn) end
			local colorContent = doc:GetElementById("gb-smart-color-content")
			if colorContent then colorContent:SetClass("hidden", not colorOn) end

			local tc = gbState.texFilterColor or {}
			local swatchEl = doc:GetElementById("gb-tex-color-swatch")
			if swatchEl then
				local ri = math.floor(math.min(math.max(tc[1] or 0, 0), 1) * 255 + 0.5)
				local gi = math.floor(math.min(math.max(tc[2] or 0, 0), 1) * 255 + 0.5)
				local bi = math.floor(math.min(math.max(tc[3] or 0, 0), 1) * 255 + 0.5)
				swatchEl:SetAttribute("style", string.format("background-color: rgb(%d, %d, %d);", ri, gi, bi))
			end

			local pipBtn = doc:GetElementById("btn-gb-pipette")
			if pipBtn then pipBtn:SetClass("active", gbState.pipetteMode or false) end

			local threshVal = math.floor((gbState.texFilterThreshold or 0.35) * 100 + 0.5)
			syncAndFlash(doc:GetElementById("slider-gb-color-thresh"), "gb-color-thresh", tostring(threshVal))
			local threshLabel = doc:GetElementById("gb-color-thresh-label")
			if threshLabel then threshLabel.inner_rml = tostring(threshVal) end

			local padVal = gbState.texFilterPadding or 0
			syncAndFlash(doc:GetElementById("slider-gb-color-pad"), "gb-color-pad", tostring(math.floor(padVal + 0.5)))
			local padLabel = doc:GetElementById("gb-color-pad-label")
			if padLabel then padLabel.inner_rml = tostring(math.floor(padVal + 0.5)) end

			local exOn = gbState.texExcludeEnabled
			local exToggle = doc:GetElementById("btn-gb-exclude-toggle")
			if exToggle then exToggle:SetAttribute("src", exOn and "/luaui/images/terraform_brush/check_on.png" or "/luaui/images/terraform_brush/check_off.png") end

			local ec = gbState.texFilterColor or {}
			local exSwatchEl = doc:GetElementById("gb-tex-exclude-swatch")
			if exSwatchEl then
				local ri = math.floor(math.min(math.max(ec[5] or 0.65, 0), 1) * 255 + 0.5)
				local gi = math.floor(math.min(math.max(ec[6] or 0.35, 0), 1) * 255 + 0.5)
				local bi = math.floor(math.min(math.max(ec[7] or 0.10, 0), 1) * 255 + 0.5)
				exSwatchEl:SetAttribute("style", string.format("background-color: rgb(%d, %d, %d);", ri, gi, bi))
			end

			local exPipBtn = doc:GetElementById("btn-gb-exclude-pipette")
			if exPipBtn then exPipBtn:SetClass("active", gbState.pipetteExcludeMode or false) end
		end

		-- History slider sync
		do
			local histIdx = gbState.historyIndex or 0
			local histMax = gbState.historyMax or 0
			local slH = doc:GetElementById("slider-gb-history")
			if slH then
				slH:SetAttribute("max", tostring(histMax))
				syncAndFlash(slH, "gb-history", tostring(histIdx))
			end
			local numH = doc:GetElementById("slider-gb-history-numbox")
			if numH then numH:SetAttribute("value", tostring(histIdx)) end
		end

		uiState.updatingFromCode = false
	end

	-- Shape: use grass brush shape (own state)
	if gbState.shape then
		setActiveClass(widgetState.gbShapeButtons, gbState.shape)
	end

	-- Gray out ring and unsupported shapes
	for shape, element in pairs(widgetState.shapeButtons) do
		if element and shape ~= "ring" then
			element:SetClass("disabled", false)
		end
	end

	do
		local gApi = WG['grassgl4']
		local hasGrass = gApi and gApi.hasGrass and gApi.hasGrass()
		if not hasGrass then
			if sumEl then
				local sep = '<span class="tf-ss-sep">|</span>'
				sumEl.inner_rml = '<span class="tf-ss-mode" style="color: #10b981;">GRASS</span>' .. sep .. '<span class="tf-ss-val" style="color: #fbbf24;">No grass data for this map</span>'
			end
		else
			setSummary("GRASS", "#10b981",
				"", (gbState.subMode or "paint"):upper(),
				"", shapeNames[gbState.shape] or "Circle",
				"R ", tostring(gbState.radius or 0),
				"Density ", string.format("%.0f", (gbState.density or 0) * 100) .. "%")
		end
	end
end

return M
