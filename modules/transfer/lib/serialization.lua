local M = {}

M.FieldTypes = {
	string = "string",
	boolean = "boolean",
	number = "number",
}

-- pooled to avoid a table allocation per call
local serializeBuffer = {}

--- @param fields table<string,string> fieldName -> FieldTypes
--- @param obj table
--- @return string
function M.Serialize(fields, obj)
	local n = 0
	for fieldName, fieldType in pairs(fields) do
		local v = obj[fieldName]
		if v ~= nil then
			if fieldType == M.FieldTypes.boolean then
				v = v and "1" or "0"
			else
				v = tostring(v)
			end
			n = n + 1
			serializeBuffer[n] = fieldName
			n = n + 1
			serializeBuffer[n] = v
		end
	end
	for i = n + 1, #serializeBuffer do
		serializeBuffer[i] = nil
	end
	return table.concat(serializeBuffer, ":")
end

--- @param fields table<string,string> fieldName -> FieldTypes
--- @param serialized string
--- @param extras table? optional table of extra kv pairs to merge into result
--- @return table
function M.Deserialize(fields, serialized, extras)
	local result = {}
	if type(serialized) ~= "string" then
		serialized = tostring(serialized or "")
	end
	local parts = {}
	for part in string.gmatch(serialized, "([^:]+)") do
		parts[#parts + 1] = part
	end
	for i = 1, #parts, 2 do
		local key = parts[i] ---@type string?
		local value = parts[i + 1] ---@type string? absent when the pair list is odd-length
		if key and value then
			local fieldType = fields[key]
			if fieldType == M.FieldTypes.boolean then
				result[key] = value == "1"
			elseif fieldType == M.FieldTypes.number then
				result[key] = tonumber(value) or 0
			else
				result[key] = value
			end
		end
	end
	if extras then
		for k, v in pairs(extras) do
			result[k] = v
		end
	end
	return result
end

return M
