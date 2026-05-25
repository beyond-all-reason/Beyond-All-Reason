--------------------------------------------------------------------------------
-- Flamethrower GL4
-- GPU-instanced replacement for engine "Flame" weapontype projectile visuals.
--
--  * Tracks every visible Flame projectile and emits stylized particles at its
--    current position each frame.
--  * Particle color is interpolated along the projectile's life so the start
--    of the stream (near the nozzle) is blue/cyan/white, the middle is bright
--    yellow/orange and the tail is dark red transitioning into smoke.
--  * Three particle "types":
--        0 = core flame      (fire texture, light buoyancy, big size growth)
--        1 = rising smoke    (smoke texture, strong buoyancy, slow drag)
--  * Per-particle RGB tint (unlike the fire-smoke shader where tint only
--    affects smoke), enabling the blue->white->orange->red gradient.
--  * Per-weapondef config derived from areaofeffect, weaponvelocity,
--    sprayangle, range, damage and burst, all overridable through the
--    CONFIG table near the top of this file.
--  * View-frustum and LOS culling so off-screen / out-of-LOS streams don't
--    consume the particle budget.
--
-- Requires gamedata/alldefs_post.lua to have hidden the engine flame visuals
-- and saved originals as customparams.flame_orig_*.
--------------------------------------------------------------------------------

if gadgetHandler:IsSyncedCode() then return end

function gadget:GetInfo()
	return {
		name    = "Flamethrower GL4",
		desc    = "GL4 instanced replacement effect for Flame weapontype projectiles",
		author  = "Floris",
		date    = "May 2026",
		license = "GNU GPL v2",
		layer   = 0,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- Localized engine functions
--------------------------------------------------------------------------------
local spEcho                   = Spring.Echo
local spGetVisibleProjectiles  = Spring.GetVisibleProjectiles
local spGetProjectilePosition  = Spring.GetProjectilePosition
local spGetProjectileVelocity  = Spring.GetProjectileVelocity
local spGetProjectileDefID     = Spring.GetProjectileDefID
local spGetProjectileTeamID    = Spring.GetProjectileTeamID
local spGetProjectileOwnerID   = Spring.GetProjectileOwnerID
local spGetUnitDefID           = Spring.GetUnitDefID
local spGetUnitPosition        = Spring.GetUnitPosition
local spGetTeamAllyTeamID      = Spring.GetTeamAllyTeamID
local spGetMyAllyTeamID        = Spring.GetMyAllyTeamID
local spGetSpectatingState     = Spring.GetSpectatingState
local spIsPosInLos             = Spring.IsPosInLos
local spIsSphereInView         = Spring.IsSphereInView
local spGetCameraPosition      = Spring.GetCameraPosition
local spGetFPS                 = Spring.GetFPS
local spGetWind                = Spring.GetWind
local spGetGameSpeed           = Spring.GetGameSpeed

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
local pushElementInstance = gl.InstanceVBOTable.pushElementInstance
local popElementInstance  = gl.InstanceVBOTable.popElementInstance

--------------------------------------------------------------------------------
-- CONFIG: tweak these to taste
--------------------------------------------------------------------------------
local CONFIG = {
	-- Global
	enabled              = true,
	maxParticles         = 8000,      -- VBO capacity (also hard cap). Fewer particles than before but each is larger/denser for a more 'real flamethrower' look (and cheaper).
	losCullingEnabled    = true,       -- skip streams whose head is not in LOS

	-- Tiered particle budget. As the pool fills up, lower-priority decorations
	-- are dropped first so core flame (the actual visible projectile trail)
	-- always has room. Thresholds are fractions of maxParticles:
	--   < budgetSoftFrac    : everything spawns (tier 0)
	--   >= budgetSoftFrac   : drop smoke + head-smoke + tail-chaos (tier 1)
	--   >= budgetMediumFrac : also thin jets and cores to every other frame per projectile (tier 2)
	--   >= budgetHardFrac   : essentials only -- 1 core per projectile per frame, no jet, no smoke (tier 3)
	budgetSoftFrac       = 0.5,
	budgetMediumFrac     = 0.7,
	budgetHardFrac       = 0.85,
	-- Overflow headroom above maxParticles reserved EXCLUSIVELY for tier-3
	-- essential core flame. When the pool is past budgetHardFrac, every tracked
	-- projectile still wants its 1 core/frame so the stream doesn't visibly
	-- stutter -- those essential spawns are allowed to cross maxParticles up
	-- to maxParticles * (1 + essentialOverflowFrac). All other particle types
	-- (jet/tail/smoke) and all non-tier-3 cores still respect maxParticles.
	essentialOverflowFrac = 0.25,

	-- Per-projectile-frame emission. Tuned for a dense, opaque-looking stream
	-- with fewer but larger particles -- the 'painterly chunks' approach
	-- reads much better as real fire than a fine particle cloud, and is far
	-- cheaper for the GPU.
	coreSpawnPerFrame    = 1,          -- core fire chunks per projectile per frame
	jetSpawnPerFrame     = 1,          -- subtle blue nozzle jet (very brief, only at muzzle)
	jetMaxLifeFrac       = 0.6,       -- only emit jet particles while projectile lifeFrac < this (tight nozzle, not the whole stream)
	smokeChance          = 0.08,       -- chance per projectile per frame to spawn dark smoke (subtle -- the stream should read as FIRE first, smoke second)
	smokeChanceHead      = 0.05,       -- additional chance to spawn a near-head smoke puff (only after the fire has had time to combust)
	tailEmitChance       = 0.10,       -- chance per frame to spawn an extra 'chaotic tail' particle from the back of the stream
	burstMultiplier      = 1.0,        -- overall emission multiplier
	emitOffsetForward    = -8,        -- spawn slight behind projectile pos (elmos, scaled by speed)

	-- Sizes (larger -> fewer particles needed to look dense)
	sizeAoeRef           = 48,         -- areaofeffect that maps to sizeScale = 1.0
	sizeScaleMin         = 0.7,
	sizeScaleMax         = 2.7,
	-- Core flame size taper from muzzle (0 dist) to max range (1 dist).
	-- muzzleTaperMin: relative size right at the emit point (0=invisible, 1=full size).
	-- muzzleTaperMax: relative size at max weapon range (normally 1.0 for full size).
	-- Curve is quadratic (distT^2) so growth is gentle near the nozzle and
	-- accelerates downrange, giving a thin-jet-to-fat-fire profile.
	muzzleTaperMin       = 0.25,       -- size fraction at muzzle (0 = nothing at nozzle, 1 = full size at nozzle)
	muzzleTaperMax       = 1.0,        -- size fraction at max weapon range

	coreSizeBase         = 7.0,        -- base elmos for core flame chunks (large, dense, painterly)
	smokeSizeBase        = 10.0,        -- big dark smoke puffs
	jetSizeBase          = 1.3,        -- base elmos for nozzle jet stream particles (small, tight)
	sizeRandRange        = 0.6,        -- +/- random size variance

	-- Per-type growth & physics
	coreGrowthMult       = 3.5,       -- core flame grows with age (chunky expansion as fuel combusts)
	smokeGrowthMult      = 3.0,        -- smoke expands a lot (turns into a plume)
	jetGrowthMult        = 0.25,        -- jet barely grows -- stays a clean stream
	flameBuoyancy        = 8.0,        -- elmos of rise at end-of-life for core flame. Applied in shader as FLAME_BUOY*t*t (t = age/life), so visible rise is uniform across weapons regardless of per-weapon lifeMult (cormaw vs short-range flamers). Was previously units/frame^2 which scaled with life^2 -- long-life weapons would billow up to 16x more.
	smokeBuoyancy        = 0.01,      -- strong upward acceleration for smoke (makes it billow above the stream)
	smokeUpwardVelMin    = 0.20,
	smokeUpwardVelMax    = 0.45,

	-- Lifetime (frames). Core/smoke are scaled per-weapon by
	-- (expectedLife / lifeScaleRef) so a particle's life roughly matches
	-- the projectile's flight time -- the oldest still-living particle sits
	-- back at the muzzle while the newest is at the projectile, filling the
	-- full path from nozzle to target. Jet particles stay short on purpose.
	coreLifeMin          = 6,         -- multiplied by per-weapon lifeMult
	coreLifeMax          = 12,
	smokeLifeMin         = 50,
	smokeLifeMax         = 100,
	jetLifeMin           = 6,          -- jet particles are short-lived (clean streak)
	jetLifeMax           = 13,
	expectedLifeFallback = 30,         -- frames to use when range/velocity unknown
	lifeScaleRef         = 30,         -- reference flight-time (frames). lifeMult = clamp(expectedLife / lifeScaleRef, lifeMultMin, lifeMultMax)
	lifeMultMin          = 0.7,
	lifeMultMax          = 3.0,
	coreLifeApplyMult    = true,       -- scale core flame lifetime by per-weapon lifeMult

	-- Velocity inheritance / spread
	-- Lower forward inheritance: particles linger near their spawn point so
	-- the trail visibly spans the projectile path (muzzle->target) instead
	-- of collapsing into a small clump that rides along with the head.
	velocityForwardMult  = 0.32,       -- core flame inherits ~1/3 projectile velocity per frame (lower = less overshoot past target)
	velocityForwardRand  = 0.12,       -- random +/- variation on forward velocity inheritance (0 = uniform)
	jetVelocityMult      = 1.00,       -- jet particles inherit full projectile velocity (smooth stream along path)
	velocityRandTangent  = 0.35,       -- random tangential push (elmos/frame) -- slightly tighter than before
	spreadFromSprayMult  = 0.0005,      -- sprayangle * this = additional tangential offset (tighter -> reads as a concentrated stream)
	jetSpreadMult        = 0.12,       -- jet particles have minimal lateral spread

	-- Wind influence
	windFlameMult        = 0.0006,
	windSmokeMult        = 0.0028,

	-- Turbulence (added in shader, scales with age)
	wobbleAmpMin         = 0.3,
	wobbleAmpMax         = 1.2,        -- max wobble at end of life for core flame (tighter = more directed stream)
	smokeWobbleAmp       = 3.2,        -- smoke wobbles more (turbulent rising column)

	-- Fire tint gradient (along projectile life: t in [0,1]). Tuned from
	-- reference photos of real flamethrowers: a mostly saturated yellow-to-
	-- red-orange palette, with only a small hot-white pinch at the very
	-- muzzle. The blue is handled separately by the nozzle jet.
	-- Stops are: (t, r, g, b)
	tintStops = {
		{ 0.00, 1.00, 0.95, 0.7 },    -- near-white hot pinch at the nozzle
		{ 0.12, 1.00, 0.93, 0.55 },    -- bright pale yellow
		{ 0.32, 1.00, 0.75, 0.3 },    -- saturated yellow-orange (main body)
		--{ 0.58, 1.00, 0.55, 0.12 },    -- orange
		--{ 1.00, 0.55, 0.10, 0.04 },    -- dying ember
	},
	tintBrightness       = 1.75,        -- global multiplier on tint rgb (brighter for a hot, glowing look)
	tintMicroJitter      = 0.3,       -- per-particle jitter on lifeT used to sample the tint LUT (wider = more color variation between neighbouring particles)
	tintRGBJitter        = 0.12,       -- per-particle multiplicative RGB jitter (channel +/- this, makes individual chunks read warmer/cooler/brighter/darker)
	smokeTint            = { 0.18, 0.17, 0.15 }, -- medium gray-brown smoke (not pitch black -- still reads as smoke without darkening the scene)
	smokeTintHead        = { 0.32, 0.30, 0.27 }, -- lighter for head smoke (mixed with hot air -- almost a haze)

	-- Nozzle jet stream (the smooth procedural blue effect at the muzzle).
	-- Rendered as a soft additive radial disc -- no fire/smoke sprite -- to
	-- give a clean, jet-like look that contrasts with the chaotic flame.
	jetColor             = { 0.55, 0.80, 1.00 }, -- base blue color of the jet stream
	jetBrightness        = 1.33,        -- additive intensity of the jet (drives bloom feel)
	jetAlphaBase         = 0.75,
	jetWobble            = 0.33,       -- jet wobble amplitude (kept very small for clean look)
	jetStretchMult       = 1.5,        -- jet billboards are stretched along the projectile velocity by this factor (length = baseSize * jetStretchMult, width = baseSize). Lets a single particle cover the screen-space distance the projectile would otherwise need 8 round particles for -- the jet reads as a streak rather than a chain of dots, and the per-frame particle budget for jets effectively pays for ~8x its visible coverage.

	-- Scavenger tint: applied when the projectile owner unit has
	-- customParams.isscavenger. scavJetColor REPLACES the blue jet RGB, and
	-- scavTintStops REPLACES the fire-gradient LUT for scav projectiles --
	-- same shape as tintStops above (white-hot pinch at nozzle, then ramping
	-- through the warm body of the stream) but tinted pink/magenta/purple.
	scavJetColor         = { 0.3, 0.0, 0.8 }, -- magenta-purple jet
	scavTintStops = {
		{ 0.00, 0.93, 0.85, 1.00 },    -- pure white hot pinch at the nozzle
		{ 0.12, 0.9, 0.78, 0.95 },    -- pale pink
		{ 0.32, 0.8, 0.64, 0.92 },    -- saturated pink
	},

	-- Alpha
	coreAlphaBase        = 0.95,       -- very opaque -- reads as dense fire
	smokeAlphaBase       = 0.30,       -- light, translucent smoke (don't blot out the scene)

	-- LOD: distance falloff
	lodDistNear          = 3000,
	lodDistFar           = 9000,
	lodMinMult           = 0.30,
	lodDistCull          = 24000,      -- hard cull: beyond this camera distance the projectile is skipped entirely (no emit, no LOS check, no per-particle work). At this distance the stream is far below 1px so there's nothing to see.
	losCacheInterval     = 12,         -- frames between fresh spIsPosInLos lookups per tracked projectile (the cached visibility flag is reused in between). 12 frames = ~0.4s at 30fps; flames are short-lived enough that one stale frame is invisible.
	staleGcInterval      = 30,         -- frames between sweeps that drop tracked/ignored entries whose engine projectile has died off-screen. Was every frame -- this is pure bookkeeping with no visual effect.

	-- Frustum culling padding (elmos)
	cullingPad           = 200,
}

--------------------------------------------------------------------------------
-- Build weaponDefID -> per-weapon config from WeaponDefs at gadget load.
-- Reads engine WeaponDefs (which contain customParams.flame_orig_* injected by
-- gamedata/alldefs_post.lua).
--------------------------------------------------------------------------------

local weaponConfigs = {}
local hasFlameWeapons = false
local missingAlldefsPost = 0     -- count of flame weapons missing the flame_orig_* customparams

for weaponID, wd in pairs(WeaponDefs) do
	if wd.type == "Flame" then
		local cp = wd.customParams or {}
		if not cp.flame_orig_intensity then
			-- alldefs_post.lua didn't run for this weaponDef. That means the
			-- engine flame billboard + cegtag are still active and the gadget
			-- will visually compete with them.
			missingAlldefsPost = missingAlldefsPost + 1
		end
		local origRange     = tonumber(cp.flame_orig_range)     or wd.range or 200
		local origVelocity  = tonumber(cp.flame_orig_velocity)  or wd.projectilespeed or 250
		local origAoe       = tonumber(cp.flame_orig_areaofeffect) or wd.damageAreaOfEffect or 48
		local origSprayDeg  = tonumber(cp.flame_orig_sprayangle) or 0
		local origDamage    = tonumber(cp.flame_orig_damage) or 0
		local origIntensity = tonumber(cp.flame_orig_intensity) or 0.5

		-- velocity returned by WeaponDefs is already in elmos/frame
		local velPerFrame = origVelocity / 30

		local sizeScale = mathMax(CONFIG.sizeScaleMin,
			mathMin(CONFIG.sizeScaleMax, origAoe / CONFIG.sizeAoeRef))

		-- Damage scales intensity slightly (more dmg = denser stream)
		local damageMult = 1.0 + mathMin(0.8, origDamage / 80)

		-- Expected projectile life in frames (range / per-frame speed)
		local expectedLife = velPerFrame > 0
			and mathMax(8, mathFloor(origRange / velPerFrame))
			or CONFIG.expectedLifeFallback

		-- Per-weapon lifetime multiplier so particles cover the full
		-- projectile flight path (longer-range/slower weapons get longer-lived
		-- particles so the visual stream stretches from muzzle to target).
		local lifeMult = expectedLife / CONFIG.lifeScaleRef
		if lifeMult < CONFIG.lifeMultMin then lifeMult = CONFIG.lifeMultMin end
		if lifeMult > CONFIG.lifeMultMax then lifeMult = CONFIG.lifeMultMax end

		-- Precompute 1/range^2 for the distance-based muzzleTaper. Avoids
		-- recomputing it every frame per projectile in emitStream.
		local rangeRef = origRange > 0 and origRange or 200
		local invRangeSq = 1 / (rangeRef * rangeRef)

		weaponConfigs[weaponID] = {
			range          = origRange,
			invRangeSq     = invRangeSq,
			velocity       = origVelocity,
			velPerFrame    = velPerFrame,
			areaOfEffect   = origAoe,
			sprayAngle     = origSprayDeg,
			damage         = origDamage,
			intensity      = origIntensity,
			sizeScale      = sizeScale,
			damageMult     = damageMult,
			expectedLife   = expectedLife,
			lifeMult       = lifeMult,
			spreadOffset   = origSprayDeg * CONFIG.spreadFromSprayMult,
		}
		hasFlameWeapons = true
	end
end

if not hasFlameWeapons or not CONFIG.enabled then
	function gadget:Initialize()
		gadgetHandler:RemoveGadget()
	end
	return
end

--------------------------------------------------------------------------------
-- Build a 1D tint LUT (16 entries) from CONFIG.tintStops
-- We bake it into the shader as a const array; rebuilt only if user changes config.
--------------------------------------------------------------------------------
local TINT_LUT_SIZE = 16
local function buildTintLut()
	local lut = {}
	local stops = CONFIG.tintStops
	for i = 0, TINT_LUT_SIZE - 1 do
		local t = i / (TINT_LUT_SIZE - 1)
		-- Find surrounding stops
		local a, b = stops[1], stops[#stops]
		for j = 1, #stops - 1 do
			if t >= stops[j][1] and t <= stops[j + 1][1] then
				a, b = stops[j], stops[j + 1]
				break
			end
		end
		local span = b[1] - a[1]
		local k = span > 0 and (t - a[1]) / span or 0
		local r = a[2] + (b[2] - a[2]) * k
		local g = a[3] + (b[3] - a[3]) * k
		local bl = a[4] + (b[4] - a[4]) * k
		lut[i + 1] = string.format("vec3(%.4f, %.4f, %.4f)", r, g, bl)
	end
	return table.concat(lut, ", ")
end

--------------------------------------------------------------------------------
-- Shaders
--------------------------------------------------------------------------------
local vsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 10000

//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

uniform vec3 windVelocity;

layout (location = 0) in vec4 position_xy_uv;

layout (location = 1) in vec4 worldPos;    // xyz spawn pos, w birthFrame
layout (location = 2) in vec4 velLife;     // xyz initial vel, w lifetime frames
layout (location = 3) in vec4 sizeData;    // x baseSize, y type (0 core,1 smoke,3 jet), z seed, w rotation
layout (location = 4) in vec4 tintAlpha;   // rgb tint, a alpha multiplier

out DataVS {
	vec2 texCoords;
	vec4 particleColor;
	float animFrame;
	float rowVariant;
	flat float ptype;
};

void main() {
	float currentFrame = timeInfo.x + timeInfo.w;
	float age = currentFrame - worldPos.w;
	float life = velLife.w;
	float t = clamp(age / life, 0.0, 1.0);

	// Cull expired / not yet born
	if (t >= 1.0 || age < 0.0) {
		gl_Position = vec4(-9999.0);
		particleColor = vec4(0.0);
		texCoords = vec2(0.0);
		animFrame = 0.0;
		rowVariant = 0.0;
		ptype = 0.0;
		return;
	}

	float type = sizeData.y;
	float seed = sizeData.z;
	float baseSize = sizeData.x;

	// Position: explicit drag-integrated forward motion
	float drag = exp(age * -0.12);
	float dragFactor = (1.0 - drag) * 8.333; // 1 / 0.12
	vec3 pos = worldPos.xyz + velLife.xyz * dragFactor;

	// Per-type vertical buoyancy (none for jet).
	// Flame uses t*t (normalized against per-particle lifetime) so the
	// end-of-life rise is uniform across weapons -- otherwise long-range
	// weapons like cormaw (lifeMult up to 4x) would rise up to 16x more
	// (rise scales with life^2 when integrating constant acceleration).
	// Smoke keeps age*age because smoke lifetime isn't weapon-scaled.
	if (type < 0.5) {
		pos.y += FLAME_BUOY * t * t;
	} else if (type < 1.5) {
		pos.y += SMOKE_BUOY * age * age;
	}
	// type == 3 (jet): no buoyancy/gravity, follows velocity only -- clean trail

	// Wind drift (smoke much more affected than flame; jet ignores wind)
	if (type < 2.5) {
		float windMult = (type < 1.5) ? WIND_FLAME_MULT : WIND_SMOKE_MULT;
		pos.x += windVelocity.x * age * windMult;
		pos.z += windVelocity.z * age * windMult;
	}

	// Turbulence: grows with age, scaled by type. Jet uses small fixed amplitude.
	float wobAmp;
	if (type > 2.5) {
		wobAmp = JET_WOBBLE;
	} else {
		float wobMax = (type < 0.5) ? WOBBLE_MAX
					 : ((type < 1.5) ? SMOKE_WOBBLE : WOBBLE_MAX * 0.6);
		wobAmp = mix(WOBBLE_MIN, wobMax, t);
	}
	float ph = seed * 6.283185;
	pos.x += sin(age * 0.11 + ph * 2.7) * wobAmp;
	pos.z += cos(age * 0.09 + ph * 3.8) * wobAmp;
	pos.y += sin(age * 0.07 + ph * 1.7) * wobAmp * 0.35;

	// Size growth varies by type
	float growth;
	if (type < 0.5) growth = CORE_GROWTH;
	else if (type < 1.5) growth = SMOKE_GROWTH;
	else growth = JET_GROWTH;
	float curve = t * (1.0 + t * 0.6);
	float size = baseSize * (1.0 + curve * growth);

	// Billboard
	vec3 camRight = cameraViewInv[0].xyz;
	vec3 camUp    = cameraViewInv[1].xyz;

	vec3 off;
	if (type > 2.5) {
		// Jet: velocity-aligned stretched billboard. The long axis follows the
		// projectile velocity in world space; the short (width) axis is the
		// in-screen perpendicular. This lets one jet quad cover the screen-space
		// span of ~JET_STRETCH round particles, so the stream reads as a continuous
		// streak rather than a dotted line and we save on per-frame jet count.
		vec3 vDir = velLife.xyz;
		float vLen = length(vDir);
		vec3 camFwd = cameraViewInv[2].xyz;
		vec3 crossAxis = (vLen > 0.001) ? cross(vDir / vLen, camFwd) : vec3(0.0);
		float cLen = length(crossAxis);
		if (vLen > 0.001 && cLen > 0.001) {
			vec3 longAxis = vDir / vLen;
			crossAxis = crossAxis / cLen;
			off = longAxis  * position_xy_uv.y * (size * JET_STRETCH)
			    + crossAxis * position_xy_uv.x * size;
		} else {
			// Velocity ~zero or pointing straight at the camera: fall back to
			// camera-aligned so the particle is still visible (no degenerate quad).
			off = (camRight * position_xy_uv.x + camUp * position_xy_uv.y) * size;
		}
	} else {
		float rotSpeed = (seed - 0.5) * 0.8;
		float rot = sizeData.w + age * rotSpeed * 0.02;
		float cr = cos(rot);
		float sr = sin(rot);
		vec3 rR = camRight * cr + camUp * sr;
		vec3 rU = -camRight * sr + camUp * cr;
		off = (rR * position_xy_uv.x + rU * position_xy_uv.y) * size;
	}

	gl_Position = cameraViewProj * vec4(pos + off, 1.0);
	texCoords = position_xy_uv.zw;
	ptype = type;

	// Per-particle color
	vec3 col = tintAlpha.rgb;

	// Alpha curve: ease-in (quick rise), long mid, soft fade-out.
	// Jet uses a faster ease-in and earlier fade-out for a crisp leading streak.
	float aIn, aOut;
	if (type > 2.5) {
		aIn  = clamp(t * 12.0, 0.0, 1.0);
		aOut = 1.0 - smoothstep(0.35, 1.0, t);
	} else {
		aIn  = clamp(t * 8.0, 0.0, 1.0);
		aOut = 1.0 - smoothstep(0.55, 1.0, t);
	}
	float a = tintAlpha.a * aIn * aOut;

	particleColor = vec4(col, a);

	// Animation atlas frame selection
	if (type < 1.5) {
		// fire atlas (16 cols x 6 rows)
		animFrame = floor(t * 15.0 + 0.5);
		rowVariant = floor(seed * 6.0);
	} else {
		// smoke atlas (8 cols x 8 rows)
		float rawFrame = age * 0.13 + seed * 8.0;
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
	flat float ptype;
};

out vec4 fragColor;

void main() {
	if (particleColor.a <= 0.001) discard;

	vec4 texSample;
	vec3 color;
	float a;

	if (ptype > 2.5) {
		// Nozzle jet: smooth procedural radial disc, no texture sample.
		// Quadratic falloff with an inner hotspot for a clean glowing streak.
		vec2 d = texCoords - vec2(0.5);
		float r2 = dot(d, d) * 4.0;        // 0 at center, 1 at edge
		float core = exp(-r2 * 4.0);        // tight bright core
		float halo = exp(-r2 * 1.6) * 0.45; // soft halo
		float shape = core + halo;
		// hot white inner hint blends into the configured jet color outward
		vec3 hot = mix(particleColor.rgb, vec3(0.97, 0.99, 1.00), core * 0.65);
		color = hot;
		a = shape * particleColor.a;
	} else if (ptype < 1.5) {
		// fire / drip
		vec2 uv = vec2(
			(animFrame + texCoords.x) * 0.0625,
			(clamp(rowVariant, 0.0, 5.0) + texCoords.y) * 0.16667
		);
		texSample = texture(fireTex, uv);

		color = particleColor.rgb * texSample.rgb;
		// Inner glow boost: brighter core
		float coreBright = texSample.r * texSample.r;
		color += coreBright * particleColor.rgb * 0.6;
		a = texSample.a * particleColor.a;
	} else {
		vec2 uv = vec2(
			(animFrame + texCoords.x) * 0.125,
			(clamp(rowVariant, 0.0, 7.0) + texCoords.y) * 0.125
		);
		texSample = texture(smokeTex, uv);
		color = particleColor.rgb * texSample.rgb;
		a = texSample.a * particleColor.a;
	}

	// Premultiplied additive-friendly output
	fragColor = vec4(color * a, a);
	if (fragColor.a < 0.004) discard;
}
]]

--------------------------------------------------------------------------------
-- GL state
--------------------------------------------------------------------------------
local fireTexture  = "bitmaps/projectiletextures/BARFlame02.tga"
local smokeTexture = "bitmaps/projectiletextures/smoke-beh-anim.tga"

local particleVBO    = nil
local particleShader = nil
local nextParticleID = 0

local particleRemoveQueue = {}    -- [deathFrame] = { id, id, ... }
local lastRemovedFrame    = 0

-- Free list of recyclable particleRemoveQueue arrays. Under heavy load each
-- distinct deathFrame previously allocated a fresh table that became garbage
-- when drained -- roughly one fresh table per frame * (unique death-frames
-- per spawn batch). Pooling them eliminates that churn and the resulting GC
-- spikes. Each pooled table stores its current logical length in slot `n`
-- (so spawnParticle can append in O(1) without `#q`) and clears its array
-- region back to nil on release so we don't keep stale ids reachable.
local removeQueuePool   = {}
local removeQueuePoolN  = 0
local REMOVE_QUEUE_POOL_MAX = 256  -- bounded so we don't hoard tables forever

local cachedGameFrame = 0
local cachedCamX, cachedCamY, cachedCamZ = 0, 0, 0
local windX, windZ = 0, 0
local cachedAllyTeamID = -1
local cachedFullView = false

local LOD_DIST_NEAR_SQ  = CONFIG.lodDistNear * CONFIG.lodDistNear
local LOD_DIST_FAR_SQ   = CONFIG.lodDistFar * CONFIG.lodDistFar
local LOD_DIST_CULL_SQ  = CONFIG.lodDistCull * CONFIG.lodDistCull
local LOD_DIST_RANGE_INV_SQ = 1 / mathMax(1, LOD_DIST_FAR_SQ - LOD_DIST_NEAR_SQ)
local LOD_MULT_RANGE    = 1 - CONFIG.lodMinMult
local CULL_RADIUS       = CONFIG.cullingPad + 80
local LOS_CACHE_INTERVAL = CONFIG.losCacheInterval
local STALE_GC_INTERVAL  = CONFIG.staleGcInterval
-- Short reuse window for *visible* LOS verdicts. Trades a tiny fog-leak window
-- (visible particles linger this many extra frames after sudden LOS loss) for
-- a ~3x reduction in spIsPosInLos calls on every visible-enemy flame stream.
local LOS_VISIBLE_CACHE_INTERVAL    = 3
-- Reuse window for the friendly ally fast-path verdict. Friendly shooters
-- don't teleport, so a 15-frame (~0.5s) cache is invisible in practice and
-- skips a Spring.GetUnitPosition call per friendly flame projectile per frame.
local ALLY_FASTPATH_CACHE_INTERVAL  = 15

--------------------------------------------------------------------------------
-- Hot-path constants bundled into a SINGLE local table.
-- IMPORTANT: do NOT promote these to individual `local FOO = ...` upvalues.
-- Lua 5.1 has a hard limit of 60 upvalues per function. emitStream() already
-- closes over many helpers (math.*, spawnParticle, sampleTint, particleVBO,
-- LOD constants, etc.) and previously crashed on load with
--   "function at line N has more than 60 upvalues".
-- Bundling into one `K` table keeps the closure at a single upvalue while
-- still being just as fast as the original `CONFIG.foo` (same hash lookup).
-- If you need a new constant, ADD A FIELD TO K -- never a new `local`.
--------------------------------------------------------------------------------
local K = {
	MAX_PARTICLES        = CONFIG.maxParticles,
	-- Absolute wall: only tier-3 essential cores may push past MAX_PARTICLES,
	-- and even they stop at this value. Sized so a few hundred tracked
	-- projectiles can each get their 1 core/frame for a few frames before
	-- expirations claw the pool back below the soft cap.
	HARD_MAX_PARTICLES   = mathFloor(CONFIG.maxParticles * (1 + (CONFIG.essentialOverflowFrac or 0))),
	LOS_CULL_ENABLED     = CONFIG.losCullingEnabled,
	LOD_MIN_MULT         = CONFIG.lodMinMult,

	-- Absolute particle counts at which each budget tier engages (precomputed
	-- from maxParticles * budget*Frac so emitStream just does an integer compare).
	BUDGET_SOFT          = mathFloor(CONFIG.maxParticles * CONFIG.budgetSoftFrac),
	BUDGET_MEDIUM        = mathFloor(CONFIG.maxParticles * CONFIG.budgetMediumFrac),
	BUDGET_HARD          = mathFloor(CONFIG.maxParticles * CONFIG.budgetHardFrac),

	CORE_SPAWN_PF        = CONFIG.coreSpawnPerFrame,
	JET_SPAWN_PF         = CONFIG.jetSpawnPerFrame,
	JET_MAX_LIFE_FRAC    = CONFIG.jetMaxLifeFrac,
	SMOKE_CHANCE         = CONFIG.smokeChance,
	SMOKE_CHANCE_HEAD    = CONFIG.smokeChanceHead,
	TAIL_EMIT_CHANCE     = CONFIG.tailEmitChance,
	BURST_MULT           = CONFIG.burstMultiplier,
	EMIT_OFFSET_FWD      = CONFIG.emitOffsetForward,

	MUZZLE_TAPER_MIN     = CONFIG.muzzleTaperMin,
	MUZZLE_TAPER_RANGE   = (CONFIG.muzzleTaperMax or 1.0) - (CONFIG.muzzleTaperMin or 0.25),

	CORE_SIZE_BASE       = CONFIG.coreSizeBase,
	SMOKE_SIZE_BASE      = CONFIG.smokeSizeBase,
	JET_SIZE_BASE        = CONFIG.jetSizeBase,
	SIZE_RAND_RANGE      = CONFIG.sizeRandRange,

	CORE_LIFE_MIN        = CONFIG.coreLifeMin,
	CORE_LIFE_MAX        = CONFIG.coreLifeMax,
	CORE_LIFE_SPAN       = CONFIG.coreLifeMax - CONFIG.coreLifeMin,
	SMOKE_LIFE_MIN       = CONFIG.smokeLifeMin,
	SMOKE_LIFE_SPAN      = CONFIG.smokeLifeMax - CONFIG.smokeLifeMin,
	JET_LIFE_MIN         = CONFIG.jetLifeMin,
	JET_LIFE_SPAN        = CONFIG.jetLifeMax - CONFIG.jetLifeMin,
	CORE_LIFE_APPLY_MULT = CONFIG.coreLifeApplyMult and true or false,

	VEL_FWD_MULT         = CONFIG.velocityForwardMult,
	VEL_FWD_RAND         = CONFIG.velocityForwardRand,
	VEL_RAND_TAN         = CONFIG.velocityRandTangent,
	JET_VEL_MULT         = CONFIG.jetVelocityMult,
	JET_SPREAD_MULT      = CONFIG.jetSpreadMult,

	SMOKE_UP_VEL_MIN     = CONFIG.smokeUpwardVelMin,
	SMOKE_UP_VEL_SPAN    = CONFIG.smokeUpwardVelMax - CONFIG.smokeUpwardVelMin,

	TINT_MICRO_JITTER    = CONFIG.tintMicroJitter,
	TINT_RGB_JITTER      = CONFIG.tintRGBJitter,

	CORE_ALPHA_BASE      = CONFIG.coreAlphaBase,
	SMOKE_ALPHA_BASE     = CONFIG.smokeAlphaBase,
	JET_ALPHA_BASE       = CONFIG.jetAlphaBase,

	SMOKE_TINT_R         = CONFIG.smokeTint[1],
	SMOKE_TINT_G         = CONFIG.smokeTint[2],
	SMOKE_TINT_B         = CONFIG.smokeTint[3],
	SMOKE_TINT_HEAD_R    = (CONFIG.smokeTintHead or CONFIG.smokeTint)[1],
	SMOKE_TINT_HEAD_G    = (CONFIG.smokeTintHead or CONFIG.smokeTint)[2],
	SMOKE_TINT_HEAD_B    = (CONFIG.smokeTintHead or CONFIG.smokeTint)[3],

	JET_R                = CONFIG.jetColor[1] * CONFIG.jetBrightness,
	JET_G                = CONFIG.jetColor[2] * CONFIG.jetBrightness,
	JET_B                = CONFIG.jetColor[3] * CONFIG.jetBrightness,

	SCAV_JET_R           = CONFIG.scavJetColor[1] * CONFIG.jetBrightness,
	SCAV_JET_G           = CONFIG.scavJetColor[2] * CONFIG.jetBrightness,
	SCAV_JET_B           = CONFIG.scavJetColor[3] * CONFIG.jetBrightness,
}

--------------------------------------------------------------------------------
-- Init / cleanup
--------------------------------------------------------------------------------
local function goodbye(reason)
	spEcho("[Flamethrower GL4] removing: " .. reason)
	gadgetHandler:RemoveGadget()
end

local function initGL4()
	local shaderSource = {
		vsSrc       = vsSrc,
		fsSrc       = fsSrc,
		shaderName  = "FlamethrowerGL4",
		uniformInt  = { fireTex = 0, smokeTex = 1 },
		uniformFloat = {},
		shaderConfig = {
			FLAME_BUOY      = CONFIG.flameBuoyancy,
			SMOKE_BUOY      = CONFIG.smokeBuoyancy,
			WIND_FLAME_MULT = CONFIG.windFlameMult,
			WIND_SMOKE_MULT = CONFIG.windSmokeMult,
			WOBBLE_MIN      = CONFIG.wobbleAmpMin,
			WOBBLE_MAX      = CONFIG.wobbleAmpMax,
			SMOKE_WOBBLE    = CONFIG.smokeWobbleAmp,
			JET_WOBBLE      = CONFIG.jetWobble,
			CORE_GROWTH     = CONFIG.coreGrowthMult,
			SMOKE_GROWTH    = CONFIG.smokeGrowthMult,
			JET_GROWTH      = CONFIG.jetGrowthMult,
			JET_STRETCH     = CONFIG.jetStretchMult,
		},
		forceupdate = true,
	}

	particleShader = LuaShader.CheckShaderUpdates(shaderSource)
	if not particleShader then
		goodbye("shader compile failed")
		return false
	end

	local quadVBO, numVertices = gl.InstanceVBOTable.makeRectVBO(
		-1, -1, 1, 1,
		0, 0, 1, 1,
		"flameQuadVBO"
	)

	local layout = {
		{ id = 1, name = "worldPos",  size = 4 },
		{ id = 2, name = "velLife",   size = 4 },
		{ id = 3, name = "sizeData",  size = 4 },
		{ id = 4, name = "tintAlpha", size = 4 },
	}

	particleVBO = gl.InstanceVBOTable.makeInstanceVBOTable(
		layout, CONFIG.maxParticles, "flameParticleVBO"
	)
	if not particleVBO then
		goodbye("VBO creation failed")
		return false
	end

	particleVBO.numVertices    = numVertices
	particleVBO.vertexVBO      = quadVBO
	particleVBO.VAO            = particleVBO:makeVAOandAttach(quadVBO, particleVBO.instanceVBO)
	particleVBO.primitiveType  = GL.TRIANGLES

	local indexVBO = gl.InstanceVBOTable.makeRectIndexVBO("flameIndexVBO")
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
-- Tint LUT lookup (Lua side: used when we don't want to push to GPU as uniform)
-- Pre-multiplied by CONFIG.tintBrightness so sampleTint can return directly
-- without 3 extra multiplies per call.
--------------------------------------------------------------------------------
local tintR, tintG, tintB = {}, {}, {}
local scavTintR, scavTintG, scavTintB = {}, {}, {}
local function bakeTintLut(stops, outR, outG, outB)
	local bri = CONFIG.tintBrightness
	for i = 0, TINT_LUT_SIZE - 1 do
		local t = i / (TINT_LUT_SIZE - 1)
		local a, b = stops[1], stops[#stops]
		for j = 1, #stops - 1 do
			if t >= stops[j][1] and t <= stops[j + 1][1] then
				a, b = stops[j], stops[j + 1]
				break
			end
		end
		local span = b[1] - a[1]
		local k = span > 0 and (t - a[1]) / span or 0
		outR[i + 1] = (a[2] + (b[2] - a[2]) * k) * bri
		outG[i + 1] = (a[3] + (b[3] - a[3]) * k) * bri
		outB[i + 1] = (a[4] + (b[4] - a[4]) * k) * bri
	end
end
bakeTintLut(CONFIG.tintStops,     tintR,     tintG,     tintB)
bakeTintLut(CONFIG.scavTintStops, scavTintR, scavTintG, scavTintB)
-- silence unused
local _ = buildTintLut

local function sampleTint(t)
	if t < 0 then t = 0 elseif t > 1 then t = 1 end
	local f = t * (TINT_LUT_SIZE - 1)
	local i = mathFloor(f)
	local k = f - i
	local i1, i2 = i + 1, i + 2
	if i2 > TINT_LUT_SIZE then i2 = TINT_LUT_SIZE end
	local r1, g1, b1 = tintR[i1], tintG[i1], tintB[i1]
	return r1 + (tintR[i2] - r1) * k,
	       g1 + (tintG[i2] - g1) * k,
	       b1 + (tintB[i2] - b1) * k
end

local function sampleScavTint(t)
	if t < 0 then t = 0 elseif t > 1 then t = 1 end
	local f = t * (TINT_LUT_SIZE - 1)
	local i = mathFloor(f)
	local k = f - i
	local i1, i2 = i + 1, i + 2
	if i2 > TINT_LUT_SIZE then i2 = TINT_LUT_SIZE end
	local r1, g1, b1 = scavTintR[i1], scavTintG[i1], scavTintB[i1]
	return r1 + (scavTintR[i2] - r1) * k,
	       g1 + (scavTintG[i2] - g1) * k,
	       b1 + (scavTintB[i2] - b1) * k
end

--------------------------------------------------------------------------------
-- Particle spawn
--------------------------------------------------------------------------------
local particleData = { 0,0,0,0, 0,0,0,0, 0,0,0,0, 1,1,1,1 }


-- Set by emitStream before spawning so spawnParticle can attribute each new
-- particle to its owning projectile (for bulk-kill on LOS loss). Reset to nil
-- by emitStream on early-returns / end so unrelated future spawns can't leak
-- into a stale tracked entry.
local emitInfoRef = nil

local function spawnParticle(px, py, pz, vx, vy, vz, size, ptype, life, r, g, b, alpha, essential)
	-- Core flame particles (ptype 0) are NEVER capped: with many flamethrowers
	-- active the soft/hard caps would starve late-iterated streams of any
	-- particles at all (the "some flamethrowers invisible" symptom). The VBO
	-- auto-resizes on overflow (instancevbotable doubles maxElements when full),
	-- so pushing past CONFIG.maxParticles is safe -- the cap here is a budget
	-- throttle, not a hardware limit. Non-core decorations (jet/tail/smoke) still
	-- respect the soft cap to keep total cost bounded.
	if ptype ~= 0 and not essential and particleVBO.usedElements >= K.MAX_PARTICLES then
		return nil
	end
	local deathFrame = cachedGameFrame + mathCeil(life) + 2

	particleData[1] = px
	particleData[2] = py
	particleData[3] = pz
	particleData[4] = cachedGameFrame
	particleData[5] = vx
	particleData[6] = vy
	particleData[7] = vz
	particleData[8] = life
	particleData[9] = size
	particleData[10] = ptype
	particleData[11] = mathRandom()
	particleData[12] = (mathRandom() * 2 - 1) * mathPi
	particleData[13] = r
	particleData[14] = g
	particleData[15] = b
	particleData[16] = alpha

	-- Advance nextParticleID, wrapping safely below 2^24. Spring's unsynced
	-- Lua uses float32 for lua_Number (to match GPU buffers), so integer
	-- arithmetic loses precision at 2^24 (16777216): `x + 1 == x`. If we let
	-- nextParticleID hit that ceiling it freezes forever, every spawn reuses
	-- the same ID, pushElementInstance takes the updateExisting path on slot
	-- 0, and the entire particle effect disappears. This was the long-run
	-- "leak" observed after ~30 min of continuous flame.
	--
	-- We wrap well below the float ceiling (2^23 = 8388608) and on collision
	-- with a still-live ID just keep incrementing. With <=10k live particles
	-- in 8M slots the average collision rate is ~0.1%.
	local nid = nextParticleID + 1
	if nid >= 8388608 then nid = 1 end
	local idToIndex = particleVBO.instanceIDtoIndex
	while idToIndex[nid] do
		nid = nid + 1
		if nid >= 8388608 then nid = 1 end
	end
	nextParticleID = nid
	local id = nid
	-- Per-element upload: only transmits this one slot (16 floats) to GPU.
	-- Tried noUpload=true + uploadAllElements() once per frame, but that
	-- uploads the ENTIRE used range every frame (~2-4k particles), which
	-- transmits far more bytes per frame than the per-element path even
	-- though it uses fewer GL calls. Net regression in profiling.
	-- Also tried noUpload=true + uploadElementRange over a tracked
	-- [dirtyMin, dirtyMax] span: looked promising on paper but regressed
	-- ~33% in practice because particles die FIFO (low indices) while new
	-- spawns push at the tail, so the dirty span covers essentially the
	-- full used range every frame -- same trap as uploadAllElements, plus
	-- extra Lua bookkeeping. Per-element upload wins.
	pushElementInstance(particleVBO, particleData, id, true)

	local q = particleRemoveQueue[deathFrame]
	if not q then
		-- Recycle a pooled table if available; otherwise allocate (rare once
		-- steady state is reached).
		if removeQueuePoolN > 0 then
			q = removeQueuePool[removeQueuePoolN]
			removeQueuePool[removeQueuePoolN] = nil
			removeQueuePoolN = removeQueuePoolN - 1
		else
			q = { n = 0 }
		end
		particleRemoveQueue[deathFrame] = q
	end
	local qn = q.n + 1
	q[qn] = id
	q.n   = qn

	-- Attribute this particle to the currently-emitting projectile, so we can
	-- pop it early if/when that projectile loses LOS. Skipped when
	-- info.noKillNeeded is set (spectator full-view or ally fast-path -- those
	-- paths can never call killProjectileParticles, so the list would just be
	-- dead weight: a hash lookup + table push per particle for nothing).
	if emitInfoRef and not emitInfoRef.noKillNeeded then
		local plist = emitInfoRef.particles
		if not plist then plist = {}; emitInfoRef.particles = plist end
		local n = #plist
		-- Cap list growth: old entries point to particles that are likely
		-- already gone (natural expiry), and even if some are still alive
		-- they're near end-of-life. Dropping the oldest 50% is harmless.
		if n >= 1024 then
			for i = 1, 512 do plist[i] = plist[i + 512] end
			for i = 513, 1024 do plist[i] = nil end
			n = 512
		end
		plist[n + 1] = id
	end
	return id
end

local function removeExpiredParticles(gameFrame)
	local startFrame = lastRemovedFrame + 1
	if gameFrame - startFrame > 600 then
		for f = startFrame, gameFrame - 601 do particleRemoveQueue[f] = nil end
		startFrame = gameFrame - 600
	end
	for f = startFrame, gameFrame do
		local q = particleRemoveQueue[f]
		if q then
			local idToIndex = particleVBO.instanceIDtoIndex
			local qn = q.n
			for i = 1, qn do
				local id = q[i]
				if idToIndex[id] then
					popElementInstance(particleVBO, id)
				end
				q[i] = nil  -- drop reference so id values can be GC'd
			end
			q.n = 0
			particleRemoveQueue[f] = nil
			-- Return the now-empty table to the pool for re-use instead of
			-- letting it become garbage. Bounded to keep memory predictable.
			if removeQueuePoolN < REMOVE_QUEUE_POOL_MAX then
				removeQueuePoolN = removeQueuePoolN + 1
				removeQueuePool[removeQueuePoolN] = q
			end
		end
	end
	lastRemovedFrame = gameFrame
end

--------------------------------------------------------------------------------
-- Projectile tracking
--------------------------------------------------------------------------------
local tracked = {}      -- [proID] = { wcfg, birthFrame, gen }
local ignored = {}      -- [proID] = lastSeenGen  (negative cache: non-flame projectiles)
local trackGen = 0

-- LOS visibility test with per-projectile caching. Asymmetric on purpose:
--   * "hidden" result is cached for LOS_CACHE_INTERVAL frames -- this is the
--     common case (many enemy projectiles in distant fog) and the one where
--     repeated spIsPosInLos calls actually hurt.
--   * "visible" result is NEVER cached: we re-check every frame so that a
--     projectile losing LOS (the unit hiding behind terrain, scout dying,
--     etc.) stops emitting on the very next frame instead of leaking up to
--     LOS_CACHE_INTERVAL frames of visible particles into fog of war.
-- This is still much cheaper than the previous always-call version because
-- the only projectiles that pay the per-frame cost are the ones the local
-- player can currently see anyway.
-- Forcibly remove every particle this projectile has spawned that's still
-- alive in the VBO. Called the instant the projectile loses LOS, so the
-- trail/puff disappears with it instead of lingering in fog for the rest of
-- the particles' natural lifetimes (up to ~2s of orange flame in fog --
-- exactly the symptom we kept seeing).
local function killProjectileParticles(info)
	local list = info.particles
	if not list then return end
	local idToIndex = particleVBO.instanceIDtoIndex
	for i = 1, #list do
		local id = list[i]
		if idToIndex[id] then popElementInstance(particleVBO, id) end
		list[i] = nil
	end
end

local function visibleToLocalPlayer(proID, info, px, py, pz, dirX, dirY, dirZ, speed, ownerAllyTeam, gameFrame)
	if cachedFullView then
		info.noKillNeeded = true
		return true, true
	end
	-- IMPORTANT: in UNSYNCED, Spring.GetProjectileTeamID and GetProjectileOwnerID
	-- return *spoofed* values for hidden enemy projectiles (engine reports
	-- local player's team and aliases ownerID to some real friendly unit).
	-- A naive ownerAllyTeam == myAllyTeam shortcut therefore waves enemy
	-- flame straight through.
	--
	-- Discriminator: a real friendly projectile is always within flame-weapon
	-- range of its actual shooter. An engine-spoofed enemy projectile has its
	-- ownerID aliased to some random friendly unit elsewhere on the map -- so
	-- comparing projectile position to the claimed owner's position reliably
	-- tells genuine from spoofed.
	local ownerID = info.ownerID
	if ownerID and ownerAllyTeam == cachedAllyTeamID then
		-- Cache the ally fast-path verdict for ALLY_CACHE_INTERVAL frames.
		-- Friendly projectiles overwhelmingly keep passing this check (their
		-- shooter doesn't teleport), so re-running GetUnitPosition every frame
		-- for every friendly flame is pure waste in big games.
		if info.allyFastPathFrame and (gameFrame - info.allyFastPathFrame) < ALLY_FASTPATH_CACHE_INTERVAL then
			info.noKillNeeded = true
			return true, true
		end
		local ox, oy, oz = spGetUnitPosition(ownerID)
		if ox then
			local dx, dy, dz = px - ox, py - oy, pz - oz
			-- Flame weapons cap around 300 elmo range; 500 gives generous
			-- headroom for projectile-in-flight + LOS slack.
			if dx * dx + dy * dy + dz * dz < 250000 then
				info.allyFastPathFrame = gameFrame
				info.noKillNeeded = true
				return true, true
			end
		end
	end
	if not K.LOS_CULL_ENABLED then return true, true end
	-- Reuse a recent *hidden* result only.
	if info.losHiddenFrame and (gameFrame - info.losHiddenFrame) < LOS_CACHE_INTERVAL then
		return false, false
	end
	-- Reuse a recent *visible* result for a SHORT window. Trades up to
	-- LOS_VISIBLE_CACHE_INTERVAL frames of fog leak on sudden LOS loss for a
	-- 3x reduction in spIsPosInLos calls on every visible-enemy flame stream.
	if info.losVisibleFrame and (gameFrame - info.losVisibleFrame) < LOS_VISIBLE_CACHE_INTERVAL then
		return true, info.losSmokeCached or false
	end
	-- Layered position-only visibility test. The engine spoofs team and
	-- ownerID for hidden enemy projectiles, so unit-based gates are
	-- unreliable; projectile position is honest.
	--   1) Head position in LOS -- kills hidden-enemy fire.
	--   2) Near-forward sample (head + dir * max(jet/core life) * speed) --
	--      stops sighted enemies from painting fire downrange into fog.
	--   3) (smoke only) Far-forward sample at ~half max smoke travel.
	--      Smoke lives 70-140f and drifts ~1k+ elmos; needs its own gate.
	local vis, smokeVis = false, false
	if spIsPosInLos(px, py, pz, cachedAllyTeamID) then
		local nearAhead = mathMax(64, K.CORE_LIFE_MAX * speed)
		if spIsPosInLos(px + dirX * nearAhead, py + dirY * nearAhead, pz + dirZ * nearAhead, cachedAllyTeamID) then
			vis = true
			if speed > 0.5 then
				local farAhead = (K.SMOKE_LIFE_MIN + K.SMOKE_LIFE_SPAN) * speed * 0.5
				if spIsPosInLos(px + dirX * farAhead, py + dirY * farAhead, pz + dirZ * farAhead, cachedAllyTeamID) then
					smokeVis = true
				end
			else
				smokeVis = true
			end
		end
	end
	if vis then
		info.losHiddenFrame   = nil
		info.losVisibleFrame  = gameFrame
		info.losSmokeCached   = smokeVis
	else
		-- Transition visible -> hidden: nuke any particles already in flight,
		-- otherwise they'd render in fog until they expire naturally.
		if not info.losHiddenFrame then killProjectileParticles(info) end
		info.losHiddenFrame = gameFrame
	end
	return vis, smokeVis
end

-- Paused-snapshot emit gating: set by gadget:Update during a paused emit
-- pass, read by emitStream to skip streams already emitted this pause.
-- pauseBurstEmitted is reset at the start of each paused emit burst so the
-- multi-pass densification loop can call emitStream multiple times for the
-- same projectile within one burst; pauseEmittedFor is updated from it at
-- the end of the burst so future bursts (camera-move re-emits) still skip
-- streams we've already snapshotted.
local pauseEmittedFor = {}
local pauseBurstEmitted = {}
local pausedEmitMode = false

local function emitStream(proID, info, gameFrame, throttleMult)
	emitInfoRef = nil
	-- Pause re-emit gate: during a paused snapshot burst, skip streams that
	-- were already snapshotted by a *previous* burst (or that were visible
	-- at pause time, seeded in pauseEmittedFor by gadget:Update).
	-- pauseBurstEmitted records per-burst emissions so the multi-pass
	-- densification within one burst is allowed.
	if pausedEmitMode then
		if pauseEmittedFor[proID] then return end
		pauseBurstEmitted[proID] = true
	end
	-- No early-exit on pool fullness: cores (ptype 0) are uncapped in
	-- spawnParticle so the stream always emits something even under heavy
	-- many-flamethrower load. spawnParticle's per-call gate still rejects
	-- non-core decorations past MAX_PARTICLES, so total cost stays bounded.

	-- Per-projectile color scalars. For scavenger-owned flamers we swap the
	-- jet color outright (blue -> magenta-purple) and route the core/tail
	-- spawn color sampling through the parallel pink-purple LUT instead of
	-- the yellow/orange one. Selecting the sampler function once here keeps
	-- the hot per-particle path branch-free.
	local jetR, jetG, jetB
	local tintSampler
	if info.isScav then
		jetR, jetG, jetB = K.SCAV_JET_R, K.SCAV_JET_G, K.SCAV_JET_B
		tintSampler = sampleScavTint
	else
		jetR, jetG, jetB = K.JET_R, K.JET_G, K.JET_B
		tintSampler = sampleTint
	end

	local px, py, pz = spGetProjectilePosition(proID)
	if not px then return end

	-- Hard distance cull: at extreme camera distance the stream is well below
	-- a pixel; skip ALL per-projectile work (emit, LOS, frustum, particle math).
	local _dx = px - cachedCamX
	local _dy = py - cachedCamY
	local _dz = pz - cachedCamZ
	if (_dx*_dx + _dy*_dy + _dz*_dz) > LOD_DIST_CULL_SQ then return end

	-- Budget tier: 0=normal, 1=soft (drop smoke), 2=medium (also thin jet/core),
	-- 3=hard (essentials only -- one core/frame). Sampled per projectile rather
	-- than once-per-frame so a burst of spawns inside a single GameFrame degrades
	-- gracefully as the pool fills up.
	local used = particleVBO.usedElements
	local budgetTier = 0
	if used >= K.BUDGET_HARD then       budgetTier = 3
	elseif used >= K.BUDGET_MEDIUM then budgetTier = 2
	elseif used >= K.BUDGET_SOFT then   budgetTier = 1
	end
	-- Paused snapshot ignores tier-based thinning: a one-shot static fill
	-- isn't subject to per-frame budget pressure, and we want cores everywhere.
	if pausedEmitMode then budgetTier = 0 end

	-- View frustum cull
	if not spIsSphereInView(px, py, pz, CULL_RADIUS) then return end

	-- Velocity fetched here (instead of post-LOS) because the LOS gate needs
	-- the projectile's forward direction to do a downrange-trajectory sample
	-- ("is the spot where my particles will drift to in LOS?").
	local vx, vy, vz = spGetProjectileVelocity(proID)
	vx = vx or 0; vy = vy or 0; vz = vz or 0
	local speed = mathSqrt(vx * vx + vy * vy + vz * vz)
	local invSpeed = speed > 0.001 and (1 / speed) or 0
	local dirX, dirY, dirZ = vx * invSpeed, vy * invSpeed, vz * invSpeed

	-- LOS / spectator cull (cached per projectile, refreshed every LOS_CACHE_INTERVAL frames)
	local losVis, losSmokeVis = visibleToLocalPlayer(proID, info, px, py, pz, dirX, dirY, dirZ, speed, info.ownerAllyTeam, gameFrame)
	if not losVis then return end

	-- Past all culls -- attribute any particles spawned below to this projectile.
	emitInfoRef = info

	local cfg = info.cfg
	local age = gameFrame - info.birthFrame
	local lifeT = mathMin(1, age / cfg.expectedLife)

	-- World-space distance from this projectile's emit point (turret muzzle).
	-- This drives the size taper so particles get bigger the further they are
	-- from where the weapon was actually fired -- independent of projectile age.
	-- We keep this in *squared* form to avoid a per-projectile-per-frame sqrt.
	local dxe = px - info.emitX
	local dye = py - info.emitY
	local dze = pz - info.emitZ
	local distFromEmitSq = dxe * dxe + dye * dye + dze * dze

	-- Position-based proID recycle detector. Spring reuses dead projectile IDs;
	-- under heavy flamethrower fire a recycled ID for a fresh same-weapon shot
	-- slips past the wDefID + age recycle checks in updateProjectiles when the
	-- old projectile died within ~1.5x expectedLife of the new one being fired.
	-- The new projectile then inherits the previous shot's stale info.emitX/Y/Z
	-- and birthFrame, so on its very first emit distFromEmitSq is enormous
	-- (muzzleTaper clamps to MAX -> full-size cores) and lifeT is already
	-- saturated (tintSampler returns orange/red) -- the visible "large orange
	-- chunks at the muzzle from frame one" artifact. A real projectile cannot
	-- physically travel more than ~range elmos from its emit point, so if we
	-- see distFromEmitSq exceed (range * 1.5)^2 it MUST be a recycle. Reset
	-- birthFrame and emitX/Y/Z to the current projectile state and skip this
	-- frame's emit -- next frame will spawn a correct fresh muzzle stream.
	-- Use 1.5x range (not 1.0x) as a tolerance band for AoE / drift / midFlight
	-- owner-position emit overrides, none of which should legitimately push
	-- distFromEmit beyond 1.5x weapon range.
	if (distFromEmitSq * cfg.invRangeSq) > 2.25 then
		info.birthFrame        = gameFrame
		info.emitX             = px
		info.emitY             = py
		info.emitZ             = pz
		info.midFlightAcquired = false
		emitInfoRef = nil
		return
	end

	-- distT^2 = clamp01( distSq / rangeSq ). cfg.invRangeSq is precomputed.
	local distT2 = distFromEmitSq * cfg.invRangeSq
	if distT2 > 1 then distT2 = 1 end

	-- Distance LOD (squared-distance compare to avoid sqrt per projectile per frame)
	local dx, dy, dz = px - cachedCamX, py - cachedCamY, pz - cachedCamZ
	local distSq = dx * dx + dy * dy + dz * dz
	local lodMult = 1
	if distSq > LOD_DIST_FAR_SQ then
		lodMult = K.LOD_MIN_MULT
		-- At minimum LOD, only emit on every other frame (per-projectile parity
		-- via proID) so we halve the per-projectile cost when zoomed all the way
		-- out. Density stays roughly the same because particles live longer than
		-- 2 frames at any LOD. Skip the parity gate during paused mode: gameFrame
		-- is constant across all densification passes, so half of far-zoom streams
		-- would receive zero particles otherwise.
		if not pausedEmitMode and (gameFrame + proID) % 2 == 0 then return end
	elseif distSq > LOD_DIST_NEAR_SQ then
		local k = (distSq - LOD_DIST_NEAR_SQ) * LOD_DIST_RANGE_INV_SQ
		lodMult = 1 - k * LOD_MULT_RANGE
	end

	-- During paused emit, force full LOD density: skipping particles for
	-- distant streams (the normal LOD behaviour) makes far-zoom paused
	-- snapshots look anemic. CPU cost is irrelevant during pause.
	if pausedEmitMode then
		lodMult = 1
	end

	-- (velocity / dir already computed above for the LOS forward-lookahead.)

	-- Forward emit offset (so particles emerge slightly ahead of projectile)
	local emitOff = K.EMIT_OFFSET_FWD
	local epx = px + dirX * emitOff
	local epy = py + dirY * emitOff
	local epz = pz + dirZ * emitOff

	-- Two perpendicular axes for tangential spread.
	-- For up = (0,1,0): cross(dir, up) = (-dirZ, 0, dirX). Normalize against
	-- the horizontal length of dir. Fallback when projectile points straight up/down.
	local cLenSq = dirX * dirX + dirZ * dirZ
	local cx, cy, cz
	if cLenSq < 0.000001 then
		cx, cy, cz = 1, 0, 0
	else
		local invCLen = 1 / mathSqrt(cLenSq)
		cx = -dirZ * invCLen
		cy = 0
		cz =  dirX * invCLen
	end
	-- second perp = dir x crossDir
	local tx = dirY * cz - dirZ * cy
	local ty = dirZ * cx - dirX * cz
	local tz = dirX * cy - dirY * cx

	local sizeScale  = cfg.sizeScale
	local damageMult = cfg.damageMult
	local spreadOff  = cfg.spreadOffset
	local lifeMult   = cfg.lifeMult or 1.0
	local coreLifeM  = K.CORE_LIFE_APPLY_MULT and lifeMult or 1.0
	local randTan    = K.VEL_RAND_TAN
	local velFwdMult = K.VEL_FWD_MULT
	local velFwdRand = K.VEL_FWD_RAND

	local intensity = cfg.intensity
	-- throttleMult compensates for FPS-based update throttling: when the gadget
	-- only runs every Nth sim frame, we emit N frames' worth of particles in
	-- one burst so the visual density stays constant regardless of FPS.
	local burstMult = K.BURST_MULT * lodMult * damageMult * (throttleMult or 1.0)

	-- farMode: at large camera distance the small/short-lived particles
	-- (head smoke, tail chaos) become a single pixel of noise. Skip
	-- them entirely -- this is the biggest CPU win, removing random gates,
	-- many CONFIG lookups, and several spawnParticle calls per projectile.
	local farMode = lodMult < 0.55

	-- Core particle size taper, driven by *world-space distance from the
	-- turret muzzle*. Ramps from 0.15 (at the emit point) to 1.0 (at max
	-- weapon range) with a quadratic curve so growth is gentle near the
	-- muzzle and accelerates downrange. distT2 is already distT^2, which
	-- means we get the quadratic curve for free with no extra mult.
	-- Floor lowered from 0.30 -> 0.15 to make the stream visibly thinner at
	-- the nozzle and reserve the big painterly chunks for downrange.
	local muzzleTaper = K.MUZZLE_TAPER_MIN + K.MUZZLE_TAPER_RANGE * distT2

	-- Particle count keeps a floor of 1 so the stream is never empty, but
	-- size taper (above) handles visual smallness near the muzzle.
	local nCore = mathMax(1, mathFloor(K.CORE_SPAWN_PF * burstMult + 0.5))
	-- Budget-aware thinning of CORE flame (the essential trail particle):
	--   tier >= 3 : always exactly 1 (one chunk per projectile per frame)
	--   tier >= 2 : per-projectile parity gate -- emit cores every other frame
	if budgetTier >= 3 then
		nCore = 1
	elseif budgetTier >= 2 and ((gameFrame + proID) % 2) == 0 then
		nCore = 0
	end

	-- Mean per-particle velocity used by tail/smoke (full inheritance scaled below)
	local pvx = vx * velFwdMult
	local pvy = vy * velFwdMult
	local pvz = vz * velFwdMult

	-- Color tint at this position along the stream's life
	local tR, tG, tB = tintSampler(lifeT)

	---- Nozzle jet stream (smooth procedural blue, no texture sample) ----
	-- Only emit while we're in the early portion of the projectile's life
	-- so the blue jet hugs the nozzle / leading half of the stream and the
	-- fire/smoke takes over further along.
	--
	-- Historical note: we used to suppress jets entirely for midFlight-
	-- acquired projectiles, because birthFrame was set to "now" so lifeT
	-- started at 0 for the rest of the projectile's life, which spawned
	-- fresh muzzle jets at the projectile's current (far-from-origin)
	-- position; the jets inherit projectile velocity and the vertex-shader
	-- drag then drifted them downstream, producing the "particles way too
	-- far outside max range" artifact. We now backdate birthFrame from
	-- distance-to-owner / speed at acquisition time, so lifeT is correct
	-- from the first frame and this `lifeT < JET_MAX_LIFE_FRAC` gate
	-- alone is sufficient -- old midFlight projectiles will already be
	-- past their jet phase and get gated out here naturally, while young
	-- ones get to emit jets normally so the user sees a jet even when the
	-- camera framed the target end at the moment the weapon fired.
	if lifeT < K.JET_MAX_LIFE_FRAC and budgetTier < 3 then
		local jetCount = mathMax(1, mathFloor(K.JET_SPAWN_PF * burstMult + 0.5))
		-- Tier 2 : halve jet emission via per-projectile parity. floor=1 means
		-- the floor-1 mathMax above would otherwise still emit every frame; the
		-- parity gate gives an actual ~50% reduction.
		if budgetTier >= 2 and ((gameFrame + proID) % 2) == 1 then
			jetCount = 0
		end
		if jetCount > 0 then
		local jetSpread = K.JET_SPREAD_MULT
		-- Jet alpha fades along the stream, but with a floor so jets emitted
		-- in the later portion of the projectile's life (the only ones you
		-- ever see when the camera is framing the target end of the stream)
		-- are still clearly visible. Without the floor, jetAlpha goes linearly
		-- from JET_ALPHA_BASE at lifeT=0 to 0 at JET_MAX_LIFE_FRAC, so framing
		-- the target makes jets look washed out compared to framing the muzzle.
		-- A 0.55 floor keeps target-end jets readable without making the
		-- muzzle-end look any different (the freshest jets still get full alpha).
		local fadeT = lifeT / K.JET_MAX_LIFE_FRAC
		if fadeT > 1 then fadeT = 1 end
		local jetAlpha  = K.JET_ALPHA_BASE * (1 - 0.45 * fadeT)
		local invJetCount = 1 / jetCount

		for i = 1, jetCount do
			-- Very tight tangential offset (clean jet shape)
			local r1 = (mathRandom() * 2 - 1) * jetSpread * sizeScale
			local r2 = (mathRandom() * 2 - 1) * jetSpread * sizeScale
			local ox = cx * r1 + tx * r2
			local oy = cy * r1 + ty * r2
			local oz = cz * r1 + tz * r2

			-- Sub-frame interpolation so multiple jet particles spread along
			-- the projectile's path within a single frame (filling the stream
			-- continuously even when the projectile moves fast)
			local backStep = (i - 1) * invJetCount * speed
			ox = ox - dirX * backStep
			oy = oy - dirY * backStep
			oz = oz - dirZ * backStep

			local size = (K.JET_SIZE_BASE + (mathRandom() - 0.5) * K.SIZE_RAND_RANGE * 0.5) * sizeScale
			-- Zoom-out compensation: JET_SIZE_BASE is only ~1.3 elmos so the
			-- jet shrinks to sub-pixel when the camera is far. Boost up to
			-- ~2.05x at full LOD distance (lodMult=0.30) so the jet stays
			-- visually present when zoomed out without becoming a dominant
			-- beam -- changing the near-zoom appearance not at all
			-- (boost == 1 when lodMult == 1).
			size = size * (1 + 1.5 * (1 - lodMult))
			local life = K.JET_LIFE_MIN + mathRandom() * K.JET_LIFE_SPAN

			spawnParticle(
				epx + ox, epy + oy, epz + oz,
				vx * K.JET_VEL_MULT, vy * K.JET_VEL_MULT, vz * K.JET_VEL_MULT,
				size, 3, life,
				jetR, jetG, jetB,
				jetAlpha
			)
		end
		end -- if jetCount > 0
	end

	---- Core flame particles ----
	local tintMicro = K.TINT_MICRO_JITTER
	local tintJit   = K.TINT_RGB_JITTER
	for i = 1, nCore do
		-- Per-particle micro age offset to add variance along the stream.
		-- Wider jitter -> each chunk samples a different point on the LUT so
		-- the stream isn't a uniform colour at a given distance.
		local microT = lifeT + (mathRandom() - 0.5) * tintMicro
		if microT < 0 then microT = 0 elseif microT > 1 then microT = 1 end
		local pR, pG, pB = tintSampler(microT)
		-- Additional per-channel multiplicative jitter so two particles at the
		-- same microT still differ slightly in warmth/brightness.
		local jr = 1 + (mathRandom() - 0.5) * tintJit
		local jg = 1 + (mathRandom() - 0.5) * tintJit
		local jb = 1 + (mathRandom() - 0.5) * tintJit
		pR = pR * jr
		pG = pG * jg
		pB = pB * jb

		-- Random offset perpendicular to projectile path; grows with lifeT and spray
		local r1 = (mathRandom() * 2 - 1) * (spreadOff + 0.4 + lifeT * 1.4) * sizeScale
		local r2 = (mathRandom() * 2 - 1) * (spreadOff + 0.4 + lifeT * 1.4) * sizeScale
		local ox = cx * r1 + tx * r2
		local oy = cy * r1 + ty * r2
		local oz = cz * r1 + tz * r2

		-- Small backwards offset randomized along stream for organic look
		local back = (mathRandom() * 0.6 - 0.1) * speed * 0.02
		ox = ox - dirX * back
		oy = oy - dirY * back
		oz = oz - dirZ * back

		local sizeR = (mathRandom() - 0.5) * K.SIZE_RAND_RANGE
		-- muzzleTaper drives size only; lifetime is kept full so the stream
		-- is continuous and visible all the way to the muzzle.
		local size = (K.CORE_SIZE_BASE + sizeR) * sizeScale * muzzleTaper

		local life = (K.CORE_LIFE_MIN + mathRandom() * K.CORE_LIFE_SPAN) * coreLifeM

		-- Tangential push: more chaotic at end
		local pushScale = randTan * (0.3 + lifeT * 1.5)
		-- Per-particle forward inheritance with small random variance so the
		-- stream looks organic (some puffs catch up to projectile, others trail)
		local fMult = velFwdMult + (mathRandom() * 2 - 1) * velFwdRand
		local rvx = vx * fMult + (mathRandom() * 2 - 1) * pushScale + cx * r1 * 0.05
		local rvy = vy * fMult + (mathRandom() * 2 - 1) * pushScale * 0.6
		local rvz = vz * fMult + (mathRandom() * 2 - 1) * pushScale + cz * r1 * 0.05

		spawnParticle(
			epx + ox, epy + oy, epz + oz,
			rvx, rvy, rvz,
			size, 0, life,
			pR, pG, pB,
			K.CORE_ALPHA_BASE * (0.85 + 0.15 * mathRandom()),
			-- Tier-3 cores are the ONE thing allowed to cross the soft cap into
			-- the essential-overflow region; everything else respects MAX_PARTICLES.
			budgetTier >= 3
		)
	end

	---- Tail chaos particle ----
	-- Gated by muzzleTaper so giant 1.4x core puffs can't spawn near the
	-- emit point (this was the main "fat fire at muzzle" offender).
	-- Skipped entirely once the particle pool is under pressure (tier >= 1).
	if budgetTier < 1 and not farMode and mathRandom() < K.TAIL_EMIT_CHANCE * burstMult * muzzleTaper then
		local microT = mathMin(1, lifeT + 0.15 + (mathRandom() - 0.5) * tintMicro)
		if microT < 0 then microT = 0 end
		local pR, pG, pB = tintSampler(microT)
		pR = pR * (1 + (mathRandom() - 0.5) * tintJit)
		pG = pG * (1 + (mathRandom() - 0.5) * tintJit)
		pB = pB * (1 + (mathRandom() - 0.5) * tintJit)
		local r1 = (mathRandom() * 2 - 1) * 2.0 * sizeScale
		local r2 = (mathRandom() * 2 - 1) * 2.0 * sizeScale
		local ox = cx * r1 + tx * r2
		local oy = cy * r1 + ty * r2
		local oz = cz * r1 + tz * r2
		local size = (K.CORE_SIZE_BASE * 1.4) * sizeScale * muzzleTaper
		local life = K.CORE_LIFE_MAX * 0.9 * coreLifeM
		local pushScale = randTan * 2.0
		spawnParticle(
			epx + ox, epy + oy, epz + oz,
			pvx * 0.5 + (mathRandom() * 2 - 1) * pushScale,
			pvy * 0.5 + (mathRandom() * 2 - 1) * pushScale,
			pvz * 0.5 + (mathRandom() * 2 - 1) * pushScale,
			size, 0, life,
			pR, pG, pB,
			K.CORE_ALPHA_BASE
		)
	end

	---- Smoke ----
	-- Smoke only kicks in after the stream has had time to combust (the muzzle
	-- area stays pure fire). Trail smoke rises behind the older parts of the
	-- stream; head smoke is a light haze that appears mid/late flight.
	-- Smoke fades in gradually from lifeT=0.3 (0%) to lifeT=0.55 (100%) instead of snapping on
	-- Smoke is the FIRST thing dropped under budget pressure (tier >= 1): it's
	-- ambient decoration, not the projectile trail itself, and smoke particles
	-- are the largest/longest-lived so dropping them frees the most pool slots.
	local smokeFade = mathMin(1.0, mathMax(0.0, (lifeT - 0.3) / 0.25))
	if losSmokeVis and budgetTier < 1 and smokeFade > 0 and mathRandom() < K.SMOKE_CHANCE * burstMult * intensity * smokeFade then
		local r1 = (mathRandom() * 2 - 1) * 1.8 * sizeScale
		local r2 = (mathRandom() * 2 - 1) * 1.8 * sizeScale
		local ox = cx * r1 + tx * r2
		local oy = cy * r1 + ty * r2
		local oz = cz * r1 + tz * r2
		local size = (K.SMOKE_SIZE_BASE + mathRandom() * K.SIZE_RAND_RANGE) * sizeScale
		local life = K.SMOKE_LIFE_MIN + mathRandom() * K.SMOKE_LIFE_SPAN
		local svy = K.SMOKE_UP_VEL_MIN + mathRandom() * K.SMOKE_UP_VEL_SPAN
		spawnParticle(
			epx + ox, epy + oy + 0.6, epz + oz,
			-- Smoke rides forward at nearly the same rate as the core flame so
			-- the smoke trail visually covers the same downrange area instead of
			-- being left behind where the fire passed.
			pvx * 0.85 + (mathRandom() - 0.5) * 0.2,
			svy,
			pvz * 0.85 + (mathRandom() - 0.5) * 0.2,
			size, 1, life,
			K.SMOKE_TINT_R, K.SMOKE_TINT_G, K.SMOKE_TINT_B,
			K.SMOKE_ALPHA_BASE
		)
	end

	---- Head smoke (light haze just behind the projectile, only mid-flight onward) ----
	-- Head smoke fades in from lifeT=0.2 (0%) to lifeT=0.45 (100%)
	if losSmokeVis and budgetTier < 1 and not farMode then
	local headSmokeFade = mathMin(1.0, mathMax(0.0, (lifeT - 0.2) / 0.25))
	if headSmokeFade > 0 and mathRandom() < K.SMOKE_CHANCE_HEAD * burstMult * intensity * headSmokeFade then
		local r1 = (mathRandom() * 2 - 1) * 1.0 * sizeScale
		local r2 = (mathRandom() * 2 - 1) * 1.0 * sizeScale
		-- Bias the offset upward so the smoke cloud sits above the bright core
		local upBias = 0.8 + mathRandom() * 1.4
		local ox = cx * r1 + tx * r2
		local oy = cy * r1 + ty * r2 + upBias * sizeScale
		local oz = cz * r1 + tz * r2
		-- Slight backward bias so the cloud sits just behind the projectile head
		local back = (0.2 + mathRandom() * 0.4) * speed
		ox = ox - dirX * back
		oy = oy - dirY * back
		oz = oz - dirZ * back
		local size = (K.SMOKE_SIZE_BASE * 0.85 + mathRandom() * K.SIZE_RAND_RANGE) * sizeScale
		local life = (K.SMOKE_LIFE_MIN * 0.7) + mathRandom() * K.SMOKE_LIFE_SPAN * 0.6
		local svy = (K.SMOKE_UP_VEL_MIN + mathRandom() * K.SMOKE_UP_VEL_SPAN) * 1.3
		spawnParticle(
			epx + ox, epy + oy, epz + oz,
			-- Head smoke also rides forward with the projectile so it reaches
			-- all the way to where the fire lands.
			pvx * 0.95 + (mathRandom() - 0.5) * 0.15,
			svy,
			pvz * 0.95 + (mathRandom() - 0.5) * 0.15,
			size, 1, life,
			K.SMOKE_TINT_HEAD_R, K.SMOKE_TINT_HEAD_G, K.SMOKE_TINT_HEAD_B,
			K.SMOKE_ALPHA_BASE * 0.6
		)
	end
	end -- if not farMode (head smoke)
end

--------------------------------------------------------------------------------
-- Per-frame projectile scan
--------------------------------------------------------------------------------
local function updateProjectiles(gameFrame, throttleMult)
	local projectiles = spGetVisibleProjectiles()
	if not projectiles then return end

	trackGen = trackGen + 1
	local gen = trackGen

	for i = 1, #projectiles do
		local proID = projectiles[i]
		local info = tracked[proID]
		-- Detect proID recycling: Spring reuses dead projectile IDs, and between
		-- STALE_GC_INTERVAL passes a new (different-weapon) projectile can hijack
		-- a tracked ID and inherit the old info's cfg/ownerID/isScav -- the "flame
		-- with another unit's properties" symptom. Cheap defense: compare current
		-- engine wDefID against the one stamped at info creation.
		if info and spGetProjectileDefID(proID) ~= info.wDefID then
			tracked[proID] = nil
			info = nil
		end
		-- Same-wDefID recycle: under heavy flamethrower fire, a dead flame proID
		-- is reassigned to a fresh flame projectile of the SAME weapon (so the
		-- wDefID check above passes). The old info.birthFrame is now stale --
		-- lifeT computes to ~1 immediately and the new projectile spawns large
		-- orange cores at the muzzle from the very first frame. Detect via age
		-- vs expected life: if we think this proID has been alive longer than
		-- ~1.5x the weapon's projectile flight time, it MUST be a recycle.
		-- Refresh birthFrame so lifeT restarts at 0.
		if info and (gameFrame - info.birthFrame) > info.cfg.expectedLife * 1.5 then
			info.birthFrame        = gameFrame
			info.midFlightAcquired = false
			local ex, ey, ez = spGetProjectilePosition(proID)
			if ex then
				info.emitX, info.emitY, info.emitZ = ex, ey, ez
			end
		end
		if info then
			info.gen = gen
			emitStream(proID, info, gameFrame, throttleMult)
		elseif ignored[proID] then
			-- Non-flame projectile we've already classified -- just refresh its
			-- generation marker so it doesn't get GC'd until it actually expires.
			ignored[proID] = gen
		else
			local wDefID = spGetProjectileDefID(proID)
			local cfg = wDefID and weaponConfigs[wDefID] or nil
			if cfg then
				local teamID = spGetProjectileTeamID(proID)
				local ownerAllyTeam = teamID and spGetTeamAllyTeamID(teamID) or -1
				local ex, ey, ez = spGetProjectilePosition(proID)

				-- Detect mid-flight acquisition (projectile created off-screen,
				-- first observed by us while already in transit). Compare its
				-- current position to its owner unit's position; if it's already
				-- well past muzzle distance, mark it so emitStream skips the
				-- jet phase. Without this we would re-spawn fresh muzzle jets
				-- at the projectile's current far-from-origin position, and the
				-- shader drag integration would drift those jets downstream --
				-- the visible "particles way too far outside max range" bug.
				--
				-- We also override emitX/Y/Z with the owner unit's position in
				-- the midFlight case. Otherwise emitX = projectile current pos
				-- (already near the target), distFromEmitSq stays ~0, distT2
				-- never ramps, and muzzleTaper stays at MUZZLE_TAPER_MIN -- so
				-- when you zoom in on the target end of a flame stream the
				-- cores look small and yellow instead of large and orange.
				-- Owner position is a much better proxy for the real muzzle
				-- than the projectile's late-acquisition position.
				local midFlight = false
				local ownerID = nil
				local isScav = false
				local birthFrame = gameFrame
				if ex then
					ownerID = spGetProjectileOwnerID(proID)
					if ownerID then
						local ox, oy, oz = spGetUnitPosition(ownerID)
						if ox then
							local dx, dy, dz = ex - ox, ey - oy, ez - oz
							local distFromOwnerSq = dx*dx + dy*dy + dz*dz
							-- Adaptive midFlight threshold: must clear both
							-- (a) a generous absolute floor that exceeds even
							-- the longest unit barrel offset (~120 elmos for
							-- big turrets like cormaw/hammer) and (b) a
							-- fraction of weapon range so long-range weapons
							-- (which live on big units) don't false-trigger
							-- on every fresh muzzle shot. Old fixed 80-elmo
							-- threshold caused false-positives on long-barrel
							-- flamer turrets: every newly-fired projectile got
							-- birthFrame backdated, so cores spawned at the
							-- muzzle sampled the orange/saturated zone of the
							-- tint LUT immediately at full muzzleTaper size
							-- ("large orange chunks at the nozzle from frame
							-- one" symptom).
							local mfThresh = cfg.range * 0.30
							if mfThresh < 120 then mfThresh = 120 end
							local mfThreshSq = mfThresh * mfThresh
							if distFromOwnerSq > mfThreshSq then
								midFlight = true
								-- Use the owner unit position as the emit
								-- origin (see comment above).
								ex, ey, ez = ox, oy, oz
								-- Estimate the true birth frame from how far
								-- the projectile has already travelled. Without
								-- this, lifeT starts at 0 for the rest of the
								-- projectile's flight, so tintSampler(lifeT)
								-- returns the yellow nozzle color forever and
								-- the cores never warm up to orange. Using
								-- distance/speed gives a good first-order
								-- estimate (assumes the owner hasn't moved much
								-- since firing -- true for flame turrets which
								-- are buildings or slow units).
								local vx, vy, vz = spGetProjectileVelocity(proID)
								if vx then
									local speed = mathSqrt(vx*vx + vy*vy + vz*vz)
									if speed > 0.001 then
										local travelled = mathSqrt(distFromOwnerSq)
										birthFrame = gameFrame - mathFloor(travelled / speed + 0.5)
									end
								end
							end
						end
						-- Scavenger ownership: matches BAR's standard convention
						-- (unitDef.customParams.isscavenger, used by scav_spawner_defense,
						-- pve_areahealers, gfx_raptor_scum_gl4, etc.).
						local ownerDefID = spGetUnitDefID(ownerID)
						if ownerDefID then
							local ud = UnitDefs[ownerDefID]
							if ud and ud.customParams and ud.customParams.isscavenger then
								isScav = true
							end
						end
					end
				end

				info = {
					cfg                = cfg,
					wDefID             = wDefID,
					birthFrame         = birthFrame,
					ownerAllyTeam      = ownerAllyTeam,
					ownerID            = ownerID,
					isScav             = isScav,
					gen                = gen,
					emitX              = ex or 0,
					emitY              = ey or 0,
					emitZ              = ez or 0,
					midFlightAcquired  = midFlight,
				}
				tracked[proID] = info
				emitStream(proID, info, gameFrame, throttleMult)
			else
				-- Negative-cache it so we never call spGetProjectileDefID for this
				-- proID again. Massive win when many non-flame projectiles are on
				-- screen (artillery, missiles, lasers, etc.).
				ignored[proID] = gen
			end
		end
	end

	-- Drop projectiles that no longer appear. NOTE: spGetVisibleProjectiles
	-- is frustum-only, so a flamethrower passing out of view stops showing up
	-- here even though it's still alive. If we dropped tracked[proID] on the
	-- first gen mismatch, then on camera return we'd create a fresh info with
	-- birthFrame = gameFrame, which resets lifeT to 0 and re-triggers the
	-- jet-phase emission (lifeT < JET_MAX_LIFE_FRAC). Those fresh jets fly
	-- off at velocity for their full 6-14 frame life and visibly persist in
	-- mid-air past the active stream -- the "jets way past their max range/life"
	-- symptom. Fix: never drop a tracked entry on view loss alone -- only when
	-- the engine projectile is genuinely gone (spGetProjectilePosition returns
	-- nil). This preserves info.birthFrame across arbitrarily long camera pans,
	-- so lifeT is always correct on re-acquisition. We additionally validate
	-- wDefID on re-visibility to defend against the rare case of proID reuse.
	-- Run only every STALE_GC_INTERVAL frames -- a few extra dead entries lingering
	-- for half a second cost nothing, but the full table scan every frame is real
	-- CPU on big games (hundreds of projectiles tracked + thousands ignored).
	if (gameFrame % STALE_GC_INTERVAL) == 0 then
		for proID, tInfo in pairs(tracked) do
			if tInfo.gen ~= gen then
				local px = spGetProjectilePosition(proID)
				if not px then
					tracked[proID] = nil
				end
			end
		end
		for proID, g in pairs(ignored) do
			if g ~= gen then
				local px = spGetProjectilePosition(proID)
				if not px then
					ignored[proID] = nil
				end
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Draw
--------------------------------------------------------------------------------
local function drawParticles()
	if not particleVBO or particleVBO.usedElements == 0 then return end
	if not particleShader then return end

	glDepthTest(true)
	glDepthMask(false)
	glCulling(false)
	glBlending(GL_ONE, GL_ONE_MINUS_SRC_ALPHA)

	glTexture(0, fireTexture)
	glTexture(1, smokeTexture)

	particleShader:Activate()
	particleShader:SetUniformFloat("windVelocity", windX, 0, windZ)
	particleVBO:Draw()
	particleShader:Deactivate()

	glTexture(0, false)
	glTexture(1, false)

	glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	glDepthMask(true)
	glDepthTest(false)
end

--------------------------------------------------------------------------------
-- Callins
--------------------------------------------------------------------------------
function gadget:Initialize()
	if not gl.CreateShader then
		goodbye("OpenGL shaders not supported")
		return
	end
	if not initGL4() then return end

	cachedAllyTeamID = spGetMyAllyTeamID()
	_, cachedFullView = spGetSpectatingState()

	if missingAlldefsPost > 0 then
		Spring.Echo(string.format(
			"[gfx_flamethrower_gl4] WARNING: %d flame weapon(s) still have engine flame visuals + cegtag active. " ..
			"gamedata/alldefs_post.lua only runs at GAME START -- /luarules reload does NOT re-run it. " ..
			"Quit to menu and start a new game to fully suppress the engine flame billboard and cegtag smoke trail.",
			missingAlldefsPost))
	end

	GG.Flamethrower = {
		GetParticleCount = function() return particleVBO and particleVBO.usedElements or 0 end,
		GetMaxParticles  = function() return CONFIG.maxParticles end,
		GetConfig        = function() return CONFIG end,
		IsTracked        = function(weaponDefID) return weaponConfigs[weaponDefID] ~= nil end,
	}
end

function gadget:Shutdown()
	cleanupGL4()
	GG.Flamethrower = nil
end

function gadget:PlayerChanged(playerID)
	cachedAllyTeamID = spGetMyAllyTeamID()
	_, cachedFullView = spGetSpectatingState()
end

-- NOTE: gadget:ProjectileDestroyed is intentionally NOT defined here.
-- That callin only fires for weaponDefIDs registered via
-- Script.SetWatchProjectile, which is a SYNCED-only function -- this is
-- an unsynced gadget, so we cannot register and the callin would never
-- fire anyway. Instead, proID recycling is detected inline in
-- updateProjectiles via (a) a wDefID mismatch check, (b) an age-vs-
-- expectedLife check, and (c) a position-based teleport check (a recycled
-- proID's new position is typically dozens to hundreds of elmos away from
-- the previous shot's last-known position, far more than one frame of
-- velocity can account for).

local fpsUpdateInterval = 1
local lastFpsCheckFrame = 0

-- ----------------------------------------------------------------------------
-- Long-run leak instrumentation + self-healing safety net.
--
-- Background: after ~30 min of continuous heavy flame the visible effect
-- disappears. Code reading has not pinned the cause, so we run two things
-- in production:
--
--   1) Heartbeat dump every DIAG_INTERVAL frames so a long test logs which
--      counter is climbing (used, idMap, tracked, ignored, rmQ, fpsInt).
--      Disable by setting DIAG_ENABLED = false once root-caused.
--
--   2) SAFETY NET (always on): periodically validate that
--         particleVBO.usedElements == #instanceIDtoIndex
--      Those two MUST stay in lockstep -- every push +1 to both, every pop
--      -1 to both. If they ever diverge it means push/pop accounting drifted
--      (the prime leak hypothesis) and the soft cap will eventually lock the
--      pool full forever. When detected we log loudly and force-clear the
--      whole VBO + per-projectile attribution lists so the effect comes back
--      and the user can keep playing while we investigate. No-op cost when
--      everything is healthy (one pairs() walk per minute).
-- ----------------------------------------------------------------------------
local DIAG_ENABLED   = false
local DIAG_INTERVAL  = 300   -- 30s at 30Hz
local SAFETY_INTERVAL = 1800 -- 60s at 30Hz
local SAFETY_DRIFT_TOLERANCE = 4  -- |used - idMap| above this triggers heal

local function countTable(t)
	local n = 0
	for _ in pairs(t) do n = n + 1 end
	return n
end

local function dumpDiagnostics(n)
	local trackedCount  = countTable(tracked)
	local ignoredCount  = countTable(ignored)
	local queueKeys, queueTotal = 0, 0
	for _, q in pairs(particleRemoveQueue) do
		queueKeys  = queueKeys + 1
		queueTotal = queueTotal + #q
	end
	local idMapSize = particleVBO and particleVBO.instanceIDtoIndex
		and countTable(particleVBO.instanceIDtoIndex) or 0
	Spring.Echo(string.format(
		"[flameDiag] f=%d used=%d/%d(%d) idMap=%d  tracked=%d ignored=%d  rmQ=%d(%dids)  nextID=%d fpsInt=%d",
		n,
		particleVBO and particleVBO.usedElements or -1,
		K.MAX_PARTICLES, K.HARD_MAX_PARTICLES,
		idMapSize,
		trackedCount, ignoredCount,
		queueKeys, queueTotal,
		nextParticleID, fpsUpdateInterval))
end

-- Force-clear the entire particle VBO and all per-projectile attribution
-- lists. Called by the safety net when accounting drift is detected. After
-- this runs the visual effect comes back within a few frames (every tracked
-- projectile re-emits naturally). Loud Spring.Echo so a leak event is
-- impossible to miss in logs/infolog.
local function emergencyResetParticles(reason)
	Spring.Echo("[gfx_flamethrower_gl4] EMERGENCY RESET: " .. tostring(reason))
	if particleVBO then
		-- clearInstanceTable resets usedElements + both id<->index maps in one
		-- call, then re-uploads an empty buffer.
		if gl.InstanceVBOTable.clearInstanceTable then
			gl.InstanceVBOTable.clearInstanceTable(particleVBO)
		else
			-- Defensive: if the engine InstanceVBO module ever loses
			-- clearInstanceTable, fall through to a manual reset of just the
			-- accounting maps. Slots will be reclaimed lazily as new pushes
			-- swap-replace them.
			particleVBO.usedElements      = 0
			particleVBO.instanceIDtoIndex = {}
			particleVBO.indextoInstanceID = {}
		end
	end
	-- Drop every queued death-frame entry so future expirations don't try to
	-- pop IDs that no longer exist in the VBO.
	particleRemoveQueue = {}
	lastRemovedFrame    = cachedGameFrame
	-- Detach particle attribution from every tracked projectile so they emit
	-- fresh from this frame onward without dangling references to dead IDs.
	for _, info in pairs(tracked) do
		info.particles = nil
	end
end

local function runSafetyNet(n)
	if not particleVBO then return end
	local used     = particleVBO.usedElements
	local idMap    = particleVBO.instanceIDtoIndex
	if not idMap then return end
	local mapSize  = countTable(idMap)
	local drift    = used - mapSize
	if drift < 0 then drift = -drift end
	if drift > SAFETY_DRIFT_TOLERANCE then
		Spring.Echo(string.format(
			"[gfx_flamethrower_gl4] ACCOUNTING DRIFT detected: usedElements=%d idMap=%d (diff=%d). " ..
			"This is the suspected long-run leak. Triggering self-heal.",
			used, mapSize, used - mapSize))
		emergencyResetParticles("accounting drift used=" .. used .. " idMap=" .. mapSize)
		return
	end
end

function gadget:GameFrame(n)
	if not particleVBO then return end

	cachedGameFrame = n
	cachedCamX, cachedCamY, cachedCamZ = spGetCameraPosition()

	-- Wind every 10 frames
	if n % 10 == 0 then
		local _, _, _, _, wx, _, wz = spGetWind()
		windX = wx or 0
		windZ = wz or 0
	end

	-- FPS based throttling: emit every Nth sim frame when FPS is low.
	-- More aggressive than before (40/fps vs 30/fps) so we start throttling
	-- before the framerate drops below the standard 30fps target.
	if n - lastFpsCheckFrame >= 15 then
		lastFpsCheckFrame = n
		local fps = spGetFPS()
		if fps > 0 then
			fpsUpdateInterval = mathMax(1, mathCeil(40 / fps))
		end
	end

	removeExpiredParticles(n)

	if n % fpsUpdateInterval == 0 then
		updateProjectiles(n, fpsUpdateInterval)
	end

	if DIAG_ENABLED and (n % DIAG_INTERVAL) == 0 then
		dumpDiagnostics(n)
	end

	if (n % SAFETY_INTERVAL) == 0 then
		runSafetyNet(n)
	end
end

-- When the game is paused, gadget:GameFrame stops firing, so updateProjectiles
-- never runs and no new particles are spawned. If the user wasn't already
-- looking at an actively-firing flamethrower when they paused, panning the
-- camera to one shows nothing -- the stream is invisible.
--
-- Fix: run a single emission pass via gadget:Update (which keeps firing while
-- paused) when (a) we're paused, (b) the camera has moved enough since the
-- last paused-emit to plausibly have framed new projectiles, and (c) at least
-- a short cooldown has passed. The shader's time uniform is frozen during
-- pause so particles spawned here will sit frozen in mid-flight, which is
-- exactly what we want for a static "you can see what's burning" preview.
--
-- Particles spawned during pause will simply expire en masse on unpause when
-- the engine gameframe jumps forward past their deathFrame; not pretty but
-- acceptable, and bounded by the existing MAX_PARTICLES pool cap.
local PAUSE_EMIT_CAM_MOVE_SQ = 400   -- 20^2 elmos camera move re-triggers emit for newly-visible streams
local pauseEmitDone = false      -- have we already produced one snapshot for the current pause?
local lastPauseCamX, lastPauseCamY, lastPauseCamZ = 0, 0, 0
function gadget:Update()
	if not particleVBO then return end

	local _, _, paused = spGetGameSpeed()
	if not paused then
		-- Reset so the first paused Update after unpause/re-pause emits again.
		pauseEmitDone = false
		lastPauseCamX, lastPauseCamY, lastPauseCamZ = 0, 0, 0
		for k in pairs(pauseEmittedFor) do pauseEmittedFor[k] = nil end
		return
	end

	local cx, cy, cz = spGetCameraPosition()
	local dx, dy, dz = cx - lastPauseCamX, cy - lastPauseCamY, cz - lastPauseCamZ
	local camMovedSq = dx * dx + dy * dy + dz * dz

	-- Emit on first paused Update, and again whenever the camera has moved
	-- enough that previously off-screen streams may now be visible. The
	-- pauseEmittedFor table prevents already-emitted streams from receiving
	-- additional particles on camera-move re-emits.
	if pauseEmitDone and camMovedSq < PAUSE_EMIT_CAM_MOVE_SQ then return end
	local firstPausedEmit = not pauseEmitDone
	pauseEmitDone = true
	lastPauseCamX, lastPauseCamY, lastPauseCamZ = cx, cy, cz

	-- NOTE: we deliberately do NOT pre-gate currently-visible projectiles
	-- here. Earlier versions did, on the assumption that anything visible
	-- at pause time already has a fully-stocked live trail. Under heavy
	-- load (many flamethrowers firing at once) the live pool cap starves
	-- most streams of particles, so those visible streams actually have
	-- empty or near-empty trails -- pre-gating them leaves the paused
	-- view showing zero particles on most flamethrowers. Let the burst
	-- loop emit for everyone; the pauseBurstEmitted -> pauseEmittedFor
	-- promotion after the loop still prevents double-emission on later
	-- camera-move re-emits.
	--
	-- Also: wipe leftover live particles before the first paused snapshot.
	-- The last live frame leaves the VBO ~80%+ full, which would starve the
	-- snapshot of headroom (the budget split below would collapse to ~1
	-- particle per stream). Since we re-emit every visible stream, the
	-- leftovers are redundant. Camera-move re-emits in subsequent paused
	-- Updates do NOT clear, so the accumulated snapshot is preserved.
	if firstPausedEmit and gl.InstanceVBOTable.clearInstanceTable then
		gl.InstanceVBOTable.clearInstanceTable(particleVBO)
	end

	-- Multi-pass densification: a single emitStream call only produces ~1
	-- live-frame worth of particles at the projectile head, which looks
	-- extremely sparse next to the live appearance (which accumulates 30+
	-- frames of overlapping emissions). We can't fill the historical trail
	-- without trail synthesis (walking projectile pos back along velocity,
	-- previously reverted), but we can densify the head and spread jets a
	-- bit further by running several passes with backdated cachedGameFrame
	-- and an emit-count multiplier (throttleMult). Each pass varies lifeT,
	-- producing color/intensity variation, and the jet sub-frame backStep
	-- distributes the extra jet particles along ~1 frame of trail each pass.
	--
	-- Adaptive density: when many flamethrowers are active at once, full
	-- 6-pass x 3-density would blow past the VBO cap, leaving entire streams
	-- with zero particles. Estimate how many streams need snapshotting and
	-- shrink passes/density so every stream gets at least its first pass.
	cachedCamX, cachedCamY, cachedCamZ = cx, cy, cz
	local realGameFrame = cachedGameFrame
	local MAX_PASSES   = 6
	local MAX_DENSITY  = 3
	local PAUSE_EMIT_STRIDE = 4   -- frames between backdated passes

	-- Estimate streams to snapshot: visible-now minus already-gated. Each
	-- stream produces roughly density cores per pass; budget against the
	-- VBO ceiling minus what's already in flight.
	local pendingCount = 0
	local visibleNow = spGetVisibleProjectiles()
	if visibleNow then
		for i = 1, #visibleNow do
			if not pauseEmittedFor[visibleNow[i]] then
				pendingCount = pendingCount + 1
			end
		end
	end
	local pauseEmitPasses  = MAX_PASSES
	local pauseEmitDensity = MAX_DENSITY
	if pendingCount > 0 then
		local headroom = K.HARD_MAX_PARTICLES - particleVBO.usedElements
		if headroom < 0 then headroom = 0 end
		-- Reserve ~1 core per stream per pass; pick the largest pass*density
		-- product that fits. Always allow >=1 pass with density 1 so every
		-- stream gets at least one core (cores ignore the soft cap during
		-- paused mode in spawnParticle).
		local maxParticlesPerStream = mathMax(1, mathFloor(headroom / pendingCount))
		-- particles per stream = passes * density (cores), so cap product.
		local product = maxParticlesPerStream
		if product > MAX_PASSES * MAX_DENSITY then product = MAX_PASSES * MAX_DENSITY end
		-- Prefer more passes (variety/lifeT spread) over density when small.
		if product >= MAX_PASSES * MAX_DENSITY then
			pauseEmitPasses, pauseEmitDensity = MAX_PASSES, MAX_DENSITY
		elseif product >= MAX_PASSES then
			pauseEmitPasses  = MAX_PASSES
			pauseEmitDensity = mathMax(1, mathFloor(product / MAX_PASSES))
		else
			pauseEmitPasses  = mathMax(1, product)
			pauseEmitDensity = 1
		end
	end

	for k in pairs(pauseBurstEmitted) do pauseBurstEmitted[k] = nil end
	pausedEmitMode = true
	for pass = 1, pauseEmitPasses do
		-- Backdate so older passes spawn particles with older birthFrame ->
		-- larger lifeT -> warmer/redder colour and longer drift via the
		-- shader's velocity integration.
		cachedGameFrame = realGameFrame - 2 - (pauseEmitPasses - pass) * PAUSE_EMIT_STRIDE
		updateProjectiles(realGameFrame, pauseEmitDensity)
	end
	pausedEmitMode = false
	-- Promote burst hits into the permanent gate so future camera-move
	-- re-emits skip these streams.
	for k in pairs(pauseBurstEmitted) do
		pauseEmittedFor[k] = true
		pauseBurstEmitted[k] = nil
	end
	cachedGameFrame = realGameFrame
end

function gadget:DrawWorld()
	drawParticles()
end
