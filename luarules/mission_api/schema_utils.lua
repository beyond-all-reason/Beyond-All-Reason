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

local function collateObjectSchemas(definitions)
	local schemas = {}
	for objectType, typeID in pairs(definitions.Types) do
		local parameters = definitions.Parameters[typeID]
		local rows = {}
		for index, parameter in ipairs(parameters) do
			rows[index] = table.copy(parameter)
		end
		schemas[objectType] = {
			parameters = rows,
			requiresOneOf = table.copy(parameters.requiresOneOf or {}),
		}
	end
	return schemas
end

--- Built on each call from the loaded definitions, so it includes any that have been added.
local function collateSchemas()
	local missionAPI = GG["MissionAPI"]
	local parameterTypes = missionAPI.Modules.ParameterTypes
	return {
		triggers = collateObjectSchemas(missionAPI.TriggerDefinitions),
		triggerSettings = table.copy(missionAPI.TriggerDefinitions.Settings),
		actions = collateObjectSchemas(missionAPI.ActionDefinitions),
		objectiveSettings = table.copy(VFS.Include("luarules/mission_api/objectives_schema.lua").Settings),
		parameterTypes = table.copy(parameterTypes.Types),
		enums = table.copy(parameterTypes.Enums),
	}
end

return {
	GetTypesWithParameterType = getTypesWithParameterType,
	GetParameterNamesWithType = getParameterNamesWithType,
	GetTypesWithParameterName = getTypesWithParameterName,
	CollateSchemas = collateSchemas,
}
