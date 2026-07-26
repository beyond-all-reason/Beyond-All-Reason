--- Fluent builder that emits PolicyDescriptors — no runtime of its own.
---
--- The canonical policy format is the category file (see types/modules.lua):
--- modules/<name>/policies/<category>.lua registers an ordered PolicyDescriptor[]
--- and returns nothing. Pipeline() is how those files read — gates in declaration
--- order, one terminal compute — and what it hands the loader is a plain
--- descriptor list, byte-for-byte equivalent to writing the tables by hand:
---
---   Policies.Pipeline()
---       .Gate("SharingEnabled", function(ctx, resourceType) ... end)
---       .Compute("ComputeResourceTransfer", function(ctx, resourceType) ... end)
---       .Register()
---
--- Register() is the terminal for category files. Build() returns the descriptor
--- list instead, for programmatic pipelines and specs.
---
--- Dot-only closure chain, no metatables — the same surface every builder in
--- the tree speaks, and the synced-sandbox-safe one.

local PolicyBuilder = {}

---@class PolicyPipeline
---@field Gate fun(name: string, evaluate: function): PolicyPipeline
---@field Compute fun(name: string, evaluate: function): PolicyPipeline
---@field Build fun(): PolicyDescriptor[]
---@field Register fun()
---@field _sink (fun(stages: PolicyDescriptor[]))|nil bound by the loader's Policies facade

---One ordered pipeline per category file. Order is declaration order — the
---framework evaluates stages top to bottom, first result wins.
---Category is NOT an argument: the pipeline's identity is its filename
---(policies/<category>.lua) and ModuleHandler.LoadPolicies stamps it — one
---source of truth, no magic strings to drift.
---@return PolicyPipeline
function PolicyBuilder.Pipeline()
	local stages = {} ---@type PolicyDescriptor[]
	local computed = false
	local chain = {}

	---A gate: return a result to end evaluation (usually a deny), nil to pass.
	---@param name string
	---@param evaluate fun(...): any
	---@return PolicyPipeline
	chain.Gate = function(name, evaluate)
		assert(not computed, "PolicyPipeline: Gate() after Compute() — the terminal must be last")
		stages[#stages + 1] = {
			name = name,
			evaluate = evaluate,
		}
		return chain
	end

	---The terminal: always returns a result. Exactly one, and last.
	---@param name string
	---@param evaluate fun(...): any
	---@return PolicyPipeline
	chain.Compute = function(name, evaluate)
		assert(not computed, "PolicyPipeline: only one Compute() per pipeline")
		computed = true
		stages[#stages + 1] = {
			name = name,
			evaluate = evaluate,
		}
		return chain
	end

	---@return PolicyDescriptor[]
	chain.Build = function()
		assert(computed, "PolicyPipeline: a pipeline needs a terminal Compute()")
		return stages
	end

	---Terminal for policies/<category>.lua files: hand the built stage list to
	---the loader's sink (injected by ModuleHandler.LoadPolicies). Registration
	---style, one idiom framework-wide: files register, they do not return.
	chain.Register = function()
		if chain._sink == nil then
			error(
				"PolicyPipeline.Register() outside a policies/ loader bracket — use .Build() for programmatic pipelines"
			)
		end
		chain._sink(chain.Build())
	end

	return chain
end

return PolicyBuilder
