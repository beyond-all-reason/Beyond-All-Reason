-- tf_metal.lua — Metal Brush attach + sync (extracted from gui_terraform_brush.lua)
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
	local LENGTH_SCALE_STEP = ctx.LENGTH_SCALE_STEP
	local CURVE_STEP = ctx.CURVE_STEP

	widgetState.mbSubmodesEl = doc:GetElementById("tf-metal-submodes")
	widgetState.mbControlsEl = doc:GetElementById("tf-metal-controls")

	widgetState.mbSubModeButtons = {}
	widgetState.mbSubModeButtons.paint = doc:GetElementById("btn-mb-paint")
	widgetState.mbSubModeButtons.stamp = doc:GetElementById("btn-mb-stamp")
	widgetState.mbSubModeButtons.remove = doc:GetElementById("btn-mb-remove")

	for mbMode, element in pairs(widgetState.mbSubModeButtons) do
		if element then
			element:AddEventListener("click", function(event)
				playSound("modeSwitch")
				if WG.MetalBrush then WG.MetalBrush.setSubMode(mbMode) end
				setActiveClass(widgetState.mbSubModeButtons, mbMode)
				event:StopPropagation()
			end, false)
		end
	end

	local mbSliderValue = doc:GetElementById("slider-metal-value")
	if mbSliderValue then
		trackSliderDrag(mbSliderValue, "mb-value")
		mbSliderValue:AddEventListener("change", function(event)
			if uiState.updatingFromCode then event:StopPropagation(); return end
			local v = tonumber(mbSliderValue:GetAttribute("value")) or 0
			-- Logarithmic mapping: 0.01 .. 50.0
			local mv = 0.01 * math.exp(v / 1000 * math.log(50.0 / 0.01))
			if WG.MetalBrush then WG.MetalBrush.setMetalValue(mv) end
			local mbLabel = doc:GetElementById("mb-value-label")
			if mbLabel then mbLabel.inner_rml = string.format("%.1f", mv) end
			event:StopPropagation()
		end, false)
	end

	do
		local valUp = doc:GetElementById("btn-metal-value-up")
		if valUp then
			valUp:AddEventListener("click", function(event)
				if WG.MetalBrush then
					local s = WG.MetalBrush.getState()
					local cur = s and s.metalValue or 2.0
					WG.MetalBrush.setMetalValue(cur * 1.1)
				end
				event:StopPropagation()
			end, false)
		end
		local valDn = doc:GetElementById("btn-metal-value-down")
		if valDn then
			valDn:AddEventListener("click", function(event)
				if WG.MetalBrush then
					local s = WG.MetalBrush.getState()
					local cur = s and s.metalValue or 2.0
					WG.MetalBrush.setMetalValue(cur / 1.1)
				end
				event:StopPropagation()
			end, false)
		end
	end

	local mbSaveBtn = doc:GetElementById("btn-metal-save")
	if mbSaveBtn then
		mbSaveBtn:AddEventListener("click", function(event)
			playSound("save")
			if WG.MetalBrush then WG.MetalBrush.saveMetalMap() end
			event:StopPropagation()
		end, false)
	end

	local mbLoadBtn = doc:GetElementById("btn-metal-load")
	if mbLoadBtn then
		mbLoadBtn:AddEventListener("click", function(event)
			playSound("apply")
			if WG.MetalBrush then WG.MetalBrush.loadMetalMap() end
			event:StopPropagation()
		end, false)
	end

	local mbCleanBtn = doc:GetElementById("btn-metal-clean")
	local mbCleanLabel = doc:GetElementById("metal-clean-label")
	if mbCleanBtn then
		mbCleanBtn:AddEventListener("click", function(event)
			if widgetState.metalCleanConfirmExpiry > 0 then
				-- Second click: confirmed
				widgetState.metalCleanConfirmExpiry = 0
				mbCleanBtn:SetClass("confirming", false)
				if mbCleanLabel then mbCleanLabel.inner_rml = "CLEAN" end
				playSound("reset")
				if WG.MetalBrush then WG.MetalBrush.clearMetalMap() end
			else
				-- First click: ask for confirmation
				widgetState.metalCleanConfirmExpiry = (Spring.GetGameSeconds() or 0) + 3
				mbCleanBtn:SetClass("confirming", true)
				if mbCleanLabel then mbCleanLabel.inner_rml = "ARE YOU SURE?" end
				playSound("toggleOn")
			end
			event:StopPropagation()
		end, false)
	end

	-- Metal shape buttons (removed; metal now uses the shared tf-shape-row)
	widgetState.mbShapeButtons = {}

	-- Metal size slider
	do
		local sl = doc:GetElementById("slider-mb-size")
		if sl then
			trackSliderDrag(sl, "mb-size")
			sl:AddEventListener("change", function(event)
				if not uiState.updatingFromCode and WG.TerraformBrush then
					local val = tonumber(sl:GetAttribute("value")) or 100
					WG.TerraformBrush.setRadius(val)
				end
				event:StopPropagation()
			end, false)
		end
		local up = doc:GetElementById("btn-mb-size-up")
		if up then
			up:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					WG.TerraformBrush.setRadius(state.radius + RADIUS_STEP)
				end
				event:StopPropagation()
			end, false)
		end
		local dn = doc:GetElementById("btn-mb-size-down")
		if dn then
			dn:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					WG.TerraformBrush.setRadius(state.radius - RADIUS_STEP)
				end
				event:StopPropagation()
			end, false)
		end
	end

	-- Metal rotation slider
	do
		local sl = doc:GetElementById("slider-mb-rotation")
		if sl then
			trackSliderDrag(sl, "mb-rotation")
			sl:AddEventListener("change", function(event)
				if not uiState.updatingFromCode and WG.TerraformBrush then
					local val = tonumber(sl:GetAttribute("value")) or 0
					WG.TerraformBrush.setRotation(val)
				end
				event:StopPropagation()
			end, false)
		end
		local cw = doc:GetElementById("btn-mb-rot-cw")
		if cw then
			cw:AddEventListener("click", function(event)
				if WG.TerraformBrush then WG.TerraformBrush.rotate(ROTATION_STEP) end
				event:StopPropagation()
			end, false)
		end
		local ccw = doc:GetElementById("btn-mb-rot-ccw")
		if ccw then
			ccw:AddEventListener("click", function(event)
				if WG.TerraformBrush then WG.TerraformBrush.rotate(-ROTATION_STEP) end
				event:StopPropagation()
			end, false)
		end
	end

	-- Metal length slider
	do
		local sl = doc:GetElementById("slider-mb-length")
		if sl then
			trackSliderDrag(sl, "mb-length")
			sl:AddEventListener("change", function(event)
				if not uiState.updatingFromCode and WG.TerraformBrush then
					local val = tonumber(sl:GetAttribute("value")) or 10
					WG.TerraformBrush.setLengthScale(val / 10)
				end
				event:StopPropagation()
			end, false)
		end
		local up = doc:GetElementById("btn-mb-length-up")
		if up then
			up:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					WG.TerraformBrush.setLengthScale(state.lengthScale + LENGTH_SCALE_STEP)
				end
				event:StopPropagation()
			end, false)
		end
		local dn = doc:GetElementById("btn-mb-length-down")
		if dn then
			dn:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					WG.TerraformBrush.setLengthScale(state.lengthScale - LENGTH_SCALE_STEP)
				end
				event:StopPropagation()
			end, false)
		end
	end

	-- Metal curve/falloff slider
	do
		local sl = doc:GetElementById("slider-mb-curve")
		if sl then
			trackSliderDrag(sl, "mb-curve")
			sl:AddEventListener("change", function(event)
				if not uiState.updatingFromCode and WG.TerraformBrush then
					local val = tonumber(sl:GetAttribute("value")) or 10
					WG.TerraformBrush.setCurve(val / 10)
				end
				event:StopPropagation()
			end, false)
		end
		local up = doc:GetElementById("btn-mb-curve-up")
		if up then
			up:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					WG.TerraformBrush.setCurve(state.curve + CURVE_STEP)
				end
				event:StopPropagation()
			end, false)
		end
		local dn = doc:GetElementById("btn-mb-curve-down")
		if dn then
			dn:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					local state = WG.TerraformBrush.getState()
					WG.TerraformBrush.setCurve(state.curve - CURVE_STEP)
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

		-- DISPLAY
		chipToggle("btn-mb-grid-overlay",
			function() return getTFState().gridOverlay end,
			function(v) WG.TerraformBrush.setGridOverlay(v) end)
		chipToggle("btn-mb-height-colormap",
			function() return getTFState().heightColormap end,
			function(v) WG.TerraformBrush.setHeightColormap(v) end)

		-- INSTRUMENTS: Grid Snap + Measure
		local mbSnapRow = doc:GetElementById("mb-grid-snap-size-row")
		local mbSnapBtn = doc:GetElementById("btn-mb-grid-snap")
		if mbSnapBtn then
			mbSnapBtn:AddEventListener("click", function(ev)
				if WG.TerraformBrush then
					local newVal = not getTFState().gridSnap
					playSound(newVal and "toggleOn" or "toggleOff")
					WG.TerraformBrush.setGridSnap(newVal)
					mbSnapBtn:SetClass("active", newVal)
					if mbSnapRow then mbSnapRow:SetClass("hidden", not newVal) end
					Spring.Echo("[MetalBrush UI] Grid Snap -> " .. tostring(newVal) .. " (state=" .. tostring(getTFState().gridSnap) .. ")")
				end
				ev:StopPropagation()
			end, false)
		end
		local mbMeasureRow = doc:GetElementById("mb-measure-toolbar-row")
		local mbMeasureBtn = doc:GetElementById("btn-mb-measure")
		if mbMeasureBtn then
			mbMeasureBtn:AddEventListener("click", function(ev)
				if WG.TerraformBrush then
					local newVal = not getTFState().measureActive
					playSound(newVal and "toggleOn" or "toggleOff")
					WG.TerraformBrush.setMeasureActive(newVal)
					mbMeasureBtn:SetClass("active", newVal)
					if mbMeasureRow then mbMeasureRow:SetClass("hidden", not newVal) end
					Spring.Echo("[MetalBrush UI] Measure -> " .. tostring(newVal) .. " (state=" .. tostring(getTFState().measureActive) .. ")")
				end
				ev:StopPropagation()
			end, false)
		end

		-- Grid snap size slider
		local mbSnapSlider = doc:GetElementById("mb-slider-grid-snap-size")
		if mbSnapSlider then
			mbSnapSlider:AddEventListener("change", function(ev)
				if uiState.updatingFromCode then ev:StopPropagation(); return end
				if WG.TerraformBrush then
					local v = tonumber(mbSnapSlider:GetAttribute("value")) or 48
					WG.TerraformBrush.setGridSnapSize(v)
				end
				ev:StopPropagation()
			end, false)
		end
		local function mbSnapStep(delta)
			if WG.TerraformBrush then
				local cur = tonumber(getTFState().gridSnapSize) or 48
				local v = math.max(16, math.min(128, cur + delta))
				WG.TerraformBrush.setGridSnapSize(v)
			end
		end
		local sd = doc:GetElementById("mb-btn-snap-size-down")
		if sd then sd:AddEventListener("click", function(ev) mbSnapStep(-16); ev:StopPropagation() end, false) end
		local su = doc:GetElementById("mb-btn-snap-size-up")
		if su then su:AddEventListener("click", function(ev) mbSnapStep(16); ev:StopPropagation() end, false) end

		-- INSTRUMENTS: Protractor (angle snap) — shared state via WG.TerraformBrush
		local mbAngleRow = doc:GetElementById("mb-angle-snap-step-row")
		local mbAngleBtn = doc:GetElementById("btn-mb-angle-snap")
		if mbAngleBtn then
			mbAngleBtn:AddEventListener("click", function(ev)
				if WG.TerraformBrush then
					local newVal = not getTFState().angleSnap
					playSound(newVal and "toggleOn" or "toggleOff")
					WG.TerraformBrush.setAngleSnap(newVal)
					mbAngleBtn:SetClass("active", newVal)
					if mbAngleRow then mbAngleRow:SetClass("hidden", not newVal) end
				end
				ev:StopPropagation()
			end, false)
		end
		local MB_ANGLE_PRESETS = {7.5, 15, 30, 45, 60, 90}
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
		local mbAngleSlider = doc:GetElementById("mb-slider-angle-snap-step")
		if mbAngleSlider then
			mbAngleSlider:AddEventListener("change", function(ev)
				if uiState.updatingFromCode then ev:StopPropagation(); return end
				local idx = (tonumber(mbAngleSlider:GetAttribute("value")) or 1) + 1
				mbApplyAnglePreset(idx)
				ev:StopPropagation()
			end, false)
		end
		local mbStepDn = doc:GetElementById("mb-btn-angle-step-down")
		if mbStepDn then mbStepDn:AddEventListener("click", function(ev)
			if WG.TerraformBrush then mbApplyAnglePreset(mbFindAnglePresetIdx(getTFState().angleSnapStep) - 1) end
			ev:StopPropagation()
		end, false) end
		local mbStepUp = doc:GetElementById("mb-btn-angle-step-up")
		if mbStepUp then mbStepUp:AddEventListener("click", function(ev)
			if WG.TerraformBrush then mbApplyAnglePreset(mbFindAnglePresetIdx(getTFState().angleSnapStep) + 1) end
			ev:StopPropagation()
		end, false) end
		-- Auto-snap toggle
		local mbAutoBtn = doc:GetElementById("mb-btn-angle-autosnap")
		if mbAutoBtn then
			mbAutoBtn:AddEventListener("click", function(ev)
				if WG.TerraformBrush then
					local newVal = not getTFState().angleSnapAuto
					playSound(newVal and "toggleOn" or "toggleOff")
					WG.TerraformBrush.setAngleSnapAuto(newVal)
					mbAutoBtn:SetClass("active", newVal)
					local manualRow = doc:GetElementById("mb-angle-manual-spoke-row")
					if manualRow then manualRow:SetClass("hidden", newVal) end
				end
				ev:StopPropagation()
			end, false)
		end
		-- Manual spoke slider + buttons
		local mbManualSlider = doc:GetElementById("mb-slider-manual-spoke")
		local function mbApplyManualSpoke(idx)
			if WG.TerraformBrush then
				WG.TerraformBrush.setAngleSnapManualSpoke(idx)
				local step = getTFState().angleSnapStep or 15
				local deg  = (idx * step) % 360
				local lbl  = doc:GetElementById("mb-angle-manual-spoke-label")
				if lbl then lbl.inner_rml = tostring(deg) end
				if mbManualSlider then mbManualSlider:SetAttribute("value", tostring(idx)) end
			end
		end
		if mbManualSlider then
			mbManualSlider:AddEventListener("change", function(ev)
				if uiState.updatingFromCode then ev:StopPropagation(); return end
				mbApplyManualSpoke(tonumber(mbManualSlider:GetAttribute("value")) or 0)
				ev:StopPropagation()
			end, false)
		end
		local mbMsDn = doc:GetElementById("mb-btn-manual-spoke-down")
		if mbMsDn then mbMsDn:AddEventListener("click", function(ev)
			if WG.TerraformBrush then
				local s = getTFState()
				local step = s.angleSnapStep or 15
				local num  = math.max(1, math.floor(360 / step))
				mbApplyManualSpoke(((s.angleSnapManualSpoke or 0) - 1 + num) % num)
			end
			ev:StopPropagation()
		end, false) end
		local mbMsUp = doc:GetElementById("mb-btn-manual-spoke-up")
		if mbMsUp then mbMsUp:AddEventListener("click", function(ev)
			if WG.TerraformBrush then
				local s = getTFState()
				local step = s.angleSnapStep or 15
				local num  = math.max(1, math.floor(360 / step))
				mbApplyManualSpoke(((s.angleSnapManualSpoke or 0) + 1) % num)
			end
			ev:StopPropagation()
		end, false) end

		-- Measure toolbar buttons
		local function mbMeasureBtnClick(id, fn)
			local el = doc:GetElementById(id)
			if el then el:AddEventListener("click", function(ev) fn(); ev:StopPropagation() end, false) end
		end
		mbMeasureBtnClick("mb-btn-measure-ruler",       function() if WG.TerraformBrush then WG.TerraformBrush.setMeasureRulerMode(not getTFState().measureRulerMode) end end)
		mbMeasureBtnClick("mb-btn-measure-sticky",      function() if WG.TerraformBrush then WG.TerraformBrush.setMeasureStickyMode(not getTFState().measureStickyMode) end end)
		mbMeasureBtnClick("mb-btn-measure-show-length", function() if WG.TerraformBrush then WG.TerraformBrush.setMeasureShowLength(not getTFState().measureShowLength) end end)
		mbMeasureBtnClick("mb-btn-measure-clear",       function() if WG.TerraformBrush then WG.TerraformBrush.clearMeasureLines() end end)

		-- INSTRUMENTS: Symmetry master + sub-toolbar
		local mbSymRow = doc:GetElementById("mb-symmetry-toolbar-row")
		local mbSymBtn = doc:GetElementById("btn-mb-symmetry")
		if mbSymBtn then
			mbSymBtn:AddEventListener("click", function(ev)
				if WG.TerraformBrush then
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
					mbSymBtn:SetClass("active", newVal)
					if mbSymRow then mbSymRow:SetClass("hidden", not newVal) end
					Spring.Echo("[MetalBrush UI] Symmetry -> " .. tostring(newVal))
				end
				ev:StopPropagation()
			end, false)
		end

		local function mbSymBtnClick(id, fn)
			local el = doc:GetElementById(id)
			if el then el:AddEventListener("click", function(ev) fn(); ev:StopPropagation() end, false) end
		end
		-- Helper: sync mutually-exclusive radial vs mirror-X/Y chip classes to current state
		local function syncSymChipClasses()
			local s = getTFState()
			local radialEl = doc:GetElementById("mb-btn-symmetry-radial")
			local mxEl     = doc:GetElementById("mb-btn-symmetry-mirror-x")
			local myEl     = doc:GetElementById("mb-btn-symmetry-mirror-y")
			if radialEl then radialEl:SetClass("active", s.symmetryRadial and true or false) end
			if mxEl     then mxEl:SetClass("active",     s.symmetryMirrorX and true or false) end
			if myEl     then myEl:SetClass("active",     s.symmetryMirrorY and true or false) end
			-- Toggle sub-rows: copies for radial, axis angle for mirror
			local countRow = doc:GetElementById("mb-symmetry-radial-count-row")
			if countRow then countRow:SetClass("hidden", not s.symmetryRadial) end
			local angleRow = doc:GetElementById("mb-symmetry-mirror-angle-row")
			if angleRow then angleRow:SetClass("hidden", not (s.symmetryMirrorX or s.symmetryMirrorY)) end
		end
		mbSymBtnClick("mb-btn-symmetry-radial",    function() if WG.TerraformBrush then WG.TerraformBrush.setSymmetryRadial(not getTFState().symmetryRadial); syncSymChipClasses() end end)
		mbSymBtnClick("mb-btn-symmetry-mirror-x",  function() if WG.TerraformBrush then WG.TerraformBrush.setSymmetryMirrorX(not getTFState().symmetryMirrorX); syncSymChipClasses() end end)
		mbSymBtnClick("mb-btn-symmetry-mirror-y",  function() if WG.TerraformBrush then WG.TerraformBrush.setSymmetryMirrorY(not getTFState().symmetryMirrorY); syncSymChipClasses() end end)
		mbSymBtnClick("mb-btn-symmetry-place-origin",  function() if WG.TerraformBrush then WG.TerraformBrush.setSymmetryPlacingOrigin(true); playSound("toggleOn") end end)
		mbSymBtnClick("mb-btn-symmetry-center-origin", function() if WG.TerraformBrush then WG.TerraformBrush.setSymmetryOrigin(nil, nil); playSound("toggleOff") end end)
		mbSymBtnClick("mb-btn-symmetry-count-down", function()
			if WG.TerraformBrush then
				local c = math.max(2, (getTFState().symmetryRadialCount or 2) - 1)
				WG.TerraformBrush.setSymmetryRadialCount(c)
			end
		end)
		mbSymBtnClick("mb-btn-symmetry-count-up", function()
			if WG.TerraformBrush then
				local c = math.min(16, (getTFState().symmetryRadialCount or 2) + 1)
				WG.TerraformBrush.setSymmetryRadialCount(c)
			end
		end)
		mbSymBtnClick("mb-btn-symmetry-angle-down", function()
			if WG.TerraformBrush then
				local a = ((getTFState().symmetryMirrorAngle or 0) - 5) % 360
				WG.TerraformBrush.setSymmetryMirrorAngle(a)
			end
		end)
		mbSymBtnClick("mb-btn-symmetry-angle-up", function()
			if WG.TerraformBrush then
				local a = ((getTFState().symmetryMirrorAngle or 0) + 5) % 360
				WG.TerraformBrush.setSymmetryMirrorAngle(a)
			end
		end)

		local mbCountSlider = doc:GetElementById("mb-slider-symmetry-radial-count")
		if mbCountSlider then
			trackSliderDrag(mbCountSlider, "mb-symmetry-radial-count")
			mbCountSlider:AddEventListener("change", function(ev)
				if uiState.updatingFromCode then ev:StopPropagation(); return end
				if WG.TerraformBrush then
					local v = tonumber(mbCountSlider:GetAttribute("value")) or 2
					WG.TerraformBrush.setSymmetryRadialCount(v)
				end
				ev:StopPropagation()
			end, false)
		end
		local mbAngleSlider = doc:GetElementById("mb-slider-symmetry-mirror-angle")
		if mbAngleSlider then
			trackSliderDrag(mbAngleSlider, "mb-symmetry-mirror-angle")
			mbAngleSlider:AddEventListener("change", function(ev)
				if uiState.updatingFromCode then ev:StopPropagation(); return end
				if WG.TerraformBrush then
					local v = tonumber(mbAngleSlider:GetAttribute("value")) or 0
					WG.TerraformBrush.setSymmetryMirrorAngle(v)
				end
				ev:StopPropagation()
			end, false)
		end
	end

	-- ── METAL MAP analysis: full-map overlay, clusters, lasso ──
	do
		local function mbGetMbState()
			return (WG.MetalBrush and WG.MetalBrush.getState and WG.MetalBrush.getState()) or {}
		end
		local clusterRow = doc:GetElementById("mb-cluster-radius-row")
		local inspectorRow = doc:GetElementById("mb-inspector-row")
		local lassoRow = doc:GetElementById("mb-lasso-row")
		local axisRow = doc:GetElementById("mb-balance-axis-row")

		local overlayChip = doc:GetElementById("btn-mb-mapoverlay")
		if overlayChip then
			overlayChip:AddEventListener("click", function(ev)
				if WG.MetalBrush then
					local newVal = not mbGetMbState().mapOverlay
					playSound(newVal and "toggleOn" or "toggleOff")
					WG.MetalBrush.setMapOverlay(newVal)
					overlayChip:SetClass("active", newVal)
				end
				ev:StopPropagation()
			end, false)
		end

		local clusterChip = doc:GetElementById("btn-mb-clusters")
		if clusterChip then
			clusterChip:AddEventListener("click", function(ev)
				if WG.MetalBrush then
					local newVal = not mbGetMbState().clusterCounter
					playSound(newVal and "toggleOn" or "toggleOff")
					WG.MetalBrush.setClusterCounter(newVal)
					clusterChip:SetClass("active", newVal)
					if clusterRow then clusterRow:SetClass("hidden", not newVal) end
				end
				ev:StopPropagation()
			end, false)
		end

		-- Inspector parent chip: opens a sub-toolbar with Lasso + Balance Axis
		local inspectorChip = doc:GetElementById("btn-mb-inspector")
		if inspectorChip then
			inspectorChip:AddEventListener("click", function(ev)
				local st = mbGetMbState()
				local open = not (widgetState.mbInspectorOpen or false)
				widgetState.mbInspectorOpen = open
				playSound(open and "toggleOn" or "toggleOff")
				inspectorChip:SetClass("active", open)
				if inspectorRow then inspectorRow:SetClass("hidden", not open) end
				if not open and WG.MetalBrush then
					-- Closing inspector also disables its sub-tools
					if st.clusterCounter then WG.MetalBrush.setClusterCounter(false) end
					if st.lassoActive or st.lassoClosed then WG.MetalBrush.clearLasso() end
					if st.balanceAxisActive then WG.MetalBrush.setBalanceAxisActive(false) end
				end
				ev:StopPropagation()
			end, false)
		end

		local lassoChip = doc:GetElementById("btn-mb-lasso")
		if lassoChip then
			lassoChip:AddEventListener("click", function(ev)
				if WG.MetalBrush then
					local newVal = not mbGetMbState().lassoActive
					playSound(newVal and "toggleOn" or "toggleOff")
					if newVal then
						WG.MetalBrush.startLasso()
					else
						WG.MetalBrush.clearLasso()
					end
					lassoChip:SetClass("active", newVal)
					if lassoRow then lassoRow:SetClass("hidden", not newVal) end
				end
				ev:StopPropagation()
			end, false)
		end

		local lassoCloseBtn = doc:GetElementById("mb-btn-lasso-close")
		if lassoCloseBtn then
			lassoCloseBtn:AddEventListener("click", function(ev)
				if WG.MetalBrush then
					playSound("apply")
					WG.MetalBrush.finishLasso()
				end
				ev:StopPropagation()
			end, false)
		end

		local lassoClearBtn = doc:GetElementById("mb-btn-lasso-clear")
		if lassoClearBtn then
			lassoClearBtn:AddEventListener("click", function(ev)
				if WG.MetalBrush then
					playSound("reset")
					WG.MetalBrush.clearLasso()
					if lassoChip then lassoChip:SetClass("active", false) end
					if lassoRow then lassoRow:SetClass("hidden", true) end
				end
				ev:StopPropagation()
			end, false)
		end

		-- Balance Axis chip + controls
		local axisChip = doc:GetElementById("btn-mb-balance-axis")
		if axisChip then
			axisChip:AddEventListener("click", function(ev)
				if WG.MetalBrush then
					local newVal = not mbGetMbState().balanceAxisActive
					playSound(newVal and "toggleOn" or "toggleOff")
					WG.MetalBrush.setBalanceAxisActive(newVal)
					axisChip:SetClass("active", newVal)
					if axisRow then axisRow:SetClass("hidden", not newVal) end
				end
				ev:StopPropagation()
			end, false)
		end

		local axisX = doc:GetElementById("mb-btn-axis-x")
		if axisX then
			axisX:AddEventListener("click", function(ev)
				if WG.MetalBrush then
					playSound("modeSwitch")
					WG.MetalBrush.setBalanceAxisAngle(0)
				end
				ev:StopPropagation()
			end, false)
		end
		local axisZ = doc:GetElementById("mb-btn-axis-z")
		if axisZ then
			axisZ:AddEventListener("click", function(ev)
				if WG.MetalBrush then
					playSound("modeSwitch")
					WG.MetalBrush.setBalanceAxisAngle(90)
				end
				ev:StopPropagation()
			end, false)
		end
		local axisPlace = doc:GetElementById("mb-btn-axis-place")
		if axisPlace then
			axisPlace:AddEventListener("click", function(ev)
				if WG.MetalBrush then
					playSound("modeSwitch")
					WG.MetalBrush.setBalanceAxisPlacingOrigin(true)
				end
				ev:StopPropagation()
			end, false)
		end
		local axisCenter = doc:GetElementById("mb-btn-axis-center")
		if axisCenter then
			axisCenter:AddEventListener("click", function(ev)
				if WG.MetalBrush then
					playSound("reset")
					WG.MetalBrush.setBalanceAxisOrigin(nil, nil)
				end
				ev:StopPropagation()
			end, false)
		end
		local axisSlider = doc:GetElementById("mb-slider-axis-angle")
		if axisSlider then
			trackSliderDrag(axisSlider, "mb-axis-angle")
			axisSlider:AddEventListener("change", function(ev)
				if uiState.updatingFromCode then ev:StopPropagation(); return end
				if WG.MetalBrush then
					local v = tonumber(axisSlider:GetAttribute("value")) or 0
					WG.MetalBrush.setBalanceAxisAngle(v)
				end
				ev:StopPropagation()
			end, false)
		end
		local axisDn = doc:GetElementById("mb-btn-axis-angle-down")
		if axisDn then
			axisDn:AddEventListener("click", function(ev)
				if WG.MetalBrush then
					local cur = tonumber(mbGetMbState().balanceAxisAngleDeg) or 0
					WG.MetalBrush.setBalanceAxisAngle(cur - 5)
				end
				ev:StopPropagation()
			end, false)
		end
		local axisUp = doc:GetElementById("mb-btn-axis-angle-up")
		if axisUp then
			axisUp:AddEventListener("click", function(ev)
				if WG.MetalBrush then
					local cur = tonumber(mbGetMbState().balanceAxisAngleDeg) or 0
					WG.MetalBrush.setBalanceAxisAngle(cur + 5)
				end
				ev:StopPropagation()
			end, false)
		end

		local clRadSlider = doc:GetElementById("mb-slider-cluster-radius")
		if clRadSlider then
			trackSliderDrag(clRadSlider, "mb-cluster-radius")
			clRadSlider:AddEventListener("change", function(ev)
				if uiState.updatingFromCode then ev:StopPropagation(); return end
				if WG.MetalBrush then
					local v = tonumber(clRadSlider:GetAttribute("value")) or 256
					WG.MetalBrush.setClusterRadius(v)
					local lbl = doc:GetElementById("mb-cluster-radius-label")
					if lbl then lbl.inner_rml = tostring(v) end
				end
				ev:StopPropagation()
			end, false)
		end
		local clRadDn = doc:GetElementById("mb-btn-cluster-radius-down")
		if clRadDn then
			clRadDn:AddEventListener("click", function(ev)
				if WG.MetalBrush then
					local cur = tonumber(mbGetMbState().clusterRadius) or 256
					WG.MetalBrush.setClusterRadius(math.max(64, cur - 32))
				end
				ev:StopPropagation()
			end, false)
		end
		local clRadUp = doc:GetElementById("mb-btn-cluster-radius-up")
		if clRadUp then
			clRadUp:AddEventListener("click", function(ev)
				if WG.MetalBrush then
					local cur = tonumber(mbGetMbState().clusterRadius) or 256
					WG.MetalBrush.setClusterRadius(math.min(1024, cur + 32))
				end
				ev:StopPropagation()
			end, false)
		end
	end
end

function M.sync(doc, ctx, mbState, setSummary)
	local widgetState = ctx.widgetState
	local uiState = ctx.uiState
	local setActiveClass = ctx.setActiveClass
	local syncAndFlash = ctx.syncAndFlash
	local WG = ctx.WG

	local metalBtn = doc and doc:GetElementById("btn-metal")
	if metalBtn then metalBtn:SetClass("active", true) end
	setActiveClass(widgetState.modeButtons, nil)

	-- Metal sub-mode buttons
	setActiveClass(widgetState.mbSubModeButtons, mbState.subMode)

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
		setActiveClass(widgetState.shapeButtons, tfSt.shape)
	end

	-- P3.2 Metal grayouts (per Phase 3 relevance matrix)
	if doc and tfSt then
		local sm = mbState.subMode or "paint"
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
		local clusterRow = doc:GetElementById("mb-cluster-radius-row")
		if clusterRow then clusterRow:SetClass("hidden", not mbState.clusterCounter) end
		local inspectorRow = doc:GetElementById("mb-inspector-row")
		if inspectorRow then inspectorRow:SetClass("hidden", not inspectorOpen) end
		local lassoRow = doc:GetElementById("mb-lasso-row")
		if lassoRow then lassoRow:SetClass("hidden", not (mbState.lassoActive or mbState.lassoClosed)) end
		local axisRow = doc:GetElementById("mb-balance-axis-row")
		if axisRow then axisRow:SetClass("hidden", not mbState.balanceAxisActive) end
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
