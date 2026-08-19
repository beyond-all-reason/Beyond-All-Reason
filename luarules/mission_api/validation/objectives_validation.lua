---
--- Objective validation: fields and inline triggers.
---

local SECTION = VFS.Include('luarules/mission_api/validation/validation_report.lua').Sections.Objectives
local LABEL = 'Objective'

--- Objective fields, by the parameter type each is validated as. nextStage points at
--- another entity, so stage_objective_references_validation checks it instead.
local function getFieldTypes(Types)
	return {
		textKey = Types.String,
		trigger = Types.Table,
		amount  = Types.Quantity,
		coop    = Types.Boolean,
	}
end

local function validateObjectiveFields(report, parameterValidators, fieldTypes, objective, objectiveID)
	for fieldName, fieldType in pairs(fieldTypes) do
		if objective[fieldName] ~= nil then
			for _, result in ipairs(parameterValidators[fieldType](objective[fieldName]) or {}) do
				report.Error(SECTION, LABEL, objectiveID, result.message,
					"Field: " .. fieldName .. (result.parameterNameSuffix or ''))
			end
		end
	end
end

local function validateObjectiveInlineTrigger(context, report, validateSchema, objective, objectiveID)
	if type(objective.trigger) ~= 'table' then
		return
	end

	if objective.trigger.settings ~= nil then
		report.Error(SECTION, LABEL, objectiveID, "Objective trigger must not have a 'settings' field")
	end
	if objective.trigger.actions ~= nil then
		report.Error(SECTION, LABEL, objectiveID, "Objective trigger must not have an 'actions' field")
	end

	-- For statistics triggers, quantity is always forced to 1 by the loader.
	-- Inject it here so the required-parameter check passes even if the user omitted it,
	-- and warn if the user explicitly specified it (since it will be ignored).
	local parameters = objective.trigger.parameters
	if context.TriggerTypesWithQuantity[objective.trigger.type] and type(parameters) == 'table' then
		if parameters.quantity ~= nil then
			report.Warn(SECTION, LABEL, objectiveID, "Objective trigger 'quantity' is not supported and will be ignored")
		end
		parameters = table.copy(parameters)
		parameters.quantity = 1
	end

	validateSchema(
		{ section = SECTION, label = LABEL, id = objectiveID, name = 'Objective trigger' },
		context.TriggerParameters, objective.trigger.type, parameters)
end

local function validateObjective(context, report, parameterValidators, validateSchema, fieldTypes, objectiveID, objective)
	if type(objectiveID) ~= 'string' then
		report.Error(SECTION, LABEL, objectiveID, "Objective ID must be a string, got " .. type(objectiveID))
	end

	if type(objective) ~= 'table' then
		report.Error(SECTION, LABEL, objectiveID, "Objective data must be a table, got " .. type(objective))
		return
	end

	if not objective.textKey then
		report.Error(SECTION, LABEL, objectiveID, "Objective missing textKey")
	elseif objective.textKey == '' then
		report.Error(SECTION, LABEL, objectiveID, "Objective has empty textKey")
	end

	validateObjectiveFields(report, parameterValidators, fieldTypes, objective, objectiveID)
	validateObjectiveInlineTrigger(context, report, validateSchema, objective, objectiveID)
end

local function validate(context, report, parameterValidators, validateSchema)
	local fieldTypes = getFieldTypes(context.Types)

	for objectiveID, objective in pairs(context.Objectives) do
		validateObjective(context, report, parameterValidators, validateSchema, fieldTypes, objectiveID, objective)
	end
end

return {
	Validate = validate,
}
