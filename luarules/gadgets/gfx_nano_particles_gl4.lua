--------------------------------------------------------------------------------
-- Nano Particles GL4 (unsynced)
--
-- Lua replica of the engine's CNanoProjectile system, intended as a drop-in
-- alternative we can iterate / overhaul. Runs entirely in the unsynced half
-- of a luarules gadget so it never touches the simulation.
--
-- Behaviour mirrors the engine reference (rts/Sim/Projectiles/ProjectileHandler
-- ::AddNanoParticle and rts/Rendering/Env/Particles/Classes/NanoProjectile):
--
--   * Each gameframe we iterate visible builders, ask GetUnitCurrentBuildPower
--     to filter active ones, then GetUnitWorkerTask to find their target. This
--     replaces the synced AllowUnitBuildStep/AllowFeatureBuildStep callins
--     while still firing approximately every gameframe a builder is busy.
--   * For each emission: direction = normalize(end-start) + jitter*0.15,
--     velocity = dir * 3.0, lifetime = floor(len/3.0), team-color tint,
--     alpha = 20/255 (matching engine constants).
--   * Reclaim emissions spawn at the target and travel back (engine's inverse
--     overload of AddNanoParticle).
--   * Position update happens in the vertex shader (spawn + vel * elapsed) so
--     we only push instance data once at spawn and pop on death.
--
-- The gadget renders alongside the engine's own nano spray; silence the engine
-- (e.g. MaxNanoParticles=0 or unitDef.showNanoSpray=false) to compare cleanly.
--------------------------------------------------------------------------------

function gadget:GetInfo()
	return {
		name      = "Nano Particles GL4",
		desc      = "Nano build particles rendered with a custom GL4 shader for enhanced visuals and effects. Drop-in replacement for the engine's built-in nano spray",
		author    = "Floris",
		date      = "April 2026",
		license   = "GNU GPL v2",
		layer     = 0,
		enabled   = true,
	}
end

-- Synced half is empty: gadget runs entirely in unsynced space.
if gadgetHandler:IsSyncedCode() then return end

--------------------------------------------------------------------------------
-- Imports / locals
--------------------------------------------------------------------------------

local spEcho                     = Spring.Echo
local spGetGameFrame             = Spring.GetGameFrame
local spGetMyAllyTeamID          = Spring.GetMyAllyTeamID
local spGetSpectatingState       = Spring.GetSpectatingState
local spIsPosInLos            = Spring.IsPosInLos
local spGetAllUnits              = Spring.GetAllUnits
local spGetUnitTeam              = Spring.GetUnitTeam
local spGetUnitAllyTeam          = Spring.GetUnitAllyTeam
local spGetUnitNanoPieces        = Spring.GetUnitNanoPieces
local spGetUnitPiecePosDir       = Spring.GetUnitPiecePosDir
local spGetUnitPosition          = Spring.GetUnitPosition
local spGetUnitRadius            = Spring.GetUnitRadius
local spGetUnitDefID             = Spring.GetUnitDefID
local spGetUnitIsBeingBuilt      = Spring.GetUnitIsBeingBuilt
local spGetFeaturePosition       = Spring.GetFeaturePosition
local spGetFeatureRadius         = Spring.GetFeatureRadius
local spValidFeatureID           = Spring.ValidFeatureID
local spValidUnitID              = Spring.ValidUnitID
local spGetTeamColor             = Spring.GetTeamColor
local spGetUnitCurrentBuildPower = Spring.GetUnitCurrentBuildPower
local spGetUnitWorkerTask        = Spring.GetUnitWorkerTask
local spGetUnitHealth            = Spring.GetUnitHealth
local spIsSphereInView           = Spring.IsSphereInView
local spGetCameraPosition        = Spring.GetCameraPosition

-- Engine encodes feature targets in worker-task results as (featureID + MaxUnits()).
-- Used for CMD_RESURRECT (always) and CMD_RECLAIM of features. See engine
-- LuaSyncedRead.cpp::GetBuilderWorkerTask.
local MAX_UNITS = Game.maxUnits or 32000

local glBlending  = gl.Blending
local glTexture   = gl.Texture
local glDepthTest = gl.DepthTest
local glDepthMask = gl.DepthMask
local glCulling   = gl.Culling

local GL_ONE                 = GL.ONE
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_SRC_ALPHA           = GL.SRC_ALPHA

local LuaShader              = gl.LuaShader
local InstanceVBOTable       = gl.InstanceVBOTable
local pushElementInstance    = InstanceVBOTable.pushElementInstance
local popElementInstance     = InstanceVBOTable.popElementInstance
local uploadElementRange     = InstanceVBOTable.uploadElementRange

local mathRandom = math.random
local mathSqrt   = math.sqrt
local mathFloor  = math.floor
local spGetTimer   = Spring.GetTimer
local spDiffTimers = Spring.DiffTimers

local CMD_RECLAIM   = CMD.RECLAIM
local CMD_RESURRECT = CMD.RESURRECT
local CMD_CAPTURE   = CMD.CAPTURE
local CMD_REPAIR    = CMD.REPAIR

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

-- Hard VBO ceiling. The InstanceVBOTable is allocated once at init for this
-- many slots; the live cap (MAX_PARTICLES, below) can shrink at runtime when
-- the user lowers the MaxParticles config but never grows past this value.
local MAX_PARTICLES_VBO = 15000

-- Live soft cap. Driven by the MaxParticles springsetting (~33% share, with a
-- 6000 floor so the gadget always has *some* headroom). Polled in GameFrame
-- so the gfx options menu can adjust it without a /luarules reload.
local MAX_PARTICLES_FLOOR = 5000
local MAX_PARTICLES_FRACTION = 0.33
local function computeMaxParticles()
	local cfg = Spring.GetConfigInt("MaxParticles", 15000) or 15000
	local soft = math.max(MAX_PARTICLES_FLOOR, math.floor(cfg * MAX_PARTICLES_FRACTION))
	return math.min(MAX_PARTICLES_VBO, soft)
end
local MAX_PARTICLES = computeMaxParticles()
local function refreshMaxParticles()
	MAX_PARTICLES = computeMaxParticles()
end

local NANO_TEXTURE    = "bitmaps/projectiletextures/nanopart.tga"
local LOS_FILTER      = true   -- drop emissions outside our LOS

-- Debug: when true, the billboard FS skips the texture and LOS sample and
-- outputs a flat colored quad per particle. Useful to confirm particles are
-- being submitted to the GPU when the normal output looks empty. Cube mode
-- ignores this flag.
local DEBUG_FLAT_FS = false

-- Render mode: "billboard" (camera-facing textured quads matching the engine's
-- nano spray look) or "shape" (3D polyhedra that tumble in 3D space, drawn via
-- a geometry shader; the specific polyhedron is picked in
-- MODE_SETTINGS.shape.shape). Shape mode swaps shader pair only; emission,
-- homing, fade, LOS filtering and all other logic are unchanged.
--
-- Driven by the "NanoParticleMode" springsetting (set by the gfx options UI):
--   0 = engine nano spray (gadget stays loaded but inert; engine draws spray)
--   1 = gadget billboards
--   2 = gadget 3D shapes
-- Polled live in GameFrame so the user can switch in the options menu without
-- a /luarules reload.
local NANO_PARTICLE_MODE = Spring.GetConfigInt("NanoParticleMode", 2)
local RENDER_MODE = (NANO_PARTICLE_MODE == 1) and "billboard" or "shape"

-- Per-mode visual settings. Billboard matches the engine spray; shape is tuned
-- separately because shaded 3D faces read very differently from a soft glow
-- sprite. Edit the active mode's table to tweak its look in isolation.
local MODE_SETTINGS = {
	billboard = {
		drawRadius  = 3.1,        -- engine: drawRadius = 3
		nanoAlpha   = 10 / 255,
		dirJitter   = 0.15,
		-- Per-particle randomization (± fraction of the base value). 0 disables.
		sizeVar     = 0.18,
		speedVar    = 0.12,
		alphaVar    = 0,
		-- Engine static rotation params (Spring.SetNanoProjectileParams default
		-- in BAR is (-180, -50, -50, 360, 100, 100)). deg, deg/s, deg/s^2.
		rotValBase  = -180, rotValRange = 360,
		rotVelBase  = -55,  rotVelRange = 110,
		rotAccBase  = -55,  rotAccRange = 110,
		glowIntensity = 0.05,
		glowFalloff = 3.3,
		glowScale = 3.3,
		-- Energy enhancement (all shader-side, zero CPU cost):
		-- coreBoost: HDR overdrive on the textured core. >1 pushes the bright
		--   center past white into bloom range; subtle but makes streams pop.
		coreBoost      = 1.0,
		-- hueJitter: ± fractional per-channel RGB modulation per particle. Keeps
		--   team color recognizable but adds shimmer. 0.05-0.10 sweet spot.
		hueJitter      = 0.07,
		-- glowBreath + glowBreathFreq: halo intensity oscillation. Per-particle
		--   phase so adjacent halos don't pulse in lockstep. Freq in cycles/sec.
		glowBreath     = 0.8,
		glowBreathFreq = 3.0,
		-- sizePulseAmp + sizePulseFreq: subtle quad-size oscillation. Reads as
		--   particles "humming" with energy. Keep amp small (<0.10) to avoid
		--   visible jumps when sub-frame interpolation kicks in.
		sizePulseAmp   = 0.05,
		sizePulseFreq  = 4.0,
		-- cubeNoise* + whiteHotspot*: same uniforms as the shape mode, but
		-- sampled in quad-UV space (centered + v_seed) instead of object-local
		-- coords. cubeNoise modulates the textured-core brightness so the
		-- sprite crackles instead of being a uniform glow; whiteHotspot mixes
		-- the brightest noise peaks toward white for spark/heat highlights.
		-- Keep cubeNoise modest on billboards -- the underlying nanoTex already
		-- has its own falloff structure, so big noise amplitudes look chaotic.
		cubeNoise            = 1.0,
		cubeNoiseSpeed       = 30.0,
		cubeNoiseScale       = 22.0,
		whiteHotspot          = 6.0,
		whiteHotspotThreshold = 0.6,
	},
	shape = {
		shape       = "cube",   -- "cube" | "octahedron"
		drawRadius  = 1.8,        -- shape spans ~2*drawRadius edge-to-edge
		nanoAlpha   = 40 / 255,   -- match billboard look
		dirJitter   = 0.10,       -- chunks read better with less spread
		-- Shapes benefit from visible variation -- they read as discrete chunks.
		sizeVar     = 0.33,
		speedVar    = 0.15,
		alphaVar    = 2.5,
		-- 3D look: shade faces by view direction so back-facing faces are dimmed
		-- but visible through the front faces -- gives real volume instead of a
		-- flat shaded patch. 0 = flat shading, 1 = full view-dependent depth.
		cubeShowInside = 3.0,
		cubeNoise       = 2.0,
		cubeNoiseSpeed  = 20.0,
		cubeNoiseScale  = 1.5,
		-- The geometry shader applies its own per-axis 3D tumble on top of
		-- rotVal, so the base 2D rotation can be slower and more uniform.
		rotValBase  = -180, rotValRange = 360,
		rotVelBase  = -40,  rotVelRange = 80,
		rotAccBase  = -40,    rotAccRange = 870,
		glowIntensity = 0.22,
		glowFalloff = 7.5,
		glowScale = 10.0,
		-- Energy enhancement (subset; size pulsation is not wired
		-- through the shape GS, so omitted here -- halo + jitter + breath +
		-- core boost is enough to read shapes as energy chunks).
		coreBoost      = 1.1,    -- multiplies face shading; keep modest so dark faces still read
		hueJitter      = 0.07,    -- shapes already have face-noise variation, so less hue drift needed
		glowBreath     = 4.0,    -- halo pulse amplitude (0..1)
		glowBreathFreq = 3.0,     -- cycles/sec; slightly slower than billboards (chunks are bigger)

		whiteHotspot          = 0.5,
		whiteHotspotThreshold = 0.66,
	},
}
local MODE
local DRAW_RADIUS

-- Fade-out: per-particle end-of-life alpha ramp. The instance attribute
-- spawnPosAndSize.w carries the per-particle fade window in frames; 0 disables
-- the fade. Different values per emission type so reclaim doesn't fade as it
-- lands on the builder, while repair gets a soft tail-off and target-death
-- gets a snappier dissolve.
local FADE_FRAMES_REPAIR  = 4   -- gentle polish on outbound repair/capture
local FADE_FRAMES_RECLAIM = 3    -- no fade -- particles converge fully
local FADE_FRAMES_DEATH   = 20   -- dissolve when target unit dies or fully repaired

-- Skip forward-homing registration when the target unit is still being built
-- (buildProgress < 1). Avoids the visually odd effect of particles chasing a
-- freshly-rolled-out unit as it exits a factory while assist-builders work on
-- it. The particles still spawn normally; they just travel in a straight line
-- toward the spawn-time position instead of curving with the moving target.
-- A grace window keeps the skip active for a short time after the unit reports
-- complete, so the final few particles emitted as the unit rolls off the
-- factory pad don't suddenly start chasing it.
local HOMING_SKIP_INCOMPLETE = true
local HOMING_SKIP_GRACE_FRAMES = 60   -- ~2s at 30Hz

-- Throttling knobs. These trade a small amount of visual latency for a large
-- CPU win in builder-heavy games (hundreds of active nanos):
--   * WORKER_TASK_CACHE_FRAMES: skip spGetUnitWorkerTask for a builder we
--     already have a fresh task for. Builder-task transitions are rare on the
--     ~10s timescale a build step takes; 4-frame staleness is invisible.
--   * HOMING_RUN_EVERY: run the per-frame in-place re-aim on every Nth frame
--     instead of every frame. Particle speed is small relative to typical
--     unit movement over 1-2 frames so 2 looks identical.
--   * REPAIRED_CHECK_EVERY: per-target full-HP check rate in applyForwardHoming.
local WORKER_TASK_CACHE_FRAMES   = 4
local BUILD_POWER_CACHE_FRAMES   = 2
local LOS_CACHE_FRAMES           = 6
local HOMING_RUN_EVERY           = 3
local REPAIRED_CHECK_EVERY       = 6
-- Run the per-frame builder scan only every Nth sim frame. Scales with pool
-- saturation: at empty pool we scan every frame (full responsiveness), at
-- full pool we scan once per MAX_SCAN_RUN_EVERY frames (the saturation gate
-- would drop most emissions anyway). Per-builder emit probability is auto-
-- multiplied by the chosen value so total emission rate is preserved.
-- Particle rendering is unaffected (the VS animates per render frame from
-- spawn+vel*elapsed); only the spawn-event cadence is throttled.
local MIN_SCAN_RUN_EVERY         = 1
local MAX_SCAN_RUN_EVERY         = 2
-- Forward homing: skip per-particle re-aim once the target has been stationary
-- for this many consecutive homing passes. Spawn-time aim is correct as long
-- as the target hasn't moved, so this collapses entire repair-of-static-unit
-- (turret, building, paused com) cases to a near-no-op.
local STATIONARY_SKIP_AFTER      = 3
-- Off-screen emission throttle. When the builder's spray endpoints are both
-- outside the view frustum, only a fraction of emissions are kept (the rest
-- return cheaply before any spawn / homing register). Frustum visibility is
-- cached per builder for OFFSCREEN_VIS_CACHE_FRAMES, since the camera moves
-- slowly relative to the per-builder emit rate.
--
-- Keep-fraction scales with pool saturation so at low fill we stay responsive
-- (camera might pan and reveal those builders) and at high fill we throttle
-- harder (the saturation gate would drop most emissions anyway): MAX at or
-- below SAT_PIVOT, linearly ramping to MIN at full saturation.
local OFFSCREEN_EMIT_KEEP_MAX       = 0.5
local OFFSCREEN_EMIT_KEEP_MIN       = 0.25
local OFFSCREEN_EMIT_KEEP_SAT_PIVOT = 0.25
local OFFSCREEN_EMIT_KEEP_BAND_INV  = 1.0 / (1.0 - OFFSCREEN_EMIT_KEEP_SAT_PIVOT)
local OFFSCREEN_VIS_CACHE_FRAMES = 6
-- Distance-based emission throttle. Linearly ramps the keep-fraction from
-- 1.0 at DISTANT_EMIT_NEAR_RANGE down to DISTANT_EMIT_KEEP at
-- DISTANT_EMIT_RANGE (and clamped beyond). Composes with the offscreen gate.
-- Two squared-distance compares + a lerp per emission; camera position is
-- sampled once per scan frame.
local DISTANT_EMIT_KEEP          = 0.25
local DISTANT_EMIT_NEAR_RANGE    = 2500    -- elmos: full emission inside this
local DISTANT_EMIT_RANGE         = 10000    -- elmos: floor reached at this
-- Precomputed (DISTANT_EMIT_* are constants): hoisted out of scanBuilders so
-- the per-call mul/sub/inv chain is paid once at file load instead of every
-- sim frame.
local DISTANT_EMIT_NEAR_SQ  = DISTANT_EMIT_NEAR_RANGE * DISTANT_EMIT_NEAR_RANGE
local DISTANT_EMIT_FAR_SQ   = DISTANT_EMIT_RANGE      * DISTANT_EMIT_RANGE
local DISTANT_EMIT_BAND_INV = 1.0 / (DISTANT_EMIT_FAR_SQ - DISTANT_EMIT_NEAR_SQ)
local DISTANT_EMIT_DROP     = 1.0 - DISTANT_EMIT_KEEP

-- Dynamic scan stride: builders are scanned 1/stride per sim frame. emitProb
-- is scaled up by stride so total emission rate is preserved. We grow the
-- stride as the live-particle pool fills up because the saturation gate
-- already drops most emissions in that regime, so scanning every builder
-- every frame just wastes CPU. At full saturation we visit 1/MAX_SCAN_STRIDE
-- of builders per frame; under load this is the dominant scan-cost win.
local MIN_SCAN_STRIDE = 2
local MAX_SCAN_STRIDE = 6

-- Engine constants (rts/Sim/Projectiles/ProjectileHandler.cpp)
local NANO_SPEED      = 4.0	-- engine default: 3.0
local DIR_JITTER
local NANO_ALPHA
local SIZE_VAR
local SPEED_VAR
local ALPHA_VAR
local CUBE_SHOW_INSIDE
local CUBE_NOISE
local CUBE_NOISE_SPEED
local CUBE_NOISE_SCALE
local GLOW_SCALE
local GLOW_INTENSITY
local GLOW_FALLOFF
local CORE_BOOST
local HUE_JITTER
local GLOW_BREATH
local GLOW_BREATH_FREQ
local SIZE_PULSE_AMP
local SIZE_PULSE_FREQ
local WHITE_HOTSPOT
local WHITE_HOTSPOT_THRESHOLD

-- Shape selector for cube-mode geometry shader. The GS branches on this and
-- emits the corresponding polyhedron's faces. All shapes use the same per-face
-- shading / noise pipeline -- only the vertex/face topology differs.
--   cube         -- 6 quads, 24 emitted verts.   Distinct large faces; classic look.
--   octahedron   -- 8 tris,  24 emitted verts.   Diamond/gem feel.
-- (Larger polyhedra like icosahedron/dodecahedron exceed GS output limits with
-- our per-vertex component count and so are not supported.)
local SHAPE_IDS = { cube = 0, octahedron = 1 }
local SHAPE_ID

-- Pack per-particle sizeMult and fadeFrames into a single float for the
-- spawnPosAndSize.w attribute slot (avoids growing the VBO layout). Layout:
--   packed = floor(sizeMult * 256 + 0.5) + fadeFrames * 1024
-- sizeMult expected in [0, 4); fadeFrames integer in [0, ~120].
local function packSizeFade(sizeMult, fadeFrames)
	return mathFloor(sizeMult * 256 + 0.5) + (fadeFrames or 0) * 1024
end

-- The engine API takes rotVel in deg/sec and rotAcc in deg/sec^2 and internally
-- divides by GAME_SPEED to convert to per-frame units. We integrate per-frame in
-- the shader, so apply the same conversion here.
local GAME_SPEED     = Game.gameSpeed or 30
local ROT_VAL_BASE
local ROT_VEL_BASE
local ROT_ACC_BASE
local ROT_VAL_RANGE
local ROT_VEL_RANGE
local ROT_ACC_RANGE

-- Populate every mode-derived local from MODE_SETTINGS[name]. Called once at
-- file load and again whenever NanoParticleMode changes between billboard (1)
-- and shape (2) so the user can switch modes from the options menu without a
-- gadget reload. Callers are responsible for tearing down / rebuilding the GL
-- objects (cleanupGL4 + initGL4) since the shader pair depends on RENDER_MODE.
local function applyRenderMode(name)
	RENDER_MODE      = name
	MODE             = MODE_SETTINGS[name] or MODE_SETTINGS.billboard
	DRAW_RADIUS      = MODE.drawRadius
	DIR_JITTER       = MODE.dirJitter
	NANO_ALPHA       = MODE.nanoAlpha
	SIZE_VAR         = MODE.sizeVar  or 0.0
	SPEED_VAR        = MODE.speedVar or 0.0
	ALPHA_VAR        = MODE.alphaVar or 0.0
	CUBE_SHOW_INSIDE = MODE.cubeShowInside or 0.0
	CUBE_NOISE       = MODE.cubeNoise       or 0.0
	CUBE_NOISE_SPEED = MODE.cubeNoiseSpeed  or 0.0
	CUBE_NOISE_SCALE = MODE.cubeNoiseScale  or 0.5
	GLOW_SCALE       = MODE.glowScale       or 1.0
	GLOW_INTENSITY   = MODE.glowIntensity   or 0.0
	GLOW_FALLOFF     = MODE.glowFalloff     or 2.0
	CORE_BOOST       = MODE.coreBoost       or 1.0
	HUE_JITTER       = MODE.hueJitter       or 0.0
	GLOW_BREATH      = MODE.glowBreath      or 0.0
	GLOW_BREATH_FREQ = MODE.glowBreathFreq  or 0.0
	SIZE_PULSE_AMP   = MODE.sizePulseAmp    or 0.0
	SIZE_PULSE_FREQ  = MODE.sizePulseFreq   or 0.0
	WHITE_HOTSPOT           = MODE.whiteHotspot          or 0.0
	WHITE_HOTSPOT_THRESHOLD = MODE.whiteHotspotThreshold or 0.7
	SHAPE_ID         = SHAPE_IDS[MODE.shape or "cube"] or 0
	ROT_VAL_BASE     = MODE.rotValBase
	ROT_VEL_BASE     = MODE.rotVelBase  / GAME_SPEED
	ROT_ACC_BASE     = MODE.rotAccBase  / (GAME_SPEED * GAME_SPEED)
	ROT_VAL_RANGE    = MODE.rotValRange
	ROT_VEL_RANGE    = MODE.rotVelRange / GAME_SPEED
	ROT_ACC_RANGE    = MODE.rotAccRange / (GAME_SPEED * GAME_SPEED)
end

applyRenderMode(RENDER_MODE)

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local nanoVBO
local nanoShader
local isShapeMode = false        -- set in initGL4 once shader path is decided
local lastLosUniform = -1       -- cache to skip redundant SetUniform calls

-- Active particle bookkeeping. The InstanceVBOTable instanceID is our handle.
local nextID = 1

-- Death-frame buckets: deathBuckets[deathFrame] = { id1, id2, ... }
-- Cull walks the bucket for the current frame only -> O(deaths/frame) instead
-- of O(live) per cull pass.
local deathBuckets = {}
local liveCount    = 0  -- approximate live (incremented on spawn, decremented on cull)

-- Shared scratch table reused for every pushElementInstance call -- avoids
-- allocating a fresh 16-element array per spawn (thousands per second).
local instanceScratch = { 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0 }

-- Per-builder cache: avoids re-fetching nano pieces / team color every frame.
-- builderID -> info table, or false sentinel for non-builders / teamless units.
local builderCache = {}

-- Set of all known builder unit IDs (not camera-culled, unlike GetVisibleUnits).
-- Maintained via Unit{Created,Finished,Destroyed,Given,Taken,EnteredLos} callins.
-- Stored as both a hash (for O(1) membership tests) and an array (for fast
-- numeric-for iteration in the per-frame scan).
local trackedBuilders     = {}  -- unitID -> arrayIndex (also used as membership set)
local trackedBuildersList = {}  -- arrayIndex -> unitID

-- Forward declaration so the Initialize/GameFrame callins can call into it.
local trackUnit

-- Cached visibility state
local cachedAllyTeamID   = spGetMyAllyTeamID()
local cachedSpecFullView = false

-- Debug instrumentation: timers + per-30f Echo. Toggle to true to profile.
local DEBUG        = false
local _dbgFrame    = 0
local _dbgEmits    = 0
local _dbgBuilders = 0
local _dbgWithTask = 0
local _dbgTRescan  = 0  -- GetAllUnits rescan time
local _dbgTScan    = 0  -- scanBuilders time
local _dbgTCull    = 0  -- cullDead time
local _dbgTDraw    = 0  -- DrawWorld time (incl. cull)
local _dbgDraws    = 0

local function refreshSpec()
	local spec, fullView = spGetSpectatingState()
	cachedSpecFullView = spec and fullView
	cachedAllyTeamID   = spGetMyAllyTeamID()
end

-- High gamespeed throttle. When the engine is running faster than 1x (e.g.
-- client reconnecting to an in-progress game and catching up on queued sim
-- frames) scanBuilders fires many times per render frame and can dominate
-- the Lua budget. Ramp an extra throttle factor from 0 at GAMESPEED_THROTTLE_START
-- to 1 at GAMESPEED_THROTTLE_FULL, and use it at scan time to:
--   * cap effective particle pool to (1 - 0.5 * throttle) * MAX_PARTICLES
--     (i.e. down to 50% at full throttle),
--   * multiply emitProb by (1 - GAMESPEED_EMIT_CUT * throttle) so fewer
--     spawn events happen per visited builder.
-- Refreshed in GameFrame on a 1s cadence; cheap (one Spring.GetGameSpeed call).
local GAMESPEED_THROTTLE_START = 1.5   -- below this, no extra throttle
local GAMESPEED_THROTTLE_FULL  = 5.0   -- at or above this, full throttle
local GAMESPEED_EMIT_CUT       = 0.66   -- emitProb cut at full throttle (0..1)
local GAMESPEED_MAX_CUT        = 0.85   -- effective-max cut at full throttle (0..1)
local speedThrottle = 0.0              -- 0 = none, 1 = max (set in GameFrame)

local function refreshSpeedThrottle()
	local _, speedFactor = Spring.GetGameSpeed()
	if not speedFactor or speedFactor <= GAMESPEED_THROTTLE_START then
		speedThrottle = 0.0
		return
	end
	local t = (speedFactor - GAMESPEED_THROTTLE_START)
	        / (GAMESPEED_THROTTLE_FULL - GAMESPEED_THROTTLE_START)
	if t < 0 then t = 0 elseif t > 1 then t = 1 end
	speedThrottle = t
end

-- Cached infoTex-is-LOS state. Spring.GetMapDrawMode() returns the active
-- mini-map mode ("" / "los" / "height" / "metal" / "path"); when it's not LOS,
-- the engine's $info texture holds that other map data and our LOS smoothstep
-- in the FS would treat most of the map as fogged and discard fragments.
-- Polled on the same 1s GameFrame cadence as the speed throttle -- the user
-- toggles map view modes via hotkeys / gfx menu, so 1s latency is invisible.
local cachedInfoIsLos = true
local function refreshInfoIsLos()
	local m = Spring.GetMapDrawMode()
	cachedInfoIsLos = (m == nil or m == "" or m == "los")
end

--------------------------------------------------------------------------------
-- Shaders
--------------------------------------------------------------------------------

local vsSrc = [[
#version 430 core

// Per-vertex (rect VBO: xy in [-1,1], uv in [0,1])
layout(location = 0) in vec4 vertexPosUV;

// Per-instance
layout(location = 1) in vec4 spawnPosAndSize;   // xyz=spawnPos, w=packed(sizeMult,fadeFrames)
layout(location = 2) in vec4 velAndSpawnFrame;  // xyz=velocity, w=spawnFrame
layout(location = 3) in vec4 instColor;         // rgba team color
layout(location = 4) in vec4 rotData;           // x=rotVal0, y=rotVel0, z=rotAcc, w=deathFrame

//__ENGINEUNIFORMBUFFERDEFS__

uniform float drawRadius;
uniform float glowScale;      // quad expansion factor (1.0 = no glow)
uniform float glowIntensity;  // peak outer-falloff brightness (0.0 = no glow)
uniform float sizePulseAmp;   // \u00b1 fractional size oscillation (0 = no pulse)
uniform float sizePulseFreq;  // size pulse frequency (cycles/sim-second)

out vec2 v_uv;
out vec4 v_color;
out vec3 v_worldPos;
out float v_seed;        // stable per-particle seed for FS jitter (radians)

void main() {
	float currentFrame = timeInfo.x + timeInfo.w; // sub-frame interpolated
	float spawnFrame   = velAndSpawnFrame.w;
	float deathFrame   = rotData.w;

	// Cull dead particles by collapsing to a degenerate point off-screen
	if (currentFrame >= deathFrame) {
		gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
		v_uv = vec2(0.0);
		v_color = vec4(0.0);
		v_seed = 0.0;
		return;
	}

	float t = currentFrame - spawnFrame;
	if (t < 0.0) t = 0.0;

	// World-space center: pos = spawn + vel * elapsed
	vec3 worldPos = spawnPosAndSize.xyz + velAndSpawnFrame.xyz * t;

	// Decode packed w: floor sizeMult times 256 in low 1024, fadeFrames times 1024 above.
	float fadeFrames = floor(spawnPosAndSize.w / 1024.0);
	float sizeMult   = (spawnPosAndSize.w - fadeFrames * 1024.0) / 256.0;

	// End-of-life alpha fade: ramps from 1 to 0 over the last fadeFrames frames.
	// fadeFrames == 0 disables the fade.
	float fade = 1.0;
	if (fadeFrames > 0.5) {
		fade = clamp((deathFrame - currentFrame) / fadeFrames, 0.0, 1.0);
	}

	// Engine rotation model: rotVel = rotVel0 + rotAcc*t; rotVal = rotVal0 + rotVel*t
	float rotVel = rotData.y + rotData.z * t;
	float rotVal = rotData.x + rotVel  * t;
	float rotRad = radians(rotVal);
	float c = cos(rotRad);
	float s = sin(rotRad);

	// Per-particle stable seed (radians). rotData.x is the per-spawn random
	// in degrees; converting to radians gives a uniform [-pi, pi] hash that
	// homing won't perturb (rotData is never rewritten in-place).
	float seed = radians(rotData.x);

	// Subtle size pulsation. Using absolute currentFrame (not t) keeps the
	// pulse phase stable across homing rewrites.
	float pulseScale = 1.0;
	if (sizePulseAmp > 0.0001) {
		float ph = currentFrame * sizePulseFreq * (6.2831853 / 30.0) + seed;
		pulseScale = 1.0 + sizePulseAmp * sin(ph);
	}

	float size = drawRadius * sizeMult * glowScale * pulseScale;
	vec3 right = cameraViewInv[0].xyz;
	vec3 up    = cameraViewInv[1].xyz;

	// Rotate quad corner around camera-forward
	vec2 corner = vertexPosUV.xy; // in [-1,1]
	vec2 rotCorner = vec2(c * corner.x - s * corner.y, s * corner.x + c * corner.y);

	vec3 offset = (right * rotCorner.x + up * rotCorner.y) * size;

	gl_Position = cameraViewProj * vec4(worldPos + offset, 1.0);

	v_uv       = vertexPosUV.zw;
	v_color    = instColor * fade;  // premultiplied-alpha fade (blend = ONE, 1-SRC_ALPHA)
	v_worldPos = worldPos;
	v_seed     = seed;
}
]]

local fsSrcDebug = [[
#version 430 core

//__ENGINEUNIFORMBUFFERDEFS__

uniform sampler2D nanoTex;
uniform sampler2D infoTex;
uniform float losAlwaysVisible;

in vec2 v_uv;
in vec4 v_color;
in vec3 v_worldPos;
out vec4 fragColor;

void main() {
	// Solid magenta with the team-color alpha so we can immediately see whether
	// any particles are being submitted at all. Premultiplied for the ONE,
	// 1-SRC_ALPHA blend in DrawWorld.
	float a = 0.5;
	fragColor = vec4(1.0 * a, 0.0, 1.0 * a, a);
}
]]

local fsSrc = [[
#version 430 core

//__ENGINEUNIFORMBUFFERDEFS__

uniform sampler2D nanoTex;
uniform sampler2D infoTex;        // engine $info texture (LOS in .rgb)
uniform float losAlwaysVisible;   // 1.0 for spectator full-view, else 0.0
uniform float glowScale;          // quad expansion factor; core lives in inner 1/glowScale
uniform float glowIntensity;      // peak alpha of the outer radial falloff (0.0 = off)
uniform float glowFalloff;        // falloff exponent: 1.0 linear, 2.0 quadratic (bloomy),
                                  // 4.0+ sharp initial drop then long faint tail
uniform float coreBoost;          // brightness multiplier for the textured core (>=1.0)
uniform float hueJitter;          // \u00b1 per-channel modulation amplitude (0 = off)
uniform float glowBreath;         // halo intensity oscillation amplitude (0..1)
uniform float glowBreathFreq;     // halo oscillation frequency (cycles/sim-second)
uniform float cubeNoise;             // brightness noise on the textured core (0 = off)
uniform float cubeNoiseSpeed;        // noise time-scroll rate
uniform float cubeNoiseScale;        // noise spatial frequency (UV space)
uniform float whiteHotspot;          // peak strength of noise->white mix on the core (0 = off)
uniform float whiteHotspotThreshold; // noise value where hotspot ramp starts (0..1)

in vec2  v_uv;
in vec4  v_color;
in vec3  v_worldPos;
in float v_seed;
out vec4 fragColor;

// Cheap 2D value noise -- billboard analog of the cube FS's valueNoise3. Same
// Hoskins hash + quintic fade; one fewer dimension because billboards have no
// useful object-local Z. The per-particle v_seed offsets the sample so adjacent
// sprites don't sparkle in lockstep.
float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 31.32);
	return fract((p3.x + p3.y) * p3.z);
}
float valueNoise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float n00 = hash12(i + vec2(0.0, 0.0));
	float n10 = hash12(i + vec2(1.0, 0.0));
	float n01 = hash12(i + vec2(0.0, 1.0));
	float n11 = hash12(i + vec2(1.0, 1.0));
	vec2 nx = mix(vec2(n00, n01), vec2(n10, n11), f.x);
	return mix(nx.x, nx.y, f.y);
}

void main() {
	// Early LOS discard: test before the nanoTex fetch so fogged fragments skip
	// the texture bandwidth entirely.
	float losMul = 1.0;
	if (losAlwaysVisible < 0.5) {
		vec2 losUV = clamp(v_worldPos.xz, vec2(0.0), mapSize.xy) / mapSize.zw;
		float los = dot(vec3(0.3333), texture(infoTex, losUV).rgb);
		losMul = smoothstep(0.30, 0.50, los);
		if (losMul < 0.02) discard;
	}

	// Radial distance from the quad center in [0..1] at the outer edge.
	vec2  centered = v_uv * 2.0 - 1.0;
	float rd       = length(centered);
	if (rd > 1.0) discard;

	// Per-particle hue jitter: cheap pseudo-hue rotation by phase-shifted sin
	// per channel. Centered on 1.0 so the average tint matches team color.
	vec3 tint = vec3(1.0);
	if (hueJitter > 0.0001) {
		tint = vec3(1.0) + hueJitter * vec3(
			sin(v_seed),
			sin(v_seed + 2.094),    // +120 degrees
			sin(v_seed + 4.188));   // +240 degrees
	}

	// Core occupies the inner 1/glowScale of the expanded quad. Sample the
	// nanoTex with uv remapped so the blob covers that inner disc exactly at
	// its original size (glowScale == 1.0 reproduces the pre-glow look).
	float coreEdge = 1.0 / max(glowScale, 1.0);
	float mask     = 0.0;
	float noiseVal = 0.5;  // neutral default when cubeNoise + whiteHotspot are off
	if (rd < coreEdge) {
		vec2 coreUV = centered / coreEdge * 0.5 + 0.5;
		vec4 tex    = texture(nanoTex, coreUV);
		mask        = max(dot(tex.rgb, vec3(0.3333)), tex.a) * coreBoost;

		// Per-particle animated value noise on the core, sampled in quad-UV
		// space (the cube path samples in object-local 3D coords, but billboards
		// have no useful local Z so we use UV + a per-particle seed offset).
		if (cubeNoise > 0.001 || whiteHotspot > 0.001) {
			float tt = (timeInfo.x + timeInfo.w) * cubeNoiseSpeed * (1.0 / 30.0);
			vec2 samp = centered * cubeNoiseScale + vec2(v_seed * 7.13, v_seed * 3.57)
			          + vec2(tt, tt * 0.7);
			noiseVal = valueNoise2(samp);
			if (cubeNoise > 0.001) {
				mask *= 1.0 + cubeNoise * (noiseVal * 2.0 - 1.0);
			}
		}
	}

	// Outer radial falloff: smooth ring from coreEdge out to 1.0. The glowFalloff
	// exponent controls the curve shape: 1.0 = linear (even fade), 2.0 = quadratic
	// (classic bloomy halo), higher values (4-8) = sharp initial drop with a long
	// faint tail, reading more as a sharp corona than a soft blob.
	float glow = 0.0;
	if (glowIntensity > 0.0 && glowScale > 1.001) {
		float t = clamp((1.0 - rd) / (1.0 - coreEdge), 0.0, 1.0);
		float gI = glowIntensity;
		// Animated halo "breath": small intensity oscillation, per-particle
		// phase-offset so adjacent halos don't pulse in lockstep.
		if (glowBreath > 0.0001) {
			float ph = (timeInfo.x + timeInfo.w) * glowBreathFreq * (6.2831853 / 30.0) + v_seed;
			gI *= 1.0 + glowBreath * sin(ph);
		}
		glow = pow(t, max(glowFalloff, 0.01)) * gI;
	}

	float combined = (mask + glow);
	vec3  rgb = v_color.rgb * tint * combined;
	float a   = v_color.a   * combined;

	// White hotspot overlay on the textured core. Premultiplied-alpha caveat:
	// rgb here is (team_color * tint * combined), and v_color.a is the per-
	// emission alpha (small, ~0.04). Mixing rgb toward vec3(a) does almost
	// nothing because the target is the same low magnitude. Instead we ADD
	// a white energy spark in premultiplied space: contribution is
	//     rgbAdd = vec3(mask * v_color.a * hotspot * whiteHotspot)
	//     aAdd   = mask * v_color.a * hotspot * whiteHotspot
	// Multiplying by mask confines it to the textured core (no halo
	// whitening), multiplying by v_color.a keeps it consistent with the rest
	// of the premultiplied-alpha pipeline, and the noise->smoothstep gate
	// keeps only the high-noise peaks bright.
	// boost so the hotspot ramps up at birth too.
	if (whiteHotspot > 0.0001 && mask > 0.0) {
		float hotspot = smoothstep(whiteHotspotThreshold, 1.0, noiseVal) * whiteHotspot;
		float spark   = mask * v_color.a * hotspot;
		rgb += vec3(spark);
		a   += spark;
	}

	fragColor = vec4(rgb, a) * losMul;
}
]]

--------------------------------------------------------------------------------
-- Cube render mode shaders
--   VS: pass per-instance attrs + computed worldPos/fade/rotData through.
--   GS: receives 3 verts of the dummy quad's first triangle (gated on
--       gl_PrimitiveIDIn==0 so we emit one cube per instance, not two).
--       Builds a 3D rotation matrix from rotVal driving 3 axes at slightly
--       different rates (per-particle phase from a hash of spawnPos), then
--       emits 6 face quads with face normals for cheap directional shading.
--   FS: untextured -- multiplies team color by per-face brightness; LOS fade
--       same as billboard path.
--------------------------------------------------------------------------------

local vsSrcCube = [[
#version 430 core

layout(location = 0) in vec4 vertexPosUV;
layout(location = 1) in vec4 spawnPosAndSize;   // xyz=spawnPos, w=packed(sizeMult,fadeFrames)
layout(location = 2) in vec4 velAndSpawnFrame;  // xyz=velocity, w=spawnFrame
layout(location = 3) in vec4 instColor;
layout(location = 4) in vec4 rotData;           // x=rotVal0, y=rotVel0, z=rotAcc, w=deathFrame

//__ENGINEUNIFORMBUFFERDEFS__

out vec3 v_worldPos;
out vec4 v_color;
out float v_rotVal;
out float v_dead;
out vec3 v_phaseSeed;
out float v_sizeMult;

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
		return;
	}
	v_dead = 0.0;

	float t = currentFrame - spawnFrame;
	if (t < 0.0) t = 0.0;

	vec3 worldPos = spawnPosAndSize.xyz + velAndSpawnFrame.xyz * t;

	// Decode packed w: sizeMult in low 1024, fadeFrames * 1024 above.
	float fadeFrames = floor(spawnPosAndSize.w / 1024.0);
	float sizeMult   = (spawnPosAndSize.w - fadeFrames * 1024.0) / 256.0;

	float fade = (fadeFrames > 0.5)
		? clamp((deathFrame - currentFrame) / fadeFrames, 0.0, 1.0)
		: 1.0;

	float rotVel = rotData.y + rotData.z * t;
	float rotVal = rotData.x + rotVel  * t;

	v_worldPos = worldPos;
	v_color    = instColor * fade;
	v_rotVal   = rotVal;
	v_sizeMult = sizeMult;
	// Stable per-particle seed for cube tumble phase. Homing rewrites spawnPos
	// every frame, so we hash spawn-time random rotData (untouched by homing)
	// instead -- otherwise the phase jumps and the cube rotation goes wild.
	v_phaseSeed = rotData.xyz;
	gl_Position = vec4(worldPos, 1.0);  // GS reads this
}
]]

local gsSrcCube = [[
#version 430 core

layout(triangles) in;
// 28 = worst case across supported shapes:
//   cube: 6 quads * 4 verts = 24 + 4 glow billboard verts
//   octahedron: 8 tris * 3 verts = 24 + 4 glow billboard verts
// Larger polyhedra (icosahedron, dodecahedron) would exceed
// MAX_GEOMETRY_TOTAL_OUTPUT_COMPONENTS (1024 on most GPUs) given our ~22
// per-vertex output components, so they aren't supported here.
layout(triangle_strip, max_vertices = 28) out;

//__ENGINEUNIFORMBUFFERDEFS__

uniform float drawRadius;
uniform int   u_shape;   // 0=cube, 1=octahedron
uniform float glowScale;     // billboard halo scale relative to shape size
uniform float glowIntensity; // 0 = no halo emitted

in vec3  v_worldPos[];
in vec4  v_color[];
in float v_rotVal[];
in float v_dead[];
in vec3  v_phaseSeed[];
in float v_sizeMult[];

out vec4 g_color;
out vec3 g_normal;
out vec3 g_worldPos;
out vec3 g_localPos;     // pre-translation cube-local position for stable noise sampling
out vec3 g_noiseSeed;    // per-particle noise offset (so cubes don't all sparkle in lockstep)
out vec2 g_glowUV;       // [-1..1] across the glow billboard (zero on shape verts)
out float g_isGlow;      // 0 = shape face, 1 = glow halo billboard
out float g_seed;        // stable per-particle seed (radians) for FS jitter

float hash11(float x) {
	return fract(sin(x) * 43758.5453);
}

mat3 rotXYZ(vec3 a) {
	float cx = cos(a.x), sx = sin(a.x);
	float cy = cos(a.y), sy = sin(a.y);
	float cz = cos(a.z), sz = sin(a.z);
	mat3 Rx = mat3(1,0,0, 0,cx,sx, 0,-sx,cx);
	mat3 Ry = mat3(cy,0,-sy, 0,1,0, sy,0,cy);
	mat3 Rz = mat3(cz,sz,0, -sz,cz,0, 0,0,1);
	return Rz * Ry * Rx;
}

// Emit one quad face: 4 corners as a triangle strip, then EndPrimitive. Inputs
// are local-space corner offsets pre-multiplied by the rotation matrix and
// scaled by size.
void emitFace(vec3 c0, vec3 c1, vec3 c2, vec3 c3, vec3 n, vec3 center, vec4 col, vec3 noiseSeed, float seed) {
	g_color = col;
	g_normal = n;
	g_noiseSeed = noiseSeed;
	g_isGlow = 0.0;
	g_glowUV = vec2(0.0);
	g_seed = seed;
	g_localPos = c0; g_worldPos = center + c0; gl_Position = cameraViewProj * vec4(g_worldPos, 1.0); EmitVertex();
	g_localPos = c1; g_worldPos = center + c1; gl_Position = cameraViewProj * vec4(g_worldPos, 1.0); EmitVertex();
	g_localPos = c2; g_worldPos = center + c2; gl_Position = cameraViewProj * vec4(g_worldPos, 1.0); EmitVertex();
	g_localPos = c3; g_worldPos = center + c3; gl_Position = cameraViewProj * vec4(g_worldPos, 1.0); EmitVertex();
	EndPrimitive();
}

// Emit one triangle face. Used by the octahedron path.
void emitTri(vec3 c0, vec3 c1, vec3 c2, vec3 n, vec3 center, vec4 col, vec3 noiseSeed, float seed) {
	g_color = col;
	g_normal = n;
	g_noiseSeed = noiseSeed;
	g_isGlow = 0.0;
	g_glowUV = vec2(0.0);
	g_seed = seed;
	g_localPos = c0; g_worldPos = center + c0; gl_Position = cameraViewProj * vec4(g_worldPos, 1.0); EmitVertex();
	g_localPos = c1; g_worldPos = center + c1; gl_Position = cameraViewProj * vec4(g_worldPos, 1.0); EmitVertex();
	g_localPos = c2; g_worldPos = center + c2; gl_Position = cameraViewProj * vec4(g_worldPos, 1.0); EmitVertex();
	EndPrimitive();
}

// Emit one camera-facing quad as the soft halo around the shape. The FS
// branches on g_isGlow to do radial falloff using g_glowUV instead of the
// face-shading path.
void emitGlow(vec3 center, vec4 col, float halfSize, float seed) {
	vec3 right = cameraViewInv[0].xyz * halfSize;
	vec3 up    = cameraViewInv[1].xyz * halfSize;
	g_color = col;
	g_normal = vec3(0.0, 1.0, 0.0);
	g_noiseSeed = vec3(0.0);
	g_localPos = vec3(0.0);
	g_isGlow = 1.0;
	g_seed = seed;
	g_glowUV = vec2(-1.0, -1.0); g_worldPos = center - right - up; gl_Position = cameraViewProj * vec4(g_worldPos, 1.0); EmitVertex();
	g_glowUV = vec2( 1.0, -1.0); g_worldPos = center + right - up; gl_Position = cameraViewProj * vec4(g_worldPos, 1.0); EmitVertex();
	g_glowUV = vec2(-1.0,  1.0); g_worldPos = center - right + up; gl_Position = cameraViewProj * vec4(g_worldPos, 1.0); EmitVertex();
	g_glowUV = vec2( 1.0,  1.0); g_worldPos = center + right + up; gl_Position = cameraViewProj * vec4(g_worldPos, 1.0); EmitVertex();
	EndPrimitive();
}

void main() {
	if (v_dead[0] > 0.5) return;
	// Cube mode uses a 3-index VBO (one triangle per instance) so GS runs
	// exactly once per particle -- no need for a gl_PrimitiveIDIn gate.

	vec3 center = v_worldPos[0];
	float size  = drawRadius * v_sizeMult[0];

	// Stable per-particle noise offset, scaled into a wide range so adjacent
	// particles sample completely different noise regions instead of overlapping.
	vec3 noiseSeed = v_phaseSeed[0] * 137.0 + vec3(11.0, 47.0, 83.0);

	// Per-particle phase from a stable spawn-time seed (NOT spawnPos -- that
	// gets rewritten every frame by homing). Three axis rates with slightly
	// different multipliers give a constantly-evolving tumble.
	float h  = dot(v_phaseSeed[0], vec3(0.123, 0.456, 0.789));
	vec3 phase = vec3(hash11(h), hash11(h+1.7), hash11(h+3.3)) * 6.2831853;
	float r = radians(v_rotVal[0]);
	vec3 ang = phase + vec3(r * 1.0, r * 1.3, r * 0.7);
	mat3 R = rotXYZ(ang);

	vec4 col = v_color[0];

	// Stable per-particle seed for FS hue jitter / glow breath. v_phaseSeed.x
	// is the spawn-time random rotData.x in degrees -> wrap to radians.
	float seed = radians(v_phaseSeed[0].x);

	if (u_shape == 1) {
		// ---- OCTAHEDRON ---- 6 vertices on the axes, 8 triangle faces.
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
		// Top hemisphere (apex Y), CCW from outside.
		emitTri(Y,  Z,  X,  nPPP, center, col, noiseSeed, seed);
		emitTri(Y, nX,  Z,  nNPP, center, col, noiseSeed, seed);
		emitTri(Y, nZ, nX,  nNPN, center, col, noiseSeed, seed);
		emitTri(Y,  X, nZ,  nPPN, center, col, noiseSeed, seed);
		// Bottom hemisphere (apex nY).
		emitTri(nY,  X,  Z,  nPNP, center, col, noiseSeed, seed);
		emitTri(nY,  Z, nX,  nNNP, center, col, noiseSeed, seed);
		emitTri(nY, nX, nZ,  nNNN, center, col, noiseSeed, seed);
		emitTri(nY, nZ,  X,  nPNN, center, col, noiseSeed, seed);

	} else {
		// ---- CUBE (default) ---- 8 corners, 6 quad faces.
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

	// Optional camera-facing halo around the shape. One extra quad per particle.
	if (glowIntensity > 0.0 && glowScale > 1.001) {
		emitGlow(center, col, size * glowScale, seed);
	}
}
]]

local fsSrcCube = [[
#version 430 core

//__ENGINEUNIFORMBUFFERDEFS__

uniform sampler2D infoTex;
uniform float losAlwaysVisible;
uniform float cubeShowInside;   // 0 = flat shading, 1 = view-dependent 3D look
uniform float cubeNoise;        // 0 = no noise, 1 = full ±noise brightness modulation
uniform float cubeNoiseSpeed;   // animation rate (time scroll)
uniform float cubeNoiseScale;   // spatial frequency in object-local units
uniform float glowIntensity;    // peak alpha of the halo (0 = halo verts emit nothing)
uniform float glowFalloff;      // halo radial falloff exponent
uniform float coreBoost;        // brightness multiplier for the lit faces (>=1.0)
uniform float hueJitter;        // \u00b1 per-channel modulation amplitude (0 = off)
uniform float glowBreath;       // halo intensity oscillation amplitude (0..1)
uniform float glowBreathFreq;   // halo oscillation frequency (cycles/sim-second)
uniform float whiteHotspot;          // peak strength of noise->white mix on faces (0 = off)
uniform float whiteHotspotThreshold; // noise value where hotspot ramp starts (0..1)

in vec4 g_color;
in vec3 g_normal;
in vec3 g_worldPos;
in vec3 g_localPos;
in vec3 g_noiseSeed;
in vec2 g_glowUV;
in float g_isGlow;
in float g_seed;
out vec4 fragColor;

// Cheap 3D value noise: 8 corner hashes + quintic fade. The quintic fade
// (f*f*f*(f*(f*6-15)+10)) has a continuous second derivative, so integer-cell
// boundaries don't show as visible creases the way they do with a cubic
// smoothstep. Combined with the per-particle g_noiseSeed offset, this is
// sufficient to mask the grid without needing a second fbm octave.
//
// hash uses Dave Hoskins' hash-without-sine (https://www.shadertoy.com/view/4djSRW).
// Avoid the classic IQ hash `fract(p.x*p.y*p.z*(p.x+p.y+p.z))` -- the product
// collapses to near-zero whenever any component is near zero, producing visible
// axis-aligned dark planes through the noise volume (shows up as a straight
// band on the cube faces).
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
	// Early LOS discard -- bail before ANY shading/noise work for fogged
	// fragments. Saves the view-dir, noise, and normalize math when a particle
	// spawns in unseen territory.
	float losMul = 1.0;
	if (losAlwaysVisible < 0.5) {
		vec2 losUV = clamp(g_worldPos.xz, vec2(0.0), mapSize.xy) / mapSize.zw;
		float los = dot(vec3(0.3333), texture(infoTex, losUV).rgb);
		losMul = smoothstep(0.30, 0.50, los);
		if (losMul < 0.02) discard;
	}

	// Per-particle hue jitter, identical curve to the billboard FS so both
	// modes drift through the same range of tints.
	vec3 tint = vec3(1.0);
	if (hueJitter > 0.0001) {
		tint = vec3(1.0) + hueJitter * vec3(
			sin(g_seed),
			sin(g_seed + 2.094),
			sin(g_seed + 4.188));
	}

	// Halo path: radial falloff billboard around the shape. Same falloff math
	// as the billboard FS so visuals match across modes.
	if (g_isGlow > 0.5) {
		float rd = length(g_glowUV);
		if (rd > 1.0) discard;
		float t = 1.0 - rd;
		float gI = glowIntensity;
		if (glowBreath > 0.0001) {
			float ph = (timeInfo.x + timeInfo.w) * glowBreathFreq * (6.2831853 / 30.0) + g_seed;
			gI *= 1.0 + glowBreath * sin(ph);
		}
		float glow = pow(clamp(t, 0.0, 1.0), max(glowFalloff, 0.01)) * gI;
		fragColor = vec4(g_color.rgb * tint * glow, g_color.a * glow) * losMul;
		return;
	}

	vec3 N = normalize(g_normal);

	// Sun-style directional shading -- always on so faces are distinguishable
	// regardless of camera angle.
	vec3 lightDir = normalize(vec3(0.4, 1.0, 0.25));
	float dirShade = 0.85 + 0.15 * max(dot(N, lightDir), 0.0);

	float shade = dirShade;
	float aMul  = 1.0;

	// 3D view-dependent shading: only computed when enabled (skip the viewDir
	// normalize + ndv work entirely when cubeShowInside is off).
	if (cubeShowInside > 0.001) {
		vec3 viewDir = normalize(cameraViewInv[3].xyz - g_worldPos);
		float ndv = dot(N, viewDir);
		float shade3D, alpha3D;
		if (ndv >= 0.0) {
			shade3D = 0.80 + 0.45 * (1.0 - ndv);    // front: edge-rim boost
			alpha3D = 1.0;
		} else {
			shade3D = 0.30 + 0.30 * (-ndv);         // back: dim but visible
			alpha3D = 0.55;
		}
		shade = mix(dirShade, dirShade * shade3D, cubeShowInside);
		aMul  = mix(1.0,      alpha3D,            cubeShowInside);
	}

	// Animated face noise: sampled in object-local space (rides along with the
	// tumbling cube) with a per-particle seed offset so cubes don't sparkle in
	// lockstep. Single-octave value noise with quintic fade -- cheap and the
	// per-particle offset hides any residual grid structure.
	float noiseVal = 0.5;  // neutral default when cubeNoise == 0
	if (cubeNoise > 0.001 || whiteHotspot > 0.001) {
		float tt = (timeInfo.x + timeInfo.w) * cubeNoiseSpeed * (1.0 / 30.0);
		vec3 samp = g_localPos * cubeNoiseScale + g_noiseSeed + vec3(tt, tt * 0.7, tt * 1.3);
		noiseVal = valueNoise3(samp);
		if (cubeNoise > 0.001) {
			shade *= 1.0 + cubeNoise * (noiseVal * 2.0 - 1.0);
		}
	}

	// Team-tinted base color with hue jitter and face shading baked in.
	vec3 baseRgb = g_color.rgb * tint * shade * coreBoost;

	// White hotspot overlay: reuses the animated noise so bright regions
	// crawl across faces over time. Threshold + smoothstep keeps only the
	// high-noise peaks whitening, so the team color dominates everywhere else.
	if (whiteHotspot > 0.0001) {
		float hotspot = smoothstep(whiteHotspotThreshold, 1.0, noiseVal) * whiteHotspot;
		baseRgb = mix(baseRgb, vec3(1.0) * max(shade, 0.6), hotspot);
	}

	fragColor = vec4(baseRgb, g_color.a * aMul) * losMul;
}
]]

--------------------------------------------------------------------------------
-- Init / shutdown
--------------------------------------------------------------------------------

local function goodbye(reason)
	spEcho("Nano Particles GL4 exiting: " .. tostring(reason))
	gadgetHandler:RemoveGadget()
end

local function initGL4()
	local shapeMode = (RENDER_MODE == "shape")
	if shapeMode and not LuaShader.isGeometryShaderSupported then
		spEcho("Nano Particles GL4: geometry shader not supported, falling back to billboard mode.")
		shapeMode = false
	end
	isShapeMode = shapeMode
	local shaderCache = {
		vsSrc = shapeMode and vsSrcCube or vsSrc,
		fsSrc = shapeMode and fsSrcCube or (DEBUG_FLAT_FS and fsSrcDebug or fsSrc),
		gsSrc = shapeMode and gsSrcCube or nil,
		shaderName = shapeMode and "NanoParticlesGL4_Shape" or "NanoParticlesGL4",
		uniformInt = shapeMode and { infoTex = 1, u_shape = SHAPE_ID } or { nanoTex = 0, infoTex = 1 },
		uniformFloat = { losAlwaysVisible = 0, drawRadius = DRAW_RADIUS, cubeShowInside = CUBE_SHOW_INSIDE,
		                 cubeNoise = CUBE_NOISE, cubeNoiseSpeed = CUBE_NOISE_SPEED, cubeNoiseScale = CUBE_NOISE_SCALE,
		                 glowScale = GLOW_SCALE, glowIntensity = GLOW_INTENSITY, glowFalloff = GLOW_FALLOFF,
		                 coreBoost = CORE_BOOST,
		                 hueJitter = HUE_JITTER, glowBreath = GLOW_BREATH, glowBreathFreq = GLOW_BREATH_FREQ,
		                 sizePulseAmp = SIZE_PULSE_AMP, sizePulseFreq = SIZE_PULSE_FREQ,
		                 whiteHotspot = WHITE_HOTSPOT, whiteHotspotThreshold = WHITE_HOTSPOT_THRESHOLD },
		shaderConfig = {},
		forceupdate = true,
	}
	nanoShader = LuaShader.CheckShaderUpdates(shaderCache)
	if not nanoShader then
		goodbye("Failed to compile shader")
		return false
	end

	-- Quad: xy in [-1,1] (corner), uv in [0,1]
	local quadVBO, numVertices = InstanceVBOTable.makeRectVBO(
		-1, -1, 1, 1,
		0, 0, 1, 1,
		"nanoQuadVBO"
	)
	local indexVBO
	if shapeMode then
		-- Shape GS only needs ONE triangle per instance; using the rect's 2-tri
		-- index buffer would invoke the GS twice per particle. A 3-index VBO
		-- (the rect's first triangle: bl,tl,tr) cuts GS work in half.
		indexVBO = gl.GetVBO(GL.ELEMENT_ARRAY_BUFFER, false)
		indexVBO:Define(3)
		indexVBO:Upload({0, 1, 2})
	else
		indexVBO = InstanceVBOTable.makeRectIndexVBO("nanoQuadIndexVBO")
	end

	local layout = {
		{ id = 1, name = "spawnPosAndSize",  size = 4 },
		{ id = 2, name = "velAndSpawnFrame", size = 4 },
		{ id = 3, name = "instColor",        size = 4 },
		{ id = 4, name = "rotData",          size = 4 },
	}
	nanoVBO = InstanceVBOTable.makeInstanceVBOTable(layout, MAX_PARTICLES_VBO, "nanoParticleVBO")
	if not nanoVBO then
		goodbye("Failed to create instance VBO")
		return false
	end
	nanoVBO.numVertices = numVertices
	nanoVBO.vertexVBO   = quadVBO
	nanoVBO.indexVBO    = indexVBO
	nanoVBO.VAO         = nanoVBO:makeVAOandAttach(quadVBO, nanoVBO.instanceVBO, indexVBO)
	nanoVBO.primitiveType = GL.TRIANGLES

	return true
end

local function cleanupGL4()
	if nanoVBO then nanoVBO:Delete(); nanoVBO = nil end
end

--------------------------------------------------------------------------------
-- Builder cache
--------------------------------------------------------------------------------

-- Negative cache is keyed by UnitDefID so newly-built units of a known builder
-- type always re-resolve, while non-builder defs are skipped cheaply.
local nonBuilderDefs = {}

-- Team color cache: spGetTeamColor is a Spring->C call; teamID -> {r, g, b}.
-- Colors can change mid-game (commshare, alliance, modoptions), so a periodic
-- refresh in GameFrame re-fetches every cached team and propagates any change
-- into the per-builder info entries via builderCacheByTeam[team] = {info, ...}.
local teamColorCache    = {}
local builderCacheByTeam = {}  -- teamID -> array of info tables (for color propagation)
local function getTeamColor(team)
	local c = teamColorCache[team]
	if c then return c[1], c[2], c[3] end
	local r, g, b = spGetTeamColor(team)
	teamColorCache[team] = { r, g, b }
	return r, g, b
end

local function refreshTeamColors()
	-- Rebuild per-team buckets from the live builderCache to drop stale entries
	-- left behind by Destroyed/Given/Taken. Cheap; runs every few seconds and
	-- builderCache size scales with active builders.
	for team in pairs(builderCacheByTeam) do
		builderCacheByTeam[team] = nil
	end
	for _, info in pairs(builderCache) do
		local team = info.team
		local bucket = builderCacheByTeam[team]
		if bucket then
			bucket[#bucket + 1] = info
		else
			builderCacheByTeam[team] = { info }
		end
	end

	for team, c in pairs(teamColorCache) do
		local r, g, b = spGetTeamColor(team)
		if r and (r ~= c[1] or g ~= c[2] or b ~= c[3]) then
			c[1], c[2], c[3] = r, g, b
			local infos = builderCacheByTeam[team]
			if infos then
				for i = 1, #infos do
					local info = infos[i]
					info.r = r; info.g = g; info.b = b
				end
			end
		end
	end
end

-- Per-frame piece-position cache: spGetUnitPiecePosDir is the single most
-- expensive call in emitNano. A builder typically emits multiple particles
-- per frame from the same piece, and even cycles a small set of pieces. Cache
-- by (builderID, pieceIdx) for the duration of one scan frame; invalidated by
-- bumping the epoch each frame instead of clearing the table.
local piecePosCache = {}    -- key = builderID * 256 + pieceIdx -> [epoch, x, y, z]
local piecePosEpoch = 0

-- Per-frame target position cache for the emit path. Many builders frequently
-- work the same target (assist groups, repair clusters), so resolveTarget's
-- spGetUnitPosition / spGetFeaturePosition gets hammered with duplicate calls
-- for the same ID inside one scan frame. Keyed by the raw targetID returned
-- by GetUnitWorkerTask (so feature IDs naturally don't collide with units).
local emitTargetPosCache = {}

-- Reclaim/homing particles: in-flight inverse particles (those travelling
-- back toward a builder) need to bend toward the builder's CURRENT piece
-- position when the builder moves, otherwise the spray converges on a stale
-- spawn-time location. Each frame we re-aim each particle's velocity so that
-- it still arrives at its death frame, but at the new piece position. The
-- particle position formula is `pos = spawn + vel * (frame - spawnFrame)`,
-- so we rewrite spawn to the current pos, vel to (newTarget-currentPos)/
-- remaining, and spawnFrame to the current frame. Death stays the same.
--   homingByBuilder[builderID] = { {id=, pieceIdx=, death=}, ... }
local homingByBuilder = {}
local HOMING_MAX_PER_BUILDER = 96   -- safety cap; oldest entries drop off

-- Forward homing: outbound particles aimed at a UNIT target (repair, capture)
-- need to bend toward the target's CURRENT mid-position when the target moves
-- mid-flight. Same rewrite trick as inverse: keep death frame, rewrite spawn
-- to current pos, vel toward new target, spawnFrame to current frame.
--   homingFwdByTarget[targetUnitID] = { {id=, death=}, ... }
-- Keyed by target so we resolve each target's position once per frame.
local homingFwdByTarget = {}
local targetPosCache    = {}    -- unitID -> [epoch, x, y, z]
local targetIncompleteCache = {} -- unitID -> [epoch, isBeingBuilt]
local HOMING_FWD_MAX_PER_TARGET = 192   -- safety cap per repaired/captured unit

local function getBuilderInfo(builderID)
	local cached = builderCache[builderID]
	if cached then return cached end

	local udid = spGetUnitDefID(builderID)
	if not udid then return nil end
	if nonBuilderDefs[udid] then return nil end

	local pieces = spGetUnitNanoPieces(builderID)
	if not pieces or #pieces == 0 then
		-- Per-unit transient (likely out of LOS); do NOT blacklist the def,
		-- otherwise the first out-of-LOS instance poisons the whole type.
		return nil
	end
	local team = spGetUnitTeam(builderID)
	if not team then return nil end -- transient (e.g. during creation), retry next frame

	local r, g, b = getTeamColor(team)
	local ud = UnitDefs[udid]
	local info = {
		pieces    = pieces,
		nPieces   = #pieces,
		r = r, g = g, b = b,
		team      = team,
		allyTeam  = spGetUnitAllyTeam(builderID),
		isFactory = ud and ud.isFactory or false,
	}
	builderCache[builderID] = info
	local bucket = builderCacheByTeam[team]
	if bucket then
		bucket[#bucket + 1] = info
	else
		builderCacheByTeam[team] = { info }
	end
	return info
end

-- Engine: gsRNG.NextInt(cnt) - random pick each call.
local function pickNanoPiece(pieces, n)
	if n == 1 then return pieces[1] end
	return pieces[mathRandom(n)]
end

--------------------------------------------------------------------------------
-- Emission
--------------------------------------------------------------------------------

local function spawnParticle(px, py, pz, vx, vy, vz, lifetime, r, g, b, frame, fadeFrames)
	if not nanoVBO then return end

	local death = frame + lifetime

	local rotVal = ROT_VAL_BASE + ROT_VAL_RANGE * (mathRandom() * 2 - 1)
	local rotVel = ROT_VEL_BASE + ROT_VEL_RANGE * (mathRandom() * 2 - 1)
	local rotAcc = ROT_ACC_BASE + ROT_ACC_RANGE * (mathRandom() * 2 - 1)

	-- Per-particle size and alpha jitter. Size is packed into w alongside
	-- fadeFrames; alpha replaces the flat NANO_ALPHA in the color attribute.
	local sizeMult = (SIZE_VAR > 0) and (1.0 + SIZE_VAR * (mathRandom() * 2 - 1)) or 1.0
	local alpha    = (ALPHA_VAR > 0) and (NANO_ALPHA * (1.0 + ALPHA_VAR * (mathRandom() * 2 - 1))) or NANO_ALPHA
	if alpha < 0 then alpha = 0 end

	local id = nextID
	nextID = nextID + 1

	local s = instanceScratch
	s[1]=px; s[2]=py; s[3]=pz;  s[4]=packSizeFade(sizeMult, fadeFrames)
	s[5]=vx; s[6]=vy; s[7]=vz;  s[8]=frame
	s[9]=r;  s[10]=g; s[11]=b;  s[12]=alpha
	s[13]=rotVal; s[14]=rotVel; s[15]=rotAcc; s[16]=death

	if pushElementInstance(nanoVBO, s, id, false, true, nil) then
		local bucket = deathBuckets[death]
		if bucket then
			bucket[#bucket + 1] = id
		else
			deathBuckets[death] = { id }
		end
		liveCount = liveCount + 1
		return id
	end
end

local function emitNano(builderID, info, endX, endY, endZ, inverse, jitterRadius, frame, targetUnitID)
	local pieceIdx = pickNanoPiece(info.pieces, info.nPieces)

	-- Spring.GetUnitPiecePosDir is the hot Spring->C call here. Within a single
	-- scan frame the same builder/piece often emits multiple particles (resurrect
	-- dual-emit, factories, multi-piece cycling) -- cache by (unitID, pieceIdx)
	-- and invalidate via per-frame epoch bump.
	local key = builderID * 256 + pieceIdx
	local entry = piecePosCache[key]
	local sx, sy, sz
	if entry and entry[1] == piecePosEpoch then
		sx, sy, sz = entry[2], entry[3], entry[4]
	else
		sx, sy, sz = spGetUnitPiecePosDir(builderID, pieceIdx)
		if not sx then return end
		if entry then
			entry[1] = piecePosEpoch
			entry[2] = sx; entry[3] = sy; entry[4] = sz
		else
			piecePosCache[key] = { piecePosEpoch, sx, sy, sz }
		end
	end

	local dx, dy, dz = endX - sx, endY - sy, endZ - sz
	local lenSq = dx*dx + dy*dy + dz*dz
	if lenSq < 1.0 then return end
	local len = mathSqrt(lenSq)
	local invLen = 1.0 / len
	dx, dy, dz = dx * invLen, dy * invLen, dz * invLen

	-- Engine: dif += guRNG.NextVector() * jitterScale, where NextVector() is
	-- rejection-sampled inside the unit sphere (GlobalRNG.h). Builders pass a
	-- per-task radius and the jitter scale is (radius / len); factories use a
	-- fixed 0.15. (See ProjectileHandler::AddNanoParticle overloads.)
	local jitterScale = jitterRadius and (jitterRadius * invLen) or DIR_JITTER
	local jx, jy, jz
	repeat
		jx = mathRandom() * 2 - 1
		jy = mathRandom() * 2 - 1
		jz = mathRandom() * 2 - 1
	until (jx*jx + jy*jy + jz*jz) <= 1.0
	dx = dx + jx * jitterScale
	dy = dy + jy * jitterScale
	dz = dz + jz * jitterScale

	local speed = NANO_SPEED
	if SPEED_VAR > 0 then
		speed = NANO_SPEED * (1.0 + SPEED_VAR * (mathRandom() * 2 - 1))
		if speed < 0.1 then speed = 0.1 end
	end
	local vx, vy, vz = dx * speed, dy * speed, dz * speed
	local lifetime = mathFloor(len / speed)
	if lifetime < 1 then return end

	-- Engine (ProjectileHandler::AddNanoParticle, inverse branch):
	--   pos   = startPos + dif * len    (dif is normalized+jitter)
	--   speed = -dif * 3.0
	-- This makes the particle converge exactly on startPos (the builder).
	-- Spawning at the raw endPos would carry the jitter offset all the way
	-- through and the spray would diverge instead of converge.
	local px, py, pz
	if inverse then
		px = sx + dx * len
		py = sy + dy * len
		pz = sz + dz * len
		vx, vy, vz = -vx, -vy, -vz
	else
		px, py, pz = sx, sy, sz
	end

	-- LOS filter: enemy emissions hidden when not in our LOS / not full view.
	-- Throttled per builder: LOS at the builder location changes slowly relative
	-- to the emit rate; one IsPosInLos per builder per LOS_CACHE_FRAMES is plenty.
	if LOS_FILTER and not cachedSpecFullView then
		if info.allyTeam ~= cachedAllyTeamID then
			local losFrame = info.losFrame
			local visible
			if losFrame and (frame - losFrame) < LOS_CACHE_FRAMES then
				visible = info.losVisible
			else
				visible = spIsPosInLos(px, py, pz, cachedAllyTeamID) and true or false
				info.losFrame   = frame
				info.losVisible = visible
			end
			if not visible then return end
		end
	end

	local pid = spawnParticle(px, py, pz, vx, vy, vz, lifetime, info.r, info.g, info.b, frame,
		inverse and FADE_FRAMES_RECLAIM or FADE_FRAMES_REPAIR)

	-- Inverse particles converge on the builder. If the builder moves before
	-- the particle dies, the original straight-line trajectory ends at a stale
	-- location. Track the particle so applyHoming() can re-aim it each frame.
	if inverse and pid then
		local list = homingByBuilder[builderID]
		if not list then
			list = {}
			homingByBuilder[builderID] = list
		end
		local n = #list
		if n >= HOMING_MAX_PER_BUILDER then
			-- Drop oldest by sliding (rare; only triggers on heavy reclaimers).
			for i = 1, n - 1 do list[i] = list[i + 1] end
			list[n] = { id = pid, pieceIdx = pieceIdx, death = frame + lifetime }
		else
			list[n + 1] = { id = pid, pieceIdx = pieceIdx, death = frame + lifetime }
		end
	elseif (not inverse) and pid and targetUnitID then
		-- Forward emission aimed at a moving unit (repair/capture). Track so
		-- applyForwardHoming() can curve the particle toward the target's new
		-- position when it moves. Store the per-particle landing offset (the
		-- engine's jitter encodes a unique end-point per particle) so the spray
		-- spread is preserved at the destination as the target moves.
		if HOMING_SKIP_INCOMPLETE then
			local entry = targetIncompleteCache[targetUnitID]
			local beingBuilt
			if entry and entry[1] == piecePosEpoch then
				beingBuilt = entry[2]
			else
				beingBuilt = spGetUnitIsBeingBuilt(targetUnitID) and true or false
				if entry then
					entry[1] = piecePosEpoch; entry[2] = beingBuilt
					if beingBuilt then entry[3] = frame end
				else
					targetIncompleteCache[targetUnitID] = { piecePosEpoch, beingBuilt, beingBuilt and frame or -1 }
				end
			end
			if beingBuilt then return end
			-- Grace window: still skip for a short time after completion so the
			-- last particles don't chase the unit as it rolls out.
			local lastIncompleteFrame = entry and entry[3] or -1
			if lastIncompleteFrame >= 0 and (frame - lastIncompleteFrame) < HOMING_SKIP_GRACE_FRAMES then
				return
			end
		end
		local landingX = sx + dx * len
		local landingY = sy + dy * len
		local landingZ = sz + dz * len
		local offX = landingX - endX
		local offY = landingY - endY
		local offZ = landingZ - endZ
		local list = homingFwdByTarget[targetUnitID]
		if not list then
			list = {}
			homingFwdByTarget[targetUnitID] = list
		end
		local n = #list
		if n >= HOMING_FWD_MAX_PER_TARGET then
			for i = 1, n - 1 do list[i] = list[i + 1] end
			list[n] = { id = pid, death = frame + lifetime, ox = offX, oy = offY, oz = offZ }
		else
			list[n + 1] = { id = pid, death = frame + lifetime, ox = offX, oy = offY, oz = offZ }
		end
	end
end

--------------------------------------------------------------------------------
-- Worker task -> target position resolution
-- Returns (endX, endY, endZ, inverse, jitterRadius) or nil.
-- Per-builder cache holds the immutable bits (factor, isReclaim/isResurrect,
-- isFeature, radius, jitterRadius). Position is refreshed every call (units
-- move; features are static but the call is just as cheap either way).
--------------------------------------------------------------------------------

local function resolveTarget(info, cmdID, targetID)
	if not targetID then return nil end

	local meta = info.targetMeta
	if not meta or meta.cmdID ~= cmdID or meta.targetID ~= targetID then
		-- Engine returns featureID + MaxUnits() for feature reclaim / resurrect.
		local rawID = targetID
		local resolvedID = rawID
		local isUnit = false
		local isFeature = false
		if rawID >= MAX_UNITS then
			resolvedID = rawID - MAX_UNITS
			isFeature = spValidFeatureID(resolvedID)
		else
			isUnit = spValidUnitID(rawID)
			if not isUnit then
				isFeature = spValidFeatureID(rawID)
			end
		end
		if not (isUnit or isFeature) then
			info.targetMeta = nil
			return nil
		end

		local accept, factor, isReclaim, isResurrect = false, 0.5, false, false
		if cmdID == CMD_RECLAIM then
			accept, factor, isReclaim = (isUnit or isFeature), 0.7, true
		elseif cmdID == CMD_RESURRECT then
			accept, factor, isResurrect = (isUnit or isFeature), 0.7, true
		elseif cmdID == CMD_CAPTURE then
			accept, factor = isUnit, 0.7
		elseif cmdID < 0 or cmdID == CMD_REPAIR then
			accept, factor = isUnit, 0.5
		end
		if not accept then
			info.targetMeta = nil
			return nil
		end

		local radius = isUnit and spGetUnitRadius(resolvedID) or spGetFeatureRadius(resolvedID)
		local jitterRadius = (radius and radius > 0) and (radius * factor) or nil

		meta = {
			cmdID        = cmdID,
			targetID     = targetID,    -- raw value from GetUnitWorkerTask (for cache key)
			resolvedID   = resolvedID,  -- engine ID (with MaxUnits offset stripped)
			isFeature    = isFeature or false,
			jitterRadius = jitterRadius,
			isReclaim    = isReclaim,
			isResurrect  = isResurrect,
		}
		info.targetMeta = meta
	end

	local px, py, pz
	local cached = emitTargetPosCache[meta.targetID]
	if cached and cached[1] == piecePosEpoch then
		px, py, pz = cached[2], cached[3], cached[4]
	else
		if meta.isFeature then
			px, py, pz = spGetFeaturePosition(meta.resolvedID)
		else
			-- spGetUnitPosition(uid, true) returns 6 values: base + mid. We want mid.
			local _, _, _, mx, my, mz = spGetUnitPosition(meta.resolvedID, true)
			px, py, pz = mx, my, mz
		end
		if px then
			if cached then
				cached[1] = piecePosEpoch
				cached[2] = px; cached[3] = py; cached[4] = pz
			else
				emitTargetPosCache[meta.targetID] = { piecePosEpoch, px, py, pz }
			end
		end
	end
	if not px then
		info.targetMeta = nil
		return nil
	end

	local inverse, isResurrect
	if meta.isReclaim then
		inverse = true
	elseif meta.isResurrect then
		-- Engine emits TWO particles per frame for resurrect: one outbound and
		-- one inbound, giving the characteristic two-way spray. We return the
		-- outbound here and signal the caller to emit a second inbound one.
		inverse, isResurrect = false, true
	else
		inverse = false
	end
	return px, py, pz, inverse, meta.jitterRadius, isResurrect, (not meta.isFeature) and meta.resolvedID or nil
end

--------------------------------------------------------------------------------
-- Per-frame homing: re-aim in-flight inverse particles toward the builder's
-- current piece position, so reclaim sprays curve when the builder moves
-- mid-flight instead of converging on a stale point. Returns updated
-- (dirtyMin, dirtyMax) range in 0-based slot indices for VBO upload.
--------------------------------------------------------------------------------

local function applyHoming(frame, dirtyMin, dirtyMax)
	if not nanoVBO then return dirtyMin, dirtyMax end
	-- Fast-path: avoid pairs() VM setup when nothing is in flight.
	if next(homingByBuilder) == nil then return dirtyMin, dirtyMax end
	local data       = nanoVBO.instanceData
	local idtoIndex  = nanoVBO.instanceIDtoIndex
	local step       = nanoVBO.instanceStep

	for builderID, list in pairs(homingByBuilder) do
		local info = builderCache[builderID]
		if not info or not spValidUnitID(builderID) then
			homingByBuilder[builderID] = nil
		else
			local writeIdx = 0
			-- Hoist the high half of the piecePosCache key out of the per-particle
			-- loop. Hot path: ~thousands of particles per scan in heavy reclaim.
			local builderKeyHi = builderID * 256
			for i = 1, #list do
				local p = list[i]
				local remaining = p.death - frame
				local slot = (remaining > 1) and idtoIndex[p.id] or nil
				if slot then
					-- Resolve current piece position via the per-frame cache.
					local pieceIdx = p.pieceIdx
					local key = builderKeyHi + pieceIdx
					local entry = piecePosCache[key]
					local nx, ny, nz
					if entry and entry[1] == piecePosEpoch then
						nx, ny, nz = entry[2], entry[3], entry[4]
					else
						nx, ny, nz = spGetUnitPiecePosDir(builderID, pieceIdx)
						if nx then
							if entry then
								entry[1] = piecePosEpoch
								entry[2] = nx; entry[3] = ny; entry[4] = nz
							else
								piecePosCache[key] = { piecePosEpoch, nx, ny, nz }
							end
						end
					end

					if nx then
						local base = (slot - 1) * step
						local sx, sy, sz   = data[base+1], data[base+2], data[base+3]
						local vx, vy, vz   = data[base+5], data[base+6], data[base+7]
						local spawnF       = data[base+8]
						local elapsed      = frame - spawnF
						local cpx = sx + vx * elapsed
						local cpy = sy + vy * elapsed
						local cpz = sz + vz * elapsed
						-- Inverse particles all converge on the builder piece (engine
						-- behaviour: speed = -dif*3 makes pos arrive at startPos exactly).
						-- Visual spread comes from staggered spawn positions, not from
						-- the velocity direction, so simple aim is correct here.
						local invR = 1.0 / remaining
						data[base+1] = cpx;            data[base+2] = cpy;            data[base+3] = cpz
						data[base+5] = (nx - cpx) * invR
						data[base+6] = (ny - cpy) * invR
						data[base+7] = (nz - cpz) * invR
						data[base+8] = frame
						local s0 = slot - 1
						if s0 < dirtyMin     then dirtyMin = s0     end
						if s0 + 1 > dirtyMax then dirtyMax = s0 + 1 end
						writeIdx = writeIdx + 1
						list[writeIdx] = p
					end
				end
			end
			-- Trim dropped entries (dead, missing slot, or no piece pos).
			for j = #list, writeIdx + 1, -1 do list[j] = nil end
			if writeIdx == 0 then
				homingByBuilder[builderID] = nil
			end
		end
	end
	return dirtyMin, dirtyMax
end

--------------------------------------------------------------------------------
-- Per-frame forward homing: re-aim outbound particles aimed at moving units
-- (repair, capture) toward the target's current mid-position. Same in-place
-- spawn/vel/spawnFrame rewrite as inverse homing; death frame preserved.
--------------------------------------------------------------------------------

-- Forward declaration: applyForwardHoming triggers this when a target hits full
-- HP, but the implementation lives further down with the other death handlers.
local fadeOutHomingFwd

local targetPosEpoch = 0

local function applyForwardHoming(frame, dirtyMin, dirtyMax)
	if not nanoVBO then return dirtyMin, dirtyMax end
	if next(homingFwdByTarget) == nil then return dirtyMin, dirtyMax end
	local data       = nanoVBO.instanceData
	local idtoIndex  = nanoVBO.instanceIDtoIndex
	local step       = nanoVBO.instanceStep

	targetPosEpoch = targetPosEpoch + 1

	for targetID, list in pairs(homingFwdByTarget) do
		if not spValidUnitID(targetID) then
			homingFwdByTarget[targetID] = nil
		else
			-- Detect "work complete" (full HP and buildProgress >= 1) -- this fires
			-- when a repair finishes or a unit is just-built. Trigger the same
			-- per-particle death fade as UnitDestroyed so the trailing spray
			-- dissolves instead of getting yanked off when the builder moves on.
			-- Throttled per target: stagger by targetID so checks spread across
			-- frames instead of all firing on the same one. Use the call-tick
			-- (frame / HOMING_RUN_EVERY) rather than raw frame -- otherwise raw
			-- frame is always a multiple of HOMING_RUN_EVERY here, and target
			-- IDs whose modulus doesn't line up never satisfy the check.
			local fadedOut = false
			local checkTick = mathFloor(frame / HOMING_RUN_EVERY)
			if ((checkTick + targetID) % REPAIRED_CHECK_EVERY) == 0 then
				local h, maxH, _, _, bp = spGetUnitHealth(targetID)
				if h and maxH and h >= maxH and (bp == nil or bp >= 1.0) then
					fadeOutHomingFwd(targetID)
					homingFwdByTarget[targetID] = nil
					targetPosCache[targetID]    = nil
					fadedOut = true
				end
			end
			if not fadedOut then
			-- Cache layout per target: { epoch, tx, ty, tz, lastTx, lastTy, lastTz, stationaryStreak }
			-- stationaryStreak counts consecutive homing passes the target has
			-- not moved. Once it crosses STATIONARY_SKIP_AFTER, we skip the
			-- per-particle rewrite entirely until the target moves again --
			-- spawn-time aim is already correct for stationary targets.
			local entry = targetPosCache[targetID]
			local tx, ty, tz
			if entry and entry[1] == targetPosEpoch then
				tx, ty, tz = entry[2], entry[3], entry[4]
			else
				-- spGetUnitPosition(uid, true) returns 6 values; want mid (4,5,6).
				local _, _, _, mx, my, mz = spGetUnitPosition(targetID, true)
				tx, ty, tz = mx, my, mz
				if tx then
					if entry then
						entry[1] = targetPosEpoch
						entry[2] = tx; entry[3] = ty; entry[4] = tz
					else
						entry = { targetPosEpoch, tx, ty, tz, tx, ty, tz, 0 }
						targetPosCache[targetID] = entry
					end
				end
			end

			if not tx then
				homingFwdByTarget[targetID] = nil
				targetPosCache[targetID]    = nil
			else
				-- Stationary detection: compare current pos to last-seen pos.
				-- Threshold is generous (1 elmo) -- builders sub-elmo wobble doesn't
				-- count as movement. Streak resets on any movement.
				local moved = true
				if entry[5] then
					local ddx = tx - entry[5]
					local ddy = ty - entry[6]
					local ddz = tz - entry[7]
					if ddx*ddx + ddy*ddy + ddz*ddz < 1.0 then moved = false end
				end
				if moved then
					entry[5] = tx; entry[6] = ty; entry[7] = tz
					entry[8] = 0
				else
					entry[8] = (entry[8] or 0) + 1
				end

				if entry[8] >= STATIONARY_SKIP_AFTER then
					-- Stationary: just trim dead/missing particles from list,
					-- skip the expensive per-particle rewrite. Spawn-time
					-- velocity already aims at the (still-correct) target.
					local writeIdx = 0
					for i = 1, #list do
						local p = list[i]
						if (p.death - frame) > 1 and idtoIndex[p.id] then
							writeIdx = writeIdx + 1
							list[writeIdx] = p
						end
					end
					for j = #list, writeIdx + 1, -1 do list[j] = nil end
					if writeIdx == 0 then
						homingFwdByTarget[targetID] = nil
						targetPosCache[targetID]    = nil
					end
				else
				local writeIdx = 0
				for i = 1, #list do
					local p = list[i]
					local remaining = p.death - frame
					local slot = (remaining > 1) and idtoIndex[p.id] or nil
					if slot then
						local base = (slot - 1) * step
						local sx, sy, sz   = data[base+1], data[base+2], data[base+3]
						local vx, vy, vz   = data[base+5], data[base+6], data[base+7]
						local spawnF       = data[base+8]
						local elapsed      = frame - spawnF
						local cpx = sx + vx * elapsed
						local cpy = sy + vy * elapsed
						local cpz = sz + vz * elapsed
						-- Aim at target + per-particle landing offset. The offset is the
						-- engine's jitter-driven spread point for this specific particle,
						-- so the spray width at the destination is preserved as the
						-- target moves.
						local aimX = tx + p.ox
						local aimY = ty + p.oy
						local aimZ = tz + p.oz
						local invR = 1.0 / remaining
						data[base+1] = cpx;            data[base+2] = cpy;            data[base+3] = cpz
						data[base+5] = (aimX - cpx) * invR
						data[base+6] = (aimY - cpy) * invR
						data[base+7] = (aimZ - cpz) * invR
						data[base+8] = frame
						local s0 = slot - 1
						if s0 < dirtyMin     then dirtyMin = s0     end
						if s0 + 1 > dirtyMax then dirtyMax = s0 + 1 end
						writeIdx = writeIdx + 1
						list[writeIdx] = p
					end
				end
				for j = #list, writeIdx + 1, -1 do list[j] = nil end
				if writeIdx == 0 then
					homingFwdByTarget[targetID] = nil
					targetPosCache[targetID]    = nil
				end
			end -- end of stationary-skip if/else
			end -- end of "not tx" else
			end -- end of "not fully repaired" else
		end
	end
	return dirtyMin, dirtyMax
end

--------------------------------------------------------------------------------
-- Per-frame builder scan
--------------------------------------------------------------------------------

local function scanBuilders(frame)
	-- Engine emits nano particles for every active builder regardless of camera
	-- frustum. Iterate the tracked builder set; LOS filtering happens in emitNano.

	-- Bump the per-frame epoch so cached piece positions from previous frames
	-- are implicitly invalidated without clearing the table.
	piecePosEpoch = piecePosEpoch + 1

	-- Snapshot pre-scan tail so we can do ONE upload covering all spawns
	-- pushed this frame. Pushes use noUpload=true; we upload the [first..last]
	-- contiguous range here (spawns always append, so the new range is
	-- guaranteed contiguous at the tail).
	local preUsed = nanoVBO and nanoVBO.usedElements or 0

	-- Engine-style saturation gate evaluated per-emission. Pre-computed once so
	-- we can skip the per-builder math (GetUnitPiecePosDir, sqrt, RNG, target
	-- resolution) for the majority of dropped emissions when at capacity.
	-- Under a high-gamespeed catchup, shrink the effective cap so saturation
	-- ramps up faster and the existing stride/runEvery math does more work
	-- per scan (fewer per-builder calls even at nominal pool fill).
	local effectiveMax = MAX_PARTICLES
	if speedThrottle > 0.0 then
		effectiveMax = MAX_PARTICLES * (1.0 - GAMESPEED_MAX_CUT * speedThrottle)
	end
	local saturation = liveCount / effectiveMax
	if saturation >= 1.0 then return end

	-- Dynamic scan-frame skip: at empty pool we run every sim frame (full
	-- responsiveness), at saturated pool we run once per MAX_SCAN_RUN_EVERY
	-- frames (the saturation gate would drop most emissions anyway). emitProb
	-- scales by runEvery so total emission rate is preserved across the ramp.
	local runEvery = MIN_SCAN_RUN_EVERY + math.floor(saturation * (MAX_SCAN_RUN_EVERY - MIN_SCAN_RUN_EVERY) + 0.5)
	if runEvery < 1 then runEvery = 1 end
	if (frame % runEvery) ~= 0 then return end

	-- Camera position for the per-emit distance throttle. One call per scan.
	-- The squared-distance band constants (near/far/inv/drop) live at module
	-- scope -- DISTANT_EMIT_* never change at runtime so there's no point
	-- recomputing them per call.
	local camX, camY, camZ = spGetCameraPosition()

	-- Dynamic stride: linearly grow with saturation. Empty pool -> stride 1
	-- (full fidelity); near full -> MAX_SCAN_STRIDE (skip most builders, since
	-- the gate would drop them anyway). emitProb is scaled by stride so the
	-- total per-builder emission rate is preserved.
	local stride = MIN_SCAN_STRIDE + math.floor(saturation * (MAX_SCAN_STRIDE - MIN_SCAN_STRIDE) + 0.5)
	if stride < 1 then stride = 1 end
	local emitProb = (1.0 - saturation) * stride * runEvery
	if speedThrottle > 0.0 then
		emitProb = emitProb * (1.0 - GAMESPEED_EMIT_CUT * speedThrottle)
	end

	-- Pool-saturation-driven offscreen keep-fraction. Cheap (one branch + one
	-- lerp), recomputed once per scan so all per-emit checks below use the
	-- same value.
	local offscreenKeep
	if saturation <= OFFSCREEN_EMIT_KEEP_SAT_PIVOT then
		offscreenKeep = OFFSCREEN_EMIT_KEEP_MAX
	else
		local t = (saturation - OFFSCREEN_EMIT_KEEP_SAT_PIVOT) * OFFSCREEN_EMIT_KEEP_BAND_INV
		offscreenKeep = OFFSCREEN_EMIT_KEEP_MAX + t * (OFFSCREEN_EMIT_KEEP_MIN - OFFSCREEN_EMIT_KEEP_MAX)
	end
	if emitProb > 1.0 then emitProb = 1.0 end

	local list = trackedBuildersList
	local n    = #list
	-- Use the scan-call counter (frame / runEvery) for the stride offset
	-- rather than the raw frame. Otherwise runEvery=2 + stride=2 means frame
	-- is always even, frame%stride is always 0, and even-indexed builders
	-- are never visited.
	local scanTick = mathFloor(frame / runEvery)
	local start = (scanTick % stride) + 1
	for i = start, n, stride do
		if emitProb >= 1.0 or mathRandom() < emitProb then
			local unitID = list[i]
			-- Cheap idle filter: a builder with no current build power is not
			-- emitting nano particles this frame (walking, queued, blocked,
			-- paused, or simply has no orders). Skipping these saves the
			-- builder-cache lookup AND the worker-task lookup, which together
			-- dominate per-builder cost when most builders sit idle.
			-- Throttled: cache result on the per-builder info table for a few
			-- frames (transitions to/from idle are slower than this).
			local info = getBuilderInfo(unitID)
			if info then
				local bp
				local bpFrame = info.bpFrame
				if bpFrame and (frame - bpFrame) < BUILD_POWER_CACHE_FRAMES then
					bp = info.bp
				else
					bp = spGetUnitCurrentBuildPower(unitID)
					info.bpFrame = frame
					info.bp      = bp
				end
				if bp and bp > 0 then
					if DEBUG then _dbgBuilders = _dbgBuilders + 1 end
					-- Throttled worker-task lookup. spGetUnitWorkerTask is the
					-- single most expensive engine call in this scan when many
					-- builders are active. Builder-task transitions happen on a
					-- timescale of seconds; caching for a few frames is invisible.
					local cmdID, targetID
					local taskFrame = info.taskFrame
					if taskFrame and (frame - taskFrame) < WORKER_TASK_CACHE_FRAMES then
						cmdID, targetID = info.cmdID, info.targetID
					else
						cmdID, targetID = spGetUnitWorkerTask(unitID)
						info.taskFrame = frame
						info.cmdID     = cmdID
						info.targetID  = targetID
					end
					if cmdID then
						if DEBUG then _dbgWithTask = _dbgWithTask + 1 end
						local ex, ey, ez, inverse, jitterRadius, isResurrect, targetUnitID = resolveTarget(info, cmdID, targetID)
						if ex then
							-- Off-screen throttle. Test view-frustum at the target
							-- endpoint (covers the whole spray for a builder near its
							-- target -- the typical case). Cached on targetMeta and
							-- invalidated by piecePosEpoch so each builder pays at most
							-- one IsSphereInView per scan frame, and the dropped
							-- emissions skip emitNano entirely (no piece pos, no
							-- jitter RNG, no homing register).
							if offscreenKeep < 1.0 then
								local meta = info.targetMeta
								local visible
								if meta and meta.visEpoch == piecePosEpoch then
									visible = meta.visible
								else
									visible = spIsSphereInView(ex, ey, ez, 64) and true or false
									if meta then
										meta.visEpoch = piecePosEpoch
										meta.visible  = visible
									end
								end
								if not visible and mathRandom() > offscreenKeep then
									ex = nil
								end
							end
							-- Distance throttle. Below near-range we keep all; in the
							-- ramp band we lerp keep-fraction (in squared-distance,
							-- which biases more aggressive culling toward the far end);
							-- beyond far-range we clamp to DISTANT_EMIT_KEEP.
							if ex and DISTANT_EMIT_KEEP < 1.0 then
								local ddx = ex - camX
								local ddy = ey - camY
								local ddz = ez - camZ
								local d2 = ddx*ddx + ddy*ddy + ddz*ddz
								if d2 > DISTANT_EMIT_NEAR_SQ then
									local keep
									if d2 >= DISTANT_EMIT_FAR_SQ then
										keep = DISTANT_EMIT_KEEP
									else
										local t = (d2 - DISTANT_EMIT_NEAR_SQ) * DISTANT_EMIT_BAND_INV
										keep = 1.0 - DISTANT_EMIT_DROP * t
									end
									if mathRandom() > keep then
										ex = nil
									end
								end
							end
						end
						if ex then
							if DEBUG then _dbgEmits = _dbgEmits + 1 end
							-- Factories always use the engine's fixed 0.15 jitter regardless of buildee size.
							if info.isFactory then jitterRadius = nil end
							emitNano(unitID, info, ex, ey, ez, inverse, jitterRadius, frame, targetUnitID)
							-- Resurrect: emit the matching inbound particle so the spray
							-- visibly travels both ways at once (engine behaviour).
							if isResurrect then
								emitNano(unitID, info, ex, ey, ez, true, jitterRadius, frame, nil)
							end
						end
					elseif info.targetMeta then
						info.targetMeta = nil  -- builder went idle; drop stale cache
					end
				end
			end
		end
	end

	-- Flush all spawns AND in-place homing rewrites in a single upload. Spawns
	-- are always at the tail [preUsed .. postUsed); homing rewrites can touch
	-- arbitrary slots. Take the union and upload once. (uploadElementRange uses
	-- 0-based start, exclusive-end form -- compare uploadAllElements which
	-- passes usedElements directly as the end argument.)
	if nanoVBO then
		local dirtyMin, dirtyMax = math.huge, -1
		-- Run the in-place re-aim passes on a slower cadence than the scan.
		-- They rewrite per-particle pos/vel for every live homed particle
		-- (potentially thousands) and only need to keep up with target
		-- movement, which is slow vs particle speed.
		if (frame % HOMING_RUN_EVERY) == 0 then
			dirtyMin, dirtyMax = applyHoming(frame, dirtyMin, dirtyMax)
			dirtyMin, dirtyMax = applyForwardHoming(frame, dirtyMin, dirtyMax)
		end
		local postUsed = nanoVBO.usedElements
		if postUsed > preUsed then
			if preUsed  < dirtyMin then dirtyMin = preUsed  end
			if postUsed > dirtyMax then dirtyMax = postUsed end
		end
		if dirtyMax > dirtyMin then
			uploadElementRange(nanoVBO, dirtyMin, dirtyMax)
		end
	end
end

--------------------------------------------------------------------------------
-- Per-frame: cull dead particles. Called from GameFrame (deaths only advance
-- once per sim frame, no point doing this per render frame).
--------------------------------------------------------------------------------

local function cullDead(frame)
	local bucket = deathBuckets[frame]
	if not bucket then return end
	local nb = #bucket
	-- Per-pop upload: each call uploads only the one swapped slot's range
	-- (~64B). Tried batching with uploadAllElements but that re-marshals the
	-- entire instanceData Lua table (~8000*16 numbers) and was much slower.
	for i = 1, nb do
		popElementInstance(nanoVBO, bucket[i], false)
	end
	liveCount = liveCount - nb
	deathBuckets[frame] = nil
end

--------------------------------------------------------------------------------
-- Callins
--------------------------------------------------------------------------------

-- Switch to a new NanoParticleMode (0 engine / 1 billboards / 2 shapes).
-- Tears down GL resources when leaving 1/2, rebuilds them with the right
-- shader pair when entering 1/2, and keeps the engine's MaxNanoParticles
-- budget in sync so we never double-spray.
local function applyParticleMode(newMode, force)
	if (not force) and newMode == NANO_PARTICLE_MODE and nanoVBO ~= nil then return end
	if (not force) and newMode == NANO_PARTICLE_MODE and newMode == 0 then return end

	NANO_PARTICLE_MODE = newMode

	-- Clear all in-flight homing references; their VBO slots are about to be
	-- destroyed (or we're entering mode 0 where they're meaningless).
	for k in pairs(homingByBuilder)     do homingByBuilder[k]     = nil end
	for k in pairs(homingFwdByTarget)   do homingFwdByTarget[k]   = nil end
	for k in pairs(targetPosCache)      do targetPosCache[k]      = nil end
	for k in pairs(targetIncompleteCache) do targetIncompleteCache[k] = nil end
	for k in pairs(deathBuckets)        do deathBuckets[k]        = nil end
	liveCount = 0

	cleanupGL4()

	if newMode == 0 then
		-- Hand the spray budget back to the engine.
		Spring.SetConfigInt("MaxNanoParticles", math.floor(Spring.GetConfigInt("MaxParticles", 15000) * 0.34))
		return
	end

	-- Modes 1/2: silence the engine spray, swap to the matching shader pair.
	Spring.SetConfigInt("MaxNanoParticles", 0)
	applyRenderMode((newMode == 1) and "billboard" or "shape")
	if not initGL4() then
		spEcho("Nano Particles GL4: GL init failed; falling back to engine spray.")
		NANO_PARTICLE_MODE = 0
		Spring.SetConfigInt("MaxNanoParticles", math.floor(Spring.GetConfigInt("MaxParticles", 15000) * 0.34))
	end
end

function gadget:Initialize()
	-- The gadget always stays loaded so it can observe live NanoParticleMode
	-- changes from the gfx options menu. Mode 0 = engine spray: we just leave
	-- nanoVBO unset and skip emission/draw; switching to 1/2 lazy-inits GL.
	applyParticleMode(NANO_PARTICLE_MODE, true)
	refreshSpec()
	-- Seed tracked builder set with units that already exist (handles
	-- /luarules reload mid-game). Tracking runs regardless of mode so that
	-- a later switch to mode 1/2 starts producing particles immediately.
	local all = spGetAllUnits()
	if all then
		for i = 1, #all do
			trackUnit(all[i])
		end
	end
end

function gadget:Shutdown()
	cleanupGL4()
end

function gadget:PlayerChanged()
	refreshSpec()
	-- Player-state transitions can change visible team colors (e.g. take/give,
	-- spec view of recolored teams). Refresh now so the next frame paints right.
	refreshTeamColors()
end

-- Emission once per gameframe (matches the engine's per-frame AddNanoParticle
-- cadence for an active builder).
function gadget:GameFrame(n)
	-- Poll NanoParticleMode. The springsetting is written by the gfx options
	-- UI; engine doesn't fire a callin on change so we sample on a slow tick.
	-- Cheap (one GetConfigInt) and 1s latency on a settings-menu toggle is
	-- imperceptible.
	if n % 30 == 0 then
		local mode = Spring.GetConfigInt("NanoParticleMode", 2)
		if mode ~= NANO_PARTICLE_MODE then
			applyParticleMode(mode, false)
		elseif NANO_PARTICLE_MODE ~= 0 then
			-- Defensive: another widget/gadget (or the user via /set) may have
			-- re-enabled the engine spray underneath us. Re-silence it so we
			-- don't double-spray.
			if Spring.GetConfigInt("MaxNanoParticles", 0) ~= 0 then
				Spring.SetConfigInt("MaxNanoParticles", 0)
			end
		end
		-- Refresh high-gamespeed throttle (reconnect catchup, user /speed) and
		-- the cached map-draw-mode (heightmap / metalmap / pathmap views).
		refreshSpeedThrottle()
		refreshInfoIsLos()
		refreshMaxParticles()
	end

	-- Mode 0 = engine renders the spray; we just track builders for a quick
	-- restart if the user switches back to gadget mode.
	if NANO_PARTICLE_MODE == 0 then return end

	-- Periodic team-color refresh: colors can change mid-game (commshare,
	-- alliance, custom recolor widgets). Cheap (one Spring call per cached
	-- team, only propagates on actual change).
	if n % 150 == 0 then
		refreshTeamColors()
	end

	-- Periodic full rescan as a safety net for callins that don't fire in
	-- unsynced context (e.g. mid-game gadget reloads, spectator transitions).
	-- Unit{Created,Finished,Given,Taken,Destroyed} cover the steady state, so
	-- every 10 seconds is plenty for the safety net.
	if n % 300 == 0 then
		if DEBUG then
			local t0 = spGetTimer()
			local all = spGetAllUnits()
			if all then
				for i = 1, #all do
					local uid = all[i]
					if not trackedBuilders[uid] then
						trackUnit(uid)
					end
				end
			end
			_dbgTRescan = _dbgTRescan + spDiffTimers(spGetTimer(), t0)
		else
			local all = spGetAllUnits()
			if all then
				for i = 1, #all do
					local uid = all[i]
					if not trackedBuilders[uid] then
						trackUnit(uid)
					end
				end
			end
		end
	end

	if DEBUG then
		local t0 = spGetTimer()
		scanBuilders(n)
		_dbgTScan = _dbgTScan + spDiffTimers(spGetTimer(), t0)

		local tc0 = spGetTimer()
		cullDead(n)
		_dbgTCull = _dbgTCull + spDiffTimers(spGetTimer(), tc0)

		_dbgFrame = _dbgFrame + 1
		if _dbgFrame % 30 == 0 then
			spEcho(string.format(
				"[NanoGL4] f=%d tracked=%d busy/30=%d task=%d emit=%d live=%d used=%d  | scan=%.2fms cull=%.2fms draw=%.2fms(x%d) rescan=%.2fms",
				n, #trackedBuildersList, _dbgBuilders, _dbgWithTask, _dbgEmits,
				liveCount, nanoVBO and nanoVBO.usedElements or -1,
				_dbgTScan * 1000, _dbgTCull * 1000, _dbgTDraw * 1000, _dbgDraws,
				_dbgTRescan * 1000))
			_dbgBuilders, _dbgWithTask, _dbgEmits = 0, 0, 0
			_dbgTScan, _dbgTCull, _dbgTDraw, _dbgTRescan, _dbgDraws = 0, 0, 0, 0, 0
		end
	else
		scanBuilders(n)
		cullDead(n)
	end
end

-- Builder tracking ----------------------------------------------------------

function trackUnit(unitID, unitDefID)
	if trackedBuilders[unitID] then return end
	unitDefID = unitDefID or Spring.GetUnitDefID(unitID)
	if not unitDefID then return end
	if nonBuilderDefs[unitDefID] then return end
	local ud = UnitDefs[unitDefID]
	-- Accept anything that can build (buildSpeed > 0): covers commanders,
	-- construction units, factories, nano turrets, resurrectors, etc. The
	-- isBuilder flag is not always set even for things like nano turrets.
	if not ud or not ((ud.buildSpeed or 0) > 0 or ud.isBuilder or ud.isFactory) then
		nonBuilderDefs[unitDefID] = true
		return
	end
	local idx = #trackedBuildersList + 1
	trackedBuildersList[idx] = unitID
	trackedBuilders[unitID]  = idx
end

local function untrackUnit(unitID)
	local idx = trackedBuilders[unitID]
	if not idx then return end
	local n = #trackedBuildersList
	if idx ~= n then
		local swapID = trackedBuildersList[n]
		trackedBuildersList[idx]   = swapID
		trackedBuilders[swapID]    = idx
	end
	trackedBuildersList[n]   = nil
	trackedBuilders[unitID]  = nil
end

function gadget:UnitCreated(unitID, unitDefID)
	trackUnit(unitID, unitDefID)
end

function gadget:UnitFinished(unitID, unitDefID)
	trackUnit(unitID, unitDefID)
end

-- Clear this builder's piecePosCache entries so the cache doesn't grow without
-- bound as builders are created/destroyed over a long match. Called before
-- builderCache is nilled so we still have nPieces to bound the sweep.
local function clearPiecePosCache(unitID)
	local info = builderCache[unitID]
	if not info then return end
	local base = unitID * 256
	for i = 1, info.nPieces do
		piecePosCache[base + info.pieces[i]] = nil
	end
end

function gadget:UnitGiven(unitID, unitDefID)
	clearPiecePosCache(unitID)
	builderCache[unitID] = nil
	trackUnit(unitID, unitDefID)
end

function gadget:UnitTaken(unitID, unitDefID)
	clearPiecePosCache(unitID)
	builderCache[unitID] = nil
	trackUnit(unitID, unitDefID)
end

-- Builder cache invalidation
-- Fade out forward-homing particles aimed at a unit that just died: shorten
-- their deathFrame so the shader's end-of-life alpha ramp kicks in, and zero
-- their velocity so they hang in place instead of chasing through the corpse.
-- Slot reclamation still happens at the original death frame (we don't touch
-- deathBuckets), the shader simply renders nothing in the gap.
-- Fade out forward-homing particles aimed at a unit that just died: shorten
-- their deathFrame so the shader's end-of-life alpha ramp kicks in. Velocity
-- and spawn are left untouched so they keep coasting along their last
-- trajectory (toward where the target was) while fading out, instead of
-- abruptly freezing in mid-air.
-- Slot reclamation still happens at the original death frame (we don't touch
-- deathBuckets), the shader simply renders nothing in the gap.
fadeOutHomingFwd = function(unitID)
	local list = homingFwdByTarget[unitID]
	if not list or not nanoVBO then return end
	local data      = nanoVBO.instanceData
	local idtoIndex = nanoVBO.instanceIDtoIndex
	local step      = nanoVBO.instanceStep
	local frame     = spGetGameFrame()
	-- Per-particle fade duration: FADE_FRAMES_DEATH * (0.4..1.6). Staggers the
	-- dissolve across the spray so particles don't all wink out on the same
	-- frame -- looks more like a soft cloud breaking up.
	local dirtyMin, dirtyMax = math.huge, -1
	for i = 1, #list do
		local p = list[i]
		local slot = idtoIndex[p.id]
		if slot then
			local remaining = p.death - frame
			if remaining > 0 then
				local fadeFrames = mathFloor(FADE_FRAMES_DEATH * (0.4 + mathRandom()))
				if fadeFrames < 1 then fadeFrames = 1 end
				-- Clamp to remaining lifetime: never extend a particle's life,
				-- only shorten/replace it. Particles already close to the target
				-- (small remaining) get a proportionally shorter fade so they
				-- still dissolve instead of converging cleanly into the unit.
				if fadeFrames > remaining then fadeFrames = remaining end
				local newDeath = frame + fadeFrames
				local base = (slot - 1) * step
				data[base+16] = newDeath
				-- Force per-particle fade window so even reclaim-style (fadeFrames=0)
				-- particles dissolve when the target dies. w is packed: preserve the
				-- low (sizeMult) bits and replace only the fadeFrames portion.
				local packed   = data[base+4]
				local oldFade  = mathFloor(packed / 1024)
				local sizeBits = packed - oldFade * 1024
				data[base+4]   = sizeBits + fadeFrames * 1024
				local s0 = slot - 1
				if s0 < dirtyMin     then dirtyMin = s0     end
				if s0 + 1 > dirtyMax then dirtyMax = s0 + 1 end
			end
		end
	end
	if dirtyMax > dirtyMin then
		uploadElementRange(nanoVBO, dirtyMin, dirtyMax)
	end
end

function gadget:UnitDestroyed(unitID)
	fadeOutHomingFwd(unitID)
	clearPiecePosCache(unitID)
	builderCache[unitID] = nil
	homingByBuilder[unitID] = nil
	homingFwdByTarget[unitID] = nil
	targetPosCache[unitID]    = nil
	targetIncompleteCache[unitID] = nil
	untrackUnit(unitID)
end
function gadget:RenderUnitDestroyed(unitID)
	fadeOutHomingFwd(unitID)
	clearPiecePosCache(unitID)
	builderCache[unitID] = nil
	homingByBuilder[unitID] = nil
	homingFwdByTarget[unitID] = nil
	targetPosCache[unitID]    = nil
	targetIncompleteCache[unitID] = nil
	untrackUnit(unitID)
end

function gadget:DrawWorld()
	if not nanoVBO or nanoVBO.usedElements == 0 then return end

	local t0
	if DEBUG then t0 = spGetTimer() end

	glDepthTest(true)
	glDepthMask(false)
	glCulling(false)
	-- Engine uses premultiplied alpha for the alpha particle pass:
	--   BlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA)
	glBlending(GL_ONE, GL_ONE_MINUS_SRC_ALPHA)

	-- Shape shader has no nanoTex sampler -- skip the bind entirely.
	if not isShapeMode then
		glTexture(0, NANO_TEXTURE)
	end
	glTexture(1, "$info")
	nanoShader:Activate()
	-- losAlwaysVisible: bypass the LOS/infoTex sample either when the player
	-- has full visibility (spectator full-view) or when the engine's $info
	-- texture isn't currently rendering LOS (heightmap / metalmap / pathmap
	-- minimap modes -- $info holds that other map data instead of LOS, and
	-- our smoothstep would discard most fragments). cachedInfoIsLos is
	-- refreshed on the 1s GameFrame poll instead of polled per render frame.
	local losU = (cachedSpecFullView or not cachedInfoIsLos) and 1 or 0
	if losU ~= lastLosUniform then
		nanoShader:SetUniform("losAlwaysVisible", losU)
		lastLosUniform = losU
	end
	nanoVBO:Draw()
	nanoShader:Deactivate()
	if not isShapeMode then
		glTexture(0, false)
	end
	glTexture(1, false)

	glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	glDepthMask(true)

	if DEBUG then
		_dbgTDraw = _dbgTDraw + spDiffTimers(spGetTimer(), t0)
		_dbgDraws = _dbgDraws + 1
	end
end
