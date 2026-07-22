--- Fluent builder that emits PolicyDescriptors — no runtime of its own.
---
--- The canonical policy format is the category file (see types/modules.lua):
--- modules/<name>/policies/<category>.lua registers an ordered PolicyDescriptor[]
--- and returns nothing. Pipeline() is how those files read — gates in declaration
--- order, one terminal compute — and what it hands the loader is a plain
--- descriptor list, byte-for-byte equivalent to writing the tables by hand:
---
---   Policies.Pipeline()
---       :Gate("SharingEnabled", function(ctx, resourceType) ... end)
---       :Compute("ComputeResourceTransfer", function(ctx, resourceType) ... end)
---       :Register()
---
--- Register() is the terminal for category files. Build() returns the descriptor
--- list instead, for programmatic pipelines and specs.

local PolicyBuilder = {}

---@class PolicyPipeline
---@field stages PolicyDescriptor[]
---@field computed boolean
---@field _sink (fun(stages: PolicyDescriptor[]))|nil bound by the loader's Policies facade
local PolicyPipeline = {}
PolicyPipeline.__index = PolicyPipeline

---One ordered pipeline per category file. Order is declaration order — the
---framework evaluates stages top to bottom, first result wins.
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

---Terminal for policies/<category>.lua files: hand the built stage list to
---the loader's sink (injected by ModuleHandler.LoadPolicies). Registration
---style, one idiom framework-wide: files register, they do not return.
function PolicyPipeline:Register()
	if self._sink == nil then
		error("PolicyPipeline:Register() outside a policies/ loader bracket — use :Build() for programmatic pipelines")
	end
	self._sink(self:Build())
end

return PolicyBuilder
