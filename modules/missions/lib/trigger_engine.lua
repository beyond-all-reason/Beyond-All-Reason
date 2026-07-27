--- Mission trigger engine: holds registered triggers, evaluates their
--- conditions on the caller's cadence, runs effects. Pure Lua — no Spring —
--- so it specs under busted.
---
--- State discipline (the savegame rule, enforced from commit one): trigger
--- progress — fired flags — lives in the engine's plain `state` table, never
--- in closures. Definitions are the source pile; `state` is the save pile.
---
--- Conditions declare their inputs (mission_authoring_dsl.md): the engine
--- indexes input -> watching triggers at Register; OnEvent marks watchers
--- dirty; the evaluation cadence processes dirty triggers plus pollers
--- (conditions with nil inputs). The watcher index and dirty flags are
--- DERIVED — rebuilt from source at load, never serialized.

local TriggerEngine = {}

---@class MissionTriggerEngine
---@field Register fun(descriptor: TriggerDescriptor)
---@field UnregisterFile fun(filename: string): integer removed count
---@field OnEvent fun(name: MissionEventName) mark the input's watchers dirty (the mission bus entry point)
---@field WatchedInputs fun(): table<MissionEventName, boolean> input names some registered trigger watches
---@field Evaluate fun(ctx: MissionContext)
---@field Triggers fun(): TriggerDescriptor[] registration order, read-only by convention
---@field GetState fun(): TriggerEngineState the serializable progress pile
---@field SetState fun(state: TriggerEngineState) reapply saved progress over reloaded definitions

---@return MissionTriggerEngine
function TriggerEngine.New()
	local triggers = {} ---@type TriggerDescriptor[]
	local state = { fired = {} } ---@type TriggerEngineState
	-- Derived, never serialized: input name -> { [id] = true } watchers;
	-- poller ids (nil-inputs conditions); ids awaiting evaluation.
	local watchers = {} ---@type table<string, table<string, boolean>>
	local pollers = {} ---@type table<string, boolean>
	local dirty = {} ---@type table<string, boolean>

	local engine = {}

	---@param descriptor TriggerDescriptor
	engine.Register = function(descriptor)
		assert(type(descriptor.id) == "string", "trigger descriptor needs an id")
		assert(type(descriptor.condition) == "table" and type(descriptor.condition.evaluate) == "function",
			descriptor.id .. ": condition must have an evaluate function")
		assert(type(descriptor.effects) == "table" and #descriptor.effects > 0,
			descriptor.id .. ": descriptor needs a non-empty effects list")
		for _, effect in ipairs(descriptor.effects) do
			assert(type(effect) == "table" and type(effect.execute) == "function",
				descriptor.id .. ": every effect must have an execute function")
		end
		for _, existing in ipairs(triggers) do
			if existing.id == descriptor.id then
				error("duplicate trigger id: " .. descriptor.id)
			end
		end
		triggers[#triggers + 1] = descriptor
		local inputs = descriptor.condition.inputs
		if inputs == nil then
			pollers[descriptor.id] = true
		else
			for _, input in ipairs(inputs) do
				watchers[input] = watchers[input] or {}
				watchers[input][descriptor.id] = true
			end
		end
		-- A trigger armed mid-game evaluates once immediately, whatever its
		-- inputs — its condition may already hold.
		dirty[descriptor.id] = true
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
				pollers[trigger.id] = nil
				dirty[trigger.id] = nil
				for _, ids in pairs(watchers) do
					ids[trigger.id] = nil
				end
			else
				kept[#kept + 1] = trigger
			end
		end
		for input, ids in pairs(watchers) do
			if next(ids) == nil then
				watchers[input] = nil
			end
		end
		triggers = kept
		return removed
	end

	---An event on the mission bus: engine callins and module events are the
	---same kind of string here. Marks the input's watchers for evaluation on
	---the next cadence.
	---@param name MissionEventName
	engine.OnEvent = function(name)
		for id in pairs(watchers[name] or {}) do
			dirty[id] = true
		end
	end

	---@return table<string, boolean>
	engine.WatchedInputs = function()
		local out = {}
		for input in pairs(watchers) do
			out[input] = true
		end
		return out
	end

	---@param ctx MissionContext
	engine.Evaluate = function(ctx)
		for _, trigger in ipairs(triggers) do
			local id = trigger.id
			if pollers[id] or dirty[id] then
				dirty[id] = nil
				if not (trigger.once and state.fired[id]) and trigger.condition.evaluate(ctx) then
					state.fired[id] = true
					for _, effect in ipairs(trigger.effects) do
						effect.execute(ctx)
					end
				end
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
