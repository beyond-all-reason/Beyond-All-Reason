local Policy = require("modules/policy")

-- May a builder put this step of work in: on a unit, or on a feature (reclaim, resurrect)
--
---@class ConstructionBuildContext
---@field builderID integer
---@field builderTeam integer
---@field delayed boolean
---@field unitID integer|nil
---@field unitDefID integer|nil
---@field featureID integer|nil
---@field part number the step's share of the whole; negative for reclaim

---@class ConstructionBuildPolicy: PolicySteps<ConstructionBuildContext, boolean>
---@field BuilderDelayed "BuilderDelayed"
---@field Allowed "Allowed"

---@type ConstructionBuildPolicy
local Build = {
	BuilderDelayed = "BuilderDelayed",
	Allowed = "Allowed",
}
Policy.Single(Build)

Policies.On(Build)
	.Unless(Build.BuilderDelayed, function(ctx)
		return ctx.delayed
	end)
	.Answer(Build.Allowed, function()
		return true
	end)

---@class (partial) ConstructionContract
local Contract = {}
Contract.Build = Build

return Contract
