local Policy = require("modules/policy")

-- What redistribution costs one team: nothing, unless a module taxes it
--
---@class EconomyTeamContext: PolicyContext
---@field teamId integer
---@field springRepo Spring

---@class EconomyDistributionFacts: PolicyFacts<EconomyTeamContext>
---@field TaxRate "taxRate"

---@type EconomyDistributionFacts
local Distribution = {
	TaxRate = "taxRate",
}
Policy.Facts(Distribution)

Policies.On(Distribution).Default(Distribution.TaxRate, function()
	return 0
end)

---@class (partial) EconomyContract
local Contract = {}
Contract.Distribution = Distribution

return Contract
