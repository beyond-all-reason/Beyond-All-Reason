local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name    = "Diffuse Painter",
		desc    = "WM/Gaea/Terragen-style layered diffuse paint over the SMF base texture",
		author  = "BARb",
		date    = "2026",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = false, -- WIP: disabled by default
	}
end

-- ============================================================================
-- Engine API aliases
-- ============================================================================
local Echo                  = Spring.Echo
local GetMouseState         = Spring.GetMouseState
local TraceScreenRay        = Spring.TraceScreenRay
local GetGroundHeight       = Spring.GetGroundHeight
local GetGroundNormal       = Spring.GetGroundNormal
local SetMapSquareTexture   = Spring.SetMapSquareTexture
local GetMapSquareTextureFn = Spring.GetMapSquareTexture

local glCreateTexture  = gl.CreateTexture
local glDeleteTexture  = gl.DeleteTexture
local glTexture        = gl.Texture
local glRenderToTexture = gl.RenderToTexture
local glCreateShader   = gl.CreateShader
local glDeleteShader   = gl.DeleteShader
local glUseShader      = gl.UseShader
local glUniform        = gl.Uniform
local glUniformInt     = gl.UniformInt
local glGetUniformLocation = gl.GetUniformLocation
local glTexRect        = gl.TexRect
local glColor          = gl.Color
local glBlending       = gl.Blending
local glLineWidth      = gl.LineWidth
local glDrawGroundCircle = gl.DrawGroundCircle
local glBeginEnd       = gl.BeginEnd
local glVertex         = gl.Vertex
local glDepthTest      = gl.DepthTest

local floor, max, min = math.floor, math.max, math.min
local cos, sin, pi    = math.cos, math.sin, math.pi
local sqrt, abs       = math.sqrt, math.abs

-- ============================================================================
-- Constants
-- ============================================================================
local SQUARE_SIZE_ELMOS = 1024 -- engine constant (one SMF texture square)
local TILE_PX           = 1024 -- composite/seed texture resolution per square
local MASK_PX           = 512  -- per-layer hand-paint mask resolution
local MAX_LAYERS        = 8

local MIN_RADIUS = 8
local MAX_RADIUS = 2000
local DEFAULT_RADIUS = 128
local MIN_STRENGTH = 0.01
local MAX_STRENGTH = 1.0
local DEFAULT_STRENGTH = 1.0
local MIN_CURVE = 0.1
local MAX_CURVE = 5.0
local DEFAULT_CURVE = 1.5

local RADIUS_STEP   = 8
local STRENGTH_STEP = 0.05
local CURVE_STEP    = 0.1

local MIN_FRACTAL       = 0.0
local MAX_FRACTAL       = 1.0
local MIN_FRACTAL_FREQ  = 0.0001
local MAX_FRACTAL_FREQ  = 0.05
local FRACTAL_FREQ_STEP = 0.001

-- ============================================================================
-- State
-- ============================================================================
local active = false

local mapSizeX, mapSizeZ = 0, 0
local numSqX, numSqZ = 0, 0

-- squares[key] = {sx, sy, seedTex, compositeTex, bound, dirty}
local squares = {}
-- masks[layerId][key] = RGBA8 paint-canvas FBO texture (per layer per square).
-- For hand-paint layers, strokes are baked here with material*layerColor already
-- composited in, so switching material later only affects FUTURE strokes.
local masks = {}
-- maskClearTex: tiny zeroed FBO used to clear newly-allocated masks (lazy)
local maskClearTex = nil

-- Layer record table; one starter built-in layer pre-populated in Initialize.
-- layer = { id, name, enabled, opacity, color={r,g,b}, blend (string),
--           altMin, altMax, altFalloffLo, altFalloffHi, altEnabled,
--           slopeMin, slopeMax, slopeFalloffLo, slopeFalloffHi, slopeEnabled,
--           handPaintEnabled }
local layers = {}
local activeLayerId = nil
local nextLayerId = 1

-- Material library catalog: array of { key, name, path, resK }
local materialLibrary = {}

-- Brush
local brushRadius        = DEFAULT_RADIUS
local brushStrength      = DEFAULT_STRENGTH
local brushCurve         = DEFAULT_CURVE
local eraseMode          = false
local brushFractalAmount = 0.0   -- 0 = no warp, 1 = maximum organic fractal edge
local brushFractalFreq   = 0.003 -- world-space fBm frequency (1/elmos)

-- Pen-pressure modulation (reuses WG.TerraformBrush pen-pressure system).
-- Returns (effRadius, effStrength) for the current frame. When pressure is
-- disabled or the WG API is missing, returns the raw brush values.
--
-- Painter convention (differs from TerraformBrush): full pressure == slider
-- value, light touch == small fraction. Scale ∈ [floor, 1] where floor keeps
-- the pen barely usable at 0 pressure. Sensitivity stretches the curve so
-- "medium" feels harder/lighter.
local PEN_RADIUS_FLOOR   = 0.25
local PEN_STRENGTH_FLOOR = 0.05
local _penDiagPrinted = false
local function getEffectiveBrush()
	local effRadius, effStrength = brushRadius, brushStrength
	local tfBrush = WG.TerraformBrush
	if not tfBrush or not tfBrush.getState then return effRadius, effStrength end
	local tbState = tfBrush.getState()
	if not tbState or not tbState.penPressureEnabled then return effRadius, effStrength end
	-- Pen not actually touching tablet (mouse click, hover, lifted pen) →
	-- pass through unmodulated. Without this, mouse-clicks paint at the
	-- 5% floor because pressureMapped reads as 0.
	if not tbState.penInContact then return effRadius, effStrength end
	local pressureMapped = tbState.penPressureMapped or tbState.penPressure or 1.0
	local sensitivity    = tbState.penPressureSensitivity or 1.0
	-- Stretch by sensitivity; clamp into [0,1].
	local pressure = pressureMapped * sensitivity
	if pressure < 0 then pressure = 0 elseif pressure > 1 then pressure = 1 end
	if not _penDiagPrinted then
		_penDiagPrinted = true
		Echo(string.format(
			"[Diffuse Painter] pen pressure ACTIVE: pm=%.3f sens=%.2f size=%s intensity=%s",
			pressureMapped, sensitivity, tostring(tbState.penPressureModulateSize), tostring(tbState.penPressureModulateIntensity)))
	end
	if tbState.penPressureModulateSize or tbState.penPressureModulateRadius then
		local factor = PEN_RADIUS_FLOOR + (1.0 - PEN_RADIUS_FLOOR) * pressure
		effRadius = max(MIN_RADIUS, min(MAX_RADIUS, floor(effRadius * factor + 0.5)))
	end
	if tbState.penPressureModulateIntensity then
		local factor = PEN_STRENGTH_FLOOR + (1.0 - PEN_STRENGTH_FLOOR) * pressure
		effStrength = max(MIN_STRENGTH, min(MAX_STRENGTH, effStrength * factor))
	end
	return effRadius, effStrength
end

-- Mouse drag
local leftMouseHeld = false
local lastPaintX, lastPaintZ = nil, nil

-- Deferred GL work (Draw call-in context required)
local pendingInit       = false
local pendingFullBake   = false  -- re-bake already-allocated squares
local pendingFullCover  = false  -- allocate every map square + bake (heavy)
local pendingPaintStrokes = {}   -- array of {wx, wz, layerId, erase}
local dirtySquares      = {}     -- squareKey -> true; consumed each Draw

-- Shaders
local compositorShader = nil
local stampShader      = nil
local copyShader       = nil

local uComp = {} -- uniform locations on compositorShader
local uStamp = {}

-- ============================================================================
-- Helpers
-- ============================================================================
local function squareKey(sx, sy) return sx * 1024 + sy end

local function getOrAllocSquare(sx, sy)
	if sx < 0 or sx >= numSqX or sy < 0 or sy >= numSqZ then return nil end
	local k = squareKey(sx, sy)
	local s = squares[k]
	if s then return s end
	s = { sx = sx, sy = sy, seedTex = nil, compositeTex = nil, bound = false, dirty = true }
	squares[k] = s
	return s
end

local function ensureLayerMaskTex(layerId, key)
	local layerMasks = masks[layerId]
	if not layerMasks then layerMasks = {}; masks[layerId] = layerMasks end
	local maskTex = layerMasks[key]
	if maskTex then return maskTex end
	maskTex = glCreateTexture(MASK_PX, MASK_PX, {
		border = false,
		min_filter = GL.LINEAR,
		mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
		fbo = true,
		format = GL.RGBA8,
	})
	if not maskTex then return nil end
	-- Clear to fully transparent (alpha=0 means "no paint here").
	glRenderToTexture(maskTex, function()
		glBlending(false)
		glColor(0, 0, 0, 0)
		glTexRect(-1, -1, 1, 1)
		glBlending(true)
	end)
	layerMasks[key] = maskTex
	return maskTex
end

local function getWorldMousePosition()
	local mx, my = GetMouseState()
	local _, pos = TraceScreenRay(mx, my, true)
	if pos then return pos[1], pos[3] end
	return nil, nil
end

local function findLayer(id)
	for i = 1, #layers do
		if layers[i].id == id then return layers[i], i end
	end
end

-- ============================================================================
-- Shaders
-- ============================================================================

local VERT_SRC = [[
	#version 130
	void main() {
		gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
		gl_TexCoord[0] = gl_MultiTexCoord0;
	}
]]

-- Stochastic non-tiling sampler (Inigo Quilez "Texture Repetition" technique
-- 3, simplified). Splits UV space into 1x1 macro-cells, each cell gets a
-- random offset + sign-flip (acts as random rotation/mirror per tile), and
-- the 4 neighboring cells are blended by smoothstep weights at the cell
-- boundaries. The result hides the underlying texture period without
-- introducing visible seams.
local FRACTAL_SAMPLE_GLSL = [[
	vec4 hash4(vec2 p) {
		p = vec2(dot(p, vec2(127.1, 311.7)),
		         dot(p, vec2(269.5, 183.3)));
		return fract(sin(vec4(p.x, p.y, p.x + p.y, p.x - p.y)) * 43758.5453);
	}
	vec3 sampleNoTile(sampler2D tex, vec2 uv) {
		vec2 iuv = floor(uv);
		vec2 fuv = fract(uv);
		vec4 ofa = hash4(iuv + vec2(0.0, 0.0));
		vec4 ofb = hash4(iuv + vec2(1.0, 0.0));
		vec4 ofc = hash4(iuv + vec2(0.0, 1.0));
		vec4 ofd = hash4(iuv + vec2(1.0, 1.0));
		// random per-cell sign flip (mirror) on uv coords for variety
		ofa.zw = sign(ofa.zw - 0.5);
		ofb.zw = sign(ofb.zw - 0.5);
		ofc.zw = sign(ofc.zw - 0.5);
		ofd.zw = sign(ofd.zw - 0.5);
		vec2 uva = uv * ofa.zw + ofa.xy;
		vec2 uvb = uv * ofb.zw + ofb.xy;
		vec2 uvc = uv * ofc.zw + ofc.xy;
		vec2 uvd = uv * ofd.zw + ofd.xy;
		// Narrow blend band (0.45..0.55) keeps each cell sharp; only a
		// thin seam shows the crossfade. Wider bands ghost the texture.
		vec2 b = smoothstep(0.45, 0.55, fuv);
		vec3 sa = texture2D(tex, uva).rgb;
		vec3 sb = texture2D(tex, uvb).rgb;
		vec3 sc = texture2D(tex, uvc).rgb;
		vec3 sd = texture2D(tex, uvd).rgb;
		return mix(mix(sa, sb, b.x), mix(sc, sd, b.x), b.y);
	}
]]

-- Compositor: 1 layer per pass. Reads compositeTex as input (start = seed),
-- samples layer mask + procedural masks, blends layer.color over input.
-- Supports blend modes: 0=Normal 1=Multiply 2=Screen 3=Overlay 4=SoftLight
--                       5=ColorDodge 6=HardLight 7=Difference
-- Hydro erosion mask: paints preferentially in concave valleys/channels.
-- Thermo erosion mask: paints at slope transitions near the repose angle.
local COMPOSITOR_FRAG_SRC = [[
	#version 130
	uniform sampler2D srcTex;      // current composite
	uniform sampler2D maskTex;     // per-layer hand-paint mask
	uniform sampler2D heightMap;   // engine $heightmap
	uniform sampler2D layerTex;    // optional tiled material diffuse
	uniform vec2  squareOrigin;    // world-space origin of this square (elmos)
	uniform vec2  squareSize;      // world-space size of this square (elmos)
	uniform vec2  mapSize;         // full map size (elmos)
	uniform vec3  layerColor;
	uniform float layerOpacity;
	uniform int   blendMode;       // 0=normal 1=multiply 2=screen 3=overlay 4=softlight 5=colordodge 6=hardlight 7=difference
	uniform int   useLayerTex;
	uniform float tileScale;       // world elmos per material UV tile
	// Altitude mask
	uniform int   altEnabled;
	uniform float altMin, altMax, altFalloffLo, altFalloffHi;
	// Slope mask
	uniform int   slopeEnabled;
	uniform float slopeMinCos;     // cos(maxAngle) — higher = flatter
	uniform float slopeMaxCos;     // cos(minAngle)
	uniform float slopeFalloffLo;  // in cos units
	uniform float slopeFalloffHi;
	// Hand paint
	uniform int   handPaintEnabled;
	// Hydro erosion (valley/channel affinity via heightmap concavity)
	uniform int   hydroEnabled;
	uniform float hydroStrength;   // scale: larger = more selective to valleys
	uniform float hydroFalloffLo;  // normalised flow at which painting starts
	uniform float hydroFalloffHi;  // normalised flow at full strength
	// Thermo erosion (talus / repose-angle zone)
	uniform int   thermoEnabled;
	uniform float thermoAngle;     // repose angle (degrees, e.g. 30)
	uniform float thermoFalloff;   // ± band width around repose angle (degrees)

	float smoothBand(float v, float lo, float hi, float fLo, float fHi) {
		float a = (fLo > 0.001) ? smoothstep(lo - fLo, lo, v) : step(lo, v);
		float b = (fHi > 0.001) ? (1.0 - smoothstep(hi, hi + fHi, v)) : step(v, hi);
		return clamp(a * b, 0.0, 1.0);
	}

	// Photoshop-style blend: base = existing layer, blend = incoming colour.
	vec3 blendColors(int mode, vec3 base, vec3 blend) {
		if (mode == 0) return blend;                                              // Normal
		if (mode == 1) return base * blend;                                       // Multiply
		if (mode == 2) return base + blend - base * blend;                        // Screen
		if (mode == 3) return mix(2.0*base*blend,                                 // Overlay
		                          1.0 - 2.0*(1.0-base)*(1.0-blend),
		                          step(vec3(0.5), base));
		if (mode == 4) return mix(                                                // Soft Light
		                    2.0*base*blend + base*base*(1.0-2.0*blend),
		                    sqrt(clamp(base,0.0001,1.0))*(2.0*blend-1.0) + 2.0*base*(1.0-blend),
		                    step(vec3(0.5), blend));
		if (mode == 5) return clamp(base / max(1.0-blend, vec3(0.001)), 0.0, 1.4); // Color Dodge
		if (mode == 6) return mix(2.0*base*blend,                                 // Hard Light
		                          1.0 - 2.0*(1.0-base)*(1.0-blend),
		                          step(vec3(0.5), blend));
		if (mode == 7) return abs(base - blend);                                  // Difference
		return blend;
	}

	void main() {
		vec2 localUV = gl_TexCoord[0].st;
		vec2 worldXZ = squareOrigin + localUV * squareSize;
		vec4 src = texture2D(srcTex, localUV);

		// Hand-paint: colour already baked at stroke time; just blend with mode.
		if (handPaintEnabled == 1) {
			vec4 paint = texture2D(maskTex, localUV);
			float pa = clamp(paint.a * layerOpacity, 0.0, 1.0);
			// paint.rgb is premultiplied (stored as color * alpha by the stamp shader).
			// De-premultiply to recover the actual deposited colour before blending,
			// otherwise the deposit contribution is paint.a² instead of paint.a.
			vec3 paintColor = (paint.a > 0.001) ? paint.rgb / paint.a : vec3(0.0);
			vec3 bl = blendColors(blendMode, src.rgb, paintColor);
			gl_FragColor = vec4(mix(src.rgb, bl, pa), 1.0);
			return;
		}

		float m = 1.0;

		// Shared heightmap samples (one tap for alt, four more for gradients).
		vec2 hmTexel = 1.0 / vec2(textureSize(heightMap, 0));
		vec2 uvCtr   = worldXZ / mapSize;
		vec2 cellSz  = mapSize * hmTexel;

		if (altEnabled == 1 || slopeEnabled == 1 || hydroEnabled == 1 || thermoEnabled == 1) {
			float hC = texture2D(heightMap, uvCtr).x;
			float hL = texture2D(heightMap, uvCtr + vec2(-hmTexel.x, 0.0)).x;
			float hR = texture2D(heightMap, uvCtr + vec2( hmTexel.x, 0.0)).x;
			float hD = texture2D(heightMap, uvCtr + vec2(0.0, -hmTexel.y)).x;
			float hU = texture2D(heightMap, uvCtr + vec2(0.0,  hmTexel.y)).x;

			if (altEnabled == 1) {
				m *= smoothBand(hC, altMin, altMax, altFalloffLo, altFalloffHi);
			}

			if (slopeEnabled == 1) {
				vec3 nrm = normalize(vec3(hL - hR, 2.0 * cellSz.x, hD - hU));
				m *= smoothBand(nrm.y, slopeMinCos, slopeMaxCos, slopeFalloffLo, slopeFalloffHi);
			}

			if (hydroEnabled == 1) {
				// Positive Laplacian = concave = valley/channel = high flow.
				float lap  = hL + hR + hD + hU - 4.0 * hC;
				float flow = clamp(lap * hydroStrength, 0.0, 1.0);
				float hfHi = max(hydroFalloffHi, hydroFalloffLo + 0.001);
				m *= smoothstep(hydroFalloffLo, hfHi, flow);
			}

			if (thermoEnabled == 1) {
				// Surface normal → slope angle in degrees.
				vec3 nrmT = normalize(vec3(hL - hR, 2.0 * cellSz.x, hD - hU));
				float slopeAngleDeg = acos(clamp(nrmT.y, 0.0, 1.0)) * (180.0 / 3.14159265);
				float tFall = max(thermoFalloff, 0.5);
				float tLo   = max(0.0, thermoAngle - tFall);
				float tHi   = thermoAngle + tFall;
				float tMask = smoothBand(slopeAngleDeg, tLo, tHi, tFall, tFall);
				// Weight by steepness of uphill source terrain (6-texel radius).
				vec2 grad2d = vec2(hR - hL, hU - hD);
				float gLen  = length(grad2d);
				float steep = 0.0;
				if (gLen > 0.0001) {
					vec2 upDir = (grad2d / gLen) * hmTexel * 6.0;
					vec2 upUV  = clamp(uvCtr + upDir, vec2(0.001), vec2(0.999));
					float hUp  = texture2D(heightMap, upUV).x;
					float rise = hUp - hC;
					float run  = length((grad2d / gLen) * cellSz * 6.0);
					float upAng = atan(rise / max(run, 0.001)) * (180.0 / 3.14159265);
					steep = clamp(upAng / 45.0, 0.0, 1.0);
				}
				m *= tMask * steep;
			}
		}

		float a = clamp(m * layerOpacity, 0.0, 1.0);
		vec3 layerRGB = layerColor;
		if (useLayerTex == 1) {
			vec2 tileUV = worldXZ / max(tileScale, 1.0);
			layerRGB = sampleNoTile(layerTex, tileUV) * layerColor;
		}
		vec3 blended = blendColors(blendMode, src.rgb, layerRGB);
		vec3 outRGB  = mix(src.rgb, blended, a);
		gl_FragColor = vec4(outRGB, 1.0);
	}
]]

-- Brush stamp into a per-layer RGBA canvas. The shader samples the current
-- material texture (if any) at world UV / tileScale, multiplies by layerColor,
-- and blends it over the canvas using brush alpha. This way the deposited RGB
-- is fully baked at stroke time — switching material later only affects FUTURE
-- strokes. Erase reduces canvas alpha to fade the paint.
-- fractalAmount > 0 applies fBm domain-warp to create organic/fractal edges.
local STAMP_FRAG_SRC = [[
	#version 130
	uniform sampler2D srcMask;     // current RGBA canvas
	uniform sampler2D layerTex;    // material diffuse (bound to a 1x1 white fallback if no path)
	uniform sampler2D normalTex;   // material normal (nor_gl); used iff useNormalTex==1
	uniform sampler2D roughTex;    // material roughness; used iff useRoughTex==1
	uniform vec2  squareOrigin;
	uniform vec2  squareSize;
	uniform vec2  brushPos;
	uniform float brushRadius;
	uniform float brushStrength;
	uniform float brushCurve;
	uniform int   brushErase;
	uniform int   useLayerTex;
	uniform int   useNormalTex;
	uniform int   useRoughTex;
	uniform float tileScale;
	uniform float pbrStrength;     // 0 = no shading bake; ~1.0 = strong
	uniform vec3  layerColor;
	uniform float fractalAmount;   // 0 = off, 0-1 = brush-edge fBm warp strength
	uniform float fractalFreq;     // world-space fBm frequency (1/elmos)

	float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

	// Value-noise fBm for organic brush-edge warping
	float hfh(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
	float hfn(vec2 p) {
		vec2 i = floor(p), f = fract(p);
		vec2 u = f * f * (3.0 - 2.0 * f);
		return mix(mix(hfh(i), hfh(i+vec2(1.0,0.0)), u.x),
		           mix(hfh(i+vec2(0.0,1.0)), hfh(i+vec2(1.0,1.0)), u.x), u.y) * 2.0 - 1.0;
	}
	float hffbm(vec2 p) {
		float v = 0.0;
		v += 0.500 * hfn(p); p *= 2.13;
		v += 0.225 * hfn(p); p *= 2.13;
		v += 0.101 * hfn(p); p *= 2.13;
		v += 0.045 * hfn(p);
		return v;
	}

	void main() {
		vec2 uv    = gl_TexCoord[0].st;
		vec2 world = squareOrigin + uv * squareSize;

		// Domain-warp world position to produce fractal / organic brush edges.
		if (fractalAmount > 0.001) {
			float wx = hffbm(world * fractalFreq + vec2(31.4, 57.2));
			float wy = hffbm(world * fractalFreq + vec2(89.7, 23.1));
			world += vec2(wx, wy) * brushRadius * fractalAmount;
		}

		vec2  d = world - brushPos;
		float r = length(d) / brushRadius;
		vec4 current = texture2D(srcMask, uv);
		if (r >= 1.0) { gl_FragColor = current; return; }
		float fall   = 1.0 - pow(r, brushCurve);
		float amount = clamp(brushStrength * fall, 0.0, 1.0);
		if (brushErase == 1) {
			float newA = max(0.0, current.a - amount);
			gl_FragColor = vec4(current.rgb, newA);
			return;
		}
		vec3 deposit = layerColor;
		vec2 tileUV  = world / max(tileScale, 1.0);
		if (useLayerTex == 1) {
			deposit = sampleNoTile(layerTex, tileUV) * layerColor;
		}
		// Faux PBR shading bake. Engine API only takes diffuse, so we bake
		// directional light + crevice AO + bump-from-luminance + specular
		// highlight into RGB.
		if (pbrStrength > 0.001) {
			// Build a normal: prefer real normal map, else derive from diffuse
			// luminance gradient at multiple scales (free pseudo-bump).
			vec3 N;
			if (useNormalTex == 1) {
				vec3 nm = sampleNoTile(normalTex, tileUV) * 2.0 - 1.0;
				N = normalize(vec3(nm.x, nm.y, max(nm.z, 0.05)));
			} else if (useLayerTex == 1) {
				// Gradient must use PLAIN texture() (not sampleNoTile) — the
				// no-tile sampler randomizes per-cell so neighbor taps would
				// cross random offsets and produce pure noise.
				float tx = 1.0 / max(tileScale, 1.0);
				float cL = luma(texture(layerTex, tileUV - vec2(tx, 0.0)).rgb);
				float cR = luma(texture(layerTex, tileUV + vec2(tx, 0.0)).rgb);
				float cD = luma(texture(layerTex, tileUV - vec2(0.0, tx)).rgb);
				float cU = luma(texture(layerTex, tileUV + vec2(0.0, tx)).rgb);
				float gx = (cR - cL) * 5.0;
				float gy = (cU - cD) * 5.0;
				N = normalize(vec3(-gx, -gy, 1.0));
			} else {
				N = vec3(0.0, 0.0, 1.0);
			}
			float rough = 0.55;
			if (useRoughTex == 1) {
				rough = clamp(sampleNoTile(roughTex, tileUV).r, 0.0, 1.0);
			} else if (useLayerTex == 1) {
				// Approximate roughness from diffuse luma: darker -> rougher.
				rough = clamp(1.0 - luma(deposit), 0.25, 0.85);
			}
			vec3 L = normalize(vec3(0.35, 0.45, 0.82));
			vec3 V = vec3(0.0, 0.0, 1.0);          // top-down view
			vec3 H = normalize(L + V);
			float lambert = clamp(dot(N, L), 0.0, 1.0);
			float ao = mix(0.55, 1.0, N.z);         // gentle crevice darkening
			float shade = (0.45 + 0.75 * lambert) * ao;
			// Specular highlight: Blinn-Phong, gated by (1 - rough).
			float specExp = mix(12.0, 48.0, 1.0 - rough);
			float specTerm = pow(clamp(dot(N, H), 0.0, 1.0), specExp);
			float specStrength = mix(0.02, 0.18, 1.0 - rough);
			// Mild contrast pump.
			float lum = luma(deposit);
			float contrast = mix(0.88, 1.12, smoothstep(0.0, 1.0, lum));
			shade *= contrast;
			shade = mix(1.0, shade, pbrStrength);
			deposit *= clamp(shade, 0.0, 1.6);
			deposit += vec3(specTerm * specStrength * pbrStrength);
			deposit = clamp(deposit, 0.0, 1.4);
		}
		float newA  = current.a + (1.0 - current.a) * amount;
		vec3 newRGB = mix(current.rgb, deposit, amount);
		gl_FragColor = vec4(newRGB, clamp(newA, 0.0, 1.0));
	}
]]

local COPY_FRAG_SRC = [[
	#version 130
	uniform sampler2D tex0;
	void main() { gl_FragColor = texture2D(tex0, gl_TexCoord[0].st); }
]]

local function createShaders()
	local function injectFractal(src)
		return (src:gsub("(#version%s+%d+%s*\n)", "%1" .. FRACTAL_SAMPLE_GLSL .. "\n", 1))
	end
	compositorShader = glCreateShader({
		vertex = VERT_SRC, fragment = injectFractal(COMPOSITOR_FRAG_SRC),
		uniformInt = { srcTex = 0, maskTex = 1, heightMap = 2, layerTex = 3 },
	})
	if not compositorShader then
		Echo("[Diffuse Painter] compositor shader failed: " .. tostring(gl.GetShaderLog())); return false
	end
	uComp.squareOrigin     = glGetUniformLocation(compositorShader, "squareOrigin")
	uComp.squareSize       = glGetUniformLocation(compositorShader, "squareSize")
	uComp.mapSize          = glGetUniformLocation(compositorShader, "mapSize")
	uComp.layerColor       = glGetUniformLocation(compositorShader, "layerColor")
	uComp.layerOpacity     = glGetUniformLocation(compositorShader, "layerOpacity")
	uComp.blendMode        = glGetUniformLocation(compositorShader, "blendMode")
	uComp.altEnabled       = glGetUniformLocation(compositorShader, "altEnabled")
	uComp.altMin           = glGetUniformLocation(compositorShader, "altMin")
	uComp.altMax           = glGetUniformLocation(compositorShader, "altMax")
	uComp.altFalloffLo     = glGetUniformLocation(compositorShader, "altFalloffLo")
	uComp.altFalloffHi     = glGetUniformLocation(compositorShader, "altFalloffHi")
	uComp.slopeEnabled     = glGetUniformLocation(compositorShader, "slopeEnabled")
	uComp.slopeMinCos      = glGetUniformLocation(compositorShader, "slopeMinCos")
	uComp.slopeMaxCos      = glGetUniformLocation(compositorShader, "slopeMaxCos")
	uComp.slopeFalloffLo   = glGetUniformLocation(compositorShader, "slopeFalloffLo")
	uComp.slopeFalloffHi   = glGetUniformLocation(compositorShader, "slopeFalloffHi")
	uComp.handPaintEnabled = glGetUniformLocation(compositorShader, "handPaintEnabled")
	uComp.useLayerTex      = glGetUniformLocation(compositorShader, "useLayerTex")
	uComp.tileScale        = glGetUniformLocation(compositorShader, "tileScale")
	uComp.hydroEnabled     = glGetUniformLocation(compositorShader, "hydroEnabled")
	uComp.hydroStrength    = glGetUniformLocation(compositorShader, "hydroStrength")
	uComp.hydroFalloffLo   = glGetUniformLocation(compositorShader, "hydroFalloffLo")
	uComp.hydroFalloffHi   = glGetUniformLocation(compositorShader, "hydroFalloffHi")
	uComp.thermoEnabled    = glGetUniformLocation(compositorShader, "thermoEnabled")
	uComp.thermoAngle      = glGetUniformLocation(compositorShader, "thermoAngle")
	uComp.thermoFalloff    = glGetUniformLocation(compositorShader, "thermoFalloff")

	stampShader = glCreateShader({
		vertex = VERT_SRC, fragment = injectFractal(STAMP_FRAG_SRC),
		uniformInt = { srcMask = 0, layerTex = 1, normalTex = 2, roughTex = 3 },
	})
	if not stampShader then
		Echo("[Diffuse Painter] stamp shader failed: " .. tostring(gl.GetShaderLog())); return false
	end
	uStamp.squareOrigin  = glGetUniformLocation(stampShader, "squareOrigin")
	uStamp.squareSize    = glGetUniformLocation(stampShader, "squareSize")
	uStamp.brushPos      = glGetUniformLocation(stampShader, "brushPos")
	uStamp.brushRadius   = glGetUniformLocation(stampShader, "brushRadius")
	uStamp.brushStrength = glGetUniformLocation(stampShader, "brushStrength")
	uStamp.brushCurve    = glGetUniformLocation(stampShader, "brushCurve")
	uStamp.brushErase    = glGetUniformLocation(stampShader, "brushErase")
	uStamp.useLayerTex   = glGetUniformLocation(stampShader, "useLayerTex")
	uStamp.tileScale     = glGetUniformLocation(stampShader, "tileScale")
	uStamp.layerColor    = glGetUniformLocation(stampShader, "layerColor")
	uStamp.useNormalTex  = glGetUniformLocation(stampShader, "useNormalTex")
	uStamp.useRoughTex   = glGetUniformLocation(stampShader, "useRoughTex")
	uStamp.pbrStrength   = glGetUniformLocation(stampShader, "pbrStrength")
	uStamp.fractalAmount = glGetUniformLocation(stampShader, "fractalAmount")
	uStamp.fractalFreq   = glGetUniformLocation(stampShader, "fractalFreq")

	copyShader = glCreateShader({
		vertex = VERT_SRC, fragment = COPY_FRAG_SRC,
		uniformInt = { tex0 = 0 },
	})
	if not copyShader then
		Echo("[Diffuse Painter] copy shader failed: " .. tostring(gl.GetShaderLog())); return false
	end

	return true
end

local function destroyShaders()
	if compositorShader then glDeleteShader(compositorShader); compositorShader = nil end
	if stampShader      then glDeleteShader(stampShader);      stampShader      = nil end
	if copyShader       then glDeleteShader(copyShader);       copyShader       = nil end
end

-- ============================================================================
-- Square texture allocation + seeding
-- ============================================================================
local function allocateSquare(s)
	if s.seedTex and s.compositeTex then return true end

	local seedTex = glCreateTexture(TILE_PX, TILE_PX, {
		border = false,
		min_filter = GL.LINEAR,
		mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
		fbo = false,
		format = GL.RGBA8,
	})
	if not seedTex then
		Echo("[Diffuse Painter] failed to create seed tex for square " .. s.sx .. "," .. s.sy)
		return false
	end

	-- Ask engine to copy its current diffuse for this square into the seed tex
	local ok = GetMapSquareTextureFn(s.sx, s.sy, 0, seedTex, 0)
	if not ok then
		Echo("[Diffuse Painter] GetMapSquareTexture failed for " .. s.sx .. "," .. s.sy)
		glDeleteTexture(seedTex)
		return false
	end

	local compositeTex = glCreateTexture(TILE_PX, TILE_PX, {
		border = false,
		min_filter = GL.LINEAR,
		mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
		fbo = true,
		format = GL.RGBA8,
	})
	if not compositeTex then
		glDeleteTexture(seedTex)
		Echo("[Diffuse Painter] failed to create composite tex for " .. s.sx .. "," .. s.sy)
		return false
	end

	-- Initialize composite = seed (so unpainted look identical to engine)
	glRenderToTexture(compositeTex, function()
		glBlending(false)
		glUseShader(copyShader)
		glTexture(0, seedTex)
		glTexRect(-1, -1, 1, 1, 0, 0, 1, 1)
		glTexture(0, false)
		glUseShader(0)
		glBlending(true)
	end)

	s.seedTex = seedTex
	s.compositeTex = compositeTex
	s.dirty = true
	return true
end

local function bindSquare(s)
	if s.bound or not s.compositeTex then return end
	local ok = SetMapSquareTexture(s.sx, s.sy, s.compositeTex)
	if ok then
		s.bound = true
	else
		Echo("[Diffuse Painter] SetMapSquareTexture failed for " .. s.sx .. "," .. s.sy)
	end
end

local function unbindAllSquares()
	for _, s in pairs(squares) do
		if s.bound then
			SetMapSquareTexture(s.sx, s.sy, "")
			s.bound = false
		end
	end
end

local function freeSquare(s)
	if s.bound then
		SetMapSquareTexture(s.sx, s.sy, "")
		s.bound = false
	end
	if s.compositeTex then glDeleteTexture(s.compositeTex); s.compositeTex = nil end
	if s.seedTex      then glDeleteTexture(s.seedTex);      s.seedTex      = nil end
end

-- ============================================================================
-- Compositor pass — bakes one square from seed through all enabled layers
-- ============================================================================
local function bakeSquare(s)
	if not s or not s.compositeTex or not s.seedTex then return end
	if not compositorShader then return end

	-- Start by copying seed -> composite
	glRenderToTexture(s.compositeTex, function()
		glBlending(false)
		glUseShader(copyShader)
		glTexture(0, s.seedTex)
		glTexRect(-1, -1, 1, 1, 0, 0, 1, 1)
		glTexture(0, false)
		glUseShader(0)
		glBlending(true)
	end)

	-- Ping-pong buffer: render composite -> temp using compositor, then copy back.
	-- One temp per square per bake. Cheap (1024^2 RGBA8 ~4MB live).
	local key = squareKey(s.sx, s.sy)
	local squareOriginX = s.sx * SQUARE_SIZE_ELMOS
	local squareOriginZ = s.sy * SQUARE_SIZE_ELMOS

	for li = 1, #layers do
		local layer = layers[li]
		if layer.enabled and (layer.opacity or 0) > 0.001 then
			local maskTex = nil
			if layer.handPaintEnabled then
				maskTex = ensureLayerMaskTex(layer.id, key)
			end

			local tempTex = glCreateTexture(TILE_PX, TILE_PX, {
				border = false, min_filter = GL.LINEAR, mag_filter = GL.LINEAR,
				wrap_s = GL.CLAMP_TO_EDGE, wrap_t = GL.CLAMP_TO_EDGE,
				fbo = true, format = GL.RGBA8,
			})
			if tempTex then
				glRenderToTexture(tempTex, function()
					glBlending(false)
					glUseShader(compositorShader)
					glTexture(0, s.compositeTex)
					if maskTex then glTexture(1, maskTex) else glTexture(1, "$heightmap") end
					glTexture(2, "$heightmap")
					local useTex = false
					if layer.texturePath and layer.texturePath ~= "" then
						local ok = pcall(glTexture, 3, layer.texturePath)
						useTex = ok and true or false
					end
					if not useTex then glTexture(3, "$heightmap") end
					glUniformInt(uComp.useLayerTex, useTex and 1 or 0)
					glUniform(uComp.tileScale, layer.tileScale or 384)

					glUniform(uComp.squareOrigin, squareOriginX, squareOriginZ)
					glUniform(uComp.squareSize, SQUARE_SIZE_ELMOS, SQUARE_SIZE_ELMOS)
					glUniform(uComp.mapSize, mapSizeX, mapSizeZ)
					glUniform(uComp.layerColor, layer.color[1], layer.color[2], layer.color[3])
					glUniform(uComp.layerOpacity, layer.opacity)
					local blendModeIdx = ({ normal=0, multiply=1, screen=2, overlay=3,
					                        softlight=4, colordodge=5, hardlight=6, difference=7 })[layer.blend or "normal"] or 0
					glUniformInt(uComp.blendMode, blendModeIdx)
					glUniformInt(uComp.altEnabled, layer.altEnabled and 1 or 0)
					glUniform(uComp.altMin, layer.altMin)
					glUniform(uComp.altMax, layer.altMax)
					glUniform(uComp.altFalloffLo, layer.altFalloffLo)
					glUniform(uComp.altFalloffHi, layer.altFalloffHi)
					glUniformInt(uComp.slopeEnabled, layer.slopeEnabled and 1 or 0)
					-- slope params: layer.slopeMin/Max are degrees; convert to cos.
					-- A "small angle" (flat) has large cos; "large angle" (steep) has small cos.
					-- Layer says "apply between slopeMin..slopeMax degrees", so in cos space
					-- the valid band is [cos(slopeMax), cos(slopeMin)].
					local cosLo = cos(layer.slopeMax * pi / 180)
					local cosHi = cos(layer.slopeMin * pi / 180)
					glUniform(uComp.slopeMinCos, cosLo)
					glUniform(uComp.slopeMaxCos, cosHi)
					-- Falloff in cos units derived from degree falloff at the band edges
					local fLo = abs(cos((layer.slopeMax - (layer.slopeFalloffLo or 0)) * pi / 180) - cosLo)
					local fHi = abs(cos((layer.slopeMin + (layer.slopeFalloffHi or 0)) * pi / 180) - cosHi)
					glUniform(uComp.slopeFalloffLo, fLo)
					glUniform(uComp.slopeFalloffHi, fHi)
					glUniformInt(uComp.handPaintEnabled, (layer.handPaintEnabled and maskTex) and 1 or 0)
					-- Hydro erosion mask
					glUniformInt(uComp.hydroEnabled, layer.hydroEnabled and 1 or 0)
					glUniform(uComp.hydroStrength, layer.hydroStrength or 0.02)
					glUniform(uComp.hydroFalloffLo, layer.hydroFalloffLo or 0.1)
					glUniform(uComp.hydroFalloffHi, layer.hydroFalloffHi or 0.6)
					-- Thermo erosion mask
					glUniformInt(uComp.thermoEnabled, layer.thermoEnabled and 1 or 0)
					glUniform(uComp.thermoAngle, layer.thermoAngle or 30.0)
					glUniform(uComp.thermoFalloff, layer.thermoFalloff or 8.0)

					glTexRect(-1, -1, 1, 1, 0, 0, 1, 1)

					glTexture(3, false); glTexture(2, false); glTexture(1, false); glTexture(0, false)
					glUseShader(0)
					glBlending(true)
				end)

				-- Copy temp back into composite
				glRenderToTexture(s.compositeTex, function()
					glBlending(false)
					glUseShader(copyShader)
					glTexture(0, tempTex)
					glTexRect(-1, -1, 1, 1, 0, 0, 1, 1)
					glTexture(0, false)
					glUseShader(0)
					glBlending(true)
				end)

				glDeleteTexture(tempTex)
			end
		end
	end

	s.dirty = false
	if not s.bound then bindSquare(s) end
end

-- ============================================================================
-- Brush: stamp into active layer mask for all affected squares
-- ============================================================================
local function affectedSquares(wx, wz, r)
	local out = {}
	local sx0 = floor((wx - r) / SQUARE_SIZE_ELMOS)
	local sx1 = floor((wx + r) / SQUARE_SIZE_ELMOS)
	local sy0 = floor((wz - r) / SQUARE_SIZE_ELMOS)
	local sy1 = floor((wz + r) / SQUARE_SIZE_ELMOS)
	for sx = sx0, sx1 do
		for sy = sy0, sy1 do
			if sx >= 0 and sx < numSqX and sy >= 0 and sy < numSqZ then
				out[#out + 1] = { sx, sy }
			end
		end
	end
	return out
end

local function executeStroke(wx, wz, layerId, erase)
	if not stampShader then return end
	local layer = findLayer(layerId)
	if not layer then return end
	-- Force hand-paint to be considered enabled for the duration of this layer
	-- if the brush is being used (otherwise stamping has no visible effect).
	layer.handPaintEnabled = true

	local effR, effS = getEffectiveBrush()
	local affected = affectedSquares(wx, wz, effR)
	for i = 1, #affected do
		local sx, sy = affected[i][1], affected[i][2]
		local s = getOrAllocSquare(sx, sy)
		if s then
			if not s.seedTex then allocateSquare(s) end
			local key = squareKey(sx, sy)
			local maskTex = ensureLayerMaskTex(layerId, key)
			if maskTex then
				-- Ping-pong stamp: write to temp, copy back
				local tempMask = glCreateTexture(MASK_PX, MASK_PX, {
					border = false, min_filter = GL.LINEAR, mag_filter = GL.LINEAR,
					wrap_s = GL.CLAMP_TO_EDGE, wrap_t = GL.CLAMP_TO_EDGE,
					fbo = true, format = GL.RGBA8,
				})
				if tempMask then
					local squareOriginX = sx * SQUARE_SIZE_ELMOS
					local squareOriginZ = sy * SQUARE_SIZE_ELMOS
					-- Bind material textures to units 1/2/3 with safe fallbacks.
					local useTex = false
					if layer.texturePath and layer.texturePath ~= "" then
						local ok = pcall(glTexture, 1, layer.texturePath)
						useTex = ok and true or false
					end
					if not useTex then glTexture(1, "$heightmap") end
					local useNormal = false
					if layer.normalPath and layer.normalPath ~= "" then
						local okN = pcall(glTexture, 2, layer.normalPath)
						useNormal = okN and true or false
					end
					if not useNormal then glTexture(2, "$heightmap") end
					local useRough = false
					if layer.roughPath and layer.roughPath ~= "" then
						local okR = pcall(glTexture, 3, layer.roughPath)
						useRough = okR and true or false
					end
					if not useRough then glTexture(3, "$heightmap") end
					if not layer._pbrLogged then
						layer._pbrLogged = true
						Echo(string.format(
							"[Diffuse Painter] layer '%s' PBR: diff=%s normal=%s(%s) rough=%s(%s)",
							tostring(layer.name), tostring(useTex),
							tostring(useNormal), tostring(layer.normalPath or "-"),
							tostring(useRough),  tostring(layer.roughPath  or "-")))
					end
					glRenderToTexture(tempMask, function()
						glBlending(false)
						glUseShader(stampShader)
						glTexture(0, maskTex)
						glUniform(uStamp.squareOrigin, squareOriginX, squareOriginZ)
						glUniform(uStamp.squareSize, SQUARE_SIZE_ELMOS, SQUARE_SIZE_ELMOS)
						glUniform(uStamp.brushPos, wx, wz)
						glUniform(uStamp.brushRadius, effR)
						glUniform(uStamp.brushStrength, effS)
						glUniform(uStamp.brushCurve, brushCurve)
						glUniformInt(uStamp.brushErase, erase and 1 or 0)
						glUniformInt(uStamp.useLayerTex, useTex and 1 or 0)
						glUniformInt(uStamp.useNormalTex, useNormal and 1 or 0)
						glUniformInt(uStamp.useRoughTex, useRough and 1 or 0)
						glUniform(uStamp.tileScale, layer.tileScale or 384)
						glUniform(uStamp.pbrStrength, layer.pbrStrength or 1.0)
						glUniform(uStamp.layerColor, layer.color[1], layer.color[2], layer.color[3])
						glUniform(uStamp.fractalAmount, brushFractalAmount)
						glUniform(uStamp.fractalFreq,   brushFractalFreq)
						glTexRect(-1, -1, 1, 1, 0, 0, 1, 1)
						glTexture(0, false)
						glUseShader(0)
						glBlending(true)
					end)
					glTexture(3, false)
					glTexture(2, false)
					glTexture(1, false)
					-- Copy back
					glRenderToTexture(maskTex, function()
						glBlending(false)
						glUseShader(copyShader)
						glTexture(0, tempMask)
						glTexRect(-1, -1, 1, 1, 0, 0, 1, 1)
						glTexture(0, false)
						glUseShader(0)
						glBlending(true)
					end)
					glDeleteTexture(tempMask)
				end
				dirtySquares[key] = true
			end
		end
	end
end

-- ============================================================================
-- Layer management
-- ============================================================================
local function defaultLayer(name, r, g, b)
	return {
		id = 0, name = name or "Layer",
		enabled = true, opacity = 1.0,
		color = { r or 1, g or 1, b or 1 }, blend = "normal",
		altEnabled = false, altMin = 0, altMax = 200, altFalloffLo = 10, altFalloffHi = 10,
		slopeEnabled = false, slopeMin = 0, slopeMax = 30, slopeFalloffLo = 3, slopeFalloffHi = 3,
		handPaintEnabled = false,
		texturePath = nil, tileScale = 384,
		-- Hydro erosion: paint preferentially in concave valleys / flow channels
		hydroEnabled = false, hydroStrength = 0.02,
		hydroFalloffLo = 0.1, hydroFalloffHi = 0.6,
		-- Thermo erosion: paint at slope transitions near the repose angle
		thermoEnabled = false, thermoAngle = 30.0, thermoFalloff = 8.0,
	}
end

local function addLayer(layerDef)
	if #layers >= MAX_LAYERS then
		Echo("[Diffuse Painter] layer cap reached (" .. MAX_LAYERS .. ")")
		return nil
	end
	local layer = defaultLayer()
	if layerDef then
		for k, v in pairs(layerDef) do layer[k] = v end
	end
	layer.id = nextLayerId
	nextLayerId = nextLayerId + 1
	layers[#layers + 1] = layer
	if not activeLayerId then activeLayerId = layer.id end
	pendingFullBake = true
	return layer.id
end

local function removeLayer(id)
	local _, idx = findLayer(id)
	if not idx then return end
	table.remove(layers, idx)
	-- Free that layer's masks
	if masks[id] then
		for _, maskTex in pairs(masks[id]) do glDeleteTexture(maskTex) end
		masks[id] = nil
	end
	if activeLayerId == id then activeLayerId = layers[1] and layers[1].id or nil end
	pendingFullBake = true
end

local function setLayerParam(id, key, val)
	local layer = findLayer(id)
	if not layer then return end
	layer[key] = val
	pendingFullBake = true
end

local function findSibling(diffPath, channel)
	-- Replace `_diff_` with `_<channel>_` and probe likely extensions.
	local exts
	if channel == "nor_gl" then exts = { "exr", "jpg", "png" }
	elseif channel == "rough" then exts = { "jpg", "exr", "png" }
	elseif channel == "disp" then exts = { "png", "exr", "jpg" }
	else exts = { "jpg", "png", "exr" } end
	local stem = diffPath:gsub("_diff_(%d+k)%.jpg$", "_" .. channel .. "_%1.")
	for i = 1, #exts do
		local candidate = stem .. exts[i]
		if VFS.FileExists and VFS.FileExists(candidate, VFS.RAW_FIRST) then
			return candidate
		end
	end
	return nil
end

local function scanMaterialLibrary()
	materialLibrary = {}
	local ROOT = "luaui/images/terraform_brush/textures/"
	local byKey = {} -- prefer lowest-resolution diffuse per material key

	-- Diffuse textures may sit at any depth under ROOT (the source packs nest
	-- them in `<pack>.blend/textures/textures/`), so walk the tree explicitly
	-- rather than relying on a recursive DirList flag that not every engine
	-- build honours. Bounded depth guards against symlink/loop surprises.
	local function consume(files)
		for _, f in ipairs(files or {}) do
			local base = f:gsub("^.*/", "")
			-- Parse: <name>_diff_<NK>.jpg
			local mat, res = base:match("^(.-)_diff_(%d+)k%.jpg$")
			if mat and res then
				local resK = tonumber(res) or 8
				local prev = byKey[mat]
				if (not prev) or resK < prev.resK then
					byKey[mat] = {
						key = mat, name = mat:gsub("_", " "), path = f, resK = resK,
						normalPath = findSibling(f, "nor_gl"),
						roughPath  = findSibling(f, "rough"),
						dispPath   = findSibling(f, "disp"),
					}
				end
			end
		end
	end

	local function walk(dir, depth)
		if depth > 8 then return end
		consume(VFS.DirList and VFS.DirList(dir, "*_diff_*k.jpg", VFS.RAW_FIRST) or {})
		for _, sub in ipairs((VFS.SubDirs and VFS.SubDirs(dir, "*", VFS.RAW_FIRST)) or {}) do
			walk(sub, depth + 1)
		end
	end
	walk(ROOT, 0)

	for _, v in pairs(byKey) do materialLibrary[#materialLibrary + 1] = v end
	table.sort(materialLibrary, function(a, b) return a.key < b.key end)
end

local function findMaterialByPath(p)
	if not p then return nil end
	for i = 1, #materialLibrary do
		if materialLibrary[i].path == p then return materialLibrary[i] end
	end
	return nil
end

local function setLayerTexture(id, path, tileScale, name)
	local layer = findLayer(id)
	if not layer then return end
	if path == "" then path = nil end
	layer.texturePath = path
	if tileScale then layer.tileScale = tileScale end
	-- Look up PBR siblings from the material library for the stamp shader.
	local mat = findMaterialByPath(path)
	layer.normalPath = mat and mat.normalPath or nil
	layer.roughPath  = mat and mat.roughPath  or nil
	layer.dispPath   = mat and mat.dispPath   or nil
	-- Auto-name the layer after the material when we have one. Keeps the
	-- LAYERS list readable ("snow 01", "rock face 03") instead of generic
	-- "Layer N" placeholders. User-renamed layers are preserved via the
	-- `customName` flag (set if the caller renames explicitly later).
	if name and not layer.customName then
		layer.name = name
	end
	-- Hand-paint layers bake material at stroke time, so changing the active
	-- material must NOT rebake the canvas — only future strokes use the new
	-- texture. Procedural layers do sample texturePath in the compositor and
	-- therefore need a re-bake.
	if not layer.handPaintEnabled then
		pendingFullBake = true
	end
end

local function addLayerFromMaterial(path, name)
	local id = addLayer({
		name = name or "Layer",
		color = { 1.0, 1.0, 1.0 },
		handPaintEnabled = true,
		enabled = true,
		opacity = 1.0,
		texturePath = path,
	})
	if id then activeLayerId = id end
	return id
end

-- ============================================================================
-- Activation
-- ============================================================================
local function activate()
	if active then return end
	if not compositorShader then
		if not createShaders() then
			Echo("[Diffuse Painter] activation aborted: shader creation failed")
			return
		end
	end
	active = true
	pendingInit = true
	Echo("[Diffuse Painter] active. LMB paint, RMB erase. /diffusepaint to toggle.")
end

local function deactivate()
	if not active then return end
	active = false
	leftMouseHeld = false
	lastPaintX, lastPaintZ = nil, nil
end

-- ============================================================================
-- Widget callbacks
-- ============================================================================
function widget:Initialize()
	mapSizeX = Game.mapSizeX
	mapSizeZ = Game.mapSizeZ
	numSqX = floor(mapSizeX / SQUARE_SIZE_ELMOS)
	numSqZ = floor(mapSizeZ / SQUARE_SIZE_ELMOS)
	if numSqX <= 0 or numSqZ <= 0 then
		Echo("[Diffuse Painter] map too small (no full SMF squares); disabling")
		widgetHandler:RemoveWidget()
		return
	end

	-- Single empty handpaint layer to start. User adds more by clicking
	-- materials in the UI (each material click on an unassigned active layer
	-- assigns it; otherwise spawns a new layer with that material).
	local paintId = addLayer({ name = "Layer 1", color = { 1.0, 1.0, 1.0 },
	           handPaintEnabled = true, enabled = true, opacity = 1.0 })
	activeLayerId = paintId

	scanMaterialLibrary()

	widgetHandler:AddAction("diffusepaint", function()
		if active then deactivate() else activate() end
	end, nil, "t")
	widgetHandler:AddAction("diffusepaintoff", deactivate, nil, "t")
	widgetHandler:AddAction("diffusepaintbake", function()
		if not active then activate() end
		pendingFullCover = true
	end, nil, "t")

	-- Dump every currently-composited square texture to disk as PNG so the
	-- user can repackage them into a real SMF map (engine API only lets us
	-- override diffuse per square at runtime; baked PBR shading is in RGB).
	local function exportSquares(folder)
		folder = folder or "tf_diffuse_export"
		local count = 0
		for _, s in pairs(squares) do
			if s and s.compositeTex then
				local fname = folder .. "/sq_" .. s.sx .. "_" .. s.sy .. ".png"
				local ok = pcall(gl.SaveImage, s.compositeTex, fname)
				if ok then count = count + 1 end
			end
		end
		Echo("[Diffuse Painter] exported " .. count .. " square textures to " ..
			tostring(Spring.GetConfigString and Spring.GetConfigString("WriteDir", "") or "") ..
			"/" .. folder .. "/")
		return count
	end
	widgetHandler:AddAction("diffusepaintexport", function() exportSquares() end, nil, "t")

	WG.DiffusePainter = {
		isActive       = function() return active end,
		activate       = activate,
		deactivate     = deactivate,
		getLayers      = function() return layers end,
		getActiveLayerId = function() return activeLayerId end,
		setActiveLayer = function(id) if findLayer(id) then activeLayerId = id end end,
		addLayer       = addLayer,
		removeLayer    = removeLayer,
		setLayerParam  = setLayerParam,
		setLayerTexture = setLayerTexture,
		addLayerFromMaterial = addLayerFromMaterial,
		getMaterialLibrary = function() return materialLibrary end,
		rescanMaterialLibrary = scanMaterialLibrary,
		bakeAll        = function() pendingFullCover = true end,
		exportSquares  = exportSquares,
		getBrush       = function() return brushRadius, brushStrength, brushCurve, eraseMode end,
		setRadius        = function(r) brushRadius = max(MIN_RADIUS, min(MAX_RADIUS, floor(r))) end,
		setStrength      = function(v) brushStrength = max(MIN_STRENGTH, min(MAX_STRENGTH, v)) end,
		setCurve         = function(v) brushCurve = max(MIN_CURVE, min(MAX_CURVE, v)) end,
		setErase         = function(b) eraseMode = b and true or false end,
		setFractal       = function(amount, freq)
			if amount ~= nil then brushFractalAmount = max(MIN_FRACTAL, min(MAX_FRACTAL, amount)) end
			if freq   ~= nil then brushFractalFreq   = max(MIN_FRACTAL_FREQ, min(MAX_FRACTAL_FREQ, freq)) end
		end,
		getFractal       = function() return brushFractalAmount, brushFractalFreq end,
		setLayerBlend    = function(id, mode)
			local layer = findLayer(id)
			if layer then layer.blend = mode or "normal"; pendingFullBake = true end
		end,
		setLayerHydro    = function(id, enabled, strength, fallLo, fallHi)
			local layer = findLayer(id)
			if not layer then return end
			if enabled   ~= nil then layer.hydroEnabled   = enabled and true or false end
			if strength  ~= nil then layer.hydroStrength  = max(0.001, strength) end
			if fallLo    ~= nil then layer.hydroFalloffLo = max(0.0, fallLo) end
			if fallHi    ~= nil then layer.hydroFalloffHi = max(0.0, fallHi) end
			pendingFullBake = true
		end,
		setLayerThermo   = function(id, enabled, angle, falloff)
			local layer = findLayer(id)
			if not layer then return end
			if enabled ~= nil then layer.thermoEnabled = enabled and true or false end
			if angle   ~= nil then layer.thermoAngle   = max(0.0, min(85.0, angle)) end
			if falloff ~= nil then layer.thermoFalloff = max(0.5, min(45.0, falloff)) end
			pendingFullBake = true
		end,
		resetSquare    = function(wx, wz)
			local sx, sy = floor(wx / SQUARE_SIZE_ELMOS), floor(wz / SQUARE_SIZE_ELMOS)
			local k = squareKey(sx, sy)
			for layerId, layerMasks in pairs(masks) do
				local maskTex = layerMasks[k]
				if maskTex then
					glRenderToTexture(maskTex, function()
						glBlending(false); glColor(0,0,0,0); glTexRect(-1,-1,1,1); glBlending(true)
					end)
				end
			end
			dirtySquares[k] = true
		end,
		resetAll       = function()
			for layerId, layerMasks in pairs(masks) do
				for k, maskTex in pairs(layerMasks) do
					glRenderToTexture(maskTex, function()
						glBlending(false); glColor(0,0,0,0); glTexRect(-1,-1,1,1); glBlending(true)
					end)
				end
			end
			pendingFullBake = true
		end,
	}
end

function widget:Shutdown()
	unbindAllSquares()
	for _, s in pairs(squares) do freeSquare(s) end
	squares = {}
	for _, layerMasks in pairs(masks) do
		for _, maskTex in pairs(layerMasks) do glDeleteTexture(maskTex) end
	end
	masks = {}
	destroyShaders()
	widgetHandler:RemoveAction("diffusepaint")
	widgetHandler:RemoveAction("diffusepaintoff")
	widgetHandler:RemoveAction("diffusepaintbake")
	widgetHandler:RemoveAction("diffusepaintexport")
	WG.DiffusePainter = nil
end

function widget:MousePress(mx, my, button)
	if not active then return false end
	if button ~= 1 and button ~= 3 then return false end
	-- Defer to common tf instruments
	local tfBrush = WG.TerraformBrush
	if tfBrush and tfBrush.getState then
		local tbState = tfBrush.getState()
		if tbState and (tbState.measureActive or tbState.heightSamplingMode) then return false end
	end
	leftMouseHeld = true
	eraseMode = (button == 3)
	local wx, wz = getWorldMousePosition()
	if wx and activeLayerId then
		pendingPaintStrokes[#pendingPaintStrokes + 1] = { wx, wz, activeLayerId, eraseMode }
		lastPaintX, lastPaintZ = wx, wz
	end
	return true
end

function widget:MouseRelease(mx, my, button)
	if not active then return false end
	if button == 1 or button == 3 then
		leftMouseHeld = false
		lastPaintX, lastPaintZ = nil, nil
		return true
	end
	return false
end

function widget:MouseMove(mx, my, dx, dy, button)
	if not active or not leftMouseHeld then return false end
	local wx, wz = getWorldMousePosition()
	if not wx or not activeLayerId then return false end
	local effR = getEffectiveBrush()
	local spacing = max(effR * 0.3, 8)
	if lastPaintX and lastPaintZ then
		local ddx, ddz = wx - lastPaintX, wz - lastPaintZ
		local dist = sqrt(ddx * ddx + ddz * ddz)
		if dist >= spacing then
			local steps = floor(dist / spacing)
			for i = 1, steps do
				local t = i / steps
				pendingPaintStrokes[#pendingPaintStrokes + 1] = {
					lastPaintX + ddx * t, lastPaintZ + ddz * t, activeLayerId, eraseMode
				}
			end
			lastPaintX, lastPaintZ = wx, wz
		end
	else
		pendingPaintStrokes[#pendingPaintStrokes + 1] = { wx, wz, activeLayerId, eraseMode }
		lastPaintX, lastPaintZ = wx, wz
	end
	return false
end

function widget:MouseWheel(up, value)
	if not active then return false end
	local alt, ctrl, _, shift = Spring.GetModKeyState()
	if ctrl then
		brushRadius = max(MIN_RADIUS, min(MAX_RADIUS, brushRadius + (up and RADIUS_STEP or -RADIUS_STEP)))
		return true
	elseif shift then
		brushCurve = max(MIN_CURVE, min(MAX_CURVE, brushCurve + (up and CURVE_STEP or -CURVE_STEP)))
		return true
	elseif alt then
		brushStrength = max(MIN_STRENGTH, min(MAX_STRENGTH, brushStrength + (up and STRENGTH_STEP or -STRENGTH_STEP)))
		return true
	end
	return false
end

function widget:DrawWorld()
	-- Lazy init: NO bulk alloc. Squares are allocated on first paint stroke
	-- (executeStroke) or on explicit /diffusepaintbake (which will allocate
	-- every map square — heavy, opt-in).
	if pendingInit then
		pendingInit = false
	end

	-- Strokes
	if #pendingPaintStrokes > 0 then
		for i = 1, #pendingPaintStrokes do
			local stroke = pendingPaintStrokes[i]
			executeStroke(stroke[1], stroke[2], stroke[3], stroke[4])
		end
		pendingPaintStrokes = {}
	end

	-- Full bake = re-bake every ALREADY-allocated square. Cheap for layer
	-- param tweaks; does not allocate new squares.
	if pendingFullBake then
		pendingFullBake = false
		for k, s in pairs(squares) do
			if s.seedTex then dirtySquares[k] = true end
		end
	end

	-- Full coverage = allocate every map square + bake. Heavy; opt-in via
	-- /diffusepaintbake action.
	if pendingFullCover then
		pendingFullCover = false
		for sx = 0, numSqX - 1 do
			for sy = 0, numSqZ - 1 do
				local s = getOrAllocSquare(sx, sy)
				if s and not s.seedTex then allocateSquare(s) end
				if s and s.compositeTex then dirtySquares[squareKey(sx, sy)] = true end
			end
		end
	end

	-- Bake all dirty squares this frame (no rate limit yet)
	local bakedCount = 0
	for k, _ in pairs(dirtySquares) do
		local s = squares[k]
		if s and s.seedTex then bakeSquare(s) end
		dirtySquares[k] = nil
		bakedCount = bakedCount + 1
		if bakedCount >= 16 then break end  -- coarse rate limit per frame
	end

	-- Brush ring
	if active then
		local wx, wz = getWorldMousePosition()
		if wx then
			local groundY = GetGroundHeight(wx, wz)
			local effR = getEffectiveBrush()
			local col = eraseMode and { 1.0, 0.55, 0.1, 0.9 } or { 0.4, 0.85, 1.0, 0.9 }
			glColor(col[1], col[2], col[3], col[4])
			glLineWidth(2.0)
			glDrawGroundCircle(wx, groundY, wz, effR, 64)
			glLineWidth(1.0)
			-- Falloff ring at 50%
			if brushCurve > 0.1 then
				local halfR = effR * (0.5 ^ (1 / brushCurve))
				glColor(col[1], col[2], col[3], 0.35)
				glDrawGroundCircle(wx, groundY, wz, halfR, 64)
			end
		end
	end
end
