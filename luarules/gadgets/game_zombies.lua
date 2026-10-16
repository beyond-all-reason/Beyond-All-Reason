-- [Scavenger Zombies] Zombies do not capture units that are still being built.
-- [Scavenger Zombies] After 60 minutes, zombies stay permanently aggro'd. Revival delays calculated from then on use a fixed speed of 20 instead of the tech estimate. Corpses that are already waiting keep the delay they were given.
-- [Scavenger Zombies] Gaia zombie factories build at their original buildpower * 1.7 ^ the current tech estimate. The boost is removed when the factory leaves Gaia, including a transfer to the Scavenger team. The 60 minute speed change does not change this boost.
-- [Scavenger Zombies] Modes are Basic, Oni, Yokai, Nani?!, Akumu, and Spidergeddon. They share one revival speed table, and power-based revival times are clamped to 45 to 120 seconds. Oni adds a corpse when an eligible death would otherwise leave none. Yokai adds ghostly apparitions. Nani?! adds multiple spawns. Akumu and Spidergeddon combine all three. Spidergeddon stamps zombie_ghost_respawn_pool onto its substitute list when the game loads. Switching mode after that does not add or remove the pool.
-- [Scavenger Zombies] Nani?!, Akumu, and Spidergeddon roll 2 to 6 zombies per corpse. At tech 1 or below, the count is the lowest of 3 rolls. Above tech 1, units whose power-based revival time is the minimum take the highest of 2 rolls, units at the maximum take the lowest of 3 rolls, and units in between roll once. A custom respawn time does not change which roll is used. Other modes always roll 1. Corpses that were already zombies, and units that cannot move, always roll 1. That roll is how many copies are created, or the budget multiplier when substitutes are bought. Dead zombies have their corpse swapped for a heap outside Oni, Akumu, and Spidergeddon, so they rise only once. In those three modes, a death with no wreck still leaves a corpse, except reclaims, Lua removals, cheat kills, out of bounds, units turned into features, cancelled or decaying builds, units still being built, metal extractors, geothermals, units with a negative zombie_respawn_time, drowning, and lava that kills the unit by itself. A weapon kill while the unit is standing in lava still leaves a corpse. Zombies that drown, or die to lava by itself, never leave a resurrectable corpse. Zombie turrets are removed after 10 minutes and do not leave a corpse.
-- [Scavenger Zombies] In Yokai, Akumu, and Spidergeddon, apparitions are fed by deaths that leave no resurrectable corpse, by queued corpses destroyed by anything other than reclaim or resurrection, and by zombie turrets that expire. Harmless metal and energy structures, and radar, sonar, or jammer structures, never feed them. A dead zombie whose corpse was forced into a heap does not feed them. In Yokai, a zombie overkilled into a heap or nothing still takes the roll. In Akumu and Spidergeddon, ordinary overkill leaves a corpse instead, so it does not. Each feeding death has a 66% chance to enter the apparition respawn queue at 4 times that unit's revival delay. A failed roll drops the unit. An apparition is still placed at the death location, except during the first 5 minutes, and except when 25 apparitions exist and none has lived at least 30 seconds. After the first 5 minutes, up to 3 more apparitions appear at random every minute, up to 25. Each lives 2 minutes, is not ready to manifest a queued unit for 20 seconds, and that wait resets while an enemy is within 300.
-- [Scavenger Zombies] When any unit has zombie_ghost_respawn_pool, revived corpses, apparition respawns, and units captured by zombies rise as substitutes instead of the original unit. Pool units that were already zombies rise as themselves. Other zombies are substituted. The budget is the unit's power, times 0.5 times the current tech level for commanders, times the rolled spawn count for revived corpses and captures. Apparition respawns use a count of 1, after multiplying that power by the ghost power multiplier, which defaults to 1. Up to that same power can be borrowed from the floating excess. Substitutes from the cheapest up to the most expensive affordable one are considered, skipping the cheapest ones that would buy more than the maximum spawn count. One is picked from what remains by taking the cheaper of 2 random rolls until 20 minutes, and by one roll across that same range after 20 minutes, or the most expensive affordable one if every affordable substitute would exceed that count. As many as can be afforded are bought, up to the maximum spawn count. If none can be afforded, the whole budget is added to the floating excess. Otherwise the leftover goes back to it. Substitutes that fail to spawn on the spot are queued as that same substitute for an apparition, or refunded to the floating excess in modes without apparitions.
-- [Scavenger Zombies] Todo: Should zombies be infinitely recycled? Or should they have a chance to exit the respawn queue?

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
--     substitutes one spawn can buy. Swapped if the minimum is greater than the maximum.
--   zombie_minimum_respawn_delay (seconds, default 45)
--   zombie_maximum_respawn_delay (seconds, default 120)
--     the window that power-based revival times are clamped to. Swapped if the minimum is greater than the maximum.
--   zombie_ghost_respawn_chance (0 to 1, default 0.66)
--     the chance that a death feeding the apparitions enters the apparition respawn queue.
--   zombie_ghost_power_multiplier (default 1, minimum 0)
--     multiplies a unit's power when an apparition respawn spends it on substitutes. Units that rise as
--     themselves are unchanged. Revived corpses and captures do not use this multiplier.
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

local WARNING_TIME = Game.gameSpeed * 15 -- Frames to start warning before reanimation
local TIMER_NEAR_MAX_THRESHOLD = Game.gameSpeed * 5 -- skip the tamper sparkle if the spawn timer is still near its maximum
local ZOMBIE_REZ_FRAME_PARAM = "zombie_rez_frame"
local WAS_ZOMBIE_PARAM = "wasZombie"
local PUBLIC_RULES_PARAM_ACCESS = { public = true }
local PENDING_DEATH_TIMEOUT_FRAMES = Game.gameSpeed * 10
local PREVIOUS_STATE_PARAMS = { "previous_xp", "previous_firestate", "previous_movestate" }
local CORPSE_HEAP_MATCH_DISTANCE = 64
local FACTORY_BUILDPOWER_TECH_BASE = 1.7
local GHOST = {
	SAFE_TIME = Game.gameSpeed * 20,
	MINIMUM_LIFE = Game.gameSpeed * 30,
	EXPIRATION_TIME = Game.gameSpeed * 120,
	MAP_MARGIN = 16,
	SPAWN_ATTEMPT_COUNT = 3,
	SPAWN_OFFSET_DISTANCE = 50,
	SPAWN_CHECK_INTERVAL = Game.gameSpeed * 60,
	SPAWN_GRACE_PERIOD = Game.gameSpeed * 60 * 5,
	RANDOM_SPAWN_INTERVAL = Game.gameSpeed * 60,
	MAX_RANDOM_SPAWNS_PER_CHECK = 3,
	MAX_COUNT = 25,
	RESPAWN_DELAY_MULTIPLIER = 4,
	MAX_BUFFER_SPAWNS_PER_PASS = 100,
	MIST_UNIT_NAME = "scavapparition",
}
local ZOMBIE_TURRET_LIFETIME = Game.gameSpeed * 60 * 10
local LOWEST = true
local HIGHEST = false
local SUBSTITUTE_ROLL_COUNT = 2
local SUBSTITUTE_FAIR_ROLL_FRAMES = Game.gameSpeed * 60 * 20
local COMMANDER_SUBSTITUTION_POWER_MULTIPLIER = 0.5

local zombieModeSettings = {
	spawnCountMinimum = 2,
	spawnCountMaximum = 6,
	respawnDelayMinimum = 45,
	respawnDelayMaximum = 120,
	ghostFeedSuccessChance = 0.66,
	ghostPowerMultiplier = 1,
}

local TECH_TO_REZ_POWER_SPEEDS = {
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

local ZOMBIE_CHECK_INTERVAL = Game.gameSpeed -- How often (in frames) everything else is checked
local REZ_SPEED_UPDATE_INTERVAL = Game.gameSpeed * 60
local TOO_LONG_GAME_FRAMES = Game.gameSpeed * 60 * 60
local TOO_LONG_REZ_POWER_SPEED = 20
local WATER_DAMAGE_DEF_ID = Game.envDamageTypes.Water
local CORPSE_GUARANTEE_EXCLUDED_DEATH_NAMES = {
	Reclaimed = true,
	KilledByLua = true,
	TurnedIntoFeature = true,
	FactoryCancel = true,
	ConstructionDecay = true,
	OutOfBounds = true,
	KilledByCheat = true,
}
local CORPSE_GUARANTEE_EXCLUDED_DEATHS = {}
for deathName, damageTypeID in pairs(Game.envDamageTypes) do
	CORPSE_GUARANTEE_EXCLUDED_DEATHS[damageTypeID] = CORPSE_GUARANTEE_EXCLUDED_DEATH_NAMES[deathName]
end
local CORPSE_RESET_CEG = "selfrepair-sparks-purple"
local CORPSE_RESET_CEG_HEIGHT = 15
local UNAUTHORIZED_TEXT = "You are not authorized to use zombie commands" --i18n library doesn't exist in gadget space.
local GAIA_RESOURCE_AMOUNT = 1000000
local GAIA_RESOURCES = {
	{ resourceName = "metal", storageKey = "ms" },
	{ resourceName = "energy", storageKey = "es" },
}
local SPAWN_EFFECT_SIZE_THRESHOLDS = {
	{ threshold = 4.5, name = "huge" },
	{ threshold = 3.5, name = "large" },
	{ threshold = 2.5, name = "medium" },
	{ threshold = 1.5, name = "small" },
}
local ZOMBIE_AI_FORWARDED_METHODS = {
	{ methodName = "PacifyZombies" },
	{ methodName = "SuspendAutoOrders" },
	{ methodName = "AggroTeamID", missingResult = false },
	{ methodName = "AggroAllyID", missingResult = false },
	{ methodName = "KillAllZombies" },
	{ methodName = "ClearAllOrders" },
}
local random = math.random
local floor = math.floor
local clamp = math.clamp

local function rollFor(keep, rollCount, minimum, maximum)
	local result = random(minimum, maximum)
	for _ = 2, rollCount do
		local roll = random(minimum, maximum)
		if (keep == LOWEST and roll < result) or (keep == HIGHEST and roll > result) then
			result = roll
		end
	end
	return result
end

local function findScavengerTeamID()
	for _, teamID in ipairs(spring.GetTeamList() or {}) do
		local teamLuaAI = spring.GetTeamLuaAI(teamID)
		if teamLuaAI and string.find(teamLuaAI, "ScavengersAI") then
			return teamID
		end
	end
	return nil
end

local scavTeamID = findScavengerTeamID()
local gaiaTeamID = spring.GetGaiaTeamID()

local gameFrame = 0
local tooLong = false
local adjustedRezPowerSpeed = TECH_TO_REZ_POWER_SPEEDS[1]
local currentTechLevel = nil
local autoSpawningEnabled = true

local zombiesBeingBuilt = {}
local rezzedCorpses = {}
local zombieCorpseDefs = {} ---@type table<FeatureDefID, table?>
local corpseCheckFrames = {}
local corpsesData = {}
local pendingDeaths = {}
local pendingWreckSwaps = {}
local replacementDeathData = nil ---@type table?
local pendingZombieCaptures = {}
local suppressedDeaths = {}
local zombieHeapDefs = {}
local zombieHeapFeatureDefs = {} ---@type table<FeatureDefID, table?>
local zombieUnitDefs = {}
local zombieUnitRoles = {}
local zombieFactories = {} ---@type table<UnitID, table?>
local ghostPoolUnitDefIDs = {}
local substitutePoolMemberUnitDefIDs = {}
local excessPower = 0
local ghostRespawnFrames = {}
local pendingCorpseHeapFeeds = {}
local ghostSpawnBuffer = {}
local zombieTurretExpirationFrames = {}
local ghosts = {} ---@type table<UnitID, table?>
local ghostCount = 0
local captureSwapOverride = {}
local unitDefs = UnitDefs
local unitDefNames = UnitDefNames
local WARNING_EFFECTS = {
	"scavmist",
	"scavradiation-lightning",
}
local SPAWN_SOUNDS = {
	"xploelc2",
	"xploelc3",
}

do
	local function setNumericSetting(customParams, customParamName, settingName, minimum, maximum, integer)
		local value = tonumber(customParams[customParamName])
		if value then
			value = clamp(value, minimum, maximum)
			zombieModeSettings[settingName] = integer and floor(value) or value
		end
	end

	local FEATURE_CUSTOM_PARAMS = {
		zombie_enable_yokai = { "ghostRespawns" },
		zombie_enable_oni = { "alwaysCorpses" },
		zombie_enable_nani = { "multipleSpawns" },
	}
	local featureOverrides = {}
	for unitDefID = 1, #unitDefs do
		local customParams = unitDefs[unitDefID].customParams ---@type table<string, any>
		setNumericSetting(customParams, "zombie_ghost_respawn_chance", "ghostFeedSuccessChance", 0, 1)
		setNumericSetting(customParams, "zombie_ghost_power_multiplier", "ghostPowerMultiplier", 0, math.huge)
		setNumericSetting(customParams, "zombie_minimum_spawns", "spawnCountMinimum", 1, math.huge, true)
		setNumericSetting(customParams, "zombie_maximum_spawns", "spawnCountMaximum", 1, math.huge, true)
		setNumericSetting(customParams, "zombie_minimum_respawn_delay", "respawnDelayMinimum", 0, math.huge)
		setNumericSetting(customParams, "zombie_maximum_respawn_delay", "respawnDelayMaximum", 0, math.huge)
		for customParamName, featureNames in pairs(FEATURE_CUSTOM_PARAMS) do
			local value = tonumber(customParams[customParamName])
			if value == 1 or value == 0 then
				local enabled = value == 1
				for featureIndex = 1, #featureNames do
					featureOverrides[featureNames[featureIndex]] = enabled
				end
			end
		end
	end

	local spawnCountMinimum = zombieModeSettings.spawnCountMinimum
	local spawnCountMaximum = zombieModeSettings.spawnCountMaximum
	local respawnDelayMinimum = zombieModeSettings.respawnDelayMinimum
	local respawnDelayMaximum = zombieModeSettings.respawnDelayMaximum
	zombieModeSettings.spawnCountMinimum = math.min(spawnCountMinimum, spawnCountMaximum)
	zombieModeSettings.spawnCountMaximum = math.max(spawnCountMinimum, spawnCountMaximum)
	zombieModeSettings.respawnDelayMinimum = math.min(respawnDelayMinimum, respawnDelayMaximum)
	zombieModeSettings.respawnDelayMaximum = math.max(respawnDelayMinimum, respawnDelayMaximum)
	for _, modeFeatures in pairs(ZOMBIE_MODE_FEATURES) do
		for featureName, enabled in pairs(featureOverrides) do
			modeFeatures[featureName] = enabled
		end
	end
end

local function unitRequiresSpecificPlacement(unitDef)
	if unitDef.extractsMetal and unitDef.extractsMetal > 0 then
		return true
	end
	local customParams = unitDef.customParams
	return customParams and customParams.geothermal and true or false
end

for unitDefID, unitDef in pairs(unitDefs) do
	local captureOverride = unitDef.customParams.scav_swap_override_captured
	if captureOverride == "delete" or unitDefNames[captureOverride] then
		captureSwapOverride[unitDefID] = captureOverride
	end

	local corpseFeatureDef = FeatureDefNames[unitDef.corpse]
	if corpseFeatureDef then
		local corpseDefID = corpseFeatureDef.id
		local unitDefData = { unitDefID = unitDefID }
		local customRespawnTime = tonumber(unitDef.customParams and unitDef.customParams.zombie_respawn_time)
		if customRespawnTime then
			if customRespawnTime < 0 then
				unitDefData.neverRespawn = true
			else
				unitDefData.customRespawnTime = customRespawnTime
			end
		end
		if unitRequiresSpecificPlacement(unitDef) then
			unitDefData.neverRespawn = true
		end
		local isGhostPoolUnit = unitDef.customParams and unitDef.customParams.zombie_ghost_respawn_pool
		if isGhostPoolUnit then
			unitDefData.forceRespawn = true
		end
		zombieUnitDefs[unitDefID] = unitDefData
		if corpseFeatureDef.resurrectable ~= 0 or isGhostPoolUnit then
			zombieCorpseDefs[corpseDefID] = unitDefData
		end

		local zombieDefData = {}
		zombieDefData.corpseDefID = corpseDefID

		local heapDefID = corpseFeatureDef.deathFeatureID
		if heapDefID then
			zombieDefData.heapDefID = heapDefID
			zombieHeapFeatureDefs[heapDefID] = unitDefData
		end

		zombieHeapDefs[unitDefID] = zombieDefData
	end
end

local ghostMistUnitDefID = unitDefNames[GHOST.MIST_UNIT_NAME] and unitDefNames[GHOST.MIST_UNIT_NAME].id

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

local function getUnitRezPower(unitDef)
	return math.max(1, unitDef.power or 1)
end

-- Commanders being available immediately in the beginning of the game can cause T3 to cancerously spawn via substitutes. We decrease the value in the beginning to compensate.
local function getSubstitutionPower(unitDef)
	local unitPower = getUnitRezPower(unitDef)
	if unitDef.customParams and unitDef.customParams.iscommander then
		return unitPower * COMMANDER_SUBSTITUTION_POWER_MULTIPLIER * (currentTechLevel or 1)
	end
	return unitPower
end

local function addToFrameList(frameLists, frame, id)
	local list = frameLists[frame]
	if not list then
		list = {}
		frameLists[frame] = list
	end
	list[#list + 1] = id
end

local function rebuildGhostPoolUnitDefIDs()
	local unitDefIDsByBaseName = {}
	substitutePoolMemberUnitDefIDs = {}
	for unitDefID, unitDef in pairs(unitDefs) do
		if unitDef.customParams and unitDef.customParams.zombie_ghost_respawn_pool then
			substitutePoolMemberUnitDefIDs[unitDefID] = true
			local baseName = string.gsub(unitDef.name, "_scav$", "")
			local existingUnitDefID = unitDefIDsByBaseName[baseName]
			if not existingUnitDefID or unitDef.name == baseName then
				unitDefIDsByBaseName[baseName] = unitDefID
			end
		end
	end

	ghostPoolUnitDefIDs = {}
	for _, unitDefID in pairs(unitDefIDsByBaseName) do
		ghostPoolUnitDefIDs[#ghostPoolUnitDefIDs + 1] = unitDefID
	end
	table.sort(ghostPoolUnitDefIDs, function(firstUnitDefID, secondUnitDefID)
		local firstPower = getUnitRezPower(unitDefs[firstUnitDefID])
		local secondPower = getUnitRezPower(unitDefs[secondUnitDefID])
		if firstPower == secondPower then
			return firstUnitDefID < secondUnitDefID
		end
		return firstPower < secondPower
	end)
end

local function calculateSpawnDelayFrames(unitPower)
	local spawnSeconds = clamp(
		floor(unitPower / adjustedRezPowerSpeed),
		zombieModeSettings.respawnDelayMinimum,
		zombieModeSettings.respawnDelayMaximum
	)
	return floor(spawnSeconds * Game.gameSpeed)
end

local function getRezPowerSpeedForTechLevel(techLevel)
	return TECH_TO_REZ_POWER_SPEEDS[techLevel] or TECH_TO_REZ_POWER_SPEEDS[1]
end

local function rebuildZombieCorpseSpawnDelays()
	for _, unitDefData in pairs(zombieUnitDefs) do
		if unitDefData.neverRespawn then
			unitDefData.spawnDelayFrames = nil
		elseif unitDefData.customRespawnTime then
			unitDefData.spawnDelayFrames = floor(unitDefData.customRespawnTime * Game.gameSpeed)
		else
			local unitDef = unitDefs[unitDefData.unitDefID]
			unitDefData.spawnDelayFrames = calculateSpawnDelayFrames(getUnitRezPower(unitDef))
		end
	end
end

rebuildGhostPoolUnitDefIDs()

local function calculateFactoryBuildpower(baseBuildpower, techLevel)
	return baseBuildpower * FACTORY_BUILDPOWER_TECH_BASE ^ techLevel
end

local function applyZombieFactoryBuildpower(unitID, unitDefID)
	local unitDef = unitDefs[unitDefID]
	if not unitDef or not unitDef.isFactory then
		return
	end

	local techLevel = currentTechLevel or 1
	local buildpower = calculateFactoryBuildpower(unitDef.buildSpeed, techLevel)
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

local function updateAdjustedRezPowerSpeed()
	local techLevel = 1
	if GG.PowerLib and GG.PowerLib.HighestPlayerTeamPower and GG.PowerLib.TechGuesstimate then
		local highestPowerData = GG.PowerLib.HighestPlayerTeamPower()
		techLevel = GG.PowerLib.TechGuesstimate(highestPowerData.power)
	end
	if tooLong then
		adjustedRezPowerSpeed = TOO_LONG_REZ_POWER_SPEED
	else
		adjustedRezPowerSpeed = getRezPowerSpeedForTechLevel(techLevel)
	end
	currentTechLevel = techLevel
end

local function updateRezSpeed()
	updateAdjustedRezPowerSpeed()
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

local function spawnWarningEffects(x, y, z, radius)
	local selectedEffect = WARNING_EFFECTS[random(#WARNING_EFFECTS)] or WARNING_EFFECTS[1]
	if selectedEffect == "scavradiation-lightning" and GG.SpawnEnvironmentalLightning then
		GG.SpawnEnvironmentalLightning("scavradiation", x, y, z)
	else
		spring.SpawnCEG(selectedEffect, x, y, z, 0, 0, 0, radius * 0.25)
	end
	spring.SpawnCEG("scaspawn-trail", x, y, z, 0, 0, 0, radius)
end

local function warningCEG(featureID, x, y, z)
	spawnWarningEffects(x, y, z, spring.GetFeatureRadius(featureID))
end

local function playSpawnSound(x, y, z)
	local selectedSound = SPAWN_SOUNDS[random(#SPAWN_SOUNDS)] or SPAWN_SOUNDS[1]
	spring.PlaySoundFile(selectedSound, 0.5, x, y, z, 0)
end

local function setCorpseRezRulesParam(featureID, spawnFrame)
	spring.SetFeatureRulesParam(featureID, ZOMBIE_REZ_FRAME_PARAM, spawnFrame, PUBLIC_RULES_PARAM_ACCESS)
end

local function clearCorpseRezRulesParam(featureID)
	spring.SetFeatureRulesParam(featureID, ZOMBIE_REZ_FRAME_PARAM, nil, PUBLIC_RULES_PARAM_ACCESS)
end

local function wasZombieCorpse(featureID, corpseData)
	if corpseData and corpseData.wasZombie then
		return true
	end
	local wasZombieParam = spring.GetFeatureRulesParam(featureID, WAS_ZOMBIE_PARAM)
	return wasZombieParam == 1
end

local function armCorpseSpawn(featureID, featureData, spawnFrame)
	featureData.spawnFrame = spawnFrame
	setCorpseRezRulesParam(featureID, spawnFrame)
	addToFrameList(corpseCheckFrames, spawnFrame, featureID)
end

local function resetSpawn(featureID, featureData, featureX, featureZ)
	local newFrame = featureData.tamperedFrame + featureData.spawnDelayFrames
	featureData.creationFrame = featureData.tamperedFrame
	featureData.tamperedFrame = nil -- reclaim/rez progress restarts the spawn timer from this frame
	armCorpseSpawn(featureID, featureData, newFrame)
	spring.SpawnCEG(
		CORPSE_RESET_CEG,
		featureX,
		spring.GetGroundHeight(featureX, featureZ) + CORPSE_RESET_CEG_HEIGHT,
		featureZ,
		0,
		0,
		0
	)
end

local function getScavVariantUnitDefID(unitDefID)
	local unitDef = unitDefs[unitDefID]
	if not unitDef or string.find(unitDef.name, "_scav") then
		return unitDefID
	end

	local scavUnitDefName = unitDef.name .. "_scav"
	local scavUnitDef = unitDefNames[scavUnitDefName]
	return scavUnitDef and scavUnitDef.id or unitDefID
end

local function initializeZombieAI(unitID, unitDefID)
	if GG.ZombieAI then
		GG.ZombieAI.InitializeZombie(unitID, unitDefID)
	end
end

local function rollSpawnCount(keep, rollCount)
	return rollFor(keep, rollCount, zombieModeSettings.spawnCountMinimum, zombieModeSettings.spawnCountMaximum)
end

local function calculateSpawnCount(unitDefID)
	if not currentModeFeatures.multipleSpawns then
		return 1
	end

	local unitDef = unitDefs[unitDefID]
	local rezTimeSeconds = calculateSpawnDelayFrames(getUnitRezPower(unitDef)) / Game.gameSpeed

	if currentTechLevel <= 1 then
		return rollSpawnCount(LOWEST, 3)
	end

	if rezTimeSeconds == zombieModeSettings.respawnDelayMinimum then
		return rollSpawnCount(HIGHEST, 2)
	end
	if rezTimeSeconds == zombieModeSettings.respawnDelayMaximum then
		return rollSpawnCount(LOWEST, 3)
	end
	return rollSpawnCount(LOWEST, 1)
end

local function scheduleZombieTurretExpiration(unitID, unitDefID)
	local unitRole = zombieUnitRoles[unitDefID]
	if not unitRole or not unitRole.isTurret then
		return
	end
	addToFrameList(zombieTurretExpirationFrames, gameFrame + ZOMBIE_TURRET_LIFETIME, unitID)
end

local function getSpawnEffectSizeName(sizeCategory)
	for thresholdIndex = 1, #SPAWN_EFFECT_SIZE_THRESHOLDS do
		local sizeThreshold = SPAWN_EFFECT_SIZE_THRESHOLDS[thresholdIndex]
		if sizeCategory > sizeThreshold.threshold then
			return sizeThreshold.name
		end
	end
	return "tiny"
end

---@return integer spawnedCount
local function spawnZombieUnits(
	unitDefID,
	spawnCount,
	healthReductionRatio,
	spawnX,
	spawnY,
	spawnZ,
	inheritedXp,
	useExactPosition
)
	local unitDef = unitDefs[unitDefID]
	if not unitDef then
		return 0
	end
	local size = unitDef.xsize
	local unitDefToCreate = getScavVariantUnitDefID(unitDefID)
	local sizeCategory = math.ceil((unitDef.xsize / 2 + unitDef.zsize / 2) / 2)
	local sizeName = getSpawnEffectSizeName(sizeCategory)

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

		local unitID = spring.CreateUnit(unitDefToCreate, randomX, adjustedY, randomZ, 0, gaiaTeamID)
		if unitID then
			spring.SpawnCEG("scav-spawnexplo-" .. sizeName, randomX, adjustedY, randomZ, 0, 0, 0)
			local spawnExperience = inheritedXp or 0
			if spawnExperience > 0 then
				spring.SetUnitExperience(unitID, spawnExperience)
			end
			local unitHealth = spring.GetUnitHealth(unitID)
			if unitHealth then
				spring.SetUnitHealth(unitID, unitHealth * healthReductionRatio)
			end
			spring.SetUnitRulesParam(unitID, "zombie", 1)
			applyZombieFactoryBuildpower(unitID, unitDefToCreate)
			if scavTeamID then
				spring.TransferUnit(unitID, scavTeamID)
			else
				initializeZombieAI(unitID, unitDefToCreate)
			end
			scheduleZombieTurretExpiration(unitID, unitDefToCreate)
			spawnedCount = spawnedCount + 1
		else
			break
		end
	end
	return spawnedCount
end

local function pushGhostSpawn(unitDefID)
	local unitValue = getUnitRezPower(unitDefs[unitDefID])
	local insertIndex = #ghostSpawnBuffer + 1
	for bufferIndex = 1, #ghostSpawnBuffer do
		if unitValue > getUnitRezPower(unitDefs[ghostSpawnBuffer[bufferIndex]]) then
			insertIndex = bufferIndex
			break
		end
	end
	table.insert(ghostSpawnBuffer, insertIndex, unitDefID)
end

local function pickSubstituteUnitDefID(totalPower)
	local lowestIndex
	local highestIndex
	local substituteRollCount = SUBSTITUTE_ROLL_COUNT
	if gameFrame >= SUBSTITUTE_FAIR_ROLL_FRAMES then
		substituteRollCount = 1
	end
	for poolIndex = 1, #ghostPoolUnitDefIDs do
		local substitutePower = getUnitRezPower(unitDefs[ghostPoolUnitDefIDs[poolIndex]])
		if substitutePower > totalPower then
			break
		end
		highestIndex = poolIndex
		if not lowestIndex and floor(totalPower / substitutePower) <= zombieModeSettings.spawnCountMaximum then
			lowestIndex = poolIndex
		end
	end
	if not highestIndex then
		return nil
	end
	return ghostPoolUnitDefIDs[rollFor(LOWEST, substituteRollCount, lowestIndex or highestIndex, highestIndex)]
end

local function purchaseSubstitutes(unitPower, spawnCount)
	local borrowedPower = math.min(excessPower, unitPower)
	local totalPower = unitPower * spawnCount + borrowedPower
	excessPower = excessPower - borrowedPower
	local substituteUnitDefID = pickSubstituteUnitDefID(totalPower)
	if not substituteUnitDefID then
		excessPower = excessPower + totalPower
		return nil, 0
	end
	local substitutePower = getUnitRezPower(unitDefs[substituteUnitDefID])
	local purchaseCount = math.min(floor(totalPower / substitutePower), zombieModeSettings.spawnCountMaximum)
	excessPower = excessPower + totalPower - purchaseCount * substitutePower
	return substituteUnitDefID, purchaseCount
end

local function retryFailedSubstitutes(substituteUnitDefID, failedCount)
	if currentModeFeatures.ghostRespawns then
		for _ = 1, failedCount do
			pushGhostSpawn(substituteUnitDefID)
		end
		return
	end
	excessPower = excessPower + failedCount * getUnitRezPower(unitDefs[substituteUnitDefID])
end

local function spawnsAsItself(unitDefID, wasZombie)
	return #ghostPoolUnitDefIDs == 0 or (wasZombie and substitutePoolMemberUnitDefIDs[unitDefID]) or false
end

local function spawnZombies(featureID, unitDefID, healthReductionRatio, x, y, z, wasZombie, inheritedXp)
	local unitDef = unitDefs[unitDefID]
	if not unitDef then
		return
	end
	local spawnCount = 1 -- dead zombies never multiply, so they can't snowball
	if not wasZombie and unitDef.speed > 0 then
		spawnCount = calculateSpawnCount(unitDefID)
	end

	if featureID then
		inheritedXp = spring.GetFeatureRulesParam(featureID, "previous_xp") or 0
		corpsesData[featureID] = nil
		spring.DestroyFeature(featureID)
	end
	if not spawnsAsItself(unitDefID, wasZombie) then
		local substituteUnitDefID, purchaseCount = purchaseSubstitutes(getSubstitutionPower(unitDef), spawnCount)
		if substituteUnitDefID then
			local spawnedCount =
				spawnZombieUnits(substituteUnitDefID, purchaseCount, healthReductionRatio, x, y, z, inheritedXp)
			retryFailedSubstitutes(substituteUnitDefID, purchaseCount - spawnedCount)
		end
		return
	end
	spawnZombieUnits(unitDefID, spawnCount, healthReductionRatio, x, y, z, inheritedXp)
end

local function spawnZombiesFromFeature(featureID, unitDefID, wasZombie)
	local featureX, featureY, featureZ = spring.GetFeaturePosition(featureID)
	if not featureX then
		return false
	end
	spawnZombies(featureID, unitDefID, calculateHealthRatio(featureID), featureX, featureY, featureZ, wasZombie)
	return true
end

local function buildZombieUnitRoles()
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

	local function unitHasSensorRadius(unitDef)
		return (unitDef.radarRadius or 0) > 0
			or (unitDef.jammerRadius or 0) > 0
			or (unitDef.sonarRadius or 0) > 0
			or (unitDef.sonarJamRadius or 0) > 0
	end

	local function isHarmlessEconomyUnit(unitDef)
		local unitGroup = unitDef.customParams and unitDef.customParams.unitgroup
		if unitGroup ~= "metal" and unitGroup ~= "energy" then
			return false
		end
		return not unitDefHasDamagingWeapon(unitDef)
	end

	local function isRadarOrJammerUnit(unitDef)
		local unitGroup = unitDef.customParams and unitDef.customParams.unitgroup
		if unitGroup ~= "util" then
			return false
		end
		return unitHasSensorRadius(unitDef)
	end

	for unitDefID, unitDef in pairs(unitDefs) do
		local isHarmlessEconomy = isHarmlessEconomyUnit(unitDef)
		local isRadarOrJammer = isRadarOrJammerUnit(unitDef)
		local isTurret = unitDef.speed <= 0
			and not unitRequiresSpecificPlacement(unitDef)
			and not isRadarOrJammer
			and not isHarmlessEconomy
			and unitDefHasDamagingWeapon(unitDef)
		zombieUnitRoles[unitDefID] = {
			isTurret = isTurret,
			excludedFromGhostSpawn = isHarmlessEconomy or isRadarOrJammer,
		}
	end
end

buildZombieUnitRoles()

local function canFeedGhostQueue(unitDefID)
	local unitDefData = zombieUnitDefs[unitDefID]
	local unitRole = zombieUnitRoles[unitDefID]
	if not unitDefData or unitDefData.neverRespawn or not unitRole or unitRole.excludedFromGhostSpawn then
		return false
	end
	return true
end

local function resolveGhostRespawn(unitDefID, wasZombie)
	if spawnsAsItself(unitDefID, wasZombie) then
		pushGhostSpawn(unitDefID)
		return
	end
	local unitPower = getSubstitutionPower(unitDefs[unitDefID]) * zombieModeSettings.ghostPowerMultiplier
	local substituteUnitDefID, purchaseCount = purchaseSubstitutes(unitPower, 1)
	for _ = 1, purchaseCount do
		pushGhostSpawn(substituteUnitDefID)
	end
end

local function queueGhostRespawn(unitDefID, wasZombie, respawnFrame)
	if respawnFrame <= gameFrame then
		resolveGhostRespawn(unitDefID, wasZombie)
		return
	end
	addToFrameList(ghostRespawnFrames, respawnFrame, { unitDefID = unitDefID, wasZombie = wasZombie })
end

local function processDueGhostRespawns(frame)
	local respawns = ghostRespawnFrames[frame]
	if not respawns then
		return
	end
	ghostRespawnFrames[frame] = nil
	for respawnIndex = 1, #respawns do
		local respawn = respawns[respawnIndex]
		resolveGhostRespawn(respawn.unitDefID, respawn.wasZombie)
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
		if gameFrame - creationFrame >= GHOST.MINIMUM_LIFE then
			if
				not oldestCreationFrame
				or creationFrame < oldestCreationFrame
				or (creationFrame == oldestCreationFrame and unitID < oldestUnitID)
			then
				oldestUnitID = unitID
				oldestCreationFrame = creationFrame
			end
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
	if not autoSpawningEnabled or not currentModeFeatures.ghostRespawns or not canFeedGhostQueue(unitDefID) then
		return
	end
	if random() < zombieModeSettings.ghostFeedSuccessChance then
		local spawnDelayFrames = (zombieUnitDefs[unitDefID].spawnDelayFrames or 0) * GHOST.RESPAWN_DELAY_MULTIPLIER
		queueGhostRespawn(unitDefID, wasZombie, gameFrame + spawnDelayFrames)
	end
	createGhost(spawnX, spawnZ)
end

local function expireZombieTurret(unitID)
	if not spring.ValidUnitID(unitID) then
		return
	end
	local unitDefID = spring.GetUnitDefID(unitID)
	local unitRole = unitDefID and zombieUnitRoles[unitDefID]
	if not unitDefID or not isZombie(unitID) or not unitRole or not unitRole.isTurret then
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

local function canSpawnUnitAt(unitDefID, spawnX, spawnY, spawnZ)
	local unitDef = unitDefs[unitDefID]
	if not unitDef then
		return false
	end
	if unitDef.speed > 0 then
		return spring.TestMoveOrder(unitDefID, spawnX, spawnY, spawnZ) and true or false
	end
	return spring.TestBuildOrder(unitDefID, spawnX, spawnY, spawnZ, 0) > 0
end

local function isTeamAtUnitCap(teamID)
	local maxUnits, currentUnits = spring.GetTeamMaxUnits(teamID)
	return maxUnits ~= nil and currentUnits ~= nil and currentUnits >= maxUnits
end

local function attemptGhostBufferSpawn(unitDefID, readyGhosts)
	local unitDefToCreate = getScavVariantUnitDefID(unitDefID)
	local size = unitDefs[unitDefToCreate].xsize
	for ghostIndex = 1, #readyGhosts do
		local readyGhost = readyGhosts[ghostIndex]
		for _ = 1, GHOST.SPAWN_ATTEMPT_COUNT do
			local spawnX, spawnY, spawnZ = getGhostSpawnAttemptPosition(readyGhost.x, readyGhost.z, size)
			if canSpawnUnitAt(unitDefToCreate, spawnX, spawnY, spawnZ) then
				if spawnZombieUnits(unitDefID, 1, 1, spawnX, spawnY, spawnZ, 0, true) > 0 then
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
	spring.SpawnCEG("scavradiation-lightning", ghostX, lightningY, ghostZ, 0, 0, 0)
	spring.SpawnCEG("scaspawn-trail", ghostX, ghostY, ghostZ, 0, 0, 0, 32)
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

---Turns a unit into a zombie, swapping it for its `_scav` variant where one exists.
---@param unitID UnitID
local function setZombie(unitID)
	local unitDefID = spring.GetUnitDefID(unitID)
	if not unitDefID then
		return
	end

	local scavUnitDefID = getScavVariantUnitDefID(unitDefID)

	-- If we need to convert to _scav variant
	local unitX, unitY, unitZ = spring.GetUnitPosition(unitID)
	local teamID = spring.GetUnitTeam(unitID)
	if scavUnitDefID ~= unitDefID and unitX and teamID then
		local facing = spring.GetUnitBuildFacing(unitID) or 0
		local newUnitID = spring.CreateUnit(scavUnitDefID, unitX, unitY, unitZ, facing, teamID)
		if newUnitID then
			local health, maxHealth = spring.GetUnitHealth(unitID)
			local _, newMaxHealth = spring.GetUnitHealth(newUnitID)
			if health and maxHealth > 0 then
				spring.SetUnitHealth(newUnitID, health / maxHealth * newMaxHealth)
			end
			local experience = spring.GetUnitExperience(unitID)
			spring.SetUnitExperience(newUnitID, experience)

			suppressedDeaths[unitID] = true
			spring.DestroyUnit(unitID, false, true)

			unitID = newUnitID
			unitDefID = scavUnitDefID
		end
	end

	spring.SetUnitRulesParam(unitID, "zombie", 1)
	applyZombieFactoryBuildpower(unitID, unitDefID)
	initializeZombieAI(unitID, unitDefID)
	scheduleZombieTurretExpiration(unitID, unitDefID)
end

function gadget:FeatureBuildStepPost(featureID)
	local featureData = corpsesData[featureID]
	if featureData and featureData.zombieStepFrame ~= gameFrame then
		if not featureData.tamperedFrame then
			local remainingFrames = featureData.spawnFrame - gameFrame
			if remainingFrames < featureData.spawnDelayFrames - TIMER_NEAR_MAX_THRESHOLD then
				local featureX, featureY, featureZ = spring.GetFeaturePosition(featureID)
				if featureX and featureY then
					spring.SpawnCEG("scaspawn-trail", featureX, featureY + 15, featureZ, 0, 0, 0)
				end
			end
		end
		featureData.tamperedFrame = gameFrame
	end
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
	local featureX, featureY, featureZ = spring.GetFeaturePosition(featureID)
	if not featureX then
		return true
	end
	rezzedCorpses[featureID] = true
	spawnZombies(
		featureID,
		corpseDefData.unitDefID,
		calculateHealthRatio(featureID),
		featureX,
		featureY,
		featureZ,
		wasZombieCorpse(featureID, corpseData),
		corpseData and corpseData.pastXp
	)
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
	if not currentModeFeatures.alwaysCorpses or inFluid or CORPSE_GUARANTEE_EXCLUDED_DEATHS[weaponDefID] then
		return false
	end
	local unitDefData = zombieUnitDefs[unitDefID]
	if not unitDefData or unitDefData.neverRespawn or not zombieCorpseDefs[zombieHeapDefs[unitDefID].corpseDefID] then
		return false
	end
	local _, _, _, _, buildProgress = spring.GetUnitHealth(unitID)
	return buildProgress == nil or buildProgress >= 1
end

local function recordPendingDeath(unitID, unitDefID, unitTeam, attackerID, weaponDefID)
	if not zombieHeapDefs[unitDefID] then
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
	for paramIndex = 1, #PREVIOUS_STATE_PARAMS do
		local paramName = PREVIOUS_STATE_PARAMS[paramIndex]
		previousStates[paramName] = spring.GetFeatureRulesParam(featureID, paramName)
	end
	return previousStates
end

local function applyPreviousStates(featureID, previousStates)
	if not previousStates then
		return
	end
	for paramIndex = 1, #PREVIOUS_STATE_PARAMS do
		local paramName = PREVIOUS_STATE_PARAMS[paramIndex]
		local paramValue = previousStates[paramName]
		if paramValue then
			spring.SetFeatureRulesParam(featureID, paramName, paramValue)
		end
	end
end

local function createDeathCorpse(deathData, featureX, featureY, featureZ, heading, teamID)
	replacementDeathData = deathData
	local featureID = spring.CreateFeature(
		zombieHeapDefs[deathData.unitDefID].corpseDefID,
		featureX,
		featureY,
		featureZ,
		heading,
		teamID
	)
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

local function expireCorpseHeapFeeds(frame)
	if #pendingCorpseHeapFeeds == 0 then
		return
	end
	local remainingFeeds = {}
	for _, feed in ipairs(pendingCorpseHeapFeeds) do
		if frame - feed.frame <= 1 then
			remainingFeeds[#remainingFeeds + 1] = feed
		end
	end
	pendingCorpseHeapFeeds = remainingFeeds
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
		resetSpawn(featureID, corpseData, featureX, featureZ)
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

function gadget:GameFrame(frame)
	gameFrame = frame

	expireCorpseHeapFeeds(frame)
	processWreckSwaps()
	resolveVanishedDeaths()
	expireDueZombieTurrets(frame)
	if currentModeFeatures.ghostRespawns then
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
		for resourceIndex = 1, #GAIA_RESOURCES do
			spring.AddTeamResource(gaiaTeamID, GAIA_RESOURCES[resourceIndex].resourceName, GAIA_RESOURCE_AMOUNT)
		end
		for featureID, featureData in pairs(corpsesData) do
			if featureData.spawnFrame - frame < WARNING_TIME then
				local featureX, featureY, featureZ = spring.GetFeaturePosition(featureID)
				if not featureX then --doesn't exist anymore
					corpsesData[featureID] = nil
				elseif not featureData.tamperedFrame then
					warningCEG(featureID, featureX, featureY, featureZ)
				end
			end
		end
	end
end

local function isCorpseResurrectable(featureID)
	local resurrectUnitName = spring.GetFeatureResurrect(featureID)
	return resurrectUnitName ~= nil and resurrectUnitName ~= ""
end

local function corpseCanRespawn(featureID, corpseDefData)
	if not corpseDefData or corpseDefData.neverRespawn then
		return false
	end
	if corpseDefData.forceRespawn or isCorpseResurrectable(featureID) then
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

	local existingRezFrame = spring.GetFeatureRulesParam(featureID, ZOMBIE_REZ_FRAME_PARAM)
	existingRezFrame = tonumber(existingRezFrame)
	local spawnDelayFrames = corpseDefData.spawnDelayFrames
	local spawnFrame = gameFrame + (spawnDelayFrames or 0)
	if existingRezFrame and existingRezFrame > 0 then
		spawnFrame = floor(existingRezFrame)
	end
	if spawnFrame <= gameFrame then
		spawnZombiesFromFeature(featureID, corpseDefData.unitDefID, wasZombie)
		return
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

local function consumeCorpseHeapFeed(featureX, featureZ)
	local closestFeedIndex
	local closestDistanceSquared
	local matchDistanceSquared = CORPSE_HEAP_MATCH_DISTANCE * CORPSE_HEAP_MATCH_DISTANCE
	for feedIndex, feed in ipairs(pendingCorpseHeapFeeds) do
		if gameFrame - feed.frame <= 1 then
			local differenceX = featureX - feed.x
			local differenceZ = featureZ - feed.z
			local distanceSquared = differenceX * differenceX + differenceZ * differenceZ
			if distanceSquared <= matchDistanceSquared then
				if not closestDistanceSquared or distanceSquared < closestDistanceSquared then
					closestFeedIndex = feedIndex
					closestDistanceSquared = distanceSquared
				end
			end
		end
	end
	if not closestFeedIndex then
		return false
	end
	table.remove(pendingCorpseHeapFeeds, closestFeedIndex)
	return true
end

local function getWreckSwap(featureID, featureDefID, deathData)
	local heapDefData = zombieHeapDefs[deathData.unitDefID]
	if not heapDefData then
		return nil
	end
	if featureDefID == heapDefData.corpseDefID and deathData.demoteCorpse then
		return { featureID = featureID, deathData = deathData, demote = true }
	end
	if featureDefID == heapDefData.heapDefID and deathData.guaranteeCorpse then
		return { featureID = featureID, deathData = deathData, demote = false }
	end
	return nil
end

local function handleFeatureCreated(featureID, sourceID)
	local featureDefID = spring.GetFeatureDefID(featureID)
	local deathData = replacementDeathData
	if deathData then
		applyPreviousStates(featureID, deathData.previousStates)
		if featureDefID == zombieHeapDefs[deathData.unitDefID].corpseDefID then
			local featureFacing = spring.GetFacingFromHeading(spring.GetFeatureHeading(featureID) or 0)
			spring.SetFeatureResurrect(featureID, deathData.unitDefID, featureFacing)
		end
	elseif sourceID and pendingDeaths[sourceID] then
		deathData = pendingDeaths[sourceID]
		pendingDeaths[sourceID] = nil
		local wreckSwap = getWreckSwap(featureID, featureDefID, deathData)
		if wreckSwap then
			pendingWreckSwaps[#pendingWreckSwaps + 1] = wreckSwap
			return
		end
	end

	local wasZombie = deathData and deathData.wasZombie
	if wasZombie then
		spring.SetFeatureRulesParam(featureID, WAS_ZOMBIE_PARAM, 1, PUBLIC_RULES_PARAM_ACCESS)
	end
	if zombieCorpseDefs[featureDefID] then
		queueCorpseForSpawning(featureID, false, wasZombie)
		return
	end

	local featureX, _, featureZ = spring.GetFeaturePosition(featureID)
	if not featureX then
		return
	end
	if deathData then
		if not deathData.forcedHeap then
			feedGhostQueue(deathData.unitDefID, featureX, featureZ, deathData.wasZombie)
		end
		return
	end
	local heapUnitDefData = zombieHeapFeatureDefs[featureDefID]
	if not heapUnitDefData or consumeCorpseHeapFeed(featureX, featureZ) then
		return
	end
	feedGhostQueue(heapUnitDefData.unitDefID, featureX, featureZ)
end

function gadget:FeatureCreated(featureID, _, sourceID)
	handleFeatureCreated(featureID, sourceID)
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
			pendingCorpseHeapFeeds[#pendingCorpseHeapFeeds + 1] = {
				unitDefID = corpseDefData.unitDefID,
				x = featureX,
				z = featureZ,
				frame = gameFrame,
			}
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
	if pendingZombieCaptures[unitID] then
		pendingZombieCaptures[unitID] = nil
		if not isZombie(unitID) then
			local unitX, unitY, unitZ = spring.GetUnitPosition(unitID)
			local health, maxHealth = spring.GetUnitHealth(unitID)
			local inheritedXp = spring.GetUnitExperience(unitID) or 0
			local healthReductionRatio = 1.0
			if health and maxHealth and maxHealth ~= 0 then
				healthReductionRatio = health / maxHealth
			end
			suppressedDeaths[unitID] = true
			spring.DestroyUnit(unitID, false, true)
			local spawnDefID = unitDefID
			local swapOverride = captureSwapOverride[unitDefID]
			if swapOverride then
				spawnDefID = swapOverride ~= "delete" and unitDefNames[swapOverride].id or nil
			end
			if unitX and spawnDefID then
				spawnZombies(nil, spawnDefID, healthReductionRatio, unitX, unitY, unitZ, false, inheritedXp)
			end
		end
	end
end

---Immediately raises zombies from a corpse feature. Only acts while in idle mode.
---@param featureID FeatureID
---@return boolean spawned `false` when not in idle mode, or the feature is not a zombie corpse.
local function createZombieFromFeature(featureID)
	if isIdleMode then
		local featureDefID = spring.GetFeatureDefID(featureID)
		local featureDefData = featureDefID and zombieCorpseDefs[featureDefID]
		if featureDefData and corpseCanRespawn(featureID, featureDefData) then
			local corpseData = corpsesData[featureID]
			local wasZombie = wasZombieCorpse(featureID, corpseData)
			if spawnZombiesFromFeature(featureID, featureDefData.unitDefID, wasZombie) then
				return true
			end
		end
	end
	return false
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
	pendingCorpseHeapFeeds = {}
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
	applyZombieModeSettings(resolveZombieMode(modeName))
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

local function runZombieChatAction(action, words, playerID)
	if not isAuthorized(playerID) then
		spring.SendMessageToPlayer(playerID, UNAUTHORIZED_TEXT)
		return
	end
	action(words, playerID)
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
			handleFeatureCreated(featureID)
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
			if not GG.ZombieAI then
				return forwardedMethod.missingResult
			end
			return callZombieAI(methodName, ...)
		end
	end

	for _, chatAction in ipairs(ZOMBIE_CHAT_ACTIONS) do
		gadgetHandler:AddChatAction(chatAction.name, function(_, _, words, playerID)
			runZombieChatAction(chatAction.run, words, playerID)
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
