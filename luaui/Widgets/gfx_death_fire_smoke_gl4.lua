--------------------------------------------------------------------------------
-- GPU-based fire & smoke particle system for unit death effects and crashing aircraft
-- Replaces CPU-based CEG pieceexplosiongenerators with instanced GL4 rendering
--------------------------------------------------------------------------------
local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Death Fire & Smoke GL4",
		desc = "Fire and smoke particles for unit death pieces and crashing aircraft",
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
local spGetGroundHeight   = Spring.GetGroundHeight
local spEcho              = Spring.Echo
local spGetProjectilesInRectangle = Spring.GetProjectilesInRectangle
local spGetProjectilePosition = Spring.GetProjectilePosition
local spGetProjectileVelocity = Spring.GetProjectileVelocity
local spIsSphereInView        = Spring.IsSphereInView
local spGetCameraPosition     = Spring.GetCameraPosition
local spGetProjectileOwnerID  = Spring.GetProjectileOwnerID
local spGetFPS                = Spring.GetFPS
local spGetUnitPosition       = Spring.GetUnitPosition
local spGetUnitVelocity       = Spring.GetUnitVelocity
local spValidUnitID           = Spring.ValidUnitID

local mapSizeX = Game.mapSizeX
local mapSizeZ = Game.mapSizeZ

local glBlending  = gl.Blending
local glTexture   = gl.Texture
local glDepthTest = gl.DepthTest
local glDepthMask = gl.DepthMask
local glCulling   = gl.Culling

local GL_ONE                  = GL.ONE
local GL_ONE_MINUS_SRC_ALPHA  = GL.ONE_MINUS_SRC_ALPHA
local GL_SRC_ALPHA            = GL.SRC_ALPHA

local mathRandom = math.random
local mathMin    = math.min
local mathMax    = math.max
local mathFloor  = math.floor
local mathCeil   = math.ceil
local mathSqrt   = math.sqrt
local mathPi     = math.pi

local LuaShader = gl.LuaShader
local pushElementInstance  = gl.InstanceVBOTable.pushElementInstance
local popElementInstance   = gl.InstanceVBOTable.popElementInstance

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------


-- Textures
local fireTexture  = "bitmaps/projectiletextures/BARFlame02.tga"
local smokeTexture = "bitmaps/projectiletextures/smoke-beh-anim.tga"

-- General
local MAX_PARTICLES          = 128000	-- tested 100k particles 96->90 fps on RTX 5080 at 5K resolution (~1000 fighters clashing)
local PARTICLE_SHADER_NAME   = "DeathFireSmokeGL4"
local PARTICLE_SIZE_MIN      = 1
local PARTICLE_SIZE_MAX      = 4

-- Shared smoke physics (used by both piece debris and crashing aircraft trails)
local SMOKE_LIFETIME_MULT      = 1   -- general lifetime multiplier for smoke particles
local SMOKE_VEL_UP_MIN         = 0.04  -- minimum upward velocity for smoke
local SMOKE_VEL_UP_MAX         = 0.20  -- maximum upward velocity
local SMOKE_VEL_RANDOM         = 0.1   -- random velocity offset per axis
local SMOKE_GROWTH_MULT        = 1.05   -- growth over lifetime: final size = base * (1 + curve * this). 1.5 gives 1x->4x
local SMOKE_GROWTH_RATE        = 0.11  -- time-based growth per frame (elmos), decoupled from lifetime
local SMOKE_WOBBLE_START       = 1  -- initial turbulence amplitude (elmos)
local SMOKE_WOBBLE_RAMP        = 0.5  -- additional amplitude over lifetime (ramps to start + ramp)
local SMOKE_WOBBLE_RATE        = 0.11  -- time-based wobble growth per frame (elmos), decoupled from lifetime

-- Smoke highlight: lighter particle layered above each smoke particle (sunlit top)
local SMOKE_HIGHLIGHT_ENABLED  = true  -- spawn a lighter highlight particle on top of each smoke
local SMOKE_HIGHLIGHT_OFFSET_Y = 2.2   -- vertical offset above base smoke (elmos)
local SMOKE_HIGHLIGHT_BRIGHT   = 2.8   -- brightness multiplier for highlight (via colorTint.rgb)
local SMOKE_HIGHLIGHT_SIZE     = 0.85  -- size relative to base smoke particle
local SMOKE_HIGHLIGHT_ALPHA    = 1   -- alpha relative to base smoke particle
local SMOKE_HIGHLIGHT_LIFE     = 0.7  -- lifetime relative to base smoke particle

-- Frustum culling margin (elmos beyond visible sphere to still spawn)
local CULLING_MARGIN           = 350  -- extra radius for view check

-- Fire particle settings (shared base, each trail type can scale)
local FIRE_LIFETIME_MIN        = 33   -- min fire particle lifetime in frames
local FIRE_LIFETIME_RANGE      = 33   -- fire lifetime variation
local FIRE_SIZE_MULT           = 2  -- fire particles are smaller than smoke
local FIRE_ALPHA_MIN           = 0.8  -- fire particles are brighter

-- Piece projectile trails (fire on flying debris)
local PIECE_SPAWN_INTERVAL     = 1    -- frames between piece spawns
local PIECE_SPAWN_COUNT_MAX    = 3    -- max particles spawned per piece per interval (early life)
local PIECE_SPAWN_TAPER        = 2  -- how fast spawn count reduces with piece age
local PIECE_SKIP_CHANCE        = 0.33  -- chance to skip spawning a particle (visual variety)
local PIECE_VEL_SCALE          = 6.0  -- velocity inheritance multiplier (after 0.05 pre-scale)
local PIECE_LIFETIME_MIN       = 45   -- min smoke particle lifetime in frames
local PIECE_LIFETIME_MAX       = 95  -- max smoke particle lifetime in frames
local PIECE_SIZE_SCALE_MIN     = 0.25  -- min size multiplier for piece particles
local PIECE_SIZE_SCALE_MAX     = 0.7  -- max size multiplier
local PIECE_SIZE_SCALE_REF     = 25.0 -- reference radius for piece size scaling
local PIECE_LIFE_BASE          = 200   -- base piece emitter lifetime in frames
local PIECE_LIFE_PER_RADIUS    = 1.5  -- extra frames per unit radius
local PIECE_ALPHA_FADE         = 0.66  -- alpha reduction over piece age
local PIECE_ALPHA_MIN          = 0.25  -- min random alpha
local PIECE_GROUND_SKIP_HEIGHT = 5    -- skip ground check above this height
local PIECE_FIRE_CHANCE        = 0.25  -- per-emitter chance of fire for pieces

-- Distance LOD: reduce spawn count when camera is far away (piece trails)
local LOD_DIST_NEAR            = 4000   -- full detail within this range
local LOD_DIST_FAR             = 10000  -- minimum detail beyond this range
local LOD_MIN_MULT             = 0.33  -- spawn multiplier at max distance
local LOD_DIST_RANGE_INV       = 1.0 / (LOD_DIST_FAR - LOD_DIST_NEAR)
local LOD_MULT_RANGE           = 1.0 - LOD_MIN_MULT
local LOD_DIST_NEAR_SQ         = LOD_DIST_NEAR * LOD_DIST_NEAR

-- Crashing aircraft trails (larger, longer, denser than piece trails)
local CRASH_SPAWN_INTERVAL     = 1     -- frames between spawns
local CRASH_SPAWN_COUNT        = 3     -- smoke particles per spawn interval
local CRASH_SIZE_MULT          = 1   -- particle size multiplier vs base PARTICLE_SIZE
local CRASH_LIFETIME_MULT      = 1   -- smoke particle lifetime multiplier (on top of SMOKE_LIFETIME_MULT)
local CRASH_VEL_INHERIT        = 0.6  -- fraction of aircraft velocity inherited by smoke
local CRASH_ALPHA_FADE         = 0.66   -- alpha reduction over crash trail age
local CRASH_ALPHA_MIN          = 0.25   -- minimum smoke alpha
local CRASH_SKIP_CHANCE        = 0.05  -- lower skip = denser trail
local CRASH_FIRE_CHANCE        = 0.6   -- per-emitter chance to have fire (crashes burn more)
local CRASH_FIRE_INTENSITY_MIN = 0.66   -- minimum fire intensity when fire is present
local CRASH_FIRE_LIFETIME_MULT = 1.4   -- fire lifetime multiplier
local CRASH_FIRE_SIZE_MULT     = 1.3   -- fire size multiplier (relative to FIRE_SIZE_MULT)
local CRASH_CULLING_RADIUS     = 200   -- view culling radius for aircraft
local CRASH_ALWAYS_EMIT        = true  -- emit crash trail particles even when off-screen
local CRASH_MAX_DURATION       = 450   -- max frames to track (matches crashing_aircraft gadget)
local CRASH_LIFETIME_MIN       = 120    -- min smoke particle lifetime in frames
local CRASH_LIFETIME_RANGE     = 90    -- smoke lifetime variation range

-- Unit-based crash trail scaling: bigger/costlier units produce bigger, longer, denser trails
local CRASH_SCALE_RADIUS_REF   = 30    -- reference radius for scale=1.0
local CRASH_SCALE_COST_REF     = 250   -- reference metal cost for scale=1.0
local CRASH_SCALE_RADIUS_WEIGHT= 0.4   -- how much radius contributes to unit scale
local CRASH_SCALE_COST_WEIGHT  = 0.7   -- how much metal cost contributes to unit scale
local CRASH_SCALE_MIN          = 0.75   -- minimum unit scale (small scouts)
local CRASH_SCALE_MAX          = 1.25   -- maximum unit scale (heavy bombers)
local CRASH_SCALE_SIZE_EXP     = 0.8   -- exponent for size scaling (< 1 = diminishing returns)
local CRASH_SCALE_LIFE_EXP     = 0.5   -- exponent for lifetime scaling
local CRASH_SCALE_SPAWN_EXP    = 0.6   -- exponent for spawn count scaling

-- Distance LOD for crashing aircraft (stays visible longer since trails are larger)
local CRASH_LOD_DIST_NEAR      = 6000   -- full detail within this range
local CRASH_LOD_DIST_FAR       = 15000   -- minimum detail beyond this range
local CRASH_LOD_MIN_MULT       = 0.45   -- higher minimum = stays denser at distance
local CRASH_LOD_DIST_RANGE_INV = 1.0 / (CRASH_LOD_DIST_FAR - CRASH_LOD_DIST_NEAR)
local CRASH_LOD_MULT_RANGE     = 1.0 - CRASH_LOD_MIN_MULT
local CRASH_LOD_DIST_NEAR_SQ   = CRASH_LOD_DIST_NEAR * CRASH_LOD_DIST_NEAR

-- Pre-computed constants (avoid repeated arithmetic in hot loops)
local SMOKE_VEL_UP_RANGE       = SMOKE_VEL_UP_MAX - SMOKE_VEL_UP_MIN
local SMOKE_VEL_RANDOM_2       = SMOKE_VEL_RANDOM * 2
local PIECE_VEL_COMBINED       = PIECE_VEL_SCALE * 0.05  -- velocity inheritance * engine pre-scale combined
local PARTICLE_SIZE_RANGE      = PARTICLE_SIZE_MAX - PARTICLE_SIZE_MIN
local PIECE_ALPHA_RANGE        = 1.0 - PIECE_ALPHA_MIN
local PIECE_LIFETIME_RANGE     = PIECE_LIFETIME_MAX - PIECE_LIFETIME_MIN
local PARTICLE_SIZE_INV_RANGE  = 1.0 / PARTICLE_SIZE_RANGE  -- for normalizing size to 0..1
local CRASH_ALPHA_RANGE        = 1.0 - CRASH_ALPHA_MIN
local CRASH_CULLING_TOTAL      = CRASH_CULLING_RADIUS + CULLING_MARGIN

-- Quality presets: auto-switch based on average particle count over 0.5 seconds
-- Each preset is active while avg particles < maxPct * MAX_PARTICLES.
-- Higher key = higher quality. The system picks the highest preset whose maxPct isn't exceeded.
local QUALITY_PRESETS = {
	[1] = {
		name            = "Low",
		spawnMult       = 0.35,
		pieceCountMult  = 0.5,
		lifetimeMult    = 0.2,
		maxPct          = 1.0,   -- percentage of MAX_PARTICLES when to switch to lower preset
	},
	[2] = {
		name            = "Medium",
		spawnMult       = 0.65,
		pieceCountMult  = 0.75,
		lifetimeMult    = 0.3,
		maxPct          = 0.66,   -- percentage of MAX_PARTICLES when to switch to lower preset
	},
	[3] = {
		name            = "High",
		spawnMult       = 1.0,
		pieceCountMult  = 1.0,
		lifetimeMult    = 0.4,
		maxPct          = 0.33,   -- percentage of MAX_PARTICLES when to switch to lower preset
	},
}
local AVG_WINDOW_FRAMES        = 15   -- 0.5 seconds at 30fps
local AVG_SAMPLE_INTERVAL      = 4    -- sample every N frames


--------------------------------------------------------------------------------
-- Shader sources
--------------------------------------------------------------------------------

-- Vertex shader: each instance is one particle
-- We animate position and appearance entirely on GPU based on birth time + params
local vsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 10000

//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

// Per-vertex quad data (billboard corners)
layout (location = 0) in vec4 position_xy_uv;

// Per-instance particle data
layout (location = 1) in vec4 worldPos;        // xyz = spawn position, w = birthFrame
layout (location = 2) in vec4 velocity;        // xyz = initial velocity, w = lifetime (frames)
layout (location = 3) in vec4 sizeAndType;     // x = baseSize, y = unused, z = randomSeed, w = rotation
layout (location = 4) in vec4 colorTint;       // rgb = faction/variant tint, a = alpha multiplier

out DataVS {
	vec2 texCoords;
	vec4 particleColor;
	float animFrame;
	float rowVariant;
	flat float isFireParticle; // 0.0 = smoke, 1.0 = fire
};

void main()
{
	float currentFrame = timeInfo.x + timeInfo.w;
	float ageFrames = currentFrame - worldPos.w;
	float lifetime = velocity.w;
	float normalizedAge = clamp(ageFrames / lifetime, 0.0, 1.0);

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

	// Animate position: apply velocity with airdrag (0.85 like deathceg)
	// exp(ageFrames * ln(0.85)) is cheaper than pow(0.85, ageFrames)
	float dragPow = exp(ageFrames * -0.16252);  // ln(0.85) = -0.16252
	float dragFactor = (1.0 - dragPow) * 6.6667;  // 1/(1-0.85) = 6.6667

	vec3 pos = worldPos.xyz;
	pos += velocity.xyz * dragFactor;

	// Gentle buoyancy
	pos.y += 0.004 * ageFrames * ageFrames;

	// Size: lifetime-based growth + time-based growth (decoupled)
	float baseSize = sizeAndType.x;

	// Turbulence: grows with age so particles wobble more over time
	float seedPhase = seed * 6.283;
	float wobble = SMOKE_WOBBLE_START + normalizedAge * SMOKE_WOBBLE_RAMP * baseSize + ageFrames * SMOKE_WOBBLE_RATE;
	pos.x += sin(ageFrames * 0.07 + seedPhase * 2.7) * wobble;
	pos.z += cos(ageFrames * 0.09 + seedPhase * 3.8) * wobble;
	pos.y += sin(ageFrames * 0.05 + seedPhase * 1.8) * wobble * 0.25;

	float growCurve = normalizedAge * (1.0 + normalizedAge);  // accelerating: 0 -> 2.0
	float lifetimeGrowth = baseSize * (1.0 + growCurve * SMOKE_GROWTH_MULT);
	float timeGrowth = ageFrames * SMOKE_GROWTH_RATE;  // constant rate, independent of lifetime
	float sizeGrowth = lifetimeGrowth + timeGrowth;

	// Billboard: camera right/up from inverse view matrix (already orthonormal)
	vec3 camRight = cameraViewInv[0].xyz;
	vec3 camUp    = cameraViewInv[1].xyz;

	// Apply rotation (subtle spin over lifetime)
	float rotSpeed = (seed - 0.5) * 0.6;  // -0.3 to +0.3 radians over full life
	float rot = sizeAndType.w + normalizedAge * rotSpeed;
	float cr = cos(rot);
	float sr = sin(rot);
	vec3 rotRight = camRight * cr + camUp * sr;
	vec3 rotUp    = -camRight * sr + camUp * cr;

	vec3 vertexOffset = (rotRight * position_xy_uv.x + rotUp * position_xy_uv.y) * sizeGrowth;
	vec4 worldPosition = vec4(pos + vertexOffset, 1.0);

	gl_Position = cameraViewProj * worldPosition;

	// Texture coordinates
	texCoords = position_xy_uv.zw;

	// sizeAndType.y encodes particle type: 0 = smoke, 1 = fire
	isFireParticle = step(0.5, sizeAndType.y);
	int cmapVariant = int(isFireParticle);

	// 2 colormaps: 0 = smoke (dark -> grey -> transparent), 1 = fire (orange -> black -> transparent)
	const vec4 cmaps[16] = vec4[16](
		// Variant 0: smoke (wider brightness range, more grey in mid-life)
		vec4(0.10, 0.10, 0.10, 0.75),
		vec4(0.16, 0.16, 0.16, 0.7),
		vec4(0.22, 0.22, 0.22, 0.65),
		vec4(0.28, 0.27, 0.26, 0.55),
		vec4(0.30, 0.29, 0.28, 0.42),
		vec4(0.25, 0.24, 0.23, 0.28),
		vec4(0.18, 0.17, 0.17, 0.14),
		vec4(0.10, 0.10, 0.10, 0.01),
		// Variant 1: fire (orange -> black)
		vec4(1.0, 0.7, 0.15, 1.0),
		vec4(0.9, 0.55, 0.1, 0.9),
		vec4(0.65, 0.33, 0.07, 0.75),
		vec4(0.4, 0.17, 0.04, 0.55),
		vec4(0.2, 0.09, 0.02, 0.35),
		vec4(0.08, 0.03, 0.01, 0.18),
		vec4(0.03, 0.01, 0.005, 0.06),
		vec4(0.0, 0.0, 0.0, 0.01)
	);
	int cmapBase = cmapVariant * 8;
	float t = normalizedAge * 7.0;
	int idx = int(clamp(t, 0.0, 6.0));
	vec4 cmapColor = mix(cmaps[cmapBase + idx], cmaps[cmapBase + idx + 1], fract(t));

	// Per-particle brightness variation for smoke (seed-based so each particle is consistent)
	if (isFireParticle < 0.5) {
		float brightnessVar = 0.5 + seed * 0.5;  // range 0.5 to 1.0 (base smoke stays dark)
		cmapColor.rgb *= brightnessVar * colorTint.rgb;  // colorTint.rgb carries highlight brightness
	}

	// Alpha from instance
	cmapColor.a *= colorTint.a;

	particleColor = cmapColor;

	// Animation frame and row based on texture type
	if (isFireParticle > 0.5) {
		// Fire: 16x6 atlas — tied to lifetime so it burns out naturally
		animFrame = floor(normalizedAge * 15.0 + 0.5);
		rowVariant = floor(seed * 6.0);
	} else {
		// Smoke: 8x8 atlas — constant speed (~4 frames/sec), wraps around
		// Uses absolute age so long-lived smoke doesn't animate in slow-motion
		float smokeAnimSpeed = 0.13;  // frames per game-frame (~4 fps at 30 game-fps)
		float rawFrame = ageFrames * smokeAnimSpeed + seed * 8.0;  // seed offsets start frame
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
		// Fire atlas: 16x6 grid (BARFlame02)
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
		// Smoke atlas: 8x8 grid (smoke-ice-anim)
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
local particleVBO   = nil
local particleShader = nil
local nextParticleID = 0

-- Particle removal queue: [deathFrame] = {particleID, ...}
local particleRemoveQueue = {}

-- Cache of unit death effect sizes
local unitDeathSizeCache = {} -- [unitDefID] = { radius, numPieces }

-- Quality preset state
local currentPreset = 3  -- start at High
local particleCountSamples = {}  -- ring buffer of recent particle counts
local sampleIndex = 0
local sampleCount = 0
local runningSum = 0             -- maintained incrementally to avoid re-summing
local avgParticleCount = 0
local lastPresetSwitchFrame = 0
local PRESET_SWITCH_COOLDOWN = 15  -- 0.5 seconds at 30fps

--------------------------------------------------------------------------------
-- Helper functions
--------------------------------------------------------------------------------

-- Pre-computed culling radius for piece projectiles (50 elmo piece radius + margin)
local PIECE_CULLING_RADIUS = 50 + CULLING_MARGIN

-- Pre-compute quality preset thresholds (maxPct * MAX_PARTICLES)
local presetThresholds = {}
for i = 1, #QUALITY_PRESETS do
	presetThresholds[i] = QUALITY_PRESETS[i].maxPct * MAX_PARTICLES
end

-- Update average particle count and auto-switch quality preset
local maxSamples = mathCeil(AVG_WINDOW_FRAMES / AVG_SAMPLE_INTERVAL)
local function updateQualityPreset(gameFrame)
	if not particleVBO then return end

	-- Sample particle count periodically
	if gameFrame % AVG_SAMPLE_INTERVAL == 0 then
		sampleIndex = (sampleIndex % maxSamples) + 1
		local oldVal = particleCountSamples[sampleIndex] or 0
		local newVal = particleVBO.usedElements
		particleCountSamples[sampleIndex] = newVal
		runningSum = runningSum - oldVal + newVal
		if sampleCount < maxSamples then sampleCount = sampleCount + 1 end
		avgParticleCount = runningSum / sampleCount
	end

	-- Check for preset transitions (with cooldown)
	if gameFrame - lastPresetSwitchFrame < PRESET_SWITCH_COOLDOWN then return end

	local preset = QUALITY_PRESETS[currentPreset]
	if not preset then return end

	-- Pick the highest quality preset whose threshold isn't exceeded
	local newPreset = 1
	for i = #QUALITY_PRESETS, 1, -1 do
		if avgParticleCount < presetThresholds[i] then
			newPreset = i
			break
		end
	end
	if newPreset ~= currentPreset then
		currentPreset = newPreset
		lastPresetSwitchFrame = gameFrame
		spEcho("Death Fire GL4: quality -> " .. QUALITY_PRESETS[currentPreset].name .. " (avg: " .. mathFloor(avgParticleCount) .. ")")
	end
end

-- Pre-cache unit death sizes from UnitDefs (only radius needed for piece sizing)
-- Excludes critters (category OBJECT) and raptors (category RAPTOR)
local function buildUnitDeathSizeCache()
	for udid, ud in pairs(UnitDefs) do
		local cats = ud.modCategories
		if not cats or (not cats.object and not cats.raptor) then
			local radius = ud.radius or 10
			local xsize = ud.xsize or 2
			local zsize = ud.zsize or 2
			local footprint = mathMax(xsize, zsize) * 4  -- footprint in elmos (each square = 8 elmos)
			unitDeathSizeCache[udid] = mathMax(radius, footprint * 0.5)
		end
	end
end

--------------------------------------------------------------------------------
-- Particle spawning
--------------------------------------------------------------------------------

-- Spawn a single particle into the VBO
-- cachedFrame: pass current game frame to avoid redundant spGetGameFrame() calls
local cachedGameFrame = 0
-- Reusable table to avoid per-particle allocation/GC
local particleData = {0,0,0,0, 0,0,0,0, 0,0,0,0, 1,1,1,0}
local function spawnParticle(px, py, pz, vx, vy, vz, size, cmapVariant, lifetime, alphaMult, tintBrightness)
	if particleVBO.usedElements >= MAX_PARTICLES then return end

	local currentFrame = cachedGameFrame
	local seed = mathRandom()
	local rotation = (mathRandom() * 2 - 1) * mathPi  -- inline randomFloat(-pi, pi)

	particleData[1] = px
	particleData[2] = py
	particleData[3] = pz
	particleData[4] = currentFrame
	particleData[5] = vx
	particleData[6] = vy
	particleData[7] = vz
	particleData[8] = lifetime
	particleData[9] = size
	particleData[10] = cmapVariant
	particleData[11] = seed
	particleData[12] = rotation
	local tb = tintBrightness or 1.0
	particleData[13] = tb
	particleData[14] = tb
	particleData[15] = tb
	particleData[16] = alphaMult

	nextParticleID = nextParticleID + 1
	local particleID = nextParticleID
	pushElementInstance(particleVBO, particleData, particleID, true, false)

	-- Schedule removal
	local deathFrame = currentFrame + mathCeil(lifetime) + 5
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
	spEcho("Death Fire & Smoke GL4 exiting: " .. reason)
	widgetHandler:RemoveWidget()
end

local shaderSourceCache = {
	vsSrc = vsSrc,
	fsSrc = fsSrc,
	shaderName = PARTICLE_SHADER_NAME,
	uniformInt = {
		fireTex  = 0,
		smokeTex = 1,
	},
	uniformFloat = {},
	shaderConfig = {
		SMOKE_GROWTH_MULT = SMOKE_GROWTH_MULT,
		SMOKE_GROWTH_RATE = SMOKE_GROWTH_RATE,
		SMOKE_WOBBLE_START = SMOKE_WOBBLE_START,
		SMOKE_WOBBLE_RAMP = SMOKE_WOBBLE_RAMP,
		SMOKE_WOBBLE_RATE = SMOKE_WOBBLE_RATE,
	},
	forceupdate = true,
}

local function initGL4()
	particleShader = LuaShader.CheckShaderUpdates(shaderSourceCache)
	if not particleShader then
		goodbye("Failed to compile particle shader")
		return false
	end

	-- Create quad geometry for billboards
	local quadVBO, numVertices = gl.InstanceVBOTable.makeRectVBO(
		-1, -1, 1, 1,  -- position (centered quad)
		0, 0, 1, 1,    -- UVs
		"deathFireQuadVBO"
	)

	-- Define per-instance particle layout
	local particleLayout = {
		{id = 1, name = 'worldPos',    size = 4},  -- xyz + birthFrame
		{id = 2, name = 'velocity',    size = 4},  -- xyz + lifetime
		{id = 3, name = 'sizeAndType', size = 4},  -- baseSize, type, seed, rotation
		{id = 4, name = 'colorTint',   size = 4},  -- rgb + alphaMult
	}

	particleVBO = gl.InstanceVBOTable.makeInstanceVBOTable(
		particleLayout, MAX_PARTICLES, "deathFireSmokeVBO"
	)
	if not particleVBO then
		goodbye("Failed to create particle VBO")
		return false
	end

	particleVBO.numVertices = numVertices
	particleVBO.vertexVBO = quadVBO
	particleVBO.VAO = particleVBO:makeVAOandAttach(quadVBO, particleVBO.instanceVBO)
	particleVBO.primitiveType = GL.TRIANGLES

	local indexVBO = gl.InstanceVBOTable.makeRectIndexVBO("deathFireIndexVBO")
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
local function DrawParticles()
	if not particleVBO or particleVBO.usedElements == 0 then return end
	if not particleShader then return end

	glDepthTest(true)
	glDepthMask(false)
	glCulling(false)

	-- Premultiplied alpha blending for fire, standard for smoke
	-- Using standard alpha blending works well for both
	glBlending(GL_ONE, GL_ONE_MINUS_SRC_ALPHA)  -- premultiplied alpha (fire outputs premultiplied, smoke divides out)

	glTexture(0, fireTexture)
	glTexture(1, smokeTexture)

	particleShader:Activate()

	particleVBO:Draw()

	particleShader:Deactivate()

	glTexture(0, false)
	glTexture(1, false)

	-- Reset to default blending
	glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	glDepthMask(true)
	glDepthTest(false)
end

-- Remove expired particles from VBO
local function removeExpiredParticles(gameFrame)
	-- Only run removal every 4 frames, process wider window
	if gameFrame % 4 ~= 0 then return end
	local idToIdx = particleVBO.instanceIDtoIndex
	for frame = gameFrame - 5, gameFrame do
		local queue = particleRemoveQueue[frame]
		if queue then
			for i = 1, #queue do
				local pid = queue[i]
				if idToIdx[pid] then
					popElementInstance(particleVBO, pid)
				end
			end
			particleRemoveQueue[frame] = nil
		end
	end
end

--------------------------------------------------------------------------------
-- Piece projectile tracking (for debris fire trails)
--------------------------------------------------------------------------------
local trackedPieceProjectiles = {}  -- [proID] = { spawnTimer, sizeScale, ... }
local pendingDeathUnitRadii = {}    -- [unitID] = radius, set in UnitDestroyed so piece tracker can use it
local excludedDeathUnits = {}       -- [unitID] = true, for raptors/critters whose pieces should be skipped
local pieceGeneration = 0  -- incremented each update; used to detect stale tracked pieces without allocating a set


-- Spawns trail particles for a single tracked piece projectile
-- Extracted to keep updatePieceProjectiles under the 60 upvalue limit
local function spawnPieceTrailParticles(tracked, proID, gameFrame, cx, cy, cz, preset)
	local pieceAge = gameFrame - tracked.birthFrame

	-- Stop emitting after piece lifetime expires
	if pieceAge > tracked.lifeFrames then return end

	tracked.spawnTimer = tracked.spawnTimer + 1
	if tracked.spawnTimer < PIECE_SPAWN_INTERVAL then return end
	tracked.spawnTimer = 0

	local px, py, pz = spGetProjectilePosition(proID)
	if not px then return end

	-- Skip ground check for pieces clearly airborne
	local aboveGround = py > PIECE_GROUND_SKIP_HEIGHT
	if not aboveGround then
		local groundY = spGetGroundHeight(px, pz) or 0
		aboveGround = py > groundY + 1
	end
	if not (aboveGround and spIsSphereInView(px, py, pz, PIECE_CULLING_RADIUS)) then return end

	-- Distance LOD: reduce spawns for distant pieces
	local dx, dy, dz = px - cx, py - cy, pz - cz
	local distSq = dx*dx + dy*dy + dz*dz
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

	-- Spawn multiple smoke particles early, tapering to 1 late in life
	local presetLifeMult = preset.lifetimeMult * lodMult
	local spawnCount = mathMax(1, mathFloor((PIECE_SPAWN_COUNT_MAX - ageFrac * PIECE_SPAWN_TAPER + 0.5) * preset.spawnMult * preset.pieceCountMult * lodMult))
	local skipChance = PIECE_SKIP_CHANCE + (1.0 - lodMult) * 0.3

	-- Pre-compute combined multipliers for the inner loops
	local smokeLifeBase = presetLifeMult * SMOKE_LIFETIME_MULT
	local smokeAlphaBase = (1.0 - ageFrac * PIECE_ALPHA_FADE) * (fi > 0 and 1.0 or 0.6)
	local smokeSizeSc = sc * (fi > 0 and 1.0 or 0.75)

	-- Always emit smoke particles (cmapVariant = 0)
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
			-- Highlight: lighter particle slightly above (sunlit top)
			if SMOKE_HIGHLIGHT_ENABLED then
				spawnParticle(
					spx, spy + SMOKE_HIGHLIGHT_OFFSET_Y, spz,
					svx, svy, svz,
					particleSize * SMOKE_HIGHLIGHT_SIZE, 0,
					smokeLife * SMOKE_HIGHLIGHT_LIFE,
					smokeAlpha * SMOKE_HIGHLIGHT_ALPHA,
					SMOKE_HIGHLIGHT_BRIGHT
				)
			end
		end
	end

	-- Emit a short-lived fire particle on top (if this emitter has fire)
	if fi > 0 then
		local sizeRand = mathRandom() * PARTICLE_SIZE_RANGE
		local particleSize = (PARTICLE_SIZE_MIN + sizeRand) * sc * FIRE_SIZE_MULT * fi
		spawnParticle(
			px + mathRandom() * 0.6 - 0.3, py + mathRandom() * 0.5, pz + mathRandom() * 0.6 - 0.3,
			vxs + (mathRandom() * SMOKE_VEL_RANDOM_2 - SMOKE_VEL_RANDOM),
			vys + mathRandom() * SMOKE_VEL_UP_RANGE + SMOKE_VEL_UP_MIN,
			vzs + (mathRandom() * SMOKE_VEL_RANDOM_2 - SMOKE_VEL_RANDOM),
			particleSize, 1,  -- 1 = fire
			(FIRE_LIFETIME_MIN + mathRandom() * FIRE_LIFETIME_RANGE) * presetLifeMult * fi,
			(FIRE_ALPHA_MIN + mathRandom() * 0.2) * (0.5 + 0.5 * fi)
		)
	end
end

local function updatePieceProjectiles(gameFrame)
	if not spGetProjectilesInRectangle then return end

	-- Get camera position for distance-based LOD
	local cx, cy, cz = spGetCameraPosition()

	-- Get all piece projectiles in the map
	local projectiles = spGetProjectilesInRectangle(0, 0, mapSizeX, mapSizeZ, true, false)
	if not projectiles then return end

	-- Cache preset once for all pieces this frame
	local preset = QUALITY_PRESETS[currentPreset]

	-- Try to associate new pieces with a recently-dead unit radius
	local _, ownerRadius = next(pendingDeathUnitRadii)

	pieceGeneration = pieceGeneration + 1
	local gen = pieceGeneration
	local numProjectiles = #projectiles
	for i = 1, numProjectiles do
		local proID = projectiles[i]
		local tracked = trackedPieceProjectiles[proID]
		if not tracked then
			-- New piece projectile - check if it belongs to an excluded unit (raptor/critter)
			local ownerID = spGetProjectileOwnerID(proID)
			if ownerID and excludedDeathUnits[ownerID] then
				-- Mark as excluded so we don't check again
				trackedPieceProjectiles[proID] = { gen = gen, excluded = true }
			else
				-- New piece projectile - start tracking
				local px, py, pz = spGetProjectilePosition(proID)
				if px then
					local pieceRadius = ownerRadius or 10
					local sizeScale = mathMax(PIECE_SIZE_SCALE_MIN, mathMin(PIECE_SIZE_SCALE_MAX, pieceRadius / PIECE_SIZE_SCALE_REF))
					local fi = mathRandom() < PIECE_FIRE_CHANCE and (0.3 + mathRandom() * 0.7) or 0
					local lifeScale = fi > 0 and (1.0 + 0.3 * fi) or 0.7
					trackedPieceProjectiles[proID] = {
						spawnTimer = 0,
						sizeScale = sizeScale,
						birthFrame = gameFrame,
						lifeFrames = mathFloor((PIECE_LIFE_BASE + pieceRadius * PIECE_LIFE_PER_RADIUS) * lifeScale),
						gen = gen,
						fireIntensity = fi,
						lifeBias = mathRandom() * 0.7,  -- per-emitter bias within lifetime range (pre-computed * 0.7)
					}
				end
			end
		else
			tracked.gen = gen
			if not tracked.excluded then
				spawnPieceTrailParticles(tracked, proID, gameFrame, cx, cy, cz, preset)
			end
		end
	end

	-- Clean up tracked pieces that no longer exist (stale generation)
	for proID, tracked in pairs(trackedPieceProjectiles) do
		if tracked.gen ~= gen then
			trackedPieceProjectiles[proID] = nil
		end
	end
end

--------------------------------------------------------------------------------
-- Crashing aircraft tracking (dense smoke trails behind crashing planes)
--------------------------------------------------------------------------------
local trackedCrashingAircraft = {}  -- [unitID] = { birthFrame, sizeScale, fireIntensity, spawnTimer, lifetimeMult, spawnMult }
local crashingAircraftCount = 0

-- Build a lookup of aircraft unitDefIDs for crash trail scaling
local aircraftDataCache = {}  -- [unitDefID] = { radius, unitScale }
do
	for udid, ud in pairs(UnitDefs) do
		if ud.canFly then
			local radius = ud.radius or 20
			local xsize = ud.xsize or 2
			local zsize = ud.zsize or 2
			local footprint = mathMax(xsize, zsize) * 4
			radius = mathMax(radius, footprint * 0.5)

			local metalCost = ud.metalCost or 50
			local radiusFactor = radius / CRASH_SCALE_RADIUS_REF
			local costFactor = metalCost / CRASH_SCALE_COST_REF
			local rawScale = radiusFactor * CRASH_SCALE_RADIUS_WEIGHT + costFactor * CRASH_SCALE_COST_WEIGHT
			local unitScale = mathMax(CRASH_SCALE_MIN, mathMin(CRASH_SCALE_MAX, rawScale))

			aircraftDataCache[udid] = { radius = radius, unitScale = unitScale }
		end
	end
end

-- Spawns trail particles for a single crashing aircraft
local function spawnCrashTrailParticles(tracked, unitID, gameFrame, cx, cy, cz, preset)
	local crashAge = gameFrame - tracked.birthFrame
	if crashAge > CRASH_MAX_DURATION then return end

	tracked.spawnTimer = tracked.spawnTimer + 1
	if tracked.spawnTimer < CRASH_SPAWN_INTERVAL then return end
	tracked.spawnTimer = 0

	local px, py, pz = spGetUnitPosition(unitID)
	if not px then return end

	local inView = spIsSphereInView(px, py, pz, CRASH_CULLING_TOTAL)
	if not CRASH_ALWAYS_EMIT and not inView then return end

	-- Distance LOD (crash-specific: stays visible at greater distances)
	local dx, dy, dz = px - cx, py - cy, pz - cz
	local distSq = dx*dx + dy*dy + dz*dz
	local lodMult = 1.0
	if distSq > CRASH_LOD_DIST_NEAR_SQ then
		local t = (mathSqrt(distSq) - CRASH_LOD_DIST_NEAR) * CRASH_LOD_DIST_RANGE_INV
		lodMult = t >= 1.0 and CRASH_LOD_MIN_MULT or (1.0 - t * CRASH_LOD_MULT_RANGE)
	end

	-- Get aircraft velocity for trail direction
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

	local presetLifeMult = preset.lifetimeMult * lodMult
	local spawnCount = mathMax(1, mathFloor(CRASH_SPAWN_COUNT * preset.spawnMult * lodMult * unitSpawnMult + 0.5))
	local skipChance = CRASH_SKIP_CHANCE + (1.0 - lodMult) * 0.3

	-- Pre-compute combined multipliers
	local smokeLifeBase = presetLifeMult * SMOKE_LIFETIME_MULT * CRASH_LIFETIME_MULT * unitLifeMult
	local smokeAlphaBase = (1.0 - ageFrac * CRASH_ALPHA_FADE) * (fi > 0 and 1.0 or 0.6)
	local smokeSizeSc = sc * CRASH_SIZE_MULT * (fi > 0 and 1.0 or 0.75)

	-- Emit smoke particles
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
			-- Highlight: lighter particle slightly above (sunlit top)
			if SMOKE_HIGHLIGHT_ENABLED then
				spawnParticle(
					spx, spy + SMOKE_HIGHLIGHT_OFFSET_Y, spz,
					svx, svy, svz,
					particleSize * SMOKE_HIGHLIGHT_SIZE, 0,
					smokeLife * SMOKE_HIGHLIGHT_LIFE,
					smokeAlpha * SMOKE_HIGHLIGHT_ALPHA,
					SMOKE_HIGHLIGHT_BRIGHT
				)
			end
		end
	end

	-- Emit fire particle (if this emitter has fire)
	if fi > 0 then
		local sizeRand = mathRandom() * PARTICLE_SIZE_RANGE
		local particleSize = (PARTICLE_SIZE_MIN + sizeRand) * sc * FIRE_SIZE_MULT * CRASH_FIRE_SIZE_MULT * fi
		spawnParticle(
			px + mathRandom() * 2 - 1, py + mathRandom(), pz + mathRandom() * 2 - 1,
			vxs + (mathRandom() * SMOKE_VEL_RANDOM_2 - SMOKE_VEL_RANDOM),
			vys + mathRandom() * SMOKE_VEL_UP_RANGE + SMOKE_VEL_UP_MIN,
			vzs + (mathRandom() * SMOKE_VEL_RANDOM_2 - SMOKE_VEL_RANDOM),
			particleSize, 1,  -- 1 = fire
			(FIRE_LIFETIME_MIN + mathRandom() * FIRE_LIFETIME_RANGE) * presetLifeMult * CRASH_FIRE_LIFETIME_MULT * fi * unitLifeMult,
			(FIRE_ALPHA_MIN + mathRandom() * 0.2) * (0.5 + 0.5 * fi)
		)
	end
end

local function updateCrashingAircraft(gameFrame)
	if crashingAircraftCount == 0 then return end

	local cx, cy, cz = spGetCameraPosition()
	local preset = QUALITY_PRESETS[currentPreset]

	for unitID, tracked in pairs(trackedCrashingAircraft) do
		-- Check if unit is still alive
		if not spValidUnitID(unitID) then
			trackedCrashingAircraft[unitID] = nil
			crashingAircraftCount = crashingAircraftCount - 1
		elseif gameFrame - tracked.birthFrame > CRASH_MAX_DURATION then
			trackedCrashingAircraft[unitID] = nil
			crashingAircraftCount = crashingAircraftCount - 1
		else
			spawnCrashTrailParticles(tracked, unitID, gameFrame, cx, cy, cz, preset)
		end
	end
end

--------------------------------------------------------------------------------
-- Widget callins
--------------------------------------------------------------------------------
function widget:Initialize()
	if not gl.CreateShader then
		goodbye("OpenGL shaders not supported")
		return
	end

	buildUnitDeathSizeCache()

	if not initGL4() then
		return
	end
end

function widget:Shutdown()
	cleanupGL4()
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	if not particleVBO then return end

	-- Stop tracking crashing aircraft on death
	if trackedCrashingAircraft[unitID] then
		trackedCrashingAircraft[unitID] = nil
		crashingAircraftCount = crashingAircraftCount - 1
	end

	local radius = unitDeathSizeCache[unitDefID]
	if radius then
		-- Store radius so the piece projectile tracker can size effects appropriately
		pendingDeathUnitRadii[unitID] = radius
	else
		-- Mark as excluded so its piece projectiles won't emit particles
		excludedDeathUnits[unitID] = true
	end
end

function widget:CrashingAircraft(unitID, unitDefID, teamID)
	if not particleVBO then return end
	if trackedCrashingAircraft[unitID] then return end  -- already tracking

	local data = aircraftDataCache[unitDefID]
	local unitScale = data and data.unitScale or 1.0

	-- Derive per-unit multipliers from unitScale using configurable exponents
	local sizeScale = unitScale ^ CRASH_SCALE_SIZE_EXP
	local lifetimeMult = unitScale ^ CRASH_SCALE_LIFE_EXP
	local spawnMult = unitScale ^ CRASH_SCALE_SPAWN_EXP

	-- Bigger/costlier units burn more reliably and intensely
	local fireChance = mathMin(1.0, CRASH_FIRE_CHANCE * (0.5 + 0.5 * unitScale))
	local fi = mathRandom() < fireChance and (CRASH_FIRE_INTENSITY_MIN + mathRandom() * (1.0 - CRASH_FIRE_INTENSITY_MIN)) * mathMin(1.0, 0.6 + 0.4 * unitScale) or 0

	trackedCrashingAircraft[unitID] = {
		spawnTimer = 0,
		sizeScale = sizeScale,
		birthFrame = cachedGameFrame,
		fireIntensity = fi,
		lifetimeMult = lifetimeMult,
		spawnMult = spawnMult,
	}
	crashingAircraftCount = crashingAircraftCount + 1
end

function widget:GameFrame(n)
	if not particleVBO then return end

	if debugEcho and n % 30 == 0 then
		Spring.Echo("Death Fire GL4: avg particles: " .. mathFloor(avgParticleCount) .. ", quality: " .. QUALITY_PRESETS[currentPreset].name)
	end

	-- Cache frame for spawnParticle to avoid repeated spGetGameFrame() calls
	cachedGameFrame = n

	-- Track average particle count and auto-switch quality preset
	updateQualityPreset(n)

	-- Remove expired particles
	removeExpiredParticles(n)

	-- Track piece projectiles — reduce update rate when particle count is high or FPS is low
	local updateInterval = PIECE_SPAWN_INTERVAL
	if avgParticleCount > MAX_PARTICLES * 0.8 then
		updateInterval = 3
	elseif avgParticleCount > MAX_PARTICLES * 0.4 then
		updateInterval = 2
	end
	-- Don't update faster than the render FPS can display
	local fps = spGetFPS()
	if fps > 0 then
		local minInterval = mathCeil(30 / fps)
		if minInterval > updateInterval then
			updateInterval = minInterval
		end
	end
	if n % updateInterval == 0 then
		updatePieceProjectiles(n)
		updateCrashingAircraft(n)
	end

	-- Clean up pending death unit radii and exclusion set after a short delay
	if n % 30 == 0 then
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
end

function widget:DrawWorld()
	DrawParticles()
end

-- Skip reflection pass for smoke/fire particles (they're rarely visible in reflections
-- and the draw call is identical cost to the main pass)

-- Reconfigure if needed
function widget:GetConfigData()
	return {
		maxParticles = MAX_PARTICLES,
		qualityPreset = currentPreset,
	}
end

function widget:SetConfigData(data)
	if data then
		--if data.maxParticles then MAX_PARTICLES = data.maxParticles end
		if data.qualityPreset and QUALITY_PRESETS[data.qualityPreset] then
			currentPreset = data.qualityPreset
		end
	end
end
