function widget:GetInfo()
	return {
		name      = "Bloom Shader",
		desc      = "Sets Spring In Bloom",
		author    = "Floris", -- orginal bloom shader: Kloot
		date      = "24-9-2016",
		license   = "",
		layer     = 9,
		enabled   = false
	}
end

--------------------------------------------------------------------------------
-- config 
--------------------------------------------------------------------------------

local basicAlpha = 0.4

local drawHighlights = false		-- apply extra bloom bright spots (note: quite costly)
local highlightsAlpha = 0.35

local dbgDraw = 0					-- debug: draw only the bloom-mask?

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local drawWorldAlpha = 0
local drawWorldPreUnitAlpha = 0
local usedBasicAlpha = basicAlpha

local camX, camY, camZ = Spring.GetCameraPosition()
local camDirX,camDirY,camDirZ = Spring.GetCameraDirection()

-- shader and texture handles
local blurShaderH71 = nil
local blurShaderV71 = nil

local brightShader = nil
local brightTexture1 = nil
local brightTexture2 = nil
local brightTexture3 = nil
local brightTexture4 = nil

local combineShader = nil
local screenTexture = nil
local screenTextureQuarter = nil
local screenTextureSixteenth = nil

-- speedups
local glCreateTexture = gl.CreateTexture
local glActiveTexture = gl.ActiveTexture
local glCopyToTexture = gl.CopyToTexture
local glRenderToTexture = gl.RenderToTexture
local glTexture = gl.Texture
local glTexRect = gl.TexRect

local glUseShader = gl.UseShader

local glUniformInt = gl.UniformInt
local glUniform = gl.Uniform
local glGetUniformLocation = gl.GetUniformLocation
local glGetActiveUniforms = gl.GetActiveUniforms


local GL_RGBA32F_ARB                = 0x8814
local GL_RGB32F_ARB                 = 0x8815
local GL_ALPHA32F_ARB               = 0x8816
local GL_INTENSITY32F_ARB           = 0x8817
local GL_LUMINANCE32F_ARB           = 0x8818
local GL_LUMINANCE_ALPHA32F_ARB     = 0x8819
local GL_RGBA16F_ARB                = 0x881A
local GL_RGB16F_ARB                 = 0x881B
local GL_ALPHA16F_ARB               = 0x881C
local GL_INTENSITY16F_ARB           = 0x881D
local GL_LUMINANCE16F_ARB           = 0x881E
local GL_LUMINANCE_ALPHA16F_ARB     = 0x881F
local GL_TEXTURE_RED_TYPE_ARB       = 0x8C10
local GL_TEXTURE_GREEN_TYPE_ARB     = 0x8C11
local GL_TEXTURE_BLUE_TYPE_ARB      = 0x8C12
local GL_TEXTURE_ALPHA_TYPE_ARB     = 0x8C13
local GL_TEXTURE_LUMINANCE_TYPE_ARB = 0x8C14
local GL_TEXTURE_INTENSITY_TYPE_ARB = 0x8C15
local GL_TEXTURE_DEPTH_TYPE_ARB     = 0x8C16
local GL_UNSIGNED_NORMALIZED_ARB    = 0x8C17


-- shader uniform locations
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

local combineShaderDebgDrawLoc = nil
local combineShaderTexture0Loc = nil
local combineShaderTexture1Loc = nil
local combineShaderIllumLoc = nil
local combineShaderFragLoc = nil

local illumThreshold = 0.33
local function SetIllumThreshold()
	local ra, ga, ba = gl.GetSun("ambient")
	local rd, gd, bd = gl.GetSun("diffuse")
	local rs, gs, bs = gl.GetSun("specular")

	local ambientIntensity  = ra * 0.299 + ga * 0.587 + ba * 0.114
	local diffuseIntensity  = rd * 0.299 + gd * 0.587 + bd * 0.114
	local specularIntensity = rs * 0.299 + gs * 0.587 + bs * 0.114
	--Spring.Echo(ambientIntensity..'  '..diffuseIntensity..'  '..specularIntensity)
	illumThreshold = (0.33 * ambientIntensity) + (0.05 * diffuseIntensity) + (0.05 * specularIntensity)
end

local function RemoveMe(msg)
	Spring.Echo(msg)
	--widgetHandler:RemoveWidget()
end

function reset()

	--if not initialized then return end
	
	if drawHighlights then
		usedBasicAlpha = basicAlpha
		drawWorldAlpha = 0.2 - (illumThreshold*0.4) + (usedBasicAlpha/11) + (0.018 * highlightsAlpha)
		drawWorldPreUnitAlpha = 0.16 - (illumThreshold*0.4)  + (usedBasicAlpha/6.2)  + (0.023 * highlightsAlpha)
	else
		usedBasicAlpha = basicAlpha
		drawWorldAlpha = 0.035 + (usedBasicAlpha/11)
		drawWorldPreUnitAlpha = 0.2 - (illumThreshold*0.4) + (usedBasicAlpha/6)
	end
	gl.DeleteTexture(brightTexture1 or "")
	gl.DeleteTexture(brightTexture2 or "")
	if drawHighlights then
		gl.DeleteTexture(brightTexture3 or "")
		gl.DeleteTexture(brightTexture4 or "")
	end
	gl.DeleteTexture(screenTexture or "")
	
	local btQuality = 4.6		-- high value creates flickering, but lower is more expensive
	brightTexture1 = glCreateTexture(vsx/btQuality, vsy/btQuality, {
		fbo = true, min_filter = GL.LINEAR, mag_filter = GL.LINEAR,
		format = GL_RGB16F_ARB, wrap_s = GL.CLAMP, wrap_t = GL.CLAMP,
	})
	brightTexture2 = glCreateTexture(vsx/btQuality, vsy/btQuality, {
		fbo = true, min_filter = GL.LINEAR, mag_filter = GL.LINEAR,
		format = GL_RGB16F_ARB, wrap_s = GL.CLAMP, wrap_t = GL.CLAMP,
	})
	if drawHighlights then
		btQuality = 3.2		-- high value creates flickering, but lower is more expensive
		brightTexture3 = glCreateTexture(vsx/btQuality, vsy/btQuality, {
			fbo = true, min_filter = GL.LINEAR, mag_filter = GL.LINEAR,
			format = GL_RGB16F_ARB, wrap_s = GL.CLAMP, wrap_t = GL.CLAMP,
		})
		brightTexture4 = glCreateTexture(vsx/btQuality, vsy/btQuality, {
			fbo = true, min_filter = GL.LINEAR, mag_filter = GL.LINEAR,
			format = GL_RGB16F_ARB, wrap_s = GL.CLAMP, wrap_t = GL.CLAMP,
		})
	end
	screenTexture = glCreateTexture(vsx, vsy, {
		min_filter = GL.LINEAR, mag_filter = GL.LINEAR,
	})
	screenTextureQuarter = glCreateTexture(vsx/2, vsy/2, {
		min_filter = GL.LINEAR, mag_filter = GL.LINEAR,
	})
	screenTextureSixteenth = glCreateTexture(vsx/4, vsy/4, {
		min_filter = GL.LINEAR, mag_filter = GL.LINEAR,
	})
end


function widget:ViewResize(viewSizeX, viewSizeY)
	vsx,vsy = gl.GetViewSizes()
	
	ivsx = 1.0 / vsx
	ivsy = 1.0 / vsy
	kernelRadius = vsy / 80.0
	kernelRadius2 = vsy / 30.0
	
	reset()
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:Update(dt)
	if initialized == false then return end
	camX, camY, camZ = Spring.GetCameraPosition()
	camDirX,camDirY,camDirZ = Spring.GetCameraDirection()
end

function widget:DrawWorldPreUnit()
	if initialized == false or drawWorldPreUnitAlpha <= 0.05 then return end
	gl.PushMatrix()
	gl.Color(0,0,0,drawWorldPreUnitAlpha)
	gl.Translate(camX+(camDirX*360),camY+(camDirY*360),camZ+(camDirZ*360))
	gl.Billboard()
	gl.Rect(-500, -500, 500, 500)
	gl.PopMatrix()
end

function widget:DrawWorld()
	if initialized == false or drawWorldAlpha <= 0.05 then return end
	gl.PushMatrix()
	gl.Color(0,0,0,drawWorldAlpha)
	gl.Translate(camX+(camDirX*360),camY+(camDirY*360),camZ+(camDirZ*360))
	gl.Billboard()
	gl.Rect(-500, -500, 500, 500)
	gl.PopMatrix()
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local initialized = false
function widget:Initialize()

  SetIllumThreshold()

  WG['bloom'] = {}
  WG['bloom'].getAdvBloom = function()
  	return drawHighlights
  end
  WG['bloom'].setAdvBloom = function(value)
  	drawHighlights = value
	reset()
  	if initialized == false then
  		Spring.Echo('Bloom shader doesnt work (enable shaders: \'ForceShaders = 1\' in springsettings.cfg)')
  	end
  end
  WG['bloom'].getBrightness = function()
  	return basicAlpha
  end
  WG['bloom'].setBrightness = function(value)
	basicAlpha = value
	reset()
  	if initialized == false then
  		Spring.Echo('Bloom shader doesnt work (enable shaders: \'ForceShaders = 1\' in springsettings.cfg)')
  	end
  end

  if (gl.CreateShader == nil) then
    RemoveMe("[BloomShader::Initialize] no shader support")
    return
  end

  widget:ViewResize(widgetHandler:GetViewSizes())
    

	combineShader = gl.CreateShader({
		fragment = [[
			uniform sampler2D texture0;
			uniform sampler2D texture1;
			uniform float illuminationThreshold;
			uniform float fragMaxBrightness;
			uniform int debugDraw;

			void main(void) {

				vec2 C0 = vec2(gl_TexCoord[0]);
				vec4 S0 = texture2D(texture0, C0);
				vec4 S1 = texture2D(texture1, C0);
				S1 = vec4(S1.rgb * fragMaxBrightness/max(1.0 - illuminationThreshold, 0.0001), 1.0);

				gl_FragColor = bool(debugDraw) ? S1 : S0 + S1;
			}
		]],

		uniformInt = { texture0 = 0, texture1 = 1, debugDraw = 0},
		uniformFloat = {illuminationThreshold, fragMaxBrightness}
	})

	if (combineShader == nil) then
		RemoveMe("[BloomShader::Initialize] combineShader compilation failed"); print(gl.GetShaderLog()); return
	end


	blurShaderH71 = gl.CreateShader({
		fragment = [[
			uniform sampler2D texture0;
			uniform float inverseRX;
			uniform float fragKernelRadius;
			float bloomSigma = fragKernelRadius / 2.5;

			void main(void) {
				vec2 C0 = vec2(gl_TexCoord[0]);

				vec4 S = texture2D(texture0, C0);
				float weight = 1.0 / (2.50663 * bloomSigma);
				float total_weight = weight;
				S *= weight;
				for (float r = 1.5; r < fragKernelRadius; r += 2)
				{
					weight = exp(-((r*r)/(2.0 * bloomSigma * bloomSigma)))/(2.50663 * bloomSigma);
					S += texture2D(texture0, C0 - vec2(r * inverseRX, 0.0)) * weight;
					S += texture2D(texture0, C0 + vec2(r * inverseRX, 0.0)) * weight;

					total_weight += 2*weight;
				}

				gl_FragColor = vec4(S.rgb/total_weight, 1.0);
			}
		]],

		uniformInt = {texture0 = 0},
		uniformFloat = {inverseRX, fragKernelRadius}
	})

	if (blurShaderH71 == nil) then
		RemoveMe("[BloomShader::Initialize] blurShaderH71 compilation failed"); print(gl.GetShaderLog()); return
	end

	blurShaderV71 = gl.CreateShader({
		fragment = [[
			uniform sampler2D texture0;
			uniform float inverseRY;
			uniform float fragKernelRadius;
			float bloomSigma = fragKernelRadius / 2.5;

			void main(void) {
				vec2 C0 = vec2(gl_TexCoord[0]);

				vec4 S = texture2D(texture0, C0);
				float weight = 1.0 / (2.50663 * bloomSigma);
				float total_weight = weight;
				S *= weight;
				for (float r = 1.5; r < fragKernelRadius; r += 2)
				{
					weight = exp(-((r*r)/(2.0 * bloomSigma * bloomSigma)))/(2.50663 * bloomSigma);
					S += texture2D(texture0, C0 - vec2(0.0, r * inverseRY)) * weight;
					S += texture2D(texture0, C0 + vec2(0.0, r * inverseRY)) * weight;

					total_weight += 2*weight;
				}

				gl_FragColor = vec4(S.rgb/total_weight, 1.0);
			}
		]],

		uniformInt = {texture0 = 0},
		uniformFloat = {inverseRY, fragKernelRadius}
	})

	if (blurShaderV71 == nil) then
		RemoveMe("[BloomShader::Initialize] blurShaderV71 compilation failed"); print(gl.GetShaderLog()); return
	end

	brightShader = gl.CreateShader({
		fragment = [[
			uniform sampler2D texture0;
			uniform float illuminationThreshold;
			uniform float inverseRX;
			uniform float inverseRY;

			void main(void) {
				vec2 C0 = vec2(gl_TexCoord[0]);
				vec3 color = vec3(texture2D(texture0, C0));
				float illum = dot(color, vec3(0.2990, 0.5870, 0.1140));
		
				if (illum > illuminationThreshold) {
					gl_FragColor = vec4((color - color*(illuminationThreshold/max(illum, 0.00001))), 1.0);
				} else {
					gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
				}
			}
		]],

		uniformInt = {texture0 = 0},
		uniformFloat = {illuminationThreshold, inverseRX, inverseRY}
	})

	if (brightShader == nil) then
		RemoveMe("[BloomShader::Initialize] brightShader compilation failed"); print(gl.GetShaderLog()); return
	end

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

	combineShaderDebgDrawLoc = glGetUniformLocation(combineShader, "debugDraw")
	combineShaderTexture0Loc = glGetUniformLocation(combineShader, "texture0")
	combineShaderTexture1Loc = glGetUniformLocation(combineShader, "texture1")
	combineShaderIllumLoc = glGetUniformLocation(combineShader, "illuminationThreshold")
	combineShaderFragLoc = glGetUniformLocation(combineShader, "fragMaxBrightness")
	
	initialized = true
end

function widget:Shutdown()
	if initialized then
		gl.DeleteTexture(brightTexture1 or "")
		gl.DeleteTexture(brightTexture2 or "")
		if drawHighlights then
			gl.DeleteTexture(brightTexture3 or "")
			gl.DeleteTexture(brightTexture4 or "")
		end
		gl.DeleteTexture(screenTexture or "")

		if (gl.DeleteShader) then
			gl.DeleteShader(brightShader or 0)
			gl.DeleteShader(blurShaderH71 or 0)
			gl.DeleteShader(blurShaderV71 or 0)
			gl.DeleteShader(combineShader or 0)
		end
	end
	WG['bloom'] = nil
end



local function mglDrawTexture(texUnit, tex, w, h, flipS, flipT)
	glTexture(texUnit, tex)
	glTexRect(0, 0, w, h, flipS, flipT)
	glTexture(texUnit, false)
end

local function mglDrawFBOTexture(tex)
	glTexture(tex)
	glTexRect(-1, -1, 1, 1)
	glTexture(false)
end


local function activeTextureFunc(texUnit, tex, w, h, flipS, flipT)
	glTexture(texUnit, tex)
	glTexRect(0, 0, w, h, flipS, flipT)
	glTexture(texUnit, false)
end

local function mglActiveTexture(texUnit, tex, w, h, flipS, flipT)
	glActiveTexture(texUnit, activeTextureFunc, texUnit, tex, w, h, flipS, flipT)
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
	
	glCopyToTexture(screenTexture, 0, 0, 0, 0, vsx, vsy)
	
	-- global bloomin
	glUseShader(brightShader)
		glUniformInt(brightShaderText0Loc, 0)
		glUniform(   brightShaderInvRXLoc, ivsx)
		glUniform(   brightShaderInvRYLoc, ivsy)
		glUniform(   brightShaderIllumLoc, illumThreshold)
		mglRenderToTexture(brightTexture1, screenTexture, 1, -1)
	glUseShader(0)
	
	for i = 1, 4 do
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
		glUniformInt(combineShaderDebgDrawLoc, dbgDraw)
		glUniformInt(combineShaderTexture0Loc, 0)
		glUniformInt(combineShaderTexture1Loc, 1)
		glUniform(   combineShaderIllumLoc, illumThreshold)
		glUniform(   combineShaderFragLoc, usedBasicAlpha)
		mglActiveTexture(0, screenTexture, vsx, vsy, false, true)
		mglActiveTexture(1, brightTexture1, vsx, vsy, false, true)
	glUseShader(0)
	
	-- highlights
	if drawHighlights then
		glCopyToTexture(screenTexture, 0, 0, 0, 0, vsx, vsy)
		
		glUseShader(brightShader)
			glUniformInt(brightShaderText0Loc, 0)
			glUniform(   brightShaderInvRXLoc, ivsx)
			glUniform(   brightShaderInvRYLoc, ivsy)
			glUniform(   brightShaderIllumLoc, 0.5)
			mglRenderToTexture(brightTexture3, screenTexture, 1, -1)
		glUseShader(0)
		
		for i = 1, 1 do
			glUseShader(blurShaderH71)
				glUniformInt(blurShaderH71Text0Loc, 0)
				glUniform(   blurShaderH71InvRXLoc, ivsx)
				glUniform(	 blurShaderH71FragLoc, kernelRadius2)
				mglRenderToTexture(brightTexture4, brightTexture3, 1, -1)
			glUseShader(0)
			glUseShader(blurShaderV71)
				glUniformInt(blurShaderV71Text0Loc, 0)
				glUniform(   blurShaderV71InvRYLoc, ivsy)
				glUniform(	 blurShaderV71FragLoc, kernelRadius2)
				mglRenderToTexture(brightTexture3, brightTexture4, 1, -1)
			glUseShader(0)
		end
		glUseShader(combineShader)
			glUniformInt(combineShaderDebgDrawLoc, dbgDraw)
			glUniformInt(combineShaderTexture0Loc, 0)
			glUniformInt(combineShaderTexture1Loc, 1)
			glUniform(   combineShaderIllumLoc, illumThreshold*0.66)
			glUniform(   combineShaderFragLoc, highlightsAlpha)
			mglActiveTexture(0, screenTexture, vsx, vsy, false, true)
			mglActiveTexture(1, brightTexture3, vsx, vsy, false, true)
		glUseShader(0)
	end
end

function widget:DrawScreenEffects()
	if initialized == false then return end
	Bloom()
end

function widget:GetConfigData(data)
    savedTable = {}
    savedTable.basicAlpha = basicAlpha
    savedTable.drawHighlights = drawHighlights
    return savedTable
end

function widget:SetConfigData(data)
	if data.basicAlpha ~= nil then
		basicAlpha = data.basicAlpha
		if data.highlightsAlpha ~= nil then
			highlightsAlpha = data.highlightsAlpha
		end
		drawHighlights = data.drawHighlights
	end
end

function widget:TextCommand(command)
  if (string.find(command, "advbloom") == 1  and  string.len(command) == 8) then 
		WG['bloom'].setAdvBloom(not drawHighlights)
		if drawHighlights then
	 		Spring.Echo('Adv bloom enabled')
	 	else
	 		Spring.Echo('Adv bloom disabled')
	 	end
	end
end