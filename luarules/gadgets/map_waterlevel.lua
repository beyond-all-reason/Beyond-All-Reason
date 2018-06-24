--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
	return {
		name      = "Map Waterlevel",
		version   = "v1",
		desc      = "Sets map waterlevel according to the modoption",
		author    = "Doo",
		date      = "Nov 2017", 
		license   = "GPL",
		layer     = math.huge,	--higher layer is loaded last
		enabled   = true,  
	}
end


if (gadgetHandler:IsSyncedCode()) then


function gadget:Initialize()
	if Spring.GetModOptions() and Spring.GetModOptions().map_waterlevel and Spring.GetModOptions().map_waterlevel ~= "0" then
		-- Spring.SetMapRenderingParams({ voidWater = false})
		local waterlevel = ((Spring.GetModOptions() and tonumber(Spring.GetModOptions().map_waterlevel)))
		Spring.AdjustHeightMap(0, 0, Game.mapSizeX, Game.mapSizeZ, -waterlevel)
		Spring.AdjustSmoothMesh(0, 0, Game.mapSizeX, Game.mapSizeZ, -waterlevel)
	end
end

function gadget:GamePreload()
	if Spring.GetModOptions() and Spring.GetModOptions().map_waterlevel and Spring.GetModOptions().map_waterlevel ~= "0" then --only move features if there was a waterlevel change
			featuretable = Spring.GetAllFeatures()
		for i = 1,#featuretable do
		featureDefID = Spring.GetFeatureDefID(featuretable[i])
		x,_,z = Spring.GetFeaturePosition(featuretable[i])
				Spring.DestroyFeature(featuretable[i])
				if (Spring.GetGroundHeight(x,z) >= 0) or (FeatureDefs[featureDefID].geoThermal == true) or (FeatureDefs[featureDefID].metal > 0) then -- Keep features (> 0 height) or (geovents) or (contains metal)
				Spring.CreateFeature(featureDefID, x, Spring.GetGroundHeight(x,z), z)
				end
		end
	end
end

end


