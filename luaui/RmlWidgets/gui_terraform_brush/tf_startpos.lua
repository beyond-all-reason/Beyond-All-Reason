-- tf_startpos.lua: STARTS tool panel module for gui_terraform_brush.
local M = {}

function M.attach(doc, ctx)
	local trackSliderDrag = ctx.trackSliderDrag

	for _, sid in ipairs({ "sp-allyteams", "sp-teams-per-ally", "sp-count", "sp-size", "sp-rotation" }) do
		local sl = doc:GetElementById("slider-" .. sid)
		if sl then
			trackSliderDrag(sl, sid)
		end
	end
	-- The onSpXxx event handlers live in initialModel in gui_terraform_brush.lua:
	-- Recoil forbids adding function keys to a DataModel after OpenDataModel.
end

function M.sync(doc, ctx, stpState, setSummary)
	if ctx.syncTBMirrorControls then
		ctx.syncTBMirrorControls(doc, "st")
	end
	local widgetState = ctx.widgetState

	if widgetState.dmHandle then
		local shp = stpState.shapeType or "circle"
		if widgetState.dmHandle.stpShapeMode ~= shp then
			widgetState.dmHandle.stpShapeMode = shp
		end
	end

	-- Startbox placement-mode buttons (box / polygon / freedraw)
	if doc then
		local sbxMode = stpState.startboxMode or "polygon"
		-- These flags drive data-if visibility in the RML.
		if widgetState.dmHandle then
			local sm = stpState.subMode or ""
			if widgetState.dmHandle.stpSubMode ~= sm then
				widgetState.dmHandle.stpSubMode = sm
			end
			if widgetState.dmHandle.stpStartboxMode ~= sbxMode then
				widgetState.dmHandle.stpStartboxMode = sbxMode
			end
		end
	end

	local dm = widgetState.dmHandle
	if dm then
		local function setDm(f, v)
			if dm[f] ~= v then
				dm[f] = v
			end
		end
		setDm("stpAllyTeamsStr", tostring(stpState.numAllyTeams))
		setDm("stpCountStr", tostring(stpState.shapeCount))
		setDm("stpSizeStr", tostring(math.floor(stpState.shapeRadius)))
		setDm("stpRotationStr", tostring(math.floor(stpState.shapeRotation)) .. "\194\176")
		setDm("stpTeamsPerAllyStr", tostring(stpState.numTeamsPerAlly or 1))
		setDm("stpPlacementModeStr", (stpState.placementMode or "roundrobin"):upper():gsub("ROUNDROBIN", "ROUND-ROBIN"))
	end

	local getCachedEl = ctx.getCachedEl
	local allySlider = doc and getCachedEl(doc, "slider-sp-allyteams")
	if allySlider then
		allySlider:SetAttribute("value", tostring(stpState.numAllyTeams))
	end
	local tpaSlider = doc and getCachedEl(doc, "slider-sp-teams-per-ally")
	if tpaSlider then
		tpaSlider:SetAttribute("value", tostring(stpState.numTeamsPerAlly or 1))
	end
	local tpaNumbox = doc and getCachedEl(doc, "slider-sp-teams-per-ally-numbox")
	if tpaNumbox then
		tpaNumbox:SetAttribute("value", tostring(stpState.numTeamsPerAlly or 1))
	end
	local countSlider = doc and getCachedEl(doc, "slider-sp-count")
	if countSlider then
		countSlider:SetAttribute("value", tostring(stpState.shapeCount))
	end
	local sizeSlider = doc and getCachedEl(doc, "slider-sp-size")
	if sizeSlider then
		sizeSlider:SetAttribute("value", tostring(math.floor(stpState.shapeRadius)))
	end
	local rotSlider = doc and getCachedEl(doc, "slider-sp-rotation")
	if rotSlider then
		rotSlider:SetAttribute("value", tostring(math.floor(stpState.shapeRotation)))
	end

	setSummary(
		"START POS",
		"#fdc04c",
		"",
		(stpState.subMode or "express"):upper(),
		"Players ",
		tostring(stpState.totalPlayers or (stpState.numAllyTeams or 2))
			.. " ("
			.. tostring(stpState.numAllyTeams or 2)
			.. "x"
			.. tostring(stpState.numTeamsPerAlly or 1)
			.. ")"
	)

	-- Gray out controls that do nothing in the current submode.
	if doc and ctx.setDisabledIds then
		local sm = stpState.subMode or "express"
		-- Both counts only drive start-position placement, so they are off in startbox
		-- (ally teams come from the boxes drawn) and in roles.
		ctx.setDisabledIds(doc, {
			"slider-sp-allyteams",
			"slider-sp-allyteams-numbox",
			"btn-sp-teams-up",
			"btn-sp-teams-down",
			"slider-sp-teams-per-ally",
			"slider-sp-teams-per-ally-numbox",
			"btn-sp-teams-per-ally-up",
			"btn-sp-teams-per-ally-down",
		}, sm == "startbox" or sm == "roles")
		-- Rotation only matters in shape mode on a non-circular shape.
		local rotOff = (sm ~= "shape") or (stpState.shapeType == "circle")
		ctx.setDisabledIds(doc, {
			"slider-sp-rotation",
			"slider-sp-rotation-numbox",
			"btn-sp-rot-ccw",
			"btn-sp-rot-cw",
		}, rotOff)
	end
end

return M
