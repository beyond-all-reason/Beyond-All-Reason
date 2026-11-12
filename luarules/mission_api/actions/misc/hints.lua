local ParameterTypes = GG["MissionAPI"].Modules.ParameterTypes.Types

-- One hint at a time, as public game rules params for the hint widget (gui_mission_hint):
--     mission_hint_key, mission_hint_data (json), mission_hint_until (game frame, 0 = until hidden),
--     mission_hint_serial, bumped on every change and written last.
local PARAM_PREFIX = "mission_hint_"
local PUBLIC = { public = true }

local function publish(messageKey, messageData, untilFrame)
	Spring.SetGameRulesParam(PARAM_PREFIX .. "key", messageKey, PUBLIC)
	Spring.SetGameRulesParam(PARAM_PREFIX .. "data", messageData and Json.encode(messageData) or nil, PUBLIC)
	Spring.SetGameRulesParam(PARAM_PREFIX .. "until", untilFrame or 0, PUBLIC)
	local serial = tonumber((Spring.GetGameRulesParam(PARAM_PREFIX .. "serial"))) or 0
	Spring.SetGameRulesParam(PARAM_PREFIX .. "serial", serial + 1, PUBLIC)
end

local function showHint(messageKey, messageData, seconds)
	local untilFrame = seconds and (Spring.GetGameFrame() + math.ceil(seconds * Game.gameSpeed)) or 0
	publish(messageKey, messageData, untilFrame)
end

local function hideHint()
	publish(nil, nil, 0)
end

return {
	{
		type = "ShowHint",
		parameters = {
			{ name = "messageKey", required = true, type = ParameterTypes.String },
			{ name = "messageData", required = false, type = ParameterTypes.Table },
			{ name = "seconds", required = false, type = ParameterTypes.Number },
		},
		actionFunction = showHint,
	},
	{
		type = "HideHint",
		parameters = {},
		actionFunction = hideHint,
	},
}
