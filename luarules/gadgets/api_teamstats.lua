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
--
-- Reclaim is the one exception: which team took a feature's metal and energy only shows
-- on the synced side, in the step a builder takes on it. So a small synced half counts it
-- and leaves each team's running totals in a rules param, which the unsynced half reads
-- into its samples like the rest - still nothing through the network or the replay.
if gadgetHandler:IsSyncedCode() then
	local spGetFeatureResources = Spring.GetFeatureResources
	local spSetTeamRulesParam = Spring.SetTeamRulesParam
	local spGetGameFrame = Spring.GetGameFrame
	-- The unsynced half reads these for every team and gates them as it gates the rest.
	local PRIVATE = { private = true }
	-- [featureID] = what it held at the last reclaim step on it, and whose builder took it.
	---@type table<integer, { team: integer, metal: number, energy: number, frame: integer }?>
	local lastSeen = {}
	-- [teamID] = { metal, energy } taken so far, and which of them changed since the params
	-- were last set.
	---@type table<integer, { metal: number, energy: number }?>
	local reclaimed = {}
	---@type table<integer, boolean>
	local changed = {}

	local function credit(teamID, metal, energy)
		if metal <= 0 and energy <= 0 then
			return
		end
		local r = reclaimed[teamID] or { metal = 0, energy = 0 }
		reclaimed[teamID] = r
		r.metal = r.metal + math.max(0, metal)
		r.energy = r.energy + math.max(0, energy)
		changed[teamID] = true
	end

	-- A reclaim step, before it is taken: what the feature gave up since the step before
	-- went to that step's team. It is read off what the feature has left, so a gadget that
	-- changes the step's size is accounted for.
	function gadget:AllowFeatureBuildStep(builderID, builderTeam, featureID, featureDefID, step)
		if step >= 0 then
			return true
		end
		local metal, _, energy = spGetFeatureResources(featureID)
		if not metal then
			return true
		end
		local seen = lastSeen[featureID]
		if seen then
			credit(seen.team, seen.metal - metal, seen.energy - energy)
			seen.team, seen.metal, seen.energy, seen.frame = builderTeam, metal, energy, spGetGameFrame()
		else
			lastSeen[featureID] = { team = builderTeam, metal = metal, energy = energy, frame = spGetGameFrame() }
		end
		return true
	end

	-- Reclaimed away by a step of this very frame: what it had left went to that step's
	-- team. One burnt or blown up later gave nobody anything.
	function gadget:FeatureDestroyed(featureID)
		local seen = lastSeen[featureID]
		if seen then
			if seen.frame == spGetGameFrame() then
				credit(seen.team, seen.metal, seen.energy)
			end
			lastSeen[featureID] = nil
		end
	end

	function gadget:GameFrame(frame)
		if frame % 30 ~= 0 or not next(changed) then
			return
		end
		for teamID in pairs(changed) do
			local r = reclaimed[teamID]
			if r then
				spSetTeamRulesParam(teamID, "teamStatsReclaimedMetal", r.metal, PRIVATE)
				spSetTeamRulesParam(teamID, "teamStatsReclaimedEnergy", r.energy, PRIVATE)
			end
		end
		changed = {}
	end
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

-- A unit's tech level, 1 when it names none.
local function techOf(ud)
	return tonumber(ud.customParams.techlevel) or 1
end

-- What a power plant of the second tech level or above makes: the fusion reactors, not the
-- geothermal plants (which have milestones of their own) or anything that moves.
local function plantMakes(ud)
	local cp = ud.customParams
	if ud.speed ~= 0 or cp.geothermal or cp.iscommander or techOf(ud) < 2 then
		return 0
	end
	return ud.energyMake or 0
end
-- What a fusion reactor makes at the least, and an advanced one.
local FUSION_ENERGY = 500
local ADVANCED_FUSION_ENERGY = 2500

-- The moments worth remembering, and what marks them. `built` is tested on every unit
-- a team finishes (with the bucket it counts in) and `lost` on every unit it loses, and
-- the ones with neither are marked where they happen; a milestone is kept once per team,
-- or every time when `every` is set. The unit that reached it is stored with it.
local MILESTONES = {
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
	{ key = "firstKill" },
	{ key = "firstLoss" },
	-- The economy's steps: the first extractor of the second tech level, converter,
	-- advanced converter, fusion reactor, advanced one and geothermal plant.
	{
		key = "moho",
		built = function(ud)
			return (ud.extractsMetal or 0) > 0 and techOf(ud) >= 2
		end,
	},
	{
		key = "converter",
		built = function(ud)
			return ud.customParams.energyconv_capacity ~= nil
		end,
	},
	{
		key = "advConverter",
		built = function(ud)
			return ud.customParams.energyconv_capacity ~= nil and techOf(ud) >= 2
		end,
	},
	{
		key = "fusion",
		built = function(ud)
			return plantMakes(ud) >= FUSION_ENERGY
		end,
	},
	{
		key = "afus",
		built = function(ud)
			return plantMakes(ud) >= ADVANCED_FUSION_ENERGY
		end,
	},
	{
		key = "geo",
		built = function(ud)
			return ud.customParams.geothermal ~= nil
		end,
	},
	-- What the team grows into: the first radar tower, construction turret, aircraft and
	-- ship.
	{
		key = "radar",
		built = function(ud)
			return (ud.radarDistance or 0) > 0 and ud.speed == 0 and ud.customParams.unitgroup == "util"
		end,
	},
	{
		key = "nano",
		built = function(ud)
			return ud.isBuilder and not ud.isFactory and ud.speed == 0
		end,
	},
	{
		key = "air",
		built = function(_, bucket)
			return bucket == "air"
		end,
	},
	{
		key = "naval",
		built = function(_, bucket)
			return bucket == "sea"
		end,
	},
	-- Every time: an enemy commander killed, a nuke launched, a nuke come down on the team.
	{ key = "commanderKill", every = true },
	{ key = "nukeLaunched", every = true },
	{ key = "nuked", every = true },
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
	"buildPowerIdle",
	"unitCount",
	"unitValue",
	"killedValue",
	"killedArmyValue",
	"killedEcoValue",
	"lostValue",
	"teamKillValue",
	"comKills",
	"comLost",
	"actionsPerMinute",
	-- What the team's builders took from wrecks, rocks and trees, from the synced half.
	"metalReclaimed",
	"energyReclaimed",
	-- The wind is everyone's; every team's sample carries it, so a chart reads it off any.
	"windSpeed",
}
-- What the team's losses were lost to, as value, adding up to lostValue: enemies, its own
-- side's fire, lava or deep water, self-destruction, reclaim or a cancelled build, and the
-- rest (crashes and collisions, a transport or a factory going down with the unit in it,
-- a unit removed by the game).
local LOSS_CAUSES = { "lostEnemy", "lostFriendly", "lostWater", "lostSelfD", "lostReclaimed", "lostOther" }
for i = 1, #LOSS_CAUSES do
	SAMPLED[#SAMPLED + 1] = LOSS_CAUSES[i]
end
-- The map as each side holds it: the metal and geothermal spots its extractors and plants
-- stand on, how much of the map its units see and its radar covers (per cent, the ally
-- team's for every team in it), and how far toward the enemy its army stands (per cent of
-- the way from its team's start to the nearest enemy's, each unit weighing what it is
-- worth).
local MAP_KEYS = { "metalSpots", "geoSpots", "visionCoverage", "radarCoverage", "frontLine" }
-- Where the income comes from right now, per second: metal from extractors, converters,
-- reclaim and the rest (the commander, the game's gifts); energy from wind, solar, tidal,
-- geothermal and fusion plants, and the rest.
---@type string[]
local INCOME_METAL = { "incomeMex", "incomeConverters", "incomeReclaim", "incomeMetalOther" }
---@type string[]
local INCOME_ENERGY = { "incomeWind", "incomeSolar", "incomeTidal", "incomeGeo", "incomeFusion", "incomeEnergyOther" }
-- The value on the field by tech level, the third holding everything above it too.
local TECH_KEYS = { "valueT1", "valueT2", "valueT3" }
-- How much of the time the team had no energy left, and its metal and energy storage full
-- (per cent), as often as the income is read.
local STORAGE_KEYS = { "energyDry", "metalFull", "energyFull" }
-- What a pass of the scan finds for each team.
local PASS_KEYS = { INCOME_METAL, INCOME_ENERGY, STORAGE_KEYS }
for _, list in ipairs({ MAP_KEYS, INCOME_METAL, INCOME_ENERGY, TECH_KEYS, STORAGE_KEYS }) do
	for i = 1, #list do
		SAMPLED[#SAMPLED + 1] = list[i]
	end
end
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
	"buildPowerIdle",
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
for i = 1, #LOSS_CAUSES do
	TALLIED[#TALLIED + 1] = LOSS_CAUSES[i]
end
TALLIED[#TALLIED + 1] = "metalSpots"
TALLIED[#TALLIED + 1] = "geoSpots"
-- The metal spots held by an extractor that draws more than the least one does: an upgrade.
-- Live only, for what the count is made of.
TALLIED[#TALLIED + 1] = "metalSpotsUpgraded"
for i = 1, #TECH_KEYS do
	TALLIED[#TALLIED + 1] = TECH_KEYS[i]
end

-- The engine's own causes of death a loss is put down to, when no enemy did it; any other
-- cause with the team's own side behind it is friendly fire.
---@type table<integer, string>
local CAUSE_OF = {}
for name, key in pairs({
	Water = "lostWater",
	SelfD = "lostSelfD",
	Kamikaze = "lostSelfD",
	Reclaimed = "lostReclaimed",
	FactoryCancel = "lostReclaimed",
	ConstructionDecay = "lostReclaimed",
	TurnedIntoFeature = "lostReclaimed",
}) do
	local id = Game.envDamageTypes and Game.envDamageTypes[name]
	if id then
		CAUSE_OF[id] = key
	end
end
-- What the engine names when a gadget destroyed the unit, whatever it did that for.
local KILLED_BY_LUA = Game.envDamageTypes and Game.envDamageTypes.KilledByLua

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
local spGetWind = Spring.GetWind
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
local spGetUnitSelfDTime = Spring.GetUnitSelfDTime
local spGetUnitMoveTypeData = Spring.GetUnitMoveTypeData
local spGetGameRulesParam = Spring.GetGameRulesParam
local spGetAllFeatures = Spring.GetAllFeatures
local spGetFeatureDefID = Spring.GetFeatureDefID
local spGetFeaturePosition = Spring.GetFeaturePosition
local spGetPositionLosState = Spring.GetPositionLosState
local spGetTeamStartPosition = Spring.GetTeamStartPosition
local spGetUnitResources = Spring.GetUnitResources
local spGetGroundHeight = Spring.GetGroundHeight

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
---@type table<integer, boolean>
local defCanFly = {}
-- The buildings an upgrade is built over where they stand, the game handing their metal
-- back once it is done: metal extractors and geothermal plants. They are also what holds
-- a spot of the map.
---@type table<integer, string?>
local defSite = {}
-- The tech level key a unit's value is counted under.
---@type table<integer, string>
local defTechKey = {}
-- Where a producing unit's output is counted: the income key, and whether it makes metal
-- (else energy). A commander's and anything else's falls under the rest.
---@type table<integer, string?>
local defIncome = {}
---@type table<integer, boolean>
local defIncomeMetal = {}
-- The units whose place makes the front line: the army on land and at sea.
---@type table<integer, boolean>
local defArmy = {}
-- Extractors that draw more from their spot than the least one does.
---@type table<integer, boolean>
local defUpgraded = {}
-- Nuke silos, and their missiles' weapons with the silo that fires them.
---@type table<integer, boolean>
local defNuke = {}
---@type table<integer, integer>
local nukeWeapon = {}
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

-- The least any extractor draws.
local baseExtraction = math.huge
for _, ud in pairs(UnitDefs) do
	local draws = ud.extractsMetal or 0
	if draws > 0 and draws < baseExtraction then
		baseExtraction = draws
	end
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
	defCanFly[unitDefID] = ud.canFly == true
	if (ud.extractsMetal or 0) > 0 then
		defSite[unitDefID] = "metal"
	elseif ud.customParams.geothermal then
		defSite[unitDefID] = "geo"
	end
	local tech = math.floor(tonumber(ud.customParams.techlevel) or 1)
	tech = tech < 1 and 1 or (tech > 3 and 3 or tech)
	defTechKey[unitDefID] = TECH_KEYS[tech]
	local cp = ud.customParams
	if (ud.extractsMetal or 0) > 0 then
		defIncome[unitDefID], defIncomeMetal[unitDefID] = "incomeMex", true
	elseif cp.energyconv_capacity then
		defIncome[unitDefID], defIncomeMetal[unitDefID] = "incomeConverters", true
	elseif (ud.windGenerator or 0) > 0 then
		defIncome[unitDefID] = "incomeWind"
	elseif (ud.tidalGenerator or 0) > 0 then
		defIncome[unitDefID] = "incomeTidal"
	elseif cp.geothermal then
		defIncome[unitDefID] = "incomeGeo"
	elseif ((ud.energyMake or 0) > 0 or (ud.energyUpkeep or 0) < 0) and not cp.iscommander and ud.speed == 0 then
		-- Made outright, or as a negative upkeep, the way the solar collectors do it. What a
		-- ship or a commander makes is the rest's.
		defIncome[unitDefID] = tech >= 2 and "incomeFusion" or "incomeSolar"
	end
	defArmy[unitDefID] = bucket == "army" or bucket == "sea"
	defUpgraded[unitDefID] = (ud.extractsMetal or 0) > baseExtraction * 1.5
	if cp.unitgroup == "nuke" then
		defNuke[unitDefID] = true
		for _, weapon in ipairs(ud.weapons) do
			if type(weapon) == "table" and weapon.weaponDef then
				nukeWeapon[weapon.weaponDef] = unitDefID
			end
		end
	end
	for i = 1, #MILESTONES do
		local m = MILESTONES[i]
		if m.built and m.built(ud, bucket) then
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
-- [unitID] = the team whose fire last hurt an aircraft. A plane shot down falls for a while
-- and is then destroyed, by the ground or by the game, with no attacker named.
---@type table<integer, integer?>
local lastHitBy = {}
-- [teamID] = the frame a nuke last came down on the team: one explosion hurts many units,
-- over more than one frame, so hits this close together are the same one.
---@type table<integer, integer?>
local nukedAt = {}
local NUKE_FRAMES = 90

-- The metal and geothermal spots: the metal ones as the resource spot finder left them in
-- the game rules (none on a metal map), the geothermal ones off the map's vents. Read the
-- first time one is asked for; each keeps the extractor or plant that holds it.
---@type { metal: table[], geo: table[] }?
local spots = nil
-- [unitID] = the spot a finished extractor or plant holds.
---@type table<integer, table?>
local spotOf = {}
-- How far from a spot's middle a building on it may stand.
local SPOT_REACH = 80
local SPOT_KEY = { metal = "metalSpots", geo = "geoSpots" }

-- A set of units kept as an array too, so a scan can walk it a slice a frame; each unit
-- with what it is worth to the scan.
local function newRoster()
	return { list = {}, at = {}, what = {} }
end
local function enlist(roster, unitID, what)
	if roster.at[unitID] then
		return
	end
	local n = #roster.list + 1
	roster.list[n] = unitID
	roster.at[unitID] = n
	roster.what[unitID] = what
end
local function delist(roster, unitID)
	local i = roster.at[unitID]
	if not i then
		return
	end
	local list = roster.list
	local last = list[#list]
	list[i] = last
	roster.at[last] = i
	list[#list] = nil
	roster.at[unitID] = nil
	roster.what[unitID] = nil
end
-- The army, by value, for the front line; the producing units, by income key.
local army = newRoster()
local producers = newRoster()
-- [teamID] = where its first commander appeared: its start, for a team the game gave none
-- (an AI's can stay unset).
---@type table<integer, number[]?>
local commanderAt = {}

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

----------------------------------------------------------------
-- The map's spots
----------------------------------------------------------------

local function loadSpots()
	if spots then
		return spots
	end
	-- Not set yet by the spot finder: none for now, and asked again next time.
	local count = spGetGameRulesParam("mex_count")
	if count == nil then
		return { metal = {}, geo = {} }
	end
	local found = { metal = {}, geo = {} }
	for i = 1, count do
		local x, z = spGetGameRulesParam("mex_x" .. i), spGetGameRulesParam("mex_z" .. i)
		if x and z then
			found.metal[#found.metal + 1] = { x = x, z = z }
		end
	end
	local vents = {}
	for featureDefID, fd in pairs(FeatureDefs) do
		if fd.geoThermal then
			vents[featureDefID] = true
		end
	end
	local features = spGetAllFeatures()
	for i = 1, #features do
		if vents[spGetFeatureDefID(features[i])] then
			local x, _, z = spGetFeaturePosition(features[i])
			found.geo[#found.geo + 1] = { x = x, z = z }
		end
	end
	spots = found
	return found
end

-- A finished extractor or plant takes the spot under it, from the one it was built over
-- too: an upgrade's spot is the upgrade's.
local function claimSpot(unitID, kind, teamID, unitDefID)
	local x, _, z = spGetUnitPosition(unitID)
	if not x then
		return
	end
	local found = loadSpots()
	local list = kind == "metal" and found.metal or found.geo
	---@type table?
	local best = nil
	---@type number
	local bestD = SPOT_REACH * SPOT_REACH
	for i = 1, #list do
		local spot = list[i]
		---@cast spot -?
		local dx, dz = spot.x - x, spot.z - z
		local d = dx * dx + dz * dz
		if d <= bestD then
			best, bestD = spot, d
		end
	end
	if not best then
		return
	end
	local key = SPOT_KEY[kind]
	local before = best.holder
	if before and before ~= unitID then
		local held = finished[before] and teams[finished[before]]
		if held then
			held[key] = held[key] - 1
			if best.upgraded then
				held.metalSpotsUpgraded = held.metalSpotsUpgraded - 1
			end
		end
		spotOf[before] = nil
	end
	best.holder = unitID
	best.upgraded = defUpgraded[unitDefID] or nil
	spotOf[unitID] = best
	local t = teams[teamID]
	---@cast t -?
	t[key] = t[key] + 1
	if best.upgraded then
		t.metalSpotsUpgraded = t.metalSpotsUpgraded + 1
	end
end

local function releaseSpot(unitID, kind, teamID)
	local spot = spotOf[unitID]
	if not spot then
		return
	end
	spotOf[unitID] = nil
	if spot.holder == unitID then
		spot.holder = nil
		local t = teams[teamID]
		---@cast t -?
		local key = SPOT_KEY[kind]
		t[key] = t[key] - 1
		if spot.upgraded then
			t.metalSpotsUpgraded = t.metalSpotsUpgraded - 1
		end
		spot.upgraded = nil
	end
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
	local tk = defTechKey[unitDefID]
	t[tk] = t[tk] + cost
	local site = defSite[unitDefID]
	if site then
		claimSpot(unitID, site, teamID, unitDefID)
	end
	if defIsCommander[unitDefID] and not commanderAt[teamID] then
		local x, _, z = spGetUnitPosition(unitID)
		if x and (x > 0 or z > 0) then
			commanderAt[teamID] = { x, z }
		end
	end
	if defArmy[unitDefID] then
		enlist(army, unitID, cost)
	end
	if defIncome[unitDefID] then
		enlist(producers, unitID, unitDefID)
	end
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
	local site = defSite[unitDefID]
	if site then
		releaseSpot(unitID, site, teamID)
	end
	delist(army, unitID)
	delist(producers, unitID)
	finished[unitID] = nil
	local t = teams[teamID]
	---@cast t -?
	local cost = defCost[unitDefID]
	t.unitCount = t.unitCount - 1
	t.unitValue = t.unitValue - cost
	local ck, vk = defCountKey[unitDefID], defValueKey[unitDefID]
	t[ck] = t[ck] - 1
	t[vk] = t[vk] - cost
	local tk = defTechKey[unitDefID]
	t[tk] = t[tk] - cost
	local buildSpeed = builders[teamID][unitID]
	if buildSpeed then
		builders[teamID][unitID] = nil
		t.buildPower = t.buildPower - buildSpeed
	end
end

-- The milestones that are not read off a unit definition, by key.
local MILESTONE_BY_KEY = {}
for i = 1, #MILESTONES do
	MILESTONE_BY_KEY[MILESTONES[i].key] = MILESTONES[i]
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
-- The scan
----------------------------------------------------------------

-- Over each sampling period, a slice a frame, the scan looks at a grid of points over the
-- map for every ally team's sight and radar, at every army unit for where it stands, and at
-- every producing unit for what it makes; what a pass found is kept for the samples and the
-- live values until the next one is done. A pass takes a little less than a period, so
-- every sample finds a fresh one.
local PASS_FRAMES = SAMPLE_PERIOD - 30
-- The grid's points a side.
local GRID = 40
-- The teams' income is read this often over a pass, for what the rest made, and whether
-- their storage is empty or full.
local INCOME_EVERY = 15
-- Energy at or below this share of the storage is none left; metal or energy at or above
-- this one fills it.
local DRY_SHARE = 0.01
local FULL_SHARE = 0.99

---@type integer[]
local allyList = {}
---@type table<string, any>
local scan = {
	-- x, y, z of every point, made the first time
	---@type number[]?
	grid = nil,
	-- per ally team: its start, and the way to the enemy's start
	---@type table<integer, table>?
	bases = nil,
	left = 0,
	point = 1,
	armyAt = 1,
	producerAt = 1,
	pointQuota = 0,
	armyQuota = 0,
	producerQuota = 0,
	-- this pass so far
	---@type table<integer, number>
	seen = {},
	---@type table<integer, number>
	radar = {},
	---@type table<integer, number>
	weight = {},
	---@type table<integer, number>
	reach = {},
	---@type table<integer, table<string, number>>
	made = {},
	---@type table<integer, { metal: number, energy: number, n: integer, dry: integer, metalFull: integer, energyFull: integer }>
	income = {},
	---@type table<integer, number>
	reclaimedAt = {},
	-- the last pass's
	---@type table<integer, number>
	vision = {},
	---@type table<integer, number>
	radarCover = {},
	---@type table<integer, number>
	front = {},
	---@type table<integer, table<string, number>>
	sources = {},
}

local function loadGrid()
	local grid = {}
	local sx, sz = Game.mapSizeX / GRID, Game.mapSizeZ / GRID
	for i = 0, GRID - 1 do
		for j = 0, GRID - 1 do
			local x, z = (i + 0.5) * sx, (j + 0.5) * sz
			grid[#grid + 1] = x
			grid[#grid + 1] = spGetGroundHeight(x, z)
			grid[#grid + 1] = z
		end
	end
	return grid
end

-- Every team's start, and the way from it to the nearest enemy's - the map's middle when
-- there is none. By team rather than by side: allies can start far apart, and each pushes
-- from its own base. A team's start is the one the game gives it, else where its first
-- commander appeared; read again every pass, as a start can be set after the game began.
local function loadBases()
	local starts = {}
	for teamID in pairs(teams) do
		local x, _, z = spGetTeamStartPosition(teamID)
		if not (x and z and (x > 0 or z > 0)) then
			local at = commanderAt[teamID]
			x, z = at and at[1], at and at[2]
		end
		if x and z then
			starts[teamID] = { x = x, z = z }
		end
	end
	local bases = {}
	for teamID, a in pairs(starts) do
		---@type table?
		local nearest = nil
		local best = math.huge
		for other, o in pairs(starts) do
			if allyOf[other] ~= allyOf[teamID] then
				local d = (o.x - a.x) ^ 2 + (o.z - a.z) ^ 2
				if d < best then
					nearest, best = o, d
				end
			end
		end
		local ex, ez = Game.mapSizeX * 0.5, Game.mapSizeZ * 0.5
		if nearest then
			ex, ez = nearest.x, nearest.z
		end
		local dx, dz = ex - a.x, ez - a.z
		bases[teamID] = { x = a.x, z = a.z, dx = dx, dz = dz, len2 = dx * dx + dz * dz }
	end
	return bases
end

-- What the pass found, kept; and the next one begun.
local function finishPass()
	local points = scan.grid and #scan.grid / 3 or 0
	if points > 0 then
		for i = 1, #allyList do
			local ally = allyList[i]
			scan.vision[ally] = (scan.seen[ally] or 0) / points * 100
			scan.radarCover[ally] = (scan.radar[ally] or 0) / points * 100
			local weight = scan.weight[ally] or 0
			scan.front[ally] = weight > 0 and (scan.reach[ally] or 0) / weight * 100 or 0
		end
	end
	local seconds = PASS_FRAMES / 30
	for teamID in pairs(teams) do
		---@type table<string, number>
		local made = scan.made[teamID] or {}
		local income = scan.income[teamID]
		local metalIncome = income and income.n > 0 and income.metal / income.n or 0
		local energyIncome = income and income.n > 0 and income.energy / income.n or 0
		local reclaimed = spGetTeamRulesParam(teamID, "teamStatsReclaimedMetal") or 0
		local reclaimRate = math.max(0, (reclaimed - (scan.reclaimedAt[teamID] or reclaimed)) / seconds)
		scan.reclaimedAt[teamID] = reclaimed
		---@type table<string, number>
		local src = {}
		src.incomeMex = made.incomeMex or 0
		src.incomeConverters = made.incomeConverters or 0
		src.incomeReclaim = reclaimRate
		src.incomeMetalOther = math.max(0, metalIncome - src.incomeMex - src.incomeConverters - reclaimRate)
		---@type number
		local energy = 0
		for i = 1, #INCOME_ENERGY - 1 do
			local key = INCOME_ENERGY[i]
			---@cast key -?
			local v = made[key] or 0
			src[key] = v
			energy = energy + v
		end
		src.incomeEnergyOther = math.max(0, energyIncome - energy)
		local reads = income and income.n or 0
		src.energyDry = reads > 0 and income.dry / reads * 100 or 0
		src.metalFull = reads > 0 and income.metalFull / reads * 100 or 0
		src.energyFull = reads > 0 and income.energyFull / reads * 100 or 0
		scan.sources[teamID] = src
	end
	scan.seen, scan.radar, scan.weight, scan.reach, scan.made, scan.income = {}, {}, {}, {}, {}, {}
	scan.point, scan.armyAt, scan.producerAt = 1, 1, 1
	scan.pointQuota = math.ceil(points / PASS_FRAMES)
	scan.armyQuota = math.ceil(#army.list / PASS_FRAMES)
	scan.producerQuota = math.ceil(#producers.list / PASS_FRAMES)
	scan.left = PASS_FRAMES
end

local function scanStep(frame)
	if not scan.grid then
		scan.grid = loadGrid()
	end
	if scan.left <= 0 then
		finishPass()
		scan.bases = loadBases()
	end
	scan.left = scan.left - 1
	local grid = scan.grid
	---@cast grid -?
	-- Sight and radar at a few points, for every ally team.
	local points = #grid / 3
	for _ = 1, scan.pointQuota do
		local k = scan.point
		if k > points then
			break
		end
		scan.point = k + 1
		local x, y, z = grid[k * 3 - 2], grid[k * 3 - 1], grid[k * 3]
		for i = 1, #allyList do
			local ally = allyList[i]
			local _, inLos, inRadar = spGetPositionLosState(x, y, z, ally)
			if inLos then
				scan.seen[ally] = (scan.seen[ally] or 0) + 1
			end
			if inRadar then
				scan.radar[ally] = (scan.radar[ally] or 0) + 1
			end
		end
	end
	-- Where a few army units stand, on the way from their start to the enemy's.
	local bases = scan.bases
	---@cast bases -?
	for _ = 1, scan.armyQuota do
		local unitID = army.list[scan.armyAt]
		if not unitID then
			break
		end
		scan.armyAt = scan.armyAt + 1
		local teamID = finished[unitID]
		local ally = teamID and allyOf[teamID]
		local base = teamID and bases[teamID]
		if ally and base and base.len2 > 0 then
			local x, _, z = spGetUnitPosition(unitID)
			if x then
				local t = ((x - base.x) * base.dx + (z - base.z) * base.dz) / base.len2
				t = t < 0 and 0 or (t > 1 and 1 or t)
				local value = army.what[unitID] or 0
				scan.weight[ally] = (scan.weight[ally] or 0) + value
				scan.reach[ally] = (scan.reach[ally] or 0) + value * t
			end
		end
	end
	-- What a few producing units make.
	for _ = 1, scan.producerQuota do
		local unitID = producers.list[scan.producerAt]
		if not unitID then
			break
		end
		scan.producerAt = scan.producerAt + 1
		local teamID = finished[unitID]
		local unitDefID = producers.what[unitID]
		local key = unitDefID and defIncome[unitDefID]
		if teamID and key then
			local metalMake, _, energyMake = spGetUnitResources(unitID)
			local made = scan.made[teamID]
			if not made then
				made = {}
				scan.made[teamID] = made
			end
			local v = (defIncomeMetal[unitDefID] and metalMake or energyMake) or 0
			made[key] = (made[key] or 0) + v
		end
	end
	-- And every team's whole income now and then, for what the rest made.
	if frame % INCOME_EVERY == 0 then
		for teamID in pairs(teams) do
			local income = scan.income[teamID]
			if not income then
				income = { metal = 0, energy = 0, n = 0, dry = 0, metalFull = 0, energyFull = 0 }
				scan.income[teamID] = income
			end
			local metalHas, metalMax, _, metal = spGetTeamResources(teamID, "metal")
			local energyHas, energyMax, _, energy = spGetTeamResources(teamID, "energy")
			income.metal = income.metal + (metal or 0)
			income.energy = income.energy + (energy or 0)
			income.n = income.n + 1
			if energyHas and energyMax and energyMax > 0 then
				if energyHas <= energyMax * DRY_SHARE then
					income.dry = income.dry + 1
				elseif energyHas >= energyMax * FULL_SHARE then
					income.energyFull = income.energyFull + 1
				end
			end
			if metalHas and metalMax and metalMax > 0 and metalHas >= metalMax * FULL_SHARE then
				income.metalFull = income.metalFull + 1
			end
		end
	end
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
	-- The APM broadcast gadget's last figure for the team, so the rate has a history.
	local apm = GG.teamAPM
	out.actionsPerMinute = apm and apm[teamID] or 0
	out.metalReclaimed = spGetTeamRulesParam(teamID, "teamStatsReclaimedMetal") or 0
	out.energyReclaimed = spGetTeamRulesParam(teamID, "teamStatsReclaimedEnergy") or 0
	out.windSpeed = select(4, spGetWind()) or 0
	local ally = allyOf[teamID]
	out.visionCoverage = scan.vision[ally] or 0
	out.radarCoverage = scan.radarCover[ally] or 0
	out.frontLine = scan.front[ally] or 0
	local src = scan.sources[teamID]
	for _, list in ipairs(PASS_KEYS) do
		for i = 1, #list do
			local key = list[i]
			out[key] = src and src[key] or 0
		end
	end
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

-- The minutes one sampling period is worth: idle build power is added up over them.
local SAMPLE_MINUTES = SAMPLE_PERIOD / 1800

local function sample(frame)
	for teamID, h in pairs(history) do
		if not dead[teamID] then
			readLive(teamID, scratch)
			-- What was not building over the period just gone, in build power minutes.
			local t = teams[teamID]
			local idle = math.max(0, (scratch.buildPower or 0) - (scratch.buildPowerActive or 0))
			t.buildPowerIdle = t.buildPowerIdle + idle * SAMPLE_MINUTES
			scratch.buildPowerIdle = t.buildPowerIdle
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

-- An upgrade of its kind finished on top of it: what the game removed and refunded.
local function replacedInPlace(unitID, unitDefID)
	local site = defSite[unitDefID]
	if not site then
		return false
	end
	local x, _, z = spGetUnitPosition(unitID)
	if not x then
		return false
	end
	local near = spGetUnitsInCylinder(x, z, 10)
	for i = 1, #near do
		if near[i] ~= unitID and defSite[spGetUnitDefID(near[i])] == site then
			return true
		end
	end
	return false
end

-- Whose fire brought an aircraft down, for when it hits the ground; and a nuke come down
-- on a team, once for all it hurt of the team.
function gadget:UnitDamaged(
	unitID,
	unitDefID,
	unitTeam,
	damage,
	paralyzer,
	weaponDefID,
	projectileID,
	attackerID,
	attackerDefID,
	attackerTeam
)
	if defCanFly[unitDefID] and attackerTeam and damage > 0 and not paralyzer then
		lastHitBy[unitID] = attackerTeam
	end
	local silo = nukeWeapon[weaponDefID]
	if silo and teams[unitTeam] then
		local frame = spGetGameFrame()
		local last = nukedAt[unitTeam]
		if not last or frame - last > NUKE_FRAMES then
			markMilestone(unitTeam, MILESTONE_BY_KEY.nuked, attackerDefID or silo, attackerID)
		end
		nukedAt[unitTeam] = frame
	end
end

-- A silo's stockpile going down is a missile on its way.
---@diagnostic disable-next-line: undefined-field
function gadget:StockpileChanged(unitID, unitDefID, unitTeam, weaponNum, oldCount, newCount)
	if defNuke[unitDefID] and newCount < oldCount and teams[unitTeam] then
		markMilestone(unitTeam, MILESTONE_BY_KEY.nukeLaunched, unitDefID, unitID)
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	-- A plane that was shot down and has crashed is its shooter's kill.
	local hitBy = lastHitBy[unitID]
	if hitBy then
		lastHitBy[unitID] = nil
		local moveType = not attackerTeam and spGetUnitMoveTypeData(unitID)
		if moveType and moveType.aircraftState == "crashing" then
			attackerTeam = hitBy
		end
	end
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
		-- What it was lost to: an enemy whatever the way, else the engine's cause, else the
		-- team's own side when it was behind it.
		local attackerAlly = attackerTeam and allyOf[attackerTeam]
		---@type string
		local cause
		if attackerAlly ~= nil and attackerAlly ~= allyOf[unitTeam] then
			cause = "lostEnemy"
		elseif weaponDefID == KILLED_BY_LUA and (attackerAlly == nil or attackerID == unitID) then
			-- Taken away by the game: at once on a self-destruct order, refunded under an
			-- upgrade, or for some other reason of its own.
			if (spGetUnitSelfDTime(unitID) or 0) > 0 then
				cause = "lostSelfD"
			elseif replacedInPlace(unitID, unitDefID) then
				cause = "lostReclaimed"
			else
				cause = "lostOther"
			end
		else
			cause = CAUSE_OF[weaponDefID or 0] or (attackerAlly ~= nil and "lostFriendly" or "lostOther")
		end
		victim[cause] = victim[cause] + value
		markMilestone(unitTeam, MILESTONE_BY_KEY.firstLoss, unitDefID, unitID)
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
	markMilestone(attackerTeam, MILESTONE_BY_KEY.firstKill, unitDefID, unitID)
	local split = killedAs[defBucket[unitDefID]]
	if split then
		killer[split] = killer[split] + value
	end
	if defIsCommander[unitDefID] then
		killer.comKills = killer.comKills + 1
		markMilestone(attackerTeam, MILESTONE_BY_KEY.commanderKill, unitDefID, unitID)
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
	local found = loadSpots()
	return {
		period = SAMPLE_PERIOD,
		keys = keys,
		buckets = buckets,
		milestones = kinds,
		energyPerMetal = ENERGY_PER_METAL,
		-- How many spots the map has of either kind: none, and their counts say nothing.
		metalSpots = #found.metal,
		geoSpots = #found.geo,
	}
end

-- For other unsynced gadgets, through the shared table: GG.TeamStats.GetLive(teamID),
-- GetHistory(teamID, from), GetMilestones(teamID), GetInfo(). The same gate applies.
local exports = {
	GetLive = GetTeamStatsLive,
	GetHistory = GetTeamStatsHistory,
	GetMilestones = GetTeamStatsMilestones,
	GetInfo = GetTeamStatsInfo,
}

----------------------------------------------------------------
-- Serving LuaUI
----------------------------------------------------------------

-- The engine's cross-state calls: Script.LuaUI.<name>(...) runs a global of the LuaUI
-- state, and Script.LuaUI("<name>") says whether there is one to run.
---@diagnostic disable-next-line: undefined-global
local Script = Script

-- LuaUI takes part by registering globals (luaui/Widgets/api_teamstats.lua holds them
-- for every widget): `TeamStatsLive(all, frame)` is handed the live values of every
-- team the viewer may see, keyed by team, every LIVE_PERIOD frames for as long as it is
-- registered; `TeamStatsInfo(info)` is handed the layout while it is registered;
-- `TeamStatsHistoryRequest()` returning { [teamID] = fromIndex } is answered through
-- `TeamStatsHistory(teamID, history)` with the samples from that index on (see
-- GetTeamStatsHistory for the shape), so a caller holding the first n samples asks for
-- what came after them.
local function serveLuaUI(frame)
	if Script.LuaUI("TeamStatsLive") then
		Script.LuaUI.TeamStatsLive(GetTeamStatsLive(), frame)
	end
	if Script.LuaUI("TeamStatsInfo") then
		Script.LuaUI.TeamStatsInfo(GetTeamStatsInfo())
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
	if frame > 0 then
		scanStep(frame)
	end
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
	local allies = {}
	for teamID in pairs(teams) do
		allies[allyOf[teamID]] = true
	end
	for ally in pairs(allies) do
		allyList[#allyList + 1] = ally
	end
	table.sort(allyList)
	-- Units already standing, after a reload or when the game is joined late.
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		local unitDefID = Spring.GetUnitDefID(unitID)
		---@cast unitDefID -?
		unitCreated(unitID, unitDefID, Spring.GetUnitTeam(unitID))
	end
	GG.TeamStats = exports
end

function gadget:Shutdown()
	GG.TeamStats = nil
end
