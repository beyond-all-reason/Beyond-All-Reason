local ConstructionEnums = require("modules/construction/enums")
local Policy = require("modules/policy")
local Tax = require("modules/transfer/resource/tax")
local TransferEnums = require("modules/transfer/enums")

-- Two teams, sender and receiver: the context every transfer is decided in, and the terms a module fills into it
--
---@class TransferTeamResources
---@field metal EconomyResource
---@field energy EconomyResource

---@class TransferContext: PolicyContext
---@field senderTeamId integer
---@field receiverTeamId integer
---@field sender TransferTeamResources
---@field receiver TransferTeamResources
---@field springRepo Spring
---@field areAlliedTeams boolean
---@field isCheatingEnabled boolean
---@field techBlocking? TechBlockingContext
---@field unitSharingModes? string[]
---@field taxRate? number

---@class TransferRequest: TransferContext
---@field policyType string TransferEnums.PolicyType

---@class TransferTeamPairingFacts: PolicyFacts<TransferContext> providers get the spring repo, the sender and the receiver as their extra arguments
---@field TechBlocking "techBlocking"
---@field UnitSharingModes "unitSharingModes"
---@field TaxRate "taxRate"

---@type TransferTeamPairingFacts
local TeamPairing = {
	TechBlocking = "techBlocking",
	UnitSharingModes = "unitSharingModes",
	TaxRate = "taxRate",
}
Policy.Facts(TeamPairing)

Policies.On(TeamPairing)
	.Default(TeamPairing.UnitSharingModes, function(ctx)
		local mode = ctx.modOptions[TransferEnums.ModOptions.UnitSharingMode]
		return { mode or ConstructionEnums.UnitFilterCategory.None }
	end)
	.Default(TeamPairing.TaxRate, function(ctx)
		return Tax.ModOption(ctx.modOptions)
	end)

---@class (partial) TransferContract
local Contract = {}
Contract.TeamPairing = TeamPairing

return Contract
