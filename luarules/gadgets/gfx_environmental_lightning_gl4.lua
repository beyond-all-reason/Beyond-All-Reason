--------------------------------------------------------------------------------
-- Environmental Lightning GL4
-- GPU-instanced procedural electric arcs that grow/branch out from an origin
-- over time WITHOUT connecting to an endpoint (unlike the lightning cannon).
-- Intended as a configurable replacement for ambient lightning CEGs such as
-- "scavradiation-lightning".
--
-- Synced API (call from any synced gadget):
--   GG.SpawnEnvironmentalLightning(configName, x, y, z [, sizeScale [, intensityScale]])
--     configName     : key into the `lightningConfigs` table below (string)
--     x, y, z         : world origin of the burst
--     sizeScale       : optional multiplier on reach + thickness (default 1)
--     intensityScale  : optional multiplier on brightness (default 1)
--
-- Per-config visual parameters (see `lightningConfigs`):
--   color (r,g,b + core color), lifetime, intensity, feather, size (width + reach),
--   shape (directional bias + spread), branch count / depth, jitter, glow, etc.
--
-- Based on the rendering approach of gfx_lightning_cannon_gl4.lua (Floris).
--------------------------------------------------------------------------------

function gadget:GetInfo()
	return {
		name    = "Environmental Lightning GL4",
		desc    = "GL4 instanced procedural environmental lightning bursts",
		author  = "Floris",
		date    = "June 2026",
		license = "GNU GPL v2",
		layer   = 0,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- SYNCED: expose the spawn API and forward spawn requests to the renderer.
--------------------------------------------------------------------------------
if gadgetHandler:IsSyncedCode() then

	local SendToUnsynced = SendToUnsynced

	function gadget:Initialize()
		GG.SpawnEnvironmentalLightning = function(configName, x, y, z, sizeScale, intensityScale)
			if not configName or not x or not y or not z then return end
			SendToUnsynced("envLightningSpawn",
				tostring(configName),
				x, y, z,
				sizeScale or 1.0,
				intensityScale or 1.0)
		end
	end

	function gadget:Shutdown()
		GG.SpawnEnvironmentalLightning = nil
	end

	return
end

--------------------------------------------------------------------------------
-- UNSYNCED (rendering)
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Lightning config presets.
-- Each entry is a fully self-contained look. Add new entries here and reference
-- them by name from synced code via GG.SpawnEnvironmentalLightning("name", ...).
--
-- Fields:
--   r,g,b            edge (outer) color
--   coreR,coreG,coreB  hot core color (auto-brightened from edge if omitted)
--   lifeFrames       total lifetime in sim frames (30 = 1s)
--   intensity        overall brightness multiplier
--   feather          0..1 edge softness (0 = crisp, 1 = very soft/diffuse glow)
--   baseWidth        bolt core thickness in elmos
--   reach            full length of the primary arms in elmos
--   branchCount      number of primary arms shooting out of the origin
--   childCount       child forks spawned per branch node
--   maxDepth         recursion depth of forking (0 = only primary arms)
--   segments         jagged segments per arm (visual detail)
--   jitterAmp        perpendicular jaggedness amplitude in elmos
--   glowBrightness   additive halo brightness
--   vbias            vertical direction bias of primary arms (-1 down .. 1 up)
--   spread           child fork angular spread in radians
--   growFrac         fraction of life an arm takes to extend to full length
--   flowFrac         0..0.95 how much the arm tail advances toward the tip
--                    during growth (higher = stronger outward propagation)
--   tipTaper         leading-tip thinning (0.1 = sharp point, 1 = no taper)
--   sizeVarMin/Max   random per-burst size range multiplier (correlates complexity/lifetime)
--   intensityVar     extra random intensity variance around size-correlated base
--   lifeVar          extra random lifetime variance around complexity-correlated base
--   maxIntensityScale optional cap on per-burst intensityScale after variation
--
-- Optional "scatter" fields (for unit-centered bursts that crackle around an
-- area over time, e.g. the commander-spawn effect). When scatterCount > 0 the
-- API call emits one central burst plus a stream of smaller delayed sub-bursts
-- spread across an area:
--   startDelay        frames to wait before the central burst (and scatter window)
--   centerHeight      vertical offset (elmos) added to the central burst origin
--   centerSizeScale   size multiplier for the central burst
--   centerIntensityScale  intensity multiplier for the central burst
--   scatterCount      number of scattered area sparks
--   scatterFrames     time window (frames) over which sparks appear
--   scatterRadius     horizontal scatter radius (elmos)
--   scatterHeightMin/Max  vertical offset range for sparks (elmos)
--   scatterSizeMin/Max    size scale range for sparks (small -> simpler/shorter)
--   scatterIntensityScale intensity multiplier for sparks
--   scatterWidthScale     width multiplier for sparks (thickness only)
--------------------------------------------------------------------------------
local lightningConfigs = {
	scavradiation = {
		r = 0.50, g = 0.4, b = 1.00,
		coreR = 0.82, coreG = 0.7, coreB = 1.00,
		lifeFrames     = 11,
		intensity      = 0.3,
		feather        = 0.4,
		baseWidth      = 0.9,
		reach          = 450,
		branchCount    = 2,
		childCount     = 1,
		maxDepth       = 4,
		segments       = 3,
		jitterAmp      = 32,
		glowBrightness = 0.4,
		vbias          = 0.20,
		spread         = 4,
		growFrac       = 0.5,
		flowFrac       = 0.3,
		tipTaper       = 0.1,
		sizeVarMin     = 0.3,
		sizeVarMax     = 1.3,
		intensityVar   = 0.5,
		lifeVar        = 0.3,
	},

	-- Centered on a freshly spawned unit (commander spawn / warp-in). Unlike the
	-- airborne scavradiation cloud, this fires a strong arc burst at the unit
	-- plus a stream of smaller electric sparks crackling across the surrounding
	-- area over roughly two seconds.
	commanderspawn = {
		r = 0.55, g = 0.66, b = 1.00,
		coreR = 0.92, coreG = 0.96, coreB = 1.00,
		lifeFrames     = 11,
		intensity      = 0.12,
		feather        = 0.5,
		baseWidth      = 0.9,
		reach          = 50,
		branchCount    = 3,
		childCount     = 2,
		maxDepth       = 2,
		segments       = 2,
		jitterAmp      = 12,
		glowBrightness = 0.35,
		vbias          = 0.35,
		spread         = 3.5,
		growFrac       = 0.5,
		flowFrac       = 0.2,
		tipTaper       = 0.1,
		sizeVarMin     = 0.85,
		sizeVarMax     = 1.3,
		intensityVar   = 0.1,
		lifeVar        = 0.15,
		maxIntensityScale = 1.35,
		startDelay            = 18,
		-- scatter / area behaviour
		centerHeight          = 25,
		centerSizeScale       = 1.35,
		centerIntensityScale  = 1.45,
		scatterCount          = 10,
		scatterFrames         = 45,
		scatterRadius         = 30,
		scatterHeightMin      = 18,
		scatterHeightMax      = 45,
		scatterSizeMin        = 0.3,
		scatterSizeMax        = 0.6,
		scatterIntensityScale = 1.0,
		scatterWidthScale     = 1.75,
	},
}

--------------------------------------------------------------------------------
-- Localized functions
--------------------------------------------------------------------------------
local spGetGameFrame   = Spring.GetGameFrame
local spIsAABBInView   = Spring.IsAABBInView

local glBlending  = gl.Blending
local glDepthTest = gl.DepthTest
local glDepthMask = gl.DepthMask
local glCulling   = gl.Culling

local GL_ONE                 = GL.ONE
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_SRC_ALPHA           = GL.SRC_ALPHA

local mathMin    = math.min
local mathMax    = math.max
local mathSqrt   = math.sqrt
local mathSin    = math.sin
local mathCos    = math.cos
local mathPi     = math.pi
local mathFloor  = math.floor
local mathAbs    = math.abs
local mathRandom = math.random

local LuaShader = gl.LuaShader
local uploadAllElements = gl.InstanceVBOTable.uploadAllElements

local function clamp(v, lo, hi) return v < lo and lo or (v > hi and hi or v) end
local function lerp(a, b, t) return a + (b - a) * t end

-- When false, bolt shape/brightness no longer reroll every render frame.
-- Bursts still spawn/grow/fade normally, but each bolt stays temporally stable.
local ENABLE_DYNAMIC_ANIMATION = false

--------------------------------------------------------------------------------
-- Config / tuning constants (global shader behaviour; per-burst overrides come
-- through the instance attributes).
--------------------------------------------------------------------------------
local INITIAL_VBO_SIZE = 512
local IDLE_SKIP_FRAMES = 3
local MAX_ACTIVE       = 256     -- hard cap on simultaneous bursts (oldest dropped)

-- Lifetime envelope (fractions of each burst's lifeFrames)
local FADE_IN_FRAC   = 0.08    -- burst fades in over this fraction of life
local FADE_OUT_FRAC  = 0.35    -- burst fades out over the final fraction of life
local BRANCH_APPEAR  = 0.06    -- per-arm pop-in fade window (life fraction)

-- Bolt body look
local FLICKER_AMPLITUDE   = 0.45
local THICKNESS_VARIATION = 0.7
local SEGMENT_LENGTH_VAR  = 0.75
local JITTER_MAX_BOLT_FRAC  = 0.10
local BRUSH_MAX_JITTER_FRAC = 0.5
local CORE_EDGE_START   = 0.03
local CORE_EDGE_END     = 0.3
local CORE_BRIGHTNESS   = 2.3
local BRIGHTNESS_MULT   = 2.5
local MIN_PIXEL_WIDTH   = 0.0018
local TIP_TAPER_START   = 0.55  -- segPos where tip taper begins

-- Glow halo
local GLOW_WIDTH_MULT      = 12.0
local GLOW_FALLOFF_POWER   = 5.0
local GLOW_MIN_PIXEL_WIDTH = 0.005

local INSTANCE_STRIDE = 24      -- 6 vec4 attributes

--------------------------------------------------------------------------------
-- Precompute derived per-config fields (core color fallback, length falloff).
--------------------------------------------------------------------------------
for _, cfg in pairs(lightningConfigs) do
	cfg.coreR = cfg.coreR or mathMin(1, cfg.r + 0.4)
	cfg.coreG = cfg.coreG or mathMin(1, cfg.g + 0.4)
	cfg.coreB = cfg.coreB or mathMin(1, cfg.b + 0.4)
	cfg.feather    = cfg.feather    or 0.5
	cfg.intensity  = cfg.intensity  or 1.0
	cfg.childCount = cfg.childCount or 0
	cfg.maxDepth   = cfg.maxDepth   or 0
	cfg.growFrac   = cfg.growFrac   or 0.4
	cfg.flowFrac   = clamp(cfg.flowFrac or 0.0, 0.0, 0.95)
	cfg.tipTaper   = cfg.tipTaper   or 0.15
	cfg.vbias      = cfg.vbias      or 0.0
	cfg.spread     = cfg.spread     or 0.8
	cfg.sizeVarMin = cfg.sizeVarMin or 1.0
	cfg.sizeVarMax = cfg.sizeVarMax or 1.0
	cfg.intensityVar = cfg.intensityVar or 0.0
	cfg.lifeVar = cfg.lifeVar or 0.0
end

--------------------------------------------------------------------------------
-- Shaders
--------------------------------------------------------------------------------
local boltVsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 10000

//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

// Quad vertex: xy = corner (-1..1), zw = UV
layout (location = 0) in vec4 position_xy_uv;

layout (location = 1) in vec4 startPosAndWidth;   // xyz = arm start, w = base width
layout (location = 2) in vec4 endPosAndTip;       // xyz = current (grown) tip, w = tip taper
layout (location = 3) in vec4 coreColor;          // rgb = core color, a = alphaMul
layout (location = 4) in vec4 edgeColor;          // rgb = edge color, a = length falloff
layout (location = 5) in vec4 boltParams;         // x = seed, y = segIndex, z = segCount, w = jitterAmp
layout (location = 6) in vec4 extraParams;        // x = widthMul, y = widthScale, z = glowMult, w = feather

out DataVS {
	vec3 vCoreColor;
	vec3 vEdgeColor;
	float alpha;
	float widthPos;
	float coverage;
	float feather;
};

float hash11(float x) { return fract(sin(x * 12.9898) * 43758.5453); }

void cullVertex() { gl_Position = vec4(2.0, 2.0, 2.0, 1.0); }

void main()
{
	vec3 startPos   = startPosAndWidth.xyz;
	float baseWidth = startPosAndWidth.w * extraParams.y * extraParams.x;
	vec3 endPos     = endPosAndTip.xyz;
	float tipTaper  = endPosAndTip.w;

	float seed     = boltParams.x;
	float segIndex = boltParams.y;
	float segCount = boltParams.z;
	float jitterAmp= boltParams.w;

	vec3 boltDir = endPos - startPos;
	float boltLen = length(boltDir);
	if (boltLen < 0.01 || segCount < 1.0) { cullVertex(); return; }
	vec3 forward = boltDir / boltLen;

	vec3 upRef = abs(forward.y) > 0.9 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0);
	vec3 perpA = normalize(cross(forward, upRef));
	vec3 perpB = normalize(cross(forward, perpA));

	float frameTick = ENV_LIGHTNING_ANIMATE > 0.5 ? floor(timeInfo.z * 30.0) : 0.0;

	// Per-segment t with deterministic per-boundary length jitter (endpoints fixed)
	float yNorm = position_xy_uv.y * 0.5 + 0.5;
	float invSeg = 1.0 / segCount;
	float lenVarAmp = SEGMENT_LENGTH_VAR * invSeg * 0.5;
	float b0 = segIndex;
	float b1 = segIndex + 1.0;
	float off0 = (b0 > 0.5 && b0 < segCount - 0.5) ? (hash11(seed * 41.0 + b0 * 17.3 + frameTick * 0.29) * 2.0 - 1.0) * lenVarAmp : 0.0;
	float off1 = (b1 > 0.5 && b1 < segCount - 0.5) ? (hash11(seed * 41.0 + b1 * 17.3 + frameTick * 0.29) * 2.0 - 1.0) * lenVarAmp : 0.0;
	float t0 = b0 * invSeg + off0;
	float t1 = b1 * invSeg + off1;
	float tHere = mix(t0, t1, yNorm);
	float tNext = (yNorm < 0.5) ? t1 : t0;

	float keyHere = seed * 13.0 + tHere * 91.0 + frameTick * 0.37;
	float keyNext = seed * 13.0 + tNext * 91.0 + frameTick * 0.37;

	float jitterScale = min(jitterAmp, boltLen * JITTER_MAX_BOLT_FRAC);

	float endFadeHere = sin(tHere * 3.14159);
	float endFadeNext = sin(tNext * 3.14159);
	vec3 jitHere = (perpA * hash11(keyHere) + perpB * hash11(keyHere + 7.7)) * 2.0 - (perpA + perpB);
	vec3 jitNext = (perpA * hash11(keyNext) + perpB * hash11(keyNext + 7.7)) * 2.0 - (perpA + perpB);
	jitHere *= jitterScale * endFadeHere;
	jitNext *= jitterScale * endFadeNext;

	vec3 posHere = mix(startPos, endPos, tHere) + jitHere;
	vec3 posNext = mix(startPos, endPos, tNext) + jitNext;

	vec3 segDir = posNext - posHere;
	float segLen = length(segDir);
	if (segLen < 0.0001) { cullVertex(); return; }
	segDir /= segLen;

	vec3 camPos = cameraViewInv[3].xyz;
	vec3 toCam  = normalize(camPos - posHere);
	vec3 right  = cross(segDir, toCam);
	float rightLen = length(right);
	if (rightLen < 0.3) {
		vec3 fb = normalize(cross(segDir, vec3(0.0, 1.0, 0.0)));
		if (length(fb) < 0.001) fb = normalize(cross(segDir, vec3(1.0, 0.0, 0.0)));
		float bl = clamp(rightLen / 0.3, 0.0, 1.0);
		right = normalize(mix(fb, right / max(rightLen, 0.001), bl));
	} else {
		right = right / rightLen;
	}

	float segWobble = mix(1.0 - THICKNESS_VARIATION, 1.0 + THICKNESS_VARIATION,
		hash11(seed * 3.1 + segIndex * 5.7 + frameTick * 0.21));
	float flicker = 1.0;
	if (ENV_LIGHTNING_ANIMATE > 0.5) {
		float flickerSeed = seed * 0.97 + frameTick * 0.13;
		flicker = 1.0 - FLICKER_AMPLITUDE * 0.5 + FLICKER_AMPLITUDE * hash11(flickerSeed);
	}

	// Leading-tip taper: thin to a point toward the (unconnected) far end.
	float tipW = mix(1.0, tipTaper, smoothstep(TIP_TAPER_START, 1.0, tHere));

	float width = baseWidth * segWobble * flicker * tipW;

	float camDist = length(camPos - mix(startPos, endPos, 0.5));
	float minWidth = camDist * MIN_PIXEL_WIDTH;
	minWidth = min(minWidth, jitterScale * BRUSH_MAX_JITTER_FRAC);
	float coverageVal = clamp(width / max(minWidth, 0.001), 0.0, 1.0);
	width = max(width, minWidth);

	vec3 vertexWorld = posHere + right * position_xy_uv.x * width;
	gl_Position = cameraViewProj * vec4(vertexWorld, 1.0);

	vCoreColor = coreColor.rgb;
	vEdgeColor = edgeColor.rgb;
	widthPos = position_xy_uv.x;
	coverage = coverageVal;
	feather  = extraParams.w;

	float lengthFalloff = edgeColor.a;
	alpha = coreColor.a * coverageVal * flicker * (1.0 - lengthFalloff * tHere);
}
]]

local boltFsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 20000

//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

in DataVS {
	vec3 vCoreColor;
	vec3 vEdgeColor;
	float alpha;
	float widthPos;
	float coverage;
	float feather;
};

out vec4 fragColor;

void main(void)
{
	float edgeDist = abs(widthPos);
	float fw = fwidth(edgeDist);
	float coreEnd = CORE_EDGE_END * mix(1.0, 2.5, feather);
	float aaStart = CORE_EDGE_START - fw * 0.5;
	float aaEnd   = max(coreEnd, CORE_EDGE_START + fw);
	float coreFactor = 1.0 - smoothstep(aaStart, aaEnd, edgeDist);

	float radial = 1.0 - smoothstep(0.0, 1.0, edgeDist);

	vec3 col = mix(vEdgeColor, vCoreColor, coreFactor);
	col *= BRIGHTNESS_MULT;
	col *= (1.0 + coreFactor * CORE_BRIGHTNESS);
	col *= radial * alpha;

	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	if (lum < 0.0005) discard;
	float edgeSoft = smoothstep(0.0005, 0.004, lum);
	col *= edgeSoft;

	fragColor = vec4(col, 0.0);
}
]]

-- Glow: ONE camera-facing quad per arm along the straight start->tip axis.
local glowVsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 30000

//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

layout (location = 0) in vec4 position_xy_uv;
layout (location = 1) in vec4 startPosAndWidth;
layout (location = 2) in vec4 endPosAndTip;
layout (location = 3) in vec4 coreColor;
layout (location = 4) in vec4 edgeColor;
layout (location = 5) in vec4 boltParams;
layout (location = 6) in vec4 extraParams;

out DataVS {
	float widthPos;
	float lengthT;
	vec3 glowColor;
	float alpha;
	float glowMult;
	float feather;
};

float hash11(float x) { return fract(sin(x * 12.9898) * 43758.5453); }

void main()
{
	vec3 startPos   = startPosAndWidth.xyz;
	float baseWidth = startPosAndWidth.w * extraParams.y * extraParams.x;
	vec3 endPos     = endPosAndTip.xyz;

	float seed     = boltParams.x;
	float segIndex = boltParams.y;
	float segCount = boltParams.z;

	vec3 boltDir = endPos - startPos;
	float boltLen = length(boltDir);
	if (boltLen < 0.01 || segCount < 1.0) { gl_Position = vec4(2.0,2.0,2.0,1.0); return; }
	// One glow quad per arm: cull every segment except the first.
	if (segIndex > 0.5) { gl_Position = vec4(2.0,2.0,2.0,1.0); return; }
	vec3 forward = boltDir / boltLen;

	float yNorm = position_xy_uv.y * 0.5 + 0.5;
	float tHere = yNorm;
	vec3 posOnAxis = mix(startPos, endPos, tHere);

	vec3 camPos = cameraViewInv[3].xyz;
	vec3 toCam  = normalize(camPos - posOnAxis);
	vec3 right  = cross(forward, toCam);
	float rightLen = length(right);
	if (rightLen < 0.3) {
		vec3 fb = normalize(cross(forward, vec3(0.0, 1.0, 0.0)));
		if (length(fb) < 0.001) fb = normalize(cross(forward, vec3(1.0, 0.0, 0.0)));
		float bl = clamp(rightLen / 0.3, 0.0, 1.0);
		right = normalize(mix(fb, right / max(rightLen, 0.001), bl));
	} else {
		right = right / rightLen;
	}

	float flicker = 1.0;
	if (ENV_LIGHTNING_ANIMATE > 0.5) {
		float frameTick = floor(timeInfo.z * 30.0);
		flicker = 1.0 - FLICKER_AMPLITUDE * 0.5 + FLICKER_AMPLITUDE * hash11(seed * 0.97 + frameTick * 0.13);
	}
	float glowWidth = baseWidth * GLOW_WIDTH_MULT * flicker;

	float camDist = length(camPos - posOnAxis);
	float minWidth = camDist * GLOW_MIN_PIXEL_WIDTH;
	float coverageVal = clamp(glowWidth / max(minWidth, 0.001), 0.0, 1.0);
	glowWidth = max(glowWidth, minWidth);

	vec3 vertexWorld = posOnAxis + right * position_xy_uv.x * glowWidth;
	gl_Position = cameraViewProj * vec4(vertexWorld, 1.0);

	widthPos = position_xy_uv.x;
	lengthT  = tHere;
	glowColor = edgeColor.rgb;
	float lengthFalloff = edgeColor.a;
	alpha = coreColor.a * flicker * coverageVal * (1.0 - lengthFalloff * tHere);
	glowMult = extraParams.z;
	feather  = extraParams.w;
}
]]

local glowFsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 40000

//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

in DataVS {
	float widthPos;
	float lengthT;
	vec3 glowColor;
	float alpha;
	float glowMult;
	float feather;
};

out vec4 fragColor;

void main(void)
{
	float edgeDist = abs(widthPos);
	if (edgeDist >= 1.0) discard;
	// Softer (lower power) falloff for higher feather -> wider diffuse halo.
	float power = GLOW_FALLOFF_POWER * mix(1.6, 0.5, feather);
	float g = exp(-edgeDist * edgeDist * power);
	float edgeVal = exp(-power);
	float falloff = max(g - edgeVal, 0.0) / max(1.0 - edgeVal, 0.0001);
	// Anchor glow to zero at the origin and the tip.
	float lengthEndFade = sin(clamp(lengthT, 0.0, 1.0) * 3.14159);
	falloff *= lengthEndFade;
	vec3 col = glowColor * (falloff * alpha * glowMult);
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	if (lum < 0.001) discard;
	fragColor = vec4(col, 0.0);
}
]]

--------------------------------------------------------------------------------
-- Shader #define configs
--------------------------------------------------------------------------------
local function ensureFloatDefines(cfg)
	for k, v in pairs(cfg) do
		if type(v) == "number" and v == mathFloor(v) then
			cfg[k] = v + 0.00001
		end
	end
	return cfg
end

local boltShaderConfig = {
	FLICKER_AMPLITUDE   = FLICKER_AMPLITUDE,
	THICKNESS_VARIATION = THICKNESS_VARIATION,
	SEGMENT_LENGTH_VAR  = SEGMENT_LENGTH_VAR,
	ENV_LIGHTNING_ANIMATE = ENABLE_DYNAMIC_ANIMATION and 1 or 0,
	JITTER_MAX_BOLT_FRAC  = JITTER_MAX_BOLT_FRAC,
	BRUSH_MAX_JITTER_FRAC = BRUSH_MAX_JITTER_FRAC,
	CORE_EDGE_START     = CORE_EDGE_START,
	CORE_EDGE_END       = CORE_EDGE_END,
	CORE_BRIGHTNESS     = CORE_BRIGHTNESS,
	BRIGHTNESS_MULT     = BRIGHTNESS_MULT,
	MIN_PIXEL_WIDTH     = MIN_PIXEL_WIDTH,
	TIP_TAPER_START     = TIP_TAPER_START,
}

local glowShaderConfig = {
	FLICKER_AMPLITUDE    = FLICKER_AMPLITUDE,
	ENV_LIGHTNING_ANIMATE = ENABLE_DYNAMIC_ANIMATION and 1 or 0,
	GLOW_WIDTH_MULT      = GLOW_WIDTH_MULT,
	GLOW_FALLOFF_POWER   = GLOW_FALLOFF_POWER,
	GLOW_MIN_PIXEL_WIDTH = GLOW_MIN_PIXEL_WIDTH,
}

--------------------------------------------------------------------------------
-- GL4 state
--------------------------------------------------------------------------------
local boltVBO
local boltShader
local glowShader

local function goodbye(reason)
	Spring.Echo("[Environmental Lightning GL4] removing self: " .. tostring(reason))
	gadgetHandler:RemoveGadget()
end

local function initGL4()
	ensureFloatDefines(boltShaderConfig)
	ensureFloatDefines(glowShaderConfig)

	boltShader = LuaShader.CheckShaderUpdates({
		vsSrc = boltVsSrc,
		fsSrc = boltFsSrc,
		shaderName = "EnvLightningBoltGL4",
		uniformFloat = {},
		shaderConfig = boltShaderConfig,
		forceupdate = true,
	})
	if not boltShader then goodbye("Failed to compile bolt shader"); return false end

	glowShader = LuaShader.CheckShaderUpdates({
		vsSrc = glowVsSrc,
		fsSrc = glowFsSrc,
		shaderName = "EnvLightningGlowGL4",
		uniformFloat = {},
		shaderConfig = glowShaderConfig,
		forceupdate = true,
	})
	if not glowShader then goodbye("Failed to compile glow shader"); return false end

	local quadVBO, numVertices = gl.InstanceVBOTable.makeRectVBO(
		-1, -1, 1, 1, 0, 0, 1, 1, "envLightningQuadVBO"
	)
	local indexVBO = gl.InstanceVBOTable.makeRectIndexVBO("envLightningIndexVBO")

	local boltLayout = {
		{id = 1, name = "startPosAndWidth", size = 4},
		{id = 2, name = "endPosAndTip",     size = 4},
		{id = 3, name = "coreColor",        size = 4},
		{id = 4, name = "edgeColor",        size = 4},
		{id = 5, name = "boltParams",       size = 4},
		{id = 6, name = "extraParams",      size = 4},
	}
	boltVBO = gl.InstanceVBOTable.makeInstanceVBOTable(boltLayout, INITIAL_VBO_SIZE, "envLightningVBO")
	if not boltVBO then goodbye("Failed to create bolt VBO"); return false end
	boltVBO.numVertices = numVertices
	boltVBO.vertexVBO = quadVBO
	boltVBO.VAO = boltVBO:makeVAOandAttach(quadVBO, boltVBO.instanceVBO)
	boltVBO.primitiveType = GL.TRIANGLES
	boltVBO.VAO:AttachIndexBuffer(indexVBO)
	boltVBO.indexVBO = indexVBO
	return true
end

local function resizeBoltVBO(needed)
	local newMax = boltVBO.maxElements
	while newMax < needed do newMax = newMax * 2 end
	boltVBO.maxElements = newMax
	local newInstanceVBO = gl.GetVBO(GL.ARRAY_BUFFER, true)
	newInstanceVBO:Define(newMax, boltVBO.layout)
	boltVBO.instanceVBO:Delete()
	boltVBO.instanceVBO = newInstanceVBO
	local data = boltVBO.instanceData
	local step = boltVBO.instanceStep
	for i = #data + 1, step * newMax do data[i] = 0 end
	boltVBO.VAO:Delete()
	boltVBO.VAO = boltVBO:makeVAOandAttach(boltVBO.vertexVBO, boltVBO.instanceVBO)
	boltVBO.VAO:AttachIndexBuffer(boltVBO.indexVBO)
end

local function cleanupGL4()
	if boltVBO then boltVBO:Delete(); boltVBO = nil end
end

--------------------------------------------------------------------------------
-- Active bursts
-- Each burst: { cfg, x,y,z, birthFrame, seed, sizeScale, intensityScale,
--               aabbPad, branches = { {sx,sy,sz, dx,dy,dz, len, startFrac,
--               growFrac, seed, widthScale} ... } }
--------------------------------------------------------------------------------
local active   = {}    -- array of bursts
local nActive  = 0
local idleSkipCounter = 0
local lastBuildFrame  = -1

-- Build an arbitrary perpendicular basis around a unit forward vector.
local function perpBasis(fx, fy, fz)
	local upX, upY, upZ = 0, 1, 0
	if mathAbs(fy) > 0.9 then upX, upY, upZ = 1, 0, 0 end
	local ax = fy * upZ - fz * upY
	local ay = fz * upX - fx * upZ
	local az = fx * upY - fy * upX
	local al = mathSqrt(ax*ax + ay*ay + az*az)
	if al > 0.001 then ax, ay, az = ax/al, ay/al, az/al end
	local bx = fy * az - fz * ay
	local by = fz * ax - fx * az
	local bz = fx * ay - fy * ax
	return ax, ay, az, bx, by, bz
end

-- Generate the branch tree of a burst (deterministic per-burst via math.random
-- seeded look; values are unsynced/visual only, so plain math.random is fine).
local function buildBranches(cfg, sizeScale, branchCount, childCount, maxDepth, growFrac)
	local branches = {}
	local n = 0
	local reach = cfg.reach * sizeScale
	local spread = cfg.spread
	local vbias = cfg.vbias

	-- recursive generation via explicit stack to avoid deep closures
	local function addBranch(sx, sy, sz, dx, dy, dz, len, startFrac, growFrac, depth, widthScale)
		n = n + 1
		branches[n] = {
			sx = sx, sy = sy, sz = sz,
			dx = dx, dy = dy, dz = dz,
			len = len,
			startFrac = startFrac,
			growFrac = growFrac,
			seed = mathRandom() * 1000.0,
			widthScale = widthScale,
		}
		if depth >= maxDepth or childCount <= 0 then return end
		local ax, ay, az, bx, by, bz = perpBasis(dx, dy, dz)
		for _ = 1, childCount do
			local anchorFrac = 0.30 + mathRandom() * 0.55
			-- child base position along this (straight) arm
			local cx = sx + dx * len * anchorFrac
			local cy = sy + dy * len * anchorFrac
			local cz = sz + dz * len * anchorFrac
			-- child direction = arm dir rotated by a random angle within spread
			local angle = (mathRandom() * 2.0 - 1.0) * spread
			local roll = mathRandom() * 2.0 * mathPi
			local rc, rs = mathCos(roll), mathSin(roll)
			local pmx = ax * rc + bx * rs
			local pmy = ay * rc + by * rs
			local pmz = az * rc + bz * rs
			local c, s = mathCos(angle), mathSin(angle)
			local ndx = dx * c + pmx * s
			local ndy = dy * c + pmy * s
			local ndz = dz * c + pmz * s
			local nl = mathSqrt(ndx*ndx + ndy*ndy + ndz*ndz)
			if nl > 0.001 then ndx, ndy, ndz = ndx/nl, ndy/nl, ndz/nl end
			local childLen = len * (0.45 + mathRandom() * 0.30)
			local childStart = startFrac + growFrac * anchorFrac
			if childStart < 0.98 then
				addBranch(cx, cy, cz, ndx, ndy, ndz, childLen,
					childStart, growFrac * 0.7, depth + 1, widthScale * 0.7)
			end
		end
	end

	for _ = 1, branchCount do
		-- primary arm direction: random sphere direction with vertical bias
		local rx = mathRandom() * 2.0 - 1.0
		local ry = mathRandom() * 2.0 - 1.0
		local rz = mathRandom() * 2.0 - 1.0
		local rl = mathSqrt(rx*rx + ry*ry + rz*rz)
		if rl < 0.001 then rx, ry, rz, rl = 0, 1, 0, 1 end
		rx, ry, rz = rx/rl, ry/rl, rz/rl
		-- blend vertical component toward the bias
		ry = ry * (1.0 - mathAbs(vbias)) + vbias
		local bl = mathSqrt(rx*rx + ry*ry + rz*rz)
		rx, ry, rz = rx/bl, ry/bl, rz/bl
		local armLen = reach * (0.70 + mathRandom() * 0.30)
		-- positions are origin-relative; the burst origin is added at emit time
		addBranch(0, 0, 0, rx, ry, rz, armLen, 0.0, growFrac, 0, 1.0)
	end
	return branches, n
end

local function spawnBurst(configName, x, y, z, sizeScale, intensityScale, widthScale)
	local cfg = lightningConfigs[configName]
	if not cfg then return end
	sizeScale = (sizeScale and sizeScale > 0) and sizeScale or 1.0
	intensityScale = intensityScale or 1.0
	widthScale = widthScale or 1.0

	-- One master random controls most of the burst profile so visuals feel coherent:
	-- small/light variants are usually simpler and shorter-lived; large ones richer/longer.
	local sizeVarMin = mathMin(cfg.sizeVarMin, cfg.sizeVarMax)
	local sizeVarMax = mathMax(cfg.sizeVarMin, cfg.sizeVarMax)
	local sizeVarRange = mathMax(0.0001, sizeVarMax - sizeVarMin)
	local sizeVar = sizeVarMin + mathRandom() * sizeVarRange
	local complexity01 = clamp((sizeVar - sizeVarMin) / sizeVarRange, 0, 1)

	local burstSizeScale = sizeScale * sizeVar
	-- External requested size must strongly affect complexity so tiny scatter sparks
	-- become simpler (fewer branches/children/segments), not just visually smaller.
	local scaleComplexity01 = clamp((burstSizeScale - 0.25) / 0.9, 0, 1)
	complexity01 = clamp(complexity01 * 0.45 + scaleComplexity01 * 0.55, 0, 1)

	local complexityScale = lerp(0.30, 1.45, complexity01)
	local branchCount = mathMax(1, mathFloor(cfg.branchCount * complexityScale + 0.5))
	local childCount = mathMax(0, mathFloor(cfg.childCount * lerp(0.18, 1.4, complexity01) + 0.2))
	local maxDepth = cfg.maxDepth
	if burstSizeScale < 0.65 and maxDepth > 0 then
		maxDepth = maxDepth - 1
	end
	if burstSizeScale < 0.45 and maxDepth > 0 then
		maxDepth = maxDepth - 1
	end
	if complexity01 < 0.25 and maxDepth > 0 then
		maxDepth = maxDepth - 1
	elseif complexity01 > 0.8 and cfg.maxDepth > 0 then
		maxDepth = maxDepth + 1
	end
	maxDepth = clamp(maxDepth, 0, cfg.maxDepth + 1)
	local minSegments = (burstSizeScale < 0.5) and 1 or 2
	local segments = mathMax(minSegments, mathFloor(cfg.segments * lerp(0.35, 1.35, complexity01) + 0.5))
	local growFrac = clamp(cfg.growFrac * lerp(0.85, 1.15, complexity01), 0.18, 0.95)

	local intensityJitter = 1.0 + ((mathRandom() * 2.0 - 1.0) * cfg.intensityVar)
	local burstIntensity = intensityScale * lerp(0.78, 1.25, complexity01) * intensityJitter
	if burstIntensity < 0.05 then burstIntensity = 0.05 end
	if cfg.maxIntensityScale and burstIntensity > cfg.maxIntensityScale then
		burstIntensity = cfg.maxIntensityScale
	end

	local lifeJitter = 1.0 + ((mathRandom() * 2.0 - 1.0) * cfg.lifeVar)
	local burstLifeFrames = mathMax(6, mathFloor(cfg.lifeFrames * lerp(0.55, 1.40, complexity01) * lifeJitter + 0.5))

	local branches, nBranches = buildBranches(cfg, burstSizeScale, branchCount, childCount, maxDepth, growFrac)

	-- Padding for view culling: longest reachable extent + glow halo.
	local maxExtent = cfg.reach * burstSizeScale * 1.4
	local aabbPad = maxExtent + cfg.baseWidth * burstSizeScale * GLOW_WIDTH_MULT + cfg.jitterAmp

	local burst = {
		cfg = cfg,
		x = x, y = y, z = z,
		birthFrame = spGetGameFrame(),
		lifeFrames = burstLifeFrames,
		intensity = cfg.intensity * burstIntensity,
		intensityScale = burstIntensity,
		widthScale = widthScale,
		segments = segments,
		baseWidth = cfg.baseWidth * burstSizeScale,
		jitterAmp = cfg.jitterAmp * burstSizeScale,
		aabbPad = aabbPad,
		branches = branches,
		nBranches = nBranches,
	}

	if nActive >= MAX_ACTIVE then
		-- drop the oldest
		table.remove(active, 1)
		nActive = nActive - 1
	end
	nActive = nActive + 1
	active[nActive] = burst
	idleSkipCounter = 0
end

--------------------------------------------------------------------------------
-- Scheduled / scattered spawns
-- Bursts can be delayed and scattered across an area over time (e.g. the
-- commander-spawn crackle). Pending entries are kept in a queue and emitted by
-- updateBolts() once their target frame is reached.
--------------------------------------------------------------------------------
local pending  = {}
local nPending = 0
local nextPendingFrame = math.huge

local function schedule(configName, x, y, z, sizeScale, intensityScale, widthScale, atFrame)
	nPending = nPending + 1
	pending[nPending] = {
		configName = configName,
		x = x, y = y, z = z,
		sizeScale = sizeScale,
		intensityScale = intensityScale,
		widthScale = widthScale,
		frame = atFrame,
	}
	if atFrame < nextPendingFrame then
		nextPendingFrame = atFrame
	end
	idleSkipCounter = 0
end

-- Public entry point used by the sync action: dispatches a config's central
-- burst plus any scattered area sparks it defines.
local function requestLightning(configName, x, y, z, sizeScale, intensityScale)
	local cfg = lightningConfigs[configName]
	if not cfg then return end
	sizeScale = (sizeScale and sizeScale > 0) and sizeScale or 1.0
	intensityScale = intensityScale or 1.0

	local frame = spGetGameFrame()
	local startDelay = cfg.startDelay or 0

	-- Central burst (at the unit), optionally raised and delayed.
	local cx = x
	local cy = y + (cfg.centerHeight or 0)
	local cz = z
	local cSize = sizeScale * (cfg.centerSizeScale or 1.0)
	local cInt  = intensityScale * (cfg.centerIntensityScale or 1.0)
	local cWidth = cfg.centerWidthScale or 1.0
	if startDelay <= 0 then
		spawnBurst(configName, cx, cy, cz, cSize, cInt, cWidth)
	else
		schedule(configName, cx, cy, cz, cSize, cInt, cWidth, frame + startDelay)
	end

	-- Scattered area sparks crackling around the origin over time.
	local scatterCount = cfg.scatterCount or 0
	if scatterCount > 0 then
		local scatterFrames = cfg.scatterFrames or 60
		local scatterRadius = cfg.scatterRadius or 120
		local hMin = cfg.scatterHeightMin or 20
		local hMax = cfg.scatterHeightMax or 60
		local sMin = cfg.scatterSizeMin or 0.3
		local sMax = cfg.scatterSizeMax or 0.7
		local sInt = cfg.scatterIntensityScale or 1.0
		local sWidth = cfg.scatterWidthScale or 1.0
		for _ = 1, scatterCount do
			local ang = mathRandom() * 2.0 * mathPi
			local rad = mathSqrt(mathRandom()) * scatterRadius   -- uniform over disc
			local sx = x + mathCos(ang) * rad
			local sz = z + mathSin(ang) * rad
			local sy = y + hMin + mathRandom() * (hMax - hMin)
			local ss = sizeScale * (sMin + mathRandom() * (sMax - sMin))
			local at = frame + startDelay + mathFloor(mathRandom() * scatterFrames)
			schedule(configName, sx, sy, sz, ss, intensityScale * sInt, sWidth, at)
		end
	end
end

local function processPending(frame)
	if nPending == 0 then
		nextPendingFrame = math.huge
		return
	end
	local w = 0
	local nextFrame = math.huge
	for r = 1, nPending do
		local p = pending[r]
		if p.frame <= frame then
			spawnBurst(p.configName, p.x, p.y, p.z, p.sizeScale, p.intensityScale, p.widthScale)
		else
			w = w + 1
			pending[w] = p
			if p.frame < nextFrame then
				nextFrame = p.frame
			end
		end
	end
	for i = w + 1, nPending do pending[i] = nil end
	nPending = w
	nextPendingFrame = nextFrame
end

--------------------------------------------------------------------------------
-- Per-frame VBO build
--------------------------------------------------------------------------------
local function pushArm(beamData, offset, burst, br, life, alphaMul)
	local cfg = burst.cfg
	local segs = burst.segments

	-- current grown length of this arm
	local local01 = (life - br.startFrac) / br.growFrac
	if local01 <= 0 then return offset, 0 end
	if local01 > 1 then local01 = 1 end
	-- ease-out growth for a snappier "reaching" feel
	local grown = br.len * (1.0 - (1.0 - local01) * (1.0 - local01))
	if grown < 1 then return offset, 0 end

	-- per-arm pop-in alpha
	local appear = (life - br.startFrac) / BRANCH_APPEAR
	if appear > 1 then appear = 1 elseif appear < 0 then appear = 0 end
	local armAlpha = alphaMul * appear

	local ox, oy, oz = burst.x, burst.y, burst.z
	local baseSx = ox + br.sx
	local baseSy = oy + br.sy
	local baseSz = oz + br.sz
	local sx = baseSx
	local sy = baseSy
	local sz = baseSz
	-- Move the tail forward as the branch grows so lightning visually flows away
	-- from the spawn point instead of remaining fully anchored at origin.
	local flowFrac = cfg.flowFrac
	if flowFrac > 0 then
		local tailAdvance = grown * flowFrac * (local01 * local01)
		sx = sx + br.dx * tailAdvance
		sy = sy + br.dy * tailAdvance
		sz = sz + br.dz * tailAdvance
	end
	local ex = baseSx + br.dx * grown
	local ey = baseSy + br.dy * grown
	local ez = baseSz + br.dz * grown

	-- length falloff: dim toward the tip
	local lengthFalloff = 0.45

	local widthScale = br.widthScale * (burst.widthScale or 1.0)
	local feather = cfg.feather
	-- Keep intensity-driven size/glow bounded so one very bright burst does not
	-- over-bloom nearby lightning effects.
	local widthIntensityScale = clamp(burst.intensityScale, 0.70, 1.25)
	local glowIntensityScale = clamp(burst.intensityScale, 0.70, 1.20)
	local glowMult = cfg.glowBrightness * glowIntensityScale
	local tipTaper = cfg.tipTaper
	local jitterAmp = burst.jitterAmp
	local baseWidth = burst.baseWidth
	local intensityW = widthIntensityScale

	local cr, cg, cb = cfg.coreR, cfg.coreG, cfg.coreB
	local er, eg, eb = cfg.r, cfg.g, cfg.b
	local seed = br.seed
	local count = 0
	for s = 0, segs - 1 do
		beamData[offset + 1]  = sx
		beamData[offset + 2]  = sy
		beamData[offset + 3]  = sz
		beamData[offset + 4]  = baseWidth
		beamData[offset + 5]  = ex
		beamData[offset + 6]  = ey
		beamData[offset + 7]  = ez
		beamData[offset + 8]  = tipTaper
		beamData[offset + 9]  = cr
		beamData[offset + 10] = cg
		beamData[offset + 11] = cb
		beamData[offset + 12] = armAlpha
		beamData[offset + 13] = er
		beamData[offset + 14] = eg
		beamData[offset + 15] = eb
		beamData[offset + 16] = lengthFalloff
		beamData[offset + 17] = seed
		beamData[offset + 18] = s
		beamData[offset + 19] = segs
		beamData[offset + 20] = jitterAmp
		beamData[offset + 21] = intensityW   -- widthMul (brightness/size intensity)
		beamData[offset + 22] = widthScale
		beamData[offset + 23] = glowMult
		beamData[offset + 24] = feather
		offset = offset + INSTANCE_STRIDE
		count = count + 1
	end
	return offset, count
end

local function updateBolts()
	local frame = spGetGameFrame()
	if frame >= nextPendingFrame then
		processPending(frame)
	end

	if idleSkipCounter > 0 and nActive == 0 and nPending == 0 then
		idleSkipCounter = idleSkipCounter - 1
		boltVBO.usedElements = 0
		return
	end

	boltVBO.usedElements = 0
	local beamData = boltVBO.instanceData
	local beamCount = 0
	local offset = 0

	-- iterate bursts, compacting out dead ones in-place
	local w = 0
	for r = 1, nActive do
		local burst = active[r]
		local cfg = burst.cfg
		local age = frame - burst.birthFrame
		local life = age / burst.lifeFrames
		if life < 1.0 then
			w = w + 1
			active[w] = burst

			-- overall fade envelope
			local envIn  = life < FADE_IN_FRAC and (life / FADE_IN_FRAC) or 1.0
			local envOut = (1.0 - life) < FADE_OUT_FRAC and ((1.0 - life) / FADE_OUT_FRAC) or 1.0
			local alphaMul = envIn * envOut * burst.intensity

			if alphaMul > 0.001 then
				local pad = burst.aabbPad
				if spIsAABBInView(
					burst.x - pad, burst.y - pad, burst.z - pad,
					burst.x + pad, burst.y + pad, burst.z + pad
				) then
					local nBranches = burst.nBranches
					-- ensure capacity for the whole burst at once
					local need = beamCount + nBranches * burst.segments
					if need > boltVBO.maxElements then
						resizeBoltVBO(need + 128)
						beamData = boltVBO.instanceData
					end
					local branches = burst.branches
					for b = 1, nBranches do
						local pushed
						offset, pushed = pushArm(beamData, offset, burst, branches[b], life, alphaMul)
						beamCount = beamCount + pushed
					end
				end
			end
		else
			active[r] = nil
		end
	end
	-- clear any leftover slots after compaction
	for i = w + 1, nActive do active[i] = nil end
	nActive = w

	boltVBO.usedElements = beamCount
	if beamCount > 0 then
		idleSkipCounter = 0
		uploadAllElements(boltVBO)
	elseif nActive == 0 and nPending == 0 then
		idleSkipCounter = IDLE_SKIP_FRAMES
	end
end

--------------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------------
local function drawAll()
	if boltVBO.usedElements == 0 then return end

	glDepthTest(true)
	glDepthMask(false)
	glCulling(false)
	glBlending(GL_ONE, GL_ONE)

	glowShader:Activate()
	boltVBO:Draw()
	glowShader:Deactivate()

	boltShader:Activate()
	boltVBO:Draw()
	boltShader:Deactivate()

	glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	glDepthMask(true)
	glDepthTest(false)
end

--------------------------------------------------------------------------------
-- Callins
--------------------------------------------------------------------------------
local function handleSpawn(_, configName, x, y, z, sizeScale, intensityScale)
	requestLightning(configName, x, y, z, sizeScale, intensityScale)
end

function gadget:Initialize()
	if not initGL4() then return end
	gadgetHandler:AddSyncAction("envLightningSpawn", handleSpawn)
end

function gadget:Shutdown()
	gadgetHandler:RemoveSyncAction("envLightningSpawn")
	cleanupGL4()
end

function gadget:DrawWorld()
	if not boltVBO then return end
	local simFrame = spGetGameFrame()
	if simFrame ~= lastBuildFrame then
		lastBuildFrame = simFrame
		updateBolts()
	end
	drawAll()
end
