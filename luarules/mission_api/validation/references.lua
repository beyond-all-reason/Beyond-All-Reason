---
--- Checks references: objectives in a stage, nextStage, and unit, feature, and marker names.
---

local SECTION = VFS.Include("luarules/mission_api/validation/report.lua").Sections.References
local getTypesWithParameterType = VFS.Include("luarules/mission_api/schema_utils.lua").GetTypesWithParameterType

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

--------------------------------------------------------------------------------
-- Unit, feature and marker name references
--------------------------------------------------------------------------------

local function recordSource(sourcesByName, name, source)
	local sources = table.ensureTable(sourcesByName, name)
	sources[#sources + 1] = source
end

local function reportUnmatchedNames(report, label, createdNames, referencedNames)
	-- Sources are collected while walking tables, so they are sorted to keep the
	-- message the same from one run to the next.
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

--- Shared walker for unit and feature names, which can be created and referenced by
--- loadouts, actions, triggers and the inline triggers of objectives.
local function validateNameReferences(context, report, spec)
	local nameKey = spec.nameKey
	local createdNames = {}
	local referencedNames = {}

	-- Loadout entries with a name count as creating that name.
	for index, entry in ipairs(spec.loadout) do
		if type(entry) == "table" and type(entry[nameKey]) == "string" then
			recordSource(createdNames, entry[nameKey], spec.loadoutLabel .. "[" .. index .. "]")
		end
	end

	for actionID, action in pairs(context.Actions) do
		local parameters = type(action) == "table" and action.parameters
		if type(parameters) == "table" then
			-- Actions with an inline loadout also create names.
			if action.type == spec.loadoutActionType and type(parameters[spec.loadoutParameter]) == "table" then
				for index, entry in ipairs(parameters[spec.loadoutParameter]) do
					if type(entry) == "table" and type(entry[nameKey]) == "string" then
						recordSource(
							createdNames,
							entry[nameKey],
							"action " .. actionID .. " (" .. spec.loadoutParameter .. "[" .. index .. "])"
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
				if spec.creatingActionTypes[action.type] then
					recordSource(createdNames, name, "action " .. actionID)
				elseif spec.referencingActionTypes[action.type] then
					recordSource(referencedNames, name, "action " .. actionID)
				end
			end
		end
	end

	-- Triggers only ever reference names.
	local referencingTriggerTypes = getTypesWithParameterType(context.TriggerParameters, spec.nameType)
	for triggerID, trigger in pairs(context.Triggers) do
		local parameters = type(trigger) == "table" and trigger.parameters
		if
			type(parameters) == "table"
			and referencingTriggerTypes[trigger.type]
			and type(parameters[nameKey]) == "string"
		then
			recordSource(referencedNames, parameters[nameKey], "trigger " .. triggerID)
		end
	end

	-- Objective inline triggers can also refer to names.
	for objectiveID, objective in pairs(context.Objectives) do
		local trigger = type(objective) == "table" and objective.trigger
		local parameters = type(trigger) == "table" and trigger.parameters
		if type(parameters) == "table" and type(parameters[nameKey]) == "string" then
			recordSource(referencedNames, parameters[nameKey], "objective " .. objectiveID .. " (trigger)")
		end
	end

	reportUnmatchedNames(report, spec.label, createdNames, referencedNames)
end

--- Marker names are simpler: only actions create and reference them.
local function validateMarkerNameReferences(context, report)
	local actionTypes = context.ActionTypes
	local createdNames = {}
	local referencedNames = {}

	for actionID, action in pairs(context.Actions) do
		local parameters = type(action) == "table" and action.parameters
		if type(parameters) == "table" and type(parameters.name) == "string" then
			if action.type == actionTypes.AddMarker then
				recordSource(createdNames, parameters.name, "action " .. actionID)
			elseif action.type == actionTypes.EraseMarker then
				recordSource(referencedNames, parameters.name, "action " .. actionID)
			end
		end
	end

	reportUnmatchedNames(report, "Marker name", createdNames, referencedNames)
end

--- Any action taking a unit/feature name parameter references that name, unless it creates it.
local function getReferencingActionTypes(context, nameType, creatingActionTypes)
	local referencingActionTypes = getTypesWithParameterType(context.ActionParameters, nameType)
	for actionType in pairs(creatingActionTypes) do
		referencingActionTypes[actionType] = nil
	end
	return referencingActionTypes
end

--------------------------------------------------------------------------------

local function validate(context, report)
	local actionTypes = context.ActionTypes
	local Types = context.Types

	validateStageObjectiveReferences(context, report)
	validateObjectiveNextStageReferences(context, report)

	local unitCreatingActionTypes = {
		[actionTypes.SpawnUnits] = true,
		[actionTypes.NameUnits] = true,
	}
	validateNameReferences(context, report, {
		label = "Unit name",
		nameKey = "unitName",
		nameType = Types.UnitName,
		loadout = context.UnitLoadout,
		loadoutLabel = "UnitLoadout",
		loadoutParameter = "unitLoadout",
		loadoutActionType = actionTypes.SpawnUnits,
		creatingActionTypes = unitCreatingActionTypes,
		referencingActionTypes = getReferencingActionTypes(context, Types.UnitName, unitCreatingActionTypes),
	})

	local featureCreatingActionTypes = {
		[actionTypes.CreateFeatures] = true,
	}
	validateNameReferences(context, report, {
		label = "Feature name",
		nameKey = "featureName",
		nameType = Types.FeatureName,
		loadout = context.FeatureLoadout,
		loadoutLabel = "FeatureLoadout",
		loadoutParameter = "featureLoadout",
		loadoutActionType = actionTypes.CreateFeatures,
		creatingActionTypes = featureCreatingActionTypes,
		referencingActionTypes = getReferencingActionTypes(context, Types.FeatureName, featureCreatingActionTypes),
	})

	validateMarkerNameReferences(context, report)
end

return {
	Validate = validate,
}
