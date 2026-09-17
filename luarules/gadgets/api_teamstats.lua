local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Team stats",
		desc = "Per-team economy, build power, conversion, unit composition, value traded and milestones: live on request, sampled into a history",
		author = "Floris",
		date = "September 2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

-- Unsynced on purpose. The unsynced half of LuaRules gets every unit event and reads
-- every team, so the tally, the history and the milestones are built here from the
-- same events the simulation runs on: the same on every client and in every replay,
-- without a byte through the synced state, the network or the replay file. LuaUI cannot
-- call into a gadget (its Script table reaches LuaUI alone), so the gadget serves it the
-- other way round: while a widget keeps a receiver registered it is handed the live
-- values every second, and a request for history is answered with the backlog. A widget
-- that is reloaded, or a player who resigned and may now see the other side, gets what
-- it may see within a second. Nothing is handed over while no widget asks.
--
-- Should a synced consumer ever need the numbers (an awards gadget computing in synced,
-- say), the tally takes only callin arguments and reads the same engine calls exist
-- synced, so it can run there as it is; the awards gadget could as well move its
-- accounting to this side, since its results only ever go to LuaUI.
if gadgetHandler:IsSyncedCode() then
	return
end

----------------------------------------------------------------
-- Configuration
----------------------------------------------------------------

-- Frames between two history samples: the engine's own team statistics period, so the
-- two histories line up sample for sample. Between samples the live values are read on
-- request and never stored.
local SAMPLE_PERIOD = 450

-- Frames between two hand-overs to LuaUI while a widget is listening: the responsive
-- number between two samples, read fresh each time and never stored.
local LIVE_PERIOD = 30

-- Energy counts at a sixtieth of metal in a unit's value, the game's usual exchange.
local ENERGY_PER_METAL = 60

-- What a unit counts as, from its def. Builders come before the rest so a constructor
-- with a gun is a builder; strategic and economy come before the medium split so a
-- floating nuke silo is strategic, not sea.
local BUCKETS = { "army", "air", "sea", "defense", "strategic", "factories", "builders", "economy", "utility" }

-- The moments worth remembering, and what marks them. `built` is tested on every unit
-- a team finishes and `lost` on every unit it loses; a milestone is kept once per team,
-- or every time when `every` is set. The unit that reached it is stored with it.
local MILESTONES = {
	{
		key = "factory",
		built = function(ud)
			return ud.isFactory
		end,
	},
	{
		key = "tech2",
		built = function(ud)
			return (tonumber(ud.customParams.techlevel) or 1) == 2
		end,
	},
	{
		key = "tech3",
		built = function(ud)
			return (tonumber(ud.customParams.techlevel) or 1) >= 3
		end,
	},
	{
		key = "nuke",
		built = function(ud)
			return ud.customParams.unitgroup == "nuke"
		end,
	},
	{
		key = "antinuke",
		built = function(ud)
			return ud.customParams.unitgroup == "antinuke"
		end,
	},
	{
		key = "lrpc",
		built = function(ud)
			return ud.customParams.islrpc ~= nil
		end,
	},
	{
		key = "commanderLost",
		lost = function(ud)
			return ud.customParams.iscommander ~= nil
		end,
		every = true,
	},
	{ key = "teamDied" },
}

----------------------------------------------------------------
-- What a sample holds
----------------------------------------------------------------

-- Every value a sample carries, in one fixed order. A live request returns the same
-- keys, read at that moment.
local SAMPLED = {
	"metalIncome",
	"metalExpense",
	"metalCurrent",
	"metalStorage",
	"energyIncome",
	"energyExpense",
	"energyCurrent",
	"energyStorage",
	"convCapacity",
	"convUse",
	"buildPower",
	"buildPowerActive",
	"unitCount",
	"unitValue",
	"killedValue",
	"killedArmyValue",
	"killedEcoValue",
	"lostValue",
	"teamKillValue",
	"comKills",
	"comLost",
}
local countKey, valueKey = {}, {}
for i = 1, #BUCKETS do
	local bucket = BUCKETS[i]
	local cap = bucket:sub(1, 1):upper() .. bucket:sub(2)
	countKey[bucket] = "count" .. cap
	valueKey[bucket] = "value" .. cap
	SAMPLED[#SAMPLED + 1] = countKey[bucket]
	SAMPLED[#SAMPLED + 1] = valueKey[bucket]
end

-- The keys the tally keeps as running counters; the rest of a sample is read live.
local TALLIED = {
	"unitCount",
	"unitValue",
	"buildPower",
	"killedValue",
	"killedArmyValue",
	"killedEcoValue",
	"lostValue",
	"teamKillValue",
	"comKills",
	"comLost",
}
for i = 1, #BUCKETS do
	TALLIED[#TALLIED + 1] = countKey[BUCKETS[i]]
	TALLIED[#TALLIED + 1] = valueKey[BUCKETS[i]]
end

----------------------------------------------------------------
-- Unit defs
----------------------------------------------------------------

local spGetTeamResources = Spring.GetTeamResources
local spGetTeamRulesParam = Spring.GetTeamRulesParam
local spGetUnitCurrentBuildPower = Spring.GetUnitCurrentBuildPower
local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local spGetGameFrame = Spring.GetGameFrame
local spGetMyAllyTeamID = Spring.GetMyAllyTeamID
local spGetSpectatingState = Spring.GetSpectatingState

---@type table<integer, number>
local defCost = {}
---@type table<integer, string>
local defBucket = {}
---@type table<integer, string>
local defCountKey = {}
---@type table<integer, string>
local defValueKey = {}
---@type table<integer, number?>
local defBuildSpeed = {}
---@type table<integer, boolean>
local defIsCommander = {}
---@type table<integer, table?>
local defBuiltMilestones = {}
---@type table<integer, table?>
local defLostMilestones = {}
---@type table<string, string?>
local killedAs = {
	army = "killedArmyValue",
	air = "killedArmyValue",
	sea = "killedArmyValue",
	defense = "killedArmyValue",
	strategic = "killedArmyValue",
	economy = "killedEcoValue",
}

local ARMED_GROUPS =
	{ weapon = true, aa = true, sub = true, emp = true, explo = true, weaponaa = true, weaponsub = true }
---@type table<string, boolean?>
local SEA_CLASSES = { BOAT = true, UBOAT = true, EPICSHIP = true }

local function bucketOf(ud)
	local cp = ud.customParams
	local group = cp.unitgroup or ""
	if ud.isFactory then
		return "factories"
	end
	if ud.isBuilder then
		return "builders"
	end
	if group == "nuke" or group == "antinuke" or cp.islrpc then
		return "strategic"
	end
	if group == "energy" or group == "metal" then
		return "economy"
	end
	if group == "util" then
		return "utility"
	end
	local armed = #ud.weapons > 0 or ARMED_GROUPS[group]
	if ud.speed == 0 then
		return armed and "defense" or "utility"
	end
	if ud.canFly then
		return "air"
	end
	local moveClass = ud.moveDef and ud.moveDef.name or ""
	if SEA_CLASSES[moveClass:match("^%u+") or ""] then
		return "sea"
	end
	return armed and "army" or "utility"
end

for unitDefID, ud in pairs(UnitDefs) do
	defCost[unitDefID] = ud.metalCost + ud.energyCost / ENERGY_PER_METAL
	local bucket = bucketOf(ud)
	defBucket[unitDefID] = bucket
	defCountKey[unitDefID] = countKey[bucket]
	defValueKey[unitDefID] = valueKey[bucket]
	if ud.buildSpeed > 0 and (ud.isBuilder or ud.isFactory) then
		defBuildSpeed[unitDefID] = ud.buildSpeed
	end
	defIsCommander[unitDefID] = ud.customParams.iscommander ~= nil
	for i = 1, #MILESTONES do
		local m = MILESTONES[i]
		if m.built and m.built(ud) then
			local list = defBuiltMilestones[unitDefID] or {}
			list[#list + 1] = m
			defBuiltMilestones[unitDefID] = list
		end
		if m.lost and m.lost(ud) then
			local list = defLostMilestones[unitDefID] or {}
			list[#list + 1] = m
			defLostMilestones[unitDefID] = list
		end
	end
end

----------------------------------------------------------------
-- State
----------------------------------------------------------------

-- [teamID] = the running counters, one per TALLIED key.
---@type table<integer, table<string, number>?>
local teams = {}
---@type table<integer, integer>
local allyOf = {}
-- [unitID] = the team a finished unit is counted for; a unit under construction is not
-- in here and counts for nothing until it is done.
---@type table<integer, integer?>
local finished = {}
-- [teamID][unitID] = build speed, for every finished builder and factory.
---@type table<integer, table<integer, number?>>
local builders = {}
-- [teamID] = { frames = { ... }, values = { [key] = { ... } } }, one entry per sample.
---@type table<integer, { frames: number[], values: table<string, number[]> }>
local history = {}
-- [teamID] = { { key, frame, unitDefID, unitID }, ... } in the order they were reached.
---@type table<integer, table[]>
local milestones = {}
local reached = {}
local dead = {}
local gameOver = false

local function newTally()
	local t = {}
	for i = 1, #TALLIED do
		t[TALLIED[i]] = 0
	end
	return t
end

local function newHistory()
	local h = { frames = {}, values = {} }
	for i = 1, #SAMPLED do
		h.values[SAMPLED[i]] = {}
	end
	return h
end

----------------------------------------------------------------
-- The tally
----------------------------------------------------------------

local function addUnit(unitID, unitDefID, teamID)
	local t = teams[teamID]
	if not t or finished[unitID] then
		return
	end
	finished[unitID] = teamID
	local cost = defCost[unitDefID]
	t.unitCount = t.unitCount + 1
	t.unitValue = t.unitValue + cost
	local ck, vk = defCountKey[unitDefID], defValueKey[unitDefID]
	t[ck] = t[ck] + 1
	t[vk] = t[vk] + cost
	local buildSpeed = defBuildSpeed[unitDefID]
	if buildSpeed then
		builders[teamID][unitID] = buildSpeed
		t.buildPower = t.buildPower + buildSpeed
	end
end

local function removeUnit(unitID, unitDefID)
	local teamID = finished[unitID]
	if not teamID then
		return
	end
	finished[unitID] = nil
	local t = teams[teamID]
	---@cast t -?
	local cost = defCost[unitDefID]
	t.unitCount = t.unitCount - 1
	t.unitValue = t.unitValue - cost
	local ck, vk = defCountKey[unitDefID], defValueKey[unitDefID]
	t[ck] = t[ck] - 1
	t[vk] = t[vk] - cost
	local buildSpeed = builders[teamID][unitID]
	if buildSpeed then
		builders[teamID][unitID] = nil
		t.buildPower = t.buildPower - buildSpeed
	end
end

local function markMilestone(teamID, m, unitDefID, unitID)
	if not m.every then
		if reached[teamID][m.key] then
			return
		end
		reached[teamID][m.key] = true
	end
	local list = milestones[teamID]
	list[#list + 1] = { key = m.key, frame = spGetGameFrame(), unitDefID = unitDefID, unitID = unitID }
end

----------------------------------------------------------------
-- Reading the live values
----------------------------------------------------------------

-- Fills `out` with every SAMPLED key for the team, as things stand right now: the
-- counters from the tally, the economy and the conversion from the engine, and the
-- build power in use from every builder's nano activity.
local function readLive(teamID, out)
	local t = teams[teamID]
	---@cast t -?
	local cur, storage, _, income, expense = spGetTeamResources(teamID, "metal")
	out.metalIncome = income or 0
	out.metalExpense = expense or 0
	out.metalCurrent = cur or 0
	out.metalStorage = storage or 0
	cur, storage, _, income, expense = spGetTeamResources(teamID, "energy")
	out.energyIncome = income or 0
	out.energyExpense = expense or 0
	out.energyCurrent = cur or 0
	out.energyStorage = storage or 0
	out.convCapacity = spGetTeamRulesParam(teamID, "mmCapacity") or 0
	out.convUse = spGetTeamRulesParam(teamID, "mmUse") or 0
	---@type number
	local active = 0
	for unitID, buildSpeed in pairs(builders[teamID]) do
		active = active + buildSpeed * (spGetUnitCurrentBuildPower(unitID) or 0)
	end
	out.buildPowerActive = active
	for i = 1, #TALLIED do
		local key = TALLIED[i]
		out[key] = t[key]
	end
	return out
end

local scratch = {}

local function sample(frame)
	for teamID, h in pairs(history) do
		if not dead[teamID] then
			readLive(teamID, scratch)
			local n = #h.frames + 1
			h.frames[n] = frame
			local values = h.values
			for i = 1, #SAMPLED do
				local key = SAMPLED[i]
				values[key][n] = scratch[key]
			end
		end
	end
end

----------------------------------------------------------------
-- Callins
----------------------------------------------------------------

local function unitCreated(unitID, unitDefID, unitTeam)
	if not spGetUnitIsBeingBuilt(unitID) then
		addUnit(unitID, unitDefID, unitTeam)
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	unitCreated(unitID, unitDefID, unitTeam)
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	addUnit(unitID, unitDefID, unitTeam)
	local list = defBuiltMilestones[unitDefID]
	if list and teams[unitTeam] then
		for i = 1, #list do
			markMilestone(unitTeam, list[i], unitDefID, unitID)
		end
	end
end

function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	if finished[unitID] then
		removeUnit(unitID, unitDefID)
		addUnit(unitID, unitDefID, newTeam)
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	local value = defCost[unitDefID]
	if not finished[unitID] then
		-- A unit still under construction is worth what was put into it.
		local _, progress = spGetUnitIsBeingBuilt(unitID)
		value = value * (progress or 0)
	end
	removeUnit(unitID, unitDefID)

	local victim = teams[unitTeam]
	if victim then
		victim.lostValue = victim.lostValue + value
		if defIsCommander[unitDefID] then
			victim.comLost = victim.comLost + 1
		end
		local list = defLostMilestones[unitDefID]
		if list then
			for i = 1, #list do
				markMilestone(unitTeam, list[i], unitDefID, unitID)
			end
		end
	end

	local killer = attackerTeam and teams[attackerTeam]
	if not killer or attackerTeam == unitTeam or value == 0 then
		return
	end
	if allyOf[attackerTeam] == allyOf[unitTeam] then
		killer.teamKillValue = killer.teamKillValue + value
		return
	end
	killer.killedValue = killer.killedValue + value
	local split = killedAs[defBucket[unitDefID]]
	if split then
		killer[split] = killer[split] + value
	end
	if defIsCommander[unitDefID] then
		killer.comKills = killer.comKills + 1
	end
end

function gadget:TeamDied(teamID)
	if not teams[teamID] or dead[teamID] then
		return
	end
	dead[teamID] = true
	for i = 1, #MILESTONES do
		if MILESTONES[i].key == "teamDied" then
			markMilestone(teamID, MILESTONES[i])
		end
	end
end

-- The last sample is the state at the end: what happens in the minutes after is not
-- the game.
function gadget:GameOver()
	if gameOver then
		return
	end
	gameOver = true
	sample(spGetGameFrame())
end

----------------------------------------------------------------
-- What LuaUI may see
----------------------------------------------------------------

-- The same rule the engine applies to its own team statistics: a team's numbers are for
-- its allies, for a spectator watching everything, and for everyone once the game is
-- over. A spectator watching one side sees that side.
local function visible(teamID)
	if not teams[teamID] then
		return false
	end
	if gameOver then
		return true
	end
	local spec, fullView = spGetSpectatingState()
	if spec and fullView then
		return true
	end
	return allyOf[teamID] == spGetMyAllyTeamID()
end

local function copyMilestones(teamID)
	local out = {}
	local list = milestones[teamID]
	for i = 1, #list do
		local m = list[i]
		out[i] = { key = m.key, frame = m.frame, unitDefID = m.unitDefID, unitID = m.unitID }
	end
	return out
end

local function liveOf(teamID)
	local out = readLive(teamID, {})
	out.dead = dead[teamID] or false
	out.milestones = copyMilestones(teamID)
	return out
end

-- The values as they stand right now, for one team or for every team the caller may
-- see, keyed by team. Read fresh on every call and never stored: it is the responsive
-- number between two samples.
local function GetTeamStatsLive(teamID)
	if teamID ~= nil then
		if not visible(teamID) then
			return nil
		end
		return liveOf(teamID)
	end
	local out = {}
	for id in pairs(teams) do
		if visible(id) then
			out[id] = liveOf(id)
		end
	end
	return out
end

-- The samples from `from` (1 by default) on: the frames they were taken at and each
-- value's run, so a caller with the first n only asks for what came after them.
local function GetTeamStatsHistory(teamID, from)
	if not visible(teamID) then
		return nil
	end
	from = math.max(1, from or 1)
	local h = history[teamID]
	local out = { period = SAMPLE_PERIOD, from = from, frames = {}, values = {} }
	for n = from, #h.frames do
		out.frames[n - from + 1] = h.frames[n]
	end
	for i = 1, #SAMPLED do
		local key = SAMPLED[i]
		local run, src = {}, h.values[key]
		for n = from, #src do
			run[n - from + 1] = src[n]
		end
		out.values[key] = run
	end
	return out
end

local function GetTeamStatsMilestones(teamID)
	if not visible(teamID) then
		return nil
	end
	return copyMilestones(teamID)
end

-- What the numbers mean: the sample period, the keys in their order, the buckets and
-- the milestone kinds, so a caller need not hardcode them.
local function GetTeamStatsInfo()
	local kinds = {}
	for i = 1, #MILESTONES do
		kinds[i] = MILESTONES[i].key
	end
	local keys = {}
	for i = 1, #SAMPLED do
		keys[i] = SAMPLED[i]
	end
	local buckets = {}
	for i = 1, #BUCKETS do
		buckets[i] = BUCKETS[i]
	end
	return {
		period = SAMPLE_PERIOD,
		keys = keys,
		buckets = buckets,
		milestones = kinds,
		energyPerMetal = ENERGY_PER_METAL,
	}
end

-- For other unsynced gadgets, as globals.
local exports = {
	GetTeamStatsLive = GetTeamStatsLive,
	GetTeamStatsHistory = GetTeamStatsHistory,
	GetTeamStatsMilestones = GetTeamStatsMilestones,
	GetTeamStatsInfo = GetTeamStatsInfo,
}

----------------------------------------------------------------
-- Serving LuaUI
----------------------------------------------------------------

-- The engine's cross-state calls: Script.LuaUI.<name>(...) runs a global of the LuaUI
-- state, and Script.LuaUI("<name>") says whether there is one to run.
---@diagnostic disable-next-line: undefined-global
local Script = Script

-- A widget takes part by registering globals: `TeamStatsLive(all, frame)` is handed
-- the live values of every team the viewer may see, keyed by team, every LIVE_PERIOD
-- frames for as long as it is registered; `TeamStatsHistoryRequest()` returning
-- { [teamID] = fromIndex } is answered through `TeamStatsHistory(teamID, history)`
-- with the samples from that index on (see GetTeamStatsHistory for the shape), so a
-- caller holding the first n samples asks for what came after them.
local function serveLuaUI(frame)
	if Script.LuaUI("TeamStatsLive") then
		Script.LuaUI.TeamStatsLive(GetTeamStatsLive(), frame)
	end
	if Script.LuaUI("TeamStatsHistoryRequest") and Script.LuaUI("TeamStatsHistory") then
		local wanted = Script.LuaUI.TeamStatsHistoryRequest()
		if type(wanted) == "table" then
			for teamID, from in pairs(wanted) do
				local h = GetTeamStatsHistory(teamID, from)
				if h then
					Script.LuaUI.TeamStatsHistory(teamID, h)
				end
			end
		end
	end
end

function gadget:GameFrame(frame)
	if frame % SAMPLE_PERIOD == 0 and not gameOver then
		sample(frame)
	end
	if frame % LIVE_PERIOD == 0 then
		serveLuaUI(frame)
	end
end

function gadget:Initialize()
	local gaia = Spring.GetGaiaTeamID()
	local teamList = Spring.GetTeamList()
	---@cast teamList -?
	for _, teamID in ipairs(teamList) do
		if teamID ~= gaia then
			teams[teamID] = newTally()
			allyOf[teamID] = select(6, Spring.GetTeamInfo(teamID, false))
			builders[teamID] = {}
			history[teamID] = newHistory()
			milestones[teamID] = {}
			reached[teamID] = {}
			local _, _, isDead = Spring.GetTeamInfo(teamID, false)
			dead[teamID] = isDead == true or nil
		end
	end
	-- Units already standing, after a reload or when the game is joined late.
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		local unitDefID = Spring.GetUnitDefID(unitID)
		---@cast unitDefID -?
		unitCreated(unitID, unitDefID, Spring.GetUnitTeam(unitID))
	end
	for name, fn in pairs(exports) do
		gadgetHandler:RegisterGlobal(name, fn)
	end
end

function gadget:Shutdown()
	for name in pairs(exports) do
		gadgetHandler:DeregisterGlobal(name)
	end
end
