--------------------------------------------------------------------------------
-- GPU Particle Engine GL4
-- Core fire/smoke particle rendering system with public API.
-- Handles VBO management, shaders, drawing, quality auto-scaling, wind.
-- Consumer gadgets use GG.Particles API to spawn effects.
--
-- Provides:
--   - Instanced GL4 VBO particle rendering (smoke + fire)
--   - Quality preset auto-scaling based on particle count
--   - Priority-based particle budgeting
--   - Wind-influenced particle drift
--   - Point emitter management (stationary fire/smoke sources)
--   - Pre-draw callback system for consumer buffer flushing
--   - Public API via GG.Particles (+ backward compat GG.FireSmoke)
--------------------------------------------------------------------------------

if gadgetHandler:IsSyncedCode() then
	return
end

function gadget:GetInfo()
	return {
		name = "Particle Engine GL4",
		desc = "GPU-instanced (fire/smoke) particle engine with public API",
		author = "Floris",
		date = "April 2026",
		license = "GNU GPL v2",
		layer = 0,
		enabled = true,
		dependents = { -- for gadget auto reloader to reload these as well
			"Piece Trail Particles GL4",
			"Crash Trail Particles GL4",
		},
	}
end

local debugEcho = false

--------------------------------------------------------------------------------
-- Localized functions
--------------------------------------------------------------------------------
local spGetGroundHeight = SpringShared.GetGroundHeight
local spEcho = SpringShared.Echo
local spGetTimer = SpringUnsynced.GetTimer
local spDiffTimers = SpringUnsynced.DiffTimers
local spIsSphereInView = SpringUnsynced.IsSphereInView
local spGetCameraPosition = SpringUnsynced.GetCameraPosition
local spGetFPS = SpringUnsynced.GetFPS
local spGetWind = SpringShared.GetWind
local spGetConfigInt = SpringUnsynced.GetConfigInt
local spGetGameSpeed = SpringUnsynced.GetGameSpeed

local glBlending = gl.Blending
local glTexture = gl.Texture
local glDepthTest = gl.DepthTest
local glDepthMask = gl.DepthMask
local glCulling = gl.Culling

local GL_ONE = GL.ONE
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_SRC_ALPHA = GL.SRC_ALPHA

local mathRandom = math.random
local mathMin = math.min
local mathMax = math.max
local mathFloor = math.floor
local mathCeil = math.ceil
local mathSqrt = math.sqrt
local mathPi = math.pi

local LuaShader = gl.LuaShader
local pushElementInstance = gl.InstanceVBOTable.pushElementInstance
local popElementInstance = gl.InstanceVBOTable.popElementInstance
local uploadAllElements = gl.InstanceVBOTable.uploadAllElements

--------------------------------------------------------------------------------
-- Priority levels for particle budgeting
--------------------------------------------------------------------------------
local PRIORITY_ESSENTIAL = 1 -- always emit: crash trails, wreck fires
local PRIORITY_NORMAL = 2 -- standard: piece debris trails
local PRIORITY_COSMETIC = 3 -- reduced first: ambient fluff, extra detail

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

-- Textures
local fireTexture = "bitmaps/projectiletextures/BARFlame02.tga"
local smokeTexture = "bitmaps/projectiletextures/smoke-beh-anim.tga"

-- General (MAX_PARTICLES read from configint so the options widget can expose a slider)
local minFireSmokeParticles = 10000
local MAX_PARTICLES = ((spGetConfigInt("MaxParticles", 10000) - 7500) * 3) + minFireSmokeParticles
local VBO_CAPACITY = MAX_PARTICLES

-- Default particle property values (exposed via API for consumer overrides)
local defaults = {
	-- Particle size range
	PARTICLE_SIZE_MIN = 1,
	PARTICLE_SIZE_MAX = 4,

	-- Shared smoke physics
	SMOKE_VEL_UP_MIN = 0.04,
	SMOKE_VEL_UP_MAX = 0.20,
	SMOKE_VEL_RANDOM = 0.1,

	-- Fire particle settings
	FIRE_LIFETIME_MIN = 20,
	FIRE_LIFETIME_RANGE = 100,
	FIRE_SIZE_MULT = 7.5,
	FIRE_ALPHA_MIN = 0.55,

	-- Smoke alpha range
	SMOKE_ALPHA_MIN = 0.25,
	SMOKE_ALPHA_RANGE = 0.75,
}

-- Local aliases for hot-path use (updated when defaults change)
local PARTICLE_SIZE_MIN = defaults.PARTICLE_SIZE_MIN
local PARTICLE_SIZE_MAX = defaults.PARTICLE_SIZE_MAX
local SMOKE_VEL_UP_MIN = defaults.SMOKE_VEL_UP_MIN
local SMOKE_VEL_UP_MAX = defaults.SMOKE_VEL_UP_MAX
local SMOKE_VEL_RANDOM = defaults.SMOKE_VEL_RANDOM
local FIRE_LIFETIME_MIN = defaults.FIRE_LIFETIME_MIN
local FIRE_LIFETIME_RANGE = defaults.FIRE_LIFETIME_RANGE
local FIRE_SIZE_MULT = defaults.FIRE_SIZE_MULT
local FIRE_ALPHA_MIN = defaults.FIRE_ALPHA_MIN
local SMOKE_ALPHA_MIN = defaults.SMOKE_ALPHA_MIN
local SMOKE_ALPHA_RANGE = defaults.SMOKE_ALPHA_RANGE

-- Priority-based budget: each level can fill the VBO up to this fraction
local BUDGET_ESSENTIAL = 1.0
local BUDGET_NORMAL = 0.85
local BUDGET_COSMETIC = 0.60

-- Smoke highlight: lighter particle layered above each smoke particle
local SMOKE_HIGHLIGHT_OFFSET_Y = 2.2
local SMOKE_HIGHLIGHT_BRIGHT = 2.8
local SMOKE_HIGHLIGHT_SIZE = 0.85
local SMOKE_HIGHLIGHT_LIFE = 0.7

-- Frustum culling margin (elmos beyond visible sphere to still spawn)
local CULLING_MARGIN = 200

-- Point emitter defaults
local POINT_SPAWN_INTERVAL = 2
local POINT_SPAWN_COUNT = 2
local POINT_SMOKE_LIFE_MIN = 60
local POINT_SMOKE_LIFE_RANGE = 60
local POINT_POS_SPREAD = 2.0
local POINT_CULLING_RADIUS = 100

-- Pre-computed constants (recomputed via refreshDerivedConstants)
local SMOKE_VEL_UP_RANGE = SMOKE_VEL_UP_MAX - SMOKE_VEL_UP_MIN
local SMOKE_VEL_RANDOM_2 = SMOKE_VEL_RANDOM * 2
local PARTICLE_SIZE_RANGE = PARTICLE_SIZE_MAX - PARTICLE_SIZE_MIN
local PARTICLE_SIZE_INV_RANGE = 1.0 / PARTICLE_SIZE_RANGE
local POINT_CULLING_TOTAL = POINT_CULLING_RADIUS + CULLING_MARGIN

local function refreshDerivedConstants()
	PARTICLE_SIZE_MIN = defaults.PARTICLE_SIZE_MIN
	PARTICLE_SIZE_MAX = defaults.PARTICLE_SIZE_MAX
	SMOKE_VEL_UP_MIN = defaults.SMOKE_VEL_UP_MIN
	SMOKE_VEL_UP_MAX = defaults.SMOKE_VEL_UP_MAX
	SMOKE_VEL_RANDOM = defaults.SMOKE_VEL_RANDOM
	FIRE_LIFETIME_MIN = defaults.FIRE_LIFETIME_MIN
	FIRE_LIFETIME_RANGE = defaults.FIRE_LIFETIME_RANGE
	FIRE_SIZE_MULT = defaults.FIRE_SIZE_MULT
	FIRE_ALPHA_MIN = defaults.FIRE_ALPHA_MIN
	SMOKE_ALPHA_MIN = defaults.SMOKE_ALPHA_MIN
	SMOKE_ALPHA_RANGE = defaults.SMOKE_ALPHA_RANGE
	SMOKE_VEL_UP_RANGE = SMOKE_VEL_UP_MAX - SMOKE_VEL_UP_MIN
	SMOKE_VEL_RANDOM_2 = SMOKE_VEL_RANDOM * 2
	PARTICLE_SIZE_RANGE = PARTICLE_SIZE_MAX - PARTICLE_SIZE_MIN
	PARTICLE_SIZE_INV_RANGE = PARTICLE_SIZE_RANGE > 0 and (1.0 / PARTICLE_SIZE_RANGE) or 1.0
end

-- LOD settings (used by point emitters)
local LOD_DIST_NEAR = 4000
local LOD_DIST_FAR = 10000
local LOD_MIN_MULT = 0.33
local LOD_DIST_RANGE_INV = 1.0 / (LOD_DIST_FAR - LOD_DIST_NEAR)
local LOD_MULT_RANGE = 1.0 - LOD_MIN_MULT
local LOD_DIST_NEAR_SQ = LOD_DIST_NEAR * LOD_DIST_NEAR

-- Budget limits (computed from MAX_PARTICLES)
local budgetLimits = {
	[PRIORITY_ESSENTIAL] = mathFloor(MAX_PARTICLES * BUDGET_ESSENTIAL),
	[PRIORITY_NORMAL] = mathFloor(MAX_PARTICLES * BUDGET_NORMAL),
	[PRIORITY_COSMETIC] = mathFloor(MAX_PARTICLES * BUDGET_COSMETIC),
}

-- Quality presets: auto-switch based on average particle count
local QUALITY_PRESETS = {
	[1] = {
		name = "Low",
		spawnMult = 0.35,
		pieceCountMult = 0.5,
		lifetimeMult = 0.25,
		maxPct = 1.0,
	},
	[2] = {
		name = "Medium",
		spawnMult = 0.65,
		pieceCountMult = 0.75,
		lifetimeMult = 0.33,
		maxPct = 0.75,
	},
	[3] = {
		name = "High",
		spawnMult = 1.0,
		pieceCountMult = 1.0,
		lifetimeMult = 0.4,
		maxPct = 0.45,
	},
}
-- temp just to test
-- QUALITY_PRESETS[1] = QUALITY_PRESETS[3]
-- QUALITY_PRESETS[2] = QUALITY_PRESETS[3]

--------------------------------------------------------------------------------
-- Shader sources
--------------------------------------------------------------------------------

local vsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 10000

//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

uniform vec3 windVelocity;
uniform vec4 highlightPass;  // x=enabled, y=sizeMult, z=yOffset, w=1/lifetimeMult

layout (location = 0) in vec4 position_xy_uv;

layout (location = 1) in vec4 worldPos;        // xyz = spawn position, w = birthFrame
layout (location = 2) in vec4 velocity;        // xyz = initial velocity, w = lifetime (frames)
layout (location = 3) in vec4 sizeAndType;     // x = baseSize, y = type (0=smoke,1=fire), z = randomSeed, w = rotation
layout (location = 4) in vec4 colorTint;       // rgb = brightness tint, a = alpha multiplier

out DataVS {
	vec2 texCoords;
	vec4 particleColor;
	float animFrame;
	float rowVariant;
	flat float isFireParticle;
};

void main()
{
	float currentFrame = timeInfo.x + timeInfo.w;
	float ageFrames = currentFrame - worldPos.w;
	float lifetime = velocity.w;
	float normalizedAge = clamp(ageFrames / lifetime, 0.0, 1.0);

	// Highlight pass: skip fire particles, shorten effective lifetime
	if (highlightPass.x > 0.5) {
		if (sizeAndType.y > 0.5) {
			gl_Position = vec4(-9999.0, -9999.0, -9999.0, 1.0);
			particleColor = vec4(0.0);
			texCoords = vec2(0.0);
			animFrame = 0.0;
			rowVariant = 0.0;
			isFireParticle = 0.0;
			return;
		}
		normalizedAge = clamp(normalizedAge * highlightPass.w, 0.0, 1.0);
	}

	// Kill expired particles
	if (normalizedAge >= 1.0 || ageFrames < 0.0) {
		gl_Position = vec4(-9999.0, -9999.0, -9999.0, 1.0);
		particleColor = vec4(0.0);
		texCoords = vec2(0.0);
		animFrame = 0.0;
		rowVariant = 0.0;
		isFireParticle = 0.0;
		return;
	}

	float seed = sizeAndType.z;

	// Velocity with air drag (0.85 per frame)
	float dragPow = exp(ageFrames * -0.16252);  // ln(0.85)
	float dragFactor = (1.0 - dragPow) * 6.6667;  // 1/(1-0.85)

	vec3 pos = worldPos.xyz;
	pos += velocity.xyz * dragFactor;

	// Buoyancy
	pos.y += 0.004 * ageFrames * ageFrames;

	// Highlight pass: Y offset (applied before wind/wobble)
	pos.y += highlightPass.z;

	// Wind drift: accumulates over particle age, smoke drifts more than fire
	float windMult = mix(WIND_SMOKE_MULT, WIND_SMOKE_MULT * WIND_FIRE_MULT, step(0.5, sizeAndType.y));
	pos.x += windVelocity.x * ageFrames * windMult;
	pos.z += windVelocity.z * ageFrames * windMult;

	// Size
	float baseSize = sizeAndType.x;

	// Turbulence: grows with age, scaled by particle size
	float seedPhase = seed * 6.283;
	float wobble = SMOKE_WOBBLE_START + normalizedAge * SMOKE_WOBBLE_RAMP * baseSize + ageFrames * SMOKE_WOBBLE_RATE;
	pos.x += sin(ageFrames * 0.07 + seedPhase * 2.7) * wobble;
	pos.z += cos(ageFrames * 0.09 + seedPhase * 3.8) * wobble;
	pos.y += sin(ageFrames * 0.05 + seedPhase * 1.8) * wobble * 0.25;

	// Growth: lifetime-based curve + time-based linear rate (smoke only)
	float isFire = step(0.5, sizeAndType.y);
	float growCurve = normalizedAge * (1.0 + normalizedAge);
	float lifetimeGrowth = baseSize * (1.0 + growCurve * SMOKE_GROWTH_MULT);
	float timeGrowth = ageFrames * SMOKE_GROWTH_RATE;
	float smokeGrowth = lifetimeGrowth + timeGrowth;
	float sizeGrowth = mix(smokeGrowth, baseSize, isFire);

	// Highlight pass: smaller size, Y offset
	if (highlightPass.x > 0.5) {
		sizeGrowth *= highlightPass.y;
	}

	// Billboard
	vec3 camRight = cameraViewInv[0].xyz;
	vec3 camUp    = cameraViewInv[1].xyz;

	// Rotation
	float rotSpeed = (seed - 0.5) * 0.6;
	float rot = sizeAndType.w + normalizedAge * rotSpeed;
	float cr = cos(rot);
	float sr = sin(rot);
	vec3 rotRight = camRight * cr + camUp * sr;
	vec3 rotUp    = -camRight * sr + camUp * cr;

	vec3 vertexOffset = (rotRight * position_xy_uv.x + rotUp * position_xy_uv.y) * sizeGrowth;
	vec4 worldPosition = vec4(pos + vertexOffset, 1.0);

	gl_Position = cameraViewProj * worldPosition;
	texCoords = position_xy_uv.zw;

	// Particle type (reuse isFire from growth section)
	isFireParticle = isFire;
	int cmapVariant = int(isFireParticle);

	// Colormaps: 0 = smoke (dark grey), 1 = fire (orange->black)
	const vec4 cmaps[16] = vec4[16](
		// smoke
		vec4(0.20, 0.15, 0.10, 0.75),
		vec4(0.22, 0.18, 0.16, 0.7),
		vec4(0.22, 0.19, 0.18, 0.65),
		vec4(0.28, 0.27, 0.26, 0.55),
		vec4(0.30, 0.29, 0.28, 0.42),
		vec4(0.27, 0.26, 0.25, 0.28),
		vec4(0.2, 0.2, 0.2, 0.14),
		vec4(0.12, 0.12, 0.12, 0.01),
		// fire
		vec4(1.0, 0.7, 0.15, 1.0),
		vec4(0.88, 0.4, 0.1, 0.9),
		vec4(0.5, 0.15, 0.07, 0.75),
		vec4(0.3, 0.1, 0.04, 0.55),
		vec4(0.1, 0.06, 0.02, 0.35),
		vec4(0.07, 0.02, 0.01, 0.18),
		vec4(0.02, 0.012, 0.005, 0.06),
		vec4(0.0, 0.0, 0.0, 0.01)
	);
	int cmapBase = cmapVariant * 8;
	float t = normalizedAge * 7.0;
	int idx = int(clamp(t, 0.0, 6.0));
	vec4 cmapColor = mix(cmaps[cmapBase + idx], cmaps[cmapBase + idx + 1], fract(t));

	// Per-particle brightness variation for smoke
	if (isFireParticle < 0.5) {
		float brightnessVar = 0.5 + seed * 0.5;
		float hBright = (highlightPass.x > 0.5) ? HIGHLIGHT_BRIGHT : 1.0;
		cmapColor.rgb *= brightnessVar * colorTint.rgb * hBright;
	}

	cmapColor.a *= colorTint.a;
	particleColor = cmapColor;

	// Animation
	if (isFireParticle > 0.5) {
		animFrame = floor(normalizedAge * 15.0 + 0.5);
		rowVariant = floor(seed * 6.0);
	} else {
		float smokeAnimSpeed = 0.13;
		float rawFrame = ageFrames * smokeAnimSpeed + seed * 8.0;
		animFrame = mod(floor(rawFrame), 8.0);
		rowVariant = floor(seed * 8.0);
	}
}
]]

local fsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 20000

//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

uniform sampler2D fireTex;
uniform sampler2D smokeTex;

in DataVS {
	vec2 texCoords;
	vec4 particleColor;
	float animFrame;
	float rowVariant;
	flat float isFireParticle;
};

out vec4 fragColor;

void main(void)
{
	if (particleColor.a <= 0.001) discard;

	vec4 texSample;
	if (isFireParticle > 0.5) {
		vec2 atlasUV = vec2(
			(animFrame + texCoords.x) * 0.0625,
			(clamp(rowVariant, 0.0, 5.0) + texCoords.y) * 0.16667
		);
		texSample = texture(fireTex, atlasUV);

		vec3 color = particleColor.rgb * texSample.rgb;
		float coreBright3 = texSample.r * texSample.r * texSample.r;
		float glowScale = coreBright3;
		color += glowScale * vec3(0.4, 0.32, 0.16);

		float a = texSample.a * particleColor.a;
		vec3 premul = color * (a + glowScale * 0.2);
		fragColor = vec4(premul, a);
	} else {
		vec2 atlasUV = vec2(
			(animFrame + texCoords.x) * 0.125,
			(clamp(rowVariant, 0.0, 7.0) + texCoords.y) * 0.125
		);
		texSample = texture(smokeTex, atlasUV);

		vec3 color = particleColor.rgb * texSample.rgb;
		float a = texSample.a * particleColor.a;
		fragColor = vec4(color * a, a);
	}

	if (fragColor.a < 0.005) discard;
}
]]

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------
local particleVBO = nil
local particleShader = nil
local nextParticleID = 0

-- Particle removal queue: [deathFrame] = {particleID, ...}
local particleRemoveQueue = {}

-- Quality preset state
local currentPreset = spGetConfigInt("GfxFireSmokeQuality", 3)
if not QUALITY_PRESETS[currentPreset] then
	currentPreset = 3
end
local particleCountSamples = {}
local sampleIndex = 0
local sampleCount = 0
local runningSum = 0
local avgParticleCount = 0
local lastPresetSwitchFrame = 0

-- Current budget limit (set before each spawn batch based on emitter priority)
local currentBudgetLimit = MAX_PARTICLES

-- Wind state (updated periodically)
local windX, windZ = 0, 0
local windStrength = 0

-- Cached FPS-based update interval floor
local cachedFpsInterval = 1
local cachedUpdateInterval = 1

-- Debug timing accumulators
local debugTimingSamples = 0
local debugTimings = {
	housekeeping = 0,
	qualityPreset = 0,
	removeExpired = 0,
	pointEmitters = 0,
	totalFrame = 0,
}

-- Cached per-frame state
local cachedGameFrame = 0
local cachedCamX, cachedCamY, cachedCamZ = 0, 0, 0
local cachedPreset = QUALITY_PRESETS[currentPreset]
local fastForward = false

-- Adaptive batch upload: defer individual GPU uploads when ops/draw ratio is high
local batchUploadMode = false -- current mode: true = defer uploads, false = immediate
local pendingOps = 0 -- ops since last DrawWorld

-- Pre-draw callbacks (called before DrawParticles, for consumer buffer flushing)
local preDrawCallbacks = {}

-- Update callbacks (called from engine's GameFrame — keeps everything in one Lua context)
-- Signature: fn(gameFrame, preset, camX, camY, camZ, isFastForward)
local updateCallbacks = {}
-- Per-frame callbacks (called every frame regardless of update interval)
-- Signature: fn(gameFrame, preset, camX, camY, camZ, isFastForward)
local perFrameCallbacks = {}

-- Auto-flush configs for off-screen buffer replay in DrawWorld
local autoFlushConfigs = {}
local nextAutoFlushID = 0

--------------------------------------------------------------------------------
-- Pre-compute quality preset thresholds
--------------------------------------------------------------------------------
local presetThresholds = {}
for i = 1, #QUALITY_PRESETS do
	presetThresholds[i] = QUALITY_PRESETS[i].maxPct * MAX_PARTICLES
end

local maxSamples = mathCeil(15 / 4)

local function updateQualityPreset(gameFrame)
	if not particleVBO then
		return
	end

	if gameFrame % 4 == 0 then
		sampleIndex = (sampleIndex % maxSamples) + 1
		local oldVal = particleCountSamples[sampleIndex] or 0
		local newVal = particleVBO.usedElements
		particleCountSamples[sampleIndex] = newVal
		runningSum = runningSum - oldVal + newVal
		if sampleCount < maxSamples then
			sampleCount = sampleCount + 1
		end
		avgParticleCount = runningSum / sampleCount
	end

	if gameFrame - lastPresetSwitchFrame < 15 then
		return
	end

	local newPreset = 1
	for i = #QUALITY_PRESETS, 1, -1 do
		if avgParticleCount < presetThresholds[i] then
			newPreset = i
			break
		end
	end
	if newPreset ~= currentPreset then
		currentPreset = newPreset
		cachedPreset = QUALITY_PRESETS[newPreset]
		lastPresetSwitchFrame = gameFrame
	end
end

local function updateMaxParticles(gameFrame)
	if gameFrame % 90 ~= 0 then
		return
	end
	local newMax = ((spGetConfigInt("MaxParticles", 10000) - 7000) * 3) + minFireSmokeParticles

	if newMax == MAX_PARTICLES then
		return
	end
	newMax = mathMin(newMax, VBO_CAPACITY)
	if newMax < 1 then
		newMax = 1
	end
	MAX_PARTICLES = newMax
	budgetLimits[PRIORITY_ESSENTIAL] = mathFloor(MAX_PARTICLES * BUDGET_ESSENTIAL)
	budgetLimits[PRIORITY_NORMAL] = mathFloor(MAX_PARTICLES * BUDGET_NORMAL)
	budgetLimits[PRIORITY_COSMETIC] = mathFloor(MAX_PARTICLES * BUDGET_COSMETIC)
	for i = 1, #QUALITY_PRESETS do
		presetThresholds[i] = QUALITY_PRESETS[i].maxPct * MAX_PARTICLES
	end
end

local function updateWind(gameFrame)
	if gameFrame % 10 ~= 0 then
		return
	end
	local _, _, _, strength, wx, _, wz = spGetWind()
	windX = wx or 0
	windZ = wz or 0
	windStrength = strength or 0
end

--------------------------------------------------------------------------------
-- Particle spawning
--------------------------------------------------------------------------------

local particleData = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0 }

local function spawnParticle(px, py, pz, vx, vy, vz, size, particleType, lifetime, alphaMult, tintBrightness, birthFrame)
	if not particleVBO or particleVBO.usedElements >= currentBudgetLimit then
		return
	end

	local bf = birthFrame or cachedGameFrame
	local deathFrame = bf + mathCeil(lifetime) + 2
	if deathFrame <= cachedGameFrame then
		return
	end

	local seed = mathRandom()

	particleData[1] = px
	particleData[2] = py
	particleData[3] = pz
	particleData[4] = bf
	particleData[5] = vx
	particleData[6] = vy
	particleData[7] = vz
	particleData[8] = lifetime
	particleData[9] = size
	particleData[10] = particleType
	particleData[11] = seed
	particleData[12] = (mathRandom() * 2 - 1) * mathPi
	local tb = tintBrightness or 1.0
	particleData[13] = tb
	particleData[14] = tb
	particleData[15] = tb
	particleData[16] = alphaMult

	nextParticleID = nextParticleID + 1
	local particleID = nextParticleID
	pushElementInstance(particleVBO, particleData, particleID, true, batchUploadMode)
	pendingOps = pendingOps + 1

	local queue = particleRemoveQueue[deathFrame]
	if not queue then
		queue = {}
		particleRemoveQueue[deathFrame] = queue
	end
	queue[#queue + 1] = particleID
end

--------------------------------------------------------------------------------
-- GL4 initialization
--------------------------------------------------------------------------------
local function goodbye(reason)
	spEcho("Particle Engine GL4 exiting: " .. reason)
	gadgetHandler:RemoveGadget()
end

local shaderSourceCache = {
	vsSrc = vsSrc,
	fsSrc = fsSrc,
	shaderName = "ParticleEngineGL4",
	uniformInt = {
		fireTex = 0,
		smokeTex = 1,
	},
	uniformFloat = {},
	shaderConfig = {
		SMOKE_GROWTH_MULT = 1.05,
		SMOKE_GROWTH_RATE = 0.11,
		SMOKE_WOBBLE_START = 0.6,
		SMOKE_WOBBLE_RAMP = 0.4,
		SMOKE_WOBBLE_RATE = 0.1,
		WIND_SMOKE_MULT = 0.0012,
		WIND_FIRE_MULT = 0.2,
		HIGHLIGHT_BRIGHT = SMOKE_HIGHLIGHT_BRIGHT,
	},
	forceupdate = true,
}

local function initGL4()
	particleShader = LuaShader.CheckShaderUpdates(shaderSourceCache)
	if not particleShader then
		goodbye("Failed to compile particle shader")
		return false
	end

	local quadVBO, numVertices = gl.InstanceVBOTable.makeRectVBO(-1, -1, 1, 1, 0, 0, 1, 1, "particleEngineQuadVBO")

	local particleLayout = {
		{ id = 1, name = "worldPos", size = 4 },
		{ id = 2, name = "velocity", size = 4 },
		{ id = 3, name = "sizeAndType", size = 4 },
		{ id = 4, name = "colorTint", size = 4 },
	}

	particleVBO = gl.InstanceVBOTable.makeInstanceVBOTable(particleLayout, MAX_PARTICLES, "particleEngineVBO")
	if not particleVBO then
		goodbye("Failed to create particle VBO")
		return false
	end

	particleVBO.numVertices = numVertices
	particleVBO.vertexVBO = quadVBO
	particleVBO.VAO = particleVBO:makeVAOandAttach(quadVBO, particleVBO.instanceVBO)
	particleVBO.primitiveType = GL.TRIANGLES

	local indexVBO = gl.InstanceVBOTable.makeRectIndexVBO("particleEngineIndexVBO")
	particleVBO.VAO:AttachIndexBuffer(indexVBO)
	particleVBO.indexVBO = indexVBO

	return true
end

local function cleanupGL4()
	if particleVBO then
		particleVBO:Delete()
		particleVBO = nil
	end
end

--------------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------------
local HIGHLIGHT_LIFE_INV = 1.0 / SMOKE_HIGHLIGHT_LIFE

local function DrawParticles()
	if not particleVBO or particleVBO.usedElements == 0 then
		return
	end
	if not particleShader then
		return
	end

	glDepthTest(true)
	glDepthMask(false)
	glCulling(false)

	glBlending(GL_ONE, GL_ONE_MINUS_SRC_ALPHA)

	glTexture(0, fireTexture)
	glTexture(1, smokeTexture)

	particleShader:Activate()

	particleShader:SetUniformFloat("windVelocity", windX, 0, windZ)

	-- Pass 1: Normal rendering
	particleShader:SetUniformFloat("highlightPass", 0, 1, 0, 1)
	particleVBO:Draw()

	-- Pass 2: Smoke highlight (fire particles killed in VS)
	particleShader:SetUniformFloat("highlightPass", 1, SMOKE_HIGHLIGHT_SIZE, SMOKE_HIGHLIGHT_OFFSET_Y, HIGHLIGHT_LIFE_INV)
	particleVBO:Draw()

	particleShader:Deactivate()

	glTexture(0, false)
	glTexture(1, false)

	glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	glDepthMask(true)
	glDepthTest(false)
end

local function removeExpiredParticles(gameFrame)
	local queue = particleRemoveQueue[gameFrame]
	if not queue then
		return
	end
	local noUpload = batchUploadMode
	for i = 1, #queue do
		popElementInstance(particleVBO, queue[i], noUpload)
		pendingOps = pendingOps + 1
	end
	particleRemoveQueue[gameFrame] = nil
end

--------------------------------------------------------------------------------
-- Generic point emitter system
-- Stationary (or slowly moving) fire/smoke sources.
-- Used for: wreck fires, burning trees, burning buildings, etc.
--------------------------------------------------------------------------------
local pointEmitters = {}
local nextEmitterID = 0
local pointEmitterCount = 0

local function spawnPointEmitterParticles(emitter, gameFrame, preset)
	local age = gameFrame - emitter.birthFrame

	if emitter.duration > 0 and age > emitter.duration then
		return false
	end

	emitter.spawnTimer = emitter.spawnTimer + 1
	if emitter.spawnTimer < emitter.spawnInterval then
		return true
	end
	emitter.spawnTimer = 0

	local px, py, pz = emitter.x, emitter.y, emitter.z

	if not spIsSphereInView(px, py, pz, POINT_CULLING_TOTAL) then
		return true
	end

	local dx, dy, dz = px - cachedCamX, py - cachedCamY, pz - cachedCamZ
	local distSq = dx * dx + dy * dy + dz * dz
	local lodMult = 1.0
	if distSq > LOD_DIST_NEAR_SQ then
		local t = (mathSqrt(distSq) - LOD_DIST_NEAR) * LOD_DIST_RANGE_INV
		lodMult = t >= 1.0 and LOD_MIN_MULT or (1.0 - t * LOD_MULT_RANGE)
	end

	local ageFrac = emitter.duration > 0 and (age / emitter.duration) or 0
	local decayMult = 1.0 - ageFrac * 0.5

	local presetLifeMult = preset.lifetimeMult * lodMult
	local spawnCount = mathMax(1, mathFloor(emitter.spawnCount * preset.spawnMult * lodMult * decayMult + 0.5))
	local sc = emitter.sizeScale
	local fi = emitter.fireIntensity
	local spread = emitter.posSpread

	currentBudgetLimit = budgetLimits[emitter.priority]

	local smokeLifeBase = presetLifeMult * emitter.smokeLifeMult
	local smokeAlphaBase = emitter.smokeAlpha * decayMult

	for p = 1, spawnCount do
		local sizeRand = mathRandom() * PARTICLE_SIZE_RANGE
		local particleSize = (PARTICLE_SIZE_MIN + sizeRand) * sc * emitter.smokeSizeMult
		local spx = px + (mathRandom() * 2 - 1) * spread
		local spy = py + mathRandom() * spread * 0.5
		local spz = pz + (mathRandom() * 2 - 1) * spread
		local svx = (mathRandom() * SMOKE_VEL_RANDOM_2 - SMOKE_VEL_RANDOM) * emitter.velocityScale
		local svy = (mathRandom() * SMOKE_VEL_UP_RANGE + SMOKE_VEL_UP_MIN) * emitter.velocityScale
		local svz = (mathRandom() * SMOKE_VEL_RANDOM_2 - SMOKE_VEL_RANDOM) * emitter.velocityScale
		local smokeLife = (POINT_SMOKE_LIFE_MIN + mathRandom() * POINT_SMOKE_LIFE_RANGE) * (1.0 + sizeRand * PARTICLE_SIZE_INV_RANGE) * smokeLifeBase
		local smokeAlpha = (SMOKE_ALPHA_MIN + mathRandom() * SMOKE_ALPHA_RANGE) * smokeAlphaBase
		spawnParticle(spx, spy, spz, svx, svy, svz, particleSize, 0, smokeLife, smokeAlpha)
	end

	if fi > 0 and mathRandom() < fi * decayMult then
		local sizeRand = mathRandom() * PARTICLE_SIZE_RANGE
		local particleSize = (PARTICLE_SIZE_MIN + sizeRand) * sc * FIRE_SIZE_MULT * emitter.fireSizeMult * fi
		spawnParticle(px + (mathRandom() * 2 - 1) * spread * 0.5, py + mathRandom() * spread * 0.3, pz + (mathRandom() * 2 - 1) * spread * 0.5, (mathRandom() * SMOKE_VEL_RANDOM_2 - SMOKE_VEL_RANDOM) * emitter.velocityScale, (mathRandom() * SMOKE_VEL_UP_RANGE + SMOKE_VEL_UP_MIN) * emitter.velocityScale, (mathRandom() * SMOKE_VEL_RANDOM_2 - SMOKE_VEL_RANDOM) * emitter.velocityScale, particleSize, 1, (FIRE_LIFETIME_MIN + mathRandom() * FIRE_LIFETIME_RANGE) * presetLifeMult * emitter.fireLifeMult * fi, (FIRE_ALPHA_MIN + mathRandom() * 0.2) * (0.5 + 0.5 * fi) * decayMult)
	end

	return true
end

local function updatePointEmitters(gameFrame)
	if pointEmitterCount == 0 then
		return
	end

	for emitterID, emitter in pairs(pointEmitters) do
		local alive = spawnPointEmitterParticles(emitter, gameFrame, cachedPreset)
		if not alive then
			pointEmitters[emitterID] = nil
			pointEmitterCount = pointEmitterCount - 1
		end
	end
end

--------------------------------------------------------------------------------
-- API functions
--------------------------------------------------------------------------------

local function apiBudget(priority)
	currentBudgetLimit = budgetLimits[priority or PRIORITY_NORMAL]
end

local function apiAddEmitter(params)
	if not particleVBO then
		return nil
	end
	if not params or not params.x then
		return nil
	end

	nextEmitterID = nextEmitterID + 1
	local id = nextEmitterID

	pointEmitters[id] = {
		x = params.x,
		y = params.y or (spGetGroundHeight(params.x, params.z or 0) or 0),
		z = params.z or 0,
		birthFrame = cachedGameFrame,
		duration = params.duration or 300,
		sizeScale = params.sizeScale or 1.0,
		fireIntensity = params.fireIntensity or 0,
		spawnCount = params.spawnCount or POINT_SPAWN_COUNT,
		spawnInterval = params.spawnInterval or POINT_SPAWN_INTERVAL,
		priority = params.priority or PRIORITY_NORMAL,
		smokeSizeMult = params.smokeSizeMult or 1.0,
		smokeLifeMult = params.smokeLifeMult or 1.0,
		smokeAlpha = params.smokeAlpha or 1.0,
		fireSizeMult = params.fireSizeMult or 1.0,
		fireLifeMult = params.fireLifeMult or 1.0,
		posSpread = params.posSpread or POINT_POS_SPREAD,
		velocityScale = params.velocityScale or 1.0,
		spawnTimer = 0,
	}
	pointEmitterCount = pointEmitterCount + 1

	return id
end

local function apiRemoveEmitter(emitterID)
	if emitterID and pointEmitters[emitterID] then
		pointEmitters[emitterID] = nil
		pointEmitterCount = pointEmitterCount - 1
		return true
	end
	return false
end

local function apiUpdateEmitterPos(emitterID, x, y, z)
	local emitter = pointEmitters[emitterID]
	if not emitter then
		return false
	end
	emitter.x = x
	emitter.y = y
	emitter.z = z
	return true
end

local function apiGetPreset(index)
	if index then
		return QUALITY_PRESETS[index]
	end
	return cachedPreset
end

local function apiGetGameFrame()
	return cachedGameFrame
end

local function apiGetCameraPos()
	return cachedCamX, cachedCamY, cachedCamZ
end

local function apiGetWindState()
	return windX, windZ, windStrength
end

local function apiIsFastForward()
	return fastForward
end

local function apiGetParticleCount()
	return particleVBO and particleVBO.usedElements or 0
end

local function apiGetMaxParticles()
	return MAX_PARTICLES
end

local function apiGetUpdateInterval()
	return cachedUpdateInterval
end

local function apiSetDefaults(overrides)
	for k, v in pairs(overrides) do
		if defaults[k] ~= nil then
			defaults[k] = v
		end
	end
	refreshDerivedConstants()
end

local function apiGetDefaults()
	return defaults
end

local function apiRegisterPreDrawCallback(fn)
	preDrawCallbacks[#preDrawCallbacks + 1] = fn
end

local function apiUnregisterPreDrawCallback(fn)
	for i = #preDrawCallbacks, 1, -1 do
		if preDrawCallbacks[i] == fn then
			table.remove(preDrawCallbacks, i)
			break
		end
	end
end

--------------------------------------------------------------------------------
-- Off-screen buffer management
-- Consumers call bufferOffscreen() when an entity is off-screen to store
-- position/velocity snapshots. When the entity comes back into view, the
-- consumer calls replayBuffer() to spawn retroactive particles.
-- registerAutoFlush() automates the pre-draw visibility check.
--------------------------------------------------------------------------------

-- Buffer an off-screen position/velocity snapshot for later replay.
-- Automatically skips during fast-forward.
-- throttle: optional, only buffer every Nth frame (default 1 = every frame)
local function apiBufferOffscreen(tracked, gameFrame, px, py, pz, vx, vy, vz, throttle)
	if fastForward then
		return
	end
	if throttle and throttle > 1 and gameFrame % throttle ~= 0 then
		return
	end
	local buf = tracked.offscreenBuffer
	if not buf then
		buf = {}
		tracked.offscreenBuffer = buf
	end
	buf[#buf + 1] = { gameFrame, px, py, pz, vx, vy, vz }
end

-- Replay buffered snapshots if buffer exists.
-- Calls replayFn(tracked, gameFrame, buffer) where buffer is the array.
-- Returns true if buffer was flushed.
local function apiReplayBuffer(tracked, gameFrame, replayFn)
	local buf = tracked.offscreenBuffer
	if not buf or #buf == 0 then
		tracked.offscreenBuffer = nil
		return false
	end
	replayFn(tracked, gameFrame, buf)
	tracked.offscreenBuffer = nil
	return true
end

-- Register automatic pre-draw buffer flushing for a table of tracked entities.
-- params.entities:      table keyed by entityID -> tracked data
-- params.positionFn:    fn(entityID) -> px,py,pz or nil
-- params.cullingRadius: number (sphere radius for visibility check)
-- params.replayFn:      fn(tracked, gameFrame, buffer) called when buffer needs flushing
-- Returns a handle for unregistration.
local function apiRegisterAutoFlush(params)
	nextAutoFlushID = nextAutoFlushID + 1
	local id = nextAutoFlushID
	autoFlushConfigs[id] = {
		entities = params.entities,
		positionFn = params.positionFn,
		cullingRadius = params.cullingRadius,
		replayFn = params.replayFn,
	}
	return id
end

local function apiUnregisterAutoFlush(handle)
	if handle then
		autoFlushConfigs[handle] = nil
	end
end

-- Register an update callback called at the computed update interval.
-- fn(gameFrame, preset, camX, camY, camZ, isFastForward)
local function apiRegisterUpdateCallback(fn)
	updateCallbacks[#updateCallbacks + 1] = fn
end

local function apiUnregisterUpdateCallback(fn)
	for i = #updateCallbacks, 1, -1 do
		if updateCallbacks[i] == fn then
			table.remove(updateCallbacks, i)
			break
		end
	end
end

-- Register a per-frame callback (called every GameFrame, for lightweight periodic work).
-- fn(gameFrame, preset, camX, camY, camZ, isFastForward)
local function apiRegisterPerFrameCallback(fn)
	perFrameCallbacks[#perFrameCallbacks + 1] = fn
end

local function apiUnregisterPerFrameCallback(fn)
	for i = #perFrameCallbacks, 1, -1 do
		if perFrameCallbacks[i] == fn then
			table.remove(perFrameCallbacks, i)
			break
		end
	end
end

--------------------------------------------------------------------------------
-- Gadget callins
--------------------------------------------------------------------------------

function gadget:Initialize()
	if not gl.CreateShader then
		goodbye("OpenGL shaders not supported")
		return
	end

	if not initGL4() then
		return
	end

	-- Expose public API
	GG.Particles = {
		-- Particle spawning
		spawnParticle = spawnParticle,
		setBudget = apiBudget,

		-- Point emitter management
		addEmitter = apiAddEmitter,
		removeEmitter = apiRemoveEmitter,
		updateEmitterPos = apiUpdateEmitterPos,

		-- Callback registration (consumers use these instead of their own GameFrame/DrawWorld)
		registerUpdateCallback = apiRegisterUpdateCallback,
		unregisterUpdateCallback = apiUnregisterUpdateCallback,
		registerPerFrameCallback = apiRegisterPerFrameCallback,
		unregisterPerFrameCallback = apiUnregisterPerFrameCallback,
		registerPreDrawCallback = apiRegisterPreDrawCallback,
		unregisterPreDrawCallback = apiUnregisterPreDrawCallback,

		-- Off-screen buffer management (consumers use these for retroactive replay)
		bufferOffscreen = apiBufferOffscreen,
		replayBuffer = apiReplayBuffer,
		registerAutoFlush = apiRegisterAutoFlush,
		unregisterAutoFlush = apiUnregisterAutoFlush,

		-- State queries (cached, cheap to call)
		getPreset = apiGetPreset,
		getGameFrame = apiGetGameFrame,
		getCameraPos = apiGetCameraPos,
		getWindState = apiGetWindState,
		isFastForward = apiIsFastForward,
		getParticleCount = apiGetParticleCount,
		getMaxParticles = apiGetMaxParticles,
		getUpdateInterval = apiGetUpdateInterval,

		-- Priority constants
		PRIORITY_ESSENTIAL = PRIORITY_ESSENTIAL,
		PRIORITY_NORMAL = PRIORITY_NORMAL,
		PRIORITY_COSMETIC = PRIORITY_COSMETIC,

		-- Quality preset indices
		QUALITY_LOW = 1,
		QUALITY_MEDIUM = 2,
		QUALITY_HIGH = 3,

		-- Default property accessors (consumers can read/write these)
		getDefaults = apiGetDefaults,
		setDefaults = apiSetDefaults,

		-- Shared physics constants (snapshot of current defaults for consumer localization)
		SMOKE_VEL_UP_MIN = SMOKE_VEL_UP_MIN,
		SMOKE_VEL_UP_RANGE = SMOKE_VEL_UP_RANGE,
		SMOKE_VEL_RANDOM = SMOKE_VEL_RANDOM,
		SMOKE_VEL_RANDOM_2 = SMOKE_VEL_RANDOM_2,
		PARTICLE_SIZE_MIN = PARTICLE_SIZE_MIN,
		PARTICLE_SIZE_MAX = PARTICLE_SIZE_MAX,
		PARTICLE_SIZE_RANGE = PARTICLE_SIZE_RANGE,
		PARTICLE_SIZE_INV_RANGE = PARTICLE_SIZE_INV_RANGE,
		FIRE_LIFETIME_MIN = FIRE_LIFETIME_MIN,
		FIRE_LIFETIME_RANGE = FIRE_LIFETIME_RANGE,
		FIRE_SIZE_MULT = FIRE_SIZE_MULT,
		FIRE_ALPHA_MIN = FIRE_ALPHA_MIN,
		SMOKE_ALPHA_MIN = SMOKE_ALPHA_MIN,
		SMOKE_ALPHA_RANGE = SMOKE_ALPHA_RANGE,
		CULLING_MARGIN = CULLING_MARGIN,
	}

	-- Backward compatibility alias
	GG.FireSmoke = GG.Particles
end

function gadget:Shutdown()
	cleanupGL4()
	GG.Particles = nil
	GG.FireSmoke = nil
end

function gadget:GameFrame(n)
	if not particleVBO then
		return
	end

	local t0, t1, tStart
	if debugEcho then
		tStart = spGetTimer()
		t0 = tStart
	end

	cachedGameFrame = n
	cachedCamX, cachedCamY, cachedCamZ = spGetCameraPosition()

	-- Detect fast-forward / rejoin
	local userSpeed, internalSpeed = spGetGameSpeed()
	fastForward = (internalSpeed or userSpeed) > 1.5

	-- Periodic housekeeping
	local nMod = n % 90
	if nMod == 0 then
		updateMaxParticles(n)
	end
	if n % 10 == 0 then
		updateWind(n)
	end

	if debugEcho then
		t1 = spGetTimer()
		debugTimings.housekeeping = debugTimings.housekeeping + spDiffTimers(t1, t0, true)
		t0 = t1
	end

	-- Quality auto-scaling
	updateQualityPreset(n)

	-- Override to Low during fast-forward; restore from currentPreset otherwise
	cachedPreset = fastForward and QUALITY_PRESETS[1] or QUALITY_PRESETS[currentPreset]

	if debugEcho then
		t1 = spGetTimer()
		debugTimings.qualityPreset = debugTimings.qualityPreset + spDiffTimers(t1, t0, true)
		t0 = t1
	end

	-- Remove expired particles
	removeExpiredParticles(n)

	if debugEcho then
		t1 = spGetTimer()
		debugTimings.removeExpired = debugTimings.removeExpired + spDiffTimers(t1, t0, true)
		t0 = t1
	end

	-- Compute update interval (exposed to consumers)
	local interval = 1
	if avgParticleCount > MAX_PARTICLES * 0.8 then
		interval = 3
	elseif avgParticleCount > MAX_PARTICLES * 0.4 then
		interval = 2
	end
	if n % 15 == 0 then
		local fps = spGetFPS()
		if fps > 0 then
			cachedFpsInterval = mathCeil(30 / fps)
		end
	end
	if cachedFpsInterval > interval then
		interval = cachedFpsInterval
	end
	-- Scale update interval with game speed during fast-forward
	if fastForward then
		local ffInterval = mathCeil((internalSpeed or userSpeed) * 0.5)
		if ffInterval > interval then
			interval = ffInterval
		end
	end
	cachedUpdateInterval = interval

	-- Call per-frame callbacks (lightweight periodic work)
	for i = 1, #perFrameCallbacks do
		perFrameCallbacks[i](n, cachedPreset, cachedCamX, cachedCamY, cachedCamZ, fastForward)
	end

	-- Update point emitters + consumer update callbacks (respects update interval)
	if n % interval == 0 then
		for i = 1, #updateCallbacks do
			updateCallbacks[i](n, cachedPreset, cachedCamX, cachedCamY, cachedCamZ, fastForward)
		end
		updatePointEmitters(n)
	end

	if debugEcho then
		t1 = spGetTimer()
		debugTimings.pointEmitters = debugTimings.pointEmitters + spDiffTimers(t1, t0, true)
		debugTimings.totalFrame = debugTimings.totalFrame + spDiffTimers(t1, tStart, true)
		debugTimingSamples = debugTimingSamples + 1

		if n % 30 == 0 and debugTimingSamples > 0 then
			local inv = 1000 / debugTimingSamples
			spEcho(string.format("Particle Engine GL4 (us/frame avg %d): TOTAL=%.1f  housekeep=%.1f  quality=%.1f  removeExp=%.1f  pointEm=%.1f  | particles=%d  emitters=%d  preset=%s  interval=%d  wind=%d", debugTimingSamples, debugTimings.totalFrame * inv, debugTimings.housekeeping * inv, debugTimings.qualityPreset * inv, debugTimings.removeExpired * inv, debugTimings.pointEmitters * inv, mathFloor(avgParticleCount), pointEmitterCount, cachedPreset.name, cachedUpdateInterval, mathFloor(windStrength)))
			for k in pairs(debugTimings) do
				debugTimings[k] = 0
			end
			debugTimingSamples = 0
		end
	end
end

function gadget:DrawWorld()
	-- Fire pre-draw callbacks (consumers flush off-screen buffers here)
	for i = 1, #preDrawCallbacks do
		preDrawCallbacks[i]()
	end

	-- Auto-flush off-screen buffers for registered entity tables
	local gameFrame = cachedGameFrame
	for _, config in pairs(autoFlushConfigs) do
		local posFn = config.positionFn
		local radius = config.cullingRadius
		local replayFn = config.replayFn
		for entityID, tracked in pairs(config.entities) do
			if tracked.offscreenBuffer then
				local px, py, pz = posFn(entityID)
				if px and spIsSphereInView(px, py, pz, radius) then
					apiReplayBuffer(tracked, gameFrame, replayFn)
				end
			end
		end
	end

	-- Flush deferred GPU uploads and decide batch mode for next interval
	if particleVBO then
		if particleVBO.dirty then
			uploadAllElements(particleVBO)
		end
		-- Adaptive: batch if ops since last draw > 3% of used elements (min 40)
		-- At 1x ~60fps: ~20 ops/draw vs 5000 elements → individual (20 < 150)
		-- At 5x ~60fps: ~150 ops/draw → borderline, switches to batch
		-- At 10x ~60fps: ~500 ops/draw → batch (500 > 150)
		local threshold = mathMax(40, (particleVBO.usedElements or 0) * 0.03)
		batchUploadMode = pendingOps > threshold
		pendingOps = 0
	end

	DrawParticles()
end
