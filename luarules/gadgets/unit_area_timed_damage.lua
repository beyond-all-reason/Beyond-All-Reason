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

local damageInterval = 0.7333 ---@type number in seconds, time between procs
local damageLimit = 100 ---@type number in damage per second, soft-cap across multiple areas
local damageExcessRate = 0.2 ---@type number %damage dealt above limit [0, 1)
local damageCegMinScalar = 30 ---@type number in damage, minimum to show hit CEG
local damageCegMinMultiple = 1 / 3 ---@type number in %damage, minimum to show hit CEG
local factoryWaitTime = damageInterval ---@type number in seconds, immunity period for factory-built units

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

local max                    = math.max
local min                    = math.min
local floor                  = math.floor

local spAddUnitDamage        = Spring.AddUnitDamage
local spGetFeatureHealth     = Spring.GetFeatureHealth
local spGetFeaturePosition   = Spring.GetFeaturePosition
local spGetFeaturesInSphere  = Spring.GetFeaturesInSphere
local spGetGroundHeight      = Spring.GetGroundHeight
local spGetGroundNormal      = Spring.GetGroundNormal
local spGetUnitDefID         = Spring.GetUnitDefID
local spGetUnitPosition      = Spring.GetUnitPosition
local spGetUnitsInSphere     = Spring.GetUnitsInSphere
local spSetFeatureHealth     = Spring.SetFeatureHealth
local spSpawnCEG             = Spring.SpawnCEG

local gameSpeed              = Game.gameSpeed

--------------------------------------------------------------------------------
-- Local variables -------------------------------------------------------------

local frameInterval = math.round(Game.gameSpeed * damageInterval)
local frameCegShift = math.round(Game.gameSpeed * damageInterval * 0.5)
local frameWaitTime = math.round(Game.gameSpeed * factoryWaitTime)

local timedDamageWeapons = {}
local unitDamageImmunity = {}
local featDamageImmunity = {}

local isFactory = {}
local isNewUnit = {}

local aliveExplosions = {}
local frameExplosions = {}
local frameNumber = 0

local unitDamageTaken = {}
local featDamageTaken = {}
local unitDamageReset = {}
local featDamageReset = {}

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

---The ordering of areas, if left arbitrary, penalizes high-damage areas.
---This gives a faster insert when ordering areas from low to high damage
---without favoring newly created areas (effectively penalizing duration).
local function bisectDamage(array, damage, low, high)
    if low < high then
        local indexMiddle = floor((low + high) * 0.5)
        local areaMiddle = array[indexMiddle]
        local damageMiddle = areaMiddle and areaMiddle.damage

        if damageMiddle then
            if damageMiddle == damage then
                return indexMiddle
            else
                if damageMiddle > damage then
                    high = indexMiddle - 1
                else
                    low = indexMiddle + 1
                end
                return bisectDamage(array, damage, low, high)
            end
        end
    end
    return low
end

local function addTimedExplosion(weaponDefID, px, py, pz, attackerID, projectileID)
    local explosion = timedDamageWeapons[weaponDefID]
    local elevation = max(spGetGroundHeight(px, pz), 0)
    if py <= elevation + explosion.range then
        local dx, dy, dz
        if elevation > 0 then
            dx, dy, dz = spGetGroundNormal(px, pz, true)
        end
        local area = {
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
        local index = bisectDamage(frameExplosions, area.damage, 1, #frameExplosions)
        table.insert(frameExplosions, index, area)
    end
end

local function spawnAreaCEGs(loopIndex)
    for index, area in pairs(aliveExplosions[loopIndex]) do
        spSpawnCEG(area.ceg, area.x, area.y, area.z, area.dx, area.dy, area.dz)
    end
end

---Applies a simple formula to keep damage under a limit when many areas of effect overlap.
---Stronger areas partially ignore the preset limit but not damage accumulation on the target.
---Damage may be reduced enough that the CEG effect for indicating damage should not be shown.
---@param incoming number The area weapon's damage to the target
---@param accumulated number The target's area damage taken in the current interval
---@return number damage
---@return boolean showDamageCeg
local function getLimitedDamage(incoming, accumulated)
    local ignoreLimit = max(0, incoming - damageLimit - accumulated)
    local belowLimit = max(0, min(damageLimit - accumulated, incoming))
    local aboveLimit = incoming - belowLimit - ignoreLimit

    local damage = ignoreLimit + belowLimit + aboveLimit * damageExcessRate

    return damage, damage >= incoming * damageCegMinMultiple or damage >= damageCegMinScalar
end

local function damageTargetsInAreas(timedAreas, gameFrame)
    local length = #timedAreas

    local resetNewUnit = {}
    local count = 0

    for index = length, 1, -1 do
        local area = timedAreas[index]
        local unitsInRange = spGetUnitsInSphere(area.x, area.y, area.z, area.range)
        for j = 1, #unitsInRange do
            local unitID = unitsInRange[j]
            if unitDamageImmunity[spGetUnitDefID(unitID)][area.resistance] == nil
                and isNewUnit[unitID] == nil
            then
                local damageTaken = unitDamageTaken[unitID]
                if not damageTaken then
                    damageTaken = 0
                    count = count + 1
                    resetNewUnit[count] = unitID
                end
                local damage, showDamageCeg = getLimitedDamage(area.damage, damageTaken)
                if showDamageCeg then
                    local ux, uy, uz = spGetUnitPosition(unitID)
                    spSpawnCEG(area.damageCeg, ux, uy, uz)
                end
                spAddUnitDamage(unitID, damage, nil, area.owner, area.weapon)
                unitDamageTaken[unitID] = damageTaken + damage
            end
        end
    end

    for _, unitID in ipairs(unitDamageReset[gameFrame]) do
        unitDamageTaken[unitID] = nil
    end

    unitDamageReset[gameFrame] = nil
    unitDamageReset[gameFrame + gameSpeed] = resetNewUnit

    local resetNewFeat = {}
    count = 0

    for index = length, 1, -1 do
        local area = timedAreas[index]
        local featuresInRange = spGetFeaturesInSphere(area.x, area.y, area.z, area.range)
        for j = 1, #featuresInRange do
            local featureID = featuresInRange[j]
            if not featDamageImmunity[featureID] then
                local damageTaken = featDamageTaken[featureID]
                if not damageTaken then
                    damageTaken = 0
                    count = count + 1
                    resetNewFeat[count] = featureID
                end
                local damage, showDamageCeg = getLimitedDamage(area.damage, damageTaken)
                if showDamageCeg then
                    local fx, fy, fz = spGetFeaturePosition(featureID)
                    spSpawnCEG(area.damageCeg, fx, fy, fz)
                end
                local health = spGetFeatureHealth(featureID) - damage
                if health > 1 then
                    spSetFeatureHealth(featureID, health)
                    featDamageTaken[featureID] = damageTaken + damage
                else
                    Spring.DestroyFeature(featureID)
                end
            end
        end

        if area.endFrame <= gameFrame then
            table.remove(timedAreas, index)
        end
    end

    for _, featID in ipairs(featDamageReset[gameFrame]) do
        featDamageTaken[featID] = nil
    end

    featDamageReset[gameFrame] = nil
    featDamageReset[gameFrame + gameSpeed] = resetNewFeat
end

local function removeFromArrays(arrays, value)
    for _, array in pairs(arrays) do
        for i = 1, #array do
            if value == array[i] then
                array[#array], array[i] = array[i], nil
                return
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Gadget callins --------------------------------------------------------------

function gadget:Initialize()
    timedDamageWeapons = {}
    for weaponDefID = 0, #WeaponDefs do
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
        if unitDef.isFactory then
            isFactory[unitDefID] = true
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

    featDamageImmunity = {}
    for _, featureID in ipairs(Spring.GetAllFeatures()) do
        local featureDefID = Spring.GetFeatureDefID(featureID)
        local featureDef = FeatureDefs[featureDefID]
        if featureDef.indestructible or featureDef.geoThermal then
            featDamageImmunity[featureID] = true
        end
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
        for frame = frameNumber - 1, frameNumber + gameSpeed do
            unitDamageReset[frame] = {}
            featDamageReset[frame] = {}
        end

        isNewUnit = {}
		local progressMax = 0.05 -- Assuming 20s build time. Any guess is fine (for /luarules reload).
		local beingBuilt, progress, health, healthMax, framesRemaining
        for _, unitID in ipairs(Spring.GetAllUnits()) do
            beingBuilt, progress = Spring.GetUnitIsBeingBuilt(unitID)
			health, healthMax = Spring.GetUnitHealth(unitID)
            if beingBuilt and min(progress, health / healthMax) <= progressMax then
                framesRemaining = frameInterval * (1 - 0.5 * min(progress, health / healthMax) / progressMax)
                isNewUnit[unitID] = frameNumber + max(1, framesRemaining)
            end
        end
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

    for unitID, expire in pairs(isNewUnit) do
        if expire > frame then
            isNewUnit[unitID] = nil
        end
    end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
    if isFactory[builderID] then
        isNewUnit[unitID] = frameNumber + frameWaitTime
    end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	isNewUnit[unitID] = nil
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
    if unitDamageTaken[unitID] then
        unitDamageTaken[unitID] = nil
        removeFromArrays(unitDamageReset, unitID)
    end
    isNewUnit[unitID] = nil
end

function gadget:FeatureDestroyed(featureID, allyTeam)
    if featDamageTaken[featureID] then
        featDamageTaken[featureID] = nil
        removeFromArrays(featDamageReset, featureID)
    end
end
