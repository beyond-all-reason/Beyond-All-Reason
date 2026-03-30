--------------------------------------------------------------------------------
-- GPU-based fire & smoke particle system for unit death effects
-- Replaces CPU-based CEG pieceexplosiongenerators with instanced GL4 rendering
--------------------------------------------------------------------------------
local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Death Fire & Smoke GL4",
		desc = "Fire and smoke particles for unit death pieces",
		author = "Floris",
		date = "March 2026",
		license = "GNU GPL v2",
		layer = 0,
		enabled = true,
	}
end

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

-- General
local MAX_PARTICLES          = 10000
local PARTICLE_SHADER_NAME   = "DeathFireSmokeGL4"
local PARTICLE_SIZE_MIN      = 13
local PARTICLE_SIZE_MAX      = 26

local SMOKE_LIFETIME_MULT      = 0.9  -- lifetime multiplier for smoke particles

-- Piece projectile trails (fire on flying debris)
local PIECE_SPAWN_INTERVAL     = 1    -- frames between piece spawns
local PIECE_SPAWN_COUNT_MAX    = 3    -- max particles spawned per piece per interval (early life)
local PIECE_SPAWN_TAPER        = 2.5  -- how fast spawn count reduces with piece age
local PIECE_SKIP_CHANCE        = 0.1  -- chance to skip spawning a particle (visual variety)
local PIECE_VEL_SCALE          = 6.0  -- velocity inheritance multiplier (after 0.05 pre-scale)
local PIECE_VEL_RANDOM         = 0.1  -- random velocity offset per axis
local PIECE_VEL_UP_MIN         = 0.04 -- minimum upward velocity
local PIECE_VEL_UP_MAX         = 0.20 -- maximum upward velocity (0.04 + 0.16)
local PIECE_LIFETIME_MIN       = 15   -- min particle lifetime in frames
local PIECE_LIFETIME_RANGE     = 25   -- lifetime variation range
local PIECE_LIFETIME_MULT_MIN  = 0.5  -- min per-piece lifetime multiplier
local PIECE_LIFETIME_MULT_MAX  = 1.8  -- max per-piece lifetime multiplier
local PIECE_SIZE_SCALE_MIN     = 0.3  -- min size multiplier for piece particles
local PIECE_SIZE_SCALE_MAX     = 1.5  -- max size multiplier
local PIECE_SIZE_SCALE_REF     = 25.0 -- reference radius for piece size scaling
local PIECE_LIFE_BASE          = 200   -- base piece emitter lifetime in frames
local PIECE_LIFE_PER_RADIUS    = 1.5  -- extra frames per unit radius
local PIECE_ALPHA_FADE         = 0.6  -- alpha reduction over piece age
local PIECE_ALPHA_MIN          = 0.3  -- min random alpha
local PIECE_GROUND_SKIP_HEIGHT = 5    -- skip ground check above this height

-- Fire particle settings (short-lived fire on top of smoke)
local FIRE_CHANCE              = 0.25  -- chance per spawn interval to also emit fire
local FIRE_LIFETIME_MIN        = 33   -- min fire particle lifetime in frames
local FIRE_LIFETIME_RANGE      = 33   -- fire lifetime variation
local FIRE_SIZE_MULT           = 0.85  -- fire particles are smaller than smoke
local FIRE_ALPHA_MIN           = 0.8  -- fire particles are brighter

-- Frustum culling margin (elmos beyond visible sphere to still spawn)
local CULLING_MARGIN           = 300  -- extra radius for view check

-- Pre-computed constants (avoid repeated arithmetic in hot loops)
local PIECE_VEL_COMBINED       = PIECE_VEL_SCALE * 0.05  -- velocity inheritance * engine pre-scale combined
local PIECE_VEL_RANDOM_2       = PIECE_VEL_RANDOM * 2
local PIECE_VEL_UP_RANGE       = PIECE_VEL_UP_MAX - PIECE_VEL_UP_MIN
local PARTICLE_SIZE_RANGE      = PARTICLE_SIZE_MAX - PARTICLE_SIZE_MIN
local PIECE_ALPHA_RANGE        = 1.0 - PIECE_ALPHA_MIN
local PIECE_LIFE_MULT_RANGE    = PIECE_LIFETIME_MULT_MAX - PIECE_LIFETIME_MULT_MIN
local PARTICLE_SIZE_INV_RANGE  = 1.0 / PARTICLE_SIZE_RANGE  -- for normalizing size to 0..1
local PIECE_SIZE_LIFE_SCALE    = 1  -- bigger particles live up to 100% longer

-- Distance LOD: reduce spawn count when camera is far away
local LOD_DIST_NEAR            = 1500   -- full detail within this range
local LOD_DIST_FAR             = 5500  -- minimum detail beyond this range
local LOD_MIN_MULT             = 0.33  -- spawn multiplier at max distance
local LOD_DIST_RANGE_INV       = 1.0 / (LOD_DIST_FAR - LOD_DIST_NEAR)
local LOD_MULT_RANGE           = 1.0 - LOD_MIN_MULT
local LOD_DIST_NEAR_SQ         = LOD_DIST_NEAR * LOD_DIST_NEAR

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
local AVG_SAMPLE_INTERVAL      = 3    -- sample every N frames

-- Textures
local fireTexture  = "bitmaps/projectiletextures/BARFlame02.tga"
local smokeTexture = "bitmaps/projectiletextures/smoke-ice-anim.tga"

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
	pos.y += 0.008 * ageFrames * ageFrames * 0.5;

	// Turbulence: grows with age so particles wobble more over time
	float seedPhase = seed * 6.283;
	float wobble = 0.8 + normalizedAge * 2.4;  // ramps from 0.8 to 3.2
	pos.x += sin(ageFrames * 0.07 + seedPhase * 2.7) * wobble;
	pos.z += cos(ageFrames * 0.09 + seedPhase * 3.8) * wobble;
	pos.y += sin(ageFrames * 0.05 + seedPhase * 1.8) * wobble * 0.25;

	// Size: starts at base, grows with sizegrowth + sizemod (matching deathceg behavior)
	// sizegrowth ~2, sizemod ~0.85 per frame
	float baseSize = sizeAndType.x;
	// Accelerating growth: particles expand more towards end of life
	float growRate = 0.15 + normalizedAge * normalizedAge * 0.26;  // gentle ramp at end
	float sizeGrowth = baseSize + ageFrames * growRate;
	sizeGrowth *= exp(ageFrames * -0.008032);  // ln(0.992) = -0.008032, cheaper than pow

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
	float particleType = sizeAndType.y;
	isFireParticle = step(0.5, particleType);
	int cmapVariant = int(clamp(particleType, 0.0, 1.0));

	// 2 colormaps: 0 = smoke (dark -> lighter -> transparent), 1 = fire (orange -> black -> transparent)
	const vec4 cmaps[16] = vec4[16](
		// Variant 0: smoke
		vec4(0.08, 0.08, 0.08, 0.75),
		vec4(0.10, 0.10, 0.10, 0.7),
		vec4(0.13, 0.13, 0.13, 0.65),
		vec4(0.16, 0.16, 0.16, 0.55),
		vec4(0.18, 0.18, 0.18, 0.45),
		vec4(0.15, 0.15, 0.15, 0.32),
		vec4(0.10, 0.10, 0.10, 0.18),
		vec4(0.06, 0.06, 0.06, 0.01),
		// Variant 1: fire (orange -> black)
		vec4(1.0, 0.6, 0.15, 1.0),
		vec4(0.9, 0.45, 0.1, 0.9),
		vec4(0.65, 0.28, 0.07, 0.75),
		vec4(0.4, 0.15, 0.04, 0.55),
		vec4(0.2, 0.08, 0.02, 0.35),
		vec4(0.08, 0.03, 0.01, 0.18),
		vec4(0.03, 0.01, 0.005, 0.06),
		vec4(0.0, 0.0, 0.0, 0.01)
	);
	int cmapBase = cmapVariant * 8;
	float t = normalizedAge * 7.0;
	int idx = int(clamp(t, 0.0, 6.0));
	vec4 cmapColor = mix(cmaps[cmapBase + idx], cmaps[cmapBase + idx + 1], fract(t));

	// Alpha from instance (tint RGB is always 1.0, skip tint multiply)
	cmapColor.a *= colorTint.a;

	particleColor = cmapColor;

	// Animation frame and row based on texture type
	if (isFireParticle > 0.5) {
		// Fire: 16x6 atlas
		animFrame = floor(normalizedAge * 15.0 + 0.5);
		rowVariant = floor(seed * 6.0);
	} else {
		// Smoke: 8x8 atlas
		animFrame = floor(normalizedAge * 7.0 + 0.5);
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
local function spawnParticle(px, py, pz, vx, vy, vz, size, cmapVariant, lifetime, alphaMult)
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
	-- [13..15] = tint RGB, always 1.0 (set at table init)
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
	shaderConfig = {},
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
local hasGetProjectileVelocity = (spGetProjectileVelocity ~= nil)  -- check once at load

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

	local vxs, vys, vzs = 0, 0, 0
	if hasGetProjectileVelocity then
		local pvx, pvy, pvz = spGetProjectileVelocity(proID)
		if pvx then
			vxs, vys, vzs = pvx * PIECE_VEL_COMBINED, pvy * PIECE_VEL_COMBINED, pvz * PIECE_VEL_COMBINED
		end
	end

	local ageFrac = pieceAge / tracked.lifeFrames
	local sc = tracked.sizeScale
	local fi = tracked.fireIntensity

	-- Spawn multiple smoke particles early, tapering to 1 late in life
	local presetLifeMult = preset.lifetimeMult * lodMult
	local spawnCount = mathMax(1, mathFloor((PIECE_SPAWN_COUNT_MAX - ageFrac * PIECE_SPAWN_TAPER + 0.5) * preset.spawnMult * preset.pieceCountMult * lodMult))
	local skipChance = PIECE_SKIP_CHANCE + (1.0 - lodMult) * 0.3

	-- Pre-compute combined multipliers for the inner loops
	local smokeLifeBase = tracked.lifeMult * presetLifeMult * SMOKE_LIFETIME_MULT
	local smokeAlphaBase = (1.0 - ageFrac * PIECE_ALPHA_FADE) * (fi > 0 and 1.0 or 0.6)
	local smokeSizeSc = sc * (fi > 0 and 1.0 or 0.75)

	-- Always emit smoke particles (cmapVariant = 0)
	for p = 1, spawnCount do
		if mathRandom() > skipChance then
			local sizeRand = mathRandom() * PARTICLE_SIZE_RANGE
			local particleSize = (PARTICLE_SIZE_MIN + sizeRand) * smokeSizeSc
			spawnParticle(
				px + mathRandom() - 0.5, py + mathRandom(), pz + mathRandom() - 0.5,
				vxs + (mathRandom() * PIECE_VEL_RANDOM_2 - PIECE_VEL_RANDOM),
				vys + mathRandom() * PIECE_VEL_UP_RANGE + PIECE_VEL_UP_MIN,
				vzs + (mathRandom() * PIECE_VEL_RANDOM_2 - PIECE_VEL_RANDOM),
				particleSize, 0,  -- 0 = smoke
				(PIECE_LIFETIME_MIN + mathRandom() * PIECE_LIFETIME_RANGE) * (1.0 + sizeRand * PARTICLE_SIZE_INV_RANGE * PIECE_SIZE_LIFE_SCALE) * smokeLifeBase,
				(PIECE_ALPHA_MIN + mathRandom() * PIECE_ALPHA_RANGE) * smokeAlphaBase
			)
		end
	end

	-- Emit a short-lived fire particle on top (if this emitter has fire)
	if fi > 0 then
		local sizeRand = mathRandom() * PARTICLE_SIZE_RANGE
		local particleSize = (PARTICLE_SIZE_MIN + sizeRand) * sc * FIRE_SIZE_MULT * fi
		spawnParticle(
			px + mathRandom() * 0.6 - 0.3, py + mathRandom() * 0.5, pz + mathRandom() * 0.6 - 0.3,
			vxs + (mathRandom() * PIECE_VEL_RANDOM_2 - PIECE_VEL_RANDOM),
			vys + mathRandom() * PIECE_VEL_UP_RANGE + PIECE_VEL_UP_MIN,
			vzs + (mathRandom() * PIECE_VEL_RANDOM_2 - PIECE_VEL_RANDOM),
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
					local fi = mathRandom() < FIRE_CHANCE and (0.3 + mathRandom() * 0.7) or 0
					local lifeScale = fi > 0 and (1.0 + 0.3 * fi) or 0.7
					trackedPieceProjectiles[proID] = {
						spawnTimer = 0,
						sizeScale = sizeScale,
						birthFrame = gameFrame,
						lifeFrames = mathFloor((PIECE_LIFE_BASE + pieceRadius * PIECE_LIFE_PER_RADIUS) * lifeScale),
						gen = gen,
						fireIntensity = fi,
						lifeMult = PIECE_LIFETIME_MULT_MIN + mathRandom() * PIECE_LIFE_MULT_RANGE,
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

	local radius = unitDeathSizeCache[unitDefID]
	if radius then
		-- Store radius so the piece projectile tracker can size effects appropriately
		pendingDeathUnitRadii[unitID] = radius
	else
		-- Mark as excluded so its piece projectiles won't emit particles
		excludedDeathUnits[unitID] = true
	end
end

function widget:GameFrame(n)
	if not particleVBO then return end

	-- if n % 30 == 0 then
	-- 	Spring.Echo("Death Fire GL4: avg particles: " .. mathFloor(avgParticleCount) .. ", quality: " .. QUALITY_PRESETS[currentPreset].name)
	-- end

	-- Cache frame for spawnParticle to avoid repeated spGetGameFrame() calls
	cachedGameFrame = n

	-- Track average particle count and auto-switch quality preset
	updateQualityPreset(n)

	-- Remove expired particles
	removeExpiredParticles(n)

	-- Track piece projectiles — reduce update rate when particle count is high
	local updateInterval = PIECE_SPAWN_INTERVAL
	if avgParticleCount > MAX_PARTICLES * 0.8 then
		updateInterval = 3
	elseif avgParticleCount > MAX_PARTICLES * 0.4 then
		updateInterval = 2
	end
	if n % updateInterval == 0 then
		updatePieceProjectiles(n)
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
