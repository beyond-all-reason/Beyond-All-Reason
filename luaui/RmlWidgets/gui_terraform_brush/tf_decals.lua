-- tf_decals.lua: decal tool wiring for the gui_terraform_brush panel
local M = {}

function M.attach(doc, ctx)
	local trackSliderDrag = ctx.trackSliderDrag

	-- Drag tracking only; slider change events are wired in the RML (data-event-change).
	for _, sid in ipairs({
		"radius",
		"rotation",
		"rotrand",
		"count",
		"cadence",
		"sizemin",
		"sizemax",
		"alpha",
	}) do
		local sl = doc:GetElementById("dc-slider-" .. sid)
		if sl then
			trackSliderDrag(sl, "dc-" .. sid)
		end
	end
	local sliderDcHistory = doc:GetElementById("slider-dc-history")
	if sliderDcHistory then
		trackSliderDrag(sliderDcHistory, "dc-history")
	end

	-- The onDcXxx handlers live in initialModel (gui_terraform_brush.lua): Recoil
	-- forbids adding function keys to a DataModel after OpenDataModel.
end

function M.sync(doc, ctx, setSummary)
	if ctx.syncTBMirrorControls then
		ctx.syncTBMirrorControls(doc, "dc")
	end
	local widgetState = ctx.widgetState
	local uiState = ctx.uiState
	local WG = ctx.WG
	local syncAndFlash = ctx.syncAndFlash
	-- btn-decals active state comes from data-class-active in the RML.

	local dpState = WG.DecalPlacer and WG.DecalPlacer.getState()
	if dpState then
		-- Six groups like the other tools: the strip is a space-evenly flex
		-- row, so a sparse line floats off the left edge instead of aligning.
		setSummary(
			"DECALS",
			"#fdc04c",
			"",
			(dpState.mode or "idle"):upper(),
			"R ",
			tostring(dpState.radius or 0),
			"Rot ",
			tostring(math.floor(dpState.rotation or 0)),
			"Cnt ",
			tostring(dpState.decalCount or 0),
			"Sel ",
			tostring(#(dpState.selectedDecals or {}))
		)

		uiState.updatingFromCode = true

		-- syncAndFlash skips a slider being dragged, so the setter and the sync do not
		-- fight over its value.
		local getCachedEl = ctx.getCachedEl
		local function setLbl(id, txt)
			ctx.setInnerRmlIfChanged(doc and getCachedEl(doc, id), id, tostring(txt))
		end
		local function setNum(id, val)
			local e = doc and getCachedEl(doc, id)
			if e then
				e:SetAttribute("value", tostring(val))
			end
		end
		local radiusV = tostring(dpState.radius or 0)
		local rotV = tostring(math.floor(dpState.rotation or 0))
		local rotRandV = tostring(dpState.rotRandom or 0)
		local countV = tostring(dpState.decalCount or 0)
		local cadenceV = tostring(dpState.cadence or 0)
		local sizeMinV = tostring(dpState.sizeMin or 0)
		local sizeMaxV = tostring(dpState.sizeMax or 0)
		local alphaV = tostring(math.floor((dpState.alpha or 0) * 100))
		setLbl("dc-radius-label", dpState.radius or 0)
		setLbl("dc-rotation-label", math.floor(dpState.rotation or 0))
		setLbl("dc-rotrand-label", dpState.rotRandom or 0)
		setLbl("dc-count-label", dpState.decalCount or 0)
		setLbl("dc-cadence-label", dpState.cadence or 0)
		setLbl("dc-sizemin-label", dpState.sizeMin or 0)
		setLbl("dc-sizemax-label", dpState.sizeMax or 0)
		setLbl("dc-alpha-label", math.floor((dpState.alpha or 0) * 100))
		syncAndFlash(getCachedEl(doc, "dc-slider-radius"), "dc-radius", radiusV)
		syncAndFlash(getCachedEl(doc, "dc-slider-rotation"), "dc-rotation", rotV)
		syncAndFlash(getCachedEl(doc, "dc-slider-rotrand"), "dc-rotrand", rotRandV)
		syncAndFlash(getCachedEl(doc, "dc-slider-count"), "dc-count", countV)
		syncAndFlash(getCachedEl(doc, "dc-slider-cadence"), "dc-cadence", cadenceV)
		syncAndFlash(getCachedEl(doc, "dc-slider-sizemin"), "dc-sizemin", sizeMinV)
		syncAndFlash(getCachedEl(doc, "dc-slider-sizemax"), "dc-sizemax", sizeMaxV)
		syncAndFlash(getCachedEl(doc, "dc-slider-alpha"), "dc-alpha", alphaV)
		setNum("dc-slider-radius-numbox", radiusV)
		setNum("dc-slider-rotation-numbox", rotV)
		setNum("dc-slider-rotrand-numbox", rotRandV)
		setNum("dc-slider-count-numbox", countV)
		setNum("dc-slider-cadence-numbox", cadenceV)
		setNum("dc-slider-sizemin-numbox", sizeMinV)
		setNum("dc-slider-sizemax-numbox", sizeMaxV)
		setNum("dc-slider-alpha-numbox", alphaV)
		-- Mode row active highlight (data-class-active="dcLibMode == 'X'" in RML)
		local dm = widgetState.dmHandle
		if dm then
			local m = dpState.mode or ""
			if dm.dcLibMode ~= m then
				dm.dcLibMode = m
			end
		end
		-- Align toggle icon
		local alignBtn = doc and getCachedEl(doc, "btn-dc-align-toggle")
		if alignBtn then
			alignBtn:SetAttribute(
				"src",
				dpState.alignToNormal and "/luaui/images/terraform_brush/check_on.png"
					or "/luaui/images/terraform_brush/check_off.png"
			)
		end
		-- Undo history slider
		local dcUndoCnt = dpState.undoCount or 0
		local slDcHist = doc and getCachedEl(doc, "slider-dc-history")
		local nbDcHist = doc and getCachedEl(doc, "slider-dc-history-numbox")
		if slDcHist and uiState.draggingSlider ~= "dc-history" then
			---@type number
			local dcMax = math.max(dcUndoCnt + (dpState.redoCount or 0), 1)
			slDcHist:SetAttribute("max", tostring(dcMax))
			slDcHist:SetAttribute("value", tostring(dcUndoCnt))
		end
		if nbDcHist then
			nbDcHist:SetAttribute("value", tostring(dcUndoCnt))
		end

		-- Grey out controls that do nothing in the current mode
		if ctx.setDisabledIds then
			local mode = dpState.mode or "scatter"
			local remove = (mode == "remove")
			local scatter = (mode == "scatter")
			-- Rotation + random irrelevant in remove mode
			ctx.setDisabledIds(doc, {
				"dc-slider-rotation",
				"dc-slider-rotation-numbox",
				"dc-slider-rotrand",
				"dc-slider-rotrand-numbox",
				"btn-dc-rot-ccw",
				"btn-dc-rot-cw",
				"btn-dc-rotrand-down",
				"btn-dc-rotrand-up",
			}, remove)
			-- Count: scatter only (point places exactly 1 per tick)
			ctx.setDisabledIds(doc, {
				"dc-slider-count",
				"dc-slider-count-numbox",
				"btn-dc-count-down",
				"btn-dc-count-up",
			}, not scatter)
			-- Cadence paces both scatter and point drags. Remove ignores it: it runs on
			-- every update tick while dragging.
			ctx.setDisabledIds(doc, {
				"dc-slider-cadence",
				"dc-slider-cadence-numbox",
				"btn-dc-cadence-down",
				"btn-dc-cadence-up",
			}, remove)
			-- Size/alpha/align: irrelevant in remove
			ctx.setDisabledIds(doc, {
				"dc-slider-sizemin",
				"dc-slider-sizemin-numbox",
				"dc-slider-sizemax",
				"dc-slider-sizemax-numbox",
				"dc-slider-alpha",
				"dc-slider-alpha-numbox",
				"btn-dc-sizemin-down",
				"btn-dc-sizemin-up",
				"btn-dc-sizemax-down",
				"btn-dc-sizemax-up",
				"btn-dc-alpha-down",
				"btn-dc-alpha-up",
				"btn-dc-align-toggle",
			}, remove)
		end

		uiState.updatingFromCode = false
	else
		setSummary("DECALS", "#fdc04c", "", "LIBRARY")
	end
end

return M
