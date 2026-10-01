---
--- The battle log: every message shown to the player, kept as I18N keys and data so
--- LuaUI can render it in any language.
---

local SYNC_ACTION = "MissionBattleLogChanged"
local COUNT_PARAM = "missionBattleLogCount"
local ENTRY_PARAM_PREFIX = "missionBattleLog_"

---One message, as it is held in GG['MissionAPI'].BattleLogRaw.
---@class MissionBattleLogEntry
---@field messageType integer from the MessageType enum
---@field messageKey string I18N key
---@field messageData table? I18N interpolation values

-- Each entry is published as its own game rules param, so LuaUI can read the log back after a reload.
local function addMessage(messageType, messageKey, messageData)
	local log = GG["MissionAPI"].BattleLogRaw
	local entry = { messageType = messageType, messageKey = messageKey, messageData = messageData }
	log[#log + 1] = entry

	Spring.SetGameRulesParam(ENTRY_PARAM_PREFIX .. #log, Json.encode(entry))
	Spring.SetGameRulesParam(COUNT_PARAM, #log)
	SendToUnsynced(SYNC_ACTION)

	Spring.Echo(messageKey) -- placeholder until a widget displays the log
end

return {
	AddMessage = addMessage,
}
