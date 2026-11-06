local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Widget Selector",
		desc = "Widget selection widget",
		author = "trepan, jK, Bluestone, Floris",
		date = "Jan 8, 2007",
		license = "GNU GPL, v2 or later",
		layer = -99999,
		handler = true,
		enabled = true,
	}
end

-- Laid out the way the game info panel and the keybind editor are: the same inset area,
-- the title in the top-left corner over a darker card holding the category column, a
-- search field and a filter toggle in the header band, a 14 px scrollbar in its own
-- channel against the right edge, and the actions along the bottom.
--
-- The categories come from the filename prefix every widget in the game already carries -
-- gui_, cmd_, unit_ and the rest - spelled out. A widget whose prefix is not one of them,
-- which is most of what a player writes themselves, falls into Other.
--
-- Anything that cannot be taken back without a reload asks first, in a modal that says
-- what it is about to do. Toggling a single widget is not one of those: it is reversible
-- by clicking again, and asking every time would make the panel unusable.

-- Shared with the keybind editor and the game info panel, which is where they were written.
local Dropdown = require("luaui/Include/keybind_dropdown")
local Editbox = require("luaui/Include/keybind_editbox")
local KEYSYMS = require("luaui/Include/keybind_keysyms")
local text = require("luaui/Include/keybind_text")
-- What the widgets are, how they are listed and what each control says. This file is the window on it.
local model = VFS.Include("luaui/Include/widget_selector/model.lua")
-- Wrapping every callin to time it is global and does not nest, so one thing owns it and
-- everything else reads what it measured. Subscribing is what puts the wrappers in, so
-- nothing is paid for until the column is switched on.
local profiling = require("luaui/Include/widget_profiling")

-- Localized functions for performance
local mathFloor = math.floor
local mathMax = math.max

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
local UiButton
---@type function
local UiScroller
---@type function
local UiScrollerAt
---@type function
local Highlight
---@type function
local UiToggle
local elementCorner
local font

local area = { x1 = 0, y1 = 0, x2 = 0, y2 = 0 }
-- Sizes derived from the scale, in one table rather than a local each, the way the two
-- panels this is modelled on hold theirs: this chunk is close to Lua's limit of 200.
local metrics = {
	rowHeight = 24,
	catRowHeight = 29,
	rowFs = 13,
	catFs = 13,
	rowPad = 6,
	sidePad = 12,
	catInset = 4,
	accentW = 3,
	edgeInset = 4,
	headerH = 34,
	headerGap = 4,
	footerH = 38,
	footerGap = 6,
	buttonGap = 6,
	listGap = 12,
	cardLip = 5,
	titleY = 17,
	titleFs = 20,
	sidebarDrop = 8,
	sidebarW = 240,
	barW = 14,
	wheelRows = 3,
	csSmall = 2,
	csPanel = 4,
	csButton = 3,
	toggleFs = 13,
	captionBleed = 3,
	-- Where the description starts, as a fraction of the list width. A widget's name is
	-- the thing being hunted for, so it gets the room; the description is context.
	descSplit = 0.42,
	-- And where it starts with the cost columns showing. Everything ahead of the name
	-- shifts right to make room for them while a fixed split would not, so the two columns
	-- come out of the name's width alone and the names start being cut. The split moves
	-- with them instead, giving back about half of what they took - half rather than all
	-- of it because the description is being cut by then too.
	descSplitCost = 0.47,
}
local look = {
	sidebarFill = { 0, 0, 0, 0.24 },
	sidebarFillTop = { 0, 0, 0, 0.16 },
	selectedFill = { 1, 1, 1, 0.13 },
	white = { 1, 1, 1 },
	rowHoverOpacity = 0.14,
	hoverOpacity = 0.14,
	-- A widget is in one of three states, and each is marked three ways at once - the
	-- switch in front of it, a band across the row and a bar down its left edge - so it
	-- still reads in a list being scrolled past quickly, where a change of text colour
	-- alone reads as noise.
	--
	-- Running: loaded and doing its job.
	activeFill = { 0.45, 0.95, 0.5, 0.1 },
	activeAccent = { 0.4, 0.95, 0.45, 0.95 },
	-- Enabled but not running: the config says load it and it is not loaded, so it errored
	-- out or its conditions were not met.
	pendingFill = { 1, 0.8, 0.35, 0.09 },
	pendingAccent = { 1, 0.78, 0.3, 0.9 },
	-- Asked for and it would not load. The same three marks the other states get, in the
	-- colour the panel uses for everything that has gone wrong.
	errorFill = { 1, 0.35, 0.35, 0.12 },
	errorAccent = { 1, 0.35, 0.35, 0.95 },
	buttonFill = { 0.18, 0.18, 0.18, 1 },
	-- Anything that cannot be undone without a reload. The same stops the keybind
	-- editor's destructive buttons use, so the two panels read alike.
	dangerFill = { 0.46, 0.1, 0.1, 1 },
	dangerFillHover = { 0.66, 0.14, 0.14, 1 },
	-- And the other half of that pair: an accept that saves something.
	confirmFill = { 0.17, 0.38, 0.21, 1 },
	confirmFillHover = { 0.24, 0.52, 0.29, 1 },
	scrim = { 0, 0, 0, 0.55 },
	-- The outline every string the panel prints is drawn with, set on every batch rather than
	-- inherited. The font objects are shared with every other widget, many of those set an
	-- outline and leave it set, and text baked into a display list keeps whatever outline was
	-- current when it was baked - so the panel's text went heavier and lighter as it re-baked.
	outline = { 0, 0, 0, 0.4 },
}
-- FlowUI's Button gradients from a bottom stop to a top one. Left to its defaults it
-- fades the fill up to a near-transparent white, which colours only the bottom edge and
-- washes the rest out to grey. Each fill becomes a darker bottom and itself on top
-- instead. Derived once per fill and kept: the pair is passed on every draw.
look.gradients = setmetatable({}, {
	__index = function(self, fill)
		local pair = {
			{ fill[1] * 0.55, fill[2] * 0.55, fill[3] * 0.55, fill[4] or 1 },
			{ fill[1], fill[2], fill[3], fill[4] or 1 },
		}
		self[fill] = pair

		return pair
	end,
})
look.groups, look.groupText = model.look.groups, model.look.groupText
look.emptyText, look.tip = model.look.emptyText, model.look.tip
-- The same colours faded, for a row that is off and a category the search left empty: both
-- are drawn quieter than the rest, and a square at full strength would undo that. Derived
-- once per colour and kept, like the gradients.
look.faded = setmetatable({}, {
	__index = function(self, color)
		local faded = { color[1], color[2], color[3], 0.55 }
		self[color] = faded

		return faded
	end,
})
-- How a row's name and its description read in each of the three states a widget can be
-- in. `pending` - enabled but not running - is warm, because nothing is actually
-- happening. One table rather than five locals: this chunk is at Lua's ceiling of 200.
look.rowText = {
	name = "\255\145\143\140",
	nameOn = "\255\248\248\248",
	namePending = "\255\255\210\135",
	desc = "\255\105\105\105",
	descOn = "\255\175\175\175",
}
local colorTitle = "\255\235\235\235"
local colorSelected = "\255\210\210\205"
local colorDim = "\255\160\160\160"
local colorText = "\255\235\235\235"
local tagColors, codeColors, cost = model.tagColors, model.codeColors, model.cost
local colorDanger = "\255\255\190\190"
-- And the other half of that pair: a press that turns something on rather than off.
local colorGood = "\255\190\255\190"
local L = model.L
local fav, filters, deps = model.fav, model.filters, model.deps
local sweep, dataView = model.sweep, model.dataView
local switches = model.switches
local rebuildRows, buildCategories = model.rebuildRows, model.buildCategories
local applySet, saveSet, deleteSet = model.applySet, model.saveSet, model.deleteSet
local factoryReset, toggleUserWidgets = model.factoryReset, model.toggleUserWidgets
local clearConfigData, clearDataWarning = model.clearConfigData, model.clearDataWarning
local showTooltip = model.showTooltip

local show, showOnceMore
local panelList, windowList, backgroundGuishader
local listTop, listBottom, listX1, listRight, descX1, barX1 = 0, 0, 0, 0, 0, 0
local switchX1, orderX1, nameX1, clearX1 = 0, 0, 0, 0
-- The sets block at the foot of the category column: a caption, the picker, and the
-- two buttons that make and unmake a set. It lives there rather than in the header
-- because the column already has the room and the header has none left.
local setsTop = 0
-- How far the category column is scrolled, in whole entries. The sets block below it
-- takes a fixed bite out of the card, so a game with enough widget prefixes - or a
-- short panel - can have more categories than there is room for.
local catScroll = 0
-- Declared here because the content is built before the layout that measures the column,
-- and rebuilding it can leave the column scrolled past its own end.
local setCatScroll
local layoutGen = 0
local scroll = 0
local dragging = false
local dragGrab = 0
---@type table
local searchBox
---@type table
-- The name field the save dialog puts up. Its own, rather than the search field: a
-- dialog must not disturb what was typed in the panel behind it.
local nameBox
---@type table
local setPicker

-- The buttons under the picker. Load and Delete need a set picked and are not drawn
-- without one; Save always has something to save.
local setButtons = {
	{ id = "loadset" },
	{ id = "saveset" },
	{ id = "deleteset" },
}
-- The open modal, or nil. `accept` is what the confirm button runs.
---@type table?
local dialog
local dialogOk, dialogCancel, dialogField = {}, {}, {}
-- The modal's own box, kept so the blur behind it can be placed without measuring
-- everything again.
local dialogBox = {}
-- The row a press landed on, by name and button. A click is a press and a release on
-- the same row: press one, slide off, let go, and nothing happens - the row under the
-- cursor at the end was never the one being clicked.
---@type string?
local pressedRow
local pressedButton = 0
local pressedOn

local hover = model.hover

-- FlowUI and the font handler are widgets too, and this one is inserted before them:
-- widgetHandler calls Initialize the moment a widget loads, so everything taken from
-- them is picked up on the first frame that has them rather than at Initialize, where
-- they do not exist yet. The old selector survived this by never doing arithmetic on
-- what it read; this one lays out against it, so it has to wait.
local uiBound = false

local setLayout

----------------------------------------------------------------
-- Rows and scrolling
----------------------------------------------------------------

local function pageRows()
	return mathMax(1, mathFloor((listTop - listBottom) / metrics.rowHeight))
end

local function maxScroll()
	return mathMax(0, #model.rows - pageRows())
end

local function clampScroll()
	local m = maxScroll()
	if scroll > m then
		scroll = m
	end
	if scroll < 0 then
		scroll = 0
	end
end

local function setScroll(n)
	scroll = n
	clampScroll()
end

-- The row under y, as an index into what is on screen, or nil. Half-open on the shared
-- edge so one point never lands in two rows.
local function rowAt(y)
	if y > listTop or y <= listBottom then
		return nil
	end
	local i = mathFloor((listTop - y) / metrics.rowHeight) + 1
	if not model.rows[scroll + i] then
		return nil
	end

	return i
end

local function scrollerThumb()
	return UiScrollerAt(
		barX1,
		listBottom,
		area.x2 - metrics.edgeInset,
		listTop,
		#model.rows * metrics.rowHeight,
		scroll * metrics.rowHeight
	)
end

-- Scrolls so the thumb's top sits where the cursor has dragged it. The offset taken at
-- the grab keeps this relative: the thumb moves with the cursor rather than centring
-- itself on it, so taking hold of it does not shift the list before the drag begins.
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

-- Takes hold of the bar. On the thumb that is a grab and the list stays put; on the track
-- either side the thumb jumps to the cursor first and is then dragged from its middle,
-- which is what a press on bare track is asking for.
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

-- The modal's box and its two buttons. Centred on the panel rather than the screen, so it
-- reads as belonging to what it is about to change.
local function dialogGeometry()
	local s = widgetScale
	local w = mathFloor(440 * s)
	local h = mathFloor(190 * s)
	local cx = mathFloor((area.x1 + area.x2) * 0.5)
	local cy = mathFloor((area.y1 + area.y2) * 0.5)
	local bx1, bx2 = cx - mathFloor(w * 0.5), cx + mathFloor(w * 0.5)
	local by1, by2 = cy - mathFloor(h * 0.5), cy + mathFloor(h * 0.5)
	local bw = mathFloor(130 * s)
	local bh = mathFloor(30 * s)
	local pad = mathFloor(16 * s)
	local by = by1 + pad

	dialogCancel = { bx1 + pad, by, bx1 + pad + bw, by + bh }
	dialogOk = { bx2 - pad - bw, by, bx2 - pad, by + bh }
	-- The name box sits between the message and the buttons, the full width of the box.
	dialogField = { bx1 + pad, by + bh + pad, bx2 - pad, by + bh + pad + mathFloor(30 * s) }
	dialogBox = { bx1, by1, bx2, by2 }

	return bx1, by1, bx2, by2
end

----------------------------------------------------------------
-- Actions
----------------------------------------------------------------

-- The picker's options, and which of them is showing. A set stops being the one that is
-- loaded the moment anything is toggled by hand, so the caption falls back to a
-- placeholder rather than naming a set the widgets no longer match.
local function refreshSets()
	if not setPicker then
		return
	end
	local names = {}
	local selected = 1
	for i = 1, #model.sets do
		names[i] = model.sets[i].name
		if model.sets[i].name == model.pickedSet then
			selected = i
		end
	end
	setPicker.placeholder = (not model.pickedSet or #names == 0) and L.noSet or nil
	-- With nothing saved there is nothing to pick, so the control does not light under the
	-- cursor and does not open: a list that drops open empty is worse than one that does not
	-- move at all.
	setPicker.disabled = #names == 0
	setPicker:setOptions(names)
	setPicker:setSelected(selected)
	-- Load and Delete come and go with the pick, and the block is a row shorter without
	-- them, so it has to be measured again.
	if uiBound then
		setLayout()
	end
end

-- The name the save dialog would use, and whether it is one at all. A set with no name
-- cannot be found again, so an empty field blocks the accept rather than saving one.
local function dialogName()
	if not (dialog and dialog.field and nameBox) then
		return nil, false
	end
	local name = nameBox:getText():gsub("^%s*(.-)%s*$", "%1")

	return name, name == ""
end

-- Where the window sits: most of the panel, since the whole point is to see a lot of it at
-- once, but inside it rather than over the screen - it belongs to the panel it was opened
-- from.
function dataView.geometry()
	local w = mathFloor(screenWidth * 0.6)
	local h = mathFloor(screenHeight * 0.8)
	local cx = mathFloor(screenX + screenWidth * 0.5)
	local cy = mathFloor(screenY - screenHeight * 0.5)
	local x1, y1 = cx - mathFloor(w * 0.5), cy - mathFloor(h * 0.5)
	dataView.rect[1], dataView.rect[2], dataView.rect[3], dataView.rect[4] = x1, y1, x1 + w, y1 + h

	local pad = mathFloor(14 * widgetScale)
	local bh = mathFloor(28 * widgetScale)
	local bw = mathFloor(110 * widgetScale)
	dataView.pad = pad
	dataView.close[1], dataView.close[2] = x1 + w - pad - bw, y1 + pad
	dataView.close[3], dataView.close[4] = x1 + w - pad, y1 + pad + bh

	-- The title takes a band of its own across the top, and the listing starts a whole line
	-- below it: the lines are drawn from their baselines, so one starting level with the
	-- bottom of the title band would have its ascenders run up into the title.
	dataView.titleFs = mathFloor(metrics.rowHeight * 0.72)
	dataView.titleY = y1 + h - pad - mathFloor(dataView.titleFs * 0.5)
	dataView.lineH = mathFloor(metrics.rowHeight * 0.62)
	dataView.fs = mathFloor(dataView.lineH * 0.78)
	dataView.top = y1 + h - pad - dataView.titleFs - dataView.lineH
	dataView.bottom = y1 + pad * 2 + bh
	dataView.page = mathFloor((dataView.top - dataView.bottom) / dataView.lineH) + 1

	-- The bar runs the height of the reading area, against the right edge. Same width as
	-- the list's, so the two read as the same control.
	dataView.barX1 = x1 + w - pad - metrics.barW
	dataView.barX2 = x1 + w - pad
	dataView.textX1 = x1 + pad

	-- How many characters fit across. The face is monospaced, so a width in characters is
	-- exact and the wrapping below is arithmetic rather than measurement per part.
	local code = look.mono or font
	dataView.charW = code:GetTextWidth("0") * dataView.fs
	local room = dataView.barX1 - pad - dataView.textX1
	dataView.chars = mathMax(16, mathFloor(room / mathMax(1, dataView.charW)))

	-- The lines only need flowing again when the width they were flowed to changes, or when
	-- a different widget's settings are being shown.
	if dataView.wrappedAt ~= dataView.chars or dataView.wrappedFor ~= dataView.name then
		dataView.wrappedAt = dataView.chars
		dataView.wrappedFor = dataView.name
		dataView.wrap()
	end

	return x1, y1, x1 + w, y1 + h
end

-- Where the thumb is, in the same terms the list's bar answers in.
function dataView.thumb()
	return UiScrollerAt(
		dataView.barX1,
		dataView.bottom,
		dataView.barX2,
		dataView.top + dataView.lineH,
		#dataView.rows * dataView.lineH,
		dataView.scroll * dataView.lineH
	)
end

-- Taking hold of the bar. On the thumb it is taken where it was grabbed, so the listing
-- does not jump before the drag starts; on the bare track it goes there at once, which is
-- what a press away from the thumb is asking for.
function dataView.grab(y)
	local top, height = dataView.thumb()
	if not top then
		return
	end

	dataView.dragging = true
	if y <= top and y >= top - height then
		dataView.grabAt = y - top
	else
		dataView.grabAt = -mathFloor(height * 0.5)
		dataView.dragTo(y)
	end
end

function dataView.dragTo(y)
	local _, _, trackTop, travel = dataView.thumb()
	if not travel or travel <= 0 then
		return
	end

	local f = (trackTop - (y - dataView.grabAt)) / travel
	if f < 0 then
		f = 0
	elseif f > 1 then
		f = 1
	end
	dataView.setScroll(mathFloor(f * dataView.maxScroll() + 0.5))
end

-- A press inside the window is the window's, whether or not it lands on anything: a click
-- meant for the settings must not reach the rows behind it.
function dataView.press(x, y)
	if not dataView.name then
		return false
	end
	local r = dataView.rect
	if not math_isInRect(x, y, r[1], r[2], r[3], r[4]) then
		-- Pressing outside it is how a window like this is dismissed.
		dataView.shut()

		return true
	end
	local c = dataView.close
	if math_isInRect(x, y, c[1], c[2], c[3], c[4]) then
		dataView.shut()
	elseif
		dataView.maxScroll() > 0
		and math_isInRect(x, y, dataView.barX1, dataView.bottom, dataView.barX2, dataView.top + dataView.lineH)
	then
		dataView.grab(y)
	end

	return true
end
local function closeDialog()
	local d = dialog
	dialog = nil

	return d
end

-- Raises the modal. Everything routed through here is something a reload undoes only by
-- accident, so the wording says what goes rather than asking "are you sure".
-- `field` puts a name box in the dialog and hands what was typed to `accept`.
local function confirm(title, message, accept, danger, field, initial)
	dialog = { title = title, message = message, accept = accept, danger = danger, field = field }
	-- Laid out here rather than at the first frame of it: the cursor is tested against
	-- these buttons before anything is drawn, and empty rects there are a crash.
	dialogGeometry()
	if searchBox then
		searchBox:blur()
	end
	if field and nameBox then
		nameBox:setText(initial or "")
		nameBox:focus()
	end
end

----------------------------------------------------------------
-- Layout
----------------------------------------------------------------

local function sidebarTop()
	return listTop - metrics.sidebarDrop
end

-- How many entries fit between the title and the sets block below.
local function catPageRows()
	return mathMax(1, mathFloor((sidebarTop() - setsTop) / metrics.catRowHeight))
end

-- Where the column stops: a whole number of entries below the title, not wherever the
-- sets block happens to begin. The leftover is never a full row, and a card and a
-- scrollbar drawn over it read as a column with dead space at the foot of it.
local function categoryBottom()
	return sidebarTop() - catPageRows() * metrics.catRowHeight
end

local function maxCatScroll()
	return mathMax(0, #model.categories - catPageRows())
end

-- Where an entry sits. `i` is its place in `categories`, not its place on screen: the two
-- differ by however far the column is scrolled.
--
-- The right edge gives way to the bar when there is one. Without that the count reads
-- right up against it and the hover plate runs underneath it, which looks like the plate
-- is behind the bar rather than the bar being beside the row.
local function categoryRect(i)
	local top = sidebarTop() - (i - 1 - catScroll) * metrics.catRowHeight
	local right = area.x1 + metrics.sidebarW
	if maxCatScroll() > 0 then
		right = right - metrics.catInset - metrics.catBarW - metrics.catInset
	end

	return area.x1, top - metrics.catRowHeight, right, top
end

setCatScroll = function(n)
	local m = maxCatScroll()
	catScroll = (n < 0 and 0) or (n > m and m) or n
end

local function sidebarIndexAt(x, y)
	local top = sidebarTop()
	if x < area.x1 or x > area.x1 + metrics.sidebarW or y > top or y <= categoryBottom() then
		return nil
	end

	local i = mathFloor((top - y) / metrics.catRowHeight) + 1 + catScroll
	if not model.categories[i] then
		return nil
	end

	local _, y1 = categoryRect(i)
	if y1 < categoryBottom() then
		return nil
	end

	return i
end

-- Rebuilds every rect against the panel size. Whole pixels throughout, so glyph and
-- rectangle edges do not land between pixels.
setLayout = function()
	local s = widgetScale
	local pad = mathFloor(8 * s)
	area.x1 = screenX + pad
	area.y1 = screenY - screenHeight + pad
	area.x2 = screenX + screenWidth - pad
	area.y2 = screenY - pad

	metrics.rowHeight = mathFloor(24 * s)
	metrics.catRowHeight = mathFloor(29 * s)
	metrics.rowFs = mathFloor(metrics.rowHeight * 0.55)
	metrics.catFs = mathFloor(metrics.catRowHeight * 0.55 * 0.85)
	metrics.accentW = mathMax(2, mathFloor(3 * s))
	metrics.rowPad = mathFloor(6 * s)
	metrics.sidePad = mathFloor(12 * s)
	metrics.catInset = mathFloor(4 * s)
	metrics.edgeInset = mathFloor(4 * s)
	metrics.headerH = mathFloor(34 * s)
	metrics.headerGap = mathFloor(4 * s)
	metrics.footerH = mathFloor(38 * s)
	metrics.footerGap = mathFloor(6 * s)
	metrics.buttonGap = mathFloor(6 * s)
	metrics.listGap = mathFloor(12 * s)
	metrics.cardLip = mathFloor(5 * s)
	-- The gap between the category card and the sets block below it. The two were one
	-- card, which left the sets reading as the last few categories rather than as a
	-- different thing that happens to sit in the same column.
	metrics.setsGap = mathFloor(7 * s)
	metrics.titleY = mathFloor(17 * s)
	metrics.titleFs = mathFloor(metrics.rowHeight * 0.85)
	metrics.sidebarDrop = mathFloor(8 * s)
	metrics.sidebarW = mathFloor(240 * s)
	metrics.barW = mathFloor(14 * s)
	metrics.catBarW = mathMax(3, mathFloor(6 * s))
	metrics.csPanel = mathFloor(elementCorner)
	metrics.csSmall = mathFloor(elementCorner * 0.66)
	metrics.csButton = mathFloor(elementCorner * 0.66)

	listX1 = area.x1 + metrics.sidebarW + metrics.listGap
	-- The switch owns a column at the head of the row, and the name starts after it.
	metrics.switchH = mathFloor(metrics.rowHeight * 0.46)
	metrics.switchW = mathFloor(metrics.switchH * 2.2)

	-- What each widget costs, ahead of the control that turns it off: the number is the
	-- reason for reaching for the switch, so it is read first. Both columns are measured
	-- from the widest they can print and the figures are right-aligned in them, so the
	-- decimal points line up down the list instead of wandering with the digits.
	metrics.loadFs = mathFloor(metrics.rowFs * 0.95)
	metrics.cpuW = look.mono and mathFloor(look.mono:GetTextWidth(cost.sampleCpu) * metrics.loadFs) or mathFloor(34 * s)
	metrics.memW = look.mono and mathFloor(look.mono:GetTextWidth(cost.sampleMem) * metrics.loadFs) or mathFloor(30 * s)
	-- What the switch leaves above and below itself inside the row. It is held the same
	-- distance from the accent bar down the left edge, so the air around it reads as even
	-- rather than pinched on one side.
	metrics.switchGap = mathFloor((metrics.rowHeight - metrics.switchH) * 0.5)
	metrics.cpuX1 = listX1 + metrics.accentW + metrics.switchGap
	metrics.memX1 = metrics.cpuX1 + metrics.cpuW + metrics.rowPad
	if filters.profiler then
		switchX1 = metrics.memX1 + metrics.memW + metrics.rowPad * 2
	else
		switchX1 = metrics.cpuX1
	end
	-- The rank gets a column of its own only while the list is in that order: a number
	-- nobody is reading is clutter, and the name is worth the room.
	orderX1 = switchX1 + metrics.switchW + metrics.rowPad * 2
	metrics.orderW = 0
	if filters.byOrder then
		metrics.orderW = font and mathFloor(font:GetTextWidth("8888") * metrics.rowFs) or mathFloor(34 * s)
	end
	-- The star, ahead of everything that names the widget - which is where the column
	-- carries it ahead of the Favourites label, so the two read as the same mark. A column
	-- of its own rather than a hit box carved out of the row: a click on it must star the
	-- widget rather than switch it, and both halves of that click have to land on the star.
	metrics.starR = mathMax(4, mathFloor(6 * s))
	metrics.starW = metrics.starR * 2
	metrics.starX1 = orderX1 + metrics.orderW + (metrics.orderW > 0 and metrics.rowPad * 2 or 0)
	-- The square in the widget's group colour, just ahead of its name: the name is what the eye
	-- lands on, so the colour beside it is read with it rather than looked for along the row.
	metrics.swatch = mathMax(5, mathFloor(8 * s))
	metrics.swatchGap = mathFloor(7 * s)
	metrics.swatchCorner = mathMax(1, mathFloor(metrics.swatch * 0.25))
	-- What the star leaves either side of itself is the star's to be clicked on, so the
	-- swatch starts a full pad past it rather than against it.
	metrics.swatchX1 = metrics.starX1 + metrics.starW + metrics.rowPad * 2
	-- And what answers a click: the star and the pad either side of it. Measured once here
	-- rather than at both places that ask - the hover test and the press - so the two
	-- cannot come apart, and a twelve-pixel target is not the whole of what has to be hit.
	metrics.starHit1 = metrics.starX1 - metrics.rowPad
	metrics.starHit2 = metrics.swatchX1 - metrics.rowPad
	nameX1 = metrics.swatchX1 + metrics.swatch + metrics.swatchGap
	listTop = area.y2 - metrics.headerH - metrics.headerGap
	local footerTop = area.y1 + metrics.footerH
	listBottom = footerTop + metrics.footerGap
	barX1 = area.x2 - metrics.edgeInset - metrics.barW
	listRight = barX1 - metrics.listGap
	local split = filters.profiler and metrics.descSplitCost or metrics.descSplit
	descX1 = listX1 + mathFloor((listRight - listX1) * split)

	-- The header band: the switches against the right edge, and the search field takes
	-- whatever width they leave it.
	local rowTop = area.y2 - mathFloor(4 * s)
	local rowBottom = area.y2 - metrics.headerH + mathFloor(4 * s)
	local fs = mathFloor((rowTop - rowBottom) * 0.5)
	local togW = mathFloor(38 * s)
	local togH = mathFloor((rowTop - rowBottom) * 0.62)
	local togY = mathFloor((rowTop + rowBottom) * 0.5)
	local togY1 = togY - mathFloor(togH * 0.5)
	metrics.toggleFs = mathFloor(metrics.rowFs * 1.05)
	-- Outlined text spreads past the box it is measured in, so the caption's first glyph
	-- already sits a little left of where its advance box starts. This buys the caption
	-- side back the room its outline took, so the hover plate opens the same on both ends.
	metrics.captionBleed = mathFloor(metrics.toggleFs * 0.2 + 0.5)

	local x2 = area.x2 - metrics.edgeInset
	local lastSwitch
	for i = 1, #switches do
		local sw = switches[i]
		sw.label = L[sw.key]
		-- A sub-switch is only there while what it qualifies is on. No rect means it is not
		-- drawn and cannot be hit, so nothing else has to know about it.
		if sw.sub and not filters[sw.sub] then
			sw.draw, sw.hit = nil, nil
		else
			local w = font and mathFloor(font:GetTextWidth(sw.label) * metrics.toggleFs) or mathFloor(90 * s)
			sw.draw = { x2 - togW, togY1, x2, togY1 + togH }
			-- The caption is part of the control: a switch this small is a poor click target on
			-- its own, and the words beside it are what names the thing being switched.
			sw.hit =
				{ sw.draw[1] - metrics.rowPad * 2 - w - metrics.captionBleed, rowBottom, x2 + metrics.rowPad, rowTop }
			x2 = sw.hit[1] - mathFloor(14 * s)
			lastSwitch = sw
		end
	end

	-- Wider than the gaps inside a switch, so the last caption reads as belonging to the
	-- switch beside it rather than to the field it would otherwise sit against.
	searchBox:setRect(listX1, rowBottom, lastSwitch.hit[1] - mathFloor(28 * s), rowTop, fs)

	-- The sets block, measured up from the foot of the category card.
	local setsPad = mathFloor(8 * s)
	local pickH = mathFloor(metrics.rowHeight * 1.1)
	local setBtnH = mathFloor(metrics.rowHeight * 1.0)
	metrics.setsFs = mathFloor(metrics.rowHeight * 0.5)
	-- One row of buttons without a set picked, two with.
	local buttonRows = model.pickedSet and 2 or 1
	local topOfButtons
	setsTop = listBottom + setsPad * (buttonRows + 2) + pickH + setBtnH * buttonRows + metrics.catRowHeight

	local sx1 = area.x1 + metrics.catInset + setsPad
	local sx2 = area.x1 + metrics.sidebarW - metrics.catInset - setsPad
	-- Save and Delete share a row; Load takes one of its own above them, being the one
	-- reached for most and the one whose label must not be cut at a narrow sidebar.
	local pairTop = listBottom + setsPad + setBtnH
	local half = mathFloor((sx2 - sx1 - setsPad) * 0.5)
	if model.pickedSet then
		local loadTop = pairTop + setsPad + setBtnH
		setButtons[1].rect = { sx1, loadTop - setBtnH, sx2, loadTop }
		setButtons[2].rect = { sx1, pairTop - setBtnH, sx1 + half, pairTop }
		setButtons[3].rect = { sx2 - half, pairTop - setBtnH, sx2, pairTop }
		topOfButtons = loadTop
	else
		-- Nothing picked, so Save is the only button: it takes the whole row on its own
		-- rather than half of one with a hole beside it and an empty row above. The other
		-- two lose their rects outright, so a stale one from the last layout cannot be hit.
		setButtons[1].rect = nil
		setButtons[2].rect = { sx1, pairTop - setBtnH, sx2, pairTop }
		setButtons[3].rect = nil
		topOfButtons = pairTop
	end
	setPicker:setRect(sx1, topOfButtons + setsPad, sx2, topOfButtons + setsPad + pickH, metrics.setsFs)
	metrics.setsCaptionY = topOfButtons + setsPad + pickH + mathFloor(metrics.catRowHeight * 0.5)

	-- The footer: the actions, spread evenly across the width. Held off both edges by the
	-- same inset the scrollbar keeps against the right one, so the outermost buttons do
	-- not sit against the panel's rounded corners.
	local n = #model.buttons
	if n > 0 then
		local fx1 = area.x1 + metrics.edgeInset
		local fx2 = area.x2 - metrics.edgeInset
		local bw = mathFloor(((fx2 - fx1) - (n - 1) * metrics.buttonGap) / n)
		local by1 = area.y1 + mathFloor(4 * s)
		local by2 = by1 + metrics.footerH - mathFloor(8 * s)
		for i = 1, n do
			local bx1 = fx1 + (i - 1) * (bw + metrics.buttonGap)
			-- The last one takes whatever the division left over, so the row ends flush with
			-- the inset rather than a pixel or two short of it.
			model.buttons[i].rect = { bx1, by1, (i == n) and fx2 or (bx1 + bw), by2 }
		end
	end
	metrics.buttonFs = mathFloor(metrics.rowHeight * 0.55)
	-- The clear-data button's column at the right end of the row. Reserved on every row
	-- whether or not one is drawn there: a widget saves its first settings the moment it
	-- is switched on, and a description that reflowed under the cursor reads worse than
	-- the gap does.
	metrics.clearFs = mathFloor(metrics.rowFs * 0.92)
	metrics.clearH = mathFloor(metrics.rowHeight * 0.62)
	metrics.clearW = font and (mathFloor(font:GetTextWidth(L.cleardata) * metrics.clearFs) + metrics.rowPad * 3)
		or mathFloor(46 * s)
	clearX1 = listRight - metrics.rowPad - metrics.clearW
	-- And beside it, the button that shows what the widget has actually saved. Same
	-- reservation: it appears and disappears with the settings, and a description that
	-- reflowed when one was saved would read worse than the gap.
	metrics.dataW = font and (mathFloor(font:GetTextWidth(L.showdata) * metrics.clearFs) + metrics.rowPad * 3)
		or mathFloor(66 * s)
	metrics.dataX1 = clearX1 - metrics.rowPad - metrics.dataW
	-- What the tag at the end of a local row takes, so a description can be kept out of it.
	metrics.localTagW = font and mathFloor(font:GetTextWidth(L.islocal) * metrics.rowFs) or mathFloor(30 * s)
	-- And what the RmlUi tag takes beside it. Both can be on the same row.
	metrics.rmlTagW = font and mathFloor(font:GetTextWidth(L.isrml) * metrics.rowFs) or mathFloor(22 * s)
	-- And the error tag, on rows that have raised anything this session.
	metrics.errorTagW = font and mathFloor(font:GetTextWidth(L.iserror) * metrics.rowFs) or mathFloor(26 * s)

	if dialog then
		dialogGeometry()
	end

	setCatScroll(catScroll)
	layoutGen = layoutGen + 1
	clampScroll()
end

-- Cuts the category captions to the column once per layout, rather than measuring them on
-- every frame the panel is baked.
local function fitCategories()
	-- Every entry leaves room for a group's colour ahead of its label, so the labels line up
	-- whether an entry has one or not.
	local avail = metrics.sidebarW
		- metrics.sidePad * 2
		- metrics.swatch
		- metrics.swatchGap
		- mathFloor(46 * widgetScale)
	for _, c in ipairs(model.categories) do
		local label = text.fit(font, c.label, avail, metrics.catFs)
		c.textDim = colorDim .. label
		c.textSel = colorSelected .. label
		c.textEmpty = look.emptyText .. label
		c.fitGen = layoutGen
	end
end

-- Cuts a row's name and description to their columns, once per row per layout.
local function fitRow(row)
	if row.fitGen == layoutGen then
		return
	end
	row.fitGen = layoutGen

	local ink = look.rowText
	local nameColor = ink.name
	local descColor = ink.desc
	if row.state == 1 then
		nameColor, descColor = ink.nameOn, ink.descOn
	elseif row.state == 0.5 then
		nameColor, descColor = ink.namePending, ink.descOn
	end

	if metrics.orderW > 0 then
		-- Nothing running has no place in the order, and a dash says that better than a gap.
		row.fitOrder = colorDim .. (row.order and tostring(row.order) or "-")
	end
	local nameW = descX1 - nameX1 - metrics.rowPad
	row.fitName = nameColor .. text.fit(font, row.name, nameW, metrics.rowFs)
	if row.desc ~= "" then
		-- A local row ends with its tag, so the description stops short of it rather than
		-- running underneath.
		local descW = metrics.dataX1 - descX1 - metrics.rowPad * 2
		if row.errors then
			descW = descW - metrics.errorTagW - metrics.rowPad
		end
		if row.isLocal then
			descW = descW - metrics.localTagW - metrics.rowPad
		end
		if row.isRml then
			descW = descW - metrics.rmlTagW - metrics.rowPad
		end
		row.fitDesc = descColor .. text.fit(font, row.desc, descW, metrics.rowFs)
	else
		row.fitDesc = nil
	end
end

----------------------------------------------------------------
-- Drawing
----------------------------------------------------------------

local textQueue = {}

local function queueText(str, x, y, size, opts)
	textQueue[#textQueue + 1] = { str, x, y, size, opts }
end

local function flushText()
	if #textQueue == 0 then
		return
	end
	font:Begin()
	font:SetOutlineColor(look.outline)
	for i = 1, #textQueue do
		local t = textQueue[i]
		font:Print(t[1], t[2], t[3], t[4], t[5])
	end
	font:End()
	textQueue = {}
end

local function drawButtonFace(r, fill)
	local pair = look.gradients[fill]

	UiButton(r[1], r[2], r[3], r[4], 1, 1, 1, 1, 1, 1, 1, 1, nil, pair[1], pair[2])
end

-- The fan itself, handed to gl.BeginEnd rather than closed over, so nothing is allocated
-- per star. gl.Vertex and gl.BeginEnd are reached through their tables rather than through
-- locals the way the rest of this file reaches the GL calls it makes: a star is only drawn
-- while the panel is being baked, and the panel is baked when something about it moves.
function fav.fan(cx, cy, r, cr, cg, cb, ca)
	local p = fav.points
	glColor(cr, cg, cb, ca)
	gl.Vertex(cx, cy, 0)
	for i = 1, #p, 2 do
		gl.Vertex(cx + p[i] * r, cy + p[i + 1] * r, 0)
	end
end

-- One star, on its centre, in the colour its state and the cursor put it in. Drawn twice:
-- a wider, faint pass under the solid one, which takes the staircase off an edge at this
-- size. There is no antialiasing to lean on, and five points and five notches is a shape
-- made almost entirely of diagonal edges.
function fav.draw(cx, cy, r, on, hovered)
	local c = on and (hovered and fav.onHover or fav.on) or (hovered and fav.offHover or fav.off)
	-- Widest first, so the bands stack inward and one alpha makes a falloff. One band that
	-- wide would read as a second star drawn round the first rather than as light. Only one
	-- star is ever under the cursor, so the extra band is paid for once a bake.
	local how = hovered and fav.lit or fav.rest
	r = r * how.size
	for i = how.bands, 1, -1 do
		local spread = 1 + how.spread * (i / how.bands)
		gl.BeginEnd(GL.TRIANGLE_FAN, fav.fan, cx, cy, r * spread, c[1], c[2], c[3], c[4] * how.alpha)
	end
	gl.BeginEnd(GL.TRIANGLE_FAN, fav.fan, cx, cy, r, c[1], c[2], c[3], c[4])
	-- Put back, so what is baked after this is painted in its own colour rather than in a
	-- star's. Everything else here draws through FlowUI, which sets its own.
	glColor(1, 1, 1, 1)
end

local function drawRow(row, top, bottom, hovered, overSwitch, overClear, overData, overStar)
	fitRow(row)

	-- A widget an error stopped reads as its own state rather than as the amber one: it is
	-- not waiting for anything, it is broken, and the panel knows what broke it.
	local fill = (row.stoppedBy and look.errorFill)
		or (row.state == 1 and look.activeFill)
		or (row.state == 0.5 and look.pendingFill)
	local accent = (row.stoppedBy and look.errorAccent)
		or (row.state == 1 and look.activeAccent)
		or (row.state == 0.5 and look.pendingAccent)
	if fill then
		RectRound(listX1, bottom, listRight, top, metrics.csSmall, 1, 1, 1, 1, fill)
		RectRound(listX1, bottom + 1, listX1 + metrics.accentW, top - 1, metrics.csSmall, 1, 1, 1, 1, accent)
	end
	if hovered then
		Highlight(listX1, bottom, listRight, top, metrics.csSmall, look.rowHoverOpacity, look.white)
	end

	local ty = mathFloor((top + bottom) * 0.5)
	-- The switch says the state on its own, the way a bool row in the settings does: green
	-- knob to the right for running, amber in the middle for enabled but not running, and
	-- the off colour to the left for off.
	local sy = ty - mathFloor(metrics.switchH * 0.5)
	UiToggle(switchX1, sy, switchX1 + metrics.switchW, sy + metrics.switchH, row.state, overSwitch)
	if metrics.orderW > 0 then
		-- Right-aligned, so the ranks line up as a column however many digits they run to.
		queueText(row.fitOrder, orderX1 + metrics.orderW, ty, metrics.rowFs, "rov")
	end
	-- The star, ahead of the name. On every row rather than only on the starred ones: an
	-- empty slot is what says a row can be starred, and a mark that only appears once the
	-- click has been found is a mark nobody finds.
	fav.draw(metrics.starX1 + metrics.starR, ty, metrics.starR, fav.names[row.name] ~= nil, overStar)
	-- The group the widget is in, in that group's colour from the column: in All, and in the
	-- views and searches that cut across the groups, this is what says where a row belongs.
	-- Faded on a row that is off, the way its name and description are.
	local swatch = look.groups[row.group]
	if swatch then
		local swatchY = ty - mathFloor(metrics.swatch * 0.5)
		RectRound(
			metrics.swatchX1,
			swatchY,
			metrics.swatchX1 + metrics.swatch,
			swatchY + metrics.swatch,
			metrics.swatchCorner,
			1,
			1,
			1,
			1,
			row.state == 0 and look.faded[swatch] or swatch
		)
	end
	queueText(row.fitName, nameX1, ty, metrics.rowFs, "ov")
	if row.fitDesc then
		queueText(row.fitDesc, descX1, ty, metrics.rowFs, "ov")
	end
	-- The two things about a widget that are not in its name or its description: whose
	-- file it is, and whether it draws through RmlUi rather than through this UI. Both
	-- right to left from the buttons, so a row with both still reads in order.
	local tagX = metrics.dataX1 - metrics.rowPad
	-- A widget that has raised an error this session says so first, nearest the buttons: red
	-- while an error is what stopped it, a softer red once it runs again. What the errors were
	-- is in its tooltip - each is nearly always one short line, which a tooltip shows at a
	-- glance and a window of its own made a click and a close out of.
	if row.errors then
		local tint = row.stoppedBy and tagColors.iserror or tagColors.iserrorSoft
		queueText(tint .. L.iserror, tagX, ty, metrics.rowFs, "rov")
		tagX = tagX - metrics.errorTagW - metrics.rowPad
	end
	if row.isLocal then
		queueText(tagColors.islocal .. L.islocal, tagX, ty, metrics.rowFs, "rov")
		tagX = tagX - metrics.localTagW - metrics.rowPad
	end
	if row.isRml then
		queueText(tagColors.isrml .. L.isrml, tagX, ty, metrics.rowFs, "rov")
		tagX = tagX - metrics.rmlTagW - metrics.rowPad
	end

	-- Only where there is something to clear. Quiet until it is pointed at, and red then:
	-- a column of red buttons down a list of two hundred rows would read as a warning
	-- about the list rather than an action on one row of it.
	if row.hasConfig then
		local cy1 = ty - mathFloor(metrics.clearH * 0.5)
		local r = { clearX1, cy1, clearX1 + metrics.clearW, cy1 + metrics.clearH }
		drawButtonFace(r, overClear and look.dangerFillHover or look.buttonFill)
		queueText(
			(overClear and colorDanger or colorDim) .. L.cleardata,
			mathFloor((r[1] + r[3]) * 0.5),
			ty,
			metrics.clearFs,
			"cov"
		)

		-- And beside it, what the widget has saved. Plain rather than red: reading settings
		-- takes nothing away, and only the button that does should look like it might.
		local d = { metrics.dataX1, cy1, metrics.dataX1 + metrics.dataW, cy1 + metrics.clearH }
		drawButtonFace(d, look.buttonFill)
		if overData then
			Highlight(d[1], d[2], d[3], d[4], metrics.csButton, look.hoverOpacity, look.white)
		end
		queueText(
			(overData and colorText or colorDim) .. L.showdata,
			mathFloor((d[1] + d[3]) * 0.5),
			ty,
			metrics.clearFs,
			"cov"
		)
	end
end

-- The two cost columns, drawn live rather than baked into the panel list with the rest of
-- the row. They change several times a second, and re-baking three hundred rows at that
-- rate would cost more than the numbers are worth; everything else on the row is static
-- between hovers, so it stays in the list.
--
-- Nothing is drawn behind them. A plate per row would put two hundred small boxes down
-- the panel and turn a column of figures into a table nobody asked for.
local function drawCostColumns()
	if not (filters.profiler and look.mono) then
		return
	end

	look.mono:Begin()
	look.mono:SetOutlineColor(look.outline)
	for i = 1, #model.rows - scroll do
		local row = model.rows[scroll + i]
		if not row then
			break
		end
		local top = listTop - (i - 1) * metrics.rowHeight
		if top - metrics.rowHeight < listBottom then
			break
		end
		local stat = profiling.stats[row.name]
		if stat then
			local ty = mathFloor(top - metrics.rowHeight * 0.5)
			-- Each figure is coloured by itself, not by some other average of the same widget:
			-- a row reading 0.4% in the warning colour beside one reading 2.0% in the quiet one
			-- says the colour means nothing.
			local cpu = stat.load
			local mem = stat.space
			-- Right-aligned in its own column, so the figures line up down the list.
			look.mono:Print(
				(cpu >= cost.cpuHot and cost.hot or cpu >= cost.cpuWarn and cost.warm or cost.cool)
					.. string.format("%.1f%%", cpu),
				metrics.cpuX1 + metrics.cpuW,
				ty,
				metrics.loadFs,
				"rov"
			)
			look.mono:Print(
				(mem >= cost.memHot and cost.hot or mem >= cost.memWarn and cost.warm or cost.cool)
					.. string.format("%.0fk", mem),
				metrics.memX1 + metrics.memW,
				ty,
				metrics.loadFs,
				"rov"
			)
		end
	end
	look.mono:End()
end

local function drawRows()
	for i = 1, #model.rows - scroll do
		local row = model.rows[scroll + i]
		if not row then
			break
		end
		local top = listTop - (i - 1) * metrics.rowHeight
		local bottom = top - metrics.rowHeight
		if bottom < listBottom then
			break
		end
		drawRow(
			row,
			top,
			bottom,
			hover.row == i,
			hover.row == i and hover.sw == 1,
			hover.row == i and hover.clr == 1,
			hover.row == i and hover.dat == 1,
			hover.row == i and hover.star == 1
		)
	end
end

function dataView.draw()
	local x1, y1, x2, y2 = dataView.geometry()
	local mx, my, lmb = spGetMouseState()
	local pad = dataView.pad

	-- A drag runs for as long as the button is held, wherever the cursor goes: letting go
	-- is the only thing that ends it.
	if dataView.dragging then
		if lmb then
			dataView.dragTo(my)
		else
			dataView.dragging = false
		end
	end

	-- Everything behind it dims, the same as a confirmation does: this is the only thing
	-- that will answer while it is up.
	RectRound(screenX, screenY - screenHeight, screenX + screenWidth, screenY, elementCorner, 1, 1, 1, 1, look.scrim)
	UiElement(x1, y1, x2, y2, 1, 1, 1, 1, 1, 1, 1, 1, WG.FlowUI.clampedOpacity)

	local overClose = math_isInRect(mx, my, dataView.close[1], dataView.close[2], dataView.close[3], dataView.close[4])
	drawButtonFace(dataView.close, look.buttonFill)
	if overClose then
		Highlight(
			dataView.close[1],
			dataView.close[2],
			dataView.close[3],
			dataView.close[4],
			metrics.csButton,
			look.hoverOpacity,
			look.white
		)
	end

	font:Begin()
	font:SetOutlineColor(look.outline)
	font:Print(colorTitle .. dataView.name, x1 + pad, dataView.titleY, dataView.titleFs, "ov")
	font:Print(
		colorText .. L.close,
		mathFloor((dataView.close[1] + dataView.close[3]) * 0.5),
		mathFloor((dataView.close[2] + dataView.close[4]) * 0.5),
		metrics.setsFs,
		"cov"
	)
	font:End()

	-- The listing, in the monospaced face: this is source, and source whose columns do not
	-- line up is harder to read than source with no colour at all. Already flowed to the
	-- width by geometry, so a row here is a row on screen.
	local code = look.mono or font
	code:Begin()
	code:SetOutlineColor(look.outline)
	for i = 1, dataView.page do
		local row = dataView.rows[dataView.scroll + i]
		if not row then
			break
		end
		local ly = dataView.top - (i - 1) * dataView.lineH
		local lx = dataView.textX1 + row.indent * dataView.charW
		for _, part in ipairs(row.parts) do
			code:Print((codeColors[part.k] or codeColors.name) .. part.s, lx, ly, dataView.fs, "o")
			lx = lx + #part.s * dataView.charW
		end
	end
	code:End()

	-- How much is off the bottom, and how to get at it. A bar rather than a count: a count
	-- says there is more without saying where, and this panel scrolls everything else with
	-- a bar you can take hold of.
	if dataView.maxScroll() > 0 then
		-- Lit under the cursor and again while it is being dragged, the same as the list's
		-- bar: a bar that does not react is a bar nobody tries to take hold of.
		local top, height = dataView.thumb()
		local onThumb = top and my <= top and my >= top - height and mx >= dataView.barX1 and mx <= dataView.barX2
		UiScroller(
			dataView.barX1,
			dataView.bottom,
			dataView.barX2,
			dataView.top + dataView.lineH,
			#dataView.rows * dataView.lineH,
			dataView.scroll * dataView.lineH,
			onThumb or false,
			dataView.dragging or false
		)
	end
end

-- The sets block at the foot of the column. The picker draws itself, live, since it can
-- open over the list.
local function drawSetsBlock()
	-- With how many there are, once there are any: the picker only ever shows the one picked.
	local caption = #model.sets > 0 and (L.sets .. " (" .. #model.sets .. ")") or L.sets
	queueText(colorDim .. caption, area.x1 + metrics.sidePad, metrics.setsCaptionY, metrics.catFs, "ov")

	for _, b in ipairs(setButtons) do
		-- Load and Delete are not drawn at all without a set picked: a button that can do
		-- nothing is worse than no button.
		if b.rect then
			local hovered = hover.btn == b.id
			drawButtonFace(b.rect, look.buttonFill)
			if hovered then
				Highlight(b.rect[1], b.rect[2], b.rect[3], b.rect[4], metrics.csButton, look.hoverOpacity, look.white)
			end
			queueText(
				colorText .. L[b.id],
				mathFloor((b.rect[1] + b.rect[3]) * 0.5),
				mathFloor((b.rect[2] + b.rect[4]) * 0.5),
				metrics.setsFs,
				"cov"
			)
		end
	end
end

local function drawSidebar()
	-- The categories get their own card, with the same lip below the last entry as it has
	-- above the first. Ending exactly on the last row leaves it sitting on the edge, and a
	-- selected or hovered last entry then has its plate flush with the card's own border.
	RectRound(
		area.x1,
		categoryBottom() - metrics.cardLip,
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

	-- And the sets get theirs, with air between them. One card holding both made the
	-- sets read as the tail of the category list rather than as their own thing.
	RectRound(
		area.x1,
		listBottom,
		area.x1 + metrics.sidebarW,
		setsTop - metrics.setsGap,
		metrics.csPanel,
		1,
		1,
		1,
		1,
		look.sidebarFill,
		look.sidebarFillTop
	)
	queueText(colorTitle .. L.title, area.x1 + metrics.sidePad, area.y2 - metrics.titleY, metrics.titleFs, "ov")

	if model.categories[1] and model.categories[1].fitGen ~= layoutGen then
		fitCategories()
	end

	for i = catScroll + 1, #model.categories do
		local c = model.categories[i]
		-- The loop covers every index, so this cannot be nil.
		---@cast c -?
		local x1, y1, x2, y2 = categoryRect(i)
		if y1 < categoryBottom() then
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
		-- A prefix group carries its colour ahead of its label, which is the key to the squares on
		-- the rows. All, Changed, Your own and RmlUi cut across the groups, so they have none.
		--
		-- Favourites carries the same star its rows are starred with instead, in the slot the
		-- colour would have taken: the mark on the rows and the mark on the category it
		-- collects them into are the one mark, so neither has to be explained.
		local swatch = c.key and look.groups[c.key]
		if c.key == fav.key then
			-- Never lit, however the entry under it is: the halo on a row's star is what says
			-- the cursor is on the star itself and that clicking it would star or unstar that
			-- widget. Nothing here can be clicked that way, so this one is a label, and a label
			-- that lights with the row it is on would be read as offering the same click.
			fav.draw(x1 + metrics.sidePad + mathFloor(metrics.swatch * 0.5), ty, metrics.starR, true, false)
		elseif swatch then
			local swatchY = ty - mathFloor(metrics.swatch * 0.5)
			RectRound(
				x1 + metrics.sidePad,
				swatchY,
				x1 + metrics.sidePad + metrics.swatch,
				swatchY + metrics.swatch,
				metrics.swatchCorner,
				1,
				1,
				1,
				1,
				(c.empty and not selected) and look.faded[swatch] or swatch
			)
		end
		local label = (selected and c.textSel) or (c.empty and c.textEmpty) or c.textDim
		queueText(label, x1 + metrics.sidePad + metrics.swatch + metrics.swatchGap, ty, metrics.catFs, "ov")
		queueText(c.countText, x2 - metrics.sidePad, ty, metrics.catFs, "rov")
	end

	-- A bar of its own, and a slim one: the column is narrow and this only appears when
	-- there are more categories than the card has room for.
	if maxCatScroll() > 0 then
		local bx2 = area.x1 + metrics.sidebarW - metrics.catInset
		UiScroller(
			bx2 - metrics.catBarW,
			categoryBottom(),
			bx2,
			sidebarTop(),
			#model.categories * metrics.catRowHeight,
			catScroll * metrics.catRowHeight
		)
	end
end

-- One switch and its caption. The plate goes behind the switch and the switch lights
-- itself: at the plate's opacity the switch has one of its own bright enough to swallow
-- it, and painting over the switch only dulls it.
local function drawSwitch(draw, hit, label, state, hovered)
	if hovered then
		Highlight(hit[1], hit[2], hit[3], hit[4], metrics.csSmall, look.rowHoverOpacity, look.white)
	end
	UiToggle(draw[1], draw[2], draw[3], draw[4], state, hovered)
	queueText(
		(state and colorSelected or colorDim) .. label,
		draw[1] - metrics.rowPad,
		mathFloor((hit[2] + hit[4]) * 0.5),
		metrics.toggleFs,
		"rov"
	)
end

local function drawHeader()
	for i = 1, #switches do
		local sw = switches[i]
		if sw.draw then
			drawSwitch(sw.draw, sw.hit, sw.label, filters[sw.key], hover.tog == i)
		end
	end
end

local function drawFooter()
	for _, b in ipairs(model.buttons) do
		local r = b.rect
		if r then
			local hovered = hover.btn == b.id
			local fill = b.danger and (hovered and look.dangerFillHover or look.dangerFill)
				or b.good and (hovered and look.confirmFillHover or look.confirmFill)
				or nil
			drawButtonFace(r, fill or look.buttonFill)
			-- A tinted button would lose its colour under the white overlay, so it brightens
			-- its own fill above instead.
			if hovered and not fill then
				Highlight(r[1], r[2], r[3], r[4], metrics.csButton, look.hoverOpacity, look.white)
			end
			queueText(
				(b.danger and colorDanger or b.good and colorGood or colorText) .. (b.label or ""),
				mathFloor((r[1] + r[3]) * 0.5),
				mathFloor((r[2] + r[4]) * 0.5),
				metrics.buttonFs,
				"cov"
			)
		end
	end
end

local function drawDialog(d)
	local bx1, by1, bx2, by2 = dialogGeometry()
	local s = widgetScale
	local cx = mathFloor((bx1 + bx2) * 0.5)
	local tfs = mathFloor(metrics.rowHeight * 0.6)
	local sfs = mathFloor(metrics.rowHeight * 0.5)

	-- Everything behind it dims, so the modal is plainly the only thing that will answer.
	-- The whole window, not the inset area inside it: a modal that leaves the panel's own
	-- border lit does not read as covering it. Rounded like the panel so it does not
	-- square off its corners.
	RectRound(screenX, screenY - screenHeight, screenX + screenWidth, screenY, elementCorner, 1, 1, 1, 1, look.scrim)
	UiElement(bx1, by1, bx2, by2, 1, 1, 1, 1, 1, 1, 1, 1, WG.FlowUI.clampedOpacity)

	-- With nothing typed there is nothing to save, so the accept is not drawn at all: a
	-- button that cannot do anything is worse than no button.
	local _, blocked = dialogName()
	local faces = { { r = dialogCancel, id = "cancel" } }
	if not blocked then
		-- Green when the accept saves something, red when it takes something away.
		faces[2] = { r = dialogOk, id = "ok", danger = d.danger, confirm = d.field or not d.danger }
	end
	for _, b in ipairs(faces) do
		local hovered = hover.dlg == b.id
		local base = (b.danger and look.dangerFill) or (b.confirm and look.confirmFill)
		local lift = (b.danger and look.dangerFillHover) or (b.confirm and look.confirmFillHover)
		local fill = base and (hovered and lift or base)
		drawButtonFace(b.r, fill or look.buttonFill)
		if hovered and not fill then
			Highlight(b.r[1], b.r[2], b.r[3], b.r[4], metrics.csButton, look.hoverOpacity, look.white)
		end
	end

	font:Begin()
	font:SetOutlineColor(look.outline)
	font:Print(colorText .. d.title, cx, by2 - mathFloor(26 * s), tfs, "cov")
	local lines = text.wrap(font, d.message, bx2 - bx1 - mathFloor(32 * s), sfs)
	local step = mathFloor(sfs * 1.45)
	-- Centred in the band the title and the buttons leave, not in the whole box: centring
	-- on the box puts the text low, since the buttons take more room than the title.
	local bandTop = by2 - mathFloor(26 * s) - tfs
	local bandBottom = (d.field and dialogField[4] or dialogOk[4]) + mathFloor(8 * s)
	local top = mathFloor((bandTop + bandBottom) * 0.5 + (#lines - 1) * step * 0.5)
	for i = 1, #lines do
		font:Print(colorDim .. lines[i], cx, top - (i - 1) * step, sfs, "cov")
	end
	font:Print(
		colorText .. L.cancel,
		mathFloor((dialogCancel[1] + dialogCancel[3]) * 0.5),
		mathFloor((dialogCancel[2] + dialogCancel[4]) * 0.5),
		sfs,
		"cov"
	)
	if not blocked then
		font:Print(
			(d.danger and colorDanger or colorGood) .. (d.field and L.save or L.confirm),
			mathFloor((dialogOk[1] + dialogOk[3]) * 0.5),
			mathFloor((dialogOk[2] + dialogOk[4]) * 0.5),
			sfs,
			"cov"
		)
	end
	font:End()

	if d.field then
		-- Sized here, drawn in DrawScreen: the panel around it is a display list replayed
		-- until something moves, and a field being typed into moves every frame.
		nameBox:setRect(dialogField[1], dialogField[2], dialogField[3], dialogField[4], sfs)
	end
end

local function drawPanel()
	drawSidebar()
	drawSetsBlock()
	drawHeader()
	drawRows()
	drawFooter()
	flushText()

	if #model.rows > 0 then
		UiScroller(
			barX1,
			listBottom,
			area.x2 - metrics.edgeInset,
			listTop,
			#model.rows * metrics.rowHeight,
			scroll * metrics.rowHeight,
			hover.bar == 1,
			dragging
		)
	end

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
	end
	if windowList then
		glDeleteList(windowList)
		windowList = nil
	end
end

-- What is blurred behind the things that float over the panel: the modal, and the
-- picker's list while it is down. Both are drawn after the panel and over whatever
-- happens to be under them, so they get the same treatment the tooltip gives itself.
--
-- Only touched when the rect actually changes: inserting one marks the screen stencil
-- dirty, and doing that every frame would have it rebuilt every frame.
local shaded = {}

local function shadeRect(name, x1, y1, x2, y2)
	if not WG.guishader then
		return
	end
	local was = shaded[name]
	if x1 then
		if not (was and was[1] == x1 and was[2] == y1 and was[3] == x2 and was[4] == y2) then
			WG.guishader.InsertScreenRect(x1, y1, x2, y2, "widgetselector_" .. name, widget)
			shaded[name] = { x1, y1, x2, y2 }
		end
	elseif was then
		WG.guishader.RemoveScreenRect("widgetselector_" .. name)
		shaded[name] = nil
	end
end

-- Content that has to stay crisp above its own blur.
--
-- widgetHandler draws the DrawScreen list in reverse layer order, so this widget (layer
-- 999999) draws first and gfx_guishader (-990000) draws its blur pass last, over
-- everything. Anything of ours sitting inside one of the rects above would be blurred
-- along with what is behind it. gui_options has the same problem with its select list and
-- solves it by handing the drawing to guishader, which replays it after the blur; the
-- other way out is gui_tooltip's, sitting below guishader's layer so it draws last, but
-- that would mean moving this whole panel.
--
-- Rebuilt per frame: a modal carries a blinking caret and the picker's list lights the
-- option under the cursor, so there is nothing static to hold on to.
local floatLists = {}

local function dropFloat(name)
	local list = floatLists[name]
	if list then
		if WG.guishader then
			WG.guishader.removeRenderDlist(list)
		end
		glDeleteList(list)
		floatLists[name] = nil
	end
end

local function drawFloating(name, fn)
	if not (WG.guishader and WG.guishader.insertRenderDlist) then
		-- No blur will be drawn over it, so there is nothing to hand over.
		fn()
		return
	end
	dropFloat(name)
	floatLists[name] = glCreateList(fn)
	WG.guishader.insertRenderDlist(floatLists[name])
end

local function updateShading()
	if dataView.name and dataView.rect[1] then
		shadeRect("dialog", dataView.rect[1], dataView.rect[2], dataView.rect[3], dataView.rect[4])
	elseif dialog and dialogBox[1] then
		shadeRect("dialog", dialogBox[1], dialogBox[2], dialogBox[3], dialogBox[4])
	else
		shadeRect("dialog")
	end

	-- The list the picker drops, which stands clear of the control and over the rows.
	local opts = setPicker and setPicker:isOpen() and setPicker.optRects
	if opts and opts[1] then
		shadeRect("picker", opts[1].x1, opts[#opts].y1, opts[1].x2, opts[1].y2)
	else
		shadeRect("picker")
	end
end

local function deleteGuishader()
	shadeRect("dialog")
	shadeRect("picker")
	dropFloat("dialog")
	dropFloat("picker")
	if backgroundGuishader ~= nil then
		if WG.guishader then
			WG.guishader.DeleteDlist("widgetselector")
		else
			glDeleteList(backgroundGuishader)
		end
		backgroundGuishader = nil
	end
end

-- Reads the hover state and answers a signature of everything the baked panel is painted
-- from. Same signature, same picture, so the display list is replayed as it is.
-- The accept button in a dialog appears the moment there is a name to save under, and
-- it is painted into the baked panel, so whether the field is empty is part of this.
-- The row at a visible index, and whether it has anything to clear. Both the hit test
-- and the click ask this, and a row can scroll out from under the cursor between them.
local function rowClearable(i)
	local row = i > 0 and model.rows[scroll + i]

	return (row and row.hasConfig) and row or nil
end

local function panelChanged(mx, my)
	hover.sb, hover.row, hover.sw, hover.tog, hover.bar = 0, 0, 0, 0, 0
	hover.clr, hover.dat, hover.star = 0, 0, 0
	hover.btn, hover.dlg = "", ""

	if dataView.name then
		-- The settings window takes the cursor outright, the same as a modal does: nothing
		-- behind it lights, because nothing behind it will answer a click. The hover fields
		-- are already cleared above, so there is nothing more to do here.
	elseif dialog then
		-- A modal takes the cursor outright: lighting anything behind it would say it could
		-- still be clicked.
		local _, blocked = dialogName()
		if not blocked and math_isInRect(mx, my, dialogOk[1], dialogOk[2], dialogOk[3], dialogOk[4]) then
			hover.dlg = "ok"
		elseif math_isInRect(mx, my, dialogCancel[1], dialogCancel[2], dialogCancel[3], dialogCancel[4]) then
			hover.dlg = "cancel"
		end
	else
		hover.sb = sidebarIndexAt(mx, my) or 0
		for i = 1, #switches do
			local h = switches[i].hit
			if h and math_isInRect(mx, my, h[1], h[2], h[3], h[4]) then
				hover.tog = i
			end
		end

		if hover.tog ~= 0 then
			-- A switch has it; nothing behind it lights.
		elseif mx >= listX1 and mx <= listRight then
			hover.row = rowAt(my) or 0
			-- The switch lights on its own, so it is plain that it is the thing being pointed
			-- at rather than the row behind it. The clear button at the other end the same, and
			-- only on the rows that have one.
			if hover.row > 0 and mx >= switchX1 - metrics.rowPad and mx <= metrics.starHit1 then
				hover.sw = 1
			-- The star warms towards the colour it would turn rather than lighting a plate: a
			-- click on it does something other than what a click on the row does, so it has to
			-- say what before it is made.
			elseif hover.row > 0 and mx >= metrics.starHit1 and mx <= metrics.starHit2 then
				hover.star = 1
			elseif hover.row > 0 and mx >= clearX1 and rowClearable(hover.row) then
				hover.clr = 1
			elseif hover.row > 0 and mx >= metrics.dataX1 and rowClearable(hover.row) then
				hover.dat = 1
			end
		elseif mx >= barX1 and mx <= area.x2 then
			local top, height = scrollerThumb()
			if top and my <= top and my >= top - height then
				hover.bar = 1
			end
		end
		-- Written out rather than looped over a { buttons, setButtons } literal: that literal
		-- is a table built and thrown away on every frame the panel is open.
		for i = 1, #model.buttons do
			local r = model.buttons[i].rect
			if r and math_isInRect(mx, my, r[1], r[2], r[3], r[4]) then
				hover.btn = model.buttons[i].id
			end
		end
		for i = 1, #setButtons do
			local r = setButtons[i].rect
			if r and math_isInRect(mx, my, r[1], r[2], r[3], r[4]) then
				hover.btn = setButtons[i].id
			end
		end
	end

	-- Compared one value at a time against the last frame's rather than joined into a
	-- string. This runs on every frame the panel is open, and a string built every frame
	-- is a string collected every frame; the two tables here are filled in place and
	-- never replaced.
	local now, was = sweep.now, sweep.was
	now[1] = hover.sb
	now[2] = hover.row
	now[3] = hover.sw
	now[4] = hover.tog
	now[5] = hover.bar
	now[6] = hover.clr
	now[17] = hover.dat
	now[7] = filters.profiler
	now[8] = hover.btn
	now[9] = hover.dlg
	now[10] = scroll
	now[11] = model.rowsGen
	now[12] = layoutGen
	now[13] = catScroll
	now[14] = dragging
	now[15] = dialog ~= nil
	-- Only asked while a dialog is actually up: answering it trims the field with a gsub,
	-- and a gsub on every frame the panel is open is a string on every frame.
	now[16] = dialog ~= nil and select(2, dialogName()) or false
	now[18] = hover.star

	local changed = false
	for i = 1, 18 do
		if was[i] ~= now[i] then
			was[i] = now[i]
			changed = true
		end
	end

	return changed
end

----------------------------------------------------------------
-- Callins
----------------------------------------------------------------

-- True once FlowUI and the font handler are up and everything taken from them is bound.
-- Nothing is drawn or laid out before that.
local function bindUi()
	if not (WG.FlowUI and WG.FlowUI.Draw and WG.FlowUI.elementCorner and WG.fonts and WG.fonts.getFont) then
		return false
	end

	font = WG.fonts.getFont()
	model.font = font
	-- The monospaced face, for the cost columns and the stored-settings listing. Figures that change several times
	-- a second wander sideways in a proportional face as the digits under them change,
	-- which turns a column that should be read at a glance into one that has to be
	-- re-read. Fixed widths hold the decimal point still.
	look.mono = WG.fonts.getFont(3)
	elementCorner = WG.FlowUI.elementCorner
	RectRound = WG.FlowUI.Draw.RectRound
	UiElement = WG.FlowUI.Draw.Element
	UiButton = WG.FlowUI.Draw.Button
	UiScroller = WG.FlowUI.Draw.Scroller
	UiScrollerAt = WG.FlowUI.Draw.ScrollerGeometry
	Highlight = WG.FlowUI.Draw.SelectHighlight
	UiToggle = WG.FlowUI.Draw.Toggle

	if not searchBox then
		searchBox = Editbox.new({
			outline = look.outline,
			placeholder = L.search,
			-- It is focused from the moment the panel opens, so it would otherwise never show.
			keepPlaceholder = true,
			clearable = true,
			onChange = function()
				setScroll(0)
				rebuildRows()
			end,
		})
		-- Focused from the start: a panel opened before FlowUI was up had no field to focus yet,
		-- and a hidden panel never takes the keyboard.
		searchBox:focus()
		nameBox = Editbox.new({ outline = look.outline })
		setPicker = Dropdown.new({
			outline = look.outline,
			placeholder = L.noSet,
			onSelect = function(name)
				-- Picked, not loaded: Load is its own button, so choosing a set to delete does
				-- not switch every widget on the way past.
				model.pickedSet = name
				-- The placeholder is what the picker shows until something is picked, and it
				-- wins over the selection while it is set.
				refreshSets()
			end,
		})
	end

	uiBound = true

	return true
end

-- What the model asks of the window.
model.confirm = confirm
model.searchText = function()
	return searchBox and searchBox:getText()
end
model.onSetsChanged = refreshSets
model.onCategoriesBuilt = function()
	-- Fewer categories than before can leave the column scrolled past its own end.
	setCatScroll(catScroll)
end
model.onContentChanged = clampScroll
local refreshContent = model.refreshContent

function widget:ViewResize()
	vsx, vsy = spGetViewGeometry()
	widgetScale = (vsy / 1080)

	screenHeight = mathFloor(screenHeightOrg * widgetScale)
	screenWidth = mathFloor(screenWidthOrg * widgetScale)
	screenX = mathFloor((vsx * 0.5) - (screenWidth / 2))
	screenY = mathFloor((vsy * 0.5) + (screenHeight / 2))

	if not (uiBound or bindUi()) then
		return
	end
	-- Asked for again on every resize rather than kept from the first bind. The font handler deletes
	-- every font it has handed out when the view changes size, and it sits on a far lower layer, so
	-- its ViewResize has already run: the fonts from before are deleted fonts by now. Measuring with
	-- one took this widget down - and /widgetselector, F11 and the top bar button with it - until
	-- LuaUI was reloaded. FlowUI resizes its corner the same way, before any widget runs.
	if WG.fonts and WG.fonts.getFont then
		font = WG.fonts.getFont()
		model.font = font
		look.mono = WG.fonts.getFont(3)
	end
	if WG.FlowUI and WG.FlowUI.elementCorner then
		elementCorner = WG.FlowUI.elementCorner
	end

	setLayout()
	rebuildRows()
	dropLists()
	deleteGuishader()
end

local function closePanel()
	show = false
	dialog = nil
	if setPicker then
		setPicker:close()
	end
	shadeRect("dialog")
	shadeRect("picker")
	dropFloat("dialog")
	dropFloat("picker")
	if searchBox then
		searchBox:blur()
	end
	if WG.tooltip then
		WG.tooltip.RemoveTooltip("widgetselector")
	end
end

local function setShow(state)
	if state == show then
		return
	end

	if state then
		-- Before `show` is set, not after: hideWindows closes every window that says it is
		-- visible, and this panel is one of them. Setting the flag first makes it close the
		-- one it is in the middle of opening, which looks exactly like nothing happening.
		if WG.topbar then
			WG.topbar.hideWindows()
		end
	end

	show = state
	if show then
		Spring.SetConfigInt("widgetselector", 1)
		if not uiBound then
			widget:ViewResize()
		end
		-- Still nothing to draw with: FlowUI or the font handler is not running, which is what switching
		-- one of them off leaves after the next reload. This panel draws with both and is the way to
		-- switch them back on, so asking for it brings them back rather than opening a panel that can
		-- never appear. Queued, so it shows a few frames on, on the first frame that has them.
		if not uiBound then
			for _, name in ipairs({ "FlowUI", "Font handler" }) do
				local known = widgetHandler.knownWidgets[name]
				if known and not known.active then
					widgetHandler:EnableWidget(name)
				end
			end
		end
		refreshContent()
		-- Ready to type into; Update takes the keyboard next frame.
		if uiBound then
			searchBox:focus()
		end
	else
		closePanel()
	end
end

function widget:Initialize()
	model.loadLabels()
	model.buildButtons()

	widgetHandler.knownChanged = true
	-- F11 is left to the keymap. The shipped presets bind it to `luaui selector`, which the
	-- handler answers by toggling this panel, or by switching it back on when an error took it
	-- down, and a player who moves it in the keybind editor keeps it where they put it.
	-- Rebinding it here on every start undid that edit on the next launch.

	-- Lets the handler hide the rest of the interface while the list is open. This widget
	-- holds the real widgetHandler, so it passes itself.
	widgetHandler:RegisterModalWindow(widget, function()
		return show == true
	end)

	WG.widgetselector = {}
	WG.widgetselector.toggle = function(state)
		local newShow = state
		if newShow == nil then
			newShow = not show
		end
		setShow(newShow and true or false)
	end
	WG.widgetselector.isvisible = function()
		return show
	end
	WG.widgetselector.getLocalWidgetCount = function()
		return model.localWidgetCount
	end

	-- Deliberately before the layout: this is what /widgetselector and the top bar reach,
	-- and it has to work whether or not FlowUI has loaded yet.
	-- Text and key press both: typed as /widgetselector, and bound to a key by anyone who
	-- would rather not use F11.
	widgetHandler.actionHandler:AddAction(self, "widgetselector", function()
		setShow(not show)
		-- Holds the key it fired on. A preset saved while this widget still bound F11 to itself
		-- can carry this and `luaui selector` on one key, and a handler that declines lets the
		-- next action on that keyset toggle the panel straight back shut.
		return true
	end, nil, "tp")
	widgetHandler.actionHandler:AddAction(self, "factoryreset", function()
		factoryReset()
	end, nil, "t")
	widgetHandler.actionHandler:AddAction(self, "userwidgets", function()
		toggleUserWidgets()
	end, nil, "t")

	widget:ViewResize()
	refreshContent()
end

function widget:Shutdown()
	deleteGuishader()
	dropLists()
	-- Or every widget in the game keeps a wrapper round every callin for the rest of the
	-- session, measuring into a table nobody is left to read.
	profiling.unsubscribe(widget)
	if WG.tooltip then
		WG.tooltip.RemoveTooltip("widgetselector")
	end
	WG.widgetselector = nil
	model.holdKeyboard(false)
end

function widget:LanguageChanged()
	model.loadLabels()
	model.buildButtons()
	if searchBox then
		searchBox.placeholder = L.search
	end
	refreshContent()
	setLayout()
	dropLists()
end

function widget:Update()
	-- Kept up whether or not the panel is open: the averages are a running figure, and one
	-- that starts from nothing every time the panel is opened would read as every widget
	-- being free for the first few seconds. The include only does the work on a tick.
	-- The column may have been switched on by the config, before there was a handler far
	-- enough along to wrap. Anything that leaves the two disagreeing is settled here.
	model.syncProfiling()

	-- Back up after a reload this panel asked for. Only `"restore"`, never `"asked"`: the
	-- panel that asked is still open and still running, and clearing the flag here would
	-- take it back before the handler ever gets to write it down. Waits for FlowUI the way
	-- the first open does, and clears itself, so closing the panel cannot reopen it.
	if filters.reopen == "restore" and (uiBound or bindUi()) then
		filters.reopen = nil
		widget:ViewResize()
		setShow(true)
	end

	-- Only the row under the cursor is broken down per callin: the include smooths one
	-- widget at a time, and nothing reads more than one at once.
	if filters.profiler then
		local over = show and hover.row > 0 and model.rows[scroll + hover.row]
		profiling.setDetail(over and over.name or nil)
	end

	if filters.profiler and profiling.sample() and filters.byLoad and show then
		-- Ordering by cost means the list moves under the cursor, and a row that slides
		-- away between aiming at it and clicking it is how the wrong widget gets switched
		-- off. So while the cursor is anywhere over the list the order is held exactly as
		-- it is, and catches up the moment the cursor leaves. The figures on each row keep
		-- moving throughout: it is the order that is frozen, not the reading.
		local mx, my = spGetMouseState()
		if not math_isInRect(mx, my, listX1, listBottom, listRight, listTop) then
			rebuildRows()
			clampScroll()
		end
	end

	model.finishClear()

	if widgetHandler.knownChanged then
		widgetHandler.knownChanged = false
		refreshContent()
	elseif show and model.contentMoved(scroll, mathFloor((listTop - listBottom) / metrics.rowHeight)) then
		refreshContent()
	end

	-- While a dialog is asking for a name it owns the keyboard too, or nothing typed
	-- into it arrives.
	-- widgetHandler:KeyPress tries the text owner first, then the action bindings, and only
	-- then the widgets. So a panel that does not own the keyboard never sees Escape: the
	-- binding has already closed something by the time its own KeyPress would run. Anything
	-- here that has to answer Escape itself therefore has to own it.
	local wantsInput = show
		and uiBound
		and (dataView.name ~= nil or (dialog and dialog.field) or (not dialog and searchBox and searchBox:isFocused()))
	model.holdKeyboard(wantsInput)
end

function widget:DrawScreen()
	if not (show or showOnceMore) then
		deleteGuishader()
		return
	end
	-- The first frame that has FlowUI is where this one gets laid out, since Initialize
	-- ran before FlowUI existed.
	if not uiBound then
		if not bindUi() then
			return
		end
		widget:ViewResize()
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

	-- Answers whether anything painted into the baked panel moved. It has to run even
	-- when nothing did, since that is how it finds out.
	if panelChanged(show and mx or -1, show and my or -1) or not panelList then
		if panelList then
			glDeleteList(panelList)
		end
		panelList = glCreateList(drawPanel)
	end

	if not windowList then
		windowList = glCreateList(drawWindow)
	end
	glCallList(windowList)
	glCallList(panelList)
	if show and not dialog then
		drawCostColumns()
	end
	-- Live, over the baked panel: a text field's caret blinks and its contents change as
	-- it is typed into, and the picker's list opens over the rows.
	if show then
		if dataView.name then
			dropFloat("picker")
			drawFloating("dialog", dataView.draw)
		elseif dialog then
			dropFloat("picker")
			drawFloating("dialog", function()
				drawDialog(dialog)
				if dialog.field then
					nameBox:draw()
				end
			end)
		else
			dropFloat("dialog")
			searchBox:draw()
			if setPicker:isOpen() then
				drawFloating("picker", function()
					setPicker:draw()
				end)
			else
				dropFloat("picker")
				setPicker:draw()
			end
		end
		-- After the picker has laid its list out, so the blur behind it is the right size
		-- on the frame the list appears rather than the one after.
		updateShading()
	end

	if WG.guishader and backgroundGuishader == nil then
		backgroundGuishader = glCreateList(function()
			RectRound(screenX, screenY - screenHeight, screenX + screenWidth, screenY, elementCorner, 1, 1, 1, 1)
		end)
		WG.guishader.InsertDlist(backgroundGuishader, "widgetselector", nil, widget)
	end
	showOnceMore = false

	if math_isInRect(mx, my, screenX, screenY - screenHeight, screenX + screenWidth, screenY) then
		Spring.SetMouseCursor("cursornormal")

		if WG.tooltip and not dialog then
			showTooltip(hover.row > 0 and model.rows[scroll + hover.row] or nil)
		end
	end
end

----------------------------------------------------------------
-- Input
----------------------------------------------------------------

function widget:KeyPress(key, _mods, _isRepeat, _label, _unicode, _scanCode, actions)
	if not show or not uiBound then
		return false
	end

	-- Innermost first: the settings window is over everything, so Escape closes it before
	-- anything else is considered.
	if dataView.name then
		if key == KEYSYMS.ESCAPE then
			dataView.shut()
		end

		return true
	end

	if dialog then
		if key == KEYSYMS.ESCAPE then
			closeDialog()
		elseif key == KEYSYMS.RETURN then
			local typed, blocked = dialogName()
			if not blocked then
				local d = closeDialog()
				if d then
					d.accept(typed)
				end
			end
		elseif dialog.field then
			-- Everything else is typing. Escape and Return are handled above, which is why the
			-- box never sees them.
			nameBox:keyPress(key)
		end

		return true
	end

	-- Escape takes one thing down at a time, innermost first, and only closes the panel
	-- once there is nothing left over it: the picker's open list, then the search that
	-- made the list being read, then the panel itself.
	if key == KEYSYMS.ESCAPE then
		if setPicker:isOpen() then
			setPicker:close()

			return true
		end
		if searchBox:getText() ~= "" then
			searchBox:setText("")
		else
			showOnceMore = true
			closePanel()
		end

		return true
	end

	if searchBox:isFocused() then
		-- Let the panel's own toggle (F11) through, or the focused field would swallow it.
		for _, bound in ipairs(actions or {}) do
			if bound.command == "widgetselector" or (bound.command == "luaui" and bound.extra == "selector") then
				return false
			end
		end
		searchBox:keyPress(key)

		return true
	end

	return false
end

function widget:KeyRelease(key)
	if not show or not uiBound then
		return false
	end
	-- The window and a dialog swallow releases as well as presses: the key answered by
	-- either must not fire whatever it is bound to on the way back up.
	if dataView.name then
		return true
	end
	if dialog then
		return dialog.field == true
	end
	if not searchBox:isFocused() then
		return false
	end

	return not model.heldAtFocus(key)
end

function widget:TextInput(utf8char)
	if not (show and uiBound) then
		return false
	end
	-- The settings window owns the keyboard while it is up, so nothing typed at it leaks
	-- into the search field behind it.
	if dataView.name then
		return true
	end
	if dialog then
		return dialog.field and nameBox:textInput(utf8char) or false
	end
	if searchBox:isFocused() then
		return searchBox:textInput(utf8char)
	end

	return false
end

-- Swallowed across the whole panel, not just the list: a wheel that gets through zooms
-- the camera behind it.
function widget:MouseWheel(up, _value)
	if not show or not uiBound then
		return false
	end

	local x, y = spGetMouseState()
	if not math_isInRect(x, y, screenX, screenY - screenHeight, screenX + screenWidth, screenY) then
		return false
	end
	if dialog then
		return true
	end
	-- The chat history's modifiers: Ctrl moves three notches' worth at once, Shift a whole
	-- page of whatever is being scrolled.
	local _, ctrl, _, shift = Spring.GetModKeyState()
	-- The settings window takes the wheel while it is up: it is the thing being read.
	if dataView.name then
		local step = shift and mathMax(1, dataView.page) or (ctrl and 9 or 3)
		dataView.setScroll(dataView.scroll + (up and -step or step))

		return true
	end

	-- Over the column it scrolls the column, over anything else the list. A wheel that
	-- moved the list while the cursor was on the categories would read as broken.
	if x <= area.x1 + metrics.sidebarW and y > categoryBottom() and y <= sidebarTop() then
		setCatScroll(catScroll + (up and -1 or 1))
	else
		local step = shift and pageRows() or (ctrl and metrics.wheelRows * 3 or metrics.wheelRows)
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

local function click()
	if playSounds then
		Spring.PlaySoundFile(buttonclick, 0.6, "ui")
	end
end

-- A press inside the panel goes to the modal, the field, the switches, the column, the
-- scrollbar, a row or a footer button; a press outside closes it.
local function mouseEvent(x, y, button, release)
	if spIsGUIHidden() or not show or not uiBound then
		return false
	end

	-- A press on a top bar button is the top bar's to handle: it closes the open windows
	-- and opens the one that was clicked.
	if WG.topbar and WG.topbar.buttonAt and WG.topbar.buttonAt(x, y) then
		return false
	end

	local inside = math_isInRect(x, y, screenX, screenY - screenHeight, screenX + screenWidth, screenY)

	if dialog then
		-- The modal owns every press while it is up, inside the panel or out, so a stray
		-- click cannot dismiss it or reach what it is asking about.
		if not release and button == 1 then
			if dialog.field and nameBox:mousePress(x, y) then
				return true
			end
			local typed, blocked = dialogName()
			if not blocked and math_isInRect(x, y, dialogOk[1], dialogOk[2], dialogOk[3], dialogOk[4]) then
				local d = closeDialog()
				click()
				if d then
					d.accept(typed)
				end
			elseif math_isInRect(x, y, dialogCancel[1], dialogCancel[2], dialogCancel[3], dialogCancel[4]) then
				closeDialog()
				click()
			end
		end

		return true
	end

	if inside then
		if not release and button == 1 then
			-- The picker first: while it is open its list is over the rows, and they must not
			-- take a click meant for it.
			if setPicker:mousePress(x, y) then
				searchBox:blur()
				click()
				return true
			end
			if searchBox:mousePress(x, y) then
				return true
			end
			searchBox:blur()

			for _, b in ipairs(setButtons) do
				local r = b.rect
				if r and math_isInRect(x, y, r[1], r[2], r[3], r[4]) then
					click()
					if b.id == "loadset" then
						applySet(model.pickedSet)
					elseif b.id == "saveset" then
						confirm(L.saveSetTitle, L.saveSetWarn, saveSet, false, true, model.pickedSet)
					else
						local name = model.pickedSet
						confirm(L.deleteSetTitle, L.deleteSetWarn, function()
							deleteSet(name)
						end, true)
					end

					return true
				end
			end

			local i = sidebarIndexAt(x, y)
			local hitSwitch
			for n = 1, #switches do
				local h = switches[n].hit
				if h and math_isInRect(x, y, h[1], h[2], h[3], h[4]) then
					hitSwitch = switches[n].key
				end
			end
			if hitSwitch then
				model.toggleFilter(hitSwitch)
				-- The rank column appears and disappears with the sort, so the columns move.
				setLayout()
				-- The column counts what the filters leave, so they still say what clicking one
				-- of them would show.
				buildCategories()
				setScroll(0)
				rebuildRows()
				click()
			elseif i then
				selectCategory(model.categories[i].key)
			elseif math_isInRect(x, y, barX1, listBottom, area.x2, listTop) then
				grabScroller(y)
			else
				for _, b in ipairs(model.buttons) do
					local r = b.rect
					if r and math_isInRect(x, y, r[1], r[2], r[3], r[4]) then
						click()
						model.buttonAction(b.id)

						return true
					end
				end
			end
		end

		-- Which row the press landed on, remembered by name: the list can be rebuilt between
		-- the press and the release, so an index would not still mean the same widget.
		local overRow
		if math_isInRect(x, y, listX1, listBottom, listRight, listTop) then
			local r = rowAt(y)
			overRow = r and model.rows[scroll + r] or nil
		end

		-- The buttons are part of the row, so the press has to remember which of them was under
		-- the cursor: releasing over the row after pressing one would otherwise toggle the
		-- widget. One value rather than a flag per button, since only one can be under it.
		local onButton
		if overRow and x >= metrics.starHit1 and x <= metrics.starHit2 then
			onButton = "star"
		elseif overRow and overRow.hasConfig and x >= clearX1 and x <= listRight then
			onButton = "clear"
		elseif overRow and overRow.hasConfig and x >= metrics.dataX1 and x < clearX1 then
			onButton = "data"
		end
		if not release then
			pressedRow = overRow and overRow.name or nil
			pressedButton = button
			pressedOn = onButton
		elseif overRow and overRow.name == pressedRow and button == pressedButton then
			-- A click, rather than a drag that happened to finish over a row.
			if button == 1 and (onButton or pressedOn) then
				-- Both halves of the click have to be on the same button. Pressing one and sliding
				-- off before letting go is how a player takes an accidental press back.
				if onButton == pressedOn then
					if onButton == "star" then
						-- A bookmark either way, so it asks nothing and can be taken back by clicking
						-- again. The column has to be rebuilt as well as the rows: starring the first
						-- widget is what puts Favourites in it, and unstarring the last takes it out.
						fav.toggle(overRow.name)
						buildCategories()
						rebuildRows()
						-- Held where it was rather than sent back to the top: unstarring a row inside
						-- Favourites shortens the list under the cursor, and nothing else moved.
						clampScroll()
					elseif onButton == "data" then
						dataView.open(overRow.name)
					-- Named rather than left as an else: this is the branch that throws settings
					-- away, and a button added later must not fall through into it.
					elseif onButton == "clear" then
						local name = overRow.name
						local running = overRow.state == 1
						confirm(L.cleardataTitle, clearDataWarning(name, running), function()
							clearConfigData(name)
						end, true)
					end
					click()
				end
			elseif button == 1 then
				model.clickRow(overRow, 1)

				click()
			elseif button == 2 or button == 3 then
				model.clickRow(overRow, button)
			end
		end
		if release then
			pressedRow, pressedButton, pressedOn = nil, 0, nil
		end

		return true
	elseif not release then
		-- Only a press outside closes. A release out here belongs to a drag that started on
		-- the scrollbar.
		showOnceMore = true
		closePanel()

		return true
	end
end

function widget:MousePress(x, y, button)
	-- The settings window is over everything, so it answers first: a press meant for it
	-- must not fall through to the rows underneath.
	if dataView.name and dataView.press(x, y) then
		return true
	end

	return mouseEvent(x, y, button, false)
end

function widget:MouseRelease(x, y, button)
	-- The window owns the release as well as the press: a drag down its bar can end with
	-- the cursor anywhere, and that must not read as a click on a row behind it.
	if dataView.name then
		dataView.dragging = false

		return true
	end

	return mouseEvent(x, y, button, true)
end

function widget:GetConfigData()
	return model.getConfigData()
end

function widget:SetConfigData(data)
	model.setConfigData(data)
end
