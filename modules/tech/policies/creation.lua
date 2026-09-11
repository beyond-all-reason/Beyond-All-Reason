local ConstructionContract = VFS.Include("modules/construction/contract.lua") ---@type ConstructionContract
local Contract = VFS.Include("modules/tech/contract.lua") ---@type TechContract

Policies.On(ConstructionContract.CreationFacts)
	.Provide(ConstructionContract.CreationFacts.Tier, function(ctx, springRepo)
		local raw = (springRepo or Spring).GetTeamRulesParam(ctx.teamID, "tech_level")
		if raw == nil then
			return nil
		end
		return tonumber(raw) or 1
	end)

Policies.On(ConstructionContract.Creation).Unless(Contract.Creation.BelowTier, function(ctx)
	if ctx.tier == nil or not ctx.unitDef.isFactory then
		return false
	end
	local required = tonumber(ctx.unitDef.customParams and ctx.unitDef.customParams.techlevel) or 1
	return required >= 2 and ctx.tier < required
end)
