--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Widget Profiler",
		desc = "",
		author = "jK, Bluestone",
		version = "2.0",
		date = "2007+",
		license = "GNU GPL, v2 or later",
		layer = -99900,
		handler = true,
		enabled = false,
	}
end

-- Localized functions for performance
local mathFloor = math.floor
local mathMax = math.max
local mathMin = math.min
local mathRandom = math.random
local mathExp = math.exp
local tableSort = table.sort
local stringChar = string.char
local stringSub = string.sub
local stringFind = string.find
local stringLower = string.lower
local stringFormat = string.format
local stringGmatch = string.gmatch
local stringMatch = string.match
local pairs = pairs
local next = next
local tonumber = tonumber
local type = type

-- Localized Spring API for performance
local spEcho = Spring.Echo
local glText = gl.Text
local glColor = gl.Color
local glBeginText = gl.BeginText
local glEndText = gl.EndText
local glGetViewSizes = gl.GetViewSizes
local glRect = gl.Rect
local glGetTextWidth = gl.GetTextWidth

-- The measurement itself, which the widget selector reads too. Wrapping every callin is
-- global and does not nest, so exactly one thing may do it; this widget draws what that
-- one thing measures.
local profiling = VFS.Include("luaui/Include/widget_profiling.lua")

local usePrefixedNames = true

local minPerc = 0.005 -- above this value, we fade in how red we mark a widget
local maxPerc = 0.02 -- above this value, we mark a widget as red
local minSpace = 10 -- Kb
local maxSpace = 100

local title_colour = "\255\160\255\160"
local totals_colour = "\255\200\200\255"

local prefixColor = {
	gui = "\255\100\222\100",
	gfx = "\255\222\160\100",
	game = "\255\166\166\255",
	cmd = "\255\166\255\255",
	unit = "\255\255\166\255",
	map = "\255\255\255\080",
	dbg = "\255\120\120\120",
}

local userWidgets = {}

local sortedList = {}
-- Copied off the include on each sample, since the drawing reads them many times over.
local lm, gm, um, sm = 0, 0, 0, 0
local allOverTime = 0
local allOverSpace = 0

local selectedWidget = nil -- name of the widget currently drilled into, or nil
local clickableRows = {} -- reused each frame: { {x1, y1, x2, y2, plainname}, ... }
local clickableRowCount = 0 -- how many entries of clickableRows are valid this frame
local detailColour = "\255\255\255\255"

local redStrength = {}
local ColorString = BAR.Utilities.Color.ToString

local prefixedWnames = {}
local widgetNameColors = {} -- Store RGB values for background tinting
local function ConstructPrefixedName(ghInfo)
	local gadgetName = ghInfo.name
	local baseName = ghInfo.basename
	local _pos = stringFind(baseName, "_", 1, true)
	local prefix = ""
	if _pos and usePrefixedNames then
		local prefixKey = stringSub(baseName, 1, _pos - 1)
		local prefixClr = prefixColor[prefixKey] or "\255\166\166\166"
		prefix = prefixClr .. prefixKey .. "     "
	end
	-- Cache random color generation with more contrast
	local r, g, b = mathRandom(30, 255), mathRandom(30, 255), mathRandom(30, 255)
	-- Ensure at least one channel is bright for visibility and prevent too dark colors
	local maxChannel = mathMax(r, g, b)
	if maxChannel < 150 then
		-- If all channels are too dark, make at least one bright
		local brightChannel = mathRandom(1, 3)
		if brightChannel == 1 then
			r = mathRandom(180, 255)
		elseif brightChannel == 2 then
			g = mathRandom(180, 255)
		else
			b = mathRandom(180, 255)
		end
	end
	widgetNameColors[gadgetName] = { r / 255, g / 255, b / 255 } -- Store normalized RGB
	prefixedWnames[gadgetName] = prefix .. stringChar(255, r, g, b) .. gadgetName .. "   "
	return prefixedWnames[gadgetName]
end

local function widgetprofilertickrateCmd(_, line)
	local token = {}
	local n = 0
	for w in stringGmatch(line or "", "%S+") do
		n = n + 1
		token[n] = w
	end
	if token[1] then
		profiling.setTick(token[1])
	end
	spEcho("Setting widget profiler to tick=", profiling.getTick())
	return true
end

function widget:Initialize()
	if widgetHandler.AddAction then
		widgetHandler:AddAction("widgetprofilertickrate", widgetprofilertickrateCmd, nil, "t")
	elseif widgetHandler.actionHandler and widgetHandler.actionHandler.AddAction then
		widgetHandler.actionHandler:AddAction(self, "widgetprofilertickrate", widgetprofilertickrateCmd, nil, "t")
	end

	for name, wData in pairs(widgetHandler.knownWidgets) do
		userWidgets[name] = not wData.fromZip
	end

	-- Being loaded is this widget's on switch, so this is where the hooks go in. The
	-- include counts who wants them; the widget selector may already have asked.
	profiling.subscribe(self)
end

function widget:Shutdown()
	if widgetHandler.RemoveAction then
		widgetHandler:RemoveAction("widgetprofilertickrate", "t")
	elseif widgetHandler.actionHandler and widgetHandler.actionHandler.RemoveAction then
		widgetHandler.actionHandler:RemoveAction(self, "widgetprofilertickrate", "t")
	end
	profiling.unsubscribe(self)
end

-- Click a widget row to drill into its per-callin breakdown; click it again to close.
function widget:MousePress(mx, my, button)
	if button ~= 1 or clickableRowCount == 0 then
		return false
	end
	for i = 1, clickableRowCount do
		local r = clickableRows[i]
		if mx >= r[1] and mx <= r[3] and my >= r[2] and my <= r[4] then
			if selectedWidget == r[5] then
				selectedWidget = nil
			else
				selectedWidget = r[5]
			end
			-- Only one breakdown is smoothed at a time, and setting it starts a fresh window.
			profiling.setDetail(selectedWidget)
			return true
		end
	end
	return false
end

-- Precompute constants for GetRedColourStrings
local colorScaleFactor = (255 - 64) / 255
local percRange = maxPerc - minPerc
local spaceRange = maxSpace - minSpace

function GetRedColourStrings(v)
	-- tLoad is %
	local tTime = v.tTime
	local sLoad = v.sLoad
	local name = v.plainname
	local u = mathExp(-profiling.deltaTime / 5) --magic colour changing rate
	local oneMinusU = 1 - u

	-- Clamp tTime
	if tTime > maxPerc then
		tTime = maxPerc
	elseif tTime < minPerc then
		tTime = minPerc
	end

	-- time
	local new_r = (tTime - minPerc) / percRange
	local timeKey = name .. "_time"
	redStrength[timeKey] = redStrength[timeKey] or 0
	redStrength[timeKey] = u * redStrength[timeKey] + oneMinusU * new_r
	local timeRedStrength = redStrength[timeKey]
	local colorFactor = 1 - timeRedStrength * colorScaleFactor
	v.timeColourString = ColorString(1, colorFactor, colorFactor)

	-- space
	new_r = (sLoad - minSpace) / spaceRange
	if new_r > 1 then
		new_r = 1
	elseif new_r < 0 then
		new_r = 0
	end
	local spaceKey = name .. "_space"
	redStrength[spaceKey] = redStrength[spaceKey] or 0
	redStrength[spaceKey] = u * redStrength[spaceKey] + oneMinusU * new_r
	local spaceColorFactor = 1 - redStrength[spaceKey] * colorScaleFactor
	v.spaceColourString = ColorString(1, spaceColorFactor, spaceColorFactor)
end

-- Helper function to render percentage with dimmed leading zeros
local function DrawPercentWithDimmedZeros(colorString, value, x, y, fontSize, decimalPlaces)
	local formatStr = "%." .. (decimalPlaces or 3) .. "f%%"
	local formatted = stringFormat(formatStr, value)
	local leadingPart, significantPart = stringMatch(formatted, "^(0%.0*)(.+)$")

	if leadingPart then
		-- Has leading zeros - render them dimmed
		glText(colorString .. "\255\140\140\140" .. leadingPart, x, y, fontSize, "no")
		local leadingWidth = glGetTextWidth(leadingPart) * fontSize
		glText(colorString .. significantPart, x + leadingWidth, y, fontSize, "no")
	else
		-- No leading zeros - render normally
		glText(colorString .. formatted, x, y, fontSize, "no")
	end
end

-- Helper function to render memory allocation with dimmed leading zeros
local function DrawMemoryWithDimmedZeros(colorString, value, x, y, fontSize, decimalPlaces, suffix)
	local formatStr = "%." .. (decimalPlaces or 1) .. "f"
	local formatted = stringFormat(formatStr, value)

	-- Check if value is 0.0 (all zeros)
	if tonumber(formatted) == 0 then
		-- Render entire "0.0" dimmed
		glText(colorString .. "\255\150\150\150" .. formatted .. suffix, x, y, fontSize, "no")
	else
		local leadingPart, significantPart = stringMatch(formatted, "^(0%.0*)(.+)$")
		if leadingPart then
			-- Has leading zeros - render them dimmed
			glText(colorString .. "\255\150\150\150" .. leadingPart, x, y, fontSize, "no")
			local leadingWidth = glGetTextWidth(leadingPart) * fontSize
			glText(colorString .. significantPart .. suffix, x + leadingWidth, y, fontSize, "no")
		else
			-- No leading zeros - render normally
			glText(colorString .. formatted .. suffix, x, y, fontSize, "no")
		end
	end
end

-- Advance to the next column; when crossing left out of the first column, also
-- skip past the band reserved for the detail panel.
local function nextColumn(x, colWidth, firstColX, reserve)
	return x - colWidth - (x >= firstColX and reserve or 0)
end

function DrawWidgetList(list, name, x, y, j, fontSize, lineSpace, maxLines, colWidth, dataColWidth, firstColX, reserve)
	reserve = reserve or 0
	if j >= maxLines - 5 then
		x = nextColumn(x, colWidth, firstColX, reserve)
		j = 0
	end
	j = j + 1
	glText(title_colour .. name .. " WIDGETS", x + 152, y - lineSpace * j, fontSize, "no")
	j = j + 2

	local listLen = #list
	for i = 1, listLen do
		if j >= maxLines then
			x = nextColumn(x, colWidth, firstColX, reserve)
			j = 0
		end
		local v = list[i]
		local textY = y - lineSpace * j

		-- Draw tinted background and colored square for widget line
		local color = widgetNameColors[v.name]
		if color then
			-- Draw opaque colored square on the left
			glColor(color[1], color[2], color[3], 1.0)
			glRect(x - 12, textY - 3, x - 5, textY + fontSize - 3)

			-- Draw subtle tinted background across the whole line
			glColor(color[1], color[2], color[3], 0.25)
			glRect(x - 5, textY - 3, x + colWidth - 15, textY + fontSize - 3)

			glColor(1, 1, 1, 1) -- Reset color
		end

		-- Highlight the row that is currently drilled into
		if v.plainname == selectedWidget then
			glColor(1, 1, 1, 0.18)
			glRect(x - 12, textY - 3, x + colWidth - 15, textY + fontSize - 3)
			glColor(1, 1, 1, 1)
		end

		-- Record click target so MousePress can map a click back to this widget.
		-- Reuse the row tables across frames to avoid per-frame GC churn.
		clickableRowCount = clickableRowCount + 1
		local r = clickableRows[clickableRowCount]
		if not r then
			r = {}
			clickableRows[clickableRowCount] = r
		end
		r[1], r[2], r[3], r[4], r[5] = x - 12, textY - 3, x + colWidth - 15, textY + fontSize - 3, v.plainname

		DrawPercentWithDimmedZeros(v.timeColourString, v.tLoad, x, textY, fontSize)
		DrawMemoryWithDimmedZeros(v.spaceColourString, v.sLoad, x + dataColWidth, textY, fontSize, 1, "kB/s")
		glText(v.fullname, x + dataColWidth * 2, textY, fontSize, "no")
		j = j + 1
	end

	DrawPercentWithDimmedZeros(totals_colour, list.allOverTime, x, y - lineSpace * j, fontSize, 2)
	DrawMemoryWithDimmedZeros(
		totals_colour,
		list.allOverSpace,
		x + dataColWidth,
		y - lineSpace * j,
		fontSize,
		0,
		"kB/s"
	)
	glText(
		totals_colour .. "totals (" .. stringLower(name) .. ")",
		x + dataColWidth * 2,
		y - lineSpace * j,
		fontSize,
		"no"
	)
	j = j + 1

	return x, j
end

-- Drill-down view: every callin of the selected widget, sorted by cpu time
local function DrawDetailPanel(x, y, fontSize, lineSpace, panelWidth)
	local avgs = selectedWidget and profiling.callins(selectedWidget)
	if not avgs then
		return
	end

	-- Hide a callin only when BOTH its cpu and alloc rate are negligible; hidden
	-- callins still count towards the total so it stays accurate.
	local minCallinPerc = 0.003 -- % of running time
	local minCallinKB = 0.1 -- kB/s allocated

	local list = {}
	local hidden = 0
	local total_t, total_s = 0, 0
	for cname, a in pairs(avgs) do
		total_t = total_t + a[1]
		total_s = total_s + a[2]
		if a[1] >= minCallinPerc or a[2] >= minCallinKB then
			list[#list + 1] = { name = cname, tLoad = a[1], sLoad = a[2] }
		else
			hidden = hidden + 1
		end
	end
	tableSort(list, function(a, b)
		return a.tLoad > b.tLoad
	end)

	local colW = fontSize * 8 -- one column width, wide enough for "9999.9 kB/s"
	local timeColX = x
	local allocsColX = x + colW
	local callinColX = x + colW * 2
	local panelRight = x + panelWidth

	-- Fixed lines: title, blank, header, total, blank, close-hint (+ optional hidden line)
	local lineCount = #list + 6 + (hidden > 0 and 1 or 0)

	-- translucent backdrop (drawn first so the text lands on top of it)
	glColor(0, 0, 0, 0.55)
	glRect(x - 10, y - lineSpace * lineCount - 3, panelRight, y + lineSpace)
	glColor(1, 1, 1, 1)

	-- Line cursor: returns the current line's y, then advances past it plus any trailing blanks.
	local cy = y
	local function line(blanks)
		local ly = cy
		cy = cy - lineSpace * (1 + (blanks or 0))
		return ly
	end

	glText(title_colour .. "CALLIN BREAKDOWN  " .. detailColour .. selectedWidget, x, line(1), fontSize, "no")

	local hy = line()
	glText(totals_colour .. "time", timeColX, hy, fontSize, "no")
	glText(totals_colour .. "allocs", allocsColX, hy, fontSize, "no")
	glText(totals_colour .. "callin", callinColX, hy, fontSize, "no")

	for i = 1, #list do
		local v = list[i]
		local ry = line()
		DrawPercentWithDimmedZeros(detailColour, v.tLoad, timeColX, ry, fontSize)
		DrawMemoryWithDimmedZeros(detailColour, v.sLoad, allocsColX, ry, fontSize, 1, "kB/s")
		glText(detailColour .. v.name, callinColX, ry, fontSize, "no")
	end

	local ty = line()
	DrawPercentWithDimmedZeros(totals_colour, total_t, timeColX, ty, fontSize, 2)
	DrawMemoryWithDimmedZeros(totals_colour, total_s, allocsColX, ty, fontSize, 0, "kB/s")
	glText(totals_colour .. "total", callinColX, ty, fontSize, "no")

	if hidden > 0 then
		glText(
			totals_colour .. "\255\140\140\140" .. stringFormat("(%d negligible callins hidden)", hidden),
			x,
			line(),
			fontSize,
			"no"
		)
	end

	line() -- blank separator before the close hint
	glText(title_colour .. "click the widget again to close", x, line(), fontSize, "no")
end

function widget:DrawScreen()
	-- Whatever else is subscribed, the numbers are only recomputed on a tick; this
	-- answers true on the frames a new set landed, which is when the list is rebuilt.
	if profiling.sample() then
		sortedList = {}
		allOverTime = 0
		allOverSpace = 0
		local n = 1
		local sortByLoad = Spring.GetConfigInt("profiler_sort_by_load", 1) == 1

		for name, stat in pairs(profiling.stats) do
			if not sortByLoad or stat.avg >= 0.05 or stat.space >= 5 then -- only show heavy ones
				sortedList[n] = {
					name = name,
					plainname = name,
					fullname = (prefixedWnames[name] or ConstructPrefixedName({ name = name, basename = name }))
						.. " ­vvv("
						.. stat.peakTime
						.. ","
						.. stat.peakSpace
						.. ")",
					tLoad = stat.load,
					sLoad = stat.space,
					tTime = stat.share,
					avgTLoad = stat.avg,
				}
				n = n + 1
			end
		end

		allOverTime, allOverSpace = profiling.total.load, profiling.total.space

		if sortByLoad then
			tableSort(sortedList, function(a, b)
				return a.avgTLoad > b.avgTLoad
			end)
		else
			tableSort(sortedList, function(a, b)
				return a.name < b.name
			end)
		end

		local sortedLen = #sortedList
		for i = 1, sortedLen do
			GetRedColourStrings(sortedList[i])
		end
		lm, gm, um, sm = profiling.mem.lua, profiling.mem.global, profiling.mem.unsynced, profiling.mem.shared
	end

	if not sortedList[1] then
		return
	end

	-- add to category and set colour
	local userList = {}
	local userListCount = 0
	local gameList = {}
	local gameListCount = 0
	userList.allOverTime = 0
	gameList.allOverTime = 0
	userList.allOverSpace = 0
	gameList.allOverSpace = 0
	local sortedLen = #sortedList
	for i = 1, sortedLen do
		local item = sortedList[i]
		if userWidgets[item.plainname] then
			userListCount = userListCount + 1
			userList[userListCount] = item
			userList.allOverTime = userList.allOverTime + item.tLoad
			userList.allOverSpace = userList.allOverSpace + item.sLoad
		else
			gameListCount = gameListCount + 1
			gameList[gameListCount] = item
			gameList.allOverTime = gameList.allOverTime + item.tLoad
			gameList.allOverSpace = gameList.allOverSpace + item.sLoad
		end
	end

	-- draw
	local vsx, vsy = glGetViewSizes()

	local fontSize = mathMax(11, mathFloor(vsy / 90))
	local lineSpace = fontSize + 2

	local dataColWidth = fontSize * 5
	local colWidth = vsx * 0.98 / 4

	local firstColX = vsx - colWidth
	local x, y = firstColX, vsy * 0.77 -- initial coord for writing
	local maxLines = mathMax(20, mathFloor(y / lineSpace) - 3)
	local j = -1 --line number

	-- When a widget is drilled into, reserve a band immediately left of the first
	-- column for the detail panel; overflow columns then wrap to the left of it.
	-- detail panel: two 8-wide data columns (time, allocs) + room for the callin name
	local panelGap = fontSize * 2 -- gutter between the panel and the first column
	local panelWidth = mathMin(colWidth - panelGap, fontSize * 30)
	local reserve = selectedWidget and (panelWidth + panelGap) or 0

	clickableRowCount = 0 -- refilled below so MousePress hit-testing matches what is on screen

	glColor(1, 1, 1, 1)
	glBeginText()

	x, j = DrawWidgetList(
		gameList,
		"GAME",
		x,
		y,
		j,
		fontSize,
		lineSpace,
		maxLines,
		colWidth,
		dataColWidth,
		firstColX,
		reserve
	)
	x, j = DrawWidgetList(
		userList,
		"USER",
		x,
		y,
		j,
		fontSize,
		lineSpace,
		maxLines,
		colWidth,
		dataColWidth,
		firstColX,
		reserve
	)

	if j >= maxLines - 15 then
		x = nextColumn(x, colWidth, firstColX, reserve)
		j = -1
	end

	if selectedWidget then
		-- Fixed slot in the reserved band, just left of the first column.
		DrawDetailPanel(firstColX - panelWidth - panelGap, vsy * 0.77, fontSize, lineSpace, panelWidth)
	end
	j = j + 1
	glText(title_colour .. "ALL", x + dataColWidth * 2, y - lineSpace * j, fontSize, "no")
	j = j + 1

	j = j + 1
	glText(
		totals_colour .. "total percentage of running time spent in luaui callins",
		x + dataColWidth * 2,
		y - lineSpace * j,
		fontSize,
		"no"
	)
	glText(totals_colour .. stringFormat("%.1f%%", allOverTime), x + dataColWidth, y - lineSpace * j, fontSize, "no")
	j = j + 1
	glText(
		totals_colour .. "total rate of mem allocation by luaui callins",
		x + dataColWidth * 2,
		y - lineSpace * j,
		fontSize,
		"no"
	)
	glText(
		totals_colour .. stringFormat("%.0f", allOverSpace) .. "kB/s",
		x + dataColWidth,
		y - lineSpace * j,
		fontSize,
		"no"
	)

	-- Cache memory calculations
	local gmMB = gm / 1000
	local lmPercent = 100 * lm / gm
	local umPercent = 100 * um / gm
	local smPercent = 100 * sm / gm

	j = j + 2
	glText(
		totals_colour .. "total lua memory usage is " .. stringFormat("%.0f", gmMB) .. "MB, of which:",
		x,
		y - lineSpace * j,
		fontSize,
		"no"
	)
	j = j + 1
	glText(
		totals_colour .. "  " .. stringFormat("%.0f", lmPercent) .. "% is from luaui",
		x,
		y - lineSpace * j,
		fontSize,
		"no"
	)
	j = j + 1
	glText(
		totals_colour .. "  " .. stringFormat("%.0f", umPercent) .. "% is from unsynced states (luarules+luagaia+luaui)",
		x,
		y - lineSpace * j,
		fontSize,
		"no"
	)
	j = j + 1
	glText(
		totals_colour .. "  " .. stringFormat("%.0f", smPercent) .. "% is from synced states (luarules+luagaia)",
		x,
		y - lineSpace * j,
		fontSize,
		"no"
	)

	j = j + 2
	glText(
		title_colour .. "All data excludes load from garbage collection & executing GL calls",
		x,
		y - lineSpace * j,
		fontSize,
		"no"
	)
	j = j + 1
	glText(
		title_colour .. "Callins in brackets are heaviest per widget for (time,allocs)",
		x,
		y - lineSpace * j,
		fontSize,
		"no"
	)

	j = j + 2
	glText(title_colour .. "Tick time: " .. profiling.getTick() .. "s", x, y - lineSpace * j, fontSize, "no")
	j = j + 1
	-- Read here rather than carried down from the sampling block, which moved into the
	-- profiling include along with the smoothing it names.
	glText(
		title_colour .. "Smoothing time: " .. Spring.GetConfigFloat("profiler_averagetime", 2) .. "s",
		x,
		y - lineSpace * j,
		fontSize,
		"no"
	)

	glEndText()
end
