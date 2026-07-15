local Enums = VFS.Include("modules/sharing/enums.lua")
local Shared = VFS.Include("modules/sharing/resource/shared.lua")
local Helpers = VFS.Include("modules/sharing/helpers.lua")

--- Terminal compute: every gate passed, so build the pair's ResourcePolicyResult
--- (taxed sendable vs receiver capacity). Always returns.

local METAL = Enums.ResourceType.METAL

local policyResultPool = {} ---@type table<ResourceName, ResourcePolicyResult>

---@type PolicyDescriptor
return {
	name = "ComputeResourceTransfer",
	---@param ctx PolicyContext
	---@param resourceType ResourceName
	---@return ResourcePolicyResult
	evaluate = function(ctx, resourceType)
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

		Shared.CombineResourcePolicy(taxedSendable, effectiveRate, capacity, ctx.senderTeamId, ctx.receiverTeamId, resourceType, result)
		result.techBlocking = ctx.ext and ctx.ext.techBlocking or nil

		return result
	end,
}
