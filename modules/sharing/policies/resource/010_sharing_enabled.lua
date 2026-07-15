local SharedConfig = VFS.Include("modules/sharing/config.lua")
local Shared = VFS.Include("modules/sharing/resource/shared.lua")

--- Resource sharing disabled by mod option: deny everything, even when cheating.

---@type PolicyDescriptor
return {
	name = "SharingEnabled",
	---@param ctx PolicyContext
	---@param resourceType ResourceName
	---@return ResourcePolicyResult|nil
	evaluate = function(ctx, resourceType)
		if not SharedConfig.isResourceSharingEnabled(ctx.springRepo) then
			return Shared.CreateDenyPolicy(ctx.senderTeamId, ctx.receiverTeamId, resourceType, ctx.springRepo)
		end
		return nil
	end,
}
