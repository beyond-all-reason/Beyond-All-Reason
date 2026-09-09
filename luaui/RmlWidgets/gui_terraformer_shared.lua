if not RmlUi then
	return
end

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Terraformer Shared RmlUi Helpers",
		desc = "Feature-owned shared helpers (DP-ratio, document registry, draggable panels, scrollable panel bodies) used by the realtime terraformer RmlUi widgets: terraform brush, weather brush, feature placer and decal placer.",
		author = "PtaQ",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = -999999,
		enabled = false,
	}
end

local WG = WG
local Spring = Spring

local function calculateDpRatio()
	local viewSizeX, viewSizeY = Spring.GetViewGeometry()
	local userScale = Spring.GetConfigFloat("ui_scale", 1)
	local baseWidth = 1920
	local baseHeight = 1080
	local resFactor = math.min(viewSizeX / baseWidth, viewSizeY / baseHeight)
	local dpRatio = resFactor * userScale
	return math.floor(dpRatio * 100) / 100
end

local currentDpRatio = calculateDpRatio()

WG.TerraformerShared = WG.TerraformerShared or {}

-- Shared accessor so widgets don't reimplement calculateDpRatio().
-- Returns the current scale factor (resolution_factor * ui_scale), matching
-- whatever the shared RmlUi context is currently using.
WG.TerraformerShared.getDpRatio = function()
	return currentDpRatio
end

-- Cross-widget DOM-read registry. Widgets that want to be snap targets (or
-- otherwise have their rect read by a sibling widget) should register their
-- root document after LoadDocument(), and unregister on Shutdown().
-- Readers call getElementRect(docName, elementId) to pull live pixel-space
-- layout off the target element instead of mirroring position through WG.*.
local registeredDocuments = {}

-- === Scrollable panel bodies ===
-- Every floating terraformer window pins its header and puts the rest of its
-- content in a `.tf-panel-body` scroll box (see the RML files). RCSS can only
-- give those a fixed vh cap, which is wrong for a window that can be dragged
-- anywhere: a panel near the top of the screen has far more room below it than
-- one near the bottom. So the cap is recomputed here from each window's live
-- position and the viewport height. Bounding the height also lets the drag
-- clamp keep a window fully on-screen.
local panelBodies = {} -- [docName] = { {root=, body=, lastStyle=}, ... }
local panelBodyTick = 0
local wheelHeld = false
local PANEL_BODY_MIN_PX = 120
-- Covers the window's bottom padding (the scroll box does not reach the frame
-- edge) plus a couple of pixels of breathing room at the screen edge.
local PANEL_BODY_GAP_PX = 18
local PANEL_BODY_POLL_FRAMES = 15

local function collectPanelBodies(docName)
	local doc = registeredDocuments[docName]
	local list = {}
	if doc then
		local found = doc:QuerySelectorAll(".tf-panel-body")
		if found then
			for i = 1, #found do
				local bodyEl = found[i]
				local rootEl = bodyEl.parent_node
				if rootEl then
					list[#list + 1] = { root = rootEl, body = bodyEl }
				end
			end
		end
	end
	panelBodies[docName] = list
	return list
end

local function sizePanelBodies()
	local _, vsy = Spring.GetViewGeometry()
	if not vsy or vsy <= 0 then
		return
	end
	for docName in pairs(registeredDocuments) do
		-- Empty is not cached: a document can register before its body element
		-- exists, and the retry costs one selector query per idle document.
		local list = panelBodies[docName]
		if not list or #list == 0 then
			list = collectPanelBodies(docName)
		end
		for i = 1, #list do
			local e = list[i]
			-- A window hidden by data-if (or a `hidden` class) has no height;
			-- skip it and size it on the first tick after it is shown.
			if e.root.offset_height > 0 then
				-- body.offset_top is the pinned header's height (the window
				-- root is the offset parent), so this is "screen bottom minus
				-- where the scroll box starts", less a small breathing gap.
				local avail = vsy - e.root.offset_top - e.body.offset_top - PANEL_BODY_GAP_PX
				if avail < PANEL_BODY_MIN_PX then
					avail = PANEL_BODY_MIN_PX
				end
				avail = math.floor(avail)
				local style = "max-height: " .. avail .. "px;"
				-- A locked slider owns the mouse wheel (the brush drives it
				-- from anywhere on screen), so panel scrolling stands down
				-- while one is armed rather than fighting over the cursor.
				if wheelHeld then
					style = style .. " overflow-y: hidden;"
				end
				if e.lastStyle ~= style then
					e.lastStyle = style
					e.body:SetAttribute("style", style)
				end
			end
		end
	end
end

-- Re-cap every registered document's panel bodies right now. Widgets call this
-- after something that changes the space below a window (end of a drag).
WG.TerraformerShared.refreshPanelBodies = function()
	panelBodyTick = PANEL_BODY_POLL_FRAMES
	sizePanelBodies()
end

-- Tell the panels that something else (a locked brush slider) currently owns
-- the mouse wheel, so they stop scrolling until it is released.
WG.TerraformerShared.setWheelHeld = function(held)
	held = held and true or false
	if held ~= wheelHeld then
		wheelHeld = held
		WG.TerraformerShared.refreshPanelBodies()
	end
end

WG.TerraformerShared.registerDocument = function(name, document)
	if name and document then
		registeredDocuments[name] = document
		-- Any cached body handles belong to the previous document instance.
		panelBodies[name] = nil
	end
end

WG.TerraformerShared.unregisterDocument = function(name)
	if name then
		registeredDocuments[name] = nil
		panelBodies[name] = nil
	end
end

WG.TerraformerShared.getDocument = function(name)
	return registeredDocuments[name]
end

WG.TerraformerShared.getElementRect = function(docName, elementId)
	local doc = registeredDocuments[docName]
	if not doc then
		return nil
	end
	local el = elementId and doc:GetElementById(elementId) or nil
	if not el then
		return nil
	end
	local w = el.offset_width
	local h = el.offset_height
	if not w or w <= 0 then
		return nil
	end
	return {
		left = el.offset_left,
		top = el.offset_top,
		width = w,
		height = h or 0,
	}
end

-- Shared drag-and-drop helper for floating panels.
-- Sets up mousedown on handleId + mouseup on doc, returns a handle with tick().
-- Call handle.tick() every frame from widget:Update() while the widget is alive.
--
-- opts fields (all optional):
--   snapThreshold (number, default 30) — pixel snap distance for edges + panel snap
--   onDragStart   (function)           — called on mousedown (e.g. set userDragged)
--   snapDocName   (string, default "terraform_brush") — registered document to snap to
--   snapElementId (string, default "tf-root")         — element within that document
WG.TerraformerShared.attachDraggable = function(doc, handleId, rootEl, opts)
	if not doc or not rootEl then
		return { tick = function() end }
	end
	local handleEl = doc:GetElementById(handleId)
	if not handleEl then
		return { tick = function() end }
	end

	local snapThreshold = (opts and opts.snapThreshold) or 30
	local onDragStart = opts and opts.onDragStart
	local snapDocName = (opts and opts.snapDocName) or "terraform_brush"
	local snapElementId = (opts and opts.snapElementId) or "tf-root"

	local ds = {
		active = false,
		rootEl = nil,
		offsetX = 0,
		offsetY = 0,
		ew = 0,
		eh = 0,
		vsx = 0,
		vsy = 0,
		lastX = -1,
		lastY = -1,
	}

	handleEl:AddEventListener("mousedown", function(event)
		local p = event.parameters
		if not p or (p.button and p.button ~= 0) then
			return
		end
		local mx, my = Spring.GetMouseState()
		local vsx, vsy = Spring.GetViewGeometry()
		ds.active = true
		ds.rootEl = rootEl
		ds.offsetX = mx - rootEl.offset_left
		ds.offsetY = (vsx > 0 and vsy > 0) and ((vsy - my) - rootEl.offset_top) or 0
		ds.ew = rootEl.offset_width
		ds.eh = rootEl.offset_height
		ds.vsx = vsx
		ds.vsy = vsy
		ds.lastX = -1
		ds.lastY = -1
		if onDragStart then
			onDragStart()
		end
		event:StopPropagation()
	end, false)

	doc:AddEventListener("mouseup", function()
		if ds.active then
			ds.active = false
			ds.rootEl = nil
			-- The window moved, so the room left below it changed. Guarded:
			-- a document can outlive this widget's Shutdown.
			if WG.TerraformerShared and WG.TerraformerShared.refreshPanelBodies then
				WG.TerraformerShared.refreshPanelBodies()
			end
		end
	end, false)

	local T = snapThreshold
	return {
		tick = function()
			if not ds.active or not ds.rootEl then
				return
			end
			local mx, my, _, _, _, offscreen = Spring.GetMouseState()
			if offscreen then
				return
			end
			local vsx, vsy = ds.vsx, ds.vsy
			local ew, eh = ds.ew, ds.eh
			local newX = mx - ds.offsetX
			local newY = (vsy - my) - ds.offsetY

			-- Clamp to viewport
			if newX < 0 then
				newX = 0
			elseif newX + ew > vsx then
				newX = vsx - ew
			end
			if newY < 0 then
				newY = 0
			elseif newY + eh > vsy then
				newY = vsy - eh
			end

			-- Snap to screen edges
			if newX < T then
				newX = 0
			elseif vsx - newX - ew < T then
				newX = vsx - ew
			end
			if newY < T then
				newY = 0
			elseif vsy - newY - eh < T then
				newY = vsy - eh
			end

			-- Snap to registered panel
			local snapTarget = WG.TerraformerShared.getElementRect(snapDocName, snapElementId)
			if snapTarget then
				local ox, oy = snapTarget.left, snapTarget.top
				local oR = ox + (snapTarget.width or 0)
				local oB = oy + (snapTarget.height or 0)
				local newR, newB = newX + ew, newY + eh
				if newY < oB and newB > oy then
					local d = newX - oR
					if d > -T and d < T then
						newX = oR
					else
						d = newR - ox
						if d > -T and d < T then
							newX = ox - ew
						end
					end
				end
				if newX < oR and newR > ox then
					local d = newY - oB
					if d > -T and d < T then
						newY = oB
					else
						d = newB - oy
						if d > -T and d < T then
							newY = oy - eh
						end
					end
				end
			end

			local ix = math.floor(newX)
			local iy = math.floor(newY)
			if ix ~= ds.lastX or iy ~= ds.lastY then
				ds.lastX = ix
				ds.lastY = iy
				ds.rootEl.style.left = ix .. "px"
				ds.rootEl.style.top = iy .. "px"
			end
		end,
	}
end

function widget:Update()
	-- Panel bodies are re-capped on a poll rather than on events: a window can
	-- change the space below it by being dragged, by a resize, or by simply
	-- being opened, and the reads are cheap.
	panelBodyTick = panelBodyTick - 1
	if panelBodyTick <= 0 then
		panelBodyTick = PANEL_BODY_POLL_FRAMES
		sizePanelBodies()
	end
end

function widget:ViewResize()
	currentDpRatio = calculateDpRatio()
	WG.TerraformerShared.refreshPanelBodies()
end

function widget:Shutdown()
	if WG.TerraformerShared then
		WG.TerraformerShared.getDpRatio = nil
		WG.TerraformerShared.registerDocument = nil
		WG.TerraformerShared.unregisterDocument = nil
		WG.TerraformerShared.getDocument = nil
		WG.TerraformerShared.getElementRect = nil
		WG.TerraformerShared.attachDraggable = nil
		WG.TerraformerShared.refreshPanelBodies = nil
		WG.TerraformerShared.setWheelHeld = nil
	end
	registeredDocuments = {}
	panelBodies = {}
end
