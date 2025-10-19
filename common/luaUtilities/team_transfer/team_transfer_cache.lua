local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")

local M = {}

-- Simple field type markers used by serializer
M.FieldTypes = {
  string = "string",
  boolean = "boolean",
  number = "number",
}

---Generate base key for policy caching using TransferCategory
---@param receiverId number
---@param transferCategory string SharedEnums.TransferCategory enum value
---@return string
function M.MakeBaseKey(receiverId, transferCategory)
  local baseKeyPrefix = transferCategory
  return string.format("%s_policy_%d_", baseKeyPrefix, receiverId)
end

--- Serialize an object using a fields schema into a colon-delimited string
--- @param fields table<string,string> fieldName -> FieldTypes
--- @param obj table
--- @return string
function M.Serialize(fields, obj)
  local parts = {}
  for fieldName, fieldType in pairs(fields) do
    local v = obj[fieldName]
    if v ~= nil then
      if fieldType == M.FieldTypes.boolean then
        v = v and "1" or "0"
      elseif fieldType == M.FieldTypes.string then
        v = tostring(v)
      else
        v = tostring(v)
      end
      parts[#parts+1] = fieldName
      parts[#parts+1] = v
    end
  end
  return table.concat(parts, ":")
end

--- Deserialize a colon-delimited string into a table using a fields schema
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
    parts[#parts+1] = part
  end
  for i = 1, #parts, 2 do
    local key = parts[i]
    local value = parts[i + 1]
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


