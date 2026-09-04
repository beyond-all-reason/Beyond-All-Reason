-- Select control for the keybind editor's preset picker.
-- Uses FlowUI's Selector visuals to match the Settings look. Shows the current
-- selection; onSelect(option, index) fires when a choice is picked.

local text = VFS.Include("luaui/Include/keybind_text.lua")

local Dropdown = {}
Dropdown.__index = Dropdown

local floor = math.floor

local colorText = "\255\235\235\235"
-- SelectHighlight defaults to 0.35 and the rest of the UI stays near it. At 1 the
-- overlay is opaque and swallows the option label under it.
local hoverOpacity = 0.25

-- Font is fetched per draw; it does not exist when this file is included.
local function getFont()
	return WG["fonts"].getFont()
end

-- Options may be plain strings or { label = ... } records.
local function optionLabel(opt)
	if type(opt) == "table" then
		return opt.label or tostring(opt.value)
	end

	return tostring(opt)
end

-- A select: closed it shows the selection, open it overlays its options.
function Dropdown.new(opts)
	opts = opts or {}

	local self = setmetatable({}, Dropdown)
	self.options = opts.options or {}
	self.onSelect = opts.onSelect
	self.selected = opts.selected or 1
	self.placeholder = opts.placeholder
	self.open = false
	self.rect = { 0, 0, 0, 0 }
	self.optRects = {}
	self.fontSize = 14

	return self
end

-- Placement, plus the option rects the open list will use.
function Dropdown:setRect(x1, y1, x2, y2, fontSize)
	self.rect = { x1, y1, x2, y2 }
	self.fontSize = fontSize or (y2 - y1) * 0.5

	local optH = floor(y2 - y1)
	self.optRects = {}
	for i = 1, #self.options do
		self.optRects[i] = { x1 = x1, y1 = y1 - i * optH, x2 = x2, y2 = y1 - (i - 1) * optH }
	end
end

-- Swaps the options, closing the list and keeping the selection in range.
function Dropdown:setOptions(options)
	-- Closed as well as rebuilt: a refresh while the list is down would otherwise leave it
	-- open over a different set of options than the one it was opened on.
	self.open = false
	self.options = options or {}
	if self.selected > #self.options then
		self.selected = 1
	end

	local r = self.rect
	self:setRect(r[1], r[2], r[3], r[4], self.fontSize)
end

-- Moves the selection without notifying the owner, for syncing from outside.
function Dropdown:setSelected(i)
	if i and self.options[i] then
		self.selected = i
	end
end

function Dropdown:isOpen()
	return self.open
end

function Dropdown:close()
	self.open = false
end

-- Chevron corners, held as upvalues so the vertex callback can be built once rather
-- than closing over fresh geometry on every draw.
local chevronX, chevronY, chevronH = 0, 0, 0
local function chevronVertices()
	gl.Vertex(chevronX - chevronH, chevronY)
	gl.Vertex(chevronX + chevronH, chevronY)
	gl.Vertex(chevronX, chevronY - chevronH * 1.2)
end

function Dropdown:draw()
	local font = getFont()
	local Selector = WG.FlowUI.Draw.Selector
	local Highlight = WG.FlowUI.Draw.SelectHighlight
	local R = WG.FlowUI.Draw.RectRound
	local mx, my = Spring.GetMouseState()
	local x1, y1, x2, y2 = self.rect[1], self.rect[2], self.rect[3], self.rect[4]
	local inset = floor((y2 - y1) * 0.3)

	Selector(x1, y1, x2, y2)

	-- Chevron in the gap already reserved at the right edge, so the control reads as a
	-- select rather than a button. Drawn before the text: geometry inside a font batch
	-- makes both flicker.
	local arrowH = floor((y2 - y1) * 0.16)
	local arrowX = x2 - inset - arrowH
	local arrowY = (y1 + y2) * 0.5 + arrowH * 0.5
	gl.Color(1, 1, 1, self.open and 0.9 or 0.55)
	chevronX, chevronY, chevronH = arrowX, arrowY, arrowH
	gl.BeginEnd(GL.TRIANGLES, chevronVertices)
	gl.Color(1, 1, 1, 1)

	font:Begin()
	local current = self.options[self.selected]
	local label = self.placeholder or (current and optionLabel(current) or "")
	-- A profile name is free text and can outrun the control, which is fixed width so the
	-- header does not reflow every time the selection changes.
	local labelW = (arrowX - arrowH) - (x1 + inset) - inset * 2
	font:Print(
		colorText .. text.fit(font, label, labelW, self.fontSize),
		x1 + inset,
		(y1 + y2) * 0.5,
		self.fontSize,
		"ov"
	)
	font:End()

	if self.open and #self.optRects > 0 then
		local top = self.optRects[1].y2
		local bottom = self.optRects[#self.optRects].y1
		local cs = floor((y2 - y1) * 0.1)
		R(x1, bottom, x2, top, cs, 1, 1, 1, 1, { 0.09, 0.09, 0.09, 0.96 })

		for i in ipairs(self.options) do
			---@type table
			local r = self.optRects[i]
			if mx >= r.x1 and mx <= r.x2 and my >= r.y1 and my <= r.y2 then
				Highlight(r.x1, r.y1, r.x2, r.y2, cs, hoverOpacity, { 1, 1, 1 })
			end
		end

		font:Begin()
		for i, opt in ipairs(self.options) do
			local r = self.optRects[i]
			local w = (r.x2 - inset) - (r.x1 + inset)
			font:Print(
				colorText .. text.fit(font, optionLabel(opt), w, self.fontSize),
				r.x1 + inset,
				(r.y1 + r.y2) * 0.5,
				self.fontSize,
				"ov"
			)
		end
		font:End()
	end
end

function Dropdown:mousePress(x, y)
	if self.open then
		for i, r in ipairs(self.optRects) do
			if x >= r.x1 and x <= r.x2 and y >= r.y1 and y <= r.y2 then
				self.open = false
				self.selected = i
				if self.onSelect then
					self.onSelect(self.options[i], i)
				end

				return true
			end
		end
	end

	local b = self.rect
	if x >= b[1] and x <= b[3] and y >= b[2] and y <= b[4] then
		self.open = not self.open
		return true
	end

	self.open = false

	return false
end

return Dropdown
