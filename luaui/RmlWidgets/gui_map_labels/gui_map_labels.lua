if not RmlUi then
	return
end

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Map Labels UI",
		desc = "Figma-style map comments: colored world-anchored dots with author, text, color coding and a browser window",
		author = "PtaQ",
		date = "2026",
		license = "GNU GPL, v2 or later",
		-- Below cmd_terraform_brush (1000000): MousePress lists iterate ascending
		-- by layer, so label placement clicks are consumed before the brush paints.
		layer = 999999,
		enabled = false,
	}
end

local RML_PATH = "luaui/RmlWidgets/gui_map_labels/gui_map_labels.rml"
local LABELS_DIR = "Terraform Brush/map_labels/"

local COLORS = {
	"#eab308",
	"#f97316",
	"#ef4444",
	"#ec4899",
	"#a855f7",
	"#3b82f6",
	"#06b6d4",
	"#22c55e",
}
local DEFAULT_COLOR = COLORS[1]
local SNIPPET_LEN = 48

local WG = WG
local GetViewGeometry = Spring.GetViewGeometry
local GetMouseState = Spring.GetMouseState
local WorldToScreenCoords = Spring.WorldToScreenCoords
local GetGroundHeight = Spring.GetGroundHeight
local TraceScreenRay = Spring.TraceScreenRay

local state = {
	rmlContext = nil,
	document = nil,
	rootEl = nil,
	dotsLayerEl = nil,
	ghostEl = nil,
	popupEl = nil,
	listEl = nil,
	newBtnEl = nil,
	authorInputEl = nil,
	popupViewEl = nil,
	popupEditEl = nil,
	popupTextEl = nil,
	popupAuthorEl = nil,
	popupDateEl = nil,
	popupDotEl = nil,
	editTextEl = nil,
	colorPopEl = nil,
	colorPickerOpen = false,
	swatchEls = {},
	dragHandle = nil,

	windowOpen = false,
	placing = false,
	labels = {}, -- { {id, x, z, color, author, created, ts, text}, ... }
	nextId = 1,
	authorName = "",
	openLabelId = nil, -- label whose popup is open, or nil
	popupEditing = false,
	popupFresh = false, -- popup opened for a just-placed label (discard if left empty)
	uiDirty = false, -- dots layer + browser list need a rebuild
	dotEls = {}, -- [id] = {el, lastLeft, lastTop, lastHidden}
	ghostLast = nil,
	popupLast = nil,
	draggingId = nil, -- label being dragged by its dot, or nil
	dragMoved = false, -- drag passed the click threshold (suppresses the click)
	dragStartX = 0,
	dragStartY = 0,
	hoverDotId = nil, -- dot under the cursor (suppresses the brush ring)
}

local uiSounds = {
	click = { "LuaUI/Sounds/tock.wav", 0.35 },
	panelOpen = { "LuaUI/Sounds/buildbar_click.wav", 0.3 },
	save = { "LuaUI/Sounds/buildbar_waypoint.wav", 0.5 },
	delete = { "LuaUI/Sounds/buildbar_rem.wav", 0.4 },
	place = { "LuaUI/Sounds/buildbar_add.wav", 0.5 },
}

local function playSound(name)
	local s = uiSounds[name]
	if s then
		Spring.PlaySoundFile(s[1], s[2], "ui")
	end
end

-- ===========================================================================
-- Persistence (one file per map in the Spring write dir)
-- ===========================================================================

local function labelsFilePath()
	local slug = (Game.mapName or "unknown"):gsub("[^%w%-_%. ]", "_")
	-- "labels_" prefix also sidesteps Windows reserved device names (CON, AUX...)
	return LABELS_DIR .. "labels_" .. slug .. ".lua"
end

-- Deterministic serialization: same labels in, byte-identical file out, so a
-- map project that did not change its comments produces a zero diff.
local function serializeLabels(nodate)
	local out = { "-- Map Labels (Terraform Brush map comments)\n" }
	if not nodate then
		out[#out + 1] = "-- saved " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n"
	end
	out[#out + 1] = "return {\n"
	out[#out + 1] = string.format("\tnextId = %d,\n\tlabels = {\n", state.nextId)
	for _, L in ipairs(state.labels) do
		out[#out + 1] = string.format(
			"\t\t{ id = %d, x = %.1f, z = %.1f, color = %q, author = %q, created = %q, ts = %d, text = %q },\n",
			L.id,
			L.x,
			L.z,
			L.color,
			L.author,
			L.created or "",
			L.ts or 0,
			L.text or ""
		)
	end
	out[#out + 1] = "\t},\n}\n"
	return table.concat(out)
end

local function writeLabelsFile(path, nodate)
	local f = io.open(path, "w")
	if not f then
		return false
	end
	f:write(serializeLabels(nodate))
	f:close()
	return true
end

local function saveLabels()
	Spring.CreateDir(LABELS_DIR)
	if not writeLabelsFile(labelsFilePath(), true) then
		Spring.Echo("[Map Labels] Could not write " .. labelsFilePath())
	end
end

-- Raw io (not VFS) so labels written earlier in the same session are seen.
-- Returns a labels array and the next free id, or nil when the file is absent
-- or unreadable (nil, reason).
local function parseLabelsFile(path)
	local f = io.open(path, "r")
	if not f then
		return nil, "not found"
	end
	local raw = f:read("*a")
	f:close()
	if not raw or raw == "" then
		return nil, "empty"
	end
	local ok, data = pcall(function()
		return loadstring(raw)()
	end)
	if not ok or type(data) ~= "table" or type(data.labels) ~= "table" then
		return nil, "parse failed"
	end
	local labels = {}
	for _, L in ipairs(data.labels) do
		if type(L) == "table" and tonumber(L.x) and tonumber(L.z) then
			labels[#labels + 1] = {
				id = tonumber(L.id) or #labels + 1,
				x = tonumber(L.x),
				z = tonumber(L.z),
				color = tostring(L.color or DEFAULT_COLOR),
				author = tostring(L.author or ""),
				created = tostring(L.created or ""),
				ts = tonumber(L.ts) or 0,
				text = tostring(L.text or ""),
			}
		end
	end
	local nextId = math.max(tonumber(data.nextId) or 1, #labels + 1)
	for _, L in ipairs(labels) do
		if L.id >= nextId then
			nextId = L.id + 1
		end
	end
	return labels, nextId
end

local function loadLabels()
	local labels, nextId = parseLabelsFile(labelsFilePath())
	if not labels then
		if nextId == "parse failed" then
			Spring.Echo("[Map Labels] Could not parse " .. labelsFilePath())
		end
		state.labels = {}
		state.nextId = 1
		return
	end
	state.labels = labels
	state.nextId = nextId
end

-- ===========================================================================
-- Helpers
-- ===========================================================================

local function findLabel(id)
	for _, L in ipairs(state.labels) do
		if L.id == id then
			return L
		end
	end
	return nil
end

local function escapeRml(s)
	s = tostring(s or "")
	return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local function renderMultiline(s)
	return (escapeRml(s):gsub("\n", "<br/>"))
end

local function snippet(s)
	s = tostring(s or ""):gsub("%s+", " ")
	if s == "" then
		return "(empty label)"
	end
	if #s > SNIPPET_LEN then
		return escapeRml(s:sub(1, SNIPPET_LEN - 1)) .. "&#8230;"
	end
	return escapeRml(s)
end

local function displayAuthor(L)
	return (L.author and L.author ~= "") and L.author or "Anonymous"
end

local function markDirty()
	state.uiDirty = true
end

-- Cursor-inside test for one of our floating windows.
-- mx is Spring screen X, myTop is Y measured from the top (RmlUi convention).
local function cursorOverRect(el, mx, myTop)
	if not el then
		return false
	end
	local left = el.absolute_left
	local top = el.absolute_top
	local w = el.offset_width
	local h = el.offset_height
	if not left or not w or w <= 0 or not h or h <= 0 then
		return false
	end
	return mx >= left and mx <= left + w and myTop >= top and myTop <= top + h
end

-- ===========================================================================
-- Popup (open comment attached to a dot)
-- ===========================================================================

local function setEditing(on)
	state.popupEditing = on
	if state.popupViewEl then
		state.popupViewEl:SetClass("hidden", on)
	end
	if state.popupEditEl then
		state.popupEditEl:SetClass("hidden", not on)
	end
	if on and state.editTextEl then
		local L = findLabel(state.openLabelId)
		state.editTextEl:SetAttribute("value", (L and L.text) or "")
		pcall(function()
			state.editTextEl:Focus()
		end)
	end
end

local function refreshPopupContent()
	local L = findLabel(state.openLabelId)
	if not L then
		return
	end
	if state.popupAuthorEl then
		state.popupAuthorEl.inner_rml = escapeRml(displayAuthor(L))
	end
	if state.popupDateEl then
		state.popupDateEl.inner_rml = escapeRml(L.created or "")
	end
	if state.popupDotEl then
		state.popupDotEl:SetAttribute("style", "background-color: " .. L.color .. ";")
	end
	if state.popupTextEl then
		state.popupTextEl.inner_rml = (L.text ~= "" and renderMultiline(L.text))
			or '<span style="color: #6b7280;">(empty label)</span>'
	end
	for i, sw in ipairs(state.swatchEls) do
		sw:SetClass("active", COLORS[i] == L.color)
	end
end

local function removeLabel(id)
	for i, L in ipairs(state.labels) do
		if L.id == id then
			table.remove(state.labels, i)
			break
		end
	end
	saveLabels()
	markDirty()
end

local function closeColorPicker()
	state.colorPickerOpen = false
	if state.colorPopEl then
		state.colorPopEl:SetClass("hidden", true)
	end
end

local function openPopup(id, editing, fresh)
	-- Switching away from a freshly placed label that never got text discards it
	if state.popupFresh and state.openLabelId and state.openLabelId ~= id then
		local prev = findLabel(state.openLabelId)
		if prev and (prev.text == nil or prev.text == "") then
			removeLabel(prev.id)
		end
	end
	local L = findLabel(id)
	if not L then
		return
	end
	closeColorPicker()
	state.openLabelId = id
	state.popupFresh = fresh or false
	state.popupLast = nil
	refreshPopupContent()
	setEditing(editing or false)
	if state.popupEl then
		state.popupEl:SetClass("hidden", false)
	end
end

local function closePopup()
	-- Discard a freshly placed label that was never given any text
	if state.popupFresh then
		local L = findLabel(state.openLabelId)
		if L and (L.text == nil or L.text == "") then
			removeLabel(L.id)
		end
	end
	state.openLabelId = nil
	state.popupFresh = false
	setEditing(false)
	closeColorPicker()
	if state.popupEl then
		state.popupEl:SetClass("hidden", true)
	end
	Spring.SDLStopTextInput()
end

-- ===========================================================================
-- Placement mode
-- ===========================================================================

local function setPlacing(on)
	state.placing = on
	if state.newBtnEl then
		state.newBtnEl:SetClass("placing", on)
		state.newBtnEl.inner_rml = on and "CLICK MAP TO PLACE" or "+ NEW LABEL"
	end
	if state.ghostEl then
		state.ghostEl:SetClass("hidden", not on)
	end
	state.ghostLast = nil
end

-- ===========================================================================
-- Window open/close (WG.MapLabels bridge for the terraform header button)
-- ===========================================================================

-- The terraform header button is a master "show comments" switch: turning it
-- off takes the browser window, the world dots and any open comment with it.
local function setWindowOpen(open)
	state.windowOpen = open
	if state.rootEl then
		state.rootEl:SetClass("hidden", not open)
	end
	if state.dotsLayerEl then
		state.dotsLayerEl:SetClass("hidden", not open)
	end
	if not open then
		setPlacing(false)
		closePopup()
		state.hoverDotId = nil
		state.draggingId = nil
		state.dragMoved = false
	end
end

-- ===========================================================================
-- UI rebuild (dots layer + browser list)
-- ===========================================================================

local function rebuildUi()
	local doc = state.document
	if not doc then
		return
	end

	-- World dots
	local layer = state.dotsLayerEl
	if layer then
		layer.inner_rml = ""
		-- The elements those ids referred to are gone
		state.dotEls = {}
		state.hoverDotId = nil
		state.draggingId = nil
		for _, L in ipairs(state.labels) do
			local el = doc:CreateElement("div")
			el:SetClass("ml-dot", true)
			el:SetAttribute("style", "background-color: " .. L.color .. ";")

			local prev = doc:CreateElement("div")
			prev:SetClass("ml-dot-preview", true)
			prev.inner_rml = '<div class="ml-preview-author">'
				.. escapeRml(displayAuthor(L))
				.. '</div><div class="ml-preview-text">'
				.. snippet(L.text)
				.. "</div>"
			el:AppendChild(prev)

			layer:AppendChild(el)
			state.dotEls[L.id] = {
				el = el,
				lastLeft = nil,
				lastTop = nil,
				lastHidden = nil,
				-- screen-space center + radius, refreshed by the Update sync
				cx = nil,
				cy = nil,
				r = 8,
				visible = false,
				lastHovered = nil,
			}
		end
	end

	-- Browser list (newest first)
	local listEl = state.listEl
	if listEl then
		listEl.inner_rml = ""
		local sorted = {}
		for i, L in ipairs(state.labels) do
			sorted[i] = L
		end
		table.sort(sorted, function(a, b)
			return (a.ts or 0) > (b.ts or 0)
		end)

		if #sorted == 0 then
			local empty = doc:CreateElement("div")
			empty:SetClass("ml-empty", true)
			empty.inner_rml = "No labels yet. Click + NEW LABEL, then click the map."
			listEl:AppendChild(empty)
		end

		for _, L in ipairs(sorted) do
			local item = doc:CreateElement("div")
			item:SetClass("ml-item", true)

			local dot = doc:CreateElement("div")
			dot:SetClass("ml-item-dot", true)
			dot:SetAttribute("style", "background-color: " .. L.color .. ";")

			local body = doc:CreateElement("div")
			body:SetClass("ml-item-body", true)
			body.inner_rml = '<div class="ml-item-author">'
				.. escapeRml(displayAuthor(L))
				.. '</div><div class="ml-item-snippet">'
				.. snippet(L.text)
				.. "</div>"

			item:AppendChild(dot)
			item:AppendChild(body)

			local capturedId = L.id
			item:AddEventListener("click", function(ev)
				local target = findLabel(capturedId)
				if target then
					playSound("click")
					local gy = GetGroundHeight(target.x, target.z) or 0
					Spring.SetCameraTarget(target.x, gy, target.z, 0.6)
					openPopup(capturedId, false, false)
				end
				ev:StopPropagation()
			end, false)

			listEl:AppendChild(item)
		end
	end

	-- The open popup may reference edited/deleted content
	if state.openLabelId then
		if findLabel(state.openLabelId) then
			refreshPopupContent()
		else
			closePopup()
		end
	end
end

-- ===========================================================================
-- Declarative event handlers (called from RML via onclick="widget:Foo()")
-- ===========================================================================

function widget:OnQuit()
	playSound("click")
	setWindowOpen(false)
end

function widget:OnNewLabel()
	playSound(state.placing and "click" or "panelOpen")
	setPlacing(not state.placing)
end

function widget:OnAuthorFocus()
	Spring.SDLStartTextInput()
end

function widget:OnAuthorBlur()
	Spring.SDLStopTextInput()
end

function widget:OnAuthorChange()
	local el = state.authorInputEl
	if el then
		state.authorName = tostring(el:GetAttribute("value") or "")
	end
end

function widget:OnPopupEdit()
	playSound("click")
	setEditing(true)
end

function widget:OnPopupDelete()
	playSound("delete")
	local id = state.openLabelId
	state.popupFresh = false
	closePopup()
	if id then
		removeLabel(id)
	end
end

function widget:OnPopupClose()
	playSound("click")
	closePopup()
end

-- Abandons an in-progress edit without applying it. A never-saved label has
-- nothing to fall back to, so it goes away with the popup.
local function cancelEditing()
	if state.editTextEl then
		pcall(function()
			state.editTextEl:Blur()
		end)
	end
	if state.popupFresh then
		closePopup()
	else
		setEditing(false)
		Spring.SDLStopTextInput()
	end
end

function widget:OnEditCancel()
	playSound("click")
	cancelEditing()
end

function widget:OnEditSave()
	local L = findLabel(state.openLabelId)
	if not L then
		closePopup()
		return
	end
	local text = ""
	if state.editTextEl then
		text = tostring(state.editTextEl:GetAttribute("value") or "")
	end
	L.text = text
	if state.authorName ~= "" then
		L.author = state.authorName
	end
	state.popupFresh = false
	playSound("save")
	saveLabels()
	setEditing(false)
	Spring.SDLStopTextInput()
	refreshPopupContent()
	markDirty()
end

function widget:OnTextFocus()
	Spring.SDLStartTextInput()
end

function widget:OnTextBlur()
	Spring.SDLStopTextInput()
end

function widget:OnToggleColorPicker()
	playSound("click")
	state.colorPickerOpen = not state.colorPickerOpen
	if state.colorPopEl then
		state.colorPopEl:SetClass("hidden", not state.colorPickerOpen)
	else
		Spring.Echo("[Map Labels] color picker element not found (ml-color-pop)")
	end
end

function widget:OnPickColor(color)
	local L = findLabel(state.openLabelId)
	if not L or not color then
		return
	end
	playSound("click")
	L.color = color
	closeColorPicker()
	saveLabels()
	refreshPopupContent()
	markDirty()
end

-- ===========================================================================
-- Map interaction: placement clicks, popup dismiss
-- ===========================================================================

function widget:MousePress(mx, my, button)
	-- Clicks over RmlUi elements never reach this callin, so anything here is a
	-- click on the bare map (or other game UI). Dots are pointer-events:none,
	-- so a press on one lands here and is hit-tested against hoverDotId.
	if not state.placing then
		if button == 1 and state.hoverDotId and findLabel(state.hoverDotId) then
			-- Press on a dot: begin a potential drag. Returning true makes us the
			-- mouse owner (MouseRelease routes here) and stops the terrain brush.
			state.draggingId = state.hoverDotId
			state.dragMoved = false
			state.dragStartX = mx
			state.dragStartY = my
			return true
		end
		-- Clicking away dismisses an open comment, Figma-style: an in-progress
		-- edit is cancelled, an open comment is closed. The dismissing click is
		-- consumed (return true) so the active brush does not also fire on it;
		-- the next click reaches the brush normally.
		if state.openLabelId and button == 1 then
			playSound("click")
			if state.popupEditing then
				cancelEditing()
			else
				closePopup()
			end
			return true
		end
		return false
	end

	if button == 3 then
		setPlacing(false)
		playSound("click")
		return true
	end
	if button ~= 1 then
		return false
	end

	local _, pos = TraceScreenRay(mx, my, true)
	if not pos then
		return false
	end

	local x = math.max(0, math.min(Game.mapSizeX, pos[1]))
	local z = math.max(0, math.min(Game.mapSizeZ, pos[3]))
	local L = {
		id = state.nextId,
		x = x,
		z = z,
		color = DEFAULT_COLOR,
		author = (state.authorName ~= "") and state.authorName or "Anonymous",
		created = os.date("%Y-%m-%d %H:%M"),
		ts = os.time(),
		text = "",
	}
	state.nextId = state.nextId + 1
	state.labels[#state.labels + 1] = L

	setPlacing(false)
	playSound("place")
	saveLabels()
	rebuildUi()
	state.uiDirty = false
	openPopup(L.id, true, true)
	return true
end

-- ===========================================================================
-- Per-frame sync: dot positions, popup anchor, ghost cursor
-- ===========================================================================

local function projectLabel(L, vsy)
	local gy = GetGroundHeight(L.x, L.z) or 0
	local sx, sy, sz = WorldToScreenCoords(L.x, gy, L.z)
	if not sx then
		return nil
	end
	return sx, vsy - sy, sz
end

local DRAG_THRESHOLD = 4 -- pixels of travel before a press counts as a drag

-- Ends a dot drag: a real drag saves the new position, a click opens the popup.
local function endDotDrag()
	local id = state.draggingId
	if not id then
		return
	end
	state.draggingId = nil
	local L = findLabel(id)
	if not L then
		state.dragMoved = false
		return
	end
	if state.dragMoved then
		state.dragMoved = false
		playSound("place")
		saveLabels()
	else
		playSound("click")
		openPopup(id, false, false)
	end
end

-- Moves the dragged label to the cursor. Runs before the position sync below so
-- the dot lands under the cursor on the same frame.
local function tickDotDrag()
	if not state.draggingId then
		return
	end
	local mx, my, lmb = GetMouseState()
	local L = findLabel(state.draggingId)
	if not L then
		state.draggingId = nil
		state.dragMoved = false
		return
	end
	-- MouseRelease normally ends the drag; this catches a release we never saw
	-- (e.g. focus loss while the button was down).
	if not lmb then
		endDotDrag()
		return
	end

	if not state.dragMoved then
		local dx = mx - state.dragStartX
		local dy = my - state.dragStartY
		if (dx * dx + dy * dy) < (DRAG_THRESHOLD * DRAG_THRESHOLD) then
			return
		end
		state.dragMoved = true
	end

	local _, pos = TraceScreenRay(mx, my, true)
	if pos then
		L.x = math.max(0, math.min(Game.mapSizeX, pos[1]))
		L.z = math.max(0, math.min(Game.mapSizeZ, pos[3]))
	end
end

function widget:MouseRelease(mx, my, button)
	if button == 1 and state.draggingId then
		endDotDrag()
	end
	-- Release mouse ownership so other widgets get input again
	return false
end

function widget:Update()
	if state.dragHandle then
		state.dragHandle.tick()
	end
	if not state.document then
		return
	end

	tickDotDrag()

	-- Rebuilding recreates every dot element, which would drop an in-flight drag
	if state.uiDirty and not state.draggingId then
		state.uiDirty = false
		rebuildUi()
	end

	-- Comments switched off: nothing is drawn and nothing reacts to the cursor
	if not state.windowOpen then
		state.hoverDotId = nil
		return
	end

	local vsx, vsy = GetViewGeometry()
	if vsx <= 0 then
		return
	end

	-- Dots follow their world position (constant screen size)
	for _, L in ipairs(state.labels) do
		local rec = state.dotEls[L.id]
		if rec then
			local sx, ry, sz = projectLabel(L, vsy)
			local visible = sx ~= nil and sz and sz < 1 and sx > -80 and sx < vsx + 80 and ry > -80 and ry < vsy + 80
			rec.visible = visible and true or false
			if not visible then
				rec.cx, rec.cy = nil, nil
				if rec.lastHidden ~= true then
					rec.lastHidden = true
					rec.el:SetClass("hidden", true)
				end
			else
				if rec.lastHidden ~= false then
					rec.lastHidden = false
					rec.el:SetClass("hidden", false)
				end
				local w = rec.el.offset_width
				local half = (w and w > 0) and (w * 0.5) or 8
				rec.cx, rec.cy, rec.r = sx, ry, half
				local left = math.floor(sx - half)
				local top = math.floor(ry - half)
				if left ~= rec.lastLeft or top ~= rec.lastTop then
					rec.lastLeft = left
					rec.lastTop = top
					rec.el.style.left = left .. "px"
					rec.el.style.top = top .. "px"
				end
			end
		end
	end

	-- Hover hit-test (dots are pointer-events:none, so RmlUi never reports this).
	-- Nearest dot wins so overlapping dots resolve predictably.
	local hoverId = state.draggingId
	if not hoverId then
		local mx, my = GetMouseState()
		local myTop = vsy - my
		-- A dot visually behind one of our windows must not react
		local overWindow = (state.windowOpen and cursorOverRect(state.rootEl, mx, myTop))
			or (state.openLabelId and cursorOverRect(state.popupEl, mx, myTop))
		if not overWindow then
			local bestDist
			for _, L in ipairs(state.labels) do
				local rec = state.dotEls[L.id]
				if rec and rec.visible and rec.cx then
					local dx = mx - rec.cx
					local dy = myTop - rec.cy
					local d2 = dx * dx + dy * dy
					local reach = rec.r + 2
					if d2 <= reach * reach and (not bestDist or d2 < bestDist) then
						bestDist = d2
						hoverId = L.id
					end
				end
			end
		end
	end
	state.hoverDotId = hoverId

	-- Apply hover styling; the preview stays hidden for the label whose full
	-- comment is already open, so the two never show at once
	for id, rec in pairs(state.dotEls) do
		local hovered = (id == hoverId) and (id ~= state.openLabelId)
		if rec.lastHovered ~= hovered then
			rec.lastHovered = hovered
			rec.el:SetClass("hovered", hovered)
		end
	end

	-- Popup rides its dot, clamped to the viewport
	if state.openLabelId and state.popupEl then
		local L = findLabel(state.openLabelId)
		if L then
			local sx, ry = projectLabel(L, vsy)
			if sx then
				local pw = state.popupEl.offset_width or 240
				local ph = state.popupEl.offset_height or 120
				local left = math.floor(sx + 14)
				local top = math.floor(ry + 10)
				if left + pw > vsx then
					left = math.floor(sx - pw - 14)
				end
				if left < 0 then
					left = 0
				end
				if top + ph > vsy then
					top = vsy - ph
				end
				if top < 0 then
					top = 0
				end
				local key = left * 100000 + top
				if state.popupLast ~= key then
					state.popupLast = key
					state.popupEl.style.left = left .. "px"
					state.popupEl.style.top = top .. "px"
				end
			end
		end
	end

	-- Ghost "cloud cursor" while placing
	if state.placing and state.ghostEl then
		local mx, my = GetMouseState()
		local left = mx + 18
		local top = (vsy - my) + 14
		local key = left * 100000 + top
		if state.ghostLast ~= key then
			state.ghostLast = key
			state.ghostEl.style.left = left .. "px"
			state.ghostEl.style.top = top .. "px"
		end
	end
end

-- ===========================================================================
-- Config persistence (author name remembered across games)
-- ===========================================================================

function widget:GetConfigData()
	return { authorName = state.authorName }
end

function widget:SetConfigData(data)
	if type(data) == "table" and type(data.authorName) == "string" then
		state.authorName = data.authorName
	end
end

-- ===========================================================================
-- Initialize / Shutdown
-- ===========================================================================

function widget:Initialize()
	state.rmlContext = RmlUi.GetContext("shared")
	if not state.rmlContext then
		return false
	end

	local document = state.rmlContext:LoadDocument(RML_PATH, self)
	if not document then
		return false
	end
	state.document = document
	document:Show()

	if WG.TerraformerShared and WG.TerraformerShared.registerDocument then
		WG.TerraformerShared.registerDocument("map_labels", document)
	end

	state.rootEl = document:GetElementById("ml-root")
	state.dotsLayerEl = document:GetElementById("ml-dots-layer")
	state.ghostEl = document:GetElementById("ml-ghost")
	state.popupEl = document:GetElementById("ml-popup")
	state.listEl = document:GetElementById("ml-list")
	state.newBtnEl = document:GetElementById("ml-btn-new")
	state.authorInputEl = document:GetElementById("ml-author")
	state.popupViewEl = document:GetElementById("ml-popup-view")
	state.popupEditEl = document:GetElementById("ml-popup-editbox")
	state.popupTextEl = document:GetElementById("ml-popup-text")
	state.popupAuthorEl = document:GetElementById("ml-popup-author")
	state.popupDateEl = document:GetElementById("ml-popup-date")
	state.popupDotEl = document:GetElementById("ml-popup-dot")
	state.editTextEl = document:GetElementById("ml-edit-text")
	state.colorPopEl = document:GetElementById("ml-color-pop")
	state.swatchEls = {}
	for i = 1, #COLORS do
		state.swatchEls[i] = document:GetElementById("ml-swatch-" .. i)
	end

	if state.authorInputEl then
		state.authorInputEl:SetAttribute("value", state.authorName)
	end

	if WG.TerraformerShared and WG.TerraformerShared.attachDraggable then
		state.dragHandle = WG.TerraformerShared.attachDraggable(document, "ml-handle", state.rootEl)
	end

	-- Double-click on the comment text switches straight to edit mode
	if state.popupViewEl then
		state.popupViewEl:AddEventListener("dblclick", function(ev)
			if state.openLabelId and not state.popupEditing then
				playSound("click")
				setEditing(true)
			end
			ev:StopPropagation()
		end, false)
	end

	loadLabels()
	rebuildUi()

	WG.MapLabels = {
		toggle = function()
			setWindowOpen(not state.windowOpen)
			return state.windowOpen
		end,
		open = function()
			setWindowOpen(true)
		end,
		close = function()
			setWindowOpen(false)
		end,
		isOpen = function()
			return state.windowOpen
		end,
		isPlacing = function()
			return state.placing
		end,
		-- Single answer for "is the terrain brush off right now" — the brush
		-- widget hides its cursor ring whenever this is true. Covers label
		-- placement, dot hover/drag, hovering our windows, and an open comment
		-- (whose dismissing click is consumed instead of painting).
		shouldSuppressBrush = function()
			if state.placing or state.openLabelId then
				return true
			end
			return WG.MapLabels.isCursorOver()
		end,
		-- True when the cursor is over the labels browser window or an open
		-- comment popup; cmd_terraform_brush hides the brush ring there.
		isCursorOver = function()
			-- Hovering or dragging a dot is a label interaction, not painting
			if state.hoverDotId or state.draggingId then
				return true
			end
			if not state.windowOpen and not state.openLabelId then
				return false
			end
			local mx, my = GetMouseState()
			local _, vsy = GetViewGeometry()
			if vsy <= 0 then
				return false
			end
			local myTop = vsy - my
			if state.windowOpen and cursorOverRect(state.rootEl, mx, myTop) then
				return true
			end
			if state.openLabelId and cursorOverRect(state.popupEl, mx, myTop) then
				return true
			end
			return false
		end,
		getLabelCount = function()
			return #state.labels
		end,

		-- Read-only snapshot for exporters (Terraform Brush Capture writes these
		-- as an SVG pin layer). Copied so a caller cannot mutate live state.
		getLabels = function()
			local out = {}
			for i, L in ipairs(state.labels) do
				out[i] = {
					id = L.id,
					x = L.x,
					z = L.z,
					color = L.color,
					author = L.author,
					created = L.created,
					text = L.text,
				}
			end
			return out
		end,

		-- Map project integration (cmd_map_project.lua). Comments are part of a
		-- project's persisted data: saveProject writes them into the project
		-- folder, loadProject replaces the live set when a project is opened.

		-- Returns the number of comments written (0 = none, caller deletes the
		-- file), or nil if the file could not be written.
		saveProject = function(path)
			if not path then
				return nil
			end
			if not writeLabelsFile(path, true) then
				return nil
			end
			return #state.labels
		end,

		-- Opening a project whose manifest has no labels section: the project
		-- genuinely has no comments, so drop whatever the previous project left
		-- in the (map-name-keyed, hence shared) autosave file.
		clearProject = function()
			closePopup()
			setPlacing(false)
			state.labels = {}
			state.nextId = 1
			state.hoverDotId = nil
			state.draggingId = nil
			saveLabels()
			markDirty()
		end,

		-- Replaces every live comment with the project's. Also refreshes the
		-- per-map autosave so the two copies do not disagree afterwards.
		-- Returns ok, count.
		loadProject = function(path)
			if not path then
				return false
			end
			local labels, nextId = parseLabelsFile(path)
			if not labels then
				return false
			end
			closePopup()
			setPlacing(false)
			state.labels = labels
			state.nextId = nextId
			state.hoverDotId = nil
			state.draggingId = nil
			saveLabels()
			markDirty()
			return true, #labels
		end,
	}
end

function widget:Shutdown()
	WG.MapLabels = nil

	if WG.TerraformerShared and WG.TerraformerShared.unregisterDocument then
		WG.TerraformerShared.unregisterDocument("map_labels")
	end

	if state.document then
		state.document:Close()
		state.document = nil
	end
	state.rootEl = nil
	state.dotsLayerEl = nil
	state.ghostEl = nil
	state.popupEl = nil
	state.listEl = nil
	state.dotEls = {}
	state.dragHandle = nil
	state.openLabelId = nil
	state.placing = false
	state.windowOpen = false
end
