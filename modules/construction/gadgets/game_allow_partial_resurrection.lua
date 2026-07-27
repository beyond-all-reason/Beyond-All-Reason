local gadget = gadget ---@type Gadget

local ModeEnums = VFS.Include("modules/context/mode_enums.lua")
local ModuleHandler = VFS.Include("modules/module_handler.lua")

local allowPartialResurrection = Spring.GetModOptions()[ModeEnums.ModOptions.AllowPartialResurrection]
	== ModeEnums.AllowPartialResurrection.Enabled

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

local pipelines = ModuleHandler.LoadPolicies("construction") ---@type ConstructionPipelines

function gadget:AllowFeatureBuildStep(builderID, builderTeam, featureID, featureDefID, part)
	if part >= 0 then
		return true
	end

	local metal, defMetal = spGetFeatureResources(featureID)
	if metal == defMetal then -- first reclaim touch on this wreck
		---@type ConstructionResurrectContext
		local ctx = { partialAllowed = allowPartialResurrection }
		if not ModuleHandler.Evaluate(pipelines.resurrect, ctx) then
			spSetFeatureResurrect(featureID, false)
		end
	end
	return true
end
