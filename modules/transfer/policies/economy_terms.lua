local EconomyContract = VFS.Include("modules/economy/contract.lua") ---@type EconomyContract
local distribution = EconomyContract.Distribution
local redistribution = EconomyContract.Redistribution
local SharedConfig = VFS.Include("modules/transfer/economy/shared_config.lua")
local ManualShareLedger = VFS.Include("modules/transfer/economy/manual_share_ledger.lua")

Policies.On(distribution).Provide(distribution.TaxRate, function(ctx)
	return SharedConfig.getTeamTaxRate(ctx.springRepo, ctx.teamId)
end)

Policies.On(redistribution).Provide(redistribution.Results, function(ctx)
	return ManualShareLedger.FoldInto(ctx.results)
end)
