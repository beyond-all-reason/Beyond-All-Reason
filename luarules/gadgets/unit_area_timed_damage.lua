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

local timedDamageWeapons
local unitDamageImmunity
local aliveExplosions
local frameIndex

-- Params:
-- ceg - ceg to spawn when explosion happens
-- damageCeg - ceg to spawn when damage is dealt
-- time - how long the effect should stay
-- damage - damage per second
-- range - from center to edge, in elmos
-- resistance - defines which units are resistant to this type of damage when it matches with 'areadamageresistance' customparameter in a unit.

--------------------------------------------------------------------------------

function gadget:Initialize()
    timedDamageWeapons = {}
    unitDamageImmunity = {}

    for weaponDefID, weaponDef in ipairs(WeaponDefs) do
        if weaponDef.customParams and weaponDef.customParams.area_onhit_ceg then
            local custom = weaponDef.customParams
            local params = {
                ceg        = custom.area_onhit_ceg,
                damageCeg  = custom.area_onhit_damageceg,
                resistance = string.lower(custom.area_onhit_resistance),
                damage     = tonumber(custom.area_onhit_damage or 0) * (22/30),
                range      = tonumber(custom.area_onhit_range),
                time       = tonumber(custom.area_onhit_time),
            }
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
                damage     = tonumber(custom.area_ondeath_damage or 0) * (22/30),
                range      = tonumber(custom.area_ondeath_range),
                time       = tonumber(custom.area_ondeath_time),
            }
            timedDamageWeapons[WeaponDefNames[unitDef.deathExplosion].id] = params
            timedDamageWeapons[WeaponDefNames[unitDef.selfDExplosion].id] = params
        end
    end

    local areaCegSizes = { 37.5, 46, 54, 62.5, 75, 87.5, 100, 125, 150, 175, 200, 225, 250, 275, 300 }
    local areaDamageTypes = {}
    for weaponDefID, params in pairs(timedDamageWeapons) do
        -- Example how to tweak areas:
        -- for udid, udef in pairs(UnitDefs) do
        --     for name, wdef in pairs(udef.weapondefs or {}) do
        --         if wdef.customparams and wdef.customparams.area_onhit_ceg then
        --             wdef.customparams.area_onhit_time = 4
        --             wdef.customparams.area_onhit_range = 200
        --             wdef.projectiles = 1
        --             Spring.Echo('[unit_area_timed_damage] tweaked weapon '..wdef.name..' => '..table.toString(wdef.customparams))
        --         end
        --     end
        -- end
        -- While areas of effect are tweak-able, CEGs are not.
        -- Try to keep timed areas and their visuals in sync with one another:
        if not string.find(params.ceg, '-'..math.floor(params.range)..'-', nil, true) then
            local cegName = params.ceg
            local rangeNew = math.huge
            local diffBest = math.huge
            for ii = 1, #areaCegSizes do
                local diff = math.abs(params.range / areaCegSizes[ii] - areaCegSizes[ii] / params.range)
                if diff < diffBest then
                    local success, cegID = Spring.SpawnCEG(string.gsub(cegName, '\d+', rangeNew, 1), 0, -9e9, 0)
                    if cegID ~= nil then
                        diffBest = diff
                        rangeNew = areaCegSizes[ii]
                    else
                        Spring.Log(gadget:GetInfo().name, LOG.WARNING, 'Did not find CEG: ' .. string.gsub(cegName, params.range, rangeNew, 1))
                    end
                end
            end
            if rangeNew < math.huge then
                params.ceg = string.gsub(cegName, params.range, rangeNew, 1)
                params.range = rangeNew
                Spring.Log(gadget:GetInfo().name, LOG.INFO, 'Set '..WeaponDefs[weaponDefID].name..' to range, ceg = '..params.range..', '..params.ceg)
            else
                timedDamageWeapons[weaponDefID] = nil
                Spring.Log(gadget:GetInfo().name, LOG.INFO, 'Removed '..WeaponDefs[weaponDefID].name)
            end
        end

        if params.resistance ~= nil and params.resistance ~= "none" then
            areaDamageTypes[params.resistance] = true
        else
            params.resistance = "none"
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
        frameIndex = 1 + (Spring.GetGameFrame() % 22)
        aliveExplosions = {}
        for ii = 1, 22 do
            aliveExplosions[ii] = {}
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
            local frameExplosions = aliveExplosions[frameIndex]
            frameExplosions[#frameExplosions+1] = {
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
    frame = 1 + (frame % 22)
    local currentTime = Spring.GetGameSeconds()
    for explosionID, explosionStats in pairs(aliveExplosions[frame]) do
        if explosionStats.endTime >= currentTime then
            local x = explosionStats.x
            local y = explosionStats.y
            local z = explosionStats.z
            local damage = explosionStats.damage
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
            aliveExplosions[frame][explosionID] = nil
        end
    end
    frameIndex = frame
end
