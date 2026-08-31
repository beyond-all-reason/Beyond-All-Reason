local ModuleHandler = VFS.Include("modules/module_handler.lua")
local Stages = VFS.Include("modules/transfer/policy_stages.lua") ---@type TransferPolicyStages

Policies.Enrich(Stages.team_pairing).Provide(
	Stages.team_pairing.TechBlocking,
	Stages.team_pairing.UnitSharingModes,
	Stages.team_pairing.TaxRate,
	function(_, springRepo, senderTeamID)
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
		local pipelines = ModuleHandler.LoadPolicies("tech") ---@type TechPipelines
		local tier = ModuleHandler.Evaluate(pipelines.tech_core, request)
		local taxRate = (tier.taxRate ~= nil and tier.taxRate >= 0) and tier.taxRate or nil
		return tier.blocking, tier.modes, taxRate
	end
)
