if not RmlUi then
	return
end

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name    = "Feature Placer UI",
		desc    = "RmlUI asset library panel for feature placer",
		author  = "BARb",
		date    = "2026",
		license = "GNU GPL, v2 or later",
		layer   = 1,
		enabled = true,
	}
end

local RML_PATH = "luaui/RmlWidgets/gui_feature_placer/gui_feature_placer.rml"
local MODEL_NAME = "feature_placer_model"

local WG = WG
local GetViewGeometry = Spring.GetViewGeometry

local INITIAL_LEFT_VW   = 60
local INITIAL_TOP_VH    = 10
local BASE_WIDTH_DP     = 220
local TILE_COLUMNS      = 3
local TILE_GAP_DP       = 2

local widgetState = {
	rmlContext   = nil,
	document     = nil,
	dmHandle     = nil,
	rootElement  = nil,
	-- Logical (dp) width used for tile layout math. Rendered width lives
	-- in RCSS (.fp-root) via dp + min-width.
	panelWidthDp = BASE_WIDTH_DP,
}

local initialModel = {
	-- Root panel visibility (data-class-hidden on #fp-root)
	hidden = true,
	-- Two-way-bound search filter (data-value on #feature-search)
	search = "",
}

local lastSearchFilter = ""
local activeCategory   = "all"
local categoryButtons  = {} -- { [catKey] = element }
local featureElements  = {} -- { [defName] = element }
local thumbDivs        = {} -- { [defName] = div element }
local manuallyHidden   = false
local lastActive       = false
local userDragged      = false  -- once user drags, stop auto-positioning



----------------------------------------------------------------
-- Thumbnail generation state (in-memory GL textures)
----------------------------------------------------------------
local THUMB_SIZE = 128
local THUMBS_PER_FRAME = 3
local GL_DEPTH_COMPONENT24 = 0x81A6
local GL_COLOR_ATTACHMENT0_EXT = 0x8CE0

local thumbTextures = {}   -- { [defName] = glTexture }
local thumbQueue = {}
local thumbQueueIdx = 0
local thumbTotal = 0
local thumbDone = 0
local thumbGenerating = false
local thumbGenAttempted = false
local thumbRefreshTimer = 0
local needsListRefresh = false
local depthTex  -- shared depth buffer for rendering

local function buildRootStyle()
	-- Width lives in RCSS (.fp-root); we only set position here.
	return string.format("left: %.2fvw; top: %.2fvh;",
		INITIAL_LEFT_VW, INITIAL_TOP_VH)
end

local function getDpRatio()
	return (WG.RmlContextManager and WG.RmlContextManager.getDpRatio
		and WG.RmlContextManager.getDpRatio()) or 1.0
end

----------------------------------------------------------------
-- Thumbnail generation (render feature models to GL textures)
----------------------------------------------------------------
local thumbShader

local function initThumbShader()
	if thumbShader then return true end
	-- Model transform goes through TextureMatrix[0]; no UV-packed AO (rocks don't use that convention)
	thumbShader = gl.CreateShader({
		vertex = [[
			#version 150 compatibility
			varying vec3 normal;
			varying vec4 pos;
			void main() {
				gl_FrontColor = gl_Color;
				gl_TexCoord[0] = gl_MultiTexCoord0;
				// Rotate normal by the same view rotation applied to the vertex
				normal = mat3(gl_TextureMatrix[0]) * gl_Normal;
				pos = gl_ModelViewMatrix * gl_Vertex;
				gl_Position = gl_ProjectionMatrix * (gl_TextureMatrix[0] * pos);
			}
		]],
		fragment = [[
			#version 150 compatibility
			uniform sampler2D tex0;
			varying vec3 normal;
			void main() {
				vec4 color = texture2D(tex0, gl_TexCoord[0].st);
				// In s3o models, alpha = team color mix factor (NOT transparency)
				vec3 albedo = mix(color.rgb, gl_Color.rgb, color.a);
				vec3 n = normalize(normal);
				// Three-point lighting for thumbnail clarity
				vec3 keyDir  = normalize(vec3(0.35, 0.75, 0.55));  // upper-right key
				vec3 fillDir = normalize(vec3(-0.5, 0.3, -0.4));   // left fill
				vec3 rimDir  = normalize(vec3(0.0, 0.2, -1.0));    // back rim
				float key  = max(dot(n, keyDir), 0.0);
				float fill = max(dot(n, fillDir), 0.0);
				float rim  = pow(max(1.0 - max(dot(n, vec3(0.0, 0.0, 1.0)), 0.0), 0.0), 2.5) * 0.35;
				float lighting = 0.38 + 0.48 * key + 0.18 * fill + rim;
				gl_FragColor = vec4(albedo * lighting, 1.0);
			}
		]],
		uniformInt = { tex0 = 0 },
	})
	if not thumbShader or thumbShader == 0 then
		Spring.Echo("[Feature Placer UI] Failed to create thumbnail shader: " .. tostring(gl.GetShaderLog()))
		thumbShader = nil
		return false
	end
	return true
end
local function initSharedDepth()
	if depthTex then return true end
	depthTex = gl.CreateTexture(THUMB_SIZE, THUMB_SIZE, {
		border = false,
		format = GL_DEPTH_COMPONENT24,
		min_filter = GL.NEAREST,
		mag_filter = GL.NEAREST,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
	})
	if not depthTex then
		Spring.Echo("[Feature Placer UI] Failed to create shared depth texture")
		return false
	end
	return true
end

local function cleanupThumbs()
	for _, tex in pairs(thumbTextures) do
		gl.DeleteTexture(tex)
	end
	thumbTextures = {}
	if depthTex then gl.DeleteTexture(depthTex); depthTex = nil end
	if thumbShader then gl.DeleteShader(thumbShader); thumbShader = nil end
end

local function renderOneThumb(name, defID)
	local def = FeatureDefs[defID]
	if not def then return false end
	-- Check if this feature has a 3D model (runtime field is .modelpath)
	if (def.modelpath or "") == "" then return false end

	-- Ensure the model geometry is loaded into GPU memory
	Spring.PreloadFeatureDefModel(defID)

	-- Compute bounding box from model dimensions for proper framing
	local midX, midY, midZ = 0, 0, 0
	local radius
	local m = def.model
	if m and m.minx and m.maxx then
		midX = (m.maxx + m.minx) * 0.5
		midY = (math.max(0, m.maxy or 0) + math.max(0, m.miny or 0)) * 0.5
		midZ = (m.maxz + m.minz) * 0.5
		local ax = math.max(math.abs(m.maxx - midX), math.abs(m.minx - midX))
		local ay = math.max(math.abs((m.maxy or 0) - midY), math.abs((m.miny or 0) - midY))
		local az = math.max(math.abs(m.maxz - midZ), math.abs(m.minz - midZ))
		radius = math.sqrt(ax * ax + ay * ay + az * az)
	end
	-- Fallback: if model bounds not available, use collision radius
	if not radius or radius < 1 then
		radius = (def.radius or 20) * 0.8
	end
	radius = math.max(radius, 5) * 1.25

	-- Create a texture for this feature
	local colorTex = gl.CreateTexture(THUMB_SIZE, THUMB_SIZE, {
		border = false,
		min_filter = GL.LINEAR,
		mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
		fbo = true,
	})
	if not colorTex then return false end

	local fbo = gl.CreateFBO({
		color0 = colorTex,
		depth  = depthTex,
		drawbuffers = { GL_COLOR_ATTACHMENT0_EXT },
	})
	if not fbo or not gl.IsValidFBO(fbo) then
		gl.DeleteTexture(colorTex)
		if fbo then gl.DeleteFBO(fbo) end
		return false
	end

	local vsx, vsy = Spring.GetViewGeometry()

	gl.ActiveFBO(fbo, function()
		gl.Viewport(0, 0, THUMB_SIZE, THUMB_SIZE)

		gl.DepthMask(true)
		gl.Clear(GL.COLOR_BUFFER_BIT, 0.08, 0.08, 0.12, 1)
		gl.Clear(GL.DEPTH_BUFFER_BIT, 1)

		gl.Blending(false)
		gl.DepthTest(true)
		gl.DepthMask(true)

		-- PROJECTION matrix: orthographic view
		gl.MatrixMode(GL.PROJECTION)
		gl.PushMatrix()
		gl.LoadIdentity()
		gl.Ortho(-radius, radius, -radius, radius, -radius * 4, radius * 4)

		-- TEXTURE matrix: model transform (matches unit_icongenerator pattern)
		-- Spring's shape rendering uses TextureMatrix[0] for transforms when rawState=true
		gl.ActiveTexture(0, gl.MatrixMode, GL.TEXTURE)
		gl.PushMatrix()
		gl.LoadIdentity()
		gl.Rotate(-30, 1, 0, 0)
		gl.Rotate(45, 0, 1, 0)
		gl.Translate(-midX, -midY, -midZ)

		-- MODELVIEW matrix: identity
		gl.MatrixMode(GL.MODELVIEW)
		gl.PushMatrix()
		gl.LoadIdentity()

		-- Set vertex color to white so the shader's gl_Color is defined
		gl.Color(1, 1, 1, 1)

		-- Render with custom shader + engine texture push/pop
		gl.UseShader(thumbShader)
		gl.FeatureShapeTextures(defID, true)
		gl.FeatureShape(defID, 0, true, false, true)
		-- Alpha pass
		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
		gl.FeatureShape(defID, 0, true, false, false)
		gl.Blending(false)
		gl.FeatureShapeTextures(defID, false)
		gl.UseShader(0)

		-- Restore all matrices in reverse order
		gl.ActiveTexture(0, gl.MatrixMode, GL.TEXTURE)
		gl.PopMatrix()
		gl.MatrixMode(GL.PROJECTION)
		gl.PopMatrix()
		gl.MatrixMode(GL.MODELVIEW)
		gl.PopMatrix()

		gl.DepthMask(false)
		gl.DepthTest(false)

		gl.Viewport(0, 0, vsx, vsy)
	end)

	gl.Blending(true)
	gl.DeleteFBO(fbo)
	thumbTextures[name] = colorTex
	return true
end

local function startThumbGeneration()
	if thumbGenAttempted then return end
	if not WG.FeaturePlacer then return end
	thumbGenAttempted = true

	local categories = WG.FeaturePlacer.getFeatureCategories()
	local order = WG.FeaturePlacer.getCategoryOrder()
	if not categories or not order then return end

	thumbQueue = {}
	thumbQueueIdx = 1

	for _, catName in ipairs(order) do
		local items = categories[catName]
		if items then
			for _, entry in ipairs(items) do
				if not thumbTextures[entry.name] then
					thumbQueue[#thumbQueue + 1] = { name = entry.name, defID = entry.id }
				end
			end
		end
	end

	thumbTotal = #thumbQueue
	thumbDone = 0

	if thumbTotal == 0 then
		needsListRefresh = true
		return
	end

	thumbGenerating = true
	Spring.Echo("[Feature Placer UI] Generating " .. thumbTotal .. " thumbnails...")
end

local function processThumbQueue()
	if not thumbGenerating then return end
	if not initThumbShader() then
		thumbGenerating = false
		return
	end
	if not depthTex then
		if not initSharedDepth() then
			thumbGenerating = false
			return
		end
	end

	local processed = 0
	while thumbQueueIdx <= #thumbQueue and processed < THUMBS_PER_FRAME do
		local item = thumbQueue[thumbQueueIdx]
		thumbQueueIdx = thumbQueueIdx + 1
		renderOneThumb(item.name, item.defID)
		thumbDone = thumbDone + 1
		processed = processed + 1
	end

	if thumbQueueIdx > #thumbQueue then
		thumbGenerating = false
		needsListRefresh = true
		Spring.Echo("[Feature Placer UI] Thumbnails complete (" .. thumbDone .. "/" .. thumbTotal .. ")")
	end
end

local function invalidateThumbCache()
	-- no-op; kept for call-site compatibility
end

local function drawThumbnailOverlays()
	local doc = widgetState.document
	if not doc then return end
	if not next(thumbTextures) then return end

	if widgetState.rootElement and widgetState.rootElement:IsClassSet("hidden") then return end

	local listEl = doc:GetElementById("feature-list")
	if not listEl then return end

	local vsx, vsy = Spring.GetViewGeometry()

	-- Scissor clip to the feature list scroll area
	local clipX = listEl.absolute_left
	local clipH = listEl.client_height
	local clipY = vsy - listEl.absolute_top - clipH
	local clipW = listEl.client_width

	gl.Scissor(clipX, clipY, clipW, clipH)
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)

	-- thumbDivs now only contains visible items (virtualized), so iterate all
	for name, div in pairs(thumbDivs) do
		local tex = thumbTextures[name]
		if tex then
			local x = div.absolute_left
			local y = div.absolute_top
			local w = div.offset_width
			local h = div.offset_height

			if w > 0 and h > 0 then
				local glY2 = vsy - y
				local glY1 = vsy - y - h

				gl.Color(1, 1, 1, 1)
				gl.Texture(0, tex)
				gl.TexRect(x, glY1, x + w, glY2, 0, 0, 1, 1)
			end
		end
	end

	gl.Texture(0, false)
	gl.Scissor(false)
	gl.Blending(true)
	gl.Color(1, 1, 1, 1)
end

----------------------------------------------------------------
-- Asset library: build categorized feature list
----------------------------------------------------------------
local function updateSelectedCount()
	local doc = widgetState.document
	if not doc then return end
	local el = doc:GetElementById("selected-count")
	if el and WG.FeaturePlacer then
		local state = WG.FeaturePlacer.getState()
		local n = state and #state.selectedDefs or 0
		el.inner_rml = tostring(n)
	end
end

----------------------------------------------------------------
-- Virtual list: only create DOM elements for visible items.
-- The full filtered data lives in virtualItems; DOM is rebuilt
-- on scroll / filter / category change for the visible window.
----------------------------------------------------------------
local virtualItems = {}       -- flat array of { name=..., id=..., category=... }
local virtualTileW = 32       -- computed tile width (dp)
local virtualTileH = 32       -- computed tile height (includes name bar)
local virtualRowH  = 0        -- tile height + gap in px (computed after first layout)
local virtualScrollTop = -1   -- last known scroll_top
local virtualTopSpacer = nil  -- spacer div for items above viewport
local virtualBotSpacer = nil  -- spacer div for items below viewport
local virtualVisStart = 0     -- first visible index (0-based)
local virtualVisEnd   = 0     -- last visible index (exclusive)
local measuredRowHeightPx = 0 -- actual rendered tile row height in px (measured after first render)
local lastBuildInnerPx = 0    -- client_width of feature-list at last rebuild, for resize detection

local function getListInnerPx()
	local listEl = widgetState.document and widgetState.document:GetElementById("feature-list")
	if listEl then
		local cw = listEl.client_width or 0
		if cw > 0 then return cw, listEl end
	end
	local dpRatio = getDpRatio()
	local pwPx = (widgetState.rootElement and widgetState.rootElement.offset_width) or 0
	if pwPx <= 0 then pwPx = widgetState.panelWidthDp * dpRatio end
	-- list has padding: 4dp each side + border: 1dp each side + ~12px scrollbar
	return pwPx - (4 + 4 + 1 + 1) * dpRatio - 12, listEl
end

local function computeTileWidth()
	-- ALWAYS 3 columns. Work from the list element's actual client_width
	-- (content area; excludes padding/border/scrollbar) and err on the side
	-- of slightly-too-small tiles so flex-wrap never promotes us to 4 or
	-- demotes us to 2 due to sub-pixel rounding or a scrollbar that pops in
	-- after the rebuild.
	local dpRatio = getDpRatio()
	local innerPx = getListInnerPx()
	-- Always reserve scrollbar (8dp from RCSS) even when it isn't currently
	-- visible, so the layout doesn't collapse to 2 cols when the user scrolls
	-- and the scrollbar pops in.
	innerPx = innerPx - 8 * dpRatio
	local gapPx = TILE_GAP_DP * dpRatio
	local tileBorderPx = 4 * dpRatio  -- per-tile border: 2dp each side
	local safetyPx = 6 * dpRatio       -- fudge against sub-pixel rounding
	local tileW = math.floor((innerPx - (TILE_COLUMNS - 1) * gapPx - TILE_COLUMNS * tileBorderPx - safetyPx) / TILE_COLUMNS)
	if tileW < 24 then tileW = 24 end
	return tileW
end

local function createTileElement(doc, entry, tileW, selectedSet)
	local name = entry.name
	local itemEl = doc:CreateElement("div")
	itemEl:SetClass("fp-feature-item", true)
	itemEl:SetAttribute("style", string.format("width: %dpx; height: %dpx;", tileW, tileW))
	if selectedSet[name] then
		itemEl:SetClass("selected", true)
	end

	local thumbEl = doc:CreateElement("div")
	thumbEl:SetClass("fp-feature-thumb", true)
	thumbEl:SetClass("fp-thumb-" .. (entry.category or "other"), true)
	itemEl:AppendChild(thumbEl)
	thumbDivs[name] = thumbEl

	local nameEl = doc:CreateElement("div")
	nameEl:SetClass("fp-feature-name", true)
	nameEl.inner_rml = name
	itemEl:AppendChild(nameEl)

	itemEl:AddEventListener("click", function(event)
		if not WG.FeaturePlacer then return end
		local _, _, _, shift = Spring.GetModKeyState()
		if shift then
			WG.FeaturePlacer.toggleFeature(name)
		else
			WG.FeaturePlacer.selectFeature(name)
		end
		local st = WG.FeaturePlacer.getState()
		local ss = st and st.selectedSet or {}
		for n, el in pairs(featureElements) do
			el:SetClass("selected", ss[n] or false)
		end
		updateSelectedCount()
		event:StopPropagation()
	end, false)

	featureElements[name] = itemEl
	return itemEl
end

-- Render only the visible window of tiles into the DOM
local function renderVirtualWindow(listEl, doc, startIdx, endIdx, selectedSet)
	-- Remove old content
	listEl.inner_rml = ""
	featureElements = {}
	thumbDivs = {}
	invalidateThumbCache()

	local tileW = virtualTileW
	local totalItems = #virtualItems

	-- Compute row height in PX. Prefer the measured value from a prior render,
	-- since CSS borders/gaps make the real rendered height differ from tileW+gap dp.
	-- Falls back to dp estimate for the very first render (startIdx=0, topSpacer=0 so exact value doesn't matter yet).
	local dpRatio = getDpRatio()
	local rowHeightPx = measuredRowHeightPx
	if rowHeightPx < 1 then
		rowHeightPx = tileW + TILE_GAP_DP * dpRatio
	end

	-- Top spacer: accounts for all rows above startIdx (sized in px for exact match to real tile row height)
	local topRows = math.floor(startIdx / TILE_COLUMNS)
	virtualTopSpacer = doc:CreateElement("div")
	virtualTopSpacer:SetAttribute("style", string.format(
		"width: 100%%; height: %dpx; flex-shrink: 0;", math.floor(topRows * rowHeightPx + 0.5)))
	listEl:AppendChild(virtualTopSpacer)

	-- Create visible tiles
	local firstItemEl
	for i = startIdx + 1, math.min(endIdx, totalItems) do
		local entry = virtualItems[i]
		local itemEl = createTileElement(doc, entry, tileW, selectedSet)
		listEl:AppendChild(itemEl)
		if not firstItemEl then firstItemEl = itemEl end
	end

	-- Bottom spacer: accounts for all rows below endIdx
	local bottomItems = math.max(0, totalItems - endIdx)
	local bottomRows = math.ceil(bottomItems / TILE_COLUMNS)
	virtualBotSpacer = doc:CreateElement("div")
	virtualBotSpacer:SetAttribute("style", string.format(
		"width: 100%%; height: %dpx; flex-shrink: 0;", math.floor(bottomRows * rowHeightPx + 0.5)))
	listEl:AppendChild(virtualBotSpacer)

	virtualVisStart = startIdx
	virtualVisEnd = endIdx

	-- Calibrate measured row height from the first rendered tile so subsequent
	-- renders (and scroll math) use the actual pixel size including border+gap.
	if firstItemEl then
		local h = firstItemEl.offset_height
		if h and h > 0 then
			local gapPx = TILE_GAP_DP * dpRatio
			measuredRowHeightPx = h + gapPx
		end
	end
end

local function updateVirtualWindow()
	local doc = widgetState.document
	local listEl = doc and doc:GetElementById("feature-list")
	if not listEl or #virtualItems == 0 then return end

	local scrollTop = listEl.scroll_top or 0
	local viewH = listEl.client_height or 500

	local tileW = virtualTileW
	-- Prefer the measured pixel row height (accurate, includes border+gap); fall back to dp estimate.
	local rowHeightPx = measuredRowHeightPx
	if rowHeightPx < 1 then
		local dpRatio = getDpRatio()
		rowHeightPx = tileW + TILE_GAP_DP * dpRatio
	end

	if rowHeightPx < 1 then rowHeightPx = 40 end

	local firstVisRow = math.max(0, math.floor(scrollTop / rowHeightPx) - 2)  -- 2 row buffer
	local visibleRows = math.ceil(viewH / rowHeightPx) + 4  -- 4 row buffer total
	local startIdx = firstVisRow * TILE_COLUMNS
	local endIdx = math.min(#virtualItems, (firstVisRow + visibleRows) * TILE_COLUMNS)

	-- Only rebuild DOM if the visible window actually changed
	if startIdx == virtualVisStart and endIdx == virtualVisEnd then return end

	local state = WG.FeaturePlacer and WG.FeaturePlacer.getState()
	local selectedSet = state and state.selectedSet or {}
	renderVirtualWindow(listEl, doc, startIdx, endIdx, selectedSet)
end

local function rebuildFeatureList(filter)
	local doc = widgetState.document
	local listEl = doc and doc:GetElementById("feature-list")
	if not listEl or not WG.FeaturePlacer then return end

	listEl.inner_rml = ""
	featureElements = {}
	thumbDivs = {}
	invalidateThumbCache()
	virtualItems = {}
	virtualVisStart = 0
	virtualVisEnd = 0
	virtualScrollTop = -1

	-- Loading indicator during thumbnail generation
	if thumbGenerating and thumbTotal > 0 then
		local loadEl = doc:CreateElement("div")
		loadEl:SetClass("fp-loading-bar", true)
		local pct = math.floor(thumbDone / thumbTotal * 100)
		local fillEl = doc:CreateElement("div")
		fillEl:SetClass("fp-loading-fill", true)
		fillEl:SetAttribute("style", "width: " .. pct .. "%;")
		loadEl:AppendChild(fillEl)
		local labelEl = doc:CreateElement("span")
		labelEl:SetClass("fp-loading-label", true)
		labelEl.inner_rml = "Loading thumbnails " .. pct .. "%"
		loadEl:AppendChild(labelEl)
		listEl:AppendChild(loadEl)
	end

	local categories = WG.FeaturePlacer.getFeatureCategories()
	local order = WG.FeaturePlacer.getCategoryOrder()
	if not categories or not order then return end

	local state = WG.FeaturePlacer.getState()
	local selectedSet = state and state.selectedSet or {}
	local lowerFilter = filter and filter:lower() or ""
	local cat = activeCategory

	-- Build flat filtered list
	local toShow = {}
	if cat == "all" then
		for _, catName in ipairs(order) do
			local items = categories[catName]
			if items then
				for _, entry in ipairs(items) do
					toShow[#toShow + 1] = entry
				end
			end
		end
	else
		local items = categories[cat]
		if items then
			for _, entry in ipairs(items) do
				toShow[#toShow + 1] = entry
			end
		end
	end

	for _, entry in ipairs(toShow) do
		if lowerFilter == "" or entry.name:lower():find(lowerFilter, 1, true) then
			virtualItems[#virtualItems + 1] = entry
		end
	end

	virtualTileW = computeTileWidth()
	lastBuildInnerPx = getListInnerPx()

	-- Render initial visible window (top of list)
	local viewH = listEl.client_height or 500
	local dpRatio = getDpRatio()
	local rowHeightPx = (virtualTileW + TILE_GAP_DP * dpRatio)
	if rowHeightPx < 1 then rowHeightPx = 40 end
	local visibleRows = math.ceil(viewH / rowHeightPx) + 4
	local endIdx = math.min(#virtualItems, visibleRows * TILE_COLUMNS)

	renderVirtualWindow(listEl, doc, 0, endIdx, selectedSet)
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
	rebuildFeatureList("")
end

function widget:OnClearSelection()
	if WG.FeaturePlacer then
		WG.FeaturePlacer.clearSelectedFeatures()
		for _, el in pairs(featureElements) do
			el:SetClass("selected", false)
		end
		updateSelectedCount()
	end
end

----------------------------------------------------------------
-- Attach event listeners (imperative — drag handle + category buttons
-- + dynamic feature tiles; all simple buttons/inputs live in RML)
----------------------------------------------------------------
local function attachEventListeners()
	local doc = widgetState.document
	if not doc then return end

	-- Category buttons
	local catKeys = { "all", "rocks", "trees", "foliage", "crystals", "christmas", "raptor", "armada_wrecks", "cortex_wrecks", "legion_wrecks", "other" }
	for _, key in ipairs(catKeys) do
		local btn = doc:GetElementById("btn-cat-" .. key)
		if btn then
			categoryButtons[key] = btn
			btn:AddEventListener("click", function(event)
				activeCategory = key
				for k, el in pairs(categoryButtons) do
					el:SetClass("active", k == key)
				end
				rebuildFeatureList(lastSearchFilter)
				event:StopPropagation()
			end, false)
		end
	end

	-- Build initial feature list
	rebuildFeatureList("")

	-- Drag handle
	if WG.RmlContextManager and WG.RmlContextManager.attachDraggable then
		widgetState.dragHandle = WG.RmlContextManager.attachDraggable(
			doc, "fp-handle", widgetState.rootElement,
			{ onDragStart = function() userDragged = true end }
		)
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
	document:Show()

	if WG.RmlContextManager and WG.RmlContextManager.registerDocument then
		WG.RmlContextManager.registerDocument("feature_placer", document)
	end

	widgetState.rootElement = document:GetElementById("fp-root")

	-- Hidden state is driven via data-class-hidden on #fp-root; the initial
	-- model has `hidden = true` so the panel stays invisible until Update().
	widgetState.rootElement:SetAttribute("style", buildRootStyle())

	attachEventListeners()
end

function widget:Update()
	if widgetState.dragHandle then widgetState.dragHandle.tick() end

	local function setHidden(v)
		if widgetState.dmHandle and widgetState.dmHandle.hidden ~= v then
			widgetState.dmHandle.hidden = v
		end
	end

	if not WG.FeaturePlacer then
		setHidden(true)
		return
	end

	local state = WG.FeaturePlacer.getState()
	if not state then
		setHidden(true)
		return
	end

	local isActive = state.active
	if isActive and not lastActive then
		manuallyHidden = false
	end
	lastActive = isActive
	setHidden((not isActive) or manuallyHidden)

	if not isActive then return end

	-- Sync two-way-bound search filter back to internal state
	if widgetState.dmHandle then
		local searchVal = widgetState.dmHandle.search or ""
		if searchVal ~= lastSearchFilter then
			lastSearchFilter = searchVal
			rebuildFeatureList(searchVal)
		end
	end

	-- Align to the left of the main terraform panel (only if not user-dragged)
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

	-- Update selected count
	updateSelectedCount()

	-- Resize/relayout: if the feature-list's client_width changed since the
	-- last rebuild, rebuild so tile widths re-derive. Handles window resize,
	-- scrollbar appearing/disappearing, and first-frame-where-layout-finally-settled.
	if widgetState.document then
		local curInner = getListInnerPx()
		if curInner > 0 and math.abs(curInner - lastBuildInnerPx) >= 2 then
			rebuildFeatureList(lastSearchFilter)
		end
	end

	-- Lazy-start thumbnail generation
	if not thumbGenAttempted and WG.FeaturePlacer then
		startThumbGeneration()
	end

	-- Virtual scroll: update visible window when user scrolls
	if #virtualItems > 0 then
		local listEl = widgetState.document and widgetState.document:GetElementById("feature-list")
		if listEl then
			local scrollTop = listEl.scroll_top or 0
			if scrollTop ~= virtualScrollTop then
				virtualScrollTop = scrollTop
				updateVirtualWindow()
			end
		end
	end

	-- Periodic list refresh during thumbnail generation
	if thumbGenerating then
		thumbRefreshTimer = thumbRefreshTimer + 1
		if thumbRefreshTimer >= 30 then
			thumbRefreshTimer = 0
			rebuildFeatureList(lastSearchFilter)
		end
	elseif needsListRefresh then
		needsListRefresh = false
		rebuildFeatureList(lastSearchFilter)
	end
end

function widget:DrawScreen()
	if thumbGenerating then
		processThumbQueue()
	end
end

function widget:DrawScreenPost()
	-- Skip entirely when panel is hidden (feature placer inactive or manually closed)
	if widgetState.rootElement and widgetState.rootElement:IsClassSet("hidden") then return end
	if not next(thumbTextures) then return end
	drawThumbnailOverlays()
end

function widget:Shutdown()
	-- If the search input had focus when we shut down, SDL text-input mode is
	-- still active and will leak into the next session.
	Spring.SDLStopTextInput()

	if WG.RmlContextManager and WG.RmlContextManager.unregisterDocument then
		WG.RmlContextManager.unregisterDocument("feature_placer")
	end

	cleanupThumbs()
	thumbGenerating = false
	thumbQueue = {}
	if widgetState.document then
		widgetState.document:Close()
		widgetState.document = nil
	end
	if widgetState.rmlContext then
		widgetState.rmlContext:RemoveDataModel(MODEL_NAME)
	end
	widgetState.dmHandle = nil
	widgetState.rootElement = nil
	featureElements = {}
	categoryButtons = {}
	activeCategory = "all"
end
