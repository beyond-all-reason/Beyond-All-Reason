local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Geo fix",
		version = "",
		desc = "Makes geothermal features stick to ground level height (fixing broken maps like: Desert 3.25)",
		author = "Floris",
		date = "August 2021",
		license = "GNU GPL, v2 or later",
		layer = -1,
		enabled = true,
	}
end

if gadgetHandler:IsSyncedCode() then

	function gadget:GameFrame(gf)
		local geoFeatureDefs = {}
		for defID, def in pairs(FeatureDefs) do
			if def.geoThermal then
				geoFeatureDefs[defID] = true
			end
		end
		local features = SpringShared.GetAllFeatures()
		for i = 1, #features do
			if geoFeatureDefs[SpringShared.GetFeatureDefID(features[i])] then
				local x, y, z = SpringShared.GetFeaturePosition(features[i])
				SpringSynced.SetFeaturePosition(features[i], x, SpringShared.GetGroundHeight(x, z), z, true) -- snaptoground = true
			end
		end
		gadgetHandler:RemoveGadget(self)
	end

end
