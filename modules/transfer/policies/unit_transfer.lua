local ConstructionEnums = require("modules/construction/enums")
local Policy = require("modules/policy")
local TransferEnums = require("modules/transfer/enums")

-- May this team give that one a unit, and on what terms
--
---@class TransferTerms
---@field senderTeamId integer
---@field receiverTeamId integer

---@class UnitTransferTerms: TransferTerms
---@field canShare boolean
---@field sharingModes string[]
---@field stunSeconds number?
---@field stunCategory string?
---@field buildDelaySeconds number?

---@class TransferUnitTransferPolicy: PolicySteps<TransferContext, UnitTransferTerms>
---@field SharingDisabled "SharingDisabled"
---@field Allied "Allied"
---@field ReceiverHasNoPlayers "ReceiverHasNoPlayers"
---@field TransferTerms "TransferTerms"

---@type TransferUnitTransferPolicy
local UnitTransfer = {
	SharingDisabled = "SharingDisabled",
	Allied = "Allied",
	ReceiverHasNoPlayers = "ReceiverHasNoPlayers",
	TransferTerms = "TransferTerms",
}
Policy.Single(UnitTransfer)

local NONE = ConstructionEnums.UnitFilterCategory.None

---@param ctx TransferContext
---@return string[]
local function modesOf(ctx)
	return ctx.unitSharingModes or { tostring(ctx.modOptions[TransferEnums.ModOptions.UnitSharingMode] or NONE) }
end

---@param ctx TransferContext
---@param canShare boolean
---@return UnitTransferTerms
local function terms(ctx, canShare)
	local modOptions = ctx.modOptions
	return {
		canShare = canShare,
		senderTeamId = ctx.senderTeamId,
		receiverTeamId = ctx.receiverTeamId,
		sharingModes = modesOf(ctx),
		stunSeconds = tonumber(modOptions[TransferEnums.ModOptions.UnitShareStunSeconds]) or 0,
		stunCategory = tostring(
			modOptions[TransferEnums.ModOptions.UnitStunCategory] or ConstructionEnums.UnitFilterCategory.Resource
		),
		buildDelaySeconds = tonumber(modOptions[ConstructionEnums.ModOptions.ConstructorBuildDelay]) or 0,
	}
end

Policies.On(UnitTransfer)
	.Refusal(function(ctx)
		return terms(ctx, false)
	end)
	.Unless(UnitTransfer.SharingDisabled, function(ctx)
		local modes = modesOf(ctx)
		return #modes == 1 and modes[1] == NONE
	end)
	.If(UnitTransfer.Allied, function(ctx)
		return ctx.areAlliedTeams
	end)
	.Unless(UnitTransfer.ReceiverHasNoPlayers, function(ctx)
		if ctx.isCheatingEnabled then
			return false
		end
		local numActivePlayers = ctx.springRepo.GetTeamRulesParam(ctx.receiverTeamId, "numActivePlayers")
		return numActivePlayers ~= nil and tonumber(numActivePlayers) == 0
	end)
	.Answer(UnitTransfer.TransferTerms, function(ctx)
		return terms(ctx, true)
	end)

-- The notes other modules attach to a unit-terms record for the player to read
--
---@class TransferNotesContext: PolicyContext
---@field terms TransferTerms the record the notes are for

---@class TransferUnitNotesContext: TransferNotesContext
---@field terms UnitTransferTerms

---@class TransferUnitNotesFacts: PolicyFacts<TransferUnitNotesContext>
---@field Opening "opening" a clause, in the player's language, on what would open unit sharing further

---@type TransferUnitNotesFacts
local UnitTermsNotes = {
	Opening = "opening",
}
Policy.Facts(UnitTermsNotes)

---@class (partial) TransferContract
local Contract = {}
Contract.UnitTransfer = UnitTransfer
Contract.UnitTermsNotes = UnitTermsNotes

return Contract
