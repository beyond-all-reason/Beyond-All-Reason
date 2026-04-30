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

----------------------------------------------------------------
-- Type definitions (Lua LS only — strip at compile time, no runtime cost)
----------------------------------------------------------------

---Shape of the data model bound to the RML document.
---@class DecalPlacerModel
---@field search string               -- data-value on #dp-search
---@field activeCategory string       -- data-class-active on each fp-cat-btn
---@field selectedCount integer       -- {{selectedCount}} in tile header
---@field onCategorySelect fun(event: any, key: string)       -- data-event-click on category button
---@field onSearchFocus fun(event: any)                       -- data-event-focus on search input
---@field onSearchBlur fun(event: any)                        -- data-event-blur on search input
---@field onSearchChange fun(event: any)                      -- data-event-change on search input
---@field onSearchClear fun(event: any)                       -- data-event-click on clear button
-- Note: panel visibility is NOT a model field. Show/hide is controlled at the
-- document level via document:Show() / document:Hide() so RmlUi drops the
-- whole document from its active set when off — no layout/draw cost when
-- closed.
-- Note: the tile grid is built imperatively via CreateElement/AppendChild.
-- Recoil's data-for does not propagate iterator scope to child element
-- bindings (d.field fails with "Could not find variable"), so we use the
-- same imperative DOM approach as gui_feature_placer.

---@class WidgetState
---@field rmlContext any
---@field document any
---@field dmHandle DecalPlacerModel? -- nil until widget:Initialize() opens the data model
---@field rootElement any

---@type WidgetState
local widgetState = {
	rmlContext  = nil,
	document    = nil,
	dmHandle   = nil,
	rootElement = nil,
}

-- Hoisted above initialModel so model-resident handlers can capture them
-- as upvalues. Reassignments work because Lua closures bind to the local
-- slot, not the value at definition time.
local syncDecals          -- forward decl, assigned further down
local lastSearchFilter = ""

---@type DecalPlacerModel
local initialModel = {
	search = "",
	activeCategory = "all",
	selectedCount = 0,

	onCategorySelect = function(_event, key)
		local dm = widgetState.dmHandle
		if not dm or dm.activeCategory == key then return end
		dm.activeCategory = key
		-- syncDecals is defined below; forward declared via the closure since
		-- this whole table is the model and `syncDecals` is in module scope.
		syncDecals()
	end,

	onSearchFocus = function(_event)
		Spring.SDLStartTextInput()
	end,

	onSearchBlur = function(_event)
		Spring.SDLStopTextInput()
	end,

	-- data-value="search" updates dm.search AFTER the change event fires
	-- (RmlUi quirk, see rmlui_data_value_race memory note). So we read the
	-- input element's value directly rather than dm.search.
	onSearchChange = function(_event)
		local doc = widgetState.document
		local el = doc and doc:GetElementById("dp-search")
		local val = el and el:GetAttribute("value") or ""
		if val == lastSearchFilter then return end
		lastSearchFilter = val
		syncDecals()
	end,

	onSearchClear = function(_event)
		local dm = widgetState.dmHandle
		if not dm then return end
		dm.search = ""
		lastSearchFilter = ""
		syncDecals()
	end,
}

-- Tracks document:Show/Hide state so we don't issue redundant calls every frame.
-- See setVisible() below.
local documentVisible  = false

-- One-shot guard for the lazy first sync. WG.DecalPlacer may not be ready in
-- widget:Initialize (engine resources still loading), so widget:Update retries
-- until categories arrive. After that — never. State changes (category click,
-- filter change) drive subsequent syncs explicitly; Update does NOT poll.
local firstSyncDone = false

local userDragged = false

----------------------------------------------------------------
-- Document-level visibility. document:Show()/Hide() takes the whole document
-- in/out of the RmlUi context's active set — when hidden, NO layout/draw/event
-- cost. This is the right primitive for "panel is closed" (vs CSS class
-- toggling, which keeps the document live).
----------------------------------------------------------------
local function setVisible(visible)
	if visible == documentVisible then return end
	local doc = widgetState.document
	if not doc then return end
	documentVisible = visible
	if visible then doc:Show() else doc:Hide() end
end

-- Polls WG.DecalPlacer.state.active once per Update tick. The X button
-- deactivates the tool directly (see widget:OnQuit), so there's no separate
-- "manually closed" concept — tool active state is the single source of
-- truth for whether the panel is shown.
-- TODO: replace with an event-driven WG.DecalPlacer.onActiveChanged hook
-- when the WG layer grows callbacks; until then we poll.
-- Returns whether the tool is currently engaged so callers can early-bail.
local function syncVisibilityFromTool()
	local state = WG.DecalPlacer and WG.DecalPlacer.getState()
	local toolActive = state and state.active or false
	setVisible(toolActive)
	return toolActive
end

local DP_SNAP_THRESHOLD = 30
local dpDragState = {
	active = false, rootEl = nil,
	offsetX = 0, offsetY = 0,
	ew = 0, eh = 0,
	vsx = 0, vsy = 0,
	lastX = -1, lastY = -1,
}

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
-- Mask-shader pre-bake module — channel-encoded BMP atlases (mainscars,
-- tracks, footprints) have no alpha. Module composites them through a one-
-- shot shader into RGBA PNGs cached on disk, then <img> renders the cached
-- PNG normally. See dp_preview_bake.lua for the full API + design notes.
----------------------------------------------------------------
local Bake = VFS.Include("luaui/RmlWidgets/gui_decal_placer/dp_preview_bake.lua")
local PREVIEW_CACHE_DIR = "Terraform Brush/DecalPreviews/"

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------
local function buildRootStyle()
	-- Width lives in RCSS (.dp-root); we only set position here.
	return string.format("left: %.2fvw; top: %.2fvh;",
		INITIAL_LEFT_VW, INITIAL_TOP_VH)
end

----------------------------------------------------------------
-- Tile elements by decal name — for updating selection visuals without a
-- full DOM rebuild. Reset on every full syncDecals call.
local tileElements = {}

-- Derive the visible decal rows from WG state + active filter/category and
-- rebuild the tile grid imperatively.
-- NOTE: Recoil's data-for does not propagate iterator scope to child
-- element bindings, so we use CreateElement/AppendChild/AddEventListener
-- instead (same pattern as gui_feature_placer).
-- Idempotent — safe to call on category change, filter change, bake finish.
-- (Forward-declared above so initialModel handlers can capture it.)
----------------------------------------------------------------
syncDecals = function()
	local dm = widgetState.dmHandle
	if not WG.DecalPlacer then return end
	if not dm then return end
	local doc = widgetState.document
	if not doc then return end

	local listEl = doc:GetElementById("dp-tile-list")
	if not listEl then return end

	local categories = WG.DecalPlacer.getDecalCategories()
	local order = WG.DecalPlacer.getCategoryOrder()
	if not categories or not order then return end

	local state = WG.DecalPlacer.getState()
	local selectedSet = state and state.selectedSet or {}
	local lowerFilter = (lastSearchFilter or ""):lower()
	local cat = dm.activeCategory or "all"

	-- Full DOM rebuild
	listEl.inner_rml = ""
	tileElements = {}

	local catOrder = (cat == "all") and order or { cat }
	for _, catName in ipairs(catOrder) do
		local items = categories[catName]
		if items then
			for _, entry in ipairs(items) do
				local name = entry.name
				local labelName = entry.displayName or name
				if lowerFilter == "" or labelName:lower():find(lowerFilter, 1, true) then
					local displayName = (#labelName > 22) and (labelName:sub(1, 20) .. "..") or labelName

					-- Tile container
					local itemEl = doc:CreateElement("div")
					itemEl:SetClass("fp-feature-item", true)
					if selectedSet[name] then
						itemEl:SetClass("selected", true)
					end

					-- Thumbnail
					local thumbEl = doc:CreateElement("div")
					thumbEl:SetClass("fp-feature-thumb", true)
					thumbEl:SetClass("dp-thumb-" .. (entry.category or "other"), true)

					local fname = entry.filename
					if not fname or fname == "" then
						fname = findPreviewPath(name)
					end
					local resolved = nil
					if fname and fname ~= "" then
						local sourcePath = fname:gsub("\\", "/"):gsub("^/+", "")
						resolved = Bake.resolve(name, sourcePath, Bake.classifyMaskMode(sourcePath))
					end
					if not firstSyncDone then
						Spring.Echo(string.format("[DP] tile %s fname=%s resolved=%s", name, tostring(fname), tostring(resolved)))
					end
					if resolved then
						local imgEl = doc:CreateElement("img")
						imgEl:SetAttribute("src", resolved)
						thumbEl:AppendChild(imgEl)
					end
					itemEl:AppendChild(thumbEl)

					-- Name label
					local nameEl = doc:CreateElement("div")
					nameEl:SetClass("fp-feature-name", true)
					nameEl.inner_rml = displayName
					itemEl:AppendChild(nameEl)

					-- Click: select or toggle
					local capName = name
					itemEl:AddEventListener("click", function(event)
						if not WG.DecalPlacer then return end
						local _, _, _, shift = Spring.GetModKeyState()
						if shift then
							WG.DecalPlacer.toggleDecal(capName)
						else
							WG.DecalPlacer.selectDecal(capName)
						end
						-- Update visuals without full DOM rebuild
						local newState = WG.DecalPlacer.getState()
						local ss = newState and newState.selectedSet or {}
						for n, el in pairs(tileElements) do
							el:SetClass("selected", ss[n] or false)
						end
						dm.selectedCount = #(newState and newState.selectedDecals or {})
						event:StopPropagation()
					end, false)

					tileElements[name] = itemEl
					-- Wrap in dp-tile-host so RCSS 84dp×84dp sizing applies
					local hostEl = doc:CreateElement("div")
					hostEl:SetClass("dp-tile-host", true)
					hostEl:AppendChild(itemEl)
					listEl:AppendChild(hostEl)
				end
			end
		end
	end

	dm.selectedCount = #(state and state.selectedDecals or {})
	if not firstSyncDone then
		firstSyncDone = true
		Bake.enqueueAll(WG.DecalPlacer.getDecalCategories(), findPreviewPath)
	end
end

----------------------------------------------------------------
-- Declarative event handlers (called from RML via onclick="widget:Foo()")
----------------------------------------------------------------
function widget:OnQuit()
	-- Closing the panel disengages the tool — this is the panel's whole UI,
	-- so closing it without deactivating leaves the main terraform brush
	-- still highlighting DECALS as active. Deactivating cascades through
	-- WG.DecalPlacer.getState().active → syncVisibilityFromTool hides the
	-- document on the next Update tick.
	if WG.DecalPlacer then WG.DecalPlacer.deactivate() end
end

function widget:OnClearSelection()
	if not WG.DecalPlacer then return end
	WG.DecalPlacer.clearSelectedDecals()
	syncDecals()
end


----------------------------------------------------------------
-- Drag handle wiring (the only imperative event listener left — everything
-- else lives declaratively in the RML).
----------------------------------------------------------------
local function wireDragHandle()
	local doc = widgetState.document
	local rootEl = widgetState.rootElement
	if not doc or not rootEl then return end
	local handleEl = doc:GetElementById("dp-handle")
	if not handleEl then return end

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

----------------------------------------------------------------
-- Lifecycle
----------------------------------------------------------------
function widget:Initialize()
	Spring.CreateDir(PREVIEW_CACHE_DIR)
	Bake.init(PREVIEW_CACHE_DIR)
	widgetState.rmlContext = RmlUi.GetContext("shared")
	if not widgetState.rmlContext then return false end

	widgetState.dmHandle = widgetState.rmlContext:OpenDataModel(MODEL_NAME, initialModel, self)
	if not widgetState.dmHandle then return false end

	widgetState.document = widgetState.rmlContext:LoadDocument(RML_PATH, self)
	if not widgetState.document then
		widget:Shutdown()
		return false
	end

	if WG.RmlContextManager and WG.RmlContextManager.registerDocument then
		WG.RmlContextManager.registerDocument("decal_placer", document)
	end

	widgetState.document:ReloadStyleSheet()

	-- Document starts hidden. widget:Update() calls setVisible() based on
	-- whether the DECALS tool is active, so the panel appears the first time
	-- the user picks the tool — never paying layout cost in between.
	widgetState.document:Hide()
	documentVisible = false

	widgetState.rootElement = widgetState.document:GetElementById("dp-root")

	widgetState.rootElement:SetAttribute("style", buildRootStyle())

	wireDragHandle()
	-- Populate tile list after document (and dp-tile-list element) exists.
	syncDecals()
end

-- Drain bake queue. Spring restricts gl.RenderToTexture to draw callbacks,
-- so this is where the bake module's per-frame work happens.
function widget:DrawScreen()
	Bake.drainQueue()
end

function widget:Update()
	-- After a batch of bakes completes, re-push the model so newly-cached
	-- srcPaths land on their tiles.
	if Bake.consumeResync() then syncDecals() end

	-- Window drag
	local ds = dpDragState
	if ds.active and ds.rootEl then
		local mx, my, _, _, _, offscreen = Spring.GetMouseState()
		if not offscreen then
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
		end -- not offscreen
	end

	if not syncVisibilityFromTool() then return end

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

	-- Lazy FIRST build only — WG.DecalPlacer's category data may not be ready
	-- in widget:Initialize. After firstSyncDone, syncDecals is only ever called
	-- in response to actual state changes (category click, filter change), never
	-- from this Update tick.
	if not firstSyncDone then
		local cats = WG.DecalPlacer.getDecalCategories()
		if cats and next(cats) then syncDecals() end
	end
end

function widget:Shutdown()
	Spring.SDLStopTextInput()
	if WG.RmlContextManager and WG.RmlContextManager.unregisterDocument then
		WG.RmlContextManager.unregisterDocument("decal_placer")
	end

	if widgetState.rmlContext and widgetState.dmHandle then
		widgetState.rmlContext:RemoveDataModel(MODEL_NAME)
		widgetState.dmHandle = nil
	end

	if widgetState.document then
		widgetState.document:Close()
		widgetState.document = nil
	end

	widgetState.rmlContext = nil
	widgetState.rootElement = nil

	Bake.shutdown()
end

