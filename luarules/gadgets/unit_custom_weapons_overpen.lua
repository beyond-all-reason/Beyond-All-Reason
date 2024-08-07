function gadget:GetInfo()
    return {
        name    = 'Target Over-Penetration',
        desc    = 'Allows projectiles to pass through targets with customizable behavior.',
        author  = 'efrec',
        version = 'alpha',
        date    = '2024-07',
        license = 'GNU GPL, v2 or later',
        layer   = 0,
        enabled = true
    }
end

if not gadgetHandler:IsSyncedCode() then return false end


--------------------------------------------------------------------------------
-- Configuration ---------------------------------------------------------------

local damageThreshold  = 0.1     -- A percentage. Minimum damage that can overpen; a tad multipurpose.
local explodeThreshold = 0.1     -- A percentage. Minimum damage that detonates, rather than peircing.
local impulseArrested  = 1.7     -- A coefficient. Reduces the impulse falloff when damage is reduced.
local overpenDuration  = 3       -- In seconds. Time-to-live or flight time of re-spawned projectiles.

-- Customparam defaults --------------------------------------------------------

local penaltyDefault  = 0.02     -- A percentage. Additional damage falloff per each over-penetration.
local falloffPerType  = {        -- Whether the projectile deals reduced damage after each hit/pierce.
    DGun              = false ,
    Cannon            = true  ,
    LaserCannon       = true  ,
    BeamLaser         = true  ,
    LightningCannon   = false ,
 -- Flame             = false ,
 -- MissileLauncher   = false ,
 -- StarburstLauncher = false ,
 -- TorpedoLauncher   = false ,
 -- AircraftBomb      = false ,
}

--------------------------------------------------------------------------------
--
--    customparams = {
--        overpen          = true,  -- << Required
--        overpen_falloff  = <boolean> | see defaults,
--        overpen_penalty  = <number>  | see defaults,
--        overpen_with_def = <string>  | respawns the same def,
--        overpen_expl_def = <string>  | none,
--    }
--
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- Locals ----------------------------------------------------------------------

local min  = math.min
local sqrt = math.sqrt
local cos  = math.cos
local atan = math.atan

local spGetProjectileDirection  = Spring.GetProjectileDirection
local spGetProjectilePosition   = Spring.GetProjectilePosition
local spGetProjectileTimeToLive = Spring.GetProjectileTimeToLive
local spGetProjectileVelocity   = Spring.GetProjectileVelocity
local spGetUnitHealth           = Spring.GetUnitHealth
local spGetUnitPosition         = Spring.GetUnitPosition
local spGetUnitRadius           = Spring.GetUnitRadius
local spSpawnExplosion          = Spring.SpawnExplosion
local spSpawnProjectile         = Spring.SpawnProjectile


--------------------------------------------------------------------------------
-- Setup -----------------------------------------------------------------------

-- Find all weapons with an over-penetration behavior.

local weaponParams = {}

for weaponDefID, weaponDef in ipairs(WeaponDefs) do
    if weaponDef.customParams.overpen then
        local custom = weaponDef.customParams
        local params = {}

        params.damages = weaponDef.damages[0] > 1
                         and weaponDef.damages[0]
                          or weaponDef.damages[Game.armorTypes.vtol]
        params.penalty = tonumber(custom.overpen_penalty) or penaltyDefault
        params.falloff = (custom.overpen_falloff == "true" or custom.overpen_falloff == "1")
                      or (custom.overpen_falloff == nil and falloffPerType[weaponDef.type])

        if custom.overpen_with_def then
            -- The weapon uses separate driver/penetrator projectiles.
            local penDefID = (WeaponDefNames[custom.overpen_with_def] or weaponDef).id
            if penDefID ~= weaponDefID then
                params.penDefID = penDefID

                local driverVelocity = weaponDef.weaponvelocity
                local penDefVelocity = WeaponDefs[penDefID].weaponvelocity
                params.velRatio = penDefVelocity / driverVelocity

                local driverLifetime = weaponDef.flighttime            or overpenDuration * Game.gameSpeed
                local penDefLifetime = WeaponDefs[penDefID].flighttime or overpenDuration * Game.gameSpeed
                params.ttlRatio = penDefLifetime / driverLifetime
            end
        end

        if custom.overpen_expl_def then
            -- When the weapon fails to overpen, it explodes as this alt weapondef.
            -- This can add damage or just visuals to show the projectile stopping.
            -- Use the overpen penalty and falloff to tune the explosion threshold.
            local expDefID = (WeaponDefNames[custom.overpen_expl_def] or weaponDef).id
            if expDefID ~= weaponDefID then
                params.expDefID = expDefID
            end
        end

        weaponParams[weaponDefID] = params
    end
end

-- Cache the table params for SpawnExplosion.

local explosionCaches = {}

for driverDefID, params in pairs(weaponParams) do
    if params.expDefID then
        local expDefID = params.expDefID
        local expDef = WeaponDefs[expDefID]

        explosionCaches[expDefID] = {
            weaponDef = expDefID,
            damages   = table.copy(expDef.damages),

            craterAreaOfEffect = expDef.craterAreaOfEffect,
            damageAreaOfEffect = expDef.damageAreaOfEffect,
            edgeEffectiveness  = expDef.edgeEffectiveness,
            explosionSpeed     = expDef.explosionSpeed,
            ignoreOwner        = expDef.noSelfDamage,

            damageGround       = true,
            hitUnit            = 1,
            hitFeature         = 1,

            projectileID       = -1,
            owner              = -1,
        }
    end
end

-- Keep track of drivers, penetrators, and remaining damage.

local drivers = {}
local respawn = {}

local spawnCache = {
    pos     = { 0, 0, 0 },
    speed   = { 0, 0, 0 },
    ttl     = overpenDuration * Game.gameSpeed,
    gravity = -1 * Game.gravity / Game.gameSpeed / Game.gameSpeed,
}


--------------------------------------------------------------------------------
-- Functions -------------------------------------------------------------------

local function explodeDriver(projID, expDefID, attackID)
    local px, py, pz = spGetProjectilePosition(projID)
    local dx, dy, dz = spGetProjectileDirection(projID)
    local explosion = explosionCaches[expDefID]
    explosion.owner = attackID
    explosion.projectileID = projID
    spSpawnExplosion(px, py, pz, dx, dy, dz, explosion)
end

local function consumeDriver(projID, unitID, damage, attackID)
    local driver = drivers[projID]
    drivers[projID] = nil

    local health, healthMax = spGetUnitHealth(unitID)
    if not health then health, healthMax = 0, 0 end

    local weaponData = driver[1]
    local damageLeft = driver[2]
    damage = damage * damageLeft
    damageLeft = damageLeft - health / weaponData.damages - weaponData.penalty

    local penetrate = damage >= health and damage >= healthMax * damageThreshold
    local explodeID = weaponData.expDefID

    if penetrate and (not explodeID or damageLeft > explodeThreshold) then
        driver[2] = weaponData.falloff and damageLeft or 1.00
        respawn[projID] = driver
        return damage
    end

    if explodeID then
        explodeDriver(projID, explodeID, attackID)
    end

    return damage,
           damageLeft * (1 + impulseArrested) / (1 + impulseArrested * damageLeft)
end

local function spawnPenetrator(projID, unitID, attackID, penDefID)
    local penetrator = respawn[projID]
    respawn[projID] = nil

    local px, py, pz = spGetProjectilePosition(projID)
    local timeToLive = spGetProjectileTimeToLive(projID)
    local vx, vy, vz, vw = spGetProjectileVelocity(projID)

    if penetrator[1].penDefID then
        -- Spawn an alternative weapondef:
        local driverData = penetrator[1]
        timeToLive = timeToLive * driverData.ttlRatio
        local velRatio = driverData.velRatio
        vx, vy, vz, vw = vx * velRatio,
                         vy * velRatio,
                         vz * velRatio,
                         vw * velRatio
        -- Which may or may not be a driver:
        penDefID = driverData.penDefID
        penetrator[1] = weaponParams[penDefID]
    end

    local _,_,_, mx, my, mz = spGetUnitPosition(unitID, true)
    local unitRadius = spGetUnitRadius(unitID)

    -- Without more checks, we don't know if the overpen'd unit leaves a wreck.
    -- A newly-spawned projectile would have to avoid instant recollision; also,
    -- we might need to move its "muzzle flash" position to avoid overlapping fx.
    -- 3D secant/raycast-type solvers are expensive in lua, so we just estimate.
    -- We wouldn't want to move an impossible distance in sub-frame time, anyway.
    local ex, ey, ez = (mx - px) / unitRadius - vx / vw,
                       (my - py) / unitRadius - vy / vw,
                       (mz - pz) / unitRadius - vz / vw
    local move = unitRadius / vw * (cos(atan(ex)) + cos(atan(ey)) + cos(atan(ez))) * (2/3)
    -- Since movement is sub-frame, which is scary, limit to a number of frames:
    move = min(1, move)

    local data = spawnCache
    data.owner = attackID
    data.pos = { px + move * vx, py + move * vy, pz + move * vz }
    data.speed = { vx, vy, vz }
    data.ttl = timeToLive

    local spawnID = spSpawnProjectile(penDefID, data)
    if penetrator[1] then
        drivers[spawnID] = penetrator
    end
end


--------------------------------------------------------------------------------
-- Gadget call-ins -------------------------------------------------------------

function gadget:Initialize()
    if not next(weaponParams) then
        Spring.Log(gadget:GetInfo().name, LOG.INFO,
            "No weapons with over-penetration found. Removing.")
        gadgetHandler:RemoveGadget(self)
    end

    for weaponDefID, params in ipairs(weaponParams) do
        Script.SetWatchProjectile(weaponDefID, true)
    end
end

function gadget:ProjectileCreated(projID, ownerID, weaponDefID)
    -- Detect penetrators only when initially fired:
    if weaponParams[weaponDefID] and not drivers[projID] then
        drivers[projID] = { weaponParams[weaponDefID], 1, ownerID }
    end
end

function gadget:ProjectileDestroyed(projID)
    -- Explode alternate expl_def on terrain hit, ttl end, etc:
    if drivers[projID] then
        local driver = drivers[projID]
        local expDefID = driver[1].expDefID
        if expDefID then
            explodeDriver(projID, expDefID, driver[3])
            drivers[projID] = nil
        end
    end
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam,
    damage, paralyzer, weaponDefID, projID, attackID, attackDefID, attackTeam)
    if drivers[projID] then
        return consumeDriver(projID, unitID, damage, attackID)
    end
end

function gadget:UnitDamaged(unitID, unitDefID, unitTeam,
    damage, paralyzer, weaponDefID, projID, attackID, attackDefID, attackTeam)
    if respawn[projID] then
        spawnPenetrator(projID, unitID, attackID, weaponDefID)
    end
end
