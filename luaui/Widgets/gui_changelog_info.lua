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

local changelogFile = VFS.LoadFile("changelog.txt")
-- Convert tabs to 4 spaces
changelogFile = string.gsub(changelogFile, "\t", "    ")
local changelogFileHash = VFS.CalculateHash(changelogFile, 0)
local changelogFileLength = string.len(changelogFile)
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

local versions = {} -- version k -> index of the changelog line its heading is on
local versionLabels = {} -- version k -> the heading text shown in the month column
local changelogLines = {}

local showOnceMore = false -- used because of GUI shader delay

---@type function
local RectRound
---@type function
local UiElement
---@type function
local UiScroller
---@type function
local Highlight
local elementCorner
local font, loadedFontSize
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
	-- Text rows: the heading size plus a separator, shared by every kind of line so the
	-- scrollbar can count rows.
	lineH = 19,
	fsTitle = 17,
	fsDate = 13,
	fsLine = 15,
	-- Body lines and dates sit this far in from the headings; bullet text a further step.
	bodyX = 9,
	bulletX = 26,
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
	colorDate = { 0.66, 0.88, 0.66, 1 },
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

-- One entry per changelog line: the rows it wraps into, where they print and how, so
-- the draw loop and the scroll math count the same rows.
local layout = {}
-- Rows above each line, so the scrollbar knows where a line sits in the whole text.
local lineOff = {}
local totalRows = 0
local startLine = 1
-- The highest startLine that still fills the band with whole entries.
local maxStart = 1
local dragging = false
-- Month column state: the entry under the cursor and the one lit as current. The
-- sidebar list is rebuilt whenever either changes.
local hoverIdx, selectedIdx
local sidebarHover, sidebarSelected

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

-- The version whose section holds the given line: the last heading at or above it.
local function versionAt(line)
	if not versions[1] then
		return nil
	end
	local k = 1
	for i = 2, #versions do
		if versions[i] <= line then
			k = i
		else
			break
		end
	end
	return k
end

-- Moves the text so the given line is the first one shown. The current month follows
-- the top line unless a click chose one explicitly, in which case that one stays lit
-- until the text is scrolled again.
local function setStartLine(n, chosen)
	n = mathMax(1, mathMin(maxStart, n))
	if n ~= startLine then
		startLine = n
		if panelList then
			glDeleteList(panelList)
			panelList = nil
		end
	end
	selectedIdx = chosen or versionAt(startLine)
end

-- Cursor height in the band mapped straight onto the scroll range, as the keybind
-- editor's bar does: the top of the bar is the start, the bottom the end.
local function scrollFromY(y)
	local f = (listTop - y) / mathMax(1, listTop - listBottom)
	if f < 0 then
		f = 0
	elseif f > 1 then
		f = 1
	end
	setStartLine(1 + mathFloor(f * (maxStart - 1) + 0.5))
end

local function splitRows(s)
	local rows = {}
	for row in string.gmatch(s .. "\n", "([^\n]*)\n") do
		rows[#rows + 1] = row
	end
	if #rows == 0 then
		rows[1] = ""
	end
	return rows
end

-- Wraps every line once against the text width, so drawing prints ready rows and the
-- scrollbar can measure the whole text instead of guessing one row per line.
local function layoutLines()
	layout = {}
	lineOff = {}
	local off = 0
	local fsLine = metrics.fsLine
	local scaleToFont = loadedFontSize / fsLine
	local textW = listRight - listX1 - metrics.sidePad
	local wrapBullet = (textW - metrics.bodyX - metrics.bulletX) * scaleToFont
	local wrapPlain = (textW - metrics.bodyX) * scaleToFont

	for i, line in ipairs(changelogLines) do
		local entry
		if
			string.find(line, "^([0-9][0-9][/][0-9][0-9][/][0-9][0-9])")
			or string.find(line, "^([0-9][/][0-9][0-9][/][0-9][0-9])")
		then
			-- date line
			entry = { rows = { line }, x = metrics.bodyX, fs = metrics.fsDate, color = look.colorDate }
		elseif string.find(line, "^# ") then
			-- version line
			entry = { rows = { string.sub(line, 3) }, x = 0, fs = metrics.fsTitle, color = look.colorTitle }
		elseif string.find(line, "^(-)") then
			-- bulletpointed line
			local firstLetterPos = 2
			if string.find(line, "^(- )") then
				firstLetterPos = 3
			end
			local text = string.upper(string.sub(line, firstLetterPos, firstLetterPos))
				.. string.sub(line, firstLetterPos + 1)
			entry = {
				rows = splitRows((font:WrapText(text, wrapBullet))),
				x = metrics.bodyX + metrics.bulletX,
				fs = fsLine,
				color = look.colorLine,
				bullet = true,
			}
		else
			entry = {
				rows = splitRows((font:WrapText(line, wrapPlain))),
				x = metrics.bodyX,
				fs = fsLine,
				color = look.colorLine,
			}
		end
		layout[i] = entry
		lineOff[i] = off
		off = off + #entry.rows
	end
	totalRows = off

	-- Walked back from the end so the last page is full of whole entries, the way the
	-- keybind editor finds its own last page.
	local rowsFit = mathFloor((listTop - listBottom) / metrics.lineH)
	local used = 0
	local i = #layout
	while i > 0 do
		local n = #layout[i].rows
		if used + n > rowsFit then
			break
		end
		used = used + n
		i = i - 1
	end
	maxStart = mathMax(1, i + 1)
	setStartLine(startLine)
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
	metrics.fsTitle = mathFloor(17 * s)
	metrics.fsDate = mathFloor(13 * s)
	metrics.fsLine = mathFloor(15 * s)
	metrics.lineH = metrics.fsTitle + mathFloor(2 * s)
	metrics.bodyX = mathFloor(9 * s)
	metrics.bulletX = mathFloor(26 * s)
	metrics.csPanel = mathFloor(elementCorner)
	metrics.csSmall = mathFloor(elementCorner * 0.66)

	listX1 = area.x1 + metrics.sidebarW + metrics.listGap
	listTop = area.y2 - metrics.headerH - metrics.headerGap
	listBottom = area.y1 + metrics.edgeInset
	-- The scrollbar owns a column of its own against the panel edge, and the text stops
	-- a clear gap short of it, so the bar sits in a channel rather than hugging the rows.
	barX1 = area.x2 - metrics.edgeInset - metrics.barW
	listRight = barX1 - metrics.listGap
end

-- The month column starts below where the text does, so the title above it is not
-- crowded by the first entry. Everything in the column measures from here.
local function sidebarTop()
	return listTop - metrics.sidebarDrop
end

local function categoryRect(i)
	local top = sidebarTop() - (i - 1) * metrics.catRowHeight

	return area.x1, top - metrics.catRowHeight, area.x1 + metrics.sidebarW, top
end

-- The month entry under x,y, or nil. Half-open on the shared edge, so one point never
-- lands in two entries.
local function sidebarIndexAt(x, y)
	local top = sidebarTop()
	if x < area.x1 or x > area.x1 + metrics.sidebarW or y > top or y <= listBottom then
		return nil
	end

	local i = mathFloor((top - y) / metrics.catRowHeight) + 1
	if not versions[i] then
		return nil
	end

	local _, y1 = categoryRect(i)
	if y1 < listBottom then
		return nil
	end

	return i
end

-- The month column's entries: the lit current one, the hover, then the labels. The card
-- itself is part of the panel list, since it never changes with the cursor.
local function drawSidebar()
	local n = #versions
	local shown = 0
	for i = 1, n do
		local x1, y1, x2, y2 = categoryRect(i)
		if y1 < listBottom then
			break
		end
		shown = i
		if i == selectedIdx then
			RectRound(x1 + metrics.catInset, y1, x2 - metrics.catInset, y2, metrics.csSmall, 1, 1, 1, 1, look.selectedFill)
		elseif i == hoverIdx then
			Highlight(x1 + metrics.catInset, y1, x2 - metrics.catInset, y2, metrics.csSmall, look.rowHoverOpacity, look.white)
		end
	end

	font:Begin()
	for i = 1, shown do
		local x1, y1, _, y2 = categoryRect(i)
		local label = (i == selectedIdx and colorSelected or colorDim) .. versionLabels[i]
		font:Print(label, x1 + metrics.sidePad, mathFloor((y1 + y2) * 0.5), metrics.catFs, "ov")
	end
	font:End()
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

	-- Whole entries only: the band can end mid-entry, and a row painted below it would
	-- be clipped by nothing.
	local lineH = metrics.lineH
	local rowsFit = mathFloor((listTop - listBottom) / lineH)
	local r = 0
	local i = startLine
	while layout[i] do
		local e = layout[i]
		local rows = e.rows
		if r + #rows > rowsFit then
			break
		end
		local x = listX1 + e.x
		font:SetTextColor(e.color)
		if e.bullet then
			font:Print("   - ", listX1 + metrics.bodyX, listTop - (r + 1) * lineH, e.fs, "n")
		end
		for k = 1, #rows do
			font:Print(rows[k], x, listTop - (r + k) * lineH, e.fs, "n")
		end
		r = r + #rows
		i = i + 1
	end
	font:End()

	UiScroller(barX1, listBottom, area.x2 - metrics.edgeInset, listTop, totalRows * lineH, lineOff[startLine] * lineH)
end

function widget:ViewResize()
	vsx, vsy = spGetViewGeometry()
	widgetScale = (vsy / 1080)

	screenHeight = mathFloor(screenHeightOrg * widgetScale)
	screenWidth = mathFloor(screenWidthOrg * widgetScale)
	screenX = mathFloor((vsx * centerPosX) - (screenWidth / 2))
	screenY = mathFloor((vsy * centerPosY) + (screenHeight / 2))

	font, loadedFontSize = WG.fonts.getFont()
	elementCorner = WG.FlowUI.elementCorner

	RectRound = WG.FlowUI.Draw.RectRound
	UiElement = WG.FlowUI.Draw.Element
	UiScroller = WG.FlowUI.Draw.Scroller
	Highlight = WG.FlowUI.Draw.SelectHighlight

	titleText = colorText .. BAR.I18N("ui.changelog.title")

	setLayout()
	layoutLines()
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

	if not panelList then
		panelList = glCreateList(drawPanel)
	end
	if not sidebarList or hoverIdx ~= sidebarHover or selectedIdx ~= sidebarSelected then
		if sidebarList then
			glDeleteList(sidebarList)
		end
		sidebarList = glCreateList(drawSidebar)
		sidebarHover = hoverIdx
		sidebarSelected = selectedIdx
	end

	glCallList(panelList)
	glCallList(sidebarList)

	if WG.guishader and backgroundGuishader == nil then
		backgroundGuishader = glCreateList(function()
			RectRound(screenX, screenY - screenHeight, screenX + screenWidth, screenY, elementCorner, 1, 1, 1, 1)
		end)
		WG.guishader.InsertDlist(backgroundGuishader, "changelog")
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

	setStartLine(startLine + (up and -3 or 3))
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

	if math_isInRect(x, y, screenX, screenY - screenHeight, screenX + screenWidth, screenY) then
		if not release and button == 1 then
			local i = sidebarIndexAt(x, y)
			if i then
				setStartLine(versions[i], i)
				if playSounds then
					Spring.PlaySoundFile(buttonclick, 0.6, "ui")
				end
			elseif math_isInRect(x, y, barX1, listBottom, area.x2, listTop) then
				-- The strip between the bar and the panel edge stays grabbable too.
				dragging = true
				scrollFromY(y)
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

	-- store changelog into array
	changelogLines = string.lines(changelogFile)

	-- The first line always heads the column, so the latest entry is reachable even
	-- when the file does not open with a heading.
	local versionKey = 0
	for i, line in ipairs(changelogLines) do
		if versionKey == 0 or string.match(line, "^# ") then
			versionKey = versionKey + 1
			versions[versionKey] = i
			versionLabels[versionKey] = string.match(line, "^# (.*)") or line
		end
	end
	selectedIdx = versionAt(startLine)

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
