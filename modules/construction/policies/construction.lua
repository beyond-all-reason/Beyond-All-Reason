local Contract = VFS.Include("modules/construction/contract.lua") ---@type ConstructionContract
local assist = Contract.Assist
local reclaim = Contract.Reclaim
local resurrect = Contract.Resurrect
local build = Contract.Build
local placement = Contract.Placement
local creation = Contract.Creation

Policies.On(assist)
	.Unless(assist.AlliedAssistDisabled, function(ctx)
		return not ctx.assistEnabled and ctx.allied and (not ctx.targetComplete or ctx.targetIsBuilder)
	end)
	.Answer(assist.Allowed, function()
		return true
	end)

Policies.On(reclaim)
	.Unless(reclaim.AlliedReclaimDisabled, function(ctx)
		return not ctx.reclaimEnabled and ctx.allied and (ctx.command == "reclaim" or ctx.targetCanReclaim)
	end)
	.Answer(reclaim.Allowed, function()
		return true
	end)

Policies.On(resurrect)
	.Unless(resurrect.PartialResurrectionDisabled, function(ctx)
		return not ctx.partialAllowed
	end)
	.Answer(resurrect.Allowed, function()
		return true
	end)

Policies.On(build)
	.Unless(build.BuilderDelayed, function(ctx)
		return ctx.delayed
	end)
	.Answer(build.Allowed, function()
		return true
	end)

Policies.On(placement)
	.Unless(placement.AlliedExtractorOccupied, function(ctx)
		return ctx.extractor ~= nil and ctx.alliedExtractorNearby and not ctx.utilitySharing
	end)
	.Answer(placement.Allowed, function()
		return true
	end)

Policies.On(creation).Answer(creation.Allowed, function()
	return true
end)

Policies.On(Contract.CreationFacts).Default(Contract.CreationFacts.Tier, function()
	return nil
end)
