local PolicyBuilder = VFS.Include("modules/policy_builder.lua")

---@class TechTierRequest
---@field level integer the team's current tech level
---@field points number keystone points the team holds
---@field opts table<string, string|number|boolean> the modoption snapshot
---@field t2Threshold number keystones per player for tech 2
---@field t3Threshold number keystones per player for tech 3

---@class TechCoreStages: PolicyStages<TechTierRequest, TechCoreLadder>
---@field TechCoreLadder string

---@type TechCoreStages
local TechCore = {
	TechCoreLadder = "TechCoreLadder",
}

---@class TechPipelines what LoadPolicies("tech") hands back
---@field tech_core AssembledPipeline<TechTierRequest, TechCoreLadder>

---@class TechPolicyStages
---@field tech_core TechCoreStages

return PolicyBuilder.Stages("tech", { tech_core = PolicyBuilder.Single(TechCore) })
