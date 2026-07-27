local Policy = require("modules/policy")

-- May a builder help an ally's unit along
--
---@class ConstructionAssistContext
---@field allied boolean
---@field targetComplete boolean
---@field targetIsBuilder boolean
---@field assistEnabled boolean

---@class ConstructionAssistPolicy: PolicySteps<ConstructionAssistContext, boolean>
---@field AlliedAssistDisabled "AlliedAssistDisabled"
---@field Allowed "Allowed"

---@type ConstructionAssistPolicy
local Assist = {
	AlliedAssistDisabled = "AlliedAssistDisabled",
	Allowed = "Allowed",
}
Policy.Single(Assist)

Policies.On(Assist)
	.Unless(Assist.AlliedAssistDisabled, function(ctx)
		return not ctx.assistEnabled and ctx.allied and (not ctx.targetComplete or ctx.targetIsBuilder)
	end)
	.Answer(Assist.Allowed, function()
		return true
	end)

---@class (partial) ConstructionContract
local Contract = {}
Contract.Assist = Assist

return Contract
