local PolicyBuilder = VFS.Include("modules/policy_builder.lua")
local Modules = VFS.Include("modules/enums.lua").Modules
local ConstructionContract = VFS.Include("modules/construction/contract.lua") ---@type ConstructionContract
local RegionsContract = VFS.Include("modules/regions/contract.lua") ---@type RegionsContract

---@class TransferTakeContext
---@field modOptions table<string, string|number|boolean>|nil

---@class TransferPolicyContext
---@field senderTeamId integer
---@field receiverTeamId integer
---@field sender TeamResources
---@field receiver TeamResources
---@field springRepo Spring
---@field areAlliedTeams boolean
---@field isCheatingEnabled boolean
---@field techBlocking? TechBlockingContext provided by an enricher (tech blocking)
---@field unitSharingModes? string[] Effective sharing modes, provided by an enricher
---@field taxRate? number Effective tax rate, provided by an enricher

---@class TransferTeamContext one team, no pairing: what a single team's terms are
---@field teamId integer
---@field springRepo Spring
---@field opts table<string, string|number|boolean>

---@class TransferTeamTermsFacts: PolicyFacts<TransferTeamContext>
---@field TaxRate string

---@type TransferTeamTermsFacts
local TeamTerms = {
	TaxRate = "taxRate",
}

---@class TransferUnitNotesFacts: PolicyFacts<UnitPolicyResult> display notes other modules attach to a unit-terms record
---@field FutureUnlock string
---@field TechData string

---@type TransferUnitNotesFacts
local UnitNotes = {
	FutureUnlock = "futureUnlock",
	TechData = "techData",
}

---@class TransferResourceNotesFacts: PolicyFacts<ResourcePolicyResult> display notes other modules attach to a resource-terms record
---@field TaxUnlock string

---@type TransferResourceNotesFacts
local ResourceNotes = {
	TaxUnlock = "taxUnlock",
}

---@class TransferTeamPairingFacts: PolicyFacts<TransferPolicyContext>
---@field TechBlocking string
---@field UnitSharingModes string
---@field TaxRate string

---@type TransferTeamPairingFacts
local TeamPairing = {
	TechBlocking = "techBlocking",
	UnitSharingModes = "unitSharingModes",
	TaxRate = "taxRate",
}

---@class TransferTakeStages: PolicyStages<TransferTakeContext, TakePolicy>
---@field TakeTerms string

---@type TransferTakeStages
local Take = {
	TakeTerms = "TakeTerms",
}

---@class TransferUnitTransferStages: PolicyStages<TransferPolicyContext, UnitPolicyResult>
---@field SharingDisabled string
---@field Allied string
---@field ReceiverHasNoPlayers string
---@field TransferTerms string

---@type TransferUnitTransferStages
local UnitTransfer = {
	SharingDisabled = "SharingDisabled",
	Allied = "Allied",
	ReceiverHasNoPlayers = "ReceiverHasNoPlayers",
	TransferTerms = "TransferTerms",
}

---@class TransferResourceTransferStages: PolicyStages<TransferPolicyContext, ResourcePolicyResult>
---@field SharingDisabled string
---@field Allied string
---@field ReceiverHasNoPlayers string
---@field RateAndCapacity string

---@type TransferResourceTransferStages
local ResourceTransfer = {
	SharingDisabled = "SharingDisabled",
	Allied = "Allied",
	ReceiverHasNoPlayers = "ReceiverHasNoPlayers",
	RateAndCapacity = "RateAndCapacity",
}

---@class MexRegion: Region an area of the layout, in elmos, whose metal is dealt to the teams seated at one start
---@field type "mex_region"
---@field id string identity, from RegionsApi.Create via the layout; the deal is keyed by it
---@field name string display name: set by the map, or derived from the group at load
---@field team integer the start ordinal the region belongs to; start 1 is team 1
---@field group string the region's role on this map, e.g. "anti", "tech"
---@field vertices { x: number, z: number }[]

---@class MexRegionsTeamStart a team, seated at a start
---@field teamID integer
---@field allyTeam integer the start ordinal the team plays from; engine ally team 0 is 1
---@field x number the team's start point: the centre of its start area
---@field z number

---@class MexRegionsDealContext the inputs to the deal: the layout, the map's metal spots, and the seated teams
---@field regions MexRegion[] the layout's regions
---@field spots { x: number, z: number }[] the map's metal spots; a mex is attributed to the spot it mines
---@field teams MexRegionsTeamStart[] in deal order

---@class MexRegionsDeal the outcome: who holds what. Empty, with problems set, when no deal could be made
---@field regions table<string, integer> the team holding each region, by region id
---@field spots table<string, integer[]> the teams holding each metal spot, by spot key; this is what a mex placement is checked against. A spot covered by two regions is held by both teams
---@field problems string[] why no deal was made; empty when one was

---@class TransferMexSplittingStages: PolicyStages<MexRegionsDealContext, MexRegionsDeal>
---@field LayoutChecksOut string the layout passes the regions module's set check for mex regions: every region well-formed with its fields set, and every spot covered
---@field SpotsKnown string the map has metal spots; a metal map has none to deal
---@field NearestRoundRobin string a region goes round the teams seated at its start, nearest first; one whose start is empty this match goes round every team. A team left holding nothing means the layout has too few regions, and there is no deal

---@type TransferMexSplittingStages
local MexSplitting = {
	LayoutChecksOut = "LayoutChecksOut",
	SpotsKnown = "SpotsKnown",
	NearestRoundRobin = "NearestRoundRobin",
}

---@class MexRegionsHeirContext a team has left the match; decides who inherits its regions
---@field departing MexRegionsTeamStart
---@field heirs { teamID: integer, x: number, z: number, gifted: integer }[] the departing team's living allies in the deal; gifted is how many regions each has already inherited

---@class TransferMexSplittingHeirStages: PolicyStages<MexRegionsHeirContext, integer|false>
---@field FewestGiftedThenNearest string the ally that has inherited the fewest regions; ties go to the one starting nearest the departing team

---@type TransferMexSplittingHeirStages
local MexSplittingHeir = {
	FewestGiftedThenNearest = "FewestGiftedThenNearest",
}

---@class MexRegionEnv the keys the mex region stages read from the caller-supplied env (see RegionSetContext.env)
---@field spots { x: number, z: number, worth: number|nil }[]|nil the map's metal spots, when the caller has them. worth is the metal map's sum for the spot; a T1 mex yields worth/1000 metal per second

---@class TransferMexRegionsSetStages transfer's stages on the regions module's set check, for the mex region type
---@field MexesCovered string every metal spot in env.spots lies inside some mex region

---@type TransferMexRegionsSetStages
local MexRegionsSet = {
	MexesCovered = "MexesCovered",
}

---@class TransferMexRegionsNamesStages transfer's stages on the regions module's naming, for the mex region type
---@field FromGroup string an unnamed mex region is named after its group

---@type TransferMexRegionsNamesStages
local MexRegionsNames = {
	FromGroup = "FromGroup",
}

---@class TransferMexRegionsDescribeStages transfer's stages on the regions module's description, for regions of any type
---@field MetalSpots string the number of metal spots inside the region and their total worth; adds nothing when env.spots is nil

---@type TransferMexRegionsDescribeStages
local MexRegionsDescribe = {
	MetalSpots = "MetalSpots",
}

---@class TransferPipelines the return value of LoadPolicies("transfer")
---@field take AssembledPipeline<TransferTakeContext, TakePolicy>
---@field unit_transfer AssembledPipeline<TransferPolicyContext, UnitPolicyResult>
---@field resource_transfer AssembledPipeline<TransferPolicyContext, ResourcePolicyResult>
---@field mex_splitting AssembledPipeline<MexRegionsDealContext, MexRegionsDeal>
---@field mex_splitting_heir AssembledPipeline<MexRegionsHeirContext, integer|false>

---@class TransferContract
---@field Take TransferTakeStages
---@field UnitTransfer TransferUnitTransferStages
---@field ResourceTransfer TransferResourceTransferStages
---@field TeamPairing TransferTeamPairingFacts
---@field TeamTerms TransferTeamTermsFacts
---@field UnitTermsNotes TransferUnitNotesFacts
---@field ResourceTermsNotes TransferResourceNotesFacts
---@field MexSplitting TransferMexSplittingStages
---@field MexSplittingHeir TransferMexSplittingHeirStages
---@field MexRegionsSet TransferMexRegionsSetStages
---@field MexRegionsNames TransferMexRegionsNamesStages
---@field MexRegionsDescribe TransferMexRegionsDescribeStages

---@class TransferBuildStages the stages transfer adds to construction's build pipeline
---@field UnaffordableAssistTax string a build step the assisting team cannot pay the tax on

---@type TransferBuildStages
local Build = {
	UnaffordableAssistTax = "UnaffordableAssistTax",
}

return PolicyBuilder.Contract(Modules.Transfer, {
	Build = PolicyBuilder.Contributes(ConstructionContract.Build, Build),
	Take = PolicyBuilder.Single(Take),
	UnitTransfer = PolicyBuilder.Single(UnitTransfer),
	ResourceTransfer = PolicyBuilder.Single(ResourceTransfer),
	TeamPairing = PolicyBuilder.Facts(TeamPairing),
	TeamTerms = PolicyBuilder.Facts(TeamTerms),
	UnitTermsNotes = PolicyBuilder.Facts(UnitNotes),
	ResourceTermsNotes = PolicyBuilder.Facts(ResourceNotes),
	MexSplitting = PolicyBuilder.Single(MexSplitting),
	MexSplittingHeir = PolicyBuilder.Single(MexSplittingHeir),
	MexRegionsSet = PolicyBuilder.Contributes(RegionsContract.CheckSet, MexRegionsSet),
	MexRegionsNames = PolicyBuilder.Contributes(RegionsContract.Names, MexRegionsNames),
	MexRegionsDescribe = PolicyBuilder.Contributes(RegionsContract.Describe, MexRegionsDescribe),
})
