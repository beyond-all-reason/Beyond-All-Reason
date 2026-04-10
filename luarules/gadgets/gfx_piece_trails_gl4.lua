--------------------------------------------------------------------------------
-- Piece Trail Particles GL4
-- Smoke and fire trails for piece projectile debris.
-- Uses GG.Particles API from the core particle engine.
--------------------------------------------------------------------------------

if gadgetHandler:IsSyncedCode() then return end

function gadget:GetInfo()
	return {
		name = "Piece Trail Particles GL4",
		desc = "Smoke/fire trails for piece projectiles via Particle Engine",
		author = "Floris",
		date = "April 2026",
		license = "GNU GPL v2",
		layer = 1,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- Localized functions
--------------------------------------------------------------------------------
local spEcho                      = Spring.Echo
local spGetProjectilesInRectangle = Spring.GetProjectilesInRectangle
local spGetProjectilePosition     = Spring.GetProjectilePosition
local spGetProjectileVelocity     = Spring.GetProjectileVelocity
local spGetProjectileOwnerID      = Spring.GetProjectileOwnerID
local spGetProjectileTeamID       = Spring.GetProjectileTeamID
local spGetTeamAllyTeamID         = Spring.GetTeamAllyTeamID
local spIsSphereInView            = Spring.IsSphereInView
local spGetGroundHeight           = Spring.GetGroundHeight
local spIsPosInAirLos             = Spring.IsPosInAirLos
local spGetMyAllyTeamID           = Spring.GetLocalAllyTeamID
local spGetSpectatingState        = Spring.GetSpectatingState

local mathRandom = math.random
local mathMin    = math.min
local mathMax    = math.max
local mathFloor  = math.floor
local mathCeil   = math.ceil
local mathSqrt   = math.sqrt

local mapSizeX = Game.mapSizeX
local mapSizeZ = Game.mapSizeZ

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------
local PIECE_SPAWN_COUNT_MAX    = 3
local PIECE_SPAWN_TAPER        = 2
local PIECE_SKIP_CHANCE        = 0.4
local PIECE_VEL_SCALE          = 6.0
local PIECE_LIFETIME_MIN       = 35
local PIECE_LIFETIME_MAX       = 85
local PIECE_SIZE_SCALE_MIN     = 0.18
local PIECE_SIZE_SCALE_MAX     = 0.5
local PIECE_SIZE_SCALE_REF     = 25.0
local PIECE_LIFE_BASE          = 200
local PIECE_LIFE_PER_RADIUS    = 1.5
local PIECE_ALPHA_FADE         = 0.66
local PIECE_ALPHA_MIN          = 0.25
local PIECE_GROUND_SKIP_HEIGHT = 5
local PIECE_FIRE_CHANCE        = 0.3

-- Distance LOD for piece trails
local LOD_DIST_NEAR            = 4000
local LOD_DIST_FAR             = 10000
local LOD_MIN_MULT             = 0.33
local LOD_DIST_RANGE_INV       = 1.0 / (LOD_DIST_FAR - LOD_DIST_NEAR)
local LOD_MULT_RANGE           = 1.0 - LOD_MIN_MULT
local LOD_DIST_NEAR_SQ         = LOD_DIST_NEAR * LOD_DIST_NEAR

-- Replay quality: preset index for off-screen buffer replay (1=Low, 0=use current)
local REPLAY_PIECE_PRESET      = 1

-- Pre-computed
local PIECE_VEL_COMBINED       = PIECE_VEL_SCALE * 0.05
local PIECE_ALPHA_RANGE        = 1.0 - PIECE_ALPHA_MIN
local PIECE_LIFETIME_RANGE     = PIECE_LIFETIME_MAX - PIECE_LIFETIME_MIN

--------------------------------------------------------------------------------
-- Particle engine API (localized at init for performance)
--------------------------------------------------------------------------------
local api                  -- GG.Particles reference
local spawnParticle        -- api.spawnParticle
local setBudget            -- api.setBudget
local bufferOffscreen      -- api.bufferOffscreen
local replayBuffer         -- api.replayBuffer

-- Shared physics constants (localized from core at init)
local SMOKE_VEL_UP_MIN
local SMOKE_VEL_UP_RANGE
local SMOKE_VEL_RANDOM
local SMOKE_VEL_RANDOM_2
local PARTICLE_SIZE_MIN
local PARTICLE_SIZE_RANGE
local PARTICLE_SIZE_INV_RANGE
local FIRE_LIFETIME_MIN
local FIRE_LIFETIME_RANGE
local FIRE_SIZE_MULT
local FIRE_ALPHA_MIN
local CULLING_MARGIN
local PIECE_CULLING_RADIUS
local PRIORITY_NORMAL

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------
local trackedPieceProjectiles = {}
local pendingDeathUnitRadii = {}
local excludedDeathUnits = {}
local pieceGeneration = 0
local pieceFlushHandle = nil

-- Cache of unit death effect sizes
local unitDeathSizeCache = {}

--------------------------------------------------------------------------------
-- Build unit death size cache
--------------------------------------------------------------------------------
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
-- Replay buffered off-screen piece frames retroactively
-- Called by the engine's buffer management (replayBuffer / autoFlush).
-- buf: array of {frame, px, py, pz, vx, vy, vz} entries
--------------------------------------------------------------------------------
local function replayPieceEntries(tracked, gameFrame, buf)
	local preset = REPLAY_PIECE_PRESET > 0 and api.getPreset(REPLAY_PIECE_PRESET) or api.getPreset()
	local sc = tracked.sizeScale
	local fi = tracked.fireIntensity
	local presetLifeMult = preset.lifetimeMult
	local smokeSizeSc = sc * (fi > 0 and 1.0 or 0.75)
	setBudget(PRIORITY_NORMAL)

	-- Only replay recent entries that could still produce alive particles
	local maxReplayAge = mathCeil(PIECE_LIFETIME_MAX * 2 * presetLifeMult) + 2
	local startIdx = #buf
	for i = #buf, 1, -1 do
		if gameFrame - buf[i][1] > maxReplayAge then break end
		startIdx = i
	end

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
					bpx + mathRandom() - 0.5, bpy + mathRandom(), bpz + mathRandom() - 0.5,
					vxs + (mathRandom() * SMOKE_VEL_RANDOM_2 - SMOKE_VEL_RANDOM),
					vys + mathRandom() * SMOKE_VEL_UP_RANGE + SMOKE_VEL_UP_MIN,
					vzs + (mathRandom() * SMOKE_VEL_RANDOM_2 - SMOKE_VEL_RANDOM),
					particleSize, 0,
					(PIECE_LIFETIME_MIN + (tracked.lifeBias + mathRandom() * 0.3) * PIECE_LIFETIME_RANGE) * (1.0 + sizeRand * PARTICLE_SIZE_INV_RANGE) * smokeLifeBase,
					(PIECE_ALPHA_MIN + mathRandom() * PIECE_ALPHA_RANGE) * smokeAlphaBase,
					nil, frame
				)
			end
		end

		if fi > 0 then
			local sizeRand = mathRandom() * PARTICLE_SIZE_RANGE
			local particleSize = (PARTICLE_SIZE_MIN + sizeRand) * sc * FIRE_SIZE_MULT * fi
			spawnParticle(
				bpx + mathRandom() * 0.6 - 0.3, bpy + mathRandom() * 0.5, bpz + mathRandom() * 0.6 - 0.3,
				vxs + (mathRandom() * SMOKE_VEL_RANDOM_2 - SMOKE_VEL_RANDOM),
				vys + mathRandom() * SMOKE_VEL_UP_RANGE + SMOKE_VEL_UP_MIN,
				vzs + (mathRandom() * SMOKE_VEL_RANDOM_2 - SMOKE_VEL_RANDOM),
				particleSize, 1,
				(FIRE_LIFETIME_MIN + mathRandom() * FIRE_LIFETIME_RANGE) * presetLifeMult * fi,
				(FIRE_ALPHA_MIN + mathRandom() * 0.2) * (0.5 + 0.5 * fi),
				nil, frame
			)
		end
	end
end

--------------------------------------------------------------------------------
-- Spawn piece trail particles for one projectile
--------------------------------------------------------------------------------
-- Per-frame cached state from update callback
local framePreset
local frameCamX, frameCamY, frameCamZ = 0, 0, 0
local frameAllyTeamID = -1
local frameFullView = true

-- Debug counters
local debugPieceSpawnCount = 0
local debugPieceCallCount = 0
local debugPieceSkipAboveGround = 0
local debugPieceSkipOffscreen = 0
local debugPieceSkipExpired = 0
local debugPieceSkipNoPos = 0

local function spawnPieceTrailParticles(tracked, proID, gameFrame)
	local pieceAge = gameFrame - tracked.birthFrame
	if pieceAge > tracked.lifeFrames then debugPieceSkipExpired = debugPieceSkipExpired + 1 return end

	local px, py, pz = spGetProjectilePosition(proID)
	if not px then debugPieceSkipNoPos = debugPieceSkipNoPos + 1 return end

	local aboveGround = py > PIECE_GROUND_SKIP_HEIGHT
	if not aboveGround then
		local groundY = spGetGroundHeight(px, pz) or 0
		aboveGround = py > groundY + 1
	end
	if not aboveGround then debugPieceSkipAboveGround = debugPieceSkipAboveGround + 1 return end

	-- LOS check: own allyteam pieces always visible, enemy ones need LOS
	if not frameFullView and tracked.allyTeamID ~= frameAllyTeamID and not spIsPosInAirLos(px, py, pz, frameAllyTeamID) then return end

	local inView = spIsSphereInView(px, py, pz, PIECE_CULLING_RADIUS)
	if not inView then
		debugPieceSkipOffscreen = debugPieceSkipOffscreen + 1
		local pvx, pvy, pvz = spGetProjectileVelocity(proID)
		bufferOffscreen(tracked, gameFrame, px, py, pz, pvx or 0, pvy or 0, pvz or 0, 3)
		return
	end

	debugPieceCallCount = debugPieceCallCount + 1

	-- Transition to in-view: replay buffered particles
	replayBuffer(tracked, gameFrame, replayPieceEntries)

	local dx, dy, dz = px - frameCamX, py - frameCamY, pz - frameCamZ
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

	local presetLifeMult = framePreset.lifetimeMult * lodMult
	local spawnCount = mathMax(1, mathFloor((PIECE_SPAWN_COUNT_MAX - ageFrac * PIECE_SPAWN_TAPER + 0.5) * framePreset.spawnMult * framePreset.pieceCountMult * lodMult))
	local skipChance = PIECE_SKIP_CHANCE + (1.0 - lodMult) * 0.3

	local smokeLifeBase = presetLifeMult
	local smokeAlphaBase = (1.0 - ageFrac * PIECE_ALPHA_FADE) * (fi > 0 and 1.0 or 0.6)
	local smokeSizeSc = sc * (fi > 0 and 1.0 or 0.75)

	setBudget(PRIORITY_NORMAL)

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
			debugPieceSpawnCount = debugPieceSpawnCount + 1
		end
	end

	if fi > 0 then
		local sizeRand = mathRandom() * PARTICLE_SIZE_RANGE
		local particleSize = (PARTICLE_SIZE_MIN + sizeRand) * sc * FIRE_SIZE_MULT * fi
		spawnParticle(
			px + mathRandom() * 0.6 - 0.3, py + mathRandom() * 0.5, pz + mathRandom() * 0.6 - 0.3,
			vxs + (mathRandom() * SMOKE_VEL_RANDOM_2 - SMOKE_VEL_RANDOM),
			vys + mathRandom() * SMOKE_VEL_UP_RANGE + SMOKE_VEL_UP_MIN,
			vzs + (mathRandom() * SMOKE_VEL_RANDOM_2 - SMOKE_VEL_RANDOM),
			particleSize, 1,
			(FIRE_LIFETIME_MIN + mathRandom() * FIRE_LIFETIME_RANGE) * presetLifeMult * fi,
			(FIRE_ALPHA_MIN + mathRandom() * 0.2) * (0.5 + 0.5 * fi)
		)
		debugPieceSpawnCount = debugPieceSpawnCount + 1
	end
end

--------------------------------------------------------------------------------
-- Update all tracked piece projectiles
--------------------------------------------------------------------------------
local function updatePieceProjectiles(gameFrame)
	local projectiles = spGetProjectilesInRectangle(0, 0, mapSizeX, mapSizeZ, true, false)
	if not projectiles then return end

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
					local proTeam = spGetProjectileTeamID(proID)
					local proAlly = proTeam and spGetTeamAllyTeamID(proTeam) or -1
					trackedPieceProjectiles[proID] = {
						sizeScale = sizeScale,
						birthFrame = gameFrame,
						lifeFrames = mathFloor((PIECE_LIFE_BASE + pieceRadius * PIECE_LIFE_PER_RADIUS) * lifeScale),
						gen = gen,
						fireIntensity = fi,
						lifeBias = mathRandom() * 0.7,
						allyTeamID = proAlly,
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
-- Update callback: called by engine at computed update interval.
--------------------------------------------------------------------------------
local function onUpdate(gameFrame, preset, camX, camY, camZ, isFastForward)
	framePreset = preset
	frameCamX, frameCamY, frameCamZ = camX, camY, camZ
	local _, specFullView = spGetSpectatingState()
	frameFullView = specFullView
	frameAllyTeamID = specFullView and -1 or spGetMyAllyTeamID()
	updatePieceProjectiles(gameFrame)

	-- Debug output every 30 frames
	if gameFrame % 30 == 0 then
		local trackedCount = 0
		for _ in pairs(trackedPieceProjectiles) do trackedCount = trackedCount + 1 end
		-- spEcho(string.format(
		-- 	"[PieceTrails] spawned=%d  calls=%d  tracked=%d  skipGround=%d  skipOffscreen=%d  skipExpired=%d  skipNoPos=%d  preset=%s  interval=%d",
		-- 	debugPieceSpawnCount, debugPieceCallCount, trackedCount,
		-- 	debugPieceSkipAboveGround, debugPieceSkipOffscreen, debugPieceSkipExpired, debugPieceSkipNoPos,
		-- 	preset.name, api.getUpdateInterval()
		-- ))
		debugPieceSpawnCount = 0
		debugPieceCallCount = 0
		debugPieceSkipAboveGround = 0
		debugPieceSkipOffscreen = 0
		debugPieceSkipExpired = 0
		debugPieceSkipNoPos = 0
	end

	-- Clean up pending death data periodically (must run AFTER updatePieceProjectiles)
	if gameFrame % 90 == 30 then
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

--------------------------------------------------------------------------------
-- Gadget callins
--------------------------------------------------------------------------------

function gadget:Initialize()
	api = GG.Particles
	if not api then
		spEcho("Piece Trail Particles GL4: Particle Engine not available, removing")
		gadgetHandler:RemoveGadget()
		return
	end

	-- Localize API functions for hot-path performance
	spawnParticle   = api.spawnParticle
	setBudget       = api.setBudget
	bufferOffscreen = api.bufferOffscreen
	replayBuffer    = api.replayBuffer

	-- Localize shared physics constants
	SMOKE_VEL_UP_MIN      = api.SMOKE_VEL_UP_MIN
	SMOKE_VEL_UP_RANGE    = api.SMOKE_VEL_UP_RANGE
	SMOKE_VEL_RANDOM      = api.SMOKE_VEL_RANDOM
	SMOKE_VEL_RANDOM_2    = api.SMOKE_VEL_RANDOM_2
	PARTICLE_SIZE_MIN     = api.PARTICLE_SIZE_MIN
	PARTICLE_SIZE_RANGE   = api.PARTICLE_SIZE_RANGE
	PARTICLE_SIZE_INV_RANGE = api.PARTICLE_SIZE_INV_RANGE
	FIRE_LIFETIME_MIN     = api.FIRE_LIFETIME_MIN
	FIRE_LIFETIME_RANGE   = api.FIRE_LIFETIME_RANGE
	FIRE_SIZE_MULT        = api.FIRE_SIZE_MULT
	FIRE_ALPHA_MIN        = api.FIRE_ALPHA_MIN
	CULLING_MARGIN        = api.CULLING_MARGIN
	PIECE_CULLING_RADIUS  = 50 + CULLING_MARGIN
	PRIORITY_NORMAL       = api.PRIORITY_NORMAL

	buildUnitDeathSizeCache()

	-- Register callbacks on the engine (called from engine's GameFrame)
	api.registerUpdateCallback(onUpdate)

	-- Register auto-flush for off-screen buffer replay in DrawWorld
	pieceFlushHandle = api.registerAutoFlush({
		entities = trackedPieceProjectiles,
		positionFn = spGetProjectilePosition,
		cullingRadius = PIECE_CULLING_RADIUS,
		replayFn = replayPieceEntries,
	})
end

function gadget:Shutdown()
	if api then
		api.unregisterUpdateCallback(onUpdate)
		api.unregisterAutoFlush(pieceFlushHandle)
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	local radius = unitDeathSizeCache[unitDefID]
	if radius then
		pendingDeathUnitRadii[unitID] = radius
	else
		excludedDeathUnits[unitID] = true
	end
end
