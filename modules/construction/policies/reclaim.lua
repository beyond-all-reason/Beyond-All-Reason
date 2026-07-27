local Policy = require("modules/policy")

-- May a builder reclaim an ally's unit, or guard something that would
--
---@class ConstructionReclaimContext
---@field allied boolean
---@field command "reclaim"|"guard"
---@field targetCanReclaim boolean
---@field reclaimEnabled boolean

---@class ConstructionReclaimPolicy: PolicySteps<ConstructionReclaimContext, boolean>
---@field AlliedReclaimDisabled "AlliedReclaimDisabled"
---@field Allowed "Allowed"

---@type ConstructionReclaimPolicy
local Reclaim = {
	AlliedReclaimDisabled = "AlliedReclaimDisabled",
	Allowed = "Allowed",
}
Policy.Single(Reclaim)

Policies.On(Reclaim)
	.Unless(Reclaim.AlliedReclaimDisabled, function(ctx)
		return not ctx.reclaimEnabled and ctx.allied and (ctx.command == "reclaim" or ctx.targetCanReclaim)
	end)
	.Answer(Reclaim.Allowed, function()
		return true
	end)

---@class (partial) ConstructionContract
local Contract = {}
Contract.Reclaim = Reclaim

return Contract
