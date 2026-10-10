local Policy = require("modules/policy")

-- May a builder put a new unit here
--
---@class ConstructionPlacementContext: PolicyContext
---@field unitDefID integer
---@field builderTeam integer
---@field x number
---@field y number
---@field z number
---@field extractor "mex"|"geo"|nil what the def extracts, if anything
---@field alliedExtractorNearby boolean another team's extractor already sits in the radius
---@field utilitySharing boolean utility buildings may change hands between allies
---@field spotX number|nil for an extractor, the resource spot it targets
---@field spotZ number|nil
---@field spotHolder integer the team that holds this spot
---@field spotHolderAllied boolean the holder is another team on the builder's side

---@class ConstructionPlacementPolicy: PolicySteps<ConstructionPlacementContext, boolean>
---@field AlliedExtractorOccupied "AlliedExtractorOccupied"
---@field SpotHeldByAnAlly "SpotHeldByAnAlly"
---@field Allowed "Allowed"

---@type ConstructionPlacementPolicy
local Placement = {
	AlliedExtractorOccupied = "AlliedExtractorOccupied",
	SpotHeldByAnAlly = "SpotHeldByAnAlly",
	Allowed = "Allowed",
}
Policy.Single(Placement)

Policies.On(Placement)
	.Unless(Placement.AlliedExtractorOccupied, function(ctx)
		return ctx.extractor ~= nil and ctx.alliedExtractorNearby and not ctx.utilitySharing
	end)
	.Unless(Placement.SpotHeldByAnAlly, function(ctx)
		local upgradesTheirs = ctx.alliedExtractorNearby and ctx.utilitySharing
		return ctx.extractor ~= nil and ctx.spotHolderAllied and not upgradesTheirs
	end)
	.Answer(Placement.Allowed, function()
		return true
	end)

-- What placement asks of the modules that deal out spots and let buildings change hands
--
---@class ConstructionPlacementFacts: PolicyFacts<ConstructionPlacementContext>
---@field SpotHolder "spotHolder"
---@field UtilitySharing "utilitySharing"

---@type ConstructionPlacementFacts
local PlacementFacts = {
	SpotHolder = "spotHolder",
	UtilitySharing = "utilitySharing",
}
Policy.Facts(PlacementFacts)

Policies.For(PlacementFacts).Default(PlacementFacts.SpotHolder, function(ctx)
	return ctx.builderTeam
end)

---@class (partial) ConstructionContract
local Contract = {}
Contract.Placement = Placement
Contract.PlacementFacts = PlacementFacts

return Contract
