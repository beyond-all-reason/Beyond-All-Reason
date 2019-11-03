-- $Id$
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function SunChanged(curShaderObj)
	curShaderObj:SetUniformAlways("shadowDensity", gl.GetSun("shadowDensity" ,"unit"))

	curShaderObj:SetUniformAlways("sunAmbient", gl.GetSun("ambient" ,"unit"))
	curShaderObj:SetUniformAlways("sunDiffuse", gl.GetSun("diffuse" ,"unit"))
	curShaderObj:SetUniformAlways("sunSpecular", gl.GetSun("specular" ,"unit"))

	curShaderObj:SetUniformFloatArrayAlways("pbrParams", {
		Spring.GetConfigFloat("tonemapA", 0.0),
		Spring.GetConfigFloat("tonemapB", 1.0),
		Spring.GetConfigFloat("tonemapC", 0.0),
		Spring.GetConfigFloat("tonemapD", 0.0),
		Spring.GetConfigFloat("tonemapE", 1.0),
		Spring.GetConfigFloat("envAmbient", 0.5),
		Spring.GetConfigFloat("unitSunMult", 1.5),
		Spring.GetConfigFloat("unitExposureMult", 1.0),
	})
end


local default_lua = VFS.Include("materials/Shaders/default.lua")

local materials = {
	feature_wreck = {
		shader    = default_lua,
		deferred  = default_lua,
		shaderDefinitions = {
			"#define use_normalmapping",
			"#define deferred_mode 0",

			"#define SHADOW_SOFTNESS SHADOW_SOFT",

			"#define SUNMULT 1.0",
			--"#define EXPOSURE 1.0",

			--"#define METALNESS 0.0",
			"#define ROUGHNESS 0.6",

			--"#define USE_ENVIRONMENT_DIFFUSE",
			--"#define USE_ENVIRONMENT_SPECULAR",

			--"#define GAMMA 2.2",
			--"#define TONEMAP(c) SteveMTM1(c)",
		},
		deferredDefinitions = {
			"#define use_normalmapping",
			"#define deferred_mode 1",

			"#define SHADOW_SOFTNESS SHADOW_SOFT",

			"#define SUNMULT 1.0",
			--"#define EXPOSURE 1.0",

			--"#define METALNESS 0.0",
			"#define ROUGHNESS 0.6",

			--"#define USE_ENVIRONMENT_DIFFUSE",
			--"#define USE_ENVIRONMENT_SPECULAR",

			--"#define GAMMA 2.2",
			--"#define TONEMAP(c) SteveMTM1(c)",

			"#define MAT_IDX 128",
		},
		feature = true,
		usecamera = false,
		force = true,
		culling   = GL.BACK,
		texunits  = {
			[0] = '%%FEATUREDEFID:0',
			[1] = '%%FEATUREDEFID:1',
			[2] = '$shadow',
			[4] = '$reflection',
			[5] = '%NORMALTEX',
			[6] = "$info",
			[7] = GG.GetBrdfTexture(),
		},
		--DrawFeature = DrawFeature,
		SunChanged = SunChanged,
	},
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- affected featuredefs

local function FindNormalmap(tex1, tex2)
	local normaltex = nil
	-- Spring.Echo("searching for normals for",tex1)
	--// check if there is a corresponding _normals.dds file
	unittexttures = 'unittextures/'
	if (VFS.FileExists(unittexttures .. tex1)) and (VFS.FileExists(unittexttures .. tex2)) then
		normaltex = unittexttures .. tex1:gsub("%.","_normals.")
		-- Spring.Echo(normaltex)
		if (VFS.FileExists(normaltex)) then
			return normaltex
		end
		normaltex = unittexttures .. tex1:gsub("%.","_normal.")
		-- Spring.Echo(normaltex)
		if (VFS.FileExists(normaltex)) then
			return normaltex
		end
	end
	return nil
end


local featureMaterials = {}

for id, featureDef in pairs(FeatureDefs) do
	local isTree=false
	for _,stub in ipairs({"ad0_", "btree", "art"}) do
		if featureDef.name:find(stub) == 1 then
			isTree=true
			-- Spring.Echo(featureDef.name, 'is a tree')
		end
	end
	Spring.PreloadFeatureDefModel(id)
	-- how to check if its a wreck or a heap?

	if (not isTree) and featureDef.model.textures and featureDef.model.textures.tex1 and featureDef.modeltype == "s3o" then --its likely a proper feature
		if featureDef.name:find("_dead") then
			if featureDef.name == "cormaw_dead" or featureDef.name == "armclaw_dead" then
				--ignore these two edge cases.
			elseif featureDef.name == "freefusion_free_fusion_dead" then
				featureMaterials[featureDef.name] = {"feature_wreck", NORMALTEX = "unittextures/mission_command_tower_wreck_1_normal.dds"}
			elseif featureDef.model.textures.tex1:find("Arm_wreck") then
				featureMaterials[featureDef.name] = {"feature_wreck", NORMALTEX = "unittextures/Arm_wreck_color_normal.dds"}
				--Spring.Echo('Featuredef info for', featureDef.name, to_string(featureDef.model))
			elseif featureDef.model.textures.tex1:find("Core_color_wreck") then
				featureMaterials[featureDef.name] = {"feature_wreck", NORMALTEX = "unittextures/Core_color_wreck_normal.dds"}
			else
				--Spring.Echo("3_feature_wrecks: featureDef.name has _dead but doesnt have the correct tex1 defined!",featureDef.name, featureDef.model.textures.tex1,featureDef.model.textures.tex2)
			end
		elseif featureDef.model.textures.tex1 and featureDef.model.textures.tex2 then
			if FindNormalmap(featureDef.model.textures.tex1,featureDef.model.textures.tex2) then
				featureMaterials[featureDef.name] = {"feature_wreck", NORMALTEX = FindNormalmap(featureDef.model.textures.tex1,featureDef.model.textures.tex2)}
			end
		end
	end
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

return materials, featureMaterials

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
