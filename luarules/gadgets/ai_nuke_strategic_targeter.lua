function gadget:GetInfo()
    return {
        name      = "AI Nuke Strategic Targeter",
        desc      = "AI nuke silos auto-stockpile and fire at enemy starting bases and heavy defensive clusters",
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
local spGetTeamInfo          = Spring.GetTeamInfo
local spGetTeamStartPosition = Spring.GetTeamStartPosition
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

local CMD_STOCKPILE   = CMD.STOCKPILE
local CMD_ATTACK      = CMD.ATTACK
local CMD_FIRE_STATE  = CMD.FIRE_STATE
local CMD_INSERT      = CMD.INSERT
local FIRESTATE_HOLD  = 0
local INSERT_AT_FRONT = { "alt" }

local SILO_NAMES = {
    armsilo = true,
    corsilo = true,
    legsilo = true,
}

local siloDefIDs = {}
local siloDefRange = {}
for name in pairs(SILO_NAMES) do
    local def = UnitDefNames[name]
    if def then
        siloDefIDs[def.id] = true
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
        if r <= 0 then r = 96000 end
        siloDefRange[def.id] = r
    else
        spEcho("[AI NukeTargeter] WARNING: UnitDef not found: " .. name)
    end
end

local defenseScore = {}
local heavyDefenseDefID = {}

local HEAVY_DEFENSE_PATTERNS = {
    "anni",      -- Annihilator
    "toast",     -- Pulverizer
    "pulver",
    "brtha", "bertha",
    "vulc", "ragnarok", "buzz", "buzzsaw",
    "calam",     -- Calamity
    "intim",     -- Intimidator
    "lrpc",
    "doom",      -- Doomsday
    "bhmth", "behem",
    "viper", "vipe",
    "emp",       -- EMP launcher (Arm), Tactical Missile launcher names sometimes
    "tron",      -- Tactical Missile Launcher (cortron)
    "perdition", -- Legion tac missile
    "mercury", "screamer", -- T3 AA strategic
    "guard",     -- Punisher (armguard)
    "bombard",
    "rail",
    "starfall",
    "bastion",
    "amd", "antinuke", -- antinuke (worth nuking out)
    "silo",      -- enemy nuke silo (counter-nuke priority)
}

local function isHeavyDefenseName(n)
    for i = 1, #HEAVY_DEFENSE_PATTERNS do
        if n:find(HEAVY_DEFENSE_PATTERNS[i], 1, true) then return true end
    end
    return false
end

for defID, def in pairs(UnitDefs) do
    if def and not def.canMove and not def.canFly then
        local hasWeapon = def.weapons and #def.weapons > 0
        local metal = def.metalCost or 0
        local n = def.name or ""
        local nameHeavy = isHeavyDefenseName(n)
        local isHeavy = hasWeapon and (nameHeavy or metal >= 1200)
        if hasWeapon and (metal >= 600 or isHeavy) then
            local score = math.floor(metal / 100)
            if n:find("lrpc") or n:find("calamity") or n:find("intimidator")
                or n:find("vulcan") or n:find("ragnarok") or n:find("buzzsaw")
                or n:find("antinuke") or n:find("amd")
                or n:find("antiv") or n:find("emp") or n:find("scep")
                or n:find("silo") or n:find("nuke") then
                score = score + 50
            end
            if isHeavy then
                score = score + 200
                heavyDefenseDefID[defID] = true
            end
            defenseScore[defID] = score
        elseif hasWeapon and metal >= 250 then
            -- regular T2 turrets etc.
            defenseScore[defID] = 2
        end
    end
end

-- Tunables
local MIN_CLUSTER_SCORE  = 8         -- minimum summed defense score in a cell to qualify
local CLUSTER_CELL       = 384       -- elmo grid cell size
local STARTPOS_RADIUS    = 1200      -- enemies within this distance of a start pos count as "still at base"
local STARTPOS_MIN_UNITS = 4         -- need at least this many enemy units near the start pos
local FIRE_INTERVAL_MIN  = 30        -- seconds between shots per silo (min)
local FIRE_INTERVAL_MAX  = 75        -- seconds between shots per silo (max)
local STOCKPILE_TARGET   = 5         -- queue up to N rockets when empty
local STOCKPILE_REFILL_AT= 2         -- top off when stockpile drops to this

local TEAM_REFRESH_INTERVAL = 30 * 30 -- frames

local aiTeams = {}
local enemyStartPositions = {} -- ally-team-id -> list of {x,z,teamID} for non-allied teams
local trackedSilos = {} -- unitID -> nextFireSecond

local function refreshAITeams()
    aiTeams = {}
    for _, teamID in ipairs(spGetTeamList()) do
        local _, _, _, isAiTeam, _, _, _, _ = spGetTeamInfo(teamID, false)
        if isAiTeam then
            aiTeams[teamID] = true
        end
    end
end

local function refreshStartPositions()
    enemyStartPositions = {}
    local allTeams = spGetTeamList()
    for _, observerTeam in ipairs(allTeams) do
        local _, _, _, _, _, observerAlly = spGetTeamInfo(observerTeam, false)
        local list = {}
        for _, otherTeam in ipairs(allTeams) do
            if otherTeam ~= observerTeam then
                local _, _, _, _, _, otherAlly = spGetTeamInfo(otherTeam, false)
                if otherAlly ~= observerAlly then
                    local sx, sy, sz = spGetTeamStartPosition(otherTeam)
                    if sx and sz and sx > 0 and sz > 0 then
                        list[#list + 1] = { x = sx, z = sz, teamID = otherTeam }
                    end
                end
            end
        end
        enemyStartPositions[observerTeam] = list
    end
end

local function clampToRange(siloX, siloZ, tx, tz, range)
    local dx, dz = tx - siloX, tz - siloZ
    local d2 = dx * dx + dz * dz
    if d2 <= range * range then
        return tx, tz
    end
    local d = math.sqrt(d2)
    local s = (range - 32) / d
    return siloX + dx * s, siloZ + dz * s
end

local function pickStrategicTarget(siloID)
    local siloTeam = spGetUnitTeam(siloID)
    local siloAlly = spGetUnitAllyTeam(siloID)
    local sx, _, sz = spGetUnitPosition(siloID)
    if not sx then return nil end
    local range = siloDefRange[spGetUnitDefID(siloID)] or 96000
    local r2 = range * range

    local allUnits = spGetAllUnits()
    local enemies = {}
    for i = 1, #allUnits do
        local uID = allUnits[i]
        if spGetUnitAllyTeam(uID) ~= siloAlly then
            enemies[#enemies + 1] = uID
        end
    end

    do
        local bestHV, bestHVD2
        for j = 1, #enemies do
            local uID = enemies[j]
            local udID = spGetUnitDefID(uID)
            if udID and heavyDefenseDefID[udID] then
                local ux, _, uz = spGetUnitPosition(uID)
                if ux then
                    local dx, dz = ux - sx, uz - sz
                    local d2 = dx * dx + dz * dz
                    if d2 <= r2 and (not bestHV or d2 < bestHVD2) then
                        bestHV, bestHVD2 = { x = ux, z = uz, defID = udID }, d2
                    end
                end
            end
        end
        if bestHV then
            local defName = (UnitDefs[bestHV.defID] and UnitDefs[bestHV.defID].name) or "?"
            return bestHV.x, bestHV.z, "heavydef(" .. defName .. ")"
        end
    end

    local cells = {}
    local bestKey, bestScore, bestCX, bestCZ = nil, 0, nil, nil
    for j = 1, #enemies do
        local uID = enemies[j]
        local udID = spGetUnitDefID(uID)
        local score = udID and defenseScore[udID]
        if score then
            local ux, _, uz = spGetUnitPosition(uID)
            if ux then
                local dx, dz = ux - sx, uz - sz
                if dx * dx + dz * dz <= r2 then
                    local cx = math.floor(ux / CLUSTER_CELL)
                    local cz = math.floor(uz / CLUSTER_CELL)
                    local key = cx * 100000 + cz
                    local c = cells[key]
                    if not c then
                        c = { score = 0, sx = 0, sz = 0, n = 0 }
                        cells[key] = c
                    end
                    c.score = c.score + score
                    c.sx = c.sx + ux
                    c.sz = c.sz + uz
                    c.n = c.n + 1
                    if c.score > bestScore then
                        bestScore = c.score
                        bestKey = key
                    end
                end
            end
        end
    end
    if bestKey and bestScore >= MIN_CLUSTER_SCORE then
        local c = cells[bestKey]
        local tx, tz = c.sx / c.n, c.sz / c.n
        tx, tz = clampToRange(sx, sz, tx, tz, range)
        return tx, tz, "defcluster(score=" .. bestScore .. ",n=" .. c.n .. ")"
    end

    for j = 1, #enemies do
        local udID = spGetUnitDefID(enemies[j])
        if udID and heavyDefenseDefID[udID] then
            return nil
        end
    end

    local startList = enemyStartPositions[siloTeam] or {}
    local bestStart, bestStartCount = nil, 0
    for i = 1, #startList do
        local sp = startList[i]
        local dx, dz = sp.x - sx, sp.z - sz
        if dx * dx + dz * dz <= r2 then
            local count = 0
            local r2sp = STARTPOS_RADIUS * STARTPOS_RADIUS
            for j = 1, #enemies do
                local uID = enemies[j]
                local udID = spGetUnitDefID(uID)
                local def = udID and UnitDefs[udID]
                if def and not def.isBuilder
                    and (def.metalCost or 0) >= 150 then
                    local ux, _, uz = spGetUnitPosition(uID)
                    if ux then
                        local ex, ez = ux - sp.x, uz - sp.z
                        if ex * ex + ez * ez <= r2sp then
                            count = count + 1
                        end
                    end
                end
            end
            if count >= STARTPOS_MIN_UNITS and count > bestStartCount then
                bestStartCount = count
                bestStart = sp
            end
        end
    end
    if bestStart then
        return bestStart.x, bestStart.z, "startbase(team=" .. bestStart.teamID .. ",units=" .. bestStartCount .. ")"
    end

    return nil
end

local gadgetIssuing = false

local function gadgetGive(unitID, cmdID, params, opts)
    gadgetIssuing = true
    spGiveOrderToUnit(unitID, cmdID, params, opts)
    gadgetIssuing = false
end

local function queueStockpile(unitID, n)
    for _ = 1, n do
        gadgetGive(unitID, CMD_STOCKPILE, {}, 0)
    end
end

local function setHoldFire(unitID)
    gadgetGive(unitID, CMD_FIRE_STATE, { FIRESTATE_HOLD }, 0)
end
local function setupSilo(unitID)
    setHoldFire(unitID)
    queueStockpile(unitID, STOCKPILE_TARGET)
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOpts, playerID, fromSynced, fromLua)
    if not siloDefIDs[unitDefID] then return true end
    if gadgetIssuing then return true end
    if not aiTeams[teamID] then return true end

    if cmdID == CMD_ATTACK or cmdID == CMD_FIRE_STATE then
        return false
    end
    if cmdID == CMD_INSERT and cmdParams and cmdParams[2] then
        local inserted = cmdParams[2]
        if inserted == CMD_ATTACK or inserted == CMD_FIRE_STATE then
            return false
        end
    end
    return true
end

function gadget:Initialize()
    refreshAITeams()
    refreshStartPositions()
    spEcho("[AI NukeTargeter] Initialized")
    for _, unitID in ipairs(spGetAllUnits()) do
        local defID = spGetUnitDefID(unitID)
        if defID and siloDefIDs[defID] and aiTeams[spGetUnitTeam(unitID)] then
            trackedSilos[unitID] = spGetGameSeconds() + math.random(20, 60)
            setupSilo(unitID)
        end
    end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
    if siloDefIDs[unitDefID] and aiTeams[unitTeam] then
        trackedSilos[unitID] = spGetGameSeconds() + math.random(20, 60)
        setupSilo(unitID)
    end
end

function gadget:UnitGiven(unitID, unitDefID, newTeam)
    if siloDefIDs[unitDefID] and aiTeams[newTeam] then
        trackedSilos[unitID] = spGetGameSeconds() + math.random(20, 60)
        setupSilo(unitID)
    elseif trackedSilos[unitID] and not aiTeams[newTeam] then
        trackedSilos[unitID] = nil
    end
end

function gadget:UnitDestroyed(unitID)
    trackedSilos[unitID] = nil
end

function gadget:GameFrame(f)
    if f % TEAM_REFRESH_INTERVAL == 0 then
        refreshAITeams()
        refreshStartPositions()
    end

    if f % 30 ~= 13 then return end
    local now = spGetGameSeconds()

    for unitID, nextFire in pairs(trackedSilos) do
        local team = spGetUnitTeam(unitID)
        if team and aiTeams[team] then
            local numQueued, numStored = spGetUnitStockpile(unitID)
            numQueued = numQueued or 0
            numStored = numStored or 0

            if numStored + numQueued <= STOCKPILE_REFILL_AT then
                queueStockpile(unitID, STOCKPILE_TARGET - (numStored + numQueued))
            end

            if numStored > 0 and now >= nextFire then
                local tx, tz, why = pickStrategicTarget(unitID)
                if tx and tz then
                    local ty = spGetGroundHeight(tx, tz) or 0
                    gadgetGive(unitID, CMD_INSERT,
                        { 0, CMD_ATTACK, 0, tx, ty, tz }, INSERT_AT_FRONT)
                    trackedSilos[unitID] = now + math.random(FIRE_INTERVAL_MIN, FIRE_INTERVAL_MAX)
                    spEcho(string.format("[AI NukeTargeter] silo %d -> %s @ (%.0f, %.0f)",
                        unitID, why or "?", tx, tz))
                else
                    -- no good target; recheck soon
                    trackedSilos[unitID] = now + 15
                end
            end
        else
            trackedSilos[unitID] = nil
        end
    end
end
