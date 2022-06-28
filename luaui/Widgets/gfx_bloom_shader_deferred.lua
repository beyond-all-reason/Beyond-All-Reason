local isPotatoGpu = false
local gpuMem = (Platform.gpuMemorySize and Platform.gpuMemorySize or 1000) / 1000
if Platform ~= nil and Platform.gpuVendor == 'Intel' then
	isPotatoGpu = true
end
if gpuMem and gpuMem > 0 and gpuMem < 1800 then
	isPotatoGpu = true
end

function widget:GetInfo()
	return {
		name      = "Bloom Shader Deferred", --(v0.5)
		desc      = "Light Bloom Shader, simulates overbrightness",
		author    = "Kloot, Beherith",
		date      = "2018-05-13",
		license   = "GPL V2",
		layer     = 99999,
		enabled   = not isPotatoGpu,
	}
end

local version = 1.1

local dbgDraw = 0               -- draw only the bloom-mask? [0 | 1]

local glowAmplifier = 0.85            -- intensity multiplier when filtering a glow source fragment [1, n]
local blurAmplifier = 1        -- intensity multiplier when applying a blur pass [1, n] (should be set close to 1)
local illumThreshold = 0            -- how bright does a fragment need to be before being considered a glow source? [0, 1]

--quality =1 : 90 fps, 9% memctrler load, 99% shader load
--quality =2 : 113 fps, 57% memctrler load, 99% shader load
--quality =4 : 123 fps, 9% memctrler load, 99% shader load

local preset = 2
local presets = {
	{
		quality = 3,
		blurPasses = 2,
		blursize = 8,
	},
	{
		quality = 2,
		blurPasses = 3,
		blursize = 9,
	},
	{
		quality = 1,
		blurPasses = 4,
		blursize = 9,
	},
}

-- non-editables
local vsx = 1                        -- current viewport width
local vsy = 1                        -- current viewport height
local ivsx = 1.0 / vsx
local ivsy = 1.0 / vsy

local debugBrightShader = false

-- shader and texture handles
local blurShaderH71 = nil
local blurShaderV71 = nil

local brightShader = nil
local brightTexture1 = nil
local brightTexture2 = nil

local combineShader = nil

local glGetSun = gl.GetSun

local glCreateTexture = gl.CreateTexture
local glDeleteTexture = gl.DeleteTexture
local glRenderToTexture = gl.RenderToTexture
local glTexture = gl.Texture

local glGetShaderLog = gl.GetShaderLog
local glCreateShader = gl.CreateShader
local glDeleteShader = gl.DeleteShader
local glUseShader = gl.UseShader

local glUniformInt = gl.UniformInt
local glUniform = gl.Uniform
local glGetUniformLocation = gl.GetUniformLocation

local brightShaderIllumLoc, brightShaderFragLoc
local blurShaderH71FragLoc, blurShaderV71FragLoc
local combineShaderDebgDrawLoc

local camX, camY, camZ = Spring.GetCameraPosition()
local camDirX, camDirY, camDirZ = Spring.GetCameraDirection()

local function SetIllumThreshold()
	local ra, ga, ba = glGetSun("ambient", "unit")
	local rd, gd, bd = glGetSun("diffuse","unit")
	local rs, gs, bs = glGetSun("specular")

	local ambientIntensity  = ra * 0.299 + ga * 0.587 + ba * 0.114
	local diffuseIntensity  = rd * 0.299 + gd * 0.587 + bd * 0.114
	local specularIntensity = rs * 0.299 + gs * 0.587 + bs * 0.114

	illumThreshold = illumThreshold*(0.8 * ambientIntensity) + (0.5 * diffuseIntensity) + (0.1 * specularIntensity)
	illumThreshold = math.min(illumThreshold, 0.8)

	illumThreshold = (0.4 + illumThreshold) / 2
end
SetIllumThreshold()

local function RemoveMe(msg)
	Spring.Echo(msg)
	widgetHandler:RemoveWidget()
end

local function MakeBloomShaders()
	local viewSizeX, viewSizeY = Spring.GetViewGeometry()

	vsx = math.max(4,viewSizeX); ivsx = 1.0 / vsx --we can do /n here!
	vsy = math.max(4,viewSizeY); ivsy = 1.0 / vsy
	local qvsx,qvsy = math.floor(vsx/presets[preset].quality), math.floor(vsy/presets[preset].quality)
	glDeleteTexture(brightTexture1 or "")
	glDeleteTexture(brightTexture2 or "")

	brightTexture1 = glCreateTexture(math.max(1,qvsx), math.max(1,qvsy), {
		fbo = true,
		min_filter = GL.LINEAR, mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP, wrap_t = GL.CLAMP,
	})
	brightTexture2 = glCreateTexture(math.max(1,qvsx), math.max(1,qvsy), {
		fbo = true,
		min_filter = GL.LINEAR, mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP, wrap_t = GL.CLAMP,
	})

	if (brightTexture1 == nil or brightTexture2 == nil) then
		if (brightTexture1 == nil ) then Spring.Echo('brightTexture1 == nil ') end
		if (brightTexture2 == nil ) then Spring.Echo('brightTexture2 == nil ') end
		RemoveMe("[BloomShader::ViewResize] removing widget, bad texture target")
		return
	end


	if glDeleteShader then
		if brightShader ~= nil then glDeleteShader(brightShader or 0) end
		if blurShaderH71 ~= nil then glDeleteShader(blurShaderH71 or 0) end
		if blurShaderV71 ~= nil then glDeleteShader(blurShaderV71 or 0) end
		if combineShader ~= nil then glDeleteShader(combineShader or 0) end
	end

	combineShader = glCreateShader({
		fragment = [[
			#version 150 compatibility
			uniform sampler2D texture0;
			uniform int debugDraw;

			void main(void) {
				vec4 a = texture2D(texture0, gl_TexCoord[0].st);
				if (debugDraw == 1) {
					a.a= 1.0;
				}
				gl_FragColor = a;
			}
		]],
		--while this vertex shader seems to do nothing, it actually does the very important world space to screen space mapping for gl.TexRect!
		vertex = [[
			#version 150 compatibility
			void main(void)
			{
				gl_TexCoord[0] = gl_MultiTexCoord0;
				gl_Position    = gl_Vertex;
			}
		]],
		uniformInt = {
			texture0 = 0,
			debugDraw = 0,
		}
	})

	if (combineShader == nil) then
		RemoveMe("[BloomShader::Initialize] combineShader compilation failed"); print(glGetShaderLog()); return
	end

	-- How about we do linear sampling instead, using the GPU's built in texture fetching linear blur hardware :)
	-- http://rastergrid.com/blog/2010/09/efficient-gaussian-blur-with-linear-sampling/
	-- this allows us to get away with 5 texture fetches instead of 9 for our 9 sized kernel!
	 -- TODO:  all this simplification may result in the accumulation of quantizing errors due to the small numbers that get pushed into the BrightTexture

	blurShaderH71 = glCreateShader({
		fragment = "#version 150 compatibility\n"..
			"#define inverseRX " .. tostring(ivsx) .. "\n" .. [[
			uniform sampler2D texture0;
			uniform int blursize;
			uniform float fragBlurAmplifier;
			const float invKernelSum = 0.0084; // (1/119)

			void main(void) {
				vec2 texCoors = vec2(gl_TexCoord[0]);
				vec3 newblur;

				newblur  = 10 * texture2D(texture0, texCoors + vec2(-blursize * inverseRX, 0)).rgb;
				newblur += 37 * texture2D(texture0, texCoors + vec2(-(blursize/3.5) * inverseRX, 0)).rgb;
				newblur += 25 * texture2D(texture0, texCoors + vec2(0               , 0)).rgb;
				newblur += 37 * texture2D(texture0, texCoors + vec2( (blursize/3.5) * inverseRX, 0)).rgb;
				newblur += 10 * texture2D(texture0, texCoors + vec2( blursize * inverseRX, 0)).rgb;
				gl_FragColor = vec4(newblur * invKernelSum * fragBlurAmplifier, 1.0);
			}
		]],
		uniformInt = {
			texture0 = 0,
			blursize = math.floor(presets[preset].blursize),
		},
	})

	if (blurShaderH71 == nil) then
		RemoveMe("[BloomShader::Initialize] blurShaderH71 compilation failed"); Spring.Echo(glGetShaderLog()); return
	end

	blurShaderV71 = glCreateShader({
		fragment = "#version 150 compatibility\n"..
		"#define inverseRY " .. tostring(ivsy) .. "\n" .. [[
			uniform sampler2D texture0;
			uniform int blursize;
			uniform float fragBlurAmplifier;
			const float invKernelSum = 0.0084; // (1/119)

			void main(void) {
				vec2 texCoors = vec2(gl_TexCoord[0]);
				vec3 newblur;

				newblur  = 10 * texture2D(texture0, texCoors + vec2(0, -blursize * inverseRY)).rgb;
				newblur += 37 * texture2D(texture0, texCoors + vec2(0, -(blursize/3.5) * inverseRY)).rgb;
				newblur += 25 * texture2D(texture0, texCoors + vec2(0,                         0)).rgb;
				newblur += 37 * texture2D(texture0, texCoors + vec2(0,  (blursize/3.5) * inverseRY)).rgb;
				newblur += 10 * texture2D(texture0, texCoors + vec2(0,  blursize * inverseRY)).rgb;
				gl_FragColor = vec4(newblur * invKernelSum * fragBlurAmplifier, 1.0);
			}
		]],

		uniformInt = {
			texture0 = 0,
			blursize = math.floor(presets[preset].blursize),
		}
	})

	if (blurShaderV71 == nil) then
		RemoveMe("[BloomShader::Initialize] blurShaderV71 compilation failed"); Spring.Echo(glGetShaderLog()); return
	end

	brightShader = glCreateShader({
		fragment =   [[
			#version 150 compatibility
			uniform sampler2D modelDiffuseTex;
			uniform sampler2D modelEmitTex;

			uniform sampler2D modelDepthTex;
			uniform sampler2D mapDepthTex;

			uniform float illuminationThreshold;
			uniform float fragGlowAmplifier;

			void main(void) {
				vec2 texCoors = vec2(gl_TexCoord[0]);
				vec4 color = vec4(texture2D(modelDiffuseTex, texCoors));
				vec4 colorEmit = texture2D(modelEmitTex, texCoors);

				float modelDepth = texture2D(modelDepthTex, texCoors).r;
				float mapDepth = texture2D(mapDepthTex, texCoors).r;

				float unoccludedModel = float(modelDepth < mapDepth); // this is 1 for a model fragment

				//Handle transparency in color.a
				color.rgb = color.rgb * color.a;

				//calculate the resulting color by adding the emit color
				color.rgb += colorEmit.rgb;

				//Make the bloom more sensitive to luminance in green channel
				float illum = dot(color.rgb, vec3(0.2990, 0.4870, 0.2140)); //adjusted from the real values of  vec3(0.2990, 0.5870, 0.1140)

				// This results in an all 0/1 vector if its over the threshold
				float illumCond = float(illum > illuminationThreshold) ;

				vec4 brightOutput = vec4(color.rgb * (illum-illuminationThreshold), 1.0) * fragGlowAmplifier * unoccludedModel ;

				// mix each channel on wether
				gl_FragColor = mix(
					vec4(0.0, 0.0, 0.0, 1.0),
					brightOutput,
					illumCond);
			}
		]],

		uniformInt = {
			modelDiffuseTex = 0,
			modelEmitTex = 1,
			modelDepthTex = 2,
			mapDepthTex = 3,
		}
	})

	if (brightShader == nil) then
		RemoveMe("[BloomShader::Initialize] brightShader compilation failed"); print(glGetShaderLog()); return
	end



	--brightShaderText0Loc = glGetUniformLocation(brightShader, "modelDiffuseTex")
	--brightShaderText1Loc = glGetUniformLocation(brightShader, "modelEmitTex")

	brightShaderIllumLoc = glGetUniformLocation(brightShader, "illuminationThreshold")
	brightShaderFragLoc = glGetUniformLocation(brightShader, "fragGlowAmplifier")

	--blurShaderH71Text0Loc = glGetUniformLocation(blurShaderH71, "texture0")
	blurShaderH71FragLoc = glGetUniformLocation(blurShaderH71, "fragBlurAmplifier")
	--blurShaderV71Text0Loc = glGetUniformLocation(blurShaderV71, "texture0")
	blurShaderV71FragLoc = glGetUniformLocation(blurShaderV71, "fragBlurAmplifier")

	combineShaderDebgDrawLoc = glGetUniformLocation(combineShader, "debugDraw")
	--combineShaderTexture0Loc = glGetUniformLocation(combineShader, "texture0")
	--combineShaderTexture1Loc = glGetUniformLocation(combineShader, "texture1")

end

function widget:ViewResize(viewSizeX, viewSizeY)
	MakeBloomShaders()
end

function widget:Initialize()

	if glCreateShader == nil then
		RemoveMe("[BloomShader::Initialize] removing widget, no shader support")
		return
	end

	local hasdeferredmodelrendering = (Spring.GetConfigString("AllowDeferredModelRendering")=='1')
	if hasdeferredmodelrendering == false then
		RemoveMe("[BloomShader::Initialize] removing widget, AllowDeferredModelRendering is required")
	end
	local hasdeferredmaprendering = (Spring.GetConfigString("AllowDeferredMapRendering")=='1')
	if hasdeferredmaprendering == false then
		RemoveMe("[BloomShader::Initialize] removing widget, AllowDeferredMapRendering is required")
	end

	WG['bloomdeferred'] = {}
	WG['bloomdeferred'].getBrightness = function()
		return glowAmplifier
	end
	WG['bloomdeferred'].setBrightness = function(value)
		glowAmplifier = value
		MakeBloomShaders()
	end
	WG['bloomdeferred'].getPreset = function()
		return preset
	end
	WG['bloomdeferred'].setPreset = function(value)
		preset = value
		MakeBloomShaders()
	end

	MakeBloomShaders()
end

function widget:Shutdown()
	glDeleteTexture(brightTexture1 or "")
	if glDeleteShader then
		if brightShader ~= nil then glDeleteShader(brightShader or 0) end
		if blurShaderH71 ~= nil then glDeleteShader(blurShaderH71 or 0) end
		if blurShaderV71 ~= nil then glDeleteShader(blurShaderV71 or 0) end
		if combineShader ~= nil then glDeleteShader(combineShader or 0) end
	end
	WG['bloomdeferred'] = nil
end


local function Bloom()
	gl.DepthMask(false)
	gl.Color(1, 1, 1, 1)

	glUseShader(brightShader)
		--glUniformInt(brightShaderText0Loc, 0)
		--glUniformInt(brightShaderText1Loc, 1)
		glUniform(   brightShaderIllumLoc, illumThreshold)
		glUniform(   brightShaderFragLoc, glowAmplifier)
		glTexture(0, "$model_gbuffer_difftex")
		glTexture(1, "$model_gbuffer_emittex")
		glTexture(2, "$model_gbuffer_zvaltex")
		glTexture(3, "$map_gbuffer_zvaltex")

		glRenderToTexture(brightTexture1, gl.TexRect, -1, 1, 1, -1)

		glTexture(0, false)
		glTexture(1, false)
		glTexture(2, false)
		glTexture(3, false)
	glUseShader(0)

	if not debugBrightShader then
		for i = 1, presets[preset].blurPasses do
			glUseShader(blurShaderH71)
				--glUniformInt(blurShaderH71Text0Loc, 0)
				glUniform(blurShaderH71FragLoc, blurAmplifier)
				glTexture(brightTexture1)
				glRenderToTexture(brightTexture2, gl.TexRect, -1, 1, 1, -1)
				glTexture(false)
			glUseShader(0)

			glUseShader(blurShaderV71)
				--glUniformInt(blurShaderV71Text0Loc, 0)
				glUniform(blurShaderV71FragLoc, blurAmplifier)
				glTexture(brightTexture2)
				glRenderToTexture(brightTexture1, gl.TexRect, -1, 1, 1, -1)
				glTexture(false)
			glUseShader(0)
		end
	end

	if dbgDraw == 0 then
		gl.Blending("alpha_add")
	else
		gl.Blending(GL.ONE, GL.ZERO)
	end

	glUseShader(combineShader)
		glUniformInt(combineShaderDebgDrawLoc, dbgDraw)
		--glUniformInt(combineShaderTexture0Loc, 0)
		glTexture(0, brightTexture1)
		gl.TexRect(-1, -1, 1, 1, 0, 0, 1, 1)
		glTexture(0, false)
	glUseShader(0)

	gl.Blending("reset")
	gl.DepthMask(true)
end

function widget:DrawWorld()
	Bloom()
end


function widget:GetConfigData()
	return {
		version = version,
		glowAmplifier = glowAmplifier,
		preset = preset,
	}
end

function widget:SetConfigData(data)
	if data.version and data.version == version then
		data.version = version
		if data.glowAmplifier ~= nil then
			glowAmplifier = data.glowAmplifier
		end
		if data.preset ~= nil then
			preset = data.preset
			if preset > 3 then
				preset = 3
			end
		end
	end
end
