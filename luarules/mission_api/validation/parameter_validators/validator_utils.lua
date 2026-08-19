---
--- Building blocks shared by the parameter validators.
---
--- A validator takes a value and returns a list of results, or nil when the value is valid.
--- A result is { message, parameterNameSuffix }, where the suffix names the part of the
--- parameter the message is about, e.g. "[2].unitDefName". Set isWarning on a result that
--- should not fail the mission.
---

local function validateLuaType(value, expectedType)
	local actualType = type(value)
	if value ~= nil and actualType ~= expectedType then
		return "Unexpected parameter type, expected " .. expectedType .. ", got " .. actualType
	end
end

--- Validates a named field of a value, e.g. the x of a position.
local function validateField(value, fieldName, expectedType)
	if value == nil then
		return { message = "Missing required parameter", parameterNameSuffix = "." .. fieldName }
	end
	if type(value) ~= expectedType then
		return { message = "Unexpected parameter type, expected " .. expectedType .. ", got " .. type(value), parameterNameSuffix = "." .. fieldName }
	end
end

--- Adds results to a result list, naming each one after the part it came from,
--- e.g. the index of a list element or the name of a field.
local function appendResults(results, addedResults, parameterNamePrefix)
	for _, addedResult in ipairs(addedResults or {}) do
		results[#results + 1] = {
			message = addedResult.message,
			parameterNameSuffix = (parameterNamePrefix or '') .. (addedResult.parameterNameSuffix or ''),
			isWarning = addedResult.isWarning,
		}
	end
	return results
end

-- Wraps validateLuaType as a validator, which returns a list of results
local function getLuaTypeValidator(expectedType)
	return function(value)
		local luaTypeResult = validateLuaType(value, expectedType)
		return luaTypeResult and { { message = luaTypeResult } } or nil
	end
end

local validateTableType = getLuaTypeValidator('table')

--- Validates that a value of a valid type also exists, e.g. a stage ID or a unit def name.
--- The lookup is a function, so engine def tables are read when the value is validated.
local function getLookupValidator(typeValidator, valueName, lookup)
	return function(value)
		local typeResult = typeValidator(value)
		if typeResult then
			return typeResult
		end

		if not lookup(value) then
			return { { message = "Invalid " .. valueName .. ": " .. value } }
		end
	end
end

--- Validates list elements with provided validator, naming results after the index.
--- Pass emptyMessage for lists that must not be empty.
local function getListValidator(elementValidator, emptyMessage)
	return function(values)
		local luaTypeResult = validateTableType(values)
		if luaTypeResult then
			return luaTypeResult
		end

		if emptyMessage and table.isNilOrEmpty(values) then
			return { { message = emptyMessage } }
		end

		local results = {}
		for index, value in pairs(values) do
			appendResults(results, elementValidator(value), "[" .. index .. "]")
		end
		return results
	end
end

return {
	ValidateLuaType     = validateLuaType,
	ValidateField       = validateField,
	AppendResults       = appendResults,
	GetLuaTypeValidator = getLuaTypeValidator,
	ValidateTableType   = validateTableType,
	GetLookupValidator  = getLookupValidator,
	GetListValidator    = getListValidator,
}
