---
--- Lua type, string, number, and enum-set parameter validators.
---

VFS.Include('common/wav.lua')

local validatorUtils = VFS.Include('luarules/mission_api/validation/parameter_validators/validator_utils.lua')
local getLuaTypeValidator = validatorUtils.GetLuaTypeValidator
local getLookupValidator = validatorUtils.GetLookupValidator
local getListValidator = validatorUtils.GetListValidator
local validateTableType = validatorUtils.ValidateTableType

local function getEnumSetValidator(enums, enumSetName, enumSetList)
	local valueSet = enums[enumSetName]
	local emptyMessage = enumSetName .. " table must not be empty"
	local allowedList = "'" .. table.concat(enumSetList, "', '") .. "'"

	return function(values)
		local luaTypeResult = validateTableType(values)
		if luaTypeResult then
			return luaTypeResult
		end
		if #values == 0 then
			return { { message = emptyMessage } }
		end

		local results = {}
		for index, value in ipairs(values) do
			if not valueSet[value] then
				results[#results + 1] = {
					message = "Invalid " .. enumSetName .. ": '" .. tostring(value) .. "'. Must be one of: " .. allowedList,
					parameterNameSuffix = "[" .. index .. "]",
				}
			end
		end
		if #results > 0 then
			return results
		end
	end
end

local function register(parameterValidators, context)
	local Types = context.Types
	local enums = context.Enums

	--- Lua type validators:
	parameterValidators[Types.Table] = validateTableType
	parameterValidators[Types.String] = getLuaTypeValidator('string')
	parameterValidators[Types.Number] = getLuaTypeValidator('number')
	parameterValidators[Types.Boolean] = getLuaTypeValidator('boolean')
	parameterValidators[Types.Function] = getLuaTypeValidator('function')

	--- Enum set validators:
	for enumSetName, valuesList in pairs(context.EnumSets) do
		parameterValidators[enumSetName] = getEnumSetValidator(enums, enumSetName, valuesList)
	end

	--- String validators:
	local validateString = parameterValidators[Types.String]

	parameterValidators[Types.StageID] = getLookupValidator(validateString, 'stageID',
		function(stageID) return context.Stages[stageID] end)
	parameterValidators[Types.ObjectiveID] = getLookupValidator(validateString, 'objectiveID',
		function(objectiveID) return context.Objectives[objectiveID] end)
	parameterValidators[Types.TriggerID] = getLookupValidator(validateString, 'triggerID',
		function(triggerID) return context.Triggers[triggerID] end)

	parameterValidators[Types.UnitDefName] = getLookupValidator(validateString, 'unitDefName',
		function(unitDefName) return UnitDefNames[unitDefName] end)
	parameterValidators[Types.WeaponDefName] = getLookupValidator(validateString, 'weaponDefName',
		function(weaponDefName) return WeaponDefNames[weaponDefName] end)
	parameterValidators[Types.FeatureDefName] = getLookupValidator(validateString, 'featureDefName',
		function(featureDefName) return FeatureDefNames[featureDefName] end)

	parameterValidators[Types.UnitName] = validateString
	parameterValidators[Types.FeatureName] = validateString

	--- List validators, checking each element with its own type's validator:
	parameterValidators[Types.StageIDs] = getListValidator(parameterValidators[Types.StageID])
	parameterValidators[Types.TriggerIDs] = getListValidator(parameterValidators[Types.TriggerID])

	parameterValidators[Types.Facing] = function(facing)
		local expectedTypes = { string = true, number = true }
		local actualType = type(facing)
		if not expectedTypes[actualType] then
			return { { message = "Unexpected parameter type, expected string or number, got " .. actualType } }
		end

		if not enums[Types.Facing][facing] then
			return { { message = "Invalid facing: " .. facing .. ". Must be one of 'n', 's', 'e', 'w', 'north', 'south', 'east', 'west'" } }
		end
	end

	parameterValidators[Types.SoundFile] = function(soundfile)
		local luaTypeResult = validateString(soundfile)
		if luaTypeResult then
			return luaTypeResult
		end

		if not VFS.FileExists(soundfile) then
			return { { message = "Invalid soundfile: " .. soundfile .. ". File does not exist" } }
		end

		if not ReadWAV(soundfile) then
			return { { message = "Invalid soundfile: " .. soundfile .. ". File is not a RIFF .wav file" } }
		end
	end

	--- Number validators:
	parameterValidators[Types.Quantity] = function(quantity)
		local luaTypeResult = parameterValidators[Types.Number](quantity)
		if luaTypeResult then
			return luaTypeResult
		end

		if quantity < 0 then
			return { { message = "Quantity must be >= 0, got " .. quantity } }
		end
	end
end

return {
	Register = register,
}
