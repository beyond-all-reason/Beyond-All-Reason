local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "TeamStats",
		desc = "Shows game stats.",
		author = "Floris",
		version = "2.0",
		date = "",
		license = "GNU GPL, v2 or later",
		layer = -99990,
		enabled = true,
	}
end

local text = require("luaui/Include/keybind_text")

-- Localized functions for performance
local mathFloor = math.floor
local mathMax = math.max
local mathMin = math.min
local mathHuge = math.huge
local math_isInRect = math.isInRect

-- Localized Spring API for performance
local spGetViewGeometry = Spring.GetViewGeometry
local spGetMouseState = Spring.GetMouseState
local spIsGUIHidden = Spring.IsGUIHidden
local spGetModKeyState = Spring.GetModKeyState
local spSetMouseCursor = Spring.SetMouseCursor

local glCreateList = gl.CreateList
local glCallList = gl.CallList
local glDeleteList = gl.DeleteList
local glColor = gl.Color
local glTexture = gl.Texture
local glBeginEnd = gl.BeginEnd
local glVertex = gl.Vertex
local GL_TRIANGLES = GL.TRIANGLES

-- What the panel shows, apart from how it shows it: the columns, the numbers, the rows, the switches.
local model = VFS.Include("luaui/Include/teamstats_model.lua")
local view = model.view
local COLUMNS, groupByKey, switches = model.COLUMNS, model.groupByKey, model.switches
local filters, handover, L = model.filters, model.handover, model.L

local screenHeightOrg = 610
local screenWidthOrg = 1100
local screenHeight = screenHeightOrg
local screenWidth = screenWidthOrg

local vsx, vsy = spGetViewGeometry()
local widgetScale = (vsy / 1080)
local screenX = mathFloor((vsx * 0.5) - (screenWidth / 2))
local screenY = mathFloor((vsy * 0.5) + (screenHeight / 2))

---@type function
local RectRound
---@type function
local UiElement
---@type function
local UiScroller
---@type function
local UiScrollerAt
---@type function
local Highlight
---@type function
local UiToggle
---@type number
local elementCorner
---@type LuaFont
local font

----------------------------------------------------------------
-- Layout and look
----------------------------------------------------------------

local area = { x1 = 0, y1 = 0, x2 = 0, y2 = 0 }
-- Sizes derived from the scale, in one table rather than a local each, the way the other
-- panels hold their own.
local metrics = {
	-- The numbers are set in the monospaced face, so a column of them lines up figure
	-- under figure however wide each one is, and the player names in the face the rest of
	-- the interface names players in; everything else is the interface's own.
	numFont = nil,
	nameFont = nil,
	rowHeight = 24,
	rowFs = 13,
	-- An ally team's band stands taller than the rows under it and is set larger, so it
	-- reads as a divider rather than another row.
	bandRowHeight = 32,
	bandFs = 14,
	-- The two rows of the table header: the group captions spanning their columns, and
	-- the stat captions under them that sort when clicked.
	groupRowHeight = 22,
	groupFs = 13,
	statRowHeight = 24,
	statFs = 12,
	catRowHeight = 29,
	catFs = 13,
	-- The rule in the column between the player's categories and the built-in ones, and the
	-- caption over the tables and over the graphs.
	dividerH = 14,
	sectionH = 26,
	-- The air between the column's cards: the tables', the graphs' and the settings'.
	islandGap = 7,
	rowPad = 6,
	-- Room a number keeps from the right edge of its cell; the sort marker sits in it.
	cellPad = 7,
	sidePad = 12,
	catInset = 4,
	-- The bar of team colour down a row's left edge, and how far it stops short of the
	-- rows above and below so each reads as its own.
	accentW = 3,
	accentPad = 3,
	-- The bar behind a number, inside its row by this much top and bottom; the trend line
	-- that can take its place is drawn this thick.
	barInset = 4,
	trendW = 1,
	-- The mark under the number of a column a row leads: this far above the row's bottom
	-- edge, and this thick.
	leadDrop = 3,
	leadH = 2,
	-- The line along the bottom of a group caption and of an ally team's band.
	underlineH = 2,
	-- Everything that sits against the panel's right edge - the switches and the
	-- scrollbar - is held off it by this much.
	edgeInset = 4,
	-- The band the title sits in, and the gap below it.
	headerH = 34,
	-- The top of the settings' card at the foot of the column, and where the groups above it
	-- stop: inside the graphs' card, which ends the air above the settings'.
	settingsCardTop = 0,
	settingsTop = 0,
	headerGap = 4,
	-- Clearance between the table header and the first row.
	tableGap = 4,
	-- Clearance between the right edge of the rows and the scrollbar beside them.
	listGap = 12,
	-- How far the column's card rises above the first entry in it.
	cardLip = 5,
	-- The panel title: its baseline below the top edge, and its size.
	titleY = 17,
	titleFs = 20,
	-- How far the column starts below the table beside it, to leave the title room.
	sidebarDrop = 8,
	sidebarW = 190,
	-- The slim scrollbar beside the graphs' entries when they do not all fit.
	sideBarW = 6,
	-- Between the column and the Graphs page's stat list, two cards side by side.
	pageGap = 8,
	barW = 14,
	-- Rows the wheel moves per notch.
	wheelRows = 3,
	-- The name column: never narrower than this, and otherwise this share of the table.
	nameMinW = 150,
	nameShare = 0.2,
	-- A number's column at its widest, twice what a view of twelve gives each: a view of a
	-- few keeps its numbers near the names, and the table ends with its last column.
	colMaxW = 150,
	-- The sort marker beside the caption of the sorted column.
	triW = 5,
	triH = 4,
	toggleFs = 13,
	captionBleed = 3,
	switchGap = 16,
	-- Corner radii, taken from FlowUI's so the panel rounds like the rest of the UI.
	csSmall = 2,
	csPanel = 4,
	-- Filled in by the layout. `barTop` and `barH` are the strip along the top beside the
	-- sidebar: the Graphs page's legend bar, or the table's with its Columns... button.
	nameIndent = 0,
	bandTop = 0,
	barTop = 0,
	barH = 0,
	groupTop = 0,
	groupBottom = 0,
	statTop = 0,
	statBottom = 0,
}
local look = {
	-- The column sits on its own darker card, so it reads apart from the table.
	sidebarFill = { 0, 0, 0, 0.24 },
	sidebarFillTop = { 0, 0, 0, 0.16 },
	-- A card laid over the charts, which has to read over whatever is under it: opaque, or
	-- the lines and captions behind it ghost through.
	cardFill = { 0.05, 0.05, 0.05, 1 },
	cardFillTop = { 0.1, 0.1, 0.1, 1 },
	selectedFill = { 1, 1, 1, 0.13 },
	white = { 1, 1, 1 },
	-- Rows, entries and captions hover with the same FlowUI highlight the settings list
	-- uses, at the strength it gives a plain row.
	rowHoverOpacity = 0.14,
	-- A chart in the overview under the cursor: fainter than a row, over a larger area.
	chartHoverOpacity = 0.09,
	-- A block of the Graphs page's legend bar under the cursor: small, so lit more than a
	-- row, and over a lit block too.
	barHoverOpacity = 0.24,
	-- A graph dragged in a category of the player's own: its place shaded, and the line
	-- where it would land in the hue of the captions.
	dragShade = { 0, 0, 0, 0.45 },
	dropLine = { 1, 0.78, 0.51, 0.9 },
	-- Underline under a group caption and an ally team's band: a thin bar fading up out
	-- of the bottom edge, in the hue of the caption above it.
	headerLine = { 1, 0.78, 0.51, 0.4 },
	headerLineFade = { 1, 0.78, 0.51, 0 },
	sheenTop = { 1, 1, 1, 0.05 },
	-- The rule closing the table header off from the rows, and the one in the column.
	rule = { 1, 1, 1, 0.08 },
	-- The bar behind a number, scaled to the column's largest.
	barFill = { 1, 1, 1, 0.07 },
	-- A band's trend line, where the band stands for several players and so for no colour
	-- of its own.
	trendBand = { 1, 0.86, 0.66, 0.4 },
	-- The mark under the number of a column a row leads.
	leadMark = { 1, 0.78, 0.51, 0.55 },
	-- Laid over a switch whose row is dimmed, so its state reads but its colour does not
	-- call for a press.
	mutedFill = { 0.09, 0.09, 0.09, 0.62 },
	-- Every second team row under a band takes this, so the eye keeps its line across a
	-- dozen columns. Faint: it is a guide, not a highlight.
	stripeFill = { 1, 1, 1, 0.022 },
	-- The sort marker.
	sortMark = { 0.92, 0.73, 0.27, 0.9 },
	-- The font is shared with every other widget, and whichever of them set its outline
	-- last is what a bake would freeze in; pinned after every Begin, the way the keybind
	-- editor and the widget selector pin theirs.
	outline = { 0, 0, 0, 0.4 },
	-- The sorted column, tinted down its length in the hue of its caption, so the eye
	-- follows the values the table is ordered by.
	sortedFill = { 1, 0.78, 0.51, 0.04 },
	-- The line framing the sorted column, caption to last row, in the same hue.
	sortedLine = { 1, 0.78, 0.51, 0.28 },
	-- The sorted column's numbers, a shade warmer than the rest.
	sortedText = "\255\240\226\205",
	-- A number that is nothing, or not known: quieter, so what there is stands out.
	zeroText = "\255\150\150\150",
}
local colorTitle = model.colors.title
local colorHeader = model.colors.header
local colorKey = "\255\235\185\070"
local colorValue = "\255\215\212\208"
-- An ally team's totals in its band: lighter than a player's numbers, since they sit on
-- the band's own sheen, and not the warm of the caption beside them.
local colorTotal = "\255\225\222\218"
local colorSelected = "\255\210\210\205"
local colorDim = model.colors.dim
-- An entry that cannot be opened: dimmer than the dim used for ordinary secondary text,
-- since it has to read as unavailable rather than merely quiet.
local colorFaded = "\255\115\115\115"
local colorBad = model.colors.bad

---@type boolean?, boolean?
local show, showOnceMore
---@type integer?, integer?, integer?, string?
local panelList, windowList, backgroundGuishader, panelSig
---@type number, number, number, number, number
local listTop, listBottom, listX1, listRight, barX1 = 0, 0, 0, 0, 0

-- The graphs' entries scroll by whole entries when their card cannot hold them all: `first` is
-- the first of them (nil without the Graphs caption), `scroll` how many are out of sight above,
-- `max` how many can be, `bar` whether they give way to a scrollbar.
---@type table<string, any>
local sidebar = { first = nil, scroll = 0, max = 0, bar = false }
-- The columns the table shows right now, each with the x range it takes, and the group
-- captions spanning them.
---@type table[]
local columns = {}
---@type table[]
local spans = {}

-- Bumped by the layout. A cached row layout carries the value it was built against and
-- is measured again when it moves, without every row being walked at resize.
local layoutGen = 0
---@type { gen: number, rows: number, totalH: number }
local rowMetrics = { gen = -1, rows = -1, totalH = 0 }
local scroll = 0
---@type boolean
local dragging = false
-- Where the thumb was taken hold of, as the distance from the cursor to its top edge.
---@type number
local dragGrab = 0
-- What the cursor is over, in the terms the baked panel is painted with. Refilled in
-- place each frame rather than allocated. `cols` is the table's Columns... button.
---@type table<string, integer>
local hover = { sb = 0, row = 0, col = 0, hcol = 0, tog = 0, bar = 0, cols = 0 }

-- Text is queued while the panel is baked and printed in one Begin/End at the end.
local pending = {}
local pendingCount = 0

-- The Graphs page (luaui/Include/teamstats_graphs.lua) and the tables with the columns the
-- player keeps in them (luaui/Include/teamstats_tables.lua), made at the end of the file once
-- everything they read from is declared.
---@type table<string, any>
local graphs
---@type table<string, any>
local tables

local function rowHeightOf(row)
	if row.type == "band" then
		return metrics.bandRowHeight
	end
	return metrics.rowHeight
end

-- A row's position is a sum of what is above it rather than its index times one height:
-- a band is not the height of an ordinary row. The running total is stamped onto the
-- rows, and redone when the list or the layout changes.
local function ensureRowMetrics()
	if rowMetrics.gen == layoutGen and rowMetrics.rows == model.rowsGen then
		return
	end

	local off = 0
	for i = 1, #model.rows do
		model.rows[i].off = off
		off = off + rowHeightOf(model.rows[i])
	end
	rowMetrics.totalH = off
	rowMetrics.gen, rowMetrics.rows = layoutGen, model.rowsGen
end

-- Pixels of content above the first painted row.
local function scrollOffset()
	ensureRowMetrics()
	local first = model.rows[scroll + 1]

	return first and first.off or 0
end

-- Furthest offset that still fills the band. Walked from the end, so it does not depend
-- on where the list is scrolled to now.
local function maxScroll()
	ensureRowMetrics()
	local band = listTop - listBottom
	local used = 0
	local i = #model.rows
	while i > 0 do
		local h = rowHeightOf(model.rows[i])
		if used + h > band then
			break
		end
		used = used + h
		i = i - 1
	end

	return i
end

local function clampScroll()
	local top = maxScroll()
	if scroll > top then
		scroll = top
	end
	if scroll < 0 then
		scroll = 0
	end
end

local function setScroll(n)
	scroll = n
	clampScroll()
end

-- The painted row under y, as its offset from the first painted one. Every hover test and
-- the panel signature go through this, so neither can disagree with what was drawn. nil
-- when y is outside the band or past the last whole row the band can hold.
local function rowAt(y)
	ensureRowMetrics()
	if y > listTop or y <= listBottom then
		return nil
	end

	local base = scrollOffset()
	for i = scroll + 1, #model.rows do
		local top = listTop - (model.rows[i].off - base)
		local bottom = top - rowHeightOf(model.rows[i])
		if bottom < listBottom then
			break
		end
		-- Half-open on the shared edge: rows stack, so one row's top is the next one's
		-- bottom and a closed test would put the cursor in both.
		if y <= top and y > bottom then
			return i - scroll
		end
	end

	return nil
end

-- The column under x, or nil outside the table. Half-open on the shared edge.
local function columnAt(x)
	for i = 1, #columns do
		local c = columns[i]
		if x >= c.x1 and x < c.x2 then
			return i
		end
	end

	return nil
end

----------------------------------------------------------------
-- The scrollbar
----------------------------------------------------------------

-- The bar serves whichever of the two is open: the table's rows, or the grid of charts on
-- the Graphs page, which runs up to the top of the charts. Its band and its thumb come out
-- of the same call, so the page's top is worked out once.
local function scrollerThumb()
	local total, offset = rowMetrics.totalH, scrollOffset()
	local top = listTop
	if graphs and graphs.open then
		total, offset = graphs.scrollExtent()
		top = graphs.rects and graphs.rects.chart[4] or listTop
	end
	local a, b, c, d = UiScrollerAt(barX1, listBottom, area.x2 - metrics.edgeInset, top, total, offset)
	return a, b, c, d, top, total, offset
end

-- Scrolls so the thumb's top sits where the cursor has dragged it. The offset taken at the
-- grab is what keeps this relative: the thumb moves with the cursor rather than centring
-- itself on it, so taking hold of it does not shift the view before the drag begins.
local function scrollFromY(y)
	local _, _, trackTop, travel = scrollerThumb()
	if not travel or travel <= 0 then
		return
	end

	local f = (trackTop - (y - dragGrab)) / travel
	if f < 0 then
		f = 0
	elseif f > 1 then
		f = 1
	end
	if graphs and graphs.open then
		-- The grid scrolls by whole rows, so the bar asks for the row it landed on.
		local total = graphs.scrollExtent()
		local c = graphs.rects and graphs.rects.chart
		-- The page's own generation is part of the bake signature, so the picture follows.
		graphs.setScrollPixels(f * mathMax(0, total - (c and c[4] - c[2] or 0)))
		return
	end
	setScroll(mathFloor(f * maxScroll() + 0.5))
end

-- Takes hold of the bar. On the thumb that is a grab, and the view stays where it is; on
-- the track either side of it the thumb jumps to the cursor first and is then dragged from
-- its middle, which is what a press on empty track is asking for.
local function grabScroller(y)
	local top, height = scrollerThumb()
	if not top then
		return
	end

	dragging = true
	if y <= top and y >= top - height then
		dragGrab = y - top
	else
		dragGrab = -mathFloor(height * 0.5)
		scrollFromY(y)
	end
end

----------------------------------------------------------------
-- Layout
----------------------------------------------------------------

-- The column starts below where the table does, so the title above it is not crowded by
-- the first entry. Everything in the column measures from here.
local function sidebarTop()
	return metrics.bandTop - metrics.sidebarDrop
end

-- A section after the first starts a card of its own: the card before it ends a lip below its
-- last entry, then the air between the two, then this one's lip.
-- A graphs' entry scrolled out of sight takes no room: its rect is empty, at the top of theirs.
local function entryRect(i)
	---@type number, number
	local top, h = sidebarTop(), 0
	local first = sidebar.first or mathHuge
	for j = 1, i do
		local e = model.entries[j]
		---@cast e -?
		top = top - h
		if e.section and j > 1 then
			top = top - metrics.cardLip * 2 - metrics.islandGap
		end
		if j >= first and j < first + sidebar.scroll then
			h = 0
		else
			h = e.divider and metrics.dividerH or (e.section and metrics.sectionH or metrics.catRowHeight)
		end
	end
	-- Beside the bar the entries give way to it, as the widget selector's categories do.
	local right = area.x1 + metrics.sidebarW
	if sidebar.bar and i >= first then
		right = right - metrics.catInset - metrics.sideBarW - metrics.catInset
	end

	return area.x1, top - h, right, top
end

-- The graphs' entries: where they start, how far they can scroll, and the scroll kept inside
-- that. Walked from the end, as the table's rows are, so it does not depend on the scroll now.
function sidebar.fit()
	sidebar.first = nil
	for i = 1, #model.entries do
		if model.entries[i].section and model.entries[i].key == "newCategory" then
			sidebar.first = i + 1
		end
	end
	local first = sidebar.first
	sidebar.max = 0
	if first and model.entries[first] then
		local _, captionBottom = entryRect(first - 1)
		local room = captionBottom - metrics.settingsTop
		local used, i = 0, #model.entries
		while i >= first do
			local e = model.entries[i]
			---@cast e -?
			local h = e.divider and metrics.dividerH or metrics.catRowHeight
			if used + h > room then
				break
			end
			used = used + h
			i = i - 1
		end
		sidebar.max = i - first + 1
	end
	sidebar.scroll = mathMax(0, mathMin(sidebar.scroll, sidebar.max))
	sidebar.bar = sidebar.max > 0
end

-- Scrolls the graphs' entries just far enough that entry i shows whole.
function sidebar.reveal(i)
	local first = sidebar.first
	if not first or i < first then
		return
	end
	if i < first + sidebar.scroll then
		sidebar.scroll = i - first
	end
	local _, bottom = entryRect(i)
	while sidebar.scroll < sidebar.max and bottom < metrics.settingsTop do
		sidebar.scroll = sidebar.scroll + 1
		_, bottom = entryRect(i)
	end
end

-- The entry under x,y, or nil. A rule or a section's caption is not one.
local function sidebarIndexAt(x, y)
	if x < area.x1 or x > area.x1 + metrics.sidebarW then
		return nil
	end
	for i = 1, #model.entries do
		local _, y1, _, y2 = entryRect(i)
		if y1 < metrics.settingsTop then
			return nil
		end
		if y <= y2 and y > y1 then
			if model.entries[i].divider or model.entries[i].section then
				return model.entries[i].add and tables.addAt(x, y, entryRect(i)) and i or nil
			end
			return i
		end
	end

	return nil
end

local function switchAt(x, y)
	for i = 1, #switches do
		local hit = switches[i].hit
		if hit and not switches[i].heading and math_isInRect(x, y, hit[1], hit[2], hit[3], hit[4]) then
			return i
		end
	end

	return nil
end

-- The stat caption under x,y, which sorts the table when clicked.
local function headerColumnAt(x, y)
	if y > metrics.statTop or y <= metrics.statBottom then
		return nil
	end

	return columnAt(x)
end

-- The columns of the table last picked, each given its x range: the name column takes its
-- share and the numeric ones split the rest evenly, with the leftover pixels going to the
-- name, up to a width a number's column never passes. The table's right edge is where its
-- last column ends.
local function layoutColumns()
	columns = { COLUMNS.name }
	for _, key in ipairs(tables.columnsOf(tables.current)) do
		local c = COLUMNS[key]
		if c and handover.shows(c) then
			columns[#columns + 1] = c
		end
	end

	-- The room is the channel up to the scrollbar's; the table itself ends with its last
	-- column, which a view of few columns leaves short of it.
	local tableW = barX1 - metrics.listGap - listX1
	local n = #columns - 1
	---@type number
	local nameW = mathMax(metrics.nameMinW, mathFloor(tableW * metrics.nameShare))
	---@type number
	local colW = metrics.colMaxW
	if n > 0 and mathFloor((tableW - nameW) / n) < colW then
		colW = mathFloor((tableW - nameW) / n)
		nameW = tableW - colW * n
	end
	listRight = listX1 + nameW + colW * n

	local x = listX1
	for i = 1, #columns do
		local c = columns[i]
		c.x1 = x
		c.x2 = x + (i == 1 and nameW or colW)
		x = c.x2
		-- The caption takes the whole cell: the sort marker sits in the cell's padding, so
		-- it never takes room from the caption when the column is the sorted one.
		local room = c.x2 - c.x1 - metrics.cellPad * 2
		if i == 1 then
			room = c.x2 - c.x1 - metrics.nameIndent - metrics.cellPad - metrics.triW - metrics.rowPad
		end
		c.fitStat = text.fit(font, L.stat[c.key], room, metrics.statFs)
		c.statW = mathFloor(font:GetTextWidth(c.fitStat) * metrics.statFs)
	end

	-- Neighbouring columns with the same group share one caption over them.
	spans = {}
	---@type table?
	local span
	for i = 2, #columns do
		local c = columns[i]
		if span and span.group == c.group then
			span.x2 = c.x2
		else
			span = { group = c.group, x1 = c.x1, x2 = c.x2 }
			spans[#spans + 1] = span
		end
	end
	for i = 1, #spans do
		local s = spans[i]
		local label = L.caption[s.group] or s.group
		s.label = text.fit(font, label, s.x2 - s.x1 - metrics.cellPad * 2, metrics.groupFs)
	end

	layoutGen = layoutGen + 1
	clampScroll()
end

-- Rebuilds every rect against the panel size. Whole pixels throughout, so glyph and
-- rectangle edges do not land between pixels.
local function setLayout()
	local s = widgetScale
	local pad = mathFloor(8 * s)
	area.x1 = screenX + pad
	area.y1 = screenY - screenHeight + pad
	area.x2 = screenX + screenWidth - pad
	area.y2 = screenY - pad

	metrics.rowHeight = mathFloor(24 * s)
	metrics.rowFs = mathFloor(metrics.rowHeight * 0.55)
	metrics.bandRowHeight = mathFloor(metrics.rowHeight * 1.35)
	metrics.bandFs = mathFloor(metrics.rowFs * 0.95 * 1.13)
	metrics.groupRowHeight = mathFloor(22 * s)
	metrics.groupFs = metrics.rowFs
	metrics.statRowHeight = metrics.rowHeight
	metrics.statFs = mathFloor(metrics.rowFs * 0.92)
	metrics.catRowHeight = mathFloor(29 * s)
	metrics.catFs = mathFloor(metrics.catRowHeight * 0.55 * 0.85)
	metrics.dividerH = mathFloor(14 * s)
	metrics.sectionH = mathFloor(26 * s)
	metrics.islandGap = mathFloor(7 * s)
	metrics.rowPad = mathFloor(6 * s)
	metrics.cellPad = mathFloor(7 * s)
	metrics.sidePad = mathFloor(12 * s)
	metrics.catInset = mathFloor(4 * s)
	metrics.accentW = mathMax(2, mathFloor(3 * s))
	metrics.accentPad = mathMax(1, mathFloor(3 * s))
	metrics.barInset = mathMax(2, mathFloor(4 * s))
	metrics.trendW = mathMax(1, mathFloor(1.5 * s))
	metrics.leadDrop = mathMax(2, mathFloor(3 * s))
	metrics.leadH = mathMax(1, mathFloor(2 * s))
	metrics.underlineH = mathMax(1, mathFloor(2 * s))
	metrics.edgeInset = mathFloor(4 * s)
	metrics.headerH = mathFloor(34 * s)
	metrics.headerGap = mathFloor(4 * s)
	metrics.tableGap = mathFloor(4 * s)
	metrics.listGap = mathFloor(12 * s)
	metrics.cardLip = mathFloor(5 * s)
	metrics.titleY = mathFloor(17 * s)
	metrics.titleFs = mathFloor(metrics.rowHeight * 0.85)
	metrics.sidebarDrop = mathFloor(8 * s)
	metrics.sidebarW = mathFloor(190 * s)
	metrics.sideBarW = mathMax(3, mathFloor(6 * s))
	metrics.pageGap = mathFloor(8 * s)
	metrics.barW = mathFloor(14 * s)
	metrics.nameMinW = mathFloor(150 * s)
	metrics.colMaxW = mathFloor(150 * s)
	-- The narrowest a number's column gets: a table holds no more columns than that leaves room
	-- for.
	metrics.colMinW = mathFloor(44 * s)
	-- Narrower than the cell padding it sits in.
	metrics.triW = mathMax(4, mathFloor(5 * s))
	metrics.triH = mathMax(3, mathFloor(4 * s))
	metrics.switchGap = mathFloor(16 * s)
	metrics.csPanel = mathFloor(elementCorner)
	metrics.csSmall = mathFloor(elementCorner * 0.66)
	metrics.nameIndent = metrics.accentW + metrics.rowPad * 2

	listX1 = area.x1 + metrics.sidebarW + metrics.listGap
	-- The sidebar's card starts below the panel's title; the table and the page beside it
	-- have no title of their own to clear, so they start at the panel's own edge, with the
	-- strip along the top: the page's legend bar, or the table's Columns... button.
	metrics.bandTop = area.y2 - metrics.headerH - metrics.headerGap
	metrics.barTop = area.y2 - metrics.headerGap * 2
	metrics.barH = metrics.rowHeight + mathFloor(8 * s)
	-- The table header under the strip, as the page's charts are: group captions, then the
	-- stat captions, then a gap to the rows.
	metrics.groupTop = metrics.barTop - metrics.barH - mathFloor(4 * s)
	metrics.groupBottom = metrics.groupTop - metrics.groupRowHeight
	metrics.statTop = metrics.groupBottom
	metrics.statBottom = metrics.statTop - metrics.statRowHeight
	listTop = metrics.statBottom - metrics.tableGap
	listBottom = area.y1 + metrics.edgeInset
	-- The scrollbar owns a column of its own: its right edge lines up with the switches
	-- above it, and the rows stop a clear gap short of it rather than running up against
	-- it, so the bar sits in a channel rather than hugging them.
	barX1 = area.x2 - metrics.edgeInset - metrics.barW
	listRight = barX1 - metrics.listGap
	metrics.toggleFs = mathFloor(metrics.rowFs * 1.05)
	local togW = mathFloor(38 * s)
	local onGraphs = graphs and graphs.open
	local customGroup = groupByKey[model.selectedGroup] and groupByKey[model.selectedGroup].custom
	-- A custom category's page of charts: every graph on it keeps its own settings.
	local customCharts = onGraphs and customGroup and not graphs.openGraph()

	-- Group by team at the right end of the strip along the top in both views, captioned like
	-- Remove unselected beside it: next to the teams the page picks, over the table's rows.
	-- Without a side of more than one player, or another side to be seen, there is nothing
	-- to group.
	---@type number
	local barX2 = area.x2 - metrics.edgeInset
	local groupable = model.canGroup()
	for i = 1, #switches do
		local sw = switches[i]
		if sw.top and groupable then
			local togH = mathFloor(metrics.rowHeight * 0.52)
			local cy = metrics.barTop - mathFloor(metrics.barH * 0.5)
			local labelW = mathFloor(font:GetTextWidth(sw.label or "") * metrics.catFs)
			sw.draw = { barX2 - togW, cy - mathFloor(togH * 0.5), barX2, cy - mathFloor(togH * 0.5) + togH }
			sw.hit = { sw.draw[1] - metrics.rowPad - labelW, metrics.barTop - metrics.barH, barX2, metrics.barTop }
			-- Never greyed: on a custom category's page of charts it sets every graph of it.
			sw.disabled = nil
			barX2 = sw.hit[1] - metrics.sidePad * 2
		elseif sw.top then
			sw.draw, sw.hit, sw.disabled = nil, nil, nil
		end
	end
	-- The Graphs page takes the table's room, header rows and scrollbar included. Its
	-- stat list is a card like the column's, so it sits closer and spans the same height.
	if graphs then
		graphs.setFont(font, metrics.rowFs, metrics.nameFont)
		graphs.setLayout(
			area.x1 + metrics.sidebarW + metrics.pageGap,
			listBottom,
			listRight,
			metrics.barTop,
			s,
			area.y1,
			sidebarTop() + metrics.cardLip,
			-- The legend bar runs over the scrollbar's column, which only starts below it,
			-- up to the grouping switch.
			barX2
		)
	end
	tables.layout(listX1, metrics.barTop - metrics.barH, metrics.barTop, s)

	-- The settings: a row each under the sidebar's groups, the caption on the left and the
	-- toggle on the right, laid out from the bottom of the column upwards so the block
	-- stays put however many groups there are. A switch the open view cannot use keeps its
	-- row and is dimmed, so nothing ever moves when one is pressed.
	local togH = mathFloor(metrics.catRowHeight * 0.52)
	---@diagnostic disable-next-line: undefined-field
	local canCompare = model.allies.me ~= nil
	local y = listBottom + metrics.edgeInset
	-- Bottom-up, leaving out the one laid out along the top.
	for i = #switches, 1, -1 do
		local sw = switches[i]
		-- Which view a switch belongs to.
		local mine = not ((sw.table and onGraphs) or (sw.page and not onGraphs))
		-- The caption over a custom graph's own rows, only while one is open.
		if sw.heading and not (onGraphs and graphs.openGraph()) then
			mine = false
		end
		if mine and not sw.top then
			local cy = y + mathFloor(metrics.catRowHeight * 0.5)
			sw.hit = {
				area.x1 + metrics.catInset,
				y,
				area.x1 + metrics.sidebarW - metrics.catInset,
				y + metrics.catRowHeight,
			}
			sw.draw = {
				sw.hit[3] - metrics.sidePad - togW,
				cy - mathFloor(togH * 0.5),
				sw.hit[3] - metrics.sidePad,
				cy - mathFloor(togH * 0.5) + togH,
			}
			-- Nothing to say: the switch stays where it is and greys out.
			sw.disabled = (
				sw.key == "milestones"
				and graphs
				and (not graphs.overTime() or graphs.milestonesOwn() or not graphs.marksApply())
			)
				or (sw.key == "milestoneKinds" and graphs and not graphs.kindsApply())
				or (sw.key == "vsMe" and not canCompare)
				or (sw.key == "shareOfTotal" and onGraphs and not graphs.shareApplies())
				or (sw.perGraph and customCharts)
				or nil
			y = y + metrics.catRowHeight
		elseif not sw.top then
			sw.draw, sw.hit, sw.disabled = nil, nil, nil
		end
	end
	-- The block's own card, with the lip above its top row it has below its bottom one; the
	-- groups stop inside the graphs' card, which ends the air above it.
	metrics.settingsCardTop = y + metrics.edgeInset * 2
	metrics.settingsTop = metrics.settingsCardTop + metrics.islandGap + metrics.cardLip
	sidebar.fit()
	if graphs then
		for i = 1, #switches do
			if switches[i].key == "milestoneKinds" then
				graphs.setKindsAnchor(switches[i].hit)
			end
		end
	end

	layoutColumns()
end

----------------------------------------------------------------
-- Drawing
----------------------------------------------------------------

-- `face` says which of the three the string is set in: the interface's own, the numbers'
-- or the names'.
local function queueText(str, x, y, size, opts, face)
	local at = pendingCount * 6
	pending[at + 1] = str
	pending[at + 2] = x
	pending[at + 3] = y
	pending[at + 4] = size
	pending[at + 5] = opts
	pending[at + 6] = face or false
	pendingCount = pendingCount + 1
end

-- One batch a face: it draws what was queued for it, in the order it was queued in. The
-- three never overlap on the screen, so the order between them does not matter.
local function flushBatch(face, key)
	local began = false
	for i = 0, pendingCount - 1 do
		local at = i * 6
		if pending[at + 6] == key then
			if not began then
				began = true
				face:Begin()
				face:SetOutlineColor(look.outline)
			end
			face:Print(pending[at + 1], pending[at + 2], pending[at + 3], pending[at + 4], pending[at + 5])
		end
	end
	if began then
		face:End()
	end
end

local function flushText()
	if pendingCount == 0 then
		return
	end

	flushBatch(font, false)
	flushBatch(metrics.numFont or font, "number")
	flushBatch(metrics.nameFont or font, "name")

	pendingCount = 0
end

-- The sort marker: a small triangle pointing the way the column is sorted.
---@type { x: number, y: number, w: number, h: number, up: boolean, right: boolean }
local tri = { x = 0, y = 0, w = 0, h = 0, up = false, right = false }
local function triangleVertices()
	local x, y, w, h = tri.x, tri.y, tri.w, tri.h
	if tri.right then
		glVertex(x, y)
		glVertex(x, y + h)
		glVertex(x + w, y + h * 0.5)
	elseif tri.up then
		glVertex(x, y)
		glVertex(x + w, y)
		glVertex(x + w * 0.5, y + h)
	else
		glVertex(x, y + h)
		glVertex(x + w, y + h)
		glVertex(x + w * 0.5, y)
	end
end

local function drawTriMark(x, cy, up, right)
	tri.x, tri.y, tri.w, tri.h, tri.up, tri.right =
		x, cy - mathFloor(metrics.triH * 0.5), metrics.triW, metrics.triH, up, right
	glColor(look.sortMark)
	glBeginEnd(GL_TRIANGLES, triangleVertices)
	glColor(1, 1, 1, 1)
end

-- The mark under the number of a column its row leads: a short bar the width of the
-- number, in the warm hue the panel uses for what stands out.
local function drawLeadMark(column, cell, bottom)
	local w = mathFloor((metrics.numFont or font):GetTextWidth(cell) * metrics.rowFs)
	if w < 4 then
		return
	end
	RectRound(
		column.x2 - metrics.cellPad - w,
		bottom + metrics.leadDrop,
		column.x2 - metrics.cellPad,
		bottom + metrics.leadDrop + metrics.leadH,
		0,
		0,
		0,
		0,
		0,
		look.leadMark
	)
end

-- What a row shows, fitted to the columns. Cached on the row and redone when the
-- columns move: the rows themselves are rebuilt whenever the values behind them change.
local function fitRow(row)
	if row.fitGen == layoutGen then
		return
	end
	row.fitGen = layoutGen
	model.fillRow(row, columns)

	local nameColumn = columns[1]
	---@cast nameColumn -?
	if row.type == "team" then
		local room = nameColumn.x2 - nameColumn.x1 - metrics.nameIndent - metrics.cellPad
		row.fitName = text.fit(metrics.nameFont or font, row.team.label, room, metrics.rowFs)
	else
		local caption, members = model.bandCaption(row)
		local room = nameColumn.x2 - nameColumn.x1 - metrics.rowPad * 2
		local face = row.team and (metrics.nameFont or font) or font
		row.caption = text.fit(face, caption, room, metrics.bandFs)
		row.captionW = mathFloor(face:GetTextWidth(row.caption) * metrics.bandFs)
		-- The count goes after the caption when it fits beside it, and is dropped when
		-- not: cut short it would say nothing.
		local left = room - row.captionW - metrics.rowPad * 2 - metrics.triW * 2
		if members and font:GetTextWidth(members) * metrics.rowFs <= left then
			row.members = members
			row.membersW = mathFloor(font:GetTextWidth(members) * metrics.rowFs) + metrics.rowPad
		else
			row.members = nil
			row.membersW = 0
		end
	end
end

local function drawBand(row, top, bottom, hovered)
	RectRound(
		listX1,
		bottom,
		listRight,
		top - metrics.csSmall,
		metrics.csSmall,
		1,
		1,
		0,
		0,
		look.sheenTop,
		look.sheenTop
	)
	local nameColumn = columns[1]
	---@cast nameColumn -?
	if hovered and not row.team then
		-- The caption is the fold button.
		Highlight(
			listX1,
			bottom,
			nameColumn.x2,
			top - metrics.csSmall,
			metrics.csSmall,
			look.rowHoverOpacity,
			look.white
		)
	end
	if row.team then
		RectRound(
			listX1,
			bottom + metrics.accentPad,
			listX1 + metrics.accentW,
			top - metrics.csSmall - metrics.accentPad,
			0,
			0,
			0,
			0,
			0,
			row.team.accent
		)
	end
	RectRound(
		listX1,
		bottom,
		listRight,
		bottom + metrics.underlineH,
		0,
		0,
		0,
		0,
		0,
		look.headerLine,
		look.headerLineFade
	)
	local by = text.baseline(font, bottom, top, metrics.bandFs)
	local captionX = listX1 + (row.team and metrics.nameIndent or metrics.rowPad)
	queueText(colorHeader .. row.caption, captionX, by, metrics.bandFs, "o", row.team and "name" or nil)
	if row.members then
		local team = row.team
		local color = colorDim
		if team then
			color = (team.dead or team.gone) and colorDim or team.nameColor
		end
		queueText(
			color .. row.members,
			captionX + metrics.rowPad * 2 + row.captionW,
			text.baseline(font, bottom, top, metrics.rowFs),
			metrics.rowFs,
			"o"
		)
	end
	if not row.team then
		-- Down while the band's players are shown, right once they are folded away.
		drawTriMark(
			captionX + metrics.rowPad * 2 + row.captionW + (row.membersW or 0),
			mathFloor((bottom + top - metrics.csSmall) * 0.5),
			false,
			row.folded == true
		)
	end
	local vy = text.baseline(font, bottom, top, metrics.rowFs)
	for i = 2, #columns do
		local v = row.vals[i]
		local valueColor = row.tones[i] or ((v == 0 or not model.isFinite(v)) and look.zeroText or colorTotal)
		queueText(valueColor .. row.cells[i], columns[i].x2 - metrics.cellPad, vy, metrics.rowFs, "or", "number")
		if row.ally.leads[columns[i].key] then
			drawLeadMark(columns[i], row.cells[i], bottom)
		end
	end
end

local function drawTeamRow(row, top, bottom, hovered)
	local team = row.team
	if row.stripe then
		RectRound(listX1, bottom, listRight, top, metrics.csSmall, 1, 1, 1, 1, look.stripeFill)
	end
	if team.isLocal then
		RectRound(listX1, bottom, listRight, top, metrics.csSmall, 1, 1, 1, 1, look.selectedFill)
	end
	if hovered then
		Highlight(listX1, bottom, listRight, top, metrics.csSmall, look.rowHoverOpacity, look.white)
	end
	-- The team's colour down the left edge, the way an adjusted option is marked in the
	-- game info panel, so a row is found by colour before its name is read.
	RectRound(
		listX1,
		bottom + metrics.accentPad,
		listX1 + metrics.accentW,
		top - metrics.accentPad,
		0,
		0,
		0,
		0,
		0,
		team.accent
	)

	if filters.bars then
		for i = 2, #columns do
			local c = columns[i]
			local top_ = model.colMax[c.key]
			local v = row.vals[i]
			if top_ and top_ > 0 and v and model.isFinite(v) and v > 0 then
				local room = c.x2 - c.x1 - metrics.cellPad * 2
				local w = mathFloor(room * mathMin(1, v / top_))
				if w >= 2 then
					RectRound(
						c.x1 + metrics.cellPad,
						bottom + metrics.barInset,
						c.x1 + metrics.cellPad + w,
						top - metrics.barInset,
						mathMin(metrics.csSmall, mathFloor(w * 0.5)),
						1,
						1,
						1,
						1,
						look.barFill
					)
				end
			end
		end
	end

	local by = text.baseline(font, bottom, top, metrics.rowFs)
	local quiet = team.dead or team.gone
	queueText(
		(quiet and colorDim or team.nameColor) .. row.fitName,
		listX1 + metrics.nameIndent,
		by,
		metrics.rowFs,
		"o",
		"name"
	)
	for i = 2, #columns do
		local v = row.vals[i]
		local valueColor
		if quiet then
			valueColor = colorDim
		elseif row.tones[i] then
			valueColor = row.tones[i]
		elseif v == 0 or not model.isFinite(v) then
			valueColor = look.zeroText
		elseif columns[i].key == model.sortKey then
			valueColor = look.sortedText
		else
			valueColor = colorValue
		end
		queueText(valueColor .. row.cells[i], columns[i].x2 - metrics.cellPad, by, metrics.rowFs, "or", "number")
		if team.leads[columns[i].key] then
			drawLeadMark(columns[i], row.cells[i], bottom)
		end
	end
end

-- Whole rows only: the band can end mid-row, and a row painted below it would be clipped
-- by nothing.
local function drawRows()
	local base = scrollOffset()

	model.columnFacts(columns)

	-- The sorted column's tint, from the first row to the last one drawn, under them all.
	---@type table?
	local sortedColumn
	for i = 2, #columns do
		if columns[i].key == model.sortKey then
			sortedColumn = columns[i]
		end
	end
	if sortedColumn then
		-- From the top of the first row drawn - a band's plate starts a corner lower - to
		-- the bottom of the last.
		local first = model.rows[scroll + 1]
		local top = listTop - ((first and first.type == "band") and metrics.csSmall or 0)
		local bottom = listTop
		for i = scroll + 1, #model.rows do
			local rowBottom = listTop - (model.rows[i].off - base) - rowHeightOf(model.rows[i])
			if rowBottom < listBottom then
				break
			end
			bottom = rowBottom
		end
		if bottom < top then
			RectRound(sortedColumn.x1, bottom, sortedColumn.x2, top, metrics.csSmall, 0, 0, 1, 1, look.sortedFill)
			-- And a frame around it, from the first row to the last one drawn, so the column
			-- the table is ordered by is found at a glance. The caption stays outside: its
			-- sort marker says enough, and a frame up there would run into the group line.
			-- Plain whole-pixel rects, so all four sides are the same thickness.
			local x1, x2 = sortedColumn.x1, sortedColumn.x2
			glColor(look.sortedLine)
			gl.Rect(x1, bottom, x1 + 1, top)
			gl.Rect(x2 - 1, bottom, x2, top)
			gl.Rect(x1, top - 1, x2, top)
			gl.Rect(x1, bottom, x2, bottom + 1)
			glColor(1, 1, 1, 1)
		end
	end

	for i = 1, #model.rows - scroll do
		local row = model.rows[scroll + i]
		if not row then
			break
		end
		local top = listTop - (row.off - base)
		local bottom = top - rowHeightOf(row)
		if bottom < listBottom then
			break
		end
		fitRow(row)
		if row.type == "band" then
			drawBand(row, top, bottom, hover.row == i)
		else
			drawTeamRow(row, top, bottom, hover.row == i)
		end
	end
end

-- The table header: a caption over each group of columns with a line under it, and the
-- stat captions under those, the sorted one marked.
local function drawTableHeader()
	local gy = text.baseline(font, metrics.groupBottom, metrics.groupTop, metrics.groupFs)
	for i = 1, #spans do
		local s = spans[i]
		if s.label ~= "" then
			RectRound(
				s.x1 + metrics.rowPad,
				metrics.groupBottom,
				s.x2 - metrics.rowPad,
				metrics.groupBottom + metrics.underlineH,
				0,
				0,
				0,
				0,
				0,
				look.headerLine,
				look.headerLineFade
			)
			queueText(colorHeader .. s.label, mathFloor((s.x1 + s.x2) * 0.5), gy, metrics.groupFs, "oc")
		end
	end

	local sy = text.baseline(font, metrics.statBottom, metrics.statTop, metrics.statFs)
	local cy = mathFloor((metrics.statBottom + metrics.statTop) * 0.5)
	for i = 1, #columns do
		local c = columns[i]
		local hovered = hover.hcol == i
		local sorted = c.key == model.sortKey
		if hovered then
			Highlight(
				c.x1,
				metrics.statBottom,
				c.x2,
				metrics.statTop,
				metrics.csSmall,
				look.rowHoverOpacity,
				look.white
			)
		end
		local color = sorted and colorKey or (hovered and colorTitle or colorDim)
		if i == 1 then
			queueText(color .. c.fitStat, c.x1 + metrics.nameIndent, sy, metrics.statFs, "o")
			if sorted then
				drawTriMark(c.x1 + metrics.nameIndent + c.statW + metrics.rowPad, cy, model.sortAscending, false)
			end
		else
			queueText(color .. c.fitStat, c.x2 - metrics.cellPad, sy, metrics.statFs, "or")
			-- In the padding after the caption, over the right edge the numbers line up on.
			if sorted then
				drawTriMark(c.x2 - metrics.cellPad + 1, cy, model.sortAscending, false)
			end
		end
	end

	-- A rule closing the header off from the rows.
	RectRound(listX1, metrics.statBottom, listRight, metrics.statBottom + 1, 0, 0, 0, 0, 0, look.rule)
end

-- The column under the title: the tables, the categories of graphs and the settings each on a
-- card of their own with air between them, the way the widget selector keeps its sets apart
-- from its categories. The graphs' card runs down to the settings'.
local function drawSidebar()
	local function card(bottom, top)
		RectRound(
			area.x1,
			bottom,
			area.x1 + metrics.sidebarW,
			top,
			metrics.csPanel,
			1,
			1,
			1,
			1,
			look.sidebarFill,
			look.sidebarFillTop
		)
	end
	---@type number
	local cardTop = sidebarTop() + metrics.cardLip
	for i = 2, #model.entries do
		if model.entries[i].section then
			local _, bottom = entryRect(i - 1)
			local _, _, _, top = entryRect(i)
			card(bottom - metrics.cardLip, cardTop)
			cardTop = top + metrics.cardLip
		end
	end
	card(metrics.settingsCardTop + metrics.islandGap, cardTop)
	card(area.y1, metrics.settingsCardTop)
	queueText(L.titleText, area.x1 + metrics.sidePad, area.y2 - metrics.titleY, metrics.titleFs, "ov")

	for i = 1, #model.entries do
		local e = model.entries[i]
		local x1, y1, x2, y2 = entryRect(i)
		if y1 < metrics.settingsTop then
			break
		end
		if y1 == y2 then
			-- Scrolled out of sight.
		elseif e.divider then
			local y = mathFloor((y1 + y2) * 0.5)
			RectRound(x1 + metrics.sidePad, y, x2 - metrics.sidePad, y + 1, 0, 0, 0, 0, 0, look.rule)
		elseif e.section then
			-- Faded like the caption over a graph's own settings, at the head of its card.
			queueText(colorFaded .. e.label, x1 + metrics.sidePad, mathFloor((y1 + y2) * 0.5), metrics.toggleFs, "ov")
			if e.add then
				tables.drawAdd(i == hover.sb, x1, y1, x2, y2)
			end
		else
			local selected = e.key == model.selectedGroup
			if selected then
				RectRound(
					x1 + metrics.catInset,
					y1,
					x2 - metrics.catInset,
					y2,
					metrics.csSmall,
					1,
					1,
					1,
					1,
					look.selectedFill
				)
			elseif i == hover.sb and not e.disabled then
				Highlight(
					x1 + metrics.catInset,
					y1,
					x2 - metrics.catInset,
					y2,
					metrics.csSmall,
					look.rowHoverOpacity,
					look.white
				)
			end
			local color = e.disabled and colorFaded or (selected and colorSelected or colorDim)
			if not (graphs.naming and graphs.naming.key == e.key) then
				queueText(color .. e.label, x1 + metrics.sidePad, mathFloor((y1 + y2) * 0.5), metrics.catFs, "ov")
			end
		end
	end

	-- A slim bar beside the graphs' entries while they do not all fit, as the widget selector's
	-- categories have: from under their caption down to where they stop.
	if sidebar.bar then
		local first = sidebar.first
		local _, top = entryRect(first - 1)
		local total, offset = 0, 0
		for i = first, #model.entries do
			local h = model.entries[i].divider and metrics.dividerH or metrics.catRowHeight
			total = total + h
			if i < first + sidebar.scroll then
				offset = offset + h
			end
		end
		local x2 = area.x1 + metrics.sidebarW - metrics.catInset
		UiScroller(x2 - metrics.sideBarW, metrics.settingsTop, x2, top, total, offset)
	end
end

-- The switches and their captions. The plate goes behind the switch and the switch
-- lights itself: painting over it would only dull it.
-- The settings block on its card under the groups: a row per switch with its caption on
-- the left and its toggle on the right. A row the open view cannot use is dimmed and does
-- not answer the cursor. The one along the top has its caption before its toggle, as
-- Remove unselected beside it has, and no row to light.
local function drawSettings()
	for i = 1, #switches do
		local sw = switches[i]
		if sw.draw and sw.heading then
			queueText(
				colorFaded .. sw.label,
				sw.hit[1] + metrics.sidePad,
				mathFloor((sw.hit[2] + sw.hit[4]) * 0.5),
				metrics.toggleFs,
				"ov"
			)
		elseif sw.draw then
			local hovered = hover.tog == i and not sw.disabled
			if not sw.top then
				if hovered then
					Highlight(
						sw.hit[1],
						sw.hit[2],
						sw.hit[3],
						sw.hit[4],
						metrics.csSmall,
						look.rowHoverOpacity,
						look.white
					)
				end
			end
			-- The grouping switch shows the grouping of whichever of the two views is open.
			local on = filters[sw.key]
			local graph = graphs.open and sw.perGraph and graphs.openGraph()
			if graph then
				-- The open custom graph's own.
				on = (sw.key == "groupByTeam" and graph.grouped)
					or (sw.key == "shareOfTotal" and graph.share)
					or (sw.key == "milestones" and graph.milestones)
			elseif sw.key == "groupByTeam" and graphs.open then
				on = graphs.grouped
			end
			local cy = mathFloor((sw.hit[2] + sw.hit[4]) * 0.5)
			local caption = (sw.disabled and colorFaded or (on and colorSelected or colorDim)) .. sw.label
			if sw.top then
				queueText(caption, sw.draw[1] - metrics.rowPad, cy, metrics.catFs, "rov")
			else
				queueText(caption, sw.hit[1] + metrics.sidePad, cy, metrics.toggleFs, "ov")
			end
			if sw.value then
				queueText(
					(sw.disabled and colorFaded or colorSelected) .. tostring(graphs.settingValue(sw.key)),
					sw.hit[3] - metrics.sidePad,
					cy,
					metrics.toggleFs,
					"rov"
				)
			else
				UiToggle(sw.draw[1], sw.draw[2], sw.draw[3], sw.draw[4], on, hovered)
				if sw.disabled then
					-- FlowUI rounds a switch by a tenth of its height and draws an edge
					-- around it; the mute covers both.
					local edge = mathMax(1, mathFloor((sw.draw[4] - sw.draw[2]) * 0.1))
					RectRound(
						sw.draw[1] - edge,
						sw.draw[2] - edge,
						sw.draw[3] + edge,
						sw.draw[4] + edge,
						edge * 2,
						1,
						1,
						1,
						1,
						look.mutedFill
					)
				end
			end
		end
	end
end

-- Everything inside the panel: the column, the switches, the table and the scroller.
-- Baked and replayed until the cursor, the list or the screen moves.
local function drawPanel()
	drawSidebar()
	drawSettings()
	if graphs.open then
		graphs.drawPanel()
		local top, total, offset = select(5, scrollerThumb())
		if total > 0 then
			UiScroller(barX1, listBottom, area.x2 - metrics.edgeInset, top, total, offset, hover.bar == 1, dragging)
		end
		flushText()
		glColor(1, 1, 1, 1)
		return
	end
	tables.drawButton(hover.cols == 1)
	drawTableHeader()
	drawRows()
	-- A table with no stats in it yet says how to give it some.
	if #columns == 1 then
		queueText(
			colorDim .. L.tableEmpty,
			mathFloor((listX1 + barX1) * 0.5),
			mathFloor((listTop + listBottom) * 0.5),
			metrics.catFs,
			"ocv"
		)
	end

	if rowMetrics.totalH > 0 then
		UiScroller(
			barX1,
			listBottom,
			area.x2 - metrics.edgeInset,
			listTop,
			rowMetrics.totalH,
			scrollOffset(),
			hover.bar == 1,
			dragging
		)
	end

	flushText()

	-- The toggle's glow leaves its own tint as the current colour, and this list is
	-- replayed every frame, so the leak would reach whoever draws next.
	glColor(1, 1, 1, 1)
end

local function drawWindow()
	UiElement(
		screenX,
		screenY - screenHeight,
		screenX + screenWidth,
		screenY,
		1,
		1,
		1,
		1,
		1,
		1,
		1,
		1,
		WG.FlowUI.clampedOpacity
	)
end

local function dropLists()
	if panelList then
		glDeleteList(panelList)
		panelList = nil
		panelSig = nil
	end
	graphs.dropTrendList()
	graphs.dropGridTexture()
	if windowList then
		glDeleteList(windowList)
		windowList = nil
	end
end

local function deleteGuishader()
	if backgroundGuishader ~= nil then
		if WG.guishader then
			WG.guishader.DeleteDlist("teamstats")
		else
			glDeleteList(backgroundGuishader)
		end
		backgroundGuishader = nil
	end
end

-- Reads the hover state and answers a signature of everything the baked panel is painted
-- from. Same signature, same picture, so the display list is replayed as it is. The body
-- column under the cursor is read too, for the tooltip, but nothing is painted from it.
local function panelSignature(mx, my)
	hover.sb = sidebarIndexAt(mx, my) or 0
	hover.row = 0
	hover.col = 0
	hover.hcol = 0
	hover.tog = switchAt(mx, my) or 0
	hover.bar = 0
	if mx >= barX1 and mx <= area.x2 then
		-- The thumb itself, not the track: it is the part that can be taken hold of, so it
		-- is the part that lights up.
		local top, height = scrollerThumb()
		if top and my <= top and my >= top - height then
			hover.bar = 1
		end
	end

	local extra = ""
	hover.cols = 0
	if graphs.open then
		extra = "|g" .. graphs.hoverAt(mx, my)
	elseif tables.buttonAt(mx, my) then
		hover.cols = 1
	elseif hover.tog == 0 and mx >= listX1 and mx < listRight then
		hover.hcol = headerColumnAt(mx, my) or 0
		if hover.hcol == 0 then
			hover.row = rowAt(my) or 0
			if hover.row > 0 then
				hover.col = columnAt(mx) or 0
			end
		end
	end
	-- The Columns... button is lit while its card is open.
	if tables.cardOpen() then
		extra = extra .. "|c"
	end

	return hover.sb
		.. "|"
		.. hover.cols
		.. "|"
		.. hover.row
		.. "|"
		.. hover.hcol
		.. "|"
		.. hover.tog
		.. "|"
		.. hover.bar
		.. "|"
		.. scroll
		.. "|"
		.. sidebar.scroll
		.. "|"
		.. model.rowsGen
		.. "|"
		.. layoutGen
		.. "|"
		.. (dragging and 1 or 0)
		.. extra
end

----------------------------------------------------------------
-- Callins
----------------------------------------------------------------

function widget:ViewResize()
	vsx, vsy = spGetViewGeometry()
	widgetScale = (vsy / 1080)

	screenHeight = mathFloor(screenHeightOrg * widgetScale)
	screenWidth = mathFloor(screenWidthOrg * widgetScale)
	screenX = mathFloor((vsx * 0.5) - (screenWidth / 2))
	screenY = mathFloor((vsy * 0.5) + (screenHeight / 2))

	font = WG.fonts.getFont()
	metrics.numFont = WG.fonts.getFont(3)
	metrics.nameFont = WG.fonts.getFont(2)
	elementCorner = WG.FlowUI.elementCorner

	RectRound = WG.FlowUI.Draw.RectRound
	UiElement = WG.FlowUI.Draw.Element
	UiScroller = WG.FlowUI.Draw.Scroller
	UiScrollerAt = WG.FlowUI.Draw.ScrollerGeometry
	Highlight = WG.FlowUI.Draw.SelectHighlight
	UiToggle = WG.FlowUI.Draw.Toggle

	setLayout()
	dropLists()
	deleteGuishader()
end

function widget:DrawScreen()
	if not (show or showOnceMore) then
		deleteGuishader()
		return
	end

	-- Pinned rather than assumed: widgets on lower layers draw first and leave blending,
	-- colour and the texture wherever they finished.
	glTexture(false)
	glColor(1, 1, 1, 1)

	local mx, my, lmb = spGetMouseState()
	if dragging then
		if lmb then
			scrollFromY(my)
		else
			dragging = false
		end
	end
	-- A graph pressed in a category of the player's own, or a table's caption, turns into a
	-- drag as it travels.
	graphs.dragUpdate(mx, my, lmb)
	tables.dragUpdate(mx, my, lmb)
	-- An open card has the cursor to itself, and so has a graph or a column being dragged:
	-- nothing under them lights up.
	local hx, hy = mx, my
	if not show or graphs.menuOpen() or graphs.dragMoving() or tables.cardOpen() or tables.dragMoving() then
		hx, hy = -1, -1
	end

	-- The rows the table waited for while the Graphs page was on.
	if rowMetrics.stale and not graphs.open then
		rowMetrics.stale = false
		model.rebuildRows()
	end
	local sig = panelSignature(hx, hy)
	if sig ~= panelSig then
		if panelList then
			glDeleteList(panelList)
		end
		panelList = glCreateList(drawPanel)
		panelSig = sig
	end

	if not windowList then
		windowList = glCreateList(drawWindow)
	end
	---@cast panelList -?
	glCallList(windowList)
	glCallList(panelList)
	-- The table's trend lines, from a list of their own: the panel is baked again whenever
	-- the cursor moves onto another row, and would draw every line again with it.
	if show and filters.trend and not graphs.open then
		graphs.drawTrendList(model.rowsGen, scroll, layoutGen)
	end
	if show and graphs.open then
		-- The chart keeps its own list and draws its hover overlay straight, so the
		-- cursor moving over it never rebakes the panel.
		graphs.drawChart(hx, hy)
		graphs.drawDrag(mx, my)
	elseif show then
		tables.drawDrag(mx, my)
	end
	-- A category being named: its field over its sidebar entry.
	if show and graphs.naming then
		for i = 1, #model.entries do
			if model.entries[i].key == graphs.naming.key then
				local x1, y1, x2, y2 = entryRect(i)
				if y2 > y1 and y1 >= metrics.settingsTop then
					graphs.drawNaming(x1 + metrics.catInset, y1, x2 - metrics.catInset, y2)
				end
			end
		end
	end
	-- The card of a table's columns, and a card of actions, over everything.
	if show then
		tables.drawCard(mx, my)
	end
	if show and graphs.menuOpen() then
		graphs.drawMenu(mx, my)
	end

	if WG.guishader and backgroundGuishader == nil then
		backgroundGuishader = glCreateList(function()
			RectRound(screenX, screenY - screenHeight, screenX + screenWidth, screenY, elementCorner, 1, 1, 1, 1)
		end)
		WG.guishader.InsertDlist(backgroundGuishader, "teamstats", nil, widget)
	end
	showOnceMore = false

	if show and math_isInRect(mx, my, screenX, screenY - screenHeight, screenX + screenWidth, screenY) then
		spSetMouseCursor("cursornormal")

		if WG.tooltip and not graphs.menuOpen() and not graphs.dragMoving() and not tables.dragMoving() then
			local title, tip
			local entry = hover.sb > 0 and model.entries[hover.sb] or nil
			if tables.cardOpen() then
				-- The card has the cursor to itself.
				title, tip = tables.cardTip(mx, my)
			elseif graphs.open and hover.sb == 0 and hover.tog == 0 then
				title, tip = graphs.tooltip()
			elseif hover.cols == 1 then
				title = tables.buttonLabel
				tip = L.columnsDesc
			elseif hover.hcol > 1 then
				local column = columns[hover.hcol]
				---@cast column -?
				title = model.columnTitle(column)
				tip = { text = L.desc[column.key], note = L.captionHint }
			elseif hover.tog > 0 then
				local sw = switches[hover.tog]
				---@cast sw -?
				title = sw.label
				tip = L.switchDesc[sw.key]
				-- In a custom category these rows are each graph's own.
				if
					sw.perGraph
					and graphs.open
					and groupByKey[model.selectedGroup]
					and groupByKey[model.selectedGroup].custom
				then
					local note = graphs.openGraph() and L.perGraphOpen or (sw.top and L.groupAll or L.perGraphGrid)
					tip = { text = tip, note = note }
				end
			elseif entry and entry.disabled then
				title = entry.label
				tip = L.notYet
			elseif entry and entry.custom then
				title = entry.label
				-- The one that ships is reset rather than deleted.
				tip = entry.key == "overview" and L.overviewHint or L.categoryHint
			elseif entry and entry.table then
				title = entry.label
				tip = tables.describe(tables.byKey[entry.key])
			elseif entry and entry.add then
				local isTable = entry.key == "newTable"
				title = isTable and L.newTable or L.newCategory
				tip = isTable and L.newTableDesc or L.newCategoryDesc
			elseif hover.row > 0 and hover.col == 1 then
				-- Everything about the player, on the name: the columns the open view hides too.
				local row = model.rows[scroll + hover.row]
				if row and row.team then
					title = (row.team.nameColor or "") .. row.team.label
					tip = model.nameCard(row.team)
				elseif row then
					title = row.caption
					tip = L.foldHint
				end
			elseif hover.row > 0 and hover.col > 1 then
				-- The cell's whole number: a cell rounds to three figures. A share says what it
				-- is a share of.
				local row = model.rows[scroll + hover.row]
				local column = columns[hover.col]
				---@cast column -?
				if row then
					fitRow(row)
					title = row.type == "team" and row.team.name or row.caption
					tip = model.cellTip(column, row, row.vals[hover.col])
				end
			end
			if tip then
				local width = WG.tooltip.getFontsize() * 90
				WG.tooltip.ShowTooltip("teamstats", model.wrapTip(tip, font, width), nil, nil, title)
			end
		end
	end
end

local function closePanel()
	show = false
	dragging = false
	model.listen(false)
	-- A name being typed is kept; a card and a drag are put away.
	graphs.stopNaming(true)
	graphs.closeMenu()
	graphs.drag = nil
	tables.closeCard()
	tables.drag = nil
	if WG.tooltip then
		WG.tooltip.RemoveTooltip("teamstats")
	end
end

local function setShown(state)
	if not state then
		closePanel()
		return
	end

	if not show and WG.topbar then
		WG.topbar.hideWindows()
	end
	show = true
	model.opened()
	for i = 1, #model.entries do
		if model.entries[i].key == model.selectedGroup then
			sidebar.reveal(i)
		end
	end
end

function widget:KeyPress(key)
	-- A name being typed takes every key: Enter keeps it, Escape keeps the old one.
	if show and graphs.naming then
		return graphs.namingKey(key)
	end
	if show and key == 27 and graphs.menuOpen() then
		graphs.closeMenu()
		dropLists()
		return true
	end
	if show and key == 27 and tables.cardOpen() then
		tables.closeCard()
		return true
	end
	-- With one chart open, the arrow keys go through the category's charts; the settings
	-- follow the chart.
	if show and graphs.open and not graphs.menuOpen() and not graphs.kindsOpen then
		local stat = graphs.stat
		if graphs.keyPress(key) then
			if graphs.stat ~= stat then
				setLayout()
			end
			return true
		end
	end
	if show and key == 27 and graphs.open and graphs.kindsOpen then
		-- ESC closes what is open on the panel before it closes the panel.
		graphs.closeKinds()
		dropLists()
		return true
	end
	if show and key == 27 then
		-- ESC
		showOnceMore = true
		closePanel()
		return true
	end

	return false
end

-- Swallowed across the whole panel, not just the table: a wheel that gets through zooms
-- the camera behind it.
function widget:MouseWheel(up, _value)
	if not show then
		return false
	end

	local x, y = spGetMouseState()
	if not math_isInRect(x, y, screenX, screenY - screenHeight, screenX + screenWidth, screenY) then
		return false
	end

	-- Over the graphs' entries while they do not all fit, the wheel scrolls them - not while
	-- one is being named, which would scroll its field away.
	local onEntries = false
	if sidebar.bar and not graphs.naming and x <= area.x1 + metrics.sidebarW and y > metrics.settingsTop then
		local _, top = entryRect(sidebar.first - 1)
		onEntries = y <= top
	end

	if onEntries then
		sidebar.scroll = mathMax(0, mathMin(sidebar.max, sidebar.scroll + (up and -1 or 1)))
	elseif graphs.open then
		-- The Graphs page scrolls its grid of charts, or the rows of an open chart that has more
		-- than fit; the wheel is the panel's either way.
		graphs.wheel(up)
	else
		-- The chat history's modifiers: Ctrl moves three notches' worth at once, Shift a whole
		-- page - the rows the band holds from where the list is now, since a band is taller.
		local _, ctrl, _, shift = spGetModKeyState()
		local step = ctrl and metrics.wheelRows * 3 or metrics.wheelRows
		if shift then
			ensureRowMetrics()
			local band, used = listTop - listBottom, 0
			step = 0
			for i = scroll + 1, #model.rows do
				used = used + rowHeightOf(model.rows[i])
				if used > band then
					break
				end
				step = step + 1
			end
			step = mathMax(1, step)
		end
		setScroll(scroll + (up and -step or step))
	end

	return true
end

-- Clicks inside the panel pick a view, flip a switch, sort a column or grab the
-- scrollbar; a press outside closes it.
local function mouseEvent(x, y, button, release)
	if spIsGUIHidden() then
		return false
	end

	if not show then
		return false
	end

	-- A graph pressed in a category of the player's own, let go wherever: opened, or moved
	-- to where it was dragged.
	if release and graphs.dragging() then
		local stat, applies = graphs.stat, graphs.shareApplies()
		graphs.mouseRelease(x, y)
		if graphs.stat ~= stat or graphs.shareApplies() ~= applies then
			setLayout()
		end
		return true
	end
	-- A table's caption let go: a click sorts by its column, a drag has moved it.
	if release and tables.drag then
		local what, key = tables.release(x, tables.current)
		if what == "click" and COLUMNS[key] then
			model.sortBy(COLUMNS[key])
		end
		return true
	end

	-- A press on a top bar button is the top bar's to handle: it closes the open windows
	-- and opens the one that was clicked. Closing (and consuming) here would swallow it.
	if WG.topbar and WG.topbar.buttonAt and WG.topbar.buttonAt(x, y) then
		return false
	end

	-- A card of actions takes every press while it is open, wherever it lands, and so does the
	-- card of a table's columns.
	if not release and graphs.menuOpen() then
		graphs.menuPress(x, y, button)
		dropLists()
		return true
	end
	if not release and tables.cardOpen() then
		tables.cardPress(x, y, button)
		return true
	end
	-- Naming a category: a press in the field moves the caret, one anywhere else keeps the
	-- name typed so far and goes on to whatever it was on.
	if not release and graphs.naming then
		local r = graphs.naming.box.rect
		if math_isInRect(x, y, r[1], r[2], r[3], r[4]) then
			graphs.naming.box:mousePress(x, y)
			return true
		end
		graphs.stopNaming(true)
	end

	if math_isInRect(x, y, screenX, screenY - screenHeight, screenX + screenWidth, screenY) then
		if not release and graphs.open and graphs.kindsOpen then
			graphs.mousePress(x, y, button)
			dropLists()
			return true
		end
		if not release and button == 3 then
			local sw = switchAt(x, y)
			local i = sidebarIndexAt(x, y)
			local entry = i and model.entries[i]
			if sw then
				-- A setting with a value steps back on the right button.
				model.toggleSwitch(sw, true)
			elseif entry and entry.custom then
				-- One of the player's categories: renamed, moved or deleted from its card.
				local x1, y1, x2, y2 = entryRect(i)
				graphs.openCategoryMenu(entry.key, { x1, y1, x2, y2 })
				dropLists()
			elseif entry and entry.table then
				-- A table: its columns put back as they shipped, from its card.
				local x1, y1, x2, y2 = entryRect(i)
				tables.openEntryMenu(entry.key, { x1, y1, x2, y2 })
				dropLists()
			elseif graphs.open then
				-- The Graphs page's legend takes the right button too: it hides a team, which
				-- can leave one on the charts and the share with nothing to share out.
				local applies = graphs.shareApplies()
				graphs.mousePress(x, y, 3)
				if graphs.shareApplies() ~= applies then
					setLayout()
				end
			else
				-- A caption: its column moved a place or taken out, from its card.
				local col = x >= listX1 and x < listRight and headerColumnAt(x, y)
				local column = col and col > 1 and columns[col]
				if column then
					tables.openColumnMenu(
						tables.current,
						column,
						{ column.x1, metrics.statBottom, column.x2, metrics.statTop }
					)
					dropLists()
				end
			end
		elseif not release and button == 1 then
			local sw = switchAt(x, y)
			local i = sidebarIndexAt(x, y)
			local col = not graphs.open and x >= listX1 and x < listRight and headerColumnAt(x, y)
			local fold = nil
			if not graphs.open and x >= listX1 and x < listRight then
				local r = rowAt(y)
				local row = r and model.rows[scroll + r]
				if row and row.type == "band" and not row.team and columnAt(x) == 1 then
					fold = row.ally.id
				end
			end
			if sw then
				model.toggleSwitch(sw)
			elseif i then
				local e = model.entries[i]
				---@cast e -?
				model.selectEntry(e.key)
			elseif not graphs.open and tables.buttonAt(x, y) then
				tables.openCard(tables.current)
			-- The bar owns its column in both views, so it is asked before the table's rows
			-- and before the page's charts.
			elseif math_isInRect(x, y, barX1, listBottom, area.x2, select(5, scrollerThumb()) or listTop) then
				-- The strip between the bar and the panel edge stays grabbable too.
				grabScroller(y)
			elseif graphs.open then
				local stat, applies = graphs.stat, graphs.shareApplies()
				graphs.mousePress(x, y, 1)
				-- Another stat, or a pick that leaves one team on the charts, changes what the
				-- settings offer: they are laid out again.
				if graphs.stat ~= stat or graphs.shareApplies() ~= applies then
					setLayout()
				end
			elseif fold then
				model.toggleFold(fold)
			elseif col then
				-- Sorted by once let go, moved if dragged; the names only ever sort.
				local column = columns[col]
				---@cast column -?
				tables.press(column.key, x, y, col == 1)
			end
		end

		return true
	elseif not release then
		-- Only a press outside closes. A release out here belongs to a drag that started
		-- on the scrollbar.
		showOnceMore = true -- show once more because the guishader lags behind
		closePanel()

		return true
	end
end

function widget:MousePress(x, y, button)
	return mouseEvent(x, y, button, false)
end

function widget:TextInput(utf8char)
	if show and graphs.naming then
		return graphs.namingText(utf8char)
	end
	return false
end

function widget:MouseRelease(x, y, button)
	return mouseEvent(x, y, button, true)
end

function widget:GameFrame(n)
	model.gameFrame(n)
end

function widget:GameOver()
	model.gameOver()
end

function widget:TeamDied(teamID)
	model.teamDied(teamID)
end

function widget:ApmEvent(teamID, apm)
	model.apmEvent(teamID, apm)
end

function widget:PlayerChanged()
	model.playerChanged()
end

function widget:Initialize()
	-- No config to hand over (a first game, or a reset config): the file still has the player's.
	if not model.store.loaded() then
		widget:SetConfigData({})
	end
	model.loadLabels()
	handover.rememberNames()
	widget:ViewResize()

	widgetHandler:AddAction("teamstats", function()
		setShown(not show)

		return true
	end, nil, "p")
	widgetHandler:AddAction("teamstatus_close", function()
		if show then
			setShown(false)

			return true
		end
	end, nil, "p")

	-- lets the handler hide the rest of the interface while the panel is open
	widgetHandler:RegisterModalWindow(function()
		return show == true
	end)

	WG.teamstats = {}
	WG.teamstats.toggle = function(state)
		if state == nil then
			state = not show
		end
		setShown(state)
	end
	WG.teamstats.isvisible = function()
		return show
	end
	-- The graphs, for a key or another widget: opens the panel on the category of graphs last
	-- shown when needed - or, turned off, on the table last shown.
	WG.teamstats.showGraphs = function(state)
		if state == nil then
			state = not graphs.open
		end
		if state and not show then
			setShown(true)
		end
		if state ~= graphs.open then
			model.selectEntry(
				state and (groupByKey[graphs.group or ""] and graphs.group or "overview") or tables.current
			)
		end
	end
end

function widget:Shutdown()
	dropLists()
	deleteGuishader()
	graphs.destroy()
	model.listen(false)
	if WG.tooltip then
		WG.tooltip.RemoveTooltip("teamstats")
	end
	WG.teamstats = nil
end

function widget:GetConfigData()
	return model.getConfig()
end

function widget:SetConfigData(data)
	model.setConfig(data)
end

function widget:LanguageChanged()
	model.languageChanged()
	widget:ViewResize()
	-- Names with a dead or gone suffix are read in the language of the read.
	if #model.allies > 0 and not model.gameover then
		model.refresh()
	end
end

view.isShown = function()
	return show
end
view.layout = setLayout
view.layoutColumns = layoutColumns
view.dropLists = dropLists
view.entriesChanged = sidebar.fit
view.revealEntry = sidebar.reveal
view.registerGlobal = function(name, fn)
	return widgetHandler:RegisterGlobal(name, fn)
end
view.deregisterGlobal = function(name)
	return widgetHandler:DeregisterGlobal(name)
end
-- Whether the viewer has a team of their own is only known once the teams are read,
-- which is after the first layout: the comparison switch lights up when it is. Only a
-- switch laid out out of step is laid out again: a layout rebuilds every chart.
view.teamsRead = function()
	---@diagnostic disable-next-line: undefined-field
	local canCompare = model.allies.me ~= nil
	-- Grouping is offered once another side is to be seen: as a spectator, or at game over.
	local groupable = model.canGroup()
	local stale, regrouped = false, false
	for i = 1, #switches do
		local sw = switches[i]
		if sw.key == "vsMe" and sw.hit and (sw.disabled == true) == canCompare then
			stale = true
		elseif sw.key == "groupByTeam" and (sw.hit ~= nil) ~= groupable then
			stale, regrouped = true, true
		end
	end
	if stale then
		setLayout()
	end
	-- As the switch's own press does: the rows follow the layout grouping decides.
	if regrouped and not graphs.open then
		model.rebuildRows()
	end
end

-- The Graphs page, handed everything of the panel's it reads. Made here, at the end, so
-- every function above is in reach of it; the callins run later than this.
graphs = require("luaui/Include/teamstats_graphs").new(model.pageContext({
	-- The history behind every number on screen, for the page's trend list: in the team's
	-- own colour, a band's in its team's when it is one team's, else in the header's hue;
	-- beside the number, in what it leaves of its cell, so neither is read through the other.
	trendRows = function()
		local base = scrollOffset()
		for i = scroll + 1, #model.rows do
			local row = model.rows[i]
			---@cast row -?
			local top = listTop - (row.off - base)
			local bottom = top - rowHeightOf(row)
			if bottom < listBottom then
				break
			end
			fitRow(row)
			if row.trendKey then
				local team = row.team
				local color, lineTop
				if row.type == "band" then
					local accent = team and team.accent
					color = accent and { accent[1], accent[2], accent[3], 0.65 } or look.trendBand
					lineTop = top - metrics.csSmall - metrics.barInset
				else
					---@cast team -?
					color = { team.accent[1], team.accent[2], team.accent[3], (team.dead or team.gone) and 0.4 or 0.75 }
					lineTop = top - metrics.barInset
				end
				for c = 2, #columns do
					local column = columns[c]
					---@cast column -?
					local right = column.x2
						- metrics.cellPad
						- mathFloor((metrics.numFont or font):GetTextWidth(row.cells[c]) * metrics.rowFs)
					graphs.trendCell(
						row.trendKey,
						column.key,
						column.rate == true,
						column.x1 + metrics.cellPad,
						bottom + metrics.barInset,
						right - metrics.rowPad,
						lineTop,
						color,
						metrics.trendW
					)
				end
			end
		end
	end,
	look = look,
	metrics = metrics,
	colors = {
		title = colorTitle,
		dim = colorDim,
		faded = colorFaded,
		selected = colorSelected,
		value = colorValue,
		bad = colorBad,
	},
	-- The FlowUI draw calls are fetched at ViewResize, so they are read when called; the
	-- plain rect is for whole-pixel lines and squares.
	draw = {
		RectRound = function(...)
			return RectRound(...)
		end,
		Highlight = function(...)
			return Highlight(...)
		end,
		Color = glColor,
		Rect = gl.Rect,
		-- Looked up when drawn: FlowUI is there by then.
		RectRoundOutline = function(...)
			return WG.FlowUI.Draw.RectRoundOutline(...)
		end,
		Toggle = function(...)
			return UiToggle(...)
		end,
	},
	queueText = queueText,
	text = text,
	font = function()
		return font
	end,
	-- The face the interface names players in, for what the page calls a team or a player.
	nameFont = function()
		return metrics.nameFont or font
	end,
}))

-- The tables and the columns the player keeps in them; their right-click cards are the
-- page's cards of actions.
tables = require("luaui/Include/teamstats_tables").new(model.tablesContext({
	look = look,
	metrics = metrics,
	colors = {
		title = colorTitle,
		header = colorHeader,
		dim = colorDim,
		faded = colorFaded,
		selected = colorSelected,
	},
	draw = {
		RectRound = function(...)
			return RectRound(...)
		end,
		Highlight = function(...)
			return Highlight(...)
		end,
		Color = glColor,
	},
	font = function()
		return font
	end,
	queueText = queueText,
	columns = function()
		return columns
	end,
	-- As many columns as keep their width above the narrowest a number's column gets, beside
	-- the names at the share of the table they take.
	capacity = function()
		local tableW = barX1 - metrics.listGap - listX1
		local nameW = mathMax(metrics.nameMinW, mathFloor(tableW * metrics.nameShare))
		return mathMax(1, mathFloor((tableW - nameW) / metrics.colMinW))
	end,
	-- A dragged column is shaded from its caption down to the last row.
	dragBounds = function()
		return metrics.statTop, mathMax(listBottom, listTop - rowMetrics.totalH + scrollOffset())
	end,
}))
model.attach(graphs, tables)
