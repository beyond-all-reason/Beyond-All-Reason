---
--- Mission API validation entrypoint.
--- Validates raw mission data, returning the collected messages.
--- The validators never log themselves, so that the messages stay grouped and ordered;
--- LogResult writes them out once validation is done.
---

local createValidationContext = VFS.Include('luarules/mission_api/validation/validation_context.lua').CreateValidationContext
local createValidationReport = VFS.Include('luarules/mission_api/validation/validation_report.lua').CreateValidationReport
local createParameterValidators = VFS.Include('luarules/mission_api/validation/parameter_validators.lua').CreateParameterValidators
local createSchemaValidator = VFS.Include('luarules/mission_api/validation/schema_validation.lua').CreateSchemaValidator

local stagesValidation = VFS.Include('luarules/mission_api/validation/stages_validation.lua')
local objectivesValidation = VFS.Include('luarules/mission_api/validation/objectives_validation.lua')
local triggersValidation = VFS.Include('luarules/mission_api/validation/triggers_validation.lua')
local actionsValidation = VFS.Include('luarules/mission_api/validation/actions_validation.lua')
local loadoutsValidation = VFS.Include('luarules/mission_api/validation/loadouts_validation.lua')
local stageObjectiveReferencesValidation = VFS.Include('luarules/mission_api/validation/stage_objective_references_validation.lua')
local nameReferencesValidation = VFS.Include('luarules/mission_api/validation/name_references_validation.lua')

local function runValidation(mission, definitions, report)
	local context = createValidationContext(mission, definitions, report)
	local parameterValidators = createParameterValidators(context)
	local validateSchema = createSchemaValidator(parameterValidators, report)

	-- Same order here as in report:
	stagesValidation.Validate(context, report, parameterValidators, validateSchema)
	objectivesValidation.Validate(context, report, parameterValidators, validateSchema)
	triggersValidation.Validate(context, report, parameterValidators, validateSchema)
	actionsValidation.Validate(context, report, parameterValidators, validateSchema)
	loadoutsValidation.Validate(context, report, parameterValidators, validateSchema)
	stageObjectiveReferencesValidation.Validate(context, report)
	nameReferencesValidation.Validate(context, report)
end

--- @param mission table raw mission table, exactly as returned by the mission file
--- @param definitions table { ParameterTypes, TriggerDefinitions, ActionDefinitions }
--- @return table result { ok = boolean, errors = string[], warnings = string[] }
local function validateMission(mission, definitions)
	local report = createValidationReport()

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
