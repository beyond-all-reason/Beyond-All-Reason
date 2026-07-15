local Enums = VFS.Include("modules/sharing/enums.lua")
local Shared = VFS.Include("modules/sharing/unit/shared.lua")
local PolicyEvents = VFS.Include("modules/sharing/policy_events.lua")
local Helpers = VFS.Include("modules/sharing/helpers.lua")

--- Per-team unit factor cache: each team's tech-resolved sharing modes + active
--- flag serialized into team rules params; pair policies are rebuilt from
--- factors on read (Shared mirror of the unit policy pipeline semantics).

local M = {}

---Compute and cache one team's unit factor: its tech-resolved sharing modes + active flag.
---@param springRepo EngineSynced
---@param teamId integer
---@param ctx PolicyContext self-context (sender==receiver==teamId) so the enricher resolves the team's modes
function M.CacheTeamFactor(springRepo, teamId, ctx)
	local modes = Shared.ResolveSharingModes(ctx, springRepo.GetModOptions())
	local serialized = Shared.SerializeUnitFactor({
		sharingModes = modes,
		active = Helpers.TeamActive(springRepo, teamId),
	})
	springRepo.SetTeamRulesParam(teamId, Shared.MakeFactorKey(), serialized)
	PolicyEvents.NotifyIfChanged(teamId, Enums.PolicyType.UnitTransfer, serialized)
end

return M
