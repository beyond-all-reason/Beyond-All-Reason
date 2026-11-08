local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Game info",
		desc = "",
		author = "Floris",
		date = "May 2017",
		license = "GNU GPL, v2 or later",
		layer = -99990,
		enabled = true,
	}
end

-- The panel is laid out the way the keybind editor lays out its own: the same inset area,
-- the title in the top-left corner over a darker card holding the category column, a
-- search field and a filter toggle in the header band, and a 14 px scrollbar standing in
-- its own channel against the right edge.
--
-- Everything shown is built once into blocks of rows, each block belonging to a category.
-- The column, the search box and the "changed only" toggle only pick which of those rows
-- the list shows, so nothing is decoded or measured again while they are used.

-- What is shown: luaui/Include/gameinfo_model.lua.
local model = require("luaui/Include/gameinfo_model")
-- Shared with the keybind editor, which is where both were written for.
local Editbox = require("luaui/Include/keybind_editbox")
local KEY_C = Spring.GetKeyCode("c")
local KEY_A = Spring.GetKeyCode("a")
local text = require("luaui/Include/keybind_text")

-- Localized functions for performance
local mathFloor = math.floor
local mathMax = math.max
local mathMin = math.min

-- Localized Spring API for performance
local spGetViewGeometry = Spring.GetViewGeometry
local spGetMouseState = Spring.GetMouseState
local spIsGUIHidden = Spring.IsGUIHidden
local glCreateList = gl.CreateList
local glCallList = gl.CallList
local glDeleteList = gl.DeleteList
local glColor = gl.Color
local glTexture = gl.Texture
local math_isInRect = math.isInRect

local playSounds = true
local buttonclick = "LuaUI/Sounds/buildbar_waypoint.wav"

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
---@type function
local UiUnit
local elementCorner
local font, fontMono

local area = { x1 = 0, y1 = 0, x2 = 0, y2 = 0 }
-- Sizes derived from the scale, in one table rather than a local each, the way the
-- keybind editor holds its own: this chunk is close to Lua's limit of 200 locals.
local metrics = {
	rowHeight = 24,
	catRowHeight = 29,
	rowFs = 13,
	-- A category heading stands taller than the rows under it and is set larger, so it
	-- reads as a divider rather than another row.
	headerRowHeight = 32,
	headerFs = 14,
	catFs = 13,
	-- Decoded tweaks are source, so they get the monospaced face on a tighter row.
	codeRowHeight = 19,
	codeFs = 12,
	-- A tweaked unit gets its picture beside it, spanning the three code rows its block takes
	-- at its shortest. What it gives up to the gaps above and below is what keeps two of them
	-- apart when a unit had only one parameter changed; more comes off the top than the
	-- bottom, so the picture sits against the fields it describes rather than the block above.
	iconSize = 45,
	iconTop = 6,
	iconBottom = 3,
	-- A search shows the lines it matched and nothing around them, so each one names its
	-- unit and shows it small. This is the most of a name that column keeps.
	tinyIcon = 15,
	ownerChars = 22,
	rowPad = 6,
	sidePad = 12,
	catInset = 4,
	-- The line along the bottom of a heading.
	underlineH = 2,
	-- The bar marking a row whose value is not the default one.
	accentW = 3,
	-- Everything that sits against the panel's right edge - the toggle and the scrollbar -
	-- is held off it by this much.
	edgeInset = 4,
	-- The band the title, the search field and the filter toggle share, and the gap below.
	headerH = 34,
	headerGap = 4,
	-- Clearance between the right edge of the rows and the scrollbar beside them.
	listGap = 12,
	-- How far the category card rises above the first entry in it.
	cardLip = 5,
	-- The panel title: its baseline below the top edge, and its size.
	titleY = 17,
	titleFs = 20,
	-- How far the category column starts below the rows beside it, to leave the title room.
	sidebarDrop = 8,
	sidebarW = 240,
	-- Where everything below the header band starts: the category column measures from it,
	-- and so does the list, unless the unit strip is standing over it.
	bandTop = 0,
	-- The unit strip over a tweakunits listing: the room inside its card, the gap between it
	-- and the rows under it, and the smallest a picture is shrunk to before it stops shrinking.
	stripPad = 6,
	stripGap = 8,
	stripMin = 12,
	barW = 14,
	-- Rows the wheel moves per notch.
	wheelRows = 3,
	-- Corner radii, taken from FlowUI's so the panel rounds like the rest of the UI.
	csSmall = 2,
	csPanel = 4,
}
local look = {
	-- The category column sits on its own darker card, so it reads apart from the list.
	sidebarFill = { 0, 0, 0, 0.24 },
	sidebarFillTop = { 0, 0, 0, 0.16 },
	selectedFill = { 1, 1, 1, 0.13 },
	-- Brighter than the category column's own selection: this one is over source that is
	-- already coloured, and has to read through it.
	codeSelectedFill = { 0.45, 0.62, 0.95, 0.28 },
	white = { 1, 1, 1 },
	-- Rows and categories hover with the same FlowUI highlight the settings list uses, at
	-- the strength it gives a plain row.
	rowHoverOpacity = 0.14,
	-- An adjusted option is marked three ways at once - a warm band across the row, a bar
	-- down its left edge and warm text - so it is still obvious in a list scrolled past
	-- quickly, where a colour change alone reads as noise.
	changedFill = { 1, 0.8, 0.45, 0.08 },
	changedAccent = { 1, 0.78, 0.35, 0.7 },
	-- The same three marks in the colour of something that did not work.
	failedFill = { 0.92, 0.35, 0.35, 0.1 },
	failedAccent = { 0.92, 0.35, 0.35, 0.8 },
	-- Underline under a category heading: a thin bar fading up out of the bottom edge, in
	-- the hue of the caption above it.
	headerLine = { 1, 0.78, 0.51, 0.4 },
	headerLineFade = { 1, 0.78, 0.51, 0 },
	failedLine = { 0.92, 0.35, 0.35, 0.5 },
	failedLineFade = { 0.92, 0.35, 0.35, 0 },
	sheenTop = { 1, 1, 1, 0.05 },
}
local colorTitle = "\255\235\235\235"
local colorHeader = "\255\255\200\130"
-- Names and values at their default, and the same pair once the value is not the default:
-- both halves of the row brighten, so the row reads as adjusted from either column.
local colorName = "\255\185\183\180"
local colorValue = "\255\145\145\145"
local colorNameOn = "\255\240\240\240"
local colorValueOn = "\255\255\205\100"
-- Between a changed option's default and its value.
local defaultArrow = "  \226\134\146  "
-- Facts read off the map and the engine rather than settings, so they take neither the
-- muted look of a default nor the warm one of a change.
local colorInfo = "\255\205\202\199"
local colorSelected = "\255\210\210\205"
local colorDim = "\255\160\160\160"
-- A tweak the game could not load. Not a shade of the warm "adjusted" colour: this is not
-- a setting that took effect, and it must not read like one.
local colorDanger = "\255\235\090\090"
-- Texture zooms for the unit pictures. The ones beside the source take the zoom the build
-- menu shows an idle cell at, so a unit reads the same in both; the smaller a picture is, the
-- more of it the frame takes, so the smaller ones are zoomed in a little further to keep the
-- unit readable. The strip's hovered zoom is the build menu's step up from idle.
local iconZoom = {
	idle = 0.075,
	strip = 0.125,
	stripHover = 0.18,
	-- The picture after a buildoptions entry, the smallest of them all, and the zoom it takes
	-- hovered when the unit it names has a block of its own to jump to.
	option = 0.22,
	optionHover = 0.3,
}

local L = model.L

local show, showOnceMore
local panelList, windowList, backgroundGuishader, panelSig
local listTop, listBottom, listX1, listRight, valueX1, barX1 = 0, 0, 0, 0, 0, 0
local toggleHit, toggleDraw = {}, {}

-- Bumped by setLayout. A cached row layout carries the value it was built against and is
-- measured again when it moves, without every row being walked at resize.
local layoutGen = 0
local rowMetrics = { gen = -1, rows = -1, totalH = 0 }
local scroll = 0
-- How far the category column is scrolled, in whole entries. A game with enough
-- modoption sections, or a short enough panel, has more of them than the column holds.
local catScroll = 0
local dragging = false
-- Where the thumb was taken hold of, as the distance from the cursor to its top edge. The
-- thumb then follows the cursor by that much, instead of jumping its middle to wherever
-- the press landed.
local dragGrab = 0
-- Rows of decoded tweak the cursor has dragged over, as indices into `rows`. Source is the
-- one thing in here worth taking somewhere else, so it is the one thing that selects.
local selFrom, selTo = 0, 0
local selecting = false
-- Keys taken for a copy. The engine runs a bound action on release as well as on press, so
-- consuming only the press would still fire whatever else the shortcut is bound to.
local consumedKeys = {}
---@type table
local searchBox
-- What the cursor is over, in the terms the baked panel is painted with. Refilled in
-- place each frame rather than allocated.
local hover = { sb = 0, row = 0, tog = 0, bar = 0, strip = 0, option = 0 }
-- The units a tweakunits listing names, as pictures above it that jump the list to each one.
-- `ids` and `rows` are parallel and reused between rebuilds; `count` says how much is live.
-- Its functions live on it too: this chunk is at Lua's limit of 200 locals.
local unitStrip = {
	ids = {},
	rows = {},
	count = 0,
	size = 0,
	gap = 0,
	cols = 1,
	h = 0,
	x1 = 0,
	top = 0,
	iconTop = 0,
	bottom = 0,
}

-- Input ownership is taken once when the search field takes focus and given back when it
-- loses it, rather than every frame, so chat's handling is restored exactly as it was
-- found.
local ownsInput = false
local fieldHasInput = false
local textInputStarted = false
-- Keys already down when the field took focus. Their release has to be let through, or
-- whatever they started stays stuck on once the field starts swallowing releases.
local heldAtFocus = {}

local rebuildRows

----------------------------------------------------------------
-- The row list
----------------------------------------------------------------

local function rowHeightOf(row)
	if row.type == "header" then
		return metrics.headerRowHeight
	elseif row.type == "code" then
		return metrics.codeRowHeight
	end
	return metrics.rowHeight
end

-- A row's position is a sum of what is above it rather than its index times one height:
-- headings and code lines are not the height of an ordinary row. The running total is
-- stamped onto the rows, and redone when the list or the layout changes.
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

local function setScroll(n)
	scroll = n
	clampScroll()
end

-- Lays the unit strip out over whatever the list is showing, and moves the top of the list
-- down under it. One picture per unit per slot, in listing order, each pointing at the first
-- row of that unit the list kept - which under a search can be a line rather than the opening.
--
-- Pictures take two thirds of the size they have beside the source, in up to three lines of
-- that size; fewer lines take less room. More than three lines' worth shrinks them until they
-- fit in that same room on four lines, then five, and so on.
function unitStrip.layout()
	local s = unitStrip
	local n, blockRows, anyRow = model.listUnits(s)
	s.count = n
	s.blockRows, s.anyRow = blockRows, anyRow

	if n == 0 then
		s.h = 0
		listTop = metrics.bandTop
		return
	end

	local width = listRight - listX1 - metrics.stripPad * 2
	local base = mathMax(metrics.stripMin, mathFloor(metrics.iconSize * 2 / 3))
	local gapShare = 0.12
	local room = base * 3 + mathMax(1, mathFloor(base * gapShare)) * 2
	local size, gap, cols, lines = base, 1, 1, 1
	local fit = 3
	while true do
		gap = mathMax(1, mathFloor(size * gapShare))
		cols = mathMax(1, mathFloor((width + gap) / (size + gap)))
		lines = mathFloor((n + cols - 1) / cols)
		if lines <= fit or size <= metrics.stripMin then
			break
		end
		fit = fit + 1
		size = mathMax(metrics.stripMin, mathFloor(room / (fit + (fit - 1) * gapShare)))
	end

	-- Only reached past the smallest size: a strip that still does not fit is cut off rather
	-- than left to push the list out of the panel.
	local h = mathMin(lines * size + (lines - 1) * gap, mathFloor((metrics.bandTop - listBottom) * 0.5))
	s.size, s.gap, s.cols, s.h = size, gap, cols, h
	s.x1 = listX1 + metrics.stripPad
	-- Level with the top of the category card beside it.
	s.top = metrics.bandTop - metrics.sidebarDrop + metrics.cardLip
	s.iconTop = s.top - metrics.stripPad
	s.bottom = s.iconTop - h - metrics.stripPad
	listTop = s.bottom - metrics.stripGap
end

-- The strip picture under x,y, as its place in the strip, or nil. A picture's cell runs on
-- over the gap after it, so moving between two never lights neither.
function unitStrip.indexAt(x, y)
	local s = unitStrip
	if s.count == 0 or x < s.x1 or x > listRight or y > s.iconTop or y <= s.iconTop - s.h then
		return nil
	end

	local step = s.size + s.gap
	local col = mathFloor((x - s.x1) / step)
	local line = mathFloor((s.iconTop - y) / step)
	local i = line * s.cols + col + 1
	if col >= s.cols or i > s.count or (line + 1) * step - s.gap > s.h then
		return nil
	end

	return i
end

----------------------------------------------------------------
-- Selecting source
----------------------------------------------------------------

local function clearSelection()
	selFrom, selTo, selecting = 0, 0, false
end

-- The selected span, low end first, or nil when nothing is selected.
local function selectionRange()
	if selFrom == 0 then
		return nil
	end

	return mathMin(selFrom, selTo), mathMax(selFrom, selTo)
end

-- Puts the selected source on the clipboard. Answers whether there was anything to copy.
local function copySelection()
	local from, to = selectionRange()
	if not from then
		return false
	end

	return model.copyRows(from, to)
end

-- Every row of source the list is showing. In a tweak category that is the whole snippet,
-- which is what someone reaching for select-all is after.
local function selectAllCode()
	local first, last = model.codeRange()
	if not first then
		return false
	end

	selFrom, selTo, selecting = first, last, false

	return true
end

-- The thumb, where it is now. Nil when everything fits and no bar is drawn.
local function scrollerThumb()
	return UiScrollerAt(barX1, listBottom, area.x2 - metrics.edgeInset, listTop, rowMetrics.totalH, scrollOffset())
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

-- The list again, from the model's blocks (gameinfo_model.rebuildRows): the column, the search
-- box and the changed-only toggle pick its rows.
rebuildRows = function()
	model.rebuildRows(searchBox and searchBox:getText())
	-- The selection is a span of row numbers, and these are now different rows.
	clearSelection()
	unitStrip.layout()
	clampScroll()
end

----------------------------------------------------------------
-- Layout
----------------------------------------------------------------

-- The category column starts below where the rows do, so the title above it is not
-- crowded by the first entry. Everything in the column measures from here.
local function sidebarTop()
	return metrics.bandTop - metrics.sidebarDrop
end

-- How many entries the column has room for, and how far it can be scrolled.
local function catPageRows()
	return mathMax(1, mathFloor((sidebarTop() - listBottom) / metrics.catRowHeight))
end

-- `i` is the entry's place in `categories`, not its place on screen: the two differ by
-- however far the column is scrolled.
local function categoryRect(i)
	local top = sidebarTop() - (i - 1 - catScroll) * metrics.catRowHeight
	-- The right edge gives way to the bar when there is one. Without that the count reads
	-- right up against it and the hover plate runs underneath it, which looks like the
	-- plate is behind the bar rather than the bar being beside the row.
	local right = area.x1 + metrics.sidebarW
	if #model.categories > catPageRows() then
		right = right - metrics.catInset - metrics.catBarW - metrics.catInset
	end

	return area.x1, top - metrics.catRowHeight, right, top
end

-- The category entry under x,y, or nil. Half-open on the shared edge, like the rows, so
-- one point never lands in two entries.
local function sidebarIndexAt(x, y)
	local top = sidebarTop()
	if x < area.x1 or x > area.x1 + metrics.sidebarW or y > top or y <= listBottom then
		return nil
	end

	local i = mathFloor((top - y) / metrics.catRowHeight) + 1 + catScroll
	if not model.categories[i] then
		return nil
	end

	local _, y1 = categoryRect(i)
	if y1 < listBottom then
		return nil
	end

	return i
end

local function maxCatScroll()
	return mathMax(0, #model.categories - catPageRows())
end

local function setCatScroll(n)
	local m = maxCatScroll()
	catScroll = (n < 0 and 0) or (n > m and m) or n
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
	metrics.catRowHeight = mathFloor(29 * s)
	metrics.rowFs = mathFloor(metrics.rowHeight * 0.55)
	metrics.headerRowHeight = mathFloor(metrics.rowHeight * 1.35)
	metrics.headerFs = mathFloor(metrics.rowFs * 0.95 * 1.13)
	metrics.catFs = mathFloor(metrics.catRowHeight * 0.55 * 0.85)
	metrics.codeRowHeight = mathFloor(metrics.rowHeight * 0.78)
	metrics.codeFs = mathFloor(metrics.codeRowHeight * 0.62)
	metrics.iconTop = mathMax(1, mathFloor(6 * s))
	metrics.iconBottom = mathMax(1, mathFloor(3 * s))
	metrics.iconSize = metrics.codeRowHeight * 3 - metrics.iconTop - metrics.iconBottom
	-- Small enough to sit on a single row, with the same air above and below it.
	metrics.tinyIcon = metrics.codeRowHeight - mathMax(2, mathFloor(4 * s))
	metrics.underlineH = mathMax(1, mathFloor(2 * s))
	metrics.accentW = mathMax(2, mathFloor(3 * s))
	metrics.rowPad = mathFloor(6 * s)
	metrics.sidePad = mathFloor(12 * s)
	metrics.catInset = mathFloor(4 * s)
	metrics.edgeInset = mathFloor(4 * s)
	metrics.headerH = mathFloor(34 * s)
	metrics.headerGap = mathFloor(4 * s)
	metrics.listGap = mathFloor(12 * s)
	metrics.cardLip = mathFloor(5 * s)
	metrics.titleY = mathFloor(17 * s)
	metrics.titleFs = mathFloor(metrics.rowHeight * 0.85)
	metrics.sidebarDrop = mathFloor(8 * s)
	metrics.sidebarW = mathFloor(240 * s)
	metrics.stripPad = mathMax(2, mathFloor(6 * s))
	metrics.stripGap = mathMax(2, mathFloor(8 * s))
	metrics.stripMin = mathMax(8, mathFloor(12 * s))
	metrics.barW = mathFloor(14 * s)
	metrics.catBarW = mathMax(3, mathFloor(6 * s))
	-- Rounded like the settings panel's inner elements, which take a share of this too.
	metrics.csPanel = mathFloor(elementCorner)
	metrics.csSmall = mathFloor(elementCorner * 0.66)

	listX1 = area.x1 + metrics.sidebarW + metrics.listGap
	metrics.bandTop = area.y2 - metrics.headerH - metrics.headerGap
	listTop = metrics.bandTop
	listBottom = area.y1 + metrics.edgeInset
	-- The scrollbar owns a column of its own: its right edge lines up with the toggle
	-- above it, and the rows stop a clear gap short of it rather than running up against
	-- it, so the bar sits in a channel rather than hugging them.
	barX1 = area.x2 - metrics.edgeInset - metrics.barW
	listRight = barX1 - metrics.listGap
	valueX1 = listX1 + mathFloor((listRight - listX1) * 0.55)

	-- The header band: the search field takes the width the filter toggle leaves it.
	local rowTop = area.y2 - mathFloor(4 * s)
	local rowBottom = area.y2 - metrics.headerH + mathFloor(4 * s)
	local fs = mathFloor((rowTop - rowBottom) * 0.5)
	local togW = mathFloor(38 * s)
	local togH = mathFloor((rowTop - rowBottom) * 0.62)
	local togY = mathFloor((rowTop + rowBottom) * 0.5)
	local togX2 = area.x2 - metrics.edgeInset
	toggleDraw = { togX2 - togW, togY - mathFloor(togH * 0.5), togX2, togY - mathFloor(togH * 0.5) + togH }
	-- Measured at the size it is drawn at, not at the header's: the rect below is built off
	-- this, and a caption measured at one size and drawn at another puts it out by whatever
	-- the two happen to differ by.
	metrics.toggleFs = mathFloor(metrics.rowFs * 1.05)
	local labelW = font and mathFloor(font:GetTextWidth(L.changedOnly) * metrics.toggleFs) or mathFloor(90 * s)
	-- Outlined text spreads past the box it is measured in: gui_fonthandler builds the faces
	-- with an outline of 0.22 * 0.9 of the em, so the caption's first glyph already sits that
	-- much left of where its advance box starts. The toggle at the other end has no such
	-- bleed, so matching the two boxes does not read as matching - this buys the caption side
	-- back the room its outline took.
	metrics.captionBleed = mathFloor(metrics.toggleFs * 0.2 + 0.5)
	-- The caption is part of the control: a toggle this small is a poor click target on its
	-- own, and the words beside it are what names the thing being switched. This is also what
	-- the hover paints, so it keeps the same room in front of the caption as it does after
	-- the toggle, rather than opening wider on one side than the other.
	toggleHit = {
		toggleDraw[1] - metrics.rowPad * 2 - labelW - metrics.captionBleed,
		rowBottom,
		togX2 + metrics.rowPad,
		rowTop,
	}
	-- Wider than the gaps inside the control, so the caption reads as belonging to the
	-- toggle beside it rather than to the field it would otherwise sit against.
	searchBox:setRect(listX1, rowBottom, toggleHit[1] - mathFloor(28 * s), rowTop, fs)

	setCatScroll(catScroll)
	layoutGen = layoutGen + 1
	-- The strip is sized to the list's width, and where the list starts depends on it.
	unitStrip.layout()
	clampScroll()
end

-- The tweaks' source as code rows for the list's width (gameinfo_model.layoutCode).
local function layoutCodeBlocks()
	if not fontMono then
		return
	end

	local charW = mathMax(1, fontMono:GetTextWidth("0") * metrics.codeFs)
	model.layoutCode({
		charW = charW,
		column = listRight - listX1 - metrics.rowPad * 4,
		iconSize = metrics.iconSize,
		ownerChars = metrics.ownerChars,
		-- What the picture after a buildoptions entry takes out of its line, gap included.
		optionChars = mathFloor((metrics.tinyIcon + metrics.rowPad * 2) / charW) + 1,
	})
end

-- Category labels, shortened to the column and carrying their colour codes, so the
-- sidebar draws them as they are. Redone when the column resizes.
local function fitCategories()
	for _, c in ipairs(model.categories) do
		-- How much of what the category lists is not the way the game ships, in the colour an
		-- adjusted value takes in the list itself. The count is never shortened and the label
		-- gives way to it: half a number says nothing, while a shortened name still does.
		local count = (c.changes or 0) > 0 and tostring(c.changes) or nil
		c.countText = count and (colorValueOn .. count) or nil
		local countW = count and (mathFloor(font:GetTextWidth(count) * metrics.catFs) + metrics.rowPad) or 0

		local fitted = text.fit(font, c.label, metrics.sidebarW - metrics.sidePad * 2 - countW, metrics.catFs)
		-- A category holding a tweak the game refused stays red whether it is the selected
		-- one or not: it is a warning, not a state of the column.
		c.textSel = (c.failed and colorDanger or colorSelected) .. fitted
		c.textDim = (c.failed and colorDanger or colorDim) .. fitted
		c.fitGen = layoutGen
	end
end

-- A row's text, shortened to the columns it is drawn in and coloured for whether its
-- value is the default one. Cached against the layout, so a resize measures it again and
-- a scroll does not.
local function fitRow(row)
	-- The owner prefix comes and goes with the search while the layout stands still, so it
	-- is part of what the cached text was built for.
	local owner = row.needsOwner and true or false
	if row.fitGen == layoutGen and row.fitOwner == owner then
		return
	end
	row.fitGen, row.fitOwner = layoutGen, owner

	if row.type == "header" then
		row.fitName = (row.failed and colorDanger or colorHeader)
			.. text.fit(font, row.name, listRight - listX1 - metrics.rowPad * 2, metrics.headerFs)
	elseif row.type == "code" then
		-- Already coloured token by token, and already cut to the column, when the source was
		-- wrapped in this same layout pass. A failure overrides the highlighting: it has to
		-- read as something that did not work, not as source that did.
		row.fitName = row.failed and (colorDanger .. row.plain) or row.name
		if owner then
			-- The column this goes in was taken out of the wrap budget, so the source beside
			-- it still ends where every other line of the block does.
			row.fitName = model.codeColors.call .. row.ownerLabel .. row.fitName
		end
		if row.optionUnitDefID and fontMono then
			-- Measured rather than counted: the note in the comment is translated, and a
			-- character count is only a width while every character is one byte.
			local shown = owner and (row.ownerLabel .. row.plain) or row.plain
			row.optionX = listX1
				+ metrics.rowPad * 4
				+ (row.gutter or 0)
				+ mathFloor(fontMono:GetTextWidth(shown) * metrics.codeFs + 0.5)
		end
	else
		-- Map and engine facts are neither adjusted nor left at a default, so they take the
		-- plain reading colour rather than either of the two the options are told apart by.
		local valueColor = colorInfo
		if row.type == "option" then
			valueColor = row.changed and colorValueOn or colorValue
		end
		row.fitName = (row.changed and colorNameOn or colorName)
			.. text.fit(font, row.name, valueX1 - listX1 - metrics.rowPad * 3, metrics.rowFs)
		local valueW = listRight - valueX1 - metrics.rowPad * 2
		if row.default then
			-- The default leads, dimmed, as the value it was changed from. It gives up its room
			-- first: what the game runs with is the half that has to stay readable.
			local default = text.fit(font, row.default, mathFloor(valueW * 0.4), metrics.rowFs)
			local leadW = font:GetTextWidth(default .. defaultArrow) * metrics.rowFs
			row.fitValue = colorDim
				.. default
				.. defaultArrow
				.. valueColor
				.. text.fit(font, row.value, valueW - leadW, metrics.rowFs)
		else
			row.fitValue = valueColor .. text.fit(font, row.value, valueW, metrics.rowFs)
		end
	end
end

-- The block a buildoptions picture under x,y jumps to, as the row it starts on, or nil. Only
-- a unit the list itself shows a block for can be jumped to; one in the same tweak slot as
-- the line is preferred over the same unit in another.
function unitStrip.optionAt(x, y)
	local r = rowAt(y)
	local row = r and model.rows[scroll + r]
	if not (row and row.optionUnitDefID) then
		return nil
	end

	fitRow(row)
	local x1 = row.optionX
	if not x1 or x < x1 or x > x1 + metrics.tinyIcon then
		return nil
	end

	local id = row.optionUnitDefID
	local inBlock = unitStrip.blockRows and unitStrip.blockRows[row.srcBlock]

	return (inBlock and inBlock[id]) or (unitStrip.anyRow and unitStrip.anyRow[id])
end

-- Where the picture of a block's opening row goes, given that row's edges: left, top and
-- size. Full size over three rows of its block, two rows tall over two, and the small
-- single-row picture over one - always against the right of the column, where the full one
-- ends, so they line up whatever size each came out at.
function unitStrip.pictureFor(row, top, bottom)
	local right = listX1 + metrics.rowPad + (row.gutter or metrics.iconSize)
	local k = row.pictureRows or 3
	if k >= 3 then
		return right - metrics.iconSize, top - metrics.iconTop, metrics.iconSize
	elseif k == 2 then
		local size = metrics.codeRowHeight * 2 - metrics.iconTop - metrics.iconBottom
		return right - size, top - metrics.iconTop, size
	end

	local size = metrics.tinyIcon
	return right - size, mathFloor(mathFloor((top + bottom) * 0.5) + size * 0.5), size
end

-- Whether x,y is in the picture column down the left of a tweakunits block, and the unit
-- whose picture is under it when there is one. The column belongs to the pictures, not the
-- source, so nothing in it selects.
function unitStrip.gutterAt(x, y)
	local r = rowAt(y)
	local row = r and model.rows[scroll + r]
	local gutter = row and row.type == "code" and row.gutter or 0
	if gutter <= 0 or x < listX1 or x >= listX1 + metrics.rowPad * 2 + gutter then
		return false
	end

	local x1 = listX1 + metrics.rowPad
	-- The small picture a search puts against the right of the column, on its own row.
	if row.needsOwner and x >= x1 + gutter - metrics.tinyIcon and x <= x1 + gutter then
		return true, row.ownerUnitDefID
	end
	-- A block's picture hangs from its opening row over the rows under it, so it is found by
	-- looking up from the hovered row for that opening, as far as a picture reaches.
	local base = scrollOffset()
	local reach = mathFloor((metrics.iconTop + metrics.iconSize) / mathMax(1, metrics.codeRowHeight)) + 1
	for i = scroll + r, mathMax(scroll + 1, scroll + r - reach), -1 do
		local above = model.rows[i]
		if above.unitDefID then
			local top = listTop - (above.off - base)
			local px, py, size = unitStrip.pictureFor(above, top, top - rowHeightOf(above))
			if x >= px and x <= px + size and y <= py and y >= py - size then
				return true, above.unitDefID
			end

			return true
		end
	end

	return true
end

----------------------------------------------------------------
-- Drawing
----------------------------------------------------------------

-- Geometry drawn between font:Begin and font:End interleaves with the font's batched
-- glyphs and makes both flicker. The list alternates shapes and text row by row, so it
-- queues here and flushes once all the shapes are down. Held flat and refilled in place,
-- since a table per string per frame is hundreds of allocations a second.
local pending = { {}, {} }
local pendingCount = { 0, 0 }

-- The unit pictures are not baked with the rest of the panel: they bind a texture apiece,
-- and a display list is the wrong place for that. The rows note where each one goes while
-- the panel is baked, and the draw below replays those positions live - which is correct
-- for as long as the baked panel is, since anything that moves a row rebuilds both.
local pendingIcons = {}
local iconCount = 0

local function queueIcon(unitDefID, x, y, size, zoom, hot)
	local at = iconCount * 6
	pendingIcons[at + 1] = x
	pendingIcons[at + 2] = y
	pendingIcons[at + 3] = unitDefID
	-- Its own size: a block opens with a picture three rows tall, while a line a search
	-- pulled out of one carries a picture small enough to sit on that line.
	pendingIcons[at + 4] = size
	pendingIcons[at + 5] = zoom or iconZoom.idle
	-- The zoom a picture takes while hovered, or false. Only pictures that can be clicked are
	-- ever given one.
	pendingIcons[at + 6] = hot or false
	iconCount = iconCount + 1
end

-- Drawn the way the build menu draws its own cells, at the zoom it uses for an idle one.
local function drawIcons()
	if iconCount == 0 then
		return
	end

	-- A picture is three rows tall and hangs off a row that can be the last one the band had
	-- room for, so the band is what it is allowed to paint in.
	-- Up to the top of the band rather than of the list, which takes in the strip over it; the
	-- list's own pictures only ever hang downwards, so they cannot reach up into it.
	gl.Scissor(listX1, listBottom, area.x2 - listX1, metrics.bandTop - listBottom)
	for i = 0, iconCount - 1 do
		local at = i * 6
		local x, y, size = pendingIcons[at + 1], pendingIcons[at + 2], pendingIcons[at + 4]
		local hot = pendingIcons[at + 6]
		local texture = "#" .. pendingIcons[at + 3]
		-- Before every one of them, the way the build menu does it: the frame Draw.Unit lays
		-- over the picture is a gradient, and it leaves its last colour behind. Setting white
		-- once outside the loop leaves every picture after the first modulated by that.
		glColor(1, 1, 1, 1)
		UiUnit(x, y - size, x + size, y, nil, 1, 1, 1, 1, hot or pendingIcons[at + 5], nil, nil, texture)
		if hot then
			-- The build menu's hover: zoomed in, and brightened by a second pass of the same
			-- picture, so a picture that can be clicked answers the cursor the way a cell does.
			gl.Blending(GL.DST_ALPHA, GL.ONE_MINUS_SRC_COLOR)
			glColor(0.63, 0.63, 0.63, 0)
			glTexture(texture)
			UiUnit(x, y - size, x + size, y, nil, 1, 1, 1, 1, hot)
			glTexture(false)
			gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
		end
	end
	gl.Scissor(false)
	glColor(1, 1, 1, 1)
end

local function queueText(str, x, y, size, opts, which)
	local n = pendingCount[which]
	local at = n * 5
	local list = pending[which]
	list[at + 1] = str
	list[at + 2] = x
	list[at + 3] = y
	list[at + 4] = size
	list[at + 5] = opts
	pendingCount[which] = n + 1
end

local function flushText(which, face)
	local n = pendingCount[which]
	if n == 0 then
		return
	end

	local list = pending[which]
	face:Begin()
	for i = 0, n - 1 do
		local at = i * 5
		face:Print(list[at + 1], list[at + 2], list[at + 3], list[at + 4], list[at + 5])
	end
	face:End()

	pendingCount[which] = 0
end

-- The band a category heading sits on: the sheen and the line closing it off underneath,
-- so the heading closes off the block above it rather than floating in the middle.
local function drawHeaderBand(top, bottom, caption, failed)
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
		failed and look.failedLine or look.headerLine,
		failed and look.failedLineFade or look.headerLineFade
	)
	queueText(caption, listX1 + metrics.rowPad, mathFloor((top + bottom) * 0.5), metrics.headerFs, "ov", 1)
end

local function drawRow(row, top, bottom, hovered, selected)
	fitRow(row)
	local cy = mathFloor((top + bottom) * 0.5)

	if row.type == "header" then
		drawHeaderBand(top, bottom, row.fitName, row.failed)
		return
	end

	if row.type == "code" then
		if row.failed then
			RectRound(listX1, bottom, listRight, top, metrics.csSmall, 1, 1, 1, 1, look.failedFill)
			RectRound(listX1, bottom, listX1 + metrics.accentW, top, 0, 0, 0, 0, 0, look.failedAccent)
		end
		if selected then
			-- Stops short of the pictures. The gutter belongs to them, and a band running
			-- under one would read as though the unit were selected rather than the lines
			-- beside it; flush against the picture it would read as part of its frame, so it
			-- keeps the same gap from it that it leaves before the source.
			local gutter = row.gutter or 0
			RectRound(
				listX1 + (gutter > 0 and metrics.rowPad * 2 + gutter or 0),
				bottom,
				listRight,
				top,
				0,
				0,
				0,
				0,
				0,
				look.codeSelectedFill
			)
		end
		if row.unitDefID then
			local px, py, size = unitStrip.pictureFor(row, top, bottom)
			queueIcon(row.unitDefID, px, py, size)
		elseif row.needsOwner then
			-- Against the right of the gutter, so it reads as belonging to the name it is in
			-- front of rather than floating out at the panel edge.
			local size = metrics.tinyIcon
			queueIcon(
				row.ownerUnitDefID,
				listX1 + metrics.rowPad + (row.gutter or 0) - size,
				mathFloor(cy + size * 0.5),
				size
			)
		end
		if row.optionX then
			local size = metrics.tinyIcon
			queueIcon(
				row.optionUnitDefID,
				row.optionX,
				mathFloor(cy + size * 0.5),
				size,
				iconZoom.option,
				hovered and hover.option > 0 and iconZoom.optionHover
			)
		end
		queueText(row.fitName, listX1 + metrics.rowPad * 3 + (row.gutter or 0), cy, metrics.codeFs, "ov", 2)

		return
	end

	if row.changed then
		RectRound(listX1, bottom, listRight, top, metrics.csSmall, 1, 1, 1, 1, look.changedFill)
		RectRound(listX1, bottom, listX1 + metrics.accentW, top, 0, 0, 0, 0, 0, look.changedAccent)
	end
	if hovered then
		Highlight(listX1, bottom, listRight, top, metrics.csSmall, look.rowHoverOpacity, look.white)
	end

	-- Indented past the accent bar and under the heading above them, so the block reads as
	-- a group rather than as rows that happen to follow a caption.
	queueText(row.fitName, listX1 + metrics.rowPad * 2, cy, metrics.rowFs, "ov", 1)
	queueText(row.fitValue, valueX1, cy, metrics.rowFs, "ov", 1)
end

-- Whole rows only: the band can end mid-row, and a row painted below it would be clipped
-- by nothing.
local function drawRows()
	local base = scrollOffset()
	local selLow, selHigh = selectionRange()
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
		drawRow(row, top, bottom, hover.row == i, selLow and scroll + i >= selLow and scroll + i <= selHigh)
	end
end

-- The category column: its own card under the title, then one entry per category.
local function drawSidebar()
	-- Derived from the first category rather than measured from the panel top, so the card
	-- keeps its lip above the entries wherever the column starts.
	RectRound(
		area.x1,
		area.y1,
		area.x1 + metrics.sidebarW,
		sidebarTop() + metrics.cardLip,
		metrics.csPanel,
		1,
		1,
		1,
		1,
		look.sidebarFill,
		look.sidebarFillTop
	)
	queueText(L.titleText, area.x1 + metrics.sidePad, area.y2 - metrics.titleY, metrics.titleFs, "ov", 1)

	if model.categories[1] and model.categories[1].fitGen ~= layoutGen then
		fitCategories()
	end

	for i = catScroll + 1, #model.categories do
		local c = model.categories[i]
		local x1, y1, x2, y2 = categoryRect(i)
		if y1 < listBottom then
			break
		end
		local selected = model.selectedCategory == c.key
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
		elseif i == hover.sb then
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
		local ty = mathFloor((y1 + y2) * 0.5)
		queueText(selected and c.textSel or c.textDim, x1 + metrics.sidePad, ty, metrics.catFs, "ov", 1)
		if c.countText then
			queueText(c.countText, x2 - metrics.sidePad, ty, metrics.catFs, "rov", 1)
		end
	end

	-- A bar of its own, and a slim one: the column is narrow and this only shows up when
	-- there are more categories than the card has room for.
	if maxCatScroll() > 0 then
		local bx2 = area.x1 + metrics.sidebarW - metrics.catInset
		-- Over the entries, not over the whole card: the last row rarely lands exactly on the
		-- bottom, and a bar running past it reads as a column with dead space at its foot -
		-- and makes the thumb say more fits than does.
		UiScroller(
			bx2 - metrics.catBarW,
			sidebarTop() - catPageRows() * metrics.catRowHeight,
			bx2,
			sidebarTop(),
			#model.categories * metrics.catRowHeight,
			catScroll * metrics.catRowHeight
		)
	end
end

-- The filter toggle and its caption. The search field draws itself, live, so its caret
-- can blink without the panel being baked again every frame.
local function drawHeader()
	-- The plate goes behind the switch and the switch lights itself, rather than the plate
	-- being laid over it: at the plate's opacity the switch has one of its own bright enough
	-- to swallow it, and painting over the switch only dulls it.
	if hover.tog == 1 then
		Highlight(
			toggleHit[1],
			toggleHit[2],
			toggleHit[3],
			toggleHit[4],
			metrics.csSmall,
			look.rowHoverOpacity,
			look.white
		)
	end
	UiToggle(toggleDraw[1], toggleDraw[2], toggleDraw[3], toggleDraw[4], model.changedOnly, hover.tog == 1)
	queueText(
		(model.changedOnly and colorSelected or colorDim) .. L.changedOnly,
		toggleDraw[1] - metrics.rowPad,
		mathFloor((toggleHit[2] + toggleHit[4]) * 0.5),
		metrics.toggleFs,
		"rov",
		1
	)
end

-- The unit strip: its own card over the list, the way the category column has one, with the
-- pictures queued onto it to be drawn live with the rest.
function unitStrip.draw()
	local s = unitStrip
	if s.count == 0 then
		return
	end

	RectRound(listX1, s.bottom, listRight, s.top, metrics.csPanel, 1, 1, 1, 1, look.sidebarFill, look.sidebarFillTop)

	local step = s.size + s.gap
	for i = 1, s.count do
		local line = mathFloor((i - 1) / s.cols)
		-- A line the strip's height was capped short of.
		if (line + 1) * step - s.gap > s.h then
			break
		end
		queueIcon(
			s.ids[i],
			s.x1 + (i - 1 - line * s.cols) * step,
			s.iconTop - line * step,
			s.size,
			iconZoom.strip,
			hover.strip == i and iconZoom.stripHover
		)
	end
end

-- Everything inside the panel: the column, the header controls, the list and the
-- scroller. Baked and replayed until the cursor, the list or the screen moves.
local function drawPanel()
	iconCount = 0
	drawSidebar()
	drawHeader()
	unitStrip.draw()
	drawRows()

	local base = scrollOffset()
	if rowMetrics.totalH > 0 then
		UiScroller(
			barX1,
			listBottom,
			area.x2 - metrics.edgeInset,
			listTop,
			rowMetrics.totalH,
			base,
			hover.bar == 1,
			dragging
		)
	end

	flushText(1, font)
	flushText(2, fontMono)

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
	if windowList then
		glDeleteList(windowList)
		windowList = nil
	end
end

local function deleteGuishader()
	if backgroundGuishader ~= nil then
		if WG.guishader then
			WG.guishader.DeleteDlist("gameinfo")
		else
			glDeleteList(backgroundGuishader)
		end
		backgroundGuishader = nil
	end
end

-- Reads the hover state and answers a signature of everything the baked panel is painted
-- from. Same signature, same picture, so the display list is replayed as it is.
local function panelSignature(mx, my)
	hover.sb = sidebarIndexAt(mx, my) or 0
	hover.row = 0
	hover.tog = 0
	hover.bar = 0
	hover.strip = unitStrip.indexAt(mx, my) or 0
	hover.option = 0

	if toggleHit[1] and math_isInRect(mx, my, toggleHit[1], toggleHit[2], toggleHit[3], toggleHit[4]) then
		hover.tog = 1
	elseif mx >= listX1 and mx <= listRight then
		hover.row = rowAt(my) or 0
		hover.option = (hover.row > 0 and unitStrip.optionAt(mx, my)) and 1 or 0
	elseif mx >= barX1 and mx <= area.x2 then
		-- The thumb itself, not the track: it is the part that can be taken hold of, so it
		-- is the part that lights up.
		local top, height = scrollerThumb()
		if top and my <= top and my >= top - height then
			hover.bar = 1
		end
	end

	return hover.sb
		.. "|"
		.. hover.row
		.. "|"
		.. hover.tog
		.. "|"
		.. hover.bar
		.. "|"
		.. hover.strip
		.. "|"
		.. hover.option
		.. "|"
		.. scroll
		.. "|"
		.. model.rowsGen
		.. "|"
		.. layoutGen
		.. "|"
		.. catScroll
		.. "|"
		.. selFrom
		.. "|"
		.. selTo
		.. "|"
		.. (dragging and 1 or 0)
end

----------------------------------------------------------------
-- Callins
----------------------------------------------------------------

local function refreshContent()
	model.buildContent()
	layoutCodeBlocks()
	rebuildRows()
end

local function loadLabels()
	model.loadLabels()
	L.titleText = colorTitle .. L.title
end

function widget:ViewResize()
	vsx, vsy = spGetViewGeometry()
	widgetScale = (vsy / 1080)

	screenHeight = mathFloor(screenHeightOrg * widgetScale)
	screenWidth = mathFloor(screenWidthOrg * widgetScale)
	screenX = mathFloor((vsx * 0.5) - (screenWidth / 2))
	screenY = mathFloor((vsy * 0.5) + (screenHeight / 2))

	font = WG.fonts.getFont()
	-- Decoded tweaks are source, so they take the monospaced face the changelog gives code.
	fontMono = WG.fonts.getFont(3)
	elementCorner = WG.FlowUI.elementCorner

	RectRound = WG.FlowUI.Draw.RectRound
	UiElement = WG.FlowUI.Draw.Element
	UiScroller = WG.FlowUI.Draw.Scroller
	UiScrollerAt = WG.FlowUI.Draw.ScrollerGeometry
	Highlight = WG.FlowUI.Draw.SelectHighlight
	UiToggle = WG.FlowUI.Draw.Toggle
	UiUnit = WG.FlowUI.Draw.Unit

	if not searchBox then
		searchBox = Editbox.new({
			placeholder = L.search,
			clearable = true,
			onChange = function()
				setScroll(0)
				rebuildRows()
			end,
		})
	end

	setLayout()
	-- The code column moved, so how much of a source line fits it did too.
	layoutCodeBlocks()
	rebuildRows()
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

	if selecting then
		if lmb then
			-- Only over source: dragging off the end of a snippet holds the selection where it
			-- was rather than reaching into whatever block follows.
			local r = rowAt(my)
			local row = r and model.rows[scroll + r]
			if row and row.type == "code" then
				selTo = scroll + r
			end
		else
			selecting = false
		end
	end

	local sig = panelSignature(show and mx or -1, show and my or -1)
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
	glCallList(windowList)
	glCallList(panelList)
	drawIcons()
	if show then
		searchBox:draw()
	end

	if WG.guishader and backgroundGuishader == nil then
		backgroundGuishader = glCreateList(function()
			RectRound(screenX, screenY - screenHeight, screenX + screenWidth, screenY, elementCorner, 1, 1, 1, 1)
		end)
		WG.guishader.InsertDlist(backgroundGuishader, "gameinfo", nil, widget)
	end
	showOnceMore = false

	if math_isInRect(mx, my, screenX, screenY - screenHeight, screenX + screenWidth, screenY) then
		Spring.SetMouseCursor("cursornormal")

		local row = hover.row > 0 and model.rows[scroll + hover.row]
		local inGutter, gutterUnit = false, nil
		if row then
			inGutter, gutterUnit = unitStrip.gutterAt(mx, my)
		end
		-- A picture on its own does not say which unit it is to anyone who does not know the
		-- art, so every one of them names its unit and says what it is. Not the def name: the
		-- source beside it already spells that out.
		local unit = (hover.strip > 0 and unitStrip.ids[hover.strip])
			or (hover.option > 0 and row and row.optionUnitDefID)
			or gutterUnit
		-- Source says how to take it somewhere else, since nothing about a row of it looks
		-- like something you could drag across. Not over the picture column, which does not
		-- select.
		local tip = row and not inGutter and (row.tooltip or (row.type == "code" and L.copyHint))
		if unit and WG.tooltip then
			local def = UnitDefs[unit]
			WG.tooltip.ShowTooltip(
				"gameinfo",
				"\255\240\240\240" .. (def.translatedTooltip or ""),
				nil,
				nil,
				def.translatedHumanName
			)
		elseif tip and WG.tooltip then
			WG.tooltip.ShowTooltip("gameinfo", tip.text, nil, nil, tip.title)
		end
	end
end

local function closePanel()
	show = false
	clearSelection()
	if searchBox then
		searchBox:blur()
	end
	if WG.tooltip then
		WG.tooltip.RemoveTooltip("gameinfo")
	end
end

-- Keys are only taken while the search field has focus. This is a panel to read, not one
-- to edit in, so leaving it open must not cost the player their hotkeys - unlike the
-- keybind editor, which has to swallow everything because it is editing the binds.
function widget:KeyPress(key)
	if not show then
		return false
	end

	-- Escape, before the field gets a look at it: it undoes the most recent thing first
	-- and closes the panel only when there is nothing left to undo. The selection is the
	-- thing most recently picked up, and closing over it would throw away what was about
	-- to be copied. A search comes next: the list being read is the one the search made,
	-- and the first Escape is asking for that back rather than for the panel to go.
	if key == 27 then
		if selectionRange() then
			clearSelection()
		elseif searchBox:getText() ~= "" then
			-- Focus stays, so the next thing typed starts a new search.
			searchBox:setText("")
		else
			showOnceMore = true
			closePanel()
		end

		return true
	end

	if searchBox:isFocused() then
		searchBox:keyPress(key)

		return true
	end

	-- Copy and select-all are taken only while there is source selected, which is also the
	-- only time this panel owns the keyboard. Both are bound to something in the shipped
	-- profiles - Ctrl+C focuses the commander - so without that ownership the action handler
	-- would have had them first.
	local _, ctrl = Spring.GetModKeyState()
	if ctrl and (key == KEY_C or key == KEY_A) then
		local took = key == KEY_C and copySelection() or (key == KEY_A and selectAllCode())
		if took then
			consumedKeys[key] = true

			return true
		end
	end

	return false
end

-- The engine runs bound actions on release as well as on press, so a release has to be
-- swallowed wherever its press was. A key already down when the field took focus is let
-- through instead, or whatever it started stays stuck on.
function widget:KeyRelease(key)
	-- A shortcut taken on the way down has to be taken on the way up too, or the action it
	-- was bound to fires its release half anyway.
	if consumedKeys[key] then
		consumedKeys[key] = nil

		return true
	end

	if not show or not searchBox:isFocused() then
		return false
	end

	if heldAtFocus[key] then
		heldAtFocus[key] = nil

		return false
	end

	return true
end

function widget:TextInput(utf8char)
	if show and searchBox:isFocused() then
		return searchBox:textInput(utf8char)
	end

	return false
end

-- Swallowed across the whole panel, not just the list: a wheel that gets through zooms
-- the camera behind it.
function widget:MouseWheel(up, _value)
	if not show then
		return false
	end

	local x, y = spGetMouseState()
	if not math_isInRect(x, y, screenX, screenY - screenHeight, screenX + screenWidth, screenY) then
		return false
	end

	-- Over the column it scrolls the column, over anything else the list. A wheel that
	-- moved the list while the cursor was on the categories would read as broken.
	if x <= area.x1 + metrics.sidebarW and y > listBottom and y <= sidebarTop() then
		setCatScroll(catScroll + (up and -1 or 1))
	else
		-- The chat history's modifiers: Ctrl moves three notches' worth at once, Shift a whole
		-- page - the rows the band holds from where the list is now, since they are not all
		-- the same height.
		local _, ctrl, _, shift = Spring.GetModKeyState()
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

local function selectCategory(key)
	if model.selectedCategory == key then
		return
	end
	model.selectedCategory = key
	setScroll(0)
	rebuildRows()
	if playSounds then
		Spring.PlaySoundFile(buttonclick, 0.6, "ui")
	end
end

-- Clicks inside the panel go to the field, the toggle, the column or the scrollbar; a
-- press outside closes it.
local function mouseEvent(x, y, button, release)
	if spIsGUIHidden() then
		return false
	end

	if not show then
		return false
	end

	-- A press on a top bar button is the top bar's to handle: it closes the open windows
	-- and opens the one that was clicked. Closing (and consuming) here would swallow it.
	if WG.topbar and WG.topbar.buttonAt and WG.topbar.buttonAt(x, y) then
		return false
	end

	if math_isInRect(x, y, screenX, screenY - screenHeight, screenX + screenWidth, screenY) then
		if not release and button == 1 then
			if searchBox:mousePress(x, y) then
				clearSelection()
			else
				searchBox:blur()

				local i = sidebarIndexAt(x, y)
				local unit = unitStrip.indexAt(x, y)
				if math_isInRect(x, y, toggleHit[1], toggleHit[2], toggleHit[3], toggleHit[4]) then
					clearSelection()
					model.changedOnly = not model.changedOnly
					setScroll(0)
					rebuildRows()
					if playSounds then
						Spring.PlaySoundFile(buttonclick, 0.6, "ui")
					end
				elseif i then
					selectCategory(model.categories[i].key)
				elseif unit then
					-- The unit's first row to the top of the list. The selection stays: this is
					-- only a scroll, the same as reaching the unit with the wheel would be.
					setScroll(unitStrip.rows[unit] - 1)
					if playSounds then
						Spring.PlaySoundFile(buttonclick, 0.6, "ui")
					end
				elseif math_isInRect(x, y, barX1, listBottom, area.x2, listTop) then
					-- The strip between the bar and the panel edge stays grabbable too. The
					-- selection survives it: scrolling to reach more of the source is part of
					-- selecting it, not a change of mind.
					grabScroller(y)
				elseif math_isInRect(x, y, listX1, listBottom, listRight, listTop) then
					-- Source is the only thing here worth taking elsewhere, so it is the only
					-- thing that selects; a press on any other row puts the selection down.
					local r = rowAt(y)
					local row = r and model.rows[scroll + r]
					local target = unitStrip.optionAt(x, y)
					if target then
						-- A buildoptions picture whose unit has a block here: the same jump the
						-- strip makes, and the selection is left alone for the same reason.
						setScroll(target - 1)
						if playSounds then
							Spring.PlaySoundFile(buttonclick, 0.6, "ui")
						end
					elseif unitStrip.gutterAt(x, y) then
						-- The picture column is not source, so a press in it selects nothing and
						-- puts down whatever was selected, like a press on any other row.
						clearSelection()
					elseif row and row.type == "code" then
						selFrom, selTo = scroll + r, scroll + r
						selecting = true
					else
						clearSelection()
					end
				end
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

function widget:MouseRelease(x, y, button)
	return mouseEvent(x, y, button, true)
end

-- Holds input ownership while the search field has focus, or while source is selected.
-- Text ownership is what puts this panel ahead of actionHandler, which otherwise runs
-- before every widget: it would fire the keybinds being typed over, and it has Ctrl+C.
function widget:Update()
	if show and searchBox and (searchBox:isFocused() or selectionRange()) then
		if not fieldHasInput then
			fieldHasInput = true
			heldAtFocus = Spring.GetPressedKeys and Spring.GetPressedKeys() or {}
			ownsInput = widgetHandler:OwnText()

			-- Chat has to be asked to let go, and toggling its input flag is the only public
			-- way to make it cancel. The flag goes straight back because gui_chat persists it,
			-- and a config save while the field is focused would leave chat input dead next
			-- launch.
			if not ownsInput and WG.chat and WG.chat.isInputActive and WG.chat.isInputActive() then
				WG.chat.setHandleInput(false)
				WG.chat.setHandleInput(true)
				ownsInput = widgetHandler:OwnText()
			end
		elseif not ownsInput then
			ownsInput = widgetHandler:OwnText()
		end

		-- Only once it is ours. Starting SDL text input for a field we never took, then
		-- stopping it again on the way out, is what kills that field.
		if ownsInput and not textInputStarted then
			textInputStarted = true
			if Spring.SDLStartTextInput then
				Spring.SDLStartTextInput()
			end
		end
	elseif fieldHasInput then
		fieldHasInput = false
		if ownsInput then
			ownsInput = false
			widgetHandler:DisownText()
		end
		if textInputStarted then
			textInputStarted = false
			if Spring.SDLStopTextInput then
				Spring.SDLStopTextInput()
			end
		end
	end
end

function widget:GamePreload()
	model.readReclaimable()
	refreshContent()
end

-- Single way in and out, so the action, the top bar and a keybind all open the panel the
-- same way: opening hands the other windows to the top bar to close first.
local function setShown(wanted)
	if not wanted then
		closePanel()

		return
	end

	if not show and WG.topbar then
		WG.topbar.hideWindows()
	end
	show = true
end

function widget:Initialize()
	loadLabels()
	widget:ViewResize()
	refreshContent()

	widgetHandler:AddAction("customgameinfo", function()
		setShown(not show)

		return true
	end, nil, "p")

	widgetHandler:AddAction("customgameinfo_close", function()
		if show then
			setShown(false)

			return true
		end
	end, nil, "p")

	-- lets the handler hide the rest of the interface while the panel is open
	widgetHandler:RegisterModalWindow(function()
		return show == true
	end)

	WG.gameinfo = {}
	WG.gameinfo.toggle = function(state)
		if state == nil then
			state = not show
		end
		setShown(state)
	end
	WG.gameinfo.isvisible = function()
		return show
	end
	-- amount of modoptions that aren't set to their default value
	WG.gameinfo.getChangedModoptionsCount = model.changedCount
end

function widget:Shutdown()
	if searchBox then
		searchBox:blur()
	end
	widgetHandler:DisownText()
	if ownsInput then
		ownsInput = false
		if Spring.SDLStopTextInput then
			Spring.SDLStopTextInput()
		end
	end
	dropLists()
	deleteGuishader()
	if WG.tooltip then
		WG.tooltip.RemoveTooltip("gameinfo")
	end
end

-- The changed-only filter is kept between games: someone who only wants to see what a lobby
-- adjusted wants that every time they open the panel, not only the first.
function widget:GetConfigData()
	return { changedOnly = model.changedOnly }
end

-- Runs before Initialize, so the first list built already honours it.
function widget:SetConfigData(data)
	if data and data.changedOnly ~= nil then
		model.changedOnly = data.changedOnly == true
	end
end

function widget:LanguageChanged()
	loadLabels()
	if searchBox then
		-- The field keeps the coloured placeholder it was built with; both have to go for
		-- the new language's wording to be the one drawn.
		searchBox.placeholder = L.search
		searchBox.placeholderShown = nil
	end
	refreshContent()
	widget:ViewResize()
end
