-- tf_decals.lua: extracted tool module for gui_terraform_brush
local M = {}

function M.attach(doc, ctx)
	if ctx.attachTBMirrorControls then ctx.attachTBMirrorControls(doc, "dc") end
	local widgetState = ctx.widgetState
	local uiState = ctx.uiState
	local WG = ctx.WG
	local playSound = ctx.playSound
	local setActiveClass = ctx.setActiveClass
	local trackSliderDrag = ctx.trackSliderDrag

	widgetState.dcControlsEl  = doc:GetElementById("tf-decal-controls")
	widgetState.dcSubmodesEl  = doc:GetElementById("tf-dc-submodes")

	-- Cache distribution / mode button elements (used by setActiveClass in M.sync).
	widgetState.dcDistButtons.random    = doc:GetElementById("btn-dc-dist-random")
	widgetState.dcDistButtons.regular   = doc:GetElementById("btn-dc-dist-regular")
	widgetState.dcDistButtons.clustered = doc:GetElementById("btn-dc-dist-clustered")

	-- Slider drag tracking (legitimate imperative: slider-specific drag state).
	-- Slider change events are wired declaratively via onchange= in RML.
	for _, sid in ipairs({
		"radius", "rotation", "rotrand", "count", "cadence",
		"sizemin", "sizemax", "alpha",
	}) do
		local sl = doc:GetElementById("dc-slider-" .. sid)
		if sl then trackSliderDrag(sl, "dc-" .. sid) end
	end
	local sliderDcHistory = doc:GetElementById("slider-dc-history")
	if sliderDcHistory then trackSliderDrag(sliderDcHistory, "dc-history") end

	-- Register widget methods for inline onclick/onchange handlers in RML.
	local w = ctx.widget
	if not w then return end

	local function ensureDecalPlacer()
		if not WG.DecalPlacer then
			Spring.Echo("[Decal Library] Enable the 'Decal Placer' widget first")
			return false
		end
		return true
	end

	-- Distribution
	w.dcSetDist = function(self, dist)
		playSound("shapeSwitch")
		if WG.DecalPainter then WG.DecalPainter.setDistribution(dist) end
		setActiveClass(widgetState.dcDistButtons, dist)
	end

	-- Heatmap
	w.dcHeatmapExport = function(self)
		playSound("tick")
		if WG.DecalExporter then
			WG.DecalExporter.exportHeatmapCSV()
			WG.DecalExporter.exportHeatmapPGM()
		else
			Spring.Echo("[Decal Heatmap] Enable the 'Decal Exporter & Analytics' widget first")
		end
	end
	w.dcHeatmapReset = function(self)
		playSound("tick")
		if WG.DecalExporter then
			WG.DecalExporter.resetHeatmap()
			Spring.Echo("[Decal Heatmap] Heatmap reset")
		end
	end

	-- Library mode buttons
	w.dcLibScatter = function(self)
		playSound("tick")
		if ensureDecalPlacer() then WG.DecalPlacer.setMode("scatter") end
	end
	w.dcLibPoint = function(self)
		playSound("tick")
		if ensureDecalPlacer() then WG.DecalPlacer.setMode("point") end
	end
	w.dcLibRemove = function(self)
		playSound("tick")
		if ensureDecalPlacer() then WG.DecalPlacer.setMode("remove") end
	end
	w.dcLibStop = function(self)
		playSound("tick")
		if WG.DecalPlacer then WG.DecalPlacer.deactivate() end
	end
	w.dcLibOpen = function(self)
		playSound("tick")
		if ensureDecalPlacer() then
			local s = WG.DecalPlacer.getState()
			if not s or not s.active then
				WG.DecalPlacer.setMode("point")
			end
		end
	end

	-- Slider/numbox onchange helpers (transform optional).
	local function dcSliderChange(element, setter, transform)
		if uiState.updatingFromCode or not WG.DecalPlacer then return end
		local v = element and tonumber(element:GetAttribute("value"))
		if not v then return end
		if transform then v = transform(v) end
		setter(v)
	end

	w.dcOnRadiusChange   = function(self, e) dcSliderChange(e, WG.DecalPlacer and WG.DecalPlacer.setRadius     or function() end) end
	w.dcOnRotationChange = function(self, e) dcSliderChange(e, WG.DecalPlacer and WG.DecalPlacer.setRotation   or function() end) end
	w.dcOnRotRandChange  = function(self, e) dcSliderChange(e, WG.DecalPlacer and WG.DecalPlacer.setRotRandom  or function() end) end
	w.dcOnCountChange    = function(self, e) dcSliderChange(e, WG.DecalPlacer and WG.DecalPlacer.setDecalCount or function() end) end
	w.dcOnCadenceChange  = function(self, e) dcSliderChange(e, WG.DecalPlacer and WG.DecalPlacer.setCadence    or function() end) end
	w.dcOnSizeMinChange  = function(self, e) dcSliderChange(e, WG.DecalPlacer and WG.DecalPlacer.setSizeMin    or function() end) end
	w.dcOnSizeMaxChange  = function(self, e) dcSliderChange(e, WG.DecalPlacer and WG.DecalPlacer.setSizeMax    or function() end) end
	w.dcOnAlphaChange    = function(self, e)
		if not WG.DecalPlacer then return end
		dcSliderChange(e, WG.DecalPlacer.setAlpha, function(v) return v / 100 end)
	end

	-- Stepper buttons (re-fetch state on each click; safe if DecalPlacer enabled later).
	local function dcStep(getter, setter, delta)
		if not WG.DecalPlacer then return end
		local st = WG.DecalPlacer.getState()
		if not st then return end
		setter(getter(st) + delta)
	end

	w.dcRadiusDown   = function(self) playSound("tick"); dcStep(function(s) return s.radius     end, WG.DecalPlacer and WG.DecalPlacer.setRadius     or function() end, -8) end
	w.dcRadiusUp     = function(self) playSound("tick"); dcStep(function(s) return s.radius     end, WG.DecalPlacer and WG.DecalPlacer.setRadius     or function() end,  8) end
	w.dcRotCCW       = function(self) playSound("tick"); dcStep(function(s) return s.rotation   end, WG.DecalPlacer and WG.DecalPlacer.setRotation   or function() end, -5) end
	w.dcRotCW        = function(self) playSound("tick"); dcStep(function(s) return s.rotation   end, WG.DecalPlacer and WG.DecalPlacer.setRotation   or function() end,  5) end
	w.dcRotRandDown  = function(self) playSound("tick"); dcStep(function(s) return s.rotRandom  end, WG.DecalPlacer and WG.DecalPlacer.setRotRandom  or function() end, -1) end
	w.dcRotRandUp    = function(self) playSound("tick"); dcStep(function(s) return s.rotRandom  end, WG.DecalPlacer and WG.DecalPlacer.setRotRandom  or function() end,  1) end
	w.dcCountDown    = function(self) playSound("tick"); dcStep(function(s) return s.decalCount end, WG.DecalPlacer and WG.DecalPlacer.setDecalCount or function() end, -1) end
	w.dcCountUp      = function(self) playSound("tick"); dcStep(function(s) return s.decalCount end, WG.DecalPlacer and WG.DecalPlacer.setDecalCount or function() end,  1) end
	w.dcCadenceDown  = function(self) playSound("tick"); dcStep(function(s) return s.cadence    end, WG.DecalPlacer and WG.DecalPlacer.setCadence    or function() end, -5) end
	w.dcCadenceUp    = function(self) playSound("tick"); dcStep(function(s) return s.cadence    end, WG.DecalPlacer and WG.DecalPlacer.setCadence    or function() end,  5) end
	w.dcSizeMinDown  = function(self) playSound("tick"); dcStep(function(s) return s.sizeMin    end, WG.DecalPlacer and WG.DecalPlacer.setSizeMin    or function() end, -4) end
	w.dcSizeMinUp    = function(self) playSound("tick"); dcStep(function(s) return s.sizeMin    end, WG.DecalPlacer and WG.DecalPlacer.setSizeMin    or function() end,  4) end
	w.dcSizeMaxDown  = function(self) playSound("tick"); dcStep(function(s) return s.sizeMax    end, WG.DecalPlacer and WG.DecalPlacer.setSizeMax    or function() end, -4) end
	w.dcSizeMaxUp    = function(self) playSound("tick"); dcStep(function(s) return s.sizeMax    end, WG.DecalPlacer and WG.DecalPlacer.setSizeMax    or function() end,  4) end
	w.dcAlphaDown    = function(self)
		playSound("tick")
		if not WG.DecalPlacer then return end
		local st = WG.DecalPlacer.getState(); if not st then return end
		WG.DecalPlacer.setAlpha(math.max(0, ((st.alpha or 0) * 100 - 1) / 100))
	end
	w.dcAlphaUp      = function(self)
		playSound("tick")
		if not WG.DecalPlacer then return end
		local st = WG.DecalPlacer.getState(); if not st then return end
		WG.DecalPlacer.setAlpha(math.min(1, ((st.alpha or 0) * 100 + 1) / 100))
	end

	-- Align-to-normal toggle
	w.dcAlignToggle = function(self)
		playSound("tick")
		if not WG.DecalPlacer then return end
		local s = WG.DecalPlacer.getState()
		if s then WG.DecalPlacer.setAlignToNormal(not s.alignToNormal) end
	end

	-- Undo / Redo (DC has no redo backend; redo is a no-op stub)
	w.dcUndo = function(self)
		if WG.DecalPlacer then playSound("undo"); WG.DecalPlacer.undo() end
	end
	w.dcRedo = function(self)
		-- placeholder; DC redo not implemented
	end
	w.dcOnHistoryChange = function(self, element)
		if uiState.updatingFromCode or not WG.DecalPlacer then return end
		local val = element and tonumber(element:GetAttribute("value")) or 0
		local dcSt = WG.DecalPlacer.getState()
		if not dcSt then return end
		local cur = dcSt.undoCount or 0
		local diff = val - cur
		if diff < 0 then
			for _ = 1, -diff do WG.DecalPlacer.undo() end
		end
	end

	-- Save / Load / Clear
	w.dcClearAll = function(self)
		playSound("tick")
		if WG.DecalPlacer then WG.DecalPlacer.clearAll() end
	end
	w.dcSave = function(self)
		playSound("tick")
		if WG.DecalPlacer then WG.DecalPlacer.save() end
	end
	w.dcLoad = function(self)
		playSound("tick")
		if not WG.DecalPlacer then return end
		local saves = WG.DecalPlacer.listSaves()
		if not saves or #saves == 0 then
			Spring.Echo("[Decal Placer] No saved files"); return
		end
		WG.DecalPlacer.load(saves[#saves])
		Spring.Echo("[Decal Placer] Loaded " .. saves[#saves])
	end
end

function M.sync(doc, ctx, setSummary)
	if ctx.syncTBMirrorControls then ctx.syncTBMirrorControls(doc, "dc") end
	local widgetState = ctx.widgetState
	local uiState = ctx.uiState
	local WG = ctx.WG
	local setActiveClass = ctx.setActiveClass
	local syncAndFlash = ctx.syncAndFlash
	local cadenceToSlider = ctx.cadenceToSlider
	local shapeNames = ctx.shapeNames
		-- ===== Decals mode: highlight decals button =====
		local decalsBtnA = doc and doc:GetElementById("btn-decals")
		if decalsBtnA then decalsBtnA:SetClass("active", true) end
		setActiveClass(widgetState.modeButtons, nil)
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
			-- Mode row active highlight
			local modes = { scatter = "btn-dc-library-scatter", point = "btn-dc-library-point", remove = "btn-dc-library-remove" }
			for m, id in pairs(modes) do
				local b = doc and doc:GetElementById(id)
				if b then b:SetClass("active", dpState.mode == m) end
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
