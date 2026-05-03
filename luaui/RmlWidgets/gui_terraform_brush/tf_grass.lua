-- tf_grass.lua â€” Grass Brush attach + sync (extracted from gui_terraform_brush.lua)
local M = {}

function M.attach(doc, ctx)
	local widgetState = ctx.widgetState
	local uiState = ctx.uiState
	local playSound = ctx.playSound
	local trackSliderDrag = ctx.trackSliderDrag
	local WG = ctx.WG
	local RADIUS_STEP = ctx.RADIUS_STEP
	local ROTATION_STEP = ctx.ROTATION_STEP
	local CURVE_STEP = ctx.CURVE_STEP

	widgetState.gbSubmodesEl = doc:GetElementById("tf-grass-submodes")
	widgetState.gbControlsEl = doc:GetElementById("tf-grass-controls")

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

	-- All data-event-click/change handlers (onGbXxx) are defined in initialModel in gui_terraform_brush.lua.
end


function M.sync(doc, ctx, gbState, setSummary, sumEl)
	local widgetState = ctx.widgetState
	local uiState = ctx.uiState
	local syncAndFlash = ctx.syncAndFlash
	local shapeNames = ctx.shapeNames
	local WG = ctx.WG
	local dm = widgetState.dmHandle

	-- btn-grass active state driven by data-class-active="activeTool == 'gb'" in RML.

	-- Grass sub-mode buttons (driven by dm.gbSubMode via data-class-active)
	if widgetState.dmHandle then widgetState.dmHandle.gbSubMode = gbState.subMode or "paint" end

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
			-- (driven by dm flags via data-class-active in RML)
			if dm then
				dm.gbGridOverlay     = s.gridOverlay and true or false
				dm.gbHeightColormap  = s.heightColormap and true or false
				dm.gbGridSnap        = s.gridSnap and true or false
				dm.gbAngleSnap       = s.angleSnap and true or false
				dm.gbMeasureActive   = s.measureActive and true or false
				dm.gbSymmetryActive  = s.symmetryActive and true or false
				dm.gbSymmetryRadial  = s.symmetryRadial and true or false
				dm.gbSymMirrorX      = s.symmetryMirrorX and true or false
				dm.gbSymMirrorY      = s.symmetryMirrorY and true or false
				dm.gbSymmetryMirrorAny = (s.symmetryMirrorX or s.symmetryMirrorY) and true or false
				dm.gbSymHasAxis = (s.symmetryRadial or s.symmetryMirrorX or s.symmetryMirrorY) and true or false
				dm.gbAngleSnapAuto   = s.angleSnapAuto and true or false
				dm.gbMeasureRulerMode  = s.measureRulerMode and true or false
				dm.gbMeasureStickyMode = s.measureStickyMode and true or false
				dm.gbMeasureShowLength = s.measureShowLength and true or false
			end
		end
	end

	-- Grass density slider & label sync
	if doc then
		uiState.updatingFromCode = true

		if widgetState.dmHandle then
			local s = tostring(math.floor(gbState.density * 100 + 0.5)) .. "%"
			if widgetState.dmHandle.gbDensityStr ~= s then widgetState.dmHandle.gbDensityStr = s end
		end

		do
			local sv = math.floor(gbState.density * 100 + 0.5)
			syncAndFlash(doc:GetElementById("slider-grass-density"), "gb-density", tostring(sv))
		end

		-- Sync size, rotation, curve, length from grass brush own state
		do
			if widgetState.dmHandle then
				local s = tostring(gbState.radius or 100)
				if widgetState.dmHandle.gbSizeStr ~= s then widgetState.dmHandle.gbSizeStr = s end
			end
			syncAndFlash(doc:GetElementById("slider-gb-size"), "gb-size", tostring(gbState.radius or 100))

			do
				-- Rotation is shared with TerraformBrush (applyBrush always reads TB rotation)
				local tfSt = WG.TerraformBrush and WG.TerraformBrush.getState()
				local rotDeg = tfSt and tfSt.rotationDeg or (gbState.rotationDeg or 0)
				if widgetState.dmHandle then
					local s = tostring(rotDeg) .. "\194\176"
					if widgetState.dmHandle.gbRotStr ~= s then widgetState.dmHandle.gbRotStr = s end
				end
				syncAndFlash(doc:GetElementById("slider-gb-rotation"), "gb-rotation", tostring(rotDeg))
			end

			if widgetState.dmHandle then
				local s = string.format("%.1f", gbState.curve or 1.0)
				if widgetState.dmHandle.gbCurveStr ~= s then widgetState.dmHandle.gbCurveStr = s end
			end
			syncAndFlash(doc:GetElementById("slider-gb-curve"), "gb-curve", tostring(math.floor((gbState.curve or 1.0) * 10 + 0.5)))

			if widgetState.dmHandle then
				local s = string.format("%.1f", gbState.lengthScale or 1.0)
				if widgetState.dmHandle.gbLengthStr ~= s then widgetState.dmHandle.gbLengthStr = s end
			end
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
			if widgetState.dmHandle then
				local s = tostring(sf.slopeMax or 45)
				if widgetState.dmHandle.gbSlopeMaxStr ~= s then widgetState.dmHandle.gbSlopeMaxStr = s end
			end
			syncAndFlash(doc:GetElementById("slider-gb-slope-max"), "gb-slope-max", tostring(sf.slopeMax or 45))

			-- gb-smart-slope-min-row/slider-row visibility driven by data-if="gbPreferSlopes"
			if widgetState.dmHandle then
				local s = tostring(sf.slopeMin or 10)
				if widgetState.dmHandle.gbSlopeMinStr ~= s then widgetState.dmHandle.gbSlopeMinStr = s end
			end
			syncAndFlash(doc:GetElementById("slider-gb-slope-min"), "gb-slope-min", tostring(sf.slopeMin or 10))

			-- gb-smart-alt-min-slider-row visibility driven by data-if="gbAltMinEnable"
			if widgetState.dmHandle then
				local s = tostring(sf.altMin or 0)
				if widgetState.dmHandle.gbAltMinStr ~= s then widgetState.dmHandle.gbAltMinStr = s end
			end
			syncAndFlash(doc:GetElementById("slider-gb-alt-min"), "gb-alt-min", tostring(sf.altMin or 0))

			-- gb-smart-alt-max-slider-row visibility driven by data-if="gbAltMaxEnable"
			if widgetState.dmHandle then
				local s = tostring(sf.altMax or 200)
				if widgetState.dmHandle.gbAltMaxStr ~= s then widgetState.dmHandle.gbAltMaxStr = s end
			end
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
			if widgetState.dmHandle then
				local s = tostring(threshVal)
				if widgetState.dmHandle.gbColorThreshStr ~= s then widgetState.dmHandle.gbColorThreshStr = s end
			end

			local padVal = gbState.texFilterPadding or 0
			syncAndFlash(doc:GetElementById("slider-gb-color-pad"), "gb-color-pad", tostring(math.floor(padVal + 0.5)))
			if widgetState.dmHandle then
				local s = tostring(math.floor(padVal + 0.5))
				if widgetState.dmHandle.gbColorPadStr ~= s then widgetState.dmHandle.gbColorPadStr = s end
			end

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

		-- Symmetry count + angle slider sync (labels driven by dm.tbSymCountStr/tbSymAngleStr via syncTBMirrorControls)
		local symStGb = WG.TerraformBrush and WG.TerraformBrush.getState()
		if symStGb then
			syncAndFlash(doc:GetElementById("gb-slider-symmetry-radial-count"), "gb-symmetry-radial-count", tostring(symStGb.symmetryRadialCount or 2))
			syncAndFlash(doc:GetElementById("gb-slider-symmetry-mirror-angle"), "gb-symmetry-mirror-angle", tostring(symStGb.symmetryMirrorAngle or 0))
		end
		uiState.updatingFromCode = false
	end

	-- Shape: grass brush uses shared activeShape dm field
	if gbState.shape and widgetState.dmHandle then
		widgetState.dmHandle.activeShape = gbState.shape
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

	if ctx.syncTBMirrorControls then ctx.syncTBMirrorControls(doc, "gb") end
end

return M
