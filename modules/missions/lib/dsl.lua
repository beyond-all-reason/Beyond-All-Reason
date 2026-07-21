--- The mission authoring DSL builder: chain -> descriptor -> sink, the
--- policy_builder idiom. Pure Lua, no Spring.
---
--- The surface is dot-only AND closure-free: every chain step is a plain call
--- with parens — `T.When(cond).Do(effect).Register()` — no colon methods, no
--- metatables, and no function bodies in mission files. Effects are lazy
--- objects built by named verbs (Objective("x").Complete()); the engine
--- executes them when the condition fires. Chains are closures over a local
--- descriptor internally, so the same file loads in the synced sandbox (which
--- strips rawset) and in busted unchanged.
---
--- Trigger identity = filename + declaration order, stamped at Register —
--- the key hot reload unregisters by.

local DSL = {}

---Build the `T` injected into one trigger file's environment. Declaration
---order is per-file: the Nth Register call in the file is trigger N.
---@param filename string mission-relative path, e.g. "triggers/win.lua"
---@param sink fun(descriptor: TriggerDescriptor)
---@return TriggerDSL
function DSL.ForFile(filename, sink)
	local order = 0

	local T = {}

	---@param condition MissionCondition
	---@return TriggerChain
	T.When = function(condition)
		assert(type(condition) == "table" and type(condition.evaluate) == "function",
			filename .. ": T.When expects a condition (a table with an evaluate function)")

		local effects = {} ---@type MissionEffect[]
		local once = true
		local registered = false

		local chain = {}

		---@param effect MissionEffect a lazy effect built by a named verb
		---@return TriggerChain
		chain.Do = function(effect)
			assert(not registered, filename .. ": Do after Register — the trigger is already registered")
			assert(type(effect) == "table" and type(effect.execute) == "function",
				filename .. ": Do expects an effect (a table with an execute function) — build one with a named verb like Objective(...).Complete()")
			effects[#effects + 1] = effect
			return chain
		end

		---@param flag boolean?
		---@return TriggerChain
		chain.Once = function(flag)
			once = flag ~= false
			return chain
		end

		chain.Register = function()
			assert(not registered, filename .. ": trigger registered twice")
			assert(#effects > 0, filename .. ": trigger needs at least one Do before Register")
			registered = true
			order = order + 1
			sink({
				id = filename .. ":" .. order,
				filename = filename,
				order = order,
				condition = condition,
				effects = effects,
				once = once,
			})
		end

		return chain
	end

	return T
end

return DSL
