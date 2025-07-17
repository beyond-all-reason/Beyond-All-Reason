local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Water Crush and Collision Damage",
		desc = "Creates and handles water collision events, and kills units stuck underwater",
		author = "SethDGamre",
		date = "2024.9.22",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then return end

-- CONSTANTS
---configables
local DOOM_DECAY_PERCENTAGE = 0.01 -- the speed at which doom (virtual health) decays as a percentage per second.

local SlOW_PROJECTILE_FRAMES = 10 -- For each multiple of this threshold, CERTAINTY_PROJECTILE_SLOWNESS_PENALTY_MULTIPLIER is multiplied.

--certainty constants
local CERTAINTY_PROJECTILE_SLOWNESS_PENALTY_MULTIPLIER = 0.9 -- the multiplier for the projectile's speed to determine the certainty of overkill prevention.

-- variables
local gameFrame = 0

local overkillWeaponWatch = {}

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

--functions

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

for unitDefID, unitDef in ipairs(UnitDefs) do
	local localUnitDefs = {}
	localUnitDefs.maxDoom = unitDef.health
	localUnitDefs.doomDecay = localUnitDefs.maxDoom * DOOM_DECAY_PERCENTAGE / Game.gameSpeed
end

for weaponDefID, weaponDef in ipairs(WeaponDefs) do
	local watchWeapon = false

	local slownessCertainty = getProjectileSlownessCertainty(weaponDefID)
	if getProjectileSlownessCertainty(weaponDefID) then
		watchWeapon = true
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