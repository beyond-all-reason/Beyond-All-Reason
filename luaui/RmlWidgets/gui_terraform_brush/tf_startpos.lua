-- tf_startpos.lua: extracted tool module for gui_terraform_brush
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
	local GetMouseState = Spring.GetMouseState
	local TraceScreenRay = Spring.TraceScreenRay
	local Game = Game
		widgetState.stpSubmodesEl = doc:GetElementById("tf-startpos-submodes")
		widgetState.stpControlsEl = doc:GetElementById("tf-startpos-controls")
		widgetState.stpShapeOptionsEl = doc:GetElementById("sp-shape-options")
		widgetState.stpShapeRowEl = doc:GetElementById("sp-shape-row")
		widgetState.stpExpressHintEl = doc:GetElementById("sp-express-hint")
		widgetState.stpStartboxHintEl = doc:GetElementById("sp-startbox-hint")

		-- Sub-mode buttons
		local stpSubModes = { "express", "shape", "startbox" }
		for _, sm in ipairs(stpSubModes) do
			local btn = doc:GetElementById("btn-sp-" .. sm)
			if btn then
				widgetState.stpSubModeButtons[sm] = btn
				btn:AddEventListener("click", function(event)
					playSound("modeSwitch")
					if WG.StartPosTool then WG.StartPosTool.setSubMode(sm) end
					event:StopPropagation()
				end, false)
			end
		end

		-- Shape buttons
		local stpShapes = { "circle", "square", "hexagon", "triangle" }
		for _, sh in ipairs(stpShapes) do
			local btn = doc:GetElementById("btn-sp-shape-" .. sh)
			if btn then
				widgetState.stpShapeButtons[sh] = btn
				btn:AddEventListener("click", function(event)
					playSound("modeSwitch")
					if WG.StartPosTool then WG.StartPosTool.setShape(sh) end
					event:StopPropagation()
				end, false)
			end
		end

		-- Ally teams slider
		local allySlider = doc:GetElementById("slider-sp-allyteams")
		if allySlider then
			trackSliderDrag(allySlider, "sp-allyteams")
			allySlider:AddEventListener("change", function(event)
				if uiState.updatingFromCode then return end
				local val = tonumber(allySlider:GetAttribute("value")) or 2
				if WG.StartPosTool then WG.StartPosTool.setNumAllyTeams(val) end
				event:StopPropagation()
			end, false)
		end
		local teamsDown = doc:GetElementById("btn-sp-teams-down")
		if teamsDown then
			teamsDown:AddEventListener("click", function(event)
				if WG.StartPosTool then
					local s = WG.StartPosTool.getState()
					WG.StartPosTool.setNumAllyTeams(s.numAllyTeams - 1)
				end
				event:StopPropagation()
			end, false)
		end
		local teamsUp = doc:GetElementById("btn-sp-teams-up")
		if teamsUp then
			teamsUp:AddEventListener("click", function(event)
				if WG.StartPosTool then
					local s = WG.StartPosTool.getState()
					WG.StartPosTool.setNumAllyTeams(s.numAllyTeams + 1)
				end
				event:StopPropagation()
			end, false)
		end

		-- Shape count slider
		local countSlider = doc:GetElementById("slider-sp-count")
		if countSlider then
			trackSliderDrag(countSlider, "sp-count")
			countSlider:AddEventListener("change", function(event)
				if uiState.updatingFromCode then return end
				local val = tonumber(countSlider:GetAttribute("value")) or 4
				if WG.StartPosTool then WG.StartPosTool.setShapeCount(val) end
				event:StopPropagation()
			end, false)
		end
		local countDown = doc:GetElementById("btn-sp-count-down")
		if countDown then
			countDown:AddEventListener("click", function(event)
				if WG.StartPosTool then
					local s = WG.StartPosTool.getState()
					WG.StartPosTool.setShapeCount(s.shapeCount - 1)
				end
				event:StopPropagation()
			end, false)
		end
		local countUp = doc:GetElementById("btn-sp-count-up")
		if countUp then
			countUp:AddEventListener("click", function(event)
				if WG.StartPosTool then
					local s = WG.StartPosTool.getState()
					WG.StartPosTool.setShapeCount(s.shapeCount + 1)
				end
				event:StopPropagation()
			end, false)
		end

		-- Shape size slider
		local sizeSlider = doc:GetElementById("slider-sp-size")
		if sizeSlider then
			trackSliderDrag(sizeSlider, "sp-size")
			sizeSlider:AddEventListener("change", function(event)
				if uiState.updatingFromCode then return end
				local val = tonumber(sizeSlider:GetAttribute("value")) or 2000
				if WG.StartPosTool then WG.StartPosTool.setRadius(val) end
				event:StopPropagation()
			end, false)
		end
		local sizeDown = doc:GetElementById("btn-sp-size-down")
		if sizeDown then
			sizeDown:AddEventListener("click", function(event)
				if WG.StartPosTool then
					local s = WG.StartPosTool.getState()
					WG.StartPosTool.setRadius(s.shapeRadius - 32)
				end
				event:StopPropagation()
			end, false)
		end
		local sizeUp = doc:GetElementById("btn-sp-size-up")
		if sizeUp then
			sizeUp:AddEventListener("click", function(event)
				if WG.StartPosTool then
					local s = WG.StartPosTool.getState()
					WG.StartPosTool.setRadius(s.shapeRadius + 32)
				end
				event:StopPropagation()
			end, false)
		end

		-- Rotation slider
		local rotSlider = doc:GetElementById("slider-sp-rotation")
		if rotSlider then
			trackSliderDrag(rotSlider, "sp-rotation")
			rotSlider:AddEventListener("change", function(event)
				if uiState.updatingFromCode then return end
				local val = tonumber(rotSlider:GetAttribute("value")) or 0
				if WG.StartPosTool then WG.StartPosTool.setRotation(val) end
				event:StopPropagation()
			end, false)
		end
		do
			local spRotCW = doc:GetElementById("btn-sp-rot-cw")
			if spRotCW then
				spRotCW:AddEventListener("click", function(event)
					if WG.StartPosTool then
						local s = WG.StartPosTool.getState()
						WG.StartPosTool.setRotation(((s and s.shapeRotation or 0) + ROTATION_STEP) % 360)
					end
					event:StopPropagation()
				end, false)
			end
			local spRotCCW = doc:GetElementById("btn-sp-rot-ccw")
			if spRotCCW then
				spRotCCW:AddEventListener("click", function(event)
					if WG.StartPosTool then
						local s = WG.StartPosTool.getState()
						WG.StartPosTool.setRotation(((s and s.shapeRotation or 0) - ROTATION_STEP) % 360)
					end
					event:StopPropagation()
				end, false)
			end
		end

		-- Random positions button
		local randomBtn = doc:GetElementById("btn-sp-random")
		if randomBtn then
			randomBtn:AddEventListener("click", function(event)
				playSound("apply")
				if WG.StartPosTool then
					local mx, my = Spring.GetMouseState()
					local _, pos = Spring.TraceScreenRay(mx, my, true)
					if pos then
						WG.StartPosTool.placeRandomPositions(pos[1], pos[3])
					else
						-- Fallback: center of map
						local mapX = Game.mapSizeX / 2
						local mapZ = Game.mapSizeZ / 2
						WG.StartPosTool.placeRandomPositions(mapX, mapZ)
					end
				end
				event:StopPropagation()
			end, false)
		end

		-- Clear all button
		local clearBtn = doc:GetElementById("btn-sp-clear")
		if clearBtn then
			clearBtn:AddEventListener("click", function(event)
				playSound("apply")
				if WG.StartPosTool then
					WG.StartPosTool.clearAllPositions()
					WG.StartPosTool.clearAllStartboxes()
				end
				event:StopPropagation()
			end, false)
		end

		-- Save button
		local saveBtn = doc:GetElementById("btn-sp-save")
		if saveBtn then
			saveBtn:AddEventListener("click", function(event)
				playSound("apply")
				if WG.StartPosTool then
					WG.StartPosTool.saveStartPositions()
					WG.StartPosTool.saveStartboxes()
				end
				event:StopPropagation()
			end, false)
		end

		-- Load button
		local loadBtn = doc:GetElementById("btn-sp-load")
		if loadBtn then
			loadBtn:AddEventListener("click", function(event)
				playSound("apply")
				if WG.StartPosTool then
					WG.StartPosTool.loadStartPositions()
					WG.StartPosTool.loadStartboxes()
				end
				event:StopPropagation()
			end, false)
		end
end

function M.sync(doc, ctx, stpState, setSummary)
	local widgetState = ctx.widgetState
	local uiState = ctx.uiState
	local WG = ctx.WG
	local setActiveClass = ctx.setActiveClass
	local syncAndFlash = ctx.syncAndFlash
	local cadenceToSlider = ctx.cadenceToSlider
	local shapeNames = ctx.shapeNames
		-- ===== Start Positions mode: highlight button, sync controls =====
		local stpBtnU = doc and doc:GetElementById("btn-startpos")
		if stpBtnU then stpBtnU:SetClass("active", true) end
		setActiveClass(widgetState.modeButtons, nil)

		-- Sub-mode buttons
		setActiveClass(widgetState.stpSubModeButtons, stpState.subMode)

		-- Shape buttons
		setActiveClass(widgetState.stpShapeButtons, stpState.shapeType)

		-- Show/hide shape options and shape row (only in shape mode)
		local isShapeMode = stpState.subMode == "shape"
		if widgetState.stpShapeOptionsEl then
			widgetState.stpShapeOptionsEl:SetClass("hidden", not isShapeMode)
		end
		if widgetState.stpShapeRowEl then
			widgetState.stpShapeRowEl:SetClass("hidden", not isShapeMode)
		end

		-- Show/hide hint text based on sub-mode
		if widgetState.stpExpressHintEl then
			widgetState.stpExpressHintEl:SetClass("hidden", stpState.subMode ~= "express")
		end
		if widgetState.stpStartboxHintEl then
			widgetState.stpStartboxHintEl:SetClass("hidden", stpState.subMode ~= "startbox")
		end

		-- Update labels
		local allyLabel = doc and doc:GetElementById("sp-allyteams-label")
		if allyLabel then allyLabel.inner_rml = tostring(stpState.numAllyTeams) end
		local countLabel = doc and doc:GetElementById("sp-count-label")
		if countLabel then countLabel.inner_rml = tostring(stpState.shapeCount) end
		local sizeLabel = doc and doc:GetElementById("sp-size-label")
		if sizeLabel then sizeLabel.inner_rml = tostring(math.floor(stpState.shapeRadius)) end
		local rotLabel = doc and doc:GetElementById("sp-rotation-label")
		if rotLabel then rotLabel.inner_rml = tostring(math.floor(stpState.shapeRotation)) .. "\194\176" end

		-- Sync sliders
		local allySlider = doc and doc:GetElementById("slider-sp-allyteams")
		if allySlider then allySlider:SetAttribute("value", tostring(stpState.numAllyTeams)) end
		local countSlider = doc and doc:GetElementById("slider-sp-count")
		if countSlider then countSlider:SetAttribute("value", tostring(stpState.shapeCount)) end
		local sizeSlider = doc and doc:GetElementById("slider-sp-size")
		if sizeSlider then sizeSlider:SetAttribute("value", tostring(math.floor(stpState.shapeRadius))) end
		local rotSlider = doc and doc:GetElementById("slider-sp-rotation")
		if rotSlider then rotSlider:SetAttribute("value", tostring(math.floor(stpState.shapeRotation))) end

		setSummary("START POS", "#9ca3af",
			"", (stpState.subMode or "express"):upper(),
			"Teams ", tostring(stpState.numAllyTeams or 2))

end

return M
