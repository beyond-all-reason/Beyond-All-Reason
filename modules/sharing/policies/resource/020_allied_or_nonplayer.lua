local Shared = VFS.Include("modules/sharing/resource/shared.lua")
local Helpers = VFS.Include("modules/sharing/helpers.lua")

--- Only allied teams may receive from player teams (cheating bypasses; AI/Gaia
--- senders are exempt so scenario scripting can seed enemy economies).

---@type PolicyDescriptor
return {
	name = "AlliedOrNonPlayerSender",
	---@param ctx PolicyContext
	---@param resourceType ResourceName
	---@return ResourcePolicyResult|nil
	evaluate = function(ctx, resourceType)
		if ctx.isCheatingEnabled then
			return nil
		end
		if not ctx.areAlliedTeams and not Helpers.IsNonPlayerTeam(ctx.springRepo, ctx.senderTeamId) then
			return Shared.CreateDenyPolicy(ctx.senderTeamId, ctx.receiverTeamId, resourceType, ctx.springRepo)
		end
		return nil
	end,
}
