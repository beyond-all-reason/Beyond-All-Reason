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
-- Configuration ---------------------------------------------------------------

local damageInterval = 0.7333
local areaSizePresets = {
    37.5,  46,  54,  63,  75,
      88, 100, 125, 150, 175,
     200, 225, 250, 275, 300,
}

-- Defaults and customparams
local prefixes = { unit = 'area_ondeath_', weapon = 'area_onhit_' }
local damage, time, range, resistance = 30, 10, 75, "none"

--------------------------------------------------------------------------------
-- Local variables -------------------------------------------------------------

-- Params:
-- ceg - ceg to spawn when explosion happens
-- damageCeg - ceg to spawn when damage is dealt
-- time - how long the effect should stay
-- damage - damage per second
-- range - from center to edge, in elmos
-- resistance - defines which units are resistant to this type of damage when it matches with 'areadamageresistance' customparameter in a unit.
local timedDamageWeapons
local unitDamageImmunity

local aliveExplosions
local frameExplosions
local gameFrame
local frameIndex

damageInterval = math.round(Game.gameSpeed * damageInterval)

--------------------------------------------------------------------------------
-- Local functions -------------------------------------------------------------

local function getExplosionParams(def, prefix)
    local params = {
        ceg        = def.customParams[ prefix.."ceg"        ],
        damageCeg  = def.customParams[ prefix.."damageceg"  ],
        resistance = def.customParams[ prefix.."resistance" ] or resistance,
        damage     = def.customParams[ prefix.."damage"     ] or damage,
        frames     = def.customParams[ prefix.."time"       ] or time,
        range      = def.customParams[ prefix.."range"      ] or range,
    }
    params.damage = tonumber(params.damage) * (damageInterval/Game.gameSpeed)
    params.frames = tonumber(params.frames) * Game.gameSpeed
    params.frames = math.round(params.frames / damageInterval) * damageInterval
    params.range = tonumber(params.range)
    params.resistance = string.lower(params.resistance)
    return params
end

-- Change (eg) fire-area-150-repeating to fire-area-<range>-repeating for tweakdefs:
local sub1, sub2 = '-area-', '-repeating'
local pattern = sub1..'\d+'..sub2
local midX, midZ = Game.mapSizeX / 2, Game.mapSizeZ / 2
local lowY = Spring.GetGroundHeight(midX, midZ) - 10000
local function getNearestCEG(weaponDefID, params)
    local ceg, range = params.ceg, params.range
    local sizeBest, diffBest = math.huge, math.huge
    for ii = 1, #areaSizePresets do
        local size = areaSizePresets[ii]
        local diff = math.abs(range / size - size / range)
        if diff < diffBest then
            local cegTest = string.gsub(ceg, pattern, sub1..math.floor(sizeBest)..sub2)
            local success, cegID = Spring.SpawnCEG(cegTest, midX, lowY, midZ) -- hidden-ish
            if success and cegID then
                diffBest = diff
                sizeBest = size
            end
        end
    end
    if sizeBest < math.huge then
        ceg = string.gsub(ceg, '\d+', sizeBest, 1)
        return ceg, sizeBest
    end
end

--------------------------------------------------------------------------------
-- Gadget callins --------------------------------------------------------------

function gadget:Initialize()
    timedDamageWeapons = {}
    unitDamageImmunity = {}

    local weaponDefBaseIndex = 0
    for weaponDefID = weaponDefBaseIndex, #WeaponDefs do
        local weaponDef = WeaponDefs[weaponDefID]
        if weaponDef.customParams and weaponDef.customParams[prefixes.weapon.."ceg"] then
            timedDamageWeapons[weaponDefID] = getExplosionParams(weaponDef, prefixes.weapon)
        end
    end
    for unitDefID, unitDef in ipairs(UnitDefs) do
        if unitDef.customParams[prefixes.unit.."ceg"] then
            local params = getExplosionParams(unitDef, prefixes.unit)
            timedDamageWeapons[WeaponDefNames[unitDef.deathExplosion].id] = params
            timedDamageWeapons[WeaponDefNames[unitDef.selfDExplosion].id] = params
        end
    end

    for weaponDefID, params in pairs(timedDamageWeapons) do
        if  string.find(params.ceg, pattern, nil, false) and not
            string.find(params.ceg, sub1..math.floor(params.range)..sub2)
        then
            local ceg, range = getNearestCEG(weaponDefID, params)
            local name = WeaponDefs[weaponDefID].name
            if ceg and range then
                params.ceg = ceg
                params.range = range
                Spring.Log(gadget:GetInfo().name, LOG.INFO, 'Set '..name..' to range, ceg = '..params.range..', '..params.ceg)
            else
                timedDamageWeapons[weaponDefID] = nil
                Spring.Log(gadget:GetInfo().name, LOG.WARN, 'Removed '..name..' from area timed damage weapons.')
            end
        end
    end

    local areaDamageTypes = {}
    for weaponDefID, params in pairs(timedDamageWeapons) do
        if params.resistance == nil then
            params.resistance = "none"
        elseif params.resistance ~= "none" then
            areaDamageTypes[params.resistance] = true
        end
    end
    local immunities = { all = areaDamageTypes, none = {} }
    for unitDefID, unitDef in ipairs(UnitDefs) do
        local unitImmunity
        if unitDef.canFly or unitDef.armorType == Game.armorTypes.indestructible then
            unitImmunity = immunities.all
        elseif unitDef.customParams.areadamageresistance == nil then
            unitImmunity = immunities.none
        else
            local resistance = string.lower(unitDef.customParams.areadamageresistance)
            if immunities[resistance] then
                unitImmunity = immunities[resistance]
            else
                unitImmunity = {}
                for damageType in pairs(areaDamageTypes) do
                    if string.find(resistance, damageType, nil, false) then
                        unitImmunity[damageType] = true
                    end
                end
                if not next(unitImmunity) then
                    unitImmunity = immunities.none
                end
                immunities[resistance] = unitImmunity
            end
        end
        unitDamageImmunity[unitDefID] = unitImmunity
    end

    if next(timedDamageWeapons) then
        for weaponDefID in pairs(timedDamageWeapons) do
            Script.SetWatchExplosion(weaponDefID, true)
        end
        aliveExplosions = {}
        for ii = 1, damageInterval do
            aliveExplosions[ii] = {}
        end
        gameFrame = Spring.GetGameFrame()
        frameIndex = 1 + (gameFrame % damageInterval)
        frameExplosions = aliveExplosions[frameIndex]
    else
        Spring.Log(gadget:GetInfo().name, LOG.INFO, "No timed areas found. Removing gadget.")
        gadgetHandler:RemoveGadget(self)
    end
end

function gadget:Explosion(weaponDefID, px, py, pz, attackerID, projectileID)
    if timedDamageWeapons[weaponDefID] ~= nil then
        local explosion = timedDamageWeapons[weaponDefID]
        local elevation = math.max(Spring.GetGroundHeight(px, pz), 0)
        if py <= elevation + explosion.range then
            local dx, dy, dz
            if elevation > 0 then
                dx, dy, dz = Spring.GetGroundNormal(px, pz)
            else
                dx, dy, dz = 0, 1, 0
            end

            frameExplosions[#frameExplosions+1] = {
                x = px,
                y = elevation,
                z = pz,
                dx = dx,
                dy = dy,
                dz = dz,
                endFrame = gameFrame + explosion.frames,
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
    offset = 1 + (frame % damageInterval)
    local explosions = aliveExplosions[offset]
    for explosionID, explosionStats in pairs(explosions) do
        if explosionStats.endFrame >= frame then
            local x = explosionStats.x
            local y = explosionStats.y
            local z = explosionStats.z
            local damage = explosionStats.damage
            local damageType = explosionStats.resistance

            Spring.SpawnCEG(explosionStats.ceg, x, y + 8, z, explosionStats.dx, explosionStats.dy, explosionStats.dz)

            local unitsInRange = Spring.GetUnitsInSphere(x, y, z, explosionStats.range)
            for j = 1,#unitsInRange do
                local unitID = unitsInRange[j]
                if not unitDamageImmunity[Spring.GetUnitDefID(unitID)][damageType] then
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
        else
            explosions[explosionID] = nil
        end
    end

    gameFrame = frame
    frameIndex = offset
    frameExplosions = explosions
end
