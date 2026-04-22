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

	widgetState.dcControlsEl  = doc:GetElementById("tf-decal-controls")
	widgetState.dcSubmodesEl  = doc:GetElementById("tf-dc-submodes")

	-- Decal distribution buttons
	widgetState.dcDistButtons.random    = doc:GetElementById("btn-dc-dist-random")
	widgetState.dcDistButtons.regular   = doc:GetElementById("btn-dc-dist-regular")
	widgetState.dcDistButtons.clustered = doc:GetElementById("btn-dc-dist-clustered")

	for dist, element in pairs(widgetState.dcDistButtons) do
		if element then
			element:AddEventListener("click", function(event)
				playSound("shapeSwitch")
				if WG.DecalPainter then WG.DecalPainter.setDistribution(dist) end
				setActiveClass(widgetState.dcDistButtons, dist)
				event:StopPropagation()
			end, false)
		end
	end

	-- ============ Decal Heatmap buttons ============
	do
		local function dcHeatClick(btnId, actionFn)
			local btn = doc:GetElementById(btnId)
			if btn then
				btn:AddEventListener("click", function(event)
					playSound("tick")
					actionFn()
					event:StopPropagation()
				end, false)
			end
		end

		dcHeatClick("btn-dc-heatmap-export", function()
			if WG.DecalExporter then
				WG.DecalExporter.exportHeatmapCSV()
				WG.DecalExporter.exportHeatmapPGM()
			else
				Spring.Echo("[Decal Heatmap] Enable the 'Decal Exporter & Analytics' widget first")
			end
		end)

		dcHeatClick("btn-dc-heatmap-reset", function()
			if WG.DecalExporter then
				WG.DecalExporter.resetHeatmap()
				Spring.Echo("[Decal Heatmap] Heatmap reset")
			end
		end)
	end

	-- ============ Decal Library buttons ============
	do
		local function dcLibClick(btnId, fn)
			local btn = doc:GetElementById(btnId)
			if btn then
				btn:AddEventListener("click", function(event)
					playSound("tick")
					fn()
					event:StopPropagation()
				end, false)
			end
		end
		local function ensureDecalPlacer()
			if not WG.DecalPlacer then
				Spring.Echo("[Decal Library] Enable the 'Decal Placer' widget first")
				return false
			end
			return true
		end
		dcLibClick("btn-dc-library-scatter", function()
			if ensureDecalPlacer() then WG.DecalPlacer.setMode("scatter") end
		end)
		dcLibClick("btn-dc-library-point", function()
			if ensureDecalPlacer() then WG.DecalPlacer.setMode("point") end
		end)
		dcLibClick("btn-dc-library-remove", function()
			if ensureDecalPlacer() then WG.DecalPlacer.setMode("remove") end
		end)
		dcLibClick("btn-dc-library-stop", function()
			if WG.DecalPlacer then WG.DecalPlacer.deactivate() end
		end)
		dcLibClick("btn-dc-library-open", function()
			if ensureDecalPlacer() then
				local s = WG.DecalPlacer.getState()
				if not s or not s.active then
					WG.DecalPlacer.setMode("point")
				end
			end
		end)

		-- Brush / decal option sliders + action buttons (dc-*)
		local function bindDCSlider(sliderId, numboxId, setter, transform)
			local slider = doc:GetElementById(sliderId)
			local numbox = doc:GetElementById(numboxId)
			if not slider then return end
			local function applyFromValue(s)
				local v = tonumber(s); if not v then return end
				if transform then v = transform(v) end
				setter(v)
			end
			slider:AddEventListener("change", function()
				applyFromValue(slider:GetAttribute("value"))
			end, false)
			if numbox then
				numbox:AddEventListener("focus", function() Spring.SDLStartTextInput(); widgetState.focusedRmlInput = numbox end, false)
				numbox:AddEventListener("blur",  function() Spring.SDLStopTextInput(); widgetState.focusedRmlInput = nil end, false)
				numbox:AddEventListener("change", function()
					applyFromValue(numbox:GetAttribute("value"))
				end, false)
			end
		end
		local function bindDCStep(btnId, getCur, setter, step)
			local btn = doc:GetElementById(btnId)
			if btn then
				btn:AddEventListener("click", function(event)
					playSound("tick")
					setter(getCur() + step)
					event:StopPropagation()
				end, false)
			end
		end
		local DP = WG.DecalPlacer
		if DP then
			bindDCSlider("dc-slider-radius",   "dc-slider-radius-numbox",   DP.setRadius)
			bindDCSlider("dc-slider-rotation", "dc-slider-rotation-numbox", DP.setRotation)
			bindDCSlider("dc-slider-rotrand",  "dc-slider-rotrand-numbox",  DP.setRotRandom)
			bindDCSlider("dc-slider-count",    "dc-slider-count-numbox",    DP.setDecalCount)
			bindDCSlider("dc-slider-cadence",  "dc-slider-cadence-numbox",  DP.setCadence)
			bindDCSlider("dc-slider-sizemin",  "dc-slider-sizemin-numbox",  DP.setSizeMin)
			bindDCSlider("dc-slider-sizemax",  "dc-slider-sizemax-numbox",  DP.setSizeMax)
			bindDCSlider("dc-slider-alpha",    "dc-slider-alpha-numbox",    DP.setAlpha, function(v) return v/100 end)

			bindDCStep("btn-dc-radius-down",  function() return DP.getState().radius end,     DP.setRadius,    -8)
			bindDCStep("btn-dc-radius-up",    function() return DP.getState().radius end,     DP.setRadius,     8)
			bindDCStep("btn-dc-rot-ccw",      function() return DP.getState().rotation end,   DP.setRotation,  -5)
			bindDCStep("btn-dc-rot-cw",       function() return DP.getState().rotation end,   DP.setRotation,   5)
			bindDCStep("btn-dc-count-down",   function() return DP.getState().decalCount end, DP.setDecalCount,-1)
			bindDCStep("btn-dc-count-up",     function() return DP.getState().decalCount end, DP.setDecalCount, 1)
			bindDCStep("btn-dc-cadence-down",  function() return DP.getState().cadence end,    DP.setCadence,    -5)
			bindDCStep("btn-dc-cadence-up",    function() return DP.getState().cadence end,    DP.setCadence,     5)
			bindDCStep("btn-dc-rotrand-down",  function() return DP.getState().rotRandom end,  DP.setRotRandom,  -1)
			bindDCStep("btn-dc-rotrand-up",    function() return DP.getState().rotRandom end,  DP.setRotRandom,   1)
			bindDCStep("btn-dc-sizemin-down",  function() return DP.getState().sizeMin end,    DP.setSizeMin,    -4)
			bindDCStep("btn-dc-sizemin-up",    function() return DP.getState().sizeMin end,    DP.setSizeMin,     4)
			bindDCStep("btn-dc-sizemax-down",  function() return DP.getState().sizeMax end,    DP.setSizeMax,    -4)
			bindDCStep("btn-dc-sizemax-up",    function() return DP.getState().sizeMax end,    DP.setSizeMax,     4)
			bindDCStep("btn-dc-alpha-down",    function() return DP.getState().alpha*100 end,  function(v) DP.setAlpha(v/100) end, -1)
			bindDCStep("btn-dc-alpha-up",      function() return DP.getState().alpha*100 end,  function(v) DP.setAlpha(v/100) end,  1)
		end
		dcLibClick("btn-dc-align-toggle", function()
			if DP then
				local s = DP.getState()
				if s then DP.setAlignToNormal(not s.alignToNormal) end
			end
		end)
		-- Decal undo/redo section (undo only — DC has no redo backend)
		local dcUndoBtn = doc:GetElementById("btn-dc-undo")
		if dcUndoBtn then
			dcUndoBtn:AddEventListener("click", function(event)
				if DP then playSound("undo"); DP.undo() end
				event:StopPropagation()
			end, false)
		end
		-- Redo button: no-op (DC redo not implemented)
		local dcRedoBtn = doc:GetElementById("btn-dc-redo")
		if dcRedoBtn then
			dcRedoBtn:AddEventListener("click", function(event)
				event:StopPropagation()
			end, false)
		end
		local sliderDcHistory = doc:GetElementById("slider-dc-history")
		if sliderDcHistory then
			trackSliderDrag(sliderDcHistory, "dc-history")
			sliderDcHistory:AddEventListener("change", function(event)
				if uiState.updatingFromCode then event:StopPropagation(); return end
				if not DP then event:StopPropagation(); return end
				local val = tonumber(sliderDcHistory:GetAttribute("value")) or 0
				local dcSt = DP.getState()
				if not dcSt then event:StopPropagation(); return end
				local cur = dcSt.undoCount or 0
				local diff = val - cur
				if diff < 0 then
					for i = 1, -diff do DP.undo() end
				end
				event:StopPropagation()
			end, false)
		end
		dcLibClick("btn-dc-clearall", function() if DP then DP.clearAll() end end)
		dcLibClick("btn-dc-save",     function() if DP then DP.save()     end end)
		dcLibClick("btn-dc-load",     function()
			if not DP then return end
			local saves = DP.listSaves()
			if not saves or #saves == 0 then Spring.Echo("[Decal Placer] No saved files"); return end
			DP.load(saves[#saves])
			Spring.Echo("[Decal Placer] Loaded " .. saves[#saves])
		end)
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

			-- Sync brush/option labels & sliders
			local function setLbl(id, txt)
				local e = doc and doc:GetElementById(id)
				if e then e.inner_rml = tostring(txt) end
			end
			local function setSlider(id, val)
				local e = doc and doc:GetElementById(id)
				if e then e:SetAttribute("value", tostring(val)) end
			end
			setLbl("dc-radius-label",   dpState.radius or 0)
			setLbl("dc-rotation-label", math.floor(dpState.rotation or 0))
			setLbl("dc-rotrand-label",  dpState.rotRandom or 0)
			setLbl("dc-count-label",    dpState.decalCount or 0)
			setLbl("dc-cadence-label",  dpState.cadence or 0)
			setLbl("dc-sizemin-label",  dpState.sizeMin or 0)
			setLbl("dc-sizemax-label",  dpState.sizeMax or 0)
			setLbl("dc-alpha-label",    math.floor((dpState.alpha or 0) * 100))
			setSlider("dc-slider-radius",   dpState.radius or 0)
			setSlider("dc-slider-rotation", math.floor(dpState.rotation or 0))
			setSlider("dc-slider-rotrand",  dpState.rotRandom or 0)
			setSlider("dc-slider-count",    dpState.decalCount or 0)
			setSlider("dc-slider-cadence",  dpState.cadence or 0)
			setSlider("dc-slider-sizemin",  dpState.sizeMin or 0)
			setSlider("dc-slider-sizemax",  dpState.sizeMax or 0)
			setSlider("dc-slider-alpha",    math.floor((dpState.alpha or 0) * 100))
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
					"dc-slider-rotation", "dc-slider-rotrand",
					"dc-btn-rot-ccw", "dc-btn-rot-cw",
				}, remove)
				-- Count/cadence/distribution: scatter only
				ctx.setDisabledIds(doc, {
					"dc-slider-count", "dc-slider-cadence",
					"dc-btn-count-down", "dc-btn-count-up",
					"dc-btn-cadence-down", "dc-btn-cadence-up",
					"dc-btn-dist-random", "dc-btn-dist-regular", "dc-btn-dist-clustered",
				}, not scatter)
				-- Size/alpha/align: irrelevant in remove
				ctx.setDisabledIds(doc, {
					"dc-slider-sizemin", "dc-slider-sizemax",
					"dc-slider-alpha",
					"btn-dc-align-toggle",
				}, remove)
			end
		else
			setSummary("DECALS", "#e060e0", "", "LIBRARY", "", "", "", "")
		end

end

return M
