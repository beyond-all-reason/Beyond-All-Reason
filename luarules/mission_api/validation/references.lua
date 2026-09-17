---
--- Checks references: objective events, actions, unit, feature and marker names,
--- and countdown IDs.
--- Malformed entries are skipped, as sections.lua already reports them.
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
local objectiveEventFields = { "onActivated", "onCanceled", "onProgress", "onCompleted", "onFailed" }

local function validateObjectiveEventReferences(context, report)
	local namedTriggerIDs = {}

	for objectiveID, objective in pairs(context.Objectives) do
		if type(objective) == "table" then
			for _, fieldName in ipairs(objectiveEventFields) do
				local triggerID = objective[fieldName]
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
-- Map marker name references
--------------------------------------------------------------------------------

--- Only the removing side is checked: a marker left standing for the rest of the
--- mission is ordinary, so an added marker that is never removed does not warn.
local function validateMarkerNameReferences(context, report)
	local actionTypes = context.ActionTypes
	local addedNames = {}
	local referencedNames = {}

	--- Only actions use marker names
	for actionID, action in pairs(context.Actions) do
		local parameters = parametersOf(action)
		if parameters and type(parameters.markerName) == "string" then
			if action.type == actionTypes.AddMapMarker then
				addedNames[parameters.markerName] = true
			elseif action.type == actionTypes.RemoveMapMarker then
				recordSource(referencedNames, parameters.markerName, "action " .. actionID)
			end
		end
	end

	reportUncreatedNames(report, "Marker name", addedNames, referencedNames)
end

--------------------------------------------------------------------------------
-- Unit and feature name references
--------------------------------------------------------------------------------

--- Unit names and feature names work the same way. A loadout, or an action carrying one
--- inline, gives units or features a name; other triggers and actions then use that name
--- to find them again. Only the wording differs between the two, so validateNameReferences
--- walks both, and takes one of these to tell it which words to use.
---@class NameKind
---@field label string names the kind in messages, "Unit name" or "Feature name"
---@field nameKey string the key holding the name, "unitName" or "featureName"
---@field nameType string the parameter type, so every parameter taking one can be found
---@field loadout table the mission's own UnitLoadout or FeatureLoadout
---@field loadoutLabel string cites that loadout in messages, "UnitLoadout" or "FeatureLoadout"
---@field loadoutParameter string the inline equivalent, "unitLoadout" or "featureLoadout"
---@field loadoutActionType string the action taking that inline loadout, SpawnUnits or CreateFeatures
---@field creatingActionTypes table<string, boolean> the actions that hand out the name. Any other
---       action naming it is looking up one already handed out.

--- A top level loadout entry creates every name it gives.
local function collectLoadoutNames(nameKind, createdNames)
	for index, entry in ipairs(nameKind.loadout) do
		if type(entry) == "table" and type(entry[nameKind.nameKey]) == "string" then
			recordSource(createdNames, entry[nameKind.nameKey], nameKind.loadoutLabel .. "[" .. index .. "]")
		end
	end
end

--- An action can carry a loadout inline, which creates names just as a top level one does.
local function collectInlineLoadoutNames(nameKind, actionID, parameters, createdNames)
	local entries = parameters[nameKind.loadoutParameter]
	if type(entries) ~= "table" then
		return
	end

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

--- IssueOrders action can name an order's target.
local function collectOrderNames(nameKind, actionID, parameters, referencedNames)
	if type(parameters.orders) ~= "table" then
		return
	end

	for _, order in ipairs(parameters.orders) do
		local orderParameters = order[2]
		if type(orderParameters) == "table" and type(orderParameters[nameKind.nameKey]) == "string" then
			recordSource(referencedNames, orderParameters[nameKind.nameKey], "action " .. actionID .. " (orders)")
		end
	end
end

--- Records every distinct name held by the entity's parameters of this kind. A trigger
--- can name several units at once, e.g. a passenger and the transport carrying it.
local function collectParameterNames(parameterNames, parameters, source, referencedNames)
	local seen = {}
	for _, parameterName in ipairs(parameterNames or {}) do
		local name = parameters[parameterName]
		if type(name) == "string" and not seen[name] then
			seen[name] = true
			recordSource(referencedNames, name, source)
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
				collectInlineLoadoutNames(nameKind, actionID, parameters, createdNames)
			end
			if action.type == context.ActionTypes.IssueOrders then
				collectOrderNames(nameKind, actionID, parameters, referencedNames)
			end

			if nameKind.creatingActionTypes[action.type] then
				local name = parameters[nameKind.nameKey]
				if type(name) == "string" then
					recordSource(createdNames, name, "action " .. actionID)
				end
			else
				collectParameterNames(
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
				referencingParameterNames[trigger.type],
				parameters,
				"trigger " .. triggerID,
				referencedNames
			)
		end
	end
end

--- An objective can hold a trigger inline, which refers to names as any other trigger does.
local function collectObjectiveTriggerNames(context, nameKind, referencedNames)
	local referencingParameterNames = getParameterNamesWithType(context.TriggerParameters, nameKind.nameType)

	for objectiveID, objective in pairs(context.Objectives) do
		local trigger = type(objective) == "table" and objective.trigger
		local parameters = parametersOf(trigger)
		if parameters then
			collectParameterNames(
				referencingParameterNames[trigger.type],
				parameters,
				"objective " .. objectiveID .. " (trigger)",
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

	for actionID, action in pairs(context.Actions) do
		local parameters = parametersOf(action)
		local countdownID = parameters and parameters.countdownID
		if type(countdownID) == "string" then
			if action.type == context.ActionTypes.AddCountdown then
				addedIDs[countdownID] = true
			elseif referencingActionTypes[action.type] then
				recordSource(referencedIDs, countdownID, "action " .. actionID)
			end
		end
	end

	local referencingTriggerTypes = getTypesWithParameterType(context.TriggerParameters, context.Types.CountdownID)
	for triggerID, trigger in pairs(context.Triggers) do
		local parameters = parametersOf(trigger)
		if parameters and referencingTriggerTypes[trigger.type] and type(parameters.countdownID) == "string" then
			recordSource(referencedIDs, parameters.countdownID, "trigger " .. triggerID)
		end
	end

	-- Objectives can hold a trigger inline, which refers to a countdown as any other trigger does.
	for objectiveID, objective in pairs(context.Objectives) do
		local parameters = parametersOf(type(objective) == "table" and objective.trigger)
		if parameters and type(parameters.countdownID) == "string" then
			recordSource(referencedIDs, parameters.countdownID, "objective " .. objectiveID .. " (trigger)")
		end
	end

	reportUncreatedNames(report, "Countdown", addedIDs, referencedIDs)
end

--------------------------------------------------------------------------------

local function validate(context, report)
	local actionTypes = context.ActionTypes
	local Types = context.Types

	validateActionReferences(context, report)
	validateObjectiveEventReferences(context, report)
	validateMarkerNameReferences(context, report)

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
end

return {
	Validate = validate,
}
