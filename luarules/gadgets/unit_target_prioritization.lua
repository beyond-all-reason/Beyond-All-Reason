local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "weapon prioritization",
		desc = "weapon prioritization gadget",
		author = "SethDGamre",
		date = "2025.7.18",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

--[[
TODO:
-- need to ensure armored units are accounted for in their armored state

Spring.GetProjectileTarget ( number projectileID )
return: nil | number targetTypeInt, number targetID | table targetPos = {x, y, z}


Spring.GetUnitWeaponDamages ( number unitID, number weaponNum | string "selfDestruct" | string "explode", string tag )
return: nil | number tagVariable

String argument "tag" can return a specific variable. Possible tags are:
  "paralyzeDamageTime"
  "impulseFactor"
  "impulseBoost"
  "craterMult"
  "craterBoost"
  "dynDamageExp"
  "dynDamageMin"
  "dynDamageRange"
  "dynDamageInverted"
  "craterAreaOfEffect"
  "damageAreaOfEffect"
  "edgeEffectiveness"
  "explosionSpeed"
  - or -
  an armor type index to get the damage against it.
]]



if not gadgetHandler:IsSyncedCode() then return end

-- CONSTANTS
local CYCLE_FRAMES = Game.gameSpeed

local PROJECTILE_TARGET_TYPE_GROUND = string.byte('g')      -- 103
local PROJECTILE_TARGET_TYPE_UNIT = string.byte('u')        -- 117  
local PROJECTILE_TARGET_TYPE_FEATURE = string.byte('f')     -- 102
local PROJECTILE_TARGET_TYPE_PROJECTILE = string.byte('p')  -- 112

local WEAPON_TARGET_TYPE_UNIT = 1

-- Armor type constants
local ARMOR_TYPE_DEFAULT = Game.armorTypes.default or 0

-- Movement constants
local IS_MOVING_THRESHOLD = 0.5

---configables
local DOOM_DECAY_PERCENTAGE = 0.01 -- the speed at which doom (virtual health) decays as a percentage per second.

local SlOW_PROJECTILE_FRAMES = 10 -- For each multiple of this threshold, CERTAINTY_PROJECTILE_SLOWNESS_PENALTY_MULTIPLIER is multiplied.

--certainty constants
local CERTAINTY_PROJECTILE_SLOWNESS_PENALTY_MULTIPLIER = 0.9 -- the multiplier for the projectile's speed to determine the certainty of overkill prevention.
local ACCURACY_PENALTY_CALC_RANGE = 300 -- weapons with range below this are pre-calculated and not calculated dynamically to save performance
local PERFECT_CERTAINTY = 1.0
-- variables
local gameFrame = 0

local slowProjectileDefs = {}
local unitWatch = {}
local projectileWatch = {}
local precalculatedCertainties = {}
local weaponDefDibsSteps = {}
local doomedUnits = {}
local unitDefCache = {}
local weaponDefs = WeaponDefs -- localized for faster performance
local weaponDefDPSCache = {}

local dibsSteps = { --musn't be more than 30 steps. This is the order in which units are given "dibs" on target selection in order of reloadtime.
	[1] = 0.5,
	[2] = 1,
	[3] = 2,
	[4] = 4,
	[5] = 8
}


local weaponTypeCertaintyPenalties = { -- the smaller the number, the less certain the weapon will deal its full damage.
	AircraftBomb = 0.8,
	BeamLaser = 1.0,
	Cannon = 0.95,
	Dgun = 1.0,
	EmgCannon = 1.0,
	Flame = 1.0,
	LaserCannon = 1.0,
	LightningCanon = 1.0,
	Melee = 1.0,
	MissileLauncher = 0.95,
	Rifle = 1.0,
	StarburstLauncher = 0.95,
	TorpedoLauncher = 1,
}

local projectileWeaponTypes = {
	AircraftBomb = true,
	Cannon = true,
	Dgun = true,
	EmgCannon = true,
	Flame = true,
	LaserCannon = true,
	MissileLauncher = true,
	StarburstLauncher = true,
	StarburstMissiles = true,
	TorpedoLauncher = true,
}

local ignoredWeaponTypes = {
	Shield = true
}

--functions
local spGetUnitIsDead = Spring.GetUnitIsDead
local spValidUnitID = Spring.ValidUnitID
local spAddUnitDamage = Spring.AddUnitDamage
local spGetUnitVelocity = Spring.GetUnitVelocity
local spGetUnitBasePosition = Spring.GetUnitBasePosition
local spGetUnitPosition = Spring.GetUnitPosition
local spSpawnCEG = Spring.SpawnCEG
local spPlaySoundFile = Spring.PlaySoundFile
local spTestMoveOrder = Spring.TestMoveOrder
local spGetUnitHealth = Spring.GetUnitHealth
local spDestroyUnit = Spring.DestroyUnit
local spGetProjectileTarget = Spring.GetProjectileTarget
local spGetUnitWeaponTarget = Spring.GetUnitWeaponTarget
local spGetUnitWeaponState = Spring.GetUnitWeaponState

local mathSqrt = math.sqrt
local mathMax = math.max
local mathMin = math.min

--functions

local function projectileSpeedIsSlowerThanACycle(range, velocity)
	local distanceTraveledInOneSecond = velocity * CYCLE_FRAMES
	if distanceTraveledInOneSecond >= range then
		return distanceTraveledInOneSecond / range
	else
		return false
	end
end

local function calculateProjectileTravelFrames(weaponDefID, range)
	local weaponDef = WeaponDefs[weaponDefID]
	local initialVelocity = weaponDef.startvelocity
	local maximumVelocity = weaponDef.projectilespeed
	local accelerationRate = weaponDef.weaponAcceleration
	local totalDistance = range or weaponDef.range

	local totalFrames = 0

	-- Handle weapons with no acceleration (constant velocity)
	if accelerationRate <= 0 then
		totalFrames = totalDistance / maximumVelocity
	else
		-- Frames to reach maximum velocity
		local framesToMaxVelocity = (maximumVelocity - initialVelocity) / accelerationRate

		-- Distance traveled while accelerating
		local distanceAccelerating = initialVelocity * framesToMaxVelocity + 0.5 * accelerationRate * framesToMaxVelocity^2

		if distanceAccelerating > totalDistance then
			-- We already traveled too much, so just calculate time with accelerated movement + quadratic equation formula
			totalFrames = (mathSqrt(initialVelocity^2 + 2 * totalDistance * accelerationRate) - initialVelocity) / accelerationRate
		else
			-- Linear movement after accelerating
			totalFrames = framesToMaxVelocity + (totalDistance - distanceAccelerating) / maximumVelocity
		end
	end

	if weaponDef.type == "StarburstMissiles" then
		totalFrames = totalFrames - math.floor(math.rad(90) / weaponDef.turnRate) -- subtract the time it takes to turn at the top of ascent only for starburst missiles
	end

	return math.floor(totalFrames)
end

local function getProjectileSlownessCertainty(weaponDefID, range)
	local travelFrames = calculateProjectileTravelFrames(weaponDefID, range)
	if travelFrames > SlOW_PROJECTILE_FRAMES then
		return CERTAINTY_PROJECTILE_SLOWNESS_PENALTY_MULTIPLIER ^ (travelFrames / SlOW_PROJECTILE_FRAMES)
	end
	return PERFECT_CERTAINTY
end

local function getAccuracyCertainty(weaponDefID, range, targetRadius) --range and targetRadius are optional parameters, if not provided, they will be calculated from the weaponDef
	if not range then range = weaponDefs[weaponDefID].range end
	if not targetRadius then targetRadius = 22 end -- default to the collision volume of the armpw aka pawn
	local weaponDef = weaponDefs[weaponDefID]
	local aoe = weaponDef.damageAreaOfEffect
	local minAOE = 10
	aoe = mathMax(aoe, minAOE)
	
	local edgeEffectiveness = weaponDef.edgeEffectiveness or 0.15
	local edgeDenominator = (1 - 0.5 * edgeEffectiveness)
	if edgeDenominator <= 0 then
		return PERFECT_CERTAINTY -- Edge case: if edgeEffectiveness >= 2.0, assume perfect certainty
	end
	local radius50PercentDamage = (0.5 * aoe) / edgeDenominator
	
	local maximumRange = weaponDef.range
	if maximumRange <= 0 then
		return PERFECT_CERTAINTY -- Edge case: if weapon has no range, assume perfect certainty
	end
	local accuracyFactor = weaponDef.accuracy or 0
	local sprayAngle = weaponDef.sprayAngle or 0
	local accuracyRadius = range * (accuracyFactor + sprayAngle)
	
	local certainty
	if accuracyRadius <= 0 then
		certainty = PERFECT_CERTAINTY
	else
		local effectiveRadius = mathMax(targetRadius, radius50PercentDamage)
		certainty = mathMin(1.0, (effectiveRadius * effectiveRadius) / (accuracyRadius * accuracyRadius))
	end
	return certainty
end


local function calculateWeaponCertainties(weaponDefID)
	local weaponDef = WeaponDefs[weaponDefID]
	local certainties = {
		accuracy = PERFECT_CERTAINTY,
		movingTarget = PERFECT_CERTAINTY,
	}

	if weaponDef.tracking then
		certainties.accuracy = PERFECT_CERTAINTY
		certainties.movingTarget = PERFECT_CERTAINTY
		return
	end

	certainties.accuracy = getAccuracyCertainty(weaponDefID)

	certainties.movingTarget = getProjectileSlownessCertainty(weaponDefID) * certainties.accuracy

	if weaponTypeCertaintyPenalties[weaponDef.type] then
		certainties.accuracy = certainties.accuracy * weaponTypeCertaintyPenalties[weaponDef.type]
	end
	
	if weaponTypeCertaintyPenalties[weaponDef.type] then
		local typePenalty = weaponTypeCertaintyPenalties[weaponDef.type]
		certainties.accuracy = certainties.accuracy * typePenalty
		certainties.movingTarget = certainties.movingTarget * typePenalty
	end

	if weaponDef.customParams.certainty_override_accuracy then
		certainties.accuracy = weaponDef.customParams.certainty_override_accuracy
	end
	if weaponDef.customParams.certainty_override_moving_target then
		certainties.movingTarget = weaponDef.customParams.certainty_override_moving_target
	end
	precalculatedCertainties[weaponDefID] = certainties
end

local function calculateWeaponDibsPriority(weaponDefID)
	local weaponDef = WeaponDefs[weaponDefID]
	local reloadTime = weaponDef.reload
	local dibsStep = 1 -- needs to be something for error handling
	for i, step in ipairs(dibsSteps) do
		if reloadTime <= step then
			dibsStep = i
			break
		end
	end
	weaponDefDibsSteps[weaponDefID] = dibsStep
end

local function calculateWeaponDoomages(weaponDefID)
	local weaponDef = WeaponDefs[weaponDefID]
	if not weaponDef.damages then
		return
	end
	
	weaponDefDPSCache[weaponDefID] = {}
	
	local reloadTime = weaponDef.reload or 1
	local salvoSize = weaponDef.salvoSize or 1
	local projectiles = weaponDef.projectiles or 1
	
	-- Calculate total damage per salvo
	local damagePerSalvo = salvoSize * projectiles
	
	-- Determine if we use DPS (fast weapons) or single damage (slow weapons)
	local useDPS = reloadTime <= CYCLE_FRAMES
	
	-- Populate doomage for each armor type
	for armorType = 0, #Game.armorTypes do
		local baseDamage = weaponDef.damages[armorType] or weaponDef.damages[ARMOR_TYPE_DEFAULT] or 0
		local totalDamage = baseDamage * damagePerSalvo
		
		local doomage
		if useDPS then
			-- Fast weapon: calculate DPS (damage per cycle)
			doomage = totalDamage * (CYCLE_FRAMES / reloadTime)
		else
			-- Slow weapon: use single instance damage
			doomage = totalDamage
		end
		
		weaponDefDPSCache[weaponDefID][armorType] = doomage
	end
end

local function isWeaponAvailableToFire(unitID, weaponNum)
	local reloadState = spGetUnitWeaponState(unitID, weaponNum)
	if not reloadState then
		return false  -- Invalid weapon or unit
	end
	return reloadState <= CYCLE_FRAMES
end

local function isUnitMoving(unitID)
	local velocity = select(4, spGetUnitVelocity(unitID))
	if not velocity then
		return false  -- Invalid unit
	end
	return velocity > IS_MOVING_THRESHOLD
end

local function getWeaponDoomageAgainstTarget(weaponDefID, targetUnitID, isProjectile)
	local targetUnitDefID = unitDefCache[targetUnitID]
	if not targetUnitDefID then
		return 0
	end
	
	local targetUnitDef = UnitDefs[targetUnitDefID]
	local armorType = targetUnitDef.armorType or ARMOR_TYPE_DEFAULT
	if isProjectile then
		return weaponDefs[weaponDefID].damages[armorType] or weaponDefs[weaponDefID].damages[ARMOR_TYPE_DEFAULT] or 0
	else
		return weaponDefDPSCache[weaponDefID] and weaponDefDPSCache[weaponDefID][armorType] or 0
	end
end

local function refreshAllUnitDoomPoints()
	for unitID, unitData in pairs(unitWatch) do
		local health = spGetUnitHealth(unitID)
		if health then
			unitData.doomPoints = health
		else
			-- Clean up dead units that somehow weren't removed
			unitWatch[unitID] = nil
		end
	end
end

local function applyProjectileDoomages()
	for projID, projectileData in pairs(projectileWatch) do
		local targetID = projectileData.targetID
		local weaponDefID = projectileData.weaponDefID
		local baseDoomage = projectileData.doomage
		
		local targetUnitData = unitWatch[targetID]
		if targetUnitData then
			local certainties = precalculatedCertainties[weaponDefID]
			if certainties then
				local certainty
				if isUnitMoving(targetID) then
					certainty = certainties.movingTarget
				else
					certainty = certainties.accuracy
				end
				
				local adjustedDoomage = baseDoomage * certainty
				targetUnitData.doomPoints = targetUnitData.doomPoints - adjustedDoomage
				
				if targetUnitData.doomPoints <= 0 then
					doomedUnits[targetID] = true
				end
			end
		end
	end
end

local function applyWeaponDoomageToTarget(weaponDefID, targetID)
	local doomage = getWeaponDoomageAgainstTarget(weaponDefID, targetID, false)
	local certainties = precalculatedCertainties[weaponDefID]
	if not certainties then
		return
	end
	
	local certainty = isUnitMoving(targetID) and certainties.movingTarget or certainties.accuracy
	local adjustedDoomage = doomage * certainty
	
	local targetUnitData = unitWatch[targetID]
	if not targetUnitData then
		return
	end
	
	targetUnitData.doomPoints = targetUnitData.doomPoints - adjustedDoomage
	if targetUnitData.doomPoints <= 0 then
		doomedUnits[targetID] = true
	end
end

local function applyUnitWeaponDoomages()
	for unitID, unitData in pairs(unitWatch) do
		local unitDefID = unitDefCache[unitID]
		if unitDefID then
			local unitDef = UnitDefs[unitDefID]
			if unitDef.weapons then
				for weaponNum = 1, #unitDef.weapons do
					local targetType, targetID = spGetUnitWeaponTarget(unitID, weaponNum)
					if targetID and targetType == WEAPON_TARGET_TYPE_UNIT and isWeaponAvailableToFire(unitID, weaponNum) then
						local weaponDefID = unitDef.weapons[weaponNum].weaponDef
						if weaponDefID then
							applyWeaponDoomageToTarget(weaponDefID, targetID)
						end
					end
				end
			end
		end
	end
end

for weaponDefID, weaponDef in ipairs(WeaponDefs) do


	local watchWeapon = false
	if not ignoredWeaponTypes[weaponDef.type] then
		if projectileWeaponTypes[weaponDef.type] and projectileSpeedIsSlowerThanACycle(weaponDef.range, weaponDef.projectilespeed) then
			watchWeapon = true
			slowProjectileDefs[weaponDefID] = true
		end
		calculateWeaponCertainties(weaponDefID)
		calculateWeaponDibsPriority(weaponDefID)
		calculateWeaponDoomages(weaponDefID)
		Spring.Echo("name", weaponDef.name, "certainties", precalculatedCertainties[weaponDefID], "dibsStep", weaponDefDibsSteps[weaponDefID])
	end

	if weaponTypeCertaintyPenalties[weaponDef.type] then
		Script.SetWatchAllowTarget(weaponDefID, true)
	end
	if watchWeapon then
		Script.SetWatchWeapon(weaponDefID, true)
	end

end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID, builderDefID, builderTeam)
	unitWatch[unitID] = {
		doomPoints = Spring.GetUnitHealth(unitID)
	}
	unitDefCache[unitID] = unitDefID
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	unitWatch[unitID] = nil
	unitDefCache[unitID] = nil
end

function gadget:ProjectileCreated(projectileID, weaponDefID, attackerID, attackerDefID, attackerTeam)
	if slowProjectileDefs[weaponDefID] then
		local targetType, targetID = spGetProjectileTarget(projectileID)
		if targetType == PROJECTILE_TARGET_TYPE_UNIT then
			projectileWatch[projectileID] = {
				weaponDefID = weaponDefID,
				targetID = targetID,
				doomage = getWeaponDoomageAgainstTarget(weaponDefID, targetID, true)
			}
		end
	end
end

function gadget:ProjectileDestroyed(projectileID)
	projectileWatch[projectileID] = nil
end

function gadget:GameFrame(frame)
	gameFrame = frame
	if frame % CYCLE_FRAMES == 0 then
		refreshAllUnitDoomPoints()
		doomedUnits = {}
		applyProjectileDoomages()
		applyUnitWeaponDoomages()
	end
end

--[[
observations:
10x multiplier causes retargeting always to something else equivalent power
5x multiplier causes a bias towards recalculating another equivalent power if the conditions are juicy enough
2x multiplier heavily biases it and rarely triggers retargeting.
]]

local priorityMultipliers = {
	dropNow = 10,
	dropMaybe = 5,
	preferElse = 2,
	preferThis = 0.1,
	thisNow = 0.01
}
function gadget:AllowWeaponTarget(attackerID, targetID, attackerWeaponNum, attackerWeaponDefID, defPriority)
	if not defPriority then
		return
	end
	Spring.Echo(gameFrame, "checking...", targetID, doomedUnits[targetID])
	if doomedUnits[targetID] then
		Spring.Echo("targetID", targetID, "defPriority", defPriority, "priorityMultipliers.dropNow", priorityMultipliers.dropNow)
		return true, defPriority * priorityMultipliers.dropNow
	end
	return true, defPriority
end

function gadget:Initialize()
	local allUnits = Spring.GetAllUnits()
	for i = 1, #allUnits do
		local unitID = allUnits[i]
		local unitDefID = Spring.GetUnitDefID(unitID)
		local unitTeam = Spring.GetUnitTeam(unitID)
		if unitDefID and unitTeam then
			gadget:UnitCreated(unitID, unitDefID, unitTeam)
		end
	end
end