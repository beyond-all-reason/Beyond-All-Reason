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

local function getNamesWithParameterType(schemaParameters, parameterType)
	local parameterNames = {}

	for actionOrTriggerType, parameters in pairs(schemaParameters) do
		for _, parameter in ipairs(parameters) do
			if parameter.type == parameterType then
				parameterNames[actionOrTriggerType] = parameter.name
				break
			end
		end
	end

	return parameterNames
end

return {
	GetTypesWithParameterType = getTypesWithParameterType,
	GetNamesWithParameterType = getNamesWithParameterType,
}
