local PolicyBuilder = VFS.Include("modules/policy_builder.lua")

---@class TechTierRequest
---@field level integer the team's current tech level
---@field points number keystone points the team holds
---@field opts table<string, string|number|boolean> the modoption snapshot
---@field t2Threshold number keystones per player for tech 2
---@field t3Threshold number keystones per player for tech 3

---@class TechUnlockContext may this team build this def at its tier
---@field unitDefID integer
---@field teamID integer
---@field level integer the team's current tech level
---@field requiredLevel integer the def's tier

---@class TechUnlockStages: PolicyStages<TechUnlockContext, boolean>
---@field BelowTier string
---@field Allowed string

---@type TechUnlockStages
local Unlock = {
	BelowTier = "BelowTier",
	Allowed = "Allowed",
}

---@class TechCoreStages: PolicyStages<TechTierRequest, TechCoreLadder>
---@field TechCoreLadder string

---@type TechCoreStages
local TechCore = {
	TechCoreLadder = "TechCoreLadder",
}

---@class TechPipelines what LoadPolicies("tech") hands back
---@field tech_core AssembledPipeline<TechTierRequest, TechCoreLadder>
---@field unlock AssembledPipeline<TechUnlockContext, boolean>

---@class TechContract
---@field TechCore TechCoreStages
---@field Unlock TechUnlockStages

return PolicyBuilder.Contract("tech", {
	TechCore = PolicyBuilder.Single(TechCore),
	Unlock = PolicyBuilder.Single(Unlock),
})
