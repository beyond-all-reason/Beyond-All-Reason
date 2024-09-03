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

local timedDamageWeapons = {}
local unitDamageImmunity = {}
local aliveExplosions = {}

-- Params:
-- ceg - ceg to spawn when explosion happens
-- damageCeg - ceg to spawn when damage is dealt
-- time - how long the effect should stay
-- damage - damage per second
-- range - from center to edge, in elmos
-- resistance - defines which units are resistant to this type of damage when it matches with 'areadamageresistance' customparameter in a unit.

--------------------------------------------------------------------------------

function gadget:Initialize()
    local areaDamageTypes = {}
    for weaponDefID, weaponDef in ipairs(WeaponDefs) do
        if weaponDef.customParams and weaponDef.customParams.area_onhit_ceg then
            local custom = weaponDef.customParams
            local params = {
                ceg        = custom.area_onhit_ceg,
                damageCeg  = custom.area_onhit_damageceg,
                resistance = string.lower(custom.area_onhit_resistance),
                damage     = tonumber(custom.area_onhit_damage),
                range      = tonumber(custom.area_onhit_range),
                time       = tonumber(custom.area_onhit_time),
            }
            if params.resistance then
                areaDamageTypes[params.resistance] = true
            else
                params.resistance = "none"
            end
            timedDamageWeapons[weaponDefID] = params
        end
    end
    for unitDefID, unitDef in ipairs(UnitDefs) do
        if unitDef.customParams.area_ondeath_ceg then
            local custom = unitDef.customParams
            local params = {
                ceg        = custom.area_ondeath_ceg,
                damageCeg  = custom.area_ondeath_damageceg,
                resistance = string.lower(custom.area_onhit_resistance),
                damage     = tonumber(custom.area_ondeath_damage),
                range      = tonumber(custom.area_ondeath_range),
                time       = tonumber(custom.area_ondeath_time),
            }
            if params.resistance ~= nil then
                areaDamageTypes[params.resistance] = true
            else
                params.resistance = "none"
            end
            timedDamageWeapons[WeaponDefNames[unitDef.deathExplosion].id] = params
            timedDamageWeapons[WeaponDefNames[unitDef.selfDExplosion].id] = params
        end
    end

    for unitDefID, unitDef in ipairs(UnitDefs) do
        local immunities = {}
        if unitDef.canFly then
            immunities["all"] = true
        elseif unitDef.customParams.areadamageresistance then
            local resistance = string.lower(unitDef.customParams.areadamageresistance)
            for damageType in pairs(areaDamageTypes) do
                if string.find(resistance, damageType, nil, true) then
                    immunities[damageType] = true
                end
            end
        end
        unitDamageImmunity[unitDefID] = immunities
    end

    if next(timedDamageWeapons) then
        for weaponDefID in pairs(timedDamageWeapons) do
            Script.SetWatchExplosion(weaponDefID, true)
        end
    else
        Spring.Log(gadget:GetInfo().name, LOG.INFO, "No timed areas found. Removing gadget.")
        gadgetHandler:RemoveGadget(self)
    end
end

function gadget:Explosion(weaponDefID, px, py, pz, attackerID, projectileID)
    if timedDamageWeapons[weaponDefID] ~= nil then
        local explosion = timedDamageWeapons[weaponDefID]
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
                owner = attackerID,
                weapon = weaponDefID,
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
                local damageType = explosionStats.resistance

                Spring.SpawnCEG(explosionStats.ceg, x, y + 8, z, 0, 0, 0)

                local unitsInRange = Spring.GetUnitsInSphere(x, y, z, explosionStats.range)
                for j = 1,#unitsInRange do
                    local unitID = unitsInRange[j]
                    local unitImmunities = unitDamageImmunity[Spring.GetUnitDefID(unitID)]
                    if not unitImmunities.all and not unitImmunities[damageType] then
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
