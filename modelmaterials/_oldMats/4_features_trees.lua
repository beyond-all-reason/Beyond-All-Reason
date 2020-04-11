-- $Id$
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function DrawFeature(featureID, featureDefID, material, drawMode, luaShaderObj) -- UNUSED!
  local wx, wy, wz = Spring.GetWind()
  luaShaderObj:SetUniformAlways("wind", wx, wy, wz)

  return false
end

local spGetMapDrawMode = Spring.GetMapDrawMode
local function DrawGenesis(curShaderObj)
	local inLosMode = ((spGetMapDrawMode() or "") == "los" and 1.0) or 0.0
	curShaderObj:SetUniform("inLosMode", inLosMode)
end


local default_aux = VFS.Include("materials/Shaders/default_aux.lua")
local default_lua = VFS.Include("materials/Shaders/default.lua")

local materials = {
	feature_tree_normalmap = {
		shader    = default_lua,
		deferred  = default_lua,
		shaderDefinitions = {
			"#define use_normalmapping",
			"#define deferred_mode 0",

			"#define USE_LOSMAP",

			"#define SHADOW_SOFTNESS SHADOW_HARD", -- cuz shadow for swaying trees is bugged anyway

			"#define SUNMULT 1.5",
			--"#define EXPOSURE 1.0",

			"#define METALNESS 0.1",
			"#define ROUGHNESS 0.8",
			"#define EMISSIVENESS 0.0",

			--"#define USE_ENVIRONMENT_DIFFUSE",
			--"#define USE_ENVIRONMENT_SPECULAR",

			--"#define GAMMA 2.2",
			--"#define TONEMAP(c) ACESFilmicTM(c)",
		},
		deferredDefinitions = {
			--"#define use_normalmapping", --very expensive for trees (too much overdraw)
			"#define deferred_mode 1",

			"#define USE_LOSMAP",

			"#define SHADOW_SOFTNESS SHADOW_HARD", -- cuz shadow for swaying trees is bugged anyway

			"#define SUNMULT 1.5",
			--"#define EXPOSURE 1.0",

			"#define METALNESS 0.1",
			"#define ROUGHNESS 0.8",
			"#define EMISSIVENESS 0.0",

			--"#define USE_ENVIRONMENT_DIFFUSE",
			--"#define USE_ENVIRONMENT_SPECULAR",

			--"#define GAMMA 2.2",
			--"#define TONEMAP(c) SteveMTM1(c)",

			"#define MAT_IDX 129",
		},
		shaderPlugins = default_aux.treeDisplacementPlugun,
		feature = true, --// This is used to define that this is a feature shader
		usecamera = false,
		force = true,
		culling = GL.BACK,
		texunits  = {
			[0] = '%%FEATUREDEFID:0',
			[1] = '%%FEATUREDEFID:1',
			[2] = "$shadow",
			[3] = "$reflection",
			[4] = "%NORMALTEX",
			[5] = "$info",
			[6] = GG.GetBrdfTexture(),
			[7] = GG.GetEnvTexture(),
		},
		--DrawFeature = DrawFeature,
		DrawGenesis = DrawGenesis,
		SunChanged = default_aux.SunChanged,
	}
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- affected unitdefs

local featureNameStubs = {
	"ad0_",
	"btree",
	"art",
	"bush",
	"tree",
	"vegetation",
	"vegitation",
	"baobab",
	"aleppo",
	"pine",
	"senegal",
	"palm",
	"shrub",
	"bloodthorn",
	"birch",
	"maple",
	"oak",
	"fern",
	"grass",
	"weed",
	"plant",
	"palmetto",
	"lowpoly_tree",
} -- This list should cover all vegetative features in spring features

local featureMaterials = {}


for id, featureDef in pairs(FeatureDefs) do

	--Spring.Echo("Parsed feature",featureDef.name)
	if featureDef.customParams and featureDef.customParams.normaltex then
		featureMaterials[id] = {"feature_tree_normalmap", NORMALTEX = featureDef.customParams.normaltex}
		--Spring.Echo("Parsed feature",featureDef.name,"and added normal map",featureDef.customParams.normaltex)
	else
		for _,stub in ipairs (featureNameStubs) do
			if featureDef.model.textures and featureDef.model.textures.tex1 and featureDef.name and featureDef.name:find(stub) and featureDef.name:find(stub) == 1 then --also starts with
				if featureDef.name:find('btree') == 1 then --beherith's old trees suffer if they get shitty normals
					featureMaterials[id] = {"feature_tree_normalmap", NORMALTEX = "unittextures/blank_normal.dds"}
				else
					featureMaterials[id] = {"feature_tree_normalmap", NORMALTEX = "unittextures/default_tree_normal.dds"}
				end
			end
		end
	end

end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

return materials, featureMaterials

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
