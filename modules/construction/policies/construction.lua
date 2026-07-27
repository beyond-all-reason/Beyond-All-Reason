local Contract = VFS.Include("modules/construction/contract.lua") ---@type ConstructionContract
local assist = Contract.Assist
local reclaim = Contract.Reclaim
local resurrect = Contract.Resurrect
local build = Contract.Build
local placement = Contract.Placement

Policies.Pipeline(assist)
	.Unless(assist.AlliedAssistDisabled, function(ctx)
		return not ctx.assistEnabled and ctx.allied and (not ctx.targetComplete or ctx.targetIsBuilder)
	end)
	.Select(assist.Allowed, function()
		return true
	end)

Policies.Pipeline(reclaim)
	.Unless(reclaim.AlliedReclaimDisabled, function(ctx)
		return not ctx.reclaimEnabled and ctx.allied and (ctx.command == "reclaim" or ctx.targetCanReclaim)
	end)
	.Select(reclaim.Allowed, function()
		return true
	end)

Policies.Pipeline(resurrect)
	.Unless(resurrect.PartialResurrectionDisabled, function(ctx)
		return not ctx.partialAllowed
	end)
	.Select(resurrect.Allowed, function()
		return true
	end)

Policies.Pipeline(build)
	.Unless(build.BuilderDelayed, function(ctx)
		return ctx.delayed
	end)
	.Select(build.Allowed, function()
		return true
	end)

Policies.Pipeline(placement)
	.Unless(placement.AlliedExtractorOccupied, function(ctx)
		return ctx.extractor ~= nil and ctx.alliedExtractorNearby and not ctx.utilitySharing
	end)
	.Select(placement.Allowed, function()
		return true
	end)
