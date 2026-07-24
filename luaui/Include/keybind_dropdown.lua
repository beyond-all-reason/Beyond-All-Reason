-- Select control for the keybind editor's preset picker.
-- Uses FlowUI's Selector visuals to match the Settings look. Shows the current
-- selection; onSelect(option, index) fires when a choice is picked.

local Dropdown = {}
Dropdown.__index = Dropdown

local floor = math.floor

local colorText = "\255\235\235\235"

local function getFont()
	return WG['fonts'].getFont()
end

local function optionLabel(opt)
	if type(opt) == "table" then
		return opt.label or tostring(opt.value)
	end

	return tostring(opt)
end

function Dropdown.new(opts)
	opts = opts or {}

	local self = setmetatable({}, Dropdown)
	self.options = opts.options or {}
	self.onSelect = opts.onSelect
	self.selected = opts.selected or 1
	self.placeholder = opts.placeholder -- when set, shown instead of the selection
	self.open = false
	self.rect = { 0, 0, 0, 0 }
	self.optRects = {}
	self.fontSize = 14

	return self
end

function Dropdown:setRect(x1, y1, x2, y2, fontSize)
	self.rect = { x1, y1, x2, y2 }
	self.fontSize = fontSize or (y2 - y1) * 0.5

	local optH = floor(y2 - y1)
	self.optRects = {}
	for i = 1, #self.options do
		self.optRects[i] = { x1 = x1, y1 = y1 - i * optH, x2 = x2, y2 = y1 - (i - 1) * optH }
	end
end

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

function Dropdown:draw()
	local font = getFont()
	local Selector = WG.FlowUI.Draw.Selector
	local Highlight = WG.FlowUI.Draw.SelectHighlight
	local R = WG.FlowUI.Draw.RectRound
	local mx, my = Spring.GetMouseState()
	local x1, y1, x2, y2 = self.rect[1], self.rect[2], self.rect[3], self.rect[4]
	local inset = floor((y2 - y1) * 0.3)

	Selector(x1, y1, x2, y2)

	font:Begin()
	local current = self.options[self.selected]
	local label = self.placeholder or (current and optionLabel(current) or "")
	font:Print(colorText .. label, x1 + inset, (y1 + y2) * 0.5, self.fontSize, "ov")
	font:End()

	if self.open and #self.optRects > 0 then
		local top = self.optRects[1].y2
		local bottom = self.optRects[#self.optRects].y1
		local cs = floor((y2 - y1) * 0.1)
		R(x1, bottom, x2, top, cs, 1, 1, 1, 1, { 0.09, 0.09, 0.09, 0.96 })

		font:Begin()
		for i, opt in ipairs(self.options) do
			local r = self.optRects[i]
			if mx >= r.x1 and mx <= r.x2 and my >= r.y1 and my <= r.y2 then
				Highlight(r.x1, r.y1, r.x2, r.y2, cs, 1, { 1, 1, 1 })
			end
			font:Print(colorText .. optionLabel(opt), r.x1 + inset, (r.y1 + r.y2) * 0.5, self.fontSize, "ov")
		end
		font:End()
	end
end

-- Returns true if the press was consumed (button toggle or option pick).
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
