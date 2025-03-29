
local gadget = gadget ---@type Gadget

function gadget:GetInfo()
  return {
    name      = "Stats",
    desc      = "Collect stats, send to LuaUI on GameOver",
    author    = "Bluestone",
    date      = "",
    license   = "GNU GPL, v2 or later",
    layer     = -999990,
    enabled   = true,
  }
end

if gadgetHandler:IsSyncedCode() then
    return
end

local unitMetalCost = {}
local unitEnergyCost = {}
for unitDefID, defs in pairs(UnitDefs) do
    unitMetalCost[unitDefID] = defs.metalCost
    unitEnergyCost[unitDefID] = defs.energyCost
end

local info = {}
local gameType

function gadget:Initialize()
    local tList = Spring.GetTeamList()

    if Spring.Utilities.Gametype.IsFFA() then
        gameType = "free for all"
        return
    end

    local nHumanTeams = 0
    local nAITeams = 0
    local nRaptorTeams = 0
    for _,teamID in pairs(tList) do
        local luaAI = Spring.GetTeamLuaAI(teamID) or ''
        local aiRaptor = (luaAI:find("Raptor") ~= nil)
        local aiTeam = select(4,Spring.GetTeamInfo(teamID,false))
        local gaiaTeam = (teamID == Spring.GetGaiaTeamID())
        if aiRaptor then
            nRaptorTeams = nRaptorTeams + 1
        end
        if aiTeam then
            nAITeams = nAITeams + 1
        end
        if not aiTeam and not aiRaptor and not gaiaTeam then
            nHumanTeams = nHumanTeams + 1
        end
    end

    if nRaptorTeams >=1 then
        gameType = "raptor defence"
        return
    end

    if nHumanTeams <= 1 then gameType = "single player" -- and gaia
    elseif nHumanTeams == 2 and nAITeams == 0 then gameType = "1v1"
    else gameType = "team"
    end
end

function gadget:UnitCreated(unitID, unitDefID, teamID, builderID)
    local pList = Spring.GetPlayerList(teamID)
    local playerID = pList[1]
    local customtable = false
    if playerID then
        customtable = select(11,Spring.GetPlayerInfo(playerID)) or {}
    end
    local tsMu = customtable and customtable.skill or ""
    local mu = tsMu and tonumber(tsMu:match("%d+%.?%d*")) or 25

    info[unitDefID] = info[unitDefID] or {dmg_dealt=0,dmg_rec=0,kills=0,killed_cost=0,n=0,ts=0,minutes=0}

    info[unitDefID].n = info[unitDefID].n + 1
    info[unitDefID].ts = info[unitDefID].ts + mu
    info[unitDefID].minutes = info[unitDefID].minutes + Spring.GetGameFrame()/(30*60)
end

function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
    if not attackerDefID then return end
    if not unitDefID then return end
    if not info[attackerDefID] then return end
    if not info[unitDefID] then return end
    if Spring.AreTeamsAllied(unitTeam,attackerTeam) then return end
    local h,_,_ = Spring.GetUnitHealth(unitID)
    if h > damage then damage = h end

    info[attackerDefID].dmg_dealt = info[attackerDefID].dmg_dealt + damage
    info[unitDefID].dmg_rec = info[unitDefID].dmg_rec + damage
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
    if not attackerDefID then return end
    if not unitDefID then return end
    if not info[attackerDefID] then return end
    if not info[unitDefID] then return end
    if unitTeam==attackerTeam then return end

    info[attackerDefID].kills = info[attackerDefID].kills + 1
    info[attackerDefID].killed_cost = info[attackerDefID].killed_cost + unitMetalCost[unitDefID] + unitEnergyCost[unitDefID]/60
end

function gadget:GameOver()
    -- send totals to luaui
    if Script.LuaUI("SendStats") and Script.LuaUI("SendStats_GameMode") then
        Script.LuaUI.SendStats_GameMode(gameType)
        for uDID,t in pairs(info) do
            Script.LuaUI.SendStats(uDID, t.n, t.ts, t.dmg_dealt, t.dmg_rec, t.minutes, t.kills, t.killed_cost)
        end
    end
end
