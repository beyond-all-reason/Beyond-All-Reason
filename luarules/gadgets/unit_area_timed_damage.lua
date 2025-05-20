local gadget = gadget ---@type Gadget

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

-- Since I couldn't figure out totally arbitrary-radius variable CEGs for fire,
-- we're left with this static list, which is repeated in the expgen def files:
local areaSizePresets = {
    37.5,  46,  54,  63,  75,
      88, 100, 125, 150, 175,
     200, 225, 250, 275, 300,
}

-- Customparams and defaults:
local prefixes = { unit = 'area_ondeath_', weapon = 'area_onhit_' }
local damage, time, range, resistance = 30, 10, 75, "none"

--[[
    customparams = {
        <prefix>_damage     := <number>    The damage done per second
        <prefix>_time       := <number>    Duration of the timed area
        <prefix>_range      := <number>    The radius of the timed area
        <prefix>_damageCeg  := <ceg_name>  Spawns repeatedly for duration
        <prefix>_resistance := <string>    Matched against areadamageresistance
    }
    prefix := area_ondeath | area_onhit  Units use ondeath; weapons use onhit.

    When adding timed areas to existing weapons, you should tweak the weapon's
    explosion ceg, too. There's a short delay between the hit and the area ceg,
    which you can mask/make look nice with an explosion lasting about 0.5 secs.
]]--

--------------------------------------------------------------------------------
-- Cached globals --------------------------------------------------------------

local max                   = math.max
local spGetFeaturesInSphere = Spring.GetFeaturesInSphere
local spGetGroundHeight     = Spring.GetGroundHeight
local spGetGroundNormal     = Spring.GetGroundNormal
local spGetUnitDefID        = Spring.GetUnitDefID
local spGetUnitsInSphere    = Spring.GetUnitsInSphere
local spSpawnCEG            = Spring.SpawnCEG

--------------------------------------------------------------------------------
-- Local variables -------------------------------------------------------------

local frameInterval = math.round(Game.gameSpeed * damageInterval)
local frameCegShift = math.round(Game.gameSpeed * damageInterval * 0.5)

local timedDamageWeapons = {}
local unitDamageImmunity = {}

local aliveExplosions = {}
local frameExplosions = {}
local frameNumber = 0
local explosionCount = 0

local regexArea, regexRepeat = '%-area%-', '%-repeat'
local regexDigits = "%d+"
local regexCegRadius = regexArea..regexDigits..regexRepeat
local regexCegToRadius = regexArea.."("..regexDigits..")"..regexRepeat

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
    params.damage = tonumber(params.damage) * (frameInterval/Game.gameSpeed)
    params.frames = tonumber(params.frames) * Game.gameSpeed
    params.frames = math.round(params.frames / frameInterval) * frameInterval
    params.range = tonumber(params.range)
    params.resistance = string.lower(params.resistance)
    return params
end

local function getNearestCEG(params)
    local ceg, range = params.ceg, params.range

    -- We can't check properties of the ceg, so use the name to compare 'size'. Yes, "that is bad".
    if string.find(ceg, "-"..math.floor(range).."-", nil, true) then
        local _, _, _, namedRange = string.find(ceg, regexCegToRadius, nil, true)
        if tonumber(namedRange) == math.floor(range) then
            return ceg, range
        end
    end

    -- User tweaks have modified the ceg and/or range; update both to the best-fitting preset.
    local sizeBest, diffBest = math.huge, math.huge
    for ii = 1, #areaSizePresets do
        local size = areaSizePresets[ii]
        local diff = math.abs(range / size - size / range)
        if diff < diffBest then
            diffBest = diff
            sizeBest = size
        end
    end
    if sizeBest < math.huge then
        ceg = string.gsub(ceg, regexDigits, sizeBest, 1)
        return ceg, sizeBest
    end
end

local function addTimedExplosion(weaponDefID, px, py, pz, attackerID, projectileID)
    local explosion = timedDamageWeapons[weaponDefID]
    local elevation = max(spGetGroundHeight(px, pz), 0)
    if py <= elevation + explosion.range then
        local dx, dy, dz
        if elevation > 0 then
            dx, dy, dz = spGetGroundNormal(px, pz, true)
        end
        frameExplosions[#frameExplosions + 1] = {
            weapon     = weaponDefID,
            owner      = attackerID,
            x          = px,
            y          = elevation,
            z          = pz,
            dx         = dx,
            dy         = dy,
            dz         = dz,
            ceg        = explosion.ceg,
            range      = explosion.range,
            resistance = explosion.resistance,
            damage     = explosion.damage,
            damageCeg  = explosion.damageCeg,
            endFrame   = explosion.frames + frameNumber,
        }
        explosionCount = explosionCount + 1
    end
end

local function spawnAreaCEGs(loopIndex)
    for index, area in pairs(aliveExplosions[loopIndex]) do
        spSpawnCEG(area.ceg, area.x, area.y, area.z, area.dx, area.dy, area.dz)
    end
end

local function damageTargetsInAreas(timedAreas, gameFrame)
    for index, area in pairs(timedAreas) do
        local unitsInRange = spGetUnitsInSphere(area.x, area.y, area.z, area.range)
        for j = 1, #unitsInRange do
            local unitID = unitsInRange[j]
            if not unitDamageImmunity[spGetUnitDefID(unitID)][area.resistance] then
                local ux, uy, uz = Spring.GetUnitPosition(unitID)
                spSpawnCEG(area.damageCeg, ux, uy, uz)
                Spring.AddUnitDamage(unitID, area.damage, nil, area.owner, area.weapon)
            end
        end

        local featuresInRange = spGetFeaturesInSphere(area.x, area.y, area.z, area.range)
        for j = 1, #featuresInRange do
            local featureID = featuresInRange[j]
            local fx, fy, fz = Spring.GetFeaturePosition(featureID)
            spSpawnCEG(area.damageCeg, fx, fy, fz)
            local health = Spring.GetFeatureHealth(featureID) - area.damage
            if health > 1 then
                Spring.SetFeatureHealth(featureID, health)
            else
                Spring.DestroyFeature(featureID)
            end
        end

        if area.endFrame <= gameFrame then
            timedAreas[index] = nil
        end
    end
end

--------------------------------------------------------------------------------
-- Gadget callins --------------------------------------------------------------

function gadget:Initialize()
    timedDamageWeapons = {}
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

    -- This simplifies writing tweakdefs to modify area_on[x]_range for balance,
    -- e.g. setting all ranges to 80% their original amount will work correctly.
    for weaponDefID, params in pairs(timedDamageWeapons) do
        if string.find(params.ceg, regexCegRadius, nil, false) then
            local ceg, range = getNearestCEG(params)
            local name = WeaponDefs[weaponDefID].name
            if ceg and range then
                if params.ceg ~= ceg or params.range ~= range then
                    params.ceg = ceg
                    params.range = range
                    Spring.Log(gadget:GetInfo().name, LOG.INFO, 'Set '..name..' to range, ceg = '..range..', '..ceg)
                end
            else
                timedDamageWeapons[weaponDefID] = nil
                Spring.Log(gadget:GetInfo().name, LOG.WARN, 'Removed '..name..' from area timed damage weapons.')
            end
        end
    end

    unitDamageImmunity = {}
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
        for ii = 1, frameInterval do
            aliveExplosions[ii] = {}
        end
        frameNumber = Spring.GetGameFrame()
        frameExplosions = aliveExplosions[1 + (frameNumber % frameInterval)]
    else
        Spring.Log(gadget:GetInfo().name, LOG.INFO, "No timed areas found. Removing gadget.")
        gadgetHandler:RemoveGadget(self)
    end
end

function gadget:Explosion(weaponDefID, px, py, pz, attackerID, projectileID)
    if timedDamageWeapons[weaponDefID] then
        addTimedExplosion(weaponDefID, px, py, pz, attackerID, projectileID)
    end
end

function gadget:GameFrame(frame)
    local indexDamage = 1 + (frame % frameInterval)
    local indexExpGen = 1 + ((frame + frameCegShift) % frameInterval)
    local frameAreas = aliveExplosions[indexDamage]

    spawnAreaCEGs(indexExpGen)
    damageTargetsInAreas(frameAreas, frame)

    frameExplosions = frameAreas
    frameNumber = frame
end