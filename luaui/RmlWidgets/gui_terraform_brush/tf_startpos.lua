-- tf_startpos.lua: extracted tool module for gui_terraform_brush
local M = {}

function M.attach(doc, ctx)
	if ctx.attachTBMirrorControls then ctx.attachTBMirrorControls(doc, "st") end
	local trackSliderDrag = ctx.trackSliderDrag

	-- Slider drag tracking (legitimate imperative: slider-specific drag state).
	for _, sid in ipairs({ "sp-allyteams", "sp-teams-per-ally", "sp-count", "sp-size", "sp-rotation" }) do
		local sl = doc:GetElementById("slider-" .. sid)
		if sl then trackSliderDrag(sl, sid) end
	end
	-- All data-event-click/change handlers (onSpXxx) are defined in initialModel
	-- in gui_terraform_brush.lua — Recoil forbids adding or replacing function
	-- keys in a DataModel after OpenDataModel.
end

function M.sync(doc, ctx, stpState, setSummary)
	if ctx.syncTBMirrorControls then ctx.syncTBMirrorControls(doc, "st") end
	local widgetState = ctx.widgetState
	local uiState = ctx.uiState
	local WG = ctx.WG
	local syncAndFlash = ctx.syncAndFlash
	local cadenceToSlider = ctx.cadenceToSlider
	local shapeNames = ctx.shapeNames
		-- btn-startpos active state driven by data-class-active="activeTool == 'stp'" in RML.

		-- Sub-mode and shape buttons driven by dm fields via data-class-active
		-- (stpSubMode is set below at widgetState.dmHandle.stpSubMode)

		-- Startpos shape (stpShapeMode dm field)
		if widgetState.dmHandle then
			local shp = stpState.shapeType or "circle"
			if widgetState.dmHandle.stpShapeMode ~= shp then widgetState.dmHandle.stpShapeMode = shp end
		end

		-- Startbox placement-mode buttons (box / polygon / freedraw)
		if doc then
			local sbxMode = stpState.startboxMode or "polygon"
			local inStartbox = stpState.subMode == "startbox"
			-- Sync data-model flags driving data-if visibility
			if widgetState.dmHandle then
				local sm = stpState.subMode or ""
				if widgetState.dmHandle.stpSubMode ~= sm then widgetState.dmHandle.stpSubMode = sm end
				if widgetState.dmHandle.stpStartboxMode ~= sbxMode then widgetState.dmHandle.stpStartboxMode = sbxMode end
			end
			-- Contextual hint visibility now driven by data-if on the elements.
		end

		-- Visibility for sp-shape-options, sp-shape-row, sp-express-hint, sp-startbox-hint
		-- is driven by data-if="stpSubMode == ..." against widgetState.dmHandle.stpSubMode
		-- (synced above). No imperative SetClass needed here.

		-- Update labels via dm interpolation (Phase 2 step 4)
		local dm = widgetState.dmHandle
		if dm then
			local function setDm(f, v) if dm[f] ~= v then dm[f] = v end end
			setDm("stpAllyTeamsStr", tostring(stpState.numAllyTeams))
			setDm("stpCountStr", tostring(stpState.shapeCount))
			setDm("stpSizeStr", tostring(math.floor(stpState.shapeRadius)))
			setDm("stpRotationStr", tostring(math.floor(stpState.shapeRotation)) .. "\194\176")
			setDm("stpTeamsPerAllyStr", tostring(stpState.numTeamsPerAlly or 1))
			setDm("stpPlacementModeStr", (stpState.placementMode or "roundrobin"):upper():gsub("ROUNDROBIN", "ROUND-ROBIN"))
		end

		-- Sync sliders
		local getCachedEl = ctx.getCachedEl
		local allySlider = doc and getCachedEl(doc, "slider-sp-allyteams")
		if allySlider then allySlider:SetAttribute("value", tostring(stpState.numAllyTeams)) end
		local tpaSlider = doc and getCachedEl(doc, "slider-sp-teams-per-ally")
		if tpaSlider then tpaSlider:SetAttribute("value", tostring(stpState.numTeamsPerAlly or 1)) end
		local tpaNumbox = doc and getCachedEl(doc, "slider-sp-teams-per-ally-numbox")
		if tpaNumbox then tpaNumbox:SetAttribute("value", tostring(stpState.numTeamsPerAlly or 1)) end
		local countSlider = doc and getCachedEl(doc, "slider-sp-count")
		if countSlider then countSlider:SetAttribute("value", tostring(stpState.shapeCount)) end
		local sizeSlider = doc and getCachedEl(doc, "slider-sp-size")
		if sizeSlider then sizeSlider:SetAttribute("value", tostring(math.floor(stpState.shapeRadius))) end
		local rotSlider = doc and getCachedEl(doc, "slider-sp-rotation")
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
