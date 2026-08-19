---
--- Spatial parameter validators: Position, Positions and Area.
---

local validatorUtils = VFS.Include('luarules/mission_api/validation/parameter_validators/validator_utils.lua')
local validateField = validatorUtils.ValidateField
local validateTableType = validatorUtils.ValidateTableType
local getListValidator = validatorUtils.GetListValidator

-- Height is optional, so a position without y is only checked for x and z.
local positionFields = { "x", "z" }
local positionFieldsWithHeight = { "x", "y", "z" }

local function register(parameterValidators, context)
	local Types = context.Types

	parameterValidators[Types.Position] = function(position)
		local luaTypeResult = validateTableType(position)
		if luaTypeResult then
			return luaTypeResult
		end

		local result = {}
		local fields = position.y ~= nil and positionFieldsWithHeight or positionFields
		for _, field in ipairs(fields) do
			local fieldResult = validateField(position[field], field, 'number')
			if fieldResult then
				result[#result + 1] = fieldResult
			end
		end

		return result
	end

	local validatePositionList = getListValidator(parameterValidators[Types.Position])

	parameterValidators[Types.Positions] = function(positions)
		local result = validatePositionList(positions)

		-- Counting only makes sense once the list validator has confirmed a table
		if type(positions) == 'table' and #positions < 2 then
			table.insert(result, 1, { message = "Positions table needs at least two positions" })
		end

		return result
	end

	parameterValidators[Types.Area] = function(area)
		local luaTypeResult = validateTableType(area)
		if luaTypeResult then
			return luaTypeResult
		end

		local isRectangle = area.x1 and area.z1 and area.x2 and area.z2
		local isCircle = area.x and area.z and area.radius
		if not isRectangle and not isCircle then
			return { { message = "Invalid area parameter, must be either rectangle { x1, z1, x2, z2 } with x1 < x2 and z1 < z2, or circle { x, z, radius }" } }
		end

		-- Every field of an area is a number, whether it is a rectangle or a circle.
		local result = {}
		for key, value in pairs(area) do
			local fieldResult = validateField(value, key, 'number')
			if fieldResult then
				result[#result + 1] = fieldResult
			end
		end
		if not table.isEmpty(result) then
			return result
		end

		-- Corners can only be compared once every field is known to be a number.
		if isRectangle then
			if area.x1 >= area.x2 then
				result[#result + 1] = { message = "Invalid area rectangle parameter, x1 must be less than x2" }
			end
			if area.z1 >= area.z2 then
				result[#result + 1] = { message = "Invalid area rectangle parameter, z1 must be less than z2" }
			end
		end

		return result
	end
end

return {
	Register = register,
}
