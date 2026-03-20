local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = 'Restrict unit resurrection',
		desc    = 'Disable resurrecting partly reclaimed wrecks when modoption enabled.',
		author  = 'RebelNode',
		date    = 'January 2026',
		license = 'GNU GPL, v2 or later',
		layer   = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

if not Spring.GetModOptions().easytax then
	return false
end

function gadget:AllowFeatureBuildStep(builderID, builderTeam, featureID, featureDefID, part)
    if part < 0 then -- We are reclaiming some wreck
		metal, defMetal, _, _, _, _ = Spring.GetFeatureResources(featureID)
		if metal == defMetal then -- It's the first time we are touching this wreck/feature to reclaim it, i.e. we don't need to call SetFeatureResurrect every frame once we already set the wreck as non-resurrectable. Is this check actually faster than just always calling it?
			Spring.SetFeatureResurrect(featureID, false) -- Set the wreck as non-resurrectable
		end
	end
	return true
end
