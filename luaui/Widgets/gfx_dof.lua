local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name	  = "Depth of Field",
		version	  = 2.0,
		desc	  = "Blurs far away objects.",
		author	= "aeonios, Shadowfury333 (with some code from Kleber Garcia)",
		date	  = "Feb. 2019",
		license   = "GPL, MIT",
		layer	 = -100000, --To run after gfx_deferred_rendering.lua
		enabled   = false
	}
end

local highQuality = true		-- doesnt seem to do anything
local autofocus = true
local mousefocus = not autofocus
local focusDepth = 300
local fStop = 2

local autofocusInFocusMultiplier = fStop/2	-- Autofocus Minimum In-Focus region size
local autofocusPower = 6				-- Autofocus Power (lower = blurrier at range)
local autofocusFocalLength = 0.03		-- Autofocus Focal Length

-----------------------------------------------------------------
-- Engine Functions
-----------------------------------------------------------------

local spGetCameraPosition   = Spring.GetCameraPosition

local math_max = math.max
local math_log = math.log
local math_sqrt = math.sqrt

local glCopyToTexture = gl.CopyToTexture
local glCreateShader = gl.CreateShader
local glCreateTexture = gl.CreateTexture
local glDeleteShader = gl.DeleteShader
local glDeleteTexture = gl.DeleteTexture
local glTexture	= gl.Texture
local glTexRect	= gl.TexRect
local glRenderToTexture = gl.RenderToTexture
local glUseShader = gl.UseShader
local glUniform = gl.Uniform
local glUniformInt = gl.UniformInt
local glUniformMatrix = gl.UniformMatrix

local GL_DEPTH_COMPONENT   = 0x1902
local GL_DEPTH_COMPONENT16 = 0x81A5
local GL_DEPTH_COMPONENT24 = 0x81A6
local GL_DEPTH_COMPONENT32 = 0x81A7

local GL_COLOR_ATTACHMENT0_EXT = 0x8CE0
local GL_COLOR_ATTACHMENT1_EXT = 0x8CE1
local GL_COLOR_ATTACHMENT2_EXT = 0x8CE2
local GL_COLOR_ATTACHMENT3_EXT = 0x8CE3

local GL_RGBA16F_ARB = 0x881A

local baseBlurTex, baseNearBlurTex, intermediateBlurTex0, intermediateBlurTex1, intermediateBlurTex2, intermediateBlurTex3, finalBlurTex, finalNearBlurTex
local screenTex, depthTex, intermediateBlurFBO, baseBlurFBO
local chobbyInterface

-----------------------------------------------------------------


local function CleanupTextures()
	glDeleteTexture(baseBlurTex)
	glDeleteTexture(baseNearBlurTex)
	glDeleteTexture(intermediateBlurTex0)
	glDeleteTexture(intermediateBlurTex1)
	glDeleteTexture(intermediateBlurTex2)
	glDeleteTexture(intermediateBlurTex3)
	glDeleteTexture(finalBlurTex)
	glDeleteTexture(finalNearBlurTex)
	glDeleteTexture(screenTex)
	glDeleteTexture(depthTex)
	gl.DeleteFBO(intermediateBlurFBO)
	gl.DeleteFBO(baseBlurFBO)
	baseBlurTex, baseNearBlurTex, intermediateBlurTex0, intermediateBlurTex1,
	intermediateBlurTex2, intermediateBlurTex3, finalBlurTex, finalNearBlurTex,
	screenTex, depthTex =
		nil, nil, nil, nil,
		nil, nil, nil, nil,
		nil, nil
	intermediateBlurFBO = nil
	baseBlurFBO = nil
end
-----------------------------------------------------------------
-- Global Vars
-----------------------------------------------------------------

local maxBlurDistance = 10000 --Distance in Spring units above which autofocus blurring can't happen

local vsx = nil	-- current viewport width
local vsy = nil	-- current viewport height
local vpx = nil	-- current viewport pos x
local vpy = nil	-- current viewport pos y
local dofShader = nil
local screenTex = nil
local depthTex = nil
local baseBlurTex = nil
local baseNearBlurTex = nil
local baseBlurFBO = nil
local intermediateBlurTex0 = nil
local intermediateBlurTex1 = nil
local intermediateBlurTex2 = nil
local intermediateBlurTex3 = nil
local intermediateBlurFBO = nil
local finalBlurTex = nil
local finalNearBlurTex = nil

-- shader uniform handles
local eyePosLoc = nil
local projectionMatLoc = nil
local resolutionLoc = nil
local distanceLimitsLoc = nil
local autofocusLoc = nil
local autofocusFudgeFactorLoc = nil
local autofocusPowerLoc = nil
local autofocusFocalLengthLoc = nil
local mousefocusLoc = nil
local focusDepthLoc = nil
local mouseDepthCoordLoc = nil
local fStopLoc = nil
local qualityLoc = nil
local passLoc = nil

-- shader uniform enums
local shaderPasses =
{
	filterSize = 0,
	initialBlur = 1,
	finalBlur = 2,
	initialNearBlur = 3,
	finalNearBlur = 4,
	composition = 5,
}


function InitTextures()
	vsx, vsy, vpx, vpy = Spring.GetViewGeometry()
	local blurTexSizeX, blurTexSizeY = vsx/2, vsy/2;

	CleanupTextures()

	screenTex = glCreateTexture(vsx, vsy, {
		fbo = true, min_filter = GL.LINEAR, mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP_TO_EDGE, wrap_t = GL.CLAMP_TO_EDGE,
	})

	depthTex = gl.CreateTexture(vsx,vsy, {
		border = false,
		format = GL_DEPTH_COMPONENT32,
		min_filter = GL.NEAREST,
		mag_filter = GL.NEAREST,
	})

	baseBlurTex = glCreateTexture(blurTexSizeX, blurTexSizeY, {
		min_filter = GL.LINEAR, mag_filter = GL.LINEAR,
		format = GL_RGBA16F_ARB, wrap_s = GL.CLAMP_TO_EDGE, wrap_t = GL.CLAMP_TO_EDGE,
	})
	if highQuality then
		baseNearBlurTex = glCreateTexture(blurTexSizeX, blurTexSizeY, {
			min_filter = GL.LINEAR, mag_filter = GL.LINEAR,
			format = GL_RGBA16F_ARB, wrap_s = GL.CLAMP_TO_EDGE, wrap_t = GL.CLAMP_TO_EDGE,
		})
	end

	intermediateBlurTex0 = glCreateTexture(blurTexSizeX, blurTexSizeY, {
		min_filter = GL.LINEAR, mag_filter = GL.LINEAR,
		format = GL_RGBA16F_ARB, wrap_s = GL.CLAMP_TO_EDGE, wrap_t = GL.CLAMP_TO_EDGE,
	})

	intermediateBlurTex1 = glCreateTexture(blurTexSizeX, blurTexSizeY, {
		 min_filter = GL.LINEAR, mag_filter = GL.LINEAR,
		format = GL_RGBA16F_ARB, wrap_s = GL.CLAMP_TO_EDGE, wrap_t = GL.CLAMP_TO_EDGE,
	})

	intermediateBlurTex2 = glCreateTexture(blurTexSizeX, blurTexSizeY, {
		 min_filter = GL.LINEAR, mag_filter = GL.LINEAR,
		format = GL_RGBA16F_ARB, wrap_s = GL.CLAMP_TO_EDGE, wrap_t = GL.CLAMP_TO_EDGE,
	})

	if highQuality then
		intermediateBlurTex3 = glCreateTexture(blurTexSizeX, blurTexSizeY, {
			 min_filter = GL.LINEAR, mag_filter = GL.LINEAR,
			format = GL_RGBA16F_ARB, wrap_s = GL.CLAMP_TO_EDGE, wrap_t = GL.CLAMP_TO_EDGE,
		})
	end

	finalBlurTex = glCreateTexture(blurTexSizeX, blurTexSizeY, {
		fbo = true, min_filter = GL.LINEAR, mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP_TO_EDGE, wrap_t = GL.CLAMP_TO_EDGE,
	})
	if highQuality then
		finalNearBlurTex = glCreateTexture(blurTexSizeX, blurTexSizeY, {
			fbo = true, min_filter = GL.LINEAR, mag_filter = GL.LINEAR,
			wrap_s = GL.CLAMP_TO_EDGE, wrap_t = GL.CLAMP_TO_EDGE,
		})
	end

	if highQuality then
		baseBlurFBO = gl.CreateFBO({
			color0 = baseBlurTex,
			color1 = baseNearBlurTex,
		drawbuffers = {
			GL_COLOR_ATTACHMENT0_EXT,
			GL_COLOR_ATTACHMENT1_EXT
		}
			})

		intermediateBlurFBO = gl.CreateFBO({
			color0 = intermediateBlurTex0,
			color1 = intermediateBlurTex1,
			color2 = intermediateBlurTex2,
			color3 = intermediateBlurTex3,
		drawbuffers = {
			GL_COLOR_ATTACHMENT0_EXT,
			GL_COLOR_ATTACHMENT1_EXT,
			GL_COLOR_ATTACHMENT2_EXT,
			GL_COLOR_ATTACHMENT3_EXT
		}
			})
	else
		baseBlurFBO = gl.CreateFBO({
			color0 = baseBlurTex,
		drawbuffers = {
			GL_COLOR_ATTACHMENT0_EXT
		}
			})

		intermediateBlurFBO = gl.CreateFBO({
			color0 = intermediateBlurTex0,
			color1 = intermediateBlurTex1,
			color2 = intermediateBlurTex2,
		drawbuffers = {
			GL_COLOR_ATTACHMENT0_EXT,
			GL_COLOR_ATTACHMENT1_EXT,
			GL_COLOR_ATTACHMENT2_EXT
		}
			})
	end

	if not intermediateBlurTex0 or not intermediateBlurTex1 or not intermediateBlurTex2
		 or not finalBlurTex or not baseBlurTex or not screenTex or not depthTex
		 or (highQuality and (not baseNearBlurTex or not intermediateBlurTex3 or not finalNearBlurTex)) then
			Spring.Echo("Depth of Field: Failed to create textures!")
			widgetHandler:RemoveWidget()
		return
	end
end

function widget:ViewResize(x, y)
	InitTextures()
end

function init()
	reset()

	if (glCreateShader == nil) then
		Spring.Echo("[Depth of Field::Initialize] removing widget, no shader support")
		widgetHandler:RemoveWidget()
		return
	end

	dofShader = dofShader or glCreateShader({
		defines = {
			"#version 150 compatibility\n",
			"#define DEPTH_CLIP01 " .. (Platform.glSupportClipSpaceControl and "1" or "0") .. "\n",

			"#define FILTER_SIZE_PASS " .. shaderPasses.filterSize .. "\n",
			"#define INITIAL_BLUR_PASS " .. shaderPasses.initialBlur .. "\n",
			"#define FINAL_BLUR_PASS " .. shaderPasses.finalBlur .. "\n",
			"#define INITIAL_NEAR_BLUR_PASS " .. shaderPasses.initialNearBlur .. "\n",
			"#define FINAL_NEAR_BLUR_PASS " .. shaderPasses.finalNearBlur .. "\n",
			"#define COMPOSITION_PASS " .. shaderPasses.composition .. "\n",

			"#define BLUR_START_DIST " .. maxBlurDistance .. "\n",

			"#define LOW_QUALITY 0 \n",
			"#define HIGH_QUALITY 1 \n"
		},
		fragment = VFS.LoadFile("LuaUI/Shaders/dof.fs", VFS.RAW_FIRST),

		uniformInt = {origTex = 0, blurTex0 = 1, blurTex1 = 2, blurTex2 = 3, blurTex3 = 4},
	})

	if not dofShader then
		Spring.Echo("Depth of Field: Failed to create shader!")
		Spring.Echo(gl.GetShaderLog())
		widgetHandler:RemoveWidget()
		return
	end

	eyePosLoc = gl.GetUniformLocation(dofShader, "eyePos")
	projectionMatLoc = gl.GetUniformLocation(dofShader, "projectionMat")
	resolutionLoc = gl.GetUniformLocation(dofShader, "resolution")
	distanceLimitsLoc = gl.GetUniformLocation(dofShader, "distanceLimits")
	autofocusLoc = gl.GetUniformLocation(dofShader, "autofocus")
	autofocusFudgeFactorLoc = gl.GetUniformLocation(dofShader, "autofocusFudgeFactor")
	autofocusPowerLoc = gl.GetUniformLocation(dofShader, "autofocusPower")
	autofocusFocalLengthLoc = gl.GetUniformLocation(dofShader, "autofocusFocalLength")
	mousefocusLoc = gl.GetUniformLocation(dofShader, "mousefocus")
	focusDepthLoc = gl.GetUniformLocation(dofShader, "manualFocusDepth")
	mouseDepthCoordLoc = gl.GetUniformLocation(dofShader, "mouseDepthCoord")
	fStopLoc = gl.GetUniformLocation(dofShader, "fStop")
	qualityLoc = gl.GetUniformLocation(dofShader, "quality")
	passLoc = gl.GetUniformLocation(dofShader, "pass")

	widget:ViewResize()
end

function widget:Initialize()
	init()
	WG['dof'] = {}
	WG['dof'].getFocusDepth = function()
		return focusDepth
	end
	WG['dof'].setFocusDepth = function(value)
		focusDepth = value
	end
	WG['dof'].getFstop = function()
		return fStop
	end
	WG['dof'].setFstop = function(value)
		fStop = value
		autofocusInFocusMultiplier = fStop/2
	end
	WG['dof'].getHighQuality = function()
		return highQuality
	end
	WG['dof'].setHighQuality = function(value)
		highQuality = value
		InitTextures()
	end
	WG['dof'].getAutofocus = function()
		return autofocus
	end
	WG['dof'].setAutofocus = function(value)
		autofocus = value
		mousefocus = not autofocus
	end
end

function reset()
	if (glDeleteShader and dofShader) then
		glDeleteShader(dofShader)
	end

	if glDeleteTexture then
		CleanupTextures()
	end
	dofShader = nil
end

function widget:Shutdown()
	reset()
	WG['dof'] = nil
end

local function FilterCalculation()
	local cpx, cpy, cpz = spGetCameraPosition()
	local gmin, gmax = Spring.GetGroundExtremes()
	local effectiveHeight = cpy - math_max(0, gmin)
	cpy = 3.5 * math_sqrt(effectiveHeight) * math_log(effectiveHeight)
	glUniform(eyePosLoc, cpx, cpy, cpz)
	glUniformInt(passLoc, shaderPasses.filterSize)
	glTexture(0, screenTex)
	glTexture(1, depthTex)

	-- glTexRect(-1-0.5/vsx,1+0.5/vsy,1+0.5/vsx,-1-0.5/vsy)
	glTexRect(0, 0, vsx, vsy, false, true)
	--
	glTexture(0, false)
	glTexture(1, false)
end

local function InitialBlur()
	glUniform(resolutionLoc, vsx/2, vsy/2)
	glUniformInt(passLoc, shaderPasses.initialBlur)
	glTexture(0, baseBlurTex)
	glTexRect(0, 0, vsx, vsy, false, true)
	glTexture(0, false)
end

local function FinalBlur()
	glUniform(resolutionLoc, vsx/2, vsy/2)
	glUniformInt(passLoc, shaderPasses.finalBlur)
	glTexture(0, baseBlurTex)
	glTexture(1, intermediateBlurTex0) --R
	glTexture(2, intermediateBlurTex1) --G
	glTexture(3, intermediateBlurTex2) --B
	glTexRect(-1-0.5/vsx,1+0.5/vsy,1+0.5/vsx,-1-0.5/vsy)
	glTexture(0, false)
	glTexture(1, false)
	glTexture(2, false)
	glTexture(3, false)
end

local function InitialNearBlur()
	glUniform(resolutionLoc, vsx/2, vsy/2)
	glUniformInt(passLoc, shaderPasses.initialNearBlur)
	glTexture(0, baseNearBlurTex)
	glTexRect(0, 0, vsx, vsy, false, true)
	glTexture(0, false)
end

local function FinalNearBlur()
	glUniform(resolutionLoc, vsx/2, vsy/2)
	glUniformInt(passLoc, shaderPasses.finalNearBlur)
	glTexture(0, baseNearBlurTex)
	glTexture(1, intermediateBlurTex0) --R
	glTexture(2, intermediateBlurTex1) --G
	glTexture(3, intermediateBlurTex2) --B
	glTexture(4, intermediateBlurTex3) --A
	glTexRect(-1-0.5/vsx,1+0.5/vsy,1+0.5/vsx,-1-0.5/vsy)
	glTexture(0, false)
	glTexture(1, false)
	glTexture(2, false)
	glTexture(3, false)
	glTexture(4, false)
end

local function Composition()
	glUniformInt(passLoc, shaderPasses.composition)
	glTexture(0, screenTex)
	glTexture(1, finalBlurTex)
	if (highQuality) then
		glTexture(2, finalNearBlurTex)
	end

	glTexRect(0, 0, vsx, vsy, false, true)
	glTexture(0, false)
	glTexture(1, false)
	glTexture(2, false)
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
	end
end

function widget:DrawWorld()
	if chobbyInterface then return end
	gl.ActiveShader(dofShader, function() glUniformMatrix(projectionMatLoc, "projection") end)
end

function widget:DrawScreenEffects()
	if chobbyInterface then return end
	gl.Blending(false)
	glCopyToTexture(screenTex, 0, 0, vpx, vpy, vsx, vsy) -- the original screen image
	glCopyToTexture(depthTex, 0, 0, vpx, vpy, vsx, vsy) -- the original screen image

	local mx, my = Spring.GetMouseState()

	glUseShader(dofShader)
		glUniform(distanceLimitsLoc, gl.GetViewRange())

		glUniformInt(autofocusLoc, autofocus and 1 or 0)
		glUniformInt(mousefocusLoc, mousefocus and 1 or 0)
		glUniform(autofocusFudgeFactorLoc, autofocusInFocusMultiplier)
		glUniform(autofocusPowerLoc, autofocusPower)
		glUniform(autofocusFocalLengthLoc, autofocusFocalLength)
		glUniform(mouseDepthCoordLoc, mx/vsx, my/vsy)
		glUniform(focusDepthLoc, focusDepth / maxBlurDistance)
		glUniform(fStopLoc, fStop)
		glUniformInt(qualityLoc, highQuality and 1 or 0)

		gl.ActiveFBO(baseBlurFBO, FilterCalculation)
		gl.ActiveFBO(intermediateBlurFBO, InitialBlur)
		glRenderToTexture(finalBlurTex, FinalBlur)
		if highQuality then
			gl.ActiveFBO(intermediateBlurFBO, InitialNearBlur)
			glRenderToTexture(finalNearBlurTex, FinalNearBlur)
		end
		Composition()

	glUseShader(0)
end

function widget:GetConfigData()
	return {
		highQuality = highQuality,
		autofocus = autofocus,
		focusDepth = focusDepth,
		fStop = fStop,
		autofocusInFocusMultiplier = autofocusInFocusMultiplier,
		autofocusPower = autofocusPower,
		autofocusFocalLength = autofocusFocalLength,
	}
end

function widget:SetConfigData(data)
	if data.highQuality ~= nil then
		highQuality = data.highQuality
		autofocus = data.autofocus
		mousefocus = not autofocus
		focusDepth = data.focusDepth
		fStop = data.fStop
		autofocusInFocusMultiplier = fStop/2

		--if data.autofocusInFocusMultiplier then
		--	autofocusInFocusMultiplier = data.autofocusInFocusMultiplier
		--	autofocusPower = data.autofocusPower
		--	autofocusFocalLength = data.autofocusFocalLength
		--end
	end
end
