local Shared = VFS.Include("modules/sharing/unit/shared.lua")

--- Terminal compute: the gate passed, so build the pair's allowed
--- UnitPolicyResult. Always returns.

---@type PolicyDescriptor
return {
	name = "ComputeUnitPolicy",
	---@param ctx PolicyContext
	---@return UnitPolicyResult
	evaluate = function(ctx)
		return Shared.BuildUnitPolicyResult(ctx, ctx.springRepo.GetModOptions(), true)
	end,
}
