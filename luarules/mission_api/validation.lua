---
--- Mission API validation entrypoint.
--- Validates raw mission data, returning the collected messages, ordered.
--- LogResult writes the messages.
---

local validationReport = VFS.Include("luarules/mission_api/validation/report.lua")
local createReport = validationReport.Create
local sections = validationReport.Sections
local createParameterValidators =
	VFS.Include("luarules/mission_api/validation/parameter_validators.lua").CreateParameterValidators
local sectionsValidation = VFS.Include("luarules/mission_api/validation/sections.lua")
local referencesValidation = VFS.Include("luarules/mission_api/validation/references.lua")

--- Mission tables are normalised here so no validator has to handle a missing or
--- misdeclared one. A wrong type is reported once, in the section it belongs to.
local function missionTable(value, fieldName, section, report)
	if value == nil then
		return {}
	end
	if type(value) ~= "table" then
		report.Error(section, nil, nil, fieldName .. " must be a table, got " .. type(value))
		return {}
	end
	return value
end

--- Read-only view of the raw mission data and the loaded definitions.
--- Definitions are read when validation runs, not when this file is included, so that
--- including it does not depend on how far GG["MissionAPI"] has been populated.
--- @param mission table raw mission table, exactly as returned by the mission file
local function createValidationContext(mission, report)
	local missionAPI = GG["MissionAPI"]
	local parameterTypes = missionAPI.Modules.ParameterTypes
	local triggerDefinitions = missionAPI.TriggerDefinitions
	local actionDefinitions = missionAPI.ActionDefinitions

	return {
		-- Raw mission data:
		InitialStage = mission.InitialStage,
		Stages = missionTable(mission.Stages, "Stages", sections.Stages, report),
		Objectives = missionTable(mission.Objectives, "Objectives", sections.Objectives, report),
		Triggers = missionTable(mission.Triggers, "Triggers", sections.Triggers, report),
		Actions = missionTable(mission.Actions, "Actions", sections.Actions, report),
		UnitLoadout = missionTable(mission.UnitLoadout, "UnitLoadout", sections.Loadouts, report),
		FeatureLoadout = missionTable(mission.FeatureLoadout, "FeatureLoadout", sections.Loadouts, report),

		-- Parameter types:
		Types = parameterTypes.Types,
		Enums = parameterTypes.Enums,
		EnumSets = parameterTypes.EnumSets,

		-- Trigger definitions:
		TriggerTypes = triggerDefinitions.Types,
		TriggerParameters = triggerDefinitions.Parameters,

		-- Action definitions:
		ActionTypes = actionDefinitions.Types,
		ActionParameters = actionDefinitions.Parameters,
	}
end

local function runValidation(mission, report)
	local context = createValidationContext(mission, report)
	local parameterValidators = createParameterValidators(context)

	sectionsValidation.Validate(context, report, parameterValidators)
	referencesValidation.Validate(context, report)
end

--- @param mission table raw mission table, exactly as returned by the mission file
--- @return table result { ok = boolean, errors = string[], warnings = string[] }
local function validateMission(mission)
	local report = createReport()

	local succeeded, err = pcall(runValidation, mission, report)

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
		Spring.Log("MissionAPI", LOG.ERROR, "[Mission API] " .. message)
	end
	for _, message in ipairs(result.warnings) do
		Spring.Log("MissionAPI", LOG.WARNING, "[Mission API] " .. message)
	end
end

return {
	ValidateMission = validateMission,
	LogResult = logResult,
}
