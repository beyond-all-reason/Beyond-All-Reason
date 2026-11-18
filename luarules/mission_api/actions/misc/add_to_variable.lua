local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function addToVariable(key, amount)
	local variables = GG['MissionAPI'].Modules.Variables
	variables.Set(key, variables.Get(key) + amount)
end

return {
	{
		type = 'AddToVariable',
		parameters = {
			{ name = 'key', required = true, type = ParameterTypes.VariableKey },
			{ name = 'amount', required = true, type = ParameterTypes.Integer },
		},
		actionFunction = addToVariable,
	}
}
