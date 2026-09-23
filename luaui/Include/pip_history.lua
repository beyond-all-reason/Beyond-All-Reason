-- Rolling event log for the PIP rewind: unit positions (dead reckoning), health and build
-- levels, hits, deaths, explosions, orders, heavy beams, long-flight projectiles, map marks,
-- wrecks and broadcast cameras, packed into u16 strings per tick and zlib-frozen once cold.
-- Over the byte cap the oldest keyframe segments are spilled to files; a coarse copy of each
-- stays resident so the whole log always plays back while the detail loads.
--
-- Store: one per LuaUI state, shared by every PIP instance (recording is idempotent per frame).
-- View:  one per PIP instance, materialises the recorded world at any frame inside the log.

local PipHistory = {}

local packU16 = VFS.PackU16
local unpackU16 = VFS.UnpackU16
local zlibCompress = VFS.ZlibCompress
local zlibDecompress = VFS.ZlibDecompress
local mathFloor = math.floor
local mathAbs = math.abs
local mathMin = math.min
local mathMax = math.max

-- record layouts (u16 each)
local UNIT_STRIDE = 7 -- id, defID, team | flags << 8, x, z, vx + bias, vz + bias: new / keyframe / flag change (a dead record keeps its death age in the vx slot)
local MOVE_STRIDE = 5 -- id, x, z, vx + bias, vz + bias: a known unit re-logged after drifting
local EXPL_STRIDE = 4 -- x, z, weaponDefID + flags << 12, age
local EVENT_STRIDE = 7 -- kind, a, b, c, d, e, age: deaths, orders, beams
local PROJ_STRIDE = 7 -- id, weaponDefID, x, z, vx + bias, vz + bias, age: a shell's launch / course change
local PEND_STRIDE = 2 -- id, age: the shell is gone
local HP_STRIDE = 2 -- id, health level 0..hpStates-1 (logged on change only)
local BLD_STRIDE = 2 -- id, build level 0..hpStates-1 (logged on change only)
local DMG_STRIDE = 3 -- id, hit strength 0..100, age
local FEAT_STRIDE = 7 -- kind, featureID, featureDefID, x, z, heading + 32768, age
local CAM_STRIDE = 6 -- player | heightFlag << 8, x, z, distance, tilt, heading: a broadcast camera
local V_SCALE = 64 -- velocity quantum: 1/64 elmo per frame
local V_BIAS = 32768
local V_MAX = 511 -- elmo per frame, ±(32767 / 64)
local TICK_OVERHEAD = 128 -- rough per-tick table cost counted against the byte cap
local STREAMS = { "units", "moves", "expl", "events", "proj", "pend", "hp", "bld", "dmg", "feat", "cam" }

PipHistory.F_RADAR = 1 -- seen on radar only
PipHistory.F_VANISH = 2 -- left vision (last known position)
PipHistory.F_DEAD = 4 -- destroyed at this position
PipHistory.F_GHOST = 8 -- building that left vision: keep drawing it dimmed
PipHistory.F_BUILDING = 16

PipHistory.EV_EXPLOSION = 1 -- own stream (expl)
PipHistory.EV_DEATH = 2 -- a = unitID, b = x, c = z, d = defID, e = team
PipHistory.EV_COMMAND = 3 -- a = unitID, b = kind | queued << 8, c = x, d = z, e = target unitID
PipHistory.EV_BEAM = 4 -- a = ox, b = oz, c = tx, d = tz, e = weaponDefID
PipHistory.EV_MARK = 5 -- a = playerID, b = teamID | spectator << 8, c = x, d = z
PipHistory.EV_MAPLINE = 6 -- a = teamID, b = x1, c = z1, d = x2, e = z2
PipHistory.EV_ERASE = 7 -- a = x, b = z, c = radius
PipHistory.FEAT_CREATED = 1 -- feat stream kinds
PipHistory.FEAT_GONE = 2

PipHistory.CMD_MOVE = 1
PipHistory.CMD_FIGHT = 2
PipHistory.CMD_ATTACK = 3
PipHistory.CMD_PATROL = 4
PipHistory.CMD_BUILD = 5
PipHistory.CMD_OTHER = 6

local F_RADAR, F_VANISH, F_DEAD, F_GHOST, F_BUILDING =
	PipHistory.F_RADAR, PipHistory.F_VANISH, PipHistory.F_DEAD, PipHistory.F_GHOST, PipHistory.F_BUILDING
local EV_DEATH, EV_COMMAND, EV_BEAM = PipHistory.EV_DEATH, PipHistory.EV_COMMAND, PipHistory.EV_BEAM
local EV_MARK, EV_MAPLINE, EV_ERASE = PipHistory.EV_MARK, PipHistory.EV_MAPLINE, PipHistory.EV_ERASE
local FEAT_CREATED, FEAT_GONE = PipHistory.FEAT_CREATED, PipHistory.FEAT_GONE

local function clampU16(v)
	if v < 0 then
		return 0
	elseif v > 65534.5 then
		return 65535
	end
	return mathFloor(v + 0.5)
end

local function quantV(v)
	if v > V_MAX then
		v = V_MAX
	elseif v < -V_MAX then
		v = -V_MAX
	end
	return mathFloor(v * V_SCALE + 0.5) + V_BIAS
end

---@param str string?
---@return table<integer, integer>?
local function unpackAll(str)
	if not str then
		return nil
	end
	-- the engine's annotation only knows the single-value form
	---@diagnostic disable-next-line: redundant-parameter
	local arr = unpackU16(str, 1, -1)
	---@diagnostic disable-next-line: cast-type-mismatch
	---@cast arr table<integer, integer>
	return arr
end

---@return integer
local function findTickIndex(ticks, frame)
	-- last tick with tick.frame <= frame, or 0
	local lo, hi = 1, #ticks
	local best = 0
	while lo <= hi do
		local mid = mathFloor((lo + hi) / 2)
		if ticks[mid].frame <= frame then
			best = mid
			lo = mid + 1
		else
			hi = mid - 1
		end
	end
	return best
end

local function trim(buf, n)
	for i = #buf, n + 1, -1 do
		buf[i] = nil
	end
end

----------------------------------------------------------------------------------------------------
-- Store (recorder)
----------------------------------------------------------------------------------------------------

---@class PipHistoryTick
---@field frame number
---@field key boolean
---@field level number
---@field bytes number
---@field maxAge number? -- oldest event in the tick, in frames before tick.frame
---@field units string?
---@field moves string?
---@field expl string?
---@field events string?
---@field proj string?
---@field pend string?
---@field hp string?
---@field bld string?
---@field dmg string?
---@field feat string?
---@field cam string?
---@field z string? -- zlib blob of all streams once the tick is cold
---@field basic boolean? -- coarse resident copy of a spilled tick

---@class PipHistoryStore
---@field opts table<string, any>
---@field isBuilding table<number, boolean>
---@field canFly table<number, boolean>
---@field beamWeapon table<number, boolean>
---@field projectileWeapon table<number, boolean>
---@field weaponRadius table<number, number>
---@field mapSizeX number
---@field mapSizeZ number
---@field ticks table<integer, PipHistoryTick> -- composed: per spilled segment its basic or loaded ticks, then hot
---@field hot table<integer, PipHistoryTick> -- detailed ticks still in memory (the tail of ticks)
---@field segments table<integer, table> -- spilled keyframe segments {first, last, count, file, bytes, basic, loaded, lastUse}
---@field job table<string, any>? -- running spill or load, advanced by Update()
---@field wantSeg integer? -- segment the viewer needs loaded
---@field useCounter number
---@field spillFailed boolean
---@field feeder integer? -- the PIP instance whose callins feed this store (set by the widget)
---@field keyTicks table<integer, integer>
---@field totalBytes number
---@field rawBytes number
---@field tickCount number
---@field lastTickFrame number
---@field generation number
---@field tX table<number, number>
---@field tZ table<number, number>
---@field tVX table<number, number>
---@field tVZ table<number, number>
---@field tF table<number, number?>
---@field tDef table<number, integer>
---@field tTeam table<number, integer>
---@field tFlags table<number, number?>
---@field tHp table<number, number?>
---@field tBld table<number, number?>
---@field tPrevX table<number, number>
---@field tPrevZ table<number, number>
---@field tPrevF table<number, number>
---@field tSeen table<number, number?>
---@field liveList table<integer, number>
---@field liveCount number
---@field bufs table<string, integer[]>
---@field lens table<string, number>
---@field eventMaxAge number
---@field pendingDeaths table<number, table<integer, number>>
---@field pendingDeathN number
---@field pendingExpl table<number, table<integer, number>>
---@field pendingExplN number
---@field pendingCmd table<number, table<integer, number>>
---@field pendingCmdN number
---@field pendingBeam table<number, table<integer, number|integer>>
---@field pendingBeamN number
---@field pendingEv table<number, table<integer, number>>
---@field pendingEvN number
---@field pendingDmgQ table<number, number?>
---@field pendingDmgF table<number, number>
---@field pendingDmgList table<integer, number>
---@field pendingDmgN number
---@field hpDirty table<number, boolean?>
---@field playerCameras (fun(): table<integer, table>?)?
---@field seenBeam table<number, number>
---@field pX table<number, number>
---@field pZ table<number, number>
---@field pVX table<number, number>
---@field pVZ table<number, number>
---@field pF table<number, number?>
---@field pW table<number, integer>
---@field pSeen table<number, number>
---@field pTracked number
---@field pidDef table<number, integer?>
---@field pidStamp table<number, number?>
---@field scanStamp number
---@field projStepNow number
---@field allyOfTeam table<number, integer>
---@field toleranceNow number
---@field explosionMinRadiusNow number
---@field projectileCapNow number
---@field stats table<string, any>
---@field savedToFile boolean
---@field thawCache table<PipHistoryTick, table<string, any>?>
---@field thawCount number
local Store = {}
Store.__index = Store

local storeDefaults = {
	tickFrames = 60, -- sample cadence in game frames
	keyframeTicks = 180, -- full snapshot every N ticks
	tolerance = 6, -- elmos of prediction drift before a unit is re-logged
	flyerTolerance = 0.5, -- tolerance factor for aircraft (fast, curving)
	hpStates = 16, -- health is kept as this many levels (a record only when the level changes)
	maxBytes = 16 * 1024 * 1024,
	autoDetail = true, -- scale tolerance / thresholds with the unit count
	logExplosions = true,
	logProjectiles = true,
	logCommands = true,
	explosionMinRadius = 8,
	explosionCap = 400, -- per tick
	projectileCap = 300, -- shells followed at once
	projectileStep = 5, -- projectile scan cadence in frames (within a tick)
	projectileTolerance = 2, -- elmos of course drift before a shell is re-logged
	commandCap = 200, -- per tick
	lookaheadTicks = 8, -- playback searches this far ahead for a unit's next record
	coldTicks = 240, -- ticks older than this are zlib-frozen
	maxLevel = 5, -- merge rounds before a segment is dropped whole (thinning fallback)
	spillEnabled = true, -- over the cap, spill the oldest keyframe segments to files instead of thinning
	spillBytes = 16 * 1024 * 1024, -- size a spill aims for (whole keyframe segments)
	basicLevel = 2, -- merge rounds for the resident basic copy of a spilled segment (2 = 4x coarser)
	loadedSegments = 2, -- detailed segments kept in memory at once (the viewed one + preload)
	loadChunkBytes = 2 * 1024 * 1024, -- file bytes read per frame while loading a segment
	spillTicksPerFrame = 8, -- ticks written per frame while spilling
	mergeStepsPerFrame = 4, -- basic-copy merges per frame while spilling
	preloadNext = true, -- also load the segment after the viewed one
	filePrefix = "", -- spill file path prefix ('' disables spilling)
	eventCap = 400, -- map marks, lines, erases and feature changes per tick
	damageCap = 400, -- hit records per tick (strongest kept)
	flashFrames = 12, -- a hit flashes its icon this long in playback
}

function PipHistory.newStore(opts)
	local self = setmetatable({}, Store)
	---@cast self PipHistoryStore
	self.opts = {}
	for k, v in pairs(storeDefaults) do
		self.opts[k] = v
	end
	self.isBuilding = {}
	self.canFly = {}
	self.beamWeapon = {}
	self.projectileWeapon = {}
	self.weaponRadius = {}
	self.mapSizeX = 0
	self.mapSizeZ = 0
	self:Configure(opts)
	self:Reset()
	return self
end

function Store:Configure(opts)
	if not opts then
		return
	end
	for k, v in pairs(opts) do
		if storeDefaults[k] ~= nil then
			self.opts[k] = v
		end
	end
	self.isBuilding = opts.isBuilding or self.isBuilding
	self.canFly = opts.canFly or self.canFly
	self.playerCameras = opts.playerCameras or self.playerCameras
	self.beamWeapon = opts.beamWeapon or self.beamWeapon
	self.projectileWeapon = opts.projectileWeapon or self.projectileWeapon
	self.weaponRadius = opts.weaponRadius or self.weaponRadius
	self.mapSizeX = opts.mapSizeX or self.mapSizeX
	self.mapSizeZ = opts.mapSizeZ or self.mapSizeZ
end

function Store:Reset()
	self.ticks = {}
	self.hot = self.ticks
	self.segments = {}
	self.job = nil
	self.wantSeg = nil
	self.useCounter = 0
	self.spillFailed = false
	self.keyTicks = {} -- tick indices that hold a full snapshot
	self.totalBytes = 0
	self.rawBytes = 0
	self.tickCount = 0
	self.lastTickFrame = -1
	self.generation = (self.generation or 0) + 1 -- views drop their caches when this changes
	-- per-unit tracks
	self.tX, self.tZ, self.tVX, self.tVZ, self.tF = {}, {}, {}, {}, {}
	self.tDef, self.tTeam, self.tFlags, self.tHp = {}, {}, {}, {}
	self.tBld = {}
	self.tPrevX, self.tPrevZ, self.tPrevF = {}, {}, {}
	self.tSeen = {}
	self.liveList = {}
	self.liveCount = 0
	-- pending stream buffers (element counts, not record counts)
	self.bufs, self.lens = {}, {}
	for i = 1, #STREAMS do
		self.bufs[STREAMS[i]] = {}
		self.lens[STREAMS[i]] = 0
	end
	self.eventMaxAge = 0
	self.pendingDeaths, self.pendingDeathN = {}, 0
	self.pendingExpl, self.pendingExplN = {}, 0
	self.pendingCmd, self.pendingCmdN = {}, 0
	self.pendingBeam, self.pendingBeamN = {}, 0
	self.pendingEv, self.pendingEvN = {}, 0
	self.pendingDmgQ, self.pendingDmgF, self.pendingDmgList, self.pendingDmgN = {}, {}, {}, 0
	self.hpDirty = {}
	self.seenBeam = {}
	self.pX, self.pZ, self.pVX, self.pVZ, self.pF, self.pW, self.pSeen = {}, {}, {}, {}, {}, {}, {}
	self.pidDef, self.pidStamp, self.scanStamp, self.projStepNow = {}, {}, 0, self.opts.projectileStep
	self.pTracked = 0
	self.allyOfTeam = {}
	self.toleranceNow = self.opts.tolerance
	self.explosionMinRadiusNow = self.opts.explosionMinRadius
	self.projectileCapNow = self.opts.projectileCap
	self.stats = {
		unitRecords = 0,
		moveRecords = 0,
		events = 0,
		projSamples = 0,
		hpRecords = 0,
		bldRecords = 0,
		dmgRecords = 0,
		featRecords = 0,
		scanMs = 0,
		compactions = 0,
		spills = 0,
		loads = 0,
		spilledBytes = 0,
		frozen = 0,
		projMs = 0,
		projSeen = 0,
	}
	self.thawCache = {}
	self.thawCount = 0
	self.savedToFile = false
end

function Store:GetRange()
	local ticks = self.ticks
	if #ticks == 0 then
		return nil, nil
	end
	return ticks[1].frame, ticks[#ticks].frame
end

function Store:GetStats()
	local s = self.stats
	s.bytes = self.totalBytes
	s.rawBytes = self.rawBytes
	s.ticks = #self.ticks
	s.keyframes = #self.keyTicks
	s.tracked = self.liveCount
	s.firstFrame, s.lastFrame = self:GetRange()
	s.hotBytes = self:HotBytes()
	s.segments = #self.segments
	local loaded = 0
	for i = 1, #self.segments do
		if self.segments[i].loaded then
			loaded = loaded + 1
		end
	end
	s.loadedSegments = loaded
	s.job = self.job and self.job.kind or nil
	return s
end

-- Cold ticks keep one zlib blob instead of their streams ----------------------------------------

local function tickRawBytes(t)
	local n = 0
	for i = 1, #STREAMS do
		local s = t[STREAMS[i]]
		if s then
			n = n + #s
		end
	end
	return n
end

function Store:Freeze(t)
	if t.z or not zlibCompress then
		return
	end
	local parts = {}
	local lens = {}
	for i = 1, #STREAMS do
		local s = t[STREAMS[i]] or ""
		parts[i] = s
		lens[i] = #s
	end
	local raw = table.concat(lens, " ") .. "\n" .. table.concat(parts)
	local ok, z = pcall(zlibCompress, raw)
	if not ok or not z then
		return
	end
	local before = t.bytes
	for i = 1, #STREAMS do
		t[STREAMS[i]] = nil
	end
	t.z = z
	t.bytes = TICK_OVERHEAD + #z
	self.totalBytes = self.totalBytes + t.bytes - before
	self.stats.frozen = self.stats.frozen + 1
end

-- The streams of a tick (the tick itself while raw, a cached thaw once frozen)
function Store:Streams(t)
	if not t.z then
		return t
	end
	local cache = self.thawCache
	local hit = cache[t]
	if hit then
		return hit
	end
	local raw = zlibDecompress(t.z) or ""
	local nl = raw:find("\n", 1, true) or 1
	local lens = {} ---@type number[]
	for v in raw:sub(1, nl - 1):gmatch("%d+") do
		lens[#lens + 1] = tonumber(v)
	end
	local out = {}
	local pos = nl + 1
	for i = 1, #STREAMS do
		local n = lens[i] or 0
		if n > 0 then
			out[STREAMS[i]] = raw:sub(pos, pos + n - 1)
			pos = pos + n
		end
	end
	if self.thawCount >= 160 then
		for k in pairs(cache) do
			cache[k] = nil
		end
		self.thawCount = 0
	end
	cache[t] = out
	self.thawCount = self.thawCount + 1
	return out
end

-- Callin feeders --------------------------------------------------------------------------------

function Store:OnUnitDestroyed(unitID, unitDefID, unitTeam, x, z, frame)
	local n = self.pendingDeathN + 1
	self.pendingDeathN = n
	local d = self.pendingDeaths[n] or {}
	self.pendingDeaths[n] = d
	d[1], d[2], d[3] = unitID, x or self.tPrevX[unitID] or 0, z or self.tPrevZ[unitID] or 0
	d[4], d[5], d[6] = unitDefID or 0, unitTeam or 0, frame
end

function Store:OnUnitTeamChanged(unitID, newTeam)
	if self.tSeen[unitID] then
		self.tTeam[unitID] = newTeam
		self.tFlags[unitID] = -1 -- force a record next tick
	end
end

function Store:OnExplosion(x, z, weaponDefID, flags, frame)
	if not self.opts.logExplosions then
		return
	end
	local radius = self.weaponRadius[weaponDefID] or 10
	if radius < self.explosionMinRadiusNow then
		return
	end
	local n = self.pendingExplN + 1
	self.pendingExplN = n
	local e = self.pendingExpl[n] or {}
	self.pendingExpl[n] = e
	e[1], e[2], e[3], e[4], e[5], e[6] = x, z, weaponDefID or 0, flags or 0, frame, radius
end

function Store:OnCommand(unitID, kind, x, z, targetID, queued, frame)
	if not self.opts.logCommands then
		return
	end
	local n = self.pendingCmdN + 1
	if n > self.opts.commandCap then
		return
	end
	self.pendingCmdN = n
	local c = self.pendingCmd[n] or {}
	self.pendingCmd[n] = c
	c[1], c[2], c[3], c[4], c[5], c[6] = unitID, kind + (queued and 256 or 0), x or 0, z or 0, targetID or 0, frame
end

-- Recording ---------------------------------------------------------------------------------------

local function pushUnit(self, uid, def, team, flags, x, z, vx, vz)
	local buf = self.bufs.units
	local n = self.lens.units
	buf[n + 1] = uid
	buf[n + 2] = def
	buf[n + 3] = team + flags * 256
	buf[n + 4] = clampU16(x)
	buf[n + 5] = clampU16(z)
	buf[n + 6] = quantV(vx)
	buf[n + 7] = quantV(vz)
	self.lens.units = n + UNIT_STRIDE
end

local function pushMove(self, uid, x, z, vx, vz)
	local buf = self.bufs.moves
	local n = self.lens.moves
	buf[n + 1] = uid
	buf[n + 2] = clampU16(x)
	buf[n + 3] = clampU16(z)
	buf[n + 4] = quantV(vx)
	buf[n + 5] = quantV(vz)
	self.lens.moves = n + MOVE_STRIDE
end

local function noteAge(self, age)
	if age > self.eventMaxAge then
		self.eventMaxAge = age
	end
end

local function pushExpl(self, x, z, wd, flags, age)
	local buf = self.bufs.expl
	local n = self.lens.expl
	buf[n + 1] = clampU16(x)
	buf[n + 2] = clampU16(z)
	buf[n + 3] = mathMin(wd, 4095) + mathMin(flags, 15) * 4096
	buf[n + 4] = clampU16(age)
	self.lens.expl = n + EXPL_STRIDE
	noteAge(self, age)
end

local function pushEvent(self, kind, a, b, c, d, e, age)
	local buf = self.bufs.events
	local n = self.lens.events
	buf[n + 1] = kind
	buf[n + 2] = clampU16(a)
	buf[n + 3] = clampU16(b)
	buf[n + 4] = clampU16(c)
	buf[n + 5] = clampU16(d)
	buf[n + 6] = clampU16(e)
	buf[n + 7] = clampU16(age)
	self.lens.events = n + EVENT_STRIDE
	noteAge(self, age)
end

local function pushHp(self, uid, level)
	local buf = self.bufs.hp
	local n = self.lens.hp
	buf[n + 1] = uid
	buf[n + 2] = level
	self.lens.hp = n + HP_STRIDE
end

local function pushBld(self, uid, level)
	local buf = self.bufs.bld
	local n = self.lens.bld
	buf[n + 1] = uid
	buf[n + 2] = level
	self.lens.bld = n + BLD_STRIDE
end

local function removeLive(self, uid)
	self.tSeen[uid] = nil
	self.tFlags[uid] = nil
	self.tF[uid] = nil
	self.tHp[uid] = nil
	self.tBld[uid] = nil
	self.hpDirty[uid] = nil
end

local function pushPending(self, kind, a, b, c, d, e, frame)
	local n = self.pendingEvN
	if n >= self.opts.eventCap then
		return
	end
	n = n + 1
	self.pendingEvN = n
	local ev = self.pendingEv[n] or {}
	self.pendingEv[n] = ev
	ev[1], ev[2], ev[3], ev[4], ev[5], ev[6], ev[7] = kind, a, b, c, d, e, frame
end

-- strength 0..1 (the live pip's flash intensity); one record per unit per tick, hits accumulate
function Store:OnUnitDamaged(unitID, strength, frame)
	local q = mathFloor(strength * 100 + 0.5)
	if q <= 0 then
		return
	end
	self.hpDirty[unitID] = true
	local old = self.pendingDmgQ[unitID]
	if old then
		self.pendingDmgQ[unitID] = mathMin(100, old + mathFloor(q * 0.5))
	else
		self.pendingDmgN = self.pendingDmgN + 1
		self.pendingDmgList[self.pendingDmgN] = unitID
		self.pendingDmgQ[unitID] = mathMin(100, q)
	end
	self.pendingDmgF[unitID] = frame
end

function Store:OnMapMark(playerID, teamID, isSpectator, x, z, frame)
	pushPending(self, EV_MARK, playerID, teamID + (isSpectator and 256 or 0), x, z, 0, frame)
end

function Store:OnMapLine(teamID, x1, z1, x2, z2, frame)
	pushPending(self, EV_MAPLINE, teamID, x1, z1, x2, z2, frame)
end

function Store:OnMapErase(x, z, radius, frame)
	pushPending(self, EV_ERASE, x, z, radius, 0, 0, frame)
end

-- heading in engine units (-32768..32767)
function Store:OnFeatureCreated(featureID, featureDefID, x, z, heading, frame)
	pushPending(self, FEAT_CREATED, featureID, featureDefID, x, z, heading + 32768, frame)
end

function Store:OnFeatureDestroyed(featureID, featureDefID, x, z, heading, frame)
	pushPending(self, FEAT_GONE, featureID, featureDefID, x, z, heading + 32768, frame)
end

local function currentDetail(self, unitCount)
	local o = self.opts
	if not o.autoDetail then
		self.toleranceNow = o.tolerance
		self.explosionMinRadiusNow = o.explosionMinRadius
		self.projectileCapNow = o.projectileCap
		return
	end
	-- early game: full detail; past ~1000 units, loosen up to 3x by 4000 units
	local f = mathMin(mathMax((unitCount - 1000) / 3000, 0), 1)
	self.toleranceNow = o.tolerance * (1 + 2 * f)
	self.explosionMinRadiusNow = o.explosionMinRadius * (1 + 3 * f)
	self.projectileCapNow = mathFloor(o.projectileCap * (1 - 0.4 * f))
end

local function pushProj(self, pid, wd, x, z, qvx, qvz, frame)
	local buf = self.bufs.proj
	local n = self.lens.proj
	buf[n + 1] = pid % 65536
	buf[n + 2] = wd
	buf[n + 3] = x
	buf[n + 4] = z
	buf[n + 5] = qvx
	buf[n + 6] = qvz
	buf[n + 7] = frame -- becomes an age at pack time
	self.lens.proj = n + PROJ_STRIDE
end

local function pushProjEnd(self, pid, age)
	local buf = self.bufs.pend
	local n = self.lens.pend
	buf[n + 1] = pid % 65536
	buf[n + 2] = clampU16(age)
	self.lens.pend = n + PEND_STRIDE
end

-- Whitelisted projectiles are dead-reckoned like units: a record at launch and whenever the
-- flight leaves its predicted course, an end marker once the shell is gone (scanned every
-- projectileStep frames); heavy beams are logged once per beam from owner to target.
function Store:SampleProjectiles(frame)
	local whitelist = self.projectileWeapon
	local beamWeapon = self.beamWeapon
	local spGetProjectileDefID = Spring.GetProjectileDefID
	local spGetProjectilePosition = Spring.GetProjectilePosition
	local spGetProjectileVelocity = Spring.GetProjectileVelocity
	local t0 = os.clock()
	local projectiles = Spring.GetProjectilesInRectangle(0, 0, self.mapSizeX, self.mapSizeZ, false, true) --[[@as table<integer, integer>]]
	local pX, pZ, pVX, pVZ, pF, pW, pSeen = self.pX, self.pZ, self.pVX, self.pVZ, self.pF, self.pW, self.pSeen
	local tracked = self.pTracked
	local cap = self.projectileCapNow
	local tol = self.opts.projectileTolerance
	local seenBeam = self.seenBeam
	-- a projectile keeps its weapon for its whole flight: the def is asked once per id and
	-- reused while the id stays in consecutive scans (bullets and lasers are the bulk of a
	-- battle's projectiles, and none of them are on the whitelist)
	local pidDef, pidStamp = self.pidDef, self.pidStamp
	local stamp = self.scanStamp + 1
	self.scanStamp = stamp
	local count = #projectiles
	for i = 1, count do
		local pid = projectiles[i]
		local wd
		if pidStamp[pid] == stamp - 1 then
			wd = pidDef[pid]
		else
			wd = spGetProjectileDefID(pid)
			pidDef[pid] = wd
		end
		pidStamp[pid] = stamp
		if wd and whitelist[wd] then
			local f0 = pF[pid]
			if f0 or tracked < cap then
				local px, _, pz = spGetProjectilePosition(pid)
				if px then
					local x, z = clampU16(px), clampU16(pz)
					local drift = true
					if f0 then
						local dt = frame - f0
						local err = mathAbs(x - (pX[pid] + pVX[pid] * dt)) + mathAbs(z - (pZ[pid] + pVZ[pid] * dt))
						drift = err > tol
						-- the id was recycled onto a new shell: close the old one first
						if wd ~= pW[pid] or err > 400 then
							pushProjEnd(self, pid, frame - pSeen[pid])
						end
					else
						tracked = tracked + 1
					end
					if drift then
						local vx, _, vz = spGetProjectileVelocity(pid)
						local qvx, qvz = quantV(vx or 0), quantV(vz or 0)
						pushProj(self, pid, wd, x, z, qvx, qvz, frame)
						pX[pid], pZ[pid], pF[pid], pW[pid] = x, z, frame, wd
						pVX[pid], pVZ[pid] = (qvx - V_BIAS) / V_SCALE, (qvz - V_BIAS) / V_SCALE
					end
					pSeen[pid] = frame
				end
			end
		elseif wd and beamWeapon[wd] and not seenBeam[pid] then
			seenBeam[pid] = frame
			local ownerID = Spring.GetProjectileOwnerID(pid)
			local ox, oz
			if ownerID then
				ox, _, oz = Spring.GetUnitPosition(ownerID)
			end
			if ox then
				local targetType, target = Spring.GetProjectileTarget(pid)
				local tx, tz
				if targetType == 117 and type(target) == "number" then -- 'u'
					tx, _, tz = Spring.GetUnitPosition(target)
				elseif targetType == 103 and type(target) == "table" then -- 'g'
					tx, tz = target[1], target[3]
				end
				if not tx then
					local px, _, pz = spGetProjectilePosition(pid)
					tx, tz = px, pz
				end
				if tx then
					local bn = self.pendingBeamN + 1
					self.pendingBeamN = bn
					local b = self.pendingBeam[bn] or {}
					self.pendingBeam[bn] = b
					b[1], b[2], b[3], b[4], b[5], b[6] = ox, oz, tx, tz, wd, frame
				end
			end
		end
	end
	self.pTracked = tracked
	if stamp % 60 == 0 then
		for pid, st in pairs(pidStamp) do
			if st ~= stamp then
				pidStamp[pid] = nil
				pidDef[pid] = nil
			end
		end
	end
	-- crowded battles are scanned less often; playback dead-reckons between records anyway
	local base = self.opts.projectileStep
	self.projStepNow = count > 3000 and base * 3 or (count > 1200 and base * 2 or base)
	local stats = self.stats
	stats.projSeen = count
	stats.projMs = stats.projMs + 0.1 * ((os.clock() - t0) * 1000 - stats.projMs)
end

-- Called every game frame by whichever PIP instance runs first; records at tickFrames cadence.
function Store:GameFrame(frame)
	local o = self.opts
	if o.logProjectiles and self.mapSizeX > 0 and frame % (self.projStepNow or o.projectileStep) == 0 then
		self:SampleProjectiles(frame)
	end
	if frame - self.lastTickFrame < o.tickFrames then
		return false
	end
	local t0 = os.clock()
	local isKey = (self.tickCount % o.keyframeTicks) == 0
	local tickStamp = self.tickCount + 1
	local prevStamp = self.tickCount

	local spGetAllUnits = Spring.GetAllUnits
	local spGetUnitDefID = Spring.GetUnitDefID
	local spGetUnitTeam = Spring.GetUnitTeam
	local spGetUnitBasePosition = Spring.GetUnitBasePosition
	local spGetUnitLosState = Spring.GetUnitLosState
	local spGetTeamAllyTeamID = Spring.GetTeamAllyTeamID
	local spGetUnitHealth = Spring.GetUnitHealth

	local allUnits = spGetAllUnits() --[[@as table<integer, integer>]]
	local unitCount = #allUnits
	currentDetail(self, unitCount)
	local tol = self.toleranceNow

	local myAlly = Spring.GetLocalAllyTeamID()
	local _, fullview = Spring.GetSpectatingState()
	local losChecks = not fullview

	local tX, tZ, tVX, tVZ, tF = self.tX, self.tZ, self.tVX, self.tVZ, self.tF
	local tDef, tTeam, tFlags, tHp = self.tDef, self.tTeam, self.tFlags, self.tHp
	local tBld = self.tBld
	local hpDirty = self.hpDirty
	local tPrevX, tPrevZ, tPrevF = self.tPrevX, self.tPrevZ, self.tPrevF
	local tSeen = self.tSeen
	local isBuilding = self.isBuilding
	local canFly = self.canFly
	local flyerTol = tol * o.flyerTolerance
	local hpTop = o.hpStates - 1
	local allyOfTeam = self.allyOfTeam
	local liveList, liveCount = self.liveList, self.liveCount
	local defCheckSlot = tickStamp % 8

	-- deaths reported since the last tick: exact position + frame, drop from tracks
	for i = 1, self.pendingDeathN do
		local d = self.pendingDeaths[i]
		local uid = d[1]
		local def = d[4] ~= 0 and d[4] or (tDef[uid] or 0)
		local team = d[5] ~= 0 and d[5] or (tTeam[uid] or 0)
		pushEvent(self, EV_DEATH, uid, d[2], d[3], def, team, frame - d[6])
		if tSeen[uid] then
			pushUnit(self, uid, def, team, F_DEAD + (isBuilding[def] and F_BUILDING or 0), d[2], d[3], frame - d[6], 0)
			removeLive(self, uid)
		end
	end
	self.pendingDeathN = 0

	for i = 1, unitCount do
		local uid = allUnits[i]
		local seen = tSeen[uid]
		local def = tDef[uid] ---@type integer?
		local isNew = (seen ~= prevStamp)
		if isNew or not def or uid % 8 == defCheckSlot then
			local liveDef = spGetUnitDefID(uid)
			if liveDef ~= def then
				def = liveDef
				tDef[uid] = def
				tTeam[uid] = spGetUnitTeam(uid) or 0
				isNew = true
			end
		end
		if def then
			local team = tTeam[uid]
			if not team then
				team = spGetUnitTeam(uid) or 0
				tTeam[uid] = team
			end
			-- a known structure does not move: its position and sight state are re-read on
			-- every 8th tick only (the bulk of a late game's units are structures)
			local bld = isBuilding[def]
			local quick = bld and not isNew and not isKey and uid % 8 ~= defCheckSlot and tF[uid] ~= nil
			local x, z
			if quick then
				x, z = tX[uid], tZ[uid]
			else
				x, _, z = spGetUnitBasePosition(uid)
			end
			if x and z then
				local flags = 0
				if bld then
					flags = F_BUILDING
				end
				if quick then
					flags = tFlags[uid] or flags
				elseif losChecks then
					local ally = allyOfTeam[team]
					if ally == nil then
						ally = spGetTeamAllyTeamID(team) or -1
						allyOfTeam[team] = ally
					end
					if ally ~= myAlly then
						local bits = spGetUnitLosState(uid, myAlly, true)
						if bits and bits % 2 == 0 then
							flags = flags + F_RADAR
						end
					end
				end

				local full = isNew or isKey or flags ~= tFlags[uid]
				local drift = false
				local vx, vz = 0.0, 0.0
				if not isNew and not bld then
					local pf = tPrevF[uid]
					local dtp = frame - pf
					if dtp > 0 then
						vx = (x - tPrevX[uid]) / dtp
						vz = (z - tPrevZ[uid]) / dtp
					end
					if not full then
						local dt = frame - (tF[uid] or frame)
						local px = tX[uid] + tVX[uid] * dt
						local pz = tZ[uid] + tVZ[uid] * dt
						if mathAbs(x - px) + mathAbs(z - pz) > (canFly[def] and flyerTol or tol) then
							drift = true
						end
					end
				end
				if full or drift then
					-- store the quantised velocity so prediction matches what playback extrapolates
					local qvx = (quantV(vx) - V_BIAS) / V_SCALE
					local qvz = (quantV(vz) - V_BIAS) / V_SCALE
					if full then
						pushUnit(self, uid, def, team, flags, x, z, qvx, qvz)
					else
						pushMove(self, uid, x, z, qvx, qvz)
					end
					tX[uid], tZ[uid], tVX[uid], tVZ[uid], tF[uid] = x, z, qvx, qvz, frame
					tFlags[uid] = flags
				end
				tPrevX[uid], tPrevZ[uid], tPrevF[uid] = x, z, frame

				-- health and build levels, logged when they change (keyframes restate the incomplete);
				-- polled only for units that were hit, are under construction, or every 8th tick (repairs)
				local bld = tBld[uid]
				local hp, maxHP, bp
				if isNew or isKey or hpDirty[uid] or (bld and bld < hpTop) or uid % 8 == defCheckSlot then
					hp, maxHP, _, _, bp = spGetUnitHealth(uid)
					hpDirty[uid] = nil
				end
				if bp then
					local level = mathMin(hpTop, mathMax(0, mathFloor(bp * hpTop + 0.5)))
					local last = tBld[uid]
					if level ~= last or (isKey and level < hpTop) then
						if not (last == nil and level >= hpTop) then
							pushBld(self, uid, level)
						end
						tBld[uid] = level
					end
				end
				if hp and maxHP and maxHP > 0 then
					local level = mathMin(hpTop, mathMax(0, mathFloor(hp / maxHP * hpTop + 0.5)))
					local last = tHp[uid]
					if level ~= last or (isKey and level < hpTop) then
						if not (last == nil and level >= hpTop) then
							pushHp(self, uid, level)
						end
						tHp[uid] = level
					end
				end

				if isNew then
					liveCount = liveCount + 1
					liveList[liveCount] = uid
				end
				tSeen[uid] = tickStamp
			end
		end
	end

	-- units that were live last tick but are gone now: vanish (or ghost for buildings)
	local w = 0
	for i = 1, liveCount do
		local uid = liveList[i]
		local seen = tSeen[uid]
		if seen == tickStamp then
			w = w + 1
			liveList[w] = uid
		elseif seen == prevStamp then
			local def = tDef[uid] or 0
			local flags = isBuilding[def] and (F_GHOST + F_BUILDING) or F_VANISH
			pushUnit(self, uid, def, tTeam[uid] or 0, flags, tPrevX[uid] or 0, tPrevZ[uid] or 0, 0, 0)
			removeLive(self, uid)
		end
	end
	for i = w + 1, liveCount do
		liveList[i] = nil
	end
	self.liveCount = w

	-- explosions: keep the biggest when over the per-tick cap
	local en = self.pendingExplN
	if en > 0 then
		local list = self.pendingExpl
		if en > o.explosionCap then
			local idx = {} ---@type table<integer, integer>
			for i = 1, en do
				idx[i] = i
			end
			table.sort(idx, function(a, b)
				return list[a][6] > list[b][6]
			end)
			for k = 1, o.explosionCap do
				local e = list[idx[k]]
				pushExpl(self, e[1], e[2], e[3], e[4], frame - e[5])
			end
		else
			for i = 1, en do
				local e = list[i]
				pushExpl(self, e[1], e[2], e[3], e[4], frame - e[5])
			end
		end
		self.pendingExplN = 0
	end

	for i = 1, self.pendingCmdN do
		local c = self.pendingCmd[i]
		pushEvent(self, EV_COMMAND, c[1], c[2], c[3], c[4], c[5], frame - c[6])
	end
	self.pendingCmdN = 0

	for i = 1, self.pendingBeamN do
		local b = self.pendingBeam[i]
		pushEvent(self, EV_BEAM, b[1], b[2], b[3], b[4], b[5], frame - b[6])
	end
	self.pendingBeamN = 0

	for i = 1, self.pendingEvN do
		local ev = self.pendingEv[i]
		local kind = ev[1]
		if kind == FEAT_CREATED or kind == FEAT_GONE then
			local fb = self.bufs.feat
			local fn = self.lens.feat
			fb[fn + 1], fb[fn + 2], fb[fn + 3] = kind, ev[2] % 65536, ev[3]
			fb[fn + 4], fb[fn + 5], fb[fn + 6], fb[fn + 7] = clampU16(ev[4]), clampU16(ev[5]), ev[6], frame - ev[7]
			self.lens.feat = fn + FEAT_STRIDE
		else
			pushEvent(self, kind, ev[2], ev[3], ev[4], ev[5], ev[6], frame - ev[7])
		end
	end
	self.pendingEvN = 0

	-- hits: the strongest kept under the cap
	local dn = self.pendingDmgN
	if dn > 0 then
		local list, q, f = self.pendingDmgList, self.pendingDmgQ, self.pendingDmgF
		if dn > o.damageCap then
			table.sort(list, function(a, b)
				return (q[a] or 0) > (q[b] or 0)
			end)
		end
		local buf = self.bufs.dmg
		local n = self.lens.dmg
		for i = 1, mathMin(dn, o.damageCap) do
			local uid = list[i]
			local age = frame - f[uid]
			buf[n + 1], buf[n + 2], buf[n + 3] = uid, q[uid], clampU16(age)
			n = n + DMG_STRIDE
			noteAge(self, age)
		end
		self.lens.dmg = n
		for i = 1, dn do
			local uid = list[i]
			q[uid], f[uid], list[i] = nil, nil, nil
		end
		self.pendingDmgN = 0
	end

	-- broadcast cameras: {playerID, x, z, distance, tilt, heading, isHeight} per player
	local cams = self.playerCameras and self.playerCameras()
	if cams then
		local buf = self.bufs.cam
		local n = self.lens.cam
		for i = 1, #cams do
			local c = cams[i]
			buf[n + 1] = c[1] % 256 + (c[7] and 256 or 0)
			buf[n + 2] = clampU16(c[2])
			buf[n + 3] = clampU16(c[3])
			buf[n + 4] = clampU16(c[4])
			buf[n + 5] = clampU16((c[5] + 3.1416) * 10000)
			buf[n + 6] = clampU16((c[6] + 3.1416) * 10000)
			n = n + CAM_STRIDE
		end
		self.lens.cam = n
	end
	local seenBeam = self.seenBeam
	for pid, f in pairs(seenBeam) do
		if frame - f > 90 then
			seenBeam[pid] = nil
		end
	end
	-- shells missing from the latest scan are gone; a keyframe restates the ones in flight
	local pF, pSeen = self.pF, self.pSeen
	local lastScan = frame - frame % (self.projStepNow or o.projectileStep)
	for pid, f0 in pairs(pF) do
		if pSeen[pid] < lastScan then
			pushProjEnd(self, pid, frame - pSeen[pid])
			pF[pid] = nil
			self.pTracked = self.pTracked - 1
		elseif isKey then
			pushProj(
				self,
				pid,
				self.pW[pid],
				self.pX[pid],
				self.pZ[pid],
				quantV(self.pVX[pid]),
				quantV(self.pVZ[pid]),
				f0
			)
		end
	end
	-- projectile records carry their absolute frame until now
	local pbuf = self.bufs.proj
	for i = PROJ_STRIDE, self.lens.proj, PROJ_STRIDE do
		pbuf[i] = mathFloor(mathMax(frame - pbuf[i], 0))
	end

	-- pack the tick
	local tick = { frame = frame, key = isKey, level = 0, maxAge = self.eventMaxAge }
	local bytes = TICK_OVERHEAD
	local bufs, lens, stats = self.bufs, self.lens, self.stats
	for i = 1, #STREAMS do
		local name = STREAMS[i]
		local n = lens[name]
		if n > 0 then
			trim(bufs[name], n)
			local str = packU16(bufs[name])
			tick[name] = str
			bytes = bytes + #str
			lens[name] = 0
		end
	end
	stats.unitRecords = stats.unitRecords + (tick.units and #tick.units / (UNIT_STRIDE * 2) or 0)
	stats.moveRecords = stats.moveRecords + (tick.moves and #tick.moves / (MOVE_STRIDE * 2) or 0)
	stats.events = stats.events
		+ (tick.expl and #tick.expl / (EXPL_STRIDE * 2) or 0)
		+ (tick.events and #tick.events / (EVENT_STRIDE * 2) or 0)
	stats.projSamples = stats.projSamples + (tick.proj and #tick.proj / (PROJ_STRIDE * 2) or 0)
	stats.hpRecords = stats.hpRecords + (tick.hp and #tick.hp / (HP_STRIDE * 2) or 0)
	stats.bldRecords = stats.bldRecords + (tick.bld and #tick.bld / (BLD_STRIDE * 2) or 0)
	stats.dmgRecords = stats.dmgRecords + (tick.dmg and #tick.dmg / (DMG_STRIDE * 2) or 0)
	stats.featRecords = stats.featRecords + (tick.feat and #tick.feat / (FEAT_STRIDE * 2) or 0)
	self.eventMaxAge = 0
	tick.bytes = bytes
	local ticks = self.ticks
	ticks[#ticks + 1] = tick
	if self.hot ~= ticks then
		self.hot[#self.hot + 1] = tick
	end
	if isKey then
		self.keyTicks[#self.keyTicks + 1] = #ticks
	end
	self.totalBytes = self.totalBytes + bytes
	self.rawBytes = self.rawBytes + bytes
	self.tickCount = tickStamp
	self.lastTickFrame = frame
	self.savedToFile = false

	-- freeze the raw tail that has gone cold (stops at the first already-frozen tick)
	for i = #ticks - o.coldTicks, 1, -1 do
		if ticks[i].z then
			break
		end
		self:Freeze(ticks[i])
	end

	if self:HotBytes() > o.maxBytes then
		if self:CanSpill() then
			self:StartSpill()
		elseif not self.job and (not o.spillEnabled or o.filePrefix == "" or self.spillFailed) then
			self:Compact()
		end
	end
	stats.scanMs = stats.scanMs + 0.1 * ((os.clock() - t0) * 1000 - stats.scanMs)
	return true
end

-- Compaction ---------------------------------------------------------------------------------------

-- Merge tick B (newer) into tick A (older) -> one tick stamped at B's frame.
function Store:MergeTicks(a, b)
	local fa, fb = a.frame, b.frame
	local shift = fb - fa
	local merged = { frame = fb, key = a.key or b.key, level = a.level, bytes = TICK_OVERHEAD }
	merged.maxAge = mathMax((a.maxAge or 0) + shift, b.maxAge or 0)
	local sa, sb = self:Streams(a), self:Streams(b)

	-- units and moves: later record wins per unit, A's positions re-based to B's frame
	local order, byId = {}, {}
	local function getRec(uid)
		local rec = byId[uid]
		if not rec then
			rec = { full = false }
			byId[uid] = rec
			order[#order + 1] = uid
		end
		return rec
	end
	local function addUnits(arr, rebase)
		if not arr then
			return
		end
		for i = 1, #arr, UNIT_STRIDE do
			local rec = getRec(arr[i])
			local tf = arr[i + 2]
			local flags = mathFloor(tf / 256)
			local x, z = arr[i + 3], arr[i + 4]
			local vx = (arr[i + 5] - V_BIAS) / V_SCALE
			local vz = (arr[i + 6] - V_BIAS) / V_SCALE
			if rebase and flags % (F_VANISH * 2) < F_VANISH and flags % (F_DEAD * 2) < F_DEAD then
				x = clampU16(x + vx * shift)
				z = clampU16(z + vz * shift)
			end
			rec.full, rec.def, rec.tf, rec.x, rec.z, rec.qvx, rec.qvz =
				true, arr[i + 1], tf, x, z, arr[i + 5], arr[i + 6]
		end
	end
	local function addMoves(arr, rebase)
		if not arr then
			return
		end
		for i = 1, #arr, MOVE_STRIDE do
			local rec = getRec(arr[i])
			local x, z = arr[i + 1], arr[i + 2]
			if rebase then
				x = clampU16(x + (arr[i + 3] - V_BIAS) / V_SCALE * shift)
				z = clampU16(z + (arr[i + 4] - V_BIAS) / V_SCALE * shift)
			end
			rec.x, rec.z, rec.qvx, rec.qvz = x, z, arr[i + 3], arr[i + 4]
		end
	end
	addUnits(unpackAll(sa.units), true)
	addMoves(unpackAll(sa.moves), true)
	addUnits(unpackAll(sb.units), false)
	addMoves(unpackAll(sb.moves), false)
	if #order > 0 then
		local uo, mo = {}, {} ---@type integer[], integer[]
		local un, mn = 0, 0
		for i = 1, #order do
			local uid = order[i]
			local rec = byId[uid]
			if rec.full then
				uo[un + 1], uo[un + 2], uo[un + 3], uo[un + 4], uo[un + 5], uo[un + 6], uo[un + 7] =
					uid, rec.def, rec.tf, rec.x, rec.z, rec.qvx, rec.qvz
				un = un + UNIT_STRIDE
			else
				mo[mn + 1], mo[mn + 2], mo[mn + 3], mo[mn + 4], mo[mn + 5] = uid, rec.x, rec.z, rec.qvx, rec.qvz
				mn = mn + MOVE_STRIDE
			end
		end
		if un > 0 then
			merged.units = packU16(uo)
		end
		if mn > 0 then
			merged.moves = packU16(mo)
		end
	end

	-- events with ages shifted; explosions likewise
	local function concatAged(strA, strB, stride)
		local ea, eb = unpackAll(strA), unpackAll(strB)
		if not ea and not eb then
			return nil
		end
		local out = {} ---@type integer[]
		local n = 0
		if ea then
			for i = 1, #ea, stride do
				for k = 0, stride - 2 do
					out[n + 1 + k] = ea[i + k]
				end
				out[n + stride] = clampU16(ea[i + stride - 1] + shift)
				n = n + stride
			end
		end
		if eb then
			for i = 1, #eb do
				out[n + i] = eb[i]
			end
		end
		return packU16(out)
	end
	merged.events = concatAged(sa.events, sb.events, EVENT_STRIDE)
	merged.expl = concatAged(sa.expl, sb.expl, EXPL_STRIDE)
	merged.proj = concatAged(sa.proj, sb.proj, PROJ_STRIDE)
	merged.pend = concatAged(sa.pend, sb.pend, PEND_STRIDE)

	merged.dmg = concatAged(sa.dmg, sb.dmg, DMG_STRIDE)
	merged.feat = concatAged(sa.feat, sb.feat, FEAT_STRIDE)
	merged.cam = sb.cam or sa.cam

	-- health and build levels: later value per unit
	local function laterPerUnit(strA, strB)
		local ha, hb = unpackAll(strA), unpackAll(strB)
		if not ha and not hb then
			return nil
		end
		local seen, ord = {}, {}
		local vals = {}
		for _, arr in ipairs({ ha or {}, hb or {} }) do
			for i = 1, #arr, HP_STRIDE do
				local uid = arr[i]
				if not seen[uid] then
					seen[uid] = true
					ord[#ord + 1] = uid
				end
				vals[uid] = arr[i + 1]
			end
		end
		local out = {} ---@type integer[]
		for i = 1, #ord do
			out[#out + 1] = ord[i]
			out[#out + 1] = vals[ord[i]]
		end
		return packU16(out)
	end
	merged.hp = laterPerUnit(sa.hp, sb.hp)
	merged.bld = laterPerUnit(sa.bld, sb.bld)

	merged.bytes = TICK_OVERHEAD + tickRawBytes(merged)
	return merged
end

function Store:RebuildKeyIndex()
	local keys = {}
	local total = 0.0
	for i = 1, #self.ticks do
		local t = self.ticks[i]
		total = total + t.bytes
		if t.key then
			keys[#keys + 1] = i
		end
	end
	self.keyTicks = keys
	self.totalBytes = total
end

-- Halve the sample density of the oldest segment that still has detail, or drop it entirely.
function Store:CompactOnce()
	local ticks = self.ticks
	local keys = self.keyTicks
	if #keys == 0 then
		return false
	end
	local segStart, segEnd = nil, 0
	for k = 1, #keys do
		local s = keys[k]
		local e = (keys[k + 1] or (#ticks + 1)) - 1
		if ticks[s].level < self.opts.maxLevel and e > s then
			segStart, segEnd = s, e
			break
		end
	end
	local out = {}
	if not segStart then
		-- every segment is fully coarsened: drop the oldest one (but keep the newest)
		if #keys < 2 then
			return false
		end
		for i = keys[2], #ticks do
			out[#out + 1] = ticks[i]
		end
	else
		for i = 1, segStart - 1 do
			out[#out + 1] = ticks[i]
		end
		local j = segStart
		while j <= segEnd do
			if j + 1 <= segEnd then
				local merged = self:MergeTicks(ticks[j], ticks[j + 1])
				self:Freeze(merged)
				out[#out + 1] = merged
				j = j + 2
			else
				out[#out + 1] = ticks[j]
				j = j + 1
			end
		end
		out[segStart].level = ticks[segStart].level + 1
		out[segStart].key = true
		for i = segEnd + 1, #ticks do
			out[#out + 1] = ticks[i]
		end
	end
	self.ticks = out
	self.hot = out
	self:RebuildKeyIndex()
	self.generation = self.generation + 1
	self.stats.compactions = self.stats.compactions + 1
	return true
end

function Store:Compact()
	local target = self.opts.maxBytes * 0.9
	local guard = 0
	while self.totalBytes > target and guard < 64 do
		if not self:CompactOnce() then
			break
		end
		guard = guard + 1
	end
end

-- Segment files ---------------------------------------------------------------------------------
-- Over the cap the oldest keyframe segments go to a file, one file per spill, and a coarse
-- "basic" copy (merged basicLevel rounds, big effect streams dropped) stays in memory so the
-- whole log always plays back. Seeking into a spilled range loads the file back in chunks;
-- until it lands the basic copy is what the viewer sees.

local function writeTick(f, t)
	local parts = {}
	local lens = {}
	if t.z then
		parts[1] = t.z
		lens[1] = #t.z
		for k = 2, #STREAMS do
			lens[k] = 0
		end
	else
		for k = 1, #STREAMS do
			local s = t[STREAMS[k]] or ""
			parts[k] = s
			lens[k] = #s
		end
	end
	f:write(
		string.format("%d %d %d %d %d ", t.frame, t.key and 1 or 0, t.level, t.maxAge or 0, t.z and 1 or 0),
		table.concat(lens, " "),
		"\n",
		table.concat(parts)
	)
end

-- Parses ticks from `data` starting at `pos`; returns the ticks and the end position.
local function parseTicks(data, pos, count, maxFrame)
	local ticks = {}
	for _ = 1, count do
		local nl = data:find("\n", pos, true)
		if not nl then
			break
		end
		local line = data:sub(pos, nl - 1)
		pos = nl + 1
		local nums = {}
		for v in line:gmatch("%d+") do
			nums[#nums + 1] = tonumber(v)
		end
		if #nums < 5 + #STREAMS then
			break
		end
		local frame = nums[1]
		if maxFrame and frame > maxFrame then
			break
		end
		local t = { frame = frame, key = nums[2] == 1, level = nums[3], maxAge = nums[4] }
		local isZ = nums[5] == 1
		local bytes = TICK_OVERHEAD
		for k = 1, #STREAMS do
			local n = mathFloor(nums[5 + k])
			if n > 0 then
				local s = data:sub(pos, pos + n - 1)
				pos = pos + n
				if isZ and k == 1 then
					t.z = s
				else
					t[STREAMS[k]] = s
				end
				bytes = bytes + n
			end
		end
		t.bytes = bytes
		ticks[#ticks + 1] = t
	end
	return ticks, pos
end

function Store:HotBytes()
	local hot = self.hot
	local total = 0.0
	for i = 1, #hot do
		total = total + hot[i].bytes
	end
	return total
end

-- The composed tick list: each spilled segment contributes its loaded or basic ticks, then hot.
function Store:Compose()
	local out = {}
	local segs = self.segments
	for i = 1, #segs do
		local seg = segs[i]
		local src = seg.loaded or seg.basic
		for k = 1, #src do
			out[#out + 1] = src[k]
		end
	end
	local hot = self.hot
	for k = 1, #hot do
		out[#out + 1] = hot[k]
	end
	self.ticks = out
	self:RebuildKeyIndex()
	self.generation = self.generation + 1
end

-- true when there is a complete keyframe segment older than the newest one and spilling works
function Store:CanSpill()
	local o = self.opts
	if not o.spillEnabled or o.filePrefix == "" or self.spillFailed or self.job then
		return false
	end
	local hot = self.hot
	local keys = 0
	for i = 1, #hot do
		if hot[i].key then
			keys = keys + 1
		end
	end
	return keys >= 2
end

function Store:StartSpill()
	local hot = self.hot
	local o = self.opts
	-- the oldest complete keyframe segments up to spillBytes (never the newest one)
	local lastKey = 0
	for i = #hot, 1, -1 do
		if hot[i].key then
			lastKey = i
			break
		end
	end
	local e, bytes = 0, 0
	for i = 1, lastKey - 1 do
		bytes = bytes + hot[i].bytes
		if hot[i + 1].key then
			e = i
			if bytes >= o.spillBytes then
				break
			end
		end
	end
	if e == 0 then
		return
	end
	local id = #self.segments + 1
	local path = o.filePrefix .. id .. ".bin"
	local f = io.open(path, "wb")
	if not f then
		self.spillFailed = true
		return
	end
	f:write(string.format("PIPSEG1\n%d\n%d\n%d\n", hot[1].frame, hot[e].frame, e))
	self.job =
		{ kind = "spill", file = f, path = path, count = e, written = 0, bytes = bytes, basic = nil, mergeRound = 0 }
end

-- one merge round of a tick list (pairs; the odd last tick stays)
local function mergeRound(self, list)
	local out = {}
	local j = 1
	while j <= #list do
		if j + 1 <= #list then
			out[#out + 1] = self:MergeTicks(list[j], list[j + 1])
			j = j + 2
		else
			out[#out + 1] = list[j]
			j = j + 1
		end
	end
	return out
end

local BASIC_DROP = { "expl", "dmg", "proj", "pend" }

function Store:StepSpill(job)
	local o = self.opts
	local hot = self.hot
	if job.written < job.count then
		local stop = mathMin(job.count, job.written + o.spillTicksPerFrame)
		for i = job.written + 1, stop do
			writeTick(job.file, hot[i])
		end
		job.written = stop
		return
	end
	if not job.basic then
		job.basic = {}
		for i = 1, job.count do
			job.basic[i] = hot[i]
		end
		job.mergeRound, job.mergePos, job.mergeOut = 0, 1, {}
		return
	end
	if job.mergeRound < o.basicLevel then
		-- one round in slices of mergeStepsPerFrame pairs
		local list, out = job.basic, job.mergeOut
		local steps = 0
		while job.mergePos <= #list and steps < o.mergeStepsPerFrame do
			local j = job.mergePos
			if j + 1 <= #list then
				out[#out + 1] = self:MergeTicks(list[j], list[j + 1])
				job.mergePos = j + 2
			else
				out[#out + 1] = list[j]
				job.mergePos = j + 1
			end
			steps = steps + 1
		end
		if job.mergePos > #list then
			job.basic, job.mergeOut, job.mergePos = out, {}, 1
			job.mergeRound = job.mergeRound + 1
		end
		return
	end
	-- finalize: strip the heavy streams from the basic copy, freeze it, swap it in
	local basic = job.basic
	local basicBytes = 0
	for i = 1, #basic do
		local t = basic[i]
		for k = 1, #BASIC_DROP do
			t[BASIC_DROP[k]] = nil
		end
		t.bytes = TICK_OVERHEAD + tickRawBytes(t)
		t.basic = true
		self:Freeze(t)
		basicBytes = basicBytes + t.bytes
	end
	basic[1].key = true
	job.file:close()
	self.useCounter = self.useCounter + 1
	self.segments[#self.segments + 1] = {
		first = hot[1].frame,
		last = hot[job.count].frame,
		count = job.count,
		file = job.path,
		bytes = job.bytes,
		basic = basic,
		loaded = nil,
		lastUse = self.useCounter,
	}
	local rest = {}
	for i = job.count + 1, #hot do
		rest[#rest + 1] = hot[i]
	end
	self.hot = rest
	self.job = nil
	self.stats.spills = self.stats.spills + 1
	self.stats.spilledBytes = self.stats.spilledBytes + job.bytes
	self.savedToFile = false
	self:Compose()
end

function Store:SegmentAt(frame)
	local segs = self.segments
	for i = 1, #segs do
		local seg = segs[i]
		if frame >= seg.first and frame <= seg.last then
			return i
		end
	end
	return nil
end

-- The viewer is at `frame`: make sure its segment (and the next one) is loaded or loading.
function Store:Want(frame)
	local idx = self:SegmentAt(frame)
	if not idx then
		self.wantSeg = nil
		return
	end
	local segs = self.segments
	self.useCounter = self.useCounter + 1
	segs[idx].lastUse = self.useCounter
	if not segs[idx].loaded then
		self.wantSeg = idx
	elseif self.opts.preloadNext and segs[idx + 1] and not segs[idx + 1].loaded then
		segs[idx + 1].lastUse = self.useCounter
		self.wantSeg = idx + 1
	else
		self.wantSeg = nil
	end
end

function Store:StartLoad(idx)
	local seg = self.segments[idx]
	local f = io.open(seg.file, "rb")
	if not f then
		seg.missing = true
		return
	end
	local magic = f:read("*l")
	f:read("*l")
	f:read("*l")
	local countLine = f:read("*l")
	if magic ~= "PIPSEG1" or not tonumber(countLine) then
		f:close()
		seg.missing = true
		return
	end
	self.job = { kind = "load", file = f, idx = idx, parts = {}, count = tonumber(countLine) }
end

function Store:StepLoad(job)
	local chunk = job.file:read(self.opts.loadChunkBytes)
	if chunk then
		job.parts[#job.parts + 1] = chunk
		return
	end
	job.file:close()
	local data = table.concat(job.parts)
	local ticks = parseTicks(data, 1, job.count, nil)
	local seg = self.segments[job.idx]
	if #ticks > 0 then
		ticks[1].key = true
		seg.loaded = ticks
		self.stats.loads = self.stats.loads + 1
	else
		seg.missing = true
	end
	self.job = nil
	-- keep at most loadedSegments detailed segments in memory
	local segs = self.segments
	local loaded = {}
	for i = 1, #segs do
		if segs[i].loaded then
			loaded[#loaded + 1] = i
		end
	end
	while #loaded > self.opts.loadedSegments do
		local oldest, oi = nil, 0
		for k = 1, #loaded do
			local s = segs[loaded[k]]
			if not oldest or s.lastUse < oldest.lastUse then
				oldest, oi = s, k
			end
		end
		oldest.loaded = nil
		table.remove(loaded, oi)
	end
	self:Compose()
end

-- Called every frame by the feeding PIP: advances the running spill or load by one slice.
function Store:Update()
	local job = self.job
	if job then
		if job.kind == "spill" then
			self:StepSpill(job)
		else
			self:StepLoad(job)
		end
		return
	end
	local want = self.wantSeg
	if want then
		local seg = self.segments[want]
		if seg and not seg.loaded and not seg.missing then
			self:StartLoad(want)
		end
		self.wantSeg = nil
	end
end

-- Segment ranges for the timeline: {first, last, loaded, loading}
function Store:SegmentRanges()
	local out = self.segmentRanges or {}
	self.segmentRanges = out
	local segs = self.segments
	local job = self.job
	for i = 1, #segs do
		local seg = segs[i]
		local r = out[i] or {}
		out[i] = r
		r.first, r.last, r.loaded = seg.first, seg.last, seg.loaded ~= nil
		r.loading = (job ~= nil and job.kind == "load" and job.idx == i) or self.wantSeg == i
	end
	for i = #segs + 1, #out do
		out[i] = nil
	end
	return out
end

-- Persistence across /luaui reload: hot ticks and the spilled segments' basic copies go to a
-- binary file in the write dir (the segment files themselves stay). Layout: "PIPHIST5", game id,
-- hot tick count, tick counter, segment count; per segment its file path, "first last count bytes
-- basicCount" and the basic ticks; then the hot ticks. A tick is a header line "frame key level
-- maxAge z n1..nN" followed by the raw bytes (the zlib blob when z is 1).
function Store:SaveToFile(path, gameID)
	local f = io.open(path, "wb")
	if not f then
		return false
	end
	local hot = self.hot
	local segs = self.segments
	f:write(string.format("PIPHIST5\n%s\n%d\n%d\n%d\n", tostring(gameID), #hot, self.tickCount, #segs))
	for i = 1, #segs do
		local seg = segs[i]
		f:write(string.format("%s\n%d %d %d %d %d\n", seg.file, seg.first, seg.last, seg.count, seg.bytes, #seg.basic))
		for k = 1, #seg.basic do
			writeTick(f, seg.basic[k])
		end
	end
	for i = 1, #hot do
		writeTick(f, hot[i])
	end
	f:close()
	self.savedToFile = true
	return true
end

-- Ticks past maxFrame are dropped: the same game id also names its replay.
function PipHistory.loadStore(path, opts, gameID, maxFrame)
	local f = io.open(path, "rb")
	if not f then
		return nil
	end
	local magic = f:read("*l")
	local id = f:read("*l")
	local countLine = f:read("*l")
	local tickLine = f:read("*l")
	local segLine = f:read("*l")
	local count = tonumber(countLine)
	local tickCount = tonumber(tickLine)
	local segCount = tonumber(segLine)
	if magic ~= "PIPHIST5" or id ~= tostring(gameID) or not count or not tickCount or not segCount then
		f:close()
		return nil
	end
	local data = f:read("*a") or ""
	f:close()
	local store = PipHistory.newStore(opts)
	local pos = 1
	for _ = 1, segCount do
		local nl = data:find("\n", pos, true)
		if not nl then
			break
		end
		local file = data:sub(pos, nl - 1)
		pos = nl + 1
		nl = data:find("\n", pos, true)
		if not nl then
			break
		end
		local nums = {}
		for v in data:sub(pos, nl - 1):gmatch("%d+") do
			nums[#nums + 1] = tonumber(v)
		end
		pos = nl + 1
		if #nums < 5 then
			break
		end
		local basic
		basic, pos = parseTicks(data, pos, nums[5], nil)
		if #basic > 0 and nums[2] <= maxFrame then
			store.segments[#store.segments + 1] = {
				first = nums[1],
				last = nums[2],
				count = nums[3],
				file = file,
				bytes = nums[4],
				basic = basic,
				loaded = nil,
				lastUse = 0,
			}
		end
	end
	local hot = parseTicks(data, pos, count, maxFrame)
	store.hot = hot
	if #hot == 0 and #store.segments == 0 then
		return nil
	end
	store:Compose()
	store.rawBytes = store.totalBytes
	local lastTick = store.ticks[#store.ticks]
	store.lastTickFrame = lastTick and lastTick.frame or -1
	-- the recorder starts with empty tracks, so its next tick must be a keyframe
	local kf = store.opts.keyframeTicks
	store.tickCount = math.ceil(tickCount / kf) * kf
	store.savedToFile = true
	return store
end

----------------------------------------------------------------------------------------------------
-- View (materialiser)
----------------------------------------------------------------------------------------------------

---@class PipHistoryView
---@field store PipHistoryStore
---@field generation number
---@field keyIdx integer?
---@field appliedTick integer
---@field uX table<number, number>
---@field uZ table<number, number>
---@field uVX table<number, number>
---@field uVZ table<number, number>
---@field uF table<number, number>
---@field uDef table<number, integer>
---@field uTeam table<number, integer>
---@field uFlags table<number, integer>
---@field uHealth table<number, number>
---@field uBuild table<number, number>
---@field ids table<integer, number>
---@field idCount integer
---@field present table<number, boolean>
---@field nX table<number, number>
---@field nZ table<number, number>
---@field nF table<number, number?>
---@field nDef table<number, integer>
---@field nSpan table<number, number>
---@field nDead table<number, number?>
---@field nVX table<number, number>
---@field nVZ table<number, number>
---@field nList table<integer, number>
---@field nCount integer
---@field nextFor integer
---@field nextGen number
---@field outCount integer
---@field outId table<integer, number>
---@field outX table<integer, number>
---@field outZ table<integer, number>
---@field outDef table<integer, integer>
---@field outTeam table<integer, integer>
---@field outFlags table<integer, integer>
---@field outHealth table<integer, number>
---@field outBuild table<integer, number>
---@field outFrame number?
---@field explosions table<integer, table>
---@field explosionCount integer
---@field deaths table<integer, table>
---@field deathCount integer
---@field commands table<integer, table>
---@field commandCount integer
---@field beams table<integer, table>
---@field beamCount integer
---@field projectiles table<integer, table>
---@field projectileCount integer
---@field sX table<number, number>
---@field sZ table<number, number>
---@field sVX table<number, number>
---@field sVZ table<number, number>
---@field sF table<number, number?>
---@field sW table<number, integer>
---@field sEnd table<number, number?>
---@field sList table<integer, number>
---@field sCount integer
---@field pendIdx integer
---@field pendGen number
---@field pendArr table<integer, integer>?
---@field pendEnds table<integer, integer>?
---@field pendOverride table<number, integer>
---@field pendEndAt table<number, number>
---@field eventCache table<integer, table<string, any>>
---@field flashes table<number, number?>
---@field flashList table<integer, number>
---@field flashCount integer
---@field marks table<integer, table>
---@field markCount integer
---@field lines table<integer, table>
---@field lineCount integer
---@field erases table<integer, table>
---@field ledger table<string, any>
---@field features table<integer, table>
---@field featureCount integer
---@field featureKey number
---@field cX table<number, number>
---@field cZ table<number, number>
---@field cH table<number, number>
---@field cRX table<number, number>
---@field cRY table<number, number>
---@field cF table<number, number?>
---@field cHF table<number, boolean>
---@field camIdx integer
---@field camGen number
---@field camArr table<integer, integer>?
local View = {}
View.__index = View

function PipHistory.newView(store)
	local self = setmetatable({}, View)
	---@cast self PipHistoryView
	self.store = store
	self.generation = -1
	self.keyIdx = nil
	self.appliedTick = 0
	self.uX, self.uZ, self.uVX, self.uVZ, self.uF = {}, {}, {}, {}, {}
	self.uDef, self.uTeam, self.uFlags = {}, {}, {}
	self.uHealth = {}
	self.uBuild = {}
	self.ids, self.idCount = {}, 0
	self.present = {}
	-- next record per unit (first record after the applied tick, within the lookahead)
	self.nX, self.nZ, self.nF, self.nDef, self.nSpan = {}, {}, {}, {}, {}
	self.nDead = {}
	self.nVX, self.nVZ = {}, {}
	self.nList, self.nCount = {}, 0
	self.nextFor, self.nextGen = -1, -1
	self.outCount = 0
	self.outId, self.outX, self.outZ, self.outDef, self.outTeam, self.outFlags = {}, {}, {}, {}, {}, {}
	self.outHealth = {}
	self.outBuild = {}
	self.outFrame = nil
	self.explosions, self.explosionCount = {}, 0
	self.deaths, self.deathCount = {}, 0
	self.commands, self.commandCount = {}, 0
	self.beams, self.beamCount = {}, 0
	self.projectiles, self.projectileCount = {}, 0
	-- shells: committed state from the applied ticks, plus the next tick's records (pend*)
	self.sX, self.sZ, self.sVX, self.sVZ, self.sF, self.sW, self.sEnd = {}, {}, {}, {}, {}, {}, {}
	self.sList, self.sCount = {}, 0
	self.pendIdx, self.pendGen = -1, -1
	self.pendOverride, self.pendEndAt = {}, {}
	self.eventCache = {} -- unpacked event ticks of the current window, by tick index
	self.flashes, self.flashList, self.flashCount = {}, {}, 0
	self.marks, self.markCount = {}, 0
	self.lines, self.lineCount = {}, 0
	self.erases = {}
	self.ledger = { gen = -1, scanned = 0, n = 0, entries = {}, open = {}, known = {} }
	self.features, self.featureCount, self.featureKey = {}, 0, 0
	self.cX, self.cZ, self.cH, self.cRX, self.cRY, self.cF, self.cHF = {}, {}, {}, {}, {}, {}, {}
	self.camIdx, self.camGen, self.camArr = -1, -1, nil
	return self
end

local function viewReset(self)
	for uid in pairs(self.present) do
		self.present[uid] = nil
	end
	self.idCount = 0
	self.appliedTick = 0
	local sF, sEnd = self.sF, self.sEnd
	for i = 1, self.sCount do
		local pid = self.sList[i]
		sF[pid] = nil
		sEnd[pid] = nil
	end
	self.sCount = 0
	for pid in pairs(self.cF) do
		self.cF[pid] = nil
	end
end

local function applyShells(self, s, frame)
	local sX, sZ, sVX, sVZ, sF, sW, sEnd = self.sX, self.sZ, self.sVX, self.sVZ, self.sF, self.sW, self.sEnd
	local arr = unpackAll(s.proj)
	if arr then
		local sList = self.sList
		for i = 1, #arr, PROJ_STRIDE do
			local pid = arr[i]
			local f0 = frame - arr[i + 6]
			if not sF[pid] then
				self.sCount = self.sCount + 1
				sList[self.sCount] = pid
			end
			-- an end at or before this record closed an earlier shell with the same id
			local e = sEnd[pid]
			if e and e <= f0 then
				sEnd[pid] = nil
			end
			sF[pid], sW[pid], sX[pid], sZ[pid] = f0, arr[i + 1], arr[i + 2], arr[i + 3]
			sVX[pid], sVZ[pid] = (arr[i + 4] - V_BIAS) / V_SCALE, (arr[i + 5] - V_BIAS) / V_SCALE
		end
	end
	local ends = unpackAll(s.pend)
	if ends then
		for i = 1, #ends, PEND_STRIDE do
			local pid = ends[i]
			local e = frame - ends[i + 1]
			local f0 = sF[pid]
			if f0 and e >= f0 then
				sEnd[pid] = e
			end
		end
	end
end

local function applyTick(self, store, tick)
	local s = store:Streams(tick)
	local frame = tick.frame
	local uX, uZ, uVX, uVZ, uF = self.uX, self.uZ, self.uVX, self.uVZ, self.uF
	local uDef, uTeam, uFlags = self.uDef, self.uTeam, self.uFlags
	local present, ids = self.present, self.ids
	local arr = unpackAll(s.units)
	if arr then
		for i = 1, #arr, UNIT_STRIDE do
			local uid = arr[i]
			local tf = arr[i + 2]
			uDef[uid] = arr[i + 1]
			uTeam[uid] = tf % 256
			uFlags[uid] = mathFloor(tf / 256)
			uX[uid] = arr[i + 3]
			uZ[uid] = arr[i + 4]
			uVX[uid] = (arr[i + 5] - V_BIAS) / V_SCALE
			uVZ[uid] = (arr[i + 6] - V_BIAS) / V_SCALE
			uF[uid] = frame
			if not present[uid] then
				present[uid] = true
				self.idCount = self.idCount + 1
				ids[self.idCount] = uid
			end
		end
	end
	local moves = unpackAll(s.moves)
	if moves then
		for i = 1, #moves, MOVE_STRIDE do
			local uid = moves[i]
			if present[uid] then
				uX[uid] = moves[i + 1]
				uZ[uid] = moves[i + 2]
				uVX[uid] = (moves[i + 3] - V_BIAS) / V_SCALE
				uVZ[uid] = (moves[i + 4] - V_BIAS) / V_SCALE
				uF[uid] = frame
			end
		end
	end
	local hp = unpackAll(s.hp)
	if hp then
		local uHealth = self.uHealth
		local scale = 100 / (store.opts.hpStates - 1)
		for i = 1, #hp - 1, HP_STRIDE do
			uHealth[hp[i]] = hp[i + 1] * scale
		end
	end
	local bld = unpackAll(s.bld)
	if bld then
		local uBuild = self.uBuild
		local scale = 1 / (store.opts.hpStates - 1)
		for i = 1, #bld - 1, BLD_STRIDE do
			uBuild[bld[i]] = bld[i + 1] * scale
		end
	end
	local cam = unpackAll(s.cam)
	if cam then
		local cX, cZ, cH, cRX, cRY, cF, cHF = self.cX, self.cZ, self.cH, self.cRX, self.cRY, self.cF, self.cHF
		for i = 1, #cam, CAM_STRIDE do
			local pid = cam[i] % 256
			cX[pid], cZ[pid], cH[pid] = cam[i + 1], cam[i + 2], cam[i + 3]
			cRX[pid], cRY[pid] = cam[i + 4] / 10000 - 3.1416, cam[i + 5] / 10000 - 3.1416
			cF[pid], cHF[pid] = frame, cam[i] >= 256
		end
	end
	applyShells(self, s, frame)
end

-- Bring the unit state up to `frame`; returns false when the log has nothing there.
function View:Materialize(frame)
	local store = self.store
	local ticks = store.ticks
	if #ticks == 0 then
		return false
	end
	local last = findTickIndex(ticks, frame)
	if last == 0 then
		return false
	end
	local keys = store.keyTicks
	local keyIdx = 0
	for k = #keys, 1, -1 do
		if keys[k] <= last then
			keyIdx = keys[k]
			break
		end
	end
	if keyIdx == 0 then
		keyIdx = 1
	end
	local incremental = store.generation == self.generation and self.keyIdx == keyIdx and self.appliedTick <= last
	if not incremental then
		viewReset(self)
		self.generation = store.generation
		self.keyIdx = keyIdx
		self.appliedTick = keyIdx - 1
	end
	for i = self.appliedTick + 1, last do
		applyTick(self, store, ticks[i])
	end
	self.appliedTick = last

	-- next record per unit, scanned a bounded number of ticks ahead (a keyframe restates everyone)
	local nX, nZ, nF, nDef, nSpan = self.nX, self.nZ, self.nF, self.nDef, self.nSpan
	local nDead = self.nDead
	local nVX, nVZ = self.nVX, self.nVZ
	if self.nextFor ~= last or self.nextGen ~= store.generation then
		local nList = self.nList
		for i = 1, self.nCount do
			nF[nList[i]] = nil
			nDead[nList[i]] = nil
		end
		local nCount = 0
		local stop = mathMin(#ticks, last + store.opts.lookaheadTicks)
		for k = 1, #keys do
			if keys[k] > last then
				stop = mathMin(stop, keys[k])
				break
			end
		end
		local uDef = self.uDef
		for i = last + 1, stop do
			local tick = ticks[i]
			local s = store:Streams(tick)
			local tf = tick.frame
			-- the change that caused a record happened inside the tick before it
			local span = mathMax(tf - ticks[i - 1].frame, 1)
			local arr = unpackAll(s.units)
			if arr then
				for j = 1, #arr, UNIT_STRIDE do
					local uid = arr[j]
					local tflags = mathFloor(arr[j + 2] / 256)
					if tflags % (F_DEAD * 2) >= F_DEAD and not nDead[uid] then
						-- the unit is gone from its death frame on, not from this tick's frame
						nDead[uid] = tf - (arr[j + 5] - V_BIAS) / V_SCALE
						if not nF[uid] then
							nCount = nCount + 1
							nList[nCount] = uid
							nF[uid] = tf
							nDef[uid] = -1
						end
					elseif not nF[uid] then
						nF[uid] = tf
						nX[uid] = arr[j + 3]
						nZ[uid] = arr[j + 4]
						nDef[uid] = arr[j + 1]
						nSpan[uid] = span
						nVX[uid] = (arr[j + 5] - V_BIAS) / V_SCALE
						nVZ[uid] = (arr[j + 6] - V_BIAS) / V_SCALE
						nCount = nCount + 1
						nList[nCount] = uid
					end
				end
			end
			local moves = unpackAll(s.moves)
			if moves then
				for j = 1, #moves, MOVE_STRIDE do
					local uid = moves[j]
					if not nF[uid] then
						nF[uid] = tf
						nX[uid] = moves[j + 1]
						nZ[uid] = moves[j + 2]
						nDef[uid] = uDef[uid] or 0
						nSpan[uid] = span
						nVX[uid] = (moves[j + 3] - V_BIAS) / V_SCALE
						nVZ[uid] = (moves[j + 4] - V_BIAS) / V_SCALE
						nCount = nCount + 1
						nList[nCount] = uid
					end
				end
			end
		end
		self.nCount = nCount
		self.nextFor = last
		self.nextGen = store.generation
	end

	-- output: dead-reckon from the applied record; when the next record is known, bend through
	-- it (cubic Hermite when records are dense, eased correction over the tick before it otherwise)
	local uX, uZ, uVX, uVZ, uF = self.uX, self.uZ, self.uVX, self.uVZ, self.uF
	local uDef, uTeam, uFlags = self.uDef, self.uTeam, self.uFlags
	local ids = self.ids
	local outId, outX, outZ, outDef, outTeam, outFlags =
		self.outId, self.outX, self.outZ, self.outDef, self.outTeam, self.outFlags
	local outHealth, uHealth = self.outHealth, self.uHealth
	local outBuild, uBuild = self.outBuild, self.uBuild
	local n = 0
	local nextFrame = ticks[last + 1] and ticks[last + 1].frame or frame
	local extrapTo = mathMin(frame, nextFrame)
	for i = 1, self.idCount do
		local uid = ids[i]
		local flags = uFlags[uid]
		local dead = nDead[uid]
		if flags % (F_VANISH * 2) < F_VANISH and flags % (F_DEAD * 2) < F_DEAD and not (dead and frame >= dead) then
			local def = uDef[uid]
			local f0 = uF[uid]
			local x, z = uX[uid], uZ[uid]
			local nf = nF[uid]
			local vx, vz = uVX[uid], uVZ[uid]
			if nf and nf > f0 and nDef[uid] == def then
				local dt = frame - f0
				local span = nSpan[uid]
				local dtn = nf - f0
				if dtn <= span * 2 then
					local t = dt / dtn
					local t2 = t * t
					local t3 = t2 * t
					local h00 = 2 * t3 - 3 * t2 + 1
					local h10 = (t3 - 2 * t2 + t) * dtn
					local h01 = 3 * t2 - 2 * t3
					local h11 = (t3 - t2) * dtn
					x = h00 * x + h10 * vx + h01 * nX[uid] + h11 * nVX[uid]
					z = h00 * z + h10 * vz + h01 * nZ[uid] + h11 * nVZ[uid]
				else
					x = x + vx * dt
					z = z + vz * dt
					local sBlend = (frame - (nf - span)) / span
					if sBlend > 0 then
						if sBlend > 1 then
							sBlend = 1
						end
						sBlend = sBlend * sBlend * (3 - 2 * sBlend)
						x = x + (nX[uid] - (uX[uid] + vx * dtn)) * sBlend
						z = z + (nZ[uid] - (uZ[uid] + vz * dtn)) * sBlend
					end
				end
			else
				local dt = extrapTo - f0
				x = x + vx * dt
				z = z + vz * dt
			end
			n = n + 1
			outId[n] = uid
			outX[n] = x
			outZ[n] = z
			outDef[n] = def
			outTeam[n] = uTeam[uid]
			outFlags[n] = flags
			outHealth[n] = uHealth[uid] or 100
			outBuild[n] = uBuild[uid] or 1
		end
	end
	self.outCount = n
	self.outFrame = frame
	return true
end

-- Events whose frame lies in (frame - window, frame]; fills explosions / deaths / commands / beams.
function View:CollectEvents(frame, window, flashSpan)
	local store = self.store
	local ticks = store.ticks
	self.explosionCount, self.deathCount, self.commandCount, self.beamCount = 0, 0, 0, 0
	if #ticks == 0 then
		return
	end
	local minFrame = frame - window
	local explMin = frame - 75 -- explosions and deaths draw for at most ~2.5 s
	local markMin = frame - 120
	local flashMin = frame - (flashSpan or store.opts.flashFrames)
	local first = findTickIndex(ticks, minFrame)
	if first == 0 then
		first = 1
	end
	local expl, deaths, cmds, beams = self.explosions, self.deaths, self.commands, self.beams
	local en, dn, cn, bn = 0, 0, 0, 0
	local marks, lines, erases = self.marks, self.lines, self.erases
	local mn, ln, rn = 0, 0, 0
	local flashes, flashList = self.flashes, self.flashList
	for i = 1, self.flashCount do
		local uid = flashList[i]
		if uid then
			flashes[uid] = nil
		end
		flashList[i] = nil
	end
	self.flashCount = 0
	local fn = 0
	local flashFrames = flashSpan or store.opts.flashFrames
	local cache = self.eventCache
	for k in pairs(cache) do
		if k < first then
			cache[k] = nil
		end
	end
	local gen = store.generation
	for i = first, #ticks do
		local tick = ticks[i]
		if tick.frame - (tick.maxAge or 0) > frame then
			break
		end
		local ce = cache[i]
		if not ce or ce.gen ~= gen or ce.tick ~= tick then
			local s = store:Streams(tick)
			ce = { gen = gen, tick = tick, ev = unpackAll(s.events), ex = unpackAll(s.expl), dm = unpackAll(s.dmg) }
			cache[i] = ce
		end
		local tf = tick.frame
		local ex = ce.ex
		if ex and tf >= explMin then
			for j = 1, #ex, EXPL_STRIDE do
				local ef = tf - ex[j + 3]
				if ef > minFrame and ef <= frame then
					en = en + 1
					local e = expl[en]
					if not e then
						e = {}
						expl[en] = e
					end
					local wf = ex[j + 2]
					e.x, e.z, e.weaponDefID, e.flags, e.frame = ex[j], ex[j + 1], wf % 4096, mathFloor(wf / 4096), ef
				end
			end
		end
		local dm = ce.dm
		if dm and tf >= flashMin then
			for j = 1, #dm, DMG_STRIDE do
				local age = frame - (tf - dm[j + 2])
				if age >= 0 and age < flashFrames then
					local uid = dm[j]
					local f = dm[j + 1] / 100 * (1 - age / flashFrames)
					local cur = flashes[uid]
					if not cur then
						fn = fn + 1
						flashList[fn] = uid
						flashes[uid] = f
					elseif f > cur then
						flashes[uid] = f
					end
				end
			end
		end
		local arr = ce.ev
		if arr then
			for j = 1, #arr, EVENT_STRIDE do
				local ef = tf - arr[j + 6]
				if ef > minFrame and ef <= frame then
					local kind = arr[j]
					if kind == EV_DEATH then
						if ef > explMin then
							dn = dn + 1
							local d = deaths[dn]
							if not d then
								d = {}
								deaths[dn] = d
							end
							d.unitID, d.x, d.z, d.defID, d.team, d.frame =
								arr[j + 1], arr[j + 2], arr[j + 3], arr[j + 4], arr[j + 5], ef
						end
					elseif kind == EV_COMMAND then
						cn = cn + 1
						local c = cmds[cn]
						if not c then
							c = {}
							cmds[cn] = c
						end
						local kq = arr[j + 2]
						c.unitID, c.kind, c.queued, c.x, c.z, c.targetID, c.frame =
							arr[j + 1], kq % 256, kq >= 256, arr[j + 3], arr[j + 4], arr[j + 5], ef
					elseif kind == EV_BEAM then
						bn = bn + 1
						local b = beams[bn]
						if not b then
							b = {}
							beams[bn] = b
						end
						b.ox, b.oz, b.tx, b.tz, b.weaponDefID, b.frame =
							arr[j + 1], arr[j + 2], arr[j + 3], arr[j + 4], arr[j + 5], ef
					elseif kind == EV_MARK and ef > markMin then
						mn = mn + 1
						local m = marks[mn]
						if not m then
							m = {}
							marks[mn] = m
						end
						local ts = arr[j + 2]
						m.playerID, m.teamID, m.isSpectator, m.x, m.z, m.frame =
							arr[j + 1], ts % 256, ts >= 256, arr[j + 3], arr[j + 4], ef
					elseif kind == EV_MAPLINE then
						ln = ln + 1
						local l = lines[ln]
						if not l then
							l = {}
							lines[ln] = l
						end
						l.teamID, l.x1, l.z1, l.x2, l.z2, l.frame =
							arr[j + 1], arr[j + 2], arr[j + 3], arr[j + 4], arr[j + 5], ef
					elseif kind == EV_ERASE then
						rn = rn + 1
						local r = erases[rn]
						if not r then
							r = {}
							erases[rn] = r
						end
						r.x, r.z, r.radius, r.frame = arr[j + 1], arr[j + 2], arr[j + 3], ef
					end
				end
			end
		end
	end
	-- a line is gone once an erase after it touches it
	local kept = 0
	for i = 1, ln do
		local l = lines[i]
		local erased = false
		for k = 1, rn do
			local r = erases[k]
			if r.frame > l.frame then
				local dx, dz = l.x2 - l.x1, l.z2 - l.z1
				local lenSq = dx * dx + dz * dz
				local t = 0
				if lenSq > 0 then
					t = mathMax(0, mathMin(1, ((r.x - l.x1) * dx + (r.z - l.z1) * dz) / lenSq))
				end
				local ex, ez = r.x - (l.x1 + dx * t), r.z - (l.z1 + dz * t)
				if ex * ex + ez * ez <= r.radius * r.radius then
					erased = true
					break
				end
			end
		end
		if not erased then
			kept = kept + 1
			lines[kept], lines[i] = l, lines[kept]
		end
	end
	self.explosionCount, self.deathCount, self.commandCount, self.beamCount = en, dn, cn, bn
	self.markCount, self.lineCount, self.flashCount = mn, kept, fn
end

-- Feature ledger: every feature the log saw appear or vanish, extended as ticks arrive.
-- A vanish without a matching appearance is a map feature (or one older than the log).
function View:UpdateFeatureLedger()
	local store = self.store
	local ticks = store.ticks
	local led = self.ledger
	if led.gen ~= store.generation then
		led.gen = store.generation
		led.scanned = 0
		led.n = 0
		for k in pairs(led.open) do
			led.open[k] = nil
		end
		for k in pairs(led.known) do
			led.known[k] = nil
		end
	end
	local entries, open, known = led.entries, led.open, led.known
	for i = led.scanned + 1, #ticks do
		local tick = ticks[i]
		local arr = unpackAll(store:Streams(tick).feat)
		if arr then
			local tf = tick.frame
			for j = 1, #arr, FEAT_STRIDE do
				local kind, fid = arr[j], arr[j + 1]
				local ef = tf - arr[j + 6]
				known[fid] = true
				local oi = open[fid]
				if kind == FEAT_GONE and oi then
					entries[oi].gone = ef
					open[fid] = nil
				else
					local n = led.n + 1
					led.n = n
					local e = entries[n] or {}
					entries[n] = e
					e.id, e.defID, e.x, e.z, e.heading = fid, arr[j + 2], arr[j + 3], arr[j + 4], arr[j + 5] - 32768
					if kind == FEAT_CREATED then
						e.created, e.gone = ef, nil
						open[fid] = n
					else
						e.created, e.gone = 0, ef
					end
				end
			end
		end
	end
	led.scanned = #ticks
end

-- Features present at `frame`; returns the set of feature ids the ledger covers, so a live
-- feature with a covered id is drawn from the ledger instead. `featureKey` changes with the list.
function View:CollectFeatures(frame)
	self:UpdateFeatureLedger()
	local led = self.ledger
	local out = self.features
	local n, key = 0, 0.0
	for i = 1, led.n do
		local e = led.entries[i]
		if e.created <= frame and (not e.gone or e.gone > frame) then
			n = n + 1
			out[n] = e
			key = key + e.id * 3 + e.created
		end
	end
	self.featureCount = n
	self.featureKey = key * 4 + n
	return led.known
end

-- A player's broadcast camera at `frame`: the applied sample, blended towards the next one.
-- Returns x, z, distance-or-height, tilt, heading, isHeight.
function View:CameraAt(playerID, frame)
	local store = self.store
	if self.outFrame ~= frame or self.generation ~= store.generation then
		if not self:Materialize(frame) then
			return nil
		end
	end
	local f0 = self.cF[playerID]
	if not f0 then
		return nil
	end
	local x, z, h = self.cX[playerID], self.cZ[playerID], self.cH[playerID]
	local rx, ry = self.cRX[playerID], self.cRY[playerID]
	local ticks = store.ticks
	local nextIdx = self.appliedTick + 1
	local tick = ticks[nextIdx] ---@type PipHistoryTick?
	if tick then
		if self.camIdx ~= nextIdx or self.camGen ~= store.generation then
			self.camArr = unpackAll(store:Streams(tick).cam)
			self.camIdx, self.camGen = nextIdx, store.generation
		end
		local arr = self.camArr
		if arr then
			for j = 1, #arr, CAM_STRIDE do
				if arr[j] % 256 == playerID then
					local t = mathMax(0, mathMin(1, (frame - f0) / mathMax(1, tick.frame - f0)))
					x = x + (arr[j + 1] - x) * t
					z = z + (arr[j + 2] - z) * t
					h = h + (arr[j + 3] - h) * t
					local nrx, nry = arr[j + 4] / 10000 - 3.1416, arr[j + 5] / 10000 - 3.1416
					rx = rx + (nrx - rx) * t
					local dy = (nry - ry + 3.1416) % 6.2832 - 3.1416
					ry = ry + dy * t
					break
				end
			end
		end
	end
	return x, z, h, rx, ry, self.cHF[playerID]
end

-- Shells in flight at `frame`, dead-reckoned from their latest record; a shell fades over
-- projectileStep frames past its end. Records of the tick after the applied one count as
-- soon as their frame has passed, so launches show without waiting for the next tick.
function View:CollectProjectiles(frame)
	local store = self.store
	local ticks = store.ticks
	if self.outFrame ~= frame or self.generation ~= store.generation then
		if not self:Materialize(frame) then
			self.projectileCount = 0
			return
		end
	end
	local step = store.opts.projectileStep
	local sX, sZ, sVX, sVZ, sF, sW, sEnd = self.sX, self.sZ, self.sVX, self.sVZ, self.sF, self.sW, self.sEnd
	local sList = self.sList
	local out = self.projectiles
	local n = 0
	local function emit(pid, wd, x, z, vx, vz, f0, e)
		local alpha = 1.0
		if e and frame > e then
			alpha = 1 - (frame - e) / (step + 1)
			if alpha <= 0 then
				return
			end
		end
		local dt = frame - f0
		n = n + 1
		local p = out[n]
		if not p then
			p = {}
			out[n] = p
		end
		p.id, p.weaponDefID, p.x, p.z, p.dirX, p.dirZ, p.alpha = pid, wd, x + vx * dt, z + vz * dt, vx, vz, alpha
	end

	-- the next tick's records, taken up to the frame
	local nextIdx = self.appliedTick + 1
	local nextTick = ticks[nextIdx] ---@type PipHistoryTick?
	local pendArr, pendEnds = nil, nil
	if nextTick then
		if self.pendIdx ~= nextIdx or self.pendGen ~= store.generation then
			local s = store:Streams(nextTick)
			self.pendArr, self.pendEnds = unpackAll(s.proj), unpackAll(s.pend)
			self.pendIdx, self.pendGen = nextIdx, store.generation
		end
		pendArr, pendEnds = self.pendArr, self.pendEnds
	end
	local nf = nextTick and nextTick.frame or 0
	local override = self.pendOverride
	if pendArr then
		for i = 1, #pendArr, PROJ_STRIDE do
			if nf - pendArr[i + 6] <= frame then
				override[pendArr[i]] = i
			end
		end
	end
	local pendEnd = self.pendEndAt
	if pendEnds then
		for i = 1, #pendEnds, PEND_STRIDE do
			local e = nf - pendEnds[i + 1]
			if e <= frame then
				pendEnd[pendEnds[i]] = e
			end
		end
	end

	-- committed shells (ends long past are dropped; a scrub back inside the tick still finds them)
	local prune = frame - step - store.opts.tickFrames
	local w = 0
	for i = 1, self.sCount do
		local pid = sList[i]
		local e = sEnd[pid]
		if e and e < prune then
			sF[pid] = nil
			sEnd[pid] = nil
		else
			w = w + 1
			sList[w] = pid
			local f0, wd, x, z, vx, vz = sF[pid], sW[pid], sX[pid], sZ[pid], sVX[pid], sVZ[pid]
			local oi = override[pid]
			if oi then
				---@cast pendArr -?
				local of = nf - pendArr[oi + 6]
				if of >= f0 then
					f0, wd, x, z = of, pendArr[oi + 1], pendArr[oi + 2], pendArr[oi + 3]
					vx, vz = (pendArr[oi + 4] - V_BIAS) / V_SCALE, (pendArr[oi + 5] - V_BIAS) / V_SCALE
					e = nil
				end
				override[pid] = nil
			end
			local pe = pendEnd[pid]
			if pe and pe >= f0 and (not e or pe < e) then
				e = pe
			end
			emit(pid, wd, x, z, vx, vz, f0, e)
		end
	end
	for i = w + 1, self.sCount do
		sList[i] = nil
	end
	self.sCount = w
	-- shells that only exist in the next tick so far
	for pid, oi in pairs(override) do
		do
			---@cast pendArr -?
			local f0 = nf - pendArr[oi + 6]
			local pe = pendEnd[pid]
			if pe and pe < f0 then
				pe = nil
			end
			emit(
				pid,
				pendArr[oi + 1],
				pendArr[oi + 2],
				pendArr[oi + 3],
				(pendArr[oi + 4] - V_BIAS) / V_SCALE,
				(pendArr[oi + 5] - V_BIAS) / V_SCALE,
				f0,
				pe
			)
			override[pid] = nil
		end
	end
	for pid in pairs(pendEnd) do
		pendEnd[pid] = nil
	end
	self.projectileCount = n
end

return PipHistory
