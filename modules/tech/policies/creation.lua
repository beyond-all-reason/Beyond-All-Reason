local Modules = require("modules/enums").Modules
local Policy = require("modules/policy")

---@type ConstructionContract
local Construction = Policies.Contract(Modules.Construction)

-- A team's tier is its tech level, and a lab above it stays out of the build menu
--
local Creation = Policy.Contributes(Construction.Creation, { BelowTier = "BelowTier" })

Policies.For(Construction.CreationFacts).Provide(Construction.CreationFacts.Tier, function(ctx)
	local raw = ctx.springRepo.GetTeamRulesParam(ctx.teamID, "tech_level")
	if raw == nil then
		return nil
	end
	return tonumber(raw) or 1
end)

Policies.On(Creation).Unless(Creation.BelowTier, function(ctx)
	if ctx.tier == nil or not ctx.unitDef.isFactory then
		return false
	end
	local required = tonumber(ctx.unitDef.customParams and ctx.unitDef.customParams.techlevel) or 1
	return required >= 2 and ctx.tier < required
end)

---@class (partial) TechContract
local Contract = {}
Contract.Creation = Creation

return Contract
