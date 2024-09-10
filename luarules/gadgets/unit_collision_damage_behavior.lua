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
local maxImpulseThreshold = 0.08 --incease this to make units move less from impulse. This defines the max impulse damage a unit can take expressed in a percentage multiplier
local cooldownsFrameThreshold = Game.gameSpeed --this is how long in frames before a unit's maximum impulse limit resets.

local spGetUnitVelocity = Spring.GetUnitVelocity
local spGetUnitHealth = Spring.GetUnitHealth
local mathmin = math.min

local fallDamageMultipliers = {}
local unitsMaxImpulse = {}
local weaponDefIDImpulses = {}
local overImpulseCooldowns = {}
local transportingUnits = {}
local unitMasses = {}

local currentModulusFrame = 0

for unitDefID, unitDef in ipairs(UnitDefs) do
	local fallDamageMultiplier = unitDef.customParams.fall_damage_multiplier or 1.0
	fallDamageMultipliers[unitDefID] = fallDamageMultiplier * fallDamageMagnificationFactor
	unitsMaxImpulse[unitDefID] = unitDef.mass / maxImpulseThreshold
	unitMasses[unitDefID] = unitDef.mass
end

for weaponDefID, wDef in ipairs(WeaponDefs) do
	if wDef.damages and wDef.damages.impulseBoost and wDef.damages.impulseFactor then
		weaponDefIDImpulses[weaponDefID] = {impulseboost = wDef.damages.impulseBoost, impulsefactor = wDef.damages.impulseFactor}
	end
end

local function calculateImpulseData(unitDefID, damage, weaponDefID)
	local impulse = (damage + weaponDefIDImpulses[weaponDefID].impulseboost) * weaponDefIDImpulses[weaponDefID].impulsefactor
	local maxImpulse = unitsMaxImpulse[unitDefID]
	local impulseMultiplier = mathmin(maxImpulse/impulse, 1)
	return impulse, impulseMultiplier
end

local function isUnitBeingTransported(unitID)
	for transportID, transportedID in pairs(transportingUnits) do
		if transportingUnits[transportID][unitID] then
			return true
		end
	end
	return false
end

local function calculateMassToHealthRatioMultiplier(unitID, unitDefID)
	local health, maxHealth = spGetUnitHealth(unitID)
	if maxHealth then
		local massToMaxHealthMultiplier = (maxHealth / unitMasses[unitDefID]) * fallDamageMultipliers[unitDefID]
		return massToMaxHealthMultiplier
	else
		return fallDamageMultipliers[unitDefID]
	end
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	if weaponDefID > 0 then --this section handles limiting maximum impulse
		local impulseMultiplier = 1
		local impulse = 0
		impulse, impulseMultiplier = calculateImpulseData(unitDefID, damage, weaponDefID)
		if overImpulseCooldowns[unitID] and overImpulseCooldowns[unitID].highestimpulse < impulse then
			impulseMultiplier = impulseMultiplier - overImpulseCooldowns[unitID].impulsemultiplier
		end
		overImpulseCooldowns[unitID] = {expireframe = currentModulusFrame + cooldownsFrameThreshold, highestimpulse = impulse, impulsemultiplier = impulseMultiplier}
		return damage, impulseMultiplier
	else
		if weaponDefID == groundCollisionDefID and not isUnitBeingTransported(unitID) then --handles ground collision events
			damage = damage * calculateMassToHealthRatioMultiplier(unitID, unitDefID)
			return damage, 0
		elseif weaponDefID == objectCollisionDefID and not isUnitBeingTransported(unitID) then --handles object collision events
			local _, velY, _, velLength = spGetUnitVelocity(unitID)
			if velLength > objectCollisionVelocityThreshold and -velY > (velLength/3) then --prevents mostly horizontal object collisions from taking damage, allows damage if dropped from above
				damage = damage * calculateMassToHealthRatioMultiplier(unitID, unitDefID)
				return damage, 0
			else
				return 0, 0
			end
		end
	end
end

function gadget:UnitLoaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	transportingUnits[transportID] = transportingUnits[transportID] or {}
	transportingUnits[transportID][unitID] = true
end

function gadget:UnitUnloaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	transportingUnits[transportID][unitID] = nil
end

function gadget:UnitDestroyed(unitID)
	transportingUnits[unitID] = nil
end

function gadget:GameFrame(frame)
	if frame % 5 == 3 then
		for unitID, data in pairs (overImpulseCooldowns) do
			if data.expireframe < frame  then --this is done to prevent a unit from being impulsed multiple times in a compounding fashion in a performant way.
				overImpulseCooldowns[unitID] = nil
			end
		end
		currentModulusFrame = frame
	end
end
