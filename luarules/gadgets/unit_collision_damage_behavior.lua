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

--use customparams.fall_damage_multiplier = <number> a multiplier that's applied to defaultDamageMultiplier.
local fallDamageMagnificationFactor = 14 --the multiplier by which default engine ground collision damage is multiplied. change this value to reduce the amount of fall/collision damage taken for all units.

local groundCollisionDefID = Game.envDamageTypes.GroundCollision
local objectCollisionDefID = Game.envDamageTypes.ObjectCollision
local objectCollisionVelocityThreshold = 3.3 --this defines how fast a unit has to be moving in order to take object collision damage
local maxImpulseProportion = 0.04 --incease this to make units move less from impulse. This defines the max impulse damage allowed a unit can take relative to its mass.
local velocityCap = 3 --measured in elmos per frame. Any unit hit with an explosion that achieves a velocity greater than this will be slowed until stopped.

local spGetUnitHealth = Spring.GetUnitHealth
local spGetUnitVelocity = Spring.GetUnitVelocity
local spSetUnitVelocity = Spring.SetUnitVelocity
local mathMin = math.min
local mathMax = math.max
local mathCeil = math.ceil

local fallDamageMultipliers = {}
local unitsMaxImpulse = {}
local weaponDefIDImpulses = {}
local transportedUnits = {}
local unitMasses = {}
local weaponDefIgnored = {}
local unitInertiaCheckFlags = {} -- track inertia via velocity (units have constant mass)
local gameFrame = 0
local velocityWatchDuration = 3

for unitDefID, unitDef in ipairs(UnitDefs) do
	local fallDamageMultiplier = unitDef.customParams.fall_damage_multiplier or 1.0
	fallDamageMultipliers[unitDefID] = fallDamageMultiplier * fallDamageMagnificationFactor
	unitsMaxImpulse[unitDefID] = unitDef.mass / maxImpulseProportion
	unitMasses[unitDefID] = unitDef.mass
end

for name, weaponDefID in pairs(Game.envDamageTypes or {}) do
	weaponDefIgnored[weaponDefID] = true
end

for weaponDefID, wDef in ipairs(WeaponDefs) do
	if wDef.damages and wDef.damages.impulseBoost and wDef.damages.impulseFactor then
		weaponDefIDImpulses[weaponDefID] = {impulseboost = wDef.damages.impulseBoost, impulsefactor = wDef.damages.impulseFactor}
	end

	
	local function maxDamage(damages)
		local damage = damages[0]
		for i = 1, #damages do
			damage = mathMax(damages[i], damage)
		end
		return damage
	end
	
	--generate list of exempted weapons to improve performance
	local minImpulseFactor = 0.15
	local minImpulseToDamageRatio = 0.2
	if wDef.damages and wDef.damages.impulseFactor == 0 or
		(wDef.damages.impulseFactor < minImpulseFactor and wDef.damages.impulseBoost < maxDamage(wDef.damages) * minImpulseToDamageRatio) then
		weaponDefIgnored[weaponDefID] = true
	end
end

local function getImpulseMultiplier(unitDefID, weaponDefID, damage)
	local impulseBoost = weaponDefIDImpulses[weaponDefID].impulseboost or 0
	local impulseFactor = weaponDefIDImpulses[weaponDefID].impulsefactor or 1
	local impulse = (damage + impulseBoost) * impulseFactor
	local maxImpulse = unitsMaxImpulse[unitDefID]
	local impulseMultiplier = mathMin(maxImpulse/impulse, 1)  --we round to prevent the loss of impulse due to sheered tiny, tiny values being returned in UnitPreDamaged
	return impulseMultiplier
end

local function massToHealthRatioMultiplier(unitID, unitDefID)
	local health, maxHealth = spGetUnitHealth(unitID)
	if maxHealth then
		local massToMaxHealthMultiplier = (maxHealth / unitMasses[unitDefID]) * fallDamageMultipliers[unitDefID]
		return massToMaxHealthMultiplier
	else
		return fallDamageMultipliers[unitDefID]
	end
end

local function velocityDamageDirection(unitID)
	local velX, velY, velZ, velLength = spGetUnitVelocity(unitID)
		-- y-velocity check prevents mostly horizontal object collisions from taking damage, allows damage if dropped from above
		return velLength > objectCollisionVelocityThreshold and -velY > (velLength/2)
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	if not weaponDefIgnored[weaponDefID] and weaponDefID > 0 then --this section handles limiting maximum impulse
		local impulseMultiplier = 1
		impulseMultiplier = getImpulseMultiplier(unitDefID, weaponDefID, damage)
		unitInertiaCheckFlags[unitID] = gameFrame + velocityWatchDuration
		return damage, impulseMultiplier
	else
		if weaponDefID == groundCollisionDefID and not transportedUnits[unitID] then
			damage = damage * massToHealthRatioMultiplier(unitID, unitDefID)
			return damage, 0
		elseif weaponDefID == objectCollisionDefID and not transportedUnits[unitID] then
			if velocityDamageDirection(unitID) then
				damage = damage * massToHealthRatioMultiplier(unitID, unitDefID)
				return damage, 0
			else
				return 0, 0
			end
		end
	end
end

function gadget:UnitLoaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	transportedUnits[unitID] = true
end

function gadget:UnitUnloaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	transportedUnits[unitID] = nil
end

function gadget:UnitDestroyed(unitID)
	transportedUnits[unitID] = nil
	unitInertiaCheckFlags[unitID] = nil
end

function gadget:GameFrame(frame)
	for unitID, expirationFrame in pairs(unitInertiaCheckFlags) do
		if not transportedUnits[unitID] then
			local velX, velY, velZ, velocityLength = spGetUnitVelocity(unitID)
			if velocityLength > velocityCap then
				velX = (velocityCap / velocityLength) * velX
				velY = (velocityCap / velocityLength) * velY
				velZ = (velocityCap / velocityLength) * velZ
			end
			if velocityLength > objectCollisionVelocityThreshold then
				local decelerateHorizontal = 0.95
				local decelerateVertical = 0.33
				if velY < 0 then
					decelerateVertical = 1
				end
				spSetUnitVelocity(unitID, velX * decelerateHorizontal, velY * decelerateVertical, velZ * decelerateHorizontal)
				expirationFrame = frame + velocityWatchDuration
			elseif expirationFrame < frame then
				unitInertiaCheckFlags[unitID] = nil
			end
		end
	end
	gameFrame = frame
end
