local ConstructionContract = VFS.Include("modules/construction/contract.lua") ---@type ConstructionContract
local Contract = VFS.Include("modules/tech/contract.lua") ---@type TechContract

-- Tech's part in construction's creation decision: it provides the team's
-- tier as a fact, and it contributes the one guard that reads it.

-- The tier, from the team rules param the tech gadget maintains. Nil until
-- the gadget has set it, which is also the answer when no tier system runs.
Policies.On(ConstructionContract.CreationFacts)
	.Provide(ConstructionContract.CreationFacts.Tier, function(ctx, springRepo)
		local raw = (springRepo or Spring).GetTeamRulesParam(ctx.teamID, "tech_level")
		if raw == nil then
			return nil
		end
		return tonumber(raw) or 1
	end)

-- A lab whose tier the team has not reached. Passes when there is no tier.
Policies.On(ConstructionContract.Creation).Unless(Contract.Creation.BelowTier, function(ctx)
	if ctx.tier == nil or not ctx.unitDef.isFactory then
		return false
	end
	local required = tonumber(ctx.unitDef.customParams and ctx.unitDef.customParams.techlevel) or 1
	return required >= 2 and ctx.tier < required
end)
