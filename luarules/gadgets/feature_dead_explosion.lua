function gadget:GetInfo()
	return {
		name = "Feature Death Explosion",
		desc = "123",
		author = "Damgam",
		date = "2022",
		layer = -100,
		enabled = true,
	}
end

if gadgetHandler:IsSyncedCode() then
    function gadget:FeatureDestroyed(featureID, allyTeamID)
        local featureDefID = Spring.GetFeatureDefID(featureID)
        local fname = FeatureDefs[featureDefID].name
        if string.find(fname, "_dead") then
            local _, _, resurrectProgress = Spring.GetFeatureHealth(featureID)
            if resurrectProgress < 0.98 then
                local fsize
                local x,y,z = Spring.GetFeaturePosition (featureID)
                if FeatureDefs[featureDefID].footprintX then
                    fsize = FeatureDefs[featureDefID].footprintX
                else
                    fsize = 2
                end
                --SPAWN CEG HERE
                if fsize <= 1 then
                    Spring.SpawnCEG("wallexplosion-metal", x, y, z)
                elseif fsize <= 2 then
                    Spring.SpawnCEG("wallexplosion-metal", x, y, z)
                elseif fsize <= 3 then
                    Spring.SpawnCEG("wallexplosion-metal", x, y, z)
                elseif fsize <= 4 then
                    Spring.SpawnCEG("wallexplosion-metal", x, y, z)
                elseif fsize <= 5 then
                    Spring.SpawnCEG("wallexplosion-metal", x, y, z)
                else -- bigger than 5
                    Spring.SpawnCEG("wallexplosion-metal", x, y, z)
                end
            end
        end
    end
else
    function gadget:FeatureDestroyed(featureID, allyTeamID)
        local featureDefID = Spring.GetFeatureDefID(featureID)
        local fname = FeatureDefs[featureDefID].name
        if string.find(fname, "_dead") then
            local _, _, resurrectProgress = Spring.GetFeatureHealth(featureID)
            if resurrectProgress < 0.98 then
                local x,y,z = Spring.GetFeaturePosition(featureID)
                --SPAWN SOUND HERE
                Spring.PlaySoundFile("xplodragmetal", 2, x, y, z, 'sfx')
            end
        end
    end
end