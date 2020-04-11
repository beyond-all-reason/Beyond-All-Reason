local matTemplate = VFS.Include("ModelMaterials/Templates/defaultMaterialTemplate.lua")

local materials = {
	featuresOther = Spring.Utilities.MergeWithDefault(matTemplate, {
		texUnits  = {
			[0] = "%%FEATUREDEFID:0",
			[1] = "%%FEATUREDEFID:1",
		},
		feature = true,
		shaderOptions = {
			autonormal = true,
			autoNormalParams = {0.75, 0.03},
		},
		deferredOptions = {
			materialIndex = 133,
		},
	})
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local cusFeaturesMaterials = GG.CUS.featureMaterialDefs
local featureMaterials = {}

for id = 1, #FeatureDefs do
	local fdef = FeatureDefs[id]
	if not cusFeaturesMaterials[id] and fdef.modeltype ~= "3do" then
		featureMaterials[id] = {"featuresOther"}
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

return materials, featureMaterials

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
