local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name      = "Unit Hit Lights",
		desc      = "Spawns short-lived deferred point lights on T2/T3 units when damaged. Plasma=warm flash, laser=weapon-colored glow. Lights follow the unit's piece automatically.",
		author    = "Phase 2 (lights)",
		date      = "2026-05-03",
		license   = "GNU GPL v2",
		layer     = 0,
		enabled   = true,
	}
end

------------------------------------------------------------------------------
-- CONFIG
------------------------------------------------------------------------------

local MIN_TECHLEVEL = 1

-- Per-kind light tuning. Lifetime/sustain/colortime are in game frames (30 = 1s).
-- (r,g,b)         = primary color
-- (r2,g2,b2)      = secondary color. The shader OSCILLATES between primary and
--                   secondary for unit-attached point lights — it's a continuous
--                   cosine cycle, NOT a one-way transition.
--                   See deferred_lights_gl4.vert.glsl ~L268.
-- colortime       = period of the cosine oscillation, in frames.
--                   0  = no color modulation (stays at primary)
--                   ~10  = visible flicker (good for flame)
--                   ~120 = slow drift (one full cycle per ~4s)
-- colorJitter     = ± random shift on each channel of r2/g2/b2 per spawn (0 = no variation)
-- colortimeJitter = ± random shift on colortime per spawn, in frames (0 = no variation)
-- cooldown        = min frames between consecutive lights of this kind on the SAME unit
-- maxActive       = global cap on active lights of this kind (0 = unlimited)
local LIGHT = {
	plasma = {
		radius      = 11,
		r  = 1.0,  g  = 0.55, b  = 0.15, a = 1.1,
		r2 = 0.9,  g2 = 0.45, b2 = 0.1,                 -- subtle hue cycle
		colortime       = 30,                              -- 0 = steady color (no oscillation needed for a quick flash)
		colorJitter     = 0.10,
		colortimeJitter = 15,
		lifetime    = 100,
		sustain     = 5,
		modelfactor = 2.1,
		specular    = 0.0,
		scattering  = 0.0,
		lensflare   = 0.0,
		cooldown    = 2,
		maxActive   = 500,
	},
	laser = {
		radius      = 20,
		a           = 2.5,                                -- (r,g,b) filled per-weapon below
		-- no secondary color shift for laser — keep weapon color steady
		colortime       = 0,
		colorJitter     = 0.0,
		colortimeJitter = 0,
		lifetime    = 300,
		sustain     = 6,
		modelfactor = 1.0,
		specular    = 1.0,
		scattering  = 0.0,
		lensflare   = 0.0,
		cooldown    = 6,
		maxActive   = 150,
	},
	bomb = {
		radius      = 22,
		r  = 1.0,  g  = 0.55, b  = 0.15, a = 0.7,
		r2 = 0.9,  g2 = 0.25, b2 = 0.05,                 -- secondary ember tone
		colortime       = 0,                              -- 0 = steady; bombs read better as a solid burst
		colorJitter     = 0.12,
		colortimeJitter = 0,
		lifetime    = 140,
		sustain     = 3,
		modelfactor = 1.0,
		specular    = 0.0,
		scattering  = 0.0,
		lensflare   = 0.0,
		cooldown    = 0,
		maxActive   = 150,
	},
	flame = {
		radius      = 30,
		r  = 1.0,  g  = 0.40, b  = 0.10, a = 0.5,
		r2 = 0.95, g2 = 0.30, b2 = 0.05,                  -- ember end of flicker
		colortime       = 22,                             -- ~0.4s/cycle — visible flame flicker
		colorJitter     = 0.10,
		colortimeJitter = 7,
		lifetime    = 150,
		sustain     = 2,
		modelfactor = 1.0,
		specular    = 0.0,
		scattering  = 0.0,
		lensflare   = 0.0,
		cooldown    = 8,
		maxActive   = 150,
	},
}

-- Small Y nudge above the chosen piece's origin. Lights now spawn at piece origin
-- + this offset (in piece-local space). Piece origins are inside the visible mesh,
-- so a tiny upward bias keeps the light just above the surface. 0-6 is the useful
-- range; bigger pushes lights up into the air above the unit.
local LIGHT_Y_OFFSET = 4

local WEAPON_TYPE_DEFAULTS = {
	Cannon            = "plasma",
	MissileLauncher   = "plasma",
	StarburstLauncher = "plasma",
	TorpedoLauncher   = "plasma",
	EmgCannon         = "plasma",
	AircraftBomb      = "bomb",
	BeamLaser         = "laser",
	LaserCannon       = "laser",
	LightningCannon   = "laser",
	Flame             = "flame",
}

------------------------------------------------------------------------------
-- LOCALS
------------------------------------------------------------------------------

local spGetGameFrame          = Spring.GetGameFrame
local spGetUnitPosition       = Spring.GetUnitPosition
local spGetUnitRadius         = Spring.GetUnitRadius
local spValidUnitID           = Spring.ValidUnitID
local spGetUnitPieceList      = Spring.GetUnitPieceList
local spGetUnitPiecePos       = Spring.GetUnitPiecePosition
local spGetUnitPieceInfo      = Spring.GetUnitPieceInfo
local spGetUnitPieceMatrix    = Spring.GetUnitPieceMatrix
local spGetUnitTransformMatrix = Spring.GetUnitTransformMatrix

local mathRandom = math.random
local mathSqrt   = math.sqrt
local mathSin    = math.sin
local mathCos    = math.cos

------------------------------------------------------------------------------
-- LOOKUPS (built in Initialize)
------------------------------------------------------------------------------

local unitEligible    = {}
local weaponDecalType = {}
local weaponColor     = {}   -- [wdid] = {r, g, b}

local function buildLookups()
	for udid, ud in pairs(UnitDefs) do
		local tech = tonumber(ud.customParams and ud.customParams.techlevel) or 1
		if tech >= MIN_TECHLEVEL then
			unitEligible[udid] = true
		end
	end

	for wdid, wd in pairs(WeaponDefs) do
		local cp = wd.customParams or {}
		local override = cp.bar_hit_decal_type
		local kind
		if override == "none" then
			kind = nil
		elseif override == "plasma" or override == "laser" then
			kind = override
		else
			kind = WEAPON_TYPE_DEFAULTS[wd.type]
		end
		weaponDecalType[wdid] = kind

		if kind == "laser" then
			local c = wd.visuals and (wd.visuals.color or wd.visuals.rgbColor1)
			if type(c) == "table" and #c >= 3 then
				weaponColor[wdid] = { c[1], c[2], c[3] }
			else
				weaponColor[wdid] = { 1.0, 0.3, 0.2 }
			end
		end
	end
end

------------------------------------------------------------------------------
-- PIECE SELECTION
------------------------------------------------------------------------------

-- Cache: [unitDefID] -> { pieceCount, [i] = { empty, cx, cy, cz } }
-- AABB center is in piece-local space; we use it only to score "this piece is biggest/most central"
-- which combined with current world position gives a decent piece pick.
local pieceCache = {}

local function getPieceCache(unitID, unitDefID)
	local c = pieceCache[unitDefID]
	if c then return c end
	local names = spGetUnitPieceList(unitID)
	if not names then return nil end
	local cache = { pieceCount = #names, unitName = (UnitDefs[unitDefID] and UnitDefs[unitDefID].name) or "?" }
	for i = 1, #names do
		local info = spGetUnitPieceInfo(unitID, i)
		local empty = true
		local cx, cy, cz = 0, 0, 0
		local pieceRadius = 0
		if info and info.min and info.max then
			empty = info.empty == true
			local mnx, mny, mnz = info.min[1], info.min[2], info.min[3]
			local mxx, mxy, mxz = info.max[1], info.max[2], info.max[3]
			cx = (mnx + mxx) * 0.5
			cy = (mny + mxy) * 0.5
			cz = (mnz + mxz) * 0.5
			local ax = math.max(math.abs(mnx), math.abs(mxx))
			local ay = math.max(math.abs(mny), math.abs(mxy))
			local az = math.max(math.abs(mnz), math.abs(mxz))
			pieceRadius = math.sqrt(ax*ax + ay*ay + az*az)
		end
		-- Skip pieces with absurd AABB radii (sentinel "infinite" markers, ±10000).
		local sane = pieceRadius < 200

		cache[i] = {
			name = names[i] or "?",
			empty = empty or not sane,
			cx = cx, cy = cy, cz = cz,
			radius = pieceRadius,
			minx = (info and info.min and info.min[1]) or 0,
			miny = (info and info.min and info.min[2]) or 0,
			minz = (info and info.min and info.min[3]) or 0,
			maxx = (info and info.max and info.max[1]) or 0,
			maxy = (info and info.max and info.max[2]) or 0,
			maxz = (info and info.max and info.max[3]) or 0,
		}
	end
	pieceCache[unitDefID] = cache
	return cache
end

-- Approximate world hit point on bounding sphere from attacker direction.
local function approximateWorldHit(unitID, attackerID)
	local ux, uy, uz = spGetUnitPosition(unitID)
	if not ux then return nil end
	local radius = spGetUnitRadius(unitID) or 16
	local r = radius * 0.85
	local cy = uy + radius * 0.5

	if attackerID and spValidUnitID(attackerID) then
		local ax, ay, az = spGetUnitPosition(attackerID)
		if ax then
			local dx, dy, dz = ax - ux, (ay + 20) - cy, az - uz
			local len = mathSqrt(dx*dx + dy*dy + dz*dz)
			if len > 0.001 then
				local inv = r / len
				return ux + dx * inv, cy + dy * inv, uz + dz * inv
			end
		end
	end

	local theta = mathRandom() * 6.2831853
	local phi   = mathRandom() * 0.6 + 0.2
	local sp = mathSin(phi)
	return ux + r * sp * mathCos(theta), cy + r * mathCos(phi), uz + r * sp * mathSin(theta)
end

local debugRemainingHits = 0  -- when > 0, echo per-hit diagnostics


-- Pick the non-empty piece whose ORIGIN is closest to the impact point.
-- Used as fallback when the engine doesn't report which piece was hit.
--
-- Why "piece origin"? Piece origins are authored at the pivot points of model
-- parts — they're INSIDE the visible mesh by construction. Anchoring lights to
-- a piece origin (rather than to an arbitrary computed surface position) keeps
-- lights consistently near the visible geometry, especially on small units
-- where collision-volume-vs-mesh discrepancy is large.
local function pickClosestPieceByOrigin(unitID, unitDefID, wx, wy, wz)
	local cache = getPieceCache(unitID, unitDefID)
	if not cache then return nil end
	local ux, uy, uz = spGetUnitPosition(unitID)
	if not ux then return nil end

	local bestIdx, bestD2 = nil, math.huge
	local verbose = debugRemainingHits > 0
	if verbose then
		Spring.Echo(string.format("  closest-piece-by-origin for %s (impact %.0f,%.0f,%.0f):",
			cache.unitName, wx, wy, wz))
	end
	for i = 1, cache.pieceCount do
		local p = cache[i]
		if p and not p.empty then
			local plx, ply, plz = spGetUnitPiecePos(unitID, i)
			if plx then
				local pwx, pwy, pwz = ux + plx, uy + ply, uz + plz
				local dx, dy, dz = pwx - wx, pwy - wy, pwz - wz
				local d2 = dx*dx + dy*dy + dz*dz
				if verbose then
					Spring.Echo(string.format("    [%d] %-20s wpos=(%5.0f,%4.0f,%5.0f) dist=%.1f",
						i, p.name, pwx, pwy, pwz, math.sqrt(d2)))
				end
				if d2 < bestD2 then
					bestD2 = d2
					bestIdx = i
				end
			end
		end
	end
	if bestIdx and verbose then
		Spring.Echo(string.format("  -> WINNER: piece [%d] %s", bestIdx, cache[bestIdx].name))
	end
	return bestIdx
end

------------------------------------------------------------------------------
-- HIT HOOK (called by gfx_unit_hit_decals_forwarding.lua via Script.LuaUI)
------------------------------------------------------------------------------

local stats = {
	hitsReceived = 0,
	rejectedNotEligible = 0,
	rejectedNoKind = 0,
	rejectedNoLightsAPI = 0,
	rejectedNoHitPos = 0,
	rejectedNoPiece = 0,
	rejectedCooldown = 0,
	rejectedMaxActive = 0,
	lightsSpawned = 0,
}

-- Throttling state.
-- lastSpawnFrame[kind][unitID] = game frame the most recent light of this kind was spawned on this unit.
-- activeCount[kind] = how many lights of this kind are currently alive (decremented at expiry).
-- expirySchedule[frame] = list of {kind} pairs to decrement when that frame is reached.
local lastSpawnFrame = { plasma = {}, laser = {}, bomb = {}, flame = {} }
local activeCount    = { plasma = 0,  laser = 0,  bomb = 0,  flame = 0  }
local expirySchedule = {}  -- [frame] = { "plasma", "flame", ... }

local function UnitHitDecal(unitID, unitDefID, weaponDefID, attackerID, damage,
                            hx, hy, hz, vx, vy, vz, hitPiece)
	stats.hitsReceived = stats.hitsReceived + 1

	if not unitEligible[unitDefID] then
		stats.rejectedNotEligible = stats.rejectedNotEligible + 1
		return
	end

	local kind = weaponDecalType[weaponDefID]
	if not kind then
		stats.rejectedNoKind = stats.rejectedNoKind + 1
		return
	end

	if not WG['lightsgl4'] or not WG['lightsgl4'].AddPointLight then
		stats.rejectedNoLightsAPI = stats.rejectedNoLightsAPI + 1
		return
	end

	local cfg = LIGHT[kind]
	local now = spGetGameFrame()

	-- Per-unit cooldown: one light of this kind per N frames per unit.
	if cfg.cooldown > 0 then
		local last = lastSpawnFrame[kind][unitID]
		if last and (now - last) < cfg.cooldown then
			stats.rejectedCooldown = stats.rejectedCooldown + 1
			return
		end
	end

	-- Global cap on active lights of this kind.
	if cfg.maxActive > 0 and activeCount[kind] >= cfg.maxActive then
		stats.rejectedMaxActive = stats.rejectedMaxActive + 1
		return
	end

	-- Piece selection: trust the engine first, fall back to closest piece by origin.
	-- (We need wx,wy,wz only for the fallback. If engine reports a piece, we don't
	-- compute or use a world hit position at all — the light goes at the piece origin.)
	local pieceIndex
	if hitPiece and hitPiece > 0 then
		local cache = getPieceCache(unitID, unitDefID)
		if cache and cache[hitPiece] and not cache[hitPiece].empty then
			pieceIndex = hitPiece
		end
	end
	if not pieceIndex then
		local wx, wy, wz
		if hx then
			wx, wy, wz = hx, hy, hz
		else
			wx, wy, wz = approximateWorldHit(unitID, attackerID)
		end
		if wx then
			pieceIndex = pickClosestPieceByOrigin(unitID, unitDefID, wx, wy, wz)
		end
	end

	if debugRemainingHits > 0 then
		Spring.Echo(string.format(
			"[UnitHitLights] hit unit %d (%s) kind=%s dmg=%.0f hitPiece(engine)=%s -> picked=%s",
			unitID, (UnitDefs[unitDefID] and UnitDefs[unitDefID].name) or "?",
			kind, damage, tostring(hitPiece), tostring(pieceIndex)))
		debugRemainingHits = debugRemainingHits - 1
	end

	if not pieceIndex then
		stats.rejectedNoPiece = stats.rejectedNoPiece + 1
		return
	end

	-- Light goes at the piece's AABB CENTER (in piece-local space) + small Y nudge.
	-- Piece origins are often at ground level (model bottom), which puts lights at
	-- the unit's feet — wrong. The AABB center is the geometric middle of the
	-- visible piece geometry, guaranteed inside the mesh.
	local cache = pieceCache[unitDefID]
	local p = cache and cache[pieceIndex]
	local ox, oy, oz = 0, LIGHT_Y_OFFSET, 0
	if p then
		ox, oy, oz = p.cx, p.cy + LIGHT_Y_OFFSET, p.cz
	end

	local r, g, b
	if kind == "laser" then
		local c = weaponColor[weaponDefID]
		r, g, b = c[1], c[2], c[3]
	else
		r, g, b = cfg.r, cfg.g, cfg.b
	end

	-- Secondary color (transition target over `colortime`). Per-spawn jitter for variation.
	-- Lasers have colortime=0 so this branch is a no-op for them.
	local r2, g2, b2, ct = 0, 0, 0, 0
	if cfg.r2 and cfg.colortime and cfg.colortime > 0 then
		local cj = cfg.colorJitter or 0
		local tj = cfg.colortimeJitter or 0
		if cj > 0 then
			r2 = cfg.r2 + (mathRandom() * 2 - 1) * cj
			g2 = cfg.g2 + (mathRandom() * 2 - 1) * cj
			b2 = cfg.b2 + (mathRandom() * 2 - 1) * cj
			if r2 < 0 then r2 = 0 elseif r2 > 1 then r2 = 1 end
			if g2 < 0 then g2 = 0 elseif g2 > 1 then g2 = 1 end
			if b2 < 0 then b2 = 0 elseif b2 > 1 then b2 = 1 end
		else
			r2, g2, b2 = cfg.r2, cfg.g2, cfg.b2
		end
		ct = cfg.colortime
		if tj > 0 then
			ct = ct + (mathRandom() * 2 - 1) * tj
			if ct < 1 then ct = 1 end
		end
	end

	-- Bigger hits = bigger light, capped.
	local radiusMult = 1.0
	if damage > 200 then radiusMult = 1.3 end
	if damage > 800 then radiusMult = 1.6 end

	-- Build the light param table by explicit slot, using the canonical layout from
	-- gfx_deferred_rendering_GL4.lua's lightParamKeyOrder. Passing a pre-built table
	-- avoids the AddPointLight wrapper's slot-pollution bug where positional args
	-- get written to BOTH worldposrad2 (slots 5-8) AND color2 (21-24). Slot 8
	-- (worldposrad2.w) controls world-space animation acceleration in the shader,
	-- so polluting it with `colortime` flings the light off into space.
	-- VBO expects 29 elements per instance: 25 light params + 4 instData slots
	-- (matoffset, uniformoffset, teamIndex, drawFlags) which the engine populates.
	local lightParams = {
		[1] = ox, [2] = oy, [3] = oz, [4] = cfg.radius * radiusMult,
		[5] = 0, [6] = 0, [7] = 0, [8] = 0,                    -- worldposrad2 — MUST stay zero
		[9] = r, [10] = g, [11] = b, [12] = cfg.a,             -- light color rgba
		[13] = cfg.modelfactor, [14] = cfg.specular, [15] = cfg.scattering, [16] = cfg.lensflare,
		[17] = 0,                                               -- spawnframe (auto-filled by AddPointLight)
		[18] = cfg.lifetime, [19] = cfg.sustain, [20] = 0,
		[21] = r2, [22] = g2, [23] = b2, [24] = ct,            -- color2 + colortime
		[25] = pieceIndex,                                      -- pieceIndex (table form needs this set explicitly)
		[26] = 0, [27] = 0, [28] = 0, [29] = 0,                 -- instData (engine fills these)
	}
	WG['lightsgl4'].AddPointLight(
		nil,            -- instanceID (auto)
		unitID,         -- attach to this unit
		pieceIndex,     -- attach to this piece
		nil,            -- targetVBO (auto)
		lightParams     -- pre-built param table
	)
	stats.lightsSpawned = stats.lightsSpawned + 1

	-- Bookkeeping for throttle/cap.
	lastSpawnFrame[kind][unitID] = now
	activeCount[kind] = activeCount[kind] + 1
	local expireFrame = now + cfg.lifetime
	local list = expirySchedule[expireFrame]
	if not list then
		list = {}
		expirySchedule[expireFrame] = list
	end
	list[#list + 1] = kind
end

function widget:GameFrame(n)
	-- Decrement active-light counters for any lights that expired this frame.
	local list = expirySchedule[n]
	if list then
		for i = 1, #list do
			local k = list[i]
			activeCount[k] = activeCount[k] - 1
			if activeCount[k] < 0 then activeCount[k] = 0 end
		end
		expirySchedule[n] = nil
	end
end

function widget:TextCommand(command)
	if command == "unithitlights stats" then
		Spring.Echo(string.format(
			"[UnitHitLights] hits=%d notEligible=%d noKind=%d noLightsAPI=%d noHitPos=%d noPiece=%d cooldown=%d capped=%d spawned=%d",
			stats.hitsReceived, stats.rejectedNotEligible, stats.rejectedNoKind,
			stats.rejectedNoLightsAPI, stats.rejectedNoHitPos, stats.rejectedNoPiece,
			stats.rejectedCooldown, stats.rejectedMaxActive, stats.lightsSpawned))
		Spring.Echo(string.format(
			"  active: plasma=%d  laser=%d  bomb=%d  flame=%d",
			activeCount.plasma, activeCount.laser, activeCount.bomb, activeCount.flame))
		return true
	end
	if command == "unithitlights reset" then
		for k, _ in pairs(stats) do stats[k] = 0 end
		Spring.Echo("[UnitHitLights] stats reset")
		return true
	end
	if command == "unithitlights debug" then
		debugRemainingHits = 5
		Spring.Echo("[UnitHitLights] verbose: will dump per-piece scoring for the next 5 hits")
		return true
	end
	return false
end

------------------------------------------------------------------------------
-- LIFECYCLE
------------------------------------------------------------------------------

function widget:Initialize()
	buildLookups()
	widgetHandler:RegisterGlobal("UnitHitDecal", UnitHitDecal)
end

function widget:Shutdown()
	widgetHandler:DeregisterGlobal("UnitHitDecal")
end
