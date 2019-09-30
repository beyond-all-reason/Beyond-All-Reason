-- $Id$
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function DrawFeature(featureID, featureDefID, material, drawMode, luaShaderObj) -- UNUSED!
  local wx, wy, wz = Spring.GetWind()
  luaShaderObj:SetUniformAlways("wind", wx, wy, wz)

  return false
end

local function SunChanged(curShaderObj)
	curShaderObj:SetUniformAlways("shadowDensity", gl.GetSun("shadowDensity" ,"unit"))

	curShaderObj:SetUniformAlways("sunAmbient", gl.GetSun("ambient" ,"unit"))
	curShaderObj:SetUniformAlways("sunDiffuse", gl.GetSun("diffuse" ,"unit"))
	curShaderObj:SetUniformAlways("sunSpecular", gl.GetSun("specular" ,"unit"))
	--gl.Uniform(gl.GetUniformLocation(curShader, "sunSpecularExp"), gl.GetSun("specularExponent" ,"unit"))
end

local spGetMapDrawMode = Spring.GetMapDrawMode
local function DrawGenesis(curShaderObj)
	local inLosMode = ((spGetMapDrawMode() or "") == "los" and 1.0) or 0.0
	curShaderObj:SetUniform("inLosMode", inLosMode)
end


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

			"#define SPECULARMULT 2.0",

			"#define METALNESS 0.2",
			"#define ROUGHNESS 0.9",

			"#define USE_ENVIRONMENT_DIFFUSE",
			"#define USE_ENVIRONMENT_SPECULAR",

			"#define DO_GAMMA_CORRECTION",
			"#define TONEMAP(c) SteveMTM1(c)",
		},
		deferredDefinitions = {
			--"#define use_normalmapping", --very expensive for trees (too much overdraw)
			"#define deferred_mode 1",

			"#define USE_LOSMAP",

			"#define SHADOW_SOFTNESS SHADOW_HARD", -- cuz shadow for swaying trees is bugged anyway

			"#define SPECULARMULT 2.0",

			"#define METALNESS 0.5",
			"#define ROUGHNESS 0.5",

			"#define USE_ENVIRONMENT_DIFFUSE",
			"#define USE_ENVIRONMENT_SPECULAR",

			"#define DO_GAMMA_CORRECTION",
			"#define TONEMAP(c) SteveMTM1(c)",

			"#define MAT_IDX 129",
		},
		shaderPlugins = {
			VERTEX_GLOBAL_NAMESPACE = [[
				vec2 getWind(int period) {
					vec2 wind;
					wind.x = sin(period * 5.0);
					wind.y = cos(period * 5.0);
					return wind * 12.0f;
				}
			]],
			VERTEX_PRE_TRANSFORM = [[
				// adapted from 0ad's model_common.vs

				vec2 curWind = getWind(simFrame / 750);
				vec2 nextWind = getWind(simFrame / 750 + 1);
				float tweenFactor = smoothstep(0.0f, 1.0f, max(simFrame % 750 - 600, 0) / 150.0f);
				vec2 wind = mix(curWind, nextWind, tweenFactor);




				// fractional part of model position, clamped to >.4
				vec4 modelPos = gl_ModelViewMatrix[3];
				modelPos = fract(modelPos);
				modelPos = clamp(modelPos, 0.4, 1.0);

				// crude measure of wind intensity
				float abswind = abs(wind.x) + abs(wind.y);

				vec4 cosVec;
				float simTime = 0.02 * simFrame;
				// these determine the speed of the wind's "cosine" waves.
				cosVec.w = 0.0;
				cosVec.x = simTime * modelPos[0] + vertex.x;
				cosVec.y = simTime * modelPos[2] / 3.0 + modelPos.x;
				cosVec.z = simTime * 1.0 + vertex.z;

				// calculate "cosines" in parallel, using a smoothed triangle wave
				vec4 tri = abs(fract(cosVec + 0.5) * 2.0 - 1.0);
				cosVec = tri * tri *(3.0 - 2.0 * tri);

				float limit = clamp((vertex.x * vertex.z * vertex.y) / 3000.0, 0.0, 0.2);

				float diff = cosVec.x * limit;
				float diff2 = cosVec.y * clamp(vertex.y / 30.0, 0.05, 0.2);

				vertex.xyz += cosVec.z * limit * clamp(abswind, 1.2, 1.7);

				vertex.xz += diff + diff2 * wind;
			]]
		},
		feature = true, --// This is used to define that this is a feature shader
		usecamera = false,
		force = true,
		culling   = GL.BACK,
		texunits  = {
			[0] = '%%FEATUREDEFID:0',
			[1] = '%%FEATUREDEFID:1',
			[2] = '$shadow',
			[4] = '$reflection',
			[5] = "%NORMALTEX",
			[6] = "$info",
			[7] = GG.GetBrdfTexture(),
		},
		--DrawFeature = DrawFeature,
		DrawGenesis = DrawGenesis,
		SunChanged = SunChanged,
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
	Spring.PreloadFeatureDefModel(id)
	for _,stub in ipairs (featureNameStubs) do
		if featureDef.model.textures and featureDef.model.textures.tex1 and featureDef.name and featureDef.name:find(stub) and featureDef.name:find(stub) == 1 then --also starts with
			if featureDef.name:find('btree') == 1 then --beherith's old trees suffer if they get shitty normals
				featureMaterials[featureDef.name] = {"feature_tree_normalmap", NORMALTEX = "unittextures/blank_normal.dds"}
			else
				featureMaterials[featureDef.name] = {"feature_tree_normalmap", NORMALTEX = "unittextures/default_tree_normal.dds"}
			end
		end
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

return materials, featureMaterials

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
