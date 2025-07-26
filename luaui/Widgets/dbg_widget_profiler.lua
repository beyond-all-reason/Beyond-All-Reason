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

local usePrefixedNames = true

local tick = 0.1
local averageTime = 0.5
local retainSortTime = 10

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
	map = '\255\122\122\122',
	dbg = '\255\088\088\088',
}

local spGetLuaMemUsage = Spring.GetLuaMemUsage
local spDiffTimers = Spring.DiffTimers
local spGetTimer = Spring.GetTimer
local glText = gl.Text
local exp = math.exp

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
local function SortFunc(a, b)
	return a.avgTLoad > b.avgTLoad
	--return a.plainname < b.plainname
end

local deltaTime
local redStrength = {}

local ColorString = Spring.Utilities.Color.ToString

if Spring.GetTimerMicros and  Spring.GetConfigInt("UseHighResTimer", 0) == 1 then
	spGetTimer = Spring.GetTimerMicros
	highres = true
end

Spring.Echo("Profiler using highres timers", highres, Spring.GetConfigInt("UseHighResTimer", 0))

local prefixedWnames = {}
local function ConstructPrefixedName (ghInfo)
	local gadgetName = ghInfo.name
	local baseName = ghInfo.basename
	local _pos = baseName:find("_", 1, true)
	local prefix = ((_pos and usePrefixedNames) and ((prefixColor[baseName:sub(1, _pos - 1)] and prefixColor[baseName:sub(1, _pos - 1)] or "\255\166\166\166") .. baseName:sub(1, _pos - 1) .. "     ") or "")
	prefixedWnames[gadgetName] = prefix .. string.char(255, math.random(100, 255), math.random(100, 255), math.random(100, 255)) .. gadgetName .. "   "
	return prefixedWnames[gadgetName]
end

local function ArrayInsert(t, f, g)
	if f then
		local layer = g.whInfo.layer
		local index = 1
		for i, v in ipairs(t) do
			if v == g then
				return -- already in the table
			end
			if layer >= v.whInfo.layer then
				index = i + 1
			end
		end
		table.insert(t, index, g)
	end
end

local function ArrayRemove(t, g)
	for k, v in ipairs(t) do
		if v == g then
			table.remove(t, k)
			-- break
		end
	end
end

function widget:TextCommand(s)
	local token = {}
	local n = 0
	--for w in string.gmatch(s, "%a+") do
	for w in string.gmatch(s, "%S+") do
		n = n + 1
		token[n] = w
	end
	if token[1] == "widgetprofilertickrate" then
		if token[2] then
			tick = tonumber(token[2]) or tick
		end
		if token[3] then
			averageTime = tonumber(token[3]) or averageTime
		end
		Spring.Echo("Setting widget profiler to tick=", tick, "averageTime=", averageTime)
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

local function Hook(w, name)
	-- name is the callin
	local widgetName = w.whInfo.name

	local wname = prefixedWnames[widgetName] or ConstructPrefixedName(w.whInfo)

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
	Spring.Echo("start profiling")

	local wh = widgetHandler
	--wh.actionHandler:AddAction("widgetprofiler", widgetprofileraction, "Configure the tick rate of the widget profiler", 't')

	local CallInsList = {}
	local CallInsListCount = 0
	for name, e in pairs(wh) do
		local i = name:find("List", nil, true)
		if i and type(e) == "table" then
			CallInsListCount = CallInsListCount + 1
			CallInsList[CallInsListCount] = name:sub(1, i - 1)
		end
	end

	--// hook all existing callins
	for _, callin in ipairs(CallInsList) do
		local callinGadgets = wh[callin .. "List"]
		for _, w in ipairs(callinGadgets or {}) do
			w[callin] = Hook(w, callin)
		end
	end

	Spring.Echo("hooked all callins")

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

	Spring.Echo("hooked UpdateCallin")

	--// hook the InsertWidget function
	oldInsertWidget = wh.InsertWidgetRaw
	widgetHandler.InsertWidgetRaw = function(self, widget)
		if widget == nil then
			return
		end

		oldInsertWidget(self, widget)

		for _, callin in ipairs(CallInsList) do
			local func = widget[callin]
			if type(func) == 'function' then
				widget[callin] = Hook(widget, callin)
			end
		end
	end

	Spring.Echo("hooked InsertWidget")
end

local function StopHook()
	Spring.Echo("stop profiling")

	local wh = widgetHandler
	--widgetHandler.RemoveAction("widgetprofiler")
	local CallInsList = {}
	local CallInsListCount = 0
	for name, e in pairs(wh) do
		local i = name:find("List", nil, true)
		if i and type(e) == "table" then
			CallInsListCount = CallInsListCount + 1
			CallInsList[CallInsListCount] = name:sub(1, i - 1)
		end
	end

	--// unhook all existing callins
	for _, callin in ipairs(CallInsList) do
		local callinWidgets = wh[callin .. "List"]
		for _, w in ipairs(callinWidgets or {}) do
			if w["_old" .. callin] then
				w[callin] = w["_old" .. callin]
			end
		end
	end

	Spring.Echo("unhooked all callins")

	--// unhook the UpdateCallin and InsertWidget functions
	wh.UpdateWidgetCallInRaw = oldUpdateWidgetCallIn
	Spring.Echo("unhooked UpdateCallin")
	wh.InsertWidgetRaw = oldInsertWidget
	Spring.Echo("unhooked InsertWidget")
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
		local exptick = exp(-tick / t)
		return old_load * exptick + new_load * (1 - exptick)
	else
		return new_load
	end
end

function GetRedColourStrings(v)
	-- tLoad is %
	local tTime = v.tTime
	local sLoad = v.sLoad
	local name = v.plainname
	local u = math.exp(-deltaTime / 5) --magic colour changing rate

	if tTime > maxPerc then
		tTime = maxPerc
	end
	if tTime < minPerc then
		tTime = minPerc
	end

	-- time
	local new_r = (tTime - minPerc) / (maxPerc - minPerc)
	redStrength[name .. '_time'] = redStrength[name .. '_time'] or 0
	redStrength[name .. '_time'] = u * redStrength[name .. '_time'] + (1 - u) * new_r
	local r, g, b = 1, 1 - redStrength[name .. "_time"] * ((255 - 64) / 255), 1 - redStrength[name .. "_time"] * ((255 - 64) / 255)
	v.timeColourString = ColorString(r, g, b)

	-- space
	new_r = (sLoad - minSpace) / (maxSpace - minSpace)
	if new_r > 1 then
		new_r = 1
	elseif new_r < 0 then
		new_r = 0
	end
	redStrength[name .. '_space'] = redStrength[name .. '_space'] or 0
	redStrength[name .. '_space'] = u * redStrength[name .. '_space'] + (1 - u) * new_r
	g = 1 - redStrength[name .. "_space"] * ((255 - 64) / 255)
	b = g
	v.spaceColourString = ColorString(r, g, b)
end

function DrawWidgetList(list, name, x, y, j, fontSize, lineSpace, maxLines, colWidth, dataColWidth)
	if j >= maxLines - 5 then
		x = x - colWidth;
		j = 0;
	end
	j = j + 1
	glText(title_colour .. name .. " WIDGETS", x + 152, y - lineSpace * j, fontSize, "no")
	j = j + 2

	for i = 1, #list do
		if j >= maxLines then
			x = x - colWidth;
			j = 0;
		end
		local v = list[i]
		glText(v.timeColourString .. ('%.3f%%'):format(v.tLoad), x, y - lineSpace * j, fontSize, "no")
		glText(v.spaceColourString .. ('%.1f'):format(v.sLoad) .. 'kB/s', x + dataColWidth, y - lineSpace * j, fontSize, "no")
		glText(v.fullname, x + dataColWidth * 2, y - lineSpace * j, fontSize, "no")
		j = j + 1
	end

	glText(totals_colour .. ('%.2f%%'):format(list.allOverTime), x, y - lineSpace * j, fontSize, "no")
	glText(totals_colour .. ('%.0f'):format(list.allOverSpace) .. 'kB/s', x + dataColWidth, y - lineSpace * j, fontSize, "no")
	glText(totals_colour .. "totals (" .. string.lower(name) .. ")", x + dataColWidth * 2, y - lineSpace * j, fontSize, "no")
	j = j + 1

	return x, j
end

function widget:DrawScreen()
	if not next(callinStats) then
		return
	end

	-- sort & count timing
	deltaTime = Spring.DiffTimers(spGetTimer(), startTimer, nil, highres)
	if deltaTime >= tick then
		startTimer = spGetTimer()
		sortedList = {}

		allOverTime = 0
		allOverSpace = 0
		local n = 1
		local sortByLoad = Spring.GetConfigInt("profiler_sort_by_load", 1) == 1
		for wname, callins in pairs(callinStats) do
			local t = 0 -- would call it time, but protected
			local cmax_t = 0
			local cmaxname_t = "-"
			local space = 0
			local cmax_space = 0
			local cmaxname_space = "-"
			for cname, c in pairs(callins) do
				t = t + c[1]
				if c[2] > cmax_t then
					cmax_t = c[2]
					cmaxname_t = cname
				end
				c[1] = 0

				space = space + c[3]
				if c[4] > cmax_space then
					cmax_space = c[4]
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
			local frames = math.min(1 / tick, Spring.GetFPS()) * retainSortTime
			avgTLoad[wname] = ((avgTLoad[wname]*(frames-1)) + tLoad) / frames
			local sLoad = spaceLoadAverages[wname]
			if not sortByLoad or avgTLoad[wname] >= 0.05 or sLoad >= 5 then -- only show heavy ones
				sortedList[n] = { plainname = wname, fullname = wname .. ' \255\166\166\166(' .. cmaxname_t .. ',' .. cmaxname_space .. ')', tLoad = tLoad, sLoad = sLoad, tTime = t / deltaTime, avgTLoad = avgTLoad[wname] }
				n = n + 1
			end
			allOverTime = allOverTime + tLoad
			allOverSpace = allOverSpace + sLoad
		end
		if sortByLoad then
			table.sort(sortedList, SortFunc)
		else
			table.sort(sortedList, function(a, b) return a.plainname < b.plainname end)
		end

		for i = 1, #sortedList do
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
	for i = 1, #sortedList do
		if userWidgets[sortedList[i].plainname] then
			userListCount = userListCount + 1
			userList[userListCount] = sortedList[i]
			userList.allOverTime = userList.allOverTime + sortedList[i].tLoad
			userList.allOverSpace = userList.allOverSpace + sortedList[i].sLoad
		else
			gameListCount = gameListCount + 1
			gameList[gameListCount] = sortedList[i]
			gameList.allOverTime = gameList.allOverTime + sortedList[i].tLoad
			gameList.allOverSpace = gameList.allOverSpace + sortedList[i].sLoad
		end
	end

	-- draw
	local vsx, vsy = gl.GetViewSizes()

	local fontSize = math.max(11, math.floor(vsy / 90))
	local lineSpace = fontSize + 2

	local dataColWidth = fontSize * 5
	local colWidth = vsx * 0.98 / 4

	local x, y = vsx - colWidth, vsy * 0.77 -- initial coord for writing
	local maxLines = math.max(20, math.floor(y / lineSpace) - 3)
	local j = -1 --line number

	gl.Color(1, 1, 1, 1)
	gl.BeginText()

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
	glText(totals_colour .. ('%.1f%%'):format(allOverTime), x + dataColWidth, y - lineSpace * j, fontSize, "no")
	j = j + 1
	glText(totals_colour .. "total rate of mem allocation by luaui callins", x + dataColWidth * 2, y - lineSpace * j, fontSize, "no")
	glText(totals_colour .. ('%.0f'):format(allOverSpace) .. 'kB/s', x + dataColWidth, y - lineSpace * j, fontSize, "no")

	j = j + 2
	glText(totals_colour .. 'total lua memory usage is ' .. ('%.0f'):format(gm / 1000) .. 'MB, of which:', x, y - lineSpace * j, fontSize, "no")
	j = j + 1
	glText(totals_colour .. '  ' .. ('%.0f'):format(100 * lm / gm) .. '% is from luaui', x, y - lineSpace * j, fontSize, "no")
	j = j + 1
	glText(totals_colour .. '  ' .. ('%.0f'):format(100 * um / gm) .. '% is from unsynced states (luarules+luagaia+luaui)', x, y - lineSpace * j, fontSize, "no")
	j = j + 1
	glText(totals_colour .. '  ' .. ('%.0f'):format(100 * sm / gm) .. '% is from synced states (luarules+luagaia)', x, y - lineSpace * j, fontSize, "no")

	j = j + 2
	glText(title_colour .. "All data excludes load from garbage collection & executing GL calls", x, y - lineSpace * j, fontSize, "no")
	j = j + 1
	glText(title_colour .. "Callins in brackets are heaviest per widget for (time,allocs)", x, y - lineSpace * j, fontSize, "no")

	j = j + 2
	glText(title_colour .. "Tick time: " .. tick .. "s", x, y - lineSpace * j, fontSize, "no")
	j = j + 1
	glText(title_colour .. "Smoothing time: " .. averageTime .. "s", x, y - lineSpace * j, fontSize, "no")

	gl.EndText()
end
