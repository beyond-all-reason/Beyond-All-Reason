function gadget:GetInfo()
  return {
    name      = "Substitution",
    desc      = "Allows players absent at gamestart to be replaced by specs",
    author    = "Bluestone",
    date      = "June 2014",
    license   = "GNU GPL, v3 or later",
    layer     = 1, --run after game_intial_spawn 
    enabled   = true  
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if (tonumber(Spring.GetModOptions().mo_noowner) or 0) == 1 then
	gadgetHandler:RemoveGadget() -- don't run in FFA mode
end

-----------------------------
if gadgetHandler:IsSyncedCode() then 
-----------------------------

local tsRegex = '^\144(%d+)$'
local substitutes = {}
local players = {}
local absent = {}
local replaced = false

local gaiaTeamID = Spring.GetGaiaTeamID()

function gadget:RecvLuaMsg(msg, playerID)
	local ts = tonumber(msg:match(tsRegex))
    if ts~=nil then
        substitutes[playerID] = ts
        Spring.Echo("recieved", playerID, ts)
    end
end

function gadget:Initialize()
    -- record a list of which playersIDs are players on which teamID
    local allyTeamList = Spring.GetAllyTeamList()
    for _,allyTeamID in pairs(allyTeamList) do
        local teamList = Spring.GetTeamList(allyTeamID)
        for _,teamID in pairs(teamList) do
        if teamID~=gaiaTeamID then
            local playerList = Spring.GetPlayerList(teamID)
            for _,playerID in pairs(playerList) do
                local _,_,spec = Spring.GetPlayerInfo(playerID)
                if not spec then
                    players[playerID] = teamID
                end
            end
        end
        end
    end
end


function gadget:GameStart()
    -- make a list of absent players (only ones with valid ts)
    for playerID,_ in pairs(players) do
        local _,active,spec = Spring.GetPlayerInfo(playerID)
        local present = active and not spec
        if not present then
            local customtable = select(10,Spring.GetPlayerInfo(playerID)) -- player custom table
            local tsMu = customtable.skill
            ts = 25 --tsMu and tonumber(tsMu:match("%d+%.?%d*")) 
            if ts then
                absent[playerID] = ts
                --Spring.Echo("absent:", playerID, ts)
            end
        end
    end
    
    -- for each one, try and find a suitable replacement & substitute if so
    for playerID,ts in pairs(absent) do
        local validSubs = {}
        for subID,subts in pairs(substitutes) do
            local _,active,spec = Spring.GetPlayerInfo(subID)
            if active and spec and math.abs(ts-subts)<=4.5 then 
                validSubs[#validSubs+1] = subID
            end
        end
        if #validSubs>0 then
            local sID = validSubs[math.random(1,#validSubs)]
            local teamID = players[playerID]
            Spring.AssignPlayerToTeam(sID, teamID)
            substitutes[sID] = nil
            replaced = true
            
            local incoming,_ = Spring.GetPlayerInfo(sID)
            local outgoing,_ = Spring.GetPlayerInfo(playerID)            
            Spring.Echo("Player " .. playerID .. " (" .. outgoing .. ") was replaced with Player " .. sID .. " (" .. incoming .. ")")
        end
    end

    if replaced then
        Spring.Echo("Revealing start positions to all")
    end
end

function gadget:GameFrame(n)
    if n~=1 then return end

   -- if at least one player was replaced, reveal startpoints to all
    if replaced then
        local coopStartPoints = GG.coopStartPoints or {}
        local revealed = {}
        for pID,p in pairs(coopStartPoints) do
            local name,_ = Spring.GetPlayerInfo(pID)
            Spring.MarkerAddPoint(p[1], p[2], p[3], name, true)
            revealed[pID] = true
        end
        
        local teamStartPoints = GG.teamStartPoints or {}
        for tID,p in pairs(teamStartPoints) do
            p = teamStartPoints[tID]
            local playerList = Spring.GetPlayerList(tID)
            local name = ""
            for _,pID in pairs(playerList) do --get all pIDs for this team which were not coop starts
                if not revealed[pID] then
                    local pName,_ = Spring.GetPlayerInfo(pID) 
                    if pName and absent[pID]==nil then -- AIs might not have a name, don't write the name of the dropped player
                        name = name .. pName .. ", "
                        revealed[pID] = true
                    end
                end
            end
            name = string.sub(name, 1, math.max(string.len(name)-2,1)) --remove final ", "
            Spring.MarkerAddPoint(p[1], p[2], p[3], name, true)
        end
    end

    gadgetHandler:RemoveGadget()
end

-----------------------------
else -- begin unsynced section
-----------------------------

local x = 500
local y = 500

local myPlayerID = Spring.GetMyPlayerID()
local amISpec = Spring.GetSpectatingState()

local customtable = select(10,Spring.GetPlayerInfo(myPlayerID)) -- player custom table
local tsMu = customtable.skill 
local tsSigma = customtable.skilluncertainty
ts = tsMu and tonumber(tsMu:match("%d+%.?%d*"))
tsSigma = tonumber(tsSigma)
local eligible = tsMu and tsSigma and (tsSigma<=2) and (not string.find(tsMu, ")")) 

function gadget:DrawScreen()
    -- ask each spectator if they would like to replace an absent player

end

--function gadget:MousePress(mx,my)
local temp 
function gadget:DrawScreen()
    if not temp then -- tell luarules that user offered to be a substitute
        ts = 25
        Spring.Echo("sent", myPlayerID, ts)
        Spring.SendLuaRulesMsg('\144' .. tostring(ts))
        temp = true
    end
end



-----------------------------
end -- end unsynced section
-----------------------------
