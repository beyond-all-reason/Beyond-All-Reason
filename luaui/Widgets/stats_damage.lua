local widget = widget ---@type Widget

function widget:GetInfo()
	return {
	name      = "Statistics Collection",
	desc      = "Receive unit stats and write to file in /luaui/config \nIf your experiment needs statistics, you should have done a better experiment",
	author    = "Bluestone",
	date      = "",
	license   = "GNU GPL, v2 or later",
	layer     = 0,
	enabled   = true,
	}
end

--[[
This writes a file in /luaui/config for every user, containing statistics on which units were built, and various other stats,
summarizing all (non-aborted, non-replay, non-$VERSION) games seen by the user, since they last deleted the stats file.

The statistics are stored as a lua table which can be loaded in the normal way, see below.
The format of the stats table is self-explanatory:
    stats[game][mode][unitName] = { various statistics }.
All statistics are mean averages, except for 'n', which is the number of samples of the given unit.
]]

local info
local STATS_FILE = 'LuaUI/Config/BAR_damageStats.lua'
local INTERNAL_VERSION = 1 -- bump to reset stats file (user can delete file with same effect)

local game = Game.gameName
local version = Game.gameVersion

local unitName = {}
local unitMetalCost = {}
local unitEnergyCost = {}
local unitHumanName = {}
for unitDefID, unitDef in pairs(UnitDefs) do
    unitName[unitDefID] = unitDef.name
    unitMetalCost[unitDefID] = unitDef.metalCost
    unitEnergyCost[unitDefID] = unitDef.energyCost
    unitHumanName[unitDefID] = unitDef.translatedHumanName
end

local chunk, err = loadfile(STATS_FILE)
if chunk then
    local tmp = {}
    setfenv(chunk, tmp)
    stats = chunk()
end


function widget:Initialize()
	widgetHandler:RegisterGlobal('SendStats', RecieveStats)
	widgetHandler:RegisterGlobal('SendStats_GameMode', RecieveGameMode)
end

function RecieveGameMode(mode)
    mode = mode or "unknown"

    stats = stats or {}
    if not stats.internal_version or stats.internal_version < INTERNAL_VERSION then stats = {} end
    stats.internal_version = INTERNAL_VERSION

    stats[game] = stats[game] or {}
    stats[game][mode] = stats[game][mode] or {}

    info = stats[game][mode]
    info.games = info.games or 0
    info.games = info.games + 1

    info["_games_per_version"] = info["_games_per_version"] or {}
    info["_games_per_version"][version] = info["_games_per_version"][version] or 0
    info["_games_per_version"][version] = info["_games_per_version"][version] + 1
end

function RecieveStats(uDID, n, ts, dmg_dealt, dmg_rec, minutes, kills, killed_cost)
    if not info then return end
    local name = unitName[uDID]
    if not name then return end

    local cost = unitMetalCost[uDID] + unitEnergyCost[uDID] / 60
    info[name] = info[name] or {dmg_dealt=0,dmg_rec=0,n=0,ts=0,name=unitHumanName[uDID],minutes=0,kills=0,killed_cost=0, cost=cost}

    local old_n = info[name].n
    info[name].ts = ((info[name].ts or 0) * old_n + ts)/(old_n+n)
    info[name].dmg_dealt = ((info[name].dmg_dealt or 0) * old_n + dmg_dealt)/(old_n+n)
    info[name].dmg_rec = ((info[name].dmg_rec or 0) * old_n + dmg_rec)/(old_n+n)
    info[name].minutes = ((info[name].minutes or 0) * old_n + minutes)/(old_n+n)
    info[name].kills = ((info[name].kills or 0) * old_n + kills)/(old_n+n)
    info[name].killed_cost = ((info[name].killed_cost or 0) * old_n + killed_cost)/(old_n+n)

    info[name].n = info[name].n + n
end

function widget:GameOver()
    if not info or Spring.IsReplay() then return end
    if Spring.Utilities.IsDevMode() then return end

    table.save(stats, STATS_FILE, '-- Damage Stats')
end

function widget:Shutdown()
    widgetHandler:DeregisterGlobal('SendStats')
    widgetHandler:DeregisterGlobal('SendStats_GameMode')
end
