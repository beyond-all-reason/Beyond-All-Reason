-- Single-line text input for the keybind editor search field, shared with the game info
-- panel. Active only while focused, so it is safe to host alongside game input.

local utf8 = VFS.Include("common/luaUtilities/utf8.lua")

local KEYSYMS = VFS.Include("luaui/Include/keybind_keysyms.lua")
local text = VFS.Include("luaui/Include/keybind_text.lua")

-- Declared rather than inferred: the fields live on the instance new() builds, which is not
-- something the type checker can follow back from a method's self.
---@class Editbox
---@field text string
---@field caret integer
---@field selAnchor any
---@field focused boolean
---@field dragging boolean
---@field placeholder string
---@field maxChars integer
---@field maxCharsOwn integer The limit it was built with, restored when a raise is dropped
---@field onChange any
---@field outline any
---@field clearable any
---@field rect any
---@field fontSize any
---@field pad any
---@field blinkStart any
---@field blinkText any
---@field blinkCaret any
local Editbox = {}
Editbox.__index = Editbox

local floor = math.floor

local colorText = "\255\235\235\235"
local colorDim = "\255\160\160\160"

-- Taken from gui_chat input so the two fields read as the same control.
local cursorBlinkDuration = 1
local cursorGrey = 0.7

-- What the panels light a row with under the cursor, so the field reads as clickable.
local hoverOpacity = 0.14
local white = { 1, 1, 1 }

-- Font is fetched per draw; it does not exist when this file is included.
local function getFont()
	return WG["fonts"].getFont()
end

-- Restarts the fade, so the caret is at its brightest right after an edit.
local function resetBlink(self)
	self.blinkStart = Spring.GetTimer()
	self.blinkText = self.text
	self.blinkCaret = self.caret
end

-- Single-line text field with a caret, selection and word motion.
function Editbox.new(opts)
	opts = opts or {}

	local self = setmetatable({}, Editbox)
	self.text = opts.text or ""
	self.caret = utf8.len(self.text)
	self.selAnchor = nil
	self.focused = false
	self.dragging = false
	self.placeholder = opts.placeholder or ""
	self.maxChars = opts.maxChars or 127
	self.maxCharsOwn = self.maxChars
	self.onChange = opts.onChange
	-- The font is shared with every other widget and keeps whatever outline was set on it last.
	self.outline = opts.outline
	-- Asked for rather than given: a field whose text is not a filter has nothing to clear to.
	self.clearable = opts.clearable
	self.rect = { 0, 0, 0, 0 }
	self.fontSize = 14
	self.pad = 6

	return self
end

function Editbox:setRect(x1, y1, x2, y2, fontSize, pad)
	self.rect = { x1, y1, x2, y2 }
	self.fontSize = fontSize or (y2 - y1) * 0.5
	self.pad = pad or floor((y2 - y1) * 0.3)
end

-- Nothing hands back the raised limit, so it falls to what the field asked for.
function Editbox:setMaxChars(n)
	self.maxChars = n or self.maxCharsOwn
end

function Editbox:getText()
	return self.text
end

-- Replaces the contents, caret to the end.
function Editbox:setText(t)
	self.text = t or ""
	self.caret = utf8.len(self.text)
	self.selAnchor = nil

	if self.onChange then
		self.onChange(self.text)
	end
end

-- SDL text input is owned by the panel: blurring this field must not stop text events while
-- the editor is open.
function Editbox:focus()
	-- A field that just took focus shows a bright caret, not whatever phase the fade was in.
	if not self.focused then
		resetBlink(self)
	end
	self.focused = true
end

-- Gives up focus and any drag in progress.
function Editbox:blur()
	self.focused = false
	self.dragging = false
end

function Editbox:isFocused()
	return self.focused
end

function Editbox:hasSelection()
	return self.selAnchor ~= nil and self.selAnchor ~= self.caret
end

-- The highlighted range, low end first.
function Editbox:selRange()
	return math.min(self.selAnchor, self.caret), math.max(self.selAnchor, self.caret)
end

-- Removes the highlighted range, caret left where it began.
function Editbox:deleteSelection()
	if not self:hasSelection() then
		return false
	end

	local a, b = self:selRange()
	self.text = utf8.sub(self.text, 1, a) .. utf8.sub(self.text, b + 1)
	self.caret = a
	self.selAnchor = nil

	return true
end

-- Moves the caret, growing the selection when the caller asks to extend.
function Editbox:setCaret(pos, extend)
	if extend then
		if not self.selAnchor then
			self.selAnchor = self.caret
		end
	else
		self.selAnchor = nil
	end

	local len = utf8.len(self.text)
	if pos < 0 then
		pos = 0
	elseif pos > len then
		pos = len
	end
	self.caret = pos
end

function Editbox:prevWord()
	local pos = self.caret
	while pos > 0 and utf8.sub(self.text, pos, pos):match("%s") do
		pos = pos - 1
	end
	while pos > 0 and not utf8.sub(self.text, pos, pos):match("%s") do
		pos = pos - 1
	end

	return pos
end

function Editbox:nextWord()
	local len = utf8.len(self.text)
	local pos = self.caret
	while pos < len and not utf8.sub(self.text, pos + 1, pos + 1):match("%s") do
		pos = pos + 1
	end
	while pos < len and utf8.sub(self.text, pos + 1, pos + 1):match("%s") do
		pos = pos + 1
	end

	return pos
end

function Editbox:indexFromX(x)
	local font = getFont()
	local relX = x - (self.rect[1] + self.pad)

	if relX <= 0 then
		return 0
	end

	local n = utf8.len(self.text)
	for i = 1, n do
		local w = font:GetTextWidth(utf8.sub(self.text, 1, i)) * self.fontSize
		if w >= relX then
			local wPrev = font:GetTextWidth(utf8.sub(self.text, 1, i - 1)) * self.fontSize
			if (relX - wPrev) < (w - relX) then
				return i - 1
			end

			return i
		end
	end

	return n
end

-- Takes a typed character, replacing any selection.
function Editbox:textInput(char)
	if not self.focused then
		return false
	end

	self:deleteSelection()

	if utf8.len(self.text) >= self.maxChars then
		return true
	end

	self.text = utf8.sub(self.text, 1, self.caret) .. char .. utf8.sub(self.text, self.caret + 1)
	self.caret = self.caret + 1
	self.selAnchor = nil

	if self.onChange then
		self.onChange(self.text)
	end

	return true
end

-- Editing and motion keys; printable characters arrive through textInput instead.
function Editbox:keyPress(key)
	if not self.focused then
		return false
	end

	local _, ctrl, _, shift = Spring.GetModKeyState()
	local changed = false

	if ctrl and key == KEYSYMS.A then
		self.selAnchor = 0
		self.caret = utf8.len(self.text)
	elseif key == KEYSYMS.ESCAPE or key == KEYSYMS.RETURN then
		self:blur()
	elseif key == KEYSYMS.BACKSPACE then
		if not self:deleteSelection() then
			if ctrl then
				local p = self:prevWord()
				if p < self.caret then
					self.text = utf8.sub(self.text, 1, p) .. utf8.sub(self.text, self.caret + 1)
					self.caret = p
				end
			elseif self.caret > 0 then
				self.text = utf8.sub(self.text, 1, self.caret - 1) .. utf8.sub(self.text, self.caret + 1)
				self.caret = self.caret - 1
			end
		end
		changed = true
	elseif key == KEYSYMS.DELETE then
		if not self:deleteSelection() then
			if self.caret < utf8.len(self.text) then
				self.text = utf8.sub(self.text, 1, self.caret) .. utf8.sub(self.text, self.caret + 2)
			end
		end
		changed = true
	elseif key == KEYSYMS.LEFT then
		self:setCaret(ctrl and self:prevWord() or self.caret - 1, shift)
	elseif key == KEYSYMS.RIGHT then
		self:setCaret(ctrl and self:nextWord() or self.caret + 1, shift)
	elseif key == KEYSYMS.HOME then
		self:setCaret(0, shift)
	elseif key == KEYSYMS.END then
		self:setCaret(utf8.len(self.text), shift)
	end

	if changed and self.onChange then
		self.onChange(self.text)
	end

	return true
end

-- Inset like the caret and the selection are.
local function clearRect(self)
	local x2, y1, y2 = self.rect[3], self.rect[2], self.rect[4]
	local inset = floor((y2 - y1) * 0.18)

	return x2 - (y2 - y1) + inset, y1 + inset, x2 - inset, y2 - inset
end

local function overClear(self, x, y)
	if not self.clearable or self.text == "" then
		return false
	end
	local bx1, by1, bx2, by2 = clearRect(self)

	return x >= bx1 and x <= bx2 and y >= by1 and y <= by2
end

-- Click to place the caret, or start a drag selection.
function Editbox:mousePress(x, y)
	if x < self.rect[1] or x > self.rect[3] or y < self.rect[2] or y > self.rect[4] then
		return false
	end

	-- Focus stays, so the next thing typed starts a new search.
	if overClear(self, x, y) then
		self:focus()
		self:setText("")

		return true
	end

	local _, _, _, shift = Spring.GetModKeyState()
	local idx = self:indexFromX(x)

	self:focus()
	self:setCaret(idx, shift)
	if not shift then
		self.selAnchor = idx
	end
	self.dragging = true

	return true
end

-- Recomputes caret and selection pixel offsets after the text or rect changes.
local function update(self)
	if self.dragging then
		local mx, _, lmb = Spring.GetMouseState()
		if lmb then
			self.caret = self:indexFromX(mx)
		else
			self.dragging = false
		end
	end

	-- Every way the caret can move shows up as one of these two changing.
	if not self.blinkStart or self.text ~= self.blinkText or self.caret ~= self.blinkCaret then
		resetBlink(self)
	end
end

-- Full brightness at the last edit, fading to 0.15 over the blink duration, then over again.
local function caretAlpha(self)
	local elapsed = Spring.DiffTimers(Spring.GetTimer(), self.blinkStart) % cursorBlinkDuration

	return 1 - (elapsed * (1 / cursorBlinkDuration)) + 0.15
end

-- Measured only when the text, the caret or the size moved: the field is drawn every frame so
-- the blink can animate.
local function caretOffset(self, font)
	if self.caretPxAt ~= self.caret or self.caretPxText ~= self.text or self.caretPxFs ~= self.fontSize then
		self.caretPxAt, self.caretPxText, self.caretPxFs = self.caret, self.text, self.fontSize
		self.caretPx = font:GetTextWidth(utf8.sub(self.text, 1, self.caret)) * self.fontSize
	end

	return self.caretPx
end

-- Held rather than built per draw: a colour table a frame is an allocation a frame.
local fieldFill = { 0, 0, 0, 0.35 }
local clearFill = { 1, 1, 1, 0.04 }

-- Geometry rather than a glyph so it does not depend on the font carrying one.
local function drawClear(self, hot, cs)
	local bx1, by1, bx2, by2 = clearRect(self)
	WG.FlowUI.Draw.RectRound(bx1, by1, bx2, by2, cs, 1, 1, 1, 1, clearFill)
	if hot then
		WG.FlowUI.Draw.SelectHighlight(bx1, by1, bx2, by2, cs, hoverOpacity, white)
	end

	local arm = math.max(2, floor((bx2 - bx1) * 0.24))
	local half = math.max(1, floor((bx2 - bx1) * 0.035 + 0.5))
	gl.Color(1, 1, 1, hot and 0.75 or 0.32)
	gl.PushMatrix()
	gl.Translate(floor((bx1 + bx2) * 0.5), floor((by1 + by2) * 0.5), 0)
	gl.Rotate(45, 0, 0, 1)
	gl.Rect(-arm, -half, arm, half)
	gl.Rect(-half, half, half, arm)
	gl.Rect(-half, -arm, half, -half)
	gl.PopMatrix()
	gl.Color(1, 1, 1, 1)
end

function Editbox:draw()
	update(self)

	local font = getFont()
	local R = WG.FlowUI.Draw.RectRound
	local x1, y1, x2, y2 = self.rect[1], self.rect[2], self.rect[3], self.rect[4]
	-- Whole pixels: an edge on a fraction is blended across two and reads as a blur.
	local cs = floor(WG.FlowUI.elementCorner * 0.66)
	local inset = floor((y2 - y1) * 0.18)
	local tx = x1 + self.pad
	-- The caret and selection want the box; the text baseline wants the font.
	local cy = floor((y1 + y2) * 0.5)
	local ty = text.baseline(font, y1, y2, self.fontSize)

	R(x1, y1, x2, y2, cs, 1, 1, 1, 1, fieldFill)

	local mx, my = Spring.GetMouseState()
	if mx >= x1 and mx <= x2 and my >= y1 and my <= y2 then
		WG.FlowUI.Draw.SelectHighlight(x1, y1, x2, y2, cs, hoverOpacity, white)
	end

	if self:hasSelection() then
		local a, b = self:selRange()
		local sa = floor(font:GetTextWidth(utf8.sub(self.text, 1, a)) * self.fontSize)
		local sb = floor(font:GetTextWidth(utf8.sub(self.text, 1, b)) * self.fontSize)
		gl.Color(0.4, 0.55, 0.85, 0.5)
		gl.Rect(tx + sa, y1 + inset, tx + sb, y2 - inset)
		gl.Color(1, 1, 1, 1)
	end

	-- The coloured string is kept until the text changes, not rebuilt every frame.
	local shown
	if self.text == "" and not self.focused then
		shown = self.placeholderShown
		if not shown then
			shown = colorDim .. self.placeholder
			self.placeholderShown = shown
		end
	else
		if self.shownFor ~= self.text then
			self.shownFor = self.text
			self.shown = colorText .. self.text
		end
		shown = self.shown
	end

	font:Begin()
	if self.outline then
		font:SetOutlineColor(self.outline)
	end
	font:Print(shown, tx, ty, self.fontSize, "o")
	font:End()

	if self.clearable and self.text ~= "" then
		drawClear(self, overClear(self, mx, my), cs)
	end

	if self.focused then
		-- Sized and placed off the font like chat, so it does not stretch with the field.
		local cx = floor(tx + caretOffset(self, font))
		local cWidth = 1 + floor(self.fontSize / 14)
		local cy1 = math.max(y1 + 1, floor(cy - self.fontSize * 0.6))
		local cy2 = math.min(y2 - 1, floor(cy + self.fontSize * 0.64))
		gl.Color(cursorGrey, cursorGrey, cursorGrey, caretAlpha(self))
		gl.Rect(cx, cy1, cx + cWidth, cy2)
		gl.Color(1, 1, 1, 1)
	end
end

return Editbox
