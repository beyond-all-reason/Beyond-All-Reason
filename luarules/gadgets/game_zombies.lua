function gadget:GetInfo()
	return {
		name = "Zombies",
		desc = "Resurrects corpses as Scavengers or hostile Gaia Zombies",
		author = "SethDGamre, code snippets/inspiration from Rafal",
		date = "March 2024",
		license = "GNU GPL, v2 or later",
		layer = 2, -- after game_team_resources.lua
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
local WAS_ZOMBIE_TIMEOUT_FRAMES = Game.gameSpeed * 3

local MIN_ZOMBIE_XP = 0.25
local ZOMBIE_MAX_XP = 1.5

local standardTechToRezPowerSpeeds = {
	[0.5] = 1,
	[1] = 1,
	[1.5] = 3,
	[2] = 8,
	[2.5] = 25,
	[3] = 42,
	[3.5] = 63,
	[4] = 83,
	[4.5] = 104,
}

local harderTechToRezPowerSpeeds = {
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

---One of the zombie difficulty presets, matching the keys of `zombieModeConfigs`.
---@alias ZombieMode "normal"|"hard"|"nightmare"|"akumu"

local zombieModeConfigs = {
	normal = {
		techToRezPowerSpeeds = standardTechToRezPowerSpeeds,
		rezMin = 90,
		rezMax = 180,
		countMin = 1,
		countMax = 1,
		zombieCorpses = false,
	},
	hard = {
		techToRezPowerSpeeds = harderTechToRezPowerSpeeds,
		rezMin = 60,
		rezMax = 180,
		countMin = 1,
		countMax = 1,
		zombieCorpses = false,
	},
	nightmare = {
		techToRezPowerSpeeds = harderTechToRezPowerSpeeds,
		rezMin = 60,
		rezMax = 120,
		countMin = 2,
		countMax = 6,
		zombieCorpses = false,
	},
	akumu = {
		techToRezPowerSpeeds = harderTechToRezPowerSpeeds,
		rezMin = 60,
		rezMax = 120,
		countMin = 2,
		countMax = 8,
		zombieCorpses = true,
	},
}

---@type ZombieMode
local currentZombieMode = "normal"
local currentZombieConfig = zombieModeConfigs.normal

local ZOMBIE_CHECK_INTERVAL = Game.gameSpeed -- How often (in frames) everything else is checked
local REZ_SPEED_UPDATE_INTERVAL = Game.gameSpeed * 60
local WATER_DAMAGE_DEF_ID = Game.envDamageTypes.Water
local UNAUTHORIZED_TEXT = "You are not authorized to use zombie commands" --i18n library doesn't exist in gadget space.
local spValidUnitID = spring.ValidUnitID
local spGetGroundHeight = spring.GetGroundHeight
local spGetUnitPosition = spring.GetUnitPosition
local spGetFeaturePosition = spring.GetFeaturePosition
local spGetUnitDefID = spring.GetUnitDefID
local spGetUnitHealth = spring.GetUnitHealth
local spGetUnitRulesParam = spring.GetUnitRulesParam
local spSpawnCEG = spring.SpawnCEG
local random = math.random
local floor = math.floor
local clamp = math.clamp
local ceil = math.ceil

local teams = spring.GetTeamList()
local scavTeamID
local gaiaTeamID = spring.GetGaiaTeamID()
for _, teamID in ipairs(teams) do
	local teamLuaAI = spring.GetTeamLuaAI(teamID)
	if teamLuaAI and string.find(teamLuaAI, "ScavengersAI") then
		scavTeamID = teamID
	end
end

local gameFrame = 0
local adjustedRezPowerSpeed = currentZombieConfig.techToRezPowerSpeeds[1]
local currentTechLevel = nil
local autoSpawningEnabled = true

local zombiesBeingBuilt = {}
local zombieCorpseDefs = {}
local corpseCheckFrames = {}
local corpsesData = {}
local wereZombies = {}
local pendingUnitXp = {}
local pendingZombieCaptures = {}
local heapingZombies = {}
local zombieHeapDefs = {}
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

for unitDefID, unitDef in pairs(unitDefs) do
	local corpseDefName = unitDef.corpse
	if featureDefNames[corpseDefName] then
		local corpseDefID = featureDefNames[corpseDefName].id
		local corpseDefData = { unitDefID = unitDefID }
		local customRespawnTime = tonumber(unitDef.customParams and unitDef.customParams.zombie_respawn_time)
		if customRespawnTime then
			if customRespawnTime < 0 then
				corpseDefData.neverRespawn = true
			else
				corpseDefData.customRespawnTime = customRespawnTime
			end
		end
		zombieCorpseDefs[corpseDefID] = corpseDefData

		local zombieDefData = {}
		local deathExplosionName = unitDef.deathExplosion
		local explosionDefID = WeaponDefNames[deathExplosionName].id
		zombieDefData.explosionDefID = explosionDefID

		local heapDefName = featureDefs[corpseDefID].deathFeatureID
		if heapDefName then
			zombieDefData.heapDefID = heapDefName
		end

		zombieHeapDefs[unitDefID] = zombieDefData
	end

end

local function isZombie(unitID)
	return spGetUnitRulesParam(unitID, "zombie") == 1
end

local function setGaiaStorage()
	local metalStorageToSet = 1000000
	local energyStorageToSet = 1000000

	local _, currentMetalStorage = spring.GetTeamResources(gaiaTeamID, "metal")
	if currentMetalStorage and currentMetalStorage < metalStorageToSet then
		spring.SetTeamResource(gaiaTeamID, "ms", metalStorageToSet)
	end

	local _, currentEnergyStorage = spring.GetTeamResources(gaiaTeamID, "energy")
	if currentEnergyStorage and currentEnergyStorage < energyStorageToSet then
		spring.SetTeamResource(gaiaTeamID, "es", energyStorageToSet)
	end
end

local function getUnitRezPower(unitDef)
	return math.max(1, unitDef.power or 1)
end

local function calculateSpawnDelayFrames(unitPower)
	local spawnSeconds = floor(unitPower / adjustedRezPowerSpeed)
	spawnSeconds = clamp(spawnSeconds, currentZombieConfig.rezMin, currentZombieConfig.rezMax)
	return spawnSeconds * Game.gameSpeed
end

local function getRezPowerSpeedForTechLevel(config, techLevel)
	local speeds = config.techToRezPowerSpeeds
	if speeds[techLevel] then
		return speeds[techLevel]
	end
	return speeds[1]
end

local function rebuildZombieCorpseSpawnDelays()
	for _, corpseDefData in pairs(zombieCorpseDefs) do
		if corpseDefData.neverRespawn then
			corpseDefData.spawnDelayFrames = nil
		elseif corpseDefData.customRespawnTime then
			corpseDefData.spawnDelayFrames = floor(corpseDefData.customRespawnTime * Game.gameSpeed)
		else
			local unitDef = unitDefs[corpseDefData.unitDefID]
			corpseDefData.spawnDelayFrames = calculateSpawnDelayFrames(getUnitRezPower(unitDef))
		end
	end
end

local function updateAdjustedRezPowerSpeed()
	local techLevel = 1
	adjustedRezPowerSpeed = getRezPowerSpeedForTechLevel(currentZombieConfig, techLevel)
	if GG.PowerLib and GG.PowerLib.HighestPlayerTeamPower and GG.PowerLib.TechGuesstimate then
		local highestPowerData = GG.PowerLib.HighestPlayerTeamPower()
		techLevel = GG.PowerLib.TechGuesstimate(highestPowerData.power)
		adjustedRezPowerSpeed = getRezPowerSpeedForTechLevel(currentZombieConfig, techLevel)
	end

	currentTechLevel = techLevel
end

local function updateRezSpeed()
	updateAdjustedRezPowerSpeed()
	rebuildZombieCorpseSpawnDelays()
end

---Applies a preset's tuning to the live zombie config, falling back to `normal`
---for an unknown mode.
---@param mode ZombieMode
local function applyZombieModeSettings(mode)
	local config = zombieModeConfigs[mode]
	---@diagnostic disable-next-line: unnecessary-if
	if not config then
		config = zombieModeConfigs.normal
	end

	currentZombieMode = mode
	currentZombieConfig = config

	updateRezSpeed()
end

local function calculateHealthRatio(featureID)
	local partialReclaimRatio = 1
	local damagedReductionRatio = 1
	local currentMetal, maxMetal = spring.GetFeatureResources(featureID)
	if currentMetal and maxMetal and currentMetal ~= 0 and maxMetal ~= 0 then
		partialReclaimRatio = currentMetal / maxMetal
	end
	local health, maxHealth = spring.GetFeatureHealth(featureID)
	if health and maxHealth and health ~= 0 and maxHealth ~= 0 then
		damagedReductionRatio = health / maxHealth
	end
	local healthRatio = (partialReclaimRatio + damagedReductionRatio) * 0.5 --average the two ratios to skew the result towards maximum health
	return healthRatio
end

local function warningCEG(featureID, x, y, z)
	local radius = spring.GetFeatureRadius(featureID)

	local selectedEffect = warningEffects[random(#warningEffects)]
	if selectedEffect == "scavradiation-lightning" and GG.SpawnEnvironmentalLightning then
		GG.SpawnEnvironmentalLightning("scavradiation", x, y, z)
	else
		spSpawnCEG(selectedEffect, x, y, z, 0, 0, 0, radius * 0.25)
	end
	spSpawnCEG("scaspawn-trail", x, y, z, 0, 0, 0, radius)
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

local function resetSpawn(featureID, featureData, featureDefData)
	local newFrame = featureData.tamperedFrame + featureData.spawnDelayFrames
	featureData.spawnFrame = newFrame
	featureData.creationFrame = featureData.tamperedFrame
	featureData.tamperedFrame = nil -- reclaim/rez progress restarts the spawn timer from this frame
	setCorpseRezRulesParam(featureID, newFrame)
	corpseCheckFrames[newFrame] = corpseCheckFrames[newFrame] or {}
	corpseCheckFrames[newFrame][#corpseCheckFrames[newFrame] + 1] = featureID
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

local function applyZombieBuildRangeBonus(unitID, unitDefID)
	local unitDef = unitDefs[unitDefID]
	local originalBuildDistance = unitDef and unitDef.buildDistance
	if not originalBuildDistance or originalBuildDistance <= 0 then
		return
	end
	local losRadius = unitDef.losRadius or unitDef.sightDistance or 0
	local boostedBuildDistance = math.max(originalBuildDistance, losRadius)
	spring.SetUnitBuildParams(unitID, "buildDistance", boostedBuildDistance)
end

local function restoreOriginalBuildRange(unitID, unitDefID)
	local unitDef = unitDefs[unitDefID]
	local originalBuildDistance = unitDef and unitDef.buildDistance
	if not originalBuildDistance or originalBuildDistance <= 0 then
		return
	end
	spring.SetUnitBuildParams(unitID, "buildDistance", originalBuildDistance)
end

local function rollSpawnCount()
	return random(currentZombieConfig.countMin, currentZombieConfig.countMax)
end

local function calculateSpawnCount(unitDefID)
	local countMin = currentZombieConfig.countMin
	local countMax = currentZombieConfig.countMax
	if countMin == countMax then
		return countMin
	end

	local unitDef = unitDefs[unitDefID]
	local rezTimeSeconds = calculateSpawnDelayFrames(getUnitRezPower(unitDef)) / Game.gameSpeed
	local rezMin = currentZombieConfig.rezMin
	local rezMax = currentZombieConfig.rezMax

	if currentTechLevel <= 1 then
		return math.min(rollSpawnCount(), rollSpawnCount(), rollSpawnCount()) -- extra min() rolls skew the count down except for cheap, fast-rez units
	end

	if rezTimeSeconds == rezMin then
		return rollSpawnCount()
	end
	if rezTimeSeconds == rezMax then
		return math.min(rollSpawnCount(), rollSpawnCount(), rollSpawnCount())
	end
	return math.min(rollSpawnCount(), rollSpawnCount())
end

local function spawnZombies(featureID, unitDefID, healthReductionRatio, x, y, z, wasZombie, pastXp)
	local unitDef = unitDefs[unitDefID]
	local spawnCount = 1 -- dead zombies never multiply, so they can't snowball
	if not wasZombie and unitDef.speed > 0 then
		spawnCount = calculateSpawnCount(unitDefID)
	end
	local size = unitDef.xsize
	local unitDefToCreate = getScavVariantUnitDefID(unitDefID)
	local sizeCategory = ceil((unitDef.xsize / 2 + unitDef.zsize / 2) / 2)
	local sizeName = "small"
	if sizeCategory > 4.5 then
		sizeName = "huge"
	elseif sizeCategory > 3.5 then
		sizeName = "large"
	elseif sizeCategory > 2.5 then
		sizeName = "medium"
	elseif sizeCategory > 1.5 then
		sizeName = "small"
	else
		sizeName = "tiny"
	end

	if pastXp == nil then
		local corpseData = corpsesData[featureID]
		if corpseData then
			pastXp = corpseData.pastXp
		else
			pastXp = spring.GetFeatureRulesParam(featureID, "previous_xp") or 0
		end
	end

	spring.DestroyFeature(featureID)
	corpsesData[featureID] = nil
	playSpawnSound(x, y, z)

	for i = 1, spawnCount do
		local randomX = x + random(-size * spawnCount, size * spawnCount)
		local randomZ = z + random(-size * spawnCount, size * spawnCount)
		local adjustedY = spGetGroundHeight(randomX, randomZ)

		local unitID = spring.CreateUnit(unitDefToCreate, randomX, adjustedY, randomZ, 0, gaiaTeamID)
		if unitID then
			spSpawnCEG("scav-spawnexplo-" .. sizeName, randomX, adjustedY, randomZ, 0, 0, 0)
			local generatedXp = 0
			if modOptions.zombies ~= "normal" then
				generatedXp = math.max(MIN_ZOMBIE_XP, math.min(random() * ZOMBIE_MAX_XP, random() * ZOMBIE_MAX_XP, random() * ZOMBIE_MAX_XP)) -- triple-roll min keeps most extra XP low
			end
			spring.SetUnitExperience(unitID, math.max(pastXp, generatedXp))
			local unitHealth = spGetUnitHealth(unitID)
			spring.SetUnitHealth(unitID, unitHealth * healthReductionRatio)
			spring.SetUnitRulesParam(unitID, "zombie", 1)
			if scavTeamID then
				spring.TransferUnit(unitID, scavTeamID)
			else
				initializeZombieAI(unitID, unitDefToCreate)
				applyZombieBuildRangeBonus(unitID, unitDefToCreate)
			end
		end
	end
end

---Turns a unit into a zombie, swapping it for its `_scav` variant where one exists.
---@param unitID UnitID
local function setZombie(unitID)
	local unitDefID = spGetUnitDefID(unitID)
	if not unitDefID then
		return
	end

	local scavUnitDefID = getScavVariantUnitDefID(unitDefID)

	-- If we need to convert to _scav variant
	if scavUnitDefID ~= unitDefID then
		local x, y, z = spGetUnitPosition(unitID)
		local facing = spring.GetUnitDirection(unitID)
		local teamID = spring.GetUnitTeam(unitID)
		local newUnitID = spring.CreateUnit(scavUnitDefID, x, y, z, facing, teamID)
		if newUnitID then
			local health, maxHealth = spGetUnitHealth(unitID)
			local originalHealthRatio = health / maxHealth
			spring.SetUnitHealth(newUnitID, originalHealthRatio * maxHealth)
			local experience = spring.GetUnitExperience(unitID)
			spring.SetUnitExperience(newUnitID, experience)

			spring.DestroyUnit(unitID, false, true)

			unitID = newUnitID
			unitDefID = scavUnitDefID
		end
	end

	spring.SetUnitRulesParam(unitID, "zombie", 1)
	initializeZombieAI(unitID, unitDefID)
	if spring.GetUnitTeam(unitID) == gaiaTeamID then
		applyZombieBuildRangeBonus(unitID, unitDefID)
	end
end

function gadget:FeatureBuildStepPost(featureID)
	local featureData = corpsesData[featureID]
	if featureData then
		if not featureData.tamperedFrame then
			local remainingFrames = featureData.spawnFrame - gameFrame
			if remainingFrames < featureData.spawnDelayFrames - TIMER_NEAR_MAX_THRESHOLD then
				local featureX, featureY, featureZ = spGetFeaturePosition(featureID)
				if featureX then
					spSpawnCEG("scaspawn-trail", featureX, featureY + 15, featureZ, 0, 0, 0)
				end
			end
		end
		featureData.tamperedFrame = gameFrame
	end
end

function gadget:GameFrame(frame)
	gameFrame = frame

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
				featureX, featureY, featureZ = spGetFeaturePosition(featureID)
			end
			if not featureX then --feature is gone
				corpsesData[featureID] = nil
			else --feature is still there
				local featureDefData = zombieCorpseDefs[corpseData.featureDefID]
				if corpseData.tamperedFrame then
					resetSpawn(featureID, corpseData, featureDefData)
				else
					local healthReductionRatio = calculateHealthRatio(featureID)
					spawnZombies(
						featureID,
						featureDefData.unitDefID,
						healthReductionRatio,
						featureX,
						featureY,
						featureZ,
						corpseData.wasZombie,
						corpseData.pastXp
					)
				end
			end
		end
		corpseCheckFrames[frame] = nil
	end

	if frame % ZOMBIE_CHECK_INTERVAL == 0 then
		spring.AddTeamResource(gaiaTeamID, "metal", 1000000)
		spring.AddTeamResource(gaiaTeamID, "energy", 1000000)
		for unitID, timeoutFrame in pairs(wereZombies) do
			if timeoutFrame < frame then
				wereZombies[unitID] = nil
			end
		end
		for unitID, xpData in pairs(pendingUnitXp) do
			if xpData.timeout < frame then
				pendingUnitXp[unitID] = nil
			end
		end
		for featureID, featureData in pairs(corpsesData) do
			if featureData.spawnFrame - frame < WARNING_TIME then
				local featureX, featureY, featureZ = spGetFeaturePosition(featureID)
				if not featureX then --doesn't exist anymore
					corpsesData[featureID] = nil
				elseif not featureData.tamperedFrame then
					warningCEG(featureID, featureX, featureY, featureZ)
				end
			end
		end
	end
end

local function queueCorpseForSpawning(featureID, override, wasZombie, pastXp)
	if not override and not autoSpawningEnabled then
		return
	end

	local featureDefID = spring.GetFeatureDefID(featureID)
	local corpseDefData = zombieCorpseDefs[featureDefID]
	if not corpseDefData or corpseDefData.neverRespawn then
		return
	end

	wasZombie = wasZombie or wasZombieCorpse(featureID)
	if pastXp == nil then
		local existingCorpseData = corpsesData[featureID]
		if existingCorpseData then
			pastXp = existingCorpseData.pastXp
		else
			pastXp = spring.GetFeatureRulesParam(featureID, "previous_xp") or 0
		end
	end

	local spawnDelayFrames = corpseDefData.spawnDelayFrames
	if spawnDelayFrames == 0 then
		local featureX, featureY, featureZ = spGetFeaturePosition(featureID)
		if featureX then
			local healthReductionRatio = calculateHealthRatio(featureID)
			spawnZombies(
				featureID,
				corpseDefData.unitDefID,
				healthReductionRatio,
				featureX,
				featureY,
				featureZ,
				wasZombie,
				pastXp
			)
		end
		return
	end

	local spawnFrame = gameFrame + spawnDelayFrames
	corpsesData[featureID] = {
		featureDefID = featureDefID,
		spawnDelayFrames = spawnDelayFrames,
		creationFrame = gameFrame,
		spawnFrame = spawnFrame,
		wasZombie = wasZombie,
		pastXp = pastXp,
	}
	setCorpseRezRulesParam(featureID, spawnFrame)
	corpseCheckFrames[spawnFrame] = corpseCheckFrames[spawnFrame] or {}
	corpseCheckFrames[spawnFrame][#corpseCheckFrames[spawnFrame] + 1] = featureID
end

function gadget:FeatureCreated(featureID, allyTeam, sourceID)
	local wasZombie = false
	local pastXp = 0
	if sourceID and wereZombies[sourceID] then
		wasZombie = true
		wereZombies[sourceID] = nil
		spring.SetFeatureRulesParam(featureID, WAS_ZOMBIE_PARAM, 1, PUBLIC_RULES_PARAM_ACCESS)
	end
	if sourceID and pendingUnitXp[sourceID] then
		pastXp = pendingUnitXp[sourceID].xp
		pendingUnitXp[sourceID] = nil
	else
		pastXp = spring.GetFeatureRulesParam(featureID, "previous_xp") or 0
	end
	queueCorpseForSpawning(featureID, false, wasZombie, pastXp)
end

function gadget:FeatureDestroyed(featureID, allyTeam)
	clearCorpseRezRulesParam(featureID)
	corpsesData[featureID] = nil
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

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	if zombieHeapDefs[unitDefID] then
		pendingUnitXp[unitID] =
			{ xp = spring.GetUnitExperience(unitID) or 0, timeout = gameFrame + WAS_ZOMBIE_TIMEOUT_FRAMES }
	end
	if isZombie(unitID) and currentZombieConfig.zombieCorpses and not heapingZombies[unitID] then
		wereZombies[unitID] = gameFrame + WAS_ZOMBIE_TIMEOUT_FRAMES -- FeatureCreated may land later, so stash zombie-ness for a few seconds
	end
	heapingZombies[unitID] = nil
	pendingZombieCaptures[unitID] = nil
	zombiesBeingBuilt[unitID] = nil
end

function gadget:AllowUnitCaptureStep(builderID, builderTeam, unitID, unitDefID, part)
	if isZombie(builderID) then
		pendingZombieCaptures[unitID] = true
	end
	return true
end

function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	if oldTeam == gaiaTeamID and newTeam ~= gaiaTeamID and isZombie(unitID) then
		restoreOriginalBuildRange(unitID, unitDefID)
	end
	if pendingZombieCaptures[unitID] then
		pendingZombieCaptures[unitID] = nil
		if not isZombie(unitID) then
			setZombie(unitID) -- capture finished: the victim becomes a zombie too
		end
	end
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

local function shouldAlwaysLeaveHeap(unitID, weaponDefID, attackerID) -- water/lava deaths always heap so they can't rez from the fluid
	if weaponDefID == WATER_DAMAGE_DEF_ID then
		return true
	end
	if not isUnitInLava(unitID) then
		return false
	end
	if not weaponDefID or weaponDefID < 0 then
		return true
	end
	if not attackerID or attackerID < 0 or not spValidUnitID(attackerID) then
		return true
	end
	return false
end

local function leaveZombieHeap(unitID, unitDefID, attackerID)
	local unitX, unitY, unitZ = spGetUnitPosition(unitID)
	if not unitX then
		return
	end
	local defData = zombieHeapDefs[unitDefID]
	if not defData then
		return
	end
	heapingZombies[unitID] = true -- eat the killing blow and leave a heap instead of a rez-able wreck
	spring.DestroyUnit(unitID, false, true, attackerID)
	spring.SpawnExplosion(unitX, unitY, unitZ, 0, 0, 0, { weaponDef = defData.explosionDefID, owner = unitID })
	if defData.heapDefID then
		spring.CreateFeature(defData.heapDefID, unitX, unitY, unitZ)
	end
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID)
	if not isZombie(unitID) then
		return
	end
	local leaveHeap = not currentZombieConfig.zombieCorpses or shouldAlwaysLeaveHeap(unitID, weaponDefID, attackerID)
	if not leaveHeap then
		return
	end
	local health = spGetUnitHealth(unitID)
	if damage >= health then
		leaveZombieHeap(unitID, unitDefID, attackerID)
	end
end

---Immediately raises zombies from a corpse feature. Only acts while in idle mode.
---@param featureID FeatureID
---@return boolean spawned `false` when not in idle mode, or the feature is not a zombie corpse.
local function createZombieFromFeature(featureID)
	if isIdleMode then
		local featureDefID = spring.GetFeatureDefID(featureID)
		if zombieCorpseDefs[featureDefID] then
			local featureX, featureY, featureZ = spGetFeaturePosition(featureID)
			if featureX then
				local featureDefData = zombieCorpseDefs[featureDefID]
				local healthReductionRatio = calculateHealthRatio(featureID)
				local corpseData = corpsesData[featureID]
				local wasZombie = wasZombieCorpse(featureID, corpseData)
				local pastXp = corpseData and corpseData.pastXp
				spawnZombies(
					featureID,
					featureDefData.unitDefID,
					healthReductionRatio,
					featureX,
					featureY,
					featureZ,
					wasZombie,
					pastXp
				)
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
		queueCorpseForSpawning(featureID, true)
	end
end

---Switches all zombies between return-fire with no auto-orders and normal aggression.
---@param enabled boolean `true` to pacify, `false` to restore normal behavior.
local function pacifyZombies(enabled)
	if GG.ZombieAI then
		GG.ZombieAI.PacifyZombies(enabled)
	end
end

---Stops or resumes the automatic orders given to zombies, without changing fire state.
---@param enabled boolean `true` to suspend auto-orders, `false` to resume them.
local function suspendAutoOrders(enabled)
	if GG.ZombieAI then
		GG.ZombieAI.SuspendAutoOrders(enabled)
	end
end

local function aggroTeamID(teamID)
	if GG.ZombieAI then
		return GG.ZombieAI.AggroTeamID(teamID)
	end
	return false
end

local function aggroAllyID(allyID)
	if GG.ZombieAI then
		return GG.ZombieAI.AggroAllyID(allyID)
	end
	return false
end

local function killAllZombies()
	if GG.ZombieAI then
		GG.ZombieAI.KillAllZombies()
	end
end

local function clearAllOrders()
	if GG.ZombieAI then
		GG.ZombieAI.ClearAllOrders()
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

---Drops every queued corpse spawn without affecting zombies already raised.
local function clearAllZombieSpawns()
	for featureID in pairs(corpsesData) do
		clearCorpseRezRulesParam(featureID)
	end
	corpsesData = {}
	corpseCheckFrames = {}
end

local function isAuthorized(playerID)
	if spring.IsCheatingEnabled() then
		return true
	end
	local playername = spring.GetPlayerInfo(playerID)
	local accountID = BAR.Utilities.GetAccountID(playerID)
	if
		(
			_G.permissions.devhelpers
			and (_G.permissions.devhelpers[accountID] or (playername and _G.permissions.devhelpers[playername]))
		)
		or (
			SYNCED
			and SYNCED.permissions.devhelpers
			and (SYNCED.permissions.devhelpers[accountID] or (playername and SYNCED.permissions.devhelpers[playername]))
		)
	then
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
		if spValidUnitID(unitID) then
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
		if unitTeam == gaiaTeamID and not isZombie(unitID) then
			setZombie(unitID)
			convertedCount = convertedCount + 1
		end
	end

	return convertedCount
end

local function commandSetAllGaiaToZombies(_, line, words, playerID)
	if not isAuthorized(playerID) then
		spring.SendMessageToPlayer(playerID, UNAUTHORIZED_TEXT)
		return
	end

	local convertedCount = setAllGaiaToZombies()
	spring.SendMessageToPlayer(playerID, "Set " .. convertedCount .. " Gaia units as zombies")
end

local function commandQueueAllCorpsesForReanimation(_, line, words, playerID)
	if not isAuthorized(playerID) then
		spring.SendMessageToPlayer(playerID, UNAUTHORIZED_TEXT)
		return
	end

	queueAllCorpsesForSpawning()
	spring.SendMessageToPlayer(playerID, "Queued all corpses for spawning")
end

local function commandToggleAutoReanimation(_, line, words, playerID)
	if not isAuthorized(playerID) then
		spring.SendMessageToPlayer(playerID, UNAUTHORIZED_TEXT)
		return
	end

	if #words == 0 then
		spring.SendMessageToPlayer(playerID, "Usage: /luarules zombieautospawn 0|1")
		return
	end

	local enabled = tonumber(words[1])
	if enabled == nil or (enabled ~= 0 and enabled ~= 1) then
		spring.SendMessageToPlayer(playerID, "Invalid value. Use 0 to disable or 1 to enable")
		return
	end

	setAutoSpawning(enabled == 1)
	spring.SendMessageToPlayer(playerID, "Auto spawning " .. (enabled == 1 and "enabled" or "disabled"))
end

local function commandPacifyZombies(_, line, words, playerID)
	if not isAuthorized(playerID) then
		spring.SendMessageToPlayer(playerID, UNAUTHORIZED_TEXT)
		return
	end

	if #words == 0 then
		spring.SendMessageToPlayer(playerID, "Usage: /luarules zombiepacify 0|1")
		return
	end

	local enabled = tonumber(words[1])
	if enabled == nil or (enabled ~= 0 and enabled ~= 1) then
		spring.SendMessageToPlayer(playerID, "Invalid value. Use 0 to disable or 1 to enable")
		return
	end

	pacifyZombies(enabled == 1)
	spring.SendMessageToPlayer(playerID, "Zombies " .. (enabled == 1 and "pacified" or "unpacified"))
end

local function commandSuspendAutoOrders(_, line, words, playerID)
	if not isAuthorized(playerID) then
		spring.SendMessageToPlayer(playerID, UNAUTHORIZED_TEXT)
		return
	end

	if #words == 0 then
		spring.SendMessageToPlayer(playerID, "Usage: /luarules zombiesuspendorders 0|1")
		return
	end

	local enabled = tonumber(words[1])
	if enabled == nil or (enabled ~= 0 and enabled ~= 1) then
		spring.SendMessageToPlayer(playerID, "Invalid value. Use 0 to disable or 1 to enable")
		return
	end

	suspendAutoOrders(enabled == 1)
	spring.SendMessageToPlayer(playerID, "Zombie auto-orders " .. (enabled == 1 and "suspended" or "resumed"))
end

local function commandAggroZombiesToTeam(_, line, words, playerID)
	if not isAuthorized(playerID) then
		spring.SendMessageToPlayer(playerID, UNAUTHORIZED_TEXT)
		return
	end

	if #words == 0 then
		spring.SendMessageToPlayer(playerID, "Usage: /luarules zombieaggroteam <teamID>")
		return
	end

	local targetTeamID = tonumber(words[1])
	if not targetTeamID or targetTeamID < 0 then
		spring.SendMessageToPlayer(playerID, "Invalid team ID")
		return
	end

	local success = aggroTeamID(targetTeamID)
	if success then
		spring.SendMessageToPlayer(playerID, "Zombies aggroed to team " .. targetTeamID)
	else
		spring.SendMessageToPlayer(playerID, "Team " .. targetTeamID .. " not found or has no units")
	end
end

local function commandAggroZombiesToAlly(_, line, words, playerID)
	if not isAuthorized(playerID) then
		spring.SendMessageToPlayer(playerID, UNAUTHORIZED_TEXT)
		return
	end

	if #words == 0 then
		spring.SendMessageToPlayer(playerID, "Usage: /luarules zombieaggroally <allyID>")
		return
	end

	local targetAllyID = tonumber(words[1])
	if not targetAllyID or targetAllyID < 0 then
		spring.SendMessageToPlayer(playerID, "Invalid ally ID")
		return
	end

	local success = aggroAllyID(targetAllyID)
	if success then
		spring.SendMessageToPlayer(playerID, "Zombies aggroed to ally team " .. targetAllyID)
	else
		spring.SendMessageToPlayer(playerID, "Ally team " .. targetAllyID .. " not found or has no units")
	end
end

local function commandKillAllZombies(_, line, words, playerID)
	if not isAuthorized(playerID) then
		spring.SendMessageToPlayer(playerID, UNAUTHORIZED_TEXT)
		return
	end

	killAllZombies()
	spring.SendMessageToPlayer(playerID, "Killed all zombies")
end

local function commandClearAllZombieOrders(_, line, words, playerID)
	if not isAuthorized(playerID) then
		spring.SendMessageToPlayer(playerID, UNAUTHORIZED_TEXT)
		return
	end

	clearAllOrders()
	spring.SendMessageToPlayer(playerID, "Cleared zombie orders")
end

local function commandClearZombieSpawns(_, line, words, playerID)
	if not isAuthorized(playerID) then
		spring.SendMessageToPlayer(playerID, UNAUTHORIZED_TEXT)
		return
	end

	clearAllZombieSpawns()
	spring.SendMessageToPlayer(playerID, "Cleared all queued zombie spawns")
end

---Switches the zombie difficulty preset.
---@param mode ZombieMode
---@return boolean applied `false` when `mode` is not a known preset.
local function setZombieMode(mode)
	---@diagnostic disable-next-line: unnecessary-if
	if mode ~= "normal" and mode ~= "hard" and mode ~= "nightmare" and mode ~= "akumu" then
		return false
	end

	currentZombieMode = mode
	applyZombieModeSettings(mode)
	return true
end

local function getZombieMode()
	return currentZombieMode
end

local function commandSetZombieMode(_, line, words, playerID)
	if not isAuthorized(playerID) then
		spring.SendMessageToPlayer(playerID, UNAUTHORIZED_TEXT)
		return
	end

	if #words == 0 then
		spring.SendMessageToPlayer(playerID, "Usage: /luarules zombiemode normal|hard|nightmare|akumu")
		return
	end

	local mode = string.lower(words[1])
	if mode ~= "normal" and mode ~= "hard" and mode ~= "nightmare" and mode ~= "akumu" then
		spring.SendMessageToPlayer(playerID, "Invalid mode. Use: normal, hard, nightmare, or akumu")
		return
	end

	setZombieMode(mode)
	spring.SendMessageToPlayer(playerID, "Zombie mode set to " .. mode)
end

function gadget:Initialize()
	local initialMode = modOptions.zombies or "normal"
	applyZombieModeSettings(initialMode)

	autoSpawningEnabled = modOptionEnabled and not isIdleMode

	gameFrame = spring.GetGameFrame()

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

	GG.Zombies = { IdleMode = isIdleMode }
	GG.Zombies.SetZombie = setZombie
	GG.Zombies.ConvertUnitsToZombies = convertUnitsToZombies
	GG.Zombies.SetAllGaiaToZombies = setAllGaiaToZombies
	GG.Zombies.CreateZombieFromFeature = createZombieFromFeature
	GG.Zombies.QueueAllCorpsesForSpawning = queueAllCorpsesForSpawning
	GG.Zombies.SetAutoSpawning = setAutoSpawning
	GG.Zombies.ClearAllZombieSpawns = clearAllZombieSpawns
	GG.Zombies.PacifyZombies = pacifyZombies
	GG.Zombies.SuspendAutoOrders = suspendAutoOrders
	GG.Zombies.AggroTeamID = aggroTeamID
	GG.Zombies.AggroAllyID = aggroAllyID
	GG.Zombies.KillAllZombies = killAllZombies
	GG.Zombies.ClearAllOrders = clearAllOrders
	GG.Zombies.SetZombieMode = setZombieMode
	GG.Zombies.GetZombieMode = getZombieMode

	gadgetHandler:AddChatAction("zombiesetallgaia", commandSetAllGaiaToZombies, "Set all Gaia units as zombies")
	gadgetHandler:AddChatAction(
		"zombiequeueallcorpses",
		commandQueueAllCorpsesForReanimation,
		"Queue all corpses for spawning"
	)
	gadgetHandler:AddChatAction("zombieautospawn", commandToggleAutoReanimation, "Enable/disable auto spawning")
	gadgetHandler:AddChatAction("zombieclearspawns", commandClearZombieSpawns, "Clear all queued zombie spawns")
	gadgetHandler:AddChatAction("zombiepacify", commandPacifyZombies, "Pacify/unpacify zombies")
	gadgetHandler:AddChatAction("zombiesuspendorders", commandSuspendAutoOrders, "Suspend/resume zombie auto-orders")
	gadgetHandler:AddChatAction("zombieaggroteam", commandAggroZombiesToTeam, "Make zombies aggro to specific team")
	gadgetHandler:AddChatAction("zombieaggroally", commandAggroZombiesToAlly, "Make zombies aggro to entire ally team")
	gadgetHandler:AddChatAction("zombiekillall", commandKillAllZombies, "Kill all zombies")
	gadgetHandler:AddChatAction("zombieclearallorders", commandClearAllZombieOrders, "Clear allzombie orders")
	gadgetHandler:AddChatAction("zombiemode", commandSetZombieMode, "Set zombie mode (normal/hard/nightmare/akumu)")
end

function gadget:Shutdown()
	gadgetHandler:RemoveChatAction("zombiesetallgaia")
	gadgetHandler:RemoveChatAction("zombiequeueallcorpses")
	gadgetHandler:RemoveChatAction("zombieautospawn")
	gadgetHandler:RemoveChatAction("zombieclearspawns")
	gadgetHandler:RemoveChatAction("zombiepacify")
	gadgetHandler:RemoveChatAction("zombiesuspendorders")
	gadgetHandler:RemoveChatAction("zombieaggroteam")
	gadgetHandler:RemoveChatAction("zombieaggroally")
	gadgetHandler:RemoveChatAction("zombiekillall")
	gadgetHandler:RemoveChatAction("zombieclearallorders")
	gadgetHandler:RemoveChatAction("zombiemode")
end

function gadget:GameStart()
	setGaiaStorage()
end
