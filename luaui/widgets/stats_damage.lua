function widget:GetInfo()
	return {
	name      = "Statistics Collection", 
	desc      = "Receive unit stats and write to file in /luaui/config \nIf your experiment needs statistics, you should have done a better experiment",
	author    = "Bluestone",
	date      = "", 
	license   = "GNU GPL, v3 or later",
	layer     = 0,
	enabled   = true,
	}
end

--[[
This writes a file in /luaui/config for every user, containing statistics on which units were built, and various other stats,
summarizing all (complete, non-replay) games seen by the user, of the most recent game version.

The statistics are stored as a lua table which can be loaded in the normal way (see widget part). the format of the stats 
table is self-explanatory: stats[game][mode][unitName] = { various statistics }. All statistics are mean averages, except for 'n', 
which is the number of samples of the given unit.
]]

local info
local writeInfo = false
local STATS_FILE = 'LuaUI/Config/BA_damageStats.lua'

local game = Game.gameShortName .. " " .. Game.gameVersion

local chunk, err = loadfile(STATS_FILE)
if chunk then
    local tmp = {}
    setfenv(chunk, tmp)
    stats = chunk()    
end

function widget:GameStart()
	widgetHandler:RegisterGlobal('SendStats', RecieveStats)
	widgetHandler:RegisterGlobal('SendStats_GameMode', RecieveGameMode)    
end

function RecieveGameMode(mode)
    mode = mode or "unknown"
    
    stats = stats or {}
    stats[game] = stats[game] or {}
    stats[game].versionNumber = Game.gameVersion ~= "$VERSION" and string.sub(Game.gameVersion,2)
    
    -- remove any versions that are not the current max version
    local max_version = -1
    for k,_ in pairs(stats) do
        if tonumber(stats[k].versionNumber) then
            max_version = math.max(max_version, tonumber(stats[k].versionNumber))
        end
    end
    for k,_ in pairs(stats) do
        if (not stats[k].versionNumber) or (not tonumber(stats[k].versionNumber)) or (tonumber(stats[k].versionNumber) < max_version) then
            stats[k] = nil
        end
    end

    stats[game] = stats[game] or {}
    stats[game][mode] = stats[game][mode] or {}
    
    info = stats[game][mode]
    info.games = info.games or 0
end

function RecieveStats(uDID, n, ts, dmg_dealt, dmg_rec, minutes, kills, killed_cost)
    if not info then return end
    local name = UnitDefs[uDID].name
    if not name then return end

    local cost = UnitDefs[uDID].metalCost + UnitDefs[uDID].energyCost / 60
    info[name] = info[name] or {dmg_dealt=0,dmg_rec=0,n=0,ts=0,name=UnitDefs[uDID].humanName,minutes=0,kills=0,killed_cost=0, cost=cost}

    local old_n = info[name].n 
    info[name].ts = (info[name].ts * old_n + ts)/(old_n+n)
    info[name].dmg_dealt = (info[name].dmg_dealt * old_n + dmg_dealt)/(old_n+n)
    info[name].dmg_rec = (info[name].dmg_rec * old_n + dmg_rec)/(old_n+n)
    info[name].minutes = (info[name].minutes * old_n + minutes)/(old_n+n)
    info[name].kills = (info[name].kills * old_n + kills)/(old_n+n)
    info[name].killed_cost = (info[name].killed_cost * old_n + killed_cost)/(old_n+n)
   
    info[name].n = info[name].n + n
end

function widget:GameOver()
    if not info or Spring.IsReplay() then return end
    info.games = info.games + 1
    table.save(stats, STATS_FILE, '-- ' .. Game.gameName .. ' Damage Stats')
end

function widget:Shutdown()
    widgetHandler:DeregisterGlobal('SendStats')
    widgetHandler:DeregisterGlobal('SendStats_GameMode')
end

