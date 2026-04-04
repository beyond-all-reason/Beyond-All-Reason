--------------------------------------------------------------------------------
-- GPU-based fire & smoke particle system
-- General-purpose instanced GL4 fire/smoke renderer with:
--   - Piece projectile debris trails
--   - Crashing aircraft smoke trails
--   - Generic point emitters (wreck fires, tree fires, etc.)
--   - Wind-influenced particle drift
--   - Priority-based particle budgeting
--   - Public GG.FireSmoke API for other gadgets
--------------------------------------------------------------------------------

if gadgetHandler:IsSyncedCode() then
	return
end

function gadget:GetInfo()
	return {
		name = "Fire & Smoke GL4",
		desc = "GPU-instanced fire and smoke particle system with emitter API",
		author = "Floris",
		date = "March 2026",
		license = "GNU GPL v2",
		layer = 0,
		enabled = true,
	}
end

local debugEcho = false

--------------------------------------------------------------------------------
-- Localized functions
--------------------------------------------------------------------------------
local spGetGroundHeight = Spring.GetGroundHeight
local spEcho = Spring.Echo
local spGetTimer = Spring.GetTimer
local spDiffTimers = Spring.DiffTimers
local spGetProjectilesInRectangle = Spring.GetProjectilesInRectangle
local spGetProjectilePosition = Spring.GetProjectilePosition
local spGetProjectileVelocity = Spring.GetProjectileVelocity
local spIsSphereInView = Spring.IsSphereInView
local spGetCameraPosition = Spring.GetCameraPosition
local spGetProjectileOwnerID = Spring.GetProjectileOwnerID
local spGetFPS = Spring.GetFPS
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitVelocity = Spring.GetUnitVelocity
local spValidUnitID = Spring.ValidUnitID
local spGetWind = Spring.GetWind
local spGetConfigInt = Spring.GetConfigInt
local spGetGameSpeed = Spring.GetGameSpeed

local mapSizeX = Game.mapSizeX
local mapSizeZ = Game.mapSizeZ

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

--------------------------------------------------------------------------------
-- Priority levels for particle budgeting
--------------------------------------------------------------------------------
local PRIORITY_ESSENTIAL = 1 -- always emit: crash trails, wreck fires (gameplay-relevant)
local PRIORITY_NORMAL = 2 -- standard: piece debris trails
local PRIORITY_COSMETIC = 3 -- reduced first: ambient fluff, extra detail

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

-- Textures
local fireTexture = "bitmaps/projectiletextures/BARFlame02.tga"
local smokeTexture = "bitmaps/projectiletextures/smoke-beh-anim.tga"

-- General (MAX_PARTICLES read from configint so the options widget can expose a slider)
local minFireSmokeParticles = 10000 -- before MaxParticles is added
local MAX_PARTICLES = ((spGetConfigInt("MaxParticles", 10000) - 7500) * 3) + minFireSmokeParticles -- NOTE: actual calc is in func updateMaxParticles

local VBO_CAPACITY = MAX_PARTICLES -- fixed at init; VBO cannot be resized
local PARTICLE_SIZE_MIN = 1
local PARTICLE_SIZE_MAX = 4

-- Priority-based budget: each priority level can fill the VBO up to this fraction
local BUDGET_ESSENTIAL = 1.0 -- essential emitters can use 100% of VBO
local BUDGET_NORMAL = 0.85 -- normal emitters can use up to 85%
local BUDGET_COSMETIC = 0.60 -- cosmetic emitters can use up to 60%

-- Shared smoke physics (used by all emitter types)
local SMOKE_VEL_UP_MIN = 0.04 -- minimum upward velocity for smoke
local SMOKE_VEL_UP_MAX = 0.20 -- maximum upward velocity
local SMOKE_VEL_RANDOM = 0.1 -- random velocity offset per axis

-- Smoke highlight: lighter particle layered above each smoke particle (simulates sunlit top)
local SMOKE_HIGHLIGHT_OFFSET_Y = 2.2 -- vertical offset above base smoke (elmos)
local SMOKE_HIGHLIGHT_BRIGHT = 2.8 -- brightness multiplier for highlight (via colorTint.rgb)
local SMOKE_HIGHLIGHT_SIZE = 0.85 -- size relative to base smoke particle
local SMOKE_HIGHLIGHT_LIFE = 0.7 -- lifetime relative to base smoke particle

-- Wind influence (WIND_SMOKE_MULT=0.0012, WIND_FIRE_MULT=0.2 defined in shaderConfig)

-- Frustum culling margin (elmos beyond visible sphere to still spawn)
local CULLING_MARGIN = 200

-- Fire particle settings (shared base, each trail type can scale)
local FIRE_LIFETIME_MIN = 20 -- min fire particle lifetime in frames
local FIRE_LIFETIME_RANGE = 100 -- fire lifetime variation
local FIRE_SIZE_MULT = 7.5 -- fire particles relative to smoke
local FIRE_ALPHA_MIN = 0.55 -- fire particles base alpha

-- Piece projectile trails (smoke and fire on flying debris)
local PIECE_SPAWN_COUNT_MAX = 3
local PIECE_SPAWN_TAPER = 2
local PIECE_SKIP_CHANCE = 0.4
local PIECE_VEL_SCALE = 6.0
local PIECE_LIFETIME_MIN = 35
local PIECE_LIFETIME_MAX = 85
local PIECE_SIZE_SCALE_MIN = 0.18
local PIECE_SIZE_SCALE_MAX = 0.5
local PIECE_SIZE_SCALE_REF = 25.0
local PIECE_LIFE_BASE = 200
local PIECE_LIFE_PER_RADIUS = 1.5
local PIECE_ALPHA_FADE = 0.66
local PIECE_ALPHA_MIN = 0.25
local PIECE_GROUND_SKIP_HEIGHT = 5
local PIECE_FIRE_CHANCE = 0.3

-- Distance LOD: reduce spawn count when camera is far away (piece trails)
local LOD_DIST_NEAR = 4000
local LOD_DIST_FAR = 10000
local LOD_MIN_MULT = 0.33
local LOD_DIST_RANGE_INV = 1.0 / (LOD_DIST_FAR - LOD_DIST_NEAR)
local LOD_MULT_RANGE = 1.0 - LOD_MIN_MULT
local LOD_DIST_NEAR_SQ = LOD_DIST_NEAR * LOD_DIST_NEAR

-- Crashing aircraft trails
local CRASH_SPAWN_COUNT = 2
local CRASH_VEL_INHERIT = 0.6
local CRASH_ALPHA_FADE = 0.66
local CRASH_ALPHA_MIN = 0.25
local CRASH_SKIP_CHANCE = 0.05
local CRASH_FIRE_LIFETIME_MULT = 1.6
local CRASH_FIRE_SIZE_MULT = 1
local CRASH_CULLING_RADIUS = 200
local CRASH_MAX_DURATION = 450
local CRASH_LIFETIME_MIN = 120
local CRASH_LIFETIME_RANGE = 90

-- Unit-based crash trail scaling (+ fire chance/intensity thresholds)
local crashScale = {
	RADIUS_REF = 30,
	COST_REF = 250,
	RADIUS_WEIGHT = 0.4,
	COST_WEIGHT = 0.7,
	MIN = 0.66,
	MAX = 1.15,
	SIZE_EXP = 0.8,
	LIFE_EXP = 0.5,
	SPAWN_EXP = 0.6,
	FIRE_CHANCE = 0.66,
	FIRE_INT_MIN = 0.66,
}

-- Distance LOD for crashing aircraft
local CRASH_LOD_DIST_NEAR = 6000
local CRASH_LOD_DIST_FAR = 15000
local CRASH_LOD_MIN_MULT = 0.45
local CRASH_LOD_DIST_RANGE_INV = 1.0 / (CRASH_LOD_DIST_FAR - CRASH_LOD_DIST_NEAR)
local CRASH_LOD_MULT_RANGE = 1.0 - CRASH_LOD_MIN_MULT
local CRASH_LOD_DIST_NEAR_SQ = CRASH_LOD_DIST_NEAR * CRASH_LOD_DIST_NEAR

-- Point emitter defaults (for generic fire/smoke sources)
local POINT_SPAWN_INTERVAL = 2 -- frames between spawns
local POINT_SPAWN_COUNT = 2 -- particles per interval
local POINT_SMOKE_LIFE_MIN = 60 -- min smoke particle lifetime
local POINT_SMOKE_LIFE_RANGE = 60 -- lifetime variation
local POINT_POS_SPREAD = 2.0 -- random position offset (elmos)
local POINT_CULLING_RADIUS = 100 -- view frustum check radius

-- Pre-computed constants (avoid repeated arithmetic in hot loops)
local SMOKE_VEL_UP_RANGE = SMOKE_VEL_UP_MAX - SMOKE_VEL_UP_MIN
local SMOKE_VEL_RANDOM_2 = SMOKE_VEL_RANDOM * 2
local PIECE_VEL_COMBINED = PIECE_VEL_SCALE * 0.05
local PARTICLE_SIZE_RANGE = PARTICLE_SIZE_MAX - PARTICLE_SIZE_MIN
local PIECE_ALPHA_RANGE = 1.0 - PIECE_ALPHA_MIN
local PIECE_LIFETIME_RANGE = PIECE_LIFETIME_MAX - PIECE_LIFETIME_MIN
local PARTICLE_SIZE_INV_RANGE = 1.0 / PARTICLE_SIZE_RANGE
local CRASH_ALPHA_RANGE = 1.0 - CRASH_ALPHA_MIN
local CRASH_CULLING_TOTAL = CRASH_CULLING_RADIUS + CULLING_MARGIN
local POINT_CULLING_TOTAL = POINT_CULLING_RADIUS + CULLING_MARGIN

-- Priority budget limits (computed from MAX_PARTICLES)
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
		maxPct = 0.66,
	},
	[3] = {
		name = "High",
		spawnMult = 1.0,
		pieceCountMult = 1.0,
		lifetimeMult = 0.4,
		maxPct = 0.33,
	},
}

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

	// Colormaps: 0 = smoke (dark grey), 1 = fire (orange→black)
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

-- Cache of unit death effect sizes
local unitDeathSizeCache = {} -- [unitDefID] = radius

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

-- Cached FPS-based update interval floor (refreshed every 15 frames)
local cachedFpsInterval = 1

-- Debug timing accumulators (only used when debugEcho = true)
local debugTimingSamples = 0
local debugTimings = {
	housekeeping = 0,
	qualityPreset = 0,
	removeExpired = 0,
	pieceProjectiles = 0,
	crashingAircraft = 0,
	pointEmitters = 0,
	cleanup = 0,
	totalFrame = 0,
}

-- Cached per-frame state
local cachedGameFrame = 0
local cachedCamX, cachedCamY, cachedCamZ = 0, 0, 0
local cachedPreset = QUALITY_PRESETS[currentPreset]
local cachedBudgetNormal = budgetLimits[PRIORITY_NORMAL]
local cachedBudgetEssential = budgetLimits[PRIORITY_ESSENTIAL]
local fastForward = false -- true when gamespeed > 1.5 or catching up (rejoining)

--------------------------------------------------------------------------------
-- Helper functions
--------------------------------------------------------------------------------

local PIECE_CULLING_RADIUS = 50 + CULLING_MARGIN

-- Pre-compute quality preset thresholds
local presetThresholds = {}
for i = 1, #QUALITY_PRESETS do
	presetThresholds[i] = QUALITY_PRESETS[i].maxPct * MAX_PARTICLES
end

local maxSamples = mathCeil(15 / 4) -- AVG_WINDOW_FRAMES / AVG_SAMPLE_INTERVAL

local function updateQualityPreset(gameFrame)
	if not particleVBO then
		return
	end

	if gameFrame % 4 == 0 then -- AVG_SAMPLE_INTERVAL
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
	end -- PRESET_SWITCH_COOLDOWN

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
	end -- re-read configint every ~3 seconds
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
	cachedBudgetNormal = budgetLimits[PRIORITY_NORMAL]
	cachedBudgetEssential = budgetLimits[PRIORITY_ESSENTIAL]
	for i = 1, #QUALITY_PRESETS do
		presetThresholds[i] = QUALITY_PRESETS[i].maxPct * MAX_PARTICLES
	end
end

local function updateWind(gameFrame)
	if gameFrame % 10 ~= 0 then
		return
	end -- WIND_UPDATE_INTERVAL
	local _, _, _, strength, wx, _, wz = spGetWind()
	windX = wx or 0
	windZ = wz or 0
	windStrength = strength or 0
end

-- Pre-cache unit death sizes from UnitDefs
-- Excludes critters (category OBJECT) and raptors (category RAPTOR)
local function buildUnitDeathSizeCache()
	for udid, ud in pairs(UnitDefs) do
		local cats = ud.modCategories
		if not cats or (not cats.object and not cats.raptor) then
			local radius = ud.radius or 10
			local xsize = ud.xsize or 2
			local zsize = ud.zsize or 2
			local footprint = mathMax(xsize, zsize) * 4
			unitDeathSizeCache[udid] = mathMax(radius, footprint * 0.5)
		end
	end
end

--------------------------------------------------------------------------------
-- Particle spawning
--------------------------------------------------------------------------------

local particleData = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0 }

local function spawnParticle(px, py, pz, vx, vy, vz, size, cmapVariant, lifetime, alphaMult, tintBrightness, birthFrame)
	if particleVBO.usedElements >= currentBudgetLimit then
		return
	end

	local bf = birthFrame or cachedGameFrame
	local deathFrame = bf + mathCeil(lifetime) + 2
	if deathFrame <= cachedGameFrame then
		return
	end -- already expired (retroactive particle)

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
	particleData[10] = cmapVariant
	particleData[11] = seed
	particleData[12] = (mathRandom() * 2 - 1) * mathPi
	local tb = tintBrightness or 1.0
	particleData[13] = tb
	particleData[14] = tb
	particleData[15] = tb
	particleData[16] = alphaMult

	nextParticleID = nextParticleID + 1
	local particleID = nextParticleID
	pushElementInstance(particleVBO, particleData, particleID, true, false)

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
	spEcho("Fire & Smoke GL4 exiting: " .. reason)
	gadgetHandler:RemoveGadget()
end

local shaderSourceCache = {
	vsSrc = vsSrc,
	fsSrc = fsSrc,
	shaderName = "FireSmokeGL4",
	uniformInt = {
		fireTex = 0,
		smokeTex = 1,
	},
	uniformFloat = {},
	shaderConfig = {
		SMOKE_GROWTH_MULT = 1.05, -- growth over lifetime
		SMOKE_GROWTH_RATE = 0.11, -- time-based growth per frame (elmos)
		SMOKE_WOBBLE_START = 0.6, -- initial turbulence amplitude (elmos)
		SMOKE_WOBBLE_RAMP = 0.4, -- wobble ramp over lifetime, scaled by particle size
		SMOKE_WOBBLE_RATE = 0.1, -- time-based wobble growth per frame (elmos)
		WIND_SMOKE_MULT = 0.0012, -- wind push on smoke (per frame * wind speed)
		WIND_FIRE_MULT = 0.2, -- fire wind resistance (fraction of smoke)
		HIGHLIGHT_BRIGHT = SMOKE_HIGHLIGHT_BRIGHT, -- highlight brightness multiplier
	},
	forceupdate = true,
}

local function initGL4()
	particleShader = LuaShader.CheckShaderUpdates(shaderSourceCache)
	if not particleShader then
		goodbye("Failed to compile particle shader")
		return false
	end

	local quadVBO, numVertices = gl.InstanceVBOTable.makeRectVBO(-1, -1, 1, 1, 0, 0, 1, 1, "fireSmokeQuadVBO")

	local particleLayout = {
		{ id = 1, name = "worldPos", size = 4 },
		{ id = 2, name = "velocity", size = 4 },
		{ id = 3, name = "sizeAndType", size = 4 },
		{ id = 4, name = "colorTint", size = 4 },
	}

	particleVBO = gl.InstanceVBOTable.makeInstanceVBOTable(particleLayout, MAX_PARTICLES, "fireSmokeVBO")
	if not particleVBO then
		goodbye("Failed to create particle VBO")
		return false
	end

	particleVBO.numVertices = numVertices
	particleVBO.vertexVBO = quadVBO
	particleVBO.VAO = particleVBO:makeVAOandAttach(quadVBO, particleVBO.instanceVBO)
	particleVBO.primitiveType = GL.TRIANGLES

	local indexVBO = gl.InstanceVBOTable.makeRectIndexVBO("fireSmokeIndexVBO")
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
-- Pre-computed highlight pass uniform values
local HIGHLIGHT_LIFE_INV = 1.0 / SMOKE_HIGHLIGHT_LIFE -- = 1/0.7 ≈ 1.4286

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

	-- Upload wind uniform
	particleShader:SetUniformFloat("windVelocity", windX, 0, windZ)

	-- Pass 1: Normal rendering (all particles)
	particleShader:SetUniformFloat("highlightPass", 0, 1, 0, 1)
	particleVBO:Draw()

	-- Pass 2: Smoke highlight (fire particles killed in VS, smoke gets offset/brighter/smaller/shorter)
	particleShader:SetUniformFloat("highlightPass", 1, SMOKE_HIGHLIGHT_SIZE, SMOKE_HIGHLIGHT_OFFSET_Y, HIGHLIGHT_LIFE_INV)
	particleVBO:Draw()

	particleShader:Deactivate()

	glTexture(0, false)
	glTexture(1, false)

	glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	glDepthMask(true)
	glDepthTest(false)
end

-- Remove expired particles from VBO (runs every frame, pops exact deathFrame queue)
local function removeExpiredParticles(gameFrame)
	local queue = particleRemoveQueue[gameFrame]
	if not queue then
		return
	end
	for i = 1, #queue do
		popElementInstance(particleVBO, queue[i])
	end
	particleRemoveQueue[gameFrame] = nil
end

--------------------------------------------------------------------------------
-- Generic point emitter system
--------------------------------------------------------------------------------
-- Point emitters are stationary (or slowly moving) fire/smoke sources.
-- Other gadgets create them via GG.FireSmoke.AddPointEmitter().
-- Used for: wreck fires, burning trees, burning buildings, etc.
--------------------------------------------------------------------------------
local pointEmitters = {} -- [emitterID] = emitter data
local nextEmitterID = 0
local pointEmitterCount = 0

local function spawnPointEmitterParticles(emitter, gameFrame, preset)
	local age = gameFrame - emitter.birthFrame

	-- Check duration (0 = permanent until removed)
	if emitter.duration > 0 and age > emitter.duration then
		return false
	end

	emitter.spawnTimer = emitter.spawnTimer + 1
	if emitter.spawnTimer < emitter.spawnInterval then
		return true
	end
	emitter.spawnTimer = 0

	local px, py, pz = emitter.x, emitter.y, emitter.z

	-- View frustum culling
	if not spIsSphereInView(px, py, pz, POINT_CULLING_TOTAL) then
		return true
	end

	-- Distance LOD
	local dx, dy, dz = px - cachedCamX, py - cachedCamY, pz - cachedCamZ
	local distSq = dx * dx + dy * dy + dz * dz
	local lodMult = 1.0
	if distSq > LOD_DIST_NEAR_SQ then
		local t = (mathSqrt(distSq) - LOD_DIST_NEAR) * LOD_DIST_RANGE_INV
		lodMult = t >= 1.0 and LOD_MIN_MULT or (1.0 - t * LOD_MULT_RANGE)
	end

	-- Age-based decay: intensity reduces over lifetime
	local ageFrac = emitter.duration > 0 and (age / emitter.duration) or 0
	local decayMult = 1.0 - ageFrac * 0.5 -- 50% reduction at end of life

	local presetLifeMult = preset.lifetimeMult * lodMult
	local spawnCount = mathMax(1, mathFloor(emitter.spawnCount * preset.spawnMult * lodMult * decayMult + 0.5))
	local sc = emitter.sizeScale
	local fi = emitter.fireIntensity
	local spread = emitter.posSpread

	-- Set budget limit based on emitter priority
	currentBudgetLimit = budgetLimits[emitter.priority]

	local smokeLifeBase = presetLifeMult * emitter.smokeLifeMult
	local smokeAlphaBase = emitter.smokeAlpha * decayMult

	-- Smoke particles
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
		local smokeAlpha = (PIECE_ALPHA_MIN + mathRandom() * PIECE_ALPHA_RANGE) * smokeAlphaBase
		spawnParticle(spx, spy, spz, svx, svy, svz, particleSize, 0, smokeLife, smokeAlpha)
	end

	-- Fire particle
	if fi > 0 and mathRandom() < fi * decayMult then
		local sizeRand = mathRandom() * PARTICLE_SIZE_RANGE
		local particleSize = (PARTICLE_SIZE_MIN + sizeRand) * sc * FIRE_SIZE_MULT * emitter.fireSizeMult * fi
		spawnParticle(px + (mathRandom() * 2 - 1) * spread * 0.5, py + mathRandom() * spread * 0.3, pz + (mathRandom() * 2 - 1) * spread * 0.5, (mathRandom() * SMOKE_VEL_RANDOM_2 - SMOKE_VEL_RANDOM) * emitter.velocityScale, (mathRandom() * SMOKE_VEL_UP_RANGE + SMOKE_VEL_UP_MIN) * emitter.velocityScale, (mathRandom() * SMOKE_VEL_RANDOM_2 - SMOKE_VEL_RANDOM) * emitter.velocityScale, particleSize, 1, (FIRE_LIFETIME_MIN + mathRandom() * FIRE_LIFETIME_RANGE) * presetLifeMult * emitter.fireLifeMult * fi, (FIRE_ALPHA_MIN + mathRandom() * 0.2) * (0.5 + 0.5 * fi) * decayMult)
	end

	return true -- emitter still alive
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
-- Piece projectile tracking (debris fire trails)
--------------------------------------------------------------------------------
local trackedPieceProjectiles = {}
local pendingDeathUnitRadii = {}
local excludedDeathUnits = {}
local pieceGeneration = 0

-- Replay buffered off-screen piece frames retroactively.
-- Only replays the last few buffered positions (piece particles are short-lived,
-- so older entries would be dead on arrival anyway).
local function replayPieceBuffer(tracked, gameFrame)
	local buf = tracked.offscreenBuffer
	if not buf or #buf == 0 then
		tracked.offscreenBuffer = nil
		return
	end

	local preset = cachedPreset
	local sc = tracked.sizeScale
	local fi = tracked.fireIntensity
	local presetLifeMult = preset.lifetimeMult
	local smokeSizeSc = sc * (fi > 0 and 1.0 or 0.75)
	currentBudgetLimit = cachedBudgetNormal

	-- Only replay recent entries that could still produce alive particles
	-- Max possible lifetime: PIECE_LIFETIME_MAX * 2.0 (sizeRand factor) * presetLifeMult + 2 (deathFrame buffer)
	local maxReplayAge = mathCeil(PIECE_LIFETIME_MAX * 2 * presetLifeMult) + 2
	local startIdx = #buf
	for i = #buf, 1, -1 do
		if gameFrame - buf[i][1] > maxReplayAge then
			break
		end
		startIdx = i
	end

	local replayedCount = 0
	for i = startIdx, #buf do
		local entry = buf[i]
		local frame = entry[1]
		local bpx, bpy, bpz = entry[2], entry[3], entry[4]
		local bvx, bvy, bvz = entry[5], entry[6], entry[7]

		local pieceAge = frame - tracked.birthFrame
		local ageFrac = pieceAge / tracked.lifeFrames
		local vxs = bvx * PIECE_VEL_COMBINED
		local vys = bvy * PIECE_VEL_COMBINED
		local vzs = bvz * PIECE_VEL_COMBINED

		local smokeLifeBase = presetLifeMult
		local smokeAlphaBase = (1.0 - ageFrac * PIECE_ALPHA_FADE) * (fi > 0 and 1.0 or 0.6)
		local spawnCount = mathMax(1, mathFloor((PIECE_SPAWN_COUNT_MAX - ageFrac * PIECE_SPAWN_TAPER + 0.5) * preset.spawnMult * preset.pieceCountMult))

		for p = 1, spawnCount do
			if mathRandom() > PIECE_SKIP_CHANCE then
				local sizeRand = mathRandom() * PARTICLE_SIZE_RANGE
				local particleSize = (PARTICLE_SIZE_MIN + sizeRand) * smokeSizeSc
				spawnParticle(
					bpx + mathRandom() - 0.5,
					bpy + mathRandom(),
					bpz + mathRandom() - 0.5,
					vxs + (mathRandom() * SMOKE_VEL_RANDOM_2 - SMOKE_VEL_RANDOM),
					vys + mathRandom() * SMOKE_VEL_UP_RANGE + SMOKE_VEL_UP_MIN,
					vzs + (mathRandom() * SMOKE_VEL_RANDOM_2 - SMOKE_VEL_RANDOM),
					particleSize,
					0,
					(PIECE_LIFETIME_MIN + (tracked.lifeBias + mathRandom() * 0.3) * PIECE_LIFETIME_RANGE) * (1.0 + sizeRand * PARTICLE_SIZE_INV_RANGE) * smokeLifeBase,
					(PIECE_ALPHA_MIN + mathRandom() * PIECE_ALPHA_RANGE) * smokeAlphaBase,
					nil,
					frame -- birthFrame override
				)
				replayedCount = replayedCount + 1
			end
		end

		if fi > 0 then
			local sizeRand = mathRandom() * PARTICLE_SIZE_RANGE
			local particleSize = (PARTICLE_SIZE_MIN + sizeRand) * sc * FIRE_SIZE_MULT * fi
			spawnParticle(
				bpx + mathRandom() * 0.6 - 0.3,
				bpy + mathRandom() * 0.5,
				bpz + mathRandom() * 0.6 - 0.3,
				vxs + (mathRandom() * SMOKE_VEL_RANDOM_2 - SMOKE_VEL_RANDOM),
				vys + mathRandom() * SMOKE_VEL_UP_RANGE + SMOKE_VEL_UP_MIN,
				vzs + (mathRandom() * SMOKE_VEL_RANDOM_2 - SMOKE_VEL_RANDOM),
				particleSize,
				1,
				(FIRE_LIFETIME_MIN + mathRandom() * FIRE_LIFETIME_RANGE) * presetLifeMult * fi,
				(FIRE_ALPHA_MIN + mathRandom() * 0.2) * (0.5 + 0.5 * fi),
				nil,
				frame -- birthFrame override
			)
			replayedCount = replayedCount + 1
		end
	end

	tracked.offscreenBuffer = nil
	-- if debugEcho and replayedCount > 0 then
	-- 	spEcho(string.format("[FireSmoke] Replayed %d retroactive piece particles (%d buffered frames, started at %d/%d)", replayedCount, #buf, startIdx, #buf))
	-- end
end

local function spawnPieceTrailParticles(tracked, proID, gameFrame)
	local pieceAge = gameFrame - tracked.birthFrame
	if pieceAge > tracked.lifeFrames then
		return
	end

	local px, py, pz = spGetProjectilePosition(proID)
	if not px then
		return
	end

	local aboveGround = py > PIECE_GROUND_SKIP_HEIGHT
	if not aboveGround then
		local groundY = spGetGroundHeight(px, pz) or 0
		aboveGround = py > groundY + 1
	end
	if not aboveGround then
		return
	end

	local inView = spIsSphereInView(px, py, pz, PIECE_CULLING_RADIUS)
	if not inView then
		-- Buffer position/velocity every 3rd frame for retroactive spawning
		if not fastForward and gameFrame % 3 == 0 then
			local pvx, pvy, pvz = spGetProjectileVelocity(proID)
			local buf = tracked.offscreenBuffer
			if not buf then
				buf = {}
				tracked.offscreenBuffer = buf
			end
			buf[#buf + 1] = { gameFrame, px, py, pz, pvx or 0, pvy or 0, pvz or 0 }
		end
		return
	end

	-- Transition to in-view: replay buffered particles
	if tracked.offscreenBuffer then
		replayPieceBuffer(tracked, gameFrame)
	end

	local dx, dy, dz = px - cachedCamX, py - cachedCamY, pz - cachedCamZ
	local distSq = dx * dx + dy * dy + dz * dz
	local lodMult = 1.0
	if distSq > LOD_DIST_NEAR_SQ then
		local t = (mathSqrt(distSq) - LOD_DIST_NEAR) * LOD_DIST_RANGE_INV
		lodMult = t >= 1.0 and LOD_MIN_MULT or (1.0 - t * LOD_MULT_RANGE)
	end

	local pvx, pvy, pvz = spGetProjectileVelocity(proID)
	local vxs = pvx and pvx * PIECE_VEL_COMBINED or 0
	local vys = pvy and pvy * PIECE_VEL_COMBINED or 0
	local vzs = pvz and pvz * PIECE_VEL_COMBINED or 0

	local ageFrac = pieceAge / tracked.lifeFrames
	local sc = tracked.sizeScale
	local fi = tracked.fireIntensity

	local preset = cachedPreset
	local presetLifeMult = preset.lifetimeMult * lodMult
	local spawnCount = mathMax(1, mathFloor((PIECE_SPAWN_COUNT_MAX - ageFrac * PIECE_SPAWN_TAPER + 0.5) * preset.spawnMult * preset.pieceCountMult * lodMult))
	local skipChance = PIECE_SKIP_CHANCE + (1.0 - lodMult) * 0.3

	local smokeLifeBase = presetLifeMult
	local smokeAlphaBase = (1.0 - ageFrac * PIECE_ALPHA_FADE) * (fi > 0 and 1.0 or 0.6)
	local smokeSizeSc = sc * (fi > 0 and 1.0 or 0.75)

	-- Piece trails use NORMAL priority
	currentBudgetLimit = cachedBudgetNormal

	for p = 1, spawnCount do
		if mathRandom() > skipChance then
			local sizeRand = mathRandom() * PARTICLE_SIZE_RANGE
			local particleSize = (PARTICLE_SIZE_MIN + sizeRand) * smokeSizeSc
			local spx = px + mathRandom() - 0.5
			local spy = py + mathRandom()
			local spz = pz + mathRandom() - 0.5
			local svx = vxs + (mathRandom() * SMOKE_VEL_RANDOM_2 - SMOKE_VEL_RANDOM)
			local svy = vys + mathRandom() * SMOKE_VEL_UP_RANGE + SMOKE_VEL_UP_MIN
			local svz = vzs + (mathRandom() * SMOKE_VEL_RANDOM_2 - SMOKE_VEL_RANDOM)
			local smokeLife = (PIECE_LIFETIME_MIN + (tracked.lifeBias + mathRandom() * 0.3) * PIECE_LIFETIME_RANGE) * (1.0 + sizeRand * PARTICLE_SIZE_INV_RANGE) * smokeLifeBase
			local smokeAlpha = (PIECE_ALPHA_MIN + mathRandom() * PIECE_ALPHA_RANGE) * smokeAlphaBase
			spawnParticle(spx, spy, spz, svx, svy, svz, particleSize, 0, smokeLife, smokeAlpha)
		end
	end

	if fi > 0 then
		local sizeRand = mathRandom() * PARTICLE_SIZE_RANGE
		local particleSize = (PARTICLE_SIZE_MIN + sizeRand) * sc * FIRE_SIZE_MULT * fi
		spawnParticle(px + mathRandom() * 0.6 - 0.3, py + mathRandom() * 0.5, pz + mathRandom() * 0.6 - 0.3, vxs + (mathRandom() * SMOKE_VEL_RANDOM_2 - SMOKE_VEL_RANDOM), vys + mathRandom() * SMOKE_VEL_UP_RANGE + SMOKE_VEL_UP_MIN, vzs + (mathRandom() * SMOKE_VEL_RANDOM_2 - SMOKE_VEL_RANDOM), particleSize, 1, (FIRE_LIFETIME_MIN + mathRandom() * FIRE_LIFETIME_RANGE) * presetLifeMult * fi, (FIRE_ALPHA_MIN + mathRandom() * 0.2) * (0.5 + 0.5 * fi))
	end
end

local function updatePieceProjectiles(gameFrame)
	local projectiles = spGetProjectilesInRectangle(0, 0, mapSizeX, mapSizeZ, true, false)
	if not projectiles then
		return
	end

	local _, ownerRadius = next(pendingDeathUnitRadii)

	pieceGeneration = pieceGeneration + 1
	local gen = pieceGeneration
	local numProjectiles = #projectiles
	for i = 1, numProjectiles do
		local proID = projectiles[i]
		local tracked = trackedPieceProjectiles[proID]
		if not tracked then
			local ownerID = spGetProjectileOwnerID(proID)
			if ownerID and excludedDeathUnits[ownerID] then
				trackedPieceProjectiles[proID] = { gen = gen, excluded = true }
			else
				local px, py, pz = spGetProjectilePosition(proID)
				if px then
					local pieceRadius = ownerRadius or 10
					local sizeScale = mathMax(PIECE_SIZE_SCALE_MIN, mathMin(PIECE_SIZE_SCALE_MAX, pieceRadius / PIECE_SIZE_SCALE_REF))
					local fi = mathRandom() < PIECE_FIRE_CHANCE and (0.3 + mathRandom() * 0.7) or 0
					local lifeScale = fi > 0 and (1.0 + 0.3 * fi) or 0.7
					trackedPieceProjectiles[proID] = {
						sizeScale = sizeScale,
						birthFrame = gameFrame,
						lifeFrames = mathFloor((PIECE_LIFE_BASE + pieceRadius * PIECE_LIFE_PER_RADIUS) * lifeScale),
						gen = gen,
						fireIntensity = fi,
						lifeBias = mathRandom() * 0.7,
					}
				end
			end
		else
			tracked.gen = gen
			if not tracked.excluded then
				spawnPieceTrailParticles(tracked, proID, gameFrame)
			end
		end
	end

	for proID, tracked in pairs(trackedPieceProjectiles) do
		if tracked.gen ~= gen then
			trackedPieceProjectiles[proID] = nil
		end
	end
end

--------------------------------------------------------------------------------
-- Crashing aircraft tracking
--------------------------------------------------------------------------------
local trackedCrashingAircraft = {}
local crashingAircraftCount = 0

-- Aircraft data cache for crash trail scaling
local aircraftDataCache = {}
do
	for udid, ud in pairs(UnitDefs) do
		if ud.canFly then
			local radius = ud.radius or 20
			local xsize = ud.xsize or 2
			local zsize = ud.zsize or 2
			local footprint = mathMax(xsize, zsize) * 4
			radius = mathMax(radius, footprint * 0.5)

			local metalCost = ud.metalCost or 50
			local radiusFactor = radius / crashScale.RADIUS_REF
			local costFactor = metalCost / crashScale.COST_REF
			local rawScale = radiusFactor * crashScale.RADIUS_WEIGHT + costFactor * crashScale.COST_WEIGHT
			local unitScale = mathMax(crashScale.MIN, mathMin(crashScale.MAX, rawScale))

			aircraftDataCache[udid] = { radius = radius, unitScale = unitScale }
		end
	end
end

-- Replay buffered off-screen crash frames retroactively.
-- Since the vertex shader computes everything from birthFrame, particles pushed
-- retroactively render at the correct age/position/size/color immediately.
local function replayCrashBuffer(tracked, gameFrame)
	local buf = tracked.offscreenBuffer
	if not buf or #buf == 0 then
		return
	end

	local preset = cachedPreset
	local sc = tracked.sizeScale
	local fi = tracked.fireIntensity
	local unitLifeMult = tracked.lifetimeMult
	local unitSpawnMult = tracked.spawnMult

	local spawnCount = mathMax(1, mathFloor(CRASH_SPAWN_COUNT * preset.spawnMult * unitSpawnMult + 0.5))
	local presetLifeMult = preset.lifetimeMult
	local smokeSizeSc = sc * (fi > 0 and 1.0 or 0.75)
	currentBudgetLimit = cachedBudgetEssential

	local replayedCount = 0
	for i = 1, #buf do
		local entry = buf[i]
		local frame = entry[1]
		local bpx, bpy, bpz = entry[2], entry[3], entry[4]
		local bvx, bvy, bvz = entry[5], entry[6], entry[7]

		local crashAge = frame - tracked.birthFrame
		local ageFrac = crashAge / CRASH_MAX_DURATION
		local vxs = bvx * CRASH_VEL_INHERIT
		local vys = bvy * CRASH_VEL_INHERIT
		local vzs = bvz * CRASH_VEL_INHERIT

		local smokeLifeBase = presetLifeMult * unitLifeMult
		local smokeAlphaBase = (1.0 - ageFrac * CRASH_ALPHA_FADE) * (fi > 0 and 1.0 or 0.6)

		for p = 1, spawnCount do
			local sizeRand = mathRandom() * PARTICLE_SIZE_RANGE
			local particleSize = (PARTICLE_SIZE_MIN + sizeRand) * smokeSizeSc
			spawnParticle(
				bpx + mathRandom() * 4 - 2,
				bpy + mathRandom() * 2,
				bpz + mathRandom() * 4 - 2,
				vxs + (mathRandom() * SMOKE_VEL_RANDOM_2 - SMOKE_VEL_RANDOM),
				vys + mathRandom() * SMOKE_VEL_UP_RANGE + SMOKE_VEL_UP_MIN,
				vzs + (mathRandom() * SMOKE_VEL_RANDOM_2 - SMOKE_VEL_RANDOM),
				particleSize,
				0,
				(CRASH_LIFETIME_MIN + mathRandom() * CRASH_LIFETIME_RANGE) * (1.0 + sizeRand * PARTICLE_SIZE_INV_RANGE) * smokeLifeBase,
				(CRASH_ALPHA_MIN + mathRandom() * CRASH_ALPHA_RANGE) * smokeAlphaBase,
				nil,
				frame -- birthFrame override
			)
			replayedCount = replayedCount + 1
		end

		if fi > 0 then
			local sizeRand = mathRandom() * PARTICLE_SIZE_RANGE
			local particleSize = (PARTICLE_SIZE_MIN + sizeRand) * sc * FIRE_SIZE_MULT * CRASH_FIRE_SIZE_MULT * fi
			spawnParticle(
				bpx + mathRandom() * 2 - 1,
				bpy + mathRandom(),
				bpz + mathRandom() * 2 - 1,
				vxs + (mathRandom() * SMOKE_VEL_RANDOM_2 - SMOKE_VEL_RANDOM),
				vys + mathRandom() * SMOKE_VEL_UP_RANGE + SMOKE_VEL_UP_MIN,
				vzs + (mathRandom() * SMOKE_VEL_RANDOM_2 - SMOKE_VEL_RANDOM),
				particleSize,
				1,
				(FIRE_LIFETIME_MIN + mathRandom() * FIRE_LIFETIME_RANGE) * presetLifeMult * CRASH_FIRE_LIFETIME_MULT * fi * unitLifeMult,
				(FIRE_ALPHA_MIN + mathRandom() * 0.2) * (0.5 + 0.5 * fi),
				nil,
				frame -- birthFrame override
			)
			replayedCount = replayedCount + 1
		end
	end

	tracked.offscreenBuffer = nil
	-- if debugEcho and replayedCount > 0 then
	-- 	spEcho(string.format("[FireSmoke] Replayed %d retroactive crash particles (%d buffered frames)", replayedCount, #buf))
	-- end
end

local function spawnCrashTrailParticles(tracked, unitID, gameFrame)
	local crashAge = gameFrame - tracked.birthFrame
	if crashAge > CRASH_MAX_DURATION then
		return
	end

	local px, py, pz = spGetUnitPosition(unitID)
	if not px then
		return
	end

	local inView = spIsSphereInView(px, py, pz, CRASH_CULLING_TOTAL)
	if not inView then
		-- Buffer position/velocity for retroactive spawning when coming into view
		if not fastForward then
			local uvx, uvy, uvz = spGetUnitVelocity(unitID)
			local buf = tracked.offscreenBuffer
			if not buf then
				buf = {}
				tracked.offscreenBuffer = buf
			end
			buf[#buf + 1] = { gameFrame, px, py, pz, uvx or 0, uvy or 0, uvz or 0 }
		end
		return
	end

	-- Transition to in-view: replay buffered particles with low preset
	if tracked.offscreenBuffer then
		replayCrashBuffer(tracked, gameFrame)
	end

	local dx, dy, dz = px - cachedCamX, py - cachedCamY, pz - cachedCamZ
	local distSq = dx * dx + dy * dy + dz * dz
	local lodMult = 1.0
	if distSq > CRASH_LOD_DIST_NEAR_SQ then
		local t = (mathSqrt(distSq) - CRASH_LOD_DIST_NEAR) * CRASH_LOD_DIST_RANGE_INV
		lodMult = t >= 1.0 and CRASH_LOD_MIN_MULT or (1.0 - t * CRASH_LOD_MULT_RANGE)
	end

	local vxs, vys, vzs = 0, 0, 0
	local uvx, uvy, uvz = spGetUnitVelocity(unitID)
	if uvx then
		vxs, vys, vzs = uvx * CRASH_VEL_INHERIT, uvy * CRASH_VEL_INHERIT, uvz * CRASH_VEL_INHERIT
	end

	local ageFrac = crashAge / CRASH_MAX_DURATION
	local sc = tracked.sizeScale
	local fi = tracked.fireIntensity
	local unitLifeMult = tracked.lifetimeMult
	local unitSpawnMult = tracked.spawnMult

	local preset = cachedPreset
	local presetLifeMult = preset.lifetimeMult * lodMult
	local spawnCount = mathMax(1, mathFloor(CRASH_SPAWN_COUNT * preset.spawnMult * lodMult * unitSpawnMult + 0.5))
	local skipChance = CRASH_SKIP_CHANCE + (1.0 - lodMult) * 0.3

	local smokeLifeBase = presetLifeMult * unitLifeMult
	local smokeAlphaBase = (1.0 - ageFrac * CRASH_ALPHA_FADE) * (fi > 0 and 1.0 or 0.6)
	local smokeSizeSc = sc * (fi > 0 and 1.0 or 0.75)

	-- Crash trails use ESSENTIAL priority
	currentBudgetLimit = cachedBudgetEssential

	for p = 1, spawnCount do
		if mathRandom() > skipChance then
			local sizeRand = mathRandom() * PARTICLE_SIZE_RANGE
			local particleSize = (PARTICLE_SIZE_MIN + sizeRand) * smokeSizeSc
			local spx = px + mathRandom() * 4 - 2
			local spy = py + mathRandom() * 2
			local spz = pz + mathRandom() * 4 - 2
			local svx = vxs + (mathRandom() * SMOKE_VEL_RANDOM_2 - SMOKE_VEL_RANDOM)
			local svy = vys + mathRandom() * SMOKE_VEL_UP_RANGE + SMOKE_VEL_UP_MIN
			local svz = vzs + (mathRandom() * SMOKE_VEL_RANDOM_2 - SMOKE_VEL_RANDOM)
			local smokeLife = (CRASH_LIFETIME_MIN + mathRandom() * CRASH_LIFETIME_RANGE) * (1.0 + sizeRand * PARTICLE_SIZE_INV_RANGE) * smokeLifeBase
			local smokeAlpha = (CRASH_ALPHA_MIN + mathRandom() * CRASH_ALPHA_RANGE) * smokeAlphaBase
			spawnParticle(spx, spy, spz, svx, svy, svz, particleSize, 0, smokeLife, smokeAlpha)
		end
	end

	if fi > 0 then
		local sizeRand = mathRandom() * PARTICLE_SIZE_RANGE
		local particleSize = (PARTICLE_SIZE_MIN + sizeRand) * sc * FIRE_SIZE_MULT * CRASH_FIRE_SIZE_MULT * fi
		spawnParticle(px + mathRandom() * 2 - 1, py + mathRandom(), pz + mathRandom() * 2 - 1, vxs + (mathRandom() * SMOKE_VEL_RANDOM_2 - SMOKE_VEL_RANDOM), vys + mathRandom() * SMOKE_VEL_UP_RANGE + SMOKE_VEL_UP_MIN, vzs + (mathRandom() * SMOKE_VEL_RANDOM_2 - SMOKE_VEL_RANDOM), particleSize, 1, (FIRE_LIFETIME_MIN + mathRandom() * FIRE_LIFETIME_RANGE) * presetLifeMult * CRASH_FIRE_LIFETIME_MULT * fi * unitLifeMult, (FIRE_ALPHA_MIN + mathRandom() * 0.2) * (0.5 + 0.5 * fi))
	end
end

local function updateCrashingAircraft(gameFrame)
	if crashingAircraftCount == 0 then
		return
	end

	for unitID, tracked in pairs(trackedCrashingAircraft) do
		if not spValidUnitID(unitID) then
			trackedCrashingAircraft[unitID] = nil
			crashingAircraftCount = crashingAircraftCount - 1
		elseif gameFrame - tracked.birthFrame > CRASH_MAX_DURATION then
			trackedCrashingAircraft[unitID] = nil
			crashingAircraftCount = crashingAircraftCount - 1
		else
			spawnCrashTrailParticles(tracked, unitID, gameFrame)
		end
	end
end

--------------------------------------------------------------------------------
-- Public API (GG.FireSmoke)
-- Other gadgets can call these to spawn fire/smoke effects
--------------------------------------------------------------------------------

local function apiCrashingAircraft(unitID, unitDefID, teamID)
	if not particleVBO then
		return
	end
	if trackedCrashingAircraft[unitID] then
		return
	end

	local data = aircraftDataCache[unitDefID]
	local unitScale = data and data.unitScale or 1.0

	local sizeScale = unitScale ^ crashScale.SIZE_EXP
	local lifetimeMult = unitScale ^ crashScale.LIFE_EXP
	local spawnMult = unitScale ^ crashScale.SPAWN_EXP

	local fireChance = mathMin(1.0, crashScale.FIRE_CHANCE * (0.5 + 0.5 * unitScale))
	local fi = mathRandom() < fireChance and (crashScale.FIRE_INT_MIN + mathRandom() * (1.0 - crashScale.FIRE_INT_MIN)) * mathMin(1.0, 0.6 + 0.4 * unitScale) or 0

	trackedCrashingAircraft[unitID] = {
		sizeScale = sizeScale,
		birthFrame = cachedGameFrame,
		fireIntensity = fi,
		lifetimeMult = lifetimeMult,
		spawnMult = spawnMult,
	}
	crashingAircraftCount = crashingAircraftCount + 1
end

-- Add a generic point emitter at a fixed position.
-- Returns emitterID (use to remove later) or nil if VBO not ready.
--
-- params table fields (all optional except x,y,z):
--   x, y, z            - world position (required)
--   duration            - emit for this many frames, 0 = permanent (default: 300)
--   sizeScale           - particle size multiplier (default: 1.0)
--   fireIntensity       - 0 = smoke only, 0-1 = fire chance/brightness (default: 0)
--   spawnCount          - smoke particles per interval (default: POINT_SPAWN_COUNT)
--   spawnInterval       - frames between spawns (default: POINT_SPAWN_INTERVAL)
--   priority            - PRIORITY_ESSENTIAL/NORMAL/COSMETIC (default: NORMAL)
--   smokeSizeMult       - multiplier on smoke particle size (default: 1.0)
--   smokeLifeMult       - multiplier on smoke lifetime (default: 1.0)
--   smokeAlpha          - base smoke alpha (default: 1.0)
--   fireSizeMult        - multiplier on fire particle size (default: 1.0)
--   fireLifeMult        - multiplier on fire particle lifetime (default: 1.0)
--   posSpread           - random position offset radius in elmos (default: POINT_POS_SPREAD)
--   velocityScale       - multiplier on particle velocity (default: 1.0)
local function apiAddPointEmitter(params)
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

-- Remove a point emitter by ID (returned from AddPointEmitter)
local function apiRemoveEmitter(emitterID)
	if emitterID and pointEmitters[emitterID] then
		pointEmitters[emitterID] = nil
		pointEmitterCount = pointEmitterCount - 1
		return true
	end
	return false
end

-- Update emitter position (for moving sources)
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

-- Spawn a single particle directly (one-shot, no emitter tracking)
-- priority: PRIORITY_ESSENTIAL/NORMAL/COSMETIC (default: NORMAL)
local function apiSpawnParticle(px, py, pz, vx, vy, vz, size, isFireType, lifetime, alpha, priority)
	if not particleVBO then
		return
	end
	currentBudgetLimit = budgetLimits[priority or PRIORITY_NORMAL]
	spawnParticle(px, py, pz, vx or 0, vy or 0, vz or 0, size or 2, isFireType and 1 or 0, lifetime or 60, alpha or 1.0)
end

-- Query current state
local function apiGetParticleCount()
	return particleVBO and particleVBO.usedElements or 0
end

local function apiGetMaxParticles()
	return MAX_PARTICLES
end

local function apiGetWindState()
	return windX, windZ, windStrength
end

--------------------------------------------------------------------------------
-- Gadget callins
--------------------------------------------------------------------------------

function gadget:Initialize()
	if not gl.CreateShader then
		goodbye("OpenGL shaders not supported")
		return
	end

	buildUnitDeathSizeCache()

	if not initGL4() then
		return
	end

	-- Expose public API for other gadgets
	GG.FireSmoke = {
		-- Emitter management
		AddPointEmitter = apiAddPointEmitter,
		RemoveEmitter = apiRemoveEmitter,
		UpdateEmitterPos = apiUpdateEmitterPos,

		-- Direct particle spawn
		SpawnParticle = apiSpawnParticle,

		-- Crashing aircraft integration (called from unit_crashing_aircraft.lua)
		CrashingAircraft = apiCrashingAircraft,

		-- Query
		GetParticleCount = apiGetParticleCount,
		GetMaxParticles = apiGetMaxParticles,
		GetWindState = apiGetWindState,

		-- Priority constants (for callers to reference)
		PRIORITY_ESSENTIAL = PRIORITY_ESSENTIAL,
		PRIORITY_NORMAL = PRIORITY_NORMAL,
		PRIORITY_COSMETIC = PRIORITY_COSMETIC,
	}
end

function gadget:Shutdown()
	cleanupGL4()
	GG.FireSmoke = nil
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	if not particleVBO then
		return
	end

	-- Stop tracking crashing aircraft on death
	if trackedCrashingAircraft[unitID] then
		trackedCrashingAircraft[unitID] = nil
		crashingAircraftCount = crashingAircraftCount - 1
	end

	local radius = unitDeathSizeCache[unitDefID]
	if radius then
		pendingDeathUnitRadii[unitID] = radius
	else
		excludedDeathUnits[unitID] = true
	end
end

function gadget:GameFrame(n)
	if not particleVBO then
		return
	end

	local t0, t1, tStart -- debug timer locals (only used when debugEcho is true)
	if debugEcho then
		tStart = spGetTimer()
		t0 = tStart
	end

	cachedGameFrame = n
	cachedCamX, cachedCamY, cachedCamZ = spGetCameraPosition()

	-- Detect fast-forward: actual sim speed > 1.5 means catching up or user speed-up
	local userSpeed, internalSpeed = spGetGameSpeed()
	fastForward = (internalSpeed or userSpeed) > 1.5

	-- Periodic housekeeping (staggered across frames)
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

	-- Override to Low preset during fast-forward; restore from currentPreset otherwise
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

	-- Determine update interval based on load
	local updateInterval = 1
	if avgParticleCount > MAX_PARTICLES * 0.8 then
		updateInterval = 3
	elseif avgParticleCount > MAX_PARTICLES * 0.4 then
		updateInterval = 2
	end
	-- FPS-based throttling (refresh cached value every 15 frames)
	if n % 15 == 0 then
		local fps = spGetFPS()
		if fps > 0 then
			cachedFpsInterval = mathCeil(30 / fps)
		end
	end
	if cachedFpsInterval > updateInterval then
		updateInterval = cachedFpsInterval
	end

	if n % updateInterval == 0 then
		updatePieceProjectiles(n)

		if debugEcho then
			t1 = spGetTimer()
			debugTimings.pieceProjectiles = debugTimings.pieceProjectiles + spDiffTimers(t1, t0, true)
			t0 = t1
		end

		updateCrashingAircraft(n)

		if debugEcho then
			t1 = spGetTimer()
			debugTimings.crashingAircraft = debugTimings.crashingAircraft + spDiffTimers(t1, t0, true)
			t0 = t1
		end

		updatePointEmitters(n)

		if debugEcho then
			t1 = spGetTimer()
			debugTimings.pointEmitters = debugTimings.pointEmitters + spDiffTimers(t1, t0, true)
			t0 = t1
		end
	end

	-- Clean up pending death data periodically
	if nMod == 30 then
		local k = next(pendingDeathUnitRadii)
		if k then
			for uid in pairs(pendingDeathUnitRadii) do
				pendingDeathUnitRadii[uid] = nil
			end
		end
		k = next(excludedDeathUnits)
		if k then
			for uid in pairs(excludedDeathUnits) do
				excludedDeathUnits[uid] = nil
			end
		end
	end

	if debugEcho then
		t1 = spGetTimer()
		debugTimings.cleanup = debugTimings.cleanup + spDiffTimers(t1, t0, true)
		debugTimings.totalFrame = debugTimings.totalFrame + spDiffTimers(t1, tStart, true)
		debugTimingSamples = debugTimingSamples + 1

		if n % 30 == 0 and debugTimingSamples > 0 then
			local inv = 1000 / debugTimingSamples -- convert to microseconds per frame
			local trackedPieceCount = 0
			for _ in pairs(trackedPieceProjectiles) do
				trackedPieceCount = trackedPieceCount + 1
			end
			spEcho(string.format("Fire Smoke GL4 timing (us/frame avg over %d frames): TOTAL=%.1f  housekeep=%.1f  quality=%.1f  removeExp=%.1f  pieces=%.1f  crash=%.1f  pointEm=%.1f  cleanup=%.1f  | particles=%d  pieces=%d  crashes=%d  emitters=%d  preset=%s  wind=%d", debugTimingSamples, debugTimings.totalFrame * inv, debugTimings.housekeeping * inv, debugTimings.qualityPreset * inv, debugTimings.removeExpired * inv, debugTimings.pieceProjectiles * inv, debugTimings.crashingAircraft * inv, debugTimings.pointEmitters * inv, debugTimings.cleanup * inv, mathFloor(avgParticleCount), trackedPieceCount, crashingAircraftCount, pointEmitterCount, cachedPreset.name, mathFloor(windStrength)))
			-- Reset accumulators
			for k in pairs(debugTimings) do
				debugTimings[k] = 0
			end
			debugTimingSamples = 0
		end
	end
end

function gadget:DrawWorld()
	-- Flush off-screen crash buffers that are now in view (works while paused too)
	if crashingAircraftCount > 0 then
		for unitID, tracked in pairs(trackedCrashingAircraft) do
			if tracked.offscreenBuffer then
				local px, py, pz = spGetUnitPosition(unitID)
				if px and spIsSphereInView(px, py, pz, CRASH_CULLING_TOTAL) then
					replayCrashBuffer(tracked, cachedGameFrame)
				end
			end
		end
	end

	-- Flush off-screen piece buffers that are now in view (works while paused too)
	for proID, tracked in pairs(trackedPieceProjectiles) do
		if tracked.offscreenBuffer then
			local px, py, pz = spGetProjectilePosition(proID)
			if px and spIsSphereInView(px, py, pz, PIECE_CULLING_RADIUS) then
				replayPieceBuffer(tracked, cachedGameFrame)
			end
		end
	end

	DrawParticles()
end
