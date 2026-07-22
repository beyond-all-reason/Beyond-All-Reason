local ModeEnums = VFS.Include("modes/sharing_mode_enums.lua")
local Helpers = VFS.Include("modules/sharing/helpers.lua")
local Policies = Policies ---@type PoliciesRegistrar injected by the loader (widget idiom)

--- Unit transfer policy: one gate, then the terminal compute. Denials still
--- carry the full UnitPolicyResult shape so downstream consumers read one type.

---Assemble a UnitPolicyResult from context + mod options; denials carry the
---same shape as allowed results so downstream consumers read one type.
---@param ctx PolicyContext
---@param modOptions table
---@param canShare boolean
---@return UnitPolicyResult
local function buildUnitPolicyResult(ctx, modOptions, canShare)
	local stunSeconds = tonumber(modOptions[ModeEnums.ModOptions.UnitShareStunSeconds]) or 0
	local stunCategory = modOptions[ModeEnums.ModOptions.UnitStunCategory] or ModeEnums.UnitFilterCategory.Resource
	local buildDelaySeconds = tonumber(modOptions[ModeEnums.ModOptions.ConstructorBuildDelay]) or 0
	return {
		canShare = canShare,
		senderTeamId = ctx.senderTeamId,
		receiverTeamId = ctx.receiverTeamId,
		sharingModes = Helpers.ResolveSharingModes(ctx, modOptions),
		stunSeconds = stunSeconds,
		stunCategory = stunCategory,
		buildDelaySeconds = buildDelaySeconds,
		techBlocking = ctx.ext and ctx.ext.techBlocking or nil,
	}
end

Policies.Pipeline()
	-- Sender and receiver must be allied, the effective sharing modes must
	-- allow something, and (unless cheating) the receiver must have players.
	:Gate("UnitCanShareGate", function(ctx)
		local modOptions = ctx.springRepo.GetModOptions()
		local modes = Helpers.ResolveSharingModes(ctx, modOptions)
		local canShare = ctx.areAlliedTeams and not (#modes == 1 and modes[1] == ModeEnums.UnitFilterCategory.None)
		if canShare and not ctx.isCheatingEnabled and not Helpers.TeamActive(ctx.springRepo, ctx.receiverTeamId) then
			canShare = false
		end
		if canShare then
			return nil
		end
		return buildUnitPolicyResult(ctx, modOptions, false)
	end)
	-- The gate passed: build the pair's allowed UnitPolicyResult.
	:Compute("ComputeUnitPolicy", function(ctx)
		return buildUnitPolicyResult(ctx, ctx.springRepo.GetModOptions(), true)
	end)
	:Register()
