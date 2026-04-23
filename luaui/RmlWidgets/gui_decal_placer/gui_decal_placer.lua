if not RmlUi then
	return
end

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name    = "Decal Placer UI",
		desc    = "RmlUI library panel for the decal placer (terraform brush companion)",
		author  = "BARb",
		date    = "2026",
		license = "GNU GPL, v2 or later",
		layer   = 1,
		enabled = true,
	}
end

local RML_PATH = "luaui/RmlWidgets/gui_decal_placer/gui_decal_placer.rml"
local MODEL_NAME = "decal_placer_model"

local WG = WG
local GetViewGeometry = Spring.GetViewGeometry

local INITIAL_LEFT_VW = 60
local INITIAL_TOP_VH  = 10
local BASE_WIDTH_DP   = 162
local TILE_COLUMNS    = 3
local TILE_GAP_DP     = 2

local widgetState = {
	rmlContext   = nil,
	document     = nil,
	dmHandle     = nil,
	rootElement  = nil,
	-- Logical (dp) width used for tile layout math. Actual rendered width
	-- lives in RCSS (.dp-root) which applies dp_ratio + min-width floor.
	panelWidthDp = BASE_WIDTH_DP,
}

local initialModel = {
	-- Root panel visibility (data-class-hidden on #dp-root)
	hidden = true,
	-- Two-way-bound search filter (data-value on #dp-search)
	search = "",
}

local lastSearchFilter = ""
local activeCategory   = "all"
local categoryButtons  = {}
local decalElements    = {}    -- { [name] = element }
local thumbDivs        = {}    -- { [name] = thumb element }
local manuallyHidden   = false
local lastActive       = false
local lastBuildInnerPx = 0  -- dp-list client_width at last rebuild, for resize detection

local function getDpRatio()
	return (WG.RmlContextManager and WG.RmlContextManager.getDpRatio
		and WG.RmlContextManager.getDpRatio()) or 1.0
end

local function getListInnerPx()
	local doc = widgetState.document
	local listEl = doc and doc:GetElementById("dp-list")
	if listEl then
		local cw = listEl.client_width or 0
		if cw > 0 then return cw, listEl end
	end
	local dpRatio = getDpRatio()
	local pwPx = (widgetState.rootElement and widgetState.rootElement.offset_width) or 0
	if pwPx <= 0 then pwPx = widgetState.panelWidthDp * dpRatio end
	return pwPx - (4 + 4 + 1 + 1) * dpRatio - 12, listEl
end
local userDragged      = false

local DP_SNAP_THRESHOLD = 30
local dpDragState = {
	active = false, rootEl = nil,
	offsetX = 0, offsetY = 0,
	ew = 0, eh = 0,
	vsx = 0, vsy = 0,
	lastX = -1, lastY = -1,
}

-- Per-tile decal texture entries, populated as tiles are built.
-- Each entry: { div = thumbEl, texPath = "string path or engine texture name" }
local thumbOverlays = {}

-- Preview compositing shader (lazy-init on first DrawScreenPost).
local previewShader
local uniMaskMode, uniGround, uniDecalTint
local function initPreviewShader()
	if previewShader ~= nil then return previewShader and true or false end
	previewShader = gl.CreateShader({
		vertex = [[
			#version 150 compatibility
			void main() {
				gl_TexCoord[0] = gl_MultiTexCoord0;
				gl_Position = gl_ProjectionMatrix * gl_ModelViewMatrix * gl_Vertex;
			}
		]],
		fragment = [[
			#version 150 compatibility
			uniform sampler2D tex0;
			uniform int maskMode;     // 0=alpha, 1=green-red, 2=1-red, 3=luminance, -1=raw
			uniform vec3 groundColor;
			uniform vec3 decalTint;
			void main() {
				vec4 c = texture2D(tex0, gl_TexCoord[0].st);
				if (maskMode < 0) {
					gl_FragColor = vec4(c.rgb, 1.0);
					return;
				}
				float mask;
				if (maskMode == 0) {
					mask = c.a;
				} else if (maskMode == 1) {
					// Atlas BMP scars: red is filler, green encodes shape
					mask = clamp(c.g - c.r * 0.5, 0.0, 1.0);
				} else if (maskMode == 2) {
					// Red-filler BMPs (tracks/footprints): dark on red background
					mask = clamp(1.0 - c.r, 0.0, 1.0);
					mask = smoothstep(0.05, 0.6, mask);
				} else {
					// Generic luminance fallback
					mask = dot(c.rgb, vec3(0.299, 0.587, 0.114));
				}
				vec3 scarred = mix(groundColor, decalTint, mask);
				gl_FragColor = vec4(scarred, 1.0);
			}
		]],
		uniformInt   = { tex0 = 0, maskMode = 3 },
		uniformFloat = { groundColor = { 0.42, 0.32, 0.22 }, decalTint = { 0.12, 0.08, 0.06 } },
	})
	if not previewShader or previewShader == 0 then
		Spring.Echo("[DecalPlacer.preview] shader compile failed: " .. tostring(gl.GetShaderLog()))
		previewShader = false
		return false
	end
	uniMaskMode  = gl.GetUniformLocation(previewShader, "maskMode")
	uniGround    = gl.GetUniformLocation(previewShader, "groundColor")
	uniDecalTint = gl.GetUniformLocation(previewShader, "decalTint")
	return true
end

----------------------------------------------------------------
-- Decal preview texture lookup
----------------------------------------------------------------
local previewPaths = {}     -- { [decalName] = filePath or false }
local previewIndexBuilt = false
local fileIndex = {}        -- { [basename_lower] = fullPath }

local function indexDir(path)
	local files = VFS.DirList(path, "*", VFS.RAW_FIRST)
	if not files then return end
	for _, f in ipairs(files) do
		local base = f:match("([^/\\]+)$") or f
		local stem = base:match("^(.+)%.[^%.]+$") or base
		fileIndex[stem:lower()] = f
	end
end

local function buildFileIndex()
	if previewIndexBuilt then return end
	previewIndexBuilt = true
	indexDir("bitmaps/decals/")
	indexDir("bitmaps/scars/")
	indexDir("bitmaps/tracks/")
	indexDir("bitmaps/Other/")
	indexDir("bitmaps/projectiletextures/")
end

local function findPreviewPath(decalName)
	if previewPaths[decalName] ~= nil then return previewPaths[decalName] end
	buildFileIndex()
	local stem = (decalName:match("([^/\\]+)$") or decalName)
	stem = (stem:match("^(.+)%.[^%.]+$") or stem):lower()
	local found = fileIndex[stem]
	previewPaths[decalName] = found or false
	return found
end

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------
local function buildRootStyle()
	-- Width lives in RCSS (.dp-root); we only set position here.
	return string.format("left: %.2fvw; top: %.2fvh;",
		INITIAL_LEFT_VW, INITIAL_TOP_VH)
end

local function setLabel(id, text)
	local el = widgetState.document and widgetState.document:GetElementById(id)
	if el then el.inner_rml = text end
end

local function setSliderValue(id, val)
	local el = widgetState.document and widgetState.document:GetElementById(id)
	if el then el:SetAttribute("value", tostring(val)) end
end

local function getModeButtons()
	local doc = widgetState.document
	if not doc then return nil end
	return {
		scatter = doc:GetElementById("btn-dp-mode-scatter"),
		point   = doc:GetElementById("btn-dp-mode-point"),
		remove  = doc:GetElementById("btn-dp-mode-remove"),
	}
end

local function getShapeButtons()
	local doc = widgetState.document
	if not doc then return nil end
	return {
		circle   = doc:GetElementById("btn-dp-shape-circle"),
		square   = doc:GetElementById("btn-dp-shape-square"),
		hexagon  = doc:GetElementById("btn-dp-shape-hexagon"),
		octagon  = doc:GetElementById("btn-dp-shape-octagon"),
		triangle = doc:GetElementById("btn-dp-shape-triangle"),
	}
end

local function refreshUIFromState()
	if not WG.DecalPlacer then return end
	local state = WG.DecalPlacer.getState()
	if not state then return end

	local mb = getModeButtons()
	if mb then
		for k, el in pairs(mb) do el:SetClass("active", state.mode == k) end
	end
	local sb = getShapeButtons()
	if sb then
		for k, el in pairs(sb) do el:SetClass("active", state.shape == k) end
	end

	setLabel("dp-radius-label",   tostring(state.radius))
	setLabel("dp-rotation-label", tostring(math.floor(state.rotation)) .. "°")
	setLabel("dp-rotrand-label",  tostring(state.rotRandom))
	setLabel("dp-count-label",    tostring(state.decalCount))
	setLabel("dp-cadence-label",  tostring(state.cadence))
	setLabel("dp-sizemin-label",  tostring(state.sizeMin))
	setLabel("dp-sizemax-label",  tostring(state.sizeMax))
	setLabel("dp-alpha-label",    tostring(math.floor(state.alpha * 100)))
	setLabel("dp-tint-r-label",   string.format("%.2f", state.tintR))
	setLabel("dp-tint-g-label",   string.format("%.2f", state.tintG))
	setLabel("dp-tint-b-label",   string.format("%.2f", state.tintB))

	setSliderValue("dp-slider-radius",   state.radius)
	setSliderValue("dp-slider-rotation", math.floor(state.rotation))
	setSliderValue("dp-slider-rotrand",  state.rotRandom)
	setSliderValue("dp-slider-count",    state.decalCount)
	setSliderValue("dp-slider-cadence",  state.cadence)
	setSliderValue("dp-slider-sizemin",  state.sizeMin)
	setSliderValue("dp-slider-sizemax",  state.sizeMax)
	setSliderValue("dp-slider-alpha",    math.floor(state.alpha * 100))
	setSliderValue("dp-slider-tint-r",   math.floor(state.tintR * 100))
	setSliderValue("dp-slider-tint-g",   math.floor(state.tintG * 100))
	setSliderValue("dp-slider-tint-b",   math.floor(state.tintB * 100))

	local doc = widgetState.document
	if doc then
		local cnt = doc:GetElementById("dp-selected-count")
		if cnt then cnt.inner_rml = tostring(#state.selectedDecals) end
		local alignBtn = doc:GetElementById("btn-dp-align-toggle")
		if alignBtn then
			alignBtn:SetAttribute("src", state.alignToNormal
				and "/luaui/images/terraform_brush/check_on.png"
				or  "/luaui/images/terraform_brush/check_off.png")
		end
		local smartBtn = doc:GetElementById("btn-dp-smart-toggle")
		if smartBtn then
			smartBtn:SetAttribute("src", state.smartEnabled
				and "/luaui/images/terraform_brush/check_on.png"
				or  "/luaui/images/terraform_brush/check_off.png")
		end
		local smartOpts = doc:GetElementById("dp-smart-options")
		if smartOpts then smartOpts:SetClass("hidden", not state.smartEnabled) end
		local waterBtn = doc:GetElementById("btn-dp-smart-water")
		if waterBtn then
			waterBtn:SetAttribute("src", state.smartFilters.avoidWater
				and "/luaui/images/terraform_brush/check_on.png"
				or  "/luaui/images/terraform_brush/check_off.png")
		end
		local cliffsBtn = doc:GetElementById("btn-dp-smart-cliffs")
		if cliffsBtn then
			cliffsBtn:SetAttribute("src", state.smartFilters.avoidCliffs
				and "/luaui/images/terraform_brush/check_on.png"
				or  "/luaui/images/terraform_brush/check_off.png")
		end
	end
end

----------------------------------------------------------------
-- Build decal list (tile grid)
----------------------------------------------------------------
local function rebuildDecalList(filter)
	local doc = widgetState.document
	local listEl = doc and doc:GetElementById("dp-list")
	if not listEl or not WG.DecalPlacer then return end

	listEl.inner_rml = ""
	decalElements = {}
	thumbDivs = {}
	thumbOverlays = {}
	_dp_debug_logged = false

	local categories = WG.DecalPlacer.getDecalCategories()
	local order = WG.DecalPlacer.getCategoryOrder()
	if not categories or not order then return end

	local state = WG.DecalPlacer.getState()
	local selectedSet = state and state.selectedSet or {}
	local lowerFilter = filter and filter:lower() or ""
	local cat = activeCategory

	local toShow = {}
	if cat == "all" then
		for _, catName in ipairs(order) do
			local items = categories[catName]
			if items then
				for _, entry in ipairs(items) do toShow[#toShow + 1] = entry end
			end
		end
	else
		local items = categories[cat]
		if items then
			for _, entry in ipairs(items) do toShow[#toShow + 1] = entry end
		end
	end

	-- ALWAYS 3 columns. Real dp-list client_width with safety margin so
	-- flex-wrap never promotes/demotes us due to sub-pixel rounding or a
	-- scrollbar popping in after rebuild.
	local dpRatio = getDpRatio()
	local rawInnerPx = getListInnerPx()
	-- RmlUI client_width includes padding. fp-feature-list has 4dp padding
	-- each side (8dp total) — subtract so tile math uses the real content box.
	-- Always reserve scrollbar (8dp from RCSS) even when not visible yet.
	local innerPx = rawInnerPx - 8 * dpRatio - 8 * dpRatio
	local gapPx = TILE_GAP_DP * dpRatio
	local tileBorderPx = 4 * dpRatio
	local safetyPx = 6 * dpRatio
	local tileW = math.floor((innerPx - (TILE_COLUMNS - 1) * gapPx - TILE_COLUMNS * tileBorderPx - safetyPx) / TILE_COLUMNS)
	if tileW < 24 then tileW = 24 end
	-- Store the RAW getListInnerPx() value for resize comparison in Update();
	-- Update() samples getListInnerPx() unadjusted, so storing the adjusted
	-- innerPx here caused a constant 16dp mismatch → rebuild every frame →
	-- new click listeners overwriting old ones → decal library tiles
	-- impossible to click.
	lastBuildInnerPx = rawInnerPx

	for _, entry in ipairs(toShow) do
		local name = entry.name
		if lowerFilter == "" or name:lower():find(lowerFilter, 1, true) then
			local itemEl = doc:CreateElement("div")
			itemEl:SetClass("fp-feature-item", true)
			itemEl:SetAttribute("style", string.format("width: %dpx; height: %dpx;", tileW, tileW))
			if selectedSet[name] then itemEl:SetClass("selected", true) end

			local thumbEl = doc:CreateElement("div")
			thumbEl:SetClass("fp-feature-thumb", true)
			thumbEl:SetClass("dp-thumb-" .. (entry.category or "other"), true)
			-- Register the tile for GL overlay rendering. We bind the decal's
			-- real texture and draw it via DrawScreen with alpha blending so the
			-- shape shows through against the category-tinted backing.
			local texPath = entry.filename
			if not texPath or texPath == "" then
				texPath = findPreviewPath(name)
			end
			if texPath and texPath ~= "" then
				local tp = texPath:gsub("\\", "/")
				-- gl.Texture wants a VFS path without leading slash
				if tp:sub(1, 1) == "/" then tp = tp:sub(2) end
				-- Choose mask channel heuristically from filename so the preview
				-- can composite the decal shape onto a ground-like background.
				-- 0 = alpha, 1 = green-minus-red, 2 = 1-red (red-filler), 3 = luminance
				-- negative = skip compositing (render raw, used for normal maps).
				local lower = tp:lower()
				local ext = lower:match("%.([^%.]+)$") or ""
				local maskMode = 3
				local isNormal = lower:find("/normscar")
					or lower:find("_normal")
					or lower:find("/normals?/")
				if isNormal then
					maskMode = -1
				elseif ext == "png" or ext == "tga" then
					maskMode = 0
				elseif lower:find("/mainscar") then
					maskMode = 1
				elseif lower:find("tracks") or lower:find("track") or lower:find("footprint") or lower:find("bigfoot") then
					maskMode = 2
				end
				thumbOverlays[name] = {
					div = thumbEl,
					texPath = tp,
					maskMode = maskMode,
				}
			end
			itemEl:AppendChild(thumbEl)
			thumbDivs[name] = thumbEl

			local nameEl = doc:CreateElement("div")
			nameEl:SetClass("fp-feature-name", true)
			-- Trim long names for display
			local displayName = #name > 22 and (name:sub(1, 20) .. "..") or name
			nameEl.inner_rml = displayName
			nameEl:SetAttribute("title", name)
			itemEl:AppendChild(nameEl)

			itemEl:AddEventListener("click", function(event)
				if not WG.DecalPlacer then return end
				local _, _, _, shift = Spring.GetModKeyState()
				if shift then
					WG.DecalPlacer.toggleDecal(name)
				else
					WG.DecalPlacer.selectDecal(name)
				end
				local st = WG.DecalPlacer.getState()
				local ss = st and st.selectedSet or {}
				for n, el in pairs(decalElements) do
					el:SetClass("selected", ss[n] or false)
				end
				local cnt = doc:GetElementById("dp-selected-count")
				if cnt then cnt.inner_rml = tostring(#st.selectedDecals) end
				event:StopPropagation()
			end, false)

			decalElements[name] = itemEl
			listEl:AppendChild(itemEl)
		end
	end
end

----------------------------------------------------------------
-- Slider helper: parse range value, call setter, refresh UI
----------------------------------------------------------------
local function bindSlider(sliderId, numboxId, setter, transform)
	local doc = widgetState.document
	local slider  = doc and doc:GetElementById(sliderId)
	local numbox  = doc and doc:GetElementById(numboxId)
	if not slider then return end
	local function applyFromValue(s)
		local v = tonumber(s)
		if not v then return end
		if transform then v = transform(v) end
		setter(v)
		refreshUIFromState()
	end
	slider:AddEventListener("change", function()
		applyFromValue(slider:GetAttribute("value"))
	end, false)
	if numbox then
		numbox:AddEventListener("focus", function() Spring.SDLStartTextInput() end, false)
		numbox:AddEventListener("blur",  function() Spring.SDLStopTextInput() end, false)
		numbox:AddEventListener("change", function()
			applyFromValue(numbox:GetAttribute("value"))
		end, false)
	end
end

local function bindButton(id, fn)
	local doc = widgetState.document
	local el = doc and doc:GetElementById(id)
	if el then
		el:AddEventListener("click", function(event)
			fn()
			event:StopPropagation()
		end, false)
	end
end

----------------------------------------------------------------
-- Declarative event handlers (called from RML via onclick="widget:Foo()")
----------------------------------------------------------------
function widget:OnQuit()
	manuallyHidden = true
	if widgetState.dmHandle then
		widgetState.dmHandle.hidden = true
	end
end

function widget:OnSearchFocus()
	Spring.SDLStartTextInput()
end

function widget:OnSearchBlur()
	Spring.SDLStopTextInput()
end

function widget:OnSearchClear()
	if widgetState.dmHandle then
		widgetState.dmHandle.search = ""
	end
	lastSearchFilter = ""
	rebuildDecalList("")
end

function widget:OnClearSelection()
	if WG.DecalPlacer then
		WG.DecalPlacer.clearSelectedDecals()
		for _, el in pairs(decalElements) do el:SetClass("selected", false) end
		refreshUIFromState()
	end
end

----------------------------------------------------------------
-- Wire all controls
----------------------------------------------------------------
local function attachEventListeners()
	local doc = widgetState.document
	if not doc then return end

	-- Categories
	local catKeys = { "all", "scars", "explosions", "tracks", "builds", "footprints", "scorch", "groundplates", "other" }
	for _, key in ipairs(catKeys) do
		local btn = doc:GetElementById("btn-dp-cat-" .. key)
		if btn then
			categoryButtons[key] = btn
			btn:AddEventListener("click", function(event)
				activeCategory = key
				for k, el in pairs(categoryButtons) do
					el:SetClass("active", k == key)
				end
				rebuildDecalList(lastSearchFilter)
				event:StopPropagation()
			end, false)
		end
	end

	-- Quit
	-- Quit button click lives in RML (onclick="widget:OnQuit()").

	-- Mode buttons
	local mb = getModeButtons()
	if mb then
		for key, btn in pairs(mb) do
			btn:AddEventListener("click", function(event)
				if WG.DecalPlacer then WG.DecalPlacer.setMode(key) end
				refreshUIFromState()
				event:StopPropagation()
			end, false)
		end
	end

	-- Shape buttons
	local sb = getShapeButtons()
	if sb then
		for key, btn in pairs(sb) do
			btn:AddEventListener("click", function(event)
				if WG.DecalPlacer then WG.DecalPlacer.setShape(key) end
				refreshUIFromState()
				event:StopPropagation()
			end, false)
		end
	end

	-- Search focus/blur/clear + clear selection + search input value all live
	-- declaratively in the RML (data-value="search", onclick, onfocus, onblur).
	-- Only the filter-change → rebuild sync is done from widget:Update().

	-- Sliders
	local DP = WG.DecalPlacer
	if DP then
		bindSlider("dp-slider-radius",   "dp-slider-radius-numbox",   DP.setRadius)
		bindSlider("dp-slider-rotation", "dp-slider-rotation-numbox", DP.setRotation)
		bindSlider("dp-slider-rotrand",  "dp-slider-rotrand-numbox",  DP.setRotRandom)
		bindSlider("dp-slider-count",    "dp-slider-count-numbox",    DP.setDecalCount)
		bindSlider("dp-slider-cadence",  "dp-slider-cadence-numbox",  DP.setCadence)
		bindSlider("dp-slider-sizemin",  "dp-slider-sizemin-numbox",  DP.setSizeMin)
		bindSlider("dp-slider-sizemax",  "dp-slider-sizemax-numbox",  DP.setSizeMax)
		bindSlider("dp-slider-alpha",    "dp-slider-alpha-numbox",    DP.setAlpha, function(v) return v / 100 end)

		-- Tint sliders share helper but call setTint
		local function tintFromUI()
			local s = DP.getState()
			if not s then return 0.5, 0.5, 0.5 end
			local r = doc:GetElementById("dp-slider-tint-r")
			local g = doc:GetElementById("dp-slider-tint-g")
			local b = doc:GetElementById("dp-slider-tint-b")
			local rv = (tonumber(r and r:GetAttribute("value")) or 50) / 100
			local gv = (tonumber(g and g:GetAttribute("value")) or 50) / 100
			local bv = (tonumber(b and b:GetAttribute("value")) or 50) / 100
			return rv, gv, bv
		end
		local function applyTint()
			local r, g, b = tintFromUI()
			DP.setTint(r, g, b, 0.5)
			refreshUIFromState()
		end
		for _, sid in ipairs({"dp-slider-tint-r","dp-slider-tint-g","dp-slider-tint-b"}) do
			local el = doc:GetElementById(sid)
			if el then el:AddEventListener("change", applyTint, false) end
		end
	end

	-- +/- buttons for radius/rotation/rotrand/count/cadence/sizemin/sizemax/alpha
	local function bindStep(btnId, getCur, setter, step)
		bindButton(btnId, function() setter(getCur() + step); refreshUIFromState() end)
	end
	if DP then
		bindStep("btn-dp-radius-down",   function() return DP.getState().radius end,     DP.setRadius,    -8)
		bindStep("btn-dp-radius-up",     function() return DP.getState().radius end,     DP.setRadius,     8)
		bindStep("btn-dp-rot-ccw",       function() return DP.getState().rotation end,   DP.setRotation,  -5)
		bindStep("btn-dp-rot-cw",        function() return DP.getState().rotation end,   DP.setRotation,   5)
		bindStep("btn-dp-rotrand-down",  function() return DP.getState().rotRandom end,  DP.setRotRandom, -5)
		bindStep("btn-dp-rotrand-up",    function() return DP.getState().rotRandom end,  DP.setRotRandom,  5)
		bindStep("btn-dp-count-down",    function() return DP.getState().decalCount end, DP.setDecalCount,-1)
		bindStep("btn-dp-count-up",      function() return DP.getState().decalCount end, DP.setDecalCount, 1)
		bindStep("btn-dp-cadence-down",  function() return DP.getState().cadence end,    DP.setCadence,   -5)
		bindStep("btn-dp-cadence-up",    function() return DP.getState().cadence end,    DP.setCadence,    5)
		bindStep("btn-dp-sizemin-down",  function() return DP.getState().sizeMin end,    DP.setSizeMin,   -4)
		bindStep("btn-dp-sizemin-up",    function() return DP.getState().sizeMin end,    DP.setSizeMin,    4)
		bindStep("btn-dp-sizemax-down",  function() return DP.getState().sizeMax end,    DP.setSizeMax,   -4)
		bindStep("btn-dp-sizemax-up",    function() return DP.getState().sizeMax end,    DP.setSizeMax,    4)
		bindStep("btn-dp-alpha-down",    function() return math.floor(DP.getState().alpha*100) end, function(v) DP.setAlpha(v/100) end, -5)
		bindStep("btn-dp-alpha-up",      function() return math.floor(DP.getState().alpha*100) end, function(v) DP.setAlpha(v/100) end,  5)
	end

	-- Toggles
	bindButton("btn-dp-align-toggle", function()
		local s = WG.DecalPlacer and WG.DecalPlacer.getState()
		if s then WG.DecalPlacer.setAlignToNormal(not s.alignToNormal); refreshUIFromState() end
	end)
	bindButton("btn-dp-smart-toggle", function()
		local s = WG.DecalPlacer and WG.DecalPlacer.getState()
		if s then WG.DecalPlacer.setSmartEnabled(not s.smartEnabled); refreshUIFromState() end
	end)
	bindButton("btn-dp-smart-water", function()
		local s = WG.DecalPlacer and WG.DecalPlacer.getState()
		if s then WG.DecalPlacer.setSmartFilter("avoidWater", not s.smartFilters.avoidWater); refreshUIFromState() end
	end)
	bindButton("btn-dp-smart-cliffs", function()
		local s = WG.DecalPlacer and WG.DecalPlacer.getState()
		if s then WG.DecalPlacer.setSmartFilter("avoidCliffs", not s.smartFilters.avoidCliffs); refreshUIFromState() end
	end)

	-- Action buttons
	bindButton("btn-dp-undo",     function() if WG.DecalPlacer then WG.DecalPlacer.undo()     end end)
	bindButton("btn-dp-clearall", function() if WG.DecalPlacer then WG.DecalPlacer.clearAll() end end)
	bindButton("btn-dp-save",     function() if WG.DecalPlacer then WG.DecalPlacer.save()     end end)
	bindButton("btn-dp-load",     function()
		if not WG.DecalPlacer then return end
		local saves = WG.DecalPlacer.listSaves()
		if not saves or #saves == 0 then Spring.Echo("[Decal Placer] No saved files"); return end
		WG.DecalPlacer.load(saves[#saves])  -- load most recent
		Spring.Echo("[Decal Placer] Loaded " .. saves[#saves])
	end)

	-- Initial population
	rebuildDecalList("")
	refreshUIFromState()

	-- Drag handle
	local handleEl = doc:GetElementById("dp-handle")
	if handleEl and widgetState.rootElement then
		local rootEl = widgetState.rootElement
		local ds = dpDragState
		handleEl:AddEventListener("mousedown", function(event)
			local p = event.parameters
			if not p or (p.button and p.button ~= 0) then return end
			local mx, my = Spring.GetMouseState()
			local vsx, vsy = GetViewGeometry()
			ds.active = true
			userDragged = true
			ds.rootEl = rootEl
			ds.offsetX = mx - rootEl.offset_left
			ds.offsetY = (vsx > 0 and vsy > 0) and ((vsy - my) - rootEl.offset_top) or 0
			ds.ew = rootEl.offset_width
			ds.eh = rootEl.offset_height
			ds.vsx = vsx
			ds.vsy = vsy
			ds.lastX = -1
			ds.lastY = -1
			event:StopPropagation()
		end, false)
		doc:AddEventListener("mouseup", function()
			if ds.active then ds.active = false; ds.rootEl = nil end
		end, false)
	end
end

----------------------------------------------------------------
-- Lifecycle
----------------------------------------------------------------
function widget:Initialize()
	widgetState.rmlContext = RmlUi.GetContext("shared")
	if not widgetState.rmlContext then return false end

	local dm = widgetState.rmlContext:OpenDataModel(MODEL_NAME, initialModel, self)
	if not dm then return false end
	widgetState.dmHandle = dm

	local document = widgetState.rmlContext:LoadDocument(RML_PATH, self)
	if not document then
		widget:Shutdown()
		return false
	end
	widgetState.document = document

	if WG.RmlContextManager and WG.RmlContextManager.registerDocument then
		WG.RmlContextManager.registerDocument("decal_placer", document)
	end
	document:Show()

	widgetState.rootElement = document:GetElementById("dp-root")
	-- hidden state is driven via data-class-hidden; initial model starts hidden.

	widgetState.rootElement:SetAttribute("style", buildRootStyle())

	attachEventListeners()
end

function widget:Update()
	-- Window drag
	local ds = dpDragState
	if ds.active and ds.rootEl then
		local mx, my = Spring.GetMouseState()
		local vsx, vsy = ds.vsx, ds.vsy
		local ew, eh = ds.ew, ds.eh
		local T = DP_SNAP_THRESHOLD
		local rmlY = vsy - my
		local newX = mx - ds.offsetX
		local newY = rmlY - ds.offsetY
		if newX < 0 then newX = 0 elseif newX + ew > vsx then newX = vsx - ew end
		if newY < 0 then newY = 0 elseif newY + eh > vsy then newY = vsy - eh end
		if newX < T then newX = 0 elseif vsx - newX - ew < T then newX = vsx - ew end
		if newY < T then newY = 0 elseif vsy - newY - eh < T then newY = vsy - eh end

		local mainPanel = WG.RmlContextManager and WG.RmlContextManager.getElementRect
			and WG.RmlContextManager.getElementRect("terraform_brush", "tf-root")
		if mainPanel then
			local ox, oy = mainPanel.left, mainPanel.top
			local oR = ox + (mainPanel.width or 0)
			local oB = oy + (mainPanel.height or 0)
			local newR, newB = newX + ew, newY + eh
			if newY < oB and newB > oy then
				local d = newX - oR
				if d > -T and d < T then newX = oR
				else d = newR - ox
					if d > -T and d < T then newX = ox - ew end
				end
			end
			if newX < oR and newR > ox then
				local d = newY - oB
				if d > -T and d < T then newY = oB
				else d = newB - oy
					if d > -T and d < T then newY = oy - eh end
				end
			end
		end

		local ix = math.floor(newX)
		local iy = math.floor(newY)
		if ix ~= ds.lastX or iy ~= ds.lastY then
			ds.lastX = ix; ds.lastY = iy
			ds.rootEl.style.left = ix .. "px"
			ds.rootEl.style.top  = iy .. "px"
		end
	end

	local function setHidden(v)
		if widgetState.dmHandle and widgetState.dmHandle.hidden ~= v then
			widgetState.dmHandle.hidden = v
		end
	end

	if not WG.DecalPlacer then
		setHidden(true)
		return
	end

	local state = WG.DecalPlacer.getState()
	if not state then return end
	local isActive = state.active
	if isActive and not lastActive then manuallyHidden = false end
	lastActive = isActive
	setHidden((not isActive) or manuallyHidden)
	if not isActive then return end

	-- Sync two-way-bound search filter back to internal state
	if widgetState.dmHandle then
		local searchVal = widgetState.dmHandle.search or ""
		if searchVal ~= lastSearchFilter then
			lastSearchFilter = searchVal
			rebuildDecalList(searchVal)
		end
	end

	-- Auto-position next to terraform main panel until user drags
	local mainPanel = WG.RmlContextManager and WG.RmlContextManager.getElementRect
		and WG.RmlContextManager.getElementRect("terraform_brush", "tf-root")
	if not userDragged and mainPanel and widgetState.rootElement then
		local myWidth = widgetState.rootElement.offset_width
		if myWidth and myWidth > 0 then
			local gap = 8
			widgetState.rootElement:SetAttribute("style",
				string.format("left: %dpx; top: %dpx;",
					mainPanel.left - myWidth - gap, mainPanel.top))
		end
	end

	-- Lazy build decal list (Spring.GetGroundDecalTextures may not be ready in Initialize)
	if WG.DecalPlacer and not next(decalElements) then
		local cats = WG.DecalPlacer.getDecalCategories()
		if cats and next(cats) then rebuildDecalList(lastSearchFilter) end
	end

	-- Relayout: if dp-list client_width changed since last rebuild, rebuild
	-- so tile widths re-derive (handles window resize + scrollbar appearance).
	if widgetState.document and next(decalElements) then
		local curInner = getListInnerPx()
		if curInner > 0 and math.abs(curInner - lastBuildInnerPx) >= 2 then
			rebuildDecalList(lastSearchFilter)
		end
	end
end

function widget:Shutdown()
	Spring.SDLStopTextInput()
	if WG.RmlContextManager and WG.RmlContextManager.unregisterDocument then
		WG.RmlContextManager.unregisterDocument("decal_placer")
	end
	if widgetState.document then
		widgetState.document:Close()
		widgetState.document = nil
	end
	if widgetState.rmlContext then
		widgetState.rmlContext:RemoveDataModel(MODEL_NAME)
	end
	widgetState.dmHandle = nil
	widgetState.rootElement = nil
	decalElements = {}
	thumbDivs = {}
	thumbOverlays = {}
	categoryButtons = {}
	activeCategory = "all"
	if previewShader and previewShader ~= false then
		gl.DeleteShader(previewShader)
	end
	previewShader = nil
end

----------------------------------------------------------------
-- DrawScreen: overlay each decal tile with its real texture.
-- RmlUi handles layout/borders/labels; we render the actual image content
-- on top of each thumb div with alpha blending so transparent shape textures
-- (tracks, scars, footprints) display their silhouette rather than raw channel
-- data.
----------------------------------------------------------------
function widget:DrawScreenPost()
	if widgetState.rootElement and widgetState.rootElement:IsClassSet("hidden") then return end
	if not next(thumbOverlays) then return end
	local doc = widgetState.document
	if not doc then return end
	local listEl = doc:GetElementById("dp-list")
	if not listEl then return end
	if not initPreviewShader() then return end

	local vsx, vsy = Spring.GetViewGeometry()

	-- Clip to the scrollable list region so thumbs don't bleed outside on scroll.
	local clipX = listEl.absolute_left
	local clipH = listEl.client_height
	local clipY = vsy - listEl.absolute_top - clipH
	local clipW = listEl.client_width
	if clipW <= 0 or clipH <= 0 then return end

	gl.Scissor(clipX, clipY, clipW, clipH)
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	gl.Color(1, 1, 1, 1)
	gl.UseShader(previewShader)

	for _, entry in pairs(thumbOverlays) do
		local div = entry.div
		local tex = entry.texPath
		if div and tex and not entry.failed then
			local x = div.absolute_left
			local y = div.absolute_top
			local w = div.offset_width
			local h = div.offset_height
			if w > 0 and h > 0 then
				-- Skip tiles scrolled outside the list viewport
				if y + h > listEl.absolute_top - 4 and y < listEl.absolute_top + clipH + 4 then
					local ok = gl.Texture(0, tex)
					if ok then
						if uniMaskMode then
							gl.Uniform(uniMaskMode, entry.maskMode or 3)
						end
						local glY2 = vsy - y
						local glY1 = vsy - y - h
						gl.TexRect(x, glY1, x + w, glY2, 0, 0, 1, 1)
					else
						entry.failed = true
					end
				end
			end
		end
	end

	gl.UseShader(0)
	gl.Texture(0, false)
	gl.Scissor(false)
	gl.Blending(true)
	gl.Color(1, 1, 1, 1)
end
