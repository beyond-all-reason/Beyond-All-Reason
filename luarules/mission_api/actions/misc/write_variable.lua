local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function writeVariable(key, value, persistent)
	-- Copy tables so later changes to the variable do not alter this action's parameter.
	if type(value) == 'table' then
		value = table.copy(value)
	end
	GG['MissionAPI'].Variables[key] = value
	if persistent then
		GG['MissionAPI'].PersistentVariables[key] = true
	end
end

return {
	{
		type = 'WriteVariable',
		parameters = {
			{ name = 'key', required = true, type = ParameterTypes.String },
			{ name = 'value', required = true, type = ParameterTypes.VariableValue },
			{ name = 'persistent', required = false, type = ParameterTypes.Boolean },
		},
		actionFunction = writeVariable,
	}
}
