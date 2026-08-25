---
--- Validation of a mission's top level sections: stages, objectives, triggers, actions and loadouts.
---

local SECTIONS = VFS.Include('luarules/mission_api/validation/report.lua').Sections

--------------------------------------------------------------------------------
-- Schema driven parameter validation, shared by triggers, actions and objective triggers
--------------------------------------------------------------------------------

local function createSchemaValidator(context, report, parameterValidators)
	local validateTableType = parameterValidators[context.Types.Table]

	--- @param entity table { section, label, id, name }, where name is what the entity is
	---        called in messages, defaulting to its label. An objective's inline trigger is
	---        labelled 'Objective', since that is the entity, but named 'Objective trigger'.
	--- @param schemaParameters table parameter schemas indexed by entity type
	return function(entity, schemaParameters, entityType, parameters)
		local section, label, id = entity.section, entity.label, entity.id
		local name = entity.name or entity.label

		if not entityType then
			return report.Error(section, label, id, name .. " missing type")
		end
		if not schemaParameters[entityType] then
			return report.Error(section, label, id, name .. " has invalid type")
		end

		local parametersTypeResult = validateTableType(parameters)
		if parametersTypeResult then
			report.Error(section, label, id, parametersTypeResult[1].message, "Parameter: parameters")
			parameters = nil
		end
		parameters = parameters or {}

		local requiresOneOf = schemaParameters[entityType].requiresOneOf
		if requiresOneOf and table.all(requiresOneOf, function(parameterName) return parameters[parameterName] == nil end) then
			report.Error(section, label, id,
				name .. " is missing required parameter, at least one of " .. table.toString(requiresOneOf) .. " is required")
		end

		for _, parameter in ipairs(schemaParameters[entityType]) do
			local value = parameters[parameter.name]
			if value == nil then
				if parameter.required then
					report.Error(section, label, id, name .. " missing required parameter", "Parameter: " .. parameter.name)
				end
			else
				for _, result in ipairs(parameterValidators[parameter.type](value) or {}) do
					local details = "Parameter: " .. parameter.name .. (result.parameterNameSuffix or '')
					local reportResult = result.isWarning and report.Warn or report.Error
					reportResult(section, label, id, result.message, details)
				end
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Stages: stage shape and the mission's initial stage
--------------------------------------------------------------------------------

local STAGE_SECTION = SECTIONS.Stages
local STAGE_LABEL = 'Stage'

local function validateStages(stages, report)
	for stageID, stageData in pairs(stages) do
		if type(stageID) ~= 'string' then
			report.Error(STAGE_SECTION, STAGE_LABEL, stageID, "Stage ID must be a string, got " .. type(stageID))
		end

		if type(stageData) ~= 'table' then
			report.Error(STAGE_SECTION, STAGE_LABEL, stageID, "Stage data must be a table, got " .. type(stageData))
		else
			local objectives = stageData.objectives
			if objectives == nil then
				report.Error(STAGE_SECTION, STAGE_LABEL, stageID, "Stage missing 'objectives' field")
			elseif type(objectives) ~= 'table' then
				report.Error(STAGE_SECTION, STAGE_LABEL, stageID, "Stage 'objectives' field must be a table, got " .. type(objectives))
			elseif #objectives == 0 then
				report.Warn(STAGE_SECTION, STAGE_LABEL, stageID, "Stage has empty 'objectives' table")
			else
				for index, objectiveID in ipairs(objectives) do
					if type(objectiveID) ~= 'string' then
						report.Error(STAGE_SECTION, STAGE_LABEL, stageID,
							"Stage 'objectives' entry must be a string, got " .. type(objectiveID), "Entry: " .. index)
					end
				end
			end
		end
	end
end

local function validateInitialStage(stages, initialStage, report)
	if next(stages) then
		if not initialStage then
			report.Error(STAGE_SECTION, nil, nil, "Stages are defined, but initialStage is not provided")
		elseif stages[initialStage] == nil then
			report.Error(STAGE_SECTION, STAGE_LABEL, initialStage, "Initial stage does not exist in stages")
		end
	elseif initialStage then
		report.Warn(STAGE_SECTION, STAGE_LABEL, initialStage, "initialStage is set, but no stages are defined")
	end
end

local function validateStagesSection(context, report)
	validateStages(context.Stages, report)
	validateInitialStage(context.Stages, context.InitialStage, report)
end

--------------------------------------------------------------------------------
-- Objectives: fields and inline triggers
--------------------------------------------------------------------------------

local OBJECTIVE_SECTION = SECTIONS.Objectives
local OBJECTIVE_LABEL = 'Objective'

--- Objective fields, by the parameter type each is validated as. nextStage points at
--- another entity, so references.lua checks it instead.
local function getObjectiveFieldTypes(Types)
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
				report.Error(OBJECTIVE_SECTION, OBJECTIVE_LABEL, objectiveID, result.message,
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
		report.Error(OBJECTIVE_SECTION, OBJECTIVE_LABEL, objectiveID, "Objective trigger must not have a 'settings' field")
	end
	if objective.trigger.actions ~= nil then
		report.Error(OBJECTIVE_SECTION, OBJECTIVE_LABEL, objectiveID, "Objective trigger must not have an 'actions' field")
	end

	-- Statistics triggers require a quantity, but an objective tracks its progress with its
	-- own 'amount' instead: the loader registers a managed objective, which never reads
	-- quantity. Inject it into a copy so the required-parameter check passes, and warn if
	-- the mission set one, since it is ignored.
	local parameters = objective.trigger.parameters
	if context.TriggerTypesWithQuantity[objective.trigger.type] and type(parameters) == 'table' then
		if parameters.quantity ~= nil then
			report.Warn(OBJECTIVE_SECTION, OBJECTIVE_LABEL, objectiveID, "Objective trigger 'quantity' is not supported and will be ignored")
		end
		parameters = table.copy(parameters)
		parameters.quantity = 1
	end

	validateSchema(
		{ section = OBJECTIVE_SECTION, label = OBJECTIVE_LABEL, id = objectiveID, name = 'Objective trigger' },
		context.TriggerParameters, objective.trigger.type, parameters)
end

local function validateObjective(context, report, parameterValidators, validateSchema, fieldTypes, objectiveID, objective)
	if type(objectiveID) ~= 'string' then
		report.Error(OBJECTIVE_SECTION, OBJECTIVE_LABEL, objectiveID, "Objective ID must be a string, got " .. type(objectiveID))
	end

	if type(objective) ~= 'table' then
		report.Error(OBJECTIVE_SECTION, OBJECTIVE_LABEL, objectiveID, "Objective data must be a table, got " .. type(objective))
		return
	end

	if not objective.textKey then
		report.Error(OBJECTIVE_SECTION, OBJECTIVE_LABEL, objectiveID, "Objective missing textKey")
	elseif objective.textKey == '' then
		report.Error(OBJECTIVE_SECTION, OBJECTIVE_LABEL, objectiveID, "Objective has empty textKey")
	end

	validateObjectiveFields(report, parameterValidators, fieldTypes, objective, objectiveID)
	validateObjectiveInlineTrigger(context, report, validateSchema, objective, objectiveID)
end

local function validateObjectivesSection(context, report, parameterValidators, validateSchema)
	local fieldTypes = getObjectiveFieldTypes(context.Types)

	for objectiveID, objective in pairs(context.Objectives) do
		validateObjective(context, report, parameterValidators, validateSchema, fieldTypes, objectiveID, objective)
	end
end

--------------------------------------------------------------------------------
-- Triggers: actions, settings and parameters
--------------------------------------------------------------------------------

local TRIGGER_SECTION = SECTIONS.Triggers
local TRIGGER_LABEL = 'Trigger'

--- The shared trigger settings (global, not per trigger type), by the parameter type each
--- is validated as. Their defaults are applied by ProcessRawTriggers in triggers_loader.lua.
local function getTriggerSettingTypes(Types)
	return {
		prerequisites = Types.TriggerIDs,
		repeating     = Types.Boolean,
		maxRepeats    = Types.Quantity,
		difficulties  = Types.Table,
		coop          = Types.Boolean,
		active        = Types.Boolean,
		stages        = Types.StageIDs,
	}
end

local function validateTriggerActions(context, report, trigger, triggerID)
	if trigger.actions ~= nil and type(trigger.actions) ~= 'table' then
		report.Error(TRIGGER_SECTION, TRIGGER_LABEL, triggerID, "Trigger 'actions' field must be a table, got " .. type(trigger.actions))
		return
	end

	if table.isNilOrEmpty(trigger.actions) then
		report.Error(TRIGGER_SECTION, TRIGGER_LABEL, triggerID, "Trigger has no actions")
		return
	end

	for _, actionID in pairs(trigger.actions) do
		if actionID == '' then
			report.Error(TRIGGER_SECTION, TRIGGER_LABEL, triggerID, "Trigger has empty action ID")
		elseif not context.Actions[actionID] then
			report.Error(TRIGGER_SECTION, TRIGGER_LABEL, triggerID, "Trigger has invalid action ID", "Action: " .. tostring(actionID))
		end
	end
end

--- Settings are optional in raw missions; triggers_loader.lua applies the defaults later.
local function validateTriggerSettings(report, parameterValidators, settingTypes, validateTableType, trigger, triggerID)
	local settings = trigger.settings
	if settings == nil then
		return
	end

	local settingsTypeResult = validateTableType(settings)
	if settingsTypeResult then
		report.Error(TRIGGER_SECTION, TRIGGER_LABEL, triggerID, settingsTypeResult[1].message, "Setting: settings")
		return
	end

	-- Validate the type of each setting. The TriggerIDs and StageIDs types also check
	-- that every listed prerequisite trigger and stage exists.
	for setting, settingType in pairs(settingTypes) do
		if settings[setting] ~= nil then
			for _, result in ipairs(parameterValidators[settingType](settings[setting]) or {}) do
				report.Error(TRIGGER_SECTION, TRIGGER_LABEL, triggerID, result.message,
					"Setting: " .. setting .. (result.parameterNameSuffix or ''))
			end
		end
	end

	if settings.maxRepeats and not settings.repeating then
		report.Error(TRIGGER_SECTION, TRIGGER_LABEL, triggerID, "Trigger has maxRepeats setting but is not set to repeating")
	end
end

local function validateTriggersSection(context, report, parameterValidators, validateSchema)
	local settingTypes = getTriggerSettingTypes(context.Types)
	local validateTableType = parameterValidators[context.Types.Table]

	for triggerID, trigger in pairs(context.Triggers) do
		if type(trigger) ~= 'table' then
			report.Error(TRIGGER_SECTION, TRIGGER_LABEL, triggerID, "Trigger data must be a table, got " .. type(trigger))
		else
			validateTriggerActions(context, report, trigger, triggerID)
			validateTriggerSettings(report, parameterValidators, settingTypes, validateTableType, trigger, triggerID)
			validateSchema({ section = TRIGGER_SECTION, label = TRIGGER_LABEL, id = triggerID },
				context.TriggerParameters, trigger.type, trigger.parameters)
		end
	end
end

--------------------------------------------------------------------------------
-- Actions: parameters and whether a trigger uses them
--------------------------------------------------------------------------------

local ACTION_SECTION = SECTIONS.Actions
local ACTION_LABEL = 'Action'

local function getAllActionIDsReferencedByTriggers(triggers)
	local allActionIDsReferencedByTriggers = {}
	for _, trigger in pairs(triggers) do
		if type(trigger) == 'table' and type(trigger.actions) == 'table' then
			for _, actionID in pairs(trigger.actions) do
				allActionIDsReferencedByTriggers[actionID] = true
			end
		end
	end
	return allActionIDsReferencedByTriggers
end

local function validateActionsSection(context, report, parameterValidators, validateSchema)
	local allActionIDsReferencedByTriggers = getAllActionIDsReferencedByTriggers(context.Triggers)

	local unreferencedActionIDs = {}
	for actionID, action in pairs(context.Actions) do
		if not allActionIDsReferencedByTriggers[actionID] then
			unreferencedActionIDs[#unreferencedActionIDs + 1] = actionID
		end

		if type(action) ~= 'table' then
			report.Error(ACTION_SECTION, ACTION_LABEL, actionID, "Action data must be a table, got " .. type(action))
		else
			validateSchema({ section = ACTION_SECTION, label = ACTION_LABEL, id = actionID },
				context.ActionParameters, action.type, action.parameters)
		end
	end

	if not table.isEmpty(unreferencedActionIDs) then
		table.sort(unreferencedActionIDs)
		report.Error(ACTION_SECTION, nil, nil, "Actions not referenced by any trigger: " .. table.concat(unreferencedActionIDs, ", "))
	end
end

--------------------------------------------------------------------------------
-- Loadouts: the mission's own unit and feature loadouts
--
-- Loadouts in actions are validated as action parameters instead.
--------------------------------------------------------------------------------

local LOADOUT_SECTION = SECTIONS.Loadouts
local LOADOUT_LABEL = 'Loadout'

local function validateLoadoutsSection(context, report, parameterValidators)
	local Types = context.Types
	local loadouts = {
		{ name = 'UnitLoadout',    value = context.UnitLoadout,    type = Types.UnitLoadout },
		{ name = 'FeatureLoadout', value = context.FeatureLoadout, type = Types.FeatureLoadout },
	}

	for _, loadout in ipairs(loadouts) do
		for _, result in ipairs(parameterValidators[loadout.type](loadout.value) or {}) do
			report.Error(LOADOUT_SECTION, LOADOUT_LABEL, loadout.name .. (result.parameterNameSuffix or ''), result.message)
		end
	end
end

--------------------------------------------------------------------------------

local function validate(context, report, parameterValidators)
	local validateSchema = createSchemaValidator(context, report, parameterValidators)

	-- Same order here as in the report:
	validateStagesSection(context, report)
	validateObjectivesSection(context, report, parameterValidators, validateSchema)
	validateTriggersSection(context, report, parameterValidators, validateSchema)
	validateActionsSection(context, report, parameterValidators, validateSchema)
	validateLoadoutsSection(context, report, parameterValidators)
end

return {
	Validate = validate,
}
