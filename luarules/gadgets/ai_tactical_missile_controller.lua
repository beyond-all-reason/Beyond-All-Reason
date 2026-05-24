function gadget:GetInfo()
    return {
        name      = "AI Tactical Missile Controller",
        desc      = "Auto-stockpiles and fires armemp / cortron / legperdition for AI teams",
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
local spGetUnitTeam          = Spring.GetUnitTeam
local spGetUnitPosition      = Spring.GetUnitPosition
local spGetUnitStockpile     = Spring.GetUnitStockpile
local spGetUnitAllyTeam      = Spring.GetUnitAllyTeam
local spGetAllUnits          = Spring.GetAllUnits
local spGetGroundHeight      = Spring.GetGroundHeight
local spGiveOrderToUnit      = Spring.GiveOrderToUnit
local spGetGameSeconds       = Spring.GetGameSeconds
local spEcho                 = Spring.Echo

local CMD_STOCKPILE  = CMD.STOCKPILE
local CMD_ATTACK     = CMD.ATTACK
local CMD_INSERT     = CMD.INSERT
local CMD_FIRE_STATE = CMD.FIRE_STATE
local FIRESTATE_FIREATWILL = 2
local INSERT_AT_FRONT = { "alt" }

local SILO_NAMES = {
    armemp       = true, -- Arm EMP missile
    cortron      = true, -- Cor tactical nuke
    legperdition = true, -- Leg tactical missile
}

local MAX_RANGE = 3600
local SAFETY_BUFFER = 200 -- extra elmo beyond the missile's blast radius

local siloDefIDs = {}
local siloDefRange = {}
local siloDefMinRange = {} -- closest distance the silo may safely fire at

local function buildSiloDefTables()
    for name in pairs(SILO_NAMES) do
        local def = UnitDefNames and UnitDefNames[name]
        if def then
            siloDefIDs[def.id] = true
            local r = 0
            local aoe = 0
            if def.weapons then
                for i = 1, #def.weapons do
                    local w = def.weapons[i]
                    local wdid = w and w.weaponDef
                    local wdef = wdid and WeaponDefs and WeaponDefs[wdid]
                    if wdef then
                        local wr = tonumber(wdef.range) or 0
                        if wr > r then r = wr end
                        local a = tonumber(wdef.damageAreaOfEffect)
                                or tonumber(wdef.areaOfEffect) or 0
                        if a > aoe then aoe = a end
                    end
                end
            end
            if r <= 0 then r = MAX_RANGE end
            if r > MAX_RANGE then r = MAX_RANGE end
            siloDefRange[def.id] = r
            local minR = aoe + SAFETY_BUFFER + 128
            if minR < 400 then minR = 400 end
            if minR > r - 64 then minR = r - 64 end
            siloDefMinRange[def.id] = minR
        end
    end
end

local ok, err = pcall(buildSiloDefTables)
if not ok then
    Spring.Echo("[AI TacMissile] WARNING: silo def scan failed: " .. tostring(err))
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

local trackedSilos = {}

local function isAITeam(teamID)
    return aiTeams[teamID] == true
end

local function queueStockpile(unitID)
    for _ = 1, 5 do
        spGiveOrderToUnit(unitID, CMD_STOCKPILE, {}, 0)
    end
end

local function setFireAtWill(unitID)
    spGiveOrderToUnit(unitID, CMD_FIRE_STATE, { FIRESTATE_FIREATWILL }, 0)
end

local function setupSilo(unitID)
    setFireAtWill(unitID)
    queueStockpile(unitID)
end

local function forceAttack(unitID, tx, ty, tz)
    spGiveOrderToUnit(unitID, CMD_INSERT, { 0, CMD_ATTACK, 0, tx, ty, tz }, INSERT_AT_FRONT)
end

function gadget:Initialize()
    refreshAITeams()
    spEcho("[AI TacMissile] Initialized; AI teams detected: " ..
        (next(aiTeams) and "yes" or "no"))

    for _, unitID in ipairs(spGetAllUnits()) do
        local defID = Spring.GetUnitDefID(unitID)
        if defID and siloDefIDs[defID] then
            local teamID = spGetUnitTeam(unitID)
            if isAITeam(teamID) then
                trackedSilos[unitID] = spGetGameSeconds() + math.random(10, 30)
                setupSilo(unitID)
            end
        end
    end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
    if siloDefIDs[unitDefID] and isAITeam(unitTeam) then
        trackedSilos[unitID] = spGetGameSeconds() + math.random(10, 30)
        setupSilo(unitID)
    end
end

function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
    if siloDefIDs[unitDefID] and isAITeam(newTeam) then
        trackedSilos[unitID] = spGetGameSeconds() + math.random(10, 30)
        setupSilo(unitID)
    elseif trackedSilos[unitID] and not isAITeam(newTeam) then
        trackedSilos[unitID] = nil
    end
end

function gadget:UnitDestroyed(unitID)
    trackedSilos[unitID] = nil
end

function gadget:TeamDied(teamID)
    aiTeams[teamID] = nil
end

local CLUSTER_CELL = 256         -- elmo per grid cell (~ tac missile blast)
local MIN_CLUSTER_SIZE = 2       -- require at least this many units in a cell
local TOP_PICKS = 3              -- pick randomly among top-N densest cells

local function pickEnemyTarget(siloID)
    local siloAlly = spGetUnitAllyTeam(siloID)
    local sx, _, sz = spGetUnitPosition(siloID)
    if not sx then return nil end

    local defID = Spring.GetUnitDefID(siloID)
    local range = siloDefRange[defID] or MAX_RANGE
    if range > MAX_RANGE then range = MAX_RANGE end
    local rangeSq = range * range
    local minRange = siloDefMinRange[defID] or 400
    local minRangeSq = minRange * minRange

    local all = spGetAllUnits()

    local cells = {}     -- key -> { count, sumX, sumZ }
    local enemyList = {} -- fallback list (in-range only)
    local enemyInRange = false

    for i = 1, #all do
        local uid = all[i]
        if spGetUnitAllyTeam(uid) ~= siloAlly then
            local x, _, z = spGetUnitPosition(uid)
            if x and z then
                local dx, dz = x - sx, z - sz
                local d2 = dx * dx + dz * dz
                if d2 >= minRangeSq and d2 <= rangeSq then
                    enemyInRange = true
                    enemyList[#enemyList + 1] = uid
                    local cx = math.floor(x / CLUSTER_CELL)
                    local cz = math.floor(z / CLUSTER_CELL)
                    local key = cx * 10000 + cz
                    local c = cells[key]
                    if c then
                        c[1] = c[1] + 1
                        c[2] = c[2] + x
                        c[3] = c[3] + z
                    else
                        cells[key] = { 1, x, z }
                    end
                end
            end
        end
    end

    if not enemyInRange then return nil end

    local ranked = {}
    for _, c in pairs(cells) do
        if c[1] >= MIN_CLUSTER_SIZE then
            ranked[#ranked + 1] = c
        end
    end

    local function clampToSafeRange(x, z)
        local dx, dz = x - sx, z - sz
        local d2 = dx * dx + dz * dz
        if d2 > rangeSq and d2 > 0 then
            local d = math.sqrt(d2)
            local scale = (range - 16) / d
            x = sx + dx * scale
            z = sz + dz * scale
        elseif d2 < minRangeSq and d2 > 0 then
            local d = math.sqrt(d2)
            local scale = (minRange + 16) / d
            x = sx + dx * scale
            z = sz + dz * scale
        end
        return x, z
    end

    if #ranked > 0 then
        table.sort(ranked, function(a, b) return a[1] > b[1] end)
        local pickIdx = math.random(1, math.min(TOP_PICKS, #ranked))
        local c = ranked[pickIdx]
        local x = c[2] / c[1]
        local z = c[3] / c[1]
        x = x + math.random(-64, 64)
        z = z + math.random(-64, 64)
        x, z = clampToSafeRange(x, z)
        local dx, dz = x - sx, z - sz
        if dx * dx + dz * dz < minRangeSq then return nil end
        local y = math.max(spGetGroundHeight(x, z), 0)
        return x, y, z
    end

    if #enemyList > 0 then
        local uid = enemyList[math.random(1, #enemyList)]
        local x, _, z = spGetUnitPosition(uid)
        if x and z then
            x = x + math.random(-128, 128)
            z = z + math.random(-128, 128)
            x, z = clampToSafeRange(x, z)
            local dx, dz = x - sx, z - sz
            if dx * dx + dz * dz < minRangeSq then return nil end
            local y = math.max(spGetGroundHeight(x, z), 0)
            return x, y, z
        end
    end
    return nil
end

function gadget:GameFrame(frame)
    if frame % 900 == 0 then
        refreshAITeams()
    end

    if frame % 30 ~= 11 then return end

    local now = spGetGameSeconds()
    for siloID, nextFire in pairs(trackedSilos) do
        if nextFire <= now then
            local numStockpiled, numQueued = spGetUnitStockpile(siloID)
            numStockpiled = numStockpiled or 0
            numQueued     = numQueued     or 0
            if numQueued < 3 then
                queueStockpile(siloID)
            end

            if numStockpiled > 0 then
                local tx, ty, tz = pickEnemyTarget(siloID)
                if tx then
                    setFireAtWill(siloID)
                    forceAttack(siloID, tx, ty, tz)
                    trackedSilos[siloID] = now + math.random(20, 60)
                else
                    trackedSilos[siloID] = now + 15
                end
            else
                trackedSilos[siloID] = now + 10
            end
        end
    end
end
