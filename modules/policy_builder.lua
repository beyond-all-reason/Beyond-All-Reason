--- Fluent builders that emit PolicyDescriptors — no runtime of their own.
---
--- The canonical policy format is the category file (see modules/types/modules.lua):
--- modules/<name>/policies/<category>.lua returns an ordered PolicyDescriptor[].
--- Pipeline() is how those files read — gates in declaration order, one terminal
--- compute — and what it Build()s is a plain descriptor list, byte-for-byte
--- equivalent to writing the tables by hand:
---
---   return Policies.Pipeline("resource")
---       :Gate("SharingEnabled", function(ctx, resourceType) ... end)
---       :Compute("ComputeResourceTransfer", function(ctx, resourceType) ... end)
---       :Build()
---
--- PolicyBuilder.new() is single-descriptor sugar for modders composing one
--- policy at a time (predicates + terminal).

---@class PolicyBuilder
---@field name string
---@field categoryName string|nil
---@field predicates (fun(...): boolean)[]
local PolicyBuilder = {}
PolicyBuilder.__index = PolicyBuilder

---@param name string
---@return PolicyBuilder
function PolicyBuilder.new(name)
	return setmetatable({
		name = name,
		categoryName = nil,
		predicates = {},
	}, PolicyBuilder)
end

---@param category string
---@return PolicyBuilder
function PolicyBuilder:Category(category)
	self.categoryName = category
	return self
end

---Add a predicate; evaluate returns nil (pass) unless every predicate holds.
---@param predicate fun(...): boolean receives evaluate's arguments (ctx, ...)
---@return PolicyBuilder
function PolicyBuilder:When(predicate)
	self.predicates[#self.predicates + 1] = predicate
	return self
end

---Sugar: only when sender and receiver are allied (ctx.areAlliedTeams).
---@return PolicyBuilder
function PolicyBuilder:Allied()
	return self:When(function(ctx)
		return ctx.areAlliedTeams == true
	end)
end

---Sugar: only when sender and receiver are enemies.
---@return PolicyBuilder
function PolicyBuilder:Enemy()
	return self:When(function(ctx)
		return ctx.areAlliedTeams == false
	end)
end

---Terminal: when all predicates hold, evaluation ends with handler's result.
---@param handler fun(...): any pure function producing the policy result
---@return PolicyBuilder
function PolicyBuilder:Returns(handler)
	self.handler = handler
	return self
end

---Terminal alias for deny-gates: reads as intent at the call site.
---@param makeDenyResult fun(...): any pure function producing the deny result
---@return PolicyBuilder
function PolicyBuilder:Deny(makeDenyResult)
	return self:Returns(makeDenyResult)
end

---@return PolicyDescriptor
function PolicyBuilder:Build()
	assert(self.handler, "PolicyBuilder: Returns()/Deny() must be set before Build()")
	local predicates = self.predicates
	local handler = self.handler
	---@type PolicyDescriptor
	return {
		name = self.name,
		category = self.categoryName,
		evaluate = function(...)
			for _, predicate in ipairs(predicates) do
				if not predicate(...) then
					return nil
				end
			end
			return handler(...)
		end,
	}
end

---@class PolicyPipeline
---@field category string
---@field stages PolicyDescriptor[]
---@field computed boolean
local PolicyPipeline = {}
PolicyPipeline.__index = PolicyPipeline

---One ordered pipeline per category file. Order is declaration order — the
---framework evaluates stages top to bottom, first result wins.
---@param category string
---@return PolicyPipeline
---Category is NOT an argument: the pipeline's identity is its filename
---(policies/<category>.lua) and ModuleHandler.LoadPolicies stamps it — one
---source of truth, no magic strings to drift.
function PolicyBuilder.Pipeline()
	return setmetatable({
		stages = {},
		computed = false,
	}, PolicyPipeline)
end

---A gate: return a result to end evaluation (usually a deny), nil to pass.
---@param name string
---@param evaluate fun(...): any
---@return PolicyPipeline
function PolicyPipeline:Gate(name, evaluate)
	assert(not self.computed, "PolicyPipeline: Gate() after Compute() — the terminal must be last")
	self.stages[#self.stages + 1] = {
		name = name,
		evaluate = evaluate,
	}
	return self
end

---The terminal: always returns a result. Exactly one, and last.
---@param name string
---@param evaluate fun(...): any
---@return PolicyPipeline
function PolicyPipeline:Compute(name, evaluate)
	assert(not self.computed, "PolicyPipeline: only one Compute() per pipeline")
	self.computed = true
	self.stages[#self.stages + 1] = {
		name = name,
		evaluate = evaluate,
	}
	return self
end

---@return PolicyDescriptor[]
function PolicyPipeline:Build()
	assert(self.computed, "PolicyPipeline: a pipeline needs a terminal Compute()")
	return self.stages
end

return PolicyBuilder
