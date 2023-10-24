
local isPotatoGpu = false
local gpuMem = (Platform.gpuMemorySize and Platform.gpuMemorySize or 1000) / 1000
if Platform ~= nil and Platform.gpuVendor == 'Intel' then
	isPotatoGpu = true
end
if gpuMem and gpuMem > 0 and gpuMem < 1800 then
	isPotatoGpu = true
end


local widgetName = "SSAO"
function widget:GetInfo()
    return {
        name      = widgetName,
        version	  = 2.0,
        desc      = "Screen-Space Ambient Occlusion",
        author    = "ivand",
        date      = "2019",
        license   = "GPL",
        layer     = 999999,
        enabled   = not isPotatoGpu,
    }
end

-- pre unitStencilTexture it takes 800 ms per frame
-- todo: fake more ground ao in blur pass?

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

local shaderConfig = {
	DEPTH_CLIP01 = tostring((Platform.glSupportClipSpaceControl and 1) or 0), -- no idea
	MERGE_MISC = 0, -- for future material indices based SSAO evaluation
}

local definesSlidersParamsList = {
	{name = 'SSAO_KERNEL_SIZE', default = 32, min = 1, max = 64, digits = 0, tooltip = 'how many samples are used for SSAO spatial sampling'},
	--{name = 'MINISHADOWS', default = 0, min = 0, max = 1, digits = 0, tooltip = 'Wether to draw a downsampled shadow sampler'},
	{name = 'SSAO_RADIUS', default = 8, min = 4, max = 16, digits = 1, tooltip = 'world space maximum sampling radius'},
	{name = 'SSAO_MIN', default = 1, min = 0, max = 4, digits = 2, tooltip = 'minimum depth difference between fragment and sample depths to trigger SSAO sample occlusion. Absolute value in world space coords.'},
	{name = 'SSAO_OCCLUSION_POWER', default = 3, min = 0, max = 16, digits = 1, tooltip = 'how much effect each SSAO sample has'},
	{name = 'SSAO_FADE_DIST_1', default = 800, min = 200, max = 3000, digits = 1, tooltip = 'near distance for max SSAO'},
	{name = 'SSAO_FADE_DIST_0', default = 2400, min = 1000, max = 4000, digits = 1, tooltip = 'far distance for min SSAO'},
	{name = 'DEBUG_SSAO', default = 0, min = 0, max = 1, digits = 0, tooltip = 'DEBUG_SSAO show the raw samples'},

	{name = 'BLUR_HALF_KERNEL_SIZE', default = 3, min = 1, max = 12, digits = 0, tooltip = 'BLUR_HALF_KERNEL_SIZE*2 - 1 samples for blur'},
	{name = 'BLUR_SIGMA', default = 3, min = 1, max = 10, digits = 1, tooltip = 'Sigma width of blur filter'},
	{name = 'MINCOSANGLE', default = -0.5, min = -3, max = 1, digits = 2, tooltip = 'the minimum angle for considering a sample colinear when blurring'},
	{name = 'ZTHRESHOLD', default = 1/255.0, min = 0.0, max = 4/255.0, digits = 3, tooltip = 'Should be more than 1.0'},
	{name = 'MINSELFWEIGHT', default = 0.2, min = 0.0, max = 1, digits = 2, tooltip = 'The minimum weight a sample needs to gather to be considered a non-outlier'},
	{name = 'OUTLIERCORRECTIONFACTOR', default = 0.5, min = 0.0, max = 1, digits = 2, tooltip = 'How strongly to use blurred result for outliers'},
	{name = 'BLUR_POWER', default = 2, min = 1, max = 8, digits = 1, tooltip = 'Post-blur correction factor'},
	{name = 'BLUR_CLAMP', default = 0.05, min = 0, max = 1, digits = 3, tooltip = 'The smallest amount of allowed SSAO post-blur'},
	{name = 'DEBUG_BLUR', default = 0, min = 0, max = 1, digits = 0, tooltip = 'DEBUG_BLUR show the result of the blur only'},

	{name = 'USE_STENCIL', default = 1, min = 0, max = 1, digits = 0, tooltip = 'USE_STENCIL set to zero if you dont wanna'},
	{name = 'DOWNSAMPLE', default = 1, min = 1, max = 2, digits = 0, tooltip = 'Set to 2 for half-rez buffers'},
	{name = 'ENABLE', default = 1, min = 0, max = 1, digits = 0, tooltip = 'Disable the whole SSAO'},
	{name = 'SLOWFUSE', default = 0, min = 0, max = 1, digits = 0, tooltip = 'Only fuse every 30 frames'},
}

for i, shaderDefine in ipairs(definesSlidersParamsList) do 
	-- dont overwrite existing, externally defined values with the defaults:
	if shaderConfig[shaderDefine.name] == nil then 
		shaderConfig[shaderDefine.name] = shaderDefine.default;
	end
end

local function shaderDefinesChangedCallback(name, value, index, oldvalue)
	--Spring.Echo("shaderDefinesChangedCallback()", name, value, shaderConfig[name])
	if value ~= oldvalue then 
		widget:ViewResize()
	end
end

local vsx, vsy = Spring.GetViewGeometry()

local shaderDefinedSliders = {
	windowtitle = "Fog Defines",
	name = "shaderDefinedSliders",
	left = vsx - 540, 
	bottom = 200, 
	right = vsx - 540 + 250,
	sliderheight = 20,
	valuetarget = shaderConfig,
	sliderParamsList = definesSlidersParamsList,
	callbackfunc = shaderDefinesChangedCallback
}
shaderDefinedSliders.top = shaderDefinedSliders.bottom + shaderDefinedSliders.sliderheight *( #definesSlidersParamsList +3)

local shaderDefinedSlidersLayer, shaderDefinedSlidersWindow



local math_sqrt = math.sqrt

local cusMult = 1.4
local strengthMult = 1

local initialTonemapA = Spring.GetConfigFloat("tonemapA", 4.75)
local initialTonemapD = Spring.GetConfigFloat("tonemapD", 0.85)
local initialTonemapE = Spring.GetConfigFloat("tonemapE", 1.0)

local preset = 2
local presets = {
	{
		SSAO_KERNEL_SIZE = 32,
		DOWNSAMPLE = 2,
		BLUR_HALF_KERNEL_SIZE = 6,
		BLUR_SIGMA = 4,
		tonemapA = 0.45,
		tonemapD = -0.25,
		tonemapE = -0.03,
	},
	{
		SSAO_KERNEL_SIZE = 32,
		DOWNSAMPLE = 1,
		BLUR_HALF_KERNEL_SIZE = 4,
		SSAO_RADIUS = 8;
		BLUR_SIGMA = 3,
		tonemapA = 0.4,
		tonemapD = -0.25,
		tonemapE = -0.025,
	},
	{
		SSAO_KERNEL_SIZE = 64,
		DOWNSAMPLE = 1,
		BLUR_HALF_KERNEL_SIZE = 8,
		BLUR_SIGMA = 6,
		tonemapA = 0.4,
		tonemapD = -0.25,
		tonemapE = -0.025,
	},
}

local function ActivatePreset(presetID)
	if presets[presetID] then 
		for k,v in pairs(presets[presetID]) do 
			shaderConfig[k] = v
		end
	end	
end

ActivatePreset(preset)
-----------------------------------------------------------------
-- File path Constants
-----------------------------------------------------------------

local shadersDir = "LuaUI/Widgets/Shaders/"
local luaShaderDir = "LuaUI/Widgets/Include/"

-----------------------------------------------------------------
-- Global Variables
-----------------------------------------------------------------

local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")

local vsx, vsy, vpx, vpy
local texPaddingX, texPaddingY = 0,0

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
local ssaoShaderCache
local gbuffFuseShaderCache
local gaussianBlurShaderCache

local unitStencilTexture

local unitStencil = nil
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
	local dWeights, dOffsets = GetGaussDiscreteWeightsOffsets(sigma, (kernelHalfSize-1) * 2 + 1 , 1.0)
	-- at khs = 4 
	-- dWeights, {1=0.1112202, 2=0.10779832, 3=0.09815148, 4=0.08395342, 5=0.06745847, 6=0.05092032, 7=0.03610791, }
	-- dOffsets, {1=0, 2=1, 3=2, 4=3, 5=4, 6=5, 7=6, }

	local weights = {dWeights[1]}
	local offsets = {dOffsets[1]}
	local totalweights = dWeights[1]
	
	-- for 4 this should go to 3
	for i = 1, kernelHalfSize -1  do -- for khs 4 this goes from 1 to , well 1. 
		local newWeight = dWeights[2 * i ] + dWeights[2 * i + 1]
		weights[i + 1] = newWeight * valMult
		offsets[i + 1] = (dOffsets[2 * i] * dWeights[2 * i] + dOffsets[2 * i + 1] * dWeights[2 * i + 1]) / newWeight
	end

	for i = 2, kernelHalfSize do 
		totalweights = totalweights + 2 * weights[i] -- 2x cause symmetric kernel
	end

	--[[
	local function tabletostring(t)
		local res = '{'
		for k,v in pairs(t) do 
			res = res .. tostring(k) .. "=" .. tostring(v) .. ', '
		end
		return res .. '}'
	end

	Spring.Echo("GetGaussLinearWeightsOffsets(sigma, kernelHalfSize, valMult)",sigma, kernelHalfSize, valMult, 'total = ', totalweights)
	Spring.Echo('dWeights',tabletostring(dWeights))
	Spring.Echo('dOffsets',tabletostring(dOffsets))
	Spring.Echo('weights',tabletostring(weights)) 
	Spring.Echo('offsets',tabletostring(offsets))
	]]--
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


local function InitGL()
	local canContinue = LuaShader.isDeferredShadingEnabled and LuaShader.GetAdvShadingActive()
	
	if not canContinue then
		Spring.Echo(string.format("Error in [%s] widget: %s", widgetName, "Deferred shading is not enabled or advanced shading is not active"))
	end

	-- make unit lighting brighter to compensate for darkening (also restoring values on Shutdown())
	if presets[preset].tonemapA then
		Spring.SetConfigFloat("tonemapA", initialTonemapA + (presets[preset].tonemapA * ((shaderConfig.SSAO_ALPHA_POW * strengthMult)/11)))
		Spring.SetConfigFloat("tonemapD", initialTonemapD + (presets[preset].tonemapD * ((shaderConfig.SSAO_ALPHA_POW * strengthMult)/11)))
		Spring.SetConfigFloat("tonemapE", initialTonemapE + (presets[preset].tonemapE * ((shaderConfig.SSAO_ALPHA_POW * strengthMult)/11)))
		Spring.SendCommands("luarules updatesun")
	end

	firstTime = true
	vsx, vsy = Spring.GetViewGeometry()


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

	if shaderConfig.MERGE_MISC ==1 then
		commonTexOpts.format = GL_RGBA8
		gbuffFuseMiscTex = gl.CreateTexture(vsx, vsy, commonTexOpts)
	end

	commonTexOpts.min_filter = GL.LINEAR
	commonTexOpts.mag_filter = GL.LINEAR

	commonTexOpts.format = GL_RGBA8

	shaderConfig.VSX = vsx
	shaderConfig.VSY = vsy
	shaderConfig.HSX = math.ceil(vsx / shaderConfig.DOWNSAMPLE)
	shaderConfig.HSY = math.ceil(vsy / shaderConfig.DOWNSAMPLE)
	shaderConfig.TEXPADDINGX = shaderConfig.DOWNSAMPLE * shaderConfig.HSX - vsx
	shaderConfig.TEXPADDINGY = shaderConfig.DOWNSAMPLE * shaderConfig.HSY - vsy

	Spring.Echo("SSAO SIZING",shaderConfig.DOWNSAMPLE, vsx, vsy, shaderConfig.TEXPADDINGX, shaderConfig.TEXPADDINGY)


	ssaoTex = gl.CreateTexture(shaderConfig.HSX, shaderConfig.HSY , commonTexOpts)

	commonTexOpts.format = GL_RGBA8
	for i = 1, 2 do
		ssaoBlurTexes[i] = gl.CreateTexture(shaderConfig.HSX, shaderConfig.HSY, commonTexOpts)
	end

	if shaderConfig.MERGE_MISC ==1 then
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
		Spring.Echo(string.format("Error in [%s] widget: %s", widgetName, "Invalid gbuffFuseFBO"))
	end

	ssaoFBO = gl.CreateFBO({
		color0 = ssaoTex,
		drawbuffers = {GL_COLOR_ATTACHMENT0_EXT},
	})
	if not gl.IsValidFBO(ssaoFBO) then
		Spring.Echo(string.format("Error in [%s] widget: %s", widgetName, "Invalid ssaoFBO"))
	end

	for i = 1, 2 do
		ssaoBlurFBOs[i] = gl.CreateFBO({
			color0 = ssaoBlurTexes[i],
			drawbuffers = {GL_COLOR_ATTACHMENT0_EXT},
		})
		if not gl.IsValidFBO(ssaoBlurFBOs[i]) then
			Spring.Echo(string.format("Error in [%s] widget: %s", widgetName, string.format("Invalid ssaoBlurFBOs[%d]", i)))
		end
	end

	if shaderConfig.USE_STENCIL == 1 then 
		unitStencilTexture = WG['unitstencilapi'].GetUnitStencilTexture()
		shaderConfig.USE_STENCIL = unitStencilTexture and 1 or 0
	end


	gbuffFuseShaderCache = {
		vssrcpath = shadersDir.."identity_texrect.vert.glsl",
		fssrcpath = shadersDir.."gbuffFuse.frag.glsl",
		uniformInt = {
			modelNormalTex = 0,
			modelDepthTex = 1,
			modelDiffTex = 2,
			mapNormalTex = 3,
			mapDepthTex = 4,

			modelMiscTex = 5,
			mapMiscTex = 6,

			unitStencilTex = 7,
		},
		uniformFloat = {
		},
		shaderConfig = shaderConfig,
		shaderName = widgetName..": G-buffer Fuse",
	}	

	gbuffFuseShader = LuaShader.CheckShaderUpdates(gbuffFuseShaderCache)

	ssaoShaderCache = {
		vssrcpath = shadersDir.."identity_texrect.vert.glsl",
		fssrcpath = shadersDir.."ssao.frag.glsl",
		uniformInt = {
			viewPosTex = 0,
			viewNormalTex = 1,
			miscTex = 2,

			unitStencilTex = 7,
		},
		uniformFloat = {
		},
		shaderConfig = shaderConfig,
		shaderName = widgetName..": SSAO",
	}

	ssaoShader = LuaShader.CheckShaderUpdates(ssaoShaderCache)

	ssaoShader:ActivateWith( function()
		local samplingKernel = GetSamplingVectorArray(shaderConfig.SSAO_KERNEL_SIZE)
		for i = 0, shaderConfig.SSAO_KERNEL_SIZE - 1 do
			local sv = samplingKernel[i]
			local success = ssaoShader:SetUniformFloatAlways(string.format("samplingKernel[%d]", i), sv.x, sv.y, sv.z)
			--Spring.Echo("ssaoShader:SetUniformFloatAlways",success, sv.x, sv.y, sv.z)
		end
		ssaoShader:SetUniformFloatAlways("testuniform", 1.0)
	end)


	gaussianBlurShaderCache = {
		vssrcpath = shadersDir.."identity_texrect.vert.glsl",
		fssrcpath = shadersDir.."gaussianBlur.frag.glsl",
		uniformInt = {
			tex = 0,
			unitStencilTex = 7,
		},
		uniformFloat = {
			dir = {0,1},
			lastpass = 0, -- on last pass, output different stuff
			strengthMult = 1,
		},
		shaderConfig = shaderConfig,
		shaderName = widgetName..": gaussianBlur",
	}

	gaussianBlurShader = LuaShader.CheckShaderUpdates(gaussianBlurShaderCache)

	local gaussWeights, gaussOffsets = GetGaussLinearWeightsOffsets(shaderConfig.BLUR_SIGMA, shaderConfig.BLUR_HALF_KERNEL_SIZE, 1.0)

	--Spring.Echo("#gaussWeights", #gaussWeights, "#gaussOffsets", #gaussOffsets)

	gaussianBlurShader:ActivateWith( function()
		gaussianBlurShader:SetUniformFloatArrayAlways("weights", gaussWeights)
		gaussianBlurShader:SetUniformFloatArrayAlways("offsets", gaussOffsets)
	end)

end

local function CleanGL()
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
	if shaderConfig.MERGE_MISC ==1 then
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


function widget:ViewResize()
	CleanGL()
	InitGL()
end

function widget:Initialize()
	WG['ssao'] = {}
	WG['ssao'].getPreset = function()
		return preset
	end
	WG['ssao'].setPreset = function(value)
		preset = value
		ActivatePreset(preset)
		CleanGL()
		InitGL()
	end
	WG['ssao'].getStrength = function()
		return shaderConfig.SSAO_ALPHA_POW
	end
	WG['ssao'].setStrength = function(value)
		shaderConfig.SSAO_ALPHA_POW = value
		CleanGL()
		InitGL()
	end
	WG['ssao'].getRadius = function()
		return shaderConfig.SSAO_RADIUS
	end
	WG['ssao'].setRadius = function(value)
		shaderConfig.SSAO_RADIUS = value
		CleanGL()
		InitGL()
	end

	if WG['flowui_gl4']  and WG['flowui_gl4'].forwardslider then 
		Spring.Echo(" WG[flowui_gl4] detected")	
			shaderDefinedSlidersLayer, shaderDefinedSlidersWindow = WG['flowui_gl4'].requestWidgetLayer(shaderDefinedSliders) -- this is a window
			shaderDefinedSliders.parent = shaderDefinedSlidersWindow
			
			WG['flowui_gl4'].forwardslider(shaderDefinedSliders)
	end

	InitGL()
end


local sec = 0
function widget:Update(dt)
	sec = sec + dt
	if sec > 1 then
		sec = 0
		if Spring.GetConfigInt("cus", 1) == 1 then
			if WG.disabledCus then
				strengthMult = 1
			else
				strengthMult = cusMult
			end
		else
			strengthMult = 1
		end
	end
end


function widget:Shutdown()

	-- restore unit lighting settings
	if presets[preset].tonemapA then
		Spring.SetConfigFloat("tonemapA", initialTonemapA)
		Spring.SetConfigFloat("tonemapD", initialTonemapD)
		Spring.SetConfigFloat("tonemapE", initialTonemapE)
		Spring.SendCommands("luarules updatesun")
	end
	
	if shaderDefinedSlidersLayer and shaderDefinedSlidersLayer.Destroy then shaderDefinedSlidersLayer:Destroy() end 
	CleanGL()
end

local function DoDrawSSAO()
	gl.DepthTest(false)
	gl.DepthMask(false) --"BK OpenGL state resets", default is already false, could remove
	gl.Blending(false)

	if firstTime then
		-- These are now offset by the half pixel that is needed here due to ceil(vsx/rez)
		screenQuadList = gl.CreateList(gl.TexRect, -1, -1, 1, 1, 0, 0, 
			1.0 - shaderConfig.TEXPADDINGX/shaderConfig.VSX, 1.0 - shaderConfig.TEXPADDINGY/shaderConfig.VSY)
		screenWideList = gl.CreateList(gl.TexRect, -1, -1, 1, 1, 0, 0,
			1.0 + shaderConfig.TEXPADDINGX/shaderConfig.VSX, 1.0 + shaderConfig.TEXPADDINGY/shaderConfig.VSY)
		firstTime = false
	end
	
	if shaderConfig.USE_STENCIL == 1 and unitStencilTexture then 
				
		unitStencilTexture = WG['unitstencilapi'].GetUnitStencilTexture() -- needs this to notify that we want it next frame too
		gl.Texture(7, unitStencilTexture)
	end

	local prevFBO
	if (shaderConfig.SLOWFUSE == 0) or Spring.GetDrawFrame()%30==0 then 
	prevFBO = gl.RawBindFBO(gbuffFuseFBO)
		gbuffFuseShader:Activate() -- ~0.25ms

			gl.Texture(0, "$model_gbuffer_normtex")
			gl.Texture(1, "$model_gbuffer_zvaltex")
			gl.Texture(2, "$model_gbuffer_difftex")
			gl.Texture(3, "$map_gbuffer_normtex")
			gl.Texture(4, "$map_gbuffer_zvaltex")

			if shaderConfig.MERGE_MISC ==1 then
				gl.Texture(5, "$model_gbuffer_misctex")
				gl.Texture(6, "$map_gbuffer_misctex")
			end

			gbuffFuseShader:SetUniformMatrix("invProjMatrix", "projectioninverse")
			gbuffFuseShader:SetUniformMatrix("viewMatrix", "view")
			gl.CallList(screenQuadList) -- gl.TexRect(-1, -1, 1, 1)
		

			gl.Texture(0, false)
			gl.Texture(1, false)
			gl.Texture(2, false)
			gl.Texture(3, false)
			gl.Texture(4, false)
			if shaderConfig.MERGE_MISC ==1 then
				gl.Texture(5, false)
				gl.Texture(6, false)
			end
		gbuffFuseShader:Deactivate()
	--end)
	gl.RawBindFBO(nil, nil, prevFBO)
	end

	prevFBO = gl.RawBindFBO(ssaoFBO)
		gl.Clear(GL.COLOR_BUFFER_BIT, 0, 0, 0, 0)
		ssaoShader:Activate()
			ssaoShader:SetUniformMatrix("projMatrix", "projection")
			local shadowDensity = gl.GetSun("shadowDensity", "unit")
			ssaoShader:SetUniformFloat("shadowDensity", shadowDensity)

			gl.Texture(0, gbuffFuseViewPosTex)
			gl.Texture(1, gbuffFuseViewNormalTex)
			if shaderConfig.MERGE_MISC ==1 then
				gl.Texture(2, gbuffFuseMiscTex)
			end
			gl.CallList(screenQuadList) 

			gl.Texture(0, false)
			gl.Texture(1, false)
			if shaderConfig.MERGE_MISC ==1 then
				gl.Texture(2, false)
			end
		ssaoShader:Deactivate()
	gl.RawBindFBO(nil, nil, prevFBO)

	gl.Texture(0, ssaoTex)

	if shaderConfig.DEBUG_SSAO == 0 then 
			gaussianBlurShader:Activate()

				gaussianBlurShader:SetUniform("dir", 1.0, 0.0) --horizontal blur
				prevFBO = gl.RawBindFBO(ssaoBlurFBOs[1])
				gl.CallList(screenQuadList) -- gl.TexRect(-1, -1, 1, 1)
				gl.RawBindFBO(nil, nil, prevFBO)
				gl.Texture(0, ssaoBlurTexes[1])

				gaussianBlurShader:SetUniform("dir", 0.0, 1.0) --vertical blur
				prevFBO = gl.RawBindFBO(ssaoBlurFBOs[2])
				gl.CallList(screenQuadList) -- gl.TexRect(-1, -1, 1, 1)
				gl.RawBindFBO(nil, nil, prevFBO)
				gl.Texture(0, ssaoBlurTexes[2])

			gaussianBlurShader:Deactivate()
		if shaderConfig.DEBUG_BLUR == 1 then
			gl.Blending(false) -- now blurred tex contains normals
		else
			gl.Blending(GL.ZERO, GL.SRC_ALPHA) -- now blurred tex contains normals
		end
	else
		if shaderConfig.DEBUG_BLUR == 1 then
			gl.Blending(false) -- now blurred tex contains normals
		else
			gl.Blending(false) -- now blurred tex contains normals
		end
	end
	-- Already bound
	--gl.Texture(0, ssaoBlurTexes[1])

	gl.CallList(screenWideList)

	gl.Texture(0, false)
	gl.Texture(1, false)
	gl.Texture(2, false)
	gl.Texture(3, false)

	gl.Blending("alpha")
	--gl.DepthMask(true) --"BK OpenGL state resets", already commented out
	--gl.DepthTest(true) --"BK OpenGL state resets", already commented out
end

function widget:DrawWorld()
	if shaderConfig.ENABLE == 0 then return end
	gl.MatrixMode(GL.MODELVIEW)
	gl.PushMatrix()
	gl.LoadIdentity()

		gl.MatrixMode(GL.PROJECTION)
		gl.PushMatrix()
		gl.LoadIdentity()

			DoDrawSSAO(false)

		gl.MatrixMode(GL.PROJECTION)
		gl.PopMatrix()

	gl.MatrixMode(GL.MODELVIEW)
	gl.PopMatrix()

	if delayedUpdateSun and os.clock() > delayedUpdateSun then
		Spring.SendCommands("luarules updatesun")
		delayedUpdateSun = nil
	end
end

function widget:GetConfigData(data)
	return {
		strength = shaderConfig.SSAO_ALPHA_POW,
		radius = shaderConfig.SSAO_RADIUS,
		preset = preset
	}
end

function widget:SetConfigData(data)
	if data.strength ~= nil then
		shaderConfig.SSAO_ALPHA_POW = data.strength
	end
	if data.radius ~= nil then
		shaderConfig.SSAO_RADIUS = data.radius
	end
	if data.preset ~= nil then
		preset = data.preset
		if preset > 3 then
			preset = 3
		end
	end
end
