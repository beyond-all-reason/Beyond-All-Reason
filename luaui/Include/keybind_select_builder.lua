-- The keybind editor's form for building an engine select command without writing its syntax: what it holds, where
-- its parts go and what a press or a key does to it. A window draws it, scrolls it by its own bar (setScroll), and
-- gives it, with setLook, what it lays out by:
--   textWidth(text)   the text's width at size 1
--   barWidth(scale)   how wide that bar is
--   plainFields       true: its fields draw no plate of their own (keybind_editbox `plain`)

local Dropdown = require("luaui/Include/keybind_dropdown")
local Editbox = require("luaui/Include/keybind_editbox")
local Select = require("luaui/Include/keybind_select")

local floor = math.floor
local max = math.max
local min = math.min
local isInRect = math.isInRect

-- The font is shared with every other widget, some of which set an outline and leave it set.
local outline = { 0, 0, 0, 0.4 }

local KEY = "ui.keybinds.select."
local STATES = { "any", "is", "not" }

local function t(key, values)
	return BAR.I18N(KEY .. key, values)
end

local M = {}
M.__index = M
M.STATES = STATES
---@type boolean
M.open = false

function M.new()
	local self = setmetatable({}, M)
	self.scroll = 0
	self.args = {}
	self.on = {}
	self.ways = {}
	self.order = {}
	-- Bumped by every show, so what a window keeps for one showing is made again for the next.
	self.serial = 0
	self.look = {}

	return self
end

function M:setLook(look)
	self.look = look
end

function M:newField()
	return Editbox.new({ maxChars = 255, outline = outline, plain = self.look.plainFields })
end

function M:argFields(id, way)
	local byWay = self.args[id]
	if not byWay then
		byWay = {}
		self.args[id] = byWay
	end
	local fields = byWay[way]
	if not fields then
		fields = {}
		local kinds = (Select.filterById[id] or {}).args or {}
		for i = 1, #kinds do
			fields[i] = self:newField()
		end
		byWay[way] = fields
	end

	return fields
end

function M:waysOf(id)
	local out, seen = {}, {}
	for _, way in ipairs(self.ways[id] or {}) do
		out[#out + 1], seen[way] = way, true
	end
	for _, way in ipairs({ "is", "not" }) do
		if not seen[way] then
			out[#out + 1] = way
		end
	end

	return out
end

local function labels()
	local L = { filterName = {}, state = {} }
	for _, name in ipairs({ "from", "pick", "replace", "filters", "incomplete" }) do
		L[name] = t(name)
	end
	for _, f in ipairs(Select.filters) do
		L.filterName[f.id] = t("filterName." .. f.id)
	end
	for _, name in ipairs(STATES) do
		L.state[name] = t("state." .. name)
	end

	return L
end

function M:show(command, opts)
	self.open = true
	self.scroll = 0
	self.serial = self.serial + 1
	self.title = opts.title
	self.acceptLabel = opts.acceptLabel
	self.cancelLabel = opts.cancelLabel
	self.onAccept = opts.onAccept
	self.onCancel = opts.onCancel
	self.args = {}
	self.on = {}
	self.ways = {}
	self.sourceArg = self:newField()
	self.conclusionArg = self:newField()
	self.L = labels()

	command = command or { source = "AllMap", filters = {}, clear = true, conclusion = "SelectAll" }
	self.source = command.source
	self.sourceArg:setText(command.sourceArg or "")
	self.conclusion = command.conclusion
	self.conclusionArg:setText(command.conclusionArg or "")
	self.clear = command.clear

	-- Written back in the order they came in, so an edit changes only what the player changed.
	self.order = {}
	local names = {}
	for _, f in ipairs(command.filters or {}) do
		local way = f.negate and "not" or "is"
		if not self.on[f.id] then
			self.on[f.id], self.ways[f.id] = {}, {}
			self.order[#self.order + 1] = f.id
		end
		if not self.on[f.id][way] then
			self.on[f.id][way] = true
			table.insert(self.ways[f.id], way)
		end
		if f.id == "IdMatches" then
			names[way] = names[way] or {}
			table.insert(names[way], f.args[1])
		else
			for i, value in ipairs(f.args or {}) do
				self:argFields(f.id, way)[i]:setText(value)
			end
		end
	end
	for _, f in ipairs(Select.filters) do
		if not self.on[f.id] then
			self.order[#self.order + 1] = f.id
		end
	end
	for way, list in pairs(names) do
		self:argFields("IdMatches", way)[1]:setText(table.concat(list, ","))
	end

	local sources, conclusions = {}, {}
	for i, s in ipairs(Select.sources) do
		sources[i] = { label = t("sourceName." .. s.id), id = s.id }
	end
	for i, c in ipairs(Select.conclusions) do
		conclusions[i] = { label = t("conclusionName." .. c.id), id = c.id }
	end
	self.sourcePicker = Dropdown.new({
		options = sources,
		markSelected = true,
		outline = outline,
		onSelect = function(opt)
			self.source = opt.id
		end,
	})
	self.conclusionPicker = Dropdown.new({
		options = conclusions,
		markSelected = true,
		outline = outline,
		onSelect = function(opt)
			self.conclusion = opt.id
		end,
	})
	for i, s in ipairs(Select.sources) do
		if s.id == self.source then
			self.sourcePicker:setSelected(i)
		end
	end
	for i, c in ipairs(Select.conclusions) do
		if c.id == self.conclusion then
			self.conclusionPicker:setSelected(i)
		end
	end

	self.g = self:geometry()
end

function M:isOpen()
	return self.open
end

function M:close()
	self.open = false
end

function M:fields()
	local out = { self.sourceArg, self.conclusionArg }
	for _, byWay in pairs(self.args) do
		for _, fields in pairs(byWay) do
			for _, f in ipairs(fields) do
				out[#out + 1] = f
			end
		end
	end

	return out
end

-- The command the form describes, and whether every value it needs is one the engine can read.
function M:command()
	local valid = true
	local function value(box, kind)
		local v = box:getText()
		if not Select.validArg(v, kind) then
			valid = false
		end

		return v
	end

	local command = { source = self.source, filters = {}, clear = self.clear, conclusion = self.conclusion }
	local sourceKind = Select.sourceById[self.source].arg
	if sourceKind then
		command.sourceArg = value(self.sourceArg, sourceKind)
	end
	local conclusionKind = Select.conclusionById[self.conclusion].arg
	if conclusionKind then
		command.conclusionArg = value(self.conclusionArg, conclusionKind)
	end

	for _, id in ipairs(self.order) do
		local on = self.on[id] or {}
		for _, way in ipairs(self:waysOf(id)) do
			if on[way] then
				local negate = way == "not"
				local fields = self:argFields(id, way)
				if id == "IdMatches" then
					local listed = false
					for name in fields[1]:getText():gmatch("[^,%s]+") do
						listed = true
						valid = valid and Select.validArg(name, "text")
						command.filters[#command.filters + 1] = { id = id, negate = negate, args = { name } }
					end
					valid = valid and listed
				else
					local args = {}
					for i, kind in ipairs(Select.filterById[id].args or {}) do
						args[i] = value(fields[i], kind)
					end
					command.filters[#command.filters + 1] = { id = id, negate = negate, args = args }
				end
			end
		end
	end

	return command, valid
end

function M:setArea(x1, y1, x2, y2, scale, wx1, wy1, wx2, wy2)
	self.area = { x1, y1, x2, y2 }
	self.dim = { wx1 or x1, wy1 or y1, wx2 or x2, wy2 or y2 }
	self.scale = scale
	if self.open then
		self.g = self:geometry()
	end
end

function M:geometry()
	local s = self.scale or 1
	local a = self.area
	local w, h = floor(760 * s), floor(560 * s)
	local cx, cy = floor((a[1] + a[3]) * 0.5), floor((a[2] + a[4]) * 0.5)
	---@type table
	local g = {}
	g.x1, g.x2 = cx - floor(w * 0.5), cx + floor(w * 0.5)
	g.y1, g.y2 = cy - floor(h * 0.5), cy + floor(h * 0.5)
	g.pad = floor(16 * s)
	g.rowH = floor(28 * s)
	g.fs = floor(g.rowH * 0.5)
	g.titleFs = floor(g.rowH * 0.62)
	g.labelX = g.x1 + g.pad
	g.controlX = g.x1 + g.pad + floor(130 * s)
	g.pickerW = floor(240 * s)
	g.argW = floor(90 * s)

	g.titleY = g.y2 - floor(24 * s)
	g.summaryY = g.y2 - floor(52 * s)
	g.rawY = g.y2 - floor(72 * s)

	local function row(top)
		return top - g.rowH, top
	end
	g.fromY1, g.fromY2 = row(g.y2 - floor(92 * s))
	g.pickY1, g.pickY2 = row(g.fromY1 - floor(8 * s))
	g.clearY1, g.clearY2 = row(g.pickY1 - floor(8 * s))
	g.filtersLabelY = g.clearY1 - floor(22 * s)

	local bh = floor(30 * s)
	g.buttonY1, g.buttonY2 = g.y1 + g.pad, g.y1 + g.pad + bh
	g.listY2 = g.filtersLabelY - floor(14 * s)
	g.listY1 = g.buttonY2 + floor(14 * s)
	g.listRows = max(1, floor((g.listY2 - g.listY1) / g.rowH))
	-- Only as tall as the rows drawn, or the thumb counts the band's leftover as room.
	g.bar = { g.x2 - g.pad - self.look.barWidth(s), g.listY2 - g.listRows * g.rowH, g.x2 - g.pad, g.listY2 }

	local nameW = 0
	for _, name in pairs(self.L.filterName) do
		nameW = max(nameW, self.look.textWidth(name))
	end
	g.gap = floor(6 * s)
	g.segW = floor(56 * s)
	g.segX = g.labelX + floor(nameW * g.fs) + floor(16 * s)
	g.argX = g.segX + g.segW * 3 + floor(12 * s)
	g.argX2 = g.bar[1] - g.gap

	g.wayLabelW = floor(
		max(self.look.textWidth(self.L.state.is), self.look.textWidth(self.L.state["not"])) * g.fs * 0.9
	) + floor(8 * s)
	local btnPad = floor(16 * s)
	local cancelW = floor(self.look.textWidth(self.cancelLabel or "") * g.fs) + btnPad * 2
	local acceptW = floor(self.look.textWidth(self.acceptLabel or "") * g.fs) + btnPad * 2
	g.cancel = { g.x1 + g.pad, g.buttonY1, g.x1 + g.pad + cancelW, g.buttonY2 }
	g.accept = { g.x2 - g.pad - acceptW, g.buttonY1, g.x2 - g.pad, g.buttonY2 }
	local sw = floor(g.rowH * 0.7 * 1.8)
	local sh = floor(g.rowH * 0.7)
	local sy = g.clearY1 + floor((g.rowH - sh) * 0.5)
	g.switch = { g.controlX, sy, g.controlX + sw, sy + sh }
	g.clearHit = {
		g.controlX,
		g.clearY1,
		g.controlX + sw + floor(10 * s) + floor(self.look.textWidth(self.L.replace) * g.fs),
		g.clearY2,
	}

	return g
end

function M:rect()
	local g = self.g

	return g.x1, g.y1, g.x2, g.y2
end

function M:clampScroll()
	self.scroll = max(0, min(self.scroll, self:maxScroll()))
end

function M:maxScroll()
	return max(0, #self.order - self.g.listRows)
end

-- A field scrolled out of view lets go, or typing would change a value nobody can see.
function M:setScroll(scroll)
	local g = self.g
	self.scroll = scroll
	self:clampScroll()
	for row, id in ipairs(self.order) do
		if row <= self.scroll or row > self.scroll + g.listRows then
			for _, fields in pairs(self.args[id] or {}) do
				for _, box in ipairs(fields) do
					box:blur()
				end
			end
		end
	end
end

function M:filterAt(x, y)
	local g = self.g
	if y < g.listY1 or y > g.listY2 or x < g.x1 or x > g.x2 then
		return nil
	end

	local row = floor((g.listY2 - y) / g.rowH) + 1
	if row > g.listRows then
		return nil
	end

	return self.order[row + self.scroll]
end

function M:focus(box)
	for _, f in ipairs(self:fields()) do
		if f ~= box then
			f:blur()
		end
	end
	if box then
		box:focus()
	end
end

function M:accept()
	local command, valid = self:command()
	if not valid then
		return
	end

	self.open = false
	if self.onAccept then
		self.onAccept(Select.format(command), command)
	end
end

function M:cancel()
	self.open = false
	if self.onCancel then
		self.onCancel()
	end
end

function M:mousePress(x, y)
	local g = self.g

	if self.sourcePicker:isOpen() then
		self.sourcePicker:mousePress(x, y)

		return true
	end
	if self.conclusionPicker:isOpen() then
		self.conclusionPicker:mousePress(x, y)

		return true
	end
	if self.sourcePicker:mousePress(x, y) or self.conclusionPicker:mousePress(x, y) then
		self:focus(nil)

		return true
	end

	if
		not isInRect(x, y, g.x1, g.y1, g.x2, g.y2)
		or isInRect(x, y, g.cancel[1], g.cancel[2], g.cancel[3], g.cancel[4])
	then
		self:cancel()

		return true
	end
	if isInRect(x, y, g.accept[1], g.accept[2], g.accept[3], g.accept[4]) then
		self:accept()

		return true
	end
	if isInRect(x, y, g.clearHit[1], g.clearHit[2], g.clearHit[3], g.clearHit[4]) then
		self.clear = not self.clear

		return true
	end

	for _, box in ipairs(self:fields()) do
		if box:mousePress(x, y) then
			self:focus(box)

			return true
		end
	end

	local id = self:filterAt(x, y)
	if id and x >= g.segX and x < g.segX + g.segW * 3 then
		local picked = STATES[floor((x - g.segX) / g.segW) + 1]
		local on = self.on[id] or {}
		if picked == "any" then
			on = {}
		elseif Select.bothWays(id) then
			on[picked] = not on[picked] or nil
		else
			on = { [picked] = true }
		end
		self.on[id] = on
		local fields = on[picked] and self:argFields(id, picked)
		self:focus(fields and fields[1] or nil)
	end

	return true
end

function M:mouseWheel(up)
	local g = self.g
	local mx, my = Spring.GetMouseState()
	if not isInRect(mx, my, g.x1, g.listY1, g.x2, g.listY2) then
		return
	end

	self:setScroll(self.scroll + (up and -1 or 1))
end

function M:textInput(char)
	for _, box in ipairs(self:fields()) do
		if box:isFocused() then
			return box:textInput(char)
		end
	end

	return false
end

function M:keyPress(key)
	if key == 27 and (self.sourcePicker:isOpen() or self.conclusionPicker:isOpen()) then
		self.sourcePicker:close()
		self.conclusionPicker:close()
	elseif key == 27 then
		self:cancel()
	elseif key == 13 or key == 271 then
		self:accept()
	else
		for _, box in ipairs(self:fields()) do
			if box:isFocused() then
				box:keyPress(key)
			end
		end
	end

	return true
end

return M
