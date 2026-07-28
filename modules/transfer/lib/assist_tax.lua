local Tax = VFS.Include("modules/transfer/resource/tax.lua")

local AssistTax = {}

---@class AssistTaxQuote
---@field metalTax number
---@field energyTax number
---@field affordable boolean the builder's team can pay the step and its tax

---What helping an ally's build step costs the helper, or nil when nothing is
---taxed: your own unit, no tax configured, or a step that is not progress.
---@param ctx ConstructionBuildContext
---@param opts table modoptions
---@param springRepo Spring
---@return AssistTaxQuote|nil
function AssistTax.Quote(ctx, opts, springRepo)
	local part = ctx.part
	local metalCost, energyCost
	if ctx.unitID ~= nil then
		if part <= 0 or not springRepo.GetUnitIsBeingBuilt(ctx.unitID) then
			return nil
		end
		local unitTeam = springRepo.GetUnitTeam(ctx.unitID)
		if not unitTeam or unitTeam == ctx.builderTeam or not springRepo.AreTeamsAllied(ctx.builderTeam, unitTeam) then
			return nil
		end
		local unitDef = UnitDefs[ctx.unitDefID]
		if not unitDef then
			return nil
		end
		metalCost, energyCost = unitDef.metalCost, unitDef.energyCost
	elseif ctx.featureID ~= nil then
		if part < 0 then
			return nil
		end
		local resurrectUnitName = springRepo.GetFeatureResurrect(ctx.featureID)
		if not resurrectUnitName or resurrectUnitName == "" then
			return nil
		end
		local featureMetal, featureMaxMetal = springRepo.GetFeatureResources(ctx.featureID)
		if not featureMetal or featureMaxMetal <= 0 or featureMetal >= featureMaxMetal then
			return nil
		end
		metalCost, energyCost = featureMaxMetal, 0
	else
		return nil
	end

	local taxRate = Tax.GetTaxRate(ctx.builderTeam, opts, springRepo)
	if taxRate <= 0 then
		return nil
	end
	local metalTax = metalCost * part * taxRate
	local energyTax = energyCost * part * taxRate
	local currentMetal = springRepo.GetTeamResources(ctx.builderTeam, "metal") or 0
	local currentEnergy = springRepo.GetTeamResources(ctx.builderTeam, "energy") or 0
	return {
		metalTax = metalTax,
		energyTax = energyTax,
		affordable = currentMetal >= metalTax + metalCost * part and currentEnergy >= energyTax + energyCost * part,
	}
end

return AssistTax
