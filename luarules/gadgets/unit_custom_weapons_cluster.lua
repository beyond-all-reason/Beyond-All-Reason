function gadget:GetInfo()
    return {
        name    = 'Cluster Munitions',
        desc    = 'Custom behavior for cluster or shrapnel weapons.',
        author  = 'efrec',
        version = 'alpha',
        date    = '2024-04',
        license = 'GNU GPL, v2 or later',
        layer   = 0,
        enabled = true
    }
end

if not gadgetHandler:IsSyncedCode() then return false end

--------------------------------------------------------------------------------------------------------------
-- Configuration ---------------------------------------------------------------------------------------------

-- General settings ------------------------------------------------------------------------------------------

local customParamName = "cluster"                  -- in the weapondef, the parameter name to set to `true`
local maxSplitNumber  = 20                         -- protect game performance against stupid ideas
local reflectionRate  = 0.5                        -- % momentum conserved when reflecting at high incidences  -- todo
local minUnitReflect  = 6                          -- smallest unit size that causes reflection as if terrain  -- todo

-- todo: Kinematic settings
-- todo: There's a tension between physics and game statistics. There's no parameter for 'scatter distance'.
-- todo: Factor secondary range into kinematics.
-- todo: Write a ScatterAreaOfEffect function for use in an aim reticule.
local dAreaInfluence = 0.1                         -- % primary area of effect influence on scatter distance   -- todo
local rangeInfluence = 0.1                         -- % secondary range influence on scatter distance
local speedInfluence = 0.8                         -- % secondary speed influence on scatter distance

-- Default settings -----------------------------------------------------------------------------------------

local defaultSpawnDef = "cluster_munition"         -- def used when omitted
local defaultSpawnNum = 5                          -- number of spawned projectiles when omitted
local defaultTrailCEG = "arty-fast"                -- projectile trail when omitted; not used
local defaultVelocity = 100                        -- speed of spawned projectiles; they need to be slow tbh
local defaultTtl      = 300                        -- detonate projectiles after frames = ttl
local defaultRebound  = 0.2                        -- % momentum inherited along normal during hard reflection -- todo
local defaultSlip     = 0.2                        -- % momentum inherited along plane during hard reflection  -- todo

--------------------------------------------------------------------------------------------------------------
-- Localization ----------------------------------------------------------------------------------------------

local abs    = math.abs
local max    = math.max
local min    = math.min
local rand   = math.random
local sqrt   = math.sqrt
local cos    = math.cos
local sin    = math.sin
local PI     = math.pi
local TAU    = 2 * PI
local format = string.format

local spGetGroundHeight       = Spring.GetGroundHeight
local spGetGroundNormal       = Spring.GetGroundNormal
local spGetProjectilePosition = Spring.GetProjectilePosition
local spGetProjectileVelocity = Spring.GetProjectileVelocity
local spGetUnitDefID          = Spring.GetUnitDefID
local spGetUnitPosition       = Spring.GetUnitPosition
local spGetUnitsInSphere      = Spring.GetUnitsInSphere
local spSpawnCEG              = Spring.SpawnCEG
local spSpawnProjectile       = Spring.SpawnProjectile

local GAME_SPEED              = Game.gameSpeed
local mapSizeX                = Game.mapSizeX
local mapSizeZ                = Game.mapSizeZ
local mapGravity              = Game.gravity / GAME_SPEED / GAME_SPEED * -1

local SetWatchExplosion       = Script.SetWatchExplosion

--------------------------------------------------------------------------------------------------------------
-- Initialize ------------------------------------------------------------------------------------------------

-- Reusable tables for reducing garbage.

local vectorCache = { 0, 0, 0 }
local spawnCache  = {
    pos     = vectorCache,
    speed   = vectorCache,
    owner   = -1,
    ttl     = defaultTtl,
    gravity = mapGravity,
}

-- Information tables for cluster weapons.

local spawnableTypes = {
    Cannon            = true  ,
    EMGCannon         = true  ,
    Fire              = false , -- but possible
    LightningCannon   = false , -- but possible
    MissileLauncher   = false , -- but possible
}

-- Fire:
-- just seems like a weird thing to do is all
-- maybe a raptor attack or something

-- LightningCannon:
-- would have to work with or replace existing lightning implementation
-- hitscan that tries to radiate; may waste arcs targeting ground just to target symmetrically
-- would be a cool emp weapon on a gunship; rocket => cluster lightning

-- MissileLauncher:
-- would have to be homing, with or without retargeting
-- feels like it could replace juno? burst weapon instead of the haze; starburst => cluster missiles

local dataTable      = {} -- Info on each cluster weapon.
local wDefNamesToIDs = {} -- Says it on the tin

for wdid, wdef in pairs(WeaponDefs) do
    wDefNamesToIDs[wdef.name] = wdid

    if wdef.customParams ~= nil and wdef.customParams[customParamName] then
        dataTable[wdef.id] = {
            weaponDefID = wdef.id,
            explVel     = wdef.damages.explosionSpeed or 1000,
            explAoe     = wdef.damageAreaOfEffect     or 12,

            def         = wdef.customParams.def or (string.split(wdef.name, "_"))[1] .. '_' .. defaultSpawnDef,
            number      = tonumber(wdef.customParams.number) or defaultSpawnNum,
            cegtag      = wdef.customParams.cegtag,

            projDID     = -1,
            projOwnerID = -1,
            projVel     = defaultVelocity,
            projTtl     = defaultTtl,
        }

        -- Remove weapons with un-spawnable projectiles: -- todo: fix this
        -- if spawnableTypes[WeaponDefNames[dataTable[wdid].def].weaponType] ~= true then
        --     -- dataTable[wdef.id] = nil
        --     -- Spring.Echo('[cluster] [warn] Invalid spawned weapon type: ' .. dataTable[wdid].def ..
        --     --     ' is not spawnable (' .. WeaponDefNames[dataTable[wdid].def].weaponType .. ')')
        -- end
    end
end

for wdid, data in pairs(dataTable) do
    local swdid = wDefNamesToIDs[data.def]
    local swdef = WeaponDefs[swdid]

    dataTable[wdid].projDID = swdid
    dataTable[wdid].projTtl = swdef.ttl              or defaultTtl
    dataTable[wdid].cegtag  = dataTable[wdid].cegtag or swdef.cegtag or ''

    -- Range and velocity are closely related so may be in disagreement.
    -- We average them together (more or less):
    local range = swdef.range or 10
    if range > 10 and swdef.maxvelocity then
        local rangeVel = sqrt((range + 8) * Game.gravity / 900) -- launch velocity @ 45deg
        dataTable[wdid].projVel = (swdef.maxvelocity + rangeVel) / 2
    else
        dataTable[wdid].projVel = swdef.maxvelocity or defaultVelocity
    end

    -- Prevent the grenade apocalypse:
    dataTable[swdid] = nil
end

spawnableTypes = nil
wDefNamesToIDs = nil

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
    vectorCache = {
        2 * m1 * m4 , -- x
        2 * m2 * m4 , -- y
        1 -  2 * m3   -- z
    }
    return vectorCache
end

-- Randomness produces clumping at small sample sizes, so we scatter evenly-spaced vectors instead.
-- Credit and thanks to Hardin, Sloane, & Smith (and contribs) for their packing solutions, n > 3.
local packedSpheres = { -- should be <const> or smth
    [1] = 0,
    [2] = {  1, 0, 0,   -1, 0, 0  },
    [3] = {  0, 0, 0,   -0.5, 0, 0.866025403784439,   -0.5, 0, -0.866025403784438  },
    [4] = { -0.577350269072,  0.577350269072, -0.577350269072,  0.577350269072,  0.577350269072,  0.577350269072, -0.577350269072, -0.577350269072,  0.577350269072,  0.577350269072, -0.577350269072, -0.577350269072 },
    [5] = { -1.478255937088018300e-01,  8.557801392177640800e-01,  4.957700547280610200e-01,  9.298520676823500700e-01, -3.330452755499895800e-01, -1.563840677968503200e-01, -7.820264758448114400e-01, -5.227348665222011400e-01, -3.393859902820995400e-01, -3.612306945786420600e-02, -5.056147808319168000e-01,  8.620027942282061400e-01,  3.612306958303366400e-02,  5.056147801034870400e-01, -8.620027946502272200e-01 },
    [6] = {  0.212548255920, -0.977150570601,  0.000000000000, -0.977150570601, -0.212548255920,  0.000000000000, -0.212548255920,  0.977150570601,  0.000000000000,  0.977150570601,  0.212548255920,  0.000000000000,  0.000000000000,  0.000000000000,  1.000000000000,  0.000000000000,  0.000000000000, -1.000000000000 },
    [7] = { -9.476914051796328000e-01, -2.052179514558175300e-01,  2.444720698749264500e-01,  8.503710682661692600e-01,  4.830848344829018500e-01,  2.085619547004717300e-01, -4.995609516538522300e-01,  3.276811928816584800e-01, -8.019126457503652500e-01, -3.344875986220292000e-01,  8.899589445240678700e-01,  3.099856826204648300e-01,  2.420381484495352800e-02, -9.924430055046316000e-01,  1.202957030483007100e-01,  5.426485704335360500e-02, -8.987314180840469400e-02,  9.944738024058507000e-01,  5.948684088498340500e-01, -2.881863468134767100e-01, -7.503867040818149600e-01 },
    [8] = { -7.941044876934105800e-01,  3.289288487526511000e-01,  5.110810846464987100e-01,  3.289288487526511000e-01, -7.941044876934105800e-01, -5.110810846464987100e-01,  7.941044876934105800e-01,  3.289288487526511000e-01, -5.110810846464987100e-01, -3.289288487526511000e-01, -7.941044876934105800e-01,  5.110810846464987100e-01, -7.941044876934105800e-01, -3.289288487526511000e-01, -5.110810846464987100e-01,  3.289288487526511000e-01,  7.941044876934105800e-01,  5.110810846464987100e-01,  7.941044876934105800e-01, -3.289288487526511000e-01,  5.110810846464987100e-01, -3.289288487526511000e-01,  7.941044876934105800e-01, -5.110810846464987100e-01 },
}

local function DistributedVectorSet(n) -- todo: test
    if n == nil or n < 1 then return else
        local vectors = packedSpheres[n] or 0
        if vectors == 0 and n <= maxSplitNumber then
            -- Random samples are likely enough to look distributed for n > 8. Source: I made it up.
            -- This is slower, though, and it's unfortunate to choose a slower method for larger n.
            for ii = 1, 3*(n-1)+1, 3 do
                vectors[ii], vectors[ii + 1], vectors[ii + 2] = RandomVector3()
            end
        end
        return vectors
    end
end

local function GetSurfaceDeflection(aoe, projSpeed, ex, ey, ez)
    local nearCheck   = max(12, sqrt(aoe), projSpeed / 200)
    local distSurface = ey - spGetGroundHeight(ex, ez)
    local x, y, z, s  = spGetGroundNormal(ex, ez, false) -- false => not smooth; but how smooth are we talking, here?

    -- If not in close contact with the surface, get a better guess.
    -- This uses very naive geometry, but it's cheap on ops and not too bad.
    if distSurface > 12 then
        local n     = cos(s) * sin(s) * distSurface
        distSurface = ey - spGetGroundHeight(ex+x*n, ez+z*n)
        x, y, z, s  = spGetGroundNormal(ex+x*n, ez+z*n, false)
        distSurface = abs(x*ex + y*ey + z*ez)
    end

    -- todo: Deflection when hitting units. This is patched, for now, in the pre-scatter.

    if distSurface < nearCheck then
        local scale = sqrt(projSpeed) / max(12, distSurface) -- todo: better scaling
        -- Spring.Echo('Deflecting with scale = '..scale..' ('..x..','..y..','..z..')')
        return { x * scale, y * scale, z * scale }
    else
        return { 0, 0, 0 }
    end
end

local function SpawnClusterProjectiles(data, attackerID, projID, ex, ey, ez, deflect)
    local number  = data.number
    local projVel = data.projVel

    spawnCache.owner = attackerID or -1
    spawnCache.ttl   = data.projTtl

    -- Initial direction vectors are evenly spaced.
    local distribute = DistributedVectorSet(number)

    local vx, vy, vz, dist, norm, elevate
    for ii = 0, (number-1) do
        -- Avoid shooting into terrain by adding deflection.
        dist = data.explVel / data.projVel / 8
        vx = distribute[(3*ii+1)] + deflect[1] * dist
        vy = distribute[(3*ii+2)] + deflect[2] * dist
        vz = distribute[(3*ii+3)] + deflect[3] * dist

        -- When the initial directions are not random, add jitter.
        if number <= #packedSpheres then
            vx = vx * (1 + rand(-number, number) / number * 0.86)
            vy = vy * (1 + rand(-number, number) / number * 0.33)
            vz = vz * (1 + rand(-number, number) / number * 0.86)
        end

        -- Adjust vector length to the speed/magnitude.
        norm = sqrt(vx*vx + vy*vy + vz*vz)
        vx = vx * projVel / norm / 30
        vy = vy * projVel / norm / 30
        vz = vz * projVel / norm / 30
        spawnCache.speed = { vx, vy, vz } -- For weapon compat: This is sometimes 'vel' or 'end' or even a target, instead.

        -- Pre-scatter projectiles. -- todo: less pre-scatter when unit deflection is ready
        spawnCache.pos = { ex + vx*4, ey + vy*4*min(3, max(1, 30 / (vx + vz))) + 3, ez + vz*4 }

        -- Spring.Echo(format('[cluster] Spawn params: pos=(%d, %d, %d), speed=(%d, %d, %d)',
        --     spawnCache.pos[1],  spawnCache.pos[2],  spawnCache.pos[3], vx, vy, vz))
        spSpawnProjectile(data.projDID, spawnCache)
    end
end

--------------------------------------------------------------------------------------------------------------
-- Gadget callins --------------------------------------------------------------------------------------------

function gadget:Initialize()
    for wdid, _ in pairs(dataTable) do
        Script.SetWatchExplosion(wdid, true)
    end
end

function gadget:Explosion(weaponDefID, ex, ey, ez, attackerID, projID)
    local data = dataTable[weaponDefID]
    if not data then return end -- complaint: Don't want other script's watchers. Just don't. Simple as

    local deflect = GetSurfaceDeflection(data.explAoe, data.projVel, ex, ey, ez)
    SpawnClusterProjectiles(data, attackerID, projID, ex, ey, ez, deflect)
end
