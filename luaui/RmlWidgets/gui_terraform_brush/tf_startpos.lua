-- tf_startpos.lua: extracted tool module for gui_terraform_brush
local M = {}

function M.attach(doc, ctx)
	if ctx.attachTBMirrorControls then ctx.attachTBMirrorControls(doc, "st") end
	local widgetState = ctx.widgetState
	local uiState = ctx.uiState
	local WG = ctx.WG
	local playSound = ctx.playSound
	local trackSliderDrag = ctx.trackSliderDrag
	local ROTATION_STEP = ctx.ROTATION_STEP
	local GetMouseState = Spring.GetMouseState
	local TraceScreenRay = Spring.TraceScreenRay
	local Game = Game

		widgetState.stpSubmodesEl = doc:GetElementById("tf-startpos-submodes")
		widgetState.stpControlsEl = doc:GetElementById("tf-startpos-controls")
		widgetState.stpShapeOptionsEl = doc:GetElementById("sp-shape-options")
		widgetState.stpShapeRowEl = doc:GetElementById("sp-shape-row")
		widgetState.stpExpressHintEl = doc:GetElementById("sp-express-hint")
		widgetState.stpStartboxHintEl = doc:GetElementById("sp-startbox-hint")

		-- Cache sub-mode / shape button elements (sync still drives active class)
		for _, sm in ipairs({ "express", "shape", "startbox" }) do
			local btn = doc:GetElementById("btn-sp-" .. sm)
			if btn then widgetState.stpSubModeButtons[sm] = btn end
		end
		for _, sh in ipairs({ "circle", "square", "hexagon", "triangle" }) do
			local btn = doc:GetElementById("btn-sp-shape-" .. sh)
			if btn then widgetState.stpShapeButtons[sh] = btn end
		end

		-- Slider drag tracking (legitimate imperative: slider-specific drag state).
		-- Slider change events are wired declaratively via onchange= in RML.
		for _, sid in ipairs({ "sp-allyteams", "sp-count", "sp-size", "sp-rotation" }) do
			local sl = doc:GetElementById("slider-" .. sid)
			if sl then trackSliderDrag(sl, sid) end
		end

		-- Register widget methods for inline onclick="widget:spFoo()" handlers.
		local w = ctx.widget
		if w then
			w.spSetSubMode = function(self, sm)
				playSound("modeSwitch")
				if WG.StartPosTool then WG.StartPosTool.setSubMode(sm) end
			end
			w.spSetShape = function(self, sh)
				playSound("modeSwitch")
				if WG.StartPosTool then WG.StartPosTool.setShape(sh) end
			end
			w.spOnAllyTeamsChange = function(self, element)
				if uiState.updatingFromCode then return end
				local val = element and tonumber(element:GetAttribute("value")) or 2
				if WG.StartPosTool then WG.StartPosTool.setNumAllyTeams(val) end
			end
			w.spTeamsDown = function(self)
				if WG.StartPosTool then
					local s = WG.StartPosTool.getState()
					WG.StartPosTool.setNumAllyTeams(s.numAllyTeams - 1)
				end
			end
			w.spTeamsUp = function(self)
				if WG.StartPosTool then
					local s = WG.StartPosTool.getState()
					WG.StartPosTool.setNumAllyTeams(s.numAllyTeams + 1)
				end
			end
			w.spOnTeamsPerAllyChange = function(self, element)
				if uiState.updatingFromCode then return end
				local val = element and tonumber(element:GetAttribute("value")) or 1
				if WG.StartPosTool and WG.StartPosTool.setNumTeamsPerAlly then
					WG.StartPosTool.setNumTeamsPerAlly(val)
				end
			end
			w.spTeamsPerAllyDown = function(self)
				if WG.StartPosTool and WG.StartPosTool.setNumTeamsPerAlly then
					local s = WG.StartPosTool.getState()
					WG.StartPosTool.setNumTeamsPerAlly((s.numTeamsPerAlly or 1) - 1)
				end
			end
			w.spTeamsPerAllyUp = function(self)
				if WG.StartPosTool and WG.StartPosTool.setNumTeamsPerAlly then
					local s = WG.StartPosTool.getState()
					WG.StartPosTool.setNumTeamsPerAlly((s.numTeamsPerAlly or 1) + 1)
				end
			end
			w.spTogglePlacement = function(self)
				playSound("modeSwitch")
				if WG.StartPosTool and WG.StartPosTool.togglePlacementMode then
					WG.StartPosTool.togglePlacementMode()
				end
			end
			w.spSetStartboxMode = function(self, mode)
				playSound("modeSwitch")
				if WG.StartPosTool and WG.StartPosTool.setStartboxMode then
					WG.StartPosTool.setStartboxMode(mode)
				end
			end
			w.spOnCountChange = function(self, element)
				if uiState.updatingFromCode then return end
				local val = element and tonumber(element:GetAttribute("value")) or 4
				if WG.StartPosTool then WG.StartPosTool.setShapeCount(val) end
			end
			w.spCountDown = function(self)
				if WG.StartPosTool then
					local s = WG.StartPosTool.getState()
					WG.StartPosTool.setShapeCount(s.shapeCount - 1)
				end
			end
			w.spCountUp = function(self)
				if WG.StartPosTool then
					local s = WG.StartPosTool.getState()
					WG.StartPosTool.setShapeCount(s.shapeCount + 1)
				end
			end
			w.spOnSizeChange = function(self, element)
				if uiState.updatingFromCode then return end
				local val = element and tonumber(element:GetAttribute("value")) or 2000
				if WG.StartPosTool then WG.StartPosTool.setRadius(val) end
			end
			w.spSizeDown = function(self)
				if WG.StartPosTool then
					local s = WG.StartPosTool.getState()
					WG.StartPosTool.setRadius(s.shapeRadius - 32)
				end
			end
			w.spSizeUp = function(self)
				if WG.StartPosTool then
					local s = WG.StartPosTool.getState()
					WG.StartPosTool.setRadius(s.shapeRadius + 32)
				end
			end
			w.spOnRotationChange = function(self, element)
				if uiState.updatingFromCode then return end
				local val = element and tonumber(element:GetAttribute("value")) or 0
				if WG.StartPosTool then WG.StartPosTool.setRotation(val) end
			end
			w.spRotCW = function(self)
				if WG.StartPosTool then
					local s = WG.StartPosTool.getState()
					WG.StartPosTool.setRotation(((s and s.shapeRotation or 0) + ROTATION_STEP) % 360)
				end
			end
			w.spRotCCW = function(self)
				if WG.StartPosTool then
					local s = WG.StartPosTool.getState()
					WG.StartPosTool.setRotation(((s and s.shapeRotation or 0) - ROTATION_STEP) % 360)
				end
			end
			w.spRandom = function(self)
				playSound("apply")
				if WG.StartPosTool then
					local mx, my = GetMouseState()
					local _, pos = TraceScreenRay(mx, my, true)
					if pos then
						WG.StartPosTool.placeRandomPositions(pos[1], pos[3])
					else
						local mapX = Game.mapSizeX / 2
						local mapZ = Game.mapSizeZ / 2
						WG.StartPosTool.placeRandomPositions(mapX, mapZ)
					end
				end
			end
			w.spClear = function(self)
				playSound("apply")
				if WG.StartPosTool then
					WG.StartPosTool.clearAllPositions()
					WG.StartPosTool.clearAllStartboxes()
				end
			end
			w.spSave = function(self)
				playSound("apply")
				if WG.StartPosTool then
					WG.StartPosTool.saveStartPositions()
					WG.StartPosTool.saveStartboxes()
				end
			end
			w.spLoad = function(self)
				playSound("apply")
				if WG.StartPosTool then
					WG.StartPosTool.loadStartPositions()
					WG.StartPosTool.loadStartboxes()
				end
			end
		end
end

function M.sync(doc, ctx, stpState, setSummary)
	if ctx.syncTBMirrorControls then ctx.syncTBMirrorControls(doc, "st") end
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

		-- Sub-mode buttons: Express + Shape (Shape == startbox submode internally)
		local expressBtn = doc and doc:GetElementById("btn-sp-express")
		local shapeBtn   = doc and doc:GetElementById("btn-sp-shape")
		if expressBtn then expressBtn:SetClass("active", stpState.subMode == "express") end
		if shapeBtn   then shapeBtn:SetClass("active",   stpState.subMode == "startbox") end

		-- Shape buttons
		setActiveClass(widgetState.stpShapeButtons, stpState.shapeType)

		-- Startbox placement-mode buttons (box / polygon / freedraw)
		if doc then
			local sbxMode = stpState.startboxMode or "polygon"
			local inStartbox = stpState.subMode == "startbox"
			local sbxRow  = doc:GetElementById("sp-startbox-mode-row")
			-- Always show the row (under Express/Shape); grey out when Shape isn't active.
			if sbxRow then sbxRow:SetClass("hidden", false) end
			local boxBtn  = doc:GetElementById("btn-sp-sbx-box")
			local polyBtn = doc:GetElementById("btn-sp-sbx-polygon")
			local freeBtn = doc:GetElementById("btn-sp-sbx-freedraw")
			if boxBtn  then
				boxBtn:SetClass("active",   inStartbox and sbxMode == "box")
				boxBtn:SetClass("disabled", not inStartbox)
			end
			if polyBtn then
				polyBtn:SetClass("active",   inStartbox and sbxMode == "polygon")
				polyBtn:SetClass("disabled", not inStartbox)
			end
			if freeBtn then
				freeBtn:SetClass("active",   inStartbox and sbxMode == "freedraw")
				freeBtn:SetClass("disabled", not inStartbox)
			end
			-- Swap contextual hint text (only meaningful when Shape/startbox active)
			local hBox  = doc:GetElementById("sp-sbx-hint-box")
			local hPoly = doc:GetElementById("sp-sbx-hint-polygon")
			local hFree = doc:GetElementById("sp-sbx-hint-freedraw")
			if hBox  then hBox:SetClass("hidden",  not inStartbox or sbxMode ~= "box") end
			if hPoly then hPoly:SetClass("hidden", not inStartbox or sbxMode ~= "polygon") end
			if hFree then hFree:SetClass("hidden", not inStartbox or sbxMode ~= "freedraw") end
		end

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
		-- Teams-per-ally
		local tpaLabel = doc and doc:GetElementById("sp-teams-per-ally-label")
		if tpaLabel then tpaLabel.inner_rml = tostring(stpState.numTeamsPerAlly or 1) end
		local tpaSlider = doc and doc:GetElementById("slider-sp-teams-per-ally")
		if tpaSlider then tpaSlider:SetAttribute("value", tostring(stpState.numTeamsPerAlly or 1)) end
		local tpaNumbox = doc and doc:GetElementById("slider-sp-teams-per-ally-numbox")
		if tpaNumbox then tpaNumbox:SetAttribute("value", tostring(stpState.numTeamsPerAlly or 1)) end
		-- Placement mode toggle button label
		local pmBtn = doc and doc:GetElementById("btn-sp-placement-mode")
		if pmBtn then pmBtn.inner_rml = (stpState.placementMode or "roundrobin"):upper():gsub("ROUNDROBIN", "ROUND-ROBIN") end
		local countSlider = doc and doc:GetElementById("slider-sp-count")
		if countSlider then countSlider:SetAttribute("value", tostring(stpState.shapeCount)) end
		local sizeSlider = doc and doc:GetElementById("slider-sp-size")
		if sizeSlider then sizeSlider:SetAttribute("value", tostring(math.floor(stpState.shapeRadius))) end
		local rotSlider = doc and doc:GetElementById("slider-sp-rotation")
		if rotSlider then rotSlider:SetAttribute("value", tostring(math.floor(stpState.shapeRotation))) end

		setSummary("START POS", "#9ca3af",
			"", (stpState.subMode or "express"):upper(),
			"Players ", tostring(stpState.totalPlayers or (stpState.numAllyTeams or 2)) .. " (" .. tostring(stpState.numAllyTeams or 2) .. "x" .. tostring(stpState.numTeamsPerAlly or 1) .. ")")

		-- P3.2 StartPos grayouts (per Phase 3 relevance matrix)
		if doc and ctx.setDisabledIds then
			local sm = stpState.subMode or "express"
			-- Ally teams slider: manual startbox submode uses drag, not team count
			ctx.setDisabledIds(doc, {
				"slider-sp-allyteams", "slider-sp-allyteams-numbox",
				"btn-sp-teams-up", "btn-sp-teams-down",
			}, sm == "startbox")
			-- Rotation: shape-mode only AND non-circular shape type
			local rotOff = (sm ~= "shape") or (stpState.shapeType == "circle")
			ctx.setDisabledIds(doc, {
				"slider-sp-rotation", "slider-sp-rotation-numbox",
				"btn-sp-rot-ccw", "btn-sp-rot-cw",
			}, rotOff)
		end

end

return M
