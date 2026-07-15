local ModeEnums = VFS.Include("modes/sharing_mode_enums.lua")
local Shared = VFS.Include("modules/sharing/unit/shared.lua")
local Helpers = VFS.Include("modules/sharing/helpers.lua")

--- Unit sharing gate: sender and receiver must be allied, the effective sharing
--- modes must allow something, and (unless cheating) the receiver must have
--- active players. Denials still carry the full UnitPolicyResult shape so
--- downstream consumers read one type.

---@type PolicyDescriptor
return {
	name = "UnitCanShareGate",
	---@param ctx PolicyContext
	---@return UnitPolicyResult|nil
	evaluate = function(ctx)
		local modOptions = ctx.springRepo.GetModOptions()
		local modes = Shared.ResolveSharingModes(ctx, modOptions)
		local canShare = ctx.areAlliedTeams and not (#modes == 1 and modes[1] == ModeEnums.UnitFilterCategory.None)
		if canShare and not ctx.isCheatingEnabled and not Helpers.TeamActive(ctx.springRepo, ctx.receiverTeamId) then
			canShare = false
		end
		if canShare then
			return nil
		end
		return Shared.BuildUnitPolicyResult(ctx, modOptions, false)
	end,
}
