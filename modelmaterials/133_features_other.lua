local matTemplate = VFS.Include("ModelMaterials/Templates/defaultMaterialTemplate.lua")

local materials = {
	featuresOther = table.merge(matTemplate, {
		texUnits  = {
			[0] = "%%FEATUREDEFID:0",
			[1] = "%%FEATUREDEFID:1",
		},
		feature = true,
		shaderDefinitions = {
			"#define RENDERING_MODE 0",
			"#define SUNMULT 1.0",
			--"#define EXPOSURE 1.0",

			"#define METALNESS 0.2",
			"#define ROUGHNESS 0.6",

			--"#define USE_ENVIRONMENT_DIFFUSE",
			--"#define USE_ENVIRONMENT_SPECULAR",

			"#define TONEMAP(c) CustomTM(c)",
		},
		deferredDefinitions = {
			"#define RENDERING_MODE 1",
			"#define SUNMULT 1.0",
			--"#define EXPOSURE 1.0",

			"#define METALNESS 0.2",
			"#define ROUGHNESS 0.6",

			--"#define USE_ENVIRONMENT_DIFFUSE",
			--"#define USE_ENVIRONMENT_SPECULAR",

			"#define TONEMAP(c) CustomTM(c)",
		},
		shaderOptions = {
			autonormal = true,
			autoNormalParams = {1.5, 0.005},
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
