--- Mission trigger engine: holds registered triggers, evaluates their
--- conditions on the caller's cadence, runs effects. Pure Lua — no Spring —
--- so it specs under busted.
---
--- State discipline (the savegame rule, enforced from commit one): trigger
--- progress — fired flags — lives in the engine's plain `state` table, never
--- in closures. Definitions are the source pile; `state` is the save pile.

local TriggerEngine = {}

---@class MissionTriggerEngine
---@field Register fun(descriptor: TriggerDescriptor)
---@field UnregisterFile fun(filename: string): integer removed count
---@field Evaluate fun(ctx: MissionContext)
---@field Triggers fun(): TriggerDescriptor[] registration order, read-only by convention
---@field GetState fun(): TriggerEngineState the serializable progress pile
---@field SetState fun(state: TriggerEngineState) reapply saved progress over reloaded definitions

---@return MissionTriggerEngine
function TriggerEngine.New()
	local triggers = {} ---@type TriggerDescriptor[]
	local state = { fired = {} } ---@type TriggerEngineState

	local engine = {}

	---@param descriptor TriggerDescriptor
	engine.Register = function(descriptor)
		assert(type(descriptor.id) == "string", "trigger descriptor needs an id")
		assert(type(descriptor.condition) == "table" and type(descriptor.condition.evaluate) == "function",
			descriptor.id .. ": condition must have an evaluate function")
		assert(type(descriptor.effect) == "function", descriptor.id .. ": effect must be a function")
		for _, existing in ipairs(triggers) do
			if existing.id == descriptor.id then
				error("duplicate trigger id: " .. descriptor.id)
			end
		end
		triggers[#triggers + 1] = descriptor
	end

	---Remove every trigger registered from `filename`, and its progress —
	---the hot-reload half of unregister-by-identity.
	---@param filename string
	---@return integer removed
	engine.UnregisterFile = function(filename)
		local kept, removed = {}, 0
		for _, trigger in ipairs(triggers) do
			if trigger.filename == filename then
				removed = removed + 1
				state.fired[trigger.id] = nil
			else
				kept[#kept + 1] = trigger
			end
		end
		triggers = kept
		return removed
	end

	---@param ctx MissionContext
	engine.Evaluate = function(ctx)
		for _, trigger in ipairs(triggers) do
			if not (trigger.once and state.fired[trigger.id]) and trigger.condition.evaluate(ctx) then
				state.fired[trigger.id] = true
				trigger.effect(ctx)
			end
		end
	end

	---@return TriggerDescriptor[]
	engine.Triggers = function()
		return triggers
	end

	---@return TriggerEngineState
	engine.GetState = function()
		return state
	end

	---@param saved TriggerEngineState
	engine.SetState = function(saved)
		state = saved
	end

	return engine
end

return TriggerEngine
