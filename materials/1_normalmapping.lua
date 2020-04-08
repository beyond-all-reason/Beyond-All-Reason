-- $Id$
--------------------------------------------------------------------------------

local default_aux = VFS.Include("materials/Shaders/default_aux.lua")
local default_lua = VFS.Include("materials/Shaders/default.lua")

local matTemplate = {
	shaderDefinitions = {
		"#define use_normalmapping",
		"#define deferred_mode 0",
		"#define flashlights",
		"#define use_vertex_ao",

		"#define SHADOW_SOFTNESS SHADOW_SOFT",

		"#define SUNMULT pbrParams[6]",
		"#define EXPOSURE pbrParams[7]",

		"#define SPECULAR_AO",

		"#define ROUGHNESS_AA 1.0",

		--"#define ROUGHNESS_PERTURB_NORMAL 0.025",
		--"#define ROUGHNESS_PERTURB_COLOR 0.05",

		"#define ENV_SMPL_NUM " .. tostring(Spring.GetConfigInt("ENV_SMPL_NUM", 64)),
		"#define USE_ENVIRONMENT_DIFFUSE 1",
		"#define USE_ENVIRONMENT_SPECULAR 1",

		--"#define GAMMA 2.2",
		"#define TONEMAP(c) CustomTM(c)",
	},
	deferredDefinitions = {
		"#define use_normalmapping",
		"#define deferred_mode 1",
		"#define flashlights",
		"#define use_vertex_ao",

		"#define SHADOW_SOFTNESS SHADOW_HARD",

		"#define SUNMULT pbrParams[6]",
		"#define EXPOSURE pbrParams[7]",

		"#define SPECULAR_AO",

		"#define ROUGHNESS_AA 1.0",

		--"#define ROUGHNESS_PERTURB_NORMAL 0.025",
		--"#define ROUGHNESS_PERTURB_COLOR 0.05",

		"#define ENV_SMPL_NUM " .. tostring(Spring.GetConfigInt("ENV_SMPL_NUM", 64)),
		"#define USE_ENVIRONMENT_DIFFUSE 1",
		"#define USE_ENVIRONMENT_SPECULAR 1",

		--"#define GAMMA 2.2",
		"#define TONEMAP(c) CustomTM(c)",

		"#define MAT_IDX 1",
	},
	shaderPlugins = default_aux.scavDisplacementPlugin,
	shader    = default_lua,
	deferred  = default_lua,
	usecamera = false,
	force = true,
	culling = GL.BACK,
	predl  = nil,
	postdl = nil,
	texunits  = {
		[0] = "%TEX1",
		[1] = "%TEX2",
		[2] = "$shadow",
		[3] = "$reflection",
		[4] = "%NORMALTEX",
		[5] = "$info",
		[6] = GG.GetBrdfTexture(),
		[7] = GG.GetEnvTexture(),
	},
	SunChanged = default_aux.SunChanged,
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local materials = {}
local unitMaterials = {}

local function PackTableIntoString(tbl, str0)
	local str = str0 or ""
	for k, v in pairs(tbl) do
		str = string.format("%s|%s=%s|", str, tostring(k), tostring(v))
	end
	return str
end

for i = 1, #UnitDefs do
	local udef = UnitDefs[i]
	local udefCM = udef.customParams

	if udef.modCategories['tank'] == nil and udefCM.normaltex and VFS.FileExists(udefCM.normaltex) then
		default_aux.FillMaterials(unitMaterials, materials, matTemplate, "normalMappedS3O", i)
	end
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

return materials, unitMaterials

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
