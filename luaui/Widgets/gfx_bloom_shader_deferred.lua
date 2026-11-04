local isPotatoGpu = false
local gpuMem = (Platform.gpuMemorySize and Platform.gpuMemorySize or 1000) / 1000
if Platform ~= nil and Platform.gpuVendor == "Intel" then
	isPotatoGpu = true
end
if gpuMem and gpuMem > 0 and gpuMem < 1800 then
	isPotatoGpu = true
end

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Bloom Shader Deferred", --(v0.5)
		desc = "Applies bloom to units only",
		author = "Kloot, Beherith",
		date = "2018-05-13",
		license = "GNU GPL, v2 or later",
		layer = 99999,
		enabled = not isPotatoGpu,
	}
end

-- Localized functions for performance
local mathCeil = math.ceil
local mathMax = math.max

-- Localized Spring API for performance
local spEcho = Spring.Echo

local version = 2.1

local dbgDraw = 0 -- draw only the bloom-mask? [0 | 1]

local glowAmplifier = 1.0 -- intensity multiplier on glow source fragments (HDR pipeline -- much lower than the old 8-bit pipeline needed)
local maxBrightContribution = 0.91 -- per-pixel cap on the bright pass output to prevent fireflies / overwhelming bloom on intense emissive blink frames
local illumThreshold = 0.1 -- soft-knee threshold for the bright pass (computed from sun lighting)
local kneeWidth = 5 -- width of the soft knee around illumThreshold
local upsampleRadius = 1.0 -- 3x3 tent filter radius in texels (for mip chain upsample)
local temporalBlend = 0.55 -- 0 = no smoothing (current frame only), 1 = freeze. ~0.5 kills sub-pixel shimmer of small emissives
local useScreenBlend = true -- true: dst + bloom*(1-dst)  ("screen"-like, soft cap). false: pure additive (old behaviour)

local glowAmplifierMult = 1.25

-- Modern bloom pipeline: bright pass -> Karis-averaged mip chain (downsample 13-tap Jimenez)
-- -> additive 3x3 tent upsample chain -> combine.
-- preset = base downscale + mip count. More mips = wider/softer glow halo.
local preset = 2
local presets = {
	{ downscale = 3, mipCount = 4 }, -- low
	{ downscale = 2, mipCount = 5 }, -- medium
	{ downscale = 1, mipCount = 6 }, -- high
}

-- R11F_G11F_B10F internal format: still HDR (no 8-bit clamping at 1.0) but half the
-- bandwidth of RGBA16F; the bloom chain never uses alpha. RGBA16F kept as fallback.
local GL_R11F_G11F_B10F = 0x8C3A
local GL_RGBA16F_ARB = 0x881A
local bloomTexFormat = GL_R11F_G11F_B10F

-- non-editables
local vsx = 1 -- current viewport width
local vsy = 1 -- current viewport height
local viewPosX, viewPosY, viewSizeX, viewSizeY = 0, 0, 1, 1 -- world viewport, restored for the combine pass
local qvsx, qvsy -- size of bloom mip 1 (top of chain)
local iqvsx, iqvsy

local debugBrightShader = false

-- shader and texture handles
local brightShader = nil
local downsampleShader = nil
local upsampleShader = nil
local upsampleFinalShader = nil -- last upsample step + temporal blend fused into one pass
local combineShader = nil
local historyMixOn = false -- whether upsampleFinalShader's historyMix is temporalBlend (else 0)
local brightShaderAmplifier = 0.0 -- glowAmplifier value brightShader currently uses
local glowAmplifierLoc = -1 -- brightShader's fragGlowAmplifier location

local bloomMips = {} -- array of { tex, fbo, w, h, ix, iy }
local historyTargets = {} ---@type table<integer, table> ping-pong pair (mip[1] resolution) holding the final bloom, used for temporal smoothing
local historyIndex = 1 -- which of the two historyTargets holds last frame's result
local historyValid = false

local rectVAO ---@type VAO
local rectVAOObjects = {} -- the VAO and its buffers, deleted on shutdown

local LuaShader = gl.LuaShader
local InstanceVBOTable = gl.InstanceVBOTable

local glGetSun = gl.GetSun

local glCreateTexture = gl.CreateTexture
local glDeleteTexture = gl.DeleteTexture
local glCreateFBO = gl.CreateFBO
local glDeleteFBO = gl.DeleteFBO
local glIsValidFBO = gl.IsValidFBO
local glRawBindFBO = gl.RawBindFBO
local glViewport = gl.Viewport
local glTexture = gl.Texture
local glBlending = gl.Blending
local glDepthMask = gl.DepthMask

local GL_TRIANGLES = GL.TRIANGLES
local GL_ONE = GL.ONE
local GL_ZERO = GL.ZERO
local GL_ONE_MINUS_DST_COLOR = GL.ONE_MINUS_DST_COLOR
local GL_COLOR_ATTACHMENT0_EXT = 0x8CE0

local glGetShaderLog = gl.GetShaderLog
local glCreateShader = gl.CreateShader
local glDeleteShader = gl.DeleteShader

local function SetIllumThreshold()
	local ra, ga, ba = glGetSun("ambient", "unit")
	local rd, gd, bd = glGetSun("diffuse", "unit")
	local rs, gs, bs = glGetSun("specular")

	-- Rec.709 luminance weights (proper)
	local ambientIntensity = ra * 0.2126 + ga * 0.7152 + ba * 0.0722
	local diffuseIntensity = rd * 0.2126 + gd * 0.7152 + bd * 0.0722
	local specularIntensity = rs * 0.2126 + gs * 0.7152 + bs * 0.0722

	illumThreshold = illumThreshold * (0.7 * ambientIntensity) + (0.4 * diffuseIntensity) + (0.1 * specularIntensity)
	illumThreshold = math.min(illumThreshold, 0.8)

	illumThreshold = (0.4 + illumThreshold) / 2.1
end
SetIllumThreshold()

local function RemoveMe(msg)
	spEcho(msg)
	widgetHandler:RemoveWidget()
end

local function FreeTarget(target)
	glDeleteFBO(target.fbo)
	glDeleteTexture(target.tex)
end

local function FreeMips()
	for i = 1, #bloomMips do
		FreeTarget(bloomMips[i])
	end
	bloomMips = {}
	for i = 1, #historyTargets do
		FreeTarget(historyTargets[i])
	end
	historyTargets = {}
	historyValid = false
end

local function MakeBloomShaders()
	viewSizeX, viewSizeY, viewPosX, viewPosY = Spring.GetViewGeometry()
	local downscale = presets[preset].downscale
	local mipCount = presets[preset].mipCount
	--spEcho("New bloom init preset:", preset)
	vsx = mathMax(4, viewSizeX)
	vsy = mathMax(4, viewSizeY)
	qvsx, qvsy = mathCeil(vsx / downscale), mathCeil(vsy / downscale) -- we ceil to ensure perfect upscaling
	iqvsx, iqvsy = 1.0 / qvsx, 1.0 / qvsy

	local padx, pady = downscale * qvsx - vsx, downscale * qvsy - vsy

	local shaderConfig = {
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

	local function CreateBloomTarget(tw, th)
		local tex = glCreateTexture(tw, th, {
			format = bloomTexFormat,
			min_filter = GL.LINEAR,
			mag_filter = GL.LINEAR,
			wrap_s = GL.CLAMP_TO_EDGE,
			wrap_t = GL.CLAMP_TO_EDGE,
		})
		local fbo = tex and glCreateFBO({ color0 = tex, drawbuffers = { GL_COLOR_ATTACHMENT0_EXT } })
		if fbo and glIsValidFBO(fbo) then
			return { tex = tex, fbo = fbo, w = tw, h = th, ix = 1.0 / tw, iy = 1.0 / th }
		end
		if fbo then
			glDeleteFBO(fbo)
		end
		if tex then
			glDeleteTexture(tex)
		end
		if bloomTexFormat ~= GL_RGBA16F_ARB then
			bloomTexFormat = GL_RGBA16F_ARB
			return CreateBloomTarget(tw, th)
		end
	end

	local mw, mh = qvsx, qvsy
	for i = 1, mipCount do
		local tw, th = mathMax(1, mw), mathMax(1, mh)
		bloomMips[i] = CreateBloomTarget(tw, th)
		if bloomMips[i] == nil then
			spEcho("bloomMip[" .. i .. "] == nil (" .. tw .. "x" .. th .. ")")
			RemoveMe("[BloomShader::ViewResize] removing widget, bad texture target")
			return
		end
		mw = mathCeil(mw * 0.5)
		mh = mathCeil(mh * 0.5)
	end

	-- History targets (same size as mip[1]) for temporal smoothing. Two of them,
	-- ping-ponged each frame, so we never sample the texture being rendered to.
	for i = 1, 2 do
		historyTargets[i] = CreateBloomTarget(qvsx, qvsy)
		if historyTargets[i] == nil then
			RemoveMe("[BloomShader::ViewResize] removing widget, bad history texture target")
			return
		end
	end
	historyIndex = 1
	historyValid = false

	if glDeleteShader then
		if brightShader then
			brightShader:Finalize()
		end
		if downsampleShader then
			downsampleShader:Finalize()
		end
		if upsampleShader then
			upsampleShader:Finalize()
		end
		if upsampleFinalShader then
			upsampleFinalShader:Finalize()
		end
		if combineShader then
			combineShader:Finalize()
		end
	end

	-- Each upsample additively contributed once, but smaller mips contribute less
	-- perceived brightness than larger ones, so a linear 1/(N-1) normalization
	-- over-attenuates higher presets. Use a sqrt-based divisor anchored at the
	-- low preset (4 mips => 1/3) so medium/high presets stay closer in intensity
	-- to low while still keeping their wider/softer halo.
	local bloomNorm = 1.0 / math.sqrt(3 * mathMax(1, mipCount - 1))
	-- Small extra boost for the highest preset, whose extra wide mips
	-- spread the energy further and thus look dimmer than medium.
	if mipCount >= 6 then
		bloomNorm = bloomNorm * 1.05
	end

	combineShader = LuaShader({
		fragment = "#version 150 compatibility\n" .. definesString .. [[
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
		vertex = "#version 150 compatibility\n" .. definesString .. [[
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
			debugDraw = dbgDraw,
		},
		uniformFloat = {
			bloomNorm = bloomNorm,
		},
	}, "Bloom Combine Shader")

	if not combineShader:Initialize() then
		RemoveMe("[BloomShader::Initialize] combineShader compilation failed")
		spEcho(glGetShaderLog())
		return
	end

	-- Downsample shader: 13-tap Jimenez "next gen post processing in CoD:AW" filter.
	-- On the very first downsample (source is mip[1]) we apply a Karis luminance average to
	-- suppress fireflies (single super-bright HDR pixels causing flickering halos).
	downsampleShader = LuaShader({
		vertex = "#version 150 compatibility\n" .. definesString .. [[
			uniform sampler2D source;
			flat out vec2 sourceTexelSize;
			flat out int firstPass;
			void main(void)	{
				ivec2 sourceSize = textureSize(source, 0);
				sourceTexelSize = 1.0 / vec2(sourceSize);
				firstPass = int(sourceSize == ivec2(HSX, HSY));
				gl_TexCoord[0] = vec4(gl_Vertex.zwzw);
				gl_Position    = vec4(gl_Vertex.xy, 0, 1);
			}
		]],
		fragment = "#version 150 compatibility\n" .. definesString .. [[
			uniform sampler2D source;
			flat in vec2 sourceTexelSize;
			flat in int firstPass;

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
		},
	}, "Bloom Downsample Shader")

	if not downsampleShader:Initialize() then
		RemoveMe("[BloomShader::Initialize] downsampleShader compilation failed")
		spEcho(glGetShaderLog())
		return
	end

	-- Upsample shader: 3x3 tent filter, blended additively into the next-larger mip.
	upsampleShader = LuaShader({
		vertex = [[
			#version 150 compatibility
			uniform sampler2D source;
			flat out vec2 sourceTexelSize;
			void main(void)	{
				sourceTexelSize = 1.0 / vec2(textureSize(source, 0));
				gl_TexCoord[0] = vec4(gl_Vertex.zwzw);
				gl_Position    = vec4(gl_Vertex.xy, 0, 1);
			}
		]],
		fragment = "#version 150 compatibility\n" .. definesString .. [[
			uniform sampler2D source;
			flat in vec2 sourceTexelSize;
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
			filterRadius = upsampleRadius,
		},
	}, "Bloom Upsample Shader")

	if not upsampleShader:Initialize() then
		RemoveMe("[BloomShader::Initialize] upsampleShader compilation failed")
		spEcho(glGetShaderLog())
		return
	end

	-- Final upsample + temporal blend, fused into a single pass: tent-upsamples
	-- mip[2], adds the bright pass (mip[1]) on top, then mixes with last frame's
	-- result to suppress sub-pixel shimmer of small/thin emissives (no reprojection
	-- - fine for low-frequency bloom). Writes the final bloom into a history texture.
	upsampleFinalShader = LuaShader({
		vertex = [[
			#version 150 compatibility
			void main(void)	{
				gl_TexCoord[0] = vec4(gl_Vertex.zwzw);
				gl_Position    = vec4(gl_Vertex.xy, 0, 1);
			}
		]],
		fragment = "#version 150 compatibility\n" .. definesString .. [[
			uniform sampler2D source;
			uniform sampler2D brightTex;
			uniform sampler2D historyTex;
			uniform vec2 sourceTexelSize;
			uniform float filterRadius;
			uniform float historyMix;

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
				vec3 tent = e * 4.0 + (b + d + f + h) * 2.0 + (a + c + g + i);
				vec3 cur = texture2D(brightTex, uv).rgb + tent * (1.0 / 16.0);
				vec3 hist = texture2D(historyTex, uv).rgb;
				gl_FragColor = vec4(mix(cur, hist, historyMix), 1.0);
			}
		]],
		uniformInt = {
			source = 0,
			brightTex = 1,
			historyTex = 2,
		},
		uniformFloat = {
			sourceTexelSize = { bloomMips[2].ix, bloomMips[2].iy },
			filterRadius = upsampleRadius,
			historyMix = 0.0,
		},
	}, "Bloom Final Upsample Shader")

	if not upsampleFinalShader:Initialize() then
		RemoveMe("[BloomShader::Initialize] upsampleFinalShader compilation failed")
		spEcho(glGetShaderLog())
		return
	end
	historyMixOn = false

	brightShader = LuaShader({
		vertex = [[
			#version 150 compatibility
			void main(void)	{
				gl_TexCoord[0] = vec4(gl_Vertex.zwzw);
				gl_Position    = vec4(gl_Vertex.xy, 0, 1);	}
		]],
		fragment = "#version 150 compatibility \n" .. definesString .. [[

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

					// Bail before the color fetches if the model is occluded by the map
					float mapDepth = texture2D(mapDepthTex, texCoors).r;
					if (modelDepth >= mapDepth) {
						gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
						return;
					}

					vec4 color = texture2D(modelDiffuseTex, texCoors);
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

					// Bail before the color fetches if the model is occluded by the map
					float mapDepth = texture2D(mapDepthTex, texCoors).r;
					if ((modelDepth1 + modelDepth2) * 0.5 >= mapDepth) {
						gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
						return;
					}

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
				vec3 brightOutput = excess * fragGlowAmplifier * kneeMul;
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
		-- these only change on a rebuild (fragGlowAmplifier also via setBrightness), so bake them in here
		-- instead of re-uploading them every frame
		uniformFloat = {
			illuminationThreshold = illumThreshold,
			kneeWidth = kneeWidth,
			fragGlowAmplifier = glowAmplifier * glowAmplifierMult,
			maxBrightContribution = maxBrightContribution,
		},
	}, "Bloom Bright Shader")

	if not brightShader:Initialize() then
		spEcho(glGetShaderLog())
		RemoveMe("[BloomShader::Initialize] brightShader compilation failed")
		return
	end
	glowAmplifierLoc = brightShader.uniformLocations.fragGlowAmplifier or -1 -- GetUniformLocation needs it active
	brightShaderAmplifier = glowAmplifier
end

-- a full-screen quad; with index and instance buffers attached too, engines without the LuaVAO
-- keep-partial fix (RecoilEngine #3446) keep the VAO instead of rebuilding it every draw
local function CreateRectVAO()
	local vao = InstanceVBOTable.MakeTexRectVAO()
	local indexVBO = gl.GetVBO(GL.ELEMENT_ARRAY_BUFFER, false)
	local instanceVBO = gl.GetVBO(GL.ARRAY_BUFFER, false)
	if not (vao and indexVBO and instanceVBO) then
		return false
	end
	indexVBO:Define(3)
	indexVBO:Upload({ 0, 1, 2 })
	instanceVBO:Define(1, { { id = 1, name = "unused", size = 1 } })
	instanceVBO:Upload({ 0 })
	vao:AttachIndexBuffer(indexVBO)
	vao:AttachInstanceBuffer(instanceVBO)
	rectVAOObjects = { vao, indexVBO, instanceVBO }
	rectVAO = vao
	return true
end

function widget:ViewResize()
	local sizeX, sizeY, posX, posY = Spring.GetViewGeometry()
	if sizeX == viewSizeX and sizeY == viewSizeY and posX == viewPosX and posY == viewPosY then
		return -- the handler's first ViewResize after load repeats the geometry Initialize built for
	end
	MakeBloomShaders()
end

function widget:Initialize()
	if glCreateShader == nil then
		RemoveMe("[BloomShader::Initialize] removing widget, no shader support")
		return
	end

	local hasdeferredmodelrendering = (Spring.GetConfigString("AllowDeferredModelRendering") == "1")
	if hasdeferredmodelrendering == false then
		RemoveMe("[BloomShader::Initialize] removing widget, AllowDeferredModelRendering is required")
	end
	local hasdeferredmaprendering = (Spring.GetConfigString("AllowDeferredMapRendering") == "1")
	if hasdeferredmaprendering == false then
		RemoveMe("[BloomShader::Initialize] removing widget, AllowDeferredMapRendering is required")
	end

	WG.bloomdeferred = {}
	WG.bloomdeferred.getBrightness = function()
		return glowAmplifier
	end
	WG.bloomdeferred.setBrightness = function(value)
		glowAmplifier = value -- a uniform, uploaded by Bloom: no rebuild per slider step
		historyValid = false -- switch at once, as the rebuild did
	end
	WG.bloomdeferred.getPreset = function()
		return preset
	end
	WG.bloomdeferred.setPreset = function(value)
		preset = value
		MakeBloomShaders()
	end

	MakeBloomShaders()
	if not CreateRectVAO() then
		RemoveMe("[BloomShader::Initialize] removing widget, could not create the full-screen quad VAO")
	end
end

function widget:Shutdown()
	FreeMips()
	for i = 1, #rectVAOObjects do
		rectVAOObjects[i]:Delete()
	end
	rectVAOObjects = {}
	if glDeleteShader then
		if brightShader then
			brightShader:Finalize()
		end
		if downsampleShader then
			downsampleShader:Finalize()
		end
		if upsampleShader then
			upsampleShader:Finalize()
		end
		if upsampleFinalShader then
			upsampleFinalShader:Finalize()
		end
		if combineShader then
			combineShader:Finalize()
		end
	end
	WG.bloomdeferred = nil
end

-- binds a bloom target for drawing, returns the previously bound FBO
local function BindTarget(target)
	local prevFBO = glRawBindFBO(target.fbo)
	glViewport(0, 0, target.w, target.h)
	return prevFBO
end

local function Bloom()
	local mipCount = #bloomMips
	if mipCount == 0 then
		return
	end

	glDepthMask(false)

	-- 1) Bright pass: write into mip[1] (top of chain).
	glBlending(false)
	local prevFBO = BindTarget(bloomMips[1])
	brightShader:Activate()
	if brightShaderAmplifier ~= glowAmplifier then
		gl.Uniform(glowAmplifierLoc, glowAmplifier * glowAmplifierMult)
		brightShaderAmplifier = glowAmplifier
	end

	glTexture(0, "$model_gbuffer_difftex")
	glTexture(1, "$model_gbuffer_emittex")
	glTexture(2, "$model_gbuffer_zvaltex")
	glTexture(3, "$map_gbuffer_zvaltex")

	rectVAO:DrawArrays(GL_TRIANGLES)
	brightShader:Deactivate()

	local finalSrc = bloomMips[1].tex

	if not debugBrightShader then
		-- 2) Downsample chain: mip[i] -> mip[i+1].
		--    Karis luminance average on the very first downsample to kill fireflies.
		downsampleShader:Activate()
		for i = 1, mipCount - 1 do
			glTexture(0, bloomMips[i].tex)
			BindTarget(bloomMips[i + 1])
			rectVAO:DrawArrays(GL_TRIANGLES)
		end
		downsampleShader:Deactivate()

		-- 3) Upsample chain: mip[i+1] -> mip[i] additively (3x3 tent), down to mip[2].
		glBlending(GL_ONE, GL_ONE)
		upsampleShader:Activate()
		for i = mipCount - 1, 2, -1 do
			glTexture(0, bloomMips[i + 1].tex)
			BindTarget(bloomMips[i])
			rectVAO:DrawArrays(GL_TRIANGLES)
		end
		upsampleShader:Deactivate()

		-- 3.5) Fused final step: tent-upsample mip[2], add the bright pass (mip[1])
		--      and blend with last frame's result, all in one pass. Ping-pong between
		--      the two history targets so we never sample the render target.
		--      On the first frame there is no valid history yet: sample mip[1]
		--      (any finite values) with historyMix = 0, which yields the current frame.
		glBlending(false)
		local histDst = historyTargets[3 - historyIndex]
		upsampleFinalShader:Activate()
		if historyMixOn ~= historyValid then
			upsampleFinalShader:SetUniform("historyMix", historyValid and temporalBlend or 0.0)
			historyMixOn = historyValid
		end
		glTexture(0, bloomMips[2].tex)
		glTexture(1, bloomMips[1].tex)
		glTexture(2, historyValid and historyTargets[historyIndex].tex or bloomMips[1].tex)
		BindTarget(histDst)
		rectVAO:DrawArrays(GL_TRIANGLES)
		upsampleFinalShader:Deactivate()
		historyIndex = 3 - historyIndex
		historyValid = true
		finalSrc = histDst.tex
	end

	glRawBindFBO(nil, nil, prevFBO)
	glViewport(viewPosX, viewPosY, viewSizeX, viewSizeY)

	-- 4) Combine: blend the accumulated bloom onto the screen.
	if dbgDraw == 0 then
		if useScreenBlend then
			-- "Screen"-like blend: dst + src*(1-dst). Naturally soft-caps near 1.0
			-- so already-bright scene pixels don't blow out from added bloom.
			glBlending(GL_ONE_MINUS_DST_COLOR, GL_ONE)
		else
			glBlending("alpha_add")
		end
	else
		glBlending(GL_ONE, GL_ZERO)
	end
	combineShader:Activate()
	glTexture(0, finalSrc)
	rectVAO:DrawArrays(GL_TRIANGLES)
	combineShader:Deactivate()

	-- gl.Texture enables GL_TEXTURE_2D on each unit it binds
	glTexture(0, false)
	glTexture(1, false)
	glTexture(2, false)
	glTexture(3, false)

	glBlending("reset")
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
