local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Options",
		desc = "",
		author = "Floris",
		date = "September 2016",
		license = "GNU GPL, v2 or later",
		layer = -99990,
		enabled = true,
		handler = true,
	}
end

-- The window showing the settings. The settings themselves and what they do are in
-- luaui/Include/options: new ones go in rows/<tab>.lua.
local model = VFS.Include("luaui/Include/options/model.lua")
local upkeep = model.upkeep
local types = model.types
local getOption, showOption, getOptionLabel = model.getOption, model.showOption, model.getOptionLabel
local sliderRange, sliderValueText, NearestValue = model.sliderRange, model.sliderValueText, model.NearestValue
local inactive = model.inactive
local applyOptionValue, applyOptionValueByID = model.applyOptionValue, model.applyOptionValueByID

local optionColor = "\255\255\255\255"
local widgetOptionColor = "\255\160\160\160"
local advOptionColor = "\255\180\160\140"
local advMainOptionColor = "\255\255\235\200"
local devOptionColor = "\255\200\110\100"
local devMainOptionColor = "\255\245\166\140"

local playSounds = true
local sounds = {
	buttonClick = "LuaUI/Sounds/tock.wav",
	paginatorClick = "LuaUI/Sounds/buildbar_waypoint.wav",
	sliderDrag = "LuaUI/Sounds/buildbar_rem.wav",
	selectClick = "LuaUI/Sounds/buildbar_click.wav",
	selectUnfoldClick = "LuaUI/Sounds/buildbar_hover.wav",
	selectHoverClick = "LuaUI/Sounds/hover.wav",
	toggleOnClick = "LuaUI/Sounds/switchon.wav",
	toggleOffClick = "LuaUI/Sounds/switchoff.wav",
}

local vsx, vsy = Spring.GetViewGeometry()

local screenHeightOrg = 610
local screenWidthOrg = 950
-- the window's sizes in pixels at 1080p, and how its list is laid out
local tuning = {
	controlsWidth = 200, -- the column the controls share; sliders and dropdowns span it
	controlsAlignLeft = true, -- toggles at the left edge of that column, else at its right end
	compactColumns = 2, -- toggles per line in grids: notifications, playlist tracks, auto cloak units
	rowHeight = 25, -- a setting's row; its controls scale with it, and section headings are 1.35x
	fontSize = 14, -- setting names and values; the switch captions scale with it
	controlFontSize = 12.5, -- the text in the controls: a dropdown's choice and a slider's value
	dropdownFontSize = 12.5, -- the entries of an open dropdown
	headingFontSize = 14, -- section headings in the list
	categoryHeight = 29, -- a tab's row in the column
	categoryFontSize = 14, -- the tabs in the column; a tab's name over its search results is 1.25x
	subcategoryHeight = 25, -- a section's row under the open tab in the column
	subcategoryFontSize = 14, -- the sections under the open tab in the column
	descriptionLines = 3, -- lines under the setting's name in the strip below the list
	rowHighlight = true, -- light up the row under the mouse (what folds a family always lights up)
}
local screenHeight = screenHeightOrg
local screenWidth = screenWidthOrg

local centerPosX = 0.5
local centerPosY = 0.5
local screenX = math.floor((vsx * centerPosX) - (screenWidth / 2))
local screenY = math.floor((vsy * centerPosY) + (screenHeight / 2))

local show = false

local os_clock = os.clock
local math_isInRect = math.isInRect

local backgroundGuishader, currentGroupTab, windowList
---@type LuaFont, LuaFont
local font, font2
local initialized = false
local checkedWidgetDataChanges
local sliderValueChanged, selectOptionsList, prevSelectHover
local fontOption, lastSliderSound, selectClickAllowHide, selectScrollOffset
-- the option whose dropdown is open, and the slider being dragged
---@type table?
local openSelect
---@type table?
local draggingSlider
local guishaderWasActive = false

local glColor = gl.Color
local glTexRect = gl.TexRect
local glTexture = gl.Texture
local glCreateList = gl.CreateList
local glCallList = gl.CallList
local glDeleteList = gl.DeleteList
local glBlending = gl.Blending
local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_ONE = GL.ONE

local RectRound, elementCorner, elementMargin, elementPadding, UiElement, UiSlider, UiSliderKnob, UiToggle, UiSelector, UiSelectHighlight, bgpadding
local UiScroller, UiScrollerAt

local widgetScale = (vsy / 1080)

-- The window, in the shape of the game info panel: the tabs and the open tab's sections in a
-- column on the left, that tab's settings in one list that scrolls, the search field and the
-- advanced switch above it, and below it a strip with the hovered setting's description.
-- look: its colors. metrics: its sizes, set from the screen size in view.setLayout. layout: where
-- the last DrawWindow put everything, read back by hover and clicks. view: what the list shows.
local look = {
	sidebarFill = { 0, 0, 0, 0.24 },
	sidebarFillTop = { 0, 0, 0, 0.16 },
	selectedFill = { 1, 1, 1, 0.13 },
	-- the section the list is showing, marked down its left edge
	sectionAccent = { 1, 0.78, 0.35, 0.7 },
	white = { 1, 1, 1 },
	hoverOpacity = 0.14,
	headingSheen = { 1, 1, 1, 0.05 },
	headingLine = { 1, 0.78, 0.51, 0.4 },
	headingLineFade = { 1, 0.78, 0.51, 0 },
	stripFill = { 0, 0, 0, 0.18 },
	stripFillTop = { 0, 0, 0, 0.12 },
	-- a row that does something when clicked lights up green
	clickRow = { 0.5, 1, 0.25 },
	controlHover = { 0.5, 0.5, 0.5, 0.22 },
	controlHoverTop = { 1, 1, 1, 0.22 },
	presetRow = { 0, 0, 0, 0.15 },
	presetRowTop = { 1, 1, 1, 0.15 },
	selectBorder = { 0, 0, 0, 0.25 },
	selectBack = { 0.3, 0.3, 0.3, 0.84 },
	selectBackTop = { 0.35, 0.35, 0.35, 0.84 },
	selectBackSolid = { 0.3, 0.3, 0.3, 0.94 },
	selectBackSolidTop = { 0.35, 0.35, 0.35, 0.94 },
	selectCurrent = { 1, 1, 1, 0.08 },
	scrollTrack = { 0.15, 0.15, 0.15, 0.85 },
	scrollThumb = { 0.65, 0.65, 0.65, 0.9 },
	chevron = { 1, 1, 1, 0.5 },
	chevronLit = { 1, 1, 1, 1 },
	-- the row picked by a click or the arrow keys
	selectedRow = { 1, 1, 1, 0.06 },
	title = "\255\235\235\235",
	heading = "\255\255\200\130",
	group = "\255\175\175\175",
	groupSelected = "\255\245\245\245",
	section = "\255\140\140\140",
	sectionLit = "\255\235\215\185",
	count = "\255\120\120\120",
	caption = "\255\160\160\160",
	captionOn = "\255\210\210\205",
	value = "\255\200\200\200",
	description = "\255\170\170\170",
	command = "\255\060\060\060",
	commandLit = "\255\200\200\200",
	restart = "\255\255\120\120",
	restartMark = "\255\255\090\090*",
	-- the sub-options of a widget that is switched off
	inactive = "\255\105\105\105",
}

local metrics = { wheelRows = 3 }

local layout = {
	window = { 0, 0, 0, 0 },
	area = { 0, 0, 0, 0 },
	rows = {} --[[@as table<integer, table>]],
	rowOf = {} --[[@as table<table, table>]],
	sidebar = {},
	selectItems = {},
	switch = { 0, 0, 0, 0 },
	switchHit = { 0, 0, 0, 0 },
	unfoldSwitch = { 0, 0, 0, 0 },
	unfoldSwitchHit = { 0, 0, 0, 0 },
	totalH = 0,
	-- the strip's /option command where a click copies it, with the command as [5]
	stripCommand = false --[[@as table|false]],
}

-- lines: what the list shows. scroll: the first line shown. scrollOf: where each tab was left.
-- folded: families folded or opened by hand; it and unfoldAll are kept in the config.
-- childCount: rows under each parent. startsOpen: the parents with a basic row that is not a cell.
-- matches/headingOf: per tab under a search, how many rows matched and where they start.
local view = {
	lines = {} --[[@as table<integer, table>]],
	scroll = 0,
	scrollOf = {},
	folded = {} --[[@as table<string, boolean>]],
	unfoldAll = false --[[@as boolean]],
	childCount = {} --[[@as table<table, integer>]],
	startsOpen = {} --[[@as table<table, boolean>]],
	matches = {},
	headingOf = {},
	dragging = false,
	dragGrab = 0,
	-- the heading last jumped to from the column, marked there until the list is scrolled otherwise
	litPin = false --[[@as table|false]],
	-- the row a click or the arrow keys picked, and the one the strip shows: that or the last hovered
	selected = false --[[@as table|false]],
	stripOption = false --[[@as table|false]],
	-- the open dropdown's entry the arrow keys are on
	selectKey = false --[[@as number|false]],
	-- a slider dragged with shift held, and where that started
	fineDrag = false --[[@as table|false]],
	-- when the strip's /option command was last copied
	copiedAt = -10 --[[@as number]],
	-- the open color picker: its option, FlowUI's picker and the value it opened on
	picker = false --[[@as table|false]],
	-- a press went to the picker, so its release does nothing else
	pickerHeld = false --[[@as boolean]],
}

-- the parts of the window, each drawing itself and recording in layout where it went
local draw = {}
-- per option type: draws the control at the right end of a row and returns where it starts
local drawControl = {}

-- Shared with the keybind editor and the game info panel.
local Editbox = require("luaui/Include/keybind_editbox")
local text = require("luaui/Include/keybind_text")
---@type table
local searchBox

model.onListChanged = function()
	view.build()
	view.refresh()
end
model.onRebuilt = function()
	view.rebind()
end

local showOnceMore = false -- used because of GUI shader delay

function view.resize()
	vsx, vsy = Spring.GetViewGeometry()

	widgetScale = (vsy / 1080)

	screenHeight = math.floor(screenHeightOrg * widgetScale)
	screenWidth = math.floor(screenWidthOrg * widgetScale)
	screenX = math.floor((vsx * centerPosX) - (screenWidth / 2))
	screenY = math.floor((vsy * centerPosY) + (screenHeight / 2))

	bgpadding = WG.FlowUI.elementPadding
	elementCorner = WG.FlowUI.elementCorner
	elementMargin = WG.FlowUI.elementMargin
	elementPadding = WG.FlowUI.elementPadding

	RectRound = WG.FlowUI.Draw.RectRound
	UiElement = WG.FlowUI.Draw.Element
	UiSlider = WG.FlowUI.Draw.Slider
	UiSliderKnob = WG.FlowUI.Draw.SliderKnob
	UiToggle = WG.FlowUI.Draw.Toggle
	UiSelector = WG.FlowUI.Draw.Selector
	UiSelectHighlight = WG.FlowUI.Draw.SelectHighlight
	UiScroller = WG.FlowUI.Draw.Scroller
	UiScrollerAt = WG.FlowUI.Draw.ScrollerGeometry

	font = WG.fonts.getFont()
	font2 = WG.fonts.getFont(2)

	if not searchBox then
		view.makeSearchBox()
	end
	view.setLayout()

	backgroundGuishader = glDeleteList(backgroundGuishader)
	view.build()
	view.refresh()
end

function widget:ViewResize()
	upkeep.viewResize()
	view.resize()
end

function widget:TextInput(char) -- if it isn't working: chobby probably hijacked it
	if not upkeep.chobbyInterface and not Spring.IsGUIHidden() and show then
		-- typing searches straight away; until then the field shows what it is for
		searchBox:focus()
		searchBox:textInput(char)
		if WG.limitidlefps and WG.limitidlefps.update then
			WG.limitidlefps.update()
		end
		return true
	end
end

-- the search field, kept in step with inputText; made again when the language changes
function view.makeSearchBox()
	searchBox = Editbox.new({
		placeholder = BAR.I18N("ui.gameInfo.search"),
		clearable = true,
		text = model.searchText,
		onChange = function(value)
			model.searchText = value
			view.scroll = 0
			model.applyFilter()
		end,
	})
end

-- Opening takes text input for the search field, so typing searches straight away; closing gives
-- it back. The search itself is kept for the next time.
function view.open()
	if not show and WG.topbar then
		WG.topbar.hideWindows()
	end
	show = true
	widgetHandler.textOwner = widget --widgetHandler:OwnText()
	Spring.SDLStartTextInput() -- because: touch chobby's text edit field once and widget:TextInput is gone for the game, so we make sure its started!
	if searchBox then
		-- other widgets may have changed settings while it was closed
		view.build()
		view.refresh()
	end
	model.forceUpdate = true -- Update reads again what can change elsewhere, like the window's size
end

function view.close()
	show = false
	openSelect = nil
	draggingSlider = nil
	view.closePicker()
	view.dragging = false
	backgroundGuishader = glDeleteList(backgroundGuishader)
	if WG.guishader then
		WG.guishader.RemoveDlist("options")
		if selectOptionsList then
			WG.guishader.RemoveScreenRect("options_select")
			WG.guishader.RemoveScreenRect("options_select_options")
			WG.guishader.removeRenderDlist(selectOptionsList)
		end
	end
	if selectOptionsList then
		selectOptionsList = glDeleteList(selectOptionsList)
	end
	Spring.SDLStopTextInput()
	widgetHandler.textOwner = nil --widgetHandler:DisownText()
	if searchBox then
		searchBox:blur()
	end
end

-- Main name color, and the one for sub-options and for what follows a prefix. Labels get one color.
local function getNameColors(option)
	if option.dimmed then
		return "\255\100\100\100", "\255\100\100\100"
	elseif option.category == types.dev then
		return devMainOptionColor, devOptionColor
	elseif option.category == types.advanced and (model.devMode or model.devUI) then
		return advMainOptionColor, advOptionColor
	elseif option.type == nil then
		return "\255\255\200\130"
	end
	return "\255\225\225\225", widgetOptionColor
end

-- what a line takes up in the list, with the gap a section leaves before the next heading
local function lineHeight(line)
	return line.h
end

-- what a line draws in, at the top of what it takes up
local function contentHeight(line)
	return line.kind == "heading" and metrics.headingHeight or metrics.rowHeight
end

-- r is { x1, y1, x2, y2 }; its edges count as inside
local function inRect(r, mx, my)
	return r ~= nil and math_isInRect(mx, my, r[1], r[2], r[3], r[4])
end

-- whitespace alone is not a search
function view.searching()
	return string.find(model.searchText, "%S") ~= nil
end

-- The header switch is the advanced one, or the developer UI's while that is on: it shows every
-- setting, so advanced does nothing then. A dev build shows everything and has no switch.
function view.switchCaption()
	if model.devUI and not model.devMode then
		return BAR.I18N("ui.settings.option.devmode")
	end
	return BAR.I18N("ui.settings.advanced")
end

-- indent levels: the rows under a section heading do not step in
local function indentOf(option)
	local n, parent = 0, option.parentOption
	while parent do
		if parent.type then
			n = n + 1
		end
		parent = parent.parentOption
	end
	return n
end

-- draws the window again into its display list
function view.refresh()
	if windowList then
		gl.DeleteList(windowList)
	end
	windowList = gl.CreateList(DrawWindow)
end

-- Whole pixels throughout, so edges and glyphs do not land between pixels.
function view.setLayout()
	local s = widgetScale
	local pad = math.floor(8 * s)
	layout.window = { screenX, screenY - screenHeight, screenX + screenWidth, screenY }
	local a = { screenX + pad, screenY - screenHeight + pad, screenX + screenWidth - pad, screenY - pad }
	layout.area = a

	metrics.rowHeight = math.floor(tuning.rowHeight * s)
	metrics.rowFs = math.floor(tuning.fontSize * s)
	metrics.dropdownFs = math.floor(tuning.dropdownFontSize * s)
	metrics.headingHeight = math.floor(metrics.rowHeight * 1.35)
	metrics.headingFs = math.floor(tuning.headingFontSize * s)
	metrics.sectionGap = math.floor(10 * s)
	metrics.tabHeadingFs = math.floor(tuning.categoryFontSize * s * 1.25)
	metrics.groupHeight = math.floor(tuning.categoryHeight * s)
	metrics.groupFs = math.floor(tuning.categoryFontSize * s)
	metrics.sectionHeight = math.floor(tuning.subcategoryHeight * s)
	metrics.sectionFs = math.floor(tuning.subcategoryFontSize * s)
	metrics.rowPad = math.floor(6 * s)
	metrics.sidePad = math.floor(12 * s)
	metrics.inset = math.floor(4 * s)
	metrics.headerH = math.floor(34 * s)
	metrics.gap = math.floor(12 * s)
	metrics.cardLip = math.floor(5 * s)
	metrics.titleY = math.floor(17 * s)
	metrics.titleFs = math.floor(tuning.fontSize * s * 1.55)
	metrics.sidebarW = math.floor(230 * s)
	metrics.barW = math.floor(14 * s)
	metrics.accentW = math.max(2, math.floor(3 * s))
	metrics.underlineH = math.max(1, math.floor(2 * s))
	metrics.indent = math.floor(18 * s)
	metrics.chevron = math.floor(8 * s)
	metrics.toggleW = math.floor(36 * s)
	metrics.toggleH = math.floor(metrics.rowHeight * 0.6)
	-- the text inside the controls, and the room a slider's value takes after its track
	metrics.controlFs = math.floor(tuning.controlFontSize * s)
	metrics.valueW = math.floor(tuning.controlFontSize * s * 4)
	metrics.stripLineH = math.floor(metrics.rowFs * 1.45)
	metrics.stripH = metrics.stripLineH * (1 + tuning.descriptionLines) + math.floor(10 * s)
	metrics.captionFs = math.floor(metrics.rowFs * 1.05)
	metrics.csPanel = math.floor(elementCorner)
	metrics.csSmall = math.floor(elementCorner * 0.66)
	metrics.selectPadding = math.floor(4 * s)
	metrics.selectScrollbar = math.max(3, math.floor(4 * s))
	metrics.selectBorder = math.max(1, math.floor(vsy / 900))
	-- the color picker, a little wider than it is tall for its square field
	metrics.pickerH = math.floor(metrics.rowHeight * 9.5)
	metrics.pickerW = math.floor(metrics.pickerH * 1.06)

	layout.sidebarTop = a[4] - metrics.headerH - metrics.inset - math.floor(8 * s)
	-- the column and the strip are cards side by side, as far apart as they are from the window edge
	layout.listX1 = a[1] + metrics.sidebarW + pad
	layout.listTop = a[4] - metrics.headerH - metrics.inset
	layout.stripTop = a[2] + metrics.stripH
	layout.listBottom = layout.stripTop + metrics.inset
	layout.barX1 = a[3] - metrics.inset - metrics.barW
	layout.listRight = layout.barX1 - metrics.gap
	-- the controls share a column, all starting on one line, with sliders and dropdowns across it
	metrics.controlW = math.floor(tuning.controlsWidth * s)

	-- the header band: the search field, then the unfold all and advanced switches, each with its caption
	local rowTop = a[4] - math.floor(4 * s)
	local rowBottom = a[4] - metrics.headerH + math.floor(4 * s)
	local togH = math.floor((rowTop - rowBottom) * 0.62)
	local togY1 = math.floor((rowTop + rowBottom) * 0.5) - math.floor(togH * 0.5)
	local togW = math.floor(38 * s)
	-- a click on a switch or its caption flips it
	local function hitArea(switch, caption)
		local captionW = math.floor(font:GetTextWidth(caption) * metrics.captionFs)
		return { switch[1] - metrics.rowPad * 2 - captionW, rowBottom, switch[3] + metrics.rowPad, rowTop }
	end
	local x2 = a[3] - metrics.inset
	layout.switch = { x2 - togW, togY1, x2, togY1 + togH }
	layout.switchHit = hitArea(layout.switch, view.switchCaption())
	local unfoldX2 = math.floor(layout.switchHit[1] - 16 * s)
	layout.unfoldSwitch = { unfoldX2 - togW, togY1, unfoldX2, togY1 + togH }
	layout.unfoldSwitchHit = hitArea(layout.unfoldSwitch, BAR.I18N("ui.settings.unfoldall"))
	searchBox:setRect(
		layout.listX1,
		rowBottom,
		layout.unfoldSwitchHit[1] - math.floor(28 * s),
		rowTop,
		math.floor((rowTop - rowBottom) * 0.5)
	)
end

-- A family is folded or opened by hand, or all open under "unfold all". Otherwise it starts folded
-- while its widget is off, and when it holds only advanced rows or a grid of toggles.
function view.isFolded(option)
	if not option.type then
		return false -- section headings do not fold
	end
	local folded = option.id and view.folded[option.id]
	if folded ~= nil then
		return folded
	end
	if view.unfoldAll then
		return false
	end
	if option.type == "bool" and option.widget ~= nil and not option.value then
		return true
	end
	return not view.startsOpen[option]
end

-- The list: section headings and the rows of the open tab, without the rows of folded families;
-- compact toggles share lines. Under a search, the matches of every tab, under a heading per tab.
function view.build()
	local lines, childCount, startsOpen = {}, {}, {}
	local searching = view.searching()
	-- only rows the list can show: a family of advanced rows has nothing to unfold in basic mode
	for _, option in ipairs(model.options) do
		local parent = option.parentOption
		if parent and option.name and showOption(option) then
			childCount[parent] = (childCount[parent] or 0) + 1
			if not option.compact and (not option.category or option.category == types.basic) then
				startsOpen[parent] = true
			end
		end
	end
	view.childCount, view.startsOpen = childCount, startsOpen
	view.matches, view.headingOf = {}, {}

	-- the open tab has to be one the column shows
	local valid
	for _, group in ipairs(model.groups) do
		if
			group.id == currentGroupTab
			and group.numOptions > 0
			and (model.devMode or model.devUI or group.id ~= "dev")
		then
			valid = true
		end
	end
	if not valid and model.groups[1] then
		currentGroupTab = model.groups[1].id
	end

	local cells
	local function add(option)
		if option.type == nil then
			if option.name then
				lines[#lines + 1] = { kind = "heading", option = option, text = option.name }
			end
			cells = nil
		elseif option.compact then
			if cells and #cells.cells < tuning.compactColumns and cells.parent == option.parentOption then
				cells.cells[#cells.cells + 1] = option
			else
				cells = { kind = "cells", cells = { option }, parent = option.parentOption, depth = indentOf(option) }
				lines[#lines + 1] = cells
			end
		else
			lines[#lines + 1] = { kind = "row", option = option }
			cells = nil
		end
	end
	local function folded(option)
		local parent = option.parentOption
		while parent do
			if childCount[parent] and view.isFolded(parent) then
				return true
			end
			parent = parent.parentOption
		end
		return false
	end

	if searching then
		for _, group in ipairs(model.groups) do
			for _, option in ipairs(model.options) do
				if option.group == group.id and option.name and showOption(option) then
					if not view.headingOf[group] then
						lines[#lines + 1] = { kind = "heading", group = group, text = group.name }
						view.headingOf[group] = #lines
						view.matches[group] = 0
						cells = nil
					end
					if option.type then
						view.matches[group] = view.matches[group] + 1
					end
					add(option)
				end
			end
		end
	else
		for _, option in ipairs(model.options) do
			if option.group == currentGroupTab and showOption(option) and not folded(option) then
				add(option)
			end
		end
	end

	-- a section leaves some room before the next heading, a tab's results more before the next tab's
	local off = 0
	for i, line in ipairs(lines) do
		local nextLine = lines[i + 1]
		line.h = contentHeight(line)
		if nextLine and nextLine.kind == "heading" and line.kind ~= "heading" then
			line.h = line.h + (nextLine.group and metrics.sectionGap * 2 or metrics.sectionGap)
		end
		line.off = off
		off = off + line.h
	end
	view.lines, layout.totalH = lines, off
	view.setScroll(view.scroll)
end

-- the furthest the first line can go with the band still full
function view.maxScroll()
	local band = (layout.listTop or 0) - (layout.listBottom or 0)
	local used, i = 0, #view.lines
	while i > 0 do
		local h = lineHeight(view.lines[i])
		if used + h > band then
			break
		end
		used = used + h
		i = i - 1
	end
	return i
end

function view.setScroll(n)
	view.scroll = math.max(0, math.min(n, view.maxScroll()))
end

-- pixels of the list above the first line shown
function view.offset()
	local first = view.lines[view.scroll + 1]
	return first and first.off or 0
end

-- how many lines the band holds from where the list is now, or going up, the page that ends there
function view.pageLines(up)
	local band, used, n = layout.listTop - layout.listBottom, 0, 0
	local from, to, dir = view.scroll + 1, #view.lines, 1
	if up then
		from, to, dir = view.scroll, 1, -1
	end
	for i = from, to, dir do
		used = used + lineHeight(view.lines[i])
		if used > band then
			break
		end
		n = n + 1
	end
	return math.max(1, n)
end

function view.scrollBy(n)
	local before = view.scroll
	view.setScroll(view.scroll + n)
	if view.scroll ~= before then
		view.litPin = false
		view.refresh()
	end
end

-- The heading the column marks (a tab heading under a search): the one last jumped to from the
-- column, as the list may not scroll far enough to bring it to the top; else at the end of the list
-- the last one, and otherwise the last one at or above the first line shown.
function view.litLine(tabsOnly)
	local lit, pinned
	local atEnd = view.scroll > 0 and view.scroll >= view.maxScroll()
	for i, line in ipairs(view.lines) do
		if line.kind == "heading" and (line.group or not tabsOnly) then
			if view.litPin and (line.option or line.group) == view.litPin then
				pinned = i
			end
			if atEnd or i <= view.scroll + 1 then
				lit = i
			end
		end
	end
	return pinned or lit
end

-- one of the window's sounds, unless they are off
function view.sound(name, volume)
	if playSounds then
		Spring.PlaySoundFile(sounds[name], volume, "ui")
	end
end

-- What the arrow keys go through, in order: each row, and each cell of a line of cells.
function view.selectable()
	local items = {} --[[@as table<integer, table>]]
	for i, line in ipairs(view.lines) do
		if line.kind == "row" then
			items[#items + 1] = { option = line.option, line = i }
		elseif line.kind == "cells" then
			for c, option in ipairs(line.cells) do
				items[#items + 1] = { option = option, line = i, cell = c }
			end
		end
	end
	return items
end

-- Scrolls as little as it takes to show line i whole, with the heading right above it going up.
---@param i integer
function view.scrollTo(i)
	local line = view.lines[i]
	if not line then
		return
	end
	local target = view.scroll
	if i <= view.scroll then
		target = i - 1
		if view.lines[i - 1] and view.lines[i - 1].kind == "heading" then
			target = i - 2
		end
	else
		local band = layout.listTop - layout.listBottom
		while target < i - 1 and line.off + contentHeight(line) - view.lines[target + 1].off > band do
			target = target + 1
		end
	end
	view.scrollBy(math.max(0, target) - view.scroll)
end

-- selects a row, shown in the strip, and scrolls it into view
function view.select(option, lineIndex)
	view.selected, view.stripOption = option, option
	if lineIndex then
		view.scrollTo(lineIndex)
	end
end

-- init() makes the options and tabs anew: what the window holds on to becomes the new one of its id
function view.rebind()
	local function same(item)
		if item and item.numOptions then
			for _, group in ipairs(model.groups) do
				if group.id == item.id then
					return group
				end
			end
		end
		return item and item.id and getOption(item.id) or false
	end
	view.selected, view.stripOption, view.litPin = same(view.selected), same(view.stripOption), same(view.litPin)
	openSelect, draggingSlider = same(openSelect) or nil, same(draggingSlider) or nil
	if view.picker then
		local option = same(view.picker.option)
		if option and option.type == "color" then
			view.picker.option = option
		else
			view.closePicker()
		end
	end
end

-- Up and down go a line along, in lines of cells to the same column; across goes a cell along. With
-- nothing selected yet, it starts at the first line shown, or going up the last one.
function view.moveSelection(dir, across)
	local items = view.selectable()
	local at = 0
	for i, item in ipairs(items) do
		if item.option == view.selected then
			at = i
		end
	end
	local target
	if at == 0 then
		local first, last
		for i, item in ipairs(items) do
			if item.line > view.scroll then
				first = first or i
				last = layout.rowOf[item.option] and i or last
			end
		end
		target = items[dir > 0 and (first or 1) or (last or first or #items)]
	elseif across then
		target = items[at + dir]
	else
		local from, i = items[at], at
		repeat
			i = i + dir
		until not items[i] or items[i].line ~= from.line
		if items[i] then
			local same = {}
			for _, item in ipairs(items) do
				if item.line == items[i].line then
					same[#same + 1] = item
				end
			end
			target = same[math.min(from.cell or 1, #same)]
		end
	end
	if target then
		view.select(target.option, target.line)
	end
end

-- moves a slider n steps along, or to the n-th next of its listed steps
function view.stepSlider(option, n)
	local min, max = sliderRange(option)
	local value
	if option.steps then
		local index = 1
		for i, v in ipairs(option.steps) do
			if math.abs(v - option.value) < math.abs(option.steps[index] - option.value) then
				index = i
			end
		end
		value = option.steps[math.max(1, math.min(#option.steps, index + n))]
	else
		local step = option.step or (max - min) / 100
		value = math.max(min, math.min(max, math.floor((option.value + n * step) / step + 0.5) * step))
	end
	if value ~= option.value then
		applyOptionValue(option, value)
		view.sound("sliderDrag", 0.3)
	end
end

-- Left and right on the selected row: a family folds or unfolds as in a tree (on a slider's row, which
-- they step, with ctrl), a slider steps (ten at a time with ctrl), a toggle goes off or on, and along
-- a line of cells the selection moves.
function view.adjustSelected(dir, ctrl)
	local option = view.selected
	if not (option and layout.rowOf[option]) then
		return
	end
	if option.compact then
		view.moveSelection(dir, true)
	elseif view.childCount[option] and not view.searching() and (ctrl or option.type ~= "slider") then
		view.folded[option.id] = dir < 0
		view.build()
		view.refresh()
	elseif option.type == "slider" then
		view.stepSlider(option, ctrl and dir * 10 or dir)
	elseif option.type == "bool" and option.value ~= (dir > 0) then
		applyOptionValue(option, dir > 0)
		view.sound(dir > 0 and "toggleOnClick" or "toggleOffClick", 0.75)
	end
end

-- Enter on the selected row: flips a toggle, opens a dropdown or a color picker, runs a row's click,
-- or folds a row with no control.
function view.activateSelected()
	local option = view.selected
	if not (option and layout.rowOf[option]) then
		return
	end
	if option.type == "bool" then
		applyOptionValue(option, not option.value)
		view.sound(option.value and "toggleOnClick" or "toggleOffClick", 0.75)
	elseif option.type == "select" then
		openSelect = option
		view.selectKey = tonumber(option.value) or 1
		selectScrollOffset = math.max(0, view.selectKey - 8)
		view.sound("selectUnfoldClick", 0.6)
	elseif option.type == "color" then
		view.openPicker(option)
	elseif option.onclick then
		option.onclick(option)
	elseif view.childCount[option] and not view.searching() then
		view.adjustSelected(view.isFolded(option) and 1 or -1, true)
	end
end

-- Tab and shift-tab: the next tab in the column, or the one before, round the end
function view.cycleTab(dir)
	local tabs, at = {}, 1
	for _, group in ipairs(model.groups) do
		if group.numOptions > 0 and (model.devMode or model.devUI or group.id ~= "dev") then
			tabs[#tabs + 1] = group
			if group.id == currentGroupTab then
				at = #tabs
			end
		end
	end
	if #tabs > 0 then
		view.openTab(tabs[(at - 1 + dir) % #tabs + 1])
	end
end

-- a small triangle: pointing right while its family is folded, down while it is open
local chevron = { x = 0, y = 0, h = 0, folded = false }
local function chevronVertices()
	local x, y, h = chevron.x, chevron.y, chevron.h
	if chevron.folded then
		gl.Vertex(x, y + h)
		gl.Vertex(x, y - h)
		gl.Vertex(x + math.floor(h * 1.3), y)
	else
		gl.Vertex(x - math.floor(h * 0.2), y + math.floor(h * 0.65))
		gl.Vertex(x + math.floor(h * 1.5), y + math.floor(h * 0.65))
		gl.Vertex(x + math.floor(h * 0.65), y - math.floor(h * 0.65))
	end
end
function draw.chevron(x, cy, size, folded, color)
	color = color or look.chevron
	chevron.x, chevron.y, chevron.h, chevron.folded = x, cy, math.floor(size * 0.5), folded
	gl.Color(color[1], color[2], color[3], color[4])
	gl.BeginEnd(GL.TRIANGLES, chevronVertices)
	gl.Color(1, 1, 1, 1)
end

-- The column: the title, then the tabs, with the open one's sections under it and the section the
-- list is showing marked. Under a search, the tabs with matches and how many.
function draw.sidebar()
	local a = layout.area
	local x1, x2 = a[1], a[1] + metrics.sidebarW
	RectRound(
		x1,
		a[2],
		x2,
		layout.sidebarTop + metrics.cardLip,
		metrics.csPanel,
		1,
		1,
		1,
		1,
		look.sidebarFill,
		look.sidebarFillTop
	)
	font:Print(
		look.title .. BAR.I18N("ui.topbar.button.settings"),
		x1 + metrics.sidePad,
		a[4] - metrics.titleY,
		metrics.titleFs,
		"ov"
	)

	-- made changes that wait for a restart: said at the foot of the column, where it stays in sight
	local bottom = a[2]
	if model.changesRequireRestart then
		local note =
			text.wrap(font, BAR.I18N("ui.settings.madechanges"), x2 - x1 - metrics.sidePad * 2, metrics.sectionFs)
		for i = #note, 1, -1 do
			font:Print(
				look.restart .. note[i],
				x1 + metrics.sidePad,
				bottom + math.floor(metrics.sectionHeight * 0.5),
				metrics.sectionFs,
				"ov"
			)
			bottom = bottom + math.floor(metrics.sectionFs * 1.3)
		end
		bottom = bottom + metrics.inset * 2
	end

	layout.sidebar = {}
	local searching = view.searching()
	local lit = view.litLine(searching)
	local litGroup = searching and lit and view.lines[lit].group
	local y = layout.sidebarTop
	for _, group in ipairs(model.groups) do
		if
			group.numOptions > 0
			and (model.devMode or model.devUI or group.id ~= "dev")
			and (not searching or view.matches[group])
			and y - metrics.groupHeight >= bottom
		then
			local r = { x1, y - metrics.groupHeight, x2, y }
			local open = not searching and group.id == currentGroupTab
			local selected = open or group == litGroup
			if selected then
				RectRound(
					r[1] + metrics.inset,
					r[2],
					r[3] - metrics.inset,
					r[4],
					metrics.csSmall,
					1,
					1,
					1,
					1,
					look.selectedFill
				)
			end
			local ty = math.floor((r[2] + r[4]) * 0.5)
			font:Print(
				(selected and look.groupSelected or look.group) .. group.name,
				x1 + metrics.sidePad,
				ty,
				metrics.groupFs,
				"ov"
			)
			if searching then
				font:Print(look.count .. view.matches[group], x2 - metrics.sidePad, ty, metrics.groupFs, "rov")
			end
			layout.sidebar[#layout.sidebar + 1] = { rect = r, group = group, line = view.headingOf[group] }
			y = r[2]

			if open then
				for i, line in ipairs(view.lines) do
					if line.kind == "heading" and y - metrics.sectionHeight >= bottom then
						local sr = { x1, y - metrics.sectionHeight, x2, y }
						local isLit = i == lit
						if isLit then
							RectRound(
								x1 + metrics.sidePad,
								sr[2] + metrics.inset,
								x1 + metrics.sidePad + metrics.accentW,
								sr[4] - metrics.inset,
								0,
								0,
								0,
								0,
								0,
								look.sectionAccent
							)
						end
						local caption = text.fit(font, line.text, x2 - x1 - metrics.sidePad * 3, metrics.sectionFs)
						font:Print(
							(isLit and look.sectionLit or look.section) .. caption,
							x1 + metrics.sidePad * 2,
							math.floor((sr[2] + sr[4]) * 0.5),
							metrics.sectionFs,
							"ov"
						)
						layout.sidebar[#layout.sidebar + 1] = { rect = sr, line = i }
						y = sr[2]
					end
				end
			end
		end
	end
end

-- A section heading on a sheen band, with a line closing it off underneath. Under a search, a tab's
-- results start with its name on a band like the open tab's in the column, set apart from the
-- section headings among them, with how many rows it found.
function draw.heading(line, top, bottom)
	local x1, x2 = layout.listX1, layout.listRight
	local cy = math.floor((top + bottom) * 0.5)
	if line.group then
		RectRound(x1, bottom, x2, top, metrics.csSmall, 1, 1, 1, 1, look.selectedFill)
		font:Print(look.groupSelected .. line.text, x1 + metrics.rowPad, cy, metrics.tabHeadingFs, "ov")
		font:Print(look.count .. view.matches[line.group], x2 - metrics.rowPad, cy, metrics.rowFs, "rov")
		return
	end
	RectRound(x1, bottom, x2, top - metrics.csSmall, metrics.csSmall, 1, 1, 0, 0, look.headingSheen, look.headingSheen)
	RectRound(x1, bottom, x2, bottom + metrics.underlineH, 0, 0, 0, 0, 0, look.headingLine, look.headingLineFade)
	font:Print(look.heading .. line.text, x1 + metrics.rowPad, cy, metrics.headingFs, "ov")
end

-- Each draws its control in the column from x1 to right and returns where it starts.

function drawControl.bool(row, x1, right, cy)
	local half = math.floor(metrics.toggleH * 0.5)
	local tx1 = tuning.controlsAlignLeft and x1 or right - metrics.toggleW
	local r = { tx1, cy - half, tx1 + metrics.toggleW, cy - half + metrics.toggleH }
	row.control = r
	UiToggle(r[1], r[2], r[3], r[4], row.option.value)
	return tx1
end

-- the track with the value printed after it; the knob is the control, row.track the line it runs along
function drawControl.slider(row, x1, right, cy)
	local option = row.option
	if type(option.value) ~= "number" then -- just to be safe
		return right
	end
	local min, max = sliderRange(option)
	-- a value from outside the range (set by a widget or the config) keeps the knob at an end
	local pos = (option.value - min) / (max - min)
	if pos ~= pos then -- a range of one value
		pos = 0
	end
	pos = math.max(0, math.min(1, pos))
	local knob = math.floor(metrics.rowHeight * 0.26)
	local tx1, tx2 = x1 + knob, right - metrics.valueW
	local trackH = math.max(2, math.floor(metrics.rowHeight * 0.16))
	local trackY = cy - math.floor(trackH * 0.5)
	UiSlider(tx1, trackY, tx2, trackY + trackH, option.steps and option.steps or option.step, option.min, option.max)
	local kx = math.floor(tx1 + (tx2 - tx1) * pos)
	UiSliderKnob(kx, cy, knob)
	row.control = { kx - knob, cy - knob, kx + knob, cy + knob }
	row.track = { tx1, tx2 }
	row.knob = knob
	font:Print(look.value .. sliderValueText(option), right, cy, metrics.controlFs, "rov")
	return x1
end

-- the chosen entry inside the button, cut short of the square FlowUI draws at its right end
function drawControl.select(row, x1, right, cy, top, bottom)
	local option = row.option
	local inset = math.floor(metrics.rowHeight * 0.12)
	local r = { x1, bottom + inset, right, top - inset }
	local square = r[4] - r[2]
	row.control = r
	UiSelector(r[1], r[2], r[3], r[4])
	local h = math.floor(metrics.chevron * 0.5)
	draw.chevron(r[3] - math.floor(square * 0.5) - math.floor(h * 0.65), cy, metrics.chevron, false)
	local value = option.options[tonumber(option.value)]
	if value ~= nil then
		value = tostring(value)
		local shown = text.fit(font, value, r[3] - r[1] - square - metrics.rowPad * 2, metrics.controlFs)
		row.cutValue = shown ~= value and value or nil
		if option.id == "font2" then
			-- the second font's dropdown shows its value in that font
			font:End()
			font2:Begin()
			font2:SetOutlineColor(0, 0, 0, 0.4)
			font2:Print(look.value .. shown, r[1] + metrics.rowPad, cy, metrics.controlFs, "ov")
			font2:End()
			font:Begin()
			font:SetOutlineColor(0, 0, 0, 0.4)
		else
			font:Print(look.value .. shown, r[1] + metrics.rowPad, cy, metrics.controlFs, "ov")
		end
	end
	return r[1]
end

-- a swatch of the color, where a toggle would sit; a press opens the picker
function drawControl.color(row, x1, right, _, top, bottom)
	local option = row.option
	if type(option.value) ~= "table" then -- just to be safe
		return right
	end
	local inset = math.floor(metrics.rowHeight * 0.12)
	local sx1 = tuning.controlsAlignLeft and x1 or right - metrics.toggleW
	local r = { sx1, bottom + inset, sx1 + metrics.toggleW, top - inset }
	row.control = r
	WG.FlowUI.Draw.ColorSwatch(r[1], r[2], r[3], r[4], model.shownColor(option))
	return sx1
end

-- a row that does something when clicked is a button across its whole width
function drawControl.click(row, _, right)
	row.control = row.hover
	return right
end

-- One setting: its name, indented under its parent with a fold arrow when it has sub-options (and how
-- many while folded), and its control in the column at the right. Its hover, fold and control areas
-- go into layout for clicks to find.
function draw.row(option, top, bottom)
	local cy = math.floor((top + bottom) * 0.5)
	local depth = indentOf(option)
	local x = layout.listX1 + metrics.rowPad * 2 + metrics.chevron + depth * metrics.indent
	local right = layout.listRight - metrics.rowPad
	local row = { option = option, hover = { layout.listX1, bottom, layout.listRight, top } }
	layout.rows[#layout.rows + 1] = row
	layout.rowOf[option] = row

	local drawIt = drawControl[option.type]
	local left = drawIt and drawIt(row, right - metrics.controlW, right, cy, top, bottom) or right

	local family = view.childCount[option] and not view.searching()
	local folded = family and view.isFolded(option)
	local count = folded and "(" .. view.childCount[option] .. ")" or ""
	local countW = folded and math.floor(font:GetTextWidth(count) * metrics.rowFs) + metrics.rowPad or 0
	local markW = option.restart and math.floor(font:GetTextWidth("*") * metrics.rowFs) + metrics.inset or 0

	local label = getOptionLabel(option)
	local shown = text.fit(font, label, left - metrics.rowPad * 2 - x - markW - countW, metrics.rowFs)
	row.cut = shown ~= label
	local nameW = math.floor(font:GetTextWidth(shown) * metrics.rowFs)
	if family then
		row.chevronX = x - metrics.rowPad - metrics.chevron
		draw.chevron(row.chevronX, cy, metrics.chevron, folded)
		if folded then
			font:Print(look.count .. count, x + nameW + markW + metrics.rowPad, cy, metrics.rowFs, "ov")
		end
		-- everything left of the control folds it, or the whole row when it has none
		row.fold = { layout.listX1, bottom, left < right and left - metrics.rowPad or layout.listRight, top }
	end

	local mainColor, subColor = getNameColors(option)
	if inactive(option) then
		mainColor, subColor = look.inactive, look.inactive
	end
	if option.prefix and string.sub(shown, 1, string.len(option.prefix)) == option.prefix then
		shown = mainColor
			.. option.prefix
			.. (subColor or mainColor)
			.. string.sub(shown, string.len(option.prefix) + 1)
	else
		shown = (depth > 0 and subColor or mainColor) .. shown
	end
	font:Print(shown, x, cy, metrics.rowFs, "ov")
	if option.restart then
		font:Print(look.restartMark, x + nameW + metrics.inset, cy, metrics.rowFs, "ov")
	end
end

-- a line of compact toggles, a switch and a name each, in columns
function draw.cells(line, top, bottom)
	local cy = math.floor((top + bottom) * 0.5)
	local x0 = layout.listX1 + metrics.rowPad * 2 + metrics.chevron + line.depth * metrics.indent
	local cellW = math.floor((layout.listRight - x0) / tuning.compactColumns)
	local half = math.floor(metrics.toggleH * 0.5)
	for i, option in ipairs(line.cells) do
		local x1 = x0 + (i - 1) * cellW
		local x2 = x1 + cellW - metrics.rowPad
		local r = { x1, cy - half, x1 + metrics.toggleW, cy - half + metrics.toggleH }
		local row = { option = option, hover = { x1 - metrics.inset, bottom, x2, top }, control = r }
		layout.rows[#layout.rows + 1] = row
		layout.rowOf[option] = row
		UiToggle(r[1], r[2], r[3], r[4], option.value)
		local label = getOptionLabel(option)
		local shown = text.fit(font, label, x2 - r[3] - metrics.rowPad, metrics.rowFs)
		row.cut = shown ~= label
		local mainColor, subColor = getNameColors(option)
		if inactive(option) then
			mainColor, subColor = look.inactive, look.inactive
		end
		font:Print((line.depth > 0 and subColor or mainColor) .. shown, r[3] + metrics.rowPad, cy, metrics.rowFs, "ov")
	end
end

-- whole lines only, from the first one scrolled to; the band can end mid-line
function draw.lines()
	layout.rows, layout.rowOf = {}, {}
	local base = view.offset()
	for i = view.scroll + 1, #view.lines do
		local line = view.lines[i]
		local top = layout.listTop - (line.off - base)
		local bottom = top - contentHeight(line)
		if bottom < layout.listBottom then
			break
		end
		if line.kind == "heading" then
			draw.heading(line, top, bottom)
		elseif line.kind == "cells" then
			draw.cells(line, top, bottom)
		else
			draw.row(line.option, top, bottom)
		end
	end
end

-- Draws the window into its display list and records in layout where everything went. The search
-- field, the switch, the scrollbar, hover and the strip's text are drawn live in DrawScreen.
function DrawWindow()
	glTexture(false)
	local w, a = layout.window, layout.area
	UiElement(w[1], w[2], w[3], w[4], 1, 1, 1, 1, 1, 1, 1, 1, WG.FlowUI.clampedOpacity)
	RectRound(
		layout.listX1,
		a[2],
		a[3],
		layout.stripTop,
		metrics.csSmall,
		1,
		1,
		1,
		1,
		look.stripFill,
		look.stripFillTop
	)
	font:Begin()
	font:SetOutlineColor(0, 0, 0, 0.4)
	draw.sidebar()
	draw.lines()
	font:End()
	glColor(1, 1, 1, 1)
end

local sec = 0
local sec2 = 0
local lastUpdate = 0

-- what is being worked right now: its value is not read back from where it is stored meanwhile
function view.isHeld(option)
	return option == draggingSlider or option == openSelect or (view.picker and option == view.picker.option)
end

function widget:Update(dt)
	upkeep.updateOffscreen(dt)
	if not initialized then
		return
	end

	model.runScheduled(view.picker and view.picker.option.id)
	upkeep.update(dt)

	sec2 = sec2 + dt
	if sec2 > 0.5 then
		sec2 = 0

		-- detect guishader toggle: force refresh when it comes back on
		local guishaderActive = WG.guishader ~= nil
		if guishaderActive and not guishaderWasActive then
			if backgroundGuishader then
				backgroundGuishader = glDeleteList(backgroundGuishader)
			end
		end
		guishaderWasActive = guishaderActive
	end

	sec = sec + dt
	if show and (sec > lastUpdate + 0.5 or model.forceUpdate) then
		sec = 0
		model.forceUpdate = nil
		lastUpdate = sec

		if model.syncValues(view.isHeld) then
			model.applyFilter()
		end
	end
end

function widget:CommandNotify(cmdID, cmdParams, cmdOptions)
	if show then
		local mx, my = Spring.GetMouseState()
		if inRect(layout.window, mx, my) then
			return true
		end
	end
end

function widget:RecvLuaMsg(msg, playerID)
	return upkeep.recvLuaMsg(msg, playerID)
end

-- the thumb, where it is now; nil when the list fits and no bar is drawn
function view.thumb()
	return UiScrollerAt(
		layout.barX1,
		layout.listBottom,
		layout.barX1 + metrics.barW,
		layout.listTop,
		layout.totalH,
		view.offset()
	)
end

function draw.scrollbar(mx, my)
	local top, height = view.thumb()
	if top then
		local x1, x2 = layout.barX1, layout.barX1 + metrics.barW
		local over = mx >= x1 and mx <= x2 and my <= top and my >= top - height
		UiScroller(x1, layout.listBottom, x2, layout.listTop, layout.totalH, view.offset(), over, view.dragging)
	end
end

-- a switch with its caption on its left, lit while hovered
function draw.switch(switch, hit, on, caption, mx, my)
	local hovered = inRect(hit, mx, my)
	if hovered then
		UiSelectHighlight(hit[1], hit[2], hit[3], hit[4], metrics.csSmall, look.hoverOpacity, look.white)
	end
	UiToggle(switch[1], switch[2], switch[3], switch[4], on, hovered)
	font:Print(caption, switch[1] - metrics.rowPad, math.floor((hit[2] + hit[4]) * 0.5), metrics.captionFs, "rov")
end

-- beside the search field: unfold all, then the switch from view.switchCaption, or in a dev build a
-- note that it shows all
function draw.header(mx, my)
	local unfold = view.unfoldAll
	local caption = (unfold and look.captionOn or look.caption) .. BAR.I18N("ui.settings.unfoldall")
	draw.switch(layout.unfoldSwitch, layout.unfoldSwitchHit, unfold, caption, mx, my)
	if model.devMode then
		local hit = layout.switchHit
		local cy = math.floor((hit[2] + hit[4]) * 0.5)
		font:Print(
			devOptionColor .. BAR.I18N("ui.settings.option.devmode"),
			layout.switch[3],
			cy,
			metrics.captionFs,
			"rov"
		)
		return
	end
	local on = model.devUI or model.advSettings
	caption = (model.devUI and devOptionColor or on and look.captionOn or look.caption) .. view.switchCaption()
	draw.switch(layout.switch, layout.switchHit, on, caption, mx, my)
end

-- The selected row is marked, and what the mouse is over lights up: a tab or section in the column, the
-- part of a row that folds its family, or a row (green when clicking it does something) and its
-- control. Returns the hovered row, for the strip.
function draw.hover(mx, my, ml)
	-- the selected row: a faint band, with the accent the column marks its section with
	local selected = view.selected and layout.rowOf[view.selected]
	if selected then
		local h = selected.hover
		RectRound(h[1], h[2], h[3], h[4], metrics.csSmall, 1, 1, 1, 1, look.selectedRow)
		RectRound(
			h[1],
			h[2] + metrics.inset,
			h[1] + metrics.accentW,
			h[4] - metrics.inset,
			0,
			0,
			0,
			0,
			0,
			look.sectionAccent
		)
	end
	if openSelect then
		return layout.rowOf[openSelect]
	end
	if view.picker then
		return layout.rowOf[view.picker.option]
	end
	for _, entry in ipairs(layout.sidebar) do
		local r = entry.rect
		if inRect(r, mx, my) then
			if not (entry.group and entry.group.id == currentGroupTab and not view.searching()) then
				UiSelectHighlight(
					r[1] + metrics.inset,
					r[2],
					r[3] - metrics.inset,
					r[4],
					metrics.csSmall,
					look.hoverOpacity,
					look.white
				)
			end
			return nil
		end
	end
	if my < layout.listBottom or my > layout.listTop then
		return nil
	end
	for _, row in ipairs(layout.rows) do
		local h, o, option = row.hover, row.control, row.option
		if inRect(h, mx, my) then
			local f = row.fold
			if f and inRect(f, mx, my) then
				-- a button of its own, with its arrow lit
				UiSelectHighlight(f[1], f[2], f[3], f[4], metrics.csSmall, ml and 0.3 or 0.2, look.white)
				local cy = math.floor((h[2] + h[4]) * 0.5)
				draw.chevron(row.chevronX, cy, metrics.chevron, view.isFolded(option), look.chevronLit)
				return row
			end
			if o and option.onclick == nil and option.type ~= "click" and inRect(o, mx, my) then
				RectRound(o[1], o[2], o[3], o[4], 1, 2, 2, 2, 2, look.controlHover, look.controlHoverTop)
			end
			-- tuning can leave the row dark; one that does something when clicked still lights up
			if (option.type ~= "text" or row.fold) and (tuning.rowHighlight or option.onclick) then
				UiSelectHighlight(
					h[1],
					h[2],
					h[3],
					h[4],
					metrics.csSmall,
					option.onclick and (ml and 0.35 or 0.22) or look.hoverOpacity,
					option.onclick and look.clickRow or look.white
				)
			end
			return row
		end
	end
end

-- The strip under the list: the name of the setting last hovered or selected, what it does, and a last
-- line with its restart note and /option command, which a click copies. A description longer than
-- its lines also goes to the tooltip, while the row or the strip is under the mouse. Laid out again
-- only when the setting changes.
local strip = {}
function draw.strip(hovered, mx, my)
	if hovered then
		view.stripOption = hovered.option
	end
	local option = view.stripOption or nil
	local row = option and layout.rowOf[option]
	local cutValue = row and row.cutValue
	local width = layout.area[3] - layout.listX1 - metrics.sidePad * 2
	if option ~= strip.option or cutValue ~= strip.cutValue or width ~= strip.width then
		strip.option, strip.cutValue, strip.width = option, cutValue, width
		strip.title, strip.restart, strip.command, strip.lines, strip.tooltip = nil, nil, nil, {}, nil
		if option and option.name then
			local fs = metrics.rowFs
			if option.restart then
				strip.restart = look.restart .. BAR.I18N("ui.settings.changesrequirerestart")
			end
			if
				option.id
				and (model.advSettings or model.devMode or model.devUI)
				and (option.onchange or option.widget or option.widgetConfig or option.configInt or option.configFloat)
			then
				strip.command = "/option " .. option.id
			end
			local title = getOptionLabel(option)
			if cutValue then
				title = title .. ":  " .. cutValue
			end
			strip.title = look.title .. text.fit(font, title, width, fs)
			local description = option.description
			if type(description) == "string" and description:find("%S") and description ~= option.name then
				-- the last line is the restart note's and the command's when there are any
				local room = tuning.descriptionLines - ((strip.restart or strip.command) and 1 or 0)
				local lines = text.wrap(font, description, width, fs)
				for i = 1, math.min(room, #lines) do
					strip.lines[i] = look.description .. lines[i]
				end
				if room > 0 and lines[room + 1] then
					strip.lines[room] = look.description
						.. text.fit(font, lines[room] .. " " .. lines[room + 1], width, fs)
					strip.tooltip = description
				end
			end
		end
	end

	layout.stripCommand = false
	if not strip.title then
		return
	end
	local x1, x2 = layout.listX1 + metrics.sidePad, layout.area[3] - metrics.sidePad
	local lh = metrics.stripLineH
	local y = layout.stripTop - math.floor(metrics.inset * 1.5) - math.floor(lh * 0.5)
	font:Print(strip.title, x1, y, metrics.rowFs, "ov")
	for i, line in ipairs(strip.lines) do
		font:Print(line, x1, y - lh * i, metrics.rowFs, "ov")
	end
	local footY = y - lh * tuning.descriptionLines
	if strip.restart then
		font:Print(strip.restart, x1, footY, metrics.rowFs, "ov")
	end
	if strip.command then
		local w = math.floor(font:GetTextWidth(strip.command) * metrics.rowFs)
		local half = math.floor(lh * 0.5)
		local r = { x2 - w, footY - half, x2, footY + half, strip.command }
		layout.stripCommand = r
		-- lit while it can be clicked, and for a moment once copied
		local lit = inRect(r, mx, my) or os_clock() - view.copiedAt < 1
		font:Print((lit and look.commandLit or look.command) .. strip.command, x2, footY, metrics.rowFs, "rov")
	end
	local overStrip = mx >= layout.listX1 and mx <= layout.area[3] and my >= layout.area[2] and my <= layout.stripTop
	if strip.tooltip and WG.tooltip and (hovered or overStrip) then
		WG.tooltip.ShowTooltip("options_description", font:WrapText(strip.tooltip, WG.tooltip.getFontsize() * 90))
	end
end

-- The open dropdown's entries under its button, or above it when they would run off the screen;
-- at most 16 at a time, with a scrollbar beyond that. The graphics preset's dropdown also marks
-- the rows the presets set. Its display list is made again only when what it shows changed.
local popup = {}
function draw.selectPopup(mx, my)
	local option = openSelect
	local row = option and layout.rowOf[option]
	if not (option and row and row.control) then
		openSelect = nil
		return
	end
	if option.id == "preset" then
		for optionID, _ in pairs(model.presets.lowest) do
			local presetRow = layout.rowOf[getOption(optionID)]
			if presetRow ~= nil then
				local h = presetRow.hover
				RectRound(h[1], h[2] + 1, h[3], h[4] - 1, 1, 2, 2, 2, 2, look.presetRow, look.presetRowTop)
			end
		end
	end

	local button = row.control
	local itemH = button[4] - button[2]
	local pad = metrics.selectPadding
	local step = itemH + pad * 2
	local fontSize = metrics.dropdownFs
	local numItems = 0
	local width = button[3] - button[1]
	for _, value in pairs(option.options) do
		numItems = numItems + 1
		width = math.max(width, math.floor(font:GetTextWidth(tostring(value)) * fontSize) + pad * 6)
	end
	local maxVisible = math.min(numItems, 16)
	selectScrollOffset = math.max(0, math.min(selectScrollOffset or 0, numItems - maxVisible))
	local height = step * maxVisible
	local top = button[2]
	if button[2] - height < 0 and vsy - button[4] > button[2] then
		top = button[4] + height
	end

	layout.selectItems = {}
	local hovered
	local i = 0
	for k, _ in pairs(option.options) do
		i = i + 1
		local vi = i - selectScrollOffset
		if vi >= 1 and vi <= maxVisible then
			local item = { button[1], top - step * vi, button[1] + width, top - step * (vi - 1), k }
			layout.selectItems[vi] = item
			if inRect(item, mx, my) then
				hovered = k
			end
		end
	end
	-- the mouse moves the entry the arrow keys go from
	if hovered ~= nil then
		view.selectKey = hovered --[[@as number]]
	end
	if hovered ~= nil and hovered ~= prevSelectHover and playSounds then
		Spring.PlaySoundFile(sounds.selectHoverClick, 0.04, "ui")
	end
	prevSelectHover = hovered

	local sig = table.concat({
		option.id or "",
		selectScrollOffset,
		tostring(view.selectKey),
		tostring(option.value),
		button[1],
		top,
		width,
		WG.guishader and 1 or 0,
	}, "|")
	if sig ~= popup.sig or not selectOptionsList then
		popup.sig = sig
		if selectOptionsList then
			if WG.guishader then
				WG.guishader.removeRenderDlist(selectOptionsList)
			end
			glDeleteList(selectOptionsList)
		end
		-- previews for the font dropdowns, which only dev mode shows; loaded once
		if option.optionsFont and not fontOption then
			fontOption = {}
			local fontScale = (0.5 + (vsx * vsy / 5700000))
			for k, file in ipairs(option.optionsFont) do
				fontOption[k] = gl.LoadFont("fonts/" .. file, 20 * fontScale, 5 * fontScale, 1.5)
			end
		end
		local items = layout.selectItems
		selectOptionsList = glCreateList(function()
			local border = metrics.selectBorder
			local cs = math.floor(itemH * 0.1)
			RectRound(
				button[1] - border,
				top - height - border,
				button[1] + width + border,
				top + border,
				cs,
				1,
				1,
				1,
				1,
				look.selectBorder,
				look.selectBorder
			)
			RectRound(
				button[1],
				top - height,
				button[1] + width,
				top,
				cs,
				1,
				1,
				1,
				1,
				WG.guishader and look.selectBack or look.selectBackSolid,
				WG.guishader and look.selectBackTop or look.selectBackSolidTop
			)
			UiSelector(button[1], button[2], button[3], button[4])
			for _, item in ipairs(items) do
				local k = item[5]
				if k == option.value then
					RectRound(item[1], item[2], item[3], item[4], cs, 1, 1, 1, 1, look.selectCurrent)
				end
				if k == view.selectKey then
					UiSelectHighlight(item[1], item[2], item[3], item[4])
				end
				local itemFont = (option.optionsFont and fontOption and fontOption[k]) or font
				itemFont:Begin()
				itemFont:SetOutlineColor(0, 0, 0, 0.4)
				itemFont:Print(
					optionColor .. tostring(option.options[k]),
					item[1] + pad * 2,
					text.baseline(itemFont, item[2], item[4], fontSize),
					fontSize,
					"o"
				)
				itemFont:End()
			end
			if numItems > maxVisible then
				local x2 = button[1] + width
				local x1 = x2 - metrics.selectScrollbar
				local y1, y2 = top - height, top
				local thumbH = math.max((y2 - y1) * maxVisible / numItems, metrics.selectScrollbar * 2)
				local thumbY2 = y2 - (selectScrollOffset / (numItems - maxVisible)) * ((y2 - y1) - thumbH)
				gl.Color(look.scrollTrack[1], look.scrollTrack[2], look.scrollTrack[3], look.scrollTrack[4])
				gl.Rect(x1, y1, x2, y2)
				gl.Color(look.scrollThumb[1], look.scrollThumb[2], look.scrollThumb[3], look.scrollThumb[4])
				gl.Rect(x1, thumbY2 - thumbH, x2, thumbY2)
				gl.Color(1, 1, 1, 1)
			end
		end)
		if WG.guishader then
			WG.guishader.InsertScreenRect(button[1], button[2], button[3], button[4], "options_select", widget)
			WG.guishader.InsertScreenRect(
				button[1],
				top - height,
				button[1] + width,
				top,
				"options_select_options",
				widget
			)
			WG.guishader.insertRenderDlist(selectOptionsList)
		end
	end
	if not WG.guishader then
		glCallList(selectOptionsList)
	end
end

-- Opens FlowUI's color picker on a color option. Its changes apply as it goes; ESC puts back the
-- color it opened on, and a click anywhere off it closes it.
function view.openPicker(option)
	view.closePicker()
	local white, value = option.white or option.max, option.value
	view.picker = {
		option = option,
		original = { value[1], value[2], value[3] },
		ui = WG.FlowUI.ColorPicker.new({ value[1] / white, value[2] / white, value[3] / white }, option.max / white),
	}
	view.sound("selectUnfoldClick", 0.6)
end

function view.dropPickerList()
	local picker = view.picker
	local guishader = WG.guishader ---@type table?
	if picker and picker.list then
		if guishader then
			guishader.removeRenderDlist(picker.list)
		end
		picker.list = glDeleteList(picker.list)
	end
end

function view.closePicker()
	local guishader = WG.guishader ---@type table?
	if view.picker then
		view.dropPickerList()
		if guishader then
			guishader.RemoveScreenRect("options_color")
		end
		view.picker = false
	end
end

-- the picker's color in its option's units, each channel on its step
function view.pickerValue(picker)
	local option, color = picker.option, picker.ui.color
	local white, step = option.white or option.max, option.step
	local value = {}
	for i = 1, 3 do
		local v = color[i] * white
		if step then
			v = math.floor(v / step + 0.5) * step
		end
		value[i] = math.max(0, math.min(option.max, v))
	end
	return value
end

-- Hands the picker's color to its option when that changed it. While a drag goes on the list is not
-- built again (the next frame draws the swatch anew); at its end it is.
function view.applyPicked(final)
	local picker = view.picker
	if not picker then
		return
	end
	local value = view.pickerValue(picker)
	if not model.sameColor(value, picker.option.value) then
		if final then
			applyOptionValue(picker.option, value)
		else
			sliderValueChanged = true
			applyOptionValue(picker.option, value, true)
			if lastSliderSound == nil or os_clock() - lastSliderSound > 0.04 then
				lastSliderSound = os_clock()
				view.sound("sliderDrag", 0.3)
			end
		end
	end
end

-- puts back the color the picker opened on
function view.revertPicked()
	local picker = view.picker
	if picker and not model.sameColor(picker.original, picker.option.value) then
		local original = picker.original
		picker.ui:setColor(picker.ui.previous)
		applyOptionValue(picker.option, { original[1], original[2], original[3] })
	end
end

-- the wheel over a bar: a step of its channel, or ten
function view.stepPickerChannel(channel, n)
	local picker = view.picker
	local option = picker.option
	local value = { option.value[1], option.value[2], option.value[3] }
	local step = option.step or option.max / 100
	value[channel] = math.max(0, math.min(option.max, math.floor((value[channel] + n * step) / step + 0.5) * step))
	if not model.sameColor(value, option.value) then
		local white = option.white or option.max
		picker.ui:setColor({ value[1] / white, value[2] / white, value[3] / white })
		applyOptionValue(option, value)
		view.sound("sliderDrag", 0.3)
	end
end

-- While the picker is open a press is its own: on it, it picks or puts back the color it opened on;
-- anywhere else, its own swatch too, it closes it. The release that follows does nothing else.
function view.pickerMouse(mx, my, release)
	local picker = view.picker
	if release then
		if not view.pickerHeld then
			return false
		end
		view.pickerHeld = false
		if picker and picker.ui.dragging then
			picker.ui:release()
			view.applyPicked(true)
		end
		return true
	end
	if not picker then
		return false
	end
	view.pickerHeld = true
	view.pressedInside = true
	local changed, part = picker.ui:press(mx, my)
	if part == "previous" then
		view.revertPicked()
	elseif changed then
		view.applyPicked()
	elseif part == nil then
		view.closePicker()
	end
	return true
end

-- The open color picker under its swatch, or above it where it would run off the screen, with each
-- channel's letter and value beside its bar. Like the dropdown it is drawn after guishader's blur,
-- and its display list is made again only when what it shows changed.
function draw.picker(mx, my)
	local picker = view.picker
	local row = layout.rowOf[picker.option]
	if not (row and row.control) then
		view.closePicker()
		return
	end
	local control, w, h = row.control, metrics.pickerW, metrics.pickerH
	local x1 = math.max(0, math.min(control[3] - w, vsx - w))
	local top = control[2] - metrics.selectPadding
	if top - h < 0 and vsy - control[4] > control[2] then
		top = control[4] + metrics.selectPadding + h
	end
	local ui, option = picker.ui, picker.option
	local guishader = WG.guishader ---@type table?
	ui:setRect(x1, top - h, x1 + w, top)
	local hovered = ui.dragging or ui:partAt(mx, my)
	local value, c = option.value, ui.color
	local sig = table.concat({
		x1,
		top,
		ui.h,
		ui.s,
		ui.v,
		c[1],
		c[2],
		c[3],
		value[1],
		value[2],
		value[3],
		tostring(hovered),
		guishader and 1 or 0,
	}, "|")
	if sig ~= picker.sig or not picker.list then
		picker.sig = sig
		view.dropPickerList()
		picker.list = glCreateList(function()
			ui:draw(hovered, guishader and look.selectBack[4] or look.selectBackSolid[4])
			font:Begin()
			font:SetOutlineColor(0, 0, 0, 0.4)
			for i, channel in ipairs(ui.parts.channels) do
				font:Print(look.caption .. channel.letter, channel.labelX, channel.y, metrics.controlFs, "ov")
				local shown = model.channelText(option, value[i])
				font:Print(look.value .. shown, channel.valueX, channel.y, metrics.controlFs, "rov")
			end
			font:End()
		end)
		if guishader then
			guishader.InsertScreenRect(x1, top - h, x1 + w, top, "options_color", widget)
			guishader.insertRenderDlist(picker.list)
		end
	end
	if not guishader then
		glCallList(picker.list)
	end
end

function widget:DrawScreen()
	-- doing it here so other widgets having higher layer number value are also loaded
	if not initialized then
		model.init()
		initialized = true
	else
		-- a slider moved
		if sliderValueChanged then
			view.refresh()
			sliderValueChanged = nil
		end

		if not openSelect and selectOptionsList then
			if WG.guishader then
				WG.guishader.RemoveScreenRect("options_select")
				WG.guishader.RemoveScreenRect("options_select_options")
				WG.guishader.removeRenderDlist(selectOptionsList)
			end
			selectOptionsList = glDeleteList(selectOptionsList)
			popup.sig = nil
		end

		if (show or showOnceMore) and windowList then
			local mx, my, ml = Spring.GetMouseState()
			if view.dragging then
				if ml then
					view.scrollFromY(my)
				else
					view.dragging = false
				end
			end
			if inRect(layout.window, mx, my) then
				Spring.SetMouseCursor("cursornormal")
			end

			glCallList(windowList)
			if WG.guishader and not backgroundGuishader then
				backgroundGuishader = glCreateList(function()
					local w = layout.window
					RectRound(w[1], w[2], w[3], w[4], elementCorner, 1, 1, 1, 1)
				end)
				WG.guishader.InsertDlist(backgroundGuishader, "options", nil, self)
			end
			showOnceMore = false

			searchBox:draw()
			font:Begin()
			font:SetOutlineColor(0, 0, 0, 0.4)
			draw.header(mx, my)
			draw.scrollbar(mx, my)
			draw.strip(draw.hover(mx, my, ml), mx, my)
			font:End()
			if openSelect ~= nil then
				draw.selectPopup(mx, my)
			elseif prevSelectHover ~= nil then
				prevSelectHover = nil
			end
			if view.picker then
				draw.picker(mx, my)
			end
			glColor(1, 1, 1, 1)
		elseif WG.guishader and backgroundGuishader then
			WG.guishader.RemoveDlist("options")
			backgroundGuishader = glDeleteList(backgroundGuishader)
		end
		if checkedWidgetDataChanges == nil then
			checkedWidgetDataChanges = true
			model.loadAllWidgetData()
		end
	end
end

function widget:KeyRelease()
	-- Since we grab the keyboard, we need to specify a KeyRelease to make sure other release actions can be triggered
	return false
end

-- ESC closes the open dropdown or color picker first (the picker puts back the color it opened on,
-- where Enter keeps the new one), then clears the search, then closes the window. The arrow keys,
-- Enter, Tab, Home and End work the rows (view.moveSelection and the ones after it), the arrows and
-- Enter an open dropdown too; while the search field is typed in, it keeps left, right, Enter, Home
-- and End. Every other key goes to the search field, and none reach the game while the window is open.
function widget:KeyPress(key, mods)
	if not show then
		return false
	end
	if view.picker and (key == 27 or key == 13 or key == 271) then
		if key == 27 then
			view.revertPicked()
		end
		view.closePicker()
		return true
	end
	if key == 27 then
		if openSelect then
			openSelect = nil
		elseif searchBox:getText() ~= "" then
			searchBox:setText("")
			searchBox:blur()
		else
			view.close()
		end
		return true
	end

	if key >= 282 and key <= 293 then -- Function keys
		return false
	end

	if key == 280 then -- PGUP
		view.scrollBy(-view.pageLines(true))
		return true
	elseif key == 281 then -- PGDN
		view.scrollBy(view.pageLines())
		return true
	end

	local enter = key == 13 or key == 271
	if openSelect then
		if key == 273 or key == 274 then -- up, down: the entry before or after, kept among those shown
			local k = (view.selectKey or tonumber(openSelect.value) or 0) + (key == 274 and 1 or -1)
			view.selectKey = math.max(1, math.min(#openSelect.options, k))
			selectScrollOffset = math.max(view.selectKey - 16, math.min(view.selectKey - 1, selectScrollOffset or 0))
			return true
		elseif enter then
			if view.selectKey then
				applyOptionValue(openSelect, view.selectKey)
				view.sound("selectClick", 0.5)
			end
			openSelect = nil
			return true
		end
	end
	if key == 273 or key == 274 then -- up, down
		view.moveSelection(key == 274 and 1 or -1)
		return true
	end
	if not searchBox:isFocused() then
		if key == 275 or key == 276 then -- right, left
			view.adjustSelected(key == 275 and 1 or -1, mods and mods.ctrl)
			return true
		elseif enter then
			view.activateSelected()
			return true
		elseif key == 9 and not view.searching() then -- tab, back with shift
			view.cycleTab(mods and mods.shift and -1 or 1)
			return true
		elseif key == 278 or key == 279 then -- home, end
			local items = view.selectable()
			if #items > 0 then
				local item = items[key == 278 and 1 or #items]
				view.select(item.option, item.line)
			end
			return true
		end
	end

	-- editing keys work on a search kept from before without clicking into it first
	if searchBox:getText() ~= "" then
		searchBox:focus()
	end
	searchBox:keyPress(key)
	return true
end

-- the value a slider takes with the mouse at mx, clamped and snapped to its step
local function sliderValueAt(option, mx)
	local row = layout.rowOf[option]
	if not (row and row.track) then
		return option.value
	end
	local track = row.track
	local min, max = sliderRange(option)
	local value
	local fine = view.fineDrag
	if fine and fine.option == option then
		-- dragged with shift held: a fifth of the speed, from where the drag started
		value = fine.value + (max - min) * 0.2 * (mx - fine.x) / (track[2] - track[1])
	else
		value = min + (max - min) * (mx - track[1]) / (track[2] - track[1])
	end
	if value < min then
		value = min
	end
	if value > max then
		value = max
	end
	if option.steps ~= nil then
		value = NearestValue(option.steps, value)
	elseif option.step ~= nil then
		value = math.floor((value + (option.step / 2)) / option.step) * option.step
	end
	return value
end

-- scrolls so the thumb's top sits where the cursor has dragged it
function view.scrollFromY(y)
	local _, _, trackTop, travel = view.thumb()
	if not travel or travel <= 0 then
		return
	end
	local f = math.max(0, math.min(1, (trackTop - (y - view.dragGrab)) / travel))
	view.scrollBy(math.floor(f * view.maxScroll() + 0.5) - view.scroll)
end

-- Takes hold of the bar: on the thumb that is a grab and the list stays put, on the track the
-- thumb jumps to the cursor first and is dragged from its middle.
function view.grabScroller(y)
	local top, height = view.thumb()
	if not top then
		return
	end
	view.dragging = true
	if y <= top and y >= top - height then
		view.dragGrab = y - top
	else
		view.dragGrab = -math.floor(height * 0.5)
		view.scrollFromY(y)
	end
end

-- each tab keeps where its list was left
function view.openTab(group)
	view.scrollOf[currentGroupTab] = view.scroll
	currentGroupTab = group.id
	openSelect = nil
	view.closePicker()
	selectClickAllowHide = nil
	view.litPin = false
	view.selected, view.stripOption = false, false
	view.scroll = view.scrollOf[group.id] or 0
	view.build()
	view.refresh()
end

-- opens the tab an option is on, unfolds its family and scrolls its row into view
function view.reveal(option)
	if searchBox and searchBox:getText() ~= "" then
		searchBox:setText("")
	end
	view.litPin = false
	if option.group ~= currentGroupTab then
		view.scrollOf[currentGroupTab] = view.scroll
		currentGroupTab = option.group
	end
	local parent = option.parentOption
	while parent do
		if parent.id and view.isFolded(parent) then
			view.folded[parent.id] = false
		end
		parent = parent.parentOption
	end
	view.build()
	for i, line in ipairs(view.lines) do
		local found = line.option == option
		for _, cell in ipairs(line.cells or {}) do
			found = found or cell == option
		end
		if found then
			view.setScroll(i - 3)
			break
		end
	end
	view.refresh()
end

-- The wheel scrolls the open dropdown, steps a channel over the color picker's bars (ten steps with
-- ctrl), or else scrolls the list: three lines, nine with ctrl, a page with shift. Nothing gets past
-- the window while it is open.
function widget:MouseWheel(up, value)
	if not show then
		return
	end
	local mx, my = Spring.GetMouseState()
	-- on the color picker the list stays put
	local part = view.picker and view.picker.ui:partAt(mx, my)
	if type(part) == "number" then
		local _, ctrl = Spring.GetModKeyState()
		view.stepPickerChannel(part, (up and 1 or -1) * (ctrl and 10 or 1))
	end
	if openSelect ~= nil then
		local numItems = 0
		for _ in pairs(openSelect.options) do
			numItems = numItems + 1
		end
		local maxVisible = math.min(numItems, 16)
		if up then
			selectScrollOffset = math.max(0, (selectScrollOffset or 0) - 1)
		else
			selectScrollOffset = math.min(numItems - maxVisible, (selectScrollOffset or 0) + 1)
		end
		return true
	end
	if not part and inRect(layout.window, mx, my) then
		local _, ctrl, _, shift = Spring.GetModKeyState()
		-- over the selected slider the wheel steps it (ten steps with ctrl); not over others, which a
		-- list scrolled past would change
		local row = view.selected and layout.rowOf[view.selected]
		if
			row
			and row.track
			and math_isInRect(mx, my, row.track[1] - row.knob, row.hover[2], row.track[2] + row.knob, row.hover[4])
		then
			view.stepSlider(view.selected, (up and 1 or -1) * (ctrl and 10 or 1))
			return true
		end
		local step = ctrl and metrics.wheelRows * 3 or metrics.wheelRows
		if shift then
			step = view.pageLines(up)
		end
		view.scrollBy(up and -step or step)
	end
	return true
end

function widget:MouseMove(mx, my)
	if view.picker and view.picker.ui:drag(mx, my) then
		view.applyPicked()
	end
	if draggingSlider ~= nil then
		local newValue = sliderValueAt(draggingSlider, mx)
		if draggingSlider.value ~= newValue then
			sliderValueChanged = true
			applyOptionValue(draggingSlider, newValue, true) -- the window is drawn again next frame
			if playSounds and (lastSliderSound == nil or os_clock() - lastSliderSound > 0.04) then
				lastSliderSound = os_clock()
				Spring.PlaySoundFile(sounds.sliderDrag, 0.4, "ui")
			end
		end
	end
end

function widget:MousePress(x, y, button)
	return mouseEvent(x, y, button, false)
end

function widget:MouseRelease(x, y, button)
	return mouseEvent(x, y, button, true)
end

-- a release on a row: fold or unfold a family, flip a toggle, or run the row's click action
local function releaseOnRows(mx, my)
	for _, row in ipairs(layout.rows) do
		local o, option = row.control, row.option
		if row.fold and inRect(row.fold, mx, my) then
			view.folded[option.id] = not view.isFolded(option)
			view.build()
			if playSounds then
				Spring.PlaySoundFile(sounds.buttonClick, 0.5, "ui")
			end
			return
		elseif o then
			if option.type == "bool" and inRect(o, mx, my) then
				applyOptionValue(option, not option.value)
				if playSounds then
					if option.value then
						Spring.PlaySoundFile(sounds.toggleOnClick, 0.75, "ui")
					else
						Spring.PlaySoundFile(sounds.toggleOffClick, 0.75, "ui")
					end
				end
				return
			elseif
				(option.type == "slider" or option.type == "select" or option.type == "color") and inRect(o, mx, my)
			then
				-- handled on press
				return
			elseif option.onclick ~= nil and inRect(row.hover, mx, my) then
				option.onclick(option)
				return
			end
		end
	end
end

-- A press on a row selects it, and grabs a slider anywhere along its track (with shift held, where
-- the knob is, to drag it finely) or opens a dropdown or a color picker.
local function pressOnRows(mx, my)
	for _, row in ipairs(layout.rows) do
		if inRect(row.hover, mx, my) then
			view.selected, view.stripOption = row.option, row.option
		end
	end
	for _, row in ipairs(layout.rows) do
		local o, option = row.control, row.option
		if o and option.type == "slider" and row.track then
			local h = row.hover
			if math_isInRect(mx, my, row.track[1] - row.knob, h[2], row.track[2] + row.knob, h[4]) then
				draggingSlider = option
				local _, _, _, shift = Spring.GetModKeyState()
				view.fineDrag = shift and { option = option, x = mx, value = option.value } or false
				local newValue = sliderValueAt(option, mx)
				if option.value ~= newValue then
					sliderValueChanged = true
					applyOptionValue(option, newValue, true)
					if playSounds then
						Spring.PlaySoundFile(sounds.sliderDrag, 0.3, "ui")
					end
				end
				return
			end
		elseif o and option.type == "select" and inRect(o, mx, my) then
			if playSounds then
				Spring.PlaySoundFile(sounds.selectUnfoldClick, 0.6, "ui")
			end
			openSelect = option
			selectScrollOffset = 0
			view.selectKey = false
			return
		elseif o and option.type == "color" and inRect(o, mx, my) then
			view.openPicker(option)
			return
		end
	end
end

-- a press on a header switch: unfold all, or advanced (the developer UI's while that is on)
local function pressOnHeader(mx, my)
	if inRect(layout.unfoldSwitchHit, mx, my) then
		-- every family follows the switch, so what was folded or opened by hand is let go
		view.unfoldAll = not view.unfoldAll
		view.folded = {}
		view.build()
		view.refresh()
	elseif not model.devMode and inRect(layout.switchHit, mx, my) then
		if model.devUI then
			-- the way its own row turns it off: reloads the UI
			applyOptionValueByID("devmode", false)
		else
			model.advSettings = not model.advSettings
			view.build()
			view.refresh()
		end
	else
		return false
	end
	if playSounds then
		Spring.PlaySoundFile(sounds.buttonClick, 0.6, "ui")
	end
	return true
end

-- a press in the column: open a tab, or scroll to a section (or a tab's search results)
local function pressOnSidebar(mx, my)
	for _, entry in ipairs(layout.sidebar) do
		if inRect(entry.rect, mx, my) then
			if entry.group and not view.searching() then
				if entry.group.id == currentGroupTab then
					view.scrollBy(-view.scroll)
					view.litPin = false
					view.refresh()
				else
					view.openTab(entry.group)
				end
			elseif entry.line then
				view.scrollBy(entry.line - 1 - view.scroll)
				local line = view.lines[entry.line]
				view.litPin = line and (line.option or line.group) or false
				view.refresh()
			end
			if playSounds then
				Spring.PlaySoundFile(sounds.paginatorClick, 0.9, "ui")
			end
			return true
		end
	end
end

-- A press in the window goes to the search field, a header switch, the column, the scrollbar or a
-- row; a release outside closes the window, unless it ends something that started inside.
function mouseEvent(mx, my, button, release)
	if Spring.IsGUIHidden() then
		return false
	end
	if not show then
		return
	end

	-- A press on a top bar button is the top bar's to handle: it closes the open windows
	-- and opens the one that was clicked. Closing (and consuming) here would swallow it.
	if WG.topbar and WG.topbar.buttonAt and WG.topbar.buttonAt(mx, my) then
		return false
	end

	local inWindow = inRect(layout.window, mx, my)
	local pressedInside = view.pressedInside
	if release then
		view.pressedInside = nil
	end

	if button == 1 and view.pickerMouse(mx, my, release) then
		return true
	end

	if button == 1 then
		if release then
			if view.dragging then
				view.dragging = false
				return true
			end

			-- apply new slider value
			if draggingSlider ~= nil then
				applyOptionValue(draggingSlider, sliderValueAt(draggingSlider, mx))
				draggingSlider = nil
				view.fineDrag = false
				return true
			end

			-- select option
			if openSelect ~= nil then
				for _, item in ipairs(layout.selectItems) do
					if inRect(item, mx, my) then
						applyOptionValue(openSelect, item[5])
						if playSounds then
							Spring.PlaySoundFile(sounds.selectClick, 0.5, "ui")
						end
					end
				end
				local row = layout.rowOf[openSelect]
				if selectClickAllowHide ~= nil or not (row and inRect(row.control, mx, my)) then
					openSelect = nil
					selectClickAllowHide = nil
				else
					selectClickAllowHide = true
				end
				return true
			end

			if inWindow then
				releaseOnRows(mx, my)
				view.refresh()
			end
		elseif inWindow and not openSelect then
			view.pressedInside = true
			if searchBox:mousePress(mx, my) then
				return true
			end
			if not pressOnHeader(mx, my) and not pressOnSidebar(mx, my) then
				if mx >= layout.barX1 and my >= layout.listBottom and my <= layout.listTop then
					view.grabScroller(my)
				elseif layout.stripCommand and inRect(layout.stripCommand, mx, my) then
					-- the /option command in the strip, to paste in the chat or a key bind
					Spring.SetClipboard(layout.stripCommand[5])
					view.copiedAt = os_clock()
				else
					pressOnRows(mx, my)
				end
			end
		end
	elseif inWindow and not release then
		view.pressedInside = true
	end

	if inWindow then
		return true
	end
	if release and not pressedInside and draggingSlider == nil then
		showOnceMore = true -- show once more because the guishader lags behind, though this will not fully fix it
		view.close()
	end
	return true
end

function widget:MapDrawCmd(playerID, cmdType, startx, starty, startz, a, b, c)
	return upkeep.mapDrawCmd()
end

function widget:UnsyncedHeightMapUpdate(x1, z1, x2, z2)
	upkeep.unsyncedHeightMapUpdate(x1, z1, x2, z2)
end

function widget:GameOver()
	upkeep.gameOver()
end

function widget:GameFrame(n)
	upkeep.gameFrame(n)
end

local function optionsCmd(_, _, params)
	if show then
		view.close()
	else
		view.open()
	end
end

local function optionCmd(_, _, params)
	if not params[1] then
		return
	end

	local option = getOption(params[1])
	if not option then
		return
	end

	if not params[2] and option.type ~= "bool" then
		view.open()
		view.reveal(option)
	else
		model.applyCommand(option, params)
	end
end

function widget:Initialize()
	upkeep.initialize(self)
	view.resize()

	-- lets the handler hide the rest of the interface while the window is open
	-- (this widget holds the real widgetHandler, so it passes itself)
	widgetHandler:RegisterModalWindow(widget, function()
		return show == true
	end)

	WG.options = model.api()
	WG.options.toggle = function(state)
		if state == nil then
			state = not show
		end
		if state then
			view.open()
		else
			view.close()
		end
	end
	WG.options.isvisible = function()
		return show
	end
	WG.options.disallowEsc = function()
		if openSelect or view.picker then
			--or draggingSlider then
			return true
		else
			return false
		end
	end

	widgetHandler.actionHandler:AddAction(self, "options", optionsCmd, nil, "t")
	widgetHandler.actionHandler:AddAction(self, "option", optionCmd, nil, "t")
end

function widget:Shutdown()
	view.close()
	if windowList then
		glDeleteList(windowList)
		glDeleteList(backgroundGuishader)
	end
	if fontOption then
		for i, font in pairs(fontOption) do
			gl.DeleteFont(fontOption[i])
		end
	end
	if WG.guishader then
		WG.guishader.RemoveDlist("options")
		WG.guishader.RemoveScreenRect("options_select")
		WG.guishader.RemoveScreenRect("options_select_options")
		if selectOptionsList then
			WG.guishader.removeRenderDlist(selectOptionsList)
		end
	end
	if selectOptionsList then
		glDeleteList(selectOptionsList)
	end
	WG.options = nil

	upkeep.shutdown(self)

	widgetHandler.actionHandler:RemoveAction(self, "options")
	widgetHandler.actionHandler:RemoveAction(self, "option")
end

function widget:GetConfigData()
	local data = model.getConfigData()
	data.folded = view.folded
	data.unfoldAll = view.unfoldAll
	data.currentGroupTab = currentGroupTab
	data.show = show
	return data
end

function widget:SetConfigData(data)
	model.setConfigData(data)
	if Spring.GetGameFrame() > 0 then
		if data.currentGroupTab ~= nil then
			currentGroupTab = data.currentGroupTab
		end
		if data.show ~= nil then
			show = data.show
			if show then
				widgetHandler.textOwner = widget --widgetHandler:OwnText()
				Spring.SDLStartTextInput() -- because: touch chobby's text edit field once and widget:TextInput is gone for the game, so we make sure its started!
			end
		end
	end
	if type(data.folded) == "table" then
		for id, folded in pairs(data.folded) do
			if type(folded) == "boolean" then
				view.folded[id] = folded
			end
		end
	end
	view.unfoldAll = data.unfoldAll == true
end

function widget:LanguageChanged()
	view.makeSearchBox()
	view.setLayout()
	model.init()
end
