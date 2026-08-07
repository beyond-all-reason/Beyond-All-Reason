--------------------------------------------------------------------------------
-- CEG Preview (Synced Gadget) written by Steel December 2025
--
-- Overview:
--   This gadget provides the synced execution layer for the CEG Browser UI.
--   It receives preview commands from LuaUI widgets and safely spawns Core
--   Effect Generator (CEG) effects in-game for visual inspection.
--
--   Two preview systems are implemented:
--
--     Ground CEG Tester:
--       - Spawns one or more CEGs directly on the ground
--       - Supports line, ring, and scatter patterns
--       - Handles multi-selection, spacing, count, and height offset
--
--     Projectile CEG Preview:
--       - Spawns an invisible helper unit to emit test projectiles
--       - Attaches selected CEGs as projectile trails
--       - Supports optional impact and muzzle flash CEGs
--       - Handles yaw, pitch, speed, gravity, TTL, spawn offsets, airburst toggle, and cleanup timing
--
-- Message protocol:
--   This gadget listens for the following LuaRules messages (protocol-stable):
--
--     cegtest:        Single ground CEG spawn
--     cegtest_multi:  Multiple ground CEG spawn
--     cegproj:        Projectile-based CEG preview
--
-- Dependencies:
--   - units/other/ceg_test_projectile.lua
--       Helper unit used for projectile previews.
--       Carries a lightweight weapon definition for ballistic testing.
--
-- Notes:
--   - This gadget does NOT modify CEG definitions or gameplay units.
--   - All spawned units and effects are temporary and cleaned up automatically.
--   - Intended for developer and artist tooling only.
--
--------------------------------------------------------------------------------


function gadget:GetInfo()
    return {
        name    = "CEG Preview",
        desc    = "Synced execution for ground and projectile CEG preview",
        author  = "Steel",
	date    = "December 2025",
        enabled = true,
        layer   = 0,
    }
end

--------------------------------------------------------------------------------
-- SYNCED / UNSYNCED SPLIT
--------------------------------------------------------------------------------
if gadgetHandler:IsSyncedCode() then
--------------------------------------------------------------------------------
-- Engine refs
--------------------------------------------------------------------------------
local spSpawnCEG        = Spring.SpawnCEG

-- TTL / Airburst (dummy-unit projectile) tracking
local pendingShots = {}
local liveProjectiles = {}
local spDeleteProjectile = Spring.DeleteProjectile or Spring.DestroyProjectile
local spGetGroundHeight = Spring.GetGroundHeight
local spEcho            = Spring.Echo

local spCreateUnit         = Spring.CreateUnit
local spDestroyUnit        = Spring.DestroyUnit
local spGiveOrderToUnit    = Spring.GiveOrderToUnit
local spValidUnitID        = Spring.ValidUnitID
local spSetUnitWeaponState = Spring.SetUnitWeaponState
local spGetGameFrame       = Spring.GetGameFrame
local spSetUnitRulesParam  = Spring.SetUnitRulesParam

--------------------------------------------------------------------------------
-- Math
--------------------------------------------------------------------------------
local math   = math
local cos    = math.cos
local sin    = math.sin
local sqrt   = math.sqrt
local pi     = math.pi
local random = math.random

--------------------------------------------------------------------------------
-- Message prefixes (UNCHANGED)
--------------------------------------------------------------------------------
local PREFIX_SINGLE = "cegtest:"
local PREFIX_MULTI  = "cegtest_multi:"
local PREFIX_GROUND = "ceg:"
local PREFIX_PROJ   = "cegproj:"

--------------------------------------------------------------------------------
-- Permission gate (mirrors cmd_dev_helpers isAuthorized, devhelpers only)
--------------------------------------------------------------------------------
local function isAuthorized(playerID)
    local playername = Spring.GetPlayerInfo(playerID)
    local accountID  = Spring.Utilities and Spring.Utilities.GetAccountID and
                       Spring.Utilities.GetAccountID(playerID)
    -- accountID of -1 means offline/singleplayer -- treat as no valid account
    if accountID and accountID <= 0 then accountID = nil end

    -- devhelpers permission bypasses cheat requirement (authorized users in any game)
    if (_G and _G.permissions and _G.permissions.devhelpers and
        (accountID and _G.permissions.devhelpers[accountID] or
         (playername and _G.permissions.devhelpers[playername]))) or
       (SYNCED and SYNCED.permissions and SYNCED.permissions.devhelpers and
        (accountID and SYNCED.permissions.devhelpers[accountID] or
         (playername and SYNCED.permissions.devhelpers[playername]))) then
        return true
    end
    -- Fall back to cheat requirement for everyone else (covers singleplayer testing)
    if Spring.IsCheatingEnabled() then
        return true
    end
    return false
end

-- Resolve dummy weaponDefID (dummy unit fires the projectile)
local dummyWeaponDefID
do
    local ud = UnitDefNames and UnitDefNames["ceg_test_projectile_unit"]
    if ud and ud.weapons and ud.weapons[1] then
        dummyWeaponDefID = ud.weapons[1].weaponDef
    end
end


--------------------------------------------------------------------------------
-- ============================================================================
-- SECTION 1: GROUND CEG TESTER (from game_ceg_tester.lua)
-- ============================================================================
--------------------------------------------------------------------------------

local currentImpactSound

local function SpawnCEG(name, x, z, height)
    if not name or name == "" then return end
    x = tonumber(x)
    z = tonumber(z)
    if not x or not z then
        spEcho("[CEG Tester] ERROR: bad coordinates")
        return
    end

    height = tonumber(height) or 0
    local y = (spGetGroundHeight(x, z) or 0) + height
    spSpawnCEG(name, x, y, z, 0, 1, 0, 0, 0)
    if currentImpactSound then
        SendToUnsynced("ceg_world_sound", currentImpactSound, x, y, z, 3.0)
    end
end

local function SpawnCEGSet(names, x, z, height)
    if type(names) ~= "table" then return end
    for i = 1, #names do
        SpawnCEG(names[i], x, z, height)
    end
end

local function SpawnPattern(names, x, z, count, spacing, pat, height)
    count   = math.max(1, math.min(100, count or 1))
    spacing = math.max(0, spacing or 0)
    pat     = (pat == "ring" or pat == "scatter") and pat or "line"

    if pat == "line" then
        for i = 0, count - 1 do
            SpawnCEGSet(names, x + i * spacing, z, height)
        end

    elseif pat == "ring" then
        local radius = spacing * 5
        for i = 0, count - 1 do
            local a = (2 * pi * i) / count
            SpawnCEGSet(names,
                x + radius * cos(a),
                z + radius * sin(a),
                height
            )
        end

    elseif pat == "scatter" then
        local radius = spacing * 3
        for i = 1, count do
            local r = radius * sqrt(random())
            local a = 2 * pi * random()
            SpawnCEGSet(names,
                x + r * cos(a),
                z + r * sin(a),
                height
            )
        end
    end
end

--------------------------------------------------------------------------------
-- ============================================================================
-- SECTION 2: PROJECTILE CEG PREVIEW (from game_ceg_projectile_preview.lua)
-- ============================================================================
--------------------------------------------------------------------------------

local TEST_UNIT_NAME    = "ceg_test_projectile_unit"
local TEST_WEAPON_INDEX = 1

local SPAWN_LIFT        = 12
local CLEANUP_FRAMES    = 30 * 10

local TRAIL_EVERY_FRAMES = 1
local MAX_TRAIL_FRAMES   = 30 * 6

local DEFAULT_GRAVITY = 0.16


-- ============================================================================
-- PROJECTILE ORIGIN OFFSETS (TWEAK THESE)
-- ============================================================================
-- Units: elmos
-- Forward: pushes projectile + muzzle flash in front of the unit
-- Up: lifts projectile + muzzle flash off the ground
local PROJECTILE_FORWARD_OFFSET = 20
local PROJECTILE_UP_OFFSET      = 20

local cleanupQueue = {}
local trails = {}
local trailSeq = 0

local function DegToRad(d) return d * pi / 180 end
local function Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function FireCEGTestProjectile(ceg, impactBlock, muzzleBlock, fireSound, impactSound, x, z, yawDeg, pitchDeg, speed, gravity, ttlFrames, airburst, fwdOfs, upOfs)
    x = tonumber(x)
    z = tonumber(z)
    if not x or not z then return end

    local impactCEGs = {}
    if impactBlock and impactBlock ~= "" then
        for n in impactBlock:gmatch("([^,]+)") do
            impactCEGs[#impactCEGs+1] = n
        end
    end
    local muzzleCEGs = {}
    if muzzleBlock and muzzleBlock ~= "" then
        for n in muzzleBlock:gmatch("([^,]+)") do
            muzzleCEGs[#muzzleCEGs+1] = n
        end
    end


    yawDeg   = Clamp(tonumber(yawDeg)   or 0, -180, 180)
    pitchDeg = Clamp(tonumber(pitchDeg) or 0,  -89,  89)
    speed    = Clamp(tonumber(speed)    or 0,    0, 5000)
    gravity  = tonumber(gravity) or DEFAULT_GRAVITY

    local baseY = (spGetGroundHeight(x, z) or 0) + SPAWN_LIFT

    local yaw   = DegToRad(yawDeg)
    local pitch = DegToRad(pitchDeg)

    local dx = cos(pitch) * cos(yaw)
    local dy = sin(pitch)
    local dz = cos(pitch) * sin(yaw)


-- Apply forward + upward offsets so projectile origin matches muzzle flash origin
local fwd = tonumber(fwdOfs) or 0
    local up  = tonumber(upOfs)  or 0

    -- Dummy unit spawns at mouse cursor (authoritative origin)
    local unitX = x
    local unitY = baseY
    local unitZ = z

    -- Projectile / muzzle origin (visual offset only)
    local spawnX = unitX + dx * (PROJECTILE_FORWARD_OFFSET + fwd)
    local spawnY = unitY + (PROJECTILE_UP_OFFSET + up)
    local spawnZ = unitZ + dz * (PROJECTILE_FORWARD_OFFSET + fwd)

    -- Optional muzzle flash CEG(s): spawned once at projectile origin
    if muzzleCEGs and #muzzleCEGs > 0 then
        for i = 1, #muzzleCEGs do
            spSpawnCEG(muzzleCEGs[i], spawnX, spawnY, spawnZ, dx, dy, dz)
        end
    end

    -- Fire sound (once, at muzzle origin)
    if fireSound then
        SendToUnsynced("ceg_world_sound", fireSound, spawnX, spawnY, spawnZ, 3.0)
    end

    local unitID = spCreateUnit(
        TEST_UNIT_NAME,
        unitX, unitY, unitZ,
        0,
        Spring.GetGaiaTeamID()
    )
    if not unitID then return end

    spSetUnitRulesParam(unitID, "no_autofire", 1)
    spGiveOrderToUnit(unitID, CMD.STOP, {}, {})

    -- VISUAL AIM (baseline-correct: applied AFTER STOP)
    Spring.SetUnitDirection(unitID, dx, 0, dz)

    spSetUnitWeaponState(unitID, TEST_WEAPON_INDEX, {
        weaponVelocity = speed,
    })

    local dist = math.max(256, speed * 2)
    spGiveOrderToUnit(unitID, CMD.ATTACK, {
        spawnX + dx * dist,
        spawnY + dy * dist,
        spawnZ + dz * dist
    }, {})

    cleanupQueue[unitID] = spGetGameFrame() + CLEANUP_FRAMES

    trailSeq = trailSeq + 1
    trails[trailSeq] = {
        ceg   = ceg,
        impactCEGs = impactCEGs,
        impactSound = impactSound,
        gravity = gravity,
        x     = spawnX,
        y     = spawnY,
        z     = spawnZ,
        vx    = dx * speed,
        vy    = dy * speed,
        vz    = dz * speed,
        nextF = spGetGameFrame(),
        endF  = spGetGameFrame() + (ttlFrames or MAX_TRAIL_FRAMES),
        airburst = airburst,
    }
end

function gadget:GameFrame(f)
    for unitID, deathFrame in pairs(cleanupQueue) do
        if f >= deathFrame then
            if spValidUnitID(unitID) then
                spDestroyUnit(unitID, false, true)
            end
            cleanupQueue[unitID] = nil
        end
    end

    for id, t in pairs(trails) do
        if f >= t.endF then
            if t.airburst and t.impactCEGs and #t.impactCEGs > 0 then
                for i = 1, #t.impactCEGs do
                    spSpawnCEG(t.impactCEGs[i], t.x, t.y, t.z, 0, 1, 0)
                end
                if t.impactSound then
                    SendToUnsynced("ceg_world_sound", t.impactSound, t.x, t.y, t.z, 3.0)
                end
            end
            trails[id] = nil
        else
            if f >= t.nextF then
                spSpawnCEG(t.ceg, t.x, t.y, t.z, t.vx, t.vy, t.vz)
                t.nextF = f + TRAIL_EVERY_FRAMES
            end

            t.x = t.x + t.vx
            t.y = t.y + t.vy
            t.z = t.z + t.vz
            t.vy = t.vy - t.gravity

            local gy = spGetGroundHeight(t.x, t.z) or 0
            if t.y <= gy then
                if t.impactCEGs and #t.impactCEGs > 0 then
                    for i = 1, #t.impactCEGs do
                        spSpawnCEG(t.impactCEGs[i], t.x, gy, t.z, 0, 1, 0)
                    end
                    if t.impactSound then
                        SendToUnsynced("ceg_world_sound", t.impactSound, t.x, gy, t.z, 3.0)
                    end
                end
                trails[id] = nil
            end
        end
    end
    -- TTL / Airburst enforcement for engine projectiles spawned by dummy unit
    for proID, data in pairs(liveProjectiles) do
        if f >= data.expireFrame then
            if data.airburst and data.impactCEGs and Spring.GetProjectilePosition then
                local x, y, z = Spring.GetProjectilePosition(proID)
                if x then
                    for i = 1, #data.impactCEGs do
                        spSpawnCEG(data.impactCEGs[i], x, y, z, 0, 1, 0)
                    end
                end
            end
            if spDeleteProjectile then
                spDeleteProjectile(proID)
            end
            liveProjectiles[proID] = nil
        end
    end

end

--------------------------------------------------------------------------------
-- ============================================================================
-- SECTION 3: MESSAGE ROUTER (unchanged protocol)
-- ============================================================================
--------------------------------------------------------------------------------

function gadget:RecvLuaMsg(msg, playerID)
    if not isAuthorized(playerID) then return end

    -- UI-ONLY SOUND PREVIEW (no position, no mode dependency)
    if msg:sub(1, 18) == "ceg_preview_sound:" then
        local soundName = msg:sub(19)
        if soundName and soundName ~= "" then
            SendToUnsynced("ceg_preview_sound", soundName)
        end
        return
    end

    -- PROJECTILE
    if msg:sub(1, #PREFIX_PROJ) == PREFIX_PROJ or msg:sub(1, #PREFIX_GROUND) == PREFIX_GROUND then
        local body = (msg:sub(1, #PREFIX_PROJ) == PREFIX_PROJ) and msg:sub(#PREFIX_PROJ + 1) or msg:sub(#PREFIX_GROUND + 1)

        -- Optional suffixes: |ttl=seconds |airburst=0|1 |muzzle=...
        local ttlFrames
        local airburst = false
        local muzzleBlock
        local fireSound
        local impactSound

        local fwdOfs, upOfs
        do
            local tmp = body
            while true do
                local core, key, val = tmp:match("^(.-)|(%w+)=([^|]*)$")
                if not core then break end
                tmp = core
                if key == "ttl" then
                    local s = tonumber(val)
                    if s then
                        if s < 1 then s = 1 end
                        if s > 30 then s = 30 end
                        ttlFrames = math.floor(s * 30 + 0.5)
                    end
                elseif key == "airburst" then
                    airburst = (val == "1")
                elseif key == "ofs" then
                    local a,b = val:match("([^,]+),([^,]+)")
                    if a and b then
                        fwdOfs = tonumber(a) or 0
                        upOfs  = tonumber(b) or 0
                    end
                elseif key == "muzzle" then
                    muzzleBlock = val
                elseif key == "fireSound" then
                    fireSound = val
                elseif key == "impactSound" then
                    impactSound = val
                end
            end
            body = tmp
        end
        -- Robust parse: accept both formats
        --   A) trail|impact:x:z:yaw:pitch:speed:gravity
        --   B) trail:impact:x:z:yaw:pitch:speed:gravity
        local parts = {}
        for seg in body:gmatch("([^:]+)") do
            parts[#parts+1] = seg
        end

        local trailCEG, impactBlock, xs, zs, yaw, pitch, speed, gravity

        if #parts == 7 then
            -- parts[1] = trail|impact  OR  trail
            local cegBlock = parts[1]
            trailCEG, impactBlock = cegBlock:match("^([^|]+)|?(.*)$")
            xs, zs, yaw, pitch, speed, gravity = parts[2], parts[3], parts[4], parts[5], parts[6], parts[7]
        elseif #parts == 8 then
            -- parts[1]=trail, parts[2]=impact
            trailCEG, impactBlock = parts[1], parts[2]
            xs, zs, yaw, pitch, speed, gravity = parts[3], parts[4], parts[5], parts[6], parts[7], parts[8]
        else
            return
        end

        if not trailCEG or trailCEG == "" then return end

        FireCEGTestProjectile(trailCEG, impactBlock, muzzleBlock, fireSound, impactSound, xs, zs, yaw, pitch, speed, gravity, ttlFrames, airburst, fwdOfs, upOfs)
        return
    end

    -- GROUND
    local isMulti = false
    local body

    if msg:sub(1, #PREFIX_MULTI) == PREFIX_MULTI then
        isMulti = true
        body    = msg:sub(#PREFIX_MULTI + 1)
    elseif msg:sub(1, #PREFIX_SINGLE) == PREFIX_SINGLE then
        body = msg:sub(#PREFIX_SINGLE + 1)
    else
        return
    end

    local nameField, xs, zs, cs, ss, pat, hs =
        body:match("^([^:]+):([^:]+):([^:]+):([^:]+):([^:]+):([^:]+):?(.*)$")
    if not nameField then
        spEcho("[CEG Tester] ERROR: bad message: " .. tostring(msg))
        return
    end

    local names = {}
    if isMulti then
        for n in nameField:gmatch("([^,]+)") do
            names[#names+1] = n
        end
    else
        names[1] = nameField
    end

    -- Parse optional suffixes appended to the height field (e.g. "12|impactSound=weapons/flakfire")
    local height = 0
    local groundImpactSound
    if hs and hs ~= "" then
        local tmp = hs
        while true do
            local core, key, val = tmp:match("^(.-)|(%w+)=([^|]*)$")
            if not core then break end
            tmp = core
            if key == "impactSound" then
                groundImpactSound = val
            end
        end
        height = tonumber(tmp) or 0
    end

    currentImpactSound = groundImpactSound
    SpawnPattern(
        names,
        tonumber(xs),
        tonumber(zs),
        tonumber(cs) or 1,
        tonumber(ss) or 0,
        pat,
        height
    )
end

function gadget:Initialize()
    if dummyWeaponDefID and Script and Script.SetWatchWeapon then
        Script.SetWatchWeapon(dummyWeaponDefID, true)
    end
end

function gadget:ProjectileCreated(proID, proOwnerID, weaponDefID)
    if not dummyWeaponDefID or weaponDefID ~= dummyWeaponDefID then return end
    local shot = table.remove(pendingShots, 1)
    if not shot then return end
    liveProjectiles[proID] = {
        expireFrame = Spring.GetGameFrame() + (shot.ttlFrames or MAX_TRAIL_FRAMES),
        airburst = shot.airburst,
        impactCEGs = shot.impactCEGs,
    }
end

--------------------------------------------------------------------------------
-- UNSYNCED ONLY
--------------------------------------------------------------------------------
else

-- Sound preview playback (UI channel)
function gadget:Initialize()
    gadgetHandler:AddSyncAction("ceg_preview_sound", function(_, soundName)
        if not soundName or soundName == "" then return end

        -- Normalize logical IDs like "weapons/flakfire" -> "sounds/weapons/flakfire.wav"
        local p = soundName
        if p:sub(1, 7) ~= "sounds/" then
            p = "sounds/" .. p
        end
        if not p:find("%.[%a%d]+$") then
            p = p .. ".wav"
        end

        Spring.PlaySoundFile(p, 1.0, "ui")
    end)

    gadgetHandler:AddSyncAction("ceg_world_sound", function(_, soundName, x, y, z, vol)
        if not soundName or soundName == "" then return end
        local v = tonumber(vol) or 1.0

        -- Normalize logical IDs like "weapons/flakfire" -> "sounds/weapons/flakfire.wav"
        local p = soundName
        if p:sub(1, 7) ~= "sounds/" then
            p = "sounds/" .. p
        end
        if not p:find("%.[%a%d]+$") then
            p = p .. ".wav"
        end

        if x and y and z then
            Spring.PlaySoundFile(p, v, "ui")
        end
    end)

end

end -- gadgetHandler:IsSyncedCode()

