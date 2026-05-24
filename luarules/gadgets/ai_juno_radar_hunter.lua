function gadget:GetInfo()
    return {
        name      = "AI Juno Radar/Jammer Hunter",
        desc      = "AI Junos auto-fire at enemy radars and jammers (full-vision)",
        author    = "Felnious",
        date      = "2026-05-24",
        layer     = 0,
        enabled   = true,
    }
end

if not gadgetHandler:IsSyncedCode() then
    return false
end

local spGetTeamList          = Spring.GetTeamList
local spGetTeamLuaAI         = Spring.GetTeamLuaAI
local spGetTeamInfo          = Spring.GetTeamInfo
local spGetUnitDefID         = Spring.GetUnitDefID
local spGetUnitTeam          = Spring.GetUnitTeam
local spGetUnitPosition      = Spring.GetUnitPosition
local spGetUnitAllyTeam      = Spring.GetUnitAllyTeam
local spGetUnitStockpile     = Spring.GetUnitStockpile
local spGetAllUnits          = Spring.GetAllUnits
local spGetGroundHeight      = Spring.GetGroundHeight
local spGiveOrderToUnit      = Spring.GiveOrderToUnit
local spGetGameSeconds       = Spring.GetGameSeconds
local spEcho                 = Spring.Echo

local CMD_STOCKPILE = CMD.STOCKPILE
local CMD_ATTACK    = CMD.ATTACK

-- Juno unit names
local JUNO_NAMES = {
    armjuno = true,
    corjuno = true,
    legjuno = true,
}

-- Build set of Juno UnitDefIDs + per-def range
local junoDefIDs = {}
local junoDefRange = {}
for name in pairs(JUNO_NAMES) do
    local def = UnitDefNames[name]
    if def then
        junoDefIDs[def.id] = true
        local r = 0
        if def.weapons then
            for i = 1, #def.weapons do
                local wdid = def.weapons[i].weaponDef
                local wdef = wdid and WeaponDefs[wdid]
                if wdef and wdef.range and wdef.range > r then
                    r = wdef.range
                end
            end
        end
        if r <= 0 then r = 3500 end
        junoDefRange[def.id] = r
    else
        spEcho("[AI JunoHunter] WARNING: UnitDef not found: " .. name)
    end
end

-- Precompute the set of UnitDefIDs that count as radars or jammers
local radarOrJammerDefID = {}
for udid, def in pairs(UnitDefs) do
    local isRadar  = (def.radarDistance  or 0) > 0
    local isJammer = (def.radarDistanceJam or 0) > 0 or (def.jammerRadius or 0) > 0
    if (isRadar or isJammer) and not def.canFly then
        local strongRadar = (def.radarDistance or 0) >= 1000
        local strongJam   = (def.radarDistanceJam or 0) >= 300 or (def.jammerRadius or 0) >= 300
        if (not def.canMove) and (strongRadar or strongJam) then
            radarOrJammerDefID[udid] = true
        end
    end
end

local aiTeams = {}
local function refreshAITeams()
    aiTeams = {}
    local gaiaID = Spring.GetGaiaTeamID()
    for _, teamID in ipairs(spGetTeamList()) do
        if teamID ~= gaiaID then
            local _, _, isDead, isAiTeam = spGetTeamInfo(teamID, false)
            local luaAI = spGetTeamLuaAI(teamID)
            local isLuaAI = (luaAI ~= nil and luaAI ~= "")
            if (isAiTeam or isLuaAI) and not isDead then
                aiTeams[teamID] = true
            end
        end
    end
end

local CMD_FIRE_STATE = CMD.FIRE_STATE
local FIRESTATE_HOLD = 0

local trackedJunos = {} -- unitID -> nextFireSecond

local function queueStockpile(unitID)
    for _ = 1, 5 do
        spGiveOrderToUnit(unitID, CMD_STOCKPILE, {}, 0)
    end
end

local function setHoldFire(unitID)
    spGiveOrderToUnit(unitID, CMD_FIRE_STATE, { FIRESTATE_HOLD }, 0)
end

local function setupJuno(unitID)
    setHoldFire(unitID)
    queueStockpile(unitID)
end

local refreshEnemyStarts

function gadget:Initialize()
    refreshAITeams()
    refreshEnemyStarts()
    spEcho("[AI JunoHunter] Initialized")
    for _, unitID in ipairs(spGetAllUnits()) do
        local defID = spGetUnitDefID(unitID)
        if defID and junoDefIDs[defID] and aiTeams[spGetUnitTeam(unitID)] then
            trackedJunos[unitID] = spGetGameSeconds() + math.random(5, 15)
            setupJuno(unitID)
        end
    end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
    if junoDefIDs[unitDefID] and aiTeams[unitTeam] then
        trackedJunos[unitID] = spGetGameSeconds() + math.random(5, 15)
        setupJuno(unitID)
    end
end

function gadget:UnitGiven(unitID, unitDefID, newTeam)
    if junoDefIDs[unitDefID] and aiTeams[newTeam] then
        trackedJunos[unitID] = spGetGameSeconds() + math.random(5, 15)
        setupJuno(unitID)
    elseif trackedJunos[unitID] and not aiTeams[newTeam] then
        trackedJunos[unitID] = nil
    end
end

function gadget:UnitDestroyed(unitID)
    trackedJunos[unitID] = nil
end

function gadget:TeamDied(teamID)
    aiTeams[teamID] = nil
end

local claimedTargets = {}
local CLAIM_DURATION = 30 -- seconds a base is "reserved" after being shot at

local function purgeClaims(now)
    for k, expire in pairs(claimedTargets) do
        if expire <= now then claimedTargets[k] = nil end
    end
end

local enemyStarts = {}
local spGetTeamStartPosition = Spring.GetTeamStartPosition

function refreshEnemyStarts()
    enemyStarts = {}
    local teams = spGetTeamList()
    local gaiaID = Spring.GetGaiaTeamID()
    -- Per-team metadata
    local meta = {}
    for _, tID in ipairs(teams) do
        if tID ~= gaiaID then
            local _, _, isDead, _, _, allyID = spGetTeamInfo(tID, false)
            local sx, _, sz = spGetTeamStartPosition(tID)
            meta[tID] = { allyID = allyID, isDead = isDead, sx = sx, sz = sz }
        end
    end
    -- Build per-ally enemy lists
    local seenAllies = {}
    for tID, m in pairs(meta) do
        if not seenAllies[m.allyID] then
            seenAllies[m.allyID] = true
            local list = {}
            for otherID, om in pairs(meta) do
                if om.allyID ~= m.allyID and not om.isDead
                    and om.sx and om.sz and om.sx > 0 and om.sz > 0 then
                    list[#list + 1] = { teamID = otherID, x = om.sx, z = om.sz }
                end
            end
            enemyStarts[m.allyID] = list
        end
    end
end

local CLUSTER_CELL = 384
local function pickClosestEnemyTarget(junoID, now)
    local sx, _, sz = spGetUnitPosition(junoID)
    if not sx then return nil end
    local junoAlly = spGetUnitAllyTeam(junoID)
    local defID = spGetUnitDefID(junoID)
    local range = junoDefRange[defID] or 3500
    local rangeSq = range * range

    local cells = {}
    local allUnits = spGetAllUnits()
    for i = 1, #allUnits do
        local uid = allUnits[i]
        if spGetUnitAllyTeam(uid) ~= junoAlly then
            local ux, _, uz = spGetUnitPosition(uid)
            if ux then
                local dx, dz = ux - sx, uz - sz
                if dx * dx + dz * dz <= rangeSq then
                    local cx = math.floor(ux / CLUSTER_CELL)
                    local cz = math.floor(uz / CLUSTER_CELL)
                    local key = cx * 100000 + cz
                    local c = cells[key]
                    if not c then
                        c = { sumX = 0, sumZ = 0, n = 0, key = key }
                        cells[key] = c
                    end
                    c.sumX = c.sumX + ux
                    c.sumZ = c.sumZ + uz
                    c.n = c.n + 1
                end
            end
        end
    end

    local bestFree, bestFreeD2
    local bestAny,  bestAnyD2
    for _, c in pairs(cells) do
        local cxw = c.sumX / c.n
        local czw = c.sumZ / c.n
        local dx, dz = cxw - sx, czw - sz
        local d2 = dx * dx + dz * dz
        if not bestAny or d2 < bestAnyD2 then
            bestAny, bestAnyD2 = c, d2
        end
        local claim = claimedTargets[c.key]
        if (not claim) or claim <= now then
            if not bestFree or d2 < bestFreeD2 then
                bestFree, bestFreeD2 = c, d2
            end
        end
    end

    local chosen = bestFree or bestAny
    if chosen then
        claimedTargets[chosen.key] = now + CLAIM_DURATION
        local tx = (chosen.sumX / chosen.n) + math.random(-64, 64)
        local tz = (chosen.sumZ / chosen.n) + math.random(-64, 64)
        local ty = math.max(spGetGroundHeight(tx, tz), 0)
        return tx, ty, tz
    end

    local list = enemyStarts[junoAlly]
    if not list or #list == 0 then return nil end
    local bestBase, bestBaseD2
    for i = 1, #list do
        local base = list[i]
        local dx, dz = base.x - sx, base.z - sz
        local d2 = dx * dx + dz * dz
        if d2 <= rangeSq and (not bestBase or d2 < bestBaseD2) then
            bestBase, bestBaseD2 = base, d2
        end
    end
    if not bestBase then return nil end
    claimedTargets[bestBase.teamID] = now + CLAIM_DURATION
    local tx = bestBase.x + math.random(-256, 256)
    local tz = bestBase.z + math.random(-256, 256)
    local ty = math.max(spGetGroundHeight(tx, tz), 0)
    return tx, ty, tz
end

function gadget:GameFrame(frame)
    if frame % 900 == 0 then
        refreshAITeams()
        refreshEnemyStarts()
    end
    if frame % 30 ~= 7 then return end

    local now = spGetGameSeconds()
    purgeClaims(now)
    for junoID, nextFire in pairs(trackedJunos) do
        if nextFire <= now then
            local numStockpiled, numQueued = spGetUnitStockpile(junoID)
            if numQueued and numQueued < 3 then
                queueStockpile(junoID)
            end

            if numStockpiled and numStockpiled > 0 then
                local tx, ty, tz = pickClosestEnemyTarget(junoID, now)
                if tx then
                    spGiveOrderToUnit(junoID, CMD_ATTACK, { tx, ty, tz }, 0)
                    trackedJunos[junoID] = now + math.random(15, 45)
                else
                    trackedJunos[junoID] = now + 10 -- no enemy base in range
                end
            else
                trackedJunos[junoID] = now + 8
            end
        end
    end
end
