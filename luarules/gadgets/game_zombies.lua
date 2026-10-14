-- [Scavenger Zombies] Zombies do not capture units that are still being built.
-- [Scavenger Zombies] After 60 minutes, zombies stay permanently aggro'd and respawn at a fixed speed of 20 instead of scaling with the tech estimate.
-- [Scavenger Zombies] Zombie factories build at their original buildpower * 1.7 ^ the current tech estimate.
-- [Scavenger Zombies] Modes are Basic, Oni, Yokai, Nani?!, Akumu, and Spidergeddon, all sharing one revival speed table and a 45 to 120 second revival window. Oni adds bonus XP and corpses on every death, Yokai adds ghostly apparitions, Nani?! adds multiple spawns, and Akumu and Spidergeddon combine all three. Spidergeddon apparitions respawn units as spider-like units.
-- [Scavenger Zombies] Nani?!, Akumu, and Spidergeddon spawn 2 to 6 zombies per corpse. At tech 1 or below, the count is the lowest of 3 rolls. Above tech 1, units that revive at the fastest allowed time take the highest of 2 rolls, units that revive at the slowest allowed time take the lowest of 3 rolls, and units in between roll once. Other modes always spawn 1. Corpses that were already zombies, and units that cannot move, always spawn 1. Dead zombies die normally and their corpse is swapped for a heap outside Oni, Akumu, and Spidergeddon, so they rise only once. In those modes, every death leaves a corpse regardless of overkill, except reclaims, Lua removals, cancelled or decaying builds, and water or lava deaths. Water and lava zombie deaths never leave a corpse, and apparitions are fed by overkilled units and by corpses destroyed by anything other than reclaim or resurrection.
-- [Scavenger Zombies] In Yokai, Akumu, and Spidergeddon, each death that feeds the apparitions has a 66% chance to enter the apparition respawn queue or add its value to a Spidergeddon spider bucket. On a failed roll the unit is dropped, though an apparition still appears at the death location. Dead zombies whose corpse is forced into a heap were not overkilled, so they never feed the apparitions. Zombies that are overkilled into a heap or nothing still take the 66% roll.
-- [Scavenger Zombies] Todo: Should zombies be infinitely recycled? Or should they have a chance to exit tyhe respawn queue?

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

-- To customize zombie respawn time, use customParams.zombie_respawn_time (seconds):
--   < 0  never respawn as a zombie
--   0    respawn instantly
--   > 0  custom respawn delay in seconds
-- this overrides default timing based on unit power, difficulty, and gamestate.

if not gadgetHandler:IsSyncedCode() then
	return false
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
local BONUS_EXPERIENCE_MIN = 0.25
local BONUS_EXPERIENCE_MAX = 1.5
local SPAWN_COUNT_MIN = 2
local SPAWN_COUNT_MAX = 6
local REZ_MIN_SECONDS = 45
local REZ_MAX_SECONDS = 120
local GHOST_SAFE_TIME = Game.gameSpeed * 20
local GHOST_MINIMUM_LIFE = Game.gameSpeed * 30
local GHOST_EXPIRATION_TIME = Game.gameSpeed * 120
local GHOST_MAP_MARGIN = 16
local GHOST_SPAWN_ATTEMPT_COUNT = 3
local GHOST_SPAWN_OFFSET_DISTANCE = 50
local GHOST_SPAWN_CHECK_INTERVAL = Game.gameSpeed * 5
local GHOST_RANDOM_SPAWN_INTERVAL = Game.gameSpeed * 60 * 15
local ZOMBIE_TURRET_LIFETIME = Game.gameSpeed * 60 * 10
local MAX_GHOSTS = 25
local MAX_GHOST_SPAWN_BUFFER = 100
local GHOST_FEED_SUCCESS_CHANCE = 0.66
local GHOST_MIST_UNIT_NAME = "scavapparition"

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
	oni = { bonusExperience = true, alwaysCorpses = true },
	yokai = { ghostRespawns = true },
	nani = { multipleSpawns = true },
	akumu = { bonusExperience = true, alwaysCorpses = true, ghostRespawns = true, multipleSpawns = true },
	spidergeddon = { bonusExperience = true, alwaysCorpses = true, ghostRespawns = true, multipleSpawns = true },
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
local CORPSE_GUARANTEE_EXCLUDED_DEATHS = {}
for _, deathName in ipairs({
	"Reclaimed",
	"KilledByLua",
	"TurnedIntoFeature",
	"FactoryCancel",
	"ConstructionDecay",
	"OutOfBounds",
	"KilledByCheat",
}) do
	local damageTypeID = Game.envDamageTypes[deathName]
	if damageTypeID then
		CORPSE_GUARANTEE_EXCLUDED_DEATHS[damageTypeID] = true
	end
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
local ceil = math.ceil
local cos = math.cos
local sin = math.sin
local pi = math.pi

local scavTeamID
local gaiaTeamID = spring.GetGaiaTeamID()
for _, teamID in ipairs(spring.GetTeamList()) do
	local teamLuaAI = spring.GetTeamLuaAI(teamID)
	if teamLuaAI and string.find(teamLuaAI, "ScavengersAI") then
		scavTeamID = teamID
	end
end

local gameFrame = 0
local tooLong = false
local adjustedRezPowerSpeed = TECH_TO_REZ_POWER_SPEEDS[1]
local currentTechLevel = nil
local autoSpawningEnabled = true

local zombiesBeingBuilt = {}
local rezzedCorpses = {}
local zombieCorpseDefs = {}
local corpseCheckFrames = {}
local corpsesData = {}
local pendingDeaths = {}
local pendingWreckSwaps = {}
local replacementDeathData = nil
local pendingZombieCaptures = {}
local suppressedDeaths = {}
local zombieHeapDefs = {}
local zombieHeapFeatureDefs = {}
local zombieUnitDefs = {}
local zombieUnitRoles = {}
local zombieFactories = {}
local ghostPoolUnitDefIDs = {}
local spiderPowerByUnitDefID = {}
local spiderPowerAddFrames = {}
local sameUnitSpawnFrames = {}
local pendingCorpseHeapFeeds = {}
local ghostSpawnBuffer = {}
local zombieTurretExpirationFrames = {}
local ghosts = {}
local ghostCount = 0
local captureSwapOverride = {}
local unitDefs = UnitDefs
local unitDefNames = UnitDefNames
local featureDefNames = FeatureDefNames
local featureDefs = FeatureDefs

local warningEffects = {
	"scavmist",
	"scavradiation-lightning",
}
local spawnEffects = {
	"xploelc2",
	"xploelc3",
}

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

	local corpseDefName = unitDef.corpse
	if featureDefNames[corpseDefName] then
		local corpseDefID = featureDefNames[corpseDefName].id
		local corpseFeatureDef = featureDefs[corpseDefID]
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

local ghostMistUnitDefID = unitDefNames[GHOST_MIST_UNIT_NAME] and unitDefNames[GHOST_MIST_UNIT_NAME].id

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
	for unitDefID, unitDef in pairs(unitDefs) do
		if unitDef.customParams and unitDef.customParams.zombie_ghost_respawn_pool then
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
		return firstPower > secondPower
	end)
end

local function calculateSpawnDelayFrames(unitPower)
	local spawnSeconds = floor(unitPower / adjustedRezPowerSpeed)
	spawnSeconds = clamp(spawnSeconds, REZ_MIN_SECONDS, REZ_MAX_SECONDS)
	return spawnSeconds * Game.gameSpeed
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
	zombieFactories[unitID] = unitDefID
end

local function revertZombieFactoryBuildpower(unitID, unitDefID)
	local unitDef = unitDefs[unitDefID]
	if unitDef then
		spring.SetUnitBuildSpeed(unitID, unitDef.buildSpeed)
	end
	zombieFactories[unitID] = nil
end

local function refreshZombieFactoryBuildpower()
	for unitID, unitDefID in pairs(zombieFactories) do
		if not spring.ValidUnitID(unitID) then
			zombieFactories[unitID] = nil
		elseif spring.GetUnitTeam(unitID) ~= gaiaTeamID then
			revertZombieFactoryBuildpower(unitID, unitDefID)
		else
			applyZombieFactoryBuildpower(unitID, unitDefID)
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
	local selectedEffect = warningEffects[random(#warningEffects)]
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
	local selectedEffect = spawnEffects[random(#spawnEffects)]
	spring.PlaySoundFile(selectedEffect, 0.5, x, y, z, 0)
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
	if string.find(unitDef.name, "_scav") then
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

local function rollSpawnCount()
	return random(SPAWN_COUNT_MIN, SPAWN_COUNT_MAX)
end

local function calculateSpawnCount(unitDefID)
	if not currentModeFeatures.multipleSpawns then
		return 1
	end

	local unitDef = unitDefs[unitDefID]
	local rezTimeSeconds = calculateSpawnDelayFrames(getUnitRezPower(unitDef)) / Game.gameSpeed

	if currentTechLevel <= 1 then
		return math.min(rollSpawnCount(), rollSpawnCount(), rollSpawnCount())
	end

	if rezTimeSeconds == REZ_MIN_SECONDS then
		return math.max(rollSpawnCount(), rollSpawnCount())
	end
	if rezTimeSeconds == REZ_MAX_SECONDS then
		return math.min(rollSpawnCount(), rollSpawnCount(), rollSpawnCount())
	end
	return rollSpawnCount()
end

local function rollBonusExperience()
	local lowestRoll = math.min(random() * BONUS_EXPERIENCE_MAX, random() * BONUS_EXPERIENCE_MAX, random() * BONUS_EXPERIENCE_MAX)
	return math.max(BONUS_EXPERIENCE_MIN, lowestRoll)
end

local function calculateSpawnExperience(inheritedXp)
	local experience = inheritedXp or 0
	if currentModeFeatures.bonusExperience then
		experience = math.max(experience, rollBonusExperience())
	end
	return experience
end

local scheduleZombieTurretExpiration
local feedGhostQueue

local function getSpawnEffectSizeName(sizeCategory)
	for thresholdIndex = 1, #SPAWN_EFFECT_SIZE_THRESHOLDS do
		local sizeThreshold = SPAWN_EFFECT_SIZE_THRESHOLDS[thresholdIndex]
		if sizeCategory > sizeThreshold.threshold then
			return sizeThreshold.name
		end
	end
	return "tiny"
end

local function spawnZombieUnits(unitDefID, spawnCount, healthReductionRatio, spawnX, spawnY, spawnZ, inheritedXp, useExactPosition)
	local unitDef = unitDefs[unitDefID]
	local size = unitDef.xsize
	local unitDefToCreate = getScavVariantUnitDefID(unitDefID)
	local sizeCategory = ceil((unitDef.xsize / 2 + unitDef.zsize / 2) / 2)
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
			local spawnExperience = calculateSpawnExperience(inheritedXp)
			if spawnExperience > 0 then
				spring.SetUnitExperience(unitID, spawnExperience)
			end
			local unitHealth = spring.GetUnitHealth(unitID)
			spring.SetUnitHealth(unitID, unitHealth * healthReductionRatio)
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

local function spawnZombies(featureID, unitDefID, healthReductionRatio, x, y, z, wasZombie, inheritedXp)
	local unitDef = unitDefs[unitDefID]
	local spawnCount = 1 -- dead zombies never multiply, so they can't snowball
	if not wasZombie and unitDef.speed > 0 then
		spawnCount = calculateSpawnCount(unitDefID)
	end

	if featureID then
		inheritedXp = spring.GetFeatureRulesParam(featureID, "previous_xp") or 0
		corpsesData[featureID] = nil
		spring.DestroyFeature(featureID)
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
	if #ghostSpawnBuffer > MAX_GHOST_SPAWN_BUFFER then
		ghostSpawnBuffer[#ghostSpawnBuffer] = nil
	end
end

local function applySpiderPowerCredit(spiderUnitDefID, power)
	local bankedPower = (spiderPowerByUnitDefID[spiderUnitDefID] or 0) + power
	local spiderPower = getUnitRezPower(unitDefs[spiderUnitDefID])
	while bankedPower >= spiderPower do
		pushGhostSpawn(spiderUnitDefID)
		bankedPower = bankedPower - spiderPower
	end
	spiderPowerByUnitDefID[spiderUnitDefID] = bankedPower
end

local function getAffordableSpiderSpawnCount(spiderUnitDefID, power)
	local bankedPower = (spiderPowerByUnitDefID[spiderUnitDefID] or 0) + power
	local spiderPower = getUnitRezPower(unitDefs[spiderUnitDefID])
	return floor(bankedPower / spiderPower)
end

local function pickSpiderUnitDefID(power)
	local firstIndex = random(1, #ghostPoolUnitDefIDs)
	local firstUnitDefID = ghostPoolUnitDefIDs[firstIndex]
	if getAffordableSpiderSpawnCount(firstUnitDefID, power) <= SPAWN_COUNT_MAX then
		return firstUnitDefID
	end
	if #ghostPoolUnitDefIDs == 1 then
		return firstUnitDefID
	end
	local secondIndex = random(1, #ghostPoolUnitDefIDs - 1)
	if secondIndex >= firstIndex then
		secondIndex = secondIndex + 1
	end
	return ghostPoolUnitDefIDs[secondIndex]
end

scheduleZombieTurretExpiration = function(unitID, unitDefID)
	local unitRole = zombieUnitRoles[unitDefID]
	if not unitRole or not unitRole.isTurret then
		return
	end
	addToFrameList(zombieTurretExpirationFrames, gameFrame + ZOMBIE_TURRET_LIFETIME, unitID)
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
		feedGhostQueue(unitDefID, unitX, unitZ)
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

local function queueSpiderPowerCredit(dyingUnitDefID, powerCreditFrame)
	if #ghostPoolUnitDefIDs == 0 then
		if powerCreditFrame <= gameFrame then
			pushGhostSpawn(dyingUnitDefID)
			return
		end
		addToFrameList(sameUnitSpawnFrames, powerCreditFrame, dyingUnitDefID)
		return
	end
	local power = getUnitRezPower(unitDefs[dyingUnitDefID])
	local spiderUnitDefID = pickSpiderUnitDefID(power)
	if powerCreditFrame <= gameFrame then
		applySpiderPowerCredit(spiderUnitDefID, power)
		return
	end
	addToFrameList(spiderPowerAddFrames, powerCreditFrame, {
		spiderUnitDefID = spiderUnitDefID,
		power = power,
	})
end

local function processDueSameUnitSpawns(frame)
	local unitDefIDs = sameUnitSpawnFrames[frame]
	if not unitDefIDs then
		return
	end
	for unitIndex = 1, #unitDefIDs do
		pushGhostSpawn(unitDefIDs[unitIndex])
	end
	sameUnitSpawnFrames[frame] = nil
end

local function processDueSpiderPowerCredits(frame)
	local credits = spiderPowerAddFrames[frame]
	if not credits then
		return
	end
	for creditIndex = 1, #credits do
		local credit = credits[creditIndex]
		applySpiderPowerCredit(credit.spiderUnitDefID, credit.power)
	end
	spiderPowerAddFrames[frame] = nil
end

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
		if gameFrame - creationFrame >= GHOST_MINIMUM_LIFE then
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
	if not ghostMistUnitDefID then
		return nil
	end

	local replacedGhostID
	if ghostCount >= MAX_GHOSTS then
		replacedGhostID = getOldestReplaceableGhostID()
		if not replacedGhostID then
			return nil
		end
	end

	local ghostX = clamp(spawnX, GHOST_MAP_MARGIN, Game.mapSizeX - GHOST_MAP_MARGIN)
	local ghostZ = clamp(spawnZ, GHOST_MAP_MARGIN, Game.mapSizeZ - GHOST_MAP_MARGIN)
	local unitID = spring.CreateUnit(ghostMistUnitDefID, ghostX, spring.GetGroundHeight(ghostX, ghostZ), ghostZ, 0, gaiaTeamID)
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
		readyFrame = gameFrame + GHOST_SAFE_TIME,
		expirationFrame = gameFrame + GHOST_EXPIRATION_TIME,
	}
	ghostCount = ghostCount + 1
	return unitID
end

local function spawnRandomMapGhost()
	if not autoSpawningEnabled or not currentModeFeatures.ghostRespawns then
		return
	end

	local minimumX = GHOST_MAP_MARGIN
	local maximumX = floor(Game.mapSizeX - GHOST_MAP_MARGIN)
	local minimumZ = GHOST_MAP_MARGIN
	local maximumZ = floor(Game.mapSizeZ - GHOST_MAP_MARGIN)
	if maximumX < minimumX or maximumZ < minimumZ then
		return
	end

	for attemptIndex = 1, GHOST_SPAWN_ATTEMPT_COUNT do
		local spawnX = random(minimumX, maximumX)
		local spawnZ = random(minimumZ, maximumZ)
		if createGhost(spawnX, spawnZ) then
			return
		end
	end
end

feedGhostQueue = function(unitDefID, spawnX, spawnZ)
	if not autoSpawningEnabled or not currentModeFeatures.ghostRespawns or not canFeedGhostQueue(unitDefID) then
		return
	end
	if random() < GHOST_FEED_SUCCESS_CHANCE then
		local spawnDelayFrames = zombieUnitDefs[unitDefID].spawnDelayFrames or 0
		queueSpiderPowerCredit(unitDefID, gameFrame + spawnDelayFrames)
	end
	createGhost(spawnX, spawnZ)
end

local function collectReadyGhostIDs()
	local readyGhostIDs = {}
	for unitID, ghostData in pairs(ghosts) do
		if gameFrame >= ghostData.readyFrame then
			readyGhostIDs[#readyGhostIDs + 1] = unitID
		end
	end
	return readyGhostIDs
end

local function getGhostSpawnAttemptPosition(originX, originZ, size)
	local angle = random() * 2 * pi
	local distance = random() * GHOST_SPAWN_OFFSET_DISTANCE
	local spawnX = clamp(originX + cos(angle) * distance, size, Game.mapSizeX - size)
	local spawnZ = clamp(originZ + sin(angle) * distance, size, Game.mapSizeZ - size)
	local spawnY = spring.GetGroundHeight(spawnX, spawnZ)
	return spawnX, spawnY, spawnZ
end

local function canSpawnUnitAt(unitDefID, spawnX, spawnY, spawnZ)
	local unitDef = unitDefs[unitDefID]
	if unitDef.speed > 0 then
		return spring.TestMoveOrder(unitDefID, spawnX, spawnY, spawnZ) and true or false
	end
	return spring.TestBuildOrder(unitDefID, spawnX, spawnY, spawnZ, 0) > 0
end

local function isTeamAtUnitCap(teamID)
	local maxUnits, currentUnits = spring.GetTeamMaxUnits(teamID)
	return maxUnits ~= nil and currentUnits ~= nil and currentUnits >= maxUnits
end

local function attemptGhostBufferSpawn(unitDefID, readyGhostIDs)
	local unitDefToCreate = getScavVariantUnitDefID(unitDefID)
	local size = unitDefs[unitDefToCreate].xsize
	for ghostIndex = 1, #readyGhostIDs do
		local ghostID = readyGhostIDs[ghostIndex]
		local ghostX, _, ghostZ = spring.GetUnitPosition(ghostID)
		if not ghostX then
			forgetGhost(ghostID)
		else
			for attemptIndex = 1, GHOST_SPAWN_ATTEMPT_COUNT do
				local spawnX, spawnY, spawnZ = getGhostSpawnAttemptPosition(ghostX, ghostZ, size)
				if canSpawnUnitAt(unitDefToCreate, spawnX, spawnY, spawnZ) then
					if spawnZombieUnits(unitDefID, 1, 1, spawnX, spawnY, spawnZ, 0, true) > 0 then
						return "spawned"
					end
					return "failed"
				end
			end
		end
	end
	return "unspawned"
end

local function spawnBufferedGhostUnits()

	local remainingSpawns = {}
	local bufferIndex = 1
	while bufferIndex <= #ghostSpawnBuffer do
		if isTeamAtUnitCap(gaiaTeamID) then
			break
		end
		local readyGhostIDs = collectReadyGhostIDs()
		if #readyGhostIDs == 0 then
			break
		end
		for ghostIndex = #readyGhostIDs, 2, -1 do
			local swapIndex = random(1, ghostIndex)
			readyGhostIDs[ghostIndex], readyGhostIDs[swapIndex] = readyGhostIDs[swapIndex], readyGhostIDs[ghostIndex]
		end

		local unitDefID = ghostSpawnBuffer[bufferIndex]
		local spawnResult = attemptGhostBufferSpawn(unitDefID, readyGhostIDs)
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
	for _, unitDefIDs in pairs(sameUnitSpawnFrames) do
		if #unitDefIDs > 0 then
			return true
		end
	end
	for _, credits in pairs(spiderPowerAddFrames) do
		if #credits > 0 then
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
				local enemyNearby = GG.ZombieAI
					and GG.ZombieAI.CommandGhost(unitID, unitDefID, ghostX, ghostY, ghostZ)
				if enemyNearby then
					ghostData.readyFrame = gameFrame + GHOST_SAFE_TIME
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
	if scavUnitDefID ~= unitDefID then
		local x, y, z = spring.GetUnitPosition(unitID)
		local facing = spring.GetUnitDirection(unitID)
		local teamID = spring.GetUnitTeam(unitID)
		local newUnitID = spring.CreateUnit(scavUnitDefID, x, y, z, facing, teamID)
		if newUnitID then
			local health, maxHealth = spring.GetUnitHealth(unitID)
			local originalHealthRatio = health / maxHealth
			spring.SetUnitHealth(newUnitID, originalHealthRatio * maxHealth)
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
				if featureX then
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
	local inFluid = isFluidDeath(unitID, weaponDefID, attackerID)
	local unitStates = spring.GetUnitStates(unitID)
	pendingDeaths[unitID] = {
		unitDefID = unitDefID,
		teamID = unitTeam,
		x = unitX,
		y = unitY,
		z = unitZ,
		heading = spring.GetUnitHeading(unitID) or 0,
		wasZombie = wasZombie,
		demoteCorpse = wasZombie and (inFluid or not currentModeFeatures.alwaysCorpses),
		forcedHeap = false,
		guaranteeCorpse = isCorpseGuaranteeEligible(unitID, unitDefID, weaponDefID, inFluid),
		experience = spring.GetUnitExperience(unitID) or 0,
		fireState = unitStates and unitStates.firestate,
		moveState = unitStates and unitStates.movestate,
		timeoutFrame = gameFrame + PENDING_DEATH_TIMEOUT_FRAMES,
	}
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
	local featureID = spring.CreateFeature(zombieHeapDefs[deathData.unitDefID].corpseDefID, featureX, featureY, featureZ, heading, teamID)
	replacementDeathData = nil
	if not featureID then
		feedGhostQueue(deathData.unitDefID, featureX, featureZ)
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
	for swapIndex = 1, #wreckSwaps do
		local wreckSwap = wreckSwaps[swapIndex]
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
		feedGhostQueue(deathData.unitDefID, deathData.x, deathData.z)
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
	local remainingFeeds = {}
	for feedIndex = 1, #pendingCorpseHeapFeeds do
		local feed = pendingCorpseHeapFeeds[feedIndex]
		if frame - feed.frame <= 1 then
			remainingFeeds[#remainingFeeds + 1] = feed
		end
	end
	pendingCorpseHeapFeeds = remainingFeeds
end

function gadget:GameFrame(frame)
	gameFrame = frame

	expireCorpseHeapFeeds(frame)
	processWreckSwaps()
	resolveVanishedDeaths()
	expireDueZombieTurrets(frame)
	if currentModeFeatures.ghostRespawns then
		processDueSameUnitSpawns(frame)
		processDueSpiderPowerCredits(frame)
		if frame % GHOST_SPAWN_CHECK_INTERVAL == 0 then
			spawnBufferedGhostUnits()
		end
		if frame >= GHOST_RANDOM_SPAWN_INTERVAL and frame % GHOST_RANDOM_SPAWN_INTERVAL == 0 then
			spawnRandomMapGhost()
		end
	end

	if frame % REZ_SPEED_UPDATE_INTERVAL == 0 then
		updateRezSpeed()
	end

	local corpsesToCheck = corpseCheckFrames[frame]
	if corpsesToCheck then
		for i = 1, #corpsesToCheck do
			local featureID = corpsesToCheck[i]
			local corpseData = corpsesData[featureID]
			local featureX, featureY, featureZ
			if corpseData then
				featureX, featureY, featureZ = spring.GetFeaturePosition(featureID)
			end
			if not featureX then --feature is gone
				corpsesData[featureID] = nil
			else --feature is still there
				local featureDefData = zombieCorpseDefs[corpseData.featureDefID]
				if corpseData.tamperedFrame then
					resetSpawn(featureID, corpseData, featureX, featureZ)
				else
					spawnZombiesFromFeature(featureID, featureDefData.unitDefID, corpseData.wasZombie)
				end
			end
		end
		corpseCheckFrames[frame] = nil
	end

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
	local featureDef = featureDefID and featureDefs[featureDefID]
	local fromUnitName = featureDef and featureDef.customParams and featureDef.customParams.fromunit or ""
	return string.sub(fromUnitName, -5) == "_scav"
end

local function queueCorpseForSpawning(featureID, override, wasZombie)
	if not override and not autoSpawningEnabled then
		return
	end

	local featureDefID = spring.GetFeatureDefID(featureID)
	local corpseDefData = featureDefID and zombieCorpseDefs[featureDefID]
	if not corpseCanRespawn(featureID, corpseDefData) then
		return
	end

	wasZombie = wasZombie or wasZombieCorpse(featureID)

	local existingRezFrame = spring.GetFeatureRulesParam(featureID, ZOMBIE_REZ_FRAME_PARAM)
	local spawnDelayFrames = corpseDefData.spawnDelayFrames
	local spawnFrame = gameFrame + (spawnDelayFrames or 0)
	if existingRezFrame and existingRezFrame > 0 then
		spawnFrame = existingRezFrame
	end
	if spawnFrame <= gameFrame then
		spawnZombiesFromFeature(featureID, corpseDefData.unitDefID, wasZombie)
		return
	end

	local featureX, _, featureZ = spring.GetFeaturePosition(featureID)
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
	for feedIndex = 1, #pendingCorpseHeapFeeds do
		local feed = pendingCorpseHeapFeeds[feedIndex]
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
		return nil
	end
	local feed = pendingCorpseHeapFeeds[closestFeedIndex]
	table.remove(pendingCorpseHeapFeeds, closestFeedIndex)
	return feed
end

local function getWreckSwap(featureID, featureDefID, deathData)
	local defData = zombieHeapDefs[deathData.unitDefID]
	if featureDefID == defData.corpseDefID and deathData.demoteCorpse then
		return { featureID = featureID, deathData = deathData, demote = true }
	end
	if featureDefID == defData.heapDefID and deathData.guaranteeCorpse then
		return { featureID = featureID, deathData = deathData, demote = false }
	end
	return nil
end

function gadget:FeatureCreated(featureID, allyTeam, sourceID)
	local featureDefID = spring.GetFeatureDefID(featureID)
	local deathData = replacementDeathData
	if deathData then
		applyPreviousStates(featureID, deathData.previousStates)
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
			feedGhostQueue(deathData.unitDefID, featureX, featureZ)
		end
		return
	end
	local heapUnitDefData = zombieHeapFeatureDefs[featureDefID]
	if heapUnitDefData and not consumeCorpseHeapFeed(featureX, featureZ) then
		feedGhostQueue(heapUnitDefData.unitDefID, featureX, featureZ)
	end
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
		if not featureX then
			featureX, _, featureZ = spring.GetFeaturePosition(featureID)
		end
		if featureX and corpseDefData then
			feedGhostQueue(corpseDefData.unitDefID, featureX, featureZ)
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
	if newTeam ~= gaiaTeamID and zombieFactories[unitID] then
		revertZombieFactoryBuildpower(unitID, unitDefID)
	end
	if pendingZombieCaptures[unitID] then
		pendingZombieCaptures[unitID] = nil
		if not isZombie(unitID) then
			local unitX, unitY, unitZ = spring.GetUnitPosition(unitID)
			local health, maxHealth = spring.GetUnitHealth(unitID)
			local inheritedXp = spring.GetUnitExperience(unitID) or 0
			local healthReductionRatio = 1
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
		local featureDefData = zombieCorpseDefs[featureDefID]
		if corpseCanRespawn(featureID, featureDefData) then
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
	spiderPowerByUnitDefID = {}
	spiderPowerAddFrames = {}
	sameUnitSpawnFrames = {}
	pendingCorpseHeapFeeds = {}
end

---Drops every queued corpse spawn without affecting zombies already raised.
local function clearAllZombieSpawns()
	for featureID in pairs(corpsesData) do
		clearCorpseRezRulesParam(featureID)
	end
	corpsesData = {}
	corpseCheckFrames = {}
	clearGhostState()
end

local function isAuthorized(playerID)
	if spring.IsCheatingEnabled() then
		return true
	end
	local playername = spring.GetPlayerInfo(playerID)
	local accountID = BAR.Utilities.GetAccountID(playerID)
	local permissionTables = {
		_G.permissions.devhelpers,
	}
	if SYNCED then
		permissionTables[#permissionTables + 1] = SYNCED.permissions.devhelpers
	end
	for permissionIndex = 1, #permissionTables do
		local devhelpers = permissionTables[permissionIndex]
		if devhelpers and (devhelpers[accountID] or (playername and devhelpers[playername])) then
			return true
		end
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
		return modeName
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
---@param mode ZombieMode
---@return boolean applied `false` when `mode` is not a known mode.
local function setZombieMode(mode)
	if not ZOMBIE_MODE_FEATURES[mode] then
		return false
	end
	applyZombieModeSettings(mode)
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

local function runZombieChatAction(action, _, line, words, playerID)
	if not isAuthorized(playerID) then
		spring.SendMessageToPlayer(playerID, UNAUTHORIZED_TEXT)
		return
	end
	action(words, playerID)
end

local zombieChatActions = {
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
			local targetTeamID = readNonNegativeID(
				words,
				playerID,
				"Usage: /luarules zombieaggroteam <teamID>",
				"Invalid team ID"
			)
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
			local targetAllyID = readNonNegativeID(
				words,
				playerID,
				"Usage: /luarules zombieaggroally <allyID>",
				"Invalid ally ID"
			)
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
		description = "Clear allzombie orders",
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
				spring.SendMessageToPlayer(playerID, "Usage: /luarules zombiemode basic|oni|yokai|nani|akumu|spidergeddon")
				return
			end
			local mode = string.lower(words[1])
			if not setZombieMode(mode) then
				spring.SendMessageToPlayer(playerID, "Invalid mode. Use: basic, oni, yokai, nani, akumu, or spidergeddon")
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
			gadget:FeatureCreated(featureID, gaiaTeamID)
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

	for actionIndex = 1, #zombieChatActions do
		local chatAction = zombieChatActions[actionIndex]
		gadgetHandler:AddChatAction(chatAction.name, function(_, line, words, playerID)
			runZombieChatAction(chatAction.run, _, line, words, playerID)
		end, chatAction.description)
	end
end

function gadget:Shutdown()
	for actionIndex = 1, #zombieChatActions do
		gadgetHandler:RemoveChatAction(zombieChatActions[actionIndex].name)
	end
end

function gadget:GameStart()
	setGaiaStorage()
end
