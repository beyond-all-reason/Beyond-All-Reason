local Enums = VFS.Include("modules/sharing/enums.lua")
local Shared = VFS.Include("modules/sharing/unit/shared.lua")
local PolicyEvents = VFS.Include("modules/sharing/policy_events.lua")
local Helpers = VFS.Include("modules/sharing/helpers.lua")
local ModuleHandler = VFS.Include("modules/module_handler.lua")

local Synced = {
	ValidateUnits = Shared.ValidateUnits,
	GetModeUnitTypes = Shared.GetModeUnitTypes,
}

-- The share gate + terminal compute live in modules/sharing/policies/unit/
-- (one pure policy per file, filename order); the transfer executor lives in
-- modules/sharing/actions/unit_transfer.lua. Loaded lazily so including this
-- library stays cheap.
local unitPolicies ---@type PolicyDescriptor[]|nil
local function getUnitPolicies()
	if not unitPolicies then
		unitPolicies = ModuleHandler.LoadPolicies("sharing").unit or {}
	end
	return unitPolicies
end

local UnitTransferAction = ModuleHandler.Include("modules/sharing/actions/unit_transfer.lua")

---Build per-pair policy (expose) from context
---@param ctx PolicyContext
---@return UnitPolicyResult
function Synced.GetPolicy(ctx)
	return ModuleHandler.Evaluate(getUnitPolicies(), ctx) --[[@as UnitPolicyResult]]
end

---Execute unit transfer with pre-validated units
---@param ctx UnitTransferContext
---@return UnitTransferResult
function Synced.UnitTransfer(ctx)
	return UnitTransferAction.execute(ctx)
end

---Compute and cache one team's unit factor: its tech-resolved sharing modes + active flag.
---@param springRepo EngineSynced
---@param teamId integer
---@param ctx PolicyContext self-context (sender==receiver==teamId) so the enricher resolves the team's modes
function Synced.CacheTeamFactor(springRepo, teamId, ctx)
	local modes = Shared.ResolveSharingModes(ctx, springRepo.GetModOptions())
	local serialized = Shared.SerializeUnitFactor({
		sharingModes = modes,
		active = Helpers.TeamActive(springRepo, teamId),
	})
	springRepo.SetTeamRulesParam(teamId, Shared.MakeFactorKey(), serialized)
	PolicyEvents.NotifyIfChanged(teamId, Enums.PolicyType.UnitTransfer, serialized)
end

return Synced
