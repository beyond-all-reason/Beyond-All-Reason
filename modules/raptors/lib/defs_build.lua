local Behaviours = VFS.Include("modules/raptors/data/behaviours.lua")
local Burrows = VFS.Include("modules/raptors/data/burrows.lua")
local CustomSquads = VFS.Include("modules/raptors/lib/custom_squads.lua")
local Difficulties = VFS.Include("modules/raptors/data/difficulties.lua")
local EconomyScale = VFS.Include("modules/waves/lib/economy_scale.lua")
local Eggs = VFS.Include("modules/raptors/data/eggs.lua")
local Minibosses = VFS.Include("modules/raptors/data/minibosses.lua")
local Minions = VFS.Include("modules/raptors/data/minions.lua")
local Settings = VFS.Include("modules/raptors/data/settings.lua")
local Squads = VFS.Include("modules/raptors/data/squads.lua")
local Turrets = VFS.Include("modules/raptors/data/turrets.lua")

local DefsBuild = {}

-- Anger caps at 999, so a squad reaching 1000 never ages out.
local FOREVER = 1000
local AI_MARKER = "RaptorsAI"

-- The legacy pool names, which this config keeps: the golden spec compares
-- the two tables directly, and spec_build renames on the way to the director.
local POOL_OF_BUCKET = {
	basicLand = "basic",
	specialLand = "special",
	basicAir = "basicAir",
	specialAir = "specialAir",
	healerLand = "healer",
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

---The repetition IS the weighting: the director draws uniformly from the
---filtered pool, so an entry present nine times is nine times as likely.
---@param pools table<string, table[]>
---@param params { type: string, minAnger: number|nil, maxAnger: number|nil, weight: integer|nil, units: table[]|nil }
local function addSquad(pools, params)
	if params == nil or params.units == nil then
		return
	end
	local minAnger = params.minAnger or 0
	local maxAnger = params.maxAnger or (minAnger + 100)
	if maxAnger >= FOREVER then
		maxAnger = FOREVER
	end
	local weight = params.weight or 1
	local pool = pools[params.type]
	if pool == nil then
		error("raptors: no such squad pool: " .. tostring(params.type))
	end
	for _ = 1, weight do
		pool[#pool + 1] = { minAnger = minAnger, maxAnger = maxAnger, units = params.units, weight = weight }
	end
end

---@param behaviours table category -> unit name -> record
---@param unitDefNames table<string, table>
---@return table<string, table[]> pools in the legacy pool names
local function buildPools(behaviours, unitDefNames)
	local pools = { basic = {}, special = {}, basicAir = {}, specialAir = {}, healer = {} }
	for _, squad in ipairs(Squads) do
		addSquad(pools, {
			type = POOL_OF_BUCKET[squad.type] or squad.type,
			weight = squad.weight,
			minAnger = squad.minAnger,
			maxAnger = squad.maxAnger,
			units = squad.units,
		})
	end
	local custom = CustomSquads.Scan(unitDefNames)
	for category, records in pairs(custom.behaviours) do
		behaviours[category] = behaviours[category] or {}
		for unitName, record in pairs(records) do
			if behaviours[category][unitName] == nil then
				behaviours[category][unitName] = record
			end
		end
	end
	for _, squad in ipairs(custom.squads) do
		addSquad(pools, {
			type = squad.pool,
			weight = squad.weight,
			minAnger = squad.minAnger,
			maxAnger = squad.maxAnger,
			units = squad.units,
		})
	end
	return pools
end

---@param row table
---@param opts table
---@param economyScale number
---@return table the row in the legacy field names, multipliers applied
local function resolveRow(row, opts, economyScale)
	local modOptions = opts.modOptions
	local graceMult = modOptions.raptor_graceperiodmult or 1
	local bossMult = modOptions.raptor_queentimemult or 1
	local paceMult = modOptions.raptor_spawntimemult or 1

	local bossDef = opts.unitDefNames[row.bossName]
	local staggerHealth = bossDef and math.ceil(bossDef.health * row.bossStagger.healthFraction) or 0

	return {
		gracePeriod = row.gracePeriod * graceMult * 60,
		queenTime = row.bossMinutes * bossMult * 60,
		raptorSpawnRate = row.waveRate / paceMult / economyScale,
		burrowSpawnRate = row.burrowRate / paceMult / economyScale,
		turretSpawnRate = row.turretRate / paceMult / economyScale,
		queenSpawnMult = row.bossSpawnMult,
		angerBonus = row.angerBonus,
		maxXP = row.maxXP * economyScale,
		spawnChance = row.spawnChance,
		damageMod = row.damageMod,
		healthMod = row.healthMod,
		maxBurrows = row.maxBurrows,
		minRaptors = row.minUnits * economyScale,
		maxRaptors = row.maxUnits * economyScale,
		raptorPerPlayerMultiplier = row.perPlayerMultiplier,
		queenName = row.bossName,
		queenResistanceMult = row.bossResistanceMult * economyScale,
		queenStagger = { health = staggerHealth, time = row.bossStagger.time },
	}
end

---@class RaptorsBuildOptions
---@field modOptions table Spring.GetModOptions() snapshot
---@field teamList integer[]
---@field getTeamLuaAI fun(teamID: integer): string|nil
---@field unitDefNames table<string, table>
---@field log fun(level: string, message: string)|nil

---@param opts RaptorsBuildOptions
---@return table config in the legacy field names
function DefsBuild.Build(opts)
	assert(
		type(opts) == "table" and type(opts.modOptions) == "table",
		"raptors defs_build.Build needs { modOptions, teamList, getTeamLuaAI, unitDefNames }"
	)
	local modOptions = opts.modOptions
	local unitDefNames = opts.unitDefNames or {}

	local economyScale = EconomyScale.Compute(modOptions)

	local difficulties = {}
	for index, key in ipairs(Difficulties.order) do
		difficulties[key] = index
	end
	local difficulty = difficulties[modOptions.raptor_difficulty]

	local difficultyParameters = {}
	for index, key in ipairs(Difficulties.order) do
		difficultyParameters[index] = resolveRow(Difficulties.rows[key], opts, economyScale)
	end

	local behaviours = shallowCopy(Behaviours)
	local pools = buildPools(behaviours, unitDefNames)

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
	local probe = unitDefNames[Settings.probeUnit]
	behavioursByID.PROBE_UNIT = probe and probe.id or nil

	local raptorTurrets = {}
	for _, name in ipairs(sortedKeys(Turrets)) do
		local info = Turrets[name]
		if not (info.restrictedBy and modOptions[info.restrictedBy]) then
			raptorTurrets[name] = {
				minQueenAnger = info.minAnger,
				spawnedPerWave = info.spawnedPerWave,
				maxExisting = info.maxExisting,
				maxQueenAnger = info.maxAnger,
			}
		end
	end

	local burrowName = next(Burrows)
	local burrowDef = unitDefNames[burrowName]

	local config = {
		useEggs = Settings.useEggs,
		useScum = Settings.useScum,
		difficulty = difficulty,
		difficulties = difficulties,
		raptorEggs = shallowCopy(Eggs),
		burrowName = burrowName,
		burrowDef = burrowDef and burrowDef.id or nil,
		burrowUnitsList = shallowCopy(Burrows),
		raptorSpawnMultiplier = modOptions.raptor_spawncountmult,
		burrowSpawnType = modOptions.raptor_raptorstart,
		spawnSquare = Settings.spawnSquare,
		spawnSquareIncrement = Settings.spawnSquareIncrement,
		raptorTurrets = raptorTurrets,
		miniBosses = shallowCopy(Minibosses),
		raptorMinions = shallowCopy(Minions),
		raptorBehaviours = behavioursByID,
		raptorReactions = { skirmish = behaviours.SKIRMISH, coward = behaviours.COWARD, berserk = behaviours.BERSERK },
		difficultyParameters = difficultyParameters,
		useWaveMsg = Settings.useWaveMsg,
		burrowSize = Settings.burrowSize,
		squadSpawnOptionsTable = pools,
		airStartAnger = modOptions.unit_restrictions_noair and 10000 or Settings.airStartAnger,
		ecoBuildingsPenalty = shallowCopy(Settings.ecoBuildingsPenalty),
		bossFightWaveSizeScale = Settings.bossFightWaveSizeScale,
		defaultRaptorFirestate = Settings.defaultRaptorFirestate,
		economyScale = economyScale,
		humanTeamCount = EconomyScale.HumanTeamCount(opts.teamList, opts.getTeamLuaAI, AI_MARKER),
	}

	if difficulty ~= nil then
		for key, value in pairs(difficultyParameters[difficulty]) do
			config[key] = value
		end
	end

	return config
end

---@return table config
function DefsBuild.FromEngine()
	return DefsBuild.Build({
		modOptions = Spring.GetModOptions(),
		teamList = Spring.GetTeamList(),
		getTeamLuaAI = Spring.GetTeamLuaAI,
		unitDefNames = UnitDefNames,
		log = function(level, message)
			Spring.Log("raptors", level == "error" and LOG.ERROR or LOG.WARNING, message)
		end,
	})
end

return DefsBuild
