local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Widget Selector",
		desc = "Widget selection widget",
		author = "trepan, jK, Bluestone, Floris",
		date = "Jan 8, 2007",
		license = "GNU GPL, v2 or later",
		layer = 999999,
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
local Editbox = VFS.Include("luaui/Include/keybind_editbox.lua")
local Dropdown = VFS.Include("luaui/Include/keybind_dropdown.lua")
local text = VFS.Include("luaui/Include/keybind_text.lua")
local KEYSYMS = VFS.Include("luaui/Include/keybind_keysyms.lua")
local Search = VFS.Include("luaui/Include/search.lua")

-- Localized functions for performance
local mathFloor = math.floor
local mathMax = math.max

-- Localized Spring API for performance
local spGetViewGeometry = Spring.GetViewGeometry
local spGetMouseState = Spring.GetMouseState
local spIsGUIHidden = Spring.IsGUIHidden
local spEcho = Spring.Echo
local spSendCommands = Spring.SendCommands
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
	buttonFill = { 0.18, 0.18, 0.18, 1 },
	-- Anything that cannot be undone without a reload. The same stops the keybind
	-- editor's destructive buttons use, so the two panels read alike.
	dangerFill = { 0.46, 0.1, 0.1, 1 },
	dangerFillHover = { 0.66, 0.14, 0.14, 1 },
	-- And the other half of that pair: an accept that saves something.
	confirmFill = { 0.17, 0.38, 0.21, 1 },
	confirmFillHover = { 0.24, 0.52, 0.29, 1 },
	scrim = { 0, 0, 0, 0.55 },
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
local colorTitle = "\255\235\235\235"
local colorName = "\255\145\143\140"
local colorNameOn = "\255\248\248\248"
local colorDesc = "\255\105\105\105"
local colorDescOn = "\255\175\175\175"
local colorSelected = "\255\210\210\205"
local colorDim = "\255\160\160\160"
local colorText = "\255\235\235\235"
-- A widget the player wrote or dropped in themselves, rather than one the game ships.
-- Enabled but not running: warm, because nothing is actually happening.
local colorPending = "\255\255\210\135"
local colorLocal = "\255\130\175\230"
local colorDanger = "\255\255\190\190"

-- Filename prefixes, spelled out. Everything the game ships carries one; a widget with a
-- prefix that is not here - which is most of what a player writes - falls into Other, so
-- this list stays a curation of the game's own rather than a catch-all that grows a
-- category out of every typo.
local GROUPS = {
	gui = "interface",
	cmd = "commands",
	unit = "units",
	gfx = "graphics",
	camera = "camera",
	snd = "sound",
	map = "map",
	minimap = "minimap",
	api = "api",
	dbg = "debug",
}
-- The column's order, which is by what a player is most likely to be looking for rather
-- than by how many widgets each holds.
local GROUP_ORDER = {
	"interface",
	"commands",
	"units",
	"camera",
	"graphics",
	"sound",
	"map",
	"minimap",
	"api",
	"debug",
}
local OTHER = "other"

local L = {}

local show, showOnceMore
local panelList, windowList, backgroundGuishader, panelSig
local listTop, listBottom, listX1, listRight, descX1, barX1 = 0, 0, 0, 0, 0, 0
local switchX1, orderX1, nameX1 = 0, 0, 0
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
-- The header switches, right to left from the panel's edge. Each carries the rects it
-- was last laid out with, so adding one is an entry here rather than another pair of
-- locals threaded through the layout, the draw, the hover test and the press.
local switches = {
	{ key = "localOnly" },
	{ key = "enabledOnly" },
	{ key = "byOrder" },
}

-- Every widget the panel can show, as rows; and the categories they fall into.
local entries = {}
-- The same entries, by name, for the staleness scan below.
local entryByName = {}
local categories = {}
local rows = {}
local rowsGen = 0
local layoutGen = 0
local scroll = 0
local dragging = false
local dragGrab = 0
local localWidgetCount = 0
local allowuserwidgets = true
---@type string?
local selectedCategory
-- What the header switches are set to, keyed the way they name themselves so a switch is
-- one entry in the list above and one field here.
--
-- `localOnly` keeps the player's own files. `enabledOnly` keeps anything the config says
-- to load, whether or not it is running. `byOrder` sorts by where each widget sits in the
-- handler's list rather than by name, which is the only way the load order can be seen.
local filters = { localOnly = false, enabledOnly = false, byOrder = false }
---@type table
local searchBox
---@type table
-- The name field the save dialog puts up. Its own, rather than the search field: a
-- dialog must not disturb what was typed in the panel behind it.
local nameBox
---@type table
local setPicker

-- Named sets of widgets. A set is the list of widgets that were enabled when it was
-- saved; applying one switches on everything in it and switches off everything else, so
-- a set describes a whole state rather than a patch to the current one.
--
-- Kept as an array so the picker's order is the order they were made in, which is stable
-- across sessions in a way that a hash's iteration order is not.
local sets = {}
-- The set showing in the picker. Choosing one only picks it: loading, saving over and
-- deleting are each their own button, so picking a set to delete does not load it on the
-- way past.
---@type string?
local pickedSet

-- The buttons under the picker. Load and Delete need a set picked and are not drawn
-- without one; Save always has something to save.
local setButtons = {
	{ id = "loadset" },
	{ id = "saveset" },
	{ id = "deleteset" },
}
-- The action buttons along the bottom, rebuilt on layout.
local buttons = {}
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

local hover = { sb = 0, row = 0, sw = 0, tog = 0, bar = 0, btn = "", dlg = "" }

-- Input ownership, taken once when the search field takes focus and given back when it
-- loses it. `widgetHandler:OwnText()` is not available here: it is built onto the
-- per-widget wrapper barwidgets hands out, and this widget asks for the real handler
-- (handler = true), which carries the textOwner field itself and none of the sugar.
local ownsInput = false
local fieldHasInput = false
local textInputStarted = false
local heldAtFocus = {}

-- FlowUI and the font handler are widgets too, and this one is inserted before them:
-- widgetHandler calls Initialize the moment a widget loads, so everything taken from
-- them is picked up on the first frame that has them rather than at Initialize, where
-- they do not exist yet. The old selector survived this by never doing arithmetic on
-- what it read; this one lays out against it, so it has to wait.
local uiBound = false

local rebuildRows
local setLayout

----------------------------------------------------------------
-- Content
----------------------------------------------------------------

-- Which of the three states a widget is in: 1 running, 0.5 enabled but not running, 0
-- off. The same numbers FlowUI's switch takes, so the control in front of a row says the
-- state without translating it.
local function stateOf(name, data)
	if data.active then
		return 1
	end
	local order = widgetHandler.orderList[name]
	if order and order >= 1 then
		return 0.5
	end

	return 0
end

-- Which column a widget belongs in, from the prefix on its filename.
local function groupOf(data)
	local base = data.basename or ""
	local prefix = base:match("^(%a+)_")

	return (prefix and GROUPS[prefix]) or OTHER
end

-- One line of description, with the newlines a multi-line one carries turned into spaces:
-- this sits on the row beside the name, and the tooltip is where the whole thing lives.
local function oneLine(str)
	if not str or str == "" then
		return ""
	end
	str = string.gsub(str, "%s+", " ")

	return (string.gsub(str, "^%s*(.-)%s*$", "%1"))
end

-- Walks what the handler knows and builds the rows from it. Called when the handler says
-- its list changed, which covers a widget being toggled, loaded or removed.
-- Walks what the handler knows and builds the rows from it. Called when the handler says
-- its list changed, which covers a widget being toggled, loaded or removed.
local function buildEntries()
	local myName = widget:GetInfo().name
	entries = {}
	entryByName = {}
	localWidgetCount = 0

	-- Where each running widget sits in the handler's list. That index is the load order:
	-- SaveConfigData writes it out as orderList[name], and it is the order the call-ins
	-- run in. A widget that is not running has no place in it.
	local order, layer = {}, {}
	for i = 1, #widgetHandler.widgets do
		local w = widgetHandler.widgets[i]
		if w.whInfo then
			order[w.whInfo.name] = i
			layer[w.whInfo.name] = w.whInfo.layer
		end
	end

	for name, data in pairs(widgetHandler.knownWidgets) do
		-- The selector cannot list itself: toggling it off would take the list with it. The
		-- def exporter is a build tool rather than something to switch on in a game.
		if name ~= myName and name ~= "Write customparam.__def to files" and not data.hidden then
			local desc = oneLine(data.desc)
			entries[#entries + 1] = {
				name = name,
				data = data,
				group = groupOf(data),
				state = stateOf(name, data),
				order = order[name],
				layer = layer[name],
				desc = desc,
				isLocal = not data.fromZip,
				-- Lowercased once here rather than per keystroke: a search walks every one of
				-- these on every letter typed.
				searchName = string.lower(name),
				searchDesc = string.lower(desc),
				searchFile = string.lower(data.basename or ""),
				searchAuthor = string.lower(data.author or ""),
			}
			entryByName[name] = entries[#entries]
			if not data.fromZip then
				localWidgetCount = localWidgetCount + 1
			end
		end
	end
end

-- The column: All, then the game's own prefixes in a fixed order, then Other. A category
-- with nothing in it is left out rather than shown empty.
--
-- The counts follow the local filter, so each one says what clicking it would show. They
-- do not follow the search: that is transient, and a column of numbers flickering on
-- every letter typed is noise rather than information.
local function buildCategories()
	local counts, active, total, on = {}, {}, 0, 0
	for i = 1, #entries do
		local e = entries[i]
		if (not filters.localOnly or e.isLocal) and (not filters.enabledOnly or e.state > 0) then
			counts[e.group] = (counts[e.group] or 0) + 1
			total = total + 1
			if e.data.active then
				active[e.group] = (active[e.group] or 0) + 1
				on = on + 1
			end
		end
	end

	categories = { { key = nil, label = L.all, count = total, active = on } }
	for _, g in ipairs(GROUP_ORDER) do
		if counts[g] then
			categories[#categories + 1] = { key = g, label = L[g] or g, count = counts[g], active = active[g] or 0 }
		end
	end
	if counts[OTHER] then
		categories[#categories + 1] =
			{ key = OTHER, label = L.other, count = counts[OTHER], active = active[OTHER] or 0 }
	end

	-- Fewer categories than before can leave the column scrolled past its own end.
	setCatScroll(catScroll)

	-- A category the filter emptied cannot stay selected, or the list shows nothing with
	-- no way back to it.
	if selectedCategory then
		local found
		for _, c in ipairs(categories) do
			if c.key == selectedCategory then
				found = true
			end
		end
		if not found then
			selectedCategory = nil
		end
	end
end

local function buildContent()
	buildEntries()
	buildCategories()
end

-- By where they load, when the switch asks for it: what runs first is what draws first
-- and gets the call-ins first, and reading it off the list is the only way to see it.
-- Anything not running has no place in that order, so it follows, alphabetically.
local function sortByOrder(a, b)
	if a.order and b.order then
		return a.order < b.order
	end
	if a.order or b.order then
		return a.order ~= nil
	end

	return a.name < b.name
end

-- Mod widgets first and then the player's own, each alphabetical, with the profiler on
-- top: it is the one a player opens this panel to reach in a hurry.
local function sortEntries(a, b)
	if a.name == "Widget Profiler" then
		return true
	elseif b.name == "Widget Profiler" then
		return false
	end
	if a.isLocal ~= b.isLocal then
		return b.isLocal
	end

	return a.name < b.name
end

-- The rows the list shows: what the column, the search box and the filter toggle left.
-- A search ranks what it finds, so the closest answer is at the top; with no search the
-- authored order stands, since a list that reshuffles as it is read loses the reader.
rebuildRows = function()
	rows = {}
	rowsGen = rowsGen + 1

	local query = Search.query(searchBox and searchBox:getText())
	-- Filled once and rewritten per widget rather than allocated for each of them.
	local primary, secondary = { "" }, { "", "", "" }
	local scored = not query.empty and {} or nil

	for i = 1, #entries do
		local e = entries[i]
		if
			(not selectedCategory or e.group == selectedCategory)
			and (not filters.localOnly or e.isLocal)
			and (not filters.enabledOnly or e.state > 0)
		then
			if query.empty then
				rows[#rows + 1] = e
			else
				primary[1] = e.searchName
				secondary[1], secondary[2], secondary[3] = e.searchDesc, e.searchFile, e.searchAuthor
				-- Named by its name alone: a widget found only through its description or author
				-- is a guess, and a list of guesses is worse than a short list.
				local score = Search.score(query, primary, secondary)
				if score > 0 then
					scored[#scored + 1] = { e = e, score = score }
				end
			end
		end
	end

	if scored then
		table.sort(scored, function(a, b)
			if a.score ~= b.score then
				return a.score > b.score
			end

			return (filters.byOrder and sortByOrder or sortEntries)(a.e, b.e)
		end)
		for i = 1, #scored do
			rows[i] = scored[i].e
		end
	else
		table.sort(rows, filters.byOrder and sortByOrder or sortEntries)
	end
end

----------------------------------------------------------------
-- Rows and scrolling
----------------------------------------------------------------

local function pageRows()
	return mathMax(1, mathFloor((listTop - listBottom) / metrics.rowHeight))
end

local function maxScroll()
	return mathMax(0, #rows - pageRows())
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
	if not rows[scroll + i] then
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
		#rows * metrics.rowHeight,
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
	for i = 1, #sets do
		names[i] = sets[i].name
		if sets[i].name == pickedSet then
			selected = i
		end
	end
	setPicker.placeholder = (not pickedSet or #names == 0) and L.noSet or nil
	setPicker:setOptions(names)
	setPicker:setSelected(selected)
	-- Load and Delete come and go with the pick, and the block is a row shorter without
	-- them, so it has to be measured again.
	if uiBound then
		setLayout()
	end
end

-- What is switched on right now, as a set. Anything the config says to load counts,
-- running or not: a widget that failed to load this session is still part of what the
-- player asked for, and dropping it here would quietly lose it from the set.
local function currentSet()
	local names = {}
	for i = 1, #entries do
		local e = entries[i]
		if e.state > 0 then
			names[e.name] = true
		end
	end

	return names
end

local function findSet(name)
	for i = 1, #sets do
		if sets[i].name == name then
			return sets[i], i
		end
	end
end

-- Switches the widgets to match the set: everything in it on, everything else off. Both
-- halves matter - a set that only turned things on would drift further from what it
-- described every time it was applied.
local function applySet(name)
	local set = findSet(name)
	if not set then
		return
	end

	for i = 1, #entries do
		local e = entries[i]
		local want = set.widgets[e.name] == true
		if want and e.state == 0 then
			widgetHandler:EnableWidget(e.name)
		elseif not want and e.state > 0 then
			widgetHandler:DisableWidget(e.name)
		end
	end
end

-- Saves what is on now under a name, replacing a set of that name if there is one.
local function saveSet(name)
	name = name and name:gsub("^%s*(.-)%s*$", "%1") or ""
	if name == "" then
		return
	end

	local set = findSet(name)
	if set then
		set.widgets = currentSet()
	else
		sets[#sets + 1] = { name = name, widgets = currentSet() }
	end
	pickedSet = name
	widgetHandler:SaveConfigData()
	refreshSets()
end

local function deleteSet(name)
	local _, i = findSet(name)
	if not i then
		return
	end
	table.remove(sets, i)
	if pickedSet == name then
		pickedSet = nil
	end
	widgetHandler:SaveConfigData()
	refreshSets()
end

local function reloadLuaUI()
	spSendCommands("luarules reloadluaui")
end

local function disableAll()
	for i = 1, #entries do
		widgetHandler:DisableWidget(entries[i].name)
	end
	widgetHandler:SaveConfigData()
end

local function toggleUserWidgets()
	if widgetHandler.allowUserWidgets then
		widgetHandler.__allowUserWidgets = false
		spEcho("Disallowed user widgets, reloading...")
	else
		widgetHandler.__allowUserWidgets = true
		spEcho("Allowed user widgets, reloading...")
	end
	reloadLuaUI()
end

local function resetLuaUI()
	spSendCommands("luaui reset")
end

local function factoryReset()
	widgetHandler.__blankOutConfig = true
	reloadLuaUI()
end

-- What the wrapper's OwnText/DisownText do, against the real handler's own field.
local function ownText()
	if widgetHandler.textOwner then
		return widgetHandler.textOwner == widget
	end
	widgetHandler.textOwner = widget

	return true
end

local function disownText()
	if widgetHandler.textOwner == widget then
		widgetHandler.textOwner = nil
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

local function buttonAction(id)
	if id == "reload" then
		reloadLuaUI()
	elseif id == "disableall" then
		confirm(L.disableAll, L.disableAllWarn, disableAll, true)
	elseif id == "userwidgets" then
		confirm(
			widgetHandler.allowUserWidgets and L.disallowUser or L.allowUser,
			widgetHandler.allowUserWidgets and L.disallowUserWarn or L.allowUserWarn,
			toggleUserWidgets,
			widgetHandler.allowUserWidgets
		)
	elseif id == "reset" then
		confirm(L.reset, L.resetWarn, resetLuaUI, true)
	elseif id == "factory" then
		confirm(L.factoryDefaults, L.factoryWarn, factoryReset, true)
	end
end

----------------------------------------------------------------
-- Layout
----------------------------------------------------------------

local function sidebarTop()
	return listTop - metrics.sidebarDrop
end

-- `i` is the entry's place in `categories`, not its place on screen: the two differ by
-- however far the column is scrolled.
local function categoryRect(i)
	local top = sidebarTop() - (i - 1 - catScroll) * metrics.catRowHeight

	return area.x1, top - metrics.catRowHeight, area.x1 + metrics.sidebarW, top
end

-- The column runs from the title down to whatever the sets block leaves it.
local function categoryBottom()
	return setsTop
end

-- How many entries the column has room for, and how far it can be scrolled.
local function catPageRows()
	return mathMax(1, mathFloor((sidebarTop() - categoryBottom()) / metrics.catRowHeight))
end

local function maxCatScroll()
	return mathMax(0, #categories - catPageRows())
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
	if not categories[i] then
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
	-- What the switch leaves above and below itself inside the row. It is held the same
	-- distance from the accent bar down the left edge, so the air around it reads as even
	-- rather than pinched on one side.
	metrics.switchGap = mathFloor((metrics.rowHeight - metrics.switchH) * 0.5)
	switchX1 = listX1 + metrics.accentW + metrics.switchGap
	-- The rank gets a column of its own only while the list is in that order: a number
	-- nobody is reading is clutter, and the name is worth the room.
	orderX1 = switchX1 + metrics.switchW + metrics.rowPad * 2
	metrics.orderW = 0
	if filters.byOrder then
		metrics.orderW = font and mathFloor(font:GetTextWidth("8888") * metrics.rowFs) or mathFloor(34 * s)
	end
	nameX1 = orderX1 + metrics.orderW + (metrics.orderW > 0 and metrics.rowPad * 2 or 0)
	listTop = area.y2 - metrics.headerH - metrics.headerGap
	local footerTop = area.y1 + metrics.footerH
	listBottom = footerTop + metrics.footerGap
	barX1 = area.x2 - metrics.edgeInset - metrics.barW
	listRight = barX1 - metrics.listGap
	descX1 = listX1 + mathFloor((listRight - listX1) * metrics.descSplit)

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
	for i = 1, #switches do
		local sw = switches[i]
		sw.label = L[sw.key]
		local w = font and mathFloor(font:GetTextWidth(sw.label) * metrics.toggleFs) or mathFloor(90 * s)
		sw.draw = { x2 - togW, togY1, x2, togY1 + togH }
		-- The caption is part of the control: a switch this small is a poor click target on
		-- its own, and the words beside it are what names the thing being switched.
		sw.hit = { sw.draw[1] - metrics.rowPad * 2 - w - metrics.captionBleed, rowBottom, x2 + metrics.rowPad, rowTop }
		x2 = sw.hit[1] - mathFloor(14 * s)
	end

	-- Wider than the gaps inside a switch, so the last caption reads as belonging to the
	-- switch beside it rather than to the field it would otherwise sit against.
	searchBox:setRect(listX1, rowBottom, switches[#switches].hit[1] - mathFloor(28 * s), rowTop, fs)

	-- The sets block, measured up from the foot of the category card.
	local setsPad = mathFloor(8 * s)
	local pickH = mathFloor(metrics.rowHeight * 1.1)
	local setBtnH = mathFloor(metrics.rowHeight * 1.0)
	metrics.setsFs = mathFloor(metrics.rowHeight * 0.5)
	-- One row of buttons without a set picked, two with.
	local buttonRows = pickedSet and 2 or 1
	local topOfButtons
	setsTop = listBottom + setsPad * (buttonRows + 2) + pickH + setBtnH * buttonRows + metrics.catRowHeight

	local sx1 = area.x1 + metrics.catInset + setsPad
	local sx2 = area.x1 + metrics.sidebarW - metrics.catInset - setsPad
	-- Save and Delete share a row; Load takes one of its own above them, being the one
	-- reached for most and the one whose label must not be cut at a narrow sidebar.
	local pairTop = listBottom + setsPad + setBtnH
	local half = mathFloor((sx2 - sx1 - setsPad) * 0.5)
	if pickedSet then
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
	local n = #buttons
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
			buttons[i].rect = { bx1, by1, (i == n) and fx2 or (bx1 + bw), by2 }
		end
	end
	metrics.buttonFs = mathFloor(metrics.rowHeight * 0.55)
	-- What the tag at the end of a local row takes, so a description can be kept out of it.
	metrics.localTagW = font and mathFloor(font:GetTextWidth(L.islocal) * metrics.rowFs) or mathFloor(30 * s)

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
	local avail = metrics.sidebarW - metrics.sidePad * 2 - mathFloor(46 * widgetScale)
	for _, c in ipairs(categories) do
		local label = text.fit(font, c.label, avail, metrics.catFs)
		c.textDim = colorDim .. label
		c.textSel = colorSelected .. label
		-- What is on out of what there is. The count of enabled widgets is the thing worth
		-- knowing at a glance; the total is what says how much there is to look through.
		c.countText = colorDim .. c.active .. "/" .. c.count
		c.fitGen = layoutGen
	end
end

-- Cuts a row's name and description to their columns, once per row per layout.
local function fitRow(row)
	if row.fitGen == layoutGen then
		return
	end
	row.fitGen = layoutGen

	local nameColor = colorName
	local descColor = colorDesc
	if row.state == 1 then
		nameColor, descColor = colorNameOn, colorDescOn
	elseif row.state == 0.5 then
		nameColor, descColor = colorPending, colorDescOn
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
		local descW = listRight - descX1 - metrics.rowPad * 2
		if row.isLocal then
			descW = descW - metrics.localTagW - metrics.rowPad
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
	for i = 1, #textQueue do
		local t = textQueue[i]
		font:Print(t[1], t[2], t[3], t[4], t[5])
	end
	font:End()
	textQueue = {}
end

local function drawRow(row, top, bottom, hovered, overSwitch)
	fitRow(row)

	local fill = (row.state == 1 and look.activeFill) or (row.state == 0.5 and look.pendingFill)
	local accent = (row.state == 1 and look.activeAccent) or (row.state == 0.5 and look.pendingAccent)
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
	queueText(row.fitName, nameX1, ty, metrics.rowFs, "ov")
	if row.fitDesc then
		queueText(row.fitDesc, descX1, ty, metrics.rowFs, "ov")
	end
	if row.isLocal then
		-- The one thing about a widget that is not in its name or its description, and the
		-- thing a player most needs to tell apart: their own files from the game's.
		queueText(colorLocal .. L.islocal, listRight - metrics.rowPad, ty, metrics.rowFs, "rov")
	end
end

local function drawRows()
	for i = 1, #rows - scroll do
		local row = rows[scroll + i]
		if not row then
			break
		end
		local top = listTop - (i - 1) * metrics.rowHeight
		local bottom = top - metrics.rowHeight
		if bottom < listBottom then
			break
		end
		drawRow(row, top, bottom, hover.row == i, hover.row == i and hover.sw == 1)
	end
end

local function drawButtonFace(r, fill)
	local pair = look.gradients[fill]

	UiButton(r[1], r[2], r[3], r[4], 1, 1, 1, 1, 1, 1, 1, 1, nil, pair[1], pair[2])
end

-- The sets block at the foot of the column. The picker draws itself, live, since it can
-- open over the list.
local function drawSetsBlock()
	queueText(colorDim .. L.sets, area.x1 + metrics.sidePad, metrics.setsCaptionY, metrics.catFs, "ov")

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
	RectRound(
		area.x1,
		listBottom,
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
	queueText(colorTitle .. L.title, area.x1 + metrics.sidePad, area.y2 - metrics.titleY, metrics.titleFs, "ov")

	if categories[1] and categories[1].fitGen ~= layoutGen then
		fitCategories()
	end

	for i = catScroll + 1, #categories do
		local c = categories[i]
		local x1, y1, x2, y2 = categoryRect(i)
		if y1 < categoryBottom() then
			break
		end
		local selected = selectedCategory == c.key
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
		queueText(selected and c.textSel or c.textDim, x1 + metrics.sidePad, ty, metrics.catFs, "ov")
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
			#categories * metrics.catRowHeight,
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
		drawSwitch(sw.draw, sw.hit, sw.label, filters[sw.key], hover.tog == i)
	end
end

local function drawFooter()
	for _, b in ipairs(buttons) do
		local r = b.rect
		if r then
			local hovered = hover.btn == b.id
			local fill = b.danger and (hovered and look.dangerFillHover or look.dangerFill) or nil
			drawButtonFace(r, fill or look.buttonFill)
			-- A tinted button would lose its colour under the white overlay, so it brightens
			-- its own fill above instead.
			if hovered and not fill then
				Highlight(r[1], r[2], r[3], r[4], metrics.csButton, look.hoverOpacity, look.white)
			end
			queueText(
				(b.danger and colorDanger or colorText) .. (b.label or ""),
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
	RectRound(area.x1, area.y1, area.x2, area.y2, 0, 0, 0, 0, 0, look.scrim)
	UiElement(bx1, by1, bx2, by2, 1, 1, 1, 1, 1, 1, 1, 1, WG.FlowUI.clampedOpacity)

	-- With nothing typed there is nothing to save, so the accept is not drawn at all: a
	-- button that cannot do anything is worse than no button.
	local _, blocked = dialogName()
	local buttons = { { r = dialogCancel, id = "cancel" } }
	if not blocked then
		-- Green when the accept saves something, red when it takes something away.
		buttons[2] = { r = dialogOk, id = "ok", danger = d.danger, confirm = d.field }
	end
	for _, b in ipairs(buttons) do
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
			(d.danger and colorDanger or colorText) .. (d.field and L.save or L.confirm),
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

	if #rows > 0 then
		UiScroller(
			barX1,
			listBottom,
			area.x2 - metrics.edgeInset,
			listTop,
			#rows * metrics.rowHeight,
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
		panelSig = nil
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
	if dialog and dialogBox[1] then
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
local function panelSignature(mx, my)
	hover.sb, hover.row, hover.sw, hover.tog, hover.bar = 0, 0, 0, 0, 0
	hover.btn, hover.dlg = "", ""

	if dialog then
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
			-- at rather than the row behind it.
			if hover.row > 0 and mx >= switchX1 - metrics.rowPad and mx <= nameX1 - metrics.rowPad then
				hover.sw = 1
			end
		elseif mx >= barX1 and mx <= area.x2 then
			local top, height = scrollerThumb()
			if top and my <= top and my >= top - height then
				hover.bar = 1
			end
		end
		for _, set in ipairs({ buttons, setButtons }) do
			for _, b in ipairs(set) do
				local r = b.rect
				if r and math_isInRect(mx, my, r[1], r[2], r[3], r[4]) then
					hover.btn = b.id
				end
			end
		end
	end

	return hover.sb
		.. "|"
		.. hover.row
		.. "|"
		.. hover.sw
		.. "|"
		.. hover.tog
		.. "|"
		.. hover.bar
		.. "|"
		.. hover.btn
		.. "|"
		.. hover.dlg
		.. "|"
		.. scroll
		.. "|"
		.. rowsGen
		.. "|"
		.. layoutGen
		.. "|"
		.. catScroll
		.. "|"
		.. (dragging and 1 or 0)
		.. "|"
		.. (dialog and 1 or 0)
		.. "|"
		.. (select(2, dialogName()) and 1 or 0)
end

----------------------------------------------------------------
-- Callins
----------------------------------------------------------------

-- Has anything been switched on or off since the rows were built?
--
-- Asking every frame the panel is open is what it takes. The handler queues Toggle,
-- Enable and Disable and runs them once the callin that asked has returned, so the state
-- cannot be read back on the click itself; and a widget can be switched from somewhere
-- else entirely - the settings panel, a /luaui command, one erroring out on load - which
-- nothing here would otherwise hear about. `knownChanged` does not cover it: the handler
-- raises that only when a widget it has never seen registers.
--
-- A few hundred table lookups on a frame where a panel is being looked at.
local function contentMoved()
	for i = 1, #entries do
		local e = entries[i]
		if e.state ~= stateOf(e.name, e.data) then
			return true
		end
	end

	-- And the load order, which moves without any state changing: raising or lowering a
	-- widget only shifts it within the handler's list, and that is queued like the rest.
	for i = 1, #widgetHandler.widgets do
		local w = widgetHandler.widgets[i]
		local e = w.whInfo and entryByName[w.whInfo.name]
		if e and e.order ~= i then
			return true
		end
	end

	return false
end

local function refreshContent()
	buildContent()
	-- The picker follows: a set can be saved or forgotten between one build and the next.
	refreshSets()
	rebuildRows()
	clampScroll()
end

local function loadLabels()
	local function tr(key, fallback)
		return BAR.I18N("ui.widgetselector." .. key, { default = fallback })
	end

	L.title = tr("title", "Widget Selector")
	L.all = tr("category.all", "All")
	L.interface = tr("category.interface", "Interface")
	L.commands = tr("category.commands", "Commands")
	L.units = tr("category.units", "Units")
	L.graphics = tr("category.graphics", "Graphics")
	L.camera = tr("category.camera", "Camera")
	L.sound = tr("category.sound", "Sound")
	L.map = tr("category.map", "Map")
	L.minimap = tr("category.minimap", "Minimap")
	L.api = tr("category.api", "API")
	L.debug = tr("category.debug", "Debug")
	L.other = tr("category.other", "Other")

	L.search = tr("search", "Search...")
	L.localOnly = tr("localonly", "Local only")
	L.enabledOnly = tr("enabledonly", "Enabled only")
	L.byOrder = tr("byorder", "By load order")
	L.sets = tr("sets", "Widget sets")
	L.noSet = tr("noset", "No set")
	L.loadset = tr("loadset", "Load")
	L.saveset = tr("saveset", "Save")
	L.deleteset = tr("deleteset", "Delete")
	L.save = L.saveset
	L.saveSetTitle = tr("savesettitle", "Save widget set")
	L.saveSetWarn = tr(
		"savesetwarn",
		"Remembers which widgets are switched on right now under this name. Saving over a name you already have replaces it."
	)
	L.deleteSetTitle = tr("deletesettitle", "Delete widget set")
	L.deleteSetWarn = tr("deletesetwarn", "Forgets this set. The widgets it switched on stay as they are.")
	L.factoryDefaults = tr("factorydefaults", "Factory defaults")
	L.islocal = tr("islocal", "local")
	L.stateOn = tr("state.on", "Running")
	L.statePending = tr("state.pending", "Enabled, but not running")
	L.stateOff = tr("state.off", "Off")
	L.file = tr("file", "File")
	L.author = tr("author", "Author")

	L.cancel = tr("cancel", "Cancel")
	L.confirm = tr("confirm", "Confirm")
	L.reload = tr("button_reloadluaui", "Reload LuaUI")
	L.disableAll = tr("button_unloadallwidgets", "Unload All Widgets")
	L.disallowUser = tr("button_disallowuserwidgets", "Disallow User Widgets")
	L.allowUser = tr("button_allowuserwidgets", "Allow User Widgets")
	L.reset = tr("button_resetluaui", "Reset LuaUI")

	L.factoryWarn = tr(
		"factorydefaultswarn",
		"This throws away every interface setting you have: which widgets are on, their positions, and anything you have configured in them. LuaUI reloads immediately. It cannot be undone."
	)
	L.disableAllWarn = tr(
		"unloadallwarn",
		"Switches off every widget in the list at once. Your settings are kept, and you can switch them back on one at a time."
	)
	L.disallowUserWarn = tr(
		"disallowuserwarn",
		"Stops loading widgets from your own LuaUI folder, leaving only the ones the game ships. LuaUI reloads immediately."
	)
	L.allowUserWarn = tr(
		"allowuserwarn",
		"Loads widgets from your own LuaUI folder again alongside the ones the game ships. LuaUI reloads immediately."
	)
	L.resetWarn = tr(
		"resetwarn",
		"Puts every widget back to the set the game enables by default. Widgets you added stay on disk. LuaUI reloads immediately."
	)
	-- Said plainly, because raise and lower do not move a widget by one place: they send
	-- it to the front or the back of the band of widgets sharing its layer, and it can
	-- never leave that band.
	L.hint = tr("hint", "Click to toggle.  Right-click sends it to the front of its layer, middle-click to the back.")
	L.order = tr("order", "Load order")
	L.layer = tr("layer", "Layer")
end

local function buildButtons()
	buttons = {
		{ id = "reload", label = L.reload },
		{ id = "disableall", label = L.disableAll, danger = true },
		{
			id = "userwidgets",
			label = widgetHandler.allowUserWidgets and L.disallowUser or L.allowUser,
			danger = widgetHandler.allowUserWidgets,
		},
		{ id = "reset", label = L.reset, danger = true },
		{ id = "factory", label = L.factoryDefaults, danger = true },
	}
	if not allowuserwidgets then
		table.remove(buttons, 3)
	end
end

-- True once FlowUI and the font handler are up and everything taken from them is bound.
-- Nothing is drawn or laid out before that.
local function bindUi()
	if not (WG.FlowUI and WG.FlowUI.Draw and WG.FlowUI.elementCorner and WG.fonts and WG.fonts.getFont) then
		return false
	end

	font = WG.fonts.getFont()
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
			placeholder = L.search,
			onChange = function()
				setScroll(0)
				rebuildRows()
			end,
		})
		nameBox = Editbox.new({})
		setPicker = Dropdown.new({
			placeholder = L.noSet,
			onSelect = function(name)
				-- Picked, not loaded: Load is its own button, so choosing a set to delete does
				-- not switch every widget on the way past.
				pickedSet = name
				-- The placeholder is what the picker shows until something is picked, and it
				-- wins over the selection while it is set.
				refreshSets()
			end,
		})
	end

	uiBound = true

	return true
end

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
		refreshContent()
	else
		closePanel()
	end
end

function widget:Initialize()
	loadLabels()
	buildButtons()

	widgetHandler.knownChanged = true
	-- barwidgets binds F11 to `luaui selector`, which looks for a loaded widget whose
	-- basename is exactly selector.lua and otherwise tries to load LuaUI/selector.lua.
	-- Neither is this file, so the key does nothing at all. Pointed at the action instead,
	-- which is the same thing /widgetselector reaches.
	spSendCommands({ "unbindkeyset f11", "bind f11 widgetselector" })

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
		return localWidgetCount
	end

	-- Deliberately before the layout: this is what /widgetselector and the top bar reach,
	-- and it has to work whether or not FlowUI has loaded yet.
	-- Text and key press both: typed as /widgetselector, and bound to a key by anyone who
	-- would rather not use F11.
	widgetHandler.actionHandler:AddAction(self, "widgetselector", function()
		setShow(not show)
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
	if WG.tooltip then
		WG.tooltip.RemoveTooltip("widgetselector")
	end
	WG.widgetselector = nil
	if ownsInput then
		ownsInput = false
		disownText()
	end
	if textInputStarted then
		textInputStarted = false
		if Spring.SDLStopTextInput then
			Spring.SDLStopTextInput()
		end
	end
end

function widget:LanguageChanged()
	loadLabels()
	buildButtons()
	if searchBox then
		searchBox.placeholder = L.search
	end
	refreshContent()
	setLayout()
	dropLists()
end

function widget:Update()
	if widgetHandler.knownChanged then
		widgetHandler.knownChanged = false
		refreshContent()
	elseif show and contentMoved() then
		refreshContent()
	end

	-- While a dialog is asking for a name it owns the keyboard too, or nothing typed
	-- into it arrives.
	local wantsInput = show
		and uiBound
		and ((dialog and dialog.field) or (not dialog and searchBox and searchBox:isFocused()))
	if wantsInput then
		if not fieldHasInput then
			fieldHasInput = true
			heldAtFocus = Spring.GetPressedKeys and Spring.GetPressedKeys() or {}
			ownsInput = ownText()

			-- Chat has to be asked to let go, and toggling its input flag is the only public
			-- way to make it cancel. The flag goes straight back because gui_chat persists it.
			if not ownsInput and WG.chat and WG.chat.isInputActive and WG.chat.isInputActive() then
				WG.chat.setHandleInput(false)
				WG.chat.setHandleInput(true)
				ownsInput = ownText()
			end
		elseif not ownsInput then
			ownsInput = ownText()
		end

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
			disownText()
		end
		if textInputStarted then
			textInputStarted = false
			if Spring.SDLStopTextInput then
				Spring.SDLStopTextInput()
			end
		end
	end
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
	-- Live, over the baked panel: a text field's caret blinks and its contents change as
	-- it is typed into, and the picker's list opens over the rows.
	if show then
		if dialog then
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

		local row = not dialog and hover.row > 0 and rows[scroll + hover.row]
		if row and WG.tooltip then
			local d = row.data
			-- The same three states the row is painted in, said in words: green is running,
			-- amber is enabled but not running, red is off.
			local stateColor, stateWord = "\255\255\160\160", L.stateOff
			if row.state == 1 then
				stateColor, stateWord = "\255\130\255\160", L.stateOn
			elseif row.state == 0.5 then
				stateColor, stateWord = "\255\255\240\160", L.statePending
			end
			local title = stateColor .. row.name .. "\n"

			local maxWidth = WG.tooltip.getFontsize() * 90
			local tip = stateColor .. stateWord .. "\n"
			if d.desc and d.desc ~= "" then
				tip = tip
					.. "\255\255\255\255"
					.. string.gsub(font:WrapText(d.desc, maxWidth), "[\n]", "\n\255\255\255\255")
					.. "\n"
			end
			if d.author and d.author ~= "" then
				tip = tip .. "\255\175\175\175" .. L.author .. ":  " .. d.author .. "\n"
			end
			if row.order then
				tip = tip
					.. "\255\175\175\175"
					.. L.order
					.. ":  "
					.. row.order
					.. "   ("
					.. L.layer
					.. " "
					.. tostring(row.layer)
					.. ")"
					.. "\n"
			end
			tip = tip
				.. "\255\175\175\175"
				.. L.file
				.. ":  "
				.. (d.basename or "")
				.. (row.isLocal and "   (" .. L.islocal .. ")" or "")
				.. "\n\255\130\130\130"
				.. L.hint
			WG.tooltip.ShowTooltip("widgetselector", tip, nil, nil, title)
		end
	end
end

----------------------------------------------------------------
-- Input
----------------------------------------------------------------

function widget:KeyPress(key)
	if not show or not uiBound then
		return false
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
		searchBox:keyPress(key)

		return true
	end

	return false
end

function widget:KeyRelease(key)
	if not show or not uiBound then
		return false
	end
	-- A dialog swallows releases as well as presses: the key that was typed into it must
	-- not fire whatever it is bound to on the way back up.
	if dialog then
		return dialog.field == true
	end
	if not searchBox:isFocused() then
		return false
	end

	if heldAtFocus[key] then
		heldAtFocus[key] = nil

		return false
	end

	return true
end

function widget:TextInput(utf8char)
	if not (show and uiBound) then
		return false
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

	-- Over the column it scrolls the column, over anything else the list. A wheel that
	-- moved the list while the cursor was on the categories would read as broken.
	if x <= area.x1 + metrics.sidebarW and y > categoryBottom() and y <= sidebarTop() then
		setCatScroll(catScroll + (up and -1 or 1))
	else
		setScroll(scroll + (up and -metrics.wheelRows or metrics.wheelRows))
	end

	return true
end

local function selectCategory(key)
	if selectedCategory == key then
		return
	end
	selectedCategory = key
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
						applySet(pickedSet)
					elseif b.id == "saveset" then
						confirm(L.saveSetTitle, L.saveSetWarn, saveSet, false, true, pickedSet)
					else
						local name = pickedSet
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
				filters[hitSwitch] = not filters[hitSwitch]
				-- The rank column appears and disappears with the sort, so the columns move.
				setLayout()
				-- The column counts what the filters leave, so they still say what clicking one
				-- of them would show.
				buildCategories()
				setScroll(0)
				rebuildRows()
				click()
			elseif i then
				selectCategory(categories[i].key)
			elseif math_isInRect(x, y, barX1, listBottom, area.x2, listTop) then
				grabScroller(y)
			else
				for _, b in ipairs(buttons) do
					local r = b.rect
					if r and math_isInRect(x, y, r[1], r[2], r[3], r[4]) then
						click()
						buttonAction(b.id)

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
			overRow = r and rows[scroll + r] or nil
		end

		if not release then
			pressedRow = overRow and overRow.name or nil
			pressedButton = button
		elseif overRow and overRow.name == pressedRow and button == pressedButton then
			-- A click, rather than a drag that happened to finish over a row.
			if button == 1 then
				widgetHandler:ToggleWidget(overRow.name)

				click()
			elseif button == 2 or button == 3 then
				local w = widgetHandler:FindWidget(overRow.name)
				if w then
					if button == 2 then
						widgetHandler:LowerWidget(w)
					else
						widgetHandler:RaiseWidget(w)
					end
					widgetHandler:SaveConfigData()
				end
			end
		end
		if release then
			pressedRow, pressedButton = nil, 0
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
	return mouseEvent(x, y, button, false)
end

function widget:MouseRelease(x, y, button)
	return mouseEvent(x, y, button, true)
end

function widget:GetConfigData()
	return {
		localOnly = filters.localOnly,
		enabledOnly = filters.enabledOnly,
		byOrder = filters.byOrder,
		category = selectedCategory,
		sets = sets,
		pickedSet = pickedSet,
	}
end

function widget:SetConfigData(data)
	if type(data) ~= "table" then
		return
	end
	filters.localOnly = data.localOnly == true
	-- Rebuilt rather than taken as read: this comes off disk, and a malformed entry here
	-- would otherwise reach the picker and the apply.
	sets = {}
	if type(data.sets) == "table" then
		for _, saved in ipairs(data.sets) do
			if type(saved) == "table" and type(saved.name) == "string" and type(saved.widgets) == "table" then
				local names = {}
				for name in pairs(saved.widgets) do
					if type(name) == "string" then
						names[name] = true
					end
				end
				sets[#sets + 1] = { name = saved.name, widgets = names }
			end
		end
	end
	pickedSet = type(data.pickedSet) == "string" and data.pickedSet or nil
	filters.enabledOnly = data.enabledOnly == true
	filters.byOrder = data.byOrder == true
	selectedCategory = type(data.category) == "string" and data.category or nil
end
