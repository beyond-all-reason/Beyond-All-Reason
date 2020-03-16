local matTemplate = VFS.Include("ModelMaterials/Templates/defaultMaterialTemplate.lua")

local materials = {
	features3do = Spring.Utilities.MergeWithDefault(matTemplate, {
		texUnits  = {
			[0] = "$units1",
			[1] = "$units2",
		},
		feature = true,
		shaderOptions = {
			autonormal = true,
			autoNormalParams = {0.250, 0.001},
		},
		deferredOptions = {
			materialIndex = 254,
		},
		culling = false,
	})
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local cusFeaturesMaterials = GG.CUS.featureMaterialDefs
local featureMaterials = {}

for id = 1, #FeatureDefs do
	local fdef = FeatureDefs[id]
	if not cusFeaturesMaterials[id] and fdef.modeltype == "3do" then
		featureMaterials[id] = {"features3do"}
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

return materials, featureMaterials

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
