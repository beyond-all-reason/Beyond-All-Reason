local wiName = "SSAO"
function widget:GetInfo()
    return {
        name      = wiName,
        version	  = 2.0,
        desc      = "Screen-Space Ambient Occlusion",
        author    = "ivand",
        date      = "2019",
        license   = "GPL",
        layer     = math.huge,
        enabled   = false, --true
    }
end

-----------------------------------------------------------------
-- Constants
-----------------------------------------------------------------

local GL_COLOR_ATTACHMENT0_EXT = 0x8CE0
local GL_COLOR_ATTACHMENT1_EXT = 0x8CE1
local GL_COLOR_ATTACHMENT2_EXT = 0x8CE2

local GL_RGB16F = 0x881B

local GL_RGB8_SNORM = 0x8F96

local GL_RGBA8 = 0x8058

local GL_FUNC_ADD = 0x8006
local GL_FUNC_REVERSE_SUBTRACT = 0x800B

-----------------------------------------------------------------
-- Configuration Constants
-----------------------------------------------------------------

local SSAO_KERNEL_SIZE = 48 -- how many samples are used for SSAO spatial sampling
local SSAO_RADIUS = 5 -- world space maximum sampling radius
local SSAO_MIN = 1.0 -- minimum depth difference between fragment and sample depths to trigger SSAO sample occlusion. Absolute value in world space coords.
local SSAO_MAX = 1.0 -- maximum depth difference between fragment and sample depths to trigger SSAO sample occlusion. Percentage of SSAO_RADIUS.
local SSAO_ALPHA_POW = 8.0 -- consider this as SSAO effect strength

local BLUR_HALF_KERNEL_SIZE = 4 -- (BLUR_HALF_KERNEL_SIZE + BLUR_HALF_KERNEL_SIZE + 1) samples are used to perform the blur
local BLUR_PASSES = 3 -- number of blur passes
local BLUR_SIGMA = 1.8 -- Gaussian sigma of a single blur pass, other factors like BLUR_HALF_KERNEL_SIZE, BLUR_PASSES and DOWNSAMPLE affect the end result gaussian shape too

local DOWNSAMPLE = 2 -- increasing downsapling will reduce GPU RAM occupation (a little bit), increase performace (a little bit), introduce occlusion blockiness

local MERGE_MISC = true -- for future material indices based SSAO evaluation
local DEBUG_SSAO = false -- use for debug

local math_sqrt = math.sqrt

local preset = 1
local presets = {
	{
		SSAO_KERNEL_SIZE = 24,
		DOWNSAMPLE = 3,
		BLUR_HALF_KERNEL_SIZE = 4,
		BLUR_PASSES = 2,
		BLUR_SIGMA = 2.4,
	},
	{
		SSAO_KERNEL_SIZE = 48,
		DOWNSAMPLE = 2,
		BLUR_HALF_KERNEL_SIZE = 6,
		BLUR_PASSES = 3,
		BLUR_SIGMA = 4.5,
	},
	{
		SSAO_KERNEL_SIZE = 64,
		DOWNSAMPLE = 1,
		BLUR_HALF_KERNEL_SIZE = 8,
		BLUR_PASSES = 4,
		BLUR_SIGMA = 6.5,
	},
}

-----------------------------------------------------------------
-- File path Constants
-----------------------------------------------------------------

local shadersDir = "LuaUI/Widgets_BAR/Shaders/"
local luaShaderDir = "LuaUI/Widgets_BAR/Include/"

-----------------------------------------------------------------
-- Global Variables
-----------------------------------------------------------------

local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")

local vsx, vsy, vpx, vpy
local firstTime

local screenQuadList
local screenWideList

local gbuffFuseFBO
local ssaoFBO
local ssaoBlurFBOs = {}

local gbuffFuseViewPosTex
local gbuffFuseViewNormalTex
local gbuffFuseMiscTex
local ssaoTex
local ssaoBlurTexes = {}

local ssaoShader
local gbuffFuseShader
local gaussianBlurShader

-----------------------------------------------------------------
-- Local Functions
-----------------------------------------------------------------

local function G(x, sigma)
	return ( 1 / ( math_sqrt(2 * math.pi) * sigma ) ) * math.exp( -(x * x) / (2 * sigma * sigma) )
end

local function GetGaussDiscreteWeightsOffsets(sigma, kernelHalfSize, valMult)
	local weights = {}
	local offsets = {}

	weights[1] = G(0, sigma)
	local sum = weights[1]

	for i = 1, kernelHalfSize - 1 do
		weights[i + 1] = G(i, sigma)
		sum = sum + 2.0 * weights[i + 1]
	end

	for i = 0, kernelHalfSize - 1 do --normalize so the weights sum up to valMult
		weights[i + 1] = weights[i + 1] / sum * valMult
		offsets[i + 1] = i
	end
	return weights, offsets
end

--see http://rastergrid.com/blog/2010/09/efficient-gaussian-blur-with-linear-sampling/
local function GetGaussLinearWeightsOffsets(sigma, kernelHalfSize, valMult)
	local dWeights, dOffsets = GetGaussDiscreteWeightsOffsets(sigma, kernelHalfSize, 1.0)

	local weights = {dWeights[1]}
	local offsets = {dOffsets[1]}

	for i = 1, (kernelHalfSize - 1) / 2 do
		local newWeight = dWeights[2 * i] + dWeights[2 * i + 1]
		weights[i + 1] = newWeight * valMult
		offsets[i + 1] = (dOffsets[2 * i] * dWeights[2 * i] + dOffsets[2 * i + 1] * dWeights[2 * i + 1]) / newWeight
	end
	return weights, offsets
end


-- quick port of GLSL.
--[[
	for (int i = 0; i < SSAO_KERNEL_SIZE; i++) {
		vec3 tmp = hash31( float(i) );
		tmp.xy = NORM2SNORM(tmp.xy);
		tmp = normalize(tmp);
		float scale = float(i)/float(SSAO_KERNEL_SIZE);
		scale = clamp(scale * scale, 0.1, 1.0);
		tmp *= scale;
		samplingKernel[i] = tmp;
	}
]]--
-- I do so because of according GLSL spec gl_MaxVertexOutputComponents = 64; and gl_MaxFragmentUniformComponents = 1024;
-- so bigger SSAO kernel size can be supported if they are conveyed via uniforms vs varyings
local function GetSamplingVectorArray(kernelSize)
	local result = {}
	math.randomseed(kernelSize) -- for repeatability
	for i = 0, kernelSize - 1 do
		local x, y, z = math.random(), math.random(), math.random() -- [0, 1]^3

		x, y = 2.0 * x - 1.0, 2.0 * y - 1.0 -- xy:[-1, 1]^2, z:[0, 1]

		local l = math_sqrt(x * x + y * y + z * z) --norm
		x, y, z = x / l, y / l, z / l --normalize

		local scale = i / (kernelSize - 1)
		scale = scale * scale -- shift most samples closer to the origin
		scale = math.min(math.max(scale, 0.1), 1.0) --clamp

		x, y, z = x * scale, y * scale, z * scale -- scale
		result[i] = {x = x, y = y, z = z}
	end
	return result
end

-----------------------------------------------------------------
-- Widget Functions
-----------------------------------------------------------------

function widget:ViewResize()
	widget:Shutdown()
	widget:Initialize()
end

function widget:Initialize()
	WG['ssao'] = {}
	WG['ssao'].getPreset = function()
		return preset
	end
	WG['ssao'].setPreset = function(value)
		preset = value
		widget:Shutdown()
		widget:Initialize()
	end
	WG['ssao'].getStrength = function()
		return SSAO_ALPHA_POW
	end
	WG['ssao'].setStrength = function(value)
		SSAO_ALPHA_POW = value
		widget:Shutdown()
		widget:Initialize()
	end
	WG['ssao'].getRadius = function()
		return SSAO_RADIUS
	end
	WG['ssao'].setRadius = function(value)
		SSAO_RADIUS = value
		widget:Shutdown()
		widget:Initialize()
	end
	local canContinue = LuaShader.isDeferredShadingEnabled and LuaShader.GetAdvShadingActive()
	if not canContinue then
		Spring.Echo(string.format("Error in [%s] widget: %s", wiName, "Deferred shading is not enabled or advanced shading is not active"))
	end

	firstTime = true
	vsx, vsy, vpx, vpy = Spring.GetViewGeometry()

	local commonTexOpts = {
		target = GL_TEXTURE_2D,
		border = false,
		min_filter = GL.NEAREST,
		mag_filter = GL.NEAREST,

		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
	}

	commonTexOpts.format = GL_RGB16F
	gbuffFuseViewPosTex = gl.CreateTexture(vsx, vsy, commonTexOpts)

	commonTexOpts.format = GL_RGB8_SNORM
	gbuffFuseViewNormalTex = gl.CreateTexture(vsx, vsy, commonTexOpts)

	if MERGE_MISC then
		commonTexOpts.format = GL_RGBA8
		gbuffFuseMiscTex = gl.CreateTexture(vsx, vsy, commonTexOpts)
	end

	commonTexOpts.min_filter = GL.LINEAR
	commonTexOpts.mag_filter = GL.LINEAR

	commonTexOpts.format = GL_RGBA8
	ssaoTex = gl.CreateTexture(vsx / presets[preset].DOWNSAMPLE, vsy / presets[preset].DOWNSAMPLE, commonTexOpts)

	commonTexOpts.format = GL_RGBA8
	for i = 1, 2 do
		ssaoBlurTexes[i] = gl.CreateTexture(vsx / presets[preset].DOWNSAMPLE, vsy / presets[preset].DOWNSAMPLE, commonTexOpts)
	end

	if MERGE_MISC then
		gbuffFuseFBO = gl.CreateFBO({
			color0 = gbuffFuseViewPosTex,
			color1 = gbuffFuseViewNormalTex,
			color2 = gbuffFuseMiscTex,
			drawbuffers = {GL_COLOR_ATTACHMENT0_EXT, GL_COLOR_ATTACHMENT1_EXT, GL_COLOR_ATTACHMENT2_EXT},
		})
	else
		gbuffFuseFBO = gl.CreateFBO({
			color0 = gbuffFuseViewPosTex,
			color1 = gbuffFuseViewNormalTex,
			drawbuffers = {GL_COLOR_ATTACHMENT0_EXT, GL_COLOR_ATTACHMENT1_EXT},
		})
	end

	if not gl.IsValidFBO(gbuffFuseFBO) then
		Spring.Echo(string.format("Error in [%s] widget: %s", wiName, "Invalid gbuffFuseFBO"))
	end

	ssaoFBO = gl.CreateFBO({
		color0 = ssaoTex,
		drawbuffers = {GL_COLOR_ATTACHMENT0_EXT},
	})
	if not gl.IsValidFBO(ssaoFBO) then
		Spring.Echo(string.format("Error in [%s] widget: %s", wiName, "Invalid ssaoFBO"))
	end

	for i = 1, 2 do
		ssaoBlurFBOs[i] = gl.CreateFBO({
			color0 = ssaoBlurTexes[i],
			drawbuffers = {GL_COLOR_ATTACHMENT0_EXT},
		})
		if not gl.IsValidFBO(ssaoBlurFBOs[i]) then
			Spring.Echo(string.format("Error in [%s] widget: %s", wiName, string.format("Invalid ssaoBlurFBOs[%d]", i)))
		end
	end


	local gbuffFuseShaderVert = VFS.LoadFile(shadersDir.."identity.vert.glsl")
	local gbuffFuseShaderFrag = VFS.LoadFile(shadersDir.."gbuffFuse.frag.glsl")

	gbuffFuseShaderFrag = gbuffFuseShaderFrag:gsub("###DEPTH_CLIP01###", tostring((Platform.glSupportClipSpaceControl and 1) or 0))
	gbuffFuseShaderFrag = gbuffFuseShaderFrag:gsub("###MERGE_MISC###", tostring((MERGE_MISC and 1) or 0))

	gbuffFuseShader = LuaShader({
		vertex = gbuffFuseShaderVert,
		fragment = gbuffFuseShaderFrag,
		uniformInt = {
			-- be consistent with gfx_deferred_rendering.lua
			--	glTexture(0, "$model_gbuffer_normtex")
			--	glTexture(1, "$model_gbuffer_zvaltex")
			--	glTexture(2, "$map_gbuffer_normtex")
			--	glTexture(3, "$map_gbuffer_zvaltex")
			modelNormalTex = 0,
			modelDepthTex = 1,
			modelDiffTex = 2,
			mapNormalTex = 3,
			mapDepthTex = 4,

			modelMiscTex = 5,
			mapMiscTex = 6,
		},
		uniformFloat = {
			viewPortSize = {vsx, vsy},
		},
	}, wiName..": G-buffer Fuse")
	gbuffFuseShader:Initialize()


	local ssaoShaderVert = VFS.LoadFile(shadersDir.."identity.vert.glsl")
	local ssaoShaderFrag = VFS.LoadFile(shadersDir.."ssao.frag.glsl")

	ssaoShaderFrag = ssaoShaderFrag:gsub("###SSAO_KERNEL_SIZE###", tostring(presets[preset].SSAO_KERNEL_SIZE))

	ssaoShaderFrag = ssaoShaderFrag:gsub("###SSAO_RADIUS###", tostring(SSAO_RADIUS))
	ssaoShaderFrag = ssaoShaderFrag:gsub("###SSAO_MIN###", tostring(SSAO_MIN))
	ssaoShaderFrag = ssaoShaderFrag:gsub("###SSAO_MAX###", tostring(SSAO_MAX))

	ssaoShaderFrag = ssaoShaderFrag:gsub("###SSAO_ALPHA_POW###", tostring(SSAO_ALPHA_POW))
	ssaoShaderFrag = ssaoShaderFrag:gsub("###USE_MATERIAL_INDICES###", tostring((MERGE_MISC and 1) or 0))

	ssaoShader = LuaShader({
		vertex = ssaoShaderVert,
		fragment = ssaoShaderFrag,
		uniformInt = {
			viewPosTex = 0,
			viewNormalTex = 1,
			miscTex = 2,
		},
		uniformFloat = {
			viewPortSize = {vsx / presets[preset].DOWNSAMPLE, vsy / presets[preset].DOWNSAMPLE},
		},
	}, wiName..": Processing")
	ssaoShader:Initialize()

	ssaoShader:ActivateWith( function()
		local samplingKernel = GetSamplingVectorArray(presets[preset].SSAO_KERNEL_SIZE)
		for i = 0, presets[preset].SSAO_KERNEL_SIZE - 1 do
			local sv = samplingKernel[i]
			ssaoShader:SetUniformFloatAlways(string.format("samplingKernel[%d]", i), sv.x, sv.y, sv.z)
		end
	end)


	local gaussianBlurVert = VFS.LoadFile(shadersDir.."identity.vert.glsl")
	local gaussianBlurFrag = VFS.LoadFile(shadersDir.."gaussianBlur.frag.glsl")

	gaussianBlurFrag = gaussianBlurFrag:gsub("###BLUR_HALF_KERNEL_SIZE###", tostring(presets[preset].BLUR_HALF_KERNEL_SIZE))

	gaussianBlurShader = LuaShader({
		vertex = gaussianBlurVert,
		fragment = gaussianBlurFrag,
		uniformInt = {
			tex = 0,
		},
		uniformFloat = {
			viewPortSize = {vsx / presets[preset].DOWNSAMPLE, vsy / presets[preset].DOWNSAMPLE},
		},
	}, wiName..": Gaussian Blur")
	gaussianBlurShader:Initialize()

	local gaussWeights, gaussOffsets = GetGaussLinearWeightsOffsets(presets[preset].BLUR_SIGMA, presets[preset].BLUR_HALF_KERNEL_SIZE, 1.0)

	gaussianBlurShader:ActivateWith( function()
		gaussianBlurShader:SetUniformFloatArrayAlways("weights", gaussWeights)
		gaussianBlurShader:SetUniformFloatArrayAlways("offsets", gaussOffsets)
	end)

	widget:SunChanged()
end

function widget:SunChanged()
	ssaoShader:ActivateWith( function()
		local shadowDensity = gl.GetSun("shadowDensity", "unit")
		ssaoShader:SetUniformFloatAlways("shadowDensity", shadowDensity)
	end)
end

function widget:Shutdown()
	firstTime = nil

	if screenQuadList then
		gl.DeleteList(screenQuadList)
	end

	if screenWideList then
		gl.DeleteList(screenWideList)
	end


	gl.DeleteTexture(ssaoTex)
	gl.DeleteTexture(gbuffFuseViewPosTex)
	gl.DeleteTexture(gbuffFuseViewNormalTex)
	if MERGE_MISC then
		gl.DeleteTexture(gbuffFuseMiscTex)
	end

	for i = 1, 2 do
		gl.DeleteTexture(ssaoBlurTexes[i])
	end

	gl.DeleteFBO(ssaoFBO)
	gl.DeleteFBO(gbuffFuseFBO)
	for i = 1, 2 do
		gl.DeleteFBO(ssaoBlurFBOs[i])
	end

	ssaoShader:Finalize()
	gbuffFuseShader:Finalize()
	gaussianBlurShader:Finalize()
end

local function DoDrawSSAO(isScreenSpace)
	gl.DepthTest(false)
	gl.DepthMask(false)
	gl.Blending(false)


	if firstTime then
		screenQuadList = gl.CreateList(gl.TexRect, -1, -1, 1, 1)
		if isScreenSpace then
			screenWideList = gl.CreateList(gl.TexRect, 0, vsy, vsx, 0)
		else
			screenWideList = gl.CreateList(gl.TexRect, -1, -1, 1, 1, false, true)
		end
		firstTime = false
	end

	gl.ActiveFBO(gbuffFuseFBO, function()
		gbuffFuseShader:ActivateWith( function ()

			gbuffFuseShader:SetUniformMatrix("invProjMatrix", "projectioninverse")
			gbuffFuseShader:SetUniformMatrix("viewMatrix", "view")

			gl.Texture(0, "$model_gbuffer_normtex")
			gl.Texture(1, "$model_gbuffer_zvaltex")
			gl.Texture(2, "$model_gbuffer_difftex")
			gl.Texture(3, "$map_gbuffer_normtex")
			gl.Texture(4, "$map_gbuffer_zvaltex")

			if MERGE_MISC then
				gl.Texture(5, "$model_gbuffer_misctex")
				gl.Texture(6, "$map_gbuffer_misctex")
			end


			gl.CallList(screenQuadList) -- gl.TexRect(-1, -1, 1, 1)
			--gl.TexRect(-1, -1, 1, 1)

			gl.Texture(0, false)
			gl.Texture(1, false)
			gl.Texture(2, false)
			gl.Texture(3, false)
			gl.Texture(4, false)
			if MERGE_MISC then
				gl.Texture(4, false)
				gl.Texture(5, false)
				gl.Texture(6, false)
			end
		end)
	end)

	gl.ActiveFBO(ssaoFBO, function()
		ssaoShader:ActivateWith( function ()
			ssaoShader:SetUniformMatrix("projMatrix", "projection")

			gl.Texture(0, gbuffFuseViewPosTex)
			gl.Texture(1, gbuffFuseViewNormalTex)
			if MERGE_MISC then
				gl.Texture(2, gbuffFuseMiscTex)
			end
			gl.CallList(screenQuadList) -- gl.TexRect(-1, -1, 1, 1)
			--gl.TexRect(-1, -1, 1, 1)

			gl.Texture(0, false)
			gl.Texture(1, false)
			if MERGE_MISC then
				gl.Texture(2, false)
			end
		end)
	end)

	gl.Texture(0, ssaoTex)

	for i = 1, presets[preset].BLUR_PASSES do
		gaussianBlurShader:ActivateWith( function ()

			gaussianBlurShader:SetUniform("dir", 1.0, 0.0) --horizontal blur
			gl.ActiveFBO(ssaoBlurFBOs[1], function()
				gl.CallList(screenQuadList) -- gl.TexRect(-1, -1, 1, 1)
			end)
			gl.Texture(0, ssaoBlurTexes[1])

			gaussianBlurShader:SetUniform("dir", 0.0, 1.0) --vertical blur
			gl.ActiveFBO(ssaoBlurFBOs[2], function()
				gl.CallList(screenQuadList) -- gl.TexRect(-1, -1, 1, 1)
			end)
			gl.Texture(0, ssaoBlurTexes[2])

		end)
	end


	if DEBUG_SSAO then
		gl.Blending(false)
	else
		gl.BlendEquation(GL_FUNC_REVERSE_SUBTRACT)
		--gl.Blending("alpha")
		gl.Blending(true)
		gl.BlendFuncSeparate(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA, GL.ZERO, GL.ONE)
		--gl.BlendFunc(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA) --alpha NO pre-multiply
		--gl.BlendFunc(GL.ONE, GL.ONE_MINUS_SRC_ALPHA) --alpha pre-multiply
		--gl.BlendFunc(GL.ZERO, GL.ONE)
	end

	-- Already bound
	--gl.Texture(0, ssaoBlurTexes[1])

	gl.CallList(screenWideList)

	if not DEBUG_SSAO then
		gl.BlendEquation(GL_FUNC_ADD)
	end




	gl.Texture(0, false)
	gl.Texture(1, false)
	gl.Texture(2, false)
	gl.Texture(3, false)


	gl.Blending("alpha")
	--gl.DepthMask(true)
	--gl.DepthTest(true)
end

function widget:DrawWorld()
	gl.MatrixMode(GL.MODELVIEW)
	gl.PushMatrix()
	gl.LoadIdentity()

		gl.MatrixMode(GL.PROJECTION)
		gl.PushMatrix()
		gl.LoadIdentity();

			DoDrawSSAO(false)

		gl.MatrixMode(GL.PROJECTION)
		gl.PopMatrix()

	gl.MatrixMode(GL.MODELVIEW)
	gl.PopMatrix()
end

function widget:GetConfigData(data)
	savedTable = {}
	savedTable.strength = SSAO_ALPHA_POW
	savedTable.radius = SSAO_RADIUS
	savedTable.preset = preset
	return savedTable
end

function widget:SetConfigData(data)
	if data.strength ~= nil then
		SSAO_ALPHA_POW = data.strength
	end
	if data.strength ~= nil then
		SSAO_RADIUS = data.radius
	end
	if data.preset ~= nil then
		preset = data.preset
	end
end
