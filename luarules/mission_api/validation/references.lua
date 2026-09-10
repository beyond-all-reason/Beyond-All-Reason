---
--- Checks references: objectives in a stage, nextStage, objective events, and unit, feature and marker names.
--- Malformed entries are skipped, as sections.lua already reports them.
---

local SECTION = VFS.Include("luarules/mission_api/validation/report.lua").Sections.References
local getTypesWithParameterType = VFS.Include("luarules/mission_api/schema_utils.lua").GetTypesWithParameterType

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

local function reportUnmatchedNames(report, label, createdNames, referencedNames)
	local function describeSources(sources)
		table.sort(sources)
		return table.concat(sources, ", ")
	end

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
-- Stage and objective references
--------------------------------------------------------------------------------

local function validateStageObjectiveReferences(context, report)
	for stageID, stageData in pairs(context.Stages) do
		if type(stageData) == "table" and type(stageData.objectives) == "table" then
			for _, objectiveID in ipairs(stageData.objectives) do
				if type(objectiveID) == "string" and context.Objectives[objectiveID] == nil then
					report.Error(
						SECTION,
						"Stage",
						stageID,
						"Stage refers to non-existent objective",
						"Objective: " .. objectiveID
					)
				end
			end
		end
	end
end

local function validateObjectiveNextStageReferences(context, report)
	for objectiveID, objective in pairs(context.Objectives) do
		if type(objective) == "table" and objective.nextStage ~= nil then
			if type(objective.nextStage) ~= "string" then
				report.Error(
					SECTION,
					"Objective",
					objectiveID,
					"Unexpected parameter type, expected string, got " .. type(objective.nextStage),
					"Field: nextStage"
				)
			elseif context.Stages[objective.nextStage] == nil then
				report.Error(
					SECTION,
					"Objective",
					objectiveID,
					"Objective references non-existent nextStage",
					"Stage: " .. objective.nextStage
				)
			end
		end
	end
end

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
-- Marker name references
--------------------------------------------------------------------------------

local function validateMarkerNameReferences(context, report)
	local actionTypes = context.ActionTypes
	local createdNames = {}
	local referencedNames = {}

	--- Only actions use marker names
	for actionID, action in pairs(context.Actions) do
		local parameters = parametersOf(action)
		if parameters and type(parameters.name) == "string" then
			if action.type == actionTypes.AddMarker then
				recordSource(createdNames, parameters.name, "action " .. actionID)
			elseif action.type == actionTypes.EraseMarker then
				recordSource(referencedNames, parameters.name, "action " .. actionID)
			end
		end
	end

	reportUnmatchedNames(report, "Marker name", createdNames, referencedNames)
end

--------------------------------------------------------------------------------
-- Unit and feature name references
--------------------------------------------------------------------------------

--- One kind of name a mission creates and refers to. Unit names and feature names
--- differ only in the fields below, so a single walker checks both.
---@class NameKind
---@field label string how the name is described in messages, e.g. "Unit name"
---@field nameKey string the key holding the name, on loadout entries and parameters alike
---@field nameType string the parameter type, used to find the action and trigger types taking one
---@field loadout table the mission's top level loadout for this kind
---@field loadoutLabel string how a top level loadout entry is cited, e.g. "UnitLoadout"
---@field loadoutParameter string the inline loadout parameter on the action creating from one
---@field loadoutActionType string the action type carrying an inline loadout
---@field creatingActionTypes table<string, boolean> action types creating the name, rather than referring to it

--- Shared walker for unit and feature names, which can be created and referenced by
--- loadouts, actions, triggers and the inline triggers of objectives.
---@param nameKind NameKind
local function validateNameReferences(context, report, nameKind)
	local nameKey = nameKind.nameKey
	local createdNames = {}
	local referencedNames = {}

	-- Any action taking the name as a parameter references it, unless it creates it.
	local referencingActionTypes = getTypesWithParameterType(context.ActionParameters, nameKind.nameType)
	for actionType in pairs(nameKind.creatingActionTypes) do
		referencingActionTypes[actionType] = nil
	end

	-- Loadout entries with a name count as creating that name.
	for index, entry in ipairs(nameKind.loadout) do
		if type(entry) == "table" and type(entry[nameKey]) == "string" then
			recordSource(createdNames, entry[nameKey], nameKind.loadoutLabel .. "[" .. index .. "]")
		end
	end

	for actionID, action in pairs(context.Actions) do
		local parameters = parametersOf(action)
		if parameters then
			-- Actions with an inline loadout also create names.
			if action.type == nameKind.loadoutActionType and type(parameters[nameKind.loadoutParameter]) == "table" then
				for index, entry in ipairs(parameters[nameKind.loadoutParameter]) do
					if type(entry) == "table" and type(entry[nameKey]) == "string" then
						recordSource(
							createdNames,
							entry[nameKey],
							"action " .. actionID .. " (" .. nameKind.loadoutParameter .. "[" .. index .. "])"
						)
					end
				end
			end

			-- Orders on IssueOrders actions can also refer to names.
			if action.type == context.ActionTypes.IssueOrders and type(parameters.orders) == "table" then
				for _, order in ipairs(parameters.orders) do
					local orderParameters = order[2]
					if type(orderParameters) == "table" and type(orderParameters[nameKey]) == "string" then
						recordSource(referencedNames, orderParameters[nameKey], "action " .. actionID .. " (orders)")
					end
				end
			end

			local name = parameters[nameKey]
			if type(name) == "string" then
				if nameKind.creatingActionTypes[action.type] then
					recordSource(createdNames, name, "action " .. actionID)
				elseif referencingActionTypes[action.type] then
					recordSource(referencedNames, name, "action " .. actionID)
				end
			end
		end
	end

	-- Triggers only ever reference names.
	local referencingTriggerTypes = getTypesWithParameterType(context.TriggerParameters, nameKind.nameType)
	for triggerID, trigger in pairs(context.Triggers) do
		local parameters = parametersOf(trigger)
		if parameters and referencingTriggerTypes[trigger.type] and type(parameters[nameKey]) == "string" then
			recordSource(referencedNames, parameters[nameKey], "trigger " .. triggerID)
		end
	end

	-- Objective inline triggers can also refer to names.
	for objectiveID, objective in pairs(context.Objectives) do
		local parameters = parametersOf(type(objective) == "table" and objective.trigger)
		if parameters and type(parameters[nameKey]) == "string" then
			recordSource(referencedNames, parameters[nameKey], "objective " .. objectiveID .. " (trigger)")
		end
	end

	reportUnmatchedNames(report, nameKind.label, createdNames, referencedNames)
end

--------------------------------------------------------------------------------

local function validate(context, report)
	local actionTypes = context.ActionTypes
	local Types = context.Types

	validateStageObjectiveReferences(context, report)
	validateObjectiveNextStageReferences(context, report)
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
end

return {
	Validate = validate,
}
