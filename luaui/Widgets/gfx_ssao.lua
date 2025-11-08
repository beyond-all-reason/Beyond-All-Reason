local gpuMem = (Platform.gpuMemorySize and Platform.gpuMemorySize or 1000) / 1000
if Platform ~= nil and Platform.gpuVendor == 'Intel' then
	return false
end
if gpuMem and gpuMem > 0 and gpuMem < 1800 then
	return false
end


local widgetName = "SSAO"
local widget = widget ---@type Widget

function widget:GetInfo()
    return {
        name      = widgetName,
        version	  = 2.0,
        desc      = "Screen-Space Ambient Occlusion",
        author    = "ivand",
        date      = "2019",
        license   = "GPL",
        layer     = 999999,
        enabled   = true,
        depends   = {'gl4'},
    }
end


-- Localized functions for performance
local mathCeil = math.ceil
local mathSqrt = math.sqrt
local mathRandom = math.random
local mathPi = math.pi

-- Localized Spring API for performance
local spEcho = Spring.Echo
local spGetViewGeometry = Spring.GetViewGeometry

-- pre unitStencilTexture it takes 800 ms per frame
-- todo: fake more ground ao in blur pass?

-----------------------------------------------------------------
-- Constants
-----------------------------------------------------------------

local GL_COLOR_ATTACHMENT0_EXT = 0x8CE0
local GL_RGB16F = 0x881B
local GL_RGBA8 = 0x8058

local glTexture = gl.Texture

-----------------------------------------------------------------
-- Configuration Constants
-----------------------------------------------------------------

local shaderConfig = {
	DEPTH_CLIP01 = tostring((Platform.glSupportClipSpaceControl and 1) or 0), -- no idea
	MERGE_MISC = 0, -- for future material indices based SSAO evaluation, completely dissabled now
}

local definesSlidersParamsList = {
	{name = 'SSAO_FIBONACCI', default = 1, min = 0, max = 1, digits = 0, tooltip = 'Use uniformly distributed rays intead of randomly distributed ones'},
	{name = 'SSAO_KERNEL_MINZ', default = 0.04, min = 0, max = 0.2, digits = 2, tooltip = 'How close vectors can be to tangent plane'},
	{name = 'SSAO_RANDOM_LENGTH', default = 0.6, min = 0.2, max = 3, digits = 2, tooltip = 'A power term for the lenghts of the random vectors, small numbers are longer vectors'},
	{name = 'SSAO_KERNEL_SIZE', default = 32, min = 1, max = 64, digits = 0, tooltip = 'how many samples are used for SSAO spatial sampling'},
	--{name = 'MINISHADOWS', default = 0, min = 0, max = 1, digits = 0, tooltip = 'Wether to draw a downsampled shadow sampler'},
	{name = 'SSAO_RADIUS', default = 8, min = 4, max = 16, digits = 1, tooltip = 'world space maximum sampling radius'},
	{name = 'SSAO_MIN', default = 0.7, min = 0, max = 4, digits = 2, tooltip = 'minimum depth difference between fragment and sample depths to trigger SSAO sample occlusion. Absolute value in world space coords.'},
	{name = 'SSAO_OCCLUSION_POWER', default = 3, min = 0, max = 16, digits = 1, tooltip = 'how much effect each SSAO sample has'},
	{name = 'SSAO_FADE_DIST_1', default = 1200, min = 200, max = 3000, digits = 1, tooltip = 'near distance for max SSAO'},
	{name = 'SSAO_FADE_DIST_0', default = 2400, min = 1000, max = 4000, digits = 1, tooltip = 'far distance for min SSAO'},
	{name = 'DEBUG_SSAO', default = 0, min = 0, max = 1, digits = 0, tooltip = 'DEBUG_SSAO show the raw samples'},


	{name = 'BRIGHTEN', default = 20, min = 0, max = 255, digits = 0, tooltip = 'Should SSAO Brighten Models, if yes by how much'},
	{name = 'BLUR_HALF_KERNEL_SIZE', default = 3, min = 1, max = 12, digits = 0, tooltip = 'BLUR_HALF_KERNEL_SIZE*2 - 1 samples for blur'},
	{name = 'BLUR_SIGMA', default = 3, min = 1, max = 10, digits = 1, tooltip = 'Sigma width of blur filter'},
	{name = 'MINCOSANGLE', default = -0.15, min = -3, max = 1, digits = 2, tooltip = 'the minimum angle for considering a sample colinear when blurring'},
	{name = 'ZTHRESHOLD', default = 0.005, min = 0.0, max = 4/255.0, digits = 3, tooltip = 'Should be more than 1.0. Do not touch'},
	{name = 'MINSELFWEIGHT', default = 0.2, min = 0.0, max = 1, digits = 2, tooltip = 'The minimum additional weight a sample needs to gather to be considered a non-outlier'},
	{name = 'OUTLIERCORRECTIONFACTOR', default = 0.5, min = 0.0, max = 1, digits = 2, tooltip = 'How strongly to use blurred result instead for outliers'},
	{name = 'BLUR_POWER', default = 2, min = 1, max = 8, digits = 1, tooltip = 'Post-blur correction factor'},
	{name = 'BLUR_CLAMP', default = 0.05, min = 0, max = 1, digits = 3, tooltip = 'Limit occlusion post-blur'},
	{name = 'DEBUG_BLUR', default = 0, min = 0, max = 1, digits = 0, tooltip = 'DEBUG_BLUR show the result of the blur only'},


	{name = 'USE_STENCIL', default = 1, min = 0, max = 1, digits = 0, tooltip = 'USE_STENCIL set to zero if you dont wanna'},
	{name = 'OFFSET', default = 0, min = 0, max = 1, digits = 0, tooltip = 'Set to 2 for half-rez buffers'},
	{name = 'DOWNSAMPLE', default = 1, min = 1, max = 2, digits = 0, tooltip = 'Set to 2 for half-rez buffers'},
	{name = 'ENABLE', default = 1, min = 0, max = 1, digits = 0, tooltip = 'Disable the whole SSAO'},
	{name = 'SLOWFUSE', default = 0, min = 0, max = 1, digits = 0, tooltip = 'Only fuse every 30 frames. DO NOT TOUCH!'},
	{name = 'NOFUSE', default = 0, min = 0, max = 1, digits = 0, tooltip = 'Dont use the gbuf fuse texture'},

	{name = 'SSAO_ALPHA_POW', default = 8, min = 1, max = 20, digits = 0, tooltip = 'Legacy setting'},
}
local function InitShaderDefines()
	for i, shaderDefine in ipairs(definesSlidersParamsList) do
		-- dont overwrite existing, externally defined values with the defaults:
		if shaderConfig[shaderDefine.name] == nil then
			shaderConfig[shaderDefine.name] = shaderDefine.default;
		end
	end
end
InitShaderDefines()

local function shaderDefinesChangedCallback(name, value, index, oldvalue)
	--spEcho("shaderDefinesChangedCallback()", name, value, shaderConfig[name])
	if value ~= oldvalue then
		widget:ViewResize()
	end
end

local vsx, vsy = spGetViewGeometry()

local shaderDefinedSliders = {
	windowtitle = "SSAO Defines",
	name = "SSAOParams",
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

local math_sqrt = mathSqrt

local cusMult = 1.4
local strengthMult = 1

local initialTonemapA = Spring.GetConfigFloat("tonemapA", 4.75)
local initialTonemapD = Spring.GetConfigFloat("tonemapD", 0.85)
local initialTonemapE = Spring.GetConfigFloat("tonemapE", 1.0)

local preset = 3
local presets = {
	{ -- LOW QUALITY
		BLUR_CLAMP = 0.16,
		BLUR_HALF_KERNEL_SIZE = 3,
		BLUR_POWER = 1.6,
		BLUR_SIGMA = 2,
		BRIGHTEN = 30,
		DOWNSAMPLE = 2,
		MINCOSANGLE = 0.69,
		MINSELFWEIGHT = 0.3,
		NOFUSE = 1, -- at low quality, some vram can be saved
		OFFSET = 1,
		OUTLIERCORRECTIONFACTOR = 0.66,
		SSAO_FADE_DIST_0 = 2000,
		SSAO_FADE_DIST_1 = 1000,
		SSAO_KERNEL_SIZE = 24,
		SSAO_MIN = 0.69,
		SSAO_RADIUS = 9,
		USE_STENCIL = 0, -- There is a non-zero cpu cost of drawing the stencil, and at low resolutions, it doesnt help really
	},
	{ -- MEDIUM QUALITY
		BLUR_CLAMP = 0.269,
		BLUR_HALF_KERNEL_SIZE = 4,
		BLUR_POWER = 1.6,
		BLUR_SIGMA = 3,
		BRIGHTEN = 33,
		DOWNSAMPLE = 1,
		MINCOSANGLE = 0.70,
		OUTLIERCORRECTIONFACTOR = 0.16,
		SSAO_FADE_DIST_0 = 2200,
		SSAO_FADE_DIST_1 = 1100,
		SSAO_KERNEL_SIZE = 32,
		SSAO_MIN = 0.74,
		SSAO_RADIUS = 8,
	},
	{ -- HIGH QUALITY
		BLUR_CLAMP = 0.145,
		BLUR_HALF_KERNEL_SIZE = 4,
		BLUR_POWER = 1.6,
		BLUR_SIGMA = 2.9,
		BRIGHTEN = 30,
		DOWNSAMPLE = 1,
		MINCOSANGLE = 0.75,
		OUTLIERCORRECTIONFACTOR = 0.10,
		SSAO_FADE_DIST_0 = 3200,
		SSAO_FADE_DIST_1 = 2000,
		SSAO_KERNEL_SIZE = 64,
		SSAO_MIN = 0.71,
		SSAO_RADIUS = 7,
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

local shadersDir = "LuaUI/Shaders/"

-----------------------------------------------------------------
-- Global Variables
-----------------------------------------------------------------

local LuaShader = gl.LuaShader
local InstanceVBOTable = gl.InstanceVBOTable

local vsx, vsy, vpx, vpy
local texPaddingX, texPaddingY = 0,0

local gbuffFuseFBO
local ssaoFBO
local ssaoBlurFBO

local gbuffFuseViewPosTex
local ssaoTex
local ssaoBlurTex

local ssaoShader
local gbuffFuseShader
local gaussianBlurShader
local ssaoShaderCache
local gbuffFuseShaderCache
local gaussianBlurShaderCache

local texrectShader = nil
local texrectFullVAO = nil
local texrectPaddedVAO = nil

local unitStencilTexture

local unitStencil = nil
-----------------------------------------------------------------
-- Local Functions
-----------------------------------------------------------------

local function G(x, sigma)
	return ( 1 / ( math_sqrt(2 * mathPi) * sigma ) ) * math.exp( -(x * x) / (2 * sigma * sigma) )
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

	spEcho("GetGaussLinearWeightsOffsets(sigma, kernelHalfSize, valMult)",sigma, kernelHalfSize, valMult, 'total = ', totalweights)
	spEcho('dWeights',tabletostring(dWeights))
	spEcho('dOffsets',tabletostring(dOffsets))
	spEcho('weights',tabletostring(weights))
	spEcho('offsets',tabletostring(offsets))
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
	mathRandomseed(kernelSize) -- for repeatability
	if shaderConfig.SSAO_FIBONACCI == 1 then
		local points = {}
		local phi = mathPi * (mathSqrt(5.) - 1.)--  # golden angle in radians
		local samples = 2*kernelSize + math.floor((100 * shaderConfig.SSAO_KERNEL_MINZ))

		for i =0, samples do
			local y = 1 - (i / (samples - 1)) * 2  -- y goes from 1 to -1
			local radius = mathSqrt(1 - y * y)  -- radius at y

			local theta = phi * i  -- golden angle increment

			local x = math.cos(theta) * radius
			local z = math.sin(theta) * radius
			local randlength = math.max(0.2, math.pow(mathRandom(), shaderConfig.SSAO_RANDOM_LENGTH) )
			points[i+1] = {x = x * randlength, y = z* randlength,z =  y* randlength} -- note the swizzle of zy
		end

		for i = 0, kernelSize-1 do
			result[i] = points[i +1]
		end
		return result

	else
		for i = 0, kernelSize - 1 do
			local x, y, z = mathRandom(), mathRandom(), mathRandom() -- [0, 1]^3

			x, y = 2.0 * x - 1.0, 2.0 * y - 1.0 -- xy:[-1, 1]^2, z:[0, 1]
			z = z + shaderConfig.SSAO_KERNEL_MINZ --dont make them fully planar, its wasteful

			local l = math_sqrt(x * x + y * y + z * z) --norm
			x, y, z = x / l, y / l, z / l --normalize

			local scale = i / (kernelSize - 1)
			--scale = scale * scale -- shift most samples closer to the origin
			scale = math.pow(scale, shaderConfig.SSAO_RANDOM_LENGTH)
			scale = math.clamp(scale, 0.2, 1.0) --clamp

			x, y, z = x * scale, y * scale, z * scale -- scale
			result[i] = {x = x, y = y, z = z}
		end
		return result
	end
end

-----------------------------------------------------------------
-- Widget Functions
-----------------------------------------------------------------


local function InitGL()
	local canContinue = LuaShader.isDeferredShadingEnabled and LuaShader.GetAdvShadingActive()

	if not canContinue then
		spEcho(string.format("Error in [%s] widget: %s", widgetName, "Deferred shading is not enabled or advanced shading is not active"))
	end

	-- make unit lighting brighter to compensate for darkening (also restoring values on Shutdown())
	if presets[preset].tonemapA then
		Spring.SetConfigFloat("tonemapA", initialTonemapA + (presets[preset].tonemapA * ((shaderConfig.SSAO_ALPHA_POW * strengthMult)/11)))
		Spring.SetConfigFloat("tonemapD", initialTonemapD + (presets[preset].tonemapD * ((shaderConfig.SSAO_ALPHA_POW * strengthMult)/11)))
		Spring.SetConfigFloat("tonemapE", initialTonemapE + (presets[preset].tonemapE * ((shaderConfig.SSAO_ALPHA_POW * strengthMult)/11)))
		Spring.SendCommands("luarules updatesun")
	end

	vsx, vsy = spGetViewGeometry()

	shaderConfig.VSX = vsx
	shaderConfig.VSY = vsy
	shaderConfig.HSX = mathCeil(vsx / shaderConfig.DOWNSAMPLE)
	shaderConfig.HSY = mathCeil(vsy / shaderConfig.DOWNSAMPLE)
	shaderConfig.TEXPADDINGX = shaderConfig.DOWNSAMPLE * shaderConfig.HSX - vsx
	shaderConfig.TEXPADDINGY = shaderConfig.DOWNSAMPLE * shaderConfig.HSY - vsy

	--spEcho("SSAO SIZING",shaderConfig.DOWNSAMPLE, vsx, vsy, shaderConfig.TEXPADDINGX, shaderConfig.TEXPADDINGY)

	local commonTexOpts = {
		target = GL_TEXTURE_2D,
		border = false,
		min_filter = GL.NEAREST,
		mag_filter = GL.NEAREST,

		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
	}

	if shaderConfig.NOFUSE == 0 then
		commonTexOpts.format = GL_RGB16F
		gbuffFuseViewPosTex = gl.CreateTexture(vsx, vsy, commonTexOpts) -- at 1080p this is 16MB

		gbuffFuseFBO = gl.CreateFBO({
			color0 = gbuffFuseViewPosTex,
			drawbuffers = {GL_COLOR_ATTACHMENT0_EXT},
		})
		if not gl.IsValidFBO(gbuffFuseFBO) then
			spEcho(string.format("Error in [%s] widget: %s", widgetName, "Invalid gbuffFuseFBO"))
		end
	end

	commonTexOpts.min_filter = GL.LINEAR
	commonTexOpts.mag_filter = GL.LINEAR
	commonTexOpts.format = GL_RGBA8

	ssaoTex = gl.CreateTexture(shaderConfig.HSX, shaderConfig.HSY , commonTexOpts)
	ssaoBlurTex = gl.CreateTexture(shaderConfig.HSX, shaderConfig.HSY, commonTexOpts)

	ssaoFBO = gl.CreateFBO({
		color0 = ssaoTex,
		drawbuffers = {GL_COLOR_ATTACHMENT0_EXT},
	})
	if not gl.IsValidFBO(ssaoFBO) then
		spEcho(string.format("Error in [%s] widget: %s", widgetName, "Invalid ssaoFBO"))
	end

	ssaoBlurFBO = gl.CreateFBO({
		color0 = ssaoBlurTex,
		drawbuffers = {GL_COLOR_ATTACHMENT0_EXT},
	})
	if not gl.IsValidFBO(ssaoBlurFBO) then
		spEcho(string.format("Error in [%s] widget: %s", widgetName, string.format("Invalid ssaoBlurFBO")))
	end

	-- ensure stencil is available
	if shaderConfig.USE_STENCIL == 1 then
		unitStencilTexture = WG['unitstencilapi'].GetUnitStencilTexture()
		shaderConfig.USE_STENCIL = unitStencilTexture and 1 or 0
	end

	gbuffFuseShaderCache = {
		vssrcpath = shadersDir.."texrect_screen.vert.glsl",
		fssrcpath = shadersDir.."gbuffFuse.frag.glsl",
		uniformInt = {
			modelDepthTex = 1,
			mapDepthTex = 4,

			unitStencilTex = 7,
		},
		uniformFloat = {},
		silent = true, -- suppress compilation messages
		shaderConfig = shaderConfig,
		shaderName = widgetName.." G-buffer Fuse",
	}

	gbuffFuseShader = LuaShader.CheckShaderUpdates(gbuffFuseShaderCache)

	ssaoShaderCache = {
		vssrcpath = shadersDir.."texrect_screen.vert.glsl",
		fssrcpath = shadersDir.."ssao.frag.glsl",
		uniformInt = {
			viewPosTex = 5,
			viewNormalTex = 6,
			miscTex = 2,

			modelNormalTex = 0,
			modelDepthTex = 1,
			mapNormalTex = 3,
			mapDepthTex = 4,

			unitStencilTex = 7,
		},
		uniformFloat = {
		},
		silent = true, -- suppress compilation messages
		shaderConfig = shaderConfig,
		shaderName = widgetName.." SSAO",
	}

	ssaoShader = LuaShader.CheckShaderUpdates(ssaoShaderCache)

	ssaoShader:ActivateWith( function()
		local samplingKernel = GetSamplingVectorArray(shaderConfig.SSAO_KERNEL_SIZE)
		for i = 0, shaderConfig.SSAO_KERNEL_SIZE - 1 do
			local sv = samplingKernel[i]
			local success = ssaoShader:SetUniformFloatAlways(string.format("samplingKernel[%d]", i), sv.x, sv.y, sv.z)
			--spEcho("ssaoShader:SetUniformFloatAlways",success, i, sv.x, sv.y, sv.z)
		end
		ssaoShader:SetUniformFloatAlways("testuniform", 1.0)
	end)


	gaussianBlurShaderCache = {
		vssrcpath = shadersDir.."texrect_screen.vert.glsl",
		fssrcpath = shadersDir.."gaussianBlur.frag.glsl",
		uniformInt = {
			tex = 0,
			unitStencilTex = 7,
		},
		uniformFloat = {
			dir = {0,1},
			strengthMult = 1,
		},
		silent = true, -- suppress compilation messages
		shaderConfig = shaderConfig,
		shaderName = widgetName.." gaussianBlur",
	}

	gaussianBlurShader = LuaShader.CheckShaderUpdates(gaussianBlurShaderCache)

	local gaussWeights, gaussOffsets = GetGaussLinearWeightsOffsets(shaderConfig.BLUR_SIGMA, shaderConfig.BLUR_HALF_KERNEL_SIZE, 1.0)

	gaussianBlurShader:ActivateWith( function()
		gaussianBlurShader:SetUniformFloatArrayAlways("weights", gaussWeights)
		gaussianBlurShader:SetUniformFloatArrayAlways("offsets", gaussOffsets)
	end)

	texrectShader = LuaShader.CheckShaderUpdates({
		vssrcpath = shadersDir.."texrect_screen.vert.glsl",
		fssrcpath = shadersDir.."texrect_screen.frag.glsl",
		uniformInt = {
			tex = 0,
		},
		uniformFloat = {
			uniformparams = {0,0,0,0},
		},
		silent = true, -- suppress compilation messages
		shaderConfig = {},
		shaderName = widgetName..": texrect",
	})
	
	texrectFullVAO = InstanceVBOTable.MakeTexRectVAO(-1, -1, 1, 1, 0,0,1,1)

	-- These are now offset by the half pixel that is needed here due to ceil(vsx/rez)
	texrectPaddedVAO = InstanceVBOTable.MakeTexRectVAO(-1, -1, 1, 1, 0.0, 0.0, 1.0 - shaderConfig.TEXPADDINGX/shaderConfig.VSX, 1.0 - shaderConfig.TEXPADDINGY/shaderConfig.VSY)


end

local function CleanGL()

	gl.DeleteTexture(ssaoTex)
	if gbuffFuseViewPosTex then gl.DeleteTexture(gbuffFuseViewPosTex) end
	gl.DeleteTexture(ssaoBlurTex)


	gl.DeleteFBO(ssaoFBO)
	if gbuffFuseFBO then gl.DeleteFBO(gbuffFuseFBO) end
	gl.DeleteFBO(ssaoBlurFBO)

	ssaoShader:Finalize()
	gbuffFuseShader:Finalize()
	gaussianBlurShader:Finalize()
	texrectShader:Finalize()
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
		InitShaderDefines()
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
		spEcho(" WG[flowui_gl4] detected")
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
	--if shaderDefinedSlidersWindow and shaderDefinedSlidersWindow.Destroy then shaderDefinedSlidersWindow:Destroy() end

	CleanGL()
end

local function DoDrawSSAO()
	gl.DepthTest(false)
	gl.DepthMask(false) --"BK OpenGL state resets", default is already false, could remove
	gl.Blending(false)

	if shaderConfig.USE_STENCIL == 1 and unitStencilTexture then
		unitStencilTexture = WG['unitstencilapi'].GetUnitStencilTexture() -- needs this to notify that we want it next frame too
		glTexture(7, unitStencilTexture)
	end


	local prevFBO

	if ((shaderConfig.SLOWFUSE == 0) or Spring.GetDrawFrame()%30==0) and (shaderConfig.NOFUSE ~= 1) then
	prevFBO = gl.RawBindFBO(gbuffFuseFBO)
		gbuffFuseShader:Activate() -- ~0.25ms

			gbuffFuseShader:SetUniformMatrix("invProjMatrix", "projectioninverse")
			glTexture(1, "$model_gbuffer_zvaltex")
			glTexture(4, "$map_gbuffer_zvaltex")
			
			texrectFullVAO:DrawArrays(GL.TRIANGLES)

			glTexture(1, false)
			glTexture(4, false)

		gbuffFuseShader:Deactivate()
	--end)
	gl.RawBindFBO(nil, nil, prevFBO)
	end

	prevFBO = gl.RawBindFBO(ssaoFBO)
		gl.Clear(GL.COLOR_BUFFER_BIT, 0, 0, 0, 0)
		ssaoShader:Activate()
			if shaderConfig.NOFUSE > 0 then
				glTexture(1, "$model_gbuffer_zvaltex")
				glTexture(4, "$map_gbuffer_zvaltex")
			else
				glTexture(5, gbuffFuseViewPosTex)
			end
			glTexture(0, "$model_gbuffer_normtex")
			
			texrectFullVAO:DrawArrays(GL.TRIANGLES)

			for i = 0, 6 do glTexture(i,false) end
		ssaoShader:Deactivate()
	gl.RawBindFBO(nil, nil, prevFBO)

	glTexture(0, ssaoTex)

	if shaderConfig.DEBUG_SSAO == 0 then -- dont debug ssao
			gaussianBlurShader:Activate()

				gaussianBlurShader:SetUniform("dir", 1.0, 0.0) --horizontal blur
				prevFBO = gl.RawBindFBO(ssaoBlurFBO)
				texrectFullVAO:DrawArrays(GL.TRIANGLES)
				gl.RawBindFBO(nil, nil, prevFBO)
				glTexture(0, ssaoBlurTex)

				gaussianBlurShader:SetUniform("strengthMult", shaderConfig.SSAO_ALPHA_POW/ 7.0) --vertical blur
				gaussianBlurShader:SetUniform("dir", 0.0, 1.0) --vertical blur
				prevFBO = gl.RawBindFBO(ssaoFBO)
				texrectFullVAO:DrawArrays(GL.TRIANGLES)
				gl.RawBindFBO(nil, nil, prevFBO)
				glTexture(0, ssaoTex)

			gaussianBlurShader:Deactivate()
		if shaderConfig.DEBUG_BLUR == 1 then
			gl.Blending(false) -- now blurred tex contains normals
		else
			if shaderConfig.BRIGHTEN == 0 then
				gl.Blending(GL.ZERO, GL.SRC_ALPHA) -- now blurred tex contains normals
			else
			-- at this point, Alpha contains occlusoin, and rgb contains brighten factor
				gl.Blending(GL.DST_COLOR, GL.SRC_ALPHA) -- now blurred tex contains normals
			end
		end
	else
		if shaderConfig.DEBUG_BLUR == 1 then
			gl.Blending(false) -- now blurred tex contains normals
		else
		end
	end
	-- Already bound
	texrectShader:Activate()
	texrectPaddedVAO:DrawArrays(GL.TRIANGLES)
	texrectShader:Deactivate()


	glTexture(0, false)
	glTexture(1, false)
	glTexture(2, false)
	glTexture(3, false)
	glTexture(4, false)
	glTexture(5, false)
	glTexture(6, false)
	glTexture(7, false)

	-- Extremely important, this is the state that we have to leave when exiting DrawWorldPreParticles!
	gl.Blending(GL.ONE, GL.ONE_MINUS_SRC_ALPHA)
	gl.DepthMask(false) --"BK OpenGL state resets", already commented out
	gl.DepthTest(true) --"BK OpenGL state resets", already commented out
end

function widget:DrawWorldPreParticles(drawAboveWater, drawBelowWater, drawReflection, drawRefraction)
	if shaderConfig.ENABLE == 0 then return end
	if drawAboveWater and not drawReflection and not drawRefraction then
		DoDrawSSAO()
	end
end

function widget:GetConfigData(data)
	return {
		strength = shaderConfig.SSAO_ALPHA_POW,
		radius = shaderConfig.SSAO_RADIUS,
		preset = preset
	}
end

local lastfps = Spring.GetFPS()
function widget:DrawScreen()
	if shaderDefinedSlidersLayer then
		local newfps = Spring.GetFPS()
		if ssaoShaderCache.updateFlag then
			ssaoShaderCache.updateFlag = nil
			lastfps = newfps
		end
		local totaldrawus = (1000/newfps)
		local lastdelta = (1000/lastfps - 1000/newfps)

		gl.Text(string.format("SSAO total %.3f ms delta %.3f ms", totaldrawus, lastdelta),  vsx - 600,  20, 16, "do")
	end
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
	spEcho("widget:SetConfigData SSAO preset=", preset)
	InitShaderDefines()
	ActivatePreset(preset)
	--widget:ViewResize()
end
