
local TriggerEngine = {}

---@class MissionTriggerEngine
---@field Register fun(descriptor: TriggerDescriptor)
---@field UnregisterFile fun(filename: string): integer removed count
---@field OnEvent fun(name: string) mark the input's watchers dirty (the mission bus entry point)
---@field WatchedInputs fun(): table<string, boolean> input names some registered trigger watches
---@field Evaluate fun(ctx: MissionContext)
---@field Triggers fun(): TriggerDescriptor[] registration order, read-only by convention
---@field GetState fun(): TriggerEngineState the serializable progress pile
---@field SetState fun(state: TriggerEngineState) reapply saved progress over reloaded definitions

---@return MissionTriggerEngine
function TriggerEngine.New()
	local triggers = {} ---@type TriggerDescriptor[]
	-- heldSince joins the save pile: a checkpoint must carry it or a reloaded
	-- mission would restart every countdown.
	local state = { fired = {}, heldSince = {}, fires = {}, lastFired = {} } ---@type TriggerEngineState
	local watchers = {} ---@type table<string, table<string, boolean>>
	local pollers = {} ---@type table<string, boolean>
	local dirty = {} ---@type table<string, boolean>

	local engine = {}

	---@param descriptor TriggerDescriptor
	engine.Register = function(descriptor)
		assert(type(descriptor.id) == "string", "trigger descriptor needs an id")
		assert(
			type(descriptor.condition) == "table" and type(descriptor.condition.evaluate) == "function",
			descriptor.id .. ": condition must have an evaluate function"
		)
		assert(
			type(descriptor.effects) == "table" and #descriptor.effects > 0,
			descriptor.id .. ": descriptor needs a non-empty effects list"
		)
		for _, effect in ipairs(descriptor.effects) do
			assert(
				type(effect) == "table" and type(effect.execute) == "function",
				descriptor.id .. ": every effect must have an execute function"
			)
		end
		for _, existing in ipairs(triggers) do
			if existing.id == descriptor.id then
				error("duplicate trigger id: " .. descriptor.id)
			end
		end
		triggers[#triggers + 1] = descriptor
		local inputs = descriptor.condition.inputs
		-- Events say the answer CHANGED; a countdown comes due on a frame when nothing
		-- changed, and nothing announces a repeating trigger's floor elapsing, so both poll.
		if inputs == nil or (descriptor.delayFrames or 0) > 0 or descriptor.limit ~= 1 then
			pollers[descriptor.id] = true
		end
		if inputs ~= nil then
			for _, input in ipairs(inputs) do
				watchers[input] = watchers[input] or {}
				watchers[input][descriptor.id] = true
			end
		end
		-- Armed mid-game, its condition may already hold.
		dirty[descriptor.id] = true
	end

	---@param filename string
	---@return integer removed
	engine.UnregisterFile = function(filename)
		local kept, removed = {}, 0
		for _, trigger in ipairs(triggers) do
			if trigger.filename == filename then
				removed = removed + 1
				state.fired[trigger.id] = nil
				state.heldSince[trigger.id] = nil
				state.fires[trigger.id] = nil
				state.lastFired[trigger.id] = nil
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

	---@param name string a module's Events enum member, or a forwarded callin
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
				local limit = trigger.limit
				local spent = limit ~= nil and (state.fires[id] or 0) >= limit
				local cooling = (trigger.cooldownFrames or 0) > 0
					and state.lastFired[id] ~= nil
					and ctx.frame - state.lastFired[id] < trigger.cooldownFrames
				if not spent and not cooling then
					local holds = trigger.condition.evaluate(ctx)
					local delay = trigger.delayFrames or 0
					if not holds then
						-- The countdown measures a CONTINUOUS hold, so losing
						-- the condition puts the clock back to zero.
						state.heldSince[id] = nil
					elseif delay == 0 then
						engine.Fire(trigger, ctx)
					else
						if state.heldSince[id] == nil then
							state.heldSince[id] = ctx.frame
						end
						if ctx.frame - state.heldSince[id] >= delay then
							-- Re-arm from the FIRE, not the next tick, or every
							-- interval gains a cadence and a repeating trigger drifts.
							state.heldSince[id] = ctx.frame
							engine.Fire(trigger, ctx)
						end
					end
				end
			end
		end
	end

	---@param trigger TriggerDescriptor
	---@param ctx MissionContext
	engine.Fire = function(trigger, ctx)
		state.fired[trigger.id] = true
		state.fires[trigger.id] = (state.fires[trigger.id] or 0) + 1
		state.lastFired[trigger.id] = ctx.frame
		for _, effect in ipairs(trigger.effects) do
			effect.execute(ctx)
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
		-- An older checkpoint predates delays and carries no countdowns.
		state.heldSince = state.heldSince or {}
		state.lastFired = state.lastFired or {}
		if state.fires == nil then
			-- Older piles knew only "fired"; a fired trigger had fired once.
			state.fires = {}
			for id in pairs(state.fired) do
				state.fires[id] = 1
			end
		end
	end

	return engine
end

return TriggerEngine
