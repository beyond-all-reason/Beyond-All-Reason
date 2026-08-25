---
--- Mission API validation entrypoint.
--- Validates raw mission data, returning the collected messages, ordered.
--- LogResult writes the messages.
---

local schemaUtils = VFS.Include('luarules/mission_api/schema_utils.lua')
local validationReport = VFS.Include('luarules/mission_api/validation/report.lua')
local createReport = validationReport.Create
local sections = validationReport.Sections
local createParameterValidators = VFS.Include('luarules/mission_api/validation/parameter_validators.lua').CreateParameterValidators
local sectionsValidation = VFS.Include('luarules/mission_api/validation/sections.lua')
local referencesValidation = VFS.Include('luarules/mission_api/validation/references.lua')

--- Mission tables are normalised here so no validator has to handle a missing or
--- misdeclared one. A wrong type is reported once, in the section it belongs to.
local function missionTable(value, fieldName, section, report)
	if value == nil then
		return {}
	end
	if type(value) ~= 'table' then
		report.Error(section, nil, nil, fieldName .. " must be a table, got " .. type(value))
		return {}
	end
	return value
end

--- Read-only view of the raw mission data and the injected definitions.
--- @param mission table raw mission table, exactly as returned by the mission file
--- @param definitions table { ParameterTypes, TriggerDefinitions, ActionDefinitions }
local function createValidationContext(mission, definitions, report)
	local parameterTypes = definitions.ParameterTypes
	local triggerDefinitions = definitions.TriggerDefinitions
	local actionDefinitions = definitions.ActionDefinitions

	return {
		-- Raw mission data:
		InitialStage   = mission.InitialStage,
		Stages         = missionTable(mission.Stages, 'Stages', sections.Stages, report),
		Objectives     = missionTable(mission.Objectives, 'Objectives', sections.Objectives, report),
		Triggers       = missionTable(mission.Triggers, 'Triggers', sections.Triggers, report),
		Actions        = missionTable(mission.Actions, 'Actions', sections.Actions, report),
		UnitLoadout    = missionTable(mission.UnitLoadout, 'UnitLoadout', sections.Loadouts, report),
		FeatureLoadout = missionTable(mission.FeatureLoadout, 'FeatureLoadout', sections.Loadouts, report),

		-- Parameter types:
		Types    = parameterTypes.Types,
		Enums    = parameterTypes.Enums,
		EnumSets = parameterTypes.EnumSets,

		-- Trigger definitions:
		TriggerParameters        = triggerDefinitions.Parameters,
		TriggerTypesWithQuantity = schemaUtils.GetTypesWithParameterType(triggerDefinitions.Parameters, parameterTypes.Types.Quantity),

		-- Action definitions:
		ActionTypes      = actionDefinitions.Types,
		ActionParameters = actionDefinitions.Parameters,
	}
end

local function runValidation(mission, definitions, report)
	local context = createValidationContext(mission, definitions, report)
	local parameterValidators = createParameterValidators(context)

	sectionsValidation.Validate(context, report, parameterValidators)
	referencesValidation.Validate(context, report)
end

--- @param mission table raw mission table, exactly as returned by the mission file
--- @param definitions table { ParameterTypes, TriggerDefinitions, ActionDefinitions }
--- @return table result { ok = boolean, errors = string[], warnings = string[] }
local function validateMission(mission, definitions)
	local report = createReport()

	local succeeded, err = pcall(runValidation, mission, definitions, report)

	local result = report.GetResult()
	if not succeeded then
		-- Validation is incomplete after an internal error, so the mission cannot be trusted.
		result.ok = false
		result.errors[#result.errors + 1] = "Validation failed unexpectedly: " .. tostring(err)
	end

	return result
end

--- @param result table as returned by ValidateMission
local function logResult(result)
	for _, message in ipairs(result.errors) do
		Spring.Log('MissionAPI', LOG.ERROR, "[Mission API] " .. message)
	end
	for _, message in ipairs(result.warnings) do
		Spring.Log('MissionAPI', LOG.WARNING, "[Mission API] " .. message)
	end
end

return {
	ValidateMission = validateMission,
	LogResult       = logResult,
}
