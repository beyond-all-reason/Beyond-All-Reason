local TRANSLATION_ROOT = "missionEditor" -- from language/<language>/missionEditor.json

local SETTINGS_SCHEMA_FILES = {
	triggerSettings = "luarules/mission_api/triggers_schema.lua",
	objectiveSettings = "luarules/mission_api/objectives_schema.lua",
	stageSettings = "luarules/mission_api/stages_schema.lua",
	cutsceneSettings = "luarules/mission_api/cutscenes_schema.lua",
	countdownSettings = "luarules/mission_api/countdowns_schema.lua",
}

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

local function setTranslationKeys(entry, path)
	local translationKey = TRANSLATION_ROOT .. "." .. path
	entry.i18nNameKey = translationKey .. ".name"
	entry.i18nDescriptionKey = translationKey .. ".description"
end

local function collateNames(names, path)
	local collated = {}
	for name in pairs(names) do
		collated[name] = {}
		setTranslationKeys(collated[name], path .. "." .. name)
	end
	return collated
end

local function collateSettings(settings, path)
	local collated = {}
	for name, parameterType in pairs(settings) do
		collated[name] = { type = parameterType }
		setTranslationKeys(collated[name], path .. "." .. name)
	end
	return collated
end

local function collateRows(rows, path)
	local collated = {}
	for index, row in ipairs(rows) do
		collated[index] = table.copy(row)
		setTranslationKeys(collated[index], path .. "." .. row.name)
	end
	return collated
end

local function collateObjectSchemas(definitions, path)
	local schemas = {}
	for objectType, typeID in pairs(definitions.Types) do
		local parameters = definitions.Parameters[typeID]
		local objectPath = path .. "." .. objectType
		schemas[objectType] = {
			parameters = collateRows(parameters, objectPath .. ".parameters"),
			requiresOneOf = table.copy(parameters.requiresOneOf or {}),
		}
		setTranslationKeys(schemas[objectType], objectPath)
	end
	return schemas
end

--- Built on each call from the loaded definitions, so it includes any that have been added.
local function collateSchemas()
	local missionAPI = GG["MissionAPI"]
	local parameterTypes = missionAPI.Modules.ParameterTypes
	local loadoutSchema = VFS.Include("luarules/mission_api/loadout_schema.lua")
	local unitFilterSchema = VFS.Include("luarules/mission_api/unit_filter_schema.lua")
	local cameraKeyframeSchema = VFS.Include("luarules/mission_api/camera_keyframe_schema.lua")

	local schemas = {
		conditions = collateObjectSchemas(missionAPI.ConditionDefinitions, "conditions"),
		actions = collateObjectSchemas(missionAPI.ActionDefinitions, "actions"),
		unitEntryFields = collateRows(loadoutSchema.UnitEntryFields, "unitEntryFields"),
		featureEntryFields = collateRows(loadoutSchema.FeatureEntryFields, "featureEntryFields"),
		unitFilterFields = collateRows(unitFilterSchema.UnitFilterFields, "unitFilterFields"),
		unitFilterAtMostOneOf = table.copy(unitFilterSchema.AtMostOneOf),
		cameraKeyframeSettings = collateSettings(cameraKeyframeSchema.Settings, "cameraKeyframeSettings"),
		cameraKeyframeExactlyOneOf = table.copy(cameraKeyframeSchema.ExactlyOneOf),
		cameraKeyframeAtMostOneOf = table.copy(cameraKeyframeSchema.AtMostOneOf),
		parameterTypes = collateNames(parameterTypes.Types, "parameterTypes"),
		enums = {},
	}
	for section, schemaFile in pairs(SETTINGS_SCHEMA_FILES) do
		schemas[section] = collateSettings(VFS.Include(schemaFile).Settings, section)
	end
	for enumType, values in pairs(parameterTypes.Enums) do
		schemas.enums[enumType] = collateNames(values, "enums." .. enumType)
	end
	return schemas
end

return {
	GetTypesWithParameterType = getTypesWithParameterType,
	GetParameterNamesWithType = getParameterNamesWithType,
	GetTypesWithParameterName = getTypesWithParameterName,
	CollateSchemas = collateSchemas,
}
