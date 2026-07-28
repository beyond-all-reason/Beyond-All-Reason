local SharedConfig = VFS.Include("modules/transfer/economy/shared_config.lua")
local Shared = VFS.Include("modules/transfer/resource/shared.lua")
local TransferEnums = VFS.Include("modules/context/enums.lua")
local Contract = VFS.Include("modules/transfer/contract.lua") ---@type TransferContract
local resourceTransfer = Contract.ResourceTransfer

local METAL = TransferEnums.ResourceType.METAL

---@param ctx TransferPolicyContext
---@param resourceType ResourceName
---@return ResourcePolicyResult
local function deny(ctx, resourceType)
	return Shared.CreateDenyPolicy(ctx.senderTeamId, ctx.receiverTeamId, resourceType, ctx.springRepo)
end

Policies
	.Pipeline(resourceTransfer)
	.Refusal(function(ctx, resourceType)
		return deny(ctx, resourceType)
	end)
	.Unless(resourceTransfer.SharingDisabled, function(ctx)
		return not SharedConfig.isResourceSharingEnabled(ctx.springRepo)
	end)
	-- Cheats bypass the alliance and empty-team checks but NOT the one above:
	-- turning sharing off is a rule of the match, not a restriction to lift.
	.If(resourceTransfer.Allied, function(ctx)
		if ctx.isCheatingEnabled then
			return true
		end
		return ctx.areAlliedTeams or Shared.IsNonPlayerTeam(ctx.springRepo, ctx.senderTeamId)
	end)
	.Unless(resourceTransfer.ReceiverHasNoPlayers, function(ctx)
		if ctx.isCheatingEnabled then
			return false
		end
		local numActivePlayers = ctx.springRepo.GetTeamRulesParam(ctx.receiverTeamId, "numActivePlayers")
		return numActivePlayers ~= nil and tonumber(numActivePlayers) == 0
	end)
	.Select(resourceTransfer.RateAndCapacity, function(ctx, resourceType, rate, result)
		local senderData, receiverData
		if resourceType == METAL then
			senderData = ctx.sender.metal
			receiverData = ctx.receiver.metal
		else
			senderData = ctx.sender.energy
			receiverData = ctx.receiver.energy
		end
		local taxedSendable = math.max(0, senderData.current) * (1 - rate)
		local capacity = receiverData.storage - receiverData.current
		Shared.CombineResourcePolicy(
			taxedSendable,
			rate,
			capacity,
			ctx.senderTeamId,
			ctx.receiverTeamId,
			resourceType,
			result
		)
		result.techBlocking = ctx.techBlocking
		return result
	end)
