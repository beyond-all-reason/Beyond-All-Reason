local ParameterTypes = GG["MissionAPI"].Modules.ParameterTypes.Types

-- Read by gui_mission_hint; nil while no hint is shown.
local HINT_PARAM = "missionHint"
local SYNC_ACTION = "MissionHintChanged"

local function publish(hint)
	Spring.SetGameRulesParam(HINT_PARAM, hint and Json.encode(hint) or nil)
	SendToUnsynced(SYNC_ACTION)
end

local function showHint(messageKey, messageData, seconds)
	local untilFrame = seconds and Spring.GetGameFrame() + math.max(1, math.ceil(seconds * Game.gameSpeed)) or nil
	publish({ messageKey = messageKey, messageData = messageData, untilFrame = untilFrame })
end

local function hideHint()
	publish(nil)
end

return {
	{
		type = "ShowHint",
		parameters = {
			{ name = "messageKey", required = true, type = ParameterTypes.String },
			{ name = "messageData", required = false, type = ParameterTypes.Table },
			{ name = "seconds", required = false, type = ParameterTypes.Quantity },
		},
		actionFunction = showHint,
	},
	{
		type = "HideHint",
		parameters = {},
		actionFunction = hideHint,
	},
}
