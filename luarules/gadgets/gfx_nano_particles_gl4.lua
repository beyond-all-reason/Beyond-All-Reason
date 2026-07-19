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
local spGetAllUnits              = Spring.GetAllUnits
local spGetUnitTeam              = Spring.GetUnitTeam
local spGetUnitAllyTeam          = Spring.GetUnitAllyTeam
local spGetUnitNanoPieces        = Spring.GetUnitNanoPieces
local spGetUnitPiecePosDir       = Spring.GetUnitPiecePosDir
local spGetUnitPosition          = Spring.GetUnitPosition
local spGetUnitRadius            = Spring.GetUnitRadius
local spGetUnitDefID             = Spring.GetUnitDefID
local spGetUnitIsBeingBuilt      = Spring.GetUnitIsBeingBuilt
local spGetUnitIsBuilding        = Spring.GetUnitIsBuilding
local spGetFeaturePosition       = Spring.GetFeaturePosition
local spGetFeatureRadius         = Spring.GetFeatureRadius
local spGetFeatureHealth         = Spring.GetFeatureHealth
local spGetFeatureResources      = Spring.GetFeatureResources
local spValidFeatureID           = Spring.ValidFeatureID
local spValidUnitID              = Spring.ValidUnitID
local spGetTeamColor             = Spring.GetTeamColor
local spGetUnitCurrentBuildPower = Spring.GetUnitCurrentBuildPower
local spGetUnitWorkerTask        = Spring.GetUnitWorkerTask
local spGetUnitHealth            = Spring.GetUnitHealth
local spGetUnitMoveTypeData      = Spring.GetUnitMoveTypeData
local spIsUnitVisible            = Spring.IsUnitVisible
local spGetUnitCollisionVolumeData = Spring.GetUnitCollisionVolumeData
local spGetGroundHeight          = Spring.GetGroundHeight

-- Engine encodes feature targets in worker-task results as (featureID + MaxUnits()).
-- Used for CMD_RESURRECT (always) and CMD_RECLAIM of features. See engine
-- LuaSyncedRead.cpp::GetBuilderWorkerTask.
local MAX_UNITS = Game.maxUnits or 32000

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
local mathCeil   = math.ceil
local mathLog    = math.log

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
local MAX_PARTICLES_VBO = 10000

-- Live soft cap. Driven by the MaxParticles springsetting (~33% share, with a
-- 6000 floor so the gadget always has *some* headroom). Polled from Update so
-- the gfx options menu can adjust it without a /luarules reload.
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

-- Render mode: "shape" (3D polyhedra via geometry shader; specific shape in
-- MODE_SETTINGS). Driven by the "NanoParticleMode" springsetting (gfx options UI):
--   0 = engine nano spray (gadget stays loaded but inert)
--   1 = gadget 3D shapes
-- Polled live from Update so changes take effect without a /luarules reload.
if Spring.GetConfigInt("NanoParticleMode", 1) == 2 then
	Spring.SetConfigInt("NanoParticleMode", 1)
end
local NANO_PARTICLE_MODE = Spring.GetConfigInt("NanoParticleMode", 1)
local RENDER_MODE = "shape"


-- Color brightness equalization, in [0..1]:
local NanoParticleColorEqualize = 0.7   -- [0..1]
-- Global unit particle rate/amount multiplier. 1.0 = unchanged. 0.5 = half particles per unit
local NanoParticleRate        = 0.32   -- [0..1]
-- Reclaiming units: tighten target-radius spawn spread so the cloud doesn't
-- fill the whole unit footprint. 0.6 = 40% less spread.
local RECLAIM_UNIT_JITTER_SCALE = 0.6
-- Resurrect emits two legs (outbound + inbound). Scale the resurrect-specific
-- spray here for BOTH legs: 1.0 = current BAR behaviour, 0.5 = half as many
-- resurrect particles on both outbound and inbound legs
local NanoParticleResurrectExtraRate = 0.5
-- During the metal-refill phase of resurrect, GetUnitCurrentBuildPower can
-- report 0 even while work is progressing. Use a conservative synthetic
-- buildpower so this phase remains visibly active.
local RESURRECT_REFILL_FALLBACK_BP = 2

local function takeScaledEmitCount(info, accumKey, emits, scale)
	if emits <= 0 or not scale or scale <= 0 then return 0 end
	local accum = (info[accumKey] or 0) + emits * scale
	local out = mathFloor(accum)
	info[accumKey] = accum - out
	return out
end

-- Per-mode visual settings. Edit the active mode's table to tweak its look in
-- isolation.
local MODE_SETTINGS = {
	shape = {
		shape       = "cube",   -- "cube" | "octahedron"
		drawRadius  = 1.5,        -- shape spans ~2*drawRadius edge-to-edge
		nanoAlpha   = 50 / 255,
		dirJitter   = 0.10,       -- chunks read better with less spread
		-- Shapes benefit from visible variation -- they read as discrete chunks.
		sizeVar     = 0.3,
		speedVar    = 0.14,
		alphaVar    = 2.5,
		-- View-dependent face shading: 0 = flat, 1 = full 3D depth (back faces visible-but-dimmed).
		cubeShowInside = 4.0,
		cubeNoise       = 6,
		cubeNoiseSpeed  = 25.0,
		cubeNoiseScale  = 1.75,
		whiteHotspot          = 1.5,
		whiteHotspotThreshold = 0.6,
		-- GS adds its own per-axis 3D tumble, so base 2D rotation can be slower.
		rotValBase  = -180, rotValRange = 360,
		rotVelBase  = -40,  rotVelRange = 80,
		rotAccBase  = -40,  rotAccRange = 80,
		glowIntensity = 0.35,
		glowFalloff = 9.5,
		glowScale = 11.0,
		-- NOTE: the halo brightness "breath" pulse was removed. A pulsing
		-- brightness on the bright additive halo gets smeared by the engine's
		-- temporal filtering into moving bands that track the camera (the
		-- reported "glitchy horizontal lines"); a steady halo has none of that.
		-- Energy enhancement (sizePulse not wired through GS; halo+jitter suffice).
		coreBoost      = 0.3,    -- multiplies face shading; modest so dark faces still read
		hueJitter      = 0.1,
	},
}

-- Fade-out: per-particle end-of-life alpha ramp. The instance attribute
-- spawnPosAndSize.w carries the per-particle fade window in frames; 0 disables
-- the fade. Different values per emission type so reclaim doesn't fade as it
-- lands on the builder, while repair gets a soft tail-off and target-death
-- gets a snappier dissolve.
local FADE_FRAMES_REPAIR  = 4   -- gentle polish on outbound repair/capture
local FADE_FRAMES_RECLAIM = 3    -- no fade -- particles converge fully
local FADE_FRAMES_DEATH   = 35   -- dissolve when target unit dies or fully repaired

-- Reclaim-completion burst: when a tracked unit finishes being reclaimed by
-- our builders, spit a one-shot cluster of inverse particles emanating from
-- random points within the unit's collision volume, distributed across the
-- builders that actually reclaimed it (= teams that received the metal).
-- Particle count is logarithmic in the unit's metal cost AND scales with the
-- number of active reclaimers: each builder contributes its own share, so a
-- solo reclaimer fires a modest puff while a coordinated swarm fires much more.
local RECLAIM_BURST_BASE      = 1      -- particles per builder regardless of unit cost (the minimum each builder adds)
local RECLAIM_BURST_LOG_K     = 40    -- controls how quickly each builder's share grows as units get more expensive.
                                      -- raise to get more particles on mid/high-cost units; lower to flatten the curve.
local RECLAIM_BURST_LOG_NORM  = 250   -- the "cheap" threshold: units at or below this metal cost produce close to
                                      -- RECLAIM_BURST_BASE particles per builder. Units significantly above it start climbing.
                                      -- raise to shift the ramp toward more expensive units; lower to ramp up sooner.
local RECLAIM_BURST_BUILDER_EXP = 0.5  -- sub-linear exponent for builder count: total = perBuilder * nb^EXP.
                                        -- 1.0 = fully linear (4 reclaimers → 4× particles), 0.5 = square-root curve.
                                        -- 0.7 is a reasonable middle ground.
local RECLAIM_BURST_MAX       = 1500    -- absolute hard cap on total particles across all builders combined
local RECLAIM_BURST_VOL_FRAC  = 0.55   -- spawn within this fraction of collvol radius

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

-- Range gating for emission. Builders normally only emit when the target is
-- within buildDistance, but fast targets (planes, jumpjets) can leave that
-- range mid-build before the worker task is re-evaluated, leading to nano
-- streams that visibly chase the target far past the builder's actual reach.
-- Allow up to BUILD_RANGE_MAX_EXTENSION beyond buildDistance, with a linear
-- emission falloff inside [buildDistance, buildDistance * MAX_EXTENSION].
local BUILD_RANGE_MAX_EXTENSION = 1.1

-- Per-visit emission rate is scaled by (buildSpeed * currentBuildPower) /
-- EMIT_REF_BUILDSPEED. This gives total particles roughly proportional to a
-- builder's actual throughput rather than its nanopiece count -- otherwise
-- multi-arm factories with modest buildpower (e.g. shipyards) hog far more
-- of the particle budget than a high-power single-piece constructor doing
-- the same amount of work. Per-visit count is capped at nPieces so no piece
-- emits twice in one visit. A fractional accumulator on info preserves
-- sub-1.0 rates across visits.
local EMIT_REF_BUILDSPEED = 100

-- Visibility-feedback floor: if a builder has any active build power but its
-- proportional rate is so small that the deterministic accumulator hasn't
-- produced a particle for this many frames, force a single particle so the
-- player still sees that something is happening (e.g. repair/build progressing
-- on a tiny fraction of buildpower). The forced emit is debited from the
-- accumulator so long-term proportionality is preserved.
local FEEDBACK_EMIT_MIN_GAP = 60   -- ~2s at 30 sim Hz

-- Throttling knobs. These trade a small amount of visual latency for a large
-- CPU win in builder-heavy games (hundreds of active nanos):
--   * HOMING_RUN_EVERY: run per-frame in-place re-aim every Nth frame instead
--     of every frame. Particle speed is small vs typical unit movement over
--     1-2 frames so this is visually identical.
local LOS_CACHE_FRAMES           = 7
-- When an enemy builder is detected by radar/sonar but not visually visible
-- (e.g. a submarine), show only this fraction of its particles. Gives a
-- subtle hint that something is happening there without revealing full detail.
-- Set to 0 to suppress entirely when only detected, 1.0 to show in full.
local ENEMY_RADAR_EMIT_SCALE     = 0.20
local HOMING_RUN_EVERY           = 4
-- Repair-completion poll cadence (sim frames). At 2Hz, HP/buildProgress polls
-- are visually indistinguishable from per-pass and cut Spring->C calls by ~80%
-- in mass-repair scenarios. UnitFinished/UnitDestroyed callins fade
-- immediately, so this only catches the slow "repaired to full HP" edge.
local HEALTH_CHECK_EVERY         = 15
-- Run the per-frame builder scan only every Nth sim frame. Scales with pool
-- saturation: empty -> every frame, full -> every MAX_SCAN_RUN_EVERY frames
-- (the saturation gate would drop most emissions anyway). Per-builder emit
-- count is multiplied by the chosen value so total emission rate is preserved.
local MIN_SCAN_RUN_EVERY         = 1
local MAX_SCAN_RUN_EVERY         = 3
-- Cache lifetime for spGetUnitCurrentBuildPower. Only trusted while bp > 0
-- (continuous-build steady state where stale samples are harmless). Idle
-- visits always re-fetch so 0 -> non-zero edges fire on the next visit. The
-- emit accumulator absorbs the worst-case over-emit on the falling edge.
local BUILD_POWER_CACHE_FRAMES   = 8
-- Forward homing: skip per-particle re-aim once a target has been stationary
-- this many homing passes. Spawn-time aim is correct as long as the target
-- hasn't moved, collapsing repair-of-static-unit cases to a near-no-op.
local STATIONARY_SKIP_AFTER      = 4
-- Off-screen emission throttle. Cold endpoints (not recently visible) do not
-- allocate particles, but they accrue a bounded virtual stream so the next
-- visible visit can materialize particles already in flight. Once a spray has
-- been visible, a short warm grace keeps reduced offscreen emission so quick
-- camera nudges do not reset the stream. Frustum visibility is cached for
-- OFFSCREEN_VIS_CACHE_FRAMES (camera moves slowly vs emit rate). Cold static
-- endpoints can recheck less often because DrawWorld separately watches the
-- cached endpoint for camera arrivals. Warm keep-fraction scales with pool
-- saturation: MAX at/below SAT_PIVOT, ramping linearly to MIN at full saturation.
local OFFSCREEN_EMIT_KEEP_MAX       = 0.45
local OFFSCREEN_EMIT_KEEP_MIN       = 0.25
local OFFSCREEN_EMIT_KEEP_SAT_PIVOT = 0.25
local OFFSCREEN_EMIT_KEEP_BAND_INV  = 1.0 / (1.0 - OFFSCREEN_EMIT_KEEP_SAT_PIVOT)
local OFFSCREEN_VIS_CACHE_FRAMES = 6
local OFFSCREEN_COLD_RECHECK_FRAMES = 30
local OFFSCREEN_VIRTUAL_CHECKS_PER_DRAW = 32
-- Distance-based emission throttle. Linear keep-fraction ramp from 1.0 at
-- DISTANT_EMIT_NEAR_RANGE down to DISTANT_EMIT_KEEP at DISTANT_EMIT_RANGE.
-- Composes with the offscreen gate. Two squared-distance compares + lerp per
-- emission; camera position sampled once per scan frame.
local DISTANT_EMIT_KEEP          = 0.35
local DISTANT_EMIT_NEAR_RANGE    = 2500    -- elmos: full emission inside this
local DISTANT_EMIT_RANGE         = 9000    -- elmos: floor reached at this
-- Precomputed at file load (DISTANT_EMIT_* are constants).
local DISTANT_EMIT_NEAR_SQ  = DISTANT_EMIT_NEAR_RANGE * DISTANT_EMIT_NEAR_RANGE
local DISTANT_EMIT_FAR_SQ   = DISTANT_EMIT_RANGE      * DISTANT_EMIT_RANGE
local DISTANT_EMIT_BAND_INV = 1.0 / (DISTANT_EMIT_FAR_SQ - DISTANT_EMIT_NEAR_SQ)
local DISTANT_EMIT_DROP     = 1.0 - DISTANT_EMIT_KEEP

-- Dynamic scan stride: builders are scanned 1/stride per sim frame. Per-builder
-- emit count is multiplied by stride so total rate is preserved. Grows with
-- pool saturation (the gate would drop most emissions at high fill anyway).
local MIN_SCAN_STRIDE = 1
local MAX_SCAN_STRIDE = 2

-- Engine constants (rts/Sim/Projectiles/ProjectileHandler.cpp)
local NANO_SPEED      = 4.0	-- engine default: 3.0

-- Anti-clump: half-width (elmos) of the symmetric stagger window around the
-- nanopiece. Particles in a batch are spread along their velocity in
-- [-MAX_SPREAD_AHEAD_ELMOS, +MAX_SPREAD_AHEAD_ELMOS], so a few sit slightly
-- behind the emit point (partially occluded by the builder model) and the
-- rest just ahead. Just enough to break up the visible "blob" without making
-- particles appear detached from the source. Direction jitter already
-- provides lateral spread; this only fixes the on-axis pile-up.
local MAX_SPREAD_AHEAD_ELMOS = 6
local MAX_SPREAD_AHEAD_FRAMES = MAX_SPREAD_AHEAD_ELMOS / NANO_SPEED

-- Shape selector for cube-mode geometry shader. The GS branches on this and
-- emits the corresponding polyhedron's faces. All shapes use the same per-face
-- shading / noise pipeline -- only the vertex/face topology differs.
--   cube         -- 6 quads, 24 emitted verts.   Distinct large faces; classic look.
--   octahedron   -- 8 tris,  24 emitted verts.   Diamond/gem feel.
-- (Larger polyhedra like icosahedron/dodecahedron exceed GS output limits with
-- our per-vertex component count and so are not supported.)
local SHAPE_IDS = { cube = 0, octahedron = 1 }

-- Pack per-particle sizeMult, fadeFrames AND inverse flag into a single float
-- for the spawnPosAndSize.w attribute slot (avoids growing the VBO layout).
-- Layout:
--   magnitude = floor(sizeMult * 256 + 0.5) + fadeFrames * 1024
--   sign      = negative iff inverse (reclaim)
-- sizeMult expected in [0, 4); fadeFrames integer in [0, ~120]. Magnitude is
-- always > 0 since spawnParticle uses sizeMult ~1, so the sign bit is free.
local function packSizeFade(sizeMult, fadeFrames, inverse)
	local v = mathFloor(sizeMult * 256 + 0.5) + (fadeFrames or 0) * 1024
	return inverse and -v or v
end

-- The engine API takes rotVel in deg/sec and rotAcc in deg/sec^2 and internally
-- divides by GAME_SPEED to convert to per-frame units. We integrate per-frame in
-- the shader, so apply the same conversion here.
local GAME_SPEED     = Game.gameSpeed or 30

-- All mode-derived constants live on this single table (`U` = "uniforms")
-- instead of as ~30 separate top-level locals. The 200 active-locals limit on
-- the main chunk was getting close, and storing per-mode values together also
-- makes applyRenderMode trivial. Hot-path call sites (spawnParticle, emitNano)
-- copy the values they need into function-locals at function entry, so per-
-- particle reads still hit a local rather than a table key.
local U = {}

-- Optional terrain clamp for particle paths. Disabled by default because it
-- adds extra ground-height queries in hot paths.
U.GROUND_CLAMP_ENABLED = true
U.GROUND_CLAMP_MARGIN  = 11.0
-- In-flight correction cadence. Enabled mode can periodically reproject active
-- particles above terrain to prevent straight-line tunneling through cliffs.
-- 0 means "all active particles each pass".
U.GROUND_CLAMP_RUN_EVERY    = 6
U.GROUND_CLAMP_MAX_PER_STEP = 0
U.GROUND_CLAMP_RECHECK_HIT  = 6
U.GROUND_CLAMP_RECHECK_MISS = 12
U.GROUND_CLAMP_USE_WAYPOINT = true
-- Smart gate: only enable clamp for builders/targets in rough terrain.
U.GROUND_CLAMP_SMART              = true
U.GROUND_CLAMP_SMART_DELTA        = 4.0
U.GROUND_CLAMP_SMART_RADIUS       = 128.0
U.GROUND_CLAMP_SMART_CACHE_FRAMES = 45

U.GROUND_CACHE_INV_CELL = 1 / 16
U.GROUND_CACHE_STRIDE = mathFloor(((Game.mapSizeZ or 65536) * U.GROUND_CACHE_INV_CELL) + 0.5) + 1024
U._groundYCache = {}
U._groundYStamp = {}
U._groundClampGateCache = {}

U._jitterTable = {}
U._jitterCursor = 1
do
	local jitterTable = U._jitterTable
	local idx = 1
	for _ = 1, 1024 do
		local jx, jy, jz
		repeat
			jx = mathRandom() * 2 - 1
			jy = mathRandom() * 2 - 1
			jz = mathRandom() * 2 - 1
		until (jx*jx + jy*jy + jz*jz) <= 1.0
		jitterTable[idx] = jx; jitterTable[idx + 1] = jy; jitterTable[idx + 2] = jz
		idx = idx + 3
	end
	U._jitterTableLast = idx - 3
end

-- Clamp-focused debug stream (lightweight; independent from full DEBUG timers)
local CLAMP_DEBUG = false
local clampDbg = {
	emitChecks = 0,
	emitEnabled = 0,
	registered = 0,
	processed = 0,
	corrected = 0,
	dropped = 0,
	maxSubset = 0,
}

-- Ground-height cache for clamp hot paths. Quantized keys trade tiny spatial
-- precision for far fewer Spring.GetGroundHeight calls in dense sprays.
local function getGroundYMargin(x, z, frame)
	if frame then
		local qx = mathFloor(x * U.GROUND_CACHE_INV_CELL + 0.5)
		local qz = mathFloor(z * U.GROUND_CACHE_INV_CELL + 0.5)
		local key = qx * U.GROUND_CACHE_STRIDE + qz
		if U._groundYStamp[key] == frame then
			return U._groundYCache[key]
		end
		local gy = spGetGroundHeight(x, z) + U.GROUND_CLAMP_MARGIN
		U._groundYStamp[key] = frame
		U._groundYCache[key] = gy
		return gy
	end
	return spGetGroundHeight(x, z) + U.GROUND_CLAMP_MARGIN
end

local function clampYAboveGround(x, y, z, frame)
	if not U.GROUND_CLAMP_ENABLED then return y end
	local gy = getGroundYMargin(x, z, frame)
	if y < gy then return gy end
	return y
end

local function shouldClampEmit(builderID, sx, sy, sz, ex, ey, ez, frame)
	if not U.GROUND_CLAMP_ENABLED then return false end
	if not U.GROUND_CLAMP_SMART then return true end
	if CLAMP_DEBUG then clampDbg.emitChecks = clampDbg.emitChecks + 1 end
	local qex = mathFloor(ex * U.GROUND_CACHE_INV_CELL + 0.5)
	local qez = mathFloor(ez * U.GROUND_CACHE_INV_CELL + 0.5)
	local targetKey = qex * U.GROUND_CACHE_STRIDE + qez
	local cached = U._groundClampGateCache[builderID]
	if cached and cached[3] == targetKey and (frame - cached[1]) < U.GROUND_CLAMP_SMART_CACHE_FRAMES then
		return cached[2], cached[4], cached[5]
	end
	local delta = U.GROUND_CLAMP_SMART_DELTA
	local guideY = -1e9
	local peakT = 0.5
	local dx = ex - sx
	local dz = ez - sz
	local dy = ey - sy
	local maxPen = -1e9
	local longPath = (dx * dx + dz * dz) > 4096
	local n = longPath and 8 or 3
	for i = 1, n do
		local t
		if longPath then
			if i == 1 then t = 0.12
			elseif i == 2 then t = 0.22
			elseif i == 3 then t = 0.35
			elseif i == 4 then t = 0.50
			elseif i == 5 then t = 0.65
			elseif i == 6 then t = 0.78
			elseif i == 7 then t = 0.90
			else t = 0.96 end
		else
			if i == 1 then t = 0.35
			elseif i == 2 then t = 0.50
			else t = 0.65 end
		end
		local mx = sx + dx * t
		local mz = sz + dz * t
		local my = sy + dy * t
		local gy = getGroundYMargin(mx, mz, frame)
		if gy > guideY then guideY = gy end
		local pen = gy - my
		if pen > maxPen then
			maxPen = pen
			peakT = t
		end
	end
	local enable = maxPen > delta
	if CLAMP_DEBUG and enable then clampDbg.emitEnabled = clampDbg.emitEnabled + 1 end
	U._groundClampGateCache[builderID] = { frame, enable, targetKey, guideY, peakT }
	return enable, guideY, peakT
end

-- Round-robin cursor for bounded global in-flight clamp passes.
local groundClampCursor = 1
local groundClampParticles = {}
local groundClampFree = {}

local function registerGroundClampParticle(id, death, wp, fx, fy, fz, targetID)
	local nFree = #groundClampFree
	local entry = groundClampFree[nFree]
	if entry then
		groundClampFree[nFree] = nil
	else
		entry = {}
	end
	entry.id = id
	entry.death = death
	entry.wp = wp
	entry.fx = fx
	entry.fy = fy
	entry.fz = fz
	entry.targetID = targetID
	entry.next = wp or 0
	groundClampParticles[#groundClampParticles + 1] = entry
	if CLAMP_DEBUG then clampDbg.registered = clampDbg.registered + 1 end
end

-- Populate every mode-derived value from MODE_SETTINGS[name]. Called once at
-- file load. Kept as a function so future mode additions can re-invoke it
-- (callers are responsible for tearing down / rebuilding GL objects via
-- cleanupGL4 + initGL4 since the shader pair depends on RENDER_MODE).
local function applyRenderMode(name)
	RENDER_MODE          = name
	local MODE           = MODE_SETTINGS[name] or MODE_SETTINGS.shape
	U.DRAW_RADIUS        = MODE.drawRadius
	U.DIR_JITTER         = MODE.dirJitter
	U.NANO_ALPHA         = MODE.nanoAlpha
	U.SIZE_VAR           = MODE.sizeVar  or 0.0
	U.SPEED_VAR          = MODE.speedVar or 0.0
	U.ALPHA_VAR          = MODE.alphaVar or 0.0
	U.CUBE_SHOW_INSIDE   = MODE.cubeShowInside or 0.0
	U.CUBE_NOISE         = MODE.cubeNoise       or 0.0
	U.CUBE_NOISE_SPEED   = MODE.cubeNoiseSpeed  or 0.0
	U.CUBE_NOISE_SCALE   = MODE.cubeNoiseScale  or 0.5
	U.GLOW_SCALE         = MODE.glowScale       or 1.0
	U.GLOW_INTENSITY     = MODE.glowIntensity   or 0.0
	U.GLOW_FALLOFF       = MODE.glowFalloff     or 2.0
	U.CORE_BOOST         = MODE.coreBoost       or 1.0
	U.HUE_JITTER         = MODE.hueJitter       or 0.0
	U.SIZE_PULSE_AMP     = MODE.sizePulseAmp    or 0.0
	U.SIZE_PULSE_FREQ    = MODE.sizePulseFreq   or 0.0
	U.WHITE_HOTSPOT           = MODE.whiteHotspot          or 0.0
	U.WHITE_HOTSPOT_THRESHOLD = MODE.whiteHotspotThreshold or 0.7
	U.SHAPE_ID           = SHAPE_IDS[MODE.shape or "cube"] or 0
	U.ROT_VAL_BASE       = MODE.rotValBase
	U.ROT_VEL_BASE       = MODE.rotVelBase  / GAME_SPEED
	U.ROT_ACC_BASE       = MODE.rotAccBase  / (GAME_SPEED * GAME_SPEED)
	U.ROT_VAL_RANGE      = MODE.rotValRange
	U.ROT_VEL_RANGE      = MODE.rotVelRange / GAME_SPEED
	U.ROT_ACC_RANGE      = MODE.rotAccRange / (GAME_SPEED * GAME_SPEED)
end

applyRenderMode(RENDER_MODE)

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local nanoVBO
local nanoShader
local lastLosUniform = -1       -- cache to skip redundant SetUniform calls

-- Active particle bookkeeping. The InstanceVBOTable instanceID is our handle.
local nextID = 1

-- Death-frame buckets: deathBuckets[deathFrame] = { id1, id2, ... }
-- Cull walks due buckets only -> O(deaths/frame) instead of O(live) per cull pass.
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

-- Forward declaration so Initialize can seed the tracked builder set.
local trackUnit

-- Cached visibility state
local cachedAllyTeamID   = Spring.GetMyAllyTeamID()
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
	local spec, fullView = Spring.GetSpectatingState()
	cachedSpecFullView = spec and fullView
	cachedAllyTeamID   = Spring.GetMyAllyTeamID()
end

-- High gamespeed throttle. When the engine runs faster than 1x (catchup after
-- reconnect, or user /speed) sim frames can advance faster than user frames and
-- nano emission can dominate the Lua budget. Ramps from 0 at *_START to 1 at
-- *_FULL and is used at scan time to cap effective particle pool and cut emitProb.
-- Refreshed from Update on a 1s sim-frame cadence (cheap, one Spring.GetGameSpeed call).
local GAMESPEED_THROTTLE_START = 1.5   -- below this, no extra throttle
local GAMESPEED_THROTTLE_FULL  = 5.0   -- at or above this, full throttle
local GAMESPEED_EMIT_CUT       = 0.66   -- emitProb cut at full throttle (0..1)
local GAMESPEED_MAX_CUT        = 0.85   -- effective-max cut at full throttle (0..1)
local speedThrottle = 0.0              -- 0 = none, 1 = max (set from Update)

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
-- mini-map mode (""/"los"/"height"/"metal"/"path"); when not LOS, $info holds
-- other map data and our LOS smoothstep would discard most of the map.
-- Also refreshed in DrawWorld so mode toggles apply immediately.
local cachedInfoIsLos = true
local function refreshInfoIsLos()
	local m = Spring.GetMapDrawMode()
	cachedInfoIsLos = (m == nil or m == "" or m == "los")
end

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
layout(location = 4) in vec4 rotData;           // x=rotVal0, y=rotVel0, z=reserved, w=deathFrame

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

	// Decode packed w: sizeMult in low 1024, fadeFrames * 1024 above. Sign
	// is the inverse flag (handled above) -- abs here.
	float packedW    = abs(spawnPosAndSize.w);
	float fadeFrames = floor(packedW / 1024.0);
	float sizeMult   = (packedW - fadeFrames * 1024.0) / 256.0;

	float fade = (fadeFrames > 0.5)
		? clamp((deathFrame - currentFrame) / fadeFrames, 0.0, 1.0)
		: 1.0;

	float rotVel = rotData.y;
	float rotVal = rotData.x + rotVel  * t;

	v_worldPos = worldPos;
	v_color    = instColor * fade;
	// Shrink during the death-fade alongside the alpha ramp: 100% size at
	// fade=1 (no fade active), down to 50% at fade=0. Reads as the chunk
	// dissolving into nothing instead of just becoming transparent.
	v_rotVal   = rotVal;
	v_sizeMult = sizeMult * (0.5 + 0.5 * fade);
	// Stable per-particle seed for cube tumble phase. Homing rewrites spawnPos
	// every frame, so derive the seed from spawn-time random rotData.x/.y only.
	v_phaseSeed = vec3(rotData.x, rotData.y, rotData.x + rotData.y);
	gl_Position = vec4(worldPos, 1.0);  // GS reads this
}
]]

local gsSrcCube = [[
#version 430 core

layout(triangles) in;
// 28 = worst case across supported shapes:
//   cube: 6 quads * 4 verts = 24 + 4 glow billboard verts
//   octahedron: 8 tris * 3 verts = 24 + 4 glow billboard verts
// Larger polyhedra would exceed MAX_GEOMETRY_TOTAL_OUTPUT_COMPONENTS given
// our per-vertex output count.
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

// Cheap 3D value noise: 8 corner hashes + quintic fade (continuous second
// derivative so cell boundaries don't show as creases). Per-particle
// g_noiseSeed offset hides any residual grid structure.
//
// hash uses Dave Hoskins' hash-without-sine (https://www.shadertoy.com/view/4djSRW).
// The classic IQ hash collapses to near-zero whenever any component is near
// zero, producing visible axis-aligned dark planes through the noise volume.
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
		float glow = pow(clamp(t, 0.0, 1.0), max(glowFalloff, 0.01)) * gI;
		// Saturation-preserving brightness equalization -- see billboard FS.
		vec3  glowTint = g_color.rgb / max(max(g_color.r, max(g_color.g, g_color.b)), 0.001);
		float gLuma    = dot(glowTint, vec3(0.2126, 0.7152, 0.0722));
		const float GLOW_LUMA_TARGET = 0.55;
		const float GLOW_BOOST_MAX   = 5.0;
		float glowBoost = min(GLOW_LUMA_TARGET / max(gLuma, 0.001), GLOW_BOOST_MAX);
		fragColor = vec4(glowTint * tint * (glow * glowBoost), g_color.a * glow) * losMul;
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
	local useGeometryShader = true

	local shaderCacheGS = {
		vsSrc = vsSrcCube,
		fsSrc = fsSrcCube,
		gsSrc = gsSrcCube,
		shaderName = "NanoParticlesGL4_Shape",
		uniformInt = { infoTex = 1, u_shape = U.SHAPE_ID },
		uniformFloat = { losAlwaysVisible = 0, drawRadius = U.DRAW_RADIUS, cubeShowInside = U.CUBE_SHOW_INSIDE,
		                 cubeNoise = U.CUBE_NOISE, cubeNoiseSpeed = U.CUBE_NOISE_SPEED, cubeNoiseScale = U.CUBE_NOISE_SCALE,
		                 glowScale = U.GLOW_SCALE, glowIntensity = U.GLOW_INTENSITY, glowFalloff = U.GLOW_FALLOFF,
		                 coreBoost = U.CORE_BOOST,
		                 hueJitter = U.HUE_JITTER,
		                 sizePulseAmp = U.SIZE_PULSE_AMP, sizePulseFreq = U.SIZE_PULSE_FREQ,
		                 whiteHotspot = U.WHITE_HOTSPOT, whiteHotspotThreshold = U.WHITE_HOTSPOT_THRESHOLD },
		shaderConfig = {},
		forceupdate = true,
	}

	local shaderCacheNoGS = {
		vssrcpath = "LuaUI/Shaders/nano_particles_gl4_nogs.vert.glsl",
		fsSrc = fsSrcCube,
		shaderName = "NanoParticlesGL4_Shape_NoGS",
		uniformInt = { infoTex = 1, u_shape = U.SHAPE_ID },
		uniformFloat = shaderCacheGS.uniformFloat,
		shaderConfig = {},
		forceupdate = true,
	}

	-- AMD GPUs have no native geometry-shader stage. Mesa emulates this GS by translating it
	-- onto the hardware's real shader stages, emitting every vertex through memory buffers.
	-- This is slow both to compile (a multi-second GS compile that stalls on the first draw,
	-- and isn't kept in the disk cache so it recurs) and to run (those memory round-trips
	-- cost bandwidth every frame). The no-GS path draws the same particles with none of that.
	-- AMD-on-Linux is always Mesa.
	local preferNoGS = (Platform ~= nil and Platform.gpuVendor == "AMD" and Platform.osFamily == "Linux")

	-- Try the geometry-shader path first (unless we already know to skip it); only
	-- fall back if compile actually fails. LuaShader.isGeometryShaderSupported can
	-- report false negatives on some drivers (e.g. AMD/Mesa), so we don't trust it
	-- alone.
	useGeometryShader = not preferNoGS
	nanoShader = useGeometryShader and LuaShader.CheckShaderUpdates(shaderCacheGS) or nil
	if not nanoShader then
		if useGeometryShader then
			spEcho("Nano Particles GL4: geometry shader compile failed; trying no-GS fallback.")
		end
		useGeometryShader = false
		nanoShader = LuaShader.CheckShaderUpdates(shaderCacheNoGS)
	end
	if not nanoShader then
		goodbye("Failed to compile shader")
		return false
	end

	if useGeometryShader then
		-- Quad: xy in [-1,1] (corner), uv in [0,1]
		local quadVBO, numVertices = InstanceVBOTable.makeRectVBO(
			-1, -1, 1, 1,
			0, 0, 1, 1,
			"nanoQuadVBO"
		)
		-- Shape GS only needs ONE triangle per instance; using the rect's 2-tri
		-- index buffer would invoke the GS twice per particle. A 3-index VBO
		-- (the rect's first triangle: bl,tl,tr) cuts GS work in half.
		local indexVBO = gl.GetVBO(GL.ELEMENT_ARRAY_BUFFER, false)
		indexVBO:Define(3)
		indexVBO:Upload({0, 1, 2})

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
	else
		-- No-GS fallback: build a template indexed mesh with one vertex per
		-- geometry-shader emitted vertex.  Default cube: 6 quads * 4 verts = 24 verts.
		-- Octahedron: 8 tris * 3 verts = 24 verts.  Plus a 4-vert glow billboard
		-- quad.  We use independent triangles, so each template vertex is emitted
		-- exactly once and indexed in GL order.
		local NUM_SHAPE_VERTS = 24
		local NUM_GLOW_VERTS  = 4
		local NUM_VERTS = NUM_SHAPE_VERTS + NUM_GLOW_VERTS
		local isOcta = (U.SHAPE_ID == 1)

		local templateVBO = gl.GetVBO(GL.ARRAY_BUFFER, false)
		templateVBO:Define(NUM_VERTS, {{ id = 0, name = "vertexSlot", size = 1 }}) -- float slot, cast to int in VS
		local vertexData = {}
		for i = 0, NUM_VERTS - 1 do
			vertexData[#vertexData + 1] = i
		end
		templateVBO:Upload(vertexData)

		-- Build indices matching the order the no-GS VS emits the template:
		-- cube quads are split into two triangles (0,1,2 and 0,2,3);
		-- octahedron triangles are a single tri (0,1,2); glow quad likewise.
		local indexData = {}
		if isOcta then
			for shapeTri = 0, NUM_SHAPE_VERTS / 3 - 1 do
				local base = shapeTri * 3
				indexData[#indexData + 1] = base + 0
				indexData[#indexData + 1] = base + 1
				indexData[#indexData + 1] = base + 2
			end
		else
			for quad = 0, NUM_SHAPE_VERTS / 4 - 1 do
				local base = quad * 4
				indexData[#indexData + 1] = base + 0
				indexData[#indexData + 1] = base + 1
				indexData[#indexData + 1] = base + 2
				indexData[#indexData + 1] = base + 0
				indexData[#indexData + 1] = base + 2
				indexData[#indexData + 1] = base + 3
			end
		end
		local glowBase = NUM_SHAPE_VERTS
		indexData[#indexData + 1] = glowBase + 0
		indexData[#indexData + 1] = glowBase + 1
		indexData[#indexData + 1] = glowBase + 2
		indexData[#indexData + 1] = glowBase + 0
		indexData[#indexData + 1] = glowBase + 2
		indexData[#indexData + 1] = glowBase + 3

		local indexVBO = gl.GetVBO(GL.ELEMENT_ARRAY_BUFFER, false)
		indexVBO:Define(#indexData)
		indexVBO:Upload(indexData)

		local layout = {
			{ id = 1, name = "spawnPosAndSize",  size = 4 },
			{ id = 2, name = "velAndSpawnFrame", size = 4 },
			{ id = 3, name = "instColor",        size = 4 },
			{ id = 4, name = "rotData",          size = 4 },
		}
		nanoVBO = InstanceVBOTable.makeInstanceVBOTable(layout, MAX_PARTICLES_VBO, "nanoParticleVBO_NoGS")
		if not nanoVBO then
			goodbye("Failed to create instance VBO")
			return false
		end

		local realVAO = nanoVBO:makeVAOandAttach(templateVBO, nanoVBO.instanceVBO, indexVBO)
		if not realVAO then
			goodbye("Failed to create no-GS VAO")
			return false
		end

		-- Anchor the template and index VBOs to the VBO table so the Lua GC
		-- cannot collect them while the VAO is alive.  OpenGL owns the buffer
		-- objects via the VAO, but Lua does not know that; without a strong Lua
		-- reference the GC can finalize the userdata and delete the GL buffers
		-- (fixed in commit 2b51f6e863 for DrawPrimitiveAtUnit).
		nanoVBO.nogsTemplateVBO = templateVBO
		nanoVBO.nogsIndexVBO    = indexVBO

		local indexCount = #indexData
		nanoVBO.VAO = {
			realVAO = realVAO,
			indexCount = indexCount,
			DrawArrays = function(self, _primitiveType, instanceCount)
				if instanceCount and instanceCount > 0 then
					self.realVAO:DrawElements(GL.TRIANGLES, self.indexCount, 0, instanceCount)
				end
			end,
			DrawElements = function(self, _primitiveType, _numVertices, _startIndex, instanceCount, _drawIndex)
				if instanceCount and instanceCount > 0 then
					self.realVAO:DrawElements(GL.TRIANGLES, self.indexCount, 0, instanceCount)
				end
			end,
			Delete = function(self)
				self.realVAO:Delete()
			end,
		}
		nanoVBO.primitiveType = GL.TRIANGLES
	end

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

-- Air-unit defs: precomputed once at file load. Used by the forward-homing
-- crashing-aircraft check so we only call spGetUnitMoveTypeData on targets
-- that can actually be in the "crashing" aircraftState. Saves the engine call
-- for every ground/sea repair target.
local isAirUnitDef = {}
local isMobileUnitDef = {}
for udid, def in pairs(UnitDefs) do
	if def.canFly then
		isAirUnitDef[udid] = true
	end
	if ((def.maxVelocity or def.speed or 0) > 0) and (not def.isFactory) then
		isMobileUnitDef[udid] = true
	end
end

-- Team color cache: spGetTeamColor is a Spring->C call; teamID -> {r, g, b}.
-- Colors can change mid-game (commshare, alliance, modoptions), so a periodic
-- refresh from Update re-fetches every cached team and propagates any change
-- into the per-builder info entries via builderCacheByTeam[team] = {info, ...}.
local teamColorCache    = {}
local builderCacheByTeam = {}  -- teamID -> array of info tables (for color propagation)

local function equalizeColor(r, g, b)
	local eq = NanoParticleColorEqualize or 0.0
	if eq <= 0.0 or not (r and g and b) then return r, g, b end
	local luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
	if luma < 0.001 then return r, g, b end
	local scale = (0.55 / luma) ^ eq
	local nr, ng, nb = r * scale, g * scale, b * scale
	-- If any channel would clip past 1.0, dampen the whole vector so we keep
	-- the original hue (uniform desaturation toward white would shift hue).
	local m = nr
	if ng > m then m = ng end
	if nb > m then m = nb end
	if m > 1.0 then
		local k = 1.0 / m
		nr, ng, nb = nr * k, ng * k, nb * k
	end
	return nr, ng, nb
end

local function getTeamColor(team)
	local c = teamColorCache[team]
	if c then return c[1], c[2], c[3] end
	local r, g, b = spGetTeamColor(team)
	r, g, b = equalizeColor(r, g, b)
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
		if team ~= "__lastEqualize" then
			local r, g, b = spGetTeamColor(team)
			r, g, b = equalizeColor(r, g, b)
			if r and (r ~= c[1] or g ~= c[2] or b ~= c[3]) then
				c[1], c[2], c[3] = r, g, b
				local lr, lg, lb = r, g, b
				if r and g and b then
					local luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
					if luma >= 0.001 then
						local scale = 0.55 / luma
						lr, lg, lb = r * scale, g * scale, b * scale
						local m = lr
						if lg > m then m = lg end
						if lb > m then m = lb end
						if m > 1.0 then
							local k = 1.0 / m
							lr, lg, lb = lr * k, lg * k, lb * k
						end
					end
				end
				local infos = builderCacheByTeam[team]
				if infos then
					for i = 1, #infos do
						local info = infos[i]
						info.r = r; info.g = g; info.b = b
						info.lr = lr; info.lg = lg; info.lb = lb
					end
				end
			end
		end
	end
end

-- If the equalize global was changed (by console / another widget), drop the
-- cached per-team colors so the next refreshTeamColors() pass recomputes them
-- with the new equalize value and propagates into every active builder.
-- Previous value tracked on teamColorCache itself (string key) instead of an
-- upvalue local -- this file is at the 200 active locals limit.
teamColorCache.__lastEqualize = NanoParticleColorEqualize
local function refreshColorEqualize()
	local v = NanoParticleColorEqualize or 0.0
	if type(v) ~= "number" then v = 0.0 end
	if v < 0.0 then v = 0.0 end
	if v > 1.0 then v = 1.0 end
	NanoParticleColorEqualize = v
	if v == teamColorCache.__lastEqualize then return false end
	teamColorCache.__lastEqualize = v
	for team in pairs(teamColorCache) do
		if team ~= "__lastEqualize" then teamColorCache[team] = nil end
	end
	return true
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

-- Reverse lookup for factory-assisted builds: when a mobile builder assists a
-- factory, GetUnitWorkerTask typically resolves to the buildee unit. For nano
-- visuals we want those particles to keep converging on the factory pad, not
-- start chasing the finished unit as it rolls out. Cache one scan-frame worth
-- of buildee -> factory anchor resolution so assist groups share the lookup.
local factoryBuildTargetCache = {}
local recentFactoryBuildTargetCache = {}

-- Reclaim/homing particles: in-flight inverse particles (those travelling back
-- toward a builder) re-aim each frame to follow the builder's CURRENT piece
-- position. Particle position formula is `pos = spawn + vel * (frame - spawnFrame)`,
-- so we rewrite spawn = current pos, vel = (newTarget - currentPos)/remaining,
-- spawnFrame = current frame. Death stays the same.
--   homingByBuilder[builderID] = { {id=, pieceIdx=, death=}, ... }
local homingByBuilder = {}
local HOMING_MAX_PER_BUILDER = 96   -- safety cap; oldest entries drop off

-- Forward homing: outbound particles aimed at a UNIT target (repair, capture)
-- bend toward the target's CURRENT mid-position. Same rewrite trick as inverse.
-- Keyed by target so each target's position resolves once per frame.
--   homingFwdByTarget[targetUnitID] = { {id=, death=}, ... }
local homingFwdByTarget = {}
local targetPosCache    = {}    -- unitID -> [epoch, x, y, z]
local targetIncompleteCache = {} -- unitID -> [epoch, isBeingBuilt]
local HOMING_FWD_MAX_PER_TARGET = 384   -- safety cap per repaired/captured unit

-- Reclaim-completion burst tracking. While a tracked unit is being reclaimed
-- by one or more of our builders, we record the builder set so that on
-- UnitDestroyed we can fire a one-shot particle burst FROM the unit center
-- TOWARD only those builders (whose teams actually got the metal). Cleared
-- when the target dies, when builders disengage (their cmdID/targetID change
-- away from this target), or when the builder itself dies.
--   reclaimedTargets[targetUnitID] = { [builderID] = true, ... }
local reclaimedTargets = {}
-- Cached build progress of reclaim targets (0..1, or nil for fully built).
-- Updated in the scan loop while the unit is alive so UnitDestroyed can read
-- it after the unit is already gone (Spring.GetUnitIsBeingBuilt returns nil
-- for dead units in unsynced context).
--   reclaimTargetBuildProgress[unitID] = number (0..1)  -- only present while isBeingBuilt
local reclaimTargetBuildProgress = {}

-- Forward emissions aimed at an UNFINISHED unit are NOT registered in
-- homingFwdByTarget (HOMING_SKIP_INCOMPLETE early-returns) so they don't curve
-- toward a moving factory exit. We still track them here in a fade-only list
-- (same {id, death} layout) for the per-particle death fade if that unit dies
-- or is cancelled mid-build. Cleared on UnitFinished and UnitDestroyed (both
-- also fade so trailing spray dissolves cleanly).
local fadeFwdByTarget = {}
local FADE_FWD_MAX_PER_TARGET = HOMING_FWD_MAX_PER_TARGET

U._trackEntryFree = {}
function U.recycleTrackList(list)
	if not list then return end
	local free = U._trackEntryFree
	for i = 1, #list do
		local p = list[i]
		if p then
			free[#free + 1] = p
			list[i] = nil
		end
	end
end

local function getFactoryBuildAnchor(targetUnitID)
	local cached = factoryBuildTargetCache[targetUnitID]
	if cached and cached[1] == piecePosEpoch then
		if cached[2] then
			return cached[2], cached[3], cached[4], cached[5], cached[6]
		end
		return nil
	end

	local list = trackedBuildersList
	for i = 1, #list do
		local factoryID = list[i]
		local finfo = builderCache[factoryID]
		local isFactory = finfo and finfo.isFactory
		if isFactory == nil then
			local factoryDefID = spGetUnitDefID(factoryID)
			isFactory = factoryDefID and UnitDefs[factoryDefID] and UnitDefs[factoryDefID].isFactory or false
		end
		if isFactory and spGetUnitIsBuilding(factoryID) == targetUnitID then
			local _, _, _, mx, my, mz = spGetUnitPosition(factoryID, true)
			if mx then
				local radius = spGetUnitRadius(factoryID) or 0
				factoryBuildTargetCache[targetUnitID] = { piecePosEpoch, factoryID, mx, my, mz, radius }
				return factoryID, mx, my, mz, radius
			end
			break
		end
	end

	local recent = recentFactoryBuildTargetCache[targetUnitID]
	if recent then
		local recentFrame = recent[1]
		if recentFrame and (Spring.GetGameFrame() - recentFrame) < HOMING_SKIP_GRACE_FRAMES then
			factoryBuildTargetCache[targetUnitID] = { piecePosEpoch, recent[2], recent[3], recent[4], recent[5], recent[6] }
			return recent[2], recent[3], recent[4], recent[5], recent[6]
		end
		recentFactoryBuildTargetCache[targetUnitID] = nil
	end

	factoryBuildTargetCache[targetUnitID] = { piecePosEpoch, false }
	return nil
end

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
	local lr, lg, lb = r, g, b
	if r and g and b then
		local luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
		if luma >= 0.001 then
			local scale = 0.55 / luma
			lr, lg, lb = r * scale, g * scale, b * scale
			local m = lr
			if lg > m then m = lg end
			if lb > m then m = lb end
			if m > 1.0 then
				local k = 1.0 / m
				lr, lg, lb = lr * k, lg * k, lb * k
			end
		end
	end
	local ud = UnitDefs[udid]
	-- buildDistance is used to gate emissions on fast-moving targets (planes
	-- etc.) that fly out of the builder's reach mid-build. Factories do not
	-- need this -- their target is a buildee on the pad. nil disables the gate.
	local buildDistance = (ud and ud.buildDistance) or 0
	if buildDistance <= 0 or (ud and ud.isFactory) then
		buildDistance = nil
	end
	local info = {
		pieces        = pieces,
		nPieces       = #pieces,
		r = r, g = g, b = b,
		lr = lr, lg = lg, lb = lb,
		team          = team,
		allyTeam      = spGetUnitAllyTeam(builderID),
		isFactory     = ud and ud.isFactory or false,
		isMobile      = isMobileUnitDef[udid] and true or false,
		buildDistance = buildDistance,
		buildSpeed    = (ud and ud.buildSpeed) or 0,
		emitAccum     = 0,
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

-- Round-robin piece selection: each scan visit advances a per-builder cursor
-- so all nano pieces emit in turn. Random pick (engine behaviour) statistically
-- leaves some pieces unselected for many consecutive throttled visits, which
-- makes multi-piece units (factories, big reclaim turrets) look like only some
-- emitters are active.
local function pickNanoPiece(info)
	local n = info.nPieces
	if n == 1 then return info.pieces[1] end
	local cursor = (info.pieceCursor or 0) + 1
	if cursor > n then cursor = 1 end
	info.pieceCursor = cursor
	return info.pieces[cursor]
end

--------------------------------------------------------------------------------
-- Emission
--------------------------------------------------------------------------------

local function spawnParticle(px, py, pz, vx, vy, vz, lifetime, r, g, b, frame, fadeFrames, inverse)
	if not nanoVBO then return end

	local death = frame + lifetime

	local rotVal = U.ROT_VAL_BASE + U.ROT_VAL_RANGE * (mathRandom() * 2 - 1)
	local rotVel = U.ROT_VEL_BASE + U.ROT_VEL_RANGE * (mathRandom() * 2 - 1)

	-- Per-particle size and alpha jitter. Size is packed into w alongside
	-- fadeFrames; alpha replaces the flat NANO_ALPHA in the color attribute.
	local sizeVar  = U.SIZE_VAR
	local nanoAlpha = U.NANO_ALPHA
	local alphaVar = U.ALPHA_VAR
	local sizeMult = (sizeVar  > 0) and (1.0 + sizeVar  * (mathRandom() * 2 - 1)) or 1.0
	local alpha    = (alphaVar > 0) and (nanoAlpha * (1.0 + alphaVar * (mathRandom() * 2 - 1))) or nanoAlpha
	if alpha < 0 then alpha = 0 end

	local id = nextID
	nextID = nextID + 1

	local s = instanceScratch
	s[1]=px; s[2]=py; s[3]=pz;  s[4]=packSizeFade(sizeMult, fadeFrames, inverse)
	s[5]=vx; s[6]=vy; s[7]=vz;  s[8]=frame
	s[9]=r;  s[10]=g; s[11]=b;  s[12]=alpha
	s[13]=rotVal; s[14]=rotVel; s[15]=frame; s[16]=death

	if pushElementInstance(nanoVBO, s, id, false, true, nil) then
		local bucket = deathBuckets[death]
		if bucket then
			bucket[#bucket + 1] = id
		else
			deathBuckets[death] = { id }
		end
		local oldest = deathBuckets.__oldestFrame
		if not oldest or death < oldest then
			deathBuckets.__oldestFrame = death
		end
		local latest = deathBuckets.__latestFrame
		if not latest or death > latest then
			deathBuckets.__latestFrame = death
		end
		liveCount = liveCount + 1
		return id
	end
end

-- Multi-emit form: count >= 1 spawns that many particles in a single call,
-- amortising piece-pos lookup, sqrt, range gate, normalize, jitter scale, LOS
-- gate selection and colour/fade lookup across the batch. Per-particle work
-- is only jitter rejection sampling, optional speed variance, spawnParticle
-- and homing register. Used by scanBuilders' single-piece path and by the
-- multi-piece round-robin (one batched call per piece).
--
-- spreadFrames: when > 0, stagger the batch's spawn times across this many
-- frames so a high-stride visit doesn't dump a clumped blob at the
-- nanopiece. Each particle is advanced along its velocity by a per-particle
-- time offset, simulating continuous emission since the last visit. The
-- caller bounds this to ~one steady-state visit interval (stride * runEvery)
-- so particles only get nudged a small distance ahead of the source -- they
-- must NOT be placed partway to the target. Defaults to 0 (legacy
-- simultaneous spawn) when omitted.
local function emitNano(builderID, info, endX, endY, endZ, inverse, jitterRadius, frame, targetUnitID, pieceIdx, count, spreadFrames, catchupAgeFrames)
	count = count or 1
	spreadFrames = spreadFrames or 0
	catchupAgeFrames = catchupAgeFrames or 0
	pieceIdx = pieceIdx or pickNanoPiece(info)
	local clampThisEmit = false
	local clampGuideY
	local clampPeakT

	-- Spring.GetUnitPiecePosDir is the hot Spring->C call here. Cached by
	-- (unitID, pieceIdx) for the duration of one scan frame, invalidated by
	-- per-frame epoch bump. Same builder/piece often emits multiple particles
	-- per frame (resurrect dual-emit, multi-piece cycling).
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

	if U.GROUND_CLAMP_ENABLED and (not info.isFactory) then
		clampThisEmit, clampGuideY, clampPeakT = shouldClampEmit(builderID, sx, sy, sz, endX, endY, endZ, frame)
		if clampThisEmit then
			endY = clampYAboveGround(endX, endY, endZ, frame)
		end
	end

	local dx, dy, dz = endX - sx, endY - sy, endZ - sz
	local lenSq = dx*dx + dy*dy + dz*dz
	if lenSq < 1.0 then return end
	local len = mathSqrt(lenSq)

	-- Range gate for moving-unit targets. Engine reach is (buildDistance +
	-- target radius); buildDistance alone under-counts heavily for large
	-- buildees. effectiveBD precomputed on meta at resolveTarget time. Hard
	-- cull is one compare; fade-band keep is rolled per-particle inside the loop.
	-- IMPORTANT: engine buildDistance is a horizontal cylinder (XZ only), not a
	-- sphere. A builder on a cliff has extra vertical distance but the same XZ
	-- reach, so we must compare effectiveBD against horizontal distance only.
	local fadeBandKeep
	if targetUnitID then
		local effectiveBD = info.targetMeta and info.targetMeta.effectiveBD
		if effectiveBD then
			local horzLen = mathSqrt(dx*dx + dz*dz)
			local maxLen = effectiveBD * BUILD_RANGE_MAX_EXTENSION
			if horzLen > maxLen then return end
			if horzLen > effectiveBD then
				fadeBandKeep = (maxLen - horzLen) / (effectiveBD * (BUILD_RANGE_MAX_EXTENSION - 1.0))
			end
		end
	end

	local invLen = 1.0 / len
	local ndx, ndy, ndz = dx * invLen, dy * invLen, dz * invLen

	-- Engine: dif += guRNG.NextVector() * jitterScale, where NextVector() is
	-- rejection-sampled inside the unit sphere (GlobalRNG.h). Builders pass a
	-- per-task radius (jitterScale = radius/len); factories use a fixed 0.15.
	local jitterScale = jitterRadius and (jitterRadius * invLen) or U.DIR_JITTER

	local r, g, b = info.r, info.g, info.b
	local fadeFrames = inverse and FADE_FRAMES_RECLAIM or FADE_FRAMES_REPAIR
	local infoIsMobile = info.isMobile
	local speedVar = U.SPEED_VAR
	local useWaypoint = clampThisEmit and U.GROUND_CLAMP_USE_WAYPOINT and clampGuideY and (not inverse)
	local nl = deathBuckets.__nanoLight
	local lightBridge = nl and nl.enabled and nl.bridgeReady
	local targetMeta = info.targetMeta
	local targetIsMobileUnit = targetMeta and targetMeta.isMobileUnit
	local fwdMaxRangeSq
	if targetUnitID and targetMeta then
		local effectiveBD = targetMeta.effectiveBD
		if effectiveBD then
			local maxRange = effectiveBD * BUILD_RANGE_MAX_EXTENSION
			fwdMaxRangeSq = maxRange * maxRange
		end
	end
	local trackEntryFree = U._trackEntryFree

	-- LOS check needed at all? Per-particle result is still cached on info
	-- because position varies for inverse emissions, but most visits skip the
	-- gate entirely (full view, ally builder, or LOS filter disabled).
	local needLosCheck = LOS_FILTER and (not cachedSpecFullView) and (info.allyTeam ~= cachedAllyTeamID)

	-- Three-tier enemy-builder visibility filter, evaluated once per emitNano
	-- call and cached for LOS_CACHE_FRAMES frames:
	--   tier 2 (IsUnitVisible true): fully seen -- full emission rate.
	--   tier 1 (INRADAR bit set, not visually seen): radar/sonar contact only
	--     (e.g. detected submarine) -- ENEMY_RADAR_EMIT_SCALE fraction of
	--     particles as a faint hint; per-particle IsPosInLos cull is skipped
	--     because the nanopiece/target position may be underwater.
	--   tier 0 (not detected at all): no particles.
	local builderVisTier = 2  -- default: fully visible (only matters when needLosCheck)
	if needLosCheck then
		local visFrame = info.visCheckFrame
		if visFrame and (frame - visFrame) < LOS_CACHE_FRAMES then
			builderVisTier = info.builderVisTier
		else
			if spIsUnitVisible(builderID, cachedAllyTeamID) then
				builderVisTier = 2
			else
				local losBits = Spring.GetUnitLosState(builderID, cachedAllyTeamID, true) or 0
				-- INRADAR bitmask bit = 2 (bit 1). losBits % 4 >= 2 isolates bit 1
				-- regardless of higher bits (PREVLOS = 4, CONTRADAR = 8).
				builderVisTier = (losBits % 4 >= 2) and 1 or 0
			end
			info.visCheckFrame  = frame
			info.builderVisTier = builderVisTier
		end
		if builderVisTier == 0 then return end
	end

	-- Stagger denominator: divide the symmetric spread window
	-- [-spreadFrames, +spreadFrames] across `count` slots so particles are
	-- evenly spaced in time (with sub-slot RNG jitter to avoid visible banding
	-- when count is small). spreadInv == 0 disables staggering.
	local spreadInv = (spreadFrames > 0 and count > 0) and (2 * spreadFrames / count) or 0
	local spreadBase = -spreadFrames
	local jitterTable = U._jitterTable
	local jitterCursor = U._jitterCursor
	local jitterTableLast = U._jitterTableLast

	-- `repeat ... until true` with `break` is Lua 5.1's idiom for `continue`:
	-- skip individual particles (fade-band drop, LOS hidden, lifetime
	-- underflow, HOMING_SKIP_INCOMPLETE branches) without aborting the batch.
	for i = 1, count do
		repeat
			if fadeBandKeep and mathRandom() > fadeBandKeep then break end
			-- Radar/sonar-only builder: stochastically drop most particles so
			-- only a faint ghost-spray hints at the undetected unit's activity.
			if builderVisTier == 1 and mathRandom() > ENEMY_RADAR_EMIT_SCALE then break end

			local jx = jitterTable[jitterCursor]
			local jy = jitterTable[jitterCursor + 1]
			local jz = jitterTable[jitterCursor + 2]
			jitterCursor = jitterCursor + 3
			if jitterCursor > jitterTableLast then jitterCursor = 1 end
			local fdx = ndx + jx * jitterScale
			local fdy = ndy + jy * jitterScale
			local fdz = ndz + jz * jitterScale

			local speed = NANO_SPEED
			if speedVar > 0 then
				speed = NANO_SPEED * (1.0 + speedVar * (mathRandom() * 2 - 1))
				if speed < 0.1 then speed = 0.1 end
			end
			local lifetime = mathCeil(len / speed)
			if lifetime < 1 then break end
			local vx, vy, vz = fdx * speed, fdy * speed, fdz * speed

			-- Engine (ProjectileHandler::AddNanoParticle, inverse branch):
			--   pos   = startPos + dif * len    (dif is normalized+jitter)
			--   speed = -dif * 3.0
			-- This makes the particle converge exactly on startPos (the
			-- builder). Spawning at the raw endPos would carry the jitter
			-- offset all the way through and the spray would diverge instead.
			local px, py, pz
			if inverse then
				px = sx + fdx * len
				py = sy + fdy * len
				pz = sz + fdz * len
				vx, vy, vz = -vx, -vy, -vz
			else
				px, py, pz = sx, sy, sz
			end
			if clampThisEmit and inverse then
				py = clampYAboveGround(px, py, pz, frame)
			end

			-- Stagger this particle's spawn along its velocity by `tOff` frames,
			-- where tOff is in [-spreadFrames, +spreadFrames]. Negative offsets
			-- place the particle slightly behind the nanopiece (partially
			-- occluded by the builder model); positive offsets place it
			-- slightly ahead. Lifetime is adjusted so total travel time to the
			-- target remains constant. If the bounded window would somehow
			-- exhaust the lifetime (very-close target), skip the particle.
			if spreadInv > 0 then
				local tOff = spreadBase + ((i - 1) + mathRandom()) * spreadInv
				local newLifetime = lifetime - mathFloor(tOff)
				if newLifetime < 1 then break end
				px = px + vx * tOff
				py = py + vy * tOff
				pz = pz + vz * tOff
				lifetime = newLifetime
			end

			-- Cold-offscreen catch-up: materialize a virtual particle already
			-- partway along its path when the camera first sees this endpoint.
			if catchupAgeFrames > 0 and lifetime > 1 then
				local age = mathFloor(mathRandom() * catchupAgeFrames)
				if age >= lifetime then age = lifetime - 1 end
				if age > 0 then
					px = px + vx * age
					py = py + vy * age
					pz = pz + vz * age
					lifetime = lifetime - age
				end
			end

			-- LOS filter: enemy emissions hidden when not in our LOS / not full
			-- view. Throttled per builder -- LOS at the builder location changes
			-- slowly relative to emit rate. Skipped for tier-1 (radar/sonar
			-- contact) builders: their nanopiece / target may be underwater and
			-- IsPosInLos would drop all remaining particles incorrectly.
			if needLosCheck and builderVisTier == 2 then
				local losFrame = info.losFrame
				local visible
				if losFrame and (frame - losFrame) < LOS_CACHE_FRAMES then
					visible = info.losVisible
				else
					visible = Spring.IsPosInLos(px, py, pz, cachedAllyTeamID) and true or false
					info.losFrame   = frame
					info.losVisible = visible
				end
				if not visible then break end
			end

			local wpFrame, finalX, finalY, finalZ
			if useWaypoint then
				finalX = px + vx * lifetime
				finalY = py + vy * lifetime
				finalZ = pz + vz * lifetime
				local peak = clampPeakT or 0.5
				if peak < 0.15 then peak = 0.15 elseif peak > 0.85 then peak = 0.85 end
				local leg1 = mathFloor(lifetime * peak)
				if leg1 < 1 then leg1 = 1 end
				if leg1 < lifetime then
					local wpX = px + (finalX - px) * peak
					local wpY = py + (finalY - py) * peak
					local wpZ = pz + (finalZ - pz) * peak
					if clampGuideY > wpY then wpY = clampGuideY end
					local invLeg1 = 1.0 / leg1
					vx = (wpX - px) * invLeg1
					vy = (wpY - py) * invLeg1
					vz = (wpZ - pz) * invLeg1
					wpFrame = frame + leg1
				end
			end

			local pid = spawnParticle(px, py, pz, vx, vy, vz, lifetime, r, g, b, frame, fadeFrames, inverse)
			if pid and clampThisEmit then
				if useWaypoint then
					if wpFrame then
						registerGroundClampParticle(pid, frame + lifetime, wpFrame, finalX, finalY, finalZ, targetUnitID)
					end
				else
					registerGroundClampParticle(pid, frame + lifetime)
				end
			end
			if pid then
				if lightBridge then
					if nl.spawnFrame ~= frame then
						nl.spawnFrame = frame
						nl.spawnCount = 0
					end
					local spawnCount = nl.spawnCount or 0
					if spawnCount < (nl.maxSpawnsPerFrame or 48) and nl.activeCount < (nl.maxActive or 2048) then
						local sampleAccum = (nl.sampleAccum or 1.0) + (nl.sampleRate or 0.25)
						if sampleAccum >= 1.0 then
							nl.sampleAccum = sampleAccum - 1.0
							nl.spawnCount = spawnCount + 1
							local lightLifetime = mathFloor(lifetime * (nl.lifeMult or 2.2) + 0.5)
							local minLifetime = nl.minLifetime or 14
							local maxLifetime = nl.maxLifetime or 96
							if lightLifetime < minLifetime then lightLifetime = minLifetime end
							if lightLifetime > maxLifetime then lightLifetime = maxLifetime end
							if lightLifetime > 1 then
								local sustain = mathFloor(lightLifetime * (nl.sustainFrac or 0.7) + 0.5)
								if sustain < 1 then sustain = 1 end
								if sustain > lightLifetime then sustain = lightLifetime end
								local lightID = "NANOP_" .. pid
								Script.LuaUI.EnvNanoBallisticLightSpawn(
									lightID,
									px, py, pz,
									vx, vy, vz,
									nl.spawnRadius or 25,
									info.lr or r, info.lg or g, info.lb or b, nl.alpha,
									lightLifetime,
									sustain,
									0.35, 0.15, 0.20, 0.0,
									frame
								)
								nl.active[pid] = frame
								nl.activeCount = nl.activeCount + 1
							end
						else
							nl.sampleAccum = sampleAccum
						end
					end
				end
			end

			-- Inverse particles converge on the builder. If the builder moves
			-- before the particle dies, the original straight-line trajectory
			-- ends at a stale location. Track so applyHoming() can re-aim.
			if inverse and pid then
				local list = homingByBuilder[builderID]
				if not list then
					list = {}
					homingByBuilder[builderID] = list
				end
				local nL = #list
				local p
				if nL >= HOMING_MAX_PER_BUILDER then
					p = list[1]
					for i = 1, nL - 1 do list[i] = list[i + 1] end
					list[nL] = p
				else
					local nFree = #trackEntryFree
					p = trackEntryFree[nFree]
					if p then
						trackEntryFree[nFree] = nil
					else
						p = {}
					end
					list[nL + 1] = p
				end
				p.id = pid; p.pieceIdx = pieceIdx; p.death = frame + lifetime; p.gc = clampThisEmit; p.lc = infoIsMobile
			elseif (not inverse) and pid and targetUnitID then
				-- Forward emission aimed at a moving unit (repair/capture).
				-- Track so applyForwardHoming() can curve the particle toward
				-- the target's new position when it moves.
				if HOMING_SKIP_INCOMPLETE then
					local ient = targetIncompleteCache[targetUnitID]
					local beingBuilt
					if ient and ient[1] == piecePosEpoch then
						beingBuilt = ient[2]
					else
						beingBuilt = spGetUnitIsBeingBuilt(targetUnitID) and true or false
						if ient then
							ient[1] = piecePosEpoch; ient[2] = beingBuilt
							if beingBuilt then ient[3] = frame end
						else
							targetIncompleteCache[targetUnitID] = { piecePosEpoch, beingBuilt, beingBuilt and frame or -1 }
						end
					end
					if beingBuilt then
						-- Track for death-fade: if the unfinished target dies or
						-- the build is cancelled, UnitDestroyed fades these so the
						-- trailing spray dissolves instead of popping.
						local flist = fadeFwdByTarget[targetUnitID]
						if not flist then
							flist = {}
							fadeFwdByTarget[targetUnitID] = flist
						end
						local fn = #flist
						local p
						if fn >= FADE_FWD_MAX_PER_TARGET then
							p = flist[1]
							for i = 1, fn - 1 do flist[i] = flist[i + 1] end
							flist[fn] = p
						else
							local nFree = #trackEntryFree
							p = trackEntryFree[nFree]
							if p then
								trackEntryFree[nFree] = nil
							else
								p = {}
							end
							flist[fn + 1] = p
						end
						p.id = pid; p.death = frame + lifetime; p.gc = clampThisEmit
						break
					end
					-- Grace window: still skip for a short time after
					-- completion so the last particles don't chase the unit out.
					local lastIncompleteFrame = ient and ient[3] or -1
					if lastIncompleteFrame >= 0 and (frame - lastIncompleteFrame) < HOMING_SKIP_GRACE_FRAMES then
						break
					end
				end
				-- Per-particle landing offset (jitter encodes a unique end-point)
				-- so spray spread is preserved at the destination as the target moves.
				local landingX = sx + fdx * len
				local landingY = sy + fdy * len
				local landingZ = sz + fdz * len
				local offX = landingX - endX
				local offY = landingY - endY
				local offZ = landingZ - endZ
				local list = homingFwdByTarget[targetUnitID]
				if not list then
					list = {}
					homingFwdByTarget[targetUnitID] = list
				end
				local nL = #list
				local p
				if nL >= HOMING_FWD_MAX_PER_TARGET then
					p = list[1]
					for i = 1, nL - 1 do list[i] = list[i + 1] end
					list[nL] = p
				else
					local nFree = #trackEntryFree
					p = trackEntryFree[nFree]
					if p then
						trackEntryFree[nFree] = nil
					else
						p = {}
					end
					list[nL + 1] = p
				end
				p.id = pid; p.death = frame + lifetime; p.ox = offX; p.oy = offY; p.oz = offZ; p.gc = clampThisEmit; p.builderID = builderID; p.pieceIdx = pieceIdx; p.maxRangeSq = fwdMaxRangeSq; p.lc = targetIsMobileUnit
			end
		until true
	end
	U._jitterCursor = jitterCursor
end

local function emitNanoBatch(unitID, info, ex, ey, ez, inverse, jitterRadius, frame, targetUnitID, isResurrect, count, spreadWindow, catchupAgeFrames)
	if count <= 0 then return end
	local n = info.nPieces
	if n == 1 then
		local p1 = info.pieces[1]
		emitNano(unitID, info, ex, ey, ez, inverse, jitterRadius, frame, targetUnitID, p1, count, spreadWindow, catchupAgeFrames)
		if isResurrect then
			emitNano(unitID, info, ex, ey, ez, true, jitterRadius, frame, nil, p1, count, spreadWindow, catchupAgeFrames)
		end
	else
		local pieces = info.pieces
		local startCursor = info.pieceCursor or 0
		local base = mathFloor(count / n)
		local rem  = count - base * n
		for i = 1, n do
			local cnt = base
			if i <= rem then cnt = cnt + 1 end
			if cnt > 0 then
				local cursor = startCursor + i
				if cursor > n then cursor = cursor - n end
				local pIdx = pieces[cursor]
				emitNano(unitID, info, ex, ey, ez, inverse, jitterRadius, frame, targetUnitID, pIdx, cnt, spreadWindow, catchupAgeFrames)
				if isResurrect then
					emitNano(unitID, info, ex, ey, ez, true, jitterRadius, frame, nil, pIdx, cnt, spreadWindow, catchupAgeFrames)
				end
			end
		end
		local newCursor = startCursor + count
		while newCursor > n do newCursor = newCursor - n end
		info.pieceCursor = newCursor
	end
end

--------------------------------------------------------------------------------
-- Reclaim-completion burst: one-shot cluster of inverse particles emanating
-- from random points within the destroyed unit's collision volume, distributed
-- across the builders that were actively reclaiming it. Builders are filtered
-- by the reclaimedTargets tracker (populated in the scan loop), so only
-- builders whose teams actually got the metal contribute -- enemy or
-- third-party builders never see the burst.
--------------------------------------------------------------------------------

local function fireReclaimBurst(targetUnitID, targetUnitDefID, attackerTeam, buildProgress, frame)
	local set = reclaimedTargets[targetUnitID]
	if not set then return end
	reclaimedTargets[targetUnitID] = nil

	-- Collect the builders that are still alive AND belong to the team that
	-- actually received the metal (attackerTeam). Builders from other teams
	-- that were also reclaiming don't get the burst -- they got nothing.
	local builders = {}
	local nb = 0
	for builderID in pairs(set) do
		local info = builderCache[builderID]
		if info and spValidUnitID(builderID) and spGetUnitTeam(builderID) == attackerTeam then
			-- Clear the back-reference so the builder doesn't keep a stale
			-- reclaimTarget pointing at a dead unit (would cause a spurious
			-- removal attempt next scan).
			if info.reclaimTarget == targetUnitID then
				info.reclaimTarget = nil
			end
			nb = nb + 1
			builders[nb] = { id = builderID, info = info }
		end
	end
	if nb == 0 then return end

	-- Particle count: per-builder share follows a log curve in metal cost, then
	-- scaled by nb^BUILDER_EXP so more reclaimers always add more particles but
	-- with diminishing returns (e.g. 4 reclaimers → ~2.6× not 4× at EXP=0.7).
	-- buildProgress scales metalCost so a half-built unit contributes half as many
	-- particles as a fully-built one (it's only worth half the metal).
	local ud = targetUnitDefID and UnitDefs[targetUnitDefID] or nil
	local metalCost = ((ud and ud.metalCost) or 0) * (buildProgress or 1.0)
	local perBuilder = RECLAIM_BURST_BASE + mathFloor(RECLAIM_BURST_LOG_K * mathLog(1 + metalCost / RECLAIM_BURST_LOG_NORM) + 0.5)
	if perBuilder < 1 then perBuilder = 1 end
	local total = mathFloor(perBuilder * (nb ^ RECLAIM_BURST_BUILDER_EXP) + 0.5)
	if total > RECLAIM_BURST_MAX then total = RECLAIM_BURST_MAX end
	if total < 1 then return end

	-- Burst origin: collision volume center if available, else mid-position.
	-- GetUnitCollisionVolumeData returns scale, offset, type, axis, disabled.
	local cx, cy, cz, radius
	local _, _, _, mx, my, mz = spGetUnitPosition(targetUnitID, true)
	cx, cy, cz = mx, my, mz
	local sx, sy, sz, ox, oy, oz = spGetUnitCollisionVolumeData(targetUnitID)
	if sx and ox then
		-- Offset is in unit-local space; for the symmetric majority of units
		-- (and certainly close enough for a particle effect) treat it as a
		-- world-space delta from mid-pos. Acceptable visual approximation
		-- given the random spread we apply on top.
		cx = (mx or 0) + ox
		cy = (my or 0) + oy
		cz = (mz or 0) + oz
		-- Use the smallest axis as the spawn radius so we stay inside thin
		-- volumes (e.g. flat factories) instead of poking through.
		local r = sx
		if sy and sy < r then r = sy end
		if sz and sz < r then r = sz end
		radius = (r or 0) * 0.5 * RECLAIM_BURST_VOL_FRAC
	else
		radius = (spGetUnitRadius(targetUnitID) or 32) * RECLAIM_BURST_VOL_FRAC
	end
	if not cx or radius <= 0 then return end

	-- Distribute particles round-robin across contributing builders. Each
	-- particle gets its own random spawn point inside the volume sphere
	-- (rejection-sampled), so the cluster is spatially varied even though all
	-- particles converge back to one builder per slot.
	local base = mathFloor(total / nb)
	local rem  = total - base * nb
	for bi = 1, nb do
		local b = builders[bi]
		local cnt = base + (bi <= rem and 1 or 0)
		if cnt > 0 then
			-- emitNano handles LOS/distance/offscreen gating, piecePos lookup,
			-- velocity composition and inverse-spawn placement. Calling it
			-- once per particle (count=1) so each gets a distinct random
			-- spawn point within the volume.
			for _ = 1, cnt do
				local jx, jy, jz
				repeat
					jx = mathRandom() * 2 - 1
					jy = mathRandom() * 2 - 1
					jz = mathRandom() * 2 - 1
				until (jx*jx + jy*jy + jz*jz) <= 1.0
				local ex = cx + jx * radius
				local ey = cy + jy * radius
				local ez = cz + jz * radius
				-- Pass jitterRadius=nil so emitNano's per-particle direction
				-- jitter stays at the small DIR_JITTER default; the spatial
				-- spread already comes from the random spawn point.
				emitNano(b.id, b.info, ex, ey, ez, true, nil, frame, nil, nil, 1, 0)
			end
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
			accept, factor = ((cmdID == CMD_REPAIR) and (isUnit or isFeature) or isUnit), 0.5
		end
		if not accept then
			info.targetMeta = nil
			return nil
		end

		local radius = isUnit and spGetUnitRadius(resolvedID) or spGetFeatureRadius(resolvedID)
		local jitterRadius = (radius and radius > 0) and (radius * factor) or nil
		if isReclaim and isUnit and jitterRadius then
			jitterRadius = jitterRadius * RECLAIM_UNIT_JITTER_SCALE
		end

		meta = {
			cmdID        = cmdID,
			targetID     = targetID,    -- raw value from GetUnitWorkerTask (for cache key)
			resolvedID   = resolvedID,  -- engine ID (with MaxUnits offset stripped)
			isFeature    = isFeature or false,
			isMobileUnit = isUnit and isMobileUnitDef[spGetUnitDefID(resolvedID)] and true or false,
			jitterRadius = jitterRadius,
			targetRadius = radius or 0, -- raw radius for build-range gate (engine reach is buildDistance + target radius)
			effectiveBD  = info.buildDistance and (info.buildDistance + (radius or 0)) or nil,
			isReclaim    = isReclaim,
			isResurrect  = isResurrect,
			visFrame     = -OFFSCREEN_VIS_CACHE_FRAMES,
			visible      = false,
			lastVisibleFrame   = -1000000000,
			coldOffscreenUntil = 0,
			virtualEmits       = 0,
			virtualAgeFrames   = 0,
			virtualFrame       = 0,
		}
		-- Keep assistant builders aimed at the actual unit being built.
		-- HOMING_SKIP_INCOMPLETE already prevents odd forward-homing while the
		-- buildee is still incomplete, so no factory-center anchor override needed.
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

local function materializeVisibleVirtualStreams(frame)
	local virtualList = deathBuckets.__virtualStreamList
	if not nanoVBO or not virtualList or #virtualList == 0 then return end

	local camX, camY, camZ = Spring.GetCameraPosition()
	local lastCamX = deathBuckets.__virtualCamX
	if lastCamX and not deathBuckets.__virtualStreamsNeedCheck then
		local dcx = camX - lastCamX
		local dcy = camY - deathBuckets.__virtualCamY
		local dcz = camZ - deathBuckets.__virtualCamZ
		if (dcx * dcx + dcy * dcy + dcz * dcz) < 4096 then return end
	end
	deathBuckets.__virtualCamX = camX
	deathBuckets.__virtualCamY = camY
	deathBuckets.__virtualCamZ = camZ
	deathBuckets.__virtualStreamsNeedCheck = false

	local preUsed = nanoVBO.usedElements or 0
	local virtualSet = deathBuckets.__virtualStreamSet
	local listCount = #virtualList
	local maxChecks = OFFSCREEN_VIRTUAL_CHECKS_PER_DRAW
	if maxChecks > listCount then maxChecks = listCount end
	local idx = deathBuckets.__virtualStreamCursor or 1
	if idx < 1 or idx > listCount then idx = 1 end
	piecePosEpoch = piecePosEpoch + 1

	local checked = 0
	while checked < maxChecks and listCount > 0 do
		if idx > listCount then idx = 1 end
		local unitID = virtualList[idx]
		local info = builderCache[unitID]
		local meta = info and info.targetMeta
		local virtualEmits = meta and meta.virtualEmits or 0
		local remove = false
		if virtualEmits > 0 then
			local visible = false
			local vx = meta.virtualX
			if vx then
				local radius = meta.virtualRadius or meta.targetRadius or 64
				if radius < 64 then radius = 64 end
				-- Small prewarm margin: DrawWorld runs before drawing, so a huge
				-- offscreen radius just materializes streams far outside the view.
				radius = radius + 192
				visible = Spring.IsSphereInView(vx, meta.virtualY, meta.virtualZ, radius) and true or false
			end
			if visible then
				local ex, ey, ez, inverse, jitterRadius, isResurrect, targetUnitID = resolveTarget(info, meta.cmdID, meta.targetID)
				meta = info.targetMeta
				if ex and meta then
					if info.isFactory then jitterRadius = nil end
					meta.visFrame = frame
					meta.visible = true
					meta.lastVisibleFrame = frame
					meta.coldOffscreenUntil = 0
					local catchupAgeFrames = meta.virtualAgeFrames or 0
					meta.virtualEmits = 0
					meta.virtualAgeFrames = 0
					meta.virtualFrame = frame
					emitNanoBatch(unitID, info, ex, ey, ez, inverse, jitterRadius, frame, targetUnitID, isResurrect, virtualEmits, 0, catchupAgeFrames)
				end
				remove = true
			end
		else
			remove = true
		end
		if remove then
			if virtualSet then virtualSet[unitID] = nil end
			virtualList[idx] = virtualList[listCount]
			virtualList[listCount] = nil
			listCount = listCount - 1
		else
			idx = idx + 1
		end
		checked = checked + 1
	end

	if idx > listCount then idx = 1 end
	deathBuckets.__virtualStreamCursor = idx
	deathBuckets.__virtualStreamCount = listCount
	local postUsed = nanoVBO.usedElements or 0
	if postUsed > preUsed then
		uploadElementRange(nanoVBO, preUsed, postUsed)
	end
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
	local trackEntryFree = U._trackEntryFree

	for builderID, list in pairs(homingByBuilder) do
		local info = builderCache[builderID]
		if not info or not spValidUnitID(builderID) then
			U.recycleTrackList(list)
			homingByBuilder[builderID] = nil
		else
			local writeIdx = 0
			-- Hoist the high half of the piecePosCache key out of the per-particle
			-- loop. Hot path: ~thousands of particles per scan in heavy reclaim.
			local builderKeyHi = builderID * 256
			local clampDelta = U.GROUND_CLAMP_SMART_DELTA
			for i = 1, #list do
				local p = list[i]
				local remaining = p.death - frame
				local slot = (remaining > 1) and idtoIndex[p.id] or nil
				if slot then
					-- Resolve current piece position via the per-frame cache.
					local pieceIdx = p.pieceIdx
					local key = builderKeyHi + pieceIdx
					local entry = piecePosCache[key]
					local pieceMoving
					local nx, ny, nz
					if entry and entry[1] == piecePosEpoch then
						nx, ny, nz = entry[2], entry[3], entry[4]
						pieceMoving = entry[8]
						if pieceMoving == nil then
							local px, py, pz = entry[5], entry[6], entry[7]
							if px then
								local mdx = nx - px
								local mdy = ny - py
								local mdz = nz - pz
								pieceMoving = (mdx*mdx + mdy*mdy + mdz*mdz) >= 1.0
							else
								pieceMoving = true
							end
							entry[8] = pieceMoving
						end
					else
						local ox, oy, oz
						if entry then ox, oy, oz = entry[2], entry[3], entry[4] end
						nx, ny, nz = spGetUnitPiecePosDir(builderID, pieceIdx)
						if nx then
							if entry then
								entry[1] = piecePosEpoch
								entry[2] = nx; entry[3] = ny; entry[4] = nz
								entry[5] = ox or nx; entry[6] = oy or ny; entry[7] = oz or nz
							else
								entry = { piecePosEpoch, nx, ny, nz, nx, ny, nz }
								piecePosCache[key] = entry
							end
							if ox then
								local mdx = nx - ox
								local mdy = ny - oy
								local mdz = nz - oz
								pieceMoving = (mdx*mdx + mdy*mdy + mdz*mdz) >= 1.0
							else
								pieceMoving = true
							end
							entry[8] = pieceMoving
							entry[9] = nil
						end
					end

					if nx then
						if pieceMoving == false and (not p.gc) then
							writeIdx = writeIdx + 1
							list[writeIdx] = p
						else
						local base = (slot - 1) * step
						local sx, sy, sz   = data[base+1], data[base+2], data[base+3]
						local vx, vy, vz   = data[base+5], data[base+6], data[base+7]
						local spawnF       = data[base+8]
						local elapsed      = frame - spawnF
						local cpx = sx + vx * elapsed
						local cpy = sy + vy * elapsed
						local cpz = sz + vz * elapsed
						local aimY = ny
						if p.gc then
							-- For reclaim on high-to-low terrain, keep particles above current
							-- ground during homing updates so they travel along the upper
							-- surface before descending at the cliff break.
							local gyCur = getGroundYMargin(cpx, cpz, frame)
							if cpy < gyCur then cpy = gyCur end
							local gyDst = entry and entry[9]
							if gyDst == nil then
								gyDst = getGroundYMargin(nx, nz, frame)
								if entry then entry[9] = gyDst end
							end
							if aimY < gyDst then aimY = gyDst end
							if gyCur > (aimY + clampDelta) then
								aimY = gyCur
							end
						end
						-- Inverse particles all converge on the builder piece (engine
						-- behaviour: speed = -dif*3 makes pos arrive at startPos exactly).
						-- Visual spread comes from staggered spawn positions, not from
						-- the velocity direction, so simple aim is correct here.
						local invR = 1.0 / remaining
						data[base+1] = cpx;            data[base+2] = cpy;            data[base+3] = cpz
						data[base+5] = (nx - cpx) * invR
						data[base+6] = (aimY - cpy) * invR
						data[base+7] = (nz - cpz) * invR
						data[base+8] = frame
						local nl = deathBuckets.__nanoLight
						if p.lc and nl and nl.bridgeReady then
							local lastFix = nl.active[p.id]
							local minFrames = nl.correctEvery or 10
							if lastFix and (frame - lastFix) >= minFrames then
								nl.active[p.id] = frame
								Script.LuaUI.EnvNanoBallisticLightCorrect("NANOP_" .. p.id, cpx, cpy, cpz, (nx - cpx) * invR, (aimY - cpy) * invR, (nz - cpz) * invR, frame)
							end
						end
						local s0 = slot - 1
						if s0 < dirtyMin     then dirtyMin = s0     end
						if s0 + 1 > dirtyMax then dirtyMax = s0 + 1 end
						writeIdx = writeIdx + 1
						list[writeIdx] = p
						end
					else
						trackEntryFree[#trackEntryFree + 1] = p
					end
				else
					trackEntryFree[#trackEntryFree + 1] = p
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

local function fadeNanoDeferredLight(pid, frame, fadeFrames)
	local nl = deathBuckets.__nanoLight
	if not (nl and nl.enabled and nl.fadeReady and nl.active and nl.active[pid]) then return end
	nl.active[pid] = frame
	Script.LuaUI.EnvNanoBallisticLightFade("NANOP_" .. pid, frame, fadeFrames)
end

local targetPosEpoch = 0

local function applyForwardHoming(frame, dirtyMin, dirtyMax)
	if not nanoVBO then return dirtyMin, dirtyMax end
	if next(homingFwdByTarget) == nil then return dirtyMin, dirtyMax end
	local data       = nanoVBO.instanceData
	local idtoIndex  = nanoVBO.instanceIDtoIndex
	local step       = nanoVBO.instanceStep
	local trackEntryFree = U._trackEntryFree
	local function fadeParticle(slot, p)
		local remaining = p.death - frame
		if remaining <= 0 then return false end
		local fadeFrames = mathFloor(FADE_FRAMES_DEATH * (0.4 + mathRandom()))
		if fadeFrames < 1 then fadeFrames = 1 end
		if fadeFrames > remaining then fadeFrames = remaining end
		local newDeath = frame + fadeFrames
		local base = (slot - 1) * step
		data[base+16] = newDeath
		local packed = data[base+4]
		local absPacked = packed < 0 and -packed or packed
		local oldFade = mathFloor(absPacked / 1024)
		local sizeBits = absPacked - oldFade * 1024
		local newPacked = sizeBits + fadeFrames * 1024
		data[base+4] = packed < 0 and -newPacked or newPacked
		local s0 = slot - 1
		if s0 < dirtyMin then dirtyMin = s0 end
		if s0 + 1 > dirtyMax then dirtyMax = s0 + 1 end
		fadeNanoDeferredLight(p.id, frame, fadeFrames)
		return true
	end

	targetPosEpoch = targetPosEpoch + 1

	for targetID, list in pairs(homingFwdByTarget) do
		if not spValidUnitID(targetID) then
			U.recycleTrackList(list)
			homingFwdByTarget[targetID] = nil
		else
			-- Detect work-complete (full HP, buildProgress >= 1) and trigger the
			-- per-particle death fade so the trailing spray dissolves instead of
			-- snapping off. Throttled to HEALTH_CHECK_EVERY -- HP changes on the
			-- order of seconds and natural particle lifetime (~0.5s) hides any
			-- missed edge. Last-check stamp is hashed onto the list itself so it
			-- GCs with the list (no separate cleanup table needed).
			local fadedOut = false
			local lastH = list._lastHealthCheck
			if not lastH or (frame - lastH) >= HEALTH_CHECK_EVERY then
				list._lastHealthCheck = frame
				local h, maxH, _, _, bp = spGetUnitHealth(targetID)
				if h and maxH and h >= maxH and (bp == nil or bp >= 1.0) then
					if not list._fadingOut then
						fadeOutHomingFwd(targetID)
						list._fadingOut = true
					end
				else
					-- Crashing aircraft: treat as dead. The unit still exists
					-- (UnitDestroyed hasn't fired) but is moving fast and
					-- predictably down -- left untreated, the spray would chase
					-- the wreck to the ground. Cache air-defID lookup on the list
					-- to skip spGetUnitDefID on every poll.
					local isAir = list._isAir
					if isAir == nil then
						isAir = isAirUnitDef[spGetUnitDefID(targetID)] and true or false
						list._isAir = isAir
					end
					if isAir then
						local mt = spGetUnitMoveTypeData(targetID)
						if mt and mt.aircraftState == "crashing" then
							fadeOutHomingFwd(targetID)
							U.recycleTrackList(list)
							homingFwdByTarget[targetID] = nil
							targetPosCache[targetID]    = nil
							fadedOut = true
						end
					end
				end
			end
			if not fadedOut then
			local isAir = list._isAir
			if isAir == nil then
				isAir = isAirUnitDef[spGetUnitDefID(targetID)] and true or false
				list._isAir = isAir
			end
				local maxSpeed = NANO_SPEED * (isAir and 1.35 or 2.0)
			local maxSpeedSq = maxSpeed * maxSpeed
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
						entry[9] = frame
					else
						entry = { targetPosEpoch, tx, ty, tz, tx, ty, tz, 0, frame }
						targetPosCache[targetID] = entry
					end
				end
			end

			if not tx then
				U.recycleTrackList(list)
				homingFwdByTarget[targetID] = nil
				targetPosCache[targetID]    = nil
			else
				-- Stationary detection: compare current pos to last-seen pos.
				-- Threshold is generous (1 elmo) -- builders sub-elmo drift doesn't
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
						if (p.death - frame) >= 1 and idtoIndex[p.id] then
							writeIdx = writeIdx + 1
							list[writeIdx] = p
						else
							trackEntryFree[#trackEntryFree + 1] = p
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
					local slot = (remaining >= 1) and idtoIndex[p.id] or nil
					if slot then
						local fadeParticleOut = false
						local maxRangeSq = p.maxRangeSq
						if maxRangeSq and p.builderID and p.pieceIdx then
							local key = p.builderID * 256 + p.pieceIdx
							local bx, bz
							local pent = piecePosCache[key]
							if pent and pent[1] == piecePosEpoch then
								bx, bz = pent[2], pent[4]
							else
								local px, py, pz = spGetUnitPiecePosDir(p.builderID, p.pieceIdx)
								if px then
									if pent then
										pent[1] = piecePosEpoch
										pent[2] = px; pent[3] = py; pent[4] = pz
									else
										piecePosCache[key] = { piecePosEpoch, px, py, pz }
									end
									bx, bz = px, pz
								end
							end
							if bx then
								local rdx = tx - bx
								local rdz = tz - bz
								if (rdx * rdx + rdz * rdz) > maxRangeSq then
									fadeParticleOut = fadeParticle(slot, p)
								end
							end
						end
						if not fadeParticleOut then
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
						local aimZ = tz + p.oz
						local aimY = ty + p.oy
						local dvx = aimX - cpx
						local dvy = aimY - cpy
						local dvz = aimZ - cpz
						local invR = 1.0 / remaining
						local needSpeedSq = (dvx*dvx + dvy*dvy + dvz*dvz) * (invR * invR)
						if needSpeedSq > maxSpeedSq then
							fadeParticleOut = fadeParticle(slot, p)
						else
							data[base+1] = cpx;            data[base+2] = cpy;            data[base+3] = cpz
							data[base+5] = dvx * invR
							data[base+6] = dvy * invR
							data[base+7] = dvz * invR
							data[base+8] = frame
							local nl = deathBuckets.__nanoLight
							if p.lc and nl and nl.bridgeReady then
								local lastFix = nl.active[p.id]
								local minFrames = nl.correctEvery or 10
								if lastFix and (frame - lastFix) >= minFrames then
									nl.active[p.id] = frame
									Script.LuaUI.EnvNanoBallisticLightCorrect("NANOP_" .. p.id, cpx, cpy, cpz, dvx * invR, dvy * invR, dvz * invR, frame)
								end
							end
							local s0 = slot - 1
							if s0 < dirtyMin     then dirtyMin = s0     end
							if s0 + 1 > dirtyMax then dirtyMax = s0 + 1 end
						end
						end
						if not fadeParticleOut then
							writeIdx = writeIdx + 1
							list[writeIdx] = p
						else
							trackEntryFree[#trackEntryFree + 1] = p
						end
					else
						trackEntryFree[#trackEntryFree + 1] = p
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
-- Optional global in-flight terrain clamp. Reprojects current particle position
-- (and destination inferred from remaining velocity) above ground+margin.
-- This addresses straight-line tunneling through cliffs for non-homed particles.
--------------------------------------------------------------------------------

local function applyGroundClamp(frame, dirtyMin, dirtyMax)
	if not U.GROUND_CLAMP_ENABLED then return dirtyMin, dirtyMax end
	if not nanoVBO then return dirtyMin, dirtyMax end
	local runEvery = U.GROUND_CLAMP_RUN_EVERY or 1
	if runEvery < 1 then runEvery = 1 end
	if frame < (deathBuckets.__nextGroundClampFrame or 0) then return dirtyMin, dirtyMax end
	deathBuckets.__nextGroundClampFrame = frame + runEvery

	local total = #groundClampParticles
	if CLAMP_DEBUG and total > clampDbg.maxSubset then clampDbg.maxSubset = total end
	if total == 0 then
		groundClampCursor = 1
		return dirtyMin, dirtyMax
	end

	local maxPer = U.GROUND_CLAMP_MAX_PER_STEP or 0
	if maxPer < 1 or maxPer > total then maxPer = total end

	local data = nanoVBO.instanceData
	local step = nanoVBO.instanceStep
	local idtoIndex = nanoVBO.instanceIDtoIndex
	local recheckHit = U.GROUND_CLAMP_RECHECK_HIT or 2
	local recheckMiss = U.GROUND_CLAMP_RECHECK_MISS or 4
	local idx = groundClampCursor
	if idx < 1 or idx > total then idx = 1 end

	local processed = 0
	local checked = 0
	local maxChecks = total + maxPer
	local n = total
	while processed < maxPer and checked < maxChecks do
		if n == 0 then
			idx = 1
			break
		end
		if idx > n then idx = 1 end
		local entry = groundClampParticles[idx]
		local slot = idtoIndex[entry.id]
		if (not slot) or entry.death <= frame + 1 then
			local removed = entry
			groundClampParticles[idx] = groundClampParticles[n]
			groundClampParticles[n] = nil
			n = n - 1
			groundClampFree[#groundClampFree + 1] = removed
			if CLAMP_DEBUG then clampDbg.dropped = clampDbg.dropped + 1 end
		elseif entry.next and frame < entry.next then
			idx = idx + 1
		elseif entry.wp then
			local base = (slot - 1) * step
			local rem = entry.death - frame
			if rem > 1 and entry.fx then
				local fx, fy, fz = entry.fx, entry.fy, entry.fz
				if entry.targetID and not recentFactoryBuildTargetCache[entry.targetID] then
					local _, _, _, mx, my, mz = spGetUnitPosition(entry.targetID, true)
					if mx then
						fx, fy, fz = mx, my, mz
					end
				end
				local sx, sy, sz = data[base + 1], data[base + 2], data[base + 3]
				local vx, vy, vz = data[base + 5], data[base + 6], data[base + 7]
				local spawnF = data[base + 8]
				local elapsed = frame - spawnF
				local cpx = sx + vx * elapsed
				local cpy = sy + vy * elapsed
				local cpz = sz + vz * elapsed
				local invR = 1.0 / rem
				data[base + 1] = cpx
				data[base + 2] = cpy
				data[base + 3] = cpz
				data[base + 5] = (fx - cpx) * invR
				data[base + 6] = (fy - cpy) * invR
				data[base + 7] = (fz - cpz) * invR
				data[base + 8] = frame
				local s0 = slot - 1
				if s0 < dirtyMin then dirtyMin = s0 end
				if s0 + 1 > dirtyMax then dirtyMax = s0 + 1 end
				if CLAMP_DEBUG then clampDbg.corrected = clampDbg.corrected + 1 end
			end
			local removed = entry
			groundClampParticles[idx] = groundClampParticles[n]
			groundClampParticles[n] = nil
			n = n - 1
			groundClampFree[#groundClampFree + 1] = removed
			processed = processed + 1
			if CLAMP_DEBUG then clampDbg.processed = clampDbg.processed + 1 end
		else
			local base = (slot - 1) * step
			local remaining = entry.death - frame
			local sx, sy, sz = data[base + 1], data[base + 2], data[base + 3]
			local vx, vy, vz = data[base + 5], data[base + 6], data[base + 7]
			local spawnF = data[base + 8]
			local elapsed = frame - spawnF
			local cpx = sx + vx * elapsed
			local cpy = sy + vy * elapsed
			local cpz = sz + vz * elapsed
			local clampedCpy = clampYAboveGround(cpx, cpy, cpz, frame)

			if clampedCpy ~= cpy then
				local aimX = cpx + vx * remaining
				local aimY = cpy + vy * remaining
				local aimZ = cpz + vz * remaining
				local invR = 1.0 / remaining
				data[base + 1] = cpx
				data[base + 2] = clampedCpy
				data[base + 3] = cpz
				data[base + 5] = (aimX - cpx) * invR
				data[base + 6] = (aimY - clampedCpy) * invR
				data[base + 7] = (aimZ - cpz) * invR
				data[base + 8] = frame
				local s0 = slot - 1
				if s0 < dirtyMin then dirtyMin = s0 end
				if s0 + 1 > dirtyMax then dirtyMax = s0 + 1 end
				if CLAMP_DEBUG then clampDbg.corrected = clampDbg.corrected + 1 end
				entry.next = frame + recheckHit
			else
				entry.next = frame + recheckMiss
			end

			processed = processed + 1
			if CLAMP_DEBUG then clampDbg.processed = clampDbg.processed + 1 end
			idx = idx + 1
		end
		checked = checked + 1
	end

	groundClampCursor = idx
	return dirtyMin, dirtyMax
end

--------------------------------------------------------------------------------
-- Per-frame builder scan
--------------------------------------------------------------------------------

local function scanBuilders(frame)
	tracy.ZoneBeginN("G:NanoParticles:RunFrame:ScanBuilders")
	-- Engine emits nano particles for every active builder regardless of camera
	-- frustum. Iterate the tracked builder set; LOS filtering happens in emitNano.
	-- Per-frame epoch bump implicitly invalidates piecePosCache / targetPosCache
	-- without clearing the tables.
	piecePosEpoch = piecePosEpoch + 1

	-- Snapshot pre-scan tail so we can do ONE upload covering all spawns this
	-- frame. Pushes use noUpload=true; we upload [first..last] here (spawns
	-- always append, so the new range is contiguous at the tail).
	local preUsed = nanoVBO and nanoVBO.usedElements or 0

	-- Engine-style saturation gate evaluated per-emission. Pre-computed once so
	-- we skip per-builder math (GetUnitPiecePosDir, sqrt, RNG, target resolution)
	-- for the majority of dropped emissions when at capacity. Under high-gamespeed
	-- catchup, shrink the effective cap so saturation ramps up faster.
	local effectiveMax = MAX_PARTICLES
	if speedThrottle > 0.0 then
		effectiveMax = MAX_PARTICLES * (1.0 - GAMESPEED_MAX_CUT * speedThrottle)
	end
	local saturation = liveCount / effectiveMax
	-- NOTE: don't early-return on saturation or scan-skip here -- the
	-- per-frame homing pass at the bottom must still run, otherwise long-lived
	-- particles aimed at far/moving targets (which are the ones that saturate
	-- the pool in the first place) fly on their stale spawn-time trajectory
	-- and never curve toward the target. Instead, skip just the per-builder
	-- emission loop below.
	local skipEmit = saturation >= 1.0

	-- Dynamic scan-frame skip: empty pool -> every frame, saturated -> every
	-- MAX_SCAN_RUN_EVERY frames. emitProb scales by runEvery so total emission
	-- rate is preserved.
	local runEvery = MIN_SCAN_RUN_EVERY + math.floor(saturation * (MAX_SCAN_RUN_EVERY - MIN_SCAN_RUN_EVERY) + 0.5)
	if runEvery < 1 then runEvery = 1 end
	local scanTick = (deathBuckets.__scanFrameTick or 0) + 1
	deathBuckets.__scanFrameTick = scanTick
	if runEvery > 1 and (scanTick % runEvery) ~= 0 then skipEmit = true end

	if not skipEmit then
	tracy.ZoneBeginN("G:NanoParticles:RunFrame:ScanBuilders:EmitLoop")
	tracy.ZoneBeginN("G:NanoParticles:RunFrame:ScanBuilders:EmitLoop:Setup")
	-- Camera position for the per-emit distance throttle. One call per scan;
	-- DISTANT_EMIT_* squared bands live at module scope.
	local camX, camY, camZ = Spring.GetCameraPosition()

	-- Dynamic stride: empty pool -> 1 (full fidelity), near full -> MAX_SCAN_STRIDE.
	-- Per-builder elapsed-frames-based emit count compensates so total rate is constant.
	local stride = MIN_SCAN_STRIDE + math.floor(saturation * (MAX_SCAN_STRIDE - MIN_SCAN_STRIDE) + 0.5)
	if stride < 1 then stride = 1 end

	-- Pool-saturation-driven offscreen keep-fraction. Recomputed once per scan
	-- so all per-emit checks below use the same value.
	local offscreenKeep
	if saturation <= OFFSCREEN_EMIT_KEEP_SAT_PIVOT then
		offscreenKeep = OFFSCREEN_EMIT_KEEP_MAX
	else
		local t = (saturation - OFFSCREEN_EMIT_KEEP_SAT_PIVOT) * OFFSCREEN_EMIT_KEEP_BAND_INV
		offscreenKeep = OFFSCREEN_EMIT_KEEP_MAX + t * (OFFSCREEN_EMIT_KEEP_MIN - OFFSCREEN_EMIT_KEEP_MAX)
	end

	local list = trackedBuildersList
	local n    = #list
	-- Use scan-call counter for the stride offset rather than raw frame: otherwise
	-- runEvery=2 + stride=2 can make the same builder coset win every scan.
	local start = (scanTick % stride) + 1
	-- Iterate this scan's stride-coset (indices start, start+stride, ..., <= n)
	-- starting from a per-scan rotating offset rather than always ascending.
	-- The mid-scan saturation early-out otherwise consistently starves the
	-- highest-indexed builders within each coset -- highly visible at large
	-- stride where each visit emits a big batch and the cap is hit early.
	-- Rotating the start position spreads the "tail position" evenly across
	-- coset members over successive scans.
	local cosetCount = mathFloor((n - start) / stride) + 1
	local rotation = (cosetCount > 0) and (scanTick % cosetCount) or 0
	tracy.ZoneEnd()
	for k = 0, cosetCount - 1 do
		-- Mid-scan saturation early-out: emissions from earlier builders may push
		-- liveCount over effectiveMax. Bail rather than do per-builder work for
		-- emissions the gate would drop. Skipped builders catch up next tick via
		-- the elapsed-frames-based emit rate.
		if liveCount >= effectiveMax then break end
		local cosetIdx = (k + rotation) % cosetCount
		local i = start + cosetIdx * stride
		do
			local unitID = list[i]
			tracy.ZoneBeginN("G:NanoParticles:RunFrame:ScanBuilders:EmitLoop:BuilderState")
			-- Cheap idle filter: a builder with no current build power is not
			-- emitting (walking, queued, blocked, paused, no orders). Skipping
			-- saves the worker-task lookup, which together with this dominates
			-- per-builder cost when most builders sit idle. bp is cached for a
			-- few frames but ONLY while non-zero -- see BUILD_POWER_CACHE_FRAMES.
			local info = getBuilderInfo(unitID)
			if info then
				local bp
				local bpRefetched = false
				local bpCacheUntil = info.bpCacheUntil
				if bpCacheUntil and frame < bpCacheUntil then
					bp = info.bpCached
				else
					bp = spGetUnitCurrentBuildPower(unitID)
					bpRefetched = true
					if bp and bp > 0 then
						info.bpCached     = bp
						info.bpCacheUntil = frame + BUILD_POWER_CACHE_FRAMES
					else
						info.bpCacheUntil = nil
					end
				end
				if not (bp and bp > 0) then
					-- Resurrectors refilling a wreck's metal before the actual
					-- resurrect step can still be actively working while reporting
					-- zero current build power. GetUnitWorkerTask still exposes the
					-- CMD_RESURRECT feature target, and the feature's resurrect
					-- progress advances in that phase, so treat it as active with a
					-- conservative fallback multiplier instead of dropping emission.
					local fallbackCmdID, fallbackTargetID = spGetUnitWorkerTask(unitID)
					if fallbackCmdID == CMD_RESURRECT and fallbackTargetID then
						local featureID = fallbackTargetID
						if featureID >= MAX_UNITS then
							featureID = featureID - MAX_UNITS
						end
						if spValidFeatureID(featureID) then
							local featureMetal, featureMaxMetal = spGetFeatureResources(featureID)
							local _, _, resurrectProgress = spGetFeatureHealth(featureID)
							local isRefilling = featureMetal and featureMaxMetal and featureMaxMetal > 0 and featureMetal < featureMaxMetal
							local isResurrecting = resurrectProgress and resurrectProgress > 0 and resurrectProgress < 1
							if isRefilling or isResurrecting then
								bp = RESURRECT_REFILL_FALLBACK_BP
								bpRefetched = true
								info.cmdID = fallbackCmdID
								info.targetID = fallbackTargetID
								info.resurrectRefillFallbackActive = isRefilling and true or false
							end
						end
					end
				end
				if not (bp and bp > 0) then
					info.resurrectRefillFallbackActive = nil
					-- Idle visit: clear lastVisitFrame so the next bp>0 visit
					-- doesn't credit the idle gap as build time and dump a burst.
					info.lastVisitFrame = nil
					-- Drop the builder from any reclaim tracking -- it's no longer
					-- contributing, so the burst shouldn't travel to it.
					local prev = info.reclaimTarget
					if prev then
						local prevSet = reclaimedTargets[prev]
						if prevSet then
							prevSet[unitID] = nil
							if next(prevSet) == nil then reclaimedTargets[prev] = nil end
						end
						info.reclaimTarget = nil
					end
				end
				if bp and bp > 0 then
					if DEBUG then _dbgBuilders = _dbgBuilders + 1 end
					-- Lazy nano-piece refresh: the COB/LUS script may not have
					-- registered all nano pieces by the time getBuilderInfo is first
					-- called (lazy, on first active scan). Re-fetch on first activity
					-- (stage 0→1) and once more ~3s later (stage 1→2) to catch
					-- scripts that register pieces inside QueryNanoPiece. Applies to
					-- ALL builders, not just factories -- constructors with multiple
					-- arms can also return a partial list on the first scan.
					local refreshStage = info.piecesRefreshStage or 0
					if refreshStage < 2 then
						local refreshAt = info.piecesRefreshAt
						if refreshStage == 0 or (refreshAt and frame >= refreshAt) then
							local fresh = spGetUnitNanoPieces(unitID)
							if fresh and #fresh > info.nPieces then
								info.pieces  = fresh
								info.nPieces = #fresh
							end
							if refreshStage == 0 then
								info.piecesRefreshStage = 1
								info.piecesRefreshAt    = frame + 90 -- ~3s @ 30Hz
							else
								info.piecesRefreshStage = 2
								info.piecesRefreshAt    = nil
							end
						end
					end
					-- Worker-task lookup. Cached in lockstep with bp -- the
					-- (cmdID, targetID) pair is even more stable during a continuous
					-- build. Mid-build changes are handled out-of-band: UnitFinished
					-- clears info.cmdID/targetID/targetMeta on every dependent builder
					-- (queue advance picked up next visit), and manual order changes
					-- are rare (worst case = BUILD_POWER_CACHE_FRAMES of stale aim).
					local cmdID, targetID = info.cmdID, info.targetID
					if bpRefetched or not cmdID then
						cmdID, targetID = spGetUnitWorkerTask(unitID)
						info.cmdID    = cmdID
						info.targetID = targetID
					end
					if cmdID then
						if DEBUG then _dbgWithTask = _dbgWithTask + 1 end
						local ex, ey, ez, inverse, jitterRadius, isResurrect, targetUnitID
						local meta = info.targetMeta
						local coldOffscreen = false
						if meta and meta.cmdID == cmdID and meta.targetID == targetID and meta.coldOffscreenUntil and frame < meta.coldOffscreenUntil then
							coldOffscreen = true
							inverse = meta.isReclaim and true or false
							isResurrect = meta.isResurrect
							targetUnitID = (not meta.isFeature) and meta.resolvedID or nil
						else
							ex, ey, ez, inverse, jitterRadius, isResurrect, targetUnitID = resolveTarget(info, cmdID, targetID)
							meta = info.targetMeta
						end
						tracy.ZoneEnd()
						tracy.ZoneBeginN("G:NanoParticles:RunFrame:ScanBuilders:EmitLoop:Filter")
						-- Record this builder as actively reclaiming `targetUnitID`
						-- so the UnitDestroyed callin can fire a finishing burst
						-- only from builders that contributed (= teams that got
						-- the metal). Tracked even when this scan's emission gets
						-- throttled away, so the burst still fires off-screen.
						-- If the builder switched targets (or away from reclaim),
						-- drop its membership in the previous target's set so a
						-- later reclaim of that earlier unit doesn't credit a
						-- builder that long-since moved on.
						local nowReclaiming = (targetUnitID and inverse and meta and meta.isReclaim) and targetUnitID or nil
						local prevReclaiming = info.reclaimTarget
						if prevReclaiming ~= nowReclaiming then
							if prevReclaiming then
								local prevSet = reclaimedTargets[prevReclaiming]
								if prevSet then
									prevSet[unitID] = nil
									if next(prevSet) == nil then
										reclaimedTargets[prevReclaiming] = nil
									end
								end
							end
							info.reclaimTarget = nowReclaiming
						end
						if nowReclaiming then
							local set = reclaimedTargets[nowReclaiming]
							if set then
								set[unitID] = true
							else
								reclaimedTargets[nowReclaiming] = { [unitID] = true }
							end
							-- Keep build-progress fresh so UnitDestroyed can scale
							-- the burst even though the unit is already dead then.
							local isBuilt, bp = spGetUnitIsBeingBuilt(nowReclaiming)
							if isBuilt and bp then
								reclaimTargetBuildProgress[nowReclaiming] = bp
							else
								reclaimTargetBuildProgress[nowReclaiming] = nil
							end
						end
						local emits, resurrectEmits = 0, 0
						local feedbackForced = false
						if ex or coldOffscreen then
							-- Factories always use the engine's fixed 0.15 jitter regardless of buildee size.
							if info.isFactory then jitterRadius = nil end
							info.lastVisitFrame = frame
							local elapsed = 1
							local rate = (info.buildSpeed * bp / EMIT_REF_BUILDSPEED) * elapsed * (NanoParticleRate or 1.0)
							local accum = (info.emitAccum or 0) + rate
							emits = mathFloor(accum)
							info.emitAccum = accum - emits
							if emits == 0 and bp > 0 then
								local lastEmit = info.lastEmitFrame or 0
								if frame - lastEmit >= FEEDBACK_EMIT_MIN_GAP then
									emits = 1
									info.emitAccum = info.emitAccum - 1
									feedbackForced = true
								end
							end
							if emits > 0 then
								info.lastEmitFrame = frame
							end
							if isResurrect then
								resurrectEmits = takeScaledEmitCount(info, "resurrectEmitAccum", emits, NanoParticleResurrectExtraRate)
								if info.resurrectRefillFallbackActive and feedbackForced and resurrectEmits < 1 then
									resurrectEmits = 1
								end
							else
								resurrectEmits = emits
							end
						end
						if ex then
							-- Off-screen throttle. Test view-frustum at the target
							-- endpoint (covers the whole spray for a builder near its
							-- target). Cold endpoints skip emitNano entirely; recently
							-- visible endpoints keep the old reduced-rate continuity.
							if offscreenKeep < 1.0 then
								local visible
								local radius = meta and meta.targetRadius or 64
								if radius < 64 then radius = 64 end
								if meta and meta.visFrame and (frame - meta.visFrame) < OFFSCREEN_VIS_CACHE_FRAMES then
									visible = meta.visible
								else
									visible = Spring.IsSphereInView(ex, ey, ez, radius) and true or false
									if meta then
										meta.visFrame = frame
										meta.visible  = visible
									end
								end
								if visible then
									if meta then
										meta.lastVisibleFrame = frame
										meta.coldOffscreenUntil = 0
									end
								else
									local warm = meta and meta.lastVisibleFrame and (frame - meta.lastVisibleFrame) <= (OFFSCREEN_VIS_CACHE_FRAMES * 8)
									if not warm then
										-- Render-frame catch-up watches the cached endpoint for
										-- camera arrivals, so the sim scan can sleep at the
										-- normal frustum-cache cadence while the stream is cold.
										if meta then
													meta.coldOffscreenUntil = frame + (meta.isMobileUnit and OFFSCREEN_VIS_CACHE_FRAMES or OFFSCREEN_COLD_RECHECK_FRAMES)
											meta.virtualX = ex; meta.virtualY = ey; meta.virtualZ = ez
											meta.virtualRadius = radius
										end
										coldOffscreen = true
										ex = nil
									elseif mathRandom() > offscreenKeep then
										ex = nil
									end
								end
							end
							-- Distance throttle. Below near-range we keep all; in the
							-- ramp band we lerp keep-fraction in squared distance
							-- (more aggressive culling at the far end); beyond far-range
							-- we clamp to DISTANT_EMIT_KEEP.
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
						if (not ex) and coldOffscreen and resurrectEmits > 0 and meta then
							local oldVirtualEmits = meta.virtualEmits or 0
							meta.virtualEmits = oldVirtualEmits + resurrectEmits
							if meta.virtualEmits > 32 then meta.virtualEmits = 32 end
							if oldVirtualEmits <= 0 then
								local virtualSet = deathBuckets.__virtualStreamSet
								if not virtualSet then
									virtualSet = {}
									deathBuckets.__virtualStreamSet = virtualSet
								end
								if not virtualSet[unitID] then
									local virtualList = deathBuckets.__virtualStreamList
									if not virtualList then
										virtualList = {}
										deathBuckets.__virtualStreamList = virtualList
									end
									virtualList[#virtualList + 1] = unitID
									virtualSet[unitID] = true
									deathBuckets.__virtualStreamCount = (deathBuckets.__virtualStreamCount or 0) + 1
									deathBuckets.__virtualStreamsNeedCheck = true
								end
							end
							local virtualDelta = ((meta.virtualFrame or 0) > 0) and (frame - meta.virtualFrame) or 1
							if virtualDelta < 1 then virtualDelta = 1 end
							meta.virtualAgeFrames = (meta.virtualAgeFrames or 0) + virtualDelta
							if meta.virtualAgeFrames > (OFFSCREEN_VIS_CACHE_FRAMES * 8) then
								meta.virtualAgeFrames = OFFSCREEN_VIS_CACHE_FRAMES * 8
							end
							meta.virtualFrame = frame
						end
						tracy.ZoneEnd()
						if ex then
							tracy.ZoneBeginN("G:NanoParticles:RunFrame:ScanBuilders:EmitLoop:EmitBatch")
							if DEBUG then _dbgEmits = _dbgEmits + 1 end
							local elapsed = 1
							-- Spread window (half-width in frames) for the in-batch
							-- stagger inside emitNano. Particles end up in
							-- [-spreadWindow, +spreadWindow] frames of velocity
							-- around the nanopiece -- a few slightly behind (model
							-- occlusion) and a few slightly ahead. Hard-capped at
							-- MAX_SPREAD_AHEAD_FRAMES so the cluster stays close to
							-- the source, never partway to the target. Direction
							-- jitter already provides lateral spread -- this just
							-- breaks the on-axis pile-up of a multi-particle batch.
							-- Count compensation still uses full `elapsed`, so total
							-- emission rate is preserved.
							local spreadWindow = math.min(MAX_SPREAD_AHEAD_FRAMES, elapsed)
							local catchupAgeFrames = 0
							if meta and meta.virtualEmits and meta.virtualEmits > 0 then
								resurrectEmits = resurrectEmits + meta.virtualEmits
								catchupAgeFrames = meta.virtualAgeFrames or 0
								meta.virtualEmits = 0
								meta.virtualAgeFrames = 0
								meta.virtualFrame = frame
							end
							if resurrectEmits > 0 then
								emitNanoBatch(unitID, info, ex, ey, ez, inverse, jitterRadius, frame, targetUnitID, isResurrect, resurrectEmits, spreadWindow, catchupAgeFrames)
							end
							tracy.ZoneEnd()
						end
					elseif info.targetMeta then
						tracy.ZoneEnd()
						info.targetMeta = nil  -- builder went idle; drop stale cache
						info.lastVisitFrame = nil  -- prevent burst on resume
						local prev = info.reclaimTarget
						if prev then
							local prevSet = reclaimedTargets[prev]
							if prevSet then
								prevSet[unitID] = nil
								if next(prevSet) == nil then reclaimedTargets[prev] = nil end
							end
							info.reclaimTarget = nil
						end
					else
						tracy.ZoneEnd()
					end
				else
					tracy.ZoneEnd()
				end
			else
				tracy.ZoneEnd()
			end
		end
	end
	tracy.ZoneEnd()
	end -- if not skipEmit

	-- Flush all spawns AND in-place homing rewrites in a single upload. Spawns
	-- are at the tail [preUsed..postUsed); homing rewrites can touch arbitrary
	-- slots. Take the union and upload once.
	if nanoVBO then
		tracy.ZoneBeginN("G:NanoParticles:RunFrame:ScanBuilders:UpdateVBO")
		local dirtyMin, dirtyMax = math.huge, -1
		-- Re-aim runs on a slower cadence than the scan: it rewrites per-particle
		-- pos/vel for every live homed particle (potentially thousands) and only
		-- needs to keep up with target movement.
		if frame >= (deathBuckets.__nextHomingFrame or 0) then
			tracy.ZoneBeginN("G:NanoParticles:RunFrame:ScanBuilders:Homing")
			deathBuckets.__nextHomingFrame = frame + HOMING_RUN_EVERY
			dirtyMin, dirtyMax = applyHoming(frame, dirtyMin, dirtyMax)
			dirtyMin, dirtyMax = applyForwardHoming(frame, dirtyMin, dirtyMax)
			tracy.ZoneEnd()
		end
		tracy.ZoneBeginN("G:NanoParticles:RunFrame:ScanBuilders:GroundClamp")
		dirtyMin, dirtyMax = applyGroundClamp(frame, dirtyMin, dirtyMax)
		tracy.ZoneEnd()
		local postUsed = nanoVBO.usedElements
		if postUsed > preUsed then
			if preUsed  < dirtyMin then dirtyMin = preUsed  end
			if postUsed > dirtyMax then dirtyMax = postUsed end
		end
		if dirtyMax > dirtyMin then
			tracy.ZoneBeginN("G:NanoParticles:RunFrame:ScanBuilders:Upload")
			uploadElementRange(nanoVBO, dirtyMin, dirtyMax)
			tracy.ZoneEnd()
		end
		tracy.ZoneEnd()
	end
	tracy.ZoneEnd()
end

-- Per-frame: cull dead particles. Called from Update after observing a new sim
-- frame; overdue buckets are handled so catch-up skips do not leak slots.
--------------------------------------------------------------------------------

local function cullDead(frame)
	tracy.ZoneBeginN("G:NanoParticles:RunFrame:CullDead")
	local oldest = deathBuckets.__oldestFrame
	if not oldest or oldest > frame then
		tracy.ZoneEnd()
		return
	end
	local nl = deathBuckets.__nanoLight
	local lightActive = nl and nl.activeCount and nl.activeCount > 0 and nl.active
	local canRemove = lightActive and Script.LuaUI("EnvNanoBallisticLightRemove")
	for deathFrame = oldest, frame do
		local bucket = deathBuckets[deathFrame]
		if bucket then
			local nb = #bucket
			if not nanoVBO then
				if lightActive then
					for i = 1, nb do
						local id = bucket[i]
						if lightActive[id] then
							lightActive[id] = nil
							nl.activeCount = nl.activeCount - 1
							if canRemove then
								Script.LuaUI.EnvNanoBallisticLightRemove("NANOP_" .. id)
							end
						end
					end
				end
			else
				-- Per-pop upload (~64B/swap). Tried batching with one uploadElementRange
				-- at the end and cull jumped from ~2-4ms to ~15-18ms in factory-heavy
				-- scenes -- per-element marshalling cost in uploadElementRange dominates
				-- the GL submit savings when slots are scattered.
				for i = 1, nb do
					local id = bucket[i]
					popElementInstance(nanoVBO, id, false)
					if lightActive and lightActive[id] then
						lightActive[id] = nil
						nl.activeCount = nl.activeCount - 1
						if canRemove then
							Script.LuaUI.EnvNanoBallisticLightRemove("NANOP_" .. id)
						end
					end
				end
			end
			liveCount = liveCount - nb
			deathBuckets[deathFrame] = nil
		end
	end
	local latest = deathBuckets.__latestFrame
	if latest and latest > frame then
		oldest = frame + 1
		while oldest <= latest and not deathBuckets[oldest] do
			oldest = oldest + 1
		end
		if oldest <= latest then
			deathBuckets.__oldestFrame = oldest
		else
			deathBuckets.__oldestFrame = nil
			deathBuckets.__latestFrame = nil
		end
	else
		deathBuckets.__oldestFrame = nil
		deathBuckets.__latestFrame = nil
	end
	tracy.ZoneEnd()
end

--------------------------------------------------------------------------------
-- Callins
--------------------------------------------------------------------------------

-- Switch to a new NanoParticleMode (0 engine / 1 shapes).
-- Tears down GL resources when leaving 1, rebuilds them when entering 1,
-- and keeps the engine's MaxNanoParticles budget in sync so we never
-- double-spray.
local function applyParticleMode(newMode, force)
	if (not force) and newMode == NANO_PARTICLE_MODE and nanoVBO ~= nil then return end
	if (not force) and newMode == NANO_PARTICLE_MODE and newMode == 0 then return end
	local nl = deathBuckets.__nanoLight
	if nl and nl.active then
		local canRemove = Script.LuaUI("EnvNanoBallisticLightRemove")
		for pid in pairs(nl.active) do
			if canRemove then
				Script.LuaUI.EnvNanoBallisticLightRemove("NANOP_" .. pid)
			end
			nl.active[pid] = nil
		end
		nl.activeCount = 0
	end

	NANO_PARTICLE_MODE = newMode

	-- Clear all in-flight homing references; their VBO slots are about to be
	-- destroyed (or we're entering mode 0 where they're meaningless).
	for k, list in pairs(homingByBuilder)     do U.recycleTrackList(list); homingByBuilder[k]     = nil end
	for k, list in pairs(homingFwdByTarget)   do U.recycleTrackList(list); homingFwdByTarget[k]   = nil end
	for k, list in pairs(fadeFwdByTarget)     do U.recycleTrackList(list); fadeFwdByTarget[k]     = nil end
	for k in pairs(targetPosCache)      do targetPosCache[k]      = nil end
	for k in pairs(targetIncompleteCache) do targetIncompleteCache[k] = nil end
	for k in pairs(reclaimTargetBuildProgress) do reclaimTargetBuildProgress[k] = nil end
	for k in pairs(deathBuckets) do
		if type(k) == "number" or k == "__nanoLight" or k == "__oldestFrame" or k == "__latestFrame" then
			deathBuckets[k] = nil
		end
	end
	liveCount = 0

	cleanupGL4()

	if newMode == 0 then
		-- Hand the spray budget back to the engine.
		Spring.SetConfigInt("MaxNanoParticles", math.floor(Spring.GetConfigInt("MaxParticles", 15000) * 0.34))
		return
	end

	-- Mode 1: silence the engine spray, swap to the shape shader pair.
	Spring.SetConfigInt("MaxNanoParticles", 0)
	applyRenderMode("shape")
	if not initGL4() then
		spEcho("Nano Particles GL4: GL init failed; falling back to engine spray.")
		NANO_PARTICLE_MODE = 0
		Spring.SetConfigInt("MaxNanoParticles", math.floor(Spring.GetConfigInt("MaxParticles", 15000) * 0.34))
	end
end

function gadget:Initialize()
	-- The gadget always stays loaded so it can observe live NanoParticleMode
	-- changes from the gfx options menu. Mode 0 = engine spray: we just leave
	-- nanoVBO unset and skip emission/draw; switching to 1 lazy-inits GL.
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
	local nl = deathBuckets.__nanoLight
	if nl and nl.active then
		local canRemove = Script.LuaUI("EnvNanoBallisticLightRemove")
		for pid in pairs(nl.active) do
			if canRemove then
				Script.LuaUI.EnvNanoBallisticLightRemove("NANOP_" .. pid)
			end
			nl.active[pid] = nil
		end
		nl.activeCount = 0
	end
	cleanupGL4()
end

function gadget:PlayerChanged()
	refreshSpec()
	-- Player-state transitions can change visible team colors (e.g. take/give,
	-- spec view of recolored teams). Refresh now so the next frame paints right.
	refreshTeamColors()
end

local function runNanoFrame(n)
	tracy.ZoneBeginN("G:NanoParticles:RunFrame")
	if DEBUG then
		local t0 = Spring.GetTimer()
		scanBuilders(n)
		_dbgTScan = _dbgTScan + Spring.DiffTimers(Spring.GetTimer(), t0)

		local tc0 = Spring.GetTimer()
		cullDead(n)
		_dbgTCull = _dbgTCull + Spring.DiffTimers(Spring.GetTimer(), tc0)

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
	tracy.ZoneEnd()
end

-- Emission once per observed sim frame (matches the engine's per-frame
-- AddNanoParticle cadence for an active builder). Update only observes the
-- simframe; heavy scan/cull work is delayed to a later DrawWorld when a spare
-- draw frame exists. If simframes arrive faster than drawframes, we catch up in
-- Update before queueing the newer frame.
function gadget:Update()
	local n = Spring.GetGameFrame()
	if n <= (deathBuckets.__lastNanoUpdateFrame or -1) then return end
	deathBuckets.__lastNanoUpdateFrame = n

	-- Poll NanoParticleMode. The springsetting is written by the gfx options
	-- UI; engine doesn't fire a callin on change so we sample on a slow tick.
	-- Cheap (one GetConfigInt) and 1s latency on a settings-menu toggle is
	-- imperceptible.
	if n >= (deathBuckets.__nextNanoSettingsPollFrame or 0) then
		deathBuckets.__nextNanoSettingsPollFrame = n + 30
		-- Optional deferred nano lights (off by default):
		--  NanoParticleLights = 0/1 enables bridge to deferred lights widget.
		local nl = deathBuckets.__nanoLight
		if not nl then
			nl = {activeCount = 0, active = {} }
			deathBuckets.__nanoLight = nl
		end
		nl.enabled = (Spring.GetConfigInt("NanoParticleLights", 1) == 1)
		if nl.enabled then
			nl.spawnRadius = 33
			nl.alpha = 0.05
			nl.sampleRate = 0.25
			nl.maxSpawnsPerFrame = 48
			nl.maxActive = 2048
			nl.correctEvery = 5
			nl.lifeMult = 2.2
			nl.minLifetime = 14
			nl.maxLifetime = 96
			nl.sustainFrac = 0.7
			nl.bridgeReady = Script.LuaUI("EnvNanoBallisticLightSpawn")
				and Script.LuaUI("EnvNanoBallisticLightCorrect")
				and Script.LuaUI("EnvNanoBallisticLightRemove")
			nl.fadeReady = Script.LuaUI("EnvNanoBallisticLightFade")
		else
			if nl.activeCount > 0 then
				local canRemove = Script.LuaUI("EnvNanoBallisticLightRemove")
				for pid in pairs(nl.active) do
					if canRemove then
						Script.LuaUI.EnvNanoBallisticLightRemove("NANOP_" .. pid)
					end
					nl.active[pid] = nil
				end
				nl.activeCount = 0
			end
			nl.bridgeReady = false
			nl.fadeReady = false
		end

		local mode = Spring.GetConfigInt("NanoParticleMode", 1)
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
		-- Refresh high-gamespeed throttle (reconnect catchup, user /speed).
		-- Map-draw-mode is also refreshed in DrawWorld for immediate overlay
		-- transitions.
		refreshSpeedThrottle()
		refreshInfoIsLos()
		refreshMaxParticles()
		-- Color equalization slider: cheap poll; if changed, force a full
		-- team-color refresh now so the new value takes effect within ~1s.
		if refreshColorEqualize() then
			refreshTeamColors()
		end
		-- Global particle amount multiplier: clamp into [0..4] in case it was
		-- set out of range from a console / widget. No cache invalidation
		-- needed -- the value is read directly each visit when computing emit
		-- rate.
		do
			local a = NanoParticleRate or 1.0
			if type(a) ~= "number" then a = 1.0 end
			if a < 0.0 then a = 0.0 end
			if a > 1.0 then a = 1.0 end
			NanoParticleRate = a
		end
	end

	-- Mode 0 = engine renders the spray; we just track builders for a quick
	-- restart if the user switches back to gadget mode.
	if NANO_PARTICLE_MODE == 0 then
		deathBuckets.__pendingNanoFrame = nil
		return
	end

	-- Periodic team-color refresh: colors can change mid-game (commshare,
	-- alliance, custom recolor widgets). Cheap (one Spring call per cached
	-- team, only propagates on actual change).
	if n >= (deathBuckets.__nextTeamColorRefreshFrame or 0) then
		deathBuckets.__nextTeamColorRefreshFrame = n + 150
		refreshTeamColors()
	end

	-- Periodic full rescan as a safety net for callins that don't fire in
	-- unsynced context (e.g. mid-game gadget reloads, spectator transitions).
	-- Unit{Created,Finished,Given,Taken,Destroyed} cover the steady state, so
	-- every 10 seconds is plenty for the safety net.
	if n >= (deathBuckets.__nextBuilderRescanFrame or 0) then
		deathBuckets.__nextBuilderRescanFrame = n + 300
		if DEBUG then
			local t0 = Spring.GetTimer()
			local all = spGetAllUnits()
			if all then
				for i = 1, #all do
					local uid = all[i]
					if not trackedBuilders[uid] then
						trackUnit(uid)
					end
				end
			end
			_dbgTRescan = _dbgTRescan + Spring.DiffTimers(Spring.GetTimer(), t0)
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

	do
		local pendingFrame = deathBuckets.__pendingNanoFrame
		if pendingFrame and pendingFrame < n then
			-- No spare draw frame arrived before the next simframe. Catch up here;
			-- this is the low-FPS/catchup case where deferring is not achievable.
			deathBuckets.__pendingNanoFrame = nil
			runNanoFrame(pendingFrame)
		end
		deathBuckets.__pendingNanoFrame = n
		deathBuckets.__pendingNanoDrawFrame = deathBuckets.__nanoDrawFrame or 0
	end

	if CLAMP_DEBUG and n >= (deathBuckets.__nextClampDebugFrame or 0) then
		deathBuckets.__nextClampDebugFrame = n + 90
		local checks = clampDbg.emitChecks
		local enabledPct = (checks > 0) and (100.0 * clampDbg.emitEnabled / checks) or 0.0
		spEcho(string.format(
			"[NanoGL4 ClampDbg] f=%d checks=%d enabled=%d(%.1f%%) reg=%d subsetNow=%d subsetMax=%d proc=%d corr=%d drop=%d",
			n,
			checks,
			clampDbg.emitEnabled,
			enabledPct,
			clampDbg.registered,
			#groundClampParticles,
			clampDbg.maxSubset,
			clampDbg.processed,
			clampDbg.corrected,
			clampDbg.dropped
		))
		clampDbg.emitChecks = 0
		clampDbg.emitEnabled = 0
		clampDbg.registered = 0
		clampDbg.processed = 0
		clampDbg.corrected = 0
		clampDbg.dropped = 0
		clampDbg.maxSubset = 0
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
	-- Construction completed: fade trailing build-spray particles instead of
	-- letting them coast into the now-finished unit and pop on natural death.
	fadeOutHomingFwd(unitID)
	U.recycleTrackList(homingFwdByTarget[unitID])
	U.recycleTrackList(fadeFwdByTarget[unitID])
	homingFwdByTarget[unitID] = nil
	fadeFwdByTarget[unitID]   = nil
	targetPosCache[unitID]    = nil
	local completionFactoryID, completionX, completionY, completionZ, completionRadius
	-- Keep a completion timestamp so HOMING_SKIP_GRACE_FRAMES still applies
	-- after UnitFinished; clearing this here made fresh emissions immediately
	-- re-enter forward homing and chase units as they roll out of factories.
	targetIncompleteCache[unitID] = { piecePosEpoch, false, Spring.GetGameFrame() }
	-- Invalidate cached target state on any builder that was working on this
	-- just-completed unit. info.targetMeta caches frustum visibility and the
	-- resolved engine ID across visits keyed by targetID; the worker-task
	-- itself is no longer cached so cmdID/targetID will refresh next visit.
	local n = #trackedBuildersList
	for i = 1, n do
		local bid = trackedBuildersList[i]
		local info = builderCache[bid]
		if info and info.targetID == unitID then
			if info.isFactory and not completionFactoryID then
				local _, _, _, mx, my, mz = spGetUnitPosition(bid, true)
				if mx then
					completionFactoryID = bid
					completionX, completionY, completionZ = mx, my, mz
					completionRadius = spGetUnitRadius(bid) or 0
				end
			end
			info.cmdID      = nil
			info.targetID   = nil
			info.targetMeta = nil
		end
	end
	if completionFactoryID then
		local frame = Spring.GetGameFrame()
		recentFactoryBuildTargetCache[unitID] = {
			frame,
			completionFactoryID,
			completionX,
			completionY,
			completionZ,
			completionRadius,
		}
		factoryBuildTargetCache[unitID] = { piecePosEpoch, completionFactoryID, completionX, completionY, completionZ, completionRadius }
	end
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

-- Fade out inverse-homing (reclaim) particles travelling toward a builder that
-- just died. Mirrors fadeOutHomingFwd: shorten deathFrame and bake in a fade
-- window so the particles dissolve rather than snapping out. The builder is
-- already dead so applyHoming will nil the list on the next pass; we only need
-- to touch the VBO data here.
local function fadeOutHomingInverse(builderID)
	if not nanoVBO then return end
	local list = homingByBuilder[builderID]
	if not list then return end
	local data      = nanoVBO.instanceData
	local idtoIndex = nanoVBO.instanceIDtoIndex
	local step      = nanoVBO.instanceStep
	local frame     = Spring.GetGameFrame()
	local dirtyMin, dirtyMax = math.huge, -1
	for i = 1, #list do
		local p = list[i]
		local slot = idtoIndex[p.id]
		if slot then
			local remaining = p.death - frame
			if remaining > 0 then
				local fadeFrames = mathFloor(FADE_FRAMES_DEATH * (0.4 + mathRandom()))
				if fadeFrames < 1 then fadeFrames = 1 end
				if fadeFrames > remaining then fadeFrames = remaining end
				local newDeath = frame + fadeFrames
				local base = (slot - 1) * step
				data[base+16] = newDeath
				local packed    = data[base+4]
				local absPacked = packed < 0 and -packed or packed
				local oldFade   = mathFloor(absPacked / 1024)
				local sizeBits  = absPacked - oldFade * 1024
				local newPacked = sizeBits + fadeFrames * 1024
				data[base+4]    = packed < 0 and -newPacked or newPacked
				local s0 = slot - 1
				if s0 < dirtyMin     then dirtyMin = s0     end
				if s0 + 1 > dirtyMax then dirtyMax = s0 + 1 end
				fadeNanoDeferredLight(p.id, frame, fadeFrames)
			end
		end
	end
	if dirtyMax > dirtyMin then
		uploadElementRange(nanoVBO, dirtyMin, dirtyMax)
	end
end

-- Fade out forward-homing particles aimed at a unit that just died: shorten
-- their deathFrame so the shader's end-of-life alpha ramp kicks in. Velocity
-- and spawn are left untouched so they keep coasting along their last
-- trajectory while fading out. Slot reclamation still happens at the original
-- death frame (deathBuckets is untouched); the shader renders nothing in the gap.
fadeOutHomingFwd = function(unitID, includeSkipList)
	if not nanoVBO then return end
	local list  = homingFwdByTarget[unitID]
	local flist = includeSkipList and fadeFwdByTarget[unitID] or nil
	if not list and not flist then return end
	local data      = nanoVBO.instanceData
	local idtoIndex = nanoVBO.instanceIDtoIndex
	local step      = nanoVBO.instanceStep
	local frame     = Spring.GetGameFrame()
	-- Per-particle fade duration: FADE_FRAMES_DEATH * (0.4..1.6). Staggers the
	-- dissolve so particles don't all wink out on the same frame.
	local dirtyMin, dirtyMax = math.huge, -1
	local function fadeList(plist)
		if not plist then return end
		for i = 1, #plist do
			local p = plist[i]
			local slot = idtoIndex[p.id]
			if slot then
				local remaining = p.death - frame
				if remaining > 0 then
					local fadeFrames = mathFloor(FADE_FRAMES_DEATH * (0.4 + mathRandom()))
					if fadeFrames < 1 then fadeFrames = 1 end
					-- Clamp to remaining lifetime: never extend a particle's life,
					-- only shorten/replace it.
					if fadeFrames > remaining then fadeFrames = remaining end
					local newDeath = frame + fadeFrames
					local base = (slot - 1) * step
					data[base+16] = newDeath
					-- Force per-particle fade window so reclaim-style (fadeFrames=0)
					-- particles also dissolve. w is packed: preserve sizeMult bits,
					-- replace only the fadeFrames portion.
					-- NOTE: inverse (reclaim) particles store a negative value; use
					-- abs before bit-manipulation and restore the sign afterward.
					local packed   = data[base+4]
					local absPacked = packed < 0 and -packed or packed
					local oldFade  = mathFloor(absPacked / 1024)
					local sizeBits = absPacked - oldFade * 1024
					local newPacked = sizeBits + fadeFrames * 1024
					data[base+4]   = packed < 0 and -newPacked or newPacked
					local s0 = slot - 1
					if s0 < dirtyMin     then dirtyMin = s0     end
					if s0 + 1 > dirtyMax then dirtyMax = s0 + 1 end
					fadeNanoDeferredLight(p.id, frame, fadeFrames)
				end
			end
		end
	end
	fadeList(list)
	fadeList(flist)
	if dirtyMax > dirtyMin then
		uploadElementRange(nanoVBO, dirtyMin, dirtyMax)
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	-- Reclaim-completion burst: in unsynced UnitDestroyed, when a unit is
	-- removed by reclaim the engine populates attacker* with the reclaiming
	-- builder (it's the agent that "killed" the unit, with no weaponDefID).
	-- Combined with our own per-builder tracker (which holds ALL contributing
	-- reclaimers, not just the one that landed the final tick), this is the
	-- trigger: attackerID present + no weapon + we tracked reclaimers => fire
	-- the burst, then distribute particles across every tracked contributor.
	if attackerID and (not weaponDefID or weaponDefID < 0) and reclaimedTargets[unitID] then
		-- Read cached build progress (set by the scan loop while the unit was alive).
		-- spGetUnitIsBeingBuilt returns nil for dead units in unsynced context.
		local bp = reclaimTargetBuildProgress[unitID] or 1.0
		reclaimTargetBuildProgress[unitID] = nil
		fireReclaimBurst(unitID, unitDefID, attackerTeam, bp, Spring.GetGameFrame())
	else
		reclaimedTargets[unitID] = nil
		reclaimTargetBuildProgress[unitID] = nil
	end
	fadeOutHomingFwd(unitID, true)
	fadeOutHomingInverse(unitID)
	U.recycleTrackList(homingByBuilder[unitID])
	U.recycleTrackList(homingFwdByTarget[unitID])
	U.recycleTrackList(fadeFwdByTarget[unitID])
	clearPiecePosCache(unitID)
	builderCache[unitID] = nil
	homingByBuilder[unitID] = nil
	homingFwdByTarget[unitID] = nil
	fadeFwdByTarget[unitID]   = nil
	targetPosCache[unitID]    = nil
	targetIncompleteCache[unitID] = nil
	untrackUnit(unitID)
end
function gadget:RenderUnitDestroyed(unitID)
	-- RenderUnitDestroyed has no attacker arg; rely on whatever UnitDestroyed
	-- already decided. If the burst ran (or skipped), the entry is gone.
	reclaimedTargets[unitID] = nil
	reclaimTargetBuildProgress[unitID] = nil
	fadeOutHomingFwd(unitID, true)
	fadeOutHomingInverse(unitID)
	U.recycleTrackList(homingByBuilder[unitID])
	U.recycleTrackList(homingFwdByTarget[unitID])
	U.recycleTrackList(fadeFwdByTarget[unitID])
	clearPiecePosCache(unitID)
	builderCache[unitID] = nil
	homingByBuilder[unitID] = nil
	homingFwdByTarget[unitID] = nil
	fadeFwdByTarget[unitID]   = nil
	targetPosCache[unitID]    = nil
	targetIncompleteCache[unitID] = nil
	untrackUnit(unitID)
end

function gadget:DrawWorld()
	tracy.ZoneBeginN("G:NanoParticles:DrawWorld")
	deathBuckets.__nanoDrawFrame = (deathBuckets.__nanoDrawFrame or 0) + 1
	do
		local pendingFrame = deathBuckets.__pendingNanoFrame
		if pendingFrame then
			tracy.ZoneBeginN("G:NanoParticles:DrawWorld:PendingFrame")
			local queuedAt = deathBuckets.__pendingNanoDrawFrame or 0
			if deathBuckets.__nanoDrawFrame > queuedAt + 1 then
				deathBuckets.__pendingNanoFrame = nil
				runNanoFrame(pendingFrame)
			end
			tracy.ZoneEnd()
		end
	end
	tracy.ZoneBeginN("G:NanoParticles:DrawWorld:MaterializeVirtual")
	materializeVisibleVirtualStreams(Spring.GetGameFrame())
	tracy.ZoneEnd()
	if not nanoVBO or nanoVBO.usedElements == 0 then
		tracy.ZoneEnd()
		return
	end

	local t0
	if DEBUG then t0 = Spring.GetTimer() end

	-- Defensive GL state setup. DrawWorld is a shared pass -- other widgets/
	-- gadgets (placement preview, ghost overlays, range rings, command UI) can
	-- leak alpha test, polygon mode, vertex color or depth func and silently
	-- kill our pass. Force every state bit our shader relies on.
	-- (Inlined gl.* calls instead of upvalue locals -- file is at the 200
	-- local-variable limit.)
	--
	-- Symptom we are guarding against: while a player is positioning a
	-- building, nano particles can briefly vanish on Twitch streams. Root
	-- causes seen / suspected:
	--   * ColorMask left with one or more channels disabled by a prior pass
	--     (post-processing, screenshot helpers, minimap stencils).
	--   * Scissor left enabled with a tiny rect (UI clipping leak).
	--   * PolygonOffset left enabled, shifting our particle depth so the
	--     placement-ghost depth values reject every fragment.
	--   * AlphaTest left enabled with a func that rejects our 20/255 alpha.
	--   * StencilTest already enabled with a stale func that rejects
	--     everywhere before we re-program it.
	-- All cheap to enforce per-frame; cost is dwarfed by the VBO draw.
	tracy.ZoneBeginN("G:NanoParticles:DrawWorld:GLState")
	gl.DepthTest(GL.LEQUAL)
	gl.DepthMask(false)
	gl.Culling(false)
	gl.AlphaTest(false)
	gl.Color(1, 1, 1, 1)
	gl.ColorMask(true, true, true, true)
	gl.Scissor(false)
	gl.PolygonOffset(false)
	gl.PolygonMode(GL.FRONT_AND_BACK, GL.FILL)
	-- Disable stencil first so the func/mask/op programming below cannot be
	-- short-circuited by a leftover test that rejects every fragment before
	-- we re-enable with the right state.
	gl.StencilTest(false)
	-- Engine premultiplied-alpha pass: BlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA).
	gl.Blending(GL_ONE, GL_ONE_MINUS_SRC_ALPHA)
	tracy.ZoneEnd()

	-- Shape shader has no nanoTex sampler -- skip the bind entirely.
	tracy.ZoneBeginN("G:NanoParticles:DrawWorld:ShaderSetup")
	gl.Texture(1, "$info")
	nanoShader:Activate()
	-- Keep map-draw-mode state fresh per render frame so toggling metal/height/
	-- path overlays does not spend up to 1s using stale LOS sampling state.
	refreshInfoIsLos()
	-- losAlwaysVisible: bypass the LOS/infoTex sample either with full view
	-- (spectator) or when $info isn't currently rendering LOS (heightmap /
	-- metalmap / pathmap modes hold other map data).
	local losU = (cachedSpecFullView or not cachedInfoIsLos) and 1 or 0
	if losU ~= lastLosUniform then
		nanoShader:SetUniform("losAlwaysVisible", losU)
		lastLosUniform = losU
	end
	tracy.ZoneEnd()

	-- Two-pass stencil-aware draw so particles overlapping a ghost shape
	-- (drawn earlier by gfx_DrawUnitShape_GL4.lua, which marks bit 0x40)
	-- shine through the ghost's depth values, while particles outside ghost
	-- areas keep regular depth-tested behavior so they're correctly hidden
	-- by world geometry / units / cliffs / etc.
	--   Pass 1 (stencil bit clear): normal LEQUAL depth test.
	--   Pass 2 (stencil bit set):   depth test off, draw on top of ghost.
	-- Bit value must match GHOST_STENCIL_BIT in gfx_DrawUnitShape_GL4.lua.
	local GHOST_STENCIL_BIT = 0x40
	tracy.ZoneBeginN("G:NanoParticles:DrawWorld:StencilSetup")
	gl.StencilTest(true)
	gl.StencilMask(0)                                                    -- never write stencil
	gl.StencilOp(GL.KEEP, GL.KEEP, GL.KEEP)
	tracy.ZoneEnd()
	-- Pass 1.
	tracy.ZoneBeginN("G:NanoParticles:DrawWorld:DrawNormal")
	gl.StencilFunc(GL.NOTEQUAL, GHOST_STENCIL_BIT, GHOST_STENCIL_BIT)
	nanoVBO:Draw()
	tracy.ZoneEnd()
	-- Pass 2.
	tracy.ZoneBeginN("G:NanoParticles:DrawWorld:DrawGhost")
	gl.StencilFunc(GL.EQUAL, GHOST_STENCIL_BIT, GHOST_STENCIL_BIT)
	gl.DepthTest(false)
	nanoVBO:Draw()
	tracy.ZoneEnd()
	-- Restore.
	tracy.ZoneBeginN("G:NanoParticles:DrawWorld:Restore")
	gl.DepthTest(GL.LEQUAL)
	gl.StencilFunc(GL.ALWAYS, 0, 0xFF)
	gl.StencilMask(0xFF)
	gl.StencilTest(false)

	nanoShader:Deactivate()
	gl.Texture(1, false)

	gl.Blending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	gl.DepthMask(true)
	tracy.ZoneEnd()

	if DEBUG then
		_dbgTDraw = _dbgTDraw + Spring.DiffTimers(Spring.GetTimer(), t0)
		_dbgDraws = _dbgDraws + 1
	end
	tracy.ZoneEnd()
end
