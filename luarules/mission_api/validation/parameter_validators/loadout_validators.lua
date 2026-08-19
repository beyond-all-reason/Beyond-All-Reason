---
--- Unit and feature loadout parameter validators.
---

local validatorUtils = VFS.Include('luarules/mission_api/validation/parameter_validators/validator_utils.lua')
local appendResults = validatorUtils.AppendResults
local getListValidator = validatorUtils.GetListValidator
local validateTableType = validatorUtils.ValidateTableType

local function register(parameterValidators, context)
	local Types = context.Types

	--- Named fields of a loadout entry, in the order they are reported. The position of an
	--- entry is not among them, since its x, y and z sit directly on the entry.
	local unitEntryFields = {
		{ name = 'unitDefName',  type = Types.UnitDefName, required = true },
		{ name = 'team',         type = Types.TeamID, required = true },
		{ name = 'facing',       type = Types.Facing },
		{ name = 'unitName',     type = Types.String },
		{ name = 'construction', type = Types.Boolean },
		{ name = 'quantity',     type = Types.Number },
		{ name = 'spacing',      type = Types.Number },
		{ name = 'neutral',      type = Types.Boolean },
		{ name = 'orders',       type = Types.Orders },
	}

	local featureEntryFields = {
		{ name = 'featureDefName', type = Types.FeatureDefName, required = true },
		{ name = 'facing',         type = Types.Facing },
		{ name = 'featureName',    type = Types.String },
	}

	local function getEntryValidator(fields)
		return function(entry)
			local entryTypeResult = validateTableType(entry)
			if entryTypeResult then
				return entryTypeResult
			end

			-- The entry itself is the position, since x, y and z are fields of the entry.
			local results = appendResults({}, parameterValidators[Types.Position](entry))

			for _, field in ipairs(fields) do
				local value = entry[field.name]
				if value == nil then
					if field.required then
						results[#results + 1] = { message = "Missing required parameter", parameterNameSuffix = "." .. field.name }
					end
				else
					appendResults(results, parameterValidators[field.type](value), "." .. field.name)
				end
			end

			return results
		end
	end

	parameterValidators[Types.UnitLoadout] = getListValidator(getEntryValidator(unitEntryFields))
	parameterValidators[Types.FeatureLoadout] = getListValidator(getEntryValidator(featureEntryFields))
end

return {
	Register = register,
}
