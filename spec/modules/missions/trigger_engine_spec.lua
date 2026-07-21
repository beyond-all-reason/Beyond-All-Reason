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
