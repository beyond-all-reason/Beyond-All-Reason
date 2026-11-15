function gadget:GetInfo()
	return {
		name = "Zombies",
		desc = "Resurrects corpses as Scavengers or hostile Gaia Zombies",
		author = "SethDGamre, code snippets/inspiration from Rafal",
		date = "March 2024",
		license = "GNU GPL, v2 or later",
		layer = 6, -- after unit_corpse_link.lua, game_team_resources.lua, ai_ruins.lua, and unit_resurrected.lua so the corpse is already linked and previous_xp is on it
		enabled = true,
	}
end

-- Modder customParams.
--
-- Per unit, affecting only that unit:
--   zombie_respawn_time (seconds)
--     < 0  never respawn as a zombie
--     0    respawn instantly
--     > 0  custom respawn delay in seconds
--     this replaces the power-based delay. A heap waits twice this delay.
--   zombie_wraith_respawn_pool (any value)
--     adds the unit to the substitute pool. When the pool has any units, revived corpses, wraith
--     respawns, and units captured by zombies rise as pool units instead of the original unit. Pool units
--     always respawn, even if their corpse is not resurrectable. A unit and its _scav variant count as one
--     pool entry. The flag on either covers both. Pool units that were already zombies rise as themselves
--     instead of being substituted.
--   scav_swap_override_captured (unit name or "delete")
--     when the unit is captured by zombies, it becomes the named unit instead, or is removed with "delete".
--     With a substitute pool, the named unit's power is spent on substitutes. "delete" removes the unit
--     and does not add its power to the excess.
--
-- On any unit def, applied to the whole mode. The highest unitDefID that sets a value wins.
-- Out-of-range values are corrected: spawn counts are whole numbers of at least 1 and the minimum cannot
-- exceed the maximum, the spawn cap is a whole number at least as high as that maximum, the minimum
-- respawn delay cannot exceed the maximum, wraith chance stays between 0 and 1, band delays, the respawn
-- decay delay, the ceiling growth delay, and the tech scaling delay stay at least 0, minutes per tech
-- level stay at least 0, and a scale, decay, or spawn growth rate of 0 or less is replaced with its default.
--   zombie_minimum_spawns (integer, default 2)
--     the pack roll floor. After the bottom band delay it compounds by the minimum spawn growth rate
--     each clock minute, capped by the live spawn maximum. Also floors the configured maximum.
--   zombie_maximum_spawns (integer, default 6)
--     multiple spawns roll from the live minimum up to a maximum that starts here. After the maximum
--     spawn growth delay it compounds by the maximum spawn growth rate each clock minute, capped by the
--     spawn count cap. That live maximum also caps how many substitutes one spawn can buy.
--   zombie_minimum_spawn_growth_rate (default 1.04)
--     the pack floor multiplies by this each clock minute after the bottom band delay.
--   zombie_maximum_spawn_growth_rate (default 1.04)
--     the pack ceiling multiplies by this each clock minute after its growth delay.
--   zombie_maximum_spawn_growth_delay (minutes, default 10)
--     the pack ceiling stays at the configured maximum until this clock minute. 0 starts growth immediately.
--   zombie_spawn_count_cap (integer, default 15)
--     the pack ceiling cannot grow past this.
--   zombie_minutes_per_tech_level (default 16)
--     band-minutes gained for each tech level above the base. This is what lets player power outrun the clock.
--   zombie_tech_scaling_delay (minutes, default 15)
--     before this clock minute, player power loses one extra base tech level before the conversion.
--     0 applies the full conversion immediately.
--   zombie_minimum_respawn_delay (seconds, default 45)
--   zombie_maximum_respawn_delay (seconds, default 120)
--     the starting window for power-based revival times. After the respawn decay delay both ends
--     multiply by the respawn decay rate each minute. A heap waits twice its unit's delay.
--   zombie_power_scale_rate (default 1.13)
--     both power-band thresholds compound by this each band-minute after their delays.
--   zombie_bottom_band_delay (band-minutes, default 15)
--     the bottom stays at 10 until this many band-minutes. The pack floor waits this many clock minutes.
--     0 starts immediately.
--   zombie_top_band_delay (band-minutes, default 0)
--     the top stays at 150 until this many band-minutes, then compounds. 0 starts immediately.
--   zombie_respawn_decay_rate (default 0.96)
--     after the respawn decay delay, the minimum and maximum respawn delays multiply by this each minute.
--   zombie_respawn_decay_delay (minutes, default 40)
--     the respawn window stays at its starting minimum and maximum until this minute. 0 starts decay
--     immediately.
--   zombie_traditional_band_delay (band-minutes, default 10, or 0 when ruins, evocom, or quick start is on)
--     TEMPORARY bandaid fix, to make the balance of the traditional non-accelerated games reasonable. power based progression must be calibrated.
--     added on top of the bottom and top band delays. A customparam replaces that default. 0 adds nothing.
--   zombie_wraith_respawn_chance (0 to 1, default 0.66)
--     the chance one of these destructions creates a wraith: a unit that leaves no wreck,
--     a corpse that leaves no heap, or a heap. Reclaim and resurrection do not count.
--     A failed roll leaves nothing behind.
--   zombie_wraith_power_multiplier (default 1)
--     multiplies a unit's power when a wraith respawn spends it on substitutes. Units that rise as
--     themselves are unchanged. Revived corpses and captures do not use this multiplier.
--   zombie_factory_buildpower_tech_multiplier (default 1.7)
--     a Gaia zombie factory's buildpower is its build speed times this value raised to the current tech
--     level. Scavenger-team zombie factories keep their normal build speed.
--   zombie_wraith_spawn_max_units_per_spawn_multiplier (default 1)
--     scales how many copies a pool unit may take and still stay in the substitute roll range.
--     The permitted count is the spawn maximum times this value, rounded up.
--   zombie_enable_wraith (1 enables, 0 disables)
--     wraiths, in every mode.
--   zombie_enable_hydra (1 enables, 0 disables)
--     multiple spawns per corpse, in every mode.

if not gadgetHandler:IsSyncedCode() then
	return
end

local spring = Spring
local modOptions = spring.GetModOptions()
local modOptionEnabled = modOptions.zombies ~= "disabled"
local isIdleMode = GG.Zombies and GG.Zombies.IdleMode == true or false
if not modOptionEnabled and not isIdleMode then
	return false
end

local unitDefs = UnitDefs
local unitDefNames = UnitDefNames
local random = math.random
local floor = math.floor
local distance2dSquared = math.distance2dSquared
local clamp = math.clamp

local scavTeamID = BAR.Utilities.GetScavTeamID()
local gaiaTeamID = spring.GetGaiaTeamID()
local gaiaAllyTeamID = spring.GetTeamAllyTeamID(gaiaTeamID)
local zombieModeSettings = {
	initialSpawnCountMinimum = 2,
	initialSpawnCountMaximum = 6,
	initialRespawnDelayMinimum = 45,
	initialRespawnDelayMaximum = 120,
	wraithFeedSuccessChance = 0.66,
	wraithPowerMultiplier = 1,
	heapRespawnDelayMultiplier = 2, -- multiplied by the base corpse respawn delay
	factoryBuildpowerTechMultiplier = 1.7,
	wraithSpawnMaxUnitsPerSpawnMultiplier = 1,
	powerScaleRate = 1.13,
	minimumSpawnGrowthRate = 1.04,
	maximumSpawnGrowthRate = 1.04,
	maximumSpawnGrowthDelayMinutes = 10,
	spawnCountCap = 15,
	minutesPerTechLevel = 16,
	techScalingDelayMinutes = 15,
	bottomBandDelayMinutes = 15,
	topBandDelayMinutes = 0,
	respawnDecayRate = 0.96,
	respawnDecayDelayMinutes = 40,
	-- TEMPORARY bandaid fix, to make the balance of the traditional non-accelerated games reasonable. power based progression must be calibrated.
	traditionalBandDelayMinutes = 10,
}

---One of the zombie modes, matching the keys of `ZOMBIE_MODE_FEATURES`.
---@alias ZombieMode "basic"|"wraith"|"hydra"|"akumu"

---@class ZombieModeFeatures
---@field wraithRespawns boolean?
---@field multipleSpawns boolean?

---@type table<ZombieMode, ZombieModeFeatures>
local ZOMBIE_MODE_FEATURES = {
	basic = {},
	wraith = { wraithRespawns = true },
	hydra = { multipleSpawns = true },
	akumu = { wraithRespawns = true, multipleSpawns = true },
}
local DEFAULT_ZOMBIE_MODE = "basic"

---@type ZombieMode
local currentZombieMode = DEFAULT_ZOMBIE_MODE
local currentModeFeatures = ZOMBIE_MODE_FEATURES[DEFAULT_ZOMBIE_MODE]
local autoSpawningEnabled = true

local BASE_TECH_LEVEL = 0.5
local POWER_BAND = {
	BOTTOM_START = 10,
	TOP_START = 150,
	ADVANTAGE_AT_BOTTOM = 2,
	ADVANTAGE_AT_TOP = -3,
}
local ruinsEnabled = modOptions.ruins == "enabled"
	or (modOptions.ruins == "scav_only" and BAR.Utilities.Gametype.IsScavengers())
local evocomEnabled = modOptions.evocom and true or false
local quickStartMode = modOptions.quick_start
local quickStartEnabled = quickStartMode == "enabled"
	or quickStartMode == "factory_discount"
	or quickStartMode == "factory_discount_only"
	or (quickStartMode == "default" and modOptions.deathmode == "dominion")
if ruinsEnabled or evocomEnabled or quickStartEnabled then
	zombieModeSettings.traditionalBandDelayMinutes = 0
end
local EXPERIENCE_GROWTH = {
	RATE = 1.15,
	START_MINUTE = 25.2,
	CAP_MINUTE = 44.8,
	MAXIMUM = 0.8,
	VETERAN_PACK_CHANCE = 0.05,
	ELITE_BONUS = 0.25,
}
local FRAMES = {
	TOO_LONG = Game.gameSpeed * 60 * 45,
	CHECK_INTERVAL = Game.gameSpeed, -- How often (in frames) everything else is checked
	TECH_UPDATE = Game.gameSpeed * 60,
	MINUTE = Game.gameSpeed * 60,
	SUBSTITUTE_FAIR_ROLL = Game.gameSpeed * 60 * 20,
	RECENT_TAMPER = Game.gameSpeed,
	BUILD_STEP_CHECK = floor(Game.gameSpeed / 2),
	REZ_HIJACK_LEAD = 30,
	PENDING_DEATH_TIMEOUT = Game.gameSpeed * 3,
	VANISHED_DEATH_CHECK = 15,
	ATTACKER_SAMPLE = Game.gameSpeed,
	UNTAMPERED = -math.huge,
}
local BUILDING = {
	EXPIRING_LIFETIME = Game.gameSpeed * 60 * 5, -- we don't want random zombie immobile trash taking up unit cap forever.
	PERMANENT_POWER_LIMIT = 5000, -- to preserve more impactful units
	EXPIRING_FACTORY_LIFETIME = Game.gameSpeed * 60 * 5,
	EXPIRING_CONSTRUCTOR_POWER_LIMIT = 1000,
}
local WRECK_GRID = {
	CELL_SIZE = 512,
	CELL_STRIDE = 4096,
	HASH_X = 73856093,
	HASH_Y = 19349663,
	HASH_Z = 83492791,
}
local DAMAGE = {
	WATER_DEF_ID = Game.envDamageTypes.Water,
	KILLED_BY_LUA_DEF_ID = Game.envDamageTypes.KilledByLua,
	IS_LAVA = BAR.Lava ~= nil and BAR.Lava.isLavaMap == true,
}

local gameFrame = 0
local runFeatureBuildStepCheck = false
local tooLong = false
local factoryBuildpowerMultiplier = 1
local currentTechLevel = 1
local cachedHighestPlayerTeamPower = 0

local PICK = {
	LOWEST = true,
	HIGHEST = false,
}
local COMMANDER_SUBSTITUTION_POWER_MULTIPLIER = 0.5 -- to prevent T3 from being substituted in for commanders that die super early in the game.

local excessPower = 0

local WRAITH = {
	UNIT_NAME = "scavwraith",
	MIN_FLEE_TIME = Game.gameSpeed * 5,
	MAX_FLEE_TIME = Game.gameSpeed * 7,
	EXPIRATION_TIME = Game.gameSpeed * 480,
	MAP_MARGIN = 16,
	SPAWN_ATTEMPT_COUNT = 3,
	SPAWN_OFFSET_DISTANCE = 100,
	SPAWN_DELAY = 5,
	ENEMY_CLEAR_RADIUS = 250,
	SUBSTITUTE_ROLL_COUNT = 2,
}
local wraithUnitDefID = unitDefNames[WRAITH.UNIT_NAME] and unitDefNames[WRAITH.UNIT_NAME].id
local IDLEMODE_FLY = 0

local RULES_PARAM = {
	ENABLED = "zombies_enabled",
	TECH_LEVEL = "zombie_tech_level",
	FACTORY_BUILDPOWER_MULTIPLIER = "zombie_factory_buildpower_multiplier",
	REZ_FRAME = "zombie_rez_frame",
	REZ_ARM_FRAME = "zombie_rez_arm_frame",
	WAS_ZOMBIE = "wasZombie",
	PUBLIC_ACCESS = { public = true },
}
local creatingForcedHeap = false
local pendingCreatedFeatureData = nil

local wraithPoolUnitDefIDs = {}
local wraiths = {} ---@type table<UnitID, table?>
local pendingWraithFeeds = {}
local pendingWraithSpawns = {}
local wreckWraithFeeds = {}
local createdFeaturesByPosition = {}
local resurrectableWreckCells = {}
local wreckCellIndex = {}
local heapFeatureDefIDs = {}
local zombieFactories = {} ---@type table<UnitID, table?>
local expiringBuildingFrames = {}
local zombieUnitDefs = {}
local zombieCorpseDefs = {} ---@type table<FeatureDefID, table?>
local zombieHeapDefs = {} ---@type table<FeatureDefID, table?>
local trackedFeatures = {}
local featureCheckFrames = {}
local rezzedCorpses = {}
local zombieRezChecks = {}
local pendingTamperedFrames = {}
local pendingDeaths = {}
local pendingWreckSwaps = {}
local suppressedDeaths = {}
local DEATHS_BLOCKING_WRAITHS = {}
local pendingZombieCaptures = {}
local unitTamperFrames = {}
local zombiesBeingBuilt = {}
local zombieUnitIDs = {}

do
	local deathNamesBlockingWraiths = {
		SetNegativeHealth = true,
		KilledByCheat = true,
		Reclaimed = true,
		OutOfBounds = true,
		FactoryKilled = true,
		FactoryCancel = true,
		ConstructionDecay = true,
		TurnedIntoFeature = true,
		KilledByLua = true,
		SelfD = true,
		Water = true,
	}
	for deathName, damageTypeID in pairs(Game.envDamageTypes) do
		DEATHS_BLOCKING_WRAITHS[damageTypeID] = deathNamesBlockingWraiths[deathName]
	end
end

for featureDefID, featureDef in pairs(FeatureDefs) do
	local customParams = featureDef.customParams
	local category = customParams and customParams.category
	if category == "heaps" or string.sub(featureDef.name, -5) == "_heap" then
		heapFeatureDefIDs[featureDefID] = true
	end
end

local EFFECT = {
	HEAP_UPCYCLE_DIRT = "dirtpopup",
	HEAP_UPCYCLE_SMOKE = "corpsedestroyed-purple",
	BURST_COUNT = 3,
	OFFSET_SCALE = 0.5,
}
local SPAWN_EXPLOSION_CEGS = {
	huge = "scav-spawnexplo-huge",
	large = "scav-spawnexplo-large",
	medium = "scav-spawnexplo-medium",
	small = "scav-spawnexplo-small",
	tiny = "scav-spawnexplo-tiny",
}
local SPAWN_EFFECT_SIZE_THRESHOLDS = {
	{ threshold = 4.5, name = "huge" },
	{ threshold = 3.5, name = "large" },
	{ threshold = 2.5, name = "medium" },
	{ threshold = 1.5, name = "small" },
}
local SPAWN_SOUNDS = {
	"xploelc2",
	"xploelc3",
}

local GAIA_RESOURCE_AMOUNT = 1000000
local GAIA_RESOURCES = {
	{ resourceName = "metal", storageKey = "ms" },
	{ resourceName = "energy", storageKey = "es" },
}

local ZOMBIE_AI_FORWARDED_METHOD_NAMES = {
	"PacifyZombies",
	"SuspendAutoOrders",
	"AggroTeamID",
	"AggroAllyID",
	"KillAllZombies",
	"ClearAllOrders",
}
local ZOMBIE_AI_MISSING_RESULTS = {
	AggroTeamID = false,
	AggroAllyID = false,
}

local function compareUnitDefPower(firstUnitDefID, secondUnitDefID)
	local firstPower = zombieUnitDefs[firstUnitDefID].rezPower
	local secondPower = zombieUnitDefs[secondUnitDefID].rezPower
	if firstPower == secondPower then
		return firstUnitDefID < secondUnitDefID
	end
	return firstPower < secondPower
end

local function nameEndsWithScav(name)
	return name ~= nil and string.sub(name, -5) == "_scav"
end

do
	local defaultPowerScaleRate = zombieModeSettings.powerScaleRate
	local defaultRespawnDecayRate = zombieModeSettings.respawnDecayRate
	local defaultMinimumSpawnGrowthRate = zombieModeSettings.minimumSpawnGrowthRate
	local defaultMaximumSpawnGrowthRate = zombieModeSettings.maximumSpawnGrowthRate

	local function setSetting(customParams, customParamName, settingName, isModeFeature)
		local value = tonumber(customParams[customParamName])
		if value then
			if isModeFeature then
				for _, modeFeatures in pairs(ZOMBIE_MODE_FEATURES) do
					modeFeatures[settingName] = value == 1
				end
			else
				zombieModeSettings[settingName] = value
			end
		end
	end

	local function unitDefHasDamagingWeapon(unitDef)
		if not unitDef.weapons then
			return false
		end
		for weaponIndex = 1, #unitDef.weapons do
			local weapon = unitDef.weapons[weaponIndex]
			local weaponDefID = weapon.weaponDef
			local weaponDef = weaponDefID and WeaponDefs[weaponDefID]
			if
				weaponDef
				and weaponDef.range
				and weaponDef.range > 0
				and not (weaponDef.customParams and weaponDef.customParams.bogus)
			then
				return true
			end
		end
		return false
	end

	local function unitDefHasSensorRadius(unitDef)
		return (unitDef.radarRadius or 0) > 0
			or (unitDef.jammerRadius or 0) > 0
			or (unitDef.sonarRadius or 0) > 0
			or (unitDef.sonarJamRadius or 0) > 0
	end

	local function isExcludedFromWraithSpawn(unitDef)
		if
			unitDef.customParams.objectify
			or unitDef.customParams.drone
			or string.find(unitDef.name, "assistdrone", 1, true)
		then
			return true
		end
		local unitGroup = unitDef.customParams.unitgroup
		if unitGroup == "metal" or unitGroup == "energy" then
			return not unitDefHasDamagingWeapon(unitDef)
		end
		if unitGroup == "util" then
			return unitDefHasSensorRadius(unitDef)
		end
		return false
	end

	local function getExpiryLifetimeFrames(unitDef, rezPower)
		if unitDef.isFactory then
			return BUILDING.EXPIRING_FACTORY_LIFETIME
		elseif unitDef.speed <= 0 and rezPower <= BUILDING.PERMANENT_POWER_LIMIT then
			return BUILDING.EXPIRING_LIFETIME
		elseif unitDef.isBuilder and unitDef.speed > 0 and rezPower < BUILDING.EXPIRING_CONSTRUCTOR_POWER_LIMIT then
			return BUILDING.EXPIRING_LIFETIME
		end
	end

	local function getScavVariantUnitDefID(unitDef, unitDefID)
		if nameEndsWithScav(unitDef.name) then
			return unitDefID
		end
		local scavUnitDef = unitDefNames[unitDef.name .. "_scav"]
		return scavUnitDef and scavUnitDef.id or unitDefID
	end

	local function claimZombieFeature(featureDefsByID, featureDef, unitDef, unitDefData)
		local existingUnitDefData = featureDefsByID[featureDef.id]
		if not existingUnitDefData then
			featureDefsByID[featureDef.id] = unitDefData
			return
		end
		local customParams = featureDef.customParams
		local fromUnitName = customParams and customParams.fromunit or ""
		if fromUnitName == unitDef.name then
			featureDefsByID[featureDef.id] = unitDefData
			return
		end
		local existingUnitName = unitDefs[existingUnitDefData.unitDefID].name
		if fromUnitName ~= existingUnitName then
			featureDefsByID[featureDef.id] = unitDefData
		end
	end

	local function getSpawnExplosionCeg(unitDef)
		local sizeCategory = math.ceil((unitDef.xsize / 2 + unitDef.zsize / 2) / 2)
		for thresholdIndex = 1, #SPAWN_EFFECT_SIZE_THRESHOLDS do
			local sizeThreshold = SPAWN_EFFECT_SIZE_THRESHOLDS[thresholdIndex]
			if sizeCategory > sizeThreshold.threshold then
				return SPAWN_EXPLOSION_CEGS[sizeThreshold.name]
			end
		end
		return SPAWN_EXPLOSION_CEGS.tiny
	end

	local poolUnitDefIDsByBaseName = {}
	for unitDefID = 1, #unitDefs do
		local unitDef = unitDefs[unitDefID]
		local customParams = unitDef.customParams ---@type table<string, any>
		setSetting(customParams, "zombie_wraith_respawn_chance", "wraithFeedSuccessChance")
		setSetting(customParams, "zombie_wraith_power_multiplier", "wraithPowerMultiplier")
		setSetting(customParams, "zombie_heap_respawn_delay_multiplier", "heapRespawnDelayMultiplier")
		setSetting(customParams, "zombie_factory_buildpower_tech_multiplier", "factoryBuildpowerTechMultiplier")
		setSetting(
			customParams,
			"zombie_wraith_spawn_max_units_per_spawn_multiplier",
			"wraithSpawnMaxUnitsPerSpawnMultiplier"
		)
		setSetting(customParams, "zombie_minimum_spawns", "initialSpawnCountMinimum")
		setSetting(customParams, "zombie_maximum_spawns", "initialSpawnCountMaximum")
		setSetting(customParams, "zombie_minimum_spawn_growth_rate", "minimumSpawnGrowthRate")
		setSetting(customParams, "zombie_maximum_spawn_growth_rate", "maximumSpawnGrowthRate")
		setSetting(customParams, "zombie_maximum_spawn_growth_delay", "maximumSpawnGrowthDelayMinutes")
		setSetting(customParams, "zombie_spawn_count_cap", "spawnCountCap")
		setSetting(customParams, "zombie_minutes_per_tech_level", "minutesPerTechLevel")
		setSetting(customParams, "zombie_tech_scaling_delay", "techScalingDelayMinutes")
		setSetting(customParams, "zombie_minimum_respawn_delay", "initialRespawnDelayMinimum")
		setSetting(customParams, "zombie_maximum_respawn_delay", "initialRespawnDelayMaximum")
		setSetting(customParams, "zombie_power_scale_rate", "powerScaleRate")
		setSetting(customParams, "zombie_bottom_band_delay", "bottomBandDelayMinutes")
		setSetting(customParams, "zombie_top_band_delay", "topBandDelayMinutes")
		setSetting(customParams, "zombie_respawn_decay_rate", "respawnDecayRate")
		setSetting(customParams, "zombie_respawn_decay_delay", "respawnDecayDelayMinutes")
		setSetting(customParams, "zombie_traditional_band_delay", "traditionalBandDelayMinutes")
		setSetting(customParams, "zombie_enable_wraith", "wraithRespawns", true)
		setSetting(customParams, "zombie_enable_hydra", "multipleSpawns", true)

		local rezPower = math.max(1, unitDef.power or 1)
		local isPoolMember = customParams.zombie_wraith_respawn_pool and true or false
		local unitDefData = {
			unitDefID = unitDefID,
			rezPower = rezPower,
			size = unitDef.xsize,
			isMobile = unitDef.speed > 0,
			isCommander = customParams.iscommander and true or false,
			isPoolMember = isPoolMember,
			forceRespawn = isPoolMember,
			expiryLifetimeFrames = getExpiryLifetimeFrames(unitDef, rezPower),
			excludedFromWraithSpawn = isExcludedFromWraithSpawn(unitDef),
			scavVariantUnitDefID = getScavVariantUnitDefID(unitDef, unitDefID),
			spawnExplosionCeg = getSpawnExplosionCeg(unitDef),
		}

		local customRespawnTime = tonumber(customParams.zombie_respawn_time)
		if customRespawnTime then
			if customRespawnTime < 0 then
				unitDefData.neverRespawn = true
			else
				unitDefData.customRespawnTime = customRespawnTime
			end
		end

		local captureOverride = customParams.scav_swap_override_captured
		if captureOverride == "delete" or unitDefNames[captureOverride] then
			unitDefData.captureOverride = captureOverride
		end

		local corpseFeatureDef = FeatureDefNames[unitDef.corpse]
		if corpseFeatureDef then
			unitDefData.corpseDefID = corpseFeatureDef.id
			local canCorpseRespawn = corpseFeatureDef.resurrectable ~= 0 or isPoolMember
			if canCorpseRespawn then
				claimZombieFeature(zombieCorpseDefs, corpseFeatureDef, unitDef, unitDefData)
			end
			local deathFeatureID = corpseFeatureDef.deathFeatureID
			local heapFeatureDef = (
				deathFeatureID
				and heapFeatureDefIDs[deathFeatureID]
				and FeatureDefs[deathFeatureID]
			) or FeatureDefNames[unitDef.name .. "_heap"]
			if heapFeatureDef then
				unitDefData.heapDefID = heapFeatureDef.id
				if canCorpseRespawn then
					claimZombieFeature(zombieHeapDefs, heapFeatureDef, unitDef, unitDefData)
				end
			end
		end
		zombieUnitDefs[unitDefID] = unitDefData

		if isPoolMember and unitDefData.corpseDefID then
			local baseName = string.gsub(unitDef.name, "_scav$", "")
			local existingUnitDefID = poolUnitDefIDsByBaseName[baseName]
			if not existingUnitDefID or unitDef.name == baseName then
				poolUnitDefIDsByBaseName[baseName] = unitDefID
			end
		end
	end

	local function markPoolMembership(unitDefID)
		local unitDefData = zombieUnitDefs[unitDefID]
		if unitDefData then
			unitDefData.isPoolMember = true
			unitDefData.forceRespawn = true
		end
	end

	for _, unitDefID in pairs(poolUnitDefIDsByBaseName) do
		wraithPoolUnitDefIDs[#wraithPoolUnitDefIDs + 1] = unitDefID
		local poolUnitDefData = zombieUnitDefs[unitDefID]
		markPoolMembership(unitDefID)
		if poolUnitDefData then
			markPoolMembership(poolUnitDefData.scavVariantUnitDefID)
		end
		local baseUnitName = string.gsub(unitDefs[unitDefID].name, "_scav$", "")
		local baseUnitDef = unitDefNames[baseUnitName] ---@as UnitDef?
		if baseUnitDef then
			markPoolMembership(baseUnitDef.id)
		end
	end
	table.sort(wraithPoolUnitDefIDs, compareUnitDefPower)

	local function sanitizePositiveRate(currentRate, defaultRate)
		if currentRate <= 0 then
			return defaultRate
		end
		return currentRate
	end

	zombieModeSettings.initialSpawnCountMinimum = math.max(1, floor(zombieModeSettings.initialSpawnCountMinimum))
	zombieModeSettings.initialSpawnCountMaximum =
		math.max(zombieModeSettings.initialSpawnCountMinimum, floor(zombieModeSettings.initialSpawnCountMaximum))
	zombieModeSettings.spawnCountCap =
		math.max(zombieModeSettings.initialSpawnCountMaximum, floor(zombieModeSettings.spawnCountCap))
	zombieModeSettings.maximumSpawnGrowthDelayMinutes = math.max(0, zombieModeSettings.maximumSpawnGrowthDelayMinutes)
	zombieModeSettings.techScalingDelayMinutes = math.max(0, zombieModeSettings.techScalingDelayMinutes)
	zombieModeSettings.minutesPerTechLevel = math.max(0, zombieModeSettings.minutesPerTechLevel)
	zombieModeSettings.initialRespawnDelayMinimum = math.max(0, zombieModeSettings.initialRespawnDelayMinimum)
	if zombieModeSettings.initialRespawnDelayMinimum > zombieModeSettings.initialRespawnDelayMaximum then
		zombieModeSettings.initialRespawnDelayMaximum = zombieModeSettings.initialRespawnDelayMinimum
	end
	zombieModeSettings.wraithFeedSuccessChance = clamp(zombieModeSettings.wraithFeedSuccessChance, 0, 1)
	zombieModeSettings.bottomBandDelayMinutes = math.max(0, zombieModeSettings.bottomBandDelayMinutes)
	zombieModeSettings.topBandDelayMinutes = math.max(0, zombieModeSettings.topBandDelayMinutes)
	zombieModeSettings.respawnDecayDelayMinutes = math.max(0, zombieModeSettings.respawnDecayDelayMinutes)
	zombieModeSettings.traditionalBandDelayMinutes = math.max(0, zombieModeSettings.traditionalBandDelayMinutes)
	zombieModeSettings.powerScaleRate = sanitizePositiveRate(zombieModeSettings.powerScaleRate, defaultPowerScaleRate)
	zombieModeSettings.respawnDecayRate =
		sanitizePositiveRate(zombieModeSettings.respawnDecayRate, defaultRespawnDecayRate)
	zombieModeSettings.minimumSpawnGrowthRate =
		sanitizePositiveRate(zombieModeSettings.minimumSpawnGrowthRate, defaultMinimumSpawnGrowthRate)
	zombieModeSettings.maximumSpawnGrowthRate =
		sanitizePositiveRate(zombieModeSettings.maximumSpawnGrowthRate, defaultMaximumSpawnGrowthRate)
end

local function isZombie(unitID)
	return zombieUnitIDs[unitID]
end

local function isZombieTeam(teamID)
	return teamID == gaiaTeamID or (scavTeamID ~= nil and teamID == scavTeamID)
end

local function setGaiaStorage()
	for resourceIndex = 1, #GAIA_RESOURCES do
		local resource = GAIA_RESOURCES[resourceIndex]
		local _, currentStorage = spring.GetTeamResources(gaiaTeamID, resource.resourceName)
		if currentStorage and currentStorage < GAIA_RESOURCE_AMOUNT then
			spring.SetTeamResource(gaiaTeamID, resource.storageKey, GAIA_RESOURCE_AMOUNT)
		end
	end
end

-- Commanders being available immediately in the beginning of the game can cause T3 to cancerously spawn via substitutes. We decrease the value in the beginning to compensate.
local function getSubstitutionPower(unitDefID)
	local unitDefData = zombieUnitDefs[unitDefID]
	if unitDefData.isCommander then
		return unitDefData.rezPower * COMMANDER_SUBSTITUTION_POWER_MULTIPLIER * currentTechLevel
	end
	return unitDefData.rezPower
end

local function addToFrameList(frameLists, frame, id)
	local list = frameLists[frame]
	if not list then
		list = {}
		frameLists[frame] = list
	end
	list[#list + 1] = id
end

local function removeFromFrameList(frameLists, frame, id)
	local list = frameLists[frame]
	if not list then
		return
	end
	for listIndex = 1, #list do
		if list[listIndex] == id then
			list[listIndex] = list[#list]
			list[#list] = nil
			if #list == 0 then
				frameLists[frame] = nil
			end
			return
		end
	end
end

local function getElapsedMinutes()
	return gameFrame / FRAMES.MINUTE
end

local function techLevelForPower(power)
	local powerThresholds = GG.PowerLib and GG.PowerLib.PowerThresholds
	local previousThreshold = powerThresholds and powerThresholds[1]
	if not previousThreshold then
		return BASE_TECH_LEVEL
	end
	for thresholdIndex = 2, #powerThresholds do
		local nextThreshold = powerThresholds[thresholdIndex]
		if power < nextThreshold.threshold then
			local powerSpan = nextThreshold.threshold - previousThreshold.threshold
			local blend = 0
			if powerSpan > 0 then
				blend = (power - previousThreshold.threshold) / powerSpan
			end
			return previousThreshold.techLevel + (nextThreshold.techLevel - previousThreshold.techLevel) * blend
		end
		previousThreshold = nextThreshold
	end
	return previousThreshold.techLevel
end

local function refreshCachedHighestPlayerTeamPower()
	if GG.PowerLib and GG.PowerLib.HighestPlayerTeamPower then
		cachedHighestPlayerTeamPower = GG.PowerLib.HighestPlayerTeamPower().power
	else
		cachedHighestPlayerTeamPower = 0
	end
end

local function bandMinutesFromPlayerPower()
	local techLevel = techLevelForPower(cachedHighestPlayerTeamPower)
	if getElapsedMinutes() < zombieModeSettings.techScalingDelayMinutes then
		techLevel = techLevel - BASE_TECH_LEVEL
	end
	local bandMinutes = (techLevel - BASE_TECH_LEVEL) * zombieModeSettings.minutesPerTechLevel
	if bandMinutes < 0 then
		return 0
	end
	return bandMinutes
end

local function getBandMinutes()
	return math.max(getElapsedMinutes(), bandMinutesFromPlayerPower())
end

local function powerBandThresholdsForMinutes(bandMinutes)
	local bandDelayMinutes = zombieModeSettings.traditionalBandDelayMinutes
	local bottomPowerThreshold = POWER_BAND.BOTTOM_START
		* zombieModeSettings.powerScaleRate
			^ math.max(0, bandMinutes - zombieModeSettings.bottomBandDelayMinutes - bandDelayMinutes)
	local topPowerThreshold = POWER_BAND.TOP_START
		* zombieModeSettings.powerScaleRate
			^ math.max(0, bandMinutes - zombieModeSettings.topBandDelayMinutes - bandDelayMinutes)
	return bottomPowerThreshold, topPowerThreshold
end

local function getGameStateScaleForPower(power, rangeMinimum, rangeMaximum)
	local bandMinutes = getBandMinutes()
	local bottomPowerThreshold, topPowerThreshold = powerBandThresholdsForMinutes(bandMinutes)
	if power <= bottomPowerThreshold then
		return rangeMinimum
	end
	if power >= topPowerThreshold then
		return rangeMaximum
	end
	local blend = (power - bottomPowerThreshold) / (topPowerThreshold - bottomPowerThreshold)
	return math.mix(rangeMinimum, rangeMaximum, 1 - (1 - blend) ^ 3)
end

local function getSpawnCountMaximum()
	local minutesAfterStart = math.max(0, getElapsedMinutes() - zombieModeSettings.maximumSpawnGrowthDelayMinutes)
	local grownMaximum = math.round(
		zombieModeSettings.initialSpawnCountMaximum * zombieModeSettings.maximumSpawnGrowthRate ^ minutesAfterStart,
		0
	)
	return math.min(zombieModeSettings.spawnCountCap, grownMaximum)
end

local function getSmallestPack()
	local minutesAfterStart = math.max(0, getElapsedMinutes() - zombieModeSettings.bottomBandDelayMinutes)
	local grownMinimum = math.round(
		zombieModeSettings.initialSpawnCountMinimum * zombieModeSettings.minimumSpawnGrowthRate ^ minutesAfterStart,
		0
	)
	return math.min(grownMinimum, getSpawnCountMaximum())
end

local function experienceAtThisMinute()
	local elapsedMinutes = getElapsedMinutes()
	if elapsedMinutes < EXPERIENCE_GROWTH.START_MINUTE then
		return 0
	end
	local experience = EXPERIENCE_GROWTH.MAXIMUM
		* EXPERIENCE_GROWTH.RATE ^ (elapsedMinutes - EXPERIENCE_GROWTH.CAP_MINUTE)
	if experience > EXPERIENCE_GROWTH.MAXIMUM then
		return EXPERIENCE_GROWTH.MAXIMUM
	end
	return experience
end

local function calculateSpawnDelayFrames(unitDefData)
	local decaySteps = math.max(0, getElapsedMinutes() - zombieModeSettings.respawnDecayDelayMinutes)
	local decay = zombieModeSettings.respawnDecayRate ^ decaySteps
	local minimumSpawnSeconds = zombieModeSettings.initialRespawnDelayMinimum * decay
	local maximumSpawnSeconds = zombieModeSettings.initialRespawnDelayMaximum * decay
	local spawnSeconds =
		math.round(getGameStateScaleForPower(unitDefData.rezPower, minimumSpawnSeconds, maximumSpawnSeconds), 0)
	return floor(spawnSeconds * Game.gameSpeed)
end

local function getUnitSpawnDelayFrames(unitDefData)
	if unitDefData.neverRespawn then
		return nil
	end
	if unitDefData.customRespawnTime then
		return floor(unitDefData.customRespawnTime * Game.gameSpeed)
	end
	return calculateSpawnDelayFrames(unitDefData)
end

local function setZombieFactoryBuildpower(unitID, useZombieBuildpower, unitDefID)
	local factoryData = zombieFactories[unitID]
	local resolvedUnitDefID = unitDefID or (factoryData and factoryData.unitDefID)
	local unitDef = resolvedUnitDefID and unitDefs[resolvedUnitDefID]
	if useZombieBuildpower and unitDef and unitDef.isFactory then
		spring.SetUnitBuildSpeed(unitID, unitDef.buildSpeed * factoryBuildpowerMultiplier)
		zombieFactories[unitID] = factoryData or { unitDefID = resolvedUnitDefID, baseBuildSpeed = unitDef.buildSpeed }
		return
	end
	if factoryData and spring.ValidUnitID(unitID) then
		spring.SetUnitBuildSpeed(unitID, factoryData.baseBuildSpeed)
	end
	zombieFactories[unitID] = nil
end

local function refreshZombieFactoryBuildpowers()
	for trackedUnitID, factoryData in pairs(zombieFactories) do
		local keepZombieBuildpower = spring.ValidUnitID(trackedUnitID)
			and spring.GetUnitTeam(trackedUnitID) == gaiaTeamID
		setZombieFactoryBuildpower(trackedUnitID, keepZombieBuildpower, factoryData.unitDefID)
	end
end

local function updateTechLevel()
	local techLevel = 1
	if GG.PowerLib and GG.PowerLib.TechGuesstimate then
		techLevel = GG.PowerLib.TechGuesstimate(cachedHighestPlayerTeamPower)
	end
	factoryBuildpowerMultiplier = zombieModeSettings.factoryBuildpowerTechMultiplier ^ techLevel
	currentTechLevel = techLevel
	refreshZombieFactoryBuildpowers()
	spring.SetGameRulesParam(RULES_PARAM.TECH_LEVEL, techLevel)
	spring.SetGameRulesParam(RULES_PARAM.FACTORY_BUILDPOWER_MULTIPLIER, factoryBuildpowerMultiplier)
end

local function updateTooLong(frame)
	if tooLong or frame < FRAMES.TOO_LONG then
		return
	end
	tooLong = true
	GG.Zombies.tooLong = true
	if GG.ZombieAI and GG.ZombieAI.EnablePermanentAggro then
		GG.ZombieAI.EnablePermanentAggro()
	end
end

local function getRandomRadiusOffset(radius, scale)
	local angle = random() * 2 * math.pi
	local distance = random() * radius * scale
	return math.cos(angle) * distance, math.sin(angle) * distance
end

local function spawnHeapUpcycleEffects(featureX, featureY, featureZ, radius)
	spring.SpawnCEG(EFFECT.HEAP_UPCYCLE_SMOKE, featureX, featureY, featureZ, 0, 1, 0, radius)
	for _ = 1, EFFECT.BURST_COUNT do
		local offsetX, offsetZ = getRandomRadiusOffset(radius, EFFECT.OFFSET_SCALE)
		local effectX = featureX + offsetX
		local effectZ = featureZ + offsetZ
		local effectY = spring.GetGroundHeight(effectX, effectZ)
		spring.SpawnCEG(EFFECT.HEAP_UPCYCLE_DIRT, effectX, effectY, effectZ, 0, 1, 0, radius * 0.5)
	end
end

local function playSpawnSound(spawnX, spawnY, spawnZ)
	local selectedSound = SPAWN_SOUNDS[random(#SPAWN_SOUNDS)] or SPAWN_SOUNDS[1]
	spring.PlaySoundFile(selectedSound, 0.5, spawnX, spawnY, spawnZ, 0)
end

local function clearCorpseRezRulesParam(featureID)
	spring.SetFeatureRulesParam(featureID, RULES_PARAM.REZ_FRAME, nil, RULES_PARAM.PUBLIC_ACCESS)
	spring.SetFeatureRulesParam(featureID, RULES_PARAM.REZ_ARM_FRAME, nil, RULES_PARAM.PUBLIC_ACCESS)
end

local function wasZombieCorpse(featureID, corpseData)
	if corpseData and corpseData.wasZombie then
		return true
	end
	local wasZombieParam = spring.GetFeatureRulesParam(featureID, RULES_PARAM.WAS_ZOMBIE)
	return wasZombieParam == 1
end

local function armCorpseSpawn(featureID, featureData, spawnFrame, armFrame)
	spawnFrame = math.max(spawnFrame, gameFrame + 1)
	local previousSpawnFrame = featureData.spawnFrame
	if previousSpawnFrame ~= spawnFrame then
		if previousSpawnFrame then
			removeFromFrameList(featureCheckFrames, previousSpawnFrame, featureID)
		end
		featureData.spawnFrame = spawnFrame
		addToFrameList(featureCheckFrames, spawnFrame, featureID)
	end
	spring.SetFeatureRulesParam(featureID, RULES_PARAM.REZ_FRAME, spawnFrame, RULES_PARAM.PUBLIC_ACCESS)
	if featureData.isHeap then
		return
	end
	local resolvedArmFrame = armFrame or featureData.creationFrame
	spring.SetFeatureRulesParam(featureID, RULES_PARAM.REZ_ARM_FRAME, resolvedArmFrame, RULES_PARAM.PUBLIC_ACCESS)
	if GG.ZombieWreckEffects then
		GG.ZombieWreckEffects.Arm(featureID, resolvedArmFrame, spawnFrame)
	end
end

local function disarmCorpseEffects(featureID, corpseData)
	if corpseData and corpseData.isHeap then
		return
	end
	if GG.ZombieWreckEffects then
		GG.ZombieWreckEffects.Disarm(featureID)
	end
end

local function pushBackCorpseSpawn(featureID, corpseData)
	local pushbackFrames = floor(corpseData.pushbackFrames)
	if pushbackFrames > 0 then
		corpseData.pushbackFrames = corpseData.pushbackFrames - pushbackFrames
		armCorpseSpawn(featureID, corpseData, corpseData.spawnFrame + pushbackFrames)
	end
end

local function publishPushedSpawn(featureID, corpseData)
	local shownSpawnFrame = floor((corpseData.spawnFrame or gameFrame) + (corpseData.pushbackFrames or 0))
	if shownSpawnFrame < gameFrame + 1 then
		shownSpawnFrame = gameFrame + 1
	end
	spring.SetFeatureRulesParam(featureID, RULES_PARAM.REZ_FRAME, shownSpawnFrame, RULES_PARAM.PUBLIC_ACCESS)
	if corpseData.isHeap or not GG.ZombieWreckEffects then
		return
	end
	GG.ZombieWreckEffects.Arm(featureID, gameFrame, shownSpawnFrame)
end

local function rollFor(keep, rollCount, minimum, maximum)
	local result = random(minimum, maximum)
	for _ = 2, rollCount do
		local roll = random(minimum, maximum)
		if (keep == PICK.LOWEST and roll < result) or (keep == PICK.HIGHEST and roll > result) then
			result = roll
		end
	end
	return result
end

local function calculateSpawnCount(unitDefID, inheritedExperience)
	local minuteExperience = experienceAtThisMinute()
	local budget = math.max(minuteExperience, inheritedExperience)
	if not currentModeFeatures.multipleSpawns then
		return 1, budget
	end

	local smallestPack = getSmallestPack()
	local spawnCountMaximum = getSpawnCountMaximum()
	local unitDefData = zombieUnitDefs[unitDefID]
	local advantage = math.round(
		getGameStateScaleForPower(unitDefData.rezPower, POWER_BAND.ADVANTAGE_AT_BOTTOM, POWER_BAND.ADVANTAGE_AT_TOP),
		0
	)
	local rollCount = 1 + math.abs(advantage)
	local keep = PICK.LOWEST
	if advantage > 0 then
		keep = PICK.HIGHEST
	end
	local spawnCount = rollFor(keep, rollCount, smallestPack, spawnCountMaximum)
	local experience = budget * smallestPack / spawnCount
	local veteranChance = EXPERIENCE_GROWTH.VETERAN_PACK_CHANCE * (1 - minuteExperience / EXPERIENCE_GROWTH.MAXIMUM)
	if random() < veteranChance then
		experience = experience + EXPERIENCE_GROWTH.ELITE_BONUS
	end
	return spawnCount, experience
end

local function registerZombie(unitID, unitDefID, transferToScavs)
	spring.SetUnitRulesParam(unitID, "zombie", 1)
	zombieUnitIDs[unitID] = true
	if transferToScavs and scavTeamID then
		spring.TransferUnit(unitID, scavTeamID)
	else
		local keepZombieBuildpower = spring.GetUnitTeam(unitID) ~= scavTeamID
		setZombieFactoryBuildpower(unitID, keepZombieBuildpower, unitDefID)
		if GG.ZombieAI then
			GG.ZombieAI.InitializeZombie(unitID, unitDefID)
		end
	end
	local expiryLifetimeFrames = zombieUnitDefs[unitDefID].expiryLifetimeFrames
	if expiryLifetimeFrames then
		addToFrameList(expiringBuildingFrames, gameFrame + expiryLifetimeFrames, unitID)
	end
end

---@return integer spawnedCount
local function spawnZombieUnits(unitDefID, spawnCount, spawnX, spawnY, spawnZ, facing, inheritedExperience)
	local unitDefData = zombieUnitDefs[unitDefID]
	if not unitDefData then
		return 0
	end
	local size = unitDefData.size
	local unitDefToCreate = unitDefData.scavVariantUnitDefID

	playSpawnSound(spawnX, spawnY, spawnZ)

	local spawnedCount = 0
	while spawnedCount < spawnCount do
		local offsetX = 0
		local offsetZ = 0
		if spawnCount > 1 then
			offsetX = random(-size * spawnCount, size * spawnCount)
			offsetZ = random(-size * spawnCount, size * spawnCount)
		end
		local randomX = clamp(spawnX + offsetX, size, Game.mapSizeX - size)
		local randomZ = clamp(spawnZ + offsetZ, size, Game.mapSizeZ - size)
		local adjustedY = spring.GetGroundHeight(randomX, randomZ)

		local unitID = spring.CreateUnit(unitDefToCreate, randomX, adjustedY, randomZ, facing, gaiaTeamID)
		if unitID then
			spring.SpawnCEG(unitDefData.spawnExplosionCeg, randomX, adjustedY, randomZ, 0, 0, 0)
			local spawnExperience = inheritedExperience or 0
			if spawnExperience > 0 then
				spring.SetUnitExperience(unitID, spawnExperience)
			end
			registerZombie(unitID, unitDefToCreate, true)
			spawnedCount = spawnedCount + 1
		else
			break
		end
	end
	return spawnedCount
end

local function resolveSpawnPlan(unitDefID, wasZombie, unitPower, spawnCount)
	if #wraithPoolUnitDefIDs == 0 or (wasZombie and zombieUnitDefs[unitDefID].isPoolMember) then
		return unitDefID, spawnCount, false
	end

	local borrowedPower = math.min(excessPower, unitPower)
	local totalPower = unitPower * spawnCount + borrowedPower
	local spawnCountMaximum = getSpawnCountMaximum()
	local wraithSpawnMaxUnits = math.ceil(spawnCountMaximum * zombieModeSettings.wraithSpawnMaxUnitsPerSpawnMultiplier)
	excessPower = excessPower - borrowedPower

	local lowestIndex
	local highestIndex
	for poolIndex = 1, #wraithPoolUnitDefIDs do
		local poolPower = zombieUnitDefs[wraithPoolUnitDefIDs[poolIndex]].rezPower
		if poolPower > totalPower then
			break
		end
		highestIndex = poolIndex
		if not lowestIndex and floor(totalPower / poolPower) <= wraithSpawnMaxUnits then
			lowestIndex = poolIndex
		end
	end
	if not highestIndex then
		excessPower = excessPower + totalPower
		return nil, 0, true
	end

	local substituteRollCount = WRAITH.SUBSTITUTE_ROLL_COUNT
	if gameFrame >= FRAMES.SUBSTITUTE_FAIR_ROLL then
		substituteRollCount = 1
	end
	local substituteIndex = rollFor(PICK.LOWEST, substituteRollCount, lowestIndex or highestIndex, highestIndex)
	local substituteUnitDefID = wraithPoolUnitDefIDs[substituteIndex]
	local substitutePower = zombieUnitDefs[substituteUnitDefID].rezPower
	local purchaseCount = math.min(floor(totalPower / substitutePower), spawnCountMaximum)
	excessPower = excessPower + totalPower - purchaseCount * substitutePower
	return substituteUnitDefID, purchaseCount, true
end

local function refundSubstitutePayload(payloadUnitDefID, payloadCount, isSubstitute)
	if isSubstitute and payloadUnitDefID and payloadCount > 0 then
		excessPower = excessPower + payloadCount * zombieUnitDefs[payloadUnitDefID].rezPower
	end
end

local function isScavUnitDefID(unitDefID)
	local unitDef = unitDefs[unitDefID] ---@as UnitDef?
	return nameEndsWithScav(unitDef and unitDef.name)
end

local function isScavFeature(featureID)
	local featureDefID = spring.GetFeatureDefID(featureID)
	local featureDef = featureDefID and FeatureDefs[featureDefID]
	local fromUnitName = featureDef and featureDef.customParams and featureDef.customParams.fromunit or ""
	return nameEndsWithScav(fromUnitName)
end

local function spawnZombies(unitDefID, spawnX, spawnY, spawnZ, facing, wasZombie, inheritedExperience, featureIsScav)
	local unitDefData = zombieUnitDefs[unitDefID]
	if not unitDefData then
		return
	end
	local sourceIsScav = featureIsScav == true or (featureIsScav == nil and isScavUnitDefID(unitDefID))
	local inherited = inheritedExperience or 0
	local spawnCount, experience = 1, math.max(inherited, experienceAtThisMinute())
	if not wasZombie and not sourceIsScav and unitDefData.isMobile then
		spawnCount, experience = calculateSpawnCount(unitDefID, inherited)
	end

	local spawnUnitDefID, plannedCount, isSubstitute
	if sourceIsScav then
		spawnUnitDefID, plannedCount, isSubstitute = unitDefID, 1, false
	else
		spawnUnitDefID, plannedCount, isSubstitute =
			resolveSpawnPlan(unitDefID, wasZombie, getSubstitutionPower(unitDefID), spawnCount)
	end
	if not spawnUnitDefID then
		return
	end
	local spawnedCount = spawnZombieUnits(spawnUnitDefID, plannedCount, spawnX, spawnY, spawnZ, facing, experience)
	refundSubstitutePayload(spawnUnitDefID, plannedCount - spawnedCount, isSubstitute)
end

local function spawnZombiesFromFeature(featureID, unitDefID, wasZombie)
	local featureX, featureY, featureZ = spring.GetFeaturePosition(featureID)
	if not featureX then
		return false
	end
	local inheritedExperience = spring.GetFeatureRulesParam(featureID, "previous_xp") or 0
	local facing = spring.GetFacingFromHeading(spring.GetFeatureHeading(featureID) or 0)
	local featureIsScav = isScavFeature(featureID)
	local corpseData = trackedFeatures[featureID]
	trackedFeatures[featureID] = nil
	wreckWraithFeeds[featureID] = nil
	disarmCorpseEffects(featureID, corpseData)
	spring.DestroyFeature(featureID)
	spawnZombies(unitDefID, featureX, featureY, featureZ, facing, wasZombie, inheritedExperience, featureIsScav)
	return true
end

---@return UnitID[]
local function getWraithIDsSortedAscending()
	local wraithIDs = {}
	for unitID in pairs(wraiths) do
		wraithIDs[#wraithIDs + 1] = unitID
	end
	table.sort(wraithIDs)
	return wraithIDs
end

local function removeWraith(unitID)
	if not wraiths[unitID] then
		return
	end
	wraiths[unitID] = nil
	spring.DestroyUnit(unitID, false, true)
end

local function getLiveAttackerPosition(attackerID, fallbackX, fallbackZ)
	if attackerID and attackerID >= 0 and spring.ValidUnitID(attackerID) and not spring.GetUnitIsDead(attackerID) then
		local attackerX, _, attackerZ = spring.GetUnitPosition(attackerID)
		if attackerX then
			return attackerX, attackerZ
		end
	end
	return fallbackX, fallbackZ
end

local function createWraith(spawnData)
	if not wraithUnitDefID then
		return nil
	end

	local wraithX = clamp(spawnData.x, WRAITH.MAP_MARGIN, Game.mapSizeX - WRAITH.MAP_MARGIN)
	local wraithZ = clamp(spawnData.z, WRAITH.MAP_MARGIN, Game.mapSizeZ - WRAITH.MAP_MARGIN)
	local wraithY = spring.GetGroundHeight(wraithX, wraithZ)
	local unitID = spring.CreateUnit(wraithUnitDefID, wraithX, wraithY, wraithZ, 0, gaiaTeamID)
	if not unitID then
		return nil
	end

	spring.SetUnitNeutral(unitID, true)
	spring.GiveOrderToUnit(unitID, CMD.FIRE_STATE, { 0 }, 0)
	if GG.SetWantedCloaked then
		GG.SetWantedCloaked(unitID, 1)
	else
		spring.SetUnitCloak(unitID, 1)
	end

	local fleeDuration = random(WRAITH.MIN_FLEE_TIME, WRAITH.MAX_FLEE_TIME)
	wraiths[unitID] = {
		readyFrame = gameFrame + fleeDuration,
		expirationFrame = gameFrame + WRAITH.EXPIRATION_TIME,
		payloadUnitDefID = spawnData.payloadUnitDefID,
		payloadCount = spawnData.payloadCount or 0,
	}
	local attackerX, attackerZ = getLiveAttackerPosition(spawnData.attackerID, spawnData.attackerX, spawnData.attackerZ)
	if GG.ZombieAI then
		GG.ZombieAI.CommandWraith(unitID, wraithUnitDefID, wraithX, wraithY, wraithZ, attackerX, attackerZ)
	end
	return unitID
end

local function makeWraithFeed(unitDefID, x, z, wasZombie, attackerID, attackerX, attackerZ)
	return {
		unitDefID = unitDefID,
		x = x,
		z = z,
		wasZombie = wasZombie,
		attackerID = attackerID,
		attackerX = attackerX,
		attackerZ = attackerZ,
	}
end

local function feedWraithQueue(unitDefID, spawnX, spawnZ, wasZombie, attackerID, attackerX, attackerZ)
	if not autoSpawningEnabled or not currentModeFeatures.wraithRespawns then
		return
	end
	local unitDefData = zombieUnitDefs[unitDefID]
	if
		not unitDefData
		or not unitDefData.isMobile
		or not unitDefData.corpseDefID
		or unitDefData.neverRespawn
		or unitDefData.excludedFromWraithSpawn
	then
		return
	end
	pendingWraithFeeds[#pendingWraithFeeds + 1] =
		makeWraithFeed(unitDefID, spawnX, spawnZ, wasZombie, attackerID, attackerX, attackerZ)
end

local function rememberWreckWraithFeed(
	featureID,
	unitDefID,
	featureX,
	featureZ,
	wasZombie,
	attackerID,
	attackerX,
	attackerZ
)
	if not featureID or not unitDefID or featureX == nil then
		return
	end
	wreckWraithFeeds[featureID] =
		makeWraithFeed(unitDefID, featureX, featureZ, wasZombie, attackerID, attackerX, attackerZ)
end

local function getWraithPayloadHeap(payloadUnitDefID)
	local payloadUnitDefData = payloadUnitDefID and zombieUnitDefs[payloadUnitDefID]
	if not payloadUnitDefData then
		return
	end
	local scavUnitDefID = payloadUnitDefData.scavVariantUnitDefID
	local scavUnitDefData = zombieUnitDefs[scavUnitDefID] or payloadUnitDefData
	local heapDefID = scavUnitDefData.heapDefID
	if not heapDefID or not zombieHeapDefs[heapDefID] then
		return
	end
	return heapDefID, scavUnitDefID, scavUnitDefData
end

local function processWraithFeeds()
	if #pendingWraithFeeds == 0 then
		return
	end
	local wraithFeeds = pendingWraithFeeds
	pendingWraithFeeds = {}
	for feedIndex = 1, #wraithFeeds do
		local wraithFeed = wraithFeeds[feedIndex]
		if random() <= zombieModeSettings.wraithFeedSuccessChance then
			local unitPower = getSubstitutionPower(wraithFeed.unitDefID) * zombieModeSettings.wraithPowerMultiplier
			local payloadUnitDefID, payloadCount, isSubstitute =
				resolveSpawnPlan(wraithFeed.unitDefID, wraithFeed.wasZombie, unitPower, 1)
			local heapDefID = getWraithPayloadHeap(payloadUnitDefID)
			if payloadUnitDefID and payloadCount > 0 and heapDefID then
				addToFrameList(pendingWraithSpawns, gameFrame + WRAITH.SPAWN_DELAY, {
					x = wraithFeed.x,
					z = wraithFeed.z,
					payloadUnitDefID = payloadUnitDefID,
					payloadCount = payloadCount,
					isSubstitute = isSubstitute,
					attackerID = wraithFeed.attackerID,
					attackerX = wraithFeed.attackerX,
					attackerZ = wraithFeed.attackerZ,
				})
			else
				refundSubstitutePayload(payloadUnitDefID, payloadCount or 0, isSubstitute)
			end
		end
	end
end

local function processDueWraithSpawns(frame)
	local spawns = pendingWraithSpawns[frame]
	if not spawns then
		return
	end
	pendingWraithSpawns[frame] = nil
	for spawnIndex = 1, #spawns do
		local spawn = spawns[spawnIndex]
		if not wraithUnitDefID then
			refundSubstitutePayload(spawn.payloadUnitDefID, spawn.payloadCount, spawn.isSubstitute)
		elseif not createWraith(spawn) then
			spawn.attempts = (spawn.attempts or 0) + 1
			if spawn.attempts >= WRAITH.SPAWN_ATTEMPT_COUNT then
				refundSubstitutePayload(spawn.payloadUnitDefID, spawn.payloadCount, spawn.isSubstitute)
			else
				addToFrameList(pendingWraithSpawns, frame + WRAITH.SPAWN_DELAY, spawn)
			end
		end
	end
end

local function expireDueBuildings(frame)
	local expiringBuildings = expiringBuildingFrames[frame]
	if not expiringBuildings then
		return
	end
	expiringBuildingFrames[frame] = nil
	for buildingIndex = 1, #expiringBuildings do
		local unitID = expiringBuildings[buildingIndex]
		local unitDefID = spring.ValidUnitID(unitID) and spring.GetUnitDefID(unitID)
		if unitDefID and isZombie(unitID) and zombieUnitDefs[unitDefID].expiryLifetimeFrames then
			suppressedDeaths[unitID] = true
			spring.DestroyUnit(unitID, false, true)
		end
	end
end

local function canSpawnUnitAt(unitDefID, spawnX, spawnY, spawnZ, facing)
	local unitDefData = zombieUnitDefs[unitDefID]
	if not unitDefData then
		return false
	end
	if unitDefData.isMobile then
		return spring.TestMoveOrder(unitDefID, spawnX, spawnY, spawnZ)
	end
	return spring.TestBuildOrder(unitDefID, spawnX, spawnY, spawnZ, facing) > 0
end

local function isPositionInLava(positionY)
	return DAMAGE.IS_LAVA and _G.lavaLevel ~= nil and positionY < _G.lavaLevel
end

local function isEnemyWithinRadius(positionX, positionY, positionZ, radius)
	return spring.GetClosestEnemyUnit(positionX, positionY, positionZ, radius, gaiaAllyTeamID, false) ~= nil
end

local function spawnHeapAtWraith(wraithData, wraithX, wraithZ, maxAttempts)
	local heapDefID, scavUnitDefID, scavUnitDefData = getWraithPayloadHeap(wraithData.payloadUnitDefID)
	if not heapDefID then
		return false
	end
	local size = scavUnitDefData.size
	for _ = 1, maxAttempts do
		local angle = random() * 2 * math.pi
		local distance = random() * WRAITH.SPAWN_OFFSET_DISTANCE
		local spawnX = clamp(wraithX + math.cos(angle) * distance, size, Game.mapSizeX - size)
		local spawnZ = clamp(wraithZ + math.sin(angle) * distance, size, Game.mapSizeZ - size)
		local spawnY = spring.GetGroundHeight(spawnX, spawnZ)
		local facing = random(0, 3)
		if
			not isPositionInLava(spawnY)
			and canSpawnUnitAt(scavUnitDefID, spawnX, spawnY, spawnZ, facing)
			and not isEnemyWithinRadius(spawnX, spawnY, spawnZ, WRAITH.ENEMY_CLEAR_RADIUS)
		then
			pendingCreatedFeatureData = {
				unitDefID = scavUnitDefID,
				facing = facing,
				wasZombie = true,
			}
			local featureID =
				spring.CreateFeature(heapDefID, spawnX, spawnY, spawnZ, spring.GetHeadingFromFacing(facing), gaiaTeamID)
			pendingCreatedFeatureData = nil
			if featureID then
				if trackedFeatures[featureID] then
					spring.SpawnCEG(scavUnitDefData.spawnExplosionCeg, spawnX, spawnY, spawnZ, 0, 0, 0)
					return true
				end
				spring.DestroyFeature(featureID)
			end
		end
	end
	return false
end

local function updateWraiths()
	local wraithIDs = getWraithIDsSortedAscending()
	for wraithIndex = 1, #wraithIDs do
		local unitID = wraithIDs[wraithIndex]
		local wraithData = wraiths[unitID]
		if wraithData then
			local wraithX, wraithY, wraithZ = spring.GetUnitPosition(unitID)
			if not wraithX or gameFrame >= wraithData.expirationFrame or (wraithData.payloadCount or 0) <= 0 then
				removeWraith(unitID)
			else
				local enemyNearby = false
				if GG.ZombieAI then
					enemyNearby = not not GG.ZombieAI.CommandWraith(unitID, wraithUnitDefID, wraithX, wraithY, wraithZ)
				else
					enemyNearby = isEnemyWithinRadius(wraithX, wraithY, wraithZ, WRAITH.ENEMY_CLEAR_RADIUS)
				end
				if gameFrame >= wraithData.readyFrame and not enemyNearby then
					local maxAttempts = 1
					if not wraithData.didExpandedDropSearch then
						wraithData.didExpandedDropSearch = true
						maxAttempts = WRAITH.SPAWN_ATTEMPT_COUNT
					end
					if spawnHeapAtWraith(wraithData, wraithX, wraithZ, maxAttempts) then
						wraithData.payloadCount = wraithData.payloadCount - 1
						if wraithData.payloadCount <= 0 then
							removeWraith(unitID)
						end
					end
				end
			end
		end
	end
end

local function replaceWithScavVariant(unitID, scavUnitDefID)
	local unitX, unitY, unitZ = spring.GetUnitPosition(unitID)
	local teamID = spring.GetUnitTeam(unitID)
	if not unitX or not teamID then
		return nil
	end
	local facing = spring.GetUnitBuildFacing(unitID) or 0
	local newUnitID = spring.CreateUnit(scavUnitDefID, unitX, unitY, unitZ, facing, teamID)
	if not newUnitID then
		return nil
	end

	spring.SetUnitExperience(newUnitID, spring.GetUnitExperience(unitID))

	suppressedDeaths[unitID] = true
	spring.DestroyUnit(unitID, false, true)
	return newUnitID
end

---Turns a unit into a zombie, swapping it for its `_scav` variant where one exists.
---@param unitID UnitID
local function setZombie(unitID)
	local unitDefID = spring.GetUnitDefID(unitID)
	if not unitDefID then
		return
	end

	local scavUnitDefID = zombieUnitDefs[unitDefID].scavVariantUnitDefID
	local scavUnitID = scavUnitDefID ~= unitDefID and replaceWithScavVariant(unitID, scavUnitDefID)
	if scavUnitID then
		unitID = scavUnitID
		unitDefID = scavUnitDefID
	end
	registerZombie(unitID, unitDefID, false)
end

local function wasTamperedRecently(tamperedFrame)
	return tamperedFrame and gameFrame - tamperedFrame < FRAMES.RECENT_TAMPER
end

local function framesUntilResurrectCompletes(featureID, buildStepFraction)
	local _, _, resurrectProgress = spring.GetFeatureHealth(featureID)
	if not resurrectProgress or buildStepFraction <= 0 then
		return nil
	end
	local progressPerFrame = buildStepFraction
	local rezCheck = zombieRezChecks[featureID]
	if rezCheck and rezCheck.frame < gameFrame then
		local measuredProgressPerFrame = (resurrectProgress - rezCheck.progress) / (gameFrame - rezCheck.frame)
		if measuredProgressPerFrame > progressPerFrame then
			progressPerFrame = measuredProgressPerFrame
		end
	end
	if not rezCheck or rezCheck.frame ~= gameFrame then
		zombieRezChecks[featureID] = { frame = gameFrame, progress = resurrectProgress }
	end
	if progressPerFrame <= 0 then
		return nil
	end
	return (1 - resurrectProgress) / progressPerFrame
end

function gadget:AllowFeatureBuildStep(builderID, builderTeam, featureID, featureDefID, buildStepFraction)
	if not runFeatureBuildStepCheck then
		return true
	end
	if isZombieTeam(builderTeam) then
		if buildStepFraction <= 0 or not zombieUnitIDs[builderID] then
			return true
		end
		local corpseDefData = zombieCorpseDefs[featureDefID]
		if not corpseDefData then
			return true
		end
		if rezzedCorpses[featureID] then
			return false
		end
		local corpseData = trackedFeatures[featureID]
		local tamperedFrame = pendingTamperedFrames[featureID]
		if not tamperedFrame and corpseData then
			tamperedFrame = corpseData.tamperedFrame
		end
		if wasTamperedRecently(tamperedFrame) then
			return true
		end
		local framesRemaining = framesUntilResurrectCompletes(featureID, buildStepFraction)
		if not framesRemaining or framesRemaining > FRAMES.REZ_HIJACK_LEAD then
			return true
		end
		rezzedCorpses[featureID] = true
		if spawnZombiesFromFeature(featureID, corpseDefData.unitDefID, wasZombieCorpse(featureID, corpseData)) then
			return false
		end
		rezzedCorpses[featureID] = nil
		return true
	end
	if trackedFeatures[featureID] then
		pendingTamperedFrames[featureID] = gameFrame
	end
	return true
end

local function isWraithFeedingDeath(unitID, unitDefID, weaponDefID)
	-- The crashing aircraft gadget finishes the crash with Spring.DestroyUnit, which reports KilledByLua.
	if weaponDefID == DAMAGE.KILLED_BY_LUA_DEF_ID and unitDefs[unitDefID].canFly then
		return not spring.GetUnitIsBeingBuilt(unitID)
	end
	if DEATHS_BLOCKING_WRAITHS[weaponDefID] then
		return false
	end
	return not spring.GetUnitIsBeingBuilt(unitID)
end

local function recordPendingDeath(unitID, unitDefID, weaponDefID, attackerID)
	if not zombieUnitDefs[unitDefID].corpseDefID then
		return
	end
	local unitX, _, unitZ = spring.GetUnitPosition(unitID)
	if not unitX then
		return
	end
	local attackerX
	local attackerZ
	if currentModeFeatures.wraithRespawns then
		attackerX, attackerZ = getLiveAttackerPosition(attackerID)
	end
	pendingDeaths[unitID] = {
		unitDefID = unitDefID,
		x = unitX,
		z = unitZ,
		wasZombie = isZombie(unitID),
		isDrowned = weaponDefID == DAMAGE.WATER_DEF_ID and not DAMAGE.IS_LAVA,
		feedsWraith = isWraithFeedingDeath(unitID, unitDefID, weaponDefID),
		attackerID = attackerID,
		attackerX = attackerX,
		attackerZ = attackerZ,
		timeoutFrame = gameFrame + FRAMES.PENDING_DEATH_TIMEOUT,
	}
end

local function corpseCanRespawn(featureID, corpseDefData)
	if not corpseDefData or corpseDefData.neverRespawn then
		return false
	end
	if corpseDefData.forceRespawn then
		return true
	end
	local resurrectUnitName = spring.GetFeatureResurrect(featureID)
	if resurrectUnitName ~= nil and resurrectUnitName ~= "" then
		return true
	end
	return isScavFeature(featureID)
end

local function queueZombieFeature(featureID, override, wasZombie, attackerID, attackerX, attackerZ, isHeap)
	if not override and not autoSpawningEnabled then
		return
	end
	if trackedFeatures[featureID] then
		return
	end

	local featureDefID = spring.GetFeatureDefID(featureID)
	local featureDefData = featureDefID and (isHeap and zombieHeapDefs or zombieCorpseDefs)[featureDefID]
	if isHeap then
		if not featureDefData or featureDefData.neverRespawn then
			return
		end
	elseif not corpseCanRespawn(featureID, featureDefData) then
		return
	end

	local spawnDelayFrames = getUnitSpawnDelayFrames(featureDefData)
	if spawnDelayFrames == nil then
		return
	end
	if isHeap then
		spawnDelayFrames = floor(spawnDelayFrames * zombieModeSettings.heapRespawnDelayMultiplier)
	end

	local featureX, _, featureZ = spring.GetFeaturePosition(featureID)
	if not featureX then
		return
	end

	wasZombie = wasZombie or wasZombieCorpse(featureID)
	if wasZombie then
		spring.SetFeatureRulesParam(featureID, RULES_PARAM.WAS_ZOMBIE, 1, RULES_PARAM.PUBLIC_ACCESS)
	end

	local rezFrameParam = spring.GetFeatureRulesParam(featureID, RULES_PARAM.REZ_FRAME)
	local existingRezFrame = rezFrameParam and tonumber(rezFrameParam)
	local spawnFrame = gameFrame + spawnDelayFrames
	if existingRezFrame and existingRezFrame > 0 then
		spawnFrame = floor(existingRezFrame)
	end

	local featureData = {
		featureDefID = featureDefID,
		spawnDelayFrames = spawnDelayFrames,
		creationFrame = gameFrame,
		tamperedFrame = FRAMES.UNTAMPERED,
		pushbackFrames = 0,
		wasZombie = wasZombie,
		isHeap = isHeap,
		x = featureX,
		z = featureZ,
		attackerID = attackerID,
		attackerX = attackerX,
		attackerZ = attackerZ,
	}
	trackedFeatures[featureID] = featureData
	armCorpseSpawn(featureID, featureData, spawnFrame)
	rememberWreckWraithFeed(
		featureID,
		featureDefData.unitDefID,
		featureX,
		featureZ,
		wasZombie,
		attackerID,
		attackerX,
		attackerZ
	)
end

local function spawnCorpseFromHeap(featureID, heapDefData, heapData)
	local corpseDefID = heapDefData and heapDefData.corpseDefID
	if not corpseDefID or not zombieCorpseDefs[corpseDefID] then
		return false
	end
	local featureX, featureY, featureZ = spring.GetFeaturePosition(featureID)
	if not featureX then
		return false
	end
	local remainingMetal = spring.GetFeatureResources(featureID)
	local remainingHealth = spring.GetFeatureHealth(featureID)
	local radius = spring.GetFeatureRadius(featureID) or 0
	local inheritedExperience = spring.GetFeatureRulesParam(featureID, "previous_xp") or 0
	local heading = spring.GetFeatureHeading(featureID) or 0
	local facing = spring.GetFacingFromHeading(heading)
	local wasZombie = wasZombieCorpse(featureID, heapData)
	local wreckFeed = wreckWraithFeeds[featureID]
	local attackerID = heapData and heapData.attackerID or (wreckFeed and wreckFeed.attackerID)
	local attackerX = heapData and heapData.attackerX or (wreckFeed and wreckFeed.attackerX)
	local attackerZ = heapData and heapData.attackerZ or (wreckFeed and wreckFeed.attackerZ)

	trackedFeatures[featureID] = nil
	wreckWraithFeeds[featureID] = nil
	disarmCorpseEffects(featureID, heapData)
	spring.DestroyFeature(featureID)
	spawnHeapUpcycleEffects(featureX, featureY, featureZ, radius)

	pendingCreatedFeatureData = {
		unitDefID = heapDefData.unitDefID,
		facing = facing,
		wasZombie = wasZombie,
		inheritedExperience = inheritedExperience,
		attackerID = attackerID,
		attackerX = attackerX,
		attackerZ = attackerZ,
	}
	local corpseFeatureID = spring.CreateFeature(corpseDefID, featureX, featureY, featureZ, heading, gaiaTeamID)
	pendingCreatedFeatureData = nil
	if not corpseFeatureID then
		return false
	end
	local corpseDefMetal = FeatureDefs[corpseDefID].metal
	if remainingMetal and corpseDefMetal and corpseDefMetal > 0 then
		spring.SetFeatureReclaim(corpseFeatureID, clamp(remainingMetal / corpseDefMetal, 0, 1))
	end
	local _, corpseMaxHealth = spring.GetFeatureHealth(corpseFeatureID)
	if remainingHealth and corpseMaxHealth and corpseMaxHealth > 0 then
		spring.SetFeatureHealth(corpseFeatureID, clamp(remainingHealth, 0, corpseMaxHealth))
	end
	return true
end

local function registerDeathFeature(featureID, featureDefID, deathData)
	local wasZombie = deathData and deathData.wasZombie
	local attackerID = deathData and deathData.attackerID
	local attackerX = deathData and deathData.attackerX
	local attackerZ = deathData and deathData.attackerZ
	if zombieCorpseDefs[featureDefID] then
		queueZombieFeature(featureID, false, wasZombie, attackerID, attackerX, attackerZ, false)
		return
	end
	if zombieHeapDefs[featureDefID] then
		queueZombieFeature(featureID, false, wasZombie, attackerID, attackerX, attackerZ, true)
		return
	end

	if not deathData or not deathData.feedsWraith then
		return
	end
	local featureX, _, featureZ = spring.GetFeaturePosition(featureID)
	if featureX ~= nil then
		if wasZombie then
			spring.SetFeatureRulesParam(featureID, RULES_PARAM.WAS_ZOMBIE, 1, RULES_PARAM.PUBLIC_ACCESS)
		end
		rememberWreckWraithFeed(
			featureID,
			deathData.unitDefID,
			featureX,
			featureZ,
			deathData.wasZombie,
			deathData.attackerID,
			deathData.attackerX,
			deathData.attackerZ
		)
	end
end

local function processWreckSwaps()
	if #pendingWreckSwaps == 0 then
		return
	end
	local wreckSwaps = pendingWreckSwaps
	pendingWreckSwaps = {}
	creatingForcedHeap = true
	for _, featureID in ipairs(wreckSwaps) do
		if spring.ValidFeatureID(featureID) then
			spring.CreateFeatureWreck(featureID, 1)
			spring.DestroyFeature(featureID)
		end
	end
	creatingForcedHeap = false
end

local function resolveVanishedDeaths()
	if next(pendingDeaths) == nil then
		return
	end
	local vanishedEntries = {}
	for unitID, deathData in pairs(pendingDeaths) do
		if spring.GetUnitIsDead(unitID) ~= true then
			pendingDeaths[unitID] = nil
			vanishedEntries[#vanishedEntries + 1] = {
				unitID = unitID,
				deathData = deathData,
			}
		elseif deathData.timeoutFrame < gameFrame then
			pendingDeaths[unitID] = nil
		end
	end
	table.sort(vanishedEntries, function(firstEntry, secondEntry)
		return firstEntry.unitID < secondEntry.unitID
	end)
	for vanishedIndex = 1, #vanishedEntries do
		local deathData = vanishedEntries[vanishedIndex].deathData
		if deathData.feedsWraith then
			feedWraithQueue(
				deathData.unitDefID,
				deathData.x,
				deathData.z,
				deathData.wasZombie,
				deathData.attackerID,
				deathData.attackerX,
				deathData.attackerZ
			)
		end
	end
end

local function processDueCorpse(featureID, frame)
	local corpseData = trackedFeatures[featureID]
	if not corpseData or corpseData.spawnFrame ~= frame then
		return
	end
	if not spring.ValidFeatureID(featureID) then
		trackedFeatures[featureID] = nil
		wreckWraithFeeds[featureID] = nil
		return
	end
	if corpseData.pushbackFrames >= 1 then
		pushBackCorpseSpawn(featureID, corpseData)
		return
	end
	if corpseData.isHeap then
		local _, heapY = spring.GetFeaturePosition(featureID)
		if heapY ~= nil and isPositionInLava(heapY) then
			armCorpseSpawn(featureID, corpseData, gameFrame + (corpseData.spawnDelayFrames or 0))
			return
		end
		local heapDefData = zombieHeapDefs[corpseData.featureDefID]
		if heapDefData then
			spawnCorpseFromHeap(featureID, heapDefData, corpseData)
		end
		return
	end
	local featureDefData = zombieCorpseDefs[corpseData.featureDefID]
	if featureDefData then
		spawnZombiesFromFeature(featureID, featureDefData.unitDefID, corpseData.wasZombie)
	end
end

local function processDueCorpses(frame)
	local featuresToCheck = featureCheckFrames[frame]
	if not featuresToCheck then
		return
	end
	featureCheckFrames[frame] = nil
	for _, featureID in ipairs(featuresToCheck) do
		processDueCorpse(featureID, frame)
	end
end

local function topUpGaiaResources()
	for resourceIndex = 1, #GAIA_RESOURCES do
		spring.AddTeamResource(gaiaTeamID, GAIA_RESOURCES[resourceIndex].resourceName, GAIA_RESOURCE_AMOUNT)
	end
end

local function publishPendingTamperedCorpses()
	if next(pendingTamperedFrames) == nil then
		return
	end
	local featureIDs = {}
	for featureID in pairs(pendingTamperedFrames) do
		featureIDs[#featureIDs + 1] = featureID
	end
	table.sort(featureIDs)
	for featureIndex = 1, #featureIDs do
		local featureID = featureIDs[featureIndex]
		local tamperedFrame = pendingTamperedFrames[featureID]
		pendingTamperedFrames[featureID] = nil
		local corpseData = trackedFeatures[featureID]
		if corpseData then
			corpseData.tamperedFrame = tamperedFrame
			local delayFrames = corpseData.spawnDelayFrames or 0
			local restartPushback = gameFrame + delayFrames - (corpseData.spawnFrame or gameFrame)
			if restartPushback < 0 then
				restartPushback = 0
			end
			if (corpseData.pushbackFrames or 0) < restartPushback then
				corpseData.pushbackFrames = restartPushback
			end
			publishPushedSpawn(featureID, corpseData)
		end
	end
end

function gadget:GameFrame(frame)
	gameFrame = frame
	refreshCachedHighestPlayerTeamPower()
	if frame % FRAMES.BUILD_STEP_CHECK == 5 then
		runFeatureBuildStepCheck = true
	else
		runFeatureBuildStepCheck = false
	end

	processWreckSwaps()
	if frame % FRAMES.VANISHED_DEATH_CHECK == 0 then
		resolveVanishedDeaths()
	end
	expireDueBuildings(frame)
	if currentModeFeatures.wraithRespawns then
		processWraithFeeds()
		processDueWraithSpawns(frame)
	end

	if frame % FRAMES.TECH_UPDATE == 0 then
		updateTechLevel()
	end

	if frame % FRAMES.CHECK_INTERVAL == 0 then
		publishPendingTamperedCorpses()
		updateTooLong(frame)
		if currentModeFeatures.wraithRespawns then
			updateWraiths()
		end
		topUpGaiaResources()
	end

	processDueCorpses(frame)
	if next(createdFeaturesByPosition) then
		createdFeaturesByPosition = {}
	end
end

local function handlePendingCreatedFeature(featureID, createdData)
	local featureDefID = spring.GetFeatureDefID(featureID)
	if not featureDefID then
		return
	end
	if createdData.wasZombie then
		spring.SetFeatureRulesParam(featureID, RULES_PARAM.WAS_ZOMBIE, 1, RULES_PARAM.PUBLIC_ACCESS)
	end
	if createdData.inheritedExperience and createdData.inheritedExperience > 0 then
		spring.SetFeatureRulesParam(featureID, "previous_xp", createdData.inheritedExperience)
	end
	local featureDef = FeatureDefs[featureDefID]
	if not zombieHeapDefs[featureDefID] and featureDef and featureDef.resurrectable ~= 0 and createdData.unitDefID then
		spring.SetFeatureResurrect(featureID, createdData.unitDefID, createdData.facing or 0)
	end
	if zombieHeapDefs[featureDefID] then
		queueZombieFeature(
			featureID,
			true,
			createdData.wasZombie,
			createdData.attackerID,
			createdData.attackerX,
			createdData.attackerZ,
			true
		)
	elseif zombieCorpseDefs[featureDefID] then
		queueZombieFeature(
			featureID,
			true,
			createdData.wasZombie,
			createdData.attackerID,
			createdData.attackerX,
			createdData.attackerZ,
			false
		)
	end
end

local function featurePositionKey(positionX, positionY, positionZ)
	return floor(positionX + 0.5) * WRECK_GRID.HASH_X
		+ floor(positionY + 0.5) * WRECK_GRID.HASH_Y
		+ floor(positionZ + 0.5) * WRECK_GRID.HASH_Z
end

local function rememberFeatureCreatedThisFrame(featureID)
	local featureX, featureY, featureZ = spring.GetFeaturePosition(featureID)
	if not featureX then
		return
	end
	local positionKey = featurePositionKey(featureX, featureY, featureZ)
	local bucket = createdFeaturesByPosition[positionKey]
	if not bucket then
		bucket = {}
		createdFeaturesByPosition[positionKey] = bucket
	end
	bucket[#bucket + 1] = {
		featureID = featureID,
		x = featureX,
		y = featureY,
		z = featureZ,
	}
end

local function wreckCellKey(cellX, cellZ)
	return cellX * WRECK_GRID.CELL_STRIDE + cellZ
end

local function addResurrectableWreck(featureID, featureX, featureY, featureZ)
	local cellX = floor(featureX / WRECK_GRID.CELL_SIZE)
	local cellZ = floor(featureZ / WRECK_GRID.CELL_SIZE)
	local cellKey = wreckCellKey(cellX, cellZ)
	local cell = resurrectableWreckCells[cellKey]
	if not cell then
		cell = {}
		resurrectableWreckCells[cellKey] = cell
	end
	local wreckIndex = #cell + 1
	cell[wreckIndex] = featureID -- buckets keep resurrectable wrecks only, so a query skips the trees and rocks on a forest map
	wreckCellIndex[featureID] = {
		cellKey = cellKey,
		index = wreckIndex,
		x = featureX,
		y = featureY,
		z = featureZ,
	}
end

local function removeResurrectableWreck(featureID)
	local trackedWreck = wreckCellIndex[featureID]
	if not trackedWreck then
		return
	end
	local cell = resurrectableWreckCells[trackedWreck.cellKey]
	local lastIndex = #cell
	local lastFeatureID = cell[lastIndex]
	cell[trackedWreck.index] = lastFeatureID
	cell[lastIndex] = nil
	if lastFeatureID ~= featureID then
		wreckCellIndex[lastFeatureID].index = trackedWreck.index
	end
	wreckCellIndex[featureID] = nil
	if lastIndex == 1 then
		resurrectableWreckCells[trackedWreck.cellKey] = nil
	end
end

local function trackResurrectableWreck(featureID)
	if wreckCellIndex[featureID] then
		return
	end
	local resurrectName = spring.GetFeatureResurrect(featureID)
	if not resurrectName or resurrectName == "" then
		return
	end
	local featureX, featureY, featureZ = spring.GetFeaturePosition(featureID)
	if not featureX then
		return
	end
	addResurrectableWreck(featureID, featureX, featureY, featureZ)
end

local function getRandomResurrectableWreck(originX, originZ, radius)
	local radiusSquared = radius * radius
	local minCellX = floor((originX - radius) / WRECK_GRID.CELL_SIZE)
	local maxCellX = floor((originX + radius) / WRECK_GRID.CELL_SIZE)
	local minCellZ = floor((originZ - radius) / WRECK_GRID.CELL_SIZE)
	local maxCellZ = floor((originZ + radius) / WRECK_GRID.CELL_SIZE)
	local chosenFeatureID
	local validWreckCount = 0
	for cellX = minCellX, maxCellX do
		for cellZ = minCellZ, maxCellZ do
			local cell = resurrectableWreckCells[wreckCellKey(cellX, cellZ)]
			if cell then
				for wreckIndex = 1, #cell do
					local featureID = cell[wreckIndex]
					local trackedWreck = wreckCellIndex[featureID]
					if trackedWreck and not isPositionInLava(trackedWreck.y) then
						local wreckDistanceSquared = distance2dSquared(originX, originZ, trackedWreck.x, trackedWreck.z)
						if wreckDistanceSquared <= radiusSquared then
							validWreckCount = validWreckCount + 1
							if random(1, validWreckCount) == 1 then
								chosenFeatureID = featureID
							end
						end
					end
				end
			end
		end
	end
	return chosenFeatureID
end

local function indexExistingResurrectableWrecks()
	local features = spring.GetAllFeatures()
	for featureIndex = 1, #features do
		trackResurrectableWreck(features[featureIndex])
	end
end

function gadget:FeatureCreated(featureID, _, sourceID)
	if pendingCreatedFeatureData then
		local createdData = pendingCreatedFeatureData
		pendingCreatedFeatureData = nil
		handlePendingCreatedFeature(featureID, createdData)
		trackResurrectableWreck(featureID)
		return
	end
	rememberFeatureCreatedThisFrame(featureID)
	if creatingForcedHeap then
		spring.SetFeatureRulesParam(featureID, RULES_PARAM.WAS_ZOMBIE, 1, RULES_PARAM.PUBLIC_ACCESS)
		queueZombieFeature(featureID, false, true, nil, nil, nil, true)
		trackResurrectableWreck(featureID)
		return
	end
	local featureDefID = spring.GetFeatureDefID(featureID)
	local deathData = sourceID and pendingDeaths[sourceID] or nil
	if deathData then
		pendingDeaths[sourceID] = nil
		local featureX, featureY, featureZ = spring.GetFeaturePosition(featureID)
		if
			deathData.wasZombie
			and featureDefID == zombieUnitDefs[deathData.unitDefID].corpseDefID
			and (deathData.isDrowned or (featureY ~= nil and isPositionInLava(featureY)))
		then
			if deathData.feedsWraith and featureX ~= nil then
				rememberWreckWraithFeed(
					featureID,
					deathData.unitDefID,
					featureX,
					featureZ,
					deathData.wasZombie,
					deathData.attackerID,
					deathData.attackerX,
					deathData.attackerZ
				)
			end
			pendingWreckSwaps[#pendingWreckSwaps + 1] = featureID
			trackResurrectableWreck(featureID)
			return
		end
	end
	registerDeathFeature(featureID, featureDefID, deathData)
	trackResurrectableWreck(featureID)
end

local function wasCorpseReclaimedOrResurrected(featureID)
	local remainingMetal, _, _, _, reclaimLeft = spring.GetFeatureResources(featureID)
	if (remainingMetal and remainingMetal <= 0) or (reclaimLeft and reclaimLeft <= 0) then
		return true
	end
	local _, _, resurrectProgress = spring.GetFeatureHealth(featureID)
	return resurrectProgress ~= nil and resurrectProgress >= 1
end

local function findSuccessorFeatureID(featureID, featureX, featureY, featureZ)
	local bucket = createdFeaturesByPosition[featurePositionKey(featureX, featureY, featureZ)]
	if not bucket then
		return
	end
	local successorFeatureID
	local successorX
	local successorZ
	for entryIndex = 1, #bucket do
		local entry = bucket[entryIndex]
		if entry.featureID ~= featureID and entry.x == featureX and entry.y == featureY and entry.z == featureZ then
			successorFeatureID = entry.featureID
			successorX = entry.x
			successorZ = entry.z
		end
	end
	return successorFeatureID, successorX, successorZ
end

local function releaseWreckWraithFeed(featureID)
	local wreckFeed = wreckWraithFeeds[featureID]
	wreckWraithFeeds[featureID] = nil
	if not wreckFeed or wasCorpseReclaimedOrResurrected(featureID) then
		return
	end
	local featureX, featureY, featureZ = spring.GetFeaturePosition(featureID)
	local corpseData = trackedFeatures[featureID]
	if corpseData then
		if corpseData.attackerX then
			wreckFeed.attackerID = corpseData.attackerID
			wreckFeed.attackerX = corpseData.attackerX
			wreckFeed.attackerZ = corpseData.attackerZ
		end
		wreckFeed.wasZombie = corpseData.wasZombie
		if featureX == nil and corpseData.x ~= nil then
			featureX = corpseData.x
			featureZ = corpseData.z
		end
	end
	if featureX ~= nil then
		wreckFeed.x = featureX
		wreckFeed.z = featureZ
	end
	local featureDefID = spring.GetFeatureDefID(featureID)
	local isHeap = featureDefID ~= nil and heapFeatureDefIDs[featureDefID] == true
	local successorFeatureID
	local successorX
	local successorZ
	if featureX ~= nil and featureY ~= nil and not isHeap then
		successorFeatureID, successorX, successorZ = findSuccessorFeatureID(featureID, featureX, featureY, featureZ)
	end
	if successorFeatureID then
		if successorX ~= nil then
			wreckFeed.x = successorX
			wreckFeed.z = successorZ
		end
		if wreckFeed.wasZombie then
			spring.SetFeatureRulesParam(successorFeatureID, RULES_PARAM.WAS_ZOMBIE, 1, RULES_PARAM.PUBLIC_ACCESS)
		end
		local inheritedExperience = spring.GetFeatureRulesParam(featureID, "previous_xp")
		if inheritedExperience and inheritedExperience > 0 then
			spring.SetFeatureRulesParam(successorFeatureID, "previous_xp", inheritedExperience)
		end
		local successorData = trackedFeatures[successorFeatureID]
		if successorData then
			successorData.wasZombie = wreckFeed.wasZombie
			successorData.attackerID = wreckFeed.attackerID
			successorData.attackerX = wreckFeed.attackerX
			successorData.attackerZ = wreckFeed.attackerZ
		end
		wreckWraithFeeds[successorFeatureID] = wreckFeed
		return
	end
	feedWraithQueue(
		wreckFeed.unitDefID,
		wreckFeed.x,
		wreckFeed.z,
		wreckFeed.wasZombie,
		wreckFeed.attackerID,
		wreckFeed.attackerX,
		wreckFeed.attackerZ
	)
end

function gadget:FeatureDamaged(featureID, _, _, _, _, _, attackerID)
	if not currentModeFeatures.wraithRespawns then
		return
	end
	local corpseData = trackedFeatures[featureID]
	if not corpseData then
		return
	end
	if
		corpseData.attackerID == attackerID
		and gameFrame - (corpseData.attackerSampleFrame or 0) < FRAMES.ATTACKER_SAMPLE
	then
		return
	end
	local attackerX, attackerZ = getLiveAttackerPosition(attackerID)
	if not attackerX then
		return
	end
	corpseData.attackerID = attackerID
	corpseData.attackerX = attackerX
	corpseData.attackerZ = attackerZ
	corpseData.attackerSampleFrame = gameFrame
end

function gadget:FeatureDestroyed(featureID, allyTeam)
	removeResurrectableWreck(featureID)
	releaseWreckWraithFeed(featureID)
	local corpseData = trackedFeatures[featureID]
	if corpseData then
		trackedFeatures[featureID] = nil
		disarmCorpseEffects(featureID, corpseData)
	end
	rezzedCorpses[featureID] = nil
	zombieRezChecks[featureID] = nil
	pendingTamperedFrames[featureID] = nil
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if unitDefID == wraithUnitDefID then
		spring.GiveOrderToUnit(unitID, CMD.IDLEMODE, { IDLEMODE_FLY }, 0)
	end
	if isZombieTeam(unitTeam) and builderID and isZombie(builderID) then
		zombiesBeingBuilt[unitID] = true
		spring.SetUnitRulesParam(unitID, "resurrected", 0, { inlos = true })
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if isZombieTeam(unitTeam) and zombiesBeingBuilt[unitID] then
		zombiesBeingBuilt[unitID] = nil
		setZombie(unitID)
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	local wasWraith = wraiths[unitID] ~= nil
	wraiths[unitID] = nil

	if not suppressedDeaths[unitID] and not wasWraith and unitDefID ~= wraithUnitDefID then
		recordPendingDeath(unitID, unitDefID, weaponDefID, attackerID)
	end

	suppressedDeaths[unitID] = nil
	pendingZombieCaptures[unitID] = nil
	unitTamperFrames[unitID] = nil
	zombiesBeingBuilt[unitID] = nil
	zombieUnitIDs[unitID] = nil
	setZombieFactoryBuildpower(unitID, false)
end

function gadget:AllowUnitCaptureStep(builderID, builderTeam, unitID, unitDefID, part)
	local tamperedFrame = unitTamperFrames[unitID]
	if zombieUnitIDs[builderID] and isZombieTeam(builderTeam) then
		if not wasTamperedRecently(tamperedFrame) then
			pendingZombieCaptures[unitID] = gameFrame
		end
		return true
	end
	pendingZombieCaptures[unitID] = nil
	if tamperedFrame and gameFrame - tamperedFrame < FRAMES.BUILD_STEP_CHECK then
		return true
	end
	unitTamperFrames[unitID] = gameFrame
	return true
end

function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	unitTamperFrames[unitID] = nil
	if newTeam ~= gaiaTeamID then
		setZombieFactoryBuildpower(unitID, false)
	end
	local captureFrame = pendingZombieCaptures[unitID]
	pendingZombieCaptures[unitID] = nil
	if not wasTamperedRecently(captureFrame) or not isZombieTeam(newTeam) or isZombie(unitID) then
		return
	end

	local unitX, unitY, unitZ = spring.GetUnitPosition(unitID)
	local inheritedExperience = spring.GetUnitExperience(unitID) or 0
	local facing = spring.GetUnitBuildFacing(unitID) or 0
	suppressedDeaths[unitID] = true
	spring.DestroyUnit(unitID, false, true)

	local spawnDefID = unitDefID
	local swapOverride = zombieUnitDefs[unitDefID].captureOverride
	if swapOverride then
		spawnDefID = swapOverride ~= "delete" and unitDefNames[swapOverride].id or nil
	end
	if unitX and spawnDefID then
		spawnZombies(spawnDefID, unitX, unitY, unitZ, facing, false, inheritedExperience)
	end
end

---Immediately raises zombies from a corpse feature. Only acts while in idle mode.
---@param featureID FeatureID
---@return boolean spawned `false` when not in idle mode, or the feature is not a zombie corpse.
local function createZombieFromFeature(featureID)
	if not isIdleMode then
		return false
	end
	local featureDefID = spring.GetFeatureDefID(featureID)
	local featureDefData = featureDefID and zombieCorpseDefs[featureDefID]
	if not featureDefData or not corpseCanRespawn(featureID, featureDefData) then
		return false
	end
	local wasZombie = wasZombieCorpse(featureID, trackedFeatures[featureID])
	return spawnZombiesFromFeature(featureID, featureDefData.unitDefID, wasZombie)
end

---Queues every corpse currently on the map to raise zombies.
local function queueAllCorpsesForSpawning()
	local features = spring.GetAllFeatures()
	for _, featureID in ipairs(features) do
		local featureDefID = spring.GetFeatureDefID(featureID)
		if zombieCorpseDefs[featureDefID] then
			queueZombieFeature(featureID, true, nil, nil, nil, nil, false)
		elseif zombieHeapDefs[featureDefID] then
			queueZombieFeature(featureID, true, nil, nil, nil, nil, true)
		end
	end
end

---Enables or disables raising zombies from corpses automatically.
---Enabling also queues every corpse already on the map.
---@param enabled boolean
local function setAutoSpawning(enabled)
	autoSpawningEnabled = enabled
	if enabled then
		queueAllCorpsesForSpawning()
	end
end

local function clearWraithState()
	local wraithIDs = getWraithIDsSortedAscending()
	for wraithIndex = 1, #wraithIDs do
		removeWraith(wraithIDs[wraithIndex])
	end
	pendingWraithFeeds = {}
	pendingWraithSpawns = {}
	wreckWraithFeeds = {}
	createdFeaturesByPosition = {}
end

---Drops every queued corpse spawn without affecting zombies already raised.
local function clearAllZombieSpawns()
	for featureID, featureData in pairs(trackedFeatures) do
		clearCorpseRezRulesParam(featureID)
		disarmCorpseEffects(featureID, featureData)
	end
	trackedFeatures = {}
	featureCheckFrames = {}
	excessPower = 0
	clearWraithState()
end

local function isAuthorized(playerID)
	if spring.IsCheatingEnabled() then
		return true
	end
	local permissions = _G.permissions
	if not permissions then
		return false
	end
	local playerName = spring.GetPlayerInfo(playerID)
	local accountID = BAR.Utilities.GetAccountID(playerID)
	local devHelpers = permissions.devhelpers
	if devHelpers and (devHelpers[accountID] or (playerName and devHelpers[playerName])) then
		return true
	end
	local director = permissions.director
	if director and (director[accountID] or (playerName and director[playerName])) then
		return true
	end
	return false
end

---Turns each of the given units into a zombie.
---@param unitIDs UnitID[]?
---@return integer converted Number of units that were valid and converted.
local function convertUnitsToZombies(unitIDs)
	if not unitIDs or #unitIDs == 0 then
		return 0
	end

	local convertedCount = 0
	for _, unitID in ipairs(unitIDs) do
		if spring.ValidUnitID(unitID) and not isZombie(unitID) then
			setZombie(unitID)
			convertedCount = convertedCount + 1
		end
	end

	return convertedCount
end

---Turns every Gaia-owned unit that is not already a zombie into one.
---@return integer converted
local function setAllGaiaToZombies()
	local allUnits = spring.GetAllUnits()
	local convertedCount = 0

	for _, unitID in ipairs(allUnits) do
		local unitTeam = spring.GetUnitTeam(unitID)
		if unitTeam == gaiaTeamID and not isZombie(unitID) and not wraiths[unitID] then
			setZombie(unitID)
			convertedCount = convertedCount + 1
		end
	end

	return convertedCount
end

---Returns `modeName` when it is a known zombie mode, otherwise the default mode.
---@param modeName string?
---@return ZombieMode
local function resolveZombieMode(modeName)
	if modeName and ZOMBIE_MODE_FEATURES[modeName] then
		return modeName ---@as ZombieMode
	end
	return DEFAULT_ZOMBIE_MODE
end

---Switches the zombie mode, removing wraiths when the new mode has no wraiths.
---@param modeName string
---@return boolean applied `false` when `modeName` is not a known mode.
local function setZombieMode(modeName)
	if not ZOMBIE_MODE_FEATURES[modeName] then
		return false
	end
	currentZombieMode = modeName
	currentModeFeatures = ZOMBIE_MODE_FEATURES[modeName]
	if not currentModeFeatures.wraithRespawns then
		clearWraithState()
	end
	return true
end

local function readToggleArgument(words, playerID, usageText)
	if #words == 0 then
		spring.SendMessageToPlayer(playerID, usageText)
		return nil
	end
	local enabled = tonumber(words[1])
	if enabled == nil or (enabled ~= 0 and enabled ~= 1) then
		spring.SendMessageToPlayer(playerID, "Invalid value. Use 0 to disable or 1 to enable")
		return nil
	end
	return enabled == 1
end

local function readNonNegativeID(words, playerID, usageText, invalidText)
	if #words == 0 then
		spring.SendMessageToPlayer(playerID, usageText)
		return nil
	end
	local targetID = tonumber(words[1])
	if not targetID or targetID < 0 then
		spring.SendMessageToPlayer(playerID, invalidText)
		return nil
	end
	return targetID
end

local ZOMBIE_CHAT_ACTIONS = {
	{
		name = "zombiesetallgaia",
		description = "Set all Gaia units as zombies",
		run = function(words, playerID)
			local convertedCount = setAllGaiaToZombies()
			spring.SendMessageToPlayer(playerID, "Set " .. convertedCount .. " Gaia units as zombies")
		end,
	},
	{
		name = "zombiequeueallcorpses",
		description = "Queue all corpses for spawning",
		run = function(words, playerID)
			queueAllCorpsesForSpawning()
			spring.SendMessageToPlayer(playerID, "Queued all corpses for spawning")
		end,
	},
	{
		name = "zombieautospawn",
		description = "Enable/disable auto spawning",
		run = function(words, playerID)
			local enabled = readToggleArgument(words, playerID, "Usage: /luarules zombieautospawn 0|1")
			if enabled == nil then
				return
			end
			setAutoSpawning(enabled)
			spring.SendMessageToPlayer(playerID, "Auto spawning " .. (enabled and "enabled" or "disabled"))
		end,
	},
	{
		name = "zombieclearspawns",
		description = "Clear all queued zombie spawns",
		run = function(words, playerID)
			clearAllZombieSpawns()
			spring.SendMessageToPlayer(playerID, "Cleared all queued zombie spawns")
		end,
	},
	{
		name = "zombiepacify",
		description = "Pacify/unpacify zombies",
		run = function(words, playerID)
			local enabled = readToggleArgument(words, playerID, "Usage: /luarules zombiepacify 0|1")
			if enabled == nil then
				return
			end
			GG.Zombies.PacifyZombies(enabled)
			spring.SendMessageToPlayer(playerID, "Zombies " .. (enabled and "pacified" or "unpacified"))
		end,
	},
	{
		name = "zombiesuspendorders",
		description = "Suspend/resume zombie auto-orders",
		run = function(words, playerID)
			local enabled = readToggleArgument(words, playerID, "Usage: /luarules zombiesuspendorders 0|1")
			if enabled == nil then
				return
			end
			GG.Zombies.SuspendAutoOrders(enabled)
			spring.SendMessageToPlayer(playerID, "Zombie auto-orders " .. (enabled and "suspended" or "resumed"))
		end,
	},
	{
		name = "zombieaggroteam",
		description = "Make zombies aggro to specific team",
		run = function(words, playerID)
			local targetTeamID =
				readNonNegativeID(words, playerID, "Usage: /luarules zombieaggroteam <teamID>", "Invalid team ID")
			if targetTeamID == nil then
				return
			end
			if GG.Zombies.AggroTeamID(targetTeamID) then
				spring.SendMessageToPlayer(playerID, "Zombies aggroed to team " .. targetTeamID)
			else
				spring.SendMessageToPlayer(playerID, "Team " .. targetTeamID .. " not found or has no units")
			end
		end,
	},
	{
		name = "zombieaggroally",
		description = "Make zombies aggro to entire ally team",
		run = function(words, playerID)
			local targetAllyID =
				readNonNegativeID(words, playerID, "Usage: /luarules zombieaggroally <allyID>", "Invalid ally ID")
			if targetAllyID == nil then
				return
			end
			if GG.Zombies.AggroAllyID(targetAllyID) then
				spring.SendMessageToPlayer(playerID, "Zombies aggroed to ally team " .. targetAllyID)
			else
				spring.SendMessageToPlayer(playerID, "Ally team " .. targetAllyID .. " not found or has no units")
			end
		end,
	},
	{
		name = "zombiekillall",
		description = "Kill all zombies",
		run = function(words, playerID)
			GG.Zombies.KillAllZombies()
			spring.SendMessageToPlayer(playerID, "Killed all zombies")
		end,
	},
	{
		name = "zombieclearallorders",
		description = "Clear all zombie orders",
		run = function(words, playerID)
			GG.Zombies.ClearAllOrders()
			spring.SendMessageToPlayer(playerID, "Cleared zombie orders")
		end,
	},
	{
		name = "zombiemode",
		description = "Set zombie mode (basic/wraith/hydra/akumu)",
		run = function(words, playerID)
			if #words == 0 then
				spring.SendMessageToPlayer(
					playerID,
					"Usage: /luarules zombiemode basic|wraith|hydra|akumu"
				)
				return
			end
			local mode = string.lower(words[1])
			if not setZombieMode(mode) then
				spring.SendMessageToPlayer(playerID, "Invalid mode. Use: basic, wraith, hydra, or akumu")
				return
			end
			spring.SendMessageToPlayer(playerID, "Zombie mode set to " .. mode)
		end,
	},
}

local RELOAD_STATE_RULES_PARAM = "zombie_reload_state"

local function saveReloadState()
	local serpent = require("common/luaUtilities/serpent")
	spring.SetGameRulesParam(
		RELOAD_STATE_RULES_PARAM,
		serpent.dump({
			gameFrame = gameFrame,
			zombieMode = currentZombieMode,
			autoSpawningEnabled = autoSpawningEnabled,
			tooLong = tooLong,
			currentTechLevel = currentTechLevel,
			excessPower = excessPower,
			wraiths = wraiths,
			pendingWraithFeeds = pendingWraithFeeds,
			pendingWraithSpawns = pendingWraithSpawns,
			wreckWraithFeeds = wreckWraithFeeds,
			zombieFactories = zombieFactories,
			expiringBuildingFrames = expiringBuildingFrames,
			trackedFeatures = trackedFeatures,
			featureCheckFrames = featureCheckFrames,
			zombieRezChecks = zombieRezChecks,
			pendingTamperedFrames = pendingTamperedFrames,
			pendingDeaths = pendingDeaths,
			pendingWreckSwaps = pendingWreckSwaps,
			pendingZombieCaptures = pendingZombieCaptures,
			unitTamperFrames = unitTamperFrames,
			zombiesBeingBuilt = zombiesBeingBuilt,
			zombieUnitIDs = zombieUnitIDs,
		})
	)
end

local function restoreReloadState()
	local savedState = spring.GetGameRulesParam(RELOAD_STATE_RULES_PARAM)
	if not savedState then
		return false
	end
	local serpent = require("common/luaUtilities/serpent")
	local loaded, reloadState = serpent.load(savedState)
	if not loaded or type(reloadState) ~= "table" or reloadState.gameFrame ~= gameFrame then
		return false
	end

	setZombieMode(resolveZombieMode(reloadState.zombieMode))
	autoSpawningEnabled = reloadState.autoSpawningEnabled
	tooLong = reloadState.tooLong
	currentTechLevel = reloadState.currentTechLevel or 1
	excessPower = reloadState.excessPower
	factoryBuildpowerMultiplier = zombieModeSettings.factoryBuildpowerTechMultiplier ^ currentTechLevel
	wraiths = reloadState.wraiths
	pendingWraithFeeds = reloadState.pendingWraithFeeds
	pendingWraithSpawns = reloadState.pendingWraithSpawns
	wreckWraithFeeds = reloadState.wreckWraithFeeds
	zombieFactories = reloadState.zombieFactories
	expiringBuildingFrames = reloadState.expiringBuildingFrames
	trackedFeatures = reloadState.trackedFeatures
	for _, corpseData in pairs(trackedFeatures) do
		corpseData.pushbackFrames = corpseData.pushbackFrames or 0
	end
	featureCheckFrames = reloadState.featureCheckFrames
	zombieRezChecks = reloadState.zombieRezChecks
	pendingTamperedFrames = reloadState.pendingTamperedFrames or {}
	pendingDeaths = reloadState.pendingDeaths
	pendingWreckSwaps = reloadState.pendingWreckSwaps
	pendingZombieCaptures = reloadState.pendingZombieCaptures
	unitTamperFrames = reloadState.unitTamperFrames
	zombiesBeingBuilt = reloadState.zombiesBeingBuilt
	zombieUnitIDs = reloadState.zombieUnitIDs
	refreshZombieFactoryBuildpowers()

	spring.SetGameRulesParam(RELOAD_STATE_RULES_PARAM, nil)
	return true
end

function gadget:Initialize()
	gameFrame = spring.GetGameFrame()
	spring.SetGameRulesParam(RULES_PARAM.ENABLED, true)

	if not restoreReloadState() then
		setZombieMode(resolveZombieMode(modOptions.zombies))
		updateTechLevel()

		autoSpawningEnabled = modOptionEnabled and not isIdleMode

		local units = spring.GetAllUnits()
		for _, unitID in ipairs(units) do
			local unitDefID = spring.GetUnitDefID(unitID)
			local isExistingWraith = wraithUnitDefID
				and unitDefID == wraithUnitDefID
				and spring.GetUnitTeam(unitID) == gaiaTeamID
			if isExistingWraith then
				spring.DestroyUnit(unitID, false, true)
			elseif spring.GetUnitRulesParam(unitID, "zombie") == 1 then
				setZombie(unitID)
			end
		end

		if not isIdleMode then
			local features = spring.GetAllFeatures()
			for _, featureID in ipairs(features) do
				gadget:FeatureCreated(featureID)
			end
		end
	end
	indexExistingResurrectableWrecks()

	GG.Zombies = { IdleMode = isIdleMode, tooLong = tooLong }
	GG.Zombies.GetRandomResurrectableWreck = getRandomResurrectableWreck
	GG.Zombies.SetZombie = setZombie
	GG.Zombies.ConvertUnitsToZombies = convertUnitsToZombies
	GG.Zombies.SetAllGaiaToZombies = setAllGaiaToZombies
	GG.Zombies.CreateZombieFromFeature = createZombieFromFeature
	GG.Zombies.QueueAllCorpsesForSpawning = queueAllCorpsesForSpawning
	GG.Zombies.SetAutoSpawning = setAutoSpawning
	GG.Zombies.ClearAllZombieSpawns = clearAllZombieSpawns
	GG.Zombies.SetZombieMode = setZombieMode
	GG.Zombies.GetZombieMode = function()
		return currentZombieMode
	end
	for methodIndex = 1, #ZOMBIE_AI_FORWARDED_METHOD_NAMES do
		local methodName = ZOMBIE_AI_FORWARDED_METHOD_NAMES[methodIndex]
		GG.Zombies[methodName] = function(...)
			local zombieAI = GG.ZombieAI
			if not zombieAI then
				return ZOMBIE_AI_MISSING_RESULTS[methodName]
			end
			return zombieAI[methodName](...)
		end
	end

	for _, chatAction in ipairs(ZOMBIE_CHAT_ACTIONS) do
		gadgetHandler:AddChatAction(chatAction.name, function(_, _, words, playerID)
			if not isAuthorized(playerID) then
				spring.SendMessageToPlayer(playerID, "You are not authorized to use zombie commands") --i18n library doesn't exist in gadget space.
				return
			end
			chatAction.run(words, playerID)
		end, chatAction.description)
	end
end

function gadget:Shutdown()
	for _, chatAction in ipairs(ZOMBIE_CHAT_ACTIONS) do
		gadgetHandler:RemoveChatAction(chatAction.name)
	end
	saveReloadState()
	spring.SetGameRulesParam(RULES_PARAM.ENABLED, nil)
end

function gadget:GameStart()
	setGaiaStorage()
end
