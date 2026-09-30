---
--- The battle log: every message shown to the player, kept as I18N keys and data so
--- LuaUI can render it in any language.
---

local COUNT_PARAM = "missionBattleLogCount"
local ENTRY_PARAM_PREFIX = "missionBattleLog_"

local MessageTypes = {
	Briefing = "Briefing",
	Message = "Message",
	Objective = "Objective",
	Notification = "Notification",
	Dialogue = "Dialogue",
}

---One message, as it is held in GG['MissionAPI'].BattleLogRaw.
---@class MissionBattleLogEntry
---@field messageType string one of MessageTypes
---@field messageKey string I18N key
---@field messageData table? I18N interpolation values

-- Each entry is published as its own game rules param, so LuaUI reads the log
-- back after a reload and picks up new entries from the count.
local function addMessage(messageType, messageKey, messageData)
	local log = GG["MissionAPI"].BattleLogRaw
	local entry = { messageType = messageType, messageKey = messageKey, messageData = messageData }
	log[#log + 1] = entry

	Spring.SetGameRulesParam(ENTRY_PARAM_PREFIX .. #log, Json.encode(entry))
	Spring.SetGameRulesParam(COUNT_PARAM, #log)

	Spring.Echo(messageKey) -- placeholder until a widget displays the log
end

return {
	MessageTypes = MessageTypes,
	AddMessage = addMessage,
}
