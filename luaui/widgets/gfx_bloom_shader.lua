-- $Id: BloomShader.lua 3171 2008-11-06 09:06:29Z det $
function widget:GetInfo()
	return {
		name      = "Bloom Shader",
		desc      = "Sets Spring In Bloom (do not use with < 7xxx geforce series or non-latest ATI cards!)",
		author    = "Kloot", --Updated by Shadowfury333
		date      = "28-5-2008",
		license   = "",
		layer     = 9,
		enabled   = false
	}
end


-- CarRepairer: v0.31 has configurable settings in the menu.

options_path = 'Settings/Graphics/Effects/Bloom'
options = {
	shortcuts = {
		brightnessIncrease = 'Ctrl+Shift+]',
		brightnessDecrease = 'Ctrl+Shift+[',
	},
	dbgDraw 		= { type='bool', 		name='Draw Only Bloom Mask', 	value=false,		},
	
	maxBrightness 	= { type='number', 		name='Maximum Highlight Brightness', 	value=0.06,		min=0.005, 	max=3,	step=0.006, 	},
	illumThreshold 	= { type='number', 		name='Illumination Threshold', 			value=0.18, 	min=0, 		max=1,	step=0.01, 	},
	blurPasses 		= { type='number', 		name='Blur Passes', 					value=1, 		min=0, 		max=10,	step=1,  		},
}


-- config params
local dbgDraw = 0					-- draw only the bloom-mask? [0 | 1]
local maxBrightness = 0.15			-- maximum brightness of bloom additions [1, n]
local illumThreshold = 0.44			-- how bright does a fragment need to be before being considered a glow source? [0, 1]
local blurPasses = 1				-- how many iterations of Gaussian blur should be applied to the glow sources?

local function OnchangeFunc()
	dbgDraw 		= options.dbgDraw.value and 1 or 0
	
	maxBrightness 	= options.maxBrightness.value
	illumThreshold 	= options.illumThreshold.value
	blurPasses 		= options.blurPasses.value
end
for key,option in pairs(options) do
	option.OnChange = OnchangeFunc
end
OnchangeFunc()

-- non-editables
local vsx = 1						-- current viewport width
local vsy = 1						-- current viewport height
local ivsx = 1.0 / vsx
local ivsy = 1.0 / vsy
local kernelRadius = vsx / 36.0 --30 at 1080 px high

-- shader and texture handles
local blurShaderH71 = nil
local blurShaderV71 = nil

local brightShader = nil
local brightTexture1 = nil
local brightTexture2 = nil

local combineShader = nil
local screenTexture = nil
local screenTextureQuarter = nil
local screenTextureSixteenth = nil

-- speedups
local glGetSun = gl.GetSun

local glCreateTexture = gl.CreateTexture
local glDeleteTexture = gl.DeleteTexture
local glActiveTexture = gl.ActiveTexture
local glCopyToTexture = gl.CopyToTexture
local glRenderToTexture = gl.RenderToTexture
local glTexture = gl.Texture
local glTexRect = gl.TexRect
local glGenerateMipmaps = gl.GenerateMipmap

local glGetShaderLog = gl.GetShaderLog
local glCreateShader = gl.CreateShader
local glDeleteShader = gl.DeleteShader
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


function bloomBrightnessIncrease()
  options.maxBrightness.value = options.maxBrightness.value + options.maxBrightness.step
  if (options.maxBrightness.value > options.maxBrightness.max) then
  	 options.maxBrightness.value = options.maxBrightness.max
  end
  OnchangeFunc()
  --Spring.Echo("Bloom: brightness: "..options.maxBrightness.value)
  return true
end

function bloomBrightnessDecrease()
  options.maxBrightness.value = options.maxBrightness.value - options.maxBrightness.step
  if (options.maxBrightness.value < options.maxBrightness.min) then
  	 options.maxBrightness.value = options.maxBrightness.min
  end
  OnchangeFunc()
  --Spring.Echo("Bloom: brightness: "..options.maxBrightness.value)
  return true
end

local function SetIllumThreshold()
	local ra, ga, ba = glGetSun("ambient")
	local rd, gd, bd = glGetSun("diffuse")
	local rs, gs, bs = glGetSun("specular")

	local ambientIntensity  = ra * 0.299 + ga * 0.587 + ba * 0.114
	local diffuseIntensity  = rd * 0.299 + gd * 0.587 + bd * 0.114
	local specularIntensity = rs * 0.299 + gs * 0.587 + bs * 0.114

	-- illumThreshold = (0.8 * ambientIntensity) + (0.1 * diffuseIntensity) + (0.1 * specularIntensity)

	print("[BloomShader::SetIllumThreshold] sun ambient color:  ", ra .. ", " .. ga .. ", " .. ba .. " (intensity: " .. ambientIntensity .. ")")
	print("[BloomShader::SetIllumThreshold] sun diffuse color:  ", rd .. ", " .. gd .. ", " .. bd .. " (intensity: " .. diffuseIntensity .. ")")
	print("[BloomShader::SetIllumThreshold] sun specular color: ", rs .. ", " .. gs .. ", " .. bs .. " (intensity: " .. specularIntensity .. ")")
	print("[BloomShader::SetIllumThreshold] illumination threshold: " .. illumThreshold)
end

local function RemoveMe(msg)
	Spring.Echo(msg)
	widgetHandler:RemoveWidget()
end


function widget:ViewResize(viewSizeX, viewSizeY)
	vsx,vsy = gl.GetViewSizes()
	
		ivsx = 1.0 / vsx
		ivsy = 1.0 / vsy
		kernelRadius = vsy / 36.0

		glDeleteTexture(brightTexture1 or "")
		glDeleteTexture(brightTexture2 or "")
		glDeleteTexture(screenTexture or "")


		brightTexture1 = glCreateTexture(vsx/4, vsy/4, {
			fbo = true, min_filter = GL.LINEAR, mag_filter = GL.LINEAR,
			format = GL_RGB16F_ARB, wrap_s = GL.CLAMP, wrap_t = GL.CLAMP,
		})
		brightTexture2 = glCreateTexture(vsx/4, vsy/4, {
			fbo = true, min_filter = GL.LINEAR, mag_filter = GL.LINEAR,
			format = GL_RGB16F_ARB, wrap_s = GL.CLAMP, wrap_t = GL.CLAMP,
		})

		screenTexture = glCreateTexture(vsx, vsy, {
			min_filter = GL.LINEAR, mag_filter = GL.LINEAR,
		})
		screenTextureQuarter = glCreateTexture(vsx/2, vsy/2, {
			min_filter = GL.LINEAR, mag_filter = GL.LINEAR,
		})
		screenTextureSixteenth = glCreateTexture(vsx/4, vsy/4, {
			min_filter = GL.LINEAR, mag_filter = GL.LINEAR,
		})

		if (brightTexture1 == nil or brightTexture2 == nil or screenTexture == nil or screenTextureQuarter == nil or screenTextureSixteenth == nil) then
			RemoveMe("[BloomShader::ViewResize] removing widget, bad texture target")
			return
		end
end

widget:ViewResize(widgetHandler:GetViewSizes())




function widget:Initialize()
	if (glCreateShader == nil) then
		RemoveMe("[BloomShader::Initialize] removing widget, no shader support")
		return
	end
  
	SetIllumThreshold()



	combineShader = glCreateShader({
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
		RemoveMe("[BloomShader::Initialize] combineShader compilation failed"); print(glGetShaderLog()); return
	end



	blurShaderH71 = glCreateShader({
		fragment = [[
			uniform sampler2D texture0;
			uniform float inverseRX;
			uniform float fragKernelRadius;
			float bloomSigma = fragKernelRadius / 2.0;

			void main(void) {
				vec2 C0 = vec2(gl_TexCoord[0]);

				vec4 S = texture2D(texture0, C0);
				float weight = 1.0 / (2.50663 * bloomSigma);
				float total_weight = weight;
				S *= weight;
				for (float r = 1.5; r < fragKernelRadius; r += 2.0)
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
		RemoveMe("[BloomShader::Initialize] blurShaderH71 compilation failed"); print(glGetShaderLog()); return
	end

	blurShaderV71 = glCreateShader({
		fragment = [[
			uniform sampler2D texture0;
			uniform float inverseRY;
			uniform float fragKernelRadius;
			float bloomSigma = fragKernelRadius / 2.0;

			void main(void) {
				vec2 C0 = vec2(gl_TexCoord[0]);

				vec4 S = texture2D(texture0, C0);
				float weight = 1.0 / (2.50663 * bloomSigma);
				float total_weight = weight;
				S *= weight;
				for (float r = 1.5; r < fragKernelRadius; r += 2.0)
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
		RemoveMe("[BloomShader::Initialize] blurShaderV71 compilation failed"); print(glGetShaderLog()); return
	end

	brightShader = glCreateShader({
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
		RemoveMe("[BloomShader::Initialize] brightShader compilation failed"); print(glGetShaderLog()); return
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
	

	widgetHandler:AddAction("bloom1BrightnessIncrease", bloomBrightnessIncrease, nil, "t")
	Spring.SendCommands({"bind "..options.shortcuts.brightnessIncrease.." bloom1BrightnessIncrease"})

	widgetHandler:AddAction("bloom1BrightnessDecrease", bloomBrightnessDecrease, nil, "t")
	Spring.SendCommands({"bind "..options.shortcuts.brightnessDecrease.." bloom1BrightnessDecrease"})
end

function widget:Shutdown()
	glDeleteTexture(brightTexture1 or "")
	glDeleteTexture(brightTexture2 or "")
	glDeleteTexture(screenTexture or "")

	if (glDeleteShader) then
		glDeleteShader(brightShader or 0)
		glDeleteShader(blurShaderH71 or 0)
		glDeleteShader(blurShaderV71 or 0)
		glDeleteShader(combineShader or 0)
	end
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


	
	glUseShader(brightShader)
		glUniformInt(brightShaderText0Loc, 0)
		glUniform(   brightShaderInvRXLoc, ivsx)
		glUniform(   brightShaderInvRYLoc, ivsy)
		glUniform(   brightShaderIllumLoc, illumThreshold)
		mglRenderToTexture(brightTexture1, screenTexture, 1, -1)
	glUseShader(0)

	for i = 1, blurPasses do
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
		glUniform(   combineShaderFragLoc, maxBrightness)
		mglActiveTexture(0, screenTexture, vsx, vsy, false, true)
		mglActiveTexture(1, brightTexture1, vsx, vsy, false, true)
	glUseShader(0)
end

function widget:DrawScreenEffects() 
	Bloom()
end



function widget:TextCommand(command)
	local cmdgiven = false
	
	if (string.find(command, "+illumthres") == 1) then illumThreshold = illumThreshold + 0.02 cmdgiven = true end
	if (string.find(command, "-illumthres") == 1) then illumThreshold = illumThreshold - 0.02 cmdgiven = true end

	if (string.find(command, "+glowamplif") == 1) then maxBrightness = maxBrightness + 0.05 cmdgiven = true end
	if (string.find(command, "-glowamplif") == 1) then maxBrightness = maxBrightness - 0.05 cmdgiven = true end

	if (string.find(command, "+blurpasses") == 1) then blurPasses = blurPasses + 1 cmdgiven = true end
	if (string.find(command, "-blurpasses") == 1) then blurPasses = blurPasses - 1 cmdgiven = true end

	if (string.find(command, "+bloomdebug") == 1) then dbgDraw = 1 cmdgiven = true end
	if (string.find(command, "-bloomdebug") == 1) then dbgDraw = 0 cmdgiven = true end

	if cmdgiven then
		illumThreshold = math.max(0.0, math.min(1.0, illumThreshold))
		blurPasses = math.max(0, blurPasses)
		
		Spring.Echo("[BloomShader::TextCommand]")
		Spring.Echo("   illumThreshold: " .. illumThreshold)
		Spring.Echo("   maxBrightness:  " .. maxBrightness)
		--Spring.Echo("   blurAmplifier:  " .. blurAmplifier)
		Spring.Echo("   blurPasses:     " .. blurPasses)
		--Spring.Echo("   dilatePass:     " .. dilatePass)
	end
end



