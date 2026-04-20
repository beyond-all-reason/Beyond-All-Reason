-- tf_splat.lua: extracted tool module for gui_terraform_brush
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
	widgetState.spControlsEl = doc:GetElementById("tf-splat-controls")

	-- Splat channel buttons
	local spChannelButtons = {
		doc:GetElementById("btn-sp-ch1"),
		doc:GetElementById("btn-sp-ch2"),
		doc:GetElementById("btn-sp-ch3"),
		doc:GetElementById("btn-sp-ch4"),
	}
	for i, btn in ipairs(spChannelButtons) do
		if btn then
			btn:AddEventListener("click", function(event)
				playSound("modeSwitch")
				if WG.SplatPainter then WG.SplatPainter.setChannel(i) end
				for j, b in ipairs(spChannelButtons) do
					if b then b:SetClass("active", j == i) end
				end
				event:StopPropagation()
			end, false)
		end
	end

	-- Splat detail texture previews: discover per-layer texture names
	do
		widgetState.spPreviewEls = {
			doc:GetElementById("sp-ch1-preview"),
			doc:GetElementById("sp-ch2-preview"),
			doc:GetElementById("sp-ch3-preview"),
			doc:GetElementById("sp-ch4-preview"),
		}
		widgetState.spPreviewTextures = {}
		widgetState.spPreviewVerified = false
	end

	-- Splat strength slider + buttons
	local spSliderStrength = doc:GetElementById("sp-slider-strength")
	if spSliderStrength then
		trackSliderDrag(spSliderStrength, "sp-strength")
		spSliderStrength:AddEventListener("change", function(event)
			if not uiState.updatingFromCode and WG.SplatPainter then
				local val = tonumber(spSliderStrength:GetAttribute("value")) or 15
				WG.SplatPainter.setStrength(val / 100)
			end
			event:StopPropagation()
		end, false)
	end

	local spStrengthUp = doc:GetElementById("btn-sp-strength-up")
	if spStrengthUp then
		spStrengthUp:AddEventListener("click", function(event)
			if WG.SplatPainter then
				local st = WG.SplatPainter.getState()
				WG.SplatPainter.setStrength(st.strength + 0.05)
			end
			event:StopPropagation()
		end, false)
	end

	local spStrengthDown = doc:GetElementById("btn-sp-strength-down")
	if spStrengthDown then
		spStrengthDown:AddEventListener("click", function(event)
			if WG.SplatPainter then
				local st = WG.SplatPainter.getState()
				WG.SplatPainter.setStrength(st.strength - 0.05)
			end
			event:StopPropagation()
		end, false)
	end

	-- Splat intensity slider + buttons
	local spSliderIntensity = doc:GetElementById("sp-slider-intensity")
	if spSliderIntensity then
		trackSliderDrag(spSliderIntensity, "sp-intensity")
		spSliderIntensity:AddEventListener("change", function(event)
			if not uiState.updatingFromCode and WG.SplatPainter then
				local val = tonumber(spSliderIntensity:GetAttribute("value")) or 10
				WG.SplatPainter.setIntensity(val / 10)
			end
			event:StopPropagation()
		end, false)
	end

	local spIntensityUp = doc:GetElementById("btn-sp-intensity-up")
	if spIntensityUp then
		spIntensityUp:AddEventListener("click", function(event)
			if WG.SplatPainter then
				local st = WG.SplatPainter.getState()
				WG.SplatPainter.setIntensity(st.intensity + 0.1)
			end
			event:StopPropagation()
		end, false)
	end

	local spIntensityDown = doc:GetElementById("btn-sp-intensity-down")
	if spIntensityDown then
		spIntensityDown:AddEventListener("click", function(event)
			if WG.SplatPainter then
				local st = WG.SplatPainter.getState()
				WG.SplatPainter.setIntensity(st.intensity - 0.1)
			end
			event:StopPropagation()
		end, false)
	end

	-- Splat size slider + buttons
	local spSliderSize = doc:GetElementById("sp-slider-size")
	if spSliderSize then
		trackSliderDrag(spSliderSize, "sp-size")
		spSliderSize:AddEventListener("change", function(event)
			if not uiState.updatingFromCode and WG.SplatPainter then
				local val = tonumber(spSliderSize:GetAttribute("value")) or 100
				WG.SplatPainter.setRadius(val)
			end
			event:StopPropagation()
		end, false)
	end

	local spSizeUp = doc:GetElementById("btn-sp-size-up")
	if spSizeUp then
		spSizeUp:AddEventListener("click", function(event)
			if WG.SplatPainter then
				local st = WG.SplatPainter.getState()
				WG.SplatPainter.setRadius(st.radius + RADIUS_STEP)
			end
			event:StopPropagation()
		end, false)
	end

	local spSizeDown = doc:GetElementById("btn-sp-size-down")
	if spSizeDown then
		spSizeDown:AddEventListener("click", function(event)
			if WG.SplatPainter then
				local st = WG.SplatPainter.getState()
				WG.SplatPainter.setRadius(st.radius - RADIUS_STEP)
			end
			event:StopPropagation()
		end, false)
	end

	-- Splat rotation slider + buttons
	local spSliderRotation = doc:GetElementById("sp-slider-rotation")
	if spSliderRotation then
		trackSliderDrag(spSliderRotation, "sp-rotation")
		spSliderRotation:AddEventListener("change", function(event)
			if not uiState.updatingFromCode and WG.SplatPainter then
				local val = tonumber(spSliderRotation:GetAttribute("value")) or 0
				WG.SplatPainter.setRotation(val)
			end
			event:StopPropagation()
		end, false)
	end

	local spRotCW = doc:GetElementById("btn-sp-rot-cw")
	if spRotCW then
		spRotCW:AddEventListener("click", function(event)
			if WG.SplatPainter then WG.SplatPainter.rotate(ROTATION_STEP) end
			event:StopPropagation()
		end, false)
	end

	local spRotCCW = doc:GetElementById("btn-sp-rot-ccw")
	if spRotCCW then
		spRotCCW:AddEventListener("click", function(event)
			if WG.SplatPainter then WG.SplatPainter.rotate(-ROTATION_STEP) end
			event:StopPropagation()
		end, false)
	end

	-- Splat curve slider + buttons
	local spSliderCurve = doc:GetElementById("sp-slider-curve")
	if spSliderCurve then
		trackSliderDrag(spSliderCurve, "sp-curve")
		spSliderCurve:AddEventListener("change", function(event)
			if not uiState.updatingFromCode and WG.SplatPainter then
				local val = tonumber(spSliderCurve:GetAttribute("value")) or 10
				WG.SplatPainter.setCurve(val / 10)
			end
			event:StopPropagation()
		end, false)
	end

	local spCurveUp = doc:GetElementById("btn-sp-curve-up")
	if spCurveUp then
		spCurveUp:AddEventListener("click", function(event)
			if WG.SplatPainter then
				local st = WG.SplatPainter.getState()
				WG.SplatPainter.setCurve(st.curve + CURVE_STEP)
			end
			event:StopPropagation()
		end, false)
	end

	local spCurveDown = doc:GetElementById("btn-sp-curve-down")
	if spCurveDown then
		spCurveDown:AddEventListener("click", function(event)
			if WG.SplatPainter then
				local st = WG.SplatPainter.getState()
				WG.SplatPainter.setCurve(st.curve - CURVE_STEP)
			end
			event:StopPropagation()
		end, false)
	end

	-- Splat smart filter controls
	local function wireSpSmartToggle(btnId, filterKey)
		local btn = doc:GetElementById(btnId)
		if btn then
			btn:AddEventListener("click", function(event)
				if WG.SplatPainter then
					local sf = WG.SplatPainter.getState().smartFilters
					WG.SplatPainter.setSmartFilter(filterKey, not sf[filterKey])
				end
				event:StopPropagation()
			end, false)
		end
	end
	wireSpSmartToggle("btn-sp-avoid-water",    "avoidWater")
	wireSpSmartToggle("btn-sp-avoid-cliffs",   "avoidCliffs")
	wireSpSmartToggle("btn-sp-prefer-slopes",  "preferSlopes")
	wireSpSmartToggle("btn-sp-alt-min-enable", "altMinEnable")
	wireSpSmartToggle("btn-sp-alt-max-enable", "altMaxEnable")

	local btnSpSmartToggle = doc:GetElementById("btn-sp-smart-toggle")
	if btnSpSmartToggle then
		btnSpSmartToggle:AddEventListener("click", function(event)
			if WG.SplatPainter then
				local st = WG.SplatPainter.getState()
				WG.SplatPainter.setSmartEnabled(not st.smartEnabled)
			end
			event:StopPropagation()
		end, false)
	end

	local spSliderSlopeMax = doc:GetElementById("sp-slider-slope-max")
	if spSliderSlopeMax then
		trackSliderDrag(spSliderSlopeMax, "sp-slope-max")
		spSliderSlopeMax:AddEventListener("change", function(event)
			if not uiState.updatingFromCode and WG.SplatPainter then
				local val = tonumber(spSliderSlopeMax:GetAttribute("value")) or 45
				WG.SplatPainter.setSmartFilter("slopeMax", val)
			end
			event:StopPropagation()
		end, false)
	end

	local spSliderSlopeMin = doc:GetElementById("sp-slider-slope-min")
	if spSliderSlopeMin then
		trackSliderDrag(spSliderSlopeMin, "sp-slope-min")
		spSliderSlopeMin:AddEventListener("change", function(event)
			if not uiState.updatingFromCode and WG.SplatPainter then
				local val = tonumber(spSliderSlopeMin:GetAttribute("value")) or 10
				WG.SplatPainter.setSmartFilter("slopeMin", val)
			end
			event:StopPropagation()
		end, false)
	end

	local spSliderAltMin = doc:GetElementById("sp-slider-alt-min")
	if spSliderAltMin then
		trackSliderDrag(spSliderAltMin, "sp-alt-min")
		spSliderAltMin:AddEventListener("change", function(event)
			if not uiState.updatingFromCode and WG.SplatPainter then
				local val = tonumber(spSliderAltMin:GetAttribute("value")) or 0
				local sf = WG.SplatPainter.getState().smartFilters
				if sf.altMaxEnable and val > sf.altMax then
					WG.SplatPainter.setSmartFilter("altMax", val)
				end
				WG.SplatPainter.setSmartFilter("altMin", val)
			end
			event:StopPropagation()
		end, false)
	end

	local spSliderAltMax = doc:GetElementById("sp-slider-alt-max")
	if spSliderAltMax then
		trackSliderDrag(spSliderAltMax, "sp-alt-max")
		spSliderAltMax:AddEventListener("change", function(event)
			if not uiState.updatingFromCode and WG.SplatPainter then
				local val = tonumber(spSliderAltMax:GetAttribute("value")) or 200
				local sf = WG.SplatPainter.getState().smartFilters
				if sf.altMinEnable and val < sf.altMin then
					WG.SplatPainter.setSmartFilter("altMin", val)
				end
				WG.SplatPainter.setSmartFilter("altMax", val)
			end
			event:StopPropagation()
		end, false)
	end

	-- Splat painter smart filter +/- buttons
	do
		local function wireSpSmartBtn(btnId, filterKey, step)
			local btn = doc:GetElementById(btnId)
			if btn then
				btn:AddEventListener("click", function(event)
					if WG.SplatPainter then
						local sf = WG.SplatPainter.getState().smartFilters
						WG.SplatPainter.setSmartFilter(filterKey, (sf[filterKey] or 0) + step)
					end
					event:StopPropagation()
				end, false)
			end
		end
		wireSpSmartBtn("btn-sp-slope-max-up",   "slopeMax",  5)
		wireSpSmartBtn("btn-sp-slope-max-down", "slopeMax", -5)
		wireSpSmartBtn("btn-sp-slope-min-up",   "slopeMin",  5)
		wireSpSmartBtn("btn-sp-slope-min-down", "slopeMin", -5)
		wireSpSmartBtn("btn-sp-alt-min-up",     "altMin",   10)
		wireSpSmartBtn("btn-sp-alt-min-down",   "altMin",  -10)
		wireSpSmartBtn("btn-sp-alt-max-up",     "altMax",   10)
		wireSpSmartBtn("btn-sp-alt-max-down",   "altMax",  -10)
	end

	-- Splat export format toggle
	local spExportFmtBtn = doc:GetElementById("btn-sp-export-format")
	if spExportFmtBtn then
		spExportFmtBtn:AddEventListener("click", function(event)
			playSound("click")
			if WG.SplatPainter then WG.SplatPainter.cycleExportFormat() end
			event:StopPropagation()
		end, false)
	end

	-- Splat save button
	local spSaveBtn = doc:GetElementById("btn-sp-save")
	if spSaveBtn then
		spSaveBtn:AddEventListener("click", function(event)
			playSound("save")
			if WG.SplatPainter then WG.SplatPainter.saveSplats() end
			event:StopPropagation()
		end, false)
	end

	-- Splat undo/redo buttons and history slider
	do
		local spUndoBtn = doc:GetElementById("btn-sp-undo")
		if spUndoBtn then
			spUndoBtn:AddEventListener("click", function(event)
				playSound("click")
				if WG.SplatPainter then WG.SplatPainter.undo() end
				event:StopPropagation()
			end, false)
		end

		local spRedoBtn = doc:GetElementById("btn-sp-redo")
		if spRedoBtn then
			spRedoBtn:AddEventListener("click", function(event)
				playSound("click")
				if WG.SplatPainter then WG.SplatPainter.redo() end
				event:StopPropagation()
			end, false)
		end

		local spHistSlider = doc:GetElementById("slider-sp-history")
		if spHistSlider then
			spHistSlider:AddEventListener("change", function(event)
				if uiState.updatingFromCode then return end
				local spSt = WG.SplatPainter and WG.SplatPainter.getState()
				if not spSt then return end
				local newVal = tonumber(event.target:GetAttribute("value")) or 0
				local curPos = spSt.undoCount or 0
				local diff = newVal - curPos
				if diff < 0 then
					for _ = 1, -diff do
						WG.SplatPainter.undo()
					end
				elseif diff > 0 then
					for _ = 1, diff do
						WG.SplatPainter.redo()
					end
				end
				event:StopPropagation()
			end, false)
		end
	end

end

function M.sync(doc, ctx, spState, setSummary)
	local widgetState = ctx.widgetState
	local uiState = ctx.uiState
	local WG = ctx.WG
	local setActiveClass = ctx.setActiveClass
	local syncAndFlash = ctx.syncAndFlash
	local cadenceToSlider = ctx.cadenceToSlider
	local shapeNames = ctx.shapeNames
		-- ===== Splat Painter mode: update splat controls =====
		local splatBtn = doc and doc:GetElementById("btn-splat")
		if splatBtn then splatBtn:SetClass("active", true) end
		setActiveClass(widgetState.modeButtons, nil)

		setActiveClass(widgetState.shapeButtons, spState.shape)

		if doc then
			uiState.updatingFromCode = true
			local ds = uiState.draggingSlider

			-- Splat labels
			local spStrengthLabel = doc:GetElementById("sp-strength-label")
			if spStrengthLabel then spStrengthLabel.inner_rml = string.format("%.2f", spState.strength) end

			local spIntensityLabel = doc:GetElementById("sp-intensity-label")
			if spIntensityLabel then spIntensityLabel.inner_rml = string.format("%.1f", spState.intensity) end

			local spRadiusLabel = doc:GetElementById("sp-radius-label")
			if spRadiusLabel then spRadiusLabel.inner_rml = tostring(spState.radius) end

			local spRotationLabel = doc:GetElementById("sp-rotation-label")
			if spRotationLabel then spRotationLabel.inner_rml = tostring(spState.rotationDeg) end

			local spCurveLabel = doc:GetElementById("sp-curve-label")
			if spCurveLabel then spCurveLabel.inner_rml = string.format("%.1f", spState.curve) end

			-- Splat channel button highlights
			for i = 1, 4 do
				local chBtn = doc:GetElementById("btn-sp-ch" .. i)
				if chBtn then chBtn:SetClass("active", i == spState.channel) end
			end

			-- Splat sliders
			syncAndFlash(doc:GetElementById("sp-slider-strength"), "sp-strength", tostring(math.floor(spState.strength * 100 + 0.5)))
			syncAndFlash(doc:GetElementById("sp-slider-intensity"), "sp-intensity", tostring(math.floor(spState.intensity * 10 + 0.5)))
			syncAndFlash(doc:GetElementById("sp-slider-size"), "sp-size", tostring(spState.radius))
			syncAndFlash(doc:GetElementById("sp-slider-rotation"), "sp-rotation", tostring(spState.rotationDeg))
			syncAndFlash(doc:GetElementById("sp-slider-curve"), "sp-curve", tostring(math.floor(spState.curve * 10 + 0.5)))

			-- Smart filter UI sync
			local spSmartOptions = doc:GetElementById("sp-smart-options")
			if spSmartOptions then
				local isSmart = spState.smartEnabled == true
				spSmartOptions:SetClass("hidden", not isSmart)
				local spSmartToggleBtn = doc:GetElementById("btn-sp-smart-toggle")
				if spSmartToggleBtn then
					spSmartToggleBtn:SetAttribute("src", isSmart
						and "/luaui/images/terraform_brush/check_on.png"
						or  "/luaui/images/terraform_brush/check_off.png")
				end
				if spState.smartFilters then
					local sf = spState.smartFilters

					local avoidWaterBtn = doc:GetElementById("btn-sp-avoid-water")
					if avoidWaterBtn then
						avoidWaterBtn:SetAttribute("src", sf.avoidWater
							and "/luaui/images/terraform_brush/check_on.png"
							or "/luaui/images/terraform_brush/check_off.png")
					end

					local avoidCliffsBtn = doc:GetElementById("btn-sp-avoid-cliffs")
					if avoidCliffsBtn then
						avoidCliffsBtn:SetAttribute("src", sf.avoidCliffs
							and "/luaui/images/terraform_brush/check_on.png"
							or "/luaui/images/terraform_brush/check_off.png")
					end

					local slopeMaxRow = doc:GetElementById("sp-smart-slope-max-row")
					if slopeMaxRow then slopeMaxRow:SetClass("hidden", not sf.avoidCliffs) end
					local slopeMaxSliderRow = doc:GetElementById("sp-smart-slope-max-slider-row")
					if slopeMaxSliderRow then slopeMaxSliderRow:SetClass("hidden", not sf.avoidCliffs) end
					local slopeMaxLabel = doc:GetElementById("sp-smart-slope-max-label")
					if slopeMaxLabel then slopeMaxLabel.inner_rml = tostring(sf.slopeMax) end
					local spSSlopeMax = doc:GetElementById("sp-slider-slope-max")
					if spSSlopeMax and ds ~= "sp-slope-max" then
						spSSlopeMax:SetAttribute("value", tostring(sf.slopeMax))
					end

					local preferSlopesBtn = doc:GetElementById("btn-sp-prefer-slopes")
					if preferSlopesBtn then
						preferSlopesBtn:SetAttribute("src", sf.preferSlopes
							and "/luaui/images/terraform_brush/check_on.png"
							or "/luaui/images/terraform_brush/check_off.png")
					end

					local slopeMinRow = doc:GetElementById("sp-smart-slope-min-row")
					if slopeMinRow then slopeMinRow:SetClass("hidden", not sf.preferSlopes) end
					local slopeMinSliderRow = doc:GetElementById("sp-smart-slope-min-slider-row")
					if slopeMinSliderRow then slopeMinSliderRow:SetClass("hidden", not sf.preferSlopes) end
					local slopeMinLabel = doc:GetElementById("sp-smart-slope-min-label")
					if slopeMinLabel then slopeMinLabel.inner_rml = tostring(sf.slopeMin) end
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
					local altMinSliderRow = doc:GetElementById("sp-smart-alt-min-slider-row")
					if altMinSliderRow then altMinSliderRow:SetClass("hidden", not sf.altMinEnable) end
					local altMinLabel = doc:GetElementById("sp-smart-alt-min-label")
					if altMinLabel then altMinLabel.inner_rml = tostring(sf.altMin) end
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
					local altMaxSliderRow = doc:GetElementById("sp-smart-alt-max-slider-row")
					if altMaxSliderRow then altMaxSliderRow:SetClass("hidden", not sf.altMaxEnable) end
					local altMaxLabel = doc:GetElementById("sp-smart-alt-max-label")
					if altMaxLabel then altMaxLabel.inner_rml = tostring(sf.altMax) end
					local spSAltMax = doc:GetElementById("sp-slider-alt-max")
					if spSAltMax and ds ~= "sp-alt-max" then
						spSAltMax:SetAttribute("value", tostring(sf.altMax))
					end
				end
			end

			-- Export format label
			local spExportFmtLabel = doc:GetElementById("sp-export-format-label")
			if spExportFmtLabel and spState.exportFormat then
				spExportFmtLabel.inner_rml = string.upper(spState.exportFormat)
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
			do if WG.DecalExporter and (Spring.GetGameFrame() % 30 == 0) then
				local dcGl4 = doc:GetElementById("dc-gl4-count")
				local dcEng = doc:GetElementById("dc-engine-count")
				local dcHeat = doc:GetElementById("dc-heat-count")
				local dcHeatExp = doc:GetElementById("dc-heat-explosions")
				local gl4n = 0
				local decalsApi = WG['decalsgl4']
				if decalsApi and decalsApi.GetActiveDecals then
					local ad = decalsApi.GetActiveDecals()
					if ad then for _ in pairs(ad) do gl4n = gl4n + 1 end end
				end
				local engn = 0
				if Spring.GetAllGroundDecals then
					local ids = Spring.GetAllGroundDecals()
					if ids then engn = #ids end
				end
				if dcGl4 then dcGl4.inner_rml = tostring(gl4n) end
				if dcEng then dcEng.inner_rml = tostring(engn) end
				local _, _, _, hm = WG.DecalExporter.getHeatGrid()
				if dcHeat then dcHeat.inner_rml = string.format("%.0f", hm or 0) end
				if dcHeatExp then dcHeatExp.inner_rml = tostring(WG.DecalExporter.getTotalExplosions()) end
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

end

return M
