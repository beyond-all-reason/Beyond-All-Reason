--- The mission authoring DSL builder: chain -> descriptor -> sink, the
--- policy_builder idiom. Pure Lua, no Spring.
---
--- The surface is dot-only: every chain step is a plain call with parens —
--- `T.When(cond).Then(fn).Register()` — no colon methods, no metatables.
--- Chains are closures over a local descriptor, so the same file loads in the
--- synced sandbox (which strips rawset) and in busted unchanged.
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

		local effect = nil ---@type nil|fun(ctx: MissionContext)
		local once = true
		local registered = false

		local chain = {}

		---@param fn fun(ctx: MissionContext)
		---@return TriggerChain
		chain.Then = function(fn)
			assert(type(fn) == "function", filename .. ": Then expects a function")
			assert(effect == nil, filename .. ": duplicate Then on one trigger")
			effect = fn
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
			assert(effect ~= nil, filename .. ": trigger needs a Then before Register")
			registered = true
			order = order + 1
			sink({
				id = filename .. ":" .. order,
				filename = filename,
				order = order,
				condition = condition,
				effect = effect,
				once = once,
			})
		end

		return chain
	end

	return T
end

return DSL
