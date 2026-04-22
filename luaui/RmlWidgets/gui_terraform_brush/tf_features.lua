-- tf_features.lua: extracted tool module for gui_terraform_brush
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
	-- ============ Feature Placer controls ============

	-- Cache section elements for visibility toggling
	widgetState.tfControlsEl = doc:GetElementById("tf-terraform-controls")
	widgetState.fpControlsEl = doc:GetElementById("tf-feature-controls")
	widgetState.fpSubmodesEl = doc:GetElementById("tf-feature-submodes")
	widgetState.shapeRowEl = doc:GetElementById("tf-shape-row")
	widgetState.smoothSubmodesEl = doc:GetElementById("tf-smooth-submodes")
	widgetState.fullRestoreEl = doc:GetElementById("btn-full-restore")
	widgetState.fullRestoreLabel1 = doc:GetElementById("full-restore-label-1")
	widgetState.fullRestoreLabel2 = doc:GetElementById("full-restore-label-2")
	widgetState.metalCleanEl = doc:GetElementById("btn-metal-clean")
	widgetState.metalCleanLabel = doc:GetElementById("metal-clean-label")

	-- Feature sub-mode buttons
	widgetState.fpSubModeButtons.scatter = doc:GetElementById("btn-fp-scatter")
	widgetState.fpSubModeButtons.point = doc:GetElementById("btn-fp-point")
	widgetState.fpSubModeButtons.remove = doc:GetElementById("btn-fp-remove")

	for fmode, element in pairs(widgetState.fpSubModeButtons) do
		if element then
			element:AddEventListener("click", function(event)
				playSound("modeSwitch")
				if WG.FeaturePlacer then
					WG.FeaturePlacer.setMode(fmode)
				end
				setActiveClass(widgetState.fpSubModeButtons, fmode)
				event:StopPropagation()
			end, false)
		end
	end

	-- Distribution buttons
	widgetState.fpDistButtons.random    = doc:GetElementById("btn-fp-dist-random")
	widgetState.fpDistButtons.regular   = doc:GetElementById("btn-fp-dist-regular")
	widgetState.fpDistButtons.clustered = doc:GetElementById("btn-fp-dist-clustered")

	for dist, element in pairs(widgetState.fpDistButtons) do
		if element then
			element:AddEventListener("click", function(event)
				playSound("shapeSwitch")
				if WG.FeaturePlacer then
					WG.FeaturePlacer.setDistribution(dist)
				end
				setActiveClass(widgetState.fpDistButtons, dist)
				event:StopPropagation()
			end, false)
		end
	end

	-- Feature size slider + buttons
	local fpSliderSize = doc:GetElementById("fp-slider-size")
	if fpSliderSize then
		trackSliderDrag(fpSliderSize, "fp-size")
		fpSliderSize:AddEventListener("change", function(event)
			if not uiState.updatingFromCode and WG.FeaturePlacer then
				local val = tonumber(fpSliderSize:GetAttribute("value")) or 200
				WG.FeaturePlacer.setRadius(val)
			end
			event:StopPropagation()
		end, false)
	end

	local fpSizeUp = doc:GetElementById("btn-fp-size-up")
	if fpSizeUp then
		fpSizeUp:AddEventListener("click", function(event)
			if WG.FeaturePlacer then
				local st = WG.FeaturePlacer.getState()
				WG.FeaturePlacer.setRadius(st.radius + RADIUS_STEP * 4)
			end
			event:StopPropagation()
		end, false)
	end

	local fpSizeDown = doc:GetElementById("btn-fp-size-down")
	if fpSizeDown then
		fpSizeDown:AddEventListener("click", function(event)
			if WG.FeaturePlacer then
				local st = WG.FeaturePlacer.getState()
				WG.FeaturePlacer.setRadius(st.radius - RADIUS_STEP * 4)
			end
			event:StopPropagation()
		end, false)
	end

	-- Feature rotation slider + buttons
	local fpSliderRotation = doc:GetElementById("fp-slider-rotation")
	if fpSliderRotation then
		trackSliderDrag(fpSliderRotation, "fp-rotation")
		fpSliderRotation:AddEventListener("change", function(event)
			if not uiState.updatingFromCode and WG.FeaturePlacer then
				local val = tonumber(fpSliderRotation:GetAttribute("value")) or 0
				WG.FeaturePlacer.setRotation(val)
			end
			event:StopPropagation()
		end, false)
	end

	local fpRotCW = doc:GetElementById("btn-fp-rot-cw")
	if fpRotCW then
		fpRotCW:AddEventListener("click", function(event)
			if WG.FeaturePlacer then WG.FeaturePlacer.rotate(ROTATION_STEP) end
			event:StopPropagation()
		end, false)
	end

	local fpRotCCW = doc:GetElementById("btn-fp-rot-ccw")
	if fpRotCCW then
		fpRotCCW:AddEventListener("click", function(event)
			if WG.FeaturePlacer then WG.FeaturePlacer.rotate(-ROTATION_STEP) end
			event:StopPropagation()
		end, false)
	end

	-- Feature rotation randomness slider
	local fpSliderRotRandom = doc:GetElementById("fp-slider-rot-random")
	if fpSliderRotRandom then
		trackSliderDrag(fpSliderRotRandom, "fp-rot-random")
		fpSliderRotRandom:AddEventListener("change", function(event)
			if not uiState.updatingFromCode and WG.FeaturePlacer then
				local val = tonumber(fpSliderRotRandom:GetAttribute("value")) or 100
				WG.FeaturePlacer.setRotRandom(val)
			end
			event:StopPropagation()
		end, false)
	end

	local fpRotRndDown = doc:GetElementById("btn-fp-rot-random-down")
	if fpRotRndDown then
		fpRotRndDown:AddEventListener("click", function(event)
			if WG.FeaturePlacer then
				local st = WG.FeaturePlacer.getState()
				WG.FeaturePlacer.setRotRandom(math.max(0, (st.rotRandom or 100) - 5))
			end
			event:StopPropagation()
		end, false)
	end

	local fpRotRndUp = doc:GetElementById("btn-fp-rot-random-up")
	if fpRotRndUp then
		fpRotRndUp:AddEventListener("click", function(event)
			if WG.FeaturePlacer then
				local st = WG.FeaturePlacer.getState()
				WG.FeaturePlacer.setRotRandom(math.min(100, (st.rotRandom or 0) + 5))
			end
			event:StopPropagation()
		end, false)
	end

	-- Feature count slider + buttons
	local fpSliderCount = doc:GetElementById("fp-slider-count")
	if fpSliderCount then
		trackSliderDrag(fpSliderCount, "fp-count")
		fpSliderCount:AddEventListener("change", function(event)
			if not uiState.updatingFromCode and WG.FeaturePlacer then
				local val = tonumber(fpSliderCount:GetAttribute("value")) or 10
				WG.FeaturePlacer.setFeatureCount(val)
			end
			event:StopPropagation()
		end, false)
	end

	local fpCountUp = doc:GetElementById("btn-fp-count-up")
	if fpCountUp then
		fpCountUp:AddEventListener("click", function(event)
			if WG.FeaturePlacer then
				local st = WG.FeaturePlacer.getState()
				WG.FeaturePlacer.setFeatureCount(st.featureCount + 1)
			end
			event:StopPropagation()
		end, false)
	end

	local fpCountDown = doc:GetElementById("btn-fp-count-down")
	if fpCountDown then
		fpCountDown:AddEventListener("click", function(event)
			if WG.FeaturePlacer then
				local st = WG.FeaturePlacer.getState()
				WG.FeaturePlacer.setFeatureCount(st.featureCount - 1)
			end
			event:StopPropagation()
		end, false)
	end

	-- Feature cadence slider + buttons
	local fpSliderCadence = doc:GetElementById("fp-slider-cadence")
	if fpSliderCadence then
		trackSliderDrag(fpSliderCadence, "fp-cadence")
		fpSliderCadence:AddEventListener("change", function(event)
			if not uiState.updatingFromCode and WG.FeaturePlacer then
				local sliderVal = tonumber(fpSliderCadence:GetAttribute("value")) or 0
				WG.FeaturePlacer.setCadence(sliderToCadence(sliderVal))
			end
			event:StopPropagation()
		end, false)
	end

	local fpCadenceUp = doc:GetElementById("btn-fp-cadence-up")
	if fpCadenceUp then
		fpCadenceUp:AddEventListener("click", function(event)
			if WG.FeaturePlacer then
				local st = WG.FeaturePlacer.getState()
				local step = math.max(1, math.floor(st.cadence * 0.2))
				WG.FeaturePlacer.setCadence(st.cadence + step)
			end
			event:StopPropagation()
		end, false)
	end

	local fpCadenceDown = doc:GetElementById("btn-fp-cadence-down")
	if fpCadenceDown then
		fpCadenceDown:AddEventListener("click", function(event)
			if WG.FeaturePlacer then
				local st = WG.FeaturePlacer.getState()
				local step = math.max(1, math.floor(st.cadence * 0.2))
				WG.FeaturePlacer.setCadence(st.cadence - step)
			end
			event:StopPropagation()
		end, false)
	end

	-- Feature undo/redo buttons
	local fpUndoBtn = doc:GetElementById("btn-fp-undo")
	if fpUndoBtn then
		fpUndoBtn:AddEventListener("click", function(event)
			playSound("undo")
			if WG.FeaturePlacer then WG.FeaturePlacer.undo() end
			event:StopPropagation()
		end, false)
	end

	local fpRedoBtn = doc:GetElementById("btn-fp-redo")
	if fpRedoBtn then
		fpRedoBtn:AddEventListener("click", function(event)
			playSound("undo")
			if WG.FeaturePlacer then WG.FeaturePlacer.redo() end
			event:StopPropagation()
		end, false)
	end

	-- Feature history slider
	local sliderFpHistory = doc:GetElementById("slider-fp-history")
	if sliderFpHistory then
		trackSliderDrag(sliderFpHistory, "fp-history")
		sliderFpHistory:AddEventListener("change", function(event)
			if uiState.updatingFromCode then event:StopPropagation(); return end
			if not WG.FeaturePlacer then event:StopPropagation(); return end
			local val = tonumber(sliderFpHistory:GetAttribute("value")) or 0
			local fpSt = WG.FeaturePlacer.getState()
			if not fpSt then event:StopPropagation(); return end
			local currentUndoCount = fpSt.undoCount or 0
			local diff = val - currentUndoCount
			if diff > 0 then
				for i = 1, diff do
					WG.FeaturePlacer.redo()
				end
			elseif diff < 0 then
				for i = 1, -diff do
					WG.FeaturePlacer.undo()
				end
			end
			event:StopPropagation()
		end, false)
	end

	-- Feature save/load/clear buttons
	local fpSaveBtn = doc:GetElementById("btn-fp-save")
	if fpSaveBtn then
		fpSaveBtn:AddEventListener("click", function(event)
			playSound("save")
			if WG.FeaturePlacer then WG.FeaturePlacer.save() end
			event:StopPropagation()
		end, false)
	end

	local fpLoadBtn = doc:GetElementById("btn-fp-load")
	if fpLoadBtn then
		fpLoadBtn:AddEventListener("click", function(event)
			playSound("dropdown")
			-- Toggle the save list visibility and populate it
			local listEl = doc:GetElementById("fp-save-load-list")
			if listEl then
				local isHidden = listEl.class_name and listEl.class_name:find("hidden") ~= nil
				listEl:SetClass("hidden", not isHidden)
				if isHidden and WG.FeaturePlacer then
					-- Rebuild the file list
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
								listEl:SetClass("hidden", true)
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
			event:StopPropagation()
		end, false)
	end

	local fpClearAllBtn = doc:GetElementById("btn-fp-clearall")
	if fpClearAllBtn then
		fpClearAllBtn:AddEventListener("click", function(event)
			playSound("reset")
			if WG.FeaturePlacer then WG.FeaturePlacer.clearAll() end
			event:StopPropagation()
		end, false)
	end


	-- ============ Smart distribution filter controls ============
	local fpSmartToggle = doc:GetElementById("btn-fp-smart-toggle")
	if fpSmartToggle then
		fpSmartToggle:AddEventListener("click", function(event)
			if WG.FeaturePlacer then
				local st = WG.FeaturePlacer.getState()
				playSound(st.smartEnabled and "toggleOff" or "toggleOn")
				WG.FeaturePlacer.setSmartEnabled(not st.smartEnabled)
			end
			event:StopPropagation()
		end, false)
	end

	local function wireSmartToggle(btnId, filterKey)
		local btn = doc:GetElementById(btnId)
		if btn then
			btn:AddEventListener("click", function(event)
				if WG.FeaturePlacer then
					local sf = WG.FeaturePlacer.getState().smartFilters
					playSound(sf[filterKey] and "toggleOff" or "toggleOn")
					WG.FeaturePlacer.setSmartFilter(filterKey, not sf[filterKey])
				end
				event:StopPropagation()
			end, false)
		end
	end
	wireSmartToggle("btn-fp-alt-min-enable", "altMinEnable")
	wireSmartToggle("btn-fp-alt-max-enable", "altMaxEnable")

	-- Altitude min/max SAMPLE buttons: toggle height-sampling mode for FP filter endpoints
	local function wireAltSampler(btnId, target)
		local btn = doc:GetElementById(btnId)
		if btn then
			btn:AddEventListener("click", function(event)
				if WG.TerraformBrush then
					local cur = (WG.TerraformBrush.getState() or {}).heightSamplingMode
					WG.TerraformBrush.setHeightSamplingMode(cur == target and nil or target)
				end
				event:StopPropagation()
			end, false)
		end
	end
	wireAltSampler("btn-fp-alt-min-sample", "fpAltMin")
	wireAltSampler("btn-fp-alt-max-sample", "fpAltMax")

	-- Display overlay: Grid (feature panel)
	local btnFpGridDisplay = doc:GetElementById("btn-fp-grid-overlay-display")
	if btnFpGridDisplay then
		btnFpGridDisplay:AddEventListener("click", function(event)
			if WG.TerraformBrush then
				local state = WG.TerraformBrush.getState()
				local newVal = not (state and state.gridOverlay)
				playSound(newVal and "toggleOn" or "toggleOff")
				WG.TerraformBrush.setGridOverlay(newVal)
				btnFpGridDisplay:SetClass("active", newVal)
			end
			event:StopPropagation()
		end, false)
	end

	-- Display overlay: Height Map (feature panel)
	local btnFpHeightMap = doc:GetElementById("btn-fp-height-colormap")
	if btnFpHeightMap then
		btnFpHeightMap:AddEventListener("click", function(event)
			if WG.TerraformBrush then
				local state = WG.TerraformBrush.getState()
				local newVal = not (state and state.heightColormap)
				playSound(newVal and "toggleOn" or "toggleOff")
				WG.TerraformBrush.setHeightColormap(newVal)
				btnFpHeightMap:SetClass("active", newVal)
			end
			event:StopPropagation()
		end, false)
	end

	-- Instruments: Measure (feature panel)
	local btnFpMeasure = doc:GetElementById("btn-fp-measure")
	if btnFpMeasure then
		btnFpMeasure:AddEventListener("click", function(event)
			if WG.TerraformBrush then
				local state = WG.TerraformBrush.getState()
				local newVal = not (state and state.measureActive)
				playSound(newVal and "toggleOn" or "toggleOff")
				WG.TerraformBrush.setMeasureActive(newVal)
				btnFpMeasure:SetClass("active", newVal)
			end
			event:StopPropagation()
		end, false)
	end

	-- Instruments: Symmetry (feature panel)
	local btnFpSymmetry = doc:GetElementById("btn-fp-symmetry")
	local fpSymRow = doc:GetElementById("fp-symmetry-toolbar-row")
	if btnFpSymmetry then
		btnFpSymmetry:AddEventListener("click", function(event)
			if WG.TerraformBrush then
				local state = WG.TerraformBrush.getState()
				local newVal = not (state and state.symmetryActive)
				playSound(newVal and "toggleOn" or "toggleOff")
				WG.TerraformBrush.setSymmetryActive(newVal)
				btnFpSymmetry:SetClass("active", newVal)
				if fpSymRow then fpSymRow:SetClass("hidden", not newVal) end
			end
			event:StopPropagation()
		end, false)
	end

	-- Feature panel symmetry sub-toolbar handlers
	do
		local function fpSymBtn(id, fn)
			local el = doc:GetElementById(id)
			if el then el:AddEventListener("click", function(ev) fn(ev); ev:StopPropagation() end, false) end
			return el
		end
		fpSymBtn("fp-btn-symmetry-radial", function()
			if WG.TerraformBrush then
				local s = WG.TerraformBrush.getState()
				WG.TerraformBrush.setSymmetryRadial(not (s and s.symmetryRadial))
			end
		end)
		fpSymBtn("fp-btn-symmetry-mirror-x", function()
			if WG.TerraformBrush then
				local s = WG.TerraformBrush.getState()
				WG.TerraformBrush.setSymmetryMirrorX(not (s and s.symmetryMirrorX))
			end
		end)
		fpSymBtn("fp-btn-symmetry-mirror-y", function()
			if WG.TerraformBrush then
				local s = WG.TerraformBrush.getState()
				WG.TerraformBrush.setSymmetryMirrorY(not (s and s.symmetryMirrorY))
			end
		end)
		fpSymBtn("fp-btn-symmetry-place-origin", function()
			if WG.TerraformBrush then
				WG.TerraformBrush.setSymmetryPlacingOrigin(true)
			end
		end)
		fpSymBtn("fp-btn-symmetry-center-origin", function()
			if WG.TerraformBrush then
				WG.TerraformBrush.setSymmetryOrigin(nil, nil)
				playSound("toggleOff")
			end
		end)
		fpSymBtn("fp-btn-symmetry-count-down", function()
			if WG.TerraformBrush then
				local s = WG.TerraformBrush.getState()
				local c = math.max(2, (s and s.symmetryRadialCount or 2) - 1)
				WG.TerraformBrush.setSymmetryRadialCount(c)
			end
		end)
		fpSymBtn("fp-btn-symmetry-count-up", function()
			if WG.TerraformBrush then
				local s = WG.TerraformBrush.getState()
				local c = math.min(16, (s and s.symmetryRadialCount or 2) + 1)
				WG.TerraformBrush.setSymmetryRadialCount(c)
			end
		end)
		fpSymBtn("fp-btn-symmetry-angle-down", function()
			if WG.TerraformBrush then
				local s = WG.TerraformBrush.getState()
				local a = ((s and s.symmetryMirrorAngle or 0) - 5) % 360
				WG.TerraformBrush.setSymmetryMirrorAngle(a)
			end
		end)
		fpSymBtn("fp-btn-symmetry-angle-up", function()
			if WG.TerraformBrush then
				local s = WG.TerraformBrush.getState()
				local a = ((s and s.symmetryMirrorAngle or 0) + 5) % 360
				WG.TerraformBrush.setSymmetryMirrorAngle(a)
			end
		end)
		local fpSymCountSlider = doc:GetElementById("fp-slider-symmetry-radial-count")
		if fpSymCountSlider then
			fpSymCountSlider:AddEventListener("change", function(ev)
				if uiState.updatingFromCode then ev:StopPropagation(); return end
				if WG.TerraformBrush then
					local v = tonumber(fpSymCountSlider:GetAttribute("value")) or 2
					WG.TerraformBrush.setSymmetryRadialCount(v)
				end
				ev:StopPropagation()
			end, false)
		end
		local fpSymAngleSlider = doc:GetElementById("fp-slider-symmetry-mirror-angle")
		if fpSymAngleSlider then
			fpSymAngleSlider:AddEventListener("change", function(ev)
				if uiState.updatingFromCode then ev:StopPropagation(); return end
				if WG.TerraformBrush then
					local v = tonumber(fpSymAngleSlider:GetAttribute("value")) or 0
					WG.TerraformBrush.setSymmetryMirrorAngle(v)
				end
				ev:StopPropagation()
			end, false)
		end
	end

	local btnFpGridOverlay = doc:GetElementById("btn-fp-grid-overlay")
	if btnFpGridOverlay then
		btnFpGridOverlay:AddEventListener("click", function(event)
			if WG.FeaturePlacer then
				local st = WG.FeaturePlacer.getState()
				local newVal = not (st and st.gridOverlay)
				WG.FeaturePlacer.setGridOverlay(newVal)
				btnFpGridOverlay:SetClass("active", newVal)
			end
			event:StopPropagation()
		end, false)
	end

	local btnFpGridSnap = doc:GetElementById("btn-fp-grid-snap")
	if btnFpGridSnap then
		btnFpGridSnap:AddEventListener("click", function(event)
			if WG.FeaturePlacer then
				local st = WG.FeaturePlacer.getState()
				local newVal = not (st and st.gridSnap)
				WG.FeaturePlacer.setGridSnap(newVal)
				btnFpGridSnap:SetClass("active", newVal)
			end
			event:StopPropagation()
		end, false)
	end

	local fpSliderSlopeMax = doc:GetElementById("fp-slider-slope-max")
	if fpSliderSlopeMax then
		trackSliderDrag(fpSliderSlopeMax, "fp-slope-max")
		fpSliderSlopeMax:AddEventListener("change", function(event)
			if not uiState.updatingFromCode and WG.FeaturePlacer then
				local val = tonumber(fpSliderSlopeMax:GetAttribute("value")) or 45
				WG.FeaturePlacer.setSmartFilter("slopeMax", val)
			end
			event:StopPropagation()
		end, false)
	end

	local fpSliderSlopeMin = doc:GetElementById("fp-slider-slope-min")
	if fpSliderSlopeMin then
		trackSliderDrag(fpSliderSlopeMin, "fp-slope-min")
		fpSliderSlopeMin:AddEventListener("change", function(event)
			if not uiState.updatingFromCode and WG.FeaturePlacer then
				local val = tonumber(fpSliderSlopeMin:GetAttribute("value")) or 10
				WG.FeaturePlacer.setSmartFilter("slopeMin", val)
			end
			event:StopPropagation()
		end, false)
	end

	local fpSliderAltMin = doc:GetElementById("fp-slider-alt-min")
	if fpSliderAltMin then
		trackSliderDrag(fpSliderAltMin, "fp-alt-min")
		fpSliderAltMin:AddEventListener("change", function(event)
			if not uiState.updatingFromCode and WG.FeaturePlacer then
				local val = tonumber(fpSliderAltMin:GetAttribute("value")) or 0
				-- Couple: clamp max up if it's below new min
				local sf = WG.FeaturePlacer.getState().smartFilters
				if sf.altMaxEnable and val > sf.altMax then
					WG.FeaturePlacer.setSmartFilter("altMax", val)
				end
				WG.FeaturePlacer.setSmartFilter("altMin", val)
			end
			event:StopPropagation()
		end, false)
	end

	local fpSliderAltMax = doc:GetElementById("fp-slider-alt-max")
	if fpSliderAltMax then
		trackSliderDrag(fpSliderAltMax, "fp-alt-max")
		fpSliderAltMax:AddEventListener("change", function(event)
			if not uiState.updatingFromCode and WG.FeaturePlacer then
				local val = tonumber(fpSliderAltMax:GetAttribute("value")) or 200
				-- Couple: clamp min down if it's above new max
				local sf = WG.FeaturePlacer.getState().smartFilters
				if sf.altMinEnable and val < sf.altMin then
					WG.FeaturePlacer.setSmartFilter("altMin", val)
				end
				WG.FeaturePlacer.setSmartFilter("altMax", val)
			end
			event:StopPropagation()
		end, false)
	end

	-- Feature placer smart filter +/- buttons
	do
		local function wireFpSmartBtn(btnId, filterKey, step)
			local btn = doc:GetElementById(btnId)
			if btn then
				btn:AddEventListener("click", function(event)
					if WG.FeaturePlacer then
						local sf = WG.FeaturePlacer.getState().smartFilters
						WG.FeaturePlacer.setSmartFilter(filterKey, (sf[filterKey] or 0) + step)
					end
					event:StopPropagation()
				end, false)
			end
		end
		wireFpSmartBtn("btn-fp-slope-max-up",   "slopeMax",  5)
		wireFpSmartBtn("btn-fp-slope-max-down", "slopeMax", -5)
		wireFpSmartBtn("btn-fp-slope-min-up",   "slopeMin",  5)
		wireFpSmartBtn("btn-fp-slope-min-down", "slopeMin", -5)
		wireFpSmartBtn("btn-fp-alt-min-up",     "altMin",   10)
		wireFpSmartBtn("btn-fp-alt-min-down",   "altMin",  -10)
		wireFpSmartBtn("btn-fp-alt-max-up",     "altMax",   10)
		wireFpSmartBtn("btn-fp-alt-max-down",   "altMax",  -10)
	end

end

function M.sync(doc, ctx, fpState, setSummary)
	local widgetState = ctx.widgetState
	local uiState = ctx.uiState
	local WG = ctx.WG
	local setActiveClass = ctx.setActiveClass
	local syncAndFlash = ctx.syncAndFlash
	local cadenceToSlider = ctx.cadenceToSlider
	local shapeNames = ctx.shapeNames
		-- ===== Feature Placer mode: update feature controls =====
		local featuresBtn = doc and doc:GetElementById("btn-features")
		if featuresBtn then
			featuresBtn:SetClass("active", true)
		end
		-- Clear terraform mode highlights
		setActiveClass(widgetState.modeButtons, nil)

		-- Feature sub-mode buttons
		setActiveClass(widgetState.fpSubModeButtons, fpState.mode)

		-- Feature distribution buttons
		setActiveClass(widgetState.fpDistButtons, fpState.distribution)

		-- Feature shape buttons
		setActiveClass(widgetState.shapeButtons, fpState.shape)

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
			if fpState.smartFilters then
				local sf = fpState.smartFilters

				-- Filter chips: Avoid Water mirrors filter state; slope sub-chips mirror avoidCliffs / preferSlopes
				local avoidWaterChip = doc:GetElementById("fp-filter-chip-avoid-water")
				if avoidWaterChip then avoidWaterChip:SetClass("active", sf.avoidWater == true) end
				local slopeAvoidChip = doc:GetElementById("fp-slope-mode-avoid")
				if slopeAvoidChip then slopeAvoidChip:SetClass("active", sf.avoidCliffs == true) end
				local slopePreferChip = doc:GetElementById("fp-slope-mode-prefer")
				if slopePreferChip then slopePreferChip:SetClass("active", sf.preferSlopes == true) end

				local slopeMaxRow = doc:GetElementById("fp-smart-slope-max-row")
				if slopeMaxRow then slopeMaxRow:SetClass("hidden", not sf.avoidCliffs) end
				local slopeMaxSliderRow = doc:GetElementById("fp-smart-slope-max-slider-row")
				if slopeMaxSliderRow then slopeMaxSliderRow:SetClass("hidden", not sf.avoidCliffs) end
				local slopeMaxLabel = doc:GetElementById("fp-smart-slope-max-label")
				if slopeMaxLabel then slopeMaxLabel.inner_rml = tostring(sf.slopeMax) end
				local fpSSlopeMax = doc:GetElementById("fp-slider-slope-max")
				if fpSSlopeMax and ds ~= "fp-slope-max" then
					fpSSlopeMax:SetAttribute("value", tostring(sf.slopeMax))
				end

				local slopeMinRow = doc:GetElementById("fp-smart-slope-min-row")
				if slopeMinRow then slopeMinRow:SetClass("hidden", not sf.preferSlopes) end
				local slopeMinSliderRow = doc:GetElementById("fp-smart-slope-min-slider-row")
				if slopeMinSliderRow then slopeMinSliderRow:SetClass("hidden", not sf.preferSlopes) end
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
				local altMinSliderRow = doc:GetElementById("fp-smart-alt-min-slider-row")
				if altMinSliderRow then altMinSliderRow:SetClass("hidden", not sf.altMinEnable) end
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
				local altMaxSliderRow = doc:GetElementById("fp-smart-alt-max-slider-row")
				if altMaxSliderRow then altMaxSliderRow:SetClass("hidden", not sf.altMaxEnable) end
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
					-- fp-symmetry sub-toolbar sync
					local fpSymRow2 = doc:GetElementById("fp-symmetry-toolbar-row")
					if fpSymRow2 then fpSymRow2:SetClass("hidden", not tbState.symmetryActive) end
					local fpSymRadial = doc:GetElementById("fp-btn-symmetry-radial")
					if fpSymRadial then fpSymRadial:SetClass("active", tbState.symmetryRadial == true) end
					local fpSymMX = doc:GetElementById("fp-btn-symmetry-mirror-x")
					if fpSymMX then fpSymMX:SetClass("active", tbState.symmetryMirrorX == true) end
					local fpSymMY = doc:GetElementById("fp-btn-symmetry-mirror-y")
					if fpSymMY then fpSymMY:SetClass("active", tbState.symmetryMirrorY == true) end
					local fpSymRadRow = doc:GetElementById("fp-symmetry-radial-count-row")
					if fpSymRadRow then fpSymRadRow:SetClass("hidden", not tbState.symmetryRadial) end
					local fpSymRadLabel = doc:GetElementById("fp-symmetry-radial-count-label")
					if fpSymRadLabel then fpSymRadLabel.inner_rml = tostring(tbState.symmetryRadialCount or 2) end
					local fpSymRadSlider = doc:GetElementById("fp-slider-symmetry-radial-count")
					if fpSymRadSlider then fpSymRadSlider:SetAttribute("value", tostring(tbState.symmetryRadialCount or 2)) end
					local fpHasAxial = tbState.symmetryMirrorX or tbState.symmetryMirrorY
					local fpSymAngRow = doc:GetElementById("fp-symmetry-mirror-angle-row")
					if fpSymAngRow then fpSymAngRow:SetClass("hidden", not fpHasAxial) end
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
				"fp-btn-rot-ccw", "fp-btn-rot-cw",
				"fp-slider-rot-random", "fp-slider-rot-random-numbox",
			}, rotOff)
			ctx.setDisabledIds(doc, {
				"fp-slider-count", "fp-slider-count-numbox",
				"fp-btn-count-down", "fp-btn-count-up",
				"fp-slider-cadence", "fp-slider-cadence-numbox",
				"fp-btn-cadence-down", "fp-btn-cadence-up",
				"fp-btn-dist-random", "fp-btn-dist-regular", "fp-btn-dist-clustered",
			}, not scatter)
		end

		setSummary("FEATURES", "#34d399",
			"", (fpState.mode or "place"):upper(),
			"", shapeNames[fpState.shape] or "Circle",
			"R ", tostring(fpState.radius or 0),
			"Count ", tostring(fpState.featureCount or 1))

end

return M
