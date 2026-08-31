
local DSL = {}

-- The fallback keeps this pure enough to spec without Spring.
local GAME_SPEED = (Game and Game.gameSpeed) or 30

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
		assert(
			type(condition) == "table" and type(condition.evaluate) == "function",
			filename .. ": When expects a condition (a table with an evaluate function)"
		)

		local build = {
			conditions = { condition }, ---@type MissionCondition[]
			effects = {}, ---@type MissionEffect[]
			limit = 1, ---@type integer|nil fires allowed; nil = unbounded
			delayFrames = 0,
			cooldownFrames = 0,
		}
		chains[#chains + 1] = build

		local chain = {}

		---@param another MissionCondition
		---@return TriggerChain
		chain.When = function(another)
			assert(not finalized, filename .. ": When after Finalize — the file already loaded")
			assert(
				type(another) == "table" and type(another.evaluate) == "function",
				filename .. ": .When expects a condition (a table with an evaluate function)"
			)
			build.conditions[#build.conditions + 1] = another
			return chain
		end

		---@param effect MissionEffect a lazy effect built by a named verb
		---@return TriggerChain
		chain.Do = function(effect)
			assert(not finalized, filename .. ": Do after Finalize — the file already loaded")
			assert(
				type(effect) == "table" and type(effect.execute) == "function",
				filename
					.. ": Do expects an effect (a table with an execute function) — build one with a named verb like Objective(...).Complete()"
			)
			build.effects[#build.effects + 1] = effect
			return chain
		end

		---@param seconds number
		---@return TriggerChain
		chain.After = function(seconds)
			assert(not finalized, filename .. ": After after Finalize — the file already loaded")
			assert(
				type(seconds) == "number" and seconds >= 0,
				filename .. ": .After expects a non-negative number of seconds"
			)
			build.delayFrames = math.floor(seconds * GAME_SPEED)
			return chain
		end

		---@param flag boolean?
		---@return TriggerChain
		chain.Once = function(flag)
			assert(not finalized, filename .. ": Once after Finalize — the file already loaded")
			build.limit = (flag ~= false) and 1 or nil
			return chain
		end

		---@param count integer
		---@return TriggerChain
		chain.Times = function(count)
			assert(not finalized, filename .. ": Times after Finalize — the file already loaded")
			assert(
				type(count) == "number" and count >= 1 and count % 1 == 0,
				filename .. ": .Times expects a whole number of fires"
			)
			build.limit = count
			return chain
		end

		---@param seconds number
		---@return TriggerChain
		chain.Every = function(seconds)
			assert(not finalized, filename .. ": Every after Finalize — the file already loaded")
			assert(
				type(seconds) == "number" and seconds > 0,
				filename .. ": .Every expects a positive number of seconds"
			)
			build.cooldownFrames = math.floor(seconds * GAME_SPEED)
			if build.limit == 1 then
				build.limit = nil
			end
			return chain
		end

		return chain
	end

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
				-- The closure captures configuration, never progress (the savegame rule).
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
				limit = build.limit,
				delayFrames = build.delayFrames,
				cooldownFrames = build.cooldownFrames,
			})
		end
		return #chains
	end

	return { When = When, Finalize = Finalize }
end

return DSL
