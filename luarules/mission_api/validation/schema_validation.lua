---
--- Schema driven parameter validation, shared by triggers, actions and objective triggers.
---

local validatorUtils = VFS.Include('luarules/mission_api/validation/parameter_validators/validator_utils.lua')
local validateTableType = validatorUtils.ValidateTableType

local function createSchemaValidator(parameterValidators, report)
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

return {
	CreateSchemaValidator = createSchemaValidator,
}
