-- tf_clone.lua: extracted tool module for gui_terraform_brush
local M = {}

function M.attach(doc, ctx)
	if ctx.attachTBMirrorControls then ctx.attachTBMirrorControls(doc, "cl") end
	local widgetState = ctx.widgetState
	local uiState = ctx.uiState
	local WG = ctx.WG
	local playSound = ctx.playSound
	local trackSliderDrag = ctx.trackSliderDrag
	local clearPassthrough = ctx.clearPassthrough
	local ROTATION_STEP = ctx.ROTATION_STEP

	widgetState.cloneActive = false
	widgetState.cloneControlsEl = doc:GetElementById("tf-clone-controls")
	widgetState.clonePasteTransformsEl = doc:GetElementById("cl-paste-transforms")

	-- Slider drag tracking (legitimate imperative: slider-specific drag state).
	-- Slider change events are wired declaratively via onchange= in RML.
	for _, sid in ipairs({ "cl-rotation", "cl-height", "cl-history" }) do
		local sl = doc:GetElementById("slider-" .. sid)
		if sl then trackSliderDrag(sl, sid) end
	end

	-- Register widget methods for inline onclick/onchange handlers in RML.
	local w = ctx.widget
	if not w then return end

	w.clOnClone = function(self)
		playSound("toolSwitch")
		clearPassthrough()
		if widgetState.cloneActive then
			-- Toggle OFF
			widgetState.cloneActive = false
			if WG.CloneTool then WG.CloneTool.deactivate() end
			if WG.TerraformBrush then
				local st = WG.TerraformBrush.getState()
				WG.TerraformBrush.setMode(st and st.mode or "raise")
			end
		else
			-- Toggle ON: deactivate all other tools
			if WG.TerraformBrush then WG.TerraformBrush.deactivate() end
			if WG.FeaturePlacer then WG.FeaturePlacer.deactivate() end
			if WG.WeatherBrush then WG.WeatherBrush.deactivate() end
			if WG.SplatPainter then WG.SplatPainter.deactivate() end
			if WG.MetalBrush then WG.MetalBrush.deactivate() end
			if WG.GrassBrush then WG.GrassBrush.deactivate() end
			widgetState.envActive = false
			widgetState.lightActive = false
			if WG.LightPlacer then WG.LightPlacer.deactivate() end
			widgetState.startposActive = false
			if WG.StartPosTool then WG.StartPosTool.deactivate() end
			widgetState.decalsActive = false
			if WG.DecalPlacer then WG.DecalPlacer.deactivate() end
			widgetState.cloneActive = true
			if WG.CloneTool then WG.CloneTool.activate() end
		end
	end

	w.clToggleLayer = function(self, name)
		if not WG.CloneTool then return end
		local st = WG.CloneTool.getState()
		local cur = st and st.layers and st.layers[name] or false
		WG.CloneTool.setLayer(name, not cur)
		-- Active-class sync happens in M.sync() via clState.layers; no need to toggle here.
	end

	w.clCopy = function(self)
		if WG.CloneTool then WG.CloneTool.doCopy() end
	end
	w.clPaste = function(self)
		if WG.CloneTool then WG.CloneTool.startPaste() end
	end
	w.clClear = function(self)
		if WG.CloneTool then WG.CloneTool.cancelOperation() end
	end

	w.clOnRotChange = function(self, element)
		if uiState.updatingFromCode then return end
		local val = element and tonumber(element:GetAttribute("value")) or 0
		if WG.CloneTool then WG.CloneTool.setRotation(val) end
	end
	w.clRotCW = function(self)
		if WG.CloneTool then
			local st = WG.CloneTool.getState()
			WG.CloneTool.setRotation(((st and st.pasteRotation or 0) + ROTATION_STEP) % 360)
		end
	end
	w.clRotCCW = function(self)
		if WG.CloneTool then
			local st = WG.CloneTool.getState()
			WG.CloneTool.setRotation(((st and st.pasteRotation or 0) - ROTATION_STEP) % 360)
		end
	end

	w.clOnHeightChange = function(self, element)
		if uiState.updatingFromCode then return end
		local val = element and tonumber(element:GetAttribute("value")) or 0
		if WG.CloneTool then WG.CloneTool.setHeightOffset(val) end
	end
	w.clHeightUp = function(self)
		if WG.CloneTool then
			local st = WG.CloneTool.getState()
			local cur = (st and st.pasteHeightOffset or 0)
			WG.CloneTool.setHeightOffset(math.min(500, cur + 10))
		end
	end
	w.clHeightDown = function(self)
		if WG.CloneTool then
			local st = WG.CloneTool.getState()
			local cur = (st and st.pasteHeightOffset or 0)
			WG.CloneTool.setHeightOffset(math.max(-500, cur - 10))
		end
	end

	w.clToggleMirrorX = function(self)
		if not WG.CloneTool then return end
		local st = WG.CloneTool.getState()
		WG.CloneTool.setMirrorX(not (st and st.pasteMirrorX))
		-- Active-class sync happens in M.sync() via clState.pasteMirrorX.
	end
	w.clToggleMirrorZ = function(self)
		if not WG.CloneTool then return end
		local st = WG.CloneTool.getState()
		WG.CloneTool.setMirrorZ(not (st and st.pasteMirrorZ))
		-- Active-class sync happens in M.sync() via clState.pasteMirrorZ.
	end

	w.clSetQuality = function(self, qName)
		if WG.CloneTool then WG.CloneTool.setTerrainQuality(qName) end
		-- Active-class sync happens in M.sync() via clState.terrainQuality; no need to toggle here.
	end

	w.clUndo = function(self)
		if WG.CloneTool and WG.CloneTool.undo then WG.CloneTool.undo() end
	end
	w.clRedo = function(self)
		if WG.CloneTool and WG.CloneTool.redo then WG.CloneTool.redo() end
	end

	w.clOnHistoryChange = function(self, element)
		if uiState.updatingFromCode then return end
		if not WG.CloneTool then return end
		local val = element and tonumber(element:GetAttribute("value")) or 0
		local clSt = WG.CloneTool.getState()
		if not clSt then return end
		local currentUndoCount = clSt.undoCount or 0
		local diff = val - currentUndoCount
		if diff > 0 then
			for i = 1, diff do WG.CloneTool.redo() end
		elseif diff < 0 then
			for i = 1, -diff do WG.CloneTool.undo() end
		end
	end
end

function M.sync(doc, ctx, clState, setSummary)
	if ctx.syncTBMirrorControls then ctx.syncTBMirrorControls(doc, "cl") end
	local widgetState = ctx.widgetState
	local uiState = ctx.uiState
	local WG = ctx.WG
	local setActiveClass = ctx.setActiveClass
	local syncAndFlash = ctx.syncAndFlash
	local cadenceToSlider = ctx.cadenceToSlider
	local shapeNames = ctx.shapeNames
		-- ===== Clone Tool mode: highlight button, sync controls =====
		do
			local clBtnU = doc and doc:GetElementById("btn-clone")
			if clBtnU then clBtnU:SetClass("active", true) end


			-- Update status label
			local statusLabel = doc and doc:GetElementById("cl-status-label")
			if statusLabel and clState then
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
				statusLabel.inner_rml = statusText
			end

			-- Sync rotation/height sliders
			if doc then
				uiState.updatingFromCode = true
				local ds = uiState.draggingSlider
				local rotLabel = doc:GetElementById("cl-rotation-label")
				if rotLabel and clState then rotLabel.inner_rml = tostring(math.floor(clState.pasteRotation)) .. "\194\176" end
				local rotSl = doc:GetElementById("slider-cl-rotation")
				if rotSl and ds ~= "cl-rotation" and clState then
					rotSl:SetAttribute("value", tostring(math.floor(clState.pasteRotation)))
				end
				local rotNumbox = doc:GetElementById("slider-cl-rotation-numbox")
				if rotNumbox and ds ~= "cl-rotation" and clState then
					rotNumbox:SetAttribute("value", tostring(math.floor(clState.pasteRotation)))
				end
				local heightLabel = doc:GetElementById("cl-height-label")
				if heightLabel and clState then heightLabel.inner_rml = tostring(math.floor(clState.pasteHeightOffset)) end
				local heightSl = doc:GetElementById("slider-cl-height")
				if heightSl and ds ~= "cl-height" and clState then
					heightSl:SetAttribute("value", tostring(math.floor(clState.pasteHeightOffset)))
				end
				local heightNumbox = doc:GetElementById("slider-cl-height-numbox")
				if heightNumbox and ds ~= "cl-height" and clState then
					heightNumbox:SetAttribute("value", tostring(math.floor(clState.pasteHeightOffset)))
				end

				-- Sync mirror buttons
				local mirXBtn = doc:GetElementById("btn-cl-mirror-x")
				if mirXBtn and clState then mirXBtn:SetClass("active", clState.pasteMirrorX) end
				local mirZBtn = doc:GetElementById("btn-cl-mirror-z")
				if mirZBtn and clState then mirZBtn:SetClass("active", clState.pasteMirrorZ) end

				-- Sync layer toggle buttons
				if clState and clState.layers then
					local layerIds = {
						terrain  = "btn-cl-terrain",
						metal    = "btn-cl-metal",
						features = "btn-cl-features",
						splats   = "btn-cl-splats",
						grass    = "btn-cl-grass",
						decals   = "btn-cl-decals",
						weather  = "btn-cl-weather",
						lights   = "btn-cl-lights",
					}
					for name, id in pairs(layerIds) do
						local btn = doc:GetElementById(id)
						if btn then btn:SetClass("active", clState.layers[name] == true) end
					end
				end

				-- Sync quality buttons
				if clState then
					local tq = clState.terrainQuality or "full"
					local qFull = doc:GetElementById("btn-cl-quality-full")
					local qBal  = doc:GetElementById("btn-cl-quality-balanced")
					local qFast = doc:GetElementById("btn-cl-quality-fast")
					if qFull then qFull:SetClass("active", tq == "full") end
					if qBal  then qBal:SetClass("active", tq == "balanced") end
					if qFast then qFast:SetClass("active", tq == "fast") end
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
