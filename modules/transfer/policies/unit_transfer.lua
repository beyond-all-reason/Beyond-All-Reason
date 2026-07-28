--- No early deny: the answer is always a record with canShare in it, because callers
--- need the stun and delay terms even when refused (the tooltip explains why).

local ConstructionEnums = VFS.Include("modules/construction/enums.lua")
local TransferEnums = VFS.Include("modules/transfer/enums.lua")
local Contract = VFS.Include("modules/transfer/contract.lua") ---@type TransferContract
local unitTransfer = Contract.UnitTransfer

local NONE = ConstructionEnums.UnitFilterCategory.None

---@param ctx TransferPolicyContext
---@return string[]
local function modesOf(ctx)
	return ctx.unitSharingModes or { ctx.springRepo.GetModOptions().unit_sharing_mode or NONE }
end

---@param ctx TransferPolicyContext
---@param canShare boolean
---@return UnitPolicyResult
local function terms(ctx, canShare)
	local modOptions = ctx.springRepo.GetModOptions()
	return {
		canShare = canShare,
		senderTeamId = ctx.senderTeamId,
		receiverTeamId = ctx.receiverTeamId,
		sharingModes = modesOf(ctx),
		stunSeconds = tonumber(modOptions[TransferEnums.ModOptions.UnitShareStunSeconds]) or 0,
		stunCategory = modOptions[TransferEnums.ModOptions.UnitStunCategory]
			or ConstructionEnums.UnitFilterCategory.Resource,
		buildDelaySeconds = tonumber(modOptions[ConstructionEnums.ModOptions.ConstructorBuildDelay]) or 0,
		techBlocking = ctx.techBlocking,
	}
end

Policies.On(unitTransfer)
	.Refusal(function(ctx)
		return terms(ctx, false)
	end)
	.Unless(unitTransfer.SharingDisabled, function(ctx)
		-- One mode, and it is None: the mode grammar's way of saying denied.
		local modes = modesOf(ctx)
		return #modes == 1 and modes[1] == NONE
	end)
	.If(unitTransfer.Allied, function(ctx)
		return ctx.areAlliedTeams
	end)
	.Unless(unitTransfer.ReceiverHasNoPlayers, function(ctx)
		if ctx.isCheatingEnabled then
			return false
		end
		local numActivePlayers = ctx.springRepo.GetTeamRulesParam(ctx.receiverTeamId, "numActivePlayers")
		return numActivePlayers ~= nil and tonumber(numActivePlayers) == 0
	end)
	.Answer(unitTransfer.TransferTerms, function(ctx)
		return terms(ctx, true)
	end)
