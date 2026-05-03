-- tf_metal.lua â€” Metal Brush attach + sync (extracted from gui_terraform_brush.lua)
local M = {}

function M.attach(doc, ctx)
	local widgetState = ctx.widgetState
	local trackSliderDrag = ctx.trackSliderDrag

	widgetState.mbSubmodesEl = doc:GetElementById("tf-metal-submodes")
	widgetState.mbControlsEl = doc:GetElementById("tf-metal-controls")

	-- Slider drag tracking (legitimate imperative: slider-specific drag state).
	-- All data-event-click/change handlers (onMbXxx) are defined in initialModel
	-- in gui_terraform_brush.lua â€” Recoil forbids adding or replacing function
	-- keys in a DataModel after OpenDataModel.
	for _, entry in ipairs({
		{ "mb-slider-cluster-radius",            "mb-cluster-radius" },
		{ "mb-slider-axis-angle",                "mb-axis-angle" },
		{ "mb-slider-symmetry-radial-count",     "mb-symmetry-radial-count" },
		{ "mb-slider-symmetry-mirror-angle",     "mb-symmetry-mirror-angle" },
	}) do
		local sl = doc:GetElementById(entry[1])
		if sl then trackSliderDrag(sl, entry[2]) end
	end
end

function M.sync(doc, ctx, mbState, setSummary)
	local widgetState = ctx.widgetState
	local uiState = ctx.uiState
	local syncAndFlash = ctx.syncAndFlash
	local WG = ctx.WG
	local dm = widgetState.dmHandle

	-- btn-metal active state driven by data-class-active="activeTool == 'mb'" in RML.

	-- DISPLAY/INSTRUMENTS warn chips (shared TB state mirror)
	if doc and ctx.syncWarnChip then
		local tbs = (WG.TerraformBrush and WG.TerraformBrush.getState()) or {}
		local dispActive = tbs.gridOverlay or tbs.heightColormap
		local instActive = tbs.gridSnap or tbs.angleSnap or tbs.measureActive or tbs.symmetryActive
		ctx.syncWarnChip(doc, "warn-chip-mb-overlays",    "section-mb-overlays",    dispActive)
		ctx.syncWarnChip(doc, "warn-chip-mb-instruments", "section-mb-instruments", instActive)
	end

	-- Metal sub-mode buttons (driven by dm.mbSubMode via data-class-active)
	if widgetState.dmHandle then widgetState.dmHandle.mbSubMode = mbState.subMode or "paint" end

	-- Instruments sub-row visibility flags (data-if driven) + chip active states (data-class-active)
	do
		local s = WG.TerraformBrush and WG.TerraformBrush.getState and WG.TerraformBrush.getState()
		if dm and s then
			dm.mbGridSnap        = s.gridSnap and true or false
			dm.mbAngleSnap       = s.angleSnap and true or false
			dm.mbMeasureActive   = s.measureActive and true or false
			dm.mbSymmetryActive  = s.symmetryActive and true or false
			dm.mbSymmetryRadial  = s.symmetryRadial and true or false
			dm.mbSymmetryMirrorAny = (s.symmetryMirrorX or s.symmetryMirrorY) and true or false
			dm.mbSymHasAxis = (s.symmetryRadial or s.symmetryMirrorX or s.symmetryMirrorY) and true or false
			dm.mbAngleSnapAuto   = s.angleSnapAuto and true or false
			dm.mbGridOverlay     = s.gridOverlay and true or false
			dm.mbHeightColormap  = s.heightColormap and true or false
			dm.mbSymMirrorX      = s.symmetryMirrorX and true or false
			dm.mbSymMirrorY      = s.symmetryMirrorY and true or false
			dm.mbMeasureRulerMode  = s.measureRulerMode and true or false
			dm.mbMeasureStickyMode = s.measureStickyMode and true or false
			dm.mbMeasureShowLength = s.measureShowLength and true or false
		end
		-- data-class-active bindings in RML drive active state for all chips above.
	end

	-- Metal value slider & label sync
	if doc then
		uiState.updatingFromCode = true

		if dm then
			local v = string.format("%.1f", mbState.metalValue)
			if dm.mbValueStr ~= v then dm.mbValueStr = v end
		end

		do
			local mv = math.max(0.01, mbState.metalValue)
			local sv = math.floor(1000 * math.log(mv / 0.01) / math.log(50.0 / 0.01) + 0.5)
			syncAndFlash(doc:GetElementById("slider-metal-value"), "mb-value", tostring(sv))
		end

		-- Sync size, rotation, length, curve from shared terraform state
		local tfSt2 = WG.TerraformBrush and WG.TerraformBrush.getState()
		if tfSt2 then
if dm then
				local v = tostring(tfSt2.radius)
				if dm.mbSizeStr ~= v then dm.mbSizeStr = v end
			end
			syncAndFlash(doc:GetElementById("slider-mb-size"), "mb-size", tostring(tfSt2.radius))

if dm then
				local v = tostring(tfSt2.rotationDeg) .. "\194\176"
				if dm.mbRotStr ~= v then dm.mbRotStr = v end
			end
			syncAndFlash(doc:GetElementById("slider-mb-rotation"), "mb-rotation", tostring(tfSt2.rotationDeg))

if dm then
				local v = string.format("%.1f", tfSt2.lengthScale)
				if dm.mbLengthStr ~= v then dm.mbLengthStr = v end
			end
			syncAndFlash(doc:GetElementById("slider-mb-length"), "mb-length", tostring(math.floor(tfSt2.lengthScale * 10 + 0.5)))


			if dm then
				local v = string.format("%.1f", tfSt2.curve)
				if dm.mbCurveStr ~= v then dm.mbCurveStr = v end
			end
			syncAndFlash(doc:GetElementById("slider-mb-curve"), "mb-curve", tostring(math.floor(tfSt2.curve * 10 + 0.5)))
		end
		-- Symmetry count + angle slider sync (labels driven by dm.tbSymCountStr/tbSymAngleStr via syncTBMirrorControls)
		local symSt = WG.TerraformBrush and WG.TerraformBrush.getState()
		if symSt then
			syncAndFlash(doc:GetElementById("mb-slider-symmetry-radial-count"), "mb-symmetry-radial-count", tostring(symSt.symmetryRadialCount or 2))
			syncAndFlash(doc:GetElementById("mb-slider-symmetry-mirror-angle"), "mb-symmetry-mirror-angle", tostring(symSt.symmetryMirrorAngle or 0))
		end

		uiState.updatingFromCode = false
	end

	-- Shape: use terraform brush shape (shared)
	local tfSt = WG.TerraformBrush and WG.TerraformBrush.getState()
	if tfSt then
		if widgetState.dmHandle then widgetState.dmHandle.activeShape = tfSt.shape or "circle" end
	end

	-- P3.2 Metal grayouts (per Phase 3 relevance matrix)
	if doc and tfSt then
		local sm = mbState.subMode or "stamp"
		local circular = (tfSt.shape == "circle")
		local nonStamp = (sm ~= "stamp")
		-- Rotation: stamp mode AND non-circular shape
		local rotOff = nonStamp or circular
		ctx.setDisabledIds(doc, {
			"slider-mb-rotation", "slider-mb-rotation-numbox",
			"btn-mb-rot-ccw", "btn-mb-rot-cw",
		}, rotOff)
		-- Length: stamp mode AND non-circular shape
		ctx.setDisabledIds(doc, {
			"slider-mb-length", "slider-mb-length-numbox",
			"btn-mb-length-down", "btn-mb-length-up",
		}, rotOff)
		-- Curve/Fall-off: stamp mode only
		ctx.setDisabledIds(doc, {
			"slider-mb-curve", "slider-mb-curve-numbox",
			"btn-mb-curve-down", "btn-mb-curve-up",
		}, nonStamp)
		-- Metal Value: disabled in remove submode
		local valueOff = (sm == "remove")
		ctx.setDisabledIds(doc, {
			"slider-metal-value", "slider-metal-value-numbox",
			"btn-metal-value-down", "btn-metal-value-up",
		}, valueOff)
	end

	do
		local tfSt2 = WG.TerraformBrush and WG.TerraformBrush.getState()
		local sm = mbState.subMode or "paint"
		setSummary("METAL", "#14b8a6",
			"", sm:upper(),
			"R ", tostring(tfSt2 and tfSt2.radius or "?"),
			"Val ", string.format("%.1f", mbState.metalValue or 0),
			"Crv ", string.format("%.1f", tfSt2 and tfSt2.curve or 0))
	end

	-- Metal map analysis chip/slider sync
	if doc then
		-- Chip active states driven by data-class-active bindings in RML.
		local inspectorOpen = widgetState.mbInspectorOpen
			or mbState.clusterCounter or mbState.lassoActive or mbState.lassoClosed or mbState.balanceAxisActive
		widgetState.mbInspectorOpen = inspectorOpen and true or false
		-- Map analysis sub-row visibility + chip active states driven by data model
		if dm then
			dm.mbInspectorOpen = inspectorOpen and true or false
			dm.mbClusterOpen   = mbState.clusterCounter and true or false
			dm.mbLassoOpen     = (mbState.lassoActive or mbState.lassoClosed) and true or false
			dm.mbAxisOpen      = mbState.balanceAxisActive and true or false
			dm.mbMapOverlay    = mbState.mapOverlay and true or false
			dm.mbLassoActive   = mbState.lassoActive and true or false
		end
		local lbl = doc:GetElementById("mb-cluster-radius-label")
		if lbl then lbl.inner_rml = tostring(mbState.clusterRadius or 256) end
		-- Labels driven by {{mbClusterRadiusStr}}/{{mbAxisAngleStr}}/{{mbAxisAStr}}/{{mbAxisBStr}}/{{mbAxisBalanceStr}}/{{mbLassoTotalStr}} in RML.
		if dm then
			local v = tostring(mbState.clusterRadius or 256)
			if dm.mbClusterRadiusStr ~= v then dm.mbClusterRadiusStr = v end
			v = string.format("%.2f", mbState.lassoTotal or 0)
			if dm.mbLassoTotalStr ~= v then dm.mbLassoTotalStr = v end
			v = tostring(math.floor((mbState.balanceAxisAngleDeg or 0) + 0.5))
			if dm.mbAxisAngleStr ~= v then dm.mbAxisAngleStr = v end
			v = string.format("%.2f", mbState.balanceAxisSumA or 0)
			if dm.mbAxisAStr ~= v then dm.mbAxisAStr = v end
			v = string.format("%.2f", mbState.balanceAxisSumB or 0)
			if dm.mbAxisBStr ~= v then dm.mbAxisBStr = v end
			do
				local a = mbState.balanceAxisSumA or 0
				local b = mbState.balanceAxisSumB or 0
				local diff = a - b
				local tot = a + b
				local balStr
				if tot > 0.001 then
					balStr = string.format("%+.2f (%+.0f%%)", diff, diff / tot * 100)
				else
					balStr = "--"
				end
				if dm.mbAxisBalanceStr ~= balStr then dm.mbAxisBalanceStr = balStr end
			end
		end
		uiState.updatingFromCode = true
		local clRadSlider = doc:GetElementById("mb-slider-cluster-radius")
		if clRadSlider then syncAndFlash(clRadSlider, "mb-cluster-radius", tostring(mbState.clusterRadius or 256)) end
		local axisSlider = doc:GetElementById("mb-slider-axis-angle")
		if axisSlider then syncAndFlash(axisSlider, "mb-axis-angle", tostring(math.floor((mbState.balanceAxisAngleDeg or 0) + 0.5))) end
		uiState.updatingFromCode = false
	end

	if ctx.syncTBMirrorControls then ctx.syncTBMirrorControls(doc, "mb") end
end

return M
