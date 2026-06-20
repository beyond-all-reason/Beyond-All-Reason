--------------------------------------------------------------------------------
-- Unit Energy Explosion Particles GL4
--
-- When an "energy" unit dies (significant energy production or storage),
-- spawn a burst of nano-style particles with random upward-biased trajectories
-- that slow down (linear drag) and arc back down (gravity). Visually
-- consistent with gfx_nano_particles_gl4.lua: same texture, additive blend,
-- team-colored tint, end-of-life alpha fade.
--
-- Pure unsynced gadget: UnitDefs are available unsynced and UnitDestroyed
-- fires on the unsynced side too. An explicit IsPosInLos check in
-- UnitDestroyed ensures no particles appear for units the player can't see.
--
-- All tunables live in CONFIG at the top of the file.
--------------------------------------------------------------------------------

function gadget:GetInfo()
	return {
		name      = "Energy Explosion Particles GL4",
		desc      = "Nano-style particle burst when energy producers/storers die",
		author    = "Floris",
		date      = "May 2026",
		license   = "GNU GPL v2",
		layer     = 0,
		enabled   = true,
	}
end

-- Synced side: nothing to do. The gadget runs unsynced only.
if gadgetHandler:IsSyncedCode() then return end

--------------------------------------------------------------------------------
-- CONFIG (edit these freely)
--------------------------------------------------------------------------------

local CONFIG = {
	-- Master switch. Set false to keep the gadget loaded but inert.
	enabled = true,

	------------------------------------------------------------------
	-- Which units qualify and how many particles they get
	------------------------------------------------------------------
	-- Weights map UnitDef resource fields to a single "energy score". The
	-- score is also the baseline particle count for that def (before the
	-- master multiplier). Tune these to taste.
	weightEnergyMake     = 0.16,   -- particles per energy/sec produced
	weightEnergyStorage  = 0.006,  -- particles per energy stored
	weightWindGenerator  = 0.05,   -- particles per max-wind output
	weightTidalGenerator = 0.05,   -- particles per tidal output
	weightEnergyConv     = 0.05,   -- particles per customParams.energyconv_capacity

	-- Defs whose total score is below this threshold get no burst.
	minEnergyScore = 15,

	-- Units whose energy score divided by metalcost is below this ratio are
	-- treated as "incidental energy" (a combat unit with a passive generator)
	-- and receive no burst. Units qualifying via energyconv_capacity or an
	-- explicit overrides.particleCount entry are exempt from this check.
	-- armbanth (score 24 / metal 13500 = 0.0018) → excluded.
	-- armcarry  (score 48 / metal  1400 = 0.034)  → included.
	minEnergyScoreRatio = 0.003,

	-- Final particleCount = clamp(score ^ particleCountPower * particleCountMul, minPC, maxPC)
	-- particleCountPower < 1 gives diminishing returns: doubling a unit's energy
	-- output no longer doubles its particle burst. 0.7 is a mild curve (2× energy
	-- → ~1.6× particles); 0.5 (sqrt) is aggressive (2× energy → 1.41× particles).
	particleCountPower = 0.77,
	particleCountMul = 1.3,
	minParticleCount = 5,
	maxParticleCount = 250,

	-- Global cap so a wave of dying fusions can't blow the pool.
	maxLiveParticles  = 6000,
	-- Hard cap on bursts processed per render frame (extras are dropped).
	maxBurstsPerFrame = 16,
	-- Frames to wait after UnitDestroyed before spawning energy particles.
	-- 0 = spawn immediately (no delay). Increase to let the initial CEG fireball
	-- start dispersing before energy particles appear (trades visual "lateness"
	-- for less CEG obstruction at spawn).
	spawnDelayFrames  = 1,

	------------------------------------------------------------------
	-- Velocity / spawn geometry
	------------------------------------------------------------------
	-- Initial speed range (elmos per sim frame). Each particle samples in
	-- [minSpeed, maxSpeed] with `rand ^ speedPower` -- speedPower > 1 means
	-- most particles are slow with a long high-speed tail ("shrapnel" feel),
	-- < 1 means most fly fast.
	minSpeed     = 0.2,
	maxSpeed     = 2,
	speedPower   = 1.5,
	-- Direction bias. 1.0 = strictly +Y, 0.0 = uniform full sphere,
	-- intermediate values blend (cosTheta = (2r-1)*(1-bias) + bias).
	upwardBias = 0.15,
	-- Spawn jitter around the unit center, as a fraction of unit radius.
	-- Keep small so particles start near the center and expand visibly;
	-- too large and they appear pre-spread with no expansion phase.
	spawnJitterFrac = 0.35,
	-- Compress vertical spawn jitter so particles don't spawn far below the
	-- ground plane (1.0 = full sphere, 0.4 = flat oval).
	spawnJitterYFrac = 0.66,

	------------------------------------------------------------------
	-- Death-explosion weapon influence
	-- Reads UnitDef.deathExplosion -> WeaponDef.damageAreaOfEffect and damages.
	-- Bigger AoE = more spread + more speed. Bigger damage = more chunks +
	-- more speed. Set useDeathExplosion=false to ignore the weapon entirely.
	------------------------------------------------------------------
	useDeathExplosion = true,
	aoeJitterMul      = 0.15,   -- spawn jitter += aoe * mul (elmos); keep tiny so AoE widens velocity range, not spawn origin
	aoeSpeedMul       = 0.0035,  -- maxSpeed += aoe * mul
	damageSpeedMul    = 0.0035,  -- maxSpeed += damage * mul
	damageCountMul    = 0.022,  -- extra particles per damage point
	damageCountMax    = 2.5,     -- hard cap on the damage/aoe particle bonus
	maxSpeedBonus     = 3.3,   -- hard cap on the aoe+damage speed bonus (elmos/frame)

	------------------------------------------------------------------
	-- Physics (applied in vertex shader, global)
	--   pos(t) = spawn + vel*t*(1 - 0.5*drag*t) + 0.5*gravity*t^2
	-- t is in sim frames since spawn; vel/gravity in elmos/frame[^2].
	------------------------------------------------------------------
	drag     = 0.008,
	gravityY = -0.003,

	------------------------------------------------------------------
	-- Lifetime / fade
	------------------------------------------------------------------
	minLifetimeFrames = 25,
	maxLifetimeFrames = 125,
	-- Lifetime scales with burst size: at count == maxParticleCount the
	-- min/max lifetime are multiplied by this value. At minimum count, scale
	-- is 1.0 (no extension). Set to 1.0 to disable.
	lifetimeBigMul    = 1.8,
	fadeFramesMin     = 11,
	fadeFramesMax     = 44,
	-- Frames over which a freshly-spawned particle ramps from invisible to full
	-- alpha. Hides the "pop into existence" at the unit center while the
	-- explosion debris is still bright.
	-- Fade-in is disabled (matches nano gadget). Any non-zero value makes
	-- particles invisible for the first N frames -- against the dim coreBoost
	-- and small alpha the burst then appears to "pop in late". Set to a small
	-- value (e.g. 2) if you want a brief soft attack instead of an instant start.
	fadeInFrames      = 2,

	------------------------------------------------------------------
	-- Visual
	------------------------------------------------------------------
	-- Per-particle size multiplier range applied to base sprite half-size.
	-- Matches nano gadget's sizeVar=0.3 around 1.0.
	sizeMin = 0.7,
	sizeMax = 1.3,
	-- (Cube/GS path: physical size is DRAW_RADIUS * sizeMult elmos -- see SHAPE constants.)
	-- Base alpha (0..1).
	alpha = 0.55,
	-- Brightness equalization for team colours (matches nano gadget feel).
	colorEqualize = 0.7,

	------------------------------------------------------------------
	-- Per-unit overrides. Keyed by UnitDef name. Any subset of:
	--   particleCount        -- absolute override (also lets a def qualify
	--                           even if its energy score is 0)
	--   particleCountMul     -- multiplier applied after the power curve
	--   particleCountPower   -- per-def diminishing-returns exponent override
	--   minSpeed, maxSpeed
	--   upwardBias
	--   sizeMin, sizeMax
	--   alpha
	--   fadeFramesMin, fadeFramesMax
	--   minLifetimeFrames, maxLifetimeFrames
	--   spawnJitterFrac
	-- Example:
	--   overrides = {
	--       cormoho   = { particleCount = 300, sizeMax = 4.0 },
	--       armadvsol = { upwardBias = 0.85 },
	--       cortide   = { particleCountMul = 0.5 },
	--   },
	------------------------------------------------------------------
	overrides = {},

	-- Skip entire defs by name.
	excludeUnitDefs = {
		-- ["armdrag"] = true,
	},

	-- Debug logging on each burst.
	debug = false,
}

--------------------------------------------------------------------------------
-- Locals
--------------------------------------------------------------------------------

local spEcho               = Spring.Echo
local spGetUnitPosition    = Spring.GetUnitPosition
local spGetUnitRadius      = Spring.GetUnitRadius
local spGetMyAllyTeamID    = Spring.GetMyAllyTeamID
local spGetSpectatingState = Spring.GetSpectatingState
local spIsPosInLos         = Spring.IsPosInLos
local spIsSphereInView     = Spring.IsSphereInView
local spGetTeamColor       = Spring.GetTeamColor

local glBlending      = gl.Blending
local glDepthTest     = gl.DepthTest
local glDepthMask     = gl.DepthMask
local glCulling       = gl.Culling
local glAlphaTest     = gl.AlphaTest
local glColor         = gl.Color
local glColorMask     = gl.ColorMask
local glScissor       = gl.Scissor
local glPolygonOffset = gl.PolygonOffset
local glPolygonMode   = gl.PolygonMode
local glStencilTest   = gl.StencilTest

local GL_ONE                 = GL.ONE
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_SRC_ALPHA           = GL.SRC_ALPHA
local GL_FRONT_AND_BACK      = GL.FRONT_AND_BACK
local GL_FILL                = GL.FILL
local GL_LEQUAL              = GL.LEQUAL

local LuaShader           = gl.LuaShader
local InstanceVBOTable    = gl.InstanceVBOTable
local pushElementInstance = InstanceVBOTable.pushElementInstance
local popElementInstance  = InstanceVBOTable.popElementInstance
local uploadElementRange  = InstanceVBOTable.uploadElementRange

local mathRandom = math.random
local mathSqrt   = math.sqrt
local mathFloor  = math.floor
local mathPi     = math.pi
local mathSin    = math.sin
local mathCos    = math.cos
local mathMax    = math.max
local mathMin    = math.min
local mathHuge   = math.huge
local stringFind = string.find

-- Cube/GS path -- no texture sampled.

-- VBO ceiling (instance slots allocated once at Init).
local MAX_PARTICLES_VBO = CONFIG.maxLiveParticles
local liveCount = 0
local nextID    = 1

-- Per-instance scratch buffer (4 vec4 = 16 floats), reused per spawn.
local instanceScratch = { 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0 }

-- death-frame buckets for cheap O(1) cull
local deathBuckets = {}

local particleVBO
local particleShader

-- When NanoParticleMode == 0 the engine renders its own nano spray and the
-- GL4 nano gadget is inactive; energy explosion particles would look out of
-- place, so we go dormant too. Polled every 30 frames.
local nanoParticleMode = Spring.GetConfigInt("NanoParticleMode", 1)

-- Pending bursts queue (drained from GameFrame, capped per frame).
local burstQueue = {}
local burstHead, burstTail = 1, 0

-- Team color cache.
local teamColorCache = {}

-- defID -> { count, jitterRadius, overrideRef or nil }
local qualifyingDefs = {}

-- unitID set: populated by UnitFinished so UnitDestroyed can skip
-- incomplete (under-construction) units. Cleared on UnitDestroyed.
local finishedUnits = {}

local reclaimedWeaponDefID = Game and Game.envDamageTypes and Game.envDamageTypes.Reclaimed
local killedByLuaWeaponDefID = Game and Game.envDamageTypes and Game.envDamageTypes.KilledByLua

-- Cached view state (refreshed each GameFrame).
local cachedAllyTeamID   = spGetMyAllyTeamID()
local cachedSpecFullView = false

-- Dirty range for batched per-frame upload (updated inline in processBurst).
local dirtyMin, dirtyMax = mathHuge, -1

--------------------------------------------------------------------------------
-- Shaders
--------------------------------------------------------------------------------


local vsSrc = [[
#version 430 core
#line 10000

layout(location = 0) in vec4 vertexPosUV;
layout(location = 1) in vec4 spawnPosAndSize;   // xyz=spawnPos, w=packed(sizeMult,fadeFrames)
layout(location = 2) in vec4 velAndSpawnFrame;  // xyz=velocity (elmos/frame), w=spawnFrame
layout(location = 3) in vec4 instColor;         // rgb + alpha
layout(location = 4) in vec4 rotData;           // x=rotVal0, y=rotVel0, z=rotAcc (deg/frame²), w=deathFrame

//__ENGINEUNIFORMBUFFERDEFS__

uniform float drag;
uniform vec3  gravity;
uniform float fadeInFrames;   // 0 = no fade-in
uniform float wobbleAmp;
uniform float wobbleFreq;
uniform float wobbleVar;
uniform float wobbleFreqVar;
uniform float wobbleRampFrames;

out vec3 v_worldPos;
out vec4 v_color;
out float v_rotVal;
out float v_dead;
out vec3 v_phaseSeed;
out float v_sizeMult;
out float v_breathScale;  // glow-breath amplitude envelope: 1.0 for first half of life, ramps to 0 at death

void main() {
	float currentFrame = timeInfo.x + timeInfo.w;
	float spawnFrame   = velAndSpawnFrame.w;
	float deathFrame   = rotData.w;

	if (currentFrame >= deathFrame) {
		v_dead = 1.0;
		gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
		v_worldPos = vec3(0.0);
		v_color = vec4(0.0);
		v_rotVal = 0.0;
		v_phaseSeed = vec3(0.0);
		v_sizeMult = 0.0;
		v_breathScale = 0.0;
		return;
	}
	v_dead = 0.0;

	float t = max(currentFrame - spawnFrame, 0.0);

	// Ballistic motion with linear damping (clamp t so drag doesn't reverse vel).
	float tCap   = (drag > 0.0001) ? (1.0 / drag) : 1.0e6;
	float tClamp = min(t, tCap);
	vec3 worldPos = spawnPosAndSize.xyz
	              + velAndSpawnFrame.xyz * tClamp * (1.0 - 0.5 * drag * tClamp)
	              + 0.5 * gravity * t * t;

	// Optional wobble (matches nano gadget's swirl).
	// rotData.z is now rotAcc (deg/frame²); use spawnFrame for wobble timing.
	if (wobbleAmp > 0.0001) {
		float wobbleT   = max(currentFrame - spawnFrame, 0.0);
		float totalLife = max(deathFrame - spawnFrame, 1.0);
		float bell      = sin(3.14159265 * wobbleT / totalLife);
		if (wobbleRampFrames > 0.5)
			bell *= min(1.0, wobbleT / wobbleRampFrames);
		vec3 vdir = velAndSpawnFrame.xyz;
		vec3 ref, axA, axB;
		float refAngle = rotData.x * 0.01745329;
		float s1 = sin(refAngle), c1 = cos(refAngle);
		float s2 = sin(refAngle * 2.19), c2 = cos(refAngle * 2.19);
		if (abs(vdir.y) < 0.95) {
			ref = normalize(vec3(s1, c1, s2));
		} else {
			ref = normalize(vec3(c1, s2, c2));
		}
		float h1 = fract(sin(rotData.x * 12.9898 + rotData.y * 78.233) * 43758.5453);
		float h2 = fract(sin(rotData.x * 23.1451 + rotData.y * 34.567) * 65432.0987);
		axA = normalize(vec3(
			sin(h1 * 6.28318),
			sin(h2 * 6.28318),
			cos(h1 * 3.14159 + h2 * 3.14159)
		));
		axB = cross(axA, ref);
		if (dot(axB, axB) > 0.001) {
			axB = normalize(axB);
		} else {
			axB = cross(axA, (abs(axA.x) < 0.9) ? vec3(1, 0, 0) : vec3(0, 1, 0));
			axB = normalize(axB);
		}
		float phaseOff = radians(rotData.x);
		float hash     = fract(sin(rotData.x * 12.9898 + rotData.y * 78.233) * 43758.5453);
		float freqScale = max(0.0, 1.0 + wobbleFreqVar * (2.0 * hash - 1.0));
		float dirSign  = (fract(hash * 7.31) < 0.5) ? -1.0 : 1.0;
		float hash2    = fract(hash * 113.7 + 0.317);
		float ampScale = max(0.0, 1.0 + wobbleVar * (2.0 * hash2 - 1.0));
		float ph = currentFrame * wobbleFreq * freqScale * dirSign * (6.2831853 / 30.0) + phaseOff;
		worldPos += (axA * cos(ph) + axB * sin(ph)) * (wobbleAmp * ampScale * bell);
	}

	// Decode packed w: sizeMult in low 1024, fadeFrames * 1024 above.
	float packedW    = abs(spawnPosAndSize.w);
	float fadeFrames = floor(packedW / 1024.0);
	float sizeMult   = (packedW - fadeFrames * 1024.0) / 256.0;

	float fadeOut = (fadeFrames > 0.5)
		? clamp((deathFrame - currentFrame) / fadeFrames, 0.0, 1.0)
		: 1.0;
	float fadeIn  = (fadeInFrames > 0.5)
		? clamp(t / fadeInFrames, 0.0, 1.0)
		: 1.0;
	float fade    = fadeOut * fadeIn;

	// Quadratic rotation integration: val0 + vel*t + 0.5*acc*t²
	float rotVel = rotData.y;
	float rotAcc = rotData.z;
	float rotVal = rotData.x + rotVel * t + 0.5 * rotAcc * t * t;

	v_worldPos = worldPos;
	v_color    = instColor * fade;
	v_rotVal   = rotVal;
	v_sizeMult = sizeMult;
	v_phaseSeed = vec3(rotData.x, rotData.y, rotData.x + rotData.y);

	// Glow-breath envelope: full amplitude until half-life, then ramps to 0
	// by death. smoothstep is reversed because we want 1 -> 0 as life goes
	// 0.5 -> 1.0 (so big lingering particles stop pulsing as they fade out).
	float totalLifeBR = max(deathFrame - spawnFrame, 1.0);
	float lifeFrac    = clamp(t / totalLifeBR, 0.0, 1.0);
	v_breathScale = 1.0 - smoothstep(0.5, 1.0, lifeFrac);

	gl_Position = vec4(worldPos, 1.0);  // GS reads this
}
]]

local gsSrc = [[
#version 430 core

layout(triangles) in;
layout(triangle_strip, max_vertices = 28) out;

//__ENGINEUNIFORMBUFFERDEFS__

uniform float drawRadius;
uniform int   u_shape;
uniform float glowScale;
uniform float glowIntensity;

in vec3  v_worldPos[];
in vec4  v_color[];
in float v_rotVal[];
in float v_dead[];
in vec3  v_phaseSeed[];
in float v_sizeMult[];
in float v_breathScale[];

out vec4 g_color;
out vec3 g_normal;
out vec3 g_worldPos;
out vec3 g_localPos;
out vec3 g_noiseSeed;
out vec2 g_glowUV;
out float g_isGlow;
out float g_seed;
out float g_breathScale;

float hash11(float x) { return fract(sin(x) * 43758.5453); }

mat3 rotXYZ(vec3 a) {
	float cx = cos(a.x), sx = sin(a.x);
	float cy = cos(a.y), sy = sin(a.y);
	float cz = cos(a.z), sz = sin(a.z);
	mat3 Rx = mat3(1,0,0, 0,cx,sx, 0,-sx,cx);
	mat3 Ry = mat3(cy,0,-sy, 0,1,0, sy,0,cy);
	mat3 Rz = mat3(cz,sz,0, -sz,cz,0, 0,0,1);
	return Rz * Ry * Rx;
}

void emitFace(vec3 c0, vec3 c1, vec3 c2, vec3 c3, vec3 n, vec3 center, vec4 col, vec3 noiseSeed, float seed) {
	g_color = col; g_normal = n; g_noiseSeed = noiseSeed; g_isGlow = 0.0; g_glowUV = vec2(0.0); g_seed = seed; g_breathScale = 0.0;
	g_localPos = c0; g_worldPos = center + c0; gl_Position = cameraViewProj * vec4(g_worldPos, 1.0); EmitVertex();
	g_localPos = c1; g_worldPos = center + c1; gl_Position = cameraViewProj * vec4(g_worldPos, 1.0); EmitVertex();
	g_localPos = c2; g_worldPos = center + c2; gl_Position = cameraViewProj * vec4(g_worldPos, 1.0); EmitVertex();
	g_localPos = c3; g_worldPos = center + c3; gl_Position = cameraViewProj * vec4(g_worldPos, 1.0); EmitVertex();
	EndPrimitive();
}

void emitTri(vec3 c0, vec3 c1, vec3 c2, vec3 n, vec3 center, vec4 col, vec3 noiseSeed, float seed) {
	g_color = col; g_normal = n; g_noiseSeed = noiseSeed; g_isGlow = 0.0; g_glowUV = vec2(0.0); g_seed = seed; g_breathScale = 0.0;
	g_localPos = c0; g_worldPos = center + c0; gl_Position = cameraViewProj * vec4(g_worldPos, 1.0); EmitVertex();
	g_localPos = c1; g_worldPos = center + c1; gl_Position = cameraViewProj * vec4(g_worldPos, 1.0); EmitVertex();
	g_localPos = c2; g_worldPos = center + c2; gl_Position = cameraViewProj * vec4(g_worldPos, 1.0); EmitVertex();
	EndPrimitive();
}

void emitGlow(vec3 center, vec4 col, float halfSize, float seed) {
	vec3 right = cameraViewInv[0].xyz * halfSize;
	vec3 up    = cameraViewInv[1].xyz * halfSize;
	g_color = col; g_normal = vec3(0.0, 1.0, 0.0); g_noiseSeed = vec3(0.0);
	g_localPos = vec3(0.0); g_isGlow = 1.0; g_seed = seed; g_breathScale = v_breathScale[0];
	g_glowUV = vec2(-1.0, -1.0); g_worldPos = center - right - up; gl_Position = cameraViewProj * vec4(g_worldPos, 1.0); EmitVertex();
	g_glowUV = vec2( 1.0, -1.0); g_worldPos = center + right - up; gl_Position = cameraViewProj * vec4(g_worldPos, 1.0); EmitVertex();
	g_glowUV = vec2(-1.0,  1.0); g_worldPos = center - right + up; gl_Position = cameraViewProj * vec4(g_worldPos, 1.0); EmitVertex();
	g_glowUV = vec2( 1.0,  1.0); g_worldPos = center + right + up; gl_Position = cameraViewProj * vec4(g_worldPos, 1.0); EmitVertex();
	EndPrimitive();
}

void main() {
	if (v_dead[0] > 0.5) return;
	vec3 center = v_worldPos[0];
	float size  = drawRadius * v_sizeMult[0];
	vec3 noiseSeed = v_phaseSeed[0] * 137.0 + vec3(11.0, 47.0, 83.0);
	float h  = dot(v_phaseSeed[0], vec3(0.123, 0.456, 0.789));
	vec3 phase = vec3(hash11(h), hash11(h+1.7), hash11(h+3.3)) * 6.2831853;
	float r = radians(v_rotVal[0]);
	vec3 ang = phase + vec3(r * 1.0, r * 1.3, r * 0.7);
	mat3 R = rotXYZ(ang);
	vec4 col = v_color[0];
	float seed = radians(v_phaseSeed[0].x);

	if (u_shape == 1) {
		vec3 X = R * vec3(size, 0, 0); vec3 nX = -X;
		vec3 Y = R * vec3(0, size, 0); vec3 nY = -Y;
		vec3 Z = R * vec3(0, 0, size); vec3 nZ = -Z;
		float k = 0.57735027;
		vec3 nPPP = R * vec3( k,  k,  k);
		vec3 nNPP = R * vec3(-k,  k,  k);
		vec3 nNPN = R * vec3(-k,  k, -k);
		vec3 nPPN = R * vec3( k,  k, -k);
		vec3 nPNP = R * vec3( k, -k,  k);
		vec3 nNNP = R * vec3(-k, -k,  k);
		vec3 nNNN = R * vec3(-k, -k, -k);
		vec3 nPNN = R * vec3( k, -k, -k);
		emitTri(Y,  Z,  X,  nPPP, center, col, noiseSeed, seed);
		emitTri(Y, nX,  Z,  nNPP, center, col, noiseSeed, seed);
		emitTri(Y, nZ, nX,  nNPN, center, col, noiseSeed, seed);
		emitTri(Y,  X, nZ,  nPPN, center, col, noiseSeed, seed);
		emitTri(nY,  X,  Z,  nPNP, center, col, noiseSeed, seed);
		emitTri(nY,  Z, nX,  nNNP, center, col, noiseSeed, seed);
		emitTri(nY, nX, nZ,  nNNN, center, col, noiseSeed, seed);
		emitTri(nY, nZ,  X,  nPNN, center, col, noiseSeed, seed);
	} else {
		vec3 X = R * vec3(size, 0, 0);
		vec3 Y = R * vec3(0, size, 0);
		vec3 Z = R * vec3(0, 0, size);
		vec3 nXp =  R[0]; vec3 nXm = -R[0];
		vec3 nYp =  R[1]; vec3 nYm = -R[1];
		vec3 nZp =  R[2]; vec3 nZm = -R[2];
		emitFace( X-Y-Z,  X+Y-Z,  X-Y+Z,  X+Y+Z, nXp, center, col, noiseSeed, seed);
		emitFace(-X-Y-Z, -X-Y+Z, -X+Y-Z, -X+Y+Z, nXm, center, col, noiseSeed, seed);
		emitFace(-X+Y-Z, -X+Y+Z,  X+Y-Z,  X+Y+Z, nYp, center, col, noiseSeed, seed);
		emitFace(-X-Y-Z,  X-Y-Z, -X-Y+Z,  X-Y+Z, nYm, center, col, noiseSeed, seed);
		emitFace(-X-Y+Z,  X-Y+Z, -X+Y+Z,  X+Y+Z, nZp, center, col, noiseSeed, seed);
		emitFace(-X-Y-Z, -X+Y-Z,  X-Y-Z,  X+Y-Z, nZm, center, col, noiseSeed, seed);
	}

	if (glowIntensity > 0.0 && glowScale > 1.001) {
		emitGlow(center, col, size * glowScale, seed);
	}
}
]]

local fsSrc = [[
#version 430 core

//__ENGINEUNIFORMBUFFERDEFS__

uniform float cubeShowInside;
uniform float cubeNoise;
uniform float cubeNoiseSpeed;
uniform float cubeNoiseScale;
uniform float glowIntensity;
uniform float glowFalloff;
uniform float coreBoost;
uniform float hueJitter;
uniform float glowBreath;
uniform float glowBreathFreq;
uniform float glowBreathVar;
uniform float glowBreathFreqVar;
uniform float whiteHotspot;
uniform float whiteHotspotThreshold;

in vec4 g_color;
in vec3 g_normal;
in vec3 g_worldPos;
in vec3 g_localPos;
in vec3 g_noiseSeed;
in vec2 g_glowUV;
in float g_isGlow;
in float g_seed;
in float g_breathScale;
out vec4 fragColor;

float hash13(vec3 p) {
	p  = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}
float valueNoise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float n000 = hash13(i + vec3(0,0,0));
	float n100 = hash13(i + vec3(1,0,0));
	float n010 = hash13(i + vec3(0,1,0));
	float n110 = hash13(i + vec3(1,1,0));
	float n001 = hash13(i + vec3(0,0,1));
	float n101 = hash13(i + vec3(1,0,1));
	float n011 = hash13(i + vec3(0,1,1));
	float n111 = hash13(i + vec3(1,1,1));
	vec4 nx = mix(vec4(n000, n010, n001, n011), vec4(n100, n110, n101, n111), f.x);
	vec2 ny = mix(nx.xz, nx.yw, f.y);
	return mix(ny.x, ny.y, f.z);
}

void main() {
	vec3 tint = vec3(1.0);
	if (hueJitter > 0.0001) {
		tint = vec3(1.0) + hueJitter * vec3(
			sin(g_seed),
			sin(g_seed + 2.094),
			sin(g_seed + 4.188));
	}

	if (g_isGlow > 0.5) {
		float rd = length(g_glowUV);
		if (rd > 1.0) discard;
		float tg = 1.0 - rd;
		float gI = glowIntensity;
		if (glowBreath > 0.0001) {
			float hAmp  = fract(sin(g_seed * 91.7253 + 17.31) * 43758.5453);
			float hFreq = fract(sin(g_seed * 33.1117 + 43.93) * 27183.4500);
			float ampScale  = max(0.0, 1.0 + glowBreathVar     * (2.0 * hAmp  - 1.0));
			float freqScale = max(0.0, 1.0 + glowBreathFreqVar * (2.0 * hFreq - 1.0));
			float ph = (timeInfo.x + timeInfo.w) * glowBreathFreq * freqScale * (6.2831853 / 30.0) + g_seed;
			// Floor the breath multiplier at 0.35: with glowBreath=4 the raw
			// 1+breath*sin(ph) swings to -3, meaning the halo VANISHES for big
			// portions of each cycle. For small bursts (few particles) all the
			// per-particle phases can happen to land in the negative band at
			// spawn, producing a burst that "lights up late" once phases
			// drift positive. Large bursts average out and didn't show it.
			// g_breathScale ramps the breath amplitude from 1.0 to 0.0 across
			// the second half of the particle's lifetime so lingering particles
			// settle into a steady halo instead of pulsing all the way to death.
			gI *= max(1.0 + glowBreath * g_breathScale * ampScale * sin(ph), 0.35);
		}
		float glow = pow(clamp(tg, 0.0, 1.0), max(glowFalloff, 0.01)) * gI;
		vec3  glowTint = g_color.rgb / max(max(g_color.r, max(g_color.g, g_color.b)), 0.001);
		float gLuma    = dot(glowTint, vec3(0.2126, 0.7152, 0.0722));
		const float GLOW_LUMA_TARGET = 0.55;
		const float GLOW_BOOST_MAX   = 5.0;
		float glowBoost = min(GLOW_LUMA_TARGET / max(gLuma, 0.001), GLOW_BOOST_MAX);
		// Premultiplied output: rgb scaled by alpha so the per-particle fade
		// (already baked into g_color.a) actually dims the halo instead of
		// just lowering destination weight under ONE/1-SRC_ALPHA blend.
		float glowA = g_color.a * glow;
		fragColor = vec4(glowTint * tint * (glow * glowBoost) * g_color.a, glowA);
		return;
	}

	vec3 N = normalize(g_normal);
	vec3 lightDir = normalize(vec3(0.4, 1.0, 0.25));
	float dirShade = 0.85 + 0.15 * max(dot(N, lightDir), 0.0);

	float shade = dirShade;
	float aMul  = 1.0;
	if (cubeShowInside > 0.001) {
		vec3 viewDir = normalize(cameraViewInv[3].xyz - g_worldPos);
		float ndv = dot(N, viewDir);
		float shade3D, alpha3D;
		if (ndv >= 0.0) {
			shade3D = 0.80 + 0.45 * (1.0 - ndv);
			alpha3D = 1.0;
		} else {
			shade3D = 0.30 + 0.30 * (-ndv);
			alpha3D = 0.55;
		}
		shade = mix(dirShade, dirShade * shade3D, cubeShowInside);
		aMul  = mix(1.0,      alpha3D,            cubeShowInside);
	}

	float noiseVal = 0.5;
	if (cubeNoise > 0.001 || whiteHotspot > 0.001) {
		float tt = (timeInfo.x + timeInfo.w) * cubeNoiseSpeed * (1.0 / 30.0);
		vec3 samp = g_localPos * cubeNoiseScale + g_noiseSeed + vec3(tt, tt * 0.7, tt * 1.3);
		noiseVal = valueNoise3(samp);
		if (cubeNoise > 0.001) {
			shade *= 1.0 + cubeNoise * (noiseVal * 2.0 - 1.0);
		}
	}

	vec3 baseRgb = g_color.rgb * tint * shade * coreBoost;

	if (whiteHotspot > 0.0001) {
		float hotspot = smoothstep(whiteHotspotThreshold, 1.0, noiseVal) * whiteHotspot;
		baseRgb = mix(baseRgb, vec3(1.0) * max(shade, 0.6), hotspot);
	}

	// Premultiplied output (matches ONE/1-SRC_ALPHA blend); ensures the
	// per-particle fade-in/out baked into g_color.a actually attenuates
	// the visible colour instead of only lifting destination weight.
	float outA = g_color.a * aMul;
	fragColor = vec4(baseRgb * outA, outA);
}
]]

--------------------------------------------------------------------------------
-- Init / shutdown
--------------------------------------------------------------------------------

local function goodbye(reason)
	spEcho("Unit Energy Explosion Particles GL4 exiting: " .. tostring(reason))
	gadgetHandler:RemoveGadget()
end

-- Visual constants taken verbatim from gfx_nano_particles_gl4.lua
-- (MODE_SETTINGS.shape) so the chunks look identical to nano spray.
local SHAPE_ID         = 0    -- 0 = cube, 1 = octahedron
local DRAW_RADIUS      = 1.5  -- shape spans ~2 * drawRadius elmos
local CUBE_SHOW_INSIDE = 4.0
local CUBE_NOISE       = 6.0
local CUBE_NOISE_SPEED = 25.0
local CUBE_NOISE_SCALE = 1.75
local GLOW_SCALE       = 11.0
local GLOW_INTENSITY   = 0.15
local GLOW_FALLOFF     = 9.5
local CORE_BOOST       = 0.3
local HUE_JITTER       = 0.1
local GLOW_BREATH      = 4.0
local GLOW_BREATH_FREQ = 2.0
local GLOW_BREATH_VAR  = 0.5
local GLOW_BREATH_FREQ_VAR = 0.5
local WOBBLE_AMP       = 2.5
local WOBBLE_VAR       = 0.5
local WOBBLE_FREQ      = 0.2
local WOBBLE_FREQ_VAR  = 0.5
local WOBBLE_RAMP_FRAMES = 7.0
local WHITE_HOTSPOT          = 1.5
local WHITE_HOTSPOT_THRESHOLD = 0.6
local SIZE_VAR    = 0.3
local ALPHA_VAR   = 2.5
local NANO_ALPHA  = 50 / 255
local ROT_VAL_BASE  = -180  local ROT_VAL_RANGE = 360
local ROT_VEL_BASE  = -40   local ROT_VEL_RANGE = 80
-- rotAcc in deg/sec² converted to deg/frame² (GAME_SPEED = 30)
local ROT_ACC_BASE  = -40 / (30*30)   local ROT_ACC_RANGE = 80 / (30*30)

local function initGL4()
	if not LuaShader.isGeometryShaderSupported then
		goodbye("geometry shader not supported")
		return false
	end
	local shaderCache = {
		vsSrc = vsSrc,
		fsSrc = fsSrc,
		gsSrc = gsSrc,
		shaderName = "UnitEnergyExplosionParticlesGL4",
		uniformInt   = { u_shape = SHAPE_ID },
		uniformFloat = {
			drag        = CONFIG.drag,
			gravity     = { 0, CONFIG.gravityY, 0 },
			fadeInFrames = CONFIG.fadeInFrames,
			drawRadius  = DRAW_RADIUS,
			cubeShowInside = CUBE_SHOW_INSIDE,
			cubeNoise      = CUBE_NOISE,
			cubeNoiseSpeed = CUBE_NOISE_SPEED,
			cubeNoiseScale = CUBE_NOISE_SCALE,
			glowScale     = GLOW_SCALE,
			glowIntensity = GLOW_INTENSITY,
			glowFalloff   = GLOW_FALLOFF,
			coreBoost     = CORE_BOOST,
			hueJitter     = HUE_JITTER,
			glowBreath    = GLOW_BREATH,
			glowBreathFreq = GLOW_BREATH_FREQ,
			glowBreathVar  = GLOW_BREATH_VAR,
			glowBreathFreqVar = GLOW_BREATH_FREQ_VAR,
			wobbleAmp     = WOBBLE_AMP,
			wobbleVar     = WOBBLE_VAR,
			wobbleFreq    = WOBBLE_FREQ,
			wobbleFreqVar = WOBBLE_FREQ_VAR,
			wobbleRampFrames = WOBBLE_RAMP_FRAMES,
			whiteHotspot          = WHITE_HOTSPOT,
			whiteHotspotThreshold = WHITE_HOTSPOT_THRESHOLD,
		},
		shaderConfig = {},
		forceupdate  = true,
	}
	particleShader = LuaShader.CheckShaderUpdates(shaderCache)
	if not particleShader then
		goodbye("Failed to compile shader")
		return false
	end

	local quadVBO, numVertices = InstanceVBOTable.makeRectVBO(
		-1, -1, 1, 1,
		0, 0, 1, 1,
		"eepQuadVBO"
	)
	-- Shape GS only needs ONE triangle per instance; use a 3-index VBO so the
	-- GS doesn't get invoked twice per particle.
	local indexVBO = gl.GetVBO(GL.ELEMENT_ARRAY_BUFFER, false)
	indexVBO:Define(3)
	indexVBO:Upload({0, 1, 2})

	local layout = {
		{ id = 1, name = "spawnPosAndSize",  size = 4 },
		{ id = 2, name = "velAndSpawnFrame", size = 4 },
		{ id = 3, name = "instColor",        size = 4 },
		{ id = 4, name = "rotData",          size = 4 },
	}
	particleVBO = InstanceVBOTable.makeInstanceVBOTable(layout, MAX_PARTICLES_VBO, "eepParticleVBO")
	if not particleVBO then
		goodbye("Failed to create instance VBO")
		return false
	end
	particleVBO.numVertices = numVertices
	particleVBO.vertexVBO   = quadVBO
	particleVBO.indexVBO    = indexVBO
	particleVBO.VAO         = particleVBO:makeVAOandAttach(quadVBO, particleVBO.instanceVBO, indexVBO)
	particleVBO.primitiveType = GL.TRIANGLES
	return true
end

local function cleanupGL4()
	if particleVBO then particleVBO:Delete(); particleVBO = nil end
	particleShader = nil
end

--------------------------------------------------------------------------------
-- Classification: build qualifyingDefs from UnitDefs at init.
--------------------------------------------------------------------------------

local function computeScore(ud)
	local s = 0
	-- Energy production in BAR can be expressed either as positive `energyMake`
	-- (most generators) or as negative `energyUpkeep` (solar collectors and a
	-- handful of others). Take whichever is larger so both styles count.
	local make   = ud.energyMake or 0
	local upkeep = ud.energyUpkeep or 0
	local production = make
	if upkeep < 0 and -upkeep > production then production = -upkeep end
	s = s + production               * CONFIG.weightEnergyMake
	s = s + (ud.energyStorage  or 0) * CONFIG.weightEnergyStorage
	s = s + (ud.windGenerator  or 0) * CONFIG.weightWindGenerator
	s = s + (ud.tidalGenerator or 0) * CONFIG.weightTidalGenerator
	local cp = ud.customParams
	if cp then
		local cap = tonumber(cp.energyconv_capacity)
		if cap and cap > 0 then
			s = s + cap * CONFIG.weightEnergyConv
		end
	end
	return s
end

local function classifyDefs()
	local n = 0
	for defID, ud in pairs(UnitDefs) do
		local cp = ud.customParams
		local isRaptor = (ud.category and stringFind(ud.category, "RAPTOR", 1, true))
			or (cp and cp.subfolder == "other/raptors")

		if not CONFIG.excludeUnitDefs[ud.name] and not isRaptor then
			local score = computeScore(ud)
			local ov    = CONFIG.overrides[ud.name]
			-- Energy converters/metal-makers qualify via their energyconv_capacity
			-- regardless of the energy score threshold.
			local hasConverter = cp and tonumber(cp.energyconv_capacity) and tonumber(cp.energyconv_capacity) > 0
			-- A unit qualifies via energy score only if the score is also significant
			-- relative to its build cost. This prevents combat units with a small
			-- passive generator (e.g. armbanth) from triggering the effect.
			local metalCost = ud.metalCost or 0
			local scoreQualifies = score >= CONFIG.minEnergyScore
				and (metalCost == 0 or score / metalCost >= CONFIG.minEnergyScoreRatio)
			if (ov and ov.particleCount) or scoreQualifies or hasConverter then
				-- Look up the unit's death-explosion weapon (if any) so we can
				-- scale spread/speed/count by the weapon's AoE and damage.
				local aoe, deathDmg = 0, 0
				if CONFIG.useDeathExplosion then
					local wname = ud.deathExplosion
					if wname and wname ~= "" and WeaponDefNames then
						local wd = WeaponDefNames[wname]
						if wd then
							aoe = wd.damageAreaOfEffect or wd.areaOfEffect or 0
							local dmgs = wd.damages
							if dmgs then
								-- Default-armorclass damage; index 0 is the generic class.
								deathDmg = dmgs[0] or dmgs.default or 0
								if deathDmg == 0 then
									for _, v in pairs(dmgs) do
										if type(v) == "number" and v > deathDmg then deathDmg = v end
									end
								end
							end
						end
					end
				end

				local count
				if ov and ov.particleCount then
					count = ov.particleCount
				else
					local mul = (ov and ov.particleCountMul) or CONFIG.particleCountMul
					local pow = (ov and ov.particleCountPower) or CONFIG.particleCountPower
					local dmgBonus = mathMin(deathDmg * CONFIG.damageCountMul, CONFIG.damageCountMax)
					count = mathFloor((score ^ pow) * mul + dmgBonus + 0.5)
				end
				if count < CONFIG.minParticleCount then count = CONFIG.minParticleCount end
				if count > CONFIG.maxParticleCount then count = CONFIG.maxParticleCount end

				--Spring.Echo(ud.name, count, score, aoe, deathDmg)

				local jf       = (ov and ov.spawnJitterFrac) or CONFIG.spawnJitterFrac
				local jitter   = (ud.radius or 32) * jf + aoe * CONFIG.aoeJitterMul
				local speedBonus = mathMin(aoe * CONFIG.aoeSpeedMul + deathDmg * CONFIG.damageSpeedMul, CONFIG.maxSpeedBonus)

				qualifyingDefs[defID] = {
					count        = count,
					overrideRef  = ov,
					jitterRadius = jitter,
					speedBonus   = speedBonus,
					aoe          = aoe,
					deathDamage  = deathDmg,
				}

				n = n + 1
			end
		end
	end
	if CONFIG.debug then
		spEcho(("EEP: classified %d qualifying UnitDefs"):format(n))
	end
end

--------------------------------------------------------------------------------
-- Team color helpers (with brightness equalization, matches nano feel)
--------------------------------------------------------------------------------

local function fetchTeamColor(teamID)
	local cached = teamColorCache[teamID]
	if cached then return cached[1], cached[2], cached[3] end
	local r, g, b = spGetTeamColor(teamID)
	if not r then r, g, b = 1, 1, 1 end
	local eq = CONFIG.colorEqualize
	if eq > 0.001 then
		local luma = 0.2126*r + 0.7152*g + 0.0722*b
		local target = 0.55
		local boost = (luma > 0.001) and (target / luma) or 1.0
		boost = mathMin(boost, 4.0)
		local mul = 1.0 + eq * (boost - 1.0)
		r = mathMin(r * mul, 1.5)
		g = mathMin(g * mul, 1.5)
		b = mathMin(b * mul, 1.5)
	end
	teamColorCache[teamID] = { r, g, b }
	return r, g, b
end

--------------------------------------------------------------------------------
-- Spawn helpers
--------------------------------------------------------------------------------

-- Resolve effective per-burst parameters. ov may be nil.
local function paramOr(ov, key)
	if ov and ov[key] ~= nil then return ov[key] end
	return CONFIG[key]
end

local function processBurst(px, py, pz, teamID, meta, frame)
	local count        = meta.count
	local jitterRadius = meta.jitterRadius
	local overrideRef  = meta.overrideRef
	local speedBonus   = meta.speedBonus or 0

	-- Frustum gate: if the burst sphere isn't in view, skip entirely.
	if not spIsSphereInView(px, py, pz, jitterRadius + 64) then return end

	local r, g, b = fetchTeamColor(teamID)

	local minS          = paramOr(overrideRef, "minSpeed")
	local maxS          = paramOr(overrideRef, "maxSpeed") + speedBonus
	local speedPow      = paramOr(overrideRef, "speedPower")
	local szMin         = paramOr(overrideRef, "sizeMin")
	local szMax         = paramOr(overrideRef, "sizeMax")
	local lifeMin       = paramOr(overrideRef, "minLifetimeFrames")
	local lifeMax       = paramOr(overrideRef, "maxLifetimeFrames")
	-- Scale lifetime range with burst size: small bursts use the configured
	-- range; large bursts (approaching maxParticleCount) get up to lifetimeBigMul
	-- times longer life so fusion-sized explosions linger.
	local lifeScale  = 1.0 + (CONFIG.lifetimeBigMul - 1.0)
		* mathMin(count / CONFIG.maxParticleCount, 1.0)
	lifeMax = lifeMax * lifeScale
	local bias          = paramOr(overrideRef, "upwardBias")
	local alpha         = paramOr(overrideRef, "alpha")
	local fadeFramesMin = paramOr(overrideRef, "fadeFramesMin")
	local fadeFramesMax = paramOr(overrideRef, "fadeFramesMax")
	local fadeInFrames  = paramOr(overrideRef, "fadeInFrames")
	local jyFrac        = paramOr(overrideRef, "spawnJitterYFrac")

	-- Cache the VBO reference; bail early if it disappeared.
	local _pVBO = particleVBO
	if not _pVBO then return end
	local _liveCount = liveCount
	local budget = MAX_PARTICLES_VBO - _liveCount
	if budget <= 0 then return end
	if count > budget then count = budget end

	-- Hoist frequently-mutated upvalues into locals so the tight per-particle
	-- loop avoids repeated upvalue indirection (each upvalue access requires an
	-- extra pointer dereference vs a plain local stack slot).
	local _nextID   = nextID
	local _dirtyMin = dirtyMin
	local _dirtyMax = dirtyMax
	local _scratch  = instanceScratch
	local _buckets  = deathBuckets

	-- Pre-compute per-burst invariants so they aren't recomputed each iteration.
	local speedRange = maxS - minS
	local szRange    = szMax - szMin
	local lifeRange  = lifeMax - lifeMin
	local fadeRange  = fadeFramesMax - fadeFramesMin
	local biasTerm   = 1.0 - bias   -- weight for the (2r-1) term in cosTheta
	local twoPi      = 2.0 * mathPi
	local hasAlphaVar = ALPHA_VAR > 0

	for _ = 1, count do
		-- Rejection-sampled offset inside unit sphere; Y compressed by jyFrac.
		local jx, jy, jz
		repeat
			jx = mathRandom() * 2 - 1
			jy = mathRandom() * 2 - 1
			jz = mathRandom() * 2 - 1
		until (jx*jx + jy*jy + jz*jz) <= 1.0
		local sx = px + jx * jitterRadius
		local sy = py + jy * jitterRadius * jyFrac
		local sz = pz + jz * jitterRadius

		-- Inlined sampleExplosionDir: uniform sphere biased toward +Y.
		-- bias=0 -> full sphere, bias=1 -> straight up.
		local cosT = (2.0 * mathRandom() - 1.0) * biasTerm + bias
		if cosT < -1 then cosT = -1 elseif cosT > 1 then cosT = 1 end
		local sinT = mathSqrt(mathMax(0.0, 1.0 - cosT * cosT))
		local phi  = mathRandom() * twoPi
		local dx   = sinT * mathCos(phi)
		local dz   = sinT * mathSin(phi)

		-- Power-law speed sample: rand^speedPow biases distribution toward minS
		-- when speedPow > 1 (long high-speed tail = "shrapnel").
		local speed = minS + speedRange * (mathRandom() ^ speedPow)
		local vx, vy, vz = dx * speed, cosT * speed, dz * speed

		local sizeMult = szMin + szRange * mathRandom()
		local lifetime = lifeMin + mathFloor(lifeRange * mathRandom() + 0.5)

		-- Fade window scales linearly with the particle's own lifetime so
		-- short-lived particles don't get a disproportionately long tail.
		local lifeFrac   = (lifeRange > 0) and (lifetime - lifeMin) / lifeRange or 0.0
		local fadeFrames = mathFloor(fadeFramesMin + fadeRange * lifeFrac + 0.5)

		-- Per-particle alpha jitter (matches nano gadget look). Centred on the
		-- configured `alpha`; ALPHA_VAR is a fractional swing (2.5 -> ±250%).
		local pa = hasAlphaVar and (alpha * (1.0 + ALPHA_VAR * (mathRandom() * 2 - 1))) or alpha

		-- Inlined spawnParticle: pack size+fade, randomise rotation, push VBO slot.
		local death  = frame + lifetime
		local packed = mathFloor(sizeMult * 256 + 0.5) + (fadeFrames or 0) * 1024
		local rotVal = ROT_VAL_BASE + ROT_VAL_RANGE * (mathRandom() * 2 - 1)
		local rotVel = ROT_VEL_BASE + ROT_VEL_RANGE * (mathRandom() * 2 - 1)
		local rotAcc = ROT_ACC_BASE + ROT_ACC_RANGE * (mathRandom() * 2 - 1)

		local id = _nextID
		_nextID = _nextID + 1

		_scratch[1]  = sx;    _scratch[2]  = sy;    _scratch[3]  = sz;    _scratch[4]  = packed
		_scratch[5]  = vx;    _scratch[6]  = vy;    _scratch[7]  = vz;    _scratch[8]  = frame
		_scratch[9]  = r;     _scratch[10] = g;     _scratch[11] = b;     _scratch[12] = pa
		_scratch[13] = rotVal; _scratch[14] = rotVel; _scratch[15] = rotAcc; _scratch[16] = death

		-- noUpload=true: we batch the GPU upload at end of GameFrame.
		-- pushElementInstance returns the instanceID (not the slot index!), so we
		-- read the actual 1-based slot from usedElements right after the push.
		-- Pop-swaps in earlier frames mean instanceID != slot index for any burst
		-- after the first, and uploadElementRange wants 0-based slot offsets, so
		-- we must convert via (usedElements - 1) here.
		local ok = pushElementInstance(_pVBO, _scratch, id, false, true, nil)
		if ok then
			local bucket = _buckets[death]
			if bucket then
				bucket[#bucket + 1] = id
			else
				_buckets[death] = { id }
			end
			_liveCount = _liveCount + 1
			local slot = _pVBO.usedElements - 1
			if slot < _dirtyMin then _dirtyMin = slot end
			if slot > _dirtyMax then _dirtyMax = slot end
		end
	end

	-- Write back the upvalues that changed inside the loop.
	liveCount = _liveCount
	nextID    = _nextID
	dirtyMin  = _dirtyMin
	dirtyMax  = _dirtyMax

	if CONFIG.debug then
		spEcho(("EEP: burst @ (%d, %d, %d) team=%d count=%d aoe=%d dmg=%d")
			:format(px, py, pz, teamID, count, meta.aoe or 0, meta.deathDamage or 0))
	end
end

--------------------------------------------------------------------------------
-- Per-frame cull
--------------------------------------------------------------------------------

local function cullDead(frame)
	local bucket = deathBuckets[frame]
	if not bucket then return end
	local nb = #bucket
	local _pVBO = particleVBO
	if not _pVBO then
		liveCount = liveCount - nb
		deathBuckets[frame] = nil
		return
	end
	-- popElementInstance swaps the tail in. Each swap touches the destination
	-- slot; rely on its internal per-element upload so cull doesn't need batching.
	local pop = popElementInstance
	for i = 1, nb do
		pop(_pVBO, bucket[i], false)
	end
	liveCount = liveCount - nb
	deathBuckets[frame] = nil
end

--------------------------------------------------------------------------------
-- Callins
--------------------------------------------------------------------------------

function gadget:Initialize()
	if not CONFIG.enabled then spEcho("EEP: disabled in CONFIG, removing"); gadgetHandler:RemoveGadget(); return end
	if not initGL4() then spEcho("EEP: initGL4 failed, bailing"); return end
	classifyDefs()
	-- Populate finishedUnits for any qualifying units already on the map
	-- (handles mid-game widget reloads and gadget restarts).
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		local unitDefID = Spring.GetUnitDefID(unitID)
		if qualifyingDefs[unitDefID] then
			local _, _, _, _, buildProgress = Spring.GetUnitHealth(unitID)
			if buildProgress and buildProgress >= 1.0 then
				finishedUnits[unitID] = true
			end
		end
	end
end

function gadget:Shutdown()
	cleanupGL4()
end

function gadget:UnitFinished(unitID, unitDefID)
	if qualifyingDefs[unitDefID] then
		finishedUnits[unitID] = true
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, _attackerDefID, _attackerTeam, weaponDefID)
	if nanoParticleMode == 0 then return end
	-- Skip units that were still under construction when they died.
	local wasFinished = finishedUnits[unitID]
	finishedUnits[unitID] = nil
	if not wasFinished then return end
	if weaponDefID == reclaimedWeaponDefID then return end
	-- Geo-upgrade reclaim cleanup currently arrives as KilledByLua with no attacker.
	-- Treat that specific scripted geothermal removal as non-explosive.
	if not attackerID and weaponDefID == killedByLuaWeaponDefID then
		local ud = UnitDefs[unitDefID]
		if ud and ud.customParams and ud.customParams.geothermal then return end
	end
	-- Legacy fallback used by other BAR visuals: builder attacker with no valid weapon.
	if attackerID and attackerID ~= unitID and (not weaponDefID or weaponDefID < 0) then return end
	local meta = qualifyingDefs[unitDefID]
	if not meta then return end
	local px, py, pz = spGetUnitPosition(unitID)
	if not px then return end
	-- LOS gate: skip if the local player can't see the unit's position.
	if not cachedSpecFullView and not spIsPosInLos(px, py, pz, cachedAllyTeamID) then return end
	-- Lift slightly above the model base so particles emerge from the volume.
	local r = spGetUnitRadius(unitID) or 32
	py = py + r * 0.35
	-- Delay so energy particles appear after the initial CEG fireball peaks.
	local targetFrame = Spring.GetGameFrame() + CONFIG.spawnDelayFrames
	burstTail = burstTail + 1
	burstQueue[burstTail] = { px, py, pz, unitTeam, meta, targetFrame }
end

function gadget:GameFrame(n)
	-- Refresh view caches and NanoParticleMode at low cadence.
	if n % 30 == 0 then
		nanoParticleMode = Spring.GetConfigInt("NanoParticleMode", 1)
		cachedAllyTeamID = spGetMyAllyTeamID()
		local _, full = spGetSpectatingState()
		cachedSpecFullView = full and true or false
		teamColorCache = {}
	end

	-- Engine-spray mode: GL4 nano particles are off, so skip our burst too.
	if nanoParticleMode == 0 then return end

	-- Drain burst queue, capped per frame.
	local processed = 0
	local cap = CONFIG.maxBurstsPerFrame
	while burstHead <= burstTail and processed < cap do
		local b = burstQueue[burstHead]
		if b[6] > n then break end  -- delay not yet elapsed; queue is FIFO so no later entry is ready
		burstQueue[burstHead] = nil
		burstHead = burstHead + 1
		processBurst(b[1], b[2], b[3], b[4], b[5], n)
		processed = processed + 1
	end
	if burstHead > burstTail then
		burstHead, burstTail = 1, 0
	end

	cullDead(n)

	-- Flush spawn uploads in one range.
	if particleVBO and dirtyMax >= dirtyMin then
		uploadElementRange(particleVBO, dirtyMin, dirtyMax)
		dirtyMin, dirtyMax = mathHuge, -1
	end
end

function gadget:DrawWorld()
	if nanoParticleMode == 0 then return end
	local _pVBO = particleVBO
	if not _pVBO or _pVBO.usedElements == 0 then return end

	-- Defensive GL state (same rationale as nano gadget).
	glDepthTest(GL_LEQUAL)
	glDepthMask(false)
	glCulling(false)
	glAlphaTest(false)
	glColor(1, 1, 1, 1)
	glColorMask(true, true, true, true)
	glScissor(false)
	glPolygonOffset(false)
	glPolygonMode(GL_FRONT_AND_BACK, GL_FILL)
	glStencilTest(false)
	-- Premultiplied-alpha additive blend, same as nano spray.
	glBlending(GL_ONE, GL_ONE_MINUS_SRC_ALPHA)

	particleShader:Activate()
	_pVBO:Draw()
	particleShader:Deactivate()

	glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	glDepthMask(true)
end
