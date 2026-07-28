local Policy = require("modules/policy")

-- What redistribution does with one team's excess: it goes to the team's allies, untaxed, unless a module says the
-- team shares nothing (its excess is wasted) or taxes it
--
---@class EconomyTeamContext: PolicyContext
---@field teamId integer
---@field springRepo Spring

---@class EconomyDistributionFacts: PolicyFacts<EconomyTeamContext>
---@field Shares "shares" whether the team's excess reaches its allies at all
---@field TaxRate "taxRate"

---@type EconomyDistributionFacts
local Distribution = {
	Shares = "shares",
	TaxRate = "taxRate",
}
Policy.Facts(Distribution)

Policies.For(Distribution)
	.Default(Distribution.Shares, function()
		return true
	end)
	.Default(Distribution.TaxRate, function()
		return 0
	end)

---@class (partial) EconomyContract
local Contract = {}
Contract.Distribution = Distribution

return Contract
