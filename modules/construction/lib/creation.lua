local GG = GG
local UnitDefs = UnitDefs

local ModuleHandler = require("modules/module_handler")
local Modules = require("modules/enums").Modules
local state = require("modules/construction/state")

local REASON = "construction_creation"

local Creation = {}

---@param teamID integer
---@param springRepo Spring
function Creation.Refresh(teamID, springRepo)
	---@type ConstructionContract
	local Construction = ModuleHandler.Contract(Modules.Construction)
	local blocking = GG and GG.BuildBlocking
	if not blocking then
		return
	end
	local modOptions = springRepo.GetModOptions()
	local facts = ModuleHandler.Enrich(
		Construction.CreationFacts,
		{ teamID = teamID, modOptions = modOptions, springRepo = springRepo }
	)
	local blocked = state.creationBlocked[teamID] or {}
	state.creationBlocked[teamID] = blocked
	for unitDefID, unitDef in pairs(UnitDefs) do
		---@type ConstructionCreationContext
		local ctx = {
			modOptions = modOptions,
			unitDefID = unitDefID,
			unitDef = unitDef,
			teamID = teamID,
			tier = facts[Construction.CreationFacts.Tier],
		}
		local allowed = ModuleHandler.Evaluate(Construction.Creation, ctx) == true
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
