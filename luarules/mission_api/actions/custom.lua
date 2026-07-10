local Types = GG['MissionAPI'].Modules.ParameterTypes.Types

local function custom(func)
	func()
end

return {
	name = 'Custom',
	parameters = {
		{ name = 'function', required = true, type = Types.Function },
	},
	execute = custom,
}
