function gadget:GetInfo()
    return {
        name    = 'Cluster Munitions',
        desc    = 'Custom behavior for projectiles that explode and split on impact.',
        author  = 'efrec',
        version = '1.1',
        date    = '2024-06-07',
        license = 'GNU GPL, v2 or later',
        layer   = 10, -- preempt :Explosion handlers like fx_watersplash.lua that return `true` (not pure fx)
        enabled = true
    }
end

if not gadgetHandler:IsSyncedCode() then return false end

--------------------------------------------------------------------------------------------------------------
-- Configuration ---------------------------------------------------------------------------------------------

-- Default settings ------------------------------------------------------------------------------------------

local defaultSpawnDef = "cluster_munition"         -- def used, by default
local defaultSpawnNum = 5                          -- number of spawned projectiles, by default
local defaultSpawnTtl = 300                        -- detonate projectiles after time = ttl, by default
local defaultVelocity = 240                        -- speed of spawned projectiles, by default

-- General settings ------------------------------------------------------------------------------------------

local customParamName = "cluster"                  -- in the weapondef, the parameter name to set to `true`
local maxSpawnNumber  = 24                         -- protect game performance against stupid ideas
local minUnitBounces  = "armpw"                    -- smallest unit (name) that bounces projectiles at all
local minBulkReflect  = 64000                      -- smallest unit bulk that causes reflection as if terrain
local deepWaterDepth  = -40                        -- used for the surface deflection on water, lava, ...

-- CustomParams setup ----------------------------------------------------------------------------------------

--    primary_weapon = {
--        customparams = {
--            cluster  = true,
--           [def      = <string>,]
--           [number   = <integer>,]
--        },
--    },
--    cluster_munition | <def> = {
--       [maxvelocity = <number>,]
--       [range       = <number>,]
--    }

--------------------------------------------------------------------------------------------------------------
-- Localize --------------------------------------------------------------------------------------------------

local DirectionsUtil = VFS.Include("LuaRules/Gadgets/Include/DirectionsUtil.lua")

local abs   = math.abs
local max   = math.max
local min   = math.min
local rand  = math.random
local sqrt  = math.sqrt
local cos   = math.cos
local sin   = math.sin
local atan2 = math.atan2

local spGetGroundHeight  = Spring.GetGroundHeight
local spGetGroundNormal  = Spring.GetGroundNormal
local spGetUnitDefID     = Spring.GetUnitDefID
local spGetUnitPosition  = Spring.GetUnitPosition
local spGetUnitRadius    = Spring.GetUnitRadius
local spGetUnitsInSphere = Spring.GetUnitsInSphere
local spSpawnProjectile  = Spring.SpawnProjectile

local GAME_SPEED         = Game.gameSpeed
local mapGravity         = Game.gravity / GAME_SPEED / GAME_SPEED * -1

local SetWatchExplosion  = Script.SetWatchExplosion

--------------------------------------------------------------------------------------------------------------
-- Initialize ------------------------------------------------------------------------------------------------

-- Information table for cluster weapons

local spawnableTypes = {
    Cannon          = true  ,
    EMGCannon       = true  ,
    Fire            = false , -- but possible
    LightningCannon = false , -- but possible
    MissileLauncher = false , -- but possible
}

local dataTable      = {} -- Info on each cluster weapon
local wDefNamesToIDs = {} -- Says it on the tin

for wdid, wdef in pairs(WeaponDefs) do
    wDefNamesToIDs[wdef.name] = wdid

    if wdef.customParams and wdef.customParams[customParamName] then
        dataTable[wdid] = {}
        dataTable[wdid].number  = tonumber(wdef.customParams.number) or defaultSpawnNum
        dataTable[wdid].def     = wdef.customParams.def
        dataTable[wdid].projDef = -1
        dataTable[wdid].projTtl = defaultSpawnTtl
        dataTable[wdid].projVel = defaultVelocity / GAME_SPEED

        -- Enforce limits, eg the projectile count, at init.
        dataTable[wdid].number  = min(dataTable[wdid].number, maxSpawnNumber)

        -- When the cluster munition name isn't specified, search for the default.
        if dataTable[wdid].def == nil then
            local search = ''
            for word in string.gmatch(wdef.name, '([^_]+)') do
                search = search == '' and word or search .. '_' .. word
                if UnitDefNames[search] ~= nil then
                    dataTable[wdid].def = search .. '_' .. defaultSpawnDef
                end
            end
            -- There's still the chance we haven't found anything, so:
            if dataTable[wdid].def == nil then
                Spring.Echo('[clustermun] [warn] Did not find cluster munition for weapon id ' .. wdid)
                dataTable[wdid] = nil
            end
        end
    end
end

-- Information for cluster munitions

for wdid, data in pairs(dataTable) do
    local cmdid = wDefNamesToIDs[data.def]
    local cmdef = WeaponDefs[cmdid]

    dataTable[wdid].projDef = cmdid
    dataTable[wdid].projTtl = cmdef.ttl or defaultSpawnTtl

    -- Range and velocity are closely related so may be in disagreement. Average them (more or less):
    local projVel = cmdef.projectileSpeed or cmdef.startvelocity
    projVel = projVel and projVel * GAME_SPEED or defaultVelocity
    if cmdef.range > 10 then
        local rangeVel = sqrt(cmdef.range * abs(mapGravity)) -- inverse range calc for launch @ 45deg
        dataTable[wdid].projVel = (projVel + rangeVel) / 2
    else
        dataTable[wdid].projVel = projVel
    end

    -- Prevent the grenade apocalypse:
    if dataTable[cmdid] ~= nil then
        Spring.Echo('[clustermun] [warn] Preventing recursive explosions: ' .. cmdid)
        dataTable[cmdid] = nil
    end

    -- Remove unspawnable projectiles:
    if spawnableTypes[cmdef.type] ~= true then
        Spring.Echo('[clustermun] [warn] Invalid spawned weapon type: ' ..
            dataTable[wdid].def .. ' is not spawnable (' .. (cmdef.type or 'nil!') .. ')')
        dataTable[wdid] = nil
    end

    -- Remove invalid spawn counts:
    if data.number == nil or data.number <= 1 then
        Spring.Echo('[clusermun] [warn] Removing low-count cluster weapon: ' .. wdid)
        dataTable[wdid] = nil
    end
end

-- Information on units

local unitBulk = {} -- How sturdy the unit is. Projectiles scatter less with lower bulk values.

for udid, udef in pairs(UnitDefs) do
    -- Set the unit bulk values.
    -- todo: We don't even _detect_ walls. "Objectified" units aren't returned by GetUnitsInSphere?
    -- todo: Seems likely that the same goes for wall-like units, then.
    if udef.armorType == Game.armorTypes.wall or udef.armorType == Game.armorTypes.indestructible then
        unitBulk[udid] = 0.9
    elseif udef.customParams.neutral_when_closed then -- Dragon turrets
        unitBulk[udid] = 0.8
    else
        unitBulk[udid] = min(
            1.0,
            ((  udef.health ^ 0.5 +                         -- HP is log2-ish but that feels too tryhard
                udef.metalCost ^ 0.5 *                      -- Steel (metal) is heavier than feathers (energy)
                udef.xsize * udef.zsize * udef.radius ^ 0.5 -- People see 'bigger thing' as 'more solid'
            ) / minBulkReflect)                             -- Scaled against some large-ish bulk rating
        ) ^ 0.33                                            -- Raised to a low power to curve up the results
    end
end

local bulkMin = unitBulk[UnitDefNames[minUnitBounces].id] or minBulkReflect / 10
for udid, _ in pairs(UnitDefs) do
    if unitBulk[udid] < bulkMin then
        unitBulk[udid] = nil
    end
end

-- Reusable table for reducing garbage

local spawnCache  = {
    pos     = { 0, 0, 0 },
    speed   = { 0, 0, 0 },
    owner   = 0,
    ttl     = defaultSpawnTtl,
    gravity = mapGravity,
}

-- Set up preset direction vectors for scattering cluster projectiles.

local directions = DirectionsUtil.Directions
local maxDataNum = 2
for _, data in pairs(dataTable) do
    if data.number > maxDataNum then maxDataNum = data.number end
end
DirectionsUtil.ProvisionDirections(maxDataNum)

--------------------------------------------------------------------------------------------------------------
-- Functions -------------------------------------------------------------------------------------------------

local function GetSurfaceDeflection(ex, ey, ez)
    ---- Deflection away from terrain.
    local elevation = spGetGroundHeight(ex, ez)
    local x, y, z, m, distance
    -- Deep water doesn't care much about ground normals.
    -- Lava might have a shallower "deep" elevation. Idk.
    if elevation < deepWaterDepth then
        distance = ey - deepWaterDepth / 3 -- compress distance to fixed value
        x, y, z  = 0, 1, 0
    else
        distance = ey - elevation
        x, y, z, m = spGetGroundNormal(ex, ez, true)
        if m > 1e-2 then
            distance = distance * cos(m)                       -- Actual distance given a flat plane with slope m.
            m        = distance * sin(m) / sqrt(x * x + z * z) -- Shift to next ground intercept; normalize {x,z}.
            local xm, zm = ex - x * m, ez - z * m
            elevation = spGetGroundHeight(xm, zm) -- very likely a higher elevation than the previous
            x, y, z,_ = spGetGroundNormal(xm, zm, true)

            -- Shallow water produces a weaker terrain response,
            -- but uses a shorter distance (more response overall).
            if elevation <= 0 then
                -- compress distance to middle value
                elevation = max(spGetGroundHeight(xm, zm) / 2, deepWaterDepth / 3)
                x, z = x * 0.9, z * 0.9
                if y < 0.999999999 then y = 1 / sqrt(x*x + z*z) end
            end

            distance = min(distance, ey - elevation)
        end
    end
    distance = sqrt(max(1, distance))
    x, y, z  = 1.52*x/distance, 1.52*y/distance, 1.52*z/distance

    ---- Deflection away from unit colliders.
    -- This is used to keep grenades-of-grenades from detonating on contact instead of spreading out.
    -- We have to check a radius ~ge the largest collider so we are, otherwise, way-too efficient.
    -- That mostly means not checking and not rotating the unit's collider around in world space.
    local colliders = spGetUnitsInSphere(ex, ey, ez, 80)
    local udefid, bounce, ux, uy, uz, uw, radius
    for _, uid in ipairs(colliders) do
        udefid = spGetUnitDefID(uid)
        bounce = unitBulk[udefid]
        if bounce ~= nil then
            -- Assuming spherical collider in frictionless vacuum
            _,_,_,ux,uy,uz = spGetUnitPosition(uid, true)
            radius         = spGetUnitRadius(uid)
            if uy + radius > 0 then
                ux, uy, uz = ex-ux, ey-uy, ez-uz
                distance   = ux*ux + uy*uy + uz*uz -- just going to reuse this var a lot
                uw         = distance / radius
                distance   = sqrt(distance)

                -- We allow wiggle room since our colliders are not spheres
                if uw <= 1.24 * distance then
                    distance = max(1, distance / radius)
                    -- Even with a bunch of transcendentals, the perf isn't so bad.
                    local th_z = atan2(ux, uz)
                    local ph_y = atan2(uy, sqrt(ux*ux+uz*uz))
                    local cosy = cos(ph_y)
                    x = x + bounce / distance * sin(th_z) * cosy
                    y = y + bounce / distance * sin(ph_y)
                    z = z + bounce / distance * cos(th_z) * cosy
                end
            end
        end
    end
    return { x, y, z }
end

local function SpawnClusterProjectiles(data, attackerID, ex, ey, ez, deflection)
    local projNum = data.number
    local projVel = data.projVel

    spawnCache.owner = attackerID or -1
    spawnCache.ttl   = data.projTtl

    -- Initial direction vectors are evenly spaced.
    local directions = directions[projNum]

    local vx, vy, vz, norm
    for ii = 0, (projNum-1) do
        -- Avoid shooting into terrain by adding deflection.
        vx = directions[3*ii+1] + deflection[1]
        vy = directions[3*ii+2] + deflection[2]
        vz = directions[3*ii+3] + deflection[3]

        -- Since the initial directions are not random, we add jitter.
        -- Note: Comment this out to test without any randomness.
        vx = vx + (rand() * 6 - 3) / projNum
        vy = vy + (rand() * 6 - 3) / projNum
        vx = vx + (rand() * 6 - 3) / projNum

        -- Set the projectile's velocity vector.
        norm = sqrt(vx*vx + vy*vy + vz*vz)
        vx = vx * projVel / norm
        vy = vy * projVel / norm
        vz = vz * projVel / norm
        spawnCache.speed = { vx, vy, vz }

        -- Pre-scatter the projectile and set its initial position.
        spawnCache.pos = {
            ex + vx * GAME_SPEED / 2,
            ey + vy * GAME_SPEED / 10 * max(1, 5 * abs(vy) / projVel),
            ez + vz * GAME_SPEED / 2
        }

        spSpawnProjectile(data.projDef, spawnCache)
    end
end

--------------------------------------------------------------------------------------------------------------
-- Gadget callins --------------------------------------------------------------------------------------------

function gadget:Initialize()
    for wdid, _ in pairs(dataTable) do
        SetWatchExplosion(wdid, true)
    end
end

function gadget:Explosion(weaponDefID, ex, ey, ez, attackerID, projID)
    if not dataTable[weaponDefID] then return end
    local weaponData = dataTable[weaponDefID]
    local deflection = GetSurfaceDeflection(ex, ey, ez)
    SpawnClusterProjectiles(weaponData, attackerID, ex, ey, ez, deflection)
end
