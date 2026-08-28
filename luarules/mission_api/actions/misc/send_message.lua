local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
local Presentation = GG['MissionAPI'].Modules.Presentation

---Messages resolve first as an i18n key unsynced-side, then fall back as literal text.
local function sendMessage(message, audience)
	Presentation.SendMessage(message, audience)
end

return {
	{
		type = 'SendMessage',
		parameters = {
			{ name = 'message',  required = true,  type = ParameterTypes.String },
			{ name = 'audience', required = false, type = ParameterTypes.Table }, -- todo: PlayerIDs as audience type
		},
		actionFunction = sendMessage,
	}
}
