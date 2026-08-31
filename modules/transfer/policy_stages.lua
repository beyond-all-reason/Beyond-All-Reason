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

---@class TransferPolicyStages
---@field take TransferTakeStages
---@field unit_transfer TransferUnitTransferStages
---@field resource_transfer TransferResourceTransferStages
---@field team_pairing TransferTeamPairingToken

return PolicyBuilder.Stages("transfer", {
	take = PolicyBuilder.Single(Take),
	unit_transfer = PolicyBuilder.Single(UnitTransfer),
	resource_transfer = PolicyBuilder.Single(ResourceTransfer),
	team_pairing = PolicyBuilder.Context(TeamPairing),
})
