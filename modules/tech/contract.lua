local PolicyBuilder = VFS.Include("modules/policy_builder.lua")
local ConstructionContract = VFS.Include("modules/construction/contract.lua") ---@type ConstructionContract

---@class TechTierRequest
---@field level integer the team's current tech level
---@field points number keystone points the team holds
---@field opts table<string, string|number|boolean> the modoption snapshot
---@field t2Threshold number keystones per player for tech 2
---@field t3Threshold number keystones per player for tech 3

---@class TechCreationStages the guard tech adds to construction's creation pipeline
---@field BelowTier string a lab whose tier the team has not reached

---@type TechCreationStages
local Creation = {
	BelowTier = "BelowTier",
}

---@class TechCoreStages: PolicyStages<TechTierRequest, TechCoreLadder>
---@field TechCoreLadder string

---@type TechCoreStages
local TechCore = {
	TechCoreLadder = "TechCoreLadder",
}

---@class TechPipelines what LoadPolicies("tech") hands back
---@field tech_core AssembledPipeline<TechTierRequest, TechCoreLadder>

---@class TechContract
---@field TechCore TechCoreStages
---@field Creation TechCreationStages

return PolicyBuilder.Contract("tech", {
	TechCore = PolicyBuilder.Single(TechCore),
	Creation = PolicyBuilder.Contributes(ConstructionContract.Creation, Creation),
})
