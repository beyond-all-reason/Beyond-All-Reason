local Types = GG['MissionAPI'].Modules.ParameterTypes.Types

local function custom(func)
	func()
end

return {
	type = 'Custom',
	parameters = {
		{ name = 'function', required = true, type = Types.Function },
	},
	actionFunction = custom,
}
