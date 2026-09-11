local PolicyBuilder = VFS.Include("modules/policy_builder.lua")
local Modules = VFS.Include("modules/enums.lua").Modules
local ConstructionContract = VFS.Include("modules/construction/contract.lua") ---@type ConstructionContract

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

---@class TransferPipelines what LoadPolicies("transfer") hands back
---@field take AssembledPipeline<TransferTakeContext, TakePolicy>
---@field unit_transfer AssembledPipeline<TransferPolicyContext, UnitPolicyResult>
---@field resource_transfer AssembledPipeline<TransferPolicyContext, ResourcePolicyResult>

---@class TransferContract
---@field Take TransferTakeStages
---@field UnitTransfer TransferUnitTransferStages
---@field ResourceTransfer TransferResourceTransferStages
---@field TeamPairing TransferTeamPairingFacts
---@field TeamTerms TransferTeamTermsFacts
---@field UnitTermsNotes TransferUnitNotesFacts
---@field ResourceTermsNotes TransferResourceNotesFacts

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
})
