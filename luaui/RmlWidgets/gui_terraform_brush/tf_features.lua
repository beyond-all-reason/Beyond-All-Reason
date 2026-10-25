-- tf_features.lua: extracted tool module for gui_terraform_brush
local M = {}

function M.attach(doc, ctx)
	local trackSliderDrag = ctx.trackSliderDrag

	-- Slider drag tracking (legitimate imperative state).
	-- Slider change events wired declaratively via onchange= in RML.
	for _, sid in ipairs({
		"size",
		"rotation",
		"rot-random",
		"scale-min",
		"scale-max",
		"clumps",
		"clump-size",
		"clump-loose",
		"clump-variety",
		"count",
		"cadence",
		"slope-max",
		"slope-min",
		"alt-min",
		"alt-max",
		"symmetry-radial-count",
		"symmetry-mirror-angle",
		"grid-snap-size",
	}) do
		local sl = doc:GetElementById("fp-slider-" .. sid)
		if sl then
			trackSliderDrag(sl, "fp-" .. sid)
		end
	end
	local sliderFpHistory = doc:GetElementById("slider-fp-history")
	if sliderFpHistory then
		trackSliderDrag(sliderFpHistory, "fp-history")
	end

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
		ctx.syncWarnChip(doc, "warn-chip-fp-overlays", "section-fp-overlays", dispActive)
		ctx.syncWarnChip(doc, "warn-chip-fp-instruments", "section-fp-instruments", instActive)
	end

	-- Feature sub-mode and distribution (driven by dm fields via data-class-active)
	if widgetState.dmHandle then
		local dmh = widgetState.dmHandle
		local sm = fpState.mode or "point"
		if dmh.fpSubMode ~= sm then
			dmh.fpSubMode = sm
		end
		local dist = fpState.distribution or "random"
		if dmh.fpDistMode ~= dist then
			dmh.fpDistMode = dist
		end
	end

	-- Feature shape buttons
	if widgetState.dmHandle then
		local shp = fpState.shape or "circle"
		if widgetState.dmHandle.activeShape ~= shp then
			widgetState.dmHandle.activeShape = shp
		end
	end

	-- Gizmo selection. The SELECTION section only appears on an empty mouse,
	-- because that is the only time clicking the map selects rather than
	-- places; Reroll is the mirror case, only useful while scattering.
	if widgetState.dmHandle then
		local dmh = widgetState.dmHandle
		local function setDm(f, v)
			if dmh[f] ~= v then
				dmh[f] = v
			end
		end
		local count = fpState.selectionCount or 0
		setDm("fpShowSelection", fpState.selectMode == true)
		setDm("fpShowReroll", fpState.selectMode ~= true and (fpState.mode == "scatter" or fpState.mode == "point"))
		setDm("fpHasSelection", count > 0)
		setDm("fpSelectionStr", count == 0 and "none" or (count .. " selected"))
	end

	if doc then
		uiState.updatingFromCode = true
		local ds = uiState.draggingSlider

		-- Labels driven by {{fpRadiusStr}}/{{fpRotationStr}}/{{fpRotRandomStr}}/{{fpCountStr}}/{{fpCadenceStr}} in RML.
		-- Phase 2 step 4: mirror to data-model {{Str}} interpolation
		if widgetState.dmHandle then
			local dm = widgetState.dmHandle
			local v = tostring(fpState.radius)
			if dm.fpRadiusStr ~= v then
				dm.fpRadiusStr = v
			end
			v = tostring(fpState.rotation)
			if dm.fpRotationStr ~= v then
				dm.fpRotationStr = v
			end
			v = tostring(fpState.rotRandom)
			if dm.fpRotRandomStr ~= v then
				dm.fpRotRandomStr = v
			end
			v = tostring(fpState.tiltRandom or 0)
			if dm.fpTiltRandomStr ~= v then
				dm.fpTiltRandomStr = v
			end
			v = tostring(fpState.heightOffset or 0)
			if dm.fpHeightOffsetStr ~= v then
				dm.fpHeightOffsetStr = v
			end
			v = string.format("%.2f", fpState.scaleMin or 1)
			if dm.fpScaleMinStr ~= v then
				dm.fpScaleMinStr = v
			end
			v = string.format("%.2f", fpState.scaleMax or 1)
			if dm.fpScaleMaxStr ~= v then
				dm.fpScaleMaxStr = v
			end
			v = (fpState.clumps or 0) == 0 and "AUTO" or tostring(fpState.clumps)
			if dm.fpClumpsStr ~= v then
				dm.fpClumpsStr = v
			end
			v = string.format("%.2f", fpState.clumpSize or 1)
			if dm.fpClumpSizeStr ~= v then
				dm.fpClumpSizeStr = v
			end
			v = tostring(fpState.clumpLoose or 25)
			if dm.fpClumpLooseStr ~= v then
				dm.fpClumpLooseStr = v
			end
			v = tostring(fpState.clumpVariety or 0)
			if dm.fpClumpVarietyStr ~= v then
				dm.fpClumpVarietyStr = v
			end
			v = tostring(fpState.featureCount)
			if dm.fpCountStr ~= v then
				dm.fpCountStr = v
			end
			v = tostring(fpState.cadence)
			if dm.fpCadenceStr ~= v then
				dm.fpCadenceStr = v
			end
		end

		-- Feature sliders
		syncAndFlash(getCachedEl(doc, "fp-slider-size"), "fp-size", tostring(fpState.radius))
		syncAndFlash(getCachedEl(doc, "fp-slider-rotation"), "fp-rotation", tostring(fpState.rotation))
		syncAndFlash(getCachedEl(doc, "fp-slider-rot-random"), "fp-rot-random", tostring(fpState.rotRandom))
		syncAndFlash(getCachedEl(doc, "fp-slider-tilt-random"), "fp-tilt-random", tostring(fpState.tiltRandom or 0))
		syncAndFlash(
			getCachedEl(doc, "fp-slider-height-offset"),
			"fp-height-offset",
			tostring(fpState.heightOffset or 0)
		)
		syncAndFlash(getCachedEl(doc, "fp-slider-scale-min"), "fp-scale-min", tostring(fpState.scaleMin or 1))
		syncAndFlash(getCachedEl(doc, "fp-slider-scale-max"), "fp-scale-max", tostring(fpState.scaleMax or 1))
		syncAndFlash(getCachedEl(doc, "fp-slider-clumps"), "fp-clumps", tostring(fpState.clumps or 0))
		syncAndFlash(getCachedEl(doc, "fp-slider-clump-size"), "fp-clump-size", tostring(fpState.clumpSize or 1))
		syncAndFlash(getCachedEl(doc, "fp-slider-clump-loose"), "fp-clump-loose", tostring(fpState.clumpLoose or 25))
		syncAndFlash(
			getCachedEl(doc, "fp-slider-clump-variety"),
			"fp-clump-variety",
			tostring(fpState.clumpVariety or 0)
		)
		syncAndFlash(getCachedEl(doc, "fp-slider-count"), "fp-count", tostring(fpState.featureCount))
		syncAndFlash(getCachedEl(doc, "fp-slider-cadence"), "fp-cadence", tostring(cadenceToSlider(fpState.cadence)))

		-- Smart filter UI sync
		do
			local sf = fpState.smartFilters or {}
			local anyFilterOn = fpState.smartEnabled == true
					and (sf.avoidWater or sf.avoidCliffs or sf.preferSlopes or sf.altMinEnable or sf.altMaxEnable)
					and true
				or false
			ctx.syncWarnChip(doc, "warn-chip-fp-smart", "section-fp-smart", anyFilterOn)
		end
		if fpState.smartFilters then
			local sf = fpState.smartFilters

			-- Mirror smart-filter flags into data-model for data-if visibility.
			if widgetState.dmHandle then
				local dmh = widgetState.dmHandle
				local function setDm(f, v)
					if dmh[f] ~= v then
						dmh[f] = v
					end
				end
				setDm("fpAvoidCliffs", sf.avoidCliffs == true)
				setDm("fpPreferSlopes", sf.preferSlopes == true)
				setDm("fpAltMinEnable", sf.altMinEnable == true)
				setDm("fpAltMaxEnable", sf.altMaxEnable == true)
			end

			-- Filter chips: Avoid Water mirrors filter state (the slope sub-chips bind fpAvoidCliffs / fpPreferSlopes)
			local avoidWaterChip = getCachedEl(doc, "fp-filter-chip-avoid-water")
			if avoidWaterChip then
				avoidWaterChip:SetClass("active", sf.avoidWater == true)
			end

			-- Slope-max rows visibility driven by data-if="fpAvoidCliffs"
			-- Label driven by {{fpSlopeMaxStr}} in RML.
			if widgetState.dmHandle then
				local v = tostring(sf.slopeMax)
				if widgetState.dmHandle.fpSlopeMaxStr ~= v then
					widgetState.dmHandle.fpSlopeMaxStr = v
				end
			end
			local fpSSlopeMax = getCachedEl(doc, "fp-slider-slope-max")
			if fpSSlopeMax and ds ~= "fp-slope-max" then
				fpSSlopeMax:SetAttribute("value", tostring(sf.slopeMax))
			end

			-- Slope-min rows visibility driven by data-if="fpPreferSlopes"
			-- Label driven by {{fpSlopeMinStr}} in RML.
			if widgetState.dmHandle then
				local v = tostring(sf.slopeMin)
				if widgetState.dmHandle.fpSlopeMinStr ~= v then
					widgetState.dmHandle.fpSlopeMinStr = v
				end
			end
			local fpSSlopeMin = getCachedEl(doc, "fp-slider-slope-min")
			if fpSSlopeMin and ds ~= "fp-slope-min" then
				fpSSlopeMin:SetAttribute("value", tostring(sf.slopeMin))
			end

			local altMinEnableBtn = getCachedEl(doc, "btn-fp-alt-min-enable")
			if altMinEnableBtn then
				altMinEnableBtn:SetAttribute(
					"src",
					sf.altMinEnable and "/luaui/images/terraform_brush/check_on.png"
						or "/luaui/images/terraform_brush/check_off.png"
				)
			end
			-- Alt-min slider-row visibility driven by data-if="fpAltMinEnable"
			-- Label driven by {{fpAltMinStr}} in RML.
			if widgetState.dmHandle then
				local v = tostring(sf.altMin)
				if widgetState.dmHandle.fpAltMinStr ~= v then
					widgetState.dmHandle.fpAltMinStr = v
				end
			end
			local fpSAltMin = getCachedEl(doc, "fp-slider-alt-min")
			if fpSAltMin and ds ~= "fp-alt-min" then
				fpSAltMin:SetAttribute("value", tostring(sf.altMin))
			end

			local altMaxEnableBtn = getCachedEl(doc, "btn-fp-alt-max-enable")
			if altMaxEnableBtn then
				altMaxEnableBtn:SetAttribute(
					"src",
					sf.altMaxEnable and "/luaui/images/terraform_brush/check_on.png"
						or "/luaui/images/terraform_brush/check_off.png"
				)
			end
			-- Alt-max slider-row visibility driven by data-if="fpAltMaxEnable"
			-- Label driven by {{fpAltMaxStr}} in RML.
			if widgetState.dmHandle then
				local v = tostring(sf.altMax)
				if widgetState.dmHandle.fpAltMaxStr ~= v then
					widgetState.dmHandle.fpAltMaxStr = v
				end
			end
			local fpSAltMax = getCachedEl(doc, "fp-slider-alt-max")
			if fpSAltMax and ds ~= "fp-alt-max" then
				fpSAltMax:SetAttribute("value", tostring(sf.altMax))
			end

			-- SAMPLE button active state mirrors TerraformBrush heightSamplingMode
			local hsm = WG.TerraformBrush and (WG.TerraformBrush.getState() or {}).heightSamplingMode
			local sampMin = getCachedEl(doc, "btn-fp-alt-min-sample")
			if sampMin then
				sampMin:SetClass("active", hsm == "fpAltMin")
			end
			local sampMax = getCachedEl(doc, "btn-fp-alt-max-sample")
			if sampMax then
				sampMax:SetClass("active", hsm == "fpAltMax")
			end
		end

		-- Grid snap chip sync (FP-specific snap state)
		if widgetState.dmHandle then
			local v = fpState.gridSnap == true
			if widgetState.dmHandle.fpGridSnap ~= v then
				widgetState.dmHandle.fpGridSnap = v
			end
			-- Snap size label + slider
			local ss = tostring(fpState.gridSnapSize or 48)
			if widgetState.dmHandle.fpGridSnapSizeStr ~= ss then
				widgetState.dmHandle.fpGridSnapSizeStr = ss
			end
		end
		local fpSnapSizeSlider = getCachedEl(doc, "fp-slider-grid-snap-size")
		if fpSnapSizeSlider and uiState.draggingSlider ~= "fp-grid-snap-size" then
			fpSnapSizeSlider:SetAttribute("value", tostring(fpState.gridSnapSize or 48))
		end
		local fpSnapSizeNb = getCachedEl(doc, "fp-slider-grid-snap-size-numbox")
		if fpSnapSizeNb then
			fpSnapSizeNb:SetAttribute("value", tostring(fpState.gridSnapSize or 48))
		end

		-- Display overlay sync (shared TerraformBrush state)
		if WG.TerraformBrush then
			local tbState = WG.TerraformBrush.getState()
			if tbState then
				-- Mirror display + symmetry/measure flags into data-model.
				if widgetState.dmHandle then
					local dmh = widgetState.dmHandle
					local function setDm(f, v)
						if dmh[f] ~= v then
							dmh[f] = v
						end
					end
					-- fpGridOverlay is FP's own building grid, NOT the terrain grid
					setDm("fpGridOverlay", fpState.gridOverlay == true)
					setDm("fpHeightColormap", tbState.heightColormap == true)
					setDm("fpSymmetryActive", tbState.symmetryActive == true)
					setDm("fpSymmetryRadial", tbState.symmetryRadial == true)
					setDm(
						"fpSymHasAxis",
						(tbState.symmetryRadial or tbState.symmetryMirrorX or tbState.symmetryMirrorY) and true or false
					)
					setDm("fpMeasureActive", tbState.measureActive == true)
					setDm("fpMeasureRulerMode", tbState.measureRulerMode == true)
					setDm("fpMeasureStickyMode", tbState.measureStickyMode == true)
					setDm("fpMeasureShowLength", tbState.measureShowLength == true)
					setDm("fpSymMirrorX", tbState.symmetryMirrorX == true)
					setDm("fpSymMirrorY", tbState.symmetryMirrorY == true)
				end
				-- fp-symmetry-radial-count-row visibility driven by data-if="fpSymmetryRadial"
				if widgetState.dmHandle then
					local v = tostring(tbState.symmetryRadialCount or 2)
					if widgetState.dmHandle.tbSymCountStr ~= v then
						widgetState.dmHandle.tbSymCountStr = v
					end
				end
				local fpSymRadSlider = getCachedEl(doc, "fp-slider-symmetry-radial-count")
				if fpSymRadSlider then
					fpSymRadSlider:SetAttribute("value", tostring(tbState.symmetryRadialCount or 2))
				end
				-- fp-symmetry-mirror-angle-row visibility driven by data-if="fpSymHasAxis"
				if widgetState.dmHandle then
					local v = tostring(math.floor(tbState.symmetryMirrorAngle or 0))
					if widgetState.dmHandle.tbSymAngleStr ~= v then
						widgetState.dmHandle.tbSymAngleStr = v
					end
				end
				local fpSymAngSlider = getCachedEl(doc, "fp-slider-symmetry-mirror-angle")
				if fpSymAngSlider then
					fpSymAngSlider:SetAttribute("value", tostring(tbState.symmetryMirrorAngle or 0))
				end
			end
		end

		-- Feature history slider sync
		local sliderFpHist = getCachedEl(doc, "slider-fp-history")
		if sliderFpHist and ds ~= "fp-history" then
			local totalSteps = (fpState.undoCount or 0) + (fpState.redoCount or 0)
			local maxVal = math.min(totalSteps, 400)
			if maxVal < 1 then
				maxVal = 1
			end
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
		local mode = fpState.mode or "point"
		local circular = (fpState.shape == "circle")
		local remove = (mode == "remove")
		local scatter = (mode == "scatter")

		-- Rotation and randomise-alignment are separate concerns and used to
		-- share one "circular or remove" condition, which greyed out
		-- randomise-alignment for every circular brush -- the default shape,
		-- and the only shape point mode has. It defaults to 100 (fully
		-- random), so features came out randomly turned with no way to stop
		-- it.
		--
		-- Brush rotation sets the base heading of everything placed (see
		-- generateLocal / the point-mode branch of ensureLayout), so it is
		-- meaningful whatever the shape. Only in remove mode is it purely a
		-- shape orientation, and only then does a circle make it pointless.
		ctx.setDisabledIds(doc, {
			"fp-slider-rotation",
			"fp-slider-rotation-numbox",
			"btn-fp-rot-ccw",
			"btn-fp-rot-cw",
		}, remove and circular)

		-- Randomise-alignment and randomise-tilt perturb each feature's own
		-- heading and lean. Nothing to do with the brush shape; only
		-- meaningless when placing nothing.
		ctx.setDisabledIds(doc, {
			"fp-slider-rot-random",
			"fp-slider-rot-random-numbox",
			"btn-fp-rot-random-down",
			"btn-fp-rot-random-up",
			"fp-slider-tilt-random",
			"fp-slider-tilt-random-numbox",
			"btn-fp-tilt-random-down",
			"btn-fp-tilt-random-up",
		}, remove)

		-- Scale variation applies to whatever gets placed -- scatter and point
		-- alike -- so like randomise-alignment it only greys out in remove mode.
		ctx.setDisabledIds(doc, {
			"fp-slider-height-offset",
			"fp-slider-height-offset-numbox",
			"btn-fp-height-down",
			"btn-fp-height-up",
			"fp-slider-scale-min",
			"fp-slider-scale-min-numbox",
			"btn-fp-scale-min-down",
			"btn-fp-scale-min-up",
			"fp-slider-scale-max",
			"fp-slider-scale-max-numbox",
			"btn-fp-scale-max-down",
			"btn-fp-scale-max-up",
		}, remove)
		ctx.setDisabledIds(doc, {
			"fp-slider-count",
			"fp-slider-count-numbox",
			"btn-fp-count-down",
			"btn-fp-count-up",
			"fp-slider-cadence",
			"fp-slider-cadence-numbox",
			"btn-fp-cadence-down",
			"btn-fp-cadence-up",
			"btn-fp-dist-random",
			"btn-fp-dist-regular",
			"btn-fp-dist-clustered",
			"fp-slider-clumps",
			"fp-slider-clumps-numbox",
			"btn-fp-clumps-down",
			"btn-fp-clumps-up",
			"fp-slider-clump-size",
			"fp-slider-clump-size-numbox",
			"btn-fp-clump-size-down",
			"btn-fp-clump-size-up",
			"fp-slider-clump-loose",
			"fp-slider-clump-loose-numbox",
			"btn-fp-clump-loose-down",
			"btn-fp-clump-loose-up",
			"fp-slider-clump-variety",
			"fp-slider-clump-variety-numbox",
			"btn-fp-clump-variety-down",
			"btn-fp-clump-variety-up",
		}, not scatter)
	end

	setSummary(
		"FEATURES",
		"#fdc04c",
		"",
		(fpState.mode or "place"):upper(),
		"",
		shapeNames[fpState.shape] or "Circle",
		"R ",
		tostring(fpState.radius or 0),
		"Count ",
		tostring(fpState.featureCount or 1)
	)
end

return M
