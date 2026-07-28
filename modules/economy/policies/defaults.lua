local Contract = VFS.Include("modules/economy/contract.lua") ---@type EconomyContract

-- What economy's slots mean when no live module fills them: no tax, and a
-- tick's results published as solved.
Policies.Enrich(Contract.Distribution).Default(Contract.Distribution.TaxRate, function()
	return 0
end)

Policies.Enrich(Contract.Redistribution).Default(Contract.Redistribution.Results, function(ctx)
	return ctx.results
end)
