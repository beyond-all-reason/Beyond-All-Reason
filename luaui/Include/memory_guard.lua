-- Keeps user widgets from running Lua out of memory, and names the one that would.
--
-- The engine's LuaAllocLimit is one pool for every Lua state: LuaUI, both halves of LuaRules and
-- the lobby. Once it is full the next allocation fails in whichever state makes it: in synced
-- LuaRules that quits the game, in LuaUI it takes down a widget or all of LuaUI. Neither names
-- the widget that filled it, so a player who installed it never learns why.
--
-- Only user widgets are measured. What each call-in allocates is exact and cheap, since the
-- engine stops the collector for every call-in; how much each one holds is estimated now and
-- then by walking what it reaches, a little per update. One call-in allocating too much is
-- stopped by a count hook, a widget holding too much is turned off, and when the pool runs
-- short the biggest user widget goes first. Game widgets are left alone.

local MemoryGuard = {}

local debugEcho = false

MemoryGuard.OUT_OF_MEMORY = "not enough memory" -- Lua's message for a failed allocation
MemoryGuard.TRIP_ERROR = "memory limit exceeded"

MemoryGuard.defaults = {
	poolLimitKB = 1536 * 1024, -- system.LuaAllocLimit in gamedata/modrules.lua
	-- Shares of the pool.
	poolCollect = 0.60, -- step a full collection of LuaUI
	poolWarn = 0.70, -- say which user widget holds the most
	poolAct = 0.80, -- turn user widgets off, biggest first
	poolEmergency = 0.90, -- collect at once, whatever it stalls
	luauiShare = 0.35, -- below this share of the pool, turning user widgets off cannot help
	walkMaxLoad = 0.75, -- what the walk keeps track of is garbage too
	callLimitKB = 256 * 1024, -- allocated by one call-in
	retainWarnKB = 100 * 1024,
	retainLimitKB = 400 * 1024,
	significantKB = 32 * 1024, -- held, for ranking by it rather than by what was allocated
	-- Objects one walk may keep track of, about 80 MB of its own on a 64-bit build. A widget made of
	-- more small objects than that is only known to hold at least what was seen.
	walkObjectCap = 1500000,
	growthKB = 16 * 1024, -- per walk, growthWalks walks in a row
	growthWalks = 3,
	rateWarnKB = 8 * 1024, -- per second, for rateSustain seconds in a row
	rateSustain = 10,
	rateSmoothing = 10, -- seconds, for the reported rate
	firstWalk = 20, -- seconds
	walkInterval = 60, -- or ten times as long as the last walk took, if longer
	walkBudget = 0.3, -- ms per update
	hookInterval = 25000, -- VM instructions between checks
	checkInterval = 15, -- updates between pool checks
	stepKB = 1024, -- collector work per update, about 1 ms
	pressureStepKB = 4096,
}

local floor, max, min = math.floor, math.max, math.min
local next, pairs, ipairs, type, rawget = next, pairs, ipairs, type, rawget
local getfenv, error = getfenv, error
local stringFind, stringFormat = string.find, string.format
local tableSort, tableRemove = table.sort, table.remove
local getupvalue, getmetatable = debug.getupvalue, debug.getmetatable
local getinfo, getlocal = debug.getinfo, debug.getlocal

local function mb(kb)
	return floor(kb / 1024 + 0.5)
end

local function nextPow2(n)
	if n <= 0 then
		return 0
	end
	local p = 1
	while p < n do
		p = p * 2
	end
	return p
end

-- What Lua 5.1 allocates on a 64-bit build, for when measuring fails.
local FALLBACK_SIZES = { table = 56, slot = 16, node = 40, string = 25, closure = 40, upvalue = 48, thread = 1200 }

-- Object sizes for the walk, measured rather than assumed: they depend on the engine's build.
-- Needs the collector stopped, which the engine already does inside call-ins.
function MemoryGuard.calibrate(gc)
	gc("stop")
	local function per(n, make)
		local keep = {}
		for i = 1, n do
			keep[i] = false
		end
		local before = gc("count")
		for i = 1, n do
			keep[i] = make(i)
		end
		return (gc("count") - before) * 1024 / n
	end
	local sizes = {}
	sizes.table = per(256, function()
		return {}
	end)
	sizes.slot = (
		per(16, function()
			local t = {}
			for j = 1, 1024 do
				t[j] = j
			end
			return t
		end) - sizes.table
	) / 1024
	sizes.node = (
		per(16, function()
			local t = {}
			for j = 1, 1024 do
				t[j + 0.5] = true
			end
			return t
		end) - sizes.table
	) / 1024
	sizes.string = per(256, function(i)
		return stringFormat("%020d", i)
	end) - 20
	sizes.closure = per(256, function()
		return function() end
	end)
	sizes.upvalue = per(256, function()
		local u = {}
		return function()
			return u
		end
	end) - sizes.closure - sizes.table
	sizes.thread = per(64, function()
		return coroutine.create(function() end)
	end)
	for k, v in pairs(FALLBACK_SIZES) do
		if not (sizes[k] > 0) then
			sizes[k] = v
		end
	end
	sizes.userdata = 64
	return sizes
end

-- Marks what is shared, down to the given depth, so the walk charges none of it to a widget.
function MemoryGuard.buildStopSet(roots, widgets)
	local stop = {}
	local function mark(t, depth)
		stop[t] = true
		if depth <= 0 then
			return
		end
		for _, v in next, t do
			local tv = type(v)
			if tv == "table" then
				mark(v, depth - 1)
			elseif tv == "function" or tv == "userdata" then
				stop[v] = true
			end
		end
	end
	for _, root in ipairs(roots) do
		if type(root[1]) == "table" then
			mark(root[1], root[2])
		end
	end
	for _, w in ipairs(widgets) do
		stop[w] = true
	end
	return stop
end

-- Entries of one table per visit: a table with millions of them must not stall a frame.
local CHUNK = 512

---@class MemoryGuardWalk
---@field bytes number
---@field objects integer
---@field capped boolean stopped at capBytes, so it holds at least that much
---@field partial boolean stopped at capObjects, so bytes is only a lower bound
---@field push fun(v: any)
---@field step fun(budget: number): boolean

---@class MemoryGuardWalkOptions
---@field stop table shared objects, not charged
---@field allow table? overrides stop
---@field ownsEnv fun(env: table?, widget: table): boolean
---@field transparent table? functions passed through though not the widget's own, like call-in wrappers
---@field sizes table
---@field capBytes number?
---@field capObjects number?

-- Estimates the bytes `root` holds: what it reaches, short of anything shared. A function only
-- counts when it runs in the widget's own environment, so the game's API functions it keeps, and
-- the game data behind their upvalues, are not put on it. What the walk has seen costs memory of
-- its own, which capObjects bounds.
---@param opts MemoryGuardWalkOptions
function MemoryGuard.newWalk(root, opts)
	local stop, allow, ownsEnv, sizes = opts.stop, opts.allow or {}, opts.ownsEnv, opts.sizes
	local transparent = opts.transparent or {}
	local capBytes, capObjects = opts.capBytes or math.huge, opts.capObjects or math.huge
	local seen, stack, top, seenCount = {}, {}, 0, 0
	-- A table left half done goes back on the stack with the last key it got to.
	local resumeKey = {} ---@type table<table, any>
	local resumeCount = {} ---@type table<table, integer>
	local walk ---@type MemoryGuardWalk

	local function push(v)
		local tv = type(v)
		if tv == "string" then
			if not seen[v] then
				seen[v] = true
				seenCount = seenCount + 1
				walk.bytes = walk.bytes + sizes.string + #v
			end
		elseif
			(tv == "table" or tv == "function" or tv == "thread" or tv == "userdata")
			and not seen[v]
			and (allow[v] or not stop[v])
		then
			seen[v] = true
			seenCount = seenCount + 1
			top = top + 1
			stack[top] = v
		end
	end

	local function ownCode(env)
		return env == root or ownsEnv(env, root)
	end

	local function visitTable(v)
		local weakKeys, weakValues = false, false
		local mt = getmetatable(v)
		if mt then
			push(mt)
			local mode = rawget(mt, "__mode")
			if type(mode) == "string" then
				weakKeys = stringFind(mode, "k", 1, true) ~= nil
				weakValues = stringFind(mode, "v", 1, true) ~= nil
			end
		end
		local entries = 0
		local k, val
		local resumeAt = resumeKey[v]
		if resumeAt == nil then
			walk.objects = walk.objects + 1
			k, val = next(v)
		else
			-- The widget ran since and may have changed it; a key it removed ends the visit.
			entries = resumeCount[v] or 0
			local ok
			ok, k, val = pcall(next, v, resumeAt)
			if not ok then
				k = nil
			end
		end
		local visited, lastKey = 0, nil
		while k ~= nil and visited < CHUNK do
			visited = visited + 1
			if not weakKeys then
				push(k)
			end
			if not weakValues then
				push(val)
			end
			lastKey = k
			k, val = next(v, k)
		end
		entries = entries + visited
		if k ~= nil then
			resumeKey[v], resumeCount[v] = lastKey, entries
			top = top + 1
			stack[top] = v
		else
			resumeKey[v], resumeCount[v] = nil, nil
			local n = #v
			local array = (n > 0 and v[n] ~= nil) and n or 0
			walk.bytes = walk.bytes
				+ sizes.table
				+ nextPow2(array) * sizes.slot
				+ nextPow2(entries - array) * sizes.node
		end
		return visited
	end

	-- Returns true once done, `budget` being objects plus an eighth of the entries iterated.
	---@param budget number
	local function step(budget)
		while top > 0 and budget > 0 do
			local v = stack[top]
			stack[top] = nil
			top = top - 1
			budget = budget - 1
			local tv = type(v)
			if tv == "table" then
				budget = budget - visitTable(v) / 8
			elseif tv == "function" then
				walk.objects = walk.objects + 1
				local env = getfenv(v)
				local own = ownCode(env)
				if own or transparent[v] then
					local i = 1
					while true do
						local name, val = getupvalue(v, i)
						if name == nil then
							break
						end
						push(val)
						i = i + 1
					end
					if own then
						walk.bytes = walk.bytes + sizes.closure + (i - 1) * sizes.upvalue
						push(env)
					end
				end
			elseif tv == "thread" then
				walk.objects = walk.objects + 1
				walk.bytes = walk.bytes + sizes.thread
				local level = 0
				while true do
					local info = getinfo(v, level, "f")
					if not info then
						break
					end
					push(info.func)
					local i = 1
					while true do
						local name, val = getlocal(v, level, i)
						if name == nil then
							break
						end
						push(val)
						i = i + 1
					end
					level = level + 1
				end
			else
				walk.objects = walk.objects + 1
				walk.bytes = walk.bytes + sizes.userdata
			end
			if walk.bytes > capBytes then
				walk.capped = true
				return true
			end
			if seenCount > capObjects then
				walk.partial = true
				return true
			end
		end
		return top == 0
	end

	walk = { bytes = 0, objects = 0, capped = false, partial = false, push = push, step = step }
	return walk
end

---@class MemoryGuardStats
---@field allocKB number since the last sample
---@field allocTotalKB number
---@field windowKB number since the pool was last below poolCollect
---@field rateKB number per second, smoothed
---@field hotSeconds number seconds above rateWarnKB without a break
---@field history number[] what it held at each walk
---@field warned table<string, boolean>
---@field retainedKB number?
---@field capped boolean?
---@field partial boolean? retainedKB is only a lower bound
---@field walkedAt number?
---@field settled number? when Initialize finished
---@field trip number? kB a call-in had allocated when it was stopped
---@field tripReported boolean?
---@field off boolean?
---@field wgKeys table<any, boolean>?

---@class MemoryGuardCycle
---@field queue table[]
---@field i integer
---@field stop table
---@field started number
---@field walk MemoryGuardWalk?

---@class MemoryGuardDeps
---@field gc? function collectgarbage
---@field sethook? function debug.sethook
---@field now fun(): number seconds
---@field startTimer fun(): any
---@field elapsedMs fun(timer: any): number
---@field poolUsage fun(): number kB in use across every Lua state
---@field gameFrame fun(): integer
---@field setCollectorBudget fun(ms: integer)
---@field activeWidgets fun(): table[]
---@field isActive fun(widget: table): boolean
---@field ownsEnv fun(env: table?, widget: table): boolean
---@field stopRoots fun(): table[] { {table, depth}, ... }
---@field WG table
---@field disable fun(widget: table, reason: string) turns it off and keeps the reason against it
---@field notify fun(text: string) a line the player reads
---@field log fun(text: string) a line for infolog
---@field translate fun(key: string, vars: table?): string
---@field enforce? boolean false: warn, never stop or turn off anything
---@field config? table overrides of MemoryGuard.defaults
---@field sizes? table skips calibrate

---@param deps MemoryGuardDeps
function MemoryGuard.new(deps)
	local cfg = setmetatable(deps.config or {}, { __index = MemoryGuard.defaults })
	local gc = deps.gc or collectgarbage
	local sethook = deps.sethook or debug.sethook
	local now, startTimer, elapsedMs = deps.now, deps.startTimer, deps.elapsedMs
	local poolUsage = deps.poolUsage
	local isActive, ownsEnv = deps.isActive, deps.ownsEnv
	local notify, log, tr = deps.notify, deps.log, deps.translate
	local enforce = deps.enforce ~= false
	local WG = deps.WG
	local limitKB = cfg.poolLimitKB
	local callLimitKB = cfg.callLimitKB
	local hookInterval = cfg.hookInterval
	local TRIP_ERROR = MemoryGuard.TRIP_ERROR

	local guard = { TRIP_ERROR = TRIP_ERROR }
	-- widget -> stats. Stats never point back at their widget, or it would never be collected.
	local users = setmetatable({}, { __mode = "k" }) ---@type table<table, MemoryGuardStats>
	guard.users = users

	local function nameOf(w)
		local info = rawget(w, "whInfo")
		return info and info.name or "?"
	end

	----------------------------------------------------------------------------
	-- Call-ins: what each allocates, and a stop for one that allocates far too much

	-- Nested call-ins (a user widget's call-in running another's) each keep only what they
	-- allocated themselves: the outer one is charged its whole span less the inner ones.
	local depth = 0
	local stackW = {} ---@type table[]
	local stackStart = {} ---@type number[]
	local stackChild = {} ---@type number[]
	local hooked = false

	-- Raises only while the widget's own code runs. Not in game code it called, which would be
	-- left half done, and not in the handler around it, outside the pcall that catches this.
	local function hook()
		local w = stackW[depth]
		if not w then
			return
		end
		local start = stackStart[depth] --[[@as number]]
		local used = gc("count") - start
		if used <= callLimitKB then
			return
		end
		local info = getinfo(2, "f")
		local env = info and getfenv(info.func)
		if env ~= w and not ownsEnv(env, w) then
			return
		end
		local s = users[w]
		if not s.trip then
			s.trip = used
		end
		-- The hook stays set: a widget that catches this runs into it again.
		error(TRIP_ERROR, 0)
	end

	function guard.register(w)
		if not users[w] then
			users[w] = {
				allocKB = 0,
				allocTotalKB = 0,
				windowKB = 0,
				rateKB = 0,
				hotSeconds = 0,
				history = {},
				warned = {},
			}
		end
	end

	function guard.isUser(w)
		return users[w] ~= nil
	end

	-- The handler's wrapper around a call-in runs in the handler's environment, and the walk would
	-- stop there, short of the widget's own function and the file-level state in its upvalues.
	local wrappers = setmetatable({}, { __mode = "k" })
	function guard.addWrapper(f)
		wrappers[f] = true
	end

	function guard.enter(w)
		local d = depth + 1
		depth = d
		stackW[d] = w
		stackStart[d] = gc("count")
		stackChild[d] = 0
		if d == 1 and enforce then
			sethook(hook, "", hookInterval)
			hooked = true
		end
	end

	-- Returns true when the call-in went over the limit, even if the widget caught the error.
	function guard.leave()
		local d = depth
		local start = stackStart[d] --[[@as number]]
		local child = stackChild[d] --[[@as number]]
		local used = gc("count") - start
		local w = stackW[d] --[[@as table]]
		stackW[d] = nil
		depth = d - 1
		if depth > 0 then
			local parent = stackChild[depth] --[[@as number]]
			stackChild[depth] = parent + used
		elseif hooked then
			sethook()
			hooked = false
		end
		local s = users[w]
		local own = used - child
		if own > 0 then
			s.allocKB = s.allocKB + own
		end
		return s.trip ~= nil and not s.tripReported
	end

	-- After Initialize: what loading allocated says nothing about the rate from here on.
	function guard.settle(w)
		local s = users[w]
		if s then
			s.allocKB = 0
			s.settled = now()
		end
	end

	-- WG entries a user widget makes while loading are its own, though WG is shared.
	function guard.snapshotWG()
		local keys = {}
		for k in pairs(WG) do
			keys[k] = true
		end
		return keys
	end

	function guard.claimWG(w, keys)
		local s = users[w]
		for k in pairs(WG) do
			if not keys[k] then
				s.wgKeys = s.wgKeys or {}
				s.wgKeys[k] = true
			end
		end
	end

	----------------------------------------------------------------------------
	-- Turning widgets off, and saying so

	-- WG entries of widgets turned off, cleared on the next update: by then the handler has removed
	-- the widget and run its Shutdown, and what they still hold would not be freed otherwise.
	local releaseWG = {}

	local function turnOff(w, s, reason)
		if s.off then
			return
		end
		s.off = true
		notify(tr("turnedOff", { name = nameOf(w), reason = reason }))
		deps.disable(w, reason)
		if s.wgKeys then
			releaseWG[#releaseWG + 1] = s.wgKeys
		end
	end

	local function warnOnce(s, kind, text)
		if not s.warned[kind] then
			s.warned[kind] = true
			notify(text)
		end
	end

	local function allocated(entry)
		return entry.s.windowKB + entry.s.allocKB
	end

	-- Running user widgets, the one most likely to be filling memory first: by what it holds when
	-- that is enough to matter, else by what it allocated since the pool last ran high, which
	-- covers what the walk cannot see without blaming a widget for a long session of garbage.
	---@return { w: table, s: MemoryGuardStats }[]
	local function suspects()
		local list = {}
		for _, w in ipairs(deps.activeWidgets()) do
			local s = users[w]
			if s and not s.off then
				list[#list + 1] = { w = w, s = s }
			end
		end
		tableSort(list, function(a, b)
			local ra, rb = a.s.retainedKB or 0, b.s.retainedKB or 0
			if ra ~= rb then
				return ra > rb
			end
			return allocated(a) > allocated(b)
		end)
		if list[1] and (list[1].s.retainedKB or 0) < cfg.significantKB then
			tableSort(list, function(a, b)
				return allocated(a) > allocated(b)
			end)
		end
		return list
	end

	-- A load that went over the limit. Returns the reason, or nil if it did not.
	function guard.takeTrip(w, label)
		local s = users[w]
		if not (s and s.trip and not s.tripReported) then
			return nil
		end
		s.tripReported = true
		local reason = tr("reasonLoad", { limit = mb(callLimitKB) })
		notify(tr("turnedOff", { name = label, reason = reason }))
		return reason
	end

	local stepping, stepKB = false, cfg.stepKB
	local reloaded = {}

	-- Called from the handler when a call-in raised. Returns "handled" when this turned the widget
	-- off, "reload" when a game widget ran out of memory and should be loaded again once removed.
	function guard.failure(w, funcName, errorMsg)
		if funcName == "Shutdown" then
			return nil
		end
		local s = users[w]
		if s and s.trip and not s.tripReported then
			s.tripReported = true
			turnOff(w, s, tr("reasonCall", { callin = funcName, limit = mb(callLimitKB) }))
			return "handled"
		end
		if type(errorMsg) ~= "string" or not stringFind(errorMsg, MemoryGuard.OUT_OF_MEMORY, 1, true) then
			return nil
		end
		-- Room to get through the rest of this at all.
		gc("collect")
		gc("stop")
		stepping = false
		if s then
			if not enforce then
				return nil
			end
			turnOff(w, s, tr("reasonOutOfMemory"))
			return "handled"
		end
		local top = suspects()[1]
		if top and enforce then
			turnOff(top.w, top.s, tr("reasonOutOfMemoryOther"))
		end
		local name = nameOf(w)
		if not reloaded[name] then
			reloaded[name] = true
			return "reload"
		end
		return nil
	end

	----------------------------------------------------------------------------
	-- How much each user widget holds

	local sizes = deps.sizes
	local cycle ---@type MemoryGuardCycle? the walk in progress over every running user widget
	local nextWalkAt = cfg.firstWalk ---@type number
	local lastCycleEnd = -math.huge
	local lastCycle = { widgets = 0, seconds = 0.0, stopMs = 0.0 } -- for the report
	local poolWarnPending = false

	local function evaluate(w, s)
		local kb = s.retainedKB
		if enforce and kb >= cfg.retainLimitKB then
			-- The walk stops counting at the limit.
			turnOff(w, s, tr("reasonHeld", { mb = mb(cfg.retainLimitKB) }))
			return
		end
		if kb >= cfg.retainWarnKB then
			warnOnce(s, "held", tr(s.partial and "warnHeldAtLeast" or "warnHeld", { name = nameOf(w), mb = mb(kb) }))
		end
		local h = s.history
		if s.partial then
			-- A lower bound that stays put says nothing about growth.
			for i = #h, 1, -1 do
				h[i] = nil
			end
			return
		end
		h[#h + 1] = kb
		if #h > cfg.growthWalks + 1 then
			tableRemove(h, 1)
		end
		if #h == cfg.growthWalks + 1 then
			for i = 2, #h do
				if h[i] - h[i - 1] < cfg.growthKB then
					return
				end
			end
			warnOnce(
				s,
				"growing",
				tr("warnGrowing", {
					name = nameOf(w),
					mb = mb(kb),
					grown = mb(h[#h] - h[1]),
					minutes = floor(cfg.growthWalks * cfg.walkInterval / 60 + 0.5),
				})
			)
		end
	end

	local function finishCycle()
		local c = cycle --[[@as MemoryGuardCycle]]
		cycle = nil
		lastCycleEnd = now()
		lastCycle.seconds = lastCycleEnd - c.started
		nextWalkAt = lastCycleEnd + max(cfg.walkInterval, 10 * lastCycle.seconds)
		if poolWarnPending then
			poolWarnPending = false
			local top = suspects()[1]
			local load = poolUsage() / limitKB
			if top and load >= cfg.poolWarn then
				notify(tr("warnPool", { percent = floor(load * 100), name = nameOf(top.w) }))
			end
		end
	end

	local function beginWidget()
		local c = cycle --[[@as MemoryGuardCycle]]
		while true do
			c.i = c.i + 1
			local w = c.queue[c.i]
			if not w then
				finishCycle()
				return
			end
			local s = users[w]
			if s and not s.off and isActive(w) then
				local allow = { [w] = true }
				local owned = {}
				for key in pairs(s.wgKeys or {}) do
					local v = WG[key]
					if type(v) == "table" or type(v) == "function" then
						allow[v] = true
						owned[#owned + 1] = v
						if type(v) == "table" then
							for _, child in next, v do
								allow[child] = true
							end
						end
					end
				end
				c.walk = MemoryGuard.newWalk(w, {
					stop = c.stop,
					allow = allow,
					ownsEnv = ownsEnv,
					transparent = wrappers,
					sizes = sizes --[[@as table]],
					capBytes = cfg.retainLimitKB * 1024,
					capObjects = cfg.walkObjectCap,
				})
				c.walk.push(w)
				for _, v in ipairs(owned) do
					c.walk.push(v)
				end
				return
			end
		end
	end

	local function startCycle()
		local widgets = deps.activeWidgets()
		local queue = {}
		for _, w in ipairs(widgets) do
			if guard.isUser(w) then
				queue[#queue + 1] = w
			end
		end
		if queue[1] == nil then
			nextWalkAt = now() + cfg.walkInterval
			return
		end
		sizes = sizes or MemoryGuard.calibrate(gc)
		local timer = startTimer()
		cycle = {
			queue = queue,
			i = 0,
			stop = MemoryGuard.buildStopSet(deps.stopRoots(), widgets),
			started = now(),
		}
		lastCycle.widgets, lastCycle.stopMs = #queue, elapsedMs(timer)
		beginWidget()
	end

	local function walkSlice()
		local timer = startTimer()
		repeat
			local c = cycle --[[@as MemoryGuardCycle]]
			local walk = c.walk --[[@as MemoryGuardWalk]]
			if walk.step(64) then
				-- The queue keeps the widget, so its stats are still there.
				local w = c.queue[c.i] --[[@as table]]
				local s = users[w]
				s.retainedKB = walk.bytes / 1024
				s.capped = walk.capped
				s.partial = walk.partial
				s.walkedAt = now()
				evaluate(w, s)
				beginWidget()
				if not cycle then
					return
				end
			end
		until elapsedMs(timer) >= cfg.walkBudget
	end

	local function requestWalk(t)
		if not cycle and t - lastCycleEnd > 10 then
			nextWalkAt = t
		end
	end

	----------------------------------------------------------------------------
	-- Allocation rates

	local lastSample

	local function sample(t)
		if not lastSample then
			lastSample = t
			return
		end
		local dt = t - lastSample
		if dt < 1 then
			return
		end
		lastSample = t
		local k = dt / cfg.rateSmoothing
		if k > 1 then
			k = 1
		end
		for w, s in pairs(users) do
			local rate = s.allocKB / dt
			s.allocTotalKB = s.allocTotalKB + s.allocKB
			s.windowKB = s.windowKB + s.allocKB
			s.rateKB = s.rateKB + (rate - s.rateKB) * k
			s.allocKB = 0
			-- Sustained, so a burst while it builds its caches is not taken for a habit.
			s.hotSeconds = (s.settled and rate > cfg.rateWarnKB) and s.hotSeconds + dt or 0
			if s.hotSeconds >= cfg.rateSustain and not s.off and isActive(w) then
				warnOnce(s, "rate", tr("warnRate", { name = nameOf(w), mb = mb(s.rateKB) }))
			end
		end
	end

	----------------------------------------------------------------------------
	-- The pool, and LuaUI's share of it

	local nextCollectKB = 0 ---@type number
	local pressureWait = false
	local poolWarned = false
	local poolHealthy = true

	-- The engine's per-state collector budget follows how fast LuaUI grows; see also
	-- luarules/gadgets/api_garbage_collector.lua.
	local capMin, capMax, cap = 1, 4, 1
	local trendWindow = 1800 -- frames
	local growthStepKB = 20000
	local trendFrame ---@type integer?
	local trendKB = 0

	local function adaptBudget(count)
		local n = deps.gameFrame()
		if not trendFrame then
			trendFrame, trendKB = n, count
			return
		end
		if n - trendFrame < trendWindow then
			return
		end
		local growth = count - trendKB
		trendFrame, trendKB = n, count
		local newCap = cap
		if growth > growthStepKB then
			newCap = min(capMax, cap + 1)
		elseif growth < growthStepKB / 4 then
			newCap = max(capMin, cap - 1)
		end
		if newCap ~= cap then
			cap = newCap
			deps.setCollectorBudget(cap)
			if debugEcho then
				log(
					stringFormat(
						"LuaUI memory %s %d MB in the last minute, garbage collector budget set to %d ms",
						growth >= 0 and "grew" or "shrank",
						mb(math.abs(growth)),
						cap
					)
				)
			end
		end
	end

	-- A widget turned off is still marked live in a collection already under way: only one that
	-- starts after it was removed frees it, so pressure waits for two.
	local cyclesLeft = 0

	local function startStepping(kb, cycles)
		stepping, stepKB, cyclesLeft = true, kb, cycles or 1
	end

	local function finishStepping()
		stepping = false
		pressureWait = false
		local poolKB = poolUsage()
		nextCollectKB = poolKB + 0.1 * limitKB
		trendFrame, trendKB = deps.gameFrame(), gc("count")
		if debugEcho then
			log(
				stringFormat(
					"Gradual garbage collection done, LuaUI now uses %d MB, Lua memory at %d%% of its limit",
					mb(gc("count")),
					floor(poolKB / limitKB * 100)
				)
			)
		end
	end

	local function checkPool(t)
		local poolKB = poolUsage()
		local load = poolKB / limitKB
		local ownKB = gc("count")
		adaptBudget(ownKB)

		if load >= cfg.poolEmergency then
			log(
				stringFormat(
					"Warning: Lua memory at %d%% of its limit (%d of %d MB), collecting LuaUI's garbage at once",
					floor(load * 100),
					mb(poolKB),
					mb(limitKB)
				)
			)
			gc("collect")
			gc("stop")
			stepping, pressureWait = false, false
			poolKB = poolUsage()
			load = poolKB / limitKB
			ownKB = gc("count")
		end

		if load >= cfg.poolAct and enforce and ownKB >= cfg.luauiShare * limitKB then
			if not pressureWait then
				local top = suspects()[1]
				if top then
					turnOff(top.w, top.s, tr("reasonPool", { percent = floor(load * 100) }))
					startStepping(cfg.pressureStepKB, 2)
					pressureWait = true -- until the collection shows what that freed
				end
			end
		elseif load >= cfg.poolWarn then
			if not poolWarned then
				poolWarned = true
				if suspects()[1] then
					poolWarnPending = true
					requestWalk(t)
				else
					log(stringFormat("Warning: Lua memory at %d%% of its limit", floor(load * 100)))
				end
			end
		elseif load < cfg.poolWarn - 0.05 then
			poolWarned = false
		end

		if poolKB < cfg.poolCollect * limitKB then
			nextCollectKB = 0
			if not poolHealthy then
				poolHealthy = true
				for _, s in pairs(users) do
					s.windowKB = 0
				end
			end
		else
			poolHealthy = false
		end
		if poolKB >= cfg.poolCollect * limitKB and not stepping and poolKB >= nextCollectKB then
			log(
				stringFormat(
					"Warning: Lua memory at %d%% of its limit, LuaUI uses %d MB, starting a gradual garbage collection",
					floor(load * 100),
					mb(ownKB)
				)
			)
			startStepping(cfg.stepKB)
		end
		return load
	end

	----------------------------------------------------------------------------

	local updates = 0
	local load = 0 ---@type number

	function guard.update()
		updates = updates + 1
		for i = #releaseWG, 1, -1 do
			for key in pairs(releaseWG[i]) do
				WG[key] = nil
			end
			releaseWG[i] = nil
		end
		if stepping then
			local done = gc("step", stepKB)
			-- The engine keeps the collector stopped outside its own collection, and a step restarts it.
			gc("stop")
			if done then
				cyclesLeft = cyclesLeft - 1
				if cyclesLeft <= 0 then
					finishStepping()
				end
			end
		end
		if updates % cfg.checkInterval == 0 then
			local t = now()
			load = checkPool(t)
			sample(t)
			-- Past walkMaxLoad only to name the widget behind a pool warning.
			local canWalk = load < cfg.walkMaxLoad or (poolWarnPending and load < cfg.poolAct)
			if not cycle and t >= nextWalkAt and canWalk then
				startCycle()
			end
		end
		if cycle then
			walkSlice()
		end
	end

	-- For /luaui widgetmemory.
	function guard.report()
		local poolKB = poolUsage()
		log(
			stringFormat(
				"Lua memory: %d of %d MB (%d%%), LuaUI %d MB",
				mb(poolKB),
				mb(limitKB),
				floor(poolKB / limitKB * 100),
				mb(gc("count"))
			)
		)
		local list = suspects()
		if list[1] == nil then
			log("No user widgets running")
		end
		local t = now()
		if lastCycleEnd > -math.huge then
			log(
				stringFormat(
					"Last walk: %d widgets in %.1f s, %d s ago, shared tables marked in %.1f ms",
					lastCycle.widgets,
					lastCycle.seconds,
					t - lastCycleEnd,
					lastCycle.stopMs
				)
			)
		end
		for _, entry in ipairs(list) do
			local s = entry.s
			local held = s.retainedKB
					and stringFormat(
						"holds %s%.1f MB (%d s ago)",
						(s.capped or s.partial) and ">" or "",
						s.retainedKB / 1024,
						t - (s.walkedAt or t)
					)
				or "not measured yet"
			log(
				stringFormat(
					"  %s: %s, allocates %d kB/s, %d MB since loaded",
					nameOf(entry.w),
					held,
					floor(s.rateKB),
					mb(s.allocTotalKB + s.allocKB)
				)
			)
		end
		requestWalk(t)
	end

	return guard
end

return MemoryGuard
