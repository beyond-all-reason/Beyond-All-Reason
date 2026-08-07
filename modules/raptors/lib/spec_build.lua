local Difficulty = VFS.Include("modules/waves/lib/difficulty.lua")

local SpecBuild = {}

local BOSS_MIN_HEALTH_FRACTION = 0.2

local SQUAD_LIFE = 10
local SPECIALIST_LIFE = 100

local OPENING_ANGER = 5

-- Raptors are land-only: a sea map gets the land roster spawned on land, as it always did.
local BUCKET_OF_POOL = {
	basic = "basicLand",
	special = "specialLand",
	basicAir = "basicAirLand",
	specialAir = "specialAirLand",
	healer = "healerLand",
}

-- The legacy panel reads these names; the prefix alone would derive the
-- "Boss" spellings.
local RULES_NAMES = {
	bossAnger = "raptorQueenAnger",
	bossTime = "raptorQueenTime",
	bossesKilled = "raptorQueensKilled",
	bossHealth = "raptorQueenHealth",
	angerGainBase = "RaptorQueenAngerGain_Base",
	angerGainAggression = "RaptorQueenAngerGain_Aggression",
	angerGainEco = "RaptorQueenAngerGain_Eco",
}

---@param pools table<string, table[]> the legacy pools
---@return table<string, WaveBucketEntry[]>
function SpecBuild.Buckets(pools)
	local translated = {}
	local seen = {}
	local function unitsOf(units)
		if seen[units] == nil then
			local out = {}
			for _, slot in ipairs(units) do
				out[#out + 1] = { def = slot.unit, count = slot.count }
			end
			seen[units] = out
		end
		return seen[units]
	end
	for pool, bucket in pairs(BUCKET_OF_POOL) do
		local out = {}
		for _, entry in ipairs(pools[pool] or {}) do
			out[#out + 1] = {
				minAnger = entry.minAnger,
				maxAnger = entry.maxAnger,
				weight = entry.weight,
				units = unitsOf(entry.units),
			}
		end
		translated[bucket] = out
	end
	return translated
end

---@param behaviours table<string, table<integer, any>>
---@return table<integer, WaveBehaviour>
function SpecBuild.Behaviours(behaviours)
	local byID = {}
	local function record(defID)
		byID[defID] = byID[defID] or {}
		return byID[defID]
	end
	for defID in pairs(behaviours.HEALER or {}) do
		local entry = record(defID)
		entry.role = "healer"
		entry.regroup = false
		entry.minLife = SPECIALIST_LIFE
	end
	for defID in pairs(behaviours.ARTILLERY or {}) do
		local entry = record(defID)
		entry.role = "artillery"
		entry.regroup = false
		entry.minLife = SPECIALIST_LIFE
	end
	for defID in pairs(behaviours.KAMIKAZE or {}) do
		local entry = record(defID)
		entry.role = "kamikaze"
		entry.regroup = false
		entry.minLife = SPECIALIST_LIFE
	end
	for _, category in ipairs({ "SKIRMISH", "COWARD", "ARTILLERY", "HEALER" }) do
		for defID in pairs(behaviours[category] or {}) do
			record(defID).prefersFight = true
		end
	end
	return byID
end

---@param reactions { skirmish: table, coward: table, berserk: table } the legacy records, by def name
---@return WaveReactions
function SpecBuild.Reactions(reactions)
	local out = {}
	for kind, records in pairs(reactions) do
		local translated = {}
		for defName, record in pairs(records or {}) do
			translated[defName] = {
				chance = record.chance,
				distance = record.distance,
				teleport = record.teleport or nil,
				teleportCooldown = record.teleportcooldown,
			}
		end
		out[kind] = translated
	end
	return out
end

---@param difficultyParameters table[] the legacy rows
---@return WaveDifficultyRow[]
function SpecBuild.DifficultyRows(difficultyParameters)
	local rows = {}
	for index, row in ipairs(difficultyParameters) do
		rows[index] = {
			bossName = row.queenName,
			bossTime = row.queenTime,
			spawnRate = row.raptorSpawnRate,
			burrowSpawnRate = row.burrowSpawnRate,
			turretSpawnRate = row.turretSpawnRate,
			spawnChance = row.spawnChance,
			minScavs = row.minRaptors,
			maxScavs = row.maxRaptors,
			maxBurrows = row.maxBurrows,
			maxXP = row.maxXP,
			angerBonus = row.angerBonus,
			bossResistanceMult = row.queenResistanceMult,
			damageMod = row.damageMod,
			healthMod = row.healthMod,
			bossStagger = row.queenStagger,
		}
	end
	return rows
end

---@param turrets table<string, table>|nil the legacy turret table
---@return table<string, WaveStructureEntry>|nil
function SpecBuild.Structures(turrets)
	if turrets == nil or next(turrets) == nil then
		return nil
	end
	local structures = {}
	for name, entry in pairs(turrets) do
		structures[name] = {
			minAnger = entry.minQueenAnger,
			maxAnger = entry.maxQueenAnger,
			spawnedPerWave = entry.spawnedPerWave,
			maxExisting = entry.maxExisting,
			surface = "land",
		}
	end
	return structures
end

---@class RaptorsSpecOptions
---@field name string director name; also the savegame key and the rulesParam owner
---@field config table what defs_build produced
---@field modOptions table
---@field teamID integer
---@field allyTeamID integer
---@field teamCount integer human teams, gaia excluded
---@field unitCap integer
---@field hooks WaveHooks|nil
---@field overrides table|nil params the caller pins

---@param opts RaptorsSpecOptions
---@return WaveSpec
function SpecBuild.Build(opts)
	local config = opts.config
	local modOptions = opts.modOptions
	local graceMultiplier = modOptions.raptor_graceperiodmult or 1
	local bossMultiplier = modOptions.raptor_queentimemult or 1
	local spawnMultiplier = config.raptorSpawnMultiplier or 1
	local perPlayer = config.raptorPerPlayerMultiplier

	local bossTime = config.queenTime + config.gracePeriod

	local params = {
		gracePeriod = config.gracePeriod,
		gracePeriodRamped = config.gracePeriod / graceMultiplier,
		graceRamp = graceMultiplier > 1,
		bossTime = bossTime,
		bossTimeSpan = config.queenTime,
		techAngerBossTime = bossTime / bossMultiplier,
		spawnRate = config.raptorSpawnRate,
		turretSpawnRate = config.turretSpawnRate,
		minWaveSize = Difficulty.PerPlayer(config.minRaptors, perPlayer, opts.teamCount, spawnMultiplier),
		maxWaveSize = Difficulty.PerPlayer(config.maxRaptors, perPlayer, opts.teamCount, spawnMultiplier),
		bossFightWaveSizeScale = config.bossFightWaveSizeScale,
		economyScale = config.economyScale,
		perPlayerMultiplier = perPlayer,
		spawnMultiplier = spawnMultiplier,
		spawnChance = config.spawnChance,
		angerBonus = config.angerBonus,
		maxXP = config.maxXP,
		airStartAnger = config.airStartAnger,
		tier2MinAnger = OPENING_ANGER,
		teamCount = opts.teamCount,
		unitCap = opts.unitCap,
		endless = modOptions.raptor_endless and true or false,
		difficultyRows = SpecBuild.DifficultyRows(config.difficultyParameters),
		difficultyIndex = config.difficulty,
		squadLife = SQUAD_LIFE,
		spawnTimeMultiplier = modOptions.raptor_spawntimemult or 1,
		damageMod = config.damageMod,
		healthMod = config.healthMod,
		bossResistanceMult = config.queenResistanceMult,
		bossStagger = config.queenStagger,
		firstWavesBoost = modOptions.raptor_firstwavesboost or 1,
	}
	for key, value in pairs(opts.overrides or {}) do
		params[key] = value
	end

	local bossCount = modOptions.raptor_queen_count or 1
	local boss = nil
	if bossCount > 0 then
		boss = {
			defName = config.queenName,
			count = bossCount,
			minHealthFraction = BOSS_MIN_HEALTH_FRACTION,
			stagger = config.queenStagger,
			staggerDivisor = "linear",
		}
	end

	return {
		name = opts.name,
		teamID = opts.teamID,
		allyTeamID = opts.allyTeamID,
		rulesParamPrefix = "raptor",
		rulesNames = RULES_NAMES,
		params = params,
		buckets = SpecBuild.Buckets(config.squadSpawnOptionsTable),
		populations = {},
		burrows = {
			defs = config.burrowUnitsList,
			placement = config.burrowSpawnType,
			size = config.burrowSize,
			spawnSquare = config.spawnSquare,
			spawnSquareIncrement = config.spawnSquareIncrement,
			useScum = config.useScum,
			maxBurrows = Difficulty.PerPlayer(config.maxBurrows, perPlayer, opts.teamCount, spawnMultiplier, 8),
			spawnRate = config.burrowSpawnRate,
		},
		structures = SpecBuild.Structures(config.raptorTurrets),
		boss = boss,
		aggression = {
			burrowKilled = config.angerBonus,
			ecoPenalty = config.ecoBuildingsPenalty,
		},
		targets = { highValue = {}, policy = "eco" },
		reactions = SpecBuild.Reactions(config.raptorReactions),
		events = { toLuaUI = "RaptorEvent", useWaveMsg = config.useWaveMsg, bossKind = "queen" },
		hooks = opts.hooks or {},
		specRef = { module = "raptors", builder = "default", overrides = opts.overrides or {} },
	}
end

return SpecBuild
