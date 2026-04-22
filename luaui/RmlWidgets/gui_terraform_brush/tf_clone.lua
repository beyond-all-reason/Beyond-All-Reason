-- tf_clone.lua: extracted tool module for gui_terraform_brush
local M = {}

function M.attach(doc, ctx)
	if ctx.attachTBMirrorControls then ctx.attachTBMirrorControls(doc, "cl") end
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
		widgetState.cloneActive = false
		widgetState.cloneControlsEl = doc:GetElementById("tf-clone-controls")
		widgetState.clonePasteTransformsEl = doc:GetElementById("cl-paste-transforms")

		-- Clone tool launch button
		local cloneBtn = doc:GetElementById("btn-clone")
		if cloneBtn then
			cloneBtn:AddEventListener("click", function(event)
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
				event:StopPropagation()
			end, false)
		end

		-- Layer toggles
		local layerNames = {"terrain", "metal", "features", "splats", "grass", "decals", "weather", "lights"}
		for _, name in ipairs(layerNames) do
			local el = doc:GetElementById("btn-cl-" .. name)
			if el then
				el:AddEventListener("click", function(event)
					local isActive = el:IsClassSet("active")
					el:SetClass("active", not isActive)
					if WG.CloneTool then WG.CloneTool.setLayer(name, not isActive) end
					event:StopPropagation()
				end, false)
			end
		end

		-- Copy button
		local copyBtn = doc:GetElementById("btn-cl-copy")
		if copyBtn then
			copyBtn:AddEventListener("click", function(event)
				if WG.CloneTool then WG.CloneTool.doCopy() end
				event:StopPropagation()
			end, false)
		end

		-- Paste button
		local pasteBtn = doc:GetElementById("btn-cl-paste")
		if pasteBtn then
			pasteBtn:AddEventListener("click", function(event)
				if WG.CloneTool then WG.CloneTool.startPaste() end
				event:StopPropagation()
			end, false)
		end

		-- Clear button
		local clearBtn = doc:GetElementById("btn-cl-clear")
		if clearBtn then
			clearBtn:AddEventListener("click", function(event)
				if WG.CloneTool then WG.CloneTool.cancelOperation() end
				event:StopPropagation()
			end, false)
		end

		-- Rotation slider
		local rotSlider = doc:GetElementById("slider-cl-rotation")
		if rotSlider then
			trackSliderDrag(rotSlider, "cl-rotation")
			rotSlider:AddEventListener("change", function(event)
				if uiState.updatingFromCode then return end
				local val = tonumber(rotSlider:GetAttribute("value")) or 0
				if WG.CloneTool then WG.CloneTool.setRotation(val) end
				event:StopPropagation()
			end, false)
		end
		local clRotCW = doc:GetElementById("btn-cl-rot-cw")
		if clRotCW then
			clRotCW:AddEventListener("click", function(event)
				if WG.CloneTool then
					local st = WG.CloneTool.getState()
					WG.CloneTool.setRotation(((st and st.pasteRotation or 0) + ROTATION_STEP) % 360)
				end
				event:StopPropagation()
			end, false)
		end
		local clRotCCW = doc:GetElementById("btn-cl-rot-ccw")
		if clRotCCW then
			clRotCCW:AddEventListener("click", function(event)
				if WG.CloneTool then
					local st = WG.CloneTool.getState()
					WG.CloneTool.setRotation(((st and st.pasteRotation or 0) - ROTATION_STEP) % 360)
				end
				event:StopPropagation()
			end, false)
		end

		-- Height offset slider
		local heightSlider = doc:GetElementById("slider-cl-height")
		if heightSlider then
			trackSliderDrag(heightSlider, "cl-height")
			heightSlider:AddEventListener("change", function(event)
				if uiState.updatingFromCode then return end
				local val = tonumber(heightSlider:GetAttribute("value")) or 0
				if WG.CloneTool then WG.CloneTool.setHeightOffset(val) end
				event:StopPropagation()
			end, false)
		end
		local clHeightUp = doc:GetElementById("btn-cl-height-up")
		if clHeightUp then
			clHeightUp:AddEventListener("click", function(event)
				if WG.CloneTool then
					local st = WG.CloneTool.getState()
					local cur = (st and st.pasteHeightOffset or 0)
					WG.CloneTool.setHeightOffset(math.min(500, cur + 10))
				end
				event:StopPropagation()
			end, false)
		end
		local clHeightDown = doc:GetElementById("btn-cl-height-down")
		if clHeightDown then
			clHeightDown:AddEventListener("click", function(event)
				if WG.CloneTool then
					local st = WG.CloneTool.getState()
					local cur = (st and st.pasteHeightOffset or 0)
					WG.CloneTool.setHeightOffset(math.max(-500, cur - 10))
				end
				event:StopPropagation()
			end, false)
		end

		-- Mirror X button
		local mirXBtn = doc:GetElementById("btn-cl-mirror-x")
		if mirXBtn then
			mirXBtn:AddEventListener("click", function(event)
				local isActive = mirXBtn:IsClassSet("active")
				mirXBtn:SetClass("active", not isActive)
				if WG.CloneTool then WG.CloneTool.setMirrorX(not isActive) end
				event:StopPropagation()
			end, false)
		end

		-- Mirror Z button
		local mirZBtn = doc:GetElementById("btn-cl-mirror-z")
		if mirZBtn then
			mirZBtn:AddEventListener("click", function(event)
				local isActive = mirZBtn:IsClassSet("active")
				mirZBtn:SetClass("active", not isActive)
				if WG.CloneTool then WG.CloneTool.setMirrorZ(not isActive) end
				event:StopPropagation()
			end, false)
		end

		-- Terrain quality buttons
		local qualityBtns = {
			doc:GetElementById("btn-cl-quality-full"),
			doc:GetElementById("btn-cl-quality-balanced"),
			doc:GetElementById("btn-cl-quality-fast"),
		}
		local qualityNames = { "full", "balanced", "fast" }
		for qi = 1, 3 do
			local btn = qualityBtns[qi]
			local qName = qualityNames[qi]
			if btn then
				btn:AddEventListener("click", function(event)
					if WG.CloneTool then WG.CloneTool.setTerrainQuality(qName) end
					for j = 1, 3 do
						if qualityBtns[j] then qualityBtns[j]:SetClass("active", j == qi) end
					end
					event:StopPropagation()
				end, false)
			end
		end

		-- Undo button
		local undoBtn = doc:GetElementById("btn-cl-undo")
		if undoBtn then
			undoBtn:AddEventListener("click", function(event)
				if WG.CloneTool and WG.CloneTool.undo then
					WG.CloneTool.undo()
				end
				event:StopPropagation()
			end, false)
		end

		-- Redo button
		local redoBtn = doc:GetElementById("btn-cl-redo")
		if redoBtn then
			redoBtn:AddEventListener("click", function(event)
				if WG.CloneTool and WG.CloneTool.redo then
					WG.CloneTool.redo()
				end
				event:StopPropagation()
			end, false)
		end

		-- History slider
		local sliderClHistory = doc:GetElementById("slider-cl-history")
		if sliderClHistory then
			trackSliderDrag(sliderClHistory, "cl-history")
			sliderClHistory:AddEventListener("change", function(event)
				if uiState.updatingFromCode then event:StopPropagation(); return end
				if not WG.CloneTool then event:StopPropagation(); return end
				local val = tonumber(sliderClHistory:GetAttribute("value")) or 0
				local clSt = WG.CloneTool.getState()
				if not clSt then event:StopPropagation(); return end
				local currentUndoCount = clSt.undoCount or 0
				local diff = val - currentUndoCount
				if diff > 0 then
					for i = 1, diff do
						WG.CloneTool.redo()
					end
				elseif diff < 0 then
					for i = 1, -diff do
						WG.CloneTool.undo()
					end
				end
				event:StopPropagation()
			end, false)
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
			setActiveClass(widgetState.modeButtons, nil)

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

				-- Sync quality buttons
				if clState then
					local tq = clState.terrainQuality or "balanced"
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
				"Quality ", (clState and clState.terrainQuality or "balanced"):upper())
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
