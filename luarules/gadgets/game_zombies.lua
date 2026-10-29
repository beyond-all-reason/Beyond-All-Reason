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
--     pool entry. Pool units that were already zombies rise as themselves instead of being substituted.
--   scav_swap_override_captured (unit name or "delete")
--     when the unit is captured by zombies, it becomes the named unit instead, or is removed with "delete".
--     With a substitute pool, the named unit's power is spent on substitutes. "delete" removes the unit
--     and does not add its power to the excess.
--
-- On any unit def, applied to the whole mode. The highest unitDefID that sets a value wins:
--   zombie_minimum_spawns (integer, default 2)
--   zombie_maximum_spawns (integer, default 6)
--     the range rolled per corpse when multiple spawns are enabled. The maximum also caps how many
--     substitutes one spawn can buy.
--   zombie_minimum_respawn_delay (seconds, default 45)
--   zombie_maximum_respawn_delay (seconds, default 120)
--     the window that power-based revival times are clamped to.
--   zombie_wraith_respawn_chance (0 to 1, default 0.66)
--     the fraction of each wraith spawn wave that is kept. Every feeding death enters the wraith
--     respawn queue, and when a wave spawns the lowest-power remainder of the wave is dropped, rounded down.
--   zombie_wraith_power_multiplier (default 1)
--     multiplies a unit's power when a wraith respawn spends it on substitutes. Units that rise as
--     themselves are unchanged. Revived corpses and captures do not use this multiplier.
--   zombie_wraith_respawn_delay_multiplier (default 3)
--     multiplies a unit's revival delay when a feeding death enters the wraith respawn queue.
--   zombie_factory_buildpower_tech_multiplier (default 1.7)
--     a zombie factory's buildpower is its build speed times this value raised to the current tech level.
--   zombie_rez_power_speed_multiplier (default 1)
--     multiplies the tech-level resurrection power speeds. Higher values shorten power-based revival delays.
--   zombie_wraith_spawn_max_units_per_spawn_multiplier (default 1)
--     scales how many copies a pool unit may take and still stay in the substitute roll range.
--     The permitted count is the spawn maximum times this value, rounded up.
--   zombie_enable_wraith (1 enables, 0 disables)
--     wraiths and the wraith respawn queue, in every mode.
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
local clamp = math.clamp

local scavTeamID = BAR.Utilities.GetScavTeamID()
local gaiaTeamID = spring.GetGaiaTeamID()

local zombieModeSettings = {
	spawnCountMinimum = 2,
	spawnCountMaximum = 6,
	respawnDelayMinimum = 45,
	respawnDelayMaximum = 120,
	wraithFeedSuccessChance = 0.66,
	wraithPowerMultiplier = 1,
	wraithRespawnDelayMultiplier = 3,
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
local currentTechLevel = nil

local PICK_LOWEST = true
local PICK_HIGHEST = false
local SUBSTITUTE_FAIR_ROLL_FRAMES = Game.gameSpeed * 60 * 20
local COMMANDER_SUBSTITUTION_POWER_MULTIPLIER = 0.5 -- to prevent T3 from being substituted in for commanders that die super early in the game.

local excessPower = 0

local WRAITH = {
	UNIT_NAME = "scavwraith",
	SAFE_TIME = Game.gameSpeed * 20,
	EXPIRATION_TIME = Game.gameSpeed * 480,
	REPLACEMENT_MIN_AGE = Game.gameSpeed * 60,
	MAP_MARGIN = 16,
	SPAWN_CHECK_INTERVAL = Game.gameSpeed * 10,
	SPAWN_ATTEMPT_COUNT = 3,
	SPAWN_OFFSET_DISTANCE = 100,
	SPAWN_DELAY = 5,
	MAX_COUNT = Game.mapSizeX / 1024 + Game.mapSizeZ / 1024, -- Scalable to ensure there isn't too many or too few wraiths at any time.
	SUBSTITUTE_ROLL_COUNT = 2,
}
local wraithUnitDefID = unitDefNames[WRAITH.UNIT_NAME] and unitDefNames[WRAITH.UNIT_NAME].id
local wraithCount = 0
local IDLEMODE_FLY = 0

local ZOMBIE_EXPIRING_BUILDING_LIFETIME = Game.gameSpeed * 60 * 10 -- we don't want random zombie immobile trash taking up unit cap forever.
local ZOMBIE_PERMANENT_BUILDING_POWER_LIMIT = 5000 -- to preserve more impactful units

local WARNING_TIME = Game.gameSpeed * 15 -- Frames to start warning before reanimation
local TIMER_NEAR_MAX_THRESHOLD = Game.gameSpeed * 5 -- skip the tamper sparkle if the spawn timer is still near its maximum
local UNTAMPERED_FRAME = -math.huge
local RECENT_TAMPER_FRAMES = Game.gameSpeed
local BUILD_STEP_CHECK_INTERVAL = floor(Game.gameSpeed / 3)
local ZOMBIE_REZ_HIJACK_LEAD_FRAMES = BUILD_STEP_CHECK_INTERVAL * 2.5

local WATER_DAMAGE_DEF_ID = Game.envDamageTypes.Water
local KILLED_BY_LUA_DAMAGE_DEF_ID = Game.envDamageTypes.KilledByLua
local WATER_IS_LAVA = BAR.Lava ~= nil and BAR.Lava.isLavaMap == true
local PENDING_DEATH_TIMEOUT_FRAMES = Game.gameSpeed * 3
local VANISHED_DEATH_CHECK_INTERVAL = 3
local WATER_FEEDS_WRAITHS = WATER_IS_LAVA or (Game.waterDamage or 0) > 0
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
	Water = not WATER_FEEDS_WRAITHS,
}
local RULES_PARAM = {
	TECH_LEVEL = "zombie_tech_level",
	REZ_POWER_SPEED = "zombie_rez_power_speed",
	FACTORY_BUILDPOWER_MULTIPLIER = "zombie_factory_buildpower_multiplier",
	REZ_FRAME = "zombie_rez_frame",
	WAS_ZOMBIE = "wasZombie",
	WRAITH_READY_FRAME = "zombie_wraith_ready_frame",
	WRAITH_EXPIRATION_FRAME = "zombie_wraith_expiration_frame",
	PUBLIC_ACCESS = { public = true },
}
local creatingForcedHeap = false

local wraithPoolUnitDefIDs = {}
local wraiths = {} ---@type table<UnitID, table?>
local wraithRespawnFrames = {}
local wraithSpawnBuffer = {}
local pendingWraithWaveSpawns = {}
local pendingWraithFeeds = {}
local pendingWraithSpawns = {}
local zombieFactories = {} ---@type table<UnitID, table?>
local expiringBuildingFrames = {}
local zombieUnitDefs = {}
local zombieCorpseDefs = {} ---@type table<FeatureDefID, table?>
local corpsesData = {}
local corpseCheckFrames = {}
local corpseWarningFrames = {}
local warningCorpses = {}
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

local EFFECT = {
	CORPSE_RESET = "selfrepair-sparks-purple",
	CORPSE_RESET_HEIGHT = 15,
	SPAWN_TRAIL = "scaspawn-trail",
	RADIATION_LIGHTNING = "zombie-radiation-lightning",
}
local LIGHTNING_SIZE_SCALE = 0.5
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
local WARNING_CEGS = {
	"scavmist-low",
	"zombie-radiation-lightning",
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
	local function setSetting(customParams, customParamName, settingName, boolean)
		local value = tonumber(customParams[customParamName])
		if value then
			if boolean then
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

	local function getScavVariantUnitDefID(unitDef, unitDefID)
		if string.find(unitDef.name, "_scav") then
			return unitDefID
		end
		local scavUnitDef = unitDefNames[unitDef.name .. "_scav"]
		return scavUnitDef and scavUnitDef.id or unitDefID
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
			isExpiringBuilding = unitDef.speed <= 0
				and not unitDef.isFactory
				and rezPower <= ZOMBIE_PERMANENT_BUILDING_POWER_LIMIT,
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
			if corpseFeatureDef.resurrectable ~= 0 or isPoolMember then
				zombieCorpseDefs[corpseFeatureDef.id] = unitDefData
			end
		end
		zombieUnitDefs[unitDefID] = unitDefData

		if isPoolMember then
			local baseName = string.gsub(unitDef.name, "_scav$", "")
			local existingUnitDefID = poolUnitDefIDsByBaseName[baseName]
			if not existingUnitDefID or unitDef.name == baseName then
				poolUnitDefIDsByBaseName[baseName] = unitDefID
			end
		end
	end

	for _, unitDefID in pairs(poolUnitDefIDsByBaseName) do
		wraithPoolUnitDefIDs[#wraithPoolUnitDefIDs + 1] = unitDefID
	end
	table.sort(wraithPoolUnitDefIDs, compareUnitDefPower)
end

local function isZombie(unitID)
	return zombieUnitIDs[unitID] == true
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
		return unitDefData.rezPower * COMMANDER_SUBSTITUTION_POWER_MULTIPLIER * (currentTechLevel or 1)
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
	for _, unitDefData in pairs(zombieUnitDefs) do
		unitDefData.powerSpawnDelayFrames = calculateSpawnDelayFrames(unitDefData.rezPower)
		if unitDefData.neverRespawn then
			unitDefData.spawnDelayFrames = nil
		elseif unitDefData.customRespawnTime then
			unitDefData.spawnDelayFrames = floor(unitDefData.customRespawnTime * Game.gameSpeed)
		else
			unitDefData.spawnDelayFrames = unitDefData.powerSpawnDelayFrames
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

local function spawnWarningEffects(featureID, featureX, featureY, featureZ)
	local radius = spring.GetFeatureRadius(featureID)
	local selectedEffect = WARNING_CEGS[random(#WARNING_CEGS)] or WARNING_CEGS[1]
	if selectedEffect == EFFECT.RADIATION_LIGHTNING and GG.SpawnEnvironmentalLightning then
		GG.SpawnEnvironmentalLightning("scavradiation", featureX, featureY, featureZ, LIGHTNING_SIZE_SCALE)
	else
		spring.SpawnCEG(selectedEffect, featureX, featureY, featureZ, 0, 0, 0, radius * 0.25)
	end
	spring.SpawnCEG(EFFECT.SPAWN_TRAIL, featureX, featureY, featureZ, 0, 0, 0, radius)
end

local function playSpawnSound(x, y, z)
	local selectedSound = SPAWN_SOUNDS[random(#SPAWN_SOUNDS)] or SPAWN_SOUNDS[1]
	spring.PlaySoundFile(selectedSound, 0.5, x, y, z, 0)
end

local function clearCorpseRezRulesParam(featureID)
	spring.SetFeatureRulesParam(featureID, RULES_PARAM.REZ_FRAME, nil, RULES_PARAM.PUBLIC_ACCESS)
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
	addToFrameList(corpseCheckFrames, spawnFrame, featureID)
	local warningFrame = spawnFrame - WARNING_TIME
	if warningFrame <= gameFrame then
		warningCorpses[featureID] = true
	else
		addToFrameList(corpseWarningFrames, warningFrame, featureID)
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
	setZombieFactoryBuildpower(unitID, true, unitDefID)
	if transferToScavs and scavTeamID then
		spring.TransferUnit(unitID, scavTeamID)
	elseif GG.ZombieAI then
		GG.ZombieAI.InitializeZombie(unitID, unitDefID)
	end
	if zombieUnitDefs[unitDefID].isExpiringBuilding then
		addToFrameList(expiringBuildingFrames, gameFrame + ZOMBIE_EXPIRING_BUILDING_LIFETIME, unitID)
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
	inheritedXp,
	useExactPosition
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
		if not useExactPosition then
			offsetX = random(-size * spawnCount, size * spawnCount)
			offsetZ = random(-size * spawnCount, size * spawnCount)
		end
		local randomX = clamp(spawnX + offsetX, size, Game.mapSizeX - size)
		local randomZ = clamp(spawnZ + offsetZ, size, Game.mapSizeZ - size)
		local adjustedY = spring.GetGroundHeight(randomX, randomZ)

		local unitID = spring.CreateUnit(unitDefToCreate, randomX, adjustedY, randomZ, facing, gaiaTeamID)
		if unitID then
			spring.SpawnCEG(unitDefData.spawnExplosionCeg, randomX, adjustedY, randomZ, 0, 0, 0)
			local spawnExperience = inheritedXp or 0
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
	if currentModeFeatures.wraithRespawns then
		for _ = 1, failedCount do
			wraithSpawnBuffer[#wraithSpawnBuffer + 1] = substituteUnitDefID
		end
		return
	end
	excessPower = excessPower + failedCount * zombieUnitDefs[substituteUnitDefID].rezPower
end

local function spawnZombies(unitDefID, spawnX, spawnY, spawnZ, facing, wasZombie, inheritedXp)
	local unitDefData = zombieUnitDefs[unitDefID]
	if not unitDefData then
		return
	end
	local spawnCount = 1 -- dead zombies never multiply, so they can't snowball
	if not wasZombie and unitDefData.isMobile then
		spawnCount = calculateSpawnCount(unitDefID)
	end

	local spawnUnitDefID, plannedCount, isSubstitute =
		resolveSpawnPlan(unitDefID, wasZombie, getSubstitutionPower(unitDefID), spawnCount)
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
		inheritedXp
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
	local inheritedXp = spring.GetFeatureRulesParam(featureID, "previous_xp") or 0
	local facing = spring.GetFacingFromHeading(spring.GetFeatureHeading(featureID) or 0)
	corpsesData[featureID] = nil
	warningCorpses[featureID] = nil
	spring.DestroyFeature(featureID)
	spawnZombies(unitDefID, featureX, featureY, featureZ, facing, wasZombie, inheritedXp)
	return true
end

local function processDueWraithRespawns(frame)
	local respawns = wraithRespawnFrames[frame]
	if not respawns then
		return
	end
	wraithRespawnFrames[frame] = nil
	for respawnIndex = 1, #respawns do
		local respawn = respawns[respawnIndex]
		local unitPower = getSubstitutionPower(respawn.unitDefID) * zombieModeSettings.wraithPowerMultiplier
		local spawnUnitDefID, spawnCount = resolveSpawnPlan(respawn.unitDefID, respawn.wasZombie, unitPower, 1)
		for _ = 1, spawnCount do
			pendingWraithWaveSpawns[#pendingWraithWaveSpawns + 1] = spawnUnitDefID
		end
	end
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
	if wraiths[unitID] then
		wraiths[unitID] = nil
		wraithCount = wraithCount - 1
	end
	spring.DestroyUnit(unitID, false, true)
end

local function setWraithReadyFrame(unitID, readyFrame)
	wraiths[unitID].readyFrame = readyFrame
	spring.SetUnitRulesParam(unitID, RULES_PARAM.WRAITH_READY_FRAME, readyFrame)
end

local function trackWraith(unitID, readyFrame, expirationFrame, birthFrame)
	spring.SetUnitRulesParam(unitID, RULES_PARAM.WRAITH_READY_FRAME, readyFrame)
	spring.SetUnitRulesParam(unitID, RULES_PARAM.WRAITH_EXPIRATION_FRAME, expirationFrame)
	wraiths[unitID] = {
		readyFrame = readyFrame,
		expirationFrame = expirationFrame,
		birthFrame = birthFrame,
	}
	wraithCount = wraithCount + 1
end

local function registerExistingWraith(unitID)
	local readyFrame = tonumber(spring.GetUnitRulesParam(unitID, RULES_PARAM.WRAITH_READY_FRAME))
	local expirationFrame = tonumber(spring.GetUnitRulesParam(unitID, RULES_PARAM.WRAITH_EXPIRATION_FRAME))
	if not readyFrame or not expirationFrame then
		readyFrame = gameFrame
		expirationFrame = gameFrame + WRAITH.EXPIRATION_TIME
	end
	trackWraith(unitID, readyFrame, expirationFrame, expirationFrame - WRAITH.EXPIRATION_TIME)
end

local function getOldestWraithID()
	local oldestUnitID = nil
	local oldestBirthFrame = nil
	for unitID, wraithData in pairs(wraiths) do
		local birthFrame = wraithData.birthFrame
		if not oldestBirthFrame or birthFrame < oldestBirthFrame or (birthFrame == oldestBirthFrame and unitID < oldestUnitID) then
			oldestBirthFrame = birthFrame
			oldestUnitID = unitID
		end
	end
	return oldestUnitID
end

local function freeWraithSlotForNewWraith()
	if wraithCount < WRAITH.MAX_COUNT then
		return true
	end
	local oldestUnitID = getOldestWraithID()
	local oldestWraith = oldestUnitID and wraiths[oldestUnitID]
	if not oldestWraith or gameFrame - oldestWraith.birthFrame <= WRAITH.REPLACEMENT_MIN_AGE then
		return false
	end
	removeWraith(oldestUnitID)
	return true
end

local function createWraith(spawnX, spawnZ)
	if not wraithUnitDefID or not freeWraithSlotForNewWraith() then
		return nil
	end

	local wraithX = clamp(spawnX, WRAITH.MAP_MARGIN, Game.mapSizeX - WRAITH.MAP_MARGIN)
	local wraithZ = clamp(spawnZ, WRAITH.MAP_MARGIN, Game.mapSizeZ - WRAITH.MAP_MARGIN)
	local wraithY = spring.GetGroundHeight(wraithX, wraithZ)
	local unitID =
		spring.CreateUnit(wraithUnitDefID, wraithX, wraithY, wraithZ, 0, gaiaTeamID)
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

	trackWraith(unitID, gameFrame + WRAITH.SAFE_TIME, gameFrame + WRAITH.EXPIRATION_TIME, gameFrame)
	if GG.ZombieAI then
		GG.ZombieAI.CommandWraith(unitID, wraithUnitDefID, wraithX, wraithY, wraithZ)
	end
	return unitID
end

local function feedWraithQueue(unitDefID, spawnX, spawnZ, wasZombie)
	if not autoSpawningEnabled or not currentModeFeatures.wraithRespawns then
		return
	end
	local unitDefData = zombieUnitDefs[unitDefID]
	if not unitDefData.corpseDefID or unitDefData.neverRespawn or unitDefData.excludedFromWraithSpawn then
		return
	end
	pendingWraithFeeds[#pendingWraithFeeds + 1] = { unitDefID = unitDefID, x = spawnX, z = spawnZ, wasZombie = wasZombie }
end

local function processWraithFeeds()
	if #pendingWraithFeeds == 0 then
		return
	end
	local wraithFeeds = pendingWraithFeeds
	pendingWraithFeeds = {}
	for feedIndex = 1, #wraithFeeds do
		local wraithFeed = wraithFeeds[feedIndex]
		local spawnDelayFrames = (zombieUnitDefs[wraithFeed.unitDefID].spawnDelayFrames or 0)
			* zombieModeSettings.wraithRespawnDelayMultiplier
		local respawnFrame = gameFrame + math.max(spawnDelayFrames, 1)
		local respawn = { unitDefID = wraithFeed.unitDefID, wasZombie = wraithFeed.wasZombie }
		addToFrameList(wraithRespawnFrames, respawnFrame, respawn)
		addToFrameList(pendingWraithSpawns, gameFrame + WRAITH.SPAWN_DELAY, { x = wraithFeed.x, z = wraithFeed.z })
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
		createWraith(spawn.x, spawn.z)
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
		if unitDefID and isZombie(unitID) and zombieUnitDefs[unitDefID].isExpiringBuilding then
			suppressedDeaths[unitID] = true
			spring.DestroyUnit(unitID, true, true)
		end
	end
end

local function getReadyWraithIDs()
	local readyWraithIDs = {}
	local wraithIDs = getWraithIDsSortedAscending()
	for wraithIndex = 1, #wraithIDs do
		local wraithID = wraithIDs[wraithIndex]
		if gameFrame >= wraiths[wraithID].readyFrame then
			readyWraithIDs[#readyWraithIDs + 1] = wraithID
		end
	end
	return readyWraithIDs
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

local function isTeamAtUnitCap(teamID)
	local maxUnits, currentUnits = spring.GetTeamMaxUnits(teamID)
	return maxUnits ~= nil and currentUnits ~= nil and currentUnits >= maxUnits
end

local function spawnAtWraith(unitDefID, wraithID)
	local wraithData = wraiths[wraithID]
	if not wraithData or gameFrame < wraithData.readyFrame then
		return false
	end
	local wraithX, _, wraithZ = spring.GetUnitPosition(wraithID)
	if not wraithX then
		return false
	end
	local unitDefToCreate = zombieUnitDefs[unitDefID].scavVariantUnitDefID
	local size = zombieUnitDefs[unitDefToCreate].size
	for _ = 1, WRAITH.SPAWN_ATTEMPT_COUNT do
		local angle = random() * 2 * math.pi
		local distance = random() * WRAITH.SPAWN_OFFSET_DISTANCE
		local spawnX = clamp(wraithX + math.cos(angle) * distance, size, Game.mapSizeX - size)
		local spawnZ = clamp(wraithZ + math.sin(angle) * distance, size, Game.mapSizeZ - size)
		local spawnY = spring.GetGroundHeight(spawnX, spawnZ)
		local facing = random(0, 3)
		if canSpawnUnitAt(unitDefToCreate, spawnX, spawnY, spawnZ, facing) then
			return spawnZombieUnits(unitDefID, 1, spawnX, spawnY, spawnZ, facing, 0, true) > 0
		end
	end
	return false
end

local function spawnDueWraithUnits()
	if #wraithSpawnBuffer == 0 and #pendingWraithWaveSpawns == 0 then
		return
	end
	local readyWraithIDs = getReadyWraithIDs()
	if #readyWraithIDs == 0 then
		return
	end
	local waveCount = #pendingWraithWaveSpawns
	if waveCount > 0 then
		table.sort(pendingWraithWaveSpawns, compareUnitDefPower)
		local dropCount = clamp(floor(waveCount * (1 - zombieModeSettings.wraithFeedSuccessChance)), 0, waveCount)
		for waveIndex = dropCount + 1, waveCount do
			wraithSpawnBuffer[#wraithSpawnBuffer + 1] = pendingWraithWaveSpawns[waveIndex]
		end
		pendingWraithWaveSpawns = {}
	end
	local pendingSpawns = wraithSpawnBuffer
	wraithSpawnBuffer = {}
	table.shuffle(pendingSpawns)
	for spawnIndex = 1, #pendingSpawns do
		local unitDefID = pendingSpawns[spawnIndex]
		if isTeamAtUnitCap(gaiaTeamID) then
			for remainingIndex = spawnIndex, #pendingSpawns do
				wraithSpawnBuffer[#wraithSpawnBuffer + 1] = pendingSpawns[remainingIndex]
			end
			return
		end
		local wraithID = readyWraithIDs[(spawnIndex - 1) % #readyWraithIDs + 1]
		if not spawnAtWraith(unitDefID, wraithID) then
			wraithSpawnBuffer[#wraithSpawnBuffer + 1] = unitDefID
		end
	end
end

local function spawnWraithReadyLightning(wraithX, wraithY, wraithZ)
	if random() < 0.5 then
		return
	end
	local lightningY = wraithY + 100
	if GG.SpawnEnvironmentalLightning then
		GG.SpawnEnvironmentalLightning("scavradiation", wraithX, lightningY, wraithZ, 0.5 * LIGHTNING_SIZE_SCALE)
	end
	spring.SpawnCEG(EFFECT.RADIATION_LIGHTNING, wraithX, lightningY, wraithZ, 0, 0, 0)
	spring.SpawnCEG(EFFECT.SPAWN_TRAIL, wraithX, wraithY, wraithZ, 0, 0, 0, 32)
end

local function updateWraiths()
	local wraithIDs = getWraithIDsSortedAscending()
	local gaiaAtUnitCap = isTeamAtUnitCap(gaiaTeamID)
	for wraithIndex = 1, #wraithIDs do
		local unitID = wraithIDs[wraithIndex]
		local wraithData = wraiths[unitID]
		if wraithData then
			local wraithX, wraithY, wraithZ = spring.GetUnitPosition(unitID)
			if not wraithX or gameFrame >= wraithData.expirationFrame then
				removeWraith(unitID)
			else
				local enemyNearby = GG.ZombieAI
					and GG.ZombieAI.CommandWraith(unitID, wraithUnitDefID, wraithX, wraithY, wraithZ)
				if enemyNearby then
					setWraithReadyFrame(unitID, gameFrame + WRAITH.SAFE_TIME)
				elseif gameFrame >= wraithData.readyFrame and not gaiaAtUnitCap then
					spawnWraithReadyLightning(wraithX, wraithY, wraithZ)
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
	if part > 0 and builderTeam == gaiaTeamID and zombieUnitIDs[builderID] then
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
	if not corpseData or gameFrame - corpseData.tamperedFrame < BUILD_STEP_CHECK_INTERVAL then
		return true
	end
	if corpseData.tamperedFrame == UNTAMPERED_FRAME then
		local remainingFrames = corpseData.spawnFrame - gameFrame
		if remainingFrames < corpseData.spawnDelayFrames - TIMER_NEAR_MAX_THRESHOLD then
			local featureX, featureY, featureZ = spring.GetFeaturePosition(featureID)
			if featureX then
				spring.SpawnCEG(EFFECT.SPAWN_TRAIL, featureX, featureY + 15, featureZ, 0, 0, 0)
			end
		end
	end
	corpseData.tamperedFrame = gameFrame
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

local function recordPendingDeath(unitID, unitDefID, weaponDefID)
	if not zombieUnitDefs[unitDefID].corpseDefID then
		return
	end
	local unitX, _, unitZ = spring.GetUnitPosition(unitID)
	if not unitX then
		return
	end
	pendingDeaths[unitID] = {
		unitDefID = unitDefID,
		x = unitX,
		z = unitZ,
		wasZombie = isZombie(unitID),
		isDrowned = weaponDefID == WATER_DAMAGE_DEF_ID and not WATER_IS_LAVA,
		feedsWraith = isWraithFeedingDeath(unitID, unitDefID, weaponDefID),
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
	local featureDefID = spring.GetFeatureDefID(featureID)
	local featureDef = featureDefID and FeatureDefs[featureDefID]
	local fromUnitName = featureDef and featureDef.customParams and featureDef.customParams.fromunit or ""
	return string.sub(fromUnitName, -5) == "_scav"
end

local function queueCorpseForSpawning(featureID, override, wasZombie)
	if not override and not autoSpawningEnabled then
		return
	end

	local featureDefID = spring.GetFeatureDefID(featureID)
	local corpseDefData = featureDefID and zombieCorpseDefs[featureDefID]
	if not corpseDefData or not corpseCanRespawn(featureID, corpseDefData) then
		return
	end

	wasZombie = wasZombie or wasZombieCorpse(featureID)

	local existingRezFrame = spring.GetFeatureRulesParam(featureID, RULES_PARAM.REZ_FRAME)
	existingRezFrame = tonumber(existingRezFrame)
	local spawnDelayFrames = corpseDefData.spawnDelayFrames
	local spawnFrame = gameFrame + (spawnDelayFrames or 0)
	if existingRezFrame and existingRezFrame > 0 then
		spawnFrame = floor(existingRezFrame)
	end

	local featureX, _, featureZ = spring.GetFeaturePosition(featureID)
	if not featureX then
		return
	end
	local featureData = {
		featureDefID = featureDefID,
		spawnDelayFrames = spawnDelayFrames,
		creationFrame = gameFrame,
		tamperedFrame = UNTAMPERED_FRAME,
		wasZombie = wasZombie,
		x = featureX,
		z = featureZ,
	}
	corpsesData[featureID] = featureData
	armCorpseSpawn(featureID, featureData, spawnFrame)
end

local function registerDeathFeature(featureID, featureDefID, deathData)
	local wasZombie = deathData and deathData.wasZombie
	if wasZombie then
		spring.SetFeatureRulesParam(featureID, RULES_PARAM.WAS_ZOMBIE, 1, RULES_PARAM.PUBLIC_ACCESS)
	end
	if zombieCorpseDefs[featureDefID] then
		queueCorpseForSpawning(featureID, false, wasZombie)
		return
	end

	if not deathData or not deathData.feedsWraith then
		return
	end
	local featureX, _, featureZ = spring.GetFeaturePosition(featureID)
	if featureX then
		feedWraithQueue(deathData.unitDefID, featureX, featureZ, deathData.wasZombie)
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
	local vanishedCount = 0
	for unitID, deathData in pairs(pendingDeaths) do
		if spring.GetUnitIsDead(unitID) ~= true then
			pendingDeaths[unitID] = nil
			vanishedCount = vanishedCount + 1
			vanishedDeaths[vanishedCount] = deathData
		elseif deathData.timeoutFrame < gameFrame then
			pendingDeaths[unitID] = nil
		end
	end
	for deathIndex = 1, vanishedCount do
		local deathData = vanishedDeaths[deathIndex]
		vanishedDeaths[deathIndex] = nil
		if deathData.feedsWraith then
			feedWraithQueue(deathData.unitDefID, deathData.x, deathData.z, deathData.wasZombie)
		end
	end
end

local function processDueCorpse(featureID)
	local corpseData = corpsesData[featureID]
	if not corpseData then
		return
	end
	local featureX, _, featureZ = spring.GetFeaturePosition(featureID)
	if not featureX then
		corpsesData[featureID] = nil
		return
	end
	if corpseData.tamperedFrame ~= UNTAMPERED_FRAME then
		local tamperedFrame = corpseData.tamperedFrame
		corpseData.creationFrame = tamperedFrame
		corpseData.tamperedFrame = UNTAMPERED_FRAME -- reclaim/rez progress restarts the spawn timer from this frame
		armCorpseSpawn(featureID, corpseData, tamperedFrame + corpseData.spawnDelayFrames)
		local resetY = spring.GetGroundHeight(featureX, featureZ) + EFFECT.CORPSE_RESET_HEIGHT
		spring.SpawnCEG(EFFECT.CORPSE_RESET, featureX, resetY, featureZ, 0, 0, 0)
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
		processDueCorpse(featureID)
	end
	corpseCheckFrames[frame] = nil
end

local function topUpGaiaResources()
	for resourceIndex = 1, #GAIA_RESOURCES do
		spring.AddTeamResource(gaiaTeamID, GAIA_RESOURCES[resourceIndex].resourceName, GAIA_RESOURCE_AMOUNT)
	end
end

local function activateDueWarnings(frame)
	local dueWarnings = corpseWarningFrames[frame]
	if not dueWarnings then
		return
	end
	corpseWarningFrames[frame] = nil
	for warningIndex = 1, #dueWarnings do
		warningCorpses[dueWarnings[warningIndex]] = true
	end
end

local function spawnCorpseWarnings(frame)
	for featureID in pairs(warningCorpses) do
		local featureData = corpsesData[featureID]
		if not featureData or featureData.spawnFrame - frame >= WARNING_TIME then
			warningCorpses[featureID] = nil
		else
			local featureX, featureY, featureZ = spring.GetFeaturePosition(featureID)
			if not featureX then --doesn't exist anymore
				corpsesData[featureID] = nil
				warningCorpses[featureID] = nil
			elseif featureData.tamperedFrame == UNTAMPERED_FRAME then
				spawnWarningEffects(featureID, featureX, featureY, featureZ)
			end
		end
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
		processDueWraithRespawns(frame)
		if frame % WRAITH.SPAWN_CHECK_INTERVAL == 0 then
			spawnDueWraithUnits()
		end
	end

	if frame % REZ_SPEED_UPDATE_INTERVAL == 0 then
		updateRezSpeed()
	end

	activateDueWarnings(frame)
	processDueCorpses(frame)

	if frame % ZOMBIE_CHECK_INTERVAL == 0 then
		updateTooLong(frame)
		if currentModeFeatures.wraithRespawns then
			updateWraiths()
		end
		topUpGaiaResources()
		spawnCorpseWarnings(frame)
	end
end

local function isFeatureInLava(featureID)
	if not WATER_IS_LAVA or not _G.lavaLevel then
		return false
	end
	local _, featureY = spring.GetFeaturePosition(featureID)
	return featureY ~= nil and featureY < _G.lavaLevel
end

function gadget:FeatureCreated(featureID, _, sourceID)
	if creatingForcedHeap then
		spring.SetFeatureRulesParam(featureID, RULES_PARAM.WAS_ZOMBIE, 1, RULES_PARAM.PUBLIC_ACCESS)
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

function gadget:FeatureDestroyed(featureID, allyTeam)
	local corpseData = corpsesData[featureID]
	if corpseData and not wasCorpseReclaimedOrResurrected(featureID) then
		local corpseDefData = zombieCorpseDefs[corpseData.featureDefID]
		if corpseDefData then
			feedWraithQueue(corpseDefData.unitDefID, corpseData.x, corpseData.z, corpseData.wasZombie)
		end
	end
	clearCorpseRezRulesParam(featureID)
	corpsesData[featureID] = nil
	warningCorpses[featureID] = nil
	rezzedCorpses[featureID] = nil
	zombieRezChecks[featureID] = nil
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if unitDefID == wraithUnitDefID then
		spring.GiveOrderToUnit(unitID, CMD.IDLEMODE, { IDLEMODE_FLY }, 0)
	end
	if unitTeam == gaiaTeamID and builderID and isZombie(builderID) then
		zombiesBeingBuilt[unitID] = true
		spring.SetUnitRulesParam(unitID, "resurrected", 0, { inlos = true })
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if unitTeam == gaiaTeamID and zombiesBeingBuilt[unitID] then
		zombiesBeingBuilt[unitID] = nil
		setZombie(unitID)
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	local wasWraith = wraiths[unitID] ~= nil
	removeWraith(unitID)

	if not suppressedDeaths[unitID] and not wasWraith and unitDefID ~= wraithUnitDefID then
		recordPendingDeath(unitID, unitDefID, weaponDefID)
	end

	suppressedDeaths[unitID] = nil
	pendingZombieCaptures[unitID] = nil
	unitTamperFrames[unitID] = nil
	zombiesBeingBuilt[unitID] = nil
	zombieUnitIDs[unitID] = nil
	setZombieFactoryBuildpower(unitID, false)
end

function gadget:AllowUnitCaptureStep(builderID, builderTeam, unitID, unitDefID, part)
	if pendingZombieCaptures[unitID] then
		return true
	end
	local tamperedFrame = unitTamperFrames[unitID]
	if zombieUnitIDs[builderID] and (builderTeam == gaiaTeamID or builderTeam == scavTeamID) then
		if not wasTamperedRecently(tamperedFrame) then
			pendingZombieCaptures[unitID] = true
		end
		return true
	end
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
	if not pendingZombieCaptures[unitID] then
		return
	end
	pendingZombieCaptures[unitID] = nil
	if (newTeam ~= gaiaTeamID and newTeam ~= scavTeamID) or isZombie(unitID) then
		return
	end

	local unitX, unitY, unitZ = spring.GetUnitPosition(unitID)
	local inheritedXp = spring.GetUnitExperience(unitID) or 0
	local facing = spring.GetUnitBuildFacing(unitID) or 0
	suppressedDeaths[unitID] = true
	spring.DestroyUnit(unitID, false, true)

	local spawnDefID = unitDefID
	local swapOverride = zombieUnitDefs[unitDefID].captureOverride
	if swapOverride then
		spawnDefID = swapOverride ~= "delete" and unitDefNames[swapOverride].id or nil
	end
	if unitX and spawnDefID then
		spawnZombies(spawnDefID, unitX, unitY, unitZ, facing, false, inheritedXp)
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
	wraithSpawnBuffer = {}
	pendingWraithWaveSpawns = {}
	wraithRespawnFrames = {}
	pendingWraithFeeds = {}
	pendingWraithSpawns = {}
end

---Drops every queued corpse spawn without affecting zombies already raised.
local function clearAllZombieSpawns()
	for featureID in pairs(corpsesData) do
		clearCorpseRezRulesParam(featureID)
	end
	corpsesData = {}
	corpseCheckFrames = {}
	corpseWarningFrames = {}
	warningCorpses = {}
	excessPower = 0
	clearWraithState()
end

local function isAuthorized(playerID)
	if spring.IsCheatingEnabled() then
		return true
	end
	local playerName = spring.GetPlayerInfo(playerID)
	local accountID = BAR.Utilities.GetAccountID(playerID)
	local devHelpers = _G.permissions.devhelpers
	if devHelpers and (devHelpers[accountID] or (playerName and devHelpers[playerName])) then
		return true
	end
	local director = _G.permissions.director
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

function gadget:Initialize()
	gameFrame = spring.GetGameFrame()

	applyZombieModeSettings(resolveZombieMode(modOptions.zombies))
	updateRezSpeed()

	autoSpawningEnabled = modOptionEnabled and not isIdleMode

	local units = spring.GetAllUnits()
	for _, unitID in ipairs(units) do
		local unitDefID = currentModeFeatures.wraithRespawns and spring.GetUnitDefID(unitID)
		local isExistingWraith = wraithUnitDefID
			and unitDefID == wraithUnitDefID
			and spring.GetUnitTeam(unitID) == gaiaTeamID
		if isExistingWraith then
			registerExistingWraith(unitID)
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
end

function gadget:GameStart()
	setGaiaStorage()
end
