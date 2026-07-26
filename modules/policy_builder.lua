--- Dot-only closure chain, no metatables — the same surface every builder in
--- the tree speaks, and the synced-sandbox-safe one.

local PolicyBuilder = {}

---@class PolicyPipeline
---@field Gate fun(name: string, evaluate: function): PolicyPipeline
---@field Compute fun(name: string, evaluate: function): PolicyPipeline
---@field Build fun(): PolicyDescriptor[]
---@field Register fun()
---@field _sink (fun(stages: PolicyDescriptor[]))|nil bound by the loader's Policies facade

---Category is NOT an argument: the pipeline's identity is its filename
---(policies/<category>.lua) and ModuleHandler.LoadPolicies stamps it — one
---source of truth, no magic strings to drift.
---@return PolicyPipeline
function PolicyBuilder.Pipeline()
	local stages = {} ---@type PolicyDescriptor[]
	local computed = false
	local chain = {}

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
