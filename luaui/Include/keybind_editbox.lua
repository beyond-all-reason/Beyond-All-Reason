-- Reusable single-line text input with selection and editing shortcuts.
-- Instance-based: Editbox.new{...} per field. Selection / ctrl+a / ctrl+arrow
-- word-jump / shift+arrow / ctrl+backspace / mouse-drag select, UTF-8 aware.
-- Active only while focused, so it is safe to host alongside game input.

local utf8 = VFS.Include('common/luaUtilities/utf8.lua')

local Editbox = {}
Editbox.__index = Editbox

local floor = math.floor

local colorText = "\255\235\235\235"
local colorDim = "\255\160\160\160"

local function getFont()
	return WG['fonts'].getFont()
end

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
	self.onChange = opts.onChange
	self.rect = { 0, 0, 0, 0 }
	self.fontSize = 14
	self.pad = 6

	return self
end

function Editbox:setRect(x1, y1, x2, y2, fontSize, pad)
	self.rect = { x1, y1, x2, y2 }
	self.fontSize = fontSize or (y2 - y1) * 0.5
	self.pad = pad or floor((y2 - y1) * 0.2)
end

function Editbox:getText()
	return self.text
end

function Editbox:setText(t)
	self.text = t or ""
	self.caret = utf8.len(self.text)
	self.selAnchor = nil

	if self.onChange then
		self.onChange(self.text)
	end
end

function Editbox:focus()
	if not self.focused then
		self.focused = true
		if Spring.SDLStartTextInput then
			Spring.SDLStartTextInput()
		end
	end
end

function Editbox:blur()
	if self.focused then
		self.focused = false
		self.dragging = false
		if Spring.SDLStopTextInput then
			Spring.SDLStopTextInput()
		end
	end
end

function Editbox:isFocused()
	return self.focused
end

function Editbox:hasSelection()
	return self.selAnchor ~= nil and self.selAnchor ~= self.caret
end

function Editbox:selRange()
	return math.min(self.selAnchor, self.caret), math.max(self.selAnchor, self.caret)
end

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

function Editbox:setCaret(pos, extend)
	if extend then
		if not self.selAnchor then
			self.selAnchor = self.caret
		end
	else
		self.selAnchor = nil
	end

	local len = utf8.len(self.text)
	if pos < 0 then pos = 0 elseif pos > len then pos = len end
	self.caret = pos
end

function Editbox:prevWord()
	local pos = self.caret
	while pos > 0 and utf8.sub(self.text, pos, pos):match("%s") do pos = pos - 1 end
	while pos > 0 and not utf8.sub(self.text, pos, pos):match("%s") do pos = pos - 1 end

	return pos
end

function Editbox:nextWord()
	local len = utf8.len(self.text)
	local pos = self.caret
	while pos < len and not utf8.sub(self.text, pos + 1, pos + 1):match("%s") do pos = pos + 1 end
	while pos < len and utf8.sub(self.text, pos + 1, pos + 1):match("%s") do pos = pos + 1 end

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

function Editbox:keyPress(key)
	if not self.focused then
		return false
	end

	local _, ctrl, _, shift = Spring.GetModKeyState()
	local changed = false

	if ctrl and key == 97 then -- ctrl+a
		self.selAnchor = 0
		self.caret = utf8.len(self.text)
	elseif key == 27 or key == 13 then -- escape / enter
		self:blur()
	elseif key == 8 then -- backspace
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
	elseif key == 127 then -- delete
		if not self:deleteSelection() then
			if self.caret < utf8.len(self.text) then
				self.text = utf8.sub(self.text, 1, self.caret) .. utf8.sub(self.text, self.caret + 2)
			end
		end
		changed = true
	elseif key == 276 then -- left
		self:setCaret(ctrl and self:prevWord() or self.caret - 1, shift)
	elseif key == 275 then -- right
		self:setCaret(ctrl and self:nextWord() or self.caret + 1, shift)
	elseif key == 278 then -- home
		self:setCaret(0, shift)
	elseif key == 279 then -- end
		self:setCaret(utf8.len(self.text), shift)
	end

	if changed and self.onChange then
		self.onChange(self.text)
	end

	return true
end

function Editbox:mousePress(x, y)
	if x < self.rect[1] or x > self.rect[3] or y < self.rect[2] or y > self.rect[4] then
		return false
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

local function update(self)
	if self.dragging then
		local mx, _, lmb = Spring.GetMouseState()
		if lmb then
			self.caret = self:indexFromX(mx)
		else
			self.dragging = false
		end
	end
end

function Editbox:draw()
	update(self)

	local font = getFont()
	local R = WG.FlowUI.Draw.RectRound
	local x1, y1, x2, y2 = self.rect[1], self.rect[2], self.rect[3], self.rect[4]
	local cs = floor((y2 - y1) * 0.18)
	local tx = x1 + self.pad
	local ty = (y1 + y2) * 0.5

	R(x1, y1, x2, y2, cs, 1, 1, 1, 1, { 0, 0, 0, 0.35 })

	if self:hasSelection() then
		local a, b = self:selRange()
		local sa = font:GetTextWidth(utf8.sub(self.text, 1, a)) * self.fontSize
		local sb = font:GetTextWidth(utf8.sub(self.text, 1, b)) * self.fontSize
		gl.Color(0.4, 0.55, 0.85, 0.5)
		gl.Rect(tx + sa, y1 + cs, tx + sb, y2 - cs)
		gl.Color(1, 1, 1, 1)
	end

	font:Begin()
	if self.text == "" and not self.focused then
		font:Print(colorDim .. self.placeholder, tx, ty, self.fontSize, "ov")
	else
		font:Print(colorText .. self.text, tx, ty, self.fontSize, "ov")
	end
	font:End()

	if self.focused then
		local cw = font:GetTextWidth(utf8.sub(self.text, 1, self.caret)) * self.fontSize
		R(tx + cw, y1 + cs, tx + cw + math.max(1, floor(cs * 0.5)), y2 - cs, 0, 0, 0, 0, 0, { 1, 1, 1, 0.85 })
	end
end

return Editbox
