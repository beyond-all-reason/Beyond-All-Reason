local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Changelog Info",
		desc = "",
		author = "Floris",
		date = "August 2015",
		license = "GNU GPL, v2 or later",
		layer = -99990,
		enabled = true,
	}
end

local Markdown = VFS.Include("luaui/Include/markdown.lua")

-- Localized functions for performance
local mathFloor = math.floor
local mathMax = math.max
local mathMin = math.min

-- Localized Spring API for performance
local spGetMouseState = Spring.GetMouseState
local spGetViewGeometry = Spring.GetViewGeometry
local spIsGUIHidden = Spring.IsGUIHidden
local glCreateList = gl.CreateList
local glCallList = gl.CallList
local glDeleteList = gl.DeleteList
local math_isInRect = math.isInRect

local vsx, vsy = spGetViewGeometry()

local changelogFile = VFS.LoadFile("changelog.md")
local changelogFileHash = changelogFile and VFS.CalculateHash(changelogFile, 0) or ""
local changelogFileLength = changelogFile and string.len(changelogFile) or 0
local lastviewedHash = ""
local lastviewedChangelogLength = 0

local screenHeightOrg = 610
local screenWidthOrg = 1100
local screenHeight = screenHeightOrg
local screenWidth = screenWidthOrg

local playSounds = true
local buttonclick = "LuaUI/Sounds/buildbar_waypoint.wav"

local centerPosX = 0.5
local centerPosY = 0.5
local screenX = mathFloor((vsx * centerPosX) - (screenWidth / 2))
local screenY = mathFloor((vsy * centerPosY) + (screenHeight / 2))
local widgetScale = (vsy / 1080)

-- The changelog is markdown: the month column lists its chapter headings (the
-- shallowest heading level the file uses), and the text is rendered by the shared
-- markdown include, so bold, lists, code and links look the way they do anywhere else.
local doc
local versions = {} -- chapter k -> index of the row its heading starts on
local versionLabels = {} -- chapter k -> the heading text shown in the month column

local showOnceMore = false -- used because of GUI shader delay

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
local elementCorner
local font, fontBold, fontMono
local panelList, sidebarList, backgroundGuishader, show
local titleText = ""

-- The panel is laid out the way the keybind editor lays out its own: the same inset
-- area, the title in the top-left corner over a darker card holding the month column,
-- and a 14 px scrollbar standing in its own channel against the right edge.
local area = { x1 = 0, y1 = 0, x2 = 0, y2 = 0 }
local metrics = {
	sidePad = 12,
	catInset = 4,
	catRowHeight = 29,
	catFs = 13,
	-- The band above the text where the title sits, and the gap under it.
	headerH = 34,
	headerGap = 4,
	-- Everything against the panel's right edge - the scrollbar - is held off it by this.
	edgeInset = 4,
	-- Clearance between the right edge of the text and the scrollbar beside it.
	listGap = 12,
	-- How far the month card rises above the first entry in it.
	cardLip = 5,
	-- The panel title: its baseline below the top edge, and its size.
	titleY = 17,
	titleFs = 20,
	-- How far the month column starts below the text beside it, so the title has room.
	sidebarDrop = 8,
	sidebarW = 200,
	barW = 14,
	-- Rows the wheel moves per notch.
	wheelRows = 3,
	-- Corner radii, taken from FlowUI's so the panel rounds like the rest of the UI.
	csSmall = 2,
	csPanel = 4,
}
local look = {
	-- The month column sits on its own darker card, so it reads apart from the text.
	sidebarFill = { 0, 0, 0, 0.24 },
	sidebarFillTop = { 0, 0, 0, 0.16 },
	selectedFill = { 1, 1, 1, 0.13 },
	white = { 1, 1, 1 },
	-- Entries hover with the same FlowUI highlight the settings list uses, at the
	-- strength it gives a plain row.
	rowHoverOpacity = 0.14,
	colorTitle = { 1, 1, 1, 1 },
	colorLine = { 0.8, 0.77, 0.74, 1 },
}
local colorText = "\255\235\235\235"
local colorSelected = "\255\210\210\205"
local colorDim = "\255\160\160\160"

local listTop = 0
local listBottom = 0
local listX1 = 0
local listRight = 0
local barX1 = 0

-- The markdown layout: sizes, faces and colours the include renders with. Rebuilt on
-- resize, since every size in it is in pixels.
local ctx
-- The laid-out text, one entry per wrapped row, and where each row's top sits in the
-- whole text so the scrollbar can place its thumb exactly.
local rows = {}
local rowTop = {}
local totalH = 0
local startRow = 1
-- The highest startRow that still fills the band.
local maxStart = 1
local dragging = false
-- Where the thumb was taken hold of, as the distance from the cursor to its top edge, so
-- the thumb follows the cursor instead of jumping its middle to wherever the press landed.
local dragGrab = 0
-- Lit while the cursor is on the thumb, and lit further while it is held.
local barHover = false
-- Month column state: the entry under the cursor and the one lit as current. The
-- sidebar list is rebuilt whenever either changes.
local hoverIdx, selectedIdx
local sidebarHover, sidebarSelected, sidebarScroll

-- How far the month column is scrolled, in whole entries. A changelog gathers versions
-- for as long as the game has been going, so this one overflows as a matter of course.
local catScroll = 0
-- Declared here because setStartRow keeps the month being read in view and setLayout
-- clamps the column, and both run well before the column measures itself below.
local revealCategory, setCatScroll

local function dropLists()
	if panelList then
		glDeleteList(panelList)
		panelList = nil
	end
	if sidebarList then
		glDeleteList(sidebarList)
		sidebarList = nil
	end
end

local function deleteGuishader()
	if backgroundGuishader ~= nil then
		if WG.guishader then
			WG.guishader.DeleteDlist("changelog")
		else
			glDeleteList(backgroundGuishader)
		end
		backgroundGuishader = nil
	end
end

-- The chapter whose section holds the given row: the last heading at or above it.
local function versionAt(row)
	if not versions[1] then
		return nil
	end
	local k = 1
	for i = 2, #versions do
		if versions[i] <= row then
			k = i
		else
			break
		end
	end
	return k
end

-- Moves the text so the given row is the first one shown. The current month follows
-- the top row unless a click chose one explicitly, in which case that one stays lit
-- until the text is scrolled again.
local function setStartRow(n, chosen)
	n = mathMax(1, mathMin(maxStart, n))
	if n ~= startRow then
		startRow = n
		if panelList then
			glDeleteList(panelList)
			panelList = nil
		end
	end
	selectedIdx = chosen or versionAt(startRow)
	-- The month being read stays in view, however far the text has been scrolled.
	if selectedIdx then
		revealCategory(selectedIdx)
	end
end

-- Where the text currently sits, in the pixels the scrollbar is drawn against.
local function scrollPos()
	return rows[startRow] and (rowTop[startRow] + rows[startRow].pad) or 0
end

-- The thumb, where it is now. Nil when the whole text fits and no bar is drawn.
local function scrollerThumb()
	return UiScrollerAt(barX1, listBottom, area.x2 - metrics.edgeInset, listTop, totalH, scrollPos())
end

-- Scrolls so the thumb's top sits where the cursor has dragged it. The offset taken at the
-- grab is what keeps this relative: the thumb moves with the cursor rather than centring
-- itself on it, so taking hold of it does not shift the text before the drag begins.
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
	setStartRow(1 + mathFloor(f * (maxStart - 1) + 0.5))
end

-- Takes hold of the bar. On the thumb that is a grab and the text stays put; on the track
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

-- The space a row takes below its text box: the gap to the next block. The last row
-- on a page may let that gap spill past the band, since nothing is drawn in it.
local function rowTail(row)
	return row.h - row.pad - row.box
end

-- The last row that fits on a page starting at `first`. The first row's top padding
-- is not drawn, so it does not count.
local function lastRowFrom(first)
	local band = listTop - listBottom
	local used = -rows[first].pad
	local i = first
	while rows[i] and used + rows[i].h - rowTail(rows[i]) <= band do
		used = used + rows[i].h
		i = i + 1
	end
	return mathMax(first, i - 1)
end

-- Shortens a heading to the month column's width, since the column clips nothing.
local function fitLabel(text)
	local maxW = metrics.sidebarW - metrics.sidePad * 2
	if font:GetTextWidth(text) * metrics.catFs <= maxW then
		return text
	end
	local chars = {}
	for ch in string.gmatch(text, "[%z\1-\127\194-\244][\128-\191]*") do
		chars[#chars + 1] = ch
	end
	local n = #chars
	while n > 1 do
		n = n - 1
		local short = table.concat(chars, "", 1, n) .. "..."
		if font:GetTextWidth(short) * metrics.catFs <= maxW then
			return short
		end
	end
	return "..."
end

-- Lays the whole text out against the text width, so drawing prints ready rows and the
-- scrollbar can measure the text instead of guessing one row per line.
local function layoutRows()
	ctx.width = listRight - listX1 - metrics.sidePad
	rows = Markdown.layout(doc, ctx)
	rowTop = {}
	local off = 0
	for i = 1, #rows do
		rowTop[i] = off
		off = off + rows[i].h
	end
	totalH = off

	versions = {}
	versionLabels = {}
	for _, h in ipairs(doc.headings) do
		if h.level == doc.chapterLevel then
			versions[#versions + 1] = doc.blocks[h.block].firstRow
			versionLabels[#versionLabels + 1] = fitLabel(h.text)
		end
	end
	-- The first row always heads the column, so the latest entry is reachable even
	-- when the file does not open with a heading.
	if rows[1] and versions[1] ~= 1 then
		local first = doc.blocks[1]
		local label = first.inline and Markdown.plainText(first.inline) or ""
		if label == "" then
			label = "..."
		end
		table.insert(versions, 1, 1)
		table.insert(versionLabels, 1, fitLabel(label))
	end

	-- Walked back from the end so the last page is full, the way the keybind editor
	-- finds its own last page. The final row's trailing gap is not part of the text.
	local band = listTop - listBottom
	local i = #rows
	local acc = rows[i] and -rowTail(rows[i]) or 0
	while i > 0 do
		if acc + rows[i].h - rows[i].pad > band then
			break
		end
		acc = acc + rows[i].h
		i = i - 1
	end
	maxStart = mathMax(1, i + 1)
	setStartRow(startRow)
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

	metrics.sidePad = mathFloor(12 * s)
	metrics.catInset = mathFloor(4 * s)
	metrics.catRowHeight = mathFloor(29 * s)
	metrics.catBarW = mathMax(3, mathFloor(6 * s))
	metrics.catFs = mathFloor(metrics.catRowHeight * 0.55 * 0.85)
	metrics.headerH = mathFloor(34 * s)
	metrics.headerGap = mathFloor(4 * s)
	metrics.edgeInset = mathFloor(4 * s)
	metrics.listGap = mathFloor(12 * s)
	metrics.cardLip = mathFloor(5 * s)
	metrics.titleY = mathFloor(17 * s)
	metrics.titleFs = mathFloor(mathFloor(24 * s) * 0.85)
	metrics.sidebarDrop = mathFloor(8 * s)
	metrics.sidebarW = mathFloor(200 * s)
	metrics.barW = mathFloor(14 * s)
	metrics.csPanel = mathFloor(elementCorner)
	metrics.csSmall = mathFloor(elementCorner * 0.66)

	listX1 = area.x1 + metrics.sidebarW + metrics.listGap
	listTop = area.y2 - metrics.headerH - metrics.headerGap
	listBottom = area.y1 + metrics.edgeInset
	-- The scrollbar owns a column of its own against the panel edge, and the text stops
	-- a clear gap short of it, so the bar sits in a channel rather than hugging the rows.
	barX1 = area.x2 - metrics.edgeInset - metrics.barW
	listRight = barX1 - metrics.listGap

	-- A shorter panel holds fewer months, so the column can be left past its own end.
	setCatScroll(catScroll)

	-- The markdown sizes scale with the panel; its palette follows the panel's look.
	ctx = Markdown.defaultContext(s)
	ctx.fonts = { regular = font, bold = fontBold, mono = fontMono }
	ctx.rectRound = RectRound
	ctx.corner = metrics.csSmall
	ctx.colors.text = look.colorLine
	ctx.colors.heading = look.colorTitle
end

-- The month column starts below where the text does, so the title above it is not
-- crowded by the first entry. Everything in the column measures from here.

local function sidebarTop()
	return listTop - metrics.sidebarDrop
end

-- `i` is the entry's place in `versions`, not its place on screen: the two differ by
-- however far the column is scrolled.
local function categoryRect(i)
	local top = sidebarTop() - (i - 1 - catScroll) * metrics.catRowHeight

	return area.x1, top - metrics.catRowHeight, area.x1 + metrics.sidebarW, top
end

-- The month entry under x,y, or nil. Half-open on the shared edge, so one point never
-- lands in two entries.
local function sidebarIndexAt(x, y)
	local top = sidebarTop()
	if x < area.x1 or x > area.x1 + metrics.sidebarW or y > top or y <= listBottom then
		return nil
	end

	local i = mathFloor((top - y) / metrics.catRowHeight) + 1 + catScroll
	if not versions[i] then
		return nil
	end

	local _, y1 = categoryRect(i)
	if y1 < listBottom then
		return nil
	end

	return i
end

-- How many entries the column has room for, and how far it can be scrolled.
local function catPageRows()
	return mathMax(1, mathFloor((sidebarTop() - listBottom) / metrics.catRowHeight))
end

local function maxCatScroll()
	return mathMax(0, #versions - catPageRows())
end

setCatScroll = function(n)
	local m = maxCatScroll()
	catScroll = (n < 0 and 0) or (n > m and m) or n
end

-- Keeps the month being read in view. The column is scrolled by the reader as well, so
-- this only moves it when the entry has actually gone off one end.
revealCategory = function(i)
	if i <= catScroll then
		setCatScroll(i - 1)
	elseif i > catScroll + catPageRows() then
		setCatScroll(i - catPageRows())
	end
end

-- The month column's entries: the lit current one, the hover, then the labels. The card
-- itself is part of the panel list, since it never changes with the cursor.
local function drawSidebar()
	local shown = 0
	for i = catScroll + 1, #versions do
		local x1, y1, x2, y2 = categoryRect(i)
		if y1 < listBottom then
			break
		end
		shown = i
		if i == selectedIdx then
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
		elseif i == hoverIdx then
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
	end

	font:Begin()
	for i = catScroll + 1, shown do
		local x1, y1, _, y2 = categoryRect(i)
		local label = (i == selectedIdx and colorSelected or colorDim) .. versionLabels[i]
		font:Print(label, x1 + metrics.sidePad, mathFloor((y1 + y2) * 0.5), metrics.catFs, "ov")
	end
	font:End()

	-- A bar of its own, and a slim one: the column is narrow and this only shows up when
	-- there are more months than the card has room for.
	if maxCatScroll() > 0 then
		local bx2 = area.x1 + metrics.sidebarW - metrics.catInset
		UiScroller(
			bx2 - metrics.catBarW,
			listBottom,
			bx2,
			sidebarTop(),
			#versions * metrics.catRowHeight,
			catScroll * metrics.catRowHeight
		)
	end
end

-- The panel: its backdrop, the title, the month card, the text and the scrollbar. Baked
-- and replayed until the text scrolls or the screen resizes.
local function drawPanel()
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

	-- Derived from the first entry rather than measured from the panel top, so the card
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

	font:Begin()
	font:SetTextColor(1, 1, 1, 1)
	font:Print(titleText, area.x1 + metrics.sidePad, area.y2 - metrics.titleY, metrics.titleFs, "ov")
	font:End()

	-- Whole rows only: the band can end mid-paragraph, and a row painted below it would
	-- be clipped by nothing.
	if rows[startRow] then
		Markdown.draw(rows, startRow, lastRowFrom(startRow), listX1, listTop, ctx)
	end

	UiScroller(barX1, listBottom, area.x2 - metrics.edgeInset, listTop, totalH, scrollPos(), barHover, dragging)
end

function widget:ViewResize()
	vsx, vsy = spGetViewGeometry()
	widgetScale = (vsy / 1080)

	screenHeight = mathFloor(screenHeightOrg * widgetScale)
	screenWidth = mathFloor(screenWidthOrg * widgetScale)
	screenX = mathFloor((vsx * centerPosX) - (screenWidth / 2))
	screenY = mathFloor((vsy * centerPosY) + (screenHeight / 2))

	-- Bold text takes the heavier weight of the UI face; code takes the monospaced one.
	font = WG.fonts.getFont()
	fontBold = WG.fonts.getFont("fonts/Poppins-Medium.otf")
	fontMono = WG.fonts.getFont(3)
	elementCorner = WG.FlowUI.elementCorner

	RectRound = WG.FlowUI.Draw.RectRound
	UiElement = WG.FlowUI.Draw.Element
	UiScroller = WG.FlowUI.Draw.Scroller
	UiScrollerAt = WG.FlowUI.Draw.ScrollerGeometry
	Highlight = WG.FlowUI.Draw.SelectHighlight

	titleText = colorText .. BAR.I18N("ui.changelog.title")

	setLayout()
	layoutRows()
	dropLists()
	deleteGuishader()
end

function widget:DrawScreen()
	if not (show or showOnceMore) then
		deleteGuishader()
		return
	end

	gl.Texture(false) -- some other widget left it on

	local mx, my, lmb = spGetMouseState()
	if dragging then
		if lmb then
			scrollFromY(my)
		else
			dragging = false
		end
	end

	hoverIdx = show and sidebarIndexAt(mx, my) or nil

	-- Only the thumb, not the track: it is the part that can be taken hold of, so it is the
	-- part that lights up.
	local wasHovered, wasDragging = barHover, dragging
	barHover = false
	if show and mx >= barX1 and mx <= area.x2 then
		local top, height = scrollerThumb()
		barHover = top ~= nil and my <= top and my >= top - height
	end

	-- The bar is painted into the panel list, so a change in how it is lit is a change to
	-- what that list holds.
	if panelList and (barHover ~= wasHovered or dragging ~= wasDragging) then
		panelList = glDeleteList(panelList)
	end

	if not panelList then
		panelList = glCreateList(drawPanel)
	end
	if not sidebarList or hoverIdx ~= sidebarHover or selectedIdx ~= sidebarSelected or catScroll ~= sidebarScroll then
		if sidebarList then
			glDeleteList(sidebarList)
		end
		sidebarList = glCreateList(drawSidebar)
		sidebarHover = hoverIdx
		sidebarSelected = selectedIdx
		sidebarScroll = catScroll
	end

	glCallList(panelList)
	glCallList(sidebarList)

	if WG.guishader and backgroundGuishader == nil then
		backgroundGuishader = glCreateList(function()
			RectRound(screenX, screenY - screenHeight, screenX + screenWidth, screenY, elementCorner, 1, 1, 1, 1)
		end)
		WG.guishader.InsertDlist(backgroundGuishader, "changelog", nil, widget)
	end
	showOnceMore = false

	if math_isInRect(mx, my, screenX, screenY - screenHeight, screenX + screenWidth, screenY) then
		Spring.SetMouseCursor("cursornormal")
	end
end

function widget:KeyPress(key)
	if show and key == 27 then
		-- ESC
		show = false
	end
end

-- Swallowed across the whole panel, not just the text: a wheel that gets through zooms
-- the camera behind it.
function widget:MouseWheel(up, _value)
	if not show then
		return false
	end

	local x, y = spGetMouseState()
	if not math_isInRect(x, y, screenX, screenY - screenHeight, screenX + screenWidth, screenY) then
		return false
	end

	-- Over the column it scrolls the column, over anything else the text. A wheel that
	-- moved the text while the cursor was on the months would read as broken.
	if x <= area.x1 + metrics.sidebarW and y > listBottom and y <= sidebarTop() then
		setCatScroll(catScroll + (up and -1 or 1))
	else
		setStartRow(startRow + (up and -metrics.wheelRows or metrics.wheelRows))
	end
	return true
end

-- Clicks inside the panel pick a month or grab the scrollbar; a press outside closes it.
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
			local i = sidebarIndexAt(x, y)
			if i then
				setStartRow(versions[i], i)
				if playSounds then
					Spring.PlaySoundFile(buttonclick, 0.6, "ui")
				end
			elseif math_isInRect(x, y, barX1, listBottom, area.x2, listTop) then
				-- The strip between the bar and the panel edge stays grabbable too.
				grabScroller(y)
			end
		end

		return true
	elseif not release then
		-- Only a press outside closes. A release out here belongs to a drag that started
		-- on the scrollbar.
		showOnceMore = true -- show once more because the guishader lags behind
		show = false
		return true
	end
end

function widget:MousePress(x, y, button)
	return mouseEvent(x, y, button, false)
end

function widget:MouseRelease(x, y, button)
	return mouseEvent(x, y, button, true)
end

function widget:Initialize()
	if not changelogFile then
		Spring.Echo("Changelog: couldn't load the changelog file")
		widgetHandler:RemoveWidget()
		return
	end

	-- lets the handler hide the rest of the interface while the panel is open
	widgetHandler:RegisterModalWindow(function()
		return show == true
	end)

	WG.changelog = {}
	WG.changelog.toggle = function(state)
		if state ~= nil then
			show = state
		else
			show = not show
		end
		if show then
			lastviewedHash = changelogFileHash
			if changelogFileLength > lastviewedChangelogLength then
				lastviewedChangelogLength = changelogFileLength
			end
		end
	end
	WG.changelog.isvisible = function()
		return show
	end
	WG.changelog.haschanges = function()
		return lastviewedHash ~= changelogFileHash and lastviewedChangelogLength < changelogFileLength
	end

	doc = Markdown.parse(changelogFile)

	widget:ViewResize()
end

function widget:Shutdown()
	dropLists()
	deleteGuishader()
end

function widget:LanguageChanged()
	widget:ViewResize()
end

function widget:GetConfigData()
	return {
		lastviewedHash = lastviewedHash,
		lastviewedChangelogLength = lastviewedChangelogLength,
	}
end

function widget:SetConfigData(data)
	if data.lastviewedHash ~= nil then
		lastviewedHash = data.lastviewedHash
	end
	if data.lastviewedChangelogLength ~= nil then
		lastviewedChangelogLength = data.lastviewedChangelogLength
	end
end
