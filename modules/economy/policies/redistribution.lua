local Policy = require("modules/policy")

-- One tick's results, before they are published: a module may fold its own transfers in
--
---@class EconomyTeamResult
---@field teamId integer
---@field resourceType ResourceName
---@field delta number net change against the snapshot
---@field sent number
---@field received number
---@field excess number wasted overflow this tick

---@class EconomyRedistributionContext: PolicyContext
---@field results EconomyTeamResult[]

---@class EconomyRedistributionFacts: PolicyFacts<EconomyRedistributionContext>
---@field Results "results"

---@type EconomyRedistributionFacts
local Redistribution = {
	Results = "results",
}
Policy.Facts(Redistribution)

---@class (partial) EconomyContract
local Contract = {}
Contract.Redistribution = Redistribution

return Contract
