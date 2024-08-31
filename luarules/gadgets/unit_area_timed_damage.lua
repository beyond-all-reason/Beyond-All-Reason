function gadget:GetInfo()
	return {
		name = 'Area Timed Damage Handler',
		desc = '',
		author = 'Damgam',
		version = '1.0',
		date = '2022',
		license = 'GNU GPL, v2 or later',
		layer = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
    return
end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------

local TimedDamageWeapons = {}
local TimedDamageDyingUnits = {}

-- Params:
-- ceg - ceg to spawn when explosion happens
-- damageCeg - ceg to spawn when damage is dealt
-- time - how long the effect should stay
-- damage - damage per second
-- range - from center to edge, in elmos
-- resistance - defines which units are resistant to this type of damage when it matches with 'areadamageresistance' customparameter in a unit.

for weaponDefID, weaponDef in ipairs(WeaponDefs) do
    if weaponDef.customParams and type(weaponDef.customParams.timed_area_weapon) == "table" then
        TimedDamageWeapons[weaponDefID] = weaponDef.customParams.timed_area_weapon
    end
end

for unitDefID, unitDef in ipairs(UnitDefs) do
    if type(unitDef.customParams.timed_area_deathexplosion) == "table" then
        TimedDamageDyingUnits[unitDefID] = unitDef.customParams.timed_area_deathexplosion
    end
end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------

local aliveExplosions = {}

function gadget:Initialize()
    for id, a in pairs(TimedDamageWeapons) do
        Script.SetWatchExplosion(id, true)
    end
end

function gadget:Explosion(weaponDefID, px, py, pz, AttackerID, ProjectileID)
    if TimedDamageWeapons[weaponDefID] ~= nil then
        local currentTime = Spring.GetGameSeconds()
        if py <= math.max(Spring.GetGroundHeight(px, pz), 0) + TimedDamageWeapons[weaponDefID].range*0.5 then
            aliveExplosions[#aliveExplosions+1] = {
                x = px,
                y = math.max(Spring.GetGroundHeight(px, pz), 0),
                z = pz,
                endTime = currentTime + TimedDamageWeapons[weaponDefID].time,
                damage = TimedDamageWeapons[weaponDefID].damage,
                range = TimedDamageWeapons[weaponDefID].range,
                ceg = TimedDamageWeapons[weaponDefID].ceg,
                cegSpawned = false,
                damageCeg = TimedDamageWeapons[weaponDefID].damageCeg,
                resistance = TimedDamageWeapons[weaponDefID].resistance,
                owner = AttackerID,
                weapon = weaponDefID,
            }
        end
    end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
    if TimedDamageDyingUnits[unitDefID] ~= nil then
        local dyingUnit = TimedDamageDyingUnits[unitDefID]
        local px, py, pz = Spring.GetUnitPosition(unitID)
        if py <= math.max(Spring.GetGroundHeight(px, pz), 0) + dyingUnit.range*0.5 then
            local currentTime = Spring.GetGameSeconds()
            aliveExplosions[#aliveExplosions+1] = {
                x = px,
                y = math.max(Spring.GetGroundHeight(px, pz), 0),
                z = pz,
                endTime = currentTime + dyingUnit.time,
                damage = dyingUnit.damage,
                range = dyingUnit.range,
                ceg = dyingUnit.ceg,
                cegSpawned = false,
                damageCeg = dyingUnit.damageCeg,
                resistance = dyingUnit.resistance,
                owner = unitID,
                weapon = WeaponDefNames[UnitDefs[unitDefID].deathExplosion].id,
            }
        end
    end
end

function gadget:GameFrame(frame)
    if frame%22 == 10 then
        local currentTime = Spring.GetGameSeconds()
        for explosionID, explosionStats in pairs(aliveExplosions) do
            if explosionStats.endTime >= currentTime then
                local x = explosionStats.x
                local y = explosionStats.y
                local z = explosionStats.z
                if explosionStats.cegSpawned == false then
                    Spring.SpawnCEG(explosionStats.ceg, x, y + 8, z, 0, 0, 0)
                    explosionStats.cegSpawned = true
                end
                local damage = explosionStats.damage*0.733
                local range = explosionStats.range
                local resistance = explosionStats.resistance
                local unitsInRange = Spring.GetUnitsInSphere(x, y, z, range)
                for j = 1,#unitsInRange do
                    local unitID = unitsInRange[j]
                    local unitDef = UnitDefs[Spring.GetUnitDefID(unitID)]
                    if (not unitDef.canFly) and not (unitDef.customParams.areadamageresistance and string.find(unitDef.customParams.areadamageresistance, resistance)) then
                        Spring.AddUnitDamage(unitID, damage, 0, explosionStats.owner, explosionStats.weapon)
                        local ux, uy, uz = Spring.GetUnitPosition(unitID)
                        Spring.SpawnCEG(explosionStats.damageCeg, ux, uy + 8, uz, 0, 0, 0)
                    end
                end
                local featuresInRange = Spring.GetFeaturesInSphere(x, y, z, range)
                for j = 1,#featuresInRange do
                    local featureID = featuresInRange[j]
                    local health = Spring.GetFeatureHealth(featureID)
                    if health > damage then
                        Spring.SetFeatureHealth(featureID, health - damage)
                    else
                        Spring.DestroyFeature(featureID)
                    end
                    local ux, uy, uz = Spring.GetFeaturePosition(featureID)
                    Spring.SpawnCEG(explosionStats.damageCeg, ux, uy + 8, uz, 0, 0, 0)
                end
            else -- This explosion is outdated, we can remove it from the list
                aliveExplosions[explosionID] = nil
            end
        end
    end
end
