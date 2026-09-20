-- Select control for the keybind editor's preset picker.
-- Uses FlowUI's Selector visuals to match the Settings look. Shows the current
-- selection; onSelect(option, index) fires when a choice is picked.
--
-- An option record may carry a `tag`, a short word drawn on a faint pill at the right of its
-- row, and of the closed control while it is the selection; and a `group`, where the open
-- list rules a line between two neighbours whose groups differ. Both are opt-in, so a list
-- of plain strings draws as it always has.

local text = VFS.Include("luaui/Include/keybind_text.lua")

local Dropdown = {}
Dropdown.__index = Dropdown

local floor = math.floor

local colorText = "\255\235\235\235"
-- Quieter than the name beside it: a tag qualifies the option rather than naming it.
local colorTag = "\255\175\175\175"
-- SelectHighlight defaults to 0.35 and the rest of the UI stays near it. At 1 the
-- overlay is opaque and swallows the option label under it.
local hoverOpacity = 0.25
-- Lighter for the control itself than for a row of the open list: one says the cursor
-- is on it, the other says this is the option a click would take.
local controlHoverOpacity = 0.14
local white = { 1, 1, 1 }
-- The two ends of the wash SelectHighlight paints, taken from the colour it would be handed so
-- a row of the list and the control above it cannot drift apart. Held rather than built per
-- row per frame.
local washLow = { white[1] * 0.5, white[2] * 0.5, white[3] * 0.5, hoverOpacity }
local washHigh = { white[1], white[2], white[3], hoverOpacity }
local listFill = { 0.09, 0.09, 0.09, 0.96 }
local tagFill = { 1, 1, 1, 0.08 }
local ruleColor = { 1, 1, 1, 0.14 }

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

local function optionTag(opt)
	return type(opt) == "table" and opt.tag or nil
end

local function optionGroup(opt)
	return type(opt) == "table" and opt.group or nil
end

-- A select: closed it shows the selection, open it overlays its options.
function Dropdown.new(opts)
	opts = opts or {}

	local self = setmetatable({}, Dropdown)
	self.options = opts.options or {}
	self.onSelect = opts.onSelect
	self.selected = opts.selected or 1
	self.placeholder = opts.placeholder
	-- An outline to draw the text with, for a panel that pins its own. The font is shared with
	-- every other widget and keeps whatever outline was set on it last; without one this takes
	-- that, as it always has.
	self.outline = opts.outline
	-- Shade the selected option in the open list: for a picker whose selection is always a
	-- real choice, never a placeholder standing in for none.
	self.markSelected = opts.markSelected
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
	-- Tag pills are measured against the row height and the font size, both just set.
	self.tagCache = nil

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
	-- Fitted captions belong to the old options.
	self.optFitted = nil

	local r = self.rect
	self:setRect(r[1], r[2], r[3], r[4], self.fontSize)
end

-- The caption shortened to its box, measured once per text and width rather than per
-- frame. The result is kept on the cache table under the key given.
local function fittedLabel(cache, key, font, label, w, fs)
	local hit = cache[key]
	if hit and hit.label == label and hit.w == w then
		return hit.text
	end

	local fitted = colorText .. text.fit(font, label, w, fs)
	cache[key] = { label = label, w = w, text = fitted }

	return fitted
end

-- A tag's pill width, caption size, padding and coloured caption at this control's size.
-- Measured once per tag rather than per frame; setRect drops them when the size changes.
local function tagMetrics(self, font, tag)
	local cache = self.tagCache
	if not cache then
		cache = {}
		self.tagCache = cache
	end

	local hit = cache[tag]
	if not hit then
		local fs = floor(self.fontSize * 0.8)
		local pad = floor((self.rect[4] - self.rect[2]) * 0.25)
		hit = { w = floor(font:GetTextWidth(tag) * fs) + pad * 2, fs = fs, pad = pad, text = colorTag .. tag }
		cache[tag] = hit
	end

	return hit
end

-- Vertical span of a tag's pill in a row: a little over half the row's height, centred.
local function tagSpan(y1, y2)
	local h = floor((y2 - y1) * 0.62)
	local py1 = floor((y1 + y2 - h) * 0.5)

	return py1, py1 + h
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

-- What the cursor is over: an option's index in the open list, 0 for the control itself,
-- nil for neither. For an owner that shows something about the option under the cursor.
function Dropdown:optionAt(x, y)
	if self.open then
		for i, r in ipairs(self.optRects) do
			if x >= r.x1 and x <= r.x2 and y >= r.y1 and y <= r.y2 then
				return i
			end
		end
	end

	local b = self.rect
	if x >= b[1] and x <= b[3] and y >= b[2] and y <= b[4] then
		return 0
	end

	return nil
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
	-- Floored with the rest: a vertex between two pixels softens the whole glyph.
	gl.Vertex(chevronX, floor(chevronY - chevronH * 1.2))
end

function Dropdown:draw()
	local font = getFont()
	local Selector = WG.FlowUI.Draw.Selector
	local Highlight = WG.FlowUI.Draw.SelectHighlight
	local R = WG.FlowUI.Draw.RectRound
	local mx, my = Spring.GetMouseState()
	local x1, y1, x2, y2 = self.rect[1], self.rect[2], self.rect[3], self.rect[4]
	local inset = floor((y2 - y1) * 0.3)
	local tagCs = math.max(1, floor(WG.FlowUI.elementCorner * 0.5))
	-- Where a tag's pill ends: clear of the square FlowUI's Selector draws for its button at the
	-- right end, as wide as the control is tall. The open list's tags keep to the same column,
	-- so a tag does not jump sideways between the closed control and the rows under it.
	local tagRight = x2 - (y2 - y1) - inset

	Selector(x1, y1, x2, y2)
	-- A control with nothing to choose from does not light under the cursor. Lighting is
	-- what tells a player something will happen when they press, and here nothing will.
	if not self.disabled and mx >= x1 and mx <= x2 and my >= y1 and my <= y2 then
		Highlight(x1, y1, x2, y2, floor(WG.FlowUI.elementCorner * 0.66), controlHoverOpacity, white)
	end

	-- Chevron in the gap already reserved at the right edge, so the control reads as a
	-- select rather than a button. Drawn before the text: geometry inside a font batch
	-- makes both flicker.
	local arrowH = floor((y2 - y1) * 0.16)
	local arrowX = x2 - inset - arrowH
	local arrowY = floor((y1 + y2) * 0.5 + arrowH * 0.5)
	gl.Color(1, 1, 1, self.disabled and 0.25 or (self.open and 0.9 or 0.55))
	chevronX, chevronY, chevronH = arrowX, arrowY, arrowH
	gl.BeginEnd(GL.TRIANGLES, chevronVertices)
	gl.Color(1, 1, 1, 1)

	-- The selection's tag, in the column worked out above. Its pill is geometry too, so it goes
	-- down here and its caption waits for the font batch. A placeholder is not an option and
	-- has no tag.
	local current = self.options[self.selected]
	local currentTag = not self.placeholder and optionTag(current)
	local tag = currentTag and tagMetrics(self, font, currentTag)
	local labelRight = (arrowX - arrowH) - inset * 2
	local tagX1, tagY1, tagY2
	if tag then
		tagX1 = tagRight - tag.w
		tagY1, tagY2 = tagSpan(y1, y2)
		R(tagX1, tagY1, tagRight, tagY2, tagCs, 1, 1, 1, 1, tagFill)
		labelRight = tagX1 - inset
	end

	local fitted = self.optFitted
	if not fitted then
		fitted = {}
		self.optFitted = fitted
	end

	font:Begin()
	if self.outline then
		font:SetOutlineColor(self.outline)
	end
	local label = self.placeholder or (current and optionLabel(current) or "")
	-- A preset name is free text and can outrun the control, which is fixed width so the
	-- header does not reflow every time the selection changes.
	local labelW = labelRight - (x1 + inset)
	font:Print(
		fittedLabel(fitted, 0, font, label, labelW, self.fontSize),
		x1 + inset,
		text.baseline(font, y1, y2, self.fontSize),
		self.fontSize,
		"o"
	)
	if tag then
		font:Print(tag.text, tagX1 + tag.pad, text.baseline(font, tagY1, tagY2, tag.fs), tag.fs, "o")
	end
	font:End()

	if self.open and #self.optRects > 0 then
		local top = self.optRects[1].y2
		local bottom = self.optRects[#self.optRects].y1
		-- Rounded like the rest of the panel's inner elements.
		local cs = floor(WG.FlowUI.elementCorner * 0.66)
		R(x1, bottom, x2, top, cs, 1, 1, 1, 1, listFill)

		local ruleH = math.max(1, floor((y2 - y1) * 0.04))
		for i, opt in ipairs(self.options) do
			---@type table
			local r = self.optRects[i]
			-- The option the list was opened on is shaded exactly as a hovered one: one treatment
			-- for the list rather than two washes of different weights sitting next to each other.
			-- Drawn once when the cursor is on that row, so it does not double up.
			local hovered = mx >= r.x1 and mx <= r.x2 and my >= r.y1 and my <= r.y2
			if hovered or (self.markSelected and i == self.selected) then
				-- The wash SelectHighlight draws, with the corners ours to set: it rounds all four,
				-- and a row has corners only where the list itself has them. Square against the row
				-- above or below, which has none to meet.
				local first = (i == 1) and 1 or 0
				local last = (i == #self.options) and 1 or 0
				R(r.x1, r.y1, r.x2, r.y2, cs, first, first, last, last, washLow, washHigh)
			end

			local optTag = optionTag(opt)
			if optTag then
				local m = tagMetrics(self, font, optTag)
				local py1, py2 = tagSpan(r.y1, r.y2)
				R(tagRight - m.w, py1, tagRight, py2, tagCs, 1, 1, 1, 1, tagFill)
			end

			-- A rule along the top of the row where one group of options gives way to the next.
			if i > 1 and optionGroup(opt) ~= optionGroup(self.options[i - 1]) then
				gl.Color(ruleColor[1], ruleColor[2], ruleColor[3], ruleColor[4])
				gl.Rect(r.x1 + inset, r.y2 - ruleH, r.x2 - inset, r.y2)
				gl.Color(1, 1, 1, 1)
			end
		end

		-- Still the caption's outline: it was set on this same font a moment ago, in this draw.
		font:Begin()
		for i, opt in ipairs(self.options) do
			local r = self.optRects[i]
			local optTag = optionTag(opt)
			local m = optTag and tagMetrics(self, font, optTag)
			-- The name stops short of its tag when it has one, as the closed control's does.
			local right = m and (tagRight - m.w - inset) or (r.x2 - inset)
			font:Print(
				fittedLabel(fitted, i, font, optionLabel(opt), right - (r.x1 + inset), self.fontSize),
				r.x1 + inset,
				text.baseline(font, r.y1, r.y2, self.fontSize),
				self.fontSize,
				"o"
			)
			if m then
				local py1, py2 = tagSpan(r.y1, r.y2)
				font:Print(m.text, tagRight - m.w + m.pad, text.baseline(font, py1, py2, m.fs), m.fs, "o")
			end
		end
		font:End()
	end
end

function Dropdown:mousePress(x, y)
	if self.disabled then
		self.open = false

		return false
	end

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
