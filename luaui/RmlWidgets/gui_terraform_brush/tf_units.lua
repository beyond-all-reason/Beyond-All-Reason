-- tf_units.lua: the UNITS tool's panel module for gui_terraform_brush. A copy of
-- tf_features.lua driving WG.UnitPlacerTool; units have no scale, and the
-- distribution row also carries the formations (line / grid / box).
local M = {}

function M.attach(doc, ctx)
	local trackSliderDrag = ctx.trackSliderDrag

	-- Slider drag tracking (legitimate imperative state).
	-- Slider change events wired declaratively via onchange= in RML.
	for _, sid in ipairs({
		"size",
		"rotation",
		"rot-random",
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
		local sl = doc:GetElementById("un-slider-" .. sid)
		if sl then
			trackSliderDrag(sl, "un-" .. sid)
		end
	end
	local sliderFpHistory = doc:GetElementById("slider-un-history")
	if sliderFpHistory then
		trackSliderDrag(sliderFpHistory, "un-history")
	end

	-- All data-event-click/change handlers (onUnXxx) are defined in initialModel in gui_terraform_brush.lua.
end

function M.sync(doc, ctx, unState, setSummary)
	local widgetState = ctx.widgetState
	local uiState = ctx.uiState
	local WG = ctx.WG
	local syncAndFlash = ctx.syncAndFlash
	local getCachedEl = ctx.getCachedEl
	local cadenceToSlider = ctx.cadenceToSlider
	local shapeNames = ctx.shapeNames
	-- ===== Unit Placer mode: update feature controls =====
	-- btn-features active state driven by data-class-active="activeTool == 'fp'" in RML.
	-- Clear terraform mode highlights

	-- DISPLAY/INSTRUMENTS warn chips (shared TB state mirror)
	if doc and ctx.syncWarnChip then
		local tbs = (WG.TerraformBrush and WG.TerraformBrush.getState()) or {}
		local dispActive = tbs.gridOverlay or tbs.heightColormap
		local instActive = unState.gridSnap or tbs.measureActive or tbs.symmetryActive
		ctx.syncWarnChip(doc, "warn-chip-un-overlays", "section-un-overlays", dispActive)
		ctx.syncWarnChip(doc, "warn-chip-un-instruments", "section-un-instruments", instActive)
	end

	-- Feature sub-mode and distribution (driven by dm fields via data-class-active)
	if widgetState.dmHandle then
		local dmh = widgetState.dmHandle
		local sm = unState.mode or "point"
		if dmh.unSubMode ~= sm then
			dmh.unSubMode = sm
		end
		local dist = unState.distribution or "random"
		if dmh.unDistMode ~= dist then
			dmh.unDistMode = dist
		end
	end

	-- Feature shape buttons
	if widgetState.dmHandle then
		local shp = unState.shape or "circle"
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
		local count = unState.selectionCount or 0
		setDm("unShowSelection", unState.selectMode == true)
		setDm("unShowReroll", unState.selectMode ~= true and (unState.mode == "scatter" or unState.mode == "point"))
		setDm("unHasSelection", count > 0)
		setDm("unSelectionStr", count == 0 and "none" or (count .. " selected"))
		-- FORMATION density: shown while placing or selecting (not while removing). With a
		-- selection on an empty mouse the buttons pack or spread it, else they set the
		-- spacing of the next line / grid / box drag.
		setDm("unShowFormation", unState.mode ~= "remove")
		if unState.selectMode and count >= 2 then
			setDm("unDensityStr", "SELECTION:")
		else
			setDm("unDensityStr", "SPACING: " .. tostring(unState.spacing or 0))
		end
		-- What a click does right now, in one line under the mode buttons.
		local note
		if unState.mode == "remove" then
			note = "Drag over units to remove them. Ctrl+Z / Ctrl+Y undo and redo."
		elseif unState.selectMode then
			note =
				"Nothing picked: click or box-drag to select, drag to move, R turns, Delete removes, Ctrl+C / Ctrl+V copy."
		elseif unState.formation then
			note =
				"Drag to lay out the formation; Shift (line), +Alt (grid), +Alt+Ctrl (box) as in the game. Alt+Z / Alt+X spacing, R turns."
		else
			note =
				"Click to place. Shift-drag a line, Shift+Alt a grid, Shift+Alt+Ctrl a box, as in the game; Alt+Z / Alt+X spacing. R turns, right-click drops the pick."
		end
		setDm("unNoteStr", note)
	end

	if doc then
		uiState.updatingFromCode = true
		local ds = uiState.draggingSlider

		-- Labels driven by {{unRadiusStr}}/{{unRotationStr}}/{{unRotRandomStr}}/{{unCountStr}}/{{unCadenceStr}} in RML.
		-- Phase 2 step 4: mirror to data-model {{Str}} interpolation
		if widgetState.dmHandle then
			local dm = widgetState.dmHandle
			local v = tostring(unState.radius)
			if dm.unRadiusStr ~= v then
				dm.unRadiusStr = v
			end
			v = tostring(unState.rotation)
			if dm.unRotationStr ~= v then
				dm.unRotationStr = v
			end
			v = tostring(unState.rotRandom)
			if dm.unRotRandomStr ~= v then
				dm.unRotRandomStr = v
			end
			v = tostring(unState.unitCount)
			if dm.unCountStr ~= v then
				dm.unCountStr = v
			end
			v = tostring(unState.cadence)
			if dm.unCadenceStr ~= v then
				dm.unCadenceStr = v
			end
		end

		-- Feature sliders
		syncAndFlash(getCachedEl(doc, "un-slider-size"), "un-size", tostring(unState.radius))
		syncAndFlash(getCachedEl(doc, "un-slider-rotation"), "un-rotation", tostring(unState.rotation))
		syncAndFlash(getCachedEl(doc, "un-slider-rot-random"), "un-rot-random", tostring(unState.rotRandom))
		syncAndFlash(getCachedEl(doc, "un-slider-count"), "un-count", tostring(unState.unitCount))
		syncAndFlash(getCachedEl(doc, "un-slider-cadence"), "un-cadence", tostring(cadenceToSlider(unState.cadence)))

		-- Smart filter UI sync
		do
			local sf = unState.smartFilters or {}
			local anyFilterOn = unState.smartEnabled == true
					and (sf.avoidWater or sf.avoidCliffs or sf.preferSlopes or sf.altMinEnable or sf.altMaxEnable)
					and true
				or false
			ctx.syncWarnChip(doc, "warn-chip-un-smart", "section-un-smart", anyFilterOn)
		end
		if unState.smartFilters then
			local sf = unState.smartFilters

			-- Mirror smart-filter flags into data-model for data-if visibility.
			if widgetState.dmHandle then
				local dmh = widgetState.dmHandle
				local function setDm(f, v)
					if dmh[f] ~= v then
						dmh[f] = v
					end
				end
				setDm("unAvoidCliffs", sf.avoidCliffs == true)
				setDm("unPreferSlopes", sf.preferSlopes == true)
				setDm("unAltMinEnable", sf.altMinEnable == true)
				setDm("unAltMaxEnable", sf.altMaxEnable == true)
			end

			-- Filter chips: Avoid Water mirrors filter state (the slope sub-chips bind unAvoidCliffs / unPreferSlopes)
			local avoidWaterChip = getCachedEl(doc, "un-filter-chip-avoid-water")
			if avoidWaterChip then
				avoidWaterChip:SetClass("active", sf.avoidWater == true)
			end

			-- Slope-max rows visibility driven by data-if="unAvoidCliffs"
			-- Label driven by {{unSlopeMaxStr}} in RML.
			if widgetState.dmHandle then
				local v = tostring(sf.slopeMax)
				if widgetState.dmHandle.unSlopeMaxStr ~= v then
					widgetState.dmHandle.unSlopeMaxStr = v
				end
			end
			local unSSlopeMax = getCachedEl(doc, "un-slider-slope-max")
			if unSSlopeMax and ds ~= "un-slope-max" then
				unSSlopeMax:SetAttribute("value", tostring(sf.slopeMax))
			end

			-- Slope-min rows visibility driven by data-if="unPreferSlopes"
			-- Label driven by {{unSlopeMinStr}} in RML.
			if widgetState.dmHandle then
				local v = tostring(sf.slopeMin)
				if widgetState.dmHandle.unSlopeMinStr ~= v then
					widgetState.dmHandle.unSlopeMinStr = v
				end
			end
			local unSSlopeMin = getCachedEl(doc, "un-slider-slope-min")
			if unSSlopeMin and ds ~= "un-slope-min" then
				unSSlopeMin:SetAttribute("value", tostring(sf.slopeMin))
			end

			local altMinEnableBtn = getCachedEl(doc, "btn-un-alt-min-enable")
			if altMinEnableBtn then
				altMinEnableBtn:SetAttribute(
					"src",
					sf.altMinEnable and "/luaui/images/terraform_brush/check_on.png"
						or "/luaui/images/terraform_brush/check_off.png"
				)
			end
			-- Alt-min slider-row visibility driven by data-if="unAltMinEnable"
			-- Label driven by {{unAltMinStr}} in RML.
			if widgetState.dmHandle then
				local v = tostring(sf.altMin)
				if widgetState.dmHandle.unAltMinStr ~= v then
					widgetState.dmHandle.unAltMinStr = v
				end
			end
			local unSAltMin = getCachedEl(doc, "un-slider-alt-min")
			if unSAltMin and ds ~= "un-alt-min" then
				unSAltMin:SetAttribute("value", tostring(sf.altMin))
			end

			local altMaxEnableBtn = getCachedEl(doc, "btn-un-alt-max-enable")
			if altMaxEnableBtn then
				altMaxEnableBtn:SetAttribute(
					"src",
					sf.altMaxEnable and "/luaui/images/terraform_brush/check_on.png"
						or "/luaui/images/terraform_brush/check_off.png"
				)
			end
			-- Alt-max slider-row visibility driven by data-if="unAltMaxEnable"
			-- Label driven by {{unAltMaxStr}} in RML.
			if widgetState.dmHandle then
				local v = tostring(sf.altMax)
				if widgetState.dmHandle.unAltMaxStr ~= v then
					widgetState.dmHandle.unAltMaxStr = v
				end
			end
			local unSAltMax = getCachedEl(doc, "un-slider-alt-max")
			if unSAltMax and ds ~= "un-alt-max" then
				unSAltMax:SetAttribute("value", tostring(sf.altMax))
			end

			-- SAMPLE button active state mirrors TerraformBrush heightSamplingMode
			local hsm = WG.TerraformBrush and (WG.TerraformBrush.getState() or {}).heightSamplingMode
			local sampMin = getCachedEl(doc, "btn-un-alt-min-sample")
			if sampMin then
				sampMin:SetClass("active", hsm == "unAltMin")
			end
			local sampMax = getCachedEl(doc, "btn-un-alt-max-sample")
			if sampMax then
				sampMax:SetClass("active", hsm == "unAltMax")
			end
		end

		-- Grid snap chip sync (FP-specific snap state)
		if widgetState.dmHandle then
			local v = unState.gridSnap == true
			if widgetState.dmHandle.unGridSnap ~= v then
				widgetState.dmHandle.unGridSnap = v
			end
			-- Snap size label + slider
			local ss = tostring(unState.gridSnapSize or 48)
			if widgetState.dmHandle.unGridSnapSizeStr ~= ss then
				widgetState.dmHandle.unGridSnapSizeStr = ss
			end
		end
		local unSnapSizeSlider = getCachedEl(doc, "un-slider-grid-snap-size")
		if unSnapSizeSlider and uiState.draggingSlider ~= "un-grid-snap-size" then
			unSnapSizeSlider:SetAttribute("value", tostring(unState.gridSnapSize or 48))
		end
		local unSnapSizeNb = getCachedEl(doc, "un-slider-grid-snap-size-numbox")
		if unSnapSizeNb then
			unSnapSizeNb:SetAttribute("value", tostring(unState.gridSnapSize or 48))
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
					-- unGridOverlay is FP's own building grid, NOT the terrain grid
					setDm("unGridOverlay", unState.gridOverlay == true)
					setDm("unHeightColormap", tbState.heightColormap == true)
					setDm("unSymmetryActive", tbState.symmetryActive == true)
					setDm("unSymmetryRadial", tbState.symmetryRadial == true)
					setDm(
						"unSymHasAxis",
						(tbState.symmetryRadial or tbState.symmetryMirrorX or tbState.symmetryMirrorY) and true or false
					)
					setDm("unMeasureActive", tbState.measureActive == true)
					setDm("unMeasureRulerMode", tbState.measureRulerMode == true)
					setDm("unMeasureStickyMode", tbState.measureStickyMode == true)
					setDm("unMeasureShowLength", tbState.measureShowLength == true)
					setDm("unSymMirrorX", tbState.symmetryMirrorX == true)
					setDm("unSymMirrorY", tbState.symmetryMirrorY == true)
				end
				-- un-symmetry-radial-count-row visibility driven by data-if="unSymmetryRadial"
				if widgetState.dmHandle then
					local v = tostring(tbState.symmetryRadialCount or 2)
					if widgetState.dmHandle.tbSymCountStr ~= v then
						widgetState.dmHandle.tbSymCountStr = v
					end
				end
				local unSymRadSlider = getCachedEl(doc, "un-slider-symmetry-radial-count")
				if unSymRadSlider then
					unSymRadSlider:SetAttribute("value", tostring(tbState.symmetryRadialCount or 2))
				end
				-- un-symmetry-mirror-angle-row visibility driven by data-if="unSymHasAxis"
				if widgetState.dmHandle then
					local v = tostring(math.floor(tbState.symmetryMirrorAngle or 0))
					if widgetState.dmHandle.tbSymAngleStr ~= v then
						widgetState.dmHandle.tbSymAngleStr = v
					end
				end
				local unSymAngSlider = getCachedEl(doc, "un-slider-symmetry-mirror-angle")
				if unSymAngSlider then
					unSymAngSlider:SetAttribute("value", tostring(tbState.symmetryMirrorAngle or 0))
				end
			end
		end

		-- Feature history slider sync
		local sliderFpHist = getCachedEl(doc, "slider-un-history")
		if sliderFpHist and ds ~= "un-history" then
			local totalSteps = (unState.undoCount or 0) + (unState.redoCount or 0)
			local maxVal = math.min(totalSteps, 400)
			if maxVal < 1 then
				maxVal = 1
			end
			sliderFpHist:SetAttribute("max", tostring(maxVal))
			sliderFpHist:SetAttribute("value", tostring(unState.undoCount or 0))
		end
		local unHistNumbox = getCachedEl(doc, "slider-un-history-numbox")
		if unHistNumbox then
			unHistNumbox:SetAttribute("value", tostring(unState.undoCount or 0))
		end

		uiState.updatingFromCode = false
	end

	-- Gray out unsupported shapes in feature mode (no ring, no fill)
	for shape, element in pairs(widgetState.shapeButtons) do
		if element and shape ~= "ring" and shape ~= "fill" then
			element:SetClass("disabled", false)
		end
	end

	-- P3.2 Unit Placer grayouts (per Phase 3 relevance matrix)
	if doc and ctx.setDisabledIds then
		local mode = unState.mode or "point"
		local circular = (unState.shape == "circle")
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
			"un-slider-rotation",
			"un-slider-rotation-numbox",
			"btn-un-rot-ccw",
			"btn-un-rot-cw",
		}, remove and circular)

		-- Randomise-alignment perturbs each feature's own heading. Nothing to
		-- do with the brush shape; only meaningless when placing nothing.
		ctx.setDisabledIds(doc, {
			"un-slider-rot-random",
			"un-slider-rot-random-numbox",
			"btn-un-rot-random-down",
			"btn-un-rot-random-up",
		}, remove)

		ctx.setDisabledIds(doc, {
			"un-slider-count",
			"un-slider-count-numbox",
			"btn-un-count-down",
			"btn-un-count-up",
			"un-slider-cadence",
			"un-slider-cadence-numbox",
			"btn-un-cadence-down",
			"btn-un-cadence-up",
			"btn-un-dist-random",
			"btn-un-dist-regular",
			"btn-un-dist-clustered",
		}, not scatter)
	end

	setSummary(
		"UNITS",
		"#fdc04c",
		"",
		(unState.mode or "place"):upper(),
		"",
		shapeNames[unState.shape] or "Circle",
		"R ",
		tostring(unState.radius or 0),
		"Count ",
		tostring(unState.unitCount or 1)
	)
end

return M
