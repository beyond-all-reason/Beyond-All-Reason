local ModuleHandler = VFS.Include("modules/module_handler.lua")
local Modules = VFS.Include("modules/enums.lua").Modules
local Contract = VFS.Include("modules/construction/contract.lua") ---@type ConstructionContract
local state = VFS.Include("modules/construction/state.lua") ---@type ConstructionState

local REASON = "construction_creation"

local Creation = {}

---Re-decides every def for one team and applies the answers through
---GG.BuildBlocking, adding and removing only under construction's own reason.
---Called when a fact the decision reads has changed: tech calls it when a
---team's tier moves.
---@param teamID integer
---@param springRepo Spring
function Creation.Refresh(teamID, springRepo)
	local blocking = GG and GG.BuildBlocking
	if not blocking then
		return
	end
	local pipelines = ModuleHandler.LoadPolicies(Modules.Construction) ---@type ConstructionPipelines
	local facts =
		ModuleHandler.Enrich(Contract.CreationFacts, springRepo.GetModOptions(), { teamID = teamID }, springRepo)
	local blocked = state.creationBlocked[teamID] or {}
	state.creationBlocked[teamID] = blocked
	for unitDefID, unitDef in pairs(UnitDefs) do
		---@type ConstructionCreationContext
		local ctx =
			{ unitDefID = unitDefID, unitDef = unitDef, teamID = teamID, tier = facts[Contract.CreationFacts.Tier] }
		local allowed = ModuleHandler.Evaluate(pipelines.creation, ctx) == true
		if not allowed and not blocked[unitDefID] then
			blocking.AddBlockedUnit(unitDefID, teamID, REASON)
			blocked[unitDefID] = true
		elseif allowed and blocked[unitDefID] then
			blocking.RemoveBlockedUnit(unitDefID, teamID, REASON)
			blocked[unitDefID] = nil
		end
	end
end

return Creation
