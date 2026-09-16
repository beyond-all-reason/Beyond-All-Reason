-- Per-widget CPU and memory measurement, shared by everything that wants to read it.
--
-- There is no engine call for what one widget costs, so the only way to find out is to wrap
-- every callin of every widget and time what happens inside. That wrapping is global and it
-- does not nest: two independent hookers would each end up timing the other's wrapper, and
-- both sets of numbers would be wrong. So it lives here, once, behind a count of who wants
-- it - the first subscriber puts the hooks in and the last one takes them out again.
--
-- VFS.Include runs the file afresh for each includer, which would hand every widget its own
-- copy of that count. The instance is therefore parked on WG, and every later include of
-- this file gets the one already running.
--
-- Ported out of dbg_widget_profiler, which measured all of this itself before the widget
-- selector wanted the same numbers.

if WG.widgetProfiling then
	return WG.widgetProfiling
end

local spGetTimer = Spring.GetTimer
local spDiffTimers = Spring.DiffTimers
local spGetLuaMemUsage = Spring.GetLuaMemUsage
local spGetFPS = Spring.GetFPS
local spGetConfigFloat = Spring.GetConfigFloat
local mathExp = math.exp
local mathMin = math.min
local stringFind = string.find
local stringSub = string.sub
local type = type
local pairs = pairs

local highres
if Spring.GetTimerMicros and Spring.GetConfigInt("UseHighResTimer", 0) == 1 then
	spGetTimer = Spring.GetTimerMicros
	highres = true
end

local M = {}

-- How often the raw counters are turned into averages.
--
-- The wrappers run whatever this is - they are the callins themselves - but the sweep that
-- turns their counters into averages walks every widget and all of its callins, and that
-- only happens on a tick. So this is worth asking for no faster than the reader needs:
-- subscribers say what they want and the fastest of them wins, since a slower reader is
-- satisfied by numbers arriving sooner than it asked.
local DEFAULT_TICK = 0.1
local tick = DEFAULT_TICK
-- Set by hand through the profiler's action, which is an explicit instruction and beats
-- what the subscribers asked for.
local tickOverride
-- The window the ordering average is taken over, in seconds. Much longer than the smoothing
-- above on purpose: a list that reorders itself every time a widget has a busy frame cannot
-- be read at all.
local retainSortTime = 100

-- [owner] = how often that owner wants the numbers, in seconds.
local subscribers = {}
local subscriberCount = 0
local hooked = false

-- [name][callin] = { time since last sample, time since forever, space since last, space }
local callinStats = {}
local wrapped = {}
setmetatable(wrapped, { __mode = "k" })
local inHook = false
local s = 0
local startTimer
local deltaTime

-- What each widget costs, as everything reading this sees it. Entries are updated in place
-- rather than rebuilt, since the sweep runs several times a second for the whole widget list.
--
--   load  smoothed share of wall clock, in percent
--   space smoothed allocation rate, in kB/s
--   avg   load again over a much longer window, for anything that orders by cost
--   peakTime, peakSpace  the callin that accounted for most of each
M.stats = {}
M.total = { load = 0, space = 0 }
M.mem = { lua = 0, global = 0, unsynced = 0, shared = 0 }
M.deltaTime = 0
-- Counts up once per sample. Anything that builds something out of these numbers can
-- hold it until this moves, rather than rebuilding on every frame for figures that only
-- change ten times a second.
M.gen = 0

-- Per-callin detail, which only the widget being drilled into pays for.
local callinAverages = {}
local detailName

local oldUpdateWidgetCallIn
local oldInsertWidget
local callInsList

local function calcLoad(old, new, t)
	if t and t > 0 then
		local exptick = mathExp(-tick / t)

		return old * exptick + new * (1 - exptick)
	end

	return new
end

local function buildCallInsList(wh)
	local list, n = {}, 0
	for name, e in pairs(wh) do
		local i = stringFind(name, "List", nil, true)
		if i and type(e) == "table" then
			n = n + 1
			list[n] = stringSub(name, 1, i - 1)
		end
	end

	return list
end

-- Keeps the handler's own ordering when a callin list is rebuilt: widgets sit in layer
-- order, and re-inserting one anywhere else would change the order call-ins run in.
local function arrayInsert(t, f, g)
	if f then
		local layer = g.whInfo.layer
		local index = 1
		for i = 1, #t do
			local v = t[i]
			if v == g then
				return
			end
			if layer >= v.whInfo.layer then
				index = i + 1
			end
		end
		table.insert(t, index, g)
	end
end

local function arrayRemove(t, g)
	for k = 1, #t do
		if t[k] == g then
			table.remove(t, k)

			return
		end
	end
end

-- Wraps one callin of one widget. The timer is taken before the real function and read
-- after it, and the allocation counter with it; `inHook` keeps a callin that calls another
-- widget's callin from being counted twice.
local function hook(w, name)
	local widgetName = w.whInfo.name
	local realFunc = w[name]
	w["_old" .. name] = realFunc

	-- Measuring the measurer only makes the measurement worse.
	if widgetName == "Widget Profiler" then
		return realFunc
	end

	local stats = callinStats[widgetName]
	if not stats then
		stats = {}
		callinStats[widgetName] = stats
	end
	stats[name] = stats[name] or { 0, 0, 0, 0 }
	local c = stats[name]

	local t

	local helperFunc = function(...)
		local dt = spDiffTimers(spGetTimer(), t, nil, highres)
		local _, _, newS, _ = spGetLuaMemUsage()
		local ds = newS - s
		c[1] = c[1] + dt
		c[2] = c[2] + dt
		c[3] = c[3] + ds
		c[4] = c[4] + ds
		inHook = false

		return ...
	end

	local hookFunc = function(...)
		if inHook then
			return realFunc(...)
		end

		inHook = true
		t = spGetTimer()
		local _, _, newS, _ = spGetLuaMemUsage()
		s = newS

		return helperFunc(realFunc(...))
	end

	wrapped[hookFunc] = true

	return hookFunc
end

local function startHook()
	local wh = widgetHandler
	callInsList = callInsList or buildCallInsList(wh)

	for i = 1, #callInsList do
		local callin = callInsList[i]
		local list = wh[callin .. "List"]
		if list then
			for j = 1, #list do
				list[j][callin] = hook(list[j], callin)
			end
		end
	end

	-- A widget that gains or loses a callin later, and one that loads later, both have to
	-- be wrapped too, or they measure as free.
	oldUpdateWidgetCallIn = wh.UpdateWidgetCallInRaw
	wh.UpdateWidgetCallInRaw = function(self, name, w)
		local ciList = self[name .. "List"]
		if ciList then
			local func = w[name]
			if type(func) == "function" then
				if not wrapped[func] then
					w[name] = hook(w, name)
				end
				arrayInsert(ciList, func, w)
			else
				arrayRemove(ciList, w)
			end
			self:UpdateCallIn(name)
		else
			Spring.Echo("UpdateWidgetCallIn: bad name: " .. name)
		end
	end

	oldInsertWidget = wh.InsertWidgetRaw
	wh.InsertWidgetRaw = function(self, w)
		if w == nil then
			return
		end
		oldInsertWidget(self, w)
		for i = 1, #callInsList do
			local callin = callInsList[i]
			if type(w[callin]) == "function" then
				w[callin] = hook(w, callin)
			end
		end
	end

	startTimer = spGetTimer()
	hooked = true
end

local function stopHook()
	local wh = widgetHandler
	local list = callInsList or buildCallInsList(wh)

	-- Every widget the handler holds, not only the ones still in a callin list: a widget
	-- that dropped a callin after it was wrapped is no longer in that list, and leaving it
	-- wrapped would have it measuring into a table nobody reads for the rest of the
	-- session. That costs nothing while profiling runs once; this goes on and off as often
	-- as a panel is opened.
	for i = 1, #wh.widgets do
		local w = wh.widgets[i]
		for j = 1, #list do
			local callin = list[j]
			local old = w["_old" .. callin]
			if old then
				w[callin] = old
				w["_old" .. callin] = nil
			end
		end
	end

	if oldUpdateWidgetCallIn then
		wh.UpdateWidgetCallInRaw = oldUpdateWidgetCallIn
		oldUpdateWidgetCallIn = nil
	end
	if oldInsertWidget then
		wh.InsertWidgetRaw = oldInsertWidget
		oldInsertWidget = nil
	end

	hooked = false
	callinStats = {}
	callinAverages = {}
	for name in pairs(M.stats) do
		M.stats[name] = nil
	end
	M.total.load, M.total.space = 0, 0
end

----------------------------------------------------------------
-- API
----------------------------------------------------------------

-- How often everyone wanting the numbers needs them, which is as often as the most
-- impatient of them asked.
local function retick()
	if tickOverride then
		tick = tickOverride

		return
	end
	local want
	for _, interval in pairs(subscribers) do
		if not want or interval < want then
			want = interval
		end
	end
	tick = want or DEFAULT_TICK
end

-- `owner` is any unique key; the widget table itself does. Subscribing twice from the same
-- owner counts once, so a panel can ask on every toggle without keeping track. `interval`
-- is how often that owner wants the numbers refreshed - a reader that updates a column a
-- player is glancing at does not need them as often as one drawing a live graph.
function M.subscribe(owner, interval)
	if subscribers[owner] then
		return
	end
	subscribers[owner] = tonumber(interval) or DEFAULT_TICK
	subscriberCount = subscriberCount + 1
	retick()
	if subscriberCount == 1 then
		startHook()
	end
end

function M.unsubscribe(owner)
	if not subscribers[owner] then
		return
	end
	subscribers[owner] = nil
	subscriberCount = subscriberCount - 1
	retick()
	if subscriberCount == 0 then
		stopHook()
	end
end

function M.subscribed()
	return subscriberCount
end

-- Whether this particular owner is one of them, which is how a panel restoring a saved
-- setting can tell whether it has acted on it yet.
function M.subscribes(owner)
	return subscribers[owner] ~= nil
end

function M.isHooked()
	return hooked
end

-- Sets the rate by hand, whatever the subscribers asked for; nil gives it back to them.
function M.setTick(seconds)
	tickOverride = tonumber(seconds)
	retick()

	return tick
end

function M.getTick()
	return tick
end

-- Which widget's per-callin breakdown to keep. Only one at a time: the smoothing behind it
-- costs a table per callin, and nothing reads more than one at once.
function M.setDetail(name)
	if detailName ~= name then
		detailName = name
		callinAverages = {}
	end
end

function M.callins(name)
	return callinAverages[name]
end

-- Turns the raw counters into averages, at most once per tick however often it is called -
-- several panels can ask on the same frame and only the first does the work. Answers true
-- when new numbers landed.
function M.sample()
	if not hooked or not startTimer then
		return false
	end

	deltaTime = spDiffTimers(spGetTimer(), startTimer, nil, highres)
	if deltaTime < tick then
		return false
	end
	startTimer = spGetTimer()
	M.deltaTime = deltaTime

	local averageTime = spGetConfigFloat("profiler_averagetime", 2)
	-- The long-window average is in frames, and a frame is however long the tick or the
	-- frame rate makes it.
	local frames = mathMin(1 / tick, spGetFPS()) * retainSortTime
	local framesMinusOne = frames - 1

	local totalLoad, totalSpace = 0, 0

	for name, callins in pairs(callinStats) do
		local t, space = 0, 0
		local peakT, peakTName = 0, "-"
		local peakS, peakSName = 0, "-"

		local detail
		if name == detailName then
			detail = callinAverages[name]
			if not detail then
				detail = {}
				callinAverages[name] = detail
			end
		end

		for cname, c in pairs(callins) do
			local c1, c2, c3, c4 = c[1], c[2], c[3], c[4]
			t = t + c1
			if c2 > peakT then
				peakT, peakTName = c2, cname
			end
			c[1] = 0

			space = space + c3
			if c4 > peakS then
				peakS, peakSName = c4, cname
			end
			c[3] = 0

			if detail then
				local relT = 100 * c1 / deltaTime
				local relS = c3 / deltaTime
				local prev = detail[cname]
				if prev then
					prev[1] = calcLoad(prev[1], relT, averageTime)
					prev[2] = calcLoad(prev[2], relS, averageTime)
				else
					detail[cname] = { relT, relS }
				end
			end
		end

		local entry = M.stats[name]
		if not entry then
			entry = { load = 100 * t / deltaTime, space = space / deltaTime }
			entry.avg = entry.load * 0.7
			M.stats[name] = entry
		end

		entry.load = calcLoad(entry.load, 100 * t / deltaTime, averageTime)
		entry.space = calcLoad(entry.space, space / deltaTime, averageTime)
		entry.avg = ((entry.avg * framesMinusOne) + entry.load) / frames
		entry.share = t / deltaTime
		entry.peakTime = peakTName
		entry.peakSpace = peakSName

		totalLoad = totalLoad + entry.load
		totalSpace = totalSpace + entry.space
	end

	M.total.load, M.total.space = totalLoad, totalSpace
	M.gen = M.gen + 1

	local lm, _, gm, _, um, _, sm, _ = spGetLuaMemUsage()
	M.mem.lua, M.mem.global, M.mem.unsynced, M.mem.shared = lm, gm, um, sm

	return true
end

WG.widgetProfiling = M

return M
