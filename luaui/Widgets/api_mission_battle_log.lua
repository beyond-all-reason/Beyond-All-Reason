local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Mission Battle Log API",
		desc = "Keeps the Mission API battle log translated, for the widgets that display it",
		date = "September 2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

local spGetGameRulesParam = Spring.GetGameRulesParam

-- Written by luarules/mission_api/battle_log.lua: one JSON entry per param, plus the count.
local COUNT_PARAM = "missionBattleLogCount"
local ENTRY_PARAM_PREFIX = "missionBattleLog_"

---@class MissionBattleLogMessage
---@field messageType string
---@field message string as displayed to the player

---@type MissionBattleLogEntry[]
local battleLogRaw = {}
---@type MissionBattleLogMessage[]
local battleLog = {}

local function translate(entry)
	return { messageType = entry.messageType, message = BAR.I18N(entry.messageKey, entry.messageData) }
end

local function readNewEntries()
	local count = spGetGameRulesParam(COUNT_PARAM) --[[@as integer?]]
	for i = #battleLogRaw + 1, count or 0 do
		local encoded = spGetGameRulesParam(ENTRY_PARAM_PREFIX .. i) --[[@as string]]
		local entry = Json.decode(encoded) --[[@as MissionBattleLogEntry]]
		battleLogRaw[i] = entry
		battleLog[i] = translate(entry)
	end
end

---Oldest first; display it in reverse to show the newest message on top.
local function getMessages()
	return battleLog
end

function widget:Initialize()
	WG.missionBattleLog = { GetMessages = getMessages }
	readNewEntries()
end

function widget:Shutdown()
	WG.missionBattleLog = nil
end

function widget:GameFrame()
	readNewEntries()
end

function widget:LanguageChanged()
	for i = 1, #battleLogRaw do
		battleLog[i] = translate(battleLogRaw[i])
	end
end
