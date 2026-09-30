local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function sendMessage(messageKey, messageData)
	local battleLog = GG['MissionAPI'].Modules.BattleLog
	battleLog.AddMessage(battleLog.MessageTypes.Message, messageKey, messageData)
end

return {
	{
		type = 'SendMessage',
		parameters = {
			{ name = 'messageKey', required = true, type = ParameterTypes.String },
			{ name = 'messageData', required = false, type = ParameterTypes.Table },
		},
		actionFunction = sendMessage,
	}
}
