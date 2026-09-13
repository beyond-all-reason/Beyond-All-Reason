local ConstructionEnums = VFS.Include("modules/construction/enums.lua")
local ModuleHandler = VFS.Include("modules/module_handler.lua")
local Modules = VFS.Include("modules/enums.lua").Modules
local Shared = VFS.Include("modules/transfer/unit/shared.lua")

local Synced = {
	ValidateUnits = Shared.ValidateUnits,
	GetModeUnitTypes = Shared.GetModeUnitTypes,
}

---@param ctx TransferPolicyContext
---@return UnitPolicyResult
function Synced.GetPolicy(ctx)
	local pipelines = ModuleHandler.LoadPolicies(Modules.Transfer) ---@type TransferPipelines
	return ModuleHandler.Evaluate(pipelines.unit_transfer, ctx)
end

---@param springRepo Spring
---@param teamId integer
---@return boolean
local function teamActive(springRepo, teamId)
	local n = springRepo.GetTeamRulesParam(teamId, "numActivePlayers")
	if n == nil then
		return true
	end
	return tonumber(n) ~= 0
end

---@param springRepo Spring
---@param teamId integer
---@param ctx TransferPolicyContext self-context (sender==receiver==teamId) so the enricher resolves the team's modes
function Synced.CacheTeamFactor(springRepo, teamId, ctx)
	local modes = ctx.unitSharingModes
		or { springRepo.GetModOptions().unit_sharing_mode or ConstructionEnums.UnitFilterCategory.None }
	Shared.UnitFactor.Write(springRepo, teamId, { sharingModes = modes, active = teamActive(springRepo, teamId) })
end

return Synced
