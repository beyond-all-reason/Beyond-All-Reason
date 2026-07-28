local ManualShareLedger = require("modules/transfer/economy/manual_share_ledger")
local Modules = require("modules/enums").Modules
local SharedConfig = require("modules/transfer/economy/shared_config")

---@type EconomyContract
local Economy = Policies.Contract(Modules.Economy)
local distribution = Economy.Distribution
local redistribution = Economy.Redistribution

-- What transfer tells economy: a team's tax rate is transfer's, and its manual shares are folded into the tick
--

Policies.On(distribution).Provide(distribution.TaxRate, function(ctx)
	return SharedConfig.getTeamTaxRate(ctx.springRepo, ctx.teamId)
end)

Policies.On(redistribution).Provide(redistribution.Results, function(ctx)
	return ManualShareLedger.FoldInto(ctx.results)
end)
