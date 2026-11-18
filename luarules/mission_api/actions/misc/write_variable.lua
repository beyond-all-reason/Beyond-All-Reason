local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function writeVariable(key, value)
	-- Copy tables so later changes to the variable do not alter this action's parameter.
	if type(value) == 'table' then
		value = table.copy(value)
	end
	GG['MissionAPI'].Modules.Variables.Set(key, value)
end

return {
	{
		type = 'WriteVariable',
		parameters = {
			{ name = 'key', required = true, type = ParameterTypes.VariableKey },
			{ name = 'value', required = true, type = ParameterTypes.VariableValue },
		},
		actionFunction = writeVariable,
	}
}
