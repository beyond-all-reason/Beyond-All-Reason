local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "GPU Profiler",
		desc = "GPU time per gadget and draw callin, measured with GL timer queries; shown by the GPU Profiler widget",
		author = "Beherith, Claude",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = -999999,
		handler = true,
		enabled = true,
	}
end

-- The gadget side of the GPU Profiler widget (luaui/Widgets/dbg_gpu_profiler.lua): every draw callin of
-- every unsynced gadget is wrapped between two GL_TIMESTAMP queries, read three frames later without
-- waiting, and the smoothed per-gadget numbers are handed to the widget a few times a second, which
-- lists them next to the widgets. Dormant until started: the widget sends "luarules gpuprofile on"
-- when it is enabled and "off" when it goes; "/luarules gpuprofile" toggles it by hand.
-- Per-object callins (DrawProjectile) are not timed: only the first few calls of a frame would be.

if gadgetHandler:IsSyncedCode() then
	return false
end

---@diagnostic disable-next-line: undefined-global
local Script = Script

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
local spEcho = Spring.Echo
local osClock = os.clock
local pairs, ipairs, type = pairs, ipairs, type

local MAX_INVOCATIONS = 8 ---@type integer timed calls of one callin per frame
local NSETS = 4 -- query sets in flight; a set is read NSETS - 1 frames after it was written
local SMOOTHING = 0.05 -- per-sample exponential average factor
local SEND_INTERVAL = 0.25 -- seconds between hand-overs to LuaUI
local EXCLUDED = { DrawProjectile = true }

local active = false
local frame = 0
local parity = 1
local framesSampled, framesDropped = 0, 0
local lastSend = 0.0

---@class GpuProfilerGadgetSlot
---@field name string gadget name
---@field callin string
---@field q table<integer, table<integer, [integer, integer]|false>> per query set: query pairs, false where creation failed
---@field used integer[] per query set: pairs written this frame

-- [gadgetName][callin] = slot
local slots = {} ---@type table<string, table<string, GpuProfilerGadgetSlot>>
local slotList = {} ---@type GpuProfilerGadgetSlot[]
local hookedFuncs = setmetatable({}, { __mode = "k" })
local wrappedGadgets = setmetatable({}, { __mode = "k" }) -- [gadget] = { [callin] = original }

-- [gadgetName] = { ms = smoothed GPU ms per frame, cur = this frame's sum, peakCallin, peakMs }
local stats = {}
local callinMs, callinCur = {}, {}
local totalMs = 0.0

-- the handler methods replaced while running: [key] = original
local replaced = {}
local drawCallins

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

local function getSlot(gadgetName, callin)
	local byGadget = slots[gadgetName]
	if not byGadget then
		byGadget = {}
		slots[gadgetName] = byGadget
	end
	local slot = byGadget[callin]
	if not slot then
		---@type GpuProfilerGadgetSlot
		slot = { name = gadgetName, callin = callin, q = {}, used = {} }
		for i = 1, NSETS do
			slot.q[i] = {}
			slot.used[i] = 0
		end
		byGadget[callin] = slot
		slotList[#slotList + 1] = slot
		if not stats[gadgetName] then
			stats[gadgetName] = { ms = 0, cur = 0, peakCallin = "", peakMs = 0 }
		end
	end
	return slot
end

local function finish(pair, ...)
	glQueryCounter(pair[2])
	return ...
end

local function hook(g, callin)
	local realFunc = g[callin]
	if type(realFunc) ~= "function" or hookedFuncs[realFunc] or g == gadget then
		return realFunc
	end
	local slot = getSlot(g.ghInfo.name, callin)
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
	wrappedGadgets[g] = wrappedGadgets[g] or {}
	wrappedGadgets[g][callin] = realFunc
	return hookFunc
end

local function hookGadget(g)
	for i = 1, #drawCallins do
		local callin = drawCallins[i]
		if type(g[callin]) == "function" then
			g[callin] = hook(g, callin)
		end
	end
end

local function unhookAll()
	for g, originals in pairs(wrappedGadgets) do
		for callin, original in pairs(originals) do
			if hookedFuncs[g[callin]] then
				g[callin] = original
			end
		end
	end
	wrappedGadgets = setmetatable({}, { __mode = "k" })
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
end

-- Parallel arrays for LuaUI (cross-state calls copy their arguments; arrays copy cheapest)
local function send()
	if not Script.LuaUI("GpuProfilerGadgets") then
		return
	end
	local names, ms, peaks = {}, {}, {}
	local n = 0
	for name, stat in pairs(stats) do
		n = n + 1
		names[n], ms[n], peaks[n] = name, stat.ms, stat.peakCallin
	end
	local callinNames, callinValues = {}, {}
	local c = 0
	for callin, value in pairs(callinMs) do
		c = c + 1
		callinNames[c], callinValues[c] = callin, value
	end
	Script.LuaUI.GpuProfilerGadgets(names, ms, peaks, totalMs, framesDropped, framesSampled, callinNames, callinValues)
end

function gadget:DrawGenesis()
	if not active then
		return
	end
	frame = frame + 1
	parity = (frame % NSETS) + 1
	collect(((frame + 1) % NSETS) + 1)
	local now = osClock()
	if now - lastSend >= SEND_INTERVAL then
		lastSend = now
		send()
	end
end

local function start()
	if active then
		return
	end
	if not (glCreateQuery and glQueryCounter and glGetQueryDelta and GL_TIMESTAMP) then
		spEcho(
			"GPU Profiler (gadgets): this engine cannot time GPU work from Lua (needs gl.QueryCounter and gl.GetQueryDelta)"
		)
		return
	end
	local probe = glCreateQuery(GL_TIMESTAMP)
	if not probe then
		spEcho("GPU Profiler (gadgets): timer queries unavailable on this GPU")
		return
	end
	glDeleteQuery(probe)

	local gh = gadgetHandler ---@type table methods are replaced below
	drawCallins = {}
	for name, list in pairs(gh) do
		if type(list) == "table" and type(name) == "string" and name:sub(1, 4) == "Draw" and name:sub(-4) == "List" then
			local callin = name:sub(1, -5)
			if not EXCLUDED[callin] then
				drawCallins[#drawCallins + 1] = callin
			end
		end
	end
	table.sort(drawCallins)
	for i = 1, #gh.gadgets do
		hookGadget(gh.gadgets[i])
	end
	-- gadgets loaded later, and callins added later, get wrapped too. The queued API (InsertGadget,
	-- UpdateGadgetCallIn) dispatches to the Raw methods captured when the handler started, so both the
	-- queued entry points (wrapping at enqueue time) and the Raw methods (direct calls) are replaced.
	local function hookCallin(name, g)
		if
			g
			and type(g[name]) == "function"
			and not hookedFuncs[g[name]]
			and not EXCLUDED[name]
			and name:sub(1, 4) == "Draw"
		then
			g[name] = hook(g, name)
		end
	end
	for _, key in ipairs({ "InsertGadget", "InsertGadgetRaw" }) do
		local original = gh[key]
		replaced[key] = original
		gh[key] = function(self, g, ...)
			if g ~= nil then
				hookGadget(g)
			end
			return original(self, g, ...)
		end
	end
	for _, key in ipairs({ "UpdateGadgetCallIn", "UpdateGadgetCallInRaw" }) do
		local original = gh[key]
		replaced[key] = original
		gh[key] = function(self, name, g, ...)
			hookCallin(name, g)
			return original(self, name, g, ...)
		end
	end
	frame, framesSampled, framesDropped = 0, 0, 0
	active = true
	gadgetHandler:UpdateGadgetCallIn("DrawGenesis", gadget)
end

local function stop()
	if not active then
		return
	end
	active = false
	local gh = gadgetHandler ---@type table
	for key, original in pairs(replaced) do
		gh[key] = original
	end
	replaced = {}
	unhookAll()
	deleteQueries()
	slots, slotList, stats, callinMs, callinCur = {}, {}, {}, {}, {}
	totalMs = 0
	gadgetHandler:RemoveGadgetCallIn("DrawGenesis", gadget)
end

local function command(_, _, words)
	local arg = words and words[1]
	if arg == "on" then
		start()
	elseif arg == "off" then
		stop()
	elseif active then
		stop()
	else
		start()
	end
end

function gadget:Initialize()
	gadgetHandler.actionHandler.AddChatAction(
		gadget,
		"gpuprofile",
		command,
		" [on|off] : GPU time per gadget, shown by the GPU Profiler widget"
	)
	gadgetHandler:RemoveGadgetCallIn("DrawGenesis", gadget)
end

function gadget:Shutdown()
	stop()
	gadgetHandler.actionHandler.RemoveChatAction(gadget, "gpuprofile")
end
