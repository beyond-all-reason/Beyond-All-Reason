--- Whether these two teams may hand units over, and on what terms.
---
--- Unlike resources there is no early deny here: the answer is always a
--- record, and canShare is a field in it, because the callers need the stun
--- and delay terms even when the transfer itself is refused (the tooltip
--- explains WHY it is refused). So this pipeline is one Compute and the gates
--- are the conditions inside it — named, and separable the moment a caller
--- wants a reason code instead of a boolean.

local ModeEnums = VFS.Include("modules/context/mode_enums.lua")

local NONE = ModeEnums.UnitFilterCategory.None

---@param ctx PolicyContext
---@param modes string[]
---@return boolean
local function sharingIsOn(ctx, modes)
	if not ctx.areAlliedTeams then
		return false
	end
	-- One mode, and it is None: the mode grammar's way of saying denied.
	return not (#modes == 1 and modes[1] == NONE)
end

---@param ctx PolicyContext
---@return boolean
local function receiverHasPlayers(ctx)
	if ctx.isCheatingEnabled then
		return true
	end
	local numActivePlayers = ctx.springRepo.GetTeamRulesParam(ctx.receiverTeamId, "numActivePlayers")
	return numActivePlayers == nil or tonumber(numActivePlayers) ~= 0
end

Policies.Pipeline()
	:Compute("ModeTermsAndReach", function(ctx)
		local modOptions = ctx.springRepo.GetModOptions()
		local modes = ctx.unitSharingModes or { modOptions.unit_sharing_mode or NONE }
		return {
			canShare = sharingIsOn(ctx, modes) and receiverHasPlayers(ctx),
			senderTeamId = ctx.senderTeamId,
			receiverTeamId = ctx.receiverTeamId,
			sharingModes = modes,
			stunSeconds = tonumber(modOptions[ModeEnums.ModOptions.UnitShareStunSeconds]) or 0,
			stunCategory = modOptions[ModeEnums.ModOptions.UnitStunCategory] or ModeEnums.UnitFilterCategory.Resource,
			buildDelaySeconds = tonumber(modOptions[ModeEnums.ModOptions.ConstructorBuildDelay]) or 0,
			techBlocking = ctx.ext and ctx.ext.techBlocking or nil,
		}
	end)
	:Register()
