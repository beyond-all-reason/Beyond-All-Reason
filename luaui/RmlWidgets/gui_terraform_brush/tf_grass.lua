-- tf_grass.lua â€” Grass Brush attach + sync (extracted from gui_terraform_brush.lua)
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
	widgetState.gbSubModeButtons = widgetState.gbSubModeButtons or {}
	widgetState.gbSubModeButtons.paint = doc:GetElementById("btn-gb-paint")
	widgetState.gbSubModeButtons.fill  = doc:GetElementById("btn-gb-fill")
	widgetState.gbSubModeButtons.erase = doc:GetElementById("btn-gb-erase")

	-- Slider drag tracking (legitimate imperative: slider-specific drag state).
	-- Slider change events wired declaratively via onchange= in RML.
	for _, sid in ipairs({
		"size", "rotation", "curve", "length",
		"slope-max", "slope-min", "alt-min", "alt-max",
		"color-thresh", "color-pad",
		"symmetry-radial-count", "symmetry-mirror-angle",
	}) do
		local sl = doc:GetElementById("slider-gb-" .. sid)
		if sl then trackSliderDrag(sl, "gb-" .. sid) end
	end
	do
		local sl = doc:GetElementById("slider-grass-density")
		if sl then trackSliderDrag(sl, "gb-density") end
		local slHist = doc:GetElementById("slider-gb-history")
		if slHist then trackSliderDrag(slHist, "gb-history") end
		local gbSnapSlider = doc:GetElementById("gb-slider-grid-snap-size")
		if gbSnapSlider then trackSliderDrag(gbSnapSlider, "gb-grid-snap-size") end
		local gbAngleSlider = doc:GetElementById("gb-slider-angle-snap-step")
		if gbAngleSlider then trackSliderDrag(gbAngleSlider, "gb-angle-snap-step") end
		local gbManualSlider = doc:GetElementById("gb-slider-manual-spoke")
		if gbManualSlider then trackSliderDrag(gbManualSlider, "gb-manual-spoke") end
	end

	-- Register widget methods for inline onclick/onchange handlers in RML.
	local w = ctx.widget
	if not w then return end

	-- Sub-mode
	w.gbSetSubMode = function(self, gbMode)
		playSound("modeSwitch")
		if WG.GrassBrush then WG.GrassBrush.setSubMode(gbMode) end
		setActiveClass(widgetState.gbSubModeButtons, gbMode)
	end

	-- Density
	w.gbOnDensityChange = function(self, element)
		if uiState.updatingFromCode or not WG.GrassBrush then return end
		local v = element and tonumber(element:GetAttribute("value")) or 80
		WG.GrassBrush.setDensity(v / 100)
		local label = doc:GetElementById("gb-density-label")
		if label then label.inner_rml = tostring(math.floor(v + 0.5)) .. "%" end
	end
	w.gbDensityUp = function(self)
		if not WG.GrassBrush then return end
		local s = WG.GrassBrush.getState()
		local cur = s and s.density or 0.8
		WG.GrassBrush.setDensity(math.min(1.0, cur + 0.05))
	end
	w.gbDensityDown = function(self)
		if not WG.GrassBrush then return end
		local s = WG.GrassBrush.getState()
		local cur = s and s.density or 0.8
		WG.GrassBrush.setDensity(math.max(0.0, cur - 0.05))
	end

	-- Save / Load / Clean
	w.gbSave = function(self)
			local grassApi = WG['grassgl4']
			if grassApi and grassApi.saveGrassTGA then
				playSound("save")
				grassApi.saveGrassTGA()
			end
	end
	w.gbLoad = function(self)
			local grassApi = WG['grassgl4']
			if grassApi and grassApi.loadGrass then grassApi.loadGrass() end
	end
	w.gbClean = function(self)
			playSound("undo")
			local grassApi = WG['grassgl4']
			if grassApi and grassApi.clearGrass then grassApi.clearGrass() end
	end

	-- Undo / Redo / History
	w.gbUndo = function(self)
		if WG.GrassBrush then playSound("undo"); WG.GrassBrush.undo() end
	end
	w.gbRedo = function(self)
		if WG.GrassBrush then playSound("redo"); WG.GrassBrush.redo() end
	end
	w.gbOnHistoryChange = function(self, element)
		if uiState.updatingFromCode or not WG.GrassBrush then return end
		local v = element and tonumber(element:GetAttribute("value")) or 0
		WG.GrassBrush.undoToIndex(v)
	end

	-- Size
	w.gbOnSizeChange = function(self, element)
		if uiState.updatingFromCode or not WG.GrassBrush then return end
		local val = element and tonumber(element:GetAttribute("value")) or 100
		WG.GrassBrush.setRadius(val)
	end
	w.gbSizeUp = function(self)
		if WG.GrassBrush then
			local s = WG.GrassBrush.getState()
			WG.GrassBrush.setRadius((s.radius or 100) + RADIUS_STEP)
		end
	end
	w.gbSizeDown = function(self)
		if WG.GrassBrush then
			local s = WG.GrassBrush.getState()
			WG.GrassBrush.setRadius((s.radius or 100) - RADIUS_STEP)
		end
	end

	-- Rotation
	w.gbOnRotChange = function(self, element)
		if uiState.updatingFromCode or not WG.GrassBrush then return end
		local val = element and tonumber(element:GetAttribute("value")) or 0
		WG.GrassBrush.setRotation(val)
	end
	w.gbRotCW = function(self)
		if WG.GrassBrush then
			local s = WG.GrassBrush.getState()
			WG.GrassBrush.setRotation((s.rotationDeg or 0) + ROTATION_STEP)
		end
	end
	w.gbRotCCW = function(self)
		if WG.GrassBrush then
			local s = WG.GrassBrush.getState()
			WG.GrassBrush.setRotation((s.rotationDeg or 0) - ROTATION_STEP)
		end
	end

	-- Curve
	w.gbOnCurveChange = function(self, element)
		if uiState.updatingFromCode or not WG.GrassBrush then return end
		local val = element and tonumber(element:GetAttribute("value")) or 10
		WG.GrassBrush.setCurve(val / 10)
	end
	w.gbCurveUp = function(self)
		if WG.GrassBrush then
			local s = WG.GrassBrush.getState()
			WG.GrassBrush.setCurve((s.curve or 1.0) + CURVE_STEP)
		end
	end
	w.gbCurveDown = function(self)
		if WG.GrassBrush then
			local s = WG.GrassBrush.getState()
			WG.GrassBrush.setCurve((s.curve or 1.0) - CURVE_STEP)
		end
	end

	-- Length
	w.gbOnLengthChange = function(self, element)
		if uiState.updatingFromCode or not WG.GrassBrush then return end
		local val = element and tonumber(element:GetAttribute("value")) or 10
		WG.GrassBrush.setLengthScale(val / 10)
	end
	w.gbLengthUp = function(self)
		if WG.GrassBrush then
			local s = WG.GrassBrush.getState()
			WG.GrassBrush.setLengthScale((s.lengthScale or 1.0) + 0.1)
		end
	end
	w.gbLengthDown = function(self)
		if WG.GrassBrush then
			local s = WG.GrassBrush.getState()
			WG.GrassBrush.setLengthScale((s.lengthScale or 1.0) - 0.1)
		end
	end

	-- Smart filter master toggle (checkbox img)
	w.gbSmartToggle = function(self)
		if not WG.GrassBrush then return end
		local st = WG.GrassBrush.getState()
		playSound(st.smartEnabled and "toggleOff" or "toggleOn")
		WG.GrassBrush.setSmartEnabled(not st.smartEnabled)
	end

	-- Smart filter sub-toggle (altMinEnable / altMaxEnable checkbox)
	w.gbSmartSubToggle = function(self, filterKey)
		if not WG.GrassBrush then return end
		local sf = WG.GrassBrush.getState().smartFilters
		playSound(sf[filterKey] and "toggleOff" or "toggleOn")
		WG.GrassBrush.setSmartFilter(filterKey, not sf[filterKey])
	end

	-- Slope pill: toggle slope section (avoidCliffs default when activating)
	-- Inline onclick replaces the broken wireGbFilterChip in tf_environment (content was nil due to data-if removal)
	w.gbPillSlope = function(self)
		if not WG.GrassBrush then return end
		local sf = WG.GrassBrush.getState().smartFilters or {}
		if sf.avoidCliffs or sf.preferSlopes then
			playSound("toggleOff")
			WG.GrassBrush.setSmartFilter("avoidCliffs", false)
			WG.GrassBrush.setSmartFilter("preferSlopes", false)
		else
			playSound("toggleOn")
			WG.GrassBrush.setSmartFilter("avoidCliffs", true)
		end
		local sf2 = WG.GrassBrush.getState().smartFilters or {}
		WG.GrassBrush.setSmartEnabled((sf2.avoidWater or sf2.avoidCliffs or sf2.preferSlopes or sf2.altMinEnable or sf2.altMaxEnable) and true or false)
	end

	-- Altitude pill: toggle altitude section (altMinEnable default when activating)
	w.gbPillAlt = function(self)
		if not WG.GrassBrush then return end
		local sf = WG.GrassBrush.getState().smartFilters or {}
		if sf.altMinEnable or sf.altMaxEnable then
			playSound("toggleOff")
			WG.GrassBrush.setSmartFilter("altMinEnable", false)
			WG.GrassBrush.setSmartFilter("altMaxEnable", false)
		else
			playSound("toggleOn")
			WG.GrassBrush.setSmartFilter("altMinEnable", true)
		end
		local sf2 = WG.GrassBrush.getState().smartFilters or {}
		WG.GrassBrush.setSmartEnabled((sf2.avoidWater or sf2.avoidCliffs or sf2.preferSlopes or sf2.altMinEnable or sf2.altMaxEnable) and true or false)
	end

	-- Slope mode sub-chips: mutually exclusive (inside gb-smart-slope-content, wired by inline onclick)
	-- wireMutexChipPair in tf_environment couldn't wire these because data-if removes them from DOM at attach time
	w.gbSlopeModeAvoid = function(self)
		if not WG.GrassBrush then return end
		local sf = WG.GrassBrush.getState().smartFilters or {}
		local newVal = not sf.avoidCliffs
		playSound(newVal and "toggleOn" or "toggleOff")
		if newVal then WG.GrassBrush.setSmartFilter("preferSlopes", false) end
		WG.GrassBrush.setSmartFilter("avoidCliffs", newVal)
		local sf2 = WG.GrassBrush.getState().smartFilters or {}
		WG.GrassBrush.setSmartEnabled((sf2.avoidWater or sf2.avoidCliffs or sf2.preferSlopes or sf2.altMinEnable or sf2.altMaxEnable) and true or false)
	end
	w.gbSlopeModePrefer = function(self)
		if not WG.GrassBrush then return end
		local sf = WG.GrassBrush.getState().smartFilters or {}
		local newVal = not sf.preferSlopes
		playSound(newVal and "toggleOn" or "toggleOff")
		if newVal then WG.GrassBrush.setSmartFilter("avoidCliffs", false) end
		WG.GrassBrush.setSmartFilter("preferSlopes", newVal)
		local sf2 = WG.GrassBrush.getState().smartFilters or {}
		WG.GrassBrush.setSmartEnabled((sf2.avoidWater or sf2.avoidCliffs or sf2.preferSlopes or sf2.altMinEnable or sf2.altMaxEnable) and true or false)
	end

	-- Altitude SAMPLE toggles (shared TerraformBrush)
	w.gbAltSample = function(self, target)
		if WG.TerraformBrush then
			local cur = (WG.TerraformBrush.getState() or {}).heightSamplingMode
			WG.TerraformBrush.setHeightSamplingMode(cur == target and nil or target)
		end
	end

	-- Slope / altitude slider onchange
	w.gbOnSlopeMaxChange = function(self, element)
		if uiState.updatingFromCode or not WG.GrassBrush then return end
		local v = element and tonumber(element:GetAttribute("value")) or 45
		WG.GrassBrush.setSmartFilter("slopeMax", v)
	end
	w.gbOnSlopeMinChange = function(self, element)
		if uiState.updatingFromCode or not WG.GrassBrush then return end
		local v = element and tonumber(element:GetAttribute("value")) or 10
		WG.GrassBrush.setSmartFilter("slopeMin", v)
	end
	w.gbOnAltMinChange = function(self, element)
		if uiState.updatingFromCode or not WG.GrassBrush then return end
		local v = element and tonumber(element:GetAttribute("value")) or 0
		WG.GrassBrush.setSmartFilter("altMin", v)
	end
	w.gbOnAltMaxChange = function(self, element)
		if uiState.updatingFromCode or not WG.GrassBrush then return end
		local v = element and tonumber(element:GetAttribute("value")) or 200
		WG.GrassBrush.setSmartFilter("altMax", v)
	end

	-- Slope / altitude stepper
	w.gbSmartStep = function(self, filterKey, step)
		if not WG.GrassBrush then return end
		local sf = WG.GrassBrush.getState().smartFilters
		WG.GrassBrush.setSmartFilter(filterKey, (sf[filterKey] or 0) + step)
	end

	-- Color filter
	w.gbColorToggle = function(self)
		if not WG.GrassBrush then return end
		local st = WG.GrassBrush.getState()
		playSound(st.texFilterEnabled and "toggleOff" or "toggleOn")
		WG.GrassBrush.setTexFilterEnabled(not st.texFilterEnabled)
	end
	w.gbPipette = function(self)
		if not WG.GrassBrush then return end
		local st = WG.GrassBrush.getState()
		if st.pipetteMode then
			WG.GrassBrush.setPipetteMode(false)
		else
			playSound("click")
			WG.GrassBrush.setPipetteMode(true)
		end
	end
	w.gbOnColorThreshChange = function(self, element)
		if uiState.updatingFromCode or not WG.GrassBrush then return end
		local v = element and tonumber(element:GetAttribute("value")) or 35
		WG.GrassBrush.setTexFilterThreshold(v / 100)
	end
	w.gbOnColorPadChange = function(self, element)
		if uiState.updatingFromCode or not WG.GrassBrush then return end
		local v = element and tonumber(element:GetAttribute("value")) or 0
		WG.GrassBrush.setTexFilterPadding(v)
	end
	w.gbExcludeToggle = function(self)
		if not WG.GrassBrush then return end
		local st = WG.GrassBrush.getState()
		playSound(st.texExcludeEnabled and "toggleOff" or "toggleOn")
		WG.GrassBrush.setTexExcludeEnabled(not st.texExcludeEnabled)
	end
	w.gbExcludePipette = function(self)
		if not WG.GrassBrush then return end
		local st = WG.GrassBrush.getState()
		if st.pipetteExcludeMode then
			WG.GrassBrush.setPipetteExcludeMode(false)
		else
			playSound("click")
			WG.GrassBrush.setPipetteExcludeMode(true)
		end
	end

	-- DISPLAY chips (shared TerraformBrush state)
	local function getTFState() return WG.TerraformBrush and WG.TerraformBrush.getState() or {} end
	w.gbToggleGridOverlay = function(self)
		if not WG.TerraformBrush then return end
		local newVal = not getTFState().gridOverlay
		playSound(newVal and "toggleOn" or "toggleOff")
		WG.TerraformBrush.setGridOverlay(newVal)
		local btn = doc:GetElementById("btn-gb-grid-overlay")
		if btn then btn:SetClass("active", newVal) end
	end
	w.gbToggleHeightMap = function(self)
		if not WG.TerraformBrush then return end
		local newVal = not getTFState().heightColormap
		playSound(newVal and "toggleOn" or "toggleOff")
		WG.TerraformBrush.setHeightColormap(newVal)
		local btn = doc:GetElementById("btn-gb-height-colormap")
		if btn then btn:SetClass("active", newVal) end
	end

	-- INSTRUMENTS chips (shared TerraformBrush state)
	w.gbToggleGridSnap = function(self)
		if not WG.TerraformBrush then return end
		local newVal = not getTFState().gridSnap
		playSound(newVal and "toggleOn" or "toggleOff")
		WG.TerraformBrush.setGridSnap(newVal)
		local btn = doc:GetElementById("btn-gb-grid-snap")
		if btn then btn:SetClass("active", newVal) end
		-- gb-grid-snap-size-row visibility driven by data-if="gbGridSnap"
	end
	w.gbToggleAngleSnap = function(self)
		if not WG.TerraformBrush then return end
		local newVal = not getTFState().angleSnap
		playSound(newVal and "toggleOn" or "toggleOff")
		WG.TerraformBrush.setAngleSnap(newVal)
		local btn = doc:GetElementById("btn-gb-angle-snap")
		if btn then btn:SetClass("active", newVal) end
		-- gb-angle-snap-step-row visibility driven by data-if="gbAngleSnap"
	end
	w.gbToggleMeasure = function(self)
		if not WG.TerraformBrush then return end
		local newVal = not getTFState().measureActive
		playSound(newVal and "toggleOn" or "toggleOff")
		WG.TerraformBrush.setMeasureActive(newVal)
		local btn = doc:GetElementById("btn-gb-measure")
		if btn then btn:SetClass("active", newVal) end
		-- gb-measure-toolbar-row visibility driven by data-if="gbMeasureActive"
	end
	w.gbToggleSymmetry = function(self)
		if not WG.TerraformBrush then return end
		local s = getTFState()
		local newVal = not s.symmetryActive
		playSound(newVal and "toggleOn" or "toggleOff")
		WG.TerraformBrush.setSymmetryActive(newVal)
		if newVal and not (s.symmetryRadial or s.symmetryMirrorX or s.symmetryMirrorY) then
			WG.TerraformBrush.setSymmetryMirrorX(true)
			local mxBtn = doc:GetElementById("gb-btn-symmetry-mirror-x")
			if mxBtn then mxBtn:SetClass("active", true) end
		end
		local btn = doc:GetElementById("btn-gb-symmetry")
		if btn then btn:SetClass("active", newVal) end
		-- gb-symmetry-toolbar-row visibility driven by data-if="gbSymmetryActive"
	end

	-- Grid snap size (shared TerraformBrush)
	w.gbOnSnapSizeChange = function(self, element)
		if uiState.updatingFromCode or not WG.TerraformBrush then return end
		local v = element and tonumber(element:GetAttribute("value")) or 48
		WG.TerraformBrush.setGridSnapSize(v)
	end
	local function gbSnapStep(delta)
		if WG.TerraformBrush then
			local cur = tonumber(getTFState().gridSnapSize) or 48
			local v = math.max(16, math.min(128, cur + delta))
			WG.TerraformBrush.setGridSnapSize(v)
		end
	end
	w.gbSnapSizeDown = function(self) gbSnapStep(-16) end
	w.gbSnapSizeUp   = function(self) gbSnapStep(16) end

	-- Protractor / angle step presets
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
	w.gbOnAngleStepChange = function(self, element)
		if uiState.updatingFromCode or not WG.TerraformBrush then return end
		local idx = (element and tonumber(element:GetAttribute("value")) or 1) + 1
		gbApplyAnglePreset(idx)
	end
	w.gbAngleStepDown = function(self)
		if WG.TerraformBrush then gbApplyAnglePreset(gbFindAnglePresetIdx(getTFState().angleSnapStep) - 1) end
	end
	w.gbAngleStepUp = function(self)
		if WG.TerraformBrush then gbApplyAnglePreset(gbFindAnglePresetIdx(getTFState().angleSnapStep) + 1) end
	end
	w.gbAngleAutoSnap = function(self)
		if not WG.TerraformBrush then return end
		local newVal = not getTFState().angleSnapAuto
		playSound(newVal and "toggleOn" or "toggleOff")
		WG.TerraformBrush.setAngleSnapAuto(newVal)
		local btn = doc:GetElementById("gb-btn-angle-autosnap")
		if btn then btn:SetClass("active", newVal) end
		-- gb-angle-manual-spoke-row visibility driven by data-if="!gbAngleSnapAuto"
	end

	-- Manual spoke
	local function gbApplyManualSpoke(idx)
		if WG.TerraformBrush then
			WG.TerraformBrush.setAngleSnapManualSpoke(idx)
			local step = getTFState().angleSnapStep or 15
			local deg  = (idx * step) % 360
			local lbl  = doc:GetElementById("gb-angle-manual-spoke-label")
			if lbl then lbl.inner_rml = tostring(deg) end
			local sl = doc:GetElementById("gb-slider-manual-spoke")
			if sl then sl:SetAttribute("value", tostring(idx)) end
		end
	end
	w.gbOnManualSpokeChange = function(self, element)
		if uiState.updatingFromCode or not WG.TerraformBrush then return end
		gbApplyManualSpoke(element and tonumber(element:GetAttribute("value")) or 0)
	end
	w.gbManualSpokeDown = function(self)
		if WG.TerraformBrush then
			local s = getTFState()
			local step = s.angleSnapStep or 15
			local num  = math.max(1, math.floor(360 / step))
			gbApplyManualSpoke(((s.angleSnapManualSpoke or 0) - 1 + num) % num)
		end
	end
	w.gbManualSpokeUp = function(self)
		if WG.TerraformBrush then
			local s = getTFState()
			local step = s.angleSnapStep or 15
			local num  = math.max(1, math.floor(360 / step))
			gbApplyManualSpoke(((s.angleSnapManualSpoke or 0) + 1) % num)
		end
	end

	-- Measure sub-row
	w.gbMeasureRuler      = function(self) if WG.TerraformBrush then WG.TerraformBrush.setMeasureRulerMode(not getTFState().measureRulerMode) end end
	w.gbMeasureSticky     = function(self) if WG.TerraformBrush then WG.TerraformBrush.setMeasureStickyMode(not getTFState().measureStickyMode) end end
	w.gbMeasureShowLength = function(self) if WG.TerraformBrush then WG.TerraformBrush.setMeasureShowLength(not getTFState().measureShowLength) end end
	w.gbMeasureClear      = function(self) if WG.TerraformBrush then WG.TerraformBrush.clearMeasureLines() end end

	-- Symmetry sub-row
	local function syncGbSymChipClasses()
		local s = getTFState()
		local radialEl = doc:GetElementById("gb-btn-symmetry-radial")
		local mxEl     = doc:GetElementById("gb-btn-symmetry-mirror-x")
		local myEl     = doc:GetElementById("gb-btn-symmetry-mirror-y")
		if radialEl then radialEl:SetClass("active", s.symmetryRadial and true or false) end
		if mxEl     then mxEl:SetClass("active",     s.symmetryMirrorX and true or false) end
		if myEl     then myEl:SetClass("active",     s.symmetryMirrorY and true or false) end
		-- gb-symmetry-radial-count-row visibility driven by data-if="gbSymmetryRadial"
		-- gb-symmetry-mirror-angle-row visibility driven by data-if="gbSymmetryMirrorAny"
	end
	w.gbSymRadial = function(self)
		if WG.TerraformBrush then WG.TerraformBrush.setSymmetryRadial(not getTFState().symmetryRadial); syncGbSymChipClasses() end
	end
	w.gbSymMirrorX = function(self)
		if WG.TerraformBrush then WG.TerraformBrush.setSymmetryMirrorX(not getTFState().symmetryMirrorX); syncGbSymChipClasses() end
	end
	w.gbSymMirrorY = function(self)
		if WG.TerraformBrush then WG.TerraformBrush.setSymmetryMirrorY(not getTFState().symmetryMirrorY); syncGbSymChipClasses() end
	end
	w.gbSymPlaceOrigin = function(self)
		if WG.TerraformBrush then WG.TerraformBrush.setSymmetryPlacingOrigin(true); playSound("toggleOn") end
	end
	w.gbSymCenterOrigin = function(self)
		if WG.TerraformBrush then WG.TerraformBrush.setSymmetryOrigin(nil, nil); playSound("toggleOff") end
	end
	w.gbSymCountDown = function(self)
		if WG.TerraformBrush then
			local c = math.max(2, (getTFState().symmetryRadialCount or 2) - 1)
			WG.TerraformBrush.setSymmetryRadialCount(c)
		end
	end
	w.gbSymCountUp = function(self)
		if WG.TerraformBrush then
			local c = math.min(16, (getTFState().symmetryRadialCount or 2) + 1)
			WG.TerraformBrush.setSymmetryRadialCount(c)
		end
	end
	w.gbSymAngleDown = function(self)
		if WG.TerraformBrush then
			local a = ((getTFState().symmetryMirrorAngle or 0) - 5) % 360
			WG.TerraformBrush.setSymmetryMirrorAngle(a)
		end
	end
	w.gbSymAngleUp = function(self)
		if WG.TerraformBrush then
			local a = ((getTFState().symmetryMirrorAngle or 0) + 5) % 360
			WG.TerraformBrush.setSymmetryMirrorAngle(a)
		end
	end
	w.gbOnSymCountChange = function(self, element)
		if uiState.updatingFromCode or not WG.TerraformBrush then return end
		local v = element and tonumber(element:GetAttribute("value")) or 2
		WG.TerraformBrush.setSymmetryRadialCount(v)
	end
	w.gbOnSymAngleChange = function(self, element)
		if uiState.updatingFromCode or not WG.TerraformBrush then return end
		local v = element and tonumber(element:GetAttribute("value")) or 0
		WG.TerraformBrush.setSymmetryMirrorAngle(v)
	end
end


function M.sync(doc, ctx, gbState, setSummary, sumEl)
	local widgetState = ctx.widgetState
	local uiState = ctx.uiState
	local setActiveClass = ctx.setActiveClass
	local syncAndFlash = ctx.syncAndFlash
	local shapeNames = ctx.shapeNames
	local WG = ctx.WG
	local dm = widgetState.dmHandle

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

	-- DISPLAY/INSTRUMENTS warn chips + instruments sub-row dm flags (data-if driven)
	do
		local s = WG.TerraformBrush and WG.TerraformBrush.getState and WG.TerraformBrush.getState()
		if s then
			local dispActive = s.gridOverlay or s.heightColormap
			local instActive = s.gridSnap or s.angleSnap or s.measureActive or s.symmetryActive
			if doc and ctx.syncWarnChip then
				local sfE = gbState.smartFilters or {}
				local anyFilter = (gbState.smartEnabled and (sfE.avoidCliffs or sfE.preferSlopes or sfE.altMinEnable or sfE.altMaxEnable))
					or gbState.texFilterEnabled
				ctx.syncWarnChip(doc, "warn-chip-gb-smart",       "section-gb-smart",       anyFilter and true or false)
				ctx.syncWarnChip(doc, "warn-chip-gb-overlays",    "section-gb-overlays",    dispActive and true or false)
				ctx.syncWarnChip(doc, "warn-chip-gb-instruments", "section-gb-instruments", instActive and true or false)
			end
			-- Sync active state on instrument chip buttons so they match TF state
			-- (SetClass("active") in toggle handlers only fires on click, not on mode entry)
			if doc then
				local function gbSetCls(id, on)
					local el = doc:GetElementById(id)
					if el then el:SetClass("active", on and true or false) end
				end
				gbSetCls("btn-gb-grid-overlay",    s.gridOverlay)
				gbSetCls("btn-gb-height-colormap", s.heightColormap)
				gbSetCls("btn-gb-grid-snap",       s.gridSnap)
				gbSetCls("btn-gb-angle-snap",      s.angleSnap)
				gbSetCls("btn-gb-measure",         s.measureActive)
				gbSetCls("btn-gb-symmetry",        s.symmetryActive)
			end
			if dm then
				dm.gbGridSnap        = s.gridSnap and true or false
				dm.gbAngleSnap       = s.angleSnap and true or false
				dm.gbMeasureActive   = s.measureActive and true or false
				dm.gbSymmetryActive  = s.symmetryActive and true or false
				dm.gbSymmetryRadial  = s.symmetryRadial and true or false
				dm.gbSymmetryMirrorAny = (s.symmetryMirrorX or s.symmetryMirrorY) and true or false
				dm.gbAngleSnapAuto   = s.angleSnapAuto and true or false
			end
		end
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
			-- gb-smart-options does not exist; warn chips handled above via ctx.syncWarnChip

			local sf = gbState.smartFilters or {}
			local function syncSmartCheck(id, key)
				local el = doc:GetElementById(id)
				if el then el:SetAttribute("src", sf[key] and "/luaui/images/terraform_brush/check_on.png" or "/luaui/images/terraform_brush/check_off.png") end
			end
			-- Pure toggle chips mirror their filter flag
			local function syncChipActive(id, key)
				local el = doc:GetElementById(id)
				if el then el:SetClass("active", sf[key] == true) end
			end
			syncChipActive("btn-gb-pill-avoid-water",  "avoidWater")
			-- Slope sub-chips mirror avoidCliffs / preferSlopes
			syncChipActive("gb-slope-mode-avoid",  "avoidCliffs")
			syncChipActive("gb-slope-mode-prefer", "preferSlopes")
			syncSmartCheck("btn-gb-alt-min-enable", "altMinEnable")
			syncSmartCheck("btn-gb-alt-max-enable", "altMaxEnable")

			-- gb-smart-slope-max-row/slider-row visibility driven by data-if="gbAvoidCliffs"
			local slopeMaxLabel = doc:GetElementById("gb-smart-slope-max-label")
			if slopeMaxLabel then slopeMaxLabel.inner_rml = tostring(sf.slopeMax or 45) end
			syncAndFlash(doc:GetElementById("slider-gb-slope-max"), "gb-slope-max", tostring(sf.slopeMax or 45))

			-- gb-smart-slope-min-row/slider-row visibility driven by data-if="gbPreferSlopes"
			local slopeMinLabel = doc:GetElementById("gb-smart-slope-min-label")
			if slopeMinLabel then slopeMinLabel.inner_rml = tostring(sf.slopeMin or 10) end
			syncAndFlash(doc:GetElementById("slider-gb-slope-min"), "gb-slope-min", tostring(sf.slopeMin or 10))

			-- gb-smart-alt-min-slider-row visibility driven by data-if="gbAltMinEnable"
			local altMinLabel = doc:GetElementById("gb-smart-alt-min-label")
			if altMinLabel then altMinLabel.inner_rml = tostring(sf.altMin or 0) end
			syncAndFlash(doc:GetElementById("slider-gb-alt-min"), "gb-alt-min", tostring(sf.altMin or 0))

			-- gb-smart-alt-max-slider-row visibility driven by data-if="gbAltMaxEnable"
			local altMaxLabel = doc:GetElementById("gb-smart-alt-max-label")
			if altMaxLabel then altMaxLabel.inner_rml = tostring(sf.altMax or 200) end
			syncAndFlash(doc:GetElementById("slider-gb-alt-max"), "gb-alt-max", tostring(sf.altMax or 200))

			-- SAMPLE button active state mirrors TerraformBrush heightSamplingMode
			local hsm = WG.TerraformBrush and (WG.TerraformBrush.getState() or {}).heightSamplingMode
			local sampMin = doc:GetElementById("btn-gb-alt-min-sample")
			if sampMin then sampMin:SetClass("active", hsm == "gbAltMin") end
			local sampMax = doc:GetElementById("btn-gb-alt-max-sample")
			if sampMax then sampMax:SetClass("active", hsm == "gbAltMax") end

			-- Filter category chip active state mirrors whether any sub-filter is on
			local slopeActive = smartOn and (sf.avoidCliffs or sf.preferSlopes)
			local altActive   = smartOn and (sf.altMinEnable or sf.altMaxEnable)
			local slopeChip = doc:GetElementById("btn-gb-pill-slope")
			if slopeChip then slopeChip:SetClass("active", slopeActive and true or false) end
			local altChip = doc:GetElementById("btn-gb-pill-altitude")
			if altChip then altChip:SetClass("active", altActive and true or false) end
			-- gb-smart-slope-content / gb-smart-altitude-content visibility driven by data-if
			if dm then
				dm.gbSlopeActive  = slopeActive and true or false
				dm.gbAvoidCliffs  = sf.avoidCliffs and true or false
				dm.gbPreferSlopes = sf.preferSlopes and true or false
				dm.gbAltActive    = altActive and true or false
				dm.gbAltMinEnable = sf.altMinEnable and true or false
				dm.gbAltMaxEnable = sf.altMaxEnable and true or false
			end
		end

		-- Color filter UI sync
		do
			local colorOn = gbState.texFilterEnabled
			local colorToggle = doc:GetElementById("btn-gb-color-toggle")
			if colorToggle then colorToggle:SetAttribute("src", colorOn and "/luaui/images/terraform_brush/check_on.png" or "/luaui/images/terraform_brush/check_off.png") end
			-- gb-color-options does not exist; gb-smart-color-content visibility driven by data-if="gbColorOpen"
			local colorChip = doc:GetElementById("btn-gb-pill-color")
			if colorChip then colorChip:SetClass("active", colorOn) end
			if dm then dm.gbColorOpen = colorOn and true or false end

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

	-- P3.2 Grass grayouts (per Phase 3 relevance matrix)
	if doc and ctx.setDisabledIds then
		local sm = gbState.subMode or "paint"
		local circular = (gbState.shape == "circle")
		local erase = (sm == "erase")
		local rotOff = erase or circular
		ctx.setDisabledIds(doc, {
			"slider-gb-rotation", "slider-gb-rotation-numbox",
			"btn-gb-rot-ccw", "btn-gb-rot-cw",
		}, rotOff)
		ctx.setDisabledIds(doc, {
			"slider-gb-length", "slider-gb-length-numbox",
			"btn-gb-length-down", "btn-gb-length-up",
		}, erase)
		ctx.setDisabledIds(doc, {
			"slider-gb-curve", "slider-gb-curve-numbox",
			"btn-gb-curve-down", "btn-gb-curve-up",
		}, erase)
		ctx.setDisabledIds(doc, {
			"slider-grass-density", "slider-grass-density-numbox",
			"btn-grass-density-down", "btn-grass-density-up",
		}, erase)
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
