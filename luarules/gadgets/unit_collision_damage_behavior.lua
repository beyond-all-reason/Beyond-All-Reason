local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Collision Damage Behavior",
		desc = "Magnifies the default engine ground and object collision damage and handles max impulse limits",
		author = "SethDGamre",
		date = "2024.8.29",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then return end

--customparams.fall_damage_multiplier = <number> a multiplier that's applied to defaultDamageMultiplier which affects the amount of damage taken from falling/collisions.

--the multiplier by which default engine ground/object collision damage is multiplied. change this value to reduce the amount of fall/collision damage taken for all units. Chosen empirically.
local fallDamageMagnificationFactor = 14

--this defines how fast a unit has to be moving in order to take object collision damage, empirically selected.
local collisionVelocityThreshold = 108 / Game.gameSpeed

--the angle of descent that is allowed collision damage. The angle is measured from directly above downward.
local validCollisionAngleMultiplier = math.cos(math.rad(20)) --degrees

-- Decrease this value to make units move less from impulse. This defines the maximum impulse allowed, which is (maxImpulseMultiplier * mass) of each unit.
local maxImpulseMultiplier = 5.5

--to save performance and reduce unit hesitation from nominal impulse, impulse values below (minImpulseMultiplier * mass) returns 0 impulse.
local minImpulseMultiplier = 0.01

-- elmo/s, converted to elmo/frame. If a unit is launched via explosion faster than this, it is instantly slowed. If unit speed/gameSpeed is greater or canFly = true, speed/gameSpeed is used instead.
local velocityCap = 330 / Game.gameSpeed

--measured in elmos per frame. If velocity is above this threshold, it will be slowed until below this threshold so long as its initial velocity was greater than velocityCap.
local velocitySlowdownThreshold = 30 / Game.gameSpeed

--any weapondef impulseFactor below this is ignored to save performance
local minImpulseFactor = 0.15

--any impulse to damage ratio below this is ignored to save performance
local minImpulseToDamageRatio = 0.2

local groundCollisionDefID = Game.envDamageTypes.GroundCollision
local objectCollisionDefID = Game.envDamageTypes.ObjectCollision
local spGetUnitHealth = Spring.GetUnitHealth
local spGetUnitVelocity = Spring.GetUnitVelocity
local spSetUnitVelocity = Spring.SetUnitVelocity
local spGetUnitIsDead = Spring.GetUnitIsDead
local spDestroyUnit = Spring.DestroyUnit
local mathMin = math.min
local mathMax = math.max
local mathAbs = math.abs

local fallDamageMultipliers = {}
local unitsMaxImpulse = {}
local unitsMinImpulse = {}
local weaponDefIDImpulses = {}
local transportedUnits = {}
local unitMasses = {}
local unitDefData = {}
local weaponDefIgnored = {}
local unitInertiaCheckFlags = {}
local fallingKillQueue = {}
local launchedUnits = {}
local fallingUnits = {}

local gameFrame = 0
local velocityWatchFrames = 300 / Game.gameSpeed

for unitDefID, unitDef in ipairs(UnitDefs) do
	unitDefData[unitDefID] = {}
	if unitDef.canFly then
		unitDefData[unitDefID].canFly = true
	end
	if unitDef.speed and unitDef.speed > 0 then
		if unitDefData[unitDefID].canFly then
			unitDefData[unitDefID].velocityCap = unitDef.speed / Game.gameSpeed
		else
			unitDefData[unitDefID].velocityCap = math.max(unitDef.speed / Game.gameSpeed, velocityCap)
		end
	else
		unitDefData[unitDefID].velocityCap = velocityCap
	end

	local fallDamageMultiplier = unitDef.customParams.fall_damage_multiplier or 1.0
	fallDamageMultipliers[unitDefID] = fallDamageMultiplier * fallDamageMagnificationFactor
	unitsMaxImpulse[unitDefID] = unitDef.mass * maxImpulseMultiplier
	unitsMinImpulse[unitDefID] = unitDef.mass * minImpulseMultiplier
	unitMasses[unitDefID] = unitDef.mass
end

for name, weaponDefID in pairs(Game.envDamageTypes) do
	weaponDefIgnored[weaponDefID] = true
end

for weaponDefID, wDef in ipairs(WeaponDefs) do
	if wDef.damages and wDef.damages.impulseBoost and wDef.damages.impulseFactor then
		weaponDefIDImpulses[weaponDefID] = {impulseBoost = wDef.damages.impulseBoost, impulseFactor = wDef.damages.impulseFactor}
		if wDef.beamtime then
			weaponDefIDImpulses[weaponDefID].impulseBoost = weaponDefIDImpulses[weaponDefID].impulseBoost * 1 / math.floor(wDef.beamtime * Game.gameSpeed) --this splits up impulseBoost across the number of frames that damage is dealt
		end
	end

	local function maxDamage(damages)
		local damage = damages[0]
		for i = 1, #damages do
			damage = mathMax(damages[i], damage)
		end
		return damage
	end
	
	--generate list of exempted weapons to improve performance
	if wDef.damages and wDef.damages.impulseFactor == 0 or
		(wDef.damages.impulseFactor < minImpulseFactor and wDef.damages.impulseBoost < maxDamage(wDef.damages) * minImpulseToDamageRatio) then
		weaponDefIgnored[weaponDefID] = true
	end
end

local function getImpulseMultiplier(unitDefID, weaponDefID, damage)
	local impulseBoost = 0
	local impulseFactor = 1
	if weaponDefID and weaponDefIDImpulses[weaponDefID] then
		impulseBoost = weaponDefIDImpulses[weaponDefID].impulseBoost or 0
		impulseFactor = weaponDefIDImpulses[weaponDefID].impulseFactor or 1
	end
	local impulse = (damage + impulseBoost) * impulseFactor
	local impulseMultiplier
	if impulse < unitsMinImpulse[unitDefID] then
		impulseMultiplier = 0
	else
		impulseMultiplier = mathMin(unitsMaxImpulse[unitDefID]/impulse, 1) -- negative impulse values are not capped.
	end
	return impulseMultiplier
end

local function massToHealthRatioMultiplier(unitID, unitDefID)
	local health, maxHealth = spGetUnitHealth(unitID)
	if maxHealth then
		local massToMaxHealthMultiplier = (maxHealth / unitMasses[unitDefID]) * fallDamageMultipliers[unitDefID]
		return massToMaxHealthMultiplier, health
	else
		return fallDamageMultipliers[unitDefID], health
	end
end

local function preventOverkillDamage(unitID, damage, health, healthRatioMultiplier)
	damage = damage * healthRatioMultiplier
	if damage >= health then
		fallingKillQueue[unitID] = true --done in GameFrame to take it out of unitPreDamaged
		return 0
	else
		return damage
	end
end

local function isValidCollisionDirection(unitID)
	local velX, velY, velZ, velLength = spGetUnitVelocity(unitID)
		-- y-velocity check prevents mostly horizontal object collisions from taking damage, allows damage if dropped from above
		return velLength > collisionVelocityThreshold and -velY > (velLength * validCollisionAngleMultiplier)
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	if not weaponDefIgnored[weaponDefID] and weaponDefID >= 0 then --this section handles limiting maximum impulse
		local impulseMultiplier = 1
			impulseMultiplier = getImpulseMultiplier(unitDefID, weaponDefID, damage)
			if not unitInertiaCheckFlags[unitID] and impulseMultiplier ~= 0 then
				unitInertiaCheckFlags[unitID] = {expirationFrame = gameFrame + velocityWatchFrames, velocityCap = unitDefData[unitDefID].velocityCap}
			end
			return damage, impulseMultiplier
	elseif (weaponDefID == groundCollisionDefID or weaponDefID == objectCollisionDefID) and (isValidCollisionDirection(unitID) or fallingUnits[unitID]) then
		local healthRatioMultiplier, health = massToHealthRatioMultiplier(unitID, unitDefID)
		damage = preventOverkillDamage(unitID, damage, health, healthRatioMultiplier)
		return damage, 0
	else
		return damage, 0
	end
end

function gadget:UnitLoaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	transportedUnits[unitID] = true
end

function gadget:UnitUnloaded(unitID, unitDefID, unitTeam,  transportID, transportTeam)
	transportedUnits[unitID] = nil
	fallingUnits[unitID] = true --units falling from transports should take collision damagee from any trajectory, including when bouncing off of other objects.
end

function gadget:UnitEnteredAir(unitID, unitDefID, unitTeam)
	if not transportedUnits[unitID] and not unitDefData[unitDefID].canFly then
		launchedUnits[unitID] = true
	end
end

function gadget:UnitLeftAir(unitID, unitDefID, unitTeam)
	fallingUnits[unitID] = nil
	launchedUnits[unitID] = nil
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	transportedUnits[unitID] = nil
	unitInertiaCheckFlags[unitID] = nil
	launchedUnits[unitID] = nil
	fallingUnits[unitID] = nil
end

function gadget:GameFrame(frame)
	for unitID, data in pairs(unitInertiaCheckFlags) do
		if not transportedUnits[unitID] and not spGetUnitIsDead(unitID) then
			local velX, velY, velZ, velocityLength = spGetUnitVelocity(unitID)
			if not data.velocityReduced and velocityLength > data.velocityCap then
				local verticalVelocityCapThreshold = 0.07 --value derived from empirical testing to prevent fall damage and goofy trajectories from impulse
				local horizontalVelocity = math.sqrt(velX^2 + velZ^2)
				local newVelY = mathAbs(mathMin(horizontalVelocity * verticalVelocityCapThreshold, velY))
				local newVelYToOldVelYRatio
				if velY ~= 0 then
				newVelYToOldVelYRatio = mathMin(mathAbs(newVelY/velY), 1)
				else
					newVelYToOldVelYRatio = 1
				end

				local divisor = mathMax(mathAbs(velX), mathAbs(newVelY), mathAbs(velZ), 0.001)
				local scale = data.velocityCap / divisor

				velX = velX * scale * newVelYToOldVelYRatio
				velZ = velZ * scale * newVelYToOldVelYRatio

				spSetUnitVelocity(unitID, velX, newVelY, velZ)
				data.velocityReduced = true
				data.expirationFrame = frame + velocityWatchFrames
			elseif launchedUnits[unitID] and velocityLength > velocitySlowdownThreshold then
				local decelerateHorizontal = 0.98 --Number empirically tested to produce optimal deceleration without looking goofy.
				local decelerateVertical
				if velY < 0 then
					decelerateVertical = 1
				else
					decelerateVertical = 0.92 --Number empirically tested to produce optimal deceleration without looking goofy.
				end
				spSetUnitVelocity(unitID, velX * decelerateHorizontal, velY * decelerateVertical, velZ * decelerateHorizontal)
				data.expirationFrame = frame + velocityWatchFrames
			elseif data.expirationFrame < frame then
				unitInertiaCheckFlags[unitID] = nil
				launchedUnits[unitID] = nil
			end
		else
			unitInertiaCheckFlags[unitID] = nil
			launchedUnits[unitID] = nil
		end
	end

	for unitID, _ in pairs(fallingKillQueue) do
		spDestroyUnit(unitID) --this ensures a wreck is left behind. If damage is too great, it destroys the heap.
		fallingKillQueue[unitID] = nil
	end
	gameFrame = frame
end

local function setVelocityControl(unitID, enabled)
	if enabled == false then
		launchedUnits[unitID] = nil
		unitInertiaCheckFlags[unitID] = nil
	elseif not unitInertiaCheckFlags[unitID] then
		unitInertiaCheckFlags[unitID] = {
			expirationFrame = gameFrame + velocityWatchFrames,
			velocityCap     = unitDefData[Spring.GetUnitDefID(unitID)].velocityCap,
		}
	end
end

function gadget:Initialize()
	GG.SetVelocityControl = setVelocityControl
end

function gadget:ShutDown()
	GG.SetVelocityControl = nil
end
