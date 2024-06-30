function gadget:GetInfo()
    return {
        name    = 'Cluster Munitions',
        desc    = 'Custom behavior for projectiles that explode and split on impact.',
        author  = 'efrec',
        version = '1.0',
        date    = '2024-05',
        license = 'GNU GPL, v2 or later',
        layer   = 0,
        enabled = true
    }
end

if not gadgetHandler:IsSyncedCode() then return false end

--------------------------------------------------------------------------------------------------------------
-- Configuration ---------------------------------------------------------------------------------------------

-- Default settings -----------------------------------------------------------------------------------------

local defaultSpawnDef = "cluster_munition"         -- def used, by default
local defaultSpawnNum = 5                          -- number of spawned projectiles, by default
local defaultTtl      = 300                        -- detonate projectiles after time = ttl, by default
local defaultVelocity = 240                        -- speed of spawned projectiles, by default
local defaultBouncing = false                      -- whether sub-munitions 'bounce' off of units, by default

-- General settings ------------------------------------------------------------------------------------------

local customParamName = "cluster"                  -- in the weapondef, the parameter name to set to `true`
local maxSplitNumber  = 20                         -- protect game performance against stupid ideas
local minBulkReflect  = 80000                      -- smallest unit bulk that causes reflection as if terrain

-- CustomParams setup ---------------------------------------------------------------------------------------

--    primary_weapon = {
--        customparams = {
--            cluster  = true,
--           [def      = <string>,]
--           [number   = <integer>,]
--           [bouncing = true | false,]
--        },
--    },
--    cluster_munition = {
--       [maxvelocity = <number>,]
--       [range       = <number>,]
--    }

--------------------------------------------------------------------------------------------------------------
-- Localize --------------------------------------------------------------------------------------------------

local abs    = math.abs
local sign   = math.sgn
local max    = math.max
local min    = math.min
local rand   = math.random
local sqrt   = math.sqrt
local cos    = math.cos
local sin    = math.sin

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

-- Reusable tables for reducing garbage

local weaponCache = {
    explVel = 0,
    explAoe = 0,
    def     = defaultSpawnDef,
    number  = defaultSpawnNum,
    projDef = 0,
    projVel = defaultVelocity / GAME_SPEED,
    projTtl = defaultTtl,
    check   = 0
}

local spawnCache  = {
    pos     = { 0, 0, 0 },
    speed   = { 0, 0, 0 },
    owner   = 0,
    ttl     = defaultTtl,
    gravity = mapGravity,
}

-- Information table for cluster weapons

local spawnableTypes = {
    Cannon            = true  ,
    EMGCannon         = true  ,
    Fire              = false , -- but possible
    LightningCannon   = false , -- but possible
    MissileLauncher   = false , -- but possible
}

local dataTable      = {} -- Info on each cluster weapon.
local wDefNamesToIDs = {} -- Says it on the tin

for wdid, wdef in pairs(WeaponDefs) do
    wDefNamesToIDs[wdef.name] = wdid

    if wdef.customParams and wdef.customParams[customParamName] then
        dataTable[wdid] = {}
        dataTable[wdid].explAoe  = wdef.damageAreaOfEffect            or 12
        dataTable[wdid].explVel  = wdef.explosionSpeed                or (8 + max(30, wdef.damages[0] / 20)) / (9 + sqrt(max(30, wdef.damages[0] / 20)) * 0.7) * 0.5
        dataTable[wdid].bouncing = wdef.customParams.bouncing         or defaultBouncing
        dataTable[wdid].number   = tonumber(wdef.customParams.number) or defaultSpawnNum
        dataTable[wdid].def      = wdef.customParams.def              or (string.split(wdef.name, "_"))[1] .. '_' .. defaultSpawnDef

        dataTable[wdid].projDef  = -1
        dataTable[wdid].projTtl  = defaultTtl
        dataTable[wdid].projVel  = defaultVelocity / GAME_SPEED
        dataTable[wdid].colDist  = max(12, sqrt(dataTable[wdid].explAoe))
    end
end

-- Information for cluster munitions

for wdid, data in pairs(dataTable) do
    local cmdid = wDefNamesToIDs[data.def]
    local cmdef = WeaponDefs[cmdid]

    dataTable[wdid].projDef = cmdid
    dataTable[wdid].projTtl = cmdef.ttl or defaultTtl

    -- Range and velocity are closely related so may be in disagreement. Average them (more or less):
    local projVel = cmdef.projectileSpeed or cmdef.startvelocity
    projVel = projVel and projVel * GAME_SPEED or defaultVelocity
    if cmdef.range > 10 then
        local rangeVel = sqrt(cmdef.range * abs(mapGravity)) -- inverse range calc for launch @ 45deg
        dataTable[wdid].projVel = (projVel + rangeVel) / 2
    else
        dataTable[wdid].projVel = projVel
    end

    -- We check for collisions within a radius:
    dataTable[wdid].colDist = max(dataTable[wdid].colDist, dataTable[wdid].projVel / 120)

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
end

-- Information on how sturdy units are, basically

local unitBulk = {}
for udid, udef in pairs(UnitDefs) do
    unitBulk[udid] = min(
        (   sqrt(udef.health) +
            sqrt(udef.metalCost) * udef.xsize * udef.zsize * sqrt(udef.radius)
        ) / minBulkReflect,
        1.0
    )
end

--------------------------------------------------------------------------------------------------------------
-- Functions -------------------------------------------------------------------------------------------------

local function RandomVector3()
    local m1, m2, m3, m4       -- Marsaglia procedure:
    repeat                     -- The method begins by sampling & rejecting points.
        m1 = 2 * rand() - 1    -- The result can be transformed into radial coords.
        m2 = 2 * rand() - 1    -- Rand floats are expensive, though. Might replace.
        m3 = m1 * m1 + m2 * m2
    until (m3 < 1)
    m4 = sqrt(1 - m3)
    return 2 * m1 * m4 , -- x
           2 * m2 * m4 , -- y
           1 -  2 * m3   -- z
end

-- Randomness produces clumping at small sample sizes, so we scatter evenly-spaced vectors instead.
-- Credit to Hardin, Sloane, & Smith (and contribs).
local packedSpheres = {
    [1] = 0,
    [2] = {  1, 0, 0,   -1, 0, 0  },
    [3] = {  1, 0, 0,   -0.5, 0, 0.866025403784439,   -0.5, 0, -0.866025403784438  },
    [4] = { -0.577350269072,  0.577350269072, -0.577350269072,  0.577350269072,  0.577350269072,  0.577350269072, -0.577350269072, -0.577350269072,  0.577350269072,  0.577350269072, -0.577350269072, -0.577350269072 },
    [5] = { -1.478255937088018300e-01,  8.557801392177640800e-01,  4.957700547280610200e-01,  9.298520676823500700e-01, -3.330452755499895800e-01, -1.563840677968503200e-01, -7.820264758448114400e-01, -5.227348665222011400e-01, -3.393859902820995400e-01, -3.612306945786420600e-02, -5.056147808319168000e-01,  8.620027942282061400e-01,  3.612306958303366400e-02,  5.056147801034870400e-01, -8.620027946502272200e-01 },
    [6] = {  0.212548255920, -0.977150570601,  0.000000000000, -0.977150570601, -0.212548255920,  0.000000000000, -0.212548255920,  0.977150570601,  0.000000000000,  0.977150570601,  0.212548255920,  0.000000000000,  0.000000000000,  0.000000000000,  1.000000000000,  0.000000000000,  0.000000000000, -1.000000000000 },
    [7] = { -9.476914051796328000e-01, -2.052179514558175300e-01,  2.444720698749264500e-01,  8.503710682661692600e-01,  4.830848344829018500e-01,  2.085619547004717300e-01, -4.995609516538522300e-01,  3.276811928816584800e-01, -8.019126457503652500e-01, -3.344875986220292000e-01,  8.899589445240678700e-01,  3.099856826204648300e-01,  2.420381484495352800e-02, -9.924430055046316000e-01,  1.202957030483007100e-01,  5.426485704335360500e-02, -8.987314180840469400e-02,  9.944738024058507000e-01,  5.948684088498340500e-01, -2.881863468134767100e-01, -7.503867040818149600e-01 },
    [8] = { -7.941044876934105800e-01,  3.289288487526511000e-01,  5.110810846464987100e-01,  3.289288487526511000e-01, -7.941044876934105800e-01, -5.110810846464987100e-01,  7.941044876934105800e-01,  3.289288487526511000e-01, -5.110810846464987100e-01, -3.289288487526511000e-01, -7.941044876934105800e-01,  5.110810846464987100e-01, -7.941044876934105800e-01, -3.289288487526511000e-01, -5.110810846464987100e-01,  3.289288487526511000e-01,  7.941044876934105800e-01,  5.110810846464987100e-01,  7.941044876934105800e-01, -3.289288487526511000e-01,  5.110810846464987100e-01, -3.289288487526511000e-01,  7.941044876934105800e-01, -5.110810846464987100e-01 },
}

local function DistributedVectorSet(n)
    if n == nil or n < 1 then return end
    local vectors = packedSpheres[n] or {}
    if vectors == {} and n <= maxSplitNumber then
        -- Random samples are likely enough to look distributed for n > 8. Source: I made it up.
        for ii = 1, 3*(n-1)+1, 3 do
            vectors[ii], vectors[ii + 1], vectors[ii + 2] = RandomVector3()
        end
    end
    return vectors
end

local function GetSurfaceDeflection(explArea, projSpeed, nearCheck, ex, ey, ez, bouncing)
    local distSurface = ey - spGetGroundHeight(ex, ez)
    local x, y, z, s  = spGetGroundNormal(ex, ez, false)

    -- If not in close contact with the surface, get a better guess.
    -- This uses naive geometry, but it's cheap on ops and not too bad.
    if distSurface > 12 then
        local n     = cos(s) * sin(s) * distSurface
        distSurface = ey - spGetGroundHeight(ex+x*n, ez+z*n)
        x, y, z, _  = spGetGroundNormal(ex+x*n, ez+z*n, false)
        distSurface = abs(x*ex + y*ey + z*ez)
        x, y, z     = x / distSurface, y / distSurface, z / distSurface
    end

    if not bouncing then
        local scale = sqrt(projSpeed) / max(12, distSurface) -- idk, seems to work
        return { x * scale, y * scale, z * scale }
    else
        -- No easy way to get units by collider distance; I believe this is by midpoint:
        local collisions = spGetUnitsInSphere(ex, ey, ez, max(nearCheck, 80)) -- 80 is a fairly wide net.
        -- When hitting a unit directly, we can determine how much to "bounce" off it.
        -- This is used to keep grenades-of-grenades from detonating on contact instead of spreading out.
        local bounce, radius, ux, uy, uz, cx, cy, cz, cw
        for _, uid in pairs(collisions) do
            bounce = unitBulk[spGetUnitDefID(uid)]
            -- Arbitrary cutoff to ignore cheap, spammy units.
            if bounce > 0.05 then
                radius = spGetUnitRadius(uid)
                ux, uy, uz = spGetUnitPosition(uid, true)

                cx = ex - ux
                cy = ey - uy
                cz = ez - uz
                cw = cx * cx + cy * cy + cz * cz
                cw = cw * max(1.0, cw - radius * radius)

                x = x + bounce * (1 - abs(cx) / cw) * sign(cx)
                y = y + bounce * (1 - abs(cy) / cw) * sign(cy)
                z = z + bounce * (1 - abs(cz) / cw) * sign(cz)
            end
        end
        return { x, y, z }
    end
end

local function SpawnClusterProjectiles(data, attackerID, projID, ex, ey, ez, deflect)
    local projNum = data.number
    local projVel = data.projVel

    spawnCache.owner = attackerID or -1
    spawnCache.ttl   = data.projTtl

    -- Initial direction vectors are evenly spaced.
    local distribute = DistributedVectorSet(projNum)

    local vx, vy, vz, dist, norm
    for ii = 0, (projNum-1) do
        -- Avoid shooting into terrain by adding deflection.
        dist = min(1, (data.explVel + data.projVel) / 12) * (data.bouncing and 4 or 1)
        vx = distribute[(3*ii+1)] + deflect[1] * dist
        vy = distribute[(3*ii+2)] + deflect[2] * dist
        vz = distribute[(3*ii+3)] + deflect[3] * dist

        -- When the initial directions are not random, add jitter.
        if projNum <= #packedSpheres then
            vx = vx + rand(-projNum, projNum) / projNum * 0.86
            vy = vy + rand(-projNum, projNum) / projNum * 0.42
            vz = vz + rand(-projNum, projNum) / projNum * 0.86
        end

        -- Adjust vector length to the speed/magnitude.
        norm = sqrt(vx*vx + vy*vy + vz*vz) or 1
        vx = vx * projVel / norm
        vy = vy * projVel / norm
        vz = vz * projVel / norm
        spawnCache.speed = { vx, vy, vz }

        -- Pre-scatter projectiles.
        spawnCache.pos = { ex + vx*4, ey + vy*2*min(4, max(1, projVel / (abs(vx) + abs(vz)))), ez + vz*4 }

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

    weaponCache = dataTable[weaponDefID]

    -- Scatter munitions away from terrain (and heavy units) as appropriate.
    local deflect = GetSurfaceDeflection(
        weaponCache.explAoe,
        weaponCache.projVel,
        weaponCache.colDist,
        ex, ey, ez,
        weaponCache.bouncing
    )

    SpawnClusterProjectiles(weaponCache, attackerID, projID, ex, ey, ez, deflect)
end
