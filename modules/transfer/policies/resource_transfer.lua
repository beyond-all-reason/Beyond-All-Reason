--- Whether these two teams may move a resource, and on what terms.
---
--- The stages were the early returns inside CalcResourcePolicy; naming them
--- is the whole change. Order is declaration order, the first non-nil result
--- wins, and Compute always returns — so "deny" and "here is the rate" are
--- the same kind of answer, produced by different stages.
---
--- Every stage takes the resource. Today the rate is one number for all eco,
--- but that is a property of the modoption behind it, not of this pipeline:
--- a mode that prices metal apart from energy needs no new stage here.

local SharedConfig = VFS.Include("modules/transfer/economy/shared_config.lua")
local Shared = VFS.Include("modules/transfer/resource/shared.lua")
local TransferEnums = VFS.Include("modules/context/enums.lua")

local METAL = TransferEnums.ResourceType.METAL

---@param ctx PolicyContext
---@param resourceType ResourceName
---@return ResourcePolicyResult
local function deny(ctx, resourceType)
	return Shared.CreateDenyPolicy(ctx.senderTeamId, ctx.receiverTeamId, resourceType, ctx.springRepo)
end

Policies
	.Pipeline()
	.Gate("SharingDisabled", function(ctx, resourceType)
		if not SharedConfig.isResourceSharingEnabled(ctx.springRepo) then
			return deny(ctx, resourceType)
		end
		return nil
	end)
	-- Cheats bypass the alliance and empty-team gates but NOT the one above:
	-- turning sharing off is a rule of the match, not a restriction to lift.
	.Gate("NotAllied", function(ctx, resourceType)
		if ctx.isCheatingEnabled then
			return nil
		end
		if not ctx.areAlliedTeams and not Shared.IsNonPlayerTeam(ctx.springRepo, ctx.senderTeamId) then
			return deny(ctx, resourceType)
		end
		return nil
	end)
	.Gate("ReceiverHasNoPlayers", function(ctx, resourceType)
		if ctx.isCheatingEnabled then
			return nil
		end
		local numActivePlayers = ctx.springRepo.GetTeamRulesParam(ctx.receiverTeamId, "numActivePlayers")
		if numActivePlayers ~= nil and tonumber(numActivePlayers) == 0 then
			return deny(ctx, resourceType)
		end
		return nil
	end)
	.Compute("RateAndCapacity", function(ctx, resourceType, rate, result)
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
		result.techBlocking = ctx.ext and ctx.ext.techBlocking or nil
		return result
	end)
	.Register()
