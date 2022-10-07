function gadget:GetInfo()
	return {
		name = "Feature Death Explosion",
		author = "Damgam",
		date = "2022",
		license = "GNU GPL, v2 or later",
		layer = -79,
		enabled = true,
	}
end

if gadgetHandler:IsSyncedCode() then

    local effectsTable = {
        [1] = {ceg = "corpsedestroyed", sound = "xplodragmetal"},
        [2] = {ceg = "corpsedestroyed", sound = "xplodragmetal"},
        [3] = {ceg = "corpsedestroyed", sound = "xplodragmetal"},
        [4] = {ceg = "corpsedestroyed", sound = "xplodragmetal"},
        [5] = {ceg = "corpsedestroyed", sound = "xplodragmetal"},
    }

	local isCorpse = {}
	for featureDefID, featureDef in pairs(FeatureDefs) do
		if featureDef.customParams.category and featureDef.customParams.category == 'corpses' then
			isCorpse[featureDefID] = true
		end
	end

    function gadget:FeatureDestroyed(featureID, allyTeamID)
        local featureDefID = Spring.GetFeatureDefID(featureID)
        if isCorpse[featureDefID] then
            local _, _, resurrectProgress = Spring.GetFeatureHealth(featureID)
            if resurrectProgress < 0.98 then
                local fsize
                local x,y,z = Spring.GetFeaturePosition (featureID)
                if FeatureDefs[featureDefID].footprintX then
                    fsize = FeatureDefs[featureDefID].footprintX
                else
                    fsize = 2
                end
                if fsize > 5 then fsize = 5 end
                fsize = math.ceil(fsize)
                --SPAWN CEG HERE
                Spring.SpawnCEG(effectsTable[fsize].ceg, x, y, z)
                Spring.PlaySoundFile(effectsTable[fsize].sound, 1, x, y, z, 'sfx')
            end
        end
    end
end
