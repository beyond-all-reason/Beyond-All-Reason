--- No early deny: the answer is always a record with canShare in it, because callers
--- need the stun and delay terms even when refused (the tooltip explains why).

local ModeEnums = VFS.Include("modules/context/mode_enums.lua")
local Stages = VFS.Include("modules/transfer/policy_stages.lua") ---@type TransferPolicyStages

local NONE = ModeEnums.UnitFilterCategory.None

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
		stunSeconds = tonumber(modOptions[ModeEnums.ModOptions.UnitShareStunSeconds]) or 0,
		stunCategory = modOptions[ModeEnums.ModOptions.UnitStunCategory] or ModeEnums.UnitFilterCategory.Resource,
		buildDelaySeconds = tonumber(modOptions[ModeEnums.ModOptions.ConstructorBuildDelay]) or 0,
		techBlocking = ctx.techBlocking,
	}
end

Policies.Pipeline(Stages.unit_transfer)
	.Refusal(function(ctx)
		return terms(ctx, false)
	end)
	.Unless(Stages.unit_transfer.SharingDisabled, function(ctx)
		-- One mode, and it is None: the mode grammar's way of saying denied.
		local modes = modesOf(ctx)
		return #modes == 1 and modes[1] == NONE
	end)
	.If(Stages.unit_transfer.Allied, function(ctx)
		return ctx.areAlliedTeams
	end)
	.Unless(Stages.unit_transfer.ReceiverHasNoPlayers, function(ctx)
		if ctx.isCheatingEnabled then
			return false
		end
		local numActivePlayers = ctx.springRepo.GetTeamRulesParam(ctx.receiverTeamId, "numActivePlayers")
		return numActivePlayers ~= nil and tonumber(numActivePlayers) == 0
	end)
	.Select(Stages.unit_transfer.TransferTerms, function(ctx)
		return terms(ctx, true)
	end)
