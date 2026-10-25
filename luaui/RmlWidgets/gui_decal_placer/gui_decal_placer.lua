if not RmlUi then
	return
end

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Decal Placer UI",
		desc = "RmlUI library panel for the decal placer (terraform brush companion)",
		author = "PtaQ",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 1000002,
		enabled = false,
	}
end

local RML_PATH = "luaui/RmlWidgets/gui_decal_placer/gui_decal_placer.rml"
local MODEL_NAME = "decal_placer_model"

local WG = WG

local INITIAL_LEFT_VW = 60
local INITIAL_TOP_VH = 10

----------------------------------------------------------------
-- Type definitions (Lua language server only, no runtime cost)
----------------------------------------------------------------

---Shape of the data model bound to the RML document.
---@class DecalPlacerModel
---@field search string               -- data-value on #dp-search
---@field selectedCount integer       -- {{selectedCount}} in tile header
---@field onCategorySelect fun(event: any, key: string)       -- data-event-click on category button
---@field onSearchFocus fun(event: any)                       -- data-event-focus on search input
---@field onSearchBlur fun(event: any)                        -- data-event-blur on search input
---@field onSearchChange fun(event: any)                      -- data-event-change on search input
---@field onSearchClear fun(event: any)                       -- data-event-click on clear button
-- Panel visibility is not a model field: document:Show()/Hide() drops the whole
-- document from RmlUi's active set, so a closed panel costs nothing.
-- The tile grid is built with CreateElement/AppendChild because Recoil's data-for
-- does not pass the iterator scope to child bindings ("Could not find variable").

---@class WidgetState
---@field rmlContext any
---@field document any
---@field dmHandle DecalPlacerModel? -- nil until widget:Initialize() opens the data model
---@field rootElement any

---@type WidgetState
local widgetState = {
	rmlContext = nil,
	document = nil,
	dmHandle = nil,
	rootElement = nil,
}

-- Declared above initialModel so its handlers capture the local slot; the
-- function is assigned further down.
local syncDecals -- forward decl, assigned further down
local lastSearchFilter = ""

-- Selected category keys. Plain click selects one, Shift+click toggles one in or
-- out; "all" excludes the specific categories. Mirrored to dm dcCat* flags for
-- the data-class-active highlights.
local selectedDecalCats = { all = true }
local DECAL_CAT_KEYS =
	{ "all", "scars", "explosions", "tracks", "builds", "footprints", "scorch", "groundplates", "other" }
local DECAL_CAT_FLAG = {
	all = "dcCatAll",
	scars = "dcCatScars",
	explosions = "dcCatExplosions",
	tracks = "dcCatTracks",
	builds = "dcCatBuilds",
	footprints = "dcCatFootprints",
	scorch = "dcCatScorch",
	groundplates = "dcCatGroundplates",
	other = "dcCatOther",
}
local function applyDecalCatFlags()
	local dm = widgetState.dmHandle
	if not dm then
		return
	end
	for _, key in ipairs(DECAL_CAT_KEYS) do
		dm[DECAL_CAT_FLAG[key]] = selectedDecalCats[key] == true
	end
end

---@type DecalPlacerModel
local initialModel = {
	search = "",
	selectedCount = 0,
	dcCatAll = true,
	dcCatScars = false,
	dcCatExplosions = false,
	dcCatTracks = false,
	dcCatBuilds = false,
	dcCatFootprints = false,
	dcCatScorch = false,
	dcCatGroundplates = false,
	dcCatOther = false,

	onCategorySelect = function(_event, key)
		local dm = widgetState.dmHandle
		if not dm then
			return
		end
		local _, _, _, shift = Spring.GetModKeyState()
		if not shift or key == "all" then
			-- Plain click (or "All"): select exactly this category.
			selectedDecalCats = { [key] = true }
		else
			-- Shift+click: toggle this category in the additive set.
			selectedDecalCats.all = nil
			if selectedDecalCats[key] then
				selectedDecalCats[key] = nil
			else
				selectedDecalCats[key] = true
			end
			if not next(selectedDecalCats) then
				selectedDecalCats = { all = true }
			end
		end
		applyDecalCatFlags()
		-- syncDecals is the forward-declared module local, assigned below.
		syncDecals()
	end,

	onSearchFocus = function(_event)
		Spring.SDLStartTextInput()
	end,

	onSearchBlur = function(_event)
		Spring.SDLStopTextInput()
	end,

	-- RmlUi writes data-value="search" to dm.search only after the change event
	-- fires, so read the input element directly.
	onSearchChange = function(_event)
		local doc = widgetState.document
		local el = doc and doc:GetElementById("dp-search")
		local val = el and el:GetAttribute("value") or ""
		if val == lastSearchFilter then
			return
		end
		lastSearchFilter = val
		syncDecals()
	end,

	onSearchClear = function(_event)
		local dm = widgetState.dmHandle
		if not dm then
			return
		end
		dm.search = ""
		lastSearchFilter = ""
		syncDecals()
	end,
}

-- Last document:Show/Hide state, so setVisible() does not repeat calls every frame.
local documentVisible = false

-- Guard for the lazy first sync: WG.DecalPlacer may have no categories yet in
-- widget:Initialize, so Update retries until they arrive. Later syncs come from
-- state changes (category click, filter change); Update does not poll.
local firstSyncDone = false

local userDragged = false

----------------------------------------------------------------
-- Document-level visibility: a hidden document has no layout, draw or event
-- cost, unlike toggling a CSS class.
----------------------------------------------------------------
local function setVisible(visible)
	if visible == documentVisible then
		return
	end
	local doc = widgetState.document
	if not doc then
		return
	end
	documentVisible = visible
	if visible then
		doc:Show()
	else
		doc:Hide()
	end
end

-- Show the panel while the tool is active. The X button deactivates the tool
-- (widget:OnQuit), so tool state is the single source of truth. Polled once per
-- Update; a WG.DecalPlacer change hook would remove the poll.
-- Returns whether the tool is engaged so callers can bail early.
local function syncVisibilityFromTool()
	local state = WG.DecalPlacer and WG.DecalPlacer.getState()
	local toolActive = state and state.active or false
	setVisible(toolActive)
	return toolActive
end

----------------------------------------------------------------
-- Decal preview texture lookup
----------------------------------------------------------------
local previewPaths = {} -- { [decalName] = filePath or false }
local previewIndexBuilt = false
local fileIndex = {} -- { [basename_lower] = fullPath }

local function indexDir(path)
	local files = VFS.DirList(path, "*", VFS.RAW_FIRST)
	if not files then
		return
	end
	for _, f in ipairs(files) do
		local base = f:match("([^/\\]+)$") or f
		local stem = base:match("^(.+)%.[^%.]+$") or base
		fileIndex[stem:lower()] = f
	end
end

local function buildFileIndex()
	if previewIndexBuilt then
		return
	end
	previewIndexBuilt = true
	indexDir("bitmaps/decals/")
	indexDir("bitmaps/scars/")
	indexDir("bitmaps/tracks/")
	indexDir("bitmaps/Other/")
	indexDir("bitmaps/projectiletextures/")
end

local function findPreviewPath(decalName)
	if previewPaths[decalName] ~= nil then
		return previewPaths[decalName]
	end
	buildFileIndex()
	local stem = (decalName:match("([^/\\]+)$") or decalName)
	stem = (stem:match("^(.+)%.[^%.]+$") or stem):lower()
	local found = fileIndex[stem]
	previewPaths[decalName] = found or false
	return found
end

----------------------------------------------------------------
-- Bakes channel-encoded BMP atlases (mainscars, tracks, footprints) into PNGs
-- an <img> can show. API and design notes in dp_preview_bake.lua.
----------------------------------------------------------------
local Bake = require("luaui/RmlWidgets/gui_decal_placer/dp_preview_bake")
local PREVIEW_CACHE_DIR = "Terraform Brush/DecalPreviews/"

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------
local function buildRootStyle()
	-- Width lives in RCSS (.dp-root); only the position is set here.
	return string.format("left: %.2fvw; top: %.2fvh;", INITIAL_LEFT_VW, INITIAL_TOP_VH)
end

----------------------------------------------------------------
-- Tile elements by decal name, for selection visuals without a full DOM rebuild.
-- Reset on every syncDecals.
local tileElements = {}

-- Rebuild the tile grid from WG state and the active filter/category (built by
-- hand, see the data-for note at the top). Safe to call on category change,
-- filter change or bake finish.
----------------------------------------------------------------
syncDecals = function()
	local dm = widgetState.dmHandle
	if not WG.DecalPlacer then
		return
	end
	if not dm then
		return
	end
	local doc = widgetState.document
	if not doc then
		return
	end

	local listEl = doc:GetElementById("dp-tile-list")
	if not listEl then
		return
	end

	local categories = WG.DecalPlacer.getDecalCategories()
	local order = WG.DecalPlacer.getCategoryOrder()
	if not categories or not order then
		return
	end

	local state = WG.DecalPlacer.getState()
	local selectedSet = state and state.selectedSet or {}
	local lowerFilter = (lastSearchFilter or ""):lower()
	local showAll = selectedDecalCats.all or not next(selectedDecalCats)

	-- Full DOM rebuild
	listEl.inner_rml = ""
	tileElements = {}

	for _, catName in ipairs(order) do
		if showAll or selectedDecalCats[catName] then
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
							if not WG.DecalPlacer then
								return
							end
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
						-- Wrap in dp-tile-host so the RCSS 84dp x 84dp sizing applies
						local hostEl = doc:CreateElement("div")
						hostEl:SetClass("dp-tile-host", true)
						hostEl:AppendChild(itemEl)
						listEl:AppendChild(hostEl)
					end
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
	-- The panel is the tool's whole UI, so closing it deactivates the tool;
	-- otherwise the main panel keeps DECALS highlighted. syncVisibilityFromTool
	-- hides the document on the next Update.
	if WG.DecalPlacer then
		WG.DecalPlacer.clearSelectedDecals()
		WG.DecalPlacer.deactivate()
	end
end

function widget:OnClearSelection()
	if not WG.DecalPlacer then
		return
	end
	WG.DecalPlacer.clearSelectedDecals()
	syncDecals()
end

----------------------------------------------------------------
-- Drag handle wiring (the only imperative listener; the rest is in the RML).
----------------------------------------------------------------
local function wireDragHandle()
	local doc = widgetState.document
	local rootEl = widgetState.rootElement
	if not doc or not rootEl then
		return
	end
	if WG.TerraformerShared and WG.TerraformerShared.attachDraggable then
		widgetState.dragHandle = WG.TerraformerShared.attachDraggable(doc, "dp-handle", rootEl, {
			onDragStart = function()
				userDragged = true
			end,
		})
	end
end

----------------------------------------------------------------
-- Lifecycle
----------------------------------------------------------------
function widget:Initialize()
	Spring.CreateDir(PREVIEW_CACHE_DIR)
	Bake.init(PREVIEW_CACHE_DIR)
	widgetState.rmlContext = RmlUi.GetContext("shared")
	if not widgetState.rmlContext then
		return false
	end

	widgetState.dmHandle = widgetState.rmlContext:OpenDataModel(MODEL_NAME, initialModel, self)
	if not widgetState.dmHandle then
		return false
	end

	widgetState.document = widgetState.rmlContext:LoadDocument(RML_PATH, self)
	if not widgetState.document then
		widget:Shutdown()
		return false
	end

	if WG.TerraformerShared and WG.TerraformerShared.registerDocument then
		WG.TerraformerShared.registerDocument("decal_placer", widgetState.document)
	end

	widgetState.document:ReloadStyleSheet()

	-- Starts hidden; Update shows it the first time the DECALS tool is picked.
	widgetState.document:Hide()
	documentVisible = false

	widgetState.rootElement = widgetState.document:GetElementById("dp-root")

	widgetState.rootElement:SetAttribute("style", buildRootStyle())

	wireDragHandle()
	-- The tile list is not built here: that runs the decal enumeration, bitmap-dir
	-- scans and the bake queue, real GL and disk work at every match start for
	-- players who never open the editor. Update builds it on first activation.
end

-- Drain the bake queue here: gl.RenderToTexture only works in draw callbacks.
function widget:DrawScreen()
	Bake.drainQueue()
end

function widget:Update()
	-- Rebuild the tiles once a batch of bakes finishes so the new PNGs show.
	if Bake.consumeResync() then
		syncDecals()
	end

	-- Window drag
	if widgetState.dragHandle then
		widgetState.dragHandle.tick()
	end

	if not syncVisibilityFromTool() then
		return
	end

	-- Sit next to the terraform main panel until the user drags the window
	local mainPanel = WG.TerraformerShared
		and WG.TerraformerShared.getElementRect
		and WG.TerraformerShared.getElementRect("terraform_brush", "tf-root")
	if not userDragged and mainPanel and widgetState.rootElement then
		local myWidth = widgetState.rootElement.offset_width
		if myWidth and myWidth > 0 then
			local gap = 8
			widgetState.rootElement:SetAttribute(
				"style",
				string.format("left: %dpx; top: %dpx;", mainPanel.left - myWidth - gap, mainPanel.top)
			)
		end
	end

	-- Lazy first build only (see firstSyncDone).
	if not firstSyncDone then
		local cats = WG.DecalPlacer.getDecalCategories()
		if cats and next(cats) then
			syncDecals()
		end
	end
end

function widget:Shutdown()
	Spring.SDLStopTextInput()
	if WG.TerraformerShared and WG.TerraformerShared.unregisterDocument then
		WG.TerraformerShared.unregisterDocument("decal_placer")
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
