-- Minimal JSON Schema (draft-07) validator, covering only the keywords the shared
-- config schemas use. Unrecognised keywords are ignored rather than rejected.
--
-- Exists so the schemas shipped for other surfaces are what CI enforces, rather than a
-- second set of rules hand-written in Lua that can drift from them.

local M = {}

-- Decoded JSON gives tables for both, so an array is a table keyed only by 1..n. An
-- empty table is indistinguishable and passes as either.
local function isArray(value)
	if type(value) ~= "table" then
		return false
	end

	local count = 0
	for key in pairs(value) do
		if type(key) ~= "number" then
			return false
		end
		count = count + 1
	end

	return count == #value
end

-- An empty Lua table is ambiguous: it reads as both an object and an array.
local function isEmptyTable(value)
	return type(value) == "table" and next(value) == nil
end

-- JSON type test over Lua values, where one table serves for object and array. Draft-07
-- allows a list of acceptable types, which matches if any one of them does.
local function typeMatches(expected, value)
	if type(expected) == "table" then
		for _, one in ipairs(expected) do
			if typeMatches(one, value) then
				return true
			end
		end

		return false
	end

	if expected == "object" then
		return type(value) == "table" and (not isArray(value) or isEmptyTable(value))
	elseif expected == "array" then
		return isArray(value)
	elseif expected == "integer" then
		return type(value) == "number" and value % 1 == 0
	elseif expected == "number" then
		return type(value) == "number"
	elseif expected == "string" then
		return type(value) == "string"
	elseif expected == "boolean" then
		return type(value) == "boolean"
	end

	return true
end

-- Follows a local $ref into definitions.
local function resolve(schema, root)
	local ref = schema["$ref"]
	if not ref then
		return schema
	end

	local node = root
	for part in ref:gmatch("[^/#]+") do
		node = node and node[part]
	end
	assert(node, "unresolvable $ref: " .. ref)

	return node
end

local validate

-- oneOf holds only when exactly one branch matches.
local function validateOneOf(schema, value, root, path, errors)
	local matched = 0
	for _, option in ipairs(schema.oneOf) do
		local sub = {}
		validate(option, value, root, path, sub)
		if #sub == 0 then
			matched = matched + 1
		end
	end

	if matched ~= 1 then
		errors[#errors + 1] = path
			.. ": matches "
			.. matched
			.. " of "
			.. #schema.oneOf
			.. " allowed shapes, expected exactly 1"
	end
end

validate = function(schema, value, root, path, errors)
	schema = resolve(schema, root)

	if schema.type and not typeMatches(schema.type, value) then
		local expected = type(schema.type) == "table" and table.concat(schema.type, "/") or schema.type
		errors[#errors + 1] = path .. ": expected " .. expected .. ", got " .. type(value)

		return errors
	end

	if schema.oneOf then
		validateOneOf(schema, value, root, path, errors)
	end

	if schema.enum then
		local allowed = false
		for _, option in ipairs(schema.enum) do
			if option == value then
				allowed = true
				break
			end
		end

		if not allowed then
			errors[#errors + 1] = path .. ": " .. tostring(value) .. " is not one of the allowed values"
		end
	end

	if type(value) == "string" and schema.minLength and #value < schema.minLength then
		errors[#errors + 1] = path .. ": shorter than minLength " .. schema.minLength
	end

	if type(value) == "number" and schema.minimum and value < schema.minimum then
		errors[#errors + 1] = path .. ": below minimum " .. schema.minimum
	end

	if type(value) ~= "table" then
		return errors
	end

	for _, name in ipairs(schema.required or {}) do
		if value[name] == nil then
			errors[#errors + 1] = path .. ": missing required property '" .. name .. "'"
		end
	end

	if schema.properties then
		for name, sub in pairs(schema.properties) do
			if value[name] ~= nil then
				validate(sub, value[name], root, path .. "." .. name, errors)
			end
		end
	end

	-- Each of these stands on its own in the spec, so none of them hangs off another
	-- keyword being present: additionalProperties is meaningful with no properties listed,
	-- and minItems with no items schema.
	if schema.additionalProperties == false then
		local declared = schema.properties or {}
		for name in pairs(value) do
			if type(name) == "string" and declared[name] == nil then
				errors[#errors + 1] = path .. ": unexpected property '" .. name .. "'"
			end
		end
	end

	if schema.minItems and isArray(value) and #value < schema.minItems then
		errors[#errors + 1] = path .. ": has " .. #value .. " items, needs at least " .. schema.minItems
	end

	if schema.items and isArray(value) then
		for i, entry in ipairs(value) do
			validate(schema.items, entry, root, path .. "[" .. i .. "]", errors)
		end
	end

	return errors
end

-- Entry point: validates a document against a schema.
function M.validate(schema, document)
	return validate(schema, document, schema, "$", {})
end

return M
