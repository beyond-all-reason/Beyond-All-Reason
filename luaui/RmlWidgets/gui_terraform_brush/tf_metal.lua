-- tf_metal.lua — Metal Brush attach + sync (extracted from gui_terraform_brush.lua)
local M = {}

function M.attach(doc, ctx)
	local widgetState = ctx.widgetState
	local uiState = ctx.uiState
	local playSound = ctx.playSound
	local trackSliderDrag = ctx.trackSliderDrag
	local WG = ctx.WG
	local RADIUS_STEP = ctx.RADIUS_STEP
	local ROTATION_STEP = ctx.ROTATION_STEP
	local LENGTH_SCALE_STEP = ctx.LENGTH_SCALE_STEP
	local CURVE_STEP = ctx.CURVE_STEP

	widgetState.mbSubmodesEl = doc:GetElementById("tf-metal-submodes")
	widgetState.mbControlsEl = doc:GetElementById("tf-metal-controls")

	widgetState.mbSubModeButtons = {}

	-- Metal shape buttons (removed; metal now uses the shared tf-shape-row)
	widgetState.mbShapeButtons = {}

	-- Slider drag tracking (legitimate imperative: slider-specific drag state).
	-- Slider change events are wired declaratively via onchange= in RML.
	for _, entry in ipairs({
		{ "mb-slider-cluster-radius",            "mb-cluster-radius" },
		{ "mb-slider-axis-angle",                "mb-axis-angle" },
		{ "mb-slider-symmetry-radial-count",     "mb-symmetry-radial-count" },
		{ "mb-slider-symmetry-mirror-angle",     "mb-symmetry-mirror-angle" },
	}) do
		local sl = doc:GetElementById(entry[1])
		if sl then trackSliderDrag(sl, entry[2]) end
	end

	-- Register widget methods for inline onclick/onchange handlers in RML.
	local w = ctx.widget
	if not w then return end

	local function getTFState() return WG.TerraformBrush and WG.TerraformBrush.getState() or {} end
	local function mbGetMbState()
		return (WG.MetalBrush and WG.MetalBrush.getState and WG.MetalBrush.getState()) or {}
	end

	-- Sub-mode (paint / stamp / remove)
	w.mbSetSubMode = function(self, mbMode)
		playSound("modeSwitch")
		if WG.MetalBrush then WG.MetalBrush.setSubMode(mbMode) end
		if widgetState.dmHandle then widgetState.dmHandle.mbSubMode = mbMode end
	end

	-- Metal Value (log-mapped slider 0..1000 → 0.01..50.0)
	w.mbOnValueChange = function(self, element)
		if uiState.updatingFromCode or not WG.MetalBrush then return end
		local v = element and tonumber(element:GetAttribute("value")) or 0
		local mv = 0.01 * math.exp(v / 1000 * math.log(50.0 / 0.01))
		WG.MetalBrush.setMetalValue(mv)
		local mbLabel = doc:GetElementById("mb-value-label")
		if mbLabel then mbLabel.inner_rml = string.format("%.1f", mv) end
	end
	w.mbValueUp = function(self)
		if WG.MetalBrush then
			local s = WG.MetalBrush.getState()
			local cur = s and s.metalValue or 2.0
			WG.MetalBrush.setMetalValue(cur * 1.1)
		end
	end
	w.mbValueDown = function(self)
		if WG.MetalBrush then
			local s = WG.MetalBrush.getState()
			local cur = s and s.metalValue or 2.0
			WG.MetalBrush.setMetalValue(cur / 1.1)
		end
	end

	-- Save / Load / Clean (two-click confirm on clean)
	w.mbSave = function(self)
		playSound("save")
		if WG.MetalBrush then WG.MetalBrush.saveMetalMap() end
	end
	w.mbLoad = function(self)
		playSound("apply")
		if WG.MetalBrush then WG.MetalBrush.loadMetalMap() end
	end
	w.mbClean = function(self)
		local mbCleanBtn = doc:GetElementById("btn-metal-clean")
		local mbCleanLabel = doc:GetElementById("metal-clean-label")
		if (widgetState.metalCleanConfirmExpiry or 0) > 0 then
			widgetState.metalCleanConfirmExpiry = 0
			if mbCleanBtn then mbCleanBtn:SetClass("confirming", false) end
			if mbCleanLabel then mbCleanLabel.inner_rml = "CLEAN" end
			playSound("reset")
			if WG.MetalBrush then WG.MetalBrush.clearMetalMap() end
		else
			widgetState.metalCleanConfirmExpiry = (Spring.GetGameSeconds() or 0) + 3
			if mbCleanBtn then mbCleanBtn:SetClass("confirming", true) end
			if mbCleanLabel then mbCleanLabel.inner_rml = "ARE YOU SURE?" end
			playSound("toggleOn")
		end
	end

	-- Size (shared TerraformBrush radius)
	w.mbOnSizeChange = function(self, element)
		if uiState.updatingFromCode or not WG.TerraformBrush then return end
		local val = element and tonumber(element:GetAttribute("value")) or 100
		WG.TerraformBrush.setRadius(val)
	end
	w.mbSizeUp = function(self)
		if WG.TerraformBrush then
			local st = WG.TerraformBrush.getState()
			WG.TerraformBrush.setRadius(st.radius + RADIUS_STEP)
		end
	end
	w.mbSizeDown = function(self)
		if WG.TerraformBrush then
			local st = WG.TerraformBrush.getState()
			WG.TerraformBrush.setRadius(st.radius - RADIUS_STEP)
		end
	end

	-- Rotation (shared TerraformBrush)
	w.mbOnRotChange = function(self, element)
		if uiState.updatingFromCode or not WG.TerraformBrush then return end
		local val = element and tonumber(element:GetAttribute("value")) or 0
		WG.TerraformBrush.setRotation(val)
	end
	w.mbRotCW = function(self)
		if WG.TerraformBrush then WG.TerraformBrush.rotate(ROTATION_STEP) end
	end
	w.mbRotCCW = function(self)
		if WG.TerraformBrush then WG.TerraformBrush.rotate(-ROTATION_STEP) end
	end

	-- Length (shared TerraformBrush)
	w.mbOnLengthChange = function(self, element)
		if uiState.updatingFromCode or not WG.TerraformBrush then return end
		local val = element and tonumber(element:GetAttribute("value")) or 10
		WG.TerraformBrush.setLengthScale(val / 10)
	end
	w.mbLengthUp = function(self)
		if WG.TerraformBrush then
			local st = WG.TerraformBrush.getState()
			WG.TerraformBrush.setLengthScale(st.lengthScale + LENGTH_SCALE_STEP)
		end
	end
	w.mbLengthDown = function(self)
		if WG.TerraformBrush then
			local st = WG.TerraformBrush.getState()
			WG.TerraformBrush.setLengthScale(st.lengthScale - LENGTH_SCALE_STEP)
		end
	end

	-- Curve / fall-off (shared TerraformBrush)
	w.mbOnCurveChange = function(self, element)
		if uiState.updatingFromCode or not WG.TerraformBrush then return end
		local val = element and tonumber(element:GetAttribute("value")) or 10
		WG.TerraformBrush.setCurve(val / 10)
	end
	w.mbCurveUp = function(self)
		if WG.TerraformBrush then
			local st = WG.TerraformBrush.getState()
			WG.TerraformBrush.setCurve(st.curve + CURVE_STEP)
		end
	end
	w.mbCurveDown = function(self)
		if WG.TerraformBrush then
			local st = WG.TerraformBrush.getState()
			WG.TerraformBrush.setCurve(st.curve - CURVE_STEP)
		end
	end

	-- ── DISPLAY chips (forward to shared WG.TerraformBrush state) ──
	local function chipToggleTB(id, getCur, setter)
		local newVal = not getCur()
		playSound(newVal and "toggleOn" or "toggleOff")
		setter(newVal)
		local el = doc:GetElementById(id)
		if el then el:SetClass("active", newVal) end
	end
	w.mbToggleGridOverlay = function(self)
		if WG.TerraformBrush then
			chipToggleTB("btn-mb-grid-overlay",
				function() return getTFState().gridOverlay end,
				function(v) WG.TerraformBrush.setGridOverlay(v) end)
		end
	end
	w.mbToggleHeightColormap = function(self)
		if WG.TerraformBrush then
			chipToggleTB("btn-mb-height-colormap",
				function() return getTFState().heightColormap end,
				function(v) WG.TerraformBrush.setHeightColormap(v) end)
		end
	end

	-- ── INSTRUMENTS: Grid Snap ──
	w.mbToggleGridSnap = function(self)
		if not WG.TerraformBrush then return end
		local newVal = not getTFState().gridSnap
		playSound(newVal and "toggleOn" or "toggleOff")
		WG.TerraformBrush.setGridSnap(newVal)
		local snapBtn = doc:GetElementById("btn-mb-grid-snap")
		if snapBtn then snapBtn:SetClass("active", newVal) end
		-- mb-grid-snap-size-row visibility driven by data-if="mbGridSnap"
	end
	w.mbOnSnapSizeChange = function(self, element)
		if uiState.updatingFromCode or not WG.TerraformBrush then return end
		local v = element and tonumber(element:GetAttribute("value")) or 48
		WG.TerraformBrush.setGridSnapSize(v)
	end
	w.mbSnapSizeStep = function(self, delta)
		if WG.TerraformBrush then
			local cur = tonumber(getTFState().gridSnapSize) or 48
			local v = math.max(16, math.min(128, cur + delta))
			WG.TerraformBrush.setGridSnapSize(v)
		end
	end

	-- ── INSTRUMENTS: Protractor (angle snap) ──
	w.mbToggleAngleSnap = function(self)
		if not WG.TerraformBrush then return end
		local newVal = not getTFState().angleSnap
		playSound(newVal and "toggleOn" or "toggleOff")
		WG.TerraformBrush.setAngleSnap(newVal)
		local angleBtn = doc:GetElementById("btn-mb-angle-snap")
		if angleBtn then angleBtn:SetClass("active", newVal) end
		-- mb-angle-snap-step-row visibility driven by data-if="mbAngleSnap"
	end

	local MB_ANGLE_PRESETS = { 7.5, 15, 30, 45, 60, 90 }
	local function mbFindAnglePresetIdx(val)
		local best, bestD = 2, math.huge
		for i, p in ipairs(MB_ANGLE_PRESETS) do
			local d = math.abs(p - (val or 15))
			if d < bestD then bestD = d; best = i end
		end
		return best
	end
	local function mbApplyAnglePreset(idx)
		idx = math.max(1, math.min(#MB_ANGLE_PRESETS, idx))
		local pval = MB_ANGLE_PRESETS[idx]
		local pstr = (pval == math.floor(pval)) and tostring(math.floor(pval)) or tostring(pval)
		if WG.TerraformBrush then WG.TerraformBrush.setAngleSnapStep(pval) end
		local sl = doc:GetElementById("mb-slider-angle-snap-step")
		if sl then sl:SetAttribute("value", tostring(idx - 1)) end
		local lbl = doc:GetElementById("mb-angle-snap-step-label")
		if lbl then lbl.inner_rml = pstr end
		local nb = doc:GetElementById("mb-slider-angle-snap-step-numbox")
		if nb then nb:SetAttribute("value", pstr) end
	end
	w.mbOnAngleStepChange = function(self, element)
		if uiState.updatingFromCode then return end
		local idx = (element and tonumber(element:GetAttribute("value")) or 1) + 1
		mbApplyAnglePreset(idx)
	end
	w.mbAngleStepStep = function(self, delta)
		if WG.TerraformBrush then
			mbApplyAnglePreset(mbFindAnglePresetIdx(getTFState().angleSnapStep) + delta)
		end
	end
	w.mbToggleAutoSnap = function(self)
		if not WG.TerraformBrush then return end
		local newVal = not getTFState().angleSnapAuto
		playSound(newVal and "toggleOn" or "toggleOff")
		WG.TerraformBrush.setAngleSnapAuto(newVal)
		local autoBtn = doc:GetElementById("mb-btn-angle-autosnap")
		if autoBtn then autoBtn:SetClass("active", newVal) end
		-- mb-angle-manual-spoke-row visibility driven by data-if="!mbAngleSnapAuto"
	end
	w.mbOnManualSpokeChange = function(self, element)
		if uiState.updatingFromCode or not WG.TerraformBrush then return end
		local idx = element and tonumber(element:GetAttribute("value")) or 0
		WG.TerraformBrush.setAngleSnapManualSpoke(idx)
	end
	w.mbManualSpokeStep = function(self, delta)
		if WG.TerraformBrush then
			local s = getTFState()
			local step = s.angleSnapStep or 15
			local num = math.max(1, math.floor(360 / step))
			local cur = s.angleSnapManualSpoke or 0
			WG.TerraformBrush.setAngleSnapManualSpoke((cur + delta + num) % num)
		end
	end

	-- ── INSTRUMENTS: Measure ──
	w.mbToggleMeasure = function(self)
		if not WG.TerraformBrush then return end
		local newVal = not getTFState().measureActive
		playSound(newVal and "toggleOn" or "toggleOff")
		WG.TerraformBrush.setMeasureActive(newVal)
		local measureBtn = doc:GetElementById("btn-mb-measure")
		if measureBtn then measureBtn:SetClass("active", newVal) end
		-- mb-measure-toolbar-row visibility driven by data-if="mbMeasureActive"
	end
	w.mbMeasureRuler = function(self)
		if WG.TerraformBrush then WG.TerraformBrush.setMeasureRulerMode(not getTFState().measureRulerMode) end
	end
	w.mbMeasureSticky = function(self)
		if WG.TerraformBrush then WG.TerraformBrush.setMeasureStickyMode(not getTFState().measureStickyMode) end
	end
	w.mbMeasureShowLength = function(self)
		if WG.TerraformBrush then WG.TerraformBrush.setMeasureShowLength(not getTFState().measureShowLength) end
	end
	w.mbMeasureClear = function(self)
		if WG.TerraformBrush then WG.TerraformBrush.clearMeasureLines() end
	end

	-- ── INSTRUMENTS: Symmetry ──
	local function syncSymChipClasses()
		local s = getTFState()
		local radialEl = doc:GetElementById("mb-btn-symmetry-radial")
		local mxEl     = doc:GetElementById("mb-btn-symmetry-mirror-x")
		local myEl     = doc:GetElementById("mb-btn-symmetry-mirror-y")
		if radialEl then radialEl:SetClass("active", s.symmetryRadial and true or false) end
		if mxEl     then mxEl:SetClass("active",     s.symmetryMirrorX and true or false) end
		if myEl     then myEl:SetClass("active",     s.symmetryMirrorY and true or false) end
		-- mb-symmetry-radial-count-row, mb-symmetry-mirror-angle-row driven by data-if
	end

	w.mbToggleSymmetry = function(self)
		if not WG.TerraformBrush then return end
		local s = getTFState()
		local newVal = not s.symmetryActive
		playSound(newVal and "toggleOn" or "toggleOff")
		WG.TerraformBrush.setSymmetryActive(newVal)
		-- If enabling with no sub-mode selected, default to mirror-X so there's visible fan-out
		if newVal and not (s.symmetryRadial or s.symmetryMirrorX or s.symmetryMirrorY) then
			WG.TerraformBrush.setSymmetryMirrorX(true)
			local mxBtn = doc:GetElementById("mb-btn-symmetry-mirror-x")
			if mxBtn then mxBtn:SetClass("active", true) end
		end
		local symBtn = doc:GetElementById("btn-mb-symmetry")
		if symBtn then symBtn:SetClass("active", newVal) end
		-- mb-symmetry-toolbar-row visibility driven by data-if="mbSymmetryActive"
	end
	w.mbToggleSymRadial = function(self)
		if WG.TerraformBrush then
			WG.TerraformBrush.setSymmetryRadial(not getTFState().symmetryRadial)
			syncSymChipClasses()
		end
	end
	w.mbToggleSymMirrorX = function(self)
		if WG.TerraformBrush then
			WG.TerraformBrush.setSymmetryMirrorX(not getTFState().symmetryMirrorX)
			syncSymChipClasses()
		end
	end
	w.mbToggleSymMirrorY = function(self)
		if WG.TerraformBrush then
			WG.TerraformBrush.setSymmetryMirrorY(not getTFState().symmetryMirrorY)
			syncSymChipClasses()
		end
	end
	w.mbSymPlaceOrigin = function(self)
		if WG.TerraformBrush then
			WG.TerraformBrush.setSymmetryPlacingOrigin(true)
			playSound("toggleOn")
		end
	end
	w.mbSymCenterOrigin = function(self)
		if WG.TerraformBrush then
			WG.TerraformBrush.setSymmetryOrigin(nil, nil)
			playSound("toggleOff")
		end
	end
	w.mbSymCountDown = function(self)
		if WG.TerraformBrush then
			local c = math.max(2, (getTFState().symmetryRadialCount or 2) - 1)
			WG.TerraformBrush.setSymmetryRadialCount(c)
		end
	end
	w.mbSymCountUp = function(self)
		if WG.TerraformBrush then
			local c = math.min(16, (getTFState().symmetryRadialCount or 2) + 1)
			WG.TerraformBrush.setSymmetryRadialCount(c)
		end
	end
	w.mbOnSymCountChange = function(self, element)
		if uiState.updatingFromCode or not WG.TerraformBrush then return end
		local v = element and tonumber(element:GetAttribute("value")) or 2
		WG.TerraformBrush.setSymmetryRadialCount(v)
	end
	w.mbSymAngleDown = function(self)
		if WG.TerraformBrush then
			local a = ((getTFState().symmetryMirrorAngle or 0) - 5) % 360
			WG.TerraformBrush.setSymmetryMirrorAngle(a)
		end
	end
	w.mbSymAngleUp = function(self)
		if WG.TerraformBrush then
			local a = ((getTFState().symmetryMirrorAngle or 0) + 5) % 360
			WG.TerraformBrush.setSymmetryMirrorAngle(a)
		end
	end
	w.mbOnSymAngleChange = function(self, element)
		if uiState.updatingFromCode or not WG.TerraformBrush then return end
		local v = element and tonumber(element:GetAttribute("value")) or 0
		WG.TerraformBrush.setSymmetryMirrorAngle(v)
	end

	-- ── METAL MAP analysis (full-map overlay, clusters, lasso, balance axis) ──
	w.mbToggleMapOverlay = function(self)
		if not WG.MetalBrush then return end
		local newVal = not mbGetMbState().mapOverlay
		playSound(newVal and "toggleOn" or "toggleOff")
		WG.MetalBrush.setMapOverlay(newVal)
	end
	w.mbToggleClusters = function(self)
		if not WG.MetalBrush then return end
		local newVal = not mbGetMbState().clusterCounter
		playSound(newVal and "toggleOn" or "toggleOff")
		WG.MetalBrush.setClusterCounter(newVal)
	end
	w.mbToggleInspector = function(self)
		local st = mbGetMbState()
		local open = not (widgetState.mbInspectorOpen or false)
		widgetState.mbInspectorOpen = open
		playSound(open and "toggleOn" or "toggleOff")
		if not open and WG.MetalBrush then
			if st.clusterCounter then WG.MetalBrush.setClusterCounter(false) end
			if st.lassoActive or st.lassoClosed then WG.MetalBrush.clearLasso() end
			if st.balanceAxisActive then WG.MetalBrush.setBalanceAxisActive(false) end
		end
	end
	w.mbToggleLasso = function(self)
		if not WG.MetalBrush then return end
		local newVal = not mbGetMbState().lassoActive
		playSound(newVal and "toggleOn" or "toggleOff")
		if newVal then WG.MetalBrush.startLasso() else WG.MetalBrush.clearLasso() end
	end
	w.mbLassoClose = function(self)
		if WG.MetalBrush then playSound("apply"); WG.MetalBrush.finishLasso() end
	end
	w.mbLassoClear = function(self)
		if WG.MetalBrush then playSound("reset"); WG.MetalBrush.clearLasso() end
	end
	w.mbToggleBalanceAxis = function(self)
		if not WG.MetalBrush then return end
		local newVal = not mbGetMbState().balanceAxisActive
		playSound(newVal and "toggleOn" or "toggleOff")
		WG.MetalBrush.setBalanceAxisActive(newVal)
	end
	w.mbAxisX = function(self)
		if WG.MetalBrush then playSound("modeSwitch"); WG.MetalBrush.setBalanceAxisAngle(0) end
	end
	w.mbAxisZ = function(self)
		if WG.MetalBrush then playSound("modeSwitch"); WG.MetalBrush.setBalanceAxisAngle(90) end
	end
	w.mbAxisPlace = function(self)
		if WG.MetalBrush then playSound("modeSwitch"); WG.MetalBrush.setBalanceAxisPlacingOrigin(true) end
	end
	w.mbAxisCenter = function(self)
		if WG.MetalBrush then playSound("reset"); WG.MetalBrush.setBalanceAxisOrigin(nil, nil) end
	end
	w.mbOnAxisAngleChange = function(self, element)
		if uiState.updatingFromCode or not WG.MetalBrush then return end
		local v = element and tonumber(element:GetAttribute("value")) or 0
		WG.MetalBrush.setBalanceAxisAngle(v)
	end
	w.mbAxisAngleDown = function(self)
		if WG.MetalBrush then
			local cur = tonumber(mbGetMbState().balanceAxisAngleDeg) or 0
			WG.MetalBrush.setBalanceAxisAngle(cur - 5)
		end
	end
	w.mbAxisAngleUp = function(self)
		if WG.MetalBrush then
			local cur = tonumber(mbGetMbState().balanceAxisAngleDeg) or 0
			WG.MetalBrush.setBalanceAxisAngle(cur + 5)
		end
	end
	w.mbOnClusterRadiusChange = function(self, element)
		if uiState.updatingFromCode or not WG.MetalBrush then return end
		local v = element and tonumber(element:GetAttribute("value")) or 256
		WG.MetalBrush.setClusterRadius(v)
		local lbl = doc:GetElementById("mb-cluster-radius-label")
		if lbl then lbl.inner_rml = tostring(v) end
	end
	w.mbClusterRadiusDown = function(self)
		if WG.MetalBrush then
			local cur = tonumber(mbGetMbState().clusterRadius) or 256
			WG.MetalBrush.setClusterRadius(math.max(64, cur - 32))
		end
	end
	w.mbClusterRadiusUp = function(self)
		if WG.MetalBrush then
			local cur = tonumber(mbGetMbState().clusterRadius) or 256
			WG.MetalBrush.setClusterRadius(math.min(1024, cur + 32))
		end
	end
end

function M.sync(doc, ctx, mbState, setSummary)
	local widgetState = ctx.widgetState
	local uiState = ctx.uiState
	local syncAndFlash = ctx.syncAndFlash
	local WG = ctx.WG
	local dm = widgetState.dmHandle

	local metalBtn = doc and doc:GetElementById("btn-metal")
	if metalBtn then metalBtn:SetClass("active", true) end


	-- DISPLAY/INSTRUMENTS warn chips (shared TB state mirror)
	if doc and ctx.syncWarnChip then
		local tbs = (WG.TerraformBrush and WG.TerraformBrush.getState()) or {}
		local dispActive = tbs.gridOverlay or tbs.heightColormap
		local instActive = tbs.gridSnap or tbs.angleSnap or tbs.measureActive or tbs.symmetryActive
		ctx.syncWarnChip(doc, "warn-chip-mb-overlays",    "section-mb-overlays",    dispActive)
		ctx.syncWarnChip(doc, "warn-chip-mb-instruments", "section-mb-instruments", instActive)
	end

	-- Metal sub-mode buttons (driven by dm.mbSubMode via data-class-active)
	if widgetState.dmHandle then widgetState.dmHandle.mbSubMode = mbState.subMode or "paint" end

	-- Instruments sub-row visibility flags (data-if driven)
	do
		local s = WG.TerraformBrush and WG.TerraformBrush.getState and WG.TerraformBrush.getState()
		if dm and s then
			dm.mbGridSnap        = s.gridSnap and true or false
			dm.mbAngleSnap       = s.angleSnap and true or false
			dm.mbMeasureActive   = s.measureActive and true or false
			dm.mbSymmetryActive  = s.symmetryActive and true or false
			dm.mbSymmetryRadial  = s.symmetryRadial and true or false
			dm.mbSymmetryMirrorAny = (s.symmetryMirrorX or s.symmetryMirrorY) and true or false
			dm.mbAngleSnapAuto   = s.angleSnapAuto and true or false
		end
	end

	-- Metal value slider & label sync
	if doc then
		uiState.updatingFromCode = true

		local mbValueLabel = doc:GetElementById("mb-value-label")
		if mbValueLabel then mbValueLabel.inner_rml = string.format("%.1f", mbState.metalValue) end

		do
			local mv = math.max(0.01, mbState.metalValue)
			local sv = math.floor(1000 * math.log(mv / 0.01) / math.log(50.0 / 0.01) + 0.5)
			syncAndFlash(doc:GetElementById("slider-metal-value"), "mb-value", tostring(sv))
		end

		-- Sync size, rotation, length, curve from shared terraform state
		local tfSt2 = WG.TerraformBrush and WG.TerraformBrush.getState()
		if tfSt2 then
			local mbSizeLabel = doc:GetElementById("mb-size-label")
			if mbSizeLabel then mbSizeLabel.inner_rml = tostring(tfSt2.radius) end
			syncAndFlash(doc:GetElementById("slider-mb-size"), "mb-size", tostring(tfSt2.radius))

			local mbRotLabel = doc:GetElementById("mb-rotation-label")
			if mbRotLabel then mbRotLabel.inner_rml = tostring(tfSt2.rotationDeg) .. "&#176;" end
			syncAndFlash(doc:GetElementById("slider-mb-rotation"), "mb-rotation", tostring(tfSt2.rotationDeg))

			local mbLenLabel = doc:GetElementById("mb-length-label")
			if mbLenLabel then mbLenLabel.inner_rml = string.format("%.1f", tfSt2.lengthScale) end
			syncAndFlash(doc:GetElementById("slider-mb-length"), "mb-length", tostring(math.floor(tfSt2.lengthScale * 10 + 0.5)))

			local mbCurveLabel = doc:GetElementById("mb-curve-label")
			if mbCurveLabel then mbCurveLabel.inner_rml = string.format("%.1f", tfSt2.curve) end
			syncAndFlash(doc:GetElementById("slider-mb-curve"), "mb-curve", tostring(math.floor(tfSt2.curve * 10 + 0.5)))
		end

		uiState.updatingFromCode = false
	end

	-- Shape: use terraform brush shape (shared)
	local tfSt = WG.TerraformBrush and WG.TerraformBrush.getState()
	if tfSt then
		if widgetState.dmHandle then widgetState.dmHandle.activeShape = tfSt.shape or "circle" end
	end

	-- P3.2 Metal grayouts (per Phase 3 relevance matrix)
	if doc and tfSt then
		local sm = mbState.subMode or "stamp"
		local circular = (tfSt.shape == "circle")
		local nonStamp = (sm ~= "stamp")
		-- Rotation: stamp mode AND non-circular shape
		local rotOff = nonStamp or circular
		ctx.setDisabledIds(doc, {
			"slider-mb-rotation", "slider-mb-rotation-numbox",
			"btn-mb-rot-ccw", "btn-mb-rot-cw",
		}, rotOff)
		-- Length: stamp mode AND non-circular shape
		ctx.setDisabledIds(doc, {
			"slider-mb-length", "slider-mb-length-numbox",
			"btn-mb-length-down", "btn-mb-length-up",
		}, rotOff)
		-- Curve/Fall-off: stamp mode only
		ctx.setDisabledIds(doc, {
			"slider-mb-curve", "slider-mb-curve-numbox",
			"btn-mb-curve-down", "btn-mb-curve-up",
		}, nonStamp)
		-- Metal Value: disabled in remove submode
		local valueOff = (sm == "remove")
		ctx.setDisabledIds(doc, {
			"slider-metal-value", "slider-metal-value-numbox",
			"btn-metal-value-down", "btn-metal-value-up",
		}, valueOff)
	end

	do
		local tfSt2 = WG.TerraformBrush and WG.TerraformBrush.getState()
		local sm = mbState.subMode or "paint"
		setSummary("METAL", "#14b8a6",
			"", sm:upper(),
			"R ", tostring(tfSt2 and tfSt2.radius or "?"),
			"Val ", string.format("%.1f", mbState.metalValue or 0),
			"Crv ", string.format("%.1f", tfSt2 and tfSt2.curve or 0))
	end

	-- Metal map analysis chip/slider sync
	if doc then
		local overlayChip = doc:GetElementById("btn-mb-mapoverlay")
		if overlayChip then overlayChip:SetClass("active", mbState.mapOverlay and true or false) end
		local clusterChip = doc:GetElementById("btn-mb-clusters")
		if clusterChip then clusterChip:SetClass("active", mbState.clusterCounter and true or false) end
		local lassoChip = doc:GetElementById("btn-mb-lasso")
		if lassoChip then lassoChip:SetClass("active", mbState.lassoActive and true or false) end
		local axisChip = doc:GetElementById("btn-mb-balance-axis")
		if axisChip then axisChip:SetClass("active", mbState.balanceAxisActive and true or false) end
		local inspectorChip = doc:GetElementById("btn-mb-inspector")
		local inspectorOpen = widgetState.mbInspectorOpen
			or mbState.clusterCounter or mbState.lassoActive or mbState.lassoClosed or mbState.balanceAxisActive
		if inspectorChip then inspectorChip:SetClass("active", inspectorOpen and true or false) end
		widgetState.mbInspectorOpen = inspectorOpen and true or false
		-- Map analysis sub-row visibility driven by data-if
		if dm then
			dm.mbInspectorOpen = inspectorOpen and true or false
			dm.mbClusterOpen   = mbState.clusterCounter and true or false
			dm.mbLassoOpen     = (mbState.lassoActive or mbState.lassoClosed) and true or false
			dm.mbAxisOpen      = mbState.balanceAxisActive and true or false
		end
		local lbl = doc:GetElementById("mb-cluster-radius-label")
		if lbl then lbl.inner_rml = tostring(mbState.clusterRadius or 256) end
		local totalLbl = doc:GetElementById("mb-lasso-total-label")
		if totalLbl then totalLbl.inner_rml = string.format("%.2f", mbState.lassoTotal or 0) end
		local angleLbl = doc:GetElementById("mb-axis-angle-label")
		if angleLbl then angleLbl.inner_rml = tostring(math.floor((mbState.balanceAxisAngleDeg or 0) + 0.5)) end
		local aLbl = doc:GetElementById("mb-axis-a-label")
		if aLbl then aLbl.inner_rml = string.format("%.2f", mbState.balanceAxisSumA or 0) end
		local bLbl = doc:GetElementById("mb-axis-b-label")
		if bLbl then bLbl.inner_rml = string.format("%.2f", mbState.balanceAxisSumB or 0) end
		local balLbl = doc:GetElementById("mb-axis-balance-label")
		if balLbl then
			local a = mbState.balanceAxisSumA or 0
			local b = mbState.balanceAxisSumB or 0
			local diff = a - b
			local tot = a + b
			if tot > 0.001 then
				balLbl.inner_rml = string.format("%+.2f (%+.0f%%)", diff, diff / tot * 100)
			else
				balLbl.inner_rml = "--"
			end
		end
		uiState.updatingFromCode = true
		local clRadSlider = doc:GetElementById("mb-slider-cluster-radius")
		if clRadSlider then syncAndFlash(clRadSlider, "mb-cluster-radius", tostring(mbState.clusterRadius or 256)) end
		local axisSlider = doc:GetElementById("mb-slider-axis-angle")
		if axisSlider then syncAndFlash(axisSlider, "mb-axis-angle", tostring(math.floor((mbState.balanceAxisAngleDeg or 0) + 0.5))) end
		uiState.updatingFromCode = false
	end
end

return M
