-- tf_units.lua: the UNITS tool's panel module for gui_terraform_brush. A copy of
-- tf_features.lua driving WG.UnitPlacerTool; units have no scale, and the
-- distribution row also carries the formations (line / grid / box).
local M = {}

function M.attach(doc, ctx)
	local trackSliderDrag = ctx.trackSliderDrag

	-- Change events are wired in the RML (onchange=); only drag tracking is set up here.
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

	-- The onUnXxx event handlers live in initialModel in gui_terraform_brush.lua.
end

function M.sync(doc, ctx, unState, setSummary)
	local widgetState = ctx.widgetState
	local uiState = ctx.uiState
	local WG = ctx.WG
	local syncAndFlash = ctx.syncAndFlash
	local getCachedEl = ctx.getCachedEl
	local cadenceToSlider = ctx.cadenceToSlider
	local shapeNames = ctx.shapeNames

	-- DISPLAY/INSTRUMENTS warn chips (shared TB state mirror)
	if doc and ctx.syncWarnChip then
		local tbs = (WG.TerraformBrush and WG.TerraformBrush.getState()) or {}
		local dispActive = tbs.gridOverlay or tbs.heightColormap
		local instActive = unState.gridSnap or tbs.measureActive or tbs.symmetryActive
		ctx.syncWarnChip(doc, "warn-chip-un-overlays", "section-un-overlays", dispActive)
		ctx.syncWarnChip(doc, "warn-chip-un-instruments", "section-un-instruments", instActive)
	end

	-- Sub-mode and distribution buttons bind these fields via data-class-active.
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

	if widgetState.dmHandle then
		local shp = unState.shape or "circle"
		if widgetState.dmHandle.activeShape ~= shp then
			widgetState.dmHandle.activeShape = shp
		end
	end

	-- The SELECTION section only shows in select mode, the only time a map click selects
	-- rather than places; Reroll is the mirror case, shown while scattering or pointing.
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

		-- Slider labels read these {{un...Str}} fields in the RML.
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

		syncAndFlash(getCachedEl(doc, "un-slider-size"), "un-size", tostring(unState.radius))
		syncAndFlash(getCachedEl(doc, "un-slider-rotation"), "un-rotation", tostring(unState.rotation))
		syncAndFlash(getCachedEl(doc, "un-slider-rot-random"), "un-rot-random", tostring(unState.rotRandom))
		syncAndFlash(getCachedEl(doc, "un-slider-count"), "un-count", tostring(unState.unitCount))
		syncAndFlash(getCachedEl(doc, "un-slider-cadence"), "un-cadence", tostring(cadenceToSlider(unState.cadence)))

		-- Smart filters.
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

			-- These flags drive data-if visibility of the filter rows.
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

			-- Only Avoid Water is set by hand; the slope chips bind unAvoidCliffs / unPreferSlopes.
			local avoidWaterChip = getCachedEl(doc, "un-filter-chip-avoid-water")
			if avoidWaterChip then
				avoidWaterChip:SetClass("active", sf.avoidWater == true)
			end

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

			-- SAMPLE lights while the terraform brush is sampling a height for this filter.
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

		-- Grid snap is the unit placer's own, not the terraform brush's.
		if widgetState.dmHandle then
			local v = unState.gridSnap == true
			if widgetState.dmHandle.unGridSnap ~= v then
				widgetState.dmHandle.unGridSnap = v
			end
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

		-- Display, symmetry and measure state is shared with the terraform brush.
		if WG.TerraformBrush then
			local tbState = WG.TerraformBrush.getState()
			if tbState then
				if widgetState.dmHandle then
					local dmh = widgetState.dmHandle
					local function setDm(f, v)
						if dmh[f] ~= v then
							dmh[f] = v
						end
					end
					-- unGridOverlay is the unit placer's own building grid, not the terrain grid.
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

		-- History slider: max is the total undo + redo steps, capped at 400.
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

	-- Re-enable every shape button but ring and fill, which the unit brush does not support.
	for shape, element in pairs(widgetState.shapeButtons) do
		if element and shape ~= "ring" and shape ~= "fill" then
			element:SetClass("disabled", false)
		end
	end

	-- Gray out controls that do nothing in the current mode.
	if doc and ctx.setDisabledIds then
		local mode = unState.mode or "point"
		local circular = (unState.shape == "circle")
		local remove = (mode == "remove")
		local scatter = (mode == "scatter")

		-- Brush rotation sets the base heading of everything placed (ensureLayout), so it
		-- matters for any shape. Only in remove mode is it purely a shape orientation, and
		-- only then does a circle make it pointless.
		ctx.setDisabledIds(doc, {
			"un-slider-rotation",
			"un-slider-rotation-numbox",
			"btn-un-rot-ccw",
			"btn-un-rot-cw",
		}, remove and circular)

		-- Randomise-alignment perturbs each placed unit, whatever the brush shape; it only
		-- does nothing in remove mode.
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
