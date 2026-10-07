local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "GPU Profiler",
		desc = "GPU time per widget, gadget and draw callin, measured with GL timer queries",
		author = "Beherith, Claude",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = -99901,
		handler = true,
		enabled = false,
	}
end

-- The widget profiler measures CPU time; this measures what the GPU spends executing the
-- draw calls each widget issues. Every draw callin of every widget is wrapped between two
-- GL_TIMESTAMP queries, and the difference is that callin's GPU time. The queries are read
-- three frames later without waiting, so the measurement never stalls the pipeline; a frame
-- whose results are still pending is skipped (counted in the pending percentage), not
-- averaged in as zero. Needs an engine with gl.QueryCounter and gl.GetQueryDelta
-- (ARB_timer_query); the delta is taken in C++ because the raw 64-bit timestamps do not fit
-- Lua's single precision numbers.
--
-- Gadgets are measured the same way by the gadget of the same name (luarules/gadgets/
-- dbg_gpu_profiler.lua), which this widget switches on while it runs; their rows are marked (g).
--
-- Read the numbers with this in mind: a timestamp difference is GPU wall time, so when the
-- GPU is starved by the CPU (CPU-bound frames) the gaps the GPU spends idle between a
-- widget's draw calls are counted too. Compare widgets in GPU-bound scenes, or compare the
-- same widget before and after a change in the same scene.

-- The Lua timer-query API (gl.CreateQuery targets, gl.QueryCounter, gl.GetQueryDelta) is newer than the
-- generated type stubs, so these locals carry its signatures.
---@type fun(target: integer): integer?
local glCreateQuery = gl.CreateQuery
local glDeleteQuery = gl.DeleteQuery
---@type fun(query: integer)
local glQueryCounter = gl.QueryCounter
---@type fun(queryBegin: integer, queryEnd: integer, wait: boolean): number?
local glGetQueryDelta = gl.GetQueryDelta
---@type integer
---@diagnostic disable-next-line: undefined-field
local GL_TIMESTAMP = GL.TIMESTAMP

local glColor = gl.Color
local glRect = gl.Rect
local glText = gl.Text
local glBeginText = gl.BeginText
local glEndText = gl.EndText
local glGetViewSizes = gl.GetViewSizes
local spEcho = Spring.Echo
local tableSort = table.sort
local mathMax = math.max
local mathFloor = math.floor
local stringFormat = string.format
local pairs, ipairs, type = pairs, ipairs, type

local MAX_INVOCATIONS = 8 ---@type integer timed calls of one callin per frame (DrawWorldPreParticles runs several times)
local NSETS = 4 -- query sets in flight; a set is read NSETS - 1 frames after it was written
local SMOOTHING = 0.05 -- per-sample exponential average factor
local MIN_SHOW_MS = 0.005

local active = false
local frame = 0
local parity = 1 -- the query set this frame writes into, 1 .. NSETS
local framesSampled, framesDropped = 0, 0

---@class GpuProfilerWidgetSlot
---@field name string widget name
---@field callin string
---@field q table<integer, table<integer, [integer, integer]|false>> per query set: query pairs, false where creation failed
---@field used integer[] per query set: pairs written this frame

-- [widgetName][callin] = slot
local slots = {} ---@type table<string, table<string, GpuProfilerWidgetSlot>>
local slotList = {} ---@type GpuProfilerWidgetSlot[]
local hookedFuncs = setmetatable({}, { __mode = "k" })
local wrappedWidgets = setmetatable({}, { __mode = "k" }) -- [widget] = { [callin] = original }

-- [widgetName] = { ms = smoothed GPU ms per frame, cur = this frame's sum, peakCallin, peakMs }
local stats = {}
local sortedList = {} ---@type { name: string, ms: number, peak: string, gadget: boolean? }[]
local totalMs = 0.0
local listDirty = true

-- [callin] = smoothed GPU ms per frame spent by all widgets in that callin
local callinMs = {}
local callinCur = {}

-- the gadget side's numbers, replaced on every hand-over: [gadgetName] = { ms, peakCallin }
local gadgetStats = {}
local gadgetCallinMs = {}
local gadgetTotalMs = 0
local gadgetDropped, gadgetSampled = 0, 0

-- the handler methods replaced while running
local oldInsertWidget ---@type function?
local oldUpdateWidgetCallIn ---@type function?
local oldQueuedUpdateWidgetCallIn ---@type function?
local drawCallins -- the handler's callins whose name starts with Draw

----------------------------------------------------------------
-- Query bookkeeping
----------------------------------------------------------------

local function getPair(slot, p, k)
	local set = slot.q[p]
	local pair = set[k]
	if pair == nil then
		local b = glCreateQuery(GL_TIMESTAMP)
		local e = glCreateQuery(GL_TIMESTAMP)
		if not (b and e) then
			if b then
				glDeleteQuery(b)
			end
			set[k] = false
			return nil
		end
		pair = { b, e }
		set[k] = pair
	end
	return pair or nil
end

local function getSlot(widgetName, callin)
	local byWidget = slots[widgetName]
	if not byWidget then
		byWidget = {}
		slots[widgetName] = byWidget
	end
	local slot = byWidget[callin]
	if not slot then
		---@type GpuProfilerWidgetSlot
		slot = { name = widgetName, callin = callin, q = {}, used = {} }
		for i = 1, NSETS do
			slot.q[i] = {}
			slot.used[i] = 0
		end
		byWidget[callin] = slot
		slotList[#slotList + 1] = slot
		if not stats[widgetName] then
			stats[widgetName] = { ms = 0, cur = 0, peakCallin = "", peakMs = 0 }
		end
	end
	return slot
end

local function finish(pair, ...)
	glQueryCounter(pair[2])
	return ...
end

local function hook(w, callin)
	local realFunc = w[callin]
	if type(realFunc) ~= "function" or hookedFuncs[realFunc] then
		return realFunc
	end
	local widgetName = w.whInfo.name
	if widgetName == "GPU Profiler" then
		return realFunc
	end

	local slot = getSlot(widgetName, callin)
	local hookFunc = function(...)
		if not active then
			return realFunc(...)
		end
		local k = slot.used[parity] + 1
		if k > MAX_INVOCATIONS then
			return realFunc(...)
		end
		local pair = getPair(slot, parity, k)
		if not pair then
			return realFunc(...)
		end
		slot.used[parity] = k
		glQueryCounter(pair[1])
		return finish(pair, realFunc(...))
	end
	hookedFuncs[hookFunc] = true

	wrappedWidgets[w] = wrappedWidgets[w] or {}
	wrappedWidgets[w][callin] = realFunc
	return hookFunc
end

local function hookWidget(w)
	for i = 1, #drawCallins do
		local callin = drawCallins[i]
		if type(w[callin]) == "function" then
			w[callin] = hook(w, callin)
		end
	end
end

local function unhookAll()
	for w, originals in pairs(wrappedWidgets) do
		for callin, original in pairs(originals) do
			if hookedFuncs[w[callin]] then
				w[callin] = original
			end
		end
	end
	wrappedWidgets = setmetatable({}, { __mode = "k" })
end

local function deleteQueries()
	for i = 1, #slotList do
		local slot = slotList[i]
		for p = 1, NSETS do
			for _, pair in pairs(slot.q[p]) do
				if pair then
					glDeleteQuery(pair[1])
					glDeleteQuery(pair[2])
				end
			end
			slot.q[p] = {}
			slot.used[p] = 0
		end
	end
end

----------------------------------------------------------------
-- Per frame
----------------------------------------------------------------

-- Reads the oldest set (written NSETS - 1 frames ago) and frees it for next frame's writes.
local function collect(readSet)
	for _, stat in pairs(stats) do
		stat.cur = 0
		stat.peakMs = 0
	end
	for callin in pairs(callinCur) do
		callinCur[callin] = 0
	end

	local complete = true
	for i = 1, #slotList do
		local slot = slotList[i]
		local used = slot.used[readSet]
		if used > 0 then
			local set = slot.q[readSet]
			local sum = 0.0
			for k = 1, used do
				local pair = set[k]
				local delta = pair and glGetQueryDelta(pair[1], pair[2], false)
				if delta then
					sum = sum + delta
				else
					complete = false
				end
			end
			slot.used[readSet] = 0
			local ms = sum * 1e-6
			local stat = stats[slot.name]
			stat.cur = stat.cur + ms
			callinCur[slot.callin] = (callinCur[slot.callin] or 0) + ms
			if ms > stat.peakMs then
				stat.peakMs = ms
				stat.peakCallin = slot.callin
			end
		end
	end

	framesSampled = framesSampled + 1
	if not complete then
		framesDropped = framesDropped + 1
		return
	end

	totalMs = 0
	for _, stat in pairs(stats) do
		stat.ms = stat.ms * (1 - SMOOTHING) + stat.cur * SMOOTHING
		totalMs = totalMs + stat.ms
	end
	for callin, cur in pairs(callinCur) do
		callinMs[callin] = (callinMs[callin] or 0) * (1 - SMOOTHING) + cur * SMOOTHING
	end
	listDirty = true
end

-- called from LuaRules (Script.LuaUI.GpuProfilerGadgets) a few times a second
local function receiveGadgetStats(names, ms, peaks, total, dropped, sampled, callinNames, callinValues)
	gadgetStats = {}
	for i = 1, #names do
		gadgetStats[names[i]] = { ms = ms[i] or 0, peakCallin = peaks[i] or "" }
	end
	gadgetCallinMs = {}
	for i = 1, #callinNames do
		gadgetCallinMs[callinNames[i]] = callinValues[i]
	end
	gadgetTotalMs = total or 0
	gadgetDropped, gadgetSampled = dropped or 0, sampled or 0
	listDirty = true
end

function widget:DrawGenesis()
	if not active then
		return
	end
	frame = frame + 1
	parity = (frame % NSETS) + 1
	collect(((frame + 1) % NSETS) + 1)
end

----------------------------------------------------------------
-- Display
----------------------------------------------------------------

local function rebuildList()
	sortedList = {}
	local n = 0
	for name, stat in pairs(stats) do
		if stat.ms >= MIN_SHOW_MS then
			n = n + 1
			sortedList[n] = { name = name, ms = stat.ms, peak = stat.peakCallin }
		end
	end
	for name, stat in pairs(gadgetStats) do
		if stat.ms >= MIN_SHOW_MS then
			n = n + 1
			sortedList[n] = { name = name, ms = stat.ms, peak = stat.peakCallin, gadget = true }
		end
	end
	tableSort(sortedList, function(a, b)
		return a.ms > b.ms
	end)
	listDirty = false
end

function widget:DrawScreen()
	if not active then
		return
	end
	if listDirty and (frame % 6 == 0) then
		rebuildList()
	end

	local vsx, vsy = glGetViewSizes()
	-- same scaling as the widget profiler, times the user's ui_scale setting
	local uiScale = Spring.GetConfigFloat("ui_scale", 1) or 1
	local fontSize = mathMax(11, mathFloor(vsy / 90)) * uiScale
	local lineSpace = fontSize * 1.18
	local width = fontSize * 38
	local x = vsx - width - fontSize * 2
	local y = vsy - fontSize * 16
	local rows = #sortedList

	glColor(0, 0, 0, 0.6)
	glRect(x - fontSize * 0.6, y + lineSpace * 1.5, x + width, y - lineSpace * (rows + 1))

	glColor(1, 1, 1, 1)
	local pending = (framesSampled > 0) and (100 * framesDropped / framesSampled) or 0
	glBeginText() -- one draw call for the whole panel; a draw per string cost 0.8 ms of CPU per frame
	glText(
		stringFormat(
			"\255\160\255\160GPU ms per frame   widgets %.2f   gadgets %.2f   (%.0f%% of frames pending)",
			totalMs,
			gadgetTotalMs,
			pending
		),
		x,
		y,
		fontSize,
		"o"
	)
	y = y - lineSpace
	for _, e in ipairs(sortedList) do
		glText(e.gadget and ("\255\255\200\140" .. e.name .. "  (g)") or e.name, x, y, fontSize, "o")
		glText(stringFormat("%.3f", e.ms), x + width - fontSize * 11.5, y, fontSize, "or")
		glText("\255\160\160\160" .. e.peak, x + width - fontSize * 10.8, y, fontSize * 0.85, "o")
		y = y - lineSpace
	end
	glEndText()
end

----------------------------------------------------------------
-- Lifetime
----------------------------------------------------------------

function widget:Initialize()
	if not (glCreateQuery and glQueryCounter and glGetQueryDelta and GL_TIMESTAMP) then
		spEcho(
			"GPU Profiler: this engine cannot time GPU work from Lua (needs gl.QueryCounter and gl.GetQueryDelta, Recoil with the Lua timer query API), widget disabled"
		)
		widgetHandler:RemoveWidget()
		return
	end
	local probe = glCreateQuery(GL_TIMESTAMP)
	if not probe then
		spEcho("GPU Profiler: timer queries unavailable on this GPU, exiting")
		widgetHandler:RemoveWidget()
		return
	end
	glDeleteQuery(probe)

	local wh = widgetHandler ---@type table methods are replaced below
	drawCallins = {}
	for name, list in pairs(wh) do
		if type(list) == "table" and type(name) == "string" and name:sub(1, 4) == "Draw" and name:sub(-4) == "List" then
			drawCallins[#drawCallins + 1] = name:sub(1, -5)
		end
	end
	tableSort(drawCallins)

	for i = 1, #wh.widgets do
		hookWidget(wh.widgets[i])
	end

	-- widgets loaded later, and callins added later, get wrapped too
	oldInsertWidget = wh.InsertWidgetRaw
	wh.InsertWidgetRaw = function(self, w)
		if w == nil then
			return
		end
		oldInsertWidget(self, w)
		hookWidget(w)
	end
	local function hookCallin(name, w)
		for i = 1, #drawCallins do
			if drawCallins[i] == name and type(w[name]) == "function" and not hookedFuncs[w[name]] then
				w[name] = hook(w, name)
			end
		end
	end
	oldUpdateWidgetCallIn = wh.UpdateWidgetCallInRaw
	wh.UpdateWidgetCallInRaw = function(self, name, w)
		hookCallin(name, w)
		return oldUpdateWidgetCallIn(self, name, w)
	end
	-- the queued UpdateWidgetCallIn runs the Raw method captured at handler start, so wrap it at enqueue time
	oldQueuedUpdateWidgetCallIn = wh.UpdateWidgetCallIn
	wh.UpdateWidgetCallIn = function(self, name, w, ...)
		if w then
			hookCallin(name, w)
		end
		return oldQueuedUpdateWidgetCallIn(self, name, w, ...)
	end

	active = true

	widgetHandler:RegisterGlobal(widget, "GpuProfilerGadgets", receiveGadgetStats)
	Spring.SendCommands("luarules gpuprofile on")

	-- for other tooling: stats[widgetName].ms is the smoothed GPU ms per frame
	WG.gpuProfiler = {
		stats = stats,
		getTotal = function()
			return totalMs
		end,
		-- the gadgets' numbers, as last handed over by the gadget side: [gadgetName] = { ms, peakCallin }
		getGadgetStats = function()
			return gadgetStats
		end,
		getGadgetTotal = function()
			return gadgetTotalMs
		end,
		getGadgetCallinMs = function()
			return gadgetCallinMs
		end,
		getGadgetDropped = function()
			return gadgetDropped, gadgetSampled
		end,
		getDropped = function()
			return framesDropped, framesSampled
		end,
		-- smoothed GPU ms per frame of all widgets per draw callin, for tools that time the engine passes between callins
		getCallinMs = function()
			return callinMs
		end,
	}
end

function widget:Shutdown()
	if active then
		Spring.SendCommands("luarules gpuprofile off")
		widgetHandler:DeregisterGlobal(widget, "GpuProfilerGadgets")
	end
	active = false
	WG.gpuProfiler = nil
	local wh = widgetHandler ---@type table
	if oldInsertWidget then
		wh.InsertWidgetRaw = oldInsertWidget
	end
	if oldUpdateWidgetCallIn then
		wh.UpdateWidgetCallInRaw = oldUpdateWidgetCallIn
	end
	if oldQueuedUpdateWidgetCallIn then
		wh.UpdateWidgetCallIn = oldQueuedUpdateWidgetCallIn
	end
	unhookAll()
	deleteQueries()
end
