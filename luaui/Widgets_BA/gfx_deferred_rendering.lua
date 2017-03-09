--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
	name      = "Deferred rendering",
	version   = 3,
	desc      = "Collects and renders point and beam lights using HDR and applies bloom.",
	author    = "beherith, aeonios",
	date      = "2015 Sept.",
	license   = "GPL V2",
	layer     = -1000000000,
	enabled   = true
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local GL_RGB16F_ARB          = 0x881B
local GL_RGB32F_ARB          = 0x8815
local GL_RGB8				 = 0x8051
local GL_MODELVIEW           = GL.MODELVIEW
local GL_NEAREST             = GL.NEAREST
local GL_ONE                 = GL.ONE
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_PROJECTION          = GL.PROJECTION
local GL_QUADS               = GL.QUADS
local GL_SRC_ALPHA           = GL.SRC_ALPHA
local glActiveTexture      	 = gl.ActiveTexture
local glBeginEnd             = gl.BeginEnd
local glBillboard            = gl.Billboard
local glBlending             = gl.Blending
local glCallList             = gl.CallList
local glClear				 = gl.Clear
local glColor                = gl.Color
local glColorMask            = gl.ColorMask
local glCopyToTexture        = gl.CopyToTexture
local glCreateList           = gl.CreateList
local glCreateShader         = gl.CreateShader
local glCreateTexture        = gl.CreateTexture
local glDeleteShader         = gl.DeleteShader
local glDeleteTexture        = gl.DeleteTexture
local glDepthMask            = gl.DepthMask
local glDepthTest            = gl.DepthTest
local glGetMatrixData        = gl.GetMatrixData
local glGetShaderLog         = gl.GetShaderLog
local glGetUniformLocation   = gl.GetUniformLocation
local glGetViewSizes         = gl.GetViewSizes
local glLoadIdentity         = gl.LoadIdentity
local glLoadMatrix           = gl.LoadMatrix
local glMatrixMode           = gl.MatrixMode
local glMultiTexCoord        = gl.MultiTexCoord
local glOrtho            	 = gl.Ortho
local glPopMatrix            = gl.PopMatrix
local glPushMatrix           = gl.PushMatrix
local glResetMatrices        = gl.ResetMatrices
local glTexCoord             = gl.TexCoord
local glTexture              = gl.Texture
local glTexRect              = gl.TexRect
local glRect                 = gl.Rect
local glRenderToTexture      = gl.RenderToTexture
local glRotate				 = gl.Rotate
local glUniform              = gl.Uniform
local glUniformInt           = gl.UniformInt
local glUniformMatrix        = gl.UniformMatrix
local glUseShader            = gl.UseShader
local glVertex               = gl.Vertex
local glTranslate            = gl.Translate
local spEcho                 = Spring.Echo
local spGetCameraPosition    = Spring.GetCameraPosition
local spGetCameraVectors     = Spring.GetCameraVectors
local spGetDrawFrame         = Spring.GetDrawFrame
local spIsSphereInView       = Spring.IsSphereInView
local spWorldToScreenCoords  = Spring.WorldToScreenCoords
local spTraceScreenRay       = Spring.TraceScreenRay
local spGetSmoothMeshHeight  = Spring.GetSmoothMeshHeight


local glowImg			= ":n:"..LUAUI_DIRNAME.."Images/glow.dds"
local beamGlowImg = LUAUI_DIRNAME.."Images/barglow-center.dds"
local beamGlowEndImg = LUAUI_DIRNAME.."Images/barglow-edge.dds"

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Config

local GLSLRenderer = true

options_path = 'Settings/Graphics/HDR (experimental)'
options_order = {'enableHDR', 'enableBloom', 'illumThreshold', 'maxBrightness'}

options = {
	enableHDR      = {type = 'bool',   name = 'Use High Dynamic Range Color',  value = false,},
	enableBloom    = {type = 'bool',   name = 'Apply Bloom Effect (HDR Only)', value = false,},
	
	-- how bright does a fragment need to be before being considered a glow source? [0, 1]
	illumThreshold = {type = 'number', name = 'Illumination Threshold',       value = 0.85, min = 0,    max = 1, step = 0.05,},
	
	-- maximum brightness of bloom additions [1, n]
	maxBrightness  = {type = 'number', name = 'Maximum Highlight Brightness', value = 0.35, min = 0.05, max = 1, step = 0.05,},
}

local initialized = false

local function OnchangeFunc()
	widget:Initialize()
end
for key,option in pairs(options) do
	option.OnChange = OnchangeFunc
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local vsx, vsy
local ivsx = 1.0 
local ivsy = 1.0 
local screenratio = 1.0
local kernelRadius = 32

-- dynamic light shaders
local depthPointShader = nil
local depthBeamShader = nil

-- bloom shaders
local brightShader = nil
local blurShaderH71 = nil
local blurShaderV71 = nil
local combineShader = nil

-- HDR textures
local screenHDR = nil
local brightTexture1 = nil
local brightTexture2 = nil

-- shader uniforms
local lightposlocPoint = nil
local lightcolorlocPoint = nil
local lightparamslocPoint = nil
local uniformEyePosPoint
local uniformViewPrjInvPoint

local lightposlocBeam  = nil
local lightpos2locBeam  = nil
local lightcolorlocBeam  = nil
local lightparamslocBeam  = nil
local uniformEyePosBeam 
local uniformViewPrjInvBeam 

-- bloom shader uniform locations
local brightShaderText0Loc = nil
local brightShaderInvRXLoc = nil
local brightShaderInvRYLoc = nil
local brightShaderIllumLoc = nil

local blurShaderH51Text0Loc = nil
local blurShaderH51InvRXLoc = nil
local blurShaderH51FragLoc = nil
local blurShaderV51Text0Loc = nil
local blurShaderV51InvRYLoc = nil
local blurShaderV51FragLoc = nil

local blurShaderH71Text0Loc = nil
local blurShaderH71InvRXLoc = nil
local blurShaderH71FragLoc = nil
local blurShaderV71Text0Loc = nil
local blurShaderV71InvRYLoc = nil
local blurShaderV71FragLoc = nil

local combineShaderUseBloomLoc = nil
local combineShaderTexture0Loc = nil
local combineShaderTexture1Loc = nil
local combineShaderFragLoc = nil

--------------------------------------------------------------------------------
--Light falloff functions: http://gamedev.stackexchange.com/questions/56897/glsl-light-attenuation-color-and-intensity-formula
--------------------------------------------------------------------------------

local verbose = false
local function VerboseEcho(...)
	if verbose then
		Spring.Echo(...) 
	end
end

local collectionFunctions = {}
local collectionFunctionCount = 0

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:ViewResize()
	vsx, vsy = gl.GetViewSizes()
	ivsx = 1.0 / vsx --we can do /n here!
	ivsy = 1.0 / vsy
	if (Spring.GetMiniMapDualScreen() == 'left') then
		vsx = vsx / 2
	end
	if (Spring.GetMiniMapDualScreen() == 'right') then
		vsx = vsx / 2
	end
	screenratio = vsy / vsx --so we dont overdraw and only always draw a square
	
	glDeleteTexture(brightTexture1 or "")
	glDeleteTexture(brightTexture2 or "")
	glDeleteTexture(screenHDR or "")
	screenHDR, brightTexture1, brightTexture2 = nil, nil, nil
	
	if options.enableHDR.value then
		screenHDR = glCreateTexture(vsx, vsy, {
			fbo = true, min_filter = GL.LINEAR, mag_filter = GL.LINEAR,
			format = GL_RGB32F_ARB, wrap_s = GL.CLAMP, wrap_t = GL.CLAMP,
		})
		
		if options.enableBloom.value then
			local width, height = vsx/2, vsy/2
			
			brightTexture1 = glCreateTexture(width, height, {
				fbo = true, min_filter = GL.LINEAR, mag_filter = GL.LINEAR,
				format = GL_RGB8, wrap_s = GL.CLAMP, wrap_t = GL.CLAMP,
			})
			brightTexture2 = glCreateTexture(width, height, {
				fbo = true, min_filter = GL.LINEAR, mag_filter = GL.LINEAR,
				format = GL_RGB8, wrap_s = GL.CLAMP, wrap_t = GL.CLAMP,
			})
			
			if not brightTexture1 or not brightTexture2 then
				Spring.Echo('Deferred Rendering: Failed to create bloom buffers!') 
				options.enableBloom.value = false
			end
		end
		
		if not screenHDR then
			Spring.Echo('Deferred Rendering: Failed to create HDR buffer!') 
			options.enableHDR.value = false
		end
	end
end

widget:ViewResize()

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local vertSrc = [[
  void main(void)
  {
	gl_TexCoord[0] = gl_MultiTexCoord0;
	gl_Position    = gl_Vertex;
  }
]]
local fragSrc

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function DeferredLighting_RegisterFunction(func)
	collectionFunctionCount = collectionFunctionCount + 1
	collectionFunctions[collectionFunctionCount] = func
end

function widget:Initialize()
	if not initialized then
		initialized = true
		OnchangeFunc()
		return
	end
	
	if (glCreateShader == nil) then
		Spring.Echo('Deferred Rendering requires shader support!') 
		widgetHandler:RemoveWidget()
		return
	end
	
	Spring.SetConfigInt("AllowDeferredMapRendering", 1)
	Spring.SetConfigInt("AllowDeferredModelRendering", 1)

	if (Spring.GetConfigString("AllowDeferredMapRendering") == '0' or Spring.GetConfigString("AllowDeferredModelRendering") == '0') then
		Spring.Echo('Deferred Rendering (gfx_deferred_rendering.lua) requires  AllowDeferredMapRendering and AllowDeferredModelRendering to be enabled in springsettings.cfg!') 
		widgetHandler:RemoveWidget()
		return
	end
	if ((not forceNonGLSL) and Spring.GetMiniMapDualScreen() ~= 'left') then --FIXME dualscreen
		if (not glCreateShader) then
			spEcho("gfx_deferred_rendering.lua: Shaders not found, removing self.")
			GLSLRenderer = false
			widgetHandler:RemoveWidget()
		else
			fragSrc = VFS.LoadFile("LuaUI\\Widgets_BA\\Shaders\\deferred_lighting.fs", VFS.ZIP)
			--Spring.Echo('gfx_deferred_rendering.lua: Shader code:', fragSrc)
			depthPointShader = depthPointShader or glCreateShader({
				vertex = vertSrc,
				fragment = fragSrc,
				uniformInt = {
					modelnormals = 0,
					modeldepths = 1,
					mapnormals = 2,
					mapdepths = 3,
					modelExtra = 4,
				},
			})

			if (not depthPointShader) then
				spEcho(glGetShaderLog())
				spEcho("gfx_deferred_rendering.lua: Bad depth point shader, removing self.")
				GLSLRenderer = false
				widgetHandler:RemoveWidget()
			else
				lightposlocPoint       = glGetUniformLocation(depthPointShader, "lightpos")
				lightcolorlocPoint     = glGetUniformLocation(depthPointShader, "lightcolor")
				uniformEyePosPoint     = glGetUniformLocation(depthPointShader, 'eyePos')
				uniformViewPrjInvPoint = glGetUniformLocation(depthPointShader, 'viewProjectionInv')
			end
			fragSrc = "#define BEAM_LIGHT \n" .. fragSrc
			depthBeamShader = depthBeamShader or glCreateShader({
				vertex = vertSrc,
				fragment = fragSrc,
				uniformInt = {
					modelnormals = 0,
					modeldepths = 1,
					mapnormals = 2,
					mapdepths = 3,
					modelExtra = 4,
				},
			})

			if (not depthBeamShader) then
				spEcho(glGetShaderLog())
				spEcho("gfx_deferred_rendering.lua: Bad depth beam shader, removing self.")
				GLSLRenderer = false
				widgetHandler:RemoveWidget()
			else
				lightposlocBeam       = glGetUniformLocation(depthBeamShader, 'lightpos')
				lightpos2locBeam      = glGetUniformLocation(depthBeamShader, 'lightpos2')
				lightcolorlocBeam     = glGetUniformLocation(depthBeamShader, 'lightcolor')
				uniformEyePosBeam     = glGetUniformLocation(depthBeamShader, 'eyePos')
				uniformViewPrjInvBeam = glGetUniformLocation(depthBeamShader, 'viewProjectionInv')
			end
			
			if options.enableHDR.value and options.enableBloom.value then
				brightShader = brightShader or glCreateShader({
					fragment = VFS.LoadFile("LuaUI\\Widgets_BA\\Shaders\\bloom_bright.fs", VFS.ZIP),

					uniformInt = {texture0 = 0},
					uniformFloat = {illuminationThreshold, inverseRX, inverseRY}
				})
			
				if not brightShader then
					Spring.Echo('Deferred Rendering Widget: brightShader failed to compile!')
					Spring.Echo(gl.GetShaderLog())
				end
		
				blurShaderH71 = blurShaderH71 or glCreateShader({
					fragment = VFS.LoadFile("LuaUI\\Widgets_BA\\Shaders\\bloom_blurH.fs", VFS.ZIP),

					uniformInt = {texture0 = 0},
					uniformFloat = {inverseRX}
				})
			
				if not blurShaderH71 then
					Spring.Echo('Deferred Rendering Widget: blurshaderH71 failed to compile!')
					Spring.Echo(gl.GetShaderLog())
				end
		
				blurShaderV71 = blurShaderV71 or glCreateShader({
					fragment = VFS.LoadFile("LuaUI\\Widgets_BA\\Shaders\\bloom_blurV.fs", VFS.ZIP),

					uniformInt = {texture0 = 0},
					uniformFloat = {inverseRY}
				})
			
				if not blurShaderV71 then
					Spring.Echo('Deferred Rendering Widget: blueShaderV71 failed to compile!')
					Spring.Echo(gl.GetShaderLog())
				end
		
				if not brightShader or not blurShaderH71 or not blurShaderV71 then
					Spring.Echo('Deferred Rendering Widget: Failed to create bloom shaders!')
					options.enableBloom.value = false
				else
					brightShaderText0Loc = glGetUniformLocation(brightShader, "texture0")
					brightShaderInvRXLoc = glGetUniformLocation(brightShader, "inverseRX")
					brightShaderInvRYLoc = glGetUniformLocation(brightShader, "inverseRY")
					brightShaderIllumLoc = glGetUniformLocation(brightShader, "illuminationThreshold")

					blurShaderH71Text0Loc = glGetUniformLocation(blurShaderH71, "texture0")
					blurShaderH71InvRXLoc = glGetUniformLocation(blurShaderH71, "inverseRX")
					blurShaderH71FragLoc = glGetUniformLocation(blurShaderH71, "fragKernelRadius")
					blurShaderV71Text0Loc = glGetUniformLocation(blurShaderV71, "texture0")
					blurShaderV71InvRYLoc = glGetUniformLocation(blurShaderV71, "inverseRY")
					blurShaderV71FragLoc = glGetUniformLocation(blurShaderV71, "fragKernelRadius")
				end
			end
			
			if options.enableHDR.value then
				combineShader = combineShader or glCreateShader({
					fragment = VFS.LoadFile("LuaUI\\Widgets_BA\\Shaders\\bloom_combine.fs", VFS.ZIP),

					uniformInt = { texture0 = 0, texture1 = 1, useBloom = 1, useHDR = 1},
					uniformFloat = {fragMaxBrightness}
				})
			
				if not combineShader then
					Spring.Echo('Deferred Rendering Widget: combineShader failed to compile!')
					options.enableHDR.value = false
					Spring.Echo(gl.GetShaderLog())
				else
					combineShaderUseBloomLoc = glGetUniformLocation(combineShader, "useBloom")
					combineShaderTexture0Loc = glGetUniformLocation(combineShader, "texture0")
					combineShaderTexture1Loc = glGetUniformLocation(combineShader, "texture1")
					combineShaderFragLoc = glGetUniformLocation(combineShader, "fragMaxBrightness")
				end
			end
			
			WG.DeferredLighting_RegisterFunction = DeferredLighting_RegisterFunction
		end
		screenratio = vsy / vsx --so we dont overdraw and only always draw a square
	else
		GLSLRenderer = false
	end
	
	widget:ViewResize()
end

function widget:Shutdown()
	if (GLSLRenderer) then
		if (glDeleteShader) then
			glDeleteShader(depthPointShader)
			glDeleteShader(depthBeamShader)
			glDeleteShader(brightShader)
			glDeleteShader(blurShaderH71)
			glDeleteShader(blurShaderV71)
			glDeleteShader(combineShader)
		end
		glDeleteTexture(brightTexture1 or "")
		glDeleteTexture(brightTexture2 or "")
		glDeleteTexture(screenHDR or "")
		screenHDR, brightTexture1, brightTexture2 = nil, nil, nil
	end
end

local function DrawLightType(lights, lightsCount, lighttype) -- point = 0 beam = 1
	--Spring.Echo('Camera FOV = ', Spring.GetCameraFOV()) -- default TA cam fov = 45
	--set uniforms:
	local cpx, cpy, cpz = spGetCameraPosition()
	if lighttype == 0 then --point
		glUseShader(depthPointShader)
		glUniform(uniformEyePosPoint, cpx, cpy, cpz)
		glUniformMatrix(uniformViewPrjInvPoint,  "viewprojectioninverse")
	else --beam
		glUseShader(depthBeamShader)
		glUniform(uniformEyePosBeam, cpx, cpy, cpz)
		glUniformMatrix(uniformViewPrjInvBeam,  "viewprojectioninverse")
	end

	glTexture(0, "$model_gbuffer_normtex")
	glTexture(1, "$model_gbuffer_zvaltex")
	glTexture(2, "$map_gbuffer_normtex")
	glTexture(3, "$map_gbuffer_zvaltex")
	glTexture(4, "$model_gbuffer_spectex")
	
	local cx, cy, cz = spGetCameraPosition()
	for i = 1, lightsCount do
		local light = lights[i]
		local param = light.param
		if verbose then
			VerboseEcho('gfx_deferred_rendering.lua: Light being drawn:', i)
			Spring.Utilities.TableEcho(light)
		end
		if lighttype == 0 then -- point
			local lightradius = param.radius
			--Spring.Echo("Drawlighttype position = ", light.px, light.py, light.pz)
			local sx, sy, sz = spWorldToScreenCoords(light.px, light.py, light.pz) -- returns x, y, z, where x and y are screen pixels, and z is z buffer depth.
			sx = sx/vsx
			sy = sy/vsy --since FOV is static in the Y direction, the Y ratio is the correct one
			local dist_sq = (light.px-cx)^2 + (light.py-cy)^2 + (light.pz-cz)^2
			local ratio = lightradius / math.sqrt(dist_sq) * 1.5
			glUniform(lightposlocPoint, light.px, light.py, light.pz, param.radius) --in world space
			glUniform(lightcolorlocPoint, param.r * light.colMult, param.g * light.colMult, param.b * light.colMult, 1) 
			glTexRect(
				math.max(-1 , (sx-0.5)*2-ratio*screenratio), 
				math.max(-1 , (sy-0.5)*2-ratio), 
				math.min( 1 , (sx-0.5)*2+ratio*screenratio), 
				math.min( 1 , (sy-0.5)*2+ratio), 
				math.max( 0 , sx - 0.5*ratio*screenratio), 
				math.max( 0 , sy - 0.5*ratio), 
				math.min( 1 , sx + 0.5*ratio*screenratio),
				math.min( 1 , sy + 0.5*ratio)
			) -- screen size goes from -1, -1 to 1, 1; uvs go from 0, 0 to 1, 1
		end 
		if lighttype == 1 then -- beam
			local lightradius = 0
			local px = light.px+light.dx*0.5
			local py = light.py+light.dy*0.5
			local pz = light.pz+light.dz*0.5
			local lightradius = param.radius + math.sqrt(light.dx^2 + light.dy^2 + light.dz^2)*0.5
			VerboseEcho("Drawlighttype position = ", light.px, light.py, light.pz)
			local sx, sy, sz = spWorldToScreenCoords(px, py, pz) -- returns x, y, z, where x and y are screen pixels, and z is z buffer depth.
			sx = sx/vsx
			sy = sy/vsy --since FOV is static in the Y direction, the Y ratio is the correct one
			local dist_sq = (px-cx)^2 + (py-cy)^2 + (pz-cz)^2
			local ratio = lightradius / math.sqrt(dist_sq)
			ratio = ratio*2

			glUniform(lightposlocBeam, light.px, light.py, light.pz, param.radius) --in world space
			glUniform(lightpos2locBeam, light.px+light.dx, light.py+light.dy+24, light.pz+light.dz, param.radius) --in world space, the magic constant of +24 in the Y pos is needed because of our beam distance calculator function in GLSL
			glUniform(lightcolorlocBeam, param.r * light.colMult, param.g * light.colMult, param.b * light.colMult, 1) 
			--TODO: use gl.Shape instead, to avoid overdraw
			glTexRect(
				math.max(-1 , (sx-0.5)*2-ratio*screenratio), 
				math.max(-1 , (sy-0.5)*2-ratio), 
				math.min( 1 , (sx-0.5)*2+ratio*screenratio), 
				math.min( 1 , (sy-0.5)*2+ratio), 
				math.max( 0 , sx - 0.5*ratio*screenratio), 
				math.max( 0 , sy - 0.5*ratio), 
				math.min( 1 , sx + 0.5*ratio*screenratio),
				math.min( 1 , sy + 0.5*ratio)
			) -- screen size goes from -1, -1 to 1, 1; uvs go from 0, 0 to 1, 1
		end
	end
	glUseShader(0)
end

local function renderToTextureFunc(tex, s, t)
	glTexture(tex)
	glTexRect(-1 * s, -1 * t,  1 * s, 1 * t)
	glTexture(false)
end

local function mglRenderToTexture(FBOTex, tex, s, t)
	glRenderToTexture(FBOTex, renderToTextureFunc, tex, s, t)
end

local function Bloom()
	gl.Color(1, 1, 1, 1)
	
	if options.enableHDR.value and options.enableBloom.value then
		glUseShader(brightShader)
			glUniformInt(brightShaderText0Loc, 0)
			glUniform(   brightShaderInvRXLoc, ivsx)
			glUniform(   brightShaderInvRYLoc, ivsy)
			glUniform(   brightShaderIllumLoc, options.illumThreshold.value)
			mglRenderToTexture(brightTexture1, screenHDR, 1, -1)
		glUseShader(0)

		glUseShader(blurShaderH71)
			glUniformInt(blurShaderH71Text0Loc, 0)
			glUniform(   blurShaderH71InvRXLoc, ivsx)
			glUniform(	 blurShaderH71FragLoc, kernelRadius)
			mglRenderToTexture(brightTexture2, brightTexture1, 1, -1)
		glUseShader(0)
		
		glUseShader(blurShaderV71)
			glUniformInt(blurShaderV71Text0Loc, 0)
			glUniform(   blurShaderV71InvRYLoc, ivsy)
			glUniform(	 blurShaderV71FragLoc, kernelRadius)
			mglRenderToTexture(brightTexture1, brightTexture2, 1, -1)
		glUseShader(0)
	end

	glUseShader(combineShader)
		glUniformInt(combineShaderUseBloomLoc, options.enableBloom.value and 1 or 0)
		glUniformInt(combineShaderTexture0Loc, 0)
		glUniformInt(combineShaderTexture1Loc, 1)
		glUniform(   combineShaderFragLoc, options.maxBrightness.value)
		glTexture(0, screenHDR)
		if options.enableBloom.value then
			glTexture(1, brightTexture1)
		end
		glTexRect(0, 0, vsx, vsy, false, true)
		glTexture(0, false)
		glTexture(1, false)
	glUseShader(0)
end

	
local beamLights = {}
local beamLightCount = 0
local pointLights = {}
local pointLightCount = 0
function widget:Update()
	beamLights = {}
	beamLightCount = 0
	pointLights = {}
	pointLightCount = 0
	for i = 1, collectionFunctionCount do
		beamLights, beamLightCount, pointLights, pointLightCount = collectionFunctions[i](beamLights, beamLightCount, pointLights, pointLightCount)
	end
end

-- adding a glow to the projectile
function widget:DrawWorld()

	local lights = pointLights
	gl.Texture(glowImg)
	for i = 1, pointLightCount do
		local light = lights[i]
		local param = light.param
		size = param.radius*0.5
		gl.PushMatrix()
			local colorMultiplier = 1 / math.max(param.r, param.g, param.b)
			gl.Color(param.r*colorMultiplier, param.g*colorMultiplier, param.b*colorMultiplier, 0.22/colorMultiplier)
			gl.Translate(light.px, light.py, light.pz)
			gl.Billboard(true)
			gl.TexRect(-(size/2), -(size/2), (size/2), (size/2))
		gl.PopMatrix()
	end
	
	---- dont know how to do this yet...
	--lights = beamLights
	--gl.Texture(beamGlowImg)
	--for i = 1, beamLightCount do
	--	local light = lights[i]
	--	local param = light.param
	--	size = param.radius/2
	--	--local dist_sq = (light.px-(light.px+light.dx))^2 + (light.py-(light.py+light.dy))^2 + (light.pz-(light.pz+light.dz))^2
	--	gl.PushMatrix()
	--		gl.Color(param.r*4, param.g*4, param.b*4, 0.5)		-- '*4' still needs to be changed to proper values
	--		gl.Translate(light.px, light.py, light.pz)
	--		--gl.Billboard(true)
	--		gl.BeginEnd(GL.QUADS, function()
	--			gl.Vertex(0,-(size/2),0)
	--			gl.Vertex(0,(size/2),0)
	--			gl.Vertex(light.px, light.py-(size/2), light.pz)
	--			gl.Vertex(light.px, light.py+(size/2), light.pz)
	--		end)
	--	gl.PopMatrix()
	--end
	
	gl.Billboard(false)
	gl.Texture(false)
end


function widget:DrawScreenEffects()
	if not (GLSLRenderer) then
		Spring.Echo('Removing deferred rendering widget: failed to use GLSL shader')
		widgetHandler:RemoveWidget()
		return
	end
	
	if options.enableHDR.value then
		glCopyToTexture(screenHDR, 0, 0, 0, 0, vsx, vsy) -- copy the screen to an HDR texture
	end
	
	glBlending(GL.DST_COLOR, GL.ONE) -- Set add blending mode
	
	if beamLightCount > 0 then
		if options.enableHDR.value then
			glRenderToTexture(screenHDR, DrawLightType, beamLights, beamLightCount, 1)
		else
			DrawLightType(beamLights, beamLightCount, 1)
		end
	end
	if pointLightCount > 0 then
		if options.enableHDR.value then
			glRenderToTexture(screenHDR, DrawLightType, pointLights, pointLightCount, 0)
		else
			DrawLightType(pointLights, pointLightCount, 0)
		end
	end
	
	glBlending(false)
	
	if options.enableHDR.value then
		Bloom()
	end
end