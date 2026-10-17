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

local function getTypesWithParameterName(schemaParameters, parameterName)
	local typesWithParameter = {}

	for actionOrTriggerType, parameters in pairs(schemaParameters) do
		for _, parameter in ipairs(parameters) do
			if parameter.name == parameterName then
				typesWithParameter[actionOrTriggerType] = true
				break
			end
		end
	end

	return typesWithParameter
end

return {
	GetTypesWithParameterType = getTypesWithParameterType,
	GetTypesWithParameterName = getTypesWithParameterName,
}
