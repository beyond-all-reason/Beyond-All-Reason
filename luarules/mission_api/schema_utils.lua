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

---Swaps a parameter name's "Name"/"Names" suffix for "ID"/"IDs": "teamName" --> "teamID"
local function swapNameSuffixForID(parameterName)
	if parameterName:match("Names$") then
		return (parameterName:gsub("Names$", "IDs"))
	end
	return (parameterName:gsub("Name$", "ID"))
end

---Assigns every parameter the key its value is stored under. Need for mapping team names to their IDs.
local function assignValueKeys(schemaParameters)
	local parameterTypes = GG["MissionAPI"].Modules.ParameterTypes.Types
	local resolvedTypes = {
		[parameterTypes.TeamName] = true,
		[parameterTypes.AllyTeamName] = true,
		[parameterTypes.AllyTeamNames] = true,
	}

	for _, parameters in pairs(schemaParameters) do
		for _, parameter in ipairs(parameters) do
			if resolvedTypes[parameter.type] then
				parameter.valueKey = swapNameSuffixForID(parameter.name)
			else
				parameter.valueKey = parameter.name
			end
		end
	end

	return schemaParameters
end

return {
	GetTypesWithParameterType = getTypesWithParameterType,
	SwapNameSuffixForID = swapNameSuffixForID,
	AssignValueKeys = assignValueKeys,
}
