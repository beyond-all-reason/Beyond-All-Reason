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
		layer = -1000000,
		handler = true,
		enabled = false
	}
end


-- Localized functions for performance
local mathFloor = math.floor
local mathMax = math.max
local mathMin = math.min
local mathRandom = math.random
local mathExp = math.exp
local tableSort = table.sort
local tableInsert = table.insert
local tableRemove = table.remove
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
local spGetLuaMemUsage = Spring.GetLuaMemUsage
local spDiffTimers = Spring.DiffTimers
local spGetTimer = Spring.GetTimer
local glText = gl.Text
local glColor = gl.Color
local glBeginText = gl.BeginText
local glEndText = gl.EndText
local glGetViewSizes = gl.GetViewSizes
local glRect = gl.Rect
local glGetTextWidth = gl.GetTextWidth

local usePrefixedNames = true

local tick = 0.1
local retainSortTime = 100

local minPerc = 0.005 -- above this value, we fade in how red we mark a widget
local maxPerc = 0.02 -- above this value, we mark a widget as red
local minSpace = 10 -- Kb
local maxSpace = 100

local title_colour = "\255\160\255\160"
local totals_colour = "\255\200\200\255"

local prefixColor = {
	gui = '\255\100\222\100',
	gfx = '\255\222\160\100',
	game = '\255\166\166\255',
	cmd = '\255\166\255\255',
	unit = '\255\255\166\255',
	map = '\255\255\255\080',
	dbg = '\255\120\120\120',
}

local s
local callinStats = {}
local highres

local timeLoadAverages = {}
local spaceLoadAverages = {}
local startTimer

local userWidgets = {}
local oldUpdateWidgetCallIn
local oldInsertWidget

local listOfHooks = {}
setmetatable(listOfHooks, { __mode = 'k' })
local inHook = false

local lm, _, gm, _, um, _, sm, _ = spGetLuaMemUsage()

local allOverTime = 0
local allOverTimeSec = 0 -- currently unused
local allOverSpace = 0
local avgTLoad = {}

local sortedList = {}

local deltaTime
local redStrength = {}

local ColorString = Spring.Utilities.Color.ToString

if Spring.GetTimerMicros and  Spring.GetConfigInt("UseHighResTimer", 0) == 1 then
	spGetTimer = Spring.GetTimerMicros
	highres = true
end

spEcho("Profiler using highres timers", highres, Spring.GetConfigInt("UseHighResTimer", 0))

local prefixedWnames = {}
local widgetNameColors = {}  -- Store RGB values for background tinting
local function ConstructPrefixedName (ghInfo)
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
	widgetNameColors[gadgetName] = {r / 255, g / 255, b / 255}  -- Store normalized RGB
	prefixedWnames[gadgetName] = prefix .. stringChar(255, r, g, b) .. gadgetName .. "   "
	return prefixedWnames[gadgetName]
end

local function ArrayInsert(t, f, g)
	if f then
		local layer = g.whInfo.layer
		local index = 1
		local tLen = #t
		for i = 1, tLen do
			local v = t[i]
			if v == g then
				return -- already in the table
			end
			if layer >= v.whInfo.layer then
				index = i + 1
			end
		end
		tableInsert(t, index, g)
	end
end

local function ArrayRemove(t, g)
	local tLen = #t
	for k = 1, tLen do
		if t[k] == g then
			tableRemove(t, k)
			return -- Only one instance to remove
		end
	end
end

function widget:TextCommand(s)
	local token = {}
	local n = 0
	for w in stringGmatch(s, "%S+") do
		n = n + 1
		token[n] = w
	end
	if token[1] == "widgetprofilertickrate" then
		if token[2] then
			tick = tonumber(token[2]) or tick
		end
		spEcho("Setting widget profiler to tick=", tick)
	end

end

function widget:Initialize()
	for name, wData in pairs(widgetHandler.knownWidgets) do
		userWidgets[name] = (not wData.fromZip)
	end
end

local function IsHook(func)
	return listOfHooks[func]
end

-- Cache CallInsList to avoid rebuilding it multiple times
local cachedCallInsList
local function BuildCallInsList(wh)
	local CallInsList = {}
	local CallInsListCount = 0
	for name, e in pairs(wh) do
		local i = stringFind(name, "List", nil, true)
		if i and type(e) == "table" then
			CallInsListCount = CallInsListCount + 1
			CallInsList[CallInsListCount] = stringSub(name, 1, i - 1)
		end
	end
	return CallInsList
end

local wname2name = {}
local function Hook(w, name)
	-- name is the callin
	local widgetName = w.whInfo.name

	local wname = prefixedWnames[widgetName] or ConstructPrefixedName(w.whInfo)
	wname2name[wname] = widgetName

	local realFunc = w[name]
	w["_old" .. name] = realFunc

	if widgetName == "Widget Profiler" then
		return realFunc -- don't profile the profilers callins (it works, but it is better that our DrawScreen call is unoptimized and expensive anyway!)
	end

	local widgetCallinTime = callinStats[wname] or {}
	callinStats[wname] = widgetCallinTime
	widgetCallinTime[name] = widgetCallinTime[name] or { 0, 0, 0, 0 }
	local c = widgetCallinTime[name]

	local t

	local helper_func = function(...)
		local dt = spDiffTimers(spGetTimer(), t, nil ,highres)
		local _, _, new_s, _ = spGetLuaMemUsage()
		local ds = new_s - s
		c[1] = c[1] + dt
		c[2] = c[2] + dt
		c[3] = c[3] + ds
		c[4] = c[4] + ds
		inHook = nil
		return ...
	end

	local hook_func = function(...)
		if inHook then
			return realFunc(...)
		end

		inHook = true
		t = spGetTimer()
		local _, _, new_s, _ = spGetLuaMemUsage()
		s = new_s
		return helper_func(realFunc(...))
	end

	listOfHooks[hook_func] = true
	return hook_func
end

local function StartHook()
	spEcho("start profiling")

	local wh = widgetHandler

	-- Build and cache CallInsList
	if not cachedCallInsList then
		cachedCallInsList = BuildCallInsList(wh)
	end
	local CallInsList = cachedCallInsList

	--// hook all existing callins
	for i = 1, #CallInsList do
		local callin = CallInsList[i]
		local callinGadgets = wh[callin .. "List"]
		if callinGadgets then
			for j = 1, #callinGadgets do
				local w = callinGadgets[j]
				w[callin] = Hook(w, callin)
			end
		end
	end

	spEcho("hooked all callins")

	--// hook the UpdateCallin function
	oldUpdateWidgetCallIn = wh.UpdateWidgetCallInRaw
	wh.UpdateWidgetCallInRaw = function(self, name, w)
		local listName = name .. 'List'
		local ciList = self[listName]
		if ciList then
			local func = w[name]
			if type(func) == 'function' then
				if not IsHook(func) then
					w[name] = Hook(w, name)
				end
				ArrayInsert(ciList, func, w)
			else
				ArrayRemove(ciList, w)
			end
			self:UpdateCallIn(name)
		else
			print('UpdateWidgetCallIn: bad name: ' .. name)
		end
	end

	spEcho("hooked UpdateCallin")

	--// hook the InsertWidget function
	oldInsertWidget = wh.InsertWidgetRaw
	widgetHandler.InsertWidgetRaw = function(self, widget)
		if widget == nil then
			return
		end

		oldInsertWidget(self, widget)

		for i = 1, #CallInsList do
			local callin = CallInsList[i]
			local func = widget[callin]
			if type(func) == 'function' then
				widget[callin] = Hook(widget, callin)
			end
		end
	end

	spEcho("hooked InsertWidget")
end

local function StopHook()
	spEcho("stop profiling")

	local wh = widgetHandler

	-- Use cached CallInsList
	local CallInsList = cachedCallInsList or BuildCallInsList(wh)

	--// unhook all existing callins
	for i = 1, #CallInsList do
		local callin = CallInsList[i]
		local callinWidgets = wh[callin .. "List"]
		if callinWidgets then
			for j = 1, #callinWidgets do
				local w = callinWidgets[j]
				if w["_old" .. callin] then
					w[callin] = w["_old" .. callin]
				end
			end
		end
	end

	spEcho("unhooked all callins")

	--// unhook the UpdateCallin and InsertWidget functions
	wh.UpdateWidgetCallInRaw = oldUpdateWidgetCallIn
	spEcho("unhooked UpdateCallin")
	wh.InsertWidgetRaw = oldInsertWidget
	spEcho("unhooked InsertWidget")
end

function widget:Update()
	widgetHandler:RemoveWidgetCallIn("Update", self)
	StartHook()
	startTimer = spGetTimer()
end

function widget:Shutdown()
	StopHook()
end

local function CalcLoad(old_load, new_load, t)
	if t and t > 0 then
		local exptick = mathExp(-tick / t)
		return old_load * exptick + new_load * (1 - exptick)
	else
		return new_load
	end
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
	local u = mathExp(-deltaTime / 5) --magic colour changing rate
	local oneMinusU = 1 - u

	-- Clamp tTime
	if tTime > maxPerc then
		tTime = maxPerc
	elseif tTime < minPerc then
		tTime = minPerc
	end

	-- time
	local new_r = (tTime - minPerc) / percRange
	local timeKey = name .. '_time'
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
	local spaceKey = name .. '_space'
	redStrength[spaceKey] = redStrength[spaceKey] or 0
	redStrength[spaceKey] = u * redStrength[spaceKey] + oneMinusU * new_r
	local spaceColorFactor = 1 - redStrength[spaceKey] * colorScaleFactor
	v.spaceColourString = ColorString(1, spaceColorFactor, spaceColorFactor)
end

-- Helper function to render percentage with dimmed leading zeros
local function DrawPercentWithDimmedZeros(colorString, value, x, y, fontSize, decimalPlaces)
	local formatStr = '%.' .. (decimalPlaces or 3) .. 'f%%'
	local formatted = stringFormat(formatStr, value)
	local leadingPart, significantPart = stringMatch(formatted, '^(0%.0*)(.+)$')

	if leadingPart then
		-- Has leading zeros - render them dimmed
		glText(colorString .. '\255\140\140\140' .. leadingPart, x, y, fontSize, "no")
		local leadingWidth = glGetTextWidth(leadingPart) * fontSize
		glText(colorString .. significantPart, x + leadingWidth, y, fontSize, "no")
	else
		-- No leading zeros - render normally
		glText(colorString .. formatted, x, y, fontSize, "no")
	end
end

-- Helper function to render memory allocation with dimmed leading zeros
local function DrawMemoryWithDimmedZeros(colorString, value, x, y, fontSize, decimalPlaces, suffix)
	local formatStr = '%.' .. (decimalPlaces or 1) .. 'f'
	local formatted = stringFormat(formatStr, value)

	-- Check if value is 0.0 (all zeros)
	if tonumber(formatted) == 0 then
		-- Render entire "0.0" dimmed
		glText(colorString .. '\255\150\150\150' .. formatted .. suffix, x, y, fontSize, "no")
	else
		local leadingPart, significantPart = stringMatch(formatted, '^(0%.0*)(.+)$')
		if leadingPart then
			-- Has leading zeros - render them dimmed
			glText(colorString .. '\255\150\150\150' .. leadingPart, x, y, fontSize, "no")
			local leadingWidth = glGetTextWidth(leadingPart) * fontSize
			glText(colorString .. significantPart .. suffix, x + leadingWidth, y, fontSize, "no")
		else
			-- No leading zeros - render normally
			glText(colorString .. formatted .. suffix, x, y, fontSize, "no")
		end
	end
end

function DrawWidgetList(list, name, x, y, j, fontSize, lineSpace, maxLines, colWidth, dataColWidth)
	if j >= maxLines - 5 then
		x = x - colWidth;
		j = 0;
	end
	j = j + 1
	glText(title_colour .. name .. " WIDGETS", x + 152, y - lineSpace * j, fontSize, "no")
	j = j + 2

	local listLen = #list
	for i = 1, listLen do
		if j >= maxLines then
			x = x - colWidth;
			j = 0;
		end
		local v = list[i]

		-- Draw tinted background and colored square for widget line
		local color = widgetNameColors[v.name]
		if color then
			local textY = y - lineSpace * j

			-- Draw opaque colored square on the left
			glColor(color[1], color[2], color[3], 1.0)
			glRect(x - 12, textY - 3, x - 5, textY + fontSize - 3)

			-- Draw subtle tinted background across the whole line
			glColor(color[1], color[2], color[3], 0.25)
			glRect(x - 5, textY - 3, x + colWidth - 15, textY + fontSize - 3)

			glColor(1, 1, 1, 1)  -- Reset color
		end

		DrawPercentWithDimmedZeros(v.timeColourString, v.tLoad, x, y - lineSpace * j, fontSize)
		DrawMemoryWithDimmedZeros(v.spaceColourString, v.sLoad, x + dataColWidth, y - lineSpace * j, fontSize, 1, 'kB/s')
		glText(v.fullname, x + dataColWidth * 2, y - lineSpace * j, fontSize, "no")
		j = j + 1
	end

	DrawPercentWithDimmedZeros(totals_colour, list.allOverTime, x, y - lineSpace * j, fontSize, 2)
	DrawMemoryWithDimmedZeros(totals_colour, list.allOverSpace, x + dataColWidth, y - lineSpace * j, fontSize, 0, 'kB/s')
	glText(totals_colour .. "totals (" .. stringLower(name) .. ")", x + dataColWidth * 2, y - lineSpace * j, fontSize, "no")
	j = j + 1

	return x, j
end

function widget:DrawScreen()
	if not next(callinStats) then
		return
	end

	local averageTime = Spring.GetConfigFloat("profiler_averagetime", 2)

	-- sort & count timing
	deltaTime = spDiffTimers(spGetTimer(), startTimer, nil, highres)
	if deltaTime >= tick then

		startTimer = spGetTimer()
		sortedList = {}

		allOverTime = 0
		allOverSpace = 0
		local n = 1
		local sortByLoad = Spring.GetConfigInt("profiler_sort_by_load", 1) == 1

		-- Cache FPS and frame calculation
		local frames = mathMin(1 / tick, Spring.GetFPS()) * retainSortTime
		local framesMinusOne = frames - 1

		for wname, callins in pairs(callinStats) do
			local t = 0 -- would call it time, but protected
			local cmax_t = 0
			local cmaxname_t = "-"
			local space = 0
			local cmax_space = 0
			local cmaxname_space = "-"

			for cname, c in pairs(callins) do
				local c1, c2, c3, c4 = c[1], c[2], c[3], c[4]
				t = t + c1
				if c2 > cmax_t then
					cmax_t = c2
					cmaxname_t = cname
				end
				c[1] = 0

				space = space + c3
				if c4 > cmax_space then
					cmax_space = c4
					cmaxname_space = cname
				end
				c[3] = 0
			end

			local relTime = 100 * t / deltaTime
			timeLoadAverages[wname] = CalcLoad(timeLoadAverages[wname] or relTime, relTime, averageTime)

			local relSpace = space / deltaTime
			spaceLoadAverages[wname] = CalcLoad(spaceLoadAverages[wname] or relSpace, relSpace, averageTime)

			allOverTimeSec = allOverTimeSec + t

			local tLoad = timeLoadAverages[wname]
			if not avgTLoad[wname] then
				avgTLoad[wname] = tLoad * 0.7
			end
			avgTLoad[wname] = ((avgTLoad[wname] * framesMinusOne) + tLoad) / frames
			local sLoad = spaceLoadAverages[wname]
			if not sortByLoad or avgTLoad[wname] >= 0.05 or sLoad >= 5 then -- only show heavy ones
				sortedList[n] = { name = wname2name[wname], plainname = wname, fullname = wname .. ' \255\166\166\166(' .. cmaxname_t .. ',' .. cmaxname_space .. ')', tLoad = tLoad, sLoad = sLoad, tTime = t / deltaTime, avgTLoad = avgTLoad[wname] }
				n = n + 1
			end
			allOverTime = allOverTime + tLoad
			allOverSpace = allOverSpace + sLoad
		end
		if sortByLoad then
			tableSort(sortedList, function(a, b) return a.avgTLoad > b.avgTLoad end)
		else
			tableSort(sortedList, function(a, b) return a.name < b.name end)
		end

		local sortedLen = #sortedList
		for i = 1, sortedLen do
			GetRedColourStrings(sortedList[i])
		end
		lm, _, gm, _, um, _, sm, _ = spGetLuaMemUsage()
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

	local x, y = vsx - colWidth, vsy * 0.77 -- initial coord for writing
	local maxLines = mathMax(20, mathFloor(y / lineSpace) - 3)
	local j = -1 --line number

	glColor(1, 1, 1, 1)
	glBeginText()

	x, j = DrawWidgetList(gameList, "GAME", x, y, j, fontSize, lineSpace, maxLines, colWidth, dataColWidth)
	x, j = DrawWidgetList(userList, "USER", x, y, j, fontSize, lineSpace, maxLines, colWidth, dataColWidth)

	if j >= maxLines - 15 then
		x = x - colWidth;
		j = -1;
	end
	j = j + 1
	glText(title_colour .. "ALL", x + dataColWidth * 2, y - lineSpace * j, fontSize, "no")
	j = j + 1

	j = j + 1
	glText(totals_colour .. "total percentage of running time spent in luaui callins", x + dataColWidth * 2, y - lineSpace * j, fontSize, "no")
	glText(totals_colour .. stringFormat('%.1f%%', allOverTime), x + dataColWidth, y - lineSpace * j, fontSize, "no")
	j = j + 1
	glText(totals_colour .. "total rate of mem allocation by luaui callins", x + dataColWidth * 2, y - lineSpace * j, fontSize, "no")
	glText(totals_colour .. stringFormat('%.0f', allOverSpace) .. 'kB/s', x + dataColWidth, y - lineSpace * j, fontSize, "no")

	-- Cache memory calculations
	local gmMB = gm / 1000
	local lmPercent = 100 * lm / gm
	local umPercent = 100 * um / gm
	local smPercent = 100 * sm / gm

	j = j + 2
	glText(totals_colour .. 'total lua memory usage is ' .. stringFormat('%.0f', gmMB) .. 'MB, of which:', x, y - lineSpace * j, fontSize, "no")
	j = j + 1
	glText(totals_colour .. '  ' .. stringFormat('%.0f', lmPercent) .. '% is from luaui', x, y - lineSpace * j, fontSize, "no")
	j = j + 1
	glText(totals_colour .. '  ' .. stringFormat('%.0f', umPercent) .. '% is from unsynced states (luarules+luagaia+luaui)', x, y - lineSpace * j, fontSize, "no")
	j = j + 1
	glText(totals_colour .. '  ' .. stringFormat('%.0f', smPercent) .. '% is from synced states (luarules+luagaia)', x, y - lineSpace * j, fontSize, "no")

	j = j + 2
	glText(title_colour .. "All data excludes load from garbage collection & executing GL calls", x, y - lineSpace * j, fontSize, "no")
	j = j + 1
	glText(title_colour .. "Callins in brackets are heaviest per widget for (time,allocs)", x, y - lineSpace * j, fontSize, "no")

	j = j + 2
	glText(title_colour .. "Tick time: " .. tick .. "s", x, y - lineSpace * j, fontSize, "no")
	j = j + 1
	glText(title_colour .. "Smoothing time: " .. averageTime .. "s", x, y - lineSpace * j, fontSize, "no")

	glEndText()
end
