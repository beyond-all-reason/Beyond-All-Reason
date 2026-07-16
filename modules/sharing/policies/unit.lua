local ModeEnums = VFS.Include("modes/sharing_mode_enums.lua")
local Shared = VFS.Include("modules/sharing/unit/shared.lua")
local Helpers = VFS.Include("modules/sharing/helpers.lua")
local Policies = VFS.Include("modules/policy_builder.lua")

--- Unit transfer policy: one gate, then the terminal compute. Denials still
--- carry the full UnitPolicyResult shape so downstream consumers read one type.

return Policies.Pipeline("unit")
	-- Sender and receiver must be allied, the effective sharing modes must
	-- allow something, and (unless cheating) the receiver must have players.
	:Gate("UnitCanShareGate", function(ctx)
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
	end)
	-- The gate passed: build the pair's allowed UnitPolicyResult.
	:Compute("ComputeUnitPolicy", function(ctx)
		return Shared.BuildUnitPolicyResult(ctx, ctx.springRepo.GetModOptions(), true)
	end)
	:Build()
