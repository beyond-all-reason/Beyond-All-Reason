local PolicyBuilder = VFS.Include("modules/policy_builder.lua")

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

---@class TransferTeamTermsToken: PolicyContextToken<TransferTeamContext>
---@field TaxRate string

---@type TransferTeamTermsToken
local TeamTerms = {
	TaxRate = "taxRate",
}

---@class TransferUnitNotesToken: PolicyContextToken<UnitPolicyResult> display notes other modules attach to a unit-terms record
---@field FutureUnlock string
---@field TechData string

---@type TransferUnitNotesToken
local UnitNotes = {
	FutureUnlock = "futureUnlock",
	TechData = "techData",
}

---@class TransferResourceNotesToken: PolicyContextToken<ResourcePolicyResult> display notes other modules attach to a resource-terms record
---@field TaxUnlock string

---@type TransferResourceNotesToken
local ResourceNotes = {
	TaxUnlock = "taxUnlock",
}

---@class TransferTeamPairingToken: PolicyContextToken<TransferPolicyContext>
---@field TechBlocking string
---@field UnitSharingModes string
---@field TaxRate string

---@type TransferTeamPairingToken
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
---@field TeamPairing TransferTeamPairingToken
---@field TeamTerms TransferTeamTermsToken
---@field UnitTermsNotes TransferUnitNotesToken
---@field ResourceTermsNotes TransferResourceNotesToken

return PolicyBuilder.Contract("transfer", {
	Take = PolicyBuilder.Single(Take),
	UnitTransfer = PolicyBuilder.Single(UnitTransfer),
	ResourceTransfer = PolicyBuilder.Single(ResourceTransfer),
	TeamPairing = PolicyBuilder.Context(TeamPairing),
	TeamTerms = PolicyBuilder.Context(TeamTerms),
	UnitTermsNotes = PolicyBuilder.Context(UnitNotes),
	ResourceTermsNotes = PolicyBuilder.Context(ResourceNotes),
})
