function widget:GetInfo()
	return {
		name      = "Depth of Field",
		version	  = 2.0,
		desc      = "Blurs far away objects.",
		author    = "aeonios, Shadowfury333 (with some code from Kleber Garcia)",
		date      = "Feb. 2019",
		license   = "GPL, MIT",
		layer     = -100000, --To run after gfx_deferred_rendering.lua
		enabled   = true
	}
end

local useDoF = false		--onChangeFunc()
local highQuality = false	--OnChange = function(self) InitTextures() end,
local autofocus = true
local focusDepth = 300
local fStop = 16
local keyToggle = 'f8'

local function onChangeFunc()
	if useDoF then
		init()
		--widgetHandler:UpdateCallIn('DrawScreenEffects')
	else
		if glDeleteTexture then
			CleanupTextures()
		end
		--widgetHandler:RemoveCallIn('DrawScreenEffects')
	end
end

-----------------------------------------------------------------
-- Engine Functions
-----------------------------------------------------------------

local spGetCameraPosition    = Spring.GetCameraPosition

local glCopyToTexture        = gl.CopyToTexture
local glCreateShader         = gl.CreateShader
local glCreateTexture        = gl.CreateTexture
local glDeleteShader         = gl.DeleteShader
local glDeleteTexture        = gl.DeleteTexture
local glTexture              = gl.Texture
local glTexRect              = gl.TexRect
local glRenderToTexture		 = gl.RenderToTexture
local glUseShader            = gl.UseShader
local glUniform				 = gl.Uniform
local glUniformInt			 = gl.UniformInt
local glUniformMatrix		 = gl.UniformMatrix

local GL_DEPTH_COMPONENT   = 0x1902
local GL_DEPTH_COMPONENT16 = 0x81A5
local GL_DEPTH_COMPONENT24 = 0x81A6
local GL_DEPTH_COMPONENT32 = 0x81A7

local GL_COLOR_ATTACHMENT0_EXT = 0x8CE0
local GL_COLOR_ATTACHMENT1_EXT = 0x8CE1
local GL_COLOR_ATTACHMENT2_EXT = 0x8CE2
local GL_COLOR_ATTACHMENT3_EXT = 0x8CE3

-----------------------------------------------------------------


local function CleanupTextures()
	glDeleteTexture(baseBlurTex or "")
	glDeleteTexture(baseNearBlurTex or "")
	glDeleteTexture(intermediateBlurTex0 or "")
	glDeleteTexture(intermediateBlurTex1 or "")
	glDeleteTexture(intermediateBlurTex2 or "")
	glDeleteTexture(intermediateBlurTex3 or "")
	glDeleteTexture(finalBlurTex or "")
	glDeleteTexture(finalNearBlurTex or "")
	glDeleteTexture(screenTex or "")
	glDeleteTexture(depthTex or "")
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
local viewProjectionLoc = nil
local resolutionLoc = nil
local distanceLimitsLoc = nil
local autofocusLoc = nil
local focusDepthLoc = nil
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

-----------------------------------------------------------------

function dofToggle(cmd, line, words)
	useDoF = not useDoF
	if words[1] then
		useDoF = words[1] == "0"
	end
	if not useDoF then
		Spring.Echo("Depth of Field: on")
	else
		Spring.Echo("Depth of Field: off")
	end
	onChangeFunc()
end

function InitTextures()
	vsx, vsy = gl.GetViewSizes()
	local blurTexSizeX, blurTexSizeY = vsx/2, vsy/2;

	CleanupTextures()
	
	screenTex = glCreateTexture(vsx, vsy, {
		fbo = true, min_filter = GL.LINEAR, mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP_TO_EDGE, wrap_t = GL.CLAMP_TO_EDGE,
	})

	depthTex = gl.CreateTexture(vsx,vsy, {
		border = false,
		format = GL_DEPTH_COMPONENT24,
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
		 or (highQuality and (not baseNearBlurTex or not intermediateBlurTex3 or not finalNearBlurTex))
		  then
		Spring.Echo("Depth of Field: Failed to create textures!")
		widgetHandler:RemoveWidget()
		return
	end
end

function widget:ViewResize(x, y)
	InitTextures()
end

function init()
	if (glCreateShader == nil) then
		Spring.Echo("[Depth of Field::Initialize] removing widget, no shader support")
		widgetHandler:RemoveWidget()
		return
	end
	
	if not useDoF then
		return
	end

	dofShader = dofShader or glCreateShader({
		defines = {"#version 150 compatibility\n",
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
		fragment = VFS.LoadFile("LuaUI\\Widgets\\Shaders\\dof.fs", VFS.ZIP),
		
		uniformInt = {origTex = 0, blurTex0 = 1, blurTex1 = 2, blurTex2 = 3, blurTex3 = 4},
	})
	
	if not dofShader then
		Spring.Echo("Depth of Field: Failed to create shader!")
		Spring.Echo(gl.GetShaderLog())
		widgetHandler:RemoveWidget()
		return
	end
	
	eyePosLoc = gl.GetUniformLocation(dofShader, "eyePos")
	viewProjectionLoc = gl.GetUniformLocation(dofShader, "viewProjection")
	resolutionLoc = gl.GetUniformLocation(dofShader, "resolution")
	distanceLimitsLoc = gl.GetUniformLocation(dofShader, "distanceLimits")
	autofocusLoc = gl.GetUniformLocation(dofShader, "autofocus")
	focusDepthLoc = gl.GetUniformLocation(dofShader, "manualFocusDepth")
	fStopLoc = gl.GetUniformLocation(dofShader, "fStop")
	qualityLoc = gl.GetUniformLocation(dofShader, "quality")
	passLoc = gl.GetUniformLocation(dofShader, "pass")
	
	widget:ViewResize()
end

function widget:Initialize()
	widgetHandler:AddAction("dofToggle", dofToggle, nil, "t")
	Spring.SendCommands({"bind "..keyToggle.." dofToggle"})
	--Spring.SendCommands({"dofToggle 0"})     -- toggle off defaultly
	WG['dof'] = {}

	init()
end

function widget:Shutdown()
	if (glDeleteShader and dofShader) then
		glDeleteShader(dofShader)
	end
	
	if glDeleteTexture then
		CleanupTextures()
	end
	dofShader = nil
	WG['dof'] = nil
	Spring.SendCommands({"dofToggle 0"})
	widgetHandler:RemoveAction("dofToggle", dofToggle)
end

local function FilterCalculation()
	local cpx, cpy, cpz = spGetCameraPosition()
	local gmin, gmax = Spring.GetGroundExtremes()
	local effectiveHeight = cpy - math.max(0, gmin)
	cpy = 3.5 * math.sqrt(effectiveHeight) * math.log(effectiveHeight)
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

function widget:DrawWorld()
	if not useDoF then
		return -- if the option is disabled don't set any uniforms.
	end
	gl.ActiveShader(dofShader, function() glUniformMatrix(viewProjectionLoc, "projection") end)
end

function widget:DrawScreenEffects()
	if not useDoF then
		return -- if the option is disabled don't draw anything.
	end

	gl.Blending(false)
	glCopyToTexture(screenTex, 0, 0, 0, 0, vsx, vsy) -- the original screen image
	glCopyToTexture(depthTex, 0, 0, 0, 0, vsx, vsy) -- the original screen image
	
	glUseShader(dofShader)
		glUniform(distanceLimitsLoc, gl.GetViewRange())

		glUniformInt(autofocusLoc, autofocus and 1 or 0)
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
		useDoF  = useDoF,
		highQuality = highQuality,
		autofocus = autofocus,
		focusDepth = focusDepth,
		fStop = fStop,
	}
end

function widget:SetConfigData(data)
	--useDoF = data.useDoF
	--highQuality = data.highQuality
	--autofocus = data.autofocus
	--focusDepth = data.focusDepth
	--fStop = data.fStop
end