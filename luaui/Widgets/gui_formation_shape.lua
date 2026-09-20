if not RmlUi then
	return
end

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Formation Shape",
		desc = "Pick the shape a group takes when its formation line is too tight for one row: the line as drawn, square grid, hex lattice, sunflower or diamond, laid along the curve. Shown while several mobile units are selected; also /formationshape <line|square|hex|sunflower|diamond|next>",
		author = "PtaQ",
		date = "2026.09.20",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

-- The choice lives in WG.formationShape, the formation widget (cmd_customformations2.lua) reads it
-- while a line is drawn and when it is released, and lays the shape over the curve.

local RML_PATH = "luaui/RmlWidgets/gui_formation_shape/gui_formation_shape.rml"

local SHAPES = {
	{ key = "line", label = "Line" }, -- as drawn, however tight: what the game did before
	{ key = "square", label = "Square" },
	{ key = "hex", label = "Hex" },
	{ key = "sunflower", label = "Sun" },
	{ key = "diamond", label = "Diamond" },
}
local DEFAULT_SHAPE = "hex"
local MAX_CHECKED = 24 -- units of a selection looked at to decide whether to show the window

local isMobile = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	isMobile[unitDefID] = (unitDef.canMove and not unitDef.isBuilding and (unitDef.speed or 0) > 0) or nil
end

local S = {
	shape = DEFAULT_SHAPE,
	pos = nil,
	visible = false,
	drag = nil,
	chips = {},
}

local function IsKnownShape(key)
	for i = 1, #SHAPES do
		if SHAPES[i].key == key then
			return true
		end
	end
	return false
end

local function RefreshChips()
	for key, chip in pairs(S.chips) do
		chip:SetClass("nt-chip-on", key == S.shape)
	end
end

local function SetShape(key)
	if not IsKnownShape(key) then
		return false
	end
	S.shape = key
	WG.formationShape = key
	RefreshChips()
	return true
end

local function NextShape()
	for i = 1, #SHAPES do
		if SHAPES[i].key == S.shape then
			SetShape(SHAPES[(i % #SHAPES) + 1].key)
			return
		end
	end
	SetShape(DEFAULT_SHAPE)
end

-- a formation needs a group: two units or more that can be sent somewhere
local function SelectionIsGroup()
	local selection = Spring.GetSelectedUnits()
	local mobile = 0
	for i = 1, math.min(#selection, MAX_CHECKED) do
		if isMobile[Spring.GetUnitDefID(selection[i]) or -1] then
			mobile = mobile + 1
			if mobile >= 2 then
				return true
			end
		end
	end
	return false
end

local function SetVisible(visible)
	if not S.document or visible == S.visible then
		return
	end
	S.visible = visible
	if visible then
		S.document:Show()
	else
		S.drag = nil
		S.document:Hide()
	end
end

local function BuildRoot()
	local parts = {
		'<div class="nt-header">'
			.. '<div id="af-handle" class="nt-title text-outline-darker">'
			.. '<div class="nt-title-gem"></div>'
			.. '<span class="nt-title-main">FORMATION</span>'
			.. '<span class="nt-title-accent">SHAPE</span>'
			.. "</div>"
			.. "</div>",
		'<div class="nt-chips nt-chips-wide">',
	}
	for i = 1, #SHAPES do
		parts[#parts + 1] = '<div id="af-shape-' .. SHAPES[i].key .. '" class="nt-chip">' .. SHAPES[i].label .. "</div>"
	end
	parts[#parts + 1] = "</div>"
	S.root.inner_rml = table.concat(parts)
end

local function WireWindow()
	local handle = S.document:GetElementById("af-handle")
	if handle then
		handle:AddEventListener("mousedown", function(event)
			local p = event.parameters
			if p and p.button and p.button ~= 0 then
				return
			end
			local mx, my = Spring.GetMouseState()
			local vsx, vsy = Spring.GetViewGeometry()
			S.drag = {
				dx = mx - S.root.offset_left,
				dy = (vsy - my) - S.root.offset_top,
				w = S.root.offset_width,
				h = S.root.offset_height,
				vsx = vsx,
				vsy = vsy,
			}
			event:StopPropagation()
		end, false)
	end
	S.document:AddEventListener("mouseup", function()
		S.drag = nil
	end, true)

	S.chips = {}
	for i = 1, #SHAPES do
		local key = SHAPES[i].key
		local chip = S.document:GetElementById("af-shape-" .. key)
		if chip then
			S.chips[key] = chip
			chip:AddEventListener("click", function()
				SetShape(key)
			end, false)
		end
	end
end

local function TickDrag()
	local drag = S.drag
	local mx, my, _, _, _, offscreen = Spring.GetMouseState()
	if not drag or offscreen then
		return
	end
	local x = math.floor(math.max(0, math.min(drag.vsx - drag.w, mx - drag.dx)))
	local y = math.floor(math.max(0, math.min(drag.vsy - drag.h, (drag.vsy - my) - drag.dy)))
	if x ~= drag.x or y ~= drag.y then
		drag.x = x
		drag.y = y
		S.root.style.left = x .. "px"
		S.root.style.top = y .. "px"
		S.pos = { x = x, y = y }
	end
end

function widget:Initialize()
	WG.formationShape = S.shape

	widgetHandler:AddAction("formationshape", function(_, _, params)
		local word = params and params[1]
		if word == "next" or word == nil then
			NextShape()
		elseif not SetShape(word) then
			Spring.Echo("[formationshape] shapes: line, square, hex, sunflower, diamond, next")
			return true
		end
		Spring.Echo("[formationshape] " .. S.shape)
		return true
	end, nil, "t")

	local context = RmlUi.GetContext("shared")
	if not context then
		return
	end
	local document = context:LoadDocument(RML_PATH)
	if not document then
		Spring.Echo("[formationshape] could not load " .. RML_PATH .. ", /formationshape still works")
		return
	end
	S.document = document
	S.root = document:GetElementById("nt-root")
	if not S.root then
		document:Close()
		S.document = nil
		return
	end

	-- (width stays what the stylesheet gives every window of this family: 13vw, at least 220px)
	local vsx, vsy = Spring.GetViewGeometry()
	if S.pos and type(S.pos.x) == "number" and type(S.pos.y) == "number" then
		S.root.style.left = math.floor(math.max(0, math.min(vsx - 120, S.pos.x))) .. "px"
		S.root.style.top = math.floor(math.max(0, math.min(vsy - 60, S.pos.y))) .. "px"
	else
		S.root.style.left = "43vw"
		S.root.style.top = "78vh"
	end

	BuildRoot()
	WireWindow()
	RefreshChips()

	document:Hide()
	S.visible = false
	SetVisible(SelectionIsGroup())
end

function widget:SelectionChanged()
	SetVisible(SelectionIsGroup())
end

function widget:Update()
	if S.drag then
		TickDrag()
	end
end

function widget:GetConfigData()
	return { shape = S.shape, pos = S.pos }
end

function widget:SetConfigData(data)
	if type(data) ~= "table" then
		return
	end
	if IsKnownShape(data.shape) then
		S.shape = data.shape
	end
	if type(data.pos) == "table" then
		S.pos = data.pos
	end
end

function widget:Shutdown()
	widgetHandler:RemoveAction("formationshape", "t")
	WG.formationShape = nil
	if S.document then
		S.document:Close()
		S.document = nil
	end
	S.chips = {}
	S.root = nil
end
