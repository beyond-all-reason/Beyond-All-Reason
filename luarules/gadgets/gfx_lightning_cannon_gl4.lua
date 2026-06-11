--------------------------------------------------------------------------------
-- Lightning Cannon GL4
-- GPU-instanced replacement for engine LightningCannon rendering.
-- Renders procedurally jagged electric arcs with per-segment offsets, variable
-- thickness, a soft additive glow halo, and optional forking sub-branches.
-- Also picks up the visual chain bolts spawned by unit_lightning_splash_dmg.lua.
--------------------------------------------------------------------------------

if gadgetHandler:IsSyncedCode() then
	return
end

function gadget:GetInfo()
	return {
		name = "Lightning Cannon GL4",
		desc = "GL4 instanced lightning arc effects for LightningCannon weapons",
		author = "Floris",
		date = "May 2026",
		license = "GNU GPL v2",
		layer = 0,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- Localized functions
--------------------------------------------------------------------------------
local spGetProjectilePosition = Engine.Shared.GetProjectilePosition
local spGetProjectileVelocity = Engine.Shared.GetProjectileVelocity
local spGetProjectileDefID = Engine.Shared.GetProjectileDefID
local spGetProjectileTeamID = Engine.Shared.GetProjectileTeamID
local spGetTeamAllyTeamID = Engine.Shared.GetTeamAllyTeamID
local spIsPosInLos = Engine.Shared.IsPosInLos
local spIsPosInAirLos = Engine.Shared.IsPosInAirLos
local spGetMyAllyTeamID = Spring.GetMyAllyTeamID
local spGetSpectatingState = Engine.Unsynced.GetSpectatingState
local spGetGameFrame = Engine.Shared.GetGameFrame
local spGetGameSpeed = Engine.Unsynced.GetGameSpeed
local spGetProjectileOwnerID = Engine.Shared.GetProjectileOwnerID
local spGetProjectilesInRectangle = Engine.Shared.GetProjectilesInRectangle

-- Subscription handle for the shared projectile dispatcher (set in Initialize).
-- When nil, we fall back to calling Spring.GetProjectilesInRectangle directly.
local dispatchHandle = nil
local spIsAABBInView = Engine.Unsynced.IsAABBInView

local glBlending = gl.Blending
local glDepthTest = gl.DepthTest
local glDepthMask = gl.DepthMask
local glCulling = gl.Culling

local GL_ONE = GL.ONE
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_SRC_ALPHA = GL.SRC_ALPHA

local mathMin = math.min
local mathMax = math.max
local mathSqrt = math.sqrt
local mathFloor = math.floor
local mathRandom = math.random

local LuaShader = gl.LuaShader
local uploadAllElements = gl.InstanceVBOTable.uploadAllElements

--------------------------------------------------------------------------------
-- Configuration
-- Each lightning bolt is rendered as N quad-instances (one per segment) sharing
-- the same per-bolt data. Adjacent segments compute their boundary points using
-- the same deterministic hash (seed, segIndex), guaranteeing the path is
-- continuous (no gaps) while still being procedurally jagged.
--------------------------------------------------------------------------------

-- VBO sizing
local INITIAL_VBO_SIZE = 256
local IDLE_SKIP_FRAMES = 3

-- Bolt geometry
local SEGMENTS_MIN = 3 -- minimum segments per bolt (short close-range bolts)
local SEGMENTS_MAX = 10 -- maximum segments per bolt (long high-range bolts)
local SEGMENTS_PER_ELMO = 0.04 -- segments added per elmo of bolt length

-- Branch / fork generation (CPU side, deterministic per-bolt seed)
local BRANCH_COUNT_MIN = 1 -- min forks for low-damage weapons
local BRANCH_COUNT_MAX = 3 -- max forks for high-damage weapons
local BRANCH_DAMAGE_REF = 200 -- damage at which BRANCH_COUNT_MAX is reached
local BRANCH_LENGTH_FRAC = 0.15 -- branch length as fraction of main-bolt length
local BRANCH_LENGTH_VAR = 0.40 -- random variation around BRANCH_LENGTH_FRAC (0..1)
local BRANCH_ANCHOR_MIN = 0.20 -- earliest spawn point on main bolt (0..1)
local BRANCH_ANCHOR_MAX = 0.95 -- latest spawn point on main bolt (0..1)
local BRANCH_ANGLE_SPREAD = 0.85 -- max angular deviation from main direction (radians ~= 49deg)
local BRANCH_WIDTH_FRAC = 0.55 -- branch width as fraction of main width
local BRANCH_JITTER_FRAC = 0.65 -- branch jitter as fraction of main jitter
local BRANCH_GLOW_FRAC = 0.55 -- branch glow brightness fraction
local BRANCH_SEGMENTS_FRAC = 0.55 -- branch segment count as fraction of main count

-- Width (base thickness for the bolt core quad)
local WIDTH_MIN = 0.25 -- minimum bolt width in elmos
local WIDTH_MAX = 1.2 -- maximum bolt width in elmos
local WIDTH_DAMAGE_REF = 250 -- damage at which WIDTH_MAX is reached
local WIDTH_THICKNESS_MULT = 0.45 -- multiplier on weapon's `thickness` to add on top

-- Jitter (perpendicular offset amplitude in elmos)
local JITTER_MIN = 2 -- baseline jitter amplitude in elmos
local JITTER_MAX = 6 -- maximum jitter for highest-damage weapons
local JITTER_DAMAGE_REF = 250 -- damage at which JITTER_MAX is reached
local JITTER_RANGE_BONUS = 0.012 -- extra jitter per elmo of bolt length
local JITTER_RANGE_BONUS_MAX = 12 -- cap on the range-derived bonus

-- Glow (wide soft halo around the bolt)
local GLOW_WIDTH_MULT = 13.0 -- glow quad width as multiple of bolt width (drawn along straight bolt axis)
local GLOW_BRIGHTNESS = 0.2 -- base additive glow brightness
local GLOW_DAMAGE_BONUS = 0.4 -- extra brightness scaling with damage (multiplier)
local GLOW_FALLOFF_POWER = 5.0 -- gaussian falloff sharpness (higher = tighter core)

-- Core brightness / color mixing
local CORE_COLOR_ADD = 0.4 -- added to weapon RGB to create the bright core color (clamped)
local CORE_BRIGHTNESS = 2.3 -- extra brightness multiplier for hot core pixels
local BRIGHTNESS_MULT = 2.5 -- overall bolt brightness multiplier
local CORE_EDGE_START = 0.03 -- |x| where core->edge color mix begins
local CORE_EDGE_END = 0.3 -- |x| where mix is fully edge color
local MIN_PIXEL_WIDTH = 0.0018 -- minimum bolt screen width (anti-aliasing at distance)
local GLOW_MIN_PIXEL_WIDTH = 0.005 -- minimum glow halo screen width (keeps glow visible far away)

-- Lifetime / fading
local BOLT_LIFE_FRAMES = 3 -- total render-frame lifetime per bolt (including ghosts)
local FADE_IN_END = 0.15 -- lifeFrac where width/alpha fade-in completes
local FADE_OUT_START = 0.5 -- lifeFrac where fade-out begins
local FLICKER_AMPLITUDE = 0.45 -- per-frame brightness flicker amplitude (0..1)
local THICKNESS_VARIATION = 0.7 -- per-segment random thickness variation (0..1)
local SEGMENT_LENGTH_VAR = 0.75 -- per-segment length variation (0..1, fraction of base segment length)
local JITTER_MAX_BOLT_FRAC = 0.07 -- cap jitter amplitude to this fraction of bolt length (keeps silhouette consistent at any zoom)
local BRUSH_MAX_JITTER_FRAC = 0.5 -- cap brush width to this fraction of jitter amplitude (prevents fat-brush chunky saw at distance)

-- Endpoint impact spark (additive billboard at the bolt's far endpoint)
local IMPACT_SIZE_MIN = 5 -- spark billboard min size in elmos
local IMPACT_SIZE_MAX = 18 -- spark billboard max size in elmos
local IMPACT_SIZE_DAMAGE_REF = 250
local IMPACT_BRIGHTNESS = 1.5 -- additive brightness of impact billboard

-- LOS
local USE_AIR_LOS = true -- if true, use air-LOS (less restrictive)
local spLosCheck = USE_AIR_LOS and spIsPosInAirLos or spIsPosInLos

-- Textures
local impactTexture = "bitmaps/projectiletextures/flare2.tga"

-- Per-weapon segment cap (must not exceed SEGMENTS_MAX)
if SEGMENTS_MAX > 64 then
	SEGMENTS_MAX = 64
end

--------------------------------------------------------------------------------
-- Per-weapon configuration table
-- All "scalable" defaults can be overridden per weapondef via customParams:
--   lightning_jitter           (multiplier on auto jitter)
--   lightning_thickness        (multiplier on auto width)
--   lightning_glow             (multiplier on auto glow brightness)
--   lightning_branches         (override branch count, integer)
--   lightning_branch_length    (multiplier on branch length fraction)
--   lightning_branch_angle     (override max branch angle, radians)
--   lightning_segments         (override segment count, integer)
--   lightning_impact_size      (override endpoint spark size, elmos)
--   lightning_color_r/g/b      (override edge color)
--   lightning_core_color_r/g/b (override hot core color)
--   lightning_no_render        ("1" to skip this weapon entirely)
--------------------------------------------------------------------------------
local weaponConfigs = {}

local function clamp(v, lo, hi)
	return v < lo and lo or (v > hi and hi or v)
end

local function buildWeaponConfig(weaponID, weaponDef)
	if weaponDef.type ~= "LightningCannon" then
		return
	end
	local cp = weaponDef.customParams or {}
	if cp.lightning_no_render == "1" or cp.bogus then
		return
	end

	-- Visual params (read originals stashed by alldefs_post; fall back to live values)
	local vis = weaponDef.visuals or {}
	local r = tonumber(cp.lightning_color_r) or vis.colorR or 0.5
	local g = tonumber(cp.lightning_color_g) or vis.colorG or 0.5
	local b = tonumber(cp.lightning_color_b) or vis.colorB or 1.0

	local coreR = tonumber(cp.lightning_core_color_r) or mathMin(1, r + CORE_COLOR_ADD)
	local coreG = tonumber(cp.lightning_core_color_g) or mathMin(1, g + CORE_COLOR_ADD)
	local coreB = tonumber(cp.lightning_core_color_b) or mathMin(1, b + CORE_COLOR_ADD)

	local origThickness = tonumber(cp.lightning_thickness_orig) or weaponDef.thickness or 1.5
	local damage = (weaponDef.damages and tonumber(weaponDef.damages[0])) or 30
	local range = weaponDef.range or 300

	-- Normalized damage / range factors (0..1, capped)
	local damageNorm = clamp(damage / WIDTH_DAMAGE_REF, 0, 1)
	local damageNormJ = clamp(damage / JITTER_DAMAGE_REF, 0, 1)
	local damageNormB = clamp(damage / BRANCH_DAMAGE_REF, 0, 1)
	local damageNormI = clamp(damage / IMPACT_SIZE_DAMAGE_REF, 0, 1)

	-- Width: damage-scaled base + thickness contribution, all user-multipliable
	local widthMult = tonumber(cp.lightning_thickness) or 1.0
	local baseWidth = (WIDTH_MIN + (WIDTH_MAX - WIDTH_MIN) * damageNorm + origThickness * WIDTH_THICKNESS_MULT) * widthMult

	-- Jitter: damage-scaled, with range bonus, user-multipliable
	local jitterMult = tonumber(cp.lightning_jitter) or 1.0
	local rangeBonus = mathMin(range * JITTER_RANGE_BONUS, JITTER_RANGE_BONUS_MAX)
	local jitterAmp = (JITTER_MIN + (JITTER_MAX - JITTER_MIN) * damageNormJ + rangeBonus) * jitterMult

	-- Glow brightness: damage-scaled, user-multipliable
	local glowMult = tonumber(cp.lightning_glow) or 1.0
	local glowBrightness = GLOW_BRIGHTNESS * (1.0 + GLOW_DAMAGE_BONUS * damageNorm) * glowMult

	-- Branches: damage-scaled, override-able
	local branchCount
	if cp.lightning_branches then
		branchCount = clamp(mathFloor(tonumber(cp.lightning_branches) + 0.5), 0, 16)
	else
		branchCount = mathFloor(BRANCH_COUNT_MIN + (BRANCH_COUNT_MAX - BRANCH_COUNT_MIN) * damageNormB + 0.5)
	end
	local branchLengthFrac = BRANCH_LENGTH_FRAC * (tonumber(cp.lightning_branch_length) or 1.0)
	local branchAngleSpread = tonumber(cp.lightning_branch_angle) or BRANCH_ANGLE_SPREAD

	-- Segments: from explicit override, or scaled by weapon range
	local segments
	if cp.lightning_segments then
		segments = clamp(mathFloor(tonumber(cp.lightning_segments) + 0.5), 4, SEGMENTS_MAX)
	else
		segments = clamp(mathFloor(SEGMENTS_MIN + range * SEGMENTS_PER_ELMO + 0.5), SEGMENTS_MIN, SEGMENTS_MAX)
	end
	local branchSegments = clamp(mathFloor(segments * BRANCH_SEGMENTS_FRAC + 0.5), 4, SEGMENTS_MAX)

	-- Endpoint impact spark
	local impactSize = tonumber(cp.lightning_impact_size) or (IMPACT_SIZE_MIN + (IMPACT_SIZE_MAX - IMPACT_SIZE_MIN) * damageNormI)

	-- AABB padding accounts for glow quad + max jitter offset
	local aabbPad = baseWidth * GLOW_WIDTH_MULT + jitterAmp + impactSize

	weaponConfigs[weaponID] = {
		r = r,
		g = g,
		b = b,
		coreR = coreR,
		coreG = coreG,
		coreB = coreB,
		baseWidth = baseWidth,
		jitterAmp = jitterAmp,
		glowBrightness = glowBrightness,
		branchCount = branchCount,
		branchLengthFrac = branchLengthFrac,
		branchAngleSpread = branchAngleSpread,
		segments = segments,
		branchSegments = branchSegments,
		branchWidth = baseWidth * BRANCH_WIDTH_FRAC,
		branchJitter = jitterAmp * BRANCH_JITTER_FRAC,
		branchGlow = glowBrightness * BRANCH_GLOW_FRAC,
		impactSize = impactSize,
		damage = damage,
		range = range,
		invRangeSq = 1.0 / mathMax(range * range, 1),
		aabbPad = aabbPad,
	}
end

for weaponID, weaponDef in pairs(WeaponDefs) do
	buildWeaponConfig(weaponID, weaponDef)
end

-- Bail out early if there are no LightningCannon weapons
local hasConfigs = false
for _ in pairs(weaponConfigs) do
	hasConfigs = true
	break
end
if not hasConfigs then
	function gadget:Initialize()
		gadgetHandler:RemoveGadget()
	end
	return
end

--------------------------------------------------------------------------------
-- Per-bolt tracking
-- Each unique projectile gets a stable seed so the procedural jagged shape is
-- consistent across the few frames it remains on screen. Tracked by proID;
-- ghost rendering continues for BOLT_LIFE_FRAMES after the projectile is gone.
--------------------------------------------------------------------------------
local tracked = {} -- proID -> { cfg, px,py,pz, ex,ey,ez, seed, firstSeen, lastSeenFrame, ownerAllyTeam }
local liveSet = {} -- proID -> true (reused; cleared each frame)
local liveList = {}
local removeList = {}
local hasTracked = false

-- Object pools: lightning bolts are short-lived (a few sim frames each), so the
-- per-bolt tracked record and its branch geometry array would otherwise be
-- allocated and discarded continuously, producing significant GC pressure
-- under sustained lightning fire. Recycle them through free lists.
local recPool = {}
local recPoolN = 0
local branchListPool = {}
local branchListPoolN = 0
local branchPool = {}
local branchPoolN = 0

local function releaseBranchList(list)
	if not list then
		return
	end
	for i = 1, #list do
		local b = list[i]
		if b then
			branchPoolN = branchPoolN + 1
			branchPool[branchPoolN] = b
			list[i] = nil
		end
	end
	branchListPoolN = branchListPoolN + 1
	branchListPool[branchListPoolN] = list
end

local function releaseRec(rec)
	if rec.branches then
		releaseBranchList(rec.branches)
		rec.branches = nil
	end
	rec.cfg = nil
	recPoolN = recPoolN + 1
	recPool[recPoolN] = rec
end
local idleSkipCounter = 0
local lastBuildFrame = -1 -- last sim frame for which the VBO was rebuilt

-- Paused-state camera tracking: while paused, only rebuild when camera moves
-- (bolt state is frozen, so unchanged camera == unchanged output).
local lastUpdateWasPaused = false
local pausedCamX, pausedCamY, pausedCamZ = 0, 0, 0
local pausedCamDX, pausedCamDY, pausedCamDZ = 0, 0, 0
local pausedLastRebuildTimer = nil
local PAUSED_MOVE_MIN_INTERVAL = 0.05

-- Cached spectating / ally
local cachedAllyTeamID = spGetMyAllyTeamID()
local cachedSpecFullView = false

-- Last sim frame in which DrawWorld ran (skip GameFrame redundant scan when keeping up)

local mapSizeX = Game.mapSizeX
local mapSizeZ = Game.mapSizeZ

--------------------------------------------------------------------------------
-- Shader sources
--
-- Bolt VS:
--   Each instance is ONE quad for ONE segment of a bolt. Per-instance attributes
--   carry the WHOLE bolt's start/end and a segIndex / segCount. The vertex shader
--   computes t0 = segIndex/segCount and t1 = (segIndex+1)/segCount, then offsets
--   both endpoints perpendicular to the bolt direction using a hash of
--   (seed, segIndex). Because hash(seed, k) is deterministic, segment N's end
--   point lines up exactly with segment N+1's start point: continuous polyline.
--
--   Per-segment thickness wobble + per-bolt time flicker produce the "alive"
--   look. Width is also expanded to MIN_PIXEL_WIDTH at distance with alpha-dim
--   compensation, matching the beam laser approach.
--------------------------------------------------------------------------------

local commonHash = [[
float hash11(float x) {
	return fract(sin(x * 12.9898) * 43758.5453);
}
vec3 hash31(float x) {
	return vec3(hash11(x), hash11(x + 17.13), hash11(x + 31.71)) * 2.0 - 1.0;
}
]]

local boltVsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 10000

//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

// Quad vertex: xy = corner (-1..1), zw = UV
layout (location = 0) in vec4 position_xy_uv;

// Per-instance
layout (location = 1) in vec4 startPosAndWidth;   // xyz = bolt start, w = base width
layout (location = 2) in vec4 endPosAndLife;       // xyz = bolt end,   w = life fraction (0..1)
layout (location = 3) in vec4 coreColor;           // rgb = core color, a = alpha
layout (location = 4) in vec4 edgeColor;           // rgb = edge color, a = range falloff
layout (location = 5) in vec4 boltParams;          // x = seed, y = segIndex, z = segCount, w = jitterAmp
layout (location = 6) in vec4 extraParams;         // x = isBranch flag, y = widthScale, z = glowMult, w = impactSize

out DataVS {
	vec3 vCoreColor;
	vec3 vEdgeColor;
	float alpha;
	float widthPos;
	float coverage;
	float segPos;      // position along the bolt (0 at start, 1 at end), used for tip taper
};

float hash11(float x) {
	return fract(sin(x * 12.9898) * 43758.5453);
}
vec3 hash31(float x) {
	return vec3(hash11(x), hash11(x + 17.13), hash11(x + 31.71)) * 2.0 - 1.0;
}

void cullVertex() {
	gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
}

void main()
{
	vec3 startPos = startPosAndWidth.xyz;
	float baseWidth = startPosAndWidth.w * extraParams.y;
	vec3 endPos = endPosAndLife.xyz;
	float lifeFrac = endPosAndLife.w;

	float seed     = boltParams.x;
	float segIndex = boltParams.y;
	float segCount = boltParams.z;
	float jitterAmp= boltParams.w;

	vec3 boltDir = endPos - startPos;
	float boltLen = length(boltDir);
	if (boltLen < 0.01 || segCount < 1.0) { cullVertex(); return; }
	vec3 forward = boltDir / boltLen;

	// Two consistent perpendicular axes (Gram-Schmidt around an arbitrary up)
	vec3 upRef = abs(forward.y) > 0.9 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0);
	vec3 perpA = normalize(cross(forward, upRef));
	vec3 perpB = normalize(cross(forward, perpA));

	// Time-quantized flicker phase (one phase per render frame): the bolt fully
	// "rerolls" its jitter pattern a few times per second for a more alive look
	// while still being stable within a single rendered frame.
	float frameTick = floor(timeInfo.z * 30.0);

	// Per-segment t along bolt; this vertex is at either t0 or t1 depending on quad.y.
	// SEGMENT_LENGTH_VAR jitters each interior boundary by a deterministic hash of
	// (seed, boundaryIndex). Endpoints (index 0 and segCount) stay fixed so the
	// bolt always meets its start/end. Adjacent segments share the boundary hash,
	// so segment N's t1 == segment N+1's t0 (no gaps).
	float yNorm = position_xy_uv.y * 0.5 + 0.5;  // 0..1: 0 = segment start, 1 = segment end
	float invSeg = 1.0 / segCount;
	float lenVarAmp = SEGMENT_LENGTH_VAR * invSeg * 0.5;
	float b0 = segIndex;
	float b1 = segIndex + 1.0;
	float off0 = (b0 > 0.5 && b0 < segCount - 0.5) ? (hash11(seed * 41.0 + b0 * 17.3 + frameTick * 0.29) * 2.0 - 1.0) * lenVarAmp : 0.0;
	float off1 = (b1 > 0.5 && b1 < segCount - 0.5) ? (hash11(seed * 41.0 + b1 * 17.3 + frameTick * 0.29) * 2.0 - 1.0) * lenVarAmp : 0.0;
	float t0 = b0 * invSeg + off0;
	float t1 = b1 * invSeg + off1;
	float tHere = mix(t0, t1, yNorm);
	// Also compute the OTHER endpoint of this segment so we can derive a local
	// tangent for perpendicular offsetting (matches between adjacent segments
	// because both share the same hash inputs at the boundary).
	float tNext = (yNorm < 0.5) ? t1 : t0;

	// Hash inputs (combine seed + segment-corner + frame for organic per-shot pattern)
	float keyHere = seed * 13.0 + tHere * 91.0 + frameTick * 0.37;
	float keyNext = seed * 13.0 + tNext * 91.0 + frameTick * 0.37;

	// Distance-based jitter compensation: when the bolt width gets clamped UP
	// to MIN_PIXEL_WIDTH at distance, the unmodified world-space jitter (still
	// at full elmos) traces a tight zigzag with an artificially fat brush,
	// producing a chunky "pingpong" look from far away. Scale the jitter down
	// by the same coverage ratio so the silhouette stays visually similar at
	// any zoom: close-up = full jaggedness, far away = naturally smoothed out.
	// Zoom-invariant jitter: bounded to a fraction of bolt length so the
	// silhouette is identical at every zoom level (jitter and length both live
	// in world space, so their ratio is preserved under projection).
	float jitterScale = min(jitterAmp, boltLen * JITTER_MAX_BOLT_FRAC);

	// Perpendicular jitter offset (zero at the bolt ends so it stays anchored)
	float endFadeHere = sin(tHere * 3.14159);
	float endFadeNext = sin(tNext * 3.14159);
	vec3 jitHere = (perpA * hash11(keyHere) + perpB * hash11(keyHere + 7.7)) * 2.0 - (perpA + perpB);
	vec3 jitNext = (perpA * hash11(keyNext) + perpB * hash11(keyNext + 7.7)) * 2.0 - (perpA + perpB);
	jitHere *= jitterScale * endFadeHere;
	jitNext *= jitterScale * endFadeNext;

	vec3 posHere = mix(startPos, endPos, tHere) + jitHere;
	vec3 posNext = mix(startPos, endPos, tNext) + jitNext;

	// Local tangent for this segment (drives perpendicular billboard direction)
	vec3 segDir = posNext - posHere;
	float segLen = length(segDir);
	if (segLen < 0.0001) { cullVertex(); return; }
	segDir /= segLen;

	// Camera-facing perpendicular for width quad
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

	// Lifetime fade in/out
	float fadeIn  = smoothstep(0.0, FADE_IN_END, lifeFrac);
	float fadeOut = 1.0 - smoothstep(FADE_OUT_START, 1.0, lifeFrac);
	float lifePulse = fadeIn * fadeOut;
	if (lifePulse < 0.001) { cullVertex(); return; }

	// Per-segment thickness variation + per-bolt flicker
	float segWobble = mix(1.0 - THICKNESS_VARIATION, 1.0 + THICKNESS_VARIATION,
		hash11(seed * 3.1 + segIndex * 5.7 + frameTick * 0.21));
	float flickerSeed = seed * 0.97 + frameTick * 0.13;
	float flicker = 1.0 - FLICKER_AMPLITUDE * 0.5 + FLICKER_AMPLITUDE * hash11(flickerSeed);

	float width = baseWidth * lifePulse * segWobble * flicker;

	// Min-pixel-width inflation with alpha compensation
	float camDist = length(camPos - mix(startPos, endPos, 0.5));
	float minWidth = camDist * MIN_PIXEL_WIDTH;
	// Cap the inflated width to a fraction of the jitter amplitude so the
	// per-segment brush rotation never exceeds the path wiggle (otherwise the
	// brush teeth become visible as a chunky saw at extreme zoom-out).
	minWidth = min(minWidth, jitterScale * BRUSH_MAX_JITTER_FRAC);
	float coverageVal = clamp(width / max(minWidth, 0.001), 0.0, 1.0);
	width = max(width, minWidth);

	vec3 vertexWorld = posHere + right * position_xy_uv.x * width;
	gl_Position = cameraViewProj * vec4(vertexWorld, 1.0);

	vCoreColor = coreColor.rgb;
	vEdgeColor = edgeColor.rgb;
	widthPos = position_xy_uv.x;
	coverage = coverageVal;
	segPos = tHere;

	float rangeFalloff = edgeColor.a;
	float alphaFalloff = 1.0 - rangeFalloff * tHere;
	alpha = coreColor.a * lifePulse * alphaFalloff * coverageVal * flicker;
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
	float segPos;
};

out vec4 fragColor;

void main(void)
{
	float edgeDist = abs(widthPos);
	float fw = fwidth(edgeDist);
	float aaStart = CORE_EDGE_START - fw * 0.5;
	float aaEnd   = max(CORE_EDGE_END, CORE_EDGE_START + fw);
	float coreFactor = 1.0 - smoothstep(aaStart, aaEnd, edgeDist);

	// Radial alpha falloff across width (no texture needed; pure procedural)
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

--------------------------------------------------------------------------------
-- Glow shader (wide soft halo around the same jagged path)
--------------------------------------------------------------------------------
-- The glow pass intentionally IGNORES the per-segment jitter and uses the
-- straight bolt axis (start -> end) with the OVERALL bolt forward direction
-- for every segment. This makes all per-segment glow quads share the same
-- plane and orientation, so they butt edge-to-edge into one continuous
-- camera-facing strip. With per-segment local tangents (like the bolt body),
-- wide glow quads create visible flat rectangles at every angle change.
local glowVsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 30000

//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

layout (location = 0) in vec4 position_xy_uv;
layout (location = 1) in vec4 startPosAndWidth;
layout (location = 2) in vec4 endPosAndLife;
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
};

float hash11(float x) {
	return fract(sin(x * 12.9898) * 43758.5453);
}

void main()
{
	vec3 startPos = startPosAndWidth.xyz;
	float baseWidth = startPosAndWidth.w * extraParams.y;
	vec3 endPos = endPosAndLife.xyz;
	float lifeFrac = endPosAndLife.w;

	float seed     = boltParams.x;
	float segIndex = boltParams.y;
	float segCount = boltParams.z;

	vec3 boltDir = endPos - startPos;
	float boltLen = length(boltDir);
	if (boltLen < 0.01 || segCount < 1.0) { gl_Position = vec4(2.0,2.0,2.0,1.0); return; }
	// Glow is drawn as ONE quad per bolt spanning the full length (start->end).
	// All segIndex > 0 instances are culled here, saving (N-1)/N of glow shader work.
	if (segIndex > 0.5) { gl_Position = vec4(2.0,2.0,2.0,1.0); return; }
	vec3 forward = boltDir / boltLen;

	// Lifetime envelope first so we can early-out
	float fadeIn  = smoothstep(0.0, FADE_IN_END, lifeFrac);
	float fadeOut = 1.0 - smoothstep(FADE_OUT_START, 1.0, lifeFrac);
	float lifePulse = fadeIn * fadeOut;
	if (lifePulse < 0.001) { gl_Position = vec4(2.0,2.0,2.0,1.0); return; }

	// Position on the STRAIGHT bolt axis (no jitter). yNorm = 0 at start, 1 at end.
	float yNorm = position_xy_uv.y * 0.5 + 0.5;
	float tHere = yNorm;
	vec3 posOnAxis = mix(startPos, endPos, tHere);

	// Camera-facing perpendicular based on the OVERALL bolt forward (constant
	// across all segments of this bolt, so quads share orientation).
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

	// Slight per-bolt flicker (same hash key as the bolt body so they match)
	float frameTick = floor(timeInfo.z * 30.0);
	float flickerSeed = seed * 0.97 + frameTick * 0.13;
	float flicker = 1.0 - FLICKER_AMPLITUDE * 0.5 + FLICKER_AMPLITUDE * hash11(flickerSeed);
	float glowWidth = baseWidth * GLOW_WIDTH_MULT * lifePulse * flicker;

	// Min-pixel-width inflation with alpha compensation: keep the glow halo
	// visible when zoomed out (otherwise it shrinks to nothing while the bolt
	// core's own min-pixel clamp leaves a fat plain stripe behind).
	float camDist = length(camPos - posOnAxis);
	float minWidth = camDist * GLOW_MIN_PIXEL_WIDTH;
	float coverageVal = clamp(glowWidth / max(minWidth, 0.001), 0.0, 1.0);
	glowWidth = max(glowWidth, minWidth);

	vec3 vertexWorld = posOnAxis + right * position_xy_uv.x * glowWidth;
	gl_Position = cameraViewProj * vec4(vertexWorld, 1.0);

	widthPos = position_xy_uv.x;
	// Pass tHere through and compute the sin in the FS. Doing sin() in the VS
	// would make the value at the two end-vertices both 0 and the GPU's linear
	// interpolation would yield 0 across the entire quad (since the quad now
	// spans the full bolt length); only per-pixel sin gives the proper bell.
	lengthT = tHere;
	glowColor = edgeColor.rgb;
	float rangeFalloff = edgeColor.a;
	float alphaFalloff = 1.0 - rangeFalloff * tHere;
	alpha = coreColor.a * lifePulse * alphaFalloff * flicker * coverageVal;
	glowMult = extraParams.z;
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
};

out vec4 fragColor;

void main(void)
{
	float edgeDist = abs(widthPos);
	if (edgeDist >= 1.0) discard;
	// Gaussian-like falloff so quad edges fade to zero quickly (hides quad outlines).
	// GLOW_FALLOFF_POWER controls sharpness: higher = tighter core, longer dim tail.
	float g = exp(-edgeDist * edgeDist * GLOW_FALLOFF_POWER);
	// Subtract the value at the edge so the curve actually reaches 0 at |x|=1
	// (otherwise a residual constant produces the rectangular outline).
	float edgeVal = exp(-GLOW_FALLOFF_POWER);
	float falloff = max(g - edgeVal, 0.0) / max(1.0 - edgeVal, 0.0001);
	// Anchor glow to zero at both bolt ends. Computed in FS so per-pixel sin
	// gives the proper bell shape across the full-bolt quad.
	float lengthEndFade = sin(clamp(lengthT, 0.0, 1.0) * 3.14159);
	falloff *= lengthEndFade;
	vec3 col = glowColor * (falloff * alpha * glowMult);
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	if (lum < 0.001) discard;
	fragColor = vec4(col, 0.0);
}
]]

--------------------------------------------------------------------------------
-- Impact spark (camera-facing billboard at the bolt's far endpoint).
-- Reuses the same instance VBO; rendered only for segIndex == 0 instances of
-- main bolts (extraParams.x < 0.5 and extraParams.w > 0). Branches have
-- extraParams.w = 0 so they emit no spark.
--------------------------------------------------------------------------------
local impactVsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 50000

//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

layout (location = 0) in vec4 position_xy_uv;
layout (location = 2) in vec4 endPosAndLife;
layout (location = 3) in vec4 coreColor;
layout (location = 5) in vec4 boltParams;
layout (location = 6) in vec4 extraParams;

out DataVS {
	vec2 texCoords;
	vec3 vColor;
	float alpha;
};

float hash11(float x) {
	return fract(sin(x * 12.9898) * 43758.5453);
}

void main()
{
	float segIndex  = boltParams.y;
	float impactSize= extraParams.w;
	if (segIndex > 0.5 || impactSize <= 0.0) {
		gl_Position = vec4(2.0,2.0,2.0,1.0); return;
	}

	vec3 worldPos = endPosAndLife.xyz;
	float lifeFrac = endPosAndLife.w;

	float fadeIn  = smoothstep(0.0, FADE_IN_END, lifeFrac);
	float fadeOut = 1.0 - smoothstep(FADE_OUT_START, 1.0, lifeFrac);
	float lifePulse = fadeIn * fadeOut;
	if (lifePulse < 0.001) { gl_Position = vec4(2.0,2.0,2.0,1.0); return; }

	float frameTick = floor(timeInfo.z * 30.0);
	float seed = boltParams.x;
	float flicker = 1.0 - FLICKER_AMPLITUDE * 0.5 + FLICKER_AMPLITUDE * hash11(seed * 0.97 + frameTick * 0.13);

	vec3 camRight = cameraViewInv[0].xyz;
	vec3 camUp    = cameraViewInv[1].xyz;
	float size = impactSize * lifePulse * flicker;
	vec3 vert = worldPos
		+ camRight * position_xy_uv.x * size
		+ camUp    * position_xy_uv.y * size;

	gl_Position = cameraViewProj * vec4(vert, 1.0);
	texCoords = position_xy_uv.zw;
	vColor = coreColor.rgb;
	alpha = coreColor.a * lifePulse * flicker;
}
]]

local impactFsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 60000

//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

uniform sampler2D impactTex;

in DataVS {
	vec2 texCoords;
	vec3 vColor;
	float alpha;
};

out vec4 fragColor;

void main(void)
{
	vec4 tex = texture(impactTex, texCoords);
	float shape = max(tex.a, dot(tex.rgb, vec3(0.299, 0.587, 0.114)));
	if (shape < 0.001) discard;
	vec3 col = vColor * shape * alpha * IMPACT_BRIGHTNESS * BRIGHTNESS_MULT;
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	if (lum < 0.001) discard;
	fragColor = vec4(col, 0.0);
}
]]

--------------------------------------------------------------------------------
-- Shader configs: numeric values consumed as GLSL #defines.
-- Lua's tostring() strips ".0" from whole numbers (3.0 -> "3"), which then
-- becomes a GLSL integer literal and breaks mix()/smoothstep() overload
-- resolution. Adding a tiny epsilon keeps the decimal.
--------------------------------------------------------------------------------
local function ensureFloatDefines(cfg)
	for k, v in pairs(cfg) do
		if type(v) == "number" and v == math.floor(v) then
			cfg[k] = v + 0.00001
		end
	end
	return cfg
end

local boltShaderConfig = {
	FADE_IN_END = FADE_IN_END,
	FADE_OUT_START = FADE_OUT_START,
	FLICKER_AMPLITUDE = FLICKER_AMPLITUDE,
	THICKNESS_VARIATION = THICKNESS_VARIATION,
	SEGMENT_LENGTH_VAR = SEGMENT_LENGTH_VAR,
	JITTER_MAX_BOLT_FRAC = JITTER_MAX_BOLT_FRAC,
	BRUSH_MAX_JITTER_FRAC = BRUSH_MAX_JITTER_FRAC,
	CORE_EDGE_START = CORE_EDGE_START,
	CORE_EDGE_END = CORE_EDGE_END,
	CORE_BRIGHTNESS = CORE_BRIGHTNESS,
	BRIGHTNESS_MULT = BRIGHTNESS_MULT,
	MIN_PIXEL_WIDTH = MIN_PIXEL_WIDTH,
}

local glowShaderConfig = {
	FADE_IN_END = FADE_IN_END,
	FADE_OUT_START = FADE_OUT_START,
	FLICKER_AMPLITUDE = FLICKER_AMPLITUDE,
	GLOW_WIDTH_MULT = GLOW_WIDTH_MULT,
	GLOW_FALLOFF_POWER = GLOW_FALLOFF_POWER,
	GLOW_MIN_PIXEL_WIDTH = GLOW_MIN_PIXEL_WIDTH,
}

local impactShaderConfig = {
	FADE_IN_END = FADE_IN_END,
	FADE_OUT_START = FADE_OUT_START,
	FLICKER_AMPLITUDE = FLICKER_AMPLITUDE,
	IMPACT_BRIGHTNESS = IMPACT_BRIGHTNESS,
	BRIGHTNESS_MULT = BRIGHTNESS_MULT,
}

--------------------------------------------------------------------------------
-- GL4 state
--------------------------------------------------------------------------------
local boltVBO
local boltShader
local glowShader
local impactShader

local function goodbye(reason)
	Engine.Shared.Echo("[Lightning Cannon GL4] removing self: " .. tostring(reason))
	gadgetHandler:RemoveGadget()
end

local function initGL4()
	ensureFloatDefines(boltShaderConfig)
	ensureFloatDefines(glowShaderConfig)
	ensureFloatDefines(impactShaderConfig)

	boltShader = LuaShader.CheckShaderUpdates({
		vsSrc = boltVsSrc,
		fsSrc = boltFsSrc,
		shaderName = "LightningCannonBoltGL4",
		uniformFloat = {},
		shaderConfig = boltShaderConfig,
		forceupdate = true,
	})
	if not boltShader then
		goodbye("Failed to compile bolt shader")
		return false
	end

	glowShader = LuaShader.CheckShaderUpdates({
		vsSrc = glowVsSrc,
		fsSrc = glowFsSrc,
		shaderName = "LightningCannonGlowGL4",
		uniformFloat = {},
		shaderConfig = glowShaderConfig,
		forceupdate = true,
	})
	if not glowShader then
		goodbye("Failed to compile glow shader")
		return false
	end

	impactShader = LuaShader.CheckShaderUpdates({
		vsSrc = impactVsSrc,
		fsSrc = impactFsSrc,
		shaderName = "LightningCannonImpactGL4",
		uniformInt = { impactTex = 0 },
		uniformFloat = {},
		shaderConfig = impactShaderConfig,
		forceupdate = true,
	})
	if not impactShader then
		goodbye("Failed to compile impact shader")
		return false
	end

	local quadVBO, numVertices = gl.InstanceVBOTable.makeRectVBO(-1, -1, 1, 1, 0, 0, 1, 1, "lightningCannonQuadVBO")
	local indexVBO = gl.InstanceVBOTable.makeRectIndexVBO("lightningCannonIndexVBO")

	local boltLayout = {
		{ id = 1, name = "startPosAndWidth", size = 4 },
		{ id = 2, name = "endPosAndLife", size = 4 },
		{ id = 3, name = "coreColor", size = 4 },
		{ id = 4, name = "edgeColor", size = 4 },
		{ id = 5, name = "boltParams", size = 4 },
		{ id = 6, name = "extraParams", size = 4 },
	}
	boltVBO = gl.InstanceVBOTable.makeInstanceVBOTable(boltLayout, INITIAL_VBO_SIZE, "lightningCannonVBO")
	if not boltVBO then
		goodbye("Failed to create bolt VBO")
		return false
	end
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
	while newMax < needed do
		newMax = newMax * 2
	end
	boltVBO.maxElements = newMax
	local newInstanceVBO = gl.GetVBO(GL.ARRAY_BUFFER, true)
	newInstanceVBO:Define(newMax, boltVBO.layout)
	boltVBO.instanceVBO:Delete()
	boltVBO.instanceVBO = newInstanceVBO
	local data = boltVBO.instanceData
	local step = boltVBO.instanceStep
	for i = #data + 1, step * newMax do
		data[i] = 0
	end
	boltVBO.VAO:Delete()
	boltVBO.VAO = boltVBO:makeVAOandAttach(boltVBO.vertexVBO, boltVBO.instanceVBO)
	boltVBO.VAO:AttachIndexBuffer(boltVBO.indexVBO)
end

local function cleanupGL4()
	if boltVBO then
		boltVBO:Delete()
		boltVBO = nil
	end
end

--------------------------------------------------------------------------------
-- Per-frame scan + VBO upload
--------------------------------------------------------------------------------

-- Push one segment-instance into beamData
local function pushSegment(beamData, offset, cfg, px, py, pz, ex, ey, ez, lifeFrac, seed, segIndex, segCount, jitterAmp, isBranch, widthScale, glowMult, impactSize, intensityFalloff)
	beamData[offset + 1] = px
	beamData[offset + 2] = py
	beamData[offset + 3] = pz
	beamData[offset + 4] = cfg.baseWidth
	beamData[offset + 5] = ex
	beamData[offset + 6] = ey
	beamData[offset + 7] = ez
	beamData[offset + 8] = lifeFrac
	beamData[offset + 9] = cfg.coreR
	beamData[offset + 10] = cfg.coreG
	beamData[offset + 11] = cfg.coreB
	beamData[offset + 12] = 1.0
	beamData[offset + 13] = cfg.r
	beamData[offset + 14] = cfg.g
	beamData[offset + 15] = cfg.b
	beamData[offset + 16] = intensityFalloff
	beamData[offset + 17] = seed
	beamData[offset + 18] = segIndex
	beamData[offset + 19] = segCount
	beamData[offset + 20] = jitterAmp
	beamData[offset + 21] = isBranch
	beamData[offset + 22] = widthScale
	beamData[offset + 23] = glowMult
	beamData[offset + 24] = impactSize
end

local INSTANCE_STRIDE = 24

-- Reused branch position scratch (avoids allocations in hot loop)
local function emitBolt(beamData, offset, beamCount, cfg, t, lifeFrac)
	-- Range falloff: longer bolts get dimmer toward the tip (matches beam laser)
	local vx = t.ex - t.px
	local vy = t.ey - t.py
	local vz = t.ez - t.pz
	local boltLenSq = vx * vx + vy * vy + vz * vz
	local intensity = 0.1 + 0.4 * mathMin(boltLenSq * cfg.invRangeSq, 1.0)

	-- Localize all per-bolt cfg fields once (avoid table lookups in the hot inner loop)
	local cBaseWidth = cfg.baseWidth
	local cCoreR, cCoreG, cCoreB = cfg.coreR, cfg.coreG, cfg.coreB
	local cR, cG, cB = cfg.r, cfg.g, cfg.b
	local cJitterAmp = cfg.jitterAmp
	local cGlowB = cfg.glowBrightness
	local cImpactSize = cfg.impactSize
	local tPx, tPy, tPz = t.px, t.py, t.pz
	local tEx, tEy, tEz = t.ex, t.ey, t.ez
	local tSeed = t.seed

	-- Main bolt: segCount segment-instances (inlined pushSegment for hot path)
	local segs = cfg.segments
	for s = 0, segs - 1 do
		beamData[offset + 1] = tPx
		beamData[offset + 2] = tPy
		beamData[offset + 3] = tPz
		beamData[offset + 4] = cBaseWidth
		beamData[offset + 5] = tEx
		beamData[offset + 6] = tEy
		beamData[offset + 7] = tEz
		beamData[offset + 8] = lifeFrac
		beamData[offset + 9] = cCoreR
		beamData[offset + 10] = cCoreG
		beamData[offset + 11] = cCoreB
		beamData[offset + 12] = 1.0
		beamData[offset + 13] = cR
		beamData[offset + 14] = cG
		beamData[offset + 15] = cB
		beamData[offset + 16] = intensity
		beamData[offset + 17] = tSeed
		beamData[offset + 18] = s
		beamData[offset + 19] = segs
		beamData[offset + 20] = cJitterAmp
		beamData[offset + 21] = 0.0 -- isBranch
		beamData[offset + 22] = 1.0 -- widthScale
		beamData[offset + 23] = cGlowB
		beamData[offset + 24] = (s == 0) and cImpactSize or 0.0
		offset = offset + INSTANCE_STRIDE
		beamCount = beamCount + 1
	end

	-- Branches: each branch is its own short jagged bolt forking off the main path.
	-- Geometry is cached per-bolt in rec.branches since the seed and endpoints are
	-- stable for the bolt's lifetime (hitscan). Eliminates 8 transcendentals/branch
	-- on every frame the bolt is rendered.
	local nBranches = cfg.branchCount
	if nBranches > 0 and boltLenSq > 1 then
		local branches = t.branches
		if not branches or #branches ~= nBranches then
			if branches then
				releaseBranchList(branches)
			end
			if branchListPoolN > 0 then
				branches = branchListPool[branchListPoolN]
				branchListPool[branchListPoolN] = nil
				branchListPoolN = branchListPoolN - 1
			else
				branches = {}
			end
			local boltLen = mathSqrt(boltLenSq)
			local fwx, fwy, fwz = vx / boltLen, vy / boltLen, vz / boltLen
			-- Build an arbitrary stable perpendicular basis
			local upRefX, upRefY, upRefZ = 0, 1, 0
			if math.abs(fwy) > 0.9 then
				upRefX, upRefY, upRefZ = 1, 0, 0
			end
			local pAx = fwy * upRefZ - fwz * upRefY
			local pAy = fwz * upRefX - fwx * upRefZ
			local pAz = fwx * upRefY - fwy * upRefX
			local pALen = mathSqrt(pAx * pAx + pAy * pAy + pAz * pAz)
			if pALen > 0.001 then
				pAx, pAy, pAz = pAx / pALen, pAy / pALen, pAz / pALen
			end
			local pBx = fwy * pAz - fwz * pAy
			local pBy = fwz * pAx - fwx * pAz
			local pBz = fwx * pAy - fwy * pAx

			local seed = tSeed
			local angleSpread = cfg.branchAngleSpread
			local lengthFrac = cfg.branchLengthFrac
			branches = {}
			for b = 1, nBranches do
				local r1 = (math.sin(seed * 12.9 + b * 91.7) * 43758.5) % 1.0
				if r1 < 0 then
					r1 = r1 + 1
				end
				local r2 = (math.sin(seed * 41.7 + b * 17.3) * 43758.5) % 1.0
				if r2 < 0 then
					r2 = r2 + 1
				end
				local r3 = (math.sin(seed * 5.3 + b * 53.1) * 43758.5) % 1.0
				if r3 < 0 then
					r3 = r3 + 1
				end
				local r4 = (math.sin(seed * 23.7 + b * 7.1) * 43758.5) % 1.0
				if r4 < 0 then
					r4 = r4 + 1
				end

				local anchorT = BRANCH_ANCHOR_MIN + r1 * (BRANCH_ANCHOR_MAX - BRANCH_ANCHOR_MIN)
				local angle = (r2 * 2.0 - 1.0) * angleSpread
				local pmix = r3 * 2.0 * math.pi
				local pmc, pms = math.cos(pmix), math.sin(pmix)
				local pMx = pAx * pmc + pBx * pms
				local pMy = pAy * pmc + pBy * pms
				local pMz = pAz * pmc + pBz * pms
				local c = math.cos(angle)
				local sn = math.sin(angle)
				local dirX = fwx * c + pMx * sn
				local dirY = fwy * c + pMy * sn
				local dirZ = fwz * c + pMz * sn

				local lenFrac = lengthFrac * (1.0 - BRANCH_LENGTH_VAR + r4 * 2.0 * BRANCH_LENGTH_VAR)
				local br
				if branchPoolN > 0 then
					br = branchPool[branchPoolN]
					branchPool[branchPoolN] = nil
					branchPoolN = branchPoolN - 1
					br.anchorT = anchorT
					br.dirX = dirX
					br.dirY = dirY
					br.dirZ = dirZ
					br.lenFrac = lenFrac
					br.branchSeed = seed * 0.71 + b * 13.7
				else
					br = {
						anchorT = anchorT,
						dirX = dirX,
						dirY = dirY,
						dirZ = dirZ,
						lenFrac = lenFrac,
						branchSeed = seed * 0.71 + b * 13.7,
					}
				end
				branches[b] = br
			end
			t.branches = branches
		end

		local boltLen = mathSqrt(boltLenSq)
		local bsegs = cfg.branchSegments
		local cBranchJitter = cfg.branchJitter
		local cBranchGlow = cfg.branchGlow
		local cBranchWidthFrac = BRANCH_WIDTH_FRAC
		for b = 1, nBranches do
			local br = branches[b]
			local anchorT = br.anchorT
			local ax = tPx + vx * anchorT
			local ay = tPy + vy * anchorT
			local az = tPz + vz * anchorT
			local blen = boltLen * br.lenFrac
			local bex = ax + br.dirX * blen
			local bey = ay + br.dirY * blen
			local bez = az + br.dirZ * blen
			local branchSeed = br.branchSeed
			for s = 0, bsegs - 1 do
				-- Inlined pushSegment for hot path (eliminates closure call per segment)
				beamData[offset + 1] = ax
				beamData[offset + 2] = ay
				beamData[offset + 3] = az
				beamData[offset + 4] = cBaseWidth
				beamData[offset + 5] = bex
				beamData[offset + 6] = bey
				beamData[offset + 7] = bez
				beamData[offset + 8] = lifeFrac
				beamData[offset + 9] = cCoreR
				beamData[offset + 10] = cCoreG
				beamData[offset + 11] = cCoreB
				beamData[offset + 12] = 1.0
				beamData[offset + 13] = cR
				beamData[offset + 14] = cG
				beamData[offset + 15] = cB
				beamData[offset + 16] = intensity
				beamData[offset + 17] = branchSeed
				beamData[offset + 18] = s
				beamData[offset + 19] = bsegs
				beamData[offset + 20] = cBranchJitter
				beamData[offset + 21] = 1.0 -- isBranch
				beamData[offset + 22] = cBranchWidthFrac -- widthScale
				beamData[offset + 23] = cBranchGlow -- glowMult
				beamData[offset + 24] = 0.0 -- impactSize (no spark on branches)
				offset = offset + INSTANCE_STRIDE
				beamCount = beamCount + 1
			end
		end
	end

	return offset, beamCount
end

local function getOrTrack(proID, cfg, px, py, pz, ex, ey, ez, frame, ownerAllyTeam)
	local rec = tracked[proID]
	if not rec then
		if recPoolN > 0 then
			rec = recPool[recPoolN]
			recPool[recPoolN] = nil
			recPoolN = recPoolN - 1
			rec.cfg = cfg
			rec.px, rec.py, rec.pz = px, py, pz
			rec.ex, rec.ey, rec.ez = ex, ey, ez
			rec.seed = mathRandom() * 1000.0 + (proID % 997)
			rec.firstSeen = frame
			rec.lastSeenFrame = frame
			rec.ownerAllyTeam = ownerAllyTeam
			-- rec.branches already nil (cleared on release)
		else
			rec = {
				cfg = cfg,
				px = px,
				py = py,
				pz = pz,
				ex = ex,
				ey = ey,
				ez = ez,
				seed = mathRandom() * 1000.0 + (proID % 997),
				firstSeen = frame,
				lastSeenFrame = frame,
				ownerAllyTeam = ownerAllyTeam,
			}
		end
		tracked[proID] = rec
		hasTracked = true
	else
		rec.px, rec.py, rec.pz = px, py, pz
		rec.ex, rec.ey, rec.ez = ex, ey, ez
		rec.lastSeenFrame = frame
		rec.ownerAllyTeam = ownerAllyTeam
		-- proIDs are recycled by the engine; if the new projectile has a different
		-- weapon cfg, invalidate the cached branch geometry so it gets rebuilt.
		if rec.cfg ~= cfg then
			rec.cfg = cfg
			if rec.branches then
				releaseBranchList(rec.branches)
				rec.branches = nil
			end
		end
	end
	return rec
end

local function updateBolts()
	-- Idle skip throttles when no bolts/ghosts are active. Disabled while paused
	-- so camera pans always re-cull the existing tracked set against the view.
	local _, _, isPaused = spGetGameSpeed()
	local usePausedCache = isPaused and lastUpdateWasPaused
	lastUpdateWasPaused = isPaused

	-- While paused, bolt state is frozen. Skip the entire rebuild when the
	-- camera hasn't moved since the last paused rebuild; the existing VBO is
	-- replayed by drawAll(). At uncapped paused FPS this saves a lot of work.
	if usePausedCache then
		local cx, cy, cz = Engine.Unsynced.GetCameraPosition()
		local dx, dy, dz = Engine.Unsynced.GetCameraDirection()
		if cx == pausedCamX and cy == pausedCamY and cz == pausedCamZ and dx == pausedCamDX and dy == pausedCamDY and dz == pausedCamDZ then
			return
		end
		local now = Engine.Unsynced.GetTimer()
		if pausedLastRebuildTimer and Engine.Unsynced.DiffTimers(now, pausedLastRebuildTimer) < PAUSED_MOVE_MIN_INTERVAL then
			return
		end
		pausedLastRebuildTimer = now
		pausedCamX, pausedCamY, pausedCamZ = cx, cy, cz
		pausedCamDX, pausedCamDY, pausedCamDZ = dx, dy, dz
	elseif isPaused then
		pausedCamX, pausedCamY, pausedCamZ = Engine.Unsynced.GetCameraPosition()
		pausedCamDX, pausedCamDY, pausedCamDZ = Engine.Unsynced.GetCameraDirection()
		pausedLastRebuildTimer = nil
	end

	if not isPaused and idleSkipCounter > 0 then
		idleSkipCounter = idleSkipCounter - 1
		return
	end

	boltVBO.usedElements = 0

	local frame = spGetGameFrame()
	-- Clear previous live set
	for i = 1, #liveList do
		liveSet[liveList[i]] = nil
	end
	local liveCount = 0

	-- Scan map-wide for projectiles ONCE (at sim rate via DrawWorld gate).
	-- Prefer the shared dispatcher: it caches the map-wide weapon scan once
	-- per tick (shared with beam laser) and pre-filters by weaponDefID so we
	-- skip flamethrower/etc. projectiles for free.
	local projectiles, matchDefIDs, nProjectiles
	local PS = GG.ProjectileScan
	local dispatcherFiltered = (PS ~= nil and dispatchHandle ~= nil)
	if dispatcherFiltered then
		projectiles, matchDefIDs, nProjectiles = PS.GetMatchesWithDefIDs(dispatchHandle)
	else
		projectiles = spGetProjectilesInRectangle(0, 0, mapSizeX, mapSizeZ, false, true)
		nProjectiles = projectiles and #projectiles or 0
	end

	local beamData = boltVBO.instanceData
	local beamCount = 0
	local offset = 0
	local myAlly = cachedAllyTeamID
	local needLos = not cachedSpecFullView

	-- Iterate the rectangle scan result directly (no intermediate table).
	-- For each projectile: filter on weaponConfigs, then per-bolt LOS + AABB.
	for i = 1, nProjectiles do
		local proID = projectiles[i]
		local wDefID, cfg
		if dispatcherFiltered then
			wDefID = matchDefIDs[i]
			cfg = weaponConfigs[wDefID]
		else
			wDefID = spGetProjectileDefID(proID)
			cfg = wDefID and weaponConfigs[wDefID]
		end
		if cfg then
			local px, py, pz = spGetProjectilePosition(proID)
			if px then
				local vx, vy, vz = spGetProjectileVelocity(proID)
				if vx then
					local ex, ey, ez = px + vx, py + vy, pz + vz

					-- Cached owner ally team on rec (owner/team don't change for a projectile).
					-- Avoids 3 engine calls per bolt per frame after the first sighting.
					local rec = tracked[proID]
					local proAlly
					if rec then
						proAlly = rec.ownerAllyTeam
					elseif needLos then
						local ownerID = spGetProjectileOwnerID(proID) or -1
						if ownerID >= 0 then
							local proTeam = spGetProjectileTeamID(proID)
							proAlly = proTeam and spGetTeamAllyTeamID(proTeam)
						end
					end

					-- LOS check:
					--   * Owned bolts: visible if friendly OR either endpoint is in LOS.
					--   * Ownerless chain/spark bolts (spawned by unit_lightning_splash_dmg with owner=-1):
					--     visible only if either endpoint is in the local player's LOS.
					local visible = true
					if needLos then
						if proAlly then
							if proAlly ~= myAlly then
								visible = spLosCheck(px, 0, pz, myAlly) or spLosCheck(ex, 0, ez, myAlly)
							end
						else
							visible = spLosCheck(px, 0, pz, myAlly) or spLosCheck(ex, 0, ez, myAlly)
						end
					end

					if visible then
						-- AABB cull (padded for glow + jitter + impact spark)
						local pad = cfg.aabbPad
						if spIsAABBInView(mathMin(px, ex) - pad, mathMin(py, ey) - pad, mathMin(pz, ez) - pad, mathMax(px, ex) + pad, mathMax(py, ey) + pad, mathMax(pz, ez) + pad) then
							rec = getOrTrack(proID, cfg, px, py, pz, ex, ey, ez, frame, proAlly)
							if not liveSet[proID] then
								liveSet[proID] = true
								liveCount = liveCount + 1
								liveList[liveCount] = proID
							end

							-- Live bolts always render at the fade-in / sustain end of life
							local lifeFrac = FADE_IN_END * 0.5
							-- Capacity check before emit (cheaper than checking inside emit)
							if beamCount + cfg.segments + cfg.branchCount * cfg.branchSegments > boltVBO.maxElements then
								resizeBoltVBO(beamCount + cfg.segments + cfg.branchCount * cfg.branchSegments + 64)
								beamData = boltVBO.instanceData
							end
							offset, beamCount = emitBolt(beamData, offset, beamCount, cfg, rec, lifeFrac)
						end
					end
				end
			end
		end
	end
	for i = liveCount + 1, #liveList do
		liveList[i] = nil
	end

	-- Ghost bolts: projectile is gone but we keep rendering the fade-out tail
	if hasTracked then
		for proID, rec in pairs(tracked) do
			if not liveSet[proID] then
				local age = frame - rec.lastSeenFrame
				if age >= 1 and age <= BOLT_LIFE_FRAMES then
					local cfg = rec.cfg
					local pad = cfg.aabbPad
					local visible = true
					if needLos and rec.ownerAllyTeam and rec.ownerAllyTeam ~= myAlly then
						visible = spLosCheck(rec.px, 0, rec.pz, myAlly) or spLosCheck(rec.ex, 0, rec.ez, myAlly)
					end
					if visible and spIsAABBInView(mathMin(rec.px, rec.ex) - pad, mathMin(rec.py, rec.ey) - pad, mathMin(rec.pz, rec.ez) - pad, mathMax(rec.px, rec.ex) + pad, mathMax(rec.py, rec.ey) + pad, mathMax(rec.pz, rec.ez) + pad) then
						-- lifeFrac sweeps from sustain through FADE_OUT_START to 1.0 across BOLT_LIFE_FRAMES
						local lifeFrac = FADE_OUT_START + (age / BOLT_LIFE_FRAMES) * (1.0 - FADE_OUT_START)
						if beamCount + cfg.segments + cfg.branchCount * cfg.branchSegments > boltVBO.maxElements then
							resizeBoltVBO(beamCount + cfg.segments + cfg.branchCount * cfg.branchSegments + 32)
							beamData = boltVBO.instanceData
						end
						offset, beamCount = emitBolt(beamData, offset, beamCount, cfg, rec, lifeFrac)
					end
				end
			end
		end
	end

	boltVBO.usedElements = beamCount
	if beamCount > 0 then
		idleSkipCounter = 0
		uploadAllElements(boltVBO)
	else
		idleSkipCounter = IDLE_SKIP_FRAMES
	end
end

--------------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------------
local function drawAll()
	if boltVBO.usedElements == 0 then
		return
	end

	glDepthTest(true)
	glDepthMask(false)
	glCulling(false)
	glBlending(GL_ONE, GL_ONE)

	-- Glow halo (drawn first, behind bolt)
	glowShader:Activate()
	boltVBO:Draw()
	glowShader:Deactivate()

	-- Bolt body (procedural; no texture)
	boltShader:Activate()
	boltVBO:Draw()
	boltShader:Deactivate()

	-- Impact spark billboard at the bolt's far endpoint (segIndex==0 instances only)
	gl.Texture(0, impactTexture)
	impactShader:Activate()
	boltVBO:Draw()
	impactShader:Deactivate()
	gl.Texture(0, false)

	glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	glDepthMask(true)
	glDepthTest(false)
end

--------------------------------------------------------------------------------
-- Callins
--------------------------------------------------------------------------------
local cleanupFrame = 0

function gadget:Initialize()
	if not initGL4() then
		return
	end

	-- Subscribe to the shared projectile dispatcher (map-wide weapon scan,
	-- shared with the beam laser gadget).
	local PS = GG.ProjectileScan
	if PS then
		local defIDSet = {}
		for wDefID in pairs(weaponConfigs) do
			defIDSet[wDefID] = true
		end
		dispatchHandle = PS.Subscribe("lightning_cannon", defIDSet, PS.SCAN_MAP_WEAPONS)
	end
end

function gadget:Shutdown()
	cleanupGL4()
end

function gadget:GameFrame(n)
	-- Periodic cleanup of stale tracked bolts (ghosts whose fade-out has finished)
	if n > cleanupFrame then
		cleanupFrame = n + 30
		local removeCount = 0
		local anyRemain = false
		for proID, rec in pairs(tracked) do
			if n - (rec.lastSeenFrame or 0) > BOLT_LIFE_FRAMES + 2 then
				removeCount = removeCount + 1
				removeList[removeCount] = proID
			else
				anyRemain = true
			end
		end
		for i = 1, removeCount do
			local proID = removeList[i]
			local rec = tracked[proID]
			tracked[proID] = nil
			removeList[i] = nil
			if rec then
				releaseRec(rec)
			end
		end
		hasTracked = anyRemain
	end
end

function gadget:PlayerChanged(playerID)
	local _, specFullView = spGetSpectatingState()
	cachedSpecFullView = specFullView
	cachedAllyTeamID = specFullView and -1 or spGetMyAllyTeamID()
end

function gadget:DrawWorld()
	local simFrame = spGetGameFrame()
	-- Bolt visuals (flicker, segment hash) tick at 30 Hz via floor(timeInfo.z * 30.0),
	-- which is the engine sim rate. Skip the projectile scan + VBO rebuild when the
	-- sim frame hasn't advanced and just redraw the existing VBO. Huge saving at
	-- render rates above sim rate (typical 60-144 fps vs 30 Hz sim).
	--
	-- Exception: while paused, simFrame is frozen but the camera can still move.
	-- The bolt set in the VBO was filtered by spIsAABBInView at the time of the
	-- last build, so off-screen bolts at pause time stay invisible even after
	-- panning. Always rebuild while paused to re-cull against the current view.
	local _, _, isPaused = spGetGameSpeed()
	if isPaused or simFrame ~= lastBuildFrame then
		lastBuildFrame = simFrame
		updateBolts()
	end
	drawAll()
end
