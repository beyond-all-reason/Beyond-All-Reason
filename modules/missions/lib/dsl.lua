--- The mission authoring DSL builder: chain -> descriptor -> sink, the
--- policy_builder idiom. Pure Lua, no Spring.
---
--- The surface is dot-only, closure-free, and terminator-free:
---
---     When(Team.Player.Has(UnitDef("armpw"), 3))
---         .Do(Objective("build_pawns").Complete())
---
--- No colon methods, no metatables, no function bodies, no Register. A
--- statement's identity is the chain object the When call creates — every
--- .When/.Do returns it, so Lua's own parser attaches continuation lines and
--- separates statements (they start with the name `When`; whitespace was
--- never the delimiter). Repeated .When AND-composes. The loader calls
--- Finalize after including the file: every chain registers in creation
--- order, and a chain without a Do is a load error naming the file — the
--- transaction check Register used to provide, without the ceremony.
---
--- Trigger identity = filename + declaration order (When-call order),
--- stamped at Finalize — the key hot reload unregisters by.

local DSL = {}

---Build one trigger file's authoring surface: the `When` chain entry the
---loader injects, and the Finalize the loader calls after the include.
---@param filename string mission-relative path, e.g. "triggers/win.lua"
---@param sink fun(descriptor: TriggerDescriptor)
---@return { When: fun(condition: MissionCondition): TriggerChain, Finalize: fun(): integer }
function DSL.ForFile(filename, sink)
	local chains = {} ---@type table[] chain build-state, in When-call (declaration) order
	local finalized = false

	---@param condition MissionCondition
	---@return TriggerChain
	local When = function(condition)
		assert(not finalized, filename .. ": When after Finalize — the file already loaded")
		assert(type(condition) == "table" and type(condition.evaluate) == "function",
			filename .. ": When expects a condition (a table with an evaluate function)")

		local build = {
			conditions = { condition }, ---@type MissionCondition[]
			effects = {}, ---@type MissionEffect[]
			once = true,
		}
		chains[#chains + 1] = build

		local chain = {}

		---Another condition on the same statement; all must hold (AND).
		---@param another MissionCondition
		---@return TriggerChain
		chain.When = function(another)
			assert(not finalized, filename .. ": When after Finalize — the file already loaded")
			assert(type(another) == "table" and type(another.evaluate) == "function",
				filename .. ": .When expects a condition (a table with an evaluate function)")
			build.conditions[#build.conditions + 1] = another
			return chain
		end

		---@param effect MissionEffect a lazy effect built by a named verb
		---@return TriggerChain
		chain.Do = function(effect)
			assert(not finalized, filename .. ": Do after Finalize — the file already loaded")
			assert(type(effect) == "table" and type(effect.execute) == "function",
				filename .. ": Do expects an effect (a table with an execute function) — build one with a named verb like Objective(...).Complete()")
			build.effects[#build.effects + 1] = effect
			return chain
		end

		---@param flag boolean?
		---@return TriggerChain
		chain.Once = function(flag)
			assert(not finalized, filename .. ": Once after Finalize — the file already loaded")
			build.once = flag ~= false
			return chain
		end

		return chain
	end

	---The commit point: called by the loader when the file's include
	---returns. Registers every chain in declaration order; a chain without a
	---Do is a load error here — half-finished statements cannot arm.
	---@return integer registered count
	local Finalize = function()
		assert(not finalized, filename .. ": Finalize called twice")
		finalized = true
		-- Validate before committing anything: a failed load arms nothing.
		for order, build in ipairs(chains) do
			if #build.effects == 0 then
				error(filename .. ": statement " .. order .. " has no Do — every trigger needs at least one effect")
			end
		end
		for order, build in ipairs(chains) do
			local combined = build.conditions[1]
			if #build.conditions > 1 then
				-- AND-composition. Inputs compose as the UNION of the parts';
				-- any poll-only part (nil inputs) makes the whole trigger
				-- poll. The closure captures the conditions list —
				-- configuration, never progress (the savegame rule holds).
				local conditions = build.conditions
				local union = {}
				local seen = {}
				for _, part in ipairs(conditions) do
					if part.inputs == nil then
						union = nil
						break
					end
					for _, input in ipairs(part.inputs) do
						if not seen[input] then
							seen[input] = true
							union[#union + 1] = input
						end
					end
				end
				combined = {
					inputs = union,
					---@param ctx MissionContext
					evaluate = function(ctx)
						for _, part in ipairs(conditions) do
							if not part.evaluate(ctx) then
								return false
							end
						end
						return true
					end,
				}
			end
			sink({
				id = filename .. ":" .. order,
				filename = filename,
				order = order,
				condition = combined,
				effects = build.effects,
				once = build.once,
			})
		end
		return #chains
	end

	return { When = When, Finalize = Finalize }
end

return DSL
