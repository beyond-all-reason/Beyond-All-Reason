local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
local MessageTypes = GG['MissionAPI'].Modules.ParameterTypes.Enums[ParameterTypes.MessageType]

local function sendMessage(messageKey, messageData)
	GG['MissionAPI'].Modules.BattleLog.AddMessage(MessageTypes.Message, messageKey, messageData)
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
