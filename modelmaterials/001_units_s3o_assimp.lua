local matTemplate = VFS.Include("ModelMaterials/Templates/defaultMaterialTemplate.lua")

local unitsNewNormalMap = Spring.Utilities.MergeWithDefault(matTemplate, {
	texUnits  = {
		[0] = "%TEX1",
		[1] = "%TEX2",
		[4] = "%NORMALTEX",
	},
	shaderDefinitions = {
		"#define SUNMULT pbrParams[6]",
		"#define EXPOSURE pbrParams[7]",

		"#define SPECULAR_AO",

		"#define ROUGHNESS_AA 1.0",

		"#define ENV_SMPL_NUM " .. tostring(Spring.GetConfigInt("ENV_SMPL_NUM", 64)),
		"#define USE_ENVIRONMENT_DIFFUSE 1",
		"#define USE_ENVIRONMENT_SPECULAR 1",

		--"#define GAMMA 2.2",
		"#define TONEMAP(c) CustomTM(c)",
	},
	deferredDefinitions = {
		"#define SUNMULT pbrParams[6]",
		"#define EXPOSURE pbrParams[7]",

		"#define SPECULAR_AO",

		"#define ROUGHNESS_AA 1.0",

		"#define ENV_SMPL_NUM " .. tostring(Spring.GetConfigInt("ENV_SMPL_NUM", 64)),
		"#define USE_ENVIRONMENT_DIFFUSE 1",
		"#define USE_ENVIRONMENT_SPECULAR 1",

		--"#define GAMMA 2.2",
		"#define TONEMAP(c) CustomTM(c)",
	},
	shaderOptions = {
		normalmapping = true,
		flashlights = true,
		vertex_ao = true,
	},
	deferredOptions = {
		normalmapping = true,
		flashlights = true,
		vertex_ao = true,
		materialIndex = 1,
	},
})

local materials = {
	unitsNewNormalMap = unitsNewNormalMap,
}


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local cusUnitMaterials = GG.CUS.unitMaterialDefs
local unitMaterials = {}

for id = 1, #UnitDefs do
	local udef = UnitDefs[id]

	if not cusUnitMaterials[id] and udef.modeltype == "s3o" then
		local udefCM = udef.customParams
		local lm = tonumber(udefCM.lumamult) or 1
		local scvd = tonumber(udefCM.scavvertdisp) or 0

		local tex1 = "%%"..id..":0"
		local tex2 = "%%"..id..":1"
		local normalTex = udefCM.normaltex

		unitMaterials[id] = {"unitsNewNormalMap", TEX1 = tex1, TEX2 = tex2, NORMALTEX = normalTex}
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

return materials, unitMaterials

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
