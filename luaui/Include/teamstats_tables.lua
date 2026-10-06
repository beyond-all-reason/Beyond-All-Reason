-- The team stats panel's tables: the summary that ships - how the game has gone so far - and
-- the player's own, each with the columns the player keeps in it, in their order, and the
-- column it is sorted by. Columns are added and taken out on the card the Columns... button
-- opens, moved by dragging a caption or from its right-click card. A table of the player's own
-- is made with the + on the Tables caption, and renamed, moved or deleted from its entry's
-- right-click card - the summary is put back as it shipped instead.
--
--   local tables = require("luaui/Include/teamstats_tables").new(ctx)
--   tables.setConfig(saved)                    -- or nothing, for the summary alone
--   local keys = tables.columnsOf("tableSummary")
--   saved = tables.getConfig()
--
-- ctx: COLUMNS, GROUPS (the built-in categories head the card's sections), L, columnShown,
-- columnTitle, i18n, look, metrics, colors, draw, font, queueText, columns (the table as laid
-- out, the name column first), openMenu (the Graphs page's card of actions), changed (the
-- columns of a table changed), listChanged (tables made, renamed, moved or deleted),
-- startNaming (a field over a table's entry), playSound.

local M = {}

local mathFloor = math.floor
local mathMax = math.max
local mathMin = math.min
local mathAbs = math.abs

-- What ships: the Overview's columns - the economy and army each side built, how it fought and
-- how fast it played - sorted by the damage dealt until the player sorts it another way.
local SHIPPED = {
	key = "tableSummary",
	name = "summary",
	columns = {
		"metalProduced",
		"energyProduced",
		"buildPower",
		"unitValue",
		"frontLine",
		"damageDealt",
		"valueEfficiency",
		"actionsPerMinute",
	},
	sortKey = "damageDealt",
}

-- The Graphs page's button backdrop, and the mark its cards put by what is in.
local PLATE = { 1, 1, 1, 0.05 }
local CHECK = "\226\128\162"

local function copy(list)
	local out = {}
	for i = 1, #list do
		out[i] = list[i]
	end
	return out
end

function M.new(ctx)
	---@type table<string, any>
	local tables = {
		-- In the sidebar's order, each { key, spec (the summary's), name, number, columns,
		-- sortKey, sortAscending }.
		---@type table[]
		list = {},
		---@type table<string, table>
		byKey = {},
		nextId = 1,
		-- The table shown last: the one the columns are laid out for while the graphs are up.
		current = SHIPPED.key,
		-- The Columns... button, laid out with the strip it sits in, and its caption.
		---@type number[]?
		button = nil,
		buttonLabel = "",
		-- The card of every column while it is open: whose it is, its rows and its outline as
		-- last drawn.
		---@type table?
		card = nil,
		-- A caption pressed, until it is let go: { key, x, y, fixed, moving }.
		---@type table?
		drag = nil,
		scale = 1,
	}
	local function shipped()
		return {
			key = SHIPPED.key,
			spec = SHIPPED,
			columns = copy(SHIPPED.columns),
			sortKey = SHIPPED.sortKey,
			sortAscending = false,
		}
	end

	local function index()
		tables.byKey = {}
		for _, t in ipairs(tables.list) do
			tables.byKey[t.key] = t
		end
	end

	tables.list[1] = shipped()
	index()

	-- What a table is called: the name it was given, else the summary's own or "My table N".
	function tables.label(t)
		if t.name and t.name ~= "" then
			return t.name
		end
		if t.spec then
			return ctx.i18n("ui.teamStats.tables." .. t.spec.name)
		end
		return ctx.i18n("ui.teamStats.tables.defaultName", { number = t.number or 1 })
	end

	-- What its entry says under the cursor: what it is, and what its right-click card offers.
	function tables.describe(t)
		local about = t.spec and ctx.i18n("ui.teamStats.tables." .. t.spec.name .. "Desc")
			or ctx.i18n("ui.teamStats.tables.ownDesc")
		local hint = ctx.i18n(t.spec and "ui.teamStats.tables.shippedHint" or "ui.teamStats.tables.ownHint")
		return about .. "\n" .. ctx.colors.dim .. hint
	end

	function tables.columnsOf(key)
		local t = tables.byKey[key]
		return t and t.columns or {}
	end

	-- A new table of the player's own, at the end, empty, named after the lowest number no
	-- other has until it is named.
	function tables.create()
		local taken = {}
		for _, t in ipairs(tables.list) do
			if t.number then
				taken[t.number] = true
			end
		end
		local number = 1
		while taken[number] do
			number = number + 1
		end
		local t = { key = "table" .. tables.nextId, number = number, columns = {}, sortAscending = false }
		tables.nextId = tables.nextId + 1
		tables.list[#tables.list + 1] = t
		index()
		return t
	end

	-- A name left empty gives the table back the one it would have without.
	function tables.rename(key, name)
		local t = tables.byKey[key]
		if t then
			name = (name or ""):gsub("^%s+", ""):gsub("%s+$", "")
			t.name = name ~= "" and name or nil
			ctx.listChanged()
		end
	end

	-- A table moved up (-1) or down (1) the list; false at either end.
	function tables.moveTable(key, delta)
		for i, t in ipairs(tables.list) do
			if t.key == key then
				local j = i + delta
				if j < 1 or j > #tables.list then
					return false
				end
				tables.list[i], tables.list[j] = tables.list[j], t
				ctx.listChanged()
				return true
			end
		end
		return false
	end

	-- A table of the player's own goes; the summary is put back as it shipped instead.
	function tables.delete(key)
		for i, t in ipairs(tables.list) do
			if t.key == key and not t.spec then
				table.remove(tables.list, i)
				index()
				if tables.current == key then
					tables.current = SHIPPED.key
				end
				ctx.listChanged()
				return true
			end
		end
		return false
	end

	-- Whether a table holds the columns it shipped with, in their order. One of the player's own
	-- never did.
	function tables.isShipped(t)
		if not t.spec then
			return false
		end
		local want = t.spec.columns
		if #t.columns ~= #want then
			return false
		end
		for i = 1, #want do
			if t.columns[i] ~= want[i] then
				return false
			end
		end
		return true
	end

	local function indexOf(t, column)
		for i, key in ipairs(t.columns) do
			if key == column then
				return i
			end
		end
		return nil
	end

	-- The columns on show, in order: what the game has nothing for is left out.
	local function shownOf(t)
		local list = {}
		for _, key in ipairs(t.columns) do
			local column = ctx.COLUMNS[key]
			if column and ctx.columnShown(column) then
				list[#list + 1] = key
			end
		end
		return list
	end

	function tables.has(key, column)
		local t = tables.byKey[key]
		return t ~= nil and indexOf(t, column) ~= nil
	end

	-- Whether a table has no room for another column: as many are on show as the panel says fit.
	function tables.full(key)
		local t = tables.byKey[key]
		return t ~= nil and #shownOf(t) >= ctx.capacity()
	end

	-- A column added at the table's end, or taken out of it.
	function tables.toggle(key, column)
		local t = tables.byKey[key]
		if not t then
			return
		end
		local at = indexOf(t, column)
		if at then
			table.remove(t.columns, at)
		else
			t.columns[#t.columns + 1] = column
		end
		ctx.changed()
	end

	-- A column moved in front of another, or to the end without one.
	function tables.place(key, column, before)
		local t = tables.byKey[key]
		local from = t and indexOf(t, column)
		if not from then
			return false
		end
		table.remove(t.columns, from)
		table.insert(t.columns, before and indexOf(t, before) or #t.columns + 1, column)
		ctx.changed()
		return true
	end

	-- One place left (-1) or right (1) among the columns on show.
	function tables.moveColumn(key, column, delta)
		local t = tables.byKey[key]
		if not t then
			return false
		end
		local shown = shownOf(t)
		for i, k in ipairs(shown) do
			if k == column then
				local j = i + delta
				if j < 1 or j > #shown then
					return false
				end
				return tables.place(key, column, delta < 0 and shown[j] or shown[j + 1])
			end
		end
		return false
	end

	-- A table's columns replaced by these, in their order.
	function tables.setColumns(key, list)
		local t = tables.byKey[key]
		if t then
			t.columns = copy(list)
			ctx.changed()
		end
	end

	function tables.reset(key)
		local t = tables.byKey[key]
		if t and t.spec then
			tables.setColumns(key, t.spec.columns)
		end
	end

	-- What a table is sorted by: the column it was left sorted by while that is on show, else
	-- its first column, else the names. A column that comes back is sorted by again.
	function tables.sortOf(key)
		local t = tables.byKey[key]
		if not t then
			return "name", true
		end
		if t.sortKey == "name" then
			return "name", t.sortAscending
		end
		local shown = shownOf(t)
		for _, k in ipairs(shown) do
			if k == t.sortKey then
				return k, t.sortAscending
			end
		end
		if shown[1] then
			return shown[1], false
		end
		return "name", true
	end

	function tables.setSort(key, sortKey, ascending)
		local t = tables.byKey[key]
		if t then
			t.sortKey, t.sortAscending = sortKey, ascending
		end
	end

	----------------------------------------------------------------
	-- Kept between games
	----------------------------------------------------------------

	-- The tables in their order. The summary's columns are kept only once they differ from what
	-- shipped, so a game that ships other ones reaches a summary nobody changed.
	function tables.getConfig()
		local list = {}
		for _, t in ipairs(tables.list) do
			list[#list + 1] = {
				key = t.key,
				shipped = t.spec and true or nil,
				name = t.name,
				number = t.number,
				columns = not tables.isShipped(t) and copy(t.columns) or nil,
				sortKey = t.sortKey,
				sortAscending = t.sortAscending,
			}
		end
		return { list = list, nextId = tables.nextId }
	end

	-- A table read back: a column the game no longer has is left out, as are the names column and
	-- a second copy of one.
	local function restore(t, saved)
		if type(saved.columns) == "table" then
			local list, seen = {}, {}
			for _, key in ipairs(saved.columns) do
				if key ~= "name" and ctx.COLUMNS[key] and not seen[key] then
					seen[key] = true
					list[#list + 1] = key
				end
			end
			t.columns = list
		end
		if saved.sortKey == "name" or ctx.COLUMNS[saved.sortKey] then
			t.sortKey = saved.sortKey
		end
		t.sortAscending = saved.sortAscending == true
		t.name = type(saved.name) == "string" and saved.name ~= "" and saved.name or nil
	end

	-- What was kept. The summary is there whatever was kept; the first version kept a map by key,
	-- of which only the summary is read.
	function tables.setConfig(data)
		if type(data) ~= "table" then
			return
		end
		tables.list, tables.byKey = {}, {}
		if type(data.list) == "table" then
			tables.nextId = tonumber(data.nextId) or 1
			for _, saved in ipairs(data.list) do
				if type(saved) == "table" and type(saved.key) == "string" then
					if saved.shipped and not tables.byKey[SHIPPED.key] then
						local t = shipped()
						restore(t, saved)
						tables.list[#tables.list + 1] = t
					elseif not saved.shipped and saved.key ~= SHIPPED.key and not tables.byKey[saved.key] then
						local t =
							{ key = saved.key, number = tonumber(saved.number), columns = {}, sortAscending = false }
						restore(t, saved)
						tables.list[#tables.list + 1] = t
					end
					index()
				end
			end
		end
		if not tables.byKey[SHIPPED.key] then
			local t = shipped()
			if type(data[SHIPPED.key]) == "table" then
				restore(t, data[SHIPPED.key])
			end
			table.insert(tables.list, 1, t)
		end
		-- A new table's key is never one already kept, whatever the count read back said.
		for _, t in ipairs(tables.list) do
			local n = tonumber(t.key:match("^table(%d+)$"))
			if n and n >= tables.nextId then
				tables.nextId = n + 1
			end
		end
		index()
		if not tables.byKey[tables.current] then
			tables.current = SHIPPED.key
		end
	end

	----------------------------------------------------------------
	-- The Columns... button and its card
	----------------------------------------------------------------

	-- The button at the left end of the strip over the table, a plate like the Graphs page's.
	function tables.layout(x1, y1, y2, scale)
		tables.scale = scale
		local font = ctx.font()
		local fs = ctx.metrics.catFs
		local label = ctx.i18n("ui.teamStats.tables.columns")
		local w = (font and mathFloor(font:GetTextWidth(label) * fs) or mathFloor(#label * fs * 0.55))
			+ ctx.metrics.sidePad * 2
		local inset = mathFloor(2 * scale)
		tables.button, tables.buttonLabel = { x1, y1 + inset, x1 + w, y2 - inset }, label
	end

	function tables.buttonAt(x, y)
		local b = tables.button
		return b ~= nil and x >= b[1] and x <= b[3] and y >= b[2] and y <= b[4]
	end

	-- Into the panel's baked list: lit while its card is open.
	function tables.drawButton(hovered)
		local b = tables.button
		if not b then
			return
		end
		local metrics, look = ctx.metrics, ctx.look
		local open = tables.card ~= nil
		ctx.draw.RectRound(b[1], b[2], b[3], b[4], metrics.csSmall, 1, 1, 1, 1, open and look.selectedFill or PLATE)
		if hovered then
			ctx.draw.Highlight(b[1], b[2], b[3], b[4], metrics.csSmall, look.barHoverOpacity, look.white)
		end
		ctx.queueText(
			(open and ctx.colors.selected or ctx.colors.title) .. tables.buttonLabel,
			mathFloor((b[1] + b[3]) * 0.5),
			mathFloor((b[2] + b[4]) * 0.5),
			metrics.catFs,
			"ovc"
		)
	end

	-- The + at the right end of a sidebar caption, which makes a table - or a category of graphs -
	-- of the player's own.
	local function addRect(_, y1, x2, y2)
		local inset = mathFloor(3 * tables.scale)
		local size = y2 - y1 - inset * 2
		local right = x2 - ctx.metrics.catInset
		return right - size, y1 + inset, right, y2 - inset
	end

	function tables.addAt(x, y, x1, y1, x2, y2)
		local ax1, ay1, ax2, ay2 = addRect(x1, y1, x2, y2)
		return x >= ax1 and x <= ax2 and y >= ay1 and y <= ay2
	end

	function tables.drawAdd(hovered, x1, y1, x2, y2)
		local ax1, ay1, ax2, ay2 = addRect(x1, y1, x2, y2)
		local metrics, look = ctx.metrics, ctx.look
		ctx.draw.RectRound(ax1, ay1, ax2, ay2, metrics.csSmall, 1, 1, 1, 1, PLATE)
		if hovered then
			ctx.draw.Highlight(ax1, ay1, ax2, ay2, metrics.csSmall, look.barHoverOpacity, look.white)
		end
		ctx.queueText(
			ctx.colors.title .. "+",
			mathFloor((ax1 + ax2) * 0.5),
			mathFloor((ay1 + ay2) * 0.5),
			metrics.catFs,
			"ovc"
		)
	end

	function tables.cardOpen()
		return tables.card ~= nil
	end

	function tables.openCard(key)
		tables.card = { key = key, rows = {}, cats = {} }
	end

	function tables.closeCard()
		tables.card = nil
	end

	-- Every column the game can show, a section per built-in category in the sidebar's order.
	local function sections()
		local list = {}
		for _, group in ipairs(ctx.GROUPS) do
			if not group.custom then
				local rows = {}
				for _, key in ipairs(group.columns) do
					local column = ctx.COLUMNS[key]
					if column and ctx.columnShown(column) then
						rows[#rows + 1] = column
					end
				end
				if #rows > 0 then
					list[#list + 1] = { key = group.key, label = ctx.L.group[group.key] or group.key, rows = rows }
				end
			end
		end
		return list
	end

	-- Text drawn after the panel's list is printed in a batch of its own, with the outline
	-- pinned: the font is shared with every other widget.
	local function printTexts(texts, fs)
		local font = ctx.font()
		if not font then
			return
		end
		font:Begin()
		font:SetOutlineColor(ctx.look.outline)
		for _, t in ipairs(texts) do
			font:Print(t[1], t[2], t[3], fs, t[4] or "ov")
		end
		font:End()
	end

	-- The card, under the button and flush with its left edge: the categories down the left, the
	-- one picked lit and each saying how many of its stats the table has, and the picked one's
	-- stats down the right, a mark by those the table has. A press on a category shows its stats;
	-- one on a stat adds it at the table's end or takes it out, and the card stays for the next.
	-- A full table takes no more, and says so. As wide as the longest stat of any category, so it
	-- keeps its size from one category to the next.
	function tables.drawCard(mx, my)
		local card, b = tables.card, tables.button
		local t = card and tables.byKey[card.key]
		if not (card and b and t) then
			return
		end
		local metrics, look, colors = ctx.metrics, ctx.look, ctx.colors
		local font = ctx.font()
		local fs, pad, lip, rowH = metrics.catFs, metrics.sidePad, metrics.cardLip, metrics.rowHeight
		local tick = mathFloor(fs * 1.2)
		local function widthOf(s)
			return font and mathFloor(font:GetTextWidth(s) * fs) or mathFloor(#s * fs * 0.55)
		end
		local list = sections()
		---@type table?
		local shown = nil
		for _, section in ipairs(list) do
			section.count = 0
			for _, column in ipairs(section.rows) do
				if indexOf(t, column.key) then
					section.count = section.count + 1
				end
			end
			if section.key == card.group then
				shown = section
			end
		end
		-- First opened on the category of the table's first stat, or the first.
		if not shown then
			local first = shownOf(t)[1]
			for _, section in ipairs(list) do
				for _, column in ipairs(section.rows) do
					if column.key == first then
						shown = section
					end
				end
			end
			shown = shown or list[1]
			if not shown then
				return
			end
			card.group = shown.key
		end
		---@type number, number, integer
		local leftW, rightW, rows = 0, 0, #list
		for _, section in ipairs(list) do
			leftW = mathMax(leftW, widthOf(section.label) + widthOf("00") + pad)
			for _, column in ipairs(section.rows) do
				rightW = mathMax(rightW, tick + widthOf(ctx.columnTitle(column)))
			end
			rows = mathMax(rows, #section.rows)
		end
		leftW = leftW + pad * 2
		local full = tables.full(card.key)
		local hint = ctx.i18n(full and "ui.teamStats.tables.full" or "ui.teamStats.tables.cardHint")
		local title = colors.title .. tables.label(t) .. "  " .. colors.dim .. hint
		local width = mathMax(leftW + rightW + pad * 2, widthOf(title) + pad * 2)
		local height = rowH * (rows + 1) + lip * 2
		local y2 = b[2] - mathFloor(6 * tables.scale)
		local x1 = mathMax(0, mathMin(b[1], Spring.GetViewGeometry() - width))
		local y1 = y2 - height
		local top = y2 - lip - rowH
		ctx.draw.RectRound(x1, y1, x1 + width, y2, metrics.csPanel, 1, 1, 1, 1, look.cardFill, look.cardFillTop)
		-- The rule between the two lists.
		ctx.draw.RectRound(x1 + leftW, y1 + lip, x1 + leftW + 1, top, 0, 0, 0, 0, 0, look.rule)
		local texts = { { title, x1 + pad, y2 - lip - mathFloor(rowH * 0.5) } }
		card.rows, card.cats, card.box = {}, {}, { x1, y1, x1 + width, y2 }
		local function over(rect)
			return mx and mx >= rect[1] and mx <= rect[3] and my >= rect[2] and my <= rect[4]
		end
		local function light(rect)
			ctx.draw.Highlight(
				rect[1] + metrics.catInset,
				rect[2],
				rect[3] - metrics.catInset,
				rect[4],
				metrics.csSmall,
				look.rowHoverOpacity,
				look.white
			)
		end
		for i, section in ipairs(list) do
			local rect = { x1, top - i * rowH, x1 + leftW, top - (i - 1) * rowH }
			card.cats[i] = { key = section.key, rect = rect }
			local cy = mathFloor((rect[2] + rect[4]) * 0.5)
			local picked = section == shown
			if picked then
				local inset = metrics.catInset
				ctx.draw.RectRound(
					rect[1] + inset,
					rect[2],
					rect[3] - inset,
					rect[4],
					metrics.csSmall,
					1,
					1,
					1,
					1,
					look.selectedFill
				)
			elseif over(rect) then
				light(rect)
			end
			texts[#texts + 1] = { (picked and colors.selected or colors.dim) .. section.label, rect[1] + pad, cy }
			if section.count > 0 then
				texts[#texts + 1] = { colors.dim .. section.count, rect[3] - pad, cy, "rov" }
			end
		end
		local cx = x1 + leftW
		for i, column in ipairs(shown.rows) do
			local rect = { cx, top - i * rowH, x1 + width, top - (i - 1) * rowH }
			card.rows[i] = { key = column.key, rect = rect }
			local cy = mathFloor((rect[2] + rect[4]) * 0.5)
			local on = indexOf(t, column.key) ~= nil
			local shut = full and not on
			if not shut and over(rect) then
				light(rect)
			end
			if on then
				texts[#texts + 1] = { colors.selected .. CHECK, cx + pad, cy }
			end
			local color = on and colors.selected or (shut and colors.faded or colors.dim)
			texts[#texts + 1] = { color .. ctx.columnTitle(column), cx + pad + tick, cy }
		end
		ctx.draw.Color(1, 1, 1, 1)
		printTexts(texts, fs)
	end

	-- The column whose row of the card is at x,y, as last drawn.
	function tables.cardRowAt(x, y)
		for _, row in ipairs(tables.card and tables.card.rows or {}) do
			local r = row.rect
			if x >= r[1] and x <= r[3] and y >= r[2] and y <= r[4] then
				return row.key
			end
		end
		return nil
	end

	-- What a row of the card says under the cursor: what its column shows, and why it cannot go
	-- in when the table is full.
	function tables.cardTip(x, y)
		local key = tables.cardRowAt(x, y)
		if not key then
			return nil, nil
		end
		local tip = ctx.L.desc[key] or ""
		if not tables.has(tables.card.key, key) and tables.full(tables.card.key) then
			tip = tip .. "\n" .. ctx.colors.dim .. ctx.i18n("ui.teamStats.tables.full")
		end
		return ctx.columnTitle(ctx.COLUMNS[key]), tip
	end

	-- While the card is open it takes every press: a category shows its stats, a stat's row adds
	-- or takes out its column, the rest of the card does nothing, and a press anywhere else puts
	-- the card away.
	function tables.cardPress(x, y, button)
		local card = tables.card
		if not card then
			return false
		end
		for _, cat in ipairs(card.cats) do
			local r = cat.rect
			if x >= r[1] and x <= r[3] and y >= r[2] and y <= r[4] then
				if button ~= 3 and cat.key ~= card.group then
					card.group = cat.key
					ctx.playSound()
				end
				return true
			end
		end
		local key = tables.cardRowAt(x, y)
		if key then
			if button ~= 3 and (tables.has(card.key, key) or not tables.full(card.key)) then
				tables.toggle(card.key, key)
				ctx.playSound()
			end
			return true
		end
		local box = card.box
		if not (box and x >= box[1] and x <= box[3] and y >= box[2] and y <= box[4]) then
			tables.card = nil
		end
		return true
	end

	----------------------------------------------------------------
	-- A caption dragged to another place, and its right-click card
	----------------------------------------------------------------

	-- How far a pressed caption travels before it is a drag rather than a click, which sorts.
	local function dragThreshold()
		return mathMax(4, mathFloor(6 * tables.scale))
	end

	-- The name column stays first, so it only ever sorts.
	function tables.press(key, x, y, fixed)
		tables.drag = { key = key, x = x, y = y, fixed = fixed }
	end

	function tables.dragMoving()
		return tables.drag ~= nil and tables.drag.moving == true
	end

	-- Every frame of a press on a caption: a drag once it has travelled. A press let go where
	-- the panel never heard of it is dropped.
	function tables.dragUpdate(mx, my, held)
		local drag = tables.drag
		if not drag then
			return
		end
		if not held then
			tables.drag = nil
		elseif not drag.fixed and mathMax(mathAbs(mx - drag.x), mathAbs(my - drag.y)) > dragThreshold() then
			drag.moving = true
		end
	end

	-- Where the dragged column lands if let go at x: at the edge between two columns nearest the
	-- cursor. Answers the column it goes in front of (none: the end) and the edge; nothing where
	-- it is already.
	---@return { before: string?, x: number }?
	local function dropTarget(x)
		local drag = tables.drag
		local cols = ctx.columns()
		if not (drag and drag.moving) then
			return nil
		end
		local from
		for i = 2, #cols do
			if cols[i].key == drag.key then
				from = i
			end
		end
		if not from then
			return nil
		end
		local best, nearest = from, math.huge
		for i = 2, #cols + 1 do
			local edge = cols[i] and cols[i].x1 or cols[#cols].x2
			if mathAbs(x - edge) < nearest then
				best, nearest = i, mathAbs(x - edge)
			end
		end
		if best == from or best == from + 1 then
			return nil
		end
		return { before = cols[best] and cols[best].key or nil, x = cols[best] and cols[best].x1 or cols[#cols].x2 }
	end

	-- The drag over the table: the column's own place shaded from its caption down to the last
	-- row, a line where it would land, and its name beside the cursor.
	function tables.drawDrag(mx, my)
		local drag = tables.drag
		if not (drag and drag.moving) then
			return
		end
		local top, bottom = ctx.dragBounds()
		local metrics, look = ctx.metrics, ctx.look
		for _, c in ipairs(ctx.columns()) do
			if c.key == drag.key then
				ctx.draw.RectRound(c.x1, bottom, c.x2, top, metrics.csSmall, 1, 1, 1, 1, look.dragShade)
			end
		end
		local target = dropTarget(mx)
		if target then
			local w = mathMax(2, mathFloor(3 * tables.scale))
			local lx = mathFloor(target.x - w * 0.5)
			ctx.draw.RectRound(lx, bottom, lx + w, top, 0, 0, 0, 0, 0, look.dropLine)
		end
		local column = ctx.COLUMNS[drag.key]
		local label = column and ctx.columnTitle(column) or drag.key
		local fs, pad = metrics.catFs, metrics.sidePad
		local font = ctx.font()
		local w = (font and mathFloor(font:GetTextWidth(label) * fs) or mathFloor(#label * fs * 0.55)) + pad * 2
		local h = mathFloor(metrics.catRowHeight * 0.9)
		local x1 = mathFloor(mx + 14 * tables.scale)
		if x1 + w > Spring.GetViewGeometry() then
			x1 = mathFloor(mx - 14 * tables.scale - w)
		end
		local y2 = mathFloor(my - 6 * tables.scale)
		ctx.draw.RectRound(x1, y2 - h, x1 + w, y2, metrics.csSmall, 1, 1, 1, 1, look.cardFill, look.cardFillTop)
		ctx.draw.Color(1, 1, 1, 1)
		printTexts({ { ctx.colors.title .. label, x1 + pad, mathFloor(y2 - h * 0.5) } }, fs)
	end

	-- The caption let go: moved to where the line showed, or - not moved - a click. Answers
	-- which of the two it was and the column.
	function tables.release(x, key)
		local drag = tables.drag
		if not drag then
			return nil
		end
		local target = dropTarget(x)
		tables.drag = nil
		if not drag.moving then
			return "click", drag.key
		end
		if target then
			tables.place(key, drag.key, target.before)
			ctx.playSound()
		end
		return "moved", drag.key
	end

	-- Right-click on a caption: the column moved a place, or taken out of the table.
	function tables.openColumnMenu(key, column, anchor)
		local t = tables.byKey[key]
		if not t then
			return
		end
		local shown = shownOf(t)
		local at = 0
		for i, k in ipairs(shown) do
			if k == column.key then
				at = i
			end
		end
		ctx.openMenu({
			{
				label = ctx.i18n("ui.teamStats.tables.moveLeft"),
				disabled = at <= 1,
				act = function()
					tables.moveColumn(key, column.key, -1)
				end,
			},
			{
				label = ctx.i18n("ui.teamStats.tables.moveRight"),
				disabled = at == 0 or at == #shown,
				act = function()
					tables.moveColumn(key, column.key, 1)
				end,
			},
			{
				label = ctx.i18n("ui.teamStats.tables.remove"),
				act = function()
					tables.toggle(key, column.key)
				end,
			},
		}, anchor, ctx.columnTitle(column), "column")
	end

	-- Right-click on a table's entry: renamed, moved, and deleted - the summary's columns put back
	-- as they shipped instead. Both destructive rows ask to be sure.
	function tables.openEntryMenu(key, anchor)
		local t = tables.byKey[key]
		if not t then
			return
		end
		local at = 1
		for i, other in ipairs(tables.list) do
			if other == t then
				at = i
			end
		end
		local L = "ui.teamStats.custom."
		local rows = {
			{
				label = ctx.i18n(L .. "rename"),
				act = function()
					ctx.startNaming(key)
				end,
			},
			{
				label = ctx.i18n(L .. "moveUp"),
				disabled = at == 1,
				act = function()
					tables.moveTable(key, -1)
				end,
			},
			{
				label = ctx.i18n(L .. "moveDown"),
				disabled = at == #tables.list,
				act = function()
					tables.moveTable(key, 1)
				end,
			},
		}
		if t.spec then
			rows[#rows + 1] = {
				label = ctx.i18n(L .. "reset"),
				confirm = ctx.i18n(L .. "resetConfirm"),
				disabled = tables.isShipped(t),
				act = function()
					tables.reset(key)
				end,
			}
		else
			rows[#rows + 1] = {
				label = ctx.i18n(L .. "delete"),
				confirm = ctx.i18n(L .. "deleteConfirm"),
				act = function()
					tables.delete(key)
				end,
			}
		end
		ctx.openMenu(rows, anchor, tables.label(t), "category")
	end

	return tables
end

return M
