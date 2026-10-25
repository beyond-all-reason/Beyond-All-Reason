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
	-- Dual-screen: panels live on the free screen; scale off it, height-keyed, same as
	-- rml_context_manager, or the two disagree about what a dp is.
	if Spring.GetDualViewGeometry then
		local dualW, dualH = Spring.GetDualViewGeometry()
		if type(dualW) == "number" and dualW > 0 then
			viewSizeX, viewSizeY = math.max(dualW, math.floor(dualH * 1920 / 1080)), dualH
		end
	end
	local userScale = Spring.GetConfigFloat("ui_scale", 1)
	local baseWidth = 1920
	local baseHeight = 1080
	local resFactor = math.min(viewSizeX / baseWidth, viewSizeY / baseHeight)
	local dpRatio = resFactor * userScale
	return math.floor(dpRatio * 100) / 100
end

local currentDpRatio = calculateDpRatio()

--- Multi-screen: a panel dropped on the WORLD screen takes that screen's scale; dropped
--- back on the free screen it inherits the context's ratio. Per document, so panels left
--- behind keep their size. Needs the engine's per-document dp override (recoil_dpi
--- build); on a stock engine the property does not exist and this does nothing.
local function applyScreenScale(rootEl)
	if not rootEl then
		return
	end
	local vsx, vsy, viewPosX = Spring.GetViewGeometry()
	local winW = Spring.GetWindowGeometry()
	if not winW or not vsx or winW <= vsx then
		return -- one screen, one scale
	end
	local doc = rootEl.owner_document
	if not doc then
		return
	end
	local centerX = (rootEl.absolute_left or 0) + (rootEl.offset_width or 0) * 0.5
	local onWorld = centerX >= (viewPosX or 0) and centerX < (viewPosX or 0) + vsx
	local userScale = Spring.GetConfigFloat("ui_scale", 1)
	local worldDp = math.floor((vsy / 1080) * userScale * 100) / 100
	pcall(function()
		doc.dp_ratio_override = onWorld and worldDp or 0
	end)
end

WG.TerraformerShared = WG.TerraformerShared or {}

-- Exported for panels that still carry their own drag code (the brush's main windows),
-- so a drop on the other screen rescales there too.
WG.TerraformerShared.applyScreenScale = applyScreenScale

-- Shared accessor so widgets don't reimplement calculateDpRatio().
---@return number dpRatio Current scale factor `resolution_factor * ui_scale`, matching the shared RmlUi context.
WG.TerraformerShared.getDpRatio = function()
	return currentDpRatio
end

-- Cross-widget DOM-read registry. A widget that is a snap target (or whose rect a
-- sibling reads) registers its document after LoadDocument() and unregisters on
-- Shutdown(). Readers call getElementRect(docName, elementId) for live layout
-- instead of mirroring positions through WG.
local registeredDocuments = {}

-- === Scrollable panel bodies ===
-- Floating windows pin their header and scroll the rest in a `.tf-panel-body`.
-- RCSS only allows a fixed vh cap, wrong for a window dragged anywhere, so the cap
-- is recomputed from each window's live position. It also lets the drag clamp keep
-- a window fully on screen.
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
				-- body.offset_top is the pinned header's height (the root is the offset
				-- parent): screen bottom minus where the scroll box starts, less a gap.
				local avail = vsy - e.root.offset_top - e.body.offset_top - PANEL_BODY_GAP_PX
				if avail < PANEL_BODY_MIN_PX then
					avail = PANEL_BODY_MIN_PX
				end
				avail = math.floor(avail)
				local style = "max-height: " .. avail .. "px;"
				-- A locked slider owns the mouse wheel (the brush drives it from
				-- anywhere on screen), so panel scrolling stands down meanwhile.
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

---Registers a document so sibling widgets can read its live layout.
---Call after `LoadDocument()`; pair with `unregisterDocument` on Shutdown.
---@param name string?
---@param document RmlUi.Document?
WG.TerraformerShared.registerDocument = function(name, document)
	if name and document then
		registeredDocuments[name] = document
		-- Any cached body handles belong to the previous document instance.
		panelBodies[name] = nil
	end
end

---Removes a document from the cross-widget registry.
---@param name string?
WG.TerraformerShared.unregisterDocument = function(name)
	if name then
		registeredDocuments[name] = nil
		panelBodies[name] = nil
	end
end

--------------------------------------------------------------------------------
-- Where the suite's windows are
--------------------------------------------------------------------------------

--- Tools that draw in the WORLD need to know when the pointer is over ANY suite window,
--- not only their own, or their ground cursor keeps drawing under another tool's window.
---
--- A provider returns one rect, an array of them, or nil while its windows are closed.
--- Rects are in Spring screen coordinates (y = 0 at the bottom, as `Spring.GetMouseState`
--- reports), so a provider flips RmlUi's downward y: `topY = vsy - offset_top`.
local boundsProviders = {}

---@param name string?
---@param provider fun(): TerraformBrushPanelBounds|TerraformBrushPanelBounds[]|nil
WG.TerraformerShared.registerBounds = function(name, provider)
	if name and type(provider) == "function" then
		boundsProviders[name] = provider
	end
end

---@param name string?
WG.TerraformerShared.unregisterBounds = function(name)
	if name then
		boundsProviders[name] = nil
	end
end

--- Every suite window currently on screen, flattened.
---
--- `Spring.GetMouseState` x is view-relative: the engine subtracts the view's x offset,
--- which is non-zero once dual-screen mode parks the world on one half of the window.
--- Providers report RmlUi window-space x, so the offset is removed here, once, for every tool.
---@return TerraformBrushPanelBounds[] rects
WG.TerraformerShared.getPanelRects = function()
	local _, _, viewPosX = Spring.GetViewGeometry()
	viewPosX = viewPosX or 0
	local rects = {}
	local function take(rect)
		rects[#rects + 1] = {
			left = rect.left - viewPosX,
			right = rect.right - viewPosX,
			topY = rect.topY,
			bottomY = rect.bottomY,
		}
	end
	for _, provider in pairs(boundsProviders) do
		-- pcall: a provider may read elements of a closed document, and one broken
		-- panel must not blind every tool to the others.
		local ok, result = pcall(provider)
		if ok and type(result) == "table" then
			if result.left then
				take(result)
			else
				for _, rect in ipairs(result) do
					if type(rect) == "table" and rect.left then
						take(rect)
					end
				end
			end
		end
	end
	return rects
end

--- The suite window under this screen point, or nil.
---@param mx number?
---@param my number?
---@return TerraformBrushPanelBounds? rect
WG.TerraformerShared.getPanelRectAt = function(mx, my)
	if not (mx and my) then
		return nil
	end
	for _, rect in ipairs(WG.TerraformerShared.getPanelRects()) do
		if mx >= rect.left and mx <= rect.right and my >= rect.bottomY and my <= rect.topY then
			return rect
		end
	end
	return nil
end

--- Bring a registered panel to the front of the shared context. Each widget owns its own
--- RmlUi document and RCSS z-index only orders elements inside one document, so
--- PullToFront is the only way to stack the brush against the mission editor.
---@param name string
WG.TerraformerShared.bringToFront = function(name)
	local doc = registeredDocuments[name]
	if doc and doc.PullToFront then
		pcall(function()
			doc:PullToFront()
		end)
	end
end

--- Raise a panel whenever the user presses inside it, so windows stack in the order they
--- were last touched. The event is not stopped: the press still reaches its target.
---@param name string
---@param rootEl RmlUi.Element?
WG.TerraformerShared.raiseOnPress = function(name, rootEl)
	if not rootEl or not rootEl.AddEventListener then
		return
	end
	rootEl:AddEventListener("mousedown", function()
		WG.TerraformerShared.bringToFront(name)
	end, false)
end

---A registered element's live layout, in pixel space.
---@class TerraformerElementRect
---@field left number
---@field top number
---@field width number
---@field height number

---Reads live pixel-space layout off an element of a registered document.
---@param docName string
---@param elementId string?
---@return TerraformerElementRect? rect `nil` when the document or element is missing,
---or the element has no width yet.
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

---Options accepted by `attachDraggable`.
---@class TerraformerDraggableOpts
---@field snapThreshold number? Pixel snap distance for edges and panel snap. Defaults to `30`.
---@field onDragStart fun()? Called on mousedown, e.g. to record that the user moved the panel.
---@field snapDocName string? Registered document to snap against. Defaults to `"terraform_brush"`.
---@field snapElementId string? Element within that document. Defaults to `"tf-root"`.

---The value returned by `attachDraggable`.
---@class TerraformerDraggable
---@field tick fun() Call every frame from `widget:Update()` while the widget is alive.

---Makes a floating panel draggable by a handle element, with edge and panel snapping.
---@param doc RmlUi.Document?
---@param handleId string Id of the element used as the drag handle.
---@param rootEl RmlUi.Element? The panel being moved.
---@param opts TerraformerDraggableOpts?
---@return TerraformerDraggable handle A no-op handle when `doc`, `rootEl` or the handle element is missing.
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
		-- Clamp to the WINDOW, not the world view: in dual-screen mode the window spans
		-- both monitors and the point is dragging a panel onto the other one. The y flip
		-- stays on the view height, which the horizontal split leaves equal.
		local winX = Spring.GetWindowGeometry()
		ds.active = true
		ds.rootEl = rootEl
		ds.offsetX = mx - rootEl.offset_left
		ds.offsetY = (vsx > 0 and vsy > 0) and ((vsy - my) - rootEl.offset_top) or 0
		ds.ew = rootEl.offset_width
		ds.eh = rootEl.offset_height
		ds.vsx = (winX and winX > vsx) and winX or vsx
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
			local moved = ds.rootEl
			ds.active = false
			ds.rootEl = nil
			-- The room below the window changed. Guarded: a document can outlive
			-- this widget's Shutdown.
			if WG.TerraformerShared and WG.TerraformerShared.refreshPanelBodies then
				WG.TerraformerShared.refreshPanelBodies()
			end
			applyScreenScale(moved)
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
	-- Polled rather than event-driven: a drag, a resize or simply opening a window
	-- changes the space below it, and the reads are cheap.
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
		WG.TerraformerShared.getElementRect = nil
		WG.TerraformerShared.attachDraggable = nil
		WG.TerraformerShared.refreshPanelBodies = nil
		WG.TerraformerShared.setWheelHeld = nil
	end
	registeredDocuments = {}
	panelBodies = {}
end
