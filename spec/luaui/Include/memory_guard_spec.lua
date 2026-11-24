-- Guards how barwidgets measures user widgets' memory, stops the ones that use too much and
-- keeps the shared Lua memory pool from running out.

local MemoryGuard = require("luaui/Include/memory_guard")

local SIZES =
	{ table = 56, slot = 16, node = 40, string = 25, closure = 40, upvalue = 48, thread = 1200, userdata = 64 }
local LIMIT_KB = 1000000

local function newWidget(h, name)
	local w = { whInfo = { name = name, basename = name .. ".lua" } }
	h.guard.register(w)
	h.widgets[#h.widgets + 1] = w
	return w
end

local function harness(config)
	local h = { notes = {}, logs = {}, disabled = {}, count = 0.0, pool = 0.0, clock = 0.0, steps = 0, collects = 0 }
	h.widgets, h.envs, h.WG = {}, {}, {}
	h.stepDone = false

	local function gc(what)
		if what == "count" then
			return h.count
		elseif what == "step" then
			h.steps = h.steps + 1
			return h.stepDone
		elseif what == "collect" then
			h.collects = h.collects + 1
			if h.afterCollect then
				h.count, h.pool = h.afterCollect, h.afterCollectPool or h.pool
			end
		end
		return 0
	end

	-- A coverage run hooks too: clearing ours gives its hook back.
	local dbgSethook = debug.sethook ---@type function
	local previousHook, previousMask, previousCount = debug.gethook()
	local function sethook(f, mask, n)
		if f then
			dbgSethook(f, mask, n)
		else
			dbgSethook(previousHook, previousMask, previousCount)
		end
	end

	local cfg = { poolLimitKB = LIMIT_KB, checkInterval = 1, firstWalk = 0, walkBudget = 1e9 }
	for k, v in pairs(config or {}) do
		cfg[k] = v
	end

	h.guard = MemoryGuard.new({
		gc = gc,
		sethook = sethook,
		now = function()
			return h.clock
		end,
		startTimer = function()
			return 0
		end,
		elapsedMs = function()
			return 0
		end,
		poolUsage = function()
			return h.pool
		end,
		gameFrame = function()
			return 0
		end,
		setCollectorBudget = function() end,
		activeWidgets = function()
			return h.widgets
		end,
		isActive = function(w)
			for _, v in ipairs(h.widgets) do
				if v == w then
					return true
				end
			end
			return false
		end,
		ownsEnv = function(env, w)
			return h.envs[env] == w
		end,
		stopRoots = function()
			return { { h.WG, 2 } }
		end,
		WG = h.WG,
		disable = function(w, reason)
			h.disabled[#h.disabled + 1] = { name = w.whInfo.name, reason = reason }
			for i, v in ipairs(h.widgets) do
				if v == w then
					table.remove(h.widgets, i)
					break
				end
			end
		end,
		notify = function(text)
			h.notes[#h.notes + 1] = text
		end,
		log = function(text)
			h.logs[#h.logs + 1] = text
		end,
		translate = function(key, vars)
			return key .. ":" .. tostring(vars and vars.name or "")
		end,
		enforce = cfg.enforce,
		config = cfg,
		sizes = SIZES,
	})
	return h
end

local function never()
	return false
end

local function walkAll(root, opts)
	opts.ownsEnv = opts.ownsEnv or never
	opts.sizes = SIZES
	local walk = MemoryGuard.newWalk(root, opts)
	walk.push(root)
	repeat
	until walk.step(64)
	return walk
end

local function noted(h, prefix)
	local found = {}
	for _, text in ipairs(h.notes) do
		if text:sub(1, #prefix) == prefix then
			found[#found + 1] = text
		end
	end
	return found
end

describe("what user widgets' call-ins allocate", function()
	it("charges nested call-ins only what each allocated itself", function()
		local h = harness()
		local a, b = newWidget(h, "A"), newWidget(h, "B")

		h.guard.enter(a)
		h.count = h.count + 10
		h.guard.enter(b)
		h.count = h.count + 5
		assert.is_false(h.guard.leave())
		h.count = h.count + 1
		assert.is_false(h.guard.leave())

		assert.are.equal(11, h.guard.users[a].allocKB)
		assert.are.equal(5, h.guard.users[b].allocKB)
	end)

	it("does not warn about a burst", function()
		local h = harness({ rateWarnKB = 1000 })
		local a = newWidget(h, "A")
		h.guard.settle(a)

		for second = 1, 30 do
			h.guard.enter(a)
			h.count = h.count + (second <= 3 and 100000 or 0)
			h.guard.leave()
			h.clock = h.clock + 1
			h.guard.update()
		end

		assert.are.same({}, noted(h, "warnRate"))
	end)

	it("warns once about a widget that keeps allocating fast, after it has settled", function()
		local h = harness({ rateWarnKB = 1000, rateSmoothing = 2 })
		local a = newWidget(h, "A")
		h.guard.settle(a)

		for _ = 1, 20 do
			h.guard.enter(a)
			h.count = h.count + 4000
			h.guard.leave()
			h.clock = h.clock + 1
			h.guard.update()
		end

		assert.are.same({ "warnRate:A" }, noted(h, "warnRate"))
	end)
end)

describe("a call-in that allocates too much", function()
	it("is stopped inside the widget's own code and turned off", function()
		local h = harness({ callLimitKB = 100, hookInterval = 100 })
		local w = newWidget(h, "Leaky")
		local function runaway()
			while true do
				h.count = h.count + 1
			end
		end
		setfenv(runaway, w)

		h.guard.enter(w)
		local ok, err = pcall(runaway)
		local tripped = h.guard.leave()

		assert.is_false(ok)
		assert.are.equal(MemoryGuard.TRIP_ERROR, err)
		assert.is_true(tripped)
		assert.are.equal("handled", h.guard.failure(w, "DrawScreen", err))
		assert.are.same({ { name = "Leaky", reason = "reasonCall:" } }, h.disabled)
		assert.are.same({ "turnedOff:Leaky" }, h.notes)
	end)

	it("is not interrupted in code that is not its own, but is once that returns", function()
		local h = harness({ callLimitKB = 100, hookInterval = 100 })
		local w = newWidget(h, "Caller")
		local finished = false
		local function gameCode()
			for _ = 1, 5000 do
				h.count = h.count + 1
			end
			finished = true
		end
		local function userCode()
			gameCode()
			while true do
				h.count = h.count + 0
			end
		end
		setfenv(userCode, w)

		h.guard.enter(w)
		local ok, err = pcall(userCode)
		h.guard.leave()

		assert.is_true(finished)
		assert.is_false(ok)
		assert.are.equal(MemoryGuard.TRIP_ERROR, err)
	end)

	it("is still turned off when the widget catches the error itself", function()
		local h = harness({ callLimitKB = 100, hookInterval = 100 })
		local w = newWidget(h, "Swallower")
		setmetatable(w, { __index = _G }) -- as a widget falls through to System
		local function userCode()
			pcall(function()
				while true do
					h.count = h.count + 1
				end
			end)
		end
		setfenv(userCode, w)

		h.guard.enter(w)
		pcall(userCode)
		local tripped = h.guard.leave()

		assert.is_true(tripped)
		assert.are.equal("handled", h.guard.failure(w, "Update", MemoryGuard.TRIP_ERROR))
		assert.are.equal(1, #h.disabled)
	end)

	it("fails the load when the widget's file allocates too much", function()
		local h = harness({ callLimitKB = 100, hookInterval = 100 })
		local w = { whInfo = nil }
		h.guard.register(w)
		local function chunk()
			while true do
				h.count = h.count + 1
			end
		end
		setfenv(chunk, w)

		h.guard.enter(w)
		pcall(chunk)
		assert.is_true(h.guard.leave())
		assert.are.equal("reasonLoad:", h.guard.takeTrip(w, "leaky.lua"))
		assert.are.same({ "turnedOff:leaky.lua" }, h.notes)
		assert.is_nil(h.guard.takeTrip(w, "leaky.lua"))
	end)
end)

describe("running out of memory", function()
	it("turns off the user widget it happened in", function()
		local h = harness()
		local w = newWidget(h, "A")

		assert.are.equal("handled", h.guard.failure(w, "Update", "not enough memory"))
		assert.are.equal(1, h.collects)
		assert.are.same({ { name = "A", reason = "reasonOutOfMemory:" } }, h.disabled)
	end)

	it("in a game widget turns off the largest user widget and reloads the game widget once", function()
		local h = harness()
		local small, big = newWidget(h, "Small"), newWidget(h, "Big")
		h.guard.users[small].retainedKB = 10
		h.guard.users[big].retainedKB = 500
		local gameWidget = { whInfo = { name = "Top Bar" } }

		assert.are.equal("reload", h.guard.failure(gameWidget, "DrawScreen", "[string]:1: not enough memory"))
		assert.are.same({ { name = "Big", reason = "reasonOutOfMemoryOther:" } }, h.disabled)
		assert.is_nil(h.guard.failure(gameWidget, "DrawScreen", "not enough memory"))
	end)

	it("leaves the user widget to the handler's usual removal when not enforcing", function()
		local h = harness({ enforce = false })
		local w = newWidget(h, "A")

		assert.is_nil(h.guard.failure(w, "Update", "not enough memory"))
		assert.are.same({}, h.disabled)
	end)

	it("leaves other errors and Shutdown to the handler", function()
		local h = harness()
		local w = newWidget(h, "A")

		assert.is_nil(h.guard.failure(w, "Update", "attempt to index a nil value"))
		assert.is_nil(h.guard.failure(w, "Shutdown", "not enough memory"))
		assert.are.same({}, h.disabled)
	end)
end)

describe("what a user widget holds", function()
	it("counts its own tables and strings", function()
		local w = { data = { 1, 2, 3 } }
		local walk = walkAll(w, { stop = {} })

		-- w: one hash node; data: four array slots; the key "data".
		assert.are.equal((56 + 40) + (56 + 4 * 16) + (25 + 4), walk.bytes)
	end)

	it("walks a huge table a slice at a time, and copes with it changing in between", function()
		local w = { big = {} }
		for i = 1, 5000 do
			w.big["k" .. i] = i
		end
		local walk = MemoryGuard.newWalk(w, { stop = {}, ownsEnv = never, sizes = SIZES })
		walk.push(w)

		local steps = 0
		repeat
			steps = steps + 1
			-- what the widget does between two updates
			w.big["k" .. steps] = nil
			w.big["new" .. steps] = steps
		until walk.step(64)

		assert.is_true(steps > 5)
		assert.is_true(walk.bytes > 5000 * (25 + 5))
	end)

	it("stops at the object cap and says the result is a lower bound", function()
		local w = { list = {} }
		for i = 1, 1000 do
			w.list[i] = { i }
		end
		local walk = walkAll(w, { stop = {}, capObjects = 100 })

		assert.is_true(walk.partial)
		assert.is_false(walk.capped)
		assert.is_true(walk.bytes < 1000 * (56 + 16))
	end)

	it("charges nothing shared, nor the game data behind functions it keeps", function()
		local h = harness()
		local shared = {}
		for i = 1, 1000 do
			shared[i] = { i }
		end
		h.WG.api = { data = shared }
		local gameData = {}
		for i = 1, 1000 do
			gameData[i] = { i }
		end
		local function gameFunction()
			return gameData
		end

		local w = newWidget(h, "A")
		local own = {}
		for i = 1, 100 do
			own[i] = { i }
		end
		local api = h.WG.api
		function w.Update()
			return own, api.data, gameFunction
		end
		setfenv(w.Update, w)
		w.cache = h.WG.api.data

		local stop = MemoryGuard.buildStopSet({ { h.WG, 2 } }, h.widgets)
		local walk = walkAll(w, { stop = stop, allow = { [w] = true } })

		-- own: 100 tables of one slot each plus their array; the rest is the widget's few fields.
		local ownBytes = 100 * (56 + 16) + (56 + 128 * 16)
		assert.is_true(walk.bytes > ownBytes)
		assert.is_true(walk.bytes < ownBytes + 2000)
	end)

	it("sees through the handler's wrapper to the widget's own call-in and its upvalues", function()
		local h = harness()
		local w = newWidget(h, "Wrapped")
		local held = {}
		for i = 1, 1000 do
			held[i] = { i }
		end
		local function update()
			return held
		end
		setfenv(update, w)
		-- what SafeWrapFuncUser hands the widget: a closure in the handler's environment
		local function wrapper(...)
			return update(...)
		end
		h.guard.addWrapper(wrapper)
		w.Update = wrapper

		h.guard.update()

		assert.is_true(h.guard.users[w].retainedKB > 1000 * 72 / 1024)
	end)

	it("counts the WG entries it made while loading as its own", function()
		local h = harness({ retainLimitKB = 1e9, retainWarnKB = 50 })
		local w = newWidget(h, "Stasher")
		local keys = h.guard.snapshotWG()
		local big = {}
		for i = 1, 1000 do
			big[i] = { i }
		end
		h.WG.stash = big
		h.guard.claimWG(w, keys)

		h.guard.update()

		assert.is_true(h.guard.users[w].retainedKB > 50)
		assert.are.same({ "warnHeld:Stasher" }, noted(h, "warnHeld"))
	end)

	it("clears the WG entries of a widget it turned off, on the next update", function()
		local h = harness({ retainLimitKB = 20 })
		local w = newWidget(h, "Stasher")
		local keys = h.guard.snapshotWG()
		h.WG.stash = {}
		for i = 1, 5000 do
			h.WG.stash[i] = { i }
		end
		h.WG.shared = h.WG.shared or {}
		h.guard.claimWG(w, keys)
		h.WG.gameApi = {}

		h.guard.update()
		assert.are.equal(1, #h.disabled)
		assert.is_not_nil(h.WG.stash)
		h.guard.update()

		assert.is_nil(h.WG.stash)
		assert.is_nil(h.WG.shared)
		assert.is_not_nil(h.WG.gameApi)
	end)

	it("turns off a widget holding more than the limit, stopping the walk there", function()
		local h = harness({ retainLimitKB = 20 })
		local w = newWidget(h, "Hoarder")
		w.hoard = {}
		for i = 1, 5000 do
			w.hoard[i] = { i }
		end

		h.guard.update()

		assert.is_true(h.guard.users[w].capped)
		assert.are.same({ { name = "Hoarder", reason = "reasonHeld:" } }, h.disabled)
	end)

	it("warns once about a widget that grows on every walk", function()
		local h = harness({ growthKB = 10, growthWalks = 3, walkInterval = 60 })
		local w = newWidget(h, "Grower")
		w.log = {}

		for walkNo = 1, 6 do
			for i = 1, 500 do
				w.log[#w.log + 1] = { walkNo, i }
			end
			h.guard.update()
			h.clock = h.clock + 61
		end

		assert.are.same({ "warnGrowing:Grower" }, noted(h, "warnGrowing"))
	end)
end)

describe("the shared Lua memory pool", function()
	it("steps a full collection past the collect share, and not again straight after", function()
		local h = harness()
		h.pool = 0.65 * LIMIT_KB

		h.guard.update()
		h.guard.update()
		assert.are.equal(1, h.steps)
		h.stepDone = true
		h.guard.update()
		local steps = h.steps
		h.stepDone = false
		h.guard.update()

		assert.are.equal(steps, h.steps)
	end)

	it("names the largest user widget past the warn share", function()
		local h = harness()
		local w = newWidget(h, "A")
		w.data = { 1, 2, 3 }
		h.pool = 0.72 * LIMIT_KB

		h.guard.update()

		assert.are.same({ "warnPool:A" }, noted(h, "warnPool"))
	end)

	it("still names it between the walking limit and the act share", function()
		local h = harness()
		local w = newWidget(h, "A")
		w.data = { 1, 2, 3 }
		h.pool = 0.77 * LIMIT_KB

		h.guard.update()

		assert.are.same({ "warnPool:A" }, noted(h, "warnPool"))
	end)

	it("turns user widgets off biggest first, one per collection, while LuaUI holds a big share", function()
		local h = harness()
		local small, big = newWidget(h, "Small"), newWidget(h, "Big")
		h.guard.users[small].retainedKB = 1000
		h.guard.users[big].retainedKB = 300000
		h.pool, h.count = 0.82 * LIMIT_KB, 0.5 * LIMIT_KB

		h.guard.update()
		h.guard.update()
		assert.are.equal(1, #h.disabled)
		assert.are.equal("Big", h.disabled[1].name)

		-- The collection under way when Big went off cannot have freed it: no judging on that one.
		h.stepDone = true
		h.guard.update()
		assert.are.equal(1, #h.disabled)
		h.guard.update()
		assert.are.equal("Small", h.disabled[2].name)
	end)

	it("goes by what was allocated when no user widget holds enough to matter", function()
		local h = harness()
		local small, hidden = newWidget(h, "Small"), newWidget(h, "Hidden")
		h.guard.users[small].retainedKB = 1000
		h.guard.users[hidden].retainedKB = 0
		h.guard.users[hidden].windowKB = 500000
		h.pool, h.count = 0.82 * LIMIT_KB, 0.5 * LIMIT_KB

		h.guard.update()

		assert.are.equal("Hidden", h.disabled[1].name)
	end)

	it("leaves user widgets alone when LuaUI is not what fills the pool", function()
		local h = harness()
		newWidget(h, "A")
		h.pool, h.count = 0.85 * LIMIT_KB, 0.1 * LIMIT_KB

		h.guard.update()

		assert.are.same({}, h.disabled)
	end)

	it("collects at once past the emergency share", function()
		local h = harness()
		h.pool, h.count = 0.95 * LIMIT_KB, 0.5 * LIMIT_KB
		h.afterCollect, h.afterCollectPool = 0.2 * LIMIT_KB, 0.5 * LIMIT_KB

		h.guard.update()

		assert.are.equal(1, h.collects)
		assert.are.same({}, h.disabled)
	end)

	it("only warns when told not to enforce", function()
		local h = harness({ enforce = false, retainLimitKB = 0.1, retainWarnKB = 0.1 })
		local w = newWidget(h, "A")
		w.data = { 1, 2, 3 }
		h.pool, h.count = 0.82 * LIMIT_KB, 0.5 * LIMIT_KB
		h.guard.update()
		-- low enough again to walk
		h.pool = 0.5 * LIMIT_KB
		h.guard.update()

		assert.are.same({}, h.disabled)
		assert.are.same({ "warnHeld:A" }, noted(h, "warnHeld"))
	end)
end)
