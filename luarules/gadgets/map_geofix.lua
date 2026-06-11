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
		local features = Engine.Shared.GetAllFeatures()
		for i = 1, #features do
			if geoFeatureDefs[Engine.Shared.GetFeatureDefID(features[i])] then
				local x, y, z = Engine.Shared.GetFeaturePosition(features[i])
				Engine.Synced.SetFeaturePosition(features[i], x, Engine.Shared.GetGroundHeight(x, z), z, true) -- snaptoground = true
			end
		end
		gadgetHandler:RemoveGadget(self)
	end
end
