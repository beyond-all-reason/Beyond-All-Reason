local gadget = gadget ---@type Gadget

local GlobalEnums = VFS.Include("modes/global_enums.lua")

local allowPartialResurrection = Spring.GetModOptions()[GlobalEnums.ModOptions.AllowPartialResurrection]

function gadget:GetInfo()
	return {
		name    = 'Restrict Partial Resurrection',
		desc    = 'Prevents resurrecting partly reclaimed wrecks.',
		author  = 'RebelNode',
		date    = 'January 2026',
		license = 'GNU GPL, v2 or later',
		layer   = 0,
		enabled = not allowPartialResurrection
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

if allowPartialResurrection then
	return false
end

function gadget:AllowFeatureBuildStep(builderID, builderTeam, featureID, featureDefID, part)
	if part < 0 then
		local metal, defMetal = Spring.GetFeatureResources(featureID)
		if metal == defMetal then
			Spring.SetFeatureResurrect(featureID, false)
		end
	end
	return true
end
