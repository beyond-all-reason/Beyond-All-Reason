local root = GG or WG or _G
if root.__published then
	return root.__published
end

local Published = {}

Published.String = "string"
Published.Number = "number"
Published.Boolean = "boolean"
Published.List = "list"

Published.FieldTypes = {
	string = Published.String,
	number = Published.Number,
	boolean = Published.Boolean,
	list = Published.List,
}

Published.EVENT = "ModulePublished"

local buffer = {}

---@param fields table<string, string> field name -> wire type
---@param record table
---@return string
function Published.Encode(fields, record)
	local n = 0
	for name, fieldType in pairs(fields) do
		local v = record[name]
		if v ~= nil then
			if fieldType == Published.Boolean then
				v = v and "1" or "0"
			elseif fieldType == Published.List then
				v = table.concat(v, ",")
			else
				v = tostring(v)
			end
			n = n + 1
			buffer[n] = name
			n = n + 1
			buffer[n] = v
		end
	end
	for i = n + 1, #buffer do
		buffer[i] = nil
	end
	return table.concat(buffer, ":")
end

---@param fields table<string, string> field name -> wire type
---@param serialized string
---@param extras table? merged into the result
---@return table
function Published.Decode(fields, serialized, extras)
	local result = {}
	if type(serialized) ~= "string" then
		serialized = tostring(serialized or "")
	end
	local parts = {}
	for part in string.gmatch(serialized, "([^:]+)") do
		parts[#parts + 1] = part
	end
	for i = 1, #parts, 2 do
		local key, value = parts[i], parts[i + 1]
		if key and value then
			local fieldType = fields[key]
			if fieldType == Published.Boolean then
				result[key] = value == "1"
			elseif fieldType == Published.Number then
				result[key] = tonumber(value) or 0
			elseif fieldType == Published.List then
				local list = {}
				for item in value:gmatch("[^,]+") do
					list[#list + 1] = item
				end
				result[key] = list
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

local lastSignature = {} ---@type table<string, table<integer, string>> key -> team -> what was last written

---@class PublishedRecord one per-team record: the param key and the fields on it
---@field key string the team rules param
---@field fields table<string, string>
---@field Write fun(spring: Spring, teamID: integer, record: table, changesOn: string[]|nil): boolean synced only; true when the record changed since this state last wrote it, which also fired EVENT. changesOn narrows what counts as a change.
---@field Read fun(spring: Spring, teamID: integer): table|nil either side; nil when never published

---@param key string the team rules param the record lives on
---@param fields table<string, string> field name -> wire type
---@return PublishedRecord
function Published.PerTeam(key, fields)
	assert(type(key) == "string" and type(fields) == "table", "Published.PerTeam(key, fields)")
	lastSignature[key] = lastSignature[key] or {}
	local last = lastSignature[key]

	local function signatureOf(record, serialized, changesOn)
		if changesOn == nil then
			return serialized
		end
		local parts = {}
		for i, name in ipairs(changesOn) do
			parts[i] = tostring(record[name])
		end
		return table.concat(parts, "|")
	end

	return {
		key = key,
		fields = fields,
		Write = function(spring, teamID, record, changesOn)
			local serialized = Published.Encode(fields, record)
			spring.SetTeamRulesParam(teamID, key, serialized)
			local signature = signatureOf(record, serialized, changesOn)
			local previous = last[teamID]
			last[teamID] = signature
			if previous == nil or previous == signature then
				return false
			end
			---@diagnostic disable-next-line: undefined-global -- synced only; absent in widgets and specs
			if SendToUnsynced then
				SendToUnsynced(Published.EVENT, key, teamID)
			end
			return true
		end,
		Read = function(spring, teamID)
			local serialized = spring.GetTeamRulesParam(teamID, key)
			if serialized == nil then
				return nil
			end
			return Published.Decode(fields, serialized)
		end,
	}
end

root.__published = Published
return Published
