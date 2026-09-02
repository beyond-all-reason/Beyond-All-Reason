local ModuleHandler = VFS.Include("modules/module_handler.lua")
local Modules = VFS.Include("modules/enums.lua").Modules
local ConstructionEnums = VFS.Include("modules/construction/enums.lua")
local TechTier = VFS.Include("modules/tech/tier.lua")
local Contract = VFS.Include("modules/transfer/contract.lua") ---@type TransferContract
local teamTerms = Contract.TeamTerms
local teamPairing = Contract.TeamPairing
local unitTermsNotes = Contract.UnitTermsNotes
local resourceTermsNotes = Contract.ResourceTermsNotes

Policies.Enrich(teamTerms).Provide(teamTerms.TaxRate, function(ctx)
	local level = tonumber(ctx.springRepo.GetTeamRulesParam(ctx.teamId, "tech_level") or 1) or 1
	local rate = tonumber(TechTier.resolveByTechLevel(ctx.opts, "tax_resource_sharing_amount", level))
	return (rate ~= nil and rate >= 0) and rate or nil
end)

Policies.Enrich(teamPairing)
	.Provide(teamPairing.TechBlocking, teamPairing.UnitSharingModes, teamPairing.TaxRate, function(_, springRepo, senderTeamID)
		local rawLevel = springRepo.GetTeamRulesParam(senderTeamID, "tech_level")
		local rawPoints = springRepo.GetTeamRulesParam(senderTeamID, "tech_points")
		local rawT2 = springRepo.GetTeamRulesParam(senderTeamID, "tech_t2_threshold")
		local rawT3 = springRepo.GetTeamRulesParam(senderTeamID, "tech_t3_threshold")
		---@type TechTierRequest
		local request = {
			opts = springRepo.GetModOptions(),
			level = tonumber(rawLevel or 1) or 1,
			points = tonumber(rawPoints or 0) or 0,
			t2Threshold = tonumber(rawT2 or 0) or 0,
			t3Threshold = tonumber(rawT3 or 0) or 0,
		}
		local pipelines = ModuleHandler.LoadPolicies(Modules.Tech) ---@type TechPipelines
		local tier = ModuleHandler.Evaluate(pipelines.tech_core, request)
		local taxRate = (tier.taxRate ~= nil and tier.taxRate >= 0) and tier.taxRate or nil
		return tier.blocking, tier.modes, taxRate
	end)

local NONE_MODE = ConstructionEnums.UnitFilterCategory.None

Policies.Enrich(unitTermsNotes).Provide(unitTermsNotes.FutureUnlock, unitTermsNotes.TechData, function(policy)
	local tb = policy.techBlocking
	if not tb then
		return false, nil
	end
	local opts = Spring.GetModOptions()
	local nextMode, nextLevel, nextThreshold
	for scanLevel = tb.level + 1, 3 do
		local mode = opts["unit_sharing_mode_at_t" .. scanLevel] ---@type string? sparse modoption
		if mode and mode ~= "" and mode ~= NONE_MODE then
			nextMode, nextLevel = mode, scanLevel
			nextThreshold = scanLevel == 2 and tb.t2Threshold or tb.t3Threshold
			break
		end
	end
	return nextMode ~= nil,
		{
			currentKeystones = tb.points,
			nextTechLevel = nextLevel or tb.nextLevel,
			requiredKeystones = nextThreshold or tb.nextThreshold,
			nextUnitSharingMode = nextMode or "",
		}
end)

Policies.Enrich(resourceTermsNotes).Provide(resourceTermsNotes.TaxUnlock, function(policyResult)
	local tb = policyResult.techBlocking
	if not tb then
		return nil
	end
	local opts = Spring.GetModOptions()
	for scanLevel = tb.level + 1, 3 do
		local raw = opts["tax_resource_sharing_amount_at_t" .. scanLevel]
		local rate = tonumber(raw)
		if rate and rate >= 0 then
			return {
				unlockLevel = scanLevel,
				unlockThreshold = scanLevel == 2 and tb.t2Threshold or tb.t3Threshold,
				unlockValue = raw,
			}
		end
	end
	return nil
end)
