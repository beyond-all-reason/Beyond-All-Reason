--- The program half of the scavengers roster: data in, config out.
---
--- Everything under data/ is inert. This is the only file that does anything
--- with it — applies the host's dials to the difficulty ladder, expands unit
--- lists into weighted squad pools, resolves names to unit-def ids, and
--- assembles the config table the director (and, until it is deleted, the old
--- monolith) reads.
---
--- Build(opts) is PURE: every piece of the world it needs arrives injected —
--- the modoption snapshot, the team list, the def tables. The old file read
--- all of that from globals at include time, which is what made it impossible
--- to test, impossible to read out of a lobby, and impossible to build twice
--- with different settings. FromEngine() is the one adapter that supplies
--- them from Spring.

local Behaviours = VFS.Include("modules/scavengers/data/behaviours.lua")
local Burrows = VFS.Include("modules/scavengers/data/burrows.lua")
local Commanders = VFS.Include("modules/scavengers/data/commanders.lua")
local CustomSquads = VFS.Include("modules/scavengers/lib/custom_squads.lua")
local Difficulties = VFS.Include("modules/scavengers/data/difficulties.lua")
local EconomyScale = VFS.Include("modules/scavengers/lib/economy_scale.lua")
local Settings = VFS.Include("modules/scavengers/data/settings.lua")
local Squads = VFS.Include("modules/scavengers/data/squads.lua")
local Targets = VFS.Include("modules/scavengers/data/targets.lua")
local Tiers = VFS.Include("modules/scavengers/data/tiers.lua")
local Turrets = VFS.Include("modules/scavengers/data/turrets.lua")

local UnitLists = {
	land = VFS.Include("modules/scavengers/data/land_units.lua"),
	sea = VFS.Include("modules/scavengers/data/sea_units.lua"),
	air = VFS.Include("modules/scavengers/data/air_units.lua"),
}

local DefsBuild = {}

-- Anger caps at 999, so a squad reaching 1000 never ages out.
local FOREVER = 1000
local AI_MARKER = "ScavengersAI"

-- The bucket names the director draws from. Declared here so a typo in a
-- data file's `type` field is a nil index at build time, not silence.
local BUCKETS = {
	"basicLand", "basicSea", "basicAirLand", "basicAirSea",
	"specialLand", "specialSea", "specialAirLand", "specialAirSea",
	"healerLand", "healerSea",
}

---@param t table
---@return table
local function shallowCopy(t)
	local out = {}
	for key, value in pairs(t) do
		out[key] = type(value) == "table" and shallowCopy(value) or value
	end
	return out
end

---Sorted keys. Every expansion below walks its source this way: a roster
---whose contents depend on table iteration order is a roster that can differ
---between two clients of the same game.
---@param t table
---@return any[]
local function sortedKeys(t)
	local keys = {}
	for key in pairs(t or {}) do
		keys[#keys + 1] = key
	end
	table.sort(keys)
	return keys
end

--------------------------------------------------------------------------------
-- Squad pools
--------------------------------------------------------------------------------

---Add one squad to a pool, repeated once per weight point.
---
---The repetition IS the weighting: the director draws uniformly from the
---filtered pool, so an entry present nine times is nine times as likely as
---one present once. Cheaper than carrying weights into the draw, and it is
---the shape the director already expects.
---@param pools table<string, table[]>
---@param params { type: string, minAnger: number|nil, maxAnger: number|nil, weight: integer|nil, units: table[]|nil }
local function addSquad(pools, params)
	if params == nil or params.units == nil then
		return
	end
	local minAnger = params.minAnger or 0
	-- A squad with no ceiling is retired a hundred points after it arrives:
	-- the default is a rotation, not a permanent addition.
	local maxAnger = params.maxAnger or (minAnger + 100)
	if maxAnger >= FOREVER then
		maxAnger = FOREVER
	end
	local weight = params.weight or 1
	local pool = pools[params.type]
	if pool == nil then
		error("scavengers: no such squad pool: " .. tostring(params.type))
	end
	for _ = 1, weight do
		pool[#pool + 1] = { minAnger = minAnger, maxAnger = maxAnger, units = params.units, weight = weight }
	end
end

---One unit, one squad, at the size its tier allows.
---@param pools table<string, table[]>
---@param behaviours table
---@param list table<integer, table<string, integer>> tier -> unit name -> weight
---@param spec table
local function expandRole(pools, behaviours, list, spec)
	for _, tier in ipairs(sortedKeys(list)) do
		local tierConfig = Tiers[tier]
		for _, unitName in ipairs(sortedKeys(list[tier])) do
			local weight = list[tier][unitName]
			if spec.behaviour then
				spec.behaviour(behaviours, unitName)
			end
			for _, variant in ipairs(spec.variants) do
				addSquad(pools, {
					type = variant.bucket,
					weight = weight,
					minAnger = tierConfig.minAnger,
					maxAnger = variant.forever and FOREVER or tierConfig.maxAnger,
					units = { { count = variant.size(tierConfig.maxSquadSize), unit = unitName } },
				})
			end
		end
	end
end

---@param behaviours table
---@param category string
---@param unitName string
---@param record table|boolean
local function claim(behaviours, category, unitName, record)
	behaviours[category] = behaviours[category] or {}
	behaviours[category][unitName] = record
end

-- The role -> behaviour contract, stated once. A unit already named in
-- behaviours.lua keeps what the roster gave it; these are the defaults for
-- everything else in the role.
local ROLE_BEHAVIOURS = {
	---Assault closes on whatever hit it.
	Assault = function(behaviours, unitName)
		if not behaviours.BERSERK[unitName] then
			claim(behaviours, "BERSERK", unitName, { distance = 2000, chance = 0.01 })
		end
	end,
	---Support keeps its distance, both after hitting and after being hit.
	Support = function(behaviours, unitName)
		if not behaviours.SKIRMISH[unitName] then
			claim(behaviours, "SKIRMISH", unitName, { distance = 500, chance = 0.1 })
			claim(behaviours, "COWARD", unitName, { distance = 500, chance = 0.75 })
			claim(behaviours, "ARTILLERY", unitName, true)
		end
	end,
	---Healers flee and mend. The skirmish half is only added if nothing else
	---already gave this unit a distance to keep.
	Healer = function(behaviours, unitName)
		if not behaviours.HEALER[unitName] then
			claim(behaviours, "HEALER", unitName, true)
			if not behaviours.SKIRMISH[unitName] then
				claim(behaviours, "SKIRMISH", unitName, { distance = 500, chance = 0.1 })
				claim(behaviours, "COWARD", unitName, { distance = 500, chance = 0.75 })
			end
		end
	end,
}

local function full(size)
	return size
end

local function double(size)
	return size * 2
end

local function quarter(size)
	return math.ceil(size * 0.25)
end

local function half(size)
	return math.ceil(size * 0.5)
end

-- How each list's roles expand. Land squads travel at full tier size and
-- specials at double; sea squads at a quarter and a half, because a fleet
-- that size cannot path out of a bay. Air has no roles and never ages out.
local EXPANSIONS = {
	{ list = "land", role = "Raid", variants = {
		{ bucket = "basicLand", size = full }, { bucket = "specialLand", size = double },
	} },
	{ list = "land", role = "Assault", behaviour = "Assault", variants = {
		{ bucket = "basicLand", size = full }, { bucket = "specialLand", size = double },
	} },
	{ list = "land", role = "Support", behaviour = "Support", variants = {
		{ bucket = "basicLand", size = full }, { bucket = "specialLand", size = double },
	} },
	{ list = "land", role = "Healer", behaviour = "Healer", variants = {
		{ bucket = "healerLand", size = full },
	} },
	{ list = "sea", role = "Raid", variants = {
		{ bucket = "basicSea", size = quarter }, { bucket = "specialSea", size = half },
	} },
	{ list = "sea", role = "Assault", behaviour = "Assault", variants = {
		{ bucket = "basicSea", size = quarter }, { bucket = "specialSea", size = half },
	} },
	{ list = "sea", role = "Support", behaviour = "Support", variants = {
		{ bucket = "basicSea", size = quarter }, { bucket = "specialSea", size = half },
	} },
	{ list = "sea", role = "Healer", behaviour = "Healer", variants = {
		{ bucket = "healerSea", size = quarter },
	} },
	{ list = "air", role = "Land", variants = {
		{ bucket = "basicAirLand", size = full, forever = true },
		{ bucket = "specialAirLand", size = double, forever = true },
	} },
	{ list = "air", role = "Sea", variants = {
		{ bucket = "basicAirSea", size = full, forever = true },
		{ bucket = "specialAirSea", size = double, forever = true },
	} },
}

---Build the ten squad pools plus the two population tables.
---@param behaviours table mutated: roles claim behaviours for their units
---@param unitDefNames table<string, table>
---@return table<string, table[]>
local function buildPools(behaviours, unitDefNames)
	local pools = {}
	for _, name in ipairs(BUCKETS) do
		pools[name] = {}
	end

	for _, expansion in ipairs(EXPANSIONS) do
		local list = UnitLists[expansion.list][expansion.role]
		-- A roster naming a unit this game does not have is not an error: unit
		-- restrictions and tweaked games legitimately remove units.
		local present = {}
		for tier, units in pairs(list) do
			present[tier] = {}
			for unitName, weight in pairs(units) do
				if unitDefNames[unitName] then
					present[tier][unitName] = weight
				end
			end
		end
		expandRole(pools, behaviours, present, {
			behaviour = expansion.behaviour and ROLE_BEHAVIOURS[expansion.behaviour] or nil,
			variants = expansion.variants,
		})
	end

	-- The hand-written mixed squads, after the generated ones.
	for _, squad in ipairs(Squads) do
		local minAnger = squad.minAnger
		if squad.minAngerTier then
			minAnger = Tiers[squad.minAngerTier].minAnger
		end
		local maxAnger = squad.maxAnger
		if squad.maxAngerTier then
			maxAnger = Tiers[squad.maxAngerTier].maxAnger
		end
		addSquad(pools, {
			type = squad.type,
			weight = squad.weight,
			minAnger = minAnger,
			maxAnger = maxAnger,
			units = squad.units,
		})
	end

	-- And last, whatever a TweakDefs game added.
	local custom = CustomSquads.Scan(unitDefNames)
	for category, records in pairs(custom.behaviours) do
		for unitName, record in pairs(records) do
			if behaviours[category] == nil or behaviours[category][unitName] == nil then
				claim(behaviours, category, unitName, record)
			end
		end
	end
	for _, squad in ipairs(custom.squads) do
		addSquad(pools, {
			type = squad.bucket,
			weight = squad.weight,
			minAnger = squad.minAnger,
			maxAnger = squad.maxAnger,
			units = squad.units,
		})
	end

	pools.commanders = shallowCopy(Commanders.commanders)
	pools.decoyCommanders = shallowCopy(Commanders.decoyCommanders)
	return pools
end

--------------------------------------------------------------------------------
-- The difficulty ladder
--------------------------------------------------------------------------------

---Apply the host's dials to one rung.
---@param row table
---@param opts table
---@param economyScale number
---@return table
local function resolveRow(row, opts, economyScale)
	local modOptions = opts.modOptions
	local graceMult = modOptions.scav_graceperiodmult or 1
	local bossMult = modOptions.scav_bosstimemult or 1
	local paceMult = modOptions.scav_spawntimemult or 1

	local bossDef = opts.unitDefNames[row.bossName]
	local staggerHealth = bossDef and math.ceil(bossDef.health * row.bossStagger.healthFraction) or 0

	return {
		gracePeriod = row.gracePeriod * graceMult,
		bossTime = row.bossMinutes * bossMult * 60,
		scavSpawnRate = row.waveRate / paceMult / economyScale,
		burrowSpawnRate = row.burrowRate / paceMult / economyScale,
		turretSpawnRate = row.turretRate / paceMult / economyScale,
		bossSpawnMult = row.bossSpawnMult,
		angerBonus = row.angerBonus,
		maxXP = row.maxXP * economyScale,
		spawnChance = row.spawnChance,
		damageMod = row.damageMod,
		healthMod = row.healthMod,
		maxBurrows = row.maxBurrows,
		minScavs = row.minScavs * economyScale,
		maxScavs = row.maxScavs * economyScale,
		scavPerPlayerMultiplier = row.perPlayerMultiplier,
		bossName = row.bossName,
		bossResistanceMult = row.bossResistanceMult * economyScale,
		bossStagger = { health = staggerHealth, time = row.bossStagger.time },
	}
end

--------------------------------------------------------------------------------

---@class ScavengersBuildOptions
---@field modOptions table Spring.GetModOptions() snapshot
---@field teamList integer[]
---@field getTeamLuaAI fun(teamID: integer): string|nil
---@field unitDefNames table<string, table>
---@field log fun(level: string, message: string)|nil

---Build the scavengers config.
---@param opts ScavengersBuildOptions
---@return table config
function DefsBuild.Build(opts)
	assert(type(opts) == "table" and type(opts.modOptions) == "table",
		"scavengers defs_build.Build needs { modOptions, teamList, getTeamLuaAI, unitDefNames }")
	local modOptions = opts.modOptions
	local unitDefNames = opts.unitDefNames or {}
	local log = opts.log or function() end

	local economyScale = EconomyScale.Compute(modOptions)

	-- The difficulty index is a wire value: the UI panels read scavDifficulty
	-- as a number, and endless mode counts up through it.
	local difficulties = {}
	for index, key in ipairs(Difficulties.order) do
		difficulties[key] = index
	end
	local difficulty = difficulties[modOptions.scav_difficulty]

	local difficultyParameters = {}
	for index, key in ipairs(Difficulties.order) do
		difficultyParameters[index] = resolveRow(Difficulties.rows[key], opts, economyScale)
	end

	-- Behaviours start as the roster's own word and are added to by the role
	-- expansion below; the copy is what keeps a second Build from inheriting
	-- the first one's additions.
	local behaviours = shallowCopy(Behaviours)
	local pools = buildPools(behaviours, unitDefNames)

	-- Resolve to unit-def ids, once. Everything downstream indexes by id
	-- because that is what the engine callins hand it.
	local behavioursByID = {}
	for category, records in pairs(behaviours) do
		behavioursByID[category] = {}
		for unitName, record in pairs(records) do
			local unitDef = unitDefNames[unitName]
			if unitDef then
				behavioursByID[category][unitDef.id] = record
			end
		end
	end

	local burrowUnitsList = {}
	for name, window in pairs(Burrows) do
		burrowUnitsList[name] = {
			minAnger = Tiers[window.minAngerTier].minAnger,
			maxAnger = Tiers[window.maxAngerTier].maxAnger,
		}
	end

	-- Turrets the game's unit restrictions have taken off the table are
	-- dropped here rather than gated at spawn time, so a no-nukes game never
	-- carries the possibility around.
	local scavTurrets = {}
	for _, tier in ipairs(sortedKeys(Turrets)) do
		for _, turret in ipairs(sortedKeys(Turrets[tier])) do
			local info = Turrets[tier][turret]
			local restricted = (modOptions.unit_restrictions_noair and info.type == "antiair")
				or (modOptions.unit_restrictions_nonukes and info.type == "nuke")
				or (modOptions.unit_restrictions_nolrpc and info.type == "lrpc")
			if scavTurrets[turret] == nil and not restricted then
				scavTurrets[turret] = {
					minBossAnger = Tiers[tier].minAnger,
					spawnedPerWave = info.spawnedPerWave or 1,
					maxExisting = info.maxExisting or 10,
					maxBossAnger = info.maxBossAnger or FOREVER,
					surfaceType = info.surface or "land",
				}
			end
		end
	end

	local highValueTargets = {}
	for _, unitName in ipairs(sortedKeys(Targets)) do
		local unitDef = unitDefNames[unitName]
		if unitDef == nil then
			log("error", "scavengers: no such high-value target: " .. unitName)
		else
			highValueTargets[unitDef.id] = Targets[unitName]
		end
	end

	local ecoBuildingsPenalty = {}
	for unitName, penalty in pairs(Settings.ecoBuildingsPenalty) do
		local unitDef = unitDefNames[unitName]
		if unitDef then
			ecoBuildingsPenalty[unitDef.id] = penalty
		end
	end

	local config = {
		useScum = Settings.useScum,
		difficulty = difficulty,
		difficulties = difficulties,
		burrowUnitsList = burrowUnitsList,
		scavSpawnMultiplier = modOptions.scav_spawncountmult,
		burrowSpawnType = modOptions.scav_scavstart,
		spawnSquare = Settings.spawnSquare,
		spawnSquareIncrement = Settings.spawnSquareIncrement,
		scavTurrets = scavTurrets,
		unprocessedScavTurrets = shallowCopy(Turrets),
		-- Units that spawn other units. The mechanism is live and the table is
		-- empty, which is where the monolith left it.
		scavMinions = {},
		scavBehaviours = behavioursByID,
		difficultyParameters = difficultyParameters,
		useWaveMsg = Settings.useWaveMsg,
		burrowSize = Settings.burrowSize,
		squadSpawnOptionsTable = pools,
		-- Air waves need a floor to fire above; a no-air game gets one the
		-- anger clock can never reach.
		airStartAnger = modOptions.unit_restrictions_noair and 10000 or Settings.airStartAnger,
		ecoBuildingsPenalty = ecoBuildingsPenalty,
		highValueTargets = highValueTargets,
		bossFightWaveSizeScale = Settings.bossFightWaveSizeScale,
		defaultScavFirestate = Settings.defaultScavFirestate,
		tierConfiguration = Tiers,
		economyScale = economyScale,
		-- Dead key, kept while the old gadget still reads this table: no
		-- modoption sets it, so it is nil in every real game.
		swarmMode = modOptions.scav_swarmmode,
		humanTeamCount = EconomyScale.HumanTeamCount(opts.teamList, opts.getTeamLuaAI, AI_MARKER),
		dynamicDifficulty = Settings.dynamicDifficulty,
	}

	-- The live rung is flattened onto the config, because that is how every
	-- reader of this table addresses it: config.gracePeriod, not
	-- config.difficultyParameters[config.difficulty].gracePeriod.
	if difficulty ~= nil then
		for key, value in pairs(difficultyParameters[difficulty]) do
			config[key] = value
		end
	end

	return config
end

---The one adapter that reads the world. Everything above takes it injected.
---@return table config
function DefsBuild.FromEngine()
	return DefsBuild.Build({
		modOptions = Spring.GetModOptions(),
		teamList = Spring.GetTeamList(),
		getTeamLuaAI = Spring.GetTeamLuaAI,
		unitDefNames = UnitDefNames,
		log = function(level, message)
			Spring.Log("scavengers", level == "error" and LOG.ERROR or LOG.WARNING, message)
		end,
	})
end

return DefsBuild
