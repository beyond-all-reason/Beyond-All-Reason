local Shared = VFS.Include("modules/sharing/resource/shared.lua")
local Helpers = VFS.Include("modules/sharing/helpers.lua")

--- Teams with no active players cannot receive (cheating bypasses).

---@type PolicyDescriptor
return {
	name = "ReceiverActive",
	---@param ctx PolicyContext
	---@param resourceType ResourceName
	---@return ResourcePolicyResult|nil
	evaluate = function(ctx, resourceType)
		if ctx.isCheatingEnabled then
			return nil
		end
		if not Helpers.TeamActive(ctx.springRepo, ctx.receiverTeamId) then
			return Shared.CreateDenyPolicy(ctx.senderTeamId, ctx.receiverTeamId, resourceType, ctx.springRepo)
		end
		return nil
	end,
}
