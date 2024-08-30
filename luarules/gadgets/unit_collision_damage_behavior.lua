function gadget:GetInfo()
	return {
		name = "Collision Damage Behavior",
		desc = "Magnifies the default engine ground and object collision damage and changes the behavior thereof",
		author = "SethDGamre",
		date = "2024.8.29",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end
--this gadget 

--use customparams.fall_damage_multiplier = <number> a multiplier that's applied to defaultDamageMultiplier.
local fallDamageMagnificationFactor = 64 --the multiplier by which default engine ground collision damage is multiplied. 

local spGetUnitVelocity = Spring.GetUnitVelocity

local groundCollisionDefID = Game.envDamageTypes.GroundCollision
local objectCollisionDefID = Game.envDamageTypes.ObjectCollision
local objectCollisionVelocityThreshold = 3.3
local fallDamageMultipliers = {}


for unitDefID, unitDef in ipairs(UnitDefs) do
	local fallDamageMultiplier = unitDef.customParams.fall_damage_multiplier or 1.0
	fallDamageMultipliers[unitDefID] = fallDamageMultiplier*fallDamageMagnificationFactor
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	Spring.Echo(weaponDefID, damage)
	if weaponDefID == objectCollisionDefID then
		local _, _, _, velLength = spGetUnitVelocity(unitID)
		if velLength > objectCollisionVelocityThreshold then
			damage = damage*fallDamageMultipliers[unitDefID]
			return damage
		else
			return 0
		end
		return 0
	elseif weaponDefID == groundCollisionDefID then
		damage = damage*fallDamageMultipliers[unitDefID]
		return damage
	end
end
