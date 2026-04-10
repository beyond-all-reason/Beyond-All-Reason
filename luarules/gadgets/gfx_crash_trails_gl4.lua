--------------------------------------------------------------------------------
-- Crash Trail Particles GL4
-- Smoke and fire trails for crashing aircraft.
-- Uses GG.Particles API from the core particle engine.
--------------------------------------------------------------------------------

if gadgetHandler:IsSyncedCode() then
	return
end

function gadget:GetInfo()
	return {
		name = "Crash Trail Particles GL4",
		desc = "Smoke/fire trails for crashing aircraft via Particle Engine",
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
local spEcho = Spring.Echo
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitVelocity = Spring.GetUnitVelocity
local spValidUnitID = Spring.ValidUnitID
local spIsSphereInView = Spring.IsSphereInView
local spIsPosInAirLos = Spring.IsPosInAirLos
local spGetTeamAllyTeamID = Spring.GetTeamAllyTeamID
local spGetMyAllyTeamID = Spring.GetLocalAllyTeamID
local spGetSpectatingState = Spring.GetSpectatingState

local mathRandom = math.random
local mathMin = math.min
local mathMax = math.max
local mathFloor = math.floor
local mathSqrt = math.sqrt

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------
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

-- Unit-based crash trail scaling
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

-- Replay quality: preset index for off-screen buffer replay (0 = use current)
local REPLAY_CRASH_PRESET = 0

-- Pre-computed
local CRASH_ALPHA_RANGE = 1.0 - CRASH_ALPHA_MIN

--------------------------------------------------------------------------------
-- Particle engine API (localized at init for performance)
--------------------------------------------------------------------------------
local api -- GG.Particles reference
local spawnParticle -- api.spawnParticle
local setBudget -- api.setBudget
local bufferOffscreen -- api.bufferOffscreen
local replayBuffer -- api.replayBuffer

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
local CRASH_CULLING_TOTAL
local PRIORITY_ESSENTIAL

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------
local trackedCrashingAircraft = {}
local crashingAircraftCount = 0
local crashFlushHandle = nil

-- Aircraft data cache for crash trail scaling
local aircraftDataCache = {}

--------------------------------------------------------------------------------
-- Build aircraft data cache
--------------------------------------------------------------------------------
local function buildAircraftDataCache()
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

--------------------------------------------------------------------------------
-- Replay buffered off-screen crash frames retroactively
-- Called by the engine's buffer management (replayBuffer / autoFlush).
-- buf: array of {frame, px, py, pz, vx, vy, vz} entries
--------------------------------------------------------------------------------
local function replayCrashEntries(tracked, gameFrame, buf)
	local preset = REPLAY_CRASH_PRESET > 0 and api.getPreset(REPLAY_CRASH_PRESET) or api.getPreset()
	local sc = tracked.sizeScale
	local fi = tracked.fireIntensity
	local unitLifeMult = tracked.lifetimeMult
	local unitSpawnMult = tracked.spawnMult

	local spawnCount = mathMax(1, mathFloor(CRASH_SPAWN_COUNT * preset.spawnMult * unitSpawnMult + 0.5))
	local presetLifeMult = preset.lifetimeMult
	local smokeSizeSc = sc * (fi > 0 and 1.0 or 0.75)
	setBudget(PRIORITY_ESSENTIAL)

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
			spawnParticle(bpx + mathRandom() * 4 - 2, bpy + mathRandom() * 2, bpz + mathRandom() * 4 - 2, vxs + (mathRandom() * SMOKE_VEL_RANDOM_2 - SMOKE_VEL_RANDOM), vys + mathRandom() * SMOKE_VEL_UP_RANGE + SMOKE_VEL_UP_MIN, vzs + (mathRandom() * SMOKE_VEL_RANDOM_2 - SMOKE_VEL_RANDOM), particleSize, 0, (CRASH_LIFETIME_MIN + mathRandom() * CRASH_LIFETIME_RANGE) * (1.0 + sizeRand * PARTICLE_SIZE_INV_RANGE) * smokeLifeBase, (CRASH_ALPHA_MIN + mathRandom() * CRASH_ALPHA_RANGE) * smokeAlphaBase, nil, frame)
		end

		if fi > 0 then
			local sizeRand = mathRandom() * PARTICLE_SIZE_RANGE
			local particleSize = (PARTICLE_SIZE_MIN + sizeRand) * sc * FIRE_SIZE_MULT * CRASH_FIRE_SIZE_MULT * fi
			spawnParticle(bpx + mathRandom() * 2 - 1, bpy + mathRandom(), bpz + mathRandom() * 2 - 1, vxs + (mathRandom() * SMOKE_VEL_RANDOM_2 - SMOKE_VEL_RANDOM), vys + mathRandom() * SMOKE_VEL_UP_RANGE + SMOKE_VEL_UP_MIN, vzs + (mathRandom() * SMOKE_VEL_RANDOM_2 - SMOKE_VEL_RANDOM), particleSize, 1, (FIRE_LIFETIME_MIN + mathRandom() * FIRE_LIFETIME_RANGE) * presetLifeMult * CRASH_FIRE_LIFETIME_MULT * fi * unitLifeMult, (FIRE_ALPHA_MIN + mathRandom() * 0.2) * (0.5 + 0.5 * fi), nil, frame)
		end
	end
end

--------------------------------------------------------------------------------
-- Spawn crash trail particles for one aircraft
--------------------------------------------------------------------------------
-- Passed via spawnCrashTrailParticles from the update callback
local framePreset
local frameCamX, frameCamY, frameCamZ = 0, 0, 0
local frameAllyTeamID = -1
local frameFullView = true

local function spawnCrashTrailParticles(tracked, unitID, gameFrame)
	local crashAge = gameFrame - tracked.birthFrame
	if crashAge > CRASH_MAX_DURATION then
		return
	end

	local px, py, pz = spGetUnitPosition(unitID)
	if not px then
		return
	end

	-- LOS check: own allyteam crashes always visible, enemy ones need LOS
	if not frameFullView and tracked.allyTeamID ~= frameAllyTeamID and not spIsPosInAirLos(px, py, pz, frameAllyTeamID) then
		return
	end

	local inView = spIsSphereInView(px, py, pz, CRASH_CULLING_TOTAL)
	if not inView then
		local uvx, uvy, uvz = spGetUnitVelocity(unitID)
		bufferOffscreen(tracked, gameFrame, px, py, pz, uvx or 0, uvy or 0, uvz or 0)
		return
	end

	-- Transition to in-view: replay buffered particles
	replayBuffer(tracked, gameFrame, replayCrashEntries)

	local dx, dy, dz = px - frameCamX, py - frameCamY, pz - frameCamZ
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

	local presetLifeMult = framePreset.lifetimeMult * lodMult
	local spawnCount = mathMax(1, mathFloor(CRASH_SPAWN_COUNT * framePreset.spawnMult * lodMult * unitSpawnMult + 0.5))
	local skipChance = CRASH_SKIP_CHANCE + (1.0 - lodMult) * 0.3

	local smokeLifeBase = presetLifeMult * unitLifeMult
	local smokeAlphaBase = (1.0 - ageFrac * CRASH_ALPHA_FADE) * (fi > 0 and 1.0 or 0.6)
	local smokeSizeSc = sc * (fi > 0 and 1.0 or 0.75)

	setBudget(PRIORITY_ESSENTIAL)

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

--------------------------------------------------------------------------------
-- Update all tracked crashing aircraft
--------------------------------------------------------------------------------
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
-- Public API: start tracking a crashing aircraft
--------------------------------------------------------------------------------
local function apiCrashingAircraft(unitID, unitDefID, teamID)
	if not api then
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
		birthFrame = api.getGameFrame(),
		fireIntensity = fi,
		lifetimeMult = lifetimeMult,
		spawnMult = spawnMult,
		allyTeamID = teamID and spGetTeamAllyTeamID(teamID) or -1,
	}
	crashingAircraftCount = crashingAircraftCount + 1
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
	updateCrashingAircraft(gameFrame)
end

--------------------------------------------------------------------------------
-- Gadget callins
--------------------------------------------------------------------------------

function gadget:Initialize()
	api = GG.Particles
	if not api then
		spEcho("Crash Trail Particles GL4: Particle Engine not available, removing")
		gadgetHandler:RemoveGadget()
		return
	end

	-- Localize API functions for hot-path performance
	spawnParticle = api.spawnParticle
	setBudget = api.setBudget
	bufferOffscreen = api.bufferOffscreen
	replayBuffer = api.replayBuffer

	-- Localize shared physics constants
	SMOKE_VEL_UP_MIN = api.SMOKE_VEL_UP_MIN
	SMOKE_VEL_UP_RANGE = api.SMOKE_VEL_UP_RANGE
	SMOKE_VEL_RANDOM = api.SMOKE_VEL_RANDOM
	SMOKE_VEL_RANDOM_2 = api.SMOKE_VEL_RANDOM_2
	PARTICLE_SIZE_MIN = api.PARTICLE_SIZE_MIN
	PARTICLE_SIZE_RANGE = api.PARTICLE_SIZE_RANGE
	PARTICLE_SIZE_INV_RANGE = api.PARTICLE_SIZE_INV_RANGE
	FIRE_LIFETIME_MIN = api.FIRE_LIFETIME_MIN
	FIRE_LIFETIME_RANGE = api.FIRE_LIFETIME_RANGE
	FIRE_SIZE_MULT = api.FIRE_SIZE_MULT
	FIRE_ALPHA_MIN = api.FIRE_ALPHA_MIN
	CULLING_MARGIN = api.CULLING_MARGIN
	CRASH_CULLING_TOTAL = CRASH_CULLING_RADIUS + CULLING_MARGIN
	PRIORITY_ESSENTIAL = api.PRIORITY_ESSENTIAL

	buildAircraftDataCache()

	-- Register callbacks on the engine (called from engine's GameFrame)
	api.registerUpdateCallback(onUpdate)
	crashFlushHandle = api.registerAutoFlush({
		entities = trackedCrashingAircraft,
		positionFn = spGetUnitPosition,
		cullingRadius = CRASH_CULLING_TOTAL,
		replayFn = replayCrashEntries,
	})

	-- Expose crash API on GG.Particles (also accessible via GG.FireSmoke alias)
	api.CrashingAircraft = apiCrashingAircraft
end

function gadget:Shutdown()
	if api then
		api.unregisterUpdateCallback(onUpdate)
		api.unregisterAutoFlush(crashFlushHandle)
		api.CrashingAircraft = nil
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	if trackedCrashingAircraft[unitID] then
		trackedCrashingAircraft[unitID] = nil
		crashingAircraftCount = crashingAircraftCount - 1
	end
end
