---
--- Validation of a mission's top level sections: stages, objectives, triggers, actions, cutscenes, and loadouts.
---

local SECTIONS = VFS.Include("luarules/mission_api/validation/report.lua").Sections
local stageFieldTypes = VFS.Include("luarules/mission_api/stages_schema.lua").Settings
local objectiveFieldTypes = VFS.Include("luarules/mission_api/objectives_schema.lua").Settings
local triggerSettingTypes = VFS.Include("luarules/mission_api/triggers_schema.lua").Settings
local cutsceneFieldTypes = VFS.Include("luarules/mission_api/cutscenes_schema.lua").Settings
local schemaUtils = VFS.Include("luarules/mission_api/schema_utils.lua")
local getTypesWithParameterType = schemaUtils.GetTypesWithParameterType
local getTypesWithParameterName = schemaUtils.GetTypesWithParameterName
local attributeDefinitions = require("luarules/gadgets/include/unit_attributes")
local attributeRules = require("luarules/gadgets/include/unit_attributes_rules")

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

--- @param validateValue function(valueType, value, fieldName): results, see createValueValidators
local function validateTypedFields(reporter, id, validateValue, fieldTypes, values, valueLabel)
	for fieldName, fieldType in pairs(fieldTypes) do
		local value = values[fieldName]
		if value ~= nil then
			for _, result in ipairs(validateValue(fieldType, value, fieldName)) do
				local details = valueLabel .. ": " .. fieldName .. (result.parameterNameSuffix or "")
				local reportResult = result.isWarning and reporter.Warn or reporter.Error
				reportResult(id, result.message, details)
			end
		end
	end
end

--- Returns two value validators, each returning a list of results: one for values that must
--- be given as is, and one that also accepts { difficulties = { <difficultyName> = <value> } },
--- which difficulty.lua resolves once the difficulty is known. Every difficulty's value is
--- validated, including those under an invalid difficulty name.
local function createValueValidators(context, parameterValidators)
	local knownDifficulties = context.Enums[context.Types.Difficulty]
	local validateTableType = parameterValidators[context.Types.Table]

	local function validateValue(valueType, value)
		return parameterValidators[valueType](value) or {}
	end

	local function validateDifficulties(valueType, value)
		local results = {}
		for key in pairs(value) do
			if key ~= "difficulties" then
				results[#results + 1] = {
					message = "Difficulties parameter must have no keys other than 'difficulties', got: "
						.. tostring(key),
				}
			end
		end

		local difficulties = value.difficulties
		local typeResult = validateTableType(difficulties)
		if typeResult then
			results[#results + 1] = { message = typeResult[1].message, parameterNameSuffix = ".difficulties" }
			return results
		end
		if next(difficulties) == nil then
			results[#results + 1] = { message = "Difficulties table is empty", parameterNameSuffix = ".difficulties" }
			return results
		end

		for difficultyName, difficultyValue in pairs(difficulties) do
			local suffix = ".difficulties." .. tostring(difficultyName)
			if not knownDifficulties[difficultyName] then
				results[#results + 1] =
					{ message = "Invalid difficulty: " .. tostring(difficultyName), parameterNameSuffix = suffix }
			end
			-- A nested difficulties table is rejected by the value's own validator.
			for _, result in ipairs(validateValue(valueType, difficultyValue)) do
				results[#results + 1] = {
					message = result.message,
					parameterNameSuffix = suffix .. (result.parameterNameSuffix or ""),
					isWarning = result.isWarning,
				}
			end
		end
		return results
	end

	local function validateValueWithDifficulties(valueType, value)
		if context.IsDifficultiesTable(value) then
			return validateDifficulties(valueType, value)
		end
		return validateValue(valueType, value)
	end

	return validateValue, validateValueWithDifficulties
end

local function createEntryValidator(context, validateValue)
	return function(reporter, id, data)
		for _, result in ipairs(validateValue(context.Types.String, id)) do
			reporter.Error(id, result.message, "Field: ID")
		end

		local dataResults = validateValue(context.Types.Table, data)
		for _, result in ipairs(dataResults) do
			reporter.Error(id, result.message, "Field: data")
		end
		return #dataResults == 0
	end
end

--------------------------------------------------------------------------------
-- Schema driven parameter validation, shared by triggers, actions and objective triggers
--------------------------------------------------------------------------------

--- Every parameter may differ by difficulty.
local function createSchemaValidator(context, parameterValidators, validateValueWithDifficulties)
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
				for _, result in ipairs(validateValueWithDifficulties(parameter.type, value)) do
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

local function validateStages(stages, stageReport, validateValue, validateEntry)
	for stageID, stageData in pairs(stages) do
		if validateEntry(stageReport, stageID, stageData) then
			if stageData.objectives == nil then
				stageReport.Error(stageID, "Stage missing 'objectives' field")
			else
				-- A stage with no objectives is valid
				validateTypedFields(stageReport, stageID, validateValue, stageFieldTypes, stageData, "Field")
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

local function validateStagesSection(context, report, validateValue, validateEntry)
	local stageReport = reporterFor(report, SECTIONS.Stages, "Stage")

	validateStages(context.Stages, stageReport, validateValue, validateEntry)
	validateInitialStage(context.Stages, context.InitialStage, stageReport)
end

--------------------------------------------------------------------------------
-- Stockpile triggers, as triggers and as objective triggers
--------------------------------------------------------------------------------

--- A unit def known only by name, as in the standalone validator, has no weapons to check.
local function hasStockpileWeapon(unitDef)
	if type(unitDef.weapons) ~= "table" then
		return true
	end
	for _, weapon in ipairs(unitDef.weapons) do
		if WeaponDefs[weapon.weaponDef].stockpile then
			return true
		end
	end
	return false
end

-- A unit def without a stockpiling weapon never changes its stockpile, so the trigger could never fire.
local function validateStockpileTrigger(context, reporter, id, trigger)
	local triggerTypes = context.TriggerTypes
	if trigger.type ~= triggerTypes.StockpileCount and trigger.type ~= triggerTypes.StockpileProgress then
		return
	end
	if type(trigger.parameters) ~= "table" then
		return
	end

	for _, unitDefName in ipairs(context.PossibleValues(trigger.parameters.unitDefName)) do
		local unitDef = type(unitDefName) == "string" and UnitDefNames[unitDefName] or nil
		if unitDef and not hasStockpileWeapon(unitDef) then
			reporter.Error(id, "Unit '" .. unitDefName .. "' has no stockpiling weapon", "Parameter: unitDefName")
		end
	end
end

--------------------------------------------------------------------------------
-- Objectives: fields and inline triggers
--------------------------------------------------------------------------------

local function validateObjectiveInlineTrigger(
	context,
	objectiveReport,
	validateSchema,
	statisticsTriggerTypes,
	objective,
	objectiveID
)
	local trigger = objective.trigger
	if type(trigger) ~= "table" or context.IsDifficultiesTable(trigger) then
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
	if statisticsTriggerTypes[trigger.type] and type(parameters) == "table" then
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
	validateStockpileTrigger(context, objectiveReport, objectiveID, trigger)
end

local function validateObjectivesSection(context, report, validateValueWithDifficulties, validateEntry, validateSchema)
	local objectiveReport = reporterFor(report, SECTIONS.Objectives, "Objective")
	local statisticsTriggerTypes = getTypesWithParameterType(context.TriggerParameters, context.Types.Quantity)

	-- The inline trigger is registered before the difficulty is resolved, so it can't vary.
	local function validateField(fieldType, value, fieldName)
		if fieldName == "trigger" and context.IsDifficultiesTable(value) then
			return { { message = "Objective 'trigger' field does not support difficulties" } }
		end
		return validateValueWithDifficulties(fieldType, value)
	end

	for objectiveID, objective in pairs(context.Objectives) do
		if validateEntry(objectiveReport, objectiveID, objective) then
			if not objective.textKey then
				objectiveReport.Error(objectiveID, "Objective missing textKey")
			elseif objective.textKey == "" then
				objectiveReport.Error(objectiveID, "Objective has empty textKey")
			end

			validateTypedFields(objectiveReport, objectiveID, validateField, objectiveFieldTypes, objective, "Field")
			validateObjectiveInlineTrigger(
				context,
				objectiveReport,
				validateSchema,
				statisticsTriggerTypes,
				objective,
				objectiveID
			)
		end
	end
end

--------------------------------------------------------------------------------
-- Triggers: actions, settings and parameters
--------------------------------------------------------------------------------

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
local function validateTriggerSettings(triggerReport, validateValue, validateTableType, trigger, triggerID)
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
	validateTypedFields(triggerReport, triggerID, validateValue, triggerSettingTypes, settings, "Setting")

	if settings.maxRepeats and not settings.repeating then
		triggerReport.Error(triggerID, "Trigger has maxRepeats setting but is not set to repeating")
	end
end

local function validateTriggersSection(
	context,
	report,
	parameterValidators,
	validateValue,
	validateEntry,
	validateSchema
)
	local triggerReport = reporterFor(report, SECTIONS.Triggers, "Trigger")
	local validateTableType = parameterValidators[context.Types.Table]

	for triggerID, trigger in pairs(context.Triggers) do
		if validateEntry(triggerReport, triggerID, trigger) then
			validateTriggerActions(context, triggerReport, trigger, triggerID)
			validateTriggerSettings(triggerReport, validateValue, validateTableType, trigger, triggerID)
			validateSchema(
				triggerReport,
				triggerID,
				"Trigger",
				context.TriggerParameters,
				trigger.type,
				trigger.parameters
			)
			validateStockpileTrigger(context, triggerReport, triggerID, trigger)
		end
	end
end

--------------------------------------------------------------------------------
-- Actions: parameters, and whether an attribute suits the value and unit def it is set with
--------------------------------------------------------------------------------

--- Unknown attributes and malformed weapons are reported by their parameter validators.
--- Each of a value's difficulties is checked, as any of them may be the one used.
local function createAttributeActionValidator(context, parameterValidators)
	local Types = context.Types
	local actionParameters = context.ActionParameters
	local unitAttributeActions = getTypesWithParameterType(actionParameters, Types.UnitAttribute)
	local weaponAttributeActions = getTypesWithParameterType(actionParameters, Types.WeaponAttribute)
	local setActions = getTypesWithParameterName(actionParameters, "value")
	local modifierActions = getTypesWithParameterName(actionParameters, "multiplier")
	local unitScopeActions = getTypesWithParameterType(actionParameters, Types.UnitName)
	local validateWeapon = parameterValidators[Types.WeaponNumber]
	local explosions = context.Enums[Types.WeaponNumber]

	local function getUnitCheck(actionType)
		if setActions[actionType] then
			return "value",
				unitScopeActions[actionType] and attributeRules.CanSetUnitAttribute
					or attributeRules.CanSetUnitDefAttribute
		elseif modifierActions[actionType] then
			return "multiplier",
				unitScopeActions[actionType] and attributeRules.CanSetUnitModifier
					or attributeRules.CanSetUnitDefModifier
		end
	end

	local function getWeaponCheck(actionType)
		if setActions[actionType] then
			return "value", attributeRules.CanSetUnitWeaponAttribute
		elseif modifierActions[actionType] then
			return "multiplier", attributeRules.CanSetUnitWeaponModifier
		end
	end

	return function(actionReport, actionID, action)
		local actionType = action.type
		local parameters = type(action.parameters) == "table" and action.parameters or {}
		local attribute = parameters.attribute
		local unitDefName = parameters.unitDefName
		local unitDef = type(unitDefName) == "string" and UnitDefNames[unitDefName] or nil

		local unitEntry = unitAttributeActions[actionType] and attributeDefinitions.UnitAttributeDefinitions[attribute]
		local weaponEntry = weaponAttributeActions[actionType]
			and attributeDefinitions.WeaponAttributeDefinitions[attribute]

		local valueName, check
		if unitEntry then
			local canSet
			valueName, canSet = getUnitCheck(actionType)
			check = canSet and function(value)
				return canSet(unitEntry, value)
			end
		elseif weaponEntry then
			local canSet
			valueName, canSet = getWeaponCheck(actionType)
			local weapon = parameters.weapon
			if weapon ~= nil and validateWeapon(weapon) then
				weapon = nil
			end
			weapon = explosions[weapon] or weapon
			check = canSet and function(value)
				return canSet(weaponEntry, value, weapon, unitDef)
			end
		end

		if check then
			for _, value in ipairs(context.PossibleValues(parameters[valueName])) do
				local ok, reason, parameter = check(value)
				if not ok then
					local kind = unitEntry and "Unit" or "Weapon"
					actionReport.Error(
						actionID,
						kind .. " attribute '" .. attribute .. "' " .. reason,
						"Parameter: " .. parameter
					)
				end
			end
		end

		if unitEntry and unitDef then
			local affects, warning = attributeRules.AffectsUnitDef(unitEntry, unitDef)
			if not affects then
				actionReport.Warn(actionID, "Unit attribute '" .. attribute .. "' " .. warning)
			end
		end
	end
end

-- Recoil cannot move an AI to another team, so ChangeTeam moves only the players of oldTeam.
local function validateChangeTeamAction(context, actionReport, actionID, action)
	if action.type ~= context.ActionTypes.ChangeTeam or type(action.parameters) ~= "table" then
		return
	end

	for _, oldTeamName in ipairs(context.PossibleValues(action.parameters.oldTeam)) do
		local oldTeamID = type(oldTeamName) == "string" and context.Teams[oldTeamName]
		if oldTeamID then
			local _, _, _, hasAI = Spring.GetTeamInfo(oldTeamID, false)
			---@cast hasAI +boolean
			if hasAI then
				actionReport.Warn(
					actionID,
					"ChangeTeam moves players only, the AI of team '" .. oldTeamName .. "' stays"
				)
			end
		end
	end
end

local function validateActionsSection(context, report, parameterValidators, validateEntry, validateSchema)
	local actionReport = reporterFor(report, SECTIONS.Actions, "Action")
	local validateAttributeAction = createAttributeActionValidator(context, parameterValidators)

	for actionID, action in pairs(context.Actions) do
		if validateEntry(actionReport, actionID, action) then
			validateSchema(actionReport, actionID, "Action", context.ActionParameters, action.type, action.parameters)
			validateAttributeAction(actionReport, actionID, action)
			validateChangeTeamAction(context, actionReport, actionID, action)
		end
	end
end

--------------------------------------------------------------------------------
-- Cutscenes: a video or a scripted control session, started by actions
--------------------------------------------------------------------------------

local function validateCutscenesSection(context, report, validateValueWithDifficulties, validateEntry)
	local cutsceneReport = reporterFor(report, SECTIONS.Cutscenes, "Cutscene")

	for cutsceneID, cutscene in pairs(context.Cutscenes) do
		if validateEntry(cutsceneReport, cutsceneID, cutscene) then
			if (cutscene.videoFile == nil) == (cutscene.script == nil) then
				cutsceneReport.Error(cutsceneID, "Cutscene must have either a videoFile or a script, but not both")
			end

			validateTypedFields(
				cutsceneReport,
				cutsceneID,
				validateValueWithDifficulties,
				cutsceneFieldTypes,
				cutscene,
				"Field"
			)
		end
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
	local validateValue, validateValueWithDifficulties = createValueValidators(context, parameterValidators)
	local validateEntry = createEntryValidator(context, validateValue)
	local validateSchema = createSchemaValidator(context, parameterValidators, validateValueWithDifficulties)

	-- Same order here as in the report:
	validateStagesSection(context, report, validateValue, validateEntry)
	validateObjectivesSection(context, report, validateValueWithDifficulties, validateEntry, validateSchema)
	validateTriggersSection(context, report, parameterValidators, validateValue, validateEntry, validateSchema)
	validateActionsSection(context, report, parameterValidators, validateEntry, validateSchema)
	validateCutscenesSection(context, report, validateValueWithDifficulties, validateEntry)
	validateLoadoutsSection(context, report, parameterValidators)
end

return {
	Validate = validate,
}
