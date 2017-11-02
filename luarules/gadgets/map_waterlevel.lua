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
		layer     = -1,	--higher layer is loaded last
		enabled   = true,  
	}
end


if (gadgetHandler:IsSyncedCode()) then


function gadget:Initialize()
	if Spring.GetModOptions() and Spring.GetModOptions().map_waterlevel and Spring.GetModOptions().map_waterlevel ~= "0" then
		local miny, maxy = Spring.GetGroundExtremes()
				if Spring.GetModOptions() and Spring.GetModOptions().map_waterlevel == "-1" then
					Spring.AdjustHeightMap(0, 0, Game.mapSizeX, Game.mapSizeZ, -miny+100)
				else
					local waterlevel1 = ((Spring.GetModOptions() and tonumber(Spring.GetModOptions().map_waterlevel))/100)
					if miny >= 0 then
						local delta = maxy-miny
						waterlevel = miny + (math.abs(delta*waterlevel1))
						Spring.AdjustHeightMap(0, 0, Game.mapSizeX, Game.mapSizeZ, -waterlevel)
					elseif miny < 0 then
						Spring.AdjustHeightMap(0, 0, Game.mapSizeX, Game.mapSizeZ, -miny)
						local delta = maxy - miny
						waterlevel = 0 + (math.abs(delta*waterlevel1))
						Spring.AdjustHeightMap(0, 0, Game.mapSizeX, Game.mapSizeZ, -waterlevel)
				end
			end
		featuretable = Spring.GetAllFeatures()
		for i = 1,#featuretable do
		featureDefID = Spring.GetFeatureDefID(featuretable[i])
		x,_,z = Spring.GetFeaturePosition(featuretable[i])
		Spring.SetFeaturePosition(featuretable[i], x,Spring.GetGroundHeight(x,z), z)
			if featureDefID >= 597 and featureDefID <= 613 then -- engine trees
				Spring.DestroyFeature(featuretable[i])
				if Spring.GetGroundHeight(x,z) >= 0 then
				Spring.CreateFeature(featureDefID, x, Spring.GetGroundHeight(x,z), z)
				end
			end
		end
	end
end
end


