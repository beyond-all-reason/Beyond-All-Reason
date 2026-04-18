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


-- Localized functions for performance
local mathCeil = math.ceil
local mathMax = math.max

-- Localized Spring API for performance
local spEcho = Spring.Echo

local version = 2.1

local dbgDraw = 0              -- draw only the bloom-mask? [0 | 1]

local glowAmplifier = 1.0            -- intensity multiplier on glow source fragments (HDR pipeline -- much lower than the old 8-bit pipeline needed)
local maxBrightContribution = 0.9     -- per-pixel cap on the bright pass output to prevent fireflies / overwhelming bloom on intense emissive blink frames
local illumThreshold = 0            -- soft-knee threshold for the bright pass (computed from sun lighting)
local kneeWidth = 0.5               -- width of the soft knee around illumThreshold
local upsampleRadius = 1.0          -- 3x3 tent filter radius in texels (for mip chain upsample)
local temporalBlend = 0.55          -- 0 = no smoothing (current frame only), 1 = freeze. ~0.5 kills sub-pixel shimmer of small emissives
local useScreenBlend = true         -- true: dst + bloom*(1-dst)  ("screen"-like, soft cap). false: pure additive (old behaviour)

-- Modern bloom pipeline: bright pass -> Karis-averaged mip chain (downsample 13-tap Jimenez)
-- -> additive 3x3 tent upsample chain -> combine.
-- preset = base downscale + mip count. More mips = wider/softer glow halo.
local preset = 2
local presets = {
	{ downscale = 3, mipCount = 4 }, -- low
	{ downscale = 2, mipCount = 5 }, -- medium
	{ downscale = 1, mipCount = 6 }, -- high
}

-- RGBA16F internal format (lets us blur HDR pixels without 8-bit clamping at 1.0)
local GL_RGBA16F_ARB = 0x881A

-- non-editables
local vsx = 1                        -- current viewport width
local vsy = 1                        -- current viewport height
local qvsx,qvsy                      -- size of bloom mip 1 (top of chain)
local iqvsx, iqvsy

local debugBrightShader = false

-- shader and texture handles
local brightShader = nil
local downsampleShader = nil
local upsampleShader = nil
local blendShader = nil
local combineShader = nil

local bloomMips = {} -- array of { tex, w, h, ix, iy }
local historyTex = nil   -- last-frame final bloom (mip[1] resolution), used for temporal smoothing
local historyValid = false

local rectVAO = nil

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

	-- Rec.709 luminance weights (proper)
	local ambientIntensity  = ra * 0.2126 + ga * 0.7152 + ba * 0.0722
	local diffuseIntensity  = rd * 0.2126 + gd * 0.7152 + bd * 0.0722
	local specularIntensity = rs * 0.2126 + gs * 0.7152 + bs * 0.0722

	illumThreshold = illumThreshold*(0.8 * ambientIntensity) + (0.5 * diffuseIntensity) + (0.1 * specularIntensity)
	illumThreshold = math.min(illumThreshold, 0.8)

	illumThreshold = (0.4 + illumThreshold) / 2
end
SetIllumThreshold()

local function RemoveMe(msg)
	spEcho(msg)
	widgetHandler:RemoveWidget()
end

local function FreeMips()
	for i = 1, #bloomMips do
		if bloomMips[i].tex then glDeleteTexture(bloomMips[i].tex) end
	end
	bloomMips = {}
	if historyTex then glDeleteTexture(historyTex); historyTex = nil end
	historyValid = false
end

local function MakeBloomShaders()
	local viewSizeX, viewSizeY = Spring.GetViewGeometry()
	local downscale = presets[preset].downscale
	local mipCount = presets[preset].mipCount
	--spEcho("New bloom init preset:", preset)
	vsx = mathMax(4,viewSizeX)
	vsy = mathMax(4,viewSizeY)
	qvsx,qvsy = mathCeil(vsx/downscale), mathCeil(vsy/downscale) -- we ceil to ensure perfect upscaling
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
		MIPCOUNT = mipCount,
	}

	local definesString = LuaShader.CreateShaderDefinesString(shaderConfig)

	--spEcho(vsx, vsy, qvsx,qvsy)

	-- Allocate the mip chain. Mip 1 is qvsx x qvsy (top of chain, sees the bright pass).
	-- Each successive mip halves both dimensions until mipCount.
	FreeMips()
	local mw, mh = qvsx, qvsy
	for i = 1, mipCount do
		local tw, th = mathMax(1, mw), mathMax(1, mh)
		local tex = glCreateTexture(tw, th, {
			fbo = true,
			format = GL_RGBA16F_ARB,
			min_filter = GL.LINEAR, mag_filter = GL.LINEAR,
			wrap_s = GL.CLAMP_TO_EDGE, wrap_t = GL.CLAMP_TO_EDGE,
		})
		if tex == nil then
			spEcho('bloomMip['..i..'] == nil ('..tw..'x'..th..')')
			RemoveMe("[BloomShader::ViewResize] removing widget, bad texture target")
			return
		end
		bloomMips[i] = { tex = tex, w = tw, h = th, ix = 1.0/tw, iy = 1.0/th }
		mw = mathCeil(mw * 0.5)
		mh = mathCeil(mh * 0.5)
	end

	-- History texture (same size as mip[1]) for temporal smoothing.
	historyTex = glCreateTexture(mathMax(1, qvsx), mathMax(1, qvsy), {
		fbo = true,
		format = GL_RGBA16F_ARB,
		min_filter = GL.LINEAR, mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP_TO_EDGE, wrap_t = GL.CLAMP_TO_EDGE,
	})
	historyValid = false


	if glDeleteShader then
		if brightShader     then brightShader:Finalize()     end
		if downsampleShader then downsampleShader:Finalize() end
		if upsampleShader   then upsampleShader:Finalize()   end
		if blendShader      then blendShader:Finalize()      end
		if combineShader    then combineShader:Finalize()    end
	end


	combineShader = LuaShader({
			fragment = "#version 150 compatibility\n" .. definesString  ..  [[
				uniform sampler2D texture0;
				uniform int debugDraw;
				uniform float bloomNorm;

				void main(void) {
					vec4 a = texture2D(texture0, gl_TexCoord[0].st);
					a.rgb *= bloomNorm;
					if (debugDraw == 1) {
						a.a = 1.0;
					}
					gl_FragColor = a;
				}
			]],
			vertex =
				"#version 150 compatibility\n" .. definesString ..[[
				void main(void)	{
					gl_TexCoord[0] = vec4(gl_Vertex.zwzw);
					#if DOWNSCALE >= 2
						// correct for the rounding pad: only the [0, VSX/(DOWNSCALE*HSX)] sub-region of mip1 covers the screen
						gl_TexCoord[0].xy = vec2(gl_TexCoord[0].xy * vec2(DOWNSCALE * HSX, DOWNSCALE * HSY ) /  vec2(VSX, VSY));
					#endif
					gl_Position    = vec4(gl_Vertex.xy, 0, 1);	}
			]],
			uniformInt = {
				texture0 = 0,
				debugDraw = 0,
			},
			uniformFloat = {
				bloomNorm = 1.0,
			},
		},
		"Bloom Combine Shader")

	if not combineShader:Initialize() then
		RemoveMe("[BloomShader::Initialize] combineShader compilation failed"); spEcho(glGetShaderLog()); return
	end


	-- Downsample shader: 13-tap Jimenez "next gen post processing in CoD:AW" filter.
	-- On the very first downsample (firstPass==1) we apply a Karis luminance average to
	-- suppress fireflies (single super-bright HDR pixels causing flickering halos).
	downsampleShader = LuaShader({
		vertex = [[
			#version 150 compatibility
			void main(void)	{
				gl_TexCoord[0] = vec4(gl_Vertex.zwzw);
				gl_Position    = vec4(gl_Vertex.xy, 0, 1);
			}
		]],
		fragment = "#version 150 compatibility\n" .. definesString .. [[
			uniform sampler2D source;
			uniform vec2 sourceTexelSize;
			uniform int firstPass;

			float karisWeight(vec3 c) {
				// Rec.709 luminance, then Karis average weight 1/(1+L)
				float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
				return 1.0 / (1.0 + l * 0.25);
			}

			void main(void) {
				vec2 uv = gl_TexCoord[0].xy;
				vec2 px = sourceTexelSize;

				vec3 a = texture2D(source, uv + px * vec2(-2.0, -2.0)).rgb;
				vec3 b = texture2D(source, uv + px * vec2( 0.0, -2.0)).rgb;
				vec3 c = texture2D(source, uv + px * vec2( 2.0, -2.0)).rgb;
				vec3 d = texture2D(source, uv + px * vec2(-2.0,  0.0)).rgb;
				vec3 e = texture2D(source, uv).rgb;
				vec3 f = texture2D(source, uv + px * vec2( 2.0,  0.0)).rgb;
				vec3 g = texture2D(source, uv + px * vec2(-2.0,  2.0)).rgb;
				vec3 h = texture2D(source, uv + px * vec2( 0.0,  2.0)).rgb;
				vec3 i = texture2D(source, uv + px * vec2( 2.0,  2.0)).rgb;
				vec3 j = texture2D(source, uv + px * vec2(-1.0, -1.0)).rgb;
				vec3 k = texture2D(source, uv + px * vec2( 1.0, -1.0)).rgb;
				vec3 l = texture2D(source, uv + px * vec2(-1.0,  1.0)).rgb;
				vec3 m = texture2D(source, uv + px * vec2( 1.0,  1.0)).rgb;

				// Five 4-tap groups (each samples a 2x2 area)
				vec3 g0 = (a + b + d + e) * 0.25;
				vec3 g1 = (b + c + e + f) * 0.25;
				vec3 g2 = (d + e + g + h) * 0.25;
				vec3 g3 = (e + f + h + i) * 0.25;
				vec3 g4 = (j + k + l + m) * 0.25;

				vec3 result;
				if (firstPass == 1) {
					float w0 = karisWeight(g0);
					float w1 = karisWeight(g1);
					float w2 = karisWeight(g2);
					float w3 = karisWeight(g3);
					float w4 = karisWeight(g4);
					float wt = w0 + w1 + w2 + w3 + w4;
					result = (g0 * w0 + g1 * w1 + g2 * w2 + g3 * w3 + g4 * w4) / wt;
				} else {
					// Standard Jimenez weights: center 0.5, four outer corners 0.125 each
					result = g4 * 0.5 + (g0 + g1 + g2 + g3) * 0.125;
				}
				gl_FragColor = vec4(result, 1.0);
			}
		]],
		uniformInt = {
			source = 0,
			firstPass = 0,
		},
		uniformFloat = {
			sourceTexelSize = {1.0, 1.0},
		},
	}, "Bloom Downsample Shader")

	if not downsampleShader:Initialize() then
		RemoveMe("[BloomShader::Initialize] downsampleShader compilation failed"); spEcho(glGetShaderLog()); return
	end


	-- Upsample shader: 3x3 tent filter, blended additively into the next-larger mip.
	upsampleShader = LuaShader({
		vertex = [[
			#version 150 compatibility
			void main(void)	{
				gl_TexCoord[0] = vec4(gl_Vertex.zwzw);
				gl_Position    = vec4(gl_Vertex.xy, 0, 1);
			}
		]],
		fragment = "#version 150 compatibility\n" .. definesString .. [[
			uniform sampler2D source;
			uniform vec2 sourceTexelSize;
			uniform float filterRadius;

			void main(void) {
				vec2 uv = gl_TexCoord[0].xy;
				float x = sourceTexelSize.x * filterRadius;
				float y = sourceTexelSize.y * filterRadius;

				vec3 a = texture2D(source, uv + vec2(-x, -y)).rgb;
				vec3 b = texture2D(source, uv + vec2( 0, -y)).rgb;
				vec3 c = texture2D(source, uv + vec2( x, -y)).rgb;
				vec3 d = texture2D(source, uv + vec2(-x,  0)).rgb;
				vec3 e = texture2D(source, uv).rgb;
				vec3 f = texture2D(source, uv + vec2( x,  0)).rgb;
				vec3 g = texture2D(source, uv + vec2(-x,  y)).rgb;
				vec3 h = texture2D(source, uv + vec2( 0,  y)).rgb;
				vec3 i = texture2D(source, uv + vec2( x,  y)).rgb;

				// 3x3 tent: center 4, edges 2, corners 1 -> divide by 16
				vec3 result = e * 4.0 + (b + d + f + h) * 2.0 + (a + c + g + i);
				result *= (1.0 / 16.0);
				gl_FragColor = vec4(result, 1.0);
			}
		]],
		uniformInt = {
			source = 0,
		},
		uniformFloat = {
			sourceTexelSize = {1.0, 1.0},
			filterRadius = 1.0,
		},
	}, "Bloom Upsample Shader")

	if not upsampleShader:Initialize() then
		RemoveMe("[BloomShader::Initialize] upsampleShader compilation failed"); spEcho(glGetShaderLog()); return
	end


	-- Temporal blend shader: mix history and current frame to suppress sub-pixel
	-- shimmer of small/thin emissives (no reprojection - fine for low-frequency bloom).
	blendShader = LuaShader({
		vertex = [[
			#version 150 compatibility
			void main(void)	{
				gl_TexCoord[0] = vec4(gl_Vertex.zwzw);
				gl_Position    = vec4(gl_Vertex.xy, 0, 1);
			}
		]],
		fragment = "#version 150 compatibility\n" .. definesString .. [[
			uniform sampler2D currentTex;
			uniform sampler2D historyTex;
			uniform float historyMix;

			void main(void) {
				vec3 cur  = texture2D(currentTex, gl_TexCoord[0].xy).rgb;
				vec3 hist = texture2D(historyTex, gl_TexCoord[0].xy).rgb;
				gl_FragColor = vec4(mix(cur, hist, historyMix), 1.0);
			}
		]],
		uniformInt = {
			currentTex = 0,
			historyTex = 1,
		},
		uniformFloat = {
			historyMix = 0.0,
		},
	}, "Bloom Temporal Blend Shader")

	if not blendShader:Initialize() then
		RemoveMe("[BloomShader::Initialize] blendShader compilation failed"); spEcho(glGetShaderLog()); return
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
			uniform float kneeWidth;
			uniform float fragGlowAmplifier;
			uniform float maxBrightContribution;

			void main(void) {
				// Center texture coordinates correctly (rounding pad correction)
				vec2 texCoors = vec2(gl_TexCoord[0].xy * vec2(VSX, VSY) / vec2(DOWNSCALE * HSX, DOWNSCALE * HSY ));
				#if DOWNSCALE <= 2
					float modelDepth = texture2D(modelDepthTex, texCoors).r;

					// Bail early if this is not a model fragment
					if (modelDepth > 0.9999) {
						gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
						return;
					}

					float mapDepth = texture2D(mapDepthTex, texCoors).r;
					float unoccludedModel = float(modelDepth < mapDepth);

					vec4 color = vec4(texture2D(modelDiffuseTex, texCoors));
					vec4 colorEmit = texture2D(modelEmitTex, texCoors);

				#else
					// downscale by 3 case
					vec2 offset = vec2(1.0/VSX, 1.0/VSY) * 0.56;
					float modelDepth1 = texture2D(modelDepthTex, texCoors + offset).r;
					float modelDepth2 = texture2D(modelDepthTex, texCoors - offset).r;

					if ((modelDepth1 + modelDepth2) > 1.9999) {
						gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
						return;
					}

					float mapDepth = texture2D(mapDepthTex, texCoors).r;
					float unoccludedModel = float((modelDepth1 + modelDepth2) * 0.5 < mapDepth);

					vec4 color = vec4(texture2D(modelDiffuseTex, texCoors+ offset));
						 color += vec4(texture2D(modelDiffuseTex, texCoors- offset));
						 color *= 0.5;
					vec4 colorEmit = texture2D(modelEmitTex, texCoors+ offset);
						 colorEmit *=2;
						 colorEmit += texture2D(modelEmitTex, texCoors- offset);

				#endif


				// Handle transparency in color.a
				color.rgb = color.rgb * color.a;

				// Add the emit color
				color.rgb += colorEmit.rgb;

				// Proper Rec.709 luminance
				float illum = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));

				// Soft-knee threshold: smoothstep from (T - knee) to (T + knee) instead of a hard cutoff.
				// This greatly reduces "popping" of pixels in/out of bloom and removes binary fireflies.
				float kneeLow  = illuminationThreshold - kneeWidth * 0.5;
				float kneeHigh = illuminationThreshold + kneeWidth * 0.5;
				float kneeMul  = smoothstep(kneeLow, kneeHigh, illum);

				// Standard "subtract threshold" bright pass (no extra (illum-threshold) gain).
				// In an HDR (FP16) pipeline that gain term is no longer clamped at 1.0, so it
				// would explode bright emissive blinks. Soft-cap the per-pixel contribution.
				vec3 excess = max(color.rgb - vec3(illuminationThreshold), vec3(0.0));
				vec3 brightOutput = excess * fragGlowAmplifier * unoccludedModel * kneeMul;
				brightOutput = min(brightOutput, vec3(maxBrightContribution));

				gl_FragColor = vec4(brightOutput, 1.0);
			}
		]],

		uniformInt = {
			modelDiffuseTex = 0,
			modelEmitTex = 1,
			modelDepthTex = 2,
			mapDepthTex = 3,
		},
		uniformFloat = {
			illuminationThreshold = 0,
			kneeWidth = 0.5,
			fragGlowAmplifier = 0,
			maxBrightContribution = 1.5,
		}
	}, "Bloom Bright Shader")

	if not brightShader:Initialize() then
		spEcho(glGetShaderLog());
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
	FreeMips()
	if glDeleteShader then
		if brightShader     then brightShader:Finalize()     end
		if downsampleShader then downsampleShader:Finalize() end
		if upsampleShader   then upsampleShader:Finalize()   end
		if blendShader      then blendShader:Finalize()      end
		if combineShader    then combineShader:Finalize()    end
	end
	WG['bloomdeferred'] = nil
end

local function FullScreenQuad()
	rectVAO:DrawArrays(GL.TRIANGLES)
end

local function Bloom()
	if #bloomMips == 0 then return end

	gl.DepthMask(false)
	gl.Color(1, 1, 1, 1)
	gl.Culling(true)

	-- 1) Bright pass: write into mip[1] (top of chain).
	gl.Blending(false)
	brightShader:Activate()
		brightShader:SetUniform("illuminationThreshold", illumThreshold)
		brightShader:SetUniform("kneeWidth", kneeWidth)
		brightShader:SetUniform("fragGlowAmplifier", glowAmplifier)
		brightShader:SetUniform("maxBrightContribution", maxBrightContribution)

		glTexture(0, "$model_gbuffer_difftex")
		glTexture(1, "$model_gbuffer_emittex")
		glTexture(2, "$model_gbuffer_zvaltex")
		glTexture(3, "$map_gbuffer_zvaltex")

		glRenderToTexture(bloomMips[1].tex, FullScreenQuad)

		glTexture(0, false)
		glTexture(1, false)
		glTexture(2, false)
		glTexture(3, false)
	brightShader:Deactivate()

	if not debugBrightShader then
		local mipCount = #bloomMips

		-- 2) Downsample chain: mip[i] -> mip[i+1].
		--    Karis luminance average on the very first downsample to kill fireflies.
		gl.Blending(false)
		downsampleShader:Activate()
		for i = 1, mipCount - 1 do
			local src = bloomMips[i]
			local dst = bloomMips[i + 1]
			downsampleShader:SetUniform("sourceTexelSize", src.ix, src.iy)
			downsampleShader:SetUniformInt("firstPass", (i == 1) and 1 or 0)
			glTexture(0, src.tex)
			glRenderToTexture(dst.tex, FullScreenQuad)
			glTexture(0, false)
		end
		downsampleShader:Deactivate()

		-- 3) Upsample chain: mip[i+1] -> mip[i] additively (3x3 tent).
		--    Result accumulates into mip[1], which holds the final blurred bloom.
		gl.Blending(GL.ONE, GL.ONE)
		upsampleShader:Activate()
		upsampleShader:SetUniform("filterRadius", upsampleRadius)
		for i = mipCount - 1, 1, -1 do
			local src = bloomMips[i + 1]
			local dst = bloomMips[i]
			upsampleShader:SetUniform("sourceTexelSize", src.ix, src.iy)
			glTexture(0, src.tex)
			glRenderToTexture(dst.tex, FullScreenQuad)
			glTexture(0, false)
		end
		upsampleShader:Deactivate()
	end

	-- 3.5) Temporal smoothing: blend mip[1] (current) with historyTex (last frame),
	--      then write the result back into both mip[1] (for combine) and historyTex.
	local finalSrc = bloomMips[1].tex
	if historyTex and temporalBlend > 0.0 and not debugBrightShader then
		if historyValid then
			gl.Blending(false)
			blendShader:Activate()
				blendShader:SetUniform("historyMix", temporalBlend)
				glTexture(0, bloomMips[1].tex)
				glTexture(1, historyTex)
				glRenderToTexture(historyTex, FullScreenQuad)
				glTexture(0, false)
				glTexture(1, false)
			blendShader:Deactivate()
			finalSrc = historyTex
		else
			-- First frame: prime history from current bloom.
			gl.Blending(false)
			blendShader:Activate()
				blendShader:SetUniform("historyMix", 0.0)
				glTexture(0, bloomMips[1].tex)
				glTexture(1, bloomMips[1].tex)
				glRenderToTexture(historyTex, FullScreenQuad)
				glTexture(0, false)
				glTexture(1, false)
			blendShader:Deactivate()
			historyValid = true
			finalSrc = historyTex
		end
	end

	-- 4) Combine: blend the accumulated bloom onto the screen.
	if dbgDraw == 0 then
		if useScreenBlend then
			-- "Screen"-like blend: dst + src*(1-dst). Naturally soft-caps near 1.0
			-- so already-bright scene pixels don't blow out from added bloom.
			gl.Blending(GL.ONE_MINUS_DST_COLOR, GL.ONE)
		else
			gl.Blending("alpha_add")
		end
	else
		gl.Blending(GL.ONE, GL.ZERO)
	end
	combineShader:Activate()
		combineShader:SetUniformInt("debugDraw", dbgDraw)
		-- Each upsample additively contributed once, so we have ~mipCount-1 accumulated copies of glow.
		-- Normalise so total brightness stays comparable to the old single-blur path.
		local norm = 1.0 / math.max(1, #bloomMips - 1)
		combineShader:SetUniform("bloomNorm", norm)
		glTexture(0, finalSrc)
		rectVAO:DrawArrays(GL.TRIANGLES)
		glTexture(0, false)
	combineShader:Deactivate()

	gl.Blending("reset")
	gl.DepthMask(false)
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
