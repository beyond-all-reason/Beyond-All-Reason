-- The keybind editor's form for building an engine select command without writing its syntax.

local Dropdown = require("luaui/Include/keybind_dropdown")
local Editbox = require("luaui/Include/keybind_editbox")
local Select = require("luaui/Include/keybind_select")
local text = require("luaui/Include/keybind_text")

local floor = math.floor
local max = math.max
local min = math.min
local isInRect = math.isInRect

local colorText = "\255\235\235\235"
local colorDim = "\255\160\160\160"
local colorHeader = "\255\255\200\130"
local colorDanger = "\255\235\090\090"
local outline = { 0, 0, 0, 0.4 }
local white = { 1, 1, 1 }

-- FlowUI Button fades from color1 up to color2, so a tint needs its darker half spelled out.
local function pair(r, g, b)
	return { { r * 0.55, g * 0.55, b * 0.55, 1 }, { r, g, b, 1 } }
end

local faces = {
	plain = pair(0.18, 0.18, 0.18),
	confirm = pair(0.17, 0.38, 0.21),
	confirmHover = pair(0.24, 0.52, 0.29),
	confirmMuted = { { 0.07, 0.09, 0.07, 0.45 }, { 0.12, 0.17, 0.13, 0.45 } },
	danger = pair(0.46, 0.10, 0.10),
}

local KEY = "ui.keybinds.select."
local STATES = { "any", "is", "not" }

local function t(key, values)
	return BAR.I18N(KEY .. key, values)
end

local M = {}
M.__index = M
---@type boolean
M.open = false

function M.new()
	local self = setmetatable({}, M)
	self.scroll = 0
	self.args = {}
	self.on = {}
	self.ways = {}
	self.order = {}

	return self
end

local function field()
	return Editbox.new({ maxChars = 255, outline = outline })
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
			fields[i] = field()
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

function M:show(spec, opts)
	self.open = true
	self.scroll = 0
	self.title = opts.title
	self.acceptLabel = opts.acceptLabel
	self.cancelLabel = opts.cancelLabel
	self.onAccept = opts.onAccept
	self.onCancel = opts.onCancel
	self.args = {}
	self.on = {}
	self.ways = {}
	self.sourceArg = field()
	self.conclusionArg = field()
	self.L = labels()

	spec = spec or { source = "AllMap", filters = {}, clear = true, conclusion = "SelectAll" }
	self.source = spec.source
	self.sourceArg:setText(spec.sourceArg or "")
	self.conclusion = spec.conclusion
	self.conclusionArg:setText(spec.conclusionArg or "")
	self.clear = spec.clear

	-- Written back in the order they came in, so an edit changes only what the player changed.
	self.order = {}
	local names = {}
	for _, f in ipairs(spec.filters or {}) do
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

-- The spec the form describes, and whether every value it needs is one the engine can read.
function M:spec()
	local valid = true
	local function value(box, kind)
		local v = box:getText()
		if not Select.validArg(v, kind) then
			valid = false
		end

		return v
	end

	local spec = { source = self.source, filters = {}, clear = self.clear, conclusion = self.conclusion }
	local sourceKind = Select.sourceById[self.source].arg
	if sourceKind then
		spec.sourceArg = value(self.sourceArg, sourceKind)
	end
	local conclusionKind = Select.conclusionById[self.conclusion].arg
	if conclusionKind then
		spec.conclusionArg = value(self.conclusionArg, conclusionKind)
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
						spec.filters[#spec.filters + 1] = { id = id, negate = negate, args = { name } }
					end
					valid = valid and listed
				else
					local args = {}
					for i, kind in ipairs(Select.filterById[id].args or {}) do
						args[i] = value(fields[i], kind)
					end
					spec.filters[#spec.filters + 1] = { id = id, negate = negate, args = args }
				end
			end
		end
	end

	return spec, valid
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

	local font = WG["fonts"].getFont()
	local nameW = 0
	for _, name in pairs(self.L.filterName) do
		nameW = max(nameW, font:GetTextWidth(name))
	end
	g.gap = floor(6 * s)
	g.segW = floor(56 * s)
	g.segX = g.labelX + floor(nameW * g.fs) + floor(16 * s)
	g.argX = g.segX + g.segW * 3 + floor(12 * s)
	g.argX2 = g.x2 - g.pad - floor(8 * s) - g.gap

	g.wayLabelW = floor(max(font:GetTextWidth(self.L.state.is), font:GetTextWidth(self.L.state["not"])) * g.fs * 0.9)
		+ floor(8 * s)
	local btnPad = floor(16 * s)
	local cancelW = floor(font:GetTextWidth(self.cancelLabel or "") * g.fs) + btnPad * 2
	local acceptW = floor(font:GetTextWidth(self.acceptLabel or "") * g.fs) + btnPad * 2
	g.cancel = { g.x1 + g.pad, g.buttonY1, g.x1 + g.pad + cancelW, g.buttonY2 }
	g.accept = { g.x2 - g.pad - acceptW, g.buttonY1, g.x2 - g.pad, g.buttonY2 }
	local sw = floor(g.rowH * 0.7 * 1.8)
	local sh = floor(g.rowH * 0.7)
	local sy = g.clearY1 + floor((g.rowH - sh) * 0.5)
	g.switch = { g.controlX, sy, g.controlX + sw, sy + sh }
	g.clearHit = {
		g.controlX,
		g.clearY1,
		g.controlX + sw + floor(10 * s) + floor(font:GetTextWidth(self.L.replace) * g.fs),
		g.clearY2,
	}

	return g
end

function M:rect()
	local g = self.g

	return g.x1, g.y1, g.x2, g.y2
end

function M:clampScroll()
	self.scroll = max(0, min(self.scroll, #self.order - self.g.listRows))
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

local function drawButton(r, face, hovered)
	WG.FlowUI.Draw.Button(r[1], r[2], r[3], r[4], 1, 1, 1, 1, 1, 1, 1, 1, nil, face[1], face[2])
	if hovered then
		WG.FlowUI.Draw.SelectHighlight(r[1], r[2], r[3], r[4], floor(WG.FlowUI.elementCorner * 0.8), 0.25, white)
	end
end

function M:draw(mx, my)
	local g = self.g
	local font = WG["fonts"].getFont()
	local spec, valid = self:spec()
	local action = Select.format(spec)
	if self.summaryFor ~= action then
		self.summaryFor = action
		self.summary = Select.describe(spec)
	end
	local s = self.scale or 1

	-- Only the fields drawn this frame get a place; the rest must not take a click where they last were.
	for _, box in ipairs(self:fields()) do
		box:setRect(0, 0, 0, 0)
	end

	WG.FlowUI.Draw.RectRound(
		self.dim[1],
		self.dim[2],
		self.dim[3],
		self.dim[4],
		floor(WG.FlowUI.elementCorner),
		1,
		1,
		1,
		1,
		{ 0, 0, 0, 0.55 }
	)
	WG.FlowUI.Draw.Element(g.x1, g.y1, g.x2, g.y2, 1, 1, 1, 1, 1, 1, 1, 1, WG.FlowUI.clampedOpacity)

	drawButton(g.cancel, faces.plain, isInRect(mx, my, g.cancel[1], g.cancel[2], g.cancel[3], g.cancel[4]))
	local overAccept = valid and isInRect(mx, my, g.accept[1], g.accept[2], g.accept[3], g.accept[4])
	drawButton(g.accept, (not valid and faces.confirmMuted) or (overAccept and faces.confirmHover) or faces.confirm)
	WG.FlowUI.Draw.Toggle(
		g.switch[1],
		g.switch[2],
		g.switch[3],
		g.switch[4],
		self.clear and 1 or 0,
		isInRect(mx, my, g.clearHit[1], g.clearHit[2], g.clearHit[3], g.clearHit[4])
	)

	local segCs = floor(WG.FlowUI.elementCorner * 0.6)
	local wayLabels = {}
	for row = 1, g.listRows do
		local id = self.order[row + self.scroll]
		if not id then
			break
		end
		local top = g.listY2 - (row - 1) * g.rowH
		local y1, y2 = top - g.rowH + floor(3 * s), top - floor(3 * s)
		local on = self.on[id] or {}
		local both = on.is and on["not"]
		for k, name in ipairs(STATES) do
			local x1 = g.segX + (k - 1) * g.segW
			local r = { x1 + 1, y1, x1 + g.segW - 1, y2 }
			local lit = on[name] or (name == "any" and not (on.is or on["not"]))
			local face = (lit and name == "is" and faces.confirm)
				or (lit and name == "not" and faces.danger)
				or faces.plain
			WG.FlowUI.Draw.Button(r[1], r[2], r[3], r[4], 1, 1, 1, 1, 1, 1, 1, 1, nil, face[1], face[2])
			if not lit and isInRect(mx, my, r[1], r[2], r[3], r[4]) then
				WG.FlowUI.Draw.SelectHighlight(r[1], r[2], r[3], r[4], segCs, 0.25, white)
			end
		end
		local share = floor((g.argX2 - g.argX - (both and g.gap or 0)) / (both and 2 or 1))
		local numeric = (Select.filterById[id].args or {})[1] ~= "text"
		local x = g.argX
		for _, way in ipairs({ "is", "not" }) do
			if on[way] then
				local fields = self:argFields(id, way)
				local fx = x
				if both then
					wayLabels[#wayLabels + 1] = { way = way, x = fx, y = floor((y1 + y2) * 0.5) }
					fx = fx + g.wayLabelW
				end
				local fw = numeric and g.argW or floor((x + share - fx - g.gap * (#fields - 1)) / #fields)
				for _, box in ipairs(fields) do
					box:setRect(fx, y1, fx + fw, y2, g.fs)
					box:draw()
					fx = fx + fw + g.gap
				end
				x = x + share + g.gap
			end
		end
	end
	if #self.order > g.listRows then
		WG.FlowUI.Draw.Scroller(
			g.x2 - g.pad - floor(8 * s),
			g.listY1,
			g.x2 - g.pad,
			g.listY2,
			#self.order * g.rowH,
			self.scroll * g.rowH
		)
	end

	if Select.sourceById[self.source].arg then
		local x1 = g.controlX + g.pickerW + floor(10 * s)
		self.sourceArg:setRect(x1, g.fromY1, x1 + g.argW, g.fromY2, g.fs)
		self.sourceArg:draw()
	end
	if Select.conclusionById[self.conclusion].arg then
		local x1 = g.controlX + g.pickerW + floor(10 * s)
		self.conclusionArg:setRect(x1, g.pickY1, x1 + g.argW, g.pickY2, g.fs)
		self.conclusionArg:draw()
	end

	local L = self.L
	font:Begin()
	font:SetOutlineColor(outline)
	local cx = floor((g.x1 + g.x2) * 0.5)
	local innerW = g.x2 - g.x1 - g.pad * 2
	font:Print(colorText .. text.fit(font, self.title or "", innerW, g.titleFs), cx, g.titleY, g.titleFs, "cov")
	font:Print(
		(valid and colorHeader or colorDanger) .. text.fit(font, valid and self.summary or L.incomplete, innerW, g.fs),
		cx,
		g.summaryY,
		g.fs,
		"cov"
	)
	if valid then
		font:Print(colorDim .. text.fit(font, action, innerW, g.fs * 0.9), cx, g.rawY, g.fs * 0.9, "cov")
	end
	font:Print(colorText .. L.from, g.labelX, floor((g.fromY1 + g.fromY2) * 0.5), g.fs, "ov")
	font:Print(colorText .. L.pick, g.labelX, floor((g.pickY1 + g.pickY2) * 0.5), g.fs, "ov")
	font:Print(colorText .. L.replace, g.switch[3] + floor(10 * s), floor((g.clearY1 + g.clearY2) * 0.5), g.fs, "ov")
	font:Print(colorDim .. L.filters, g.labelX, g.filtersLabelY, g.fs, "ov")
	for row = 1, g.listRows do
		local id = self.order[row + self.scroll]
		if not id then
			break
		end
		local cy = floor(g.listY2 - (row - 0.5) * g.rowH)
		local on = self.on[id] or {}
		local any = not (on.is or on["not"])
		font:Print((any and colorDim or colorText) .. L.filterName[id], g.labelX, cy, g.fs, "ov")
		for k, name in ipairs(STATES) do
			local x = g.segX + (k - 0.5) * g.segW
			local lit = on[name] or (name == "any" and any)
			font:Print((lit and colorText or colorDim) .. L.state[name], x, cy, g.fs * 0.9, "cov")
		end
	end
	for _, label in ipairs(wayLabels) do
		font:Print(colorDim .. L.state[label.way], label.x, label.y, g.fs * 0.9, "ov")
	end
	font:Print(
		colorText .. (self.cancelLabel or ""),
		floor((g.cancel[1] + g.cancel[3]) * 0.5),
		floor((g.cancel[2] + g.cancel[4]) * 0.5),
		g.fs,
		"cov"
	)
	font:Print(
		(valid and colorText or colorDim) .. (self.acceptLabel or ""),
		floor((g.accept[1] + g.accept[3]) * 0.5),
		floor((g.accept[2] + g.accept[4]) * 0.5),
		g.fs,
		"cov"
	)
	font:End()

	-- Last, so an open list lies over the rows under it.
	self.conclusionPicker:setRect(g.controlX, g.pickY1, g.controlX + g.pickerW, g.pickY2, g.fs)
	self.sourcePicker:setRect(g.controlX, g.fromY1, g.controlX + g.pickerW, g.fromY2, g.fs)
	self.conclusionPicker:draw()
	self.sourcePicker:draw()
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
	local spec, valid = self:spec()
	if not valid then
		return
	end

	self.open = false
	if self.onAccept then
		self.onAccept(Select.format(spec), spec)
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
		not isInRect(x, y, g.x1, g.y1, g.x2, g.y2) or isInRect(x, y, g.cancel[1], g.cancel[2], g.cancel[3], g.cancel[4])
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

-- A field scrolled out of view lets go, or typing would change a value nobody can see.
function M:mouseWheel(up)
	local g = self.g
	local mx, my = Spring.GetMouseState()
	if not isInRect(mx, my, g.x1, g.listY1, g.x2, g.listY2) then
		return
	end

	self.scroll = self.scroll + (up and -1 or 1)
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
