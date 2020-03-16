local matTemplate = VFS.Include("ModelMaterials/Templates/defaultMaterialTemplate.lua")

local materials = {
	featuresFallback = Spring.Utilities.MergeWithDefault(matTemplate, {
		texUnits  = {
			[0] = "%%FEATUREDEFID:0",
			[1] = "%%FEATUREDEFID:1",
		},
		feature = true,
		deferredOptions = {
			materialIndex = 255,
		},
	})
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local cusFeaturesMaterials = GG.CUS.featureMaterialDefs
local featureMaterials = {}

for id = 1, #FeatureDefs do
	if not cusFeaturesMaterials[id] then
		Spring.Log(gadget:GetInfo().name, LOG.WARNING, string.format("Assigning featuresFallback material to feature %s. This should never happen.", FeatureDefs[id].name))
		featureMaterials[id] = {"featuresFallback"}
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

return materials, featureMaterials

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
