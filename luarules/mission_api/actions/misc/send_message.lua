local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
local Presentation = GG['MissionAPI'].Modules.Presentation

-- A moment, so it goes out on the broadcast channel. The audience is accepted and
-- threaded, but broadcast cannot enforce it: anything private must be published as
-- state instead. The message is resolved as an i18n key unsynced-side, falling back
-- to itself, so authored prose and keys both work.
local function sendMessage(message, audience)
	Presentation.SendMessage(message, audience)
end

return {
	{
		type = 'SendMessage',
		parameters = {
			{ name = 'message',  required = true,  type = ParameterTypes.String },
			{ name = 'audience', required = false, type = ParameterTypes.Table },
		},
		actionFunction = sendMessage,
	}
}
