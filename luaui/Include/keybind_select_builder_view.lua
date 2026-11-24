-- The keybind editor's select command form as FlowUI draws it: functions over the model's keybind_select_builder,
-- and the bar that scrolls its filters.

local Select = require("luaui/Include/keybind_select")
local text = require("luaui/Include/keybind_text")

local floor = math.floor
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

local View = {}

-- What the form measures its layout with.
View.look = {
	textWidth = function(str)
		return WG["fonts"].getFont():GetTextWidth(str)
	end,
	barWidth = function(scale)
		return WG.FlowUI.Scroller.width(scale)
	end,
}

-- The filters' bar, a new one each time the form opens.
local bars = setmetatable({}, { __mode = "k" })
local function barOf(b)
	local bar = bars[b]
	if not bar or bar.serial ~= b.serial then
		bar = {
			serial = b.serial,
			scroller = WG.FlowUI.Scroller.new(function()
				return #b.order * b.g.rowH, b.scroll * b.g.rowH, b:maxScroll()
			end),
		}
		bars[b] = bar
	end

	return bar.scroller
end

-- A press on the filters' bar: true when it took it. An open list lies over everything else.
function View.pressBar(b, x, y)
	if b.sourcePicker:isOpen() or b.conclusionPicker:isOpen() then
		return false
	end
	local g = b.g
	if #b.order > g.listRows and isInRect(x, y, g.bar[1], g.bar[2], g.bar[3], g.bar[4]) then
		local step = barOf(b):press(y)
		if step then
			b:setScroll(step)
		end

		return true
	end

	return false
end

local function drawButton(r, face, hovered)
	WG.FlowUI.Draw.Button(r[1], r[2], r[3], r[4], 1, 1, 1, 1, 1, 1, 1, 1, nil, face[1], face[2])
	if hovered then
		WG.FlowUI.Draw.SelectHighlight(r[1], r[2], r[3], r[4], floor(WG.FlowUI.elementCorner * 0.8), 0.25, white)
	end
end

function View.draw(b, mx, my)
	local g = b.g
	local font = WG["fonts"].getFont()
	local command, valid = b:command()
	local action = Select.format(command)
	if b.summaryFor ~= action then
		b.summaryFor = action
		b.summary = Select.describe(command)
	end
	local s = b.scale or 1

	local scroller = barOf(b)
	scroller:setRect(g.bar[1], g.bar[2], g.bar[3], g.bar[4])
	local _, _, lmb = Spring.GetMouseState()
	local step = scroller:drag(my, lmb)
	if step then
		b:setScroll(step)
	end

	-- Only the fields drawn this frame get a place; the rest must not take a click where they last were.
	for _, box in ipairs(b:fields()) do
		box:setRect(0, 0, 0, 0)
	end

	WG.FlowUI.Draw.RectRound(
		b.dim[1],
		b.dim[2],
		b.dim[3],
		b.dim[4],
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
		b.clear and 1 or 0,
		isInRect(mx, my, g.clearHit[1], g.clearHit[2], g.clearHit[3], g.clearHit[4])
	)

	local segCs = floor(WG.FlowUI.elementCorner * 0.6)
	local wayLabels = {}
	for row = 1, g.listRows do
		local id = b.order[row + b.scroll]
		if not id then
			break
		end
		local top = g.listY2 - (row - 1) * g.rowH
		local y1, y2 = top - g.rowH + floor(3 * s), top - floor(3 * s)
		local on = b.on[id] or {}
		local both = on.is and on["not"]
		for k, name in ipairs(b.STATES) do
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
				local fields = b:argFields(id, way)
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
	scroller:draw(scroller:isOverThumb(mx, my))

	if Select.sourceById[b.source].arg then
		local x1 = g.controlX + g.pickerW + floor(10 * s)
		b.sourceArg:setRect(x1, g.fromY1, x1 + g.argW, g.fromY2, g.fs)
		b.sourceArg:draw()
	end
	if Select.conclusionById[b.conclusion].arg then
		local x1 = g.controlX + g.pickerW + floor(10 * s)
		b.conclusionArg:setRect(x1, g.pickY1, x1 + g.argW, g.pickY2, g.fs)
		b.conclusionArg:draw()
	end

	local L = b.L
	font:Begin()
	font:SetOutlineColor(outline)
	local cx = floor((g.x1 + g.x2) * 0.5)
	local innerW = g.x2 - g.x1 - g.pad * 2
	font:Print(colorText .. text.fit(font, b.title or "", innerW, g.titleFs), cx, g.titleY, g.titleFs, "cov")
	font:Print(
		(valid and colorHeader or colorDanger) .. text.fit(font, valid and b.summary or L.incomplete, innerW, g.fs),
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
		local id = b.order[row + b.scroll]
		if not id then
			break
		end
		local cy = floor(g.listY2 - (row - 0.5) * g.rowH)
		local on = b.on[id] or {}
		local any = not (on.is or on["not"])
		font:Print((any and colorDim or colorText) .. L.filterName[id], g.labelX, cy, g.fs, "ov")
		for k, name in ipairs(b.STATES) do
			local x = g.segX + (k - 0.5) * g.segW
			local lit = on[name] or (name == "any" and any)
			font:Print((lit and colorText or colorDim) .. L.state[name], x, cy, g.fs * 0.9, "cov")
		end
	end
	for _, label in ipairs(wayLabels) do
		font:Print(colorDim .. L.state[label.way], label.x, label.y, g.fs * 0.9, "ov")
	end
	font:Print(
		colorText .. (b.cancelLabel or ""),
		floor((g.cancel[1] + g.cancel[3]) * 0.5),
		floor((g.cancel[2] + g.cancel[4]) * 0.5),
		g.fs,
		"cov"
	)
	font:Print(
		(valid and colorText or colorDim) .. (b.acceptLabel or ""),
		floor((g.accept[1] + g.accept[3]) * 0.5),
		floor((g.accept[2] + g.accept[4]) * 0.5),
		g.fs,
		"cov"
	)
	font:End()

	-- Last, so an open list lies over the rows under it.
	b.conclusionPicker:setRect(g.controlX, g.pickY1, g.controlX + g.pickerW, g.pickY2, g.fs)
	b.sourcePicker:setRect(g.controlX, g.fromY1, g.controlX + g.pickerW, g.fromY2, g.fs)
	b.conclusionPicker:draw()
	b.sourcePicker:draw()
end

return View
