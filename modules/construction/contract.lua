local PolicyBuilder = VFS.Include("modules/policy_builder.lua")
local Modules = VFS.Include("modules/enums.lua").Modules

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
---@field modOptions table<string, any>
---@field unitDefID integer
---@field builderTeam integer
---@field x number
---@field y number
---@field z number
---@field extractor "mex"|"geo"|nil what the def extracts, if anything
---@field alliedExtractorNearby boolean another team's extractor already sits in the radius
---@field utilitySharing boolean utility buildings may change hands between allies, a fact the module that owns sharing provides; false when nobody does
---@field spotX number|nil for an extractor, the resource spot it targets: the nearest spot to the build position, which is what the footprint yields from wherever it lands. Known for a mex today
---@field spotZ number|nil
---@field spotHolder integer the team that holds this spot, a fact any module that deals out spots may provide, for whatever kind of extractor it deals; the builder itself when nobody else does, or when the builder is one of several who hold it
---@field spotHolderAllied boolean the holder is another team on the builder's side; an enemy's hold restricts nobody

---@class ConstructionPlacementStages: PolicyStages<ConstructionPlacementContext, boolean>
---@field AlliedExtractorOccupied string
---@field SpotHeldByAnAlly string an extractor on a spot an ally holds, unless it goes onto that ally's extractor and utility buildings may change hands
---@field Allowed string

---@type ConstructionPlacementStages
local Placement = {
	AlliedExtractorOccupied = "AlliedExtractorOccupied",
	SpotHeldByAnAlly = "SpotHeldByAnAlly",
	Allowed = "Allowed",
}

---@class ConstructionPlacementFacts: PolicyFacts<ConstructionPlacementContext>
---@field SpotHolder string the team that holds this spot; the builder itself when nobody else does
---@field UtilitySharing string whether utility buildings may change hands between allies; false when nobody says

---@type ConstructionPlacementFacts
local PlacementFacts = {
	SpotHolder = "spotHolder",
	UtilitySharing = "utilitySharing",
}

---@class ConstructionCreationContext may this team create this def at all: the build option, not one step of it
---@field unitDefID integer
---@field unitDef table
---@field teamID integer
---@field tier integer|nil the team's tech tier, a fact tech provides; nil when no tier system is live

---@class ConstructionCreationStages: PolicyStages<ConstructionCreationContext, boolean>
---@field Allowed string

---@type ConstructionCreationStages
local Creation = {
	Allowed = "Allowed",
}

---@class ConstructionCreationFacts: PolicyFacts<ConstructionCreationContext>
---@field Tier string the team's tech tier; nil when no tier system is live

---@type ConstructionCreationFacts
local CreationFacts = {
	Tier = "tier",
}

---@class ConstructionPipelines what LoadPolicies("construction") hands back
---@field assist AssembledPipeline<ConstructionAssistContext, boolean>
---@field reclaim AssembledPipeline<ConstructionReclaimContext, boolean>
---@field resurrect AssembledPipeline<ConstructionResurrectContext, boolean>
---@field build AssembledPipeline<ConstructionBuildContext, boolean>
---@field placement AssembledPipeline<ConstructionPlacementContext, boolean>
---@field creation AssembledPipeline<ConstructionCreationContext, boolean>

---@class ConstructionContract
---@field Assist ConstructionAssistStages
---@field Reclaim ConstructionReclaimStages
---@field Resurrect ConstructionResurrectStages
---@field Build ConstructionBuildStages
---@field Placement ConstructionPlacementStages
---@field PlacementFacts ConstructionPlacementFacts
---@field Creation ConstructionCreationStages
---@field CreationFacts ConstructionCreationFacts

return PolicyBuilder.Contract(Modules.Construction, {
	Assist = PolicyBuilder.Single(Assist),
	Reclaim = PolicyBuilder.Single(Reclaim),
	Resurrect = PolicyBuilder.Single(Resurrect),
	Build = PolicyBuilder.Single(Build),
	Placement = PolicyBuilder.Single(Placement),
	PlacementFacts = PolicyBuilder.Facts(PlacementFacts),
	Creation = PolicyBuilder.Single(Creation),
	CreationFacts = PolicyBuilder.Facts(CreationFacts),
})
