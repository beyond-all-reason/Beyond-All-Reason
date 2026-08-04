local Difficulty = VFS.Include("modules/waves/lib/difficulty.lua")

local SpecBuild = {}

-- A boss that arrives before the roster has climbed still has to be a boss.
local BOSS_MIN_HEALTH_FRACTION = 0.2

-- Squad lifetimes, in waves. The base is what an ordinary squad gets;
-- healers, artillery and kamikazes hold the field longer because their job
-- takes longer than one wave.
local SQUAD_LIFE = 10
local HEALER_LIFE = 20
local KAMIKAZE_LIFE = 100

---A squad appears once per weight point BY REFERENCE, so translating per distinct table instead
---of per entry keeps this proportional to the number of squads rather than their total weight.
---@param pools table<string, table[]>
---@return table<string, WaveBucketEntry[]>
function SpecBuild.Buckets(pools)
	local translated = {}
	local seen = {}

	---@param units table[]
	---@return WaveSquadUnit[]
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

	for name, pool in pairs(pools) do
		-- commanders and decoyCommanders live in the same table but are
		-- populations, not pools; they are keyed by name, not by index.
		if name ~= "commanders" and name ~= "decoyCommanders" then
			local bucket = {}
			for _, entry in ipairs(pool) do
				bucket[#bucket + 1] = {
					minAnger = entry.minAnger,
					maxAnger = entry.maxAnger,
					weight = entry.weight,
					units = unitsOf(entry.units),
				}
			end
			translated[name] = bucket
		end
	end
	return translated
end

---@param behaviours table<string, table<integer, any>>
---@return table<integer, WaveBehaviour>
function SpecBuild.Behaviours(behaviours)
	local byID = {}

	---@param defID integer
	---@return table
	local function record(defID)
		byID[defID] = byID[defID] or {}
		return byID[defID]
	end

	for defID in pairs(behaviours.HEALER or {}) do
		local entry = record(defID)
		entry.role = "healer"
		entry.regroup = false
		entry.minLife = HEALER_LIFE
	end
	for defID in pairs(behaviours.ARTILLERY or {}) do
		local entry = record(defID)
		entry.role = "artillery"
		entry.regroup = false
	end
	for defID in pairs(behaviours.KAMIKAZE or {}) do
		local entry = record(defID)
		entry.role = "kamikaze"
		entry.regroup = false
		entry.minLife = KAMIKAZE_LIFE
	end
	for defID in pairs(behaviours.ALWAYSMOVE or {}) do
		record(defID).order = "move"
	end
	for defID in pairs(behaviours.ALWAYSFIGHT or {}) do
		record(defID).order = "fight"
	end
	-- Anything that keeps its distance or mends prefers a fight order when it
	-- goes idle: a move order walks it into the thing it was avoiding.
	for _, category in ipairs({ "SKIRMISH", "COWARD", "ARTILLERY", "HEALER" }) do
		for defID in pairs(behaviours[category] or {}) do
			record(defID).prefersFight = true
		end
	end
	return byID
end

---@param difficultyParameters table[]
---@return WaveDifficultyRow[]
function SpecBuild.DifficultyRows(difficultyParameters)
	local rows = {}
	for index, row in ipairs(difficultyParameters) do
		rows[index] = {
			bossName = row.bossName,
			bossTime = row.bossTime,
			spawnRate = row.scavSpawnRate,
			burrowSpawnRate = row.burrowSpawnRate,
			turretSpawnRate = row.turretSpawnRate,
			spawnChance = row.spawnChance,
			minScavs = row.minScavs,
			maxScavs = row.maxScavs,
			maxBurrows = row.maxBurrows,
			maxXP = row.maxXP,
			angerBonus = row.angerBonus,
			bossResistanceMult = row.bossResistanceMult,
			damageMod = row.damageMod,
			healthMod = row.healthMod,
			bossStagger = row.bossStagger,
		}
	end
	return rows
end

---@param turrets table<string, table>|nil
---@return table<string, WaveStructureEntry>|nil
function SpecBuild.Structures(turrets)
	if turrets == nil or next(turrets) == nil then
		return nil
	end
	local structures = {}
	for name, entry in pairs(turrets) do
		structures[name] = {
			minAnger = entry.minBossAnger,
			maxAnger = entry.maxBossAnger,
			spawnedPerWave = entry.spawnedPerWave,
			maxExisting = entry.maxExisting,
			surface = entry.surfaceType,
		}
	end
	return structures
end

---@class ScavengersSpecOptions
---@field name string director name; also the savegame key and the rulesParam owner
---@field config table what defs_build produced
---@field modOptions table
---@field teamID integer
---@field allyTeamID integer
---@field teamCount integer human teams, gaia excluded
---@field unitCap integer
---@field hooks WaveHooks|nil flavor callbacks the gadget supplies
---@field overrides table|nil params the caller pins (a mission's intensity, a smaller boss count)

---@param opts ScavengersSpecOptions
---@return WaveSpec
function SpecBuild.Build(opts)
	local config = opts.config
	local modOptions = opts.modOptions
	local graceMultiplier = modOptions.scav_graceperiodmult or 1
	local bossMultiplier = modOptions.scav_bosstimemult or 1
	local spawnMultiplier = config.scavSpawnMultiplier or 1
	local perPlayer = config.scavPerPlayerMultiplier

	-- The absolute second the boss is due, grace included. The tech clock
	-- measures against this divided by the host's boss dial, which is what
	-- makes "boss twice as fast" also mean "roster twice as fast".
	local bossTime = config.bossTime + config.gracePeriod

	local params = {
		gracePeriod = config.gracePeriod,
		-- Before the first boss, a stretched grace period stretches the clock
		-- it is measured against too — otherwise a host who tripled grace
		-- would face tier-one waves for an hour.
		gracePeriodRamped = config.gracePeriod / graceMultiplier,
		graceRamp = graceMultiplier > 1,
		bossTime = bossTime,
		bossTimeSpan = config.bossTime,
		techAngerBossTime = bossTime / bossMultiplier,
		spawnRate = config.scavSpawnRate,
		turretSpawnRate = config.turretSpawnRate,
		minWaveSize = Difficulty.PerPlayer(config.minScavs, perPlayer, opts.teamCount, spawnMultiplier),
		maxWaveSize = Difficulty.PerPlayer(config.maxScavs, perPlayer, opts.teamCount, spawnMultiplier),
		bossFightWaveSizeScale = config.bossFightWaveSizeScale,
		economyScale = config.economyScale,
		perPlayerMultiplier = perPlayer,
		spawnMultiplier = spawnMultiplier,
		spawnChance = config.spawnChance,
		angerBonus = config.angerBonus,
		maxXP = config.maxXP,
		airStartAnger = config.airStartAnger,
		tier2MinAnger = config.tierConfiguration[2].minAnger,
		teamCount = opts.teamCount,
		unitCap = opts.unitCap,
		endless = modOptions.scav_endless and true or false,
		dynamicDifficulty = config.dynamicDifficulty,
		difficultyRows = SpecBuild.DifficultyRows(config.difficultyParameters),
		difficultyIndex = config.difficulty,
		squadLife = SQUAD_LIFE,
		spawnTimeMultiplier = modOptions.scav_spawntimemult or 1,
		damageMod = config.damageMod,
		healthMod = config.healthMod,
		bossResistanceMult = config.bossResistanceMult,
		bossStagger = config.bossStagger,
	}
	for key, value in pairs(opts.overrides or {}) do
		params[key] = value
	end

	-- A boss count of zero is not "a boss that never spawns", it is no boss at
	-- all: pressure with no ending, which is what a mission's skirmish pack
	-- wants and what the mission's own triggers then end.
	local bossCount = modOptions.scav_boss_count or 1
	local boss = nil
	if bossCount > 0 then
		boss = {
			defName = config.bossName,
			count = bossCount,
			minHealthFraction = BOSS_MIN_HEALTH_FRACTION,
			stagger = config.bossStagger,
			staggerDivisor = "sqrt",
		}
	end

	return {
		name = opts.name,
		teamID = opts.teamID,
		allyTeamID = opts.allyTeamID,
		-- "scav" reproduces every legacy GameRulesParam name byte for byte, so
		-- the two stats panels keep reading the keys they were written against.
		rulesParamPrefix = "scav",
		params = params,
		buckets = SpecBuild.Buckets(config.squadSpawnOptionsTable),
		populations = {
			commanders = config.squadSpawnOptionsTable.commanders,
			decoyCommanders = config.squadSpawnOptionsTable.decoyCommanders,
		},
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
		structures = SpecBuild.Structures(config.scavTurrets),
		boss = boss,
		aggression = {
			burrowKilled = config.angerBonus,
			ecoPenalty = config.ecoBuildingsPenalty,
		},
		targets = { highValue = config.highValueTargets },
		-- The creep takes what stands in it; the director's defaults are the
		-- scavenger numbers.
		capture = {},
		events = { toLuaUI = "ScavEvent", useWaveMsg = config.useWaveMsg },
		hooks = opts.hooks or {},
		-- How to rebuild this spec after a load: hooks are code and come from
		-- the module; only progress travels in the savegame.
		specRef = { module = "scavengers", builder = "default", overrides = opts.overrides or {} },
	}
end

return SpecBuild
