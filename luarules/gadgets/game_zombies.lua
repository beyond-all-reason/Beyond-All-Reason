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
--     this replaces the power-based delay. Spawn-count rolls still use the power-based delay.
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
-- exceed the maximum, the minimum respawn delay cannot exceed the maximum, wraith chance stays between
-- 0 and 1, and a resurrection speed multiplier of 0 or less is treated as 1.
--   zombie_minimum_spawns (integer, default 2)
--   zombie_maximum_spawns (integer, default 6)
--     the range rolled per corpse when multiple spawns are enabled. The maximum also caps how many
--     substitutes one spawn can buy.
--   zombie_minimum_respawn_delay (seconds, default 45)
--   zombie_maximum_respawn_delay (seconds, default 120)
--     the window that power-based revival times are clamped to.
--   zombie_wraith_respawn_chance (0 to 1, default 0.66)
--     the chance one of these destructions creates a wraith: a unit that leaves no wreck,
--     a corpse that leaves no heap, or a heap. Reclaim and resurrection do not count.
--     A failed roll leaves nothing behind.
--   zombie_wraith_power_multiplier (default 1)
--     multiplies a unit's power when a wraith respawn spends it on substitutes. Units that rise as
--     themselves are unchanged. Revived corpses and captures do not use this multiplier.
--   zombie_wraith_respawn_delay_multiplier (default 3)
--     multiplies the resurrection delay of each corpse a wraith drops.
--   zombie_factory_buildpower_tech_multiplier (default 1.7)
--     a Gaia zombie factory's buildpower is its build speed times this value raised to the current tech
--     level. Scavenger-team zombie factories keep their normal build speed.
--   zombie_rez_power_speed_multiplier (default 1)
--     multiplies the tech-level resurrection power speeds. Higher values shorten power-based revival delays.
--   zombie_wraith_spawn_max_units_per_spawn_multiplier (default 1)
--     scales how many copies a pool unit may take and still stay in the substitute roll range.
--     The permitted count is the spawn maximum times this value, rounded up.
--   zombie_enable_wraith (1 enables, 0 disables)
--     wraiths, in every mode.
--   zombie_enable_hydra (1 enables, 0 disables)
--     multiple spawns per corpse, in every mode.
--
-- What players see:
--   One revived unit appears on the wreck. When several rise from the same wreck, they scatter around it.
--   In every zombie mode, a heap becomes a corpse after twice the resurrection time. That corpse then
--     rises on the normal timer, so heap, corpse, then zombie takes three times as long.
--   Zombies on Gaia or the scavenger team resurrect wrecks, capture units, and finish construction as zombies.
--   A capture turns the unit into a zombie only when zombies made the capture. Another builder capturing it
--     cancels that, including a capture they started in the last second.
--   If the wraith unit cannot be created, the game tries twice more. After the third failure, a substitute
--     purchase is returned to the pool instead of being retried forever.
--   A wreck already waiting to rise keeps its timer when wrecks are queued again.

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
local clamp = math.clamp

local scavTeamID = BAR.Utilities.GetScavTeamID()
local gaiaTeamID = spring.GetGaiaTeamID()
local gaiaAllyTeamID = select(6, spring.GetTeamInfo(gaiaTeamID))

local zombieModeSettings = {
	spawnCountMinimum = 2,
	spawnCountMaximum = 6,
	respawnDelayMinimum = 45,
	respawnDelayMaximum = 120,
	wraithFeedSuccessChance = 0.66,
	wraithPowerMultiplier = 1,
	wraithRespawnDelayMultiplier = 3,
	heapRespawnDelayMultiplier = 2,
	factoryBuildpowerTechMultiplier = 1.7,
	rezPowerSpeedMultiplier = 1,
	wraithSpawnMaxUnitsPerSpawnMultiplier = 1,
}

---One of the zombie modes, matching the keys of `ZOMBIE_MODE_FEATURES`.
---@alias ZombieMode "basic"|"wraith"|"hydra"|"akumu"|"spidergeddon"

local ZOMBIE_MODE_FEATURES = {
	basic = {},
	wraith = { wraithRespawns = true },
	hydra = { multipleSpawns = true },
	akumu = { wraithRespawns = true, multipleSpawns = true },
	spidergeddon = { wraithRespawns = true, multipleSpawns = true },
}
local DEFAULT_ZOMBIE_MODE = "basic"

---@type ZombieMode
local currentZombieMode = DEFAULT_ZOMBIE_MODE
local currentModeFeatures = ZOMBIE_MODE_FEATURES[DEFAULT_ZOMBIE_MODE]
local autoSpawningEnabled = true

local TECH_TO_REZ_POWER_SPEEDS = { -- calibrated manually, spitballed numbers that seemed to be balanced.
	[0.5] = 1,
	[1] = 2,
	[1.5] = 5,
	[2] = 12,
	[2.5] = 38,
	[3] = 64,
	[3.5] = 86,
	[4] = 108,
	[4.5] = 130,
}
local TOO_LONG_GAME_FRAMES = Game.gameSpeed * 60 * 45
local ZOMBIE_CHECK_INTERVAL = Game.gameSpeed -- How often (in frames) everything else is checked
local REZ_SPEED_UPDATE_INTERVAL = Game.gameSpeed * 60

local gameFrame = 0
local tooLong = false
local adjustedRezPowerSpeed = TECH_TO_REZ_POWER_SPEEDS[1]
local factoryBuildpowerMultiplier = 1
local currentTechLevel = 1

local PICK_LOWEST = true
local PICK_HIGHEST = false
local SUBSTITUTE_FAIR_ROLL_FRAMES = Game.gameSpeed * 60 * 20
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

local ZOMBIE_EXPIRING_BUILDING_LIFETIME = Game.gameSpeed * 60 * 10 -- we don't want random zombie immobile trash taking up unit cap forever.
local ZOMBIE_PERMANENT_BUILDING_POWER_LIMIT = 5000 -- to preserve more impactful units
local ZOMBIE_EXPIRING_FACTORY_LIFETIME = Game.gameSpeed * 60 * 5

local UNTAMPERED_FRAME = -math.huge
local RECENT_TAMPER_FRAMES = Game.gameSpeed
local BUILD_STEP_CHECK_INTERVAL = floor(Game.gameSpeed / 3)
local ZOMBIE_REZ_HIJACK_LEAD_FRAMES = BUILD_STEP_CHECK_INTERVAL * 2.5

local WATER_DAMAGE_DEF_ID = Game.envDamageTypes.Water
local KILLED_BY_LUA_DAMAGE_DEF_ID = Game.envDamageTypes.KilledByLua
local WATER_IS_LAVA = BAR.Lava ~= nil and BAR.Lava.isLavaMap == true
local PENDING_DEATH_TIMEOUT_FRAMES = Game.gameSpeed * 3
local VANISHED_DEATH_CHECK_INTERVAL = 3
local DEATH_NAMES_BLOCKING_WRAITHS = {
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
local RULES_PARAM = {
	ENABLED = "zombies_enabled",
	TECH_LEVEL = "zombie_tech_level",
	REZ_POWER_SPEED = "zombie_rez_power_speed",
	FACTORY_BUILDPOWER_MULTIPLIER = "zombie_factory_buildpower_multiplier",
	REZ_FRAME = "zombie_rez_frame",
	REZ_DELAY = "zombie_rez_delay",
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
local featuresCreatedThisFrame = {}
local heapFeatureDefIDs = {}
local zombieFactories = {} ---@type table<UnitID, table?>
local expiringBuildingFrames = {}
local zombieUnitDefs = {}
local zombieCorpseDefs = {} ---@type table<FeatureDefID, table?>
local zombieHeapDefs = {} ---@type table<FeatureDefID, table?>
local corpsesData = {}
local corpseCheckFrames = {}
local rezzedCorpses = {}
local zombieRezChecks = {}
local pendingDeaths = {}
local vanishedDeaths = {}
local pendingWreckSwaps = {}
local suppressedDeaths = {}
local DEATHS_BLOCKING_WRAITHS = {}
local pendingZombieCaptures = {}
local unitTamperFrames = {}
local zombiesBeingBuilt = {}
local zombieUnitIDs = {}

for deathName, damageTypeID in pairs(Game.envDamageTypes) do
	DEATHS_BLOCKING_WRAITHS[damageTypeID] = DEATH_NAMES_BLOCKING_WRAITHS[deathName]
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
}
local HEAP_UPCYCLE_BURST_COUNT = 3
local HEAP_UPCYCLE_OFFSET_SCALE = 0.5
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

local UNAUTHORIZED_TEXT = "You are not authorized to use zombie commands" --i18n library doesn't exist in gadget space.
local ZOMBIE_AI_FORWARDED_METHODS = {
	{ methodName = "PacifyZombies" },
	{ methodName = "SuspendAutoOrders" },
	{ methodName = "AggroTeamID", missingResult = false },
	{ methodName = "AggroAllyID", missingResult = false },
	{ methodName = "KillAllZombies" },
	{ methodName = "ClearAllOrders" },
}

local function compareUnitDefPower(firstUnitDefID, secondUnitDefID)
	local firstPower = zombieUnitDefs[firstUnitDefID].rezPower
	local secondPower = zombieUnitDefs[secondUnitDefID].rezPower
	if firstPower == secondPower then
		return firstUnitDefID < secondUnitDefID
	end
	return firstPower < secondPower
end

do
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

	local function unitRequiresSpecificPlacement(unitDef)
		if unitDef.extractsMetal and unitDef.extractsMetal > 0 then
			return true
		end
		return unitDef.customParams.geothermal and true or false
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
			return ZOMBIE_EXPIRING_FACTORY_LIFETIME
		elseif unitDef.speed <= 0 and rezPower <= ZOMBIE_PERMANENT_BUILDING_POWER_LIMIT then
			return ZOMBIE_EXPIRING_BUILDING_LIFETIME
		end
	end

	local function getScavVariantUnitDefID(unitDef, unitDefID)
		if string.find(unitDef.name, "_scav") then
			return unitDefID
		end
		local scavUnitDef = unitDefNames[unitDef.name .. "_scav"]
		return scavUnitDef and scavUnitDef.id or unitDefID
	end

	local function featureFromUnitName(featureDef)
		local customParams = featureDef.customParams
		return customParams and customParams.fromunit or ""
	end

	local function claimZombieFeature(featureDefsByID, featureDef, unitDef, unitDefData)
		local existingUnitDefData = featureDefsByID[featureDef.id]
		if not existingUnitDefData then
			featureDefsByID[featureDef.id] = unitDefData
			return
		end
		local fromUnitName = featureFromUnitName(featureDef)
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
		setSetting(customParams, "zombie_wraith_respawn_delay_multiplier", "wraithRespawnDelayMultiplier")
		setSetting(customParams, "zombie_heap_respawn_delay_multiplier", "heapRespawnDelayMultiplier")
		setSetting(customParams, "zombie_factory_buildpower_tech_multiplier", "factoryBuildpowerTechMultiplier")
		setSetting(customParams, "zombie_rez_power_speed_multiplier", "rezPowerSpeedMultiplier")
		setSetting(customParams, "zombie_wraith_spawn_max_units_per_spawn_multiplier", "wraithSpawnMaxUnitsPerSpawnMultiplier")
		setSetting(customParams, "zombie_minimum_spawns", "spawnCountMinimum")
		setSetting(customParams, "zombie_maximum_spawns", "spawnCountMaximum")
		setSetting(customParams, "zombie_minimum_respawn_delay", "respawnDelayMinimum")
		setSetting(customParams, "zombie_maximum_respawn_delay", "respawnDelayMaximum")
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
			neverRespawn = unitRequiresSpecificPlacement(unitDef),
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

	for _, unitDefID in pairs(poolUnitDefIDsByBaseName) do
		wraithPoolUnitDefIDs[#wraithPoolUnitDefIDs + 1] = unitDefID
		local poolUnitDefData = zombieUnitDefs[unitDefID]
		poolUnitDefData.isPoolMember = true
		poolUnitDefData.forceRespawn = true
		local scavUnitDefID = poolUnitDefData.scavVariantUnitDefID
		local scavUnitDefData = zombieUnitDefs[scavUnitDefID]
		if scavUnitDefData and scavUnitDefID ~= unitDefID then
			scavUnitDefData.isPoolMember = true
			scavUnitDefData.forceRespawn = true
		end
		local baseUnitName = string.gsub(unitDefs[unitDefID].name, "_scav$", "")
		local baseUnitDef = unitDefNames[baseUnitName]
		local baseUnitDefData = baseUnitDef and zombieUnitDefs[baseUnitDef.id]
		if baseUnitDefData and baseUnitDef.id ~= unitDefID then
			baseUnitDefData.isPoolMember = true
			baseUnitDefData.forceRespawn = true
		end
	end
	table.sort(wraithPoolUnitDefIDs, compareUnitDefPower)

	zombieModeSettings.spawnCountMinimum = math.max(1, floor(zombieModeSettings.spawnCountMinimum))
	zombieModeSettings.spawnCountMaximum = math.max(
		zombieModeSettings.spawnCountMinimum,
		floor(zombieModeSettings.spawnCountMaximum)
	)
	zombieModeSettings.respawnDelayMinimum = math.max(0, zombieModeSettings.respawnDelayMinimum)
	if zombieModeSettings.respawnDelayMinimum > zombieModeSettings.respawnDelayMaximum then
		zombieModeSettings.respawnDelayMaximum = zombieModeSettings.respawnDelayMinimum
	end
	if zombieModeSettings.rezPowerSpeedMultiplier <= 0 then
		zombieModeSettings.rezPowerSpeedMultiplier = 1
	end
	zombieModeSettings.wraithFeedSuccessChance = clamp(zombieModeSettings.wraithFeedSuccessChance, 0, 1)
end

local function isZombie(unitID)
	return zombieUnitIDs[unitID] == true
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

local function calculateSpawnDelayFrames(unitPower)
	local spawnSeconds = clamp(
		floor(unitPower / adjustedRezPowerSpeed),
		zombieModeSettings.respawnDelayMinimum,
		zombieModeSettings.respawnDelayMaximum
	)
	return floor(spawnSeconds * Game.gameSpeed)
end

local function rebuildZombieCorpseSpawnDelays()
	for unitDefID = 1, #zombieUnitDefs do
		local unitDefData = zombieUnitDefs[unitDefID]
		unitDefData.powerSpawnDelayFrames = calculateSpawnDelayFrames(unitDefData.rezPower)
		if unitDefData.neverRespawn then
			unitDefData.spawnDelayFrames = nil
			unitDefData.heapSpawnDelayFrames = nil
		elseif unitDefData.customRespawnTime then
			unitDefData.spawnDelayFrames = floor(unitDefData.customRespawnTime * Game.gameSpeed)
			unitDefData.heapSpawnDelayFrames = floor(
				unitDefData.spawnDelayFrames * zombieModeSettings.heapRespawnDelayMultiplier
			)
		else
			unitDefData.spawnDelayFrames = unitDefData.powerSpawnDelayFrames
			unitDefData.heapSpawnDelayFrames = floor(
				unitDefData.spawnDelayFrames * zombieModeSettings.heapRespawnDelayMultiplier
			)
		end
	end
end

local function setZombieFactoryBuildpower(unitID, useZombieBuildpower, unitDefID)
	if not unitID then
		for trackedUnitID, factoryData in pairs(zombieFactories) do
			local keepZombieBuildpower = spring.ValidUnitID(trackedUnitID) and spring.GetUnitTeam(trackedUnitID) == gaiaTeamID
			setZombieFactoryBuildpower(trackedUnitID, keepZombieBuildpower, factoryData.unitDefID)
		end
		return
	end
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

local function updateRezSpeed()
	local techLevel = 1
	if GG.PowerLib and GG.PowerLib.HighestPlayerTeamPower and GG.PowerLib.TechGuesstimate then
		local highestPowerData = GG.PowerLib.HighestPlayerTeamPower()
		techLevel = GG.PowerLib.TechGuesstimate(highestPowerData.power)
	end
	local rezPowerSpeed = TECH_TO_REZ_POWER_SPEEDS[techLevel] or TECH_TO_REZ_POWER_SPEEDS[1]
	adjustedRezPowerSpeed = rezPowerSpeed * zombieModeSettings.rezPowerSpeedMultiplier
	factoryBuildpowerMultiplier = zombieModeSettings.factoryBuildpowerTechMultiplier ^ techLevel
	currentTechLevel = techLevel
	rebuildZombieCorpseSpawnDelays()
	setZombieFactoryBuildpower()
	spring.SetGameRulesParam(RULES_PARAM.TECH_LEVEL, techLevel)
	spring.SetGameRulesParam(RULES_PARAM.REZ_POWER_SPEED, adjustedRezPowerSpeed)
	spring.SetGameRulesParam(RULES_PARAM.FACTORY_BUILDPOWER_MULTIPLIER, factoryBuildpowerMultiplier)
end

local function updateTooLong(frame)
	if tooLong or frame < TOO_LONG_GAME_FRAMES then
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
	for _ = 1, HEAP_UPCYCLE_BURST_COUNT do
		local offsetX, offsetZ = getRandomRadiusOffset(radius, HEAP_UPCYCLE_OFFSET_SCALE)
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
	spring.SetFeatureRulesParam(featureID, RULES_PARAM.REZ_DELAY, nil, RULES_PARAM.PUBLIC_ACCESS)
end

local function wasZombieCorpse(featureID, corpseData)
	if corpseData and corpseData.wasZombie then
		return true
	end
	local wasZombieParam = spring.GetFeatureRulesParam(featureID, RULES_PARAM.WAS_ZOMBIE)
	return wasZombieParam == 1
end

local function armCorpseSpawn(featureID, featureData, spawnFrame)
	spawnFrame = math.max(spawnFrame, gameFrame + 1)
	featureData.spawnFrame = spawnFrame
	spring.SetFeatureRulesParam(featureID, RULES_PARAM.REZ_FRAME, spawnFrame, RULES_PARAM.PUBLIC_ACCESS)
	spring.SetFeatureRulesParam(featureID, RULES_PARAM.REZ_DELAY, featureData.spawnDelayFrames, RULES_PARAM.PUBLIC_ACCESS)
	addToFrameList(corpseCheckFrames, spawnFrame, featureID)
	if featureData.isHeap then
		return
	end
	if GG.ZombieWreckEffects then
		GG.ZombieWreckEffects.Arm(featureID, featureData.creationFrame, spawnFrame)
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

local function rollFor(keep, rollCount, minimum, maximum)
	local result = random(minimum, maximum)
	for _ = 2, rollCount do
		local roll = random(minimum, maximum)
		if (keep == PICK_LOWEST and roll < result) or (keep == PICK_HIGHEST and roll > result) then
			result = roll
		end
	end
	return result
end

local function calculateSpawnCount(unitDefID)
	if not currentModeFeatures.multipleSpawns then
		return 1
	end

	local rezTimeSeconds = zombieUnitDefs[unitDefID].powerSpawnDelayFrames / Game.gameSpeed
	local keep, rollCount = PICK_LOWEST, 1
	if currentTechLevel <= 1 then
		keep, rollCount = PICK_LOWEST, 3
	elseif rezTimeSeconds == zombieModeSettings.respawnDelayMinimum then
		keep, rollCount = PICK_HIGHEST, 2
	elseif rezTimeSeconds == zombieModeSettings.respawnDelayMaximum then
		keep, rollCount = PICK_LOWEST, 3
	end
	return rollFor(keep, rollCount, zombieModeSettings.spawnCountMinimum, zombieModeSettings.spawnCountMaximum)
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
local function spawnZombieUnits(
	unitDefID,
	spawnCount,
	spawnX,
	spawnY,
	spawnZ,
	facing,
	inheritedExperience
)
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
	local wraithSpawnMaxUnits = math.ceil(
		zombieModeSettings.spawnCountMaximum * zombieModeSettings.wraithSpawnMaxUnitsPerSpawnMultiplier
	)
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
	if gameFrame >= SUBSTITUTE_FAIR_ROLL_FRAMES then
		substituteRollCount = 1
	end
	local substituteIndex = rollFor(PICK_LOWEST, substituteRollCount, lowestIndex or highestIndex, highestIndex)
	local substituteUnitDefID = wraithPoolUnitDefIDs[substituteIndex]
	local substitutePower = zombieUnitDefs[substituteUnitDefID].rezPower
	local purchaseCount = math.min(floor(totalPower / substitutePower), zombieModeSettings.spawnCountMaximum)
	excessPower = excessPower + totalPower - purchaseCount * substitutePower
	return substituteUnitDefID, purchaseCount, true
end

local function retryFailedSubstitutes(substituteUnitDefID, failedCount)
	excessPower = excessPower + failedCount * zombieUnitDefs[substituteUnitDefID].rezPower
end

local function isScavUnitDefID(unitDefID)
	local unitDef = unitDefs[unitDefID]
	return unitDef ~= nil and string.sub(unitDef.name, -5) == "_scav"
end

local function isScavFeature(featureID)
	local featureDefID = spring.GetFeatureDefID(featureID)
	local featureDef = featureDefID and FeatureDefs[featureDefID]
	local fromUnitName = featureDef and featureDef.customParams and featureDef.customParams.fromunit or ""
	return string.sub(fromUnitName, -5) == "_scav"
end

local function spawnZombies(unitDefID, spawnX, spawnY, spawnZ, facing, wasZombie, inheritedExperience, featureIsScav)
	local unitDefData = zombieUnitDefs[unitDefID]
	if not unitDefData then
		return
	end
	local sourceIsScav = featureIsScav == true or (featureIsScav == nil and isScavUnitDefID(unitDefID))
	local spawnCount = 1
	if not wasZombie and not sourceIsScav and unitDefData.isMobile then
		spawnCount = calculateSpawnCount(unitDefID)
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
	local spawnedCount = spawnZombieUnits(
		spawnUnitDefID,
		plannedCount,
		spawnX,
		spawnY,
		spawnZ,
		facing,
		inheritedExperience
	)
	if isSubstitute then
		retryFailedSubstitutes(spawnUnitDefID, plannedCount - spawnedCount)
	end
end

local function spawnZombiesFromFeature(featureID, unitDefID, wasZombie)
	local featureX, featureY, featureZ = spring.GetFeaturePosition(featureID)
	if not featureX then
		return false
	end
	local inheritedExperience = spring.GetFeatureRulesParam(featureID, "previous_xp") or 0
	local facing = spring.GetFacingFromHeading(spring.GetFeatureHeading(featureID) or 0)
	local featureIsScav = isScavFeature(featureID)
	local corpseData = corpsesData[featureID]
	corpsesData[featureID] = nil
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

local function trackWraith(unitID, readyFrame, expirationFrame, payloadUnitDefID, payloadCount)
	wraiths[unitID] = {
		readyFrame = readyFrame,
		expirationFrame = expirationFrame,
		payloadUnitDefID = payloadUnitDefID,
		payloadCount = payloadCount or 0,
	}
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
	trackWraith(
		unitID,
		gameFrame + fleeDuration,
		gameFrame + WRAITH.EXPIRATION_TIME,
		spawnData.payloadUnitDefID,
		spawnData.payloadCount
	)
	local attackerX, attackerZ =
		getLiveAttackerPosition(spawnData.attackerID, spawnData.attackerX, spawnData.attackerZ)
	if GG.ZombieAI then
		GG.ZombieAI.CommandWraith(unitID, wraithUnitDefID, wraithX, wraithY, wraithZ, attackerX, attackerZ)
	end
	return unitID
end

local function feedWraithQueue(unitDefID, spawnX, spawnZ, wasZombie, attackerID, attackerX, attackerZ)
	if not autoSpawningEnabled or not currentModeFeatures.wraithRespawns then
		return
	end
	local unitDefData = zombieUnitDefs[unitDefID]
	if not unitDefData.isMobile or not unitDefData.corpseDefID or unitDefData.neverRespawn or unitDefData.excludedFromWraithSpawn then
		return
	end
	pendingWraithFeeds[#pendingWraithFeeds + 1] = {
		unitDefID = unitDefID,
		x = spawnX,
		z = spawnZ,
		wasZombie = wasZombie,
		attackerID = attackerID,
		attackerX = attackerX,
		attackerZ = attackerZ,
	}
end

local function rememberWreckWraithFeed(featureID, unitDefID, featureX, featureZ, wasZombie, attackerID, attackerX, attackerZ)
	if not featureID or not unitDefID or featureX == nil then
		return
	end
	wreckWraithFeeds[featureID] = {
		unitDefID = unitDefID,
		x = featureX,
		z = featureZ,
		wasZombie = wasZombie,
		attackerID = attackerID,
		attackerX = attackerX,
		attackerZ = attackerZ,
	}
end

local function refundSubstitutePayload(payloadUnitDefID, payloadCount, isSubstitute)
	if isSubstitute and payloadUnitDefID and payloadCount > 0 then
		excessPower = excessPower + payloadCount * zombieUnitDefs[payloadUnitDefID].rezPower
	end
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
			local payloadUnitDefData = payloadUnitDefID and zombieUnitDefs[payloadUnitDefID]
			local corpseDefID = payloadUnitDefData and payloadUnitDefData.corpseDefID
			if payloadUnitDefID and payloadCount > 0 and corpseDefID and zombieCorpseDefs[corpseDefID] then
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
			spring.DestroyUnit(unitID, true, false)
		end
	end
end

local function canSpawnUnitAt(unitDefID, spawnX, spawnY, spawnZ, facing)
	local unitDefData = zombieUnitDefs[unitDefID]
	if not unitDefData then
		return false
	end
	if unitDefData.isMobile then
		return spring.TestMoveOrder(unitDefID, spawnX, spawnY, spawnZ) and true or false
	end
	return spring.TestBuildOrder(unitDefID, spawnX, spawnY, spawnZ, facing) > 0
end

local function isPositionInLava(positionY)
	return WATER_IS_LAVA and _G.lavaLevel ~= nil and positionY < _G.lavaLevel
end

local function isEnemyWithinRadius(positionX, positionY, positionZ, radius)
	return spring.GetClosestEnemyUnit(positionX, positionY, positionZ, radius, gaiaAllyTeamID, false) ~= nil
end

local function spawnHeapAtWraith(wraithData, wraithX, wraithZ)
	local payloadUnitDefID = wraithData.payloadUnitDefID
	local payloadUnitDefData = payloadUnitDefID and zombieUnitDefs[payloadUnitDefID]
	if not payloadUnitDefData then
		return false
	end
	local scavUnitDefID = payloadUnitDefData.scavVariantUnitDefID
	local scavUnitDefData = zombieUnitDefs[scavUnitDefID] or payloadUnitDefData
	local heapDefID = scavUnitDefData.heapDefID
	local corpseDefID = scavUnitDefData.corpseDefID
	local hasHeapDef = heapDefID ~= nil and zombieHeapDefs[heapDefID] ~= nil
	local dropFeatureDefID = hasHeapDef and heapDefID or corpseDefID
	if not dropFeatureDefID or (not hasHeapDef and not zombieCorpseDefs[dropFeatureDefID]) then
		return false
	end
	local size = scavUnitDefData.size or payloadUnitDefData.size
	for _ = 1, WRAITH.SPAWN_ATTEMPT_COUNT do
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
				spawnDelayMultiplier = not hasHeapDef and zombieModeSettings.wraithRespawnDelayMultiplier or nil,
			}
			local featureID = spring.CreateFeature(
				dropFeatureDefID,
				spawnX,
				spawnY,
				spawnZ,
				spring.GetHeadingFromFacing(facing),
				gaiaTeamID
			)
			pendingCreatedFeatureData = nil
			if featureID then
				if corpsesData[featureID] then
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
					enemyNearby = GG.ZombieAI.CommandWraith(unitID, wraithUnitDefID, wraithX, wraithY, wraithZ) and true
						or false
				else
					enemyNearby = isEnemyWithinRadius(wraithX, wraithY, wraithZ, WRAITH.ENEMY_CLEAR_RADIUS)
				end
				if gameFrame >= wraithData.readyFrame and not enemyNearby and spawnHeapAtWraith(wraithData, wraithX, wraithZ) then
					wraithData.payloadCount = wraithData.payloadCount - 1
					if wraithData.payloadCount <= 0 then
						removeWraith(unitID)
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
	return tamperedFrame and gameFrame - tamperedFrame < RECENT_TAMPER_FRAMES
end

function gadget:AllowFeatureBuildStep(builderID, builderTeam, featureID, featureDefID, part)
	if part > 0 and isZombieTeam(builderTeam) and zombieUnitIDs[builderID] then
		local corpseDefData = zombieCorpseDefs[featureDefID]
		if not corpseDefData then
			return true
		end
		if rezzedCorpses[featureID] then
			return false
		end
		local corpseData = corpsesData[featureID]
		if corpseData and wasTamperedRecently(corpseData.tamperedFrame) then
			return true
		end
		local rezCheck = zombieRezChecks[featureID]
		if rezCheck and gameFrame - rezCheck.frame < BUILD_STEP_CHECK_INTERVAL then
			return true
		end
		local _, _, resurrectProgress = spring.GetFeatureHealth(featureID)
		local progressPerFrame = part
		if rezCheck then
			local measuredProgressPerFrame = (resurrectProgress - rezCheck.progress) / (gameFrame - rezCheck.frame)
			if measuredProgressPerFrame > progressPerFrame then
				progressPerFrame = measuredProgressPerFrame
			end
			rezCheck.frame = gameFrame
			rezCheck.progress = resurrectProgress
		else
			zombieRezChecks[featureID] = { frame = gameFrame, progress = resurrectProgress }
		end
		if resurrectProgress + progressPerFrame * ZOMBIE_REZ_HIJACK_LEAD_FRAMES < 1 then
			return true
		end
		local metal, maxMetal = spring.GetFeatureResources(featureID)
		if metal < maxMetal then
			return true
		end
		rezzedCorpses[featureID] = true
		if spawnZombiesFromFeature(featureID, corpseDefData.unitDefID, wasZombieCorpse(featureID, corpseData)) then
			return false
		end
		rezzedCorpses[featureID] = nil
		return true
	end
	local corpseData = corpsesData[featureID]
	if not corpseData then
		return true
	end
	corpseData.pushbackFrames = corpseData.pushbackFrames + math.abs(part) * corpseData.spawnDelayFrames
	if gameFrame - corpseData.tamperedFrame >= BUILD_STEP_CHECK_INTERVAL then
		corpseData.tamperedFrame = gameFrame
		pushBackCorpseSpawn(featureID, corpseData)
	end
	return true
end

local function isWraithFeedingDeath(unitID, unitDefID, weaponDefID)
	-- The crashing aircraft gadget finishes the crash with Spring.DestroyUnit, which reports KilledByLua.
	if weaponDefID == KILLED_BY_LUA_DAMAGE_DEF_ID and unitDefs[unitDefID].canFly then
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
	local attackerX, attackerZ = getLiveAttackerPosition(attackerID)
	pendingDeaths[unitID] = {
		unitDefID = unitDefID,
		x = unitX,
		z = unitZ,
		wasZombie = isZombie(unitID),
		isDrowned = weaponDefID == WATER_DAMAGE_DEF_ID and not WATER_IS_LAVA,
		feedsWraith = isWraithFeedingDeath(unitID, unitDefID, weaponDefID),
		attackerID = attackerID,
		attackerX = attackerX,
		attackerZ = attackerZ,
		timeoutFrame = gameFrame + PENDING_DEATH_TIMEOUT_FRAMES,
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

local function heapCanRespawn(heapDefData)
	if not heapDefData or heapDefData.neverRespawn or not heapDefData.heapSpawnDelayFrames then
		return false
	end
	return true
end

local function queueFeatureForSpawning(
	featureID,
	featureDefID,
	unitDefID,
	spawnDelayFrames,
	wasZombie,
	isHeap,
	attackerID,
	attackerX,
	attackerZ
)
	if corpsesData[featureID] then
		return
	end
	local featureX, _, featureZ = spring.GetFeaturePosition(featureID)
	if not featureX then
		return
	end

	wasZombie = wasZombie or wasZombieCorpse(featureID)
	if wasZombie then
		spring.SetFeatureRulesParam(featureID, RULES_PARAM.WAS_ZOMBIE, 1, RULES_PARAM.PUBLIC_ACCESS)
	end

	local existingRezFrame = spring.GetFeatureRulesParam(featureID, RULES_PARAM.REZ_FRAME)
	existingRezFrame = tonumber(existingRezFrame)
	local spawnFrame = gameFrame + (spawnDelayFrames or 0)
	if existingRezFrame and existingRezFrame > 0 then
		spawnFrame = floor(existingRezFrame)
	end

	local featureData = {
		featureDefID = featureDefID,
		spawnDelayFrames = spawnDelayFrames,
		creationFrame = gameFrame,
		tamperedFrame = UNTAMPERED_FRAME,
		pushbackFrames = 0,
		wasZombie = wasZombie,
		isHeap = isHeap,
		x = featureX,
		z = featureZ,
		attackerID = attackerID,
		attackerX = attackerX,
		attackerZ = attackerZ,
	}
	corpsesData[featureID] = featureData
	armCorpseSpawn(featureID, featureData, spawnFrame)
	rememberWreckWraithFeed(featureID, unitDefID, featureX, featureZ, wasZombie, attackerID, attackerX, attackerZ)
end

local function queueCorpseForSpawning(featureID, override, wasZombie, spawnDelayMultiplier, attackerID, attackerX, attackerZ)
	if not override and not autoSpawningEnabled then
		return
	end

	local featureDefID = spring.GetFeatureDefID(featureID)
	local corpseDefData = featureDefID and zombieCorpseDefs[featureDefID]
	if not corpseDefData or not corpseCanRespawn(featureID, corpseDefData) then
		return
	end

	local spawnDelayFrames = corpseDefData.spawnDelayFrames
	if spawnDelayFrames and spawnDelayMultiplier then
		spawnDelayFrames = floor(spawnDelayFrames * spawnDelayMultiplier)
	end
	queueFeatureForSpawning(
		featureID,
		featureDefID,
		corpseDefData.unitDefID,
		spawnDelayFrames,
		wasZombie,
		nil,
		attackerID,
		attackerX,
		attackerZ
	)
end

local function queueHeapForSpawning(featureID, override, wasZombie, attackerID, attackerX, attackerZ)
	if not override and not autoSpawningEnabled then
		return
	end

	local featureDefID = spring.GetFeatureDefID(featureID)
	local heapDefData = featureDefID and zombieHeapDefs[featureDefID]
	if not heapCanRespawn(heapDefData) then
		return
	end

	queueFeatureForSpawning(
		featureID,
		featureDefID,
		heapDefData.unitDefID,
		heapDefData.heapSpawnDelayFrames,
		wasZombie,
		true,
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
	local radius = spring.GetFeatureRadius(featureID) or 0
	local inheritedExperience = spring.GetFeatureRulesParam(featureID, "previous_xp") or 0
	local heading = spring.GetFeatureHeading(featureID) or 0
	local facing = spring.GetFacingFromHeading(heading)
	local wasZombie = wasZombieCorpse(featureID, heapData)
	local wreckFeed = wreckWraithFeeds[featureID]
	local attackerID = heapData and heapData.attackerID or (wreckFeed and wreckFeed.attackerID)
	local attackerX = heapData and heapData.attackerX or (wreckFeed and wreckFeed.attackerX)
	local attackerZ = heapData and heapData.attackerZ or (wreckFeed and wreckFeed.attackerZ)

	corpsesData[featureID] = nil
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
	return corpseFeatureID ~= nil
end

local function registerDeathFeature(featureID, featureDefID, deathData)
	local wasZombie = deathData and deathData.wasZombie
	local attackerID = deathData and deathData.attackerID
	local attackerX = deathData and deathData.attackerX
	local attackerZ = deathData and deathData.attackerZ
	if wasZombie then
		spring.SetFeatureRulesParam(featureID, RULES_PARAM.WAS_ZOMBIE, 1, RULES_PARAM.PUBLIC_ACCESS)
	end
	if zombieCorpseDefs[featureDefID] then
		queueCorpseForSpawning(featureID, false, wasZombie, nil, attackerID, attackerX, attackerZ)
		return
	end
	if zombieHeapDefs[featureDefID] then
		queueHeapForSpawning(featureID, false, wasZombie, attackerID, attackerX, attackerZ)
		return
	end

	if not deathData or not deathData.feedsWraith then
		return
	end
	local featureX, _, featureZ = spring.GetFeaturePosition(featureID)
	if featureX ~= nil then
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
	local vanishedUnitIDs = {}
	for unitID, deathData in pairs(pendingDeaths) do
		if spring.GetUnitIsDead(unitID) ~= true then
			pendingDeaths[unitID] = nil
			vanishedUnitIDs[#vanishedUnitIDs + 1] = unitID
			vanishedDeaths[unitID] = deathData
		elseif deathData.timeoutFrame < gameFrame then
			pendingDeaths[unitID] = nil
		end
	end
	table.sort(vanishedUnitIDs)
	for vanishedIndex = 1, #vanishedUnitIDs do
		local unitID = vanishedUnitIDs[vanishedIndex]
		local deathData = vanishedDeaths[unitID]
		vanishedDeaths[unitID] = nil
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
	local corpseData = corpsesData[featureID]
	if not corpseData or corpseData.spawnFrame ~= frame then
		return
	end
	if not spring.ValidFeatureID(featureID) then
		corpsesData[featureID] = nil
		wreckWraithFeeds[featureID] = nil
		return
	end
	if corpseData.pushbackFrames >= 1 then
		pushBackCorpseSpawn(featureID, corpseData)
		return
	end
	if corpseData.isHeap then
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
	local corpsesToCheck = corpseCheckFrames[frame]
	if not corpsesToCheck then
		return
	end
	for _, featureID in ipairs(corpsesToCheck) do
		processDueCorpse(featureID, frame)
	end
	corpseCheckFrames[frame] = nil
end

local function topUpGaiaResources()
	for resourceIndex = 1, #GAIA_RESOURCES do
		spring.AddTeamResource(gaiaTeamID, GAIA_RESOURCES[resourceIndex].resourceName, GAIA_RESOURCE_AMOUNT)
	end
end

function gadget:GameFrame(frame)
	gameFrame = frame

	processWreckSwaps()
	if frame % VANISHED_DEATH_CHECK_INTERVAL == 0 then
		resolveVanishedDeaths()
	end
	expireDueBuildings(frame)
	if currentModeFeatures.wraithRespawns then
		processWraithFeeds()
		processDueWraithSpawns(frame)
	end

	if frame % REZ_SPEED_UPDATE_INTERVAL == 0 then
		updateRezSpeed()
	end

	processDueCorpses(frame)

	if frame % ZOMBIE_CHECK_INTERVAL == 0 then
		updateTooLong(frame)
		if currentModeFeatures.wraithRespawns then
			updateWraiths()
		end
		topUpGaiaResources()
	end
	if #featuresCreatedThisFrame > 0 then
		featuresCreatedThisFrame = {}
	end
end

local function isFeatureInLava(featureID)
	if not WATER_IS_LAVA or not _G.lavaLevel then
		return false
	end
	local _, featureY = spring.GetFeaturePosition(featureID)
	return featureY ~= nil and featureY < _G.lavaLevel
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
		queueHeapForSpawning(
			featureID,
			true,
			createdData.wasZombie,
			createdData.attackerID,
			createdData.attackerX,
			createdData.attackerZ
		)
	elseif zombieCorpseDefs[featureDefID] then
		queueCorpseForSpawning(
			featureID,
			true,
			createdData.wasZombie,
			createdData.spawnDelayMultiplier,
			createdData.attackerID,
			createdData.attackerX,
			createdData.attackerZ
		)
	end
end

function gadget:FeatureCreated(featureID, _, sourceID)
	if pendingCreatedFeatureData then
		local createdData = pendingCreatedFeatureData
		pendingCreatedFeatureData = nil
		handlePendingCreatedFeature(featureID, createdData)
		return
	end
	featuresCreatedThisFrame[#featuresCreatedThisFrame + 1] = featureID
	if creatingForcedHeap then
		spring.SetFeatureRulesParam(featureID, RULES_PARAM.WAS_ZOMBIE, 1, RULES_PARAM.PUBLIC_ACCESS)
		queueHeapForSpawning(featureID, false, true)
		return
	end
	local featureDefID = spring.GetFeatureDefID(featureID)
	local deathData = sourceID and pendingDeaths[sourceID] or nil
	if deathData then
		pendingDeaths[sourceID] = nil
		if
			deathData.wasZombie
			and featureDefID == zombieUnitDefs[deathData.unitDefID].corpseDefID
			and (deathData.isDrowned or isFeatureInLava(featureID))
		then
			if deathData.feedsWraith then
				local featureX, _, featureZ = spring.GetFeaturePosition(featureID)
				if featureX ~= nil then
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
			pendingWreckSwaps[#pendingWreckSwaps + 1] = featureID
			return
		end
	end
	registerDeathFeature(featureID, featureDefID, deathData)
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
	local successorFeatureID
	for createdIndex = 1, #featuresCreatedThisFrame do
		local createdFeatureID = featuresCreatedThisFrame[createdIndex]
		if createdFeatureID ~= featureID then
			local createdX, createdY, createdZ = spring.GetFeaturePosition(createdFeatureID)
			if createdX == featureX and createdY == featureY and createdZ == featureZ then
				successorFeatureID = createdFeatureID
			end
		end
	end
	return successorFeatureID
end

local function releaseWreckWraithFeed(featureID)
	local wreckFeed = wreckWraithFeeds[featureID]
	wreckWraithFeeds[featureID] = nil
	if not wreckFeed or wasCorpseReclaimedOrResurrected(featureID) then
		return
	end
	local featureX, featureY, featureZ = spring.GetFeaturePosition(featureID)
	local corpseData = corpsesData[featureID]
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
	if featureX ~= nil and featureY ~= nil and not isHeap then
		successorFeatureID = findSuccessorFeatureID(featureID, featureX, featureY, featureZ)
	end
	if successorFeatureID then
		local successorX, _, successorZ = spring.GetFeaturePosition(successorFeatureID)
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
		local successorData = corpsesData[successorFeatureID]
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
	local corpseData = corpsesData[featureID]
	if not corpseData then
		return
	end
	local attackerX, attackerZ = getLiveAttackerPosition(attackerID)
	if not attackerX then
		return
	end
	corpseData.attackerID = attackerID
	corpseData.attackerX = attackerX
	corpseData.attackerZ = attackerZ
end

function gadget:FeatureDestroyed(featureID, allyTeam)
	releaseWreckWraithFeed(featureID)
	local corpseData = corpsesData[featureID]
	if corpseData then
		corpsesData[featureID] = nil
		disarmCorpseEffects(featureID, corpseData)
	end
	rezzedCorpses[featureID] = nil
	zombieRezChecks[featureID] = nil
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
	if tamperedFrame and gameFrame - tamperedFrame < BUILD_STEP_CHECK_INTERVAL then
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
	local capturedByZombie = captureFrame == true or wasTamperedRecently(captureFrame)
	if not capturedByZombie or not isZombieTeam(newTeam) or isZombie(unitID) then
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
	local wasZombie = wasZombieCorpse(featureID, corpsesData[featureID])
	return spawnZombiesFromFeature(featureID, featureDefData.unitDefID, wasZombie)
end

---Queues every corpse currently on the map to raise zombies.
local function queueAllCorpsesForSpawning()
	local features = spring.GetAllFeatures()
	for _, featureID in ipairs(features) do
		local featureDefID = spring.GetFeatureDefID(featureID)
		if zombieCorpseDefs[featureDefID] then
			queueCorpseForSpawning(featureID, true)
		elseif zombieHeapDefs[featureDefID] then
			queueHeapForSpawning(featureID, true)
		end
	end
end

local function callZombieAI(methodName, ...)
	local zombieAI = GG.ZombieAI
	if zombieAI then
		return zombieAI[methodName](...)
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
	featuresCreatedThisFrame = {}
end

---Drops every queued corpse spawn without affecting zombies already raised.
local function clearAllZombieSpawns()
	for featureID, featureData in pairs(corpsesData) do
		clearCorpseRezRulesParam(featureID)
		disarmCorpseEffects(featureID, featureData)
	end
	corpsesData = {}
	corpseCheckFrames = {}
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
		if spring.ValidUnitID(unitID) then
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

---Switches the live zombie mode, removing wraiths when the new mode has no wraiths.
---@param mode ZombieMode
local function applyZombieModeSettings(mode)
	currentZombieMode = mode
	currentModeFeatures = ZOMBIE_MODE_FEATURES[mode]
	if not currentModeFeatures.wraithRespawns then
		clearWraithState()
	end
end

---Switches the zombie mode.
---@param modeName string
---@return boolean applied `false` when `modeName` is not a known mode.
local function setZombieMode(modeName)
	if not ZOMBIE_MODE_FEATURES[modeName] then
		return false
	end
	applyZombieModeSettings(modeName)
	return true
end

local function getZombieMode()
	return currentZombieMode
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
			callZombieAI("PacifyZombies", enabled)
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
			callZombieAI("SuspendAutoOrders", enabled)
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
			local success = callZombieAI("AggroTeamID", targetTeamID)
			if success then
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
			local success = callZombieAI("AggroAllyID", targetAllyID)
			if success then
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
			callZombieAI("KillAllZombies")
			spring.SendMessageToPlayer(playerID, "Killed all zombies")
		end,
	},
	{
		name = "zombieclearallorders",
		description = "Clear all zombie orders",
		run = function(words, playerID)
			callZombieAI("ClearAllOrders")
			spring.SendMessageToPlayer(playerID, "Cleared zombie orders")
		end,
	},
	{
		name = "zombiemode",
		description = "Set zombie mode (basic/wraith/hydra/akumu/spidergeddon)",
		run = function(words, playerID)
			if #words == 0 then
				spring.SendMessageToPlayer(
					playerID,
					"Usage: /luarules zombiemode basic|wraith|hydra|akumu|spidergeddon"
				)
				return
			end
			local mode = string.lower(words[1])
			if not setZombieMode(mode) then
				spring.SendMessageToPlayer(
					playerID,
					"Invalid mode. Use: basic, wraith, hydra, akumu, or spidergeddon"
				)
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
			adjustedRezPowerSpeed = adjustedRezPowerSpeed,
			currentTechLevel = currentTechLevel,
			excessPower = excessPower,
			wraiths = wraiths,
			pendingWraithFeeds = pendingWraithFeeds,
			pendingWraithSpawns = pendingWraithSpawns,
			wreckWraithFeeds = wreckWraithFeeds,
			zombieFactories = zombieFactories,
			expiringBuildingFrames = expiringBuildingFrames,
			corpsesData = corpsesData,
			corpseCheckFrames = corpseCheckFrames,
			zombieRezChecks = zombieRezChecks,
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

	applyZombieModeSettings(resolveZombieMode(reloadState.zombieMode))
	autoSpawningEnabled = reloadState.autoSpawningEnabled
	tooLong = reloadState.tooLong
	adjustedRezPowerSpeed = reloadState.adjustedRezPowerSpeed
	currentTechLevel = reloadState.currentTechLevel or 1
	excessPower = reloadState.excessPower
	factoryBuildpowerMultiplier = zombieModeSettings.factoryBuildpowerTechMultiplier ^ currentTechLevel
	wraiths = reloadState.wraiths
	pendingWraithFeeds = reloadState.pendingWraithFeeds
	pendingWraithSpawns = reloadState.pendingWraithSpawns
	wreckWraithFeeds = reloadState.wreckWraithFeeds
	zombieFactories = reloadState.zombieFactories
	expiringBuildingFrames = reloadState.expiringBuildingFrames
	corpsesData = reloadState.corpsesData
	for _, corpseData in pairs(corpsesData) do
		corpseData.pushbackFrames = corpseData.pushbackFrames or 0
	end
	corpseCheckFrames = reloadState.corpseCheckFrames
	zombieRezChecks = reloadState.zombieRezChecks
	pendingDeaths = reloadState.pendingDeaths
	pendingWreckSwaps = reloadState.pendingWreckSwaps
	pendingZombieCaptures = reloadState.pendingZombieCaptures
	unitTamperFrames = reloadState.unitTamperFrames
	zombiesBeingBuilt = reloadState.zombiesBeingBuilt
	zombieUnitIDs = reloadState.zombieUnitIDs
	rebuildZombieCorpseSpawnDelays()
	setZombieFactoryBuildpower()

	spring.SetGameRulesParam(RELOAD_STATE_RULES_PARAM, nil)
	return true
end

function gadget:Initialize()
	gameFrame = spring.GetGameFrame()
	spring.SetGameRulesParam(RULES_PARAM.ENABLED, true)

	if not restoreReloadState() then
		applyZombieModeSettings(resolveZombieMode(modOptions.zombies))
		updateRezSpeed()

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

	GG.Zombies = { IdleMode = isIdleMode, tooLong = tooLong }
	GG.Zombies.SetZombie = setZombie
	GG.Zombies.ConvertUnitsToZombies = convertUnitsToZombies
	GG.Zombies.SetAllGaiaToZombies = setAllGaiaToZombies
	GG.Zombies.CreateZombieFromFeature = createZombieFromFeature
	GG.Zombies.QueueAllCorpsesForSpawning = queueAllCorpsesForSpawning
	GG.Zombies.SetAutoSpawning = setAutoSpawning
	GG.Zombies.ClearAllZombieSpawns = clearAllZombieSpawns
	GG.Zombies.SetZombieMode = setZombieMode
	GG.Zombies.GetZombieMode = getZombieMode
	for methodIndex = 1, #ZOMBIE_AI_FORWARDED_METHODS do
		local forwardedMethod = ZOMBIE_AI_FORWARDED_METHODS[methodIndex]
		local methodName = forwardedMethod.methodName
		GG.Zombies[methodName] = function(...)
			local zombieAI = GG.ZombieAI
			if not zombieAI then
				return forwardedMethod.missingResult
			end
			return zombieAI[methodName](...)
		end
	end

	for _, chatAction in ipairs(ZOMBIE_CHAT_ACTIONS) do
		gadgetHandler:AddChatAction(chatAction.name, function(_, _, words, playerID)
			if not isAuthorized(playerID) then
				spring.SendMessageToPlayer(playerID, UNAUTHORIZED_TEXT)
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
