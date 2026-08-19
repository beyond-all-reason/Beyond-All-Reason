---
--- Action validation: parameters and trigger references.
---

local SECTION = VFS.Include('luarules/mission_api/validation/validation_report.lua').Sections.Actions
local LABEL = 'Action'

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

local function validate(context, report, parameterValidators, validateSchema)
	local allActionIDsReferencedByTriggers = getAllActionIDsReferencedByTriggers(context.Triggers)

	local unreferencedActionIDs = {}
	for actionID, action in pairs(context.Actions) do
		if not allActionIDsReferencedByTriggers[actionID] then
			unreferencedActionIDs[#unreferencedActionIDs + 1] = actionID
		end

		if type(action) ~= 'table' then
			report.Error(SECTION, LABEL, actionID, "Action data must be a table, got " .. type(action))
		else
			validateSchema({ section = SECTION, label = LABEL, id = actionID },
				context.ActionParameters, action.type, action.parameters)
		end
	end

	if not table.isEmpty(unreferencedActionIDs) then
		table.sort(unreferencedActionIDs)
		report.Error(SECTION, nil, nil, "Actions not referenced by any trigger: " .. table.concat(unreferencedActionIDs, ", "))
	end
end

return {
	Validate = validate,
}
