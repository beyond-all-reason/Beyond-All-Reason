local wiName = "Outline"
function widget:GetInfo()
	return {
		name      = wiName,
		desc      = "Displays small outline around units based on deferred g-buffer",
		author    = "ivand",
		date      = "2019",
		layer     = math.huge,
		enabled   = false  --  loaded by default?
	}
end

-----------------------------------------------------------------
-- Constants
-----------------------------------------------------------------

local GL_COLOR_ATTACHMENT0_EXT = 0x8CE0

local GL_RGBA = 0x1908
--GL_DEPTH_COMPONENT32F is the default for deferred depth textures, but Lua API only works correctly with GL_DEPTH_COMPONENT32
local GL_DEPTH_COMPONENT32 = 0x81A7


-----------------------------------------------------------------
-- Configuration Constants
-----------------------------------------------------------------

--[[
local MIN_FPS = 20
local MIN_FPS_DELTA = 10
local AVG_FPS_ELASTICITY = 0.2
local AVG_FPS_ELASTICITY_INV = 1.0 - AVG_FPS_ELASTICITY
]]--

local DILATE_SINGLE_PASS = false --true is slower on my system
local DILATE_HALF_KERNEL_SIZE = 1
local DILATE_PASSES = 1

local STRENGTH_MULT = 0.5

local OUTLINE_ZOOM_SCALE = true
local OUTLINE_COLOR = {0, 0, 0, 1.0}
local whiteColored = false
--local OUTLINE_COLOR = {0.0, 0.0, 0.0, 1.0}
local OUTLINE_STRENGTH_BLENDED = 1.0
local OUTLINE_STRENGTH_ALWAYS_ON = 0.6

local USE_MATERIAL_INDICES = true -- for future material indices based outline evaluation

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

local screenQuadList
local screenWideList


local shapeDepthTex
local shapeColorTex

local dilationDepthTexes = {}
local dilationColorTexes = {}

local shapeFBO
local dilationFBOs = {}

local shapeShader
local dilationShader
local applicationShader

local pingPongIdx = 1


-----------------------------------------------------------------
-- Local Functions
-----------------------------------------------------------------

local function GetZoomScale()
	local cs = Spring.GetCameraState()
	local gy = Spring.GetGroundHeight(cs.px, cs.pz)
	local cameraHeight
	if cs.name == "ta" then
		cameraHeight = cs.height - gy
	else
		cameraHeight = cs.py - gy
	end
	cameraHeight = math.max(1.0, cameraHeight)
	local scaleFactor = 250.0 / cameraHeight
	scaleFactor = math.min(math.max(0.5, scaleFactor), 1.0)
	--Spring.Echo(cameraHeight, scaleFactor)
	return scaleFactor
end

local show = true
local function PrepareOutline(cleanState)
	if not show then
		return
	end

	gl.DepthTest(true)
	gl.DepthTest(GL.ALWAYS)

	gl.ActiveFBO(shapeFBO, function()
		shapeShader:ActivateWith( function ()
			gl.Texture(2, "$model_gbuffer_zvaltex")
			if USE_MATERIAL_INDICES then
				gl.Texture(1, "$model_gbuffer_misctex")
			end
			gl.Texture(3, "$map_gbuffer_zvaltex")

			gl.CallList(screenQuadList) -- gl.TexRect(-1, -1, 1, 1)

			--gl.Texture(1, false) --will reuse later
			if USE_MATERIAL_INDICES then
				gl.Texture(1, false)
			end
		end)
	end)


	gl.Texture(0, shapeDepthTex)
	gl.Texture(1, shapeColorTex)

	--Spring.Echo("DILATE_HALF_KERNEL_SIZE", DILATE_HALF_KERNEL_SIZE)

	for i = 1, DILATE_PASSES do
		dilationShader:ActivateWith( function ()
			local strength
			if OUTLINE_ZOOM_SCALE then
				strength = GetZoomScale()
			end
			dilationShader:SetUniformFloat("strength", strength)
			dilationShader:SetUniformInt("dilateHalfKernelSize", DILATE_HALF_KERNEL_SIZE)

			if DILATE_SINGLE_PASS then
				pingPongIdx = (pingPongIdx + 1) % 2
				gl.ActiveFBO(dilationFBOs[pingPongIdx + 1], function()
					gl.CallList(screenQuadList) -- gl.TexRect(-1, -1, 1, 1)
				end)
				gl.Texture(0, dilationDepthTexes[pingPongIdx + 1])
				gl.Texture(1, dilationColorTexes[pingPongIdx + 1])

			else
				pingPongIdx = (pingPongIdx + 1) % 2
				dilationShader:SetUniform("dir", 1.0, 0.0) --horizontal dilation
				gl.ActiveFBO(dilationFBOs[pingPongIdx + 1], function()
					gl.CallList(screenQuadList) -- gl.TexRect(-1, -1, 1, 1)
				end)
				gl.Texture(0, dilationDepthTexes[pingPongIdx + 1])
				gl.Texture(1, dilationColorTexes[pingPongIdx + 1])

				pingPongIdx = (pingPongIdx + 1) % 2
				dilationShader:SetUniform("dir", 0.0, 1.0) --vertical dilation
				gl.ActiveFBO(dilationFBOs[pingPongIdx + 1], function()
					gl.CallList(screenQuadList) -- gl.TexRect(-1, -1, 1, 1)
				end)
				gl.Texture(0, dilationDepthTexes[pingPongIdx + 1])
				gl.Texture(1, dilationColorTexes[pingPongIdx + 1])
			end
		end)
	end

	if cleanState then
		gl.DepthTest(GL.LEQUAL) --default mode

		gl.Texture(0, false)
		gl.Texture(1, false)
		gl.Texture(2, false)
		gl.Texture(3, false)
	end
end

local function DrawOutline(strength, loadTextures, alwaysVisible)
	if not show then
		return
	end

	if loadTextures then
		gl.Texture(0, dilationDepthTexes[pingPongIdx + 1])
		gl.Texture(1, dilationColorTexes[pingPongIdx + 1])
		gl.Texture(2, shapeDepthTex)
		gl.Texture(3, "$map_gbuffer_zvaltex")
	end

	gl.AlphaTest(true)
	gl.AlphaTest(GL.GREATER, 0.0);
	gl.DepthTest(GL.LEQUAL) --restore default mode
	gl.Blending(true)

	applicationShader:ActivateWith( function ()
		applicationShader:SetUniformFloat("alwaysShowOutLine", (alwaysVisible and 1.0) or 0.0)
		applicationShader:SetUniformFloat("strength", strength * STRENGTH_MULT)
		gl.CallList(screenWideList)
	end)

	gl.Texture(0, false)
	gl.Texture(1, false)
	gl.Texture(2, false)
	gl.Texture(3, false)

	gl.DepthTest(not alwaysVisible)
	gl.Blending(false)
	gl.AlphaTest(GL.GREATER, 0.5);  --default mode
	gl.AlphaTest(false)
end


local function EnterLeaveScreenSpace(functionName, ...)
	gl.MatrixMode(GL.MODELVIEW)
	gl.PushMatrix()
	gl.LoadIdentity()

		gl.MatrixMode(GL.PROJECTION)
		gl.PushMatrix()
		gl.LoadIdentity();

			functionName(...)

		gl.MatrixMode(GL.PROJECTION)
		gl.PopMatrix()

	gl.MatrixMode(GL.MODELVIEW)
	gl.PopMatrix()
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

	local configName = "AllowDrawModelPostDeferredEvents"
	if Spring.GetConfigInt(configName, 0) == 0 then
		Spring.SetConfigInt(configName, 1) --required to enable receiving DrawUnitsPostDeferred/DrawFeaturesPostDeferred
	end

	vsx, vsy, vpx, vpy = Spring.GetViewGeometry()

	-- depth textures
	local commonTexOpts = {
		target = GL_TEXTURE_2D,
		border = false,
		min_filter = GL.NEAREST,
		mag_filter = GL.NEAREST,

		format = GL_DEPTH_COMPONENT32,

		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
	}

	shapeDepthTex = gl.CreateTexture(vsx, vsy, commonTexOpts)
	for i = 1, 2 do
		dilationDepthTexes[i] = gl.CreateTexture(vsx, vsy, commonTexOpts)
	end

	-- color textures
	commonTexOpts.format = GL_RGBA
	shapeColorTex = gl.CreateTexture(vsx, vsy, commonTexOpts)
	for i = 1, 2 do
		dilationColorTexes[i] = gl.CreateTexture(vsx, vsy, commonTexOpts)
	end

	shapeFBO = gl.CreateFBO({
		depth = shapeDepthTex,
		color0 = shapeColorTex,
		drawbuffers = {GL_COLOR_ATTACHMENT0_EXT},
	})

	if not gl.IsValidFBO(shapeFBO) then
		Spring.Echo(string.format("Error in [%s] widget: %s", wiName, "Invalid shapeFBO"))
	end

	for i = 1, 2 do
		dilationFBOs[i] = gl.CreateFBO({
			depth = dilationDepthTexes[i],
			color0 = dilationColorTexes[i],
			drawbuffers = {GL_COLOR_ATTACHMENT0_EXT},
		})
		if not gl.IsValidFBO(dilationFBOs[i]) then
			Spring.Echo(string.format("Error in [%s] widget: %s", wiName, string.format("Invalid dilationFBOs[%d]", i)))
		end
	end

	local identityShaderVert = VFS.LoadFile(shadersDir.."identity.vert.glsl")

	local shapeShaderFrag = VFS.LoadFile(shadersDir.."outlineShape.frag.glsl")

	shapeShaderFrag = shapeShaderFrag:gsub("###USE_MATERIAL_INDICES###", tostring((USE_MATERIAL_INDICES and 1) or 0))

	shapeShader = LuaShader({
		vertex = identityShaderVert,
		fragment = shapeShaderFrag,
		uniformInt = {
			modelDepthTex = 2,
			modelMiscTex = 1,
			mapDepthTex = 3,
		},
		uniformFloat = {
			outlineColor = OUTLINE_COLOR,
			--viewPortSize = {vsx, vsy},
		},
	}, wiName..": Shape identification")
	shapeShader:Initialize()

	local dilationShaderFrag = VFS.LoadFile(shadersDir.."outlineDilate.frag.glsl")
	dilationShaderFrag = dilationShaderFrag:gsub("###DILATE_SINGLE_PASS###", tostring((DILATE_SINGLE_PASS and 1) or 0))

	dilationShader = LuaShader({
		vertex = identityShaderVert,
		fragment = dilationShaderFrag,
		uniformInt = {
			depthTex = 0,
			colorTex = 1,
			dilateHalfKernelSize = DILATE_HALF_KERNEL_SIZE,
		},
		uniformFloat = {
			viewPortSize = {vsx, vsy},
		}
	}, wiName..": Dilation")
	dilationShader:Initialize()


	local applicationFrag = VFS.LoadFile(shadersDir.."outlineApplication.frag.glsl")

	applicationShader = LuaShader({
		vertex = identityShaderVert,
		fragment = applicationFrag,
		uniformInt = {
			dilatedDepthTex = 0,
			dilatedColorTex = 1,
			shapeDepthTex = 2,
			mapDepthTex = 3,
		},
		uniformFloat = {
			viewPortSize = {vsx, vsy},
		},
	}, wiName..": Outline Application")
	applicationShader:Initialize()

	screenQuadList = gl.CreateList(gl.TexRect, -1, -1, 1, 1)
	screenWideList = gl.CreateList(gl.TexRect, -1, -1, 1, 1, false, true)

	WG['outline'] = {}
	WG['outline'].getWidth = function()
		return DILATE_HALF_KERNEL_SIZE
	end
	WG['outline'].setWidth = function(value)
		DILATE_HALF_KERNEL_SIZE = value
		widget:Shutdown()
		widget:Initialize()
	end
	WG['outline'].getMult = function()
		return STRENGTH_MULT
	end
	WG['outline'].setMult = function(value)
		STRENGTH_MULT = value
		widget:Shutdown()
		widget:Initialize()
	end
	WG['outline'].getColor = function()
		return whiteColored
	end
	WG['outline'].setColor = function(value)
		whiteColored = value
		if whiteColored then
			OUTLINE_COLOR = {0.75, 0.75, 0.75, 1.0}
		else
			OUTLINE_COLOR = {0, 0, 0, 1.0}
		end
		widget:Shutdown()
		widget:Initialize()
	end
end

function widget:Shutdown()
	if screenQuadList then
		gl.DeleteList(screenQuadList)
	end

	if screenWideList then
		gl.DeleteList(screenWideList)
	end

	gl.DeleteTexture(shapeDepthTex)
	gl.DeleteTexture(shapeColorTex)

	for i = 1, 2 do
		gl.DeleteTexture(dilationColorTexes[i])
		gl.DeleteTexture(dilationDepthTexes[i])
	end

	gl.DeleteFBO(shapeFBO)

	for i = 1, 2 do
		gl.DeleteFBO(dilationFBOs[i])
	end

	shapeShader:Finalize()
	dilationShader:Finalize()
	applicationShader:Finalize()

	WG['outline'] = nil
end

--[[
local accuTime = 0
local lastTime = 0
local averageFPS = MIN_FPS + MIN_FPS_DELTA

function widget:Update(dt)
	accuTime = accuTime + dt
	if accuTime >= lastTime + 1 then
		lastTime = accuTime
		averageFPS = AVG_FPS_ELASTICITY_INV * averageFPS + AVG_FPS_ELASTICITY * Spring.GetFPS()
		if averageFPS < MIN_FPS then
			show = false
		elseif averageFPS > MIN_FPS + MIN_FPS_DELTA then
			show = true
		end
	end
end
]]--


-- For debug
--[[
function widget:DrawScreenEffects()
	gl.Blending(false)

	gl.Texture(0, dilationDepthTexes[pingPongIdx + 1])
	gl.Texture(0, dilationColorTexes[pingPongIdx + 1])
	--gl.TexRect(0, 0, vsx, vsy, false, true)
	gl.Texture(0, false)
end
]]--


function widget:DrawWorld()
	EnterLeaveScreenSpace(DrawOutline, OUTLINE_STRENGTH_ALWAYS_ON, true, true)
end

function widget:DrawUnitsPostDeferred()
	EnterLeaveScreenSpace(function ()
		PrepareOutline(false)
		DrawOutline(OUTLINE_STRENGTH_BLENDED, false, false)
	end)
end


function widget:GetConfigData()
	return {
		DILATE_HALF_KERNEL_SIZE = DILATE_HALF_KERNEL_SIZE,
		STRENGTH_MULT = STRENGTH_MULT,
		whiteColored = whiteColored
	}
end

function widget:SetConfigData(data)
	if data.DILATE_HALF_KERNEL_SIZE then DILATE_HALF_KERNEL_SIZE = data.DILATE_HALF_KERNEL_SIZE or DILATE_HALF_KERNEL_SIZE end
	if data.STRENGTH_MULT then STRENGTH_MULT = data.STRENGTH_MULT or STRENGTH_MULT end
	if data.whiteColored ~= nil then
		whiteColored = data.whiteColored
		if whiteColored then
			OUTLINE_COLOR = {0.75, 0.75, 0.75, 1.0}
		else
			OUTLINE_COLOR = {0, 0, 0, 1.0}
		end
	end
end
