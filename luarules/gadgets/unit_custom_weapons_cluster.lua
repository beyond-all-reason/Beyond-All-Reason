function gadget:GetInfo()
    return {
        name    = 'Cluster Munitions',
        desc    = 'Custom behavior for projectiles that explode and split on impact.',
        author  = 'efrec',
        version = '1.1',
        date    = '2024-06-07',
        license = 'GNU GPL, v2 or later',
        layer   = 0,
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
            local captures = string.match(wdef.name, '([^_]+)')
            for ii = 1, #captures do
                local possibleName = table.concat(captures, '_', 1, ii)
                if UnitDefNames[possibleName] ~= nil then
                    dataTable[wdid].def = possibleName .. '_' .. defaultSpawnDef
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
    elseif udef.customParams and udef.customParams.neutral_when_closed then -- Dragon turrets
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

-- Spring.Debug.TableEcho(
--     {
--         ['Tick bulk']     = unitBulk[ UnitDefNames["armflea"].id  ],
--         ['Pawn bulk']     = unitBulk[ UnitDefNames["armpw"].id    ],
--         ['Gauntlet bulk'] = unitBulk[ UnitDefNames["armguard"].id ],
--         ['Pulsar bulk']   = unitBulk[ UnitDefNames["armanni"].id  ],
--         ['Thor bulk']     = unitBulk[ UnitDefNames["armthor"].id  ],
--     }
-- )

-- Reusable table for reducing garbage

local spawnCache  = {
    pos     = { 0, 0, 0 },
    speed   = { 0, 0, 0 },
    owner   = 0,
    ttl     = defaultSpawnTtl,
    gravity = mapGravity,
}

--------------------------------------------------------------------------------------------------------------
-- Functions -------------------------------------------------------------------------------------------------

local function RandomVector3(n)
    if n == nil then n = 1 end
    local vecs = {}
    for ii = 1, 3*(n-1)+1, 3 do
        local m1, m2, m3, m4       -- Marsaglia procedure:
        repeat                     -- The method begins by sampling & rejecting points.
            m1 = 2 * rand() - 1    -- The result can be transformed into radial coords.
            m2 = 2 * rand() - 1
            m3 = m1 * m1 + m2 * m2
        until (m3 < 1)
        m4 = (1 - m3) ^ 0.5
        vecs[ii  ] = 2 * m1 * m4 -- x
        vecs[ii+1] = 2 * m2 * m4 -- y
        vecs[ii+2] = 1 -  2 * m3 -- z
    end
    return vecs
end

-- Use spacings to replace random direction vectors
-- Randomness produces clumping at small sample sizes, so we scatter evenly-spaced vectors instead.
-- Credit to Hardin, Sloane, & Smith (and contribs) for the tables at neilsloane.com/packings/dim3/
-- To add more, fetch neilsloane.com/packings/dim3/pack.3.<n>.txt for next n, and replace newlines with commas.
local packedSpheres = {
   {},
   {  1, 0, 0,   -1, 0, 0  },
   {  1, 0, 0,   -0.5, 0, 0.866025403784439,   -0.5, 0, -0.866025403784438  },
   { -0.577350269072,  0.577350269072, -0.577350269072,  0.577350269072,  0.577350269072,  0.577350269072, -0.577350269072, -0.577350269072,  0.577350269072,  0.577350269072, -0.577350269072, -0.577350269072 },
   { -1.478255937088018300e-01,  8.557801392177640800e-01,  4.957700547280610200e-01,  9.298520676823500700e-01, -3.330452755499895800e-01, -1.563840677968503200e-01, -7.820264758448114400e-01, -5.227348665222011400e-01, -3.393859902820995400e-01, -3.612306945786420600e-02, -5.056147808319168000e-01,  8.620027942282061400e-01,  3.612306958303366400e-02,  5.056147801034870400e-01, -8.620027946502272200e-01 },
   {  0.212548255920, -0.977150570601,  0.000000000000, -0.977150570601, -0.212548255920,  0.000000000000, -0.212548255920,  0.977150570601,  0.000000000000,  0.977150570601,  0.212548255920,  0.000000000000,  0.000000000000,  0.000000000000,  1.000000000000,  0.000000000000,  0.000000000000, -1.000000000000 },
   { -9.476914051796328000e-01, -2.052179514558175300e-01, 2.444720698749264500e-01, 8.503710682661692600e-01, 4.830848344829018500e-01, 2.085619547004717300e-01, -4.995609516538522300e-01, 3.276811928816584800e-01, -8.019126457503652500e-01, -3.344875986220292000e-01, 8.899589445240678700e-01, 3.099856826204648300e-01, 2.420381484495352800e-02, -9.924430055046316000e-01, 1.202957030483007100e-01, 5.426485704335360500e-02, -8.987314180840469400e-02, 9.944738024058507000e-01, 5.948684088498340500e-01, -2.881863468134767100e-01, -7.503867040818149600e-01 },
   { -7.941044876934105800e-01, 3.289288487526511000e-01, 5.110810846464987100e-01, 3.289288487526511000e-01, -7.941044876934105800e-01, -5.110810846464987100e-01, 7.941044876934105800e-01, 3.289288487526511000e-01, -5.110810846464987100e-01, -3.289288487526511000e-01, -7.941044876934105800e-01, 5.110810846464987100e-01, -7.941044876934105800e-01, -3.289288487526511000e-01, -5.110810846464987100e-01, 3.289288487526511000e-01, 7.941044876934105800e-01, 5.110810846464987100e-01, 7.941044876934105800e-01, -3.289288487526511000e-01, 5.110810846464987100e-01, -3.289288487526511000e-01, 7.941044876934105800e-01, -5.110810846464987100e-01 },
   { -8.643506667047617900e-01, 5.383237842631424800e-02, -5.000000000000000000e-01, -5.299022434190759900e-01, 7.798028605204248000e-01, 3.333333333820566700e-01, -6.225653123557293200e-01, -7.080263559415142000e-01, 3.333333333820566700e-01, -4.633153446832672500e-02, -7.439146082309695500e-01, -6.666666667641134600e-01, -1.814158190933165000e-20, -3.736015732192668700e-20, 1.000000000000000000e+00, 8.643506667047617900e-01, -5.383237842631424800e-02, -5.000000000000000000e-01, 5.299022434190759900e-01, -7.798028605204248000e-01, 3.333333333820566700e-01, 6.225653123557293200e-01, 7.080263559415142000e-01, 3.333333333820566700e-01, 4.633153446832672500e-02, 7.439146082309695500e-01, -6.666666667641134600e-01 },
   { 1.272017215942770300e-01, -8.282613625701686900e-01, -5.457131456148549600e-01, 1.272017215942770300e-01, 8.282613625701686900e-01, 5.457131456148549600e-01, -7.924432042767676200e-01, -6.099457090557890400e-01, -2.741585411849682600e-20, 8.379720535542102300e-01, -1.947788276596200700e-27, -5.457131457662900400e-01, 1.272017215942770300e-01, -8.282613625701686900e-01, 5.457131456148549600e-01, 8.379720535542102300e-01, 1.058131978332546100e-19, 5.457131457662900400e-01, -5.103133233369202500e-01, -3.373110909106216600e-19, -8.599885534266302800e-01, -7.924432042767676200e-01, 6.099457090557890400e-01, -6.234852139790438900e-20, 1.272017215942770300e-01, 8.282613625701686900e-01, -5.457131456148549600e-01, -5.103133233369202500e-01, 1.058052789347472700e-19, 8.599885534266302800e-01 },
   { -8.506508083196721000e-01, -5.257311121715058100e-01, 0.000000000000000000e+00, 0.000000000000000000e+00, -8.506508083196721000e-01, -5.257311121715058100e-01, 0.000000000000000000e+00, 8.506508083196721000e-01, 5.257311121715058100e-01, -5.257311121715058100e-01, 0.000000000000000000e+00, -8.506508083196721000e-01, 0.000000000000000000e+00, 8.506508083196721000e-01, -5.257311121715058100e-01, 0.000000000000000000e+00, -8.506508083196721000e-01, 5.257311121715058100e-01, 5.257311121715058100e-01, 0.000000000000000000e+00, 8.506508083196721000e-01, 8.506508083196721000e-01, -5.257311121715058100e-01, 0.000000000000000000e+00, -5.257311121715058100e-01, 0.000000000000000000e+00, 8.506508083196721000e-01, 8.506508083196721000e-01, 5.257311121715058100e-01, 0.000000000000000000e+00, -8.506508083196721000e-01, 5.257311121715058100e-01, 0.000000000000000000e+00 },
   { 8.506508083520922800e-01, 8.461919126260937200e-21, -5.257311121190491000e-01, 5.257311121190491000e-01, -8.506508083520922800e-01, 0.000000000000000000e+00, 1.266847532837018700e-20, -5.257311121190491000e-01, 8.506508083520922800e-01, 8.506508083520922800e-01, 2.117154529536468700e-20, 5.257311121190491000e-01, -5.257311121190491000e-01, -8.506508083520922800e-01, 3.303943689239743800e-23, -4.393463640892673700e-21, 5.257311121190491000e-01, -8.506508083520922800e-01, -8.506508083520922800e-01, -8.452634485559703400e-21, -5.257311121190491000e-01, -5.257311121190491000e-01, 8.506508083520922800e-01, 6.548656517555661000e-21, 1.691455361231732600e-20, 5.257311121190491000e-01, 8.506508083520922800e-01, -8.506508083520922800e-01, 1.437620000877874100e-20, 5.257311121190491000e-01, 5.257311121190491000e-01, 8.506508083520922800e-01, -1.769525700386171300e-21, -1.447394738531641700e-20, -5.257311121190491000e-01, -8.506508083520922800e-01 },
   { -3.662782754263035300e-01, 7.559006998770361200e-01, 5.426364868640331000e-01, -9.408369689587646700e-01, 3.266601753606225300e-01, -9.010509238579085500e-02, 2.949031158172585300e-01, -6.086014011689210300e-01, -7.366386405670685100e-01, -7.408675404485654300e-20, 1.131011890285944400e-19, 1.000000000000000000e+00, -7.559006998770361200e-01, -3.662782754263035300e-01, 5.426364868640331000e-01, -3.266601753606225300e-01, -9.408369689587646700e-01, -9.010509238579085500e-02, 6.086014011689210300e-01, 2.949031158172585300e-01, -7.366386405670685100e-01, 3.662782754263035300e-01, -7.559006998770361200e-01, 5.426364868640331000e-01, 9.408369689587646700e-01, -3.266601753606225300e-01, -9.010509238579085500e-02, -2.949031158172585300e-01, 6.086014011689210300e-01, -7.366386405670685100e-01, 7.559006998770361200e-01, 3.662782754263035300e-01, 5.426364868640331000e-01, 3.266601753606225300e-01, 9.408369689587646700e-01, -9.010509238579085500e-02, -6.086014011689210300e-01, -2.949031158172585300e-01, -7.366386405670685100e-01 },
   { 6.946907954011297700e-01, 6.946907954011297700e-01, -1.865727674927167300e-01, -1.514598564738553500e-01, -8.118004501805740100e-01, 5.639503000828500800e-01, 8.118004501805740100e-01, 1.514598564738553500e-01, 5.639503000828500800e-01, -9.244833579897193300e-20, 1.696363851953479400e-20, 1.000000000000000000e+00, 3.564164657663047900e-20, 5.579881977585050800e-22, -1.000000000000000000e+00, -6.946907954011297700e-01, 6.946907954011297700e-01, 1.865727674927167300e-01, 1.514598564738553500e-01, -8.118004501805740100e-01, -5.639503000828500800e-01, -8.118004501805740100e-01, 1.514598564738553500e-01, -5.639503000828500800e-01, 6.946907954011297700e-01, -6.946907954011297700e-01, 1.865727674927167300e-01, -1.514598564738553500e-01, 8.118004501805740100e-01, -5.639503000828500800e-01, 8.118004501805740100e-01, -1.514598564738553500e-01, -5.639503000828500800e-01, -6.946907954011297700e-01, -6.946907954011297700e-01, -1.865727674927167300e-01, 1.514598564738553500e-01, 8.118004501805740100e-01, 5.639503000828500800e-01, -8.118004501805740100e-01, -1.514598564738553500e-01, 5.639503000828500800e-01 },
   { 3.051769020044634000e-01, -1.827216208011631400e-01, 9.346014486265010700e-01, -4.907082900156075600e-01, -4.074541928305096000e-01, -7.701859871841322300e-01, -8.509184718243962800e-01, -5.229714314530596900e-01, 4.938254946812591100e-02, 7.012202810984599100e-01, -6.570858127633901800e-01, 2.766375824816142400e-01, 9.555627298013018600e-01, -6.205070554219331900e-03, -2.947225246127304600e-01, 4.640178136061391400e-01, 7.161624359518460300e-01, -5.213432976338108200e-01, 3.293077595811665400e-01, -7.129347262317069200e-02, -9.415272912884480300e-01, -9.197709483984433100e-01, 3.744800967201638600e-01, 1.174140521517120100e-01, -1.486192639405116700e-01, -8.424318278596852900e-01, 5.179005018290389100e-01, -5.847106287835063300e-01, -1.058298387139187500e-01, 8.043093470956201900e-01, 2.450588634219090800e-01, -8.423966818187401700e-01, -4.799103915515254800e-01, -3.651725826023697900e-01, 4.861143234505876400e-01, -7.939407090278801600e-01, -5.940876942043927400e-02, 6.276928285275815700e-01, 7.761908986396279800e-01, -2.557474796815069600e-01, 9.660236791779427400e-01, -3.730251873625246900e-02, 7.271391725044883400e-01, 5.996412865218138100e-01, 3.342139304516675300e-01 },
   { 1.266109423779690200e-01, 9.635507195418956400e-01, -2.356685811483104400e-01, -5.918057918773704800e-01, 7.708607037331326500e-01, 2.356685811483104100e-01, 8.112044025054730700e-02, 6.173531063344418500e-01, 7.824925662731709900e-01, -3.791737544816633500e-01, 4.938953812696635900e-01, -7.824925662731708800e-01, -9.635507195418956400e-01, 1.266109423779690200e-01, -2.356685811483104400e-01, -7.708607037331326500e-01, -5.918057918773704800e-01, 2.356685811483104100e-01, -6.173531063344418500e-01, 8.112044025054730700e-02, 7.824925662731709900e-01, -4.938953812696635900e-01, -3.791737544816633500e-01, -7.824925662731708800e-01, -1.266109423779690200e-01, -9.635507195418956400e-01, -2.356685811483104400e-01, 5.918057918773704800e-01, -7.708607037331326500e-01, 2.356685811483104100e-01, -8.112044025054730700e-02, -6.173531063344418500e-01, 7.824925662731709900e-01, 3.791737544816633500e-01, -4.938953812696635900e-01, -7.824925662731708800e-01, 9.635507195418956400e-01, -1.266109423779690200e-01, -2.356685811483104400e-01, 7.708607037331326500e-01, 5.918057918773704800e-01, 2.356685811483104100e-01, 6.173531063344418500e-01, -8.112044025054730700e-02, 7.824925662731709900e-01, 4.938953812696635900e-01, 3.791737544816633500e-01, -7.824925662731708800e-01 }
}

-- Add any missing solutions to packedSpheres.
local number = 1
while number < #packedSpheres do
    number = number + 1
    for _, data in pairs(dataTable) do
        -- Expand packedSpheres, as needed.
        local target = data.number or 0
        if target > #packedSpheres then
            for jj = #packedSpheres + 1, target do packedSpheres[jj] = {} end
            packedSpheres[target] = RandomVector3(target)
        -- Then fill in any gaps.
        elseif target == number and number <= maxSpawnNumber then
            if packedSpheres[number] == nil then
                packedSpheres[number] = RandomVector3(number)
            end
        end
    end
end

local function GetSurfaceDeflection(ex, ey, ez)
    -- Deflection away from terrain.
    local distance = ey - spGetGroundHeight(ex, ez)
    local x,y,z, m = spGetGroundNormal(ex, ez, true)
    if m > 1e-2 then
        distance    = distance * cos(m)                 -- Actual distance given a flat plane with slope m.
        m           = distance * sin(m) / sqrt(x*x+z*z) -- Shift to next ground intercept; normalize {x,z}.
        local xx,zz = ex-x*m, ez-z*m
        distance    = min(distance, ey - spGetGroundHeight(xx, zz))
        x, y, z, _  = spGetGroundNormal(xx, zz, true)
    end
    distance = sqrt(max(1, distance))
    x, y, z  = 1.7*x/distance, 1.7*y/distance, 1.7*z/distance

    -- Deflection away from unit colliders.
    -- This is used to keep grenades-of-grenades from detonating on contact instead of spreading out.
    -- We have to check a radius ~ge the largest collider so we are, otherwise, way-too efficient.
    -- That mostly means not checking and not rotating the unit's collider around in world space.
    local colliders = spGetUnitsInSphere(ex, ey, ez, 80)
    local bounce, udefid, ux, uy, uz, uw, radius
    for _, uid in ipairs(colliders) do
        udefid = spGetUnitDefID(uid)
        bounce = unitBulk[udefid]
        if bounce ~= nil then
            -- Assuming spherical collider in frictionless vacuum
            _,_,_,ux,uy,uz = spGetUnitPosition(uid, true)
            radius         = spGetUnitRadius(uid)

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
    return { x, y, z }
end

local function SpawnClusterProjectiles(data, attackerID, ex, ey, ez, deflection)
    local projNum = data.number
    local projVel = data.projVel

    spawnCache.owner = attackerID or -1
    spawnCache.ttl   = data.projTtl

    -- Initial direction vectors are evenly spaced.
    local directions = packedSpheres[projNum]

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

function gadget:Explosion(weaponDefID, ex, ey, ez, attackerID, _)
    if not dataTable[weaponDefID] then return end
    local weaponData = dataTable[weaponDefID]
    local deflection = GetSurfaceDeflection(ex, ey, ez)
    SpawnClusterProjectiles(weaponData, attackerID, ex, ey, ez, deflection)
end
