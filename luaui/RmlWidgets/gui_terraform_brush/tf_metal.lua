-- tf_metal.lua: METAL tool controls of the terraform brush panel (attach + per-frame sync).
local M = {}

function M.attach(doc, ctx)
	local widgetState = ctx.widgetState
	local trackSliderDrag = ctx.trackSliderDrag

	widgetState.mbSubmodesEl = doc:GetElementById("tf-metal-submodes")
	widgetState.mbControlsEl = doc:GetElementById("tf-metal-controls")

	-- Drag state needs a listener per slider. The onMbXxx event handlers live in
	-- initialModel in gui_terraform_brush.lua: Recoil forbids adding or replacing
	-- function keys after OpenDataModel.
	for _, entry in ipairs({
		{ "mb-slider-cluster-radius", "mb-cluster-radius" },
		{ "mb-slider-axis-angle", "mb-axis-angle" },
		{ "mb-slider-symmetry-radial-count", "mb-symmetry-radial-count" },
		{ "mb-slider-symmetry-mirror-angle", "mb-symmetry-mirror-angle" },
	}) do
		local sl = doc:GetElementById(entry[1])
		if sl then
			trackSliderDrag(sl, entry[2])
		end
	end
end

function M.sync(doc, ctx, mbState, setSummary)
	local widgetState = ctx.widgetState
	local uiState = ctx.uiState
	local syncAndFlash = ctx.syncAndFlash
	local getCachedEl = ctx.getCachedEl
	local WG = ctx.WG
	local dm = widgetState.dmHandle

	-- DISPLAY / INSTRUMENTS warn chips mirror the shared terraform brush state.
	if doc and ctx.syncWarnChip then
		local tbs = (WG.TerraformBrush and WG.TerraformBrush.getState()) or {}
		local dispActive = tbs.gridOverlay or tbs.heightColormap
		local instActive = tbs.gridSnap or tbs.angleSnap or tbs.measureActive or tbs.symmetryActive
		ctx.syncWarnChip(doc, "warn-chip-mb-overlays", "section-mb-overlays", dispActive)
		ctx.syncWarnChip(doc, "warn-chip-mb-instruments", "section-mb-instruments", instActive)
	end

	if dm then
		local sm = mbState.subMode or "paint"
		if dm.mbSubMode ~= sm then
			dm.mbSubMode = sm
		end
	end

	-- Instrument flags drive the sub-row data-if and chip data-class-active bindings.
	do
		local s = WG.TerraformBrush and WG.TerraformBrush.getState and WG.TerraformBrush.getState()
		if dm and s then
			local setDm = ctx.setDm
			setDm("mbGridSnap", s.gridSnap and true or false)
			setDm("mbAngleSnap", s.angleSnap and true or false)
			setDm("mbMeasureActive", s.measureActive and true or false)
			setDm("mbSymmetryActive", s.symmetryActive and true or false)
			setDm("mbSymmetryRadial", s.symmetryRadial and true or false)
			setDm("mbSymHasAxis", (s.symmetryRadial or s.symmetryMirrorX or s.symmetryMirrorY) and true or false)
			setDm("mbAngleSnapAuto", s.angleSnapAuto and true or false)
			setDm("mbGridOverlay", s.gridOverlay and true or false)
			setDm("mbHeightColormap", s.heightColormap and true or false)
			setDm("mbSymMirrorX", s.symmetryMirrorX and true or false)
			setDm("mbSymMirrorY", s.symmetryMirrorY and true or false)
			setDm("mbMeasureRulerMode", s.measureRulerMode and true or false)
			setDm("mbMeasureStickyMode", s.measureStickyMode and true or false)
			setDm("mbMeasureShowLength", s.measureShowLength and true or false)
		end
	end

	if doc then
		uiState.updatingFromCode = true

		if dm then
			local v = string.format("%.1f", mbState.metalValue)
			if dm.mbValueStr ~= v then
				dm.mbValueStr = v
			end
		end

		do
			-- The value slider is logarithmic: 0..1000 maps to 0.01..50.
			local mv = math.max(0.01, mbState.metalValue)
			local sv = math.floor(1000 * math.log(mv / 0.01) / math.log(50.0 / 0.01) + 0.5)
			syncAndFlash(getCachedEl(doc, "slider-metal-value"), "mb-value", tostring(sv))
		end

		-- Size, rotation, length and curve are shared with the terraform brush.
		local tfSt2 = WG.TerraformBrush and WG.TerraformBrush.getState()
		if tfSt2 then
			if dm then
				local v = tostring(tfSt2.radius)
				if dm.mbSizeStr ~= v then
					dm.mbSizeStr = v
				end
			end
			syncAndFlash(getCachedEl(doc, "slider-mb-size"), "mb-size", tostring(tfSt2.radius))

			if dm then
				local v = tostring(tfSt2.rotationDeg) .. "\194\176"
				if dm.mbRotStr ~= v then
					dm.mbRotStr = v
				end
			end
			syncAndFlash(getCachedEl(doc, "slider-mb-rotation"), "mb-rotation", tostring(tfSt2.rotationDeg))

			if dm then
				local v = string.format("%.1f", tfSt2.lengthScale)
				if dm.mbLengthStr ~= v then
					dm.mbLengthStr = v
				end
			end
			syncAndFlash(
				getCachedEl(doc, "slider-mb-length"),
				"mb-length",
				tostring(math.floor(tfSt2.lengthScale * 10 + 0.5))
			)

			if dm then
				local v = string.format("%.1f", tfSt2.curve)
				if dm.mbCurveStr ~= v then
					dm.mbCurveStr = v
				end
			end
			syncAndFlash(getCachedEl(doc, "slider-mb-curve"), "mb-curve", tostring(math.floor(tfSt2.curve * 10 + 0.5)))
		end
		-- Symmetry sliders only; their labels are set by syncTBMirrorControls.
		local symSt = WG.TerraformBrush and WG.TerraformBrush.getState()
		if symSt then
			syncAndFlash(
				getCachedEl(doc, "mb-slider-symmetry-radial-count"),
				"mb-symmetry-radial-count",
				tostring(symSt.symmetryRadialCount or 2)
			)
			syncAndFlash(
				getCachedEl(doc, "mb-slider-symmetry-mirror-angle"),
				"mb-symmetry-mirror-angle",
				tostring(symSt.symmetryMirrorAngle or 0)
			)
		end

		uiState.updatingFromCode = false
	end

	-- Shape is shared with the terraform brush.
	local tfSt = WG.TerraformBrush and WG.TerraformBrush.getState()
	if tfSt and dm then
		local shp = tfSt.shape or "circle"
		if dm.activeShape ~= shp then
			dm.activeShape = shp
		end
	end

	-- Gray out controls that do nothing in the current submode and shape.
	if doc and tfSt then
		local sm = mbState.subMode or "stamp"
		local circular = (tfSt.shape == "circle")
		local nonStamp = (sm ~= "stamp")
		-- Rotation and length only apply to a non-circular stamp.
		local rotOff = nonStamp or circular
		ctx.setDisabledIds(doc, {
			"slider-mb-rotation",
			"slider-mb-rotation-numbox",
			"btn-mb-rot-ccw",
			"btn-mb-rot-cw",
		}, rotOff)
		ctx.setDisabledIds(doc, {
			"slider-mb-length",
			"slider-mb-length-numbox",
			"btn-mb-length-down",
			"btn-mb-length-up",
		}, rotOff)
		-- Curve (fall-off) only applies to a stamp.
		ctx.setDisabledIds(doc, {
			"slider-mb-curve",
			"slider-mb-curve-numbox",
			"btn-mb-curve-down",
			"btn-mb-curve-up",
		}, nonStamp)
		-- Metal Value stays live in every submode (remove scales its erase rate with it).
		ctx.setDisabledIds(doc, {
			"slider-metal-value",
			"slider-metal-value-numbox",
			"btn-metal-value-down",
			"btn-metal-value-up",
		}, false)
	end

	do
		local tfSt2 = WG.TerraformBrush and WG.TerraformBrush.getState()
		local sm = mbState.subMode or "paint"
		setSummary(
			"METAL",
			"#fdc04c",
			"",
			sm:upper(),
			"R ",
			tostring(tfSt2 and tfSt2.radius or "?"),
			"Val ",
			string.format("%.1f", mbState.metalValue or 0),
			"Crv ",
			string.format("%.1f", tfSt2 and tfSt2.curve or 0)
		)
	end

	-- Map analysis (inspector, cluster counter, lasso, balance axis).
	if doc then
		local inspectorOpen = widgetState.mbInspectorOpen
			or mbState.clusterCounter
			or mbState.lassoActive
			or mbState.lassoClosed
			or mbState.balanceAxisActive
		widgetState.mbInspectorOpen = inspectorOpen and true or false
		if dm then
			local setDm = ctx.setDm
			setDm("mbInspectorOpen", inspectorOpen and true or false)
			setDm("mbClusterOpen", mbState.clusterCounter and true or false)
			setDm("mbLassoOpen", (mbState.lassoActive or mbState.lassoClosed) and true or false)
			setDm("mbAxisOpen", mbState.balanceAxisActive and true or false)
			setDm("mbMapOverlay", mbState.mapOverlay and true or false)
			setDm("mbLassoActive", mbState.lassoActive and true or false)
		end
		if dm then
			local v = tostring(mbState.clusterRadius or 256)
			if dm.mbClusterRadiusStr ~= v then
				dm.mbClusterRadiusStr = v
			end
			v = string.format("%.2f", mbState.lassoTotal or 0)
			if dm.mbLassoTotalStr ~= v then
				dm.mbLassoTotalStr = v
			end
			v = tostring(math.floor((mbState.balanceAxisAngleDeg or 0) + 0.5))
			if dm.mbAxisAngleStr ~= v then
				dm.mbAxisAngleStr = v
			end
			v = string.format("%.2f", mbState.balanceAxisSumA or 0)
			if dm.mbAxisAStr ~= v then
				dm.mbAxisAStr = v
			end
			v = string.format("%.2f", mbState.balanceAxisSumB or 0)
			if dm.mbAxisBStr ~= v then
				dm.mbAxisBStr = v
			end
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
				if dm.mbAxisBalanceStr ~= balStr then
					dm.mbAxisBalanceStr = balStr
				end
			end
		end
		uiState.updatingFromCode = true
		local clRadSlider = getCachedEl(doc, "mb-slider-cluster-radius")
		if clRadSlider then
			syncAndFlash(clRadSlider, "mb-cluster-radius", tostring(mbState.clusterRadius or 256))
		end
		local axisSlider = getCachedEl(doc, "mb-slider-axis-angle")
		if axisSlider then
			syncAndFlash(axisSlider, "mb-axis-angle", tostring(math.floor((mbState.balanceAxisAngleDeg or 0) + 0.5)))
		end
		uiState.updatingFromCode = false
	end

	if ctx.syncTBMirrorControls then
		ctx.syncTBMirrorControls(doc, "mb")
	end
end

return M
