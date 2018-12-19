
function gadget:GetInfo()
  return {
    name      = "Stats",
    desc      = "Collect stats, send to LuaUI on GameOver",
    author    = "Bluestone",
    date      = "",
    license   = "GNU GPL, v3 or later",
    layer     = -math.huge,
    enabled   = true,
  }
end

if (gadgetHandler:IsSyncedCode()) then
    return
end


local info = {}
local gameType

function gadget:Initialize()
    local tList = Spring.GetTeamList()

    if (tonumber(Spring.GetModOptions().ffa_mode) or 0) == 1 then
        gameType = "free for all"
        return
    end

    local nHumanTeams = 0
    local nAITeams = 0
    local nChickenTeams = 0
    for _,teamID in pairs(tList) do
        local luaAI = Spring.GetTeamLuaAI(teamID) or ''
        local aiChicken = (luaAI:find("Chicken") ~= nil)
        local _,_,_,aiTeam = Spring.GetTeamInfo(teamID)
        local gaiaTeam = (teamID == Spring.GetGaiaTeamID())
        if aiChicken then
            nChickenTeams = nChickenTeams + 1
        end
        if aiTeam then
            nAITeams = nAITeams + 1
        end
        if not aiTeam and not aiChicken and not gaiaTeam then
            nHumanTeams = nHumanTeams + 1
        end
    end
    
    if nChickenTeams >=1 then
        gameType = "chicken defence"
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
    if playerID and select(11,Spring.GetPlayerInfo(playerID)) then
        customtable = select(11,Spring.GetPlayerInfo(playerID))
    end
    local tsMu = customtable and customtable.skill or ""
    mu = tsMu and tonumber(tsMu:match("%d+%.?%d*")) or 25
    
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
    damage = math.max(h,damage)
    
    info[attackerDefID].dmg_dealt = info[attackerDefID].dmg_dealt + damage 
    info[unitDefID].dmg_rec = info[unitDefID].dmg_rec + damage    
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
    if not attackerDefID then return end
    if not unitDefID then return end
    if not info[attackerDefID] then return end
    if not info[unitDefID] then return end
    if unitTeam==attackerTeam then return end
    
    local killed_m = UnitDefs[unitDefID].metalCost
    local killed_e = UnitDefs[unitDefID].energyCost
    info[attackerDefID].kills = info[attackerDefID].kills + 1
    info[attackerDefID].killed_cost = info[attackerDefID].killed_cost + killed_m + killed_e/60
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