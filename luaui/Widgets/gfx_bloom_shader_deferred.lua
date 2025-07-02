local isPotatoGpu = false
local gpuMem = (Platform.gpuMemorySize and Platform.gpuMemorySize or 1000) / 1000
if Platform ~= nil and Platform.gpuVendor == 'Intel' then
	isPotatoGpu = true
end
if gpuMem and gpuMem > 0 and gpuMem < 1800 then
	isPotatoGpu = true
end

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name      = "Bloom Shader Deferred", --(v0.5)
		desc      = "Applies bloom to units only",
		author    = "Kloot, Beherith",
		date      = "2018-05-13",
		license   = "GNU GPL, v2 or later",
		layer     = 99999,
		enabled   = not isPotatoGpu,
	}
end

local version = 1.1

local dbgDraw = 0              -- draw only the bloom-mask? [0 | 1]

local glowAmplifier = 0.85            -- intensity multiplier when filtering a glow source fragment [1, n]
local blurAmplifier = 1        -- intensity multiplier when applying a blur pass [1, n] (should be set close to 1)
local illumThreshold = 0            -- how bright does a fragment need to be before being considered a glow source? [0, 1]

--quality =1 : 90 fps, 9% memctrler load, 99% shader load
--quality =2 : 113 fps, 57% memctrler load, 99% shader load
--quality =4 : 123 fps, 9% memctrler load, 99% shader load

-- preopt: medium = 161 -> 152 fps

local preset = 2
local presets = {
	{
		quality = 3,
		blurPasses = 1,
	},
	{
		quality = 2,
		blurPasses = 1,
	},
	{
		quality = 1,
		blurPasses = 1,
	},
}

-- non-editables
local vsx = 1                        -- current viewport width
local vsy = 1                        -- current viewport height
local qvsx,qvsy
local iqvsx, iqvsy

local debugBrightShader = false

-- shader and texture handles
local blurShader = nil

local brightShader = nil
local brightTexture1 = nil
local brightTexture2 = nil

local rectVAO = nil

local combineShader = nil

local LuaShader = gl.LuaShader
local InstanceVBOTable = gl.InstanceVBOTable

local glGetSun = gl.GetSun

local glCreateTexture = gl.CreateTexture
local glDeleteTexture = gl.DeleteTexture
local glRenderToTexture = gl.RenderToTexture
local glTexture = gl.Texture

local glGetShaderLog = gl.GetShaderLog
local glCreateShader = gl.CreateShader
local glDeleteShader = gl.DeleteShader


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
	local downscale = presets[preset].quality
	--Spring.Echo("New bloom init preset:", preset)
	vsx = math.max(4,viewSizeX)
	vsy = math.max(4,viewSizeY)
	qvsx,qvsy = math.ceil(vsx/downscale), math.ceil(vsy/downscale) -- we ceil to ensure perfect upscaling
	iqvsx, iqvsy = 1.0 / qvsx, 1.0 / qvsy

	local padx, pady = downscale * qvsx - vsx, downscale * qvsy - vsy


	local shaderConfig  = {
		VSX = vsx,
		VSY = vsy,
		HSX = qvsx,
		HSY = qvsy,
		IHSX = iqvsx,
		IHSY = iqvsy,
		PADX = padx,
		PADY = pady,
		DOWNSCALE = downscale,
	}

	local definesString = LuaShader.CreateShaderDefinesString(shaderConfig)

	--Spring.Echo(vsx, vsy, qvsx,qvsy)

	glDeleteTexture(brightTexture1)
	brightTexture1 = glCreateTexture(math.max(1,qvsx), math.max(1,qvsy), {
		fbo = true,
		min_filter = GL.LINEAR, mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP, wrap_t = GL.CLAMP,
	})

	glDeleteTexture(brightTexture2)
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
		if brightShader  then brightShader:Finalize() end
		if blurShader  	then blurShader:Finalize() end
		if combineShader  then combineShader:Finalize() end
	end


	combineShader = LuaShader({
			fragment = "#version 150 compatibility\n" .. definesString  ..  [[
				uniform sampler2D texture0;
				uniform int debugDraw;

				void main(void) {
					vec2 subpixel = vec2(IHSX, IHSY) * 0.5; // YES FREAKING HALF-PIXEL BLUR HERE TOO CAUSE WHY NOT?
					vec4 a = texture2D(texture0, gl_TexCoord[0].st + subpixel);
					if (debugDraw == 1) {
						a.a= 1.0;
					}
					gl_FragColor = a;
					//gl_FragColor.rg = gl_TexCoord[0].st; // to debug texture coordinates
				}
			]],
			vertex =
				"#version 150 compatibility\n" .. definesString ..[[
				void main(void)	{
					gl_TexCoord[0] = vec4(gl_Vertex.zwzw);
					#if DOWNSCALE >= 2
						gl_TexCoord[0].xy = vec2(gl_TexCoord[0].xy * vec2(DOWNSCALE * HSX, DOWNSCALE * HSY ) /  vec2(VSX, VSY));
					#endif
					gl_Position    = vec4(gl_Vertex.xy, 0, 1);	}
			]],
			uniformInt = {
				texture0 = 0,
				debugDraw = 0,
			},
		},
		"Bloom Combine Shader")

	if not combineShader:Initialize() then
		RemoveMe("[BloomShader::Initialize] combineShader compilation failed"); Spring.Echo(glGetShaderLog()); return
	end

	-- How about we do linear sampling instead, using the GPU's built in texture fetching linear blur hardware :)
	-- http://rastergrid.com/blog/2010/09/efficient-gaussian-blur-with-linear-sampling/
	-- this allows us to get away with 5 texture fetches instead of 9 for our 9 sized kernel!
	 -- TODO:  all this simplification may result in the accumulation of quantizing errors due to the small numbers that get pushed into the BrightTexture

	blurShader = LuaShader({
		vertex = [[
			#version 150 compatibility
			void main(void)	{
				gl_TexCoord[0] = vec4(gl_Vertex.zwzw);
				gl_Position    = vec4(gl_Vertex.xy, 0, 1);	}
		]],
		fragment = "#version 150 compatibility\n".. definesString .. [[
			uniform sampler2D texture0;
			uniform float fragBlurAmplifier;
			const float invKernelSum = 0.012;
			uniform float horizontal;
			#define inverseRX 1.0

			vec2 quadGetQuadVector(vec2 screenCoords){
				vec2 quadVector =  fract(floor(screenCoords) * 0.5) * 4.0 - 1.0;
				vec2 odd_start_mirror = 0.5 * vec2(dFdx(quadVector.x), dFdy(quadVector.y));
				quadVector = quadVector * odd_start_mirror;
				return sign(quadVector);
			}

			vec3 quadGatherSum3D(vec3 inputval, vec2 quadVector){
				vec3 inputadjx = inputval - dFdx(inputval) * quadVector.x;
				vec3 inputadjy = inputval - dFdy(inputval) * quadVector.y;
				vec3 inputdiag = inputadjx - dFdy(inputadjx) * quadVector.y;
				return (inputval + inputadjx + inputadjy + inputdiag) * 0.25;
				//return vec4(
				//	dot( vec4(inputval.x, inputadjx.x, inputadjy.x, inputdiag.x), vec4(1.0)),
				//	dot( vec4(inputval.y, inputadjx.y, inputadjy.y, inputdiag.y), vec4(1.0)),
				//	dot( vec4(inputval.z, inputadjx.z, inputadjy.z, inputdiag.z), vec4(1.0)),
				//	dot( vec4(inputval.w, inputadjx.w, inputadjy.w, inputdiag.w), vec4(1.0))
				//	);
			}

			#define WF 0.56
			vec4 selfWeights = vec4(WF*WF, WF*(1.0-WF), WF*(1.0-WF), (1.0-WF)*(1.0-WF)); // F*F, F*(1.0-F), F*(1.0-F), (1-F)*(1-F)
			vec3 quadGatherSum3DWeighted(vec3 inputval, vec2 quadVector){
				vec3 inputadjx = inputval - dFdx(inputval) * quadVector.x;
				vec3 inputadjy = inputval - dFdy(inputval) * quadVector.y;
				vec3 inputdiag = inputadjx - dFdy(inputadjx) * quadVector.y;
				return vec3(
					dot( vec4(inputval.x, inputadjx.x, inputadjy.x, inputdiag.x), vec4(selfWeights)),
					dot( vec4(inputval.y, inputadjx.y, inputadjy.y, inputdiag.y), vec4(selfWeights)),
					dot( vec4(inputval.z, inputadjx.z, inputadjy.z, inputdiag.z), vec4(selfWeights))
					);
			}

			void main(void) {
				vec2 texCoors = vec2(gl_TexCoord[0]); // These are ideal texel perfect

				//gl_FragColor = vec4(texture2D(texture0,texCoors).rgb, 1.0);return;
				vec2 subpixel = vec2(IHSX, IHSY) * 0.5;
				vec2 offset = vec2(IHSX, 0.0);
				if (horizontal > 0.5) { // vertical pass
					offset = vec2(0.0, IHSY);
					subpixel = -1.0 * subpixel;
					}
				vec3 newblur;
				const float lod = 0.0;

				#if DOWNSCALE >= 2
					// old decent method, truly 14 pixel wide kernel in 7 samples
					newblur   = 6  * texture2D(texture0, texCoors + offset *  6.0 + subpixel, lod).rgb;
					newblur  += 10 * texture2D(texture0, texCoors + offset *  4.0 + subpixel, lod).rgb;
					newblur  += 13 * texture2D(texture0, texCoors + offset *  2.0 + subpixel, lod).rgb;
					newblur  += 20 * texture2D(texture0, texCoors + offset *  0.0 + subpixel, lod).rgb;
					newblur  += 13 * texture2D(texture0, texCoors + offset * -2.0 + subpixel, lod).rgb;
					newblur  += 10 * texture2D(texture0, texCoors + offset * -4.0 + subpixel, lod).rgb;
					newblur  += 6  * texture2D(texture0, texCoors + offset * -6.0 + subpixel, lod).rgb;
					gl_FragColor = vec4(newblur * invKernelSum * fragBlurAmplifier, 1.0);
				#else
					// super high quality path
					// new awesome method, 32 pixel wide kernel in 5 samples
					vec2 quadVector = quadGetQuadVector(gl_FragCoord.xy);
					//https://docs.google.com/spreadsheets/d/15nBdQMMwKzpbxot-BLrCQ_ZraPClJiRKD1pTvH6QGH0/edit?usp=sharing

					float SelfWeight = 0.202;
					vec4 WeightsNearer =  vec4(0.190,0.139,0.080,0.035);
					vec4 WeightsFurther = vec4(0.168,0.109,0.055,0.022);

					float SelfOffset = 0.496;
					vec4 OffsetsNearer =  vec4(2.488,6.473,10.457,14.442	);
					vec4 OffsetsFurther = vec4(4.480,8.465,12.449,16.434	);


					vec4 offsets = vec4(2,6,10,12);
					//vec4 offsets = vec4(1,3,5,7);
					vec4 weights = vec4(20, 13, 10, 6);
					float totalWeight = dot(weights , vec4(1.8)) ;
					subpixel = quadVector * subpixel * vec2( 1, -1);
					vec3 blurSample = vec3(0.0);
					float baseweight = SelfWeight;
					//vec3 baseSample = baseweight * texture2D(texture0, texCoors).rgb;

					vec2 quadCenterUV = texCoors - vec2(1,-1) * quadVector * vec2(IHSX, IHSY) * 0.5;

					//vec3 quadCenterSample = texture2D(texture0, quadCenterUV).rgb;
					vec3 quadSideSample = vec3(0);
					// center the UV coords between texel centers:
					vec2 sideSampleOffset;

					subpixel = vec2(0.0);
					if (horizontal > 0.5 ){
						// this means vertical pass
						// on vertical pass, move X coord towards center

						if (quadVector.x > 0) {
							weights = WeightsNearer;
							offsets = OffsetsNearer;
						}else{
							weights = WeightsFurther;
							offsets = OffsetsFurther;
						}
						sideSampleOffset = vec2( 0.5 * quadVector.x, SelfOffset * quadVector.y ) * offset;
						offsets *= -1 * quadVector.y;

					}else{
						// bail for now
						//gl_FragColor = vec4(baseSample/baseweight, 1.0); return;
						if (quadVector.y > 0) {
							weights = WeightsNearer;
							offsets = OffsetsNearer;
						}else{
							weights = WeightsFurther;
							offsets = OffsetsFurther;
						}
						sideSampleOffset = vec2( SelfOffset * quadVector.x, 0.5 * quadVector.y ) * offset;
						offsets *= -1 * quadVector.x;
					}

					quadSideSample = SelfWeight * texture2D(texture0, quadCenterUV + sideSampleOffset + subpixel).rgb;

					blurSample += weights.x * texture2D(texture0, quadCenterUV + offset * offsets.x + subpixel).rgb;
					blurSample += weights.y * texture2D(texture0, quadCenterUV + offset * offsets.y + subpixel).rgb;
					blurSample += weights.z * texture2D(texture0, quadCenterUV + offset * offsets.z + subpixel).rgb;
					blurSample += weights.w * texture2D(texture0, quadCenterUV + offset * offsets.w + subpixel).rgb;

					vec3 myfriends =  quadGatherSum3D(blurSample , quadVector) ;
					myfriends =  myfriends + quadGatherSum3DWeighted(quadSideSample, quadVector);

					gl_FragColor = vec4(myfriends * fragBlurAmplifier * 1.8 , 1.0);
				#endif
				/*
				// OLD CRAPPY METHOD:
					newblur  = 10 * texture2D(texture0, texCoors + vec2()         ).rgb;
					newblur += 37 * texture2D(texture0, texCoors + vec2(-(blursize/3.5) * inverseRX, 0)).rgb;
					newblur += 25 * texture2D(texture0, texCoors + vec2(0               , 0)).rgb;
					newblur += 37 * texture2D(texture0, texCoors + vec2( (blursize/3.5) * inverseRX, 0)).rgb;
					newblur += 10 * texture2D(texture0, texCoors + vec2( blursize * inverseRX, 0)).rgb;
				*/
			}
		]],
		uniformInt = {
			texture0 = 0,
		},
		uniformFloat = {
			horizontal = 0,
			fragBlurAmplifier = 0,
		}
	}, "Bloom Blur Shader")

	if not blurShader:Initialize() then
		RemoveMe("[BloomShader::Initialize] blurShader compilation failed"); Spring.Echo(glGetShaderLog()); return
	end


	brightShader = LuaShader({
		vertex = [[
			#version 150 compatibility
			void main(void)	{
				gl_TexCoord[0] = vec4(gl_Vertex.zwzw);
				gl_Position    = vec4(gl_Vertex.xy, 0, 1);	}
		]],
		fragment =
			"#version 150 compatibility \n" .. definesString  .. [[

			uniform sampler2D modelDiffuseTex;
			uniform sampler2D modelEmitTex;

			uniform sampler2D modelDepthTex;
			uniform sampler2D mapDepthTex;

			uniform float illuminationThreshold;
			uniform float fragGlowAmplifier;
			uniform float time;

			void main(void) {
				vec2 halfpixeloffset = vec2(IHSX, IHSY);
				float time0 = sin(time*0.003);
				// mega debugging:
				//if (dot(vec2(1.0), abs(gl_FragCoord.xy - (vec2(HSX,HSY) - 150))) < 40){ gl_FragColor = vec4(1); return;}

				// Center texture coordinates correctly
				vec2 texCoors = vec2(gl_TexCoord[0].xy * vec2(VSX, VSY) / vec2(DOWNSCALE * HSX, DOWNSCALE * HSY ));
				#if DOWNSCALE <= 2
					float modelDepth = texture2D(modelDepthTex, texCoors).r;

					//Bail early if this is not a model fragment
					if (modelDepth > 0.9999) {
						gl_FragColor = 	vec4(0.0, 0.0, 0.0, 1.0);
						return;
					}


					float mapDepth = texture2D(mapDepthTex, texCoors).r;
					float unoccludedModel = float(modelDepth < mapDepth); // this is 1 for a model fragment

					//texCoors +=  halfpixeloffset *  0.25 * time0;

					vec4 color = vec4(texture2D(modelDiffuseTex, texCoors));
					vec4 colorEmit = texture2D(modelEmitTex, texCoors);

				#else
					// this is for downscale by 3 case
					vec2 offset = vec2(1.0/VSX, 1.0/VSY) * 0.56;
					float modelDepth1 = texture2D(modelDepthTex, texCoors + offset).r;
					float modelDepth2 = texture2D(modelDepthTex, texCoors - offset).r;

					//Bail early if this is not a model fragment
					if ((modelDepth1 + modelDepth2) > 1.9999) {
						gl_FragColor = 	vec4(0.0, 0.0, 0.0, 1.0);
						return;
					}


					float mapDepth = texture2D(mapDepthTex, texCoors).r;
					float unoccludedModel = float((modelDepth1 + modelDepth2) * 0.5 < mapDepth); // this is 1 for a model fragment

					//texCoors +=  halfpixeloffset *  0.25 * time0;

					vec4 color = vec4(texture2D(modelDiffuseTex, texCoors+ offset));
						 color += vec4(texture2D(modelDiffuseTex, texCoors- offset));
						 color *= 0.5;
					vec4 colorEmit = texture2D(modelEmitTex, texCoors+ offset);
						 colorEmit *=2;
						 colorEmit += texture2D(modelEmitTex, texCoors- offset);

				#endif


				//Handle transparency in color.a
				color.rgb = color.rgb * color.a;

				//calculate the resulting color by adding the emit color
				color.rgb += colorEmit.rgb;


				//Make the bloom more sensitive to luminance in green channel
				float illum = dot(color.rgb, vec3(0.2990, 0.4870, 0.2140)); //adjusted from the real values of  vec3(0.2990, 0.5870, 0.1140)

				// This results in an all 0/1 vector if its over the threshold
				float illumCond = float(illum > illuminationThreshold) ;

				vec4 brightOutput = vec4(color.rgb * (illum-illuminationThreshold) * fragGlowAmplifier * unoccludedModel , 1.0);

				// mix each channel on wether illumCond is 1.0
				gl_FragColor = mix(
					vec4(0.0, 0.0, 0.0, 1.0),
					brightOutput,
					illumCond);
				//if (gl_TexCoord[0].x < 0.05) gl_FragColor.rgba = vec4(time0);
			}
		]],

		uniformInt = {
			modelDiffuseTex = 0,
			modelEmitTex = 1,
			modelDepthTex = 2,
			mapDepthTex = 3,
		},
		uniformFloat = {
			time = 0,
			illuminationThreshold = 0, 
			fragGlowAmplifier = 0,
		}
	}, "Bloom Bright Shader")

	if not brightShader:Initialize() then
		Spring.Echo(glGetShaderLog());
		RemoveMe("[BloomShader::Initialize] brightShader compilation failed"); return
	end

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
	rectVAO = InstanceVBOTable.MakeTexRectVAO()--  -1, -1, 1, 0,   0,0,1, 0.5)
end

function widget:Shutdown()
	glDeleteTexture(brightTexture1)
	glDeleteTexture(brightTexture2)
	brightTexture1, brightTexture2 = nil, nil
	if glDeleteShader then
		if brightShader  then brightShader:Finalize() end
		if blurShader ~= nil then blurShader:Finalize() end
		if combineShader ~= nil then combineShader:Finalize() end
	end
	WG['bloomdeferred'] = nil
end

local function FullScreenQuad()
	--gl.DepthMask(true)
	--gl.DepthTest(GL.NOTEQUAL)
	-- TODO: instead of drawing full screen quads, draw a billboard around every unit
	rectVAO:DrawArrays(GL.TRIANGLES)
end

local df = 0
local function Bloom()
	df = df + 1
	gl.DepthMask(false)
	gl.Color(1, 1, 1, 1)
	gl.Culling(true)

	brightShader:Activate()
		brightShader:SetUniform("illuminationThreshold", illumThreshold)
		brightShader:SetUniform("fragGlowAmplifier", glowAmplifier)
		--brightShader:SetUniform("time", df)

		glTexture(0, "$model_gbuffer_difftex")
		glTexture(1, "$model_gbuffer_emittex")
		glTexture(2, "$model_gbuffer_zvaltex")
		glTexture(3, "$map_gbuffer_zvaltex")

		--glRenderToTexture(brightTexture1, gl.TexRect, -1, 1, 1, -1)
		glRenderToTexture(brightTexture1, FullScreenQuad)

		glTexture(0, false)
		glTexture(1, false)
		glTexture(2, false)
		glTexture(3, false)
	brightShader:Deactivate()

	if not debugBrightShader then
		if presets[preset].blurPasses > 0 then
			blurShader:Activate()
			for i = 1, presets[preset].blurPasses do
					blurShader:SetUniform("fragBlurAmplifier", blurAmplifier)
					blurShader:SetUniform("horizontal", 0)
					glTexture(brightTexture1)
					--glRenderToTexture(brightTexture2, gl.TexRect, -1, 1, 1, -1)
					glRenderToTexture(brightTexture2, FullScreenQuad)
					glTexture(false)

					blurShader:SetUniform("horizontal", 1)
					glTexture(brightTexture2)
					--glRenderToTexture(brightTexture1, gl.TexRect, -1, 1, 1, -1)
					glRenderToTexture(brightTexture1, FullScreenQuad)
					glTexture(false)
			end
			blurShader:Deactivate()
		end
	end

	if dbgDraw == 0 then
		gl.Blending("alpha_add")
	else
		gl.Blending(GL.ONE, GL.ZERO)
	end
	combineShader:Activate()
		combineShader:SetUniformInt("debugDraw",dbgDraw)
		glTexture(0, brightTexture1)
		--gl.TexRect(-1, -1, 1, 1, 0, 0, 1, 1)
		rectVAO:DrawArrays(GL.TRIANGLES)
		glTexture(0, false)
	combineShader:Deactivate()

	gl.Blending("reset")
	gl.DepthMask(false) --"BK OpenGL state resets", was true
	gl.Culling(false)
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
