function widget:GetInfo()
	return {
		name      = "Bloom Shader - highlights",
		desc      = "Sets Spring In Bloom",
		author    = "Kloot",
		date      = "24-10-2013",
		license   = "GPL, v2",
		layer     = 0,
		enabled   = false,
	}
end

local glActiveTexture      = gl.ActiveTexture
local glCopyToTexture      = gl.CopyToTexture
local glRenderToTexture    = gl.RenderToTexture
local glTexture            = gl.Texture
local glTexRect            = gl.TexRect

local glUseShader          = gl.UseShader

local glUniform            = gl.Uniform
local glUniformArray       = gl.UniformArray
local glGetUniformLocation = gl.GetUniformLocation



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



local VIEWPORT_XDIM_IDX = 1
local VIEWPORT_XINV_IDX = 2
local VIEWPORT_YDIM_IDX = 3
local VIEWPORT_YINV_IDX = 4
local VIEWPORT_XPOS_IDX = 5
local VIEWPORT_YPOS_IDX = 6

local FILTER_SHADER_IDX = 1
local H_BLUR_SHADER_IDX = 2
local V_BLUR_SHADER_IDX = 3
local POSTFX_SHADER_IDX = 4

local SCREEN_TEXTURE_IDX = 1
local SOURCE_TEXTURE_IDX = 2
local TARGET_TEXTURE_IDX = 3



local mapRenderBufferNames = {"$map_gb_st", "$map_gb_et", "$map_gb_zt"}
local mdlRenderBufferNames = {"$mdl_gb_st", "$mdl_gb_et", "$mdl_gb_zt"}

local mapIntensityThresholds = {
	["BlueBend-v01"                ] = 0.60,
	["Charlie in the Hills v2.1"   ] = 0.50,
	["Castles"                     ] = 0.65,
	["Coast To Coast Remake V2"    ] = 0.99,
	["cold_snap_v1"                ] = 0.80,
	["coldsnapv2"                  ] = 0.95,
	["Comet Catcher Redux v2"      ] = 0.80,
	["DeltaSiegeDry"               ] = 0.85,
	["FolsomDamDeluxeV4"           ] = 0.75,
	["Nuclear_Winter_v1"           ] = 0.90,
	["Small Supreme Battlefield V2"] = 0.65,
	["Tabula-v4"                   ] = 0.60,
	["Terra"                       ] = 0.65,
	["TheColdPlace"                ] = 0.80,
	["Tumult"                      ] = 0.75,
}


local function GetIntensityThreshold(rk, gk, bk,  aw, dw, sw,  sun)
	if (sun) then
		local ra, ga, ba = gl.GetSun("ambient")
		local rd, gd, bd = gl.GetSun("diffuse")
		local rs, gs, bs = gl.GetSun("specular")

		local  ambientIntensity = ((ra * rk) + (ga * gk) + (ba * bk)) * aw
		local  diffuseIntensity = ((rd * rk) + (gd * gk) + (bd * bk)) * dw
		local specularIntensity = ((rs * rk) + (gs * gk) + (bs * bk)) * sw

		return (ambientIntensity + diffuseIntensity + specularIntensity)
	end

	return (mapIntensityThresholds[Game.mapName] or 0.70)
end

local function GetNormalizedKernelWeights(n, mu, sigma, xmin, xmax)
	assert(n >= 3)
	assert((n % 2) == 1)

	local wgts = {}
	local wsum = 0.0

	local xstp = (xmax - xmin) / (n - 1)
	local norm = 1.0 / (sigma * math.sqrt(math.pi * 2.0))

	for i = 0, n - 1 do
		local xcur = xmin + xstp * i
		local xdev = xcur - mu

		local pwr = -((xdev * xdev) / (2.0 * sigma * sigma))
		local exp = math.exp(pwr)

		wgts[#wgts + 1] = norm * exp
		wsum = wsum + (norm * exp)
	end

	for i = 0, n - 1 do
		wgts[i + 1] = wgts[i + 1] / wsum
	end

	return wgts
end



local configParams = {
	debugDrawBloomMask     = false,
	screenCopyBloomSource  =  true,
	applyBloomOnlyToModels =  true,

	filterParams = {0.5, 0.6, 0.3, GetIntensityThreshold(0.5, 0.6, 0.3,  0.8, 0.1, 0.1,  false),  0.5},

	blurKernelWeights = GetNormalizedKernelWeights(9, 0.0, 2.5, -6.0, 6.0),
	blurShaderPasses = 4,
}

local viewPortState = {
	[VIEWPORT_XDIM_IDX] = 1,
	[VIEWPORT_XINV_IDX] = 1.0,
	[VIEWPORT_YDIM_IDX] = 1,
	[VIEWPORT_YINV_IDX] = 1.0,
	[VIEWPORT_XPOS_IDX] = 0,
	[VIEWPORT_YPOS_IDX] = 0,
}



local haveDeferredMapRendering = (Spring.GetConfigInt("AllowDeferredMapRendering") ~= 0)
local haveDeferredMdlRendering = (Spring.GetConfigInt("AllowDeferredModelRendering") ~= 0)
local haveDeferredMdlOnlyBloom = (haveDeferredMapRendering and haveDeferredMdlRendering and configParams.screenCopyBloomSource)

local shaders = {
	[FILTER_SHADER_IDX] = -1,
	[H_BLUR_SHADER_IDX] = -1,
	[V_BLUR_SHADER_IDX] = -1,
	[POSTFX_SHADER_IDX] = -1,
}

local textures = {
	[SCREEN_TEXTURE_IDX] = "",
	[SOURCE_TEXTURE_IDX] = "",
	[SOURCE_TEXTURE_IDX] = "",
}

local shaderProgs = {
	[FILTER_SHADER_IDX] = {
		definitions = {
			"#define numFilterParams " .. #configParams.filterParams .. "\n",

			"#define useMapRenderBuffer " .. (((haveDeferredMapRendering and (not configParams.screenCopyBloomSource)) and 1) or 0) .. "\n",
			"#define useMdlRenderBuffer " .. (((haveDeferredMdlRendering and (not configParams.screenCopyBloomSource)) and 1) or 0) .. "\n",
			"#define haveModelOnlyBloom " .. (((haveDeferredMdlOnlyBloom and      configParams.applyBloomOnlyToModels) and 1) or 0) .. "\n",

			"#define mapBloomSpecIntensityMult " .. 0.0 .. "\n",
			"#define mapBloomEmitIntensityMult " .. 1.0 .. "\n",
			"#define mdlBloomSpecIntensityMult " .. 0.0 .. "\n",
			"#define mdlBloomEmitIntensityMult " .. 1.0 .. "\n",
		},

		fragment = [[
			uniform sampler2D sourceTex;

			#if (useMapRenderBuffer == 1)
			uniform sampler2D mapSpecTex;
			uniform sampler2D mapEmitTex;
			#endif
			#if (useMdlRenderBuffer == 1)
			uniform sampler2D mdlSpecTex;
			uniform sampler2D mdlEmitTex;
			#endif

			#if (haveModelOnlyBloom == 1)
			uniform sampler2D mapZvalTex;
			uniform sampler2D mdlZvalTex;
			#endif

			uniform float filterParams[numFilterParams];

			void main(void) {
				vec2 texCoors = vec2(gl_TexCoord[0]);
				vec3 color = vec3(0.0, 0.0, 0.0);
				vec3 filter = vec3(filterParams[0], filterParams[1], filterParams[2]);

				#if (useMapRenderBuffer == 1 || useMdlRenderBuffer == 1)
				{
					// NOTE:
					//   spectex alpha is angular exponent! (on SSMF maps)
					//
					//   however we cannot use the "raw" specular textures
					//   here anyway but need the view-dependent highlights
					//   which are not in gbuffer --> not as trivial (using
					//   only emissive components looks underwhelming though
					//   is "correct")
					#if (useMapRenderBuffer == 1)
					{
						color.rgb += (texture2D(mapSpecTex, texCoors).rgb * mapBloomSpecIntensityMult);
						color.rgb += (texture2D(mapEmitTex, texCoors).rgb * mapBloomEmitIntensityMult);
					}
					#endif
					#if (useMdlRenderBuffer == 1)
					{
						color.rgb += (texture2D(mdlSpecTex, texCoors).rgb * mdlBloomSpecIntensityMult);
						color.rgb += (texture2D(mdlEmitTex, texCoors).rgb * mdlBloomEmitIntensityMult);
					}
					#endif
				}
				#else
				{
					color = texture2D(sourceTex, texCoors);
				}
				#endif

				float intensity = dot(color, filter);

				#if (haveModelOnlyBloom == 1)
				{
					float mdlDepth = texture2D(mdlZvalTex, texCoors).x;
					float mapDepth = texture2D(mapZvalTex, texCoors).x;

					intensity *= float(mdlDepth < mapDepth);
				}
				#endif

				gl_FragData[0] = mix(vec4(color, 0.05), vec4(0.0, 0.0, 0.0, 1.0), float(intensity <= filterParams[3]));
			}
		]],

		uniformInt = {
			sourceTex  = 0,

			mapSpecTex = 1,
			mapEmitTex = 2,
			mdlSpecTex = 3,
			mdlEmitTex = 4,

			mapZvalTex = 5,
			mdlZvalTex = 6,
		},
		uniformFloat = {
			filterParams = configParams.filterParams,
		},
	},


	[H_BLUR_SHADER_IDX] = {
		definitions = {
			"#define numSamples " .. #configParams.blurKernelWeights .. "\n",
			"#define horizontalPass 1\n",
		},

		fragment = [[
			uniform sampler2D sourceTex;

			uniform float invTexSizeX;
			uniform float invTexSizeY;

			uniform float weights[numSamples];

			vec4 samples[numSamples];

			void main(void) {
				vec4 sampleSum = vec4(0.0, 0.0, 0.0, 0.0);

				#if (horizontalPass == 1)
				for (int i = 0; i < numSamples; i++) {
					samples[i] = texture2D(sourceTex, gl_TexCoord[0].st + vec2(float(-(numSamples / 2) + i) * invTexSizeX, 0.0));
					sampleSum += (samples[i] * weights[i]);
				}
				#else
				for (int i = 0; i < numSamples; i++) {
					samples[i] = texture2D(sourceTex, gl_TexCoord[0].st + vec2(0.0, float(-(numSamples / 2) + i) * invTexSizeY));
					sampleSum += (samples[i] * weights[i]);
				}
				#endif

				gl_FragData[0] = sampleSum;
			}
		]],

		uniformInt = {sourceTex = 0},
		uniformFloat = {invTexSizeX, invTexSizeY, weights = configParams.blurKernelWeights},
	},

	[V_BLUR_SHADER_IDX] = {
		definitions = {
			"#define numSamples " .. #configParams.blurKernelWeights .. "\n",
			"#define horizontalPass 0\n",
		},

		fragment = "",

		uniformInt = {sourceTex = 0},
		uniformFloat = {invTexSizeX, invTexSizeY, weights = configParams.blurKernelWeights},
	},

	[POSTFX_SHADER_IDX] = {
		definitions = {
			"#define debugMode " .. ((configParams.debugDrawBloomMask and 1) or 0) .. "\n",
		},

		fragment = [[
			uniform sampler2D copyTex;
			uniform sampler2D maskTex;

			void main(void) {
				vec4 copy = texture2D(copyTex, gl_TexCoord[0].st);
				vec4 mask = texture2D(maskTex, gl_TexCoord[0].st);

				gl_FragData[0] = mix(copy + mask, mask, float(debugMode == 1));
			}
		]],

		uniformInt = {
			copyTex = 0,
			maskTex = 1,
		},
	},
}




local function RemoveWidget(msg)
	Spring.Echo("[gfx_bloomshader]" .. msg)
	widgetHandler:RemoveWidget(self)
	return
end

local function CreateShaders()
	local log = nil

	shaderProgs[V_BLUR_SHADER_IDX].vertex = shaderProgs[H_BLUR_SHADER_IDX].vertex
	shaderProgs[V_BLUR_SHADER_IDX].fragment = shaderProgs[H_BLUR_SHADER_IDX].fragment

	for i = 1, #shaderProgs do
		shaders[i] = gl.CreateShader(shaderProgs[i])

		if (shaders[i] == nil) then
			log = gl.GetShaderLog()
			break
		end
	end

	if (log ~= nil) then
		RemoveWidget("[CreateShaders] shader compilation failed:\n" .. gl.GetShaderLog())
		return false
	end

	return true
end

local function SetShaderUniformLocs()
	shaderProgs[FILTER_SHADER_IDX].uniformFloat.filterParams = glGetUniformLocation(shaders[FILTER_SHADER_IDX], "filterParams")
	shaderProgs[H_BLUR_SHADER_IDX].uniformFloat.invTexSizeX = glGetUniformLocation(shaders[H_BLUR_SHADER_IDX], "invTexSizeX")
	shaderProgs[V_BLUR_SHADER_IDX].uniformFloat.invTexSizeY = glGetUniformLocation(shaders[V_BLUR_SHADER_IDX], "invTexSizeY")
end

local function CreateTextures(viewResized)
	gl.DeleteTexture(textures[SCREEN_TEXTURE_IDX] or "")
	gl.DeleteTexture(textures[SOURCE_TEXTURE_IDX] or "")
	gl.DeleteTexture(textures[TARGET_TEXTURE_IDX] or "")

	local ppTexSize = {
		math.max(1, math.floor(viewPortState[VIEWPORT_XDIM_IDX] * configParams.filterParams[5])),
		math.max(1, math.floor(viewPortState[VIEWPORT_YDIM_IDX] * configParams.filterParams[5])),
	}
	local ppTexParams = {
		fbo        = true,
		format     = GL_RGB32F_ARB,
		wrap_s     = GL.CLAMP,
		wrap_t     = GL.CLAMP,
		min_filter = GL.LINEAR,
		mag_filter = GL.LINEAR,
	}

	textures[SOURCE_TEXTURE_IDX] = gl.CreateTexture(ppTexSize[1], ppTexSize[2], ppTexParams)
	textures[TARGET_TEXTURE_IDX] = gl.CreateTexture(ppTexSize[1], ppTexSize[2], ppTexParams)

	textures[SCREEN_TEXTURE_IDX] = gl.CreateTexture(viewPortState[VIEWPORT_XDIM_IDX], viewPortState[VIEWPORT_YDIM_IDX], {
		min_filter = GL.LINEAR, mag_filter = GL.LINEAR,
	})

	if (textures[SCREEN_TEXTURE_IDX] == nil or textures[SOURCE_TEXTURE_IDX] == nil or textures[TARGET_TEXTURE_IDX] == nil) then
		RemoveWidget("[CreateTextures] removing widget, bad texture target(s)")
		return
	end
end

local function CheckEngineVersion(version)
	local relPattern = "%d+"
	local devPattern = "\-%d+\-"

	minRelIdx, maxRelIdx = string.find(version, relPattern)
	minDevIdx, maxDevIdx = string.find(version, devPattern)

	if (minDevIdx ~= nil and maxDevIdx ~= nil) then
		assert(minRelIdx ~= nil and maxRelIdx ~= nil)

		local build = tonumber(string.sub(version, minDevIdx + 1, maxDevIdx - 1))
		local major = tonumber(string.sub(version, minRelIdx + 0, maxRelIdx - 0))

		return (major >= 94 and build >= 1410)
	end

	if (minRelIdx ~= nil and maxRelIdx ~= nil) then
		return (tonumber(string.sub(version, minRelIdx, maxRelIdx)) >= 95)
	end

	return false
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
	glTexture(0, tex)
	glTexRect(-1 * s, -1 * t,  1 * s, 1 * t)
	glTexture(0, false)
end
local function mglRenderToTexture(fboTex, tex, s, t)
	glRenderToTexture(fboTex, renderToTextureFunc, tex, s, t)
end




local function DebugDrawTexture(tex, xpos, ypos, xsize, ysize)
	glTexture(0, tex)
	glTexRect(xpos, ypos, xsize, ysize,  0.0, 0.0, 1.0, 1.0)
	glTexture(0, false)
	return true
end



function widget:DrawScreenEffects()
	local filterShaderProg = shaderProgs[FILTER_SHADER_IDX]
	local hBlurShaderProgUniforms = shaderProgs[H_BLUR_SHADER_IDX].uniformFloat
	local vBlurShaderProgUniforms = shaderProgs[V_BLUR_SHADER_IDX].uniformFloat

	glCopyToTexture(textures[SCREEN_TEXTURE_IDX],  0, 0,  viewPortState[VIEWPORT_XPOS_IDX], viewPortState[VIEWPORT_YPOS_IDX], viewPortState[VIEWPORT_XDIM_IDX], viewPortState[VIEWPORT_YDIM_IDX])

	glUseShader(shaders[FILTER_SHADER_IDX])
		glUniformArray(filterShaderProg.uniformFloat.filterParams, 1, configParams.filterParams)

		if (not configParams.screenCopyBloomSource) then
			if (haveDeferredMapRendering) then
				glTexture(filterShaderProg.uniformInt.mapSpecTex, mapRenderBufferNames[1])
				glTexture(filterShaderProg.uniformInt.mapEmitTex, mapRenderBufferNames[2])
			end
			if (haveDeferredMdlRendering) then
				glTexture(filterShaderProg.uniformInt.mdlSpecTex, mdlRenderBufferNames[1])
				glTexture(filterShaderProg.uniformInt.mdlEmitTex, mdlRenderBufferNames[2])
			end
		else
			if (haveDeferredMdlOnlyBloom and configParams.applyBloomOnlyToModels) then
				glTexture(filterShaderProg.uniformInt.mapZvalTex, mapRenderBufferNames[3])
				glTexture(filterShaderProg.uniformInt.mdlZvalTex, mdlRenderBufferNames[3])
			end
		end

		mglRenderToTexture(textures[SOURCE_TEXTURE_IDX], textures[SCREEN_TEXTURE_IDX], 1, -1)
		mglRenderToTexture(textures[TARGET_TEXTURE_IDX], textures[SCREEN_TEXTURE_IDX], 1, -1)

		if (not configParams.screenCopyBloomSource) then
			if (haveDeferredMapRendering) then
				glTexture(filterShaderProg.uniformInt.mapSpecTex, false)
				glTexture(filterShaderProg.uniformInt.mapEmitTex, false)
			end
			if (haveDeferredMdlRendering) then
				glTexture(filterShaderProg.uniformInt.mdlSpecTex, false)
				glTexture(filterShaderProg.uniformInt.mdlEmitTex, false)
			end
		else
			if (haveDeferredMdlOnlyBloom and configParams.applyBloomOnlyToModels) then
				glTexture(filterShaderProg.uniformInt.mapZvalTex, false)
				glTexture(filterShaderProg.uniformInt.mdlZvalTex, false)
			end
		end
	glUseShader(0)

	for i = 1, configParams.blurShaderPasses do
		glUseShader(shaders[H_BLUR_SHADER_IDX])
			glUniform(hBlurShaderProgUniforms.invTexSizeX, viewPortState[VIEWPORT_XINV_IDX] / configParams.filterParams[5])
			mglRenderToTexture(textures[TARGET_TEXTURE_IDX], textures[SOURCE_TEXTURE_IDX], 1, -1)
		glUseShader(0)

		glUseShader(shaders[V_BLUR_SHADER_IDX])
			glUniform(vBlurShaderProgUniforms.invTexSizeY, viewPortState[VIEWPORT_YINV_IDX] / configParams.filterParams[5])
			mglRenderToTexture(textures[SOURCE_TEXTURE_IDX], textures[TARGET_TEXTURE_IDX], 1, -1)
		glUseShader(0)
	end

	glUseShader(shaders[POSTFX_SHADER_IDX])
		mglActiveTexture(0, textures[SCREEN_TEXTURE_IDX], viewPortState[VIEWPORT_XDIM_IDX], viewPortState[VIEWPORT_YDIM_IDX], false, true)
		mglActiveTexture(1, textures[SOURCE_TEXTURE_IDX], viewPortState[VIEWPORT_XDIM_IDX], viewPortState[VIEWPORT_YDIM_IDX], false, true)
	glUseShader(0)
end


function widget:ViewResize(viewSizeX, viewSizeY)
	viewPortState[VIEWPORT_XDIM_IDX] = viewSizeX; viewPortState[VIEWPORT_XINV_IDX] = 1.0 / viewSizeX
	viewPortState[VIEWPORT_YDIM_IDX] = viewSizeY; viewPortState[VIEWPORT_YINV_IDX] = 1.0 / viewSizeY
	viewPortState[VIEWPORT_XPOS_IDX] = select(3, Spring.GetViewGeometry())
	viewPortState[VIEWPORT_YPOS_IDX] = select(4, Spring.GetViewGeometry())

	CreateTextures(true)
end

function widget:Initialize()
	if (not configParams.screenCopyBloomSource) then
		if ((not haveDeferredMapRendering) and (not haveDeferredMdlRendering)) then
			RemoveWidget("[Initialize] removing widget, no deferred rendering allowed")
			return
		end
	end
	if (gl.CreateShader == nil or gl.DeleteShader == nil) then
		RemoveWidget("[Initialize] removing widget, no shader support")
		return
	end

	if (CreateShaders()) then
		SetShaderUniformLocs()
		-- CreateTextures(false)
		widget:ViewResize(Spring.GetViewGeometry())
	end
end

function widget:Shutdown()
	gl.DeleteTexture(textures[SCREEN_TEXTURE_IDX] or "")
	gl.DeleteTexture(textures[SOURCE_TEXTURE_IDX] or "")
	gl.DeleteTexture(textures[TARGET_TEXTURE_IDX] or "")

	gl.DeleteShader(shaders[FILTER_SHADER_IDX] or 0)
	gl.DeleteShader(shaders[H_BLUR_SHADER_IDX] or 0)
	gl.DeleteShader(shaders[V_BLUR_SHADER_IDX] or 0)
	gl.DeleteShader(shaders[POSTFX_SHADER_IDX] or 0)
end

function widget:TextCommand(command)
	if (string.find(command, "bloom", 1) == nil) then
		return
	end

	if (string.find(command, "+blurpasses", 6) == 1) then configParams.blurShaderPasses = math.min(10, configParams.blurShaderPasses + 1) end
	if (string.find(command, "-blurpasses", 6) == 1) then configParams.blurShaderPasses = math.max( 0, configParams.blurShaderPasses - 1) end

	if (string.find(command, "+drawdebug", 6) == 1) then configParams.debugDrawBloomMask =  true end
	if (string.find(command, "-drawdebug", 6) == 1) then configParams.debugDrawBloomMask = false end
end

