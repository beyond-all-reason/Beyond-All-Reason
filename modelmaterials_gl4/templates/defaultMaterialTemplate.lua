local vssrc = VFS.LoadFile("modelmaterials_gl4/templates/cus_gl4.vert.glsl")

--local gssrc = VFS.LoadFile("modelmaterials_gl4/templates/cus_gl4.geom.glsl")

local fssrc = VFS.LoadFile("modelmaterials_gl4/templates/cus_gl4.frag.glsl")

local shaderTemplate = {

	vertex = vssrc,

	geometry = gssrc,

	fragment = fssrc,

	uniformInt = {
		texture1 	 = 0,
		texture2 	 = 1,
		normalTex    = 2,

		texture1w    = 3,
		texture2w    = 4,
		normalTexw   = 5,

		shadowTex    = 6,
		reflectTex   = 7,

		losMapTex    = 8,
		brdfLUT      = 9,
		noisetex3dcube = 10,
		envLUT = 11,
		-- envLUT       = 10, -- uncomment this if we want environment mapping back USE_ENVIRONMENT_DIFFUSE || USE_ENVIRONMENT_SPECULAR
	},
	uniformFloat = {

	},
}

-- local SKIN_SUPPORT = Script.IsEngineMinVersion(105, 0, 1653) and "1" or "0" -- SKIN_SUPPORT is now always on since 1653
local USEQUATERNIONS = (Engine.FeatureSupport.transformsInGL4 and "1") or "0"
local SLERPQUATERIONS = nil-- "#define SLERPQUATERIONS 1" -- nil to disable slerping and just use lerp

local defaultMaterialTemplate = {
	--standardUniforms --locs, set by api_cus
	--deferredUniforms --locs, set by api_cus

	shader     = shaderTemplate, -- `shader` is replaced with standardShader later in api_cus
	deferred   = shaderTemplate, -- `deferred` is replaced with deferredShader later in api_cus
	shadow     = shaderTemplate, -- `shadow` is replaced with deferredShader later in api_cus
	reflection = shaderTemplate, -- `shadow` is replaced with deferredShader later in api_cus

	-- note these definitions below are not inherited!!!
	-- they need to be redefined on every child material that has its own {shader,deferred,shadow}Definitions
	shaderDefinitions = {
		"#define RENDERING_MODE 0",
		"#define SUNMULT pbrParams[6]",
		"#define EXPOSURE pbrParams[7]",

		"#define SPECULAR_AO",

		"#define ROUGHNESS_AA 1.0",

		"#define ENV_SMPL_NUM " .. tostring(Spring.GetConfigInt("ENV_SMPL_NUM", 64)),
		"#define USE_ENVIRONMENT_DIFFUSE 1",
		"#define USE_ENVIRONMENT_SPECULAR 1",

		"#define TONEMAP(c) CustomTM(c)",
		"#define SHIFT_RGBHSV",
		"#define USEQUATERNIONS "..USEQUATERNIONS,
		SLERPQUATERIONS,
	},
	deferredDefinitions = {
		"#define RENDERING_MODE 1",
		"#define SUNMULT pbrParams[6]",
		"#define EXPOSURE pbrParams[7]",

		"#define SPECULAR_AO",

		"#define ROUGHNESS_AA 1.0",

		"#define ENV_SMPL_NUM " .. tostring(Spring.GetConfigInt("ENV_SMPL_NUM", 64)),
		"#define USE_ENVIRONMENT_DIFFUSE 1",
		"#define USE_ENVIRONMENT_SPECULAR 1",

		"#define TONEMAP(c) CustomTM(c)",
		"#define SHIFT_RGBHSV",
		"#define USEQUATERNIONS "..USEQUATERNIONS,
		SLERPQUATERIONS,
	},
	shadowDefinitions = {
		"#define RENDERING_MODE 2",
		"#define SUPPORT_DEPTH_LAYOUT ".. tostring((Platform.glSupportFragDepthLayout and 1) or 0),
		"#define SUPPORT_CLIP_CONTROL ".. tostring((Platform.glSupportClipSpaceControl and 1) or 0),
		[[
#if (RENDERING_MODE == 2) //shadows pass. AMD requests that extensions are declared right on top of the shader
	#if (SUPPORT_DEPTH_LAYOUT == 1)
		#extension GL_ARB_conservative_depth : enable
		//#extension GL_EXT_conservative_depth : require
		// preserve early-z performance if possible
		// for future reference: https://github.com/buildaworldnet/IrrlichtBAW/wiki/Early-Fragment-Tests,-Hi-Z,-Depth,-Stencil-and-other-benchmarks
	#endif
#endif
]],
		"#define USEQUATERNIONS "..USEQUATERNIONS,
		SLERPQUATERIONS,
	},
	reflectionDefinitions = {
		"#define RENDERING_MODE 0",
		"#define SUNMULT pbrParams[6]",
		"#define EXPOSURE pbrParams[7]",

		"#define SPECULAR_AO",

		"#define ROUGHNESS_AA 1.0",

		"#define ENV_SMPL_NUM " .. tostring(Spring.GetConfigInt("ENV_SMPL_NUM", 64)),
		"#define USE_ENVIRONMENT_DIFFUSE 1",
		"#define USE_ENVIRONMENT_SPECULAR 1",

		"#define TONEMAP(c) CustomTM(c)",
		"#define REFLECT_DISCARD",
		"#define USEQUATERNIONS "..USEQUATERNIONS,
		SLERPQUATERIONS,
	},

	shaderOptions = {
		shadowmapping     = true,
		normalmapping     = false,

		vertex_ao         = false,
		flashlights       = false,
		shift_rgbhsv    = false,

		treads_arm       = false,
		treads_core      = false,

		health_displace  = false,
		health_texturing = false,
		health_texraptors = false,

		modelsfog        = true,

		treewind         = false,

		shadowsQuality   = 2,

	},

	deferredOptions = {
		shadowmapping    = true,
		normalmapping    = false,

		vertex_ao        = false,
		flashlights      = false,
		shift_rgbhsv   = false,

		treads_arm      = false,
		treads_core     = false,

		modelsfog        = true,

		health_displace  = false,
		health_texturing = false,
		health_texraptors = false,

		treewind         = false,

		shadowsQuality   = 0,
		materialIndex    = 0,
	},

	shadowOptions = {
		treewind         = false,
	},

	feature = false,

	texUnits = {
		[6] = "$shadow",
		[7] = "$reflection",

		[9] = "modelmaterials_gl4/brdf_0.png",
		[10] = "modelmaterials_gl4/envlut_0.png",
	},

	--predl = nil, -- predl is replaced with prelist later in api_cus
	--postdl = nil, -- postdl is replaced with postlist later in api_cus

	--uuid = nil, -- uuid currently unused (not sent to engine)
	--order = nil, -- currently unused (not sent to engine)

	--culling = GL.BACK, -- usually GL.BACK is default, except for 3do
	-- shadowCulling = GL.BACK,
	-- usecamera = false, -- usecamera ? {gl_ModelViewMatrix, gl_NormalMatrix} = {modelViewMatrix, modelViewNormalMatrix} : {modelMatrix, modelNormalMatrix}
}

local shaderPlugins = {
	-- Inserted between %%TARGET%% blocks via InsertPlugin
}


local function SunChanged(luaShader)

	luaShader:SetUniformFloatArrayAlways("pbrParams", {
        Spring.GetConfigFloat("tonemapA", 4.75),
        Spring.GetConfigFloat("tonemapB", 0.75),
        Spring.GetConfigFloat("tonemapC", 3.5),
        Spring.GetConfigFloat("tonemapD", 0.85),
        Spring.GetConfigFloat("tonemapE", 1.0),
        Spring.GetConfigFloat("envAmbient", 0.125),
        Spring.GetConfigFloat("unitSunMult", 1.0),
        Spring.GetConfigFloat("unitExposureMult", 1.0),
	})
	luaShader:SetUniformFloatAlways("gamma", Spring.GetConfigFloat("modelGamma", 1.0))
end

defaultMaterialTemplate.SunChangedOrig = SunChanged
defaultMaterialTemplate.SunChanged = SunChanged

return defaultMaterialTemplate
