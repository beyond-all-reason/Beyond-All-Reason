local function getTypesWithParameterType(schemaParameters, parameterType)
	local typesWithParameter = {}

	for actionOrTriggerType, parameters in pairs(schemaParameters) do
		for _, parameter in ipairs(parameters) do
			if parameter.type == parameterType then
				typesWithParameter[actionOrTriggerType] = true
				break
			end
		end
	end

	return typesWithParameter
end

--- @return table<string, string[]> names of the parameters of the given type, per action or trigger type
local function getParameterNamesWithType(schemaParameters, parameterType)
	local parameterNamesByType = {}

	for actionOrTriggerType, parameters in pairs(schemaParameters) do
		local names = {}
		for _, parameter in ipairs(parameters) do
			if parameter.type == parameterType then
				names[#names + 1] = parameter.name
			end
		end
		if #names > 0 then
			parameterNamesByType[actionOrTriggerType] = names
		end
	end

	return parameterNamesByType
end

return {
	GetTypesWithParameterType = getTypesWithParameterType,
	GetParameterNamesWithType = getParameterNamesWithType,
}
