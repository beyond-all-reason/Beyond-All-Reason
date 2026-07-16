local Enums = VFS.Include("modules/sharing/enums.lua")
local Config = VFS.Include("modules/sharing/config.lua")
local Helpers = VFS.Include("modules/sharing/helpers.lua")
local Policies = VFS.Include("modules/policy_builder.lua")

--- Resource transfer policy: deny gates in reading order, then the terminal
--- compute builds the pair's ResourcePolicyResult. Pure functions only — the
--- transfer itself is an action (modules/sharing/actions/resource_transfer.lua).

local METAL = Enums.ResourceType.METAL

---@param ctx PolicyContext
---@param resourceType ResourceName
---@return ResourcePolicyResult
local function deny(ctx, resourceType)
	return Helpers.CreateDenyPolicy(ctx.senderTeamId, ctx.receiverTeamId, resourceType, ctx.springRepo)
end

local policyResultPool = {} ---@type table<ResourceName, ResourcePolicyResult>

return Policies.Pipeline()
	-- Sharing disabled by mod option denies everything, even when cheating.
	:Gate("SharingEnabled", function(ctx, resourceType)
		if not Config.isResourceSharingEnabled(ctx.springRepo) then
			return deny(ctx, resourceType)
		end
		return nil
	end)
	-- Only allied teams may receive from player teams (cheating bypasses;
	-- AI/Gaia senders are exempt so scenario scripting can seed enemy economies).
	:Gate("AlliedOrNonPlayerSender", function(ctx, resourceType)
		if ctx.isCheatingEnabled then
			return nil
		end
		if not ctx.areAlliedTeams and not Helpers.IsNonPlayerTeam(ctx.springRepo, ctx.senderTeamId) then
			return deny(ctx, resourceType)
		end
		return nil
	end)
	-- Teams with no active players cannot receive (cheating bypasses).
	:Gate("ReceiverActive", function(ctx, resourceType)
		if ctx.isCheatingEnabled then
			return nil
		end
		if not Helpers.TeamActive(ctx.springRepo, ctx.receiverTeamId) then
			return deny(ctx, resourceType)
		end
		return nil
	end)
	-- Every gate passed: taxed sendable vs receiver capacity.
	:Compute("ComputeResourceTransfer", function(ctx, resourceType)
		local effectiveRate = Helpers.ResolveEffectiveTaxRate(ctx)

		local senderData, receiverData
		if resourceType == METAL then
			senderData = ctx.sender.metal
			receiverData = ctx.receiver.metal
		else
			senderData = ctx.sender.energy
			receiverData = ctx.receiver.energy
		end

		local taxedSendable = math.max(0, senderData.current) * (1 - effectiveRate)
		local capacity = receiverData.storage - receiverData.current

		local result = policyResultPool[resourceType]
		if not result then
			result = {} --[[@as ResourcePolicyResult]] -- filled by CombineResourcePolicy below
			policyResultPool[resourceType] = result
		end

		Helpers.CombineResourcePolicy(taxedSendable, effectiveRate, capacity, ctx.senderTeamId, ctx.receiverTeamId, resourceType, result)
		result.techBlocking = ctx.ext and ctx.ext.techBlocking or nil

		return result
	end)
	:Build()
