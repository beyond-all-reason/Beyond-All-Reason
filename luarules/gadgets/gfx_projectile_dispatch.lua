--------------------------------------------------------------------------------
-- Projectile Dispatch
-- Shared per-frame projectile scan + weaponDefID filter for the (GL4 visual) gadgets
-- gadgets (flamethrower, beam laser, missile thruster, plasma cannon,
-- lightning cannon, fire & smoke).
--
-- Problem this solves
-- -------------------
-- Each visual gadget used to independently call
--     Spring.GetVisibleProjectiles(...)        -- flame/missile/plasma
--     Spring.GetProjectilesInRectangle(...)    -- beam/lightning/fire-smoke
-- and then iterate the full result calling Spring.GetProjectileDefID(proID)
-- on every projectile to filter for its own weapon set. With many simultaneous
-- projectiles on screen (e.g. 80+ flamethrowers firing) that turns into
--
--     (engine list call * 5 gadgets) + (defID call * proID-count * 5 gadgets)
--
-- per sim frame, even when most of those gadgets have zero projectiles to
-- render.
--
-- What this gadget does
-- ---------------------
-- Runs once per sim frame (and once per render frame while paused) and
-- collapses the redundant work into:
--
--   * One Spring.GetVisibleProjectiles      call (broadest variant)
--   * One Spring.GetProjectilesInRectangle  call for weapons (map-wide)
--   * One Spring.GetProjectilesInRectangle  call for pieces  (map-wide)
--   * One Spring.GetProjectileDefID         call per projectile per scan
--
-- Consumers subscribe with a defID set; on demand they get a pre-filtered
-- array of proIDs that match their set. Engine scans are lazy: a scanID is
-- only executed when a subscriber asks for it and the cached result for the
-- current tick is missing.
--
-- API (GG.ProjectileScan)
-- -----------------------
--   SCAN_VISIBLE       -- visible projectiles (synced + weapons + pieces)
--   SCAN_MAP_WEAPONS   -- weapon projectiles, map-wide
--   SCAN_MAP_PIECES    -- piece projectiles,  map-wide
--
--   handle = Subscribe(name, defIDSet, scanID)
--       defIDSet = { [weaponDefID] = true, ... }   or nil to receive raw list
--
--   matches, count = GetMatches(handle)
--       matches is a reused array; do not store it across frames.
--
--   matches, defIDs, count = GetMatchesWithDefIDs(handle)
--       returns the matched proIDs AND a parallel array of their wDefIDs so
--       consumers can index their own config tables without calling
--       Spring.GetProjectileDefID again.
--
--   projectiles, count = GetScan(scanID)
--       raw cached scan result; do not mutate.
--
-- Consumers MUST guard against the gadget being disabled:
--       local PS = GG.ProjectileScan
--       if not PS then ... fall back ... end
--
-- NOTE: an earlier version of this gadget tried to serve SCAN_MAP_WEAPONS
-- from a reactive registry populated by synced ProjectileCreated/Destroyed
-- events (via Script.SetWatchProjectile + SendToUnsynced). That avoided the
-- map-wide engine list call entirely, but the synced->unsynced events arrive
-- ~1 sim frame later than the engine's own projectile list, so short-lived
-- projectiles (beam lasers with small beamttl) were missed every other frame.
-- The registry approach was reverted; SCAN_MAP_WEAPONS now uses the same
-- cached engine-call path as SCAN_MAP_PIECES. The win is still one engine
-- call per sim frame shared across all subscribers.
--------------------------------------------------------------------------------

function gadget:GetInfo()
	return {
		name = "Projectile Dispatch",
		desc = "Shared per-frame projectile scan + defID filter for other gadgets",
		author = "Floris",
		date = "May 2026",
		license = "GNU GPL v2",
		-- Loaded before all gfx_*_gl4 visual gadgets (which use layer = 0) so
		-- GG.ProjectileScan exists at their Initialize time.
		layer = -50,
		enabled = true,
	}
end

if gadgetHandler:IsSyncedCode() then
	-- Unsynced-only gadget: no synced state needed.
	return
end

--------------------------------------------------------------------------------
-- Localized engine calls
--------------------------------------------------------------------------------
local spGetVisibleProjectiles = Engine.Unsynced.GetVisibleProjectiles
local spGetProjectilesInRectangle = Engine.Shared.GetProjectilesInRectangle
local spGetProjectileDefID = Engine.Shared.GetProjectileDefID
local spGetGameFrame = Engine.Shared.GetGameFrame
local spGetGameSpeed = Engine.Unsynced.GetGameSpeed

local mapSizeX = Game.mapSizeX
local mapSizeZ = Game.mapSizeZ

--------------------------------------------------------------------------------
-- Scan IDs
--------------------------------------------------------------------------------
local SCAN_VISIBLE = 1
local SCAN_MAP_WEAPONS = 2
local SCAN_MAP_PIECES = 3

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------
-- scanState[scanID] = { lastTick, projectiles, projectileCount }
local scanState = {
	[SCAN_VISIBLE] = { lastTick = -1, projectiles = nil, projectileCount = 0 },
	[SCAN_MAP_WEAPONS] = { lastTick = -1, projectiles = nil, projectileCount = 0 },
	[SCAN_MAP_PIECES] = { lastTick = -1, projectiles = nil, projectileCount = 0 },
}

-- subscribersByScan[scanID] = { sub, sub, ... }
local subscribersByScan = {
	[SCAN_VISIBLE] = {},
	[SCAN_MAP_WEAPONS] = {},
	[SCAN_MAP_PIECES] = {},
}

-- handle -> { name, defIDSet, scanID, matches, matchCount, lastTick }
local subscribers = {}
local nextHandle = 0

-- Tick monotonically bumps on every sim frame (GameFrame) and on every render
-- frame while paused (Update). Each scanID runs at most once per tick.
local currentTick = 0
local lastBumpedSimFrame = -1

--------------------------------------------------------------------------------
-- Scan execution
--------------------------------------------------------------------------------
local function runScan(scanID)
	local state = scanState[scanID]
	if state.lastTick == currentTick then
		return
	end
	state.lastTick = currentTick

	local projectiles
	if scanID == SCAN_VISIBLE then
		-- Broadest variant: synced + weapons + pieces. Subscribers that only
		-- want a subset filter via their defIDSet (piece projectiles return a
		-- defID that no weapon subscriber has, so they get rejected for free).
		projectiles = spGetVisibleProjectiles(-1, true, true, true)
	elseif scanID == SCAN_MAP_PIECES then
		projectiles = spGetProjectilesInRectangle(0, 0, mapSizeX, mapSizeZ, true, false)
	elseif scanID == SCAN_MAP_WEAPONS then
		-- Engine-authoritative weapon list. The reactive registry approach
		-- (Script.SetWatchProjectile + SendToUnsynced) was tried but the
		-- synced->unsynced events arrive ~1 sim frame later than the engine's
		-- own projectile list, causing short-lived projectiles (beam lasers
		-- with small beamttl) to be missed every other frame.
		projectiles = spGetProjectilesInRectangle(0, 0, mapSizeX, mapSizeZ, false, true)
	end

	state.projectiles = projectiles
	state.projectileCount = projectiles and #projectiles or 0

	-- Reset all subscribers' match arrays for this scan.
	local subs = subscribersByScan[scanID]
	local nSubs = #subs
	for s = 1, nSubs do
		local sub = subs[s]
		sub.matchCount = 0
		sub.lastTick = currentTick
	end

	if not projectiles or nSubs == 0 then
		return
	end

	-- Single pass: one GetProjectileDefID per projectile, dispatched to every
	-- interested subscriber. Piece projectiles have no weapon-def ID, so for
	-- SCAN_MAP_PIECES we skip the defID lookup entirely and dispatch every
	-- projectile (piece subscribers don't filter by defID).
	local n = state.projectileCount
	if scanID == SCAN_MAP_PIECES then
		for i = 1, n do
			local proID = projectiles[i]
			for s = 1, nSubs do
				local sub = subs[s]
				local c = sub.matchCount + 1
				sub.matchCount = c
				sub.matches[c] = proID
			end
		end
	else
		for i = 1, n do
			local proID = projectiles[i]
			local wDefID = spGetProjectileDefID(proID)
			if wDefID then
				for s = 1, nSubs do
					local sub = subs[s]
					local set = sub.defIDSet
					if not set or set[wDefID] then
						local c = sub.matchCount + 1
						sub.matchCount = c
						sub.matches[c] = proID
						sub.matchDefIDs[c] = wDefID
					end
				end
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------
local function Subscribe(name, defIDSet, scanID)
	local subs = subscribersByScan[scanID]
	if not subs then
		Engine.Shared.Echo("[gfx_projectile_dispatch] invalid scanID: " .. tostring(scanID))
		return nil
	end
	nextHandle = nextHandle + 1
	local sub = {
		name = name,
		defIDSet = defIDSet,
		scanID = scanID,
		matches = {},
		matchDefIDs = {},
		matchCount = 0,
		lastTick = -1,
	}
	subscribers[nextHandle] = sub
	subs[#subs + 1] = sub
	return nextHandle
end

local function GetMatches(handle)
	local sub = subscribers[handle]
	if not sub then
		return nil, 0
	end
	if sub.lastTick ~= currentTick then
		runScan(sub.scanID)
	end
	return sub.matches, sub.matchCount
end

local function GetMatchesWithDefIDs(handle)
	local sub = subscribers[handle]
	if not sub then
		return nil, nil, 0
	end
	if sub.lastTick ~= currentTick then
		runScan(sub.scanID)
	end
	return sub.matches, sub.matchDefIDs, sub.matchCount
end

local function GetScan(scanID)
	local state = scanState[scanID]
	if not state then
		return nil, 0
	end
	if state.lastTick ~= currentTick then
		runScan(scanID)
	end
	return state.projectiles, state.projectileCount
end

--------------------------------------------------------------------------------
-- Callins
--------------------------------------------------------------------------------
function gadget:Initialize()
	currentTick = spGetGameFrame() * 2
	lastBumpedSimFrame = spGetGameFrame()

	GG.ProjectileScan = {
		SCAN_VISIBLE = SCAN_VISIBLE,
		SCAN_MAP_WEAPONS = SCAN_MAP_WEAPONS,
		SCAN_MAP_PIECES = SCAN_MAP_PIECES,
		Subscribe = Subscribe,
		GetMatches = GetMatches,
		GetMatchesWithDefIDs = GetMatchesWithDefIDs,
		GetScan = GetScan,
	}
end

function gadget:Shutdown()
	GG.ProjectileScan = nil
end

function gadget:GameFrame(n)
	-- One tick advance per sim frame. Cached scans from the previous sim frame
	-- are invalidated; the next GetMatches call triggers a fresh engine call.
	currentTick = n * 2
	lastBumpedSimFrame = n
end

function gadget:Update()
	-- While paused, GameFrame stops firing but consumers (e.g. flamethrower's
	-- pause-mode snapshot path) still want fresh scans on every render frame
	-- so camera pans can pick up newly framed projectiles. Bump tick here so
	-- runScan re-fires. During normal play this is a no-op because GameFrame
	-- already advanced the tick for this sim frame.
	local _, _, paused = spGetGameSpeed()
	if paused then
		currentTick = currentTick + 1
	end
end
