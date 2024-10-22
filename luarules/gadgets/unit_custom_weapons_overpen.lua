function gadget:GetInfo()
    return {
        name    = 'Impactor Over-Penetration',
        desc    = 'Projectiles punch through targets with custom stop behavior.',
        author  = 'efrec',
        version = '1.0',
        date    = '2024-09',
        license = 'GNU GPL, v2 or later',
        layer   = 0,
        enabled = true
    }
end

if not gadgetHandler:IsSyncedCode() then return false end


--------------------------------------------------------------------------------
-- Configuration ---------------------------------------------------------------

local damageThreshold  = 0.1 -- Minimum damage% (vs. target health) that can overpen.
local explodeThreshold = 0.3 -- Minimum damage% that detonates, rather than piercing.
local hardStopIncrease = 2.0 -- Reduces the impulse falloff when damage is reduced.
local maxVisualLatency = 0.075 -- Max time spent in non-existence before respawning.

--------------------------------------------------------------------------------
--
--    customparams = {
--        overpen         := true
--        overpen_falloff := <boolean> | nil (see defaults)
--        overpen_slowing := <boolean> | nil (see defaults)
--        overpen_penalty := <number> | nil (see defaults)
--        overpen_exp_def := <string> | nil
--        overpen_pen_def := <string> | nil
--    }
--
--    ┌─────────────────────────┐
--    │ With hardStopIncrease=2 │
--    ├──────────────┬──────────┤
--    │  Damage Left │  Inertia │    Inertia is used as the impact force
--    │        100%  │    100%  │    and as the leftover projectile speed.
--    │         90%  │     96%  │
--    │         75%  │     90%  │
--    │         50%  │     75%  │ -- e.g. when a penetrator deals half its
--    │         25%  │     50%  │    max damage, it deals 75% max impulse.
--    │         10%  │     25%  │
--    │          0%  │      0%  │
--    └──────────────┴──────────┘
--
--    If you're motivated to know, this gives a new, effective impulse factor
--    equal to the weapon's base impulse factor * (inertia / damage left). This
--    value increases quickly near 0% damage remaining, so the overpen_penalty
--    should be set > 0.01 or so to keep lightweight targets from going flying.
--
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Locals ----------------------------------------------------------------------

local floor = math.floor
local min   = math.min
local max   = math.max
local sqrt  = math.sqrt
local atan  = math.atan
local cos   = math.cos

local spGetProjectileDirection  = Spring.GetProjectileDirection
local spGetProjectilePosition   = Spring.GetProjectilePosition
local spGetProjectileTimeToLive = Spring.GetProjectileTimeToLive
local spGetProjectileVelocity   = Spring.GetProjectileVelocity
local spGetUnitHealth           = Spring.GetUnitHealth
local spGetUnitPosition         = Spring.GetUnitPosition
local spGetUnitRadius           = Spring.GetUnitRadius
local spSpawnExplosion          = Spring.SpawnExplosion
local spSpawnProjectile         = Spring.SpawnProjectile

local gameSpeed  = Game.gameSpeed
local mapGravity = Game.gravity / gameSpeed / gameSpeed * -1

--------------------------------------------------------------------------------
-- Setup -----------------------------------------------------------------------

local maxLatency = maxVisualLatency * gameSpeed

-- Find all weapons with an over-penetration behavior.

local weaponParams
local explosionParams
local unitArmorType

-- Keep track of drivers, penetrators, and remaining damage.

local drivers
local respawn
local waiting
local gameFrame

--------------------------------------------------------------------------------
-- Local functions -------------------------------------------------------------

local function loadOverpenWeapons()
    local falseSet = { [false] = true, ["false"] = true, ["0"] = true, [0] = true }
    local penaltyDefault  = 0.02    -- Additional damage% loss per hit.
    local falloffPerType  = {       -- Whether the projectile loses damage per hit.
        DGun              = false ,
        Cannon            = true  ,
        LaserCannon       = true  ,
        BeamLaser         = true  ,
     -- LightningCannon   = false , -- Use customparams.spark_forkdamage instead.
     -- Flame             = false , -- Use customparams.single_hit_multi instead.
        MissileLauncher   = true  ,
        StarburstLauncher = true  ,
        TorpedoLauncher   = true  ,
        AircraftBomb      = true  ,
    }
    local slowdownPerType = {       -- Whether penetrators lose velocity, as well.
        DGun              = false ,
        Cannon            = true  ,
        LaserCannon       = false ,
        BeamLaser         = false ,
     -- LightningCannon   = false , -- Use customparams.spark_forkdamage instead.
     -- Flame             = false , -- Use customparams.single_hit_multi instead.
        MissileLauncher   = true  ,
        StarburstLauncher = true  ,
        TorpedoLauncher   = true  ,
        AircraftBomb      = true  ,
    }

    weaponParams = {}
    explosionParams = {}

    local weaponDefBaseIndex = 0
    for weaponDefID = weaponDefBaseIndex, #WeaponDefs do
        local weaponDef = WeaponDefs[weaponDefID]
        if weaponDef.customParams.overpen then
            local custom = weaponDef.customParams
            local params = {
                damages = weaponDef.damages,
                falloff = (custom.overpen_falloff == nil and falloffPerType[weaponDef.type]
                          or not falseSet[custom.overpen_falloff]) and true or nil,
                slowing = (custom.overpen_slowing == nil and slowdownPerType[weaponDef.type]
                          or not falseSet[custom.overpen_slowing]) and true or nil,
                penalty = tonumber(custom.overpen_penalty) or penaltyDefault,
            }
            if custom.overpen_exp_def then
                local expDefID = (WeaponDefNames[custom.overpen_exp_def] or weaponDef).id
                if expDefID ~= weaponDefID then
                    params.expDefID = expDefID
                end
            end
            if custom.overpen_pen_def then
                local penDefID = (WeaponDefNames[custom.overpen_pen_def] or weaponDef).id
                if penDefID ~= weaponDefID then
                    params.penDefID = penDefID
    
                    local driverVelocity = weaponDef.weaponvelocity
                    local penDefVelocity = WeaponDefs[penDefID].weaponvelocity
                    params.velRatio = penDefVelocity / driverVelocity
    
                    local driverLifetime = weaponDef.flighttime            or 3 * gameSpeed
                    local penDefLifetime = WeaponDefs[penDefID].flighttime or 3 * gameSpeed
                    params.ttlRatio = penDefLifetime / driverLifetime
                end
            end
            weaponParams[weaponDefID] = params
        end
    end

    local explosionDefaults = {
        craterAreaOfEffect   = 0,
        damageAreaOfEffect   = 0,
        edgeEffectiveness    = 0,
        explosionSpeed       = 0,
        gfxMod               = 0,
        maxGroundDeformation = 0,
        impactOnly           = false,
        ignoreOwner          = false,
        damageGround         = false,
    }

    for driverDefID, params in pairs(weaponParams) do
        if params.expDefID ~= nil then
            local expDefID = params.expDefID
            local expDef = WeaponDefs[expDefID]

            local cached = {
                weaponDef          = expDefID,
                damages            = expDef.damages,
                damageAreaOfEffect = expDef.damageAreaOfEffect,
                edgeEffectiveness  = expDef.edgeEffectiveness,
                explosionSpeed     = expDef.explosionSpeed,
                ignoreOwner        = expDef.noSelfDamage and true or nil,
                damageGround       = true,
                craterAreaOfEffect = expDef.craterAreaOfEffect,
                impactOnly         = expDef.impactOnly and true or nil,
                hitFeature         = expDef.impactOnly and -1 or nil,
                hitUnit            = expDef.impactOnly and -1 or nil,
                projectileID       = -1,
                owner              = -1,
            }

            for key, value in pairs(explosionDefaults) do
                if cached[key] == value then
                    cached[key] = nil
                end
            end

            explosionParams[expDefID] = cached
        end
    end

    return (next(weaponParams) ~= nil)
end

---Translate the remaining energy of a projectile to its speed and impulse.
local function inertia(damageLeft)
    local modifier = hardStopIncrease
    return (1 + modifier) / (1 + modifier * damageLeft)
end

---Create an explosion around the impact point of a driver (with an expDef).
local function explodeDriver(projID, expDefID, attackID, unitID, featureID)
    local px, py, pz = spGetProjectilePosition(projID)
    local dx, dy, dz = spGetProjectileDirection(projID)
    local explosion = explosionParams[expDefID]
    explosion.owner = attackID
    explosion.projectileID = projID
    if explosion.impactOnly then
        explosion.hitFeature = featureID
        explosion.hitUnit = unitID
    end
    spSpawnExplosion(px, py, pz, dx, dy, dz, explosion)
end

---Remove an impactor from tracking and determine its effect on the target.
local function overpenDamage(unitID, unitDefID, featureID, damage, projID, attackID)
    local driver = drivers[projID]
    drivers[projID] = nil

    local weaponData = driver[1]
    local damageLeft = driver[2]

    local health, healthMax, damageType
    if unitID then
        health, healthMax = spGetUnitHealth(unitID)
        damageType = weaponData.damages[unitArmorType[unitDefID]]
    elseif featureID then
        health, healthMax = Spring.GetFeatureHealth(unitID)
        damageType = weaponData.damages[0]
    end
    local damageBase = min(damage, damageType)

    if weaponData.falloff then
        damage = damage * damageLeft
        damageBase = damageBase * damageLeft
        damageLeft = damageLeft - health / damageBase - weaponData.penalty

        if weaponData.expDefID and damageLeft <= explodeThreshold then
            explodeDriver(projID, weaponData.expDefID, attackID, unitID, featureID)
            return damage
        end
    end

    if damageBase > health and damageBase >= healthMax * damageThreshold then
        if damageLeft > 0 then
            if weaponData.falloff then
                driver[2] = damageLeft
            end
            respawn[projID] = driver
        end
        return damage
    elseif weaponData.expDefID then
        explodeDriver(projID, weaponData.expDefID, attackID, unitID, featureID)
        return damage
    end

    local damageDone = min(1, damageBase / damageType)
    return damage, inertia(damageDone) * damageDone
end

---Simulate the overpen effect by creating a new projectile.
local function spawnPenetrator(projID, attackID, penDefID, unitID, featureID)
    local penetrator = respawn[projID]
    respawn[projID] = nil

    local px, py, pz = spGetProjectilePosition(projID)
    local timeToLive = spGetProjectileTimeToLive(projID)
    local vx, vy, vz, vw = spGetProjectileVelocity(projID)

    local driverData = penetrator[1]
    local explodeID = driverData.expDefID

    if driverData.slowing ~= nil then
        local speedLeft = inertia(penetrator[2])
        vx, vy, vz, vw = vx * speedLeft,
                         vy * speedLeft,
                         vz * speedLeft,
                         vw * speedLeft
    end

    if driverData.penDefID ~= nil then
        -- Spawn an alternative weapondef:
        penDefID = driverData.penDefID
        timeToLive = timeToLive * driverData.ttlRatio
        local velRatio = driverData.velRatio
        vx, vy, vz, vw = vx * velRatio,
                         vy * velRatio,
                         vz * velRatio,
                         vw * velRatio
        -- Penetrators may or may not be drivers, themselves:
        penetrator[1] = weaponParams[penDefID] -- nil if not
    end

    local mx, my, mz, radius
    if unitID ~= nil then
        local _
        _, _, _, mx, my, mz = spGetUnitPosition(unitID, true)
        radius = spGetUnitRadius(unitID)
    elseif featureID ~= nil then
        local _
        _, _, _, mx, my, mz = Spring.GetFeaturePosition(featureID, true)
        radius = Spring.GetFeatureRadius(featureID)
    end

    -- Get the time to travel to a position opposite the target's sphere collider.
    local frames = (radius / vw) * (cos(atan((mx - px) / radius - vx / vw)) +
                                    cos(atan((my - py) / radius - vy / vw)) +
                                    cos(atan((mz - pz) / radius - vz / vw))) * 2/3

    if frames < timeToLive and frames < maxLatency then
        local spawnParams = {
            gravity = mapGravity,
            owner   = attackID or penetrator[4],
            pos     = { px + frames * vx, py + frames * vy, pz + frames * vz },
            speed   = { vx, vy - mapGravity * 0.5 * frames ^ 2, vz },
            ttl     = timeToLive,
        }

        -- Penetrators use ultra-naive prediction error to jump to the next frame,
        -- even when their travel time to the spawn point is miniscule. We have no
        -- other way to prevent fast penetrators from tunneling target-to-target,
        -- for as long as there are targets, without passing any frames between.

        local predict = frames + penetrator[3] -- Cumulative prediction error.

        if predict < 0.5 then
            local spawnID = spSpawnProjectile(penDefID, spawnParams)
            if spawnID ~= nil and penetrator[1] then
                penetrator[3] = predict -- Time gain => increase error
                drivers[spawnID] = penetrator
            end
        else
            spawnParams.ttl = timeToLive - predict -- Time loss => forward error
            if penetrator[1] then
                penetrator[3] = 0 -- => reset error
                waiting[#waiting+1] = { gameFrame + predict, penDefID, spawnParams, penetrator }
            else
                waiting[#waiting+1] = { gameFrame + predict, penDefID, spawnParams }
            end
        end
    elseif explodeID ~= nil then
        explodeDriver(projID, explodeID, attackID, unitID, featureID)
    end
end

--------------------------------------------------------------------------------
-- Gadget call-ins -------------------------------------------------------------

function gadget:Initialize()
    if not loadOverpenWeapons() then
        Spring.Log(gadget:GetInfo().name, LOG.INFO,
            "No weapons with over-penetration found. Removing.")
        gadgetHandler:RemoveGadget(self)
        return
    end

    for weaponDefID, params in pairs(weaponParams) do
        Script.SetWatchProjectile(weaponDefID, true)
    end

    unitArmorType = {}
    for unitDefID, unitDef in ipairs(UnitDefs) do
        unitArmorType[unitDefID] = unitDef.armorType
    end

    drivers = {}
    respawn = {}
    waiting = {}
    gameFrame = Spring.GetGameFrame()
end

function gadget:GameFrame(frame)
    local checkFrame = frame + 0.5
    for index, spawnParams in pairs(waiting) do
        if spawnParams[1] <= checkFrame then
            local spawnID = spSpawnProjectile(spawnParams[2], spawnParams[3])
            if spawnID and spawnParams[4] then
                drivers[spawnID] = spawnParams[4]
            end
            waiting[index] = nil
        end
    end
    gameFrame = frame
end

function gadget:ProjectileCreated(projID, ownerID, weaponDefID)
    if weaponParams[weaponDefID] and not drivers[projID] then
        -- driver entry = { params, damageLeft%, frameError, ownerID }
        drivers[projID] = { weaponParams[weaponDefID], 1, 0, ownerID }
    end
end

function gadget:ProjectileDestroyed(projID)
    if drivers[projID] ~= nil then
        local driver = drivers[projID]
        local expDefID = driver[1].expDefID
        if expDefID ~= nil then
            explodeDriver(projID, expDefID, driver[4])
        end
        drivers[projID] = nil
    end
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam,
    damage, paralyzer, weaponDefID, projID, attackID, attackDefID, attackTeam)
    if drivers[projID] ~= nil then
        return overpenDamage(unitID, unitDefID, nil, damage, projID, attackID)
    end
end

function gadget:FeaturePreDamaged(featureID, featureDefID, featureTeam,
        damage, weaponDefID, projectileID, attackID, attackDefID, attackTeam)
    if drivers[projID] ~= nil then
        return overpenDamage(nil, nil, featureID, damage, projID, attackID)
    end
end

function gadget:UnitDamaged(unitID, unitDefID, unitTeam,
    damage, paralyzer, weaponDefID, projID, attackID, attackDefID, attackTeam)
    if respawn[projID] ~= nil and damage > 0 then
        spawnPenetrator(projID, attackID, weaponDefID, unitID, nil)
    end
end

function gadget:FeatureDamaged(featureID, featureDefID, featureTeam,
    damage, weaponDefID, projectileID, attackID, attackDefID, attackTeam)
    if respawn[projID] ~= nil and damage > 0 then
        spawnPenetrator(projID, attackID, weaponDefID, nil, featureID)
    end
end
