function gadget:GetInfo()
    return {
        name    = 'Cluster Munitions',
        desc    = 'Projectiles split and scatter on impact.',
        author  = 'efrec',
        version = '1.1',
        date    = '2024-06-07',
        license = 'GNU GPL, v2 or later',
        layer   = 10, -- before fx_watersplash; Explosion is reverse iterated
        enabled = true
    }
end

if not gadgetHandler:IsSyncedCode() then return false end

--------------------------------------------------------------------------------
-- Configuration ---------------------------------------------------------------

-- Default settings ------------------------------------------------------------

local defaultSpawnDef = "cluster_munition" -- short def name used, by default
local defaultSpawnNum = 5                  -- number of spawned projectiles, by default
local defaultSpawnTtl = 5                  -- detonate projectiles after time = ttl, by default

-- General settings ------------------------------------------------------------

local maxSpawnNumber  = 24                 -- protect game performance against stupid ideas
local minUnitBounces  = "armpw"            -- smallest unit (name) that bounces projectiles at all
local minBulkReflect  = 64000              -- smallest unit bulk that causes reflection as if terrain
local deepWaterDepth  = -40                -- used for the surface deflection on water, lava, ...

-- CustomParams setup ----------------------------------------------------------
--
--    weapon = {
--        type := "Cannon" | "EMGCannon"
--        customparams = {
--            cluster        := true
--            cluster_def    := <string> | nil (see defaults)
--            cluster_number := <number> | nil (see defaults)
--        },
--    },
--    <cluster_def> = {
--       weaponvelocity := <number> -- Each determines the scatter
--       range          := <number> -- of the cluster munitions.
--    }

--------------------------------------------------------------------------------
-- Localize --------------------------------------------------------------------

local DirectionsUtil = VFS.Include("LuaRules/Gadgets/Include/DirectionsUtil.lua")

local max   = math.max
local min   = math.min
local rand  = math.random
local sqrt  = math.sqrt
local cos   = math.cos
local sin   = math.sin
local atan2 = math.atan2

local spGetGroundHeight       = Spring.GetGroundHeight
local spGetGroundNormal       = Spring.GetGroundNormal
local spGetProjectileVelocity = Spring.GetProjectileVelocity
local spGetUnitDefID          = Spring.GetUnitDefID
local spGetUnitPosition       = Spring.GetUnitPosition
local spGetUnitRadius         = Spring.GetUnitRadius
local spGetUnitsInSphere      = Spring.GetUnitsInSphere
local spSpawnProjectile       = Spring.SpawnProjectile

local gameSpeed  = Game.gameSpeed
local mapGravity = Game.gravity / (gameSpeed * gameSpeed) * -1

--------------------------------------------------------------------------------
-- Initialize ------------------------------------------------------------------

defaultSpawnDef = string.lower(defaultSpawnDef)
defaultSpawnTtl = defaultSpawnTtl * gameSpeed

local spawnableTypes = {
    Cannon          = true  ,
    EMGCannon       = true  ,
}

local dataTable = {}

for weaponDefID, weaponDef in pairs(WeaponDefs) do
    local custom = weaponDef.customParams
    if custom.cluster then
        local number = max(3, min(maxSpawnNumber, tonumber(custom.cluster_number or defaultSpawnNum)))

        local weaponDefName = custom.cluster_def
        if not weaponDefName or not WeaponDefNames[weaponDefName] then
            local unitName -- Every weapon name contains its unit's name, per weapondefs_post.
            for word in string.gmatch(weaponDef.name, '([^_]+)') do
                unitName = not unitName and word or unitName..'_'..word
                if UnitDefNames[unitName] and WeaponDefNames[unitName..'_'..defaultSpawnDef] then
                    weaponDefName = unitName..'_'..defaultSpawnDef
                    break
                end
            end
        end

        if weaponDefName then
            local clusterDef = WeaponDefNames[weaponDefName]
            if spawnableTypes[clusterDef.type] then
                -- This is an awkward compromise, but since map gravity can vary and etc., what can you do.
                local clusterSpeed = clusterDef.projectilespeed / gameSpeed
                if clusterDef.range > 10 then
                    local ranged = sqrt(clusterDef.range * math.abs(mapGravity)) -- velocity @ 45deg to hit range
                    Spring.Echo('[cluster] ranged, weapon = '..ranged, clusterDef.projectilespeed / gameSpeed)
                    clusterSpeed = ((clusterSpeed or ranged) + ranged * 3) / 4 -- really preferring the range stat tbh
                end

                dataTable[weaponDefID] = {
                    number      = number,
                    weaponID    = clusterDef.id,
                    weaponSpeed = clusterSpeed,
                    weaponTtl   = clusterDef.flighttime or defaultSpawnTtl,
                }
            else
                Spring.Log(gadget:GetInfo().name, LOG.ERROR, 'Invalid weapon spawn type ('..clusterDef.type..')')
            end
        else
            Spring.Log(gadget:GetInfo().name, LOG.ERROR, 'Did not find cluster def for weapon '..weaponDef.name)
        end
    end
end

local removeIDs = {}
for weaponDefID, weaponData in pairs(dataTable) do
    if dataTable[weaponData.weaponID] and dataTable[dataTable[weaponData.weaponID].weaponID] then
        removeIDs[weaponData.weaponID] = true
    end
end
for weaponDefID in pairs(removeIDs) do
    Spring.Log(gadget:GetInfo().name, LOG.ERROR, 'Preventing nested explosions: '..WeaponDefs[weaponDefID].name)
    dataTable[weaponDefID] = nil
end
removeIDs = nil

local unitBulks = {} -- How sturdy the unit is. Projectiles scatter less with lower bulk values.

for unitDefID, unitDef in pairs(UnitDefs) do
    local bulkiness = (
        unitDef.health ^ 0.5 +                               -- HP is log2-ish but that feels too tryhard
        unitDef.metalCost ^ 0.5 *                            -- Steel (metal) is heavier than feathers (energy)
        unitDef.xsize * unitDef.zsize * unitDef.radius ^ 0.5 -- We see 'bigger' as 'more solid' not 'less dense'
    ) / minBulkReflect                                       -- Scaled against some large-ish bulk rating

    if unitDef.armorType == Game.armorTypes.wall or unitDef.armorType == Game.armorTypes.indestructable then
        bulkiness = bulkiness * 2
    elseif unitDef.customParams.neutral_when_closed then
        bulkiness = bulkiness * 1.5
    end

    unitBulks[unitDefID] = min(bulkiness, 1) ^ 0.39 -- Scale bulks to [0,1] and curve them upward towards 1.
end

local bulkMin = unitBulks[UnitDefNames[minUnitBounces].id] or 0.1
for unitDefID in pairs(UnitDefs) do
    if unitBulks[unitDefID] < bulkMin then
        unitBulks[unitDefID] = nil
    end
end

local spawnCache  = {
    pos     = { 0, 0, 0 },
    speed   = { 0, 0, 0 },
    owner   = 0,
    ttl     = defaultSpawnTtl,
    gravity = mapGravity,
}

local directions = DirectionsUtil.Directions
local maxDataNum = 2
for _, data in pairs(dataTable) do
    if data.number > maxDataNum then maxDataNum = data.number end
end
DirectionsUtil.ProvisionDirections(maxDataNum)

--------------------------------------------------------------------------------
-- Functions -------------------------------------------------------------------

local function GetSurfaceDeflection(ex, ey, ez)
    -- Deflection from deep water, shallow water, and solid terrain.
    local elevation = spGetGroundHeight(ex, ez)
    local separation
    local dx, dy, dz
    if elevation < deepWaterDepth then
        separation = ey - deepWaterDepth / 3
        dx = 0
        dy = 1
        dz = 0
    else
        separation = ey - elevation
        local slope
        dx, dy, dz, slope = spGetGroundNormal(ex, ez, true)
        if slope > 0.1 or slope * separation > 10 then
            separation = separation * cos(slope)
            local shift = separation * sin(slope) / sqrt(dx*dx + dz*dz)
            local sx = ex - dx * shift -- Next surface x, z
            local sz = ez - dz * shift
            elevation = max(elevation, spGetGroundHeight(sx, sz))
            separation = ey - elevation
            dx, dy, dz = spGetGroundNormal(sx, sz, true)
        end
        if elevation <= 0 then
            separation = ey - max(elevation / 2, deepWaterDepth / 3)
            dx = dx * 0.9
            dz = dz * 0.9
            dy = dy < 0.9 and dy / sqrt(dx*dx + dz*dz) * (1/0.9) or 0.9
        end
    end
    separation = 1.3 / sqrt(max(1, separation))
    dx = dx * separation
    dy = dy * separation
    dz = dz * separation

    -- Additional deflection from units, from none to solid-terrain-like.
    local unitsNearby = spGetUnitsInSphere(ex, ey, ez, 270/2) -- gettin yuge (air repair pad size)
    local bounce, ux, uy, uz, uw, radius
    for _, unitID in ipairs(unitsNearby) do
        bounce = unitBulks[spGetUnitDefID(unitID)]
        if bounce then
            _,_,_,ux,uy,uz = spGetUnitPosition(unitID, true)
            radius         = spGetUnitRadius(unitID)
            if uy + radius > 0 then
                ux, uy, uz = ex-ux, ey-uy, ez-uz
                separation = sqrt(ux*ux + uy*uy + uz*uz) / radius
                if separation < 1.24 then
                    bounce = bounce / max(1, separation)
                    local th_z = atan2(ux, uz)
                    local ph_y = atan2(uy, sqrt(ux*ux + uz*uz))
                    local cosy = cos(ph_y)
                    dx = dx + bounce * sin(th_z) * cosy
                    dy = dy + bounce * sin(ph_y)
                    dz = dz + bounce * cos(th_z) * cosy
                end
            end
        end
    end
    return { dx, dy, dz }
end

local function SpawnClusterProjectiles(data, projectileID, attackerID, ex, ey, ez)
    local clusterDefID = data.weaponID
    local projectileCount = data.number
    local projectileSpeed = data.weaponSpeed

    local px, py, pz = spGetProjectileVelocity(projectileID)
    px = px / projectileSpeed * 0.05
    py = py / projectileSpeed * 0.05
    pz = pz / projectileSpeed * 0.05

    spawnCache.owner = attackerID or -1
    spawnCache.ttl = data.weaponTtl
    local speed = spawnCache.speed
    local pos = spawnCache.pos

    local directions = directions[projectileCount]
    local deflection = GetSurfaceDeflection(ex, ey, ez)
    local spread = projectileSpeed / sqrt(projectileCount)

    for ii = 0, (projectileCount-1) do
        local vx = directions[3*ii+1]
        local vy = directions[3*ii+2]
        local vz = directions[3*ii+3]

        vx = vx + deflection[1]
        vy = vy + deflection[2]
        vz = vz + deflection[3]

        vx = vx + (rand() - 0.5) * spread + px
        vy = vy + (rand() - 0.5) * spread + py
        vx = vx + (rand() - 0.5) * spread + pz

        local normalization = projectileSpeed / sqrt(vx*vx + vy*vy + vz*vz)
        vx = vx * normalization
        vy = vy * normalization
        vz = vz * normalization

        speed[1] = vx
        speed[2] = vy
        speed[3] = vz

        pos[1] = ex + vx * gameSpeed / 2
        pos[2] = ey + vy * gameSpeed / 2
        pos[3] = ez + vz * gameSpeed / 2

        spSpawnProjectile(clusterDefID, spawnCache)
    end
end

--------------------------------------------------------------------------------
-- Gadget callins --------------------------------------------------------------

function gadget:Initialize()
    if not next(dataTable) then
        Spring.Log(gadget:GetInfo().name, LOG.INFO, "Removing gadget. No weapons found.")
        gadgetHandler:RemoveGadget(self)
        return
    end

    for weaponDefID in pairs(dataTable) do
        Script.SetWatchExplosion(weaponDefID, true)
    end
end

function gadget:Explosion(weaponDefID, ex, ey, ez, attackerID, projectileID)
    local weaponData = dataTable[weaponDefID]
    if weaponData then
        SpawnClusterProjectiles(weaponData, projectileID, attackerID, ex, ey, ez)
    end
end
