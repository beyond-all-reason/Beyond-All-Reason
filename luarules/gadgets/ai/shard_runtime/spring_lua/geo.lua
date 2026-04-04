local function GetGeos()
	local geos = {}
	local i = 1
	local features = SpringShared.GetAllFeatures()
	for ct=1,#features do
		local featureID = features[ct]
		local featureDefID = SpringShared.GetFeatureDefID(featureID)
		if FeatureDefs[featureDefID].geoThermal == true then
			local x, y, z = SpringShared.GetFeaturePosition(featureID)
			local spot = {x = x, z = z, y = SpringShared.GetGroundHeight(x,z)}
			geos[i] = spot
			i = i + 1
		end
	end
	return geos
end

local spots = GetGeos()

return spots
