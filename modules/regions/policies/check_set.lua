local ModuleHandler = require("modules/module_handler")
local Modules = require("modules/enums").Modules
local Policy = require("modules/policy")
local Problems = require("modules/regions/lib/problems")

---@class RegionProblem
---@field message string
---@field region Region|nil
---@field name string|nil
---@field at { x: number, z: number }|nil

---@class RegionSetContext<R>
---@field type RegionType
---@field regions R[]
---@field names string[]
---@field map RegionMap
---@field problems RegionProblem[]

---@class (partial) RegionMap

---@class RegionSetPolicy: PolicySteps<RegionSetContext<Region>, RegionSetContext<Region>>
---@field Each "Each"

---@type RegionSetPolicy
local CheckSet = {
	Each = "Each",
}
Policy.Fold(CheckSet)

Policies.On(CheckSet).Apply(CheckSet.Each, function(ctx)
	---@type RegionsContract
	local Regions = ModuleHandler.Contract(Modules.Regions)
	local names = {} ---@type table<Region, string>
	for i, region in ipairs(ctx.regions) do
		names[region] = ctx.names[i]
	end
	for i, region in ipairs(ctx.regions) do
		---@type RegionCheckContext<Region>
		local one = { type = ctx.type, region = region, siblings = ctx.regions, names = names, problems = {} }
		ModuleHandler.Evaluate(Regions.Check, one)
		for _, problem in ipairs(one.problems) do
			Problems.OfRegion(ctx, i, problem.message, problem.at)
		end
	end
end)

---@class (partial) RegionsContract
local Contract = {}
Contract.CheckSet = CheckSet

return Contract
