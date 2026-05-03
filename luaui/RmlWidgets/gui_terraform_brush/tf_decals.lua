-- tf_decals.lua: extracted tool module for gui_terraform_brush
local M = {}

function M.attach(doc, ctx)
	if ctx.attachTBMirrorControls then ctx.attachTBMirrorControls(doc, "dc") end
	local widgetState = ctx.widgetState
	local trackSliderDrag = ctx.trackSliderDrag

	widgetState.dcControlsEl  = doc:GetElementById("tf-decal-controls")
	widgetState.dcSubmodesEl  = doc:GetElementById("tf-dc-submodes")

	-- Slider drag tracking (legitimate imperative: slider-specific drag state).
	-- Slider change events are wired declaratively via data-event-change= in RML.
	for _, sid in ipairs({
		"radius", "rotation", "rotrand", "count", "cadence",
		"sizemin", "sizemax", "alpha",
	}) do
		local sl = doc:GetElementById("dc-slider-" .. sid)
		if sl then trackSliderDrag(sl, "dc-" .. sid) end
	end
	local sliderDcHistory = doc:GetElementById("slider-dc-history")
	if sliderDcHistory then trackSliderDrag(sliderDcHistory, "dc-history") end

	-- All data-event-click/change handlers (onDcXxx) are defined in initialModel
	-- in gui_terraform_brush.lua — Recoil forbids adding or replacing function
	-- keys in a DataModel after OpenDataModel.
end

function M.sync(doc, ctx, setSummary)
	if ctx.syncTBMirrorControls then ctx.syncTBMirrorControls(doc, "dc") end
	local widgetState = ctx.widgetState
	local uiState = ctx.uiState
	local WG = ctx.WG
	local syncAndFlash = ctx.syncAndFlash
	local cadenceToSlider = ctx.cadenceToSlider
	local shapeNames = ctx.shapeNames
		-- btn-decals active state driven by data-class-active="activeTool == 'dc'" in RML.

		local dpState = WG.DecalPlacer and WG.DecalPlacer.getState()
		if dpState then
			setSummary("DECALS", "#e060e0",
				"", (dpState.mode or "idle"):upper(),
				"R ", tostring(dpState.radius or 0),
				"Sel ", tostring(#(dpState.selectedDecals or {})))

			uiState.updatingFromCode = true

			-- Sync brush/option labels, sliders, and numboxes.
			-- syncAndFlash guards against writing while user is dragging a slider,
			-- which prevents visual choppiness from the setter ↔ sync loop.
			local function setLbl(id, txt)
				local e = doc and doc:GetElementById(id)
				if e then e.inner_rml = tostring(txt) end
			end
			local function setNum(id, val)
				local e = doc and doc:GetElementById(id)
				if e then e:SetAttribute("value", tostring(val)) end
			end
			local radiusV   = tostring(dpState.radius or 0)
			local rotV      = tostring(math.floor(dpState.rotation or 0))
			local rotRandV  = tostring(dpState.rotRandom or 0)
			local countV    = tostring(dpState.decalCount or 0)
			local cadenceV  = tostring(dpState.cadence or 0)
			local sizeMinV  = tostring(dpState.sizeMin or 0)
			local sizeMaxV  = tostring(dpState.sizeMax or 0)
			local alphaV    = tostring(math.floor((dpState.alpha or 0) * 100))
			setLbl("dc-radius-label",   dpState.radius or 0)
			setLbl("dc-rotation-label", math.floor(dpState.rotation or 0))
			setLbl("dc-rotrand-label",  dpState.rotRandom or 0)
			setLbl("dc-count-label",    dpState.decalCount or 0)
			setLbl("dc-cadence-label",  dpState.cadence or 0)
			setLbl("dc-sizemin-label",  dpState.sizeMin or 0)
			setLbl("dc-sizemax-label",  dpState.sizeMax or 0)
			setLbl("dc-alpha-label",    math.floor((dpState.alpha or 0) * 100))
			syncAndFlash(doc:GetElementById("dc-slider-radius"),   "dc-radius",   radiusV)
			syncAndFlash(doc:GetElementById("dc-slider-rotation"), "dc-rotation", rotV)
			syncAndFlash(doc:GetElementById("dc-slider-rotrand"),  "dc-rotrand",  rotRandV)
			syncAndFlash(doc:GetElementById("dc-slider-count"),    "dc-count",    countV)
			syncAndFlash(doc:GetElementById("dc-slider-cadence"),  "dc-cadence",  cadenceV)
			syncAndFlash(doc:GetElementById("dc-slider-sizemin"),  "dc-sizemin",  sizeMinV)
			syncAndFlash(doc:GetElementById("dc-slider-sizemax"),  "dc-sizemax",  sizeMaxV)
			syncAndFlash(doc:GetElementById("dc-slider-alpha"),    "dc-alpha",    alphaV)
			setNum("dc-slider-radius-numbox",   radiusV)
			setNum("dc-slider-rotation-numbox", rotV)
			setNum("dc-slider-rotrand-numbox",  rotRandV)
			setNum("dc-slider-count-numbox",    countV)
			setNum("dc-slider-cadence-numbox",  cadenceV)
			setNum("dc-slider-sizemin-numbox",  sizeMinV)
			setNum("dc-slider-sizemax-numbox",  sizeMaxV)
			setNum("dc-slider-alpha-numbox",    alphaV)
			-- Mode row active highlight (data-class-active="dcLibMode == 'X'" in RML)
			-- and distribution row (data-class-active="dcDistribution == 'X'")
			local dm = widgetState.dmHandle
			if dm then
				local m = dpState.mode or ""
				if dm.dcLibMode ~= m then dm.dcLibMode = m end
				local d = dpState.distribution or "random"
				if dm.dcDistribution ~= d then dm.dcDistribution = d end
			end
			-- Align toggle icon
			local alignBtn = doc and doc:GetElementById("btn-dc-align-toggle")
			if alignBtn then
				alignBtn:SetAttribute("src", dpState.alignToNormal
					and "/luaui/images/terraform_brush/check_on.png"
					or  "/luaui/images/terraform_brush/check_off.png")
			end
			-- DC undo history slider
			local dcUndoCnt = dpState.undoCount or 0
			local slDcHist = doc and doc:GetElementById("slider-dc-history")
			local nbDcHist = doc and doc:GetElementById("slider-dc-history-numbox")
			if slDcHist and uiState.draggingSlider ~= "dc-history" then
				local dcMax = math.max(dcUndoCnt, 1)
				slDcHist:SetAttribute("max",   tostring(dcMax))
				slDcHist:SetAttribute("value", tostring(dcUndoCnt))
			end
			if nbDcHist then nbDcHist:SetAttribute("value", tostring(dcUndoCnt)) end

			-- P3.2 Decals grayouts (per Phase 3 relevance matrix)
			if ctx.setDisabledIds then
				local mode = dpState.mode or "scatter"
				local remove = (mode == "remove")
				local scatter = (mode == "scatter")
				-- Rotation + random irrelevant in remove mode
				ctx.setDisabledIds(doc, {
					"dc-slider-rotation", "dc-slider-rotation-numbox",
					"dc-slider-rotrand",  "dc-slider-rotrand-numbox",
					"btn-dc-rot-ccw", "btn-dc-rot-cw",
					"btn-dc-rotrand-down", "btn-dc-rotrand-up",
				}, remove)
				-- Count + distribution: scatter only (point places exactly 1 per tick)
				ctx.setDisabledIds(doc, {
					"dc-slider-count",   "dc-slider-count-numbox",
					"btn-dc-count-down", "btn-dc-count-up",
					"btn-dc-dist-random", "btn-dc-dist-regular", "btn-dc-dist-clustered",
				}, not scatter)
				-- Cadence: applies in BOTH scatter and point drag (widget:Update spam).
				-- Only irrelevant in remove (which places every frame while dragging).
				ctx.setDisabledIds(doc, {
					"dc-slider-cadence", "dc-slider-cadence-numbox",
					"btn-dc-cadence-down", "btn-dc-cadence-up",
				}, remove)
				-- Size/alpha/align: irrelevant in remove
				ctx.setDisabledIds(doc, {
					"dc-slider-sizemin", "dc-slider-sizemin-numbox",
					"dc-slider-sizemax", "dc-slider-sizemax-numbox",
					"dc-slider-alpha",   "dc-slider-alpha-numbox",
					"btn-dc-sizemin-down", "btn-dc-sizemin-up",
					"btn-dc-sizemax-down", "btn-dc-sizemax-up",
					"btn-dc-alpha-down",   "btn-dc-alpha-up",
					"btn-dc-align-toggle",
				}, remove)
			end

			uiState.updatingFromCode = false
		else
			setSummary("DECALS", "#e060e0", "", "LIBRARY", "", "", "", "")
		end

end

return M
