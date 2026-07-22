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
