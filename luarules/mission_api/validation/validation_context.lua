---
--- Read-only view of the raw mission data and the injected definitions.
---

local schemaUtils = VFS.Include('luarules/mission_api/schema_utils.lua')
local sections = VFS.Include('luarules/mission_api/validation/validation_report.lua').Sections

--- Mission tables are normalised here so no validator has to handle a missing or
--- misdeclared one. A wrong type is reported once, in the section it belongs to.
local function missionTable(value, fieldName, section, report)
	if value == nil then
		return {}
	end
	if type(value) ~= 'table' then
		report.Error(section, nil, nil, fieldName .. " must be a table, got " .. type(value))
		return {}
	end
	return value
end

--- @param mission table raw mission table, exactly as returned by the mission file
--- @param definitions table { ParameterTypes, TriggerDefinitions, ActionDefinitions }
local function createValidationContext(mission, definitions, report)
	local parameterTypes = definitions.ParameterTypes
	local triggerDefinitions = definitions.TriggerDefinitions
	local actionDefinitions = definitions.ActionDefinitions

	return {
		-- Raw mission data:
		InitialStage   = mission.InitialStage,
		Stages         = missionTable(mission.Stages, 'Stages', sections.Stages, report),
		Objectives     = missionTable(mission.Objectives, 'Objectives', sections.Objectives, report),
		Triggers       = missionTable(mission.Triggers, 'Triggers', sections.Triggers, report),
		Actions        = missionTable(mission.Actions, 'Actions', sections.Actions, report),
		UnitLoadout    = missionTable(mission.UnitLoadout, 'UnitLoadout', sections.Loadouts, report),
		FeatureLoadout = missionTable(mission.FeatureLoadout, 'FeatureLoadout', sections.Loadouts, report),

		-- Parameter types:
		Types    = parameterTypes.Types,
		Enums    = parameterTypes.Enums,
		EnumSets = parameterTypes.EnumSets,

		-- Trigger definitions:
		TriggerParameters        = triggerDefinitions.Parameters,
		TriggerTypesWithQuantity = schemaUtils.GetTypesWithParameterType(triggerDefinitions.Parameters, parameterTypes.Types.Quantity),

		-- Action definitions:
		ActionTypes      = actionDefinitions.Types,
		ActionParameters = actionDefinitions.Parameters,
	}
end

return {
	CreateValidationContext = createValidationContext,
}
