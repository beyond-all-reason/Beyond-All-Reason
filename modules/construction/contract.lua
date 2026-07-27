local PolicyBuilder = VFS.Include("modules/policy_builder.lua")

---@class ConstructionAssistContext a builder's command that would help an ally's unit along
---@field allied boolean the target belongs to another team we are allied with
---@field targetComplete boolean
---@field targetIsBuilder boolean a factory, or a builder that can build or assist
---@field assistEnabled boolean the allied assist modoption

---@class ConstructionAssistStages: PolicyStages<ConstructionAssistContext, boolean>
---@field AlliedAssistDisabled string
---@field Allowed string

---@type ConstructionAssistStages
local Assist = {
	AlliedAssistDisabled = "AlliedAssistDisabled",
	Allowed = "Allowed",
}

---@class ConstructionReclaimContext a reclaim, or a guard of something that reclaims
---@field allied boolean
---@field command "reclaim"|"guard"
---@field targetCanReclaim boolean
---@field reclaimEnabled boolean the allied unit reclaim modoption

---@class ConstructionReclaimStages: PolicyStages<ConstructionReclaimContext, boolean>
---@field AlliedReclaimDisabled string
---@field Allowed string

---@type ConstructionReclaimStages
local Reclaim = {
	AlliedReclaimDisabled = "AlliedReclaimDisabled",
	Allowed = "Allowed",
}

---@class ConstructionResurrectContext may a partly reclaimed wreck still be resurrected
---@field partialAllowed boolean the partial resurrection modoption

---@class ConstructionResurrectStages: PolicyStages<ConstructionResurrectContext, boolean>
---@field PartialResurrectionDisabled string
---@field Allowed string

---@type ConstructionResurrectStages
local Resurrect = {
	PartialResurrectionDisabled = "PartialResurrectionDisabled",
	Allowed = "Allowed",
}

---@class ConstructionBuildContext one build step by a builder: on a unit, or on a feature (reclaim, resurrect)
---@field builderID integer
---@field builderTeam integer
---@field delayed boolean the builder is under a build delay
---@field unitID integer|nil the unit being built, for a unit step
---@field unitDefID integer|nil
---@field featureID integer|nil the feature being worked, for a feature step
---@field part number the step's share of the whole; negative for reclaim

---@class ConstructionBuildStages: PolicyStages<ConstructionBuildContext, boolean>
---@field BuilderDelayed string
---@field Allowed string

---@type ConstructionBuildStages
local Build = {
	BuilderDelayed = "BuilderDelayed",
	Allowed = "Allowed",
}

---@class ConstructionPlacementContext where a builder wants to put a new unit
---@field unitDefID integer
---@field builderTeam integer
---@field x number
---@field y number
---@field z number
---@field extractor "mex"|"geo"|nil what the def extracts, if anything
---@field alliedExtractorNearby boolean another team's extractor already sits in the radius
---@field utilitySharing boolean the sharing mode lets utility buildings change hands

---@class ConstructionPlacementStages: PolicyStages<ConstructionPlacementContext, boolean>
---@field AlliedExtractorOccupied string
---@field Allowed string

---@type ConstructionPlacementStages
local Placement = {
	AlliedExtractorOccupied = "AlliedExtractorOccupied",
	Allowed = "Allowed",
}

---@class ConstructionPipelines what LoadPolicies("construction") hands back
---@field assist AssembledPipeline<ConstructionAssistContext, boolean>
---@field reclaim AssembledPipeline<ConstructionReclaimContext, boolean>
---@field resurrect AssembledPipeline<ConstructionResurrectContext, boolean>
---@field build AssembledPipeline<ConstructionBuildContext, boolean>
---@field placement AssembledPipeline<ConstructionPlacementContext, boolean>

---@class ConstructionContract
---@field Assist ConstructionAssistStages
---@field Reclaim ConstructionReclaimStages
---@field Resurrect ConstructionResurrectStages
---@field Build ConstructionBuildStages
---@field Placement ConstructionPlacementStages

return PolicyBuilder.Contract("construction", {
	Assist = PolicyBuilder.Single(Assist),
	Reclaim = PolicyBuilder.Single(Reclaim),
	Resurrect = PolicyBuilder.Single(Resurrect),
	Build = PolicyBuilder.Single(Build),
	Placement = PolicyBuilder.Single(Placement),
})
