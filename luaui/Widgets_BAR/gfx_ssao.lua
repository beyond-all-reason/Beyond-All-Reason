local wiName = "SSAO"
function widget:GetInfo()
    return {
        name      = wiName,
        version	  = 2.0,
        desc      = "Screen-Space Ambient Occlusion",
        author    = "ivand",
        date      = "2019",
        license   = "GPL",
        layer     = -1,
        enabled   = false, --true
    }
end

-----------------------------------------------------------------
-- Constants
-----------------------------------------------------------------

local GL_COLOR_ATTACHMENT0_EXT = 0x8CE0
local GL_COLOR_ATTACHMENT1_EXT = 0x8CE1

local GL_RGB16F = 0x881B

local GL_RGB8_SNORM = 0x8F96

local GL_RGBA8 = 0x8058

local GL_FUNC_ADD = 0x8006
local GL_FUNC_REVERSE_SUBTRACT = 0x800B

-----------------------------------------------------------------
-- Configuration Constants
-----------------------------------------------------------------

local SSAO_KERNEL_SIZE = 24 -- how many samples are used for SSAO spatial sampling, don't go over 24
local SSAO_RADIUS = 7 -- world space maximum sampling radius

local BLUR_HALF_KERNEL_SIZE = 5 -- (BLUR_HALF_KERNEL_SIZE + BLUR_HALF_KERNEL_SIZE + 1) samples are used to perform the blur
local BLUR_PASSES = 2 -- number of blur passes
local BLUR_SIGMA = 2.0 -- Gaussian sigma
local BLUR_SAMPLING_DIST = 1.0 -- sampling step in pixels
local BLUR_VALMULT = 0.75 -- Linear multiplier to the SSAO final strength

local DOWNSAMPLE = 2 -- increasing downsapling will reduce GPU RAM occupation (a little bit), increase performace (a little bit), introduce shadow blockiness

local DEBUG_SSAO = false -- likely doesn't work anymore, don't bother

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
local ssaoTex
local ssaoBlurTexes = {}

local ssaoShader
local gbuffFuseShader
local gaussianBlurShader

-----------------------------------------------------------------
-- Local Functions
-----------------------------------------------------------------

local function G(x, sigma)
	return ( 1 / ( math.sqrt(2 * math.pi) * sigma ) ) * math.exp( -(x * x) / (2 * sigma * sigma) )
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

-----------------------------------------------------------------
-- Widget Functions
-----------------------------------------------------------------

function widget:ViewResize()
	widget:Shutdown()
	widget:Initialize()
end

function widget:Initialize()
	WG['ssao'] = {}
	WG['ssao'].getStrength = function()
		return BLUR_VALMULT
	end
	WG['ssao'].setStrength = function(value)
		BLUR_VALMULT = value
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

	commonTexOpts.format = GL_RGBA8
	ssaoTex = gl.CreateTexture(vsx / DOWNSAMPLE, vsy / DOWNSAMPLE, commonTexOpts)

	commonTexOpts.format = GL_RGB16F
	gbuffFuseViewPosTex = gl.CreateTexture(vsx, vsy, commonTexOpts)

	commonTexOpts.format = GL_RGB8_SNORM
	gbuffFuseViewNormalTex = gl.CreateTexture(vsx, vsy, commonTexOpts)

	commonTexOpts.format = GL_RGBA8
	for i = 1, 2 do
		ssaoBlurTexes[i] = gl.CreateTexture(vsx / DOWNSAMPLE, vsy / DOWNSAMPLE, commonTexOpts)
	end

	gbuffFuseFBO = gl.CreateFBO({
		color0 = gbuffFuseViewPosTex,
		color1 = gbuffFuseViewNormalTex,
		drawbuffers = {GL_COLOR_ATTACHMENT0_EXT, GL_COLOR_ATTACHMENT1_EXT},
	})
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
	end


	local gbuffFuseShaderVert = VFS.LoadFile(shadersDir.."gbuffFuse.vert.glsl")
	local gbuffFuseShaderFrag = VFS.LoadFile(shadersDir.."gbuffFuse.frag.glsl")

	gbuffFuseShaderFrag = gbuffFuseShaderFrag:gsub("###DEPTH_CLIP01###", (Platform.glSupportClipSpaceControl and "1" or "0"))

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
			mapNormalTex = 2,
			mapDepthTex = 3,
		},
		uniformFloat = {
			viewPortSize = {vsx, vsy},
		},
	}, "SSAO: G-buffer Fuse")
	gbuffFuseShader:Initialize()


	local ssaoShaderVert = VFS.LoadFile(shadersDir.."ssao.vert.glsl")
	local ssaoShaderFrag = VFS.LoadFile(shadersDir.."ssao.frag.glsl")

	ssaoShaderVert = ssaoShaderVert:gsub("###SSAO_KERNEL_SIZE###", tostring(SSAO_KERNEL_SIZE))
	ssaoShaderFrag = ssaoShaderFrag:gsub("###SSAO_KERNEL_SIZE###", tostring(SSAO_KERNEL_SIZE))
	
	ssaoShaderFrag = ssaoShaderFrag:gsub("###SSAO_RADIUS###", tostring(SSAO_RADIUS))

	ssaoShader = LuaShader({
		vertex = ssaoShaderVert,
		fragment = ssaoShaderFrag,
		uniformInt = {
			viewPosTex = 0,
			viewNormalTex = 1,
		},
		uniformFloat = {
			viewPortSize = {vsx / DOWNSAMPLE, vsy / DOWNSAMPLE},
		},
	}, "SSAO: Processing")
	ssaoShader:Initialize()


	local gaussianBlurVert = VFS.LoadFile(shadersDir.."gaussianBlur.vert.glsl")
	local gaussianBlurFrag = VFS.LoadFile(shadersDir.."gaussianBlur.frag.glsl")

	gaussianBlurFrag = gaussianBlurFrag:gsub("###HALF_KERNEL_SIZE###", tostring(BLUR_HALF_KERNEL_SIZE))

	gaussianBlurShader = LuaShader({
		vertex = gaussianBlurVert,
		fragment = gaussianBlurFrag,
		uniformInt = {
			tex = 0,
		},
		uniformFloat = {
			viewPortSize = {vsx / DOWNSAMPLE, vsy / DOWNSAMPLE},
		},
	}, "SSAO: Gaussian Blur")
	gaussianBlurShader:Initialize()

	local realValMult = math.pow(BLUR_VALMULT, 1/(2 * BLUR_PASSES))
	local gaussWeights, gaussOffsets = GetGaussLinearWeightsOffsets(BLUR_SIGMA, BLUR_HALF_KERNEL_SIZE, realValMult)

	gaussianBlurShader:ActivateWith( function()
		gaussianBlurShader:SetUniformFloatArrayAlways("weights", gaussWeights)
		gaussianBlurShader:SetUniformFloatArrayAlways("offsets", gaussOffsets)
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

function widget:DrawScreenEffects()
	gl.DepthTest(false)
	gl.Blending(false)

	if firstTime then
		screenQuadList = gl.CreateList(gl.TexRect, -1, -1, 1, 1)
		screenWideList = gl.CreateList(gl.TexRect, 0, vsy, vsx, 0)
		firstTime = false
	end

	gl.ActiveFBO(gbuffFuseFBO, function()
		gbuffFuseShader:ActivateWith( function ()

			gbuffFuseShader:SetUniformMatrix("invProjMatrix", "projectioninverse")
			gbuffFuseShader:SetUniformMatrix("viewMatrix", "view")

			gl.Texture(0, "$model_gbuffer_normtex")
			gl.Texture(1, "$model_gbuffer_zvaltex")
			gl.Texture(2, "$map_gbuffer_normtex")
			gl.Texture(3, "$map_gbuffer_zvaltex")

			gl.CallList(screenQuadList) -- gl.TexRect(-1, -1, 1, 1)
			--gl.TexRect(-1, -1, 1, 1)

			gl.Texture(0, false)
			gl.Texture(1, false)
			gl.Texture(2, false)
			gl.Texture(3, false)
		end)
	end)

	gl.ActiveFBO(ssaoFBO, function()
		ssaoShader:ActivateWith( function ()
			ssaoShader:SetUniformMatrix("projMatrix", "projection")

			gl.Texture(0, gbuffFuseViewPosTex)
			gl.Texture(1, gbuffFuseViewNormalTex)
			gl.CallList(screenQuadList) -- gl.TexRect(-1, -1, 1, 1)
			--gl.TexRect(-1, -1, 1, 1)

			gl.Texture(0, false)
			gl.Texture(1, false)
		end)
	end)

	gl.Texture(0, ssaoTex)

	for i = 1, BLUR_PASSES do
		gaussianBlurShader:ActivateWith( function ()

			gaussianBlurShader:SetUniform("dir", BLUR_SAMPLING_DIST, 0.0) --horizontal blur
			gl.ActiveFBO(ssaoBlurFBOs[1], function()
				gl.CallList(screenQuadList) -- gl.TexRect(-1, -1, 1, 1)
			end)
			gl.Texture(0, ssaoBlurTexes[1])

			gaussianBlurShader:SetUniform("dir", 0.0, BLUR_SAMPLING_DIST) --vertical blur
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
		gl.BlendFunc(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA) --alpha NO pre-multiply
		--gl.BlendFunc(GL.ONE, GL.ONE_MINUS_SRC_ALPHA) --alpha pre-multiply
		--gl.BlendFunc(GL.ZERO, GL.ONE)
	end

	-- Already bound
	--gl.Texture(0, ssaoBlurTexes[1])

	gl.CallList(screenWideList) --gl.TexRect(0, vsy, vsx, 0)

	if not DEBUG_SSAO then
		gl.BlendEquation(GL_FUNC_ADD)
	end

	gl.Texture(0, false)
	gl.Texture(1, false)
	gl.Texture(2, false)
	gl.Texture(3, false)

	gl.Blending(true)
	gl.DepthTest(true)
end

function widget:GetConfigData(data)
	savedTable = {}
	savedTable.strength = BLUR_VALMULT
	savedTable.radius = SSAO_RADIUS
	return savedTable
end

function widget:SetConfigData(data)
	if data.strength ~= nil then
		BLUR_VALMULT = data.strength
	end
	if data.strength ~= nil then
		SSAO_RADIUS = data.radius
	end
end