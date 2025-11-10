local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Gadget Profiler",
		desc = "",
		author = "jK, Bluestone",
		date = "2007+",
		license = "GNU GPL, v2 or later",
		layer = 1000000,
		handler = true,
		enabled = true,
	}
end

-- use 'luarules profile' to switch on the profiler
-- future use of 'luarules profile' acts as a toggle to show/hide the on-screen profiling data (without touching the hooks)
-- use 'luarules kill_profiler' to switch off the profiler for *everyone* currently using it (and remove the hooks)

-- the DrawScreen call of this profiler has a performance impact, but note that this profiler does not profile its own time/allocation loads

-- if switched on during a multi-player game, and included within the game archive, the profiler will (also) have a very small performance impact on *all* players (-> synced callin hooks run in synced code!)
-- nobody will notice, but don't profile if you don't need too

--------------------------------------------------------------------------------
-- Localizations
--------------------------------------------------------------------------------

-- Localize frequently used functions
local tableInsert = table.insert
local tableRemove = table.remove
local tableSort = table.sort
local mathFloor = math.floor
local mathMax = math.max
local mathMin = math.min
local mathExp = math.exp
local mathRandom = math.random
local stringChar = string.char
local stringSub = string.sub
local stringFind = string.find
local stringLower = string.lower
local stringFormat = string.format
local pairs = pairs
local ipairs = ipairs
local next = next
local select = select

--------------------------------------------------------------------------------
-- Prefixed Gadget Names
--------------------------------------------------------------------------------

local usePrefixedNames = true

local prefixColor = {
	gui = '\255\100\222\100',
	gfx = '\255\222\160\100',
	game = '\255\166\166\255',
	cmd = '\255\166\255\255',
	unit = '\255\255\166\255',
	map = '\255\255\255\080',
	dbg = '\255\120\120\120',
}
local prefixedGnames = {}
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
	-- Cache random color generation
	local r, g, b = mathRandom(100, 255), mathRandom(100, 255), mathRandom(100, 255)
	prefixedGnames[gadgetName] = prefix .. stringChar(255, r, g, b) .. gadgetName .. "   "
	return prefixedGnames[gadgetName]
end

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

local callinStats = {}
local callinStatsSYNCED = {}

local highres = false
local tick = 0.2
local retainSortTime = 10

local spGetTimer = Spring.GetTimer

local spDiffTimers = Spring.DiffTimers
local spGetLuaMemUsage = Spring.GetLuaMemUsage or function() return 0, 0, 0, 0, 0, 0, 0, 0 end

--------------------------------------------------------------------------------
-- Default Value Helpers
--------------------------------------------------------------------------------

local function ValueForKey_SetDefaultInOriginalTable(table, key, defaultValue)
	local value = table[key] or defaultValue
	table[key] = value
	return value
end

--------------------------------------------------------------------------------
-- Array Operations (Used only in StartHook)
--------------------------------------------------------------------------------

local function ArrayInsert(t, gadget)
	local layer = gadget.ghInfo.layer
	local index = 1
	local tLen = #t
	for i = 1, tLen do
		local v = t[i]
		if v == gadget then
			return -- already in the table
		end
		if layer >= v.ghInfo.layer then
			index = i + 1
		end
	end
	tableInsert(t, index, gadget)
end

local function ArrayRemove(t, gadget)
	local tLen = #t
	for k = 1, tLen do
		if t[k] == gadget then
			tableRemove(t, k)
			return -- Only one instance to remove
		end
	end
end

--------------------------------------------------------------------------------
-- Hooks
--------------------------------------------------------------------------------

local oldUpdateGadgetCallIn

local inHook = false
local listOfHooks = {}
setmetatable(listOfHooks, { __mode = 'k' })

local function IsHook(func)
	return listOfHooks[func]
end

local hookPreRealFunction
local hookPostRealFunction

if gadgetHandler:IsSyncedCode() then
	hookPreRealFunction = function(gadgetName, callinName)
		SendToUnsynced("prf_started_from_synced", gadgetName, callinName)
	end
	hookPostRealFunction = function(gadgetName, callinName)
		SendToUnsynced("prf_finished_from_synced", gadgetName, callinName)
	end
else
	local t, s

	if Spring.GetTimerMicros and  Spring.GetConfigInt("UseHighResTimer", 0) == 1 then
		spGetTimer = Spring.GetTimerMicros
		highres = true
	end
	if not highres then
		Spring.Echo("Profiler not using highres timers", highres, Spring.GetConfigInt("UseHighResTimer", 0))
	end

	hookPreRealFunction = function(gadgetName, callinName)
		t = spGetTimer()
		_, _, s, _ = spGetLuaMemUsage()
	end

	hookPostRealFunction = function(gadgetName, callinName)
		local dt = spDiffTimers(spGetTimer(), t, nil, highres)

		local _, _, new_s, _ = spGetLuaMemUsage()
		local ds = new_s - s

		local gadgetCallinStats = ValueForKey_SetDefaultInOriginalTable(callinStats, gadgetName, {})
		local stats = ValueForKey_SetDefaultInOriginalTable(gadgetCallinStats, callinName, { 0, 0, 0, 0})

		stats[1] = stats[1] + dt
		stats[2] = stats[2] + dt
		stats[3] = stats[3] + ds
		stats[4] = stats[4] + ds
	end
end


local gname2name = {}
Hook = function(gadget, callinName)
	local gadgetName = gadget.ghInfo.name
	local realFunc = gadget[callinName]

	if gadgetName == "Gadget Profiler" then
		return realFunc -- don't profile the profilers callins within synced (nothing to profile!)
	end

	gadget['_old' .. callinName] = realFunc

	local gname = prefixedGnames[gadgetName] or ConstructPrefixedName(gadget.ghInfo)
	gname2name[gname] = gadgetName

	local hook_func = function(...)
		if inHook then
			return realFunc(...)
		end

		inHook = true
		hookPreRealFunction(gname, callinName)

		-- Use this to prevent allocating nearly empty tables every single time, instead of return unpack({realFunc(...)})
		local r1, r2, r3, r4, r5, r6, r7, r8 = realFunc(...)

		hookPostRealFunction(gname, callinName)
		inHook = false

		return r1, r2, r3, r4, r5, r6, r7, r8
	end

	listOfHooks[hook_func] = true -- !!!note: using functions as keys is unsafe in synced code!!!

	return hook_func
end

local hookset = false

local dummyTable = {} -- Avoid re-creating an empty table that will never be given elements

-- Cache the CallInsList to avoid rebuilding it every time
local cachedCallInsList
local function BuildCallInsList()
	local CallInsList = {}
	local CallInsListCount = 0

	for key, value in pairs(gadgetHandler) do
		local i = stringFind(key, "List", nil, true)
		if i and type(value) == "table" then
			CallInsListCount = CallInsListCount + 1
			CallInsList[CallInsListCount] = stringSub(key, 1, i - 1)
		end
	end
	
	return CallInsList
end

local function ForAllGadgetCallins(action)
	if not cachedCallInsList then
		cachedCallInsList = BuildCallInsList()
	end

	for i = 1, #cachedCallInsList do
		local callin = cachedCallInsList[i]
		local callinGadgets = gadgetHandler[callin .. "List"]
		for j = 1, #(callinGadgets or dummyTable) do
			action(callinGadgets[j], callin)
		end
	end
end

-- Helper for StartHook
local function AddHook(gadget, callin)
	gadget[callin] = Hook(gadget, callin)
end

local function StartHook(optName, line, words, playerID) -- this one is synced?

	if hookset then
		if not running then
			KillHook()
		end
		return false
	end

	hookset = true
	Spring.Echo("start profiling (" .. (SendToUnsynced ~= nil and "synced" or "unsynced") .. ")")

	--// hook all existing callins
	ForAllGadgetCallins(AddHook)

	Spring.Echo("hooked all callins")

	--// hook the UpdateCallin function
	oldUpdateGadgetCallIn = gadgetHandler.UpdateGadgetCallIn
	gadgetHandler.UpdateGadgetCallIn = function(self, name, g)
		local listName = name .. 'List'
		local ciList = self[listName]
		if ciList then
			local func = g[name]
			if type(func) == 'function' then
				if not IsHook(func) then
					g[name] = Hook(g, name)
				end
				ArrayInsert(ciList, g)
			else
				ArrayRemove(ciList, g)
			end
			self:UpdateCallIn(name)
		else
			print('UpdateGadgetCallIn: bad name: ' .. name)
		end
	end

	Spring.Echo("hooked UpdateCallin")

	return false -- allow the unsynced chataction to execute too
end

-- Helper for Kill Hook
local function RemoveHook(gadget, callin)
	if gadget["_old" .. callin] then
		gadget[callin] = gadget["_old" .. callin]
	end
end

function KillHook()
	if not hookset then
		return true
	end

	Spring.Echo("stop profiling (" .. (SendToUnsynced ~= nil and "synced" or "unsynced") .. ")")

	ForAllGadgetCallins(RemoveHook)

	Spring.Echo("unhooked all callins")

	--// unhook the UpdateCallin function
	gadgetHandler.UpdateGadgetCallIn = oldUpdateGadgetCallIn

	Spring.Echo("unhooked UpdateCallin")

	hookset = false
	return false -- allow the unsynced chataction to execute too
end

--------------------------------------------------------------------------------
-- Other
--------------------------------------------------------------------------------
if gadgetHandler:IsSyncedCode() then
	--------------------------------------------------------------------------------
	-- Synced Setup
	--------------------------------------------------------------------------------

	function gadget:Initialize()
		gadgetHandler.actionHandler.AddChatAction(gadget, 'profile', StartHook, " : starts the gadget profiler") -- first hook the synced callins, then synced will come back and tell us to (really) start
		gadgetHandler.actionHandler.AddChatAction(gadget, 'kill_profiler', KillHook, " : kills the gadget profiler") -- removes the profiler for everyone currently running it
	end
else
	--------------------------------------------------------------------------------
	-- Unsynced Setup
	--------------------------------------------------------------------------------

	local running = false

	local timersSynced = {}
	local startTickTimer
	local memUsageSynced = {}

	local function SetDrawCallin(drawCallin)
		-- when the profiler isn't running, the profiler gadget should have *no* draw callin
		gadget.DrawScreen = drawCallin
		gadgetHandler:UpdateGadgetCallIn("DrawScreen", gadget)
	end

	local function SyncedCallinStarted(_, gname, cname)
		hookPreRealFunction(gname, cname)
	end

	local function SyncedCallinFinished(_, gname, cname)
		local callinStatsUnsynced = callinStats
		callinStats = callinStatsSYNCED

		hookPostRealFunction(gname, cname)

		callinStats = callinStatsUnsynced
	end

	local function Start(optName, line, words, pID, _)
		if running then
			Kill(nil, nil, nil, pID, nil)
		elseif pID == Spring.GetMyPlayerID() then
			running = true

			tick = (words and words[1] and tonumber(words[1])) or tick

			if highres and true then -- this tests the timers for correctness
				local starttime = Spring.GetTimer()
				local starttimeus = Spring.GetTimerMicros()
				local j = 0
				for i = 1, 1000000 do
					j = j + 1
				end

				local endtime = Spring.GetTimer()
				local endtimeus = Spring.GetTimerMicros()

				Spring.Echo("GetTimer secs", Spring.DiffTimers( endtime,starttime, nil))
				Spring.Echo("GetTimer msecs", Spring.DiffTimers( endtime, starttime,true))
				Spring.Echo("GetTimerMicros secs", Spring.DiffTimers( endtimeus,starttimeus, nil, true))
				Spring.Echo("GetTimerMicros msecs", Spring.DiffTimers( endtimeus, starttimeus,true, true))
			end



			StartHook() -- the unsynced one!
			startTickTimer = spGetTimer()

			SetDrawCallin(gadget.DrawScreen_)

			Spring.Echo("luarules profiler started (player " .. pID .. ")")
		end
	end

	function Kill(_, _, _, pID, _)
		if running then
			running = false

			Spring.Echo("Killing...")
			SetDrawCallin(nil)
			KillHook()

			startTickTimer = nil
			timersSynced = {}
			memUsageSynced = {}

			Spring.Echo("luarules profiler killed (player " .. pID .. ")")
		end
	end

	function gadget:Initialize()
		gadgetHandler.actionHandler.AddChatAction(gadget, "profile", Start)
		gadgetHandler.actionHandler.AddChatAction(gadget, "kill_profiler", Kill)

		gadgetHandler.actionHandler.AddSyncAction(gadget, "prf_started_from_synced", SyncedCallinStarted) -- internal, not meant to be called by user
		gadgetHandler.actionHandler.AddSyncAction(gadget, "prf_finished_from_synced", SyncedCallinFinished) -- internal, not meant to be called by user
	end

	--------------------------------------------------------------------------------
	-- Data
	--------------------------------------------------------------------------------



	local timeLoadAverages = {}
	local spaceLoadAverages = {}
	local redStrength = {}
	local timeLoadAveragesSYNCED = {}
	local spaceLoadAveragesSYNCED = {}
	local redStrengthSYNCED = {}

	local luarulesMemory, _, globalMemory, _, unsyncedMemory, _, syncedMemory, _ = spGetLuaMemUsage()

	local exp = math.exp

	local function CalcLoad(old_load, new_load, t)
		if t and t > 0 then
			local exptick = exp(-tick / t)
			return old_load * exptick + new_load * (1 - exptick)
		else
			return new_load
		end
	end

	local totalLoads = {}
	local allOverTimeSec = 0 -- currently unused

	--------------------------------------------------------------------------------
	-- Presentation
	--------------------------------------------------------------------------------

	local avgTLoad = {}

	local sortedList = {}
	local sortedListSYNCED = {}
	local function SortFunc(a, b)
		return a.avgTLoad > b.avgTLoad
		--return a.plainname < b.plainname
	end

	local minPerc = 0.0005 -- above this value, we fade in how red we mark a widget (/gadget)
	local maxPerc = 0.002 -- above this value, we mark a widget as red
	local minSpace = 10 -- Kb
	local maxSpace = 100

	local title_colour = "\255\160\255\160"
	local totals_colour = "\255\200\200\255"

	-- Cache color char conversion
	local colorCharCache = {}
	local function ColorChar(color)
		local key = mathFloor(color * 255)
		if not colorCharCache[key] then
			colorCharCache[key] = stringChar(key)
		end
		return colorCharCache[key]
	end

	local function ColourString(R, G, B)
		return "\255" .. ColorChar(R) .. ColorChar(G) .. ColorChar(B)
	end

	-- Precompute constants
	local colorScaleFactor = (255 - 64) / 255
	local percRange = maxPerc - minPerc
	local spaceRange = maxSpace - minSpace

	function GetRedColourStrings(tTime, sLoad, name, redStr, deltaTime)
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
		redStr[timeKey] = redStr[timeKey] or 0
		redStr[timeKey] = u * redStr[timeKey] + oneMinusU * new_r
		local timeRedStrength = redStr[timeKey]
		local colorFactor = 1 - timeRedStrength * colorScaleFactor
		local r, g, b = 1, colorFactor, colorFactor
		local timeColourString = ColourString(r, g, b)

		-- space
		new_r = (sLoad - minSpace) / spaceRange
		if new_r > 1 then
			new_r = 1
		elseif new_r < 0 then
			new_r = 0
		end

		local spaceKey = name .. '_space'
		redStr[spaceKey] = redStr[spaceKey] or 0
		redStr[spaceKey] = u * redStr[spaceKey] + oneMinusU * new_r
		local spaceColorFactor = 1 - redStr[spaceKey] * colorScaleFactor
		local spaceColourString = ColourString(r, spaceColorFactor, spaceColorFactor)
		return timeColourString, spaceColourString
	end

	local function ProcessCallinStats(stats, timeLoadAvgs, spaceloadAvgs, redStr, deltaTime)
		totalLoads = {}
		local allOverTime = 0
		local allOverSpace = 0
		local n = 1

		local sorted = {}

		local averageTime = Spring.GetConfigFloat("profiler_averagetime", 2)
		local sortByLoad = Spring.GetConfigInt("profiler_sort_by_load", 1) == 1

		-- Cache FPS and frame calculation
		local frames = mathMin(1 / tick, Spring.GetFPS()) * retainSortTime
		local framesMinusOne = frames - 1

		for gname, callins in pairs(stats) do
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
			timeLoadAvgs[gname] = CalcLoad(timeLoadAvgs[gname] or relTime, relTime, averageTime)

			local relSpace = space / deltaTime
			spaceloadAvgs[gname] = CalcLoad(spaceloadAvgs[gname] or relSpace, relSpace, averageTime)

			allOverTimeSec = allOverTimeSec + t

			local tLoad = timeLoadAvgs[gname]
			local sLoad = spaceloadAvgs[gname]
			local tTime = t / deltaTime

			if not avgTLoad[gname] then
				avgTLoad[gname] = tLoad * 0.7
			end
			avgTLoad[gname] = ((avgTLoad[gname] * framesMinusOne) + tLoad) / frames
			local tColourString, sColourString = GetRedColourStrings(tTime, sLoad, gname, redStr, deltaTime)
			if not sortByLoad or avgTLoad[gname] >= 0.02 or sLoad >= 2 then -- only show heavy ones
				sorted[n] = { name = gname2name[gname] or gname, plainname = gname, fullname = gname .. ' \255\200\200\200(' .. cmaxname_t .. ',' .. cmaxname_space .. ')', tLoad = tLoad, sLoad = sLoad, tTime = tTime, tColourString = tColourString, sColourString = sColourString, avgTLoad = avgTLoad[gname] }
				n = n + 1
			end
			allOverTime = allOverTime + tLoad
			allOverSpace = allOverSpace + sLoad
		end
		if sortByLoad then
			tableSort(sorted, SortFunc)
		else
			tableSort(sorted, function(a, b) return a.name < b.name end)
		end

		sorted.allOverTime = allOverTime
		sorted.allOverSpace = allOverSpace

		return sorted
	end

	--------------------------------------------------------------------------------
	-- Layout
	--------------------------------------------------------------------------------

	-- Layout constants. Defaults are provided here, and updated by gadget:ViewResize() directly after it is defined.
	-- These initial values should never be used to perform an actual layout, and are just provided as examples.
	local viewWidth, viewHeight = gl.GetViewSizes()
	local fontSize = 11
	local lineSpace = 13

	local dataColWidth = 15
	local nameColWidth = 55
	local colWidth = 200
	local maxLines = 20

	-- initial coord for writing
	local initialY
	local initialX

	function gadget:ViewResize(vsx, vsy)
		viewWidth, viewHeight = gl.GetViewSizes()

		fontSize = mathMax(11, mathFloor(11 * viewWidth / 1920))
		lineSpace = fontSize + 2

		dataColWidth = fontSize * 5
		nameColWidth = fontSize * 15

		colWidth = dataColWidth * 3 + nameColWidth * 2

		initialX = viewWidth - colWidth
		initialY = viewHeight * 0.77

		maxLines = mathMax(20, mathFloor(initialY / lineSpace) - 3)
	end
	gadget:ViewResize(viewWidth, viewHeight)

	--------------------------------------------------------------------------------
	-- Drawing helpers
	--------------------------------------------------------------------------------

	-- Initialised to 0 at the start of gadget:DrawScreen_
	local currentLineIndex
	-- Initialised to 0 at the start of gadget:DrawScreen_
	local currentColumnIndex

	local function RequireSpace(requiredLines)
		if currentLineIndex + requiredLines > maxLines then
			currentColumnIndex = currentColumnIndex + 1
			currentLineIndex = 0
		end
	end

	local function Text(color, string, dataColIndex)
		gl.Text(
			color .. string,
			initialX + dataColWidth * dataColIndex - currentColumnIndex * colWidth,
			initialY - lineSpace * currentLineIndex,
			fontSize,
			"no"
		)
	end

	-- Spacing above indicates the number of blank lines left. spacingAbove = 0 will still result in a line break.
	local function Line(spacingAbove, color, col1String, col2String, col3String, color2, color3)
		local advance = 1 + spacingAbove
		RequireSpace(advance)
		currentLineIndex = currentLineIndex + advance
		if col1String then
			Text(color, col1String, 0)
		end
		if col2String then
			Text(color2 or color, col2String, 1)
		end
		if col3String then
			Text(color3 or color, col3String, 2)
		end
	end

	local function NewSection(title)
		RequireSpace(15)
		if currentLineIndex ~= 0 then currentLineIndex = currentLineIndex + 3 end
		Text(title_colour, title, 2)
		currentLineIndex = currentLineIndex + 1
	end

	-- Cache format strings
	local noDataColor = "\255\200\200\200"
	local maxnameColor = "\255\200\200\200"

	local function DrawSortedList(list, name)
		NewSection(name)

		local listLen = #list
		if listLen == 0 then
			Line(0, noDataColor, nil, nil, "No data!")
			return
		end

		for i = 1, listLen do
			local v = list[i]
			local gname = v.fullname
			local tLoad = v.tLoad
			local sLoad = v.sLoad
			local tColour = v.tColourString
			local sColour = v.sColourString

			Line(0, tColour, stringFormat('%.3f%%', tLoad), stringFormat('%.02f', sLoad) .. 'kB/s', gname, sColour)
		end

		Line(0, totals_colour,
			stringFormat('%.3f%%', list.allOverTime),
			stringFormat('%.0f', list.allOverSpace) .. 'kB/s',
			"totals (" .. stringLower(name) .. ")"
		)
	end

	--------------------------------------------------------------------------------
	-- Drawing
	--------------------------------------------------------------------------------

	function gadget:DrawScreen_()
		if not running then
			return
		end

		if not next(callinStats) and not next(callinStatsSYNCED) then
			Spring.Echo("no data in profiler!")
			return
		end

		local deltaTime = spDiffTimers(spGetTimer(), startTickTimer, nil, highres)

		if deltaTime >= tick then
			startTickTimer = spGetTimer()

			sortedList = ProcessCallinStats(callinStats, timeLoadAverages, spaceLoadAverages, redStrength, deltaTime)
			sortedListSYNCED = ProcessCallinStats(callinStatsSYNCED, timeLoadAveragesSYNCED, spaceLoadAveragesSYNCED, redStrengthSYNCED, deltaTime)

			luarulesMemory, _, globalMemory, _, unsyncedMemory, _, syncedMemory, _ = spGetLuaMemUsage()
		end

		currentLineIndex = 0
		currentColumnIndex = 0

		gl.Color(1, 1, 1, 1)
		gl.BeginText()

		DrawSortedList(sortedList, "UNSYNCED")
		DrawSortedList(sortedListSYNCED, "SYNCED")

		NewSection("ALL")

		-- Cache combined totals
		local totalTime = (sortedList.allOverTime or 0) + (sortedListSYNCED.allOverTime or 0)
		local totalSpace = (sortedList.allOverSpace or 0) + (sortedListSYNCED.allOverSpace or 0)

		Line(0, totals_colour,
			nil,
			stringFormat('%.1f%%', totalTime),
			"total percentage of running time spent in luarules callins"
		)

		Line(0, totals_colour,
			nil,
			stringFormat('%.0f', totalSpace) .. 'kB/s',
			"total rate of mem allocation by luarules callins"
		)

		-- Cache memory calculations
		local globalMemMB = globalMemory / 1000
		local luarulesPercent = 100 * luarulesMemory / globalMemory
		local unsyncedPercent = 100 * unsyncedMemory / globalMemory
		local syncedPercent = 100 * syncedMemory / globalMemory

		Line(1, title_colour, 'total lua memory usage is ' .. stringFormat('%.0f', globalMemMB) .. 'MB, of which:')

		Line(1, totals_colour, nil, stringFormat('%.0f', luarulesPercent) .. '% is from unsynced luarules')
		Line(0, totals_colour, nil, stringFormat('%.0f', unsyncedPercent) .. '% is from unsynced states (luarules+luagaia+luaui)')
		Line(0, totals_colour, nil, stringFormat('%.0f', syncedPercent) .. '% is from synced states (luarules+luagaia)')

		Line(1, title_colour, "All data excludes load from garbage collection & executing GL calls")
		Line(0, title_colour, "Callins in brackets are heaviest per gadget for (time,allocs)")

		Line(1, title_colour, "Tick time: " .. tick .. "s")
		Line(0, title_colour, "Smoothing time: " .. Spring.GetConfigFloat("profiler_averagetime", 2) .. "s")

		gl.EndText()
	end
end
