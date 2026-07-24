local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

return {
	type = 'SendMessage',
	parameters = {
		{ name = 'message', required = true, type = ParameterTypes.String },
	},
	actionFunction = Spring.Echo,
}
