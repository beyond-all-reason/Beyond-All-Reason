local PolicyBuilder = VFS.Include("modules/policy_builder.lua")
local Modules = VFS.Include("modules/enums.lua").Modules

---@class EconomyTeamContext one team, asked what redistribution costs it
---@field teamId integer
---@field springRepo Spring

---@class EconomyDistributionFacts: PolicyFacts<EconomyTeamContext>
---@field TaxRate string

---@type EconomyDistributionFacts
local Distribution = {
	TaxRate = "taxRate",
}

---@class EconomyRedistributionContext one cadence tick's results, before they are published
---@field results EconomyTeamResult[]

---@class EconomyRedistributionFacts: PolicyFacts<EconomyRedistributionContext>
---@field Results string

---@type EconomyRedistributionFacts
local Redistribution = {
	Results = "results",
}

---@class EconomyContract
---@field Distribution EconomyDistributionFacts
---@field Redistribution EconomyRedistributionFacts

return PolicyBuilder.Contract(Modules.Economy, {
	Distribution = PolicyBuilder.Facts(Distribution),
	Redistribution = PolicyBuilder.Facts(Redistribution),
})
