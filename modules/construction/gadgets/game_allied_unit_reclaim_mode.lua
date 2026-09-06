local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Allied Reclaim Control",
		desc = "Controls reclaiming allied units based on modoption",
		author = "Rimilel",
		date = "October 2025",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true,
	}
end

local ConstructionEnums = VFS.Include("modules/construction/enums.lua")

if not gadgetHandler:IsSyncedCode() then
	return false
end

local ModuleHandler = VFS.Include("modules/module_handler.lua")
local Modules = VFS.Include("modules/enums.lua").Modules

local reclaimEnabled = Spring.GetModOptions()[ConstructionEnums.ModOptions.AlliedUnitReclaimMode]
	== ConstructionEnums.AlliedUnitReclaimMode.Enabled

local pipelines = ModuleHandler.LoadPolicies(Modules.Construction) ---@type ConstructionPipelines

---@param unitTeam integer
---@param targetID integer
---@param command "reclaim"|"guard"
---@return boolean
local function mayReclaim(unitTeam, targetID, command)
	local targetTeam = Spring.GetUnitTeam(targetID)
	if targetTeam == nil then
		return true -- shouldn't happen; GetUnitTeam is nullable
	end
	local targetUnitDef = UnitDefs[Spring.GetUnitDefID(targetID)]
	---@type ConstructionReclaimContext
	local ctx = {
		allied = unitTeam ~= targetTeam and Spring.AreTeamsAllied(unitTeam, targetTeam),
		command = command,
		-- labs count as canReclaim, so guarding them counts too
		targetCanReclaim = (targetUnitDef and targetUnitDef.canReclaim) == true,
		reclaimEnabled = reclaimEnabled,
	}
	return ModuleHandler.Evaluate(pipelines.reclaim, ctx) == true
end

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD.RECLAIM)
	gadgetHandler:RegisterAllowCommand(CMD.GUARD)
end

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)
	if #cmdParams < 1 or cmdParams[1] >= Game.maxUnits then
		return true
	end
	if cmdID == CMD.RECLAIM then
		return mayReclaim(unitTeam, cmdParams[1], "reclaim")
	elseif cmdID == CMD.GUARD then
		return mayReclaim(unitTeam, cmdParams[1], "guard")
	end
	return true
end
