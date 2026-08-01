local TriggerEngine = VFS.Include("modules/missions/lib/trigger_engine.lua")

---@param counts table<integer, table<string, integer>> teamID -> defName -> count
---@param frame integer?
---@return MissionContext
local function makeCtx(counts, frame)
	return {
		frame = frame or 0,
		GetUnitDefCount = function(teamID, defName)
			return (counts[teamID] or {})[defName] or 0
		end,
	}
end

---@param id string
---@param result boolean|fun(ctx: MissionContext): boolean
---@param log string[]
---@return TriggerDescriptor
local function makeTrigger(id, result, log)
	return {
		id = id,
		filename = id:match("^(.*):") or id,
		order = tonumber(id:match(":(%d+)$")) or 1,
		condition = {
			evaluate = function(ctx)
				if type(result) == "function" then
					return result(ctx)
				end
				return result
			end,
		},
		effects = { {
			execute = function()
				log[#log + 1] = id
			end,
		} },
		once = true,
	}
end

describe("TriggerEngine", function()
	it("runs an effect when its condition holds", function()
		local engine = TriggerEngine.New()
		local log = {}
		engine.Register(makeTrigger("f.lua:1", true, log))
		engine.Evaluate(makeCtx({}))
		assert.are.same({ "f.lua:1" }, log)
	end)

	it("does not run an effect while its condition is false", function()
		local engine = TriggerEngine.New()
		local log = {}
		engine.Register(makeTrigger("f.lua:1", false, log))
		engine.Evaluate(makeCtx({}))
		assert.are.same({}, log)
	end)

	it("fires a once trigger at most once", function()
		local engine = TriggerEngine.New()
		local log = {}
		engine.Register(makeTrigger("f.lua:1", true, log))
		engine.Evaluate(makeCtx({}))
		engine.Evaluate(makeCtx({}))
		assert.are.same({ "f.lua:1" }, log)
	end)

	it("fires a repeating trigger every evaluation", function()
		local engine = TriggerEngine.New()
		local log = {}
		local trigger = makeTrigger("f.lua:1", true, log)
		trigger.once = false
		engine.Register(trigger)
		engine.Evaluate(makeCtx({}))
		engine.Evaluate(makeCtx({}))
		assert.are.same({ "f.lua:1", "f.lua:1" }, log)
	end)

	it("rejects duplicate trigger ids", function()
		local engine = TriggerEngine.New()
		local log = {}
		engine.Register(makeTrigger("f.lua:1", true, log))
		assert.has_error(function()
			engine.Register(makeTrigger("f.lua:1", true, log))
		end)
	end)

	it("keeps fired flags in the engine state table, not closures", function()
		local engine = TriggerEngine.New()
		local log = {}
		engine.Register(makeTrigger("f.lua:1", true, log))
		engine.Evaluate(makeCtx({}))
		assert.is_true(engine.GetState().fired["f.lua:1"])
	end)

	it("restores progress via SetState: a restored fired flag suppresses the effect", function()
		local engine = TriggerEngine.New()
		local log = {}
		engine.Register(makeTrigger("f.lua:1", true, log))
		engine.SetState({ fired = { ["f.lua:1"] = true } })
		engine.Evaluate(makeCtx({}))
		assert.are.same({}, log)
	end)

	describe("condition inputs (event-driven evaluation)", function()
		local function watcherTrigger(id, log, inputs, result)
			return {
				id = id,
				filename = id:match("^(.*):") or id,
				order = tonumber(id:match(":(%d+)$")) or 1,
				condition = {
					inputs = inputs,
					evaluate = function()
						log.evaluated[#log.evaluated + 1] = id
						return result ~= false
					end,
				},
				effects = { { execute = function()
					log.fired[#log.fired + 1] = id
				end } },
				once = true,
			}
		end

		local function newLog()
			return { evaluated = {}, fired = {} }
		end

		it("indexes watched inputs at Register", function()
			local engine = TriggerEngine.New()
			local log = newLog()
			engine.Register(watcherTrigger("f.lua:1", log, { "UnitFinished", "UnitDestroyed" }))
			assert.are.same({ UnitFinished = true, UnitDestroyed = true }, engine.WatchedInputs())
		end)

		it("evaluates a watcher once on arm, then only after its events", function()
			local engine = TriggerEngine.New()
			local log = newLog()
			engine.Register(watcherTrigger("f.lua:1", log, { "UnitFinished" }, false))
			engine.Evaluate(makeCtx({})) -- armed: evaluates once
			engine.Evaluate(makeCtx({})) -- no event since: skipped
			assert.are.equal(1, #log.evaluated)
			engine.OnEvent("UnitFinished")
			engine.Evaluate(makeCtx({}))
			assert.are.equal(2, #log.evaluated)
		end)

		it("ignores events nothing watches", function()
			local engine = TriggerEngine.New()
			local log = newLog()
			engine.Register(watcherTrigger("f.lua:1", log, { "UnitFinished" }, false))
			engine.Evaluate(makeCtx({}))
			engine.OnEvent("mission.objective_changed")
			engine.Evaluate(makeCtx({}))
			assert.are.equal(1, #log.evaluated)
		end)

		it("polls conditions with nil inputs every cadence", function()
			local engine = TriggerEngine.New()
			local log = newLog()
			engine.Register(watcherTrigger("f.lua:1", log, nil, false))
			engine.Evaluate(makeCtx({}))
			engine.Evaluate(makeCtx({}))
			engine.Evaluate(makeCtx({}))
			assert.are.equal(3, #log.evaluated)
		end)

		it("UnregisterFile cleans the watcher index", function()
			local engine = TriggerEngine.New()
			local log = newLog()
			engine.Register(watcherTrigger("a.lua:1", log, { "UnitFinished" }))
			engine.UnregisterFile("a.lua")
			assert.are.same({}, engine.WatchedInputs())
			engine.OnEvent("UnitFinished")
			engine.Evaluate(makeCtx({}))
			assert.are.equal(0, #log.evaluated)
		end)
	end)

	describe("UnregisterFile", function()
		it("removes exactly that file's triggers and their progress", function()
			local engine = TriggerEngine.New()
			local log = {}
			engine.Register(makeTrigger("a.lua:1", true, log))
			engine.Register(makeTrigger("b.lua:1", true, log))
			engine.Evaluate(makeCtx({}))

			local removed = engine.UnregisterFile("a.lua")
			assert.are.equal(1, removed)
			assert.is_nil(engine.GetState().fired["a.lua:1"])
			assert.is_true(engine.GetState().fired["b.lua:1"])
			assert.are.equal(1, #engine.Triggers())
			assert.are.equal("b.lua:1", engine.Triggers()[1].id)
		end)

		it("lets a re-registered trigger fire again (hot reload)", function()
			local engine = TriggerEngine.New()
			local log = {}
			engine.Register(makeTrigger("a.lua:1", true, log))
			engine.Evaluate(makeCtx({}))
			engine.UnregisterFile("a.lua")
			engine.Register(makeTrigger("a.lua:1", true, log))
			engine.Evaluate(makeCtx({}))
			assert.are.same({ "a.lua:1", "a.lua:1" }, log)
		end)
	end)
end)

describe("delayed triggers", function()
	local TriggerEngine = VFS.Include("modules/missions/lib/trigger_engine.lua")

	---@param delayFrames integer
	local function delayed(engine, delayFrames, holds, fired)
		engine.Register({
			id = "f.lua:1",
			filename = "f.lua",
			order = 1,
			condition = { evaluate = function() return holds() end },
			effects = { { execute = function() fired[#fired + 1] = true end } },
			once = true,
			delayFrames = delayFrames,
		})
	end

	it("waits for the conditions to have held that long", function()
		local engine, fired, holds = TriggerEngine.New(), {}, true
		delayed(engine, 90, function() return holds end, fired)

		engine.Evaluate({ frame = 100 })
		assert.are.equal(0, #fired, "the clock starts, nothing fires")
		engine.Evaluate({ frame = 180 })
		assert.are.equal(0, #fired, "still short of the interval")
		engine.Evaluate({ frame = 190 })
		assert.are.equal(1, #fired)
	end)

	it("measures a CONTINUOUS hold — losing the condition resets the clock", function()
		local engine, fired = TriggerEngine.New(), {}
		local holds = true
		delayed(engine, 90, function() return holds end, fired)

		engine.Evaluate({ frame = 100 })
		holds = false
		engine.Evaluate({ frame = 150 })
		holds = true
		engine.Evaluate({ frame = 160 })
		-- Were the clock still running from 100, this would fire.
		engine.Evaluate({ frame = 200 })
		assert.are.equal(0, #fired)
		engine.Evaluate({ frame = 250 })
		assert.are.equal(1, #fired)
	end)

	it("re-arms after each fire, so a repeating trigger is rate limited", function()
		local engine, fired = TriggerEngine.New(), {}
		engine.Register({
			id = "f.lua:1",
			filename = "f.lua",
			order = 1,
			condition = { evaluate = function() return true end },
			effects = { { execute = function() fired[#fired + 1] = true end } },
			once = false,
			delayFrames = 30,
		})
		engine.Evaluate({ frame = 0 })
		engine.Evaluate({ frame = 10 })
		assert.are.equal(0, #fired)
		engine.Evaluate({ frame = 30 })
		assert.are.equal(1, #fired)
		engine.Evaluate({ frame = 45 })
		assert.are.equal(1, #fired, "the interval restarts at the fire")
		-- Exactly one interval after the fire, with no cadence drift added.
		engine.Evaluate({ frame = 60 })
		assert.are.equal(2, #fired)
		engine.Evaluate({ frame = 89 })
		assert.are.equal(2, #fired)
		engine.Evaluate({ frame = 90 })
		assert.are.equal(3, #fired)
	end)

	it("polls even when its condition declares inputs — a countdown has no event", function()
		local engine, fired = TriggerEngine.New(), {}
		engine.Register({
			id = "f.lua:1",
			filename = "f.lua",
			order = 1,
			condition = { inputs = { "UnitFinished" }, evaluate = function() return true end },
			effects = { { execute = function() fired[#fired + 1] = true end } },
			once = true,
			delayFrames = 30,
		})
		-- No OnEvent at all: an event-only trigger would never come due.
		engine.Evaluate({ frame = 0 })
		engine.Evaluate({ frame = 30 })
		assert.are.equal(1, #fired)
	end)

	it("carries its countdowns in the save pile, and tolerates a checkpoint without them", function()
		local engine = TriggerEngine.New()
		assert.is_table(engine.GetState().heldSince)
		engine.SetState({ fired = {} })
		assert.is_table(engine.GetState().heldSince, "an older checkpoint predates delays")
	end)

	it("drops a countdown when its file unregisters", function()
		local engine, fired = TriggerEngine.New(), {}
		delayed(engine, 90, function() return true end, fired)
		engine.Evaluate({ frame = 0 })
		assert.is_not_nil(engine.GetState().heldSince["f.lua:1"])
		engine.UnregisterFile("f.lua")
		assert.is_nil(engine.GetState().heldSince["f.lua:1"])
	end)
end)
