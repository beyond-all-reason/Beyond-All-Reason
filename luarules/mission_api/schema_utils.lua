local TRANSLATION_ROOT = "missionEditor" -- from the editor's language/<language>/missionEditor.json

local function getTypesWithParameterType(schemaParameters, parameterType)
	local typesWithParameter = {}

	for actionOrConditionType, parameters in pairs(schemaParameters) do
		for _, parameter in ipairs(parameters) do
			if parameter.type == parameterType then
				typesWithParameter[actionOrConditionType] = true
				break
			end
		end
	end

	return typesWithParameter
end

--- @return table<string, string[]> names of the parameters of the given type, per action or condition type
local function getParameterNamesWithType(schemaParameters, parameterType)
	local parameterNamesByType = {}

	for actionOrConditionType, parameters in pairs(schemaParameters) do
		local names = {}
		for _, parameter in ipairs(parameters) do
			if parameter.type == parameterType then
				names[#names + 1] = parameter.name
			end
		end
		if #names > 0 then
			parameterNamesByType[actionOrConditionType] = names
		end
	end

	return parameterNamesByType
end

local function getTypesWithParameterName(schemaParameters, parameterName)
	local typesWithParameter = {}

	for actionOrConditionType, parameters in pairs(schemaParameters) do
		for _, parameter in ipairs(parameters) do
			if parameter.name == parameterName then
				typesWithParameter[actionOrConditionType] = true
				break
			end
		end
	end

	return typesWithParameter
end

local function setTranslationKeys(entry, translationKey)
	entry.i18nNameKey = translationKey .. ".name"
	entry.i18nDescriptionKey = translationKey .. ".description"
end

local function getTranslationKeysByName(names, translationKey)
	local translationKeys = {}
	for name in pairs(names) do
		translationKeys[name] = {}
		setTranslationKeys(translationKeys[name], translationKey .. "." .. name)
	end
	return translationKeys
end

local function getEnumTranslationKeys(enums, translationKey)
	local translationKeys = {}
	for enumType, values in pairs(enums) do
		translationKeys[enumType] = getTranslationKeysByName(values, translationKey .. "." .. enumType)
	end
	return translationKeys
end

local function collateRows(rows, translationKey)
	local collated = {}
	for index, row in ipairs(rows) do
		collated[index] = table.copy(row)
		setTranslationKeys(collated[index], translationKey .. "." .. row.name)
	end
	return collated
end

local function collateObjectSchemas(definitions, translationKey)
	local schemas = {}
	for objectType, typeID in pairs(definitions.Types) do
		local parameters = definitions.Parameters[typeID]
		local objectKey = translationKey .. "." .. objectType
		schemas[objectType] = {
			parameters = collateRows(parameters, objectKey .. ".parameters"),
			requiresOneOf = table.copy(parameters.requiresOneOf or {}),
		}
		setTranslationKeys(schemas[objectType], objectKey)
	end
	return schemas
end

--- Built on each call from the loaded definitions, so it includes any that have been added.
local function collateSchemas()
	local missionAPI = GG["MissionAPI"]
	local parameterTypes = missionAPI.Modules.ParameterTypes
	local loadoutSchema = VFS.Include("luarules/mission_api/loadout_schema.lua")
	local unitFilterSchema = VFS.Include("luarules/mission_api/unit_filter_schema.lua")
	local triggerSettings = VFS.Include("luarules/mission_api/triggers_schema.lua").Settings
	local objectiveSettings = VFS.Include("luarules/mission_api/objectives_schema.lua").Settings
	return {
		conditions = collateObjectSchemas(missionAPI.ConditionDefinitions, TRANSLATION_ROOT .. ".conditions"),
		triggerSettings = table.copy(triggerSettings),
		triggerSettingTranslationKeys = getTranslationKeysByName(
			triggerSettings,
			TRANSLATION_ROOT .. ".triggerSettings"
		),
		actions = collateObjectSchemas(missionAPI.ActionDefinitions, TRANSLATION_ROOT .. ".actions"),
		objectiveSettings = table.copy(objectiveSettings),
		objectiveSettingTranslationKeys = getTranslationKeysByName(
			objectiveSettings,
			TRANSLATION_ROOT .. ".objectiveSettings"
		),
		unitEntryFields = collateRows(loadoutSchema.UnitEntryFields, TRANSLATION_ROOT .. ".unitEntryFields"),
		featureEntryFields = collateRows(loadoutSchema.FeatureEntryFields, TRANSLATION_ROOT .. ".featureEntryFields"),
		unitFilterFields = collateRows(unitFilterSchema.UnitFilterFields, TRANSLATION_ROOT .. ".unitFilterFields"),
		unitFilterAtMostOneOf = table.copy(unitFilterSchema.AtMostOneOf),
		parameterTypes = table.copy(parameterTypes.Types),
		parameterTypeTranslationKeys = getTranslationKeysByName(
			parameterTypes.Types,
			TRANSLATION_ROOT .. ".parameterTypes"
		),
		enums = table.copy(parameterTypes.Enums),
		enumTranslationKeys = getEnumTranslationKeys(parameterTypes.Enums, TRANSLATION_ROOT .. ".enums"),
	}
end

return {
	GetTypesWithParameterType = getTypesWithParameterType,
	GetParameterNamesWithType = getParameterNamesWithType,
	GetTypesWithParameterName = getTypesWithParameterName,
	CollateSchemas = collateSchemas,
}
