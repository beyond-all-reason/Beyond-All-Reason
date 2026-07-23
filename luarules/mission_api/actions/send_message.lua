local Types = GG['MissionAPI'].Modules.ParameterTypes.Types

return {
	type = 'SendMessage',
	parameters = {
		{ name = 'message', required = true, type = Types.String },
	},
	actionFunction = Spring.Echo,
}
