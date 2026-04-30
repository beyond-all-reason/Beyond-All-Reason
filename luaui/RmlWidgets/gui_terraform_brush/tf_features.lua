-- tf_features.lua: extracted tool module for gui_terraform_brush
local M = {}

function M.attach(doc, ctx)
	local widgetState = ctx.widgetState
	local uiState = ctx.uiState
	local WG = ctx.WG
	local playSound = ctx.playSound
	local trackSliderDrag = ctx.trackSliderDrag
	local ROTATION_STEP = ctx.ROTATION_STEP
	local RADIUS_STEP = ctx.RADIUS_STEP
	local sliderToCadence = ctx.sliderToCadence

	-- Cache section elements (used by M.sync)
	widgetState.tfControlsEl = doc:GetElementById("tf-terraform-controls")
	widgetState.fpControlsEl = doc:GetElementById("tf-feature-controls")
	widgetState.fpSubmodesEl = doc:GetElementById("tf-feature-submodes")
	widgetState.shapeRowEl = doc:GetElementById("tf-shape-row")

	-- Slider drag tracking (legitimate imperative state).
	-- Slider change events wired declaratively via onchange= in RML.
	for _, sid in ipairs({
		"size", "rotation", "rot-random", "count", "cadence",
		"slope-max", "slope-min", "alt-min", "alt-max",
		"symmetry-radial-count", "symmetry-mirror-angle",
	}) do
		local sl = doc:GetElementById("fp-slider-" .. sid)
		if sl then trackSliderDrag(sl, "fp-" .. sid) end
	end
	local sliderFpHistory = doc:GetElementById("slider-fp-history")
	if sliderFpHistory then trackSliderDrag(sliderFpHistory, "fp-history") end

	-- Register widget methods for inline onclick/onchange handlers in RML.
	local w = ctx.widget
	if not w then return end

	-- Sub-mode
	w.fpSetMode = function(self, fmode)
		playSound("modeSwitch")
		if WG.FeaturePlacer then WG.FeaturePlacer.setMode(fmode) end
		if widgetState.dmHandle then widgetState.dmHandle.fpSubMode = fmode end
	end

	-- Distribution
	w.fpSetDist = function(self, dist)
		playSound("shapeSwitch")
		if WG.FeaturePlacer then WG.FeaturePlacer.setDistribution(dist) end
		if widgetState.dmHandle then widgetState.dmHandle.fpDistMode = dist end
	end

	-- Size
	w.fpOnSizeChange = function(self, element)
		if uiState.updatingFromCode or not WG.FeaturePlacer then return end
		local val = element and tonumber(element:GetAttribute("value")) or 200
		WG.FeaturePlacer.setRadius(val)
	end
	w.fpSizeUp = function(self)
		if WG.FeaturePlacer then
			local st = WG.FeaturePlacer.getState()
			WG.FeaturePlacer.setRadius(st.radius + RADIUS_STEP * 4)
		end
	end
	w.fpSizeDown = function(self)
		if WG.FeaturePlacer then
			local st = WG.FeaturePlacer.getState()
			WG.FeaturePlacer.setRadius(st.radius - RADIUS_STEP * 4)
		end
	end

	-- Rotation
	w.fpOnRotChange = function(self, element)
		if uiState.updatingFromCode or not WG.FeaturePlacer then return end
		local val = element and tonumber(element:GetAttribute("value")) or 0
		WG.FeaturePlacer.setRotation(val)
	end
	w.fpRotCW = function(self)
		if WG.FeaturePlacer then WG.FeaturePlacer.rotate(ROTATION_STEP) end
	end
	w.fpRotCCW = function(self)
		if WG.FeaturePlacer then WG.FeaturePlacer.rotate(-ROTATION_STEP) end
	end

	-- Rotation randomness
	w.fpOnRotRandomChange = function(self, element)
		if uiState.updatingFromCode or not WG.FeaturePlacer then return end
		local val = element and tonumber(element:GetAttribute("value")) or 100
		WG.FeaturePlacer.setRotRandom(val)
	end
	w.fpRotRandomUp = function(self)
		if WG.FeaturePlacer then
			local st = WG.FeaturePlacer.getState()
			WG.FeaturePlacer.setRotRandom(math.min(100, (st.rotRandom or 0) + 5))
		end
	end
	w.fpRotRandomDown = function(self)
		if WG.FeaturePlacer then
			local st = WG.FeaturePlacer.getState()
			WG.FeaturePlacer.setRotRandom(math.max(0, (st.rotRandom or 100) - 5))
		end
	end

	-- Count
	w.fpOnCountChange = function(self, element)
		if uiState.updatingFromCode or not WG.FeaturePlacer then return end
		local val = element and tonumber(element:GetAttribute("value")) or 10
		WG.FeaturePlacer.setFeatureCount(val)
	end
	w.fpCountUp = function(self)
		if WG.FeaturePlacer then
			local st = WG.FeaturePlacer.getState()
			WG.FeaturePlacer.setFeatureCount(st.featureCount + 1)
		end
	end
	w.fpCountDown = function(self)
		if WG.FeaturePlacer then
			local st = WG.FeaturePlacer.getState()
			WG.FeaturePlacer.setFeatureCount(st.featureCount - 1)
		end
	end

	-- Cadence
	w.fpOnCadenceChange = function(self, element)
		if uiState.updatingFromCode or not WG.FeaturePlacer then return end
		local sliderVal = element and tonumber(element:GetAttribute("value")) or 0
		WG.FeaturePlacer.setCadence(sliderToCadence(sliderVal))
	end
	w.fpCadenceUp = function(self)
		if WG.FeaturePlacer then
			local st = WG.FeaturePlacer.getState()
			local step = math.max(1, math.floor(st.cadence * 0.2))
			WG.FeaturePlacer.setCadence(st.cadence + step)
		end
	end
	w.fpCadenceDown = function(self)
		if WG.FeaturePlacer then
			local st = WG.FeaturePlacer.getState()
			local step = math.max(1, math.floor(st.cadence * 0.2))
			WG.FeaturePlacer.setCadence(st.cadence - step)
		end
	end

	-- Undo / redo
	w.fpUndo = function(self)
		playSound("undo")
		if WG.FeaturePlacer then WG.FeaturePlacer.undo() end
	end
	w.fpRedo = function(self)
		playSound("undo")
		if WG.FeaturePlacer then WG.FeaturePlacer.redo() end
	end

	-- History slider scrubbing
	w.fpOnHistoryChange = function(self, element)
		if uiState.updatingFromCode or not WG.FeaturePlacer then return end
		local val = element and tonumber(element:GetAttribute("value")) or 0
		local fpSt = WG.FeaturePlacer.getState()
		if not fpSt then return end
		local currentUndoCount = fpSt.undoCount or 0
		local diff = val - currentUndoCount
		if diff > 0 then
			for i = 1, diff do WG.FeaturePlacer.redo() end
		elseif diff < 0 then
			for i = 1, -diff do WG.FeaturePlacer.undo() end
		end
	end

	-- Save / Clear
	w.fpSave = function(self)
		playSound("save")
		if WG.FeaturePlacer then WG.FeaturePlacer.save() end
	end
	w.fpClearAll = function(self)
		playSound("reset")
		if WG.FeaturePlacer then WG.FeaturePlacer.clearAll() end
	end

	-- Load: toggle + dynamically populate save list (dynamic DOM = legitimate imperative)
	w.fpLoad = function(self)
		playSound("dropdown")
		local listEl = doc:GetElementById("fp-save-load-list")
		if not listEl then return end
		local dm = widgetState.dmHandle
		local willOpen = not (dm and dm.fpSaveLoadOpen)
		if dm then dm.fpSaveLoadOpen = willOpen end
		if willOpen and WG.FeaturePlacer then
			listEl.inner_rml = ""
			local files = WG.FeaturePlacer.listSaves()
			if #files == 0 then
				listEl.inner_rml = '<div style="padding: 4dp 6dp; font-size: 0.9rem; color: #6b7280;">No saved feature maps</div>'
			else
				for _, filepath in ipairs(files) do
					local fname = filepath:match("[^/\\]+$") or filepath
					local item = doc:CreateElement("div")
					item:SetAttribute("style", "padding: 3dp 6dp; font-size: 0.9rem; color: #9ca3af; cursor: pointer; border-radius: 3dp;")
					item.inner_rml = fname
					item:AddEventListener("click", function(ev)
						if WG.FeaturePlacer then
							WG.FeaturePlacer.load(filepath)
						end
						if widgetState.dmHandle then widgetState.dmHandle.fpSaveLoadOpen = false end
						ev:StopPropagation()
					end, false)
					item:AddEventListener("mouseover", function()
						item:SetAttribute("style", "padding: 3dp 6dp; font-size: 0.9rem; color: #d1d5db; cursor: pointer; border-radius: 3dp; background-color: #2a2a3a;")
					end, false)
					item:AddEventListener("mouseout", function()
						item:SetAttribute("style", "padding: 3dp 6dp; font-size: 0.9rem; color: #9ca3af; cursor: pointer; border-radius: 3dp;")
					end, false)
					listEl:AppendChild(item)
				end
			end
		end
	end

	-- Altitude enable toggle (generic; filterKey passed from RML)
	w.fpToggleAltEnable = function(self, filterKey)
		if not WG.FeaturePlacer then return end
		local sf = WG.FeaturePlacer.getState().smartFilters
		playSound(sf[filterKey] and "toggleOff" or "toggleOn")
		WG.FeaturePlacer.setSmartFilter(filterKey, not sf[filterKey])
		local sf2 = WG.FeaturePlacer.getState().smartFilters
		local anyOn = sf2.avoidWater or sf2.avoidCliffs or sf2.preferSlopes
			or sf2.altMinEnable or sf2.altMaxEnable
		WG.FeaturePlacer.setSmartEnabled(anyOn and true or false)
	end

	-- Altitude SAMPLE toggles: pick height from map for fp filter endpoints
	w.fpAltSample = function(self, target)
		if WG.TerraformBrush then
			local cur = (WG.TerraformBrush.getState() or {}).heightSamplingMode
			WG.TerraformBrush.setHeightSamplingMode(cur == target and nil or target)
		end
	end

	-- FP-panel Grid overlay (WG.FeaturePlacer)
	w.fpToggleGridOverlay = function(self)
		if not WG.FeaturePlacer then return end
		local st = WG.FeaturePlacer.getState()
		local newVal = not (st and st.gridOverlay)
		WG.FeaturePlacer.setGridOverlay(newVal)
		local btn = doc:GetElementById("btn-fp-grid-overlay")
		if btn then btn:SetClass("active", newVal) end
	end

	-- FP-panel Grid snap (WG.FeaturePlacer)
	w.fpToggleGridSnap = function(self)
		if not WG.FeaturePlacer then return end
		local st = WG.FeaturePlacer.getState()
		local newVal = not (st and st.gridSnap)
		WG.FeaturePlacer.setGridSnap(newVal)
		local btn = doc:GetElementById("btn-fp-grid-snap")
		if btn then btn:SetClass("active", newVal) end
	end

	-- Display overlay: Height Map (shared WG.TerraformBrush)
	w.fpToggleHeightMap = function(self)
		if not WG.TerraformBrush then return end
		local state = WG.TerraformBrush.getState()
		local newVal = not (state and state.heightColormap)
		playSound(newVal and "toggleOn" or "toggleOff")
		WG.TerraformBrush.setHeightColormap(newVal)
		local btn = doc:GetElementById("btn-fp-height-colormap")
		if btn then btn:SetClass("active", newVal) end
	end

	-- Instruments: Measure (shared WG.TerraformBrush)
	w.fpToggleMeasure = function(self)
		if not WG.TerraformBrush then return end
		local state = WG.TerraformBrush.getState()
		local newVal = not (state and state.measureActive)
		playSound(newVal and "toggleOn" or "toggleOff")
		WG.TerraformBrush.setMeasureActive(newVal)
		local btn = doc:GetElementById("btn-fp-measure")
		if btn then btn:SetClass("active", newVal) end
	end

	-- Instruments: Symmetry (shared WG.TerraformBrush)
	w.fpToggleSymmetry = function(self)
		if not WG.TerraformBrush then return end
		local state = WG.TerraformBrush.getState()
		local newVal = not (state and state.symmetryActive)
		playSound(newVal and "toggleOn" or "toggleOff")
		WG.TerraformBrush.setSymmetryActive(newVal)
		local btn = doc:GetElementById("btn-fp-symmetry")
		if btn then btn:SetClass("active", newVal) end
		-- fp-symmetry-toolbar-row visibility driven by data-if="fpSymmetryActive" (mirrored in M.sync)
	end

	-- Symmetry sub-toolbar
	w.fpSymRadial = function(self)
		if WG.TerraformBrush then
			local s = WG.TerraformBrush.getState()
			WG.TerraformBrush.setSymmetryRadial(not (s and s.symmetryRadial))
		end
	end
	w.fpSymMirrorX = function(self)
		if WG.TerraformBrush then
			local s = WG.TerraformBrush.getState()
			WG.TerraformBrush.setSymmetryMirrorX(not (s and s.symmetryMirrorX))
		end
	end
	w.fpSymMirrorY = function(self)
		if WG.TerraformBrush then
			local s = WG.TerraformBrush.getState()
			WG.TerraformBrush.setSymmetryMirrorY(not (s and s.symmetryMirrorY))
		end
	end
	w.fpSymPlaceOrigin = function(self)
		if WG.TerraformBrush then WG.TerraformBrush.setSymmetryPlacingOrigin(true) end
	end
	w.fpSymCenterOrigin = function(self)
		if WG.TerraformBrush then
			WG.TerraformBrush.setSymmetryOrigin(nil, nil)
			playSound("toggleOff")
		end
	end
	w.fpSymCountDown = function(self)
		if WG.TerraformBrush then
			local s = WG.TerraformBrush.getState()
			local c = math.max(2, (s and s.symmetryRadialCount or 2) - 1)
			WG.TerraformBrush.setSymmetryRadialCount(c)
		end
	end
	w.fpSymCountUp = function(self)
		if WG.TerraformBrush then
			local s = WG.TerraformBrush.getState()
			local c = math.min(16, (s and s.symmetryRadialCount or 2) + 1)
			WG.TerraformBrush.setSymmetryRadialCount(c)
		end
	end
	w.fpSymAngleDown = function(self)
		if WG.TerraformBrush then
			local s = WG.TerraformBrush.getState()
			local a = ((s and s.symmetryMirrorAngle or 0) - 5) % 360
			WG.TerraformBrush.setSymmetryMirrorAngle(a)
		end
	end
	w.fpSymAngleUp = function(self)
		if WG.TerraformBrush then
			local s = WG.TerraformBrush.getState()
			local a = ((s and s.symmetryMirrorAngle or 0) + 5) % 360
			WG.TerraformBrush.setSymmetryMirrorAngle(a)
		end
	end
	w.fpOnSymCountChange = function(self, element)
		if uiState.updatingFromCode or not WG.TerraformBrush then return end
		local v = element and tonumber(element:GetAttribute("value")) or 2
		WG.TerraformBrush.setSymmetryRadialCount(v)
	end
	w.fpOnSymAngleChange = function(self, element)
		if uiState.updatingFromCode or not WG.TerraformBrush then return end
		local v = element and tonumber(element:GetAttribute("value")) or 0
		WG.TerraformBrush.setSymmetryMirrorAngle(v)
	end

	-- Smart slope/altitude sliders (coupled clamp for alt min/max)
	w.fpOnSlopeMaxChange = function(self, element)
		if uiState.updatingFromCode or not WG.FeaturePlacer then return end
		local val = element and tonumber(element:GetAttribute("value")) or 45
		WG.FeaturePlacer.setSmartFilter("slopeMax", val)
	end
	w.fpOnSlopeMinChange = function(self, element)
		if uiState.updatingFromCode or not WG.FeaturePlacer then return end
		local val = element and tonumber(element:GetAttribute("value")) or 10
		WG.FeaturePlacer.setSmartFilter("slopeMin", val)
	end
	w.fpOnAltMinChange = function(self, element)
		if uiState.updatingFromCode or not WG.FeaturePlacer then return end
		local val = element and tonumber(element:GetAttribute("value")) or 0
		local sf = WG.FeaturePlacer.getState().smartFilters
		if sf.altMaxEnable and val > sf.altMax then
			WG.FeaturePlacer.setSmartFilter("altMax", val)
		end
		WG.FeaturePlacer.setSmartFilter("altMin", val)
	end
	w.fpOnAltMaxChange = function(self, element)
		if uiState.updatingFromCode or not WG.FeaturePlacer then return end
		local val = element and tonumber(element:GetAttribute("value")) or 200
		local sf = WG.FeaturePlacer.getState().smartFilters
		if sf.altMinEnable and val < sf.altMin then
			WG.FeaturePlacer.setSmartFilter("altMin", val)
		end
		WG.FeaturePlacer.setSmartFilter("altMax", val)
	end

	-- Smart filter +/- stepper (generic; filterKey + step passed from RML)
	w.fpSmartStep = function(self, filterKey, step)
		if not WG.FeaturePlacer then return end
		local sf = WG.FeaturePlacer.getState().smartFilters
		WG.FeaturePlacer.setSmartFilter(filterKey, (sf[filterKey] or 0) + step)
	end

end

function M.sync(doc, ctx, fpState, setSummary)
	local widgetState = ctx.widgetState
	local uiState = ctx.uiState
	local WG = ctx.WG
	local syncAndFlash = ctx.syncAndFlash
	local cadenceToSlider = ctx.cadenceToSlider
	local shapeNames = ctx.shapeNames
		-- ===== Feature Placer mode: update feature controls =====
		local featuresBtn = doc and doc:GetElementById("btn-features")
		if featuresBtn then
			featuresBtn:SetClass("active", true)
		end
		-- Clear terraform mode highlights


		-- DISPLAY/INSTRUMENTS warn chips (shared TB state mirror)
		if doc and ctx.syncWarnChip then
			local tbs = (WG.TerraformBrush and WG.TerraformBrush.getState()) or {}
			local dispActive = tbs.gridOverlay or tbs.heightColormap
			local instActive = tbs.gridSnap or tbs.angleSnap or tbs.measureActive or tbs.symmetryActive
			ctx.syncWarnChip(doc, "warn-chip-fp-overlays",    "section-fp-overlays",    dispActive)
			ctx.syncWarnChip(doc, "warn-chip-fp-instruments", "section-fp-instruments", instActive)
		end

		-- Feature sub-mode and distribution (driven by dm fields via data-class-active)
		if widgetState.dmHandle then
			widgetState.dmHandle.fpSubMode = fpState.mode or "scatter"
			widgetState.dmHandle.fpDistMode = fpState.distribution or "random"
		end

		-- Feature shape buttons
		if widgetState.dmHandle then widgetState.dmHandle.activeShape = fpState.shape or "circle" end

		if doc then
			uiState.updatingFromCode = true
			local ds = uiState.draggingSlider

			-- Feature labels
			local fpRadiusLabel = doc:GetElementById("fp-radius-label")
			if fpRadiusLabel then fpRadiusLabel.inner_rml = tostring(fpState.radius) end

			local fpRotationLabel = doc:GetElementById("fp-rotation-label")
			if fpRotationLabel then fpRotationLabel.inner_rml = tostring(fpState.rotation) end

			local fpRotRandomLabel = doc:GetElementById("fp-rot-random-label")
			if fpRotRandomLabel then fpRotRandomLabel.inner_rml = tostring(fpState.rotRandom) end

			local fpCountLabel = doc:GetElementById("fp-count-label")
			if fpCountLabel then fpCountLabel.inner_rml = tostring(fpState.featureCount) end

			local fpCadenceLabel = doc:GetElementById("fp-cadence-label")
			if fpCadenceLabel then fpCadenceLabel.inner_rml = tostring(fpState.cadence) end

			-- Feature sliders
			syncAndFlash(doc:GetElementById("fp-slider-size"), "fp-size", tostring(fpState.radius))
			syncAndFlash(doc:GetElementById("fp-slider-rotation"), "fp-rotation", tostring(fpState.rotation))
			syncAndFlash(doc:GetElementById("fp-slider-rot-random"), "fp-rot-random", tostring(fpState.rotRandom))
			syncAndFlash(doc:GetElementById("fp-slider-count"), "fp-count", tostring(fpState.featureCount))
			syncAndFlash(doc:GetElementById("fp-slider-cadence"), "fp-cadence", tostring(cadenceToSlider(fpState.cadence)))

			-- Smart filter UI sync
			local fpSmartToggle = doc:GetElementById("btn-fp-smart-toggle")
			if fpSmartToggle then
				fpSmartToggle:SetAttribute("src", fpState.smartEnabled
					and "/luaui/images/terraform_brush/check_on.png"
					or "/luaui/images/terraform_brush/check_off.png")
			end
			do
				local sf = fpState.smartFilters or {}
				local anyFilterOn = fpState.smartEnabled == true and (
					sf.avoidWater or sf.avoidCliffs or sf.preferSlopes or
					sf.altMinEnable or sf.altMaxEnable
				) and true or false
				ctx.syncWarnChip(doc, "warn-chip-fp-smart", "section-fp-smart", anyFilterOn)
			end
			if fpState.smartFilters then
				local sf = fpState.smartFilters

				-- Mirror smart-filter flags into data-model for data-if visibility.
				if widgetState.dmHandle then
					widgetState.dmHandle.fpAvoidCliffs = sf.avoidCliffs == true
					widgetState.dmHandle.fpPreferSlopes = sf.preferSlopes == true
					widgetState.dmHandle.fpAltMinEnable = sf.altMinEnable == true
					widgetState.dmHandle.fpAltMaxEnable = sf.altMaxEnable == true
				end

				-- Filter chips: Avoid Water mirrors filter state; slope sub-chips mirror avoidCliffs / preferSlopes
				local avoidWaterChip = doc:GetElementById("fp-filter-chip-avoid-water")
				if avoidWaterChip then avoidWaterChip:SetClass("active", sf.avoidWater == true) end
				local slopeAvoidChip = doc:GetElementById("fp-slope-mode-avoid")
				if slopeAvoidChip then slopeAvoidChip:SetClass("active", sf.avoidCliffs == true) end
				local slopePreferChip = doc:GetElementById("fp-slope-mode-prefer")
				if slopePreferChip then slopePreferChip:SetClass("active", sf.preferSlopes == true) end

				-- Slope-max rows visibility driven by data-if="fpAvoidCliffs"
				local slopeMaxLabel = doc:GetElementById("fp-smart-slope-max-label")
				if slopeMaxLabel then slopeMaxLabel.inner_rml = tostring(sf.slopeMax) end
				local fpSSlopeMax = doc:GetElementById("fp-slider-slope-max")
				if fpSSlopeMax and ds ~= "fp-slope-max" then
					fpSSlopeMax:SetAttribute("value", tostring(sf.slopeMax))
				end

				-- Slope-min rows visibility driven by data-if="fpPreferSlopes"
				local slopeMinLabel = doc:GetElementById("fp-smart-slope-min-label")
				if slopeMinLabel then slopeMinLabel.inner_rml = tostring(sf.slopeMin) end
				local fpSSlopeMin = doc:GetElementById("fp-slider-slope-min")
				if fpSSlopeMin and ds ~= "fp-slope-min" then
					fpSSlopeMin:SetAttribute("value", tostring(sf.slopeMin))
				end

				local altMinEnableBtn = doc:GetElementById("btn-fp-alt-min-enable")
				if altMinEnableBtn then
					altMinEnableBtn:SetAttribute("src", sf.altMinEnable
						and "/luaui/images/terraform_brush/check_on.png"
						or "/luaui/images/terraform_brush/check_off.png")
				end
				-- Alt-min slider-row visibility driven by data-if="fpAltMinEnable"
				local altMinLabel = doc:GetElementById("fp-smart-alt-min-label")
				if altMinLabel then altMinLabel.inner_rml = tostring(sf.altMin) end
				local fpSAltMin = doc:GetElementById("fp-slider-alt-min")
				if fpSAltMin and ds ~= "fp-alt-min" then
					fpSAltMin:SetAttribute("value", tostring(sf.altMin))
				end

				local altMaxEnableBtn = doc:GetElementById("btn-fp-alt-max-enable")
				if altMaxEnableBtn then
					altMaxEnableBtn:SetAttribute("src", sf.altMaxEnable
						and "/luaui/images/terraform_brush/check_on.png"
						or "/luaui/images/terraform_brush/check_off.png")
				end
				-- Alt-max slider-row visibility driven by data-if="fpAltMaxEnable"
				local altMaxLabel = doc:GetElementById("fp-smart-alt-max-label")
				if altMaxLabel then altMaxLabel.inner_rml = tostring(sf.altMax) end
				local fpSAltMax = doc:GetElementById("fp-slider-alt-max")
				if fpSAltMax and ds ~= "fp-alt-max" then
					fpSAltMax:SetAttribute("value", tostring(sf.altMax))
				end

				-- SAMPLE button active state mirrors TerraformBrush heightSamplingMode
				local hsm = WG.TerraformBrush and (WG.TerraformBrush.getState() or {}).heightSamplingMode
				local sampMin = doc:GetElementById("btn-fp-alt-min-sample")
				if sampMin then sampMin:SetClass("active", hsm == "fpAltMin") end
				local sampMax = doc:GetElementById("btn-fp-alt-max-sample")
				if sampMax then sampMax:SetClass("active", hsm == "fpAltMax") end
			end

			-- Grid overlay / snap chip sync
			local fpGridOverlayBtn = doc:GetElementById("btn-fp-grid-overlay")
			if fpGridOverlayBtn then
				fpGridOverlayBtn:SetClass("active", fpState.gridOverlay == true)
			end
			local fpGridSnapBtn = doc:GetElementById("btn-fp-grid-snap")
			if fpGridSnapBtn then
				fpGridSnapBtn:SetClass("active", fpState.gridSnap == true)
			end

			-- Display overlay sync (shared TerraformBrush state)
			if WG.TerraformBrush then
				local tbState = WG.TerraformBrush.getState()
				if tbState then
					local fpGridDisp = doc:GetElementById("btn-fp-grid-overlay-display")
					if fpGridDisp then fpGridDisp:SetClass("active", tbState.gridOverlay == true) end
					local fpHMap = doc:GetElementById("btn-fp-height-colormap")
					if fpHMap then fpHMap:SetClass("active", tbState.heightColormap == true) end
					local fpMeas = doc:GetElementById("btn-fp-measure")
					if fpMeas then fpMeas:SetClass("active", tbState.measureActive == true) end
					local fpSym = doc:GetElementById("btn-fp-symmetry")
					if fpSym then fpSym:SetClass("active", tbState.symmetryActive == true) end
					-- Mirror symmetry visibility flags into data-model (data-if).
					if widgetState.dmHandle then
						widgetState.dmHandle.fpSymmetryActive = tbState.symmetryActive == true
						widgetState.dmHandle.fpSymmetryRadial = tbState.symmetryRadial == true
						widgetState.dmHandle.fpSymmetryMirrorAny = (tbState.symmetryMirrorX or tbState.symmetryMirrorY) and true or false
					end
					-- fp-symmetry-toolbar-row visibility driven by data-if="fpSymmetryActive"
					local fpSymRadial = doc:GetElementById("fp-btn-symmetry-radial")
					if fpSymRadial then fpSymRadial:SetClass("active", tbState.symmetryRadial == true) end
					local fpSymMX = doc:GetElementById("fp-btn-symmetry-mirror-x")
					if fpSymMX then fpSymMX:SetClass("active", tbState.symmetryMirrorX == true) end
					local fpSymMY = doc:GetElementById("fp-btn-symmetry-mirror-y")
					if fpSymMY then fpSymMY:SetClass("active", tbState.symmetryMirrorY == true) end
					-- fp-symmetry-radial-count-row visibility driven by data-if="fpSymmetryRadial"
					local fpSymRadLabel = doc:GetElementById("fp-symmetry-radial-count-label")
					if fpSymRadLabel then fpSymRadLabel.inner_rml = tostring(tbState.symmetryRadialCount or 2) end
					local fpSymRadSlider = doc:GetElementById("fp-slider-symmetry-radial-count")
					if fpSymRadSlider then fpSymRadSlider:SetAttribute("value", tostring(tbState.symmetryRadialCount or 2)) end
					-- fp-symmetry-mirror-angle-row visibility driven by data-if="fpSymmetryMirrorAny"
					local fpSymAngLabel = doc:GetElementById("fp-symmetry-mirror-angle-label")
					if fpSymAngLabel then fpSymAngLabel.inner_rml = tostring(math.floor(tbState.symmetryMirrorAngle or 0)) end
					local fpSymAngSlider = doc:GetElementById("fp-slider-symmetry-mirror-angle")
					if fpSymAngSlider then fpSymAngSlider:SetAttribute("value", tostring(tbState.symmetryMirrorAngle or 0)) end
				end
			end

			-- Feature history slider sync
			local sliderFpHist = doc:GetElementById("slider-fp-history")
			if sliderFpHist and ds ~= "fp-history" then
				local totalSteps = (fpState.undoCount or 0) + (fpState.redoCount or 0)
				local maxVal = math.min(totalSteps, 400)
				if maxVal < 1 then maxVal = 1 end
				sliderFpHist:SetAttribute("max", tostring(maxVal))
				sliderFpHist:SetAttribute("value", tostring(fpState.undoCount or 0))
			end
			local fpHistNumbox = doc:GetElementById("slider-fp-history-numbox")
			if fpHistNumbox then
				fpHistNumbox:SetAttribute("value", tostring(fpState.undoCount or 0))
			end

			uiState.updatingFromCode = false
		end

		-- Gray out unsupported shapes in feature mode (no ring, no fill)
		for shape, element in pairs(widgetState.shapeButtons) do
			if element and shape ~= "ring" and shape ~= "fill" then
				element:SetClass("disabled", false)
			end
		end

		-- P3.2 Feature Placer grayouts (per Phase 3 relevance matrix)
		if doc and ctx.setDisabledIds then
			local mode = fpState.mode or "scatter"
			local circular = (fpState.shape == "circle")
			local remove = (mode == "remove")
			local scatter = (mode == "scatter")
			local rotOff = circular or remove
			ctx.setDisabledIds(doc, {
				"fp-slider-rotation", "fp-slider-rotation-numbox",
				"btn-fp-rot-ccw", "btn-fp-rot-cw",
				"fp-slider-rot-random", "fp-slider-rot-random-numbox",
				"btn-fp-rot-random-down", "btn-fp-rot-random-up",
			}, rotOff)
			ctx.setDisabledIds(doc, {
				"fp-slider-count", "fp-slider-count-numbox",
				"btn-fp-count-down", "btn-fp-count-up",
				"fp-slider-cadence", "fp-slider-cadence-numbox",
				"btn-fp-cadence-down", "btn-fp-cadence-up",
				"btn-fp-dist-random", "btn-fp-dist-regular", "btn-fp-dist-clustered",
			}, not scatter)
		end

		setSummary("FEATURES", "#34d399",
			"", (fpState.mode or "place"):upper(),
			"", shapeNames[fpState.shape] or "Circle",
			"R ", tostring(fpState.radius or 0),
			"Count ", tostring(fpState.featureCount or 1))

end

return M