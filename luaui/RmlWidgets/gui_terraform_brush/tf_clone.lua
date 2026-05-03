-- tf_clone.lua: extracted tool module for gui_terraform_brush
local M = {}

function M.attach(doc, ctx)
	if ctx.attachTBMirrorControls then ctx.attachTBMirrorControls(doc, "cl") end
	local widgetState = ctx.widgetState
	local trackSliderDrag = ctx.trackSliderDrag

	widgetState.cloneActive = false

	-- Slider drag tracking (legitimate imperative: slider-specific drag state).
	-- Slider change events are wired declaratively via data-event-change= in RML.
	for _, sid in ipairs({ "cl-rotation", "cl-height", "cl-history" }) do
		local sl = doc:GetElementById("slider-" .. sid)
		if sl then trackSliderDrag(sl, sid) end
	end
	-- All data-event-click/change handlers (onClXxx) are defined in initialModel
	-- in gui_terraform_brush.lua — Recoil forbids adding or replacing function
	-- keys in a DataModel after OpenDataModel.
end

function M.sync(doc, ctx, clState, setSummary)
	if ctx.syncTBMirrorControls then ctx.syncTBMirrorControls(doc, "cl") end
	local widgetState = ctx.widgetState
	local uiState = ctx.uiState
	local WG = ctx.WG
	local syncAndFlash = ctx.syncAndFlash
	local cadenceToSlider = ctx.cadenceToSlider
	local shapeNames = ctx.shapeNames
		-- ===== Clone Tool mode: highlight button, sync controls =====
		do
			-- Update status label (dm.clStatusStr → {{clStatusStr}} in RML)
			if clState and widgetState.dmHandle then
				local statusText = "Select an area to clone"
				if clState.state == "selecting" then
					statusText = "Drawing selection..."
				elseif clState.state == "box_drawn" then
					statusText = "Box drawn \194\183 Ctrl+C to copy"
				elseif clState.state == "copied" then
					statusText = "Copied \194\183 Ctrl+V to paste"
				elseif clState.state == "paste_preview" then
					statusText = "Click to paste \194\183 RMB to cancel"
				end
				if widgetState.dmHandle.clStatusStr ~= statusText then
					widgetState.dmHandle.clStatusStr = statusText
				end
			end

			-- Sync rotation/height sliders
			if doc then
				uiState.updatingFromCode = true
				local ds = uiState.draggingSlider
				if widgetState.dmHandle and clState then
					local v = tostring(math.floor(clState.pasteRotation)) .. "\194\176"
					if widgetState.dmHandle.clRotationStr ~= v then widgetState.dmHandle.clRotationStr = v end
				end
				local rotSl = doc:GetElementById("slider-cl-rotation")
				if rotSl and ds ~= "cl-rotation" and clState then
					rotSl:SetAttribute("value", tostring(math.floor(clState.pasteRotation)))
				end
				local rotNumbox = doc:GetElementById("slider-cl-rotation-numbox")
				if rotNumbox and ds ~= "cl-rotation" and clState then
					rotNumbox:SetAttribute("value", tostring(math.floor(clState.pasteRotation)))
				end
				if widgetState.dmHandle and clState then
					local v = tostring(math.floor(clState.pasteHeightOffset))
					if widgetState.dmHandle.clHeightStr ~= v then widgetState.dmHandle.clHeightStr = v end
				end
				local heightSl = doc:GetElementById("slider-cl-height")
				if heightSl and ds ~= "cl-height" and clState then
					heightSl:SetAttribute("value", tostring(math.floor(clState.pasteHeightOffset)))
				end
				local heightNumbox = doc:GetElementById("slider-cl-height-numbox")
				if heightNumbox and ds ~= "cl-height" and clState then
					heightNumbox:SetAttribute("value", tostring(math.floor(clState.pasteHeightOffset)))
				end

				-- Sync mirror buttons (dm)
				if clState and widgetState.dmHandle then
					local dm = widgetState.dmHandle
					local mx = clState.pasteMirrorX and true or false
					local mz = clState.pasteMirrorZ and true or false
					if dm.clMirrorX ~= mx then dm.clMirrorX = mx end
					if dm.clMirrorZ ~= mz then dm.clMirrorZ = mz end
				end

				-- Sync layer toggle buttons (dm)
				if clState and clState.layers and widgetState.dmHandle then
					local dm = widgetState.dmHandle
					local ly = clState.layers
					if dm.clLayerTerrain  ~= (ly.terrain  == true) then dm.clLayerTerrain  = ly.terrain  == true end
					if dm.clLayerMetal    ~= (ly.metal    == true) then dm.clLayerMetal    = ly.metal    == true end
					if dm.clLayerFeatures ~= (ly.features == true) then dm.clLayerFeatures = ly.features == true end
					if dm.clLayerSplats   ~= (ly.splats   == true) then dm.clLayerSplats   = ly.splats   == true end
					if dm.clLayerGrass    ~= (ly.grass    == true) then dm.clLayerGrass    = ly.grass    == true end
					if dm.clLayerDecals   ~= (ly.decals   == true) then dm.clLayerDecals   = ly.decals   == true end
					if dm.clLayerWeather  ~= (ly.weather  == true) then dm.clLayerWeather  = ly.weather  == true end
					if dm.clLayerLights   ~= (ly.lights   == true) then dm.clLayerLights   = ly.lights   == true end
				end

				-- Sync quality button (dm)
				if clState and widgetState.dmHandle then
					local tq = clState.terrainQuality or "full"
					if widgetState.dmHandle.clQuality ~= tq then widgetState.dmHandle.clQuality = tq end
				end

				-- Sync history slider
				local sliderClHist = doc:GetElementById("slider-cl-history")
				if sliderClHist and ds ~= "cl-history" and clState then
					local totalSteps = (clState.undoCount or 0) + (clState.redoCount or 0)
					local maxVal = math.min(totalSteps, 400)
					if maxVal < 1 then maxVal = 1 end
					sliderClHist:SetAttribute("max", tostring(maxVal))
					sliderClHist:SetAttribute("value", tostring(clState.undoCount or 0))
				end

				uiState.updatingFromCode = false
			end
		end

		do
			local cs = clState and clState.state or "idle"
			local stateLabels = { idle = "IDLE", selecting = "SELECTING", box_drawn = "BOX DRAWN", copied = "COPIED", paste_preview = "PASTE" }
			setSummary("CLONE", "#22d3ee",
				"", stateLabels[cs] or cs:upper(),
				"Rot ", tostring(math.floor(clState and clState.pasteRotation or 0)) .. "\194\176",
				"Quality ", (clState and clState.terrainQuality or "full"):upper())
		end

		-- P3.2 Clone grayouts (per Phase 3 relevance matrix)
		if doc and ctx.setDisabledIds and clState then
			local cs = clState.state or "idle"
			local hasBuf = clState.hasBuffer == true
			local hasSel = (cs == "selecting" or cs == "box_drawn")
			local inPaste = (cs == "paste_preview")
			-- Copy: needs an active selection
			ctx.setDisabled(doc, "btn-cl-copy", not hasSel)
			-- Paste: needs a buffer
			ctx.setDisabled(doc, "btn-cl-paste", not hasBuf)
			-- Clear: meaningful when any state or buffer
			ctx.setDisabled(doc, "btn-cl-clear", cs == "idle" and not hasBuf)
			-- Paste-transform controls: only meaningful during paste preview
			ctx.setDisabledIds(doc, {
				"slider-cl-rotation", "slider-cl-rotation-numbox",
				"btn-cl-rot-ccw", "btn-cl-rot-cw",
				"slider-cl-height", "slider-cl-height-numbox",
				"btn-cl-height-down", "btn-cl-height-up",
				"btn-cl-mirror-x", "btn-cl-mirror-z",
			}, not inPaste)
		end

end

return M
