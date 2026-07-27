local gadget = gadget ---@type Gadget

local ConstructionEnums = require("modules/construction/enums")
local ModuleHandler = require("modules/module_handler")
local Modules = require("modules/enums").Modules

local allowPartialResurrection = Spring.GetModOptions()[ConstructionEnums.ModOptions.AllowPartialResurrection]
	== ConstructionEnums.AllowPartialResurrection.Enabled

function gadget:GetInfo()
	return {
		name = "Allow Partial Resurrection",
		desc = "Whether a partly reclaimed wreck can still be resurrected, as construction's resurrect policy decides",
		author = "RebelNode",
		date = "January 2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local spGetFeatureResources = Spring.GetFeatureResources
local spSetFeatureResurrect = Spring.SetFeatureResurrect

function gadget:AllowFeatureBuildStep(builderID, builderTeam, featureID, featureDefID, part)
	---@type ConstructionContract
	local Construction = ModuleHandler.Contract(Modules.Construction)
	if part >= 0 then
		return true
	end

	local metal, defMetal = spGetFeatureResources(featureID)
	if metal == defMetal then
		---@type ConstructionResurrectContext
		local ctx = { partialAllowed = allowPartialResurrection }
		if not ModuleHandler.Evaluate(Construction.Resurrect, ctx) then
			spSetFeatureResurrect(featureID, false)
		end
	end
	return true
end
