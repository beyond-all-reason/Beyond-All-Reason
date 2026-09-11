---
--- Validation of a mission's top level sections: stages, objectives, triggers, actions, and loadouts.
---

local SECTIONS = VFS.Include("luarules/mission_api/validation/report.lua").Sections

--------------------------------------------------------------------------------
-- Shared helpers
--------------------------------------------------------------------------------

local function reporterFor(report, section, label)
	return {
		Error = function(id, message, details)
			report.Error(section, label, id, message, details)
		end,
		Warn = function(id, message, details)
			report.Warn(section, label, id, message, details)
		end,
		--- For a problem with the section as a whole, belonging to no single entity.
		SectionError = function(message)
			report.Error(section, nil, nil, message)
		end,
	}
end

local function validateTypedFields(reporter, id, parameterValidators, fieldTypes, values, valueLabel)
	for fieldName, fieldType in pairs(fieldTypes) do
		local value = values[fieldName]
		if value ~= nil then
			for _, result in ipairs(parameterValidators[fieldType](value) or {}) do
				local details = valueLabel .. ": " .. fieldName .. (result.parameterNameSuffix or "")
				reporter.Error(id, result.message, details)
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Schema driven parameter validation, shared by triggers, actions and objective triggers
--------------------------------------------------------------------------------

local function createSchemaValidator(context, parameterValidators)
	local validateTableType = parameterValidators[context.Types.Table]

	--- @param name string what the entity is called in messages. An objective's inline
	---        trigger is reported against the objective, but named 'Objective trigger'.
	--- @param schemaParameters table parameter schemas indexed by entity type
	return function(reporter, id, name, schemaParameters, entityType, parameters)
		if not entityType then
			return reporter.Error(id, name .. " missing type")
		end

		local schema = schemaParameters[entityType]
		if not schema then
			return reporter.Error(id, name .. " has invalid type")
		end

		local parametersTypeResult = validateTableType(parameters)
		if parametersTypeResult then
			reporter.Error(id, parametersTypeResult[1].message, "Parameter: parameters")
			parameters = nil
		end
		parameters = parameters or {}

		local requiresOneOf = schema.requiresOneOf
		local function isMissing(parameterName)
			return parameters[parameterName] == nil
		end
		if requiresOneOf and table.all(requiresOneOf, isMissing) then
			reporter.Error(
				id,
				name
					.. " is missing required parameter, at least one of "
					.. table.toString(requiresOneOf)
					.. " is required"
			)
		end

		for _, parameter in ipairs(schema) do
			local value = parameters[parameter.name]
			if value == nil then
				if parameter.required then
					reporter.Error(id, name .. " missing required parameter", "Parameter: " .. parameter.name)
				end
			else
				for _, result in ipairs(parameterValidators[parameter.type](value) or {}) do
					local details = "Parameter: " .. parameter.name .. (result.parameterNameSuffix or "")
					local reportResult = result.isWarning and reporter.Warn or reporter.Error
					reportResult(id, result.message, details)
				end
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Stages: stage shape and the mission's initial stage
--------------------------------------------------------------------------------

local function validateStages(stages, stageReport)
	for stageID, stageData in pairs(stages) do
		if type(stageID) ~= "string" then
			stageReport.Error(stageID, "Stage ID must be a string, got " .. type(stageID))
		end

		if type(stageData) ~= "table" then
			stageReport.Error(stageID, "Stage data must be a table, got " .. type(stageData))
		else
			local objectives = stageData.objectives
			if objectives == nil then
				stageReport.Error(stageID, "Stage missing 'objectives' field")
			elseif type(objectives) ~= "table" then
				stageReport.Error(stageID, "Stage 'objectives' field must be a table, got " .. type(objectives))
			else
				-- A stage with no objectives is valid
				for index, objectiveID in ipairs(objectives) do
					if type(objectiveID) ~= "string" then
						local got = type(objectiveID)
						stageReport.Error(
							stageID,
							"Stage 'objectives' entry must be a string, got " .. got,
							"Entry: " .. index
						)
					end
				end
			end
		end
	end
end

local function validateInitialStage(stages, initialStage, stageReport)
	if next(stages) then
		if not initialStage then
			stageReport.SectionError("Stages are defined, but initialStage is not provided")
		elseif stages[initialStage] == nil then
			stageReport.Error(initialStage, "Initial stage does not exist in stages")
		end
	elseif initialStage then
		stageReport.Warn(initialStage, "initialStage is set, but no stages are defined")
	end
end

local function validateStagesSection(context, report)
	local stageReport = reporterFor(report, SECTIONS.Stages, "Stage")

	validateStages(context.Stages, stageReport)
	validateInitialStage(context.Stages, context.InitialStage, stageReport)
end

--------------------------------------------------------------------------------
-- Objectives: fields and inline triggers
--------------------------------------------------------------------------------

local function getObjectiveFieldTypes(Types)
	return {
		textKey = Types.String,
		trigger = Types.Table,
		amount = Types.Quantity,
		coop = Types.Boolean,
		hidden = Types.Boolean,
		onActivated = Types.TriggerID,
		onCanceled = Types.TriggerID,
		onProgress = Types.TriggerID,
		onCompleted = Types.TriggerID,
		onFailed = Types.TriggerID,
	}
end

local function validateObjectiveInlineTrigger(context, objectiveReport, validateSchema, objective, objectiveID)
	local trigger = objective.trigger
	if type(trigger) ~= "table" then
		return
	end

	if trigger.settings ~= nil then
		objectiveReport.Error(objectiveID, "Objective trigger must not have a 'settings' field")
	end
	if trigger.actions ~= nil then
		objectiveReport.Error(objectiveID, "Objective trigger must not have an 'actions' field")
	end

	-- Statistics triggers require a quantity, but an objective tracks its progress with its
	-- own 'amount' instead: the loader registers a managed objective, which never reads quantity.
	local parameters = trigger.parameters
	if context.TriggerTypesWithQuantity[trigger.type] and type(parameters) == "table" then
		if parameters.quantity ~= nil then
			objectiveReport.Warn(objectiveID, "Objective trigger 'quantity' is not supported and will be ignored")
		end
		parameters = table.copy(parameters)
		parameters.quantity = 1
	end

	validateSchema(
		objectiveReport,
		objectiveID,
		"Objective trigger",
		context.TriggerParameters,
		trigger.type,
		parameters
	)
end

local function validateObjectivesSection(context, report, parameterValidators, validateSchema)
	local objectiveReport = reporterFor(report, SECTIONS.Objectives, "Objective")
	local fieldTypes = getObjectiveFieldTypes(context.Types)

	for objectiveID, objective in pairs(context.Objectives) do
		if type(objectiveID) ~= "string" then
			objectiveReport.Error(objectiveID, "Objective ID must be a string, got " .. type(objectiveID))
		end

		if type(objective) ~= "table" then
			objectiveReport.Error(objectiveID, "Objective data must be a table, got " .. type(objective))
		else
			if not objective.textKey then
				objectiveReport.Error(objectiveID, "Objective missing textKey")
			elseif objective.textKey == "" then
				objectiveReport.Error(objectiveID, "Objective has empty textKey")
			end

			validateTypedFields(objectiveReport, objectiveID, parameterValidators, fieldTypes, objective, "Field")
			validateObjectiveInlineTrigger(context, objectiveReport, validateSchema, objective, objectiveID)
		end
	end
end

--------------------------------------------------------------------------------
-- Triggers: actions, settings and parameters
--------------------------------------------------------------------------------

local function getTriggerSettingTypes(Types)
	return {
		prerequisites = Types.TriggerIDs,
		repeating = Types.Boolean,
		maxRepeats = Types.Quantity,
		difficulties = Types.Table,
		coop = Types.Boolean,
		active = Types.Boolean,
		stages = Types.StageIDs,
	}
end

local function validateTriggerActions(context, triggerReport, trigger, triggerID)
	if trigger.actions ~= nil and type(trigger.actions) ~= "table" then
		triggerReport.Error(triggerID, "Trigger 'actions' field must be a table, got " .. type(trigger.actions))
		return
	end

	if table.isNilOrEmpty(trigger.actions) then
		triggerReport.Error(triggerID, "Trigger has no actions")
		return
	end

	for _, actionID in pairs(trigger.actions) do
		if actionID == "" then
			triggerReport.Error(triggerID, "Trigger has empty action ID")
		elseif not context.Actions[actionID] then
			triggerReport.Error(triggerID, "Trigger has invalid action ID", "Action: " .. tostring(actionID))
		end
	end
end

--- Settings are optional in raw missions; triggers_loader.lua applies the defaults later.
local function validateTriggerSettings(
	triggerReport,
	parameterValidators,
	settingTypes,
	validateTableType,
	trigger,
	triggerID
)
	local settings = trigger.settings
	if settings == nil then
		return
	end

	local settingsTypeResult = validateTableType(settings)
	if settingsTypeResult then
		triggerReport.Error(triggerID, settingsTypeResult[1].message, "Setting: settings")
		return
	end

	-- The TriggerIDs and StageIDs types also check that all prerequisite triggers and stages exists.
	validateTypedFields(triggerReport, triggerID, parameterValidators, settingTypes, settings, "Setting")

	if settings.maxRepeats and not settings.repeating then
		triggerReport.Error(triggerID, "Trigger has maxRepeats setting but is not set to repeating")
	end
end

local function validateTriggersSection(context, report, parameterValidators, validateSchema)
	local triggerReport = reporterFor(report, SECTIONS.Triggers, "Trigger")
	local settingTypes = getTriggerSettingTypes(context.Types)
	local validateTableType = parameterValidators[context.Types.Table]

	for triggerID, trigger in pairs(context.Triggers) do
		if type(trigger) ~= "table" then
			triggerReport.Error(triggerID, "Trigger data must be a table, got " .. type(trigger))
		else
			validateTriggerActions(context, triggerReport, trigger, triggerID)
			validateTriggerSettings(
				triggerReport,
				parameterValidators,
				settingTypes,
				validateTableType,
				trigger,
				triggerID
			)
			validateSchema(
				triggerReport,
				triggerID,
				"Trigger",
				context.TriggerParameters,
				trigger.type,
				trigger.parameters
			)
		end
	end
end

--------------------------------------------------------------------------------
-- Actions: parameters and whether a trigger uses them
--------------------------------------------------------------------------------

local function getAllActionIDsReferencedByTriggers(triggers)
	local allActionIDsReferencedByTriggers = {}
	for _, trigger in pairs(triggers) do
		if type(trigger) == "table" and type(trigger.actions) == "table" then
			for _, actionID in pairs(trigger.actions) do
				allActionIDsReferencedByTriggers[actionID] = true
			end
		end
	end
	return allActionIDsReferencedByTriggers
end

local function validateActionsSection(context, report, parameterValidators, validateSchema)
	local actionReport = reporterFor(report, SECTIONS.Actions, "Action")
	local allActionIDsReferencedByTriggers = getAllActionIDsReferencedByTriggers(context.Triggers)

	local unreferencedActionIDs = {}
	for actionID, action in pairs(context.Actions) do
		if not allActionIDsReferencedByTriggers[actionID] then
			unreferencedActionIDs[#unreferencedActionIDs + 1] = actionID
		end

		if type(action) ~= "table" then
			actionReport.Error(actionID, "Action data must be a table, got " .. type(action))
		else
			validateSchema(actionReport, actionID, "Action", context.ActionParameters, action.type, action.parameters)
		end
	end

	if not table.isEmpty(unreferencedActionIDs) then
		table.sort(unreferencedActionIDs)
		actionReport.SectionError(
			"Actions not referenced by any trigger: " .. table.concat(unreferencedActionIDs, ", ")
		)
	end
end

--------------------------------------------------------------------------------
-- Loadouts: the mission's own unit and feature loadouts
--
-- Loadouts in actions are validated as action parameters instead.
--------------------------------------------------------------------------------

local function validateLoadoutsSection(context, report, parameterValidators)
	local loadoutReport = reporterFor(report, SECTIONS.Loadouts, "Loadout")
	local Types = context.Types
	local loadouts = {
		{ name = "UnitLoadout", value = context.UnitLoadout, type = Types.UnitLoadout },
		{ name = "FeatureLoadout", value = context.FeatureLoadout, type = Types.FeatureLoadout },
	}

	for _, loadout in ipairs(loadouts) do
		for _, result in ipairs(parameterValidators[loadout.type](loadout.value) or {}) do
			loadoutReport.Error(loadout.name .. (result.parameterNameSuffix or ""), result.message)
		end
	end
end

--------------------------------------------------------------------------------

local function validate(context, report, parameterValidators)
	local validateSchema = createSchemaValidator(context, parameterValidators)

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
