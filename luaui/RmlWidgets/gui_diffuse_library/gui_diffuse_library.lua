if not RmlUi then
	return
end

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name    = "Diffuse Library UI",
		desc    = "RmlUI material library panel for the Diffuse Painter (thumbnail grid)",
		author  = "BARb",
		date    = "2026",
		license = "GNU GPL, v2 or later",
		layer   = 1,
		enabled = true,
	}
end

local RML_PATH = "luaui/RmlWidgets/gui_diffuse_library/gui_diffuse_library.rml"
local MODEL_NAME = "diffuse_library_model"

local WG = WG

local widgetState = {
	rmlContext  = nil,
	document    = nil,
	dmHandle    = nil,
	rootElement = nil,
}

local initialModel = {
	-- Root panel visibility (data-class-hidden on #dml-root)
	hidden = true,
	-- Two-way-bound search filter (data-value on #material-search)
	search = "",
}

local lastSearchFilter = ""
-- Set of currently-selected category keys. Plain click selects exactly one;
-- Shift+click toggles a category in/out of the set. "all" is mutually
-- exclusive with the specific categories.
local selectedCategories = { all = true }
local categoryButtons    = {}  -- { [catKey] = element }
local materialElements   = {}  -- { [matKey] = tile element }
local thumbDivs          = {}  -- { [matKey] = thumb div element }
local thumbMatPath       = {}  -- { [matKey] = texture path } for selection re-derive
local manuallyHidden     = false
local lastActive         = false
local userDragged        = false
local lastLibrarySig     = nil   -- detect material-library changes
local lastActivePath     = nil   -- detect active-layer texture changes (re-highlight)

-- Categories, in display order. Derived from the material key by keyword.
local CATEGORY_ORDER = { "all", "rock", "sand", "grass", "mud", "snow", "moon", "other" }

local function categorize(key)
	local k = (key or ""):lower()
	local function has(...)
		for _, p in ipairs({ ... }) do
			if k:find(p, 1, true) then return true end
		end
		return false
	end
	if has("snow", "ice")                                          then return "snow" end
	if has("moon")                                                 then return "moon" end
	if has("sand", "coast", "beach", "dune")                       then return "sand" end
	if has("mud", "riverbed", "dirt", "clay")                      then return "mud" end
	if has("grass", "forest", "floor", "moss", "leaves", "path")   then return "grass" end
	if has("rock", "cliff", "gravel", "stone", "marble",
	       "terrain", "ground", "concrete", "coral")               then return "rock" end
	return "other"
end

----------------------------------------------------------------
-- Thumbnail generation (render each diffuse texture to a small GL texture).
-- The source diffuse maps are 8k; loading all of them at once would blow the
-- VRAM budget, so we render one at a time into a THUMB_SIZE FBO and free the
-- full-resolution named texture immediately afterwards.
----------------------------------------------------------------
local THUMB_SIZE       = 128
local THUMBS_PER_FRAME = 2
local GL_COLOR_ATTACHMENT0_EXT = 0x8CE0

local thumbTextures    = {}    -- { [matKey] = glTexture }
local thumbQueue       = {}
local thumbQueueIdx    = 0
local thumbTotal       = 0
local thumbDone        = 0
local thumbGenerating  = false
local thumbGenAttempted = false
local needsListRefresh  = false
local thumbRefreshTimer = 0

local function getDpRatio()
	return (WG.TerraformerShared and WG.TerraformerShared.getDpRatio
		and WG.TerraformerShared.getDpRatio()) or 1.0
end

local function cleanupThumbs()
	for _, tex in pairs(thumbTextures) do
		gl.DeleteTexture(tex)
	end
	thumbTextures = {}
end

local function renderOneThumb(matKey, path)
	if not path or path == "" then return false end

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
		drawbuffers = { GL_COLOR_ATTACHMENT0_EXT },
	})
	if not fbo or not gl.IsValidFBO(fbo) then
		gl.DeleteTexture(colorTex)
		if fbo then gl.DeleteFBO(fbo) end
		return false
	end

	-- Bind the full-res diffuse. If the engine can't load it, bail cleanly.
	local bound = gl.Texture(0, path)
	if bound == false then
		gl.DeleteTexture(colorTex)
		gl.DeleteFBO(fbo)
		return false
	end

	local vsx, vsy = Spring.GetViewGeometry()

	gl.ActiveFBO(fbo, function()
		gl.Viewport(0, 0, THUMB_SIZE, THUMB_SIZE)
		gl.Blending(false)
		gl.DepthTest(false)

		gl.MatrixMode(GL.PROJECTION)
		gl.PushMatrix()
		gl.LoadIdentity()
		gl.MatrixMode(GL.MODELVIEW)
		gl.PushMatrix()
		gl.LoadIdentity()

		gl.Color(1, 1, 1, 1)
		-- Full-screen NDC quad; flip V so the preview reads the same way up as
		-- the texture appears on the terrain.
		gl.TexRect(-1, -1, 1, 1, 0, 1, 1, 0)

		gl.MatrixMode(GL.PROJECTION)
		gl.PopMatrix()
		gl.MatrixMode(GL.MODELVIEW)
		gl.PopMatrix()

		gl.Viewport(0, 0, vsx, vsy)
	end)

	gl.Texture(0, false)
	-- Free the 8k source now that the thumbnail is baked. DeleteTexture accepts
	-- a named-texture string, but pcall in case an engine build disagrees —
	-- failing to free is a VRAM cost, not a crash.
	pcall(gl.DeleteTexture, path)
	gl.Blending(true)
	gl.DeleteFBO(fbo)

	thumbTextures[matKey] = colorTex
	return true
end

local function startThumbGeneration()
	if thumbGenAttempted then return end
	if not (WG.DiffusePainter and WG.DiffusePainter.getMaterialLibrary) then return end
	thumbGenAttempted = true

	local library = WG.DiffusePainter.getMaterialLibrary() or {}
	thumbQueue = {}
	thumbQueueIdx = 1
	for i = 1, #library do
		local mat = library[i]
		if mat and mat.path and not thumbTextures[mat.key] then
			thumbQueue[#thumbQueue + 1] = { key = mat.key, path = mat.path }
		end
	end

	thumbTotal = #thumbQueue
	thumbDone = 0
	if thumbTotal == 0 then
		needsListRefresh = true
		return
	end
	thumbGenerating = true
	Spring.Echo("[Diffuse Library UI] Generating " .. thumbTotal .. " material thumbnails...")
end

local function processThumbQueue()
	if not thumbGenerating then return end
	local processed = 0
	while thumbQueueIdx <= #thumbQueue and processed < THUMBS_PER_FRAME do
		local item = thumbQueue[thumbQueueIdx]
		thumbQueueIdx = thumbQueueIdx + 1
		renderOneThumb(item.key, item.path)
		thumbDone = thumbDone + 1
		processed = processed + 1
	end
	if thumbQueueIdx > #thumbQueue then
		thumbGenerating = false
		needsListRefresh = true
		Spring.Echo("[Diffuse Library UI] Thumbnails complete (" .. thumbDone .. "/" .. thumbTotal .. ")")
	end
end

----------------------------------------------------------------
-- Thumbnail overlay drawing (RmlUi can't host our in-memory GL textures, so
-- draw them over the tile divs, scissor-clipped to the scroll area).
----------------------------------------------------------------
local function drawThumbnailOverlays()
	local doc = widgetState.document
	if not doc then return end
	if not next(thumbTextures) then return end
	if widgetState.rootElement and widgetState.rootElement:IsClassSet("hidden") then return end

	local listEl = doc:GetElementById("material-list")
	if not listEl then return end

	local _, vsy = Spring.GetViewGeometry()

	local clipX = listEl.absolute_left
	local clipH = listEl.client_height
	local clipY = vsy - listEl.absolute_top - clipH
	local clipW = listEl.client_width

	gl.Scissor(clipX, clipY, clipW, clipH)
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)

	for matKey, div in pairs(thumbDivs) do
		local tex = thumbTextures[matKey]
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
-- Material library: build the categorized tile grid
----------------------------------------------------------------
local function getActiveLayerPath()
	local API = WG.DiffusePainter
	if not API then return nil end
	local id = API.getActiveLayerId and API.getActiveLayerId()
	if not id then return nil end
	local layers = API.getLayers and API.getLayers() or {}
	for i = 1, #layers do
		if layers[i].id == id then return layers[i].texturePath end
	end
	return nil
end

local function onMaterialClick(mat)
	local API = WG.DiffusePainter
	if not API then return end
	local id = API.getActiveLayerId and API.getActiveLayerId()
	local layers = API.getLayers and API.getLayers() or {}
	local activeLayer
	if id then
		for j = 1, #layers do
			if layers[j].id == id then activeLayer = layers[j]; break end
		end
	end
	-- Smart routing (matches tf_diffuse.lua): if the active layer has no
	-- material yet, assign this one to it; otherwise spawn a new layer so any
	-- existing painted strokes are preserved.
	if activeLayer and (not activeLayer.texturePath or activeLayer.texturePath == "") then
		if API.setLayerTexture then API.setLayerTexture(id, mat.path, nil, mat.name) end
	else
		if API.addLayerFromMaterial then API.addLayerFromMaterial(mat.path, mat.name) end
	end
	lastActivePath = nil -- force highlight refresh on next sync
end

local function rebuildMaterialList(filter)
	local doc = widgetState.document
	local listEl = doc and doc:GetElementById("material-list")
	if not listEl or not WG.DiffusePainter then return end

	listEl.inner_rml = ""
	materialElements = {}
	thumbDivs = {}
	thumbMatPath = {}

	-- Loading indicator during thumbnail generation.
	if thumbGenerating and thumbTotal > 0 then
		local loadEl = doc:CreateElement("div")
		loadEl:SetClass("dml-loading-bar", true)
		local pct = math.floor(thumbDone / thumbTotal * 100)
		local fillEl = doc:CreateElement("div")
		fillEl:SetClass("dml-loading-fill", true)
		fillEl:SetAttribute("style", "width: " .. pct .. "%;")
		loadEl:AppendChild(fillEl)
		local labelEl = doc:CreateElement("span")
		labelEl:SetClass("dml-loading-label", true)
		labelEl.inner_rml = "Loading thumbnails " .. pct .. "%"
		loadEl:AppendChild(labelEl)
		listEl:AppendChild(loadEl)
	end

	local library = WG.DiffusePainter.getMaterialLibrary() or {}
	local lowerFilter = filter and filter:lower() or ""
	local showAll = selectedCategories.all or not next(selectedCategories)
	local activePath = getActiveLayerPath()

	for i = 1, #library do
		local mat = library[i]
		local cat = categorize(mat.key)
		local catOk = showAll or selectedCategories[cat]
		local nameOk = lowerFilter == "" or (mat.name and mat.name:lower():find(lowerFilter, 1, true))
		if catOk and nameOk then
			thumbMatPath[mat.key] = mat.path

			local itemEl = doc:CreateElement("div")
			itemEl:SetClass("dml-material-item", true)
			if mat.path == activePath then itemEl:SetClass("selected", true) end

			local thumbEl = doc:CreateElement("div")
			thumbEl:SetClass("dml-material-thumb", true)
			thumbEl:SetClass("dml-thumb-" .. cat, true)
			itemEl:AppendChild(thumbEl)
			thumbDivs[mat.key] = thumbEl

			local resEl = doc:CreateElement("div")
			resEl:SetClass("dml-material-res", true)
			resEl.inner_rml = tostring(mat.resK or 8) .. "k"
			itemEl:AppendChild(resEl)

			local nameEl = doc:CreateElement("div")
			nameEl:SetClass("dml-material-name", true)
			nameEl.inner_rml = mat.name or mat.key
			itemEl:AppendChild(nameEl)

			itemEl:AddEventListener("click", function(event)
				onMaterialClick(mat)
				event:StopPropagation()
			end, false)

			materialElements[mat.key] = itemEl
			listEl:AppendChild(itemEl)
		end
	end

	lastActivePath = activePath
end

----------------------------------------------------------------
-- Declarative event handlers (called from RML via onclick="widget:Foo()")
----------------------------------------------------------------
function widget:OnQuit()
	manuallyHidden = true
	if widgetState.dmHandle then widgetState.dmHandle.hidden = true end
end

function widget:OnSearchFocus()
	Spring.SDLStartTextInput()
end

function widget:OnSearchBlur()
	Spring.SDLStopTextInput()
end

-- data-value writes dm.search only AFTER the change event fires (RmlUi quirk),
-- so read the input element's value directly here.
function widget:OnSearchChange()
	local doc = widgetState.document
	local el = doc and doc:GetElementById("material-search")
	local val = el and el:GetAttribute("value") or ""
	if val == lastSearchFilter then return end
	lastSearchFilter = val
	if widgetState.dmHandle then widgetState.dmHandle.search = val end
	rebuildMaterialList(val)
end

function widget:OnSearchClear()
	if widgetState.dmHandle then widgetState.dmHandle.search = "" end
	lastSearchFilter = ""
	rebuildMaterialList("")
end

----------------------------------------------------------------
-- Attach event listeners (imperative — drag handle + category buttons)
----------------------------------------------------------------
local function attachEventListeners()
	local doc = widgetState.document
	if not doc then return end

	for _, key in ipairs(CATEGORY_ORDER) do
		local btn = doc:GetElementById("btn-dmlcat-" .. key)
		if btn then
			categoryButtons[key] = btn
			btn:AddEventListener("click", function(event)
				local _, _, _, shift = Spring.GetModKeyState()
				if not shift or key == "all" then
					selectedCategories = { [key] = true }
				else
					selectedCategories.all = nil
					if selectedCategories[key] then
						selectedCategories[key] = nil
					else
						selectedCategories[key] = true
					end
					if not next(selectedCategories) then
						selectedCategories = { all = true }
					end
				end
				for k, el in pairs(categoryButtons) do
					el:SetClass("active", selectedCategories[k] == true)
				end
				rebuildMaterialList(lastSearchFilter)
				event:StopPropagation()
			end, false)
		end
	end

	rebuildMaterialList("")

	if WG.TerraformerShared and WG.TerraformerShared.attachDraggable then
		widgetState.dragHandle = WG.TerraformerShared.attachDraggable(
			doc, "dml-handle", widgetState.rootElement,
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

	if WG.TerraformerShared and WG.TerraformerShared.registerDocument then
		WG.TerraformerShared.registerDocument("diffuse_library", document)
	end

	widgetState.rootElement = document:GetElementById("dml-root")
	widgetState.rootElement:SetAttribute("style", "left: 70vw; top: 10vh;")

	attachEventListeners()
end

function widget:Update()
	if widgetState.dragHandle then widgetState.dragHandle.tick() end

	local function setHidden(v)
		if widgetState.dmHandle and widgetState.dmHandle.hidden ~= v then
			widgetState.dmHandle.hidden = v
		end
	end

	local API = WG.DiffusePainter
	if not API or not API.isActive then
		setHidden(true)
		return
	end

	local isActive = API.isActive()
	if isActive and not lastActive then
		manuallyHidden = false
	end
	lastActive = isActive
	setHidden((not isActive) or manuallyHidden)
	if not isActive then return end

	-- Sync two-way-bound search filter back to internal state.
	if widgetState.dmHandle then
		local searchVal = widgetState.dmHandle.search or ""
		if searchVal ~= lastSearchFilter then
			lastSearchFilter = searchVal
			rebuildMaterialList(searchVal)
		end
	end

	-- Position to the right of the main terraform panel (until user drags).
	local mainPanel = WG.TerraformerShared and WG.TerraformerShared.getElementRect
		and WG.TerraformerShared.getElementRect("terraform_brush", "tf-root")
	if not userDragged and mainPanel and widgetState.rootElement then
		local gap = 8
		widgetState.rootElement:SetAttribute("style",
			string.format("left: %dpx; top: %dpx;",
				mainPanel.left + (mainPanel.width or 0) + gap, mainPanel.top))
	end

	-- Lazy-start thumbnail generation once the painter library is populated.
	if not thumbGenAttempted then
		startThumbGeneration()
	end

	-- Rebuild on library size change (e.g. a rescan adds materials).
	local library = (API.getMaterialLibrary and API.getMaterialLibrary()) or {}
	local librarySig = #library
	if librarySig ~= lastLibrarySig then
		-- Only force a fresh thumbnail pass when the set actually GROWS after a
		-- completed first pass; the initial population is already handled by the
		-- lazy startThumbGeneration above, so don't re-arm it here.
		if lastLibrarySig ~= nil and librarySig > lastLibrarySig then
			thumbGenAttempted = false
		end
		lastLibrarySig = librarySig
		rebuildMaterialList(lastSearchFilter)
	end
	local activePath = getActiveLayerPath()
	if activePath ~= lastActivePath then
		lastActivePath = activePath
		for key, el in pairs(materialElements) do
			el:SetClass("selected", thumbMatPath[key] == activePath)
		end
	end

	-- Periodic refresh while thumbnails are still baking; one final refresh after.
	if thumbGenerating then
		thumbRefreshTimer = thumbRefreshTimer + 1
		if thumbRefreshTimer >= 30 then
			thumbRefreshTimer = 0
			rebuildMaterialList(lastSearchFilter)
		end
	elseif needsListRefresh then
		needsListRefresh = false
		rebuildMaterialList(lastSearchFilter)
	end
end

function widget:DrawScreen()
	if thumbGenerating then
		processThumbQueue()
	end
end

function widget:DrawScreenPost()
	if widgetState.rootElement and widgetState.rootElement:IsClassSet("hidden") then return end
	if not next(thumbTextures) then return end
	drawThumbnailOverlays()
end

function widget:Shutdown()
	Spring.SDLStopTextInput()

	if WG.TerraformerShared and WG.TerraformerShared.unregisterDocument then
		WG.TerraformerShared.unregisterDocument("diffuse_library")
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
	materialElements = {}
	thumbDivs = {}
	categoryButtons = {}
	selectedCategories = { all = true }
end
