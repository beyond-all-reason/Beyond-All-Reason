local wiName = "Outline"
function widget:GetInfo()
	return {
		name      = wiName,
		desc      = "Displays small outline around units based on deferred g-buffer",
		author    = "ivand",
		date      = "2019",
		license   = "GNU GPL, v2 or later",
		layer     = -10,
		enabled   = false  --  loaded by default?
	}
end

-----------------------------------------------------------------
-- Constants
-----------------------------------------------------------------

local GL_COLOR_ATTACHMENT0_EXT = 0x8CE0

-----------------------------------------------------------------
-- Configuration Constants
-----------------------------------------------------------------

--local MIN_FPS = 20
--local MIN_FPS_DELTA = 10
--local AVG_FPS_ELASTICITY = 0.2
--local AVG_FPS_ELASTICITY_INV = 1.0 - AVG_FPS_ELASTICITY

local BLUR_HALF_KERNEL_SIZE = 5 -- (BLUR_HALF_KERNEL_SIZE + BLUR_HALF_KERNEL_SIZE + 1) samples are used to perform the blur.
local BLUR_PASSES = 1 -- number of blur passes
local BLUR_SIGMA = 1 -- Gaussian sigma of a single blur pass, other factors like BLUR_HALF_KERNEL_SIZE, BLUR_PASSES and DOWNSAMPLE affect the end result gaussian shape too

local OUTLINE_COLOR = {0.0, 0.0, 0.0, 1.0}
local OUTLINE_STRENGTH = 2.5 -- make it much smaller for softer edges

local USE_MATERIAL_INDICES = true -- for future material indices based SSAO evaluation


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


local shapeTex
local blurTexes = {}

local shapeFBO
local blurFBOs = {}

local shapeShader
local gaussianBlurShader
local applicationShader


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

	shapeTex = gl.CreateTexture(vsx, vsy, commonTexOpts)

	commonTexOpts.mag_filter = GL.LINEAR
	for i = 1, 2 do
		blurTexes[i] = gl.CreateTexture(vsx, vsy, commonTexOpts)
	end



	shapeFBO = gl.CreateFBO({
		color0 = shapeTex,
		drawbuffers = {GL_COLOR_ATTACHMENT0_EXT},
	})

	if not gl.IsValidFBO(shapeFBO) then
		Spring.Echo(string.format("Error in [%s] widget: %s", wiName, "Invalid shapeFBO"))
	end

	for i = 1, 2 do
		blurFBOs[i] = gl.CreateFBO({
			color0 = blurTexes[i],
			drawbuffers = {GL_COLOR_ATTACHMENT0_EXT},
		})
		if not gl.IsValidFBO(blurFBOs[i]) then
			Spring.Echo(string.format("Error in [%s] widget: %s", wiName, string.format("Invalid blurFBOs[%d]", i)))
		end
	end


	local identityShaderVert = VFS.LoadFile(shadersDir.."identity.vert.glsl")

	local shapeShaderFrag = VFS.LoadFile(shadersDir.."outlineShape.frag.glsl")

	shapeShaderFrag = shapeShaderFrag:gsub("###USE_MATERIAL_INDICES###", tostring((USE_MATERIAL_INDICES and 1) or 0))

	shapeShader = LuaShader({
		vertex = identityShaderVert,
		fragment = shapeShaderFrag,
		uniformInt = {
			-- be consistent with gfx_deferred_rendering.lua
			--	glTexture(1, "$model_gbuffer_zvaltex")
			modelDepthTex = 1,
			modelMiscTex = 2,
			mapDepthTex = 3,
		},
		uniformFloat = {
			outlineColor = OUTLINE_COLOR,
		},
	}, wiName..": Shape drawing")
	shapeShader:Initialize()

	local gaussianBlurFrag = VFS.LoadFile(shadersDir.."gaussianBlur.frag.glsl")

	gaussianBlurFrag = gaussianBlurFrag:gsub("###BLUR_HALF_KERNEL_SIZE###", tostring(BLUR_HALF_KERNEL_SIZE))

	gaussianBlurShader = LuaShader({
		vertex = identityShaderVert,
		fragment = gaussianBlurFrag,
		uniformInt = {
			tex = 0,
		},
		uniformFloat = {
			viewPortSize = {vsx, vsy},
		},
	}, wiName..": Gaussian Blur")
	gaussianBlurShader:Initialize()

	local gaussWeights, gaussOffsets = GetGaussLinearWeightsOffsets(BLUR_SIGMA, BLUR_HALF_KERNEL_SIZE, OUTLINE_STRENGTH)

	gaussianBlurShader:ActivateWith( function()
		gaussianBlurShader:SetUniformFloatArrayAlways("weights", gaussWeights)
		gaussianBlurShader:SetUniformFloatArrayAlways("offsets", gaussOffsets)
	end)

	local applicationFrag = VFS.LoadFile(shadersDir.."outlineApplication.frag.glsl")

	applicationShader = LuaShader({
		vertex = identityShaderVert,
		fragment = applicationFrag,
		uniformInt = {
			tex = 0,
			modelDepthTex = 1,
		},
		uniformFloat = {
			viewPortSize = {vsx, vsy},
		},
	}, wiName..": Outline Application")
	applicationShader:Initialize()

	WG['outline'] = {}
	WG['outline'].getSize = function()
		return BLUR_SIGMA
	end
	WG['outline'].setSize = function(value)
		BLUR_SIGMA = value
		widget:Shutdown()
		widget:Initialize()
	end
	WG['outline'].getStrength = function()
		return OUTLINE_STRENGTH
	end
	WG['outline'].setStrength = function(value)
		OUTLINE_STRENGTH = value
		widget:Shutdown()
		widget:Initialize()
	end
end

function widget:Shutdown()
	firstTime = nil

	if screenQuadList then
		gl.DeleteList(screenQuadList)
	end

	if screenWideList then
		gl.DeleteList(screenWideList)
	end

	gl.DeleteTexture(shapeTex)

	for i = 1, 2 do
		gl.DeleteTexture(blurTexes[i])
	end

	gl.DeleteFBO(shapeFBO)
	for i = 1, 2 do
		gl.DeleteFBO(blurFBOs[i])
	end

	shapeShader:Finalize()
	gaussianBlurShader:Finalize()
	applicationShader:Finalize()
end

local show = true
local function DoDrawOutline(isScreenSpace)
	if not show then
		return
	end
	gl.DepthTest(false)
	gl.DepthMask(false)
	gl.Blending(false)

	if firstTime then
		screenQuadList = gl.CreateList(gl.TexRect, -1, -1, 1, 1)
		if isScreenSpace then
			--screenWideList = gl.CreateList(gl.TexRect, 0, vsy, vsx, 0)
			screenWideList = gl.CreateList(gl.TexRect, 0, vsy, vsx, 0)
		else
			screenWideList = gl.CreateList(gl.TexRect, -1, -1, 1, 1, false, true)
		end
		firstTime = false
	end

	gl.ActiveFBO(shapeFBO, function()
		shapeShader:ActivateWith( function ()
			gl.Texture(1, "$model_gbuffer_zvaltex")
			if USE_MATERIAL_INDICES then
				gl.Texture(2, "$model_gbuffer_misctex")
			end
			gl.Texture(3, "$map_gbuffer_zvaltex")

			gl.CallList(screenQuadList) -- gl.TexRect(-1, -1, 1, 1)

			--gl.Texture(1, false) --will reuse later
			if USE_MATERIAL_INDICES then
				gl.Texture(2, false)
			end
			gl.Texture(3, false)
		end)
	end)

	gl.Texture(0, shapeTex)

	for i = 1, BLUR_PASSES do
		gaussianBlurShader:ActivateWith( function ()

			gaussianBlurShader:SetUniform("dir", 1.0, 0.0) --horizontal blur
			gl.ActiveFBO(blurFBOs[1], function()
				gl.CallList(screenQuadList) -- gl.TexRect(-1, -1, 1, 1)
			end)
			gl.Texture(0, blurTexes[1])

			gaussianBlurShader:SetUniform("dir", 0.0, 1.0) --vertical blur
			gl.ActiveFBO(blurFBOs[2], function()
				gl.CallList(screenQuadList) -- gl.TexRect(-1, -1, 1, 1)
			end)
			gl.Texture(0, blurTexes[2])

		end)
	end

	gl.Blending(true)
	gl.BlendFunc(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA) --alpha NO pre-multiply

	--gl.Texture(1, "$model_gbuffer_zvaltex") -- already bound

	applicationShader:ActivateWith( function ()
		gl.CallList(screenWideList)
	end)

	gl.Texture(0, false)
	gl.Texture(1, false)
end


--local accuTime = 0
--local lastTime = 0
--local averageFPS = MIN_FPS + MIN_FPS_DELTA
--
--function widget:Update(dt)
--	accuTime = accuTime + dt
--	if accuTime >= lastTime + 1 then
--		lastTime = accuTime
--		averageFPS = AVG_FPS_ELASTICITY_INV * averageFPS + AVG_FPS_ELASTICITY * Spring.GetFPS()
--		if averageFPS < MIN_FPS then
--			show = false
--		elseif averageFPS > MIN_FPS + MIN_FPS_DELTA then
--			show = true
--		end
--	end
--end

function widget:DrawUnitsPostDeferred() --to be done
	--Spring.Echo("DrawUnitsPostDeferred")
end

function widget:DrawScreenEffects()
	--DoDrawOutline(true)
end

function widget:DrawWorld()
	gl.MatrixMode(GL.MODELVIEW)
	gl.PushMatrix()
	gl.LoadIdentity()

		gl.MatrixMode(GL.PROJECTION)
		gl.PushMatrix()
		gl.LoadIdentity();

			DoDrawOutline(false)

		gl.MatrixMode(GL.PROJECTION)
		gl.PopMatrix()

	gl.MatrixMode(GL.MODELVIEW)
	gl.PopMatrix()
end


function widget:GetConfigData()
	savedTable = {}
	savedTable.BLUR_SIGMA = BLUR_SIGMA
	savedTable.OUTLINE_STRENGTH = OUTLINE_STRENGTH
	return savedTable
end

function widget:SetConfigData(data)
	if data.BLUR_SIGMA then BLUR_SIGMA = data.BLUR_SIGMA or BLUR_SIGMA end
	if data.OUTLINE_STRENGTH then OUTLINE_STRENGTH = data.OUTLINE_STRENGTH or OUTLINE_STRENGTH end
end
