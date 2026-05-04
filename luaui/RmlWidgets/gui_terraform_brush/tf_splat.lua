-- tf_splat.lua: extracted tool module for gui_terraform_brush
local M = {}

function M.attach(doc, ctx)
	if ctx.attachTBMirrorControls then ctx.attachTBMirrorControls(doc, "sp") end
	local widgetState = ctx.widgetState
	local trackSliderDrag = ctx.trackSliderDrag

	widgetState.spControlsEl = doc:GetElementById("tf-splat-controls")

	-- Cache channel button elements (active class driven by sync).
	widgetState.spChannelButtons = {
		doc:GetElementById("btn-sp-ch1"),
		doc:GetElementById("btn-sp-ch2"),
		doc:GetElementById("btn-sp-ch3"),
		doc:GetElementById("btn-sp-ch4"),
	}

	widgetState.spPreviewEls = {
		doc:GetElementById("sp-ch1-preview"),
		doc:GetElementById("sp-ch2-preview"),
		doc:GetElementById("sp-ch3-preview"),
		doc:GetElementById("sp-ch4-preview"),
	}
	widgetState.spChannelSectionEl = doc:GetElementById("section-spl-channel")
	widgetState.spPreviewTextures = {}
	widgetState.spPreviewVerified = false

	-- Slider drag tracking (legitimate imperative: slider-specific drag state).
	-- Slider change events are wired declaratively via data-event-change= in RML.
	for _, entry in ipairs({
		{ "sp-slider-strength",             "sp-strength" },
		{ "sp-slider-intensity",            "sp-intensity" },
		{ "sp-slider-size",                 "sp-size" },
		{ "sp-slider-rotation",             "sp-rotation" },
		{ "sp-slider-curve",                "sp-curve" },
		{ "sp-slider-slope-max",            "sp-slope-max" },
		{ "sp-slider-slope-min",            "sp-slope-min" },
		{ "sp-slider-alt-min",              "sp-alt-min" },
		{ "sp-slider-alt-max",              "sp-alt-max" },
		{ "slider-sp-history",              "sp-history" },
		{ "sp-slider-symmetry-radial-count",  "sp-symmetry-radial-count" },
		{ "sp-slider-symmetry-mirror-angle",  "sp-symmetry-mirror-angle" },
	}) do
		local sl = doc:GetElementById(entry[1])
		if sl then trackSliderDrag(sl, entry[2]) end
	end
	-- All data-event-click/change handlers (onSplXxx) are defined in initialModel
	-- in gui_terraform_brush.lua — Recoil forbids adding or replacing function
	-- keys in a DataModel after OpenDataModel.
end

function M.sync(doc, ctx, spState, setSummary)
	if ctx.syncTBMirrorControls then ctx.syncTBMirrorControls(doc, "sp") end
	local widgetState = ctx.widgetState
	local uiState = ctx.uiState
	local WG = ctx.WG
	local syncAndFlash = ctx.syncAndFlash
	local cadenceToSlider = ctx.cadenceToSlider
	local shapeNames = ctx.shapeNames
		-- ===== Splat Painter mode: update splat controls =====
		-- btn-splat active state driven by data-class-active="activeTool == 'sp'" in RML.

		if widgetState.dmHandle then widgetState.dmHandle.activeShape = spState.shape or "circle" end

		if doc then
			uiState.updatingFromCode = true
			local ds = uiState.draggingSlider

			-- Splat labels (Phase 2 step 4: dm-driven {{interpolation}})
			local dm = widgetState.dmHandle
			if dm then
				local s1 = string.format("%.2f", spState.strength)
				if dm.splatStrengthStr ~= s1 then dm.splatStrengthStr = s1 end
				local s2 = string.format("%.1f", spState.intensity)
				if dm.splatIntensityStr ~= s2 then dm.splatIntensityStr = s2 end
				local s3 = tostring(spState.radius)
				if dm.splatRadiusStr ~= s3 then dm.splatRadiusStr = s3 end
				local s4 = tostring(spState.rotationDeg)
				if dm.splatRotationStr ~= s4 then dm.splatRotationStr = s4 end
				local s5 = string.format("%.1f", spState.curve)
				if dm.splatCurveStr ~= s5 then dm.splatCurveStr = s5 end
			end

			-- Splat channel button highlights (data-class-active="spChannel == N")
			if dm then
				local ch = spState.channel or 1
				if dm.spChannel ~= ch then dm.spChannel = ch end
			end

			-- Splat sliders
			syncAndFlash(doc:GetElementById("sp-slider-strength"), "sp-strength", tostring(math.floor(spState.strength * 100 + 0.5)))
			syncAndFlash(doc:GetElementById("sp-slider-intensity"), "sp-intensity", tostring(math.floor(spState.intensity * 10 + 0.5)))
			syncAndFlash(doc:GetElementById("sp-slider-size"), "sp-size", tostring(spState.radius))
			syncAndFlash(doc:GetElementById("sp-slider-rotation"), "sp-rotation", tostring(spState.rotationDeg))
			syncAndFlash(doc:GetElementById("sp-slider-curve"), "sp-curve", tostring(math.floor(spState.curve * 10 + 0.5)))

			-- Smart filter UI sync
			do
				local sf = spState.smartFilters or {}
				local anyFilterOn = spState.smartEnabled == true and (
					sf.avoidWater or sf.avoidCliffs or sf.preferSlopes or
					sf.altMinEnable or sf.altMaxEnable
				) and true or false
				ctx.syncWarnChip(doc, "warn-chip-sp-smart", "section-sp-smart", anyFilterOn)
				if spState.smartFilters then
					local sf = spState.smartFilters
					-- Mirror smart-filter flags into data-model for data-if visibility.
					if widgetState.dmHandle then
						widgetState.dmHandle.spAvoidCliffs = sf.avoidCliffs == true
						widgetState.dmHandle.spPreferSlopes = sf.preferSlopes == true
						widgetState.dmHandle.spAltMinEnable = sf.altMinEnable == true
						widgetState.dmHandle.spAltMaxEnable = sf.altMaxEnable == true
					end
					-- NB: slope/altitude chip active class is owned by wireVisibilityChip
					-- (tf_environment.lua) which treats active==section-expanded. Do NOT
					-- overwrite it here based on filter flags or the click toggle fights
					-- this per-frame write and the chip becomes unresponsive.

					-- Filter chips: avoid-water driven by data-class-active="spAvoidWater".
					-- Slope-mode mutex sub-chips owned by wireMutexChipPair — do not set active here.
					if dm then
						local v = sf.avoidWater == true
						if dm.spAvoidWater ~= v then dm.spAvoidWater = v end
					end

					-- Slope-max row visibility driven by data-if="spAvoidCliffs"
					if widgetState.dmHandle then
						local v = tostring(sf.slopeMax)
						if widgetState.dmHandle.splatSlopeMaxStr ~= v then widgetState.dmHandle.splatSlopeMaxStr = v end
					end
					local spSSlopeMax = doc:GetElementById("sp-slider-slope-max")
					if spSSlopeMax and ds ~= "sp-slope-max" then
						spSSlopeMax:SetAttribute("value", tostring(sf.slopeMax))
					end

					-- Slope-min row visibility driven by data-if="spPreferSlopes"
					if widgetState.dmHandle then
						local v = tostring(sf.slopeMin)
						if widgetState.dmHandle.splatSlopeMinStr ~= v then widgetState.dmHandle.splatSlopeMinStr = v end
					end
					local spSSlopeMin = doc:GetElementById("sp-slider-slope-min")
					if spSSlopeMin and ds ~= "sp-slope-min" then
						spSSlopeMin:SetAttribute("value", tostring(sf.slopeMin))
					end

					local altMinEnableBtn = doc:GetElementById("btn-sp-alt-min-enable")
					if altMinEnableBtn then
						altMinEnableBtn:SetAttribute("src", sf.altMinEnable
							and "/luaui/images/terraform_brush/check_on.png"
							or "/luaui/images/terraform_brush/check_off.png")
					end
					-- Alt-min slider-row visibility driven by data-if="spAltMinEnable"
					if widgetState.dmHandle then
						local v = tostring(sf.altMin)
						if widgetState.dmHandle.splatAltMinStr ~= v then widgetState.dmHandle.splatAltMinStr = v end
					end
					local spSAltMin = doc:GetElementById("sp-slider-alt-min")
					if spSAltMin and ds ~= "sp-alt-min" then
						spSAltMin:SetAttribute("value", tostring(sf.altMin))
					end

					local altMaxEnableBtn = doc:GetElementById("btn-sp-alt-max-enable")
					if altMaxEnableBtn then
						altMaxEnableBtn:SetAttribute("src", sf.altMaxEnable
							and "/luaui/images/terraform_brush/check_on.png"
							or "/luaui/images/terraform_brush/check_off.png")
					end
					-- Alt-max slider-row visibility driven by data-if="spAltMaxEnable"
					if widgetState.dmHandle then
						local v = tostring(sf.altMax)
						if widgetState.dmHandle.splatAltMaxStr ~= v then widgetState.dmHandle.splatAltMaxStr = v end
					end
					local spSAltMax = doc:GetElementById("sp-slider-alt-max")
					if spSAltMax and ds ~= "sp-alt-max" then
						spSAltMax:SetAttribute("value", tostring(sf.altMax))
					end

					-- SAMPLE button active states (data-class-active driven)
					local hsm = WG.TerraformBrush and (WG.TerraformBrush.getState() or {}).heightSamplingMode
					if dm then
						local minS = hsm == "spAltMin"
						if dm.spAltMinSample ~= minS then dm.spAltMinSample = minS end
						local maxS = hsm == "spAltMax"
						if dm.spAltMaxSample ~= maxS then dm.spAltMaxSample = maxS end
					end
				end
			end

			-- Export format label
			if spState.exportFormat and widgetState.dmHandle then
				local v = string.upper(spState.exportFormat)
				if widgetState.dmHandle.splatExportFmtStr ~= v then widgetState.dmHandle.splatExportFmtStr = v end
			end

			-- Undo/redo history slider sync
			do
				local undoCount = spState.undoCount or 0
				local redoCount = spState.redoCount or 0
				local total = undoCount + redoCount
				local spHistSlider = doc:GetElementById("slider-sp-history")
				if spHistSlider and ds ~= "sp-history" then
					spHistSlider:SetAttribute("max", tostring(total))
					spHistSlider:SetAttribute("value", tostring(undoCount))
				end
				local spHistNumbox = doc:GetElementById("slider-sp-history-numbox")
				if spHistNumbox then
					spHistNumbox.inner_rml = tostring(undoCount)
				end
			end

			-- Decal Exporter stats sync (throttled — every ~1 second)
			-- dc-heat-explosions driven by {{dcHeatExpStr}} in RML.
			do if WG.DecalExporter and (Spring.GetGameFrame() % 30 == 0) then
				if widgetState.dmHandle then
					local v = tostring(WG.DecalExporter.getTotalExplosions())
					if widgetState.dmHandle.dcHeatExpStr ~= v then widgetState.dmHandle.dcHeatExpStr = v end
				end
			end end

			uiState.updatingFromCode = false
		end

		-- Gray out unsupported shapes in splat mode (no ring)
		for shape, element in pairs(widgetState.shapeButtons) do
			if element and shape ~= "ring" then
				element:SetClass("disabled", false)
			end
		end

		do
			local toolLabel = "SPLAT"
			setSummary(toolLabel, "#22c55e",
				"CH ", tostring(spState.channel or "?"),
				"", shapeNames[spState.shape] or "Circle",
				"R ", tostring(spState.radius or 0),
				"Str ", string.format("%.2f", spState.strength or 0),
				"Int ", string.format("%.1f", spState.intensity or 0))
		end

		-- Sync DISPLAY + INSTRUMENTS chip states from shared TerraformBrush state
		do
			local tb = WG.TerraformBrush
			if tb and tb.getState then
				local s = tb.getState()
					-- Visibility + active flags pushed to data-model (data-if and data-class-active in RML).
				local dm = widgetState.dmHandle
				if dm then
					dm.spGridSnap = s.gridSnap and true or false
					dm.spAngleSnap = s.angleSnap and true or false
					dm.spMeasureActive = s.measureActive and true or false
					dm.spSymmetryActive = s.symmetryActive and true or false
					dm.spSymmetryRadial = s.symmetryRadial and true or false
					dm.spSymmetryMirrorAny = (s.symmetryMirrorX or s.symmetryMirrorY) and true or false
					dm.spSymHasAxis = (s.symmetryRadial or s.symmetryMirrorX or s.symmetryMirrorY) and true or false
					dm.spAngleSnapAuto = s.angleSnapAuto and true or false
					dm.spGridOverlay = s.gridOverlay and true or false
					dm.spHeightColormap = s.heightColormap and true or false
					-- Splat Map overlay chip (own state from SplatPainter)
					local sp = WG.SplatPainter
					dm.spSplatOverlay = (sp and sp.getState and sp.getState().showSplatOverlay) and true or false
					-- Instruments sub-chip active states
					dm.spMeasureShowLength = s.measureShowLength and true or false
					dm.spSymMirrorX = s.symmetryMirrorX and true or false
					dm.spSymMirrorY = s.symmetryMirrorY and true or false
				end
				-- Hint dot: visible (pulsing) while DISPLAY section is closed
				do
					local tipsDisabled = widgetState.uiPrefs and widgetState.uiPrefs.disableTips
					local alreadySeen = widgetState.uiPrefs and widgetState.uiPrefs.seenSplatDisplayHint
					local sec = doc:GetElementById("section-sp-overlays")
					local hidden = tipsDisabled or alreadySeen or (sec and not sec:IsClassSet("hidden")) or false
					if dm then dm.spDisplayHintVisible = not hidden end
				end
				-- Chip 2-pulse: fires the frame after DISPLAY section is opened
				if widgetState.splatDisplayPulseFrame and Spring.GetGameFrame() >= widgetState.splatDisplayPulseFrame then
					widgetState.splatDisplayPulseFrame = nil
					local tipsDisabled = widgetState.uiPrefs and widgetState.uiPrefs.disableTips
					local splatChip = doc:GetElementById("btn-sp-splat-overlay")
					if splatChip and not tipsDisabled then
						splatChip:SetClass("tf-chip-2pulse", false)
						splatChip:SetClass("tf-chip-2pulse", true)
						widgetState.splatChip2PulseExpiry = (Spring.GetGameSeconds() or 0) + 1.25
					end
				end
				-- Remove 2-pulse class after animation completes
				if widgetState.splatChip2PulseExpiry and (Spring.GetGameSeconds() or 0) >= widgetState.splatChip2PulseExpiry then
					widgetState.splatChip2PulseExpiry = nil
					local splatChip = doc:GetElementById("btn-sp-splat-overlay")
					if splatChip then splatChip:SetClass("tf-chip-2pulse", false) end
				end
				-- sp instrument chip active states driven by data-class-active in RML
				-- (dm.spGridSnap/spAngleSnap/spMeasureActive/spSymmetryActive written in dm block above)
				-- sp-grid-snap-size-row, sp-angle-snap-step-row, sp-measure-toolbar-row,
				-- sp-symmetry-toolbar-row visibility driven by data-if (dm.sp* flags above).
				-- Symmetry sub chips + sub rows
				-- (active driven by data-class-active="spSymmetryRadial"/spSymMirrorX/spSymMirrorY)
				-- sp-symmetry-radial-count-row, sp-symmetry-mirror-angle-row visibility
				-- driven by data-if (dm.spSymmetryRadial / dm.spSymmetryMirrorAny).
				-- Measure sub chips
				-- (active driven by data-class-active="spMeasureShowLength")
				-- Angle auto-snap chip + manual spoke row (data-if="!spAngleSnapAuto")
				-- (active driven by data-class-active="spAngleSnapAuto")
				-- Labels: grid-snap-size/sym-count/sym-angle/angle-step display via shared tb* dm fields
				-- (tbGridSnapSizeStr/tbSymCountStr/tbSymAngleStr/tbAngleSnapStepStr set by syncTBMirrorControls).
				-- sp-angle-manual-spoke-label driven by {{spManualSpokeStr}} in RML.
				local step = s.angleSnapStep or 15
				local spokeStr = tostring(((s.angleSnapManualSpoke or 0) * step) % 360)
				if widgetState.dmHandle and widgetState.dmHandle.spManualSpokeStr ~= spokeStr then
					widgetState.dmHandle.spManualSpokeStr = spokeStr
				end
				-- Numbox + slider value sync (avoid re-firing change)
				uiState.updatingFromCode = true
				local nb = doc:GetElementById("sp-slider-grid-snap-size-numbox")
				if nb then nb:SetAttribute("value", tostring(s.gridSnapSize or 48)) end
				local sz = doc:GetElementById("sp-slider-grid-snap-size")
				if sz then sz:SetAttribute("value", tostring(s.gridSnapSize or 48)) end
				local cntSlSp = doc:GetElementById("sp-slider-symmetry-radial-count"); if cntSlSp then cntSlSp:SetAttribute("value", tostring(s.symmetryRadialCount or 2)) end
				local angSlSp = doc:GetElementById("sp-slider-symmetry-mirror-angle"); if angSlSp then angSlSp:SetAttribute("value", tostring(math.floor(s.symmetryMirrorAngle or 0))) end
				uiState.updatingFromCode = false
			end
		end

		-- P3.2 Splat grayouts (per Phase 3 relevance matrix)
		if doc and ctx.setDisabledIds then
			local circular = (spState.shape == "circle")
			ctx.setDisabledIds(doc, {
				"sp-slider-rotation", "sp-slider-rotation-numbox",
				"btn-sp-rot-ccw", "btn-sp-rot-cw",
			}, circular)
		end

end

return M
