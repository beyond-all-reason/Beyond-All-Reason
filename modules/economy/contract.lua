local PolicyBuilder = VFS.Include("modules/policy_builder.lua")

---@class EconomyTeamContext one team, asked what redistribution costs it
---@field teamId integer
---@field springRepo Spring

---@class EconomyDistributionToken: PolicyContextToken<EconomyTeamContext>
---@field TaxRate string

---@type EconomyDistributionToken
local Distribution = {
	TaxRate = "taxRate",
}

---@class EconomyRedistributionContext one cadence tick's results, before they are published
---@field results EconomyTeamResult[]

---@class EconomyRedistributionToken: PolicyContextToken<EconomyRedistributionContext>
---@field Results string

---@type EconomyRedistributionToken
local Redistribution = {
	Results = "results",
}

---@class EconomyContract
---@field Distribution EconomyDistributionToken
---@field Redistribution EconomyRedistributionToken

return PolicyBuilder.Contract("economy", {
	Distribution = PolicyBuilder.Context(Distribution),
	Redistribution = PolicyBuilder.Context(Redistribution),
})
