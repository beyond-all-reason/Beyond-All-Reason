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

-- @efrec notes
-- Reflection seems like the final hurdle. When a shot collides face-on with the surface (or big unit):       -- todo
-- (1) Reflect its momentum across the surface normal.
-- (2) Scale the projection of the reflection along the surface normal by reflectionRate.
--
-- This ideally would work with more weapon types; but these are implemented differently in-engine.
-- Differently enough that they'd need extra arch/glue, and this script will get long.

if not gadgetHandler:IsSyncedCode() then return false end

--------------------------------------------------------------------------------------------------------------
-- Configuration ---------------------------------------------------------------------------------------------

-- General settings

local customParamName = "cluster"                  -- in the weapondef, the parameter name to set to `true`
local reflectionRate  = 0.5                        -- % momentum conserved when reflecting at high incidences  -- todo
local minUnitReflect  = 6                          -- smallest unit size that causes reflection as if terrain  -- todo
local maxSplitNumber  = 40                         -- protect us from ourselves

-- todo: Kinematic settings
-- todo: There's a tension between physics and game statistics. There's no parameter for 'scatter distance'.
-- todo: Factor secondary range into kinematics.
-- todo: Write a ScatterAreaOfEffect function for use in an aim reticule.
local dAreaInfluence = 0.1                         -- % primary area of effect influence on scatter distance   -- todo
local rangeInfluence = 0.1                         -- % secondary range influence on scatter distance
local speedInfluence = 0.8                         -- % secondary speed influence on scatter distance

-- Default settings

local defaultSpawnDef = "cluster_munition"         -- standardized weapondef name                              -- todo: prepend unit name
local defaultSpawnNum = 5                          -- number of spawned projectiles
local defaultTrailCEG = "arty-fast"                -- a little trail
local defaultVelocity = 400                        -- speed of spawned projectiles
local defaultRebound  = 0.2                        -- % momentum inherited along normal during hard reflection -- todo
local defaultSlip     = 0.2                        -- % momentum inherited along plane during hard reflection  -- todo
local defaultTtl      = 30                         -- detonate projectiles after frames = ttl

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
local mapSizeX 				  = Game.mapSizeX
local mapSizeZ 				  = Game.mapSizeZ
local mapGravity			  = Game.gravity / GAME_SPEED / GAME_SPEED * -1

local SetWatchExplosion       = Script.SetWatchExplosion

--------------------------------------------------------------------------------------------------------------
-- Initialize ------------------------------------------------------------------------------------------------

-- Reusable tables for reducing garbage.

local vectorCache = { 0, 0, 0 }
local spawnCache = {
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
    LightningCannon   = false , -- could work this in probs
    MissileLauncher   = false , -- could work this in probs
}

local dataTable      = {} -- Info on each cluster weapon.
local wDefNamesToIDs = {} -- Says it on the tin

for wdid, wdef in pairs(WeaponDefs) do
    wDefNamesToIDs[wdef.name] = wdid

    if wdef.customParams ~= nil and wdef.customParams[customParamName] then
        dataTable[wdef.id] = {
            weaponDefID = wdef.id,
            projOwnerID = -1,
            def         = wdef.customParams.def, --              or defaultSpawnDef, -- todo: prepend unitname_ to defaultSpawnDef
            number      = tonumber(wdef.customParams.number),
            explVel     = tonumber(wdef.damages.explosionSpeed)  or 1000,
            explAoe     = tonumber(wdef.damageAreaOfEffect)      or 12,
            projDID     = 0,
            projVel     = defaultVelocity,
            projTtl     = defaultTtl,
            cegtag      = wdef.customParams.cegtag,
        }

        -- Remove weapons with un-spawnable projectiles:
        if spawnableTypes[WeaponDefNames[dataTable[wdid].def].weaponType] ~= true then
            -- dataTable[wdef.id] = nil
            Spring.Echo('[cluster] [warn] Invalid spawned weapon type: ' .. dataTable[wdid].def ..
                ' is not spawnable (' .. WeaponDefNames[dataTable[wdid].def].weaponType .. ')')
        end
    end
end

for wdid, data in pairs(dataTable) do
    local swdid = wDefNamesToIDs[data.def]
    local swdef = WeaponDefs[swdid]

    dataTable[wdid].projDID = swdid
    dataTable[wdid].projVel = swdef.maxVelocity      or defaultVelocity
    dataTable[wdid].projTtl = swdef.ttl              or defaultTtl
    dataTable[wdid].cegtag  = dataTable[wdid].cegtag or swdef.cegtag or '' -- todo: empty string ok?

    -- Prevent the grenade apocalypse:
    dataTable[swdid] = nil
end

spawnableTypes = nil
wDefNamesToIDs = nil

--------------------------------------------------------------------------------------------------------------
-- Functions -------------------------------------------------------------------------------------------------

local function RandomVector3() -- todo: test
    local x1, x2, x3, x4  -- Marsaglia method:
    repeat                -- The method begins by sampling & rejecting points.
        x1 = rand(-1, 1)  -- The result can be transformed into radial coords.
        x2 = rand(-1, 1)
        x3 = x1 * x1 + x2 * x2
    until (x3 < 1)
    x4 = sqrt(1 - x3)
    vectorCache = {
        2 * x1 * x4 , -- x
        2 * x2 * x4 , -- y
        1 -  2 * x3   -- z
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
    local nearCheck     = max(12, sqrt(aoe), projSpeed / 200)
    local surfDistance  = ey - spGetGroundHeight(ex, ez)
    local x, y, z, s, n = spGetGroundNormal(ex, ez, false) -- sneak-allocating n here feels illegal

    -- If not in close contact with the surface, get a better guess.
    -- This uses very naive geometry, but it's cheap on ops.
    if surfDistance > 12 then
        n = -1 * cos(s) * sin(s) * surfDistance -- todo: check sign
        surfDistance = ey - spGetGroundHeight(ex-x*n, ez-z*n) -- todo: map bounds check, unless GetGroundHeight somehow doesn't care
        x, y, z, s = spGetGroundNormal(ex-x*n, ez-z*n, false)
        n = -1 * cos(s) * sin(s) * surfDistance
        surfDistance = abs(x*ex + y*ey + z*ez) -- Should be decent.
    end

    if surfDistance < nearCheck then
        local scale = sqrt(projSpeed) / max(12, surfDistance) -- todo: a better scale
        -- Spring.Echo('Deflecting with scale = '..scale..' ('..x..','..y..','..z..')')
        return { x * scale, y * scale, z * scale }
    else
        return { 0, 0, 0 }
    end
end

local function SpawnClusterProjectiles(data, attackerID, projID, ex, ey, ez, deflect) -- todo
    local number  = data.number
    local projVel = data.projVel

    spawnCache.owner = attackerID or -1
    spawnCache.ttl   = data.projTtl

    -- Initial direction vectors are evenly spaced.
    local distribute = DistributedVectorSet(number)
    local vx, vy, vz, norm, elevate
    for ii = 0, (number-1) do
        -- Avoid shooting into terrain by adding deflection.
        vx = distribute[(3*ii+1)] + deflect[1]
        vy = distribute[(3*ii+2)] + deflect[2]
        vz = distribute[(3*ii+3)] + deflect[3]

        -- Some additional randomness.
        if number <= 8 then -- Magic value depending on DistributedVectorSet.
            vx = vx * (1 + rand(-1, 1) * 0.86 / number)
            vy = vy * (1 + rand(-1, 1) * 0.33 / number)
            vz = vz * (1 + rand(-1, 1) * 0.86 / number)
        end

        -- Adjust vector length to the speed/magnitude.
        norm = sqrt(vx*vx + vy*vy + vz*vz)
        vx = vx * projVel / norm / 200 -- you fiddle around for ten seconds and suddenly you're off by a factor of ~200
        vy = vy * projVel / norm / 200 -- i do not understand
        vz = vz * projVel / norm / 200
        spawnCache.speed = { vx, vy, vz } -- For weapon compat: This is sometimes 'vel' or 'end' or even a target, instead.

        -- Pre-scatter projectiles.
        elevate = min(2, max(0.1, 30 / (vx + vz)))
        spawnCache.pos = { ex + vx, ey + vy*elevate + 4, ez + vz } -- For perf: Do you get the allocation benefits if you just swap the whole table in?
                                                                   -- Or only if you use the indices? Asking for a friend

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
    if not data then return end -- to complain: Don't want other script's watchers. Just don't. Simple as

    local deflect = GetSurfaceDeflection(data.explAoe, data.projVel, ex, ey, ez)
    SpawnClusterProjectiles(data, attackerID, projID, ex, ey, ez, deflect)
end
