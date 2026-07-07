local Types = GG['MissionAPI'].Modules.ParameterTypes.Types

return {
	name = 'SendMessage',
	parameters = {
		{ name = 'message', required = true, type = Types.String },
	},
	execute = Spring.Echo,
}
