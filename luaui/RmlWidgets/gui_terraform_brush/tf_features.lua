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
	local getCachedEl = ctx.getCachedEl
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
			local dmh = widgetState.dmHandle
			local sm = fpState.mode or "scatter"
			if dmh.fpSubMode ~= sm then dmh.fpSubMode = sm end
			local dist = fpState.distribution or "random"
			if dmh.fpDistMode ~= dist then dmh.fpDistMode = dist end
		end

		-- Feature shape buttons
		if widgetState.dmHandle then
			local shp = fpState.shape or "circle"
			if widgetState.dmHandle.activeShape ~= shp then widgetState.dmHandle.activeShape = shp end
		end

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
			syncAndFlash(getCachedEl(doc, "fp-slider-size"), "fp-size", tostring(fpState.radius))
			syncAndFlash(getCachedEl(doc, "fp-slider-rotation"), "fp-rotation", tostring(fpState.rotation))
			syncAndFlash(getCachedEl(doc, "fp-slider-rot-random"), "fp-rot-random", tostring(fpState.rotRandom))
			syncAndFlash(getCachedEl(doc, "fp-slider-count"), "fp-count", tostring(fpState.featureCount))
			syncAndFlash(getCachedEl(doc, "fp-slider-cadence"), "fp-cadence", tostring(cadenceToSlider(fpState.cadence)))

			-- Smart filter UI sync
			local fpSmartToggle = getCachedEl(doc, "btn-fp-smart-toggle")
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
					local dmh = widgetState.dmHandle
					local function setDm(f, v) if dmh[f] ~= v then dmh[f] = v end end
					setDm("fpAvoidCliffs", sf.avoidCliffs == true)
					setDm("fpPreferSlopes", sf.preferSlopes == true)
					setDm("fpAltMinEnable", sf.altMinEnable == true)
					setDm("fpAltMaxEnable", sf.altMaxEnable == true)
				end

				-- Filter chips: Avoid Water mirrors filter state; slope sub-chips mirror avoidCliffs / preferSlopes
				local avoidWaterChip = getCachedEl(doc, "fp-filter-chip-avoid-water")
				if avoidWaterChip then avoidWaterChip:SetClass("active", sf.avoidWater == true) end
				local slopeAvoidChip = getCachedEl(doc, "fp-slope-mode-avoid")
				if slopeAvoidChip then slopeAvoidChip:SetClass("active", sf.avoidCliffs == true) end
				local slopePreferChip = getCachedEl(doc, "fp-slope-mode-prefer")
				if slopePreferChip then slopePreferChip:SetClass("active", sf.preferSlopes == true) end

				-- Slope-max rows visibility driven by data-if="fpAvoidCliffs"
				-- Label driven by {{fpSlopeMaxStr}} in RML.
				if widgetState.dmHandle then
					local v = tostring(sf.slopeMax)
					if widgetState.dmHandle.fpSlopeMaxStr ~= v then widgetState.dmHandle.fpSlopeMaxStr = v end
				end
				local fpSSlopeMax = getCachedEl(doc, "fp-slider-slope-max")
				if fpSSlopeMax and ds ~= "fp-slope-max" then
					fpSSlopeMax:SetAttribute("value", tostring(sf.slopeMax))
				end

				-- Slope-min rows visibility driven by data-if="fpPreferSlopes"
				-- Label driven by {{fpSlopeMinStr}} in RML.
				if widgetState.dmHandle then
					local v = tostring(sf.slopeMin)
					if widgetState.dmHandle.fpSlopeMinStr ~= v then widgetState.dmHandle.fpSlopeMinStr = v end
				end
				local fpSSlopeMin = getCachedEl(doc, "fp-slider-slope-min")
				if fpSSlopeMin and ds ~= "fp-slope-min" then
					fpSSlopeMin:SetAttribute("value", tostring(sf.slopeMin))
				end

				local altMinEnableBtn = getCachedEl(doc, "btn-fp-alt-min-enable")
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
				local fpSAltMin = getCachedEl(doc, "fp-slider-alt-min")
				if fpSAltMin and ds ~= "fp-alt-min" then
					fpSAltMin:SetAttribute("value", tostring(sf.altMin))
				end

				local altMaxEnableBtn = getCachedEl(doc, "btn-fp-alt-max-enable")
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
				local fpSAltMax = getCachedEl(doc, "fp-slider-alt-max")
				if fpSAltMax and ds ~= "fp-alt-max" then
					fpSAltMax:SetAttribute("value", tostring(sf.altMax))
				end

				-- SAMPLE button active state mirrors TerraformBrush heightSamplingMode
				local hsm = WG.TerraformBrush and (WG.TerraformBrush.getState() or {}).heightSamplingMode
				local sampMin = getCachedEl(doc, "btn-fp-alt-min-sample")
				if sampMin then sampMin:SetClass("active", hsm == "fpAltMin") end
				local sampMax = getCachedEl(doc, "btn-fp-alt-max-sample")
				if sampMax then sampMax:SetClass("active", hsm == "fpAltMax") end
			end

			-- Grid snap chip sync (FP-specific snap state)
			local fpGridSnapBtn = getCachedEl(doc, "btn-fp-grid-snap")
			if fpGridSnapBtn then
				fpGridSnapBtn:SetClass("active", fpState.gridSnap == true)
			end
			if widgetState.dmHandle then
				local v = fpState.gridSnap == true
				if widgetState.dmHandle.fpGridSnap ~= v then widgetState.dmHandle.fpGridSnap = v end
				-- Snap size label + slider
				local ss = tostring(fpState.gridSnapSize or 48)
				if widgetState.dmHandle.fpGridSnapSizeStr ~= ss then widgetState.dmHandle.fpGridSnapSizeStr = ss end
			end
			local fpSnapSizeSlider = getCachedEl(doc, "fp-slider-grid-snap-size")
			if fpSnapSizeSlider and uiState.draggingSlider ~= "fp-grid-snap-size" then
				fpSnapSizeSlider:SetAttribute("value", tostring(fpState.gridSnapSize or 48))
			end
			local fpSnapSizeNb = getCachedEl(doc, "fp-slider-grid-snap-size-numbox")
			if fpSnapSizeNb then fpSnapSizeNb:SetAttribute("value", tostring(fpState.gridSnapSize or 48)) end

			-- Display overlay sync (shared TerraformBrush state)
			if WG.TerraformBrush then
				local tbState = WG.TerraformBrush.getState()
				if tbState then
					local fpHMap = getCachedEl(doc, "btn-fp-height-colormap")
					if fpHMap then fpHMap:SetClass("active", tbState.heightColormap == true) end
					local fpMeas = getCachedEl(doc, "btn-fp-measure")
					if fpMeas then fpMeas:SetClass("active", tbState.measureActive == true) end
					local fpSym = getCachedEl(doc, "btn-fp-symmetry")
					if fpSym then fpSym:SetClass("active", tbState.symmetryActive == true) end
					-- Mirror display + symmetry/measure flags into data-model.
					if widgetState.dmHandle then
						local dmh = widgetState.dmHandle
						local function setDm(f, v) if dmh[f] ~= v then dmh[f] = v end end
						-- fpGridOverlay is FP's own building grid, NOT the terrain grid
						setDm("fpGridOverlay",    fpState.gridOverlay == true)
						setDm("fpHeightColormap", tbState.heightColormap == true)
						setDm("fpSymmetryActive", tbState.symmetryActive == true)
						setDm("fpSymmetryRadial", tbState.symmetryRadial == true)
						setDm("fpSymmetryMirrorAny", (tbState.symmetryMirrorX or tbState.symmetryMirrorY) and true or false)
						setDm("fpSymHasAxis", (tbState.symmetryRadial or tbState.symmetryMirrorX or tbState.symmetryMirrorY) and true or false)
						setDm("fpMeasureActive",    tbState.measureActive == true)
						setDm("fpMeasureRulerMode",  tbState.measureRulerMode == true)
						setDm("fpMeasureStickyMode", tbState.measureStickyMode == true)
						setDm("fpMeasureShowLength", tbState.measureShowLength == true)
						setDm("fpSymMirrorX", tbState.symmetryMirrorX == true)
						setDm("fpSymMirrorY", tbState.symmetryMirrorY == true)
					end
					-- fp-symmetry-toolbar-row visibility driven by data-if="fpSymmetryActive"
					local fpSymRadial = getCachedEl(doc, "fp-btn-symmetry-radial")
					if fpSymRadial then fpSymRadial:SetClass("active", tbState.symmetryRadial == true) end
					local fpSymMX = getCachedEl(doc, "fp-btn-symmetry-mirror-x")
					if fpSymMX then fpSymMX:SetClass("active", tbState.symmetryMirrorX == true) end
					local fpSymMY = getCachedEl(doc, "fp-btn-symmetry-mirror-y")
					if fpSymMY then fpSymMY:SetClass("active", tbState.symmetryMirrorY == true) end
					-- Measure sub-chip active states
					local fpMeasRL = getCachedEl(doc, "fp-btn-measure-ruler")
					if fpMeasRL then fpMeasRL:SetClass("active", tbState.measureRulerMode == true) end
					local fpMeasST = getCachedEl(doc, "fp-btn-measure-sticky")
					if fpMeasST then fpMeasST:SetClass("active", tbState.measureStickyMode == true) end
					local fpMeasSL = getCachedEl(doc, "fp-btn-measure-show-length")
					if fpMeasSL then fpMeasSL:SetClass("active", tbState.measureShowLength == true) end
					-- fp-symmetry-radial-count-row visibility driven by data-if="fpSymmetryRadial"
					if widgetState.dmHandle then
						local v = tostring(tbState.symmetryRadialCount or 2)
						if widgetState.dmHandle.tbSymCountStr ~= v then widgetState.dmHandle.tbSymCountStr = v end
					end
					local fpSymRadSlider = getCachedEl(doc, "fp-slider-symmetry-radial-count")
					if fpSymRadSlider then fpSymRadSlider:SetAttribute("value", tostring(tbState.symmetryRadialCount or 2)) end
					-- fp-symmetry-mirror-angle-row visibility driven by data-if="fpSymmetryMirrorAny"
					if widgetState.dmHandle then
						local v = tostring(math.floor(tbState.symmetryMirrorAngle or 0))
						if widgetState.dmHandle.tbSymAngleStr ~= v then widgetState.dmHandle.tbSymAngleStr = v end
					end
					local fpSymAngSlider = getCachedEl(doc, "fp-slider-symmetry-mirror-angle")
					if fpSymAngSlider then fpSymAngSlider:SetAttribute("value", tostring(tbState.symmetryMirrorAngle or 0)) end
				end
			end

			-- Feature history slider sync
			local sliderFpHist = getCachedEl(doc, "slider-fp-history")
			if sliderFpHist and ds ~= "fp-history" then
				local totalSteps = (fpState.undoCount or 0) + (fpState.redoCount or 0)
				local maxVal = math.min(totalSteps, 400)
				if maxVal < 1 then maxVal = 1 end
				sliderFpHist:SetAttribute("max", tostring(maxVal))
				sliderFpHist:SetAttribute("value", tostring(fpState.undoCount or 0))
			end
			local fpHistNumbox = getCachedEl(doc, "slider-fp-history-numbox")
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
