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

---@class MexRegion: Region one of the layout's regions, in elmos: an area whose metal is dealt to the teams seated at one start
---@field type "mex_region"
---@field id string name@team, unique in the layout
---@field name string given by the map, or derived from the group at load
---@field team integer the start ordinal the region belongs to: start 1 is team 1
---@field group string what the region is for on this map: "anti", "tech"
---@field vertices { x: number, z: number }[]

---@class MexRegionsTeamStart a team, seated at a start
---@field teamID integer
---@field allyTeam integer the start ordinal the team plays from: ally team 0 is 1
---@field x number where the team starts from: its start area's centre
---@field z number

---@class MexRegionsDealContext what the deal is made from: the layout, the map's metal, and who sits where
---@field regions MexRegion[] the layout's regions
---@field spots { x: number, z: number }[] the map's metal spots; a mex is judged by the spot it mines
---@field teams MexRegionsTeamStart[] the order the deal goes round

---@class MexRegionsDeal who holds what; empty when the deal was refused, and problems say why
---@field regions table<string, integer> the team holding each region, by region id
---@field spots table<string, integer[]> the teams holding each metal spot, by spot key: the claims a mex is judged by. A spot two regions cover is held by both their teams
---@field problems string[] why there is no deal; empty when there is one

---@class TransferMexSplittingStages: PolicyStages<MexRegionsDealContext, MexRegionsDeal>
---@field LayoutChecksOut string the layout passes the regions module's set check for mex regions: each region whole and fielded, no two sharing ground, every spot covered
---@field SpotsKnown string the map has metal spots; a metal map has nothing to deal
---@field NearestRoundRobin string a region goes round the teams seated at its start, nearest first; one whose start is empty this match goes round every team. A team left holding nothing means the layout has too few regions, and there is no deal

---@type TransferMexSplittingStages
local MexSplitting = {
	LayoutChecksOut = "LayoutChecksOut",
	SpotsKnown = "SpotsKnown",
	NearestRoundRobin = "NearestRoundRobin",
}

---@class MexRegionsHeirContext a team has left the match; who takes its regions
---@field departing MexRegionsTeamStart
---@field heirs { teamID: integer, x: number, z: number, gifted: integer }[] its living allies in the deal, each with how many regions departing teams have already left it

---@class TransferMexSplittingHeirStages: PolicyStages<MexRegionsHeirContext, integer|false>
---@field FewestGiftedThenNearest string the ally gifted the fewest regions so far; among equals, the one who starts nearest the departing team

---@type TransferMexSplittingHeirStages
local MexSplittingHeir = {
	FewestGiftedThenNearest = "FewestGiftedThenNearest",
}

---@class TransferMexRegionsSetStages what transfer adds to the regions module's set check, for its own type
---@field MexesCovered string every metal spot the asker knows lies inside a mex region

---@type TransferMexRegionsSetStages
local MexRegionsSet = {
	MexesCovered = "MexesCovered",
}

---@class TransferMexRegionsNamesStages what transfer adds to the regions module's naming, for its own type
---@field FromGroup string a mex region that carries no name is called after its group

---@type TransferMexRegionsNamesStages
local MexRegionsNames = {
	FromGroup = "FromGroup",
}

---@class TransferPipelines what LoadPolicies("transfer") hands back
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
})
