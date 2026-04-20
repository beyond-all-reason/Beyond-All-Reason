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

local WG = WG
local GetViewGeometry = Spring.GetViewGeometry

local INITIAL_LEFT_VW   = 60
local INITIAL_TOP_VH    = 10
local BASE_WIDTH_DP     = 162
local BASE_RESOLUTION   = 1920
local TILE_COLUMNS      = 4
local TILE_GAP_DP       = 2

local widgetState = {
	rmlContext   = nil,
	document     = nil,
	rootElement  = nil,
	panelWidthDp = BASE_WIDTH_DP,
}

local lastSearchFilter = ""
local activeCategory   = "all"
local categoryButtons  = {} -- { [catKey] = element }
local featureElements  = {} -- { [defName] = element }
local thumbDivs        = {} -- { [defName] = div element }
local manuallyHidden   = false
local lastActive       = false
local userDragged      = false  -- once user drags, stop auto-positioning

-- Window drag state (module-level for widget:MouseMove/MouseRelease)
local FP_SNAP_THRESHOLD = 30
local fpDragState = {
	active = false,
	rootEl = nil,
	offsetX = 0, offsetY = 0,
	ew = 0, eh = 0,
	vsx = 0, vsy = 0,
	lastX = -1, lastY = -1,
}

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
	return string.format("left: %.2fvw; top: %.2fvh; width: %ddp;",
		INITIAL_LEFT_VW, INITIAL_TOP_VH, widgetState.panelWidthDp)
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

local function computeTileWidth()
	local pw = widgetState.panelWidthDp
	local innerW = pw - 16 - 8 - 2
	return math.floor((innerW - (TILE_COLUMNS - 1) * TILE_GAP_DP - TILE_COLUMNS * 4) / TILE_COLUMNS)
end

local function createTileElement(doc, entry, tileW, selectedSet)
	local name = entry.name
	local itemEl = doc:CreateElement("div")
	itemEl:SetClass("fp-feature-item", true)
	itemEl:SetAttribute("style", string.format("width: %ddp; height: %ddp;", tileW, tileW))
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
	-- Each row has TILE_COLUMNS items; row height ~ tileW + gap (dp)
	-- We use tileW as approx tile height since tiles are square
	local rowHeightDp = tileW + TILE_GAP_DP

	-- Top spacer: accounts for all rows above startIdx
	local topRows = math.floor(startIdx / TILE_COLUMNS)
	virtualTopSpacer = doc:CreateElement("div")
	virtualTopSpacer:SetAttribute("style", string.format(
		"width: 100%%; height: %ddp; flex-shrink: 0;", topRows * rowHeightDp))
	listEl:AppendChild(virtualTopSpacer)

	-- Create visible tiles
	for i = startIdx + 1, math.min(endIdx, totalItems) do
		local entry = virtualItems[i]
		local itemEl = createTileElement(doc, entry, tileW, selectedSet)
		listEl:AppendChild(itemEl)
	end

	-- Bottom spacer: accounts for all rows below endIdx
	local bottomItems = math.max(0, totalItems - endIdx)
	local bottomRows = math.ceil(bottomItems / TILE_COLUMNS)
	virtualBotSpacer = doc:CreateElement("div")
	virtualBotSpacer:SetAttribute("style", string.format(
		"width: 100%%; height: %ddp; flex-shrink: 0;", bottomRows * rowHeightDp))
	listEl:AppendChild(virtualBotSpacer)

	virtualVisStart = startIdx
	virtualVisEnd = endIdx
end

local function updateVirtualWindow()
	local doc = widgetState.document
	local listEl = doc and doc:GetElementById("feature-list")
	if not listEl or #virtualItems == 0 then return end

	local scrollTop = listEl.scroll_top or 0
	local viewH = listEl.client_height or 500

	local tileW = virtualTileW
	local rowHeightDp = tileW + TILE_GAP_DP
	-- Convert dp to approximate px using the scale factor
	local vsx = GetViewGeometry()
	local scaleFactor = math.max(1.0, vsx / BASE_RESOLUTION)
	local rowHeightPx = rowHeightDp * scaleFactor

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

	-- Render initial visible window (top of list)
	local viewH = listEl.client_height or 500
	local vsx = GetViewGeometry()
	local scaleFactor = math.max(1.0, vsx / BASE_RESOLUTION)
	local rowHeightPx = (virtualTileW + TILE_GAP_DP) * scaleFactor
	if rowHeightPx < 1 then rowHeightPx = 40 end
	local visibleRows = math.ceil(viewH / rowHeightPx) + 4
	local endIdx = math.min(#virtualItems, visibleRows * TILE_COLUMNS)

	renderVirtualWindow(listEl, doc, 0, endIdx, selectedSet)
end

----------------------------------------------------------------
-- Attach event listeners
----------------------------------------------------------------
local function attachEventListeners()
	local doc = widgetState.document
	if not doc then return end

	-- Category buttons
	local catKeys = { "all", "rocks", "trees", "bushes", "crystals", "christmas", "raptor", "armada_wrecks", "cortex_wrecks", "legion_wrecks", "other" }
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

	-- Quit
	local quitBtn = doc:GetElementById("btn-quit")
	if quitBtn then
		quitBtn:AddEventListener("click", function(event)
			manuallyHidden = true
			if widgetState.rootElement then
				widgetState.rootElement:SetClass("hidden", true)
			end
			event:StopPropagation()
		end, false)
	end

	-- Feature search input
	local searchInput = doc:GetElementById("feature-search")
	if searchInput then
		searchInput:AddEventListener("focus", function()
			Spring.SDLStartTextInput()
		end, false)
		searchInput:AddEventListener("blur", function()
			Spring.SDLStopTextInput()
		end, false)
		searchInput:AddEventListener("change", function(event)
			local val = searchInput:GetAttribute("value") or ""
			if val ~= lastSearchFilter then
				lastSearchFilter = val
				rebuildFeatureList(val)
			end
		end, false)
	end

	-- Search clear (x) button
	local searchClearBtn = doc:GetElementById("btn-search-clear")
	if searchClearBtn and searchInput then
		searchClearBtn:AddEventListener("click", function(event)
			searchInput:SetAttribute("value", "")
			lastSearchFilter = ""
			rebuildFeatureList("")
			event:StopPropagation()
		end, false)
	end

	-- Clear selection button
	local clearBtn = doc:GetElementById("btn-clear-selection")
	if clearBtn then
		clearBtn:AddEventListener("click", function(event)
			if WG.FeaturePlacer then
				WG.FeaturePlacer.clearSelectedFeatures()
				for _, el in pairs(featureElements) do
					el:SetClass("selected", false)
				end
				updateSelectedCount()
			end
			event:StopPropagation()
		end, false)
	end

	-- Build initial feature list
	rebuildFeatureList("")

	-- Drag handle
	local handleEl = doc:GetElementById("fp-handle")
	if handleEl and widgetState.rootElement then
		local rootEl = widgetState.rootElement
		local ds = fpDragState

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

		doc:AddEventListener("mouseup", function(event)
			if ds.active then
				ds.active = false
				ds.rootEl = nil
			end
		end, false)
	end
end

----------------------------------------------------------------
-- Lifecycle
----------------------------------------------------------------
function widget:Initialize()
	widgetState.rmlContext = RmlUi.GetContext("shared")
	if not widgetState.rmlContext then return false end

	local document = widgetState.rmlContext:LoadDocument(RML_PATH)
	if not document then
		widget:Shutdown()
		return false
	end
	widgetState.document = document
	document:Show()

	widgetState.rootElement = document:GetElementById("fp-root")

	-- Hide immediately so the panel is never briefly visible before Update() runs,
	-- and to prevent the search <input> from auto-focusing and calling SDLStartTextInput()
	-- at load time (which leaks camera-scroll key events).
	widgetState.rootElement:SetClass("hidden", true)

	local vsx = GetViewGeometry()
	local scaleFactor = math.max(1.0, vsx / BASE_RESOLUTION)
	widgetState.panelWidthDp = math.floor(BASE_WIDTH_DP * scaleFactor)
	widgetState.rootElement:SetAttribute("style", buildRootStyle())

	attachEventListeners()
end

function widget:Update()
	-- Poll-based window drag (position only — mouseup ends drag via doc listener)
	local ds = fpDragState
	if ds.active and ds.rootEl then
		local mx, my = Spring.GetMouseState()
		local vsx, vsy = ds.vsx, ds.vsy
		local ew, eh = ds.ew, ds.eh
		local T = FP_SNAP_THRESHOLD
		local rmlY = vsy - my
		local newX = mx - ds.offsetX
		local newY = rmlY - ds.offsetY

		if newX < 0 then newX = 0
		elseif newX + ew > vsx then newX = vsx - ew end
		if newY < 0 then newY = 0
		elseif newY + eh > vsy then newY = vsy - eh end

		if newX < T then newX = 0
		elseif vsx - newX - ew < T then newX = vsx - ew end
		if newY < T then newY = 0
		elseif vsy - newY - eh < T then newY = vsy - eh end

		-- Snap to terraform main panel
		local mainPanel = WG.TerraformBrushPanel
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
			ds.lastX = ix
			ds.lastY = iy
			ds.rootEl.style.left = ix .. "px"
			ds.rootEl.style.top  = iy .. "px"
		end
	end

	if not WG.FeaturePlacer then
		if widgetState.rootElement then
			widgetState.rootElement:SetClass("hidden", true)
		end
		return
	end

	local state = WG.FeaturePlacer.getState()
	if not state then
		if widgetState.rootElement then
			widgetState.rootElement:SetClass("hidden", true)
		end
		return
	end

	local isActive = state.active
	if isActive and not lastActive then
		manuallyHidden = false
	end
	lastActive = isActive
	if widgetState.rootElement then
		widgetState.rootElement:SetClass("hidden", not isActive or manuallyHidden)
	end

	if not isActive then return end

	-- Align to the left of the main terraform panel (only if not user-dragged)
	local mainPanel = WG.TerraformBrushPanel
	if not userDragged and mainPanel and widgetState.rootElement then
		local myWidth = widgetState.rootElement.offset_width
		if myWidth and myWidth > 0 then
			local gap = 8
			widgetState.rootElement:SetAttribute("style",
				string.format("left: %dpx; top: %dpx; width: %ddp;",
					mainPanel.left - myWidth - gap, mainPanel.top, widgetState.panelWidthDp))
		end
	end

	-- Update selected count
	updateSelectedCount()

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

	cleanupThumbs()
	thumbGenerating = false
	thumbQueue = {}
	if widgetState.document then
		widgetState.document:Close()
		widgetState.document = nil
	end
	widgetState.rootElement = nil
	featureElements = {}
	categoryButtons = {}
	activeCategory = "all"
end
