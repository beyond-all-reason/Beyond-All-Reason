---
--- Checks references: objective events, actions, unit, feature, marker and line names,
--- countdown IDs, cutscene IDs and variables.
--- Malformed entries are skipped, as sections.lua already reports them. A value that differs
--- by difficulty refers to each of its difficulties' values, see context.PossibleValues.
---

local SECTION = VFS.Include("luarules/mission_api/validation/report.lua").Sections.References
local schemaUtils = VFS.Include("luarules/mission_api/schema_utils.lua")
local getTypesWithParameterType = schemaUtils.GetTypesWithParameterType
local getParameterNamesWithType = schemaUtils.GetParameterNamesWithType

--------------------------------------------------------------------------------
-- Shared helpers
--------------------------------------------------------------------------------

local function parametersOf(actionOrTrigger)
	if type(actionOrTrigger) ~= "table" or type(actionOrTrigger.parameters) ~= "table" then
		return nil
	end
	return actionOrTrigger.parameters
end

local function recordSource(sourcesByName, name, source)
	local sources = table.ensureTable(sourcesByName, name)
	sources[#sources + 1] = source
end

local function describeSources(sources)
	table.sort(sources)
	return table.concat(sources, ", ")
end

--- A name nothing creates can never match, so unlike the unreferenced case below it is
--- always a mistake. It warns anyway: nothing breaks, and naming one before writing the
--- action that creates it is ordinary while a mission is being written.
local function reportUncreatedNames(report, label, createdNames, referencedNames)
	for name, sources in pairs(referencedNames) do
		if not createdNames[name] then
			report.Warn(
				SECTION,
				label,
				name,
				label .. " is referenced, but never created",
				"Referenced in: " .. describeSources(sources)
			)
		end
	end
end

--- A name nothing refers to is only a mistake for names whose sole purpose is to be referred
--- to later. A map marker left standing for the rest of the mission is ordinary, for instance.
local function reportUnreferencedNames(report, label, createdNames, referencedNames)
	for name, sources in pairs(createdNames) do
		if not referencedNames[name] then
			report.Warn(
				SECTION,
				label,
				name,
				label .. " is created, but never referenced",
				"Created in: " .. describeSources(sources)
			)
		end
	end
end

--------------------------------------------------------------------------------
-- Action references
--------------------------------------------------------------------------------

--- An action only ever runs because a trigger names it.
local function validateActionReferences(context, report)
	local referencedActionIDs = {}
	for _, trigger in pairs(context.Triggers) do
		if type(trigger) == "table" and type(trigger.actions) == "table" then
			for _, actionID in pairs(trigger.actions) do
				referencedActionIDs[actionID] = true
			end
		end
	end

	local unreferencedActionIDs = {}
	for actionID in pairs(context.Actions) do
		if type(actionID) == "string" and not referencedActionIDs[actionID] then
			unreferencedActionIDs[#unreferencedActionIDs + 1] = actionID
		end
	end

	if not table.isEmpty(unreferencedActionIDs) then
		table.sort(unreferencedActionIDs)
		report.Warn(
			SECTION,
			nil,
			nil,
			"Actions not referenced by any trigger: " .. table.concat(unreferencedActionIDs, ", ")
		)
	end
end

--------------------------------------------------------------------------------
-- Stage and objective references
--------------------------------------------------------------------------------

--- The objective fields that name an Event trigger, raised when the objective reaches
--- that state. sections.lua checks each names an existing trigger; here we check the
--- named trigger is an Event, and that every Event trigger has an owner to raise it.
local objectiveEventFields =
	{ "onActivated", "onCanceled", "onProgress", "onCompleted", "onFailed", "onHidden", "onShown" }

local function validateObjectiveEventReferences(context, report)
	local namedTriggerIDs = {}

	for objectiveID, objective in pairs(context.Objectives) do
		if type(objective) == "table" then
			for _, fieldName in ipairs(objectiveEventFields) do
				for _, triggerID in ipairs(context.PossibleValues(objective[fieldName])) do
					if type(triggerID) == "string" then
						namedTriggerIDs[triggerID] = true

						local trigger = context.Triggers[triggerID]
						if type(trigger) == "table" and trigger.type ~= context.TriggerTypes.Event then
							report.Error(
								SECTION,
								"Objective",
								objectiveID,
								"Objective event must name an Event trigger",
								"Field: " .. fieldName .. ", Trigger: " .. triggerID
							)
						end
					end
				end
			end
		end
	end

	for triggerID, trigger in pairs(context.Triggers) do
		if
			type(trigger) == "table"
			and trigger.type == context.TriggerTypes.Event
			and not namedTriggerIDs[triggerID]
		then
			report.Warn(SECTION, "Trigger", triggerID, "Event trigger has no owners, so it can never fire")
		end
	end
end

--------------------------------------------------------------------------------
-- Map marker and line name references
--------------------------------------------------------------------------------

--- Only actions use marker and line names. Only the removing side is checked: a marker or
--- line left standing for the rest of the mission is ordinary, so one that is never removed
--- does not warn.
local function validateDrawnNameReferences(context, report, label, nameKey, addingActionType, removingActionType)
	local addedNames = {}
	local referencedNames = {}

	for actionID, action in pairs(context.Actions) do
		local parameters = parametersOf(action)
		if parameters then
			for _, name in ipairs(context.PossibleValues(parameters[nameKey])) do
				if type(name) == "string" then
					if action.type == addingActionType then
						addedNames[name] = true
					elseif action.type == removingActionType then
						recordSource(referencedNames, name, "action " .. actionID)
					end
				end
			end
		end
	end

	reportUncreatedNames(report, label, addedNames, referencedNames)
end

--------------------------------------------------------------------------------
-- Unit and feature name references
--------------------------------------------------------------------------------

--- Unit names and feature names work the same way. A loadout, either top level or in an action,
--- gives units or features a name. Other triggers and actions then refer to that name. Only the
--- wording differs between the unit names and feature names, so validateNameReferences walks
--- both, and takes a NameKind to tell it which words to use.
---@class NameKind
---@field label string								  "Unit name" or "Feature name" to use in log messages
---@field nameKey string							  the key holding the name, "unitName" or "featureName"
---@field nameType string							  the parameter type, so every parameter taking one can be found
---@field loadout table								  the mission's top level UnitLoadout or FeatureLoadout
---@field loadoutLabel string                         "UnitLoadout" or "FeatureLoadout" to use in log messages
---@field loadoutParameter string 					  the action parameter "unitLoadout" or "featureLoadout"
---@field loadoutActionType string					  SpawnUnits or CreateFeatures
---@field creatingActionTypes table<string, boolean>  the action types that can create the name. Any other
---												      action naming it is referencing it instead.

--- A top level loadout entry creates every name it gives.
local function collectLoadoutNames(nameKind, createdNames)
	for index, entry in ipairs(nameKind.loadout) do
		if type(entry) == "table" and type(entry[nameKind.nameKey]) == "string" then
			recordSource(createdNames, entry[nameKind.nameKey], nameKind.loadoutLabel .. "[" .. index .. "]")
		end
	end
end

--- An action can carry a loadout inline, which creates names just as a top level one does.
local function collectInlineLoadoutNames(context, nameKind, actionID, parameters, createdNames)
	for _, entries in ipairs(context.PossibleValues(parameters[nameKind.loadoutParameter])) do
		if type(entries) == "table" then
			for index, entry in ipairs(entries) do
				if type(entry) == "table" and type(entry[nameKind.nameKey]) == "string" then
					recordSource(
						createdNames,
						entry[nameKind.nameKey],
						"action " .. actionID .. " (" .. nameKind.loadoutParameter .. "[" .. index .. "])"
					)
				end
			end
		end
	end
end

--- IssueOrders action can name an order's target.
local function collectOrderNames(context, nameKind, actionID, parameters, referencedNames)
	for _, orders in ipairs(context.PossibleValues(parameters.orders)) do
		if type(orders) == "table" then
			for _, order in ipairs(orders) do
				local orderParameters = type(order) == "table" and order[2]
				if type(orderParameters) == "table" and type(orderParameters[nameKind.nameKey]) == "string" then
					recordSource(
						referencedNames,
						orderParameters[nameKind.nameKey],
						"action " .. actionID .. " (orders)"
					)
				end
			end
		end
	end
end

--- Records every distinct name held by the entity's parameters of this kind. A trigger
--- can name several units at once, e.g. a passenger and the transport carrying it.
local function collectParameterNames(context, parameterNames, parameters, source, referencedNames)
	local seen = {}
	for _, parameterName in ipairs(parameterNames or {}) do
		for _, name in ipairs(context.PossibleValues(parameters[parameterName])) do
			if type(name) == "string" and not seen[name] then
				seen[name] = true
				recordSource(referencedNames, name, source)
			end
		end
	end
end

--- An action either creates a name or refers to one, never both.
local function collectActionNames(context, nameKind, createdNames, referencedNames)
	-- Any action taking the name as a parameter references it, unless it creates it.
	local referencingParameterNames = getParameterNamesWithType(context.ActionParameters, nameKind.nameType)
	for actionType in pairs(nameKind.creatingActionTypes) do
		referencingParameterNames[actionType] = nil
	end

	for actionID, action in pairs(context.Actions) do
		local parameters = parametersOf(action)
		if parameters then
			if action.type == nameKind.loadoutActionType then
				collectInlineLoadoutNames(context, nameKind, actionID, parameters, createdNames)
			end
			if action.type == context.ActionTypes.IssueOrders then
				collectOrderNames(context, nameKind, actionID, parameters, referencedNames)
			end

			if nameKind.creatingActionTypes[action.type] then
				for _, name in ipairs(context.PossibleValues(parameters[nameKind.nameKey])) do
					if type(name) == "string" then
						recordSource(createdNames, name, "action " .. actionID)
					end
				end
			else
				collectParameterNames(
					context,
					referencingParameterNames[action.type],
					parameters,
					"action " .. actionID,
					referencedNames
				)
			end
		end
	end
end

--- Triggers only ever refer to names, never create them.
local function collectTriggerNames(context, nameKind, referencedNames)
	local referencingParameterNames = getParameterNamesWithType(context.TriggerParameters, nameKind.nameType)

	for triggerID, trigger in pairs(context.Triggers) do
		local parameters = parametersOf(trigger)
		if parameters then
			collectParameterNames(
				context,
				referencingParameterNames[trigger.type],
				parameters,
				"trigger " .. triggerID,
				referencedNames
			)
		end
	end
end

--- An objective holds its condition inline, which refers to names as any trigger does.
local function collectObjectiveTriggerNames(context, nameKind, referencedNames)
	local referencingParameterNames = getParameterNamesWithType(context.TriggerParameters, nameKind.nameType)

	for objectiveID, objective in pairs(context.Objectives) do
		local parameters = parametersOf(objective)
		if parameters then
			collectParameterNames(
				context,
				referencingParameterNames[objective.type],
				parameters,
				"objective " .. objectiveID .. " (condition)",
				referencedNames
			)
		end
	end
end

--- For both unit and feature names
---@param nameKind NameKind
local function validateNameReferences(context, report, nameKind)
	local createdNames = {}
	local referencedNames = {}

	collectLoadoutNames(nameKind, createdNames)
	collectActionNames(context, nameKind, createdNames, referencedNames)
	collectTriggerNames(context, nameKind, referencedNames)
	collectObjectiveTriggerNames(context, nameKind, referencedNames)

	reportUncreatedNames(report, nameKind.label, createdNames, referencedNames)
	reportUnreferencedNames(report, nameKind.label, createdNames, referencedNames)
end

--------------------------------------------------------------------------------
-- Countdown ID references
--------------------------------------------------------------------------------

--- A countdown that is added and then simply left to run out is fine, so unlike the
--- names above there is no warning for one that is added but never referenced.
local function validateCountdownIDReferences(context, report)
	local addedIDs = {}
	local referencedIDs = {}

	-- AddCountdown takes a countdownID too, but it creates the countdown rather than referring to one.
	local referencingActionTypes = getTypesWithParameterType(context.ActionParameters, context.Types.CountdownID)
	referencingActionTypes[context.ActionTypes.AddCountdown] = nil

	local function countdownIDsOf(parameters)
		local countdownIDs = {}
		for _, countdownID in ipairs(context.PossibleValues(parameters and parameters.countdownID)) do
			if type(countdownID) == "string" then
				countdownIDs[#countdownIDs + 1] = countdownID
			end
		end
		return countdownIDs
	end

	for actionID, action in pairs(context.Actions) do
		for _, countdownID in ipairs(countdownIDsOf(parametersOf(action))) do
			if action.type == context.ActionTypes.AddCountdown then
				addedIDs[countdownID] = true
			elseif referencingActionTypes[action.type] then
				recordSource(referencedIDs, countdownID, "action " .. actionID)
			end
		end
	end

	local referencingTriggerTypes = getTypesWithParameterType(context.TriggerParameters, context.Types.CountdownID)
	for triggerID, trigger in pairs(context.Triggers) do
		if referencingTriggerTypes[type(trigger) == "table" and trigger.type] then
			for _, countdownID in ipairs(countdownIDsOf(parametersOf(trigger))) do
				recordSource(referencedIDs, countdownID, "trigger " .. triggerID)
			end
		end
	end

	-- Objectives hold their condition inline, which refers to a countdown as any trigger does.
	for objectiveID, objective in pairs(context.Objectives) do
		for _, countdownID in ipairs(countdownIDsOf(parametersOf(objective))) do
			recordSource(referencedIDs, countdownID, "objective " .. objectiveID .. " (condition)")
		end
	end

	reportUncreatedNames(report, "Countdown", addedIDs, referencedIDs)
end

--------------------------------------------------------------------------------
-- Cutscene ID references
--------------------------------------------------------------------------------

--- Unlike the names above, a cutscene is defined up front, so starting one that is not
--- defined would fail at runtime.
local function validateCutsceneIDReferences(context, report)
	local referencedIDs = {}

	local function recordCutsceneIDs(parameters, source)
		for _, cutsceneID in ipairs(context.PossibleValues(parameters and parameters.cutsceneID)) do
			if type(cutsceneID) == "string" then
				recordSource(referencedIDs, cutsceneID, source)
			end
		end
	end

	local referencingActionTypes = getTypesWithParameterType(context.ActionParameters, context.Types.CutsceneID)
	for actionID, action in pairs(context.Actions) do
		if referencingActionTypes[type(action) == "table" and action.type] then
			recordCutsceneIDs(parametersOf(action), "action " .. actionID)
		end
	end

	local referencingTriggerTypes = getTypesWithParameterType(context.TriggerParameters, context.Types.CutsceneID)
	for triggerID, trigger in pairs(context.Triggers) do
		if referencingTriggerTypes[type(trigger) == "table" and trigger.type] then
			recordCutsceneIDs(parametersOf(trigger), "trigger " .. triggerID)
		end
	end
	for objectiveID, objective in pairs(context.Objectives) do
		if referencingTriggerTypes[type(objective) == "table" and objective.type] then
			recordCutsceneIDs(parametersOf(objective), "objective " .. objectiveID .. " (condition)")
		end
	end

	for cutsceneID, sources in pairs(referencedIDs) do
		if context.Cutscenes[cutsceneID] == nil then
			report.Error(
				SECTION,
				"Cutscene",
				cutsceneID,
				"Cutscene is referenced, but not defined in Cutscenes",
				"Referenced in: " .. describeSources(sources)
			)
		end
	end
	for cutsceneID in pairs(context.Cutscenes) do
		if referencedIDs[cutsceneID] == nil then
			report.Warn(SECTION, "Cutscene", cutsceneID, "Cutscene is defined, but never referenced")
		end
	end
end

--------------------------------------------------------------------------------
-- Variable references
--------------------------------------------------------------------------------

--- Only the startscript sets variables before the mission starts. A value that reads an unset
--- variable can't be checked, and is missing until an action writes the variable, which may
--- well be intended. So it warns rather than errors.
local function validateVariableReferences(context, report)
	local referencedKeys = {}

	local function recordKeys(values, source, skippedField)
		for name, value in pairs(type(values) == "table" and values or {}) do
			if name ~= skippedField then
				context.CallOnVariableKeys(value, function(key)
					if type(key) == "string" then
						recordSource(referencedKeys, key, source .. " (" .. tostring(name) .. ")")
					end
				end)
			end
		end
	end

	for triggerID, trigger in pairs(context.Triggers) do
		recordKeys(parametersOf(trigger), "trigger " .. triggerID)
		if type(trigger) == "table" then
			recordKeys(
				{ count = trigger.count, atLeast = trigger.atLeast, atMost = trigger.atMost },
				"trigger " .. triggerID
			)
		end
	end
	for actionID, action in pairs(context.Actions) do
		recordKeys(parametersOf(action), "action " .. actionID)
	end
	for objectiveID, objective in pairs(context.Objectives) do
		if type(objective) == "table" then
			recordKeys(objective, "objective " .. objectiveID, "parameters")
			recordKeys(parametersOf(objective), "objective " .. objectiveID .. " condition")
		end
	end

	for key, sources in pairs(referencedKeys) do
		if context.Variables[key] == nil then
			report.Warn(
				SECTION,
				"Variable",
				key,
				"Variable has no value at the start of the mission",
				"Referenced in: " .. describeSources(sources)
			)
		end
	end
end

--------------------------------------------------------------------------------

local function validate(context, report)
	local actionTypes = context.ActionTypes
	local Types = context.Types

	validateActionReferences(context, report)
	validateObjectiveEventReferences(context, report)
	validateDrawnNameReferences(
		context,
		report,
		"Marker name",
		"markerName",
		actionTypes.AddMapMarker,
		actionTypes.RemoveMapMarker
	)
	validateDrawnNameReferences(context, report, "Line name", "lineName", actionTypes.DrawLines, actionTypes.RemoveLine)

	validateNameReferences(context, report, {
		label = "Unit name",
		nameKey = "unitName",
		nameType = Types.UnitName,
		loadout = context.UnitLoadout,
		loadoutLabel = "UnitLoadout",
		loadoutParameter = "unitLoadout",
		loadoutActionType = actionTypes.SpawnUnits,
		creatingActionTypes = { [actionTypes.SpawnUnits] = true, [actionTypes.NameUnits] = true },
	})

	validateNameReferences(context, report, {
		label = "Feature name",
		nameKey = "featureName",
		nameType = Types.FeatureName,
		loadout = context.FeatureLoadout,
		loadoutLabel = "FeatureLoadout",
		loadoutParameter = "featureLoadout",
		loadoutActionType = actionTypes.CreateFeatures,
		creatingActionTypes = { [actionTypes.CreateFeatures] = true },
	})

	validateCountdownIDReferences(context, report)
	validateCutsceneIDReferences(context, report)
	validateVariableReferences(context, report)
end

return {
	Validate = validate,
}
