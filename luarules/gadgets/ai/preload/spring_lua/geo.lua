local function GetGeos()
	local geos = {}
	local i = 1
	for ct, featureID in pairs(Spring.GetAllFeatures()) do
		local featureDefID = Spring.GetFeatureDefID(featureID)
		if FeatureDefs[featureDefID].geoThermal == true then
			local x, y, z = Spring.GetFeaturePosition(featureID)
			local spot = {x = x, z = z, y = Spring.GetGroundHeight(x,z)}
			geos[i] = spot
			i = i + 1
		end
	end
	return geos
end

local spots = GetGeos()

return spots
