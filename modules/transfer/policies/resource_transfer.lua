local Pairing = require("modules/transfer/lib/pairing")
local Policy = require("modules/policy")
local Shared = require("modules/transfer/resource/shared")
local SharedConfig = require("modules/transfer/economy/shared_config")
local TransferEnums = require("modules/transfer/enums")

-- May this team send that one a resource, how much, and what the tax takes
--
---@class TransferResourceContext: TransferContext
---@field resourceType ResourceName
---@field taxRate number the pairing's, resolved and clamped to 0..1

---@class ResourceTransferTerms: TransferTerms
---@field canShare boolean the rules' answer for the pair; a yes with nothing to send is still a yes
---@field amountSendable number what the sender can deliver this moment, after tax and the receiver's room
---@field amountReceivable number the receiver's room this moment
---@field taxRate number
---@field resourceType ResourceName

---@class TransferResourceTransferPolicy: PolicySteps<TransferResourceContext, ResourceTransferTerms>
---@field SharingDisabled "SharingDisabled"
---@field Allied "Allied"
---@field ReceiverHasNoPlayers "ReceiverHasNoPlayers"
---@field RateAndCapacity "RateAndCapacity"

---@type TransferResourceTransferPolicy
local ResourceTransfer = {
	SharingDisabled = "SharingDisabled",
	Allied = "Allied",
	ReceiverHasNoPlayers = "ReceiverHasNoPlayers",
	RateAndCapacity = "RateAndCapacity",
}
Policy.Single(ResourceTransfer, function(t)
	---@cast t ResourceTransferTerms
	return t.senderTeamId, t.receiverTeamId, t.resourceType, t.canShare, t.taxRate, t.amountSendable, t.amountReceivable
end)

local METAL = TransferEnums.ResourceType.METAL

---@param ctx TransferResourceContext
---@param canShare boolean the rules' answer
---@param sendable number what the sender can deliver this moment
---@param room number the receiver's room this moment
---@return ResourceTransferTerms
local function terms(ctx, canShare, sendable, room)
	return {
		senderTeamId = ctx.senderTeamId,
		receiverTeamId = ctx.receiverTeamId,
		resourceType = ctx.resourceType,
		canShare = canShare,
		taxRate = ctx.taxRate,
		amountSendable = sendable,
		amountReceivable = room,
	}
end

Policies.On(ResourceTransfer)
	.FormContext(Pairing.ForResource)
	.Refusal(function(ctx)
		return terms(ctx, false, 0, 0)
	end)
	.Unless(ResourceTransfer.SharingDisabled, function(ctx)
		return not SharedConfig.isResourceSharingEnabled(ctx.springRepo)
	end)
	.If(ResourceTransfer.Allied, function(ctx)
		if ctx.isCheatingEnabled then
			return true
		end
		return ctx.areAlliedTeams or Shared.IsNonPlayerTeam(ctx.springRepo, ctx.senderTeamId)
	end)
	.Unless(ResourceTransfer.ReceiverHasNoPlayers, function(ctx)
		if ctx.isCheatingEnabled then
			return false
		end
		local numActivePlayers = ctx.springRepo.GetTeamRulesParam(ctx.receiverTeamId, "numActivePlayers")
		return numActivePlayers ~= nil and tonumber(numActivePlayers) == 0
	end)
	.Answer(ResourceTransfer.RateAndCapacity, function(ctx)
		local senderData, receiverData
		if ctx.resourceType == METAL then
			senderData = ctx.sender.metal
			receiverData = ctx.receiver.metal
		else
			senderData = ctx.sender.energy
			receiverData = ctx.receiver.energy
		end
		local room = math.max(0, receiverData.storage - receiverData.current)
		local sendable = math.min(math.max(0, senderData.current) * (1 - ctx.taxRate), room)
		return terms(ctx, true, sendable, room)
	end)

-- The notes other modules attach to a resource-terms record for the player to read
--
---@class TransferResourceNotesContext: TransferNotesContext
---@field terms ResourceTransferTerms

---@class TransferResourceNotesFacts: PolicyFacts<TransferResourceNotesContext>
---@field Opening "opening" a clause, in the player's language, on what would change the terms for the better

---@type TransferResourceNotesFacts
local ResourceTermsNotes = {
	Opening = "opening",
}
Policy.Facts(ResourceTermsNotes)

---@class (partial) TransferContract
local Contract = {}
Contract.ResourceTransfer = ResourceTransfer
Contract.ResourceTermsNotes = ResourceTermsNotes

return Contract
