local ManualShareLedger = require("modules/transfer/economy/manual_share_ledger")
local Modules = require("modules/enums").Modules
local SharedConfig = require("modules/transfer/economy/shared_config")

---@type EconomyContract
local Economy = Policies.Contract(Modules.Economy)
local distribution = Economy.Distribution
local redistribution = Economy.Redistribution

-- What transfer tells economy: whether a team's excess reaches its allies at all, and at what tax rate, are the
-- transfer mode's to say; a mode that denies resource sharing denies overflow too. Its manual shares are folded into
-- the tick.
--

Policies.For(distribution)
	.Provide(distribution.Shares, function(ctx)
		return SharedConfig.isResourceSharingEnabled(ctx.springRepo)
	end)
	.Provide(distribution.TaxRate, function(ctx)
		return SharedConfig.getTeamTaxRate(ctx.springRepo, ctx.teamId)
	end)

Policies.For(redistribution).Provide(redistribution.Results, function(ctx)
	return ManualShareLedger.FoldInto(ctx.results)
end)
