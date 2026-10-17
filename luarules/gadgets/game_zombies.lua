function gadget:GetInfo()
	return {
		name = "Zombies",
		desc = "Resurrects corpses as Scavengers or hostile Gaia Zombies",
		author = "SethDGamre, code snippets/inspiration from Rafal",
		date = "March 2024",
		license = "GNU GPL, v2 or later",
		layer = 6, -- after game_team_resources.lua, ai_ruins.lua, and unit_resurrected.lua so previous_xp is already on the corpse
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
--   zombie_ghost_respawn_pool (any value)
--     adds the unit to the substitute pool. When the pool has any units, revived corpses, apparition
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
--   zombie_ghost_respawn_chance (0 to 1, default 0.66)
--     the chance that a death feeding the apparitions enters the apparition respawn queue.
--   zombie_ghost_power_multiplier (default 1)
--     multiplies a unit's power when an apparition respawn spends it on substitutes. Units that rise as
--     themselves are unchanged. Revived corpses and captures do not use this multiplier.
--   zombie_ghost_respawn_delay_multiplier (default 4)
--     multiplies a unit's revival delay when a feeding death enters the apparition respawn queue.
--   zombie_factory_buildpower_tech_multiplier (default 1.7)
--     a zombie factory's buildpower is its build speed times this value raised to the current tech level.
--   zombie_rez_power_speed_multiplier (default 1)
--     multiplies the tech-level resurrection power speeds. Higher values shorten power-based revival delays.
--   zombie_ghost_spawn_max_units_per_spawn_multiplier (default 1)
--     scales how many copies a pool unit may take and still stay in the substitute roll range.
--     The permitted count is the spawn maximum times this value, rounded up.
--   zombie_enable_oni (1 enables, 0 disables)
--     a corpse on every eligible death, in every mode.
--   zombie_enable_yokai (1 enables, 0 disables)
--     apparitions and the apparition respawn queue, in every mode.
--   zombie_enable_nani (1 enables, 0 disables)
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
	ghostFeedSuccessChance = 0.66,
	ghostPowerMultiplier = 1,
	ghostRespawnDelayMultiplier = 4,
	factoryBuildpowerTechMultiplier = 1.7,
	rezPowerSpeedMultiplier = 1,
	ghostSpawnMaxUnitsPerSpawnMultiplier = 1,
}

---One of the zombie modes, matching the keys of `ZOMBIE_MODE_FEATURES`.
---@alias ZombieMode "basic"|"oni"|"yokai"|"nani"|"akumu"|"spidergeddon"

local ZOMBIE_MODE_FEATURES = {
	basic = {},
	oni = { alwaysCorpses = true },
	yokai = { ghostRespawns = true },
	nani = { multipleSpawns = true },
	akumu = { alwaysCorpses = true, ghostRespawns = true, multipleSpawns = true },
	spidergeddon = { alwaysCorpses = true, ghostRespawns = true, multipleSpawns = true },
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
local TOO_LONG_GAME_FRAMES = Game.gameSpeed * 60 * 60
local TOO_LONG_REZ_POWER_SPEED = 20
local ZOMBIE_CHECK_INTERVAL = Game.gameSpeed -- How often (in frames) everything else is checked
local REZ_SPEED_UPDATE_INTERVAL = Game.gameSpeed * 60

local gameFrame = 0
local tooLong = false
local adjustedRezPowerSpeed = TECH_TO_REZ_POWER_SPEEDS[1]
local currentTechLevel = nil

local PICK_LOWEST = true
local PICK_HIGHEST = false
local SUBSTITUTE_FAIR_ROLL_FRAMES = Game.gameSpeed * 60 * 20
local COMMANDER_SUBSTITUTION_POWER_MULTIPLIER = 0.5 -- to prevent T3 from being substituted in for commanders that die super early in the game.

local excessPower = 0

local GHOST = {
	MIST_UNIT_NAME = "scavapparition",
	SAFE_TIME = Game.gameSpeed * 20,
	MINIMUM_LIFE = Game.gameSpeed * 30,
	EXPIRATION_TIME = Game.gameSpeed * 120,
	MAP_MARGIN = 16,
	SPAWN_GRACE_PERIOD = Game.gameSpeed * 60 * 5,
	SPAWN_CHECK_INTERVAL = Game.gameSpeed * 60,
	SPAWN_ATTEMPT_COUNT = 3,
	SPAWN_OFFSET_DISTANCE = 50,
	RANDOM_SPAWN_INTERVAL = Game.gameSpeed * 60,
	MAX_RANDOM_SPAWNS_PER_CHECK = 3,
	MAX_COUNT = 25,
	MAX_BUFFER_SPAWNS_PER_PASS = 100,
	SUBSTITUTE_ROLL_COUNT = 2,
}
local ghostMistUnitDefID = unitDefNames[GHOST.MIST_UNIT_NAME] and unitDefNames[GHOST.MIST_UNIT_NAME].id
local ghostCount = 0

local ZOMBIE_TURRET_LIFETIME = Game.gameSpeed * 60 * 10 -- we don't want random zombie immobile trash taking up unit cap forever.
local ZOMBIE_PERMANENT_BUILDING_POWER_LIMIT = 5000 -- to preserve more impactful units

local WARNING_TIME = Game.gameSpeed * 15 -- Frames to start warning before reanimation
local TIMER_NEAR_MAX_THRESHOLD = Game.gameSpeed * 5 -- skip the tamper sparkle if the spawn timer is still near its maximum

local WATER_DAMAGE_DEF_ID = Game.envDamageTypes.Water
local PENDING_DEATH_TIMEOUT_FRAMES = Game.gameSpeed * 10
local DEATH_NAMES_WITHOUT_CORPSE = {
	Reclaimed = true,
	KilledByLua = true,
	TurnedIntoFeature = true,
	FactoryCancel = true,
	ConstructionDecay = true,
	OutOfBounds = true,
	KilledByCheat = true,
}
local RULES_PARAM = {
	REZ_FRAME = "zombie_rez_frame",
	WAS_ZOMBIE = "wasZombie",
	PUBLIC_ACCESS = { public = true },
	PREVIOUS_STATE = { "previous_xp", "previous_firestate", "previous_movestate" },
}
local replacementDeathData ---@type table?

local ghostPoolUnitDefIDs = {}
local ghosts = {} ---@type table<UnitID, table?>
local ghostRespawnFrames = {}
local ghostSpawnBuffer = {}
local pendingGhostFeeds = {}
local zombieFactories = {} ---@type table<UnitID, table?>
local zombieTurretExpirationFrames = {}
local zombieUnitDefs = {}
local zombieCorpseDefs = {} ---@type table<FeatureDefID, table?>
local corpsesData = {}
local corpseCheckFrames = {}
local rezzedCorpses = {}
local pendingDeaths = {}
local pendingWreckSwaps = {}
local suppressedDeaths = {}
local DEATHS_WITHOUT_CORPSE = {}
local pendingZombieCaptures = {}
local zombiesBeingBuilt = {}

for deathName, damageTypeID in pairs(Game.envDamageTypes) do
	DEATHS_WITHOUT_CORPSE[damageTypeID] = DEATH_NAMES_WITHOUT_CORPSE[deathName]
end

local EFFECT = {
	CORPSE_RESET = "selfrepair-sparks-purple",
	CORPSE_RESET_HEIGHT = 15,
	SPAWN_TRAIL = "scaspawn-trail",
	RADIATION_LIGHTNING = "scavradiation-lightning",
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
local WARNING_CEGS = {
	"scavmist",
	"scavradiation-lightning",
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

	local function isExcludedFromGhostSpawn(unitDef)
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
		setSetting(customParams, "zombie_ghost_respawn_chance", "ghostFeedSuccessChance")
		setSetting(customParams, "zombie_ghost_power_multiplier", "ghostPowerMultiplier")
		setSetting(customParams, "zombie_ghost_respawn_delay_multiplier", "ghostRespawnDelayMultiplier")
		setSetting(customParams, "zombie_factory_buildpower_tech_multiplier", "factoryBuildpowerTechMultiplier")
		setSetting(customParams, "zombie_rez_power_speed_multiplier", "rezPowerSpeedMultiplier")
		setSetting(customParams, "zombie_ghost_spawn_max_units_per_spawn_multiplier", "ghostSpawnMaxUnitsPerSpawnMultiplier")
		setSetting(customParams, "zombie_minimum_spawns", "spawnCountMinimum")
		setSetting(customParams, "zombie_maximum_spawns", "spawnCountMaximum")
		setSetting(customParams, "zombie_minimum_respawn_delay", "respawnDelayMinimum")
		setSetting(customParams, "zombie_maximum_respawn_delay", "respawnDelayMaximum")
		setSetting(customParams, "zombie_enable_yokai", "ghostRespawns", true)
		setSetting(customParams, "zombie_enable_oni", "alwaysCorpses", true)
		setSetting(customParams, "zombie_enable_nani", "multipleSpawns", true)

		local rezPower = math.max(1, unitDef.power or 1)
		local isPoolMember = customParams.zombie_ghost_respawn_pool and true or false
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
			excludedFromGhostSpawn = isExcludedFromGhostSpawn(unitDef),
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
			unitDefData.heapDefID = corpseFeatureDef.deathFeatureID
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
		ghostPoolUnitDefIDs[#ghostPoolUnitDefIDs + 1] = unitDefID
	end
	table.sort(ghostPoolUnitDefIDs, function(firstUnitDefID, secondUnitDefID)
		local firstPower = zombieUnitDefs[firstUnitDefID].rezPower
		local secondPower = zombieUnitDefs[secondUnitDefID].rezPower
		if firstPower == secondPower then
			return firstUnitDefID < secondUnitDefID
		end
		return firstPower < secondPower
	end)
end

local function isZombie(unitID)
	return spring.GetUnitRulesParam(unitID, "zombie") == 1
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

local function applyZombieFactoryBuildpower(unitID, unitDefID)
	local unitDef = unitDefs[unitDefID]
	if not unitDef or not unitDef.isFactory then
		return
	end

	local techLevel = currentTechLevel or 1
	local buildpower = unitDef.buildSpeed * zombieModeSettings.factoryBuildpowerTechMultiplier ^ techLevel
	spring.SetUnitBuildSpeed(unitID, buildpower)
	zombieFactories[unitID] = zombieFactories[unitID] or { unitDefID = unitDefID, baseBuildSpeed = unitDef.buildSpeed }
end

local function revertZombieFactoryBuildpower(unitID)
	local factoryData = zombieFactories[unitID]
	if factoryData then
		spring.SetUnitBuildSpeed(unitID, factoryData.baseBuildSpeed)
	end
	zombieFactories[unitID] = nil
end

local function refreshZombieFactoryBuildpower()
	for unitID, factoryData in pairs(zombieFactories) do
		if not spring.ValidUnitID(unitID) then
			zombieFactories[unitID] = nil
		elseif spring.GetUnitTeam(unitID) ~= gaiaTeamID then
			revertZombieFactoryBuildpower(unitID)
		else
			applyZombieFactoryBuildpower(unitID, factoryData.unitDefID)
		end
	end
end

local function updateRezSpeed()
	local techLevel = 1
	if GG.PowerLib and GG.PowerLib.HighestPlayerTeamPower and GG.PowerLib.TechGuesstimate then
		local highestPowerData = GG.PowerLib.HighestPlayerTeamPower()
		techLevel = GG.PowerLib.TechGuesstimate(highestPowerData.power)
	end
	if tooLong then
		adjustedRezPowerSpeed = TOO_LONG_REZ_POWER_SPEED
	else
		local rezPowerSpeed = TECH_TO_REZ_POWER_SPEEDS[techLevel] or TECH_TO_REZ_POWER_SPEEDS[1]
		adjustedRezPowerSpeed = rezPowerSpeed * zombieModeSettings.rezPowerSpeedMultiplier
	end
	currentTechLevel = techLevel
	rebuildZombieCorpseSpawnDelays()
	refreshZombieFactoryBuildpower()
end

local function updateTooLong(frame)
	if tooLong or frame < TOO_LONG_GAME_FRAMES then
		return
	end
	tooLong = true
	GG.Zombies.tooLong = true
	updateRezSpeed()
	if GG.ZombieAI and GG.ZombieAI.EnablePermanentAggro then
		GG.ZombieAI.EnablePermanentAggro()
	end
end

local function featureResourceRatio(currentAmount, maximumAmount)
	if currentAmount and maximumAmount and currentAmount ~= 0 and maximumAmount ~= 0 then
		return currentAmount / maximumAmount
	end
	return 1
end

local function calculateHealthRatio(featureID)
	local currentMetal, maxMetal = spring.GetFeatureResources(featureID)
	local health, maxHealth = spring.GetFeatureHealth(featureID)
	local partialReclaimRatio = featureResourceRatio(currentMetal, maxMetal)
	local damagedReductionRatio = featureResourceRatio(health, maxHealth)
	return (partialReclaimRatio + damagedReductionRatio) * 0.5 --average the two ratios to skew the result towards maximum health
end

local function spawnWarningEffects(featureID, featureX, featureY, featureZ)
	local radius = spring.GetFeatureRadius(featureID)
	local selectedEffect = WARNING_CEGS[random(#WARNING_CEGS)] or WARNING_CEGS[1]
	if selectedEffect == EFFECT.RADIATION_LIGHTNING and GG.SpawnEnvironmentalLightning then
		GG.SpawnEnvironmentalLightning("scavradiation", featureX, featureY, featureZ)
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
	local keep = PICK_LOWEST
	local rollCount = 1
	if currentTechLevel <= 1 then
		keep = PICK_LOWEST
		rollCount = 3
	elseif rezTimeSeconds == zombieModeSettings.respawnDelayMinimum then
		keep = PICK_HIGHEST
		rollCount = 2
	elseif rezTimeSeconds == zombieModeSettings.respawnDelayMaximum then
		keep = PICK_LOWEST
		rollCount = 3
	end
	return rollFor(keep, rollCount, zombieModeSettings.spawnCountMinimum, zombieModeSettings.spawnCountMaximum)
end

local function registerZombie(unitID, unitDefID, transferToScavs)
	spring.SetUnitRulesParam(unitID, "zombie", 1)
	applyZombieFactoryBuildpower(unitID, unitDefID)
	if transferToScavs and scavTeamID then
		spring.TransferUnit(unitID, scavTeamID)
	elseif GG.ZombieAI then
		GG.ZombieAI.InitializeZombie(unitID, unitDefID)
	end
	if zombieUnitDefs[unitDefID].isExpiringBuilding then
		addToFrameList(zombieTurretExpirationFrames, gameFrame + ZOMBIE_TURRET_LIFETIME, unitID)
	end
end

---@return integer spawnedCount
local function spawnZombieUnits(
	unitDefID,
	spawnCount,
	healthReductionRatio,
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
			local unitHealth = spring.GetUnitHealth(unitID)
			if unitHealth then
				spring.SetUnitHealth(unitID, unitHealth * healthReductionRatio)
			end
			registerZombie(unitID, unitDefToCreate, true)
			spawnedCount = spawnedCount + 1
		else
			break
		end
	end
	return spawnedCount
end

local function pushGhostSpawn(unitDefID)
	local unitValue = zombieUnitDefs[unitDefID].rezPower
	local insertIndex = #ghostSpawnBuffer + 1
	for bufferIndex = 1, #ghostSpawnBuffer do
		if unitValue > zombieUnitDefs[ghostSpawnBuffer[bufferIndex]].rezPower then
			insertIndex = bufferIndex
			break
		end
	end
	table.insert(ghostSpawnBuffer, insertIndex, unitDefID)
end

local function resolveSpawnPlan(unitDefID, wasZombie, unitPower, spawnCount)
	if #ghostPoolUnitDefIDs == 0 or (wasZombie and zombieUnitDefs[unitDefID].isPoolMember) then
		return unitDefID, spawnCount, false
	end

	local borrowedPower = math.min(excessPower, unitPower)
	local totalPower = unitPower * spawnCount + borrowedPower
	local ghostSpawnMaxUnits = math.ceil(
		zombieModeSettings.spawnCountMaximum * zombieModeSettings.ghostSpawnMaxUnitsPerSpawnMultiplier
	)
	excessPower = excessPower - borrowedPower

	local lowestIndex
	local highestIndex
	for poolIndex = 1, #ghostPoolUnitDefIDs do
		local poolPower = zombieUnitDefs[ghostPoolUnitDefIDs[poolIndex]].rezPower
		if poolPower > totalPower then
			break
		end
		highestIndex = poolIndex
		if not lowestIndex and floor(totalPower / poolPower) <= ghostSpawnMaxUnits then
			lowestIndex = poolIndex
		end
	end
	if not highestIndex then
		excessPower = excessPower + totalPower
		return nil, 0, true
	end

	local substituteRollCount = GHOST.SUBSTITUTE_ROLL_COUNT
	if gameFrame >= SUBSTITUTE_FAIR_ROLL_FRAMES then
		substituteRollCount = 1
	end
	local substituteIndex = rollFor(PICK_LOWEST, substituteRollCount, lowestIndex or highestIndex, highestIndex)
	local substituteUnitDefID = ghostPoolUnitDefIDs[substituteIndex]
	local substitutePower = zombieUnitDefs[substituteUnitDefID].rezPower
	local purchaseCount = math.min(floor(totalPower / substitutePower), zombieModeSettings.spawnCountMaximum)
	excessPower = excessPower + totalPower - purchaseCount * substitutePower
	return substituteUnitDefID, purchaseCount, true
end

local function retryFailedSubstitutes(substituteUnitDefID, failedCount)
	if currentModeFeatures.ghostRespawns then
		for _ = 1, failedCount do
			pushGhostSpawn(substituteUnitDefID)
		end
		return
	end
	excessPower = excessPower + failedCount * zombieUnitDefs[substituteUnitDefID].rezPower
end

local function spawnZombies(unitDefID, healthReductionRatio, spawnX, spawnY, spawnZ, facing, wasZombie, inheritedXp)
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
		healthReductionRatio,
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
	local healthReductionRatio = calculateHealthRatio(featureID)
	local inheritedXp = spring.GetFeatureRulesParam(featureID, "previous_xp") or 0
	local facing = spring.GetFacingFromHeading(spring.GetFeatureHeading(featureID) or 0)
	corpsesData[featureID] = nil
	spring.DestroyFeature(featureID)
	spawnZombies(unitDefID, healthReductionRatio, featureX, featureY, featureZ, facing, wasZombie, inheritedXp)
	return true
end

local function processDueGhostRespawns(frame)
	local respawns = ghostRespawnFrames[frame]
	if not respawns then
		return
	end
	ghostRespawnFrames[frame] = nil
	for respawnIndex = 1, #respawns do
		local respawn = respawns[respawnIndex]
		local unitPower = getSubstitutionPower(respawn.unitDefID) * zombieModeSettings.ghostPowerMultiplier
		local spawnUnitDefID, spawnCount = resolveSpawnPlan(respawn.unitDefID, respawn.wasZombie, unitPower, 1)
		for _ = 1, spawnCount do
			pushGhostSpawn(spawnUnitDefID)
		end
	end
end

---@return UnitID[]
local function getSortedGhostIDs()
	local ghostIDs = {}
	for unitID in pairs(ghosts) do
		ghostIDs[#ghostIDs + 1] = unitID
	end
	table.sort(ghostIDs)
	return ghostIDs
end

local function forgetGhost(unitID)
	if not ghosts[unitID] then
		return
	end
	ghosts[unitID] = nil
	ghostCount = ghostCount - 1
end

local function removeGhost(unitID)
	forgetGhost(unitID)
	spring.DestroyUnit(unitID, false, true)
end

local function getOldestReplaceableGhostID()
	local oldestUnitID
	local oldestCreationFrame
	for unitID, ghostData in pairs(ghosts) do
		local creationFrame = ghostData.creationFrame
		local isReplaceable = gameFrame - creationFrame >= GHOST.MINIMUM_LIFE
		local isOldest = not oldestCreationFrame
			or creationFrame < oldestCreationFrame
			or (creationFrame == oldestCreationFrame and unitID < oldestUnitID)
		if isReplaceable and isOldest then
			oldestUnitID = unitID
			oldestCreationFrame = creationFrame
		end
	end
	return oldestUnitID
end

local function createGhost(spawnX, spawnZ)
	if not ghostMistUnitDefID or gameFrame < GHOST.SPAWN_GRACE_PERIOD then
		return nil
	end

	local replacedGhostID
	if ghostCount >= GHOST.MAX_COUNT then
		replacedGhostID = getOldestReplaceableGhostID()
		if not replacedGhostID then
			return nil
		end
	end

	local ghostX = clamp(spawnX, GHOST.MAP_MARGIN, Game.mapSizeX - GHOST.MAP_MARGIN)
	local ghostZ = clamp(spawnZ, GHOST.MAP_MARGIN, Game.mapSizeZ - GHOST.MAP_MARGIN)
	local unitID =
		spring.CreateUnit(ghostMistUnitDefID, ghostX, spring.GetGroundHeight(ghostX, ghostZ), ghostZ, 0, gaiaTeamID)
	if not unitID then
		return nil
	end

	if replacedGhostID then
		removeGhost(replacedGhostID)
	end

	spring.SetUnitNeutral(unitID, true)
	spring.SetUnitBuildSpeed(unitID, 0)
	spring.GiveOrderToUnit(unitID, CMD.FIRE_STATE, { 0 }, 0)
	if GG.SetWantedCloaked then
		GG.SetWantedCloaked(unitID, 1)
	else
		spring.SetUnitCloak(unitID, 1)
	end

	ghosts[unitID] = {
		creationFrame = gameFrame,
		readyFrame = gameFrame + GHOST.SAFE_TIME,
		expirationFrame = gameFrame + GHOST.EXPIRATION_TIME,
	}
	ghostCount = ghostCount + 1
	return unitID
end

local function spawnRandomMapGhosts()
	if not autoSpawningEnabled or not currentModeFeatures.ghostRespawns or gameFrame < GHOST.SPAWN_GRACE_PERIOD then
		return
	end

	local minimumX = GHOST.MAP_MARGIN
	local maximumX = floor(Game.mapSizeX - GHOST.MAP_MARGIN)
	local minimumZ = GHOST.MAP_MARGIN
	local maximumZ = floor(Game.mapSizeZ - GHOST.MAP_MARGIN)
	if maximumX < minimumX or maximumZ < minimumZ then
		return
	end

	for _ = 1, GHOST.MAX_RANDOM_SPAWNS_PER_CHECK do
		if ghostCount >= GHOST.MAX_COUNT then
			return
		end
		local spawnX = random(minimumX, maximumX)
		local spawnZ = random(minimumZ, maximumZ)
		createGhost(spawnX, spawnZ)
	end
end

local function feedGhostQueue(unitDefID, spawnX, spawnZ, wasZombie)
	if not autoSpawningEnabled or not currentModeFeatures.ghostRespawns then
		return
	end
	local unitDefData = zombieUnitDefs[unitDefID]
	if not unitDefData.corpseDefID or unitDefData.neverRespawn or unitDefData.excludedFromGhostSpawn then
		return
	end
	pendingGhostFeeds[#pendingGhostFeeds + 1] = { unitDefID = unitDefID, x = spawnX, z = spawnZ, wasZombie = wasZombie }
end

local function processGhostFeeds()
	if #pendingGhostFeeds == 0 then
		return
	end
	local ghostFeeds = pendingGhostFeeds
	pendingGhostFeeds = {}
	for feedIndex = 1, #ghostFeeds do
		local ghostFeed = ghostFeeds[feedIndex]
		if random() < zombieModeSettings.ghostFeedSuccessChance then
			local spawnDelayFrames = (zombieUnitDefs[ghostFeed.unitDefID].spawnDelayFrames or 0)
				* zombieModeSettings.ghostRespawnDelayMultiplier
			local respawnFrame = gameFrame + math.max(spawnDelayFrames, 1)
			local respawn = { unitDefID = ghostFeed.unitDefID, wasZombie = ghostFeed.wasZombie }
			addToFrameList(ghostRespawnFrames, respawnFrame, respawn)
		end
		createGhost(ghostFeed.x, ghostFeed.z)
	end
end

local function expireZombieTurret(unitID)
	if not spring.ValidUnitID(unitID) then
		return
	end
	local unitDefID = spring.GetUnitDefID(unitID)
	if not unitDefID or not isZombie(unitID) or not zombieUnitDefs[unitDefID].isExpiringBuilding then
		return
	end
	local unitX, _, unitZ = spring.GetUnitPosition(unitID)
	suppressedDeaths[unitID] = true
	if unitX then
		feedGhostQueue(unitDefID, unitX, unitZ, true)
	end
	spring.DestroyUnit(unitID, true, true)
end

local function expireDueZombieTurrets(frame)
	local expiringTurrets = zombieTurretExpirationFrames[frame]
	if not expiringTurrets then
		return
	end
	zombieTurretExpirationFrames[frame] = nil
	for turretIndex = 1, #expiringTurrets do
		expireZombieTurret(expiringTurrets[turretIndex])
	end
end

local function collectReadyGhosts()
	local readyGhosts = {}
	for unitID, ghostData in pairs(ghosts) do
		if gameFrame >= ghostData.readyFrame then
			local ghostX, _, ghostZ = spring.GetUnitPosition(unitID)
			if ghostX then
				readyGhosts[#readyGhosts + 1] = { x = ghostX, z = ghostZ, assignedCount = 0 }
			else
				forgetGhost(unitID)
			end
		end
	end
	return readyGhosts
end

local function getGhostSpawnAttemptPosition(originX, originZ, size)
	local angle = random() * 2 * math.pi
	local distance = random() * GHOST.SPAWN_OFFSET_DISTANCE
	local spawnX = clamp(originX + math.cos(angle) * distance, size, Game.mapSizeX - size)
	local spawnZ = clamp(originZ + math.sin(angle) * distance, size, Game.mapSizeZ - size)
	local spawnY = spring.GetGroundHeight(spawnX, spawnZ)
	return spawnX, spawnY, spawnZ
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

local function attemptGhostBufferSpawn(unitDefID, readyGhosts)
	local unitDefToCreate = zombieUnitDefs[unitDefID].scavVariantUnitDefID
	local size = zombieUnitDefs[unitDefToCreate].size
	for ghostIndex = 1, #readyGhosts do
		local readyGhost = readyGhosts[ghostIndex]
		for _ = 1, GHOST.SPAWN_ATTEMPT_COUNT do
			local spawnX, spawnY, spawnZ = getGhostSpawnAttemptPosition(readyGhost.x, readyGhost.z, size)
			local facing = random(0, 3)
			if canSpawnUnitAt(unitDefToCreate, spawnX, spawnY, spawnZ, facing) then
				if spawnZombieUnits(unitDefID, 1, 1, spawnX, spawnY, spawnZ, facing, 0, true) > 0 then
					readyGhost.assignedCount = readyGhost.assignedCount + 1
					return "spawned"
				end
				return "failed"
			end
		end
	end
	return "unspawned"
end

local function orderReadyGhostsByAssignedCount(readyGhosts)
	for ghostIndex = #readyGhosts, 2, -1 do
		local swapIndex = random(1, ghostIndex)
		readyGhosts[ghostIndex], readyGhosts[swapIndex] = readyGhosts[swapIndex], readyGhosts[ghostIndex]
	end
	table.sort(readyGhosts, function(firstGhost, secondGhost)
		return firstGhost.assignedCount < secondGhost.assignedCount
	end)
end

local function spawnBufferedGhostUnits()
	local readyGhosts = collectReadyGhosts()
	if #readyGhosts == 0 then
		return
	end
	local remainingSpawns = {}
	local unspawnableUnitDefIDs = {}
	local bufferIndex = 1
	local lastAttemptIndex = math.min(#ghostSpawnBuffer, GHOST.MAX_BUFFER_SPAWNS_PER_PASS)
	while bufferIndex <= lastAttemptIndex do
		if isTeamAtUnitCap(gaiaTeamID) then
			break
		end

		local unitDefID = ghostSpawnBuffer[bufferIndex]
		local spawnResult = "unspawned"
		if not unspawnableUnitDefIDs[unitDefID] then
			orderReadyGhostsByAssignedCount(readyGhosts)
			spawnResult = attemptGhostBufferSpawn(unitDefID, readyGhosts)
			if spawnResult == "unspawned" then
				unspawnableUnitDefIDs[unitDefID] = true
			end
		end
		if spawnResult ~= "spawned" then
			remainingSpawns[#remainingSpawns + 1] = unitDefID
		end
		bufferIndex = bufferIndex + 1
		if spawnResult == "failed" then
			break
		end
	end

	for spawnIndex = bufferIndex, #ghostSpawnBuffer do
		remainingSpawns[#remainingSpawns + 1] = ghostSpawnBuffer[spawnIndex]
	end
	ghostSpawnBuffer = remainingSpawns
end

local function hasPendingGhostSpawn()
	if #ghostSpawnBuffer > 0 then
		return true
	end
	for _, respawns in pairs(ghostRespawnFrames) do
		if #respawns > 0 then
			return true
		end
	end
	return false
end

local function spawnGhostReadyLightning(ghostX, ghostY, ghostZ)
	if random() < 0.5 then
		return
	end
	local lightningY = ghostY + 100
	if GG.SpawnEnvironmentalLightning then
		GG.SpawnEnvironmentalLightning("scavradiation", ghostX, lightningY, ghostZ, 0.5)
	end
	spring.SpawnCEG(EFFECT.RADIATION_LIGHTNING, ghostX, lightningY, ghostZ, 0, 0, 0)
	spring.SpawnCEG(EFFECT.SPAWN_TRAIL, ghostX, ghostY, ghostZ, 0, 0, 0, 32)
end

local function updateGhosts()
	local ghostIDs = getSortedGhostIDs()
	local pendingGhostSpawn = hasPendingGhostSpawn()
	local gaiaAtUnitCap = isTeamAtUnitCap(gaiaTeamID)
	for ghostIndex = 1, #ghostIDs do
		local unitID = ghostIDs[ghostIndex]
		local ghostData = ghosts[unitID]
		if ghostData then
			local unitDefID = spring.GetUnitDefID(unitID)
			local ghostX, ghostY, ghostZ = spring.GetUnitPosition(unitID)
			if not unitDefID or not ghostX then
				forgetGhost(unitID)
			elseif gameFrame >= ghostData.expirationFrame then
				removeGhost(unitID)
			else
				local enemyNearby = GG.ZombieAI and GG.ZombieAI.CommandGhost(unitID, unitDefID, ghostX, ghostY, ghostZ)
				if enemyNearby then
					ghostData.readyFrame = gameFrame + GHOST.SAFE_TIME
				elseif gameFrame >= ghostData.readyFrame and pendingGhostSpawn and not gaiaAtUnitCap then
					spawnGhostReadyLightning(ghostX, ghostY, ghostZ)
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

	local health, maxHealth = spring.GetUnitHealth(unitID)
	local _, newMaxHealth = spring.GetUnitHealth(newUnitID)
	if health and maxHealth > 0 then
		spring.SetUnitHealth(newUnitID, health / maxHealth * newMaxHealth)
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

function gadget:FeatureBuildStepPost(featureID)
	local featureData = corpsesData[featureID]
	if not featureData or featureData.zombieStepFrame == gameFrame then
		return
	end
	local remainingFrames = featureData.spawnFrame - gameFrame
	local isTimerNearMaximum = remainingFrames >= featureData.spawnDelayFrames - TIMER_NEAR_MAX_THRESHOLD
	if not featureData.tamperedFrame and not isTimerNearMaximum then
		local featureX, featureY, featureZ = spring.GetFeaturePosition(featureID)
		if featureX and featureY then
			spring.SpawnCEG(EFFECT.SPAWN_TRAIL, featureX, featureY + 15, featureZ, 0, 0, 0)
		end
	end
	featureData.tamperedFrame = gameFrame
end

function gadget:AllowFeatureBuildStep(builderID, builderTeam, featureID, featureDefID, part)
	if part <= 0 or builderTeam ~= gaiaTeamID or not isZombie(builderID) then
		return true
	end
	if rezzedCorpses[featureID] then
		return false
	end
	local corpseData = corpsesData[featureID]
	if corpseData then
		corpseData.zombieStepFrame = gameFrame
	end
	local corpseDefData = zombieCorpseDefs[featureDefID]
	local metal, maxMetal = spring.GetFeatureResources(featureID)
	local _, _, resurrectProgress = spring.GetFeatureHealth(featureID)
	if not corpseDefData or metal < maxMetal or resurrectProgress + part < 1 then
		return true
	end
	rezzedCorpses[featureID] = true
	if not spawnZombiesFromFeature(featureID, corpseDefData.unitDefID, wasZombieCorpse(featureID, corpseData)) then
		rezzedCorpses[featureID] = nil
		return true
	end
	return false
end

local function isUnitInLava(unitID)
	local _, unitY = spring.GetUnitBasePosition(unitID)
	if not unitY then
		return false
	end

	local lavaLevel = spring.GetGameRulesParam("lavaLevel")
	if lavaLevel ~= nil and unitY < lavaLevel then
		return true
	end

	local waterTypeOverlay = GG.WaterTypeOverlay
	if waterTypeOverlay and waterTypeOverlay.isActive() and waterTypeOverlay.getActiveType() == "lava" then
		local overlayLevel = waterTypeOverlay.getLevel()
		if overlayLevel and unitY < overlayLevel then
			return true
		end
	end

	return false
end

local function isFluidDeath(unitID, weaponDefID, attackerID)
	if weaponDefID == WATER_DAMAGE_DEF_ID then
		return true
	end
	if not isUnitInLava(unitID) then
		return false
	end
	if not weaponDefID or weaponDefID < 0 then
		return true
	end
	if not attackerID or attackerID < 0 or not spring.ValidUnitID(attackerID) then
		return true
	end
	return false
end

local function isCorpseGuaranteeEligible(unitID, unitDefID, weaponDefID, inFluid)
	if not currentModeFeatures.alwaysCorpses or inFluid or DEATHS_WITHOUT_CORPSE[weaponDefID] then
		return false
	end
	local unitDefData = zombieUnitDefs[unitDefID]
	if unitDefData.neverRespawn or not zombieCorpseDefs[unitDefData.corpseDefID] then
		return false
	end
	local _, _, _, _, buildProgress = spring.GetUnitHealth(unitID)
	return buildProgress == nil or buildProgress >= 1
end

local function recordPendingDeath(unitID, unitDefID, unitTeam, attackerID, weaponDefID)
	if not zombieUnitDefs[unitDefID].corpseDefID then
		return
	end
	local unitX, unitY, unitZ = spring.GetUnitPosition(unitID)
	if not unitX then
		return
	end
	local wasZombie = isZombie(unitID)
	local inFluid = currentModeFeatures.alwaysCorpses and isFluidDeath(unitID, weaponDefID, attackerID)
	local guaranteeCorpse = isCorpseGuaranteeEligible(unitID, unitDefID, weaponDefID, inFluid)
	local deathData = {
		unitDefID = unitDefID,
		teamID = unitTeam,
		x = unitX,
		y = unitY,
		z = unitZ,
		wasZombie = wasZombie,
		demoteCorpse = wasZombie and (inFluid or not currentModeFeatures.alwaysCorpses),
		forcedHeap = false,
		guaranteeCorpse = guaranteeCorpse,
		timeoutFrame = gameFrame + PENDING_DEATH_TIMEOUT_FRAMES,
	}
	if guaranteeCorpse then
		local unitStates = spring.GetUnitStates(unitID)
		deathData.heading = spring.GetUnitHeading(unitID) or 0
		deathData.experience = spring.GetUnitExperience(unitID) or 0
		deathData.fireState = unitStates and unitStates.firestate
		deathData.moveState = unitStates and unitStates.movestate
	end
	pendingDeaths[unitID] = deathData
end

local function readPreviousStates(featureID)
	local previousStates = {}
	for paramIndex = 1, #RULES_PARAM.PREVIOUS_STATE do
		local paramName = RULES_PARAM.PREVIOUS_STATE[paramIndex]
		previousStates[paramName] = spring.GetFeatureRulesParam(featureID, paramName)
	end
	return previousStates
end

local function applyPreviousStates(featureID, previousStates)
	if not previousStates then
		return
	end
	for paramIndex = 1, #RULES_PARAM.PREVIOUS_STATE do
		local paramName = RULES_PARAM.PREVIOUS_STATE[paramIndex]
		local paramValue = previousStates[paramName]
		if paramValue then
			spring.SetFeatureRulesParam(featureID, paramName, paramValue)
		end
	end
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

	if not deathData or deathData.forcedHeap then
		return
	end
	local featureX, _, featureZ = spring.GetFeaturePosition(featureID)
	if featureX then
		feedGhostQueue(deathData.unitDefID, featureX, featureZ, deathData.wasZombie)
	end
end

local function setUpReplacementFeature(featureID, featureDefID, deathData)
	applyPreviousStates(featureID, deathData.previousStates)
	if featureDefID == zombieUnitDefs[deathData.unitDefID].corpseDefID then
		local featureFacing = spring.GetFacingFromHeading(spring.GetFeatureHeading(featureID) or 0)
		spring.SetFeatureResurrect(featureID, deathData.unitDefID, featureFacing)
	end
	registerDeathFeature(featureID, featureDefID, deathData)
end

local function createDeathCorpse(deathData, featureX, featureY, featureZ, heading, teamID)
	local corpseDefID = zombieUnitDefs[deathData.unitDefID].corpseDefID
	replacementDeathData = deathData
	local featureID = spring.CreateFeature(corpseDefID, featureX, featureY, featureZ, heading, teamID)
	replacementDeathData = nil
	if not featureID then
		feedGhostQueue(deathData.unitDefID, featureX, featureZ, deathData.wasZombie)
	end
end

local function demoteCorpseToHeap(featureID, deathData)
	deathData.previousStates = nil
	deathData.forcedHeap = true
	replacementDeathData = deathData
	spring.CreateFeatureWreck(featureID, 1)
	replacementDeathData = nil
	spring.DestroyFeature(featureID)
end

local function promoteHeapToCorpse(featureID, deathData, featureX, featureY, featureZ)
	deathData.previousStates = readPreviousStates(featureID)
	local heading = spring.GetFeatureHeading(featureID)
	local teamID = spring.GetFeatureTeam(featureID)
	spring.DestroyFeature(featureID)
	createDeathCorpse(deathData, featureX, featureY, featureZ, heading, teamID)
end

local function processWreckSwaps()
	if #pendingWreckSwaps == 0 then
		return
	end
	local wreckSwaps = pendingWreckSwaps
	pendingWreckSwaps = {}
	for _, wreckSwap in ipairs(wreckSwaps) do
		local featureID = wreckSwap.featureID
		local featureX, featureY, featureZ = spring.GetFeaturePosition(featureID)
		if featureX then
			if wreckSwap.demote then
				demoteCorpseToHeap(featureID, wreckSwap.deathData)
			else
				promoteHeapToCorpse(featureID, wreckSwap.deathData, featureX, featureY, featureZ)
			end
		end
	end
end

local function resolveDeathWithoutWreck(deathData)
	if not deathData.guaranteeCorpse then
		feedGhostQueue(deathData.unitDefID, deathData.x, deathData.z, deathData.wasZombie)
		return
	end
	deathData.previousStates = {
		previous_xp = deathData.experience,
		previous_firestate = deathData.fireState,
		previous_movestate = deathData.moveState,
	}
	createDeathCorpse(deathData, deathData.x, deathData.y, deathData.z, deathData.heading, deathData.teamID)
end

local function resolveVanishedDeaths()
	if next(pendingDeaths) == nil then
		return
	end
	local vanishedDeaths = {}
	for unitID, deathData in pairs(pendingDeaths) do
		if spring.GetUnitIsDead(unitID) ~= true then
			pendingDeaths[unitID] = nil
			vanishedDeaths[#vanishedDeaths + 1] = deathData
		elseif deathData.timeoutFrame <= gameFrame then
			pendingDeaths[unitID] = nil
		end
	end
	for deathIndex = 1, #vanishedDeaths do
		resolveDeathWithoutWreck(vanishedDeaths[deathIndex])
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
	if corpseData.tamperedFrame then
		local tamperedFrame = corpseData.tamperedFrame
		corpseData.creationFrame = tamperedFrame
		corpseData.tamperedFrame = nil -- reclaim/rez progress restarts the spawn timer from this frame
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

local function spawnCorpseWarnings(frame)
	for featureID, featureData in pairs(corpsesData) do
		if featureData.spawnFrame - frame < WARNING_TIME then
			local featureX, featureY, featureZ = spring.GetFeaturePosition(featureID)
			if not featureX then --doesn't exist anymore
				corpsesData[featureID] = nil
			elseif not featureData.tamperedFrame then
				spawnWarningEffects(featureID, featureX, featureY, featureZ)
			end
		end
	end
end

function gadget:GameFrame(frame)
	gameFrame = frame

	processWreckSwaps()
	resolveVanishedDeaths()
	expireDueZombieTurrets(frame)
	if currentModeFeatures.ghostRespawns then
		processGhostFeeds()
		processDueGhostRespawns(frame)
		if frame % GHOST.SPAWN_CHECK_INTERVAL == 0 then
			spawnBufferedGhostUnits()
		end
		if frame >= GHOST.SPAWN_GRACE_PERIOD and frame % GHOST.RANDOM_SPAWN_INTERVAL == 0 then
			spawnRandomMapGhosts()
		end
	end

	if frame % REZ_SPEED_UPDATE_INTERVAL == 0 then
		updateRezSpeed()
	end

	processDueCorpses(frame)

	if frame % ZOMBIE_CHECK_INTERVAL == 0 then
		updateTooLong(frame)
		if currentModeFeatures.ghostRespawns then
			updateGhosts()
		end
		topUpGaiaResources()
		spawnCorpseWarnings(frame)
	end
end

local function getWreckSwap(featureID, featureDefID, deathData)
	local unitDefData = zombieUnitDefs[deathData.unitDefID]
	if featureDefID == unitDefData.corpseDefID and deathData.demoteCorpse then
		return { featureID = featureID, deathData = deathData, demote = true }
	end
	if featureDefID == unitDefData.heapDefID and deathData.guaranteeCorpse then
		return { featureID = featureID, deathData = deathData, demote = false }
	end
	return nil
end

function gadget:FeatureCreated(featureID, _, sourceID)
	local featureDefID = spring.GetFeatureDefID(featureID)
	if replacementDeathData then
		setUpReplacementFeature(featureID, featureDefID, replacementDeathData)
		return
	end
	local deathData = sourceID and pendingDeaths[sourceID] or nil
	if deathData then
		pendingDeaths[sourceID] = nil
		local wreckSwap = getWreckSwap(featureID, featureDefID, deathData)
		if wreckSwap then
			pendingWreckSwaps[#pendingWreckSwaps + 1] = wreckSwap
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
		local featureX = corpseData.x
		local featureZ = corpseData.z
		if corpseDefData then
			feedGhostQueue(corpseDefData.unitDefID, featureX, featureZ, corpseData.wasZombie)
		end
	end
	clearCorpseRezRulesParam(featureID)
	corpsesData[featureID] = nil
	rezzedCorpses[featureID] = nil
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
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
	local wasGhost = ghosts[unitID] ~= nil
	forgetGhost(unitID)

	if not suppressedDeaths[unitID] and not wasGhost and unitDefID ~= ghostMistUnitDefID then
		recordPendingDeath(unitID, unitDefID, unitTeam, attackerID, weaponDefID)
	end

	suppressedDeaths[unitID] = nil
	pendingZombieCaptures[unitID] = nil
	zombiesBeingBuilt[unitID] = nil
	zombieFactories[unitID] = nil
end

function gadget:AllowUnitCaptureStep(builderID, builderTeam, unitID, unitDefID, part)
	if isZombie(builderID) then
		pendingZombieCaptures[unitID] = true
	end
	return true
end

function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	if newTeam ~= gaiaTeamID then
		revertZombieFactoryBuildpower(unitID)
	end
	if not pendingZombieCaptures[unitID] then
		return
	end
	pendingZombieCaptures[unitID] = nil
	if isZombie(unitID) then
		return
	end

	local unitX, unitY, unitZ = spring.GetUnitPosition(unitID)
	local health, maxHealth = spring.GetUnitHealth(unitID)
	local inheritedXp = spring.GetUnitExperience(unitID) or 0
	local facing = spring.GetUnitBuildFacing(unitID) or 0
	local healthReductionRatio = 1.0
	if health and maxHealth and maxHealth ~= 0 then
		healthReductionRatio = health / maxHealth
	end
	suppressedDeaths[unitID] = true
	spring.DestroyUnit(unitID, false, true)

	local spawnDefID = unitDefID
	local swapOverride = zombieUnitDefs[unitDefID].captureOverride
	if swapOverride then
		spawnDefID = swapOverride ~= "delete" and unitDefNames[swapOverride].id or nil
	end
	if unitX and spawnDefID then
		spawnZombies(spawnDefID, healthReductionRatio, unitX, unitY, unitZ, facing, false, inheritedXp)
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

local function clearGhostState()
	local ghostIDs = getSortedGhostIDs()
	ghosts = {}
	ghostCount = 0
	for ghostIndex = 1, #ghostIDs do
		spring.DestroyUnit(ghostIDs[ghostIndex], false, true)
	end
	ghostSpawnBuffer = {}
	ghostRespawnFrames = {}
	pendingGhostFeeds = {}
end

---Drops every queued corpse spawn without affecting zombies already raised.
local function clearAllZombieSpawns()
	for featureID in pairs(corpsesData) do
		clearCorpseRezRulesParam(featureID)
	end
	corpsesData = {}
	corpseCheckFrames = {}
	excessPower = 0
	clearGhostState()
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
		if unitTeam == gaiaTeamID and not isZombie(unitID) and not ghosts[unitID] then
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

---Switches the live zombie mode, removing apparitions when the new mode has no ghosts.
---@param mode ZombieMode
local function applyZombieModeSettings(mode)
	currentZombieMode = mode
	currentModeFeatures = ZOMBIE_MODE_FEATURES[mode]
	if not currentModeFeatures.ghostRespawns then
		clearGhostState()
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
		description = "Set zombie mode (basic/oni/yokai/nani/akumu/spidergeddon)",
		run = function(words, playerID)
			if #words == 0 then
				spring.SendMessageToPlayer(
					playerID,
					"Usage: /luarules zombiemode basic|oni|yokai|nani|akumu|spidergeddon"
				)
				return
			end
			local mode = string.lower(words[1])
			if not setZombieMode(mode) then
				spring.SendMessageToPlayer(
					playerID,
					"Invalid mode. Use: basic, oni, yokai, nani, akumu, or spidergeddon"
				)
				return
			end
			spring.SendMessageToPlayer(playerID, "Zombie mode set to " .. mode)
		end,
	},
}

function gadget:Initialize()
	gameFrame = spring.GetGameFrame()
	if gameFrame >= TOO_LONG_GAME_FRAMES then
		tooLong = true
	end

	applyZombieModeSettings(resolveZombieMode(modOptions.zombies))
	updateRezSpeed()

	autoSpawningEnabled = modOptionEnabled and not isIdleMode

	local units = spring.GetAllUnits()
	for _, unitID in ipairs(units) do
		if isZombie(unitID) then
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
