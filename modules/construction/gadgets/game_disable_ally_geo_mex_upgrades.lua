local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Disable ally extractor upgrade",
		desc = "Removes the ability for players to upgrade teammate mexes and geos in-place",
		author = "Hobo Joe",
		date = "August 2025",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local ConstructionEnums = VFS.Include("modules/construction/enums.lua")
local UnitCategories = VFS.Include("modules/construction/lib/unit_categories.lua")
local ModuleHandler = VFS.Include("modules/module_handler.lua")
local Modules = VFS.Include("modules/enums.lua").Modules

local mode = Spring.GetModOptions().unit_sharing_mode
local modeUnitTypes = UnitCategories.TypesFor(mode)
local utilitySharing = table.contains(modeUnitTypes, ConstructionEnums.UnitType.Utility)

local pipelines = ModuleHandler.LoadPolicies(Modules.Construction) ---@type ConstructionPipelines

local extractorRadius = Game.extractorRadius

local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitTeam = Spring.GetUnitTeam

local extractorKind = {} ---@type table<integer, "mex"|"geo">
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.extractsMetal > 0 then
		extractorKind[unitDefID] = "mex"
	elseif unitDef.customParams.geothermal then
		extractorKind[unitDefID] = "geo"
	end
end

---@param kind "mex"|"geo"
---@param myTeam integer
---@return boolean
local function otherTeamsExtractorNearby(kind, myTeam, x, z)
	local units = spGetUnitsInCylinder(x, z, extractorRadius)
	for _, unitID in ipairs(units) do
		if extractorKind[spGetUnitDefID(unitID)] == kind and spGetUnitTeam(unitID) ~= myTeam then
			return true
		end
	end
	return false
end

function gadget:AllowUnitCreation(unitDefID, builderID, builderTeam, x, y, z)
	local kind = extractorKind[unitDefID]
	---@type ConstructionPlacementContext
	local ctx = {
		unitDefID = unitDefID,
		builderTeam = builderTeam,
		x = x,
		y = y,
		z = z,
		extractor = kind,
		alliedExtractorNearby = kind ~= nil and otherTeamsExtractorNearby(kind, builderTeam, x, z),
		utilitySharing = utilitySharing,
	}
	return ModuleHandler.Evaluate(pipelines.placement, ctx) == true
end
