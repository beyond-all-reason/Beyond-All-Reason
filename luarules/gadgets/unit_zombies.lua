function gadget:GetInfo()
	return {
		name      = "Corpse Revival",
		desc      = "Resurrects corpses as Scavengers or hostile Gaia",
		author    = "SethDGamre, code snippets/inspiration from Rafal",
		date      = "March 2024",
		license   = "GNU GPL, v2 or later",
		layer     = 2,
		enabled   = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local modOptions = Spring.GetModOptions()

local ZOMBIE_GUARD_RADIUS = 300			-- Radius for zombies to guard allies
local ZOMBIE_ORDER_COUNT = 10
local ZOMBIE_GUARD_CHANCE = 0.65		-- Chance a zombie will guard allies
local WARNING_TIME = 15 * Game.gameSpeed-- Frames to start warning before reanimation

local ZOMBIE_MAX_XP = 2					-- Maximum experience value for zombies, skewed towards median

local zombieModeConfigs = {
	normal = {
		rezSpeed = 16,
		rezMin = 60,
		rezMax = 180,
		countMin = 1,
		countMax = 1
	},
	hard = {
		rezSpeed = 24,
		rezMin = 30,
		rezMax = 90,
		countMin = 1,
		countMax = 1
	},
	nightmare = {
		rezSpeed = 24,
		rezMin = 30,
		rezMax = 90,
		countMin = 2,
		countMax = 5
	},
	extreme = {
		rezSpeed = 48,
		rezMin = 30,
		rezMax = 45,
		countMin = 4,
		countMax = 10
	}
}

local currentZombieMode = "normal"
local currentZombieConfig = zombieModeConfigs.normal

local ZOMBIE_ORDER_CHECK_INTERVAL = Game.gameSpeed * 10 -- How often (in frames) to check if zombies need new orders
local ZOMBIE_CHECK_INTERVAL = Game.gameSpeed -- How often (in frames) everything else is checked

local CMD_REPEAT = CMD.REPEAT
local CMD_MOVE_STATE = CMD.MOVE_STATE
local CMD_FIGHT = CMD.FIGHT
local CMD_OPT_SHIFT = CMD.OPT_SHIFT
local CMD_GUARD = CMD.GUARD
local CMD_FIRE_STATE = CMD.FIRE_STATE

local FIRE_STATE_FIRE_AT_WILL = 2
local FIRE_STATE_RETURN_FIRE = 1
local MOVE_STATE_ROAM = 2
local ENABLE_REPEAT = 1

local spGetGroundHeight			= Spring.GetGroundHeight
local spGetUnitPosition			= Spring.GetUnitPosition
local spGetFeaturePosition		= Spring.GetFeaturePosition
local spCreateUnit				= Spring.CreateUnit
local spTransferUnit			= Spring.TransferUnit
local spGetUnitDefID			= Spring.GetUnitDefID
local spGetUnitTeam				= Spring.GetUnitTeam
local spGetAllUnits				= Spring.GetAllUnits
local spGetGameFrame			= Spring.GetGameFrame
local spGetAllFeatures			= Spring.GetAllFeatures
local spGiveOrderToUnit			= Spring.GiveOrderToUnit
local spGetUnitCommandCount		= Spring.GetUnitCommandCount
local spDestroyFeature			= Spring.DestroyFeature
local spGetUnitIsDead			= Spring.GetUnitIsDead
local spGiveOrderArrayToUnit 	= Spring.GiveOrderArrayToUnit
local spGetUnitsInCylinder		= Spring.GetUnitsInCylinder
local spSetTeamResource			= Spring.SetTeamResource
local spGetUnitHealth			= Spring.GetUnitHealth
local spSetUnitHealth			= Spring.SetUnitHealth
local spSetUnitRulesParam		= Spring.SetUnitRulesParam
local spGetUnitRulesParam		= Spring.GetUnitRulesParam
local spGetFeatureDefID			= Spring.GetFeatureDefID
local spTestMoveOrder			= Spring.TestMoveOrder
local spSpawnCEG				= Spring.SpawnCEG
local spGetFeatureResources		= Spring.GetFeatureResources
local spGetFeatureHealth		= Spring.GetFeatureHealth
local spDestroyUnit				= Spring.DestroyUnit
local spCreateFeature			= Spring.CreateFeature
local spSpawnExplosion			= Spring.SpawnExplosion
local spPlaySoundFile			= Spring.PlaySoundFile
local spGetFeatureRadius		= Spring.GetFeatureRadius
local spGetUnitCurrentCommand	= Spring.GetUnitCurrentCommand
local spSetUnitExperience		= Spring.SetUnitExperience
local random					= math.random
local distance2dSquared			= math.distance2dSquared

local teams = Spring.GetTeamList()
local scavTeamID
local gaiaTeamID = Spring.GetGaiaTeamID()
for _, teamID in ipairs(teams) do
	local teamLuaAI = Spring.GetTeamLuaAI(teamID)
	if (teamLuaAI and string.find(teamLuaAI, "ScavengersAI")) then
		scavTeamID = teamID
	end
end
local mapWidth
local mapHeight

local ordersEnabled = true
local gameFrame = 0
local adjustedRezSpeed = currentZombieConfig.rezSpeed
local isIdleMode = false
local autoSpawningEnabled = true
local debugMode = false

local extraDefs = {}
local zombieCorpseDefs = {}
local zombieWatch = {}
local corpseCheckFrames = {}
local corpsesData = {}
local zombieHeapDefs = {}
local warningEffects = {
	"scavmist",
	"scavradiation-lightning",
}
local spawnEffects = {
	"xploelc2",
	"xploelc3",
}

for unitDefID, unitDef in pairs(UnitDefs) do
	local corpseDefName = unitDef.corpse
	if FeatureDefNames[corpseDefName] then
		local corpseDefID = FeatureDefNames[corpseDefName].id
		local spawnSeconds = math.floor(unitDef.metalCost / adjustedRezSpeed)

		spawnSeconds = math.clamp(spawnSeconds, currentZombieConfig.rezMin, currentZombieConfig.rezMax)
		local spawnFrames = spawnSeconds * Game.gameSpeed
		zombieCorpseDefs[corpseDefID] = {unitDefID = unitDefID, spawnDelayFrames = spawnFrames}

		local zombieDefData = {}
		local deathExplosionName = unitDef.deathExplosion
		local explosionDefID = WeaponDefNames[deathExplosionName].id
		zombieDefData.explosionDefID = explosionDefID
		
		local heapDefName = FeatureDefs[corpseDefID].deathFeatureID
		if heapDefName then
			zombieDefData.heapDefID = heapDefName
		end

		zombieHeapDefs[unitDefID] = zombieDefData
	end
	
	extraDefs[unitDefID] =  {}
	if unitDef.speed > 0 then
		extraDefs[unitDefID].isMobile = true
	elseif unitDef.buildOptions and #unitDef.buildOptions > 0 then
		extraDefs[unitDefID].isFactory = true
	end
end

local function setGaiaStorage()
	local metalStorageToSet = 1000000
	local energyStorageToSet = 1000000

	local _, currentMetalStorage = Spring.GetTeamResources(gaiaTeamID, "metal")
	if currentMetalStorage and currentMetalStorage < metalStorageToSet then
		spSetTeamResource(gaiaTeamID, "ms", metalStorageToSet)
	end
	
	local _, currentEnergyStorage = Spring.GetTeamResources(gaiaTeamID, "energy")
	if currentEnergyStorage and currentEnergyStorage < energyStorageToSet then
		spSetTeamResource(gaiaTeamID, "es", energyStorageToSet)
	end
end

local function updateAdjustedRezSpeed()
	local techGuesstimateMultiplier = 2
	if GG.PowerLib and GG.PowerLib.HighestPlayerTeamPower and GG.PowerLib.TechGuesstimate then
		local highestPowerData = GG.PowerLib.HighestPlayerTeamPower()
		if highestPowerData and highestPowerData.power then
			adjustedRezSpeed = currentZombieConfig.rezSpeed * GG.PowerLib.TechGuesstimate(highestPowerData.power) * techGuesstimateMultiplier
		end
	end
end

local function applyZombieModeSettings(mode)
	local config = zombieModeConfigs[mode]
	if not config then
		config = zombieModeConfigs.normal -- fallback to normal
	end
	
	currentZombieMode = mode
	currentZombieConfig = config
	
	updateAdjustedRezSpeed()
end

local function calculateHealthRatio(featureID)
	local partialReclaimRatio = 1
	local damagedReductionRatio = 1
	local currentMetal, maxMetal = spGetFeatureResources(featureID)
	if currentMetal and maxMetal and currentMetal ~= 0 and maxMetal ~= 0 then
		partialReclaimRatio = currentMetal/maxMetal
	end
	local health, maxHealth = spGetFeatureHealth(featureID)
	if health and maxHealth and health ~= 0 and maxHealth ~= 0 then
		damagedReductionRatio = health/maxHealth
	end
	local healthRatio = (partialReclaimRatio + damagedReductionRatio) * 0.5 --average the two ratios to skew the result towards maximum health
	return healthRatio
end

--we use this instead of spGetUnitNearestAlly to make sure the unit is not guarding something on terrain it cannot traverse (like boats/land)
local function GetUnitNearestAlly(unitID, unitDefID, range)
	local bestAllyID
	local bestDistanceSquared
	local x, y, z = spGetUnitPosition(unitID)
	if not x or not z then
		return nil
	end
	local units = spGetUnitsInCylinder(x, z, range)
	for i = 1, #units do
		local allyID = units[i]
		local allyTeam = spGetUnitTeam(allyID)
		local allyDefID = spGetUnitDefID(allyID)
		if (allyID ~= unitID) and (allyTeam == gaiaTeamID) and UnitDefs[allyDefID].canAttack and spGetUnitCurrentCommand(allyID) ~= CMD_GUARD then
			local ox, oy, oz = spGetUnitPosition(allyID)
			if ox and oy and oz then
				local currentDistanceSquared = distance2dSquared(x, z, ox, oz)
				if spTestMoveOrder(unitDefID, ox, oy, oz) and ((bestDistanceSquared == nil) or (currentDistanceSquared < bestDistanceSquared)) then
					bestAllyID = allyID
					bestDistanceSquared = currentDistanceSquared
				end
			end
		end
	end
	return bestAllyID
end

local function issueRandomFactoryBuildOrders(unitID, unitDefID)
	local buildopts = UnitDefs[unitDefID].buildOptions
	if (not buildopts) or #buildopts <= 0 then
		return
	end
	local orders = {}
	for i = 1, ZOMBIE_ORDER_COUNT do
		orders[#orders + 1] = {-buildopts[random(1, #buildopts)], 0, 0 }
	end
	if (#orders > 0) then
		spGiveOrderArrayToUnit(unitID, orders)
	end
end

local function warningCEG(featureID, x, y, z)
	local radius = spGetFeatureRadius(featureID)

	local selectedEffect = warningEffects[random(#warningEffects)]
	spSpawnCEG(selectedEffect, x, y, z, 0, 0, 0, radius * 0.25)
	spSpawnCEG("scaspawn-trail", x, y, z, 0, 0, 0, radius)
end

local function playSpawnSound(x, y, z)
	local selectedEffect = spawnEffects[random(#spawnEffects)]
		spPlaySoundFile(selectedEffect, 0.5, x, y, z, 0)
end

local function issueRandomOrders(unitID, unitDefID)
	local unitDef = UnitDefs[unitDefID]
	
	local orders = {}
	local nearAlly = (unitDef.canAttack) and GetUnitNearestAlly(unitID, unitDefID, ZOMBIE_GUARD_RADIUS) or nil
	local isGuarding = false
	if nearAlly then
		if random() < ZOMBIE_GUARD_CHANCE then
			orders[#orders + 1] = {CMD_GUARD, {nearAlly}, 0}
			isGuarding = true
		end
	end
	if extraDefs[unitDefID].isMobile and not isGuarding then
		for i = 1, ZOMBIE_ORDER_COUNT do
			local randomX = random(0, mapWidth)
			local randomZ = random(0, mapHeight)
			local randomY = spGetGroundHeight(randomX, randomZ)

			if spTestMoveOrder(unitDefID, randomX, randomY, randomZ) then
				orders[#orders + 1] = {CMD_FIGHT, {randomX, randomY, randomZ}, CMD_OPT_SHIFT}
			end
		end
	elseif not extraDefs[unitDefID].isFactory then
		orders[#orders + 1] = {CMD_FIGHT, {0, 0, 0}, CMD_OPT_SHIFT} --immobile units only need a single fight order
	end

	if #orders > 0 then
		spGiveOrderArrayToUnit(unitID, orders)
	end

	if extraDefs[unitDefID].isFactory then
		issueRandomFactoryBuildOrders(unitID, unitDefID)
	end
end

local function resetSpawn(featureID, featureData, featureDefData)
	local newFrame = featureData.tamperedFrame + featureDefData.spawnDelayFrames
	featureData.spawnFrame = newFrame
	featureData.creationFrame = featureData.tamperedFrame
	featureData.tamperedFrame = nil
	corpseCheckFrames[newFrame] = corpseCheckFrames[newFrame] or {}
	corpseCheckFrames[newFrame][#corpseCheckFrames[newFrame] + 1] = featureID
end

local function getScavVariantUnitDefID(unitDefID)
	local unitDef = UnitDefs[unitDefID]
	if not unitDef then
		return unitDefID
	end
	
	if string.find(unitDef.name, "_scav") then
		return unitDefID
	end
	
	local scavUnitDefName = unitDef.name .. "_scav"
	local scavUnitDef = UnitDefNames[scavUnitDefName]
	return scavUnitDef and scavUnitDef.id or unitDefID
end

local function setZombieStates(unitID, unitDefID)
	local unitDef = UnitDefs[unitDefID]
	spGiveOrderToUnit(unitID, CMD_REPEAT, ENABLE_REPEAT, 0)
	spGiveOrderToUnit(unitID, CMD_MOVE_STATE, MOVE_STATE_ROAM, 0)
	if ordersEnabled then
		spGiveOrderToUnit(unitID, CMD_FIRE_STATE, FIRE_STATE_FIRE_AT_WILL, 0)
	else
		spGiveOrderToUnit(unitID, CMD_FIRE_STATE, FIRE_STATE_RETURN_FIRE, 0)
	end
end

local function spawnZombies(featureID, unitDefID, healthReductionRatio, x, y, z)
	local unitDef = UnitDefs[unitDefID]
	local spawnCount = 1
	if extraDefs[unitDefID].isMobile then
		spawnCount = math.floor((random(currentZombieConfig.countMin, currentZombieConfig.countMax) + random(currentZombieConfig.countMin, currentZombieConfig.countMax)) / 2) --skew results towards average to produce better gameplay
	end
	local size = unitDef.xsize

	spDestroyFeature(featureID)
	corpsesData[featureID] = nil
	playSpawnSound(x, y, z)

	for i = 1, spawnCount do
		local randomX = x + random(-size * spawnCount, size * spawnCount)
		local randomZ = z + random(-size * spawnCount, size * spawnCount)
		local adjustedY = spGetGroundHeight(randomX, randomZ)

		local unitToCreate = getScavVariantUnitDefID(unitDefID)
		local unitID = spCreateUnit(unitToCreate, randomX, adjustedY, randomZ, 0, gaiaTeamID)
		if unitID then
			local size = math.ceil((unitDef.xsize / 2 + unitDef.zsize / 2) / 2)
			local sizeName = "small"
			if size > 4.5 then
				sizeName = "huge"
			elseif size > 3.5 then
				sizeName = "large"
			elseif size > 2.5 then
				sizeName = "medium"
			elseif size > 1.5 then
				sizeName = "small"
			else
				sizeName = "tiny"
			end
			spSpawnCEG("scav-spawnexplo-" .. sizeName, randomX, adjustedY, randomZ, 0, 0, 0)
			if modOptions.zombies ~= "normal" then
				spSetUnitExperience(unitID, (random() * ZOMBIE_MAX_XP + random() * ZOMBIE_MAX_XP) / 2) -- to skew the experience towards the median
			end
			local unitHealth = spGetUnitHealth(unitID)
			spSetUnitHealth(unitID, unitHealth * healthReductionRatio)
			spSetUnitRulesParam(unitID, "zombie", 1)
			if scavTeamID then
				spTransferUnit(unitID, scavTeamID)
			else
				zombieWatch[unitID] = unitToCreate
				if ordersEnabled then
					issueRandomOrders(unitID, unitToCreate)
				end
				setZombieStates(unitID, unitToCreate)
			end
		end
	end
end

local function setZombie(unitID)
	local unitDefID = spGetUnitDefID(unitID)
	if not unitDefID then
		return
	end
	
	local scavUnitDefID = getScavVariantUnitDefID(unitDefID)
	
	-- If we need to convert to _scav variant
	if scavUnitDefID ~= unitDefID then
		local x, y, z = spGetUnitPosition(unitID)
		local facing = Spring.GetUnitDirection(unitID) or 0
		local teamID = spGetUnitTeam(unitID)
		
		local newUnitID = spCreateUnit(scavUnitDefID, x or 0, y or 0, z or 0, facing or 0, teamID)
		if newUnitID then
			local health, maxHealth = spGetUnitHealth(unitID)
			if health and maxHealth then
				spSetUnitHealth(newUnitID, health / maxHealth)
			end
			local experience = Spring.GetUnitExperience(unitID)
			spSetUnitExperience(newUnitID, experience)
			
			spDestroyUnit(unitID, false, true)
			
			unitID = newUnitID
			unitDefID = scavUnitDefID
		end
	end
	
	spSetUnitRulesParam(unitID, "zombie", 1)
	zombieWatch[unitID] = unitDefID
	setZombieStates(unitID, unitDefID)
end

function gadget:AllowFeatureBuildStep(builderID, builderTeam, featureID, featureDefID, part)
	local featureData = corpsesData[featureID]
	if featureData then
		featureData.tamperedFrame = gameFrame
	end
	return true
end

function gadget:GameFrame(frame)
	gameFrame = frame

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
				local featureData = corpsesData[featureID]
				local featureDefData = zombieCorpseDefs[featureData.featureDefID]
				if featureData.tamperedFrame then
					resetSpawn(featureID, featureData, featureDefData)
				else
					local healthReductionRatio = calculateHealthRatio(featureID)
					spawnZombies(featureID, featureDefData.unitDefID, healthReductionRatio, featureX, featureY, featureZ)
				end
			end
			corpseCheckFrames[frame] = nil
		end
	end

	if frame % ZOMBIE_CHECK_INTERVAL == 0 then
		Spring.AddTeamResource(gaiaTeamID, "metal", 1000000)
		Spring.AddTeamResource(gaiaTeamID, "energy", 1000000)
		for featureID, featureData in pairs(corpsesData) do
			local featureX, featureY, featureZ = spGetFeaturePosition(featureID)
			if not featureX then --doesn't exist anymore
				corpsesData[featureID] = nil
			elseif featureData.spawnFrame - frame < WARNING_TIME then
				warningCEG(featureID, featureX, featureY, featureZ)
			end
		end
	end

	--check if any zombies need new orders
	if frame % ZOMBIE_ORDER_CHECK_INTERVAL == 1 then
		for unitID, unitDefID in pairs(zombieWatch) do
			if spGetUnitIsDead(unitID) then
				zombieWatch[unitID] = nil
			else
				local queueSize = spGetUnitCommandCount(unitID)
				if not (queueSize) or (queueSize == 0) and spGetUnitTeam(unitID) == gaiaTeamID then
					if ordersEnabled then
						issueRandomOrders(unitID, unitDefID)
					end
				end
			end
		end
		updateAdjustedRezSpeed()
	end
end

local function queueCorpseForSpawning(featureID, override)
	if not override and not autoSpawningEnabled then
		return
	end
	
	local featureDefID = spGetFeatureDefID(featureID)
	if zombieCorpseDefs[featureDefID] then
		local spawnDelayFrames = zombieCorpseDefs[featureDefID].spawnDelayFrames
		local spawnFrame = gameFrame + spawnDelayFrames
		corpsesData[featureID] = {featureDefID = featureDefID, spawnDelayFrames = spawnDelayFrames, creationFrame = gameFrame, spawnFrame = spawnFrame}
		corpseCheckFrames[spawnFrame] = corpseCheckFrames[spawnFrame] or {}
		corpseCheckFrames[spawnFrame][#corpseCheckFrames[spawnFrame] + 1] = featureID
	end
end

function gadget:FeatureCreated(featureID, allyTeam)
	queueCorpseForSpawning(featureID, false)
end

function gadget:FeatureDestroyed(featureID, allyTeam)
	corpsesData[featureID] = nil
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if unitTeam == gaiaTeamID then
		local identifiedZombie = spGetUnitRulesParam(unitID, "zombie")
		if identifiedZombie then
			zombieWatch[unitID] = unitDefID
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	zombieWatch[unitID] = nil
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID)
	if zombieWatch[unitID] then
		local health = spGetUnitHealth(unitID)
		if damage >= health then
			local unitX, unitY, unitZ = spGetUnitPosition(unitID)
			if unitX and unitY and unitZ then
				local defData = zombieHeapDefs[unitDefID]
				spDestroyUnit(unitID, false, true, attackerID)
				spSpawnExplosion(unitX, unitY, unitZ, 0, 0, 0, {weaponDef = defData.explosionDefID, owner = attackerID, hitUnit = unitID, hitFeature = -1, craterAreaOfEffect = 0, damageAreaOfEffect = 0, edgeEffectiveness = 0, explosionSpeed = 0, gfxMod = 0, impactOnly = false, ignoreOwner = false, damageGround = true} )
				if defData.heapDefID then
					spCreateFeature(defData.heapDefID, unitX, unitY, unitZ)
				end
			end
		end
	end
end

local function createZombieFromFeature(featureID)
	if isIdleMode then
		local featureDefID = spGetFeatureDefID(featureID)
		if zombieCorpseDefs[featureDefID] then
			local featureX, featureY, featureZ = spGetFeaturePosition(featureID)
			if featureX then
				local featureDefData = zombieCorpseDefs[featureDefID]
				local healthReductionRatio = calculateHealthRatio(featureID)
				spawnZombies(featureID, featureDefData.unitDefID, healthReductionRatio, featureX, featureY, featureZ)
				return true
			end
		end
	end
	return false
end

local function queueAllCorpsesForSpawning()
	local features = Spring.GetAllFeatures()
	for _, featureID in ipairs(features) do
		queueCorpseForSpawning(featureID, true)
	end
end

local function clearOrders()
	for zombieID, _ in pairs(zombieWatch) do
		if Spring.ValidUnitID(zombieID) then
			local currentCommand = Spring.GetUnitCurrentCommand(zombieID)
			if currentCommand ~= CMD_GUARD then
				Spring.GiveOrderToUnit(zombieID, CMD.STOP, {}, {})
			end
		end
	end
end

local function pacifyZombies(enabled)
	if enabled then
		ordersEnabled = false
		clearOrders()
		for zombieID, _ in pairs(zombieWatch) do
			if Spring.ValidUnitID(zombieID) then
				Spring.GiveOrderToUnit(zombieID, CMD.FIRE_STATE, {FIRE_STATE_RETURN_FIRE}, {})
			end
		end
	else
		ordersEnabled = true
		for zombieID, _ in pairs(zombieWatch) do
			if Spring.ValidUnitID(zombieID) then
				Spring.GiveOrderToUnit(zombieID, CMD.FIRE_STATE, {FIRE_STATE_FIRE_AT_WILL}, {})
			end
		end
	end
end

local function fightNearTargets(targetUnits)
	if not targetUnits or #targetUnits == 0 then return false end
	
	for zombieID, _ in pairs(zombieWatch) do
		if Spring.ValidUnitID(zombieID) then
			local randomTarget = targetUnits[math.random(1, #targetUnits)]
			if Spring.ValidUnitID(randomTarget) then
				local targetX, targetY, targetZ = Spring.GetUnitPosition(randomTarget)
				if targetX then
					local angle = math.random() * 2 * math.pi
					local offsetDistance = math.random(25, 500)
					local fightX = targetX + math.cos(angle) * offsetDistance
					local fightZ = targetZ + math.sin(angle) * offsetDistance
					local fightY = Spring.GetGroundHeight(fightX, fightZ)
					
					Spring.GiveOrderToUnit(zombieID, CMD.FIGHT, {fightX, fightY, fightZ}, {})
				end
			end
		end
	end
	
	return true
end

local function aggroTeamID(teamID)
	clearOrders()
	
	local isDead = select(3, Spring.GetTeamInfo(teamID))

	if isDead or isDead == nil then
		return false
	end
	
	local targetUnits = Spring.GetTeamUnits(teamID)
	return fightNearTargets(targetUnits)
end

local function aggroAllyID(allyID)
	clearOrders()
	
	local targetUnits = {}
	local allyTeams = Spring.GetTeamList(allyID)

	if not allyTeams then
		return false
	end

	for _, teamID in pairs(allyTeams) do
		local unitsToAdd = Spring.GetTeamUnits(teamID)
		for _, unitID in pairs(unitsToAdd) do
			table.insert(targetUnits, unitID)
		end
	end
		
	return fightNearTargets(targetUnits)
end

local function killAllZombies()
	for zombieID, zombieData in pairs(zombieWatch) do
		if Spring.ValidUnitID(zombieID) and not Spring.GetUnitIsDead(zombieID) then
			local currentHealth = Spring.GetUnitHealth(zombieID)
			if currentHealth and currentHealth > 0 then
				Spring.AddUnitDamage(zombieID, currentHealth, 0, -1, 0)
			end
		end
	end
end


local function setAutoSpawning(enabled)
	autoSpawningEnabled = enabled
	if enabled then
		queueAllCorpsesForSpawning()
	end
end

local function clearAllZombieSpawns()
	corpsesData = {}
	corpseCheckFrames = {}
end

local function isAuthorized(playerID)
	if Spring.IsCheatingEnabled() then
		return true
	else
		local playername,_,_,_,_,_,_,_,_,_,accountInfo = Spring.GetPlayerInfo(playerID)
		local accountID = (accountInfo and accountInfo.accountid) and tonumber(accountInfo.accountid) or -1
		if (_G and _G.permissions.devhelpers[accountID]) or (SYNCED and SYNCED.permissions.devhelpers[accountID]) then
			return true
		end
	end
	return false
end

local function handleConsoleCommand(playerID, commandName, requiredArgs, actionFunction)
	if not isAuthorized(playerID) then
		Spring.SendMessageToPlayer(playerID, "You are not authorized to use zombie commands")
		return
	end
	
	if requiredArgs and #requiredArgs == 0 then
		Spring.SendMessageToPlayer(playerID, "Usage: /luarules " .. commandName .. " " .. table.concat(requiredArgs, " "))
		return
	end
	
	return actionFunction(playerID, requiredArgs, true) -- true = send messages
end

local function convertUnitsToZombies(unitIDs)
	if not unitIDs or #unitIDs == 0 then
		return 0
	end
	
	local convertedCount = 0
	for _, unitID in ipairs(unitIDs) do
		if Spring.ValidUnitID(unitID) then
			GG.Zombies.SetZombie(unitID)
			convertedCount = convertedCount + 1
		end
	end
	
	return convertedCount
end

local function setAllGaiaToZombies()
	local allUnits = Spring.GetAllUnits()
	local convertedCount = 0
	
	for _, unitID in ipairs(allUnits) do
		local unitTeam = Spring.GetUnitTeam(unitID)
		if unitTeam == gaiaTeamID then
			GG.Zombies.SetZombie(unitID)
			convertedCount = convertedCount + 1
		end
	end
	
	return convertedCount
end


local function commandSetAllGaiaToZombies(_, line, words, playerID)
	return handleConsoleCommand(playerID, "zombiesetallgaia", nil, function(playerID, args, sendMessage)
		local convertedCount = GG.Zombies.SetAllGaiaToZombies()
		if sendMessage or debugMode then
			Spring.SendMessageToPlayer(playerID, "Set " .. convertedCount .. " Gaia units as zombies")
		end
	end)
end

local function commandQueueAllCorpsesForReanimation(_, line, words, playerID)
	return handleConsoleCommand(playerID, "zombiequeueall", nil, function(playerID, args, sendMessage)
		GG.Zombies.QueueAllCorpsesForSpawning()
		if sendMessage or debugMode then
			Spring.SendMessageToPlayer(playerID, "Queued all corpses for spawning")
		end
	end)
end

local function commandToggleAutoReanimation(_, line, words, playerID)
	return handleConsoleCommand(playerID, "zombieautospawn", words, function(playerID, args, sendMessage)
		if not args[1] then
			if sendMessage or debugMode then
				Spring.SendMessageToPlayer(playerID, "Usage: /luarules zombieautospawning 0 or 1")
			end
			return
		end
		
		local enabled = tonumber(args[1])
		if enabled == nil or (enabled ~= 0 and enabled ~= 1) then
			if sendMessage or debugMode then
				Spring.SendMessageToPlayer(playerID, "Invalid value. Use 0 to disable or 1 to enable")
			end
			return
		end
		
		GG.Zombies.SetAutoSpawning(enabled == 1)
		if sendMessage or debugMode then
			Spring.SendMessageToPlayer(playerID, "Auto spawning " .. (enabled == 1 and "enabled" or "disabled"))
		end
	end)
end

local function commandPacifyZombies(_, line, words, playerID)
	return handleConsoleCommand(playerID, "zombiepacify", words, function(playerID, args, sendMessage)
		if not args[1] then
			if sendMessage or debugMode then
				Spring.SendMessageToPlayer(playerID, "Usage: /luarules zombiepacify 0 or 1")
			end
			return
		end
		
		local enabled = tonumber(args[1])
		if enabled == nil or (enabled ~= 0 and enabled ~= 1) then
			if sendMessage or debugMode then
				Spring.SendMessageToPlayer(playerID, "Invalid value. Use 0 to disable or 1 to enable")
			end
			return
		end
		
		GG.Zombies.PacifyZombies(enabled == 1)
		if sendMessage or debugMode then
			Spring.SendMessageToPlayer(playerID, "Zombies " .. (enabled == 1 and "pacified" or "unpacified"))
		end
	end)
end

local function commandAggroZombiesToTeam(_, line, words, playerID)
	return handleConsoleCommand(playerID, "zombieaggroteam", words, function(playerID, args, sendMessage)
		if not args[1] then
			if sendMessage or debugMode then
				Spring.SendMessageToPlayer(playerID, "Usage: /luarules zombieaggroteam teamID")
			end
			return
		end
		
		local targetTeamID = tonumber(args[1])
		if not targetTeamID or targetTeamID < 0 then
			if sendMessage or debugMode then
				Spring.SendMessageToPlayer(playerID, "Invalid team ID")
			end
			return
		end
		
		local success = GG.Zombies.AggroTeamID(targetTeamID)
		if sendMessage or debugMode then
			if success then
				Spring.SendMessageToPlayer(playerID, "Zombies aggroed to team " .. targetTeamID)
			else
				Spring.SendMessageToPlayer(playerID, "Team " .. targetTeamID .. " not found or has no units")
			end
		end
	end)
end

local function commandAggroZombiesToAlly(_, line, words, playerID)
	return handleConsoleCommand(playerID, "zombieaggroally", words, function(playerID, args, sendMessage)
		if not args[1] then
			if sendMessage or debugMode then
				Spring.SendMessageToPlayer(playerID, "Usage: /luarules zombieaggroally <allyID>")
			end
			return
		end
		
		local targetAllyID = tonumber(args[1])
		if not targetAllyID or targetAllyID < 0 then
			if sendMessage or debugMode then
				Spring.SendMessageToPlayer(playerID, "Invalid ally ID")
			end
			return
		end
		
		local success = aggroAllyID(targetAllyID)
		if sendMessage or debugMode then
			if success then
				Spring.SendMessageToPlayer(playerID, "Zombies aggroed to ally team " .. targetAllyID)
			else
				Spring.SendMessageToPlayer(playerID, "Ally team " .. targetAllyID .. " not found or has no units")
			end
		end
	end)
end

local function commandKillAllZombies(_, line, words, playerID)
	return handleConsoleCommand(playerID, "zombiekillall", nil, function(playerID, args, sendMessage)
		GG.Zombies.KillAllZombies()
		if sendMessage or debugMode then
			Spring.SendMessageToPlayer(playerID, "Killed all zombies")
		end
	end)
end

local function commandClearZombieOrders(_, line, words, playerID)
	return handleConsoleCommand(playerID, "zombieclearorders", nil, function(playerID, args, sendMessage)
		GG.Zombies.ClearOrders()
		if sendMessage or debugMode then
			Spring.SendMessageToPlayer(playerID, "Cleared zombie orders")
		end
	end)
end

local function commandClearZombieSpawns(_, line, words, playerID)
	return handleConsoleCommand(playerID, "zombieclearspawns", nil, function(playerID, args, sendMessage)
		GG.Zombies.ClearAllZombieSpawns()
		if sendMessage or debugMode then
			Spring.SendMessageToPlayer(playerID, "Cleared all queued zombie spawns")
		end
	end)
end

local function commandToggleDebugMode(_, line, words, playerID)
	return handleConsoleCommand(playerID, "zombiedebug", words, function(playerID, args, sendMessage)
		if not args[1] then
			if sendMessage or debugMode then
				Spring.SendMessageToPlayer(playerID, "Usage: /luarules zombiedebug 0 or 1")
			end
			return
		end
		
		local enabled = tonumber(args[1])
		if enabled == nil or (enabled ~= 0 and enabled ~= 1) then
			if sendMessage or debugMode then
				Spring.SendMessageToPlayer(playerID, "Invalid value. Use 0 to disable or 1 to enable")
			end
			return
		end
		
		debugMode = enabled == 1
		if sendMessage or debugMode then
			Spring.SendMessageToPlayer(playerID, "Zombie debug mode " .. (debugMode and "enabled" or "disabled"))
		end
	end)
end

local function setZombieMode(mode)
	if mode ~= "normal" and mode ~= "hard" and mode ~= "nightmare" and mode ~= "extreme" then
		return false
	end
	
	currentZombieMode = mode
	applyZombieModeSettings(mode)
	return true
end

local function commandSetZombieMode(_, line, words, playerID)
	return handleConsoleCommand(playerID, "zombiemode", words, function(playerID, args, sendMessage)
		if not args[1] then
			if sendMessage or debugMode then
				Spring.SendMessageToPlayer(playerID, "Usage: /luarules zombiemode normal or hard or nightmare or extreme")
			end
			return
		end
		
		local mode = string.lower(args[1])
		if mode ~= "normal" and mode ~= "hard" and mode ~= "nightmare" and mode ~= "extreme" then
			if sendMessage or debugMode then
				Spring.SendMessageToPlayer(playerID, "Invalid mode. Use: normal, hard, nightmare, or extreme")
			end
			return
		end
		
		local success = GG.Zombies.SetZombieMode(mode)
		if sendMessage or debugMode then
			if success then
				Spring.SendMessageToPlayer(playerID, "Zombie mode set to " .. mode)
			else
				Spring.SendMessageToPlayer(playerID, "Failed to set zombie mode to " .. mode)
			end
		end
	end)
end

function gadget:Initialize()
	local modOptionEnabled = modOptions.zombies ~= "disabled"
	isIdleMode = modOptions.seasonal_surprise == true or (GG.Zombies and GG.Zombies.IdleMode == true) or false

	if not modOptionEnabled and not isIdleMode then
		gadgetHandler:RemoveGadget(gadget)
		return
	end
	
	local initialMode = modOptions.zombies or "normal"
	applyZombieModeSettings(initialMode)
	
	autoSpawningEnabled = modOptionEnabled and not isIdleMode
	
	mapWidth = Game.mapSizeX
	mapHeight = Game.mapSizeZ
	gameFrame = spGetGameFrame()

	local units = spGetAllUnits()
	for _, unitID in ipairs(units) do
		local rulesParam = spGetUnitRulesParam(unitID, "zombie")
		local identifiedZombie = rulesParam and rulesParam == 1
		if identifiedZombie then
			setZombie(unitID)
		end
	end
	
	if not isIdleMode then
		local features = spGetAllFeatures()
		for _, featureID in ipairs(features) do
			gadget:FeatureCreated(featureID, gaiaTeamID)
		end
	end

	GG.Zombies = {}
	GG.Zombies.SetZombie = setZombie
	GG.Zombies.ConvertUnitsToZombies = convertUnitsToZombies
	GG.Zombies.SetAllGaiaToZombies = setAllGaiaToZombies
	GG.Zombies.CreateZombieFromFeature = createZombieFromFeature
	GG.Zombies.QueueAllCorpsesForSpawning = queueAllCorpsesForSpawning
	GG.Zombies.SetAutoSpawning = setAutoSpawning
	GG.Zombies.ClearAllZombieSpawns = clearAllZombieSpawns
	GG.Zombies.PacifyZombies = pacifyZombies
	GG.Zombies.AggroTeamID = aggroTeamID
	GG.Zombies.AggroAllyID = aggroAllyID
	GG.Zombies.KillAllZombies = killAllZombies
	GG.Zombies.ClearOrders = clearOrders
	GG.Zombies.SetZombieMode = setZombieMode
	GG.Zombies.GetZombieMode = function() return currentZombieMode end
	
	gadgetHandler:AddChatAction('zombiesetallgaia', commandSetAllGaiaToZombies, "Set all Gaia units as zombies")
	gadgetHandler:AddChatAction('zombiequeueallcorpses', commandQueueAllCorpsesForReanimation, "Queue all corpses for spawning")
	gadgetHandler:AddChatAction('zombieautospawning', commandToggleAutoReanimation, "Enable/disable auto spawning")
	gadgetHandler:AddChatAction('zombieclearspawns', commandClearZombieSpawns, "Clear all queued zombie spawns")
	gadgetHandler:AddChatAction('zombiepacify', commandPacifyZombies, "Pacify/unpacify zombies")
	gadgetHandler:AddChatAction('zombieaggroteam', commandAggroZombiesToTeam, "Make zombies aggro to specific team")
	gadgetHandler:AddChatAction('zombieaggroally', commandAggroZombiesToAlly, "Make zombies aggro to entire ally team")
	gadgetHandler:AddChatAction('zombiekillall', commandKillAllZombies, "Kill all zombies")
	gadgetHandler:AddChatAction('zombieclearorders', commandClearZombieOrders, "Clear zombie orders")
	gadgetHandler:AddChatAction('zombiedebug', commandToggleDebugMode, "Enable/disable debug mode")
	gadgetHandler:AddChatAction('zombiemode', commandSetZombieMode, "Set zombie mode (normal/hard/nightmare/extreme)")
end

function gadget:Shutdown()
	gadgetHandler:RemoveChatAction('zombiesetallgaia')
	gadgetHandler:RemoveChatAction('zombiequeueallcorpses')
	gadgetHandler:RemoveChatAction('zombieautospawning')
	gadgetHandler:RemoveChatAction('zombieclearspawns')
	gadgetHandler:RemoveChatAction('zombiepacify')
	gadgetHandler:RemoveChatAction('zombieaggroplayer')
	gadgetHandler:RemoveChatAction('zombieaggroteam')
	gadgetHandler:RemoveChatAction('zombieaggroally')
	gadgetHandler:RemoveChatAction('zombiekillall')
	gadgetHandler:RemoveChatAction('zombieclearorders')
	gadgetHandler:RemoveChatAction('zombiedebug')
	gadgetHandler:RemoveChatAction('zombiemode')
end

function gadget:GameStart()
	setGaiaStorage()
end