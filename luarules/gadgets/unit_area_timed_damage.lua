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

--------------------------------------------------------------------------------

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
    if weaponDef.customParams and weaponDef.customParams.timed_area_ceg then
        local params = weaponDef.customParams
        TimedDamageWeapons[weaponDefID] = {
            ceg        = params.area_onhit_ceg,
            damageCeg  = params.area_onhit_damageceg, -- lowercase
            resistance = params.area_onhit_resistance   ,
            damage     = tonumber(params.area_onhit_damage),
            range      = tonumber(params.area_onhit_range),
            time       = tonumber(params.area_onhit_time),
        }
    end
end

for unitDefID, unitDef in ipairs(UnitDefs) do
    if unitDef.customParams.timed_area_ceg then
        local params = unitDef.customParams
        TimedDamageDyingUnits[unitDefID] = {
            ceg        = params.area_ondeath_ceg,
            damageCeg  = params.area_ondeath_damageceg, -- lowercase
            resistance = params.area_ondeath_resistance,
            damage     = tonumber(params.area_ondeath_damage),
            range      = tonumber(params.area_ondeath_range),
            time       = tonumber(params.area_ondeath_time),
            weapon     = WeaponDefNames[UnitDefs[unitDefID].deathExplosion].id or -1,
        }
    end
end

--------------------------------------------------------------------------------

local aliveExplosions = {}

function gadget:Initialize()
    for weaponID in pairs(TimedDamageWeapons) do
        Script.SetWatchExplosion(weaponID, true)
    end

    if not next(TimedDamageWeapons) and not next(TimedDamageDyingUnits) then
        gadgetHandler:RemoveGadget(self)
    end
end

function gadget:Explosion(weaponDefID, px, py, pz, AttackerID, ProjectileID)
    if TimedDamageWeapons[weaponDefID] ~= nil then
        local explosion = TimedDamageWeapons[weaponDefID]
        if py <= math.max(Spring.GetGroundHeight(px, pz), 0) + explosion.range*0.5 then
            local currentTime = Spring.GetGameSeconds()
            aliveExplosions[#aliveExplosions+1] = {
                x = px,
                y = math.max(Spring.GetGroundHeight(px, pz), 0),
                z = pz,
                endTime = currentTime + explosion.time,
                damage = explosion.damage,
                range = explosion.range,
                ceg = explosion.ceg,
                damageCeg = explosion.damageCeg,
                resistance = explosion.resistance,
                owner = AttackerID,
                weapon = weaponDefID,
            }
        end
    end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
    if TimedDamageDyingUnits[unitDefID] ~= nil then
        local explosion = TimedDamageDyingUnits[unitDefID]
        local px, py, pz = Spring.GetUnitPosition(unitID)
        if py <= math.max(Spring.GetGroundHeight(px, pz), 0) + explosion.range*0.5 then
            local currentTime = Spring.GetGameSeconds()
            aliveExplosions[#aliveExplosions+1] = {
                x = px,
                y = math.max(Spring.GetGroundHeight(px, pz), 0),
                z = pz,
                endTime = currentTime + explosion.time,
                damage = explosion.damage,
                range = explosion.range,
                ceg = explosion.ceg,
                damageCeg = explosion.damageCeg,
                resistance = explosion.resistance,
                owner = unitID,
                weapon = explosion.weapon,
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
                local damage = explosionStats.damage*0.733
                local resistance = explosionStats.resistance

                Spring.SpawnCEG(explosionStats.ceg, x, y + 8, z, 0, 0, 0)

                local unitsInRange = Spring.GetUnitsInSphere(x, y, z, explosionStats.range)
                for j = 1,#unitsInRange do
                    local unitID = unitsInRange[j]
                    local unitDef = UnitDefs[Spring.GetUnitDefID(unitID)]
                    if not (
                        unitDef.canFly or
                        (unitDef.customParams.areadamageresistance ~= nil and
                            string.find(unitDef.customParams.areadamageresistance, resistance, nil, true))
                    ) then
                        Spring.AddUnitDamage(unitID, damage, 0, explosionStats.owner, explosionStats.weapon)
                        local ux, uy, uz = Spring.GetUnitPosition(unitID)
                        Spring.SpawnCEG(explosionStats.damageCeg, ux, uy + 8, uz, 0, 0, 0)
                    end
                end

                local featuresInRange = Spring.GetFeaturesInSphere(x, y, z, explosionStats.range)
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
