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
		"grid-snap-size",
	}) do
		local sl = doc:GetElementById("fp-slider-" .. sid)
		if sl then trackSliderDrag(sl, "fp-" .. sid) end
	end
	local sliderFpHistory = doc:GetElementById("slider-fp-history")
	if sliderFpHistory then trackSliderDrag(sliderFpHistory, "fp-history") end

	-- All data-event-click/change handlers (onFpXxx) are defined in initialModel in gui_terraform_brush.lua.
end

function M.sync(doc, ctx, fpState, setSummary)
	local widgetState = ctx.widgetState
	local uiState = ctx.uiState
	local WG = ctx.WG
	local syncAndFlash = ctx.syncAndFlash
	local cadenceToSlider = ctx.cadenceToSlider
	local shapeNames = ctx.shapeNames
		-- ===== Feature Placer mode: update feature controls =====
		-- btn-features active state driven by data-class-active="activeTool == 'fp'" in RML.
		-- Clear terraform mode highlights


		-- DISPLAY/INSTRUMENTS warn chips (shared TB state mirror)
		if doc and ctx.syncWarnChip then
			local tbs = (WG.TerraformBrush and WG.TerraformBrush.getState()) or {}
			local dispActive = tbs.gridOverlay or tbs.heightColormap
			local instActive = fpState.gridSnap or tbs.measureActive or tbs.symmetryActive
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

			-- Labels driven by {{fpRadiusStr}}/{{fpRotationStr}}/{{fpRotRandomStr}}/{{fpCountStr}}/{{fpCadenceStr}} in RML.
			-- Phase 2 step 4: mirror to data-model {{Str}} interpolation
			if widgetState.dmHandle then
				local dm = widgetState.dmHandle
				local v = tostring(fpState.radius)
				if dm.fpRadiusStr ~= v then dm.fpRadiusStr = v end
				v = tostring(fpState.rotation)
				if dm.fpRotationStr ~= v then dm.fpRotationStr = v end
				v = tostring(fpState.rotRandom)
				if dm.fpRotRandomStr ~= v then dm.fpRotRandomStr = v end
				v = tostring(fpState.featureCount)
				if dm.fpCountStr ~= v then dm.fpCountStr = v end
				v = tostring(fpState.cadence)
				if dm.fpCadenceStr ~= v then dm.fpCadenceStr = v end
			end

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
				-- Label driven by {{fpSlopeMaxStr}} in RML.
				if widgetState.dmHandle then
					local v = tostring(sf.slopeMax)
					if widgetState.dmHandle.fpSlopeMaxStr ~= v then widgetState.dmHandle.fpSlopeMaxStr = v end
				end
				local fpSSlopeMax = doc:GetElementById("fp-slider-slope-max")
				if fpSSlopeMax and ds ~= "fp-slope-max" then
					fpSSlopeMax:SetAttribute("value", tostring(sf.slopeMax))
				end

				-- Slope-min rows visibility driven by data-if="fpPreferSlopes"
				-- Label driven by {{fpSlopeMinStr}} in RML.
				if widgetState.dmHandle then
					local v = tostring(sf.slopeMin)
					if widgetState.dmHandle.fpSlopeMinStr ~= v then widgetState.dmHandle.fpSlopeMinStr = v end
				end
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
				-- Label driven by {{fpAltMinStr}} in RML.
				if widgetState.dmHandle then
					local v = tostring(sf.altMin)
					if widgetState.dmHandle.fpAltMinStr ~= v then widgetState.dmHandle.fpAltMinStr = v end
				end
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
				-- Label driven by {{fpAltMaxStr}} in RML.
				if widgetState.dmHandle then
					local v = tostring(sf.altMax)
					if widgetState.dmHandle.fpAltMaxStr ~= v then widgetState.dmHandle.fpAltMaxStr = v end
				end
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

			-- Grid snap chip sync (FP-specific snap state)
			local fpGridSnapBtn = doc:GetElementById("btn-fp-grid-snap")
			if fpGridSnapBtn then
				fpGridSnapBtn:SetClass("active", fpState.gridSnap == true)
			end
			if widgetState.dmHandle then
				widgetState.dmHandle.fpGridSnap = fpState.gridSnap == true
				-- Snap size label + slider
				local ss = tostring(fpState.gridSnapSize or 48)
				if widgetState.dmHandle.fpGridSnapSizeStr ~= ss then widgetState.dmHandle.fpGridSnapSizeStr = ss end
			end
			local fpSnapSizeSlider = doc:GetElementById("fp-slider-grid-snap-size")
			if fpSnapSizeSlider and uiState.draggingSlider ~= "fp-grid-snap-size" then
				fpSnapSizeSlider:SetAttribute("value", tostring(fpState.gridSnapSize or 48))
			end
			local fpSnapSizeNb = doc:GetElementById("fp-slider-grid-snap-size-numbox")
			if fpSnapSizeNb then fpSnapSizeNb:SetAttribute("value", tostring(fpState.gridSnapSize or 48)) end

			-- Display overlay sync (shared TerraformBrush state)
			if WG.TerraformBrush then
				local tbState = WG.TerraformBrush.getState()
				if tbState then
					local fpHMap = doc:GetElementById("btn-fp-height-colormap")
					if fpHMap then fpHMap:SetClass("active", tbState.heightColormap == true) end
					local fpMeas = doc:GetElementById("btn-fp-measure")
					if fpMeas then fpMeas:SetClass("active", tbState.measureActive == true) end
					local fpSym = doc:GetElementById("btn-fp-symmetry")
					if fpSym then fpSym:SetClass("active", tbState.symmetryActive == true) end
					-- Mirror display + symmetry/measure flags into data-model.
					if widgetState.dmHandle then
						-- fpGridOverlay is FP's own building grid, NOT the terrain grid
						widgetState.dmHandle.fpGridOverlay    = fpState.gridOverlay == true
						widgetState.dmHandle.fpHeightColormap = tbState.heightColormap == true
						widgetState.dmHandle.fpSymmetryActive = tbState.symmetryActive == true
						widgetState.dmHandle.fpSymmetryRadial = tbState.symmetryRadial == true
						widgetState.dmHandle.fpSymmetryMirrorAny = (tbState.symmetryMirrorX or tbState.symmetryMirrorY) and true or false
						widgetState.dmHandle.fpSymHasAxis = (tbState.symmetryRadial or tbState.symmetryMirrorX or tbState.symmetryMirrorY) and true or false
						widgetState.dmHandle.fpMeasureActive    = tbState.measureActive == true
						widgetState.dmHandle.fpMeasureRulerMode  = tbState.measureRulerMode == true
						widgetState.dmHandle.fpMeasureStickyMode = tbState.measureStickyMode == true
						widgetState.dmHandle.fpMeasureShowLength = tbState.measureShowLength == true
						widgetState.dmHandle.fpSymMirrorX = tbState.symmetryMirrorX == true
						widgetState.dmHandle.fpSymMirrorY = tbState.symmetryMirrorY == true
					end
					-- fp-symmetry-toolbar-row visibility driven by data-if="fpSymmetryActive"
					local fpSymRadial = doc:GetElementById("fp-btn-symmetry-radial")
					if fpSymRadial then fpSymRadial:SetClass("active", tbState.symmetryRadial == true) end
					local fpSymMX = doc:GetElementById("fp-btn-symmetry-mirror-x")
					if fpSymMX then fpSymMX:SetClass("active", tbState.symmetryMirrorX == true) end
					local fpSymMY = doc:GetElementById("fp-btn-symmetry-mirror-y")
					if fpSymMY then fpSymMY:SetClass("active", tbState.symmetryMirrorY == true) end
					-- Measure sub-chip active states
					local fpMeasRL = doc:GetElementById("fp-btn-measure-ruler")
					if fpMeasRL then fpMeasRL:SetClass("active", tbState.measureRulerMode == true) end
					local fpMeasST = doc:GetElementById("fp-btn-measure-sticky")
					if fpMeasST then fpMeasST:SetClass("active", tbState.measureStickyMode == true) end
					local fpMeasSL = doc:GetElementById("fp-btn-measure-show-length")
					if fpMeasSL then fpMeasSL:SetClass("active", tbState.measureShowLength == true) end
					-- fp-symmetry-radial-count-row visibility driven by data-if="fpSymmetryRadial"
					if widgetState.dmHandle then
						local v = tostring(tbState.symmetryRadialCount or 2)
						if widgetState.dmHandle.tbSymCountStr ~= v then widgetState.dmHandle.tbSymCountStr = v end
					end
					local fpSymRadSlider = doc:GetElementById("fp-slider-symmetry-radial-count")
					if fpSymRadSlider then fpSymRadSlider:SetAttribute("value", tostring(tbState.symmetryRadialCount or 2)) end
					-- fp-symmetry-mirror-angle-row visibility driven by data-if="fpSymmetryMirrorAny"
					if widgetState.dmHandle then
						local v = tostring(math.floor(tbState.symmetryMirrorAngle or 0))
						if widgetState.dmHandle.tbSymAngleStr ~= v then widgetState.dmHandle.tbSymAngleStr = v end
					end
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
