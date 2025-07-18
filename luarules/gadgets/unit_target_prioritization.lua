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

if not gadgetHandler:IsSyncedCode() then return end

-- CONSTANTS
local CYCLE_FRAMES = Game.gameSpeed

---configables
local DOOM_DECAY_PERCENTAGE = 0.01 -- the speed at which doom (virtual health) decays as a percentage per second.

local SlOW_PROJECTILE_FRAMES = 10 -- For each multiple of this threshold, CERTAINTY_PROJECTILE_SLOWNESS_PENALTY_MULTIPLIER is multiplied.

--certainty constants
local CERTAINTY_PROJECTILE_SLOWNESS_PENALTY_MULTIPLIER = 0.9 -- the multiplier for the projectile's speed to determine the certainty of overkill prevention.

-- variables
local gameFrame = 0

local slowProjectileWeaponWatch = {}
local precalculatedAccuracyCertainties = {}

local dibsSteps = { --musn't be more than 30 steps. This is the order in which units are given "dibs" on target selection in order of reloadtime.
	[1] = 0.5,
	[2] = 1,
	[3] = 2,
	[4] = 4,
	[5] = 8
}

local ACCURACY_PENALTY_CALC_RANGE = 500 -- for the purposes of certainty penalizations, 
--it's good enough to assume accuracy calculations at maximum range so we don't have to calculate ranges and do simulation reconstructive math.
local accuracies = { --the left number multiplied by ACCURACY_PENALTY_CALC_RANGE is the accuracy equivalent from a weaponDef's accuracy.
 S = 1 * ACCURACY_PENALTY_CALC_RANGE, --zzz we are gonna have to do range checks, but we will simply compare the resultant accuracy * target range to this. Early exit when distance < 500
 A = 3 * ACCURACY_PENALTY_CALC_RANGE,
 B = 10 * ACCURACY_PENALTY_CALC_RANGE,
 C = 20 * ACCURACY_PENALTY_CALC_RANGE,
 D = 40 * ACCURACY_PENALTY_CALC_RANGE,
 F = 100 * ACCURACY_PENALTY_CALC_RANGE,
}

local weaponTypeCertaintyPenalties = { -- the smaller the number, the less certain the weapon will deal its full damage.
	AircraftBomb = 0.8,
	BeamLaser = 1.0,
	Cannon = 0.8,
	Dgun = 0.8,
	EmgCannon = 0.8,
	Flame = 0.8,
	LaserCannon = 0.8,
	LightningCanon = 1.0,
	Melee = 1.0,
	MissileLauncher = 0.8,
	Rifle = 1.0,
	StarburstLauncher = 0.8,
	StarburstMissiles = 0.8,
	TorpedoLauncher = 0.8,
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

local trackingAbleWeaponTypes = {
	MissileLauncher = true,
	StarburstMissiles = true,
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

local mathSqrt = math.sqrt
local mathMax = math.max

--functions

local function projectileSpeedIsSlowerThanACycle(range, velocity)
	local distanceTraveledInOneSecond = velocity * CYCLE_FRAMES
	if distanceTraveledInOneSecond >= range then
		return distanceTraveledInOneSecond / range
	else
		return false
	end
end

local function calculateProjectileTravelFrames(weaponDefID)
	local weaponDef = WeaponDefs[weaponDefID]
	local initialVelocity = weaponDef.startvelocity
	local maximumVelocity = weaponDef.projectilespeed
	local accelerationRate = weaponDef.weaponAcceleration
	local totalDistance = weaponDef.range

	local totalFrames = 0

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

	if weaponDef.type == "StarburstMissiles" then
		totalFrames = totalFrames - math.floor(math.rad(90) / weaponDef.turnRate) -- subtract the time it takes to turn at the top of ascent only for starburst missiles
	end

	return math.floor(totalFrames)
end



local function getProjectileSlownessCertainty(weaponDefID)
	local travelFrames = calculateProjectileTravelFrames(weaponDefID)
	if travelFrames > SlOW_PROJECTILE_FRAMES then
		return CERTAINTY_PROJECTILE_SLOWNESS_PENALTY_MULTIPLIER ^ (travelFrames / SlOW_PROJECTILE_FRAMES)
	end
	return false
end

local function getAccuracyThreshold(rangeAccuracyProduct)
	if rangeAccuracyProduct < accuracies.S then
		return accuracies.S
	elseif rangeAccuracyProduct < accuracies.A then
		return accuracies.A
	elseif rangeAccuracyProduct < accuracies.B then
		return accuracies.B
	elseif rangeAccuracyProduct < accuracies.C then
		return accuracies.C
	elseif rangeAccuracyProduct < accuracies.D then
		return accuracies.D
	else
		return accuracies.F
	end
end

local function calculateWeaponCertainty(weaponDefID)
	local weaponDef = WeaponDefs[weaponDefID]

	if weaponDef.customParams.certainty_override then
		return weaponDef.customParams.certainty_override
	end
	
	local certainty = 1

	-- Apply base weapon type certainty penalties
	if weaponTypeCertaintyPenalties[weaponDef.type] then
		certainty = certainty * weaponTypeCertaintyPenalties[weaponDef.type]
	end
	
	-- Handle tracking weapons (MissileLauncher and StarburstMissile) and accuracy
	local accuracyCertainty = 1.0
	if not trackingAbleWeaponTypes[weaponDef.type] then -- at such short ranges, it's worthwhile to perform a simple max range calculation.
		
		precalculatedAccuracyCertainties[weaponDefID] = getAccuracyThreshold(weaponDef.range * weaponDef.accuracy)
	end
	
	return certainty
end

local function getWeaponDibsPriority(weaponDefID)
	local weaponDef = WeaponDefs[weaponDefID]

end



for unitDefID, unitDef in ipairs(UnitDefs) do
	local localUnitDefs = {}
	localUnitDefs.maxDoom = unitDef.health
	localUnitDefs.doomDecay = localUnitDefs.maxDoom * DOOM_DECAY_PERCENTAGE / Game.gameSpeed
end

for weaponDefID, weaponDef in ipairs(WeaponDefs) do


	local watchWeapon = false
	if not ignoredWeaponTypes[weaponDef.type] then
		local slownessCertainty = getProjectileSlownessCertainty(weaponDefID)
		if projectileWeaponTypes[weaponDef.type] and projectileSpeedIsSlowerThanACycle(weaponDef.range, weaponDef.projectilespeed) then
			watchWeapon = true
			slowProjectileWeaponWatch[weaponDefID] = slownessCertainty
			Spring.Echo("Watching weapon ".. weaponDef.name .. " (" .. weaponDefID .. ") because it's slow", "travel time: " .. projectileSpeedIsSlowerThanACycle(weaponDef.range, weaponDef.projectilespeed))
		end
		local weaponCertainty = calculateWeaponCertainty(weaponDefID)
	end

	if watchWeapon then
		Script.SetWatchWeapon(weaponDefID, true)
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
end

function gadget:GameFrame(frame)
	gameFrame = frame

end