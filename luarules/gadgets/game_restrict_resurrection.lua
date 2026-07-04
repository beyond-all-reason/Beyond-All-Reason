local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = 'Restrict unit resurrection',
		desc    = 'Disable resurrecting partly reclaimed wrecks when modoption enabled.',
		author  = 'RebelNode',
		date    = 'January 2026',
		license = 'GNU GPL, v2 or later',
		layer   = 0,
		enabled = false -- disabled for now and replaced with tax in game_tax_resource_sharing.lua, delete this gadget if decision not reverted later
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

if not Spring.GetModOptions().easytax then
	return false
end

local spGetFeatureResources = Spring.GetFeatureResources
local spSetFeatureResurrect = Spring.SetFeatureResurrect

function gadget:AllowFeatureBuildStep(builderID, builderTeam, featureID, featureDefID, part)
	if part >= 0 then
		return true
	end

	local metal, defMetal = spGetFeatureResources(featureID)
	if metal == defMetal then -- first reclaim touch on this wreck
		spSetFeatureResurrect(featureID, false)
	end
	return true
end
